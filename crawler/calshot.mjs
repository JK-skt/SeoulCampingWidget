import { chromium } from "playwright";
const b=await chromium.launch();
const p=await (await b.newContext({deviceScaleFactor:2})).newPage();
await p.setViewportSize({width:900,height:720});
await p.goto("file:///tmp/calendar.html",{waitUntil:"networkidle"});
await p.waitForTimeout(300);
await p.screenshot({path:"/tmp/calendar.png",fullPage:true});
await b.close();console.log("saved");
