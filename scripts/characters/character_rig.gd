## A rigged human: a CC0 body, a skin texture and idle, walk and run clips.
##
## docs/BRIEF_AMENDMENT_1.md §B4 asks for low-poly humanoids with walk and
## idle, CC0 rigs acceptable. The body and the clips arrive as separate
## imported scenes (Kenney's animated characters ship the mesh and each clip
## in its own FBX; docs/RIGHTS_REGISTER.md), so this node assembles them: it
## instances the body, paints the skin on, and fills one AnimationPlayer
## with the clips, rooted at the body so the clips' bone paths resolve.
##
## Like the procedural walk it replaces, it reads movement from its own
## position delta: the player, pedestrians on paths and Tulu all drive it the
## same way, with no coupling to any of them. Which clip means what, and how
## fast each plays for a given ground speed, is data on the scene.
class_name CharacterRig
extends Node3D

const LIBRARY := "clips"
const STATE_IDLE := "idle"
const STATE_WALK := "walk"
const STATE_RUN := "run"
const BLEND := 0.18
const BODY_NAME := "Body"
## Slower than this, in m/s, is standing still.
const MOVING := 0.15

## Animations are shared between every rig built from the same clip scenes.
static var _clip_cache: Dictionary = {}

## The rigged mesh scene.
@export var body: PackedScene
## Albedo painted onto the body's one material.
@export var skin: Texture2D
## Metres of height the body should stand at; the body is scaled to fit.
@export_range(0.5, 3.0, 0.01) var height := 1.75
## The body's own height at scale 1 (Kenney's characterMedium is 3.70 m).
@export_range(0.1, 10.0, 0.01) var body_height := 3.7
## Turn the body so it faces -Z, Godot's forward, if the model faces +Z.
@export var face_yaw := PI
## Clip scenes and the animation name inside each.
@export var idle_scene: PackedScene
@export var idle_animation := ""
@export var walk_scene: PackedScene
@export var walk_animation := ""
## Ground speed, in m/s, at which the walk clip plays at 1x.
@export_range(0.2, 10.0, 0.1) var walk_reference_speed := 1.5
@export var run_scene: PackedScene
@export var run_animation := ""
@export_range(0.2, 10.0, 0.1) var run_reference_speed := 4.6
## Faster than this is a run; slower, a walk; below MOVING, idle.
@export_range(0.5, 10.0, 0.1) var run_above := 3.2

var _player: AnimationPlayer
var _state := ""
var _last := Vector3.ZERO
var _speed := 0.0


func _ready() -> void:
	_last = global_position
	if body == null:
		return
	var instance: Node3D = body.instantiate()
	instance.name = BODY_NAME
	var scale_factor := height / body_height
	instance.transform = Transform3D(
		Basis.from_euler(Vector3(0.0, face_yaw, 0.0)).scaled(Vector3.ONE * scale_factor),
		Vector3.ZERO
	)
	add_child(instance)
	_paint(instance)
	_player = AnimationPlayer.new()
	_player.name = "AnimationPlayer"
	add_child(_player)
	_player.root_node = _player.get_path_to(instance)
	var library := AnimationLibrary.new()
	for entry: Array in [
		[STATE_IDLE, idle_scene, idle_animation],
		[STATE_WALK, walk_scene, walk_animation],
		[STATE_RUN, run_scene, run_animation],
	]:
		var clip := _clip(entry[1], entry[2])
		if clip != null:
			library.add_animation(entry[0], clip)
	_player.add_animation_library(LIBRARY, library)
	_play(STATE_IDLE)


func _process(delta: float) -> void:
	if delta <= 0.0 or _player == null:
		return
	var moved := global_position - _last
	moved.y = 0.0
	_last = global_position
	_speed = lerpf(_speed, moved.length() / delta, minf(1.0, 10.0 * delta))
	if _speed < MOVING:
		_play(STATE_IDLE)
		_player.speed_scale = 1.0
	elif _speed < run_above:
		_play(STATE_WALK)
		_player.speed_scale = _speed / walk_reference_speed
	else:
		_play(STATE_RUN)
		_player.speed_scale = _speed / run_reference_speed


## The clip now playing: "idle", "walk" or "run".
func state() -> String:
	return _state


func speed() -> float:
	return _speed


func animation_player() -> AnimationPlayer:
	return _player


func _play(wanted: String) -> void:
	if wanted == _state:
		return
	var key := "%s/%s" % [LIBRARY, wanted]
	if not _player.has_animation(key):
		return
	_state = wanted
	_player.play(key, BLEND)


## The named animation out of a clip scene, looped, shared through the cache.
func _clip(scene: PackedScene, animation_name: String) -> Animation:
	if scene == null or animation_name.is_empty():
		return null
	var cache_key := "%s#%s" % [scene.resource_path, animation_name]
	if _clip_cache.has(cache_key):
		return _clip_cache[cache_key]
	var instance: Node = scene.instantiate()
	var source: AnimationPlayer = instance.find_child("AnimationPlayer", true, false)
	var clip: Animation = null
	if source != null and source.has_animation(animation_name):
		clip = source.get_animation(animation_name).duplicate()
		clip.loop_mode = Animation.LOOP_LINEAR
	else:
		push_warning(
			"CharacterRig: %s has no animation '%s'" % [scene.resource_path, animation_name]
		)
	instance.free()
	_clip_cache[cache_key] = clip
	return clip


func _paint(instance: Node) -> void:
	if skin == null:
		return
	var material := StandardMaterial3D.new()
	material.albedo_texture = skin
	material.roughness = 1.0
	material.metallic = 0.0
	for mesh_instance: MeshInstance3D in _meshes(instance):
		for surface: int in mesh_instance.mesh.get_surface_count():
			mesh_instance.set_surface_override_material(surface, material)


func _meshes(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	var mesh_instance := node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		found.append(mesh_instance)
	for child: Node in node.get_children():
		found.append_array(_meshes(child))
	return found
