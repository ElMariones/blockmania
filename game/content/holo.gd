class_name BMHolo
extends RefCounted
## Holo cards (owner request, 2026-09-26): an expensive late-game shelf of chrome-foil cards
## that bend the rules. From the shop after round BMRunConfig.HOLO_FROM_ROUND the pieces shelf
## becomes the Holo shelf (BMRunConfig.HOLO_OFFERS cards, seeded on the shop stream, rerolled
## with the shop). A card applies at once when bought (`buy_holo`); random targets are rolled
## on the shop stream at purchase, so a seed and its history replay exactly.
##
## Joker traits live per rack position in BMRun.joker_mods:
##   negative  the Joker takes no Joker slot (the rack holds one more card)
##   again     after every Joker has scored, this one triggers once more (scoring Jokers only)
##   level     +BMRunConfig.JOKER_LEVEL_STEP of the card's effect per level (Tuning Fork)
## Each purchase makes the next copy of that card 50% dearer (BMRun.holo_price); a rack holds
## at most MAX_NEGATIVE Negative and MAX_AGAIN AGAIN Jokers.
## Stable ids are save-facing: never rename casually. Values are provisional.

const CATALOG := [ # i18n: name, text
	{"id": "negative_film", "name": "Negative Film", "cost": 14, "weight": 5,
		"text": "A random Joker that is not Negative turns Negative: it no longer takes a Joker slot."},
	{"id": "again_seal", "name": "AGAIN Seal", "cost": 15, "weight": 5,
		"text": "A random scoring Joker gains AGAIN: after all your Jokers have scored, it triggers once more."},
	{"id": "master_schematic", "name": "Master Schematic", "cost": 12, "weight": 4,
		"text": "Every shape family in your bag gains a level (+25 Chips, +0.25 Mult per level)."},
	{"id": "master_tuning", "name": "Master Tuning", "cost": 12, "weight": 4,
		"text": "Every scoring Joker below its top level gains a level (+50% of its effect)."},
	{"id": "legend_crate", "name": "Legend Crate", "cost": 20, "weight": 3,
		"text": "The Legendary Joker shown on this card joins your rack. Needs a free Joker slot."},
	{"id": "hologram", "name": "Hologram", "cost": 18, "weight": 2,
		"text": "A random Joker that is not Legendary gets a Negative copy (the copy takes no slot)."},
]

## Price rise per earlier purchase of the same Holo card, and trait caps per rack.
const PRICE_STEP := 0.5
const MAX_NEGATIVE := 3
const MAX_AGAIN := 3

static var _by_id := {}


static func get_def(id: String) -> Dictionary:
	if _by_id.is_empty():
		for d in CATALOG:
			_by_id[d.id] = d
	return _by_id.get(id, {})


static func display_name(id: String) -> String:
	return BMLoc.t(String(get_def(id).get("name", id)))


static func display_text(id: String) -> String:
	return BMLoc.t(String(get_def(id).get("text", "")))


static func cost(id: String) -> int:
	return int(get_def(id).get("cost", 12))


## Price after `bought` earlier purchases of the same card: +50% of its base each time
## (study follow-up: Overtime runs bought one card a dozen times and broke the machine).
static func price(id: String, bought: int) -> int:
	return roundi(cost(id) * (1.0 + PRICE_STEP * maxi(0, bought)))


## Card title for a shelf offer ({"id", "joker"}); a Legend Crate names its Legendary.
static func offer_name(offer: Dictionary) -> String:
	if String(offer.get("id", "")) == "legend_crate" and String(offer.get("joker", "")) != "":
		return BMLoc.t("Legend Crate: %s") % BMJokers.display_name(String(offer.joker))
	return display_name(String(offer.get("id", "")))


static func offer_text(offer: Dictionary) -> String:
	var text := display_text(String(offer.get("id", "")))
	if String(offer.get("id", "")) == "legend_crate" and String(offer.get("joker", "")) != "":
		text += "\n" + BMJokers.display_text(String(offer.joker))
	return text


## Jokers with a scoring effect (the ones a level or AGAIN can change).
static func is_scoring(joker_id: String) -> bool:
	return String(BMJokers.get_def(joker_id).get("phase", "")) in ["chips", "add_mult", "x_mult", "copy"]
