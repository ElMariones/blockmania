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

## Shot plan (bar = 2 s, beat = 0.5 s; b = beat index from 0)

| Beats | Time | Section | Picture | Type |
|---|---|---|---|---|
| 0–4 | 0–2 | HOOK 1 | SUN slab. A red L piece is already falling at frame 0 and slams into a giant 4-cell stack; dust, shake. | BLOCKTYPE "PLACE" |
| 4–8 | 2–4 | HOOK 2 | INK. One full-width row of eight 240 px blocks fills on 8th notes, then clears in a white flash. | MEGA "CLEAR" |
| 8–12 | 4–6 | HOOK 3 | PINK. Joker stickers slam in on each beat, ×Mult pills fly. | MEGA "×MULT" |
| 12–16 | 6–8 | HOOK 4 | The score odometer rolls from 144 to a quadrillion; digits crop the frame, glitch. | "BREAK THE MACHINE." |
| 16–24 | 8–12 | LOGO | The BLOCKMANIA blocktype logo drops letter by letter over the swirl. | "THE BLOCK PUZZLE ROGUELIKE" + tagline |
| 24–40 | 12–20 | HOW | Board on the right, a cursor drags pieces from the tray, ghost preview, double clear, target bar, ROUND CLEARED stamp. | HEAD lines at left: "8×8 BOARD" / "3 PIECES" / "FILL A ROW OR COLUMN" / "BEAT THE TARGET" |
| 40–48 | 20–24 | RECEIPT | The receipt tape prints line by line; the equation builds. | "CHIPS × MULT" + SUB "Every point itemized." |
| 48–64 | 24–32 | JOKERS | A wall of 69 portraits in a diagonal wave, then four featured cards trigger in order. | MEGA "69 JOKERS", SUB "Grow them. Copy them. Double everything." |
| 64–72 | 32–36 | SHOP | Awning stripes, cards drop with prices, coins. | "THE TOYBOX" + SUB "Buy Jokers. Build your bag." |
| 72–80 | 36–40 | FINISHES | A full board of animated finishes; the material swaps on every beat. | MEGA per beat: GOLD / NEON / LAVA / PRISM / CHROME / ICE / STARFALL / AURORA |
| 80–96 | 40–48 | BOSS | Hazard tape, WARNING marquee, red swirl. Boss names, MK II stamp. Half time. | "THE WARDEN" / "THE LOCKDOWN MK II" / "THE LAST CALL" + SUB "12 rounds. 3 acts. Every boss rewrites a rule." |
| 96–112 | 48–56 | CLIMAX 1 | A chain-reaction board, clears on every beat, the counter racing. Then feature pills stack. | per beat: COMBO / TRIPLE! / OVERKILL, then pills |
| 112–128 | 56–64 | CLIMAX 2 | Milestones 1 MILLION → 1 BILLION → 1 TRILLION → 1 QUADRILLION; the machine breaks and the CRT collapses. | MEGA numbers |
| 128–144 | 64–72 | END | Silence, then POPS asks "ONE MORE RUN?", logo, call to action. | "WISHLIST ON STEAM" |

## Checks before calling it done

- Watch muted: is the loop understandable, and is every text readable within its hold time?
  Readable means at least 3 frames of full opacity per word, plus 1 s for a sentence of up to 6
  words.
- Contact sheet at 2 fps: does each second have one clear focal point?
- Freeze frames at every downbeat: do the grid and palette rules hold?
- Audio: loudness about -14 LUFS, no clipping, and SFX line up with picture cues within 1 frame.
- Encode: H.264 High, 1920×1080, 60 fps, about 16 Mbps, AAC 320 kbps, `+faststart`.
