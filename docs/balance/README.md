# Balance reports

Reports produced by `tools/experiments.gd`, a greedy, preview-guided autoplayer (`tools/autoplayer.gd`) run on paired seeds. Every variant plays the same seeds, and round 1 is re-dealt identically after setup. They justify the provisional numbers in the GDD (§5 targets, §7 and §16.6 Jokers, §16.3 upgrades). The bot is a **lower bound** for a human player: it barely sets up multi-line clears or combos, so it cannot judge those cards.

| File | When | What |
|---|---|---|
| `experiments_v1.md` | Pass 0 (2026-09-22) | First Joker and upgrade survey after retuning the targets. **Caveat:** in this run, variants with a setup re-dealt round 1 but the baseline did not, so small Δ values are unreliable. It still exposed the always-on outliers. |
| `exp_jokers.md`, `exp_upgrades.md` | Pass 2 | Paired survey after the first nerfs and stamp buffs, with the lookahead bot. |
| `exp_jokers_retune.md` | Pass 3 | Targeted check of Hollow Point, Pressure Cooker, Hoarder, and Recycler after the last trims. It supersedes those four rows in `exp_jokers.md`. |
| `exp_curve.md` | Final | Difficulty curve with the final numbers (100 seeds). |

Rerun everything after any balance change:

```bash
godot --headless --path . --script res://tools/experiments.gd -- jokers 40 1 res://docs/balance/exp_jokers.md
godot --headless --path . --script res://tools/experiments.gd -- upgrades 40 1 res://docs/balance/exp_upgrades.md
godot --headless --path . --script res://tools/experiments.gd -- curve 100 1 res://docs/balance/exp_curve.md
```

Set `BM_ONLY=id1,id2` to limit the Joker survey to a few cards. `BM_LOOKAHEAD` (default 300) and `BM_POTENTIAL` (default 0) tune the bot's heuristics.
