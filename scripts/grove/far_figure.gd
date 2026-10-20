## The figure across the water: Krishna at a distance, by the far tree.
##
## GDD §3 Act 1 "The glimpse": "From across the river the player sees Krishna
## at a distance, leaning against a tree, flute raised ... The player can
## approach the water but cannot cross." Unlike the Street's Glimpse
## (scripts/quest/glimpse.gd) this one is static: no trigger, no end, no
## flag, no line. It is simply there, and the river keeps the player on this
## side (an invisible wall placed by tools/gen_grove.py).
##
## PLACEHOLDER: the shared rigged body painted dark and unlit, the Glimpse's
## flute in its hand, a warm light behind; replaced by Krishna of GDD §4.
extends Node3D

const FLUTE := preload("res://scenes/quest/Flute.tscn")

## What the body is painted with (assets/materials/far_figure.tres).
@export var paint: Material

@onready var _figure: CharacterRig = $Figure


func _ready() -> void:
	if paint != null:
		_figure.paint_all(paint)
	_figure.carry(true, FLUTE)


func figure() -> CharacterRig:
	return _figure
