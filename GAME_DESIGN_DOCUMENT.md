# BLOCKMANIA — Game Design Document

**Version:** 0.2 — implementation started (M0 prototype) · **Date:** 2026-09-22 · **Platform:** Windows desktop at launch, Steam distribution · **Engine:** Godot 4.x stable at implementation start

## 1. Vision

### Elevator pitch

BLOCKMANIA combines an instantly readable 8×8 block placement puzzle with the run structure and buildcraft of a roguelike. Players place three offered shapes, complete rows and columns, and turn clears into score. Between rounds, they buy **Jokers** that change scoring, shape offerings, board behavior, and risk. Every run asks a simple question: *what can this board and this build do together?*

### Player promise

- Understand a legal placement in seconds and discover deeper strategy over many runs.
- Experience satisfying audiovisual feedback for every placement, clear, combo, purchase, and victory.
- Make meaningful build decisions without a timer or pay-to-win systems.
- Trust that all scoring and rule interactions are inspectable and deterministic.

### Design pillars

1. **Readable puzzle first.** Occupancy, legal placement, pending line clears, and active modifiers must remain legible even during dramatic effects.
2. **Wild combinations, clear rules.** Jokers may create powerful score explosions, but trigger order and score breakdowns are always visible.
3. **Fast choices, deep runs.** Drag a shape and play; study a shop and build synergies. Animation may celebrate but must not slow repeat play.
4. **Distinct identity.** The screenshots supplied with this brief establish the beveled colorful block puzzle reference. BLOCKMANIA uses original typography, iconography, UI composition, effects, sound, and marketing art. Balatro is a reference for tactile presentation and build excitement, not a visual or content template to copy.

### Audience and commercial framing

Single-player premium game for players who like approachable spatial puzzles, score chasing, and roguelike builds. No ads, microtransactions, lives, account requirement, or gameplay internet dependency. A run should take roughly 25–40 minutes after onboarding. Short sessions are supported by suspend/resume.

## 2. Assumptions and scope

The project owner confirmed a **fixed 12-round run**, three acts of four rounds, with boss rounds at 4, 8, and 12; **mouse-first input**; and **colorful toy blocks in a distinct arcade interface with cooler effects and a retro vibe**. Keyboard operation remains a usability and accessibility target; full controller support is deferred until the core mouse experience is proven. The original mobile screenshots inform board scale and block readability, not a mobile screen layout.

### Launch scope

- Standard Run, tutorial, Practice mode, settings, run history, unlock collection, and daily seeded challenge if Steam integration and QA permit.
- One standard 8×8 board; 24 Jokers, 8 consumables, 6 boss rules, 3 starting Kits, and 4 cosmetic board themes.
- Windows Steam launch, optimized for mouse, with functional keyboard controls, remappable inputs, scalable UI, reduced-motion and visual accessibility options. Full gamepad support is a stretch goal after the mouse-driven release candidate is stable.
- Original score-focused soundtrack and responsive sound design.

### Explicitly out of scope for initial release

Online multiplayer, leaderboards that require a backend, mobile ports, procedural art generation at runtime, paid DLC, and large narrative campaigns. Steam achievements and cloud save are desirable release features, but must not block offline play.

## 3. Core play at a glance

1. Enter a round with an empty 8×8 board, a target score, 12 placements, a three-shape tray, one free tray Refresh, and the current Jokers.
2. Select a tray shape and place it in any position where all its cells fit inside empty board cells. Shapes do not rotate in the standard rules.
3. Score the placement, clear every completed row and column simultaneously, apply Joker effects in the published order, and update the round total.
4. Keep placing until the target is reached. The round ends immediately after the complete scoring sequence that crosses the target. Remaining placements improve the payout.
5. Earn Credits, visit the shop, improve the build, then start the next round with a clean board.
6. Win after round 12. Lose when placements are spent below target, or when no legal placement or usable rescue action remains.

There is no falling gravity, timer, color matching, or manual board reset during a round. Colors mark shapes and effects, but occupied cells behave identically unless an effect explicitly changes them.

Standard mode has no Undo. Placement previews and cancel input must be reliable enough that a mistaken drop is uncommon; an invalid drop never consumes a shape or placement. Practice mode may offer Undo for experimentation, but such runs do not set records.

## 4. Board and shape rules

### Board

- Coordinates: columns A–H left to right, rows 1–8 top to bottom. All 64 cells begin empty each round.
- Placement is atomic. A shape is legal only if every occupied cell of its local footprint maps to an empty in-bounds board cell.
- After placement, detect full rows and columns from the same board state. Mark their union, score each completed line, then remove each cell in the union once. A crossing cell belongs to both scoring lines but is removed only once.
- No gravity follows a clear. Other cells stay where placed.
- Effects that create/remove cells resolve before or after line detection according to their trigger text; they never leave a partly resolved board visible to input.

### Shape tray

- Exactly three offered shapes are visible. Selecting and placing one removes only that offer. After all three have been placed, deal a new tray.
- A shape keeps its orientation. Hover/drag shows a ghost in legal cells, a distinct invalid footprint on failure, and the lines that would clear. Preview score is an estimate that includes all known deterministic effects.
- The baseline shape pool below has 12 geometric families. After choosing a family, choose uniformly among its distinct rotations; the resulting orientation is fixed once offered. Large shapes carry higher scoring potential and placement risk. Shape color is selected independently from six equally weighted colors, subject to no more than two identical colors in a fresh tray.

| Shape family | Cells | Draft draw weight | Availability |
|---|---:|---:|---|
| Single | 1 | 8% | All rounds |
| Bar 2 | 2 | 12% | All rounds |
| Bar 3 | 3 | 14% | All rounds |
| L 3 | 3 | 10% | All rounds |
| Square 2×2 | 4 | 10% | All rounds |
| Bar 4 | 4 | 10% | All rounds |
| L 4 | 4 | 9% | All rounds |
| T 4 | 4 | 8% | All rounds |
| Zigzag 4 | 4 | 8% | All rounds |
| Plus 5 | 5 | 5% | All rounds |
| Bar 5 | 5 | 4% | Round 3 onward |
| Square 3×3 | 9 | 2% | Round 3 onward |

Unavailable families are removed and remaining weights renormalized. The exact weights are tuning values to review after prototype playtests.
- Opening trays exclude 3×3 squares and 5-cell bars in rounds 1–2. The tutorial uses scripted offers.
- Each fresh tray must contain at least one legal offered shape at the time it is dealt. This guarantee does not prevent the player from creating a future dead end with later placements.
- Shape selection uses seeded weighted draws. Consecutive identical trays are disallowed. The generator records rejected draws for deterministic replays and debugging. Balancing should measure legal placement counts, early failures, and shape frequency rather than secretly rewriting the board.

### Refresh and failure

- Each round grants **one free Refresh**. Refresh replaces all unplaced tray shapes; it does not consume a placement or score points. It may be used voluntarily.
- A refreshed tray must also contain at least one legal shape when dealt. If there is no legal placement in the current tray and Refresh remains, present a clear Refresh prompt instead of ending the run.
- A round fails when (a) the target is unmet after all available placements are spent and no usable Extra Turn remains, or (b) no offered shape can legally fit and no usable rescue remains. A board rescue is an available Refresh, a ready **Tiny Insurance** Joker, or an owned consumable that can create a legal placement (Eraser, Second Tray, or Blueprint). If only a consumable can save the run, show the option and a **Concede Round** action; do not spend the consumable automatically. Boss rules can disable specific rescues.
- A player may abandon a run from the pause menu after a confirmation step; this records an abandoned run separately from a defeat.

### Important edge cases

- If a placement completes row and column simultaneously, both score, with one clear animation and one union removal.
- A target reached mid-resolution ends the round only after all triggered effects finish. Extra score counts toward run statistics but does not carry to the next round.
- If a Joker changes the board and causes a new complete line, it can trigger one additional clear wave. Clear waves are capped at five per placement; any unresolved full lines after the cap are cleared without retriggering Joker effects. This is a protective design cap, not intended to appear in ordinary play.
- A shape that is currently unplaceable stays in the tray until used or refreshed. When the tray is empty, refill automatically.

## 5. Score system

The interface shows **Chips × Mult = Points** for each placement, then adds Points to the round total. All rounding happens once, at the final Points step. Numerical values here are initial balance targets.

### Base scoring event

For each placement:

- **10 Chips per newly placed cell.**
- **100 Chips per completed row or column.**
- **40 extra Chips for each completed line beyond the first in the same wave.** This rewards multi-line setups without double-counting cells.
- **25 Chips per combo level** when at least one line clears. Combo level starts at 0, increases by 1 after a clearing placement, and caps at 4. A placement without a clear scores its cells, then resets the combo to 0.
- **Base Mult = 1.** Jokers and consumables modify Chips or Mult.

Example: a 4-cell shape completes two lines with combo level 1. Chips = 40 + 200 + 40 + 25 = 305 before Joker effects. With final Mult 2, the placement scores 610 Points.

### Modifier pipeline

All scoring modifiers resolve in this order so that previews, replays, and explanations agree:

1. Snapshot the placed shape, line count, cells cleared, combo, round state, and Joker order.
2. Apply pre-clear board effects explicitly labeled **Before Clear**. Re-evaluate completed lines.
3. Calculate base Chips for the current clear wave.
4. Apply additive Chips effects left to right in equipped Joker order.
5. Apply additive Mult effects left to right; the result cannot go below 1.
6. Apply multiplicative Mult effects left to right, then round down to two decimal places for display only.
7. Award `floor(max(0, Chips) × max(1, Mult))` Points using full internal precision.
8. Remove cleared cells, run **After Clear** effects, and process a new clear wave if one was created.
9. Update combo, target progress, counters, and run statistics.

Effects describe their trigger in plain language and show their contribution in an expandable score receipt. Duplicate Jokers can stack unless a card says **Unique**. Effects do not recursively retrigger themselves within the same placement. Reordering equipped Jokers is allowed outside a placement and can change outcomes.

### Round targets and budget

| Round | Act | Target Points | Special rule |
|---:|---|---:|---|
| 1 | 1 | 600 | Standard |
| 2 | 1 | 850 | Standard |
| 3 | 1 | 1,100 | Standard |
| 4 | 1 | 1,450 | Boss |
| 5 | 2 | 1,850 | Standard |
| 6 | 2 | 2,400 | Standard |
| 7 | 2 | 3,100 | Standard |
| 8 | 2 | 4,000 | Boss |
| 9 | 3 | 5,000 | Standard |
| 10 | 3 | 6,300 | Standard |
| 11 | 3 | 7,800 | Standard |
| 12 | 3 | 10,000 | Final boss |

Targets are tuning placeholders. Telemetry from local playtests should track median placements to win, loss reasons, shop purchases, and scores by build. The first three rounds should teach line clears before demanding large multipliers. Mid-run targets should make a directionally coherent build valuable; final rounds should demand synergies without relying on one overpowered Joker.

## 6. Run structure and economy

### Acts and bosses

Each act has three ordinary rounds and one boss. The upcoming boss is revealed at the beginning of its act so players can build toward it. A boss modifies a rule for one round. The title, exact rule, and affected UI are shown before the round and remain inspectable. Bosses are selected from the pool without repeating in one run; the final boss is drawn from the final-boss subset.

| Boss | Rule | Counterplay |
|---|---|---|
| **The Cramped Cabinet** | The round begins with four fixed occupied cells in a visible, seeded pattern. They can clear normally and score no placement Chips. | Favor small shapes or board-clearing tools. |
| **The Taxman** | The first line cleared by each placement grants 60 instead of 100 base Chips. Later lines retain full value. | Pursue double clears and flat Chip Jokers. |
| **The Color Blind** | Effects that name a block color are disabled for this round. Disabled cards stay equipped and are visibly dimmed. | Diversify beyond color-dependent scoring. |
| **The Echo Chamber** | The first clear wave from each placement scores normally; extra waves score half Chips before Jokers. | Prefer immediate clears over chained board effects. |
| **The Lockdown** | All tray-refresh actions, including the free Refresh and Second Tray, are unavailable this round. Eraser and Blueprint remain usable. | Plan tray order and preserve board space. |
| **The Last Call** | Final boss: only 10 placements; each multi-line placement gains +50 Chips. | Prepare efficient shapes and simultaneous clears. |

The same boss modifier must never silently make a Joker text false. Disabled or altered effects receive an explicit badge in the HUD and a reason in the tooltip.

### Credits and shop

- After a win: **3 Credits** base, **+1 Credit per two unused placements** (maximum +3), **+2 Credits for a boss**. No Credits are paid for losing.
- A shop appears after every won round except round 12. It contains three Joker offers and two consumable offers. Prices and descriptions are visible before purchase.
- Jokers cost 3/5/8 Credits for common/uncommon/rare. Consumables cost 3–5 Credits. The first shop reroll costs 2 Credits, then rises by 1 each reroll within that shop. Leaving resets the reroll price.
- Five Joker slots and two consumable slots. A purchase at capacity requires selling or using an item first; the UI never discards an item automatically.
- Selling a Joker returns half its printed cost, rounded up. Consumables cannot be sold. Credits carry through the run and are capped at 99.
- Shop rarity weights begin at 65% common, 30% uncommon, 5% rare, shifting toward 40/40/20 by Act 3. No duplicate unique Joker offer if already owned. Offer generation is deterministic from the run seed.

### Starting Kits

Kits are starting presets, not permanent power upgrades. Standard Kit is available immediately. Other Kits unlock through play; unlocked content broadens choices rather than raising global baseline power.

| Kit | Start effect | Unlock target |
|---|---|---|
| **Standard Kit** | 5 Joker slots, 1 Refresh, 12 placements. | Default |
| **Compact Kit** | Starts with 1 extra Refresh each round, but only 4 Joker slots. | Clear 100 total lines across runs. |
| **High Roller Kit** | Starts with 4 Credits and 11 placements per round. | Win a standard run. |

### Meta progression

The collection records discovered Jokers, bosses, consumables, best run, win count, and noteworthy scoring events. Unlocks may add new Kits, cosmetics, and Joker availability to future runs; no stat grind, currency purchase, or permanent score multiplier. If players want a fully open sandbox, Practice mode exposes all content and excludes records/achievements.

## 7. Joker content specification

Jokers are passive, visible, orderable modifiers. “This placement” refers to the current scoring event; “round” resets on board reset. Color-sensitive cards refer to the placed shape's assigned color, never to color matching on the board. Values and costs are provisional. Every card needs a tooltip with its trigger, current counter if any, and recent contribution.

| Rarity | Joker | Effect |
|---|---|---|
| Common | **Clean Sweep** | +50 Chips when exactly one line clears. |
| Common | **Crossbar** | +100 Chips when a row and column clear together. |
| Common | **Small Change** | +20 Chips per placed cell when placing a shape of 1–3 cells. |
| Common | **Heavy Hand** | +100 Chips when placing a shape of 5 or more cells. |
| Common | **First Strike** | First clearing placement each round gains +150 Chips. |
| Common | **Neat Freak** | +40 Chips if the placed shape touches no occupied cell diagonally before placement. |
| Common | **Corner Office** | +60 Chips if any placed cell occupies a board corner. |
| Common | **Blue Mood** | Blue shapes gain +1 additive Mult. |
| Common | **Chain Link** | +0.5 additive Mult per current combo level on clearing placements. |
| Common | **Spare Parts** | +1 Credit after a round won with at least three placements unused. |
| Common | **Tiny Insurance** | Once per round, when no offered shape fits and no tray Refresh is available, replace one unplaced shape with a single-cell piece before defeat is checked. |
| Common | **Second Look** | First Refresh each round additionally grants +1 placement. |
| Uncommon | **Wide Awake** | +2 additive Mult when two or more lines clear in a placement. |
| Uncommon | **Hollow Point** | +1.5 additive Mult when the board has at least 32 empty cells before placement. |
| Uncommon | **Pressure Cooker** | +0.5 additive Mult for every four occupied cells before placement, maximum +4. |
| Uncommon | **Golden Ratio** | Every third placed shape in a round gets ×1.5 Mult. Counter shown on card. |
| Uncommon | **Color Cycle** | When three consecutive placed shapes have different colors, the third gains ×2 Mult. Sequence shown on card. |
| Uncommon | **Patch Panel** | After the first clear each round, remove one extra occupied cell chosen by the player; this removal cannot itself clear a line. |
| Uncommon | **Long Game** | Gain +1 placement per round; first three placements of the round gain no cell Chips. |
| Uncommon | **Fire Sale** | Each Joker sold this run gives a permanent +0.25 additive Mult, maximum +2. Selling this card ends its bonus. |
| Rare | **Jackpot Window** | If exactly three lines clear in one placement, apply ×4 Mult. |
| Rare | **Mirror Maze** | The first row clear each round also clears the mirrored row if occupied; the mirrored removal grants 50 Chips but cannot chain. |
| Rare | **Compound Interest** | On every second clearing placement in a round, apply ×1.75 Mult. Counter resets each round. |
| Rare | **Last Stand** | When no Refresh and three or fewer placements remain, all scoring placements gain ×2 Mult. |

**Content review requirement:** before production, verify that every trigger can occur in the rules as written, every card has a detectable event, and no pair creates an unbounded scoring loop. “Tiny Insurance” is deliberately a utility common; if shop data shows it is never purchased, revisit its price or frequency rather than hiding essential input help behind a card.

### Consumables

Consumables are one-time, player-triggered tools. They may be used between placements, never during an animation. Unless stated otherwise, they do not score or trigger Joker scoring effects.

| Item | Cost | Effect |
|---|---:|---|
| **Polish** | 3 | Add +100 Chips to the next placement this round. |
| **Spark** | 3 | Add +1 Mult to the next placement this round. |
| **Eraser** | 4 | Remove up to two occupied cells chosen by the player. |
| **Second Tray** | 3 | Refresh the current tray without spending the round's free Refresh. |
| **Extra Turn** | 5 | Gain two placements this round, maximum 16 total. |
| **Lucky Paint** | 3 | Recolor one tray shape to a chosen color. Shape geometry unchanged. |
| **Blueprint** | 4 | Replace one tray shape with a chosen 1–3 cell shape from a limited preview list. |
| **Cash Out** | 3 | Gain 4 Credits after this round if won; otherwise no payout. |

## 8. Onboarding, modes, and UX

### First-run tutorial

An optional five-minute guided Standard Run opening teaches: select/place shape, legal vs invalid cells, complete a line, row+column simultaneous clear, Chips × Mult, target/placement budget, Refresh, first shop, Joker tooltip, and boss preview. Players can skip or replay it. Tutorial actions use fixed offers and target values so every explanation is reproducible. Never hide board cells behind tutorial text.

### Modes

- **Standard Run:** seeded 12-round run with unlocks and records.
- **Practice:** choose seed, Kit, bosses, and unlocked or all Jokers; no records or achievements. Useful for learning and QA.
- **Daily Challenge:** one shared seed and Kit per UTC day, with local completion record. If released, it must work offline after the seed has been computed locally; no online leaderboard required. This mode can move to post-launch if QA or Steam integration timing demands.

### Core screens

1. **Title:** Continue, New Run, Practice, Collection, Settings, Credits, Quit.
2. **Kit/seed selection:** clear Standard option; optional seed field and rules summary.
3. **Round intro:** target, placement budget, boss modifier, relevant disabled Jokers.
4. **Game board:** dominant board center; score/target and turns on left; five Joker slots and tooltips on right; tray and Refresh below; pause/settings accessible from upper corner.
5. **Scoring receipt:** compact popup near board plus expandable breakdown in side rail.
6. **Round result:** score, target, placements remaining, Credits earned, a few notable events; one button to shop.
7. **Shop:** five offers, owned Jokers, sell/reorder affordances, Credits, reroll price, next boss preview, leave shop.
8. **Run end:** victory/defeat reason, seed, score, highest combo, build snapshot, shareable text summary, replay/new run.
9. **Collection/settings:** discovery, rules glossary, input/audio/video/accessibility.

### Desktop composition and input

- Design for 1920×1080 at 16:9; remain fully usable at 1280×720 and common 16:10/ultrawide layouts. Preserve board square and move side panels rather than stretching cells. UI scale 75–150%.
- Mouse: click a tray shape then move/click a legal board anchor, or drag and release. Right-click/Escape cancels. A failed drop returns the shape to tray with an explanation, not a consumed turn.
- Keyboard: number keys 1–3 select a tray slot; arrow/WASD moves the shape anchor; Enter/Space places; R Refresh; Tab cycles focusable HUD elements; Escape pauses/cancels. Keys are remappable.
- Gamepad (post-core/stretch): shoulder buttons cycle tray slots, left stick/D-pad moves anchor, confirm places, cancel returns, shoulder shortcut opens Joker inspect, menu pauses. If advertised as controller-compatible on Steam, the entire run must be completable without a mouse.
- Hover: selected shape lifts, tilts subtly, shadow deepens; a valid ghost snaps to cells and prospective clears pulse. Invalid hover uses shape outline/pattern as well as color.
- Tooltips are available on hover and focus, with short text first and an expandable exact rule. Inspect mode freezes incidental motion while open.

### Accessibility

Options: reduced motion; screen shake off; CRT/VHS overlays off; bloom intensity; high-contrast grid; distinct patterns/shapes for colored blocks; UI and text scaling; colorblind-friendly palette presets; remappable keyboard input; independent music/SFX/UI volume; hold-to-confirm for destructive shop actions; optional slower tooltip dismissal. Every essential status has text or icon, never color alone. Important effect animation can be skipped or sped up without changing outcome. Aim for full keyboard operation and readable text at 720p; add controller remapping when controller support is production-ready.

## 9. Visual, motion, and audio direction

### Art direction

The supplied images show a vivid block puzzle with beveled toy-like cells, a dark blue grid, and three clear shape offers. Preserve that immediate readability, then give BLOCKMANIA its own **after-hours arcade workbench** identity: smoked charcoal and midnight-teal surfaces, saturated candy-enamel blocks, electric cyan and hot coral accents, warm brass score flashes, and original geometric type. The retro vibe comes from moving light bars, cabinet reflections, glitch slices at milestones, and subtle analog noise; the board itself remains clear. Avoid the screenshot's crown, logo, exact gradients, and mobile framing. Avoid reproducing Balatro's specific card art, UI arrangement, typography, or effect stack.

The board and score should remain visually crisp. Analog character lives mainly in the background, side rails, menus, transitions, and optional post-processing. A restrained CRT scanline, chromatic fringe, film grain, and slight VHS tracking during key moments can create energy without blurring the grid. At default settings, text and placement previews should be sharp. Effects can be independently disabled.

### Motion language

| Event | Target duration | Motion and feedback |
|---|---:|---|
| Hover/focus | 80–120 ms | Lift/scale 1.03, soft glow, focused sound tick. |
| Pick up shape | 100–150 ms | Shape rises from tray, shadow follows cursor, tray placeholder remains. |
| Valid snap | <80 ms | Grid cell pulse and magnetic alignment. |
| Place | 140–220 ms | Cell stamp with stagger under 25 ms, short impact and restrained shake. |
| Line clear | 250–450 ms | Charge along line, flash, cells fracture/dissolve into score stream. |
| Multi-line/large score | 350–700 ms | Layered bloom, brief chromatic split, score numerals roll up, audio chord. |
| Joker trigger | 120–250 ms each | Card glows/bounces in resolution order; capped combined sequence. |
| Shop purchase | 200–350 ms | Card glides into slot, Credits count down, confirmation chime. |
| Round win/boss win | 0.8–1.5 s | Strong celebratory sequence with skip input. |

Hover effects should be responsive at 60 fps. Score processing may be visually staged but underlying game state resolves atomically before another placement. Offer a **Fast Animations** toggle and ensure reduced motion replaces camera movement and flicker with fades and static highlights. Avoid prolonged forced waiting between placements.

### Audio direction

An original upbeat electronic soundtrack with a playful arcade pulse, evolving harmonically across acts. Adaptive layers rise with combo and target proximity; music never masks placement/clear cues. SFX families: pickup, legal/invalid hover, placement by block size, single/double/triple line clear, combo, Joker rarity/trigger, Credits, shop purchase/reroll/sell, boss warning, round win, defeat, menus. Audio cues should communicate outcomes even when effects are reduced. Target consistent loudness and no sudden full-scale spikes.

## 10. Godot implementation guidance (design-level)

This section defines system boundaries, not code. Use the latest stable Godot 4.x supported by the team when implementation begins; record the pinned version in the repository. Prefer GDScript for a small, readable project unless profiling or platform needs justify otherwise.

- **Pure rules layer:** board occupancy, shape fit, line detection, score events, target/failure checks, and seeded generation should not depend on visual nodes. One placement command produces an immutable resolution record consumed by presentation.
- **Data-driven content:** shapes, Jokers, consumables, bosses, Kits, shop weights, targets, and localization text use versioned resources or structured data. Each effect has a stable ID and explicit trigger phase.
- **Run state:** seed, RNG stream state, board, tray, round number, remaining placements/Refresh, Credits, owned content/order, counters, and settings. Save between atomic actions and on pause; do not save half an animation.
- **Presentation layer:** board view, ghosts, effects, HUD, tooltip/receipt, shop, menus. Animation timing must never determine rules. A skip or speed setting changes presentation only.
- **Input layer:** semantic actions shared by mouse and keyboard, with an extension path for controller. Focus and target cell are explicit UI state.
- **Persistence:** versioned saves with migration strategy and recovery from corruption; separate settings and run data. No personal data or online requirement.
- **Performance target:** stable 60 fps at 1080p on a modest desktop GPU, responsive input under 100 ms, quick cold start. Profile particles and post-processing; cap simultaneous effects. Support windowed, borderless, and fullscreen modes.

### Determinism and QA

Given the same content version, seed, Kit, purchases, and player actions, a run must produce the same offers and scores. Keep separate seeded streams for shape draws, shop offers, and bosses so UI activity cannot change gameplay draws. Log a compact event history for reproducing bugs. Automated rule tests should cover fit/overlap, crossing clears, score order, Joker stacking, target timing, shape generator guarantees, Refresh, save/resume, and boss interactions. Manual QA must cover all input modes, UI scales, reduced motion, long numbers, window resizing, and performance during stacked effects.

## 11. Steam release considerations

- Ship an offline-first Windows build with correct executable naming, icon, version, crash reporting/log location, Steam overlay compatibility, and clean quit/suspend behavior.
- Prepare a store page with original capsule/library art, honest gameplay screenshots, trailer, clear feature description, system requirements, age/content disclosure as applicable, and language list that matches actual localization.
- Verify current Steamworks release checklists, store art templates, and review requirements when preparing the store page; these can change. The asset document records the currently published required dimensions and source links.
- Achievements should reward variety, mastery, and first wins rather than repetitive grind. Suggested set: first line clear, first double clear, first boss, first run win, win with each Kit, clear three lines at once, win without Refresh, buy five different Jokers in one run.
- If Cloud Save is used, keep local saves authoritative during offline play and test conflicts between machines. Never require Steam API initialization for base gameplay.

## 12. Milestones and acceptance criteria

| Milestone | Deliverable | Exit criterion |
|---|---|---|
| **M0: Rules prototype** | 8×8 board, tray, line clears, target/failure, seeded runs, score receipt in placeholder UI. | Ten complete seeded runs can be reproduced and all base-rule edge cases pass. |
| **M1: Vertical slice** | One full four-round act, 8 Jokers, 2 consumables, 2 bosses, first shop, polished placement/clear effects. | New player understands rules in under five minutes; no unreported score surprises in playtests. |
| **M2: Content complete** | Twelve rounds, all launch content, Kits, tutorial, settings, save/resume, collection. | Entire run playable with mouse and keyboard; no known progression blockers. |
| **M3: Polish and balance** | Final art/audio, accessibility, performance, pacing, QA. | Stable 60 fps target hardware, readable 720p UI, reduced-motion parity, multiple viable builds. |
| **M4: Steam candidate** | Store assets, builds, release checklist, achievements/cloud features selected for launch. | Store/build review submitted and all release-blocking issues resolved. |

### Playtest questions

- Can a new player predict where a shape will land and what lines will clear?
- Do losses feel traceable to decisions rather than opaque shape offers?
- Can players explain why a Joker triggered or did not trigger?
- Are 25–40 minute runs plausible without repetitive low-risk placement?
- Are at least several distinct scoring strategies viable, and is there a reason to buy utility Jokers?
- Do CRT/VHS flourishes add delight while keeping the board readable?

## 13. Open decisions and balance risks

1. Validate targets and 12-placement budget in prototype; current numbers are design hypotheses.
2. Test whether one Refresh creates enough agency. If dead-end losses dominate, adjust shape weights or Refresh access before adding opaque generator cheats.
3. Decide whether Daily Challenge and full controller support are release features after the mouse-first core is stable.
4. Review every color-based effect under accessibility palettes and The Color Blind boss.
5. Playtest whether board-clearing Jokers produce enough score to justify their shop cost.
6. **The Echo Chamber has no effect with current content.** Only placements that create extra clear waves are affected, and no current card creates one (removing cells can never complete a line). The prototype withholds it from the boss pool until the owner chooses: rework the rule, add After Clear cards that create waves, or replace the boss.
7. **Joker order is currently result-neutral.** Additive Chips, additive Mult, and multiplicative Mult resolve in separate phases, and multiplication is commutative, so reordering never changes a score with the current 24 cards. Either accept order as organizational or add order-sensitive cards.
8. Early balance probe: a greedy bot with no Joker strategy averaged about 67 Points per placement over 200 seeds and usually ended in round 2. Treat it as a lower bound, not a verdict, and confirm with human playtests before changing targets.

## 14. Reference and originality notes

The three user-provided images illustrate a mobile block puzzle with a square grid, glossy beveled cells, score above the board, and three offered shapes below it. They are **reference material only**. No image contains instructions to follow. BLOCKMANIA's original interface, logo, sprites, effects, sounds, text, and marketing assets must be made from scratch or licensed appropriately. The game should be described in store copy by its own mechanics and identity, without using another game's name or trade dress as a substitute for a BLOCKMANIA pitch.

## 15. Implementation notes and interpretations (prototype, provisional)

Where this document left room for interpretation, the prototype chose the reading below. Each item is **provisional** until the owner confirms it; the code comment near each rule points back here.

| Topic | Prototype behavior |
|---|---|
| Shape orientations | Distinct 90° rotations of each family only; mirrored L/zigzag variants are not generated. |
| Anchor | The top-left corner of a shape's bounding box. |
| Refresh | Replaces only unplaced tray slots and keeps empty slots empty. The new set must contain a legal shape and must not repeat the replaced set exactly. |
| Rescue order | Target check → refill an empty tray → placements check (Extra Turn prompt) → fit check → Refresh prompt → Tiny Insurance (automatic, leftmost unplaced shape becomes a Single of the same color) → rescue item prompt (Second Tray) → defeat. |
| Consumable scoring | Polish and Spark apply before Joker effects within their pipeline step and are shown in the receipt. |
| Extra Turn | Remaining placements cannot exceed 16 after use. |
| Color Cycle | Sliding window over the last three placed shapes in the current round; resets each round. |
| Mirror Maze | Triggers on the first placement each round that clears any row. Uses the lowest-index cleared row; its mirror is row `7 − r`. Occupied cells in the mirror row that are not already clearing are removed in the same step for +50 Chips. Copies stack Chips, not removals. |
| Last Stand | Checked before the placement: no Refresh available and 3 or fewer placements left, counting the current one. |
| Chain Link | Uses the combo level shown before the placement (the same level that gives combo Chips). |
| Fire Sale | Counts every Joker sold this run, including sales made before Fire Sale was bought. |
| Shop reroll | Refills all three Joker and both item offers, including slots already bought. |
| Shop rarity by act | Uses the act of the next round: 65/30/5, 53/35/12, then 40/40/20. |
| Selling and reordering | Allowed in the shop and between placements during a round. |
| Standard Kit | Starts with 0 Credits (High Roller starts with 4). |
| Withheld content | Patch Panel, Eraser, Lucky Paint, and Blueprint need target-picking UI and are not offered yet. The Echo Chamber is withheld (§13 item 6). |
