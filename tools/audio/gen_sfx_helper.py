"""Voice and cues for POPS, the tutorial helper (GDD §23). Synthesized; no samples, no speech.

POPS "talks" in cheerful gibberish, like a toy: every second letter of a line plays one short
vowel blip. Each blip is a buzzy glottal source (a saw with a little vibrato) through two
formant band-passes that shape it into a/e/i/o/u, with a fast attack and a quick decay.
At runtime BMTutorial picks the blip from the letter's vowel group and nudges the pitch from
the letter itself, so the same line always "sounds" the same.

Run:  python tools/audio/gen_sfx_helper.py
Out:  assets/audio/sfx/pops_a.wav ... pops_u.wav, pops_hi.wav, pops_next.wav, pops_bye.wav
"""
import os
import numpy as np

from dsp import bandpass, env_exp, fade, lowpass, osc, saturate, Track, noise
from gen_sfx import OUT, write, chime_chord, sparkle, woody

SR = 44100
# (F1, F2) in Hz, a cartoon-sized mouth (a little higher than an adult voice).
VOWELS = {"a": (900, 1400), "e": (600, 2200), "i": (380, 2700), "o": (620, 1000), "u": (420, 850)}


def blip(vowel: str, f0: float = 330.0, dur: float = 0.085) -> np.ndarray:
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = f0 * (1.0 + 0.012 * np.sin(2 * np.pi * 7.0 * t)) * (1.0 + 0.05 * np.exp(-t * 40))
    ph = np.cumsum(2 * np.pi * f / SR)
    src = 2.0 * (ph / (2 * np.pi) % 1.0) - 1.0
    f1, f2 = VOWELS[vowel]
    x = bandpass(src, f1 * 0.8, f1 * 1.25, 2) * 1.0 + bandpass(src, f2 * 0.85, f2 * 1.15, 2) * 0.55
    x = x + lowpass(src, 500, 2) * 0.25
    envelope = np.minimum(1.0, t / 0.006) * np.exp(-np.maximum(0.0, t - 0.02) * 38.0)
    return fade(saturate(x * envelope * 2.2, 1.3), 0.001, 0.01)


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    for v in VOWELS:
        write("pops_" + v, blip(v), -9)
    # Hello: a rising three-blip "hi-hi-hi!" with a sparkle.
    tr = Track(0.8)
    for i, (v, f) in enumerate((("a", 300), ("e", 360), ("i", 430))):
        tr.add(blip(v, f, 0.1), i * 0.09)
    tr.add(sparkle(0.4, 5, 96, 104, 2301, 0.1), 0.2)
    write("pops_hi", tr.buf, -8, room=0.15, t60=0.5)
    # Next line: a soft woody tick and a tiny chime.
    tr = Track(0.4)
    tr.add(woody(84, 0.05, 0.6, seed=2302), 0.0)
    tr.add(chime_chord([88, 95], 0.3, 0.02, 0.18), 0.02)
    write("pops_next", tr.buf, -12, room=0.1, t60=0.3)
    # Goodbye: a falling "bye-bye" and a little fanfare chord.
    tr = Track(1.2)
    for i, (v, f) in enumerate((("a", 420), ("i", 380), ("a", 330), ("i", 300))):
        tr.add(blip(v, f, 0.1), i * 0.1)
    tr.add(chime_chord([72, 76, 79, 84], 0.8, 0.03, 0.3), 0.42)
    write("pops_bye", tr.buf, -8, room=0.2, t60=0.7)
    print("wrote POPS voice and cues to", OUT)


if __name__ == "__main__":
    main()
