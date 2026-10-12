class_name Food
extends Interactable
## Something to eat. Good food restores health and dexterity. Bad food (milk)
## gives the hedgehog a tummy ache and unlocks a real-world fact.

const KINDS := {
	"beetle": {"name": "beetle", "health": 0, "dexterity": 15.0, "bad": false},
	"worm": {"name": "earthworm", "health": 1, "dexterity": 10.0, "bad": false},
	"slug": {"name": "slug", "health": 1, "dexterity": 5.0, "bad": false},
	"apple": {"name": "fallen apple", "health": 1, "dexterity": 0.0, "bad": false},
	"milk": {"name": "milk", "health": -1, "dexterity": -10.0, "bad": true},
}

@export_enum("beetle", "worm", "slug", "apple", "milk") var kind: String = "beetle"
## Seconds until the food comes back. 0 = never.
@export var respawn_time := 45.0

## Sound played when eaten: crunchy beetles, munchy worms and slugs, slurpy milk.
const EAT_SOUNDS := {"beetle": "crunch", "worm": "munch", "slug": "munch", "apple": "crunch", "milk": "slurp"}

var _available := true
var _visual: Node3D
var _scent: Scent
var _crawl: AudioStreamPlayer3D


func _ready() -> void:
	super()
	_visual = Node3D.new()
	add_child(_visual)
	_build_visual()
	MeshUtil.merge(_visual)
	_scent = Scent.new()
	_scent.color = Scent.FOOD
	add_child(_scent)
	if kind == "beetle":
		# Beetles scuttle quietly in the leaves; you hear them when close.
		_crawl = Sound.attach_loop("crawl", self, -10.0, 4.0)
		_crawl.play(randf() * 2.0)


func get_prompt(_player: Hedgehog) -> String:
	if not _available:
		return ""
	var info: Dictionary = KINDS[kind]
	if kind == "milk":
		return "Drink the milk"
	return "Eat the %s" % info["name"]


func interact(player: Hedgehog) -> void:
	if not _available:
		return
	var info: Dictionary = KINDS[kind]
	player.eat(info["health"], info["dexterity"], info["bad"])
	Sound.play_at(EAT_SOUNDS[kind], global_position, -2.0, 0.1)
	if info["bad"]:
		Game.show_toast("Yuck! The milk gives the hedgehog a tummy ache.")
	else:
		Game.show_toast("Yum! A tasty %s." % info["name"])
	Game.unlock_fact(kind)
	_set_available(false)
	if respawn_time > 0.0:
		get_tree().create_timer(respawn_time).timeout.connect(_set_available.bind(true))


func is_available() -> bool:
	return _available


func _set_available(available: bool) -> void:
	_available = available
	_visual.visible = available
	_scent.active = available
	if not available:
		_scent.set_revealed(false)
	if _crawl:
		_crawl.playing = available


func _process(delta: float) -> void:
	if kind == "beetle" or kind == "worm":
		_visual.rotation.y += delta * 0.8


func _build_visual() -> void:
	match kind:
		"beetle":
			MeshUtil.add(_visual, MeshUtil.sphere(0.07), Color(0.1, 0.3, 0.2), Vector3(0.08, 0.05, 0), Vector3(1.0, 0.6, 1.4))
			MeshUtil.add(_visual, MeshUtil.sphere(0.035), Color(0.05, 0.05, 0.05), Vector3(0.08, 0.045, 0.1))
		"worm":
			for i in 5:
				var t := float(i) / 4.0
				MeshUtil.add(_visual, MeshUtil.sphere(0.03), Color(0.9, 0.55, 0.55),
						Vector3(0.12 * t - 0.06, 0.03, sin(t * PI * 1.5) * 0.04))
		"slug":
			MeshUtil.add(_visual, MeshUtil.capsule(0.04, 0.2), Color(0.55, 0.38, 0.2),
					Vector3(0, 0.035, 0), Vector3(1.0, 0.8, 1.0), Vector3(PI / 2, 0, 0))
			for side in [-1.0, 1.0]:
				MeshUtil.add(_visual, MeshUtil.cylinder(0.006, 0.006, 0.05), Color(0.45, 0.3, 0.15),
						Vector3(side * 0.015, 0.08, 0.09), Vector3.ONE, Vector3(0.5, 0, side * 0.3))
		"apple":
			MeshUtil.add(_visual, MeshUtil.sphere(0.1), Color(0.8, 0.15, 0.1), Vector3(0, 0.09, 0))
			MeshUtil.add(_visual, MeshUtil.cylinder(0.008, 0.008, 0.06), Color(0.35, 0.2, 0.1), Vector3(0, 0.2, 0))
		"milk":
			MeshUtil.add(_visual, MeshUtil.cylinder(0.16, 0.12, 0.05), Color(0.55, 0.7, 0.85), Vector3(0, 0.025, 0))
			MeshUtil.add(_visual, MeshUtil.cylinder(0.14, 0.14, 0.01), Color(0.98, 0.98, 0.95), Vector3(0, 0.05, 0))
