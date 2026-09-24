extends BMTestCase
## Legendary Jokers (2026-09-24): The Avalanche, Hall of Mirrors, Philosopher's Stone,
## Supernova. Unique, from Boss Crates (act 2 on) and rarely late shops.

const EMPTY := ["........", "........", "........", "........", "........", "........", "........", "........"]
const ONE_ROW := ["1111111.", "........", "........", "........", "........", "........", "........", "........"]
## Clearing the bottom row drops the column-7 block into the gap: a second full row.
const AVALANCHE := ["........", "........", "........", "........", "........", ".......1", "1111111.", "1111111."]


func _value(r: Dictionary, id: String) -> Variant:
	for it in r.items:
		if it.get("joker", "") == id:
			return it.value
	return null


func test_avalanche_chains_a_second_wave_at_double_mult() -> void:
	var run := run_with(AVALANCHE, [shape(&"single")], ["avalanche"])
	run.round_state.target = 999999
	run.round_state.placements_left = 10
	var r := run.place(0, Vector2i(7, 7))
	eq(r.lines, 1, "first wave: one row")
	eq(r.waves.size(), 2, "a second wave")
	eq(int(r.waves[1].points), 360, "(100 line + 80 cells) x 2")
	eq(r.points, 110 + 360, "total adds both waves")
	eq(r.wave_lines, 1, "one wave line")
	eq(run.board.occupied_count(), 0, "everything cleared")
	eq(r.placements_refilled, 2, "both lines refill")
	eq(int(run.stats.best_waves), 2, "best chain recorded")


func test_no_avalanche_without_the_card() -> void:
	var run := run_with(AVALANCHE, [shape(&"single")])
	run.round_state.target = 999999
	var r := run.place(0, Vector2i(7, 7))
	eq(r.waves.size(), 1, "one wave")
	eq(run.board.occupied_count(), 8, "blocks stay where they are")


func test_hall_of_mirrors_triggers_jokers_twice() -> void:
	var run := run_with(ONE_ROW, [shape(&"single")], ["hall_of_mirrors", "clean_sweep", "golden_ratio"])
	run.round_state.target = 999999
	run.round_state.placements_made = 2
	var r := run.place(0, Vector2i(7, 0))
	var sweeps := 0
	var ratios := 0
	for it in r.items:
		if it.get("joker", "") == "clean_sweep":
			sweeps += 1
		if it.get("joker", "") == "golden_ratio":
			ratios += 1
	eq(sweeps, 2, "Clean Sweep twice")
	eq(ratios, 2, "Golden Ratio twice")
	eq(r.chips, 10 + 100 + 100, "cells + line + 2 x 50")
	check(is_equal_approx(r.mult, 2.25), "x1.5 twice")
	var plain := run_with(ONE_ROW, [shape(&"single")], ["clean_sweep"])
	plain.round_state.target = 999999
	eq(plain.place(0, Vector2i(7, 0)).chips, 160, "without it: once")


func test_philosophers_stone_doubles_and_transmutes() -> void:
	var run := BMRun.new_run(31)
	run.jokers.assign(["philosophers_stone"])
	run.round_state.target = 999999
	run.board = board_from(EMPTY)
	var piece: Dictionary = run.tray[0]
	piece.material = "chrome"
	var slot := 0
	var r := run.place(slot, run.board.legal_anchors(piece.cells)[0])
	var chrome := 0
	for it in r.items:
		if String(it.label).begins_with("Chrome"):
			chrome = int(it.value)
	eq(chrome, BMPieces.CHROME_CHIPS_PER_CELL * piece.cells.size() * 2, "Chrome doubled")
	eq(String(r.transmuted), "", "already had a material")
	var plain: Dictionary = {}
	for i in run.tray.size():
		if not run.tray[i].is_empty() and String(run.tray[i].material) == "":
			plain = run.tray[i]
			slot = i
			break
	check(not plain.is_empty(), "a plain piece to place")
	var uid := int(plain.uid)
	r = run.place(slot, run.board.legal_anchors(plain.cells)[0])
	check(String(r.transmuted) != "", "transmuted")
	eq(String(BMBag.piece_by_uid(run, uid).material), String(r.transmuted), "the bag piece keeps it")
	eq(int(run.stats.transmuted), 1, "counted")


func test_supernova_grows_with_lines_this_round() -> void:
	var run := run_with(ONE_ROW, [shape(&"single"), shape(&"single")], ["supernova"])
	run.round_state.target = 999999
	var r := run.place(0, Vector2i(7, 0))
	eq(_value(r, "supernova"), null, "no lines before: x1")
	eq(run.round_state.lines_cleared, 1, "one line counted")
	run.round_state.lines_cleared = 6
	r = run.place(1, Vector2i(0, 5))
	eq(_value(r, "supernova"), 4.0, "6 lines: x4")
	run._start_round()
	eq(run.round_state.lines_cleared, 0, "a new round starts from x1")


func test_legendaries_never_repeat_and_crates_can_hold_one() -> void:
	var run := BMRun.new_run(40)
	run.jokers.assign(BMJokers.LEGENDARY_IDS.slice(0, 3))
	for i in 20:
		eq(run._pick_joker(BMJokers.LEGENDARY, []), "supernova", "only the missing one")
	run.jokers.append("supernova")
	eq(run._pick_joker(BMJokers.LEGENDARY, []), "", "none left")
	var found := 0
	for s in 200:
		var r := BMRun.new_run(1000 + s)
		r.round_number = 8
		var crate := r._roll_crate()
		if BMJokers.is_legendary(String(crate[0].id)):
			found += 1
	check(found > 5 and found < 60, "act 2 crates: some legendaries (%d of 200)" % found)
	for s in 100:
		var r := BMRun.new_run(2000 + s)
		r.round_number = 4
		check(not BMJokers.is_legendary(String(r._roll_crate()[0].id)), "never from the first boss")
