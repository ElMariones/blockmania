extends BMTestCase
## Engine update (2026-09-24, docs/playtests/2026-09-24_persona_playtest.md): multi-line base
## Mult, interest and overkill payouts, Rack Extender, run-long scaling Jokers, the new Jokers
## and items. Every card gets a trigger and a no-trigger check.

const EMPTY := ["........", "........", "........", "........", "........", "........", "........", "........"]
const ONE_ROW := ["1111111.", "........", "........", "........", "........", "........", "........", "........"]
const CROSS := [".......1", ".......1", ".......1", ".......1", ".......1", ".......1", ".......1", "1111111."]


func _place(rows: Array, s: Dictionary, anchor: Vector2i, jokers: Array, setup: Callable = Callable()) -> Dictionary:
	var run := run_with(rows, [s], jokers)
	run.round_state.target = 999999
	if setup.is_valid():
		setup.call(run)
	return run.place(0, anchor)


func _value(r: Dictionary, id: String) -> Variant:
	for it in r.items:
		if it.get("joker", "") == id:
			return it.value
	return null


func _item(r: Dictionary, label_start: String) -> Variant:
	for it in r.items:
		if String(it.label).begins_with(label_start):
			return it.value
	return null


func _win(run: BMRun, score_ratio: float = 1.0) -> void:
	run.round_state.score = int(run.round_state.target * score_ratio)
	run._after_round_action()


# --- Base rules and economy ---------------------------------------------------------------

func test_multi_line_adds_base_mult() -> void:
	var r := _place(CROSS, shape(&"single"), Vector2i(7, 7), [])
	eq(r.lines, 2, "two lines")
	eq(_item(r, "Multi-line Mult"), 1.0, "+1 Mult for the second line")
	eq(r.mult, 2.0, "base Mult 2")
	var one := _place(ONE_ROW, shape(&"single"), Vector2i(7, 0), [])
	eq(_item(one, "Multi-line Mult"), null, "a single line adds no Mult")


func test_interest_pays_one_per_five_held_up_to_five() -> void:
	var run := BMRun.new_run(5)
	run.credits = 17
	_win(run)
	eq(int(run.last_round_result.interest), 3, "17 held -> +3")
	run = BMRun.new_run(5)
	run.credits = 60
	_win(run)
	eq(int(run.last_round_result.interest), BMRunConfig.INTEREST_CAP, "capped")
	run = BMRun.new_run(5)
	run.credits = 4
	_win(run)
	eq(int(run.last_round_result.interest), 0, "under five: nothing")


func test_overkill_pays_for_big_finishes() -> void:
	var run := BMRun.new_run(6)
	_win(run, 2.1)
	eq(int(run.last_round_result.overkill), 2, "2.1x target: two half-targets beyond")
	run = BMRun.new_run(6)
	_win(run, 1.3)
	eq(int(run.last_round_result.overkill), 0, "1.3x: nothing")
	run = BMRun.new_run(6)
	_win(run, 9.0)
	eq(int(run.last_round_result.overkill), BMRunConfig.OVERKILL_CAP, "capped")


func test_rack_extender_adds_a_slot_up_to_seven() -> void:
	var run := BMRun.new_run(7)
	_win(run)
	run.continue_after_round()
	run.credits = 99
	run.shop.tools = [{"id": "rack_extender", "family": ""}, {"id": "rack_extender", "family": ""}]
	check(run.buy_tool(0).ok, "bought")
	eq(run.joker_slots(), 6, "5 + 1")
	check(run.buy_tool(1).ok, "bought again")
	eq(run.joker_slots(), 7, "7")
	run.shop.tools = [{"id": "rack_extender", "family": ""}]
	check(not run.buy_tool(0).ok, "no eighth slot")
	var copy := BMRun.from_dict(JSON.parse_string(JSON.stringify(run.to_dict())))
	eq(copy.joker_slots(), 7, "saved")


# --- Scaling Jokers ------------------------------------------------------------------------

func test_snowball_grows_on_multi_line_and_persists() -> void:
	var run := run_with(CROSS, [shape(&"single"), shape(&"single")], ["snowball"])
	run.round_state.target = 999999
	var r := run.place(0, Vector2i(7, 7))
	eq(_value(r, "snowball"), null, "x1 scores nothing yet")
	check(is_equal_approx(run.joker_value("snowball"), 1.15), "grew to x1.15")
	run.board = board_from(ONE_ROW)
	r = run.place(1, Vector2i(7, 0))
	check(is_equal_approx(float(_value(r, "snowball")), 1.15), "applies x1.15")
	check(is_equal_approx(run.joker_value("snowball"), 1.15), "one line: no growth")
	var copy := BMRun.from_dict(JSON.parse_string(JSON.stringify(run.to_dict())))
	check(is_equal_approx(copy.joker_value("snowball"), 1.15), "saved")


func test_selling_the_last_copy_forgets_the_growth() -> void:
	var run := run_with(EMPTY, [shape(&"single")], ["snowball", "snowball"])
	run.joker_state["snowball"] = 2.0
	run.sell_joker(0)
	check(is_equal_approx(run.joker_value("snowball"), 2.0), "a copy remains")
	run.sell_joker(0)
	check(not run.joker_state.has("snowball"), "forgotten")


func test_hot_streak_heats_on_clean_wins_and_resets_on_refresh() -> void:
	var run := BMRun.new_run(8)
	run.jokers.assign(["hot_streak"])
	_win(run)
	check(is_equal_approx(run.joker_value("hot_streak"), 1.3), "clean win: x1.3")
	run.continue_after_round()
	run.leave_shop()
	check(run.refresh().ok, "refresh")
	eq(run.joker_value("hot_streak"), 1.0, "reset by the Refresh")
	_win(run)
	eq(run.joker_value("hot_streak"), 1.0, "a round with a Refresh does not heat it")


func test_overachiever_grows_on_big_rounds() -> void:
	var run := BMRun.new_run(9)
	run.jokers.assign(["overachiever"])
	_win(run, 1.2)
	eq(run.joker_value("overachiever"), 0.0, "1.2x: no")
	run.continue_after_round()
	run.leave_shop()
	_win(run, 1.6)
	eq(run.joker_value("overachiever"), 1.0, "1.6x: +1 Mult")
	var r := _place(EMPTY, shape(&"single"), Vector2i(0, 0), ["overachiever"], func(x: BMRun) -> void: x.joker_state["overachiever"] = 3.0)
	eq(_value(r, "overachiever"), 3.0, "applies +3")


# --- New Jokers: trigger and no-trigger -----------------------------------------------------

func test_tally_counter_and_bonsai_read_the_run() -> void:
	var r := _place(EMPTY, shape(&"single"), Vector2i(0, 0), ["tally_counter", "bonsai"], func(x: BMRun) -> void:
		x.stats.lines_cleared = 10
		x.stats.rounds_won = 4)
	eq(_value(r, "tally_counter"), 40, "10 lines x 4")
	check(is_equal_approx(float(_value(r, "bonsai")), 1.4), "4 rounds x 0.35")
	var fresh := _place(EMPTY, shape(&"single"), Vector2i(0, 0), ["tally_counter", "bonsai"])
	eq(_value(fresh, "tally_counter"), null, "no lines yet")
	eq(_value(fresh, "bonsai"), null, "no rounds yet")


func test_coin_pusher_and_full_pockets() -> void:
	var r := _place(EMPTY, shape(&"single"), Vector2i(0, 0), ["coin_pusher", "full_pockets"], func(x: BMRun) -> void:
		x.credits = 23
		x.consumables.assign(["polish", "spark"]))
	check(is_equal_approx(float(_value(r, "coin_pusher")), 2.3), "23 Credits")
	eq(_value(r, "full_pockets"), 3.0, "two items")
	var rich := _place(EMPTY, shape(&"single"), Vector2i(0, 0), ["coin_pusher"], func(x: BMRun) -> void: x.credits = 90)
	eq(_value(rich, "coin_pusher"), 5.0, "capped at +5")
	var broke := _place(EMPTY, shape(&"single"), Vector2i(0, 0), ["coin_pusher", "full_pockets"])
	eq(_value(broke, "coin_pusher"), null, "no Credits")
	eq(_value(broke, "full_pockets"), null, "no items")


func test_big_game_hunter() -> void:
	eq(_value(_place(EMPTY, shape(&"square3"), Vector2i(0, 0), ["big_game_hunter"]), "big_game_hunter"), 5.0, "9 blocks: +5")
	eq(_value(_place(EMPTY, shape(&"bar4"), Vector2i(0, 0), ["big_game_hunter"]), "big_game_hunter"), null, "4 blocks: nothing")


func test_rainbow_road_needs_all_six_colors() -> void:
	var rainbow := ["012345..", "........", "........", "........", "........", "........", "........", "........"]
	eq(_value(_place(rainbow, shape(&"single"), Vector2i(0, 7), ["rainbow_road"]), "rainbow_road"), 1.75, "six colors")
	var five := ["01234...", "........", "........", "........", "........", "........", "........", "........"]
	eq(_value(_place(five, shape(&"single"), Vector2i(0, 7), ["rainbow_road"]), "rainbow_road"), null, "five colors")


func test_solo_act_counts_empty_slots() -> void:
	eq(_value(_place(EMPTY, shape(&"single"), Vector2i(0, 0), ["solo_act"]), "solo_act"), 4.0, "4 empty slots: x1 + 3")
	var full := ["solo_act", "clean_sweep", "clean_sweep", "clean_sweep", "clean_sweep"]
	eq(_value(_place(EMPTY, shape(&"single"), Vector2i(0, 0), full), "solo_act"), null, "rack full: x1")


func test_demolition_crew_pays_per_block_cleared() -> void:
	eq(_value(_place(ONE_ROW, shape(&"single"), Vector2i(7, 0), ["demolition_crew"]), "demolition_crew"), 120, "8 blocks x 15")
	eq(_value(_place(EMPTY, shape(&"single"), Vector2i(0, 0), ["demolition_crew"]), "demolition_crew"), null, "no clear")


func test_double_stamp_doubles_stamps() -> void:
	var enc := shape(&"single")
	enc.stamp = "encore"
	var r := _place(ONE_ROW, enc, Vector2i(7, 0), ["double_stamp"])
	eq(_item(r, "Encore Stamp"), 4.0, "Encore x4")
	var plain := _place(ONE_ROW, enc, Vector2i(7, 0), [])
	eq(_item(plain, "Encore Stamp"), 2.0, "without it: x2")
	var tip := shape(&"single")
	tip.stamp = "tip"
	var run := run_with(EMPTY, [tip], ["double_stamp"])
	var before := run.credits
	run.place(0, Vector2i(0, 0))
	eq(run.credits - before, 2 * BMPieces.TIP_CREDITS, "Tip twice")


func test_vending_machine_drops_an_item_on_a_win() -> void:
	var run := BMRun.new_run(10)
	run.jokers.assign(["vending_machine"])
	_win(run)
	eq(run.consumables.size(), 1, "one item dropped")
	eq(Array(run.last_round_result.drops).size(), 1, "reported")
	var full := BMRun.new_run(10)
	full.jokers.assign(["vending_machine"])
	full.consumables.assign(["polish", "spark"])
	_win(full)
	eq(full.consumables, ["polish", "spark"] as Array[String], "no free slot: nothing")


# --- New items ------------------------------------------------------------------------------

func test_overclock_doubles_the_next_placement_only() -> void:
	var run := run_with(EMPTY, [shape(&"single"), shape(&"single")])
	run.round_state.target = 99999
	run.consumables.assign(["overclock"])
	check(run.use_consumable(0).ok, "used")
	var r := run.place(0, Vector2i(0, 0))
	eq(_item(r, "Turbo"), 2.0, "x2")
	eq(r.points, 20, "10 Chips x 2")
	r = run.place(1, Vector2i(3, 3))
	eq(_item(r, "Turbo"), null, "gone after one placement")


func test_tune_up_levels_a_tray_family() -> void:
	var run := run_with(EMPTY, [shape(&"bar3"), {}, {}])
	run.consumables.assign(["tune_up"])
	check(not run.use_consumable(0, {"slot": 1}).ok, "an empty slot is refused")
	var r := run.use_consumable(0, {"slot": 0})
	check(r.ok, "used")
	eq(run.family_level(&"bar3"), 1, "Bar 3 Lv 1")


func test_coffee_break_and_coin_roll() -> void:
	var run := BMRun.new_run(11)
	run.consumables.assign(["coffee_break", "coin_roll"])
	var refreshes := run.round_state.refreshes_left
	check(run.use_consumable(0).ok, "coffee")
	eq(run.round_state.refreshes_left, refreshes + 1, "+1 Refresh")
	var before := run.credits
	check(run.use_consumable(0).ok, "coins")
	eq(run.credits - before, 1, "round 1: +1")
	var locked := BMRun.new_run(12)
	locked.bosses[0] = "lockdown"
	locked.round_number = 4
	locked._start_round()
	locked.consumables.assign(["coffee_break"])
	check(locked.consumable_usable(0) != "", "The Lockdown refuses it")
