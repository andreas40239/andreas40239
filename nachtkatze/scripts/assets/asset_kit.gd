extends RefCounted
class_name AssetKit
## Modulares Low-Poly-Asset-Kit (GDD Abschnitt 8), prozedural erzeugt
## (GDD Abschnitt 15). Jedes Teil ist ein ArrayMesh mit Vertex-Farben; alle
## teilen sich das eine Toon-Material.
##
## Massstab wie im ganzen Projekt: 1 Einheit = 1 m, Geschosshoehe 3 m.
## Der Ursprung jedes Teils liegt dort, wo man es im Level absetzt - meist
## mittig auf der Standflaeche.

enum Kind {
	# Wohnblock
	GESCHOSS_SEGMENT,
	BALKONBAND,
	MARKISE_OFFEN,
	MARKISE_GESCHLOSSEN,
	DACHABSCHLUSS,
	# Einfamilienhaus
	EINFAMILIENHAUS,
	# Dach-Props
	SOLARKOLLEKTOR,
	SATELLITENSCHUESSEL,
	ANTENNE,
	KLIMAGERAET,
	# Strasse
	LATERNE,
	STROMMAST,
	STROMLEITUNG,
	GEPARKTES_AUTO,
	FAHRENDES_AUTO,
	ZAUN,
	ZAUN_MIT_LUECKE,
	GARTENTOR,
	# Vegetation
	KIEFER,
	ZYPRESSE,
	OLIVENBAUM,
	OLEANDERBUSCH,
	# Landmarken
	KIRCHTURM,
	TANKSTELLE,
	# Interaktiv
	FISCHGRAETE,
	GANZER_FISCH,
	FUTTERNAPF,
	# Untergrund
	STRASSEN_SEGMENT,
	MAUERSTUECK,
	# Kletterbares
	REGENRINNE,
	# Athen: Fassadenvarianten und Erdgeschoss
	GESCHOSS_BALKONTUER,
	GESCHOSS_FENSTER,
	LADENZEILE,
	HAUSEINGANG,
	# Athen: Balkon und Dach
	MARKISE_OFFEN_GRUEN,
	BALKONPFLANZEN,
	WAESCHELEINE,
	BLUMENTOPF,
	PERGOLA,
	# Athen: Strasse
	ORANGENBAUM,
	PERIPTERO,
	MUELLCONTAINER,
	MUELLCONTAINER_BLAU,
	MOPED,
	GEPARKTES_AUTO_SILBER,
	# Athen: Landmarke
	AKROPOLIS,
}

## Farbtoene fuer ganze Haeuser: Athener Wohnblocks sind selten einfarbig.
## Der Ton wird auf das Bauteil multipliziert (AssetPiece.farbton).
const FARBTOENE := [
	Color(1.0, 1.0, 1.0),      # Putz wie in der Palette
	Color(1.0, 0.84, 0.62),    # warmes Ocker
	Color(1.0, 0.78, 0.74),    # Rosé
	Color(0.78, 0.90, 1.04),   # kuehles Weissblau
	Color(0.80, 0.97, 0.78),   # blasses Gruen
	Color(1.12, 1.12, 1.10),   # fast weiss
]

const MATERIAL_PATH := "res://assets/materials/toon_material.tres"
## Lichte Hoehe der Zaunluecke: die Katze (0,55 m) passt hindurch, kein Hund.
const ZAUN_LUECKE := 0.62
## Oberkanten der neuen Stufen: Muellcontainer und Kiosk (Periptero).
const CONTAINER_HOEHE := 1.15
const KIOSK_HOEHE := 2.6

## Breite der kachelbaren Bauteile - damit lassen sich Fassaden, Balkone,
## Daecher und Strassen aus Modulen zusammensetzen (GDD Abschnitt 8).
const MODULE_WIDTH := {
	Kind.GESCHOSS_SEGMENT: 4.0,
	Kind.BALKONBAND: 2.0,
	Kind.DACHABSCHLUSS: 2.0,
	Kind.ZAUN: 2.0,
	Kind.ZAUN_MIT_LUECKE: 2.0,
	Kind.STRASSEN_SEGMENT: 4.0,
	Kind.MAUERSTUECK: 2.0,
	Kind.REGENRINNE: 3.0,
	Kind.GESCHOSS_BALKONTUER: 4.0,
	Kind.GESCHOSS_FENSTER: 4.0,
	Kind.LADENZEILE: 4.0,
	Kind.HAUSEINGANG: 4.0,
	Kind.BALKONPFLANZEN: 2.0,
	Kind.WAESCHELEINE: 2.0,
}

## Bauteile, die nach oben statt zur Seite gekachelt werden.
const VERTICAL_MODULES := [Kind.REGENRINNE]

static var _mesh_cache := {}
static var _material: ShaderMaterial = null
static var _background_material: ShaderMaterial = null
static var _character_material: ShaderMaterial = null
static var _tinted_materials := {}

## Gemeinsames Toon-Material. Auf Renderern ohne light()-Unterstuetzung
## (Compatibility) wird der Ersatzpfad im Shader eingeschaltet.
static func get_material() -> ShaderMaterial:
	if _material == null:
		_material = load(MATERIAL_PATH)
		configure_material()
	return _material

## Material fuer die Parallax-Staffeln: derselbe Shader, aber entsaettigt und
## blaustichig, damit der Hintergrund zuruecktritt (GDD Abschnitt 9).
static func get_background_material() -> ShaderMaterial:
	if _background_material == null:
		_background_material = get_material().duplicate() as ShaderMaterial
		_background_material.set_shader_parameter("tint", Color(0.86, 0.90, 1.0))
		_background_material.set_shader_parameter("shadow_level", 0.72)
	return _background_material

## Material fuer Katze, Hunde und Futter: derselbe Shader, aber mit helleren
## Schatten und gleichbleibendem Eigenleuchten - Figuren sollen sich zu jeder
## Tageszeit von der Kulisse abheben (GDD Abschnitt 9).
static func get_character_material() -> ShaderMaterial:
	if _character_material == null:
		_character_material = get_material().duplicate() as ShaderMaterial
		_character_material.set_shader_parameter("shadow_level", 0.5)
		_character_material.set_shader_parameter("emission_strength", 1.0)
	return _character_material

## Material mit einem der FARBTOENE; Ton 0 ist das gemeinsame Material.
static func get_tinted_material(tone: int) -> ShaderMaterial:
	tone = clampi(tone, 0, FARBTOENE.size() - 1)
	if tone == 0:
		return get_material()
	if not _tinted_materials.has(tone):
		var material := get_material().duplicate() as ShaderMaterial
		material.set_shader_parameter("tint", FARBTOENE[tone])
		_tinted_materials[tone] = material
	return _tinted_materials[tone]

static func _world_materials() -> Array:
	var materials: Array = [get_material()]
	materials.append_array(_tinted_materials.values())
	return materials

static func configure_material() -> void:
	if _material == null:
		_material = load(MATERIAL_PATH)
	var needs_fallback := RenderingServer.get_rendering_device() == null
	_material.set_shader_parameter("fallback_sun", needs_fallback)
	var extras: Array = [_background_material, _character_material]
	extras.append_array(_tinted_materials.values())
	for extra in extras:
		if extra != null:
			extra.set_shader_parameter("fallback_sun", needs_fallback)

## Leuchtkraft von Fenstern, Laternen und Leuchtband je Tageszeit.
static func set_emission(strength: float) -> void:
	for material in _world_materials():
		material.set_shader_parameter("emission_strength", strength)
	# Die Stadt im Hintergrund leuchtet tagsueber kaum, nachts deutlich.
	get_background_material().set_shader_parameter("emission_strength",
		clampf(strength - 0.75, 0.2, 2.0))

## Sonnenrichtung und -farbe fuer den Ersatzpfad nachfuehren (Tageszeiten).
static func set_sun(direction: Vector3, color: Color, energy: float = 0.85) -> void:
	var materials := _world_materials()
	materials.append(get_background_material())
	materials.append(get_character_material())
	for material in materials:
		material.set_shader_parameter("fallback_sun_direction", direction.normalized())
		material.set_shader_parameter("fallback_sun_color", color)
		material.set_shader_parameter("fallback_sun_energy", energy)

## Mesh eines Bauteils, wahlweise mehrfach aneinandergereiht.
## Ergebnisse werden zwischengespeichert, gleiche Teile teilen sich ihr Mesh.
static func get_mesh(kind: Kind, tiles: int = 1) -> ArrayMesh:
	tiles = maxi(tiles, 1)
	var key := "%d_%d" % [kind, tiles]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var mesh: ArrayMesh
	if tiles == 1:
		var surface := MeshBuilder.create()
		_build(kind, surface)
		mesh = MeshBuilder.finish(surface)
	else:
		var base := get_mesh(kind, 1)
		var width := module_width(kind)
		var surface := MeshBuilder.create()
		var vertical := VERTICAL_MODULES.has(kind)
		for i in tiles:
			var step := float(i) * width if vertical \
				else (float(i) - float(tiles - 1) * 0.5) * width
			var offset := Vector3(0, step, 0) if vertical else Vector3(step, 0, 0)
			surface.append_from(base, 0, Transform3D(Basis(), offset))
		mesh = surface.commit()
	_mesh_cache[key] = mesh
	return mesh

## Breite eines Moduls; 0 bedeutet "nicht kachelbar".
static func module_width(kind: Kind) -> float:
	return MODULE_WIDTH.get(kind, 0.0)

## Kollisionskoerper eines Bauteils in lokalen Koordinaten. Leer bedeutet:
## reine Zier, die Katze laeuft hindurch.
static func get_collision_boxes(kind: Kind, tiles: int = 1) -> Array[AABB]:
	var boxes := _base_collision_boxes(kind)
	var width := module_width(kind)
	if tiles <= 1 or width <= 0.0:
		return boxes
	# Gekachelte Bauteile bekommen einen entsprechend breiteren Koerper.
	var total := width * float(tiles)
	var stretched: Array[AABB] = []
	for box in boxes:
		stretched.append(AABB(Vector3(-total * 0.5, box.position.y, box.position.z),
			Vector3(total, box.size.y, box.size.z)))
	return stretched

static func _base_collision_boxes(kind: Kind) -> Array[AABB]:
	match kind:
		Kind.GESCHOSS_SEGMENT, Kind.GESCHOSS_BALKONTUER, Kind.GESCHOSS_FENSTER, \
		Kind.LADENZEILE, Kind.HAUSEINGANG:
			return [AABB(Vector3(-2, 0, -2), Vector3(4, 3, 2))]
		Kind.BALKONBAND:
			return [AABB(Vector3(-1, -0.24, -1.2), Vector3(2, 0.24, 2.4))]
		Kind.MARKISE_OFFEN, Kind.MARKISE_OFFEN_GRUEN:
			return [AABB(Vector3(-1.1, 0.18, -0.05), Vector3(2.2, 0.14, 1.1))]
		Kind.DACHABSCHLUSS:
			return [AABB(Vector3(-1, -0.3, -1.2), Vector3(2, 0.3, 2.4))]
		Kind.EINFAMILIENHAUS:
			return [AABB(Vector3(-2.5, 0, -2), Vector3(5, 3, 4))]
		Kind.GEPARKTES_AUTO, Kind.GEPARKTES_AUTO_SILBER:
			return [AABB(Vector3(-1.8, 0, -0.85), Vector3(3.6, 1.4, 1.7))]
		Kind.MUELLCONTAINER, Kind.MUELLCONTAINER_BLAU:
			return [AABB(Vector3(-0.68, 0, -0.48), Vector3(1.36, CONTAINER_HOEHE, 0.96))]
		Kind.PERIPTERO:
			# Verkaufsstand und Vordach; die Oberkante traegt die Katze.
			return [
				AABB(Vector3(-0.8, 0, -0.65), Vector3(1.6, KIOSK_HOEHE, 1.3)),
				AABB(Vector3(-1.3, KIOSK_HOEHE - 0.5, -0.9), Vector3(2.6, 0.5, 1.8)),
			]
		Kind.ZAUN:
			return [AABB(Vector3(-1, 0, -0.08), Vector3(2, 1.3, 0.16))]
		Kind.ZAUN_MIT_LUECKE:
			return [AABB(Vector3(-1, ZAUN_LUECKE, -0.08), Vector3(2, 1.3 - ZAUN_LUECKE, 0.16))]
		Kind.STRASSEN_SEGMENT:
			return [AABB(Vector3(-2, -0.4, -3), Vector3(4, 0.4, 6))]
		Kind.MAUERSTUECK:
			return [AABB(Vector3(-1, 0, -0.35), Vector3(2, 0.55, 0.7))]
		Kind.GARTENTOR:
			return [AABB(Vector3(-0.6, 0, -0.06), Vector3(1.2, 1.4, 0.12))]
		Kind.KIRCHTURM:
			return [AABB(Vector3(-1.3, 0, -1.3), Vector3(2.6, 12, 2.6))]
		Kind.TANKSTELLE:
			return [
				AABB(Vector3(-3, 3.2, -2), Vector3(6, 0.45, 4)),
				AABB(Vector3(-2.6, 0, -0.15), Vector3(0.3, 3.2, 0.3)),
				AABB(Vector3(2.3, 0, -0.15), Vector3(0.3, 3.2, 0.3)),
			]
		_:
			return []

static func kind_name(kind: Kind) -> String:
	return Kind.keys()[kind].capitalize()

# --- Bauteile ---------------------------------------------------------------

static func _build(kind: Kind, surface: SurfaceTool) -> void:
	match kind:
		Kind.GESCHOSS_SEGMENT: _fassade(surface, "fenster_licht", "rollladen", false)
		Kind.BALKONBAND: _balkonband(surface)
		Kind.MARKISE_OFFEN: _markise_offen(surface, Palette.STOFF_HELL, Palette.STOFF_STREIFEN)
		Kind.MARKISE_GESCHLOSSEN: _markise_geschlossen(surface)
		Kind.DACHABSCHLUSS: _dachabschluss(surface)
		Kind.EINFAMILIENHAUS: _einfamilienhaus(surface)
		Kind.SOLARKOLLEKTOR: _solarkollektor(surface)
		Kind.SATELLITENSCHUESSEL: _satellitenschuessel(surface)
		Kind.ANTENNE: _antenne(surface)
		Kind.KLIMAGERAET: _klimageraet(surface)
		Kind.LATERNE: _laterne(surface)
		Kind.STROMMAST: _strommast(surface)
		Kind.STROMLEITUNG: _stromleitung(surface)
		Kind.GEPARKTES_AUTO: _auto(surface, false, Palette.LACK_BLAU)
		Kind.FAHRENDES_AUTO: _auto(surface, true, Palette.TAXI_GELB)
		Kind.ZAUN: _zaun(surface, false)
		Kind.ZAUN_MIT_LUECKE: _zaun(surface, true)
		Kind.GARTENTOR: _gartentor(surface)
		Kind.KIEFER: _kiefer(surface)
		Kind.ZYPRESSE: _zypresse(surface)
		Kind.OLIVENBAUM: _olivenbaum(surface)
		Kind.OLEANDERBUSCH: _oleanderbusch(surface)
		Kind.KIRCHTURM: _kirchturm(surface)
		Kind.TANKSTELLE: _tankstelle(surface)
		Kind.FISCHGRAETE: _fischgraete(surface)
		Kind.GANZER_FISCH: _ganzer_fisch(surface)
		Kind.FUTTERNAPF: _futternapf(surface)
		Kind.STRASSEN_SEGMENT: _strassen_segment(surface)
		Kind.MAUERSTUECK: _mauerstueck(surface)
		Kind.REGENRINNE: _regenrinne(surface)
		Kind.GESCHOSS_BALKONTUER: _fassade(surface, "tuer", "fenster_dunkel", true)
		Kind.GESCHOSS_FENSTER: _fassade(surface, "fenster_dunkel", "fenster_licht", false)
		Kind.LADENZEILE: _ladenzeile(surface)
		Kind.HAUSEINGANG: _hauseingang(surface)
		Kind.MARKISE_OFFEN_GRUEN: _markise_offen(surface, Palette.MARKISE_GRUEN, Palette.MARKISE_GRUEN)
		Kind.BALKONPFLANZEN: _balkonpflanzen(surface)
		Kind.WAESCHELEINE: _waescheleine(surface)
		Kind.BLUMENTOPF: _blumentopf(surface, Vector3.ZERO, 1.0, true)
		Kind.PERGOLA: _pergola(surface)
		Kind.ORANGENBAUM: _orangenbaum(surface)
		Kind.PERIPTERO: _periptero(surface)
		Kind.MUELLCONTAINER: _muellcontainer(surface, Palette.CONTAINER_GRUEN)
		Kind.MUELLCONTAINER_BLAU: _muellcontainer(surface, Palette.CONTAINER_BLAU)
		Kind.MOPED: _moped(surface)
		Kind.GEPARKTES_AUTO_SILBER: _auto(surface, false, Palette.LACK_SILBER)
		Kind.AKROPOLIS: BackgroundKit.add_acropolis(surface, 0.0, -6.0)

## Geschoss eines Athener Wohnblocks (Polykatoikia): 4 m breit, 3 m hoch,
## Front auf z = 0. Zwei Oeffnungen, jede wahlweise Fenster (hell oder dunkel),
## Rollladen oder Balkontuer; dazu auf Wunsch ein Klimageraet an der Wand.
static func _fassade(surface: SurfaceTool, left: String, right: String, with_ac: bool) -> void:
	MeshBuilder.add_box(surface, Vector3(0, 1.5, -1), Vector3(4, 3, 2), Palette.PUTZ_HELL)
	# Gesims als Geschosstrenner
	MeshBuilder.add_box(surface, Vector3(0, 2.92, -0.95), Vector3(4.1, 0.16, 2.1),
		Palette.PUTZ_SCHATTEN)
	_oeffnung(surface, -1.0, left)
	_oeffnung(surface, 1.0, right)
	if with_ac:
		# Aussengeraet der Klimaanlage - an fast jeder Athener Fassade.
		MeshBuilder.add_box(surface, Vector3(0, 2.3, 0.16), Vector3(0.72, 0.46, 0.3),
			Palette.LACK_WEISS)
		MeshBuilder.add_box(surface, Vector3(0, 2.3, 0.32), Vector3(0.44, 0.34, 0.02),
			Palette.METALL_DUNKEL)
		MeshBuilder.add_box(surface, Vector3(0, 2.04, 0.1), Vector3(0.6, 0.05, 0.2),
			Palette.METALL_DUNKEL)

static func _oeffnung(surface: SurfaceTool, x: float, kind: String) -> void:
	if kind == "tuer":
		# Balkontuer: bodentief, oben der halb heruntergelassene Rollladen.
		MeshBuilder.add_box(surface, Vector3(x, 1.12, 0.01), Vector3(1.06, 2.24, 0.06),
			Palette.PUTZ_SCHATTEN)
		MeshBuilder.add_box(surface, Vector3(x, 1.08, 0.035), Vector3(0.86, 2.06, 0.04),
			Palette.GLAS)
		MeshBuilder.add_box(surface, Vector3(x, 1.08, 0.05), Vector3(0.04, 2.06, 0.03),
			Palette.GELAENDER_WEISS)
		_rollladen(surface, Vector3(x, 1.78, 0.06), Vector3(0.86, 0.66, 0.04))
		return
	MeshBuilder.add_box(surface, Vector3(x, 1.7, 0.01), Vector3(1.04, 1.34, 0.06),
		Palette.PUTZ_SCHATTEN)
	if kind == "rollladen":
		_rollladen(surface, Vector3(x, 1.7, 0.04), Vector3(0.86, 1.16, 0.04))
	else:
		var glass := Palette.glow(Palette.FENSTER_LICHT, 0.9) if kind == "fenster_licht" \
			else Palette.GLAS
		MeshBuilder.add_box(surface, Vector3(x, 1.7, 0.035), Vector3(0.86, 1.16, 0.04), glass)
		MeshBuilder.add_box(surface, Vector3(x, 1.7, 0.05), Vector3(0.04, 1.16, 0.03),
			Palette.GELAENDER_WEISS)
	# Fensterbank
	MeshBuilder.add_box(surface, Vector3(x, 1.03, 0.07), Vector3(1.12, 0.07, 0.18),
		Palette.MARMOR_STUFE)

## Rollladen mit waagrechten Lamellen.
static func _rollladen(surface: SurfaceTool, center: Vector3, size: Vector3) -> void:
	MeshBuilder.add_box(surface, center, size, Palette.ROLLLADEN)
	var slats := int(size.y / 0.16)
	for i in slats:
		var y := center.y - size.y * 0.5 + (float(i) + 0.5) * size.y / float(slats)
		MeshBuilder.add_box(surface, Vector3(center.x, y, center.z + size.z * 0.5),
			Vector3(size.x, 0.025, 0.02), Palette.ROLLLADEN_DUNKEL)

## Balkonband mit Metallgelaender, 2-m-Modul; Ursprung auf der Oberkante.
static func _balkonband(surface: SurfaceTool) -> void:
	MeshBuilder.add_box(surface, Vector3(0, -0.12, 0), Vector3(2, 0.24, 2.4), Palette.BETON)
	var front := 1.14
	MeshBuilder.add_box(surface, Vector3(0, 0.9, front), Vector3(2, 0.06, 0.06), Palette.GELAENDER_WEISS)
	MeshBuilder.add_box(surface, Vector3(0, 0.45, front), Vector3(2, 0.04, 0.04), Palette.GELAENDER_WEISS)
	var post := -0.9
	while post <= 0.91:
		MeshBuilder.add_box(surface, Vector3(post, 0.45, front), Vector3(0.05, 0.9, 0.05),
			Palette.GELAENDER_WEISS)
		post += 0.36

## Offene Markise: gestreiftes Tuch auf zwei Armen - im Spiel eine Plattform.
static func _markise_offen(surface: SurfaceTool, cloth: Color, stripe: Color) -> void:
	var stripes := 6
	var width := 2.2
	for i in stripes:
		var x0 := -width * 0.5 + width * float(i) / float(stripes)
		var x1 := -width * 0.5 + width * float(i + 1) / float(stripes)
		var color := cloth if i % 2 == 0 else stripe
		# Tuch faellt von der Wand zur Vorderkante ab.
		MeshBuilder.add_quad(surface,
			Vector3(x0, 0.55, -0.05), Vector3(x1, 0.55, -0.05),
			Vector3(x1, 0.2, 1.05), Vector3(x0, 0.2, 1.05), color)
		MeshBuilder.add_quad(surface,
			Vector3(x0, 0.19, 1.05), Vector3(x1, 0.19, 1.05),
			Vector3(x1, 0.54, -0.05), Vector3(x0, 0.54, -0.05), color)
	MeshBuilder.add_box(surface, Vector3(0, 0.17, 1.05), Vector3(2.3, 0.1, 0.1), Palette.METALL)
	for side in [-1.0, 1.0]:
		MeshBuilder.add_box(surface, Vector3(side * 1.05, 0.38, 0.5),
			Vector3(0.05, 0.05, 1.2), Palette.METALL_DUNKEL)

## Eingerollte Markise.
static func _markise_geschlossen(surface: SurfaceTool) -> void:
	MeshBuilder.add_cylinder(surface, Vector3(0, 0.45, 0.12), 0.14, 0.14, 2.2, 10,
		Palette.STOFF_STREIFEN, Basis(Vector3.FORWARD, PI * 0.5))
	for side in [-1.0, 1.0]:
		MeshBuilder.add_box(surface, Vector3(side * 1.12, 0.45, 0.02),
			Vector3(0.06, 0.3, 0.3), Palette.METALL_DUNKEL)

## Dachabschluss mit Attika, 2-m-Modul; Ursprung auf der Dachoberkante.
static func _dachabschluss(surface: SurfaceTool) -> void:
	MeshBuilder.add_box(surface, Vector3(0, -0.15, 0), Vector3(2, 0.3, 2.4), Palette.BETON)
	# Nur eine niedrige Kante: eine hohe Attika wuerde die Beine der Katzen
	# verdecken, die auf dem Dach laufen.
	MeshBuilder.add_box(surface, Vector3(0, 0.04, 1.12), Vector3(2, 0.08, 0.16), Palette.PUTZ_HELL)
	MeshBuilder.add_box(surface, Vector3(0, 0.095, 1.12), Vector3(2, 0.03, 0.22),
		Palette.PUTZ_SCHATTEN)

## Einfamilienhaus mit rotem Ziegelvordach.
static func _einfamilienhaus(surface: SurfaceTool) -> void:
	MeshBuilder.add_box(surface, Vector3(0, 1.5, 0), Vector3(5, 3, 4), Palette.PUTZ_WARM)
	MeshBuilder.add_prism(surface, Vector3(0, 3.55, 0), Vector3(5.6, 1.1, 4.6), Palette.ZIEGEL_ROT)
	# Vordach ueber der Tuer
	MeshBuilder.add_box(surface, Vector3(0, 2.3, 2.35), Vector3(2.2, 0.12, 0.9),
		Palette.ZIEGEL_ROT)
	MeshBuilder.add_box(surface, Vector3(0, 1.05, 2.02), Vector3(0.9, 2.1, 0.08), Palette.HOLZ)
	for offset in [-1.6, 1.6]:
		MeshBuilder.add_box(surface, Vector3(offset, 1.9, 2.04), Vector3(0.9, 1.0, 0.06),
			Palette.glow(Palette.FENSTER_LICHT, 0.9))

static func _solarkollektor(surface: SurfaceTool) -> void:
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(-28.0))
	MeshBuilder.add_box(surface, Vector3(0, 0.45, 0.1), Vector3(1.6, 0.08, 1.0),
		Palette.METALL_DUNKEL, tilt)
	MeshBuilder.add_box(surface, Vector3(0, 0.47, 0.1), Vector3(1.45, 0.06, 0.85),
		Palette.GLAS, tilt)
	# Boiler dahinter
	MeshBuilder.add_cylinder(surface, Vector3(0, 0.78, -0.45), 0.24, 0.24, 1.5, 10,
		Palette.METALL, Basis(Vector3.FORWARD, PI * 0.5))
	for side in [-1.0, 1.0]:
		MeshBuilder.add_box(surface, Vector3(side * 0.7, 0.16, 0.45),
			Vector3(0.08, 0.32, 0.08), Palette.METALL_DUNKEL)

static func _satellitenschuessel(surface: SurfaceTool) -> void:
	MeshBuilder.add_box(surface, Vector3(0, 0.1, 0), Vector3(0.4, 0.2, 0.4), Palette.BETON_DUNKEL)
	MeshBuilder.add_cylinder(surface, Vector3(0, 0.55, 0), 0.05, 0.05, 0.9, 8, Palette.METALL)
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(55.0))
	MeshBuilder.add_cylinder(surface, Vector3(0, 1.0, 0.18), 0.1, 0.5, 0.2, 12,
		Palette.LACK_WEISS, tilt)
	MeshBuilder.add_box(surface, Vector3(0, 0.98, 0.5), Vector3(0.06, 0.06, 0.5), Palette.METALL)

static func _antenne(surface: SurfaceTool) -> void:
	MeshBuilder.add_box(surface, Vector3(0, 0.06, 0), Vector3(0.3, 0.12, 0.3),
		Palette.BETON_DUNKEL)
	MeshBuilder.add_cylinder(surface, Vector3(0, 0.95, 0), 0.035, 0.035, 1.8, 6, Palette.METALL)
	var y := 1.3
	var span := 0.7
	while y <= 1.8:
		MeshBuilder.add_box(surface, Vector3(0, y, 0), Vector3(span, 0.03, 0.03), Palette.METALL)
		y += 0.22
		span -= 0.14

static func _klimageraet(surface: SurfaceTool) -> void:
	MeshBuilder.add_box(surface, Vector3(0, 0.3, 0), Vector3(0.75, 0.5, 0.4), Palette.LACK_WEISS)
	MeshBuilder.add_box(surface, Vector3(0, 0.3, 0.21), Vector3(0.55, 0.36, 0.03),
		Palette.METALL_DUNKEL)
	for side in [-1.0, 1.0]:
		MeshBuilder.add_box(surface, Vector3(side * 0.3, 0.03, 0), Vector3(0.1, 0.06, 0.4),
			Palette.METALL_DUNKEL)

static func _laterne(surface: SurfaceTool) -> void:
	MeshBuilder.add_cylinder(surface, Vector3(0, 0.08, 0), 0.14, 0.11, 0.16, 8,
		Palette.BETON_DUNKEL)
	MeshBuilder.add_cylinder(surface, Vector3(0, 1.7, 0), 0.07, 0.05, 3.2, 8,
		Palette.METALL_DUNKEL)
	MeshBuilder.add_box(surface, Vector3(0.3, 3.28, 0), Vector3(0.7, 0.07, 0.07),
		Palette.METALL_DUNKEL)
	MeshBuilder.add_box(surface, Vector3(0.62, 3.18, 0), Vector3(0.34, 0.14, 0.22),
		Palette.METALL_DUNKEL)
	# Leuchtflaeche nach unten
	MeshBuilder.add_box(surface, Vector3(0.62, 3.09, 0), Vector3(0.28, 0.05, 0.18),
		Palette.LATERNE_LICHT)

static func _strommast(surface: SurfaceTool) -> void:
	MeshBuilder.add_cylinder(surface, Vector3(0, 2.5, 0), 0.12, 0.08, 5.0, 8, Palette.HOLZ)
	MeshBuilder.add_box(surface, Vector3(0, 4.6, 0), Vector3(1.6, 0.1, 0.1), Palette.HOLZ)
	MeshBuilder.add_box(surface, Vector3(0, 4.1, 0), Vector3(1.1, 0.09, 0.09), Palette.HOLZ)
	for x in [-0.6, 0.0, 0.6]:
		MeshBuilder.add_cylinder(surface, Vector3(x, 4.72, 0), 0.06, 0.05, 0.14, 6,
			Palette.GLAS)
	for y in [1.2, 1.7, 2.2]:
		MeshBuilder.add_box(surface, Vector3(0, y, 0.14), Vector3(0.34, 0.04, 0.04),
			Palette.METALL_DUNKEL)

## Durchhaengende Leitung ueber 8 m - zum Balancieren ab Level 5.
static func _stromleitung(surface: SurfaceTool) -> void:
	var span := 8.0
	var segments := 8
	var sag := 0.5
	for i in segments:
		var t0 := float(i) / float(segments)
		var t1 := float(i + 1) / float(segments)
		var y0 := -sag * sin(t0 * PI)
		var y1 := -sag * sin(t1 * PI)
		var x0 := -span * 0.5 + span * t0
		var x1 := -span * 0.5 + span * t1
		var mid := Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, 0)
		var length := Vector2(x1 - x0, y1 - y0).length()
		var angle := atan2(y1 - y0, x1 - x0)
		MeshBuilder.add_box(surface, mid, Vector3(length, 0.05, 0.05),
			Palette.METALL_DUNKEL, Basis(Vector3.BACK, angle))

## Autos. Das fahrende ist flach gehalten, damit die Katze darueber springt.
static func _auto(surface: SurfaceTool, driving: bool, lack: Color) -> void:
	var body_height := 0.44 if driving else 0.6
	var body_length := 3.2 if driving else 3.6
	var cabin_height := 0.3 if driving else 0.45
	var wheel_radius := 0.26 if driving else 0.3
	var body_y := wheel_radius + body_height * 0.5 - 0.08
	MeshBuilder.add_box(surface, Vector3(0, body_y, 0),
		Vector3(body_length, body_height, 1.7), lack)
	var cabin_y := body_y + body_height * 0.5 + cabin_height * 0.5
	MeshBuilder.add_box(surface, Vector3(-0.2, cabin_y, 0),
		Vector3(body_length * 0.5, cabin_height, 1.5), lack)
	MeshBuilder.add_box(surface, Vector3(-0.2, cabin_y, 0),
		Vector3(body_length * 0.5 - 0.12, cabin_height - 0.08, 1.56), Palette.GLAS)
	for x in [-body_length * 0.32, body_length * 0.32]:
		for z in [-0.8, 0.8]:
			MeshBuilder.add_cylinder(surface, Vector3(x, wheel_radius, z),
				wheel_radius, wheel_radius, 0.18, 8, Palette.REIFEN,
				Basis(Vector3.RIGHT, PI * 0.5))
	if driving:
		for z in [-0.55, 0.55]:
			MeshBuilder.add_box(surface, Vector3(body_length * 0.5 - 0.02, body_y, z),
				Vector3(0.08, 0.16, 0.34), Palette.SCHEINWERFER)
			MeshBuilder.add_box(surface, Vector3(-body_length * 0.5 + 0.02, body_y + 0.05, z),
				Vector3(0.06, 0.1, 0.3), Palette.glow(Palette.LACK_ROT, 0.8))
		# Taxischild auf dem Dach
		MeshBuilder.add_box(surface, Vector3(-0.2, cabin_y + cabin_height * 0.5 + 0.06, 0),
			Vector3(0.42, 0.12, 0.2), Palette.glow(Palette.TAXI_GELB, 1.2))

## Zaun, wahlweise mit Luecke unten - Hunde bleiben davor stehen.
static func _zaun(surface: SurfaceTool, with_gap: bool) -> void:
	var bottom := ZAUN_LUECKE if with_gap else 0.0
	var top := 1.3
	for x in [-1.0, 1.0]:
		MeshBuilder.add_box(surface, Vector3(x, top * 0.5, 0), Vector3(0.1, top, 0.1),
			Palette.METALL_DUNKEL)
	for y in [bottom + 0.05, top - 0.08]:
		MeshBuilder.add_box(surface, Vector3(0, y, 0), Vector3(2, 0.06, 0.06),
			Palette.METALL_DUNKEL)
	var x_bar := -0.88
	while x_bar <= 0.88:
		MeshBuilder.add_box(surface, Vector3(x_bar, (bottom + top) * 0.5, 0),
			Vector3(0.04, top - bottom, 0.04), Palette.METALL_DUNKEL)
		x_bar += 0.16

static func _gartentor(surface: SurfaceTool) -> void:
	for x in [-0.55, 0.55]:
		MeshBuilder.add_box(surface, Vector3(x, 0.7, 0), Vector3(0.08, 1.4, 0.08),
			Palette.METALL_DUNKEL)
	for y in [0.15, 1.3]:
		MeshBuilder.add_box(surface, Vector3(0, y, 0), Vector3(1.2, 0.07, 0.07),
			Palette.METALL_DUNKEL)
	var x_bar := -0.42
	while x_bar <= 0.42:
		MeshBuilder.add_box(surface, Vector3(x_bar, 0.72, 0), Vector3(0.04, 1.14, 0.04),
			Palette.METALL_DUNKEL)
		x_bar += 0.14
	MeshBuilder.add_box(surface, Vector3(0, 1.48, 0), Vector3(0.9, 0.06, 0.06),
		Palette.METALL_DUNKEL)

static func _kiefer(surface: SurfaceTool) -> void:
	MeshBuilder.add_cylinder(surface, Vector3(0, 1.1, 0), 0.16, 0.1, 2.2, 7, Palette.STAMM)
	MeshBuilder.add_cylinder(surface, Vector3(0, 2.25, 0), 1.25, 0.9, 0.3, 9,
		Palette.LAUB_DUNKEL)
	MeshBuilder.add_cylinder(surface, Vector3(0.15, 2.65, -0.1), 0.95, 0.6, 0.28, 9,
		Palette.LAUB_MITTEL)
	MeshBuilder.add_cylinder(surface, Vector3(-0.1, 3.0, 0.1), 0.6, 0.25, 0.26, 8,
		Palette.LAUB_DUNKEL)

static func _zypresse(surface: SurfaceTool) -> void:
	MeshBuilder.add_cylinder(surface, Vector3(0, 0.25, 0), 0.14, 0.12, 0.5, 6, Palette.STAMM)
	MeshBuilder.add_cylinder(surface, Vector3(0, 2.4, 0), 0.55, 0.12, 4.0, 9,
		Palette.LAUB_DUNKEL)

static func _olivenbaum(surface: SurfaceTool) -> void:
	MeshBuilder.add_cylinder(surface, Vector3(0, 0.6, 0), 0.2, 0.15, 1.2, 7, Palette.STAMM)
	MeshBuilder.add_cylinder(surface, Vector3(-0.35, 1.45, 0.1), 0.75, 0.5, 0.7, 8,
		Palette.LAUB_OLIVE)
	MeshBuilder.add_cylinder(surface, Vector3(0.4, 1.6, -0.15), 0.65, 0.4, 0.6, 8,
		Palette.LAUB_OLIVE)
	MeshBuilder.add_cylinder(surface, Vector3(0.05, 1.95, 0.05), 0.5, 0.2, 0.5, 8,
		Palette.LAUB_MITTEL)

static func _oleanderbusch(surface: SurfaceTool) -> void:
	MeshBuilder.add_cylinder(surface, Vector3(-0.25, 0.4, 0), 0.45, 0.25, 0.8, 8,
		Palette.LAUB_MITTEL)
	MeshBuilder.add_cylinder(surface, Vector3(0.28, 0.5, 0.12), 0.4, 0.2, 1.0, 8,
		Palette.LAUB_DUNKEL)
	MeshBuilder.add_cylinder(surface, Vector3(0.05, 0.35, -0.2), 0.35, 0.18, 0.7, 7,
		Palette.LAUB_MITTEL)
	for blossom in [Vector3(-0.3, 0.78, 0.12), Vector3(0.3, 0.98, 0.2),
			Vector3(0.12, 0.66, -0.3), Vector3(-0.05, 0.86, -0.05)]:
		MeshBuilder.add_box(surface, blossom, Vector3(0.12, 0.12, 0.12), Palette.BLUETE)

## Kirchturm mit Kuppel - Landmarke im Hintergrund (GDD Abschnitt 8).
static func _kirchturm(surface: SurfaceTool) -> void:
	MeshBuilder.add_box(surface, Vector3(0, 6, 0), Vector3(2.6, 12, 2.6), Palette.PUTZ_HELL)
	MeshBuilder.add_box(surface, Vector3(0, 12.1, 0), Vector3(3.0, 0.3, 3.0),
		Palette.PUTZ_SCHATTEN)
	MeshBuilder.add_dome(surface, Vector3(0, 12.25, 0), 1.6, 14, 6, Palette.KUPPEL)
	MeshBuilder.add_box(surface, Vector3(0, 14.4, 0), Vector3(0.09, 1.0, 0.09), Palette.METALL)
	MeshBuilder.add_box(surface, Vector3(0, 14.6, 0), Vector3(0.5, 0.09, 0.09), Palette.METALL)
	# Schallfenster auf allen vier Seiten
	for side in [Vector3(0, 0, 1.32), Vector3(0, 0, -1.32)]:
		MeshBuilder.add_box(surface, Vector3(0, 10.2, 0) + side, Vector3(0.7, 1.4, 0.08),
			Palette.glow(Palette.FENSTER_LICHT, 1.6))
	for side in [Vector3(1.32, 0, 0), Vector3(-1.32, 0, 0)]:
		MeshBuilder.add_box(surface, Vector3(0, 10.2, 0) + side, Vector3(0.08, 1.4, 0.7),
			Palette.glow(Palette.FENSTER_LICHT, 1.6))

## Tankstelle mit gruenem Leuchtband - einziger kuehler Farbakzent (GDD 9).
static func _tankstelle(surface: SurfaceTool) -> void:
	MeshBuilder.add_box(surface, Vector3(0, 3.42, 0), Vector3(6, 0.45, 4), Palette.BETON)
	MeshBuilder.add_box(surface, Vector3(0, 3.14, 1.98), Vector3(6.1, 0.14, 0.1),
		Palette.TANKSTELLE_GRUEN)
	MeshBuilder.add_box(surface, Vector3(0, 3.14, -1.98), Vector3(6.1, 0.14, 0.1),
		Palette.TANKSTELLE_GRUEN)
	for side in [-1.0, 1.0]:
		MeshBuilder.add_box(surface, Vector3(side * 3.02, 3.14, 0),
			Vector3(0.1, 0.14, 4.1), Palette.TANKSTELLE_GRUEN)
		MeshBuilder.add_box(surface, Vector3(side * 2.45, 1.6, 0),
			Vector3(0.3, 3.2, 0.3), Palette.BETON)
	# Zapfsaeule
	MeshBuilder.add_box(surface, Vector3(0, 0.65, 0), Vector3(0.6, 1.3, 0.5),
		Palette.LACK_WEISS)
	MeshBuilder.add_box(surface, Vector3(0, 1.05, 0.27), Vector3(0.4, 0.3, 0.04),
		Palette.glow(Palette.TANKSTELLE_GRUEN, 1.5))

static func _fischgraete(surface: SurfaceTool) -> void:
	MeshBuilder.add_box(surface, Vector3(0, 0, 0), Vector3(0.44, 0.035, 0.035), Palette.GRAETE)
	var x := -0.16
	while x <= 0.18:
		MeshBuilder.add_box(surface, Vector3(x, 0, 0), Vector3(0.025, 0.16, 0.025),
			Palette.GRAETE, Basis(Vector3.BACK, deg_to_rad(18.0)))
		x += 0.09
	MeshBuilder.add_box(surface, Vector3(0.25, 0, 0), Vector3(0.13, 0.11, 0.09), Palette.GRAETE)
	MeshBuilder.add_box(surface, Vector3(-0.26, 0, 0), Vector3(0.12, 0.13, 0.02),
		Palette.GRAETE, Basis(Vector3.BACK, deg_to_rad(35.0)))

static func _ganzer_fisch(surface: SurfaceTool) -> void:
	MeshBuilder.add_box(surface, Vector3(0, 0, 0), Vector3(0.46, 0.2, 0.13), Palette.FISCH)
	MeshBuilder.add_box(surface, Vector3(0.26, 0, 0), Vector3(0.14, 0.12, 0.1), Palette.FISCH)
	MeshBuilder.add_box(surface, Vector3(-0.3, 0, 0), Vector3(0.16, 0.22, 0.03),
		Palette.FISCH, Basis(Vector3.BACK, deg_to_rad(25.0)))
	MeshBuilder.add_box(surface, Vector3(0, 0.12, 0), Vector3(0.18, 0.1, 0.03), Palette.FISCH)
	MeshBuilder.add_box(surface, Vector3(0.28, 0.03, 0.06), Vector3(0.04, 0.04, 0.03),
		Palette.METALL_DUNKEL)

static func _futternapf(surface: SurfaceTool) -> void:
	MeshBuilder.add_cylinder(surface, Vector3(0, 0.08, 0), 0.19, 0.28, 0.16, 12, Palette.NAPF)
	MeshBuilder.add_cylinder(surface, Vector3(0, 0.16, 0), 0.22, 0.22, 0.04, 12, Palette.FUTTER)


## Strassenstueck mit Bordstein, 4-m-Modul; Ursprung auf der Fahrbahn.
static func _strassen_segment(surface: SurfaceTool) -> void:
	MeshBuilder.add_box(surface, Vector3(0, -0.2, 0), Vector3(4, 0.4, 6), Palette.ASPHALT)
	# Gehsteig vorne und hinten
	for z in [-2.55, 2.55]:
		MeshBuilder.add_box(surface, Vector3(0, -0.04, z), Vector3(4, 0.12, 0.9),
			Palette.BETON)
	# Mittellinie
	MeshBuilder.add_box(surface, Vector3(0, 0.005, 0), Vector3(1.6, 0.02, 0.12),
		Palette.LACK_WEISS)

## Niedrige Gartenmauer, 2-m-Modul - zum Darueberspringen.
static func _mauerstueck(surface: SurfaceTool) -> void:
	MeshBuilder.add_box(surface, Vector3(0, 0.26, 0), Vector3(2, 0.52, 0.7), Palette.PUTZ_WARM)
	MeshBuilder.add_box(surface, Vector3(0, 0.54, 0), Vector3(2.1, 0.06, 0.8),
		Palette.PUTZ_SCHATTEN)


## Regenrinne, 3-m-Modul zum Stapeln; Ursprung am Fuss (GDD Abschnitt 2:
## kletterbares Element). Der warme Lichtakzent kommt von der Kletterzone.
static func _regenrinne(surface: SurfaceTool) -> void:
	MeshBuilder.add_cylinder(surface, Vector3(0, 1.5, 0), 0.075, 0.075, 3.0, 8,
		Palette.METALL)
	# Schellen, die das Rohr an der Wand halten
	for y in [0.35, 1.5, 2.65]:
		MeshBuilder.add_box(surface, Vector3(0, y, -0.1), Vector3(0.2, 0.07, 0.22),
			Palette.METALL_DUNKEL)
	# Auslauf unten
	MeshBuilder.add_cylinder(surface, Vector3(0, 0.12, 0.06), 0.1, 0.085, 0.3, 8,
		Palette.METALL_DUNKEL, Basis(Vector3.RIGHT, deg_to_rad(18.0)))

# --- Athen ------------------------------------------------------------------

## Erdgeschoss mit Laden: Schaufenster, Tuer, Schild und grosse Markise ueber
## dem Gehsteig. Gleiche Masse wie ein Geschoss-Segment.
static func _ladenzeile(surface: SurfaceTool) -> void:
	MeshBuilder.add_box(surface, Vector3(0, 1.5, -1), Vector3(4, 3, 2), Palette.PUTZ_SCHATTEN)
	MeshBuilder.add_box(surface, Vector3(0, 2.92, -0.95), Vector3(4.1, 0.16, 2.1),
		Palette.PUTZ_SCHATTEN)
	# Schaufenster mit Auslage
	MeshBuilder.add_box(surface, Vector3(-0.55, 1.2, 0.02), Vector3(2.5, 1.7, 0.05),
		Palette.METALL_DUNKEL)
	MeshBuilder.add_box(surface, Vector3(-0.55, 1.2, 0.045), Vector3(2.34, 1.54, 0.04),
		Palette.glow(Palette.FENSTER_LICHT, 0.8))
	var x := -1.5
	for color in [Palette.WARE_ROT, Palette.WARE_BLAU, Palette.KIOSK_GELB, Palette.WARE_GRUEN,
			Palette.WARE_ROT]:
		MeshBuilder.add_box(surface, Vector3(x, 0.72, 0.08), Vector3(0.3, 0.42, 0.04), color)
		x += 0.46
	# Ladentuer
	MeshBuilder.add_box(surface, Vector3(1.35, 1.08, 0.02), Vector3(0.98, 2.16, 0.05),
		Palette.METALL_DUNKEL)
	MeshBuilder.add_box(surface, Vector3(1.35, 1.08, 0.045), Vector3(0.82, 2.0, 0.04),
		Palette.GLAS)
	# Ladenschild
	MeshBuilder.add_box(surface, Vector3(0, 2.52, 0.06), Vector3(3.7, 0.42, 0.08),
		Palette.LADENSCHILD)
	MeshBuilder.add_box(surface, Vector3(0, 2.52, 0.11), Vector3(2.2, 0.14, 0.02),
		Palette.glow(Palette.MARKISE_CREME, 0.5))
	# Markise ueber dem Gehsteig, gruen-creme gestreift
	var stripes := 8
	var width := 3.6
	for i in stripes:
		var x0 := -width * 0.5 + width * float(i) / float(stripes)
		var x1 := -width * 0.5 + width * float(i + 1) / float(stripes)
		var color := Palette.MARKISE_GRUEN if i % 2 == 0 else Palette.MARKISE_CREME
		MeshBuilder.add_quad(surface, Vector3(x0, 2.3, 0.1), Vector3(x1, 2.3, 0.1),
			Vector3(x1, 1.98, 0.75), Vector3(x0, 1.98, 0.75), color)
		MeshBuilder.add_quad(surface, Vector3(x0, 1.97, 0.75), Vector3(x1, 1.97, 0.75),
			Vector3(x1, 2.29, 0.1), Vector3(x0, 2.29, 0.1), color)
		MeshBuilder.add_quad(surface, Vector3(x0, 1.84, 0.75), Vector3(x1, 1.84, 0.75),
			Vector3(x1, 1.98, 0.75), Vector3(x0, 1.98, 0.75), color)

## Hauseingang einer Polykatoikia: Marmorstufen, Glastuer, Klingelbrett.
static func _hauseingang(surface: SurfaceTool) -> void:
	MeshBuilder.add_box(surface, Vector3(0, 1.5, -1), Vector3(4, 3, 2), Palette.PUTZ_HELL)
	MeshBuilder.add_box(surface, Vector3(0, 2.92, -0.95), Vector3(4.1, 0.16, 2.1),
		Palette.PUTZ_SCHATTEN)
	# Marmorverkleidung im Sockel
	MeshBuilder.add_box(surface, Vector3(0, 0.5, 0.01), Vector3(4, 1.0, 0.04), Palette.MARMOR_STUFE)
	# Eingang mit Vordach
	MeshBuilder.add_box(surface, Vector3(-0.6, 1.2, 0.03), Vector3(1.7, 2.4, 0.06),
		Palette.METALL_DUNKEL)
	MeshBuilder.add_box(surface, Vector3(-0.6, 1.15, 0.055), Vector3(1.5, 2.2, 0.04),
		Palette.glow(Palette.FENSTER_LICHT, 0.6))
	MeshBuilder.add_box(surface, Vector3(-0.6, 1.15, 0.07), Vector3(0.05, 2.2, 0.03),
		Palette.METALL_DUNKEL)
	MeshBuilder.add_box(surface, Vector3(-0.6, 2.5, 0.25), Vector3(2.0, 0.1, 0.5), Palette.BETON)
	MeshBuilder.add_box(surface, Vector3(-0.6, 0.06, 0.2), Vector3(1.9, 0.12, 0.4),
		Palette.MARMOR_STUFE)
	# Klingelbrett und Briefkaesten
	MeshBuilder.add_box(surface, Vector3(0.55, 1.4, 0.04), Vector3(0.3, 0.5, 0.04), Palette.METALL)
	MeshBuilder.add_box(surface, Vector3(1.35, 1.25, 0.05), Vector3(0.9, 0.6, 0.08),
		Palette.METALL_DUNKEL)

## Topfpflanzen fuer ein 2-m-Balkonmodul; Ursprung auf der Balkonoberkante.
static func _balkonpflanzen(surface: SurfaceTool) -> void:
	_blumentopf(surface, Vector3(-0.62, 0, 0), 0.8, true)
	_blumentopf(surface, Vector3(0.05, 0, 0.05), 1.15, false)
	_blumentopf(surface, Vector3(0.66, 0, -0.03), 0.7, true)

## Terrakottatopf mit Pflanze, wahlweise bluehend.
static func _blumentopf(surface: SurfaceTool, at: Vector3, size: float, blooming: bool) -> void:
	MeshBuilder.add_cylinder(surface, at + Vector3(0, 0.13 * size, 0), 0.13 * size, 0.18 * size,
		0.26 * size, 8, Palette.TERRAKOTTA)
	MeshBuilder.add_cylinder(surface, at + Vector3(0, 0.45 * size, 0), 0.24 * size, 0.1 * size,
		0.42 * size, 7, Palette.LAUB_MITTEL)
	MeshBuilder.add_cylinder(surface, at + Vector3(0.03, 0.62 * size, 0.02), 0.16 * size, 0.0,
		0.3 * size, 6, Palette.LAUB_DUNKEL)
	if blooming:
		for offset in [Vector3(-0.12, 0.5, 0.1), Vector3(0.13, 0.58, 0.06), Vector3(0.0, 0.7, -0.08)]:
			MeshBuilder.add_box(surface, at + offset * size, Vector3.ONE * 0.08 * size,
				Palette.BLUETE)

## Waescheleine fuer ein 2-m-Balkonmodul; Ursprung auf der Balkonoberkante.
static func _waescheleine(surface: SurfaceTool) -> void:
	MeshBuilder.add_box(surface, Vector3(0, 1.75, 0), Vector3(2.0, 0.02, 0.02), Palette.METALL)
	var x := -0.8
	var cloths := [[Palette.WAESCHE_WEISS, 0.42, 0.62], [Palette.WAESCHE_BLAU, 0.3, 0.5],
		[Palette.WAESCHE_ROT, 0.34, 0.38], [Palette.WAESCHE_GELB, 0.26, 0.56]]
	for cloth in cloths:
		var width: float = cloth[1]
		var height: float = cloth[2]
		MeshBuilder.add_box(surface, Vector3(x + width * 0.5, 1.74 - height * 0.5, 0),
			Vector3(width, height, 0.02), cloth[0])
		x += width + 0.08

## Pergola fuer die Dachterrasse, mit Weinlaub.
static func _pergola(surface: SurfaceTool) -> void:
	for x in [-1.0, 1.0]:
		for z in [-0.45, 0.45]:
			MeshBuilder.add_box(surface, Vector3(x, 1.05, z), Vector3(0.08, 2.1, 0.08), Palette.HOLZ)
	for z in [-0.45, 0.45]:
		MeshBuilder.add_box(surface, Vector3(0, 2.12, z), Vector3(2.3, 0.08, 0.08), Palette.HOLZ)
	var x_slat := -1.0
	while x_slat <= 1.01:
		MeshBuilder.add_box(surface, Vector3(x_slat, 2.19, 0), Vector3(0.06, 0.05, 1.2), Palette.HOLZ)
		x_slat += 0.4
	MeshBuilder.add_box(surface, Vector3(-0.3, 2.26, 0), Vector3(1.3, 0.1, 1.0), Palette.LAUB_MITTEL)
	MeshBuilder.add_box(surface, Vector3(0.6, 2.25, 0.1), Vector3(0.7, 0.08, 0.8), Palette.LAUB_DUNKEL)
	MeshBuilder.add_box(surface, Vector3(-1.0, 1.5, 0.45), Vector3(0.14, 0.9, 0.14), Palette.LAUB_DUNKEL)

## Bitterorangenbaum (Nerantzi) - der typische Athener Strassenbaum.
static func _orangenbaum(surface: SurfaceTool) -> void:
	MeshBuilder.add_cylinder(surface, Vector3(0, 0.85, 0), 0.11, 0.08, 1.7, 7, Palette.STAMM)
	MeshBuilder.add_cylinder(surface, Vector3(0, 1.85, 0), 0.5, 0.9, 0.5, 9, Palette.LAUB_DUNKEL)
	MeshBuilder.add_cylinder(surface, Vector3(0, 2.4, 0), 0.9, 0.9, 0.6, 9, Palette.LAUB_MITTEL)
	MeshBuilder.add_cylinder(surface, Vector3(0, 2.95, 0), 0.9, 0.45, 0.5, 9, Palette.LAUB_DUNKEL)
	for fruit in [Vector3(0.82, 2.2, 0.3), Vector3(-0.7, 2.45, 0.55), Vector3(0.2, 2.0, 0.78),
			Vector3(-0.3, 2.75, 0.74), Vector3(0.6, 2.75, 0.58), Vector3(-0.85, 2.1, 0.1),
			Vector3(0.35, 2.4, 0.86), Vector3(-0.45, 1.95, 0.6)]:
		MeshBuilder.add_box(surface, fruit, Vector3.ONE * 0.13, Palette.ORANGE_FRUCHT)

## Periptero: der Athener Kiosk mit ausladendem Vordach und buntem Sortiment.
## Sein Dach ist eine Stufe zwischen Muellcontainer und erstem Balkon.
static func _periptero(surface: SurfaceTool) -> void:
	MeshBuilder.add_box(surface, Vector3(0, 1.05, 0), Vector3(1.6, 2.1, 1.3), Palette.KIOSK_GELB)
	# Verkaufsfenster nach vorn, beleuchtet
	MeshBuilder.add_box(surface, Vector3(0, 1.45, 0.66), Vector3(1.1, 0.8, 0.04),
		Palette.glow(Palette.FENSTER_LICHT, 0.9))
	# Auslage: Zeitungen, Suessigkeiten, Getraenke
	var colors := [Palette.WARE_ROT, Palette.WARE_BLAU, Palette.WAESCHE_GELB, Palette.WARE_GRUEN]
	for row in 3:
		for column in 5:
			MeshBuilder.add_box(surface,
				Vector3(-0.56 + float(column) * 0.28, 0.3 + float(row) * 0.26, 0.7),
				Vector3(0.22, 0.2, 0.1), colors[(row * 3 + column) % colors.size()])
	for side in [-1.0, 1.0]:
		for row in 4:
			MeshBuilder.add_box(surface, Vector3(side * 0.84, 0.5 + float(row) * 0.38, 0.2),
				Vector3(0.1, 0.3, 0.7), colors[(row + int(side) + 2) % colors.size()])
	# Flaches, weit ausladendes Vordach mit Stoffblende - obenauf traegt es.
	MeshBuilder.add_box(surface, Vector3(0, KIOSK_HOEHE - 0.07, 0), Vector3(2.6, 0.14, 1.8),
		Palette.KIOSK_DACH)
	MeshBuilder.add_box(surface, Vector3(0, KIOSK_HOEHE - 0.25, 0), Vector3(1.7, 0.36, 1.4),
		Palette.KIOSK_GELB)
	for z in [-0.88, 0.88]:
		MeshBuilder.add_box(surface, Vector3(0, KIOSK_HOEHE - 0.28, z), Vector3(2.6, 0.3, 0.04),
			Palette.KIOSK_DACH.darkened(0.12))
	for x in [-1.28, 1.28]:
		MeshBuilder.add_box(surface, Vector3(x, KIOSK_HOEHE - 0.28, 0), Vector3(0.04, 0.3, 1.8),
			Palette.KIOSK_DACH.darkened(0.12))
	# Leuchtkasten an der Blende
	MeshBuilder.add_box(surface, Vector3(0, KIOSK_HOEHE - 0.28, 0.91), Vector3(1.4, 0.2, 0.04),
		Palette.glow(Palette.MARKISE_CREME, 0.9))
	# Kuehlschrank daneben
	MeshBuilder.add_box(surface, Vector3(-1.02, 0.7, -0.3), Vector3(0.4, 1.4, 0.5), Palette.LACK_WEISS)
	MeshBuilder.add_box(surface, Vector3(-1.02, 0.75, -0.04), Vector3(0.3, 1.1, 0.03),
		Palette.glow(Palette.WARE_BLAU, 0.6))

## Muellcontainer auf Rollen - in Athen an jeder Ecke, gruen oder blau.
static func _muellcontainer(surface: SurfaceTool, color: Color) -> void:
	MeshBuilder.add_box(surface, Vector3(0, 0.6, 0), Vector3(1.26, 0.84, 0.86), color)
	MeshBuilder.add_box(surface, Vector3(0, 0.3, 0), Vector3(1.1, 0.24, 0.74), color.darkened(0.15))
	# Deckel, leicht ueberstehend
	MeshBuilder.add_box(surface, Vector3(0, CONTAINER_HOEHE - 0.06, 0), Vector3(1.36, 0.12, 0.96),
		color.darkened(0.25))
	MeshBuilder.add_box(surface, Vector3(0, 0.92, 0.45), Vector3(0.9, 0.05, 0.06),
		Palette.METALL_DUNKEL)
	for x in [-0.5, 0.5]:
		for z in [-0.34, 0.34]:
			MeshBuilder.add_cylinder(surface, Vector3(x, 0.09, z), 0.09, 0.09, 0.07, 8,
				Palette.REIFEN, Basis(Vector3.RIGHT, PI * 0.5))

## Geparktes Moped - Zierde am Strassenrand.
static func _moped(surface: SurfaceTool) -> void:
	for x in [-0.55, 0.55]:
		MeshBuilder.add_cylinder(surface, Vector3(x, 0.24, 0), 0.24, 0.24, 0.1, 10,
			Palette.REIFEN, Basis(Vector3.RIGHT, PI * 0.5))
	MeshBuilder.add_box(surface, Vector3(-0.1, 0.42, 0), Vector3(0.9, 0.24, 0.26), Palette.LACK_ROT)
	MeshBuilder.add_box(surface, Vector3(-0.35, 0.62, 0), Vector3(0.62, 0.12, 0.28), Palette.REIFEN)
	MeshBuilder.add_box(surface, Vector3(0.42, 0.7, 0), Vector3(0.12, 0.7, 0.3), Palette.LACK_ROT,
		Basis(Vector3.BACK, deg_to_rad(-18.0)))
	MeshBuilder.add_box(surface, Vector3(0.36, 1.05, 0), Vector3(0.08, 0.06, 0.6),
		Palette.METALL_DUNKEL)
	MeshBuilder.add_box(surface, Vector3(0.5, 0.92, 0), Vector3(0.08, 0.14, 0.16),
		Palette.SCHEINWERFER)
	MeshBuilder.add_box(surface, Vector3(-0.78, 0.6, 0), Vector3(0.24, 0.22, 0.28), Palette.LACK_WEISS)
