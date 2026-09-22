extends RefCounted
class_name BackgroundKit
## Erzeugt die Staffeln des Parallax-Hintergrunds (GDD Abschnitt 8):
## Bergsilhouette, ferne Stadt mit Kirchturm, naehere Wohnbloecke.
##
## Alles prozedural und mit festem Zufallsstartwert, damit jeder Durchlauf
## dieselbe Skyline ergibt. Die Staffeln sind so gebaut, dass linker und
## rechter Rand zusammenpassen und sich endlos aneinanderreihen lassen.

## Flache Bergsilhouette - aus der Entfernung reicht ein Umriss.
static func mountains(width: float, height: float, seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var steps := 24
	var surface := MeshBuilder.create()
	var heights: Array[float] = []
	for i in steps + 1:
		heights.append(rng.randf_range(height * 0.45, height))
	heights[steps] = heights[0]   # nahtloser Anschluss
	var color := Color(0.60, 0.67, 0.82, 0.0)
	for i in steps:
		var x0 := width * float(i) / float(steps) - width * 0.5
		var x1 := width * float(i + 1) / float(steps) - width * 0.5
		MeshBuilder.add_quad(surface,
			Vector3(x0, 0, 0), Vector3(x1, 0, 0),
			Vector3(x1, heights[i + 1], 0), Vector3(x0, heights[i], 0), color)
	return MeshBuilder.finish(surface)

## Haeuserzeile mit beleuchteten Fenstern.
static func city_blocks(width: float, min_height: float, max_height: float,
		depth: float, color: Color, seed_value: int, with_tower: bool) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var surface := MeshBuilder.create()
	var x := -width * 0.5
	while x < width * 0.5 - 1.0:
		var block_width := rng.randf_range(width * 0.05, width * 0.12)
		block_width = minf(block_width, width * 0.5 - x)
		var block_height := rng.randf_range(min_height, max_height)
		var shade := color.lerp(Color(0.46, 0.52, 0.66, 0.0), rng.randf() * 0.35)
		MeshBuilder.add_box(surface,
			Vector3(x + block_width * 0.5, block_height * 0.5, 0),
			Vector3(block_width, block_height, depth), shade)
		_add_windows(surface, rng, x, block_width, block_height, depth)
		x += block_width + rng.randf_range(0.4, 1.6)
	if with_tower:
		_add_tower(surface, max_height * 1.35, depth)
	return MeshBuilder.finish(surface)

static func _add_windows(surface: SurfaceTool, rng: RandomNumberGenerator,
		x: float, block_width: float, block_height: float, depth: float) -> void:
	var window_size := maxf(block_width * 0.12, 0.5)
	var rows := int(block_height / (window_size * 3.0))
	var columns := int(block_width / (window_size * 2.6))
	for row in rows:
		for column in columns:
			if rng.randf() > 0.45:
				continue
			var wx := x + window_size * 1.3 + float(column) * window_size * 2.6
			var wy := window_size * 2.0 + float(row) * window_size * 3.0
			if wy > block_height - window_size:
				continue
			MeshBuilder.add_box(surface, Vector3(wx, wy, depth * 0.5 + 0.05),
				Vector3(window_size, window_size * 1.4, 0.1),
				Palette.glow(Palette.FENSTER_LICHT, 0.8))

## Kirchturm als Landmarke in der Stadtstaffel (GDD Abschnitt 8).
static func _add_tower(surface: SurfaceTool, height: float, depth: float) -> void:
	var tower_width := maxf(height * 0.13, 2.0)
	MeshBuilder.add_box(surface, Vector3(0, height * 0.5, 0),
		Vector3(tower_width, height, depth), Palette.PUTZ_SCHATTEN)
	MeshBuilder.add_box(surface, Vector3(0, height + 0.2, 0),
		Vector3(tower_width * 1.2, 0.4, depth * 1.2), Palette.PUTZ_HELL)
	MeshBuilder.add_dome(surface, Vector3(0, height + 0.4, 0), tower_width * 0.62,
		12, 5, Palette.KUPPEL)
	MeshBuilder.add_box(surface, Vector3(0, height + tower_width * 0.62 + 0.9, 0),
		Vector3(0.18, 1.4, 0.18), Palette.METALL)
	MeshBuilder.add_box(surface, Vector3(0, height + tower_width * 0.62 + 1.2, 0),
		Vector3(0.8, 0.18, 0.18), Palette.METALL)
	MeshBuilder.add_box(surface, Vector3(0, height * 0.78, depth * 0.5 + 0.05),
		Vector3(tower_width * 0.3, tower_width * 0.5, 0.1),
		Palette.glow(Palette.FENSTER_LICHT, 1.0))
