class_name NestMaterial
extends Interactable
## Dry leaves, moss or straw. Collected and carried to a hibernation spot.

const NAMES := {"leaves": "dry leaves", "moss": "soft moss", "straw": "straw"}

@export_enum("leaves", "moss", "straw") var kind: String = "leaves"
@export var amount := 1

var _taken := false
var _visual: Node3D
var _scent: Scent


func _ready() -> void:
	super()
	_visual = Node3D.new()
	add_child(_visual)
	_build_visual()
	_scent = Scent.new()
	_scent.color = Scent.NEST_MATERIAL
	add_child(_scent)


func get_prompt(_player: Hedgehog) -> String:
	return "" if _taken else "Pick up the %s" % NAMES[kind]


func interact(player: Hedgehog) -> void:
	if _taken:
		return
	_taken = true
	player.add_nest_material(amount)
	Sound.play_at("rustle", global_position, 0.0, 0.1)
	player.remove_interactable(self)
	Game.show_toast("Picked up %s for the nest." % NAMES[kind])
	Game.unlock_fact("nest")
	_visual.visible = false
	_scent.active = false
	_scent.set_revealed(false)
	set_deferred("monitoring", false)


func is_taken() -> bool:
	return _taken


func _build_visual() -> void:
	match kind:
		"leaves":
			var colors := [Color(0.85, 0.45, 0.1), Color(0.7, 0.3, 0.1), Color(0.9, 0.65, 0.2), Color(0.6, 0.25, 0.08)]
			for i in 7:
				var pos := Vector3(randf_range(-0.15, 0.15), 0.01 + i * 0.012, randf_range(-0.15, 0.15))
				MeshUtil.add(_visual, MeshUtil.box(Vector3(0.14, 0.008, 0.09)), colors[i % colors.size()],
						pos, Vector3.ONE, Vector3(randf_range(-0.2, 0.2), randf() * TAU, 0))
		"moss":
			MeshUtil.add(_visual, MeshUtil.sphere(0.14), Color(0.3, 0.55, 0.2), Vector3(0, 0.03, 0), Vector3(1.2, 0.35, 1.0))
			MeshUtil.add(_visual, MeshUtil.sphere(0.08), Color(0.4, 0.65, 0.25), Vector3(0.1, 0.04, 0.05), Vector3(1.0, 0.5, 1.0))
		"straw":
			for i in 8:
				MeshUtil.add(_visual, MeshUtil.cylinder(0.006, 0.006, 0.3), Color(0.9, 0.8, 0.4),
						Vector3(0, 0.01 + i * 0.008, 0), Vector3.ONE, Vector3(PI / 2, randf() * TAU, 0))
