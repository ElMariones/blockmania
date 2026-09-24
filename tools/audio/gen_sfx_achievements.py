"""Sound effects for achievements, the Trophy Case and Overtime (GDD §19, §20).

Unlock fanfares rise with the badge tier (bronze < silver < gold < legend); secret badges get
their own "reveal"; the Trophy Case has page flips and a hover tick; Overtime has its entry
sting, a new-record sting and the glitchy "machine broke" crash. Same palette and loudness
rules as gen_sfx.py (it provides the helpers). Everything is synthesized; no samples.

Run:  python tools/audio/gen_sfx_achievements.py
"""
import os
import numpy as np

from dsp import (mix, bandpass, bell, bitcrush, env_exp, epiano, highpass, lowpass, midi_hz, noise, osc,
                 pad, samples, saturate, sweep, timeline, Track, rng, kick, snare, pluck, hat)
from gen_sfx import OUT, write, woody, plastic, whoosh, chime_chord, sparkle, coin_blip


def arp(notes, step, inst="bell", vel=0.5, dur=0.9, seed=0):
    tr = Track(step * len(notes) + dur + 0.2)
    for i, m in enumerate(notes):
        if inst == "bell":
            tr.add(bell(m, dur, vel), i * step, pan=-0.4 + 0.8 * i / max(1, len(notes) - 1))
        elif inst == "pluck":
            tr.add(pluck(m, dur, vel, seed=seed + i), i * step)
        else:
            tr.add(epiano(m, dur, vel, seed=seed + i), i * step)
    return tr.buf


def main() -> None:
    os.makedirs(OUT, exist_ok=True)

    # --- Unlock fanfares ----------------------------------------------------------------------
    # Bronze: a bright two-note "ding-ding" with a wooden knock.
    tr = Track(1.2)
    tr.add(woody(79, 0.08, 0.6, seed=900), 0.0)
    tr.add(arp([81, 88], 0.09, "bell", 0.5, 0.8), 0.02)
    tr.add(sparkle(0.4, 6, 94, 102, 901, 0.15), 0.12)
    write("ach_bronze", tr.buf, -7, room=0.22, t60=0.9)
    # Silver: a rising major triad with a shimmer.
    tr = Track(1.5)
    tr.add(arp([76, 81, 85, 88], 0.07, "pluck", 0.55, 0.7, seed=910), 0.0)
    tr.add(chime_chord([88, 93], 0.9, 0.04, 0.4), 0.28)
    tr.add(sparkle(0.6, 10, 95, 105, 911, 0.16), 0.25)
    write("ach_silver", tr.buf, -6, room=0.25, t60=1.1)
    # Gold: arpeggio up an octave and a half, a kick under the final chord, coins sprinkle.
    tr = Track(2.2)
    tr.add(arp([72, 76, 79, 84, 88, 91], 0.06, "epiano", 0.55, 0.9, seed=920), 0.0)
    tr.add(chime_chord([84, 88, 91, 96], 1.3, 0.03, 0.5), 0.36)
    tr.add(kick(0.7), 0.36)
    for i in range(6):
        tr.add(coin_blip(88 + (i % 3) * 2, 95, 0.2, 0.35), 0.42 + i * 0.07)
    tr.add(sparkle(0.9, 16, 96, 108, 921, 0.18), 0.4)
    write("ach_gold", tr.buf, -5, room=0.28, t60=1.4)
    # Legend: a slow shimmering swell into a big bell chord and a cascade.
    tr = Track(3.2)
    tr.add(pad([60, 67, 72, 76], 2.2, bright=2400, seed=930, attack=0.5) * 0.5, 0.0)
    tr.add(whoosh(0.7, 400, 7000, seed=931) * 0.35, 0.0)
    tr.add(chime_chord([72, 79, 84, 88, 91], 1.8, 0.05, 0.55), 0.62)
    tr.add(kick(0.9), 0.62)
    tr.add(arp([96, 91, 88, 84, 91, 96, 100], 0.07, "bell", 0.35, 0.7), 0.8)
    tr.add(sparkle(1.4, 26, 96, 110, 932, 0.18), 0.7)
    write("ach_legend", tr.buf, -4, room=0.32, t60=1.8)
    # Secret reveal: a descending minor whisper that flips into major.
    tr = Track(2.0)
    tr.add(arp([83, 79, 76], 0.1, "pluck", 0.4, 0.6, seed=940), 0.0)
    tr.add(whoosh(0.4, 3000, 300, seed=941) * 0.3, 0.1)
    tr.add(chime_chord([76, 80, 83, 88], 1.2, 0.05, 0.5), 0.42)
    tr.add(sparkle(0.7, 12, 92, 104, 942, 0.16), 0.45)
    write("ach_secret", tr.buf, -6, room=0.3, t60=1.3)

    # --- Trophy Case ----------------------------------------------------------------------------
    tr = Track(1.4)
    tr.add(whoosh(0.35, 500, 3500, seed=950) * 0.4, 0.0)
    tr.add(chime_chord([79, 84, 88], 0.9, 0.05, 0.4), 0.12)
    tr.add(woody(67, 0.12, 0.6, seed=951), 0.1)
    write("trophy_open", tr.buf, -8, room=0.25, t60=1.0)
    # Page flip: a papery swish with a soft card tap.
    swish = bandpass(noise(0.2, 960), 1500, 7000, 2) * env_exp(0.2, 0.12, 0.03)
    write("page_flip", mix(swish * 0.8, woody(84, 0.05, 0.4, seed=961)), -12, room=0.08, t60=0.3)
    # Badge hover: a tiny glassy tick.
    write("badge_hover", bell(100, 0.18, 0.4) * env_exp(0.18, 0.1), -20, room=0.05, t60=0.2)
    write("badge_locked", mix(woody(55, 0.09, 0.6, seed=970), plastic(48, 0.12, 0.4, seed=971, thud=0.6)), -16)

    # --- Overtime -----------------------------------------------------------------------------
    # Overtime entry: a clock tick-tock that snaps into a driving low hit and a rising alarm.
    tr = Track(1.8)
    for i in range(4):
        tr.add(woody(84 if i % 2 == 0 else 79, 0.06, 0.7, seed=980 + i), i * 0.14)
    tr.add(kick(1.0, 0.8), 0.56)
    tr.add(saturate(osc(sweep(midi_hz(52), midi_hz(64), 0.5), 0.5, "saw") * env_exp(0.5, 0.45), 1.6) * 0.3, 0.56)
    tr.add(chime_chord([76, 83, 88], 1.0, 0.03, 0.45), 0.6)
    write("overtime", tr.buf, -5, room=0.22, t60=1.0)
    # New record: a fast "ta-da" and a ratcheting counter.
    tr = Track(1.4)
    for i in range(8):
        tr.add(woody(86 + i, 0.03, 0.5, seed=990 + i), i * 0.035)
    tr.add(arp([84, 91], 0.12, "epiano", 0.6, 0.9, seed=995), 0.3)
    tr.add(chime_chord([84, 88, 91, 96], 0.9, 0.03, 0.45), 0.42)
    write("record_new", tr.buf, -6, room=0.24, t60=1.0)
    # The machine breaks: bit-crushed overload, a power-down sweep and scattered sparks.
    r = rng(1000)
    dur = 2.4
    buzz = saturate(osc(sweep(midi_hz(40), midi_hz(88), 0.6), 0.6, "square") * env_exp(0.6, 1.0), 3.0)
    crash = bandpass(noise(0.9, 1001), 200, 6000, 1) * env_exp(0.9, 0.6)
    down = osc(sweep(midi_hz(76), midi_hz(28), 1.2), 1.2, "saw") * env_exp(1.2, 1.4)
    tr = Track(dur)
    tr.add(bitcrush(buzz * 0.5, 5), 0.0)
    tr.add(kick(1.0, 0.6), 0.6)
    tr.add(crash * 0.7, 0.6)
    tr.add(bitcrush(down * 0.4, 6), 0.7)
    for i in range(10):
        tr.add(bell(90 + r.integers(0, 14), 0.25, 0.25), 0.7 + r.uniform(0, 1.2))
    write("machine_break", lowpass(tr.buf, 9000, 2), -3, room=0.2, t60=1.2)
    print("wrote achievement and overtime cues to", OUT)


if __name__ == "__main__":
    main()
