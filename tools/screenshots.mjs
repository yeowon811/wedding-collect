// 웹 빌드를 휴대폰 크기(390x844, 2배)로 캡처한다. 디자인 확인용.
// 사용: node tools/screenshots.mjs <출력 폴더> [경로...]
//   경로 예: "?tab=0" "?tab=4"  (기본: 탭 5개)
//   화면을 한 번 누른 뒤 찍기: "?demo=1&tab=4|100,582" (CSS 좌표)
// 먼저 `flutter build web`, 그리고 build/web을 http://localhost:8095 에서 열어 둔다
// (예: python -I -m http.server 8095 --directory build/web).
import { spawn } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';

const out = resolve(process.argv[2] ?? 'build/screenshots');
const paths = process.argv.slice(3).length ? process.argv.slice(3) : [0, 1, 2, 3, 4].map((t) => `?tab=${t}`);
const chrome = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const port = 9333;
mkdirSync(out, { recursive: true });

const proc = spawn(chrome, [
  '--headless=new', `--remote-debugging-port=${port}`, '--hide-scrollbars',
  '--enable-unsafe-swiftshader', '--use-angle=swiftshader',
  `--user-data-dir=${resolve('build/chrome-profile')}`, 'about:blank',
], { stdio: 'ignore' });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let targets;
for (let i = 0; i < 50 && !targets; i++) {
  try { targets = await (await fetch(`http://127.0.0.1:${port}/json`)).json(); } catch { await sleep(200); }
}
const ws = new WebSocket(targets.find((t) => t.type === 'page').webSocketDebuggerUrl);
await new Promise((r) => ws.addEventListener('open', r));
let id = 0;
const pending = new Map();
ws.addEventListener('message', (e) => {
  const m = JSON.parse(e.data);
  if (m.id && pending.has(m.id)) { pending.get(m.id)(m.result); pending.delete(m.id); }
});
const send = (method, params = {}) => new Promise((r) => { pending.set(++id, r); ws.send(JSON.stringify({ id, method, params })); });

await send('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 2, mobile: true });
// UA=android: 안드로이드 폰처럼 (Flutter는 UA로 플랫폼을 정해 버튼 최소 크기 등이 달라진다, 11-21)
if (process.env.UA === 'android') {
  await send('Emulation.setUserAgentOverride', {
    userAgent: 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
  });
  await send('Emulation.setTouchEmulationEnabled', { enabled: true, maxTouchPoints: 5 });
}
for (const spec of paths) {
  const [p, click] = spec.split('|');
  await send('Page.navigate', { url: (process.env.BASE_URL ?? 'http://localhost:8095/') + p });
  // Flutter가 뜰 때까지 기다린다 (flt-glass-pane 또는 flutter-view가 생기고 조금 더)
  for (let i = 0; i < 60; i++) {
    const r = await send('Runtime.evaluate', { expression: '!!document.querySelector("flutter-view, flt-glass-pane")', returnByValue: true });
    if (r?.result?.value) break;
    await sleep(250);
  }
  await sleep(Number(process.env.WAIT_MS ?? 3500));
  if (click) {
    const [x, y] = click.split(',').map(Number);
    for (const type of ['mousePressed', 'mouseReleased']) {
      await send('Input.dispatchMouseEvent', { type, x, y, button: 'left', clickCount: 1 });
    }
    await sleep(Number(process.env.CLICK_WAIT_MS ?? 800));
  }
  const shot = await send('Page.captureScreenshot', { format: 'png' });
  const name = spec.replace(/[^a-z0-9=_-]+/gi, '_').replace(/^_+/, '') || 'home';
  writeFileSync(join(out, `${name}.png`), Buffer.from(shot.data, 'base64'));
  console.log(`${name}.png`);
}
ws.close();
proc.kill();
