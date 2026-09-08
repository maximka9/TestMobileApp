# Changelog

## 0.6.0 — 2026-09-09

- Add configured follower-driven audience curve, seeded stream variance and central
  content/collaboration follower rewards, separate from XP.
- Add saved, expiring incoming collaborations and free completion rewards, fatigue,
  cooldowns and a three-stream viewer boost.
- Rotate ten mixed-size candidates every 120 seconds with recent-history avoidance;
  preserve open profiles and use a local directory repository adapter.
- Show short-form views/followers/fatigue results and honest snapshot audience labels.
- Remove duplicate Games navigation; add achievement drag/touch/wheel navigation,
  hidden scrollbars, computed bounds, progress header and node detail cards.
- Migrate schema 9 saves to schema 10 while retaining career state.


## 0.5.1 — 2026-09-09

- Complete YOUNG/CURRENT/SUCCESSFUL appearance with shared mapping for room and
  kitchen, real PNG alpha and fixed pixel dimensions.
- Validate achievement graph cycles/missing parents and distinguish available
  nodes from locked descendants. Verify all nodes reachable on small portraits.
- Validate case-insensitive streamer logins, known external IDs and calendar dates.
  Preserve save relationship keys. Canonical catalog requirement: **400+ verified
  profiles**, current snapshot 473; no invented external IDs or filler entries.
- Historical save fixtures from the actual 0.3, 0.4 and 0.5 serializers; clock,
  source lifecycle, corrupt-field and repeated migration regression checks.
- One verification entry point with explicit process statuses and negative control.
  Location stress checks 20 room/kitchen round trips and one gameplay click per tap.
- Remove unreferenced generic career/kitchen artwork; reduce kitchen source size.
- Consolidate the linear feature history into main and preserve milestones as tags.

## Historical milestones

- 0.5.0: `cc2ea43`, career sources, FAIL, minute fatigue, XP bonus, location scenes.
- 0.4.0: `d802964`, completed career systems and integration verification.
- 0.3.0 typography milestone: `71f7d04`, readable Cyrillic fonts and UI hierarchy.
  Historical project.godot incorrectly retained 0.2.0; the commit diff verifies
  the typography milestone. The annotated tag documents this metadata discrepancy.
- 0.2.0: `9d77e92`, pixel-art room and mobile UI overhaul.
- 0.1.0: `51129f0`, playable MVP.
