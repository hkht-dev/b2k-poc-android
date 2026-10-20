## The traveler. Walks, runs after a held full push, walks to a tapped point,
## and climbs ledges without a jump button.
##
## GDD §6 "Movement and camera" and docs/BRIEF_AMENDMENT_1.md §A2–A3: auto-run
## at 85% deflection after 0.5 s; tap-to-walk steers to a point until the
## stick takes over. The movement vector arrives already camera-relative from
## the street; this script never reads the camera.
##
## The body wears the journey's outfit (GameState.outfit, data/outfits.json;
## owner request 2026-10-20, the showroom's wardrobe) and repaints when it
## changes, so a choice shows at once and a loaded journey comes back dressed.
##
## Rooftop running (GDD §3a "Hold to sprint; time jumps at ledges and
## cables", §16a): a run carried off a ledge vaults the gap to the next
## surface when one is in reach; otherwise the body falls, and a long fall
## ends in a brief stumble. Cables are walked by balance. There is still no
## jump button: the leap is the run meeting the edge.
extends CharacterBody3D

signal climb_started
signal climb_finished
## A run met an edge with a surface in reach: the body is in the air.
signal vault_started
## The feet are down on the far side; the run goes on.
signal vault_finished
## A fall from above STUMBLE_DROP ended: input is ignored for STUMBLE_SECONDS.
signal stumbled
## The first time the player moves under their own input. The hint listens.
signal moved_first_time

const WALK_SPEED := 2.2
const RUN_SPEED := 4.6
const AUTO_RUN_DELAY := 0.5
## Raw deflection that counts as a full push for the run timer (§A2).
const FULL_TILT := 0.85
const ACCELERATION := 12.0
const TURN_SPEED := 9.0
const GRAVITY := 18.0
const CLIMB_DURATION := 0.85
## PLACEHOLDER: four synthesised steps from tools/audio_parts/world.py,
## replaced by recorded steps per surface (GDD §10 "Sound"). One loop; the
## pitch tells a walk from a run, so there is nothing to cross-fade.
const FOOTSTEPS := preload("res://assets/audio/footsteps_pavement.ogg")
const FOOTSTEPS_WALK_PITCH := 1.0
const FOOTSTEPS_RUN_PITCH := 1.35
## Horizontal speed, m/s, below which the feet are still.
const FOOTSTEPS_MIN_SPEED := 0.3
## Tap-to-walk arrives within this of the point and stops (§A3).
const ARRIVE_DISTANCE := 0.45
## Highest ledge the feet walk straight over: kerbs (0.16 m) and the fountain
## coping, but not a wall. A CharacterBody3D has no step-up of its own, and
## without this the kerb between pavement and road is a wall.
const STEP_HEIGHT := 0.36
## What the player carries persists as a flag `carrying_<item>` (GDD §12: the
## flag model is the only state), so an autosave mid-carry comes back with
## the item in hand. Which items exist, and what they look like, is data on
## the scene (`carryables`).
const CARRY_PREFIX := "carrying_"
const DEFAULT_ITEM := "can"
## A vault: the leap from a ledge met at a run (GDD §16a), a short arc of
## this long that lands up to VAULT_REACH ahead.
const VAULT_DURATION := 0.6
## How far ahead of the feet the ground is read, and how deep a drop there
## makes an edge: a kerb or a parapet lip is not one, a storey is.
const EDGE_PROBE := 0.5
const EDGE_DROP := 1.0
## Surfaces are probed from the farthest reach to the nearest; the first with
## a clear way to it is the landing.
const VAULT_REACH := 3.5
const VAULT_REACH_MIN := 1.5
const VAULT_REACH_STEP := 0.5
## A landing may be this much higher or lower than the take-off.
const VAULT_LAND_ABOVE := 0.6
const VAULT_LAND_BELOW := 1.2
## Peak of the arc above the straight line between take-off and landing.
const VAULT_ARC := 0.6
## A fall from higher than this ends in a stumble: the stick is ignored for
## STUMBLE_SECONDS and the run timer starts over. Nothing else happens.
const STUMBLE_DROP := 4.0
const STUMBLE_SECONDS := 0.5
## A cable is a StaticBody3D in this group whose local Z runs along it. On
## one, the stick's push is kept along the cable and the body eases back to
## its line: balance is contextual, like the climb (GDD §6).
const CABLE_GROUP := "cable"
const CABLE_RECENTER := 8.0
const CABLE_RECENTER_MAX := 3.0
## Balance holds this long after the feet leave a cable, so a hop at a
## junction or a short drop onto the line does not hand the body back to
## the raw stick in mid-air.
const CABLE_GRACE := 0.5
const WORLD_LAYER := 1
## A surface is a landing when its normal is at least this upright.
const LANDING_NORMAL_Y := 0.7
const CHEST_HEIGHT := 1.0

## item id -> the scene shown in the hand (CLAUDE_CODE_BRIEF.md §4.4, §4.5).
@export var carryables: Dictionary = {}

var _move_input := Vector2.ZERO
var _deflection := 0.0
var _full_tilt_time := 0.0
var _is_running := false
var _run_time := 0.0
var _climb_from := Vector3.ZERO
var _climb_to := Vector3.ZERO
var _climb_elapsed := 0.0
var _is_climbing := false
var _walk_target := Vector3.ZERO
var _has_walk_target := false
var _has_moved := false
var _is_vaulting := false
var _vault_from := Vector3.ZERO
var _vault_to := Vector3.ZERO
var _vault_dir := Vector3.ZERO
var _vault_elapsed := 0.0
var _stumble_left := 0.0
var _was_on_floor := false
var _fall_from_y := 0.0
## Flat unit direction of the cable under the feet, or ZERO off a cable.
var _cable_axis := Vector3.ZERO
var _cable_origin := Vector3.ZERO
var _cable_grace := 0.0
var _footsteps: AudioStreamPlayer3D = null

## Standing on the fitting dais with the wardrobe open: input is ignored.
var _still := false
## The skin the scene gave the body, worn when the journey names no outfit.
var _scene_skin: Texture2D = null

@onready var _rig: CharacterRig = %Mesh


func _ready() -> void:
	_footsteps = AudioStreamPlayer3D.new()
	_footsteps.stream = FOOTSTEPS
	_footsteps.volume_db = -6.0
	_footsteps.unit_size = 3.0
	_footsteps.max_distance = 16.0
	add_child(_footsteps)
	_fall_from_y = global_position.y
	for item in carryables:
		if GameState.has_flag(CARRY_PREFIX + str(item)):
			_rig.carry(true, carryables[item])
			break
	_scene_skin = _rig.skin
	apply_outfit()
	GameState.outfit_changed.connect(_on_outfit_changed)


func _physics_process(delta: float) -> void:
	if _is_climbing:
		_advance_climb(delta)
		return
	if _is_vaulting:
		_advance_vault(delta)
		return
	if _still:
		return
	_advance_ground(delta)


## Dresses the body in the journey's outfit. An empty id, or one the data
## no longer knows, is the scene's own skin.
func apply_outfit() -> void:
	var texture: Texture2D = Outfits.skin_of(GameState.outfit)
	_rig.set_skin(texture if texture != null else _scene_skin)


## Holds the body where it stands (trying clothes on): the stick, the keys
## and a tap still arrive and do nothing until released.
func hold_still(on: bool) -> void:
	_still = on
	if on:
		velocity = Vector3.ZERO
		_has_walk_target = false


func is_held_still() -> bool:
	return _still


func _on_outfit_changed(_outfit_id: String) -> void:
	apply_outfit()


## Picks up an item: its flag is set and the body shows it in hand. One
## thing at a time; a second pick-up is refused.
func carry(item: String = DEFAULT_ITEM) -> bool:
	if is_carrying() or not carryables.has(item):
		return false
	GameState.set_flag(CARRY_PREFIX + item)
	_rig.carry(true, carryables[item])
	return true


## Whatever is in the hand leaves it (placed, or taken away by a scene).
func put_down() -> void:
	for item in carryables:
		GameState.clear_flag(CARRY_PREFIX + str(item))
	_rig.carry(false)


## Carrying `item`, or, with no item named, carrying anything.
func is_carrying(item: String = "") -> bool:
	if not item.is_empty():
		return GameState.has_flag(CARRY_PREFIX + item)
	for each in carryables:
		if GameState.has_flag(CARRY_PREFIX + str(each)):
			return true
	return false


func carried_item() -> String:
	for each in carryables:
		if GameState.has_flag(CARRY_PREFIX + str(each)):
			return str(each)
	return ""


## Sets this frame's movement wish (camera-relative, curved) and the raw
## deflection behind it. Any stick input cancels a tap-to-walk.
func set_move_input(input: Vector2, deflection: float = -1.0) -> void:
	_move_input = input if input.length() <= 1.0 else input.normalized()
	_deflection = clampf(deflection if deflection >= 0.0 else _move_input.length(), 0.0, 1.0)
	if _move_input.length() > 0.01:
		_has_walk_target = false


## Walks to a point on the ground, at walking pace, until arrival or until
## the stick takes over (§A3).
func walk_to(target: Vector3) -> void:
	_walk_target = Vector3(target.x, global_position.y, target.z)
	_has_walk_target = true


func is_walking_to() -> bool:
	return _has_walk_target


func is_running() -> bool:
	return _is_running


## Seconds of continuous running, for the camera's auto-align (§A4).
func run_time() -> float:
	return _run_time


func is_climbing() -> bool:
	return _is_climbing


## In the air between a ledge and the surface a run carried the body toward.
func is_vaulting() -> bool:
	return _is_vaulting


## Gathering itself after a long fall; the stick says nothing meanwhile.
func is_stumbling() -> bool:
	return _stumble_left > 0.0


## Standing on a cable (a body in the `cable` group), balancing along it.
func is_on_cable() -> bool:
	return _cable_axis != Vector3.ZERO


func has_moved() -> bool:
	return _has_moved


## The feet are sounding: the body is moving over the ground.
func is_footsteps_playing() -> bool:
	return _footsteps.playing


## The footsteps' pitch: FOOTSTEPS_WALK_PITCH or FOOTSTEPS_RUN_PITCH.
func footsteps_pitch() -> float:
	return _footsteps.pitch_scale


func begin_climb(exit: Vector3) -> bool:
	if _is_climbing or _is_vaulting:
		return false
	_is_climbing = true
	_climb_from = global_position
	_climb_to = exit
	_climb_elapsed = 0.0
	_full_tilt_time = 0.0
	_is_running = false
	_run_time = 0.0
	_has_walk_target = false
	velocity = Vector3.ZERO
	_update_footsteps()
	climb_started.emit()
	return true


func _advance_ground(delta: float) -> void:
	var wish := Vector3(_move_input.x, 0.0, _move_input.y)
	var strength := _move_input.length()
	var deflection := _deflection

	if _stumble_left > 0.0:
		# Landed hard: the body gathers itself and the stick says nothing.
		_stumble_left -= delta
		wish = Vector3.ZERO
		strength = 0.0
		deflection = 0.0
		_has_walk_target = false

	if _has_walk_target and strength < 0.01:
		var to_target := _walk_target - global_position
		to_target.y = 0.0
		if to_target.length() <= ARRIVE_DISTANCE:
			_has_walk_target = false
		else:
			wish = to_target.normalized()
			strength = 1.0
			deflection = 0.0

	if deflection >= FULL_TILT:
		_full_tilt_time += delta
	else:
		_full_tilt_time = 0.0
	_is_running = _full_tilt_time >= AUTO_RUN_DELAY
	_run_time = _run_time + delta if _is_running else 0.0

	_read_cable(delta)
	var recenter := Vector3.ZERO
	if is_on_cable():
		# Balance: only the push along the cable moves the body, and the body
		# eases back over the cable's line.
		wish = _cable_axis * wish.dot(_cable_axis)
		strength = minf(strength, wish.length())
		var off := global_position - _cable_origin
		off.y = 0.0
		off -= _cable_axis * off.dot(_cable_axis)
		recenter = (-off * CABLE_RECENTER).limit_length(CABLE_RECENTER_MAX)
	_update_footsteps()


## The steps loop while the body actually moves (the velocity after sliding,
## so pushing at a wall is silent), faster when running, and stop when still
## or climbing.
func _update_footsteps() -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if not _is_climbing and speed >= FOOTSTEPS_MIN_SPEED:
		_footsteps.pitch_scale = FOOTSTEPS_RUN_PITCH if _is_running else FOOTSTEPS_WALK_PITCH
		if not _footsteps.playing:
			_footsteps.play()
	elif _footsteps.playing:
		_footsteps.stop()

	var speed := RUN_SPEED if _is_running else WALK_SPEED
	var target := wish.normalized() * speed * strength if wish.length() > 0.001 else Vector3.ZERO
	target += recenter
	velocity.x = move_toward(velocity.x, target.x, ACCELERATION * delta)
	velocity.z = move_toward(velocity.z, target.z, ACCELERATION * delta)

	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta

	if wish.length() > 0.01:
		var facing := atan2(-wish.x, -wish.z)
		rotation.y = lerp_angle(rotation.y, facing, TURN_SPEED * delta)
		if not _has_moved:
			_has_moved = true
			moved_first_time.emit()

	if _try_vault():
		return
	_step_up(delta)
	move_and_slide()
	_track_fall()


## Lifts the body over a low ledge in its path. Three sweeps: is the way
## ahead blocked, is there room above, and is the way clear once raised. Only
## then does it rise; floor snapping settles it onto the ledge.
func _step_up(delta: float) -> void:
	if not is_on_floor():
		return
	var motion := Vector3(velocity.x, 0.0, velocity.z) * delta
	if motion.length() < 0.0005:
		return
	if not test_move(global_transform, motion):
		return
	var lift := Vector3.UP * STEP_HEIGHT
	if test_move(global_transform, lift):
		return
	if test_move(global_transform.translated(lift), motion):
		return
	global_position += lift


func _advance_climb(delta: float) -> void:
	_climb_elapsed += delta
	var t: float = clampf(_climb_elapsed / CLIMB_DURATION, 0.0, 1.0)
	var flat := Vector3(_climb_from.x, 0.0, _climb_from.z).lerp(
		Vector3(_climb_to.x, 0.0, _climb_to.z), smoothstep(0.35, 1.0, t)
	)
	var height: float = lerpf(_climb_from.y, _climb_to.y, smoothstep(0.0, 0.6, t))
	global_position = Vector3(flat.x, height, flat.z)
	if t >= 1.0:
		_is_climbing = false
		velocity = Vector3.ZERO
		_fall_from_y = global_position.y
		climb_finished.emit()


# -- rooftop running ----------------------------------------------------------


## A run meeting an edge: if the ground ahead falls away and a surface is in
## reach, the body leaps for it. Returns true when the leap began, in which
## case this frame's walk is skipped.
func _try_vault() -> bool:
	if not _is_running or not is_on_floor() or is_on_cable() or _stumble_left > 0.0:
		return false
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if flat.length() < WALK_SPEED:
		return false
	var dir := flat.normalized()
	if not _drop_ahead(dir):
		return false
	var landing: Variant = _find_landing(dir)
	if landing == null:
		return false
	_begin_vault(dir, landing)
	return true


## True when the ground EDGE_PROBE ahead of the feet is more than EDGE_DROP
## below them, or missing. A lip under STEP_HEIGHT is read as ground.
func _drop_ahead(dir: Vector3) -> bool:
	var ahead := global_position + dir * EDGE_PROBE
	var hit := _ray(ahead + Vector3.UP * (STEP_HEIGHT + 0.14), ahead - Vector3.UP * EDGE_DROP)
	return hit.is_empty()


## The farthest surface along [param dir] a vault can land on, or null: an
## upright face within the height window with nothing at chest height on the
## way to it.
func _find_landing(dir: Vector3) -> Variant:
	var reach := VAULT_REACH
	while reach >= VAULT_REACH_MIN - 0.001:
		var spot := global_position + dir * reach
		reach -= VAULT_REACH_STEP
		var hit := _ray(
			spot + Vector3.UP * (VAULT_LAND_ABOVE + 0.1),
			spot - Vector3.UP * (VAULT_LAND_BELOW + 0.1)
		)
		if hit.is_empty() or hit.normal.y < LANDING_NORMAL_Y:
			continue
		var land: Vector3 = hit.position
		if land.y > global_position.y + VAULT_LAND_ABOVE:
			continue
		if land.y < global_position.y - VAULT_LAND_BELOW:
			continue
		var chest := Vector3.UP * CHEST_HEIGHT
		if not _ray(global_position + chest, land + chest).is_empty():
			continue
		return land
	return null


func _begin_vault(dir: Vector3, landing: Vector3) -> void:
	_is_vaulting = true
	_vault_from = global_position
	_vault_to = landing + Vector3.UP * 0.02
	_vault_dir = dir
	_vault_elapsed = 0.0
	_has_walk_target = false
	velocity = Vector3.ZERO
	rotation.y = atan2(-dir.x, -dir.z)
	vault_started.emit()


func _advance_vault(delta: float) -> void:
	_vault_elapsed += delta
	var t: float = clampf(_vault_elapsed / VAULT_DURATION, 0.0, 1.0)
	var flat := Vector3(_vault_from.x, 0.0, _vault_from.z).lerp(
		Vector3(_vault_to.x, 0.0, _vault_to.z), t
	)
	var height: float = lerpf(_vault_from.y, _vault_to.y, t) + VAULT_ARC * 4.0 * t * (1.0 - t)
	global_position = Vector3(flat.x, height, flat.z)
	if t >= 1.0:
		_is_vaulting = false
		# Momentum carries over: the run goes on where the feet land.
		velocity = _vault_dir * RUN_SPEED
		_was_on_floor = true
		_fall_from_y = global_position.y
		vault_finished.emit()


## Remembers where the feet left the ground and, on landing, how far they
## fell. A fall from above STUMBLE_DROP costs STUMBLE_SECONDS of the stick,
## and nothing else: the GDD's "falling drops the player to the pavement;
## nothing is lost".
func _track_fall() -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		if _fall_from_y - global_position.y > STUMBLE_DROP:
			_stumble_left = STUMBLE_SECONDS
			_full_tilt_time = 0.0
			_is_running = false
			_run_time = 0.0
			stumbled.emit()
	elif _was_on_floor and not on_floor:
		_fall_from_y = global_position.y
	_was_on_floor = on_floor


## Reads what is under the feet: on a body in the `cable` group, the cable's
## flat direction and a point on its line; otherwise nothing. Off the floor,
## the last cable holds for CABLE_GRACE.
func _read_cable(delta: float) -> void:
	if not is_on_floor():
		_cable_grace -= delta
		if _cable_grace <= 0.0:
			_cable_axis = Vector3.ZERO
		return
	_cable_axis = Vector3.ZERO
	var hit := _ray(global_position + Vector3.UP * 0.3, global_position - Vector3.UP * 0.6)
	if hit.is_empty():
		return
	var cable := hit.collider as Node3D
	if cable == null or not cable.is_in_group(CABLE_GROUP):
		return
	var axis: Vector3 = cable.global_transform.basis.z
	axis.y = 0.0
	if axis.length() < 0.01:
		return
	_cable_axis = axis.normalized()
	_cable_origin = cable.global_position
	_cable_grace = CABLE_GRACE


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_LAYER)
	return get_world_3d().direct_space_state.intersect_ray(query)
