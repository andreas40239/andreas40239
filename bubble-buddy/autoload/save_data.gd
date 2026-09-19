extends Node
## Local-only persistence for Bubble Buddy.
##
## Everything the game remembers lives in one ConfigFile inside the OS-provided
## per-app user directory. Nothing is transmitted, no identifiers are generated,
## and no third-party SDK is involved. The stats below exist purely so the
## Parent Dashboard has something to show; they never leave the device.

const SAVE_PATH := "user://bubble_buddy.cfg"
const STICKERS_PER_ZONE := 10
const TOTAL_STICKERS := 50
const SESSION_HISTORY := 20

signal settings_changed
signal stickers_changed

# --- Collection -------------------------------------------------------------
var pearls_lifetime := 0
var pearls_best_run := 0
var gates_best_run := 0
var gates_lifetime := 0
var golden_shells := 0
var friends_rescued := {}        # species id -> count
var stickers := {}               # sticker index -> true
var zone_badges := {}            # zone index -> true

# --- Daily surprise (local clock only, never a server) ----------------------
var daily_date := ""
var daily_species := ""
var daily_claimed := false

# --- Settings (Parent Dashboard) -------------------------------------------
var music_enabled := true
var sfx_enabled := true
var scroll_speed_scale := 1.0     # 0.7 .. 1.3, accessibility
var session_limit_minutes := 0    # 0 = no limit
var shape_cues := true            # colour-blind friendly shape overlays
var tilt_enabled := false         # optional tilt steering, off by default

# --- Local-only metrics (GDD section 13, parent review only) ---------------
var playtime_seconds := 0.0
var sessions_played := 0
var hits_taken := 0
var quits_after_hit := 0
var session_lengths := []

var _dirty := false
var _autosave_accum := 0.0


func _ready() -> void:
	load_game()
	refresh_daily()


func _process(delta: float) -> void:
	# Cheap, bounded autosave so a tablet being closed mid-run loses nothing.
	if _dirty:
		_autosave_accum += delta
		if _autosave_accum >= 5.0:
			save_game()


func load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	pearls_lifetime = cfg.get_value("collection", "pearls_lifetime", 0)
	pearls_best_run = cfg.get_value("collection", "pearls_best_run", 0)
	gates_best_run = cfg.get_value("collection", "gates_best_run", 0)
	gates_lifetime = cfg.get_value("collection", "gates_lifetime", 0)
	golden_shells = cfg.get_value("collection", "golden_shells", 0)
	friends_rescued = cfg.get_value("collection", "friends_rescued", {})
	stickers = cfg.get_value("collection", "stickers", {})
	zone_badges = cfg.get_value("collection", "zone_badges", {})

	daily_date = cfg.get_value("daily", "date", "")
	daily_species = cfg.get_value("daily", "species", "")
	daily_claimed = cfg.get_value("daily", "claimed", false)

	music_enabled = cfg.get_value("settings", "music", true)
	sfx_enabled = cfg.get_value("settings", "sfx", true)
	scroll_speed_scale = cfg.get_value("settings", "scroll_speed", 1.0)
	session_limit_minutes = cfg.get_value("settings", "session_limit", 0)
	shape_cues = cfg.get_value("settings", "shape_cues", true)
	tilt_enabled = cfg.get_value("settings", "tilt", false)

	playtime_seconds = cfg.get_value("stats", "playtime", 0.0)
	sessions_played = cfg.get_value("stats", "sessions", 0)
	hits_taken = cfg.get_value("stats", "hits", 0)
	quits_after_hit = cfg.get_value("stats", "quits_after_hit", 0)
	session_lengths = cfg.get_value("stats", "session_lengths", [])


func save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("collection", "pearls_lifetime", pearls_lifetime)
	cfg.set_value("collection", "pearls_best_run", pearls_best_run)
	cfg.set_value("collection", "gates_best_run", gates_best_run)
	cfg.set_value("collection", "gates_lifetime", gates_lifetime)
	cfg.set_value("collection", "golden_shells", golden_shells)
	cfg.set_value("collection", "friends_rescued", friends_rescued)
	cfg.set_value("collection", "stickers", stickers)
	cfg.set_value("collection", "zone_badges", zone_badges)

	cfg.set_value("daily", "date", daily_date)
	cfg.set_value("daily", "species", daily_species)
	cfg.set_value("daily", "claimed", daily_claimed)

	cfg.set_value("settings", "music", music_enabled)
	cfg.set_value("settings", "sfx", sfx_enabled)
	cfg.set_value("settings", "scroll_speed", scroll_speed_scale)
	cfg.set_value("settings", "session_limit", session_limit_minutes)
	cfg.set_value("settings", "shape_cues", shape_cues)
	cfg.set_value("settings", "tilt", tilt_enabled)

	cfg.set_value("stats", "playtime", playtime_seconds)
	cfg.set_value("stats", "sessions", sessions_played)
	cfg.set_value("stats", "hits", hits_taken)
	cfg.set_value("stats", "quits_after_hit", quits_after_hit)
	cfg.set_value("stats", "session_lengths", session_lengths)

	cfg.save(SAVE_PATH)
	_dirty = false
	_autosave_accum = 0.0


func mark_dirty() -> void:
	_dirty = true


# --- Daily surprise ---------------------------------------------------------

## Picks today's Golden Friend from the device clock. Deterministic for a given
## date so the child sees the same friend all day, with no server involved.
func refresh_daily() -> void:
	var today := Time.get_date_string_from_system()
	if today == daily_date and daily_species != "":
		return
	var species: Array = Zones.FRIEND_SPECIES
	var seed_value := 0
	for i in today.length():
		seed_value = seed_value * 31 + today.unicode_at(i)
	daily_date = today
	daily_species = species[abs(seed_value) % species.size()]
	daily_claimed = false
	mark_dirty()


# --- Mutators ---------------------------------------------------------------

func add_pearls(count: int) -> void:
	pearls_lifetime += count
	mark_dirty()


func record_friend(species: String) -> void:
	friends_rescued[species] = int(friends_rescued.get(species, 0)) + 1
	mark_dirty()


func friend_count(species: String) -> int:
	return int(friends_rescued.get(species, 0))


func has_sticker(index: int) -> bool:
	return stickers.has(index)


func sticker_count() -> int:
	return stickers.size()


## Grants the first unfound sticker belonging to `zone`, returning its index or
## -1 when that zone's page is already complete.
func grant_zone_sticker(zone: int) -> int:
	var base := zone * STICKERS_PER_ZONE
	for i in range(base, base + STICKERS_PER_ZONE):
		if not stickers.has(i):
			stickers[i] = true
			mark_dirty()
			stickers_changed.emit()
			return i
	return -1


func grant_sticker(index: int) -> bool:
	if stickers.has(index):
		return false
	stickers[index] = true
	mark_dirty()
	stickers_changed.emit()
	return true


func record_run(pearls: int, gates: int, seconds: float, ended_right_after_hit: bool, zone_reached: int) -> void:
	pearls_best_run = maxi(pearls_best_run, pearls)
	gates_best_run = maxi(gates_best_run, gates)
	gates_lifetime += gates
	sessions_played += 1
	playtime_seconds += seconds
	if ended_right_after_hit:
		quits_after_hit += 1
	session_lengths.append(roundi(seconds))
	while session_lengths.size() > SESSION_HISTORY:
		session_lengths.pop_front()
	# A zone badge is earned by passing five Coral Gates in a single run.
	if gates >= 5:
		zone_badges[zone_reached] = true
	save_game()


func average_session_seconds() -> float:
	if session_lengths.is_empty():
		return 0.0
	var total := 0.0
	for s in session_lengths:
		total += float(s)
	return total / float(session_lengths.size())


func apply_settings() -> void:
	mark_dirty()
	settings_changed.emit()
