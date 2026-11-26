"""Englische Texte des Bollwerk-Kaders für die bestehende Lokalisierung."""
import json
from pathlib import Path
from runpy import run_path
ROOT=Path(__file__).resolve().parents[2]
source=run_path(str(Path(__file__).with_name('kader.py')))
EN_ABILITIES = '''Shield Bash|A shield bash hits a cone, knocks enemies back and interrupts them.
War Horn|Taunt nearby enemies for 3 seconds.
Charge|Charge 8 m, hit enemies along the way and stun them.
Shield Wall|A transverse shield wall blocks enemies and projectiles for 6 seconds.
Boulder|A boulder lands at the target after 0.8 seconds and stuns enemies.
Petrify|Become immobile and invulnerable for 2 seconds, then release a burst of shards.
Earth Wave|A fissure launches enemies along a line into the air.
Rockslide|Five boulders strike in succession around the target point.
Call the Wolves|Summon two wolves, up to four. They follow you and fight.
Pack Hunt|Your wolves leap to the target and pin nearby enemies down.
Shepherd's Crook|Pull enemies in a forward cone towards you.
Pack Spirit|A wolf aura strengthens you and your wolves; your hits heal you.
Blade Throw|A blade pierces enemies and applies three poison stacks.
Shadow Leap|Leap to the target point; your next basic attack deals triple damage.
Smoke Bomb|A smoke cloud reduces the damage of enemies inside by 45%.
Death Moth|Detonate your poison on nearby enemies for 55 damage per stack.
Heavy Bolt|A heavy bolt pierces up to three enemies.
Crossbow Turret|Place a crossbow turret for 30 seconds, up to three.
Springboard|Leap backwards and leave a trap that stuns enemies.
Siege Engine|A large mortar bombards enemy groups for 20 seconds.
Wind Cut|A short dash hits all enemies along your path.
Whirl|Spin your blade for 2 seconds while continuing to move.
Counter|Counter for one second: block the first hit and retaliate for triple damage.
Thousand Cuts|Eight rapid leaps between enemies; you are invulnerable during the sequence.
Fireball|A fireball explodes on the first enemy hit.
Wall of Fire|A burning line damages enemies repeatedly for four seconds.
Flame Step|Leap forward and leave a burning trail.
Meteor|After 1.5 seconds a massive meteor strikes the visible target circle.
Ice Lance|An ice lance pierces the enemy line and builds up cold.
Frost Field|A frost field heavily slows enemies and builds up cold.
Ice Block|Protect a nearby ally with ice; heroes become briefly invulnerable and recover health.
Glacier|A large ice cone freezes enemies and shatters for heavy damage.
Chain Lightning|Lightning jumps between up to five enemies.
Pitchfork Throw|A copper pitchfork strikes the target and attracts lightning for 4 seconds.
Thunderclap|A thunderclap around you briefly stuns enemies.
Storm Front|A storm follows you for 8 seconds and strikes nearby enemies.
Light Beam|A beam damages enemies and heals allies along a line.
Sanctuary|A protective circle heals heroes and reduces their damage taken by 30%.
Rescue|Pull an allied hero to you and grant a shield.
Resurrection|Revive fallen allies; living allies are healed and protected.
Place Lantern|Place up to three lanterns whose light heals and speeds up heroes.
Flare Arrow|Mark an enemy: it takes 20% more damage for 6 seconds.
Path Leap|Teleport to a lantern near the target point and heal yourself.
Beacon|All lanterns become suns for 6 seconds, increasing healing and repeatedly interrupting enemies.
Rune Hammer|A hammer blow hits ahead and strengthens nearby heroes.
Barricade|A sturdy barricade holds enemies back for 6 seconds.
Sharpen Weapon|Increase an allied hero's damage by 25% for 8 seconds.
Forge Fire|A runic anvil shields allies and increases their damage.
Blood Strike|A heavy strike heals you for a portion of its damage.
Battle Frenzy|Increase your damage and attack speed for 6 seconds.
Ironbreaker|Leap forward and shatter enemy armor.
Last Stand|Gain a strong shield, increased lifesteal and increased damage.
Mirror Shard|A piercing shard marks enemies and increases subsequent damage.
Illusions|Two mirror images distract enemies and attack for 12 seconds.
Mirror Swap|Swap positions with your nearest mirror image and gain a shield.
Hall of Mirrors|Summon four powerful illusions that distract enemies.
Cursed Feather|A feather pierces enemies and increases their damage taken.
Crow Swarm|A swarm of crows damages and weakens enemies in the target area.
Call of Doom|A cry interrupts enemies and reduces their armor.
Black Sky|A large cursed swarm deals damage and makes enemies vulnerable.
Rolling Barrel|A heavy barrel rolls through enemies, slowing and knocking them back.
Malt Shield|A thick layer of malt grants a shield and damage reduction.
Tavern Call|Taunt enemies and heal yourself for each enemy attracted.
Barrel Flood|Three heavy barrels spread out and knock enemies down.
Wind Bolt|A wind bolt pierces enemies and pushes them back.
Storm Gust|A broad gust pushes enemies back and slows them.
Sail Leap|A long leap briefly increases your movement speed.
Hurricane|A hurricane repeatedly pulls enemies towards its center and deals damage.
Soul Harvest|A sweep of soul energy hits enemies and heals nearby allies.
Grave Helpers|Summon two temporary grave helpers to distract and fight enemies.
Death Watch|A soul lantern heals allies and weakens enemies.
Return of Souls|Fallen heroes return; a powerful soul blessing heals the party.
Bell Strike|A heavy clapper strikes and interrupts enemies.
Echo Armor|A resonance shield protects you and damages nearby enemies when it ends.
Watch Chimes|The chimes taunt enemies and protect nearby heroes.
Evening Bell|Eight seconds of tolling interrupt enemies and grant shields to allies.
Anchor Throw|An anchor hits the first enemy, pulls it towards you and stuns it.
Chain Circle|Swing the chain to damage and slow nearby enemies.
Mooring|Anchor yourself: gain a shield, damage reduction and immunity to slows.
Harbor Bulwark|A broad anchor bulwark blocks enemies and projectiles for 8 seconds.'''

TITLES=['Shieldbearer','Stone Guardian','Pack Leader','Venom Blade','Tinkerer','Blade Dancer','Fire Mage','Frost Mage','Storm Farmer','Light Healer','Pathfinder','Rune Guardian','Berserker','Illusionist','Curse Weaver','Cellar Guardian','Wind Archer','Soul Keeper','Bell Knight','Chain Guardian']
PASSIVES='''Iron Will|Damage from enemies in front of you is reduced by 35%.
Moss|After standing still for 2 seconds, regenerate 3% of maximum health each second.
Pack|Each living wolf you own grants 2 armor.
Poison|Basic attacks apply poison, up to ten stacks per enemy.
Workbench|Your turrets within 8 m fire 25% faster.
Flow|Hits grant 3% attack speed, up to 30%, for 3 seconds.
Embers|Basic attacks leave a short-lived burning area at the target.
Cold|Frost hits slow enemies; every fifth hit briefly freezes them.
Charge|Damage taken builds charge; full charge strengthens your next damaging ability by 50%.
Grace|Excess ability healing becomes a limited shield.
Glow|Enemies in lantern light grant the party 20% additional kill gold.
Craftsmanship|Your recipes cost 10% less gold.
Blood Courage|As your health falls, your damage increases by up to 40%.
Mirror Skin|A living illusion you own reduces your damage taken by 15%.
Black Feather|Basic attacks make enemies 10% more vulnerable for 4 seconds.
Stout Brew|Hits heal you for 2% of maximum health, at most once per second.
Tailwind|Basic attacks grant 15% movement speed for 2 seconds.
Soul Remnant|Basic attacks heal the most injured nearby ally for 18.
Resonance|Every fourth basic attack grants a shield worth 8% of maximum health.
Heavy Stance|While standing still, you take 15% less damage.'''

translations={'Tank':'Tank','Heiler':'Healer','DD':'Damage','Offensive':'Offense','Defensive':'Defense','Utility':'Utility',
              'Heilung / Schild':'Healing / shields','Schaden':'Damage'}
abilities=[line.split('|',1) for line in EN_ABILITIES.splitlines()]
passives=[line.split('|',1) for line in PASSIVES.splitlines()]
assert len(abilities)==80 and len(passives)==20
for i,h in enumerate(source['HEROES']):
    hid,name,title,role,color,shape,passive,spells=h
    translations[name]=name
    translations[title]=TITLES[i]
    original=source['PASSIVES'][passive]
    translations.update(zip(original,passives[i]))
    for j,a in enumerate(spells):
        english=abilities[i*4+j]
        translations.update(zip((a['name'],a['desc']),english))

data=json.loads((ROOT/'data/heroes_helden.json').read_text(encoding='utf-8'))
prog=json.loads((ROOT/'data/heroes_progression.json').read_text(encoding='utf-8'))
intro={'offense':'More damage for attacks and abilities.','defense':'More health and armor; stronger healing and shields.',
       'utility':'More speed, range and duration; shorter cooldowns.'}
field_names={'stun':'stun duration (s)','duration':'duration (s)','range':'range (m)','blasts':'explosions','shield':'shield fraction',
 'radius':'radius (m)','damage':'damage','break_range':'tether range (m)','heal':'healing','knockback':'knockback (m)',
 'hp':'health','gadget_stats.hp':'construct health','count':'count','width':'width (m)','limit':'limit','poison':'poison stacks',
 'weaken':'damage reduction','dmg_out':'damage bonus','expose':'vulnerability','pull':'pull distance (m)','cooldown':'cooldown (s)'}
for h in data['heroes']:
    for card in prog['hero_imprints'][h['id']]:
        translations[card['name']]=f'{translations.get(h["title"],h["title"])}: '+{'offense':'Offense','defense':'Defense','utility':'Utility'}[card['category']]+f' {card["milestone"]}'
        change=card['skill_changes'][0]
        a=h['abilities'][0 if h['id']=='zix' else change['slot']]
        name='Construction Kit' if change['field'].startswith('gadget_stats') else translations.get(a['name'],a['name'])
        translations[card['desc']]=intro[card['category']]+f' {name}: {change["add"]:+g} {field_names[change["field"]]}.'
target=ROOT/'.godot/kader-english.json'
target.write_text(json.dumps(translations,ensure_ascii=False,indent='\t')+'\n',encoding='utf-8')
run_path(str(ROOT/'tools/pruefe_ui.py'))['eintragen'](str(target))
