extends Node
## Automatischer Test der Touch-Steuerung (Start: -- --game --touch-test).
## Simuliert Finger auf Joystick und Buttons und prüft die Wirkung.

var game
var fails := 0


func _ready() -> void:
	game = get_parent()
	await get_tree().create_timer(0.5).timeout
	var p: Character = game.player
	var hud = game.hud
	var size: Vector2 = get_viewport().get_visible_rect().size

	# 1) Joystick: Finger 0 links unten aufsetzen und nach rechts ziehen
	var start := p.global_position
	_touch(0, Vector2(200, size.y - 200), true)
	_drag(0, Vector2(330, size.y - 200))
	await get_tree().create_timer(0.8).timeout
	var moved: Vector3 = p.global_position - start
	_check("Joystick bewegt Spieler", moved.length() > 0.5)
	_check("Joystick rechts = Bildschirm rechts", moved.normalized().dot(game.cam_right) > 0.7 or moved.length() < 0.5)
	_check("Rennen macht Lärm (motion=1)", p.motion >= 1.0 or not p.moving)

	# 2) gleichzeitig (Multitouch) "Leise" antippen
	var sneak_c: Vector2 = _btn(hud, "sneak")
	_touch(1, sneak_c, true)
	_touch(1, sneak_c, false)
	await get_tree().create_timer(0.3).timeout
	_check("Leise-Button schaltet um", hud.sneak_on and p.sneaking)

	# 3) "Stillstehen" halten
	var fr: Vector2 = _btn(hud, "freeze")
	_touch(1, fr, true)
	await get_tree().create_timer(0.4).timeout
	_check("Stillstehen friert ein (trotz Joystick)", p.frozen and not p.moving)
	var left := p.freeze_left
	_check("Stillstehen-Zeit läuft ab", left < Cfg.FREEZE_MAX)
	_touch(1, fr, false)
	await get_tree().create_timer(0.3).timeout
	_check("Loslassen beendet Stillstehen", not p.frozen)
	_touch(0, Vector2(330, size.y - 200), false)
	await get_tree().create_timer(0.3).timeout
	_check("Joystick loslassen stoppt", not p.moving)

	# 4) Verstecken: neben ein Versteck stellen und Button tippen
	var spot: HidingSpot = game.spots[0]
	p.global_position = spot.access[0]
	await get_tree().create_timer(0.2).timeout
	var hide_c: Vector2 = _btn(hud, "hide")
	_touch(0, hide_c, true)
	_touch(0, hide_c, false)
	await get_tree().create_timer(0.2).timeout
	_check("Verstecken-Button versteckt (%s)" % spot.label(), p.hidden_in == spot)
	_touch(0, hide_c, true)
	_touch(0, hide_c, false)
	await get_tree().create_timer(0.2).timeout
	_check("Raus-Button verlässt Versteck", p.hidden_in == null)

	# 5) Melone: Button halten, Richtung ziehen, loslassen
	p.has_melon = true
	await get_tree().create_timer(0.1).timeout
	var mc: Vector2 = _btn(hud, "melon")
	_touch(0, mc, true)
	_drag(0, mc + Vector2(-70, 0))
	await get_tree().create_timer(0.2).timeout
	_check("Zielpfeil sichtbar", game._aim_arrow.visible)
	_check("Zielrichtung = Bildschirm links", game._aim_dir.dot(-game.cam_right) > 0.9)
	_touch(0, mc + Vector2(-70, 0), false)
	await get_tree().create_timer(0.2).timeout
	_check("Melone geworfen", not p.has_melon)

	# 6) Olivenöl: Button erscheint nur mit Flasche und legt eine Pfütze
	p.has_oil = true
	await get_tree().create_timer(0.1).timeout
	var oc: Vector2 = _btn(hud, "oil")
	_touch(0, oc, true)
	_touch(0, oc, false)
	await get_tree().create_timer(0.2).timeout
	_check("Öl-Button legt eine Pfütze", not p.has_oil and game._puddles.size() == 1)

	print("TOUCHTEST %s (%d Fehler)" % ["OK" if fails == 0 else "FEHLGESCHLAGEN", fails])
	get_tree().quit(0 if fails == 0 else 1)


func _btn(hud, id: String) -> Vector2:
	for b in hud._buttons:
		if b.id == id:
			return hud._btn_center(b)
	return Vector2.ZERO


func _check(what: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		fails += 1


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	Input.parse_input_event(e)


func _drag(index: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	Input.parse_input_event(e)
