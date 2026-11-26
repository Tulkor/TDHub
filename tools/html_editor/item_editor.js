// Item catalog remains intact: shops, tiers, wood and unknown fields survive export.
const I = { catalog: D.items ? parseJson(D.items) : {items: [], tiers: [], shops: []}, selected: 0, saved: "", search: "" };
I.saved = dumpJson(I.catalog) + "\n";
const itemText = () => dumpJson(I.catalog) + "\n";
const itemDirty = () => itemText() !== I.saved;
const ITEM_STATS = {hp:"Leben",mana:"Mana",armor:"Rüstung",hp_regen:"Lebensregeneration",mana_regen:"Manaregeneration",damage:"Schaden (Anteil)",attack_speed:"Angriffstempo (Anteil)",speed:"Tempo (Anteil)",cdr:"Abklingzeitverkürzung (Anteil)",lifesteal:"Lebensraub (Anteil)"};
let restoringEditors = true;
const DRAFT_KEY = "tdhub-editor-drafts-v1";
function persistEditors() {
  if (restoringEditors) return;
  try { localStorage.setItem(DRAFT_KEY, JSON.stringify({tab:TAB, tower:T.obj ? towerText() : null, towerSaved:T.saved, srcId:T.srcId, items:itemText(), itemsSaved:I.saved, selected:I.selected})); }
  catch (_) { /* Private browsing/storage quota: normal downloads remain available. */ }
}
function restoreEditors() {
  let draft;
  try { draft = JSON.parse(localStorage.getItem(DRAFT_KEY) || "null"); } catch (_) {}
  if (draft) {
    try {
      if (draft.tower) { T.obj = parseJson(draft.tower); T.saved = draft.towerSaved; T.srcId = draft.srcId; }
      if (draft.items) { const c = parseJson(draft.items); if (Array.isArray(c.items)) { I.catalog = c; I.saved = draft.itemsSaved; I.selected = Math.min(draft.selected || 0, Math.max(c.items.length - 1, 0)); } }
    } catch (_) { message("Der gespeicherte Entwurf konnte nicht vollständig geladen werden.", true); }
  }
  restoringEditors = false;
  setTab(["map","tower","item"].includes(draft?.tab) ? draft.tab : "map");
}
function compileScript(text) { return EffectScript.compile(String(text || ""), D.effect_catalog); }
function validateScript(o) {
  if (o.effect_script != null && typeof o.effect_script !== "string") return "Effektskript muss Text sein.";
  const result = compileScript(o.effect_script);
  return result.ok ? "" : "Effektskript: " + result.error;
}
function scriptBox(o, kind = "tower") {
  const status = el("div", {class:"note", role:"status"});
  const ta = el("textarea", {class:"effect-script", "aria-label":"Effektskript", spellcheck:"false", style:"min-height:110px", value:o.effect_script || ""});
  const update = () => {
    const r = compileScript(ta.value);
    status.className = "note " + (r.ok ? "ok" : "bad");
    status.textContent = r.ok ? (ta.value.trim() ? "Syntax gültig · unterstützte Wirkungen hängen vom Spielmodus ab (siehe Hilfe)." : "Optional: leer lassen für die bisherigen Fähigkeiten.") : r.error;
    ta.setAttribute("aria-invalid", String(!r.ok));
  };
  ta.addEventListener("input", () => { if (ta.value.trim()) o.effect_script = ta.value; else delete o.effect_script; message(""); update(); touched(); });
  const examples = ["OnHit(30%, IceBall(AoE(10m, Damage(50), Slow(20%, 3s))))", "Every(2s, AoE(5m, Damage(10)))", "OnKill(Gold(5))"];
  update();
  return section("Effektskript", "Ein kleines Effektskript statt Programmcode. Prozentwerte mit %, Reichweite mit m, Dauer mit s. Ungültige Skripte verhindern den Export.",
    ta, status, kind === "item" ? invokeReferences(ta) : null, el("details", {}, el("summary", {}, "Hilfe und Beispiele"),
      el("p", {class:"note"}, "OnHit: beim Treffer · Every: regelmäßig · OnKill: beim Töten. AoE wirkt im Umkreis; IceBall setzt einen Eiseffekt. Mehrere Anweisungen mit ; trennen. Bestehende Fähigkeiten bleiben erhalten."),
      ...examples.map(example => el("div", {class:"card"}, el("code", {style:"overflow-wrap:anywhere;white-space:pre-wrap"}, example), el("button", {class:"btn mini", style:"margin-top:6px", onclick:() => {ta.value = example; ta.dispatchEvent(new Event("input"));}}, "Beispiel einsetzen"))),
      el("p", {class:"note"}, "Die genaue Syntax wird mit demselben Effektkatalog wie im Spiel geprüft. Native(\"…\") nimmt eine JSON-Fähigkeit aus dem bisherigen Tower-System auf."),
      el("div", {class:"note"}, "Verfügbare Funktionen: " + Object.keys(D.effect_catalog?.functions || {}).join(", ")),
      el("h3", {}, "Unterstützung durch den Spielmodus"),
      ...Object.entries(D.effect_catalog?.functions || {}).filter(([,f]) => f.requires).map(([name,f]) => el("p", {class:"note"}, el("b",{},name+": "),String(f.requires)))));
}
function invokeReferences(ta) {
  const refs = D.invoke_catalog || [];
  if (!refs.length) return null;
  const command = index => 'Invoke(' + JSON.stringify(refs[Number(index)].id) + ", '{}')";
  const preview = el("input", {type:"text",readonly:true,"aria-label":"Invoke-Aufruf",value:command(0),style:"width:100%"});
  const select = el("select", {"aria-label":"Bollwerk-Fähigkeit",style:"width:100%",onchange:()=>{preview.value=command(select.value);}});
  const groups = new Map();
  refs.forEach((ref,index)=>{
    if (!groups.has(ref.group)) {const group=el("optgroup",{label:ref.group});groups.set(ref.group,group);select.append(group);}
    groups.get(ref.group).append(el("option",{value:String(index)},ref.name+" ("+ref.id+")"));
  });
  return el("details", {class:"card",id:"invoke-refs"}, el("summary",{},"Bollwerk-Fähigkeit einsetzen"),
    el("p",{class:"note"},"Echte IDs aus den Spieldaten. Heldenfähigkeiten und Gadgets müssen im eigenen Kit bekannt bzw. ausgerüstet sein. Gegnerfähigkeiten werden freundlich über ihre bestehende Zustandsmaschine ausgeführt. Diese Aufrufe benötigen Bollwerk; andere Spielmodi können eigene Adapter bereitstellen."),
    field("Fähigkeit",select),field("Aufruf zum Kopieren",preview),
    el("button",{class:"btn mini",style:"margin-top:8px",onclick:()=>{ta.value=(ta.value.trim() ? ta.value.trim().replace(/;$/,"")+";\n" : "")+command(select.value);ta.dispatchEvent(new Event("input"));ta.focus();}},"Aufruf anhängen"));
}
function validateItems(c = I.catalog) {
  if (!c || !Array.isArray(c.items)) return "Der Katalog braucht eine items-Liste.";
  for (const key of ["shops", "tiers"]) {
    if (key in c && !Array.isArray(c[key])) return "Der Katalog braucht eine " + key + "-Liste.";
    for (const entry of c[key] || []) {
      if (!entry || typeof entry !== "object" || Array.isArray(entry) || typeof entry.name !== "string" || (key === "shops" && typeof entry.id !== "string")) return "Ungültiger Eintrag in " + key + ".";
    }
  }
  const ids = new Set();
  for (const o of c.items) {
    if (!o || typeof o !== "object" || Array.isArray(o)) return "Jedes Item muss ein Objekt sein.";
    if (typeof o.id !== "string" || !validId(o.id)) return "Ungültige Item-ID: nur Kleinbuchstaben, Ziffern und _ erlaubt.";
    if (ids.has(o.id)) return "Doppelte Item-ID: " + o.id;
    ids.add(o.id);
    if (typeof o.name !== "string" || !o.name.trim()) return o.id + ": Name fehlt.";
    if (!Number.isInteger(o.tier) || o.tier < 1 || o.tier > 5) return o.id + ": Stufe muss zwischen 1 und 5 liegen.";
    for (const key of ["price","trophy","marks","stack"]) {
      if (key in o && (!Number.isInteger(o[key]) || o[key] < (key === "stack" ? 1 : 0) || o[key] > 1000000000)) return o.id + ": ungültiger Wert für " + key;
    }
    if (o.stats != null && (typeof o.stats !== "object" || Array.isArray(o.stats))) return o.id + ": stats muss ein Objekt sein.";
    for (const [k,v] of Object.entries(o.stats || {})) if (typeof v !== "number" || !Number.isFinite(v) || v < 0 || v > (k === "cdr" || k === "lifesteal" ? 1 : 1000000000)) return o.id + ": ungültiger Wert für " + k;
    if (o.recipe != null && (!Array.isArray(o.recipe) || o.recipe.some(id => typeof id !== "string"))) return o.id + ": Rezept muss eine Liste von Item-IDs sein.";
    const err = validateScript(o); if (err) return o.id + ": " + err;
  }
  const byId = new Map(c.items.map(o => [o.id,o]));
  for (const o of c.items) for (const id of o.recipe || []) if (!ids.has(id)) return o.id + ": unbekannte Rezeptzutat " + id;
  const done = new Set(), active = new Set();
  function visit(id) { if (active.has(id)) return id; if (done.has(id)) return ""; active.add(id); for (const sub of byId.get(id).recipe || []) { const cycle = visit(sub); if (cycle) return cycle; } active.delete(id); done.add(id); return ""; }
  for (const id of ids) { const cycle = visit(id); if (cycle) return "Rezeptkreis bei " + cycle; }
  return "";
}
function uniqueItemId(base) { let id = base, n = 2; while (I.catalog.items.some(o => o.id === id)) id = base + "_" + n++; return id; }
function newItem(copy = false) {
  const current = I.catalog.items[I.selected];
  const o = copy && current ? clone(current) : {id:"neues_item", name:"Neues Item",tier:1,price:100,stats:{}};
  o.id = uniqueItemId(copy ? o.id + "_kopie" : o.id);
  if (copy) o.name += " (Kopie)";
  I.catalog.items.push(o); I.selected = I.catalog.items.length - 1; renderItems(); touched();
}
function saveItems() {
  const err = validateItems(); if (err) {message(err,true);return;}
  const text = itemText(); download("heroes_items.json",text); I.saved = text; touched();
  message("Gespeichert: heroes_items.json (vollständiger Katalog). Zum Übernehmen data/heroes_items.json ersetzen.");
}
function importItems(obj, filename) {
  const catalog = Array.isArray(obj.items) ? obj : clone(I.catalog);
  if (!Array.isArray(obj.items)) {
    const at = catalog.items.findIndex(o => o.id === obj.id);
    if (at >= 0) catalog.items[at] = obj; else catalog.items.push(obj);
  }
  const err = validateItems(catalog); if (err) { message(filename + ": " + err,true); return; }
  if (Array.isArray(obj.items) && itemDirty() && !confirm("Ungespeicherten Itemkatalog durch diese Datei ersetzen?")) return;
  I.catalog = catalog; I.selected = Array.isArray(obj.items) ? 0 : catalog.items.findIndex(o => o.id === obj.id);
  if (Array.isArray(obj.items)) I.saved = itemText();
  setTab("item"); message("Geladen: " + filename + (Array.isArray(obj.items) ? " (vollständiger Katalog)" : " (Item in Katalog übernommen)")); touched();
}
function renderItemList() {
  const q = I.search.toLowerCase();
  $("ilist").replaceChildren(...I.catalog.items.map((o,n) => ({o,n})).filter(({o}) => (o.id + " " + o.name).toLowerCase().includes(q)).map(({o,n}) =>
    el("div", {class:"item" + (n === I.selected ? " on" : ""), "data-id":o.id, onclick:() => {I.selected=n;renderItems();touched();}}, o.name || o.id)));
}
function renderItems() {
  const search = el("input", {placeholder:"Items suchen", value:I.search, style:"width:100%", oninput:() => {I.search=search.value;renderItemList();}});
  $("main").replaceChildren(el("div", {class:"towerlayout"},
    el("div", {}, el("div", {class:"row",style:"margin-bottom:10px"}, el("button",{class:"btn",id:"i-new",onclick:()=>newItem()},"+ Item"),el("button",{class:"btn",id:"i-copy",onclick:()=>newItem(true)},"Duplizieren")),search,el("div",{class:"tlist",id:"ilist"}),
      el("p",{class:"note"},"Alle Änderungen bleiben im Katalog und werden lokal als Entwurf gesichert. Export lädt heroes_items.json mit allen Items, Shops und Holzregeln herunter.")),
    el("div",{id:"iform"})));
  renderItemList(); renderItemForm(); updateDirty();
}
function renderItemForm() {
  const o=I.catalog.items[I.selected], box=$("iform");
  if (!o) {box.replaceChildren(el("p",{},"Ein Item anlegen oder einen Katalog öffnen."));return;}
  const rerender=()=>{renderItemForm();renderItemList();touched();};
  const change=()=>{const heading=box.querySelector(".tname");if(heading)heading.textContent=o.name || o.id;renderItemList();touched();};
  const stats=o.stats || {};
  const shopOptions=[["","Nur Rezept / kein Laden"],...(I.catalog.shops || []).map(s=>[s.id,s.name])];
  if(o.shop && !shopOptions.some(([id])=>id===o.shop)) shopOptions.push([o.shop,o.shop]);
  const numeric=(key,label,min=0)=>field(label,numberEl(o,key,{min,max:1000000000,onchange:touched}));
  const recipe=o.recipe || [];
  const recipeRows=recipe.map((id,n)=>el("div",{class:"ing"},selectEl([["","Zutat wählen"],...I.catalog.items.map(i=>[i.id,i.name+" ("+i.id+")"]),...(!I.catalog.items.some(i=>i.id===id)?[[id,id]]:[])],id,v=>{o.recipe[n]=v;touched();}),el("button",{class:"btn mini",onclick:()=>{o.recipe.splice(n,1);rerender();}},"Entfernen")));
  const raw=el("textarea",{class:"item-raw",value:dumpJson(o),"aria-label":"Item JSON"});
  let rawEdited=false;
  raw.addEventListener("input",()=>{rawEdited=true;});
  const rawDetails=el("details",{class:"card"},el("summary",{},"ERWEITERT (JSON)"),raw,el("button",{class:"btn",onclick:()=>{try {const n=parseJson(raw.value);if(!n||typeof n!=="object"||Array.isArray(n))throw Error("Objekt erwartet");const candidate=clone(I.catalog);candidate.items[I.selected]=n;const err=validateItems(candidate);if(err)throw Error(err);I.catalog.items[I.selected]=n;rerender();message("Item-JSON übernommen.");}catch(e){message(e.message,true);}}},"Übernehmen"));
  rawDetails.addEventListener("toggle",()=>{if(rawDetails.open&&!rawEdited)raw.value=dumpJson(o);});
  box.replaceChildren(
    el("div",{class:"tname"},o.name || o.id),
    section("Item",null,el("div",{class:"fields"},field("ID",textEl(o,"id",change)),field("Name",textEl(o,"name",change)),field("Stufe",numberEl(o,"tier",{min:1,max:5})),field("Laden",selectEl(shopOptions,o.shop || "",v=>{if(v)o.shop=v;else delete o.shop;touched();})),numeric("price","Gold / Rezeptgold"),numeric("trophy","Trophäen"),numeric("marks","Arena-Marken"),field("Beschreibung",textEl(o,"desc"),true))),
    section("Werte","Anteile: 0.1 = +10 %. Abklingzeitverkürzung und Lebensraub: 0 bis 1.",el("div",{class:"fields"},...Object.entries(ITEM_STATS).map(([key,label])=>field(label,numberEl(stats,key,{float:true,min:0,max:key==="cdr"||key==="lifesteal"?1:1000000000,onchange:()=>{o.stats=stats;touched();}}))))),
    section("Rezept","Die gleiche Zutat darf mehrfach vorkommen. Unbekannte IDs und Rezeptkreise verhindern den Export.",...recipeRows,el("button",{class:"btn mini",id:"i-add-ingredient",onclick:()=>{(o.recipe ||= []).push(I.catalog.items.find(i=>i.id!==o.id)?.id || "");rerender();}},"+ Zutat")),
    section("Verbrauchs-Item","Vorhandene Wirkungen bleiben erhalten. Weitere Felder wie use und stack lassen sich unter Erweitert (JSON) ändern.",field("Ladungen je Platz",numberEl(o,"stack",{def:1,min:1,max:1000000000}))),
    scriptBox(o,"item"),
    rawDetails,
    el("button",{class:"btn mini",onclick:()=>{if(!confirm("Item löschen? Rezeptverweise müssen anschließend angepasst werden."))return;I.catalog.items.splice(I.selected,1);I.selected=Math.max(0,I.selected-1);renderItems();touched();}},"Item löschen"));
}
