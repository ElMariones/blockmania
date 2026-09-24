# BLOCKMANIA

**Status:** early M1 (playable; original pixel-art UI, CRT filter, VFX, audio) · **Engine:** Godot 4.7.2 stable (GDScript) · **Target:** premium desktop game on Steam

BLOCKMANIA is a single-player, turn-based block placement roguelike. Place pieces from your own customizable **bag** on an 8×8 board, clear complete rows and columns, beat escalating round targets, and build a run around rule-changing Jokers and upgraded pieces. The moment-to-moment puzzle should feel immediate; the run should reward planning, risk, and surprising combinations.

## Start here

1. [GAME_DESIGN_DOCUMENT.md](GAME_DESIGN_DOCUMENT.md): gameplay, progression, UI, presentation, and production specifications. §15 records the prototype's rule interpretations.
2. [TASKS.md](TASKS.md): live backlog, milestone progress, balance watch, open owner decisions.
3. [ASSET_PLAN.md](ASSET_PLAN.md): art, animation, audio, UI, and Steam deliverables.
4. [AGENTS.md](AGENTS.md): instructions for development agents and contributors (architecture, commands, workflow).

## Running the prototype

Open the folder in **Godot 4.7.2** and press Play (main scene `res://game/main.tscn`). A full 12-round run is playable: title, round intros, board and tray, score receipt, Jokers, items, bosses, shop, and run end. The run autosaves after every action; **Continue Run** on the title resumes it.

**Endless** is a separate arcade game from the main menu: place from a three-piece tray, clear rows and columns, build a combo up to x10, and play until no tray piece or already stored Hold piece fits. Each fresh tray has at least one legal option. Drag a selected piece into Hold or press H to store or swap it once per placement. Holding the last tray piece in an empty Hold deals three new pieces; Hold recharges after the next placement. An empty Hold cannot rescue a tray that is already stuck. The right rail opens 15 animated block styles (stained glass, neon, lava, chrome and more), each with its own glow, particles and sounds; two unlock through play. Endless saves independently, and pressing **Endless** with a game in progress asks whether to continue it or start a new one; there is also a local top-ten high-score view that includes run statistics and score graphs.

**Overtime:** beat round 12 and the win screen offers KEEP PLAYING. Rounds go on with targets that climb faster and faster and a boss every fourth round, until a round is lost. One placement worth 1,000,000,000,000,000 points breaks the machine and ends the run as a legendary win. Personal records (furthest round, best placement, best round, when the machine broke) are kept.

**Trophies:** 60 achievements across five pages (ten of them secret) with their own pixel badges, unlock fanfares and effects. TROPHIES on the title opens the Trophy Case with your records.

**Engine update (2026-09-24):** interest (+1 Credit per 5 held, max +5) and overkill payouts, multi-line clears add base Mult, Rack Extender (up to 7 Joker slots), 13 new Jokers (some grow for the whole run), 4 new items, and four unique **Legendary Jokers** (The Avalanche, Hall of Mirrors, Philosopher's Stone, Supernova) from Boss Crates and late shops. The design review that motivated it: `docs/playtests/2026-09-24_persona_playtest.md`.

Controls: drag a shape onto the board, or click a shape and then click a cell. Right-click or Esc cancels. Keyboard: `1`–`3` select a shape, arrows/WASD move it, Enter/Space place, `R` refresh, `B` shows your bag, `M` toggles sound, Esc pauses (in the shop too: SAVE & MAIN MENU returns to the title). In the Trophy Case, Q/E or PageUp/PageDown turn pages. Options (title or pause) has separate master, music and effects levels, sound/music switches, background mute, and Next Song.

Drag an owned Joker onto another Joker to reorder it in the campaign or shop. For keyboard use, focus a Joker and press Alt+Up or Alt+Down. Focus outlines appear during keyboard navigation and stay hidden during mouse use.

## Tests and tools

```bash
godot --headless --path . --import                                   # first time / after adding scripts
godot --headless --path . --script res://tests/run_tests.gd          # rule, determinism, save tests
godot --headless --path . --script res://tools/simulate.gd -- 200 1  # bot balance probe
godot --headless --path . --script res://tools/experiments.gd -- all 40 1 res://docs/balance/report.md  # paired-seed content experiments
godot --headless --path . --script res://tools/playtest.gd -- planner 60 1001 /tmp/planner.json  # persona playtest (see docs/playtests)
python tools/playtest_report.py out_dir /tmp/*.json  # persona tables
```

**Windows demo build.** The "Windows Desktop" preset in `export_presets.cfg` makes one self-contained `build/BLOCKMANIA_Demo/BLOCKMANIA.exe` (pck embedded, BLOCKMANIA icon and version info, no console) and leaves `tests/`, `tools/`, `docs/` and `assets/source/` out. It needs the official Godot 4.7.2 export templates (Editor > Manage Export Templates). Export from the editor (Project > Export), or headless with the editor closed:

```bash
godot --headless --path . --export-release "Windows Desktop" build/BLOCKMANIA_Demo/BLOCKMANIA.exe
```

The app icon (`icon.png` for the window, `icon.ico` for the exe) is generated by `python tools/art/gen_icon.py`.

## What exists

- Deterministic rules layer: seeded shape/shop/boss streams, the full scoring pipeline with an itemized receipt, 37/38 Jokers, 5/8 items, 5/6 bosses, economy, shop, replayable action history.
- **The Bag** (GDD §16): a visible, persistent set of pieces dealt through draw/discard piles, with materials (Chrome, Neon, Gold, Glass, Prism), stamps (Encore, Refund, Tip, Memory), Schematic family levels, a Workshop for copying/removing/rotating/repainting/upgrading pieces, and pieces for sale.
- Simulation tooling: a preview-guided autoplayer and paired-seed experiments; reports in `docs/balance/`.
- Original pixel-art UI generated as code (`tools/art/`), swirl shader background, optional CRT filter (Options / pause menu: Off, Soft, Full) and particle effects.
- Original synthesized SFX and seven ambient lo-fi tracks generated by `tools/audio/`; exported audio and provenance are listed in [AUDIO_MANIFEST.md](assets/audio/AUDIO_MANIFEST.md).
- Screenshots without the editor: `python tools/shoot.py fixture.gd out.png 1920x1080` (see `tools/shoot.py`).

## Confirmed direction

The project owner chose a fixed-length run with bosses, mouse-first input, and colorful toy blocks in a distinct arcade interface with cooler effects and a retro vibe. Keyboard play should remain usable for accessibility; full controller support is a later milestone unless priorities change.
