class_name BBDraw
extends RefCounted
## Shared drawing helpers.
##
## All Bubble Buddy art is drawn procedurally with soft, rounded shapes, which
## keeps the build tiny, scales crisply to any tablet resolution and honours the
## art direction rule of "no sharp edges" by construction.

static var _dot_texture: ImageTexture = null
static var _white_texture: ImageTexture = null

const OUTLINE := Color(0.13, 0.20, 0.27, 0.55)


static func ellipse_points(center: Vector2, rx: float, ry: float, rot := 0.0, segments := 30) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(segments)
	var c := cos(rot)
	var s := sin(rot)
	for i in segments:
		var a := TAU * float(i) / float(segments)
		var x := cos(a) * rx
		var y := sin(a) * ry
		pts[i] = center + Vector2(x * c - y * s, x * s + y * c)
	return pts


static func ellipse(ci: CanvasItem, center: Vector2, rx: float, ry: float, color: Color, rot := 0.0, segments := 30) -> void:
	if rx <= 0.05 or ry <= 0.05:
		return
	ci.draw_colored_polygon(ellipse_points(center, rx, ry, rot, segments), color)


static func ellipse_outline(ci: CanvasItem, center: Vector2, rx: float, ry: float, color: Color, width := 4.0, rot := 0.0, segments := 30) -> void:
	var pts := ellipse_points(center, rx, ry, rot, segments)
	pts.append(pts[0])
	ci.draw_polyline(pts, color, width, true)


## An organic, gently wobbling blob: the workhorse for sea creature bodies.
static func blob(ci: CanvasItem, center: Vector2, radius: float, color: Color, phase := 0.0, lobes := 3, amp := 0.06, segments := 34) -> void:
	if radius <= 0.05:
		return
	var pts := PackedVector2Array()
	pts.resize(segments)
	for i in segments:
		var a := TAU * float(i) / float(segments)
		var r: float = radius * (1.0 + sin(a * lobes + phase) * amp + sin(a * (lobes + 2) - phase * 0.7) * amp * 0.5)
		pts[i] = center + Vector2(cos(a) * r, sin(a) * r)
	ci.draw_colored_polygon(pts, color)


static func rounded_rect(ci: CanvasItem, rect: Rect2, radius: float, color: Color, segments := 6) -> void:
	if rect.size.x <= 0.1 or rect.size.y <= 0.1:
		return
	radius = minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var pts := PackedVector2Array()
	var corners := [
		Vector2(rect.position.x + rect.size.x - radius, rect.position.y + radius),
		Vector2(rect.position.x + rect.size.x - radius, rect.position.y + rect.size.y - radius),
		Vector2(rect.position.x + radius, rect.position.y + rect.size.y - radius),
		Vector2(rect.position.x + radius, rect.position.y + radius),
	]
	var start_angles := [-PI * 0.5, 0.0, PI * 0.5, PI]
	for c in 4:
		for i in range(segments + 1):
			var a: float = start_angles[c] + (PI * 0.5) * float(i) / float(segments)
			pts.append(corners[c] + Vector2(cos(a), sin(a)) * radius)
	ci.draw_colored_polygon(pts, color)


static func star(ci: CanvasItem, center: Vector2, points: int, r_out: float, r_in: float, color: Color, rot := 0.0) -> void:
	if r_out <= 0.05 or points < 3:
		return
	var pts := PackedVector2Array()
	for i in points * 2:
		var a := rot + TAU * float(i) / float(points * 2)
		var r := r_out if i % 2 == 0 else r_in
		pts.append(center + Vector2(cos(a) * r, sin(a) * r))
	ci.draw_colored_polygon(pts, color)


## A four-point sparkle, used as the universal "this is good" cue so the signal
## survives any kind of colour blindness.
static func sparkle(ci: CanvasItem, center: Vector2, size: float, color: Color, rot := 0.0) -> void:
	if size <= 0.05:
		return
	var pts := PackedVector2Array()
	for i in 8:
		var a := rot + TAU * float(i) / 8.0
		var r := size if i % 2 == 0 else size * 0.22
		pts.append(center + Vector2(cos(a) * r, sin(a) * r))
	ci.draw_colored_polygon(pts, color)


static func eye(ci: CanvasItem, pos: Vector2, radius: float, look := Vector2.ZERO, blink := 0.0) -> void:
	if blink > 0.85:
		ci.draw_line(pos + Vector2(-radius, 0), pos + Vector2(radius, 0), Color(0.13, 0.20, 0.27), radius * 0.4, true)
		return
	ellipse(ci, pos, radius, radius * (1.0 - blink * 0.8), Color.WHITE, 0.0, 18)
	var pupil := pos + look * radius * 0.35
	ellipse(ci, pupil, radius * 0.52, radius * 0.52 * (1.0 - blink * 0.8), Color(0.13, 0.20, 0.27), 0.0, 16)
	ellipse(ci, pupil + Vector2(-radius * 0.18, -radius * 0.2), radius * 0.18, radius * 0.18, Color(1, 1, 1, 0.9), 0.0, 12)


## Spiral eyes for Finley's dizzy wobble.
static func spiral_eye(ci: CanvasItem, pos: Vector2, radius: float, phase: float) -> void:
	ellipse(ci, pos, radius, radius, Color.WHITE, 0.0, 18)
	var pts := PackedVector2Array()
	var turns := 2.4
	for i in 26:
		var k := float(i) / 25.0
		var a := phase + k * TAU * turns
		pts.append(pos + Vector2(cos(a), sin(a)) * radius * 0.85 * k)
	ci.draw_polyline(pts, Color(0.13, 0.20, 0.27), radius * 0.22, true)


## A grumpy brow. Every hazard gets one, so hazards read as hazards by shape.
static func brow(ci: CanvasItem, pos: Vector2, length: float, tilt: float, color := OUTLINE) -> void:
	var dir := Vector2(cos(tilt), sin(tilt)) * length * 0.5
	ci.draw_line(pos - dir, pos + dir, color, maxf(3.0, length * 0.22), true)


static func smile(ci: CanvasItem, center: Vector2, radius: float, color: Color, width := 4.0, frown := false) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var a: float = lerpf(0.15 * PI, 0.85 * PI, float(i) / 12.0)
		var p := Vector2(cos(a) * radius, sin(a) * radius * (-1.0 if frown else 1.0))
		pts.append(center + p)
	ci.draw_polyline(pts, color, width, true)


static func rainbow_color(t: float) -> Color:
	return Color.from_hsv(fposmod(t, 1.0), 0.72, 1.0)


## Small radial-gradient dot used as the texture for every particle effect.
static func dot_texture() -> ImageTexture:
	if _dot_texture != null:
		return _dot_texture
	var size := 32
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length() / c
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			a = a * a
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_dot_texture = ImageTexture.create_from_image(img)
	return _dot_texture


## Flat white quad used as the canvas for shader-driven bubbles.
static func white_texture() -> ImageTexture:
	if _white_texture != null:
		return _white_texture
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_white_texture = ImageTexture.create_from_image(img)
	return _white_texture
