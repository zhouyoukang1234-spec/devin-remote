import io, re
src = io.open(r"C:\Users\Administrator\plugins\dao-vsix\src\extension.ts", encoding="utf-8").read().split("\n")
def find(prefix):
    for i, l in enumerate(src):
        if l.startswith(prefix):
            return i
    raise SystemExit("not found: " + prefix)
i_mpesc = find("function mpEsc(")
i_get = find("function getDaoCloudMiddlePanelHtml(")
i_show = find("function showDaoCloudMiddlePanel(")
block = "\n".join(src[i_mpesc:i_show])
block = block.replace("function mpEsc(s: string): string", "function mpEsc(s)")
block = block.replace("function getDaoCloudMiddlePanelHtml(st: any): string", "function getDaoCloudMiddlePanelHtml(st)")
mock = r"""
const st = {
  loggedIn:true, email:'lcld26815946@gmail.com', orgName:'barbba-287', orgId:'org_abc123',
  hasWindsurfCreds:true, apiKeyType:'', tokenType:'windsurf', canUseApi:false,
  port:9920, relay:true, relayUrl:'https://x.workers.dev/relay/141', hostname:'DESKTOP-MASTER',
  cfAuth:true, injecting:false
};
const html = getDaoCloudMiddlePanelHtml(st);
const fs = require('fs');
const stub = '<script>window.acquireVsCodeApi=function(){return {postMessage:function(m){console.log("POST",JSON.stringify(m));},getState:function(){return null;},setState:function(){}};};</' + 'script>';
const finalHtml = html.replace('</head>', stub + '</head>');
fs.writeFileSync('C:\\Users\\Administrator\\dao\\gen_middle.html', html, {encoding:'utf-8'});
fs.writeFileSync('C:\\Users\\Administrator\\dao\\gen_chrome.html', finalHtml, {encoding:'utf-8'});
console.log('TOTAL_LINES=' + html.split('\n').length);
"""
io.open(r"C:\Users\Administrator\dao\gen_eval.js", "w", encoding="utf-8").write(block + "\n" + mock)
print("wrote gen_eval.js")
