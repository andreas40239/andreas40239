extends Node
## Automatischer Test für Olivenöl, Frappé und das Ausrutschen (Start: -- --items-test).

var game
var fails := 0


func _ready() -> void:
	game = get_parent()
	await get_tree().create_timer(0.3).timeout
	var p: Character = game.player

	# Frappé: füllt Stillstehen auf, leise gehen wird schnell
	p.freeze_left = 2.0
	p.lives = 1
	game._spawn_pickup("frappe", p.global_position)
	await get_tree().create_timer(0.2).timeout
	_check("Frappé eingesammelt (20 s)", p.frappe_t > 19.0)
	_check("Frappé füllt Stillstehen auf", p.freeze_left >= Cfg.FREEZE_MAX - 0.5)
	_check("Upgrade füllt Lebensenergie auf", p.lives == Cfg.MAX_LIVES)
	p.sneaking = true
	_check("Leise gehen ist mit Frappé schneller als ein verfolgender Zombie", p.current_speed() > Cfg.ZOMBIE_CHASE)
	p.sneaking = false

	# Olivenöl: einsammeln, Pfütze legen
	game._spawn_pickup("oil", p.global_position)
	await get_tree().create_timer(0.2).timeout
	_check("Öl eingesammelt", p.has_oil)
	game.player_oil()
	await get_tree().create_timer(0.1).timeout
	_check("Pfütze gelegt, Flasche verbraucht", game._puddles.size() == 1 and not p.has_oil)
	_check("Mensch rutscht nicht aus", p.slip_t <= 0.0)

	# Zombie wartet draußen und wechselt das Fenster
	game.prep_left = 5.0
	await get_tree().create_timer(0.3).timeout
	var waiting: Character = game.zombies()[0]
	var before := waiting.global_position
	var win_before: Dictionary = game._pending[0].win
	game._act_window(waiting)
	await get_tree().create_timer(0.1).timeout
	_check("Wartender Zombie wechselt das Fenster", waiting.global_position.distance_to(before) > 0.5 and game._pending[0].win != win_before)
	_check("... und steht draußen vor dem neuen Fenster", waiting.busy and waiting.global_position.distance_to(game._pending[0].inside) < 1.6)

	# Zombies kommen lassen und einen über eine Pfütze schicken
	game.prep_left = 0.2
	await get_tree().create_timer(2.5).timeout
	var z: Character = game.zombies()[0]
	_check("Zombie ist in der Wohnung", not z.busy)
	game._add_puddle(99, z.global_position)
	var slipped := false
	for i in 80:
		await get_tree().create_timer(0.1).timeout
		if z.slip_t > 0.0:
			slipped = true
			break
		# Pfütze unter den laufenden Zombie schieben
		game._puddles[-1].pos = z.global_position
	_check("Zombie rutscht auf der Pfütze aus", slipped)
	_check("Ausgerutschter Zombie kann nicht handeln", not z.can_act())
	var uses: int = game._puddles[-1].uses
	_check("Pfütze verbraucht sich", uses == Cfg.OIL_USES - 1)
	await get_tree().create_timer(Cfg.SLIP_TIME + 0.3).timeout
	_check("Zombie steht nach %.1f s wieder auf" % Cfg.SLIP_TIME, z.slip_t <= 0.0 and z.can_act())
	_check("... und rutscht nicht sofort wieder aus", z.slip_cd > 0.0)

	print("ITEMSTEST %s (%d Fehler)" % ["OK" if fails == 0 else "FEHLGESCHLAGEN", fails])
	get_tree().quit(0 if fails == 0 else 1)


func _check(what: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		fails += 1
