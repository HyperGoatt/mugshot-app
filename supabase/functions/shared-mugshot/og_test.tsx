import {
  mugshotOGAlt,
  mugshotOGDescription,
  mugshotOGHeight,
  mugshotOGImageResponse,
  type MugshotOGInput,
  mugshotOGTitle,
  mugshotOGWidth,
} from "./og.tsx";

const fixture: MugshotOGInput = {
  authorName: "Amanda",
  drinkName: "Ceremonial Matcha Latte",
  contextName: "Ritual Coffee Roasters",
  coverPhotoURL: null,
  appIconURL:
    "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=",
};

Deno.test("share metadata uses the locked Mugshot narrative", () => {
  if (mugshotOGTitle !== "Mugshot: Capture Every Sip") {
    throw new Error("Unexpected share title");
  }
  if (
    mugshotOGDescription(fixture) !==
      "Amanda shared Ceremonial Matcha Latte at Ritual Coffee Roasters."
  ) {
    throw new Error("Unexpected share description");
  }
  if (!mugshotOGAlt(fixture).includes(fixture.drinkName)) {
    throw new Error("Share image alt text must identify the drink");
  }
  const keys = Object.keys(fixture).sort();
  const safeKeys = [
    "appIconURL",
    "authorName",
    "contextName",
    "coverPhotoURL",
    "drinkName",
  ].sort();
  if (JSON.stringify(keys) !== JSON.stringify(safeKeys)) {
    throw new Error("OG input exposed a field outside the public projection");
  }
});

Deno.test("share image response is a no-store 1200 by 630 PNG", async () => {
  const response = mugshotOGImageResponse(fixture);
  if (response.status !== 200) {
    throw new Error(`Unexpected status ${response.status}`);
  }
  if (response.headers.get("content-type") !== "image/png") {
    throw new Error("Share image must be PNG");
  }
  if (response.headers.get("cache-control") !== "private, no-store") {
    throw new Error("Capability-bound share image must not be cached");
  }
  const bytes = new Uint8Array(await response.arrayBuffer());
  const signature = [137, 80, 78, 71, 13, 10, 26, 10];
  if (!signature.every((value, index) => bytes[index] === value)) {
    throw new Error("Response does not contain a PNG signature");
  }
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  if (
    view.getUint32(16) !== mugshotOGWidth ||
    view.getUint32(20) !== mugshotOGHeight
  ) {
    throw new Error("Share image has the wrong dimensions");
  }
});
