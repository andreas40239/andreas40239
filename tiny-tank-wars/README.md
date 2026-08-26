# Tiny Tank Wars

A friendly, fully offline, turn-based artillery game for kids (ages 6–12),
built with **Godot 4.4 (GDScript)** for Android. Implementation of the
*Tiny Tank Wars* Game Design Document v1.0.

**No ads. No in-app purchases. No data collection. Completely offline.**
The only Android permission is `VIBRATE` (optional haptics, toggleable in-game).

## Features (v1)

- Turn-based artillery combat for 4 tanks: 1–4 human players (pass-and-play) + AI
- Procedurally generated static terrain with flat spawn platforms (≥200 px apart)
- Angle/power aiming with big kid-friendly sliders, barrel drag-aiming,
  dotted trajectory preview and the **Arc Toggle** (exact flight path before launch)
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
  style), all sounds procedurally synthesized (≈1 MB total)

## Project layout

- `src/` — all game code (autoloads `G` game state, `A` audio; battle scene,
  terrain, tanks, AI, camera, UI kit, shared trajectory sim)
- `assets/audio/` — generated WAV sound effects + music loop
- `test/smoke.gd` — headless logic test (`godot --headless -s res://test/smoke.gd`)
- `test/shots.gd` — renders screenshots of every screen under Xvfb

## Building the APK

1. Godot 4.4.1 editor + Android export templates
2. Android SDK build-tools (apksigner/zipalign) + a debug keystore
3. `godot --headless --export-debug "Android" build/TinyTankWars.apk`

Export preset is in `export_presets.cfg` (arm64-v8a + armeabi-v7a, min SDK 21).
