# Historical save fixtures

These JSON fixtures were emitted by the actual `serialize` methods extracted
with `git show`, not by assigning an old version number to a current save.

| Fixture | Historical commit | Schema |
|---|---|---|
| save_v03.json | 71f7d04 | 1 |
| save_v04.json | d802964 | 8 |
| save_v05.json | cc2ea43 | 9 |

Only the writer and its version constant were loaded into the fixture generator;
obsolete reader dependencies were excluded. Fixed timestamp 1000 and a player
with level 2, XP 3, 99 coins, fatigue 60, microphone 1 and prior career progress
make the result deterministic. These are test saves, never user save files.
