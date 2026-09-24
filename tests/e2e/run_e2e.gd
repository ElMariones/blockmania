extends SceneTree
## End-to-end suite: boots the real game (res://game/main.tscn) once per scenario with a
## sandboxed profile, runs tests/e2e/scenario_*.gd, and writes one artifact per scenario:
##   build/e2e/<scenario>.json   verdict, failures, runtime errors, checkpoints, fingerprint
##   build/e2e/<scenario>/*.png  screenshots (only with a display, e.g. under Xvfb)
##   build/e2e/summary.json      all verdicts and fingerprints
## Usage (exit code 0 = every scenario passed):
##   godot --headless --path . --script res://tests/e2e/run_e2e.gd [-- <name filter>]
##   DISPLAY=:99 godot --path . --script res://tests/e2e/run_e2e.gd   # with screenshots
## The fingerprint is a hash of each scenario's seeded facts: run it twice on the same build
## and it must not change. Runtime engine/script errors fail a scenario.

const SANDBOX := "user://e2e_sandbox"


func _init() -> void:
	_go.call_deferred()


func _go() -> void:
	var filter := ""
	var args := OS.get_cmdline_user_args()
	for a in args:
		if not a.begins_with("--"):
			filter = a
	var out_dir := ProjectSettings.globalize_path("res://").path_join("build/e2e")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var names: Array[String] = []
	for f in DirAccess.get_files_at("res://tests/e2e"):
		if f.begins_with("scenario_") and f.ends_with(".gd") and (filter == "" or f.contains(filter)):
			names.append(f.get_basename())
	names.sort()
	var capture = load("res://tests/error_capture.gd").new()
	OS.add_logger(capture)
	var summary := {}
	var failed := 0
	for n in names:
		_sandbox()
		change_scene_to_file("res://game/main.tscn")
		await process_frame
		await process_frame
		# The launch splash would sit over the title; scenarios start at the title screen.
		for c in current_scene.get_children():
			if c is BMSplash:
				c.queue_free()
		current_scene.title_screen.refresh()
		var scen: BME2ECase = load("res://tests/e2e/%s.gd" % n).new()
		scen.main = current_scene
		scen.artifact_dir = out_dir.path_join(n)
		DirAccess.make_dir_recursive_absolute(scen.artifact_dir)
		root.add_child(scen)
		var t0 := Time.get_ticks_msec()
		capture.begin_capture()
		await scen.run()
		# Let pending timers and tweens from the last action finish inside the capture window.
		await create_timer(1.5, true, false, true).timeout
		var errors: PackedStringArray = capture.end_capture()
		var ok: bool = scen.failures.is_empty() and errors.is_empty()
		var fingerprint := JSON.stringify(scen.facts, "", true).sha256_text()
		var art := {"scenario": n, "ok": ok, "failures": scen.failures, "runtime_errors": Array(errors),
			"fingerprint": fingerprint, "facts": scen.facts, "checkpoints": scen.checkpoints,
			"screenshots": scen.shots, "duration_ms": Time.get_ticks_msec() - t0,
			"engine": Engine.get_version_info().string, "display": DisplayServer.get_name()}
		var f := FileAccess.open(out_dir.path_join(n + ".json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(art, "  "))
		f.close()
		summary[n] = {"ok": ok, "fingerprint": fingerprint, "failures": scen.failures.size() + errors.size()}
		print("%s  %s  %s  (%d ms)" % ["PASS" if ok else "FAIL", n, fingerprint.substr(0, 12), art.duration_ms])
		for m in scen.failures:
			print("      - " + m)
		for e in errors:
			print("      - runtime error: " + e)
		if not ok:
			failed += 1
		scen.queue_free()
		await process_frame
	var sf := FileAccess.open(out_dir.path_join("summary.json"), FileAccess.WRITE)
	sf.store_string(JSON.stringify(summary, "  "))
	sf.close()
	OS.remove_logger(capture)
	print("\n%d scenarios, %d failed. Artifacts: %s" % [names.size(), failed, out_dir])
	quit(0 if failed == 0 else 1)


## A fresh, empty profile for each scenario: saves, settings, achievements, Endless, history.
func _sandbox() -> void:
	# Touch each store so its statics exist before they are redirected.
	BMSaveStore.has_run()
	BMAchievementStore.forget_cache()
	BMEndlessStore.high_scores()
	var dir := ProjectSettings.globalize_path(SANDBOX)
	if DirAccess.dir_exists_absolute(dir):
		for f in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.make_dir_recursive_absolute(dir)
	BMSaveStore.run_path = SANDBOX + "/run.json"
	BMSaveStore.settings_path = SANDBOX + "/settings.cfg"
	BMSaveStore.profile_path = SANDBOX + "/profile.cfg"
	BMSaveStore.history_path = SANDBOX + "/history.json"
	BMAchievementStore.path = SANDBOX + "/achievements.cfg"
	BMAchievementStore.forget_cache()
	BMEndlessStore.game_path = SANDBOX + "/endless.json"
	BMEndlessStore.scores_path = SANDBOX + "/endless_scores.json"
	# Scenarios read English text; the OS language must not leak in ("auto" is the default).
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "language", "en")
	cfg.save(BMSaveStore.settings_path)
