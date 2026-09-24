"""Sound effects for boss intros, Mk II bosses, danger, Hold and round cards (GDD §22).

Same palette and loudness rules as gen_sfx.py (it provides the helpers). Everything is
synthesized; no samples.

Run:  python tools/audio/gen_sfx_bosses.py
"""
import os
import numpy as np

from dsp import (mix, bandpass, bell, bitcrush, env_exp, highpass, lowpass, midi_hz, noise, osc,
                 pad, saturate, sweep, Track, rng, kick, snare, pluck, hat)
from gen_sfx import OUT, write, woody, plastic, whoosh, chime_chord, sparkle


def siren(dur, lo, hi, rate, seed=0):
    """Two-tone rising/falling alarm (square, band-limited)."""
    t = np.arange(int(dur * 44100)) / 44100.0
    f = lo + (hi - lo) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * rate * t)))
    ph = np.cumsum(2 * np.pi * f / 44100.0)
    x = np.sign(np.sin(ph)) * 0.5 + np.sin(ph * 2) * 0.2
    return lowpass(x * env_exp(dur, dur * 1.6, 0.01), 3500, 2)


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    r = rng(1400)

    # Boss alarm: a two-tone arcade siren over a low drone, rising into the slam.
    tr = Track(1.6)
    tr.add(siren(1.1, midi_hz(64), midi_hz(71), 4.0) * 0.45, 0.0)
    drone = osc(sweep(midi_hz(28), midi_hz(35), 1.2), 1.2, "saw") * env_exp(1.2, 2.0, 0.2)
    tr.add(lowpass(saturate(drone * 0.6, 1.8), 700, 2) * 0.6, 0.0)
    tr.add(whoosh(0.9, 200, 4000, seed=1401) * 0.3, 0.5)
    write("boss_alarm", tr.buf, -6, room=0.2, t60=0.8)

    # Boss slam: the name hits the screen. Sub kick, metal crash, low brass stab.
    tr = Track(1.6)
    tr.add(kick(1.0, 0.7), 0.0)
    tr.add(lowpass(kick(1.0, 0.5), 180, 2) * 0.8, 0.0)
    crash = bandpass(noise(1.2, 1402), 400, 9000, 1) * env_exp(1.2, 0.9)
    tr.add(crash * 0.55, 0.0)
    for m, d in ((38, 0.0), (45, 0.01), (50, 0.02)):
        stab = saturate(osc(midi_hz(m), 0.7, "saw") * env_exp(0.7, 0.5, 0.004), 2.0)
        tr.add(lowpass(stab, 1600, 2) * 0.28, d)
    write("boss_slam", tr.buf, -3, room=0.28, t60=1.2)

    # Mk II stamp: a heavy metal press, a ratchet and sparks.
    tr = Track(1.2)
    clank = mix(woody(40, 0.2, 1.0, seed=1403), plastic(33, 0.4, 0.9, seed=1404, thud=1.4))
    tr.add(clank, 0.0)
    ring = sum(osc(midi_hz(m), 0.9, "sine") * env_exp(0.9, 0.7) * g for m, g in ((81, 0.2), (88.3, 0.12), (95.1, 0.08)))
    tr.add(ring, 0.0)
    for i in range(6):
        tr.add(woody(96 + i * 0.5, 0.02, 0.3, seed=1405 + i), 0.12 + i * 0.04)
    tr.add(sparkle(0.5, 10, 98, 110, 1411, 0.14), 0.05)
    write("mk2_stamp", bitcrush(tr.buf, 12), -4, room=0.22, t60=0.7)

    # Heartbeat: danger (three or fewer placements and short of the target). Soft, low.
    tr = Track(0.7)
    tr.add(lowpass(kick(0.8, 0.6), 140, 2), 0.0)
    tr.add(lowpass(kick(0.6, 0.55), 140, 2) * 0.7, 0.2)
    write("heartbeat", tr.buf, -14, room=0.05, t60=0.2)

    # Danger on: a quiet low swell when the round turns critical.
    tr = Track(1.4)
    tr.add(pad([40, 47, 52], 1.2, bright=600, seed=1420, attack=0.4) * 0.6, 0.0)
    tr.add(bell(64, 1.0, 0.25), 0.1)
    write("danger_on", tr.buf, -12, room=0.2, t60=1.0)

    # Hold: store a piece (a soft drawer slide and a click).
    tr = Track(0.5)
    tr.add(whoosh(0.18, 3000, 800, seed=1430) * 0.4, 0.0)
    tr.add(woody(76, 0.06, 0.7, seed=1431), 0.12)
    tr.add(plastic(71, 0.12, 0.5, seed=1432, thud=0.6), 0.14)
    write("hold_store", tr.buf, -10, room=0.1, t60=0.3)

    # Round card chosen: a card flip and a rising two-note chime; twists get a sparkle.
    tr = Track(1.0)
    tr.add(bandpass(noise(0.12, 1440), 1500, 7000, 2) * env_exp(0.12, 0.08) * 0.6, 0.0)
    tr.add(pluck(79, 0.6, 0.5, seed=1441), 0.05)
    tr.add(pluck(86, 0.7, 0.5, seed=1442), 0.14)
    tr.add(sparkle(0.4, 6, 96, 104, 1443, 0.12), 0.2)
    write("round_pick", tr.buf, -8, room=0.2, t60=0.8)

    # Act stinger: a new act begins (a short brass-like fanfare).
    tr = Track(1.6)
    for i, (m, d) in enumerate(((60, 0.0), (67, 0.12), (72, 0.24))):
        note = saturate(osc(midi_hz(m), 0.9 - i * 0.1, "saw") * env_exp(0.9 - i * 0.1, 0.8, 0.02), 1.4)
        tr.add(lowpass(note, 2200, 2) * 0.22, d)
    tr.add(chime_chord([72, 76, 79, 84], 1.0, 0.03, 0.4), 0.36)
    tr.add(kick(0.7), 0.36)
    write("act_start", tr.buf, -6, room=0.28, t60=1.2)
    print("wrote boss and feature cues to", OUT)


if __name__ == "__main__":
    main()
