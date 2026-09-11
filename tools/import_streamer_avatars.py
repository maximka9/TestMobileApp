"""Build-time only: snapshot public Twitch channel avatars without changing gameplay data."""
import concurrent.futures
import datetime
import hashlib
import html
import json
import pathlib
import re
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'assets/ui/avatars'

def fetch(profile):
    creator = profile['id']
    login = profile.get('login') or creator
    page = 'https://www.twitch.tv/' + login
    result = {'creator_id': creator, 'channel': page}
    try:
        request = urllib.request.Request(page, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(request, timeout=25) as response:
            markup = response.read().decode('utf-8')
        match = re.search(r'<meta property="og:image" content="([^"]+)"', markup)
        if not match:
            raise ValueError('No public channel avatar')
        source = html.unescape(match[1])
        if not source.startswith('https://static-cdn.jtvnw.net/jtv_user_pictures/') or 'profile_image' not in source:
            raise ValueError('Generic or unsupported avatar')
        source = source.replace('300x300', '150x150')
        with urllib.request.urlopen(source, timeout=25) as response:
            data = response.read()
        extension = '.png' if data.startswith(b'\x89PNG') else '.jpg' if data.startswith(b'\xff\xd8') else ''
        if not extension:
            raise ValueError('Unsupported image bytes')
        name = 'streamer_' + creator + extension
        (OUTPUT / name).write_bytes(data)
        result.update(path='res://assets/ui/avatars/' + name, source=source,
                      sha256=hashlib.sha256(data).hexdigest())
    except Exception as error:
        result['fallback_reason'] = str(error)
    return result

if __name__ == '__main__':
    OUTPUT.mkdir(parents=True, exist_ok=True)
    profiles = json.loads((ROOT / 'resources/streamers/streamers.json').read_text(encoding='utf-8'))['profiles']
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        entries = list(pool.map(fetch, profiles))
    document = {'checked_at': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'avatars': entries}
    (ROOT / 'resources/streamers/avatars.json').write_text(json.dumps(document, indent=2) + '\n', encoding='utf-8')
    print(f"Real Twitch avatars: {sum('path' in row for row in entries)}/{len(entries)}", flush=True)
