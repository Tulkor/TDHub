"""Pack attack_probe's real GPU frames as silent, looping animated WebPs (Pillow)."""
from pathlib import Path
import argparse
import json
from PIL import Image, ImageChops, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]


def comparison(hero, previous, destination):
    """Compare captures at identical times, with readable before/after labels."""
    folders=[ROOT/'.godot/hero-attacks'/previous,ROOT/'.godot/hero-attacks'/f'{hero}-combo']
    paths=[sorted(folder.glob('frame-*.png')) for folder in folders]
    if len(paths[0])<2 or len(paths[0])!=len(paths[1]):
        raise SystemExit('Comparison needs equally long captures at the same frame rate')
    frames=[]
    try:font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',26)
    except OSError:font=ImageFont.load_default(size=26)
    for pair in zip(*paths):
        frame=Image.new('RGB',(1440,760),'#101824')
        draw=ImageDraw.Draw(frame)
        for index,path in enumerate(pair):
            with Image.open(path) as source:
                frame.paste(source.convert('RGB').resize((720,720),Image.Resampling.LANCZOS),(index*720,40))
            draw.text((index*720+18,8),'VORHER' if index==0 else 'NEU: Schulterbewegung und Oberkoerper',font=font,fill='white')
        frames.append(frame)
    target=destination/f'bollwerk-{hero}-vergleich.webp'
    frames[0].save(target,save_all=True,append_images=frames[1:],duration=50,loop=0,quality=88,method=3)
    with Image.open(target) as result:
        if not result.is_animated or result.n_frames!=len(frames):raise SystemExit('Invalid comparison')
        print(f'{target}: {result.n_frames} frames')


def contacts(heroes=None):
    heroes=heroes or [h['id'] for h in json.loads((ROOT/'data/heroes_helden.json').read_text())['heroes'] if h['id']!='mira']
    destination=ROOT/'export/screens'
    destination.mkdir(parents=True,exist_ok=True)
    font=ImageFont.load_default(size=20)
    for start in range(0,len(heroes),6):
        subset=heroes[start:start+6]
        sheet=Image.new('RGB',(1920,len(subset)*264),'#101824')
        draw=ImageDraw.Draw(sheet)
        for row,hero in enumerate(subset):
            folder=ROOT/'.godot/hero-attacks'/f'{hero}-combo'
            if not folder.is_dir():folder=folder.parent/hero
            paths=sorted(folder.glob('frame-*.png'))
            if not paths:raise SystemExit(f'No capture for {hero}')
            draw.text((8,row*264+2),hero,font=font,fill='white')
            for col,fraction in enumerate((.08,.19,.27,.42,.52,.63,.76,.87)):
                with Image.open(paths[round((len(paths)-1)*fraction)]) as source:
                    sheet.paste(source.convert('RGB').resize((240,240),Image.Resampling.LANCZOS),(col*240,row*264+24))
        path=destination/f'bollwerk-waffen-kontakt-{start//6+1:02}.png'
        sheet.save(path)
        print(path)


def gallery(clip, destination, heroes=None, ready=False):
    custom=heroes is not None
    heroes = heroes or ['torvik', 'unrat', 'vesna', 'zix']
    strips = []
    for hero in heroes:
        folder = hero + '-' + clip if clip else hero + ('-combo' if (ROOT/'.godot/hero-attacks'/f'{hero}-combo').is_dir() else '')
        paths = sorted((ROOT / '.godot/hero-attacks' / folder).glob('frame-*.png'))
        if len(paths) < 2:
            raise SystemExit(f'{folder}: missing GPU capture')
        strip = []
        for path in paths:
            with Image.open(path) as source:
                strip.append(source.convert('RGB').resize((480,480),Image.Resampling.LANCZOS))
        if ready:
            prefix=[]
            for path in sorted((ROOT/'.godot/hero-attacks'/f'{hero}-idle').glob('frame-*.png'))[:10]:
                with Image.open(path) as source:prefix.append(source.convert('RGB').resize((480,480),Image.Resampling.LANCZOS))
            if len(prefix)!=10:raise SystemExit(f'{hero}: missing ready-state capture')
            strip=prefix+strip
        if all(ImageChops.difference(strip[0], frame).getbbox() is None for frame in strip[1:]):
            raise SystemExit(f'{folder}: animation is static')
        strips.append(strip)
    frames = []
    for index in range(max(map(len,strips))):
        frame = Image.new('RGB',(960,480*((len(heroes)+1)//2)))
        for tile,strip in enumerate(strips):
            frame.paste(strip[index % len(strip)],((tile % 2)*480,(tile // 2)*480))
        frames.append(frame)
    target = destination / f'bollwerk-helden-{"waffen" if custom else "fluid"}-{"bereit-" if ready else ""}{clip or "angriffe"}.webp'
    frames[0].save(target,save_all=True,append_images=frames[1:],duration=50,loop=0,quality=85,method=3)
    with Image.open(target) as result:
        if not result.is_animated or result.n_frames != len(frames):
            raise SystemExit('Invalid gallery output')
        print(f'{target}: {result.n_frames} frames, {target.stat().st_size} bytes')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--torvik-variants', action='store_true')
    parser.add_argument('--held',help='Helden-ID aus data/heroes_helden.json')
    parser.add_argument('--schlaege',type=int,default=0)
    parser.add_argument('--combo',action='store_true')
    parser.add_argument('--clip',help='Name des importierten Animationsclips')
    parser.add_argument('--galerie',action='store_true')
    parser.add_argument('--helden',help='Kommagetrennte Helden für die Galerie')
    parser.add_argument('--kontakt',action='store_true',help='Statische Prüfbögen der Angriffsübergänge')
    parser.add_argument('--bereit',action='store_true',help='Galerie mit einer halben Sekunde Bereitschaft beginnen')
    parser.add_argument('--vergleich',help='Vorher-Aufnahmeordner; benötigt --held und aktuelle Kombo-Aufnahme')
    args = parser.parse_args()
    destination = ROOT / 'export/videos'
    destination.mkdir(parents=True, exist_ok=True)
    if args.vergleich:
        if not args.held:parser.error('--vergleich benötigt --held')
        comparison(args.held,args.vergleich,destination)
        return
    if args.kontakt:
        contacts(args.helden.split(',') if args.helden else None)
        return
    if args.galerie:
        gallery(args.clip,destination,args.helden.split(',') if args.helden else None,args.bereit)
        return
    heroes = ['torvik-attack_cleave', 'torvik-attack_dual_strike', 'torvik-attack_overhead'] if args.torvik_variants else ['torvik', 'unrat', 'vesna', 'zix']
    if args.held:heroes=[args.held+f'-{args.schlaege}-schlaege' if args.schlaege else args.held]
    if args.combo and args.held:heroes=[args.held+'-combo']
    if args.clip:heroes=[hero+'-'+args.clip for hero in heroes]
    for hero in heroes:
        paths = sorted((ROOT / '.godot/hero-attacks' / hero).glob('frame-*.png'))
        if (not args.schlaege and not args.combo and len(paths) != 80) or len(paths)<2:
            raise SystemExit(f'{hero}: expected 80 GPU frames, got {len(paths)}')
        frames = []
        for path in paths:
            with Image.open(path) as source:
                frames.append(source.convert('RGB'))
        if all(ImageChops.difference(frames[0], frame).getbbox() is None for frame in frames[1:]):
            raise SystemExit(f'{hero}: animation is static')
        target = destination / f'bollwerk-{hero}-angriff.webp'
        frames[0].save(target, save_all=True, append_images=frames[1:], duration=50,
                       loop=0, quality=85, method=3)
        with Image.open(target) as result:
            if not result.is_animated or result.n_frames < 2:
                raise SystemExit(f'{hero}: invalid animated output')
            print(f'{hero}: {result.n_frames} frames, {result.size}, {target.stat().st_size} bytes')
        for frame in frames:
            frame.close()


if __name__ == '__main__':
    main()
