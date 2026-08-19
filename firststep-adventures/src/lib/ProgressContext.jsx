import { createContext, useCallback, useContext, useEffect, useState } from "react";
import { loadProgress, saveProgress, resetProgress as resetStoredProgress, randomSticker } from "./storage";

const ProgressContext = createContext(null);

export function ProgressProvider({ children }) {
  const [progress, setProgress] = useState(loadProgress);

  useEffect(() => {
    saveProgress(progress);
  }, [progress]);

  const awardSticker = useCallback((label) => {
    setProgress((prev) => ({ ...prev, stickers: [...prev.stickers, randomSticker(label)] }));
  }, []);

  const masterLetter = useCallback((letter) => {
    setProgress((prev) =>
      prev.masteredLetters.includes(letter)
        ? prev
        : { ...prev, masteredLetters: [...prev.masteredLetters, letter] }
    );
  }, []);

  const masterFact = useCallback((fact) => {
    setProgress((prev) =>
      prev.masteredFacts.includes(fact) ? prev : { ...prev, masteredFacts: [...prev.masteredFacts, fact] }
    );
  }, []);

  const updateSettings = useCallback((patch) => {
    setProgress((prev) => ({
      ...prev,
      settings: {
        ...prev.settings,
        ...patch,
        modules: { ...prev.settings.modules, ...patch.modules },
      },
    }));
  }, []);

  const unlockMascotItem = useCallback((slot, value) => {
    setProgress((prev) => ({ ...prev, mascot: { ...prev.mascot, [slot]: value } }));
  }, []);

  const resetProgress = useCallback(() => {
    setProgress(resetStoredProgress());
  }, []);

  const value = {
    progress,
    awardSticker,
    masterLetter,
    masterFact,
    updateSettings,
    unlockMascotItem,
    resetProgress,
  };

  return <ProgressContext.Provider value={value}>{children}</ProgressContext.Provider>;
}

export function useProgress() {
  const ctx = useContext(ProgressContext);
  if (!ctx) throw new Error("useProgress must be used within a ProgressProvider");
  return ctx;
}
