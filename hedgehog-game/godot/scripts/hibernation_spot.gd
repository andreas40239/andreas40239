class_name HibernationSpot
extends Interactable
## A place to build a nest and hibernate. Hibernating in a secure spot ends
## the level. Insecure spots (like a bonfire pile) refuse and teach a fact.

signal hibernate_requested(spot: HibernationSpot)

@export var secure := true
@export var required_material := 3
@export_enum("shed", "log_pile", "bonfire", "hedgehog_house") var look: String = "shed"
## Fact unlocked when the hedgehog checks this spot.
@export var fact_id := "shed"

var nest_amount := 0
## Set by the level when winter arrives: any secure spot will do.
var winter_override := false

var _nest: MeshInstance3D


func _ready() -> void:
	super()
	add_to_group("hibernation_spots")
	_build_visual()
	if secure:
		var scent := Scent.new()
		scent.color = Scent.HIBERNATION
		add_child(scent)


func can_hibernate() -> bool:
	return secure and (nest_amount >= required_material or winter_override)


func get_prompt(player: Hedgehog) -> String:
	if player.is_sleeping:
		return ""
	if not secure:
		return "Check this pile of sticks"
	if player.nest_material > 0:
		return "Add %d nest material to the nest" % player.nest_material
	if can_hibernate():
		return "Curl up and hibernate"
	return "Bring nest material here (%d/%d)" % [nest_amount, required_material]


func interact(player: Hedgehog) -> void:
	Game.unlock_fact(fact_id)
	if not secure:
		Sound.play_at("rustle", global_position, -4.0, 0.2)
		Game.show_toast("Not safe! Someone might light this pile as a bonfire.")
		return
	if player.nest_material > 0:
		nest_amount += player.take_nest_material()
		_update_nest()
		Sound.play_at("rustle", global_position, 0.0, 0.1)
		get_tree().create_timer(0.25).timeout.connect(Sound.play_at.bind("rustle", global_position, -3.0, 0.1))
		if can_hibernate():
			if Game.touch_mode:
				Game.show_toast("The nest is cosy enough. Tap the nest again to hibernate!")
			else:
				Game.show_toast("The nest is cosy enough. Press [E] again to hibernate!")
		else:
			Game.show_toast("The nest needs %d more." % (required_material - nest_amount))
		return
	if can_hibernate():
		hibernate_requested.emit(self)
	else:
		Game.show_toast("The nest needs more dry leaves or moss. Sniff for yellow scents!")


func _update_nest() -> void:
	var fill := clampf(float(nest_amount) / 8.0, 0.15, 1.0)
	_nest.visible = nest_amount > 0
	_nest.scale = Vector3(fill * 1.4, fill * 0.6, fill * 1.4)


func _build_visual() -> void:
	var visual := Node3D.new()
	add_child(visual)
	_nest = MeshUtil.add(visual, MeshUtil.sphere(0.4), Color(0.7, 0.42, 0.15), Vector3(0, 0.02, 0))
	_nest.visible = false
	match look:
		"log_pile":
			var bark := Color(0.4, 0.27, 0.15)
			for i in 3:
				MeshUtil.add(visual, MeshUtil.cylinder(0.14, 0.14, 1.4), bark,
						Vector3(-0.45, 0.14, -0.3 + i * 0.3), Vector3.ONE, Vector3(0, 0, PI / 2))
				MeshUtil.add(visual, MeshUtil.cylinder(0.14, 0.14, 1.4), bark,
						Vector3(0.45, 0.14, -0.3 + i * 0.3), Vector3.ONE, Vector3(0, 0, PI / 2))
			for i in 3:
				MeshUtil.add(visual, MeshUtil.cylinder(0.13, 0.13, 1.6), bark.lightened(0.1),
						Vector3(0, 0.42, -0.3 + i * 0.3), Vector3.ONE, Vector3(0, 0, PI / 2))
		"bonfire":
			for i in 9:
				var angle := TAU * i / 9.0
				MeshUtil.add(visual, MeshUtil.cylinder(0.03, 0.04, 1.3), Color(0.45, 0.32, 0.2),
						Vector3(cos(angle) * 0.3, 0.45, sin(angle) * 0.3), Vector3.ONE,
						Vector3(sin(angle) * 0.45, 0, -cos(angle) * 0.45))
			MeshUtil.add(visual, MeshUtil.sphere(0.5), Color(0.6, 0.4, 0.15), Vector3(0, 0.1, 0), Vector3(1.0, 0.4, 1.0))
		"hedgehog_house":
			# A little wooden house with a low entrance, built by a kind child.
			var wood := Color(0.6, 0.42, 0.25)
			MeshUtil.add(visual, MeshUtil.box(Vector3(1.0, 0.55, 0.9)), wood, Vector3(0, 0.275, -0.25))
			MeshUtil.add(visual, MeshUtil.box(Vector3(0.62, 0.05, 1.1)), wood.darkened(0.3), Vector3(-0.28, 0.66, -0.25), Vector3.ONE, Vector3(0, 0, 0.5))
			MeshUtil.add(visual, MeshUtil.box(Vector3(0.62, 0.05, 1.1)), wood.darkened(0.3), Vector3(0.28, 0.66, -0.25), Vector3.ONE, Vector3(0, 0, -0.5))
			MeshUtil.add(visual, MeshUtil.box(Vector3(0.22, 0.2, 0.02)), Color(0.08, 0.06, 0.05), Vector3(0, 0.1, 0.21))
			MeshUtil.add(visual, MeshUtil.box(Vector3(0.12, 0.03, 0.12)), Color(0.9, 0.85, 0.75), Vector3(0.35, 0.5, 0.21))
		"shed":
			pass  # The shed (or decking) itself is part of the level scenery.
	MeshUtil.merge(visual, [_nest])
