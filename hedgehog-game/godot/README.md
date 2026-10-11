# Hedgehog Highways: Prototype (M1)

A grey-box Godot 4 prototype of the core loop from the [Game Design Document](../GDD.md):
**forage → avoid the cat → collect nest material → hibernate in a safe spot**.

All visuals are built from simple shapes. The goal is to find out whether the loop is fun before investing in art.

## Running it

1. Install **Godot 4.3** or newer (the standard version, not .NET) from <https://godotengine.org/download>.
2. Start Godot, click **Import**, and select `hedgehog-game/godot/project.godot`.
3. Press **F5** (or the ▶ Play button).

## Controls

| Action | Keyboard / Mouse | Gamepad |
|---|---|---|
| Move | WASD / arrow keys | Left stick / D-pad |
| Look around | Drag with the mouse, or Z / X | Right stick |
| Sniff (hold) | Space | A / ✕ |
| Roll into a ball (hold) | Shift | B / ○ |
| Interact (eat, pick up, build nest, sleep) | E / Enter | X / □ |
| Restart | R | Start |

Input actions are registered in code (`scripts/game.gd`), so they don't appear in *Project Settings → Input Map*.

## What's in the prototype

| Feature | Where | Notes |
|---|---|---|
| Hedgehog with **Health** (3 hearts) and **Dexterity** | `scripts/player.gd` | Dexterity raises speed and makes footsteps quieter. It slowly drops as winter approaches and while rolled up. |
| **Food**: beetle, earthworm, slug, fallen apple, milk | `scripts/food.gd` | Milk is "bad food": tummy-ache wobble and −1 heart, but it never takes the last heart. Food respawns after 45 s (the milk saucer does not). |
| **Sniff mode** | `player.gd`, `scripts/scent.gd` | Desaturates the world, lowers the camera and shows coloured scent columns: green = food, yellow = nest material, blue = safe hibernation spot, red = cat. The radius grows with dexterity. |
| **Cat AI** | `scripts/cat.gd` | Patrol → `?` suspicious → `!` stalk → crouch and pounce. Uses a vision cone, line of sight and hearing (noisy when scurrying with low dexterity). |
| **Roll into a ball** | `player.gd` | The cat can't catch a rolled-up hedgehog. It paws at it, says "meh" and wanders off. |
| **Hiding** | `scripts/hide_spot.gd` | Bushes and the space under the shed hide the hedgehog. Bushes turn see-through while you're inside. HUD eye: open = visible, closed = hidden. |
| **Gentle failure** | `player.gd`, `scripts/checkpoint.gd` | Being caught costs a heart and sends you back to the last leaf-circle checkpoint. At zero hearts you get full hearts back. |
| **Nest building and hibernation** | `scripts/hibernation_spot.gd` | Bring nest material (7 leaf piles, 2 moss, 1 straw) to a safe spot. Safe spots: under the shed (cat too big to follow) and the log pile. The bonfire pile is unsafe and teaches a fact. |
| **Star rating** | `scripts/main.gd` | ⭐ safe spot, ⭐ 6+ nest material, ⭐ full hearts and dexterity 60+. |
| **Winter clock** | `main.gd` | A 6-minute autumn: the light cools, dexterity drains faster, and at full winter it snows and any safe spot will do. |
| **Hibernation cut-scene** | `main.gd`, `scripts/hud.gd` | Snow, the hedgehog curls up and breathes, the camera circles, the screen fades blue, then a results panel. |
| **Hedgehog facts** | `game.gd`, `hud.gd` | 13 real-world fact cards unlock as you play. |

### Project layout

```
project.godot
scenes/
  main.tscn           The garden level (grey-box layout, edit it in the editor)
  player.tscn, cat.tscn, food.tscn, nest_material.tscn,
  hibernation_spot.tscn, hide_spot.tscn, checkpoint.tscn
                      Drag these into main.tscn to place more items. Set "kind" etc. in the Inspector.
scripts/              All gameplay code (GDScript)
tests/smoke_test.*    Automated play-through of the core loop
```

The entity scenes build their visuals when the game runs, so in the editor they show only as position markers.

## Automated test

The smoke test plays through the whole loop headlessly in under a minute: eat, sniff, collect, hide, get caught, roll up, use the shed gap, hibernate.

```bash
cd hedgehog-game/godot
godot --headless --fixed-fps 60 res://tests/smoke_test.tscn
```

It prints `PASS`/`FAIL` per check and exits with code 1 if anything fails.

## Tuning knobs

Most numbers are `@export` variables, so you can tweak them in the Inspector:

- **Player:** `base_speed`, `dexterity_speed_bonus`, `sniff_radius`, `max_health`
- **Cat:** `vision_range`, `vision_angle_degrees`, `notice_time`, `pounce_distance`, `bored_time`
- **Main:** `level_duration` (winter clock), `good_nest_material`, `good_dexterity`
- **Food:** `respawn_time`

## Playtest questions

- Is it clear what to do without reading? (food → nest → sleep)
- Does the cat feel exciting but not scary? Is the `?` → `!` warning long enough?
- Do kids discover rolling up and hiding on their own?
- Is 6 minutes of autumn too short or too long?
- Do kids read or notice the fact cards?

## Next steps (towards M2 / vertical slice)

- Real hedgehog, cat and garden art, plus animations
- Sound: snuffles, the beetle *crunch*, an adaptive music layer when the cat is near
- Distractions (feather, yarn, ball), a dog with a scent-based search
- Colour-blind shapes for scent columns, voice-over for prompts and facts
- Nature journal screen, world map with hedgehog highways, Explorer difficulty mode
