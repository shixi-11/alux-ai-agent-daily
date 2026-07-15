const path = require("path");
const { pathToFileURL } = require("url");
const { chromium } = require("playwright");

const root = __dirname;
const htmlPath = path.join(root, "share-card.html");
const outputRoot = path.resolve(root, "..", "..", "..");
const pngPath = path.join(root, ".share-card-render.tmp.png");

(async () => {
  const browser = await chromium.launch({
    headless: true,
    executablePath: "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
  });
  try {
    const context = await browser.newContext({
      viewport: { width: 768, height: 1024 },
      deviceScaleFactor: 4,
    });
    const page = await context.newPage();
    await page.goto(pathToFileURL(htmlPath).href, { waitUntil: "load" });
    const layout = await page.evaluate(() => {
      const allText = [...document.querySelectorAll("body *")]
        .filter((element) => element.children.length === 0 && element.textContent.trim())
        .map((element) => {
          const rect = element.getBoundingClientRect();
          return {
            text: element.textContent.trim(),
            left: rect.left,
            top: rect.top,
            right: rect.right,
            bottom: rect.bottom,
          };
        });
      return {
        width: document.documentElement.scrollWidth,
        height: document.documentElement.scrollHeight,
        clipped: allText.filter(
          (item) =>
            item.left < 24 ||
            item.top < 24 ||
            item.right > 744 ||
            item.bottom > 1000,
        ),
      };
    });
    if (layout.width !== 768 || layout.height !== 1024 || layout.clipped.length) {
      throw new Error(`Layout verification failed: ${JSON.stringify(layout)}`);
    }
    await page.screenshot({ path: pngPath, fullPage: false });
    console.log(`LAYOUT_OK ${JSON.stringify(layout)}`);
    console.log(`PNG_RENDERED ${pngPath}`);
  } finally {
    await browser.close();
  }
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
