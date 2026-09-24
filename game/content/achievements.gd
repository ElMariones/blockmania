class_name BMAchievements
extends RefCounted
## Achievement catalog and unlock conditions (GDD §20). Stable string ids: saved in
## user://achievements.cfg, never rename casually. Checks only read state and action results;
## they never change a run, a score or any random stream.
##
## `tier`: bronze | silver | gold | legend (fanfare, frame and particles scale with it).
## `secret`: the name and rule stay hidden ("???" and a cryptic `hint`) until unlocked.
## `page`: Trophy Case page (0-4), twelve badges each, in catalog order.

const TIERS := ["bronze", "silver", "gold", "legend"]
const TIER_NAMES := {"bronze": "Bronze", "silver": "Silver", "gold": "Gold", "legend": "Legendary"}
const PAGE_TITLES := ["THE CAMPAIGN", "THE BAG & THE SHOP", "THE SCOREBOARD", "ARCADE & SECRETS", "LEGENDS"]
const PER_PAGE := 12

const BLUE := 4 ## BMShapes color index
const RECORD_KEYS := ["furthest_round", "best_placement", "best_round_score", "machine_broken"]

const CATALOG := [
	# --- Page 1: the campaign ---
	{"id": "first_line", "page": 0, "tier": "bronze", "name": "First Crack", "text": "Clear your first line.", "flavor": "It's a start. A very satisfying start."},
	{"id": "first_round", "page": 0, "tier": "bronze", "name": "Warmed Up", "text": "Win a round.", "flavor": "The target never stood a chance."},
	{"id": "boss_buster", "page": 0, "tier": "bronze", "name": "Boss Buster", "text": "Defeat a boss.", "flavor": "They always look bigger on the poster."},
	{"id": "second_act", "page": 0, "tier": "bronze", "name": "Second Act", "text": "Reach Act 2 (round 5).", "flavor": "Intermission is over. Back to your seats."},
	{"id": "final_act", "page": 0, "tier": "silver", "name": "Final Act", "text": "Reach Act 3 (round 9).", "flavor": "The curtain is starting to twitch."},
	{"id": "speedrunner", "page": 0, "tier": "silver", "name": "Speedrunner", "text": "Win a round in five placements or fewer.", "flavor": "Blink and you missed it."},
	{"id": "champion", "page": 0, "tier": "gold", "name": "BLOCKMANIA!", "text": "Beat the game: win round 12.", "flavor": "Twelve rounds, three bosses, one very full board."},
	{"id": "kit_winner", "page": 0, "tier": "gold", "name": "Different Tools", "text": "Beat the game with any Kit other than the Standard Kit.", "flavor": "A good builder never blames the Kit."},
	{"id": "overtime", "page": 0, "tier": "silver", "name": "Overtime", "text": "Win a round in Overtime (after beating the game, keep playing).", "flavor": "The arcade was supposed to close an hour ago."},
	{"id": "sudden_death", "page": 0, "tier": "gold", "name": "Sudden Death", "text": "Reach round 20 in Overtime.", "flavor": "Every target is a cliff now."},
	{"id": "no_off_switch", "page": 0, "tier": "legend", "name": "No Off Switch", "text": "Reach round 30 in Overtime.", "flavor": "Somebody unplug this thing."},
	{"id": "broke_machine", "page": 0, "tier": "legend", "secret": true, "name": "Broke the Machine", "text": "Score a single placement past the machine's limit (1,000,000,000,000,000 points).", "hint": "Some scores are too big for any machine.", "flavor": "ERR ERR ERR. Please insert more digits."},
	# --- Page 2: the bag and the shop ---
	{"id": "blue_period", "page": 1, "tier": "silver", "name": "Blue Period", "text": "Have 10 or more blue pieces in your bag.", "flavor": "Feeling a little blue? Feeling VERY blue."},
	{"id": "square_dance", "page": 1, "tier": "silver", "name": "Square Dance", "text": "Have 10 or more Square pieces (2x2 or 3x3) in your bag.", "flavor": "Swing your partner, stack your blocks."},
	{"id": "full_spectrum", "page": 1, "tier": "bronze", "name": "Full Spectrum", "text": "Have at least five pieces of every color in your bag.", "flavor": "Taste the whole toybox."},
	{"id": "packrat", "page": 1, "tier": "silver", "name": "Packrat", "text": "Have 40 or more pieces in your bag.", "flavor": "You never know when you'll need a spare T."},
	{"id": "travel_light", "page": 1, "tier": "silver", "name": "Travel Light", "text": "Shrink your bag to 14 pieces or fewer.", "flavor": "Only the essentials."},
	{"id": "alchemist", "page": 1, "tier": "gold", "name": "Alchemist", "text": "Own pieces of all five materials at once: Chrome, Neon, Gold, Glass and Prism.", "flavor": "Plastic into gold, gold into glass."},
	{"id": "special_delivery", "page": 1, "tier": "gold", "name": "Special Delivery", "text": "Own pieces with all four stamps at once: Encore, Refund, Tip and Memory.", "flavor": "Signed, sealed, stamped four times."},
	{"id": "full_house", "page": 1, "tier": "bronze", "name": "Full House", "text": "Fill every Joker slot.", "flavor": "No vacancies at the Joker hotel."},
	{"id": "rare_taste", "page": 1, "tier": "gold", "name": "Rare Taste", "text": "Hold three Rare Jokers at the same time.", "flavor": "Only the finest cardboard."},
	{"id": "master_plan", "page": 1, "tier": "silver", "name": "Master Plan", "text": "Raise a shape family to Schematic level 3.", "flavor": "The blueprints have blueprints."},
	{"id": "piggy_bank", "page": 1, "tier": "silver", "name": "Piggy Bank", "text": "Hold 50 or more Credits.", "flavor": "Oink."},
	{"id": "scrooge", "page": 1, "tier": "gold", "secret": true, "name": "Scrooge", "text": "Hold the maximum 99 Credits.", "hint": "Even a wallet has a limit.", "flavor": "Swimming in coins is harder than it looks."},
	# --- Page 3: the scoreboard ---
	{"id": "big_hit", "page": 2, "tier": "bronze", "name": "Big Hit", "text": "Score 1,000 points with one placement.", "flavor": "Ka-chunk."},
	{"id": "mega_hit", "page": 2, "tier": "silver", "name": "Mega Hit", "text": "Score 10,000 points with one placement.", "flavor": "The receipt printer is sweating."},
	{"id": "giga_hit", "page": 2, "tier": "gold", "name": "Giga Hit", "text": "Score 1,000,000 points with one placement.", "flavor": "That's a lot of zeros for one little piece."},
	{"id": "triple_decker", "page": 2, "tier": "bronze", "name": "Triple Decker", "text": "Clear three lines with one placement.", "flavor": "Stacked high and cleared clean."},
	{"id": "four_alarm", "page": 2, "tier": "gold", "name": "Four-Alarm Fire", "text": "Clear four or more lines with one placement.", "flavor": "Somebody call the block brigade."},
	{"id": "crossroads", "page": 2, "tier": "bronze", "name": "Crossroads", "text": "Clear a row and a column with one placement.", "flavor": "X marks the spot."},
	{"id": "red_hot", "page": 2, "tier": "silver", "name": "Red Hot", "text": "Reach the maximum combo (x4).", "flavor": "Don't touch the board, it's hot."},
	{"id": "overkill", "page": 2, "tier": "silver", "name": "Overkill", "text": "Finish a round with at least three times its target.", "flavor": "The target asked for a little. You gave a lot."},
	{"id": "by_a_thread", "page": 2, "tier": "silver", "name": "By a Thread", "text": "Win a round with your very last placement.", "flavor": "Close. So close. Close enough!"},
	{"id": "spotless", "page": 2, "tier": "silver", "name": "Spotless", "text": "Leave the board completely empty after a clear (campaign).", "flavor": "You could eat off this board."},
	{"id": "grand_slam", "page": 2, "tier": "gold", "name": "Grand Slam", "text": "Get dealt a Grand Slam Tray Hand.", "flavor": "Three of a kind, one color, all the lights."},
	{"id": "full_deck", "page": 2, "tier": "gold", "name": "Full Deck", "text": "See all five Tray Hands (across any runs).", "flavor": "Twins, Staircase, Monochrome, Triplets, Grand Slam. Collected."},
	# --- Page 4: the arcade and secrets ---
	{"id": "arcade_rookie", "page": 3, "tier": "bronze", "name": "Arcade Rookie", "text": "Score 5,000 points in one Endless game.", "flavor": "Put your initials in. Go on."},
	{"id": "arcade_regular", "page": 3, "tier": "silver", "name": "Arcade Regular", "text": "Score 25,000 points in one Endless game.", "flavor": "The cabinet knows your name."},
	{"id": "arcade_legend", "page": 3, "tier": "gold", "name": "Arcade Legend", "text": "Score 100,000 points in one Endless game.", "flavor": "They're going to name the cabinet after you."},
	{"id": "blockstorm", "page": 3, "tier": "gold", "name": "Blockstorm", "text": "Reach the x10 combo in Endless.", "flavor": "Ten out of ten. No notes."},
	{"id": "fresh_start", "page": 3, "tier": "silver", "name": "Fresh Start", "text": "Clear the whole board in Endless.", "flavor": "Ahh. That new-board smell."},
	{"id": "vandal", "page": 3, "tier": "bronze", "secret": true, "name": "Vandal", "text": "Have every letter of the BLOCKMANIA logo blown up at once.", "hint": "The title looks awfully fragile.", "flavor": "BL...CKM...NIA? Where did everything go?"},
	{"id": "night_shift", "page": 3, "tier": "bronze", "secret": true, "name": "Night Shift", "text": "Place a piece between midnight and 5 AM.", "hint": "Some players only come out after dark.", "flavor": "The blocks glow brighter at night. Probably."},
	{"id": "no_lines", "page": 3, "tier": "gold", "secret": true, "name": "Look Ma, No Lines", "text": "Win a campaign round without clearing a single line.", "hint": "Who needs lines anyway?", "flavor": "Technically, the rules never said you HAD to."},
	{"id": "butterfingers", "page": 3, "tier": "bronze", "secret": true, "name": "Butterfingers", "text": "Shatter a Glass piece.", "hint": "Handle with care.", "flavor": "That one's coming out of your allowance."},
	{"id": "through_the_window", "page": 3, "tier": "bronze", "secret": true, "name": "Through the Window", "text": "Throw an Emergency Brick.", "hint": "In case of emergency, break something.", "flavor": "Who's paying for that?"},
	{"id": "fine_print", "page": 3, "tier": "silver", "secret": true, "name": "The Fine Print", "text": "Get a lost round replayed by Insurance Policy.", "hint": "Always read the small text.", "flavor": "Terms and conditions apply. Luckily, they applied to you."},
	{"id": "block_maniac", "page": 3, "tier": "legend", "name": "Block Maniac", "text": "Unlock every other achievement.", "flavor": "The whole trophy case. Every last shelf. Take a bow."},
	# --- Page 5: legends and engines (2026-09-24) ---
	{"id": "legend_found", "page": 4, "tier": "silver", "name": "Once Upon a Legend", "text": "Own a Legendary Joker.", "flavor": "It hums a little when you hold it."},
	{"id": "legend_pair", "page": 4, "tier": "gold", "secret": true, "name": "Double Legend", "text": "Own two Legendary Jokers at the same time.", "hint": "One legend is a story. Two is a problem.", "flavor": "The rack has never looked so smug."},
	{"id": "pantheon", "page": 4, "tier": "legend", "name": "Pantheon", "text": "Own each of the four Legendary Jokers (across any runs).", "flavor": "The Avalanche, the Mirrors, the Stone and the Star. All accounted for."},
	{"id": "avalanche_chain", "page": 4, "tier": "gold", "name": "Chain Reaction", "text": "Chain three clear waves in one placement with The Avalanche.", "flavor": "Nobody touch anything. Let it fall."},
	{"id": "mirror_world", "page": 4, "tier": "gold", "name": "Mirror World", "text": "Score a placement where Hall of Mirrors doubles four other Jokers.", "flavor": "How many of you are in there?"},
	{"id": "heavy_metal", "page": 4, "tier": "silver", "name": "Heavy Metal", "text": "Have 15 or more pieces with a material in your bag.", "flavor": "Chrome, neon, gold and glass. Very little plastic left."},
	{"id": "supernova_x10", "page": 4, "tier": "gold", "name": "Going Nova", "text": "Score with Supernova at x10 Mult or more.", "flavor": "Eighteen lines and one very bright star."},
	{"id": "snowed_in", "page": 4, "tier": "silver", "name": "Snowed In", "text": "Grow Snowball to x2 Mult or more.", "flavor": "It started as a pebble of snow."},
	{"id": "interest_rate", "page": 4, "tier": "bronze", "name": "Compound Growth", "text": "Earn the maximum interest (+5 Credits) after a round.", "flavor": "Your Credits have been working harder than you."},
	{"id": "wide_rack", "page": 4, "tier": "silver", "name": "Wide Rack", "text": "Have seven Joker slots.", "flavor": "Two Rack Extenders and a lot of shelf brackets."},
	{"id": "billionaire", "page": 4, "tier": "legend", "name": "Billionaire", "text": "Score 1,000,000,000 points with one placement.", "flavor": "Nine zeros. The counter had to borrow some."},
	{"id": "fallen_hero", "page": 4, "tier": "bronze", "secret": true, "name": "Fallen Hero", "text": "Lose a run while owning a Legendary Joker.", "hint": "Even legends have bad days.", "flavor": "They'll write songs about it. Sad ones."},
]

static var _by_id := {}


static func get_def(id: String) -> Dictionary:
	if _by_id.is_empty():
		for d in CATALOG:
			_by_id[d.id] = d
	return _by_id.get(id, {})


static func ids() -> Array[String]:
	var out: Array[String] = []
	for d in CATALOG:
		out.append(String(d.id))
	return out


static func page_ids(page: int) -> Array[String]:
	var out: Array[String] = []
	for d in CATALOG:
		if int(d.page) == page:
			out.append(String(d.id))
	return out


static func page_count() -> int:
	return PAGE_TITLES.size()


static func is_secret(id: String) -> bool:
	return bool(get_def(id).get("secret", false))


# --- Conditions --------------------------------------------------------------------------------

## Achievements whose condition holds after a campaign action. `life` holds lifetime data from
## BMAchievementStore (hands_seen). `hour` is the local hour of a placement (-1 when unknown).
static func check_campaign(run: BMRun, action: Dictionary, r: Dictionary, life: Dictionary, hour: int = -1) -> Array[String]:
	var out: Array[String] = []
	if run == null or not r.get("ok", false):
		return out
	var kind := String(r.get("type", action.get("a", "")))
	var won_round := bool(r.get("round_won", false))
	var res := run.last_round_result
	# Campaign progress.
	if kind == "place" and int(r.get("lines", 0)) > 0:
		out.append("first_line")
	if won_round:
		out.append("first_round")
		if String(res.get("boss", "")) != "":
			out.append("boss_buster")
		if run.round_state.placements_made <= 5:
			out.append("speedrunner")
		if int(res.get("score", 0)) >= 3 * int(res.get("target", 1)):
			out.append("overkill")
		if r.get("feats", []).has("last_breath") or int(res.get("unused", 1)) == 0:
			out.append("by_a_thread")
		if run.round_state.clearing_placements == 0:
			out.append("no_lines")
		if run.overtime:
			out.append("overtime")
	if run.round_number >= 5:
		out.append("second_act")
	if run.round_number >= 9:
		out.append("final_act")
	var beaten := run.phase == BMRun.Phase.RUN_WON or run.overtime
	if beaten:
		out.append("champion")
		if run.kit_id != "standard":
			out.append("kit_winner")
	if run.overtime and run.round_number >= 20:
		out.append("sudden_death")
	if run.overtime and run.round_number >= 30:
		out.append("no_off_switch")
	if run.machine_broken:
		out.append("broke_machine")
	# The bag and the shop (state checks, any action).
	out.append_array(_bag_checks(run))
	if run.jokers.size() >= run.joker_slots():
		out.append("full_house")
	var rares := 0
	for id in run.jokers:
		if int(BMJokers.get_def(id).get("rarity", 0)) == BMJokers.RARE:
			rares += 1
	if rares >= 3:
		out.append("rare_taste")
	for fam in run.family_levels:
		if int(run.family_levels[fam]) >= 3:
			out.append("master_plan")
			break
	if run.credits >= 50:
		out.append("piggy_bank")
	if run.credits >= BMRunConfig.CREDIT_CAP:
		out.append("scrooge")
	# The scoreboard.
	if kind == "place":
		var pts := int(r.get("points", 0))
		if pts >= 1000:
			out.append("big_hit")
		if pts >= 10000:
			out.append("mega_hit")
		if pts >= 1000000:
			out.append("giga_hit")
		var lines := int(r.get("lines", 0))
		if lines >= 3:
			out.append("triple_decker")
		if lines >= 4:
			out.append("four_alarm")
		if _count(r.get("rows", 0)) > 0 and _count(r.get("cols", 0)) > 0:
			out.append("crossroads")
		if int(r.get("combo_after", 0)) >= BMRunConfig.COMBO_CAP:
			out.append("red_hot")
		if r.get("feats", []).has("clean_board"):
			out.append("spotless")
		if not Array(r.get("shattered", [])).is_empty():
			out.append("butterfingers")
		if hour >= 0 and hour < 5:
			out.append("night_shift")
	for p in run.tray:
		if not p.is_empty() and String(p.get("hand", "")) == BMHands.GRAND_SLAM:
			out.append("grand_slam")
			break
	if Array(life.get("hands_seen", [])).size() >= BMHands.ORDER.size():
		out.append("full_deck")
	if kind == "use" and String(r.get("item", "")) == "emergency_brick":
		out.append("through_the_window")
	if bool(r.get("insurance", false)):
		out.append("fine_print")
	out.append_array(_legend_checks(run, kind, r, life))
	return out


## Page 5: Legendary Jokers and the engine cards.
static func _legend_checks(run: BMRun, kind: String, r: Dictionary, life: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var legends := 0
	for id in run.jokers:
		if BMJokers.is_legendary(id):
			legends += 1
	if legends >= 1:
		out.append("legend_found")
	if legends >= 2:
		out.append("legend_pair")
	if Array(life.get("legends_seen", [])).size() >= BMJokers.LEGENDARY_IDS.size():
		out.append("pantheon")
	if legends >= 1 and run.phase == BMRun.Phase.RUN_LOST:
		out.append("fallen_hero")
	if run.joker_slots() >= BMRunConfig.MAX_JOKER_SLOTS:
		out.append("wide_rack")
	if run.jokers.has("snowball") and run.joker_value("snowball") >= 2.0:
		out.append("snowed_in")
	if bool(r.get("round_won", false)) and int(run.last_round_result.get("interest", 0)) >= BMRunConfig.INTEREST_CAP:
		out.append("interest_rate")
	var metal := 0
	for p in run.bag:
		if String(p.get("material", "")) != "":
			metal += 1
	if metal >= 15:
		out.append("heavy_metal")
	if kind == "place":
		if Array(r.get("waves", [])).size() >= 3:
			out.append("avalanche_chain")
		if int(r.get("points", 0)) >= 1000000000:
			out.append("billionaire")
		var mirrored := {}
		var nova := 1.0
		for it in r.get("items", []):
			if String(it.get("source", "")) == "joker":
				var j := String(it.get("joker", ""))
				if j != "hall_of_mirrors":
					mirrored[j] = int(mirrored.get(j, 0)) + 1
				if j == "supernova":
					nova = maxf(nova, float(it.value))
		var doubled := 0
		for j in mirrored:
			if int(mirrored[j]) >= 2:
				doubled += 1
		if run.jokers.has("hall_of_mirrors") and doubled >= 4:
			out.append("mirror_world")
		if nova >= 10.0:
			out.append("supernova_x10")
	return out


static func _bag_checks(run: BMRun) -> Array[String]:
	var out: Array[String] = []
	var colors := {}
	var blue := 0
	var squares := 0
	var materials := {}
	var stamps := {}
	for p in run.bag:
		var c := int(p.color)
		colors[c] = int(colors.get(c, 0)) + 1
		if c == BLUE:
			blue += 1
		if p.family == &"square2" or p.family == &"square3":
			squares += 1
		if String(p.get("material", "")) != "":
			materials[String(p.material)] = true
		if String(p.get("stamp", "")) != "":
			stamps[String(p.stamp)] = true
	if blue >= 10:
		out.append("blue_period")
	if squares >= 10:
		out.append("square_dance")
	var spectrum := true
	for c in BMShapes.OFFER_COLOR_COUNT:
		if int(colors.get(c, 0)) < 5:
			spectrum = false
	if spectrum:
		out.append("full_spectrum")
	if run.bag.size() >= 40:
		out.append("packrat")
	if run.bag.size() <= 14:
		out.append("travel_light")
	if materials.size() >= BMPieces.MATERIALS.size() - 1:
		out.append("alchemist")
	if stamps.size() >= BMPieces.STAMP_DEFS.size():
		out.append("special_delivery")
	return out


static func _count(v: Variant) -> int:
	if v is Array:
		return (v as Array).size()
	return int(v)


## Achievements whose condition holds after an Endless action.
static func check_endless(game: BMEndless, r: Dictionary, hour: int = -1) -> Array[String]:
	var out: Array[String] = []
	if game == null or not r.get("ok", false):
		return out
	if game.score >= 5000:
		out.append("arcade_rookie")
	if game.score >= 25000:
		out.append("arcade_regular")
	if game.score >= 100000:
		out.append("arcade_legend")
	if game.best_combo >= 10:
		out.append("blockstorm")
	if bool(r.get("clean_board", false)):
		out.append("fresh_start")
	if String(r.get("type", "")) == "place" and hour >= 0 and hour < 5:
		out.append("night_shift")
	return out


## The meta achievement: every other badge unlocked.
static func check_meta(unlocked: Dictionary) -> Array[String]:
	for d in CATALOG:
		if d.id != "block_maniac" and not unlocked.has(d.id):
			return []
	return ["block_maniac"]


## Progress toward a counting achievement as [have, need], or [] when it has no counter.
static func progress(id: String, life: Dictionary, records: Dictionary, unlocked_count: int) -> Array:
	match id:
		"full_deck":
			return [Array(life.get("hands_seen", [])).size(), BMHands.ORDER.size()]
		"sudden_death":
			return [mini(20, int(records.get("furthest_round", 0))), 20]
		"no_off_switch":
			return [mini(30, int(records.get("furthest_round", 0))), 30]
		"arcade_rookie":
			return [mini(5000, int(life.get("endless_best", 0))), 5000]
		"arcade_regular":
			return [mini(25000, int(life.get("endless_best", 0))), 25000]
		"arcade_legend":
			return [mini(100000, int(life.get("endless_best", 0))), 100000]
		"block_maniac":
			return [mini(unlocked_count, CATALOG.size() - 1), CATALOG.size() - 1]
		"pantheon":
			return [Array(life.get("legends_seen", [])).size(), BMJokers.LEGENDARY_IDS.size()]
	return []
