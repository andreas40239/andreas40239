import { useEffect } from "react";
import BigButton from "./BigButton";
import Mascot from "./Mascot";
import { speak } from "../lib/speech";

export default function HomeScreen({ onNavigate, onOpenParentGate }) {
  useEffect(() => {
    speak("Hallo! Was möchtest du heute lernen?");
  }, []);

  return (
    <div className="screen home-screen">
      <Mascot mood="idle" size={110} />
      <h1 className="home-screen__title">FirstStep Adventures</h1>

      <div className="home-screen__buttons">
        <BigButton label="Buchstaben" emoji="🔤" color="teal" onClick={() => onNavigate("letters")} />
        <BigButton label="Zahlen" emoji="🔢" color="orange" onClick={() => onNavigate("numbers")} />
        <BigButton label="Meine Belohnungen" emoji="🏅" color="pink" onClick={() => onNavigate("rewards")} />
      </div>

      <button
        type="button"
        className="parent-gear"
        aria-label="Für Eltern"
        onClick={onOpenParentGate}
      >
        ⚙️
      </button>
    </div>
  );
}
