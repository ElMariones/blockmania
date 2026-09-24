"""Cues for the Refresh lever (BMRefreshLever). Synthesized; no samples.

Run:  python tools/audio/gen_sfx_lever.py
Out:  assets/audio/sfx/lever_pull.wav    a ratchet run of clicks down the gate and a metal thunk
      assets/audio/sfx/lever_spring.wav  the spring snapping the lever back up with a boing
"""
import os
import numpy as np

from dsp import bandpass, env_exp, fade, lowpass, noise, osc, saturate, sweep, Track
from gen_sfx import OUT, write

SR = 44100


def click(seed: int, bright: float) -> np.ndarray:
    n = noise(0.018, seed)
    return bandpass(n, 1800 * bright, 6500 * bright, 2) * env_exp(0.018, 0.012)


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    # Pull: four quick ratchet clicks, falling in pitch, then a low metal thunk at the bottom.
    tr = Track(0.45)
    for i in range(4):
        tr.add(click(5100 + i, 1.2 - i * 0.12) * 0.8, i * 0.024)
    body = osc(sweep(180, 90, 0.18), 0.18)
    tr.add(saturate(body * env_exp(len(body) / SR, 0.1) * 0.9, 1.6), 0.1)
    tr.add(bandpass(noise(0.08, 5110), 300, 2400, 2) * env_exp(0.08, 0.05) * 0.6, 0.1)
    for hz, t60, g in ((1320, 0.22, 0.12), (1990, 0.16, 0.07)):
        tone = osc(hz, 0.3, "sine")
        tr.add(tone * env_exp(len(tone) / SR, t60) * g, 0.1)
    write("lever_pull", tr.buf, -9, room=0.12, t60=0.35)
    # Spring back: a rising boing (a wobbling sine sweep) and a light top-stop click.
    t = np.arange(int(0.32 * SR)) / SR
    f = 220 + 520 * (1 - np.exp(-t * 14)) + 40 * np.sin(2 * np.pi * 26 * t) * np.exp(-t * 9)
    boing = np.sin(np.cumsum(2 * np.pi * f / SR)) * env_exp(0.32, 0.2) * 0.5
    tr = Track(0.45)
    tr.add(lowpass(boing, 3000, 2), 0.0)
    tr.add(click(5120, 1.4) * 0.6, 0.2)
    write("lever_spring", fade(tr.buf, 0.002, 0.03), -12, room=0.1, t60=0.3)
    print("wrote lever cues to", OUT)


if __name__ == "__main__":
    main()
