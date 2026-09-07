# Changelog

## [0.2.0] - 2026-09-07

### Added

- Detailed original SASAVOT pixel-art character based on the supplied reference.
- Layered red/black streamer room, original hockey-mask/13 and firefighter wall art.
- Character animation, high-hype lighting and bounded animated local chat.
- Touch-native room interaction with emulated mouse deduplication.
- Android SDK/export tooling and reproducible debug APK build script.
- Regression tests for dependencies, per-upgrade save limits, touch and effect pooling.
- Renderer smoke coverage for nine resolutions, safe insets and performance metrics.

### Changed

- Static main UI and room composition moved to editable `.tscn` scenes.
- Centralized crimson/black visual theme with functional energy/error colors.
- Fractional viewport scaling fills mobile aspect ratios without technical borders.
- Important touch targets are at least 48 logical units.
- Click feedback uses a fixed pool of 16 labels and no per-click tweens.

### Fixed

- Save validation respects each upgrade definition's maximum level.
- Bootstrap stops safely when configuration or parent dependencies are invalid.
- Touch plus an emulated mouse event no longer risks a duplicate gameplay click.
- Safe-area margins apply to both the main layout and modal windows.

## [0.1.0] - 2026-09-05

### Added

- Base clicker gameplay with typed player state and a portrait MainGame scene.
- Three resource-driven stream types and OFFLINE / STREAMING / SUMMARY flow.
- Viewer smoothing, hype decay, timed income, XP and level progression.
- Five generic equipment upgrades, beer and collab moves with cooldowns.
- Five random events with injectable deterministic RNG and local pseudochat.
- Original code-drawn pixel room, tap reactions, floating text and modal UI.
- Versioned local save/load, corruption backup, coalescing and bounded retries.
- Structured logging, debug performance metrics and reduced-motion setting.
- Domain, persistence, scene, restart and renderer smoke verification.
- Android export preset and setup documentation; APK requires local Android SDK.
