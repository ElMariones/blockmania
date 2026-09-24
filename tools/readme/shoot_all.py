"""Captures the README screenshots and GIFs from the real game (dev-only).

    DISPLAY=:99 BM_GODOT=godot python tools/readme/shoot_all.py [shot ...]

Each shot in shots.py is a fixture run by tools/shoot.py (off-screen window, no editor).
Mid-run shots replay a seeded run with the autoplayer (prelude.gd) and may stage a board
(stage.gd); the rules are never bypassed for scoring. GIF shots record frames in slow motion
(Engine.time_scale 0.25) and mkgif.py assembles them at real speed. Output: docs/media/raw/
and docs/media/*.gif. Then run build_media.py.
"""
import os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
RAW = os.path.join(ROOT, "docs/media/raw")
sys.path.insert(0, HERE)
import shots, mkgif

PRELUDE = open(os.path.join(HERE, "prelude.gd")).read()
BARE = "var m = get_tree().current_scene\nm.settings.tips = false\nm.toasts.visible = false\n"
GIFS = {"gif_play": ("gameplay.gif", 0), "gif_boss": ("boss_intro.gif", 2)}


def shoot(name, body, steps=0, jokers=(), credits=0, res="1920x1080", use_prelude=True, cond="false", seed=17):
    work = tempfile.mkdtemp(prefix="bm_readme_")
    src = BARE
    if use_prelude:
        src = (PRELUDE.replace("STEPS", str(steps)).replace("JOKERS", repr(list(jokers)).replace("'", '"'))
               .replace("CREDITS", str(credits)).replace("COND", cond).replace("new_run(17,", "new_run(%d," % seed))
    path = os.path.join(work, name + ".gd")
    open(path, "w").write(src + body)
    env = dict(os.environ, BM_FRAMES=os.path.join(work, "frames"))
    out = os.path.join(RAW if name not in GIFS else work, name + ".png")
    p = subprocess.run([sys.executable, "tools/shoot.py", path, out, res], cwd=ROOT, env=env,
                       capture_output=True, text=True, timeout=600)
    for line in (p.stdout + p.stderr).splitlines():
        if "SCRIPT ERROR" in line or "INFO" in line or "SHOT" in line or "Parse Error" in line:
            print(name, line)
    if name in GIFS:
        gif, start = GIFS[name]
        mkgif.build(os.path.join(work, "frames"), os.path.join(ROOT, "docs/media", gif), 720, 2, start=start)


if __name__ == "__main__":
    os.makedirs(RAW, exist_ok=True)
    only = sys.argv[1:]
    for name, kw in shots.SHOTS.items():
        if not only or name in only:
            shoot(name, **kw)
