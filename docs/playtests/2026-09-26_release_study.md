# Release playability study — 2026-09-26

Owner request: "do tests, analyses and studies about playability, fun, game loop and entertainment; simulate different strategies, Jokers, combinations and shop items; list everything each run uses and doesn't use; do a complete audit as a professional designer testing a release with many participants; record and analyze the strategies; detect the games people play, inconsistencies and things to improve." The owner's own observations to check: *"I almost use 0 items"* and *"the Jokers repeat a lot; in one game I can easily collect two of the Joker I like."*

A designed version with charts: https://claude.ai/artifact/Qn1wd68XB2bRRX9CnowmCH (private to the owner).

Build `292051f`. Full tables: [2026-09-26_release_study_tables.md](2026-09-26_release_study_tables.md). Tools: `tools/study.gd` (simulation and ledger), `tools/study_report.py` (tables).

## 1. Verdict in one page

Both of the owner's observations are real, measurable and structural. Neither is a matter of taste.

1. **Items do nothing for a run.** Six paired-seed arms (the same 120 seeds each) tried every way of using items: never buying them, hoarding them, using them on impulse, using them sensibly, using them expertly, and buying every item offered. None of them won more often than never buying items: 79% win rate with no items, 75–78% with them. Three causes:
   - **Nine of the 15 items are rescues for a situation that almost never happens.** Only **0.2% of rounds** ever reach "nothing fits", and the free Refresh or Hold fixes those. **95% of losses are "out of placements"**, which only Extra Turn can help. Eraser, Punch and Color Purge were used in **0.1–0.5%** of the runs that owned them.
   - **The boosts are small, flat and shrink over the run.** Spark adds a median 14% of the round target in act 1 but 4% in act 3. Polish drops from 12% to 8%. Only Turbo (x2) keeps its value, at ~16–21%. Rounds are won with ~7 placements to spare, so one boosted placement rarely changes the outcome.
   - **Credits are better spent elsewhere.** A 3–5 Credit item is used once. A Workshop card or Joker at the same price lasts the whole run.

   Behaviour matches the owner's: **49% of runs owned items and never used one**, and **37% of all runs ended in a loss with an unused item still in the slot**.
2. **Jokers repeat, and duplicates are a trap.**
   - In a typical run, **one Joker is offered 3 or more times in 70–76% of runs**.
   - **A Joker you just bought comes back in a later shop 30–33% of the time**, a median of 3 rounds later.
   - **About one shop visit in five** offers a Joker you already own.
   - A player who likes stacking copies ends up with a duplicate in **83% of runs** (95% on a fresh profile, where 14 Jokers are still locked and the pool is smaller).
   - **Stacking duplicates makes runs weaker, not stronger.** A player who never buys copies wins 85%, one who stacks wins 76% (paired, p = 0.02). The repeats cost the player variety and power without adding strategy.
   - A shop that never re-offers owned Jokers changes nothing in balance (80% vs 80% on the same seeds). The "fresh" variant, which also skips the previous visit's Jokers, cuts "one Joker 3+ times" from 70% to 37%.
3. **Round cards are free money, not a choice.** Twist rounds are cleared as often as Standard rounds:
   - Double or Nothing (x1.4 target): 96.3%.
   - Tight Budget (3 fewer placements): 95.6%.
   - Standard: 96.8%.

   A player who picks twists sensibly wins **89% instead of 79%** (p = 0.03). They reach the last shop with **44–46 Credits instead of 20**. Rush Hour is the only unattractive card and is almost never picked.
4. **The middle of the run is low-tension.**
   - Rounds 1–11 are cleared 91–100% of the time.
   - Rounds are won at 1.16–1.20x the target, with 7–9 placements left.
   - Only 5–11% of wins are blowouts (1.5x or more).
   - Five of the six act bosses are cleared 91–98% of the time. **The Last Call (round 12) is the only wall** at 84%.
   - Multi-line clears are still 1.1% of placements.
   - The Joker rack is full by round 4 in 76% of runs and by round 5 in 98%. From then on, Credits pile up: 15–20 left over per late shop, 26% of runs bank 25+.
5. **There is a steep skill cliff.** With the same shop brain:
   - A loose first-timer wins **1%** and dies around round 6 at 79% of the target.
   - A careful but greedy player wins **22–29%**.
   - A planner wins **77–85%**.

   The game teaches its board well but not its build.
6. **Two real bugs**, found by the simulation (§5):
   - **Soft-lock:** Tiny Insurance can drop its rescue Single into the Warden's barred slot. Nothing can then be placed, and Concede is refused.
   - **Warden Mk II never frees its second barred slot** during the round.

**What is healthy and must be protected:** runs last ~16–18 minutes, and the skill ladder is visible. Builds are varied: scaling (86% win), color (79%), multi-line (76%) and bag-engine (72%) are all viable. Legendaries feel special: they are taken from 90% of the crates that offer them and win 78–95% when kept. Workshop cards are bought constantly.

## 2. Method

`tools/study.gd` plays full campaign runs through the real rules (`BMRun`) and logs a ledger for every run:

- every shop fill: the three Jokers, two items, two Workshop cards and two pieces, and whether each Joker offer was one the player already owned;
- every purchase, sale, reroll, crate pick and round-card pick;
- every item: how it was obtained (shop, crate, Vending Machine or Treasure Hunt, Memory stamp, Draftsman), when and why it was used (boost, rescue, setup, economy), how many points a boost added to the placement it was used on, and what was still held at the end;
- every round: target, score, placements used and left, clears, multi-line clears, the longest streak without a clear, placements worth 25%+ of the target, Refreshes, Holds, emergencies, the round card and the boss;
- final Jokers, bag, credits and statistics.

Won runs stop at the campaign win (no Overtime).

### 2.1 The participant population (600 people, 3 runs each, 1,800 runs)

Each synthetic participant gets an archetype, then sampled habits. All seeds are fixed, so the study reproduces exactly.

| Archetype | Share | Hands | Shopping | Items | Round cards | Duplicates | Profile |
|---|---:|---|---|---|---|---|---|
| first_timer | 20% | loose: sees clears, otherwise noisy | buys the first Joker it can afford | hoards (60%) or uses on impulse | mostly Standard | neutral | fresh (14 Jokers locked) |
| casual_regular | 25% | careful, one-step lookahead (the old balance bot) | by rarity, or first affordable | hoards / impulse / sensible | random or greedy | 40% stack copies | half fresh |
| engaged | 30% | plans the tray, narrow search | card sense plus a favorite style (color, multi-line, bag, economy, scaling, shape, xMult) | hoards / sensible / never | sensible, Standard, or greedy | stack 50% / avoid 20% | 30% fresh |
| expert | 15% | plans the whole tray | card sense + favorites, rerolls 1–4 | sensible / expert / hoards | mostly sensible | 60% stack | unlocked |
| item_lover | 10% | careful or planning | card sense | expert, buys 80% of items, no Credit reserve | sensible or random | neutral | half fresh |

Item habits:

- **hoarder:** buys some items and uses them only when the game forces it (stuck, or out of placements).
- **impulse:** uses boosts on the next placement whatever it is.
- **smart:** uses boosts on clearing placements, Tune-Up at once, Cash Out and Coin Roll at once, Second Tray or Coffee Break on dead-end trays.
- **savvy:** adds Turbo saved for multi-line or boss moments, and Blueprint or Brick to create a clear.
- Everyone uses rescue items when stuck. The bot targets Eraser, Punch and Purge by searching for the removal that makes the most tray pieces fit.

### 2.2 Paired-seed experiments (23 arms × 120 seeds, 2,760 runs)

Same player in every arm: a planner with a narrow search, card-sense shopping, sensible items, Standard round cards, neutral on duplicates. Each arm changes one habit. The shop variants `no_owned` and `fresh` are simulated inside the harness; the game is unchanged. Differences are tested with an exact two-sided sign test on the seeds where the two arms disagree.

### 2.3 Limits

- Bots never misread the board or forget an item. They do not feel UI friction, which probably makes real item use *lower* than simulated.
- Bots cannot judge Turntable (never bought), Periscope, Card Sharp, Patch Panel or Draftsman.
- Bots avoid holes, so Locksmith is undervalued.
- The Workshop share of spending (43%) reflects the bots' taste for it.
- Time estimates assume 5 s per placement, 35 s per shop and 8 s per round screen.

## 3. Findings in detail

### 3.1 Items (owner: "I almost use 0 items")

**Experiment E1: does using items help?** All six arms have the same player, differing only in item habit.

| Item habit | Win | Final boss cleared | Items used/run | Credits on items/run | vs never |
|---|---:|---:|---:|---:|---|
| never buys | **79.2%** | 87.2% | 0 | 0 | — |
| hoarder | 77.5% | 83.0% | 0.1 | 5.5 | −2 seeds (p 0.82) |
| impulse | 75.8% | 82.7% | 2.9 | 11.4 | −4 (p 0.45) |
| smart | 75.8% | 85.0% | 2.5 | 10.5 | −4 (p 0.45) |
| savvy | 76.7% | 82.1% | 3.1 | 11.3 | −3 (p 0.66) |
| buys everything | 75.0% | 82.6% | 2.6 | 8.3 | −5 (p 0.46) |

No way of playing items beats ignoring them.

**Why:**

| Item | Obtained | Used / obtained | Held at run end | Value when used |
|---|---:|---:|---:|---|
| Spark | 4,943 (72% from the Memory stamp) | 87% | 661 | 14% of target (act 1) → **4%** (act 3) |
| Polish | 875 | 85% | 134 | 12% → **8%** |
| Turbo | 774 | 85% | 115 | 21% → 16% (the only one that scales) |
| Cash Out / Coin Roll / Tune-Up | ~850 each | 85% | ~120 | economy / a Schematic level |
| Extra Turn | 692 | 30% | 484 | the only rescue that matches how runs are lost |
| Lucky Paint | 587 | 45% | 321 | only with Blue Mood |
| Blueprint | 662 | 15% | 562 | |
| Emergency Brick | 762 | 10% | 687 | |
| Second Tray | 914 | **1.6%** | 899 | |
| Coffee Break | 862 | **2.1%** | 844 | |
| Eraser | 754 | **0.4%** | 751 | |
| Punch | 780 | **0.5%** | 776 | |
| Color Purge | 762 | **0.1%** | 761 | |

- **The failure the rescue items answer does not happen.** Only 29 of 18,532 rounds (0.2%) ever reached "nothing fits" with the free Refresh gone. The legality guarantee, Hold, the refill budget and a free Refresh make a no-fit loss rare: 2.3% of all losses. **95% of losses are "out of placements"**, a points shortfall that only Extra Turn answers.
- **Board tools remove blocks but score nothing and never set up a clear.** They are pure insurance for that 0.2% case.
- **Boosts are flat numbers in a game whose numbers grow 20x.** Spark's +1 Mult is a big deal at Mult 2 and noise at Mult 40.
- **Items compete with permanent power.** A common Joker costs the same 3 Credits and scores on every placement for the rest of the run.
- **Hoarding is the natural human reaction** to a one-shot tool with an unclear value. The item card shows no preview ("+312 points on this placement") before it is used.

### 3.2 Joker repetition and duplicates (owner: "Jokers repeat a lot")

The shop only excludes Jokers already in the same shop and owned *unique* (Legendary) Jokers. Any owned Joker can be offered again (`BMRun._pick_joker`). Commons are drawn 65% of the time in act 1 from a pool of 24.

| Measure | Fresh profile | All unlocked | Harness: never offer owned | Harness: also skip last visit's |
|---|---:|---:|---:|---:|
| Joker offers per run | 32.5 | 32.6 | 32.5 | 32.7 |
| Distinct Jokers seen | 24.7 | 25.5 | 26.7 | 27.8 |
| Offers repeating an earlier offer | 23.9% | 21.6% | 17.8% | 15.0% |
| Runs where one Joker is offered 3+ times | **75.8%** | 70.8% | 55.0% | **36.7%** |
| Shop visits offering a Joker you own | 21.6% | 17.4% | 0% | 0% |
| Runs ending with a duplicate (player likes copies) | **95.0%** | 82.5% | 4.2% | 5.8% |
| Win | 74.2% | 77.5% | 80.0% | 81.7% |

- A Joker you buy is offered again in a later shop in **33%** of cases, a median of **3 rounds** later. The owner's experience ("I can easily collect two") is the norm: a player who wants the copy buys it 75% of the time.
- **Duplicates do not pay.** Avoiding copies wins 85.0%, neutral 80.0%, stacking 75.8%. Avoid vs stack: +4 / −15 seeds, **p = 0.02**. Stacking copies of a favorite xMult card: 81.7%.
  - The most-doubled cards are the additive workhorses: Recycler, Foundry, Blue Mood, Color Cycle, Coin Pusher, Bonsai, Snowball and Pressure Cooker.
  - A second Recycler adds +1 Mult, where a new card would add a second axis.
- **A new player sees the most repetition.** With 14 Jokers locked, the rare pool shrinks from 15 to 10 and the uncommon pool from 27 to 22.
- **Removing repeats is balance-neutral:** 96 vs 96 wins on the same seeds for `no_owned`, 96 vs 98 for `fresh`.

### 3.3 Round cards

| Card | Picked (population) | Cleared |
|---|---:|---:|
| Standard | 8,737 | 96.8% |
| Double or Nothing (x1.4, +6) | 2,157 | 96.3% |
| Tight Budget (−3 placements, +4) | 1,849 | 95.6% |
| Gold Rush (+2) | 1,333 | 99.0% |
| Scholarship (x1.2, a Schematic level) | 1,074 | 97.4% |
| Treasure Hunt (x1.15, an item) | 611 | 95.5% |
| Mult Fever (x1.3, +1 Mult) | 630 | 98.4% |
| Rush Hour (x0.8, no Refresh) | 342 | 98.2% |

| Card habit (same seeds) | Win | Final boss | Credits entering the last shop |
|---|---:|---:|---:|
| always Standard | 79.2% | 84.8% | 19.7 |
| random | 85.8% | 92.8% | – |
| greedy (highest reward) | 84.2% | 94.4% | 46.0 |
| sensible (reward when the last round had slack) | **89.2%** (p 0.03) | 96.4% | 44.1 |

- The twists that pay are never risky, because rounds 1–11 are won with 7+ placements spare. Taking a twist is a strict improvement.
- The twist Credits have nowhere to go, because the rack is full. They show up as a 44-Credit bank at the end.
- Rush Hour's reward, a lower target, is worth nothing when the target is already easy. Gold Rush (99% cleared, +2 Credits and the Gold payout) is the safest money in the game.

### 3.4 Pacing and tension (population)

| Round | Cleared | Placements | Left at win | Won with ≤2 left | Score/target | Won at 1.5x+ |
|---:|---:|---:|---:|---:|---:|---:|
| 1 | 99.8% | 8.0 | 9.1 | 0.4% | 1.19 | 11.2% |
| 4 (boss) | 98.2% | 9.4 | 8.5 | 3.2% | 1.20 | 8.5% |
| 6 | 94.2% | 11.2 | 7.6 | 6.9% | 1.17 | 5.6% |
| 8 (boss) | 91.3% | 12.7 | 7.2 | 7.8% | 1.17 | 5.8% |
| 11 | 93.1% | 13.7 | 7.0 | 8.4% | 1.16 | 5.7% |
| 12 (Last Call) | **83.7%** | 13.7 | 5.0 | **20.4%** | 1.18 | 8.6% |

- **Close wins are rare until the final boss** (≤2 placements left in 0–9% of wins). **Blowouts are rarer still** and get rarer as the run goes on. The typical round ends at 1.17x the target with seven placements unused: "comfortably done", not "just made it" or "crushed it".
- Losses are fair but slow. 28% of losses are within 10% of the target (exciting near-misses). The rest are attrition.
- The longest dry spell averages 5 placements without a clear in every round. 19–28% of placements clear a line.
- Bosses: Last Call 84%, Color Blind 91%, Warden 93%, Taxman 94%, Lockdown 97%, Cramped Cabinet 98%, Undertaker 98%. Mk II versions from act 2 did not change the picture much.
- Tray Hands per run: Twins 24 and Staircase 20 placements (background noise), Monochrome 2.6, Triplets 0.5, Grand Slam 0.0.
- Feats per 100 runs: Double Tap 885, Last Breath 53, Clean Board 13, Crossfire 11, Needle Threader 4, Hat Trick 2.

### 3.5 Economy and shop

| After round | Credits in | Spent | Left with | Rack full on entry | Bought nothing |
|---:|---:|---:|---:|---:|---:|
| 1 | 6.1 | 4.9 | 1.2 | 0% | 0.4% |
| 4 | 10.3 | 4.1 | 6.1 | 77% | 16% |
| 8 | 21.1 | 5.7 | 15.4 | 99% | 12% |
| 11 | 30.2 | 10.3 | 19.9 | 98% | 7% |

- Act 1 has healthy money tension. From round 5 the only Joker decision is "is this better than my worst card?"
- Credits pile up: interest plus round-card rewards, with nothing new to buy. Spending by kind: Workshop 43%, Jokers 39%, pieces 10%, items 7.5%.
- The late shop has no new kind of purchase; Rack Extender (9 Credits, up to 7 slots) is the only sink that grows the build. Workshop cards are bought at 60–68% of offers, except:
  - Turntable: never bought (the bot cannot judge it; human check needed).
  - Repaint: 18%.
  - Schematic: 25%.
  - Prism Coat: 28%.

### 3.6 Joker health

Full table in the tables file, §E.

- **Auto-picks** (bought in 60%+ of offers, win 75–95% when kept): Recycler, Foundry, Color Cycle, Pressure Cooker; Bonsai (94% win when kept) and Hot Streak (89%).
  - They are "always on" value cards that reward buying rather than playing.
  - Bonsai and Hot Streak grow with rounds won, so they reward simply surviving.
- **Rarely bought** (under 5% of offers): Mirror Maze 1.1%, Solo Act 1.0%, Double Stamp 1.2%, Patch Panel 2.4%, Card Sharp 2.5%, Glass Cannon 2.8%, Breakage Bonus 3.1%, Lean Bag 3.4%, Draftsman 3.5%, Fire Sale 3.7%, Mimic 4.3%, Periscope 4.5%.
  - These are 12 of the 70 cards, but they take up **~1 in 7 Joker offers** (13.6%), which adds to the feeling that "the shop has nothing for me".
- **Almost never trigger** while owned:
  - Locksmith 0.1% (bots avoid holes);
  - Crossbar 1.3% and Jackpot Window 1.7% (multi-line clears are 1.1% of placements);
  - Postmaster 2.9%.
  - Fire Sale: 0% in 94 runs. It works (verified directly) but only pays after selling *other* Jokers, and owners of it almost never sell.
- **Common-slot filler:** Corner Office, First Strike, Neat Freak, Architect, Second Look, Tiny Insurance and Postmaster are kept in winning runs 9–20% of the time. Commons are drawn most often, so this filler is what players see most.

### 3.7 Strategies and "games people play"

| Final build (population) | Runs | Win |
|---|---:|---:|
| scaling (Hot Streak, Overachiever, Bonsai, Tally) | 131 | **86%** |
| color | 132 | 79% |
| multi-line | 219 | 76% |
| bag engine | 365 | 72% |
| economy | 272 | 41% |
| shape | 243 | 28% |
| generalist (no theme) | 429 | 22% |

| Behaviour | Share of runs | Win |
|---|---:|---:|
| plays a round twist | 77% | 58% |
| full Joker rack by round 4 | 76% | 54% |
| sells a Joker to upgrade | 56% | 81% |
| stacks a duplicate | 50% | 70% |
| owns items, never uses one | 49% | 53% |
| dies holding items | 37% | 0% |
| rerolls 3+ times | 30% | 84% |
| banks 25+ Credits late | 26% | 45% |

- **Economy and shape builds underperform.** Economy Jokers turn Credits into Mult or Credits, but Credits have nothing to buy late. Shape Jokers (Small Change, Heavy Hand, Architect, Straight Edge, Square Deal) are flat Chips that fade. These are also the builds a new player falls into by buying the first affordable Joker.
- **Selling to upgrade and rerolling are what strong players do.** The game rewards shop literacy more than board skill after round 5.

## 4. What to change (prioritized)

**P0: bugs (before any external playtest)**

1. Tiny Insurance must not place its Single in a Warden-barred slot. Pick the first *unlocked* non-empty slot, or skip the barred ones. Add a regression to the Warden E2E. Also confirm the no-fit check can never leave `PLAYING` with zero legal moves: the UI shows no Concede in that state.
2. Warden Mk II: decide whether the first clear frees both barred slots, one per clear, or neither. The resolver frees only `locked_slot`. Update the GDD rule text and the HUD message to match.

**P1: items (owner's complaint)**

3. **Retire or merge the rescue-only items.** Keep one board tool: *Eraser*, reworked to remove up to 3 blocks and give +1 placement. Replace Punch, Color Purge, Coffee Break, Second Tray and Emergency Brick with items that answer "out of placements" or build toward clears. For example:
   - *Overtime Ticket*: +3 placements;
   - *Line Primer*: the next clear counts one extra line;
   - *Hold+*: a second Hold slot this round.
4. **Make boosts scale.** Polish: +25 Chips × round number. Spark: +1 Mult per act. Or make both multiplicative (x1.3 / x1.5), like Turbo, the only item that stays relevant.
5. **Show the value before use.** While a piece is dragged, a held boost shows "+N with Polish" on the preview, and the item card shows its live value. Without it, hoarding is the rational reaction.
6. **Lower the stakes of holding.** Options:
   - Items sell for 1 Credit.
   - Unused items at round end give +1 Credit.
   - A tip after a win while holding an item: "Items are one-use: spend them".
7. Consider three item slots only after items are worth using.

**P1: shop repetition (owner's complaint)**

8. **Do not offer non-unique Jokers the player owns**, or weight them down strongly (x0.2). It is balance-neutral (§3.2).
9. **Down-weight Jokers shown in the previous visit** (the `fresh` variant). It halves "one Joker offered 3+ times" (70% → 37%) and adds ~2 new Jokers per run.
10. Mark a shop card you already own with an **OWNED** tag. If copies stay possible, make a copy *upgrade* the card (for example, "+50% effect") instead of a flat second instance, so the choice has a reason.
11. Trim or rework the commons nobody keeps, so the most common rarity is not the weakest.

**P1: round cards**

12. Make twists a real bet:
   - Double or Nothing x1.4 → x1.7;
   - Tight Budget −3 → −5 placements;
   - Gold Rush reward +2 → +1.

   Or scale twist targets with the player's last-round margin.
13. Give Rush Hour a Credit reward (+3), or replace it.

**P2: pacing and late game**

14. **Give Credits a late job.** Late-shop sinks with a reason to save:
   - buy a Joker "edition" or upgrade;
   - a paid "Joker level up";
   - buy an extra item slot;
   - a rarer, pricier Workshop tier after act 2.
15. **Sharpen act bosses.** Five of six sit at 91–98%. Give each act boss a target bump (x1.15), or make Mk II start in act 1 at Heat 1+.
16. **More "just made it" and "crushed it" moments in the middle rounds:**
   - Overkill pays up to +3 Credits today; show it more loudly.
   - Hot Streak-style rewards for finishing with many placements left, so strong players go for style.
17. Rare Tray Hands (Monochrome, Triplets, Grand Slam) are the exciting ones and almost never happen. Double their odds, or tie a common Joker to them.

**P2: onboarding and the skill cliff**

18. First-timers stall at round 6 with 4–5 Jokers bought at random. Options:
   - POPS could recommend one "theme" Joker in the first shops.
   - A "synergy" hint on shop cards ("works with your Blue Mood").
   - Hide the weakest commons from a fresh profile's pool.

## 5. Bugs and inconsistencies found

| # | Kind | Where | What |
|---|---|---|---|
| 1 | **Bug (soft-lock)** | `BMRun._evaluate_round`, Tiny Insurance branch | The rescue Single replaces the first non-empty slot, which can be the Warden's barred slot. The round then stays `PLAYING` with no legal move, and `concede_round` refuses. Reproduced: participant 201, seed 53417, round 8 (Warden Mk II). |
| 2 | **Bug or undocumented rule** | `BMResolver` step that frees the Warden slot | Only `locked_slot` is freed on the first clear. `locked_slot2` (Mk II) stays barred all round, and the HUD message names only one slot. |
| 3 | Doc drift | GDD §22.4 vs `BMRunConfig.KITS` / §6 | §22.4 says Compact, Chunky and Tetromino start with 14 placements and Chunky lost its 3×3. The code (and §6) has Compact 16 and Chunky 13, and the Chunky bag still contains a Square 3×3. |
| 4 | Doc drift | GDD §6 "Credits and shop" | Says rarity weights shift "toward 40/40/20". The code is 40/40/19/1 (Legendary). Minor. |
| 5 | Design gap | GDD §7 Consumables | Describes board tools as rescues, but the no-fit state they rescue from happens in 0.2% of rounds. |
| 6 | Design trap | Fire Sale | Pays only after selling *other* Jokers; 0 triggers in 94 owning runs. Its text is correct. |
| 7 | Known (TASKS) | README / round_play_update.md | Joker count and Twins text, already listed in TASKS. |

## 6. Reproducing

```bash
# Population: participants, first id, output, runs each
godot --headless --path . --script res://tools/study.gd -- population 30 1 /tmp/pop_0.json 3
# One experiment arm: arm, runs, first seed, output (arms listed in tools/study.gd ARMS)
godot --headless --path . --script res://tools/study.gd -- items_never 120 7001 /tmp/items_never.json
# Tables and summary
python tools/study_report.py out_dir /tmp/*.json
```

This study used 20 population jobs of 30 participants (ids 1–600, 3 runs each), plus every arm on seeds 7001–7120 (two jobs of 60 each), run 22 at a time: about 40 minutes on 24 cores.
