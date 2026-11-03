// Фотосессия Sky Pilot: снимает кадры прямо из веб-версии игры (наши модели и наш мир).
// Запуск: node tools/make_photos.js  ->  assets/photos/raw/*.png (потом tools/pack_photos.py)
const { chromium } = require('playwright');
const path = require('path');
const OUT = path.join(__dirname, '..', 'assets', 'photos', 'raw');
require('fs').mkdirSync(OUT, { recursive: true });
const PAGE = 'file://' + path.join(__dirname, '..', 'web', 'SkyPilot.html');
// [имя, самолёт, позиция, курс самолёта (рад, 0 = на север), смещение камеры (мир), множитель дистанции, на земле]
const DUBAI = [7000, 420, -7500];
const SHOTS = [];
for (const id of ["C172", "LEAR75", "G650", "GL7500", "B737", "A320", "B787", "A330", "A350", "B747", "A380", "F16"])
  SHOTS.push(["plane_" + id, id, [7600, 700, -9600], 0, [0.78, 0.07, -0.62], 0.62, "air"]);
SHOTS.push(["mode_free", "A380", [7300, 520, -7300], 0, [0.85, 0.2, -0.45], 1.15, "air"]);
SHOTS.push(["mode_career", "B737", null, 0, [-0.8, 0.12, -0.55], 1.1, "runway:A"]);
SHOTS.push(["mode_race", "F16", [-4840, 205, 12392], -Math.PI / 2, [-0.75, 0.16, 0.65], 1.3, "air"]);
SHOTS.push(["news_tashkent", "A320", [10500, 430, 3820], 0, [-0.92, 0.12, 0.2], 1.6, "air"]);
SHOTS.push(["news_airports", "A350", null, 0, [-0.75, 0.25, -0.6], 1.0, "runway:C"]);
(async () => {
  const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-webgl', '--ignore-gpu-blocklist'] });
  const p = await b.newPage({ viewport: { width: 1280, height: 720 } });
  const errs = []; p.on('pageerror', (e) => errs.push(e.message));
  await p.goto(PAGE);
  await p.waitForTimeout(7000);
  await p.addStyleTag({ content: '#top,#hud,#adi,#toast,#nav,#radar,#race,#warn,#touch,#park,#hangar,#help,#debug,#menu,#flow{display:none!important}' });
  const only = process.argv[2] ? new RegExp(process.argv[2]) : null;
  for (const [name, id, pos, hdg, off, dm, mode] of SHOTS) {
    if (only && !only.test(name)) continue;
    await p.evaluate(([id, pos, hdg, off, dm, mode]) => {
      startFlight(PLANES[id], mode);
      const f = flight;
      if (pos) { f.pos.set(pos[0], pos[1], pos[2]); f.att.setFromAxisAngle(new THREE.Vector3(0, 1, 0), hdg); f.speed = f.cfg.maxKts * 0.55; f.throttle = 0.6; f.gear = false; }
      camMode = 2;
      const c = f.cfg, L = Math.hypot(off[0], off[2]);
      orbit.yaw = Math.atan2(off[0], off[2]); orbit.pitch = Math.atan2(off[1], L);
      orbit.dist = Math.max(c.span, c.length) * dm + 30;
    }, [id, pos, hdg, off, dm, mode]);
    await p.waitForTimeout(2600);
    await p.screenshot({ path: path.join(OUT, name + '.png') });
    console.log('shot', name);
  }
  console.log('errors', JSON.stringify(errs));
  await b.close();
})();
