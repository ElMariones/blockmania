# BLOCKMANIA

**Status:** early M1 (playable; original pixel-art UI, CRT filter, VFX; no audio yet) · **Engine:** Godot 4.7.2 stable (GDScript) · **Target:** premium desktop game on Steam

BLOCKMANIA is a single-player, turn-based block placement roguelike. Place pieces from your own customizable **bag** on an 8×8 board, clear complete rows and columns, beat escalating round targets, and build a run around rule-changing Jokers and upgraded pieces. The moment-to-moment puzzle should feel immediate; the run should reward planning, risk, and surprising combinations.

## Start here

1. [GAME_DESIGN_DOCUMENT.md](GAME_DESIGN_DOCUMENT.md): gameplay, progression, UI, presentation, and production specifications. §15 records the prototype's rule interpretations.
2. [TASKS.md](TASKS.md): live backlog, milestone progress, balance watch, open owner decisions.
3. [ASSET_PLAN.md](ASSET_PLAN.md): art, animation, audio, UI, and Steam deliverables.
4. [AGENTS.md](AGENTS.md): instructions for development agents and contributors (architecture, commands, workflow).

## Running the prototype

Open the folder in **Godot 4.7.2** and press Play (main scene `res://game/main.tscn`). A full 12-round run is playable: title, round intros, board and tray, score receipt, Jokers, items, bosses, shop, and run end. The run autosaves after every action; **Continue Run** on the title resumes it.

Controls: drag a shape onto the board, or click a shape and then click a cell. Right-click or Esc cancels. Keyboard: `1`–`3` select a shape, arrows/WASD move it, Enter/Space place, `R` refresh, `B` shows your bag, Esc pauses.

## Tests and tools

```bash
godot --headless --path . --import                                   # first time / after adding scripts
godot --headless --path . --script res://tests/run_tests.gd          # rule, determinism, save tests
godot --headless --path . --script res://tools/simulate.gd -- 200 1  # bot balance probe
godot --headless --path . --script res://tools/experiments.gd -- all 40 1 res://docs/balance/report.md  # paired-seed content experiments
```

## What exists

- Deterministic rules layer: seeded shape/shop/boss streams, the full scoring pipeline with an itemized receipt, 37/38 Jokers, 5/8 items, 5/6 bosses, economy, shop, replayable action history.
- **The Bag** (GDD §16): a visible, persistent set of pieces dealt through draw/discard piles, with materials (Chrome, Neon, Gold, Glass, Prism), stamps (Encore, Refund, Tip, Memory), Schematic family levels, a Workshop for copying/removing/rotating/repainting/upgrading pieces, and pieces for sale.
- Simulation tooling: a preview-guided autoplayer and paired-seed experiments; reports in `docs/balance/`.
- Original pixel-art UI generated as code (`tools/art/`), swirl shader background, optional CRT filter (Options / pause menu: Off, Soft, Full) and particle effects. **No audio yet**, by owner direction.
- Screenshots without the editor: `python tools/shoot.py fixture.gd out.png 1920x1080` (see `tools/shoot.py`).

## Confirmed direction

The project owner chose a fixed-length run with bosses, mouse-first input, and colorful toy blocks in a distinct arcade interface with cooler effects and a retro vibe. Keyboard play should remain usable for accessibility; full controller support is a later milestone unless priorities change.
