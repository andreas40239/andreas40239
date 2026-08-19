import { useEffect, useState } from "react";
import "./App.css";
import HomeScreen from "./components/HomeScreen";
import RewardsScreen from "./components/RewardsScreen";
import ParentGate from "./components/ParentGate";
import ParentDashboard from "./components/ParentDashboard";
import ScreenTimeOverlay from "./components/ScreenTimeOverlay";
import LettersHub from "./modules/literacy/LettersHub";
import NumbersHub from "./modules/math/NumbersHub";
import { useProgress } from "./lib/ProgressContext";
import { stopSpeaking } from "./lib/speech";

function App() {
  const { progress } = useProgress();
  const [screen, setScreen] = useState("home");
  const [gateOpen, setGateOpen] = useState(false);
  const [dashboardOpen, setDashboardOpen] = useState(false);
  const [elapsedSeconds, setElapsedSeconds] = useState(0);

  const { screenTimeEnabled, screenTimeMinutes, highContrast } = progress.settings;
  const timeUp = screenTimeEnabled && elapsedSeconds >= screenTimeMinutes * 60;

  useEffect(() => {
    if (timeUp) return undefined;
    const id = setInterval(() => setElapsedSeconds((s) => s + 1), 1000);
    return () => clearInterval(id);
  }, [timeUp]);

  useEffect(() => stopSpeaking, [screen, gateOpen, dashboardOpen]);

  const goHome = () => setScreen("home");

  const openParentGate = () => {
    stopSpeaking();
    setGateOpen(true);
  };

  const handleGateSuccess = () => {
    setElapsedSeconds(0);
    setGateOpen(false);
    setDashboardOpen(true);
  };

  const handleGateCancel = () => setGateOpen(false);

  const handleDashboardExit = () => {
    setElapsedSeconds(0);
    setDashboardOpen(false);
    goHome();
  };

  let content;
  if (screen === "letters") content = <LettersHub onBack={goHome} />;
  else if (screen === "numbers") content = <NumbersHub onBack={goHome} />;
  else if (screen === "rewards") content = <RewardsScreen onBack={goHome} />;
  else content = <HomeScreen onNavigate={setScreen} onOpenParentGate={openParentGate} />;

  return (
    <div className={`app ${highContrast ? "app--high-contrast" : ""}`}>
      {content}
      {timeUp && !gateOpen && !dashboardOpen && <ScreenTimeOverlay onUnlock={openParentGate} />}
      {gateOpen && (
        <div className="modal-layer">
          <ParentGate onSuccess={handleGateSuccess} onCancel={handleGateCancel} />
        </div>
      )}
      {dashboardOpen && (
        <div className="modal-layer">
          <ParentDashboard onExit={handleDashboardExit} />
        </div>
      )}
    </div>
  );
}

export default App;
