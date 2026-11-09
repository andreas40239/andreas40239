class_name Unit
extends Node3D
## Eine Kreatur, ein Wichtel oder ein Held – mit eigener KI.

enum S { IDLE, WANDER, JOB, FIGHT, SLEEP, EAT, TRAIN, ORDER, LEAVE }

const STATE_NAMES := {
	S.IDLE: "Untätig", S.WANDER: "Streift umher", S.JOB: "Arbeitet", S.FIGHT: "Kämpft",
	S.SLEEP: "Ruht sich aus", S.EAT: "Isst", S.TRAIN: "Trainiert", S.ORDER: "Hält Position",
	S.LEAVE: "Verlässt den Dungeon",
}
const INVALID := Vector2i(-1, -1)

var main
var world: World
var kind := ""
var def := {}
var team := 1
var hp := 100.0
var max_hp := 100.0
var level := 1
var xp := 0.0
var tile := Vector2i.ZERO
var path: Array = []
var path_i := 0
var state := S.IDLE
var sub := 0
var act_t := 0.0
var think_t := 0.0
var atk_t := 0.0
var repath_t := 0.0
var heal_t := 3.0
var target: Unit = null
var job := {}
var carried := 0
var hunger := 0.0
var tired := 0.0
var unhappy := 0.0
var order_tile := INVALID
var hold_t := 0.0
var lair_idx := -1
var model: Node3D
var ring: MeshInstance3D
var bar: MeshInstance3D
var selected := false
var anim_t := 0.0
var flash_t := 0.0
var bar_t := 0.0
var swing_t := 0.0
var moving := false
var dead := false
var hover_y := 0.0
var facing := 0.0
var snd_t := 0.0
var uid := 0


func setup(m, k: String, t: Vector2i, lvl := 1) -> void:
	main = m
	world = m.world
	kind = k
	def = Defs.UNITS[k]
	team = def.get("team", 1)
	level = lvl
	tile = t
	uid = randi()
	position = world.tile_center(t)
	_apply_level(true)
	hunger = randf() * 0.4
	tired = randf() * 0.3
	hover_y = def.get("fly", 0.0)
	model = Models.build(k)
	add_child(model)
	ring = Models.ring(team)
	ring.visible = false
	add_child(ring)
	bar = Models.health_bar()
	bar.position.y = def.get("bar", 1.6)
	bar.visible = false
	add_child(bar)
	think_t = randf() * 0.4
	facing = randf() * TAU


func display_name() -> String:
	return def["name"]


func _apply_level(full: bool) -> void:
	var old := max_hp
	max_hp = def["hp"] * (1.0 + 0.15 * (level - 1))
	if full:
		hp = max_hp
	else:
		hp += max_hp - old


func dmg() -> float:
	return def["dmg"] * (1.0 + 0.13 * (level - 1))


func wage() -> int:
	return int(def.get("wage", 0) * (1.0 + 0.2 * (level - 1)))


func state_text() -> String:
	if state == S.JOB and not job.is_empty():
		match job["type"]:
			"dig": return "Gräbt"
			"claim": return "Beansprucht Boden"
			"fortify": return "Befestigt Wand"
			"deposit": return "Bringt Gold"
	if team == 2 and state == S.IDLE:
		return "Marschiert zum Herz"
	return STATE_NAMES.get(state, "")


func set_selected(v: bool) -> void:
	selected = v
	ring.visible = v


# ---------------------------------------------------------------- Hauptschleife
func _process(delta: float) -> void:
	if dead:
		return
	anim_t += delta
	atk_t -= delta
	think_t -= delta
	swing_t -= delta
	snd_t -= delta
	flash_t = maxf(0.0, flash_t - delta * 3.0)
	bar_t -= delta
	if team == 1 and kind != "imp":
		hunger += delta / 170.0
		tired += delta / 230.0
		if world.room_count[Defs.R.LAIR] == 0:
			unhappy += delta * 0.0018
		if hunger >= 1.0 and world.room_count[Defs.R.FARM] == 0:
			unhappy += delta * 0.004
		if hunger < 1.0 and tired < 1.0:
			unhappy = maxf(0.0, unhappy - delta * 0.0008)
	if def.get("healer", false):
		heal_t -= delta
		if heal_t <= 0.0:
			heal_t = 3.0
			main.hero_heal(self)
	if think_t <= 0.0:
		think_t = 0.3 + randf() * 0.15
		if team == 2:
			_think_hero()
		elif kind == "imp":
			_think_imp()
		else:
			_think_creature()
	moving = false
	match state:
		S.FIGHT:
			_do_fight(delta)
		S.JOB:
			_do_job(delta)
		S.SLEEP, S.EAT, S.TRAIN:
			_do_need(delta)
		S.LEAVE:
			if _follow_path(delta):
				main.creature_left(self)
				return
		S.ORDER:
			if _follow_path(delta):
				hold_t -= delta
		_:
			_follow_path(delta)
			if team == 2:
				_hero_heart_attack()
	_animate(delta)


# ---------------------------------------------------------------- Bewegung
func go_to(t: Vector2i) -> bool:
	if t == tile:
		path = [t]
		path_i = 0
		return true
	var p := world.find_path(tile, t, team == 2)
	if p.is_empty():
		return false
	path = p
	path_i = 1 if p.size() > 1 else 0
	return true


func stop() -> void:
	path = []
	path_i = 0


func _follow_path(delta: float) -> bool:
	if path_i >= path.size():
		return true
	var nt: Vector2i = path[path_i]
	if not world.is_walkable(nt):
		if team == 2 and world.hero_diggable(nt):
			_face_to(world.tile_center(nt))
			swing_t = 0.2
			if snd_t <= 0.0:
				snd_t = 0.55
				Sfx.play_at("dig", global_position, -4.0)
				world.burst(world.tile_center(nt).lerp(position, 0.45) + Vector3(0, 1.0, 0), Color(0.45, 0.38, 0.3), 5, 2.0, 0.5)
			world.hero_dig(nt, def.get("digger", 1.0) * delta)
			return false
		stop()
		return true
	var tgt := world.tile_center(nt)
	var to := tgt - position
	to.y = 0.0
	var d := to.length()
	var step: float = def["speed"] * Defs.TILE * delta
	moving = true
	if d <= step:
		position.x = tgt.x
		position.z = tgt.z
		tile = nt
		path_i += 1
		return path_i >= path.size()
	position += to / d * step
	_face_dir(to)
	tile = world.pos_to_tile(position)
	return false


func nudge(v: Vector3) -> void:
	var np := position + v
	if world.is_walkable(world.pos_to_tile(np)):
		position = np


func _face_dir(v: Vector3) -> void:
	if v.length_squared() > 0.0001:
		facing = atan2(v.x, v.z)


func _face_to(p: Vector3) -> void:
	_face_dir(p - position)


func dist_tiles(u: Node3D) -> float:
	var d := u.position - position
	d.y = 0.0
	return d.length() / Defs.TILE


# ---------------------------------------------------------------- Kampf
func take_damage(amount: float, from: Unit) -> void:
	if dead:
		return
	hp -= amount
	flash_t = 1.0
	bar_t = 5.0
	Sfx.play_at("hit", global_position, -2.0)
	world.burst(global_position + Vector3(0, 0.8 + hover_y, 0), Color(0.75, 0.05, 0.05) if team == 2 or kind != "worm" else Color(0.5, 0.9, 0.2), 8, 2.5, 0.5)
	if hp <= 0.0:
		die(from)
		return
	if from != null and is_instance_valid(from) and not from.dead and state != S.FIGHT and state != S.LEAVE:
		if team == 2 or state != S.ORDER or dist_tiles(from) < 3.0:
			start_fight(from)


func die(killer: Unit) -> void:
	if dead:
		return
	dead = true
	Sfx.play_at("death", global_position)
	world.burst(global_position + Vector3(0, 0.6, 0), Color(0.6, 0.05, 0.05) if team == 2 else Color(0.35, 0.1, 0.4), 30, 4.0, 0.9)
	if killer != null and is_instance_valid(killer) and not killer.dead:
		killer.gain_xp(12.0 * level)
	main.on_unit_died(self, killer)
	queue_free()


func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)
	bar_t = 3.0


func gain_xp(v: float) -> void:
	if kind == "imp" and level >= 5:
		return
	xp += v
	var need := 40.0 * level
	if xp >= need and level < 10:
		xp -= need
		level += 1
		_apply_level(false)
		Sfx.play_at("levelup", global_position)
		world.burst(global_position + Vector3(0, 1.0, 0), Color(1.0, 0.85, 0.3), 24, 3.0, 1.0)
		if team == 1 and kind != "imp":
			main.message("%s erreicht Stufe %d!" % [display_name(), level], Color(1.0, 0.85, 0.4))


func start_fight(e: Unit) -> void:
	if kind == "imp" and team == 1:
		main.release_job(self)
		job = {}
	target = e
	state = S.FIGHT
	repath_t = 0.0
	sub = 0


func _do_fight(delta: float) -> void:
	if target == null or not is_instance_valid(target) or target.dead:
		target = null
		state = S.ORDER if hold_t > 0.0 and order_tile != INVALID else S.IDLE
		if state == S.ORDER:
			go_to(order_tile)
		return
	var d := dist_tiles(target)
	var rng: float = def["range"]
	if d <= rng:
		stop()
		_face_to(target.position)
		if atk_t <= 0.0:
			atk_t = def["cd"]
			swing_t = 0.35
			if def.get("ranged", false):
				main.spawn_projectile(self, target, null)
			else:
				Sfx.play_at("swing", global_position, -6.0)
				target.take_damage(dmg(), self)
		return
	if d > 16.0:
		target = null
		state = S.IDLE
		return
	repath_t -= delta
	if repath_t <= 0.0 or path_i >= path.size():
		repath_t = 0.6
		if not go_to(target.tile):
			target = null
			state = S.IDLE
			return
	_follow_path(delta)


func _hero_heart_attack() -> void:
	if main.state != "play":
		return
	var hc: Vector3 = world.tile_center(world.heart_tile)
	var d := (hc - position)
	d.y = 0
	var reach := maxf(2.6, def["range"])
	if d.length() / Defs.TILE <= reach:
		stop()
		_face_to(hc)
		if atk_t <= 0.0:
			atk_t = def["cd"]
			swing_t = 0.35
			if def.get("ranged", false):
				main.spawn_projectile(self, null, hc + Vector3(0, 2.2, 0))
			else:
				Sfx.play_at("swing", global_position, -6.0)
				main.damage_heart(dmg())


# ---------------------------------------------------------------- Helden-KI
func _think_hero() -> void:
	if state == S.FIGHT:
		return
	var e: Unit = main.find_enemy(self, 6.0)
	if e != null:
		start_fight(e)
		return
	var hc: Vector3 = world.tile_center(world.heart_tile)
	var d := Vector3(hc.x - position.x, 0, hc.z - position.z).length() / Defs.TILE
	if d <= maxf(2.6, def["range"]):
		return
	repath_t -= 0.35
	if path_i >= path.size() or repath_t <= 0.0:
		repath_t = 5.0
		var best := INVALID
		var bd := 1e9
		for t in world.heart_ring():
			var dd := Vector2(t - tile).length()
			if dd < bd:
				bd = dd
				best = t
		if best != INVALID:
			go_to(best)


# ---------------------------------------------------------------- Wichtel-KI
func _think_imp() -> void:
	if state == S.FIGHT:
		return
	var e: Unit = main.find_enemy(self, 1.6)
	if e != null:
		start_fight(e)
		return
	if state == S.ORDER:
		if path_i < path.size():
			return
		state = S.IDLE
	if state == S.JOB:
		if main.job_valid(self):
			return
		end_job()
	var j: Dictionary = main.get_imp_job(self)
	if not j.is_empty():
		job = j
		state = S.JOB
		sub = 0
		act_t = 0.0
		if not go_to(j["stand"]):
			end_job()
		return
	if state != S.WANDER or (path_i >= path.size() and randf() < 0.25):
		state = S.WANDER
		var t: Vector2i = main.random_own_tile_near(tile, 5)
		if t != INVALID:
			go_to(t)


func end_job() -> void:
	main.release_job(self)
	job = {}
	state = S.IDLE
	sub = 0
	stop()


func _do_job(delta: float) -> void:
	if job.is_empty():
		state = S.IDLE
		return
	if sub == 0:
		if _follow_path(delta):
			if tile != job["stand"]:
				if not go_to(job["stand"]):
					end_job()
				return
			sub = 1
			act_t = 0.0
		return
	act_t += delta
	var jt: Vector2i = job["tile"]
	if job["type"] != "claim" and job["type"] != "deposit":
		_face_to(world.tile_center(jt))
	match job["type"]:
		"dig":
			swing_t = 0.2
			if act_t >= 0.5:
				act_t -= 0.5
				var res := world.dig_hit(jt, 1.0 + 0.15 * (level - 1))
				Sfx.play_at("dig", global_position, -5.0)
				var wc := world.tile_center(jt).lerp(position, 0.45) + Vector3(0, 1.0, 0)
				world.burst(wc, Color(1.0, 0.8, 0.2) if res["gold"] > 0 else Color(0.45, 0.38, 0.3), 6, 2.2, 0.5)
				if res["gold"] > 0:
					carried += res["gold"]
					main.stats["gold_mined"] += res["gold"]
				if res["done"]:
					main.stats["dug"] += 1
					gain_xp(3.0)
					end_job()
				elif carried >= Defs.IMP_CARRY:
					end_job()
		"claim":
			swing_t = 0.0
			if act_t >= 1.6:
				main.claim_tile(jt)
				gain_xp(1.0)
				end_job()
		"fortify":
			swing_t = 0.2
			if act_t >= 2.6:
				main.fortify_tile(jt)
				gain_xp(1.0)
				end_job()
		"deposit":
			main.deposit_gold(self, jt)
			end_job()
		_:
			end_job()


# ---------------------------------------------------------------- Kreaturen-KI
func _think_creature() -> void:
	if state == S.LEAVE or state == S.FIGHT:
		return
	if unhappy >= 1.0:
		_start_leave()
		return
	var e: Unit = main.find_enemy(self, 7.0 if state != S.SLEEP else 3.0)
	if e != null:
		if world.find_path(tile, e.tile).size() > 0 or dist_tiles(e) <= def["range"]:
			start_fight(e)
			return
	if state == S.ORDER:
		if hold_t > 0.0:
			if path_i >= path.size() and tile != order_tile:
				go_to(order_tile)
			return
		state = S.IDLE
	if (state == S.SLEEP or state == S.EAT or state == S.TRAIN):
		return
	if hp < max_hp * 0.45 or tired >= 1.0:
		if _start_need(S.SLEEP):
			return
	if hunger >= 1.0:
		if _start_need(S.EAT):
			return
	if level < 10 and world.room_count[Defs.R.TRAINING] > 0 and main.total_gold() > 50 and randf() < 0.5:
		if _start_need(S.TRAIN):
			return
	if path_i >= path.size() and randf() < 0.3:
		state = S.WANDER
		var t: Vector2i = main.random_own_tile_near(tile, 6)
		if t != INVALID:
			go_to(t)


func _start_need(s: int) -> bool:
	var t := INVALID
	match s:
		S.SLEEP:
			t = main.get_lair_tile(self)
		S.EAT:
			t = main.random_room_tile(Defs.R.FARM, tile)
		S.TRAIN:
			t = main.random_room_tile(Defs.R.TRAINING, tile)
	if t == INVALID or not go_to(t):
		return false
	state = s
	sub = 0
	act_t = 0.0
	return true


func _do_need(delta: float) -> void:
	if sub == 0:
		if _follow_path(delta):
			sub = 1
			act_t = 0.0
		return
	act_t += delta
	match state:
		S.SLEEP:
			heal(max_hp * 0.05 * delta)
			tired = maxf(0.0, tired - delta * 0.08)
			if hp >= max_hp and tired <= 0.0:
				state = S.IDLE
		S.EAT:
			if fmod(act_t, 1.0) < delta:
				Sfx.play_at("eat", global_position, -6.0)
			if act_t >= 3.0:
				hunger = 0.0
				heal(max_hp * 0.1)
				state = S.IDLE
		S.TRAIN:
			swing_t = 0.2
			if fmod(act_t, 1.0) < delta:
				if not main.spend_gold(1):
					state = S.IDLE
					return
				if fmod(act_t, 2.0) < delta:
					Sfx.play_at("swing", global_position, -10.0)
			gain_xp(delta * 2.2)
			if act_t > 30.0 or hunger >= 1.0 or tired >= 1.0:
				state = S.IDLE


func _start_leave() -> void:
	var t: Vector2i = main.portal_exit_tile()
	state = S.LEAVE
	main.message("%s ist unzufrieden und verlässt deinen Dungeon!" % display_name(), Color(1.0, 0.5, 0.3))
	if t == INVALID or not go_to(t):
		main.creature_left(self)


func order_move(t: Vector2i) -> void:
	if kind == "imp":
		end_job()
	target = null
	state = S.ORDER
	order_tile = t
	hold_t = 40.0
	if not go_to(t):
		state = S.IDLE


func order_attack(e: Unit) -> void:
	hold_t = 0.0
	order_tile = INVALID
	start_fight(e)


# ---------------------------------------------------------------- Animation
func _animate(delta: float) -> void:
	var y := hover_y
	if hover_y > 0.0:
		y += sin(anim_t * 3.0 + float(uid % 7)) * 0.15
	elif moving:
		y += absf(sin(anim_t * 11.0)) * 0.1
	model.position.y = y
	model.rotation.y = lerp_angle(model.rotation.y, facing, minf(1.0, 12.0 * delta))
	var lying := state == S.SLEEP and sub == 1
	model.rotation.z = lerpf(model.rotation.z, 1.3 if lying else 0.0, minf(1.0, 5.0 * delta))
	var tool := model.get_node_or_null("tool")
	if tool:
		if swing_t > 0.0:
			tool.rotation.x = sin(anim_t * 14.0) * 1.1 + 0.4
		else:
			tool.rotation.x = lerpf(tool.rotation.x, 0.0, minf(1.0, 8.0 * delta))
	var wl := model.get_node_or_null("wingL")
	if wl:
		var f := sin(anim_t * 16.0) * 0.7
		wl.rotation.z = f
		model.get_node("wingR").rotation.z = -f
	if kind == "worm":
		for k in 5:
			var seg := model.get_node_or_null("seg%d" % k)
			if seg:
				seg.position.x = sin(anim_t * 6.0 - k * 0.9) * 0.08 * k * (1.0 if moving else 0.3)
	if kind == "imp":
		model.get_node("sack").visible = carried > 0
	var s := 1.0 + flash_t * 0.15
	model.scale = Vector3.ONE * s * (0.95 if kind == "imp" else 1.0)
	bar.visible = selected or bar_t > 0.0 or (hp < max_hp * 0.999 and team == 1)
	if bar.visible:
		bar.set_instance_shader_parameter("fill", clampf(hp / max_hp, 0.0, 1.0))
		var c := Color(0.3, 0.95, 0.35) if team == 1 else Color(0.95, 0.3, 0.25)
		bar.set_instance_shader_parameter("bar_color", c)
