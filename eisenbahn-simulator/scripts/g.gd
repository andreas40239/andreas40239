class_name G
extends RefCounted
## Gemeinsame Konstanten und Hilfsfunktionen.

const T := 4.0                      # Kantenlänge einer Kachel in Welt-Einheiten
const N := 0
const E := 1
const S := 2
const W := 3
const DX: Array[int] = [0, 1, 0, -1]
const DZ: Array[int] = [-1, 0, 1, 0]

enum Terrain { GRASS, WATER, ROAD, ZONE_START, ZONE_GOAL, RESERVED }
enum Obst { NONE, TREE, HOUSE, ROCK }
enum Kind { TRACK, SWITCH, BRIDGE, CROSSING, STATION }
enum Tool { VIEW, TRACK, SWITCH, BRIDGE, CROSSING, STATION, ERASE }

const COST := {
	Kind.TRACK: 10,
	Kind.SWITCH: 40,
	Kind.BRIDGE: 80,
	Kind.CROSSING: 50,
	Kind.STATION: 30,
}

const RAIL_TOP := 0.28              # Höhe der Schienenoberkante
const GAUGE := 0.42                 # halbe Spurweite
const MAX_SPEED := 5.2              # Welt-Einheiten pro Sekunde
const KMH := 15.4                   # Umrechnung Einheiten/s -> km/h (Anzeige)


static func opp(d: int) -> int:
	return (d + 2) % 4


static func dir_vec(d: int) -> Vector3:
	return Vector3(DX[d], 0, DZ[d])


static func step(t: Vector2i, d: int) -> Vector2i:
	return Vector2i(t.x + DX[d], t.y + DZ[d])


static func tile_center(t: Vector2i) -> Vector3:
	return Vector3((t.x + 0.5) * T, 0.0, (t.y + 0.5) * T)


static func world_to_tile(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / T), floori(p.z / T))


## Länge einer Verbindung zwischen zwei Kachelkanten (Gerade oder Viertelkreis).
static func link_len(a: int, b: int) -> float:
	return T if opp(a) == b else PI * T * 0.25


## Punkt und Tangente (Richtung a -> b) auf einer Verbindung, relativ zur Kachelmitte.
static func link_point(a: int, b: int, s: float) -> Array:
	var pa := dir_vec(a) * (T * 0.5)
	var pb := dir_vec(b) * (T * 0.5)
	if opp(a) == b:
		var k := clampf(s / T, 0.0, 1.0)
		return [pa.lerp(pb, k), (pb - pa).normalized()]
	var c := pa + pb
	var va := pa - c
	var vb := pb - c
	var th := clampf(s / (T * 0.5), 0.0, PI * 0.5)
	var pos := c + va * cos(th) + vb * sin(th)
	var tan := (-va * sin(th) + vb * cos(th)).normalized()
	return [pos, tan]


## Stützpunkte [Position, Tangente] entlang einer Verbindung.
static func link_path(a: int, b: int, segs: int = 12) -> Array:
	var out := []
	var n := 1 if opp(a) == b else segs
	var ln := link_len(a, b)
	for i in n + 1:
		out.append(link_point(a, b, ln * float(i) / n))
	return out


static func hash2(x: int, y: int, seed_val: int = 0) -> int:
	var h := (x * 374761393 + y * 668265263 + seed_val * 1274126177) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return h ^ (h >> 16)


static func col(hex: String) -> Color:
	return Color.html(hex)
