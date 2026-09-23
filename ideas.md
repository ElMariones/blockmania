# Blockmania — Gameplay Expansion Ideas

> Design brainstorm based on the current codebase and design docs. The goal is not to turn Blockmania into a different game; it is to make every run produce more interesting decisions, stronger builds, bigger moments, and more reasons to say “one more run”.

## 1. What the current game already does well

The current foundation is strong:

- Deterministic 8x8 block placement is easy to understand and easy to simulate.
- The persistent **piece bag** gives Blockmania a real identity beyond ordinary Block Blast.
- Pieces can acquire **materials** (Chrome, Neon, Gold, Glass, Prism), **stamps** (Encore, Refund, Tip, Memory), colors, rotations and family upgrades.
- Workshop tools already let the player sculpt the bag with materials, stamps, copying, shredding, rotation, repainting and Schematics.
- Jokers already support placement geometry, combo state, board pressure, color sequencing, bag composition and copying.
- The 12-round / 3-act structure gives a natural rhythm for shops, bosses and build growth.
- Determinism, stable IDs and seeded RNG are already treated as first-class requirements, which is excellent for balance simulation, replays and seeded challenges.

The biggest opportunity is that **most of the interesting build decisions currently happen between rounds**, while the actual board loop is still mostly:

1. Pick one of the tray pieces.
2. Place it.
3. Maybe clear lines.
4. Refresh or use a simple consumable.

The best expansions therefore should not merely add more passive `+Chips` and `xMult` cards. They should create **new reasons to care where, when and in what order pieces are played**.

---

# 2. Design pillars for making the game much more fun

## Pillar A — More decisions inside a round

The player should regularly face decisions such as:

- “Do I take the easy clear now, or preserve this row for my contract?”
- “Do I spend my Hold charge on this awkward piece or save it for the boss?”
- “Do I intentionally let the board become dangerous because my build pays for pressure?”
- “Do I use my Gold piece now for Credits or save it for a 3-line clear?”
- “Do I place the perfect shape now, or wait two placements because Golden Ratio triggers then?”

This is where the game can become addictive rather than merely relaxing.

## Pillar B — Builds should change how the board is played

A good build should be describable in one sentence:

- “I made a tiny bag full of Bars and keep alternating left/right placements.”
- “I deliberately fill the board to 75% before detonating huge Neon clears.”
- “I farm Gold and Tip pieces and turn Credits into late-run power.”
- “I build around Glass pieces that may destroy themselves, constantly changing my bag.”
- “I use Prism pieces to complete color patterns.”

Prefer these identities over universal cards that are simply correct in every build.

## Pillar C — Create small stories every round

A run should generate memorable moments:

- Barely completing a contract on the final placement.
- Saving a terrible board with a one-cell Emergency Brick.
- A Glass piece shattering immediately after producing a massive clear.
- Defeating a boss using the exact counter-build prepared in the previous shop.
- Completing a rare board pattern and seeing the game celebrate it.

## Pillar D — Make success extremely readable and satisfying

Blockmania should visually communicate *why* something powerful happened. When five effects trigger, the player should understand the chain instead of only seeing a larger number.

---

# 3. Highest-impact new systems

These are the additions I think would improve playability the most.

## 3.1 Contracts / Side Bets

At the start of a normal round, offer 2 or 3 optional mini-objectives. The player may accept one or ignore them all.

Examples:

- Clear 3 columns this round.
- Clear a row and column in the same placement.
- Win without using Refresh.
- Make 2 clearing placements consecutively.
- Clear a line containing Gold.
- Place three different shape families consecutively.
- Finish the round with at least 3 placements remaining.
- Clear the leftmost and rightmost columns.
- Trigger a stamped piece twice.

**Reward:** usually 1-3 Credits, a shop coupon, a temporary item, or improved rarity on one reward slot. Avoid giant permanent score bonuses.

**Visuals:** a small dark-gold contract card slides beside the board. Completed clauses stamp themselves in bright gold; failed contracts get a red wax crack.

**Why it is fun:** the exact same board suddenly has a second objective. Players willingly make slightly suboptimal placements because they are pursuing a payout. It creates risk/reward without changing the core rules.

**Implementation:** small new system. Most contracts can evaluate data the resolver/run already tracks: line count, rows/columns, Refresh use, placement count, family, material, stamp and score state.

---

## 3.2 Trick / Feat System

Recognize cool board accomplishments even when no contract asks for them.

Possible named feats:

- **Crossfire** — clear a row and column together.
- **Double Tap** — clear on two consecutive placements.
- **Hat Trick** — clear 3+ lines in one placement.
- **Clean Board** — end a placement with zero occupied cells.
- **Needle Threader** — fill a one-cell cavity and clear a line with it.
- **Edge to Edge** — one placed piece touches both opposite halves of the board.
- **Full Spectrum** — clear cells of 4+ colors at once.
- **Workshop Special** — clear a line containing 3 different upgraded pieces.
- **Golden Sweep** — clear 3+ Gold cells at once.
- **Glass House** — clear multiple Glass cells without any of those pieces shattering.
- **Last Breath** — clear while no Refresh remains and only one placement is left.

Feats can feed Jokers, achievements, contract conditions, sound effects and statistics.

**Visuals:** a tiny medal/nameplate appears above the score for 0.6-1.0 seconds. Rare feats get a stronger border and sound.

**Why it is fun:** players learn to recognize advanced patterns and begin intentionally setting them up. It creates a vocabulary for mastery.

**Implementation:** add a deterministic `feats` array to the resolution result. This becomes a very reusable hook for future Jokers.

---

## 3.3 Hold Slot

Add one **Hold** slot beside the tray. Once per round by default, the player can put one tray piece into Hold and retrieve it later.

Possible rules:

- Holding does not consume a placement.
- Only one piece can be held.
- The default Kit gets 1 Hold use per round, or Hold can instead be introduced through a Kit/Joker if you want less base complexity.
- A held bag piece preserves its exact UID/material/stamp.

**Visuals:** a small brass-framed recess beside the tray. The piece physically slides into it. Locked Hold uses appear as broken padlocks.

**Why it is fun:** it increases agency without removing puzzle tension. Players can save a Bar for a nearly-complete row, protect a valuable Gold/Encore piece, or temporarily hide an awkward shape.

**Implementation:** medium. It changes tray state, but it is deterministic and saveable.

---

## 3.4 Draw Forecast

Show the next 2 pieces that will enter the tray from the bag/discard flow.

Do **not** let the player freely choose them by default; information alone is powerful and interesting.

**Visuals:** two tiny ghosted cards/pieces labelled `NEXT` near the bag icon. Hovering shows full upgrades.

**Why it is fun:** board planning becomes intentional instead of purely reactive. It also makes curated bags feel much more meaningful.

**Implementation:** medium. The draw stream must expose upcoming deterministic entries without accidentally consuming RNG.

---

## 3.5 Rune Cells

Each round can seed 1-3 special cells on the board. Covering or clearing them creates a small one-shot benefit.

Rune examples:

- **Chip Rune:** +75 Chips when covered.
- **Mult Rune:** +1 Mult if its line clears.
- **Coin Rune:** +1 Credit when cleared.
- **Echo Rune:** the piece covering it counts as stamped for one scoring event.
- **Refresh Rune:** recharge a Refresh fragment; collect 2 fragments for +1 Refresh.
- **Prism Rune:** the occupying cell counts as every color.

Keep rewards bounded and visible before placement.

**Visuals:** subtle animated sigils under empty cells. A placement preview should show which runes it will activate.

**Why it is fun:** the board itself becomes a source of objectives. Players choose between ideal packing and chasing runes.

**Implementation:** medium/new board metadata. Very high design value because many Jokers/Bosses can later interact with rune cells.

---

## 3.6 Cursed Cells

The risk-reward counterpart to Runes. A few seeded cells are cursed at round start.

Examples:

- Covering the cell gives +100 Chips, but the piece becomes Glass-like for the round.
- Clearing a cursed cell pays 2 Credits.
- A cursed cell grows stronger every placement it remains empty.
- A curse occupies the cell after 5 placements unless claimed first.

**Visuals:** dim purple/red cracks with a slow pulse and a number showing its current value/countdown.

**Why it is fun:** danger becomes voluntary. The player sees the risk and chooses whether the payout is worth warping the board.

---

## 3.7 Momentum Meter

Instead of another raw combo multiplier, add a meter charged by skillful actions:

- line clears,
- multi-line clears,
- feats,
- material interactions,
- completing contracts.

At full Momentum, the player earns a tactical reward such as:

- one free Hold,
- one free tray Refresh,
- a temporary Single,
- +1 placement,
- a choice of two temporary buffs.

The meter partially decays between rounds so it cannot simply snowball forever.

**Visuals:** a narrow vertical meter beside the board, filling with gold sparks. Important actions visibly send particles into it.

**Why it is fun:** good play generates *agency*, not only a larger number.

---

## 3.8 Stage Routes

After each boss, choose between two routes for the next act.

Example:

- **Foundry District:** more material tools, fewer Joker offers.
- **Market District:** cheaper shops, harder score target.
- **Glassworks:** more Glass content, +1 Credit whenever Glass shatters.
- **Arcade:** more consumables and contracts, fewer Schematics.
- **Royal Quarter:** higher rare chance, prices +1.

**Visuals:** two large destination cards with a little city map / signpost between them.

**Why it is fun:** runs diverge even before individual shop rolls. It also lets players deliberately pursue a build rather than pray that the shop eventually cooperates.

---

## 3.9 Heat / Greed

Let the player optionally increase **Heat** after winning a round.

Each Heat level could provide:

- slightly better shop rarity or +1 Credit payout,
- but a stronger score target or an added round modifier.

Heat can be reduced after a boss or by paying Credits.

Examples of Heat modifiers:

- +8% target.
- One fewer placement.
- One seeded blocked cell.
- Refresh costs a placement.

**Visuals:** a small flame/skull meter that becomes more ornate and dangerous at higher levels.

**Why it is fun:** strong runs no longer become autopilot. Players decide how greedy they want to be.

---

## 3.10 Joker Augments

Instead of simply levelling Jokers numerically, rare rewards can add one **Augment** to a Joker.

Examples:

- **Polished:** +25 Chips whenever this Joker triggers.
- **Charged:** first trigger each round is 25% stronger.
- **Frugal:** sells for +2 Credits.
- **Echoing:** every fourth trigger repeats its flat-Chip component at 50% strength.
- **Bossproof:** not disabled by one named boss category.

Only one Augment per Joker.

**Visuals:** a tiny gem/socket in the Joker frame; the border gets a subtle matching accent.

**Why it is fun:** a familiar Joker can become “my special card” during a run without requiring dozens of permanent upgrade levels.

**Balance note:** avoid generic permanent xMult augments. Flat/conditional bonuses are much safer.

---

# 4. New Joker ideas

The current catalog already covers basic one-line/multi-line rewards, corners, board emptiness/pressure, color cycling, bag size, families, upgraded-piece count, discard size, Glass, and Joker copying. The ideas below try to open *new play patterns* rather than duplicate those cards.

Implementation labels:

- **Easy** — mostly existing context/state.
- **Hook** — needs one extra deterministic context field or counter.
- **System** — depends on one of the larger features above.

## Spatial / board-play Jokers

### 1. Pendulum — Uncommon — Hook
Alternate placements between the left and right halves of the board. Each successful alternation gives +0.5 Mult to that placement, up to +2. Missing the alternation resets it.

**Visual:** a brass pendulum swinging left/right; the currently desired side glows.

**Why fun:** makes location matter every single turn and creates readable streak gameplay.

### 2. Bridge Builder — Uncommon — Hook
If the newly placed piece connects two previously separate occupied clusters, gain +150 Chips.

**Visual:** two stone towers joined by a glowing bridge.

**Why fun:** rewards understanding negative space and adjacency instead of only line completion.

### 3. Locksmith — Uncommon — Hook
Filling a one-cell enclosed hole grants +1 Mult. If that placement also clears a line, gain another +75 Chips.

**Visual:** golden key fitting into a single square keyhole.

**Why fun:** turns normally ugly cavities into deliberate setup opportunities.

### 4. Surveyor — Uncommon — Hook
At round start, one seeded 3x3 zone is marked. Placements fully inside it gain +75 Chips; clearing a line through it moves the zone.

**Visual:** dotted blueprint rectangle with tiny corner markers.

**Why fun:** creates a temporary local objective and changes preferred placement locations every round.

### 5. Center Stage — Common — Hook
If a placement covers any of the central four cells, +60 Chips. Can trigger only twice per round.

**Visual:** theatre spotlight over the board center.

**Why fun:** simple positional tension without becoming a permanent universal multiplier.

### 6. Border Patrol — Common — Hook
If every cell of the placed piece lies on the outer two-cell ring, +50 Chips.

**Visual:** little guard posts around a square frame.

**Why fun:** rewards difficult edge packing and contrasts with Center Stage.

### 7. Claustrophobia — Rare — Hook
When a placed piece has occupied cells on at least three of its four orthogonal sides after placement, x1.6 Mult.

**Visual:** a Joker squeezed between four closing walls.

**Why fun:** makes tight packing desirable instead of something the player always avoids.

### 8. Open Plan — Uncommon — Hook
If the placement creates no new enclosed holes and leaves at least 35 empty cells, +2 Mult.

**Visual:** clean architectural blueprint with large open rooms.

**Why fun:** supports a disciplined “keep the board healthy” archetype distinct from Pressure Cooker.

### 9. Fault Line — Rare — Hook
The first placement each round that causes both a row and a column to become one cell away from completion gains x1.5 Mult.

**Visual:** glowing cracks crossing at a missing square.

**Why fun:** rewards setup, not just the payoff clear.

### 10. Urban Planner — Rare — Hook
Every fourth placement that uses a previously unused board quadrant this round grants +250 Chips.

**Visual:** four city blocks lighting up one by one.

**Why fun:** encourages spreading and rotation through the whole board.

---

## Sequence / rhythm Jokers

### 11. Variety Act — Uncommon — Hook
Place three different shape families consecutively to gain +3 Mult on the third. Repeating a family resets the sequence.

**Visual:** three circus placards flipping to different silhouettes.

**Why fun:** rewards diverse bags without simply counting diversity passively.

### 12. Countdown — Rare — Hook
Play pieces with decreasing cell counts on three consecutive placements (for example 5 -> 4 -> 3). The third gains x1.75 Mult.

**Visual:** numbered fuse 5-4-3 burning downward.

**Why fun:** turns tray ordering into a little sequencing puzzle.

### 13. Echo Step — Common — Hook
If the current piece has exactly the same cell count as the previous piece, +60 Chips.

**Visual:** two matching footprints.

**Why fun:** easy to understand and supports bags built around a narrow size band without duplicating exact families.

### 14. Odd Couple — Uncommon — Hook
Alternating odd-cell and even-cell pieces adds +1 Mult per successful alternation, capped at +3; failure resets.

**Visual:** mismatched comedy masks labelled odd/even.

**Why fun:** another build identity based on shape size rather than color or family.

### 15. Patience — Uncommon — Easy/Hook
Each non-clearing placement stores +40 Chips, up to +200. The next clearing placement cashes in the stored Chips and resets.

**Visual:** a kettle/pressure gauge filling one notch per quiet turn.

**Why fun:** makes setup turns feel productive and creates satisfying release moments.

### 16. Hot Streak — Rare — Hook
Consecutive clearing placements gain +1 Mult, then +2, then +3. Missing a clear resets the streak. Cap at +3.

**Visual:** three ascending flame pips.

**Why fun:** creates exciting short streaks without an unlimited runaway multiplier.

### 17. Bookends — Uncommon — Hook
If the first and last piece used from a tray have the same family, the last gains x1.5 Mult.

**Visual:** two ornate bookends around a piece silhouette.

**Why fun:** gives tray order a goal players can plan around.

### 18. Three-Beat — Rare — Easy
Placement 1 grants +100 Chips, placement 2 grants +2 Mult, placement 3 grants x1.4 Mult, then the cycle repeats.

**Visual:** music notation with three highlighted beats.

**Why fun:** predictable rhythm creates timing decisions with zero RNG.

---

## Material / upgrade Jokers

### 19. Alchemist — Rare — Hook
If a single clear removes cells belonging to at least three different materials, gain x1.75 Mult.

**Visual:** three colored liquids pouring into one flask.

**Why fun:** encourages mixed-material boards rather than concentrating exclusively on the mathematically strongest material.

### 20. Chrome Hearts — Uncommon — Hook
If a Chrome piece is placed adjacent to another Chrome cell, +1 Mult. Once per placement.

**Visual:** two chrome blocks clinking together like magnets.

**Why fun:** gives Chrome positional identity beyond raw Chips.

### 21. Neon Circuit — Rare — Hook
Each separate Neon group touched by a clearing line adds +0.5 Mult, up to +2.

**Visual:** glowing circuit traces connecting Neon cells.

**Why fun:** makes the player distribute Neon around the board instead of merely stacking it.

### 22. Gold Standard — Uncommon — Hook
The first placement each round that clears at least 2 Gold cells gains +100 Chips in addition to Gold's normal Credits.

**Visual:** medal stamped with a gold bar.

**Why fun:** encourages timing valuable Gold clears rather than taking each coin immediately.

### 23. Shatterproof — Rare — Hook
The first Glass piece that would shatter each round survives instead; when prevented, gain +1 Credit.

**Visual:** cracked glass behind a small shield.

**Why fun:** allows a dedicated Glass archetype and creates a defensive card with clear economic value.

### 24. Breakage Bonus — Uncommon — Hook
Whenever one of your Glass pieces actually shatters, gain +150 Chips on the next placement this round.

**Visual:** broken champagne glass showering score tokens.

**Why fun:** turns a normally painful random loss into a build event without removing Glass's risk.

### 25. Prismatic Order — Rare — Hook
After placing a Prism piece, the next non-Prism piece gains +2 Mult; if that placement clears, +3 instead.

**Visual:** prism splitting light into the next card.

**Why fun:** Prism becomes a sequencing tool rather than only a passive wildcard.

### 26. Postage Due — Uncommon — Hook
Every third stamped-piece placement grants +2 Credits. Counter persists through the round and resets next round.

**Visual:** stamp book with three slots.

**Why fun:** creates a dedicated stamp-heavy economy build.

### 27. Double Feature — Rare — Hook
If a piece has both a material and a stamp, its first scoring trigger each round gains +100 Chips.

**Visual:** split card showing a material badge and postage stamp.

**Why fun:** rewards deeply investing in individual bag pieces without multiplying all of their existing effects.

### 28. Family Business — Uncommon — Easy
When placing a piece from a family with Schematic level 2+, gain +50 Chips. At level 4+, gain +1 Mult instead of the Chips bonus.

**Visual:** rolled blueprint with a family crest.

**Why fun:** makes long-term family specialization visibly matter beyond the base Schematic numbers.

---

## Bag / discard Jokers

### 29. Precision Engineering — Rare — Easy
If your bag contains 18 or fewer pieces, the first clearing placement each round gains x1.5 Mult.

**Visual:** tiny perfectly organized mechanical case.

**Why fun:** supports aggressive Shredder builds but does not stack a huge passive bonus on every placement like another Lean Bag.

### 30. Deep Pockets — Uncommon — Easy
If your bag contains 32+ pieces, every fourth placement gains +100 Chips.

**Visual:** overflowing coat pockets full of blocks.

**Why fun:** gives large-bag builds an active cadence instead of simply copying Hoarder.

### 31. Reunion Tour — Rare — Hook
When a piece returns from the discard pile and is placed again in the same round, gain +2 Mult.

**Visual:** returning performer stepping back onto stage.

**Why fun:** makes cycling and small-bag builds care about individual piece recurrence.

### 32. Fresh Ink — Common — Hook
The first time a newly stamped/material-upgraded piece is drawn after a shop, its placement gains +100 Chips.

**Visual:** wet ink / sparkling fresh plating.

**Why fun:** creates immediate excitement after modifying the bag.

### 33. Curator — Uncommon — Hook
If the current tray contains three different families, the first piece played from that tray gains +75 Chips.

**Visual:** museum display of three different silhouettes.

**Why fun:** makes tray composition matter at decision time.

### 34. Assembly Line — Rare — Hook
Three placements from the same family within a round charge the card. The next different family gains x1.6 Mult and discharges it.

**Visual:** factory conveyor ending in a brightly different product.

**Why fun:** supports both duplication and intentional pivoting.

---

## Economy / utility Jokers

### 35. Rainy Day Fund — Uncommon — Easy
At the start of a boss round, if you have 8+ Credits, gain one free consumable slot refill from a small deterministic pool. Once per act.

**Visual:** piggy bank under an umbrella.

**Why fun:** rewards saving without simply turning money into more money.

### 36. Coupon Clipper — Common — Easy
The first shop purchase after each boss costs 1 less Credit, minimum 1.

**Visual:** scissors cutting a golden coupon.

**Why fun:** simple economic planning and a reason to time expensive purchases.

### 37. Loyal Customer — Rare — Hook
After buying 3 Workshop tools in a run, gain a permanent +1 shop reroll discount. Can trigger once.

**Visual:** stamped loyalty card.

**Why fun:** supports a Workshop-focused build instead of direct scoring.

### 38. Pawn Broker — Uncommon — Easy
The first Joker sold each act sells for +1 Credit. The bonus cannot apply to Pawn Broker itself.

**Visual:** three brass balls over a card counter.

**Why fun:** encourages adapting the build instead of hoarding obsolete early Jokers.

### 39. Insurance Policy — Rare — Hook
Once per run, if the player would lose the run from a failed round, restart that round with one fewer placement and no free Refresh.

**Visual:** signed policy burning at the edges when consumed.

**Why fun:** dramatic safety valve with a meaningful penalty; creates comeback stories rather than a free life.

---

## Contract / feat Jokers

### 40. Bounty Hunter — Uncommon — System
Completing a Contract gives +1 extra Credit, at most once per round.

**Visual:** wanted poster covered in gold checkmarks.

**Why fun:** creates a contract-focused economy build.

### 41. Showboat — Rare — System
The first named Feat each round adds +2 Mult to that placement. Repeating the same feat later gives no bonus.

**Visual:** magician throwing achievement ribbons into the air.

**Why fun:** encourages varied fancy play instead of farming one pattern.

### 42. Perfectionist — Rare — System
Completing a Contract without using Refresh stores one **Star**. At 3 Stars, gain +1 Joker slot for the rest of the run, then this Joker destroys itself.

**Visual:** three empty star sockets filling with gold.

**Why fun:** creates a mini-quest with a memorable transformation and a hard cap.

---

# 5. New consumable ideas

Consumables should create tactical “save it or spend it?” decisions. Avoid adding more items that are only +score with no board interaction.

## 1. Emergency Brick
Create a temporary Single in an empty tray slot. It disappears after use and never enters the bag.

**Visual:** little red emergency box with a 1x1 block behind glass.

**Why fun:** extremely understandable clutch tool. Rare/expensive because Singles are powerful.

## 2. Pocket Dimension
Choose one tray piece and store it until the end of the round. A stored piece can be swapped back into an empty tray slot later.

**Visual:** tiny purple portal/card sleeve.

**Why fun:** consumable version of Hold with more flexibility, useful even if Hold never becomes a base mechanic.

## 3. X-Ray
Reveal the next 6 bag draws. Choose one of the first 3 to move to the front; the relative order of the others stays deterministic.

**Visual:** translucent bag with six ghost pieces.

**Why fun:** controlled manipulation of luck without rerolling the entire state.

## 4. Coupon
The next shop purchase costs 2 fewer Credits, minimum 1.

**Visual:** perforated gold ticket.

**Why fun:** lets the player bank economic value and plan for expensive rare cards.

## 5. Insurance
If no offered piece fits before the end of this round, consume Insurance and deal a temporary Single instead of immediately entering the normal defeat flow.

**Visual:** folded paper shield.

**Why fun:** player-controlled rescue resource rather than a passive bailout.

## 6. Prism Flash
The next placed piece counts as every color for Joker checks, regardless of its actual material. It does not permanently become Prism.

**Visual:** burst of rainbow light around a normal block.

**Why fun:** enables intentional Color Cycle / color-Joker combos without permanently changing the bag.

## 7. Overclock
The next stamped piece triggers its stamp twice, but receives no material benefit on that placement.

**Visual:** stamp surrounded by electrical arcs.

**Why fun:** creates interesting timing and a real tradeoff rather than a free duplicate trigger.

## 8. Magnet
Choose one of the current tray pieces. After it is placed, pull one piece of the same family from the remaining draw order into the next available tray slot if one exists.

**Visual:** horseshoe magnet pulling a matching silhouette.

**Why fun:** lets family builds create short combo sequences.

## 9. Compression Capsule
Choose one 3+ cell tray piece. Remove one deterministically highlighted edge cell for this placement only; the remaining cells must stay connected.

**Visual:** block entering a small hydraulic press.

**Why fun:** transforms an impossible piece into a clutch fit while preserving the permanent bag.

## 10. Golden Ticket
Choose one optional Contract from three immediately. Completing it this round pays 3 Credits; failure pays nothing.

**Visual:** shiny ticket with a contract seal.

**Why fun:** lets players voluntarily create a high-value objective when the board/build seems capable of it.

## 11. Stabilizer
The next Glass piece that would shatter this round does not shatter.

**Visual:** glass cube inside a gyroscopic frame.

**Why fun:** very clean synergy item for Glass builds.

## 12. Encore Pass
After the next line-clearing placement, return the exact placed bag piece to an empty tray slot immediately instead of sending it to discard. It can be played one extra time this round.

**Visual:** theatre ticket stamped “ENCORE”.

**Why fun:** allows a deliberate second use of a prized upgraded piece.

## 13. Blackout
Disable the current boss rule for the **next placement only**.

**Visual:** boss portrait covered by a black velvet curtain.

**Why fun:** creates boss counterplay without trivializing the whole boss round.

## 14. Spare Fuse
Gain +1 Refresh this round. If unused when the round ends, it disappears.

**Visual:** small fuse in a brass capsule.

**Why fun:** tactical safety that does not permanently improve the run economy.

## 15. Seal of Recall
Choose one consumable already used earlier this round. Recreate it at the end of the round only if the round is won. Cannot target another Seal of Recall.

**Visual:** circular wax seal with an arrow looping backward.

**Why fun:** delayed payoff and combinatorial item play without infinite loops.

---

# 6. New Workshop tool ideas

Existing Workshop tools already handle material application, stamps, copying, shredding, rotation, repainting and family Schematics. New tools should alter a different axis.

## 1. Mirror Jig
Mirror up to 2 selected pieces horizontally. This is distinct from Turntable rotation.

**Visual:** workshop mirror with a piece silhouette reflected inside.

**Why fun:** expands bag surgery and makes awkward L/Z orientations deliberately fixable.

## 2. Die Cutter
Choose one 4+ cell piece and remove one selectable edge cell, provided the remaining shape stays connected. The result becomes a custom piece with a stable custom geometry ID.

**Visual:** steel punch cutting one square from card stock.

**Why fun:** powerful personalization and memorable “signature pieces”.

**Implementation:** large because custom geometries must serialize and render. Worth considering later, not first.

## 3. Welder
Fuse two 1-3 cell pieces into one connected piece, removing both originals. The resulting piece keeps one chosen color and loses both materials/stamps.

**Visual:** welding sparks between two block silhouettes.

**Why fun:** a dramatic way to sculpt the bag, with a real sacrifice.

**Implementation:** large/custom geometry system.

## 4. Reclaimer
Remove one material or stamp from a selected piece. Gain 1 Credit.

**Visual:** workshop claw stripping plating from a block.

**Why fun:** lets players undo obsolete upgrades and creates value from cleaning a bag.

## 5. Transfer Press
Move the stamp from one bag piece to another unstamped piece. Neither piece changes otherwise.

**Visual:** two blocks under a mechanical stamp-transfer arm.

**Why fun:** lets the player rescue valuable upgrades from a bad geometry.

## 6. Plating Transfer
Move a material from one piece to one unmaterialed piece.

**Visual:** liquid/metal coating flowing through pipes between two blocks.

**Why fun:** same idea for materials; helps builds evolve instead of being permanently punished by an early choice.

## 7. Family Mold
Choose one piece. Replace it with another rotation/shape from the **same cell count tier** from a deterministic 3-choice list. Material/stamp are removed.

**Visual:** block melted into a mold with three silhouettes above it.

**Why fun:** controlled bag correction without letting the player simply manufacture the mathematically best piece at will.

## 8. Duplicate Stamp
Copy only the stamp of one piece onto another unstamped piece; destroy the source stamp afterward.

**Visual:** carbon-copy paper beneath a stamp.

**Why fun:** another form of bag optimization with opportunity cost.

## 9. Tempered Glass
Convert one Glass piece into **Tempered Glass**: it cannot shatter, but its xMult effect becomes x1.25 instead of x1.5.

**Visual:** reinforced grid pattern over the Glass material.

**Why fun:** meaningful risk conversion and a possible new sub-material mechanic.

## 10. Scrap Bundle
Shred exactly 3 pieces at once and receive one random/seeded upgraded 2-4 cell piece from a visible set of three.

**Visual:** shredder feeding a compact scrap cube that opens into three options.

**Why fun:** converts bag cleanup into a mini-draft rather than only deletion.

---

# 7. New boss ideas

Bosses should alter *decisions*, not merely say “score 20% less”. The counter should be understandable before the round starts.

## 1. The Auditor
**Rule:** repeating the same shape family on consecutive placements gives that placement -1 Mult. Playing a different family clears the penalty.

**Counter:** varied bags, careful tray order, Prism/material effects that do not depend on family.

**Visual:** severe accountant stamping duplicate forms in red.

**Why fun:** creates a clear sequencing puzzle.

## 2. The Eclipse
**Rule:** the left half of the board is lit for two placements, then the right half for two. Placements entirely in the dark half lose their base cell Chips; line Chips and Joker effects remain.

**Counter:** follow the light or deliberately sacrifice base Chips for a better clear.

**Visual:** huge moon shadow sweeping across the board.

**Why fun:** spatial boss with predictable rhythm and no hidden randomness.

## 3. The Warden
**Rule:** one tray slot begins locked. Clear a line to unlock it for the rest of the round.

**Counter:** build an early clear with the remaining options.

**Visual:** iron bars and a padlock over one tray card.

**Why fun:** immediate objective that changes the opening turns.

## 4. The Architect
**Rule:** a seeded 2x2 “protected site” cannot be occupied. Every time a line clears, the site relocates to a new valid seeded position.

**Counter:** maintain flexible open space and avoid overcommitting to one region.

**Visual:** blueprint barricade / construction tape over four cells.

**Why fun:** board geometry keeps changing during the fight.

## 5. The Collector
**Rule:** the first time each material type scores its special effect this round, the boss steals 25% of that effect's numeric value. Repeated uses are normal.

**Counter:** concentrate on a few materials or deliberately “pay the tax” early with small activations.

**Visual:** greedy curator reaching toward material badges.

**Why fun:** creates clever timing without disabling an entire build like a hard immunity.

## 6. The Undertaker
**Rule:** after every 4th placement, one seeded empty cell becomes a Tombstone blocker. Clearing a line through it destroys it normally.

**Counter:** clear frequently and keep lanes open.

**Visual:** tiny tombstones rising from the board with dust.

**Why fun:** produces escalating board pressure that the player can fight directly.

## 7. The Mimic King
**Rule:** after you play a family, the next tray refill has an increased deterministic chance to include another piece from that family.

**Counter:** exploit the duplicates with family builds, or intentionally vary placements to manipulate future draws.

**Visual:** crowned mirror monster reproducing block silhouettes.

**Why fun:** the boss changes the bag flow in a way clever players can exploit rather than simply endure.

## 8. The Gambler
**Rule:** before placements 4 and 8, choose one of two visible side bets. Example: “clear within two placements for +150 Chips” versus “make a multi-line clear within four placements for +300”. Failure adds +100 to the round target.

**Counter:** decline? If boss identity requires participation, always offer a conservative and aggressive option.

**Visual:** dealer hands two face-up cards onto the board.

**Why fun:** creates active boss interaction and memorable risk decisions.

## 9. The Forger
**Rule:** one seeded material is declared Counterfeit for the round. Its material bonus is disabled until you clear 3 cells of that material; then the restriction breaks permanently.

**Counter:** purge the counterfeit quickly or play around it.

**Visual:** material icon with a red counterfeit seal that cracks as cells are cleared.

**Why fun:** temporary targeted disruption with an explicit objective to overcome it.

## 10. The Clockmaker — Final Boss
**Rule:** the round is divided into three phases by placement count, not real time:
- placements 1-3: no Refresh,
- 4-7: one seeded row is blocked,
- 8+: target gains +10% but all multi-line clears gain +2 Mult.

**Counter:** plan the whole round and save resources for the right phase.

**Visual:** giant clock face behind the board advancing one notch per placement.

**Why fun:** final boss feels like a multi-phase encounter while remaining completely turn-based and deterministic.

## 11. The Curator — Final Boss
**Rule:** after every third placement, the boss “exhibits” the family just played: that family gains +25 base Chips but cannot be played on the next placement.

**Counter:** build sequences and exploit the bonus rather than simply avoiding the restriction.

**Visual:** museum frames appearing around family icons.

**Why fun:** restriction and reward are coupled, making the boss something players can outsmart.

## 12. The Void Dealer — Final Boss
**Rule:** three Void cells begin on the board. They cannot be occupied. Whenever a line adjacent to a Void clears, that Void disappears and another one spawns at a seeded empty location; destroying all three original “charges” grants +1 placement.

**Counter:** deliberately route clears around the hazards.

**Visual:** black holes with gold rims pulling particles inward.

**Why fun:** turns the whole board into an encounter rather than a passive score modifier.

---

# 8. Shop and economy improvements

## 8.1 Reserve / Layaway

Allow one shop offer to be **reserved** for the next shop for 1 Credit. It occupies a small reserve slot and keeps its current price.

**Why fun:** removes the frustrating feeling of seeing the perfect build piece one Credit too early, while still charging for the privilege.

## 8.2 Trade-In Bonus

Selling a Joker and buying another Joker in the same shop gives +1 sell value once per shop.

**Why fun:** encourages adapting instead of treating early cards as permanent mistakes.

## 8.3 Workshop Preview

Before buying a tool, let the player hover/select it and preview all valid bag targets. If a tool has no useful target, make that obvious.

**Why fun:** removes UI uncertainty and makes bag surgery feel tactile.

## 8.4 Bundles

Occasionally replace a normal shop slot with a themed bundle:

- **Glass Starter:** Glassworks + Stabilizer.
- **Postal Kit:** one random Stamp + Coupon.
- **Color Pack:** Repaint + Prism Flash.
- **Slimmer:** Shredder + small Credit refund.

Bundle price should be slightly less than the parts individually.

**Why fun:** helps builds form coherent identities earlier.

## 8.5 Boss Intel

Reveal the next boss **before the preceding shop**. The shop can guarantee at least one broadly relevant counter option.

**Why fun:** bosses become strategic tests the player can prepare for, not arbitrary punishment.

## 8.6 Salvage Bin

One cheap shop slot offers a piece removed from the bag earlier in the run or a low-tier seeded piece.

**Why fun:** creates funny recovery decisions and makes previous bag edits feel less irreversible.

---

# 9. More Kits / starting archetypes

The existing Standard / Compact / High Roller structure is a good place to add replay variety without permanent stat grinding.

## Workshop Kit
- 4 Joker slots.
- Start with 3 extra Credits.
- First Workshop tool each act costs 1 less.
- 12 placements / 1 Refresh.

**Playstyle:** bag sculpting.

## Glass Kit
- Start with two Glass pieces.
- 5 Joker slots.
- Start with one Stabilizer consumable.
- 11 placements.

**Playstyle:** volatile risk/reward.

## Courier Kit
- Start with one Tip-stamped and one Refund-stamped piece.
- Only 4 Joker slots.
- +1 consumable slot.

**Playstyle:** stamps/items/economy.

## Minimalist Kit
- Start with an 18-piece bag instead of 24.
- Only 10 pieces may be added before the bag must be trimmed.
- 5 Joker slots, 12 placements.

**Playstyle:** precise cycling and family specialization.

## Collector Kit
- Start with a 30-piece bag with broader family variety.
- +1 shop Piece offer.
- One fewer Workshop tool offer.

**Playstyle:** broad bag / variety synergies.

## Gambler Kit
- Start every normal round with a mandatory Contract.
- Contract payouts are +1 Credit.
- Failing a Contract adds a small score requirement penalty next round.

**Playstyle:** high-risk objective chasing.

---

# 10. Endless / long-term run features

## 10.1 Ascension Levels

After winning a standard run, unlock deterministic difficulty modifiers one at a time.

Examples:

1. Targets +5%.
2. Rerolls cost +1 after the first.
3. Bosses gain one minor modifier.
4. Start with 23 instead of 24 bag pieces and one awkward seeded piece.
5. Rare shop odds slightly reduced in Act 1.
6. Heat begins at 1.
7. Final boss target +10%.

Keep modifiers legible and fixed. Do not hide difficulty in opaque scaling.

**Why fun:** gives skilled players long-term challenge without changing the core game for everyone.

## 10.2 Seeded Daily Challenge

Everyone receives the same:

- run seed,
- Kit,
- initial bag,
- shops,
- bosses,
- optional special modifier.

The important part is not necessarily an online leaderboard at first. Even a visible seed and local best score makes the mode shareable.

## 10.3 Build Share Code

At run end, generate a compact text summary/code containing:

- seed,
- Kit,
- final Joker IDs,
- bag composition/upgrades,
- family levels,
- result/score.

**Why fun:** makes unusual builds easy to discuss and reproduce.

## 10.4 Boss Rush

Short mode with 3 boss rounds separated by unusually strong shops. Start with a draft of Jokers/tools.

**Why fun:** concentrated challenge and a fast way to test boss mechanics/builds.

## 10.5 Draft Mode

Start with:

- choose 1 of 3 Jokers three times,
- choose 2 of 5 Workshop edits,
- then play a shortened run with fewer shops.

**Why fun:** gets players into a coherent build immediately and is excellent for quick runs.

---

# 11. Visual / audio “juice” that would make the same mechanics feel better

These changes can improve perceived fun dramatically even before major systems are added.

## 11.1 Joker activation animation

When a Joker triggers:

1. its card rises/scales slightly,
2. its border flashes,
3. a tiny icon/beam travels toward the score calculation,
4. its contribution appears as `+75`, `+2 Mult`, or `x1.5` near the card.

For Mimic, draw a visible beam from Mimic to the copied card before the copied effect triggers.

**Why:** the player can finally *see the build working*.

## 11.2 Scoring stack presentation

For large placements, briefly show:

`Base Chips -> Materials -> Jokers -> +Mult -> xMult -> Total`

Do not open a modal; animate the existing score area rapidly through the stages.

**Why:** giant numbers feel earned instead of arbitrary.

## 11.3 Material-specific clear effects

- **Chrome:** hard white metallic slash / sparks.
- **Neon:** colored electrical trail.
- **Gold:** coin glints fly toward Credits.
- **Glass:** sharp transparent fracture; actual shatter gets a much bigger crack sound.
- **Prism:** short rainbow refraction.

## 11.4 Stamp-specific placement effects

A physical stamp slams down for Encore/Refund/Tip/Memory, with a different tiny symbol and sound for each.

## 11.5 Danger state

When board occupancy becomes dangerous:

- subtle edge vignette,
- bag/tray fit indicators become more urgent,
- music adds a percussion layer,
- do not use annoying flashing.

## 11.6 Perfect-clear celebration

A completely empty board should be a major micro-celebration even if it has no huge balance reward:

- 100-150 ms pause,
- board briefly dims,
- gold outline sweeps across all cells,
- unique sound sting,
- `CLEAN BOARD` feat banner.

## 11.7 Boss introduction

Before the first placement:

- boss card slides over the board,
- rule text appears in one concise sentence,
- affected UI/board area highlights,
- counter hint appears below.

Then shrink the boss card to a persistent corner badge.

## 11.8 Bag surgery feedback

When Workshop tools modify a piece, animate the actual mini-piece:

- Turntable physically rotates it.
- Repaint washes color over it.
- Material tools coat it.
- Stamp tools slam a stamp on it.
- Shredder visibly tears it away.
- Copier spits out the duplicate beside it.

This is a cheap way to make the bag-building identity feel tangible.

## 11.9 Rare-card finishes

Rare Jokers/tools should have subtle animated foil, star glints or moving gold linework. Keep it restrained enough that common cards remain readable.

## 11.10 Score milestones

When crossing the round target, the target marker should crack/burst and the score bar continue filling rather than simply changing text. The player should instantly know: **I have secured the round; everything else is greed.**

---

# 12. Small quality-of-life features that increase strategic depth

These are not glamorous but will make advanced play much better.

## Placement preview breakdown

Before committing, show small optional preview text:

- `2 lines`
- `+3 Gold Credits`
- `Encore x2`
- `Jokers: +150 Chips, +2 Mult`

This can be hidden behind a setting if it feels too analytical.

## Fit indicators

On tray pieces, show:

- normal: has legal placements,
- warning: very few legal placements,
- red: no legal placements.

This avoids tedious manual scanning and lets the player focus on strategy.

## Bag statistics panel

In the bag screen show:

- family counts,
- average cell count,
- material counts,
- stamp counts,
- colors,
- upgraded-piece count,
- bag size and min/max.

Important for understanding Hoarder, Lean Bag, Collector, Foundry and future synergies.

## Joker trigger counters

For every Joker with a cadence/streak, show live progress directly on the card:

- `2/3`
- `LEFT -> RIGHT`
- `Stored: +120`
- `Clears: 2`

The current Golden Ratio / Compound Interest style counters are a good pattern to extend.

## “Why didn’t this trigger?” tooltip

After a placement, hovering a non-triggered conditional Joker can optionally state its failed condition, for example:

`Needed 3 different families; Bar 3 repeated.`

Extremely helpful as the catalog becomes larger.

---

# 13. Existing unfinished features worth finishing before inventing equivalents

The current source already contains several good concepts that are intentionally unavailable because their target-selection/UI interaction is unfinished:

- **Patch Panel** — remove one extra occupied cell after the first clear.
- **Eraser** — remove up to two selected occupied cells.
- **Lucky Paint** — recolor one tray shape.
- **Blueprint** — replace a tray shape with a chosen small shape.
- **Echo Chamber boss** exists in data but is withheld because the current game does not naturally produce extra clear waves often enough for its rule to matter.

These are valuable because implementing generic **cell targeting**, **tray-piece targeting**, and **choice UI** unlocks many future ideas in this document at once.

A strong engineering priority is therefore not “add 20 bespoke buttons”; it is **build one reusable targeting/action framework** and let content data describe what it needs.

---

# 14. Recommended new effect/context hooks

To support many of these ideas cleanly, extend the resolver context rather than hard-coding Joker IDs into board logic.

Useful deterministic fields/events:

- `occupied_after`
- `empty_after`
- `holes_before`
- `holes_after`
- `holes_filled`
- `orthogonal_neighbors_before/after`
- `clusters_before`
- `clusters_after`
- `clusters_connected`
- `quadrant_mask`
- `left_half_cells`
- `right_half_cells`
- `center_cells`
- `edge_ring_cells`
- `material_types_cleared`
- `colors_cleared`
- `families_history`
- `cell_count_history`
- `clear_streak`
- `nonclear_streak`
- `tray_start_families`
- `piece_seen_count_this_round`
- `piece_uid_seen_count_this_round`
- `feats`
- `runes_covered`
- `runes_cleared`
- `contract_progress`

Try to compute board-analysis metadata once per placement and pass it through the context. Jokers should generally *read context and return effects*, not re-scan or mutate the board independently.

For deterministic random effects, continue deriving results from stable run state / seeded streams. Never let visual animation RNG alter gameplay RNG.

---

# 15. Suggested implementation order

## Phase 1 — High fun, low architectural risk

1. **Joker activation animation + scoring breakdown.**
2. **Feat detector** for 8-10 obvious feats.
3. Add 8-12 new Jokers using mostly existing context:
   - Patience
   - Three-Beat
   - Family Business
   - Precision Engineering
   - Deep Pockets
   - Coupon Clipper
   - Pawn Broker
   - Gold Standard
   - Variety Act
   - Pendulum
4. **Boss Intel** before the pre-boss shop.
5. Add 3-4 bosses with simple deterministic rules:
   - Auditor
   - Warden
   - Eclipse
   - Forger
6. Add **bag statistics** and better live Joker counters.

These alone should make runs feel significantly more expressive.

## Phase 2 — More tactical agency

1. Build reusable target-selection UI.
2. Finish Patch Panel, Eraser, Lucky Paint and Blueprint.
3. Add **Hold**.
4. Add **Draw Forecast**.
5. Add new consumables such as Emergency Brick, X-Ray, Stabilizer and Blackout.
6. Add Mirror Jig / Transfer Press / Plating Transfer to the Workshop.
7. Introduce **Contracts**.

At this point the board loop should feel much more like a true roguelike puzzle rather than “place until shop”.

## Phase 3 — Run identity and replayability

1. Rune Cells.
2. Stage Routes.
3. More Kits.
4. Heat / Greed.
5. Joker Augments.
6. Ascension.
7. Daily seeded challenge / share codes.
8. Multi-phase final bosses.

## Phase 4 — Experimental systems

Only after the core is stable:

- custom piece geometry via Die Cutter/Welder,
- advanced cursed-cell mechanics,
- large-scale meta progression,
- online leaderboards,
- highly stateful Joker transformations.

These are exciting but increase save compatibility, UI complexity and simulation burden much more than another data-driven Joker.

---

# 16. A concrete “next content update” proposal

If I were choosing one reasonably scoped update designed specifically to make the current game **noticeably more fun**, I would ship:

### New gameplay feature
- Contracts: 12 contract templates, choose 1 of 3 each normal round.

### New Feats
- Crossfire
- Double Tap
- Hat Trick
- Clean Board
- Needle Threader
- Full Spectrum
- Golden Sweep
- Last Breath

### 12 Jokers
- Pendulum
- Bridge Builder
- Locksmith
- Variety Act
- Patience
- Hot Streak
- Alchemist
- Gold Standard
- Breakage Bonus
- Precision Engineering
- Coupon Clipper
- Bounty Hunter

### 6 Consumables
- Emergency Brick
- X-Ray
- Prism Flash
- Stabilizer
- Blackout
- Golden Ticket

### 4 Bosses
- The Auditor
- The Eclipse
- The Warden
- The Forger

### Polish
- Joker activation animation.
- Material-specific clear effects.
- Score breakdown animation.
- Clean Board celebration.
- Better bag stats.
- Boss intro/telegraph.

This update adds many new combinations, but more importantly it creates **new decisions during actual placement**.

---

# 17. Balance rules for future content

These rules should keep the catalog fun as it grows.

1. **Prefer conditional power over universal power.** `x1.6 if you do something interesting` is better than `x1.3 always`.
2. **Cap positive feedback loops.** Economy -> more economy -> more multipliers can destroy the target curve quickly.
3. **Reward setup as well as payoff.** Not every card should trigger only after a line is already cleared.
4. **Give weak shapes a reason to exist.** Avoid making every optimal bag converge on Singles/Bars.
5. **Let archetypes overlap.** A Gold piece can also be stamped, belong to a specialized family and satisfy a Contract. Those intersections create roguelike magic.
6. **Bosses should be telegraphed and counterable.** A boss is more fun when the player thinks “I prepared for this” than “the game disabled my build”.
7. **Do not solve the board for the player.** Forecasting and previews should communicate consequences, not recommend the optimal placement.
8. **Keep RNG seeded and explainable.** Glass shatter, offers, contracts, runes and boss hazards should all remain replay-safe.
9. **Make every effect visually attributable.** If the player cannot tell which Joker/material caused a payoff, the build feels weaker than it actually is.
10. **Simulate new scoring cards before shipping.** The current balance methodology is a major strength; preserve it as the catalog grows.

---

# 18. Core vision

Blockmania is most interesting when it is not merely “Block Blast with score multipliers”. Its strongest identity is:

> **A deterministic block-puzzle roguelike where the player engineers the bag itself, builds bizarre synergies, and deliberately bends each 8x8 board around those synergies.**

The next layer of development should therefore focus on **agency, build identity and spectacle**:

- more things to plan *during* a round,
- more Jokers that change placement behavior,
- more interaction between materials/stamps/families,
- bosses that create puzzles rather than flat penalties,
- optional objectives that make every round different,
- and strong audiovisual feedback whenever the player's build fires.

That direction preserves the simple core while giving the game the same “I found something broken and clever” appeal that makes great score-attack roguelikes endlessly replayable.
