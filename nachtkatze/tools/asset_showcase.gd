extends Node3D
## Schauszene fuer das Asset-Kit: stellt jedes Bauteil beschriftet auf.
## Dient zum Sichten und als Vorlage beim Levelbau.
##
## Start: xvfb-run godot --rendering-driver opengl3 --path nachtkatze \
##          --resolution 1600x900 res://tools/asset_showcase.tscn

const PIECE_SCENE := preload("res://scenes/world/asset_piece.tscn")
const ROW_SPACING := 11.0

const GROUPS := [
	{"name": "Wohnblock", "kinds": [
		AssetKit.Kind.GESCHOSS_SEGMENT, AssetKit.Kind.BALKONBAND,
		AssetKit.Kind.MARKISE_OFFEN, AssetKit.Kind.MARKISE_GESCHLOSSEN,
		AssetKit.Kind.DACHABSCHLUSS, AssetKit.Kind.EINFAMILIENHAUS]},
	{"name": "Dach-Props", "kinds": [
		AssetKit.Kind.SOLARKOLLEKTOR, AssetKit.Kind.SATELLITENSCHUESSEL,
		AssetKit.Kind.ANTENNE, AssetKit.Kind.KLIMAGERAET]},
	{"name": "Strasse", "kinds": [
		AssetKit.Kind.LATERNE, AssetKit.Kind.STROMMAST, AssetKit.Kind.STROMLEITUNG,
		AssetKit.Kind.GEPARKTES_AUTO, AssetKit.Kind.FAHRENDES_AUTO,
		AssetKit.Kind.ZAUN, AssetKit.Kind.ZAUN_MIT_LUECKE, AssetKit.Kind.GARTENTOR]},
	{"name": "Vegetation", "kinds": [
		AssetKit.Kind.KIEFER, AssetKit.Kind.ZYPRESSE,
		AssetKit.Kind.OLIVENBAUM, AssetKit.Kind.OLEANDERBUSCH]},
	{"name": "Untergrund", "kinds": [
		AssetKit.Kind.STRASSEN_SEGMENT, AssetKit.Kind.MAUERSTUECK]},
	{"name": "Landmarken und Futter", "kinds": [
		AssetKit.Kind.KIRCHTURM, AssetKit.Kind.TANKSTELLE,
		AssetKit.Kind.FISCHGRAETE, AssetKit.Kind.GANZER_FISCH,
		AssetKit.Kind.FUTTERNAPF]},
]

## Ausdehnung jeder Reihe - das Bilderwerkzeug rahmt danach die Aufnahmen.
var row_infos: Array[Dictionary] = []

func _ready() -> void:
	AssetKit.configure_material()
	var row := 0
	for group in GROUPS:
		_build_row(group["name"], group["kinds"], -float(row) * ROW_SPACING)
		row += 1

func _build_row(title: String, kinds: Array, z: float) -> void:
	# Jede Reihe in einem eigenen Knoten: so laesst sie sich einzeln ablichten.
	var row_node := Node3D.new()
	row_node.name = "Reihe%d" % row_infos.size()
	add_child(row_node)
	var x := 0.0
	var max_height := 1.0
	for kind in kinds:
		var piece: AssetPiece = PIECE_SCENE.instantiate()
		piece.kind = kind
		row_node.add_child(piece)
		var box := AssetKit.get_mesh(kind).get_aabb()
		max_height = maxf(max_height, box.size.y)
		x += box.size.x * 0.5 + 0.9
		# Bauteile mit Ursprung an der Oberkante wuerden sonst im Boden stecken.
		piece.position = Vector3(x - box.get_center().x, maxf(-box.position.y, 0.0), z)
		var name_label := Label3D.new()
		name_label.text = AssetKit.kind_name(kind)
		name_label.font_size = 64
		name_label.pixel_size = 0.006
		name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		name_label.modulate = Color(1, 1, 1)
		name_label.outline_size = 16
		name_label.position = Vector3(x, box.size.y + maxf(-box.position.y, 0.0) + 0.55, z)
		row_node.add_child(name_label)
		x += box.size.x * 0.5 + 1.8

	var label := Label3D.new()
	label.text = title
	label.font_size = 110
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1, 0.88, 0.62)
	label.outline_size = 20
	label.position = Vector3(x * 0.5, max_height + 2.2, z)
	row_node.add_child(label)
	row_infos.append({"name": title, "z": z, "width": x, "height": max_height,
		"node": row_node})
