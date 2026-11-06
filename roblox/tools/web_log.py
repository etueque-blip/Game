# 📒 Бортовой журнал (веб): последние 10 полётов (самолёт, где сел, время в воздухе, км, высота, посадки,
# лучшая посадка, очки, итог) и итоги пилота (полёты, налёт, посадки, км, идеальные, крушения).
# Хранится в браузере. В Roblox то же — на сервере (Scores.logFlight, атрибут Log) и окно «📒» в ангаре.
LOG_HTML = """  <div class="overlay" id="logO" style="z-index:40" hidden>
    <div class="sheet">
      <h2>📒 Бортовой журнал</h2>
      <div class="logtot" id="logTot"></div>
      <div class="loglist" id="logList"></div>
      <div class="row"><button class="tb primary" id="logClose">Закрыть</button></div>
    </div>
  </div>
  <style>.logtot { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; margin: 6px 0 12px; }
  .logtot div { background: rgba(255,255,255,0.05); border: 1px solid var(--line); border-radius: 12px; padding: 8px 10px; }
  .logtot b { display: block; font-family: var(--f-mono, ui-monospace, monospace); font-size: 20px; } .logtot small { color: var(--dim); font-size: 11px; text-transform: uppercase; letter-spacing: .06em; }
  .loglist { display: grid; gap: 6px; max-height: min(46vh, 380px); overflow: auto; padding-right: 4px; }
  .logrow { display: grid; grid-template-columns: 34px 1fr auto; gap: 10px; align-items: center; background: rgba(24,32,50,0.75); border: 1px solid var(--line); border-radius: 12px; padding: 8px 10px; }
  .logrow .ic { font-size: 20px; text-align: center; } .logrow .t { font-weight: 700; font-size: 14px; } .logrow .s { color: var(--dim); font-size: 12px; margin-top: 2px; }
  .logrow .p { font-weight: 800; color: var(--gold); font-size: 15px; } .logrow.crash { border-color: rgba(255,77,94,0.45); }
  .logempty { color: var(--dim); font-size: 14px; padding: 18px 4px; }
  @media (max-width: 560px) { .logtot { grid-template-columns: repeat(2, 1fr); } }</style>
"""

LOG_JS = r"""
// ===== бортовой журнал
const LOGB = { list: [], tot: { flights: 0, time: 0, landings: 0, dist: 0, perfect: 0, crashes: 0 } };
try { const j = JSON.parse(localStorage.getItem("skypilot.log") || "null"); if (j && Array.isArray(j.list)) { LOGB.list = j.list.slice(0, 10); Object.assign(LOGB.tot, j.tot || {}); } } catch (e) {}
const GRADE_RANK = { perfect: 3, good: 2, hard: 1 }, GRADE_TXT = { perfect: "★ идеальная", good: "✓ хорошая", hard: "! жёсткая" };
function logLanding(g, fpm, where) { if ((GRADE_RANK[g] || 0) > (GRADE_RANK[FST.bestG] || 0)) FST.bestG = g; if (!FST.bestF || fpm < FST.bestF) FST.bestF = fpm; if (where) FST.where = where; if (g === "perfect") FST.perfect = (FST.perfect || 0) + 1; }
function logFlight(result) {
  if (FST.logged || !FST.plane || (FST.time < 5 && !FST.landings)) return; FST.logged = true;
  const e = { p: FST.plane, r: result, t: Math.round(FST.time), d: Math.round(FST.dist * 0.515 / 100) / 10, a: Math.round(FST.maxAlt), l: FST.landings, g: FST.bestG || "", f: FST.bestF || 0, pts: Math.max(0, SCORE.points - FST.startPts), w: FST.where || "", ts: Date.now() };
  LOGB.list.unshift(e); LOGB.list.length = Math.min(LOGB.list.length, 10);
  const T = LOGB.tot; T.flights++; T.time += e.t; T.landings += e.l; T.dist = Math.round((T.dist + e.d) * 10) / 10; T.perfect += FST.perfect || 0; if (result === "crash") T.crashes++;
  try { localStorage.setItem("skypilot.log", JSON.stringify(LOGB)); } catch (er) {}
}
const fmtHM = (s) => Math.floor(s / 3600) + " ч " + String(Math.floor(s / 60) % 60).padStart(2, "0") + " мин";
const fmtMS = (s) => Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
function renderLog() {
  const T = LOGB.tot, cell = (v, k) => `<div><b>${v}</b><small>${k}</small></div>`;
  $("logTot").innerHTML = cell(T.flights, "полётов") + cell(fmtHM(T.time), "налёт") + cell(T.landings, "посадок") + cell(fmt(T.dist) + " км", "пройдено") + cell(T.perfect, "идеальных") + cell(T.crashes, "крушений");
  $("logList").innerHTML = LOGB.list.length ? LOGB.list.map((e) => {
    const d = new Date(e.ts), when = String(d.getDate()).padStart(2, "0") + "." + String(d.getMonth() + 1).padStart(2, "0") + " " + String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0");
    const bits = [fmtMS(e.t) + " в воздухе", e.d.toFixed(1) + " км", fmt(e.a) + " ft", e.l + " " + (e.l === 1 ? "посадка" : e.l >= 2 && e.l <= 4 ? "посадки" : "посадок")];
    if (e.g) bits.push(GRADE_TXT[e.g] + (e.f ? " " + e.f + " fpm" : ""));
    return `<div class="logrow${e.r === "crash" ? " crash" : ""}"><div class="ic">${e.r === "crash" ? "💥" : e.l ? "🛬" : "✈"}</div><div><div class="t">${e.p}${e.w ? " · " + e.w : ""}</div><div class="s">${when} · ${bits.join(" · ")}</div></div><div class="p">+${fmt(e.pts)}</div></div>`;
  }).join("") : `<div class="logempty">Пока пусто. Слетай — здесь появятся твои полёты: время, расстояние, посадки и очки.</div>`;
}
addEventListener("beforeunload", () => logFlight("ok"));
"""

def add_log(s, patch):
    s = patch(s, '  <div class="overlay" id="setO" style="z-index:40" hidden>', LOG_HTML + '  <div class="overlay" id="setO" style="z-index:40" hidden>')
    s = patch(s, '<button class="tb" id="mDaily">📋 Задания дня</button>', '<button class="tb" id="mDaily">📋 Задания дня</button><button class="tb" id="mLog">📒 Журнал</button>')
    s = patch(s, "function fstatsReset(cfg) { paxReset(cfg); Object.assign(FST, { time: 0,", LOG_JS + "function fstatsReset(cfg) { logFlight(\"ok\"); paxReset(cfg); Object.assign(FST, { bestG: \"\", bestF: 0, where: \"\", perfect: 0, logged: false, time: 0,")
    s = patch(s, '  const grade = text.startsWith("Идеальная") ? ["Идеальная посадка"', '  logLanding(text.startsWith("Идеальная") ? "perfect" : text.startsWith("Хорошая") ? "good" : "hard", fpm, ap ? ap.code : "");\n  const grade = text.startsWith("Идеальная") ? ["Идеальная посадка"')
    s = patch(s, "function doCrash(reason) {", "function doCrash(reason) {\n  logFlight(\"crash\");")
    s = patch(s, '$("loading").hidden = true;', '$("mLog").onclick = () => { renderLog(); $("logO").hidden = false; }; $("logClose").onclick = () => ($("logO").hidden = true);\n$("loading").hidden = true;')
    return s
