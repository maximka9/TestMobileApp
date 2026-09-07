# 0.4 — Phase 2: short-form content

Completed 2026-09-07 on `feature/sasaclicker-career-v0.4`.

- `ShortFormService` publishes short-form content through an injected, seedable
  `RandomProvider`; no UI or platform API randomness is used.
- Seven data-driven definitions live in `resources/short_forms/`: Мем, Dota,
  Реакция, История, IRL, Фейл and Клип со стрима. Each has its own fatigue/money
  cost, base viral chance, follower multiplier and tags.
- Outcomes are Не залетел, Нормально, Хорошо залетел, Вирусный and
  МЕГА-ВИРУСНЫЙ. Configuration controls non-viral weights, viral cap, mega share,
  follower/momentum rewards and all scaling coefficients.
- Posting consumes fatigue even on a failed outcome. Viral outcomes add followers
  and temporary `growth_momentum`; momentum affects stream audience and decays
  after each completed stream. A configured cap prevents guaranteed virality.
- Save schema 3 persists momentum and short-form history. Schema 2 phase-1 saves
  migrate with neutral defaults; malformed or unknown history is rejected.
- The `Контент` navigation entry opens an offline-only short-form modal. It shows
  costs/chances and disables unaffordable or too-tiring posts.

Validation:

```powershell
godot --headless --path . --script tests/career_phase2.gd
.\tools\test.ps1
godot --path . --script tests/visual_smoke.gd
```

Targeted phase suite: **53 passed, 0 failed**. Integration suite:
**119 passed, 0 failed**; restart write/read PASS. Visual smoke: **0 failures**,
including `short_forms_modal.png` in `build/checks/v0.2/`.

Phase 3 requires a separate user request, as required by the master phase plan.
