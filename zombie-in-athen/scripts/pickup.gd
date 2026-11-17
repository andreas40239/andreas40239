class_name Pickup
extends Node3D
## Ein Upgrade auf der Karte: "garlic", "souvlaki" oder "melon".

var kind := "garlic"
var net_id := 0
var _model: Node3D
var _ring: MeshInstance3D
var _t := 0.0


func setup(p_kind: String) -> void:
	kind = p_kind
	_model = Props.pickup_model(kind)
	_model.scale = Vector3.ONE * 1.5
	add_child(_model)
	var col := Props.kind_color(kind)
	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 1.4
	light.omni_range = 2.6
	light.position.y = 0.8
	add_child(light)
	_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.4
	tm.outer_radius = 0.47
	tm.rings = 20
	tm.ring_segments = 5
	_ring.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(col.r, col.g, col.b, 0.7)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring.material_override = m
	_ring.position.y = 0.03
	_ring.scale.y = 0.15
	add_child(_ring)
	_t = randf() * 5.0


func _process(delta: float) -> void:
	_t += delta
	_model.position.y = 0.45 + sin(_t * 2.4) * 0.1
	_model.rotation.y = _t * 1.4
	var s := 1.0 + 0.12 * sin(_t * 4.0)
	_ring.scale = Vector3(s, 0.15, s)
