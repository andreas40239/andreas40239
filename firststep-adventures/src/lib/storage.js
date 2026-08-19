// Local-only progress store. Everything lives in localStorage so the app
// works fully offline and nothing ever leaves the device.

const STORAGE_KEY = "firststep-adventures:progress:v1";

export const DEFAULT_PROGRESS = {
  stickers: [], // { id, emoji, label, earnedAt }
  masteredLetters: [], // ["A", "B", ...]
  masteredFacts: [], // ["3+2", "10-4", ...]
  mascot: { hat: null, glasses: null, color: "orange" },
  settings: {
    modules: {
      soundMatch: true,
      addition: true,
      subtraction: true,
      counting: true,
    },
    screenTimeEnabled: true,
    screenTimeMinutes: 20,
    highContrast: false,
  },
};

export function loadProgress() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return structuredClone(DEFAULT_PROGRESS);
    const parsed = JSON.parse(raw);
    // Merge with defaults so new fields introduced later don't crash old saves.
    return {
      ...structuredClone(DEFAULT_PROGRESS),
      ...parsed,
      mascot: { ...DEFAULT_PROGRESS.mascot, ...parsed.mascot },
      settings: {
        ...DEFAULT_PROGRESS.settings,
        ...parsed.settings,
        modules: {
          ...DEFAULT_PROGRESS.settings.modules,
          ...parsed.settings?.modules,
        },
      },
    };
  } catch {
    return structuredClone(DEFAULT_PROGRESS);
  }
}

export function saveProgress(progress) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(progress));
}

export function resetProgress() {
  localStorage.removeItem(STORAGE_KEY);
  return structuredClone(DEFAULT_PROGRESS);
}

export const STICKER_EMOJIS = ["⭐", "🌈", "🦊", "🦉", "🍎", "🌻", "🐸", "🚀", "🎈", "🐢"];

export function randomSticker(label) {
  const emoji = STICKER_EMOJIS[Math.floor(Math.random() * STICKER_EMOJIS.length)];
  return { id: `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`, emoji, label, earnedAt: Date.now() };
}
