const https = require('https');
const WINDSURF = 'https://windsurf.com';
const DEVIN = 'https://app.devin.ai';
const EMAIL = process.env.DEVIN_EMAIL;
const PASS = process.env.DEVIN_PASS;
const PAT = process.env.GITHUB_PAT;

function req(method, url, headers, body) {
  return new Promise((resolve) => {
    const u = new URL(url);
    const data = body ? JSON.stringify(body) : null;
    const h = Object.assign({ 'Accept': 'application/json', 'User-Agent': 'Mozilla/5.0 dao-gitauth' }, headers || {});
    if (data) { h['Content-Type'] = 'application/json'; h['Content-Length'] = Buffer.byteLength(data); }
    const r = https.request({ hostname: u.hostname, port: 443, path: u.pathname + u.search, method, headers: h, timeout: 60000, rejectUnauthorized: false }, (res) => {
      let d = ''; res.on('data', c => d += c); res.on('end', () => { let j = null; try { j = JSON.parse(d); } catch {} resolve({ status: res.statusCode, json: j, text: d }); });
    });
    r.on('error', e => resolve({ status: 0, text: e.message }));
    r.on('timeout', () => { r.destroy(); resolve({ status: 0, text: 'timeout' }); });
    if (data) r.write(data); r.end();
  });
}

(async () => {
  console.log('PAT.len=', (PAT || '').length, 'email=', EMAIL);
  // 1. login
  const r1 = await req('POST', WINDSURF + '/_devin-auth/password/login', { Origin: WINDSURF, Referer: WINDSURF + '/account/login' }, { email: EMAIL, password: PASS });
  const auth1 = r1.json && (r1.json.token);
  console.log('1) login status=', r1.status, 'auth1.len=', (auth1 || '').length, auth1 ? '' : ('err=' + r1.text.slice(0, 150)));
  if (!auth1) return;
  // 2. post-auth -> orgId
  const r2 = await req('POST', DEVIN + '/api/users/post-auth', { Authorization: 'Bearer ' + auth1 }, {});
  const orgId = r2.json && ((r2.json.org && r2.json.org.org_id) || r2.json.org_id);
  console.log('2) post-auth status=', r2.status, 'orgId=', orgId);
  if (!orgId) { console.log('   err=', r2.text.slice(0, 200)); return; }
  // 3. github user BEFORE
  const b = await req('GET', DEVIN + '/api/integrations/github/user', { Authorization: 'Bearer ' + auth1, 'x-cog-org-id': orgId });
  console.log('3) github/user BEFORE status=', b.status, 'body=', (b.text || '').slice(0, 200));
  // 4. inject PAT
  const inj = await req('POST', DEVIN + '/api/' + orgId + '/integrations/github/pat', { Authorization: 'Bearer ' + auth1, 'x-cog-org-id': orgId }, { pat: PAT });
  console.log('4) inject PAT status=', inj.status, 'body=', (inj.text || '').slice(0, 250));
  // 5. github user AFTER
  const a = await req('GET', DEVIN + '/api/integrations/github/user', { Authorization: 'Bearer ' + auth1, 'x-cog-org-id': orgId });
  console.log('5) github/user AFTER status=', a.status, 'body=', (a.text || '').slice(0, 300));
})();
