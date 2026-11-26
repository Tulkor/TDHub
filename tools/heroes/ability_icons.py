#!/usr/bin/env python3
"""Originale monochrome Bollwerk-Fähigkeitssymbole; keine übernommenen Referenzgrafiken."""
import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/heroes/ability_icons'

def path(d, fill='none', width=5):
    return f'<path d="{d}" fill="{fill}" stroke="white" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round" fill-rule="evenodd"/>'

def circle(x,y,r,fill='none',width=4):
    return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" stroke="white" stroke-width="{width}"/>'

def group(body,x=64,y=64,scale=1,rotate=0):
    return f'<g transform="translate({x} {y}) rotate({rotate}) scale({scale}) translate(-64 -64)">{body}</g>'

S = {
 'axe':path('M39 109 78 25 M72 37Q98 28 110 52L89 70Q91 51 69 53 M66 48 53 39 60 24 82 27','white',3),
 'bolt':path('M72 10 31 70 57 67 49 119 99 51 70 55Z','white',2),
 'fire':path('M67 9C78 44 100 47 105 72C116 113 52 126 29 98C8 72 35 53 39 35C40 53 51 58 56 52C65 39 57 26 67 9ZM64 66C61 81 47 85 51 99C54 111 78 112 83 99C88 87 71 79 64 66Z','white',2),
 'rock':path('M17 81 30 39 65 19 100 34 115 78 89 108 43 113Z M30 39 63 53 100 34 M63 53 56 91 43 113 M56 91 89 108 M63 53 82 79 115 78'),
 'wind':path('M12 46H78C109 46 113 15 91 15C77 15 73 27 82 30 M8 66H106 M24 86H72C99 86 104 115 83 115C72 115 68 105 76 101'),
 'bomb':circle(61,76,33)+path('M73 43 81 29 94 37 87 52 M85 32Q88 13 104 14 M104 8 107 18 M36 76Q36 59 50 55'),
 'rat':path('M24 89C16 109 2 99 11 88C18 81 25 84 27 76C31 56 53 51 71 61L88 54 111 73 88 83 56 91Z M46 90 40 103 M79 87 89 99')+circle(77,52,10)+circle(94,69,2,'white',1),
 'robe':path('M50 19Q64 11 78 19L88 37 109 56 94 74 87 64 96 111H32L41 64 34 74 19 56 40 37Z M50 19 54 41H74L78 19 M49 56 43 100 M79 56 85 100'),
 'banner':path('M29 114V16 M31 22H108L91 46 108 69H32 M29 114H45 M45 38H76 M45 52H66')+circle(29,13,5,'white',2),
 'drop':path('M64 11C58 32 28 59 28 82C28 127 100 127 100 82C100 59 70 32 64 11Z M43 83Q42 98 56 101'),
 'arrow':path('M21 105 99 27 M79 26 108 19 101 49 M18 85 18 108 42 108 M33 71 33 94 56 94'),
 'capsule':path('M37 21Q64 6 91 21V108Q64 123 37 108Z M37 43Q64 58 91 43 M37 87Q64 102 91 87 M64 62V82 M54 72H74'),
 'syringe':path('M32 96 81 47 99 65 50 114Z M86 41 107 62 M89 44 101 32 M96 25 114 43 M32 96 17 111 M48 81 58 91 M59 70 69 80 M70 59 80 69'),
 'shield':path('M64 13Q84 27 108 24V64Q106 94 64 116Q22 94 20 64V24Q44 27 64 13Z M64 29V98 M36 36V63Q38 79 49 88'),
 'horn':path('M25 86Q47 88 76 47L94 64Q59 104 22 102Z M75 46 87 31 108 51 95 65 M31 88 36 101 M98 23Q113 22 117 36 M101 12Q123 12 126 35'),
 'wolf':path('M23 19 45 32 64 24 84 32 106 19 100 70 83 94 64 116 43 94 28 70Z M24 19 39 56 30 70 M106 19 89 56 100 70 M42 63 51 66 M77 66 86 63 M54 87 64 94 74 87 M54 103 64 96 74 103'),
 'staff':path('M47 114 69 33Q43 32 46 15Q48 1 69 9Q91 19 78 40 M39 114H56 M65 48 77 52'),
 'dagger':path('M35 104 48 91 M34 80 55 101 M44 85 80 25 103 15 95 41 56 96Z M59 76 87 36'),
 'smoke':path('M31 91C7 88 12 59 32 57C26 30 57 22 72 38C91 18 120 39 109 60C132 76 106 104 87 94C73 111 48 103 46 94 M48 71Q64 56 81 69 M43 113Q54 104 62 113 M84 108 96 114'),
 'moth':path('M60 36C44 13 9 15 16 49L47 65C11 65 20 103 45 99L61 75 M68 36C84 13 119 15 112 49L81 65C117 65 108 103 83 99L67 75 M64 32V103 M63 31 51 15 M65 31 77 15'),
 'crossbow':path('M19 70Q64 13 109 70 M19 70 64 85 109 70 M64 22V112 M54 100 64 112 74 100 M64 21 55 37 M64 21 73 37 M53 65H75'),
 'trap':path('M21 101H107 M36 100 48 69 79 59 68 89 36 79 49 47 85 47 98 66 M29 36 37 26 M89 26 101 35 M48 16H79'),
 'mortar':path('M35 90 67 30 101 46 73 99Z M67 30Q69 22 84 29L101 37Q107 44 101 46 M28 101H98 M47 104 32 117 M83 104 100 117 M34 90 72 105'),
 'sword':path('M63 12 48 36V87H77V36Z M39 88H86 M57 91V111H70V91 M53 116H75 M63 31V74'),
 'ice':path('M64 12 86 43 108 49 104 96 64 118 24 96 20 49 43 43Z M64 12V118 M20 49 64 67 108 49 M43 43 42 87 64 118 M86 43 86 87 64 118'),
 'snow':path('M64 13V115 M20 38 108 90 M20 90 108 38 M51 21 64 34 77 21 M51 107 64 94 77 107 M24 53 41 50 38 33 M24 75 41 78 38 95 M104 53 87 50 90 33 M104 75 87 78 90 95'),
 'fork':path('M64 115V24 M33 17V48Q33 62 64 62Q95 62 95 48V17 M23 29 33 17 43 29 M54 28 64 15 74 28 M85 29 95 17 105 29'),
 'cloud':path('M21 70C2 53 18 33 36 38C40 8 78 9 88 33C116 20 131 59 108 72Z M31 89 25 101 M100 89 94 104'),
 'cross':path('M52 18H76V50H108V76H76V110H52V76H20V50H52Z','white',2),
 'hand':path('M29 108 18 68Q18 57 26 64L39 80V33Q39 22 47 31L50 63V18Q52 7 59 17L63 61V20Q68 9 74 22L76 64 82 34Q88 26 91 37L88 78Q103 60 110 67L95 100 81 115Z'),
 'person':circle(64,35,15)+path('M26 112V88Q26 62 64 62Q102 62 102 88V112 M47 112V85 M81 85V112'),
 'lantern':path('M38 39H91L99 104Q64 120 29 104Z M37 39 48 25H80L91 39 M52 24V17Q64 3 76 17V24 M44 48 42 98 M85 48 87 98 M49 95Q62 104 77 95 M60 55C73 69 76 80 66 88C53 88 49 76 60 55Z'),
 'hammer':path('M50 113 72 51 M33 20 94 32 87 61 26 49Z M37 26 33 43 M86 37 82 54 M63 63 72 66'),
 'wall':path('M16 107V36H37V57H53V24H75V57H91V36H112V107Z M16 80H112 M46 80V107 M84 80V107'),
 'anvil':path('M19 38H110L94 60H77L75 86 97 104H32L54 86V63H39Z M18 38 9 28H55V38 M47 113H86'),
 'heart':path('M64 112C40 91 13 69 15 44C17 17 48 11 64 33C80 11 111 17 113 44C115 69 88 91 64 112Z M24 66H42L52 49 65 82 77 61H104'),
 'mirror':path('M64 12 100 37V91L64 116 28 91V37Z M64 25 87 43V85L64 103 41 85V43Z M49 72 78 45 M51 89 79 62'),
 'feather':path('M20 116 94 20 M31 90C5 62 40 39 59 30L108 9 101 52 76 49 87 69 63 67 70 87 47 82 47 102Z'),
 'crow':path('M16 56 47 45 68 17 83 23 100 11 97 39 116 48 94 55 85 78 95 108 69 91 46 99 47 79 27 83 33 68Z M44 57 71 45 M49 71 77 55 M68 89 79 77'),
 'barrel':path('M30 22Q64 8 98 22L108 105Q64 122 20 105Z M30 22Q64 38 98 22 M25 48Q64 63 102 48 M23 88Q64 104 105 88 M48 34 43 111 M80 34 85 111'),
 'mug':path('M30 36H87V107Q58 121 30 107Z M87 45H103Q119 65 103 83H87 M30 36C15 18 44 8 54 25C63 6 88 18 87 36 M45 52V97 M71 52V97'),
 'sail':path('M64 12V112 M57 18 20 85H58 M71 32 105 87H71 M17 104Q31 117 44 104Q57 117 70 104Q83 117 96 104Q109 117 119 104'),
 'scythe':path('M32 116 71 19 M30 29C71 3 111 19 116 57C90 39 71 34 56 42 M55 39 65 20'),
 'skull':path('M37 90C8 76 18 20 49 15C94 3 122 51 97 84L88 90V110H42V90Z M34 52Q44 41 55 52Q57 67 42 68Q31 66 34 52Z M77 50Q90 40 97 52Q99 65 85 68Q73 67 77 50Z M63 66 55 80H73Z M54 94V111 M69 94V111 M82 94V109','white',2),
 'bell':path('M64 24C36 24 36 56 33 76L20 94H108L95 76C92 56 92 24 64 24Z M55 24V15Q64 4 73 15V24 M53 101Q64 119 75 101 M42 72V55'),
 'anchor':path('M64 33V102 M36 48H92 M20 74C20 99 43 115 64 112C85 115 108 99 108 74 M14 86 20 73 34 78 M94 78 108 73 114 86 M54 94 64 106 74 94')+circle(64,21,12),
 'chain':path('M45 35 34 24C17 7 1 29 15 45L31 61C45 75 66 61 52 44 M47 83 64 100C80 116 102 96 86 80L72 66C56 52 36 71 47 83 M35 48 68 82'),
 'magnet':path('M28 28H48V69Q48 89 64 89Q80 89 80 69V28H100V72C100 121 28 121 28 72Z M28 47H48 M80 47H100 M8 55 17 63 M111 55 120 63'),
 'robot':path('M28 33H100V87H28Z M64 16V33 M44 88V114 M84 88V114 M15 48V82 M113 48V82 M41 72H88')+circle(46,53,6)+circle(82,53,6)+circle(64,13,5),
 'gear':path('M51 12H77L80 27 94 35 109 30 121 52 108 64 108 79 118 91 104 111 88 105 75 112 70 123 46 117 46 102 33 94 18 98 8 76 21 65 21 49 12 39 27 20 41 26 51 23Z')+circle(64,65,23)+circle(64,65,8),
}

# Breite Beschlagflächen mit echten transparenten Aussparungen, keine bloßen Drahtkonturen.
S.update({
 'bomb':path('M94 76A33 33 0 1 0 28 76A33 33 0 1 0 94 76Z M42 72Q43 57 57 55L58 62Q49 64 49 73Z','white',2)+path('M73 43 81 29 94 37 87 52 M85 32Q88 13 104 14 M104 8 107 18',width=6),
 'drop':path('M64 11C58 32 28 59 28 82C28 127 100 127 100 82C100 59 70 32 64 11Z M40 81H47Q47 94 59 98L56 105Q39 101 40 81Z','white',2),
 'rock':path('M17 81 30 39 65 19 100 34 115 78 89 108 43 113Z M34 43 61 56 57 64 30 51Z M65 56 72 59 61 95 53 100Z M71 61 86 80 109 80 105 86 81 86 65 66Z','white',2),
 'wolf':path('M23 19 45 32 64 24 84 32 106 19 100 70 83 94 64 116 43 94 28 70Z M31 29 36 54 44 47Z M98 29 91 54 84 47Z M40 61 55 66 49 72 40 68Z M73 66 88 61 88 68 79 72Z M55 87 64 96 73 87Z M52 102 64 106 76 102 64 114Z','white',2),
 'rat':path('M24 89C16 109 2 99 11 88C18 81 25 84 27 76C31 56 53 51 71 61L88 54 111 73 88 83 56 91Z M91 67 98 69 94 74Z','white',2)+circle(77,52,10,'none',5)+path('M46 90 40 103 M79 87 89 99',width=7),
 'robe':path('M50 19Q64 11 78 19L88 37 109 56 94 74 87 64 96 111H32L41 64 34 74 19 56 40 37Z M53 20 57 36H71L75 20Z M48 56 42 100 49 100 54 59Z M74 59 79 100 86 100 80 56Z','white',2),
 'shield_plate':path('M64 13Q84 27 108 24V64Q106 94 64 116Q22 94 20 64V24Q44 27 64 13Z M60 31H68V95L64 102 60 95Z M32 38H51V44H32Z M77 38H96V44H77Z','white',2),
 'sword':path('M63 12 48 36V84H77V36Z M60 35H66V72H60Z M39 85H86V93H70V110H56V93H39Z M53 113H75V120H53Z','white',2),
 'dagger':path('M34 80 45 84 80 25 103 15 95 41 57 94 55 101 45 95 35 109 29 103 39 89Z M61 65 87 32 83 45 64 72Z','white',2),
 'capsule':path('M37 21Q64 6 91 21V108Q64 123 37 108Z M44 40Q64 50 84 40V47Q64 57 44 47Z M59 63H69V73H79V83H69V93H59V83H49V73H59Z','white',2),
 'syringe':path('M32 96 81 47 99 65 50 114Z M46 82 51 77 62 88 57 93Z M61 67 66 62 77 73 72 78Z','white',2)+path('M86 41 107 62 M89 44 101 32 M96 25 114 43 M32 96 17 111',width=7),
 'banner':path('M31 22H108L91 46 108 69H32Z M44 36H76V42H44Z M44 50H66V56H44Z','white',2)+path('M29 114V16 M29 114H45',width=7)+circle(29,13,5,'white',2),
 'barrel':path('M30 22Q64 8 98 22L108 105Q64 122 20 105Z M31 45Q64 59 98 45L99 52Q64 66 30 52Z M27 83Q64 99 102 83L103 90Q64 106 26 90Z M44 30H50L47 42H41Z M80 30H86L89 42H83Z M41 65H47L45 80H39Z M84 65H90L92 80H86Z','white',2),
 'bell':path('M64 24C36 24 36 56 33 76L20 94H108L95 76C92 56 92 24 64 24Z M43 45 50 40 48 70 40 76Z M36 82H94V87H36Z','white',2)+path('M55 24V15Q64 4 73 15V24',width=6)+path('M53 101Q64 119 75 101','white',4),
 'gear':path('M51 12H77L80 27 94 35 109 30 121 52 108 64 108 79 118 91 104 111 88 105 75 112 70 123 46 117 46 102 33 94 18 98 8 76 21 65 21 49 12 39 27 20 41 26 51 23Z M64 38A27 27 0 1 0 64 92A27 27 0 1 0 64 38Z','white',2),
 'wind':path('M12 46H78C109 46 113 15 91 15C77 15 73 27 82 30 M8 66H106 M24 86H72C99 86 104 115 83 115C72 115 68 105 76 101',width=9),
 'staff':path('M47 114 69 33Q43 32 46 15Q48 1 69 9Q91 19 78 40 M39 114H56 M65 48 77 52',width=8),
 'anchor':path('M64 33V102 M36 48H92 M20 74C20 99 43 115 64 112C85 115 108 99 108 74 M14 86 20 73 34 78 M94 78 108 73 114 86 M54 94 64 106 74 94',width=9)+circle(64,21,12,'none',7),
 'cloud':path('M21 70C2 53 18 33 36 38C40 8 78 9 88 33C116 20 131 59 108 72Z','white',2)+path('M31 89 25 101 M100 89 94 104',width=7),
 'ice':path('M64 12 86 43 108 49 104 96 64 118 24 96 20 49 43 43Z M60 28H68V105L64 111 60 105Z M28 53 54 65 51 72 27 61Z M76 65 100 53 101 61 78 72Z M32 77 38 77 44 95 38 99Z M90 77 96 77 90 99 84 95Z','white',2),
 'hand':path('M29 108 18 68Q18 57 26 64L39 80V33Q39 22 47 31L50 63V18Q52 7 59 17L63 61V20Q68 9 74 22L76 64 82 34Q88 26 91 37L88 78Q103 60 110 67L95 100 81 115Z M48 87 55 83 72 99 68 105Z','white',2),
 'hammer':path('M50 113 72 51',width=9)+path('M33 20 94 32 87 61 26 49Z M38 28 43 29 40 43 35 42Z M82 38 87 39 84 53 79 52Z','white',2),
 'anvil':path('M19 38H110L94 60H77L75 86 97 104H32L54 86V63H39Z M18 38 9 28H55V38 M49 51H85L80 57H49Z','white',2)+path('M47 113H86',width=7),
 'wall':path('M16 107V36H37V57H53V24H75V57H91V36H112V107Z M22 77H106V84H22Z M42 89H49V107H42Z M80 89H87V107H80Z M60 34H67V68H60Z','white',2),
 'lantern':path('M38 39H91L99 104Q64 120 29 104Z M46 49H83L88 96Q64 105 40 96Z M37 39 48 25H80L91 39Z','white',2)+path('M52 24V17Q64 3 76 17V24',width=7)+path('M60 55C73 69 76 80 66 88C53 88 49 76 60 55Z','white',2),
 'person':circle(64,35,15,'white',2)+path('M26 112V88Q26 62 64 62Q102 62 102 88V112Z M44 84H50V109H44Z M78 84H84V109H78Z','white',2),
 'feather':path('M31 90C5 62 40 39 59 30L108 9 101 52 76 49 87 69 63 67 70 87 47 82 47 102Z M35 79 84 29 88 32 39 84Z','white',2)+path('M20 116 94 20',width=7),
 'crow':path('M16 56 47 45 68 17 83 23 100 11 97 39 116 48 94 55 85 78 95 108 69 91 46 99 47 79 27 83 33 68Z M41 57 71 42 74 48 44 63Z M48 72 76 55 80 60 51 78Z M78 30 85 27 85 34 78 36Z','white',2),
 'sail':path('M57 18 20 85H58Z M71 32 105 87H71Z M48 46 33 77H39L52 46Z','white',2)+path('M64 12V112 M17 104Q31 117 44 104Q57 117 70 104Q83 117 96 104Q109 117 119 104',width=7),
 'chain':path('M45 35 34 24C17 7 1 29 15 45L31 61C45 75 66 61 52 44 M47 83 64 100C80 116 102 96 86 80L72 66C56 52 36 71 47 83 M35 48 68 82',width=9),
})

RECIPES = {
 'torvik':[('axe','thunder_pair'),('fire','ring'),('rock','projectile'),('wind','ascend')],
 'unrat':[('bomb','triple'),('rat','swarm'),('robe','shield'),('banner','rat')],
 'vesna':[('drop','drain'),('arrow','stun'),('capsule','heal'),('syringe','boost')],
 'brennholt':[('shield','push'),('horn','taunt'),('shield','dash'),('shield','wall')],
 'mira':[('rock','fall'),('rock','shield'),('rock','crack'),('rock','rain')],
 'grauhirte':[('wolf','pair'),('wolf','dash'),('staff','pull'),('wolf','heal_ring')],
 'sirra':[('dagger','projectile'),('person','blink'),('smoke','ring'),('moth','drop')],
 'kaspar':[('arrow','pierce'),('crossbow','tripod'),('trap','backstep'),('mortar','rain')],
 'yuna':[('sword','dash'),('sword','whirl'),('sword','counter'),('sword','cuts')],
 'orrin':[('fire','projectile'),('fire','wall'),('fire','dash'),('rock','meteor')],
 'ilsabet':[('ice','pierce'),('snow','ring'),('ice','shield'),('ice','fan')],
 'tamo':[('bolt','chain'),('fork','fall'),('bolt','ring'),('cloud','storm')],
 'albe':[('cross','beam'),('cross','ring'),('hand','pull'),('person','revive')],
 'fenn':[('lantern','ground'),('arrow','target'),('lantern','blink'),('lantern','radiate')],
 'ralda':[('hammer','rune'),('wall','ground'),('sword','sharpen'),('anvil','fire')],
 'varg':[('axe','drop'),('heart','boost'),('hammer','broken_shield'),('heart','shield')],
 'lior':[('mirror','projectile'),('person','pair'),('mirror','swap'),('mirror','swarm')],
 'kraehenfrau':[('feather','projectile'),('crow','swarm'),('crow','taunt'),('crow','rain')],
 'bruno':[('barrel','dash'),('mug','shield'),('mug','taunt'),('barrel','fan')],
 'tessa':[('arrow','wind'),('wind','push'),('sail','ascend'),('wind','whirl')],
 'totengraeber':[('scythe','heal'),('skull','pair'),('lantern','skull'),('skull','revive')],
 'ada':[('bell','hammer'),('bell','shield'),('bell','taunt'),('bell','radiate')],
 'sorek':[('anchor','projectile'),('chain','whirl'),('anchor','shield'),('anchor','wall')],
}
GADGETS = {
 'bolzenturm':('crossbow','tripod'), 'flammenspeier':('fire','tripod'),
 'raketenwerfer':('mortar','target'), 'teslaspule':('bolt','coil'),
 'sanitaetsmast':('cross','tripod'), 'heilsprinkler':('cross','fountain'),
 'schrottbot':('robot','shield'), 'elektrozaun':('bolt','fence'),
 'schildkuppel':('shield','dome'), 'magnetkoeder':('magnet','pull'),
}

def render(base,effect):
    symbol=S['shield_plate'] if base=='shield' else S[base]
    body=group(symbol,64,61,.85)
    ring='<ellipse cx="64" cy="105" rx="52" ry="13" fill="none" stroke="white" stroke-width="4"/>'
    motion=path('M8 43H34 M5 64H28 M11 85H34',width=4)
    if effect=='thunder_pair':
        return group(symbol,42,63,.7,-24)+group(symbol,86,63,.7,24)+group(S['bolt'],65,76,.43)
    if effect in ('pair','swarm','rain','fan','wall','cuts'):
        if effect=='pair': return group(symbol,43,70,.64,-8)+group(symbol,88,59,.64,8)
        positions={'swarm':[(31,78,.48,-18),(63,42,.55,0),(98,80,.48,18)],'rain':[(28,78,.46,-20),(64,91,.5,0),(98,53,.46,15)],'fan':[(29,69,.55,-27),(64,49,.61,0),(100,69,.55,27)],'wall':[(27,71,.53,0),(64,63,.65,0),(101,71,.53,0)],'cuts':[(30,70,.55,-28),(65,57,.7,0),(98,70,.55,28)]}
        body=''.join(group(symbol,*p) for p in positions[effect])
        if effect=='rain':body+=path('M19 15 16 33 M57 11 54 29 M96 8 93 26',width=4)
        return body
    if effect in ('shield','dome'):
        return group(S['shield'],64,66,1.02)+group(symbol,64,61,.52)
    if effect in ('ring','ground','heal_ring','radiate'):
        body=group(symbol,64,51,.75)+ring
        if effect=='heal_ring':body+=group(S['cross'],102,88,.28)
        if effect=='radiate':body+=path('M14 48 5 44 M113 47 123 43 M29 22 22 13 M99 22 106 13',width=4)
        return body
    if effect in ('projectile','pierce','dash','wind'):
        body=group(symbol,78,63,.76,20 if base in ('arrow','dagger') else 0)+motion
        if effect=='pierce':body+=path('M89 14V114',width=3)
        if effect=='wind':body+=path('M9 105Q53 121 84 102',width=4)
        return body
    if effect in ('whirl','counter','swap','blink'):
        body=group(symbol,64,66,.68)
        body+=path('M21 47C27 7 94 5 109 44 M96 39 110 46 115 30 M107 83C95 123 31 124 18 85 M30 90 17 82 12 99',width=5)
        if effect=='blink':body+=path('M11 58H27 M8 69H24',width=4)
        return body
    if effect in ('taunt','stun','boost','ascend'):
        body=group(symbol,64,67,.76)
        if effect=='taunt':body+=path('M16 34Q1 61 15 85 M108 33Q126 61 111 85',width=4)
        if effect=='stun':body+=path('M19 16Q62 1 104 16 M20 16 31 29 M104 16 92 28',width=4)
        if effect in ('boost','ascend'):body+=path('M12 85V34 M4 45 12 32 21 45 M115 85V34 M107 45 115 32 123 45',width=4)
        return body
    if effect in ('heal','drop','fire','rat','skull','hammer','chain'):
        overlay={'heal':'cross','drop':'drop','fire':'fire','rat':'rat','skull':'skull','hammer':'hammer','chain':'bolt'}[effect]
        return group(symbol,54,57,.8)+group(S[overlay],98,96,.37)
    if effect=='drain':return group(symbol,29,69,.46)+group(symbol,99,69,.46)+path('M46 62H81 M72 53 83 62 72 72')
    if effect=='beam':return group(symbol,64,64,.62)+path('M8 43H119 M8 85H119 M8 64H30 M98 64H120',width=4)
    if effect in ('pull','push','backstep'):
        body=group(symbol,64,65,.75)
        body+=path('M8 42H35 M25 31 37 42 25 53 M120 42H93 M103 31 91 42 103 53' if effect=='pull' else 'M36 100H8 M19 89 7 100 19 111 M92 100H120 M109 89 121 100 109 111',width=4)
        return body
    if effect in ('fall','meteor'):
        body=group(symbol,75,76,.7)+path('M14 27 41 52 M26 11 55 40 M54 9 70 27',width=5)
        if effect=='meteor':body+=group(S['fire'],33,30,.46,-40)
        return body
    if effect=='crack':return group(symbol,64,37,.43)+path('M64 57 49 73 68 82 47 98 60 115 M49 73 23 84 M68 82 99 97 M15 108H35 M84 113H111',width=5)
    if effect=='tripod':return group(symbol,64,47,.69)+path('M64 78V104 M64 93 34 116 M64 93 94 116',width=6)
    if effect=='target':return group(symbol,62,56,.7)+'<ellipse cx="67" cy="105" rx="46" ry="13" fill="none" stroke="white" stroke-width="4"/>'+path('M67 88V121 M12 105H25 M109 105H122',width=3)
    if effect=='revive':return group(symbol,64,67,.7)+path('M14 105V32 M4 45 14 29 25 45 M114 105V32 M103 45 114 29 124 45',width=5)+ring
    if effect=='rune':return group(symbol,57,65,.86)+path('M96 25V80 M96 25 113 39 96 52 M96 55 112 68',width=4)
    if effect=='sharpen':return group(symbol,53,54,.8,28)+path('M42 103 87 79 113 89 68 116Z M76 81 82 100',width=4)
    if effect=='broken_shield':return group(S['shield'],77,76,.72)+group(symbol,39,40,.62,-15)+path('M74 59 63 78 81 84 69 105',width=5)
    if effect=='storm':return group(symbol,64,41,.85)+group(S['bolt'],46,92,.45)+group(S['bolt'],94,91,.34)
    if effect=='triple':return group(symbol,62,58,.79)+path('M17 102Q34 119 47 108 M51 109Q64 121 78 109 M84 108Q101 118 115 101',width=4)
    if effect=='coil':return group(symbol,64,40,.48)+path('M46 69H82 M39 80H89 M34 92H94 M30 106H98 M64 63V114',width=5)
    if effect=='fountain':return group(symbol,64,37,.55)+path('M19 112H109 M37 106Q10 59 37 56 M64 110V77 M90 106Q118 59 91 56',width=5)
    if effect=='fence':return group(symbol,64,62,.64)+path('M17 22V112 M111 22V112 M9 112H26 M102 112H120 M17 39H36 M93 89H111',width=6)
    raise ValueError(effect)

def write_icon(key,title,body):
    OUT.mkdir(parents=True,exist_ok=True)
    svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 128 128"><title>{html.escape(title)}</title>{body}</svg>\n'
    target=OUT/f'{key}.svg'
    if not target.exists() or target.read_text(encoding='utf-8')!=svg:
        target.write_text(svg,encoding='utf-8')

def main():
    data=json.loads((ROOT/'data/heroes_helden.json').read_text(encoding='utf-8'))
    count=0
    for hero in data['heroes']:
        for slot,ability in enumerate(hero['abilities']):
            recipe=('gear','chain') if hero['id']=='zix' else RECIPES[hero['id']][slot]
            write_icon(ability['id'],ability['name'],render(*recipe)); count+=1
    for key,gadget in data['gadgets'].items():
        write_icon('gadget_'+key,gadget['name'],render(*GADGETS[key])); count+=1
    write_icon('dodge','Ausweichen',render('person','dash')); count+=1
    print(f'{count} originale Vektor-Icons erzeugt: {OUT}')

if __name__=='__main__':main()
