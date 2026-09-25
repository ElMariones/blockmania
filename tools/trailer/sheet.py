"""Contact sheets from build/sheet_frames: 4x4 thumbnails with timecodes."""
import sys, glob, os
from PIL import Image, ImageDraw, ImageFont
fps, t0 = float(sys.argv[1]), float(sys.argv[2])
files = sorted(glob.glob('build/sheet_frames/f_*.jpg'))
font = ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf', 22)
for old in glob.glob('build/sheet_*.png'): os.remove(old)
for s in range(0, len(files), 16):
    sh = Image.new('RGB', (4 * 480, 4 * 270), 'black')
    d = ImageDraw.Draw(sh)
    for i, f in enumerate(files[s:s + 16]):
        im = Image.open(f).resize((480, 270), Image.LANCZOS)
        x, y = (i % 4) * 480, (i // 4) * 270
        sh.paste(im, (x, y))
        tc = t0 + (s + i) / fps
        d.rectangle([x, y, x + 84, y + 28], fill='black')
        d.text((x + 6, y + 3), f'{tc:.2f}s', fill='white', font=font)
    sh.save(f'build/sheet_{t0:05.1f}_{s // 16:02d}.png')
print('sheets', (len(files) + 15) // 16)
