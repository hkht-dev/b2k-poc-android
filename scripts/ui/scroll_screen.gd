## The painted scroll: one sitting of a tale, one panel at a time.
##
## GDD §9a "Tales told": "two-minute painted-scroll interludes (static
## hand-painted frames with light movement, narrated by the character who
## tells them)"; §3a: "tap to turn a painted scroll". This screen draws the
## scroll itself with _draw (parchment between two rolled ends) and lays one
## panel's words on it in the heading serif. A tap or click on the scroll,
## Enter, or the gamepad's A turns to the next panel; *Back* goes back one;
## *Close* rolls it up at any point. Turning
## past the last panel finishes the sitting: the seat that opened the scroll
## hears `finished` and sets the flags. Nothing here counts or scores: no
## page number, no bar. The tale's canto and chapter sit at the foot of the
## paper, as §9a asks of every tale's card.
##
## Pause-safe: the pause menu lies over this and stops taps; keys are ignored
## while the tree is paused. The scroll never frees itself; its owner does.
##
## PLACEHOLDER: plain drawn parchment stands in for the painted frames of
## GDD §9a (about 70 for Chapter 1) and for the teller's voice.
extends Control

signal turned(panel: int)
signal finished(tale_id: String, sitting: int)
signal closed

## Parchment and timber: GDD §10's Hollow Vale palette, nothing peacock.
const DIM := Color(0.1, 0.08, 0.05, 0.55)
const SHADOW := Color(0.0, 0.0, 0.0, 0.28)
const PAPER := Color(0.93, 0.87, 0.74)
const PAPER_FIBRE := Color(0.80, 0.70, 0.53, 0.22)
const FRAME := Color(0.72, 0.52, 0.24)
const ROLL := Color(0.42, 0.31, 0.21)
const ROLL_LIGHT := Color(0.58, 0.44, 0.30)
const ROLL_DARK := Color(0.27, 0.19, 0.12)
const ROLL_CORE := Color(0.84, 0.76, 0.60)
const MARGIN := 48.0
const ROLL_HEIGHT := 56.0
const ROLL_OVERHANG := 26.0
const FRAME_INSET := 22.0
const FIBRE_LINES := 14
const BUTTON_HEIGHT := 84.0
const BUTTON_WIDTH := 220.0
## Two input events for one tap (a touch and the click emulated from it)
## within this many milliseconds count once.
const TAP_DEBOUNCE_MS := 150

var _tale_id := ""
var _sitting := 0
var _panels := PackedStringArray()
var _panel := 0
var _last_turn_ms := -1000

@onready var _title: Label = %Title
@onready var _sitting_label: Label = %Sitting
@onready var _text: Label = %Panel
@onready var _source: Label = %Source
@onready var _hint: Label = %Hint
@onready var _back: Button = %BackButton
@onready var _close: Button = %CloseButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_back.text = Strings.t("scroll.back")
	_close.text = Strings.t("scroll.close")
	_back.tooltip_text = _back.text
	_close.tooltip_text = _close.text
	# Enter and A always turn the page; the buttons are for thumbs and mice.
	_back.focus_mode = Control.FOCUS_NONE
	_close.focus_mode = Control.FOCUS_NONE
	_back.pressed.connect(back)
	_close.pressed.connect(close)
	resized.connect(_layout)
	_layout()


## Lays out sitting [param sitting] (from 1) of the tale and shows its first
## panel. Every word is resolved through the string table by id.
func open(tale_id: String, sitting: int) -> void:
	_tale_id = tale_id
	_sitting = sitting
	_panels = Tales.panels(tale_id, sitting)
	_title.text = Strings.t(Tales.title_id_of(tale_id))
	_sitting_label.visible = Tales.sitting_count(tale_id) > 1
	_sitting_label.text = (
		Strings.t(Tales.sitting_name_id(sitting)) if _sitting_label.visible else ""
	)
	var source_id := Tales.source_id_of(tale_id)
	_source.text = Strings.t(source_id) if not source_id.is_empty() else ""
	_show_panel(0)
	_layout()


## To the next panel; past the last, the sitting is finished.
func turn() -> void:
	if _panels.is_empty():
		return
	if _panel >= _panels.size() - 1:
		finished.emit(_tale_id, _sitting)
		return
	_show_panel(_panel + 1)
	turned.emit(_panel)


## Back one panel; on the first, nothing.
func back() -> void:
	if _panel > 0:
		_show_panel(_panel - 1)
		turned.emit(_panel)


## Rolls the scroll up where it is. Whoever opened it decides what that means
## (nothing is recorded).
func close() -> void:
	closed.emit()


func tale_id() -> String:
	return _tale_id


func sitting() -> int:
	return _sitting


## The panel showing, counted from 0.
func panel_index() -> int:
	return _panel


func panel_count() -> int:
	return _panels.size()


func panel_text() -> String:
	return _text.text


func is_last() -> bool:
	return not _panels.is_empty() and _panel == _panels.size() - 1


## The parchment's rectangle in this control, between the two rolls.
func paper_rect() -> Rect2:
	var width := maxf(size.x - MARGIN * 2.0, 200.0)
	var height := clampf(size.y * 0.58, 420.0, 1100.0)
	var top := (size.y - height) * 0.42
	return Rect2(Vector2((size.x - width) * 0.5, top), Vector2(width, height))


## The painted frame on the paper: inside the rolls, which cover the paper's
## top and bottom edges, and in from its sides.
func frame_rect() -> Rect2:
	var paper := paper_rect()
	var vertical := ROLL_HEIGHT * 0.5 + FRAME_INSET
	return Rect2(
		paper.position + Vector2(FRAME_INSET, vertical),
		paper.size - Vector2(FRAME_INSET * 2.0, vertical * 2.0)
	)


func _show_panel(index: int) -> void:
	_panel = clampi(index, 0, maxi(_panels.size() - 1, 0))
	_text.text = Strings.t(_panels[_panel]) if not _panels.is_empty() else ""
	_back.disabled = _panel == 0
	_hint.text = Strings.t("scroll.roll_up" if is_last() else "scroll.turn")


func _gui_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	var tapped: bool = (
		(
			event is InputEventMouseButton
			and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT
		)
		or (event is InputEventScreenTouch and event.pressed)
	)
	if tapped:
		accept_event()
		_turn_from_input()


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	# Enter, Space, or the pad's A (the `contextual` action). Escape is not
	# taken: it stays the pause, as everywhere else. Godot 4.3's built-in
	# ui_cancel has no pad button, so Back and Close are the buttons on the
	# paper (docs/DECISIONS.md).
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("contextual"):
		get_viewport().set_input_as_handled()
		_turn_from_input()


func _turn_from_input() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_turn_ms < TAP_DEBOUNCE_MS:
		return
	_last_turn_ms = now
	turn()


## Puts the words and buttons on the paper, inside the frame and clear of
## the rolls, however the screen is shaped.
func _layout() -> void:
	if _title == null:
		return
	var inner := frame_rect().grow(-18.0)
	var left := inner.position.x
	var width := inner.size.x
	var y := inner.position.y
	_place(_title, left, y, width, 48.0)
	y += 56.0
	if _sitting_label.visible:
		_place(_sitting_label, left, y, width, 32.0)
		y += 44.0
	var buttons_y := inner.end.y - BUTTON_HEIGHT
	var button_width := minf(BUTTON_WIDTH, (width - 24.0) * 0.5)
	_place(_back, left, buttons_y, button_width, BUTTON_HEIGHT)
	_place(_close, inner.end.x - button_width, buttons_y, button_width, BUTTON_HEIGHT)
	var source_y := buttons_y - 48.0
	_place(_source, left, source_y, width, 32.0)
	var hint_y := source_y - 44.0
	_place(_hint, left, hint_y, width, 32.0)
	_place(_text, left, y, width, maxf(hint_y - 16.0 - y, 60.0))
	queue_redraw()


static func _place(control: Control, x: float, y: float, width: float, height: float) -> void:
	control.position = Vector2(x, y)
	control.size = Vector2(width, height)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), DIM)
	var paper := paper_rect()
	draw_rect(Rect2(paper.position + Vector2(10.0, 14.0), paper.size), SHADOW)
	draw_rect(paper, PAPER)
	# Fibres: faint lines across the parchment so it reads as paper, not a panel.
	var step := paper.size.y / (FIBRE_LINES + 1)
	for i in range(1, FIBRE_LINES + 1):
		var fibre_y := paper.position.y + step * i + sin(i * 1.7) * 4.0
		draw_line(
			Vector2(paper.position.x + 30.0, fibre_y),
			Vector2(paper.end.x - 30.0, fibre_y),
			PAPER_FIBRE,
			1.0
		)
	# The painted frame: a firm line and a fainter one inside it.
	var frame := frame_rect()
	draw_rect(frame, FRAME, false, 3.0)
	draw_rect(frame.grow(-9.0), Color(FRAME, 0.45), false, 1.0)
	_draw_roll(paper, paper.position.y)
	_draw_roll(paper, paper.end.y)


## A rolled end: a timber rod across the paper with the rolled parchment
## showing at both ends.
func _draw_roll(paper: Rect2, centre_y: float) -> void:
	var x0 := paper.position.x - ROLL_OVERHANG
	var x1 := paper.end.x + ROLL_OVERHANG
	var radius := ROLL_HEIGHT * 0.5
	draw_rect(Rect2(x0, centre_y - radius, x1 - x0, ROLL_HEIGHT), ROLL)
	draw_rect(Rect2(x0, centre_y - radius + 7.0, x1 - x0, 9.0), ROLL_LIGHT)
	draw_rect(Rect2(x0, centre_y + radius - 15.0, x1 - x0, 9.0), ROLL_DARK)
	for x in [x0, x1]:
		var end := Vector2(x, centre_y)
		draw_circle(end, radius, ROLL_DARK)
		draw_circle(end, radius * 0.72, ROLL_CORE)
		draw_arc(end, radius * 0.5, 0.6, 5.4, 18, ROLL, 2.0)
		draw_circle(end, radius * 0.18, ROLL)
