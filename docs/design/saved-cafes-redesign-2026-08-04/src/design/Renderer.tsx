import type { CSSProperties, ReactNode } from "react";
import { screenDefinitions, type ScreenId } from "./data";
import { PhoneScreen } from "./SavedScreens";

type RendererProps = {
  id: string;
  chunkIndex?: number;
};

type ArtifactKind = "screen" | "component-board" | "specification-board";

const SCREEN_WIDTH = 402;
const SCREEN_HEIGHT = 874;
const SCREEN_SCALE = 3;

const captureBaseStyle: CSSProperties = {
  position: "relative",
  overflow: "hidden",
  margin: 0,
  background: "#ffffff",
  colorScheme: "light",
};

function CaptureCanvas({
  id,
  kind,
  width,
  height,
  children,
}: {
  id: string;
  kind: ArtifactKind;
  width: number;
  height: number;
  children: ReactNode;
}) {
  return (
    <main
      id="export-canvas"
      className={`mg-export-canvas mg-export-${kind}`}
      data-testid="export-canvas"
      data-export-id={id}
      data-export-kind={kind}
      data-export-width={width}
      data-export-height={height}
      style={{ ...captureBaseStyle, width, height }}
    >
      {children}
    </main>
  );
}

function ScreenArtifact({ requestedId, id, chunkIndex }: { requestedId: string; id: ScreenId; chunkIndex?: number }) {
  if (chunkIndex !== undefined) {
    return (
      <CaptureCanvas
        id={requestedId}
        kind="screen"
        width={SCREEN_WIDTH * SCREEN_SCALE}
        height={SCREEN_HEIGHT}
      >
        <div
          className="mg-export-screen-source"
          data-testid="screen-capture"
          style={{
            position: "absolute",
            top: -SCREEN_HEIGHT * chunkIndex,
            left: 0,
            width: SCREEN_WIDTH,
            height: SCREEN_HEIGHT,
            transform: `scale(${SCREEN_SCALE})`,
            transformOrigin: "top left",
          }}
        >
          <PhoneScreen id={id} />
        </div>
      </CaptureCanvas>
    );
  }

  return (
    <CaptureCanvas
      id={requestedId}
      kind="screen"
      width={SCREEN_WIDTH}
      height={SCREEN_HEIGHT}
    >
      <div
        className="mg-export-screen-source"
        data-testid="screen-capture"
        style={{
          width: SCREEN_WIDTH,
          height: SCREEN_HEIGHT,
        }}
      >
        <PhoneScreen id={id} />
      </div>
    </CaptureCanvas>
  );
}

export function Renderer({ id, chunkIndex }: RendererProps) {
  const resolvedScreenId = id === "CD-01" ? "CF-12" : id;
  const screen = screenDefinitions.find((definition) => definition.id === resolvedScreenId);

  if (screen) {
    return <ScreenArtifact requestedId={id} id={screen.id} chunkIndex={chunkIndex} />;
  }

  throw new Error(`Unknown or not-yet-approved export id: ${id}`);
}

export default Renderer;
