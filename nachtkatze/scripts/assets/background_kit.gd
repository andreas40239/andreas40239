extends RefCounted
class_name BackgroundKit
## Erzeugt die Staffeln des Parallax-Hintergrunds (GDD Abschnitt 8):
## Bergsilhouette, ferne Stadt mit Kirchturm, naehere Wohnbloecke - dazu die
## Athener Landmarken Akropolis und Lykabettus (nach Referenzfotos).
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
		# Athens Haeusermeer: helle Kisten in Weiss-, Creme- und Grautoenen.
		var shade := color.lerp(Color(0.62, 0.66, 0.76, 0.0), rng.randf() * 0.45)
		MeshBuilder.add_box(surface,
			Vector3(x + block_width * 0.5, block_height * 0.5, 0),
			Vector3(block_width, block_height, depth), shade)
		_add_windows(surface, rng, x, block_width, block_height, depth)
		# Flachdach mit Aufbau: Treppenhaus oder Wassertank
		if rng.randf() < 0.7:
			var hut_width := block_width * rng.randf_range(0.2, 0.4)
			MeshBuilder.add_box(surface,
				Vector3(x + block_width * rng.randf_range(0.3, 0.7), block_height + 0.7, 0),
				Vector3(hut_width, 1.4, depth * 0.6), shade.darkened(0.08))
		x += block_width + rng.randf_range(0.4, 1.6)
	if with_tower:
		_add_tower(surface, max_height * 1.35, depth)
		add_acropolis(surface, -width * 0.27, depth)
		_add_lycabettus(surface, width * 0.30, depth)
	return MeshBuilder.finish(surface)

## Akropolis: Felsplateau mit Mauer, obenauf der angestrahlte Parthenon.
static func add_acropolis(surface: SurfaceTool, x: float, depth: float) -> void:
	var z := depth * 0.5 + 3.0
	var rock_height := 15.0
	# Felssockel in zwei Stufen, unten breiter
	MeshBuilder.add_cylinder(surface, Vector3(x, rock_height * 0.3, z), 21.0, 16.0,
		rock_height * 0.6, 9, Palette.FELS.darkened(0.12), Basis.from_scale(Vector3(1.0, 1.0, 0.25)))
	MeshBuilder.add_cylinder(surface, Vector3(x, rock_height * 0.8, z), 15.5, 13.5,
		rock_height * 0.4, 9, Palette.FELS, Basis.from_scale(Vector3(1.0, 1.0, 0.25)))
	# Zypressen und Kiefern am Hang
	for offset in [-17.0, -13.5, -9.0, 8.0, 12.5, 16.0, 19.0]:
		MeshBuilder.add_cylinder(surface, Vector3(x + offset, 4.2, z + 4.2), 1.3, 0.2, 5.5, 6,
			Color(0.24, 0.38, 0.33, 0.0))
	# Befestigungsmauer an der Kante
	MeshBuilder.add_box(surface, Vector3(x, rock_height + 0.5, z + 3.0), Vector3(25.0, 1.4, 0.6),
		Palette.PUTZ_HELL)
	# Parthenon: Stufenbau, Saeulen, Gebaelk, Giebel
	var base_y := rock_height + 1.0
	var temple_x := x - 2.0
	MeshBuilder.add_box(surface, Vector3(temple_x, base_y + 0.3, z), Vector3(13.0, 0.6, 5.0),
		Palette.MARMOR)
	for i in 8:
		MeshBuilder.add_cylinder(surface,
			Vector3(temple_x - 5.6 + float(i) * 1.6, base_y + 2.5, z + 2.0), 0.36, 0.3, 3.8, 6,
			Palette.MARMOR)
	MeshBuilder.add_box(surface, Vector3(temple_x, base_y + 2.4, z - 0.3), Vector3(11.0, 3.6, 3.0),
		Palette.MARMOR.darkened(0.2))
	MeshBuilder.add_box(surface, Vector3(temple_x, base_y + 4.75, z), Vector3(13.0, 0.7, 5.0),
		Palette.MARMOR)
	MeshBuilder.add_prism(surface, Vector3(temple_x, base_y + 5.7, z + 2.1), Vector3(13.0, 1.2, 0.5),
		Palette.MARMOR)
	# Erechtheion als kleiner Nachbar
	MeshBuilder.add_box(surface, Vector3(x + 8.5, base_y + 1.3, z), Vector3(3.6, 2.6, 3.0),
		Palette.MARMOR)

## Lykabettus: bewaldeter Kegel mit felsiger Spitze und weisser Kapelle.
static func _add_lycabettus(surface: SurfaceTool, x: float, depth: float) -> void:
	var z := -depth * 0.5 - 6.0
	var squash := Basis.from_scale(Vector3(1.0, 1.0, 0.2))
	MeshBuilder.add_cylinder(surface, Vector3(x, 12.0, z), 30.0, 9.0, 24.0, 10,
		Color(0.30, 0.44, 0.36, 0.0), squash)
	MeshBuilder.add_cylinder(surface, Vector3(x, 28.0, z), 9.0, 3.0, 8.0, 8, Palette.FELS, squash)
	MeshBuilder.add_box(surface, Vector3(x, 33.0, z), Vector3(3.4, 2.2, 1.0),
		Palette.glow(Palette.GELAENDER_WEISS, 0.5))
	MeshBuilder.add_dome(surface, Vector3(x, 34.1, z), 1.0, 8, 4, Palette.KUPPEL)

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
