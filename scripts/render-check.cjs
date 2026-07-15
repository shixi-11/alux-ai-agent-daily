const http = require('http');
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const siteRoot = path.resolve(__dirname, '..');
const publicRoot = path.join(siteRoot, 'public');
const artifactRoot = path.join(siteRoot, 'artifacts');
const port = 8765;
const chromeCandidates = [
  process.env.CHROME_EXECUTABLE,
  'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
].filter(Boolean);
const chromeExecutable = chromeCandidates.find((candidate) => fs.existsSync(candidate));

const mimeTypes = {
  '.html': 'text/html; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.xml': 'application/xml; charset=utf-8',
  '.txt': 'text/plain; charset=utf-8',
};

function resolveRequest(urlPath) {
  const clean = decodeURIComponent(urlPath.split('?')[0]);
  const relative = clean.replace(/^\/+/, '');
  let candidate = path.resolve(publicRoot, relative);
  if (!candidate.startsWith(publicRoot)) return null;
  if (fs.existsSync(candidate) && fs.statSync(candidate).isDirectory()) {
    candidate = path.join(candidate, 'index.html');
  } else if (!path.extname(candidate)) {
    const htmlCandidate = `${candidate}.html`;
    const indexCandidate = path.join(candidate, 'index.html');
    if (fs.existsSync(htmlCandidate)) candidate = htmlCandidate;
    else if (fs.existsSync(indexCandidate)) candidate = indexCandidate;
  }
  return fs.existsSync(candidate) && fs.statSync(candidate).isFile() ? candidate : null;
}

const server = http.createServer((req, res) => {
  const filePath = resolveRequest(req.url || '/');
  if (!filePath) {
    const notFound = path.join(publicRoot, '404.html');
    res.writeHead(404, { 'content-type': mimeTypes['.html'] });
    res.end(fs.readFileSync(notFound));
    return;
  }
  const mime = mimeTypes[path.extname(filePath)] || 'application/octet-stream';
  res.writeHead(200, { 'content-type': mime });
  res.end(fs.readFileSync(filePath));
});

async function inspectViewport(browser, name, width, height) {
  const page = await browser.newPage({ viewport: { width, height }, deviceScaleFactor: 1 });
  await page.goto(`http://127.0.0.1:${port}/`, { waitUntil: 'networkidle' });
  const result = await page.evaluate(() => ({
    title: document.title,
    reports: document.querySelectorAll('.report-row').length,
    latestHref: document.querySelector('.latest .button')?.getAttribute('href'),
    bodyWidth: document.body.scrollWidth,
    viewportWidth: document.documentElement.clientWidth,
  }));
  if (result.title !== 'ALUX AI 智能体情报日报') throw new Error(`${name}: title mismatch`);
  if (result.reports !== 18) throw new Error(`${name}: expected 18 reports, got ${result.reports}`);
  if (result.latestHref !== '/2026/07/15/') throw new Error(`${name}: latest href mismatch`);
  if (result.bodyWidth > result.viewportWidth) throw new Error(`${name}: horizontal overflow ${result.bodyWidth}/${result.viewportWidth}`);
  await page.screenshot({ path: path.join(artifactRoot, `homepage-${name}.png`), fullPage: true });
  await page.goto(`http://127.0.0.1:${port}/2026/07/15/`, { waitUntil: 'networkidle' });
  if (!(await page.title()).startsWith('2026-07-15')) throw new Error(`${name}: dated report failed`);
  await page.close();
  return result;
}

(async () => {
  fs.mkdirSync(artifactRoot, { recursive: true });
  await new Promise((resolve) => server.listen(port, '127.0.0.1', resolve));
  if (!chromeExecutable) throw new Error('Google Chrome executable was not found');
  const browser = await chromium.launch({ headless: true, executablePath: chromeExecutable });
  try {
    const desktop = await inspectViewport(browser, 'desktop', 1440, 1000);
    const mobile = await inspectViewport(browser, 'mobile', 390, 844);
    process.stdout.write(`${JSON.stringify({ desktop, mobile }, null, 2)}\n`);
  } finally {
    await browser.close();
    await new Promise((resolve) => server.close(resolve));
  }
})().catch((error) => {
  process.stderr.write(`${error.stack || error.message}\n`);
  process.exitCode = 1;
});
