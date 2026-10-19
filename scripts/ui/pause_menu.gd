## Pause: resume, or see the controls again.
##
## GDD §11 lists the pause menu's contents (Your journey, settings, quit);
## those arrive in P6. docs/BRIEF_AMENDMENT_1.md §A5 asks for *Controls* to be
## reachable here always, so the menu exists now with that and *Resume*.
extends Control

signal resumed
signal controls_requested
signal map_toggled(on: bool)

const MINIMAP := preload("res://scripts/ui/minimap.gd")

@onready var _title: Label = %Title
@onready var _resume: Button = %ResumeButton
@onready var _controls: Button = %ControlsButton
@onready var _map: Button = %MapButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_title.text = Strings.t("pause.title")
	_resume.text = Strings.t("pause.resume")
	_controls.text = Strings.t("pause.controls")
	_resume.pressed.connect(func() -> void: resumed.emit())
	_controls.pressed.connect(func() -> void: controls_requested.emit())
	_refresh_map_label()
	_map.pressed.connect(_on_map)
	_resume.grab_focus()


func _refresh_map_label() -> void:
	_map.text = Strings.t("pause.map_on" if MINIMAP.enabled() else "pause.map_off")


func _on_map() -> void:
	MINIMAP.set_enabled(not MINIMAP.enabled())
	_refresh_map_label()
	map_toggled.emit(MINIMAP.enabled())
