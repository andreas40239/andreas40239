class_name Scent
extends Node3D
## A glowing scent column that only shows while the hedgehog is sniffing.
## Green = food, yellow = nest material, blue = hibernation spot, red = danger.

const FOOD := Color(0.35, 1.0, 0.45)
const NEST_MATERIAL := Color(1.0, 0.85, 0.25)
const HIBERNATION := Color(0.35, 0.65, 1.0)
const DANGER := Color(1.0, 0.25, 0.2)

@export var color := FOOD
@export var height := 2.2

## Inactive scents (eaten food, picked-up material) never show.
var active := true

var _time := randf() * TAU
var _column: MeshInstance3D
var _ring: MeshInstance3D


func _ready() -> void:
	add_to_group("scent")
	_column = _make_glow(MeshUtil.cylinder(0.04, 0.22, height), 0.35)
	_column.position.y = height * 0.5
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.35
	ring_mesh.outer_radius = 0.45
	_ring = _make_glow(ring_mesh, 0.6)
	_ring.position.y = 0.03
	visible = false


func set_revealed(revealed: bool) -> void:
	visible = revealed and active


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	var pulse := 1.0 + sin(_time * 4.0) * 0.12
	_column.scale = Vector3(pulse, 1.0, pulse)
	_ring.scale = Vector3.ONE * (1.0 + fmod(_time, 1.5) * 0.6)


func _make_glow(mesh: PrimitiveMesh, alpha: float) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(color, alpha)
	mesh.material = mat
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance
