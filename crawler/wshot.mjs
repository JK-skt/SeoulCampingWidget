import { chromium } from "playwright";
const b=await chromium.launch();
const p=await (await b.newContext({deviceScaleFactor:2})).newPage();
await p.setViewportSize({width:620,height:760});
await p.goto("file:///Users/jhkoo/SeoulCampingWidget/webwidget/dist/index.html",{waitUntil:"networkidle"});
await p.waitForTimeout(400);
await p.screenshot({path:"/tmp/widget.png",fullPage:true});
await b.close(); console.log("saved");
