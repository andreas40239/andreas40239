class_name StarsView
extends Control
## Zeigt 0-3 Sterne; kann sie nacheinander "aufploppen" lassen.

var stars := 0
var star_size := 90.0
var _shown := 0.0
var _animate := false


static func make(count: int, s: float, animate: bool) -> StarsView:
	var v := StarsView.new()
	v.stars = count
	v.star_size = s
	v._animate = animate
	v._shown = 0.0 if animate else float(count)
	v.custom_minimum_size = Vector2(s * 3.4, s * 1.15)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


func _process(delta: float) -> void:
	if _animate and _shown < stars:
		var before := int(_shown)
		_shown = minf(float(stars), _shown + delta * 1.8)
		if int(_shown) > before or (_shown >= stars and before < stars):
			AudioManager.play(&"star", 0.0)
	queue_redraw()


func _draw() -> void:
	var gap := star_size * 1.1
	var start := size.x * 0.5 - gap
	for i in 3:
		var c: Vector2 = Vector2(start + i * gap, size.y * 0.5 + (0.0 if i == 1 else star_size * 0.12))
		var k := clampf(_shown - i, 0.0, 1.0)
		Icons.star(self, c, star_size, Color(1, 1, 1, 0.5), true)
		if k > 0.0:
			var s := star_size * (1.0 + 0.35 * sin(k * PI))
			Icons.star(self, c, s * k + star_size * (1.0 - k) * 0.0, Color("ffd23f"), false)
