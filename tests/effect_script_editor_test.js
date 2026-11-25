/* Run: node tests/effect_script_editor_test.js */
'use strict';
const fs = require('fs'), path = require('path'), assert = require('assert');
require('../tools/html_editor/effect_script.js');
const catalog = JSON.parse(fs.readFileSync(path.join(__dirname,'../scripts/systems/effect_script/catalog.json'),'utf8'));
const compile = text => globalThis.EffectScript.compile(text,catalog);
const valid = [
  'OnHit(30%, IceBall(AoE(10m, Damage(50), Slow(20%, 3s))))',
  "# comment\nEvery(2s,Self(Heal(10),Mana(5))); OnHurt(Self(Shield(50,3s)))",
  "Native('{\"type\":\"crit\",\"chance\":0.3}')",
  "OnNight(Self(Buff('damage',20%,5s))); OnHit(WhenDay(Damage(5)))",
  "Invoke('custom','{\"amount\":4}')"
];
for(const text of valid) assert(compile(text).ok, JSON.stringify(compile(text)));
const invalid = [
  'OnHit(101%,Damage(1))','OnHit(Damage(1),)','AoE(-1,Damage(1))',
  'Damage("x")','OnHit(OnKill(Gold(1)))','OnHit(Bogus(1))','Damage(1e999)',
  'Ring(5,2,Damage(1))',"Native('{\"type\":\"invented\"}')",
  "Native('{\"type\":\"crit\",\"chance\":\"wrong\"}')",'Damage(1,2)',
  "Native('{\"type\":\"crit\",\"chance\":2}')", "Native('{\"type\":\"crit\",\"invented\":1}')",
  "Invoke('x','[]')",'OnHit(', 'OnHit()', '0', 'Damage(1);'+ 'x'.repeat(16384)
  ,'toString()', 'constructor()', "Native('{\"type\":\"toString\"}')", "Native('{\"type\":\"crit\",\"constructor\":1}')"
  ,"Native('{\"type\":\"speed_aura\",\"chance\":0.5}')", 'Chain(1.5,5,Damage(1))', 'Summon("unit",2.5,5)'
];
for(const text of invalid) assert(!compile(text).ok,text);
assert.deepStrictEqual(compile('OnHit(30%,Damage(50))').ast,[{name:'OnHit',args:[0.3,{name:'Damage',args:[50]}]}]);
assert.equal(compile(valid[2]).passive[0].multiplier,2);
assert(!compile('Self('.repeat(26)+'Damage(1)'+')'.repeat(26)).ok);
assert(!compile(Array(130).fill('Damage(1)').join(';')).ok);
console.log('EffectScript editor: '+(valid.length+invalid.length+4)+' checks passed');

let imported = 0;
const towersDir = path.join(__dirname,'../data/towers');
for (const filename of fs.readdirSync(towersDir).filter(name => name.endsWith('.json'))) {
  const tower = JSON.parse(fs.readFileSync(path.join(towersDir,filename),'utf8'));
  for (const tier of tower.tiers || []) for (const ability of tier.abilities || []) {
    const native = {...ability};
    if (filename.startsWith('eeve_') && ownsNative('eeve.'+native.type) && !(native.type === 'chain' && 'count' in native)) native.type = 'eeve.'+native.type;
    assert(ownsNative(native.type),'missing existing runtime ability: '+native.type);
    const result = compile('Native('+JSON.stringify(JSON.stringify(native))+')');
    assert(result.ok, filename + ': ' + result.error);
    imported++;
  }
}
function ownsNative(name) { return Object.prototype.hasOwnProperty.call(catalog.native,name); }
for (const [type,scope] of Object.entries(catalog.native_scopes || {})) {
  assert.equal(scope,'eeve');
  assert(compile('Native('+JSON.stringify(JSON.stringify({type}))+')').ok,type);
}
const eeveItems = JSON.parse(fs.readFileSync(path.join(__dirname,'../data/eeve_items.json'),'utf8'));
function scanItems(node) {
  if (!node || typeof node !== 'object') return;
  if (Array.isArray(node.abilities)) for (const ability of node.abilities) {
    const native = {...ability};
    if (ownsNative('eeve.'+native.type)) native.type = 'eeve.'+native.type;
    const result = compile('Native('+JSON.stringify(JSON.stringify(native))+')');
    assert(result.ok,'existing eeve item: '+JSON.stringify(native)+' '+result.error);
  }
  for (const value of Object.values(node)) scanItems(value);
}
scanItems(eeveItems);
for (const args of [
  {type:'eeve.pulse',center:'invalid'}, {type:'eeve.pulse',targets:4},
  {type:'eeve.orb',color:'broken'}, {type:'eeve.chain',count:3},
  {type:'eeve.pulse',every:0}, {type:'armor_aura',targets:'invalid'}
]) assert(!compile('Native('+JSON.stringify(JSON.stringify(args))+')').ok,JSON.stringify(args));
const pulse = compile('Native('+JSON.stringify(JSON.stringify({type:'eeve.pulse',slow:0.5,center:'target',radius:0}))+')');
assert.equal(pulse.passive[0].stun,0,'slow-only pulse must not gain an unrelated stun');
console.log('EffectScript editor: '+imported+' existing Tower abilities validated, 8 eeve scopes and typed parameters passed');
