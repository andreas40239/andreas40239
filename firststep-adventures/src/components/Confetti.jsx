const PIECES = Array.from({ length: 24 }, (_, i) => i);
const COLORS = ["#FF9F45", "#4EC5C1", "#FFD93D", "#FF6F91", "#8AC926", "#5B8DEF"];

export default function Confetti() {
  return (
    <div className="confetti" aria-hidden="true">
      {PIECES.map((i) => (
        <span
          key={i}
          className="confetti__piece"
          style={{
            left: `${(i * 37) % 100}%`,
            background: COLORS[i % COLORS.length],
            animationDelay: `${(i % 8) * 0.08}s`,
          }}
        />
      ))}
    </div>
  );
}
