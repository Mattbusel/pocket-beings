// Renders the 1024x1024 app icon: a little window from 2001 with the town in it.
import { chromium } from "file:///C:/Users/Matthew/lastmile/node_modules/playwright/index.mjs";

const out = "C:/Users/Matthew/pocket-beings/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png";
const html = `<html><body style="margin:0">
<div id="c" style="width:1024px;height:1024px;background:linear-gradient(180deg,#A9DCFA,#7CC6F2);position:relative;font-family:'Segoe UI',Arial,sans-serif;overflow:hidden">
  <div style="position:absolute;left:92px;top:150px;width:840px;height:724px;background:#EDE8D9;
      box-shadow:inset 8px 8px 0 #fff, inset -8px -8px 0 #8C877A, 0 30px 60px rgba(0,0,0,.25)">
    <div style="height:96px;background:linear-gradient(90deg,#0A246A,#5C94E6);display:flex;align-items:center;padding:0 28px;justify-content:space-between">
      <span style="color:#fff;font-weight:900;font-size:52px;letter-spacing:1px">Pocket Beings</span>
      <span style="display:flex;gap:10px">${["_", "□", "×"].map(g => `<span style="width:58px;height:52px;background:#EDE8D9;box-shadow:inset 5px 5px 0 #fff,inset -5px -5px 0 #8C877A;display:flex;align-items:center;justify-content:center;font-weight:900;font-size:34px;color:#111">${g}</span>`).join("")}</span>
    </div>
    <div style="position:absolute;left:36px;right:36px;top:132px;bottom:36px;background:repeating-linear-gradient(180deg,#7DCB6B 0 70px,#66B858 70px 140px);box-shadow:inset 8px 8px 0 #8C877A, inset -8px -8px 0 #fff">
      ${[["📈", 120, 90], ["🧶", 420, 60], ["😈", 640, 150], ["📎", 250, 260], ["👺", 520, 320], ["🦞", 100, 400], ["🔮", 660, 400]]
        .map(([f, x, y]) => `<span style="position:absolute;left:${x}px;top:${y}px;font-size:150px;line-height:1">${f}</span>`).join("")}
      <span style="position:absolute;left:412px;top:0px;font-size:70px">👑</span>
    </div>
  </div>
</div></body></html>`;

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1024, height: 1024 } });
await page.setContent(html);
await page.locator("#c").screenshot({ path: out, omitBackground: false });
await browser.close();
console.log("wrote", out);
