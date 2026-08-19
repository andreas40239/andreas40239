import { speak, vibrate } from "../lib/speech";

export default function BigButton({ label, emoji, color = "orange", onClick, sayOnTap = true, className = "" }) {
  const handleClick = () => {
    vibrate(15);
    if (sayOnTap) speak(label);
    onClick?.();
  };

  return (
    <button className={`big-button big-button--${color} ${className}`} onClick={handleClick} type="button">
      <span className="big-button__emoji" aria-hidden="true">
        {emoji}
      </span>
      <span className="big-button__label">{label}</span>
    </button>
  );
}
