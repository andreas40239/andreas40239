import Mascot from "./Mascot";

export default function ScreenTimeOverlay({ onUnlock }) {
  return (
    <div className="screen-time-overlay" role="alertdialog" aria-label="Bildschirmzeit vorbei">
      <Mascot mood="sleepy" size={100} />
      <h2>Zeit, deine Augen auszuruhen! 😴</h2>
      <p>Frag einen Erwachsenen, wenn du weiterspielen möchtest.</p>
      <button type="button" className="screen-time-overlay__unlock" onClick={onUnlock}>
        Für Eltern
      </button>
    </div>
  );
}
