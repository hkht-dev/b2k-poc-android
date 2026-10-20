## Settings (brief §7, GDD §11): joystick side, size and opacity, camera
## sensitivity and inversion, large text, a box behind subtitles, sounds as
## ripples, tap-to-walk. Every value lives in GameState.settings and is saved
## at once; the street re-applies them when `changed` fires. The rows are
## data below; the controls are built from it. Each control carries its
## label as tooltip, the nearest thing to a screen-reader label Godot 4.3
## has (docs/DECISIONS.md).
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

var _controls: Dictionary = {}

@onready var _title: Label = %Title
@onready var _rows: VBoxContainer = %Rows
@onready var _close: Button = %CloseButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_title.text = Strings.t("settings.title")
	_close.text = Strings.t("settings.close")
	_close.pressed.connect(func() -> void: closed.emit())
	for row: Array in ROWS:
		_rows.add_child(_build_row(row))
	_close.grab_focus()


func control_for(key: String) -> Control:
	return _controls.get(key)


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
		toggle.button_pressed = bool(value_of(key))
		toggle.toggled.connect(func(on: bool) -> void: _store(key, on))
		control = toggle
	else:
		var slider := HSlider.new()
		slider.min_value = row[3]
		slider.max_value = row[4]
		slider.step = row[5]
		slider.value = float(value_of(key))
		slider.custom_minimum_size = Vector2(300, 48)
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
