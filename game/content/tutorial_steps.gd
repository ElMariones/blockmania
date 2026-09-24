class_name BMTutorialSteps
extends RefCounted
## The first-session tutorial (GDD §23): what POPS says, what he points at, and what moves the
## tour on. Presentation only; conditions read the run, never change it.
##
## screen   "round" or "shop": the step waits until that screen is up (round steps are skipped
##          if the round ends first; the goodbye waits for the next round)
## target   a control id the screen resolves with tutorial_rect(id), or "" for none
## advance  "next"      the NEXT button
##          "placed"    a piece was placed since the step began
##          "cleared"   a line was cleared since the step began (or five more placements)
##          "shop"      the shop opened
##          "left_shop" the next round started
## pose     "talk" (default), "happy"; a step with a target makes POPS point at it

const STEPS := [
	{"id": "hello", "screen": "round", "target": "", "advance": "next", "pose": "happy",
		"text": "Well hello there! I'm POPS. I've kept this arcade running since blocks were square. Want the grand tour?"},
	{"id": "tray", "screen": "round", "target": "tray", "advance": "next",
		"text": "These three are your tray: pieces drawn from your very own bag."},
	{"id": "place", "screen": "round", "target": "board", "advance": "placed",
		"text": "Drag one onto the board, or click it and then a cell. Go on, place a piece!"},
	{"id": "receipt", "screen": "round", "target": "receipt", "advance": "next", "pose": "happy",
		"text": "Nice! Every placement scores CHIPS x MULT, and the receipt shows the sums. No secrets here."},
	{"id": "clear", "screen": "round", "target": "board", "advance": "cleared",
		"text": "Now fill a whole row or column. It clears, pays big, and gives you a placement back!"},
	{"id": "target", "screen": "round", "target": "score", "advance": "next",
		"text": "Reach the target up here before the lamps run out. Each lamp is one placement."},
	{"id": "refresh", "screen": "round", "target": "refresh", "advance": "next",
		"text": "Bad tray? REFRESH swaps all three pieces. Only once a round, so pick your moment."},
	{"id": "hold", "screen": "round", "target": "hold", "advance": "next",
		"text": "HOLD keeps one piece for later. Drop a piece on it, or press H."},
	{"id": "jokers", "screen": "round", "target": "jokers", "advance": "next",
		"text": "Jokers live here. They add Chips and Mult to every placement. You buy them in the shop."},
	{"id": "play", "screen": "round", "target": "", "advance": "shop", "pose": "happy",
		"text": "That's the basics! Hit the target and I'll meet you in the shop."},
	{"id": "shop", "screen": "shop", "target": "shop_jokers", "advance": "next", "pose": "happy",
		"text": "Welcome to the Toybox! Spend your Credits on Jokers here."},
	{"id": "workshop", "screen": "shop", "target": "shop_tools", "advance": "next",
		"text": "Workshop cards change the pieces in your bag: paint them, copy them, make them shiny."},
	{"id": "next_round", "screen": "shop", "target": "next_round", "advance": "left_shop",
		"text": "Ready? Press NEXT ROUND. You even get to pick how hard it is."},
	{"id": "bye", "screen": "round", "target": "", "advance": "next", "pose": "happy",
		"text": "You're a natural! Every fourth round a boss shows up, so read its rule. Have fun!"},
]
## Tips (BMTips) that repeat what POPS already said; marked seen when the tour is finished.
const COVERED_TIPS := ["welcome", "score", "hold", "shop", "round_cards"]


static func ids() -> Array:
	var out: Array = []
	for s in STEPS:
		out.append(String(s.id))
	return out


static func index_of(id: String) -> int:
	for i in STEPS.size():
		if STEPS[i].id == id:
			return i
	return -1


static func first_on(screen: String, after: int = -1) -> int:
	for i in range(after + 1, STEPS.size()):
		if STEPS[i].screen == screen:
			return i
	return -1
