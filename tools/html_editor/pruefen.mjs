// Prüft den Map- und Tower-Editor im echten Browser (Playwright, Chromium):
// 1. Jede eingebettete Map und jeder Tower kommt beim Schreiben Byte für Byte gleich heraus (Format bleibt).
// 2. Map: neu anlegen, malen, Checkpoints, Weg, Rückgängig, als Datei speichern und wieder öffnen.
// 3. Tower: Werte und Fähigkeiten ändern, Spezial-Tower mit Rezept, speichern und wieder öffnen.
// Aufruf aus dem Projektordner: node tools/html_editor/pruefen.mjs [--laut] [--bilder=ordner]
// (oder tools/run_tests.sh htmleditor; läuft bei "geaendert" mit, wenn der Editor geändert wurde)
import { createRequire } from "module";
import { execFileSync } from "child_process";
import { mkdtempSync, readFileSync, writeFileSync } from "fs";
import { tmpdir } from "os";
import path from "path";
import { pathToFileURL } from "url";

const require = createRequire(import.meta.url);
let chromium;
try { ({ chromium } = require("playwright")); } catch (e) { ({ chromium } = createRequire(path.join(process.env.TDHUB_NODE_MODULES || "/opt/node22/lib/node_modules/", "package.json"))("playwright")); }

const tmp = mkdtempSync(path.join(tmpdir(), "html-editor-"));
const html = path.join(tmp, "td_editor.html");
execFileSync(process.env.TDHUB_PYTHON || "python3", ["tools/html_editor/bauen.py", "--ziel=" + html]);
const shots = (process.argv.find((a) => a.startsWith("--bilder=")) || "").split("=")[1];

let failed = 0;
const loud = process.argv.includes("--laut");
const check = (ok, text) => { if (!ok || loud) console.log((ok ? "OK     " : "FEHLER ") + text); if (!ok) failed++; };

const browser = await chromium.launch(process.env.TDHUB_CHROMIUM ? { executablePath:process.env.TDHUB_CHROMIUM } : {});
const page = await browser.newPage({ viewport: { width: 1400, height: 900 }, acceptDownloads: true });
const errors = [];
page.on("pageerror", (e) => errors.push(e.message));
page.on("dialog", (d) => d.accept());
await page.goto(pathToFileURL(html).href);

async function saved(button = "#b-save") {
  const [dl] = await Promise.all([page.waitForEvent("download"), page.click(button)]);
  const p = path.join(tmp, dl.suggestedFilename());
  await dl.saveAs(p);
  return { name: dl.suggestedFilename(), path: p, text: readFileSync(p, "utf8") };
}

// 1. Format
const bad = await page.evaluate(() => {
  const out = [];
  for (const [p, t] of Object.entries(D.maps)) { loadMap(parseJson(t), "", t.endsWith("\n")); if (mapText() !== t) out.push(p); }
  for (const [p, t] of Object.entries(D.towers)) if (dumpJson(parseJson(t)) + "\n" !== t) out.push(p);
  return out;
});
check(bad.length === 0, "Format bleibt beim Schreiben gleich (" + (bad.length ? bad.slice(0, 5).join(", ") : "alle Maps und Tower") + ")");
check(await page.evaluate(() => {const text=D.maps["data/maps/canyon.json"];if(!text)return true;loadMap(parseJson(text),"",text.endsWith("\n"));const name=M.obj.name;M.obj.name="Test";const changed=mapDirty();M.obj.name=name;return changed && !mapDirty() && mapText()===text;}), "Map-Änderung und Rücknahme bewahren kompaktes Originalformat und Dirty-Status");

// 2. Map
await page.click(".tab[data-tab=map]");
await page.click("text=Neu");
const box = await page.locator("#cv").boundingBox();
const cellPos = (x, y) => page.evaluate(([x, y]) => { const r = document.getElementById("cv").getBoundingClientRect(); return [r.left + M.ox + (x + 0.5) * M.zoom, r.top + M.oy + (y + 0.5) * M.zoom]; }, [x, y]);
const waitPath = () => page.waitForFunction(() => !M.needPath);
await waitPath();
check(await page.evaluate(() => M.paths[0] && M.paths[0].length > 0), "Neue Map hat einen gültigen Weg");

// Wand quer über die Map (Pinsel 2×2), mit Lücke rechts
await page.keyboard.press("1");
let [sx, sy] = await cellPos(0, 37);
const [ex] = await cellPos(66, 37);
await page.mouse.move(sx, sy); await page.mouse.down();
for (let x = sx; x <= ex; x += 4) await page.mouse.move(x, sy);
await page.mouse.up();
const wall = await page.evaluate(() => M.grid[37].join("").slice(0, 66));
check(/^#+$/.test(wall), "Wand gemalt: " + wall.slice(0, 20) + "…");
await waitPath();
const len1 = await page.evaluate(() => M.paths[0]?.length || 0);
check(len1 > 0, "Weg führt um die Wand (" + len1 + " Felder)");

// Lücke zu: kein Weg mehr
[sx, sy] = await cellPos(70, 37);
await page.mouse.click(sx, sy);
await page.mouse.click(...(await cellPos(68, 37)));
await page.mouse.click(...(await cellPos(72, 37)));
await waitPath();
check(await page.evaluate(() => M.paths[0] === null), "Geschlossene Wand: kein Weg");
check((await page.textContent("#pathstat")).includes("Kein gültiger Weg"), "Statuszeile meldet ungültigen Weg");
await page.keyboard.press("Control+z");
await waitPath();
check(await page.evaluate(() => M.paths[0] !== null), "Strg+Z macht den letzten Strich rückgängig");
await page.mouse.click(...(await cellPos(72, 37)), { button: "right" });
await page.mouse.click(...(await cellPos(70, 37)), { button: "right" });
await waitPath();

// Checkpoints
await page.keyboard.press("6");
await page.mouse.click(...(await cellPos(10, 60)));
await page.mouse.click(...(await cellPos(60, 10)));
await waitPath();
const cps = await page.evaluate(() => M.obj.checkpoints);
check(JSON.stringify(cps) === "[[10,60],[60,10]]", "Checkpoints gesetzt: " + JSON.stringify(cps));
check((await page.locator("#cps .row").count()) === 2, "Checkpoint-Liste zeigt 2 Einträge");
await page.locator("#cps .row").nth(1).locator("text=↑").click();
check(JSON.stringify(await page.evaluate(() => M.obj.checkpoints)) === "[[60,10],[10,60]]", "Checkpoint nach oben verschoben");

// Felder
await page.fill("label:has(span:text-is('Name')) input", "Test-Map");
await page.fill("label:has-text('ID (Dateiname') input", "test_map");
await page.fill("label:has-text('Leben') input", "30");
await page.selectOption("label:has-text('Modus') select", "eevetd");
check((await page.textContent("#dirty")).includes("ungespeichert"), "Ungespeichert-Hinweis");
if (shots) await page.screenshot({ path: path.join(shots, "map_editor.png") });
let f = await saved();
let m = JSON.parse(f.text);
check(f.name === "test_map.json", "Download heißt test_map.json");
check(m.format === 2 && m.width === 74 && m.tiles.length === 74 && m.tiles.every((r) => r.length === 74), "Map-Format 2, 74×74");
check(m.name === "Test-Map" && m.lives === 30 && m.game === "eevetd" && Object.keys(m).indexOf("game") === 3, "Name, Leben, Modus (nach name) gespeichert");
check(f.text.startsWith("{\n\t\"format\": 2,") && f.text.endsWith("}\n"), "Tabs und Zeilenende wie die Spieldateien");
check(!(await page.textContent("#dirty")), "Nach dem Speichern nichts mehr ungespeichert");

// Größe ändern
await page.fill("label:has-text('Breite') input", "60");
await page.click("text=Größe übernehmen");
check(await page.evaluate(() => M.obj.width === 60 && M.grid.every((r) => r.length === 60) && M.obj.goal[0] <= 59), "Größe auf 60 Breite geändert");

// Wieder öffnen
await page.setInputFiles("#file", f.path);
await page.waitForFunction(() => M.obj.width === 74, null, { timeout: 5000 }).catch(() => {});
check(await page.evaluate(() => M.obj.id === "test_map" && M.obj.width === 74 && !mapDirty()), "Gespeicherte Map lässt sich wieder öffnen");

// Mitgelieferte Maul-Map mit Bahnen: Bahn wechseln, Spawn setzen
const maul = await page.evaluate(() => Object.keys(D.maps).find((p) => p.includes("maul_4")));
if (maul) {
  await page.selectOption(".side select >> nth=0", maul);
  await waitPath();
  check(await page.evaluate(() => laneCount() === 4 && M.paths.every((p) => p && p.length)), "Maul-Map: 4 Bahnen mit gültigem Weg");
  check(await page.evaluate((p) => mapText() === D.maps[p], maul), "Maul-Map unverändert gleich");
}

// 3. Tower
await page.click(".tab[data-tab=tower]");
await page.fill("input[placeholder='Tower suchen']", "rubin");
await page.click(".tlist .item[data-id=ruby]");
const card0 = page.locator("#tform .card.tier").first();
await card0.locator("label:has-text('Reichweite') input").fill("7");
await card0.locator("label:has-text('Schaden max') input").fill("12");
await card0.locator("text=+ Fähigkeit").click();
const c0 = page.locator("#tform .card.tier").first();
await c0.locator(".ab").last().locator("select").selectOption("crit");
f = await saved();
let t = JSON.parse(f.text);
check(f.name === "ruby.json", "Tower-Download heißt ruby.json");
check(t.tiers[0].range === 7 && f.text.includes('"range": 7.0') && t.tiers[0].damage[1] === 12, "Reichweite 7.0 (Kommazahl) und Schaden gespeichert");
const crit = t.tiers[0].abilities.at(-1);
check(crit.type === "crit" && crit.chance === 0.2 && crit.multiplier === 2, "Fähigkeit Krit mit Standardwerten");
const orig = await page.evaluate(() => D.towers["data/towers/ruby.json"]);
const changedLines = f.text.split("\n").length - orig.split("\n").length;
check(changedLines === 5, "Nur die geänderten Zeilen kommen dazu (+" + changedLines + " Zeilen für die Fähigkeit)");

// Spezial-Tower: Rezept und Upgrade
await page.click("text=+ Spezial");
await page.fill("#tform label:has-text('ID (Dateiname)') input", "mein_turm");
await page.fill("#tform label:has(span:text-is('Name')) input", "Mein Turm");
await page.click("#b-save");
const msg1 = await page.textContent("#msg");
check(msg1.includes("Rezept"), "Spezial ohne Rezept wird abgelehnt (" + msg1 + ")");
await page.click("#tform >> text=+ Zutat >> nth=0");
await page.click("#tform >> text=+ Zutat „einer von …“ >> nth=0");
await page.locator("#tform .indent >> text=+ Zutat").first().click();
await page.click("#tform >> text=+ Stufe");
await page.locator("#tform .card").filter({ hasText: "Stufe 1 → 2" }).locator("input").fill("150");
if (shots) await page.screenshot({ path: path.join(shots, "tower_editor.png"), fullPage: true });
f = await saved();
t = JSON.parse(f.text);
check(f.name === "mein_turm.json" && t.category === "special" && t.recipe.length === 2 && t.recipe[1].any_of.length === 1, "Spezial-Tower mit Rezept gespeichert");
check(t.tiers.length === 2 && t.upgrades.length === 1 && t.upgrades[0].cost === 150, "Upgrade Stufe 1 → 2 mit Goldkosten");
check(!("model" in t) && f.text.includes('"cooldown": 1.0'), "Leeres Modell entfällt, Abklingzeit bleibt Kommazahl");

// JSON-Feld
await page.click("text=ERWEITERT (JSON)");
const ta = page.locator("#tform details textarea").first();
await ta.fill((await ta.inputValue()).replace('"Mein Turm"', '"Turm aus JSON"'));
await page.click("#tform button:text-is(\"Übernehmen\")");
const tn = await page.textContent(".tname");
check(tn === "Turm aus JSON", "Erweitert (JSON) übernimmt Änderungen (" + tn + " / " + (await page.textContent("#msg")) + ")");

// Wieder öffnen
await page.setInputFiles("#file", f.path);
await page.waitForFunction(() => T.obj.id === "mein_turm", null, { timeout: 5000 }).catch(() => {});
check(await page.evaluate(() => T.obj.id === "mein_turm" && T.obj.upgrades[0].cost === 150 && !towerDirty()), "Gespeicherter Tower lässt sich wieder öffnen");

// Kaputte Datei
const broken = path.join(tmp, "kaputt.json");
writeFileSync(broken, "{ nicht json");
await page.setInputFiles("#file", broken);
await page.waitForFunction(() => document.getElementById("msg").textContent.includes("kaputt.json"), null, { timeout: 5000 }).catch(() => {});
check((await page.textContent("#msg")).includes("keine gültige JSON-Datei"), "Kaputte Datei wird gemeldet");

// 4. Script authoring: syntax feedback, blocked invalid export, persisted tower draft.
check(await page.locator("#tform #invoke-refs").count() === 0, "Tower bietet keine Bollwerk-Invoke-Referenzen an");
await page.fill("#tform .effect-script", "OnHit(30%, IceBall(AoE(10m, Damage(50), Slow(20%, 3s))))");
check(await page.locator("#tform .effect-script").getAttribute("aria-invalid") === "false", "Tower-Skript gültig");
await page.fill("#tform .effect-script", "OnHit(30%, Unknown(5))");
await page.click("#b-save");
check((await page.textContent("#msg")).includes("Effektskript"), "Ungültiges Tower-Skript verhindert Export");
await page.fill("#tform .effect-script", "OnHit(30%, IceBall(AoE(10m, Damage(50), Slow(20%, 3s))))");

// 5. Full item catalog workflow; existing recipes/wood survive a new scripted item.
await page.click(".tab[data-tab=item]");
const originalCatalog = await page.evaluate(() => {I.catalog.custom_catalog={keep:true}; I.catalog.items[0].custom_field={keep:[1,2]}; I.catalog.items[0].stats={...I.catalog.items[0].stats,future_stat:2.5}; return {count:I.catalog.items.length,wood:JSON.stringify(I.catalog.wood),shops:JSON.stringify(I.catalog.shops),items:JSON.stringify(I.catalog.items)};});
await page.click("#i-new");
await page.fill("#iform label:has(span:text-is('ID')) input", "eiskugel_test");
await page.fill("#iform label:has(span:text-is('Name')) input", "Eiskugel-Test");
await page.fill("#iform label:has(span:text-is('Gold / Rezeptgold')) input", "250");
await page.fill("#iform label:has(span:text-is('Leben')) input", "100");
await page.click("#i-add-ingredient");
await page.fill("#iform .effect-script", "OnHit(30%, IceBall(AoE(10m, Damage(50), Slow(20%, 3s))))");
await page.click("#invoke-refs summary");
const gadgetReference=await page.evaluate(()=>D.invoke_catalog.findIndex(r=>r.group.startsWith("Gadgets")));
await page.selectOption("#invoke-refs select",String(gadgetReference));
const invokePreview=await page.inputValue("#invoke-refs input");
await page.click("#invoke-refs button");
check((await page.inputValue("#iform .effect-script")).includes(invokePreview) && await page.locator("#iform .effect-script").getAttribute("aria-invalid") === "false", "Echte Bollwerk-Gadget-ID als gültiger Invoke-Aufruf angehängt");
check(await page.evaluate(()=>new Set(D.invoke_catalog.map(r=>r.group)).size>=3 && D.invoke_catalog.some(r=>r.group.startsWith("Gegnerfähigkeiten"))), "Invoke-Referenzen gruppieren Helden, Gadgets und freundliche Gegnerfähigkeiten");
await page.reload();
check(await page.evaluate(() => TAB === "item" && I.catalog.items.at(-1).id === "eiskugel_test" && T.obj.effect_script?.includes("IceBall") && itemDirty() && towerDirty()), "Itemkatalog und Tower-Skript überstehen Neuladen als Entwurf");
await page.click("#i-copy");
check(await page.evaluate(() => I.catalog.items.at(-1).id === "eiskugel_test_kopie"), "Item dupliziert mit eindeutiger ID");
await page.evaluate(() => { I.catalog.items.at(-1).id = "eisenklinge"; renderItems(); });
await page.click("#b-save");
check((await page.textContent("#msg")).includes("Doppelte"), "Doppelte Item-ID verhindert Export");
await page.fill("#iform label:has(span:text-is('ID')) input", "eiskugel_test_kopie");
check(await page.evaluate(() => {const o=I.catalog.items.at(-1),recipe=o.recipe;o.recipe=["unbekannt"];const err=validateItems();o.recipe=recipe;return err.includes("unbekannte");}), "Unbekannte Rezeptzutat erkannt");
check(await page.evaluate(() => {const o=I.catalog.items.at(-1),recipe=o.recipe;o.recipe=[o.id];const err=validateItems();o.recipe=recipe;return err.includes("Rezeptkreis");}), "Rezeptkreis erkannt");
await page.fill("#iform label:has(span:text-is('Gold / Rezeptgold')) input", "-1");
await page.click("#b-save");
check((await page.textContent("#msg")).includes("price"), "Negative Kosten verhindern Export");
await page.fill("#iform label:has(span:text-is('Gold / Rezeptgold')) input", "250");
await page.fill("#iform .effect-script", "OnHit(200%, Damage(1))");
await page.click("#b-save");
check((await page.textContent("#msg")).includes("Effektskript"), "Ungültige Skriptchance verhindert Item-Export");
await page.fill("#iform .effect-script", "OnHit(30%, IceBall(AoE(10m, Damage(50), Slow(20%, 3s))))");
if (shots) await page.screenshot({path:path.join(shots,"item_editor.png"),fullPage:true});
f=await saved();
const catalog=JSON.parse(f.text);
check(f.name === "heroes_items.json" && catalog.items.length === originalCatalog.count+2 && JSON.stringify(catalog.wood)===originalCatalog.wood && JSON.stringify(catalog.shops)===originalCatalog.shops, "Vollständiger Itemkatalog bewahrt Holz und Shops");
check(JSON.stringify(catalog.items.slice(0,originalCatalog.count))===originalCatalog.items && catalog.custom_catalog.keep && catalog.items[0].stats.future_stat===2.5, "Vorhandene Items, unbekannte Felder und unbekannte Werte bleiben erhalten");
check(catalog.items.at(-1).stats.hp === 100 && catalog.items.at(-1).price === 250 && catalog.items.at(-1).recipe.length === 1 && catalog.items.at(-1).effect_script.includes("IceBall"), "Itemwerte, Rezept und Skript exportiert");
await page.setInputFiles("#file",f.path);
await page.waitForFunction(() => document.getElementById("msg").textContent.includes("Geladen:"));
check(await page.evaluate(() => !itemDirty() && I.catalog.items.at(-1).effect_script.includes("IceBall")), "Itemkatalog wieder importiert");
const single=path.join(tmp,"einzelitem.json");
writeFileSync(single,JSON.stringify({id:"einzelitem",name:"Einzelitem",tier:1,price:42}));
await page.setInputFiles("#file",single);
await page.waitForFunction(() => I.catalog.items.some(o=>o.id==="einzelitem"));
check(await page.evaluate(() => itemDirty() && I.catalog.items.filter(o=>o.id==="einzelitem").length===1), "Einzelitem wird in vollständigen Katalog übernommen");

// Switching to raw JSON must never revert more recent form/script edits.
await page.fill("#iform label:has(span:text-is('Name')) input", "Aktueller Formularname");
await page.fill("#iform .effect-script", "OnKill(Gold(7))");
await page.click("#iform summary:text-is('ERWEITERT (JSON)')");
await page.waitForFunction(()=>JSON.parse(document.querySelector("#iform .item-raw").value).name==="Aktueller Formularname");
const currentRaw=JSON.parse(await page.inputValue("#iform .item-raw"));
check(currentRaw.name==="Aktueller Formularname" && currentRaw.effect_script==="OnKill(Gold(7))", "Item-JSON öffnet den aktuellen Formular- und Skriptstand");
currentRaw.custom_latest=true;
await page.fill("#iform .item-raw",JSON.stringify(currentRaw));
await page.click("#iform details:has(.item-raw) button:text-is('Übernehmen')");
check(await page.evaluate(()=>I.catalog.items[I.selected].name==="Aktueller Formularname" && I.catalog.items[I.selected].effect_script==="OnKill(Gold(7))" && I.catalog.items[I.selected].custom_latest), "JSON-Übernahme erhält jüngste Formularwerte und Skript");

// Bad metadata must be rejected before rendering or replacing the live catalog.
const badCatalog=path.join(tmp,"katalog_fehler.json");
writeFileSync(badCatalog,JSON.stringify(await page.evaluate(()=>({...I.catalog,shops:"keine Liste"}))));
await page.setInputFiles("#file",badCatalog);
await page.waitForFunction(()=>document.getElementById("msg").textContent.includes("katalog_fehler.json"));
check((await page.textContent("#msg")).includes("shops-Liste") && await page.evaluate(()=>Array.isArray(I.catalog.shops) && I.catalog.items[I.selected].custom_latest), "Fehlerhafte Katalogmetadaten abgelehnt, aktuelle Daten erhalten");
check(await page.evaluate(()=>[null,[],{id:"grund"}].every(entry=>validateItems({...I.catalog,shops:[entry]}).includes("shops")) && validateItems({...I.catalog,tiers:"falsch"}).includes("tiers") && !!validateItems({items:[{id:123,name:"Numerische ID",tier:1}]})), "Ungültige Shop-/Stufeneinträge und nichttextuelle IDs werden gemeldet");

// Schmales Fenster: nichts ragt seitlich heraus
await page.setViewportSize({ width: 420, height: 800 });
await page.click("#iform summary:text-is('Hilfe und Beispiele')");
check(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth + 1), "Items und offene Skripthilfe ohne seitliches Scrollen");
if (shots) await page.screenshot({path:path.join(shots,"item_editor_mobile.png"),fullPage:true});
await page.click(".tab[data-tab=map]");
check(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth + 1), "Schmales Fenster ohne seitliches Scrollen");

check(errors.length === 0, "Keine Fehler im Browser" + (errors.length ? ": " + errors.join(" | ") : ""));
await browser.close();
console.log(failed ? `NICHT OK: ${failed} Fehler` : "OK: Map-, Tower- und Item-Editor");
process.exit(failed ? 1 : 0);
