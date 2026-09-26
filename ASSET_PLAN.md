# BLOCKMANIA — Asset Plan and Art Brief

**Version:** 0.3 · **Status:** 2026-09-23 UI overhaul shipped with an original, code-authored pixel-art kit (§12). The image-generator candidates from 2026-09-22 (`assets/source/generated/`) were reviewed by the owner and **not adopted**. They stay out of the game and out of the repository. · **Companion:** [GAME_DESIGN_DOCUMENT.md](GAME_DESIGN_DOCUMENT.md)

## 1. Purpose and visual target

This document lists the art, animation, UI, audio, and Steam marketing assets needed to make BLOCKMANIA feel like a finished desktop game. It is a production brief, not an asset pack. The three images provided by the project owner show the legible 8×8 grid, bright beveled blocks, score emphasis, and three-shape tray to preserve as usability cues. All deliverables must be original and sufficiently different in composition, logo, color treatment, and effect design.

**Approved direction:** colorful toy-like blocks inside a distinctive, cooler arcade UI with a retro vibe. A suggested palette is near-black charcoal `#101923`, midnight teal `#173944`, electric cyan `#51D9E8`, hot coral `#F45C71`, brass-gold `#F6BD50`, and six varied block hues. Hex values are exploration starting points, not final color specifications. Color alone must never encode legality, selection, rarity, or type.

**Style rules:** cells have tactile bevels and readable faces at 720p; board grid contrast stays strong; Joker art can be lively but must not obscure rules text; CRT/VHS layers sit behind or around the board and are optional; large score moments may use brief controlled glitches; avoid permanent heavy blur, aggressive strobe, and constant camera shake.

## 2. Asset production conventions

- **Source and exports:** keep editable source files separate from optimized game exports. Use vector source for logo/icons when practical, lossless raster for sprites/UI, and compressed delivery formats only after visual review. Record source ownership/license and export settings per asset.
- **Naming:** `category_subject_variant_state_resolution.ext`, lowercase snake case. Examples: `block_cyan_default_128.png`, `ui_button_primary_hover.svg`, `vfx_line_clear_spark_01.png`, `sfx_place_heavy_03.wav`. Stable asset IDs should match content IDs in game data.
- **Resolution:** author sprites at 2× expected 1080p display size where feasible. Verify small-screen appearance at 1280×720, 1920×1080, 16:10, and ultrawide; do not assume a fixed pixel-perfect scale.
- **Atlas policy:** pack repeating blocks, icons, and small VFX into atlases after visual iteration; preserve transparent padding to prevent bleeding. Keep large UI panels and full-screen textures separate.
- **Animation:** separate essential state communication from optional flourish. Every effect has a reduced-motion equivalent; gameplay resolution must never depend on animation duration.
- **Localization:** keep text live in Godot UI, not baked into art, except the BLOCKMANIA logo and approved Steam art. Provide enough room for longer translations: eleven UI languages ship (docs/localization.md) and `tests/e2e/scenario_languages.gd` checks every screen in each.
- **Accessibility:** check luminance contrast, colorblind palettes, non-color patterns, restrained flash, and reduced-motion alternatives for every critical state.
- **Licensing:** original or appropriately licensed assets only. The supplied screenshots are reference, not source material for tracing, extraction, or reuse.

## 3. Priority legend

- **P0 prototype:** needed to prove the core loop, may be temporary.
- **P1 vertical slice:** needed to establish the final look and feel of one act.
- **P2 content complete:** needed for the complete game.
- **P3 release/marketing:** needed for Steam launch and promotion.

## 4. Gameplay art inventory

| ID / family | Quantity target | Deliverable and states | Priority | Notes |
|---|---:|---|---|---|
| `board_frame` | 1 base + 4 cosmetic skins | Scalable frame, corner pieces, inner rim, focus glow | P0/P2 | Square 8×8 opening; no art may conceal a cell. |
| `board_cell` | 1 base + 3 accessibility variants | Empty tile, hovered, legal ghost, invalid ghost, pending clear, locked/pre-filled | P0/P1 | Use pattern and border, not color only. |
| `block_materials` | 6 colorways × 3 lighting states | Beveled tile face, side/shadow, highlight; optional normal map | P0/P1 | Color and lighting distinct at tray and board sizes. |
| `block_special` | 4 types | Gold-highlighted scoring block, boss-start block, target marker, selection marker | P1/P2 | Only where rules require; avoid misleading decorative blocks. |
| `shape_tray` | 3 slots × states | Empty, occupied, selected, hover, unavailable, refresh transition | P0/P1 | Shape geometry rendered from block cells, not a unique sprite per shape. |
| `placement_ghost` | 2 sets | Valid and invalid footprints, anchor indicator, projected cleared lines | P0/P1 | Must align exactly with the rules layer. |
| `board_themes` | 4 skins | Standard arcade, midnight neon, brass workshop, ultraviolet grid | P2 | Cosmetic only; maintain same grid readability. |
| `boss_marks` | 6 | Small symbol plus large round-intro badge per boss | P2 | Visual shorthand never replaces the written rule. |
| `block_material_finish` | 5 (Chrome, Neon, Gold, Glass, Prism) × board/tray/tile sizes | Overlay finish per material, plus shatter and clear variants for Glass and Gold | P1 | Each needs a shape cue (streaks, double outline, coin, glare, band) as well as color. The prototype draws these procedurally in `block_painter.gd`. |
| `piece_stamp_badge` | 4 (Encore, Refund, Tip, Memory) | Lettered badge that stays legible at 20 px and 90 px | P1 | Letter plus shape. Colors are secondary. |
| `schematic_level_pip` | 1 set | Family level indicator for tray, bag view, and receipt | P2 | Numeric text always present. |

**Shape art principle:** author reusable tile components. Shape definitions specify cell coordinates and colors in data; do not create a raster asset for every footprint/orientation. This reduces inconsistency and supports preview/ghost rendering.

## 5. Joker and consumable art

| ID / family | Quantity target | Deliverable and states | Priority | Notes |
|---|---:|---|---|---|
| `joker_card_frame` | 3 rarity frames + selected/disabled states | Common, uncommon, rare borders; slot shadow; foil/glow overlay | P1 | Order and rarity must remain readable without color. |
| `joker_illustration` | 24 | One original illustration for each GDD Joker | P1/P2 | Recognizable silhouette at thumbnail size; no borrowed card motifs. |
| `joker_icon` | 24 | Simplified icon for HUD/tooltips | P1/P2 | Ideally derived from same art language, not automatically cropped. |
| `joker_trigger_vfx` | 3 rarity families + 6 semantic variants | Pulse, chip burst, multiplier bloom, rule shift, board effect, economy event | P1/P2 | One Joker's effect must be distinguishable from score total. |
| `consumable_art` | 8 | One icon/illustration per item; unused/selected/used states | P1/P2 | Visual grammar different from passive Jokers. |
| `workshop_card_art` | 14 (13 tools + Schematic family variants) | Card frame and icon per Workshop card (plating, tubing, leaf, glassworks, prism, 4 stamps, copier, shredder, turntable, repaint, schematic) | P1/P2 | Distinct "tool" grammar from Jokers and items; target count shown in text. |
| `joker_illustration` (bag era) | +14 | Hoarder, Architect, Straight Edge, Square Deal, Last Piece, Postmaster, Lean Bag, Foundry, Neon Sign, Specialist, Recycler, Glass Cannon, Collector, Mimic | P2 | Joker total is now 38. |
| `kit_badge` | 5 | Standard, Compact, High Roller, Chunky, Tetromino (the picker currently draws each Kit's starter bag instead) | P2 | Clear starting tradeoff in adjacent live text. |
| Round-play icons *(produced, code-authored in `tools/art/gen_ui.py`)* | 11 | brick, eraser, hammer, bucket, blueprint, crate, tomb, scope, medal, shield, magnet | P1 | Pixel icons at 4× nearest; used on item cards, Joker emblems, tool sprites, Feat banners. |
| Boss Crate sprite *(produced, code-authored in `tools/art/gen_ui.py`)* | 2 | `crate_big` (closed wooden crate: planks, frame and diagonal brace, iron corner caps, brass hasp, pink skull seal) and `crate_big_open` (hover: lid lifted with light and sparkles) | P1 | 64×60 art px at 4×; the small `icon_crate` is its matching button icon. |
| `collection_unknown` | 1 | Undiscovered silhouette/card treatment | P2 | No gameplay information leak beyond desired unlock presentation. |
| Card portraits *(produced 2026-09-24, code-authored in `tools/art/gen_cards.py`)* | 52 Jokers + 11 items + 5 Workshop tools | 16×16 art px sprites with an auto ink outline; per sprite 8 frames: rest, 6-frame diagonal glint, dark silhouette. Drawn at whole-number scales (4× on offer/rack cards, 2× on item racks) over the phase-colored tile | P1 | `assets/ui/cards/{jokers,items,tools}.png` + `cards.json`. Materials/stamps keep their live finish drawing; Schematics show the family with a small drafting portrait. |
| Achievement badges *(produced 2026-09-24, `tools/art/gen_cards.py`)* | 48 icons + "?" + 6 frames | 16×16 icons (same format as the card portraits) and 24×24 medal frames: bronze, silver, gold, prism-rimmed legendary, locked, secret | P1 | `assets/ui/cards/achievements.png`, `badges.png`. Locked = silhouette + padlock; secret = "?" medal. |

**Card brief:** cards should look like miniature arcade curios or strange physical tokens on a workbench. Favor bold silhouettes, playful mechanical motifs, and subtle animated foil over playing-card suits or joker faces associated with other games. Each card needs legible rarity, name, rules text area, counters, and disabled-reason overlay.

## 6. UI inventory

| Screen / component | Deliverables | Priority | Key states and constraints |
|---|---|---|---|
| Title and main navigation | Background composition, animated logo, primary/secondary buttons, continue-state tile | P1 | Must read immediately as BLOCKMANIA, not a generic mobile clone. |
| Game HUD | Score/target meter, placements, combo, Credits, Refresh, boss rule, Joker strip, tray, pause | P0/P1 | Board dominates at 1080p and stays usable at 720p. |
| Score receipt | Compact event badge, expanded Chips/Mult ledger, trigger order indicators | P1 | Should explain surprising scores without pausing the run. |
| Round intro/outro | Target card, boss badge, reward tally, continue button | P1 | Animation skippable. |
| Shop | Nine offers (3 Jokers, 2 items, 2 Workshop, 2 pieces), prices, Credits, reroll, sell, reorder, next-boss preview, View Bag | P1 | Confirm purchase/sale feedback and disabled affordability states. |
| Bag view and Workshop picker | Piece tiles (material, stamp, text label), draw/tray/discard groupings, selection state, color chooser, "n of N chosen" status, confirm/cancel | P1 | Draw order is never revealed. Selection shows a "SELECTED" label and a border, not only color. |
| Tutorial | Callout bubble, pointer, step progress, skip/replay affordance | P1 | Never covers the active cells being taught. |
| Collection | Joker grid, discovery state, boss list, stats, run history | P2 | Good search/filter behavior if content grows. |
| Run result | Victory/defeat banner, seed, build summary, stats, share text action | P2 | Do not make score readout dependent on animated count-up. |
| Settings/pause | Input, audio, display, accessibility tabs; save/quit confirmation | P1/P2 | Keyboard operable and readable at 720p. |
| Focus/hover kit | Cursor states, focus rings, tooltips, disabled reasons, validation messages | P1 | Distinct mouse hover vs keyboard focus treatment. |
| Common icons | Approximately 30–40 | P1/P2 | Includes score, Chips, Mult, lines, combo, placement, Refresh, Credits, rarity, audio, display, accessibility, warning, info, back, close, inspect, lock, seed. |
| Typography | Display face, UI face, numerals; licenses | P1 | Original pairing; tabular numerals for scores and prices; support needed glyphs. |

### Suggested desktop layout exploration (future UI inspiration, not generated art)

1. **Cabinet view:** board centered in a lit frame, score column left, Joker rail right, three-shape tray below. Best baseline for 16:9.
2. **Workbench view:** board slightly left, shop/Joker elements appear as physical tokens in a right-hand workspace. Useful for tactile feel but must preserve board size.
3. **Minimal tournament view:** crisp board, thin HUD, restrained effects for clarity and accessibility.

The layout exploration above was realized as code-authored pixel art; see §12. The 2026-09-22 image-generator candidates were not adopted.

## 7. VFX and motion inventory

| Event | Assets / animation layers | Priority | Reduced-motion replacement |
|---|---|---|---|
| Shape pickup/return | Lift shadow, highlight, elastic settle | P1 | Short fade/outline. |
| Legal snap/invalid drop | Cell pulse, footprint outline, soft reject nudge | P0/P1 | Static border and text reason. |
| Placement | Tile scale, micro stagger, impact ring, small dust/spark particles | P1 | Instant tiles plus brief outline. |
| Single/multi-line clear | Traveling light strip, cell crack/dissolve, score stream, escalating layers | P1 | Simple line highlight then removal. |
| Combo and huge score | Numeral roll, brass flash, short chromatic fringe, optional camera nudge | P1/P2 | Static score update and badge. |
| Joker trigger | Ordered card pulse, semantic icon beam, contribution badge | P1 | Card border highlight and receipt entry. |
| Refresh | Tray wipe, new-shape reveal | P1 | Instant replacement with label. |
| Tray deal / Tray Hand *(produced)* | Slot-reel spin with staggered stops; Hand ribbon, chase lights, callout, themed particles | P1 | Pieces appear at once; badge and message stay. |
| Item tools *(produced)* | Board target overlay; eraser rub, hammer slam, bucket pour, paint splash, blueprint draft; thrown physics brick with trail, bounces, impact debris | P1 | Instant removal with text; the brick is placed by clicking a slot. |
| Feats, bosses, crate *(produced)* | Medal banners; Warden bars and shatter; Undertaker tomb rise; Boss Crate rattle and burst | P1/P2 | Still banner/text; no shake. |
| Boss reveal | Cabinet light sweep, badge sting, rule panel | P2 | Static boss panel. |
| Shop purchase/sell | Card glide, slot snap, Credits particle trail | P1 | Simple slot change and price update. |
| Win/defeat | Controlled screen treatment, confetti/glitch variant, transition | P1/P2 | Fade and clear result card. |
| Ambient retro layer | Optional grain, scanlines, tracking blip, light-bar sweep, subtle reflection | P1/P2 | Disabled entirely. |

**Effect budget:** no gameplay-critical text under post-processing; avoid full-screen effects during shape hover. Cap particles and simultaneous card animations. A single keypress should skip non-interactive sequences without skipping resolution or awards.

## 8. Audio inventory

| Family | Quantity target | Priority | Notes |
|---|---:|---|---|
| Music | 1 title loop, 3 act loops, 1 boss loop, 1 shop loop, 1 win/defeat cue | P1/P2 | Adaptive stems optional; loops cleanly. Original composition and rights documented. |
| Placement | 4 size/intensity classes × 3 variations | P1 | Avoid repetitive click fatigue. |
| Hover/select/UI | 12–18 distinct cues | P1 | Low-volume and non-irritating in rapid use. |
| Clears/combo | Single, double, triple+, combo escalation, target hit | P1 | Audio communicates success if visuals reduced. |
| Bag/pieces | Glass shatter, Gold coin, stamp trigger (4), Workshop apply, piece added/removed, reshuffle | P1/P2 | Shatter is a loss cue, so it must be distinct from a clear. |
| Joker/consumable | 3 rarity families + 6 semantic cues | P1/P2 | Layered under score cue, limited polyphony. |
| Shop/economy | Purchase, sell, reroll, insufficient Credits, reward | P1 | Crisp feedback with no casino-like monetization implication. |
| Boss/results | Reveal, danger, round win, boss win, run win, defeat | P2 | Strong but volume-controlled. |
| Ambience | Optional cabinet hum/room tone | P2 | Separate volume setting or folded into SFX. |

Deliver editable audio masters plus engine-ready exports, with a naming/version ledger, loop points, and license/source notes. Mix for repeated short events and test with music both on and off.

**2026-09-23 production status:** seven original, code-composed lo-fi tracks and 59 synthesized SFX are exported in `assets/audio/`. Editable source is in `tools/audio/`; IDs, formats, durations, and provenance are in `assets/audio/AUDIO_MANIFEST.md`. Playback and settings are implemented in `game/audio/audio.gd` and the Options/pause screen. Tracks play once with a short pause and are selected by screen context; they are not seamless loops. Human listening, speaker/headphone mix review, and any mastering changes remain open before calling the audio final.

## 9. Steam and external deliverables

Steamworks currently lists the following dimensions. **Recheck the live templates and rules immediately before upload** because platform requirements can change. Source: [Steamworks graphical assets overview](https://partner.steamgames.com/doc/store/assets), [store art details](https://partner.steamgames.com/doc/store/assets/standard), and [graphical asset rules](https://partner.steamgames.com/doc/store/assets/rules).

| Asset | Current required size | Priority | Creative requirement |
|---|---:|---|---|
| Store header capsule | 920×430 | P3 | Original key art and BLOCKMANIA logo. |
| Store small capsule | 462×174 | P3 | Logo readable at small scale. |
| Store main capsule | 1232×706 | P3 | Clear game identity. |
| Store vertical capsule | 748×896 | P3 | Composition for vertical crop. |
| Store screenshots | Minimum 1920×1080, 16:9 | P3 | Actual gameplay, no invented UI; show board, Jokers, shop, boss. |
| Library capsule | 600×900 | P3 | Logo included. Produced: `store/steam/library/library_capsule_english.png`. |
| Library hero | 3840×1240 PNG | P3 | Artwork only, no words. Produced: `store/steam/library/library_hero_english.png`. |
| Library logo | 1280 px wide and/or 720 px tall PNG | P3 | Transparent original logotype. Produced: `store/steam/library/library_logo_english.png` (1280×599). |
| Library header capsule | 920×430 | P3 | Logo and artwork. Produced: `store/steam/library/library_header_english.png`. |
| Shortcut icon | 256×256 ICO or PNG | P3 | Recognizable at desktop scale. |
| App icon | 184×184 JPG | P3 | Representative icon. |
| Page background | 1438×810, optional | P3 | Quiet enough for store content. |

Also plan for a trailer title/end card, social preview art, press kit logo and screenshots, and localized store text if those materials are produced. Base Steam capsules should contain only permitted game art, name, and official subtitle; do not add review scores or promotional copy to base capsules. Follow the current Steamworks review checklist when publishing.

## 10. Asset acceptance checklist

- Works at 720p and 1080p, with and without optional CRT/VHS treatment.
- Board cells, hover ghost, line preview, score, and current boss rule are readable in under two seconds.
- All gameplay-critical states have non-color cues and reduced-motion equivalents.
- All art and audio have source files, usage rights, consistent IDs, and export settings.
- No borrowed screenshots, logos, names, card designs, music, or recognizable trade dress from references.
- Steam screenshots and trailer footage match the shipping build.

## 11. Production order

1. Grayscale gameplay/shop/result wireframes and a block material test at 720p and 1080p.
2. One complete vertical-slice art set: board, six blocks, tray, HUD, eight Jokers, two bosses, core VFX/SFX.
3. Finish all content art and accessibility variants; tune effects against real gameplay.
4. Create final logo and Steam materials from the established in-game identity.

Begin full asset generation after the board layout, block material, and UI concept are chosen from vertical-slice exploration.

## 12. Implemented UI kit (2026-09-23)

Everything below is original, authored as code in this repository, and regenerated from source. No external images, fonts or VFX libraries are used.

| Deliverable | Source | Output | Status |
|---|---|---|---|
| App icon: chamfered plum tile, brass rim, a "B" of toy blocks in the logo colors; 32-px master at whole-number scales plus a hand-simplified 16 px | `tools/art/gen_icon.py` | `icon.png` (256, window/project icon), `icon.ico` (16-256, Windows exe) | In game and in the exe; prototype-final |
| Pixel UI kit: 7 block faces (6 colors + stone), empty cell, panels (plate, plain, sun, boss, inset, paper, tooltip), brass board frame, buttons in 5 colors × normal/hover/pressed + disabled, card and rack frames per rarity/type, pills, ~20 icons | `tools/art/gen_ui.py` (Pillow; drawn at 1× art pixels, exported 4× nearest) | `assets/ui/*.png`, `assets/ui/nine.json` (9-slice margins) | In game; prototype-final |
| "Blockhead" pixel typeface, regular + bold (Latin with the accents of es/fr/it/de/nl/pl/pt, digits, punctuation, « » „ and narrow no-break spaces) | `tools/art/gen_font.py` (fontTools) | `assets/fonts/blockhead*.ttf` | In game; em = 10 px, use sizes 20/30/40/60/80; accented capitals squeeze to 6 rows under a 2-row mark |
| CJK fallback glyphs for Japanese, Simplified and Traditional Chinese (Fusion Pixel 10 px subsets, metrics matched to Blockhead) | `tools/art/gen_cjk_fonts.py` (fontTools) | `assets/fonts/cjk_*.ttf` | In game (2026-09-25); third-party, OFL-1.1, see THIRD_PARTY.md; regenerate when CJK translations change |
| Swirl background (domain-warped fbm, polar swirl, Bayer-dithered 5-band posterize, moods: title/round/boss/shop, pulse on big scores) | `game/presentation/shaders/bg_swirl.gdshader` | runtime | In game; motion off under reduced motion |
| CRT post-process (warp, scanlines, aberration, glow, vignette, grain, roll bar, shock on big clears); Off / Soft (default) / Full | `game/presentation/shaders/crt.gdshader`, `BMCrtLayer` | runtime | In game; pointer input remapped through the warp |
| Particle VFX: pixel bursts, sparks, stars, confetti, coins, glass shards, homing score streams, pop text, screen shake (cap 900 particles) | `game/presentation/fx_layer.gd` | runtime | In game; reduced motion suppresses motion, keeps text |
| Chunky block logo with drop-in, bob and shine | `game/ui/title_screen.gd` | runtime | Placeholder logo until a final one is commissioned |
| Launch splash: the **Buru Arcade** studio logo builds itself: BURU drops in as toy block letters, the ARCADE marquee pops up with chasing bulbs, POPS rises from behind the sign and points at the logo, the last U's corner block pops off in a starburst (POPS cheers), "made with Godot" slides in, then every block bursts apart as the curtain fades to the title (about 2.4 s, skippable with any click/key; reduced motion fades only). Godot's boot image is off. Blockhead gained á é í ó ú ñ ü, their capitals, ¡ and ¿ | `game/ui/splash_screen.gd`, `tools/art/gen_font.py` | runtime | In game |
| Studio brand (Buru Arcade): horizontal logo with POPS pointing at BURU (4x, 8x, transparent), square mark (POPS over a BURU ARCADE banner), Steam creator page avatar 184×184 and header 1500×220 (sizes from the Steamworks creator homepage docs, 2026-09-24) | `tools/art/gen_studio_logo.py` → `assets/brand/` (`.gdignore`, not in the game build) | original, authored as code | Produced |
| Steam store description kit: localized banner, section headers, core-loop strip, Joker / finish / achievement panels (English, Spanish, Simplified Chinese), framed screenshots, gameplay and boss clips (MP4 + WEBM, 1280×720), 13 store screenshots 1920×1080 | `tools/store/capture.py` + `tools/store/build_store.py` → `store/steam/` | original, from the game's own captures and art; Chinese text drawn with Microsoft YaHei Bold (system font, license to confirm) | Produced (2026-09-25) |
| Refresh lever: brass gate, red-ball stick in five positions, pink CONCEDE and cold EMPTY housings (41×44 art px at 4×); lamps, labels and the R keycap drawn live | `tools/art/gen_lever.py` → `assets/ui/lever.png`, `game/ui/refresh_lever.gd` | original, authored as code | In game |
| Custom cursor: arrow, pressed arrow, POPS's glove (2 wiggle frames, pressed) and a fist; hardware cursors scaled per window, click/hover effects drawn live | `tools/art/gen_cursor.py` → `assets/ui/cursor_*.png`, `game/presentation/cursor.gd` | original, authored as code | In game (Options > Display) |
| Kit picker padlock (18×20 art px) for locked Kits | `tools/art/gen_ui.py` → `assets/ui/icon_padlock.png` | original, authored as code | In game |
| Veteran Joker portrait (a medal over a trained blue block) | `tools/art/cards_engine.py` | original, authored as code | In game |
| Logo easter egg: a clicked letter bursts into its spinning blocks and drops back in ~3 s later (`letter_pop` / `letter_back` sounds) | `game/ui/title_screen.gd`, `tools/audio/gen_sfx_features.py` | runtime | Cosmetic only; under reduced motion the blocks fade in place |
| Title menu icons: play, T-piece (New Run), trophy, power (plus gear and infinity) | `tools/art/gen_ui.py` | produced | Icon pinned left, label centered on every menu button |

Screens covered: title (+ Options), round HUD (score machine, marquee, receipt, Joker rack, items, tray, Refresh/Concede), round intro, round result, run end, pause, bag view, shop ("The Toybox") and Workshop picker. Checked at 1920×1080, 1280×720, 1680×1050 (16:10) and 2560×1080 (ultrawide).

## 12b. Overtime, achievements and the Trophy Case (2026-09-24)

All code-authored; no external media or generated-image art.

| Deliverable | Source | Status |
|---|---|---|
| Card portraits and achievement art (see §5) | `tools/art/gen_cards.py` → `assets/ui/cards/` | In game |
| Trophy Case screen: glass cabinet with reflections, wooden shelves, spotlights behind earned badges, completion meter, tier counts, page tabs, page slide, NEW tags, hover cards, records plaque | `game/ui/trophy_case.gd`, `game/ui/badge.gd` | In game; verified at 1920×1080 |
| Unlock toast: slide-in plate, coin-flip medal, tiered particles (ring/stars, sparks, confetti, full burst + swirl pulse + shake) | `game/ui/achievement_toast.gd` | In game; Reduced Motion fades only |
| Swirl moods `trophy` (gold on plum) and `overtime` (ember orange) | `game/presentation/swirl_background.gd` | In game |
| Overtime and machine-broken presentation: OVERTIME tags, compact M/B/T/Q numbers, KEEP PLAYING panel, MACHINE BROKEN! screen (crash sound, shake, burst, ring, title jitter) | `game/ui/game_screen.gd`, `shop_screen.gd` | In game |
| 12 sounds: `ach_bronze/silver/gold/legend/secret`, `trophy_open`, `page_flip`, `badge_hover`, `badge_locked`, `overtime`, `record_new`, `machine_break` | `tools/audio/gen_sfx_achievements.py` | In game; human listening pass open |

## 12c. Engine update and Legendary Jokers (2026-09-24)

All code-authored; no external media or generated-image art.

| Deliverable | Source | Status |
|---|---|---|
| 17 Joker portraits (13 new Jokers, 4 Legendaries), 4 item portraits (Turbo, Tune-Up, Coffee Break, Coin Roll), Rack Extender, 12 achievement icons for page 5 "Legends" | `tools/art/cards_engine.py` (merged by `gen_cards.py`) → `assets/ui/cards/` | In game |
| Legendary frames: `card_legendary`, `rack_legendary` (lilac rim, sun gem), `pill_lilac`; faster glint with twinkles on Legendary portraits | `tools/art/gen_ui.py`, `game/ui/card.gd` | In game; verified at 1920×1080 |
| Legendary callouts: LEGENDARY! pop text, lilac confetti, CRT shock on purchase or crate pick; reveal sting once per shop visit | `game/ui/shop_screen.gd` | In game |
| Avalanche chain waves (cells pop one beat per wave, AVALANCHE xN! callout, confetti, shake, wave lines in the receipt); TRANSMUTED label; Joker growth lines on the round result | `game/ui/board_view.gd`, `game/ui/game_screen.gd` | In game; since 12d the blocks visibly fall between waves |
| Compact Joker rack for 6–7 slots (64/48-px portraits) | `game/ui/card.gd` | In game; verified with 7 slots in round and shop |
| 2 sounds: `legendary_reveal`, `legendary_get` | `tools/audio/gen_sfx_achievements.py` | In game; human listening pass open |

## 12d. Boss spectacle, hard rounds, music and menus (2026-09-24)

All code-authored (shaders, procedural drawing, synthesized audio); no external media or generated-image art. GDD §22.

| Deliverable | Source | Status |
|---|---|---|
| Boss cinematic: letterbox bars with hazard tape, WARNING / MK II marching text, name slam with chromatic shadow, typed rule, stamped Mk II plate with sparks | `game/ui/boss_intro.gd` (`BMBossIntro`) | In game; verified at 1920×1080 (Mk II Warden) |
| Mood overlay shader: crawling hazard-tape frame and glow on boss rounds, heartbeat danger vignette, heat haze with embers, full-screen flash | `game/presentation/mood_layer.gd`, `shaders/mood.gdshader` | In game; boss frame and danger + heat verified in screenshots |
| Board chase bulbs on boss rounds (pink, sun for Mk II); swirl moods `boss_mk2`, `act2`, `act3`, `overtime` with their own speeds | `game/ui/board_view.gd`, `game/presentation/swirl_background.gd` | In game |
| Avalanche fall animation (gravity, squash, landing tick) | `game/ui/board_view.gd` | In game; verified mid-fall |
| Hold box, round-card picker overlay, milestone banner, NEW JOKER UNLOCKED toast, tip plates | `game/ui/game_screen.gd`, `shop_screen.gd`, `achievement_toast.gd`, `tip_plate.gd` | In game; verified in screenshots |
| Menus: reorganized title, Kit screen with Heat selector and seed, DAILY popup, RUN HISTORY with Joker portraits, tabbed Pause/Options with a round track | `game/ui/title_screen.gd`, `game/ui/settings_menu.gd` | In game; every page verified at 1920×1080 |
| 6 songs: Paper Lanterns, Pocket Change, Iron Curtain, Cascade, Overtime Rush, High Score | `tools/audio/gen_music.py` | In game; loudness checked, human listening pass open |
| 8 cues: `boss_alarm`, `boss_slam`, `mk2_stamp`, `heartbeat`, `danger_on`, `hold_store`, `round_pick`, `act_start` | `tools/audio/gen_sfx_bosses.py` | In game; human listening pass open |

## 12e. POPS, the tutorial helper (2026-09-24)

Original pixel art and synthesized audio authored as code, in the style of a character reference the owner supplied (not traced; drawn procedurally). GDD §23.

| Deliverable | Source | Status |
|---|---|---|
| POPS sprite sheet, 8 frames of 56×62 (idle, blink, talk ×2, point, point + talk, happy, happy + talk), drawn at 4× | `tools/art/gen_helper.py` → `assets/ui/helper.png` | In game; verified in E2E screenshots at 1920×1080 |
| White glove pointer, 4 directions of 16×16 | `tools/art/gen_helper.py` → `assets/ui/helper_pointer.png` | In game |
| Speech bubble, spotlight dim and marching outline | `game/ui/tutorial.gd` (code-drawn) | In game |
| Voice: 5 vowel blips (`pops_a`...`pops_u`), `pops_hi`, `pops_next`, `pops_bye` | `tools/audio/gen_sfx_helper.py` | In game; human listening pass open |

## 13. Endless arcade mode (2026-09-23)

The main menu has a code-drawn pixel infinity emblem on the Endless entry (with a game in progress it opens a Continue / New Game popup) and a local high-score view. Its cabinet reuses the original board, tray, block textures, clear waves, CRT option, particles, and existing SFX. The right rail now has a large Hold well with an occupied-shape drawing, recharge state, and drop highlight. The swirl shader has calm teal, tense rose, and celebratory multicolor moods; original tracks are grouped into matching playlists. At x5, a code-synthesized percussion layer joins the current track, with a stronger level at x8. High combos add capped drag trails, board pulse, larger score text, scoreward particles, confetti, and subtle shake. DOUBLE CLEAR, TRIPLE CLEAR, MEGA CLEAR, PERFECT, BLOCKSTORM, and CLEAN BOARD have prominent text feedback; an empty-board clear gets the largest celebration. Reduced motion retains score, Hold state, and callout text. The Endless screen and game-over card are code-built UI; no external media or generated-image art is used. Human comfort/listening review remains open.

**2026-09-23 addition:** the high-score popup was rebuilt with a reliable button layout, ten selectable score rows, a twelve-field run breakdown, and a code-drawn score chart. The No Room Left screen uses the same run breakdown and chart, with a result badge and replay/navigation actions. The right rail opens a 14-card finish picker: twelve available finishes and two unlockable animated looks (Aurora and Starfall). (Finish art superseded by the block finish redesign below.) A complete board clear changes the empty board rim, swirl colors, and music context until play continues. The picker, run details, and Fresh Board state need final human comfort and mix review at target hardware.

**2026-09-23 block finish redesign:** `tools/art/gen_finishes.py` replaces `gen_skins.py` and the material overlays. It authors 14 animated finish sheets (`assets/ui/finish_<id>.png`: frames x six colors x variants, 22x22 art px faces in 24 px cells, 4x nearest), four animated stamp strips (`stamp_<id>.png`, 12 px badges), the stepped glow halo (`block_glow.png`) and `finishes.json` (frames, fps, variants). Looks: Stained Glass (lead came, jewel panes, light sweep), Crystal (step cut, twinkles), Neon (tube on a black sign, rare flicker, strong glow), Gold (gilded plate, enamel jewel, rolling shine), Marble (clouds, a continuous colored vein, gloss sweep, 3 variants), Cyberpunk (chip, traces with data pulses, LED), Toy Wood (painted maple, carved ring, 2 variants, still), Candy (turning pinwheel), Lava (basalt plates, pulsing magma, 2 variants), Ice (frosted cube, bubbles, glints), Chrome (mirror with a colored horizon, racing glint), Prism (holographic foil, flowing rainbow), Aurora (curtains over mountains), Starfall (nebula, twinkles, shooting star, 2 variants). Campaign materials (Chrome, Neon, Gold, Glass, Prism) use the same faces. `BMFinishes` holds names, animation phasing (diagonal waves or per-cell beats with rest frames), glow and particle styles (shatter, zap, treasure, rubble, glitch, splinters, sprinkles, eruption, blizzard, sparks, rainbow, lights, cosmos). Sounds come from `tools/audio/gen_finish_sfx.py` (see the audio manifest). All code-authored; no generated-image art or external media.
