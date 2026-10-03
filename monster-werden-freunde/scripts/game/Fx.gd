class_name Fx
extends Node2D
## Kurzlebige, gewaltfreie Effekte: Herzen, Glitzer, Noten, Zzz, Wölkchen, Text, Konfetti.

enum Kind { TEXT, HEARTS, SPARKLE, NOTES, ZZZ, POOF, BUBBLES, CONFETTI, CRUMBS }

var kind: Kind = Kind.SPARKLE
var life := 1.0
var age := 0.0
var text := ""
var color := Color.WHITE
var font_size := 34
var icon: StringName = &""
var _parts: Array[Dictionary] = []


## Erzeugt einen Effekt unter 'parent' an Position 'pos' (lokale Koordinaten von parent).
static func spawn(parent: Node, fx_kind: Kind, pos: Vector2, opts: Dictionary = {}) -> Fx:
	var fx := Fx.new()
	fx.kind = fx_kind
	fx.position = pos
	fx.text = opts.get("text", "")
	fx.color = opts.get("color", Color.WHITE)
	fx.font_size = opts.get("size", 34)
	fx.icon = opts.get("icon", &"")
	fx.life = opts.get("life", _default_life(fx_kind))
	fx.z_index = 30
	fx._init_parts()
	parent.add_child(fx)
	return fx


static func _default_life(k: Kind) -> float:
	match k:
		Kind.TEXT: return 1.4
		Kind.HEARTS: return 1.2
		Kind.CONFETTI: return 2.2
		Kind.NOTES, Kind.ZZZ: return 1.4
		Kind.POOF: return 0.8
	return 0.7


func _init_parts() -> void:
	var n := 0
	match kind:
		Kind.HEARTS: n = 7
		Kind.SPARKLE: n = 8
		Kind.NOTES, Kind.ZZZ: n = 2
		Kind.POOF: n = 9
		Kind.BUBBLES: n = 6
		Kind.CONFETTI: n = 46
		Kind.CRUMBS: n = 7
	for i in n:
		var a := randf() * TAU
		var spd := randf_range(60.0, 180.0)
		var p := {"p": Vector2.ZERO, "v": Vector2(cos(a), sin(a)) * spd, "s": randf_range(0.7, 1.2),
			"r": randf() * TAU, "w": randf_range(-4.0, 4.0), "c": Color.from_hsv(randf(), 0.6, 1.0)}
		match kind:
			Kind.HEARTS:
				p.v = Vector2(randf_range(-90, 90), randf_range(-220, -120))
			Kind.NOTES, Kind.ZZZ:
				p.p = Vector2(randf_range(-20, 20), 0)
				p.v = Vector2(randf_range(-30, 30), randf_range(-80, -60))
			Kind.CONFETTI:
				p.p = Vector2(randf_range(-900, 900), randf_range(-80, 0))
				p.v = Vector2(randf_range(-60, 60), randf_range(120, 320))
			Kind.POOF:
				p.v *= 0.6
			Kind.CRUMBS:
				p.v = Vector2(randf_range(-120, 120), randf_range(-160, -40))
		_parts.append(p)


func _process(delta: float) -> void:
	age += delta
	if age >= life:
		queue_free()
		return
	var g := 0.0
	match kind:
		Kind.HEARTS: g = 120.0
		Kind.CONFETTI: g = 60.0
		Kind.CRUMBS: g = 500.0
	for p in _parts:
		p.v += Vector2(0, g) * delta
		if kind == Kind.POOF or kind == Kind.SPARKLE:
			p.v *= 1.0 - minf(1.0, delta * 3.0)
		p.p += p.v * delta
		p.r += p.w * delta
	var k := age / life
	modulate.a = 1.0 - k * k
	queue_redraw()


func _draw() -> void:
	var k := age / life
	match kind:
		Kind.TEXT:
			var f := UiTheme.get_bold()
			var pos := Vector2(-400, -k * 70.0)
			if icon != &"":
				var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
				Icons.draw(self, icon, Vector2(-w * 0.5 - font_size * 0.5, pos.y - font_size * 0.33), font_size * 1.1)
				pos.x += font_size * 0.4
			draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 800, font_size, 10, Color(0.15, 0.17, 0.3, 0.9))
			draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 800, font_size, color)
		Kind.HEARTS:
			for p in _parts:
				Icons.heart(self, p.p, 26.0 * p.s, Color("ff5a87"))
		Kind.SPARKLE:
			for p in _parts:
				Icons.sparkle(self, p.p, 22.0 * p.s * (1.0 - k * 0.5), Color(1.0, 0.95, 0.55))
		Kind.NOTES:
			for p in _parts:
				Icons.note(self, p.p, 28.0 * p.s, Color("e85aa8"))
		Kind.ZZZ:
			for p in _parts:
				Icons.zzz(self, p.p, 22.0 * p.s, Color("7d62c4"))
		Kind.POOF:
			for p in _parts:
				draw_circle(p.p, 22.0 * p.s * (0.6 + k), Color(0.92, 0.88, 1.0, 0.8))
			Icons.swirl(self, Vector2(0, -10 - k * 30), 40, Color("9b59d0"))
		Kind.BUBBLES:
			for p in _parts:
				var r: float = 8.0 * p.s * (1.0 + k)
				draw_arc(p.p, r, 0, TAU, 14, Color(0.4, 0.75, 1.0), 2.5, true)
		Kind.CONFETTI:
			for p in _parts:
				var xf := Transform2D(p.r, p.p)
				draw_set_transform_matrix(xf)
				draw_rect(Rect2(-7, -4, 14, 8), p.c)
			draw_set_transform_matrix(Transform2D.IDENTITY)
		Kind.CRUMBS:
			for p in _parts:
				draw_circle(p.p, 4.0 * p.s, Color("c98b4f"))
