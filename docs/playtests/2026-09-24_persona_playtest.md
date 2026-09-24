# Persona playtest and design review — 2026-09-24

Owner request: "do playtests, multiple runs, multiple strategies, different seeds; analyze the game loop: is it fun, too easy, too hard, always the same; are there broken and satisfying games; write a complete report as a game designer, and plan how to make the game more addictive, satisfying and fun." Follow-up: "improve what the game lacks, add Jokers, items, four Legendary Jokers and achievements around them."

A designed version of this report with charts: https://claude.ai/artifact/TpHgviX138tC6JAxfJ6Eip (private to the owner).

This document is the review (baseline build `15a2dca`), what was changed because of it (the engine update, GDD §21), the re-test of the changed build, and the plan for what is left.

## 1. Verdict in one page

**The core puzzle is readable and the presentation is strong, but the roguelike half was flat.** Before this update:

1. **Numbers barely went up.** Points per placement grew about 6x over twelve rounds, while targets grew 22x. The game made up the gap by making rounds longer (8 placements in round 1, 16–23 in round 12), not by making builds explode. The best single placement was only 20–50% of the round's target at every stage. There were no "one placement wins the round" moments.
2. **There was no ceiling to chase.** The build stopped growing once the five Joker slots filled (round 4–5). Hand-picked "dream" builds ended Overtime by round 14–16, peaking at 158,000 points per placement. The machine's limit is 10^15, about ten orders of magnitude out of reach. Nobody could get "too broken".
3. **Multi-line clears, the block puzzle's own big moment, almost never happened.** For every player type they were 1–1.5% of placements. The opportunity probe shows why: a clear of two or more lines is *available* on only ~2% of placements, and three or more lines on 0.03%, however well you play. Six Jokers keyed to multi-line clears (Jackpot Window, Keystone, Crossbar, Wide Awake…) were dead draws.
4. **Difficulty was bimodal.** A careful but greedy player (the existing balance bot) won 10% of runs. A player who plans the whole tray and drafts on purpose won 75–87%, and rounds 1–11 were effectively free: a 98–100% clear rate, with 7–9 placements left at the win. Only the final boss (Last Call, 73% clear across personas) created real tension. A loose "newcomer" never won and died around round 6.
5. **Losses were slow and samey.** 83% of all losses were "out of placements": a round where you fall a few hundred points short. Bosses other than Last Call were non-events (92–99% cleared).
6. **The economy had no decisions late.** Credits piled up (23 on average by round 12 for the balance bot, 34 for the newcomer) because the rack was full and nothing else was worth buying.

**What is good and must be protected:**

- The skill ladder is long and clear: random placement dies in round 3, a newcomer in round 6, a greedy player in round 10, a planner wins. Skill is visible.
- Builds are varied. No Joker appears in more than 42% of winning planner builds, and 40–50 different Jokers show up in late builds.
- A run takes about 19–22 minutes, a good session length.
- Round 1 is a gentle tutorial: even random placement clears it 98% of the time.

**What was changed** (GDD §21; detailed in §5):

- Multi-line Mult.
- Interest and Overkill payouts.
- Rack Extender.
- Thirteen new Jokers, three of which grow for the whole run.
- Four new items.
- Six dead cards retuned.
- **Four Legendary Jokers** that bend the rules (a gravity cascade, Jokers that trigger twice, transmutation, a per-round supernova).
- Twelve new achievements.
- Targets for rounds 3–12 raised about 25%.

The re-test (§6) shows builds now grow through the run, the greedy player's win rate is back in its intended band, and Legendary runs can go very deep into Overtime.

## 2. Method

`tools/playtest.gd` plays full runs with simulated players (personas) on the same seeds (1001+), logging every round, placement and shop visit. Won runs continue into Overtime until they lose. `tools/playtest_report.py` aggregates the logs. Commands are in §8.

| Persona | Hands (placement) | Shopping | Runs |
|---|---|---|---:|
| random | a random legal placement | never | 60 |
| newcomer | takes a clear when it sees one, otherwise loose and noisy | first Joker it can afford; some items | 60 |
| steady | the existing balance bot: preview of each placement + one-step lookahead | by rarity, plus Workshop, pieces, items | 60 |
| planner | **searches whole-tray sequences with the real resolver** (it never peeks at the next tray) | "meta" card sense: buys strong cards, sells weak ones for better, rerolls | 60 |
| line_hunter, painter, engineer, minimalist, glassblower, tycoon, gambler | planner hands | a wishlist per archetype: multi-line, color, bag engine, thin bag, glass, economy, Tray Hands (Tetromino Kit) | 40 each |
| kit_compact / high_roller / chunky / tetromino | planner hands | meta | 40 each |
| dream_mixed, dream_dupes | planner hands, five strong xMult Jokers from round 1 | meta | 30 each |
| probe_steady, probe_planner | as steady / planner, also logging whether a 2+ or 3+ line clear was available at all | | 20 each |

**Limits of the method.** Bots are proxies: the planner is a strong, patient human who never misreads the board, and the newcomer is a first-hour player. No bot uses board tools (Eraser, Punch, Color Purge, Blueprint, Emergency Brick, Patch Panel) or reads Periscope. So cards that live on those (Patch Panel, Draftsman, Periscope, Tiny Insurance, Loan Shark, Breakage Bonus, Card Sharp) show 0% trigger rates by construction. They need human judgment. Time estimates assume about 5 s per placement, 35 s per shop and 8 s per round transition.

## 3. Baseline results (build 15a2dca)

### 3.1 Skill ladder and difficulty

| Persona | Win % | Avg round reached | Points / placement | Multi-line % of placements | Best placement (median / max) |
|---|---:|---:|---:|---:|---|
| random | 0% | 3.1 | 46 | 0.5% | 165 / 440 |
| newcomer | 0% | 6.0 | 88 | 0.6% | 428 / 2,160 |
| steady | 10% | 10.0 | 192 | 1.3% | 1,600 / 5,850 |
| planner | 82% | 11.9 | 351 | 1.3% | 4,419 / 34,020 |
| painter (color) | 82% | 11.9 | 384 | 1.1% | 7,717 / 13,927 |
| glassblower | 78% | 12.0 | 347 | 1.2% | 4,795 / 20,650 |
| engineer (bag engine) | 75% | 11.9 | 336 | 1.4% | 4,680 / 13,292 |
| minimalist (thin bag) | 68% | 11.7 | 315 | 1.2% | 3,569 / 11,358 |
| line_hunter (multi-line) | **38%** | 11.2 | 300 | 1.3% | 4,455 / 14,520 |
| dream_mixed | 87% | 12.0 | 489 | 1.0% | 8,255 / 157,920 |
| dream_dupes | 100% | 12.0 | 661 | 0.8% | 14,922 / 32,558 |

**Kits (planner hands):**

| Kit | Win % | Multi-line % | Points / placement |
|---|---:|---:|---:|
| Standard | 82% | 1.3% | 351 |
| Compact | 92% | 1.8% | 364 |
| High Roller | 85% | 1.2% | 368 |
| Chunky | **100%** | 2.3% | 429 |
| Tetromino | 92% | 1.9% | 419 |
| Tetromino + Hand build (gambler) | 85% | 2.3% | 422 |
| Economy build (tycoon) | 68% | 1.4% | 314 |

Every unlockable Kit is *easier* than the Standard Kit, and Chunky never lost. Bigger pieces fill lines faster and nearly double multi-line clears (2.3% vs 1.3%). That is a second lever on multi-line availability, and a reason to re-tune the Chunky bag (fewer 3×3s, or one fewer placement).

**Round anatomy, planner (baseline):**

| Round | Target | Clear % | Placements used | Left at win | Best placement / target |
|---:|---:|---:|---:|---:|---:|
| 1 | 450 | 100% | 7.2 | 10.2 | 0.39 |
| 4 (boss) | 1,150 | 100% | 9.1 | 8.9 | 0.46 |
| 8 (boss) | 3,700 | 100% | 12.3 | 7.6 | 0.45 |
| 11 | 7,500 | 100% | 14.3 | 6.7 | 0.44 |
| 12 (final boss) | 10,000 | 83% | 16.0 | 3.6 | 0.32 |

**Steady (the greedy player) needs more placements every round:** 8.3 → 12.6 → 17.5 → 22.8 placements to win rounds 1, 5, 8 and 12. The needed points per placement (target / 15) went 30 → 107 → 247 → 667, while its actual points per placement went 63 → 157 → 231 → 378. Early rounds give it twice the points it needs; late rounds rely on line refills to stay alive.

### 3.2 Is it fun? (reading the numbers as a designer)

- **Early game: relaxed but not boring.** First decisions are about the board, and a first clear lands within a few placements. Nothing is at stake before round 5 for a competent player, though. A player's first Jokers change little: the best placement is about a third of the target.
- **Mid game: the build takes over, but only additively.** After the rack fills (round 4–5, all personas), the only growth is bag upgrades and swapping cards. The payoff of drafting well is a smoother round, never a spectacular one.
- **Late game: a grind with one wall.** Rounds 10–12 take 15–23 placements and end within 10% of the target (score/target at the win is 1.07–1.21 in every round and persona: players stop the moment they cross). Blowouts (1.5x the target) happen in 0–12% of rounds. Tension comes from running out of placements, which feels like attrition rather than a duel.
- **Always the same?** The board is empty at the start of every round and the rules only change on boss rounds. Six of seven bosses are cleared 92–99% of the time. Tray Hands add variety to trays: Twins about 36 per run, Staircase 34, Monochrome 6, Triplets 0.7, Grand Slam about 0. The common two are noise; the rare two are the exciting ones.
- **Broken and satisfying runs?** No. The biggest single placement in 770+ baseline runs was 158,000 (a hand-picked dream build). No run passed Overtime round 16.

### 3.3 Strategies

| Archetype | Verdict |
|---|---|
| Color (Blue Mood, Color Cycle, Repaint, Prism) | **Strongest.** 82% wins, highest points per placement of the fair runs. Color Cycle triggers on 56–58% of placements. |
| Bag engine (Foundry, Chrome, Schematics) | Strong (75%). Foundry is the most common card in winning planner builds (25 of 49). |
| Glass | Strong (78%) thanks to Glass xMult plus Encore; Glass Cannon itself was nearly dead (1%). |
| Thin bag (Shredder, Lean Bag) | Viable (68%). Lean Bag is weak for its slot. |
| Multi-line (Jackpot Window, Wide Awake, Keystone, Crossbar) | **A trap (38%).** The cards almost never trigger: Jackpot Window and Crossbar 0%, Keystone 1%, Wide Awake 2%. |
| Duplicates (3x Compound Interest + 2x Hot Hand) | Strongest measured (100%, round 14.7 in Overtime), but it needs specific Joker offers. |

Always-on "value" cards dominate winning builds: Foundry, Recycler, Pressure Cooker, Compound Interest, Color Cycle, Patience and Collector. They are fine, but they reward buying rather than playing.

### 3.4 Shop and economy

- The rack is full by round 4–5 in every persona. After that, Joker decisions are only swaps.
- Credits at shop entry in act 1 are about 7.5. That buys one Joker or two small things, a good tension early. By round 12 the steady bot holds 23 Credits and the newcomer 34: money with no job.
- There was no interest or any other reason to save, so "spend it all" was always right.

### 3.5 Bosses (all baseline personas pooled)

| Boss | Cleared |
|---|---:|
| The Undertaker | 99% |
| The Color Blind | 98% |
| The Lockdown | 97% |
| The Warden / Cramped Cabinet | 93% |
| The Taxman | 92% |
| **The Last Call** (final) | **73%** |

### 3.6 Overtime and the ceiling

Every baseline Overtime ended between rounds 13 and 16, all "out of placements". Targets there grow about 2x per round, and the build had stopped growing at round 5.

## 4. Diagnosis

1. **Additive scoring with a capped rack means a flat power curve.** Balatro-like games get their late-game thrill from multiplicative stacking and cards that grow. BLOCKMANIA had almost none of either.
2. **The block puzzle's jackpot (multi-line clears) was structurally rare**, and when it happened it paid only a little more than two small clears.
3. **Economy without decisions.** No interest, no sinks, a full rack.
4. **Variety lives in the shop, not the rounds.** Every round starts the same way, and most bosses are soft.

## 5. What was changed (engine update, GDD §21)

| Problem | Change |
|---|---|
| Flat power curve | **Scaling Jokers** that grow for the whole run: Snowball (x0.15 per multi-line clear), Hot Streak (x0.3 per round won without a Refresh), Overachiever (+1 Mult per big round). Run-reading Jokers: Tally Counter, Bonsai, Coin Pusher. |
| Capped rack | **Rack Extender** Workshop card: up to 7 slots. Solo Act rewards the opposite (empty slots). |
| No ceiling, no broken runs | **Four Legendary Jokers:** The Avalanche (blocks fall after a clear; new lines chain as waves at x2, x4, x8…), Hall of Mirrors (every other Joker triggers twice), Philosopher's Stone (doubled materials; every plain piece placed turns to metal), Supernova (x1 + 0.5 per line cleared earlier in the round). |
| Multi-line clears paid little, and their cards were dead | +1 base Mult per extra line (a double is x2). Jackpot Window x2.5 on doubles; Keystone, Crossbar and Wide Awake re-keyed so they trigger on reachable clears; Demolition Crew pays per block cleared; Big Game Hunter rewards big pieces. |
| No money decisions | **Interest** (+1 per 5 held, max +5); **Overkill** (+1 per half-target beyond the target, max +3); Coin Pusher and Full Pockets turn saving into Mult. |
| Items were small | Turbo (x2 next placement), Tune-Up (Schematic from the tray), Coffee Break (+1 Refresh), Coin Roll (Credits = round number). |
| Weak or dead cards | Jackpot Window, Keystone, Crossbar, Wide Awake, Last Stand, Glass Cannon retuned. |
| Too easy for good players once the engine grows | Targets for rounds 3–12 raised: 450 / 650 / **900 / 1,200 / 1,800 / 2,400 / 3,300 / 4,400 / 5,700 / 7,300 / 9,300 / 12,500**. |
| Something to chase | Achievement page 5 "Legends": Legendary finds, Pantheon, Chain Reaction, Mirror World, Going Nova, Billionaire, and more. |

## 6. Re-test of the changed build

Same seeds, final numbers (engine update + raised targets). The Legendary probe gets three Legendaries from round 1: it measures the ceiling, not a fair run.

| Persona | Win % before → after | Avg round | Best placement before → after | Deepest Overtime before → after |
|---|---|---:|---|---|
| newcomer | 0% → 0% | 6.0 → 6.6 | 2,160 → 5,520 | – |
| steady | 10% → **18%** | 10.0 → 9.6 | 5,850 → 11,465 | 14 → 15 |
| planner | 82% → 83% | 11.9 → 11.9 | 34,020 → 434,396 | 15 → 20 |
| painter (color) | 82% → 90% | 11.9 → 11.9 | 13,927 → 2,976,750 | 16 → 23 |
| line_hunter (multi-line) | **38% → 63%** | 11.2 → 11.9 | 14,520 → 657,011 | 15 → 20 |
| dream (Legendary probe, 7 seeds) | 100% | 12.0 | 158k (best baseline probe) → **123,881,786,837,029** | 16 → **60+** (the harness stops at round 60) |

What changed in play:

- **Builds grow through the run.** The planner's median best placement doubled (4,419 → 10,585), its max Mult reached 976 (was 76) and its max xMult 146 (was 14). Painter runs reached a Mult of 13,669.
- **The greedy player's curve is healthier.** 18% wins, and its losses spread over rounds 7–12 (clear rates 86 / 73 / 83 / 83 / 76 / 58%) instead of piling up at the final boss. Placements needed in round 12 dropped from 22.8 to 18.5.
- **The multi-line build is now viable** (63%): base multi-line Mult plus the retuned cards. Multi-line clears are still rare (1.3–1.7%), so it is a build you steer toward, not a default.
- **The new Jokers get picked.** In winning planner, painter and line_hunter builds: Overachiever in 13, Snowball 9, Coin Pusher 5, Hot Streak, Demolition Crew and Tally Counter 4 each.
- **Legendaries are special, not standard.** None was owned by round 8 in any run. 17 of 82 winning runs (21%) had one at the win, mostly from the round-8 crate and act-3 shops. In Overtime, crates offer them more often.
- **Broken runs exist now.** The Legendary probe reached Overtime rounds 15, 19, 25, 27, 30 and 32 with 6- to 9-digit placements. One seed (1007) snowballed to round 60, where the harness stops, with a single placement worth 123,881,786,837,029: about 8x short of breaking the machine (10^15). The limit is now a real, rare goal rather than a number nobody can reach.
- **Still open:** the planner clears rounds 1–11 almost every time (100% except 97% at round 8). For experts, early tension has to come from stakes and round choice (plan §7), not from higher targets that would crush the newcomer. Late Credits grew for the greedy player (33 held at round 12, was 23): interest works, but the late shop needs more worth buying (Rack Extender helps; round choice and stakes more).

## 7. Plan: what to do next (prioritized)

**Now (next session):**

1. **Human playtest of the engine update.** Five friends, three runs each, logged. Check whether Legendaries feel special or mandatory, whether Avalanche chains read clearly on screen, and whether interest makes players hoard.
2. **A campaign Hold slot** (Endless has one). Multi-line availability is a board and tray property (~2% of placements). A Hold slot adds a fourth piece to plan around and should roughly double setups without changing the rules of a clear. Measure it with `probe_planner`.
3. **Give act bosses teeth.** Every act 1–2 boss is cleared 92–99% of the time. Options:
   - Double-strength variants when met in act 2 or later (Undertaker every 3rd placement; Warden bars two slots; Taxman also taxes Mult).
   - A boss target bonus (x1.2).
4. **Tray Hands rebalance.** Twins and Staircase fire on most trays and mean little. Rarer, bigger Hands (Monochrome, Triplets) are the fun ones. Consider making Twins give +1 Mult instead of +30 Chips, and raising Triplets and Monochrome odds with a "Card Sharp"-like common.

5. **Kit balance.** Chunky won every planner run and every unlockable Kit beat the Standard Kit. Trim Chunky (one fewer 3×3 or 14 placements) and give Compact and Tetromino a real cost.

**Next:**

6. **Round choice (Balatro's blind select, in our language).** Before each non-boss round, pick one of two "round cards", for example:
   - Standard.
   - *Gold Rush*: 6 Gold cells pre-placed, +3 Credits.
   - *Tight Budget*: 12 placements, +4 Credits.
   - *Rush Hour*: the target is 80%, but no Refresh.
   - Skip for a Tag (a free item or a Workshop coupon).

   This adds agency and variety to every round, not just the shop.
7. **Tutorial** (GDD §8). Round 1 already teaches by itself (random play clears it), so a guided first round plus contextual tips on the first shop, first Hand and first boss is enough.
8. **Daily seed and run history** (GDD launch scope): the strongest "one more run" hook after the build fantasy itself.

**Later:**

9. **Stakes / heat levels after a win** (difficulty ladder: fewer placements, harder bosses, higher interest cap).
10. **Joker unlocks tied to achievements**, so new cards enter the pool as you play (a slow drip of novelty).
11. **Overtime milestones:** records and toasts at 1M / 1B / 1T single placements, so the road to the machine's limit has signposts.

## 8. Reproducing

```bash
# One persona: runs, first seed, output
godot --headless --path . --script res://tools/playtest.gd -- planner 60 1001 /tmp/planner.json
# Tables from any number of logs
python tools/playtest_report.py out_dir /tmp/*.json
```

Full tables for every persona (per-round curves, bosses, Jokers in winning builds, trigger rates, shop numbers) are in `docs/playtests/2026-09-24_baseline_tables.md` (baseline) and `docs/playtests/2026-09-24_after_tables.md` (after the update).
