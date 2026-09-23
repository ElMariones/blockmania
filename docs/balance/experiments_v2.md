# BLOCKMANIA content experiments

Mode `all`, 60 paired seeds from 1, greedy autoplayer (shop policy: full). Generated 2026-09-23T14:44:12.

## Difficulty curve (baseline)

Win rate 2%, average round reached 9.28, points per placement 178.3. Losses: { "out of placements": 59 }. Standard Kit: 15 placements, 1 refilled per line.

| Round | Target | Reached | Cleared | Clear % | Avg placements to clear | Avg final score |
|---:|---:|---:|---:|---:|---:|---:|
| 1 | 450 | 60 | 60 | 100% | 9.0 | 492 |
| 2 | 650 | 60 | 60 | 100% | 9.8 | 737 |
| 3 | 850 | 60 | 60 | 100% | 10.4 | 967 |
| 4 | 1150 | 60 | 59 | 98% | 12.0 | 1272 |
| 5 | 1600 | 59 | 57 | 97% | 12.3 | 1763 |
| 6 | 2100 | 57 | 54 | 95% | 14.0 | 2414 |
| 7 | 2800 | 54 | 47 | 87% | 14.8 | 2958 |
| 8 | 3700 | 47 | 38 | 81% | 17.1 | 3770 |
| 9 | 4700 | 38 | 32 | 84% | 17.8 | 4830 |
| 10 | 6000 | 32 | 21 | 66% | 18.8 | 5761 |
| 11 | 7500 | 21 | 9 | 43% | 19.6 | 7121 |
| 12 | 10000 | 9 | 1 | 11% | 22.0 | 7437 |

Workshop/piece purchases across the batch: { "shredder": 45, "tip_stamp": 28, "piece": 138, "schematic": 30, "memory_stamp": 30, "prism_coat": 10, "glassworks": 29, "neon_tubing": 53, "gold_leaf": 28, "encore_stamp": 25, "chrome_plating": 48, "copier": 41, "refund_stamp": 30, "repaint": 5 }

## Joker impact (card owned from round 1, paired seeds)

Baseline: avg round 9.28, win 2%, PPP 178.3.

| Joker | Rarity | Avg round | Δ round | Win % | PPP | Δ PPP | Trigger rate |
|---|---|---:|---:|---:|---:|---:|---:|
| Foundry | Uncommon | 11.05 | +1.77 | 32% | 252.5 | +74.2 | 72% |
| Recycler | Uncommon | 11.02 | +1.73 | 3% | 242.4 | +64.2 | 92% |
| Pressure Cooker | Uncommon | 10.77 | +1.48 | 5% | 238.0 | +59.7 | 72% |
| Collector | Rare | 10.75 | +1.47 | 12% | 242.2 | +63.9 | 100% |
| Color Cycle | Uncommon | 10.48 | +1.20 | 17% | 252.5 | +74.2 | 55% |
| Hoarder | Uncommon | 10.40 | +1.12 | 3% | 219.2 | +40.9 | 100% |
| Hollow Point | Uncommon | 10.32 | +1.03 | 3% | 222.8 | +44.5 | 93% |
| Blue Mood | Common | 10.30 | +1.02 | 7% | 232.4 | +54.1 | 26% |
| Last Piece | Common | 10.27 | +0.98 | 2% | 220.1 | +41.9 | 31% |
| Straight Edge | Common | 10.08 | +0.80 | 0% | 207.7 | +29.4 | 39% |
| Corner Office | Common | 10.05 | +0.77 | 2% | 212.8 | +34.5 | 43% |
| Small Change | Common | 10.03 | +0.75 | 2% | 210.9 | +32.6 | 55% |
| Clean Sweep | Common | 9.95 | +0.67 | 2% | 203.4 | +25.1 | 26% |
| Compound Interest | Rare | 9.95 | +0.67 | 0% | 212.4 | +34.1 | 12% |
| Golden Ratio | Uncommon | 9.92 | +0.63 | 0% | 204.4 | +26.1 | 31% |
| Architect | Common | 9.72 | +0.43 | 0% | 198.0 | +19.8 | 26% |
| Spare Parts | Common | 9.65 | +0.37 | 5% | 181.4 | +3.1 | 0% |
| Neat Freak | Common | 9.63 | +0.35 | 2% | 196.0 | +17.8 | 43% |
| Chain Link | Common | 9.58 | +0.30 | 2% | 187.4 | +9.2 | 6% |
| Square Deal | Common | 9.55 | +0.27 | 0% | 191.5 | +13.2 | 10% |
| First Strike | Common | 9.52 | +0.23 | 0% | 197.3 | +19.0 | 8% |
| Long Game | Uncommon | 9.52 | +0.23 | 2% | 173.8 | -4.5 | 7% |
| Neon Sign | Uncommon | 9.42 | +0.13 | 10% | 191.2 | +13.0 | 7% |
| Mimic (+Wide Awake) | Rare | 9.33 | +0.05 | 0% | 198.9 | +20.7 | 2% |
| Wide Awake | Uncommon | 9.30 | +0.02 | 2% | 188.9 | +10.7 | 1% |
| Lean Bag | Uncommon | 9.22 | -0.07 | 0% | 174.7 | -3.5 | 15% |
| Heavy Hand | Common | 9.22 | -0.07 | 2% | 183.0 | +4.7 | 6% |
| Glass Cannon | Rare | 9.12 | -0.17 | 2% | 176.0 | -2.2 | 2% |
| Postmaster | Common | 9.10 | -0.18 | 2% | 172.7 | -5.5 | 8% |
| Mirror Maze | Rare | 9.08 | -0.20 | 2% | 170.6 | -7.7 | 2% |
| Specialist | Uncommon | 9.08 | -0.20 | 0% | 169.8 | -8.5 | 4% |
| Crossbar | Common | 9.00 | -0.28 | 0% | 167.3 | -11.0 | 0% |
| Last Stand | Rare | 8.98 | -0.30 | 0% | 167.5 | -10.7 | 0% |
| Jackpot Window | Rare | 8.98 | -0.30 | 2% | 170.2 | -8.0 | 0% |
| Fire Sale | Uncommon | 8.97 | -0.32 | 0% | 167.1 | -11.2 | 0% |
| Second Look | Common | 8.97 | -0.32 | 0% | 167.1 | -11.2 | 0% |
| Tiny Insurance | Common | 8.97 | -0.32 | 0% | 167.1 | -11.2 | 0% |

## Bag upgrades (applied to the starter bag before round 1, paired seeds)

Baseline: avg round 9.28, win 2%, PPP 178.3.

| Scenario | Avg round | Δ round | Win % | PPP | Δ PPP |
|---|---:|---:|---:|---:|---:|
| 4x Chrome (largest pieces) | 10.28 | +1.00 | 10% | 222.8 | +44.5 |
| 4x Neon (largest pieces) | 10.80 | +1.52 | 20% | 264.9 | +86.7 |
| 4x Glass (largest pieces) | 10.05 | +0.77 | 5% | 212.8 | +34.5 |
| 2x Gold (largest pieces) | 10.37 | +1.08 | 5% | 205.2 | +26.9 |
| 2x Encore Stamp | 9.68 | +0.40 | 3% | 203.1 | +24.8 |
| 2x Refund Stamp | 10.45 | +1.17 | 8% | 192.8 | +14.5 |
| 2x Tip Stamp | 9.90 | +0.62 | 5% | 199.2 | +20.9 |
| 2x Memory Stamp | 10.03 | +0.75 | 7% | 208.7 | +30.4 |
| Schematic: Bar 3 Lv 2 | 10.28 | +1.00 | 7% | 216.8 | +38.6 |
| Schematic: L 3 Lv 2 | 9.98 | +0.70 | 3% | 213.9 | +35.7 |
| Shred Zigzags + Plus (-3 pieces) | 9.60 | +0.32 | 2% | 189.1 | +10.8 |
| Copy both Singles (+2 pieces) | 8.47 | -0.82 | 2% | 165.7 | -12.5 |
| Add Square 3x3 + Bar 5 | 10.33 | +1.05 | 15% | 218.9 | +40.6 |
| Lean Bag + shred 6 pieces | 11.02 | +1.73 | 10% | 285.1 | +106.9 |
| Foundry + 6 Chrome | 11.93 | +2.65 | 65% | 378.9 | +200.6 |
| Neon Sign + 6 Neon | 11.77 | +2.48 | 30% | 376.2 | +197.9 |
| Specialist + Bar 3 Lv 3 | 11.08 | +1.80 | 7% | 281.0 | +102.7 |


_Elapsed: 5269 s_
