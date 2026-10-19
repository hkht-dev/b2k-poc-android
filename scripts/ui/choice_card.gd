## One card: a full sentence on parchment that can be tapped.
##
## A PanelContainer rather than a Button on purpose. A Button with autowrap
## measures its minimum height before it has a width, so every character lands
## on its own line and a six-word card comes out a thousand pixels tall. A
## container sizes to its Label, which wraps correctly once the row has a width.
extends PanelContainer

signal pressed

const PRESS_TINT := Color(0.9, 0.86, 0.78, 1.0)

var text: String:
	set(value):
		text = value
		if _label != null:
			_label.text = value

var _label: Label = null


func _init() -> void:
	theme_type_variation = &"ChoiceCard"
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.add_theme_font_size_override("font_size", 22)
	_label.text = text
	add_child(_label)
	gui_input.connect(_on_gui_input)


func _on_gui_input(event: InputEvent) -> void:
	var down: bool = (
		(
			event is InputEventMouseButton
			and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT
		)
		or (event is InputEventScreenTouch and event.pressed)
	)
	var up: bool = (
		(event is InputEventMouseButton and not event.pressed)
		or (event is InputEventScreenTouch and not event.pressed)
	)
	if down:
		modulate = PRESS_TINT
	elif up:
		modulate = Color.WHITE
		if get_global_rect().has_point(
			event.position if event is InputEventScreenTouch else get_global_mouse_position()
		):
			pressed.emit()
