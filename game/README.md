# Eidechsen-Spiel — Vertical Slice

Godot 4.3 project. Open `game/` as a project in Godot 4.3+ (`project.godot`
is at this folder's root) and run the main scene (`scenes/world/main.tscn`).

## Scope of this vertical slice

Full design: `docs/design-document.md`. This slice implements a subset, to
test the core mechanics before building the full game:

- **21 growth levels**, satiety thresholds/speed/size/max-health scale
  with formulas (`GameManager`) rather than a hand-authored table.
  - Level 5: spikes appear, letting the player fend off predators/rivals
    it has outgrown instead of taking damage from them.
  - Level 10: looks like a small T-Rex.
  - Level 20: transforms into Godzilla and periodically breathes fire in
    a forward cone, instantly destroying anything caught in it (even
    otherwise-unbeatable enemies) for a satiety reward.
- **Health system**: the player has HP (`Lizard.health`/`max_health`,
  `GameManager.get_max_health()`). Contact with a dangerous animal chips
  health on a cooldown rather than an instant "catch"; reaching 0 sends
  the player back to the den and fully heals (same no-progress-loss
  respawn as before). The den also recharges health over time while the
  player stays inside it (in addition to being a safe zone).
- **9 animal species**, spawned dynamically and weighted by
  `EnemySpawner` (so ants dominate numerically):
  - Ameise / Fremde Eidechse / Möwe / Krabbe: as before, but Möwe and
    Krabbe now require a sustained fight once the player reaches their
    `edible_level` (7 / 9) - the player deals `GameManager.get_bite_dps()`
    per second to the animal's HP, and the animal fights back
    (`damage_per_tick`) until either it's defeated (eaten) or the player
    breaks contact.
  - Grosse Ameise (level 4+): harmless but has HP, needs ~2s of contact
    before it can be eaten.
  - Rote Ameise (level 11+) / Schwarze Krabbe (level 14+): tougher
    reskins of the above with real `damage_per_tick`, always fightable
    from the moment they exist.
  - Oviraptor (level 17+): fast, deals damage, `unbeatable = true` - can
    never be fended off or eaten by normal means (only Godzilla's fire
    breath kills it).
  - Hubschrauber (level 21+): `ranged = true`, keeps `preferred_range`
    (70px) and fires periodic ranged damage instead of melee contact;
    also unbeatable outside of fire breath.
- **One continuously growing map**, expanding left/right/up/down around
  the den on every level-up (not just sideways) — see
  `GameManager.get_map_half_extent()` / `world main.gd`.
- The den is a safe zone: the player takes no damage while inside it.
- **No day/night cycle**, no endless mode, no story-mode meta-progression
  beyond the 21 levels — deferred to the full build.
- Local save (`user://savegame.json`) persists growth level/satiety
  (health resets to full each session; it's session combat state, not
  core progression).
- Placeholder art: small multi-part vector critters (`CritterShapes`) built
  from Polygon2D/Line2D primitives, top-down 2D instead of the target
  pseudo-isometric look.
- Placeholder audio (`tools/generate_audio.py`, stdlib-only synthesis):
  chiptune SFX for eat/caught/level-up; a polyphonic, modern-style music
  loop (sustained pad chords + bass + lead layered together, soft
  sine/triangle tone instead of square, light algorithmic echo, calm
  passages alternating with faster ones); and an ocean ambience loop.

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
  size, satiety, max health, bite DPS), `SaveManager` (`user://`
  persistence), `AudioManager` (music/ambience/SFX, reacts to GameManager
  signals).
- `scripts/data/enemy_data.gd` + `resources/enemies/*.tres` — animal
  species as data resources (add a new species without touching code).
- `scripts/enemies/enemy.gd` — movement state machine (patrol/flee/chase/
  attack/orbit/return), decoupled from a separate contact-resolution
  layer (eat / timed fight / periodic damage / fend-off / ranged shots),
  driven entirely by each species' data resource.
- `scripts/world/enemy_spawner.gd` — spawns enemies dynamically within the
  current map bounds instead of hand-placed per-zone nodes.
- `scripts/player/lizard.gd` — movement, eating, health, growth visuals
  (incl. spikes/T-Rex/Godzilla), fire breath, den safety, fend-off,
  respawn.
- `scripts/util/critter_shapes.gd` — shared vector-shape builders for the
  player and enemies.
- `scripts/world/` — `Den` (level-up trigger, respawn point, safe zone +
  health recharge), `FruitBush` (powerup), `main.gd` (map growth
  orchestration).
- `scripts/ui/hud.gd` — health bar, satiety bar, level label, event
  messages.
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
mocking) and exercises, roughly in order: the enemy spawner producing
enemies (incl. ants), den safety (incl. against the damage-tick path),
predators giving up rather than camping at the den, eating prey via
physics overlap, the fruit powerup, the big-ant timed fight (~2s at level
4), sustained predator contact chipping health, health hitting 0
respawning + fully healing, den health regen, leveling to 5 (spikes +
map growing in both axes) with the fend-off rule, the rival-lizard
edibility rule, leveling to 7 (gulls become fightable) and to 10
(T-Rex), the Oviraptor being damaging-but-unbeatable at level 17, the
Godzilla fire breath at level 20 (instantly destroying an Oviraptor for
a satiety reward), the helicopter's ranged behavior at level 21, and
save/load.

Note: several of these tests plant an enemy at a specific position and
assert exactly what happens - the spawner's ambient wildlife is disabled
partway through the suite so it doesn't flakily interfere. A few tests
also had to explicitly settle/clear `in_den` after directly faking den
entry/exit calls, since the *real* Area2D signal (which lags a frame
behind, like any Godot Area2D) will otherwise correct a faked flag out
from under the test if the player's actual position doesn't match it -
this bit real test runs during development (see the git history) and is
worth knowing about before adding more tests in this style.

`tests/smoke_test_touch.gd` pushes real `InputEventScreenTouch`/`Drag`
events through the viewport (not direct method calls) to catch input bugs
that only manifest through the real input pipeline (e.g. a full-screen UI
element silently absorbing touches).

For manual/visual testing, open the project in the Godot editor and run
the main scene; use mouse-drag to test the dynamic touch pad.
