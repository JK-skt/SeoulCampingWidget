import { chromium } from "playwright";
const b=await chromium.launch();const p=await (await b.newContext({deviceScaleFactor:2})).newPage();
await p.setViewportSize({width:1000,height:760});
await p.goto("file:///tmp/seats.html",{waitUntil:"networkidle"});await p.waitForTimeout(300);
await p.screenshot({path:"/tmp/seats.png",fullPage:true});await b.close();console.log("saved");
