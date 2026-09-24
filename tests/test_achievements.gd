extends BMTestCase
## Achievements (GDD §20): catalog integrity, conditions (trigger and no-trigger), the store
## (unlock once, meta badge, records) and that checks never change a run.

const EMPTY := ["........", "........", "........", "........", "........", "........", "........", "........"]


func _store() -> void:
	# The store's static vars initialize on its first static call; make that happen before
	# redirecting the path, or the initializer puts the real path back (the old flaky test).
	BMAchievementStore.reload()
	BMAchievementStore.path = "user://test_achievements_%d.cfg" % OS.get_process_id()
	if FileAccess.file_exists(BMAchievementStore.path):
		DirAccess.remove_absolute(BMAchievementStore.path)
	BMAchievementStore.reload()


func _restore() -> void:
	if FileAccess.file_exists(BMAchievementStore.path):
		DirAccess.remove_absolute(BMAchievementStore.path)
	BMAchievementStore.path = BMAchievementStore.PATH
	BMAchievementStore.reload()


func test_bag_achievements_count_the_bag() -> void:
	var run := BMRun.new_run(3)
	var got := BMAchievements.check_campaign(run, {"a": "reroll"}, {"ok": true, "type": "reroll"}, {})
	check(not got.has("blue_period"), "starter bag is not blue enough")
	check(not got.has("square_dance"), "starter bag has few squares")
	for i in 10:
		run.bag.append(BMPieces.make(100 + i, &"square2", 0, BMAchievements.BLUE))
	got = BMAchievements.check_campaign(run, {"a": "reroll"}, {"ok": true, "type": "reroll"}, {})
	check(got.has("blue_period"), "10 blue pieces")
	check(got.has("square_dance"), "10 squares")
	check(got.has("packrat") == (run.bag.size() >= 40), "packrat follows bag size")


func test_no_starter_bag_earns_a_bag_badge_for_free() -> void:
	for k in BMRunConfig.KITS:
		var run := BMRun.new_run(1, String(k.id))
		var got := BMAchievements.check_campaign(run, {"a": "x"}, {"ok": true, "type": "x"}, {})
		eq(got, [] as Array[String], "%s starts with no badge" % k.id)


func test_scoring_achievements_read_the_placement() -> void:
	var run := run_with(EMPTY, [shape(&"single")])
	var r := run.apply_action({"a": "place", "slot": 0, "x": 0, "y": 0})
	var got := BMAchievements.check_campaign(run, {"a": "place"}, r, {}, 14)
	check(not got.has("big_hit"), "a single is not a big hit")
	check(not got.has("first_line"), "no line yet")
	check(not got.has("night_shift"), "2 PM is not the night shift")
	got = BMAchievements.check_campaign(run, {"a": "place"}, {"ok": true, "type": "place", "points": 12000, "lines": 4,
		"rows": [1, 2], "cols": [3, 4], "combo_after": 4, "feats": ["clean_board"]}, {}, 3)
	for id in ["big_hit", "mega_hit", "first_line", "triple_decker", "four_alarm", "crossroads", "red_hot", "spotless", "night_shift"]:
		check(got.has(id), id)
	check(not got.has("giga_hit"), "12,000 is not a million")


func test_round_and_run_achievements() -> void:
	var run := BMRun.new_run(9)
	run.round_state.score = run.round_state.target * 3
	var r := run._after_round_action()
	r.ok = true
	var got := BMAchievements.check_campaign(run, {"a": "place"}, r, {})
	check(got.has("first_round"), "round won")
	check(got.has("overkill"), "three times the target")
	check(got.has("no_lines"), "won without a clear")
	check(got.has("speedrunner"), "zero placements")
	check(not got.has("champion"), "not the whole game")
	run.phase = BMRun.Phase.RUN_WON
	got = BMAchievements.check_campaign(run, {"a": "continue"}, {"ok": true, "type": "continue"}, {})
	check(got.has("champion"), "won the game")
	check(not got.has("kit_winner"), "standard kit")


func test_endless_achievements() -> void:
	var g := BMEndless.new_game(5)
	var got := BMAchievements.check_endless(g, {"ok": true, "type": "place"}, 12)
	check(got.is_empty(), "fresh game earns nothing")
	g.score = 30000
	g.best_combo = 10
	got = BMAchievements.check_endless(g, {"ok": true, "type": "place", "clean_board": true}, 1)
	for id in ["arcade_rookie", "arcade_regular", "blockstorm", "fresh_start", "night_shift"]:
		check(got.has(id), id)
	check(not got.has("arcade_legend"), "not 100k")


func test_store_unlocks_once_and_grants_the_meta_badge() -> void:
	_store()
	var fresh := BMAchievementStore.unlock(["first_line", "first_line", "nonsense"])
	eq(fresh, ["first_line"] as Array[String], "unlocked once, unknown ids ignored")
	eq(BMAchievementStore.unlock(["first_line"]).size(), 0, "already unlocked")
	BMAchievementStore.reload()
	check(BMAchievementStore.is_unlocked("first_line"), "persisted")
	check(BMAchievementStore.is_new("first_line"), "new until seen")
	BMAchievementStore.mark_seen(["first_line"])
	check(not BMAchievementStore.is_new("first_line"), "seen")
	var rest: Array = []
	for id in BMAchievements.ids():
		if id != "block_maniac":
			rest.append(id)
	fresh = BMAchievementStore.unlock(rest)
	check(fresh.has("block_maniac"), "meta badge follows the last one")
	_restore()


func test_records_keep_the_best() -> void:
	_store()
	var run := BMRun.new_run(2)
	run.round_number = 7
	run.stats.best_placement = 900
	run.stats["best_round_score"] = 2000
	var beaten := BMAchievementStore.record_run(run)
	eq(beaten.size(), 3, "first run sets three records")
	run.round_number = 5
	run.stats.best_placement = 1200
	beaten = BMAchievementStore.record_run(run)
	eq(beaten.size(), 1, "only the placement improved")
	eq(BMAchievementStore.records().furthest_round, 7, "furthest kept")
	run.machine_broken = true
	run.round_number = 40
	beaten = BMAchievementStore.record_run(run)
	eq(BMAchievementStore.records().machine_broken, 40, "machine record")
	run.round_number = 30
	BMAchievementStore.record_run(run)
	eq(BMAchievementStore.records().machine_broken, 30, "breaking it sooner is better")
	_restore()


func test_hands_seen_accumulate() -> void:
	_store()
	var run := BMRun.new_run(4)
	run.tray[0].hand = BMHands.TWINS
	BMAchievementStore.note_campaign(run)
	BMAchievementStore.note_campaign(run)
	eq(Array(BMAchievementStore.life().hands_seen).size(), 1, "counted once")
	var got := BMAchievements.check_campaign(run, {}, {"ok": true}, {"hands_seen": BMHands.ORDER})
	check(got.has("full_deck"), "all five")
	_restore()


func test_legend_page_achievements() -> void:
	_store()
	var run := BMRun.new_run(14)
	var none := BMAchievements.check_campaign(run, {"a": "x"}, {"ok": true, "type": "x"}, BMAchievementStore.life())
	for id in ["legend_found", "legend_pair", "pantheon", "wide_rack", "snowed_in", "heavy_metal", "fallen_hero"]:
		check(not none.has(id), "fresh run: no %s" % id)
	run.jokers.assign(["avalanche", "supernova", "snowball"])
	run.joker_state["snowball"] = 2.05
	run.extra_slots = 2
	for i in 15:
		run.bag[i].material = "chrome"
	BMAchievementStore.note_campaign(run)
	var got := BMAchievements.check_campaign(run, {"a": "x"}, {"ok": true, "type": "x"}, BMAchievementStore.life())
	for id in ["legend_found", "legend_pair", "wide_rack", "snowed_in", "heavy_metal"]:
		check(got.has(id), id)
	check(not got.has("pantheon"), "two of four seen")
	run.jokers.assign(["hall_of_mirrors", "philosophers_stone"])
	BMAchievementStore.note_campaign(run)
	got = BMAchievements.check_campaign(run, {"a": "x"}, {"ok": true, "type": "x"}, BMAchievementStore.life())
	check(got.has("pantheon"), "all four seen across runs")
	run.phase = BMRun.Phase.RUN_LOST
	got = BMAchievements.check_campaign(run, {"a": "x"}, {"ok": true, "type": "x"}, BMAchievementStore.life())
	check(got.has("fallen_hero"), "lost with a legend")
	_restore()


func test_legend_placement_achievements() -> void:
	var run := BMRun.new_run(15)
	run.jokers.assign(["hall_of_mirrors", "clean_sweep", "chain_link", "golden_ratio", "corner_office"])
	var items: Array = []
	for j in ["clean_sweep", "chain_link", "golden_ratio", "corner_office"]:
		items.append({"source": "joker", "joker": j, "kind": "chips", "value": 1})
		items.append({"source": "joker", "joker": j, "kind": "chips", "value": 1, "mirrored": true})
	var r := {"ok": true, "type": "place", "points": 2000000000, "lines": 1, "items": items, "waves": [{}, {}, {}]}
	var got := BMAchievements.check_campaign(run, {"a": "place"}, r, {})
	for id in ["mirror_world", "billionaire", "avalanche_chain"]:
		check(got.has(id), id)
	items.resize(6)
	var small := {"ok": true, "type": "place", "points": 900, "lines": 1, "items": items, "waves": [{}, {}]}
	got = BMAchievements.check_campaign(run, {"a": "place"}, small, {})
	for id in ["mirror_world", "billionaire", "avalanche_chain", "supernova_x10"]:
		check(not got.has(id), "no %s" % id)
	var nova := {"ok": true, "type": "place", "points": 5, "lines": 1,
		"items": [{"source": "joker", "joker": "supernova", "kind": "xmult", "value": 10.5}]}
	check(BMAchievements.check_campaign(run, {"a": "place"}, nova, {}).has("supernova_x10"), "x10.5 Supernova")


func test_max_interest_achievement() -> void:
	var run := BMRun.new_run(16)
	run.credits = 30
	run.round_state.score = run.round_state.target
	var r := run._after_round_action()
	r.ok = true
	check(BMAchievements.check_campaign(run, {"a": "place"}, r, {}).has("interest_rate"), "30 held: +5")
	var poor := BMRun.new_run(16)
	poor.credits = 10
	poor.round_state.score = poor.round_state.target
	var r2 := poor._after_round_action()
	r2.ok = true
	check(not BMAchievements.check_campaign(poor, {"a": "place"}, r2, {}).has("interest_rate"), "10 held: +2")
