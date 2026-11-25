const { chromium } = require('playwright');
const path = require('path');
(async () => {
  const b = await chromium.launch();
  for (const [m, w, h, out] of [['icon', 512, 512, 'icon_512.png'], ['t1', 1920, 1080, 'thumb_dogfight.png'], ['t2', 1920, 1080, 'thumb_islands.png']]) {
    const p = await b.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: 1 });
    await p.goto('file://' + path.resolve(__dirname, 'promo.html') + '?m=' + m);
    await p.waitForSelector('body[data-ready]', { timeout: 15000 }).catch(() => {});
    await p.waitForTimeout(500);
    console.log(m, await p.evaluate(() => document.fonts.check("20px 'Russo One'")));
    await p.screenshot({ path: path.resolve(__dirname, out) });
    await p.close();
  }
  await b.close();
})();
