# BLOCKMANIA — Task Board

Living backlog. Update it in the same commit as the work. Milestones follow GDD §12.
Legend: `[x]` done · `[~]` partial · `[ ]` open · **(owner)** needs a project-owner decision.

_Last updated: 2026-09-23 — Endless last-piece Hold now deals a full trio._

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
- [ ] **Patch Panel** Joker — needs a board cell-picking interaction (withheld from shop).
- [ ] **Eraser**, **Lucky Paint**, **Blueprint** — need cell / color / shape pickers (withheld from shop).
- [x] Joker trigger presentation in resolution order: sequenced card pulses with Chips/Mult pop text (capped at 6 per placement).
- [x] Score count-up (rolling counter, liquid tube) and clear VFX (sweep, wave-delayed bursts, shards, streams, CRT shock).
- [ ] Fast Animations toggle; skip input for sequences.
- [x] Audio: 59 synthesized effect files for UI, pieces, clears, combos, economy, Jokers, bag, and results; seven original lo-fi tracks for title, round, shop and boss contexts.
- [x] Audio options: master/music/effects levels, sound and music switches, background mute, Next Song, and `M` shortcut; settings persist separately from runs.
- [ ] Human listening pass on target speakers/headphones: balance repetitive effects, confirm music pacing and cue comfort; adjust mixes after feedback.
- [x] **UI overhaul** (2026-09-23): original pixel-art kit and Blockhead fonts generated as code, swirl shader background, CRT filter (Off/Soft/Full), particle VFX, new title/round/shop/pause/bag/modals. See ASSET_PLAN §12.
- [x] Image-generator art (`assets/source/generated/`) reviewed by the owner: **not adopted**.
- [x] Layout verified at 1920×1080, 1280×720, 1680×1050 and 2560×1080 with `tools/shoot.py`; stage children checked for minimum-size overflow.
- [x] Title-screen Options (CRT, motion, block patterns, controls) before starting a run.
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
- [ ] Joker art: emblems are icon tiles for now; per-Joker illustrations drawn as code (pixel sprites) would add identity.
- [ ] Hover and tooltip pass with real mouse playtesting (tooltips are styled; hover lifts are verified in fixtures only).
- [ ] The Joker rack rebuilds on every refresh; keep the hover state across rebuilds.

## M2 — Content complete

- [ ] Kit selection screen (Standard / Compact / High Roller) + unlock tracking (100 lines, win a run).
- [ ] Practice mode (choose seed, Kit, bosses, Jokers; Undo; no records).
- [ ] Collection / run history / discovery.
- [~] Settings screen: audio controls are present; display mode, UI scale 75–150%, input remapping, colorblind presets, high-contrast grid remain.
- [ ] Save schema migrations (`BMSaveStore.load_run` has the hook) + corruption recovery UI.
- [ ] Daily Challenge (optional for launch).
- [ ] Remove or gate the `_mcp_game_helper` autoload in release exports (dev-only tooling).

## M3 / M4 — Polish, balance, Steam

- [ ] Production art/audio per ASSET_PLAN; original fonts with licenses.
- [ ] Performance profiling on target hardware; export presets for Windows.
- [ ] Steamworks integration (achievements/cloud optional, never required for play).

## Balance watch (provisional numbers — do not tune silently)

- 2026-09-22: greedy bot with the original targets failed round 1 in 30% of runs and round 2 in 62%; survivors cleared later rounds easily.
- 2026-09-23: **targets retuned** to 450 / 650 / 850 / 1,150 / 1,600 / 2,100 / 2,800 / 3,700 / 4,700 / 6,000 / 7,500 / 10,000 (GDD §5, §16.9). The bot now reaches round ~4.5 on average with gradual attrition. Human playtests must confirm.
- Per-Joker and per-upgrade impact tables: `docs/balance/experiments_v1.md`. Tuning actions taken from them are listed in GDD §16.9.

## Open owner decisions

- **(owner)** **The Echo Chamber** has no effect with current content (no card creates extra clear waves). It is withheld from the boss pool. Options: rework its rule, add After Clear Jokers that create waves, or replace it.
- ~~Joker order never changes a result~~: resolved by **Mimic** (copies the Joker below it). Add more order-sensitive cards? (owner)
- **(owner)** Interpretations made where the GDD was ambiguous are listed in GDD §15 — confirm or adjust.
