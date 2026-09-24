# BLOCKMANIA — Task Board

Living backlog. Update it in the same commit as the work. Milestones follow GDD §12.
Legend: `[x]` done · `[~]` partial · `[ ]` open · **(owner)** needs a project-owner decision.

_Last updated: 2026-09-24 — Persona playtest review (docs/playtests), engine update (interest, overkill, multi-line Mult, scaling Jokers, Rack Extender, 13 Jokers, 4 items, 4 Legendary Jokers, Legends achievement page, targets raised). Earlier today: shop menu, card portraits, Overtime, 48 achievements._

## M0 — Rules prototype

- [x] Pin engine: Godot **4.7.2 stable**, GDScript, Forward+ (see `project.godot`, README).
- [x] Pure rules layer independent of nodes: board, shapes, bag, resolver, run state (`game/rules`, `game/content`, `game/run`).
- [x] Seeded, separate RNG streams (shapes / shop / boss); 64-bit state stored as strings for JSON saves.
- [x] ~~Random tray dealing~~ replaced by the Bag (see below). Legal-at-deal guarantee kept.
- [x] Placement resolution pipeline (GDD §5 steps 1–9) with resolution record + itemized receipt.
- [x] Crossing row/column clears removed once; no gravity; combo 0–4 and reset.
- [x] Target crossing ends the round after full resolution; out-of-placements and no-fit failure; Refresh prompt; Tiny Insurance rescue; Concede.
- [x] Credits payout (base, unused-placement bonus, boss, Spare Parts, Cash Out; cap 99).
- [x] Shop: 3 Joker + 2 item offers, rarity weights by act, reroll price escalation, buy/sell/reorder, slot capacity.
- [x] 12 rounds / 3 acts / boss rounds 4-8-12, bosses chosen per run without repeats.
- [x] Action history + `BMRun.replay()`; determinism, replay, and save/resume tests.
- [x] Headless test runner with runtime-error capture (`tests/run_tests.gd`), now 100 tests.
- [x] Autoplayer (preview-guided, shop policy) + balance probe (`tools/simulate.gd`) + paired-seed experiments (`tools/experiments.gd`).
- [x] Placeholder UI: title, round intro, board, tray, HUD, score preview, receipt, Jokers/items rail, round result, shop, run end, pause.
- [x] Mouse drag-and-release, click-to-hold, right-click/Esc cancel; keyboard 1–3 / arrows+WASD / Enter+Space / R / Esc.
- [x] Local save after every action (atomic temp+rename), Continue on title, finished runs not resumable.
- [ ] Ten reproducible complete seeded runs reviewed by a human (M0 exit criterion) — needs playtesting.
- [ ] Tutorial (scripted offers) — M2.

## The Bag — customizable pieces (GDD §16)

- [x] Persistent bag of pieces (family, orientation, color, material, stamp); 24-piece starter bag; min 12 / max 60.
- [x] Draw/discard piles, shuffles, reshuffle on empty draw pile, legality guarantee by swap (temporary Single as last resort).
- [x] Board remembers each cell's piece and material; clear-triggered effects work on earlier placements.
- [x] Materials: Chrome, Neon, Gold, Glass (with deterministic shatter), Prism. Stamps: Encore, Refund, Tip, Memory. Schematic family levels.
- [x] Workshop: 13 tool cards + Schematics, applied via bag picker; pieces for sale; reroll covers everything.
- [x] 14 bag-era Jokers (38 total) including order-sensitive **Mimic**.
- [x] Bag view (key B / View Bag), tray tooltips, material finishes and stamp badges with non-color cues, receipt lines.
- [x] Save schema 2 (schema-1 prototype saves ignored); replays include bag edits.
- [x] Tests: dealing, pile accounting invariant, guarantee, every material/stamp/tool, new Jokers, save/replay of bag edits.
- [ ] Workshop usable during rounds? Packs with choose-1-of-3? Kit-specific starter bags? (owner, GDD §16.10)
- [ ] Bag-edit feedback animation (piece glides into the bag, shatter effect); basic bag/workshop audio cues are in.
- [ ] Autoplayer: smarter Workshop targeting (it favors large pieces, which are drawn no more often than small ones).

## M1 — Vertical slice (in progress)

- [x] 37 of 38 Jokers implemented with per-card tests (all except Patch Panel).
- [x] 5 of 8 consumables usable: Polish, Spark, Second Tray, Extra Turn, Cash Out.
- [x] 5 of 6 bosses active: Cramped Cabinet, Taxman, Color Blind, Lockdown, Last Call.
- [x] **Patch Panel**, **Eraser**, **Lucky Paint**, **Blueprint** now usable (round-play update targeting).
- [x] Joker trigger presentation in resolution order: sequenced card pulses with Chips/Mult pop text (capped at 6 per placement).
- [x] Score count-up (rolling counter, liquid tube) and clear VFX (sweep, wave-delayed bursts, shards, streams, CRT shock).
- [x] **Placement budget rework** (owner: "12 is too short"): Kits start with 15 / 15 / 14 placements, every cleared line gives one back up to the starting count, a clear on the last placement keeps the round alive. Last Call 10 → 12, Extra Turn cap 16 → 20. HUD bulbs show left/cap with a mint refill flash, a +N pop, a receipt/message line, and intro and tooltip text. Save schema 3 (`placement_cap`). Tests added (GDD §5 "Placements and refills").
- [ ] Human playtest of the refill budget: does Act 1 feel too easy now (targets unchanged)? Does the unused-placement Credit bonus and Spare Parts inflate the economy?
- [ ] Fast Animations toggle; skip input for sequences.
- [x] Audio: 59 synthesized effect files for UI, pieces, clears, combos, economy, Jokers, bag, and results; seven original lo-fi tracks for title, round, shop and boss contexts.
- [x] Audio options: master/music/effects levels, sound and music switches, background mute, Next Song, and `M` shortcut; settings persist separately from runs.
- [ ] Human listening pass on target speakers/headphones: balance repetitive effects, confirm music pacing and cue comfort; adjust mixes after feedback.
- [x] **UI overhaul** (2026-09-23): original pixel-art kit and Blockhead fonts generated as code, swirl shader background, CRT filter (Off/Soft/Full), particle VFX, new title/round/shop/pause/bag/modals. See ASSET_PLAN §12.
- [x] Image-generator art (`assets/source/generated/`) reviewed by the owner: **not adopted**.
- [x] Layout verified at 1920×1080, 1280×720, 1680×1050 and 2560×1080 with `tools/shoot.py`; stage children checked for minimum-size overflow.
- [x] Title-screen Options (CRT, motion, block patterns, controls) before starting a run.
- [x] Fullscreen toggle and Show FPS in Options (DISPLAY), saved in settings (2026-09-23).
- [x] Launch splash "by Mario Landáburu / made with Godot" replaces the Godot boot image: dancing letters, burst, fade to the title; skippable (2026-09-23).
- [x] Title menu polish (owner request, 2026-09-23): every menu button has an icon with its label centered; clicking a BLOCKMANIA logo letter makes it explode and drop back in (easter egg, cosmetic only). The Continue Endless button is gone: Endless with a game in progress opens a Continue / New Game popup.
- [x] Focus outline appears for keyboard navigation and is hidden after pointer use.
- [x] Owned Jokers reorder by drag and drop in the round and shop; Alt+Up/Down is the keyboard alternative.
- [x] Endless arcade mode: separate seeded rules and save, fair three-piece deals, Hold, no-fit loss, x1/x2/x3/x5/x8/x10 combo with three-miss reset, clean-board bonus, top-ten local scores, pixel infinity icon, and calm/tension/celebration presentation with an added combo music layer.
- [x] Endless includes 2×3 rectangle and 3×3 square offers, line-count callouts, scoreward particles, high-combo trails/pulse/shake, and a right-side Hold well in place of tutorial text.
- [x] No-fit loss triggers immediately when the tray is stuck and Hold is empty; an already stored fitting piece may still rescue the run. Stuck saves created by the old rule resume into the result screen and record their score.
- [x] Storing the last tray piece in an empty Hold deals three fresh fair offers, keeps Hold on cooldown until a placement, and survives seeded save/resume.
- [x] High-score popup rebuilt so its art cannot intercept Back or score-row clicks; run details include score progression and 11 additional statistics. No Room Left shares the same detailed breakdown and graph. Endless save schema 3 tracks stats and active time, and older saves remain readable.
- [x] Endless finish picker: 12 selectable finishes with custom synthesized cues, plus unlockable animated Aurora/Starfall. Complete board clears switch to the bright Fresh Board look and music context.
- [x] Block finish redesign (owner request, 2026-09-23): 14 animated pixel-art finishes in `tools/art/gen_finishes.py` (stained glass, step-cut crystal, neon tube, gilded gold, marble, circuit, toy wood, pinwheel candy, lava, ice, mirror chrome, holographic prism, aurora, starfall), each with its own motion, stepped glow halo, place/clear particles and generated place/clear sounds (`tools/audio/gen_finish_sfx.py`). Prism added as a 15th Endless style. Campaign materials now draw the matching finish face instead of an overlay, with their own sounds on place and clear. Stamps redrawn as animated badges with distinct silhouettes (star, return token, credit coin, bolt gem) and a trigger sound each. `tests/test_finishes.gd` guards the art/sound/catalog contract.
- [ ] Human playtest of Endless shape weights, scoring, combo pacing, and high-score replay value; balance numbers are provisional (GDD §17).
- [ ] Human comfort and listening pass for the new combo percussion and high-combo effects at 720p and on target hardware.
- [ ] Human review of all 15 block styles and their cues: color readability at tray size, glow comfort on busy boards (Neon is the strongest), shine-wave frequency, mix level of material/stamp cues over the clear chime, reduced motion, and Fresh Board transitions on target hardware.
- [x] Joker art: every Joker, item and Workshop tool has its own code-drawn pixel portrait (2026-09-24, `tools/art/gen_cards.py`).
- [ ] Hover and tooltip pass with real mouse playtesting (tooltips are styled; hover lifts are verified in fixtures only).
- [ ] The Joker rack rebuilds on every refresh; keep the hover state across rebuilds.

## Round-play proposals (awaiting owner approval)

Full specs, odds and reasoning: [docs/design/round_play_update.md](docs/design/round_play_update.md). This includes the review of `ideas.md` (keep / later / discard).

- [x] Tray Hands: Twins / Staircase / Monochrome / Triplets / Grand Slam on natural deals (`BMHands`, `tests/test_hands.gd`), Hot Hand and Card Sharp Jokers. Presentation: every deal spins the tray like slot reels; Hands get a ribbon, chase lights, a callout, particles, and their own fanfare (`tools/audio/gen_sfx_features.py`).
- [x] Item targeting (cells / one cell / color / tray slot / slot + color / slot + shape) with board overlays, keyboard control, and CANCEL/ERASE buttons on the item card. Eraser, Blueprint, Lucky Paint, and Patch Panel are live; new Punch, Color Purge, and **Emergency Brick** (a throwable physics brick: grab and fling it, or click a slot; it bounces off the screen edges and smashes into the slot it hits). Board tools remove cells without scoring (`tests/test_tools.gd`).
- [x] Feats in the resolution record (`BMFeats`): Crossfire, Double Tap, Hat Trick, Clean Board, Needle Threader, Last Breath. They show as gold medal banners and receipt lines.
- [x] 14 new Jokers (52 total): Patience, Locksmith, Countdown, Breakage Bonus, Insurance Policy, Showboat, Full Tank, Overflow, Keystone, Draftsman, Card Sharp, Hot Hand, Periscope, Loan Shark, each with trigger and no-trigger tests. Periscope draws the next pieces on its card; Insurance gets a stamp and a replay dialog; Loan Shark has its own coin sound.
- [x] Bosses: **The Warden** (a barred tray slot until the first clear; deals and Refresh skip it) and **The Undertaker** (a tombstone rises every 4th placement, never completing a line). Both have their own art, animation and sound; Echo Chamber stays out of the pool. Emergency Brick is in the shop. (`tests/test_bosses.gd`)
- [x] Fit indicators (tray "NO ROOM" caption already existed); Bag view statistics (families, colors, upgraded) and exact Tray Hand odds per deal.
- [x] Kit starter bags (Standard 24, Compact 18 without Singles, new Chunky 20 and Tetromino 20). Kit picker on New Run, with bag drawings and unlock progress. Lifetime unlock counters are in `user://profile.cfg`, and the run-end screen announces new Kits.
- [x] Boss Crate: after each boss, pick 1 free from a Joker (uncommon/rare), an item, or 6 Credits. The crate rattles and bursts open; a BOSS CRATE button reopens it until you leave the shop. Crate art redrawn (owner request, 2026-09-23): a detailed 64×60 pixel crate with a hover frame that lifts the lid, plus a matching button icon. A crate Joker or item you have no slot for shows LOCKED (padlock, SLOTS FULL tag, how-to-unlock note); while the crate is unopened the round ticker shortens so the BOSS CRATE button never covers it.
- [x] Combo grace: the campaign combo survives one placement without a clear (`COMBO_GRACE = 1`). Simulated: win rate 10% → 13%, average round 9.98 → 10.28. The HUD shows "x3!" and "HANG ON!".

## Owner requests, 2026-09-24

- [x] **Shop menu:** Esc (or the new MENU button) in the shop opens the pause menu; "SAVE & MAIN MENU" returns to the title and CONTINUE RUN resumes in the shop. Esc still closes shop popups first.
- [x] **Card portraits:** an original 16×16 pixel sprite for each of the 52 Jokers, 11 items and 5 Workshop tools (materials and stamps keep their live finish drawing), generated by `tools/art/gen_cards.py` with an auto ink outline and an 8-frame sheet (rest, 6-frame glint, silhouette). Emblems keep the phase color tile; portraits glint now and then (Rares more often, with twinkles) and hop on hover. Reduced Motion shows the rest pose.
- [x] **Overtime** (GDD §19): KEEP PLAYING after the round-12 win; rounds 13+ with fast-rising targets, a boss per act, compact M/B/T/Q numbers, OVERTIME tags, run-end "OVERTIME OVER". The machine's limit (10^15 per placement) ends the run as MACHINE BROKEN. Personal records (furthest round, best placement, best round, machine broken) with NEW RECORD lines. Save schema 5; the Kit profile never double-counts a run. Tests: `tests/test_overtime.gd`.
- [x] **Achievements** (GDD §20): 48 badges on 4 pages (8 secret), tiered medal art and 48 pixel icons, unlock toasts with tiered fanfares/particles, the Trophy Case (cabinet, meter, tabs, page flips, hover cards, NEW tags, records plaque), 12 new sounds (`tools/audio/gen_sfx_achievements.py`). Tests: `tests/test_achievements.gd`.
- [ ] Human playtest: Overtime curve (bot: 12 of 16 winners fell in round 13), toast frequency early in a first run (many bronze badges come fast), listening pass for the new fanfares and the machine-break crash.
- [ ] Steam achievements mirror of the local ids (later, optional).

## Owner requests, 2026-09-24 (review and engine update)

- [x] **Persona playtests and design report:** `tools/playtest.gd` (15 personas: random, newcomer, steady, a whole-tray search planner, seven build archetypes, four Kits, ceiling and opportunity probes) + `tools/playtest_report.py`; 770+ baseline runs. Report with verdict, diagnosis, changes and plan: `docs/playtests/2026-09-24_persona_playtest.md` (tables beside it).
- [x] **Engine update** (GDD §21): multi-line base Mult, interest, overkill, Rack Extender (7 slots), run-long scaling Jokers (`BMRun.joker_state`), 13 new Jokers, 4 new items (Turbo, Tune-Up, Coffee Break, Coin Roll), 6 retuned cards, targets for rounds 3–12 raised ~25%. Save schema 6.
- [x] **Legendary Jokers** (rarity 4, unique, cost 12): The Avalanche (gravity chain waves), Hall of Mirrors (Jokers trigger twice), Philosopher's Stone (doubled materials, transmutation), Supernova (per-round line Mult). Boss Crates from act 2 (12% / 20% / 30% Overtime) and late shops (1% / 3%). Lilac frames, reveal/get stings, callouts, receipt lines per wave.
- [x] **Achievements page 5 "Legends"** (12 badges, 2 secret, icons): Legendary finds, Pantheon (lifetime), Chain Reaction, Mirror World, Going Nova, Billionaire, and more. 60 achievements in total.
- [x] Tests: `tests/test_engine.gd`, `tests/test_legendary.gd`, new cases in `test_achievements.gd`; retuned card tests updated.
- [ ] Human playtest of the engine update: do Legendaries feel special or mandatory? Is the Avalanche readable (blocks do not animate their fall yet)? Does interest make players hoard?
- [ ] Animate the Avalanche fall (per-wave board snapshots in the record), not just the wave pops.
- [ ] Plan items from the report (§7): campaign Hold slot (multi-line availability is ~2% of placements), boss escalation in later acts, Tray Hand rebalance, round choice before non-boss rounds, tutorial, daily seed and run history, stakes after a win, achievement-gated Joker unlocks, Overtime milestones.

## M2 — Content complete

- [x] Kit selection screen + unlock tracking (see Round-play proposals).
- [ ] Practice mode (choose seed, Kit, bosses, Jokers; Undo; no records).
- [~] Collection / run history / discovery: the Trophy Case (achievements + personal records) is in; a Joker/item collection view and run history remain.
- [~] Settings screen: audio controls are present; display mode, UI scale 75–150%, input remapping, colorblind presets, high-contrast grid remain.
- [ ] Save schema migrations (`BMSaveStore.load_run` has the hook) + corruption recovery UI.
- [ ] Daily Challenge (optional for launch).
- [ ] Remove or gate the `_mcp_game_helper` autoload in release exports (dev-only tooling).

## M3 / M4 — Polish, balance, Steam

- [ ] Production art/audio per ASSET_PLAN; original fonts with licenses.
- [ ] Performance profiling on target hardware.
- [x] Windows export preset and a first demo executable (2026-09-23): single exe with embedded pck, original BLOCKMANIA icon (`tools/art/gen_icon.py`) and version info; dev folders excluded. Launch verified off-screen on the owner's machine.
- [ ] Steamworks integration (achievements/cloud optional, never required for play).

## Balance watch (provisional numbers — do not tune silently)

- 2026-09-24: **Engine update + targets 450 / 650 / 900 / 1,200 / 1,800 / 2,400 / 3,300 / 4,400 / 5,700 / 7,300 / 9,300 / 12,500.** Persona playtest (seeds 1001+): steady 10% → 37% wins with the engine and old targets → **18%** with the new targets; newcomer avg round 6.0 → 6.6; planner 82% → 83% (builds grow instead: best placement 34k → 434k, deepest Overtime 15 → 20); multi-line build 38% → 63%; painter 82% → 90%. Legendary probe (three Legendaries from round 1, 7 seeds): Overtime rounds 15–32, and one seed reached round 60 with a 1.2 × 10^14 placement (machine limit 10^15). Watch: planner still clears rounds 1–11 almost always; every unlockable Kit beats Standard (Chunky 100%); late Credits pile up for the greedy bot (33 at round 12). Report: `docs/playtests/2026-09-24_persona_playtest.md` §6.

- 2026-09-24: **Overtime** targets `10,000 × 1.6^k × (1 + 0.08k²)`. Autoplayer, 100 seeds: 16 wins; Overtime ended in round 13 for 12 and round 14 for 4. Human playtests with strong builds decide the curve.

- 2026-09-22: greedy bot with the original targets failed round 1 in 30% of runs and round 2 in 62%; survivors cleared later rounds easily.
- 2026-09-23: **targets retuned** to 450 / 650 / 850 / 1,150 / 1,600 / 2,100 / 2,800 / 3,700 / 4,700 / 6,000 / 7,500 / 10,000 (GDD §5, §16.9). The bot now reaches round ~4.5 on average with gradual attrition. Human playtests must confirm.
- 2026-09-23: **placement budget** 12 flat → 15 with a +1-per-line refill up to the cap. Bot average round 4.3 → 9.3, round 3 clear 71% → 100%, round 8 boss 81%, final boss 11%. Every baseline loss had been "out of placements". Variants compared in docs/design/round_play_update.md §1; the full report is `docs/balance/experiments_v2.md`. New outlier: **Foundry + 6 Chrome 65% wins** (was 13%). Trim Foundry if human play confirms it.
- 2026-09-23: after the round-play update the bot reaches round 10.3 on average and wins 13% (was 9.3 / 2%). **Foundry trimmed +8 → +5** (53% → 27% wins alone). Targets unchanged: human playtest needed. Tool and setup Jokers (Keystone, Locksmith, Draftsman, Overflow…) cannot be judged by the bot. Report: `docs/balance/experiments_v3.md`.
- Per-Joker and per-upgrade impact tables: `docs/balance/experiments_v1.md`. Tuning actions taken from them are listed in GDD §16.9.

## Open owner decisions

- **(owner)** **The Echo Chamber** has no effect with current content (no card creates extra clear waves). It is withheld from the boss pool. Options: rework its rule, add After Clear Jokers that create waves, or replace it. *Proposal: replace it with The Warden (round_play_update.md §5).*
- ~~Joker order never changes a result~~: resolved by **Mimic** (copies the Joker below it). Add more order-sensitive cards? (owner)
- **(owner)** Interpretations made where the GDD was ambiguous are listed in GDD §15 — confirm or adjust.
