import { useEffect, useState } from "react";
import Mascot from "../../components/Mascot";
import Confetti from "../../components/Confetti";
import { speak, vibrate } from "../../lib/speech";
import { useProgress } from "../../lib/ProgressContext";
import { randomLetterRound } from "./letterData";

const PRAISE = ["Super gemacht!", "Klasse!", "Toll!", "Du bist ein Buchstaben-Profi!"];
const ENCOURAGEMENT = ["Fast! Versuch es noch mal.", "Fast geschafft, du schaffst das!", "Nicht schlimm, hör nochmal genau hin."];

export default function SoundMatchGame({ onBack }) {
  const { masterLetter, awardSticker } = useProgress();
  const [round, setRound] = useState(randomLetterRound);
  const [celebrating, setCelebrating] = useState(false);
  const [roundsWon, setRoundsWon] = useState(0);

  const playPrompt = (r = round) => {
    speak(`Welcher Buchstabe macht dieses Geräusch? ${r.correct.sound}`);
  };

  useEffect(() => {
    const t = setTimeout(() => playPrompt(round), 400);
    return () => clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [round]);

  const handleChoice = (letter) => {
    if (celebrating) return;
    if (letter === round.correct.letter) {
      vibrate([15, 40, 15]);
      const praise = PRAISE[Math.floor(Math.random() * PRAISE.length)];
      speak(praise);
      setCelebrating(true);
      masterLetter(letter);
      const nextWon = roundsWon + 1;
      setRoundsWon(nextWon);
      if (nextWon % 3 === 0) awardSticker(`Buchstabe ${letter}`);
      setTimeout(() => {
        setCelebrating(false);
        setRound(randomLetterRound());
      }, 1800);
    } else {
      vibrate(10);
      speak(ENCOURAGEMENT[Math.floor(Math.random() * ENCOURAGEMENT.length)]);
    }
  };

  return (
    <div className="screen game-screen">
      <button type="button" className="back-button" onClick={onBack} aria-label="Zurück">
        ⬅️
      </button>

      <h2 className="game-screen__title">Laute erkennen</h2>

      <div className="game-screen__stage">
        <Mascot mood={celebrating ? "dance" : "idle"} size={90} />
        {celebrating && <Confetti />}
      </div>

      <button type="button" className="replay-button" onClick={() => playPrompt()}>
        🔊 Nochmal hören
      </button>

      <div className="choice-row">
        {round.choices.map((choice) => (
          <button
            key={choice.letter}
            type="button"
            className="letter-choice"
            onClick={() => handleChoice(choice.letter)}
            disabled={celebrating}
          >
            {choice.letter}
          </button>
        ))}
      </div>

      <p className="game-screen__hint">Sticker-Fortschritt: {roundsWon % 3}/3</p>
    </div>
  );
}
