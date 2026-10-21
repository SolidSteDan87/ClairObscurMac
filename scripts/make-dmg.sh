#!/bin/zsh
# Fabrique le DMG à partager : dist/ClairObscurMac-<version>.dmg
#   « Clair Obscur.app » (notre Wine + lanceur), Lisez-moi, sources et licences.
# Aucun fichier d'Apple (D3DMetal), du jeu, de Steam ni donnée personnelle.
# Usage : scripts/make-dmg.sh [version]
set -euo pipefail

ROOT=${0:A:h:h}
VERSION=${1:-1.0}
STAGE=$ROOT/build/dmg
APP="$STAGE/Clair Obscur.app"
RES="$APP/Contents/Resources"
OUT=$ROOT/dist/ClairObscurMac-$VERSION.dmg

step() { print -P "%F{cyan}==> $1%f" }

rm -rf $STAGE
mkdir -p "$APP/Contents/MacOS" "$RES/coe" "$RES/profiles"

step "Wine, sans D3DMetal"
cp -cR $ROOT/dist/wine "$RES/wine"
W="$RES/wine/lib"
rm -rf $W/external
for so in d3d10 d3d11 d3d12 d3d12core dxgi nvapi64 nvngx; do rm -f $W/wine/x86_64-unix/$so.so; done
rm -f $W/wine/x86_64-windows/nvapi64.dll $W/wine/x86_64-windows/nvngx.dll
if [[ -d $W/wine/builtin-backup ]]; then
  cp -f $W/wine/builtin-backup/*.dll $W/wine/x86_64-windows/
  rm -rf $W/wine/builtin-backup
fi
# Contrôle : aucun fichier d'Apple, et les DLL graphiques sont bien celles de Wine
if find "$RES/wine" \( -iname "*D3DMetal*" -o -iname "libd3dshared*" \) | grep -q .; then
  print "Fichier D3DMetal trouvé dans l'app : arrêt." >&2; exit 1
fi
for dll in d3d10 d3d11 d3d12 d3d12core dxgi; do
  grep -q "Wine builtin DLL" $W/wine/x86_64-windows/$dll.dll \
    || { print "$dll.dll n'est pas celle de Wine : arrêt." >&2; exit 1 }
done

step "Lanceur et profils"
cp $ROOT/scripts/coe "$RES/coe/coe"
cp $ROOT/config/profiles/{beau,fluide,fps-max,air,equilibre,vanilla}.ini "$RES/profiles/"
cp $ROOT/config/coe.conf.example "$RES/coe.conf.example"
print -r -- "$VERSION (Wine 11.0, sources CrossOver 26.3.0)" > "$RES/VERSION"
cp $ROOT/packaging/launcher.zsh "$APP/Contents/MacOS/ClairObscur"
chmod +x "$APP/Contents/MacOS/ClairObscur" "$RES/coe/coe"
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Clair Obscur</string>
  <key>CFBundleDisplayName</key><string>Clair Obscur</string>
  <key>CFBundleIdentifier</key><string>local.clairobscurmac.app</string>
  <key>CFBundleExecutable</key><string>ClairObscur</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSArchitecturePriority</key><array><string>arm64</string></array>
  <key>LSUIElement</key><true/>
</dict>
</plist>
EOF
codesign --force --deep -s - "$APP" 2>/dev/null

step "Contenu du DMG"
ln -s /Applications "$STAGE/Applications"
cp $ROOT/packaging/Lisez-moi.txt $ROOT/packaging/Sources-et-licences.txt "$STAGE/"
cp -R $ROOT/patches "$STAGE/Sources (correctifs Wine)"

step "Création de $OUT"
mkdir -p ${OUT:h}
hdiutil create -volname "Clair Obscur" -srcfolder "$STAGE" -ov -format ULFO "$OUT" >/dev/null
print "Taille  : $(du -h "$OUT" | cut -f1)"
print "SHA-256 : $(shasum -a 256 "$OUT" | cut -d' ' -f1)"
