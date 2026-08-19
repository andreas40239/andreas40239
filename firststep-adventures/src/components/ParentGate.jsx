import { useMemo, useState } from "react";

function generateProblem() {
  const a = 10 + Math.floor(Math.random() * 10); // 10..19
  const b = 3 + Math.floor(Math.random() * 9); // 3..11
  return { a, b, answer: a + b };
}

export default function ParentGate({ onSuccess, onCancel }) {
  const problem = useMemo(() => generateProblem(), []);
  const [input, setInput] = useState("");
  const [shake, setShake] = useState(false);

  const submit = () => {
    if (Number(input) === problem.answer) {
      onSuccess();
    } else {
      setShake(true);
      setInput("");
      setTimeout(() => setShake(false), 400);
    }
  };

  return (
    <div className="screen parent-gate">
      <h2>Für Eltern</h2>
      <p className="parent-gate__instructions">Löse die Aufgabe, um fortzufahren:</p>
      <p className={`parent-gate__problem ${shake ? "parent-gate__problem--shake" : ""}`}>
        {problem.a} + {problem.b} = ?
      </p>

      <div className="parent-gate__display">{input || " "}</div>

      <div className="parent-gate__keypad">
        {["1", "2", "3", "4", "5", "6", "7", "8", "9", "⌫", "0", "OK"].map((key) => (
          <button
            key={key}
            type="button"
            className="parent-gate__key"
            onClick={() => {
              if (key === "⌫") setInput((v) => v.slice(0, -1));
              else if (key === "OK") submit();
              else if (input.length < 3) setInput((v) => v + key);
            }}
          >
            {key}
          </button>
        ))}
      </div>

      <button type="button" className="parent-gate__cancel" onClick={onCancel}>
        Zurück zum Spiel
      </button>
    </div>
  );
}
