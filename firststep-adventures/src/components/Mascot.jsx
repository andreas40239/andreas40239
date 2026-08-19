import { useProgress } from "../lib/ProgressContext";

const HATS = { none: "", party: "🎉", crown: "👑", cap: "🧢" };
const GLASSES = { none: "", cool: "🕶️", nerd: "🤓" };

export default function Mascot({ mood = "idle", size = 96 }) {
  const { progress } = useProgress();
  const hat = HATS[progress.mascot.hat] ?? "";
  const glasses = GLASSES[progress.mascot.glasses] ?? "";

  return (
    <div className={`mascot mascot--${mood}`} style={{ fontSize: size }} aria-hidden="true">
      {hat && <span className="mascot__hat">{hat}</span>}
      <span className="mascot__body">🦊</span>
      {glasses && <span className="mascot__glasses">{glasses}</span>}
    </div>
  );
}
