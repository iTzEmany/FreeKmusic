#!/usr/bin/env bash
# AppImage: bundle release + libmpv e le sue dipendenze (build/freekmusic-<versione>-x86_64.AppImage).
# Prerequisiti: flutter build linux --release, libmpv2 installata sul sistema che costruisce.
# Usa appimagetool scaricato in build/tools (o nel PATH). Non richiede privilegi.
set -euo pipefail
cd "$(dirname "$0")/.."
bundle=build/linux/x64/release/bundle
[ -x "$bundle/freekmusic" ] || { echo "Esegui prima: flutter build linux --release" >&2; exit 1; }
version=$(sed -n 's/^version:[[:space:]]*\([0-9.]*\).*/\1/p' pubspec.yaml | head -1)
tool=${APPIMAGETOOL:-build/tools/appimagetool}
if [ ! -x "$tool" ]; then
  mkdir -p build/tools
  curl -sL -o build/tools/appimagetool https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage
  chmod +x build/tools/appimagetool
  tool=build/tools/appimagetool
fi

rm -rf build/FreeKmusic.AppDir
mkdir -p build/FreeKmusic.AppDir/usr/lib
cp -r "$bundle" build/FreeKmusic.AppDir/usr/freekmusic
cp assets/icon/icon.png build/FreeKmusic.AppDir/freekmusic.png
sed 's|@EXEC@|freekmusic|' packaging/linux/freekmusic.desktop > build/FreeKmusic.AppDir/freekmusic.desktop

# libmpv and what it needs, except what every desktop has (glibc, X11, GL, ...):
# the AppImage excludelist, abridged.
skip='^(libc|libm|libdl|libpthread|librt|libresolv|libutil|ld-linux|libGL|libEGL|libGLX|libGLdispatch|libOpenGL|libX11|libxcb|libXext|libXrender|libXau|libXdmcp|libdrm|libgbm|libwayland|libasound|libpulse|libgtk|libgdk|libglib|libgobject|libgio|libgmodule|libpango|libcairo|libatk|libharfbuzz|libfontconfig|libfreetype|libstdc\+\+|libgcc_s|libz)\.'
mpv=$(ldconfig -p | awk '/libmpv\.so\.2 /{print $NF; exit}')
[ -n "$mpv" ] || { echo "libmpv.so.2 non trovata: installa il pacchetto libmpv2 (solo per costruire)" >&2; exit 1; }
cp -L "$mpv" build/FreeKmusic.AppDir/usr/lib/
ldd "$mpv" | awk '/=> \//{print $3}' | while read -r lib; do
  name=$(basename "$lib")
  if ! [[ "$name" =~ $skip ]]; then cp -L -n "$lib" build/FreeKmusic.AppDir/usr/lib/ || true; fi
done

cat > build/FreeKmusic.AppDir/AppRun <<'RUN'
#!/bin/sh
here="$(dirname "$(readlink -f "$0")")"
export LD_LIBRARY_PATH="$here/usr/lib:$here/usr/freekmusic/lib:${LD_LIBRARY_PATH:-}"
exec "$here/usr/freekmusic/freekmusic" "$@"
RUN
chmod +x build/FreeKmusic.AppDir/AppRun

out="build/freekmusic-$version-x86_64.AppImage"
ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 "$tool" build/FreeKmusic.AppDir "$out" >/dev/null
echo "$out"
