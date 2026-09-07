# Phase 4A — Collaboration engine

Completed 2026-09-08, branch `feature/sasaclicker-career-v0.4`.

- Twenty explicitly fictional resource profiles span audience references from 5
  to 80,000. These are balance values, not real audience statistics. No networking.
- Selection prefers 2 smaller / 4 near / 3 larger / 1 aspirational candidates,
  falling back without duplicates when a group or the dataset is too small.
  Uses persistent average online, never instantaneous viewers.
- Supported formats intersect profile formats and currently available streams.
  Interest in the selected format improves acceptance; audience gap, relationship,
  reputation, recent requests and momentum also contribute. Chance is bounded,
  configurable and nonzero for compatible formats even with a very large gap.
- `CollaborationService` injects RNG and a clock. Rejection incurs a small social
  penalty; success grants capped followers, reputation, relationship and momentum.
  Momentum decays through the existing completed-stream lifecycle.
- Both outcomes create a persisted cooldown: default 600 + tier × 300 wall-clock
  seconds. These are configurable initial balance values. No real async jobs exist.
  Requests during cooldown cannot reroll or grant rewards; repeated attempts feed
  the existing spam protection. Successful collaboration count also persists.
- Schema 5 migrates schemas 1–4 with empty cooldowns and zero completed collabs.
  Cooldown IDs/timestamps and count are strictly validated and bounded.
- UI flow: candidate → format → chance/reasons → request → 0.8 s presentation
  delay → response. Outcome is resolved and saved before the animation; buttons
  prevent rapid duplicate input. Requests are available between streams.
- Legacy collab is hidden from Moves and rejected by StreamService. Its old event
  is now a fictional introduction without collab rewards; the unused move resource
  remains for compatibility with existing low-level move tests.

Validation:

```powershell
godot --headless --path . --script tests/career_phase4a.gd
godot --path . --script tests/collaboration_ui_smoke.gd
.\tools\test.ps1
```

Phase suite: **59 passed, 0 failed**. UI smoke: **0 failures**, including double
input, persistence before animation, success/rejection and cooldown button state.
Integration suite: **119 passed, 0 failed**; restart write/read PASS.
Screenshots in `build/checks/typography/collab_*.png` were inspected at 540×960;
logs are in ignored `build/checks/phase4a*.log`.

Production catalog work remains in phase 4B, requiring a separate user request.
