# Eidechsen-Spiel — Vertical Slice

Godot 4.3 project. Open `game/` as a project in Godot 4.3+ (`project.godot`
is at this folder's root) and run the main scene (`scenes/world/main.tscn`).

## Scope of this vertical slice

Full design: `docs/design-document.md`. This slice intentionally implements
only a subset, to test the core mechanics before building the full game:

- **3 growth levels** (not 10+), satiety thresholds 100 / 150.
- **4 animal species**: Ameise (prey, always edible), Fremde Eidechse
  (rival — edible once your level is higher), Moewe and Krabbe (always
  dangerous predators).
- **One continuously growing map** with 3 zones, unlocked by leveling up
  (barriers open, camera limits widen, new enemies appear) — matches the
  design doc's "map grows with each level-up" rather than separate level
  scenes.
- **No day/night cycle**, no endless mode, no story-mode meta-progression
  beyond the 3 levels — deferred to the full build.
- Local save (`user://savegame.json`) persists growth level/satiety.
- Placeholder art: flat-colored polygons (no sprites yet), top-down 2D
  instead of the target pseudo-isometric look — enough to test movement,
  eating, fleeing/chasing AI, growth, and map unlocking.

## Controls

- **Touch** (Android target): first touch sets the joystick's center;
  dragging from that point steers the lizard.
- **Desktop testing**: arrow keys / WASD move the lizard directly. Mouse
  click-drag also works as a touch emulation (enabled via
  `input_devices/pointing/emulate_touch_from_mouse` in `project.godot`) to
  test the actual touch-pad behavior without a touchscreen.

## Project layout

- `scripts/autoload/` — `GameManager` (growth level, satiety, thresholds),
  `SaveManager` (`user://` persistence).
- `scripts/data/enemy_data.gd` + `resources/enemies/*.tres` — animal
  species as data resources (add a new species without touching code).
- `scripts/enemies/enemy.gd` — single state machine (patrol/flee/chase/
  attack/return) shared by all species, driven by their data resource.
- `scripts/player/lizard.gd` — movement, eating, growth visuals, respawn.
- `scripts/world/` — `Den` (level-up trigger + respawn point), `FruitBush`
  (powerup), `Main` (zone/barrier unlock orchestration).
- `scripts/ui/hud.gd` — satiety bar, level label, event messages.

## Testing

There's no in-editor test runner set up; validate with headless Godot:

```sh
rm -f "$HOME/.local/share/godot/app_userdata/Eidechsen-Spiel (Vertical Slice)/savegame.json"
godot --headless --path game --script tests/smoke_test.gd
```

`tests/smoke_test.gd` drives a real instance of `main.tscn` (no scene/UI
mocking) and exercises: eating prey via physics overlap, the fruit
powerup, both level-ups (den + satiety threshold, barrier/zone unlock,
camera limit change), the rival-lizard edibility rule, getting caught by
a predator and respawning at the den without losing progress, and
save/load.

For manual/visual testing, open the project in the Godot editor and run
the main scene; use mouse-drag to test the dynamic touch pad.
