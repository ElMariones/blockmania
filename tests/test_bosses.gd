extends BMTestCase
## The Warden and The Undertaker (docs/design/round_play_update.md §5).

const ONE_ROW := ["1111111.", "........", "........", "........", "........", "........", "........", "........"]


func _boss_round(boss: String, seed_value: int = 21) -> BMRun:
	var run := BMRun.new_run(seed_value)
	run.bosses[0] = boss
	run.round_number = 4
	run._start_round()
	return run


func test_new_bosses_are_in_the_pool() -> void:
	var pool := BMBosses.pool(false)
	check(pool.has("warden") and pool.has("undertaker"), "in pool")
	check(not pool.has("echo_chamber"), "Echo Chamber stays out")


func test_warden_bars_a_slot_until_the_first_clear() -> void:
	var run := _boss_round("warden")
	var locked := run.round_state.locked_slot
	check(locked >= 0 and locked <= 2, "a slot is barred")
	check(not run.place(locked, Vector2i(0, 0)).ok, "barred piece can't be placed")
	check(not run.slot_fits(locked), "does not count as a fit")
	run.board = board_from(ONE_ROW)
	var open := (locked + 1) % 3
	run.tray[open] = shape(&"single")
	var r := run.place(open, Vector2i(7, 0))
	eq(r.unlocked, locked, "the clear breaks the bars")
	eq(run.round_state.locked_slot, -1, "slot free")


func test_warden_deals_and_refreshes_around_the_barred_slot() -> void:
	var run := _boss_round("warden", 5)
	var locked := run.round_state.locked_slot
	var prisoner: Dictionary = run.tray[locked].duplicate(true)
	run.refresh()
	eq(run.tray[locked].uid, prisoner.uid, "refresh leaves the barred piece")
	for i in 3:
		if i != locked:
			run.tray[i] = {}
	run._after_round_action()
	eq(run.tray[locked].uid, prisoner.uid, "a new deal skips the barred slot")
	for i in 3:
		if i != locked:
			check(not run.tray[i].is_empty(), "open slot %d dealt" % i)
	run.consumables.assign(["emergency_brick"])
	check(not run.use_consumable(0, {"slot": locked}).ok, "no bricking the barred slot")


func test_undertaker_raises_a_tomb_every_fourth_placement() -> void:
	var run := _boss_round("undertaker")
	run.round_state.target = 999999
	var tomb := Vector2i(-1, -1)
	for i in 4:
		run.tray[0] = shape(&"single")
		var r := run.place(0, Vector2i(i * 2, 3))
		check(r.ok, "placed %d" % i)
		if r.has("tomb"):
			tomb = r.tomb
	check(tomb.x >= 0, "a tombstone rose after the 4th placement")
	eq(run.board.get_cell(tomb), BMShapes.COLOR_STONE, "stone block")
	eq(run.board.full_rows().size() + run.board.full_cols().size(), 0, "never completes a line by itself")


func test_tomb_cell_avoids_completing_lines() -> void:
	var b := board_from(["1111111.", "1111111.", "1111111.", "1111111.", "1111111.", "1111111.", "1111111.", "1111111."])
	eq(BMBosses.tomb_cell(BMRngStream.new(1, "boss"), b), Vector2i(-1, -1), "every gap would finish a row")
