extends Node3D
## Fliegendes Geschoss (Feuerball, Pfeil, heiliges Licht).

var main
var src: Unit
var target: Unit
var target_pos := Vector3.ZERO
var heart := false
var damage := 10.0
var speed := 16.0
var color := Color.WHITE
var life := 4.0


func setup(m, s: Unit, t: Unit, pos, kind: String) -> void:
	main = m
	src = s
	target = t
	damage = s.dmg()
	if t == null:
		heart = true
		target_pos = pos
	else:
		target_pos = t.global_position + Vector3(0, 0.8, 0)
	global_position = s.global_position + Vector3(0, 1.0 + s.hover_y, 0)
	var mesh: Mesh
	match kind:
		"archer":
			color = Color(0.9, 0.8, 0.5)
			var b := BoxMesh.new()
			b.size = Vector3(0.05, 0.05, 0.7)
			mesh = b
			speed = 22.0
			Sfx.play_at("bow", global_position, -3.0)
		"priest":
			color = Color(1.0, 0.95, 0.55)
			var sp := SphereMesh.new()
			sp.radius = 0.16
			sp.height = 0.32
			mesh = sp
			speed = 14.0
			Sfx.play_at("fire", global_position, -6.0)
		_:
			color = Color(1.0, 0.45, 0.1)
			var sp2 := SphereMesh.new()
			sp2.radius = 0.2
			sp2.height = 0.4
			mesh = sp2
			speed = 13.0
			Sfx.play_at("fire", global_position, -3.0)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Models.mat(color, 6.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	if kind != "archer":
		var l := OmniLight3D.new()
		l.light_color = color
		l.omni_range = 3.5
		l.light_energy = 1.5
		add_child(l)


func _process(delta: float) -> void:
	life -= delta
	if target != null and is_instance_valid(target) and not target.dead:
		target_pos = target.global_position + Vector3(0, 0.8 + target.hover_y, 0)
	var to := target_pos - global_position
	var d := to.length()
	var step := speed * delta
	if d <= step or life <= 0.0:
		_hit()
		return
	global_position += to / d * step
	if to.length_squared() > 0.001:
		look_at(global_position + to, Vector3.UP)


func _hit() -> void:
	var s: Unit = src if is_instance_valid(src) else null
	if heart:
		main.damage_heart(damage)
	elif target != null and is_instance_valid(target) and not target.dead:
		target.take_damage(damage, s)
	main.world.burst(global_position, color, 10, 2.5, 0.5)
	queue_free()
