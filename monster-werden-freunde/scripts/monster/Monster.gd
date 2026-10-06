class_name Monster
extends PathFollow2D
## Ein Monster mit genau einem Bedürfnis (GDD Kap. 3).
## Es gibt KEINE Lebenspunkte, keinen Schaden und keinen Tod: Passende Hilfe senkt
## need_value. Bei 0 wird das Monster zum FREUND und läuft fröhlich ins Dorf.

signal need_changed(monster: Monster, old_value: float, new_value: float)
signal monster_became_friend(monster: Monster)
signal monster_arrived(monster: Monster, was_friend: bool)
## Unpassende Hilfe ("Das hilft nur ein bisschen").
signal weak_help(monster: Monster)
## Disco: das Monster fängt an zu tanzen.
signal started_dancing(monster: Monster)

enum State { WILD, IMPROVING, HAPPY, FRIEND, ARRIVED }

const HAPPY_SPEED_BONUS := 1.15
const FRIEND_SPEED := 1.6
const BASE_RADIUS := 34.0
const ARRIVE_ANIM := 0.9
## Nach einem Tanz läuft das Monster mindestens so lange weiter (kein Dauer-Festhalten).
const DANCE_IMMUNITY := 3.0
const FLY_SPEED := 190.0
const FLY_HEIGHT := 70.0

var data: MonsterData
var need_value: float = 100.0
var state: State = State.WILD
## Bereits fliegende, aber noch nicht angekommene Hilfe (vermeidet Verschwendung).
var incoming_help: float = 0.0

var _slow_left := 0.0
var _slow_amount := 0.0
var _t := 0.0
var _squash := 0.0
var _glow := 0.0
var _facing := 1.0
var _mood_shown := 0.0
var _arrive_t := 0.0
var _arrived_as_friend := false
var _last_x := 0.0
var _dance_left := 0.0
var _dance_immunity := 0.0
var _flying := false
var _fly_height := 0.0
var _fly_target := Vector2.ZERO


func setup(monster_data: MonsterData) -> void:
	data = monster_data
	need_value = data.max_need
	state = State.WILD
	_t = randf() * 10.0


func _ready() -> void:
	rotates = false
	loop = false
	add_to_group(&"monsters")
	_last_x = position.x


## Anteil des verbleibenden Bedürfnisses (1 = ganz wild, 0 = Freund).
func get_need_ratio() -> float:
	if data == null or data.max_need <= 0.0:
		return 0.0
	return clampf(need_value / data.max_need, 0.0, 1.0)


static func state_for_ratio(ratio: float) -> State:
	if ratio <= 0.0:
		return State.FRIEND
	if ratio <= 0.30:
		return State.HAPPY
	if ratio <= 0.70:
		return State.IMPROVING
	return State.WILD


func can_be_helped() -> bool:
	return state < State.FRIEND


func get_current_speed() -> float:
	var mult := 1.0
	match state:
		State.HAPPY:
			mult = HAPPY_SPEED_BONUS
		State.FRIEND:
			mult = data.friend_speed_mult
	if _slow_left > 0.0 and state < State.FRIEND:
		mult *= 1.0 - _slow_amount
	if is_dancing() and state < State.FRIEND:
		return 0.0
	return data.base_speed * mult


func is_dancing() -> bool:
	return _dance_left > 0.0


func is_flying() -> bool:
	return _flying


## Disco-Effekt: Monster bleibt stehen und tanzt. Das Bedürfnis ändert sich nicht.
func start_dance(duration: float) -> bool:
	if not can_be_helped() or _dance_left > 0.0 or _dance_immunity > 0.0:
		return false
	_dance_left = duration
	_dance_immunity = duration + DANCE_IMMUNITY
	started_dancing.emit(self)
	return true


## Mittelpunkt des Körpers in globalen Koordinaten (Ziel für Hilfs-Objekte).
func get_help_point() -> Vector2:
	return global_position + Vector2(0, -BASE_RADIUS * data.size_scale)


## Wie stark würde dieser Effekt wirken? (ohne ihn anzuwenden)
func preview_help(effect: HelpEffect) -> float:
	var amount := effect.amount_for(data.need_type) * (1.0 - float(data.effect_resistances.get(effect.tag, 0.0)))
	return clampf(amount, 0.0, need_value)


## Wendet eine Hilfe an. Gibt die tatsächliche Verringerung des Bedürfnisses zurück.
func apply_help(effect: HelpEffect) -> float:
	if not can_be_helped():
		return 0.0
	if effect.dance_duration > 0.0:
		start_dance(effect.dance_duration)
		return 0.0
	var matched := effect.helps(data.need_type)
	var amount := effect.amount_for(data.need_type) * (1.0 - float(data.effect_resistances.get(effect.tag, 0.0)))
	if amount <= 0.0:
		return 0.0
	var old := need_value
	need_value = maxf(0.0, need_value - amount)
	if need_value < 0.05:
		need_value = 0.0
	_glow = 1.0
	if amount >= 4.0:
		_squash = 1.0
	if matched and effect.slow_amount > 0.0:
		var res := float(data.effect_resistances.get(&"slow", 0.0))
		_slow_amount = effect.slow_amount * (1.0 - res)
		_slow_left = effect.slow_duration
	if not matched:
		weak_help.emit(self)
	need_changed.emit(self, old, need_value)
	_update_state()
	return old - need_value


func _update_state() -> void:
	if state >= State.FRIEND:
		return
	var new_state := state_for_ratio(get_need_ratio())
	if new_state == state:
		return
	state = new_state
	if state == State.FRIEND:
		need_value = 0.0
		incoming_help = 0.0
		_dance_left = 0.0
		if data.friend_flies:
			_start_flying()
		monster_became_friend.emit(self)


## Flügel: als Freund fliegt das Monster in Luftlinie direkt ins Dorf.
func _start_flying() -> void:
	var path := get_parent() as Path2D
	if path == null or path.curve == null or path.curve.point_count == 0:
		return
	_flying = true
	_fly_target = path.curve.get_point_position(path.curve.point_count - 1)


func _process(delta: float) -> void:
	_t += delta
	_squash = maxf(0.0, _squash - delta * 4.0)
	_glow = maxf(0.0, _glow - delta * 2.5)
	if _slow_left > 0.0:
		_slow_left -= delta
	_dance_left = maxf(0.0, _dance_left - delta)
	_dance_immunity = maxf(0.0, _dance_immunity - delta)
	_mood_shown = move_toward(_mood_shown, 1.0 - get_need_ratio(), delta * 1.8)
	if state == State.ARRIVED:
		_arrive_t += delta
		modulate.a = clampf(1.0 - _arrive_t / ARRIVE_ANIM, 0.0, 1.0)
		if _arrive_t >= ARRIVE_ANIM:
			queue_free()
		queue_redraw()
		return
	if _flying:
		_fly_height = move_toward(_fly_height, FLY_HEIGHT, delta * 120.0)
		position = position.move_toward(_fly_target, FLY_SPEED * delta)
		_facing = signf(_fly_target.x - position.x) if absf(_fly_target.x - position.x) > 1.0 else _facing
		if position.distance_to(_fly_target) < 2.0:
			_arrive()
		queue_redraw()
		return
	progress += get_current_speed() * delta
	var dx := position.x - _last_x
	if absf(dx) > 0.05:
		_facing = signf(dx)
	_last_x = position.x
	if progress_ratio >= 0.999:
		_arrive()
	queue_redraw()


func _arrive() -> void:
	_arrived_as_friend = state == State.FRIEND
	state = State.ARRIVED
	remove_from_group(&"monsters")
	monster_arrived.emit(self, _arrived_as_friend)


func _draw() -> void:
	if data == null:
		return
	var R := BASE_RADIUS * data.size_scale
	var offset := Vector2.ZERO
	if state == State.ARRIVED:
		var k := _arrive_t / ARRIVE_ANIM
		if _arrived_as_friend:
			offset = Vector2(k * 70.0, -sin(k * PI) * 60.0)
		else:
			offset = Vector2(k * 90.0, -absf(sin(k * PI * 3.0)) * 16.0)
	var rot := 0.0
	if _fly_height > 0.0:
		Icons.ellipse(self, offset, R * 0.7, R * 0.18, Color(0, 0, 0, 0.12))
		offset.y -= _fly_height + sin(_t * 6.0) * 4.0
	if is_dancing():
		rot = sin(_t * 9.0) * 0.28
		offset += Vector2(sin(_t * 9.0) * 6.0, -absf(sin(_t * 18.0)) * 10.0)
	draw_set_transform(offset, rot, Vector2(1.0 + 0.14 * _squash, 1.0 - 0.12 * _squash))
	var walking := (state != State.ARRIVED or not _arrived_as_friend) and not is_dancing() and not _flying
	MonsterArt.draw_monster(self, data.id, data.body_color, R, _mood_shown, _t, _facing, walking, _fly_height > 0.0)
	if is_dancing():
		for i in 2:
			var a := _t * 2.5 + i * PI
			Icons.note(self, Vector2(cos(a) * R * 1.4, -R * 1.4 + sin(a) * R * 0.5), 22, Color.from_hsv(fmod(_t * 0.5 + i * 0.5, 1.0), 0.7, 0.95))
	if state == State.FRIEND and data.friend_speed_mult > 2.0:
		for i in 3:
			var y := -R * (0.5 + i * 0.4)
			Icons.thick_line(self, Vector2(-_facing * R * 1.2, y), Vector2(-_facing * R * (1.7 + 0.2 * sin(_t * 30.0 + i)), y), Color(1.0, 0.92, 0.3, 0.9), 4.0)
	if _glow > 0.0:
		for i in 3:
			var a := _t * 3.0 + i * TAU / 3.0
			Icons.sparkle(self, Vector2(cos(a) * R * 1.2, -R + sin(a) * R * 0.9), 16.0 * _glow, Color(1, 1, 0.7, _glow))
	draw_set_transform(Vector2.ZERO)
	if state < State.FRIEND:
		_draw_need(R)
	elif state == State.FRIEND or (state == State.ARRIVED and _arrived_as_friend):
		Icons.heart(self, Vector2(offset.x, offset.y) + Vector2(0, -R * 2.3 - absf(sin(_t * 5.0)) * 8.0), 30, Color("ff5a87"))


func _draw_need(R: float) -> void:
	# Bedürfnis-Blase mit Icon (Farbe + Icon + Animation, nie nur Farbe)
	var bar_y := -R * 2.0 - 8.0
	if is_dancing():
		bar_y -= 10.0
	var bubble_c := Vector2(0, bar_y - 34.0)
	var wobble: float = sin(_t * 7.0) * 0.14 if state == State.WILD else 0.0
	var need_col := Needs.color_for(data.need_type)
	draw_circle(bubble_c + Vector2(10, 26), 5, Color.WHITE)
	draw_circle(bubble_c, 25, Color.WHITE)
	draw_arc(bubble_c, 25, 0, TAU, 28, need_col.darkened(0.2), 3.5, true)
	draw_set_transform(bubble_c, wobble)
	Icons.draw(self, Needs.icon_for(data.need_type), Vector2.ZERO, 34)
	draw_set_transform(Vector2.ZERO)
	# Fortschritt: Balken füllt sich, je glücklicher das Monster wird
	var w := 70.0
	var h := 12.0
	var rect := Rect2(-w * 0.5, bar_y - h * 0.5, w, h)
	Icons.rounded_rect(self, rect.grow(2.0), h * 0.5 + 2.0, Color(0.15, 0.17, 0.3, 0.55))
	var fill := 1.0 - get_need_ratio()
	if fill > 0.02:
		var fill_rect := Rect2(rect.position, Vector2(maxf(h, w * fill), h))
		Icons.rounded_rect(self, fill_rect, h * 0.5, Color("ffd23f").lerp(Color("5fd068"), fill))
	Icons.heart(self, Vector2(w * 0.5 + 6, bar_y), 18, Color("ff5a87"))
