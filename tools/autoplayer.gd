class_name BMAutoplayer
extends RefCounted
## Deterministic greedy bot for determinism tests and rough balance simulation.
## Not a player-facing feature. Heuristic: maximize lines cleared, then compactness
## (occupied orthogonal neighbours + board edges touched). Buys affordable Jokers left to right.


## Plays one action and returns its result, or {} if the run is over.
static func step(run: BMRun) -> Dictionary:
	match run.phase:
		BMRun.Phase.ROUND:
			return _round_step(run)
		BMRun.Phase.ROUND_RESULT:
			return run.continue_after_round()
		BMRun.Phase.SHOP:
			return _shop_step(run)
	return {}


## Plays until the run ends or `max_actions` is reached. Returns the run for chaining.
static func play(run: BMRun, max_actions: int = 5000) -> BMRun:
	for i in max_actions:
		var r := step(run)
		if r.is_empty():
			break
		if not r.ok:
			push_error("Autoplayer action failed: %s" % r.error)
			break
	return run


static func _round_step(run: BMRun) -> Dictionary:
	var rs := run.round_state
	if rs.status == BMRun.OUT_OF_PLACEMENTS:
		var i := run.consumables.find("extra_turn")
		return run.use_consumable(i) if i >= 0 else run.concede_round()
	if rs.status == BMRun.STUCK:
		if run.refreshes_available() > 0:
			return run.refresh()
		var st := run.consumables.find("second_tray")
		if st >= 0 and run.consumable_usable(st) == "":
			return run.use_consumable(st)
		return run.concede_round()
	for i in run.consumables.size():
		if run.consumables[i] in ["polish", "spark", "cash_out"]:
			return run.use_consumable(i)
	var best := {}
	var best_value := -1
	for slot in run.tray.size():
		var shape: Dictionary = run.tray[slot]
		if shape.is_empty():
			continue
		for anchor in run.board.legal_anchors(shape.cells):
			var v := evaluate(run.board, shape.cells, anchor)
			if v > best_value:
				best_value = v
				best = {"slot": slot, "anchor": anchor}
	return run.place(best.slot, best.anchor)


static func evaluate(board: BMBoard, cells: Array[Vector2i], anchor: Vector2i) -> int:
	var b := board.duplicate_board()
	var placed := b.place(cells, anchor, 0)
	var lines := b.full_rows().size() + b.full_cols().size()
	var touch := 0
	for p in placed:
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var q: Vector2i = p + d
			if not BMBoard.in_bounds(q):
				touch += 1
			elif board.get_cell(q) != BMBoard.EMPTY:
				touch += 2
	return lines * 1000 + touch * 10 + placed.size()


static func _shop_step(run: BMRun) -> Dictionary:
	for i in run.shop.jokers.size():
		var id: String = run.shop.jokers[i]
		if id != "" and run.credits >= BMJokers.cost(id) and run.jokers.size() < run.joker_slots():
			return run.buy_joker(i)
	for i in run.shop.consumables.size():
		var id: String = run.shop.consumables[i]
		if id != "" and run.credits >= BMConsumables.cost(id) + 3 and run.consumables.size() < BMRunConfig.CONSUMABLE_SLOTS:
			return run.buy_consumable(i)
	return run.leave_shop()
