# FirstStep Adventures 🦊

Eine 100% offline Lern-App für Erstklässler (6–7 Jahre): Buchstaben, Zahlen
und ein Belohnungssystem, komplett auf Deutsch und ohne Werbung, Käufe oder
externe Links.

This is a **Phase 1 prototype** per the app design document: the core hub
navigation, audio-first narration, the parental gate, one full literacy game,
and one full math module are implemented end-to-end so the interaction
loop can be evaluated with a real child before content production begins.

## Running it

```bash
npm install
npm run dev      # http://localhost:5173
npm run build    # production build into dist/
npm run lint
```

No backend, no network calls — everything runs from the bundle and
`localStorage`.

## What's implemented

- **Home hub** — 3 large buttons (Buchstaben / Zahlen / Meine Belohnungen),
  spoken aloud on load, plus a low-visibility gear icon that opens the
  parental gate (never an app-store/browser exit).
- **Buchstaben → Laute erkennen** (Sound Match): the app speaks a phonetic
  sound, the child taps the matching letter from 3 choices. Correct answers
  trigger confetti, a dancing mascot, haptic feedback, and stickers; wrong
  answers get a gentle spoken nudge, never a red X or buzzer.
- **Zahlen → Zählen** (Visual Counting) and **Plus & Minus rechnen**
  (Addition/Subtraction up to 20, visualized with tappable apple emoji).
  Subtraction can be turned off entirely from the parent dashboard if the
  child hasn't covered it in school yet.
- **Meine Belohnungen** — sticker book plus mascot customization (hats,
  glasses) that unlock as stickers are earned.
- **Parental gate** — an addition problem (e.g. "15 + 5") solved on an
  on-screen keypad, gating both Settings and the screen-time overlay.
- **Eltern-Dashboard** — mastered letters/facts, sticker count, per-module
  toggles, a screen-time limiter (5–60 min) that shows a "rest your eyes"
  overlay when time is up, a high-contrast/dark mode toggle for outdoor and
  in-car use, and a reset-progress action.
- All progress (stickers, mastered letters/facts, settings, mascot outfit)
  persists locally via `localStorage` — see `src/lib/storage.js`.

Sight Word Builder, Picture-Word Match, letter tracing, shape/pattern
recognition, and ten-frame logic are stubbed as "Bald verfügbar" cards in
their hubs, matching the Phase 3 roadmap in the design doc.

## A deliberate substitution: audio

The design doc calls for AI-recorded German voiceovers bundled as local
`.mp3`/`.wav` files. There's no voice-recording pipeline available in this
environment, so `src/lib/speech.js` speaks the same German lines through
the browser's on-device `SpeechSynthesis` API instead — every call site
already passes a short spoken-German string, so swapping in an `<audio>`
player over real recordings later shouldn't require touching call sites.

## Architecture

```
src/
  lib/
    speech.js            audio-first narration + haptics
    storage.js            localStorage read/write, sticker helpers
    ProgressContext.jsx    React context wrapping the local store
  components/
    HomeScreen, Mascot, BigButton, Confetti,
    RewardsScreen, ParentGate, ParentDashboard, ScreenTimeOverlay
  modules/
    literacy/  (LettersHub, SoundMatchGame, letterData)
    math/      (NumbersHub, CountingGame, AdditionGame, mathData)
```

`App.jsx` is a small hand-rolled router (a handful of screen names in
`useState`) plus the screen-time countdown — no routing library needed for
an app this size.

## Not yet built (Phase 2–4 of the roadmap)

Real recorded voiceovers, hand-drawn mascot/letter artwork, the remaining
mini-games (tracing, sight words, picture-word match, patterns, ten-frame),
packaging as an installable mobile app (Capacitor/React Native wrapper),
and device testing with an actual first-grader.
