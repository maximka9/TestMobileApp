# Changelog

## [0.10.1]

### Fixed
- Achievement parent prerequisites now gate unlocks; dependency chains settle in parent-first signal order. Existing saved unlocks remain intact.
- Active inbound/outbound plans exclude each other. Legacy conflicting plans complete accepted inbound first, leaving outbound for a later stream.
- Cooldown and fatigue failures no longer record a social request or penalize reputation.
- Collaboration cards label offline snapshot interests as categories; disabled actions explain pending plans.
- README now describes schema 12, continuous fatigue recovery and the existing IRL city scene.
- Android export now preserves authored resources verbatim; binary conversion had stripped achievement parent arrays. APK builds verify resource integrity.

## [0.10.0]

### Added
- Achievement zoom controls, Fit, cursor-centred Ctrl+wheel and pinch gestures.
- Sequential achievement notifications with red/gold sparks and reduced motion.
- Six parallel legendary achievements for completed featured IRL collaborations.
- Double-confirmed progress reset with atomic save, queue cancellation and retained settings.

### Changed
- Candidate rotation is 60 real seconds; slot ten is reserved for featured creators.
- Compact creator cards show average viewers, follower snapshots and verified interests.
- Featured IRL acceptance schedules a collaboration; completion requires a 30-second IRL stream.
- Schema 12 stores pending/completed IRL collaborations and migrates previous saves.

### Fixed
- Scaled graph bounds and session navigation state; graph fonts use a local MSDF copy.
- Achievement progress counter updates while the tree is open.
- Developer importer can collect follower totals without adding runtime network calls.

## [0.9.0]

### Added
- Player-level gates for equipment and relocation, preserving existing purchases.
- Exact follower-growth formulas, fixed calculator scenarios and modal screenshots.

### Changed
- Ordinary click hype is fixed at 0.7; camera upgrades improve XP instead.
- Central hype curves strengthen online, organic growth, XP and source viral chance.
- Existing content can be published at any fatigue, clamped to 100 afterwards.

### Fixed
- Room monitor rendering above modal windows; modal theme retained across canvases.
- Content availability messages share the service check and distinguish used sources.
- Completed content captures its session format and average hype before reset.


## 0.8.0

- Linear XP thresholds and level-based click XP, capped equipment bonuses and
  high-hype bonus retained; level mastery increases active click hype.
- Actual hype + XP pooled feedback, visible level and nonblocking level-up pulse.
- Continuous elapsed-time rest at 10 fatigue per real minute, online/offline parity.
- Cosplay activated through Moves once per stream; existing costs and novelty data,
  hype and special-event weighting, optional mapped costume texture support.
- Shared StreamSessionStats for peak, average, hype and organic follower rewards;
  summary no longer mislabels career average as session online.
- Schema 11 migration preserves legacy level and XP progress ratio.


## 0.7.0 — 2026-09-09

### Added
- Organic stream follower growth based on observed audience, quality, novelty,
  reputation and career tier, with bounded exposure and stochastic rounding.
- Gameplay metrics documentation, seeded stream simulations and regression checks.
- Central stream game time: one real second is one game minute; monotonic ticks.
- Viewer-scaled chat cadence and a stable session participant pool.
- Minimal city scene for IRL streams.

### Changed
- Content automatically resolves its location; closing summary returns home.
- Remove the manual location selector; preserve content-specific cosplay choice.
- Increase click hype effectiveness 1.75x with a per-click cap, unchanged XP rules.
- Rebalance fatigue per game minute while keeping 60-real-second rest ticks.
- Clip monitor text to the physical screen with padding and five reused rows.

### Fixed
- Refresh visible collaboration cards at the deadline with generation tracking and
  guaranteed alternative sets; defer refresh in creator details.
- Incoming invite checks no longer rotate the user's collaboration list.
- Remove fictitious event creators and validate production creator references.
- Explicit hours/minutes in stream summaries; new sessions reset their tick origin.


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
