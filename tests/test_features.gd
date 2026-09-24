extends BMTestCase
## GDD §22 (2026-09-24 plan items): campaign Hold, round cards, Heat, Mk II bosses, Joker
## unlocks, Daily seeds, milestones.

const EMPTY := ["........", "........", "........", "........", "........", "........", "........", "........"]


func _accounted(run: BMRun) -> bool:
	var seen := {}
	for uid in run.draw_pile + run.discard_pile:
		seen[int(uid)] = int(seen.get(int(uid), 0)) + 1
	var extra: Array = run.tray.duplicate()
	extra.append(run.round_state.held)
	for p in extra:
		if not p.is_empty() and int(p.uid) >= 0:
			seen[int(p.uid)] = int(seen.get(int(p.uid), 0)) + 1
	for p in run.bag:
		if int(seen.get(int(p.uid), 0)) != 1:
			return false
	return true


# --- Hold ------------------------------------------------------------------------------------

func test_hold_stores_a_piece_and_deals_a_replacement() -> void:
	var run := BMRun.new_run(101)
	var piece: Dictionary = run.tray[1]
	var r := run.apply_action({"a": "hold", "slot": 1})
	check(r.ok, "held")
	eq(int(run.round_state.held.uid), int(piece.uid), "stored")
	check(not run.tray[1].is_empty(), "the slot drew a new piece")
	check(_accounted(run), "every piece accounted for")
	check(not run.apply_action({"a": "hold", "slot": 0}).ok, "once between placements")


func test_hold_swaps_back_after_a_placement() -> void:
	var run := BMRun.new_run(102)
	run.round_state.target = 999999
	run.apply_action({"a": "hold", "slot": 0})
	var stored: Dictionary = run.round_state.held
	var s := 1 if not run.tray[1].is_empty() else 2
	var a: Vector2i = run.board.legal_anchors(run.tray[s].cells)[0]
	check(run.place(s, a).ok, "placed")
	check(not run.round_state.hold_used, "recharged")
	var target := 0 if not run.tray[0].is_empty() else s
	var out: Dictionary = run.tray[target]
	check(run.apply_action({"a": "hold", "slot": target}).ok, "swap")
	eq(int(run.tray[target].uid), int(stored.uid), "stored piece back in the tray")
	eq(int(run.round_state.held.get("uid", -99)), int(out.get("uid", -99)), "the other one stored")
	check(_accounted(run), "accounted")


func test_hold_survives_save_and_clears_next_round() -> void:
	var run := BMRun.new_run(103)
	run.apply_action({"a": "hold", "slot": 2})
	var copy := BMRun.from_dict(JSON.parse_string(JSON.stringify(run.to_dict())))
	eq(int(copy.round_state.held.uid), int(run.round_state.held.uid), "saved")
	check(copy.round_state.hold_used, "used flag saved")
	run.round_state.score = run.round_state.target
	run._after_round_action()
	run.continue_after_round()
	run.leave_shop()
	check(run.round_state.held.is_empty(), "a new round starts with an empty Hold")
	check(_accounted(run), "the held piece went back to the bag")


func test_a_fitting_held_piece_keeps_the_round_alive() -> void:
	var run := run_with(EMPTY, [shape(&"plus5"), {}, {}])
	run.board.cells.fill(1)
	run.board.set_cell(Vector2i(0, 0), BMBoard.EMPTY)
	run.round_state.held = shape(&"single")
	run.round_state.refreshes_left = 0
	run._after_round_action()
	eq(run.phase, BMRun.Phase.ROUND, "not lost")
	eq(run.round_state.status, BMRun.PLAYING, "playing: swap it in")
	check(run.apply_action({"a": "hold", "slot": 0}).ok, "swap")
	check(run.place(0, Vector2i(0, 0)).ok, "the held Single fits")


func test_lockdown_mk2_disables_hold() -> void:
	var run := BMRun.new_run(104)
	run.bosses[1] = "lockdown"
	run.round_number = 8
	run._start_round()
	check(run.boss_is_mk2(), "act 2 boss is Mk II")
	check(not run.apply_action({"a": "hold", "slot": 0}).ok, "no Hold")


# --- Round cards -----------------------------------------------------------------------------

func _shop(seed_value: int, round_n: int = 1) -> BMRun:
	var run := BMRun.new_run(seed_value)
	run.round_number = round_n
	run._start_round()
	run.round_state.score = run.round_state.target
	run._after_round_action()
	run.continue_after_round()
	return run


func test_shop_offers_standard_plus_two_twists() -> void:
	var run := _shop(110)
	var cards: Array = run.shop.round_cards
	eq(cards.size(), 3, "three cards")
	eq(cards[0], "standard", "standard first")
	check(cards[1] != cards[2] and cards[1] != "standard", "two different twists")
	var boss_shop := _shop(111, 3)
	eq(Array(boss_shop.shop.round_cards).size(), 0, "no choice before a boss")


func test_picking_a_card_changes_the_round() -> void:
	var run := _shop(112)
	run.shop.round_cards = ["standard", "tight_budget", "double_or_nothing"]
	check(run.apply_action({"a": "pick_round", "i": 2}).ok, "picked")
	run.leave_shop()
	eq(run.round_card, "double_or_nothing", "applied")
	eq(run.round_state.target, run.round_target(2, "double_or_nothing"), "target x1.4")
	check(run.round_state.target > BMRunConfig.target(2), "harder")
	run.round_state.score = run.round_state.target
	run._after_round_action()
	var bonus := 0
	for l in run.last_round_result.credit_lines:
		if String(l.label).begins_with("Double or Nothing"):
			bonus = int(l.value)
	eq(bonus, 6, "+6 Credits")


func test_tight_budget_rush_hour_and_gold_rush() -> void:
	var tight := _shop(113)
	tight.shop.round_cards = ["standard", "tight_budget", "rush_hour"]
	tight.apply_action({"a": "pick_round", "i": 1})
	tight.leave_shop()
	eq(tight.round_state.placements_left, int(tight.kit().placements) - 3, "three fewer")
	var rush := _shop(113)
	rush.shop.round_cards = ["standard", "tight_budget", "rush_hour"]
	rush.apply_action({"a": "pick_round", "i": 2})
	rush.leave_shop()
	eq(rush.refreshes_available(), 0, "no Refresh")
	var gold := _shop(114)
	gold.shop.round_cards = ["standard", "gold_rush", "rush_hour"]
	gold.apply_action({"a": "pick_round", "i": 1})
	gold.leave_shop()
	var golds := 0
	for i in BMBoard.SIZE * BMBoard.SIZE:
		if gold.board.mats[i] == BMPieces.material_index("gold") and gold.board.cells[i] != BMBoard.EMPTY:
			golds += 1
	eq(golds, 6, "six Gold blocks")
	eq(gold.board.full_rows().size() + gold.board.full_cols().size(), 0, "no full line")


func test_mult_fever_adds_mult() -> void:
	var run := run_with(EMPTY, [shape(&"single")])
	run.round_card = "mult_fever"
	run.round_state.target = 999999
	var r := run.place(0, Vector2i(0, 0))
	eq(r.mult, 2.0, "+1 Mult")


# --- Heat ------------------------------------------------------------------------------------

func test_heat_levels_stack() -> void:
	var h0 := BMRun.new_run(120)
	var h2 := BMRun.new_run(120, "standard", 2)
	var h5 := BMRun.new_run(120, "standard", 5)
	check(h2.round_state.target > h0.round_state.target, "heat 1+: bigger target")
	eq(h2.round_state.placements_left, h0.round_state.placements_left - 1, "heat 2: one fewer placement")
	eq(h5.round_state.refreshes_left, h0.round_state.refreshes_left - 1, "heat 5: one fewer Refresh")
	check(h5.round_state.target > h2.round_state.target, "heat 5: +35%")
	var h4 := BMRun.new_run(121, "standard", 4)
	check(h4.boss_is_mk2(1), "heat 4: act 1 boss is Mk II")
	check(not h0.boss_is_mk2(1), "heat 0: act 1 boss is normal")
	var copy := BMRun.from_dict(JSON.parse_string(JSON.stringify(h5.to_dict())))
	eq(copy.heat, 5, "saved")


func test_heat_three_caps_interest() -> void:
	var run := BMRun.new_run(122, "standard", 3)
	run.credits = 60
	run.round_state.score = run.round_state.target
	run._after_round_action()
	eq(int(run.last_round_result.interest), BMRunConfig.HEAT_INTEREST_CAP, "capped at 3")


# --- Mk II bosses ----------------------------------------------------------------------------

func _boss_round(boss: String, act_n: int, seed_value: int = 130) -> BMRun:
	var run := BMRun.new_run(seed_value)
	run.bosses[act_n - 1] = boss
	run.round_number = act_n * BMRunConfig.ROUNDS_PER_ACT
	run._start_round()
	return run


func test_mk2_bosses_are_harder() -> void:
	eq(_boss_round("cramped_cabinet", 1).round_state.fixed_cells.size(), 4, "act 1: four cells")
	eq(_boss_round("cramped_cabinet", 2).round_state.fixed_cells.size(), 7, "act 2: seven cells")
	var w := _boss_round("warden", 2)
	check(w.round_state.locked_slot >= 0 and w.round_state.locked_slot2 >= 0 and w.round_state.locked_slot != w.round_state.locked_slot2, "two barred slots")
	var cb1 := _boss_round("color_blind", 1)
	var cb2 := _boss_round("color_blind", 2)
	eq(cb2.round_state.placements_left, cb1.round_state.placements_left - 2, "two fewer placements")
	var lc := _boss_round("last_call", 3)
	eq(lc.round_state.placements_left, BMBosses.LAST_CALL_PLACEMENTS, "final boss normal before Overtime")
	eq(BMBosses.title("warden", true), "The Warden Mk II", "title")


func test_taxman_mk2_taxes_harder() -> void:
	var run := _boss_round("taxman", 2)
	run.board = board_from(["1111111.", "........", "........", "........", "........", "........", "........", "........"])
	run.tray[0] = shape(&"single")
	run.round_state.target = 999999
	var r := run.place(0, Vector2i(7, 0))
	eq(r.chips, 10 + BMBosses.TAXMAN_FIRST_LINE_CHIPS_MK2, "first line 30")


# --- Joker unlocks, Daily, milestones --------------------------------------------------------

func test_locked_jokers_are_never_offered() -> void:
	var locked := BMJokers.locked_for({})
	check(locked.has("snowball") and locked.has("avalanche"), "fresh profile locks them")
	eq(BMJokers.locked_for({"champion": 1}).has("avalanche"), false, "a win unlocks the Legendaries")
	var run := BMRun.new_run(140, "standard", 0, locked)
	for i in 300:
		check(not locked.has(run._pick_joker(i % 3, [])), "offer %d" % i)
	var copy := BMRun.from_dict(JSON.parse_string(JSON.stringify(run.to_dict())))
	eq(copy.locked_jokers.size(), locked.size(), "saved")


func test_milestones_fire_once_per_tier() -> void:
	var run := run_with(EMPTY, [shape(&"single"), shape(&"single")])
	run.round_state.target = BMRunConfig.SCORE_CAP
	run.round_state.pending_mult = 199999.0
	var r := run.place(0, Vector2i(0, 0))
	eq(int(r.milestone), 1, "a 2M placement: tier 1")
	run.round_state.pending_mult = 199999.0
	r = run.place(1, Vector2i(3, 3))
	eq(int(r.milestone), 0, "already reached")
