## Title screen. Shows the game's name and one way in.
##
## GDD §11 "HUD": nothing is on screen that does not need to be. No tagline, no
## instructions and nothing that frames this as a spiritual game
## (CLAUDE_CODE_BRIEF.md §0).
extends Control

signal begin_pressed

@onready var _title: Label = %Title
@onready var _begin: Button = %BeginButton
@onready var _build: Label = %BuildLabel


func _ready() -> void:
	_title.text = Strings.t("app.title")
	_begin.text = Strings.t("title.begin")
	_build.text = Strings.t("title.build_label") % _build_name()
	_begin.pressed.connect(func() -> void: begin_pressed.emit())
	_begin.grab_focus()


## The version from project.godot, so a tester can name the build they played
## (CLAUDE_CODE_BRIEF.md §8 playtest reporting).
func _build_name() -> String:
	var version: Variant = ProjectSettings.get_setting("application/config/version", "")
	return str(version)
