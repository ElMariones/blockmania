# BLOCKMANIA — Task Board

Living backlog. Update it in the same commit as the work. Milestones follow GDD §12.
Legend: `[x]` done · `[~]` partial · `[ ]` open · **(owner)** needs a project-owner decision.

_Last updated: 2026-09-22 — first implementation pass (M0 rules prototype + early M1 content)._

## M0 — Rules prototype

- [x] Pin engine: Godot **4.7.2 stable**, GDScript, Forward+ (see `project.godot`, README).
- [x] Pure rules layer independent of nodes: board, shapes, tray generator, resolver, run state (`game/rules`, `game/content`, `game/run`).
- [x] Seeded, separate RNG streams (shapes / shop / boss); 64-bit state stored as strings for JSON saves.
- [x] Tray dealing: weighted families, uniform rotation, ≤2 identical colors, no identical consecutive tray, legal-at-deal guarantee, rejected-draw count.
- [x] Placement resolution pipeline (GDD §5 steps 1–9) with resolution record + itemized receipt.
- [x] Crossing row/column clears removed once; no gravity; combo 0–4 and reset.
- [x] Target crossing ends the round after full resolution; out-of-placements and no-fit failure; Refresh prompt; Tiny Insurance rescue; Concede.
- [x] Credits payout (base, unused-placement bonus, boss, Spare Parts, Cash Out; cap 99).
- [x] Shop: 3 Joker + 2 item offers, rarity weights by act, reroll price escalation, buy/sell/reorder, slot capacity.
- [x] 12 rounds / 3 acts / boss rounds 4-8-12, bosses chosen per run without repeats.
- [x] Action history + `BMRun.replay()`; determinism, replay, and save/resume tests.
- [x] Headless test runner with runtime-error capture (`tests/run_tests.gd`) — 61 tests.
- [x] Greedy autoplayer + balance probe (`tools/simulate.gd`).
- [x] Placeholder UI: title, round intro, board, tray, HUD, score preview, receipt, Jokers/items rail, round result, shop, run end, pause.
- [x] Mouse drag-and-release, click-to-hold, right-click/Esc cancel; keyboard 1–3 / arrows+WASD / Enter+Space / R / Esc.
- [x] Local save after every action (atomic temp+rename), Continue on title, finished runs not resumable.
- [ ] Ten reproducible complete seeded runs reviewed by a human (M0 exit criterion) — needs playtesting.
- [ ] Tutorial (scripted offers) — M2.

## M1 — Vertical slice (in progress)

- [x] 23 of 24 Jokers implemented with per-card tests (all except Patch Panel).
- [x] 5 of 8 consumables usable: Polish, Spark, Second Tray, Extra Turn, Cash Out.
- [x] 5 of 6 bosses active: Cramped Cabinet, Taxman, Color Blind, Lockdown, Last Call.
- [ ] **Patch Panel** Joker — needs a board cell-picking interaction (withheld from shop).
- [ ] **Eraser**, **Lucky Paint**, **Blueprint** — need cell / color / shape pickers (withheld from shop).
- [ ] Joker trigger presentation in resolution order (currently a brief flash on triggered cards).
- [ ] Score count-up + clear sweep VFX polish; Fast Animations toggle; skip input for sequences.
- [ ] Audio: placeholder SFX families (pickup, place by size, clears 1/2/3+, invalid, purchase) — no audio yet.
- [ ] Grayscale wireframes at 1920×1080 and 1280×720 (ASSET_PLAN §11 step 1) before production art.
- [ ] Verify layout at 1280×720, 16:10, ultrawide (only 1600×900 window checked so far).

## M2 — Content complete

- [ ] Kit selection screen (Standard / Compact / High Roller) + unlock tracking (100 lines, win a run).
- [ ] Practice mode (choose seed, Kit, bosses, Jokers; Undo; no records).
- [ ] Collection / run history / discovery.
- [ ] Settings screen: audio buses, display mode, UI scale 75–150%, input remapping, colorblind presets, high-contrast grid.
- [ ] Save schema migrations (`BMSaveStore.load_run` has the hook) + corruption recovery UI.
- [ ] Daily Challenge (optional for launch).
- [ ] Remove or gate the `_mcp_game_helper` autoload in release exports (dev-only tooling).

## M3 / M4 — Polish, balance, Steam

- [ ] Production art/audio per ASSET_PLAN; original fonts with licenses.
- [ ] Performance profiling on target hardware; export presets for Windows.
- [ ] Steamworks integration (achievements/cloud optional, never required for play).

## Balance watch (provisional numbers — do not tune silently)

- Greedy autoplayer (no Joker strategy), 200 seeds: 0 wins, ~67 points/placement, most runs end in round 2 (target 850). Real players plan combos, so this is a **lower bound**, but it suggests early targets or the 12-placement budget may be tight. Playtest before changing (GDD §13 item 1).

## Open owner decisions

- **(owner)** **The Echo Chamber** has no effect with current content (no card creates extra clear waves). It is withheld from the boss pool. Options: rework its rule, add After Clear Jokers that create waves, or replace it.
- **(owner)** Joker order currently never changes a result (additive Chips → additive Mult → xMult are phased, and xMult is commutative). GDD says reordering "can change outcomes". Keep reordering as cosmetic, or add order-sensitive cards (e.g. "copy the Joker to the right", "x2 the previous Joker's Mult")?
- **(owner)** Interpretations made where the GDD was ambiguous are listed in GDD §15 — confirm or adjust.
