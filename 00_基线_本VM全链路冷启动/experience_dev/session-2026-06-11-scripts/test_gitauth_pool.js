const https = require('https'); const fs = require('fs'); const os = require('os'); const path = require('path');
const WINDSURF = 'https://windsurf.com', DEVIN = 'https://app.devin.ai';
const PAT = process.env.GITHUB_PAT;
function req(method, url, headers, body) {
  return new Promise((resolve) => {
    const u = new URL(url); const data = body ? JSON.stringify(body) : null;
    const h = Object.assign({ 'Accept': 'application/json', 'User-Agent': 'Mozilla/5.0 dao' }, headers || {});
    if (data) { h['Content-Type'] = 'application/json'; h['Content-Length'] = Buffer.byteLength(data); }
    const r = https.request({ hostname: u.hostname, port: 443, path: u.pathname + u.search, method, headers: h, timeout: 45000, rejectUnauthorized: false }, (res) => {
      let d = ''; res.on('data', c => d += c); res.on('end', () => resolve({ status: res.statusCode, text: d }));
    });
    r.on('error', e => resolve({ status: 0, text: e.message })); r.on('timeout', () => { r.destroy(); resolve({ status: 0, text: 'timeout' }); });
    if (data) r.write(data); r.end();
  });
}
const sleep = ms => new Promise(r => setTimeout(r, ms));
(async () => {
  const lines = fs.readFileSync(path.join(os.homedir(), '.wam', 'accounts.md'), 'utf8').split(/\r?\n/).filter(l => l.includes('@'));
  let bound = 0;
  for (let i = 0; i < lines.length; i++) {
    const parts = lines[i].trim().split(/\s+/); const email = parts[0], pass = parts[1];
    let auth1 = null;
    for (let attempt = 0; attempt < 3 && !auth1; attempt++) {
      const r1 = await req('POST', WINDSURF + '/_devin-auth/password/login', { Origin: WINDSURF, Referer: WINDSURF + '/account/login' }, { email, password: pass });
      if (r1.status === 429) { await sleep(2000 * (attempt + 1)); continue; }
      try { auth1 = JSON.parse(r1.text).token; } catch {}
      if (!auth1) { console.log('[' + i + '] ' + email + ' LOGIN FAIL status=' + r1.status + ' ' + r1.text.slice(0, 80)); break; }
    }
    if (!auth1) { await sleep(500); continue; }
    const r2 = await req('POST', DEVIN + '/api/users/post-auth', { Authorization: 'Bearer ' + auth1 }, {});
    let orgId; try { orgId = (JSON.parse(r2.text).org || {}).org_id || JSON.parse(r2.text).org_id; } catch {}
    if (!orgId) { console.log('[' + i + '] ' + email + ' NO ORG status=' + r2.status); await sleep(500); continue; }
    const inj = await req('POST', DEVIN + '/api/' + orgId + '/integrations/github/pat', { Authorization: 'Bearer ' + auth1, 'x-cog-org-id': orgId }, { pat: PAT });
    let detail = ''; try { detail = JSON.parse(inj.text).detail || ''; } catch {}
    let verify = '';
    if (inj.status === 200 || inj.status === 201) {
      const g = await req('GET', DEVIN + '/api/integrations/github/user', { Authorization: 'Bearer ' + auth1, 'x-cog-org-id': orgId });
      try { const gj = JSON.parse(g.text); verify = ' username=' + gj.github_username + ' oauth=' + gj.is_github_oauth_connected; } catch {}
      bound++;
    }
    console.log('[' + i + '] ' + email + ' org=' + orgId.slice(0, 14) + ' INJECT=' + inj.status + (detail ? (' (' + detail + ')') : '') + verify);
    await sleep(800);
  }
  console.log('=== BOUND OK: ' + bound + ' accounts ===');
})();
