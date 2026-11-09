#!/usr/bin/env bash
# Installiert Godot 4.3 (Linux, headless nutzbar) und die Windows-Exportvorlage,
# falls sie noch fehlen. Läuft in wenigen Sekunden durch, wenn alles schon da ist.
# Aufruf: tools/setup_godot.sh            (Godot + Windows-Vorlage)
#         tools/setup_godot.sh --ohne-vorlage   (nur Godot, z. B. nur für Tests)
set -euo pipefail

VERSION="4.3"
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    [ -n "${GODOT:-}" ] && [ -f "$GODOT" ] || { echo "Windows: GODOT auf die vorhandene Godot.exe setzen (tools/windows.ps1)."; exit 2; }
    if [ "${1:-}" != "--ohne-vorlage" ]; then python3 tools/windows_templates.py; fi
    exit 0 ;;
esac
BIN_DIR="${HOME}/.local/bin"
GODOT="${BIN_DIR}/godot"
TPL_DIR="${HOME}/.local/share/godot/export_templates/${VERSION}.stable"
URL="https://github.com/godotengine/godot/releases/download/${VERSION}-stable"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$BIN_DIR"
if [ -x "$GODOT" ] && "$GODOT" --version 2>/dev/null | grep -q "^${VERSION}"; then
  echo "Godot ${VERSION}: vorhanden"
else
  echo "Godot ${VERSION}: lade herunter ..."
  curl -fsSL -o "$TMP/godot.zip" "${URL}/Godot_v${VERSION}-stable_linux.x86_64.zip"
  python3 -c "import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$TMP/godot.zip" "$TMP"
  mv "$TMP/Godot_v${VERSION}-stable_linux.x86_64" "$GODOT"
  chmod +x "$GODOT"
  echo "Godot ${VERSION}: installiert nach $GODOT"
fi

if [ "${1:-}" = "--ohne-vorlage" ]; then exit 0; fi

if [ -f "$TPL_DIR/windows_release_x86_64.exe" ]; then
  echo "Windows-Exportvorlage: vorhanden"
else
  echo "Windows-Exportvorlage: lade herunter (ca. 1 GB) ..."
  curl -fsSL -o "$TMP/tpl.tpz" "${URL}/Godot_v${VERSION}-stable_export_templates.tpz"
  mkdir -p "$TPL_DIR"
  # Nur die Dateien für Windows auspacken, der Rest wird nicht gebraucht.
  python3 - "$TMP/tpl.tpz" "$TPL_DIR" <<'PY'
import sys, zipfile, os
z = zipfile.ZipFile(sys.argv[1])
for n in z.namelist():
    b = os.path.basename(n)
    if b.startswith("windows_") or b == "version.txt":
        with open(os.path.join(sys.argv[2], b), "wb") as f:
            f.write(z.read(n))
PY
  echo "Windows-Exportvorlage: installiert nach $TPL_DIR"
fi
