# BLOCKMANIA — Game Design Document

**Version:** 0.5 — round-play update implemented (§18): Tray Hands, targeted items and the Emergency Brick, Feats, 52 Jokers, Warden/Undertaker, Kit bags, Boss Crate, combo grace · **Date:** 2026-09-22 · **Platform:** Windows desktop at launch, Steam distribution · **Engine:** Godot 4.x stable at implementation start

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

1. Enter a round with an empty 8×8 board, a target score, 15 placements (every cleared line gives one back, up to that starting count; §5), a three-piece tray dealt from **your bag of pieces** (§16), one free tray Refresh, and the current Jokers.
2. Select a tray shape and place it in any position where all its cells fit inside empty board cells. Shapes do not rotate in the standard rules.
3. Score the placement, clear every completed row and column simultaneously, apply Joker effects in the published order, and update the round total.
4. Keep placing until the target is reached. The round ends immediately after the complete scoring sequence that crosses the target. Remaining placements improve the payout.
5. Earn Credits, visit the shop, improve the build (Jokers, items, and bag edits: upgrade, copy, remove, or add pieces), then start the next round with a clean board.
6. Win after round 12. Lose when placements are spent below target (a clear on the last placement refills it, so the round continues), or when no legal placement or usable rescue action remains.

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
- **Superseded by the Bag (§16):** trays are now dealt from the player's own bag of persistent pieces. The table below still defines the 12 families, and its weights (+4 each) now only drive which pieces the shop offers for sale. Large shapes carry higher scoring potential and placement risk.

| Shape family | Cells | Shop offer weight (before +4) | In starter bag |
|---|---:|---:|---|
| Single | 1 | 8% | 2 |
| Bar 2 | 2 | 12% | 3 |
| Bar 3 | 3 | 14% | 4 |
| L 3 | 3 | 10% | 4 |
| Square 2×2 | 4 | 10% | 2 |
| Bar 4 | 4 | 10% | 2 |
| L 4 | 4 | 9% | 2 |
| T 4 | 4 | 8% | 2 |
| Zigzag 4 | 4 | 8% | 2 |
| Plus 5 | 5 | 5% | 1 |
| Bar 5 | 5 | 4% | 0 (buy in shop) |
| Square 3×3 | 9 | 2% | 0 (buy in shop) |

The exact weights are tuning values to review after prototype playtests. The tutorial uses scripted offers.
- Each fresh tray must contain at least one legal offered piece at the time it is dealt (method in §16.2). This guarantee does not prevent the player from creating a future dead end with later placements.
- Dealing uses the seeded shape stream. Balancing should measure legal placement counts, early failures, and rescued deals rather than secretly rewriting the board.

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
- **25 Chips per combo level** when at least one line clears. Combo level starts at 0, increases by 1 after a clearing placement, and caps at 4. *Combo grace (2026-09-23):* the combo survives **one** placement without a clear (shown as "x3!" and "HANG ON!"); a second non-clearing placement in a row resets it to 0.
- **Base Mult = 1, +1 for each line beyond the first** in the same placement (engine update, 2026-09-24: a double clear scores at x2 base Mult, a triple at x3). Jokers and consumables modify Chips or Mult.

Example: a 4-cell shape completes two lines with combo level 1. Chips = 40 + 200 + 40 + 25 = 305 before Joker effects. Mult = 1 + 1 (second line) = 2; with a Spark (+1) it is 3 and the placement scores 915 Points.

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

### Placements and refills

*Revised 2026-09-23 (owner: "12 placements is too short and leaves no room to maneuver"). Evidence and alternatives: [docs/design/round_play_update.md](docs/design/round_play_update.md) §1.*

- A round starts with the Kit's placements (Standard 15), plus Long Game. That number is the round's **refill cap**.
- Each placement spends one. **Each line cleared gives one back** (a double clear gives two), never above the refill cap. The refill happens at pipeline step 9, before the round checks for running out, so a clearing last placement keeps the round alive.
- Other gains can exceed the cap: Extra Turn (up to 20), Second Look, and the Refund stamp.
- The score preview shows the refill because it runs the same resolver. The HUD shows placements left out of the cap, and refilled bulbs flash.
- Why it replaces the fixed 12: with 12, every simulated loss was "out of placements" and the bot needed 9–11 placements just to pass early rounds, so setting up multi-line clears was never affordable. A refill rewards clearing and pays back setup turns without removing the budget's tension.

### Round targets and budget

| Round | Act | Target Points | Special rule |
|---:|---|---:|---|
| 1 | 1 | 450 | Standard |
| 2 | 1 | 650 | Standard |
| 3 | 1 | 900 | Standard |
| 4 | 1 | 1,200 | Boss |
| 5 | 2 | 1,800 | Standard |
| 6 | 2 | 2,400 | Standard |
| 7 | 2 | 3,300 | Standard |
| 8 | 2 | 4,400 | Boss |
| 9 | 3 | 5,700 | Standard |
| 10 | 3 | 7,300 | Standard |
| 11 | 3 | 9,300 | Standard |
| 12 | 3 | 12,500 | Final boss |

*Revised 2026-09-24 with the engine update (§21): rounds 3-12 raised about 25% because interest, scaling Jokers and multi-line Mult make builds grow; the greedy balance bot went 10% → 37% wins before the raise and 18% after, the planner persona 82% → see docs/playtests/2026-09-24_persona_playtest.md §6. Previous values: 450 / 650 / 850 / 1,150 / 1,600 / 2,100 / 2,800 / 3,700 / 4,700 / 6,000 / 7,500 / 10,000.* *Revised 2026-09-23 from simulation (§16.9). The original draft was 600 / 850 / 1,100 / 1,450 / 1,850 / 2,400 / 3,100 / 4,000 / 5,000 / 6,300 / 7,800 / 10,000; its first rounds were steeper than its later ones.*

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
| **The Warden** | One tray slot starts barred: its piece can't be placed, refreshed, or bricked until the first line clear of the round. Deals and the legality guarantee skip the barred slot. | Open with a quick clear from the other two slots. |
| **The Undertaker** | After every 4th placement (not the winning one), a stone tombstone rises on a seeded empty cell that would not complete a line. It clears with its line like any block. | Clear often; keep lanes open. |
| **The Last Call** | Final boss: only 12 placements (refills capped at 12); each multi-line placement gains +50 Chips. *(was 10 of 12 before refills)* | Prepare efficient shapes and simultaneous clears. |

The same boss modifier must never silently make a Joker text false. Disabled or altered effects receive an explicit badge in the HUD and a reason in the tooltip.

### Credits and shop

- After a win: **3 Credits** base, **+1 Credit per two unused placements** (maximum +3), **+2 Credits for a boss**. No Credits are paid for losing.
- A shop appears after every won round except round 12. It contains three Joker offers, two consumable offers, two Workshop cards (bag edits), and two pieces for the bag (§16.4–16.5). Prices and descriptions are visible before purchase. Reroll replaces every offer.
- Jokers cost 3/5/8 Credits for common/uncommon/rare. Consumables cost 3–5 Credits. The first shop reroll costs 2 Credits, then rises by 1 each reroll within that shop. Leaving resets the reroll price.
- Five Joker slots and two consumable slots. A purchase at capacity requires selling or using an item first; the UI never discards an item automatically.
- Selling a Joker returns half its printed cost, rounded up. Consumables cannot be sold. Credits carry through the run and are capped at 99.
- Shop rarity weights begin at 65% common, 30% uncommon, 5% rare, shifting toward 40/40/20 by Act 3. No duplicate unique Joker offer if already owned. Offer generation is deterministic from the run seed.

### Starting Kits

Kits are starting presets, not permanent power upgrades. Standard Kit is available immediately. Other Kits unlock through play; unlocked content broadens choices rather than raising global baseline power.

| Kit | Start effect | Unlock target |
|---|---|---|
| Kit | Start effect | Signature perk (2026-09-24) | Unlock target |
|---|---|---|---|
| **Standard Kit** | 5 Joker slots, 1 Refresh, 15 placements; the 24-piece bag. | *Classic:* no twist. | Default |
| **Compact Kit** | 4 Joker slots, 2 Refreshes, 16 placements; an 18-piece bag of small pieces only (2 Singles, 4 Bar 2, 3 Bar 3, 5 L 3, 2 Square 2×2, 2 Bar 4). | *Thrift:* +1 Credit for every Refresh left unused when a round is won. | Clear 100 total lines across runs. |
| **High Roller Kit** | 5 slots, 1 Refresh, 14 placements, 4 starting Credits; the standard bag. | *Compound Interest:* the interest cap is 3 higher (+8, or +6 at Heat 3+). | Win a standard run. |
| **Chunky Kit** | 5 slots, 1 Refresh, **13** placements; a 19-piece bag of big shapes (4 Square 2×2, 3 T 4, 2 Plus 5, 3 L 4, a Bar 5, a Square 3×3, 2 Bar 4, 3 Bar 3). | *Heavy Lifting:* a placed piece of 5+ blocks scores +10 Chips per block (step 3). A first draft gave 2 placements back per line; rejected because a round could then last forever (with Veteran, unbounded). | Defeat 3 bosses across runs. |
| **Tetromino Kit** | 5 slots, 1 Refresh, 14 placements; 20 four-block pieces only. | *Full House:* +1 Credit every time a Tray Hand forms. | Form 25 Tray Hands across runs. |

*Kit picker (2026-09-24): an unlocked Kit shows its numbers, perk, bag and text. A **locked Kit hides its contents** (question marks for its numbers and bag, a big padlock that rattles when pointed at): only its name, the unlock requirement and the progress bar show.*

*Kits own their starter bags (2026-09-23): Standard and High Roller use the 24-piece bag; Compact uses an 18-piece bag without Singles. A Kit picker opens from New Run; lifetime counters (lines, standard wins, bosses, Tray Hands) live in `user://profile.cfg`, separate from runs and settings.*

### Meta progression

The collection records discovered Jokers, bosses, consumables, best run, win count, and noteworthy scoring events. Unlocks may add new Kits, cosmetics, and Joker availability to future runs; no stat grind, currency purchase, or permanent score multiplier. If players want a fully open sandbox, Practice mode exposes all content and excludes records/achievements.

*Practice seeds (owner, 2026-09-24):* a campaign run started on a seed the player chose (typed on the Kit screen, PLAY THIS SEED from the run history, SAME SEED on the game-over screen) is **practice**: it is saved and listed in the run history, but it earns no achievements, records, lifetime profile counters, Kit or Heat unlocks. The Daily and random-seed runs count as before. The mark is saved with the run (`custom_seed`, save schema 8), shown in the pause menu ("PRACTICE SEED") and on the run-end summary.

## 7. Joker content specification

Jokers are passive, visible, orderable modifiers. The table below is the original 24; §16.6 adds 14 bag-era Jokers (38 total). “This placement” refers to the current scoring event; “round” resets on board reset. Color-sensitive cards refer to the placed shape's assigned color, never to color matching on the board. Values and costs are provisional. Every card needs a tooltip with its trigger, current counter if any, and recent contribution.

| Rarity | Joker | Effect |
|---|---|---|
| Common | **Clean Sweep** | +50 Chips when exactly one line clears. |
| Common | **Crossbar** | +150 Chips when a row and column clear together. *(was +100; tuned §16.9)* |
| Common | **Small Change** | +15 Chips per placed cell when placing a shape of 1–3 cells. *(was +20)* |
| Common | **Heavy Hand** | +100 Chips when placing a shape of 5 or more cells. |
| Common | **First Strike** | First clearing placement each round gains +150 Chips. |
| Common | **Neat Freak** | +40 Chips if the placed shape touches no occupied cell diagonally before placement. |
| Common | **Corner Office** | +60 Chips if any placed cell occupies a board corner. |
| Common | **Blue Mood** | Blue shapes gain +2 additive Mult. *(was +1)* |
| Common | **Chain Link** | +1 additive Mult per current combo level on clearing placements. *(was +0.5)* |
| Common | **Spare Parts** | +2 Credits after a round won with at least two placements unused. *(was +1 with three)* |
| Common | **Tiny Insurance** | Once per round, when no offered shape fits and no tray Refresh is available, replace one unplaced shape with a single-cell piece before defeat is checked. |
| Common | **Second Look** | First Refresh each round additionally grants +1 placement. |
| Uncommon | **Wide Awake** | +3 additive Mult when two or more lines clear in a placement. *(was +2)* |
| Uncommon | **Hollow Point** | +0.5 additive Mult when the board has at least 44 empty cells before placement. *(was +1.5 at 32)* |
| Uncommon | **Pressure Cooker** | +0.5 additive Mult for every eight occupied cells before placement, maximum +2. *(was every four, max +4)* |
| Uncommon | **Golden Ratio** | Every third placed shape in a round gets ×1.5 Mult. Counter shown on card. |
| Uncommon | **Color Cycle** | When three consecutive placed shapes have different colors, the third gains ×1.75 Mult. Sequence shown on card. *(was ×2)* |
| Uncommon | **Patch Panel** | After the first clear each round, remove one extra occupied cell chosen by the player; this removal cannot itself clear a line. |
| Uncommon | **Long Game** | Gain +1 placement per round; the first placement of the round gains no cell Chips. *(was first three)* |
| Uncommon | **Fire Sale** | Each Joker sold this run gives a permanent +0.25 additive Mult, maximum +2. Selling this card ends its bonus. |
| Rare | **Jackpot Window** | If three or more lines clear in one placement, apply ×4 Mult. *(was exactly three)* |
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
| **Eraser** | 4 | Remove up to two blocks chosen by the player. |
| **Second Tray** | 3 | Refresh the current tray without spending the round's free Refresh. |
| **Extra Turn** | 5 | Gain two placements this round, maximum 20 total. |
| **Lucky Paint** | 3 | Recolor one tray piece to a chosen color. Shape unchanged; the bag piece is not repainted. |
| **Blueprint** | 4 | Swap one tray piece (it goes to the discard pile) for a temporary 1–3 cell piece chosen from nine. |
| **Cash Out** | 3 | Gain 4 Credits after this round if won; otherwise no payout. |
| **Punch** | 4 | Remove the blocks in a plus shape (up to 5) around a chosen cell. |
| **Color Purge** | 5 | Remove every block of one chosen color. Stone is immune. |
| **Emergency Brick** | 4 | Throw a brick into a tray slot: it becomes a temporary one-block piece; a piece it hits goes to the discard pile. Not into the Warden's barred slot. |

*Board tools (Eraser, Punch, Color Purge, Patch Panel) never score, never count as a clear, and never trigger Jokers or placement refills. Any of them, Blueprint, or the Brick counts as a rescue when no offered piece fits. The throw is presentation: the rules only receive the chosen slot.*

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

Display options in place (2026-09-23): fullscreen on/off and an FPS counter, saved with the other settings. Options: reduced motion; screen shake off; CRT/VHS overlays off; bloom intensity; high-contrast grid; distinct patterns/shapes for colored blocks; UI and text scaling; colorblind-friendly palette presets; remappable keyboard input; independent music/SFX/UI volume; hold-to-confirm for destructive shop actions; optional slower tooltip dismissal. Every essential status has text or icon, never color alone. Important effect animation can be skipped or sped up without changing outcome. Aim for full keyboard operation and readable text at 720p; add controller remapping when controller support is production-ready.

## 9. Visual, motion, and audio direction

### Art direction

The supplied images show a vivid block puzzle with beveled toy-like cells, a dark blue grid, and three clear shape offers. Preserve that immediate readability, then give BLOCKMANIA its own **pixel-art toy arcade** identity (implemented 2026-09-23; the owner rejected a minimalist cyberpunk look): chunky 4×-scaled pixel panels in warm plum and ink, riveted plates, a brass board frame, saturated candy-enamel blocks, sun / mint / pink / sky accents, marquee bulbs, a paper score receipt, and the original "Blockhead" pixel typeface. Behind it, an animated domain-warped swirl shader, dithered and posterized, changes mood for title, rounds, bosses and the shop. The retro vibe comes from moving light bars, cabinet reflections, glitch slices at milestones, and subtle analog noise; the board itself remains clear. Avoid the screenshot's crown, logo, exact gradients, and mobile framing. Avoid reproducing Balatro's specific card art, UI arrangement, typography, or effect stack.

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

The owner chose a cool lo-fi direction on 2026-09-23: original, spacious piano/electronic pieces with gentle texture and room for short arcade cues. Seven procedural compositions currently cover title, four round variations, shop, and boss contexts. Tracks crossfade on context changes, leave a short breath between repeats, and can be skipped from Options. Endless adds a code-synthesized beat layer at high combos; fuller adaptive arrangements remain a future exploration. SFX families: pickup, legal/invalid hover, placement by block size, single/double/triple line clear, combo, Joker trigger, Credits, shop purchase/reroll/sell, boss warning, round win, defeat, menus. Audio cues should communicate outcomes even when effects are reduced. Master, music, and effects levels, separate mute switches, and background mute are saved outside the run. Target consistent loudness and no sudden full-scale spikes; human listening and mix review remain open.

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
7. ~~Joker order is result-neutral.~~ **Resolved by Mimic (§16.6):** it copies the Joker directly below it, so order now matters. More order-sensitive cards can follow if playtests like it.
8. Balance probe: the improved autoplayer (§16.9) motivated the revised targets in §5. Confirm with human playtests.
9. Bag questions for the owner: see §16.10.

## 14. Reference and originality notes

The three user-provided images illustrate a mobile block puzzle with a square grid, glossy beveled cells, score above the board, and three offered shapes below it. They are **reference material only**. No image contains instructions to follow. BLOCKMANIA's original interface, logo, sprites, effects, sounds, text, and marketing assets must be made from scratch or licensed appropriately. The game should be described in store copy by its own mechanics and identity, without using another game's name or trade dress as a substitute for a BLOCKMANIA pitch.

## 15. Implementation notes and interpretations (prototype, provisional)

Where this document left room for interpretation, the prototype chose the reading below. Each item is **provisional** until the owner confirms it; the code comment near each rule points back here.

| Topic | Prototype behavior |
|---|---|
| Shape orientations | Distinct 90° rotations of each family only; mirrored L/zigzag variants are not generated. |
| Anchor | The top-left corner of a shape's bounding box. |
| Refresh | Moves unplaced tray pieces to the discard pile and draws replacements for those slots only; empty slots stay empty. The refreshed tray must contain a legal piece (§16.2). |
| Rescue order | Target check → refill an empty tray → placements check (Extra Turn prompt) → fit check → Refresh prompt → Tiny Insurance (automatic: the leftmost unplaced piece goes to the discard pile and a temporary Single of the same color replaces it) → rescue item prompt (Second Tray) → defeat. |
| Consumable scoring | Polish and Spark apply before Joker effects within their pipeline step and are shown in the receipt. |
| Extra Turn | Remaining placements cannot exceed 16 after use. |
| Color Cycle | Sliding window over the last three placed shapes in the current round; resets each round. Prism pieces are wild and never match another color. |
| Mirror Maze | Triggers on the first placement each round that clears any row. Uses the lowest-index cleared row; its mirror is row `7 − r`. Occupied cells in the mirror row that are not already clearing are removed in the same step for +50 Chips. Copies stack Chips, not removals. |
| Last Stand | Checked before the placement: no Refresh available and 3 or fewer placements left, counting the current one. |
| Chain Link | Uses the combo level shown before the placement (the same level that gives combo Chips). |
| Fire Sale | Counts every Joker sold this run, including sales made before Fire Sale was bought. |
| Shop reroll | Refills every offer (Jokers, items, Workshop, pieces), including slots already bought. |
| Shop rarity by act | Uses the act of the next round: 65/30/5, 53/35/12, then 40/40/20. |
| Selling and reordering | Allowed in the shop and between placements during a round. |
| Standard Kit | Starts with 0 Credits (High Roller starts with 4). |
| Withheld content | Patch Panel, Eraser, Lucky Paint, and Blueprint need target-picking UI and are not offered yet. The Echo Chamber is withheld (§13 item 6). |

## 16. The Bag — a customizable set of pieces

**Status:** implemented in the prototype (2026-09-23). Numbers are provisional and were first tuned with the autoplayer (§16.9). The owner requested this system: the pieces that appear in the tray are something the player can **see, buy, copy, delete, add to, and upgrade**, the way a deck-builder treats its deck.

### 16.1 Goals

- Turn the tray from a random draw into a **build**: players can shape what they will be offered, not only how they score it.
- Keep the puzzle honest and readable: every piece that can be dealt is visible in the Bag view, and upgrades are marked on the board as well as in the tray.
- Add strategies that stand apart from Joker scoring: a thin bag of reliable shapes, a big bag with many families, bags built around materials, stamped utility pieces, and leveled shape families.
- Keep determinism, save/resume, and "no opaque punishment" intact.

### 16.2 Pieces, the bag, and dealing (rules)

- A **piece** is a concrete shape with a fixed **family, orientation, and color**, plus an optional **material** and an optional **stamp**. Each piece has a unique id for the run.
- **Starter bag (every Kit):** 24 pieces in 10 families. Singles ×2, Bar 2 ×3, Bar 3 ×4, L 3 ×4 (one of each orientation), Square 2×2 ×2, Bar 4 ×2, L 4 ×2, T 4 ×2, Zigzag 4 ×2, Plus 5 ×1, with colors spread evenly. Bar 5 and Square 3×3 are not in the starter bag. Players add them from the shop, which replaces the old "round 3 onward" gate.
- **Bag size:** at least 12 and at most 60 pieces. Nothing can shrink the bag below 12, whether a card, a tool, or a Glass shatter.
- **Each round:** the whole bag is shuffled into a **draw pile** using the run's shape stream. Trays are dealt by drawing from the front. Placed pieces and pieces refreshed away go to the **discard pile**. When the draw pile is empty, the discard pile is shuffled back in. Every round starts again from the full bag.
- **Refresh** moves the unplaced tray pieces to the discard pile and draws replacements for those slots only. Empty slots stay empty.
- **Legality guarantee (unchanged promise, new method):** a freshly dealt or refreshed tray always contains at least one piece that fits the board when dealt.
  1. If none of the tray's pieces fits, the last dealt slot is swapped with the first fitting piece in the draw pile. The swapped-out piece takes its place in the pile, so nothing is lost or duplicated.
  2. If no piece in the draw pile fits, the discard pile is searched the same way.
  3. If no owned piece fits anywhere, a **temporary Single** is dealt. It is marked "Temporary" in the tray tooltip and never enters the bag. The piece it replaced returns to the bottom of the draw pile.
- **Tiny Insurance** also produces a temporary Single. The piece it replaces goes to the discard pile.
- The old "no identical consecutive trays" rule is retired: with a real bag, repeated trays can only come from the player's own bag composition.
- **Visibility:** the Bag view (key **B** in a round, **View Bag** in the shop) lists the draw pile, the tray, and the discard pile, sorted by family so draw order is never revealed. Schematic levels are listed too. Each piece has a tooltip with its full text.

### 16.3 Piece upgrades

A piece has **at most one material and at most one stamp**; applying a new one replaces the old. Board cells remember their piece's material after placement, so effects that trigger "when cleared" work on cells placed turns earlier.

| Material | Effect | Pipeline step | Visual cue (not color-only) |
|---|---|---|---|
| **Chrome** | Each cell scores +20 Chips when placed. | 3 (base Chips) | Silver frame and diagonal streaks |
| **Neon** | Each Neon cell cleared gives +0.5 Mult to that placement. | 5 (additive Mult) | Double outline |
| **Gold** | Each Gold cell cleared gives +1 Credit. | 9 (after scoring) | Coin mark and brass frame |
| **Glass** | ×1.5 Mult once when a placement clears any Glass cell. Afterwards, each Glass piece with a cleared cell has a 1 in 4 chance to **shatter** and leave the bag (never below 12 pieces). | 6 (xMult), shatter at 9 | See-through face with a glare streak |
| **Prism** | Counts as every color for Joker effects: it triggers Blue Mood, and it never matches another color for Color Cycle. Disabled by The Color Blind. | Joker conditions | Six-color band at the foot of the cell |

| Stamp | Effect |
|---|---|
| **Encore** (E) | If this piece clears a line: ×2 Mult (pipeline step 6, before Glass and Jokers). |
| **Refund** (R) | Placing this piece does not use up a placement. |
| **Tip** (T) | +2 Credits whenever this piece is placed. |
| **Memory** (M) | Whenever this piece is placed, gain a Spark item if an item slot is free. |

**Schematic levels** belong to a shape family, not to a piece. Each level gives every piece of that family **+25 Chips (step 3) and +0.25 Mult (step 5)** when placed. There is no level cap in the prototype.

Glass shatter rolls use the run's shape stream, in ascending piece-id order, after scoring. The same seed and actions always produce the same shatters. The score preview is unaffected, because shattering happens after Points are awarded.

**Updated pipeline order** (extends §5):

1. **Step 3:** cells, Chrome, Schematic Chips, lines, multi-line, combo, boss.
2. **Step 4:** Polish, then Jokers top to bottom.
3. **Step 5:** 1 + Schematic Mult + Neon + Spark + Jokers, with a floor of 1.
4. **Step 6:** Encore (on a clear), Glass, then Joker xMult.
5. **Step 7:** Points.
6. **Step 8:** cell removal.
7. **Step 9:** combo, Gold, Tip, Refund, Memory, shatter.

### 16.4 Workshop cards (shop)

Workshop cards are bag edits bought and applied **immediately** in the shop. Buying one opens the bag picker, where the player chooses targets (and a color for Repaint). Nothing is charged until the choice is confirmed, and an invalid choice changes nothing. Bag edits happen only between rounds, so a round's piles are never disturbed.

| Card | Cost | Effect | Targets |
|---|---:|---|---|
| Chrome Plating | 3 | Material → Chrome | up to 2 |
| Neon Tubing | 3 | Material → Neon | up to 2 |
| Gold Leaf | 4 | Material → Gold | 1 |
| Glassworks | 3 | Material → Glass | up to 2 |
| Prism Coat | 3 | Material → Prism | up to 2 |
| Encore / Refund Stamp | 4 | Stamp | up to 2 |
| Tip / Memory Stamp | 3 | Stamp | up to 2 |
| Copier | 4 | Add an exact copy of a piece (material and stamp included) | 1 |
| Shredder | 2 | Remove pieces (bag stays ≥ 12) | up to 2 |
| Turntable | 2 | Rotate 90° clockwise (not for one-orientation families) | up to 2 |
| Repaint | 2 | Set to a chosen color | up to 3 |
| Schematic: *family* | 3 | +1 level for that family (drawn from families in the bag) | none |

Draw weights (provisional): Schematic 12, Chrome 8, Neon 7, Shredder 7, Copier 6, Glass 5, Tip 5, Turntable 5, Repaint 5, Gold 4, Prism 4, Encore 4, Refund 4, Memory 4. A listing never shows the same non-Schematic card twice.

### 16.5 Pieces for sale

Each shop offers **2 pieces**. The family is drawn from the §4 weights +4 (so large shapes appear), with a random orientation and color. There is a 30% chance of a random material and a 15% chance of a random stamp. **Price = 2, +1 with a material, +1 with a stamp, +1 for 5+ cells.**

**Shop listing (updated §6):** 3 Jokers, 2 items, 2 Workshop cards, and 2 pieces. Reroll refreshes all of them.

### 16.6 Bag-era Jokers

| Rarity | Joker | Effect |
|---|---|---|
| Uncommon | **Hoarder** | +1 Chip for each piece in your bag. |
| Common | **Architect** | +60 Chips when placing an L 3 or L 4 piece. |
| Common | **Straight Edge** | +15 Chips per cell when placing a Bar piece. |
| Common | **Square Deal** | +2 Mult when placing a Square piece. |
| Common | **Last Piece** | +80 Chips when this placement empties the tray. |
| Common | **Postmaster** | +40 Chips when placing a stamped piece. |
| Uncommon | **Lean Bag** | +0.25 Mult for each piece your bag has below 24 (max +3). |
| Uncommon | **Foundry** | +5 Chips for each upgraded piece (material or stamp) in your bag. *(was +12, then +8; see §18.6)* |
| Uncommon | **Neon Sign** | Neon cells cleared give an extra +0.5 Mult each. |
| Uncommon | **Specialist** | +0.5 Mult per Schematic level of the placed piece's family. |
| Uncommon | **Recycler** | +0.1 Mult for each piece in the discard pile before placement (max +1). |
| Rare | **Glass Cannon** | ×1.5 Mult when a placement clears any Glass cell. |
| Rare | **Collector** | ×(1 + 0.1 per shape family in your bag beyond 6); ×1.4 with the starter bag. |
| Rare | **Mimic** | Copies the scoring effect of the Joker directly below it. It does not copy another Mimic, rule-only Jokers, or disabled Jokers. |

These bring the catalog to **38 Jokers** (37 in shop rotation; Patch Panel is still withheld). **Mimic** is the first card whose position matters, which answers §13 item 7: order now changes outcomes.

### 16.7 Presentation and accessibility

- Tray, bag tiles, the drag ghost, and board cells all show material finishes and stamp badges. A material replaces the plastic face with its finish while keeping the block color readable: Chrome is a mirror with a colored horizon, Neon a glowing tube on a black sign, Gold a gilded plate with a colored jewel, Glass lead-lined stained-glass panes, Prism holographic foil around a diamond. Stamps have distinct silhouettes (Encore star, Refund return token, Tip credit coin, Memory bolt gem). Every tile also has a text label, so materials never depend on color alone. Materials and stamps have their own place/clear/trigger sounds; presentation only.
- The receipt lists piece effects (Chrome, Schematic level, Encore, Neon, Glass) with their values. After-score events (Gold Credits, Tip, Refund, Memory, shatter) appear in the receipt and the message line.
- The shop gains a **Workshop** row and a **Pieces for your bag** row. The picker lists every bag piece as a selectable tile with a "SELECTED" label, the Repaint color chosen by name, and a live "n of N chosen" status.

### 16.8 Determinism and saves

- New run state: bag, draw and discard piles, next piece id, family levels, and per-cell owner and material layers on the board. Save **schema 2**.
- Schema-1 prototype saves (random trays, no piece identities) cannot be converted faithfully and are ignored.
- Replays include `buy_tool` targets and color and `buy_piece`. All bag randomness uses the shape and shop streams.

### 16.9 Simulation and tuning

`tools/experiments.gd` runs the autoplayer on **paired seeds** (the same seeds for every variant). Modes:

- **curve:** per-round difficulty.
- **jokers:** each Joker owned from round 1, compared with a no-Joker baseline, with trigger rates.
- **upgrades:** material, stamp, Schematic, and bag-surgery scenarios compared with the baseline.

The latest report is kept in `docs/balance/`.

Findings that changed provisional numbers:

- **Round targets.** With the original targets (600 / 850 / 1,100 …), the bot failed round 1 in 30% of runs and round 2 in 62%, while the few runs that survived cleared later rounds easily: the early curve was steeper than the late one. New provisional targets: **450, 650, 850, 1,150, 1,600, 2,100, 2,800, 3,700, 4,700, 6,000, 7,500, 10,000** (§5).
- **Method caveat.** The autoplayer clears lines as soon as it can and keeps the board nearly empty; a one-placement lookahead helps it set up some multi-line clears. Adding a term for "build near-full lines" made it much *worse* (average round 4.6 → 1.3 at high weight). Building toward multi-line clears is genuinely risky in this ruleset, so multi-line and combo cards need big payoffs. The bot still cannot judge them fairly, and human playtests must decide.
- **Three tuning passes** (paired seeds, card owned from round 1; Δ = change in average round reached vs. the same seeds without it). Reports: `docs/balance/`.

| Change | Why (simulation evidence) |
|---|---|
| Hollow Point +1.5 Mult at ≥32 empty → **+0.5 Mult at ≥44 empty** | Triggered 97–100% of placements; Δ +4.2 rounds (the strongest card). Now Δ +2.1. |
| Pressure Cooker +0.5 per 4 occupied (max +4) → **per 8 occupied (max +2)** | Δ +3.6 → +2.3. |
| Hoarder common +3 Chips/piece → **uncommon +1 Chip/piece** | Always-on; Δ +4.1 as a common → +1.9 as an uncommon. |
| Recycler +0.25/discarded (max +3) → **+0.1 (max +1)** | Δ +4.0 → +2.5. |
| Collector ×0.15 → **×0.1 per family beyond 6** | Always-on rare, Δ +2.7 → +2.3. |
| Small Change +20 → **+15 Chips/cell**; Color Cycle ×2 → **×1.75** | Commons and uncommons above their tier. |
| Foundry +12 → **+8/upgraded piece**; Lean Bag +0.5 (max +4) → **+0.25 (max +3)** | Build payoffs were 25–28% win-rate outliers. They remain the strongest builds (Foundry + 6 Chrome: Δ +5.5, 13% wins). |
| Crossbar +100 → **+150**; Wide Awake +2 → **+3**; Chain Link +0.5 → **+1/combo level**; Jackpot Window exactly 3 → **3 or more lines** | Trigger rates 0–4%; raising the payoff makes the risk of building worth it. Still bot-limited. |
| Blue Mood +1 → **+2**; Spare Parts +1 Credit with ≥3 unused → **+2 with ≥2**; Long Game first 3 placements → **first placement** without cell Chips | Blue Mood and Spare Parts were roughly neutral and Long Game was harmful (Δ −0.6); now Δ +1.3, +0.5, +0.4. |
| Encore: line Chips ×2 → **×2 Mult on clear**; Refund: +1 placement on clear → **placing it is free**; Tip +1 → **+2 Credits**; Memory: Spark on clear → **Spark whenever placed**; stamp cards target **up to 2 pieces** | A stamp on one piece in 24 barely registered (Δ −0.1 to +0.3). Now Refund, Tip, and Memory each add about +1 round for 2 stamps. Encore stays situational (+0.3). |
| Chrome +15 → **+20 Chips/cell** | 4 Chrome pieces now match 4 Glass or 4 Neon in value (Δ +1.5 vs +1.0 / +2.6). |

- **Card profiles after tuning** (Δ rounds, card alone):
  - *Engine cards* (always useful): Recycler, Pressure Cooker, Hollow Point, Collector, Color Cycle, Hoarder, about +1.9 to +2.5.
  - *Solid commons:* Last Piece, Small Change, Corner Office, Straight Edge, First Strike, Architect, Blue Mood, Neat Freak, Clean Sweep, about +1.0 to +1.9.
  - *Build payoffs* (≈0 alone, +3.4 to +5.5 in their build): Foundry, Neon Sign, Specialist, Lean Bag, Glass Cannon, Postmaster.
  - *Human-skill cards* (bot-limited): Crossbar, Wide Awake, Jackpot Window, Chain Link, Mirror Maze, Last Stand.
  - *Rule and utility cards:* Second Look, Tiny Insurance, Fire Sale, Spare Parts. No card is harmful any more.
- **Bag edits.** Upgrades matter: Neon +2.6, Schematic Lv 2 on a common family +1.3 to +1.6, Chrome +1.5, stamps about +1 each. Shredding awkward pieces or copying Singles is roughly neutral for the bot. These are strategy tools, not raw power. Adding Bar 5 and Square 3×3 helps (+1.3) because big pieces score more cell Chips.
- **Difficulty curve (final, 100 seeds).** Average round reached 4.3. Clear rates: round 1 100%, round 2 97%, round 3 67%, round 4 (boss) 49%, then about 45–63% per later round. This is a lower bound for a player who plans ahead.

### 16.10 Open questions for the owner

1. Should Kits get different starter bags? For example, Compact Kit could start with 18 pieces, which would suit Lean Bag.
2. Should Workshop cards also be usable during a round (targeting only draw-pile pieces), like Balatro's tarots? The prototype keeps bag edits in the shop for clarity.
3. Should materials and stamps be sold in packs with a choose-1-of-3 reveal? It adds excitement but also UI time.
4. Glass shatter currently removes the piece even if it has a stamp. Should stamped Glass be protected?

## 17. Endless arcade mode (owner request, 2026-09-23)

Endless is a separate, low-pressure game on the same 8×8 board. There are no rounds, targets, Credits, Jokers, shops, bag edits, Refresh, or bosses. A new game offers three weighted, randomly colored and oriented shapes, including a 2×3 rectangle and 3×3 square. The player may place any offered shape without a timer. Used slots stay empty until all three are placed, then a new tray is dealt. Each new trio includes at least one shape that fits the current board if any cell is open; a seeded replacement draw repairs a trio that would otherwise be unplayable. Completed rows and columns clear together without gravity, as in the campaign.

**Score (provisional):** each placed cell earns 10 points; each completed row or column earns `100 × current combo`. Multiple lines on one placement each earn this amount; crossing cells clear only once. Clearing placements advance the chain through `x1 → x2 → x3 → x5 → x8 → x10`; further clears stay at x10. Up to two non-clearing placements preserve the chain; the third consecutive miss resets it, so the next clear starts at x1. If a clear empties the entire board, award an extra `500 × current combo` and show **PERFECT / CLEAN BOARD**. The score is applied once by the rules layer before visual effects play. **DOUBLE CLEAR**, **TRIPLE CLEAR**, and **MEGA CLEAR** describe two, three, and four or more lines cleared in one placement; **BLOCKSTORM** celebrates the first x10 clear of a chain. These callouts do not add separate points.

**Hold:** one shape can be stored in the right-hand Hold well by dragging a selected tray piece there, clicking it with a selected piece, or pressing H. If other tray pieces remain, an empty Hold draws a seeded replacement into only that slot. If this was the last tray piece, storing it starts a fresh three-piece deal, with the same at-least-one-legal-offer guarantee as a deal after placement. A filled Hold swaps its piece with the selected slot. Hold may be used once between placements and recharges only after a successful placement; dealing a new trio by holding the last piece does not recharge it, score points, or advance the placement count. An empty Hold may be used while at least one offered tray piece fits; a single-slot replacement is guaranteed to fit if that hold action would otherwise leave no fitting tray piece. A swap that would leave no playable tray piece is rejected. Loss occurs immediately when no tray piece fits and there is no already stored fitting Hold piece available to swap. An empty Hold cannot draw a rescue after the tray is stuck. Hold state and cooldown are saved with the game.

An unfinished Endless game autosaves after each successful action and is resumed from the main menu: pressing **Endless** with a game in progress opens a small popup to **Continue** it or start a **New Game** (which discards the unfinished one; it was never a finished score). Finished scores enter a local, offline top-ten board. Each run detail shows score, lines, placements, highest combo, perfect clears, largest simultaneous line clear, active run duration, peak board coverage, average time per completed placement, points per placement, best consecutive clearing streak, seed, date, and a bounded score-progression graph. Active time excludes pause, the finish picker, and time with the app out of focus; it is saved on pause, focus loss, and window close. Time is supplied as command data so scoring and shape RNG remain deterministic. Old saved games and leaderboard entries remain readable; statistics that were never recorded display as unavailable. Endless uses a separate save from the campaign, so each can be resumed independently. The shape RNG state is saved as a string-valued 64-bit state for deterministic resume.

The Endless cabinet uses the same CRT option, clear waves, particles, and reduced-motion behavior, with a code-drawn pixel infinity emblem. Its calm, tension, and celebration palettes/music are selected from board occupancy, score, and combo. Celebration starts at x5; tension starts at 68% board occupancy, or at 48% after 5,000 points. Celebration has priority while the chain lasts. A synthesized beat layer joins at x5 and grows at x8; high chains also add a gentle board pulse, drag trails, larger score text, scoreward particles, capped confetti, and small shakes. Clean-board clears receive a larger celebration and switch the empty board to a bright **Fresh Board** palette and rim until the next piece is placed. Reduced motion retains score and callout text.

The player can choose a cosmetic Endless block style: Classic Plastic, Stained Glass, Crystal, Neon, Gold, Marble, Cyberpunk, Toy Wood, Candy, Lava, Ice, Chrome, or Prism. Each has an original code-generated animated pixel-art face (shine waves that roll diagonally across the board, twinkles, flowing magma, a turning candy swirl, data pulses, a neon flicker), an optional glow halo, its own placement and clear particles, and its own generated place/clear sound. Aurora unlocks on a clean board and Starfall at x10. Reduced Motion shows every style on its still rest frame and skips particles; no information depends on the animation. The selected finish and unlocks live in settings, separate from the run and gameplay RNG. These thresholds, shape weights, and score values are playtest values, not settled balance.


## 18. Round-play update (implemented 2026-09-23)

Adopted from [docs/design/round_play_update.md](docs/design/round_play_update.md); owner instruction: "add the features in order". All values are provisional.

### 18.1 Tray Hands (`BMHands`)

- A **natural** full deal of three pieces (round start, or a new tray after the old one is spent) is checked once and gets at most one Hand, highest rank first: **Grand Slam** (same family and same color) > **Triplets** (same family) > **Monochrome** (same color; Prism counts as any color) > **Staircase** (cell counts consecutive, e.g. 2-3-4) > **Twins** (exactly two of a family).
- Rewards: Twins +30 Chips per placement from the tray (step 3); Triplets +2 Mult per placement (step 5) and +1 Refresh; Monochrome ×1.5 Mult per placement (step 6, after Glass, before Jokers); Staircase +1 placement (may exceed the refill cap); Grand Slam gets Triplets + Monochrome rewards and +3 Credits.
- Trays refilled by Refresh, Second Tray, or Tiny Insurance never form a Hand (unless the **Card Sharp** Joker is owned). Temporary pieces break a Hand. Hand pieces carry a `hand` mark, so previews, saves, and replays agree.
- Starter-bag odds (exact): Twins 21.5%, Staircase 17.9%, Monochrome 1.2%, Triplets 0.4%, any Hand 41%. The Bag view lists per-deal odds from the whole bag's composition (never the draw order).
- Presentation: each deal spins the tray like slot reels that stop left to right; a Hand adds a ribbon, chasing marquee lights, a callout, and its own fanfare. Reduced motion shows the result at once.

### 18.2 Targeted items

One targeting flow covers board cells (Eraser, up to 2), one center cell (Punch), a color (Color Purge), and tray slots (Brick; Lucky Paint + color; Blueprint + shape). The board shows every cell an action would remove; the item card offers CANCEL (and ERASE for a partial Eraser); right-click and Esc cancel; the keyboard moves a board cursor. The Emergency Brick is a physics toy: grab and fling it or click a slot; it bounces off the screen edges and smashes into the slot it enters.

### 18.3 Feats (`BMFeats`)

Crossfire (row and column in one placement), Double Tap (clear on two placements in a row), Hat Trick (3+ lines), Clean Board (empty board after the clear), Needle Threader (fill a one-block hole closed on four sides and clear), Last Breath (clear with the last placement). Feats add no score; they appear as medal banners and receipt lines, and Showboat pays for new ones.

### 18.4 New Jokers (52 total)

| Rarity | Joker | Effect |
|---|---|---|
| Uncommon | **Patience** | Non-clearing placements store +40 Chips (max +200); the next clearing placement adds them. |
| Uncommon | **Locksmith** | +1 Mult when the piece fills a closed one-block hole; +75 Chips if it also clears. |
| Uncommon | **Countdown** | ×1.5 Mult on the third of three placements with strictly fewer blocks each time. |
| Uncommon | **Breakage Bonus** | +2 Credits whenever a Glass piece shatters. |
| Rare | **Insurance Policy** | Once: a lost round restarts from scratch without the free Refresh; the card is destroyed. |
| Rare | **Showboat** | +2 Mult per Feat earned for the first time this round. |
| Uncommon | **Full Tank** | +2 Mult when placing at the refill cap. |
| Common | **Overflow** | Refills wasted by the cap pay +1 Credit each (max 3 per round). |
| Rare | **Keystone** | ×2 Mult when a 1–2 block piece clears 2+ lines. |
| Uncommon | **Draftsman** | Row + column in one placement grants an Eraser (if a slot is free). |
| Uncommon | **Card Sharp** | Full trays dealt by Refresh or Second Tray can form Hands. |
| Rare | **Hot Hand** | ×1.5 Mult on placements from a Hand tray. |
| Common | **Periscope** | Shows the next three draw-pile pieces on its card. |
| Common | **Loan Shark** | Costs 0; +6 Credits on purchase; 2 Credits per won round repay 8; cannot be sold while owing. |
| Uncommon | **Patch Panel** | *Now live:* after the first clear each round, remove one block of your choice. |

### 18.5 Boss Crate

After a boss round the shop opens with a crate: one uncommon/rare Joker (40% rare), one item, or 6 Credits. The player takes one for free (slot limits apply); the rest disappears when the shop closes. Offers use the shop stream. Bosses: The Warden and The Undertaker join the pool (§6); The Echo Chamber stays withheld.

### 18.6 Balance note

With every addition the autoplayer's average round rose from 9.3 to about 10.3 and its win rate from 2% to about 13% (60 seeds). Targets are unchanged pending human playtests; `docs/balance/experiments_v3.md` has the full survey.

- **Foundry +8 → +5 Chips per upgraded piece.** With 15 refilling placements it won 53% of runs alone (baseline 13%); at +5 it wins 27% (+1.1 rounds), level with Recycler (`docs/balance/exp_foundry_v3.md`).
- New cards alone: Patience +0.9 rounds, Hot Hand +0.5, Showboat +0.5, Insurance Policy +0.4, Countdown and Full Tank about neutral. Keystone, Locksmith, Draftsman, Overflow, Card Sharp, Periscope, Loan Shark, Patch Panel and Breakage Bonus never trigger or matter for the bot (it keeps the board open and cannot aim tools), so their −0.35 is the cost of a used Joker slot. Human playtests must judge them.

## 19. Overtime: playing on after the win (owner request, 2026-09-24)

Owner request: "allow games to continue after beating the game like in Balatro, with escalating difficulties, and set a record if you are too broken". All numbers are provisional.

- **Entry.** Winning round 12 still ends the run as a win: the win, Kit unlocks, records and achievements are saved at that moment. The win screen then offers **KEEP PLAYING: OVERTIME**. Choosing it is a run command (`{"a": "overtime"}`, `BMRun.start_overtime`), so it replays and saves like any other action. Leaving the win screen any other way ends the run as before. Overtime cannot start after a loss, twice, or after the machine breaks.
- **Structure.** The shop opens and rounds continue (13, 14, ...) with the same Jokers, bag, items and Credits. Acts keep their four-round rhythm: round 16, 20, 24 ... are boss rounds. Each Overtime act draws its boss from the boss stream when first needed (any boss in the pool, finals included, never the previous act's). The shop uses the act 3 rarity weights. The round intro, marquee ("OVERTIME - ACT 5") and shop ("OVERTIME" tag) say where you are.
- **Targets.** Round 12+k needs `T12 × 1.6^k × (1 + 0.08·k²)` where T12 is the round-12 target (12,500 since the engine update), rounded to two significant digits: 22,000 · 42,000 · 88,000 · 190,000 (round 16, boss) · 1,700,000 at round 19 · 3,300,000 at round 20 · 44,000,000 at round 24 · 1,600,000,000 at round 30 · 5,000,000,000 at round 32. Targets never exceed the machine's limit.
- **The end.** Overtime ends when a round is lost. The run-end screen reads **OVERTIME OVER**, reminds the player the run was already a win, and shows the round reached (e.g. "17 (OVERTIME +5)"). The Kit profile counts the run and its win once (`BMRun.recorded` holds what was already added), and only new lines, bosses and Hands are added the second time.
- **Breaking the machine.** Scores are 64-bit integers. The machine's limit is `SCORE_CAP` = 1,000,000,000,000,000 (exact in JSON saves). A placement whose Chips × Mult reaches the limit (or overflows) scores exactly the limit (`broken: true` in the resolution record, step 7), and the run ends at once as a legendary win: **MACHINE BROKEN!**, with the machine-crash sound, heavy shake and particles, the "Broke the Machine" achievement, and a personal record of the round it happened in (sooner is better). Round scores and run totals are clamped to the limit.
- **Records.** When a run ends (win, loss, Overtime over, broken machine), personal records update: furthest round, best single placement, best round score, and the round the machine broke. Beaten records are listed on the run-end screen as NEW RECORD lines with a sting; all of them live on the Trophy Case records plaque. They sit in `user://achievements.cfg`, separate from runs and settings.
- **Numbers on screen.** Scores and targets under a million show exactly; above that the HUD shows 3 significant digits with M/B/T/Q (1.23M, 4.56B, 1.00Q) and tooltips carry the exact value. The receipt compacts huge Mult values the same way.
- **Simulation.** `tools/simulate.gd -- <runs> <seed> overtime` plays won runs on into Overtime with the autoplayer and lists where Overtime ended. First probe (100 seeds, 2026-09-24): 16 wins; in Overtime 12 of them ended in round 13 (17,000) and 4 in round 14 (34,000), all out of placements. The curve is steep for the bot by design (it does not build toward multipliers the way a human does); tune `OVERTIME_BASE` / `OVERTIME_CURVE` after human playtests of strong builds.

## 20. Achievements and the Trophy Case (owner request, 2026-09-24)

Owner request: "an achievements system with a dedicated achievements page with a cool design, locked and occult achievements; unlocked ones show what they are in the tooltip; at least 2 pages; art, animations, effects, audio; effects when unlocking."

- **Catalog.** 48 achievements (`BMAchievements`, stable ids) on four pages of twelve (60 on five pages since the engine update, §21.6): **The Campaign** (progress, bosses, the win, Overtime, the machine), **The Bag & the Shop** (bag makeup such as 10+ blue pieces or 10+ Squares, every color, 40+ pieces, 14 or fewer, all materials, all stamps, full Joker rack, three Rares, Schematic level 3, 50 and 99 Credits), **The Scoreboard** (1K / 10K / 1M placements, 3 and 4+ lines, row + column, max combo, triple target, winning on the last placement, a clean board, Grand Slam, all five Hands), **Arcade & Secrets** (Endless 5K / 25K / 100K, x10, Fresh Board, secrets, and the meta badge). Tiers: Bronze 14, Silver 17, Gold 14, Legendary 3.
- **Secret ("occult") achievements.** Eight badges hide their name and rule until earned: the Trophy Case shows "? ? ?", a "?" medal and a one-line hint (for example "The title looks awfully fragile."). Once unlocked they show everything like the others.
- **Conditions.** Checked after every successful campaign command and Endless action, and on two presentation events (every logo letter blown up at once; the local hour for the midnight-to-5 AM badge). Checks read the run, the action result and lifetime data only; they never change scores, runs, saves or random streams (a test enforces this). Lifetime data: Tray Hands seen, best Endless score. Unlocks, "seen" flags, lifetime data and records are stored in `user://achievements.cfg` (`BMAchievementStore`). The meta badge unlocks with the last of the others.
- **Unlock feedback.** A plate slides in at the top right (clear of centered dialogs): the medal flips in like a coin, a pill says ACHIEVEMENT UNLOCKED / SECRET UNLOCKED! / LEGENDARY!, then the name and rule. Fanfares rise with the tier (bronze ding, silver triad, gold arpeggio with coins, legendary swell), secrets have their own reveal; particles grow with the tier (ring and stars; sparks; confetti; a full burst, swirl pulse and a small shake for Legendary). Several unlocks queue. Reduced Motion fades the plate and skips particles.
- **Trophy Case.** TROPHIES on the title menu (it turns mint while new badges wait). A glass cabinet with three wooden shelves and a spotlight behind each earned badge; a completion meter and per-tier counts; page tabs with per-page counts; arrow buttons and Q/E / PageUp/PageDown to turn pages (a slide with a page-flip sound); a personal records plaque; BACK / Esc. Badges: tiered medal frames (bronze, silver, gold, prism-rimmed Legendary that shimmers and twinkles), a glint sweeps across earned icons, hover lifts the medal, clicking an earned one spins it with sparkles, clicking a locked one rattles it. Locked badges are dark silhouettes with a padlock and the rule (counting ones show progress, e.g. "0 / 25,000"); earned ones show tier, flavor text and the unlock date in the hover card. A blinking NEW! tag marks badges earned since the last visit.
- **Steam.** Local only for now. The ids and conditions are ready to mirror into Steam achievements later (never required for play).

## 21. Engine update: scaling, economy and Legendary Jokers (owner request, 2026-09-24)

Owner request: "after your review, improve what you see the game lacking, modify features, stats, strategies, items... add more Jokers and items that benefit the game loop, add four Legendary Jokers with very special, overpowered characteristics, and achievements around them." The review is `docs/playtests/2026-09-24_persona_playtest.md`: 15 simulated personas, 770+ runs. Its main findings, and what this section changes:

| Finding (baseline) | Change |
|---|---|
| Points per placement grow ~6x over 12 rounds while targets grow 22x, so late rounds are 20+ small placements and runs die by attrition ("out of placements" in ~90% of losses). | Run-long **scaling Jokers** and a base Mult bonus for multi-line clears, so the build (not placement count) closes the gap. |
| The Joker rack is full by round 4-5; after that the build barely grows. | **Scaling Jokers** keep growing; **Rack Extender** adds up to two slots. |
| Nothing scales exponentially: the best "dream" builds end Overtime by round 14-16, far from the machine's limit. | Four **Legendary Jokers** that bend the rules (chain waves, doubled Jokers, transmutation, per-round explosive Mult). |
| A 2+ line clear is even *possible* on only ~2% of placements (3+ lines: 0.03%), so multi-line cards were dead draws. | Multi-line base Mult; Jackpot Window, Keystone, Crossbar, Wide Awake re-keyed to reachable conditions. Availability itself is a board/tray property: see the plan (Hold slot) in the report. |
| Credits pile up late with nothing to decide (no saving decision). | **Interest** and **Overkill** payouts; late sinks (Rack Extender, Legendaries at 12). |

### 21.1 Scoring and economy (provisional)

- **Multi-line Mult:** +1 base Mult for every line beyond the first in one placement (step 5, receipt line "Multi-line Mult"). A double is x2, a triple x3 before Jokers.
- **Interest:** after a won round, +1 Credit for every 5 Credits held at the end of the round (before the payout), at most +5 (`INTEREST_STEP`, `INTEREST_CAP`).
- **Overkill:** after a won round, +1 Credit for every full half-target scored beyond the target, at most +3 (`OVERKILL_STEP`, `OVERKILL_CAP`). The round ends on the crossing placement, so only that placement's overshoot counts: a big finishing placement pays.
- **Rack Extender** (Workshop, 9 Credits, weight 3): +1 Joker slot for the rest of the run, up to 7. Not offered once the rack has 7. The rack cards shrink to fit (`BMCard.rack_height`).
- **Run-long Joker state:** `BMRun.joker_state` holds the value of scaling cards (Snowball, Hot Streak, Overachiever), shared by copies and forgotten when the last copy is sold. Save schema 6 (`joker_state`, `extra_slots`, round `pending_xmult`, `lines_cleared`, `refresh_used`); older saves load with defaults.

### 21.2 Retuned Jokers

| Joker | Before | After |
|---|---|---|
| Jackpot Window (Rare) | x4 on 3+ lines | x2.5 on 2 lines, x5 on 3+ |
| Keystone (Rare) | x2 when a 1-2 block piece clears 2+ lines | x2 when a 1-3 block piece clears a line, x4 on 2+ |
| Crossbar (Common) | +150 on row + column | +100 on any multi-line clear, +200 if it crosses |
| Wide Awake (Uncommon) | +3 Mult on 2+ lines | +2 Mult on any clear, +5 on 2+ lines |
| Last Stand (Rare) | x2 with no Refresh and ≤3 left | x2.5 with ≤4 placements left |
| Glass Cannon (Rare) | x1.5 when Glass clears | x1 + 0.3 per Glass piece in the bag (max x4) |

### 21.3 New Jokers (13)

| Joker | Rarity | Phase | Rule |
|---|---|---|---|
| Snowball | Uncommon | xMult, scaling | Gains x0.15 each time 2+ lines clear at once. Never resets. |
| Tally Counter | Common | Chips | +4 Chips per line cleared this run. |
| Bonsai | Uncommon | +Mult | +0.35 Mult per round won this run. |
| Coin Pusher | Common | +Mult | +0.1 Mult per Credit held (max +5). Pairs with interest. |
| Hot Streak | Rare | xMult, scaling | Gains x0.3 per round won without a Refresh or Second Tray; using one resets it to x1. |
| Veteran | Rare | rule (Chips on pieces) | A bag piece that completes a line permanently gains +5 Chips, stored on that piece (§24). |
| Big Game Hunter | Uncommon | +Mult | +1 Mult per block over 4 in the placed piece. |
| Rainbow Road | Uncommon | xMult, color | x1.75 when the board holds all six colors before the placement. |
| Solo Act | Rare | xMult | x1 + 0.75 per empty Joker slot. |
| Double Stamp | Rare | rule | Stamps trigger twice: Encore x4, Tip +4, Refund +2, Memory two Sparks. |
| Vending Machine | Common | rule | After each round won, a random item drops into a free item slot (shop stream). |
| Demolition Crew | Uncommon | Chips | +15 Chips per block cleared by the placement. |
| Overachiever | Uncommon | +Mult, scaling | Gains +1 Mult whenever a round ends at 1.5x its target or more. |
| Full Pockets | Common | +Mult | +1.5 Mult per item held. |

### 21.4 New items (4)

| Item | Cost | Target | Effect |
|---|---:|---|---|
| Turbo (`overclock`) | 5 | none | The next placement this round gets x2 Mult (step 6, "Turbo"). |
| Tune-Up | 4 | tray slot | Level up the shape family of that tray piece, like a Schematic. |
| Coffee Break | 3 | none | +1 Refresh this round (refused during The Lockdown; counts as a rescue). |
| Coin Roll | 3 | none | Gain Credits equal to the round number (max 12). |

### 21.5 Legendary Jokers (4)

A fourth rarity, **Legendary** (lilac frame, gem and pill; faster glint with twinkles; its own reveal and "get" stings; a LEGENDARY! callout with confetti when bought or taken from a crate). Cost 12, sell 6, **unique** (one copy each). Where they come from:

- **Boss Crates:** the crate's Joker is Legendary 12% of the time after the act 2 boss, 20% after the final boss, 30% in Overtime (never after the first boss). Otherwise Rare 40%, Uncommon the rest. If every Legendary is owned, the crate falls back to a Rare.
- **Shops:** act 3 rarity weights 40/40/19/**1**, Overtime 34/40/23/**3**. Acts 1-2 never offer one.

| Legendary | Rule | Why it is special |
|---|---|---|
| **The Avalanche** | After a clear, every block falls straight down its column (`BMBoard.settle`). New full lines clear as **chain waves** (up to 5 per placement); wave *n* scores its lines (100 per line, +40 per extra line, +10 per cell) at the placement's Mult **x2^(n-1)**. Wave lines refill placements and count as lines cleared. | It turns the puzzle into a cascade game and is the first card that makes the pipeline's clear waves real (The Echo Chamber would halve wave Chips). |
| **Hall of Mirrors** | Every other Joker's scoring effect triggers twice: Chips and Mult add twice, xMult applies twice (squared). Mimic's copy is mirrored too. | Every build becomes its own square. |
| **Philosopher's Stone** | Material effects are doubled (Chrome +40/cell, Neon +1 Mult/cell, Gold +2 Credits/cell, Glass x2.25). Every placed bag piece without a material permanently gains a random one (shapes stream). | The bag transforms into metal over a run. |
| **Supernova** | x1 Mult plus x0.5 for every line cleared earlier in the round (resets each round). | Each round builds to a crescendo: long Overtime rounds end in huge finishers. |

All four respect the machine's limit (a wave that reaches it breaks the machine) and presentation only reads the record: the board pops each wave half a second apart with an "AVALANCHE xN!" callout, the receipt lists every wave and the total, and transmutations pop a "TRANSMUTED" label.

### 21.6 Achievements: page 5, "Legends" (12)

Once Upon a Legend (own one, Silver) · Double Legend (two at once, Gold, secret) · Pantheon (own all four across runs, Legendary; lifetime `legends_seen`) · Chain Reaction (three Avalanche waves in one placement, Gold) · Mirror World (Hall of Mirrors doubles four other Jokers in one placement, Gold) · Heavy Metal (15 pieces with a material, Silver) · Going Nova (Supernova at x10+, Gold) · Snowed In (Snowball x2+, Silver) · Compound Growth (+5 interest, Bronze) · Wide Rack (7 Joker slots, Silver) · Billionaire (1,000,000,000 in one placement, Legendary) · Fallen Hero (lose a run with a Legendary, Bronze, secret). The catalog is now 60 achievements on five pages; Block Maniac needs all of them.

## 22. Plan items, boss spectacle and menus (owner request, 2026-09-24)

Owner request: "do the open report points, then add more songs, make more effects and cool animations when reaching bosses, harder rounds, etc. Play with sounds and colors and effects, shaders. Then take a good look at the settings/menu and improve it as a UI expert and senior game designer." The report points are the plan in `docs/playtests/2026-09-24_persona_playtest.md` §7. All numbers are **provisional**. Save schema 7 (`heat`, `daily`, `round_card`, `locked_jokers`; round `held`, `hold_used`, `locked_slot2`, `last_family`); older saves load with defaults.

### 22.1 Campaign Hold

- One Hold box (under the receipt). **Hold** stores a tray piece and its slot draws a replacement from the bag; with a piece already stored, Hold **swaps** it with the chosen tray piece. Once between placements (`hold_used` resets on `place`). Input: drag a piece onto the box or press H with a piece picked up (store or swap); click the box with nothing picked up to take the stored piece back into an empty tray slot. A held piece loses its Tray Hand tag.
- The held piece stays in the bag's accounting (the pile invariant counts it). A new round starts with an empty Hold; the held piece returns to the discard pile.
- A fitting held piece keeps a round alive while Hold is available: the no-fit check counts it (the player swaps it in).
- The Lockdown Mk II disables Hold. Refresh and Second Tray never touch the held piece.
- Why: a 2+ line clear was possible on only ~2% of placements. Hold lets the player keep a finisher for the moment the board is ready.

### 22.2 Round cards

Before every **non-boss** round, NEXT ROUND opens a choice of three cards: **Standard** plus two seeded twists (shop stream). The pick is a run command (`pick_round`), saved with the shop and applied when the round starts. Targets are rounded to tens.

| Card | Target | Rule | Reward on a win |
|---|---:|---|---|
| Standard | x1 | No twist. | — |
| Gold Rush | x1 | Six Gold blocks start on the board (never a full line). | +2 Credits |
| Tight Budget | x1 | Three fewer placements. | +4 Credits |
| Rush Hour | x0.8 | No Refresh this round (Coffee Break refused). | — |
| Double or Nothing | x1.4 | — | +6 Credits |
| Mult Fever | x1.3 | Every placement gets +1 Mult. | — |
| Treasure Hunt | x1.15 | — | A random item (needs a free slot) |
| Scholarship | x1.2 | — | Level up the family of the last piece placed |

### 22.3 Mk II bosses

From act 2, act bosses are **Mk II**: a harder version of the same rule. At Heat 4+ every boss is Mk II; the final boss is Mk II only in Overtime. The name gains "Mk II" everywhere (intro, panel, ticker, receipt).

| Boss | Normal | Mk II |
|---|---|---|
| Cramped Cabinet | 4 fixed cells | 7 fixed cells |
| Taxman | First line 60 Chips | First line 30 Chips, multi-line Mult halved |
| Color Blind | Color effects off | ...and two fewer placements |
| Lockdown | No Refresh or Second Tray | ...and no Coffee Break or Hold |
| Warden | One barred slot until the first clear | Two barred slots |
| Undertaker | A tombstone every 4th placement | Every 3rd placement |
| Last Call | 12 placements, +50 Chips per multi-line placement | 10 placements |

### 22.4 Tray Hands and Kits rebalanced

- Twins now give **+1 Mult** per placement (was Chips). Triplets: +2 Mult and **x1.5**, +1 Refresh. Monochrome: **x2**. Grand Slam: **x2 and +2 Mult**, +1 Refresh, +3 Credits. Staircase unchanged (+1 placement).
- Compact, Chunky and Tetromino Kits start with **14 placements** (Standard 15). Chunky's bag loses its 3x3 square (19 pieces). Reason: every unlockable Kit beat Standard in the persona playtest.

### 22.5 Heat (stakes after a win)

Heat 0–5 is chosen on the Kit screen. Each level keeps everything below it. Heat N unlocks when a run at Heat N−1 is won (`profile.heat_won`).

| Heat | Adds |
|---:|---|
| 1 | Targets +15% |
| 2 | One fewer placement every round |
| 3 | Interest pays at most +3; shop rerolls start at 3 |
| 4 | Every boss is its Mk II version |
| 5 | Targets +35% (instead of +15%) and one fewer Refresh |

### 22.6 Joker unlocks

Fourteen Jokers join the shop pool only once an achievement is earned (the other Jokers are always in the pool). Locked Jokers are stored on the run (`locked_jokers`), so a run never changes mid-way; a Daily run locks nothing. Unlocking shows a NEW JOKER UNLOCKED toast, and the Trophy Case hover card says what a badge unlocks.

Snowball ← Triple Decker · Hot Streak ← Boss Buster · Overachiever ← Overkill · Solo Act ← Travel Light · Double Stamp ← Special Delivery · Rainbow Road ← Full Spectrum · Big Game Hunter ← Square Dance · Demolition Crew ← Crossroads · Mimic ← Rare Taste · Jackpot Window ← Red Hot · the four Legendaries ← Champion (win a run).

### 22.7 Daily run and run history

- **Daily:** one seed per local date (`BMRunConfig.daily_seed`, an FNV hash of "YYYY-MM-DD"). Standard Kit, Heat 0, every Joker in the pool, so everyone plays the same game that day. The profile keeps today's best (furthest round or win); the title's DAILY popup shows it. Local only; no server.
- **Run history:** the last 40 campaign runs in `user://history.json` (date, Kit, Heat or Daily, seed, round reached, result, best placement, total score, final Jokers). A won run that goes on into Overtime updates its entry. The title's HISTORY screen lists them and offers PLAY THIS SEED (the Kit screen opens with the seed filled in).

### 22.8 Overtime milestones

The first placement in a run to reach **1,000,000**, **1,000,000,000** and **1,000,000,000,000** points triggers a stadium moment: "SEVEN DIGITS", "BILLION-POINT BLOCK", "TRILLION TERRITORY" with confetti and a fanfare. The tier is in the resolution record (`milestone`), so it replays identically.

### 22.9 Contextual tips

Thirteen short tips (`BMTips`) appear once, the first time their situation arises: placing a piece, Chips x Mult, Hold, nothing fits, combo, Tray Hands, bosses, Heat, the shop, interest, round cards, the bag, Overtime. Conditions only read state. A tip is a plate over the receipt (round) or the Joker rack (shop), with GOT IT; it never blocks the board and fades after 16 seconds unless hovered. Seen ids are saved in settings; Settings > Game turns tips off and RESET TIPS shows them again. This is the first step of the tutorial (a scripted first round is still open).

### 22.10 Menus and settings

- **Title:** CONTINUE RUN, NEW RUN, then DAILY and ENDLESS side by side, then TROPHIES · HISTORY · SCORES, then OPTIONS and QUIT. The seed field moved to the Kit screen, where it matters.
- **Kit screen:** five Kit cards, then a bar with the **Heat selector** (0–5, locked levels dimmed with the unlock rule in the tooltip, the selected level's rules spelled out) and the optional **seed**. A warning line appears when starting would replace a saved run.
- **Pause / Options** (`BMSettingsMenu`): one 1920x1080 stage. A header with where you are (round, act, Kit, Heat, seed) and COPY SEED. A tab rail (RUN in a campaign, GAME, AUDIO, DISPLAY, ACCESSIBILITY, CONTROLS; Q/E or Page Up/Down switch) with RESUME, SAVE & QUIT and a two-step ABANDON under it. Every choice is a segmented control showing all values, the current one lit and marked with `*` (never color alone), with a one-line explanation; changes apply and save immediately; RESET PAGE restores a page's defaults. The menu reopens on the last page used.
- **RUN page:** the twelve rounds as a track (bosses marked B, current round lit), Kit, Heat, Credits, Jokers, bag size, lines, best placement, bosses beaten, the Heat rules, this act's boss and its rule, and the round card in play.
- **New settings:** Game speed (Normal / Fast x1.4 / Turbo x1.9; scales time on campaign screens only, so results and Endless statistics are unaffected), Tips, Boss intros (Cinematic / Quick), Danger heartbeat, V-Sync, Screen effects (Off / Soft / Full), Screen shake (Off / Low / Full), Flashes (Off / Soft / Full; also scales CRT jolts and background pulses). Defaults are in `BMSaveStore.default_settings()`.

### 22.11 Boss spectacle, hard rounds and music

- **Boss cinematic** (`BMBossIntro`, about 2.8 s, any input skips; Settings can make it Quick): letterbox bars with hazard tape, WARNING / BOSS ROUND (or MK II) marching text and an alarm, the name slams in with a shake, a flash and a CRT jolt, the rule types in, and a Mk II boss gets a stamped metal plate with sparks. An act's first round plays an act fanfare.
- **Mood layer** (`BMMoodLayer`, `shaders/mood.gdshader`, edges only so the board stays clean): boss rounds get a crawling hazard-tape frame and a red glow; **danger** (three or fewer placements and short of the target) adds a vignette that throbs with a soft heartbeat; **heat haze** with rising embers at Heat 3+ and in Overtime (and faintly in act 3). The board's frame gets chasing bulbs on boss rounds (pink, sun for Mk II). The swirl background has boss, Mk II, act 2, act 3 and Overtime moods.
- **Avalanche fall:** blocks now visibly fall with gravity and squash between chain waves.
- **Music:** six new original songs (Paper Lanterns, Pocket Change, Iron Curtain, Cascade, Overtime Rush, High Score; 13 in total). Contexts: title, round, **round_hard** (act 3 and Heat 3+), shop, boss, **boss_mk2**, **overtime**, and the Endless moods. Eight new cues: boss alarm, boss slam, Mk II stamp, heartbeat, danger, Hold, round pick, act start.
- Reduced Motion keeps every piece of information: the cinematic becomes a still card, the mood layer keeps its tint without motion, and flashes halve.

## 23. First-session tutorial: POPS (owner request, 2026-09-24)

Owner request: a skippable tutorial with a small bot-like helper, a dialogue box and gibberish speech "like Animal Crossing", that guides the first session step by step, appears in the corners of the screen and points at things, drawn as original pixel art in the style of the owner's reference character.

- **POPS** is the arcade's old caretaker bot: rainbow afro with an antenna bulb (lit while he talks), big ears, a round peach face with slanted oval eyes and rosy cheeks, a fluffy white beard, a ruffled collar and a polka-dot bow tie. 56×62 art pixels drawn at 4× with the project's 1-pixel ink outline; frames for idle, blink, two talk frames, point, point-and-talk, happy, happy-and-talk (`tools/art/gen_helper.py`).
- **When:** round 1 of any campaign run while `settings.tutorial_done` is false, once the round intro is closed. It never starts mid-run. Finishing or skipping sets the flag; Options > Game > REPLAY TUTORIAL clears it.
- **Steps** (`BMTutorialSteps`, 14 spoken + 2 hidden waits): greeting (SHOW ME! or SKIP TUTORIAL), the tray, place a piece (waits for a placement), the receipt and Chips × Mult, clear a line (waits for a clear, or five more placements; once the player starts on it, or after four seconds, POPS **ducks down** to a peek in his corner with a "CLEAR A LINE!" reminder, so a task that takes several turns does not keep the board dimmed), the target and lamps, Refresh, Hold, the Joker rack, "meet me in the shop" (**he leaves** 3.5 s after the line, and stays away until the shop opens), the Toybox Jokers, the Workshop, the NEXT ROUND hint (a NEXT button; pressing it sends him away so the player can keep shopping; he waits for the next round), goodbye. Round steps are skipped if the round ends first; the goodbye waits for the next round's intro to close. If the run ends mid-tour, the tour stops and starts again on the next run's round 1.
- **Pointing:** POPS picks the screen corner farthest from the target whose body and speech bubble do not cover it, hops there, turns and points with his arm, a white glove bobs just outside the target, and the rest of the screen dims around a marching outline. The glove prefers pointing down from above the target, then POPS's side, below, and the far side, taking the first spot clear of POPS and his bubble; it is drawn above the bubble.
- **Speech:** lines type in at 42 characters per second; every second letter plays a synthesized vowel blip (a/e/i/o/u by the letter, pitch from the letter code), so a line always sounds the same. A greeting, page and goodbye cue. First NEXT finishes a line, the second moves on.
- **Never in the way:** only the speech bubble takes the mouse; the dim, POPS and the glove let clicks through. POPS hides behind the pause menu and screen overlays (round intro, results, round picker) and keeps his step. Contextual tips (§22.9) wait while he talks; the tips he already covered are marked seen when the tour is finished.
- **Reduced Motion:** no slide-in, hop, bob, glove bounce or marching outline; lines appear at once. All text and pointing stay.
- Presentation only: the tutorial reads the run and never changes it (checked by the E2E replay).
- **Verification:** `tests/e2e/scenario_tutorial.gd` lists 13 failure modes (written before the code) and walks the whole tour through the real UI, including pause, skip, replay and Reduced Motion.


## 24. Owner feedback update (2026-09-24)

- **Veteran** (Rare Joker, `veteran`, rule phase): each time a bag piece *completes a line*, that exact piece permanently gains +5 Chips (+5 per Veteran copy). (Owner rework, 2026-09-24: the first version trained every placement, which was too strong.) The Chips are stored on the piece (`veteran`, save schema 8), score at step 3 as "Veteran training" every time the piece is placed, and stay even after Veteran is sold. Copier copies them (a snapshot: the copy then trains on its own); a shop piece of the same shape starts at +0; Repaint, Turntable, materials, stamps and Schematic levels keep them (Schematic bonuses stack); a Glass shatter or Shredder loses them with the piece. Temporary pieces never train. It opens a "carry piece" build: train one block, then copy it. Numbers provisional.
- **Kits** each have their own bag and a signature perk (§6 table) so they play differently, and locked Kits hide their contents.
- **Practice seeds** do not count (§6 "Meta progression").
- **Refresh lever:** the Refresh button is an arcade lever (`BMRefreshLever`, art `tools/art/gen_lever.py`, cues `tools/audio/gen_sfx_lever.py`). A row of lamps shows the Refreshes left (spent lamps stay dark); pulling is a one-armed-bandit pull: the arm ratchets down, slams with a shake, sparks and a spray of gold coins, the spent lamp pops, the lamps run a casino chase while the title flashes, the tray's reels start spinning on the slam, and the arm springs back (no hover outline). Holding the mouse on it pulls the knob partway; R still works (a keycap shows it). It goes cold with no Refresh left, gets a padlock under The Lockdown, and turns pink with a skull as CONCEDE when no move is left.
- **Custom cursor** (Options > Display > Mouse cursor, default CUSTOM): a pixel arrow, POPS's white glove over anything clickable (fingers wiggle), a pressed frame, a fist while dragging; click ring and sparks, a twinkle on new buttons, a trail on fast flicks. Hardware cursors (no lag), scaled by a whole number for the window. SYSTEM restores the OS pointer; Reduced Motion drops the effects.
- **Boss hazard frame:** sized in stage pixels: 7 stage px deep over the playfield (clear of the HUD's top text at every resolution), widening into letterbox space up to 22 px.
- **Boss panel:** its header picks the longest wording that fits ("ROUND 8 BOSS: …", "R8 BOSS: …", dropping "THE" last) and the rule wraps to at most four lines, so the panel never grows into the board; the full text is in its tooltip.
