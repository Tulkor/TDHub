#!/usr/bin/env python3
"""Windows-Exportvorlage für den vorhandenen Build-Ablauf installieren (isoliertes APPDATA)."""
import os
from pathlib import Path
import time
import urllib.request
import zipfile

VERSION = "4.3"
ROOT = Path(__file__).resolve().parents[1]


def main():
    target = Path(os.environ["APPDATA"]) / "Godot/export_templates" / f"{VERSION}.stable"
    if (target / "windows_release_x86_64.exe").is_file():
        print("Windows-Exportvorlage: vorhanden", flush=True)
        return
    archive = ROOT / ".godot" / f"Godot_v{VERSION}-templates.tpz"
    archive.parent.mkdir(parents=True, exist_ok=True)
    if not archive.is_file() or not zipfile.is_zipfile(archive):
        url = f"https://github.com/godotengine/godot/releases/download/{VERSION}-stable/Godot_v{VERSION}-stable_export_templates.tpz"
        request = urllib.request.Request(url, headers={"User-Agent": "TDHub-build"})
        print("Windows-Exportvorlage: Download von Godot/GitHub", flush=True)
        with urllib.request.urlopen(request, timeout=60) as response, archive.open("wb") as out:
            size = 0
            reported = time.monotonic()
            while block := response.read(4 * 1024 * 1024):
                out.write(block)
                size += len(block)
                if time.monotonic() - reported > 15:
                    print(f"Vorlagen-Download: {size // 1048576} MiB", flush=True)
                    reported = time.monotonic()
    target.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive) as bundle:
        for item in bundle.infolist():
            name = Path(item.filename).name
            if name in {"windows_release_x86_64.exe", "version.txt"}:
                (target / name).write_bytes(bundle.read(item))
    if not (target / "windows_release_x86_64.exe").is_file():
        raise RuntimeError("Windows-Exportvorlage fehlt im Godot-Archiv")
    print(f"Windows-Exportvorlage: {target}", flush=True)


if __name__ == "__main__":
    main()
