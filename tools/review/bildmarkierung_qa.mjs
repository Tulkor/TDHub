import {createRequire} from 'node:module';
import {pathToFileURL} from 'node:url';
const require=createRequire('C:/Users/l_neu/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/package.json');
const {chromium}=require('playwright');
const directory='C:/Users/l_neu/.codex/visualizations/2026/11/09/01a1c111-84dd-7402-997d-de7cbdf14649';
const browser=await chromium.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
try{
 const page=await browser.newPage({viewport:{width:1056,height:1100}}),errors=[];
 page.on('pageerror',e=>errors.push(e.message));
 await page.goto(pathToFileURL(directory+'/bild-markieren-preview.html').href);
 const frame=page.frameLocator('iframe'),canvas=frame.locator('[data-canvas]');
 await frame.locator('[data-status]').filter({hasText:'Bereit'}).waitFor();
 let checks=0;
 const check=(v,label)=>{if(!v)throw Error(label);checks++;};
 const pixel=()=>canvas.evaluate(c=>Array.from(c.getContext('2d').getImageData(c.width*.5,c.height*.5,1,1).data));
 const before=await pixel();
 async function paint(tool){
  await frame.locator('[data-tool]').selectOption(tool);
  const b=await canvas.boundingBox();
  await page.mouse.move(b.x+b.width*.4,b.y+b.height*.5);
  await page.mouse.down();
  await page.mouse.move(b.x+b.width*.6,b.y+b.height*.5,{steps:12});
  await page.mouse.up();
 }
 await paint('pen');
 check(JSON.stringify(await pixel())!==JSON.stringify(before),'Stift zeichnet');
 await frame.locator('[data-undo]').click();
 check(JSON.stringify(await pixel())===JSON.stringify(before),'Rückgängig stellt Original wieder her');
 await frame.locator('[data-redo]').click();
 check(JSON.stringify(await pixel())!==JSON.stringify(before),'Wiederholen');
 for(const tool of ['arrow','rect','ellipse'])await paint(tool);
 check((await frame.locator('[data-status]').textContent()).includes('4 Markierungen'),'Alle Werkzeuge');
 await frame.locator('[data-save]').click();
 check(await frame.locator('[data-export]').evaluate(el=>el.src.startsWith('data:image/png;')),'PNG-Exportvorschau');
 await frame.locator('body').evaluate(()=>{window.openai={sendFollowUpMessage:async data=>{window.testSent=data;}};});
 await frame.locator('[data-send]').click();
 check(await frame.locator('body').evaluate(()=>window.testSent.prompt.includes('BILDMARKIERUNG_JSON')),'Markierungen an Host übergeben');
 await frame.locator('[data-copy]').click();
 check(/kopiert|nicht erlaubt/.test(await frame.locator('[data-status]').textContent()),'Zwischenablage oder klarer Fallback');
 await frame.locator('[data-file]').setInputFiles('C:/Users/l_neu/Documents/TDHubclaude/TDHub/export/editoren/schlund-ruhigere-textur-nah.png');
 await frame.locator('[data-status]').filter({hasText:'Bereit'}).waitFor();
 check(await frame.locator('[data-undo]').isDisabled(),'Neues Bild lädt ohne alte Markierungen');
 for(const width of [1056,768,352]){
  await page.setViewportSize({width,height:1100});
  check(await frame.locator('#td-bildmarkierung').evaluate(el=>el.scrollWidth<=el.clientWidth+1),'Kein Überlauf '+width);
 }
 check(errors.length===0,'Keine Browserfehler: '+errors.join(';'));
 console.log('Bildmarkierung QA: '+checks+' OK');
}finally{await browser.close();}
