#!/bin/zsh
# Instala la app "Seraf Acuerdos" en Aplicaciones (y repara el ayudante de PDF del comando acuerdo).
B=https://raw.githubusercontent.com/jhoinner-barboza20/jhoinner/refs/heads/claude/stoic-bell-83qiq8
DEST=/Applications; [ -w /Applications ] || { DEST=$HOME/Applications; mkdir -p $DEST; }
APP="$DEST/Seraf Acuerdos.app"
T=$(mktemp -d)
echo "1/3 Descargando..."
for f in herramientas/app/SerafAcuerdos.swift herramientas/app/Info.plist herramientas/app/AppIcon.icns herramientas/acuerdo_plantilla.html herramientas/app/htmlpdf.swift; do
  curl -fsSL "$B/$f" -o "$T/${f:t}" || { echo "No pude descargar ${f:t}. Revisa internet y vuelve a probar."; exit 1; }
done
curl -fsSL "$B/canal/logo/seraf_logo.png" -o "$T/logo.png" || exit 1
echo "2/3 Compilando la app (1-2 minutos)..."
swiftc -O -parse-as-library -target arm64-apple-macos13.0 "$T/SerafAcuerdos.swift" -o "$T/SerafAcuerdos" || { echo "❌ Error compilando la app. Mándale foto a Claude."; exit 1; }
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
mv "$T/SerafAcuerdos" "$APP/Contents/MacOS/"
cp "$T/Info.plist" "$APP/Contents/"
cp "$T/AppIcon.icns" "$T/acuerdo_plantilla.html" "$T/logo.png" "$APP/Contents/Resources/"
codesign --force --deep -s - "$APP" >/dev/null 2>&1
echo "3/3 Reparando el ayudante del comando acuerdo..."
mkdir -p ~/clipstools && cp "$T/htmlpdf.swift" "$T/acuerdo_plantilla.html" ~/clipstools/
swiftc -O -parse-as-library ~/clipstools/htmlpdf.swift -o ~/clipstools/htmlpdf >/dev/null 2>&1 || echo "(el ayudante del comando acuerdo no compiló; la app funciona igual)"
rm -rf "$T"
echo "✅ Seraf Acuerdos instalada en ${DEST:t}"
open "$APP"
