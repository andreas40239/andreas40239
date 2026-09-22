extends RefCounted
class_name MeshBuilder
## Kleiner Baukasten fuer die prozeduralen Low-Poly-Meshes (GDD Abschnitt 15:
## "Herkunft der 3D-Modelle: Prozedural erzeugt").
##
## Jede Flaeche bekommt ihre eigene Normale - dadurch bleiben die Kanten hart,
## wie es der Flat-/Toon-Stil verlangt. Farben liegen auf den Eckpunkten.

## Godot zeichnet Vorderseiten im Uhrzeigersinn; die Reihenfolge hier ist
## bewusst gegen den Uhrzeigersinn "von aussen gesehen" und wird beim Anlegen
## der Dreiecke gedreht.
static func create() -> SurfaceTool:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	return surface

static func finish(surface: SurfaceTool) -> ArrayMesh:
	return surface.commit()

## Viereck aus vier Punkten, gegen den Uhrzeigersinn von aussen gesehen.
static func add_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		d: Vector3, color: Color) -> void:
	var normal := (b - a).cross(d - a).normalized()
	_add_triangle(surface, a, d, c, normal, color)
	_add_triangle(surface, a, c, b, normal, color)

static func add_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		color: Color) -> void:
	var normal := (b - a).cross(c - a).normalized()
	_add_triangle(surface, a, c, b, normal, color)

static func add_box(surface: SurfaceTool, center: Vector3, size: Vector3,
		color: Color, basis: Basis = Basis.IDENTITY) -> void:
	var half := size * 0.5
	var corners: Array[Vector3] = []
	for signs in [Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(-1, 1, 1),
			Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(-1, 1, -1)]:
		corners.append(center + basis * (signs * half))
	# vorne, hinten, rechts, links, oben, unten
	add_quad(surface, corners[0], corners[1], corners[2], corners[3], color)
	add_quad(surface, corners[5], corners[4], corners[7], corners[6], color)
	add_quad(surface, corners[1], corners[5], corners[6], corners[2], color)
	add_quad(surface, corners[4], corners[0], corners[3], corners[7], color)
	add_quad(surface, corners[3], corners[2], corners[6], corners[7], color)
	add_quad(surface, corners[4], corners[5], corners[1], corners[0], color)

## Zylinder oder Kegelstumpf entlang der Y-Achse (radius_top = 0 ergibt einen Kegel).
static func add_cylinder(surface: SurfaceTool, center: Vector3, radius_bottom: float,
		radius_top: float, height: float, sides: int, color: Color,
		basis: Basis = Basis.IDENTITY) -> void:
	var half := height * 0.5
	var top_center := center + basis * Vector3(0, half, 0)
	var bottom_center := center + basis * Vector3(0, -half, 0)
	for i in sides:
		var a0 := TAU * float(i) / float(sides)
		var a1 := TAU * float(i + 1) / float(sides)
		var b0 := center + basis * Vector3(cos(a0) * radius_bottom, -half, sin(a0) * radius_bottom)
		var b1 := center + basis * Vector3(cos(a1) * radius_bottom, -half, sin(a1) * radius_bottom)
		var t0 := center + basis * Vector3(cos(a0) * radius_top, half, sin(a0) * radius_top)
		var t1 := center + basis * Vector3(cos(a1) * radius_top, half, sin(a1) * radius_top)
		# Reihenfolge gegen den Uhrzeigersinn von aussen gesehen, sonst zeigen
		# Normalen und Vorderseiten nach innen.
		if radius_top <= 0.0:
			add_triangle(surface, b1, b0, top_center, color)
		else:
			add_quad(surface, b1, b0, t0, t1, color)
			add_triangle(surface, t1, t0, top_center, color)
		if radius_bottom > 0.0:
			add_triangle(surface, b0, b1, bottom_center, color)

## Halbkugel, zum Beispiel fuer die Kuppel des Kirchturms.
static func add_dome(surface: SurfaceTool, center: Vector3, radius: float,
		sides: int, rings: int, color: Color) -> void:
	for ring in rings:
		var phi0 := PI * 0.5 * float(ring) / float(rings)
		var phi1 := PI * 0.5 * float(ring + 1) / float(rings)
		for i in sides:
			var a0 := TAU * float(i) / float(sides)
			var a1 := TAU * float(i + 1) / float(sides)
			var p00 := center + _sphere_point(radius, a0, phi0)
			var p10 := center + _sphere_point(radius, a1, phi0)
			var p01 := center + _sphere_point(radius, a0, phi1)
			var p11 := center + _sphere_point(radius, a1, phi1)
			if ring == rings - 1:
				add_triangle(surface, p10, p00, center + Vector3(0, radius, 0), color)
			else:
				add_quad(surface, p00, p01, p11, p10, color)

## Dreieckiges Prisma mit First entlang der X-Achse - klassische Dachform.
static func add_prism(surface: SurfaceTool, center: Vector3, size: Vector3,
		color: Color) -> void:
	var half := size * 0.5
	var fl := center + Vector3(-half.x, -half.y, half.z)
	var fr := center + Vector3(half.x, -half.y, half.z)
	var bl := center + Vector3(-half.x, -half.y, -half.z)
	var br := center + Vector3(half.x, -half.y, -half.z)
	var rl := center + Vector3(-half.x, half.y, 0.0)
	var rr := center + Vector3(half.x, half.y, 0.0)
	add_quad(surface, fl, fr, rr, rl, color)      # vordere Dachflaeche
	add_quad(surface, br, bl, rl, rr, color)      # hintere Dachflaeche
	add_triangle(surface, fr, br, rr, color)      # Giebel rechts
	add_triangle(surface, bl, fl, rl, color)      # Giebel links
	add_quad(surface, bl, br, fr, fl, color)      # Unterseite

static func _sphere_point(radius: float, theta: float, phi: float) -> Vector3:
	return Vector3(cos(theta) * cos(phi) * radius, sin(phi) * radius,
		sin(theta) * cos(phi) * radius)

static func _add_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		normal: Vector3, color: Color) -> void:
	surface.set_color(color)
	surface.set_normal(normal)
	surface.add_vertex(a)
	surface.set_color(color)
	surface.set_normal(normal)
	surface.add_vertex(b)
	surface.set_color(color)
	surface.set_normal(normal)
	surface.add_vertex(c)
