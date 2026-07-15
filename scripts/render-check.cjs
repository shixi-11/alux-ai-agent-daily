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
const archiveZh = JSON.parse(fs.readFileSync(path.join(publicRoot, 'archive.json'), 'utf8'));
const archiveEn = JSON.parse(fs.readFileSync(path.join(publicRoot, 'en', 'archive.json'), 'utf8'));
const reportCount = archiveZh.reports.length;
const latestDate = archiveZh.latest.date;

const viewports = [
  { name: 'wide', width: 1920, height: 1080 },
  { name: 'desktop', width: 1440, height: 1000, capture: true },
  { name: 'laptop', width: 1024, height: 768 },
  { name: 'tablet', width: 768, height: 1024, capture: true },
  { name: 'small-tablet', width: 620, height: 900 },
  { name: 'phone-large', width: 430, height: 932 },
  { name: 'phone', width: 390, height: 844, capture: true, checkOrphans: true },
  { name: 'narrow', width: 320, height: 568, capture: true, checkOrphans: true },
];

const locales = [
  {
    key: 'zh',
    home: '/',
    title: 'ALUX AI智能体情报日报',
    latestHref: archiveZh.latest.url,
    currentLang: 'zh-CN',
    archive: archiveZh,
  },
  {
    key: 'en',
    home: '/en/',
    title: 'ALUX AI Agent Intelligence Daily',
    latestHref: archiveEn.latest.url,
    currentLang: 'en',
    archive: archiveEn,
  },
];

const mimeTypes = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.xml': 'application/xml; charset=utf-8',
  '.txt': 'text/plain; charset=utf-8',
  '.png': 'image/png',
};

function resolveRequest(urlPath) {
  const clean = decodeURIComponent(urlPath.split('?')[0]);
  const relative = clean.replace(/^\/+/, '');
  let candidate = path.resolve(publicRoot, relative);
  if (!candidate.toLowerCase().startsWith(publicRoot.toLowerCase())) return null;
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

async function inspectCommon(page, options = {}) {
  return page.evaluate(({ checkOrphans, reportPage }) => {
    const width = document.documentElement.clientWidth;
    const bodyWidth = document.body.scrollWidth;
    const offenders = [...document.querySelectorAll('body *')]
      .map((node) => {
        const rect = node.getBoundingClientRect();
        return { node, rect };
      })
      .filter(({ node, rect }) => {
        const style = getComputedStyle(node);
        if (style.display === 'none' || style.visibility === 'hidden' || rect.width === 0) return false;
        return rect.left < -1 || rect.right > width + 1;
      })
      .slice(0, 8)
      .map(({ node, rect }) => ({
        tag: node.tagName,
        cls: node.className?.toString().slice(0, 80) || '',
        left: Math.round(rect.left),
        right: Math.round(rect.right),
      }));

    const countLines = (node) => {
      if (!node) return 0;
      const range = document.createRange();
      range.selectNodeContents(node);
      const tops = [...range.getClientRects()].filter((rect) => rect.width > 0).map((rect) => Math.round(rect.top));
      return new Set(tops).size;
    };

    const orphanBlocks = [];
    if (checkOrphans) {
      const selectors = reportPage
        ? '.lead,.heat-summary p,.priority-note strong,.item p,.signal p,.side p,.note,.risc-primer p,.risc-primer-card span,.risc-evidence,.sources li'
        : '.intro,.latest p,.archive-head p,.report-copy strong';
      for (const element of document.querySelectorAll(selectors)) {
        const fullText = element.textContent.replace(/\s+/g, ' ').trim();
        if (!/[\u3400-\u9fff]/u.test(fullText) || fullText.length < 8) continue;
        const glyphs = [];
        const walker = document.createTreeWalker(element, NodeFilter.SHOW_TEXT);
        while (walker.nextNode()) {
          const textNode = walker.currentNode;
          for (let index = 0; index < textNode.data.length; index += 1) {
            const char = textNode.data[index];
            if (/\s/u.test(char)) continue;
            const range = document.createRange();
            range.setStart(textNode, index);
            range.setEnd(textNode, index + 1);
            const rect = range.getBoundingClientRect();
            if (rect.width > 0 && rect.height > 0) glyphs.push({ char, top: Math.round(rect.top) });
          }
        }
        if (!glyphs.length) continue;
        const lastTop = Math.max(...glyphs.map((glyph) => glyph.top));
        const lastLine = glyphs.filter((glyph) => Math.abs(glyph.top - lastTop) <= 1).map((glyph) => glyph.char).join('');
        const chineseCount = [...lastLine].filter((char) => /[\u3400-\u9fff]/u.test(char)).length;
        if (chineseCount === 1 && lastLine.replace(/[\s\p{P}]/gu, '').length <= 1) {
          orphanBlocks.push({ cls: element.className?.toString().slice(0, 80) || element.tagName, tail: lastLine });
        }
      }
    }

    const favicon = document.querySelector('link[rel="icon"]');
    return {
      bodyWidth,
      viewportWidth: width,
      offenders,
      orphanBlocks: orphanBlocks.slice(0, 20),
      favicon: favicon?.getAttribute('href') || '',
      htmlLang: document.documentElement.lang,
      monthLines: [...document.querySelectorAll('.month-strip h3')].map(countLines),
      dateLines: countLines(document.querySelector('.fact:last-child b')),
      reportCount: document.querySelectorAll('.report-row').length,
      navHeight: document.querySelector('.nav-latest')?.getBoundingClientRect().height || 0,
      languageHeight: document.querySelector('.language-switch a')?.getBoundingClientRect().height || 0,
    };
  }, options);
}

async function inspectHomepage(browser, locale, viewport) {
  const page = await browser.newPage({ viewport: { width: viewport.width, height: viewport.height }, deviceScaleFactor: 1 });
  await page.goto(`http://127.0.0.1:${port}${locale.home}`, { waitUntil: 'networkidle' });
  const common = await inspectCommon(page, { checkOrphans: viewport.checkOrphans && locale.key === 'zh', reportPage: false });
  const result = {
    ...common,
    title: await page.title(),
    latestHref: await page.locator('.latest .button').getAttribute('href'),
    logoLoaded: await page.locator('.brand-mark img').evaluate((img) => img.complete && img.naturalWidth > 0),
    currentLang: await page.locator('.language-switch a[aria-current="page"]').getAttribute('lang'),
  };
  if (result.title !== locale.title) throw new Error(`${locale.key}/${viewport.name}: title mismatch`);
  if (result.reportCount !== reportCount) throw new Error(`${locale.key}/${viewport.name}: expected ${reportCount} reports, got ${result.reportCount}`);
  if (result.latestHref !== locale.latestHref) throw new Error(`${locale.key}/${viewport.name}: latest href mismatch ${result.latestHref}`);
  if (result.bodyWidth > result.viewportWidth) throw new Error(`${locale.key}/${viewport.name}: horizontal overflow ${result.bodyWidth}/${result.viewportWidth}`);
  if (result.offenders.length) throw new Error(`${locale.key}/${viewport.name}: clipped elements ${JSON.stringify(result.offenders)}`);
  if (result.monthLines.some((lines) => lines !== 1)) throw new Error(`${locale.key}/${viewport.name}: month heading wrapped ${result.monthLines}`);
  if (result.dateLines !== 1) throw new Error(`${locale.key}/${viewport.name}: archive range wrapped to ${result.dateLines} lines`);
  if (!result.logoLoaded || result.favicon !== '/assets/alux-mark.png') throw new Error(`${locale.key}/${viewport.name}: ALUX logo/favicon missing`);
  if (result.currentLang !== locale.currentLang) throw new Error(`${locale.key}/${viewport.name}: language state mismatch ${result.currentLang}`);
  if (result.navHeight < 43) throw new Error(`${locale.key}/${viewport.name}: latest nav target too short ${result.navHeight}`);
  if (result.languageHeight < 43) throw new Error(`${locale.key}/${viewport.name}: language target too short ${result.languageHeight}`);
  if (result.orphanBlocks.length) throw new Error(`${locale.key}/${viewport.name}: Chinese orphan lines ${JSON.stringify(result.orphanBlocks)}`);
  if (viewport.capture) await page.screenshot({ path: path.join(artifactRoot, `homepage-${locale.key}-${viewport.name}.png`), fullPage: true });
  await page.close();
  return result;
}

function sampleReportUrls(locale) {
  const reports = locale.archive.reports;
  const indexes = [0, Math.floor((reports.length - 1) / 2), reports.length - 1];
  return [...new Set(indexes.map((index) => reports[index].url))];
}

async function inspectReport(browser, locale, viewport, url, capture) {
  const page = await browser.newPage({ viewport: { width: viewport.width, height: viewport.height }, deviceScaleFactor: 1 });
  await page.goto(`http://127.0.0.1:${port}${url}`, { waitUntil: 'networkidle' });
  const common = await inspectCommon(page, { checkOrphans: viewport.checkOrphans && locale.key === 'zh', reportPage: true });
  const result = {
    ...common,
    title: await page.title(),
    sitebar: await page.locator('.report-sitebar').count(),
    footer: await page.locator('.report-sitefooter').count(),
    alternate: await page.locator(`.language-switch a:not([aria-current="page"])`).getAttribute('href'),
    canonical: await page.locator('link[rel="canonical"]').getAttribute('href'),
    externalLinks: await page.locator('a[href^="http"]').count(),
  };
  if (result.bodyWidth > result.viewportWidth) throw new Error(`${locale.key}/${viewport.name}${url}: horizontal overflow ${result.bodyWidth}/${result.viewportWidth}`);
  if (result.offenders.length) throw new Error(`${locale.key}/${viewport.name}${url}: clipped elements ${JSON.stringify(result.offenders)}`);
  if (result.sitebar !== 1 || result.footer !== 1) throw new Error(`${locale.key}/${viewport.name}${url}: site navigation missing`);
  if (!result.alternate) throw new Error(`${locale.key}/${viewport.name}${url}: language alternate missing`);
  if (!result.canonical?.startsWith('https://ai-agent-daily.alux.network/')) throw new Error(`${locale.key}/${viewport.name}${url}: canonical mismatch`);
  if (result.externalLinks === 0) throw new Error(`${locale.key}/${viewport.name}${url}: external sources missing`);
  if (result.favicon !== '/assets/alux-mark.png') throw new Error(`${locale.key}/${viewport.name}${url}: favicon missing`);
  if (result.orphanBlocks.length) throw new Error(`${locale.key}/${viewport.name}${url}: Chinese orphan lines ${JSON.stringify(result.orphanBlocks)}`);
  if (capture) {
    const date = url.split('/').filter(Boolean).slice(-3).join('-');
    await page.screenshot({ path: path.join(artifactRoot, `report-${locale.key}-${date}-${viewport.name}.png`), fullPage: true });
  }
  await page.close();
  return result;
}

(async () => {
  fs.mkdirSync(artifactRoot, { recursive: true });
  await new Promise((resolve) => server.listen(port, '127.0.0.1', resolve));
  if (!chromeExecutable) throw new Error('Google Chrome executable was not found');
  const browser = await chromium.launch({ headless: true, executablePath: chromeExecutable });
  const results = { latestDate, reportCount, homepages: {}, reports: {} };
  try {
    for (const locale of locales) {
      results.homepages[locale.key] = {};
      results.reports[locale.key] = {};
      for (const viewport of viewports) {
        results.homepages[locale.key][viewport.name] = await inspectHomepage(browser, locale, viewport);
      }
      const sampleUrls = sampleReportUrls(locale);
      for (const viewport of viewports) {
        results.reports[locale.key][viewport.name] = [];
        for (const [index, url] of sampleUrls.entries()) {
          const capture = viewport.capture && index === 0;
          results.reports[locale.key][viewport.name].push(await inspectReport(browser, locale, viewport, url, capture));
        }
      }
    }
    process.stdout.write(`${JSON.stringify(results, null, 2)}\n`);
  } finally {
    await browser.close();
    await new Promise((resolve) => server.close(resolve));
  }
})().catch((error) => {
  process.stderr.write(`${error.stack || error.message}\n`);
  process.exitCode = 1;
});
