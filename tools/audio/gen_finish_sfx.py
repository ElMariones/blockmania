"""Generate the block-finish and stamp sounds into assets/audio/sfx/ (16-bit WAV, 44.1 kHz).

Every finish has its own placement cue (short, plays on every drop) and clear cue (plays once
per clearing placement, over the shared chime). Stamps get a trigger cue each. All sounds are
synthesized here, tuned to the D major pentatonic palette of gen_sfx.py. Deterministic.

Run:  python tools/audio/gen_finish_sfx.py
Out:  fin_<finish>_place.wav, fin_<finish>_clear.wav, stamp_<stamp>.wav
"""
import numpy as np

from dsp import (bandpass, bell, bitcrush, env_adsr, env_exp, epiano, highpass, lowpass, midi_hz, mix, noise,
                 osc, pad, samples, sweep, timeline, Track, rng)
from gen_sfx import click_noise, coin_blip, sparkle, tone, whoosh, woody, write


def partials(f, dur, ratios, decays, gains, attack=0.001):
    """Inharmonic struck-object model: sum of decaying sines."""
    t = timeline(dur)
    out = np.zeros(len(t))
    for r, d, g in zip(ratios, decays, gains):
        out += np.sin(2 * np.pi * f * r * t) * np.exp(-t * d) * g
    return out * np.minimum(1.0, t / attack)


def glassy(midi, dur=0.5, vel=1.0):
    return partials(midi_hz(midi), dur, (1, 2.32, 4.25, 6.63), (9, 14, 22, 30), (1, 0.55, 0.35, 0.2)) * vel


def metal(midi, dur=0.8, vel=1.0, bright=1.0):
    return partials(midi_hz(midi), dur, (1, 2.76, 5.4, 8.93, 13.3), (6, 9, 14, 20, 28),
                    (1, 0.6 * bright, 0.4 * bright, 0.25 * bright, 0.12 * bright)) * vel


def thud(midi=45, dur=0.12, vel=1.0):
    t = timeline(dur)
    return osc(sweep(midi_hz(midi) * 1.8, midi_hz(midi), 0.04), dur) * np.exp(-t * 30) * vel


def buzz(f, dur, vel=1.0):
    t = timeline(dur)
    saw = osc(f, dur, "saw") + 0.5 * osc(f * 2.005, dur, "saw")
    return bandpass(saw, 300, 3200, 2) * env_adsr(dur, 0.004, 0.05, 0.6, dur * 0.4) * vel


def mono(x):
    return x.mean(axis=1) if x.ndim == 2 else x


# ------------------------------------------------------------------ finishes

def glass():
    place = mix(glassy(93, 0.35, 0.8), glassy(100, 0.25, 0.35), thud(57, 0.08, 0.4))
    tr = Track(1.3)
    tr.add(highpass(noise(0.4, 301), 2500, 2) * env_exp(0.4, 0.22) * 0.8, 0.0)
    for i, m in enumerate((105, 100, 98, 93, 90, 86)):
        tr.add(glassy(m, 0.5, 0.55 - i * 0.05), 0.03 + i * 0.045, pan=(-1) ** i * 0.4)
    return place, tr.buf


def crystal():
    place = mix(bell(98, 0.5, 0.6), bell(105, 0.35, 0.25), click_noise(0.004, 4000, 9000, 311) * 0.3)
    tr = Track(1.5)
    for i, m in enumerate((86, 90, 93, 98, 102, 105)):
        tr.add(bell(m, 0.9, 0.5), i * 0.05, pan=(i / 5 - 0.5) * 0.8)
    tr.add(sparkle(0.6, 12, 98, 108, 312, 0.22), 0.2)
    return place, tr.buf


def neon():
    place = mix(buzz(120, 0.14, 0.7), tone(93, 0.12, "tri", 0.1) * 0.35, click_noise(0.006, 3000, 8000, 321) * 0.4)
    t = timeline(0.7)
    zap = osc(sweep(2400, 120, 0.35, "exp"), 0.7, "saw") * np.exp(-t * 7)
    crackle = bandpass(noise(0.7, 322), 1500, 7000, 2) * (rng(323).random(len(t)) > 0.93) * np.exp(-t * 5)
    hum = buzz(60, 0.7, 0.5) * np.exp(-t * 3)
    clear = mix(lowpass(zap, 5000, 2) * 0.8, crackle * 1.2, hum * 0.6, tone(98, 0.4, "tri", 0.3) * 0.2)
    return place, clear


def gold():
    place = mix(metal(88, 0.45, 0.6, 0.8), thud(52, 0.12, 0.5))
    tr = Track(1.3)
    tr.add(metal(81, 0.9, 0.5), 0.0)
    r = rng(331)
    for i in range(7):
        tr.add(coin_blip(90 + (i % 3) * 2, 95 + (i % 3) * 2, 0.14, r.uniform(0.35, 0.7)), 0.08 + i * 0.055, pan=r.uniform(-0.6, 0.6))
    tr.add(bell(98, 0.8, 0.4), 0.45)
    return place, tr.buf


def marble():
    t = timeline(0.2)
    knock = lowpass(noise(0.2, 341), 2200, 2) * np.exp(-t * 55)
    place = mix(knock * 1.2, thud(43, 0.18, 0.9), partials(midi_hz(69), 0.2, (1, 2.6), (40, 70), (0.3, 0.15)))
    tr = Track(1.1)
    rumble = lowpass(noise(0.8, 342), 500, 2) * env_adsr(0.8, 0.02, 0.2, 0.5, 0.5)
    tr.add(rumble * 1.4, 0.0)
    r = rng(343)
    for i in range(9):
        tr.add(lowpass(noise(0.05, 344 + i), 3000, 2) * np.exp(-timeline(0.05) * 60) * r.uniform(0.3, 0.8), r.uniform(0, 0.45), pan=r.uniform(-0.5, 0.5))
    tr.add(thud(38, 0.4, 1.0), 0.0)
    return place, tr.buf


def cyberpunk():
    a = tone(93, 0.04, "square", 0.05) * 0.4
    b = tone(100, 0.07, "square", 0.08) * 0.35
    place = bitcrush(lowpass(np.concatenate([a, b]), 6000, 1), 6)
    tr = Track(0.9)
    notes = (86, 93, 90, 98, 95, 102, 100, 105)
    for i, m in enumerate(notes):
        tr.add(bitcrush(tone(m, 0.05, "square", 0.05) * 0.35, 5), i * 0.042, pan=(-1) ** i * 0.3)
    stutter = bandpass(noise(0.3, 351), 1000, 6000, 2) * (np.sin(2 * np.pi * 30 * timeline(0.3)) > 0) * env_exp(0.3, 0.25)
    tr.add(bitcrush(stutter, 4) * 0.5, 0.18)
    return place, tr.buf


def wood():
    place = mix(woody(74, 0.16, seed=361), woody(62, 0.12, 0.5, seed=362))
    tr = Track(1.0)
    for i, m in enumerate((74, 76, 78, 81, 83, 86, 88)):
        tr.add(woody(m, 0.2, 0.9, seed=363 + i), i * 0.05, pan=(i / 6 - 0.5) * 0.6)
    tr.add(woody(93, 0.3, 1.0, seed=371), 0.37)
    return place, tr.buf


def candy():
    t = timeline(0.16)
    bloop = osc(sweep(midi_hz(74), midi_hz(86), 0.12), 0.16) * np.exp(-t * 18) * np.minimum(1, t / 0.01)
    place = mix(bloop * 0.9, click_noise(0.005, 1500, 5000, 381) * 0.3)
    tr = Track(1.0)
    r = rng(382)
    for i in range(6):
        m = 81 + i * 2.4
        tt = timeline(0.12)
        pop = osc(sweep(midi_hz(m - 5), midi_hz(m + 7), 0.08), 0.12) * np.exp(-tt * 25)
        tr.add(pop * 0.7, i * 0.05 + r.uniform(0, 0.02), pan=r.uniform(-0.6, 0.6))
    tt = timeline(0.5)
    boing = osc(midi_hz(86) * (1 + 0.06 * np.sin(2 * np.pi * 12 * tt) * np.exp(-tt * 5)), 0.5) * np.exp(-tt * 7)
    tr.add(boing * 0.6, 0.3)
    tr.add(sparkle(0.3, 6, 98, 106, 383, 0.2), 0.3)
    return place, tr.buf


def lava():
    t = timeline(0.3)
    sizzle = highpass(noise(0.3, 391), 3000, 2) * env_exp(0.3, 0.2) * (0.6 + 0.4 * np.sin(2 * np.pi * 40 * t))
    place = mix(sizzle * 0.5, thud(40, 0.2, 1.0))
    tr = Track(1.4)
    tr.add(lowpass(noise(1.2, 392), 260, 2) * env_adsr(1.2, 0.05, 0.3, 0.6, 0.7) * 2.0, 0.0)
    r = rng(393)
    for i in range(6):
        tb = timeline(0.1)
        blorp = osc(sweep(midi_hz(50 + r.uniform(0, 8)), midi_hz(62 + r.uniform(0, 8)), 0.08), 0.1) * np.exp(-tb * 30)
        tr.add(blorp * 0.5, 0.1 + i * 0.12 + r.uniform(0, 0.05), pan=r.uniform(-0.5, 0.5))
    tr.add(highpass(noise(0.9, 394), 2500, 2) * env_exp(0.9, 0.6) * 0.35, 0.05)
    return place, tr.buf


def ice():
    t = timeline(0.12)
    crunch = bandpass(noise(0.12, 401), 2000, 8000, 2) * np.exp(-t * 35)
    place = mix(glassy(98, 0.25, 0.5), crunch * 0.6)
    tr = Track(1.4)
    tc = timeline(0.35)
    crack = bandpass(noise(0.35, 402), 1200, 9000, 2) * (rng(403).random(len(tc)) > 0.85) * np.exp(-tc * 9)
    tr.add(crack * 1.2, 0.0)
    r = rng(404)
    for i in range(10):
        tr.add(glassy(98 + r.integers(0, 10), 0.4, r.uniform(0.2, 0.45)), 0.08 + r.uniform(0, 0.6), pan=r.uniform(-0.8, 0.8))
    return place, tr.buf


def chrome():
    place = mix(metal(93, 0.4, 0.55, 1.2), click_noise(0.004, 4000, 10000, 411) * 0.5)
    tr = Track(1.3)
    tr.add(whoosh(0.35, 1500, 9000, seed=412, q=0.5) * 0.9, 0.0)
    tr.add(metal(98, 1.0, 0.5, 1.3), 0.2)
    tr.add(metal(105, 0.8, 0.3, 1.0), 0.24, pan=0.3)
    return place, tr.buf


def prism():
    place = mix(bell(93, 0.35, 0.45), bell(93.12, 0.35, 0.3), bell(100, 0.3, 0.2))
    tr = Track(1.5)
    for i, m in enumerate((86, 90, 93, 97, 98, 102, 105)):
        tr.add(mix(bell(m, 0.7, 0.4), bell(m + 0.1, 0.7, 0.25)), i * 0.045, pan=(i / 6 - 0.5))
    tr.add(sparkle(0.5, 10, 100, 110, 421, 0.18), 0.25)
    return place, tr.buf


def aurora():
    place = mix(bell(90, 0.5, 0.35), bell(97, 0.4, 0.2), whoosh(0.25, 2500, 6000, seed=431) * 0.15)
    tr = Track(2.0)
    tr.add(pad([74, 78, 81, 85, 90], 1.6, bright=2600, seed=432, attack=0.35) * 0.6, 0.0)
    for i, m in enumerate((93, 97, 102)):
        tr.add(bell(m, 1.0, 0.3), 0.2 + i * 0.18, pan=(i - 1) * 0.5)
    return place, tr.buf


def starfall():
    place = mix(bell(100, 0.3, 0.4), bell(105, 0.25, 0.3)[: samples(0.25)], click_noise(0.003, 5000, 10000, 441) * 0.2)
    tr = Track(1.6)
    for i, m in enumerate((108, 105, 102, 100, 98, 95, 93, 90)):
        tr.add(bell(m, 0.6, 0.35 + i * 0.03), i * 0.04, pan=0.7 - i * 0.2)
    tr.add(whoosh(0.5, 6000, 1500, seed=442, q=0.6) * 0.4, 0.0)
    tr.add(sparkle(0.6, 10, 100, 110, 443, 0.2), 0.35)
    return place, tr.buf


FINISHES = {
    "glass": glass, "crystal": crystal, "neon": neon, "gold": gold, "marble": marble,
    "cyberpunk": cyberpunk, "wood": wood, "candy": candy, "lava": lava, "ice": ice,
    "chrome": chrome, "prism": prism, "aurora": aurora, "starfall": starfall,
}


# ------------------------------------------------------------------ stamps

def stamps():
    # Encore: a bright two-note "ta-da" with a sparkle tail.
    tr = Track(1.0)
    tr.add(mix(epiano(86, 0.1, 0.8), tone(98, 0.1, "tri", 0.1) * 0.3), 0.0)
    tr.add(mix(epiano(93, 0.4, 0.9), epiano(97, 0.4, 0.5), tone(105, 0.3, "tri", 0.3) * 0.2), 0.1)
    tr.add(sparkle(0.3, 6, 100, 108, 501, 0.2), 0.15)
    yield "stamp_encore", tr.buf, -8
    # Refund: a rewind whirr and a returning blip.
    t = timeline(0.28)
    whirr = osc(sweep(900, 300, 0.28), 0.28, "tri") * (0.6 + 0.4 * np.sin(2 * np.pi * 34 * t)) * env_adsr(0.28, 0.01, 0.1, 0.7, 0.1)
    yield "stamp_refund", np.concatenate([whirr * 0.5, woody(86, 0.12, seed=502)]), -10
    # Tip: a coin flip landing in a jar.
    tr = Track(0.7)
    tr.add(coin_blip(93, 98, 0.18, 0.8), 0.0)
    tr.add(metal(95, 0.35, 0.3, 1.0), 0.16)
    tr.add(coin_blip(90, 95, 0.2, 0.5), 0.22)
    yield "stamp_tip", tr.buf, -9
    # Memory: an electric spark that settles into a soft chime.
    tt = timeline(0.2)
    spark = bandpass(noise(0.2, 503), 2500, 9000, 2) * (rng(504).random(len(tt)) > 0.8) * np.exp(-tt * 14)
    yield "stamp_memory", mix(spark * 0.9, bell(98, 0.6, 0.45), bell(93, 0.5, 0.25)), -9


def main():
    for fid, fn in FINISHES.items():
        place, clear = fn()
        write("fin_%s_place" % fid, mono(place), -11, room=0.06, t60=0.3)
        write("fin_%s_clear" % fid, clear, -9, room=0.18, t60=0.9)
    for name, x, peak in stamps():
        write(name, mono(x) if name != "stamp_encore" else x, peak, room=0.1, t60=0.5)
    print("wrote %d finish cues and 4 stamp cues" % (len(FINISHES) * 2))


if __name__ == "__main__":
    main()
