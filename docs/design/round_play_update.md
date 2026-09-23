# BLOCKMANIA: Round-play update

**Date:** 2026-09-23. **Status:** implemented (owner: "add the features in order"). Rules as built are in GAME_DESIGN_DOCUMENT.md §18; differences from this proposal are noted inline. All numbers are provisional until playtested.

**Sources:**
- An analysis of *Block Slot Machine* (Steam demo): its data files and the owner's screenshots.
- A review of `ideas.md`.
- Paired-seed autoplayer simulations (`tools/experiments.gd`).

Nothing here copies the other game's names, art, text or layout. The mechanics below are adapted to BLOCKMANIA's own rules: the Bag, Chips × Mult, determinism and receipts.

## 0. Diagnosis

Two problems make a round less fun than the run around it:

1. **The placement clock was the whole difficulty.** In the baseline simulation, **all 60 of 60 runs ended "Out of placements"**. None ended because a piece had no room. The bot needed 9–11 of its 12 placements just to pass rounds 1–4, so any placement spent on setup was a placement it couldn't afford. The owner reported the same thing from play: 12 placements leave no room to maneuver.
2. **Almost every decision happens between rounds.** Inside a round you place pieces until you reach the target. The deal is not an event, and color barely matters. Most rewards are numbers (Chips/Mult) instead of things that change how you play the board.

*Block Slot Machine*'s strongest idea addresses both: **your moves are fuel, and playing well refuels them.** Clearing lines earns the currency that buys more pieces, and each deal is a small, readable jackpot moment. Its weaknesses are just as instructive, and we avoid them:
- Luck hands out the power: the slot result decides the strong tools.
- "Increases the chance of…" upgrades are invisible.
- A full-board wipe removes tension.
- The build ceiling is shallow.

## 1. Placements refill on clears *(implemented)*

**Rule.**
- Each round starts with the Kit's placements: **Standard 15, Compact 15, High Roller 14**. Long Game adds +1.
- **Every line cleared gives back 1 placement**, never above the round's starting count (the *refill cap*).
- A multi-line clear gives back one placement per line (so 2 for a double), still capped.
- A clear on your last placement refills it, so the round continues.
- Placements gained from other effects can exceed the cap: Extra Turn, Second Look, and the Refund stamp restoring the one it cost.

**Why this shape.**
- It raises the ceiling on maneuvering without removing tension.
- A player who clears steadily keeps a full tank. A player who stops clearing drains it.
- Setting up a multi-line clear now pays back its setup turns, which the old rules punished (GDD §16.9, "method caveat").
- It uses the same currency the player already reads, so nothing new has to be learned.

**Simulation** (60 paired seeds, greedy bot, current targets):

| Variant | Avg round reached | R3 clear | R4 boss clear | R8 boss clear | Loss reason |
|---|---:|---:|---:|---:|---|
| 12 flat *(old)* | 4.3 | 71% | 49% | — | 100% out of placements |
| 16 flat | 7.3 | 100% | 92% | 52% | 100% out of placements |
| 20 flat | 9.0 | 100% | 98% | 70% | 100% out of placements |
| 12 + refill | 7.1 | 100% | 83% | 65% | 100% out of placements |
| 14 + refill | 8.7 | 100% | 97% | 77% | 98% out of placements |
| **15 + refill** *(chosen)* | **9.3** | **100%** | **98%** | **81%** | 98% out of placements |
| 16 + refill | 9.9 | 100% | 100% | 91% | 98% out of placements |

"15 + refill" roughly doubles how far the bot gets, while late rounds still demand a build: round 11 is cleared 43% of the time and round 12 11%.

A flat 20 reaches a similar average, but it rewards nothing, and every round still feels like a countdown. The refill version asks for skill.

The bot is a lower bound: it can't plan multi-line setups, which the refill now pays for.

**Knock-on changes (implemented):**
- **The Last Call** (final boss) now allows **12** placements, up from 10. It keeps its relative squeeze (80% of the Kit).
- **Extra Turn** can now reach **20** placements, up from 16. Otherwise it would be nearly useless above a 15 start.
- The HUD bulbs show *placements left / refill cap*. Refilled bulbs flash mint, a **+N** pops beside the counter, the message line says *"Lines cleared: +N placements"*, and the tooltip explains the rule.
- Save schema 3: rounds store `placement_cap`. Schema-2 saves resume with the cap set to the placements left at the time of saving.

**Watch list:**
- **Economy:** the unused-placement Credit bonus (+1 per 2 unused, max 3) and **Spare Parts** (≥2 unused) will pay more often, because players now finish rounds with placements to spare. The experiments tool does not report Credits per round yet; add that metric before tuning. If the economy inflates, count unused placements against the cap instead.
- **Cards to re-check:** Long Game, Second Look, and Last Stand ("three or fewer placements left") become situational rather than essential.
- **Full survey results** (`docs/balance/experiments_v2.md`, 60 seeds):
  - **Foundry + 6 Chrome now wins 65% of runs**, up from 13%. Foundry alone wins 32%. It's the new outlier: trim Foundry (+8 → +5 per upgraded piece) if humans confirm it.
  - Neon Sign + 6 Neon wins 30%. Everything else stays at or below 20%.
  - Rescue cards (Tiny Insurance, Second Look) and Fire Sale never matter to the bot, because it never gets stuck any more. They will look better if Tray Hands or the Undertaker add board pressure.
  - Copying both Singles went from neutral to harmful (Δ −0.8).
- **Targets:** the targets are unchanged. If humans now find Act 1 trivial, raise rounds 3–8 by 10–15% and keep rounds 1–2 as teaching rounds.

## 2. Tray Hands *(implemented; starter-bag Staircase odds are 17.9% because Monochrome outranks it)*

The deal becomes an event. When a **full three-piece tray is dealt** (the legality swap already applied), the game checks it for a **Hand**, shows it as a badge on the tray, and grants the reward.

| Hand | Condition | Starter-bag odds | Reward (for this tray) |
|---|---|---:|---|
| **Twins** | Exactly two pieces of the same family | 21.5% | +30 Chips on each placement from this tray |
| **Staircase** | Cell counts are consecutive (1-2-3, 2-3-4, 3-4-5) | 18.2% | +1 placement (can exceed the cap) |
| **Monochrome** | All three pieces the same color (Prism counts as any color) | 1.2% | ×1.5 Mult on each placement from this tray |
| **Triplets** | All three pieces the same family | 0.4% | +1 Refresh this round, +2 Mult on each placement from this tray |
| **Grand Slam** | Triplets and Monochrome together | ~0% | Both rewards plus 3 Credits |

*Odds are computed exactly over all 2,024 three-piece draws from the 24-piece starter bag. At least one Hand appears on 41% of trays.*

**Why it fits BLOCKMANIA better than the source game:**
- **The Bag makes the odds something you build, and something you can see.** Repaint pushes Monochrome, Copier and Shredder push Twins and Triplets, and buying pieces shapes Staircase.
- The Bag view can print the odds from the whole bag's composition ("Monochrome 14%"). That doesn't reveal the draw order, because it uses the full bag, not the pile.
- It finally gives **color** a job, which fits the existing Prism material.
- It gives Jokers a new family of hooks (§6).

**Rules:**
- **No fishing:** trays refilled by Refresh, Second Tray, or Tiny Insurance never form a Hand. Temporary Singles break a Hand.
- **Determinism:** the Hand is computed from the dealt pieces when the tray is dealt and stored in the round state. A reel-style reveal is presentation only. Reduced motion shows the badge immediately.
- **Receipt:** Hand rewards appear as their own receipt line at pipeline steps 3 (Chips), 5 (Mult) and 6 (xMult). Rewards that aren't score (placement, Refresh, Credits) go in the events line.
- **Cost:** a new field on `RoundState`, one pure detector in `BMBag`, one badge widget, and one line per Hand in the resolver. Simulate with `experiments.gd` using a new `hands` mode.

## 3. One targeting framework, then tools earned by play *(implemented, plus the Emergency Brick)*

The source game's tools (a plus-shaped cut, a 3×3 cut, "remove one color", "remove one cell") are the fun half of its loop, and each needs a **cell picker**.

Our backlog is blocked on the same thing: Eraser, Blueprint, Lucky Paint, and the Patch Panel Joker are withheld for lack of pickers (TASKS M1). Build **one** targeting framework with three pieces:
- cell picker
- tray-slot picker
- choose-1-of-N list

Card data declares which one it needs, and one build unlocks all four withheld cards at once.

**Rules for board tools:**
- Removed cells **never score and never count as a clear**. They can't trigger Jokers or refills.
- Tools are used between placements, never during resolution. Presentation follows the existing Glass-shard vocabulary.

**New tools** (consumables, 2 item slots as now):

| Tool | Effect | Where it comes from |
|---|---|---|
| **Eraser** *(existing card)* | Remove up to 2 chosen occupied cells | Shop; Draftsman Joker |
| **Punch** | Remove the occupied cells in a chosen plus shape (up to 5) | Shop; Triplets Hand when tools exist |
| **Color Purge** | Remove every cell of one chosen color. Stone cells are immune. | Shop (rare) |

There is **no whole-board wipe**. It deletes the tension that makes a round interesting.

## 4. Smaller adaptations *(implemented: Boss Crate, Kit bags + Chunky/Tetromino Kits, combo grace = 1)*

- **Faster reward cadence.** After each boss, open a free **Boss Crate**: choose 1 of 3 offers (a Joker of the next act's rarity, a Workshop edit, or a tool). This answers GDD §16.10 Q3 in favor of choose-1-of-3 at boss beats only, which keeps shop time down.
- **Kits with their own starter bags.** This answers §16.10 Q1 with yes. Examples:
  - **Compact:** 18 pieces, no Singles.
  - **Chunky Kit** (new, unlockable): a bag weighted toward Square 2×2, T 4 and Plus 5.
  - **Tetromino Kit** (new): only four-cell families.

  Alternative bags are the cheapest variety in the game.
- **Combo grace** (to test): in the campaign, combo survives **one** non-clearing placement, shown as a single grace pip. It resets on the second miss. Endless already uses a three-miss version, and players liked it there. Simulate before adopting.
- **Tooltip structure** for items and Jokers: *name → how you get it or when it triggers → what it does*. The source game's two-line "how you get it / what it does" is very readable.

## 5. Review of `ideas.md`

It's a good brainstorm, but it adds too many parallel objective layers (contracts, feats, runes, curses, momentum, heat, routes, augments). Each competes for the player's attention with the board, which must stay readable. I kept only what supports the loop above without adding a new layer of rules.

### Keep

| Idea | Why it earns its place | Notes |
|---|---|---|
| **§3.2 Feats** (named accomplishments in the resolution record) | Cheap, deterministic, and gives the player a vocabulary. It feeds Jokers (Showboat), presentation, statistics and future achievements. Start with 6: *Crossfire* (a row and a column together), *Double Tap*, *Hat Trick* (3+ lines), *Clean Board*, *Needle Threader* (fill a single enclosed hole and clear with it), *Last Breath* (clear with the last placement). | Presentation plus the `feats` array. No new rules. |
| **§13 Reusable targeting framework** | Same conclusion as §3 above. It unlocks four existing cards. | Top engineering priority. |
| **§12 Fit indicators on tray pieces** | Removes the tedium of scanning without solving the puzzle: a "NO FIT" tag and dimming on pieces with no legal spot. | Tiny. |
| **§12 Bag statistics panel** | Required for Tray Hand odds, and it explains Hoarder, Lean Bag, Collector and Foundry. | Small. |
| **§7 The Warden** (boss) | One tray slot starts locked and a clear unlocks it. Changes the opening decisions and is readable at a glance. | **Replaces The Echo Chamber**, which has no effect with current content (open owner decision). |
| **§7 The Undertaker** (boss) | A tombstone blocker on a seeded empty cell every 4th placement, cleared by a line through it. Board pressure now matters because placements refill. | Uses the Cramped Cabinet stone-cell code. |
| **§5 Emergency Brick** (consumable) | A clutch rescue anyone understands: a temporary Single in an empty tray slot. | Reuses temporary-piece rules. |
| **§9 Minimalist Kit** | Same as "Kits with starter bags" above. | |
| **Jokers:** Patience, Locksmith, Countdown, Breakage Bonus, Insurance Policy, Showboat | See §6. | |

### Maybe later

Draw Forecast (better as a Joker than a base rule, see *Periscope* in §6), Reserve/Layaway in the shop, Mirror Jig, Stabilizer, Ascension, a Daily challenge (already in GDD §2), and "Why didn't this trigger?" tooltips.

### Discard, and why

- **Contracts / Side Bets, Golden Ticket, Bounty Hunter, Perfectionist, Gambler Kit:** a second objective layer every round. Tray Hands and Feats give the same "the board has a second goal" feeling without a card to read and track.
- **Rune Cells, Cursed Cells, Void Dealer, The Architect, Eclipse:** they put persistent markings on the board, which clutters the crisp 8×8 (pillar 1) and doubles the preview's complexity.
- **Momentum Meter:** the placement refill already makes good play earn agency, and a second meter would be redundant.
- **Heat/Greed, Stage Routes, Joker Augments:** more meta-structure than the current content can fill. Revisit after content-complete.
- **Die Cutter, Welder, Family Mold, Scrap Bundle, Transfer Press, Plating Transfer, Reclaimer, Duplicate Stamp, Tempered Glass:** custom geometry or bookkeeping tools with low fun per UI minute.
- **Boss Intel:** the GDD already reveals each boss at the start of its act.
- **Joker activation animation:** already built (sequenced pulses with pop text).
- **Most other Jokers:** they duplicate existing cards. Variety Act ≈ Color Cycle, Hot Streak ≈ Chain Link, Family Business ≈ Specialist, Precision Engineering ≈ Lean Bag, Deep Pockets ≈ Hoarder, Postage Due ≈ Postmaster, Three-Beat ≈ Golden Ratio. Others are hard to read at a glance (Bridge Builder, Claustrophobia, Fault Line, Urban Planner, Pendulum). Some are economy filler (Coupon Clipper, Pawn Broker, Rainy Day Fund, Loyal Customer).

## 6. New Jokers (implemented: 14, catalog now 52)

Phase names match `game/content/jokers.gd`. "Hook" means the resolver context needs one new deterministic field. Values are provisional and must go through `experiments.gd jokers` before shipping.

### From `ideas.md` (6, some reworded)

| Joker | Rarity | Phase | Effect | Why |
|---|---|---|---|---|
| **Patience** | Uncommon | chips | Each non-clearing placement stores +40 Chips (max +200). The next clearing placement adds the stored Chips and resets it. The counter is shown on the card. | Makes setup turns feel productive. It answers the "multi-line setup is underpaid" finding directly. |
| **Locksmith** | Uncommon | add_mult | +1 Mult when the placed piece fills a one-cell hole that is enclosed on all four sides by blocks or the board edge. +75 Chips more if it also clears a line. *Hook:* `holes_filled`. | Rewards repairing ugly boards, a real puzzle skill. |
| **Countdown** | Uncommon | x_mult | ×1.5 Mult on the third of three consecutive placements with strictly decreasing cell counts (e.g. 5 → 4 → 3). The card shows the current run. *Hook:* cell-count history. | Makes the order you play the tray a small puzzle. |
| **Breakage Bonus** | Uncommon | rule | +2 Credits whenever one of your Glass pieces shatters. | Turns Glass's random loss into an event, which supports a Glass archetype. |
| **Insurance Policy** | Rare | rule | Once per run, when you would lose a round, replay that round from the start with no free Refresh. This Joker is then destroyed. | A comeback story instead of a hard stop. It speaks to the owner's "failing isn't fun". |
| **Showboat** | Rare | add_mult | The first time each different Feat happens in a round: +2 Mult on that placement. A repeated Feat gives nothing. *Needs Feats.* | Rewards varied, flashy play instead of farming one pattern. |

### Original to this update (8)

| Joker | Rarity | Phase | Effect | Why |
|---|---|---|---|---|
| **Full Tank** | Uncommon | add_mult | +2 Mult when you place while at your refill cap. | Pure "keep clearing" pressure. It tempts you to cash in before setting up. |
| **Overflow** | Common | rule | When a clear would refill past your cap, each wasted refill gives +1 Credit (max 3 per round). | Turns the cap into a decision and suits economy builds. |
| **Keystone** | Rare | x_mult | ×2 Mult when a piece of 1–2 cells clears 2 or more lines. | Rewards building a two-line setup that a small piece unlocks. It gives Singles and Bar 2 a reason to exist. |
| **Draftsman** | Uncommon | rule | Clearing a row and a column in the same placement grants an Eraser, if an item slot is free. *Needs the targeting framework.* | Rewards earned inside the round that feed back into the board. |
| **Card Sharp** | Uncommon | rule | Trays refilled by a Refresh can form Hands. *Needs Tray Hands.* | A deliberate fishing build that the base rules forbid. |
| **Hot Hand** | Rare | x_mult | ×1.5 Mult on placements from a tray that formed any Hand. *Needs Tray Hands.* | Rewards shaping the Bag toward Hands. |
| **Periscope** | Common | rule | Shows the next three pieces in your draw pile. | Planning as a choice you make in the build, not a base rule. It uses the existing pile and never consumes randomness. |
| **Loan Shark** | Common | rule | Costs 0. When bought: +6 Credits. After each won round, 2 Credits are taken from that round's payout until 8 are repaid. It can't be sold until repaid. | A deliberate risky bet: power now, a thinner economy later. |

With these, the catalog reaches **52 Jokers**.

## 7. Suggested order

1. ✅ **Placement refills**: done. Needs a human playtest pass on targets and economy.
2. **Tray Hands** plus Hot Hand and Card Sharp. Simulate with a `hands` experiment mode.
3. **Targeting framework**, which unlocks Eraser, Blueprint, Lucky Paint, Patch Panel, Punch, Color Purge and Draftsman.
4. **Feats** plus Showboat, then the no-hook Jokers: Patience, Full Tank, Overflow, Keystone, Breakage Bonus, Loan Shark.
5. **Bosses:** The Warden (replacing Echo Chamber) and The Undertaker. Fit indicators. Bag stats with Hand odds.
6. **Kit starter bags**, Boss Crate, and a combo grace experiment.
