"""Build an inline annotation canvas from a real screenshot. Requires Pillow.

python tools/review/bildmarkierung.py IMAGE OUTPUT.html
The output is a fragment for the chat's visualize surface, not a standalone page.
"""
import argparse
import base64
import io
import json
from pathlib import Path
from PIL import Image, ImageOps


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('image', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    with Image.open(args.image) as original:
        image = ImageOps.exif_transpose(original).convert('RGB')
        image.thumbnail((1536, 1152), Image.Resampling.LANCZOS)
        buffer = io.BytesIO()
        image.save(buffer, 'JPEG', quality=78, optimize=True)
    uri = 'data:image/jpeg;base64,' + base64.b64encode(buffer.getvalue()).decode('ascii')
    fragment = Path(__file__).with_suffix('.html').read_text(encoding='utf-8')
    fragment = fragment.replace('__TD_IMAGE_DATA__', uri)
    fragment = fragment.replace('__TD_SOURCE__', json.dumps(str(args.image.resolve()).replace('\\', '/'), ensure_ascii=True).replace('</', '<\\/'))
    if len(fragment.encode('utf-8')) > 1_000_000:
        raise SystemExit('Bild zu groß für die Inline-Vorschau.')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(fragment, encoding='utf-8')
    print(f'Bildmarkierung: {args.output} ({len(fragment.encode("utf-8"))} Bytes)')


if __name__ == '__main__':
    main()
