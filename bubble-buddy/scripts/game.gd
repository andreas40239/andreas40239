class_name BBGame
extends Node2D
## The gameplay scene: scrolling, spawning, collisions, checkpoints.
##
## Design rules enforced here:
##   * There is no failure state. Nothing kills, ends or resets a run.
##   * The scroll speed is constant. It never ramps up on its own.
##   * Every spawn pattern leaves a corridor wide enough to swim through.

signal exit_requested(summary: Dictionary)

const DESIGN_VIEW := Vector2(1080, 1920)
const BASE_SCROLL := 130.0             # 20% of a typical shmup scroll
const CURRENT_SCROLL_BOOST := 1.75
const PLAY_TOP_RATIO := 0.40           # player roams the bottom 60%
const PEARLS_PER_CHEST := 100
const GATE_PEARLS := 300               # GDD 5.5
const GATE_DISTANCE := 9000.0          # fallback so a gate always arrives
const SPAWN_INTERVAL := 360.0
const PEARL_DROP := 5

## The logical play area. Read from the viewport so the game fills a 4:3 tablet
## and a tall phone equally well instead of assuming one fixed aspect ratio.
var view := DESIGN_VIEW
var floor_y := DESIGN_VIEW.y * 0.93
var despawn_y := DESIGN_VIEW.y + 360.0

var scroll_speed := BASE_SCROLL
var pearls_run := 0
var pearls_collected := 0              # monotonic; drives chest and gates
var chest_progress := 0
var chests_filled := 0
var gates_run := 0
var zone := 0
var run_time := 0.0
var starfish_found := 0
var friends_freed := 0

var fx: BBFx
var background: BBBackground
var player: BBPlayer
var hud: BBHud

var _entities: Array[BBEntity] = []
var _bubbles: Array[BBBubble] = []
var _friends: Array[BBFriend] = []
var _entity_root: Node2D
var _spawn_accum := 0.0
var _distance_since_gate := 0.0
var _pearls_since_gate := 0
var _gate: BBCoralGate = null
var _pearl_combo := 0
var _pearl_combo_t := 0.0
var _last_hit_time := -99.0
var _paused := false
var _finished := false
var _rainbow_was_active := false
var _overlay: CanvasLayer = null
var _daily_ball_spawned := false
var _steer_touch := -1
var _steer_offset := Vector2.ZERO
var _touch_start := Vector2.ZERO
var _touch_time := 0.0
var _keyboard_target := Vector2.ZERO


func _ready() -> void:
	_read_view()
	get_viewport().size_changed.connect(_on_view_changed)

	background = BBBackground.new()
	background.view_size = view
	add_child(background)

	_entity_root = Node2D.new()
	add_child(_entity_root)

	fx = BBFx.new()
	fx.z_index = 30
	add_child(fx)

	player = BBPlayer.new()
	player.position = Vector2(view.x * 0.5, view.y * 0.72)
	player.target = player.position
	player.fired_small_bubble.connect(_on_small_bubble)
	player.fired_big_bubble.connect(_on_big_bubble)
	add_child(player)
	_keyboard_target = player.position

	hud = BBHud.new()
	hud.bubble_pressed.connect(func(): player.start_charge())
	hud.bubble_released.connect(func(): player.release_charge())
	hud.pause_requested.connect(_show_pause)
	add_child(hud)
	hud.layout(view)

	SaveData.refresh_daily()
	Sound.set_zone_music(zone)
	Sound.start_music()
	hud.banner(Zones.zone_name(zone), "Let's find the Queen Pearl!", 3.0)
	# A friendly opening handful of pearls so the first seconds always reward.
	_spawn_pearl_stream(view.x * 0.5, -120.0, 10)


func _read_view() -> void:
	var v := get_viewport_rect().size
	if v.x > 1.0 and v.y > 1.0:
		view = v
	floor_y = view.y * 0.93
	despawn_y = view.y + 360.0


func _on_view_changed() -> void:
	_read_view()
	background.view_size = view
	hud.layout(view)


func player_bounds() -> Rect2:
	var top := view.y * PLAY_TOP_RATIO
	return Rect2(Vector2(80.0, top), Vector2(view.x - 160.0, view.y - top - 90.0))


# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _paused or _finished:
		return

	run_time += delta
	SaveData.playtime_seconds += delta

	if SaveData.session_limit_minutes > 0 and run_time >= SaveData.session_limit_minutes * 60.0:
		_show_rest()
		return

	scroll_speed = BASE_SCROLL * SaveData.scroll_speed_scale
	if player.current > 0.0:
		scroll_speed *= CURRENT_SCROLL_BOOST
	background.scroll_speed = scroll_speed

	_read_input(delta)
	player.tick(delta, player_bounds())

	_advance_entities(delta)
	_advance_bubbles(delta)
	_advance_friends(delta)
	_handle_gate()
	_handle_spawning(delta)
	_update_combo(delta)
	_update_rainbow_layer()
	_update_hud()


func _read_input(delta: float) -> void:
	# Keyboard / gamepad steering (desktop and accessibility).
	var axis := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down"))
	if axis != Vector2.ZERO:
		_keyboard_target += axis * 1200.0 * delta
		var b := player_bounds()
		_keyboard_target.x = clampf(_keyboard_target.x, b.position.x, b.position.x + b.size.x)
		_keyboard_target.y = clampf(_keyboard_target.y, b.position.y, b.position.y + b.size.y)
		player.target = _keyboard_target
	elif _steer_touch == -1:
		_keyboard_target = player.position

	# Optional tilt steering, off by default.
	if SaveData.tilt_enabled:
		var tilt := Input.get_accelerometer()
		if tilt != Vector3.ZERO:
			var b := player_bounds()
			var t := player.target
			t.x = clampf(t.x + tilt.x * -900.0 * delta, b.position.x, b.position.x + b.size.x)
			player.target = t

	if _steer_touch != -1:
		_touch_time += delta

	if Input.is_action_just_pressed("ui_accept"):
		player.start_charge()
	if Input.is_action_just_released("ui_accept"):
		player.release_charge()


func _unhandled_input(event: InputEvent) -> void:
	if _paused or _finished:
		return
	var b := player_bounds()

	if event is InputEventScreenTouch:
		if event.pressed and _steer_touch == -1:
			_steer_touch = event.index
			_touch_start = event.position
			_touch_time = 0.0
			# Grab offset keeps Finley from teleporting under the finger.
			_steer_offset = (player.position - event.position).limit_length(260.0)
		elif not event.pressed and event.index == _steer_touch:
			_steer_touch = -1
			# A quick tap anywhere is also a Big Bubble, for players who never
			# find the corner button.
			if _touch_time < 0.22 and event.position.distance_to(_touch_start) < 40.0:
				player.start_charge()
				player.release_charge()
	elif event is InputEventScreenDrag and event.index == _steer_touch:
		var t: Vector2 = event.position + _steer_offset
		player.target = Vector2(
			clampf(t.x, b.position.x, b.position.x + b.size.x),
			clampf(t.y, b.position.y, b.position.y + b.size.y))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_steer_touch = 99
			_touch_start = event.position
			_touch_time = 0.0
			_steer_offset = (player.position - event.position).limit_length(260.0)
		else:
			_steer_touch = -1
			if _touch_time < 0.22 and event.position.distance_to(_touch_start) < 40.0:
				player.start_charge()
				player.release_charge()
	elif event is InputEventMouseMotion and _steer_touch == 99:
		var t: Vector2 = event.position + _steer_offset
		player.target = Vector2(
			clampf(t.x, b.position.x, b.position.x + b.size.x),
			clampf(t.y, b.position.y, b.position.y + b.size.y))


func _advance_entities(delta: float) -> void:
	var survivors: Array[BBEntity] = []
	for e in _entities:
		e.advance(delta, scroll_speed)

		if e is BBAnchor and e.position.y >= floor_y:
			e.floor_y = floor_y
			e.land(self)

		if e is BBPearl:
			var p := e as BBPearl
			if player.current > 0.0 and absf(p.position.x - player.position.x) < 260.0:
				# Speed Current hoovers up the whole lane.
				p.magnet_toward(player.position, delta * 3.0)
			else:
				p.magnet_toward(player.position, delta)

		if e is BBAngler and (e as BBAngler).beam_hits(player.position):
			_touch_entity(e)

		if e.overlaps(player.position, BBPlayer.RADIUS):
			_touch_entity(e)

		if e.alive and e.position.y < despawn_y and absf(e.position.x) < view.x + 600.0:
			survivors.append(e)
		else:
			e.queue_free()
	_entities = survivors


func _touch_entity(e: BBEntity) -> void:
	if not e.alive:
		return
	if e.kind == BBEntity.Kind.OBSTACLE:
		if e.pushed:
			return
		if player.rainbow > 0.0:
			e.on_rainbow(self)
			return
		if player.dizzy > 0.0:
			return   # brief grace period after a bump
	e.on_touch(self, player)


func _advance_bubbles(delta: float) -> void:
	var survivors: Array[BBBubble] = []
	for bubble in _bubbles:
		bubble.tick(delta, scroll_speed)
		for e in _entities:
			if not e.alive or not bubble.alive:
				continue
			if e.kind != BBEntity.Kind.OBSTACLE:
				continue
			if e.position.distance_to(bubble.position) > e.radius + bubble.radius:
				continue
			var consumed := false
			if bubble.big:
				var dir := signf(e.position.x - bubble.position.x)
				if absf(dir) < 0.5:
					# Nudge whichever way there is more room.
					dir = 1.0 if e.position.x < view.x * 0.5 else -1.0
				consumed = e.on_big_bubble(self, dir)
			else:
				consumed = e.on_small_bubble(self)
			if consumed:
				bubble.consume_hit()
		if bubble.alive:
			survivors.append(bubble)
		else:
			if not bubble.big:
				fx.pop_ring(bubble.position, Color(1, 1, 1, 0.5), 40.0)
			bubble.queue_free()
	_bubbles = survivors


func _advance_friends(delta: float) -> void:
	var survivors: Array[BBFriend] = []
	for i in _friends.size():
		var f := _friends[i]
		f.slot = i
		f.tick(delta, player.position)
		if f.alive:
			survivors.append(f)
		else:
			fx.sparkle(f.position, Color(1, 1, 0.85), 8)
			f.queue_free()
	_friends = survivors


func _update_combo(delta: float) -> void:
	if _pearl_combo_t > 0.0:
		_pearl_combo_t -= delta
		if _pearl_combo_t <= 0.0:
			_pearl_combo = 0


func _update_rainbow_layer() -> void:
	var active := player.rainbow > 0.0
	if active != _rainbow_was_active:
		_rainbow_was_active = active
		Sound.set_percussion(active)
		if not active:
			hud.set_power("", 0.0, Color.WHITE)


func _update_hud() -> void:
	hud.set_pearls(pearls_run, float(chest_progress) / float(PEARLS_PER_CHEST))
	hud.set_charge(player.charge if player.charging else 0.0, player.cooldown_ratio())
	hud.set_friends(_friends.size())
	if player.rainbow > 0.0:
		hud.set_power("Rainbow Rush!", player.rainbow / 4.0, BBDraw.rainbow_color(run_time * 0.6))
	elif player.current > 0.0:
		hud.set_power("Speed Current!", player.current / 5.0, Color(0.62, 0.96, 0.85))
	elif player.shield:
		hud.set_power("Bubble Shield ready", 1.0, Color(0.78, 0.94, 1.0))
	else:
		hud.set_power("", 0.0, Color.WHITE)


# ---------------------------------------------------------------------------
# Spawning
# ---------------------------------------------------------------------------

func _handle_spawning(delta: float) -> void:
	var travelled := scroll_speed * delta
	_distance_since_gate += travelled
	# Hold off on new hazards while a Coral Gate is on its way in.
	if _gate != null:
		return
	_spawn_accum += travelled
	if _spawn_accum < SPAWN_INTERVAL:
		return
	_spawn_accum = 0.0
	_spawn_pattern()


func _spawn_pattern() -> void:
	var y := -240.0
	var roll := randf()

	# The daily Golden Friend appears once per run, if still unclaimed today.
	if not _daily_ball_spawned and not SaveData.daily_claimed and run_time > 12.0 and randf() < 0.25:
		_daily_ball_spawned = true
		_spawn_friend_ball(randf_range(240.0, 840.0), y, SaveData.daily_species, true)
		_spawn_pearl_arc(randf_range(300.0, 780.0), y - 260.0, 7)
		return

	if roll < 0.28:
		_spawn_pearl_stream(_lane(), y, randi_range(12, 18))
	elif roll < 0.44:
		_spawn_pearl_arc(_lane(), y, randi_range(7, 10))
		if randf() < 0.4:
			_spawn_obstacle_row(y - 420.0)
	elif roll < 0.66:
		_spawn_obstacle_row(y)
		_spawn_pearl_stream(_lane(), y - 380.0, randi_range(8, 14))
	elif roll < 0.76:
		_spawn_seaweed_gap(y)
	elif roll < 0.85:
		_spawn_friend_ball(randf_range(220.0, 860.0), y, Zones.FRIEND_SPECIES.pick_random(), false)
		_spawn_pearl_arc(_lane(), y - 300.0, 6)
	elif roll < 0.91:
		_spawn_starfish(y)
	elif roll < 0.97:
		_spawn_power_up(y)
	else:
		_spawn_golden_shell(y)


func _lane() -> float:
	return randf_range(180.0, view.x - 180.0)


func _add(e: BBEntity, pos: Vector2) -> BBEntity:
	e.position = pos
	_entity_root.add_child(e)
	_entities.append(e)
	return e


func _spawn_pearl_stream(x: float, y: float, count: int) -> void:
	var drift := randf_range(-1.0, 1.0)
	for i in count:
		var px := x + sin(float(i) * 0.45) * 90.0 * drift
		_add(BBPearl.new(), Vector2(clampf(px, 120.0, view.x - 120.0), y - i * 62.0))


func _spawn_pearl_arc(x: float, y: float, count: int) -> void:
	var width := 340.0
	for i in count:
		var k := float(i) / float(maxi(count - 1, 1))
		var px := x + (k - 0.5) * width
		var py := y - sin(k * PI) * 170.0
		_add(BBPearl.new(), Vector2(clampf(px, 120.0, view.x - 120.0), py))


## Places one or two obstacles from the current zone, always leaving a corridor
## at least 340px wide. A young player can always simply swim around.
func _spawn_obstacle_row(y: float) -> void:
	var zone_obstacles: Array = Zones.get_zone(zone)["obstacles"]
	var gap_center := randf_range(280.0, view.x - 280.0)
	var gap := 340.0
	var slots := []
	if gap_center > 460.0:
		slots.append(randf_range(140.0, gap_center - gap * 0.5 - 60.0))
	if gap_center < view.x - 460.0:
		slots.append(randf_range(gap_center + gap * 0.5 + 60.0, view.x - 140.0))
	if slots.is_empty():
		slots.append(140.0)

	for x in slots:
		if randf() < 0.35 and slots.size() > 1:
			continue
		var pick: int = zone_obstacles.pick_random()
		_spawn_obstacle(pick, Vector2(x, y))
	# A reward for taking the corridor.
	_add(BBPearl.new(), Vector2(gap_center, y - 40.0))
	_add(BBPearl.new(), Vector2(gap_center, y - 110.0))


func _spawn_obstacle(type: int, pos: Vector2) -> void:
	match type:
		Zones.Obstacle.CRAB:
			var crab := BBCrab.new()
			crab.span = randf_range(140.0, 280.0)
			_add(crab, pos)
		Zones.Obstacle.SEAWEED:
			var sw := BBSeaweed.new()
			sw.height = randf_range(260.0, 380.0)
			sw.strands = randi_range(2, 4)
			sw.hidden_reward = "starfish" if randf() < 0.25 else "pearls"
			_add(sw, pos)
		Zones.Obstacle.JELLYFISH:
			var jelly := BBJellyfish.new()
			jelly.amplitude = randf_range(90.0, 180.0)
			jelly.frequency = randf_range(0.35, 0.65)
			_add(jelly, pos)
		Zones.Obstacle.PUFFERFISH:
			_add(BBPufferfish.new(), pos)
		Zones.Obstacle.ANCHOR:
			var anchor := BBAnchor.new()
			anchor.floor_y = floor_y
			_add(anchor, pos)
		Zones.Obstacle.ANGLER:
			_add(BBAngler.new(), pos)
		Zones.Obstacle.SEAGULL:
			var gull := BBSeagull.new()
			_add(gull, Vector2(0.0 if randf() < 0.5 else view.x, maxf(pos.y, -60.0)))
		_:
			_add(BBCrab.new(), pos)


func _spawn_seaweed_gap(y: float) -> void:
	var gap_center := randf_range(320.0, view.x - 320.0)
	for s: float in [-1.0, 1.0]:
		var x := gap_center + s * randf_range(240.0, 330.0)
		if x < 90.0 or x > view.x - 90.0:
			continue
		var sw := BBSeaweed.new()
		sw.height = randf_range(300.0, 420.0)
		sw.strands = 3
		sw.hidden_reward = "starfish" if randf() < 0.3 else "pearls"
		_add(sw, Vector2(x, y))
	_spawn_pearl_stream(gap_center, y - 120.0, 8)


func _spawn_friend_ball(x: float, y: float, species: String, golden: bool) -> void:
	var ball := BBSeaweedBall.new()
	ball.species = species
	ball.golden = golden
	_add(ball, Vector2(x, y))


func _spawn_starfish(y: float) -> void:
	# Tucked into a nook: beside a piece of seaweed, slightly off the main lane.
	var x := randf_range(150.0, view.x - 150.0)
	var sw := BBSeaweed.new()
	sw.height = randf_range(240.0, 320.0)
	sw.strands = 2
	sw.hidden_reward = "pearls"
	_add(sw, Vector2(clampf(x + 190.0 * (1.0 if x < view.x * 0.5 else -1.0), 120.0, view.x - 120.0), y))
	_add(BBStarfish.new(), Vector2(x, y - 60.0))


func _spawn_power_up(y: float) -> void:
	var p := BBPowerUp.new()
	var roll := randf()
	if roll < 0.45:
		p.type = BBPowerUp.Type.SHIELD
	elif roll < 0.8:
		p.type = BBPowerUp.Type.CURRENT
	else:
		p.type = BBPowerUp.Type.RAINBOW
	_add(p, Vector2(_lane(), y))


func _spawn_golden_shell(y: float) -> void:
	_add(BBGoldenShell.new(), Vector2(_lane(), y))


# ---------------------------------------------------------------------------
# Bubbles
# ---------------------------------------------------------------------------

func _on_small_bubble() -> void:
	var b := BBBubble.new()
	b.setup(false)
	b.position = player.position + Vector2(74.0, 12.0)
	add_child(b)
	_bubbles.append(b)
	Sound.play_varied("small_bubble", 0.1, -14.0)


func _on_big_bubble(charge: float) -> void:
	var b := BBBubble.new()
	b.setup(true, charge)
	b.position = player.position + Vector2(96.0, 8.0)
	add_child(b)
	_bubbles.append(b)
	fx.bubbles(b.position, 6)
	Sound.play_varied("big_bubble", 0.08)


# ---------------------------------------------------------------------------
# Interactions called back by entities
# ---------------------------------------------------------------------------

func bump_player(from_pos: Vector2) -> void:
	if player.dizzy > 0.0:
		return
	if player.shield:
		player.shield = false
		fx.pop_ring(player.position, Color(0.8, 0.96, 1.0, 0.9), 170.0)
		fx.bubbles(player.position, 12)
		fx.praise(player.position + Vector2(0, -110), "Phew!", Color(0.85, 0.98, 1.0))
		Sound.play("pop")
		return

	player.hit()
	SaveData.hits_taken += 1
	SaveData.mark_dirty()
	_last_hit_time = run_time
	Sound.play_varied("dizzy", 0.08)
	fx.bubbles(player.position, 10)
	fx.praise(player.position + Vector2(0, -120), "Oops!", Color(1, 0.95, 0.75))

	# Finley shakes a few pearls loose. They hang in the water to be picked up
	# again, so a bump costs a moment of attention rather than progress.
	var drop: int = mini(PEARL_DROP, pearls_run)
	pearls_run -= drop
	for i in drop:
		var p := BBPearl.new()
		p.dropped = true
		p.push_velocity = Vector2(randf_range(-260.0, 260.0), randf_range(-220.0, -60.0))
		_add(p, player.position + Vector2(randf_range(-40.0, 40.0), randf_range(-30.0, 30.0)))
	var away := (player.position - from_pos).normalized()
	player.position += away * 26.0


func zap_player(from_pos: Vector2) -> void:
	if player.dizzy > 0.0:
		return
	if player.shield:
		player.shield = false
		fx.pop_ring(player.position, Color(0.8, 0.96, 1.0, 0.9), 170.0)
		Sound.play("pop")
		return
	player.hit()
	SaveData.hits_taken += 1
	SaveData.mark_dirty()
	_last_hit_time = run_time
	Sound.play_varied("zap", 0.06)
	fx.sparkle(from_pos.lerp(player.position, 0.5), Color(1, 1, 0.7), 12)
	fx.praise(player.position + Vector2(0, -120), "Hee hee!", Color(1, 1, 0.8))


func tangle_player() -> void:
	player.tangle = 0.9
	Sound.play_varied("giggle", 0.1, -4.0)
	fx.bubbles(player.position, 6)
	fx.praise(player.position + Vector2(0, -110), "Tickly!", Color(0.8, 1.0, 0.8))


func pop_seaweed(sw: BBSeaweed) -> void:
	sw.alive = false
	var knot := sw.position + Vector2(0, -sw.height * 0.5)
	fx.bubbles(knot, 14)
	fx.pop_ring(knot, Color(0.75, 1.0, 0.8, 0.8), 150.0)
	Sound.play_varied("pop", 0.1)
	if sw.hidden_reward == "starfish":
		_add(BBStarfish.new(), knot)
	else:
		for i in 5:
			var a := TAU * float(i) / 5.0
			var p := BBPearl.new()
			p.dropped = true
			p.push_velocity = Vector2(cos(a), sin(a)) * 180.0
			_add(p, knot + Vector2(cos(a), sin(a)) * 40.0)


func free_friend(ball: BBSeaweedBall) -> void:
	var f := BBFriend.new()
	f.species = ball.species
	f.golden = ball.golden
	f.position = ball.position
	add_child(f)
	_friends.append(f)
	friends_freed += 1

	SaveData.record_friend(ball.species)
	fx.confetti(ball.position, 20)
	fx.pop_ring(ball.position, Color(1, 1, 0.85, 0.9), 190.0)
	Sound.play("rescue")
	fx.praise(ball.position + Vector2(0, -110), "Thank you!", Color(1, 0.98, 0.8))

	if ball.golden:
		SaveData.daily_claimed = true
		var index := SaveData.grant_zone_sticker(zone)
		SaveData.save_game()
		hud.show_rhyme(Zones.FRIEND_NAMES.get(ball.species, "Friend"),
			Zones.FRIEND_RHYMES.get(ball.species, ""))
		if index >= 0:
			Sound.play("sticker")


func collect_pearl(p: BBPearl) -> void:
	p.alive = false
	pearls_run += p.value
	pearls_collected += p.value
	_pearls_since_gate += p.value
	chest_progress += p.value
	SaveData.add_pearls(p.value)

	_pearl_combo = mini(_pearl_combo + 1, 10)
	_pearl_combo_t = 0.75
	Sound.play("pearl", 1.0 + _pearl_combo * 0.035, -3.0)
	fx.sparkle(p.position, Color(1, 1, 0.9), 5)

	if chest_progress >= PEARLS_PER_CHEST:
		chest_progress -= PEARLS_PER_CHEST
		_chest_filled()


func collect_starfish(s: BBStarfish) -> void:
	s.alive = false
	starfish_found += 1
	var index := SaveData.grant_zone_sticker(zone)
	fx.confetti(s.position, 16)
	fx.pop_ring(s.position, Color(1, 0.9, 0.6, 0.9), 170.0)
	Sound.play("sticker")
	if index >= 0:
		fx.praise(s.position + Vector2(0, -110), "New sticker!", Color(1, 0.95, 0.7))
		hud.banner("Sticker found!", "%s page" % Zones.zone_name(zone), 2.0)
	else:
		fx.praise(s.position + Vector2(0, -110), "Starfish!", Color(1, 0.95, 0.7))


func collect_golden_shell(g: BBGoldenShell) -> void:
	g.alive = false
	SaveData.golden_shells += 1
	SaveData.mark_dirty()
	var needed := PEARLS_PER_CHEST - chest_progress
	pearls_run += needed
	pearls_collected += needed
	_pearls_since_gate += needed
	chest_progress = 0
	SaveData.add_pearls(needed)
	fx.confetti(g.position, 28)
	Sound.play("chest")
	fx.praise(g.position + Vector2(0, -120), "Golden Shell!", Color(1, 0.9, 0.4))
	_chest_filled()


func collect_power_up(p: BBPowerUp) -> void:
	p.alive = false
	match p.type:
		BBPowerUp.Type.SHIELD:
			player.shield = true
			Sound.play("shield")
		BBPowerUp.Type.CURRENT:
			player.current = 5.0
			Sound.play("current")
		BBPowerUp.Type.RAINBOW:
			player.rainbow = 4.0
			Sound.play("rainbow")
	fx.pop_ring(p.position, p.tint(), 180.0)
	fx.sparkle(p.position, p.tint(), 16)
	fx.praise(p.position + Vector2(0, -110), p.label(), p.tint())


func _chest_filled() -> void:
	chests_filled += 1
	fx.confetti(player.position + Vector2(0, -120), 26)
	Sound.play("chest")
	hud.banner("Treasure Chest full!", "%d so far" % chests_filled, 2.2)


# ---------------------------------------------------------------------------
# Coral Gates
# ---------------------------------------------------------------------------

func _handle_gate() -> void:
	if _gate == null:
		if _pearls_since_gate >= GATE_PEARLS or _distance_since_gate >= GATE_DISTANCE:
			_gate = BBCoralGate.new()
			_gate.zone = zone
			_add(_gate, Vector2(view.x * 0.5, -520.0))
		return

	if not _gate.alive:
		_gate = null
		return

	if not _gate.passed and _gate.position.y > player.position.y:
		_gate.passed = true
		_pass_gate()


func _pass_gate() -> void:
	gates_run += 1
	_pearls_since_gate = 0
	_distance_since_gate = 0.0
	zone += 1

	background.set_zone(zone)
	Sound.set_zone_music(zone)
	Sound.play("gate")
	player.celebrate = 1.2
	fx.confetti(player.position + Vector2(0, -60), 34)
	fx.confetti(Vector2(view.x * 0.25, view.y * 0.45), 22)
	fx.confetti(Vector2(view.x * 0.75, view.y * 0.45), 22)

	var sticker := SaveData.grant_zone_sticker(posmod(zone, Zones.count()))
	SaveData.gates_lifetime += 1
	SaveData.save_game()

	var subtitle := "Gate %d - a new sticker!" % gates_run if sticker >= 0 else "Gate %d" % gates_run
	hud.banner("%s ahead!" % Zones.zone_name(zone), subtitle, 3.0)
	fx.praise(player.position + Vector2(0, -150), "Well done!", Color(1, 1, 0.85))


# ---------------------------------------------------------------------------
# Overlays
# ---------------------------------------------------------------------------

func _make_overlay() -> VBoxContainer:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = CanvasLayer.new()
	_overlay.layer = 20
	add_child(_overlay)

	_overlay.add_child(BBUi.veil())

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var panel := BBUi.panel(BBUi.CREAM, 72)
	panel.custom_minimum_size = Vector2(880, 0)
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 28)
	panel.add_child(col)
	return col


func _close_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null


func _show_pause() -> void:
	if _paused or _finished:
		return
	_paused = true
	var col := _make_overlay()
	col.add_child(BBUi.label("Taking a breath", BBUi.FONT_TITLE, BBUi.INK, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(BBUi.label("%d pearls this swim" % pearls_run, BBUi.FONT_BODY, BBUi.TEAL, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(BBUi.spacer(20))

	var resume := BBUi.button("Keep swimming", BBUi.TEAL)
	resume.pressed.connect(func():
		_close_overlay()
		_paused = false)
	col.add_child(resume)

	var quit := BBUi.button("Back to the reef", BBUi.CORAL)
	quit.pressed.connect(_finish_run)
	col.add_child(quit)


## Reached only when a grown-up has set a playtime limit.
func _show_rest() -> void:
	if _finished:
		return
	_paused = true
	var col := _make_overlay()
	col.add_child(BBUi.label("Time to rest", BBUi.FONT_TITLE, BBUi.INK, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(BBUi.label("Finley is sleepy now. You collected %d pearls and freed %d friends. See you next time!"
		% [pearls_run, friends_freed], BBUi.FONT_BODY, BBUi.INK, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(BBUi.spacer(20))
	var done := BBUi.button("Goodnight, Finley", BBUi.TEAL)
	done.pressed.connect(_finish_run)
	col.add_child(done)


func _finish_run() -> void:
	if _finished:
		return
	_finished = true
	_close_overlay()
	Sound.set_percussion(false)
	var summary := {
		"pearls": pearls_run,
		"gates": gates_run,
		"seconds": run_time,
		"friends": friends_freed,
		"starfish": starfish_found,
		"zone": posmod(zone, Zones.count()),
		# Local-only "frustration quit" signal: did the run end right after a bump?
		"quit_after_hit": run_time - _last_hit_time < 3.0,
	}
	exit_requested.emit(summary)


func _notification(what: int) -> void:
	# Tablets get closed abruptly; make sure nothing is lost when that happens.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		SaveData.save_game()
