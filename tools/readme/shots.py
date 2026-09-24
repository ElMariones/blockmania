"""README capture list: name -> fixture options for shoot_all.shoot (GDScript bodies run after the
prelude; STAGE sets up a showcase board through the real run state)."""
import os
STAGE = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "stage.gd")).read()
BUILD = ["hall_of_mirrors", "snowball", "hot_hand", "jackpot_window", "mimic"]
SHOTS = {
    "title": dict(use_prelude=False, body="""
await get_tree().create_timer(2.2).timeout
"""),
    "banner": dict(use_prelude=False, body="""
for c in m.title_screen.stage.get_children():
	if c is BoxContainer or (c is Label and c.text == "prototype build"):
		c.visible = false
await get_tree().create_timer(2.4).timeout
"""),
    "round": dict(steps=127, jokers=BUILD, credits=14, body=STAGE + """
m.game_screen._select_by_key(0)
m.game_screen.key_anchor = plus_anchor
m.game_screen._show_ghost(plus_anchor)
await get_tree().create_timer(0.6).timeout
"""),
    "clear": dict(steps=127, jokers=BUILD, credits=14, body=STAGE + """
m.game_screen._do_action({"a": "place", "slot": 0, "x": plus_anchor.x, "y": plus_anchor.y})
await get_tree().create_timer(float(OS.get_environment("BM_T")) if OS.get_environment("BM_T") != "" else 0.08).timeout
"""),
    "boss_intro": dict(steps=0, body="""
bm_run.round_number = 8
bm_run.bosses[1] = "warden"
bm_run._start_round()
BMSaveStore.save_run(bm_run)
m.game_screen._intro_shown_for = -1
m.continue_run()
await get_tree().create_timer(1.55).timeout
"""),
    "boss_round": dict(steps=3000, cond="bm_run.round_number == 8 and bm_run.phase == BMRun.Phase.ROUND", jokers=BUILD[1:], body=STAGE + """
await get_tree().create_timer(1.4).timeout
"""),
    "shop": dict(steps=3000, cond="bm_run.phase == BMRun.Phase.SHOP and bm_run.round_number >= 6", jokers=BUILD, credits=23, body="""
await get_tree().create_timer(1.0).timeout
"""),
    "round_pick": dict(steps=3000, cond="bm_run.phase == BMRun.Phase.SHOP and bm_run.round_number >= 5 and bm_run.round_number % 4 != 3 and bm_run.round_number % 4 != 0", jokers=BUILD, credits=18, body="""
await get_tree().create_timer(0.6).timeout
m.shop_screen._show_round_picker()
await get_tree().create_timer(0.8).timeout
"""),
    "won": dict(steps=127, jokers=BUILD, credits=14, body=STAGE + """
m.game_screen._do_action({"a": "place", "slot": 0, "x": plus_anchor.x, "y": plus_anchor.y})
await get_tree().create_timer(2.2).timeout
"""),
    "bag": dict(steps=127, jokers=BUILD, body=STAGE + """
m.game_screen._show_bag()
await get_tree().create_timer(0.8).timeout
"""),
    "pause": dict(steps=127, jokers=BUILD, body=STAGE + """
m.show_pause()
await get_tree().create_timer(0.6).timeout
"""),
    "kits": dict(use_prelude=False, body="""
await get_tree().create_timer(0.8).timeout
m.title_screen._show_kit_picker("")
await get_tree().create_timer(0.8).timeout
"""),
    "trophies": dict(use_prelude=False, body="""
BMAchievementStore.unlock(BMAchievements.ids().slice(0, 30))
await get_tree().create_timer(0.5).timeout
m.title_screen._show_trophies()
var mv := InputEventMouseMotion.new()
mv.position = Vector2(1900, 1070)
mv.global_position = mv.position
Input.parse_input_event(mv)
await get_tree().create_timer(1.6).timeout
"""),
    "endless": dict(use_prelude=False, body="""
m.settings.endless_skin = "neon"
m.start_endless()
await get_tree().create_timer(0.3).timeout
var g = m.endless_screen.game
for k in 30:
	if g.over or g.board.occupied_count() >= 30 and k > 14:
		break
	var best := [-1, Vector2i.ZERO, -99.0]
	for i in 3:
		if g.tray[i].is_empty():
			continue
		for a in g.board.legal_anchors(g.tray[i].cells):
			var b = g.board.duplicate_board()
			b.place(g.tray[i].cells, a, 0)
			var lines = b.full_rows().size() + b.full_cols().size()
			var sc = lines * 10.0 - float(a.y) * 0.3 - float(a.x) * 0.1 + randf() * 0.5
			if sc > best[2]:
				best = [i, a, sc]
	if best[0] < 0:
		break
	m.endless_act({"a": "place", "i": best[0], "x": best[1].x, "y": best[1].y, "ms": 900})
m.endless_screen.bind(g)
await get_tree().create_timer(1.2).timeout
print("INFO endless score=", g.score, " over=", g.over, " combo=", g.combo)
"""),
}

CAPTURE = """
var bm_frames: Array = []
var bm_times: Array = []
var bm_t0 := Time.get_ticks_msec()
m.set_process(false)
Engine.time_scale = 0.25
m.crt.set_mode("off")
m.backdrop.set_motion(false)
var bm_dir := OS.get_environment("BM_FRAMES")
DirAccess.make_dir_recursive_absolute(bm_dir)
"""
GRAB = """
await RenderingServer.frame_post_draw
var bm_img := get_viewport().get_texture().get_image()
bm_img.resize(800, 450, Image.INTERPOLATE_BILINEAR)
bm_frames.append(bm_img)
bm_times.append(Time.get_ticks_msec() - bm_t0)
BMBlockPainter.clock += 0.04
"""
FLUSH = """
for i in bm_frames.size():
	bm_frames[i].save_png("%s/f_%04d_%d.png" % [bm_dir, i, bm_times[i]])
"""
def loop(n, extra=""):
    body = "for bm_k in %d:\n" % n
    for line in (extra + GRAB).strip("\n").split("\n"):
        body += "\t" + line + "\n"
    return body
SHOTS["gif_play"] = dict(steps=127, jokers=BUILD, credits=14, body=STAGE + CAPTURE + """
m.game_screen._select_by_key(0)
var bm_path := [Vector2i(0, 5), Vector2i(1, 5), Vector2i(1, 4), Vector2i(2, 3), Vector2i(3, 3), Vector2i(3, 2)]
for bm_a in bm_path:
	m.game_screen.key_anchor = bm_a
	m.game_screen._show_ghost(bm_a)
""" + loop(4).replace("\n", "\n\t").rstrip("\t") .replace("for bm_k", "\tfor bm_k", 1) + """
""" + loop(10) + """
m.game_screen._do_action({"a": "place", "slot": 0, "x": plus_anchor.x, "y": plus_anchor.y})
""" + loop(110) + FLUSH)
SHOTS["gif_boss"] = dict(steps=0, body="""
bm_run.round_number = 8
bm_run.bosses[1] = "warden"
bm_run._start_round()
BMSaveStore.save_run(bm_run)
m.game_screen._intro_shown_for = -1
""" + CAPTURE + """
m.continue_run()
""" + loop(120) + FLUSH)
