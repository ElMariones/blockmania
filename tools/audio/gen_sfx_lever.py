"""Cues for the Refresh lever (BMRefreshLever): a one-armed-bandit pull. Synthesized; no samples.

Run:  python tools/audio/gen_sfx_lever.py
Out:  assets/audio/sfx/lever_pull.wav    the casino lever: a long ratchet that speeds up down the
                                         gate, a heavy metal KA-CHUNK with a ringing body, and a
                                         little coin jingle (the tray's reel cues play on top)
      assets/audio/sfx/lever_spring.wav  the spring snapping the arm back up: a wobbly boing and
                                         a top-stop clack
"""
import os
import numpy as np

from dsp import bandpass, env_exp, fade, lowpass, noise, osc, saturate, sweep, Track
from gen_sfx import OUT, write

SR = 44100


def click(seed: int, bright: float, dur: float = 0.02) -> np.ndarray:
    n = noise(dur, seed)
    return bandpass(n, 1500 * bright, 6000 * bright, 2) * env_exp(dur, dur * 0.6)


def tone(hz: float, dur: float, t60: float, gain: float) -> np.ndarray:
    x = osc(hz, dur, "sine")
    return x * env_exp(len(x) / SR, t60) * gain


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    tr = Track(1.1)
    # Ratchet: nine teeth, each gap shorter than the last, pitch falling as the arm travels.
    t = 0.0
    for i in range(9):
        tr.add(click(6100 + i, 1.25 - i * 0.07) * (0.55 + i * 0.04), t)
        tr.add(tone(900 - i * 40, 0.03, 0.02, 0.12), t)
        t += 0.034 - i * 0.0022
    hit = t + 0.01
    # KA-CHUNK: a low thud, a noise slap and a ringing cast-iron body (inharmonic partials).
    body = osc(sweep(150, 62, 0.22), 0.22)
    tr.add(saturate(body * env_exp(len(body) / SR, 0.12) * 1.1, 1.8), hit)
    tr.add(bandpass(noise(0.09, 6120), 200, 3000, 2) * env_exp(0.09, 0.05) * 0.8, hit)
    for hz, t60, g in ((523, 0.5, 0.10), (1187, 0.35, 0.08), (1766, 0.28, 0.06), (2931, 0.18, 0.04)):
        tr.add(tone(hz, 0.6, t60, g), hit)
    # Coin jingle: three bright bell pings, like the payout tray.
    for k, (hz, dt) in enumerate(((2637, 0.10), (3136, 0.16), (3951, 0.22))):
        tr.add(tone(hz, 0.4, 0.22, 0.09), hit + dt)
        tr.add(tone(hz * 2.76, 0.2, 0.08, 0.03), hit + dt)
        tr.add(click(6130 + k, 2.0, 0.01) * 0.25, hit + dt)
    write("lever_pull", tr.buf, -8, room=0.14, t60=0.5)

    # Spring back: a rising, wobbling boing and a light clack as the arm hits the top stop.
    tt = np.arange(int(0.34 * SR)) / SR
    f = 200 + 560 * (1 - np.exp(-tt * 13)) + 50 * np.sin(2 * np.pi * 24 * tt) * np.exp(-tt * 8)
    boing = np.sin(np.cumsum(2 * np.pi * f / SR)) * env_exp(0.34, 0.2) * 0.5
    tr = Track(0.5)
    tr.add(lowpass(boing, 3200, 2), 0.0)
    tr.add(click(6140, 1.4) * 0.7, 0.22)
    tr.add(tone(1400, 0.1, 0.05, 0.08), 0.22)
    write("lever_spring", fade(tr.buf, 0.002, 0.03), -12, room=0.1, t60=0.3)
    print("wrote lever cues to", OUT)


if __name__ == "__main__":
    main()
