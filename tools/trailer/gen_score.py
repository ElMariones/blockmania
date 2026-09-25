"""BLOCKMANIA trailer score: "toy chip-house", 120 BPM, B minor, synthesized from first principles.

The game's own sound effects (assets/audio/sfx, mostly in D major) are laid on the picture cues
exported by `node render.mjs cues` (build/cues.json), so every hit on screen has a sound. B minor
is the relative minor of the effects' D major, so they sit in key. The climax modulates up a
whole step and the effects are pitched with it.

Run:  python gen_score.py            -> build/score.wav (44.1 kHz stereo, 24-bit)
Needs NumPy, SciPy, SoundFile. Uses tools/audio/dsp.py for filters and reverb.
"""
import json
import os
import sys

import numpy as np
import soundfile as sf

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "audio"))
import dsp  # noqa: E402
from dsp import SR, lowpass, highpass, bandpass, saturate, reverb, midi_hz  # noqa: E402

BPM = 120
BEAT = 60.0 / BPM
BAR = 4 * BEAT
DUR = 72.0
N = int(DUR * SR) + SR * 2
SFX_DIR = os.path.join(ROOT, "assets", "audio", "sfx")
KEYUP_FROM, KEYUP_TO = 56.0, 63.0  # climax modulation (+2 semitones)


def S(t):
    return int(round(t * SR))


def tl(dur):
    return np.arange(max(1, S(dur))) / SR


# --------------------------------------------------------------------------- voices
def saw(freq, dur, phase=0.0):
    t = tl(dur)
    f = np.full(len(t), freq) if np.isscalar(freq) else np.asarray(freq)[: len(t)]
    ph = np.cumsum(f) / SR + phase
    return 2.0 * (ph % 1.0) - 1.0


def square(freq, dur, pw=0.5, phase=0.0):
    t = tl(dur)
    f = np.full(len(t), freq) if np.isscalar(freq) else np.asarray(freq)[: len(t)]
    ph = (np.cumsum(f) / SR + phase) % 1.0
    return np.where(ph < pw, 1.0, -1.0)


def adsr(dur, a, d, s, r):
    return dsp.env_adsr(dur, a, d, s, r)


def kick(vel=1.0):
    dur = 0.42
    t = tl(dur)
    f = 50 + 140 * np.exp(-t * 32)
    ph = 2 * np.pi * np.cumsum(f) / SR
    body = np.sin(ph) * np.exp(-t * 7.5)
    click = highpass(np.random.default_rng(3).standard_normal(len(t)), 2000, 1) * np.exp(-t * 300) * 0.25
    return saturate((body + click) * vel * 1.3, 1.8) * 0.85


def clap(vel=0.8, seed=5):
    dur = 0.3
    t = tl(dur)
    nz = np.random.default_rng(seed).standard_normal(len(t))
    nz = bandpass(nz, 900, 5000, 2)
    env = np.zeros(len(t))
    for k, off in enumerate((0.0, 0.011, 0.022)):
        env += np.exp(-np.maximum(0, t - off) * 180) * (t >= off) * (0.8 if k < 2 else 1.0)
    env += np.exp(-np.maximum(0, t - 0.03) * 22) * (t >= 0.03) * 0.5
    return nz * env * vel * 0.9


def hat(vel=0.4, open_=False, seed=2):
    return dsp.hat(vel, open_, seed)


def snare(vel=0.8, seed=1):
    return dsp.snare(vel, seed) * 1.1


def bass(midi, dur, vel=0.9, cutoff=900):
    f = midi_hz(midi)
    x = saw(f, dur) * 0.7 + np.sin(2 * np.pi * f * tl(dur)) * 0.55
    x = dsp.sweep_lowpass(x, cutoff * 2.2, cutoff * 0.6, 16)
    env = adsr(dur, 0.004, 0.08, 0.7, 0.04)
    return saturate(x * env * vel, 1.4) * 0.8


def supersaw(midis, dur, cutoff=3200, vel=0.6, seed=0, release=0.08, stereo=True):
    r = np.random.default_rng(seed)
    L = np.zeros(S(dur)); R = np.zeros(S(dur))
    for m in midis:
        f = midi_hz(m)
        for k, c in enumerate((-14, -7, 0, 7, 14)):
            w = saw(f * 2 ** (c / 1200), dur, r.uniform())
            if k % 2 == 0:
                L += w * (1.0 if c else 0.7)
            if k % 2 == 1 or c == 0:
                R += w * (1.0 if c else 0.7)
    st = np.stack([L, R], 1) / (len(midis) * 3.0)
    st = lowpass(st, cutoff, 2)
    env = adsr(dur, 0.003, dur * 0.4, 0.35, release)
    out = st * env[:, None] * vel
    return out if stereo else out.mean(1)


def pad(midis, dur, bright=1600, attack=0.6, release=1.2, seed=0):
    return dsp.pad(midis, dur, bright, seed, attack, release)


def lead(midi, dur, vel=0.7, bright=5000):
    f = midi_hz(midi)
    t = tl(dur + 0.08)
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.12) * 5, 0, 1)
    ff = f * vib
    x = square(ff, dur + 0.08, 0.5) * 0.5 + square(ff * 1.003, dur + 0.08, 0.3) * 0.4 + saw(ff * 0.5, dur + 0.08) * 0.2
    x = lowpass(x, bright, 2)
    env = adsr(dur + 0.08, 0.004, 0.1, 0.75, 0.07)
    return x * env * vel * 0.5


def bell(midi, dur=1.2, vel=0.5):
    return dsp.bell(midi, dur, vel)


def chip(midi, dur=0.12, vel=0.4):
    f = midi_hz(midi)
    x = square(f, dur, 0.25)
    env = np.exp(-tl(dur) * 22)
    return dsp.bitcrush(lowpass(x * env * vel, 6000, 1), 6) * 0.6


VOW = {"a": (850, 1350, 2600), "o": (560, 950, 2500), "i": (330, 2400, 3100), "e": (520, 1900, 2600), "u": (380, 800, 2400)}


def chant(vowel, midi, dur, vel=0.8, cons=True, seed=0):
    """Formant voice: a buzzy glottal saw through three vowel formants, doubled an octave down."""
    t = tl(dur + 0.15)
    f = midi_hz(midi) * (1 + 0.012 * np.sin(2 * np.pi * 5.8 * t) * np.clip((t - 0.1) * 4, 0, 1))
    f = f * (1 + 0.04 * np.exp(-t * 30))
    src = saw(f, len(t) / SR) + 0.5 * saw(f * 0.5, len(t) / SR)
    f1, f2, f3 = VOW[vowel]
    x = bandpass(src, f1 * 0.85, f1 * 1.2, 2) + 0.7 * bandpass(src, f2 * 0.88, f2 * 1.12, 2) + 0.35 * bandpass(src, f3 * 0.9, f3 * 1.1, 2)
    x += lowpass(src, 400, 2) * 0.3
    env = adsr(len(t) / SR, 0.012, 0.1, 0.8, 0.12)
    x = x * env
    if cons:  # a plosive / nasal onset so syllables read as words
        nz = np.random.default_rng(seed).standard_normal(S(0.03))
        x[: len(nz)] += bandpass(nz, 1500, 6000, 1) * np.exp(-np.arange(len(nz)) / SR * 120) * 0.6
    return saturate(x * vel * 2.0, 1.5) * 0.6


def riser(dur, vel=0.5, seed=7):
    t = tl(dur)
    nz = np.random.default_rng(seed).standard_normal(len(t))
    k = t / dur
    out = np.zeros(len(t))
    blocks = 48
    edges = np.linspace(0, len(t), blocks + 1).astype(int)
    for i in range(blocks):
        a, b = edges[i], edges[i + 1]
        fc = 300 * (8000 / 300) ** (i / blocks)
        seg = bandpass(nz[max(0, a - 2000): b], fc * 0.7, min(fc * 1.4, 20000), 2)[-(b - a):]
        out[a:b] = seg
    pitch = saw(110 * 2 ** (k * 3), dur) * 0.15
    return (out + lowpass(pitch, 4000, 1)) * (k ** 2) * vel


def impact(vel=1.0, seed=9, tail=1.6):
    t = tl(tail)
    sub = np.sin(2 * np.pi * np.cumsum(28 + 60 * np.exp(-t * 8)) / SR) * np.exp(-t * 2.8)
    nz = lowpass(np.random.default_rng(seed).standard_normal(len(t)), 2500, 2) * np.exp(-t * 9)
    x = saturate((sub * 1.2 + nz * 0.5) * vel, 1.6)
    return reverb(x, mix=0.3, t60=2.4)


def downlifter(dur=0.6, vel=0.5, seed=11):
    t = tl(dur)
    nz = np.random.default_rng(seed).standard_normal(len(t))
    x = dsp.sweep_lowpass(nz, 9000, 300, 24) * np.exp(-t * 3)
    return x * vel


def siren(dur, vel=0.3):
    t = tl(dur)
    f = np.where((t * 2) % 1 < 0.5, midi_hz(71), midi_hz(72))
    x = saw(f, dur) * 0.5 + saw(f * 1.005, dur) * 0.5
    return lowpass(x, 2500, 2) * vel * adsr(dur, 0.2, 0.1, 1.0, 0.4)


# --------------------------------------------------------------------------- mixing
class Bus:
    def __init__(self):
        self.x = np.zeros((N, 2))

    def add(self, clip, at, gain=1.0, pan=0.0):
        if clip.ndim == 1:
            clip = dsp.to_stereo(clip, pan)
        s = S(at)
        if s < 0:
            clip = clip[-s:]; s = 0
        e = min(N, s + len(clip))
        if e > s:
            self.x[s:e] += clip[: e - s] * gain


def db(v):
    return 10 ** (v / 20)


# --------------------------------------------------------------------------- harmony
# B minor: Bm G D A. Voicings kept near each other; stab an octave up.
CHORDS = {
    "Bm": ([54, 59, 62], 35), "G": ([55, 59, 62], 31), "D": ([54, 57, 62], 38), "A": ([52, 57, 61], 33),
    "C": ([55, 60, 64], 36), "F#": ([54, 58, 61], 30), "Em": ([55, 59, 64], 40),
}
PROG = ["Bm", "G", "D", "A"]
BOSS = ["Bm", "C", "Bm", "F#"]
HOOK = [  # (beat, midi, beats) over 16 beats, B minor
    (0, 71, .5), (.75, 69, .25), (1, 66, .5), (1.5, 69, .5), (2, 71, .75), (3, 74, .5), (3.5, 73, .5),
    (4, 71, .5), (4.75, 69, .25), (5, 66, .5), (5.5, 64, .5), (6, 62, 1.0), (7.5, 64, .5),
    (8, 66, .5), (8.75, 66, .25), (9, 69, .5), (9.5, 66, .5), (10, 74, .75), (11, 73, .5), (11.5, 71, .5),
    (12, 69, .5), (12.5, 71, .5), (13, 73, 1.0), (14.5, 69, .5), (15, 73, .5), (15.5, 76, .5),
]

# Section flags per bar (36 bars of 2 s)
def section(bar):
    if bar < 4: return "hook"
    if bar < 6: return "logo"
    if bar < 10: return "how"
    if bar < 12: return "receipt"
    if bar < 16: return "jokers"
    if bar < 18: return "shop"
    if bar < 20: return "finish"
    if bar < 24: return "boss"
    if bar < 28: return "drop"
    if bar < 32: return "drop2"
    return "end"


def build():
    drums, bassb, stabs, padb, leadb, arpb, voxb, fxb, sfxb = (Bus() for _ in range(9))
    kicks = []

    for bar in range(36):
        sec = section(bar)
        t0 = bar * BAR
        tr = 2 if sec == "drop2" else 0
        ch = (BOSS if sec == "boss" else PROG)[bar % 4]
        notes, root = CHORDS[ch]
        notes = [n + tr for n in notes]; root += tr

        # ---- drums
        if sec in ("hook", "how", "receipt", "jokers", "shop", "finish", "drop", "drop2") or (sec == "logo" and bar == 5):
            for b in range(4):
                tk = t0 + b * BEAT
                if sec == "hook" and bar == 3 and b >= 3:
                    continue  # the machine breaks on beat 4 of bar 3
                drums.add(kick(1.0 if b == 0 else 0.92), tk, db(-3)); kicks.append(tk)
            for b in range(8):
                th = t0 + b * BEAT / 2
                if sec == "hook" and bar == 3 and th >= 7.5:
                    continue
                if b % 2 == 1:
                    drums.add(hat(0.55, True, seed=b), th, db(-15), pan=0.2)
                elif sec in ("hook", "jokers", "drop", "drop2", "receipt", "finish"):
                    drums.add(hat(0.35, False, seed=b + 9), th, db(-17), pan=-0.2)
            if sec in ("hook", "jokers", "drop", "drop2", "receipt", "shop"):
                for b in (1, 3):
                    tc = t0 + b * BEAT
                    if sec == "hook" and bar == 3 and b == 3:
                        continue
                    drums.add(clap(0.9, seed=bar * 4 + b), tc, db(-7))
            if sec in ("drop", "drop2"):  # 16th shaker drive
                for b in range(16):
                    drums.add(dsp.shaker(0.35 + 0.25 * (b % 4 == 2), seed=b), t0 + b * BEAT / 4, db(-18), pan=0.35)
        if sec == "logo" and bar == 4:
            drums.add(kick(1.0), t0, db(-2)); kicks.append(t0)
            for b in range(8):
                drums.add(hat(0.3, False, seed=b), t0 + 1.0 + b * 0.125, db(-20))
        if sec == "boss":
            # half time: kick 1 and the "and" of 3, big snare on 3
            for off in (0.0, 1.25):
                drums.add(kick(1.0), t0 + off, db(-2)); kicks.append(t0 + off)
            drums.add(snare(1.0, seed=bar), t0 + 1.0, db(-5))
            drums.add(reverb(clap(1.0, seed=bar), mix=0.35, t60=1.6), t0 + 1.0, db(-9))
            for b in range(8):
                drums.add(hat(0.3, False, seed=b), t0 + b * 0.25, db(-21), pan=0.3)
        # snare rolls into the big moments
        if bar in (3, 19, 27):
            start = 0.0 if bar == 19 else (1.0 if bar == 27 else 0.0)
            end_t = 3.5 if bar == 3 else 4.0
            n = 0
            b = start
            while b < end_t:
                step = 0.5 if b < 2 else 0.25 if b < 3 else 0.125
                if bar == 3 and b >= 3.0:
                    break
                drums.add(snare(0.35 + 0.6 * (b / 4), seed=n), t0 + b * BEAT, db(-12 + 6 * b / 4)); n += 1
                b += step

        # ---- bass
        if sec in ("hook", "how", "receipt", "jokers", "shop", "finish", "drop", "drop2") or (sec == "logo" and bar == 5):
            patt = [(0, 0), (0.5, 12), (1, 0), (1.5, 12), (2, 0), (2.5, 12), (3, 0), (3.5, 7)]
            if sec in ("how", "shop"):
                patt = [(0, 0), (0.75, 0), (1.5, 12), (2, 0), (2.75, 0), (3.5, 7)]
            for b, iv in patt:
                tb = t0 + b * BEAT
                if sec == "hook" and bar == 3 and b >= 3:
                    continue
                bassb.add(bass(root + 12 + iv, 0.22), tb, db(-6))
        if sec == "boss":
            drone = bass(root + 12, BAR - 0.02, 1.0, cutoff=500)
            bassb.add(highpass(saturate(drone * 1.5, 2.5), 70, 2), t0, db(-13))
        if sec == "logo" and bar == 4:
            bassb.add(bass(root + 12, 1.9, 1.0, 400), t0, db(-5))

        # ---- chords
        if sec in ("hook", "jokers", "drop", "drop2", "receipt", "how", "shop"):
            offs = [0.5, 1.5, 2.5, 3.5]
            if sec in ("drop", "drop2", "hook"):
                offs = [0.5, 1.25, 1.5, 2.5, 3.25, 3.5]
            for b in offs:
                tb = t0 + b * BEAT
                if sec == "hook" and bar == 3 and b >= 3:
                    continue
                v = 0.45 if sec in ("how", "shop") else 0.7
                stabs.add(supersaw([n + 12 for n in notes], 0.2, 3800 if sec != "how" else 2400, v, seed=bar * 8 + int(b * 4)), tb, db(-9))
        if sec == "finish":  # a stab on every beat, brighter each time (finish swaps)
            for b in range(4):
                k = (bar - 18) * 4 + b
                stabs.add(supersaw([n + 12 for n in notes], 0.3, 1500 + k * 450, 0.8, seed=k), t0 + b * BEAT, db(-8))
        if sec in ("logo", "end", "boss", "how", "drop", "drop2"):
            pv = {"logo": -10, "end": -9, "boss": -12, "how": -17, "drop": -16, "drop2": -15}[sec]
            padb.add(pad(notes + [root + 24], BAR + 0.1, 1800 if sec != "boss" else 1100, attack=0.3 if sec != "end" else 1.0, release=1.0, seed=bar), t0, db(pv))

        # ---- lead hook (4-bar phrase)
        if sec in ("hook", "jokers", "drop", "drop2"):
            ph = bar % 4
            for (b, m, d) in HOOK:
                if ph * 4 <= b < ph * 4 + 4:
                    tb = t0 + (b - ph * 4) * BEAT
                    if sec == "hook" and bar == 3 and b - ph * 4 >= 3:
                        continue
                    oct_ = 12 if sec == "drop2" else 0
                    leadb.add(lead(m + tr + oct_, d * BEAT, 0.75), tb, db(-8))
                    if sec in ("drop", "drop2"):
                        leadb.add(lead(m + tr + oct_ - 12, d * BEAT, 0.5, 2500), tb, db(-14))
        if sec == "shop":  # the hook on a music box
            ph = bar % 4
            for (b, m, d) in HOOK:
                if ph * 4 <= b < ph * 4 + 4:
                    leadb.add(bell(m + 12, 0.8, 0.6), t0 + (b - ph * 4) * BEAT, db(-6))
        if sec == "end" and bar >= 33:
            ph = (bar - 33) % 4
            for (b, m, d) in HOOK[:13]:
                if ph * 4 <= b < ph * 4 + 4:
                    leadb.add(bell(m + 12, 1.4, 0.45), t0 + (b - ph * 4) * BEAT, db(-9))

        # ---- arps
        if sec in ("receipt", "drop", "drop2", "finish"):
            seq = [notes[0] + 12, notes[1] + 12, notes[2] + 12, notes[1] + 24]
            for b in range(16):
                arpb.add(chip(seq[b % 4], 0.11, 0.5), t0 + b * BEAT / 4, db(-17), pan=(-0.4 if b % 2 else 0.4))
        if sec == "how":
            seq = [notes[0] + 12, notes[2] + 12, notes[1] + 24, notes[2] + 12]
            for b in range(8):
                arpb.add(bell(seq[b % 4] + 12, 0.5, 0.3), t0 + b * BEAT / 2, db(-17), pan=(-0.3 if b % 2 else 0.3))

    # ---- one-off moments
    # machine break in the hook: bitcrushed descending blips, silence, then the impact at 8.0
    for i in range(6):
        fxb.add(chip(83 - i * 3, 0.07, 0.6), 7.5 + i * 0.06, db(-12))
    fxb.add(riser(1.5, 0.6), 6.0, db(-12))
    fxb.add(impact(1.0), 8.0, db(-4))
    # logo chant BLOCK-MA-NI-A (B A F# B), echoed at the drop and the end card
    CH = [("o", 71, 0.4), ("a", 69, 0.4), ("i", 66, 0.4), ("a", 71, 0.9)]
    for when, g, tr in ((8.0, -6, 0), (48.0, -9, 0), (66.0, -11, 0)):
        for i, (v, m, d) in enumerate(CH):
            c = chant(v, m + tr, d, 0.9, seed=i)
            voxb.add(reverb(c, mix=0.25, t60=1.8), when + i * BEAT, db(g))
            voxb.add(chant(v, m + tr + 12, d, 0.5, seed=i + 4), when + i * BEAT, db(g - 9), pan=0.3)
    # boss: siren and the big hits, riser into the drop, silence before it
    fxb.add(siren(8.0, 0.35), 40.0, db(-17))
    for t in (40.0, 42.0, 44.0):
        fxb.add(impact(0.8, seed=int(t)), t, db(-8))
        padb.add(supersaw([n for n in CHORDS["Bm"][0]] + [47], 0.8, 1200, 1.0, release=0.4), t, db(-7))
    for i in range(12):  # rising pips with the run track
        fxb.add(chip(59 + [0, 2, 3, 5, 7, 8, 10, 12, 14, 15, 17, 19][i], 0.1, 0.6), 46.0 + i * 0.125, db(-10))
    fxb.add(riser(1.75, 0.7), 46.0, db(-10))
    fxb.add(impact(1.2), 48.0, db(-3))
    # finishes build riser
    fxb.add(riser(4.0, 0.5, seed=3), 36.0, db(-16))
    # feature bars clear, milestones
    fxb.add(riser(2.0, 0.5, seed=5), 53.5, db(-15))
    for t in (56.0, 58.0, 60.0, 62.0):
        fxb.add(impact(1.0, seed=int(t)), t, db(-5))
    fxb.add(riser(1.0, 0.6, seed=8), 62.0, db(-12))
    fxb.add(impact(1.3, seed=99, tail=2.5), 66.0, db(-6))
    fxb.add(downlifter(0.8, 0.5), 11.75, db(-14))

    # ---- sidechain (kick ducks the music)
    g = np.ones(N)
    tt = np.arange(N) / SR
    for tk in kicks:
        s = S(tk)
        e = min(N, s + S(0.3))
        d = np.arange(e - s) / SR
        g[s:e] = np.minimum(g[s:e], 1 - 0.55 * np.exp(-d / 0.09) * np.clip(d / 0.004, 0, 1) - 0.0)
    for b in (bassb, stabs, padb, arpb):
        b.x *= g[:, None]
    leadb.x *= (0.5 + 0.5 * g)[:, None]

    # ---- bus processing
    leadb.x = reverb(leadb.x, mix=0.18, t60=1.4)[:N]
    stabs.x = reverb(stabs.x, mix=0.15, t60=1.2)[:N]
    arpb.x = reverb(arpb.x, mix=0.2, t60=1.0)[:N]
    # dotted-eighth echo on the lead
    dly = S(BEAT * 0.75)
    echo = np.zeros_like(leadb.x); echo[dly:] = leadb.x[:-dly] * 0.28
    echo[:, 0], echo[:, 1] = echo[:, 1].copy(), echo[:, 0].copy()
    leadb.x += lowpass(echo, 3000, 1)

    padb.x = highpass(padb.x, 140, 2)
    stabs.x = highpass(stabs.x, 180, 2)
    buses = {"drums": drums, "bass": bassb, "stabs": stabs, "pad": padb, "lead": leadb, "arp": arpb, "vox": voxb, "fx": fxb}
    SEC = [(0, 8, "hook"), (12, 20, "how"), (24, 32, "jokers"), (40, 48, "boss"), (48, 56, "drop"), (56, 63, "miles")]
    print("stem RMS dB per section: " + "  ".join(f"{n:>6s}" for _, _, n in SEC))
    for name, b in buses.items():
        kx = dsp.peaking(highpass(b.x, 60, 2), 3000, 4, 0.7)  # rough K-weighting
        row = [dsp.rms_db(kx[S(a):S(e)]) for a, e, _ in SEC]
        print(f"  {name:6s} " + "  ".join(f"{v:6.1f}" for v in row))
    music = drums.x * db(-2) + bassb.x * db(3) + stabs.x * db(9) + padb.x * db(5) + leadb.x * db(4) + arpb.x * db(9) + voxb.x + fxb.x
    # section dynamics: (time, gain dB) breakpoints, linear in dB
    AUTO = [(0, 0), (8, 0), (11.9, 0), (12.0, -5), (19.9, -5), (20.0, -4), (23.9, -3.5), (24.0, -1.5), (31.9, -1.5),
            (32.0, -4.5), (35.9, -4.5), (36.0, -4), (39.9, -1), (40.0, -3.5), (47.9, -3), (48.0, 1.0), (55.9, 1.0),
            (56.0, 1.5), (72, 1.5)]
    ta, ga = zip(*AUTO)
    gain = db(np.interp(np.arange(N) / SR, ta, ga))
    music *= gain[:, None]

    # machine break at 7.5: music cut (only fx/sfx remain) until 8.0
    music[S(7.5):S(8.0)] *= 0.0
    # tape stop at 63.0 -> 63.55, then silence until 64.6
    a, T = S(63.0), 0.55
    n = S(T)
    tau = np.arange(n) / SR
    pos = a + (tau - tau ** 2 / (2 * T)) * SR
    seg = np.stack([np.interp(pos, np.arange(N), music[:, c]) for c in range(2)], 1)
    seg *= np.linspace(1, 0.3, n)[:, None]
    music[a:a + n] = dsp.bitcrush(seg, 8)
    music[a + n:S(64.6)] = 0.0
    # END: only pad/bells/vox/fx after 64.6 (already arranged), fade the tail
    fade_s, fade_e = S(70.0), S(72.0)
    music[fade_s:fade_e] *= np.linspace(1, 0, fade_e - fade_s)[:, None]
    music[fade_e:] = 0

    # ---- game sound effects on picture cues
    cues = json.load(open(os.path.join(HERE, "build", "cues.json")))["cues"]
    cache = {}

    def load(name, semis=0.0):
        k = (name, semis)
        if k not in cache:
            x, sr = sf.read(os.path.join(SFX_DIR, name + ".wav"), always_2d=False)
            if x.ndim == 2:
                x = x.mean(1)
            if sr != SR:
                x = np.interp(np.arange(0, len(x), sr / SR), np.arange(len(x)), x)
            if semis:
                r = 2 ** (semis / 12)
                x = np.interp(np.arange(0, len(x), r), np.arange(len(x)), x)
            cache[k] = x
        return cache[k]

    MAP = {
        "place": [("place_m_{v}", -8)], "place_big": [("place_l_1", -4), ("stamp", -8)],
        "tick": [("pop", -14)], "clear_big": [("clear_3", -6), ("combo_3", -10)],
        "slab": [("stamp", -8)], "slab_big": [("mk2_stamp", -8)],
        "joker": [("joker_xmult", -9)], "mult": [("joker_mult", -12)],
        "counter_start": [("reel_spin", -8)], "word": [("ui_click_1", -12)],
        "machine_break": [("machine_break", -3)], "whoosh": [("score_whoosh", -6)],
        "impact": [], "pick": [("pickup", -8)], "clear_1": [("clear_1", -7)], "clear_2": [("clear_2", -6), ("combo_2", -12)],
        "clear_3": [("clear_3", -6), ("combo_3", -11)], "coin": [("coin_1", -8)], "stamp": [("stamp", -4), ("jingle_win", -14)],
        "print": [("print_tick", 4)], "receipt_total": [("feat", -8)], "score_big": [("record_new", -8)],
        "cascade": [("reel_spin", -10)], "legendary": [("legendary_reveal", -14)],
        "awning": [("modal_open", -6)], "card_drop": [("deal", -6)], "buy": [("buy", -6)], "lever": [("lever_pull", -4)],
        "finish": [("fin_{fin}_place", -4)], "boss_slam": [("boss_slam", -3), ("boss_alarm", -10)], "boss_hit": [("boss_slam", -7)],
        "mk2": [("mk2_stamp", -3)], "pip": [], "drop_impact": [("clear_3", -8)], "bar": [("stamp", -9)],
        "milestone": [("overtime", -8)], "crt_off": [("tool_cancel", -6)], "pops_hi": [("pops_hi", -4)],
        "logo_hit": [("jingle_run_win", -12)], "button": [("ui_click_2", -6)],
    }
    once = set()
    for c in cues:
        name = c["sfx"]
        t = c["t"]
        for fname, gdb in MAP.get(name, []):
            fname = fname.replace("{v}", str(c.get("var", 0) % 3 + 1)).replace("{fin}", c.get("fin", "gold"))
            if name == "legendary" and "legendary" in once:
                fname, gdb = "joker_xmult", -10
            once.add(name)
            semis = 2.0 if KEYUP_FROM <= t < KEYUP_TO else 0.0
            if name == "print":  # printer ticks rise in pitch line by line
                semis = c.get("var", 0) * 0.5
            x = load(fname, semis)
            gain = db(gdb) * (c.get("vol", 1.0))
            sfxb.add(x, t, gain, pan=((c.get("var", 0) % 5) - 2) * 0.12)

    mix = music * db(-2) + sfxb.x * db(-1)
    mix = highpass(mix, 28, 2)
    mix = dsp.limiter(mix * db(3), -1.5, 0.08)
    return mix[: S(DUR)]


def main():
    mix = build()
    os.makedirs(os.path.join(HERE, "build"), exist_ok=True)
    out = os.path.join(HERE, "build", "score.wav")
    sf.write(out, mix.astype(np.float32), SR, subtype="PCM_24")
    peak = 20 * np.log10(np.abs(mix).max() + 1e-9)
    print(f"wrote {out}  peak {peak:.1f} dBFS  rms {dsp.rms_db(mix):.1f} dB")


if __name__ == "__main__":
    main()
