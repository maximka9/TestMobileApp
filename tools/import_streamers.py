"""Developer-only Twitch snapshot importer; no credentials in output.

Set TWITCH_CLIENT_ID and TWITCH_APP_TOKEN locally; invoke with --output PATH.
API: https://dev.twitch.tv/docs/api/reference/#get-streams
Get Streams paginates 100 live streams, so reach is a snapshot, not average online.
"""
import argparse
import datetime
import json
import os
from pathlib import Path
import urllib.parse
import urllib.request


def collect(fetch, limit=500, previous=None, fetch_followers=None):
    profiles = {}
    previous = previous or []
    by_external = {p["platform_user_id"]: p["id"] for p in previous if p.get("platform_user_id")}
    by_login = {p.get("login", p["id"]).lower(): p["id"] for p in previous}
    cursor = None
    seen_cursors = set()
    observed = datetime.date.today().isoformat()
    tags = {"Dota 2": "dota_2", "Just Chatting": "just_chatting", "Food & Drink": "cooking"}
    while len(profiles) < limit:
        query = {"first": 100, "language": "ru"}
        if cursor:
            query["after"] = cursor
        page = fetch(query)
        for stream in page.get("data", []):
            login = stream["user_login"].lower()
            external_id = stream["user_id"]
            game_id = by_external.get(external_id, by_login.get(login, "twitch:" + external_id))
            viewers = max(0, int(stream["viewer_count"]))
            interest = tags.get(stream.get("game_name"), stream.get("game_name", "")[:32])
            old = next((p for p in previous if p["id"] == game_id), {})
            followers = old.get("followers", -1)
            followers_source = old.get("followers_source", "")
            if fetch_followers:
                total = fetch_followers({"broadcaster_id": external_id}).get("total")
                if type(total) is int and 0 <= total <= 1000000000:
                    followers = total
                    followers_source = "https://api.twitch.tv/helix/channels/followers?broadcaster_id=" + external_id
            profiles[external_id] = {
                "id": game_id, "display_name": stream["user_name"],
                "platform": "twitch", "platform_user_id": external_id, "login": login,
                "source": "https://www.twitch.tv/" + login,
                "source_checked_at": observed, "is_placeholder": False,
                "reach_tier": sum(viewers >= v for v in [100, 1000, 5000, 15000]),
                "reference_avg_viewers": viewers,
                "followers": followers, "followers_source": followers_source,
                "stats_updated_at": observed, "interests_source": "https://www.twitch.tv/" + login,
                "reach_basis": "live_snapshot", "interests": [interest] if interest else [],
                "collab_formats": ["just_chatting", "dota_2", "irl", "cooking"],
                "base_acceptance": 0.5, "region": "public", "language": "ru",
            }
            if len(profiles) >= limit:
                break
        cursor = page.get("pagination", {}).get("cursor")
        if not cursor or cursor in seen_cursors or not page.get("data"):
            break
        seen_cursors.add(cursor)
    return {"profiles": list(profiles.values())}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--previous", type=Path, help="Existing snapshot, to preserve saved relationship IDs")
    parser.add_argument("--followers", action="store_true", help="Fetch follower totals using a compatible developer token")
    args = parser.parse_args()
    client = os.environ.get("TWITCH_CLIENT_ID")
    token = os.environ.get("TWITCH_APP_TOKEN")
    if not client or not token:
        parser.error("Set TWITCH_CLIENT_ID and TWITCH_APP_TOKEN in local environment")

    def fetch(query, endpoint="streams"):
        request = urllib.request.Request(
            "https://api.twitch.tv/helix/" + endpoint + "?" + urllib.parse.urlencode(query),
            headers={"Client-Id": client, "Authorization": "Bearer " + token},
        )
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)

    previous = json.loads(args.previous.read_text(encoding="utf-8"))["profiles"] if args.previous else []
    result = collect(fetch, previous=previous, fetch_followers=(lambda query: fetch(query, "channels/followers")) if args.followers else None)
    if not result["profiles"]:
        raise SystemExit("Empty snapshot; existing output preserved")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    temporary = args.output.with_suffix(".tmp")
    temporary.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    temporary.replace(args.output)
    print(f"Saved {len(result['profiles'])} public profiles")


if __name__ == "__main__":
    main()
