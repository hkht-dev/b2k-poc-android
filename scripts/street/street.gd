## Hollow Vale, the Street: what is the street's own on top of Place.
##
## GDD §3 Act 3 "Arrival", CLAUDE_CODE_BRIEF.md §4.1, docs/BRIEF_AMENDMENT_1.md
## §A. The input seam, pause, settings, the hum and the doors live in
## scripts/places/place.gd; here are the street bed, the light's answer to
## the Dry Fountain, and the end of the slice at the bus stop.
extends Place

## The slice is over: the street has faded; Main shows the end screen.
signal slice_ended(reason: String)

const STREET_BED := preload("res://assets/audio/street_bed.ogg")
## §4.6: fade to black over this long, then the end screen.
const FADE_SECONDS := 1.6
const SIT_POSE := "Sitting_Idle"
## The street's light answers the Dry Fountain (CLAUDE_CODE_BRIEF.md §4.4):
## a step darker after a can is taken, a step warmer after one is given.
## Data: flag -> (sun colour, ambient energy factor), multiplied into the
## hour the story has reached (scripts/street/daylight.gd, data/daylight.json).
const MOODS := {
	"took_dry_fountain": [Color(0.93, 0.94, 0.98), 0.85],
	"gave_dry_fountain": [Color(1.0, 0.93, 0.82), 1.12],
}
const MOOD_SECONDS := 4.0

var _bed_player: AudioStreamPlayer = null
var _ending := false
var _daylight: Daylight = null
var _base_sun_colour := Color.WHITE
var _base_ambient := 1.0
var _mood_tween: Tween = null
var _tint_tween: Tween = null

@onready var _sun: DirectionalLight3D = $Sun
@onready var _bus_stop: Node3D = %BusStopPoint
@onready var _environment: WorldEnvironment = $Environment


func _ready() -> void:
	super()
	_bed_player = AudioStreamPlayer.new()
	_bed_player.stream = STREET_BED
	_bed_player.volume_db = -10.0
	add_child(_bed_player)
	_bed_player.play()
	# -- daylight: the light moves with the story (GDD §5; data/daylight.json)
	_daylight = Daylight.new()
	_daylight.name = "Daylight"
	_daylight.bind(_sun, _environment.environment)
	add_child(_daylight)
	for flag in MOODS:
		if GameState.has_flag(flag):
			_apply_mood(flag, 0.0)
	# -- end daylight
	GameState.flag_changed.connect(_on_flag_changed)
	_bus_stop.slice_ended.connect(_on_slice_ended)


func _on_flag_changed(flag: String, is_set: bool) -> void:
	if is_set and MOODS.has(flag):
		_apply_mood(flag, MOOD_SECONDS)
		if flag == "gave_dry_fountain":
			_controls.subtitle("sub.can_placed", 4.0)


## The light's answer to a flag: sun colour and ambient energy ease over, as
## a step on top of whatever hour the daylight stage has reached.
func _apply_mood(flag: String, seconds: float) -> void:
	_daylight.set_mood(MOODS[flag][0], MOODS[flag][1], seconds)


func mood_sun_colour() -> Color:
	return _sun.light_color


func daylight() -> Daylight:
	return _daylight


## The sky's first pink (GDD §10: "the first time any pink appears in Hollow
## Vale is at beat 12"; §3 Act 4 "Remembrance"): eases the sun to
## [param colour] over [param seconds]. Any mood that comes later tints from
## there, so the dawn is not undone by a flag.
func tint_sun(colour: Color, seconds: float) -> void:
	if _mood_tween != null:
		_mood_tween.kill()
	if _tint_tween != null:
		_tint_tween.kill()
	_base_sun_colour = colour
	if seconds <= 0.0:
		_sun.light_color = colour
		return
	_tint_tween = create_tween()
	_tint_tween.tween_property(_sun, "light_color", colour, seconds)


## The bus stop said it is over (CLAUDE_CODE_BRIEF.md §4.6): the player sits
## if they sat, the street fades to black, and Main takes it from there.
func _on_slice_ended(reason: String) -> void:
	if _ending or _leaving:
		return
	_ending = true
	_input_locked = true
	_player.set_move_input(Vector2.ZERO, 0.0)
	if reason == "sat":
		var rig: CharacterRig = _player.get_node("%Mesh")
		rig.hold_pose(SIT_POSE)
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, FADE_SECONDS)
	tween.tween_callback(func() -> void: slice_ended.emit(reason))


func is_ending() -> bool:
	return _ending
