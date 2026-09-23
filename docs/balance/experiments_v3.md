# BLOCKMANIA content experiments

Mode `all`, 60 paired seeds from 1, greedy autoplayer (shop policy: full). Generated 2026-09-23T17:13:47.

## Difficulty curve (baseline)

Win rate 13%, average round reached 10.28, points per placement 204.5. Losses: { "out of placements": 52 }. Standard Kit: 15 placements, 1 refilled per line.

| Round | Target | Reached | Cleared | Clear % | Avg placements to clear | Avg final score |
|---:|---:|---:|---:|---:|---:|---:|
| 1 | 450 | 60 | 60 | 100% | 8.1 | 493 |
| 2 | 650 | 60 | 60 | 100% | 9.1 | 723 |
| 3 | 850 | 60 | 60 | 100% | 10.0 | 953 |
| 4 | 1150 | 60 | 58 | 97% | 11.3 | 1286 |
| 5 | 1600 | 58 | 58 | 100% | 11.9 | 1824 |
| 6 | 2100 | 58 | 57 | 98% | 13.5 | 2308 |
| 7 | 2800 | 57 | 56 | 98% | 15.4 | 3182 |
| 8 | 3700 | 56 | 48 | 86% | 16.5 | 3856 |
| 9 | 4700 | 48 | 45 | 94% | 18.6 | 4940 |
| 10 | 6000 | 45 | 34 | 76% | 19.9 | 6157 |
| 11 | 7500 | 34 | 21 | 62% | 19.9 | 7132 |
| 12 | 10000 | 21 | 8 | 38% | 20.4 | 8267 |

Workshop/piece purchases across the batch: { "copier": 51, "refund_stamp": 29, "neon_tubing": 70, "shredder": 46, "tip_stamp": 63, "piece": 245, "chrome_plating": 80, "gold_leaf": 35, "memory_stamp": 34, "encore_stamp": 38, "glassworks": 51, "schematic": 48, "repaint": 8, "prism_coat": 8 }

## Joker impact (card owned from round 1, paired seeds)

Baseline: avg round 10.28, win 13%, PPP 204.5.

| Joker | Rarity | Avg round | Δ round | Win % | PPP | Δ PPP | Trigger rate |
|---|---|---:|---:|---:|---:|---:|---:|
| Recycler | Uncommon | 11.65 | +1.37 | 27% | 263.4 | +58.9 | 92% |
| Foundry | Uncommon | 11.62 | +1.33 | 53% | 273.4 | +68.9 | 78% |
| Pressure Cooker | Uncommon | 11.55 | +1.27 | 23% | 257.3 | +52.9 | 72% |
| Color Cycle | Uncommon | 11.52 | +1.23 | 30% | 272.5 | +68.0 | 56% |
| Collector | Rare | 11.32 | +1.03 | 23% | 257.6 | +53.1 | 100% |
| Compound Interest | Rare | 11.20 | +0.92 | 17% | 232.4 | +27.9 | 12% |
| Blue Mood | Common | 11.18 | +0.90 | 22% | 254.9 | +50.4 | 27% |
| Patience | Uncommon | 11.15 | +0.87 | 18% | 246.7 | +42.3 | 24% |
| Chain Link | Common | 11.10 | +0.82 | 20% | 231.6 | +27.1 | 12% |
| Hollow Point | Uncommon | 11.02 | +0.73 | 18% | 242.0 | +37.6 | 93% |
| Hoarder | Uncommon | 10.93 | +0.65 | 13% | 229.6 | +25.1 | 100% |
| Straight Edge | Common | 10.87 | +0.58 | 13% | 218.4 | +13.9 | 40% |
| Last Piece | Common | 10.83 | +0.55 | 10% | 226.5 | +22.0 | 32% |
| Hot Hand | Rare | 10.78 | +0.50 | 18% | 225.9 | +21.4 | 42% |
| Showboat | Rare | 10.75 | +0.47 | 10% | 218.8 | +14.3 | 7% |
| Golden Ratio | Uncommon | 10.75 | +0.47 | 8% | 218.3 | +13.8 | 31% |
| Clean Sweep | Common | 10.73 | +0.45 | 17% | 215.5 | +11.0 | 26% |
| Corner Office | Common | 10.73 | +0.45 | 10% | 221.4 | +16.9 | 40% |
| Small Change | Common | 10.72 | +0.43 | 7% | 221.1 | +16.6 | 55% |
| Neon Sign | Uncommon | 10.70 | +0.42 | 17% | 213.0 | +8.5 | 9% |
| Insurance Policy | Rare | 10.63 | +0.35 | 8% | 193.6 | -10.9 | 0% |
| Architect | Common | 10.63 | +0.35 | 8% | 210.2 | +5.7 | 25% |
| Long Game | Uncommon | 10.55 | +0.27 | 10% | 186.5 | -18.0 | 6% |
| Square Deal | Common | 10.55 | +0.27 | 10% | 211.1 | +6.6 | 10% |
| Heavy Hand | Common | 10.47 | +0.18 | 7% | 199.0 | -5.4 | 7% |
| Spare Parts | Common | 10.47 | +0.18 | 10% | 197.6 | -6.9 | 0% |
| Neat Freak | Common | 10.43 | +0.15 | 12% | 207.4 | +2.9 | 42% |
| First Strike | Common | 10.42 | +0.13 | 8% | 207.8 | +3.3 | 7% |
| Countdown | Uncommon | 10.33 | +0.05 | 7% | 191.6 | -12.8 | 8% |
| Full Tank | Uncommon | 10.33 | +0.05 | 8% | 200.8 | -3.7 | 8% |
| Postmaster | Common | 10.25 | -0.03 | 10% | 190.8 | -13.7 | 10% |
| Glass Cannon | Rare | 10.23 | -0.05 | 7% | 193.9 | -10.6 | 4% |
| Mimic (+Wide Awake) | Rare | 10.22 | -0.07 | 15% | 218.8 | +14.4 | 2% |
| Wide Awake | Uncommon | 10.18 | -0.10 | 7% | 199.6 | -4.9 | 1% |
| Specialist | Uncommon | 10.17 | -0.12 | 8% | 189.6 | -14.9 | 7% |
| Lean Bag | Uncommon | 10.12 | -0.17 | 7% | 186.7 | -17.7 | 9% |
| Keystone | Rare | 10.05 | -0.23 | 7% | 184.7 | -19.8 | 0% |
| Last Stand | Rare | 9.97 | -0.32 | 7% | 182.6 | -21.9 | 0% |
| Mirror Maze | Rare | 9.95 | -0.33 | 7% | 184.9 | -19.6 | 2% |
| Loan Shark | Common | 9.93 | -0.35 | 7% | 181.9 | -22.5 | 0% |
| Periscope | Common | 9.93 | -0.35 | 7% | 181.9 | -22.5 | 0% |
| Overflow | Common | 9.93 | -0.35 | 7% | 181.9 | -22.5 | 0% |
| Patch Panel | Uncommon | 9.93 | -0.35 | 7% | 181.9 | -22.5 | 0% |
| Fire Sale | Uncommon | 9.93 | -0.35 | 7% | 181.9 | -22.5 | 0% |
| Jackpot Window | Rare | 9.93 | -0.35 | 7% | 186.5 | -18.0 | 0% |
| Locksmith | Uncommon | 9.93 | -0.35 | 7% | 181.9 | -22.6 | 0% |
| Crossbar | Common | 9.93 | -0.35 | 7% | 182.3 | -22.2 | 0% |
| Card Sharp | Uncommon | 9.93 | -0.35 | 7% | 181.9 | -22.5 | 0% |
| Second Look | Common | 9.93 | -0.35 | 7% | 181.9 | -22.5 | 0% |
| Tiny Insurance | Common | 9.93 | -0.35 | 7% | 181.9 | -22.5 | 0% |
| Breakage Bonus | Uncommon | 9.90 | -0.38 | 7% | 181.9 | -22.6 | 0% |
| Draftsman | Uncommon | 9.90 | -0.38 | 7% | 181.1 | -23.4 | 0% |

## Bag upgrades (applied to the starter bag before round 1, paired seeds)

Baseline: avg round 10.28, win 13%, PPP 204.5.

| Scenario | Avg round | Δ round | Win % | PPP | Δ PPP |
|---|---:|---:|---:|---:|---:|
| 4x Chrome (largest pieces) | 10.78 | +0.50 | 17% | 230.0 | +25.5 |
| 4x Neon (largest pieces) | 11.30 | +1.02 | 23% | 271.5 | +67.0 |
| 4x Glass (largest pieces) | 10.62 | +0.33 | 13% | 221.4 | +16.9 |
| 2x Gold (largest pieces) | 10.75 | +0.47 | 17% | 214.3 | +9.8 |
| 2x Encore Stamp | 10.50 | +0.22 | 12% | 218.5 | +14.0 |
| 2x Refund Stamp | 11.07 | +0.78 | 25% | 211.2 | +6.7 |
| 2x Tip Stamp | 10.82 | +0.53 | 10% | 215.3 | +10.8 |
| 2x Memory Stamp | 10.75 | +0.47 | 12% | 222.0 | +17.5 |
| Schematic: Bar 3 Lv 2 | 10.87 | +0.58 | 17% | 236.0 | +31.5 |
| Schematic: L 3 Lv 2 | 10.75 | +0.47 | 13% | 232.8 | +28.3 |
| Shred Zigzags + Plus (-3 pieces) | 10.43 | +0.15 | 10% | 206.8 | +2.4 |
| Copy both Singles (+2 pieces) | 9.63 | -0.65 | 8% | 189.3 | -15.1 |
| Add Square 3x3 + Bar 5 | 10.83 | +0.55 | 23% | 228.9 | +24.4 |
| Lean Bag + shred 6 pieces | 11.18 | +0.90 | 18% | 288.3 | +83.8 |
| Foundry + 6 Chrome | 12.00 | +1.72 | 67% | 387.9 | +183.5 |
| Neon Sign + 6 Neon | 11.95 | +1.67 | 55% | 392.3 | +187.8 |
| Specialist + Bar 3 Lv 3 | 11.52 | +1.23 | 25% | 299.4 | +94.9 |


_Elapsed: 7679 s_
