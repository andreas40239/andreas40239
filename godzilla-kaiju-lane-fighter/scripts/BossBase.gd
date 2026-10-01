class_name BossBase
extends Node2D
## Shared boss plumbing: HP/phases, tells, hit flash, death.

signal boss_died
signal hp_changed(ratio: float)

var game
var player: Player
var hp := 400.0
var max_hp := 400.0
var phase := 1
var state := "intro"
var state_t := 0.0
var atk_cd := 2.0
var spr: Sprite2D
var _anim_t := 0.0
var _hit_done := false
var _speed_mult := 1.0
var mini := false            # mini-boss: lives in the enemy list, no boss bar
var phase_marks: Array = []  # HP ratios shown as markers on the boss bar
var base_mod := Color(1, 1, 1)

func _make_sprite(tex: String, hframes: int, sc: float, frame_h: float) -> void:
	spr = Sprite2D.new()
	spr.texture = load("res://assets/sprites/characters/%s.png" % tex)
	spr.hframes = hframes
	spr.scale = Vector2(sc, sc)
	spr.position = Vector2(0, -frame_h * sc * 0.5)
	add_child(spr)

func occupies(l: int) -> bool:
	return l in [G.LANE_MID, G.LANE_GROUND]

func hit_span() -> Vector2:
	return Vector2(position.x - 90.0, position.x + 40.0)

func grabbable() -> bool:
	return false

func begin_grabbed() -> void:
	pass

func _tell(sfx: String, col := Color(1.7, 1.15, 1.15)) -> void:
	if sfx != "":
		AudioManager.play_sfx(sfx)
	spr.modulate = col

func _clear_tell() -> void:
	spr.modulate = base_mod

func _wind_time(base: float) -> float:
	return (base + GameState.tell_bonus()) / _speed_mult

func _goto(s: String) -> void:
	state = s
	state_t = 0.0
	_hit_done = false

func _hit_player(amount: float, opts := {}) -> void:
	opts["src_x"] = position.x
	player.take_damage(amount, opts)

func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)
	emit_signal("hp_changed", hp / max_hp)

## Applies damage + flash. Returns false if the boss ignored the hit.
func _apply_damage(amount: float) -> bool:
	if state in ["dead", "intro"]:
		return false
	hp -= amount
	AudioManager.play_sfx("hit", -2.0)
	spr.modulate = Color(3, 3, 3)
	var tw := create_tween()
	tw.tween_property(spr, "modulate", base_mod, 0.12)
	emit_signal("hp_changed", maxf(hp, 0.0) / max_hp)
	if hp <= 0.0:
		_die()
	return true

func _die() -> void:
	state = "dead"
	game.add_score(G.SCORE["trex" if mini else "boss"])
	AudioManager.play_sfx("boss_roar", 0.0, 0.7)
	game.shake(12.0 if not mini else 6.0)
	for i in (5 if not mini else 2):
		game.spawn_explosion(position + Vector2(randf_range(-60, 40), randf_range(-160, -20)))
	var tw := create_tween()
	tw.tween_property(spr, "modulate", Color(2, 0.5, 0.5, 0.0), 1.2)
	tw.tween_callback(func():
		emit_signal("boss_died")
		queue_free())
