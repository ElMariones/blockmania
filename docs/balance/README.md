# Balance reports

Reports produced by `tools/experiments.gd`, a greedy, preview-guided autoplayer (`tools/autoplayer.gd`) run on paired seeds. Every variant plays the same seeds, and round 1 is re-dealt identically after setup. They justify the provisional numbers in the GDD (§5 targets, §7 and §16.6 Jokers, §16.3 upgrades). The bot is a **lower bound** for a human player: it barely sets up multi-line clears or combos, so it cannot judge those cards.

| File | When | What |
|---|---|---|
| `experiments_v1.md` | Pass 0 (2026-09-22) | First Joker and upgrade survey after retuning the targets. **Caveat:** in this run, variants with a setup re-dealt round 1 but the baseline did not, so small Δ values are unreliable. It still exposed the always-on outliers. |
| `exp_jokers.md`, `exp_upgrades.md` | Pass 2 | Paired survey after the first nerfs and stamp buffs, with the lookahead bot. |
| `exp_jokers_retune.md` | Pass 3 | Targeted check of Hollow Point, Pressure Cooker, Hoarder, and Recycler after the last trims. It supersedes those four rows in `exp_jokers.md`. |
| `exp_curve.md` | Pass 3 | Difficulty curve with the pass-3 numbers (12 fixed placements) (100 seeds). |
| `experiments_v2.md` | 2026-09-23 | Curve, Joker and upgrade survey (60 seeds) after the **placement refill** rework (15 placements, +1 per line up to the cap). Earlier reports used 12 fixed placements, so compare their Δ values only with each other. The curve now also reports loss reasons. |

Rerun everything after any balance change:

```bash
godot --headless --path . --script res://tools/experiments.gd -- jokers 40 1 res://docs/balance/exp_jokers.md
godot --headless --path . --script res://tools/experiments.gd -- upgrades 40 1 res://docs/balance/exp_upgrades.md
godot --headless --path . --script res://tools/experiments.gd -- curve 100 1 res://docs/balance/exp_curve.md
```

Set `BM_ONLY=id1,id2` to limit the Joker survey to a few cards. `BM_LOOKAHEAD` (default 300) and `BM_POTENTIAL` (default 0) tune the bot's heuristics.
