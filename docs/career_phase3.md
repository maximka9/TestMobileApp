# 0.4 — Phase 3: reputation and relationships

- `SocialService` owns reputation changes (0..100), per-author relationship scores
  (-100..100), a small configurable rejection penalty and per-author spam windows.
- Starting reputation is configurable (default 50). Unknown authors have neutral
  relationships. Scores never directly remove followers or money.
- Future collaboration integration uses `relationship`, `reputation_factor`,
  `record_request` and `rejected`. Request timestamps are supplied by the caller;
  no random calls or system clock dependency are hidden inside the service.
- By default the third request to one author within 300 seconds costs 2 reputation.
  A normal rejection costs 1 relationship point, with no reputation penalty.
  Backward timestamps are rejected; request state persists across reloads.
- Two resource-defined fictional events allow helping or taunting pixel_neighbor.
  Social effects apply only after successful accepted actions. Skipping and failed
  actions do not alter scores; consumed events cannot grant a second reward.
- Schema 4 strictly validates reputation, relationships and request windows.
  Schemas 1–3 migrate with configured reputation and empty social dictionaries.
  Both dictionaries are bounded by the configured profile limit (default 500).
- Options opens a profile with reputation and relationships. README and profile
  explain that social scores, compatibility and acceptance probabilities are
  fictional gameplay values, not claims about real people or predictions.

Validation:

```powershell
godot --headless --path . --script tests/career_phase3.gd
godot --path . --script tests/typography_smoke.gd
.\tools\test.ps1
```

Targeted phase checks: **58 passed, 0 failed**. Integration: **119 passed,
0 failed**, restart write/read PASS. UI smoke: **0 failures**. Profile screenshot
reviewed at 540×960: `build/checks/typography/social_profile.png`.
Logs are in ignored `build/checks/phase3-*.log` and `build/checks/phase3.log`.
The collaboration engine and catalog remain in phases 4A/4B.
