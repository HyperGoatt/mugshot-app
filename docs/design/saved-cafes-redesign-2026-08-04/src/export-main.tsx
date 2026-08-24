import ReactDOM from "react-dom/client";
import "@fontsource/roboto/latin-500.css";
import "@fontsource/source-serif-4/latin.css";
import { Renderer } from "./design/Renderer";
import "./styles.css";
import "./prototype.css";

const params = new URLSearchParams(window.location.search);
const id = params.get("id") ?? "CF-01";
const chunkValue = params.get("chunk");
const chunkIndex = chunkValue === null ? undefined : Number(chunkValue);

ReactDOM.createRoot(document.getElementById("root")!).render(<Renderer id={id} chunkIndex={chunkIndex} />);
