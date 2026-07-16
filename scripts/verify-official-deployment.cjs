const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const siteRoot = path.resolve(__dirname, '..');
const publicRoot = path.join(siteRoot, 'public');
const configuredOfficialSite = new URL(process.env.ALUX_OFFICIAL_SITE || 'https://ai.alux.network/daily/');
const officialOrigin = (process.env.ALUX_OFFICIAL_ORIGIN || configuredOfficialSite.origin).replace(/\/+$/, '');
const publicationPath = (`/${(process.env.ALUX_PUBLICATION_PATH || configuredOfficialSite.pathname).replace(/^\/+|\/+$/g, '')}`).replace(/^\/$/, '');
const officialSite = `${officialOrigin}${publicationPath}/`;
const legacyOrigin = (process.env.ALUX_LEGACY_ORIGIN || 'https://ai-agent-daily.alux.network').replace(/\/+$/, '');
const date = process.argv[2];
const timeoutMs = Number.parseInt(process.env.ALUX_DEPLOY_TIMEOUT_MS || '600000', 10);
const intervalMs = Number.parseInt(process.env.ALUX_DEPLOY_INTERVAL_MS || '15000', 10);

if (!/^\d{4}-\d{2}-\d{2}$/.test(date || '')) {
  process.stderr.write('usage: node scripts/verify-official-deployment.cjs YYYY-MM-DD\n');
  process.exit(64);
}

const [year, month, day] = date.split('-');
const datedPath = `/${year}/${month}/${day}/`;
const publishPath = (suffix = '/') => `${publicationPath}${suffix.startsWith('/') ? suffix : `/${suffix}`}`;
const routes = [
  { urlPath: publishPath('/'), file: 'index.html' },
  { urlPath: publishPath('/en/'), file: 'en/index.html' },
  { urlPath: publishPath('/latest/'), file: 'latest/index.html' },
  { urlPath: publishPath('/en/latest/'), file: 'en/latest/index.html' },
  {
    urlPath: publishPath(datedPath),
    file: `${year}/${month}/${day}/index.html`,
    alternate: publishPath(`/en${datedPath}`),
  },
  {
    urlPath: publishPath(`/en${datedPath}`),
    file: `en/${year}/${month}/${day}/index.html`,
    alternate: publishPath(datedPath),
  },
];

const legacyRoutes = [
  { legacyPath: '/', destinationPath: publishPath('/') },
  { legacyPath: '/en/', destinationPath: publishPath('/en/') },
  { legacyPath: '/latest/', destinationPath: publishPath('/latest/') },
  { legacyPath: '/en/latest/', destinationPath: publishPath('/en/latest/') },
  { legacyPath: datedPath, destinationPath: publishPath(datedPath), query: '?alux_redirect_probe=1' },
  { legacyPath: `/en${datedPath}`, destinationPath: publishPath(`/en${datedPath}`) },
  { legacyPath: '/daily/', destinationPath: publishPath('/') },
];

function normalizeHtml(value) {
  return value.toString('utf8').replace(/^\uFEFF/, '').replace(/\r\n/g, '\n').trimEnd();
}

function sha256(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

async function fetchResponse(url, redirect = 'follow') {
  return fetch(url, {
    cache: 'no-store',
    redirect,
    headers: {
      'cache-control': 'no-cache',
      pragma: 'no-cache',
      'user-agent': 'ALUX-Daily-Deployment-Verifier/2.0',
    },
    signal: AbortSignal.timeout(20000),
  });
}

async function fetchText(url) {
  const response = await fetchResponse(url, 'follow');
  const body = normalizeHtml(Buffer.from(await response.arrayBuffer()));
  return { response, body };
}

async function verifyOfficialContent() {
  const checks = [];
  for (const route of routes) {
    const localPath = path.join(publicRoot, route.file);
    if (!fs.existsSync(localPath)) throw new Error(`missing local deployment file: ${route.file}`);
    const localBody = normalizeHtml(fs.readFileSync(localPath));
    const url = `${officialOrigin}${route.urlPath}`;
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

async function verifyLegacyRedirects() {
  const checks = [];
  for (const route of legacyRoutes) {
    const query = route.query || '';
    const sourceUrl = `${legacyOrigin}${route.legacyPath}${query}`;
    const expectedLocation = `${officialOrigin}${route.destinationPath}${query}`;
    const response = await fetchResponse(sourceUrl, 'manual');
    const rawLocation = response.headers.get('location');
    const actualLocation = rawLocation ? new URL(rawLocation, sourceUrl).href : '';
    if (response.status !== 308) {
      throw new Error(`${sourceUrl} returned HTTP ${response.status}; expected one permanent 308`);
    }
    if (actualLocation !== expectedLocation) {
      throw new Error(`${sourceUrl} redirects to ${actualLocation || '(missing Location)'}; expected ${expectedLocation}`);
    }
    if (actualLocation.includes('/daily/daily/')) {
      throw new Error(`${sourceUrl} created an invalid /daily/daily/ redirect`);
    }

    const destinationResponse = await fetchResponse(actualLocation, 'manual');
    if (destinationResponse.status !== 200) {
      throw new Error(`${sourceUrl} is not a single-hop redirect; destination returned HTTP ${destinationResponse.status}`);
    }
    checks.push({
      source: `${route.legacyPath}${query}`,
      status: response.status,
      location: actualLocation,
      destinationStatus: destinationResponse.status,
    });
  }
  return checks;
}

async function verifyOfficialRootConvenienceRedirect() {
  const response = await fetchResponse(`${officialOrigin}/`, 'manual');
  const rawLocation = response.headers.get('location');
  const actualLocation = rawLocation ? new URL(rawLocation, `${officialOrigin}/`).href : '';
  if (response.status !== 307) {
    throw new Error(`${officialOrigin}/ returned HTTP ${response.status}; expected temporary 307`);
  }
  if (actualLocation !== officialSite) {
    throw new Error(`${officialOrigin}/ redirects to ${actualLocation || '(missing Location)'}; expected ${officialSite}`);
  }
  return { source: '/', status: response.status, location: actualLocation };
}

async function verifyOnce() {
  return {
    officialContent: await verifyOfficialContent(),
    legacyRedirects: await verifyLegacyRedirects(),
    officialRootRedirect: await verifyOfficialRootConvenienceRedirect(),
  };
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
        officialSite,
        legacyOrigin,
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
