# 0.4 — Phase 1: core progression

Completed 2026-09-07 from `feature/sasaclicker-ui-v0.3` / `71f7d04`.
Later phases and final version bump are intentionally not implemented yet.

- `CareerService` handles fatigue, nonlinear bounded audience reach, recency-based
  novelty, follower conversion and compact completed-stream history.
- `GameConfig` exposes starting values, fatigue rates/thresholds, recovery cap,
  audience coefficients, conversion cap, history/average/novelty windows.
- Default followers: 30. Audience uses followers^0.6 with a soft cap; clicks/XP
  cannot independently inflate base reach through level growth anymore.
- Followers are awarded on completion; average online uses the last 10 completed
  streams. History is capped at 50 entries; novelty remembers 5 formats.
- Fatigue is the only resource. Existing `energy` access is a computed inverse
  for move compatibility. Moves still consume the same percentage of capacity.
- New starts fail at configured exhaustion (95). Offline recovery is 0.1/sec,
  capped at 8 hours, with negative clock deltas ignored. Load recovery only applies
  to saves made outside a stream; an interrupted stream gives no recovery/rewards.
- Schema 2 stores fatigue and all phase-1 career fields. Explicit schema-1 migration
  preserves money, XP, settings, upgrades and counts, derives fatigue from energy,
  and initializes followers from config. No redundant saved energy or stream count.
- HUD shows followers/fatigue; content selection shows novelty; summary shows
  follower gain and persistent average online. Existing room assets are unchanged.

Validation:

```powershell
godot --headless --path . --script tests/career_phase1.gd
.\tools\test.ps1
godot --path . --script tests/typography_smoke.gd
```

Targeted phase suite: **80 passed, 0 failed** (includes affected existing tests).
Integration suite: **119 passed, 0 failed**; restart write/read PASS.
UI renderer smoke: **0 failures**, main HUD reviewed at 540×960.
Evidence: ignored `build/checks/career-*.log` and `build/checks/typography/*.png`.
The original flow test now earns remaining upgrade money after its collaboration;
it no longer assumes the old level-driven income spike within 500 seconds.

Phase 2 requires a separate user request, as specified by the master phase plan.
