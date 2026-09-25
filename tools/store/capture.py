"""Captures the Steam store media from the real game (dev-only), on a sandboxed profile.

    python tools/store/capture.py [shot ...]      # then: python tools/store/build_store.py

Reuses the README fixtures (tools/readme/shots.py) through tools/shoot.py with BM_SANDBOX=1, so the
owner's saves, settings and achievements are never touched. Output (git-ignored work files):
    build/store/raw/<shot>.png        1920x1080 stills (Steam screenshots and description art)
    build/store/frames/<clip>/        slow-motion frames at 1280x720 for the description clips
"""
import os, shutil, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, "tools/readme"))
import shots  # noqa: E402

OUT = os.path.join(ROOT, "build/store")
PRELUDE = open(os.path.join(ROOT, "tools/readme/prelude.gd")).read()
BARE = "var m = get_tree().current_scene\nm.settings.tips = false\nm.toasts.visible = false\n"
# A seasoned profile, so the Kit screen shows every Kit and some Heat unlocked.
PROFILE = """
var bm_prof := ConfigFile.new()
for kv in [["lines", 900], ["wins", 6], ["bosses", 24], ["hands", 80], ["runs", 30], ["heat_won", 2]]:
	bm_prof.set_value("profile", kv[0], kv[1])
bm_prof.save(BMSaveStore.profile_path)
"""
CLIPS = ("clip_boss", "clip_long")
# The store's gameplay clip: carry the Plus across the board to a triple clear that wins the round.
# Frames are written as they are drawn (slow motion, Engine.time_scale 0.25) with their times, so
# build_store.py plays them back at real speed.
LONG_GRAB = """
await RenderingServer.frame_post_draw
var bm_img := get_viewport().get_texture().get_image()
bm_img.resize(1280, 720, Image.INTERPOLATE_BILINEAR)
bm_img.save_png("%s/f_%04d_%d.png" % [bm_dir, bm_n, Time.get_ticks_msec() - bm_t0])
bm_n += 1
"""


def _indent(src):
    return "".join("\t" + l + "\n" for l in src.strip("\n").split("\n"))


def _frames(n):
    return "for bm_k in %d:\n" % n + _indent(LONG_GRAB)


STILLS = ("title", "kits", "round", "clear", "shop", "round_pick", "boss_intro", "boss_round", "won",
          "bag", "pause", "trophies", "endless")


def _long_body():
    capture = shots.CAPTURE + "var bm_n := 0\n"
    carry = """
m.game_screen._select_by_key(0)
for bm_a in [Vector2i(0, 5), Vector2i(1, 5), Vector2i(1, 4), Vector2i(2, 3), Vector2i(3, 3), Vector2i(3, 2)]:
	m.game_screen.key_anchor = bm_a
	m.game_screen._show_ghost(bm_a)
""" + _indent(_frames(9))
    body = shots.STAGE + capture + _frames(24) + carry + _frames(20)
    # The triple clear also wins the round: the clip ends on the Credits breakdown.
    body += 'm.game_screen._do_action({"a": "place", "slot": 0, "x": plus_anchor.x, "y": plus_anchor.y})\n'
    body += _frames(230)
    return body + 'print("INFO frames ", bm_n)\n'


def _boss_body():
    """The Warden Mk II's entrance, played to the end, then a moment of the boss round."""
    setup = shots.SHOTS["gif_boss"]["body"].split("m.continue_run()")[0].split("var bm_frames")[0]
    return setup + shots.CAPTURE + "var bm_n := 0\nm.continue_run()\n" + _frames(330) + 'print("INFO frames ", bm_n)\n'


def shoot(name, body, steps=0, jokers=(), credits=0, res="1920x1080", use_prelude=True, cond="false", seed=17):
    work = tempfile.mkdtemp(prefix="bm_store_")
    src = BARE
    if use_prelude:
        src = (PRELUDE.replace("STEPS", str(steps)).replace("JOKERS", repr(list(jokers)).replace("'", '"'))
               .replace("CREDITS", str(credits)).replace("COND", cond).replace("new_run(17,", "new_run(%d," % seed))
    if name == "kits":
        src = PROFILE + src
    if name in CLIPS:
        body = body.replace("bm_img.resize(800, 450,", "bm_img.resize(1280, 720,")
    path = os.path.join(work, name + ".gd")
    open(path, "w", encoding="utf-8").write(src + body)
    frames = os.path.join(OUT, "frames", name)
    shutil.rmtree(frames, ignore_errors=True)
    env = dict(os.environ, BM_FRAMES=frames.replace("\\", "/"), BM_SANDBOX="1")
    out = os.path.join(OUT, "raw" if name not in CLIPS else "frames", name + ".png")
    p = subprocess.run([sys.executable, "tools/shoot.py", path, out, res], cwd=ROOT, env=env,
                       capture_output=True, text=True, timeout=900)
    for line in (p.stdout + p.stderr).splitlines():
        if "SCRIPT ERROR" in line or "INFO" in line or "SHOT" in line or "Parse Error" in line:
            print(name, line)


if __name__ == "__main__":
    for d in ("raw", "frames"):
        os.makedirs(os.path.join(OUT, d), exist_ok=True)
    only = sys.argv[1:]
    for name in STILLS + CLIPS:
        if not only or name in only:
            if name == "clip_boss":
                shoot(name, _boss_body())
            elif name == "clip_long":
                shoot(name, _long_body(), steps=3000, cond=shots.MID7, jokers=shots.BUILD, credits=14)
            else:
                shoot(name, **shots.SHOTS[name])
