## One card, shown once per journey before the street, saying how to move.
##
## Playtest feedback: on a phone the controls were not discoverable. GDD §11
## lists a first-launch note among the screens; this is that note, reduced to
## the three things a player needs. It picks its words by device — a thumb
## reads differently from a mouse — and never comes back until *Play again*.
## It still tells the player nothing about where to go (CLAUDE_CODE_BRIEF.md
## §4.3): only how to walk, look and climb.
extends Control

signal dismissed

const SETTING_SEEN := "controls_seen"

@onready var _title: Label = %Title
@onready var _move: Label = %Move
@onready var _look: Label = %Look
@onready var _climb: Label = %Climb
@onready var _button: Button = %GotItButton


func _ready() -> void:
	var touch := is_touch_device()
	_title.text = Strings.t("controls.title")
	_move.text = Strings.t("controls.move.touch" if touch else "controls.move.desktop")
	_look.text = Strings.t("controls.look.touch" if touch else "controls.look.desktop")
	_climb.text = Strings.t("controls.climb")
	_button.text = Strings.t("controls.got_it")
	_button.pressed.connect(_on_got_it)
	_button.grab_focus()


## Whether this journey has already seen the card.
static func already_seen() -> bool:
	return GameState.settings.get(SETTING_SEEN, false) == true


static func is_touch_device() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")


func _on_got_it() -> void:
	GameState.settings[SETTING_SEEN] = true
	GameState.save()
	dismissed.emit()
