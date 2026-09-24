# Tiny Tank Wars

A friendly, fully offline, turn-based artillery game for kids (ages 6–12),
built with **Godot 4.4 (GDScript)** for Android. Implementation of the
*Tiny Tank Wars* Game Design Document v1.0.

**No ads. No in-app purchases. No data collection. Completely offline.**
The only Android permission is `VIBRATE` (optional haptics, toggleable in-game).

## Features (v1.2)

- Turn-based artillery combat for 4 tanks: 1–4 human players (pass-and-play) + AI
- Animated startup screen (tanks roll in, title drops, firework shells) plus a
  matching boot splash image
- Four battlefields picked from picture cards: procedural Rolling Hills and
  three hand-shaped harder maps (Snowy Peak, Desert Canyon, Rocky Towers),
  each with its own sky, colours and decorations
- FIRE shoots on touch; an optional "full flight path" setting (main menu or
  pause screen) draws the whole exact trajectory with a landing marker
- Picture-based player select: each card shows all four tanks, colourful
  players first and grey robots after, so pre-readers can choose unaided
- Three background songs with an in-game switcher (main menu + pause screen);
  Bouncy Blocks and Cloud Picnic are ~80 s sectioned pieces
- "Ace", a showman robot on levels 1–10: its first seven shots land close but
  are guaranteed harmless, then the impacts walk inward and start to hurt
- Every robot duels its own human, so in a two-player game neither player is
  ignored; robots re-target only when their player is knocked out
- Procedurally generated static terrain with flat spawn platforms (≥200 px apart)
- Angle/power aiming with big kid-friendly sliders, barrel drag-aiming,
  and a dotted trajectory preview
- Wind system: none (levels 1–10), fixed per level (11–20), changes every
  8 turns (21+), with an animated cloud face, gust streaks and a Wind-Off toggle
- AI tiers: Rookie → Semi-Rookie → Cadet → Veteran, with personalities
  (High-Archer, Straight-Shooter, Power-Player)
- Camera: pinch-zoom & pan anytime, auto zoom-out on fire, projectile
  tracking, 1 s explosion linger
- Damage model per GDD: 25 base damage, 40 px blast radius, linear falloff
- Progression: damage-ranked upgrade points (3/2/1/0), Upgrade Hangar every
  5 levels: Bigger Boom, Heavy Shells, Multi-Shot (volley), Iron Cover (Lv 20+)
- Encrypted local save (`user://`), all art drawn in code (vector cartoon
  style), all sounds and music procedurally synthesized (≈2.5 MB total)

### Simulation note

`Sim.DT` is the single integration step shared by the trajectory prediction
and the live shell, so the full flight path really is exact and shots land
where they were predicted even at the GDD's 15 FPS floor.

## Project layout

- `src/` — all game code (autoloads `G` game state, `A` audio; battle scene,
  terrain, tanks, AI, camera, UI kit, shared trajectory sim)
- `assets/audio/` — generated WAV sound effects + music loop
- `test/smoke.gd` — headless logic test (`godot --headless -s res://test/smoke.gd`)
- `test/drama_stress.gd` — replays Ace's schedule over 40 random levels to
  prove the opening shots can never damage anyone
- `test/maps_reach.gd` — checks every tank can hit every other tank on each map
- `test/shots.gd` — renders screenshots of every screen under Xvfb

Tests run in Godot's script mode (`-s`), which still creates the `G` and `A`
autoloads; tests use those instances (`root.get_node("G")`) rather than
making their own, or settings they change would never reach the game.

## Building the APK

1. Godot 4.4.1 editor + Android export templates
2. Android SDK build-tools (apksigner/zipalign) + a debug keystore
3. `godot --headless --export-debug "Android" build/TinyTankWars.apk`

Export preset is in `export_presets.cfg` (arm64-v8a + armeabi-v7a, min SDK 21).
