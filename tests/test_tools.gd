extends BMTestCase
## Targeted items (Eraser, Punch, Color Purge, Lucky Paint, Blueprint, Emergency Brick) and the
## Patch Panel Joker (docs/design/round_play_update.md §3).

const EMPTY_ROWS := ["........", "........", "........", "........", "........", "........", "........", "........"]


func _with_item(rows: Array, item: String, tray: Array = [], jokers: Array = []) -> BMRun:
	var run := run_with(rows, tray if not tray.is_empty() else [shape(&"single")], jokers)
	run.consumables.assign([item])
	return run


func _all_uids_accounted(run: BMRun) -> bool:
	var seen := {}
	for uid in run.draw_pile + run.discard_pile:
		seen[int(uid)] = int(seen.get(int(uid), 0)) + 1
	for p in run.tray:
		if not p.is_empty() and int(p.uid) >= 0:
			seen[int(p.uid)] = int(seen.get(int(p.uid), 0)) + 1
	for p in run.bag:
		if int(seen.get(int(p.uid), 0)) != 1:
			return false
	return true


func test_eraser_removes_chosen_blocks_without_scoring() -> void:
	var run := _with_item(["11......", "........", "........", "........", "........", "........", "........", "..1....."], "eraser")
	var r := run.use_consumable(0, {"cells": [[0, 0], [2, 7]]})
	check(r.ok, "used")
	eq(r.removed.size(), 2, "two removed")
	check(run.board.is_empty(Vector2i(0, 0)) and run.board.is_empty(Vector2i(2, 7)), "cells emptied")
	check(not run.board.is_empty(Vector2i(1, 0)), "others stay")
	eq(run.round_state.score, 0, "no score")
	eq(run.consumables.size(), 0, "consumed")


func test_eraser_rejects_bad_targets_and_keeps_the_item() -> void:
	var run := _with_item(["1.......", "........", "........", "........", "........", "........", "........", "........"], "eraser")
	check(not run.use_consumable(0, {"cells": [[3, 3]]}).ok, "empty cell rejected")
	check(not run.use_consumable(0, {"cells": []}).ok, "needs a target")
	eq(run.consumables.size(), 1, "item kept")


func test_punch_hits_a_plus_shape() -> void:
	var run := _with_item(["........", ".111....", ".111....", ".111....", "........", "........", "........", "........"], "punch")
	var r := run.use_consumable(0, {"cells": [[2, 2]]})
	check(r.ok, "used")
	eq(r.removed.size(), 5, "plus shape")
	check(not run.board.is_empty(Vector2i(1, 1)), "diagonal corner stays")
	check(not run.use_consumable(0, {"cells": [[6, 6]]}).ok, "no second use")


func test_punch_needs_something_to_hit() -> void:
	var run := _with_item(["1.......", "........", "........", "........", "........", "........", "........", "........"], "punch")
	check(not run.use_consumable(0, {"cells": [[5, 5]]}).ok, "empty area rejected")


func test_color_purge_removes_one_color_and_ignores_stone() -> void:
	var run := _with_item(EMPTY_ROWS, "color_purge")
	run.board.set_cell(Vector2i(0, 0), BMShapes.COLOR_BLUE)
	run.board.set_cell(Vector2i(5, 5), BMShapes.COLOR_BLUE)
	run.board.set_cell(Vector2i(3, 3), BMShapes.COLOR_RED)
	run.board.set_cell(Vector2i(7, 7), BMShapes.COLOR_STONE)
	check(not run.use_consumable(0, {"color": BMShapes.COLOR_STONE}).ok, "stone is immune")
	var r := run.use_consumable(0, {"color": BMShapes.COLOR_BLUE})
	eq(r.removed.size(), 2, "both blue removed")
	check(not run.board.is_empty(Vector2i(3, 3)), "red stays")


func test_lucky_paint_recolors_a_tray_piece() -> void:
	var run := _with_item(EMPTY_ROWS, "lucky_paint", [shape(&"bar3", 0, BMShapes.COLOR_RED)])
	check(not run.use_consumable(0, {"slot": 0, "color": BMShapes.COLOR_RED}).ok, "same color rejected")
	check(run.use_consumable(0, {"slot": 0, "color": BMShapes.COLOR_BLUE}).ok, "used")
	eq(run.tray[0].color, BMShapes.COLOR_BLUE, "recolored")


func test_blueprint_swaps_in_a_temporary_piece_and_discards_the_old_one() -> void:
	var run := BMRun.new_run(8)
	run.consumables.assign(["blueprint"])
	var old_uid := int(run.tray[1].uid)
	var r := run.use_consumable(0, {"slot": 1, "choice": 4})
	check(r.ok, "used")
	eq(run.tray[1].family, &"bar3", "chosen family")
	check(bool(run.tray[1].temporary), "temporary")
	check(run.discard_pile.has(old_uid), "old piece discarded")
	check(_all_uids_accounted(run), "pile accounting holds")


func test_emergency_brick_fills_an_empty_slot() -> void:
	var run := _with_item(EMPTY_ROWS, "emergency_brick", [shape(&"bar3")])
	var r := run.use_consumable(0, {"slot": 2})
	check(r.ok, "used")
	check(bool(run.tray[2].brick), "brick in slot 3")
	eq(run.tray[2].cells.size(), 1, "one block")
	check(not r.has("smashed"), "nothing smashed")


func test_emergency_brick_smashes_a_piece_into_the_discard_pile() -> void:
	var run := BMRun.new_run(9)
	run.consumables.assign(["emergency_brick"])
	var hit_uid := int(run.tray[0].uid)
	var r := run.use_consumable(0, {"slot": 0})
	eq(int(r.smashed.uid), hit_uid, "reports the smashed piece")
	check(run.discard_pile.has(hit_uid), "smashed piece discarded")
	check(_all_uids_accounted(run), "pile accounting holds")
	var saved := BMRun.from_dict(JSON.parse_string(JSON.stringify(run.to_dict())))
	check(bool(saved.tray[0].brick), "brick survives save")


func test_board_tools_rescue_a_stuck_board() -> void:
	var rows := ["1111111.", "1111111.", "1111111.", "1111111.", "1111111.", "1111111.", "1111111.", "11111111"]
	var run := _with_item(rows, "eraser", [shape(&"square2")])
	run.round_state.refreshes_left = 0
	run._after_round_action()
	eq(run.round_state.status, BMRun.STUCK, "stuck, not lost: the eraser can help")
	run.use_consumable(0, {"cells": [[6, 5], [6, 6]]})
	eq(run.round_state.status, BMRun.PLAYING, "a spot opened")


func test_patch_panel_readies_after_the_first_clear_once_per_round() -> void:
	var run := run_with(["1111111.", "........", "........", "........", "........", "........", "1.......", "........"], [shape(&"single"), shape(&"single")], ["patch_panel"])
	check(not run.patch_cell(Vector2i(0, 6)).ok, "not ready before a clear")
	run.place(0, Vector2i(7, 0))
	check(run.round_state.patch_ready, "ready after the first clear")
	var r := run.patch_cell(Vector2i(0, 6))
	check(r.ok, "patched")
	check(run.board.is_empty(Vector2i(0, 6)), "block removed")
	check(not run.round_state.patch_ready, "spent")


func test_targeted_uses_replay_exactly() -> void:
	var run := BMRun.new_run(4242)
	run.consumables.assign(["emergency_brick", "eraser"])
	run.use_consumable(0, {"slot": 1})
	BMAutoplayer.step(run)
	var target := Vector2i(-1, -1)
	for y in BMBoard.SIZE:
		for x in BMBoard.SIZE:
			if not run.board.is_empty(Vector2i(x, y)) and target.x < 0:
				target = Vector2i(x, y)
	if target.x >= 0:
		run.use_consumable(0, {"cells": [[target.x, target.y]]})
	var again := BMRun.new_run(4242)
	again.consumables.assign(["emergency_brick", "eraser"])
	for a in run.history:
		again.apply_action(a)
	eq(again.to_dict(false), run.to_dict(false), "replay matches")
