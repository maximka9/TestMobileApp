# Original game art — SASAclicker 0.2.0

Created for this project with the built-in `image_gen` tool and the `imagegen` skill on 2026-09-07. The user's supplied photo was an identity/clothing reference for a new illustration. The photo itself is not bundled or displayed in the game. No movie screenshots, official posters, game screenshots, logos, downloaded artwork or external chat API are used.

## Runtime assets

| Asset | Logical size | Use |
|---|---:|---|
| `../characters/sasavot_frames.png` | 512×128 | Four 128×128 frames: idle, inhale, blink, click expression. |
| `wall.png` | 336×220 | Burgundy paneled wall and localized red light; transparent holes for separate scene layers. |
| `shelf.png`, `pc.png`, `floor.png` | 44×132, 53×98, 336×39 | Separate back-furniture and floor layers. |
| `friday_13.png`, `firefighter.png` | 38×45, 40×40 | Original mask/13 and firefighter helmet wall references. |
| `monitor.png` | 112×82 | Reused bezel for two runtime-driven displays. |
| `desk.png`, `microphone.png` | 308×76, 42×46 | Foreground equipment. |

Generated source atlases were sliced and nearest-neighbour downsampled for the runtime resolution. Character chroma-key was converted to alpha; generated prop alpha was preserved. Room components are non-overlapping slices of the same original illustration, composed as separate named nodes in `room_view.tscn`. Art is stored at its actual game resolution, rather than shipping enlarged generated previews. High-resolution working sources and the one-off Godot atlas preparation script are outside the tracked runtime assets.

## Generation prompts

**Character reference / sprite sheet:**

> Use case: stylized-concept. Asset type: production pixel-art transparent sprite sheet for Godot game, not a mockup. Reference image: attached photo is identity and clothes reference ONLY; redraw as original detailed pixel art, do not include photo or its background. Create ONE horizontal strip of FOUR near-identical seated upper-body sprites, each on a genuinely transparent background. Each frame has logical resolution96x128 pixels, presented at integer6x resolution, entire sheet2304x768 or same aspect3:1. The four frame cells equal size, perfectly aligned head and chair base, clearly separated transparent gutters. Subject: recognizable light-skinned adult man from reference, short medium-brown cropped hair with distinctive side-swept fringe, broad expressive dark eyebrows, detailed eyes nose mouth chin, bulky black over-ear headphones, loose off-white T-shirt with cool blue monitor light across folds and warm crimson rim light, arms extending forward onto invisible desk. Seated in charcoal streamer chair. Face relatively large, at least30logical pixels tall with natural rounded outline, NOT chibi square head. Frame1 relaxed attentive expression, frame2 subtle inhale shoulders up1pixel, frame3 brief eyes closed blink same posture, frame4 slight forward nod surprised delighted click reaction. Same scale, clothing, perspective, face identity, palette, base alignment across every frame. Crisp hand-placed square pixel clusters, professional detailed sprite-art, NO antialiasing, no gradients, no blur. Transparent background contains no other objects, no desk, no room, no text, no labels, no outlines around cells. Need true alpha background.

**Character background correction:**

> Use case: background-extraction. Production sprite sheet edit. Preserve every character detail, four expressions, alignment and image size. Replace ONLY ALL light-gray/white checkerboard background with perfectly solid chroma-key MAGENTA #FF00FF, including gaps between arms, with hard pixel edges. Not a transparency preview. Must be a single flat uniform RGB255,0,255 color in background, no checkerboard, no gradient, no shadow. Keep white T shirts unchanged. All four sprites should have at least12pixels magenta gap from each other. This will be chroma-key imported as game sprites.

**Room:**

> Use case: stylized-concept. Asset type: original production game background sprite for mobile pixel-art streamer clicker. One empty RED BLACK BURGUNDY streamer studio, NO PERSON, NO CHAIR, NO DESK, NO MONITORS. Flat front view, very slight perspective, composition landscape336x220 logical pixels shown at4x size1344x880. Walls fill upper180logical pixels, floor40. Black ceiling edge, deep burgundy #1f0d12 paneled wall, narrow glowing red LED strips left and right, subtle film grain represented as actual pixel clusters, left small dark shelf with books and tiny model car, right dark PC tower with two crimson illuminated fans and small potted trailing plant, floor boards near-black. Center wall area completely uncluttered, reserved for seated character that will be added later. Place two small framed original pixel-art wall decorations high on the wall: left at x40y30 width45height52 a cream stylized hockey mask with vent holes, crimson markings and small number13, dark burgundy background (NOT a movie poster or logo); right at x254y34 width44height44 original bright red firefighter helmet silhouette on black plaque. No other text, no logos, no game screenshot. Atmospheric localized dim cold monitor illumination from below-center and warm red rim light at edges, white character added later must stand out. Professional handcrafted pixel-art backdrop, clean square pixels, crisp clusters, tasteful detailed environment, limited palette about32colors, no soft gradients, no antialiasing, no blur, no isometric view.

**Props:**

> Use case: stylized-concept. Asset type: original production game prop sprite atlas. FOUR SEPARATE props on solid uniform CHROMA KEY MAGENTA #FF00FF background, 2x2 grid equal cells, image1024x1024, no text or grid lines. Square-pixel handmade retro pixel art, logical each cell128x128 displayed4x. Hard pixel edges, limited palette, NO blur, NO gradients. Each prop centered in its own cell with wide magenta margins. Top-left: front-facing widescreen computer monitor, charcoal-black bezel, screen perfectly flat dark blue #142030 EMPTY for runtime UI, crimson power LED, solid stand. Top-right: dark red wood streaming desk wide front view, only tabletop and two short legs; a detailed small black keyboard with ivory keys and red accents on center-left of tabletop, small mouse on right, no monitors. Bottom-left: side-address studio microphone charcoal grille in black shock mount on short desk stand and small boom, slight crimson rim light, cool-gray highlights. Bottom-right: framed original wall plaque of bright RED FIREFIGHTER HELMET on deep-black backdrop, no letters. Matching dim red-black streamer room game art. No people, no shadows on magenta, no checkerboard, no photorealism, no perspective tilt on monitor. Four distinct isolated game prop sprites.

The unused helmet tile from the props atlas was discarded; the room's matching wall plaque is used instead.
