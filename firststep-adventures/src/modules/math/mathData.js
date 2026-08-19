export const COUNT_OBJECTS = ["🐸", "🍎", "🦋", "🌟", "🐢", "🎈"];

export function randomCountingRound() {
  const total = 2 + Math.floor(Math.random() * 9); // 2..10
  const emoji = COUNT_OBJECTS[Math.floor(Math.random() * COUNT_OBJECTS.length)];
  return { total, emoji };
}

function numberChoices(correct, max = 20) {
  const choices = new Set([correct]);
  while (choices.size < 3) {
    const offset = Math.floor(Math.random() * 5) - 2; // -2..2
    const candidate = Math.min(max, Math.max(0, correct + offset));
    choices.add(candidate);
  }
  return [...choices].sort(() => Math.random() - 0.5);
}

export function randomAdditionRound({ allowSubtraction = false } = {}) {
  const isSubtraction = allowSubtraction && Math.random() < 0.5;

  if (isSubtraction) {
    const a = 3 + Math.floor(Math.random() * 15); // 3..17, keeps room for b
    const b = 1 + Math.floor(Math.random() * Math.min(a, 10));
    const result = a - b;
    return {
      operation: "subtraction",
      a,
      b,
      result,
      factKey: `${a}-${b}`,
      choices: numberChoices(result),
      emoji: "🍎",
    };
  }

  const a = 1 + Math.floor(Math.random() * 10);
  const b = 1 + Math.floor(Math.random() * Math.min(10, 20 - a));
  const result = a + b;
  return {
    operation: "addition",
    a,
    b,
    result,
    factKey: `${a}+${b}`,
    choices: numberChoices(result),
    emoji: "🍎",
  };
}
