extends Node3D
class_name ParallaxBackground3D
## Parallax-Hintergrund in drei Staffeln (GDD Abschnitt 8).
##
## Die Staffeln stehen unterschiedlich weit hinten; die Tiefe allein erzeugt
## schon den Versatz. Damit sie nie ausgehen, wandern je drei Kopien einer
## Staffel mit der Kamera mit und rasten auf ihrer Breite ein.

const LAYERS := [
	{"name": "Berge", "z": -150.0, "width": 320.0, "seed": 4711},
	{"name": "Stadt", "z": -62.0, "width": 150.0, "seed": 1312},
	{"name": "Wohnbloecke", "z": -26.0, "width": 74.0, "seed": 907},
]

@export var target_path: NodePath

var _target: Node3D = null
var _layers: Array[Dictionary] = []

func _ready() -> void:
	_build()
	_resolve_target()
	_follow()

func _process(_delta: float) -> void:
	if _target == null:
		_resolve_target()
	_follow()

func _build() -> void:
	var material := AssetKit.get_background_material()
	for index in LAYERS.size():
		var config: Dictionary = LAYERS[index]
		var mesh := _build_layer_mesh(index, config)
		var copies: Array[MeshInstance3D] = []
		for copy_index in 3:
			var instance := MeshInstance3D.new()
			instance.mesh = mesh
			instance.material_override = material
			instance.position = Vector3(0, 0, config["z"])
			# Hintergrund nie in Schatten oder Reflexionen einrechnen.
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(instance)
			copies.append(instance)
		_layers.append({"config": config, "copies": copies})

func _build_layer_mesh(index: int, config: Dictionary) -> ArrayMesh:
	var width: float = config["width"]
	var layer_seed: int = config["seed"]
	match index:
		0:
			return BackgroundKit.mountains(width, 52.0, layer_seed)
		1:
			return BackgroundKit.city_blocks(width, 12.0, 26.0, 8.0,
				Color(0.58, 0.62, 0.76, 0.0), layer_seed, true)
		_:
			return BackgroundKit.city_blocks(width, 7.0, 15.0, 6.0,
				Color(0.68, 0.67, 0.74, 0.0), layer_seed, false)

func _follow() -> void:
	if _target == null:
		return
	var camera_x := _target.global_position.x
	for layer in _layers:
		var width: float = layer["config"]["width"]
		var base := roundf(camera_x / width) * width
		var copies: Array = layer["copies"]
		for i in copies.size():
			(copies[i] as MeshInstance3D).position.x = base + float(i - 1) * width

func _resolve_target() -> void:
	if not target_path.is_empty():
		_target = get_node_or_null(target_path) as Node3D
	if _target == null:
		_target = get_viewport().get_camera_3d()
