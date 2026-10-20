## The twelve lines a lamp can carry, as big buttons; pick one or go back.
##
## GDD §16a "Social: lamps": a lamp carries one of twelve preset lines and
## never free text, so this screen offers exactly the ids in
## data/lamp_lines.json and nothing to type. Opened from the pause menu
## (*Set a lamp here*); the Place records the choice. The buttons are built
## from the data, one per line, in the order the data lists them, all in the
## same style: no line is marked out. Keyboard and gamepad move the focus
## between them; *Not now* (or the cancel action) closes without a lamp.
extends Control

signal chosen(line_id: String)
signal closed

const BUTTON_HEIGHT := 80.0
const CANCEL_ACTION := "ui_cancel"

@onready var _title: Label = %Title
@onready var _lines: VBoxContainer = %Lines
@onready var _cancel: Button = %CancelButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_title.text = Strings.t("lamp.title")
	_cancel.text = Strings.t("lamp.cancel")
	_cancel.tooltip_text = _cancel.text
	_cancel.pressed.connect(func() -> void: closed.emit())
	for line_id in LampLines.line_ids():
		_lines.add_child(_build_button(line_id))
	if _lines.get_child_count() > 0:
		(_lines.get_child(0) as Button).grab_focus()
	else:
		_cancel.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(CANCEL_ACTION):
		closed.emit()
		get_viewport().set_input_as_handled()


## The line buttons, in the data's order.
func line_buttons() -> Array[Button]:
	var out: Array[Button] = []
	for child in _lines.get_children():
		out.append(child as Button)
	return out


func _build_button(line_id: String) -> Button:
	var button := Button.new()
	button.name = line_id.replace(".", "_")
	button.text = Strings.t(line_id)
	# The nearest thing to a screen-reader label Godot 4.3 has (docs/DECISIONS.md).
	button.tooltip_text = button.text
	button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	button.pressed.connect(func() -> void: chosen.emit(line_id))
	return button
