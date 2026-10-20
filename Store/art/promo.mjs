// 1024x1024 promotional images for promoted in-app purchases (no text, per Apple's guidance).
//   node Store/art/promo.mjs <out dir>
import { chromium } from "file:///C:/Users/Matthew/lastmile/node_modules/playwright/index.mjs";
import { mkdirSync } from "fs";

const out = process.argv[2];
mkdirSync(out, { recursive: true });
const items = {
  club: { bg: ["#0A246A", "#5C94E6"], big: "🏛️", ring: ["🧰", "✨", "🎟️", "🏖️", "📊", "☁️", "🎀", "👑"] },
  jar: { bg: ["#F7C948", "#E89B1C"], big: "🫙", ring: ["✨", "✨", "✨", "✨", "✨"] },
  yards: { bg: ["#1B2550", "#2E4D3A"], big: "🏮", ring: ["⛄️", "🌴", "🛸", "🍜", "🦀", "❄️"] },
  boost: { bg: ["#7DCC6B", "#2E7D32"], big: "🚀", ring: ["⭐", "⭐", "⭐", "🏁", "⭐"] },
};
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 1024, height: 1024 } });
for (const [name, it] of Object.entries(items)) {
  const n = it.ring.length;
  const ring = it.ring.map((e, i) => {
    const a = (i / n) * Math.PI * 2 - Math.PI / 2;
    return `<span style="position:absolute;left:${512 + Math.cos(a) * 340 - 60}px;top:${512 + Math.sin(a) * 340 - 60}px;font-size:120px;line-height:1">${e}</span>`;
  }).join("");
  await p.setContent(`<html><body style="margin:0"><div id="c" style="width:1024px;height:1024px;position:relative;overflow:hidden;
    background:radial-gradient(circle at 50% 45%,${it.bg[1]},${it.bg[0]} 75%)">
    <div style="position:absolute;left:262px;top:262px;width:500px;height:500px;border-radius:50%;background:rgba(255,255,255,.18);box-shadow:0 0 120px rgba(255,255,255,.35)"></div>
    <span style="position:absolute;left:0;right:0;top:330px;text-align:center;font-size:340px;line-height:1">${it.big}</span>${ring}</div></body></html>`);
  await p.locator("#c").screenshot({ path: `${out}/${name}.png` });
  console.log("wrote", name);
}
await b.close();
