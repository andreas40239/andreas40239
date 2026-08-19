// Simplified German phonics set for 1st grade. `sound` is the spoken laut
// (the sound the letter makes), used by the Sound Match game; `example`
// gives a friendly word association read out alongside it.
export const LETTERS = [
  { letter: "A", sound: "a", example: "Ameise" },
  { letter: "B", sound: "b", example: "Ball" },
  { letter: "D", sound: "d", example: "Dach" },
  { letter: "E", sound: "e", example: "Ente" },
  { letter: "F", sound: "f", example: "Fisch" },
  { letter: "I", sound: "i", example: "Igel" },
  { letter: "L", sound: "l", example: "Löwe" },
  { letter: "M", sound: "m", example: "Maus" },
  { letter: "N", sound: "n", example: "Nuss" },
  { letter: "O", sound: "o", example: "Ohr" },
  { letter: "R", sound: "r", example: "Rad" },
  { letter: "S", sound: "s", example: "Sonne" },
  { letter: "T", sound: "t", example: "Tisch" },
  { letter: "U", sound: "u", example: "Uhu" },
];

export function randomLetterRound() {
  const idx = Math.floor(Math.random() * LETTERS.length);
  const correct = LETTERS[idx];
  const distractors = LETTERS.filter((l) => l.letter !== correct.letter)
    .sort(() => Math.random() - 0.5)
    .slice(0, 2);
  const choices = [correct, ...distractors].sort(() => Math.random() - 0.5);
  return { correct, choices };
}
