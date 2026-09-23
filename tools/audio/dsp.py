"""BLOCKMANIA audio DSP: oscillators, envelopes, filters, effects and instrument models.

Everything here is synthesis from first principles (numpy/scipy); no samples are used.
Shared by gen_sfx.py (sound effects) and gen_music.py (soundtrack).
"""
import numpy as np
from scipy import signal

SR = 44100


# --- Basics ----------------------------------------------------------------------------------

def secs(n: int) -> float:
    return n / SR


def samples(t: float) -> int:
    return max(1, int(round(t * SR)))


def timeline(dur: float) -> np.ndarray:
    return np.arange(samples(dur)) / SR


def midi_hz(m: float) -> float:
    return 440.0 * 2.0 ** ((m - 69.0) / 12.0)


def db(x: float) -> float:
    return 10.0 ** (x / 20.0)


def rng(seed: int) -> np.random.Generator:
    return np.random.default_rng(seed)


def osc(freq, dur: float, shape: str = "sine", phase: float = 0.0) -> np.ndarray:
    """Oscillator; `freq` may be a scalar or a per-sample array (for sweeps)."""
    n = samples(dur)
    if np.isscalar(freq):
        f = np.full(n, float(freq))
    else:
        f = np.asarray(freq, dtype=float)[:n]
        if len(f) < n:  # hold the last frequency after a short sweep
            f = np.concatenate([f, np.full(n - len(f), f[-1])])
    ph = 2 * np.pi * np.cumsum(f) / SR + phase
    if shape == "sine":
        return np.sin(ph)
    if shape == "tri":
        return 2.0 / np.pi * np.arcsin(np.sin(ph))
    if shape == "square":
        # Soft square (sum of odd harmonics under Nyquist) to avoid aliasing.
        out = np.zeros(n)
        k = 1
        while k * f.max() < SR * 0.45 and k < 40:
            out += np.sin(k * ph) / k
            k += 2
        return out * 4 / np.pi
    if shape == "saw":
        out = np.zeros(n)
        k = 1
        while k * f.max() < SR * 0.45 and k < 60:
            out += ((-1) ** (k + 1)) * np.sin(k * ph) / k
            k += 1
        return out * 2 / np.pi
    raise ValueError(shape)


def sweep(f0: float, f1: float, dur: float, curve: str = "exp") -> np.ndarray:
    t = np.linspace(0.0, 1.0, samples(dur))
    if curve == "exp":
        return f0 * (f1 / f0) ** t
    return f0 + (f1 - f0) * t


def noise(dur: float, seed: int = 0) -> np.ndarray:
    return rng(seed).standard_normal(samples(dur))


# --- Envelopes -------------------------------------------------------------------------------

def env_exp(dur: float, t60: float, attack: float = 0.002) -> np.ndarray:
    """Fast attack, exponential decay reaching -60 dB after t60 seconds."""
    t = timeline(dur)
    e = np.exp(-6.9078 * t / max(t60, 1e-4))
    a = samples(attack)
    e[:a] *= np.linspace(0.0, 1.0, a)
    return e


def env_adsr(dur: float, a: float, d: float, s: float, r: float) -> np.ndarray:
    n = samples(dur)
    t = np.arange(n) / SR
    e = np.ones(n) * s
    e[t < a] = t[t < a] / max(a, 1e-4)
    m = (t >= a) & (t < a + d)
    e[m] = 1.0 - (1.0 - s) * (t[m] - a) / max(d, 1e-4)
    rel_start = max(0.0, dur - r)
    m = t >= rel_start
    e[m] *= np.clip(1.0 - (t[m] - rel_start) / max(r, 1e-4), 0.0, 1.0)
    return e


def fade(x: np.ndarray, fin: float = 0.003, fout: float = 0.01) -> np.ndarray:
    x = x.copy()
    a, b = samples(fin), samples(fout)
    if x.ndim == 1:
        x[:a] *= np.linspace(0, 1, a)
        x[-b:] *= np.linspace(1, 0, b)
    else:
        x[:a] *= np.linspace(0, 1, a)[:, None]
        x[-b:] *= np.linspace(1, 0, b)[:, None]
    return x


# --- Filters ---------------------------------------------------------------------------------

def _sos(kind: str, fc, order: int):
    nyq = SR / 2.0
    if isinstance(fc, (list, tuple)):
        wn = [min(max(f / nyq, 1e-4), 0.999) for f in fc]
    else:
        wn = min(max(fc / nyq, 1e-4), 0.999)
    return signal.butter(order, wn, btype=kind, output="sos")


def lowpass(x, fc: float, order: int = 2):
    return signal.sosfilt(_sos("lowpass", fc, order), x, axis=0)


def highpass(x, fc: float, order: int = 2):
    return signal.sosfilt(_sos("highpass", fc, order), x, axis=0)


def bandpass(x, lo: float, hi: float, order: int = 2):
    return signal.sosfilt(_sos("bandpass", [lo, hi], order), x, axis=0)


def sweep_lowpass(x: np.ndarray, f_start: float, f_end: float, blocks: int = 64) -> np.ndarray:
    """Time-varying lowpass by crossfading filtered blocks (cheap filter sweep)."""
    out = np.zeros_like(x)
    edges = np.linspace(0, len(x), blocks + 1).astype(int)
    zi = None
    for i in range(blocks):
        fc = f_start * (f_end / f_start) ** (i / max(1, blocks - 1))
        sos = _sos("lowpass", fc, 2)
        if zi is None:
            zi = signal.sosfilt_zi(sos) * 0.0
        seg, zi = signal.sosfilt(sos, x[edges[i]:edges[i + 1]], zi=zi)
        out[edges[i]:edges[i + 1]] = seg
    return out


def peaking(x, fc: float, gain_db: float, q: float = 1.0):
    """RBJ peaking EQ."""
    a = 10 ** (gain_db / 40)
    w0 = 2 * np.pi * fc / SR
    alpha = np.sin(w0) / (2 * q)
    b = [1 + alpha * a, -2 * np.cos(w0), 1 - alpha * a]
    aa = [1 + alpha / a, -2 * np.cos(w0), 1 - alpha / a]
    return signal.lfilter(np.array(b) / aa[0], np.array(aa) / aa[0], x, axis=0)


# --- Effects ---------------------------------------------------------------------------------

def saturate(x, drive: float = 1.5):
    return np.tanh(x * drive) / np.tanh(drive)


def bitcrush(x, bits: int = 10):
    q = 2 ** (bits - 1)
    return np.round(x * q) / q


def to_stereo(x: np.ndarray, pan: float = 0.0) -> np.ndarray:
    """Equal-power pan, -1 left .. 1 right."""
    if x.ndim == 2:
        return x
    ang = (pan + 1) * np.pi / 4
    return np.stack([x * np.cos(ang), x * np.sin(ang)], axis=1)


def reverb_ir(t60: float = 2.2, predelay: float = 0.015, bright: float = 5500.0, seed: int = 7,
              width: float = 1.0) -> np.ndarray:
    """Stereo impulse response: sparse early reflections + dense exponentially decaying noise
    whose high frequencies die faster (the tail darkens over time)."""
    r = rng(seed)
    n = samples(t60 * 1.1 + predelay)
    t = np.arange(n) / SR
    ir = np.zeros((n, 2))
    pd = samples(predelay)
    tail = r.standard_normal((n - pd, 2))
    decay = np.exp(-6.9078 * t[: n - pd] / t60)[:, None]
    bright_part = lowpass(tail, bright, 1) * decay ** 1.6
    dark_part = lowpass(tail, bright * 0.25, 1) * decay
    ir[pd:] = bright_part * 0.6 + dark_part * 0.9
    # Early reflections.
    for k in range(10):
        d = pd + samples(r.uniform(0.003, 0.045))
        ir[d, 0] += r.uniform(-0.9, 0.9) * (1 - k / 12)
        ir[d + samples(r.uniform(0.0005, 0.004)), 1] += r.uniform(-0.9, 0.9) * (1 - k / 12)
    mid = ir.mean(axis=1, keepdims=True)
    ir = mid + (ir - mid) * width
    ir /= np.sqrt((ir ** 2).sum() / 2)
    return ir


def reverb(x: np.ndarray, mix: float = 0.25, t60: float = 2.2, predelay: float = 0.015,
           bright: float = 5500.0, seed: int = 7) -> np.ndarray:
    """Convolution reverb; returns stereo with the dry signal kept (mix is the wet level)."""
    st = to_stereo(x)
    ir = reverb_ir(t60, predelay, bright, seed)
    wet = np.stack([signal.fftconvolve(st[:, 0], ir[:, 0])[: len(st)] + signal.fftconvolve(st[:, 1], ir[:, 0])[: len(st)] * 0.3,
                    signal.fftconvolve(st[:, 1], ir[:, 1])[: len(st)] + signal.fftconvolve(st[:, 0], ir[:, 1])[: len(st)] * 0.3], axis=1)
    return st + wet * mix * 0.35


def pad_tail(x: np.ndarray, t: float) -> np.ndarray:
    extra = samples(t)
    if x.ndim == 1:
        return np.concatenate([x, np.zeros(extra)])
    return np.concatenate([x, np.zeros((extra, x.shape[1]))])


def wow_flutter(x: np.ndarray, wow: float = 0.0018, wow_hz: float = 0.55, flutter: float = 0.0004,
                flutter_hz: float = 6.5, seed: int = 3) -> np.ndarray:
    """Tape-style pitch wobble via a modulated read position. Depth is in seconds of delay."""
    r = rng(seed)
    n = len(x)
    t = np.arange(n) / SR
    drift = np.cumsum(r.standard_normal(n // 4410 + 2))
    drift = np.interp(t, np.arange(len(drift)) * 0.1, drift)
    drift = (drift - drift.mean()) / (np.abs(drift).max() + 1e-9)
    d = wow * (0.6 * np.sin(2 * np.pi * wow_hz * t) + 0.4 * drift) + flutter * np.sin(2 * np.pi * flutter_hz * t)
    pos = np.clip(np.arange(n) - (d + wow + flutter) * SR, 0, n - 1)
    if x.ndim == 1:
        return np.interp(pos, np.arange(n), x)
    return np.stack([np.interp(pos, np.arange(n), x[:, c]) for c in range(x.shape[1])], axis=1)


def vinyl(dur: float, amount: float = 1.0, seed: int = 11) -> np.ndarray:
    """Stereo vinyl bed: soft hiss, low rumble and sparse crackle."""
    r = rng(seed)
    n = samples(dur)
    hiss = lowpass(highpass(r.standard_normal((n, 2)), 2500, 1), 9000, 1) * 0.012
    rumble = lowpass(r.standard_normal((n, 2)), 60, 2) * 0.02
    crackle = np.zeros((n, 2))
    k = int(dur * 9 * amount)
    idx = r.integers(0, n, k)
    crackle[idx, r.integers(0, 2, k)] = r.uniform(-1, 1, k) * r.uniform(0.05, 0.35, k)
    crackle = bandpass(crackle, 900, 7000, 1)
    pops = np.zeros((n, 2))
    k2 = int(dur * 0.4 * amount)
    idx2 = r.integers(0, n, k2)
    pops[idx2, :] = r.uniform(-1, 1, (k2, 1)) * 0.5
    pops = lowpass(pops, 2500, 1)
    return (hiss + rumble + crackle + pops) * amount


def rain(dur: float, amount: float = 1.0, seed: int = 21) -> np.ndarray:
    """Stereo rain on a window: a pink-ish wash plus scattered droplets."""
    r = rng(seed)
    n = samples(dur)
    wash = lowpass(highpass(r.standard_normal((n, 2)), 400, 1), 5000, 2)
    swell = 0.75 + 0.25 * np.sin(2 * np.pi * np.arange(n) / SR / 23.0)[:, None]
    drops = np.zeros((n, 2))
    k = int(dur * 55 * amount)
    idx = r.integers(0, n - 2000, k)
    for i, p in enumerate(idx):
        ln = r.integers(200, 900)
        f = r.uniform(1800, 4800)
        tt = np.arange(ln) / SR
        d = np.sin(2 * np.pi * f * tt * (1 + 3 * tt)) * np.exp(-tt * 180)
        drops[p:p + ln, i % 2] += d * r.uniform(0.02, 0.12)
    return (wash * 0.05 * swell + drops) * amount


def normalize_peak(x: np.ndarray, peak_db: float = -1.0) -> np.ndarray:
    m = np.abs(x).max()
    return x if m < 1e-9 else x * (db(peak_db) / m)


def rms_db(x: np.ndarray) -> float:
    return 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-12)


def limiter(x: np.ndarray, ceiling_db: float = -1.0, release: float = 0.12) -> np.ndarray:
    """Simple smoothed-gain peak limiter (look-ahead ~2 ms)."""
    ceil = db(ceiling_db)
    mono_peak = np.abs(x).max(axis=1) if x.ndim == 2 else np.abs(x)
    la = samples(0.002)
    need = np.minimum(1.0, ceil / np.maximum(mono_peak, 1e-9))
    # Look-ahead: take the minimum gain over the next `la` samples.
    need = np.minimum.reduce([np.roll(need, -k) for k in range(0, la, max(1, la // 8))])
    g = np.empty_like(need)
    coef = np.exp(-1.0 / (release * SR))
    cur = 1.0
    for i in range(len(need)):
        cur = need[i] if need[i] < cur else cur + (1 - coef) * (need[i] - cur)
        g[i] = cur
    return x * (g[:, None] if x.ndim == 2 else g)


def mix(*clips) -> np.ndarray:
    """Sum clips of different lengths (and mono/stereo) aligned at time 0."""
    stereo = any(c.ndim == 2 for c in clips)
    n = max(len(c) for c in clips)
    out = np.zeros((n, 2)) if stereo else np.zeros(n)
    for c in clips:
        c = to_stereo(c) if stereo and c.ndim == 1 else c
        out[: len(c)] += c
    return out


# --- Mixing helper ---------------------------------------------------------------------------

class Track:
    """A stereo mix buffer; place mono or stereo clips at times (seconds)."""

    def __init__(self, dur: float):
        self.buf = np.zeros((samples(dur), 2))

    def add(self, clip: np.ndarray, at: float, gain: float = 1.0, pan: float = 0.0) -> None:
        st = to_stereo(clip, pan) * gain
        s = samples(at) if at > 0 else 0
        e = min(len(self.buf), s + len(st))
        if e > s:
            self.buf[s:e] += st[: e - s]


# --- Instruments -----------------------------------------------------------------------------

def piano(midi: float, dur: float, vel: float = 0.7, seed: int = 0, ring: float = 1.0) -> np.ndarray:
    """Additive piano: inharmonic partials, 2-3 slightly detuned strings (beating), two-stage
    decay, velocity-dependent brightness, hammer knock, damper release after `dur`.
    Returns a mono clip that includes the release tail."""
    r = rng(seed)
    f0 = midi_hz(midi)
    rel = 0.35 * ring
    total = dur + rel + 0.05
    t = timeline(total)
    out = np.zeros(len(t))
    # Low notes ring longer; high notes are short and bright.
    t60_base = float(np.interp(midi, [21, 48, 72, 96, 108], [14.0, 9.0, 5.0, 2.2, 1.2])) * ring
    B = 0.00012 * 2 ** ((midi - 48) / 18)  # inharmonicity grows with pitch
    bright = 1.9 - 0.9 * vel
    strings = 3 if midi > 50 else 2
    detunes = [0.0, 0.6, -0.5][:strings]
    n_max = int(min(24, (9000 if vel > 0.5 else 6000) / f0))
    for n in range(1, max(2, n_max) + 1):
        fn = n * f0 * np.sqrt(1 + B * n * n)
        if fn > SR * 0.45:
            break
        amp = 1.0 / n ** bright
        if n == 1 and midi < 40:
            amp *= 0.6
        t60 = t60_base / (1 + 0.32 * (n - 1))
        env = 0.65 * np.exp(-6.9078 * t / (t60 * 0.25)) + 0.35 * np.exp(-6.9078 * t / t60)
        for dc in detunes:
            f = fn * 2 ** (dc / 1200)
            out += amp * env * np.sin(2 * np.pi * f * t + r.uniform(0, 2 * np.pi)) / strings
    # Hammer: a short felt knock, brighter at high velocity.
    hl = samples(0.02)
    knock = r.standard_normal(hl) * np.exp(-np.arange(hl) / SR * 260)
    knock = bandpass(knock, min(f0 * 2, 3000), min(f0 * 8 + 2000, 12000), 1) * (0.08 + 0.12 * vel)
    out[:hl] += knock
    thump = np.sin(2 * np.pi * 70 * t[:hl]) * np.exp(-np.arange(hl) / SR * 180) * 0.05 * vel
    out[:hl] += thump
    # Attack smoothing and damper release.
    a = samples(0.0025)
    out[:a] *= np.linspace(0, 1, a)
    d0 = samples(dur)
    rl = len(out) - d0
    if rl > 0:
        out[d0:] *= np.exp(-np.arange(rl) / SR / (0.09 * ring))
    return out * (0.25 + 0.75 * vel)


def epiano(midi: float, dur: float, vel: float = 0.6, seed: int = 0) -> np.ndarray:
    """FM electric piano (tine + tone bar): bell-like attack mellowing into a round sine."""
    f = midi_hz(midi)
    total = dur + 0.4
    t = timeline(total)
    idx = (1.6 + 2.2 * vel) * np.exp(-t * 7.0) + 0.35
    mod = np.sin(2 * np.pi * f * t) * idx
    body = np.sin(2 * np.pi * f * t + mod)
    tine = np.sin(2 * np.pi * f * 14.0 * t) * np.exp(-t * 60) * 0.12 * vel
    env = np.exp(-t * (1.1 + midi / 90.0))
    d0 = samples(dur)
    env[d0:] *= np.exp(-np.arange(len(env) - d0) / SR / 0.12)
    trem = 1.0 + 0.06 * np.sin(2 * np.pi * 4.6 * t)
    out = (body * 0.8 + tine) * env * trem
    a = samples(0.003)
    out[:a] *= np.linspace(0, 1, a)
    return saturate(out * (0.3 + 0.7 * vel), 1.2)


def pad(midis, dur: float, bright: float = 1400.0, seed: int = 0, attack: float = 1.6,
        release: float = 1.8) -> np.ndarray:
    """Warm detuned-saw pad for a whole chord, stereo."""
    r = rng(seed)
    total = dur + release
    n = samples(total)
    L = np.zeros(n)
    R = np.zeros(n)
    for m in midis:
        f = midi_hz(m)
        for k, cents in enumerate((-9, -3, 4, 10)):
            ff = f * 2 ** (cents / 1200)
            w = osc(ff, total, "saw", r.uniform(0, 6.28)) * 0.25
            if k % 2 == 0:
                L += w
            else:
                R += w
    st = np.stack([L, R], axis=1) / max(1, len(midis))
    st = lowpass(st, bright, 2)
    env = env_adsr(total, attack, 0.5, 0.85, release)
    lfo = 1 + 0.05 * np.sin(2 * np.pi * 0.21 * np.arange(n) / SR + r.uniform(0, 6))
    return st * (env * lfo)[:, None]


def bass(midi: float, dur: float, vel: float = 0.7) -> np.ndarray:
    f = midi_hz(midi)
    total = dur + 0.12
    t = timeline(total)
    body = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(4 * np.pi * f * t) * np.exp(-t * 3)
    env = env_adsr(total, 0.012, 0.25, 0.7, 0.12) * np.exp(-t * 0.6)
    return saturate(body * env * vel, 1.4) * 0.8


def bell(midi: float, dur: float = 2.5, vel: float = 0.6) -> np.ndarray:
    """Music-box / celesta bar: inharmonic modes of a free bar, highs fade first."""
    f = midi_hz(midi)
    t = timeline(dur)
    out = np.zeros(len(t))
    for ratio, amp, t60 in ((1.0, 1.0, dur), (2.756, 0.35, dur * 0.35), (5.404, 0.18, dur * 0.12), (8.933, 0.08, dur * 0.06)):
        if f * ratio < SR * 0.45:
            out += amp * np.sin(2 * np.pi * f * ratio * t) * np.exp(-6.9 * t / t60)
    a = samples(0.001)
    out[:a] *= np.linspace(0, 1, a)
    return out * vel * 0.6


def pluck(midi: float, dur: float = 1.0, vel: float = 0.6, seed: int = 0, bright: float = 0.5) -> np.ndarray:
    """Karplus-Strong string (nylon-ish), for soft plucked accents."""
    r = rng(seed)
    f = midi_hz(midi)
    n = samples(dur)
    period = int(SR / f)
    buf = r.uniform(-1, 1, period)
    buf = lowpass(buf, 2000 + 6000 * bright, 1)
    out = np.zeros(n)
    idx = 0
    damp = 0.996 - 0.004 * (1 - bright)
    for i in range(n):
        out[i] = buf[idx]
        nxt = (idx + 1) % period
        buf[idx] = damp * 0.5 * (buf[idx] + buf[nxt])
        idx = nxt
    return out * vel


# --- Drums (lofi) ----------------------------------------------------------------------------

def kick(vel: float = 0.8, tone: float = 1.0) -> np.ndarray:
    dur = 0.45
    f = sweep(150 * tone, 45 * tone, dur)
    t = timeline(dur)
    body = osc(f, dur) * np.exp(-t * 9)
    click = lowpass(noise(0.008, 5), 3000, 1) * 0.3
    body[: len(click)] += click * np.exp(-np.arange(len(click)) / SR * 400)
    return saturate(body * vel, 2.0) * 0.9


def snare(vel: float = 0.7, seed: int = 1, brushed: bool = False) -> np.ndarray:
    dur = 0.35 if not brushed else 0.28
    t = timeline(dur)
    nz = bandpass(noise(dur, seed), 900, 6500, 1) * np.exp(-t * (16 if not brushed else 11))
    tone = np.sin(2 * np.pi * 185 * t) * np.exp(-t * 30) * (0.5 if not brushed else 0.15)
    if brushed:
        nz = lowpass(nz, 5000, 1) * env_adsr(dur, 0.012, 0.05, 0.6, 0.2)
    return (nz * 0.8 + tone) * vel


def rim(vel: float = 0.6) -> np.ndarray:
    dur = 0.08
    t = timeline(dur)
    s = np.sin(2 * np.pi * 1700 * t) * np.exp(-t * 90) + bandpass(noise(dur, 9), 2000, 6000, 1) * np.exp(-t * 120) * 0.5
    return s * vel * 0.7


def hat(vel: float = 0.5, open_: bool = False, seed: int = 2) -> np.ndarray:
    dur = 0.3 if open_ else 0.06
    t = timeline(dur)
    nz = highpass(noise(dur, seed), 7000, 2) * np.exp(-t * (9 if open_ else 70))
    return nz * vel * 0.5


def shaker(vel: float = 0.4, seed: int = 4) -> np.ndarray:
    dur = 0.09
    nz = bandpass(noise(dur, seed), 4000, 11000, 1) * env_adsr(dur, 0.02, 0.02, 0.5, 0.05)
    return nz * vel * 0.5
