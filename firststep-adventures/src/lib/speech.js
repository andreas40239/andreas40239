// Audio-first navigation helper.
//
// The design doc calls for AI-recorded German voiceovers bundled as local
// .mp3/.wav assets. This prototype has no recording pipeline available, so
// it speaks the same German lines through the on-device SpeechSynthesis API
// instead. Swap `speak()`'s internals for an <audio> player over bundled
// files once real voiceovers are recorded — every call site already passes
// a short spoken-German string, so no call site changes should be needed.

let cachedVoice = null;

function pickGermanVoice() {
  if (cachedVoice) return cachedVoice;
  const voices = window.speechSynthesis?.getVoices?.() || [];
  cachedVoice =
    voices.find((v) => v.lang?.startsWith("de")) ||
    voices.find((v) => v.lang?.startsWith("de-DE")) ||
    null;
  return cachedVoice;
}

if (typeof window !== "undefined" && window.speechSynthesis) {
  window.speechSynthesis.onvoiceschanged = () => {
    cachedVoice = null;
  };
}

export function speak(text, { rate = 0.95, pitch = 1.1 } = {}) {
  if (typeof window === "undefined" || !window.speechSynthesis) return;
  window.speechSynthesis.cancel();
  const utterance = new SpeechSynthesisUtterance(text);
  utterance.lang = "de-DE";
  utterance.rate = rate;
  utterance.pitch = pitch;
  const voice = pickGermanVoice();
  if (voice) utterance.voice = voice;
  window.speechSynthesis.speak(utterance);
}

export function stopSpeaking() {
  window.speechSynthesis?.cancel?.();
}

export function vibrate(pattern = 15) {
  navigator.vibrate?.(pattern);
}
