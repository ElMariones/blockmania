extends SceneTree
## Headless test entry point:
##   godot --headless --path . --script res://tests/run_tests.gd
## Runs every `test_*` method in res://tests/test_*.gd. Exit code 0 = all passed.
## Optional filter: append `-- <substring>` to run matching test files or methods only.


func _init() -> void:
	var filter := ""
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		filter = args[0]
	var files: Array[String] = []
	var dir := DirAccess.open("res://tests")
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_case.gd":
			files.append(f)
	files.sort()
	var passed := 0
	var failed := 0
	var started := Time.get_ticks_msec()
	var capture = load("res://tests/error_capture.gd").new()
	OS.add_logger(capture)
	for f in files:
		var script: GDScript = load("res://tests/" + f)
		if script == null or not script.can_instantiate():
			print("LOAD FAIL  %s" % f)
			failed += 1
			continue
		var methods: Array[String] = []
		for m in script.get_script_method_list():
			var n: String = m.name
			if n.begins_with("test_") and not methods.has(n):
				methods.append(n)
		for n in methods:
			if filter != "" and not (f.contains(filter) or n.contains(filter)):
				continue
			var inst: BMTestCase = script.new()
			capture.begin_capture()
			inst.call(n)
			for err in capture.end_capture():
				inst.failures.append("runtime error: " + err)
			if inst.failures.is_empty():
				passed += 1
			else:
				failed += 1
				print("FAIL  %s::%s" % [f, n])
				for msg in inst.failures:
					print("      - %s" % msg)
	print("")
	print("%d passed, %d failed (%d ms)" % [passed, failed, Time.get_ticks_msec() - started])
	OS.remove_logger(capture)
	quit(0 if failed == 0 else 1)
