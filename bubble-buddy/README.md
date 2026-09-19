# Bubble Buddy

A gentle vertical endless swimmer for ages 4–8, built in **Godot 4.4** as the
vertical slice described in the Bubble Buddy game design document.

Steer Finley the clownfish upward through an endless ocean, blow bubbles to
nudge grumpy crabs aside, collect pearls, and free baby sea creatures from
tangles of seaweed. Nobody gets hurt, nothing can be lost, and there is no way
to fail.

**The game runs fully offline, contains no ads, no in-app purchases, no
analytics and no network code of any kind.**

---

## Status

The vertical slice is complete and playable end to end: title screen → run →
Coral Gates and zone changes → sticker book → parent dashboard.

A signed release APK is produced by the build described below
(`build/BubbleBuddy.apk`, package `com.bubblebuddy.game`, minSdk 21,
targetSdk 34, arm64-v8a + armeabi-v7a + x86_64).

---

## Controls

| Action | Touch | Desktop |
| --- | --- | --- |
| Steer | Drag anywhere; Finley follows your finger | Arrow keys |
| Big Bubble | Hold the bubble button (bottom right), or tap anywhere briefly | Space / Enter |
| Pause | Button (top right) | — |
| Grown-ups screen | Hold "Hold for grown-ups" on the title screen for 2 seconds | Same |

Small bubbles blow automatically every 1.2 s. The Big Bubble has a 3 s cooldown,
shown as a ring around Finley and around the button. Tilt steering is available
in the parent dashboard and is off by default.

---

## What the slice implements

**Core loop** — constant slow upward scroll (130 px/s, never speeds up on its
own), free movement in the bottom 60 % of the screen, auto bubble stream,
charge-and-release Big Bubble, Coral Gate checkpoints, endless zone cycling.

**Obstacles** — Grumpy Crab (scuttles, slowed by small bubbles, tumbles aside
with a "Bloop!"), Tangled Seaweed (pops open to reveal pearls or a starfish),
Drifting Jellyfish (sine-wave drift, harmless zap, then visibly embarrassed),
Sleepy Pufferfish (4 s inflate cycle; harmless while deflated), Falling Anchor
(lands in a puff of dust), Anglerfish (only its sweeping lamp beam is a hazard),
Seagull (skims the surface zone).

**Collectibles** — Pearls, Starfish stickers, Golden Shells (fill the Treasure
Chest instantly), and friends trapped in seaweed balls. Freed friends (turtle,
seahorse, octopus, ray — each drawn and animated separately) follow Finley for
10 s, then wave and swim off.

**Power-ups** — Bubble Shield (absorbs one bump), Speed Current (5 s, hoovers up
the whole lane, player still steers), Rainbow Rush (4 s, invincible, obstacles
burst into confetti, adds a percussion layer to the music).

**Failure-free bumps** — a bump gives a 1 s dizzy wobble with spiral eyes and
shakes loose up to 5 pearls, which float in the water and can be picked straight
back up. No lives, no game over, no restart.

**Zones** — Coral Gardens, Kelp Forest, Sunken Ship, Deep Trench, Surface Shine,
each with its own palette, obstacle table and music colour. Palettes crossfade
seamlessly; a Coral Gate marks the entrance to the next zone.

**Meta** — Sticker Book (50 stickers, 10 per zone, shape-coded per zone so the
page is readable without colour), lifetime pearls, friends rescued per species,
Coral Gates passed, zone badges for 5 gates in one run, and a Daily Golden
Friend chosen from the device clock with its own rhyme.

**Parent dashboard** — playtime limit (gentle "time to rest" ending), music and
SFX toggles, swim-speed accessibility setting, extra shape cues for hazards,
tilt steering, local-only statistics, erase-progress, and a plain-language
privacy statement.

---

## Privacy, verified

The design doc's privacy requirements are enforced by construction, not by
policy:

- There is no networking code in the project — no HTTP client, no sockets, no
  SDKs, no analytics, no crash reporting.
- The Android manifest requests **zero permissions**. The release APK was
  checked with `aapt dump badging`, which lists no `uses-permission` entries at
  all (in particular, no `INTERNET`).
  *Note: Godot's **debug** Android export injects `INTERNET` for its remote
  debugger. Always ship the **release** export, as this project's build does.*
- All progress lives in one `ConfigFile` at `user://bubble_buddy.cfg` on the
  device. `user_data_backup/allow` is off, so it is not even copied to cloud
  backup.
- The statistics in the parent dashboard exist only to be shown to that parent.

---

## Building

Requirements: **Godot 4.4.x** (standard build), the matching **export
templates**, and the **Android SDK build-tools** (for `apksigner`/`zipalign`).
No Gradle, JDK toolchain or NDK is needed — the export uses Godot's prebuilt
Android templates (`gradle_build/use_gradle_build=false`).

1. Point Godot at the Android SDK (Editor → Editor Settings → Export → Android →
   Android SDK Path), or set it in `editor_settings-4.4.tres` on a build machine.

2. Create a signing key. For development:

   ```sh
   keytool -genkeypair -v -keystore android/dev.keystore \
     -alias bubblebuddy -keyalg RSA -keysize 2048 -validity 10000 \
     -storepass <password> -keypass <password> \
     -dname "CN=Bubble Buddy Dev, O=Bubble Buddy, C=US"
   ```

   Keystores are git-ignored and no credentials are stored in
   `export_presets.cfg`. Godot reads them from the environment instead:

   ```sh
   export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$PWD/android/dev.keystore"
   export GODOT_ANDROID_KEYSTORE_RELEASE_USER=bubblebuddy
   export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=<password>
   ```

   Ship a real release key for store distribution, not this development key.

3. Export:

   ```sh
   godot --headless --path . --import
   godot --headless --path . --export-release "Android" build/BubbleBuddy.apk
   ```

Launcher icons are generated from `icon.svg` with `godot --path . -- --icons`,
so the icon set never drifts from the source art.

### Built-in checks

Run these from the project directory; each exits non-zero on failure, so they
work as CI gates.

| Command | What it does |
| --- | --- |
| `godot --path . -- --smoke` | Simulates 3 minutes of play, then asserts a Coral Gate was reached and pearl flow is healthy |
| `godot --path . -- --audio-check` | Confirms every synthesised sound and music loop is non-silent |
| `godot --path . -- --shots` | Saves screenshots of every screen to `user://shots` |
| `godot --path . -- --icons` | Regenerates the Android launcher icons |

---

## How it is put together

```
project.godot          Portrait 1080x1920, canvas_items stretch, GL Compatibility
scenes/main.tscn       One scene; every other node is built in code
autoload/save_data.gd  Local-only save file, settings and statistics
autoload/sound.gd      Runtime audio synthesis (see below)
scripts/game.gd        Scroll, spawn patterns, collisions, gates, overlays
scripts/player.gd      Finley: steering, bubbles, dizzy, shield, rainbow
scripts/background.gd  Three parallax layers, caustics, sunbeams, critters
scripts/obstacles/     One file per creature, each owning its own behaviour
scripts/items/         Pearls, starfish, shells, trapped friends, power-ups, gate
scripts/ui/            Menu, sticker book, parent dashboard, shared UI kit
shaders/               Caustic light and the bubble wobble/rim
```

**No binary art or audio assets.** Every character, obstacle and UI element is
drawn procedurally with rounded vector shapes (`scripts/bb_draw.gd`), and all 17
sound effects plus three music loops are synthesised into `AudioStreamWAV` at
startup (`autoload/sound.gd`, music rendered on a worker thread). This keeps the
project self-contained, resolution-independent and tiny in source form. In
production these are the natural seams at which to drop in an artist's sprites
and a composer's `.ogg` files.

**Responsive layout.** The playfield and HUD are measured from the actual
viewport rather than assuming 1080×1920, so the game fills a 4:3 tablet and a
20:9 phone correctly. Both were checked with rendered screenshots.

**Safety by construction.** Every obstacle row is spawned around a guaranteed
corridor at least 340 px wide, so no arrangement can ever wall the player in.

---

## Judgment calls and deviations

These are the places where the implementation departs from the design document,
and why:

1. **Coral Gate trigger.** The GDD asks for a gate every 300 pearls *and* for
   zone badges at 5 gates in a single 2–5 minute run, which cannot both hold at
   a moderate pearl density. Pearls are therefore spawned in dense streams, and
   a gate also arrives after 9000 px (~70 s) of swimming if the pearl count has
   not reached 300 yet. Both numbers are constants at the top of
   `scripts/game.gd` (`GATE_PEARLS`, `GATE_DISTANCE`) and are meant to be tuned
   against real playtests.
2. **Dropped pearls** reduce the visible run score only; Treasure Chest and
   Coral Gate progress never move backwards. A bump costs a moment of attention,
   not progress.
3. **Font.** The GDD asks for Nunito or similar. No font is bundled here, so the
   build uses Godot's built-in face at large sizes and high contrast. Dropping a
   `Nunito.ttf` into the project and setting it as the default theme font is a
   one-line change.
4. **Art and audio are procedural** rather than authored, as described above.
5. **Bubble shader** does not sample the screen. Real refraction needs a
   back-buffer copy, which is an avoidable cost on low-end tablets; the glassy
   look is built from a tinted lens gradient, a moving highlight and a wobbling
   rim instead.
6. **Music per zone** uses two rendered loops (bright and mellow) with a
   per-zone pitch offset, rather than five separate tracks, so that startup
   synthesis stays fast on a phone.

Not part of this slice (listed as post-launch in the GDD): co-op mode, the
level editor, seasonal events, and additional playable characters.
