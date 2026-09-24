class_name BMRefreshLever
extends Button
## The Refresh control as an arcade lever (art: tools/art/gen_lever.py). Still a Button, so
## clicks, the R key, focus and tooltips work as before; the look is drawn here:
##   - a brass gate with a red-ball lever; a row of lamps, one lit per Refresh left (a number
##     when there are more than fit); the labels REFRESH / LOCKED / EMPTY / CONCEDE
##   - pull(): a one-armed-bandit pull. The arm ratchets down (timed to lever_pull's teeth),
##     slams with a shake, sparks and a coin burst, the spent lamp pops, every lamp runs a
##     casino chase and the title flashes; then the arm springs back with a wobble. The tray's
##     reels start spinning at the slam (BMGameScreen).
##   - hovering nudges the knob; holding the mouse down pulls it partway (it follows the drag)
##   - no Refresh left: the housing goes cold and the knob sits still; The Lockdown boss chains
##     it with a padlock; concede mode turns the rim pink with a skull
## Presentation only: the pull animation plays after the run already refreshed.

const FRAME := Vector2(41, 44) ## art px per frame
const ART := 4.0
const PULL_DOWN := 0.24 ## matches the ratchet in lever_pull.wav, so the slam lands on its KA-CHUNK
const PULL_HOLD := 0.09
const PULL_BACK := 0.4
const CHASE := 0.8 ## seconds of lamp chase and title flash after the slam
const SHAKE := 0.28
const MAX_LAMPS := 5

enum Look { READY, EMPTY, LOCKED, CONCEDE }

var look := Look.READY
var refreshes := 0
var cap := 1 ## lamps drawn even when spent (the round's starting Refreshes)
var _tex: Texture2D
var _t := 0.0
var _pull_t := -1.0 ## seconds since pull() (-1 = idle)
var _press_y := -1.0 ## where the mouse went down (for the partial drag pull)
var _drag_k := 0.0 ## 0..1 how far the held mouse pulls the knob
var _hover := false
var _popping := -1 ## lamp index popping after a pull
var _spent := -1 ## the lamp the current pull will pop at the slam
var _slam_t := -1.0 ## seconds since the slam (-1 = none): shake, chase and flash
var _pop_t := 0.0
var _reduced := false


func _ready() -> void:
	_tex = load("res://assets/ui/lever.png")
	text = ""
	icon = null
	flat = true
	for s in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(s, StyleBoxEmpty.new())
	add_theme_stylebox_override("focus", BMStyle.focus_box())
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pressed.connect(func() -> void: BMAudio.sfx("click"))
	mouse_entered.connect(func() -> void: _hover = true)
	mouse_exited.connect(func() -> void:
		_hover = false
		_press_y = -1.0)
	button_down.connect(func() -> void: _press_y = get_local_mouse_position().y)
	button_up.connect(func() -> void: _press_y = -1.0)


## Sets what the lever shows. `lamps` = Refreshes left this round, `lamp_cap` = the round's
## starting count (spent lamps stay on the panel, dark).
func set_state(new_look: Look, lamps: int, reduced_motion: bool, lamp_cap: int = 1) -> void:
	look = new_look
	refreshes = lamps
	cap = maxi(1, lamp_cap)
	_reduced = reduced_motion
	queue_redraw()


## The lever animation for a Refresh that just happened. `spent_lamp` = the lamp that went out.
func pull(spent_lamp: int) -> void:
	BMAudio.sfx("lever_pull")
	if _reduced:
		BMAudio.sfx_later("lever_spring", PULL_DOWN + PULL_HOLD, 1.0, -4.0)
		return
	_pull_t = 0.0
	_popping = -1
	_spent = spent_lamp
	_pop_t = 0.0


func _process(delta: float) -> void:
	_t += delta
	if _pull_t >= 0.0:
		var before := _pull_t
		_pull_t += delta
		if before < PULL_DOWN and _pull_t >= PULL_DOWN:
			_slam()
		if _pull_t > PULL_DOWN + PULL_HOLD + PULL_BACK:
			_pull_t = -1.0
	if _slam_t >= 0.0:
		_slam_t += delta
		if _slam_t > maxf(CHASE, SHAKE):
			_slam_t = -1.0
	if _popping >= 0:
		_pop_t += delta
		if _pop_t > 0.45:
			_popping = -1
	var target := 0.0
	if _press_y >= 0.0 and look == Look.READY and not disabled:
		target = clampf((get_local_mouse_position().y - _press_y) / 90.0, 0.0, 1.0) * 0.8 + 0.15
	_drag_k = move_toward(_drag_k, target, delta * 8.0)
	queue_redraw()


## The bottom of the pull: sparks from the gate and a thunk.
func _slam() -> void:
	BMAudio.sfx_later("lever_spring", PULL_HOLD, 1.0, -4.0)
	_slam_t = 0.0
	_popping = _spent
	_pop_t = 0.0
	if BMFx.instance:
		var g := get_global_rect()
		var gate := g.position + Vector2(g.size.x / 2.0, g.size.y * 0.86)
		BMFx.instance.sparks(gate, BMStyle.SUN_L, 10, 460.0)
		BMFx.instance.burst(gate, [BMStyle.SUN, BMStyle.PINK_L, BMStyle.CREAM], 8, 300.0, 6.0)
		# Payout: a spray of sun-gold coins out of the top, like a jackpot tray.
		var top := g.position + Vector2(g.size.x / 2.0, g.size.y * 0.18)
		BMFx.instance.burst(top, [BMStyle.SUN_L, BMStyle.SUN, Color.WHITE], 10, 380.0, 8.0)
		BMFx.instance.stars(top, 4, 70.0)


## Knob position 0 (up) .. 4 (fully pulled), from the pull animation, the drag or the hover.
func _knob() -> int:
	if look == Look.LOCKED or look == Look.EMPTY:
		return 0
	var k := _drag_k
	if _pull_t >= 0.0:
		if _pull_t < PULL_DOWN:
			k = _pull_t / PULL_DOWN
		elif _pull_t < PULL_DOWN + PULL_HOLD:
			k = 1.0
		else:
			# Spring back with one overshoot wobble.
			var b := (_pull_t - PULL_DOWN - PULL_HOLD) / PULL_BACK
			k = maxf(0.0, (1.0 - b) * (1.0 - b)) - sin(b * PI * 2.0) * 0.12 * (1.0 - b)
			k = clampf(k, 0.0, 1.0)
	elif _hover and not disabled and not _reduced and _press_y < 0.0:
		k = maxf(k, 0.18 + sin(_t * 9.0) * 0.06)
	return clampi(roundi(k * 4.0), 0, 4)


## Sheet region of frame i (the PNG is exported at ART x).
func _region(i: int) -> Rect2:
	return Rect2(Vector2(i * FRAME.x, 0) * ART, FRAME * ART)


func _draw() -> void:
	if _tex == null:
		return
	var sz := size
	var scale := minf(sz.x / (FRAME.x * ART), sz.y / (FRAME.y * ART)) * ART
	var art := FRAME * scale
	var o := ((sz - art) / 2.0).round()
	# Slam shake: a few pixels of decaying jitter.
	if _slam_t >= 0.0 and _slam_t < SHAKE:
		var k := 1.0 - _slam_t / SHAKE
		o += Vector2(roundf(sin(_slam_t * 90.0) * 4.0 * k), roundf(cos(_slam_t * 70.0) * 2.0 * k))
	var housing := 0
	match look:
		Look.CONCEDE:
			housing = 6
		Look.EMPTY, Look.LOCKED:
			housing = 7
	var base := Rect2(o, art)
	draw_texture_rect_region(_tex, base, _region(housing))
	draw_texture_rect_region(_tex, base, _region(1 + _knob()),
		Color(1, 1, 1, 1.0) if look != Look.EMPTY else Color(0.7, 0.7, 0.8, 1.0))
	var f := BMStyle.font_bold
	# Title strip.
	var title := "REFRESH"
	var title_col := BMStyle.CREAM
	match look:
		Look.CONCEDE:
			title = "CONCEDE"
			title_col = BMStyle.PINK_L
		Look.LOCKED:
			title = "LOCKED"
			title_col = BMStyle.PINK_L
		Look.EMPTY:
			title_col = BMStyle.TEXT_DIM
	var chase := _slam_t >= 0.0 and _slam_t < CHASE
	if chase and look == Look.READY:
		# Jackpot flash: the title blinks sun and white while the lamps chase.
		title_col = BMStyle.SUN_L if int(_slam_t * 14.0) % 2 == 0 else Color.WHITE
	draw_string(f, o + Vector2(0, 7.5 * scale), title, HORIZONTAL_ALIGNMENT_CENTER, art.x, 20, title_col)
	# Lamps: one per Refresh left (a number past MAX_LAMPS); skull or padlock otherwise.
	var row_y := o.y + 10.0 * scale
	if look == Look.CONCEDE:
		var sk := BMStyle.tex("icon_skull")
		var ss := sk.get_size() * 0.5
		draw_texture_rect(sk, Rect2(Vector2(o.x + (art.x - ss.x) / 2.0, row_y - 2.0), ss), false)
	elif look == Look.LOCKED:
		var lk := BMStyle.tex("icon_padlock")
		var ls := lk.get_size() * 0.6
		draw_texture_rect(lk, Rect2(o + Vector2((art.x - ls.x) / 2.0, 24.0 * scale - ls.y / 2.0), ls), false)
	else:
		var n := maxi(refreshes, cap)
		var shown := mini(n, MAX_LAMPS)
		var lamp := 3.0 * scale
		var gap := 2.0 * scale
		var total := shown * lamp + (shown - 1) * gap
		if refreshes > MAX_LAMPS:
			total += 2.0 * scale + f.get_string_size("x%d" % refreshes, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var x := o.x + (art.x - total) / 2.0
		for i in shown:
			var on := i < refreshes
			var r := Rect2(Vector2(x, row_y), Vector2(lamp, lamp)).abs()
			draw_rect(r.grow(scale * 0.5), BMStyle.INK)
			var col := BMStyle.MINT_L if on else Color(BMStyle.PLUM_L, 0.8)
			if on and not _reduced:
				col = col.lerp(Color.WHITE, 0.25 + 0.25 * sin(_t * 4.0 + i))
			if chase:
				# Casino chase: one bright lamp runs along the row, spent lamps included.
				var head := int(_slam_t * 18.0) % shown
				if i == head:
					col = BMStyle.SUN_L
				elif absi(i - head) == 1:
					col = col.lerp(BMStyle.SUN, 0.5)
			draw_rect(r, col)
			if on:
				draw_rect(Rect2(r.position, Vector2(scale, scale)), Color.WHITE)
			# The lamp a pull just spent: a white pop and a little puff.
			if i == _popping and _pop_t < 0.45:
				var k := _pop_t / 0.45
				draw_rect(r.grow(scale * (1.0 + k * 3.0)), Color(1, 1, 1, 0.7 * (1.0 - k)), false, scale)
				draw_rect(Rect2(r.get_center() + Vector2(-scale, -scale * (2.0 + k * 6.0)), Vector2(scale * 2.0, scale * 2.0)), Color(BMStyle.CREAM, 0.5 * (1.0 - k)))
			x += lamp + gap
		if refreshes > MAX_LAMPS:
			draw_string(f, Vector2(x, row_y + lamp), "x%d" % refreshes, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, BMStyle.MINT_L)
	# Keycap hint in the bottom-right corner: R pulls the lever too.
	if look == Look.READY and not disabled:
		var kc := Rect2(o + Vector2(33.0, 36.0) * scale, Vector2(6.0, 6.0) * scale)
		draw_rect(kc, BMStyle.INK)
		draw_rect(kc.grow(-scale * 0.5), BMStyle.PLUM_L)
		draw_rect(Rect2(kc.position + Vector2(scale * 0.5, scale * 0.5), Vector2(kc.size.x - scale, scale * 0.5)), BMStyle.PLUM_LL)
		draw_string(f, kc.position + Vector2(0, kc.size.y - scale * 1.2), "R", HORIZONTAL_ALIGNMENT_CENTER, kc.size.x, 20, BMStyle.CREAM)
