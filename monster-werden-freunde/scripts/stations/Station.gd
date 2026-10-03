class_name Station
extends Node2D
## Eine Hilfsstation (GDD Kap. 4, 8.4). Kennt keine Monsterklassen-Details:
## sucht Monster in Reichweite, wählt per TargetStrategy ein Ziel und ruft apply_help() auf.

const AURA_TICK := 0.25
const SOUNDS := {&"bubble": &"bubble", &"cookie": &"cookie", &"wind": &"wind"}

var data: StationData
var spot: BuildSpot
var level: int = 1
## &"range" (+20 % Reichweite) oder &"power" (+25 % Wirkung) ab Stufe 2.
var upgrade_path: StringName = &""
## Kumulierte Investition (Bau + Upgrade) für den Verkaufswert.
var invested: int = 0
var selected := false:
	set(value):
		selected = value
		queue_redraw()

var _cooldown := 0.0
var _aura_timer := 0.0
var _fx_timer := 0.0
var _t := 0.0
var _activity := 0.0
var _pop := 1.0
var _projectiles_root: Node2D
var _fx_root: Node2D


func setup(station_data: StationData, build_spot: BuildSpot, projectiles_root: Node2D, fx_root: Node2D) -> void:
	data = station_data
	spot = build_spot
	_projectiles_root = projectiles_root
	_fx_root = fx_root
	_t = randf() * 5.0


func get_range() -> float:
	return data.help_range * (1.2 if upgrade_path == &"range" else 1.0)


func get_power() -> float:
	return 1.25 if upgrade_path == &"power" else 1.0


## 75 % der kumulierten Investition (GDD 2.2).
func get_sell_value() -> int:
	return roundi(invested * 0.75)


func apply_upgrade(path: StringName) -> void:
	level = 2
	upgrade_path = path
	_pop = 1.0


## Erzeugt den Hilfs-Effekt dieser Station (bei Auren pro Tick skaliert).
func make_effect(scale: float = 1.0) -> HelpEffect:
	var e := HelpEffect.new()
	var weakest := INF
	for need in data.need_strengths:
		var v := float(data.need_strengths[need]) * get_power() * scale
		e.strengths[int(need)] = v
		weakest = minf(weakest, v)
	e.fallback_amount = 0.0 if data.is_aura or weakest == INF else weakest * data.mismatch_factor
	e.tag = data.effect_tag
	e.slow_amount = data.slow_amount
	e.slow_duration = data.slow_duration
	return e


func monsters_in_range() -> Array[Monster]:
	var result: Array[Monster] = []
	var r := get_range()
	var r2 := r * r
	for node in get_tree().get_nodes_in_group(&"monsters"):
		var m := node as Monster
		if m and m.can_be_helped() and m.global_position.distance_squared_to(global_position) <= r2:
			result.append(m)
	return result


func _process(delta: float) -> void:
	_t += delta
	_activity = maxf(0.0, _activity - delta * 1.2)
	_pop = maxf(0.0, _pop - delta * 2.5)
	if data.is_aura:
		_process_aura(delta)
	else:
		_process_shooter(delta)
	queue_redraw()


func _process_aura(delta: float) -> void:
	_aura_timer -= delta
	_fx_timer -= delta
	if _aura_timer > 0.0:
		return
	_aura_timer += AURA_TICK
	var effect := make_effect(AURA_TICK)
	var any := false
	for m in monsters_in_range():
		if data.helps_need(m.data.need_type):
			m.apply_help(effect)
			any = true
	if any:
		_activity = 1.0
		if _fx_timer <= 0.0 and _fx_root:
			_fx_timer = 0.8
			var kind: Fx.Kind = Fx.Kind.NOTES if data.effect_tag == &"music" else Fx.Kind.ZZZ
			Fx.spawn(_fx_root, kind, _fx_root.to_local(global_position + Vector2(0, -110)))


func _process_shooter(delta: float) -> void:
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var target := pick_target()
	if target == null:
		_cooldown = 0.0
		return
	_cooldown = data.cooldown
	_fire(target)


## Zielwahl nach TargetStrategy (GDD 8.4).
func pick_target() -> Monster:
	var candidates: Array[Monster] = []
	for m in monsters_in_range():
		if m.need_value - m.incoming_help > 0.01:
			candidates.append(m)
	if candidates.is_empty():
		return null
	var pool := candidates
	if data.target_strategy == StationData.TargetStrategy.MATCHING_FIRST:
		var matching: Array[Monster] = []
		for m in candidates:
			if data.helps_need(m.data.need_type):
				matching.append(m)
		if not matching.is_empty():
			pool = matching
	var best: Monster = null
	var best_score := -INF
	for m in pool:
		var score := 0.0
		match data.target_strategy:
			StationData.TargetStrategy.MOST_NEED:
				score = m.need_value
			StationData.TargetStrategy.FASTEST:
				score = m.get_current_speed()
			_:
				score = m.progress
		if score > best_score:
			best_score = score
			best = m
	return best


func _fire(target: Monster) -> void:
	var effect := make_effect()
	var p := HelpProjectile.new()
	var muzzle := Vector2(0, -70)
	if data.projectile == &"bubble":
		muzzle = Vector2(38, -100)
	elif data.projectile == &"wind":
		muzzle = Vector2(0, -92)
	p.position = _projectiles_root.to_local(global_position + muzzle)
	p.setup(data.projectile, target, effect, _fx_root)
	_projectiles_root.add_child(p)
	_activity = 1.0
	AudioManager.play(SOUNDS.get(data.projectile, &"bubble"), 0.12, -9.0)


func _draw() -> void:
	if data == null:
		return
	if selected:
		Icons.ellipse_outline(self, Vector2(0, 2), 64, 26, Color("ffd23f"), 6.0)
	var s := 1.0 + 0.22 * sin(_pop * PI)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, 2.0 - s))
	StationArt.draw_station(self, data.id, _t, _activity, level, upgrade_path)
	draw_set_transform(Vector2.ZERO)
