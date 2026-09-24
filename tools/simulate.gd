extends SceneTree
## Rough balance probe with the greedy autoplayer (not a substitute for playtests):
##   godot --headless --path . --script res://tools/simulate.gd -- [runs=50] [first_seed=1] [overtime]
## Prints win rate, where runs end, and loss reasons. With "overtime", won runs continue into
## Overtime (GDD §19) until they lose, and the report lists where Overtime ended.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if args.size() > 0 else 50
	var first := int(args[1]) if args.size() > 1 else 1
	var overtime := args.size() > 2 and args[2] == "overtime"
	var ot_reached := {}
	var reached := {}
	var reasons := {}
	var wins := 0
	var points := 0
	var placements := 0
	var started := Time.get_ticks_msec()
	for i in runs:
		var run := BMAutoplayer.play(BMRun.new_run(first + i))
		if run.phase == BMRun.Phase.RUN_WON:
			wins += 1
			if overtime and run.start_overtime().ok:
				BMAutoplayer.play(run, 20000)
				ot_reached[run.round_number] = int(ot_reached.get(run.round_number, 0)) + 1
		reached[run.round_number] = int(reached.get(run.round_number, 0)) + 1
		var key := run.end_reason.get_slice(":", 0)
		reasons[key] = int(reasons.get(key, 0)) + 1
		points += int(run.stats.total_points)
		placements += int(run.stats.placements)
	print("runs=%d wins=%d (%.0f%%) avg points/placement=%.1f time=%d ms" % [runs, wins, 100.0 * wins / runs, float(points) / maxi(1, placements), Time.get_ticks_msec() - started])
	var keys := reached.keys()
	keys.sort()
	for k in keys:
		print("  ended in round %2d: %d" % [k, reached[k]])
	for r in reasons:
		print("  reason '%s': %d" % [r, reasons[r]])
	var ot_keys := ot_reached.keys()
	ot_keys.sort()
	for k in ot_keys:
		print("  overtime ended in round %2d (target %d): %d" % [k, BMRunConfig.target(k), ot_reached[k]])
	quit()
