class_name BMWallet
extends Control
## The Credits counter: a coin and the number, drawn here so the bounce and the coin flip never
## fight a container's layout. Presentation only: it reads Credits and never changes the run.
##
## Money that arrives flies in as coins (`gain`) and the number counts up coin by coin, each
## with a rising clink; money spent leaves as coins (`spend`); any other change (`sync`) still
## flashes and rolls. Clicking the wallet flicks the coin into the air; a long streak of clicks
## spills a little fountain. Reduced Motion: no flying coins, no hop or bounce, the number
## jumps straight to the real value.

const GAP := 8.0
const HOP_TIME := 0.42
const HOP_HEIGHT := 30.0
const FLASH_TIME := 0.5
const PUNCH_TIME := 0.28
const STREAK_GAP := 0.7 ## seconds between clicks that still count as one streak
const JACKPOT_STREAK := 10
const MAX_COINS := 10

var reduced_motion := false
var font_size := 30
var icon_scale := 0.75
var outline := 8
## "+N" / "-N" floats under the wallet (off where the amounts are already printed).
var show_pops := true

var _value := 0 ## where the number rolls to
var _shown := 0.0 ## the number drawn
var _truth := 0 ## the run's Credits at the last sync
var _arrivals: Array = [] ## [seconds left, Credits it carries]
var _landed := 0 ## coins landed in the current shower (their clinks climb)
var _punch := 0.0
var _flash := 0.0
var _flash_color := BMStyle.MINT_L
var _hop := -1.0 ## seconds into a flick, -1 when resting
var _streak := 0
var _last_poke := -10.0
var _pokes := 0
var _clock := 0.0
var _hover := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = BMLoc.t("Your Credits: spend them in the shop.")
	mouse_entered.connect(func() -> void:
		_hover = true
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hover = false
		queue_redraw())


func _get_minimum_size() -> Vector2:
	var cs := _coin_size()
	var font := BMStyle.font_bold
	if font == null:
		return cs
	var w := font.get_string_size("99", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + outline
	return Vector2(cs.x + GAP + w, maxf(cs.y, font.get_height(font_size)))


# --- What the screens call -------------------------------------------------------------------

## Shows `v` at once (a screen opening, a new run).
func set_amount(v: int) -> void:
	_truth = v
	_value = v
	_shown = v
	_arrivals.clear()
	queue_redraw()


## The run's Credits after an action. Coins still in the air land first; a change nobody
## announced with gain/spend still flashes and rolls. `quiet` jumps without a sound.
func sync(v: int, quiet: bool = false) -> void:
	_truth = v
	if not _arrivals.is_empty():
		return
	if quiet or reduced_motion:
		_value = v
		_shown = v
		queue_redraw()
		return
	if v != _value:
		_bump(v > _value)
		if v > _value:
			BMAudio.sfx("coin_collect")
		_value = v


## `amount` Credits fly in from `from` (global position) as coins; the number counts up as
## each lands. Returns when the last coin lands (seconds).
func gain(from: Vector2, amount: int, coins: int = -1) -> float:
	if amount <= 0:
		return 0.0
	_truth += amount # until the next sync says otherwise
	var fx := BMFx.instance
	if reduced_motion or fx == null or not is_visible_in_tree():
		_value += amount
		_flash_color = BMStyle.MINT_L
		_flash = 1.0
		BMAudio.sfx("coin_collect")
		_pop("+%d" % amount, BMStyle.MINT_L)
		queue_redraw()
		return 0.0
	var n := clampi(coins if coins > 0 else amount, 1, MAX_COINS)
	fx.coins(from, coin_center(), n)
	var last := 0.0
	for i in n:
		var part := amount / n + (1 if i < amount % n else 0)
		var t := BMFx.coin_flight(i)
		_arrivals.append([t, part, i == n - 1, amount])
		last = maxf(last, t)
	return last


## `amount` Credits leave for `to` (global position): the number drops at once, coins fly out.
func spend(to: Vector2, amount: int) -> void:
	if amount <= 0:
		return
	_value -= amount
	_truth -= amount
	_flash_color = BMStyle.PINK_L
	_flash = 1.0
	_punch = 0.6
	_pop("-%d" % amount, BMStyle.PINK_L)
	var fx := BMFx.instance
	if reduced_motion or fx == null:
		queue_redraw()
		return
	BMAudio.sfx("coin_out")
	fx.coins(coin_center(), to, clampi(amount, 1, 8))
	queue_redraw()


## Where coins aim: the coin's center, in global coordinates.
func coin_center() -> Vector2:
	var cs := _coin_size()
	return get_global_transform() * Vector2(cs.x / 2.0, size.y / 2.0)


func target_amount() -> int:
	return _value


func shown_amount() -> int:
	return int(round(_shown))


## Clicks since this wallet was made (for tests: a click registered, nothing else changed).
func pokes() -> int:
	return _pokes


# --- Clicking the wallet ---------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		poke()


func poke() -> void:
	_pokes += 1
	_streak = _streak + 1 if _clock - _last_poke < STREAK_GAP else 1
	_last_poke = _clock
	BMAudio.sfx("coin_flip", 1.0 + 0.035 * mini(_streak, 12))
	if reduced_motion:
		BMAudio.sfx_later("coin_catch", 0.12, 1.0 + 0.04 * mini(_streak, 12))
		_flash_color = BMStyle.SUN_L
		_flash = 0.6
		queue_redraw()
		return
	_hop = 0.0
	if _streak >= JACKPOT_STREAK:
		_streak = 0
		_jackpot()


func _jackpot() -> void:
	BMAudio.sfx("coin_jackpot")
	_punch = 1.0
	_flash_color = BMStyle.CREAM
	_flash = 1.0
	var fx := BMFx.instance
	if fx == null:
		return
	var c := coin_center()
	fx.burst(c, [BMStyle.SUN, BMStyle.SUN_L, Color("#e0a030"), BMStyle.CREAM], 26, 520.0, 9.0)
	fx.stars(c, 8, 80.0)
	fx.ring(c, BMStyle.SUN_L, 90.0)


# --- Animation -------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_clock += delta
	var busy := false
	if not _arrivals.is_empty():
		busy = true
		var keep: Array = []
		for a in _arrivals:
			a[0] -= delta
			if a[0] <= 0.0:
				_land(int(a[1]), bool(a[2]), int(a[3]))
			else:
				keep.append(a)
		_arrivals = keep
		if _arrivals.is_empty():
			_landed = 0
			if _value != _truth:
				_value = _truth
	if int(round(_shown)) != _value:
		busy = true
		var gap := absf(_value - _shown)
		_shown = move_toward(_shown, _value, maxf(14.0, gap * 9.0) * delta)
	if _punch > 0.0 or _flash > 0.0 or _hop >= 0.0:
		busy = true
		_punch = maxf(0.0, _punch - delta / PUNCH_TIME)
		_flash = maxf(0.0, _flash - delta / FLASH_TIME)
		if _hop >= 0.0:
			_hop += delta
			if _hop >= HOP_TIME:
				_hop = -1.0
				_catch()
	if busy or _hover:
		queue_redraw()


func _land(amount: int, last: bool, total: int) -> void:
	_value += amount
	_landed += 1
	_punch = 1.0
	_flash_color = BMStyle.MINT_L
	_flash = 1.0
	BMAudio.sfx("coin_collect", 1.0 + 0.06 * mini(_landed, 10))
	if last:
		_pop("+%d" % total, BMStyle.MINT_L)
		if BMFx.instance:
			BMFx.instance.stars(coin_center(), 4, 40.0)


func _catch() -> void:
	BMAudio.sfx("coin_catch", 1.0 + 0.04 * mini(_streak, 12))
	_punch = 0.45
	if BMFx.instance:
		BMFx.instance.stars(coin_center() + Vector2(0, 6), 3, 28.0)


func _bump(up: bool) -> void:
	_flash_color = BMStyle.MINT_L if up else BMStyle.PINK_L
	_flash = 1.0
	_punch = 0.7


func _pop(text: String, color: Color) -> void:
	if not show_pops or BMFx.instance == null or not is_visible_in_tree():
		return
	var r := get_global_rect()
	BMFx.instance.pop_text(Vector2(r.get_center().x, r.end.y + 22), text, color, 30, 36.0, 1.0)


func _coin_size() -> Vector2:
	var t := BMStyle.tex("icon_coin")
	return (t.get_size() if t else Vector2(44, 44)) * icon_scale


func _draw() -> void:
	var coin := BMStyle.tex("icon_coin")
	var cs := _coin_size()
	var cy := size.y / 2.0
	# The coin: a hop with two full turns (its width follows the turn; the back is darker),
	# and a shadow that shrinks while it is up.
	var lift := 0.0
	var turn := 1.0
	if _hop >= 0.0:
		var p := _hop / HOP_TIME
		lift = 4.0 * HOP_HEIGHT * p * (1.0 - p)
		turn = cos(p * TAU * 2.0)
		var sh := 1.0 - lift / HOP_HEIGHT * 0.6
		draw_set_transform(Vector2(cs.x / 2.0, cy + cs.y / 2.0 - 2.0), 0.0, Vector2(sh, 0.3 * sh))
		draw_circle(Vector2.ZERO, cs.x * 0.4, Color(BMStyle.INK, 0.35))
		draw_set_transform(Vector2.ZERO)
	elif _hover and not reduced_motion:
		turn = 0.85 + 0.15 * cos(_clock * 5.0)
	var w := maxf(3.0, absf(turn) * cs.x)
	var tint := Color.WHITE if turn >= 0.0 else Color(0.78, 0.66, 0.5)
	if coin:
		draw_texture_rect(coin, Rect2(Vector2((cs.x - w) / 2.0, cy - lift - cs.y / 2.0), Vector2(w, cs.y)), false, tint)
	# The number, bouncing and flashing on a change.
	var font := BMStyle.font_bold
	if font == null:
		return
	var text := str(int(round(_shown)))
	var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var mid := Vector2(cs.x + GAP + ts.x / 2.0, cy)
	var k := _punch * _punch
	var sc := 1.0 + 0.28 * k
	draw_set_transform(mid + Vector2(0, -6.0 * k), 0.0, Vector2(sc, sc))
	var base := BMStyle.SUN_L if _hover else BMStyle.SUN
	var col := base.lerp(_flash_color, _flash)
	var at := Vector2(-ts.x / 2.0, (font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, BMStyle.INK)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)
	draw_set_transform(Vector2.ZERO)
