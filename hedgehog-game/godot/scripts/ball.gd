class_name Ball
extends Interactable
## A dog's ball. Nudge it and it rolls away; any dog nearby forgets about the
## hedgehog and runs off to play with it.

@export var color := Color(0.95, 0.3, 0.25)
@export var roll_distance := 4.5
## The ball stays inside this square (the garden's fences).
@export var bounds := 13.5

var _rolling := false
var _visual: Node3D


func _ready() -> void:
	radius = 0.8
	super()
	_visual = Node3D.new()
	add_child(_visual)
	MeshUtil.add(_visual, MeshUtil.sphere(0.13), color, Vector3(0, 0.13, 0))
	MeshUtil.add(_visual, MeshUtil.cylinder(0.132, 0.132, 0.03), Color(1, 1, 1), Vector3(0, 0.13, 0), Vector3.ONE, Vector3(0, 0, PI / 2))
	MeshUtil.merge(_visual)


func get_prompt(_player: Hedgehog) -> String:
	return "" if _rolling else "Nudge the ball"


func interact(player: Hedgehog) -> void:
	if _rolling:
		return
	var direction := global_position - player.global_position
	direction.y = 0.0
	if direction.length() < 0.05:
		direction = Vector3.FORWARD
	var target := global_position + direction.normalized() * roll_distance
	target.x = clampf(target.x, -bounds, bounds)
	target.z = clampf(target.z, -bounds, bounds)
	_rolling = true
	Sound.play_at("huff", global_position, -6.0, 0.2)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "global_position", target, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_visual, "rotation:x", _visual.rotation.x + TAU * 2.0, 1.4).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(func() -> void: _rolling = false)
	get_tree().call_group("dogs", "chase_ball", self)
	Game.show_toast("Off it goes! Dogs can't resist a ball.")
