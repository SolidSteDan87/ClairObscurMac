#!/bin/zsh
# À lancer sur le Mac où le jeu tourne déjà : met l'environnement Windows (Steam, jeu,
# sauvegardes, session Steam), le réglage du nom d'utilisateur et D3DMetal dans une image
# disque CHIFFRÉE sur un disque externe. Sur l'autre Mac : double-clic sur l'image
# (mot de passe), puis lancer « Clair Obscur.app » : elle importe tout.
#   scripts/preparer-transfert.sh /Volumes/<disque>
# Le mot de passe est tapé par toi dans le Terminal ; il n'est écrit nulle part.
set -euo pipefail

ROOT=${0:A:h:h}
vol=${1:?usage : preparer-transfert.sh /Volumes/<disque>}
[[ -d $vol ]] || { print "Disque introuvable : $vol" >&2; exit 1 }
if pgrep -f "$ROOT/dist/wine/" >/dev/null; then
  print "Ferme le jeu et Steam d'abord : $ROOT/scripts/coe kill" >&2; exit 1
fi

img=$vol/ClairObscurPrive.sparsebundle
[[ -e $img ]] && { print "$img existe déjà : supprime-le ou choisis un autre disque." >&2; exit 1 }
need=$(( $(du -sk $ROOT/prefix | cut -f1) / 1048576 + 3 ))
free=$(( $(df -k "$vol" | awk 'NR==2{print $4}') / 1048576 ))
print "Nécessaire ~${need} Go, libre ${free} Go sur $vol"
(( free > need )) || { print "Pas assez de place." >&2; exit 1 }

print "\n1/2  Choisis un mot de passe pour chiffrer l'image (demandé deux fois) :"
hdiutil create -size $(( need + 5 ))g -type SPARSEBUNDLE -fs APFS -encryption AES-256 \
  -volname ClairObscurPrive "$img" >/dev/null
print "\n2/2  Tape-le encore une fois pour ouvrir l'image :"
dest=$(hdiutil attach -nobrowse "$img" | awk -F'\t' '/\/Volumes\//{print $NF}' | tail -1)

print "Copie de l'environnement Windows (jeu, Steam, sauvegardes)..."
rsync -a $ROOT/prefix/ "$dest/prefix/"

# Nom d'utilisateur Windows : nécessaire pour que la session Steam reste valide.
mkdir -p "$dest/config"
grep -v '^IMPORT_PREFIX=' $ROOT/config/coe.conf > "$dest/config/coe.conf"

# D3DMetal tel qu'installé ici, remis au format « redist » d'Apple.
L=$ROOT/dist/wine/lib
if [[ -d $L/external/D3DMetal.framework ]]; then
  r="$dest/d3dmetal/redist/lib"
  mkdir -p $r/wine/x86_64-unix $r/wine/x86_64-windows
  ditto $L/external $r/external
  for m in d3d10 d3d11 d3d12 d3d12core dxgi nvapi64 nvngx; do
    [[ -L $L/wine/x86_64-unix/$m.so ]] && cp -P $L/wine/x86_64-unix/$m.so $r/wine/x86_64-unix/
    [[ -f $L/wine/x86_64-windows/$m.dll ]] && cp $L/wine/x86_64-windows/$m.dll $r/wine/x86_64-windows/
  done
fi

du -sh "$dest"
hdiutil detach -quiet "$dest"
print "\nTerminé : $img (chiffré). Sur l'autre Mac : double-clic dessus, mot de passe,"
print "puis lance « Clair Obscur.app ». Après l'import, supprime l'image de la clé."
