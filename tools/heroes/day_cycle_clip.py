"""Beschriftet echte Godot-Frames; MP4-Encoding mit installiertem Blender, WebP-Vorschau mit Pillow."""
from pathlib import Path
import json
import sys

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / '.godot/bollwerk-day-cycle'
LABELED = SOURCE / 'labeled'
DEST = ROOT / 'export/videos'


def encode_blender():
    import bpy
    data = json.loads((SOURCE/'manifest.json').read_text(encoding='utf-8'))
    frames = sorted(LABELED.glob('frame-*.png'))
    assert len(frames) == data['frames'], 'Unvollständige beschriftete Aufnahme'
    scene = bpy.context.scene
    editor = scene.sequence_editor_create()
    strip = editor.strips.new_image('Bollwerk Tag Nacht', filepath=str(frames[0]), channel=1, frame_start=1)
    for frame in frames[1:]:
        strip.elements.append(frame.name)
    strip.duration = len(frames)
    scene.frame_start = 1
    scene.frame_end = len(frames)
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 944
    scene.render.resolution_percentage = 100
    scene.render.fps = 10
    scene.render.fps_base = 1
    scene.render.use_sequencer = True
    scene.view_settings.view_transform = 'Standard'
    scene.view_settings.exposure = 0
    scene.view_settings.gamma = 1
    scene.sequencer_colorspace_settings.name = 'sRGB'
    scene.render.image_settings.media_type = 'VIDEO'
    scene.render.image_settings.file_format = 'FFMPEG'
    scene.render.ffmpeg.format = 'MPEG4'
    scene.render.ffmpeg.codec = 'H264'
    scene.render.ffmpeg.constant_rate_factor = 'HIGH'
    scene.render.ffmpeg.ffmpeg_preset = 'GOOD'
    scene.render.ffmpeg.audio_codec = 'NONE'
    target = DEST/'bollwerk-tag-nacht-vier-orte.mp4'
    scene.render.filepath = str(target)
    bpy.ops.render.render(animation=True)
    assert target.exists() and target.stat().st_size > 100000
    clip = bpy.data.movieclips.load(str(target))
    assert clip.frame_duration == len(frames), (clip.frame_duration,len(frames))
    assert tuple(clip.size) == (1280,944), tuple(clip.size)
    print(f'VIDEO {target}: {clip.frame_duration} Frames, 24 Sekunden, {target.stat().st_size} Bytes')


def verify_blender():
    import bpy
    scene = bpy.context.scene
    scene.sequence_editor_create().strips.new_movie('Kontrolle',filepath=str(DEST/'bollwerk-tag-nacht-vier-orte.mp4'),channel=1,frame_start=1)
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 944
    scene.render.resolution_percentage = 100
    scene.render.fps = 10
    scene.render.fps_base = 1
    scene.render.use_sequencer = True
    scene.view_settings.view_transform = 'Standard'
    scene.sequencer_colorspace_settings.name = 'sRGB'
    scene.render.image_settings.media_type = 'IMAGE'
    scene.render.image_settings.file_format = 'PNG'
    for index in (40,170):
        scene.frame_set(index+1)
        scene.render.filepath = str(SOURCE/f'decoded-{index:04}.png')
        bpy.ops.render.render(write_still=True)
    print('VIDEO-PRUEFUNG: Tag- und Nachtframe erfolgreich aus MP4 dekodiert')


def prepare():
    from PIL import Image, ImageDraw, ImageFont, ImageStat
    data = json.loads((SOURCE/'manifest.json').read_text(encoding='utf-8'))
    paths = sorted(SOURCE.glob('frame-*.png'))
    assert len(paths) == data['frames'] == len(data['hours'])
    LABELED.mkdir(parents=True,exist_ok=True)
    DEST.mkdir(parents=True,exist_ok=True)
    title = ImageFont.truetype(str(ROOT/'assets/fonts/Cinzel-Bold.ttf'),24)
    text = ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',20)
    small = ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',17)
    previews = []
    means = []
    for index,path in enumerate(paths):
        hour = float(data['hours'][index])
        minute = round(hour*60) % 1440
        phase = 'Morgendämmerung' if 4.5<=hour<7.5 else ('Abenddämmerung' if 18<=hour<21 else ('Nacht' if hour<6 or hour>=19.3 else 'Tag'))
        with Image.open(path) as source:
            source = source.convert('RGB')
            means.append(sum(ImageStat.Stat(source.resize((64,40))).mean)/3)
            frame = Image.new('RGB',(1280,944),'#10151d')
            draw = ImageDraw.Draw(frame)
            draw.text((16,13),'BOLLWERK · TAG–NACHT-ZYKLUS',font=title,fill='#e2d1b1')
            draw.text((1264,15),f'{minute//60:02}:{minute%60:02} · {phase}',anchor='ra',font=text,fill='#e7edf4')
            for tile,name in enumerate(data['sites']):
                x,y = (tile%2)*640,56+(tile//2)*428
                draw.text((x+12,y+2),name,font=text,fill='#bdc8d5')
                frame.paste(source.crop((x,(tile//2)*400,x+640,(tile//2+1)*400)),(x,y+28))
            draw.text((16,918),'Zeitraffer · 22 Minuten Spielzyklus in 24 Sekunden · echte Spielgrafik',font=small,fill='#a5b1bf')
            draw.rectangle((0,52,1279,55),fill='#303c49')
            draw.rectangle((0,52,round(1279*index/(len(paths)-1)),55),fill='#bd9a5e')
            frame.save(LABELED/f'frame-{index:04}.png')
            if index%2==0:
                preview = frame.resize((960,708),Image.Resampling.LANCZOS)
                previews.append(preview)
            if index in [0,40,120,170]:
                frame.save(ROOT/'export/screens'/f'bollwerk-tag-nacht-{index:03}.jpg',quality=92)
    assert max(means)-min(means)>8, 'Keine sichtbare Tag-Nacht-Veränderung in den GPU-Frames'
    output = DEST/'bollwerk-tag-nacht-vier-orte.webp'
    previews[0].save(output,save_all=True,append_images=previews[1:],duration=data['duration_ms']*2,loop=0,quality=72,method=4)
    with Image.open(output) as result:
        assert result.is_animated and result.n_frames == len(previews)
    print(f'VORSCHAU {output}: {len(previews)} Frames, 24 Sekunden, {output.stat().st_size} Bytes')
    print(f'GPU-Aufnahme: {len(paths)} Frames, Helligkeit {min(means):.1f}–{max(means):.1f}, vier Standorte')


if __name__ == '__main__':
    verify_blender() if '--verify' in sys.argv else (encode_blender() if '--blender' in sys.argv else prepare())
