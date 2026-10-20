## The lotus: the UI's one ornament, pulsing at the right edge of the screen
## for eight seconds when a wisdom card is available.
##
## GDD §6 "Optional wisdom": "a lotus icon pulses at the screen edge for 8
## seconds. Tapping opens a card ... Ignoring it has no effect." GDD §11: the
## HUD is empty by default and "the lotus icon pulses only when a card is
## available"; §10: "The lotus icon is the only ornament." Drawn here with
## _draw, no image, in the parchment and ink of the rest of the UI, never in
## peacock blue or magenta (forbidden in the Street, GDD §10). It is the
## GDD's own prompt, not a notification: in-world, silent, dismissible, with
## no sound, no badge, no count, and nothing waiting on it. The Place opens
## the card when `opened` fires.
extends Control

## The player tapped the lotus (or pressed the contextual action with
## nothing usable near): open this card.
signal opened(card_id: String)
## The eight seconds passed untouched. Nothing else happens.
signal faded(card_id: String)

## How long the lotus is offered (GDD §6).
const SHOW_SECONDS := 8.0
const FADE_SECONDS := 0.6
## One slow breath every two seconds, far below the 3 Hz flashing limit
## (GDD §11).
const PULSE_HZ := 0.5
const PULSE_SCALE := 0.08
const WIDTH := 104.0
const HEIGHT := 128.0
const PETAL := Color(0.957, 0.925, 0.847, 1.0)
const INK := Color(0.42, 0.31, 0.208, 1.0)
const HEART := Color(0.85, 0.64, 0.3, 1.0)
const GLOW := Color(0.85, 0.64, 0.3, 0.18)
## Five petals seen from the side, outer first: angle from upright
## (radians), length, width.
const PETALS := [
	[-0.95, 50.0, 26.0],
	[0.95, 50.0, 26.0],
	[-0.5, 66.0, 30.0],
	[0.5, 66.0, 30.0],
	[0.0, 78.0, 34.0],
]
const PETAL_STEPS := 12

var _card_id := ""
var _left := 0.0
var _fade_left := 0.0
var _time := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	tooltip_text = Strings.t("wisdom.lotus")
	visible = false


## Counts only while the world runs: a card or the pause menu over it holds
## the offer where it is.
func _process(delta: float) -> void:
	if not visible or get_tree().paused:
		return
	_time += delta
	if _fade_left > 0.0:
		_fade_left -= delta
		if _fade_left <= 0.0:
			var id := _card_id
			_hide()
			faded.emit(id)
	else:
		_left -= delta
		if _left <= 0.0:
			_fade_left = FADE_SECONDS
	queue_redraw()


## Offers [param card_id] for SHOW_SECONDS. A newer card replaces one still
## showing: never more than one card per beat (GDD §9).
func show_card(card_id: String) -> void:
	_card_id = card_id
	_left = SHOW_SECONDS
	_fade_left = 0.0
	_time = 0.0
	visible = true
	queue_redraw()


func is_showing() -> bool:
	return visible and not _card_id.is_empty()


func is_fading() -> bool:
	return is_showing() and _fade_left > 0.0


func card_id() -> String:
	return _card_id


func seconds_left() -> float:
	return maxf(_left, 0.0)


## Opens the card that is showing, if one is. Returns whether it did.
func open() -> bool:
	if not is_showing():
		return false
	var id := _card_id
	_hide()
	opened.emit(id)
	return true


## Takes the lotus away without a word.
func dismiss() -> void:
	_hide()


## The colours the lotus is drawn in, for the palette test.
func colours() -> Array[Color]:
	return [PETAL, INK, HEART, GLOW]


func _hide() -> void:
	_card_id = ""
	_left = 0.0
	_fade_left = 0.0
	visible = false


func _gui_input(event: InputEvent) -> void:
	var pressed: bool = (
		(event is InputEventScreenTouch and event.pressed)
		or (
			event is InputEventMouseButton
			and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT
		)
	)
	if pressed and is_showing():
		accept_event()
		open()


func _alpha() -> float:
	if _fade_left > 0.0:
		return clampf(_fade_left / FADE_SECONDS, 0.0, 1.0)
	return 1.0


func _draw() -> void:
	if not is_showing():
		return
	var alpha := _alpha()
	var breath := sin(_time * TAU * PULSE_HZ)
	var scale := 1.0 + PULSE_SCALE * breath
	var base := Vector2(WIDTH * 0.5, HEIGHT - 24.0)
	draw_set_transform(base, 0.0, Vector2(scale, scale))
	draw_circle(Vector2(0.0, -34.0), 52.0 + 4.0 * breath, Color(GLOW, GLOW.a * alpha))
	for petal: Array in PETALS:
		var points := _petal(petal[0], petal[1], petal[2])
		draw_colored_polygon(points, Color(PETAL, alpha))
		points.append(points[0])
		draw_polyline(points, Color(INK, alpha), 2.0, true)
	draw_circle(Vector2(0.0, -8.0), 7.0, Color(HEART, alpha))
	draw_set_transform(Vector2.ZERO)


## A petal as a closed outline: a teardrop from the base along [param angle]
## (radians from upright), [param length] tall and [param width] across.
func _petal(angle: float, length: float, width: float) -> PackedVector2Array:
	var axis := Vector2.UP.rotated(angle)
	var side := axis.orthogonal()
	var points := PackedVector2Array([Vector2.ZERO])
	var right := PackedVector2Array()
	for i in range(1, PETAL_STEPS):
		var t := float(i) / PETAL_STEPS
		var along := axis * length * t
		var half := width * 0.5 * pow(sin(PI * t), 0.75)
		points.append(along + side * half)
		right.append(along - side * half)
	points.append(axis * length)
	right.reverse()
	points.append_array(right)
	return points
