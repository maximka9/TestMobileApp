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


def collect(fetch, limit=500):
    profiles = {}
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
            viewers = max(0, int(stream["viewer_count"]))
            interest = tags.get(stream.get("game_name"))
            profiles[login] = {
                "id": login, "display_name": stream["user_name"],
                "source": "https://www.twitch.tv/" + login,
                "source_checked_at": observed, "is_placeholder": False,
                "reach_tier": sum(viewers >= v for v in [100, 1000, 5000, 15000]),
                "reference_avg_viewers": viewers,
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
    args = parser.parse_args()
    client = os.environ.get("TWITCH_CLIENT_ID")
    token = os.environ.get("TWITCH_APP_TOKEN")
    if not client or not token:
        parser.error("Set TWITCH_CLIENT_ID and TWITCH_APP_TOKEN in local environment")

    def fetch(query):
        request = urllib.request.Request(
            "https://api.twitch.tv/helix/streams?" + urllib.parse.urlencode(query),
            headers={"Client-Id": client, "Authorization": "Bearer " + token},
        )
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)

    result = collect(fetch)
    if not result["profiles"]:
        raise SystemExit("Empty snapshot; existing output preserved")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    temporary = args.output.with_suffix(".tmp")
    temporary.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    temporary.replace(args.output)
    print(f"Saved {len(result['profiles'])} public profiles")


if __name__ == "__main__":
    main()
