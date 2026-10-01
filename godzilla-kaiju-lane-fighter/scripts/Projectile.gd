class_name Projectile
extends Node2D
## Shells, missiles, drones. Enemy-owned until swatted back by a tail whip
## (GDD 5.2: "Missiles can be swatted back with tail whip").

var game
var lane := G.LANE_GROUND
var vel := Vector2(-200, 0)
var speed := 200.0
var dmg := 6.0
var friendly := false
var swattable := true
var homing_t := 0.0
var life := 7.0
var spr: Sprite2D

const BODY_Y := -60.0  # projectiles fly at chest height of their lane

func setup(p_game, tex: String, p_lane: int, x: float, p_vel: Vector2, p_dmg: float, p_homing := 0.0) -> void:
	game = p_game
	lane = p_lane
	vel = p_vel
	speed = p_vel.length()
	dmg = p_dmg
	homing_t = p_homing
	position = Vector2(x, G.LANE_Y[lane] + BODY_Y)
	spr = Sprite2D.new()
	spr.texture = load("res://assets/sprites/fx/%s.png" % tex)
	spr.scale = Vector2(3, 3)
	add_child(spr)
	z_index = 25
	_orient()

func _orient() -> void:
	# missile art points left (nose at x=0)
	spr.rotation = vel.angle() + PI

func _process(delta: float) -> void:
	if game.frozen:
		return
	life -= delta
	if homing_t > 0.0 and not friendly and is_instance_valid(game.player):
		homing_t -= delta
		var target: Vector2 = game.player.position + Vector2(0, BODY_Y)
		var want := (target - position).normalized() * speed
		vel = vel.lerp(want, clampf(3.0 * delta, 0.0, 1.0))
	position += vel * delta
	_orient()
	lane = nearest_lane(position.y - BODY_Y)
	z_index = 20 + lane
	if friendly:
		_check_enemy_hit()
	else:
		_check_player_hit()
	if life <= 0.0 or position.x < -80.0 or position.x > 440.0 or position.y > 620.0:
		queue_free()

static func nearest_lane(y: float) -> int:
	var best := 0
	for i in 3:
		if absf(G.LANE_Y[i] - y) < absf(G.LANE_Y[best] - y):
			best = i
	return best

func _check_player_hit() -> void:
	var p: Player = game.player
	if p.state == "dead" or p.lane != lane or p.airborne:
		return
	if absf(p.position.x - position.x) < 30.0:
		p.take_damage(dmg, {"src_x": position.x - vel.x})
		_explode()

func _check_enemy_hit() -> void:
	for e in game.all_targets():
		if e.occupies(lane):
			var span: Vector2 = e.hit_span()
			if position.x >= span.x - 10.0 and position.x <= span.y + 10.0:
				e.take_hit(dmg * 2.5, {"pierce_armor": true, "reflected": true})
				_explode()
				return

func reflect(dir_x: float) -> void:
	friendly = true
	homing_t = 0.0
	life = 3.0
	vel = Vector2(dir_x * 480.0, 0.0)
	position.y = G.LANE_Y[lane] + BODY_Y
	modulate = Color(0.6, 1.6, 1.5)
	AudioManager.play_sfx("tail_whip", 0.0, 1.6)

func _explode() -> void:
	game.spawn_explosion(position)
	queue_free()
