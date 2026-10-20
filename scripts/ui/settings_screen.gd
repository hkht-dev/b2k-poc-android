## Settings (brief §7, GDD §11): joystick side, size and opacity, camera
## sensitivity and inversion, large text, a box behind subtitles, sounds as
## ripples, tap-to-walk. Every value lives in GameState.settings and is saved
## at once; the street re-applies them when `changed` fires. The rows are
## data below; the controls are built from it. Each control carries its
## label as tooltip, the nearest thing to a screen-reader label Godot 4.3
## has (docs/DECISIONS.md).
##
## Every control is a thumb target (owner request 2026-10-20; GDD §11), the
## first row's control takes the focus when the screen opens, and up and
## down walk the rows in order to *Back*, so a gamepad or a keyboard reaches
## every setting without a pointer.
extends Control

signal changed(key: String)
signal closed

## key, kind ("toggle" or "slider"), default, min, max, step
const ROWS := [
	["joystick_side", "toggle", false, 0, 0, 0],
	["joystick_size", "slider", 110.0, 70.0, 180.0, 5.0],
	["joystick_opacity", "slider", 0.55, 0.2, 1.0, 0.05],
	["camera_sensitivity", "slider", 1.0, 0.25, 2.0, 0.05],
	["camera_invert_y", "toggle", false, 0, 0, 0],
	["large_text", "toggle", false, 0, 0, 0],
	["subtitle_box", "toggle", false, 0, 0, 0],
	["sound_cues", "toggle", false, 0, 0, 0],
	["tap_to_walk", "toggle", true, 0, 0, 0],
	["compass", "toggle", true, 0, 0, 0],
]
const SIDE_RIGHT := "right"
const SIDE_LEFT := "left"
## Nothing a thumb presses is smaller than this (GDD §11; owner request).
const THUMB := 56.0
const SLIDER_WIDTH := 300.0

var _controls: Dictionary = {}

@onready var _title: Label = %Title
@onready var _rows: VBoxContainer = %Rows
@onready var _close: Button = %CloseButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_title.text = Strings.t("settings.title")
	_close.text = Strings.t("settings.close")
	_close.pressed.connect(func() -> void: closed.emit())
	var previous: Control = null
	for row: Array in ROWS:
		_rows.add_child(_build_row(row))
		var control: Control = _controls[row[0]]
		_link_focus(previous, control)
		previous = control
	_link_focus(previous, _close)
	if previous != null:
		# Back is last: the chain wraps from it to the first row.
		_link_focus(_close, _controls[ROWS[0][0]])
	first_control().grab_focus()


func control_for(key: String) -> Control:
	return _controls.get(key)


## The control that has the focus when the screen opens: the first row's.
func first_control() -> Control:
	if ROWS.is_empty():
		return _close
	return _controls[ROWS[0][0]]


## Down from [param above] lands on [param below], and up goes back.
func _link_focus(above: Control, below: Control) -> void:
	if above == null or below == null:
		return
	above.focus_neighbor_bottom = above.get_path_to(below)
	above.focus_next = above.focus_neighbor_bottom
	below.focus_neighbor_top = below.get_path_to(above)
	below.focus_previous = below.focus_neighbor_top


## The stored value, or the row's default. Joystick side is stored as the
## string the joystick reads ("left"/"right"); the toggle shows "right".
static func value_of(key: String) -> Variant:
	for row: Array in ROWS:
		if row[0] == key:
			var stored: Variant = GameState.settings.get(key, null)
			if key == "joystick_side":
				return stored == SIDE_RIGHT if stored != null else row[2]
			return stored if stored != null else row[2]
	return null


func _build_row(row: Array) -> Control:
	var key: String = row[0]
	var label_text := Strings.t("settings." + key)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)
	var control: Control
	if row[1] == "toggle":
		var toggle := CheckButton.new()
		toggle.custom_minimum_size = Vector2(THUMB, THUMB)
		toggle.button_pressed = bool(value_of(key))
		toggle.toggled.connect(func(on: bool) -> void: _store(key, on))
		control = toggle
	else:
		var slider := HSlider.new()
		slider.min_value = row[3]
		slider.max_value = row[4]
		slider.step = row[5]
		slider.value = float(value_of(key))
		slider.custom_minimum_size = Vector2(SLIDER_WIDTH, THUMB)
		slider.value_changed.connect(func(v: float) -> void: _store(key, v))
		control = slider
	control.tooltip_text = label_text
	control.name = key
	box.add_child(control)
	_controls[key] = control
	return box


func _store(key: String, value: Variant) -> void:
	if key == "joystick_side":
		GameState.settings[key] = SIDE_RIGHT if bool(value) else SIDE_LEFT
	else:
		GameState.settings[key] = value
	GameState.save()
	changed.emit(key)


## Escape, or a pad's B, closes the screen as the Back button does.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
