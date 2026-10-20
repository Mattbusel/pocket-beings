// App Store screenshots: a 2001-desktop headline window over each raw simulator shot, on the yard's sky.
//   node Store/art/frame.mjs <dir of CI shots> [plan: store | cpp-idle | cpp-widgets | cpp-chaos] [out dir]
// Writes 1320x2868 (6.9") PNGs, NN_iPhone.png. No prices or price words anywhere (Guideline 2.3.7).
import { chromium } from "file:///C:/Users/Matthew/lastmile/node_modules/playwright/index.mjs";
import { readFileSync, readdirSync, rmSync, mkdirSync } from "fs";

const src = process.argv[2];
const planName = process.argv[3] || "store";
const out = process.argv[4] || "C:/Users/Matthew/pocket-beings/fastlane/screenshots/en-US";
const PLANS = {
  store: [
    ["01_Town", "Seven tiny people.<br>No supervision.", "They rob, bribe and run for office <b>while you watch.</b>"],
    ["02_Meddle", "Tap anyone<br>to meddle.", "Give, rob, jail, crown or <b>exile.</b>"],
    ["03_Gift", "A gift<br>every day.", "Walk the 7-day calendar to <b>the big box.</b>"],
    ["04_Season", "A new Season<br>every month.", "Ten tiers, weekly challenges, <b>a face to keep.</b>"],
    ["06_Widgets", "Your town on your<br>Home Screen.", "Widgets, the Lock Screen and <b>Control Center.</b>"],
    ["05_Album", "Collect all<br>24 stamps.", "First Heist, Dynasty, <b>Funny Money.</b>"],
    ["07_Miracles", "Drop a miracle.", "Coups, frog plagues, <b>twisters.</b>"],
    ["08_Invite", "Invite anyone<br>to town.", "Your friends, your boss, <b>your cat.</b>"],
    ["09_Laws", "Pass the laws.", "Martial Law. Term Limits. <b>No Gambling.</b>"],
    ["10_Almanac", "Watch the economy<br>melt down.", "Wealth, prices and crime, <b>day by day.</b>"],
  ],
  // Custom product pages: same app, a different first impression for each audience.
  "cpp-idle": [
    ["03_Gift", "Come back daily.<br>Get rewarded.", "A 7-day gift calendar that <b>builds up.</b>"],
    ["04_Season", "A Season<br>every month.", "Ten tiers and three <b>weekly challenges.</b>"],
    ["01_Town", "It plays itself.", "Close the app, the town <b>keeps going.</b>"],
    ["05_Album", "24 stamps<br>to collect.", "Every one earned by <b>what your town does.</b>"],
    ["06_Widgets", "Check in from<br>the Home Screen.", "The whole yard, <b>always live.</b>"],
  ],
  "cpp-widgets": [
    ["06_Widgets", "A tiny town<br>on your Home Screen.", "Town Square shows <b>everyone in it.</b>"],
    ["01_Town", "Seven tiny people<br>live in there.", "And they are <b>up to something.</b>"],
    ["02_Meddle", "Tap to meddle.", "Crown one. <b>Jail another.</b>"],
    ["10_Almanac", "Charts of<br>the chaos.", "Wealth, prices, crime, <b>day by day.</b>"],
    ["03_Gift", "A gift<br>every day.", "Seven boxes, <b>one big one.</b>"],
  ],
  "cpp-chaos": [
    ["07_Miracles", "Play god.<br>Badly.", "Coups, frog plagues, <b>twisters.</b>"],
    ["09_Laws", "Make the laws.", "Watch them <b>backfire.</b>"],
    ["02_Meddle", "Crown anyone.<br>Jail anyone.", "The town <b>remembers.</b>"],
    ["01_Town", "Bribes. Heists.<br>Elections.", "No supervision <b>whatsoever.</b>"],
    ["10_Almanac", "Print money.<br>Watch prices.", "The economy, <b>melting.</b>"],
  ],
};
const steps = PLANS[planName];
const files = readdirSync(src);
rmSync(out, { recursive: true, force: true });
mkdirSync(out, { recursive: true });
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 1320, height: 2868 } });
let n = 1;
for (const [key, head, sub] of steps) {
  const f = files.find((x) => x.includes(`-${key}.png`));
  if (!f) { console.log("missing", key); continue; }
  const img = readFileSync(`${src}/${f}`).toString("base64");
  const clouds = [[60, 140, 150], [980, 60, 120], [880, 2700, 140], [40, 2600, 110]]
    .map(([x, y, s]) => `<span style="position:absolute;left:${x}px;top:${y}px;font-size:${s}px;opacity:.9">☁️</span>`).join("");
  await p.setContent(`<!doctype html><html><head>
<link href="https://fonts.googleapis.com/css2?family=Nunito:ital,wght@0,700;0,900;1,900&display=block" rel="stylesheet">
<style>
  body{margin:0;width:1320px;height:2868px;overflow:hidden;font-family:Nunito,sans-serif;
       background:linear-gradient(180deg,#8fd3f7 0%,#bfe6fb 45%,#9ed9fa 100%)}
  .win{position:absolute;left:70px;right:70px;top:150px;background:#EDE8D9;
       box-shadow:inset 6px 6px 0 #fff,inset -6px -6px 0 #8C877A,0 24px 60px rgba(10,36,106,.25)}
  .bar{height:84px;background:linear-gradient(90deg,#0A246A,#5C94E6);display:flex;align-items:center;justify-content:space-between;padding:0 24px;margin:6px 6px 0}
  .bar span{color:#fff;font-weight:900;font-size:40px}
  .btns{display:flex;gap:10px}.btns i{width:48px;height:42px;background:#EDE8D9;box-shadow:inset 4px 4px 0 #fff,inset -4px -4px 0 #8C877A;display:flex;align-items:center;justify-content:center;font-style:normal;font-weight:900;font-size:28px;color:#111}
  .txt{padding:34px 50px 44px}
  h1{margin:0;color:#16161f;font-weight:900;font-size:104px;line-height:1.02;letter-spacing:-1px}
  p{margin:22px 0 0;color:rgba(22,22,31,.66);font-weight:700;font-size:48px;line-height:1.22}
  p b{color:#0000A0;font-weight:900}
  .phone{position:absolute;left:190px;width:940px;border-radius:118px;padding:20px;background:#16161f;box-shadow:0 50px 120px rgba(10,36,106,.35)}
  .phone img{display:block;width:100%;border-radius:100px}
</style></head><body>${clouds}
<div class="win"><div class="bar"><span>Pocket Beings</span><span class="btns"><i>_</i><i>□</i><i>×</i></span></div>
<div class="txt"><h1>${head}</h1><p>${sub}</p></div></div>
<div class="phone" id="ph"><img src="data:image/png;base64,${img}"></div>
</body></html>`);
  await p.evaluate(() => document.fonts.ready);
  // Put the phone just under the headline window, whatever its height.
  await p.evaluate(() => {
    const w = document.querySelector(".win").getBoundingClientRect();
    document.getElementById("ph").style.top = (w.bottom + 60) + "px";
  });
  await p.waitForTimeout(250);
  const name = `${String(n).padStart(2, "0")}_iPhone.png`;
  await p.screenshot({ path: `${out}/${name}`, clip: { x: 0, y: 0, width: 1320, height: 2868 } });
  console.log("wrote", name, key);
  n++;
}
await b.close();
