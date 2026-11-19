"""Eight symmetric Bollwerk lanes: longer approaches, shallow bends, paired shared tails.

Edit WEST once, then --apply; --check checks the shipped layout without writing.
"""
import argparse
import json
import math
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
WEST = [[-170,30],[-146,32],[-122,40],[-103,40],[-88,28],[-84,16],[-72,0],[-52,0],[-30,1],[-7,0]]
BOUNDS = [-192,-192,192,192]
SIDES = {'west':0,'nord':1,'ost':2,'sued':3}


def points(pair, side):
    result = []
    for index,(x,z) in enumerate(WEST):
        # Mirror only the separate approach; both lanes share the exact inner road.
        if index < 6:z *= side
        for _ in range(SIDES[pair]):
            x,z = -z,x
        result.append([x,z])
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--apply',action='store_true')
    mode.add_argument('--check',action='store_true')
    args = parser.parse_args()
    path = ROOT/'data/heroes.json'
    raw = path.read_text(encoding='utf-8')
    data = json.loads(raw)
    roads = data['arena']['roads']
    expected = [dict(r,points=points(r['pair'],int(r['gate_side']))) for r in roads]
    if args.apply:
        raw,count = re.subn(r'(?m)^(\s*)"roads":.*$',lambda m:m[1]+'"roads": '+json.dumps(expected,ensure_ascii=False,separators=(',',':'))+',',raw,count=1)
        if count != 1:raise SystemExit('Expected one compact arena.roads line')
        raw,count = re.subn(r'"bounds":\s*\[[^\]]*\]',lambda _: '"bounds": '+json.dumps(BOUNDS),raw,count=1)
        if count != 1:raise SystemExit('Expected arena bounds')
        path.write_text(raw,encoding='utf-8')
    elif roads != expected or data['arena']['bounds'] != BOUNDS:
        raise SystemExit('FAIL lane layout differs; edit WEST and use --apply')
    length = sum(math.dist(a,b) for a,b in zip(WEST,WEST[1:]))
    print(f'Bollwerk lanes: {len(roads)} routes, {length:.1f} m each, paired common tail, bounds {BOUNDS}')


if __name__=='__main__':main()
