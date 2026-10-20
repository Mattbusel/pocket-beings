// The four yard icons: the same little 2001 window, with each yard's sky, lawn and things on it.
// Writes Resources/Assets.xcassets/AppIcon-<Name>.appiconset.
import { chromium } from "file:///C:/Users/Matthew/lastmile/node_modules/playwright/index.mjs";
import { mkdirSync, writeFileSync } from "fs";

const root = "C:/Users/Matthew/pocket-beings/Resources/Assets.xcassets";
const yards = {
  SnowDay: { sky: ["#DCE8F2", "#B7CDE0"], a: "#F4F8FB", b: "#DDE7F1", things: ["⛄", "❄️", "🌲", "🛷"], faces: ["🧶", "😈", "📎", "👺", "🦞"] },
  NightMarket: { sky: ["#25306A", "#141B3F"], a: "#30513C", b: "#26432F", things: ["🏮", "🍜", "🌙", "🏮"], faces: ["🧶", "😈", "📎", "👺", "🦞"] },
  BeachTown: { sky: ["#A8EEF7", "#6FD6EA"], a: "#F4DFA6", b: "#EAD08E", things: ["🌴", "🐚", "🦀", "⛱️"], faces: ["🧶", "😈", "📎", "👺", "🦞"] },
  MarsColony: { sky: ["#F6BE98", "#E99569"], a: "#CB6A42", b: "#B85A35", things: ["🛸", "🪨", "👽", "🛰️"], faces: ["🧶", "😈", "📎", "👺", "🦞"] },
};

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1024, height: 1024 } });
for (const [name, y] of Object.entries(yards)) {
  const spots = [[120, 90], [420, 60], [640, 150], [250, 260], [520, 320]];
  const thingSpots = [[60, 360], [690, 380], [380, 430], [140, 210]];
  const html = `<html><body style="margin:0">
<div id="c" style="width:1024px;height:1024px;background:linear-gradient(180deg,${y.sky[0]},${y.sky[1]});position:relative;font-family:'Segoe UI',Arial,sans-serif;overflow:hidden">
  <div style="position:absolute;left:92px;top:150px;width:840px;height:724px;background:#EDE8D9;
      box-shadow:inset 8px 8px 0 #fff, inset -8px -8px 0 #8C877A, 0 30px 60px rgba(0,0,0,.25)">
    <div style="height:96px;background:linear-gradient(90deg,#0A246A,#5C94E6);display:flex;align-items:center;padding:0 28px;justify-content:space-between">
      <span style="color:#fff;font-weight:900;font-size:52px;letter-spacing:1px">Pocket Beings</span>
      <span style="display:flex;gap:10px">${["_", "□", "×"].map(g => `<span style="width:58px;height:52px;background:#EDE8D9;box-shadow:inset 5px 5px 0 #fff,inset -5px -5px 0 #8C877A;display:flex;align-items:center;justify-content:center;font-weight:900;font-size:34px;color:#111">${g}</span>`).join("")}</span>
    </div>
    <div style="position:absolute;left:36px;right:36px;top:132px;bottom:36px;background:repeating-linear-gradient(180deg,${y.a} 0 70px,${y.b} 70px 140px);box-shadow:inset 8px 8px 0 #8C877A, inset -8px -8px 0 #fff">
      ${thingSpots.map(([x, yy], i) => `<span style="position:absolute;left:${x}px;top:${yy}px;font-size:96px;line-height:1">${y.things[i]}</span>`).join("")}
      ${spots.map(([x, yy], i) => `<span style="position:absolute;left:${x}px;top:${yy}px;font-size:150px;line-height:1">${y.faces[i]}</span>`).join("")}
      <span style="position:absolute;left:412px;top:0px;font-size:70px">👑</span>
    </div>
  </div>
</div></body></html>`;
  await page.setContent(html);
  const dir = `${root}/AppIcon-${name}.appiconset`;
  mkdirSync(dir, { recursive: true });
  await page.locator("#c").screenshot({ path: `${dir}/icon-1024.png` });
  writeFileSync(`${dir}/Contents.json`, JSON.stringify({ images: [{ filename: "icon-1024.png", idiom: "universal", platform: "ios", size: "1024x1024" }], info: { author: "xcode", version: 1 } }, null, 2));
  console.log("wrote", name);
}
await browser.close();
