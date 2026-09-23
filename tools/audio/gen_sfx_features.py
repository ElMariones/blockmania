"""Sound effects for the round-play update (docs/design/round_play_update.md): tray reels and
Hands, board tools, the Emergency Brick, Feats, bosses, the Boss Crate, and the new Jokers.

Same palette and loudness rules as gen_sfx.py (it provides the helpers). Every sound is
synthesized here; no samples.

Run:  python tools/audio/gen_sfx_features.py
"""
import os
import numpy as np

from dsp import (mix, bandpass, bell, env_adsr, env_exp, epiano, highpass, lowpass, midi_hz, noise, osc,
                 pad, samples, saturate, sweep, timeline, Track, rng, kick, snare, pluck)
from gen_sfx import OUT, write, tone, click_noise, woody, plastic, whoosh, chime_chord, sparkle, coin_blip


def ratchet(dur, rate0, rate1, midi=88, seed=0):
    """A reel spinning down: clicks whose rate slides from rate0 to rate1 per second."""
    tr = Track(dur + 0.1)
    t = 0.0
    k = 0
    r = rng(seed)
    while t < dur:
        rate = rate0 + (rate1 - rate0) * (t / dur)
        tr.add(woody(midi + r.uniform(-1, 1), 0.035, 0.5 + 0.3 * r.random(), seed=seed + k), t)
        t += 1.0 / rate
        k += 1
    return tr.buf


def thud(midi=40, dur=0.35, vel=1.0):
    t = timeline(dur)
    return osc(sweep(midi_hz(midi) * 2.2, midi_hz(midi), 0.06), dur) * np.exp(-t * 14) * vel


def crunch(dur=0.3, seed=0, lo=300, hi=4000):
    """Grainy debris: many short noise grains that thin out."""
    r = rng(seed)
    out = np.zeros(samples(dur))
    for i in range(40):
        s = samples(r.uniform(0, dur * 0.8) ** 1.6 / (dur * 0.8) ** 0.6)
        g = bandpass(noise(0.018, seed * 50 + i), lo, hi, 1) * env_exp(0.018, 0.012) * r.uniform(0.2, 1.0)
        out[s:s + len(g)] += g[: len(out) - s]
    return out


def main() -> None:
    os.makedirs(OUT, exist_ok=True)

    # --- Tray reels and Hands --------------------------------------------------------------------
    write("reel_spin", ratchet(0.75, 34, 14, 90, 300), -16, room=0.06, t60=0.3)
    for i, m in enumerate((74, 78, 81)):
        x = mix(plastic(m - 12, 0.18, seed=310 + i, thud=0.9), woody(m + 12, 0.08, 0.6, seed=320 + i) * 0.5)
        write(f"reel_stop_{i + 1}", x, -10, room=0.06, t60=0.3)
    # Hands climb in brightness and length with their rank.
    write("hand_twins", mix(chime_chord([81, 86], 0.6, 0.06, 0.6), woody(93, 0.1, seed=330) * 0.3), -8, room=0.2, t60=0.8)
    tr = Track(1.1)
    for i, m in enumerate((74, 76, 78, 81)):  # a little staircase
        tr.add(pluck(m + 12, 0.5, 0.6, seed=340 + i), i * 0.07)
    tr.add(bell(93, 0.6, 0.35), 0.3)
    write("hand_stair", tr.buf, -7, room=0.2, t60=0.8)
    tr = Track(1.3)
    tr.add(chime_chord([78, 85, 90], 0.9, 0.03, 0.55), 0.0)
    tr.add(whoosh(0.5, 1200, 6000, seed=350) * 0.35, 0.0)
    tr.add(sparkle(0.5, 10, 95, 105, 351, 0.2), 0.1)
    write("hand_mono", tr.buf, -6, room=0.25, t60=1.0)
    tr = Track(1.6)
    for i, m in enumerate((74, 81, 86)):
        tr.add(epiano(m, 0.9, 0.6, seed=360 + i), i * 0.1)
        tr.add(bell(m + 12, 1.0, 0.45), i * 0.1)
    tr.add(kick(0.6), 0.3)
    tr.add(sparkle(0.7, 16, 93, 106, 361, 0.2), 0.3)
    write("hand_triplets", tr.buf, -5, room=0.25, t60=1.2)
    tr = Track(2.6)
    notes = (74, 78, 81, 86, 90, 93)
    for i, m in enumerate(notes):
        tr.add(bell(m + 12, 1.2, 0.45), i * 0.06, pan=-0.5 + i * 0.2)
        tr.add(epiano(m, 0.8, 0.5, seed=370 + i), i * 0.06)
    r = rng(371)
    for i in range(14):  # coins pouring out
        tr.add(coin_blip(88 + r.integers(0, 6), 93 + r.integers(0, 5), 0.18, r.uniform(0.3, 0.7)), 0.4 + i * 0.07)
    tr.add(pad([62, 69, 74, 78, 81], 1.6, 2400, seed=372, attack=0.15, release=0.9) * 0.4, 0.3)
    tr.add(kick(0.7), 0.36)
    write("hand_slam", tr.buf, -3, room=0.3, t60=1.6)

    # --- Targeting and board tools -------------------------------------------------------------
    write("tool_arm", mix(whoosh(0.2, 600, 3200, seed=400) * 0.5, bell(88, 0.3, 0.5)), -11, room=0.1, t60=0.5)
    write("tool_cancel", whoosh(0.18, 3200, 700, seed=401) * 0.8, -14)
    write("tool_mark", woody(90, 0.07, 0.8, seed=402), -13)
    # Eraser: rubbery squeak scrub then a soft poof.
    t = timeline(0.28)
    squeak = osc(midi_hz(86) * (1 + 0.06 * np.sin(2 * np.pi * 18 * t)), 0.28, "tri") * env_adsr(0.28, 0.02, 0.05, 0.6, 0.1)
    write("tool_erase", mix(lowpass(squeak, 3500, 2) * 0.5, crunch(0.3, 403, 1500, 7000) * 0.5), -9, room=0.08, t60=0.4)
    # Punch: a spring-loaded hammer: wind-up, hard hit, rattle.
    tr = Track(0.8)
    tr.add(whoosh(0.15, 500, 2500, seed=404) * 0.5, 0.0)
    tr.add(saturate(mix(thud(43, 0.4, 1.2), plastic(60, 0.2, seed=405, thud=1.4) * 0.6), 1.6), 0.13)
    tr.add(crunch(0.4, 406, 400, 5000) * 0.6, 0.15)
    write("tool_punch", tr.buf, -4, room=0.1, t60=0.5)
    # Color Purge: a rising magic sweep and a sparkling vacuum.
    tr = Track(1.3)
    tr.add(osc(sweep(midi_hz(62), midi_hz(98), 0.6), 0.6, "tri") * env_adsr(0.6, 0.05, 0.1, 0.6, 0.3) * 0.35, 0.0)
    tr.add(whoosh(0.7, 400, 9000, seed=407) * 0.5, 0.05)
    tr.add(sparkle(0.6, 18, 94, 107, 408, 0.22), 0.3)
    write("tool_purge", tr.buf, -6, room=0.25, t60=1.0)
    # Paint: wet splat.
    splat = bandpass(noise(0.2, 409), 300, 2500, 1) * env_exp(0.2, 0.12)
    write("tool_paint", mix(splat, woody(76, 0.12, 0.5, seed=410) * 0.4, bell(90, 0.3, 0.25)), -9, room=0.1, t60=0.4)
    # Blueprint: paper unroll and a drafting click.
    unroll = bandpass(noise(0.35, 411), 1500, 7000, 1) * env_adsr(0.35, 0.05, 0.1, 0.5, 0.15) * 0.6
    write("tool_blueprint", np.concatenate([unroll, woody(88, 0.08, seed=412), woody(93, 0.1, seed=413)]), -10, room=0.1, t60=0.4)

    # --- The Emergency Brick -------------------------------------------------------------------
    write("brick_grab", mix(plastic(52, 0.12, seed=420, thud=0.8), crunch(0.08, 421, 800, 4000) * 0.3), -11)
    write("brick_whoosh", whoosh(0.35, 400, 1800, seed=422, q=0.9), -12)
    write("brick_bounce", mix(plastic(48, 0.2, seed=423, thud=1.3), crunch(0.15, 424, 500, 3000) * 0.4), -8, room=0.06, t60=0.3)
    tr = Track(1.0)
    tr.add(saturate(mix(thud(36, 0.6, 1.3), plastic(45, 0.3, seed=425, thud=1.6)), 1.8), 0.0)
    tr.add(crunch(0.6, 426, 250, 6000) * 0.9, 0.01)
    tr.add(crunch(0.5, 427, 2000, 9000) * 0.4, 0.05)  # glassy debris ring
    write("brick_impact", tr.buf, -2, room=0.12, t60=0.6)

    # --- Feats and Jokers ----------------------------------------------------------------------
    tr = Track(1.0)
    tr.add(snare(0.5, seed=430), 0.0)
    for i, m in enumerate((81, 88, 93)):
        tr.add(bell(m, 0.6, 0.5), 0.02 + i * 0.05)
    write("feat", tr.buf, -7, room=0.2, t60=0.8)
    write("patience_tick", mix(woody(95, 0.05, 0.6, seed=431), bell(100, 0.15, 0.15)), -18)
    tr = Track(1.2)
    tr.add(coin_blip(83, 90, 0.2, 0.8), 0.0)
    for i in range(6):
        tr.add(coin_blip(86 + i, 91 + i, 0.15, 0.5), 0.1 + i * 0.05)
    tr.add(woody(62, 0.2, 1.0, seed=432), 0.0)
    write("loan_cash", tr.buf, -7, room=0.12, t60=0.6)
    # Insurance claim: a rubber stamp, paper tear, and a bright restart chord.
    tr = Track(1.8)
    tr.add(plastic(50, 0.2, seed=433, thud=1.5), 0.0)
    tr.add(bandpass(noise(0.3, 434), 1200, 6000, 1) * env_exp(0.3, 0.2) * 0.6, 0.25)
    tr.add(chime_chord([74, 78, 81, 86, 90], 1.2, 0.05, 0.5), 0.5)
    write("insurance", tr.buf, -5, room=0.25, t60=1.2)

    # --- Bosses --------------------------------------------------------------------------------
    t = timeline(0.5)
    clang = sum(np.sin(2 * np.pi * midi_hz(57) * k * t) * np.exp(-t * (6 + 5 * k)) / k for k in (1, 2.4, 3.9, 5.6))
    write("warden_lock", mix(clang * 0.7, plastic(40, 0.2, seed=440, thud=1.2) * 0.6), -6, room=0.2, t60=0.8)
    tr = Track(1.2)
    tr.add(clang * 0.4, 0.0)
    tr.add(crunch(0.3, 441, 1500, 8000) * 0.6, 0.02)
    tr.add(chime_chord([81, 86, 93], 0.7, 0.04, 0.5), 0.12)
    write("warden_unlock", tr.buf, -6, room=0.2, t60=0.8)
    tr = Track(1.2)
    tr.add(lowpass(noise(0.6, 442), 400, 2) * env_adsr(0.6, 0.3, 0.1, 0.5, 0.2) * 0.8, 0.0)  # earth rumble
    tr.add(thud(33, 0.5, 1.0), 0.45)
    tr.add(crunch(0.4, 443, 200, 2500) * 0.6, 0.45)
    write("tomb_rise", tr.buf, -6, room=0.2, t60=0.9)

    # --- Boss Crate ----------------------------------------------------------------------------
    tr = Track(1.6)
    tr.add(plastic(45, 0.15, seed=450, thud=1.0), 0.0)
    tr.add(woody(55, 0.1, seed=451), 0.12)
    tr.add(whoosh(0.4, 500, 5000, seed=452) * 0.5, 0.2)
    tr.add(chime_chord([74, 81, 86, 90, 93], 1.0, 0.04, 0.5), 0.3)
    tr.add(sparkle(0.6, 14, 93, 106, 453, 0.22), 0.35)
    write("crate_open", tr.buf, -5, room=0.25, t60=1.0)

    # --- Title easter egg: a logo letter pops apart, then its blocks rattle back together ------
    tr = Track(1.0)
    tr.add(plastic(62, 0.12, seed=460, thud=0.7), 0.0)
    tr.add(bandpass(noise(0.09, 461), 600, 6000, 1) * env_exp(0.09, 0.03) * 0.9, 0.0)  # the "pop"
    tr.add(crunch(0.45, 462, 900, 7000) * 0.55, 0.03)
    for i in range(6):  # blocks clattering away
        tr.add(woody(79 + (i * 5) % 12, 0.06, 0.35 - i * 0.04, seed=463 + i), 0.08 + i * 0.07)
    tr.add(sparkle(0.4, 6, 93, 103, 470, 0.14), 0.05)
    write("letter_pop", tr.buf, -7, room=0.15, t60=0.6)
    tr = Track(0.8)
    tr.add(whoosh(0.35, 5000, 700, seed=480) * 0.35, 0.0)
    for i in range(5):  # blocks snapping home, rising
        tr.add(woody(74 + i * 3, 0.05, 0.3 + i * 0.06, seed=481 + i), 0.12 + i * 0.045)
    write("letter_back", tr.buf, -10, room=0.12, t60=0.5)
    print("feature sfx written to", os.path.abspath(OUT))


if __name__ == "__main__":
    main()
