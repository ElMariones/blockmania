extends BMTestCase
## Which UI language the game starts in (BMLoc.resolve_with): the in-game setting, the language
## the player chose for the game in Steam, the OS language, English. The E2E suite never runs
## with Steam, so this is only checked here.
##
## Written before the code, from this list of ways it could fail:
##  F1 Steam's "latam" (Latin American Spanish) is not recognised and the game falls to English.
##  F2 Steam's "brazilian" or "portuguese" maps to nothing (the game ships pt_BR only).
##  F3 Simplified and Traditional Chinese are swapped ("schinese" / "tchinese").
##  F4 The Steam choice is ignored: Japanese chosen in Steam, English OS -> English game.
##  F5 The Steam choice overrides a language the player picked in the game's own Settings.
##  F6 A Steam language the game does not ship ("russian") gives an empty or broken language
##     instead of falling back to the OS language, then English.
##  F7 Without Steam the OS language no longer works.
##  F8 A shipped language cannot be reached from any Steam language, so the store would claim a
##     language the Steam dropdown cannot select.


func test_steam_codes_map_to_shipped_languages() -> void:
	eq(BMLoc.resolve_with("auto", "latam", "en_US"), "es", "F1: latam -> Spanish")
	eq(BMLoc.resolve_with("auto", "spanish", "en_US"), "es", "spanish -> Spanish")
	eq(BMLoc.resolve_with("auto", "brazilian", "en_US"), "pt_BR", "F2: brazilian -> pt_BR")
	eq(BMLoc.resolve_with("auto", "portuguese", "en_US"), "pt_BR", "F2: portuguese -> pt_BR")
	eq(BMLoc.resolve_with("auto", "schinese", "en_US"), "zh_CN", "F3: schinese -> Simplified")
	eq(BMLoc.resolve_with("auto", "tchinese", "en_US"), "zh_TW", "F3: tchinese -> Traditional")


func test_steam_choice_beats_os_but_not_the_setting() -> void:
	eq(BMLoc.resolve_with("auto", "japanese", "en_US"), "ja", "F4: Steam's Japanese wins over an English OS")
	eq(BMLoc.resolve_with("auto", "english", "de_DE"), "en", "F4: Steam's English wins over a German OS")
	eq(BMLoc.resolve_with("fr", "japanese", "de_DE"), "fr", "F5: the in-game choice wins")


func test_fallbacks() -> void:
	eq(BMLoc.resolve_with("auto", "russian", "pl_PL"), "pl", "F6: unshipped Steam language -> OS language")
	eq(BMLoc.resolve_with("auto", "russian", "ru_RU"), "en", "F6: ... then English")
	eq(BMLoc.resolve_with("auto", "", "nl_NL"), "nl", "F7: no Steam -> OS language")
	eq(BMLoc.resolve_with("auto", "", "zh_Hant_TW"), "zh_TW", "F7: Traditional Chinese OS")


func test_every_shipped_language_is_selectable_in_steam() -> void:
	for entry in BMLoc.LANGUAGES:
		var code: String = entry[0]
		var found := false
		for api in BMLoc.STEAM_CODES:
			if BMLoc.STEAM_CODES[api] == code:
				found = true
		check(found, "F8: %s has a Steam language" % code)
