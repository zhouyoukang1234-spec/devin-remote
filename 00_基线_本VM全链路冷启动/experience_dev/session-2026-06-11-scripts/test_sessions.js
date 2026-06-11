const https = require('https');
const fs = require('fs');
const os = require('os');
const path = require('path');
const cfg = JSON.parse(fs.readFileSync(path.join(os.homedir(), '.dao', 'workspaces', 'cd03dea5683d', 'config.json'), 'utf8'));
const auth1 = cfg.devinAuth1, org = cfg.devinOrgId, bare = org.replace(/^org-/, '');
const DEVIN_UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/131.0.0.0 Safari/537.36';
const u = new URL('https://app.devin.ai/api/org-' + bare + '/v2sessions?limit=5');
const headers = { 'Accept': 'application/json', 'User-Agent': DEVIN_UA, Authorization: 'Bearer ' + auth1, 'x-cog-org-id': org };
console.log('ENV HTTP_PROXY=', process.env.HTTP_PROXY, 'HTTPS_PROXY=', process.env.HTTPS_PROXY, 'ALL_PROXY=', process.env.ALL_PROXY);
const req = https.request({ hostname: u.hostname, port: 443, path: u.pathname + u.search, method: 'GET', headers, timeout: 15000, rejectUnauthorized: false }, (res) => {
  let d = '';
  res.on('data', c => d += c);
  res.on('end', () => { console.log('STATUS=', res.statusCode); console.log('BODY[0:200]=', d.slice(0, 200)); });
});
req.on('error', e => console.log('ERROR=', e.message));
req.on('timeout', () => { req.destroy(); console.log('TIMEOUT'); });
req.end();
