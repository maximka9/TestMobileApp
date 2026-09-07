# Phase 4B — Offline profile catalog

The runtime now loads exactly 500 profiles from
`resources/streamers/streamers.json`. Loading creates `StreamerDefinition`
objects only after validating every field, the 500-profile limit and duplicate IDs.
Malformed catalog data clears the catalog and emits a startup diagnostic rather
than leaving a partial candidate list.

This production-scale catalog is fully offline and contains fictional gameplay
profiles. Names, relationships, compatibility, acceptance and reference audience
values are fictional balance data. They do not claim to describe public people,
their channels, analytics or behavior. The 20 fixture IDs remain for mechanics
coverage; the other 480 entries provide scale coverage without classes or runtime
network calls.

`CollaborationService` remains data-driven and selects candidate sets relative to
persistent average online. The JSON data has no executable content and uses only
the existing streamer-profile fields.

Validation:

```powershell
godot --headless --path . --script tests/career_phase4b.gd
godot --headless --path . --script tests/career_phase4a.gd
.\tools\test.ps1
```

Phase 4B catalog suite validates exact count, IDs, field completeness, unique
names, scale span and ten usable offline candidates at early and late career
levels. Phase 4A mechanics remain covered separately.
