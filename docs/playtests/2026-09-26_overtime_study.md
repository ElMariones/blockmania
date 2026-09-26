# Overtime study: past round 12 — 2026-09-26

Owner request: "analyze now runs that continue over round 12 to see how the game takes shape after that and how long is reachable." Follow-up to the [release study](2026-09-26_release_study.md), with the same harness, participants and seeds. Every run that won round 12 pressed KEEP PLAYING and went on until it lost a round.

A designed version with charts: https://claude.ai/artifact/2RHL6RaC2hrygMVMXeurDf (private to the owner).

Full tables: [2026-09-26_overtime_study_tables.md](2026-09-26_overtime_study_tables.md). Tools: `tools/study.gd` (Overtime arms and the `overtime` flag), `tools/overtime_report.py`.

## 1. Verdict

1. **For most players Overtime is a short epilogue.**
   - Every competent group (engaged, expert and all five controlled arms) has a **median final round of 15**, clearing about 2–4 extra rounds.
   - One entrant in ten reaches round 17–21. That's about 5–16 extra minutes.
   - 43% of entrants are out before round 15, and 68% before round 16.
2. **Rounds 14–16 are a cliff.** Clear rates fall from 94% (round 11) to 69%, 57% and **47%** (round 16, the first Mk II boss). The cause is the jump in targets:

   | | Campaign (rounds 1–12) | Overtime rounds 13–16 |
   |---|---:|---:|
   | Target growth per round | about 1.3x | 1.76x, 1.91x, 2.10x, 2.16x |
   | Growth of a normal build's best placement | 1.1–1.7x | 1.5–1.8x |

   A build that isn't multiplying falls behind by about 20% per round and loses within 2–4 rounds.
3. **Past round 17 it becomes a different game, and only Legendary runs play it.**
   - Survivors clear 65–100% of rounds, because their builds grow as fast as the targets or faster.
   - Deep runs (final round 16+) hold **1.5 Legendaries** on average; runs that die in round 13 hold **0.19**.
   - Supernova is in 40% of deep runs and 0.5% of shallow ones; Hall of Mirrors is 40% vs 3%.
   - Every run past round 34 owned **all four Legendaries** plus 2–3 Hot Streak copies in a 7-slot rack.
   - Depth is decided by crate luck in rounds 8–16 more than by play.
4. **How long is reachable** (population, all entrants):

   | Round | 14 | 15 | 16 | 17 | 20 | 24 | 30 | 40 | 50 | 60 |
   |---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
   | Target | 42k | 88k | 187k | 393k | 3.3M | 44M | 1.6B | 414B | 83T | the limit |
   | Entrants still playing | 85% | 57% | 32% | 17% | 6.4% | 3.1% | 1.4% | 0.6% (6 runs) | 3 runs | 1 run |
   | Minutes from round 1 (median) | 20 | 21.5 | 23 | 25 | 31 | 43 | 57 | 71 | 115 | 216 |

   - The deepest fair run lost in round 60, with a best placement of 117T.
   - Five runs were still alive when the study's 4-hour session cap stopped them (rounds 33–51).
   - **Nobody broke the machine** in 1,409 Overtime runs plus 30 Legendary probes. The best single placement was 1.17 × 10^14, about 9x short of the 10^15 limit.
   - Targets reach the machine limit at **round 55**, so from there each round needs 10^15 points in total.
5. **The deep game turns into a grind rather than a fight.** Every cleared line refills a placement, and with The Avalanche almost every placement clears lines. So a deep round rarely ends by running out of placements; it ends when the score finally crosses the target.

   | Rounds | Placements per round (median) |
   |---|---:|
   | Campaign | 13 |
   | Overtime 13–20 | 19–24 |
   | 21–40 with Avalanche | 36–37 |
   | 41+ with Avalanche | 57 |

   Individual rounds reached **271, 309, 384, 470 and 1,359 placements**; the last is nearly two hours of play for one round. These runs don't lose; they slow down until the player gives up.
6. **Money stops mattering.** Credits left after each Overtime shop grow from 25 (after round 12) to 41 (round 16) to 73 (round 20+), against a cap of 99. There is nothing new to buy.
7. **Overtime bosses are all Mk II and much harder**, with a large spread:

   | Boss (Mk II) | Cleared in Overtime |
   |---|---:|
   | Color Blind (color Jokers off, two fewer placements) | **34%** |
   | Taxman | 51% |
   | Warden | 51% |
   | Cramped Cabinet | 60% |
   | Lockdown | 64% |
   | Undertaker | 66% |
   | Last Call | 70% |

   Color Blind Mk II is the most common run-ender among the bosses.

## 2. Method

- **Population:** the same 600 participants and seeds as the release study (1,800 runs), now continuing after a win. 926 entered Overtime.
- **Controlled arms (120 seeds each, 7001–7120, 483 entrants):**

  | Arm | Hands | Other habits |
  |---|---|---|
  | `ot_smart` | careful, one-step lookahead | shops by rarity, hoards items |
  | `ot_lite` | planner, narrow search | the release-study baseline |
  | `ot_expert` | full planner | baseline |
  | `ot_best` | full planner | expert item use, sensible round cards, avoids duplicates, rerolls 3 |
  | `ot_fresh_shop` | planner, narrow search | shop never re-offers owned Jokers or last visit's Jokers |

- **Ceiling probe** (`ot_legend_probe`, 30 seeds): starts with Hall of Mirrors, Supernova, The Avalanche, Snowball and Jackpot Window.
- **Caps:** round 80 and 3,000 placements per run (about 4 hours at 5 s per placement). Capped runs count as still alive.
- **Time estimates:** 5 s per placement, 43 s per round screen plus shop.
- **Build change during the study:** the `languages` branch was merged (commit `94934da`) while the batches ran. It changes text only, not rules. Five batches were re-run on it after a class-cache refresh.

## 3. Findings in detail

### 3.1 Depth by group

| Group | Won campaign | OT rounds cleared (mean) | Final round median / p90 / max | Minutes in Overtime |
|---|---:|---:|---|---:|
| first-timer | 1% | 0.0 | 13 / 13 / 13 | 2 |
| casual regular | 22% | 0.8 | 14 / 15 / 16 | 5 |
| engaged | 78% | 2.5 | 15 / 18 / 44 | 9 |
| expert | 85% | 4.1 | 15 / 21 / 60 | 16 |
| item lover | 86% | 1.7 | 14 / 16 / 20 | 7 |
| `ot_expert` | 83% | 2.2 | 15 / 17 / 21 | 8 |
| `ot_best` | 93% | 2.6 | 15 / 17 / 26 | 9 |
| `ot_fresh_shop` | 92% | 2.6 | 15 / 18 / 24 | 8 |
| Legendary probe | 100% | 8.8 | 20 / 28 / 36+ | 38 |

- Better habits raise the campaign win rate (83% → 93%) but barely move Overtime depth (median 15 either way).
- In Overtime, skill matters less than finding a multiplying engine.
- The Legendary probe doesn't beat the best natural runs. Its preset Snowball and Jackpot Window rarely trigger, so they only take up slots.

### 3.2 Round anatomy

| Round | Cleared | Best placement / target | Placements | Won with ≤2 left |
|---:|---:|---:|---:|---:|
| 11 | 94% | 0.32 | 13.4 | 8% |
| 12 (Last Call) | 85% | 0.32 | 13.4 | 19% |
| 13 | 86% | 0.27 | 17.2 | 14% |
| 14 | 69% | 0.23 | 21.1 | 18% |
| 15 | 57% | 0.18 | 24.2 | 25% |
| 16 (Mk II boss) | 47% | 0.15 | 25.3 | 24% |
| 17 | 65% | 0.24 | 23.9 | 16% |
| 20 (Mk II boss) | 67% | 0.25 | 24.7 | 18% |
| 24 (Mk II boss) | 74% | 0.38 | 35.1 | 12% |
| 28–34 | 88–100% | 0.21–0.44 | 43–66 | 0–8% |

- **Rounds 14–16 are the most tense of the whole game.** 18–25% of their wins come with two placements or fewer left, the only stretch that matches the Last Call.
- The best placement falls to 15% of the target by round 16. The build is being outrun, and rounds are won by long chains of line refills.
- After round 20, fewer and fewer rounds are close; rounds get long rather than tense.

### 3.3 What carries a run deep

| Joker | Held by deep runs (final 16+) | Held by runs lost in round 13 | Lift |
|---|---:|---:|---:|
| Supernova | 40% | 0.5% | 27x |
| Hall of Mirrors | 40% | 3% | 11x |
| Philosopher's Stone | 38% | 4% | 8x |
| Hot Streak | 26% | 7% | 3.4x |
| The Avalanche | 33% | 12% | 2.7x |
| Bonsai | 33% | 12% | 2.6x |
| Recycler | 30% | 37% | 0.8x |

- Deep runs also have more Joker slots (6.0 vs 5.4, from Rack Extender).
- Additive workhorses such as Recycler, Blue Mood and Coin Pusher are what shallow runs die with.
- **Hot Streak copies share one value**, and any Refresh or Second Tray resets it to x1. Several deep runs ended holding three Hot Streaks all at x1.0, which is three dead slots.

### 3.4 The grind

- Seed 67779 (expert participant), round 37: **1,359 placements, 588 clears**, a best placement of 3.7B against an 81B target, and it still won the round.
- The rack was Hall of Mirrors, Philosopher's Stone, Supernova, The Avalanche and three Hot Streaks at x1.0. Its placements were worth about 1/1,000 of the target, yet it couldn't run out of placements.
- The same pattern gives the 300–470-placement rounds in seeds 62203, 76038, 8009 and 8026.
- The GDD already rejected a Chunky Kit perk ("2 placements back per line") because "a round could run forever". The Avalanche combined with +1 placement per line recreates that in deep Overtime.

### 3.5 Milestones

Share of Overtime entrants whose best placement reached each milestone (population):

| Milestone | Reached |
|---|---:|
| 1M | 5.8% |
| 1B | 1.2% |
| 1T | 0.3% |
| 10^15 (break the machine) | 0% |

The 1M/1B/1T signposts are well spaced. The final one is out of reach in practice, and unlike the others it has no gentle path.

## 4. Recommendations

**P1: pacing (the grind)**

1. **Stop deep rounds from becoming endless.** Options:
   - Lines cleared by Avalanche chain waves don't refill placements; only the placement's own lines do.
   - Or: in Overtime, a round refills at most N placements in total (for example, the starting count).
   - Or: every Overtime round has a hard limit of 30 placements.

   Any of these turns "grind until the target" back into "win or lose". Test with the Legendary probe (`ot_legend_probe`) and the capped seeds (67779, 62203, 76038).
2. **Hot Streak:** say on the card that copies share one value and all reset on a Refresh, or make the reset lose half the value instead of all of it.

**P1: the round 14–16 cliff**

3. **Soften the step from 1.3x to 2x.** Options:
   - Use `12,500 × 1.5^k × (1 + 0.05k²)` for rounds 13–16, then the current curve.
   - Or give the first Overtime shop a guaranteed "Overtime crate" with one Legendary choice.

   Today depth depends on whether a Legendary happened to drop earlier. A guaranteed chance at round 12 would make Overtime a build decision.
4. **Color Blind Mk II** (34%) is the harshest boss by far. Drop its "two fewer placements" in Overtime, or give the other Mk IIs a comparable edge.

**P2: economy and goals**

5. **Give Overtime a Credit sink.** Players hold 40–75 unused Credits. Options:
   - an Overtime-only Legendary shop slot (priced 15–25);
   - paid Joker upgrades;
   - a Rack Extender beyond 7 slots at a steep price.
6. **Decide what the machine limit is for.** Nobody reached it in about 1,440 Overtime runs; the best was 9x short. Targets also reach 10^15 at round 55, so from there each round demands exactly the machine limit in total.
   - If breaking the machine should be the reward for a perfect Legendary run, raise the late Legendary synergy or lower the cap.
   - If it should stay mythical, keep it. Either way, show a "round 55: the machine's limit" milestone so the wall reads as a goal.

## 5. Reproducing

```bash
# Population with Overtime: participants, first id, output, runs each, "overtime"
godot --headless --path . --script res://tools/study.gd -- population 30 1 /tmp/pop_0.json 3 overtime
# An Overtime arm: ot_smart | ot_lite | ot_expert | ot_best | ot_fresh_shop | ot_legend_probe
godot --headless --path . --script res://tools/study.gd -- ot_best 60 7001 /tmp/ot_best_a.json
python tools/overtime_report.py out_dir /tmp/*.json
```

This study used 20 population jobs (ids 1–600, 3 runs each), 10 arm jobs of 60 seeds and 3 probe jobs of 10 seeds. The runs took about 70 minutes on 24 cores; deep runs dominate the time.
