extends BME2ECase
## Menus and settings end to end: every title popup opens and closes (Kit screen with Heat
## and seed, Daily, History, Trophy Case, high scores), every Options page renders, every
## segmented setting is clicked through all of its values and is saved to disk, RESET PAGE
## restores defaults, and Game speed changes time only on campaign screens. A seed typed on
## the Kit screen starts that exact run.


func run() -> void:
	var ts = main.title_screen
	# Title popups.
	for popup in ["_show_kit_picker", "_show_daily", "_show_history", "_show_high_scores"]:
		ts.call(popup)
		await frames(2)
		check(is_instance_valid(ts._highscore_overlay), popup + " opens")
		if popup == "_show_kit_picker":
			await screenshot("kit_picker")
		ts._close_high_scores()
		await frames(1)
		check(not is_instance_valid(ts._highscore_overlay) or ts._highscore_overlay.is_queued_for_deletion(), popup + " closes")
	ts._show_trophies()
	await frames(2)
	var tc := ts._highscore_overlay as BMTrophyCase
	check(tc != null, "the Trophy Case opens")
	if tc:
		tc.close()
	await frames(1)
	# Options: every page, every value of every segmented setting.
	main.show_options()
	await frames(2)
	var menu := main._pause.get_child(0) as BMSettingsMenu
	check(menu != null, "OPTIONS opens the settings menu")
	var clicked := 0
	for tab in ["game", "audio", "display", "access", "controls"]:
		menu.show_tab(tab)
		await frames(1)
		await screenshot("options_" + tab)
		for b in menu.find_children("Setting_*", "Button", true, false):
			var key := String(b.name).trim_prefix("Setting_")
			key = key.substr(0, key.rfind("_"))
			if key == "fullscreen":
				continue # a real window mode change; not meaningful headless
			if String(b.name).begins_with("Setting_language_"):
				continue # rebuilds every screen; scenario_languages covers it
			b.pressed.emit()
			await frames(1)
			clicked += 1
			var saved := BMSaveStore.load_settings()
			eq(str(saved.get(key)), str(main.settings.get(key)), "setting %s saved" % key)
			check(String(b.text).begins_with("* "), "the clicked value %s is marked as selected" % b.name)
	check(clicked >= 30, "clicked every setting value (%d)" % clicked)
	# RESET PAGE on Accessibility restores its defaults.
	menu.show_tab("access")
	main.settings.shake = "off"
	menu._reset_page()
	eq(BMSaveStore.load_settings().shake, BMSaveStore.default_settings().shake, "RESET PAGE restores defaults")
	main.close_pause()
	await frames(1)
	eq(main._pause.get_child_count(), 0, "BACK closes the menu")
	# Game speed: campaign screens only.
	main.set_setting("game_speed", "turbo")
	main.set_setting("tips", false)
	ts._show_kit_picker("31337")
	await frames(2)
	ts._start_campaign("standard")
	await frames(3)
	eq(main.run.run_seed, 31337, "the seed typed on the Kit screen starts that run")
	check(is_equal_approx(Engine.time_scale, 1.9), "Turbo speeds up the campaign (time scale %.2f)" % Engine.time_scale)
	main.show_pause()
	await frames(2)
	check(is_equal_approx(Engine.time_scale, 1.0), "the pause menu runs at normal speed")
	var pmenu := main._pause.get_child(0) as BMSettingsMenu
	eq(pmenu._tab, "run", "pausing a campaign opens the RUN page")
	await screenshot("pause_run")
	main.close_pause()
	main.start_endless()
	await frames(2)
	check(is_equal_approx(Engine.time_scale, 1.0), "Endless always runs at normal speed")
	main.set_setting("game_speed", "normal")
	main.show_title()
	await frames(2)
	facts = {"settings_clicked": clicked}
