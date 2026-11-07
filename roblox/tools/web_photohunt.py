# 📸 Фотоохота (веб): 17 достопримечательностей (как src/shared/Landmarks.luau). В фото-режиме объект ближе 1600 stud
# и в пределах 28° от центра кадра — «снят»: +200 очков; 10 снимков — достижение «Фотограф» (+1000). Окно коллекции в меню.
HUNT_HTML = """  <div class="overlay" id="huntO" style="z-index:40" hidden>
    <div class="sheet">
      <h2>📸 Фотоохота</h2>
      <p id="huntSub"></p>
      <div class="achg" id="huntG"></div>
      <div class="row"><button class="tb primary" id="huntClose">Понятно</button></div>
    </div>
  </div>
"""

HUNT_JS = r"""
// ===== фотоохота
const LANDMARKS = [
  ["burj", "Бурдж-Халифа", "Дубай", 5500, 600, -7500],
  ["future", "Музей будущего", "Дубай", 6120, 40, -8060],
  ["aindubai", "Ain Dubai", "Дубай", 6400, 250, -8850],
  ["bigben", "Биг-Бен", "Лондон", -4760, 90, 12275],
  ["eye", "Лондонский глаз", "Лондон", -4560, 120, 12565],
  ["shard", "Шард", "Лондон", -3680, 300, 12854],
  ["tbridge", "Тауэрский мост", "Лондон", -3300, 40, 12619],
  ["tvtash", "Ташкентская телебашня", "Ташкент", 11100, 360, 3520],
  ["sofia", "Айя-София", "Стамбул", -21020, 60, 20800],
  ["blue", "Голубая мечеть", "Стамбул", -21020, 60, 20240],
  ["galata", "Галатская башня", "Стамбул", -19900, 60, 20080],
  ["kingdom", "Kingdom Centre", "Эр-Рияд", 20850, 300, 20350],
  ["masmak", "Крепость Масмак", "Эр-Рияд", 20480, 20, 20960],
  ["tvriyadh", "Телебашня Эр-Рияда", "Эр-Рияд", 21560, 160, 20000],
  ["registan", "Регистан", "Самарканд", -21000, 40, -20500],
  ["gur", "Гур-Эмир", "Самарканд", -20480, 50, -20080],
  ["bibi", "Биби-Ханым", "Самарканд", -21500, 50, -20030]
];
const HUNT = (() => { try { return JSON.parse(localStorage.getItem("skypilot.photos") || "[]"); } catch (e) { return []; } })();
let huntT = 0;
function huntStep(dt) {
  if (!PHOTO || !flight) return; huntT -= dt; if (huntT > 0) return; huntT = 0.4;
  const fwd = new V3(0, 0, -1).applyQuaternion(camera.quaternion); let best = null, bd = Math.cos(28 * Math.PI / 180);
  for (const l of LANDMARKS) { if (HUNT.includes(l[0])) continue; const d = new V3(l[3], l[4], l[5]).sub(camera.position), len = d.length(); if (len > 1600) continue; const dot = fwd.dot(d.divideScalar(len)); if (dot > bd) { best = l; bd = dot; } }
  if (!best) return;
  HUNT.push(best[0]); try { localStorage.setItem("skypilot.photos", JSON.stringify(HUNT)); } catch (e) {}
  toast("📸 В кадре: " + best[1] + " (" + best[2] + ") · +200 · " + HUNT.length + "/" + LANDMARKS.length, "var(--gold)"); addScore(200, "фотоохота");
  if (HUNT.length >= 10) achUnlock("photographer"); huntRender();
}
function huntRender() {
  const b = $("mHunt"); if (b) b.textContent = "📸 Фотоохота " + HUNT.length + "/" + LANDMARKS.length;
  const g = $("huntG"); if (!g) return;
  g.innerHTML = LANDMARKS.map(([id, n, city]) => { const on = HUNT.includes(id); return '<div class="achc' + (on ? " on" : "") + '"><span class="ai">' + (on ? "📸" : "🔒") + '</span><b>' + n + '</b><small>' + city + '</small><em>+200</em></div>'; }).join("");
  $("huntSub").textContent = "Снято " + HUNT.length + " из " + LANDMARKS.length + ". Подлети к достопримечательности, включи фото-режим (H) и поверни камеру так, чтобы она была в центре кадра (ближе ~800 м).";
}
"""

def add_hunt(s, patch):
    s = patch(s, '  <div class="overlay" id="setO" style="z-index:40" hidden>', HUNT_HTML + '  <div class="overlay" id="setO" style="z-index:40" hidden>')
    s = patch(s, '<button class="tb" id="mLog">📒 Журнал</button>', '<button class="tb" id="mLog">📒 Журнал</button><button class="tb" id="mHunt">📸 Фотоохота</button>')
    s = patch(s, "function dayNight(dt) {", HUNT_JS + "function dayNight(dt) {")
    s = patch(s, "\n  updateParticles(dt);\n", "\n  updateParticles(dt); huntStep(dt);\n")
    s = patch(s, '["one_engine", "🔥", "Один мотор", "Посади самолёт с отказавшим двигателем", 600],', '["one_engine", "🔥", "Один мотор", "Посади самолёт с отказавшим двигателем", 600], ["photographer", "📸", "Фотограф", "Сними 10 достопримечательностей в фото-режиме", 1000],')
    s = patch(s, '13 целей', '14 целей')
    s = patch(s, '$("loading").hidden = true;', '$("mHunt").onclick = () => { huntRender(); $("huntO").hidden = false; }; $("huntClose").onclick = () => ($("huntO").hidden = true); huntRender();\n$("loading").hidden = true;')
    s = patch(s, '<span>Пауза · крути камеру мышью или пальцем, колесо — зум</span>', '<span>Пауза · крути камеру мышью или пальцем, колесо — зум · 📸 наведи на достопримечательность</span>')
    return s
