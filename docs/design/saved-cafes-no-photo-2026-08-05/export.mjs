import { createRequire } from "node:module";
import { mkdir } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const require = createRequire(import.meta.url);
const { chromium } = require("playwright");
const root = dirname(fileURLToPath(import.meta.url));
const output = join(root, "outputs");
const pageURL = pathToFileURL(join(root, "index.html")).href;

await mkdir(output, { recursive: true });
const browser = await chromium.launch({ headless: true });

const boardContext = await browser.newContext({
  viewport: { width: 2400, height: 1600 },
  deviceScaleFactor: 1,
});
const boardPage = await boardContext.newPage();
await boardPage.goto(pageURL);
await boardPage.waitForFunction(() => Array.from(document.images).every((image) => image.complete));
await boardPage.screenshot({ path: join(output, "NP-00-ten-direction-board.png") });
await boardContext.close();

const heroContext = await browser.newContext({
  viewport: { width: 402, height: 220 },
  deviceScaleFactor: 3,
});
const heroPage = await heroContext.newPage();
for (let index = 1; index <= 10; index += 1) {
  const id = String(index).padStart(2, "0");
  await heroPage.goto(`${pageURL}?single=${id}`);
  await heroPage.waitForFunction(() => Array.from(document.images).every((image) => image.complete));
  await heroPage.screenshot({ path: join(output, `NP-${id}-hero.png`) });
}
await heroContext.close();
await browser.close();
