# BLOCKMANIA trailer: style sheet and shot plan

Status: v1, 2026-09-25. Code-authored like the rest of the project: the picture is a JavaScript
canvas/WebGL render (`trailer.html`), the music is synthesized in Python (`gen_score.py`), and
every sprite, font and effect comes from the game's own generated assets. No stock, no
image-generator art, no samples.

## The idea in one line

**The 8×8 is the frame.** Words are built out of toy blocks, scenes end in line clears, and one
score counter climbs for the whole minute until it breaks the machine.

A player of Balatro, Luck Be a Landlord or CloverPit wants three things from a trailer: the loop
at a glance, the build fantasy (cards that bend rules), and **number go up**. BLOCKMANIA's unique
promise is that a block puzzle everyone already knows can reach **one quadrillion points in a
single placement**. The trailer is built around that escalation.

## Name of the style: Toy Arcade Brutalism

The game's chunky pixel toy look, cut like a loud poster:

- flat slabs of saturated color, hard edges, no gradients except the dithered swirl;
- raw game sprites dropped in at big whole-number scales with **hard offset shadows** (no blur),
  like stickers on a cabinet;
- giant type that crops off the frame edges;
- tickers, stamps, receipts and hazard tape as graphic devices.

It is loud but disciplined: one grid, one typeface, one palette, one motion rule.

### What it is not

- Not glossy 3D, Pixar-like characters, lens flares or cinematic camera moves.
- Not a Balatro copy: no playing cards, felt, chips or poker words. Our motifs are **blocks,
  receipts, arcade machines and toy stores**.
- Not "AI slop": no generic neon gradients, sparkle overlays, stock "epic" risers without a musical
  reason, or text that floats with no purpose.

## Grid

- Canvas 1920×1080 at 60 fps. Macro grid **16×9 cells of 120 px**. Every headline baseline, sticker
  and panel snaps to it. A full-width board row is 8 cells of 240 px.
- Safe title area: 96 px inset. Steam overlays the play bar at the bottom, so keep subtitles above
  y = 960.
- Composition rule: **big type on one side, action on the other.** When type is mega, the
  background goes flat (a single color slab, or the swirl at low contrast).

## Palette (from `BMStyle`)

| Token | Hex | Role |
|---|---|---|
| INK | `#1a1026` | default background, type on light slabs |
| PLUM_DD / PLUM_D / PLUM | `#211631` `#2d1e43` `#3f2b5e` | panels, swirl base |
| CREAM | `#fff3db` | type on dark, receipts |
| SUN | `#ffcc3d` | hero accent, score, "PLACE" |
| MINT | `#3dd691` | success, "CLEAR", positive |
| PINK | `#ff4d6d` | Mult, danger, Jokers |
| SKY | `#4daaff` | Chips, info |
| LILAC | `#b388ff` | legendary, rare moments |
| Boss red | `#c82850` + hazard SUN/INK stripes | boss section only |

Hard rule: a frame has one dominant slab color plus INK/CREAM, with at most two accent colors.
Full rainbow only in two places: block-built words and the finishes montage.

## Type

- **Blockhead** (the project's own font), bold for display and regular for subtitles. Sizes are
  multiples of 10 px (em = 10 font pixels) so glyphs stay on the pixel grid. Tiers:
  - **MEGA** 300–600 px: one or two words, crops the frame, lands on a downbeat.
  - **HEAD** 120–160 px: left column, with the action on the right.
  - **SUB** 40–50 px: subtitle bar on an INK slab, above the Steam controls.
- **BLOCKTYPE**: a word rasterized from Blockhead at 10 px, each lit pixel drawn as a real
  glossy block sprite. Used for PLACE / CLEAR, the logo and the final line. Blocks fall in like
  pieces and leave in a line clear.
- Numbers are heroes: tabular, rolling odometer digits, always with thousands separators and
  the game's M/B/T/Q suffixes.

## Motion rules

1. **Snap and settle.** Things arrive fast (expo-out, 120–220 ms) and land with the block squash:
   1 frame of 8% squash, then settle. Nothing floats or drifts without a reason.
2. **On the beat.** 120 BPM, a beat is 0.5 s. Hard cuts land on beats. Type appears on beats or
   8th notes. Every impact has a sound in the score.
3. **Transitions are game mechanics.** Scenes leave by line clear (rows or columns pop with a
   white flash and particles), by slam (a slab drops over the frame), or by breaking the machine
   (glitch, then the CRT collapses).
4. **Shake and aberration are earned.** Only on impacts, scaled by magnitude, decaying within
   about 250 ms.
5. **Deterministic.** `render(t)` is a pure function of time. Particles are analytic functions of
   their spawn event, so any frame can be rendered in any order, in parallel chunks.

## Texture

- The game's domain-warped swirl, posterized with a Bayer 4×4 dither on a 6 px grid. Its palette
  shifts by section: plum, teal toybox, red boss, full-color climax.
- A light CRT pass: faint scanlines, edge chromatic aberration, a vignette, and `shock` pulses on
  impacts. Soft enough that 1080p compression stays clean.
- Grain at 2%, kept low because H.264 punishes noise.

## Sound (score)

"Toy chip-house" at 120 BPM in F minor (Fm, Db, Ab, Eb): four-on-the-floor kick, sidechained saw
chords, a square-wave hook, music-box bells and a formant chant ("BLOCK-MA-NI-A") built from the
POPS vowel voice. The game's own SFX (placement, clears, coins, boss slam, lever) are laid on
the picture cues. The boss section drops to half time with a siren and sub drone. The climax
brings everything back and ends in the bit-crushed `machine_break`, then silence and the end
card. Mastered to about -14 LUFS with a -1 dBTP ceiling (Steam downmixes to stereo, and we are
already stereo).

## Shot plan (v2 cut, 64 s; bar = 2 s, beat = 0.5 s)

Owner feedback on v1 (2026-09-25): the first 12 s were too long, so gameplay now starts at 6 s.
The Legendaries live inside the Joker wall, the shop reroll matches the game (the REROLL button
replaces all five offers and its price rises by 1), and the end card carries a pixel Steam mark.
Scenes after the hook keep their v1 clocks through `shift` (see `scene()` in `scenes.js`).

| Time | Section | Picture | Type |
|---|---|---|---|
| 0–1 | PLACE | Block letters land on 16ths, and a 2×2 full stop slams. | BLOCKTYPE "PLACE." |
| 1–2 | CLEAR | A full-width row fills on 32nds and clears in a white flash. | MEGA "CLEAR" |
| 2–3 | ×MULT | Four Joker stickers slam on 8th notes, and ×Mult pills fly out. | MEGA "×MULT" |
| 3–4 | BREAK | The counter runs from 144 to a quadrillion, and the glass cracks. | "BREAK THE MACHINE." |
| 4–6 | LOGO | The block logo drops, then clears. | "THE BLOCK PUZZLE ROGUELIKE" |
| 6–14 | HOW | Board, tray, drag, ghost, double clear, target, ROUND CLEARED. | 01–04 steps |
| 14–18 | RECEIPT | The receipt prints and the equation builds. | "CHIPS × MULT = POINTS" |
| 18–24 | JOKERS | The wall of 70 lights up with the Legendaries glowing and a rarity row, then four featured cards. | "70 JOKERS", GROW / COPY / STACK / DOUBLE |
| 24–28 | SHOP | A card is bought, then REROLL replaces every offer. | "THE TOYBOX" |
| 28–32 | FINISHES | The material swaps on every beat. | GOLD … AURORA |
| 32–40 | BOSS | Hazard tape, names, MK II, round track. | boss names |
| 40–48 | CLIMAX | Chain board, then feature bars with in-game screenshots. | COMBO … / features |
| 48–56 | MILESTONES | 1 million to 1 quadrillion, then MACHINE BROKEN and the CRT turns off. | MEGA numbers |
| 56–64 | END | POPS asks "ONE MORE RUN?", then the logo and the Steam wishlist button. | "WISHLIST ON STEAM" |

## Checks before calling it done

- Watch muted: is the loop understandable, and is every text readable within its hold time?
  Readable means at least 3 frames of full opacity per word, plus 1 s for a sentence of up to 6
  words.
- Contact sheet at 2 fps: does each second have one clear focal point?
- Freeze frames at every downbeat: do the grid and palette rules hold?
- Audio: loudness about -14 LUFS, no clipping, and SFX line up with picture cues within 1 frame.
- Encode: H.264 High, 1920×1080, 60 fps, about 16 Mbps, AAC 320 kbps, `+faststart`.
