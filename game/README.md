# Eidechsen-Spiel — Vertical Slice

Godot 4.3 project. Open `game/` as a project in Godot 4.3+ (`project.godot`
is at this folder's root) and run the main scene (`scenes/world/main.tscn`).

## Scope of this vertical slice

Full design: `docs/design-document.md`. This slice implements a subset, to
test the core mechanics before building the full game:

- **15 growth levels**, satiety thresholds and speed/size scale with a
  formula (`GameManager`) rather than a hand-authored table. Spikes appear
  from level 5 (lets the player fend off predators/rivals it has outgrown
  instead of getting caught by them); the player looks like a small T-Rex
  from level 10.
- **4 animal species**: Ameise (prey, always edible, spawned in large
  numbers), Fremde Eidechse (rival — edible once your level is higher),
  Moewe and Krabbe (dangerous predators until spikes let you fend them
  off). Spawned dynamically by `EnemySpawner`, weighted so ants dominate.
- **One continuously growing map**, expanding left/right/up/down around
  the den on every level-up (not just sideways) — see
  `GameManager.get_map_half_extent()` / `world main.gd`.
- The den is a safe zone: the player takes no damage while inside it.
- **No day/night cycle**, no endless mode, no story-mode meta-progression
  beyond the 15 levels — deferred to the full build.
- Local save (`user://savegame.json`) persists growth level/satiety.
- Placeholder art: small multi-part vector critters (`CritterShapes`) built
  from Polygon2D/Line2D primitives, top-down 2D instead of the target
  pseudo-isometric look — enough to test movement, eating, fleeing/chasing
  AI, growth, and map growth.
- Placeholder audio: procedurally synthesized chiptune SFX (eat/caught/
  level-up), an 8-bit-style music loop, and an ocean ambience loop — see
  `tools/generate_audio.py`.

## Controls

- **Touch** (Android target): first touch sets the joystick's center;
  dragging from that point steers the lizard. A translucent ring + knob
  show where the touch registered.
- **Desktop testing**: arrow keys / WASD move the lizard directly. Mouse
  click-drag also works as a touch emulation (enabled via
  `input_devices/pointing/emulate_touch_from_mouse` in `project.godot`) to
  test the actual touch-pad behavior without a touchscreen.

## Project layout

- `scripts/autoload/` — `GameManager` (growth level/stage formulas, map
  size, satiety), `SaveManager` (`user://` persistence), `AudioManager`
  (music/ambience/SFX, reacts to GameManager signals).
- `scripts/data/enemy_data.gd` + `resources/enemies/*.tres` — animal
  species as data resources (add a new species without touching code).
- `scripts/enemies/enemy.gd` — single state machine (patrol/flee/chase/
  attack/return/fended-off) shared by all species, driven by their data
  resource.
- `scripts/world/enemy_spawner.gd` — spawns enemies dynamically within the
  current map bounds instead of hand-placed per-zone nodes.
- `scripts/player/lizard.gd` — movement, eating, growth visuals (incl.
  spikes/T-Rex), den safety, fend-off, respawn.
- `scripts/util/critter_shapes.gd` — shared vector-shape builders for the
  player and enemies.
- `scripts/world/` — `Den` (level-up trigger, respawn point, safe zone),
  `FruitBush` (powerup), `main.gd` (map growth orchestration).
- `scripts/ui/hud.gd` — satiety bar, level label, event messages.
- `tools/generate_audio.py` — regenerates `assets/audio/*.wav` (pure
  stdlib synthesis, no dependencies).

## Testing

There's no in-editor test runner set up; validate with headless Godot:

```sh
rm -f "$HOME/.local/share/godot/app_userdata/Eidechsen-Spiel (Vertical Slice)/savegame.json"
godot --headless --path game --script tests/smoke_test.gd
godot --headless --path game --script tests/smoke_test_touch.gd
```

`tests/smoke_test.gd` drives a real instance of `main.tscn` (no scene/UI
mocking) and exercises: the enemy spawner producing enemies (incl. ants),
den safety, eating prey via physics overlap, the fruit powerup, leveling
to 5 (spikes + map growing in both axes) and to 10 (T-Rex), the
spikes-fend-off rule, the rival-lizard edibility rule, getting caught by a
predator (below the fend-off threshold) and respawning at the den without
losing progress, and save/load.

`tests/smoke_test_touch.gd` pushes real `InputEventScreenTouch`/`Drag`
events through the viewport (not direct method calls) to catch input bugs
that only manifest through the real input pipeline (e.g. a full-screen UI
element silently absorbing touches).

For manual/visual testing, open the project in the Godot editor and run
the main scene; use mouse-drag to test the dynamic touch pad.
