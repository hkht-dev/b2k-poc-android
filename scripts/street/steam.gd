## Steam off the chai stall's kettle: a soft translucent column that rises,
## widens and fades, then starts again at the spout.
##
## GDD §5 Hollow Vale, the chai stall. One unshaded mesh, no particles: a
## cylinder scaled up and faded by hand each frame, one draw call and nothing
## on the CPU worth measuring. Warm white, never blue (GDD §10, Hollow Vale
## palette). Placed by tools/street_parts/chai_front.py.
##
## PLACEHOLDER for the painted steam of GDD §10 (a hand-drawn wisp sprite).
extends MeshInstance3D

## One wisp's life, from the spout to gone.
@export_range(0.5, 6.0, 0.1) var seconds := 2.4
## How far it rises in that time, in metres.
@export var rise := 0.6
## Its size at the spout; it ends about twice this.
@export var base_scale := Vector3(0.16, 0.3, 0.16)
@export var colour := Color(0.96, 0.94, 0.9, 0.32)

var _elapsed := 0.0
var _base_y := 0.0
var _material: StandardMaterial3D = null


func _ready() -> void:
	_base_y = position.y
	if mesh == null:
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.5
		cylinder.bottom_radius = 0.3
		cylinder.height = 1.0
		cylinder.radial_segments = 10
		cylinder.rings = 0
		mesh = cylinder
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.albedo_color = colour
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_apply(0.0)


func _process(delta: float) -> void:
	_elapsed = fmod(_elapsed + delta, seconds)
	_apply(_elapsed / seconds)


## Where the wisp is in its life: 0 at the spout, 1 gone.
func phase() -> float:
	return _elapsed / seconds


func _apply(k: float) -> void:
	scale = base_scale * (1.0 + k)
	position.y = _base_y + rise * k
	_material.albedo_color.a = colour.a * (1.0 - k) * (1.0 - k)
