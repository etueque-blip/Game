PFD_CSS = """
/* кабинные ленты скорости и высоты (PFD) */
#spdT, #altT { position: absolute; top: 50%; transform: translateY(-58%); height: min(250px, 46vh); pointer-events: none;
  border-radius: 12px; background: rgba(12, 18, 30, 0.42); border: 1px solid rgba(255, 255, 255, 0.14); box-shadow: 0 10px 30px rgba(0, 0, 0, 0.25);
  backdrop-filter: blur(6px); -webkit-backdrop-filter: blur(6px); }
#spdT { width: calc(min(250px, 46vh) * 0.32); left: calc(50% - min(27vw, 310px)); margin-left: calc(min(250px, 46vh) * -0.16); }
#altT { width: calc(min(250px, 46vh) * 0.42); left: calc(50% + min(27vw, 310px)); margin-left: calc(min(250px, 46vh) * -0.21); }
@media (max-width: 560px) { #spdT, #altT { display: none; } }
@media (max-height: 480px) { #spdT, #altT { transform: translateY(-42%); } }
"""

PFD_JS = r"""
// ===== кабинные ленты (PFD): скорость слева (полосы сваливания/превышения, Vr, тренд), высота справа (земля, вариометр)
var PFD = true; try { PFD = localStorage.getItem("skypilot.pfd") !== "0"; } catch (e) {}
const pfdS = $("spdT"), pfdA = $("altT"), pfdSc = pfdS.getContext("2d"), pfdAc = pfdA.getContext("2d");
let pfdTrend = 0;
function pfdBox(g, x, y, w, h, txt, right) {
  g.fillStyle = "#05080f"; g.strokeStyle = "rgba(255,255,255,0.9)"; g.lineWidth = 1.2;
  g.beginPath(); if (right) { g.moveTo(x, y - h / 2); g.lineTo(x + w, y - h / 2); g.lineTo(x + w, y + h / 2); g.lineTo(x, y + h / 2); g.lineTo(x - 7, y); }
  else { g.moveTo(x, y - h / 2); g.lineTo(x + w, y - h / 2); g.lineTo(x + w + 7, y); g.lineTo(x + w, y + h / 2); g.lineTo(x, y + h / 2); }
  g.closePath(); g.fill(); g.stroke();
  g.fillStyle = "#fff"; g.font = "700 17px ui-monospace, Menlo, Consolas, monospace"; g.textAlign = "center"; g.textBaseline = "middle"; g.fillText(txt, x + w / 2, y + 1);
}
function drawPFD(f) {
  const show = PFD && !f.crashed; pfdS.hidden = pfdA.hidden = !show; if (!show) return;
  const c = f.cfg, H = 250, cy = H / 2;
  // --- скорость
  { const g = pfdSc, W = 80, U = METRIC ? 1.852 : 1, ppk = 2.7; g.setTransform(pfdS.width / W, 0, 0, pfdS.height / H, 0, 0); g.clearRect(0, 0, W, H);
    const y = (kt) => cy - (kt - f.speed) * ppk;
    const band = (a, b, col) => { const y0 = clamp(y(b), 0, H), y1 = clamp(y(a), 0, H); if (y1 > y0) { g.fillStyle = col; g.fillRect(W - 9, y0, 6, y1 - y0); } };
    const st = f.dbg.stall || c.stallKts;
    if (!f.onGround) { band(0, st, "#e5484d"); band(st, st * 1.1, "#f5a524"); }
    band(c.maxKts, c.maxKts * 3, "#e5484d");
    if (f.flaps > 0 && !c.noFlaps) band(c.flapMaxKts, c.maxKts, "rgba(245,165,36,0.75)");
    g.strokeStyle = "rgba(255,255,255,0.75)"; g.fillStyle = "rgba(255,255,255,0.9)"; g.lineWidth = 1.2; g.font = "600 12px ui-monospace, Menlo, Consolas, monospace"; g.textAlign = "right"; g.textBaseline = "middle";
    const step = METRIC ? 10 : 5, sd = f.speed * U;
    for (let v = Math.floor((sd - 60) / step) * step; v <= sd + 60; v += step) { if (v < 0) continue; const yy = cy - (v - sd) * ppk / U; if (yy < 4 || yy > H - 4) continue;
      const major = v % (step * 4) === 0; g.beginPath(); g.moveTo(W - 12, yy); g.lineTo(W - (major ? 22 : 17), yy); g.stroke(); if (major && Math.abs(yy - cy) > 15) g.fillText(String(v), W - 25, yy); }
    if (f.onGround && c.vrKts) { const yy = y(c.vrKts); if (yy > 6 && yy < H - 6) { g.fillStyle = "#3dd6f5"; g.font = "800 12px ui-sans-serif, system-ui"; g.textAlign = "left"; g.fillText("R", 4, yy); g.fillRect(14, yy - 1, W - 28, 2); } }
    pfdTrend += ((f.dbg.accel || 0) * 10 - pfdTrend) * 0.08;
    if (Math.abs(pfdTrend) > 2) { const ty = clamp(cy - pfdTrend * ppk, 6, H - 6); g.strokeStyle = "#e05bd8"; g.lineWidth = 2.5; g.beginPath(); g.moveTo(W - 30, cy); g.lineTo(W - 30, ty); g.stroke();
      const d = ty < cy ? -1 : 1; g.beginPath(); g.moveTo(W - 35, ty - d * 6); g.lineTo(W - 30, ty); g.lineTo(W - 25, ty - d * 6); g.stroke(); }
    pfdBox(g, 4, cy, 50, 26, String(Math.round(sd)), false);
    g.fillStyle = "rgba(255,255,255,0.6)"; g.font = "600 10px ui-sans-serif, system-ui"; g.textAlign = "center"; g.fillText(METRIC ? "КМ/Ч" : "KT", W / 2, H - 9);
    if (!f.onGround && f.speed < st * 1.1) { g.fillStyle = "#e5484d"; g.font = "800 11px ui-sans-serif, system-ui"; g.fillText("STALL", W / 2, 11); }
  }
  // --- высота и вариометр
  { const g = pfdAc, W = 105, TW = 76, MU = METRIC ? 0.3048 : 1, ad = f.pos.y * FT * MU, ppu = METRIC ? 125 / 180 : 125 / 600;
    g.setTransform(pfdA.width / W, 0, 0, pfdA.height / H, 0, 0); g.clearRect(0, 0, W, H);
    const gy = cy - ((f.pos.y - (f.dbg.agl === Infinity ? 1e9 : f.dbg.agl)) * FT * MU - ad) * ppu;
    if (gy < H) { g.fillStyle = "rgba(150,95,45,0.75)"; g.fillRect(0, Math.max(0, gy), TW, H - Math.max(0, gy)); g.strokeStyle = "#f5a524"; g.lineWidth = 2; g.beginPath(); g.moveTo(0, gy); g.lineTo(TW, gy); g.stroke(); }
    g.strokeStyle = "rgba(255,255,255,0.75)"; g.fillStyle = "rgba(255,255,255,0.9)"; g.lineWidth = 1.2; g.font = "600 12px ui-monospace, Menlo, Consolas, monospace"; g.textAlign = "left"; g.textBaseline = "middle";
    const step = METRIC ? 20 : 100, lab = METRIC ? 100 : 500;
    for (let v = Math.floor((ad - 700) / step) * step; v <= ad + 700; v += step) { const yy = cy - (v - ad) * ppu; if (yy < 4 || yy > H - 4) continue;
      const major = v % lab === 0; g.beginPath(); g.moveTo(3, yy); g.lineTo(major ? 13 : 8, yy); g.stroke(); if ((major || !METRIC && v % 200 === 0) && Math.abs(yy - cy) > 15) g.fillText(fmt(v), 16, yy); }
    pfdBox(g, 12, cy, 62, 26, fmt(Math.round(ad / (METRIC ? 1 : 10)) * (METRIC ? 1 : 10)), true);
    // вариометр: шкала ±6000 ft/min (нелинейная), стрелка
    const vs = vsSmooth, sc = (v) => Math.sign(v) * Math.min(1, Math.sqrt(Math.abs(v) / 6000)) * (cy - 20);
    const X = TW + 4, VW = W - X - 2; g.fillStyle = "rgba(5,8,15,0.55)"; g.fillRect(X, 14, VW, H - 28);
    g.strokeStyle = "rgba(255,255,255,0.55)"; g.lineWidth = 1; for (const v of [-6000, -2000, -1000, -500, 0, 500, 1000, 2000, 6000]) { const yy = cy - sc(v); g.beginPath(); g.moveTo(X, yy); g.lineTo(X + (v === 0 ? VW : 5), yy); g.stroke(); }
    const ny = cy - sc(vs), col = vs < -1500 && f.dbg.agl * FT < 2500 ? "#e5484d" : "#3ddc84"; g.strokeStyle = col; g.lineWidth = 3; g.beginPath(); g.moveTo(X + VW, cy); g.lineTo(X + 3, ny); g.stroke();
    if (Math.abs(vs) > 300) { g.fillStyle = col; g.font = "700 10px ui-monospace, Menlo, Consolas, monospace"; g.textAlign = "center"; g.fillText(METRIC ? (vs * 0.00508).toFixed(1) : String(Math.round(vs / 100) * 100), W / 2 + 10, vs > 0 ? 7 : H - 7); }
    g.fillStyle = "rgba(255,255,255,0.6)"; g.font = "600 10px ui-sans-serif, system-ui"; g.textAlign = "center"; g.fillText(METRIC ? "М" : "FT", TW / 2, H - 9);
  }
}
"""

def add_pfd(s, patch):
    s = patch(s, "</style>\n\n<div id=\"app\">", PFD_CSS + "</style>\n\n<div id=\"app\">")
    s = patch(s, '<canvas id="htape" width="880" height="68" hidden></canvas>', '<canvas id="htape" width="880" height="68" hidden></canvas>\n  <canvas id="spdT" width="160" height="500" hidden></canvas>\n  <canvas id="altT" width="210" height="500" hidden></canvas>')
    s = patch(s, "function updateHUD(f) {", PFD_JS + "function updateHUD(f) {")
    s = patch(s, "  $(\"htape\").hidden = f.crashed; drawTape(hdg);\n", "  $(\"htape\").hidden = f.crashed; drawTape(hdg); drawPFD(f);\n")
    s = patch(s, '$("htape").hidden = true; $("wx").hidden = true;', '$("htape").hidden = true; $("spdT").hidden = true; $("altT").hidden = true; $("wx").hidden = true;')
    s = patch(s, """    ["Сложность", ["Обычная", "Сложная (G)"],""", """    ["Ленты PFD", ["Вкл", "Выкл"], () => (PFD ? 0 : 1), (i) => { PFD = i === 0; try { localStorage.setItem("skypilot.pfd", PFD ? "1" : "0"); } catch (e) {} }],
    ["Сложность", ["Обычная", "Сложная (G)"],""")
    return s
