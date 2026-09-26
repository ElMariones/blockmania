"""Money sound effects: the wallet, flying coins and cards bought or sold (2026-09-26).

Same palette and loudness rules as gen_sfx.py (it provides the helpers). Everything is
synthesized; no samples.

  coin_flip     the wallet is clicked: a thumb flick and a spinning coin in the air
  coin_catch    ... and it lands back in the palm (the game raises its pitch on a streak)
  coin_collect  one flying coin reaches the wallet (pitched up coin after coin)
  coin_out      coins leave the wallet to pay for something
  card_land     a bought card slaps down in the rack
  card_poof     a sold card bursts into coins
  coin_jackpot  a long clicking streak on the wallet: a little fountain of coins

Run:  python tools/audio/gen_sfx_money.py
"""
import os
import numpy as np

from dsp import (bandpass, bell, env_exp, highpass, lowpass, midi_hz, noise, osc, saturate, timeline,
                 Track, rng)
from gen_sfx import OUT, write, woody, plastic, whoosh, sparkle, coin_blip, tone


def metal_ping(midi, dur=0.5, vel=1.0):
    """A small coin struck: inharmonic partials of a thin metal disc."""
    f = midi_hz(midi)
    t = timeline(dur)
    out = np.zeros(len(t))
    for ratio, gain, decay in ((1.0, 1.0, 9.0), (2.32, 0.55, 14.0), (3.86, 0.3, 22.0), (5.4, 0.16, 30.0)):
        out += np.sin(2 * np.pi * f * ratio * t) * np.exp(-t * decay) * gain
    return out * vel


def spin(dur=0.3, midi=96, rate=26.0):
    """A coin spinning in the air: a high ring whose loudness flutters as the face turns."""
    t = timeline(dur)
    ring = np.sin(2 * np.pi * midi_hz(midi) * t) + 0.4 * np.sin(2 * np.pi * midi_hz(midi) * 2.3 * t)
    flutter = 0.5 + 0.5 * np.abs(np.sin(np.pi * rate * t * (1.0 - 0.35 * t / dur)))
    return ring * flutter * np.exp(-t * 6.0)


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    r = rng(2600)

    # Flick: a thumbnail tick, the struck coin, and the spin while it is in the air.
    tr = Track(0.6)
    tr.add(bandpass(noise(0.01, 2601), 2500, 9000, 1) * np.exp(-timeline(0.01) * 500) * 0.9, 0.0)
    tr.add(metal_ping(93, 0.4, 0.7), 0.004)
    tr.add(spin(0.34, 98) * 0.28, 0.02)
    write("coin_flip", tr.buf, -11, room=0.08, t60=0.4)

    # Catch: a soft palm slap and the coin's short ring, damped by the hand.
    tr = Track(0.4)
    slap = lowpass(noise(0.05, 2602), 1800, 2) * env_exp(0.05, 0.03) * 0.8
    tr.add(slap, 0.0)
    tr.add(plastic(62, 0.12, 0.5, seed=2603, thud=0.8), 0.0)
    tr.add(metal_ping(90, 0.18, 0.45), 0.005)
    write("coin_catch", tr.buf, -12, room=0.06, t60=0.3)

    # Collect: one coin drops into the wallet, a bright two-step blip over a tiny clink.
    tr = Track(0.35)
    tr.add(coin_blip(86, 93, 0.16, 0.8), 0.0)
    tr.add(metal_ping(98, 0.2, 0.3), 0.0)
    write("coin_collect", tr.buf, -13, room=0.06, t60=0.3)

    # Coins out: a purse snap, then a short falling run of coins leaving the wallet.
    tr = Track(0.7)
    tr.add(woody(79, 0.05, 0.8, seed=2604), 0.0)
    for i in range(5):
        tr.add(metal_ping(95 - i * 1.5, 0.22, r.uniform(0.35, 0.6)), 0.03 + i * 0.045 + r.uniform(0, 0.01),)
    tr.add(whoosh(0.22, 3500, 900, seed=2605) * 0.25, 0.05)
    write("coin_out", tr.buf, -11, room=0.1, t60=0.4)

    # Card lands: a paper flap and a slap on the rack, a small bell on top.
    tr = Track(0.8)
    flap = highpass(noise(0.08, 2606), 1200, 2) * env_exp(0.08, 0.05) * 0.5
    tr.add(flap, 0.0)
    tr.add(plastic(57, 0.18, 0.8, seed=2607, thud=1.1), 0.03)
    tr.add(bell(93, 0.6, 0.35), 0.05)
    tr.add(bell(98, 0.5, 0.22), 0.1)
    write("card_land", tr.buf, -9, room=0.12, t60=0.5)

    # Card poof: a quick whoosh and a soft pop, then glittering coins spill out.
    tr = Track(0.9)
    tr.add(whoosh(0.18, 900, 5000, seed=2608) * 0.6, 0.0)
    pop = osc(np.linspace(midi_hz(70), midi_hz(58), 2000), 0.09, "sine") * env_exp(0.09, 0.06)
    tr.add(pop * 0.8, 0.14)
    tr.add(sparkle(0.3, 7, 91, 101, 2609, 0.3), 0.16)
    write("card_poof", tr.buf, -10, room=0.14, t60=0.5)

    # Jackpot: a rising run of coin blips and a bright chord, for a long clicking streak.
    tr = Track(1.4)
    for i, m in enumerate((81, 83, 86, 88, 90, 93, 95, 98)):
        tr.add(coin_blip(m, m + 5, 0.14, 0.7), i * 0.045, pan=(i / 7 - 0.5) * 0.6)
    for i, m in enumerate((86, 90, 93, 98)):
        tr.add(bell(m, 0.9, 0.35), 0.38 + i * 0.02)
    tr.add(sparkle(0.6, 12, 93, 106, 2610, 0.22), 0.4)
    write("coin_jackpot", saturate(tr.buf, 1.1), -7, room=0.16, t60=0.8)


if __name__ == "__main__":
    main()
