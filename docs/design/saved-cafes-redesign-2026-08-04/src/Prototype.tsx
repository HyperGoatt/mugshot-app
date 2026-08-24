import "@fontsource/source-serif-4/latin.css";
import { MobileScroll } from "./mobile";
import { InteractiveSavedPrototype } from "./design/SavedScreens";

export default function Prototype() {
  return (
    <MobileScroll className="app-screen">
      <InteractiveSavedPrototype />
    </MobileScroll>
  );
}
