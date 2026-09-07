# SASA UI typography

Noto Sans is the interface font (Cyrillic, numbers, buttons, descriptions).
Russo One is the decorative font for branding, status and modal titles.
Both are bundled under SIL Open Font License 1.1; see the adjacent OFL files.
Sources: https://github.com/google/fonts/tree/main/ofl/notosans and
https://github.com/google/fonts/tree/main/ofl/russoone (downloaded 2026-09-07).

The original theme had no custom FontFile/FontVariation. Small default glyphs
were rendered into a 360x640 viewport, then enlarged 1.5x for the 540x960 window.
Main UI parents had no additional scale. The room has its own proportional scale.
Switching only stretch mode to canvas_items allows native-resolution text;
logical dimensions, expand/fractional policy and sprite nearest filtering remain.
See https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html.

Font imports use grayscale antialiasing, automatic hinting/subpixel positioning
and automatic oversampling (0), without mipmaps, embedded bitmaps or MSDF.
Concrete typography sizes live in resources/themes/sasa_theme.tres: caption 12,
small 13, body/button 14, heading 18, title/counter 22. Decorative branding and
miniature monitor/prop text have dedicated theme variations. Monitor labels bind
the theme explicitly because intermediate Node2D parents interrupt inheritance.

Verification, 2026-09-07:

- Focused tests/typography_smoke.gd: 0 failures, native 540x960 capture,
  Cyrillic fonts, button styles, offline/resource-disabled moves and upgrades,
  single event Skip, repeat event acceptance and modal dismissal.
- Existing visual smoke: 0 failures across nine window resolutions.
- One final full suite: 119 passed, 0 failed; restart write/read PASS.
- Reviewed main_offline, main_live, games, moves_offline, moves_live, event,
  upgrades, options and summary PNGs in build/checks/typography/.
- Android and gameplay services were not changed or tested in this stage.

Run the focused renderer check with:
`godot --path . --script tests/typography_smoke.gd`.
