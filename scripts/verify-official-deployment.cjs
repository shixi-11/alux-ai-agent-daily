const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const siteRoot = path.resolve(__dirname, '..');
const publicRoot = path.join(siteRoot, 'public');
const baseUrl = (process.env.ALUX_OFFICIAL_SITE || 'https://ai-agent-daily.alux.network').replace(/\/$/, '');
const date = process.argv[2];
const timeoutMs = Number.parseInt(process.env.ALUX_DEPLOY_TIMEOUT_MS || '600000', 10);
const intervalMs = Number.parseInt(process.env.ALUX_DEPLOY_INTERVAL_MS || '15000', 10);

if (!/^\d{4}-\d{2}-\d{2}$/.test(date || '')) {
  process.stderr.write('usage: node scripts/verify-official-deployment.cjs YYYY-MM-DD\n');
  process.exit(64);
}

const [year, month, day] = date.split('-');
const datedPath = `/${year}/${month}/${day}/`;
const routes = [
  { urlPath: '/', file: 'index.html' },
  { urlPath: '/en/', file: 'en/index.html' },
  { urlPath: '/latest/', file: 'latest/index.html' },
  { urlPath: '/en/latest/', file: 'en/latest/index.html' },
  { urlPath: datedPath, file: `${year}/${month}/${day}/index.html`, alternate: `/en${datedPath}` },
  { urlPath: `/en${datedPath}`, file: `en/${year}/${month}/${day}/index.html`, alternate: datedPath },
];

function normalizeHtml(value) {
  return value.toString('utf8').replace(/^\uFEFF/, '').replace(/\r\n/g, '\n').trimEnd();
}

function sha256(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

async function fetchText(url) {
  const response = await fetch(url, {
    cache: 'no-store',
    redirect: 'follow',
    headers: {
      'cache-control': 'no-cache',
      pragma: 'no-cache',
      'user-agent': 'ALUX-Daily-Deployment-Verifier/1.0',
    },
    signal: AbortSignal.timeout(20000),
  });
  const body = normalizeHtml(Buffer.from(await response.arrayBuffer()));
  return { response, body };
}

async function verifyOnce() {
  const checks = [];
  for (const route of routes) {
    const localPath = path.join(publicRoot, route.file);
    if (!fs.existsSync(localPath)) throw new Error(`missing local deployment file: ${route.file}`);
    const localBody = normalizeHtml(fs.readFileSync(localPath));
    const url = `${baseUrl}${route.urlPath}`;
    const { response, body } = await fetchText(url);
    const contentType = response.headers.get('content-type') || '';
    if (response.status !== 200) throw new Error(`${route.urlPath} returned HTTP ${response.status}`);
    if (!contentType.toLowerCase().includes('text/html')) {
      throw new Error(`${route.urlPath} returned unexpected content-type ${contentType || '(empty)'}`);
    }
    if (body !== localBody) {
      throw new Error(`${route.urlPath} has not deployed the current build (${sha256(body)} != ${sha256(localBody)})`);
    }
    if (!body.includes(date)) throw new Error(`${route.urlPath} does not contain current date ${date}`);
    if (route.alternate && !body.includes(`href="${route.alternate}"`)) {
      throw new Error(`${route.urlPath} language switch does not point to ${route.alternate}`);
    }
    checks.push({
      path: route.urlPath,
      status: response.status,
      contentType,
      sha256: sha256(localBody),
    });
  }
  return checks;
}

(async () => {
  const startedAt = Date.now();
  let lastError;
  while (Date.now() - startedAt <= timeoutMs) {
    try {
      const checks = await verifyOnce();
      process.stdout.write(`${JSON.stringify({
        ok: true,
        date,
        baseUrl,
        verifiedAt: new Date().toISOString(),
        checks,
      }, null, 2)}\n`);
      return;
    } catch (error) {
      lastError = error;
      if (Date.now() - startedAt + intervalMs > timeoutMs) break;
      await new Promise((resolve) => setTimeout(resolve, intervalMs));
    }
  }
  throw lastError || new Error('official deployment verification timed out');
})().catch((error) => {
  process.stderr.write(`${error.stack || error.message}\n`);
  process.exitCode = 1;
});
