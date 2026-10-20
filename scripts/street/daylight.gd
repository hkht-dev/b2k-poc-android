## The Street's light moves with the story.
##
## GDD §5, Hollow Vale row: "Arrival: overcast midday, flat, no pink
## anywhere, sodium-orange street lamps. Shifts toward dusk as quests
## complete. Dawn climb: cold blue to warm. Act 4: dusk, lamplit, the first
## rose tint allowed into the sky." GDD §12: nothing is conditional on
## anything but flags, so the stages are data (data/daylight.json), each with
## a condition in the quest grammar (scripts/lib/condition.gd), and the latest
## stage whose condition holds is the light. No clock, no timer: a stage
## changes when a flag does, and the sun, the ambient, the fog, the sky tint
## and the lamps ease over to it.
##
## The street's older answer to the Dry Fountain (street.gd MOODS) stays as
## a multiplier on top of the stage: a taken can still steps the light
## darker, a given one warmer, whatever the hour.
class_name Daylight
extends Node

## The stage changed; the light is easing toward it.
signal stage_changed(stage_id: String)

const PATH := "res://data/daylight.json"
## The lamp lights the generator places (tools/street_parts/lamp_lights.py).
const LAMP_GROUP := "street_lamp"
const DEFAULT_TRANSITION_SECONDS := 6.0
## The sky shader's tint uniform (assets/shaders/sky_tint.gdshader).
const SKY_TINT_PARAMETER := "tint"

static var _data: Dictionary = {}
static var _loaded := false

## The street's mood (MOODS): multiplied into the stage's sun colour and
## ambient energy. White and one mean no mood.
var mood_colour := Color.WHITE
var mood_ambient := 1.0

var _sun: DirectionalLight3D = null
var _environment: Environment = null
var _stage: Dictionary = {}
var _tween: Tween = null
var _sky_tint := Color.WHITE
## 0 dark, 1 lit: how far the lamps are on, so they can fade.
var _lamp_level := 0.0
## Each lamp's authored energy, read once, so fading never loses it.
var _lamp_energy: Dictionary = {}

# -- data ---------------------------------------------------------------------


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed: Variant = Strings.read_json_file(PATH)
	if not parsed is Dictionary or not parsed.get("stages") is Array:
		push_error("Daylight: %s did not load or has no stages" % PATH)
		return
	var stages_in: Array = []
	for entry in parsed["stages"]:
		if not entry is Dictionary or str(entry.get("id", "")).is_empty():
			push_error("Daylight: a stage in %s has no id" % PATH)
			continue
		if not Condition.is_well_formed(str(entry.get("when", ""))):
			push_error(
				"Daylight: stage '%s' has a bad condition '%s'" % [entry["id"], entry.get("when")]
			)
			continue
		stages_in.append(entry)
	_data = parsed
	_data["stages"] = stages_in


## The stages, in the order the data gives them.
static func stages() -> Array:
	_load()
	return _data.get("stages", [])


static func stage_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for entry in stages():
		ids.append(str(entry["id"]))
	return ids


static func stage(stage_id: String) -> Dictionary:
	for entry in stages():
		if str(entry["id"]) == stage_id:
			return entry
	return {}


static func transition_seconds() -> float:
	_load()
	return float(_data.get("transition_seconds", DEFAULT_TRANSITION_SECONDS))


## The latest stage whose condition holds over [param flags] and
## [param events]; empty when none does (the data should start with `true`).
static func stage_for(flags: FlagStore, events: FlagStore) -> Dictionary:
	var current: Dictionary = {}
	for entry in stages():
		if Condition.evaluate(str(entry["when"]), flags, events):
			current = entry
	return current


## A colour in the data: [r, g, b] in 0..1.
static func colour_of(stage_data: Dictionary, key: String) -> Color:
	var value: Variant = stage_data.get(key)
	if value is Array and value.size() >= 3:
		return Color(float(value[0]), float(value[1]), float(value[2]))
	return Color.WHITE


## The sun's orientation for an elevation above the horizon and an azimuth
## clockwise from north (-Z; east is +X). The light travels down its -Z.
static func sun_quaternion(elevation_degrees: float, azimuth_degrees: float) -> Quaternion:
	return Quaternion.from_euler(
		Vector3(deg_to_rad(-elevation_degrees), deg_to_rad(180.0 - azimuth_degrees), 0.0)
	)


# -- the node -----------------------------------------------------------------


## Call before adding to the tree: the light and the environment this moves.
func bind(sun: DirectionalLight3D, environment: Environment) -> void:
	_sun = sun
	_environment = environment


func _ready() -> void:
	if _sun == null or _environment == null:
		push_error("Daylight: bind(sun, environment) before adding to the tree")
		return
	for lamp in _lamps():
		_lamp_energy[lamp] = lamp.light_energy
	_stage = stage_for(GameState.flags, GameState.events)
	_apply(0.0)
	GameState.flag_changed.connect(_on_flag_changed)


func _on_flag_changed(_flag: String, _is_set: bool) -> void:
	var next := stage_for(GameState.flags, GameState.events)
	if next.get("id") == _stage.get("id"):
		return
	_stage = next
	_apply(transition_seconds())
	stage_changed.emit(stage_id())


## The street's mood steps the light on top of the stage (P4 MOODS).
func set_mood(colour: Color, ambient: float, seconds: float) -> void:
	mood_colour = colour
	mood_ambient = ambient
	_apply(seconds)


func stage_id() -> String:
	return str(_stage.get("id", ""))


## Where the sun colour is heading: the stage's colour under the mood.
func target_sun_colour() -> Color:
	return colour_of(_stage, "sun_colour") * mood_colour


func target_ambient_energy() -> float:
	return float(_stage.get("ambient_energy", 1.0)) * mood_ambient


func lamps_on() -> bool:
	return _lamp_level > 0.0


func sky_tint() -> Color:
	return _sky_tint


## Eases every property to the current stage under the current mood; at zero
## seconds it is set at once (a loaded journey starts in its hour).
func _apply(seconds: float) -> void:
	if _stage.is_empty():
		return
	var sun_colour := target_sun_colour()
	var sun_energy := float(_stage.get("sun_energy", 1.0))
	var rotation := sun_quaternion(
		float(_stage.get("sun_elevation_degrees", 45.0)),
		float(_stage.get("sun_azimuth_degrees", 180.0))
	)
	var ambient := target_ambient_energy()
	var fog_colour := colour_of(_stage, "fog_colour")
	var fog_density := float(_stage.get("fog_density", 0.0))
	var tint := colour_of(_stage, "sky_tint")
	var lamp_level := 1.0 if bool(_stage.get("lamps_on", false)) else 0.0
	if _tween != null:
		_tween.kill()
		_tween = null
	if seconds <= 0.0:
		_sun.light_color = sun_colour
		_sun.light_energy = sun_energy
		_sun.quaternion = rotation
		_environment.ambient_light_energy = ambient
		_environment.fog_light_color = fog_colour
		_environment.fog_density = fog_density
		_set_sky_tint(tint)
		_set_lamp_level(lamp_level)
		return
	var from_rotation := _sun.quaternion
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_sun, "light_color", sun_colour, seconds)
	_tween.tween_property(_sun, "light_energy", sun_energy, seconds)
	_tween.tween_method(
		func(t: float) -> void: _sun.quaternion = from_rotation.slerp(rotation, t),
		0.0,
		1.0,
		seconds
	)
	_tween.tween_property(_environment, "ambient_light_energy", ambient, seconds)
	_tween.tween_property(_environment, "fog_light_color", fog_colour, seconds)
	_tween.tween_property(_environment, "fog_density", fog_density, seconds)
	_tween.tween_method(_set_sky_tint, _sky_tint, tint, seconds)
	_tween.tween_method(_set_lamp_level, _lamp_level, lamp_level, seconds)


func _set_sky_tint(tint: Color) -> void:
	_sky_tint = tint
	if _environment.sky == null:
		return
	var material := _environment.sky.sky_material as ShaderMaterial
	if material != null:
		material.set_shader_parameter(SKY_TINT_PARAMETER, tint)


## Lamps fade with the stage: hidden while dark, so a dark lamp costs nothing.
func _set_lamp_level(level: float) -> void:
	_lamp_level = level
	for lamp in _lamps():
		lamp.light_energy = float(_lamp_energy.get(lamp, lamp.light_energy)) * level
		lamp.visible = level > 0.0


func _lamps() -> Array[OmniLight3D]:
	var out: Array[OmniLight3D] = []
	if not is_inside_tree():
		return out
	for node in get_tree().get_nodes_in_group(LAMP_GROUP):
		var lamp := node as OmniLight3D
		if lamp != null:
			out.append(lamp)
	return out
