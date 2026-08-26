# Battle camera: pinch-zoom + pan anytime, auto zoom-out on fire,
# projectile tracking and post-explosion linger (GDD section 7).
class_name BattleCam
extends Camera2D

const MIN_ZOOM := 0.55
const MAX_ZOOM := 3.0

var world_w := 2400.0
var top_y := -350.0
var bottom_y := 1100.0

var follow_target: Node2D = null
var _touches := {}
var _pinch_dist := 0.0
var _shake := 0.0
var _tween: Tween

func _ready() -> void:
	make_current()
	zoom = Vector2.ONE

func begin_follow(t: Node2D) -> void:
	follow_target = t

func end_follow() -> void:
	follow_target = null

func fly_to(pos: Vector2, target_zoom: float, dur := 0.8) -> void:
	end_follow()
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(self, "position", _clamped(pos, target_zoom), dur)
	_tween.parallel().tween_property(self, "zoom", Vector2.ONE * target_zoom, dur)

func zoom_out_for_flight(shooter_pos: Vector2) -> void:
	# GDD 7: zoom out wide so source and target area are visible.
	fly_to(Vector2(world_w * 0.5, 320.0), MIN_ZOOM, 0.45)

func shake(amount: float) -> void:
	if G.settings["shake"]:
		_shake = maxf(_shake, amount)

func _process(delta: float) -> void:
	if follow_target and is_instance_valid(follow_target):
		position = _clamped(position.lerp(follow_target.position, minf(1.0, delta * 6.0)), zoom.x)
	if _shake > 0.1:
		_shake = lerpf(_shake, 0.0, minf(1.0, delta * 8.0))
		offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
	else:
		offset = Vector2.ZERO

func _clamped(pos: Vector2, z: float) -> Vector2:
	var vp := get_viewport_rect().size
	var half := vp / z * 0.5
	var min_x: float = minf(half.x, world_w * 0.5)
	var max_x: float = maxf(world_w - half.x, world_w * 0.5)
	pos.x = clampf(pos.x, min_x, max_x)
	pos.y = clampf(pos.y, top_y + half.y, bottom_y - half.y * 0.4)
	return pos

# Called by the battle scene from _unhandled_input (touches that no UI took).
func handle_touch(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		if _touches.size() == 2:
			var ks := _touches.keys()
			_pinch_dist = (_touches[ks[0]] as Vector2).distance_to(_touches[ks[1]])
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() == 1:
			end_follow()
			if _tween and _tween.is_valid():
				_tween.kill()
			position = _clamped(position - event.relative / zoom.x, zoom.x)
		elif _touches.size() == 2:
			var ks := _touches.keys()
			var d := (_touches[ks[0]] as Vector2).distance_to(_touches[ks[1]])
			if _pinch_dist > 1.0:
				var nz: float = clampf(zoom.x * (d / _pinch_dist), MIN_ZOOM, MAX_ZOOM)
				zoom = Vector2.ONE * nz
				position = _clamped(position, nz)
			_pinch_dist = d
	elif event is InputEventMouseButton and event.pressed:
		# Desktop testing convenience: wheel zoom.
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = Vector2.ONE * clampf(zoom.x * 1.1, MIN_ZOOM, MAX_ZOOM)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = Vector2.ONE * clampf(zoom.x / 1.1, MIN_ZOOM, MAX_ZOOM)
