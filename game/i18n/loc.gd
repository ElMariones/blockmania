class_name BMLoc
extends RefCounted
## Localization (UI languages). English source text is the message id: every player-facing
## string goes through `t()` / `tn()` (or is a catalog field that the display code passes to
## `t()`), and `tools/i18n/extract.py` collects them into locale/messages.pot. Each language is a
## gettext file, locale/<code>.po, loaded at startup; `tools/i18n/check.py` verifies that every
## message is translated, that placeholders match, and that the fonts have every glyph.
##
## Presentation only: rules never read the language, saves never store translated text, and a
## missing translation falls back to English.
##
## The setting "language" is "auto" (the OS language when we have it, else English) or a code
## from LANGUAGES. Changing it rebuilds the screens (BMMain.set_language).

## [code, native name]. Order is the Settings list order.
const LANGUAGES := [
	["en", "English"],
	["es", "Español"],
	["fr", "Français"],
	["it", "Italiano"],
	["de", "Deutsch"],
	["nl", "Nederlands"],
	["pl", "Polski"],
	["pt_BR", "Português (BR)"],
	["ja", "日本語"],
	["zh_CN", "简体中文"],
	["zh_TW", "繁體中文"],
]
const CJK := ["ja", "zh_CN", "zh_TW"]

static var current := "en"
static var _loaded := false


## Loads every locale/<code>.po once.
static func load_translations() -> void:
	if _loaded:
		return
	_loaded = true
	for entry in LANGUAGES:
		var code: String = entry[0]
		if code == "en":
			continue
		var path := "res://locale/%s.po" % code
		if ResourceLoader.exists(path):
			var tr_res := load(path) as Translation
			if tr_res != null:
				tr_res.locale = code
				TranslationServer.add_translation(tr_res)


## The language a setting value stands for ("auto" follows the OS).
static func resolve(pref: String) -> String:
	if pref != "auto" and has_language(pref):
		return pref
	return from_os_locale(OS.get_locale())


## Best supported language for an OS locale such as "es_ES", "pt_BR", "zh_Hant_TW", "de".
static func from_os_locale(os_locale: String) -> String:
	var loc := os_locale.replace("-", "_")
	var lang := loc.get_slice("_", 0).to_lower()
	match lang:
		"zh":
			var l := loc.to_lower()
			if l.contains("hant") or l.ends_with("_tw") or l.ends_with("_hk") or l.ends_with("_mo"):
				return "zh_TW"
			return "zh_CN"
		"pt":
			return "pt_BR"
	return lang if has_language(lang) else "en"


static func has_language(code: String) -> bool:
	for entry in LANGUAGES:
		if entry[0] == code:
			return true
	return false


static func native_name(code: String) -> String:
	for entry in LANGUAGES:
		if entry[0] == code:
			return entry[1]
	return code


## Switches the UI language (the fonts pick matching CJK glyphs). Screens rebuild their text.
static func apply(pref: String) -> void:
	load_translations()
	current = resolve(pref)
	TranslationServer.set_locale(current)
	BMStyle.apply_language(current)


static func is_cjk(code: String = "") -> bool:
	return (current if code == "" else code) in CJK


## Translated text for an English message (optionally disambiguated by a context).
static func t(msg: String, ctx: StringName = &"") -> String:
	if msg == "" or current == "en":
		return msg
	return String(TranslationServer.translate(msg, ctx))


## Plural-aware translation; `n` picks the form. The caller still formats the number in.
static func tn(msg: String, plural: String, n: int, ctx: StringName = &"") -> String:
	if current == "en":
		return msg if n == 1 else plural
	return String(TranslationServer.translate_plural(msg, plural, n, ctx))


## Thousands separator for scores: a comma in English, Japanese and Chinese; a narrow space
## elsewhere, so "12 500" never reads as twelve and a half next to the "x1.5" decimals.
static func thousands_sep() -> String:
	return "," if current in ["en", "ja", "zh_CN", "zh_TW"] else " "


## Word gap for lists joined in code ("A, B"): CJK uses the ideographic comma.
static func list_sep() -> String:
	return "、" if is_cjk() else ", "


# --- Rules text ------------------------------------------------------------------------------
# The rules layer writes English (events, errors, receipt labels, the saved end reason and
# round-result lines), so saves and replays never depend on the language. It marks those
# strings with m() / mn() for the extractor; the UI shows them through tf(), which recognizes
# the English message a string was formatted from, formats its translation with the same
# arguments and translates %s arguments too ("Held %s" + "Red Bar 3").

## Marks an English rules message (returns it unchanged).
static func m(msg: String) -> String:
	return msg


## Marks an English rules message with a plural form (returns the English form for `n`).
static func mn(msg: String, plural: String, n: int) -> String:
	return msg if n == 1 else plural


## tf() of every string in `items`, joined.
static func tf_join(items: Array, sep: String) -> String:
	var out := PackedStringArray()
	for it in items:
		out.append(tf(String(it)))
	return sep.join(out)


static var _tf_cache := {}
static var _tf_locale := ""
static var _patterns: Array = []


## Translation of an English string that may have been formatted from a message with
## placeholders. Unknown text comes back unchanged.
static func tf(s: String) -> String:
	if current == "en" or s == "":
		return s
	if _tf_locale != current:
		_tf_cache.clear()
		_tf_locale = current
	if not _tf_cache.has(s):
		_tf_cache[s] = _translate_formatted(s)
	return _tf_cache[s]


static func _translate_formatted(s: String) -> String:
	var direct := t(s)
	if direct != s:
		return direct
	var piece := _piece_name(s)
	if piece != "":
		return piece
	if not s.contains(" ") and not s.contains(":") and s.length() < 3:
		return s
	for p in _pattern_list():
		var hit: RegExMatch = p.re.search(s)
		if hit == null:
			continue
		var args: Array = []
		var n := 1
		var have_n := false
		for i in p.kinds.size():
			var g := hit.get_string(i + 1)
			match String(p.kinds[i]):
				"d":
					args.append(int(g))
					if not have_n:
						n = int(g)
						have_n = true
				"f":
					args.append(float(g))
				_:
					args.append(tf(g))
		var pattern := tn(p.msgid, p.plural, n, p.ctx) if p.plural != "" else t(p.msgid, p.ctx)
		return pattern % args
	return s


## "Red Bar 3" (BMPieces.piece_name in English) in the current language.
static func _piece_name(s: String) -> String:
	for c in BMShapes.COLOR_NAMES.size():
		var cn: String = BMShapes.COLOR_NAMES[c]
		if s.begins_with(cn + " "):
			var rest := s.substr(cn.length() + 1)
			for fam in BMShapes.FAMILIES:
				if String(fam.name) == rest:
					return BMPieces.piece_name({"color": c, "family": fam.id})
	return ""


## Regexes for every message with placeholders (BMMessages, generated by tools/i18n/extract.py),
## most specific first.
static func _pattern_list() -> Array:
	if not _patterns.is_empty():
		return _patterns
	var entries: Array = []
	for e in BMMessages.PATTERNS:
		for form in ([e[0]] if String(e[1]) == "" else [e[0], e[1]]):
			var built := _pattern_regex(String(form))
			if built.is_empty():
				continue
			built.msgid = String(e[0])
			built.plural = String(e[1])
			built.ctx = StringName(e[2])
			entries.append(built)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.lit) > int(b.lit))
	_patterns = entries
	return _patterns


## {re, kinds, lit} for a printf-style message: %d, %s, %.Nf and %%. Messages that are nothing
## but placeholders are skipped (they would match anything).
static func _pattern_regex(msg: String) -> Dictionary:
	var rx := "^"
	var kinds: Array = []
	var lit := 0
	var i := 0
	var buf := ""
	while i < msg.length():
		var ch := msg[i]
		if ch == "%" and i + 1 < msg.length():
			var j := i + 1
			while j < msg.length() and (msg[j] == "." or msg[j].is_valid_int()):
				j += 1
			var k := msg[j] if j < msg.length() else ""
			if k == "%":
				buf += "%"
				i = j + 1
				continue
			rx += _rx_escape(buf)
			lit += buf.strip_edges().length()
			buf = ""
			match k:
				"d":
					rx += "(-?[0-9]+)"
					kinds.append("d")
				"f":
					rx += "(-?[0-9]+(?:[.][0-9]+)?)"
					kinds.append("f")
				_:
					rx += "(.*?)"
					kinds.append("s")
			i = j + 1
			continue
		buf += ch
		i += 1
	rx += _rx_escape(buf) + "$"
	lit += buf.strip_edges().length()
	if kinds.is_empty() or lit < 2:
		return {}
	var re := RegEx.new()
	if re.compile(rx) != OK:
		return {}
	return {"re": re, "kinds": kinds, "lit": lit}


static func _rx_escape(s: String) -> String:
	var out := ""
	for ch in s:
		if ".^$|?*+()[]{}\\".contains(ch):
			out += "\\"
		out += ch
	return out
