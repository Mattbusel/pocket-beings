// In-App Event art: <key>-card.png 1920x1080 (no text: the App Store draws the event name over it)
// and <key>-details.png 1080x1920. node Store/art/event.mjs <raw CI shots dir> <out dir>
import { chromium } from "file:///C:/Users/Matthew/lastmile/node_modules/playwright/index.mjs";
import { readFileSync, readdirSync, mkdirSync } from "fs";

const [raw, out] = process.argv.slice(2);
mkdirSync(out, { recursive: true });
const files = readdirSync(raw);
const shot = (k) => readFileSync(`${raw}/${files.find((f) => f.includes(`-${k}.png`))}`).toString("base64");
const EV = {
  election: { bg: ["#0A246A", "#B22234"], emoji: ["🗳️", "🦃", "👑", "📜"], shots: ["04_Season", "01_Town", "09_Laws"] },
  heist: { bg: ["#0F5132", "#B22234"], emoji: ["🎁", "🎅", "💼", "❄️"], shots: ["04_Season", "07_Miracles", "03_Gift"] },
};
const b = await chromium.launch();
for (const [key, e] of Object.entries(EV)) {
  const card = await b.newPage({ viewport: { width: 1920, height: 1080 } });
  const phones = e.shots.map((k, i) => `<div class="ph p${i}"><img src="data:image/png;base64,${shot(k)}"></div>`).join("");
  const em = e.emoji.map((x, i) => `<span style="position:absolute;font-size:150px;left:${[90, 1640, 120, 1660][i]}px;top:${[90, 110, 800, 780][i]}px">${x}</span>`).join("");
  await card.setContent(`<html><body style="margin:0;width:1920px;height:1080px;overflow:hidden;background:linear-gradient(135deg,${e.bg[0]},${e.bg[1]})">
<style>.ph{position:absolute;top:110px;width:400px;border-radius:60px;padding:13px;background:#16161f;box-shadow:0 40px 110px rgba(0,0,0,.55)}
.ph img{display:block;width:100%;border-radius:48px}.p0{left:350px;transform:rotate(-7deg) translateY(70px)}.p1{left:760px;top:60px;z-index:2}.p2{left:1170px;transform:rotate(7deg) translateY(70px)}</style>
${em}${phones}</body></html>`);
  await card.screenshot({ path: `${out}/${key}-card.png` });
  const det = await b.newPage({ viewport: { width: 1080, height: 1920 } });
  await det.setContent(`<html><body style="margin:0;width:1080px;height:1920px;overflow:hidden;background:linear-gradient(180deg,${e.bg[0]},${e.bg[1]})">
<span style="position:absolute;left:60px;top:40px;font-size:120px">${e.emoji[0]}</span><span style="position:absolute;right:60px;top:40px;font-size:120px">${e.emoji[1]}</span>
<div style="position:absolute;left:170px;top:230px;width:740px;border-radius:90px;padding:18px;background:#16161f;box-shadow:0 40px 110px rgba(0,0,0,.55)">
<img style="display:block;width:100%;border-radius:74px" src="data:image/png;base64,${shot(e.shots[0])}"></div></body></html>`);
  await det.screenshot({ path: `${out}/${key}-details.png` });
  console.log("wrote", key);
}
await b.close();
