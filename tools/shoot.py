"""Dev-only screenshot runner. Launches the game as a separate background process (never through
the editor, never taking focus, window placed off-screen, audio muted via the Dummy driver),
runs a GDScript fixture, saves a PNG of the final frame and quits.

Usage:
    python tools/shoot.py fixture.gd [out.png] [WIDTHxHEIGHT]

The fixture is the body of an async function running inside a Node added to the scene tree
after `res://game/main.tscn` loads, e.g.:

    await get_tree().create_timer(0.5).timeout
    var m = get_tree().current_scene
    m.start_new_run(4242)
    print("INFO score=", m.run.round_state.score)   # lines starting with INFO are echoed

Set BM_GODOT to the Godot 4.7.2 console executable if it is not at the default path.
The launch splash is skipped (`-- --no-splash`); set BM_SPLASH=1 to keep it.
"""
import os, subprocess, sys, tempfile, textwrap

GODOT = os.environ.get("BM_GODOT", r"C:/Users/mario/Downloads/Godot_v4.7.2-stable_win64_console.exe")
PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))).replace("\\", "/")


def main() -> None:
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    fixture = open(sys.argv[1], encoding="utf-8").read()
    out = os.path.abspath(sys.argv[2] if len(sys.argv) > 2 else "shot.png").replace("\\", "/")
    res = sys.argv[3] if len(sys.argv) > 3 else "1920x1080"
    w, h = (int(v) for v in res.split("x"))
    work = tempfile.mkdtemp(prefix="bm_shoot_").replace("\\", "/")
    open(work + "/fixture_node.gd", "w", encoding="utf-8", newline="\n").write(
        "extends Node\n\nfunc run() -> void:\n" + textwrap.indent(fixture, "\t") + "\n\tpass\n")
    open(work + "/runner.gd", "w", encoding="utf-8", newline="\n").write('''extends SceneTree

func _initialize() -> void:
	change_scene_to_file("res://game/main.tscn")
	_go.call_deferred()

func _go() -> void:
	await process_frame
	await process_frame
	var n: Node = load("%s/fixture_node.gd").new()
	root.add_child(n)
	await n.run()
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png("%s")
	print("SHOT_OK ", img.get_size())
	quit()
''' % (work, out))
    cmd = [GODOT, "--path", PROJECT, "--resolution", res, "--position", "%d,%d" % (-w - 400, -h - 400),
           "--windowed", "--audio-driver", "Dummy", "--script", work + "/runner.gd"]
    if os.environ.get("BM_SPLASH") != "1":
        cmd += ["--", "--no-splash"]
    flags = 0x08000000 if os.name == "nt" else 0  # CREATE_NO_WINDOW: no console flash
    p = subprocess.run(cmd, capture_output=True, text=True, timeout=180, creationflags=flags)
    txt = p.stdout + p.stderr
    keep = [l for l in txt.splitlines() if "SHOT_OK" in l or l.startswith("INFO") or "ERROR" in l or "WARNING" in l]
    print("\n".join(keep[-30:]) if keep else txt[-2000:])


if __name__ == "__main__":
    main()
