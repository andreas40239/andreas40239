class_name HelpProjectile
extends Node2D
## Sichtbares Hilfs-Objekt (Seifenblase, Keks, Luftwirbel) - niemals eine Waffe.
## Beim Ankommen löst es ausschließlich einen HelpEffect aus.

const SPEED := 640.0

var kind: StringName
var target: Monster
var effect: HelpEffect
var expected := 0.0
var _fx_root: Node2D
var _t := 0.0


func setup(projectile_kind: StringName, monster: Monster, help: HelpEffect, fx_root: Node2D) -> void:
	kind = projectile_kind
	target = monster
	effect = help
	_fx_root = fx_root
	expected = monster.preview_help(help)
	monster.incoming_help += expected


func _release() -> void:
	if is_instance_valid(target):
		target.incoming_help = maxf(0.0, target.incoming_help - expected)
	expected = 0.0


func _process(delta: float) -> void:
	_t += delta
	if not is_instance_valid(target) or not target.can_be_helped():
		_release()
		if _fx_root:
			Fx.spawn(_fx_root, Fx.Kind.SPARKLE, _fx_root.to_local(global_position), {"life": 0.4})
		queue_free()
		return
	var goal := target.get_help_point()
	var to := goal - global_position
	var step := SPEED * delta
	if to.length() <= step + 8.0:
		_release()
		target.apply_help(effect)
		if _fx_root:
			var fx_kind := Fx.Kind.BUBBLES
			if kind == &"cookie":
				fx_kind = Fx.Kind.CRUMBS
			elif kind == &"wind":
				fx_kind = Fx.Kind.SPARKLE
			Fx.spawn(_fx_root, fx_kind, _fx_root.to_local(goal))
		queue_free()
		return
	global_position += to.normalized() * step
	queue_redraw()


func _draw() -> void:
	match kind:
		&"bubble":
			var r := 13.0 + sin(_t * 12.0) * 1.5
			draw_circle(Vector2.ZERO, r, Color(0.7, 0.9, 1.0, 0.45))
			draw_arc(Vector2.ZERO, r, 0, TAU, 20, Color(0.3, 0.6, 0.95), 2.5, true)
			draw_arc(Vector2.ZERO, r * 0.6, PI * 1.1, PI * 1.5, 6, Color.WHITE, 2.5, true)
		&"cookie":
			draw_set_transform(Vector2.ZERO, _t * 8.0)
			Icons.cookie(self, Vector2.ZERO, 26)
			draw_set_transform(Vector2.ZERO)
		&"wind":
			for i in 3:
				var a := _t * 14.0 + i * TAU / 3.0
				draw_arc(Vector2.ZERO, 8.0 + i * 5.0, a, a + 2.2, 10, Color(1, 1, 1, 0.9 - i * 0.2), 3.5, true)
		_:
			Icons.sparkle(self, Vector2.ZERO, 22, Color(1, 1, 0.7))
