"""Release gate: exported resources must retain the exact authored configuration."""
from pathlib import Path
import json
import sys
import zipfile

root = Path(__file__).resolve().parents[1]
with zipfile.ZipFile(sys.argv[1]) as apk:
    checked = 0
    for folder in (root / "resources", root / "config"):
        for source in folder.rglob("*.tres"):
            asset = "assets/" + source.relative_to(root).as_posix()
            actual = apk.read(asset).decode("utf-8").replace("\r\n", "\n")
            expected = source.read_text(encoding="utf-8")
            if actual != expected:
                raise SystemExit("APK resource changed during export: " + asset)
            checked += 1
    print(f"APK resource integrity: {checked} authored resources preserved")
    manifest_path = root / 'resources/streamers/avatars.json'
    if manifest_path.exists():
        manifest = json.loads(apk.read('assets/resources/streamers/avatars.json'))
        assert manifest == json.loads(manifest_path.read_text(encoding='utf-8'))
        for row in manifest['avatars']:
            if row.get('path'):
                imported = 'assets/' + row['path'].removeprefix('res://') + '.import'
                assert imported in apk.namelist(), 'Avatar omitted: ' + row['creator_id']
        print('APK avatar manifest and imported textures preserved')
