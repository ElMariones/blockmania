"""Visual 'listening' aid: log-frequency spectrogram + short-term loudness with section marks."""
import sys, numpy as np, soundfile as sf
from PIL import Image, ImageDraw, ImageFont
from scipy import signal
path = sys.argv[1] if len(sys.argv) > 1 else 'build/score.wav'
x, sr = sf.read(path); m = x.mean(1) if x.ndim == 2 else x
f, t, Z = signal.stft(m, sr, nperseg=4096, noverlap=4096 - 441)
P = 20 * np.log10(np.abs(Z) + 1e-7)
W, H = 1800, 520
fb = np.geomspace(30, 16000, H)
img = np.zeros((H, len(t)))
for i, fr in enumerate(fb): img[H - 1 - i] = P[np.argmin(np.abs(f - fr))]
img = np.clip((img + 90) / 70, 0, 1)
im = Image.fromarray((img * 255).astype(np.uint8)).resize((W, H))
im = Image.merge('RGB', [im.point(lambda v: min(255, v * 1.6)), im.point(lambda v: v), im.point(lambda v: max(0, 255 - v * 2) if v > 20 else 0)])
canvas = Image.new('RGB', (W + 60, H + 260), (12, 10, 18)); canvas.paste(im, (60, 0))
d = ImageDraw.Draw(canvas); font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 14)
for hz in (50, 100, 200, 500, 1000, 2000, 5000, 10000):
    y = H - 1 - np.argmin(np.abs(fb - hz)); d.text((4, y - 7), f'{hz}', fill='white', font=font)
dur = len(m) / sr
sec = [(0,'HOOK'),(4,'LOGO'),(6,'HOW'),(14,'RCPT'),(18,'JOKERS'),(24,'SHOP'),(28,'FIN'),(32,'BOSS'),(40,'DROP'),(44,'BARS'),(48,'MILES'),(56,'END')]
for s, n in sec:
    X = 60 + s / dur * W; d.line([(X, 0), (X, H + 250)], fill=(255, 204, 61)); d.text((X + 3, H + 4), n, fill=(255, 204, 61), font=font)
# short-term loudness (400ms RMS, K-ish weighting approx via highpass)
b, a = signal.butter(2, 100 / (sr / 2), 'high'); k = signal.lfilter(b, a, m)
hop = int(sr * 0.05); win = int(sr * 0.4)
L = [10 * np.log10(np.mean(k[i:i + win] ** 2) + 1e-10) for i in range(0, len(k) - win, hop)]
L = np.array(L); y0 = H + 30
for i in range(1, len(L)):
    x0 = 60 + (i - 1) * hop / sr / dur * W; x1 = 60 + i * hop / sr / dur * W
    v0 = y0 + 200 - np.clip((L[i - 1] + 50) / 50, 0, 1) * 200; v1 = y0 + 200 - np.clip((L[i] + 50) / 50, 0, 1) * 200
    d.line([(x0, v0), (x1, v1)], fill=(61, 214, 145), width=2)
for db_ in (-40, -30, -20, -10, 0):
    yy = y0 + 200 - (db_ + 50) / 50 * 200; d.text((4, yy - 7), f'{db_}', fill='gray', font=font); d.line([(60, yy), (W + 60, yy)], fill=(50, 40, 60))
clip = np.mean(np.abs(x) > 0.84)
d.text((70, H + 236), f'peak {20*np.log10(np.abs(x).max()):.1f} dBFS   samples > -1.5dB: {clip*100:.3f}%', fill='white', font=font)
canvas.save(path.replace('.wav', '_analysis.png'))
print('ok')
