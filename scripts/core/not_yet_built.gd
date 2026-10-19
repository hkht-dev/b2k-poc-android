## PLACEHOLDER: deleted in P1, when res://scenes/street/Street.tscn takes its
## place as the first play screen.
##
## It exists so a P0 build proves on-device that the title screen, the string
## table and screen swapping all work before any gameplay is written.
extends Control

signal back_pressed

@onready var _message: Label = %Message
@onready var _back: Button = %BackButton


func _ready() -> void:
	_message.text = Strings.t("placeholder.street_pending")
	_back.text = Strings.t("placeholder.back")
	_back.pressed.connect(func() -> void: back_pressed.emit())
	_back.grab_focus()
