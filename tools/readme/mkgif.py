"""Assembles captured frames (f_<index>_<ms>.png) into a GIF at real speed with one shared palette."""
import os, sys, glob
from PIL import Image
def build(src, out, width=720, step=1, scale=0.25, start=0, colors=128):
    files = sorted(glob.glob(os.path.join(src, "f_*.png")))[start:]
    times = [int(os.path.basename(f).split("_")[2].split(".")[0]) for f in files]
    frames, durs = [], []
    pal = None
    for i in range(0, len(files), step):
        im = Image.open(files[i]).convert("RGB")
        if im.width != width:
            im = im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)
        nxt = times[min(i + step, len(files) - 1)]
        d = max(20, round((nxt - times[i]) * scale)) if i + step < len(files) else 1600
        if pal is None:
            # One palette from a mid-sequence frame so colors never flicker between frames.
            ref = Image.open(files[len(files) * 2 // 3]).convert("RGB").resize(im.size)
            both = Image.new("RGB", (im.width, im.height * 2))
            both.paste(im, (0, 0)); both.paste(ref, (0, im.height))
            pal = both.quantize(colors=colors, method=Image.MEDIANCUT)
        frames.append(im.quantize(palette=pal, dither=Image.NONE))
        durs.append(d)
    frames[0].save(out, save_all=True, append_images=frames[1:], duration=durs, loop=0, optimize=True, disposal=1)
    print(out, len(frames), os.path.getsize(out) // 1024, "KB", sum(durs), "ms")
if __name__ == "__main__":
    build(sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), start=int(sys.argv[5]) if len(sys.argv) > 5 else 0)
