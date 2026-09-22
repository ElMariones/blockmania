# BLOCKMANIA — Asset Plan and Art Brief

**Version:** 0.2 · **Status:** art generation started 2026-09-22. Generated source candidates are cataloged in [assets/ASSET_MANIFEST.md](assets/ASSET_MANIFEST.md); none has been integrated or approved as final. The M0 prototype still uses procedural placeholders drawn in code. · **Companion:** [GAME_DESIGN_DOCUMENT.md](GAME_DESIGN_DOCUMENT.md)

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
- **Localization:** keep text live in Godot UI, not baked into art, except the BLOCKMANIA logo and approved Steam art. Provide enough room for longer translations.
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
| `kit_badge` | 3 | Standard, Compact, High Roller selection emblems | P2 | Clear starting tradeoff in adjacent live text. |
| `collection_unknown` | 1 | Undiscovered silhouette/card treatment | P2 | No gameplay information leak beyond desired unlock presentation. |

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

The owner has authorized cozy pixel-art asset generation. The current source candidates cover a style reference, one Joker frame, six block colors, one button, two Joker illustrations, and one illustration each for a boss, consumable, and Workshop tool. Grayscale wireframes at 1920×1080 and 1280×720 are still needed to validate composition before UI integration. See the [visual asset manifest](assets/ASSET_MANIFEST.md) for files, IDs, and status.

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

## 9. Steam and external deliverables

Steamworks currently lists the following dimensions. **Recheck the live templates and rules immediately before upload** because platform requirements can change. Source: [Steamworks graphical assets overview](https://partner.steamgames.com/doc/store/assets), [store art details](https://partner.steamgames.com/doc/store/assets/standard), and [graphical asset rules](https://partner.steamgames.com/doc/store/assets/rules).

| Asset | Current required size | Priority | Creative requirement |
|---|---:|---|---|
| Store header capsule | 920×430 | P3 | Original key art and BLOCKMANIA logo. |
| Store small capsule | 462×174 | P3 | Logo readable at small scale. |
| Store main capsule | 1232×706 | P3 | Clear game identity. |
| Store vertical capsule | 748×896 | P3 | Composition for vertical crop. |
| Store screenshots | Minimum 1920×1080, 16:9 | P3 | Actual gameplay, no invented UI; show board, Jokers, shop, boss. |
| Library capsule | 600×900 | P3 | Logo included. |
| Library hero | 3840×1240 PNG | P3 | Artwork only, no words. |
| Library logo | 1280 px wide and/or 720 px tall PNG | P3 | Transparent original logotype. |
| Library header capsule | 920×430 | P3 | Logo and artwork. |
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
