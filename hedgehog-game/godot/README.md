# Hedgehog Highways: Prototype (M1)

A grey-box Godot 4 prototype of the core loop from the [Game Design Document](../GDD.md):
**forage → avoid the cat → collect nest material → hibernate in a safe spot**.

All visuals are built from simple shapes. The goal is to find out whether the loop is fun before investing in art.

## Running it

**On a PC:**

1. Install **Godot 4.3** or newer (the standard version, not .NET) from <https://godotengine.org/download>.
2. Start Godot, click **Import**, and select `hedgehog-game/godot/project.godot`.
3. Press **F5** (or the ▶ Play button).

**On an Android phone or tablet:** see [Building the Android APK](#building-the-android-apk).

## Controls

| Action | Touch screen | Keyboard / Mouse | Gamepad |
|---|---|---|---|
| Move | **Left thumb**: put it anywhere on the left side and slide (floating joystick) | WASD / arrow keys | Left stick / D-pad |
| Look around | Swipe on empty space on the right side | Drag with the mouse, or Z / X | Right stick |
| Sniff (hold) | **Right thumb**: hold the *Sniff* button | Space | A / ✕ |
| Roll into a ball (hold) | **Right thumb**: hold the *Roll* button | Shift | B / ○ |
| Interact (eat, pick up, build nest, sleep) | **Tap the item** on the screen when it shows *Tap!* | E / Enter | X / □ |
| Restart | Tap the results screen | R (or any key on the results screen) | Start |

The touch controls show up automatically on touch screens and hide when a keyboard or gamepad is used.
To try them on a PC, run the game with the `--touch` user argument (in Godot: *Project → Project Settings → Editor → Run → Main Run Args*: `-- --touch`) and use the mouse as a finger.

Input actions are registered in code (`scripts/game.gd`), so they don't appear in *Project Settings → Input Map*.

## Tutorial

The garden starts with an 8-step tutorial (`scripts/tutorial.gd`). Each step explains one control and waits until the player has tried it:
move → look around → sniff → eat (tap food) → roll up → hide in a bush → pick up nest material → "bring it to a safe spot and hibernate".

The text matches the device: touch instructions on phones and tablets, keys on a PC. On touch screens, the control being taught pulses yellow ("Left thumb here!", "Hold me!", "Swipe here to look around", "Tap!").
The cat sleeps (*zzz*) until the roll step, and the winter clock only starts once the tutorial is done.
To turn the tutorial off, select the **Tutorial** node in `main.tscn` and untick **Enabled**.

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

## Sound and music

Every sound is synthesised by `tools/generate_sounds.py` (numpy + ffmpeg), so there are no third-party audio files or licences to worry about. Change a sound by editing its function and re-running the script. `scripts/sound.gd` (autoload `Sound`) plays them.

| What you hear | When |
|---|---|
| Hedgehog footsteps (louder when dexterity is low), snuffling while sniffing, a contented snuffle when idle | Moving, sniffing, standing still |
| A huff when curling up, a squeak and a *poof* when caught, soft snoring in the nest | Rolling, being caught, hibernating |
| Crunch (beetles, apples), munch (worms, slugs), slurp and *bleh* (milk) | Eating |
| Beetles scuttling in the leaves (only audible up close) | Near a beetle |
| Rustling leaves | Picking up nest material, adding it to the nest, entering or leaving a bush |
| Cat's collar bell (a handy warning!), a meow when it notices you, a hiss as it pounces, a bored *meh*, purring while it sleeps | Cat |
| The neighbours' dog barking behind the fence | Every 20–40 s, from a random direction |
| Crickets that fall silent as it gets colder | Ambience |
| A gentle breeze that **picks up strongly in the last quarter of the winter clock**, with more and more gusts | Ambience |
| Relaxing background music (soft pads, bass and a kalimba-like melody, 53 s loop) | Always |
| Chimes for checkpoints, fact cards, tutorial steps and each star on the results screen | UI |

Audio uses three buses (*Music*, *Ambience*, *SFX*) so volumes can be balanced or given sliders later.

### Project layout

```
project.godot
scenes/
  main.tscn           The garden level (grey-box layout, edit it in the editor)
  player.tscn, cat.tscn, food.tscn, nest_material.tscn,
  hibernation_spot.tscn, hide_spot.tscn, checkpoint.tscn
                      Drag these into main.tscn to place more items. Set "kind" etc. in the Inspector.
scripts/              All gameplay code (GDScript)
  touch_controls.gd   Joystick, Sniff/Roll buttons, tap-to-use, swipe-to-look
  tutorial.gd         The first-garden tutorial
  sound.gd            Sound effects, ambience and music
sounds/               Generated .ogg files
tools/generate_sounds.py
                      Synthesises everything in sounds/
export_presets.cfg    Android export settings
tests/smoke_test.*    Automated play-through of the core loop
```

The entity scenes build their visuals when the game runs, so in the editor they show only as position markers.

## Building the Android APK

`export_presets.cfg` has an **Android** preset (package `com.andreas40239.hedgehoghighways`, landscape, arm64 + armv7, Android 5.0+).
Mobile builds use the *Compatibility* renderer so they run on cheaper tablets too.

1. In Godot, install the export templates: *Editor → Manage Export Templates → Download and Install*.
2. In *Editor → Editor Settings → Export → Android*, set the **Android SDK path** and a **debug keystore**. Godot can create the keystore, or you can use the one Android Studio makes.
3. *Project → Export → Android → Export Project* (tick *Export With Debug*), or from the command line:

   ```bash
   godot --headless --export-debug "Android" build/hedgehog-highways.apk
   ```

**Installing a test APK on a device:** copy the `.apk` to the phone or tablet and open it. Android asks you to allow installing apps from that source (for example *Files* or your browser); allow it once.
Or, with USB debugging on: `adb install -r hedgehog-highways.apk`.

## Automated test

The smoke test plays through the whole loop headlessly in under a minute: eat, sniff, collect, hide, get caught, roll up, use the shed gap, hibernate.
A second pass plays the whole tutorial with simulated touches: joystick, swipe, the Sniff and Roll buttons, and tapping food, leaves and the nest on screen.

`tests/results_test.tscn` plays the real level, hibernates and taps the results screen to check that the level restarts.

```bash
godot --headless --fixed-fps 60 res://tests/results_test.tscn
```

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
- On a phone or tablet: are the buttons big enough and in comfortable thumb reach? Is tapping items easy, or do kids miss?

## Next steps (towards M2 / vertical slice)

- Real hedgehog, cat and garden art, plus animations
- Sound: snuffles, the beetle *crunch*, an adaptive music layer when the cat is near
- Distractions (feather, yarn, ball), a dog with a scent-based search
- Colour-blind shapes for scent columns, voice-over for prompts and facts
- Nature journal screen, world map with hedgehog highways, Explorer difficulty mode
