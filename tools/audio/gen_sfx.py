"""Generate BLOCKMANIA sound effects into assets/audio/sfx/ (16-bit WAV, 44.1 kHz).

Every sound is synthesized here (no samples). Tonal effects are tuned to a D major /
pentatonic palette so they sit well over the soundtrack. Each sound is normalized to its own
peak target, so relative loudness is decided here, not in game code.

Run:  python tools/audio/gen_sfx.py
"""
import os
import numpy as np
import soundfile as sf

from dsp import (SR, mix, bandpass, bell, db, env_adsr, env_exp, epiano, fade, highpass, lowpass, midi_hz,
                 noise, normalize_peak, osc, pad, pad_tail, piano, reverb, samples, saturate, sweep,
                 timeline, Track, rng)

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio", "sfx")

# Pitch palette (MIDI): D major pentatonic around the 5th octave.
PENTA = [74, 76, 78, 81, 83, 86, 88, 90, 93, 95]


def write(name: str, x: np.ndarray, peak_db: float, room: float = 0.0, t60: float = 0.5) -> None:
    x = highpass(np.asarray(x, dtype=float), 25, 2)  # no DC / sub rumble
    if room > 0:
        x = reverb(pad_tail(x, t60 * 0.8), mix=room, t60=t60, predelay=0.006, bright=7000, seed=len(name))
        if x.ndim == 2 and not name.startswith(("jingle", "sting", "clear")):
            x = x.mean(axis=1)
    x = fade(normalize_peak(x, peak_db), 0.001, 0.01)
    # Trim trailing silence (below -70 dB).
    env = np.abs(x) if x.ndim == 1 else np.abs(x).max(axis=1)
    idx = np.nonzero(env > db(-70))[0]
    if len(idx):
        x = x[: min(len(x), idx[-1] + samples(0.02))]
    x = fade(x, 0.001, 0.008)
    sf.write(os.path.join(OUT, name + ".wav"), x.astype(np.float32), SR, subtype="PCM_16")


def tone(midi, dur, shape="sine", t60=None, attack=0.002):
    t60 = t60 or dur
    return osc(midi_hz(midi), dur, shape) * env_exp(dur, t60, attack)


def click_noise(dur=0.006, lo=2000, hi=7000, seed=0):
    n = noise(dur, seed)
    return bandpass(n, lo, hi, 1) * np.exp(-timeline(dur) * 700)


def woody(midi, dur=0.18, vel=1.0, seed=0):
    """Toy wood-block: a pitched body with a very fast pitch drop and a knock."""
    f = midi_hz(midi)
    t = timeline(dur)
    body = osc(sweep(f * 1.35, f, dur), dur) * np.exp(-t * 38)
    over = np.sin(2 * np.pi * f * 2.4 * t) * np.exp(-t * 90) * 0.35
    k = click_noise(0.008, 1500, 6000, seed)
    out = body + over
    out[: len(k)] += k * 0.6
    return out * vel


def plastic(midi, dur=0.3, vel=1.0, seed=0, thud=1.0):
    """Chunky plastic toy block landing: low thud + mid knock + a bright resonant tick."""
    f = midi_hz(midi)
    t = timeline(dur)
    low = osc(sweep(f * 0.5 * 1.8, f * 0.5, 0.05), dur) * np.exp(-t * 22) * thud
    mid = osc(sweep(f * 1.25, f, dur), dur) * np.exp(-t * 30) * 0.8
    res = np.sin(2 * np.pi * f * 3.1 * t) * np.exp(-t * 55) * 0.25
    k = click_noise(0.01, 1200, 5000, seed) * 0.9
    out = low + mid + res
    out[: len(k)] += k
    return saturate(out * vel, 1.3)


def whoosh(dur, f0, f1, seed=0, q=0.6):
    """Band-limited noise with a moving band (filter-bank approximation)."""
    n = noise(dur, seed)
    steps = 24
    out = np.zeros_like(n)
    edges = np.linspace(0, len(n), steps + 1).astype(int)
    for i in range(steps):
        fc = f0 * (f1 / f0) ** (i / (steps - 1))
        seg = bandpass(n, fc * (1 - q / 2), fc * (1 + q / 2), 1)[edges[i]:edges[i + 1]]
        out[edges[i]:edges[i + 1]] = seg
    return out * env_adsr(dur, dur * 0.4, dur * 0.2, 0.6, dur * 0.4)


def chime_chord(midis, dur=1.2, spread=0.035, vel=0.6):
    tr = Track(dur + spread * len(midis) + 0.1)
    for i, m in enumerate(midis):
        tr.add(bell(m, dur, vel), i * spread, pan=(i / max(1, len(midis) - 1) - 0.5) * 0.6)
    return tr.buf


def sparkle(dur=0.6, count=10, lo=88, hi=100, seed=0, vel=0.25):
    r = rng(seed)
    tr = Track(dur + 0.6)
    for i in range(count):
        m = r.integers(lo, hi)
        tr.add(bell(float(m), 0.5, vel * r.uniform(0.5, 1.0)), r.uniform(0, dur), pan=r.uniform(-0.7, 0.7))
    return tr.buf


def coin_blip(m1=83, m2=88, dur=0.28, vel=1.0):
    a = tone(m1, 0.06, "tri", 0.2)
    b = tone(m2, dur, "tri", dur * 0.8)
    out = np.concatenate([a, b])
    return lowpass(out, 7000, 1) * vel


def main() -> None:
    os.makedirs(OUT, exist_ok=True)

    # --- UI ------------------------------------------------------------------------------------
    for i, m in enumerate((98, 100)):
        x = mix(tone(m, 0.04, "sine", 0.03) * 0.6, click_noise(0.004, 3000, 9000, i) * 0.3)
        write(f"ui_hover_{i + 1}", x, -22)
    for i, (m, s) in enumerate(((86, 3), (88, 4))):
        x = mix(woody(m, 0.12, seed=s) * 0.7, tone(m + 12, 0.07, "tri", 0.05) * 0.25)
        write(f"ui_click_{i + 1}", x, -10, room=0.08, t60=0.3)
    write("ui_back", np.concatenate([woody(81, 0.06, seed=5), woody(76, 0.12, seed=6)]), -11, room=0.08, t60=0.3)
    write("ui_toggle_on", np.concatenate([woody(81, 0.05, seed=7), woody(88, 0.12, seed=8)]), -11, room=0.08, t60=0.3)
    write("ui_toggle_off", np.concatenate([woody(88, 0.05, seed=9), woody(81, 0.12, seed=10)]), -11, room=0.08, t60=0.3)
    write("ui_tick", woody(93, 0.05, 0.8, seed=11), -16)
    write("card_hover", whoosh(0.09, 2500, 5000, seed=12, q=0.8), -20)
    write("modal_open", mix(whoosh(0.22, 700, 2600, seed=14) * 0.8, bell(86, 0.22, 0.3)), -12, room=0.15, t60=0.6)
    write("pause_in", whoosh(0.3, 2600, 500, seed=15), -13, room=0.2, t60=0.8)
    write("pause_out", whoosh(0.25, 600, 2800, seed=16), -13, room=0.2, t60=0.8)
    bag = np.zeros(samples(0.38))
    r = rng(17)
    for k in range(7):
        s = samples(r.uniform(0, 0.28))
        burst = bandpass(noise(0.06, 30 + k), 800, 4500, 1) * env_adsr(0.06, 0.01, 0.02, 0.5, 0.03) * r.uniform(0.4, 1)
        bag[s:s + len(burst)] += burst[: len(bag) - s]
    write("bag_open", bag, -12, room=0.1, t60=0.4)
    write("bag_close", bag[: samples(0.2)][::-1], -14, room=0.1, t60=0.4)
    write("select", np.concatenate([woody(86, 0.04, seed=18), woody(93, 0.1, seed=19)]), -11)
    write("deselect", np.concatenate([woody(93, 0.04, seed=20), woody(86, 0.1, seed=21)]), -13)

    # --- Board ---------------------------------------------------------------------------------
    write("pickup", mix(woody(81, 0.1, seed=22) * 0.6, whoosh(0.08, 1200, 3000, seed=23) * 0.4), -11)
    write("putback", woody(69, 0.14, seed=24) * 0.8, -12)
    write("key_move", woody(90, 0.04, 0.7, seed=25), -19)
    for size, (m, thud, peak) in {"s": (69, 0.6, -8), "m": (64, 1.0, -6), "l": (57, 1.4, -4.5)}.items():
        for v in range(3):
            x = plastic(m + [0, 2, -2][v], 0.32, seed=40 + v, thud=thud)
            write(f"place_{size}_{v + 1}", x, peak, room=0.08, t60=0.35)
    deny = np.concatenate([tone(52, 0.09, "square", 0.3), np.zeros(samples(0.03)), tone(48, 0.16, "square", 0.25)])
    write("deny", lowpass(deny, 1800, 2) * 0.8, -12, room=0.05, t60=0.3)
    # Cell pop: a round bubble pling at A5; the game pitches it along the pentatonic scale.
    t = timeline(0.22)
    pop = mix(osc(sweep(midi_hz(81) * 0.7, midi_hz(81), 0.03), 0.22) * np.exp(-t * 26), bell(81 + 12, 0.22, 0.25))
    write("pop", pop, -12)
    write("glass", mix(highpass(noise(0.25, 60), 3000, 2) * env_exp(0.25, 0.18) * 0.5, sparkle(0.12, 8, 96, 105, 61, 0.5).mean(axis=1)), -9)
    write("stamp", np.concatenate([plastic(57, 0.08, seed=62, thud=1.2), click_noise(0.03, 1500, 5000, 63) * 0.5]), -10, room=0.05, t60=0.3)

    # Line clears: swept shimmer + chime chords growing with the number of lines.
    for lines, chord, peak in ((1, [74, 78, 81, 86], -5), (2, [74, 78, 81, 85, 88, 93], -4), (3, [62, 74, 78, 81, 85, 88, 90, 93, 98], -3)):
        dur = 0.9 + 0.35 * lines
        tr = Track(dur + 0.8)
        tr.add(whoosh(0.35 + 0.1 * lines, 900, 7000, seed=70 + lines) * 0.5, 0.0)
        tr.add(chime_chord(chord, dur, spread=0.045 - 0.008 * lines, vel=0.5), 0.05)
        if lines >= 2:
            tr.add(sparkle(0.5 * lines, 8 * lines, 93, 105, 80 + lines, 0.2), 0.12)
            t = timeline(0.6)
            tr.add(osc(sweep(90, 40, 0.6), 0.6) * np.exp(-t * 6) * 0.6, 0.0)
        write(f"clear_{lines}", tr.buf, peak, room=0.25, t60=1.4)
    for i, m in enumerate((81, 83, 86)):
        write(f"combo_{i + 1}", chime_chord([m, m + 7, m + 12], 0.7, 0.05, 0.6), -7, room=0.2, t60=1.0)

    # Joker triggers: chips = wood + blue bell, mult = FM ding, xmult = deep boing-ding.
    write("joker_chips", mix(woody(86, 0.1, seed=90) * 0.6, bell(93, 0.4, 0.5)), -9, room=0.12, t60=0.6)
    write("joker_mult", mix(epiano(90, 0.3, 0.9), bell(97, 0.25, 0.25)), -8, room=0.12, t60=0.6)
    t = timeline(0.7)
    boing = osc(midi_hz(62) * (1 + 0.08 * np.sin(2 * np.pi * 9 * t) * np.exp(-t * 4)), 0.7) * np.exp(-t * 5)
    write("joker_xmult", mix(boing * 0.6, epiano(86, 0.5, 1.0) * 0.8, sparkle(0.3, 6, 95, 104, 91, 0.3).mean(axis=1)), -6, room=0.15, t60=0.8)

    # --- Economy -------------------------------------------------------------------------------
    write("coin_1", coin_blip(83, 88), -12, room=0.08, t60=0.4)
    write("coin_2", coin_blip(85, 90), -12, room=0.08, t60=0.4)
    tr = Track(0.9)
    tr.add(plastic(52, 0.12, seed=100, thud=0.6), 0.0, 0.7)
    for i, m in enumerate((95, 98.2)):
        tr.add(bell(m, 0.7, 0.8), 0.06 + i * 0.07)
    tr.add(coin_blip(88, 93, 0.3, 0.6), 0.2)
    write("buy", tr.buf, -6, room=0.12, t60=0.6)
    tr = Track(0.9)
    r = rng(101)
    for i in range(6):
        tr.add(coin_blip(93 - i, 90 - i, 0.15, r.uniform(0.4, 0.8)), i * 0.06 + r.uniform(0, 0.02))
    write("sell", tr.buf, -8, room=0.12, t60=0.6)
    tr = Track(0.7)
    for i in range(7):
        tr.add(woody(76 + i * 2, 0.06, 0.8, seed=110 + i), i * 0.045)
    tr.add(whoosh(0.3, 800, 3500, seed=118) * 0.5, 0.2)
    write("reroll", tr.buf, -9, room=0.1, t60=0.5)
    tr = Track(0.9)
    t = timeline(0.5)
    anvil = sum(np.sin(2 * np.pi * midi_hz(88) * k * t) * np.exp(-t * (8 + 6 * k)) / k for k in (1, 2.7, 5.2))
    tr.add(anvil * 0.5, 0.0)
    tr.add(sparkle(0.4, 10, 93, 104, 120, 0.3), 0.08)
    write("workshop", tr.buf, -7, room=0.15, t60=0.7)
    tr = Track(1.0)
    for i, m in enumerate((81, 86, 90, 93, 98)):
        tr.add(bell(m, 0.6, 0.5), i * 0.05)
    tr.add(whoosh(0.5, 1500, 8000, seed=130) * 0.4, 0.0)
    write("item_use", tr.buf, -7, room=0.2, t60=0.9)
    write("refresh", np.concatenate([whoosh(0.18, 3000, 800, seed=140), whoosh(0.22, 800, 4200, seed=141)]), -10, room=0.1, t60=0.5)
    card = bandpass(noise(0.05, 142), 1500, 6000, 1) * env_adsr(0.05, 0.004, 0.01, 0.5, 0.03)
    write("deal", mix(card, woody(90, 0.05, 0.4, seed=143)), -13)
    write("print_tick", mix(bandpass(noise(0.012, 150), 1500, 5000, 1) * env_exp(0.012, 0.01), tone(100, 0.012, "square", 0.01) * 0.05), -26)
    write("score_whoosh", mix(whoosh(0.25, 900, 4000, seed=151, q=0.4) * 0.6, bell(98, 0.2, 0.3)), -15)
    write("alert", np.concatenate([bell(88, 0.25, 0.8)[: samples(0.2)], bell(81, 0.6, 0.8)]), -9, room=0.15, t60=0.8)
    # Title letters land on one sample, pitched up the scale in game.
    write("letter", mix(plastic(69, 0.25, seed=160, thud=0.8) * 0.8, bell(81, 0.2, 0.3)), -9, room=0.1, t60=0.5)

    # --- Stings and jingles (stereo) -------------------------------------------------------------
    tr = Track(2.2)
    for i, m in enumerate((74, 78, 81, 86)):
        tr.add(bell(m, 1.4, 0.55), i * 0.11, pan=-0.3 + i * 0.2)
        tr.add(epiano(m - 12, 0.9, 0.35), i * 0.11)
    tr.add(pad([62, 69, 74, 78], 1.0, 1400, seed=170, attack=0.3, release=0.8) * 0.4, 0.0)
    write("sting_round", tr.buf, -5, room=0.3, t60=1.6)
    tr = Track(3.2)
    tr.add(mix(piano(38, 2.0, 0.9, seed=171), piano(39, 2.0, 0.6, seed=172) * 0.6), 0.0)
    tr.add(pad([38, 44, 50, 51], 1.6, 700, seed=173, attack=0.8, release=1.2) * 0.6, 0.0)
    t = timeline(2.5)
    gong = sum(np.sin(2 * np.pi * midi_hz(45) * k * t) * np.exp(-t * (1.2 + k)) / k for k in (1, 1.52, 2.3, 3.1))
    tr.add(gong * 0.5, 0.35)
    write("sting_boss", tr.buf, -5, room=0.35, t60=2.4)
    tr = Track(2.6)
    at = 0.0
    for m, d in ((74, 0.12), (78, 0.12), (81, 0.12), (86, 0.3), (83, 0.12), (86, 0.9)):
        tr.add(bell(m + 12, 1.2, 0.45), at)
        tr.add(epiano(m, d + 0.3, 0.55), at)
        at += d
    tr.add(pad([62, 66, 69, 74], 1.6, 1800, seed=174, attack=0.2, release=1.0) * 0.4, 0.4)
    tr.add(sparkle(0.8, 14, 93, 105, 175, 0.2), 0.7)
    write("jingle_win", tr.buf, -4, room=0.3, t60=1.6)
    tr = Track(4.8)
    notes = [(62, 0.15), (66, 0.15), (69, 0.15), (74, 0.3), (69, 0.15), (74, 0.15), (78, 0.3), (81, 1.6)]
    at = 0.0
    for m, d in notes:
        tr.add(bell(m + 12, 1.4, 0.45), at)
        tr.add(epiano(m, d + 0.4, 0.6), at)
        tr.add(piano(m - 12, d + 0.2, 0.5, seed=int(m)), at)
        at += d
    tr.add(pad([50, 57, 62, 66, 69, 74], 2.4, 2200, seed=176, attack=0.4, release=1.4) * 0.5, 1.2)
    tr.add(sparkle(1.6, 30, 91, 106, 177, 0.2), 1.3)
    t = timeline(1.2)
    tr.add(osc(sweep(80, 38, 1.2), 1.2) * np.exp(-t * 3) * 0.5, 1.35)
    write("jingle_run_win", tr.buf, -3, room=0.3, t60=2.0)
    tr = Track(3.6)
    for i, (m, d) in enumerate(((69, 0.35), (67, 0.35), (65, 0.35), (62, 1.6))):
        at = [0.0, 0.35, 0.7, 1.05][i]
        tr.add(epiano(m, d + 0.3, 0.55), at)
        tr.add(piano(m - 12, d + 0.3, 0.45, seed=180 + i), at)
    tr.add(pad([50, 53, 57, 60], 2.2, 900, seed=181, attack=0.6, release=1.4) * 0.45, 0.6)
    write("jingle_lose", tr.buf, -5, room=0.35, t60=2.0)
    print("sfx written to", os.path.abspath(OUT))


if __name__ == "__main__":
    main()
