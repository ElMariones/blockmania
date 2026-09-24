var m = get_tree().current_scene
m.settings.tips = false
m.toasts.visible = false
var bm_run := BMRun.new_run(17, "standard")
var bm_guard := 0
while bm_guard < STEPS and not (COND):
	var bm_r := BMAutoplayer.step(bm_run)
	bm_guard += 1
	if bm_r.is_empty():
		break
if JOKERS.size() > 0:
	bm_run.jokers.clear()
	for j in JOKERS:
		bm_run.jokers.append(j)
	bm_run.joker_state["snowball"] = 1.9
bm_run.credits = maxi(bm_run.credits, CREDITS)
BMSaveStore.save_run(bm_run)
m.continue_run()
m.game_screen.close_overlay()
await get_tree().create_timer(0.8).timeout
print("INFO round=", bm_run.round_number, " phase=", bm_run.phase, " placements=", bm_run.round_state.placements_made)
