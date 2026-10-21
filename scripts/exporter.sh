#!/bin/zsh
# Copie l'installation (Wine, D3DMetal, prefix avec Steam + jeu + sauvegardes,
# lanceur) vers un disque externe, pour la réinstaller sur un autre Mac.
#   scripts/exporter.sh /Volumes/MonDisque
# Sur un disque non Mac (exFAT, FAT...), qui casserait les liens symboliques de
# Wine, la copie se fait dans une image disque APFS créée sur le disque.
set -euo pipefail

ROOT=${0:A:h:h}
vol=${1:?usage : exporter.sh /Volumes/<disque>}
[[ -d $vol ]] || { print "Disque introuvable : $vol" >&2; exit 1 }

# Ne jamais copier un prefix en cours d'utilisation.
if pgrep -f 'Steam\\steam.exe|SandFall-Win64-Shipping' >/dev/null; then
  print "Ferme le jeu et Steam d'abord (scripts/coe kill)." >&2; exit 1
fi

fs=$(diskutil info "$vol" | awk -F': *' '/Type \(Bundle\)/{print $2}')
need_gb=$(( $(du -sk $ROOT/dist $ROOT/prefix | awk '{s+=$1} END {print s}') / 1048576 + 5 ))
free_gb=$(( $(df -k "$vol" | awk 'NR==2{print $4}') / 1048576 ))
print "Disque : $vol ($fs), libre ${free_gb} Go, nécessaire ~${need_gb} Go"
(( free_gb >= need_gb )) || { print "Pas assez de place." >&2; exit 1 }

dest=$vol/ClairObscurMac
if [[ $fs != apfs && $fs != hfs ]]; then
  img=$vol/ClairObscurMac.sparsebundle
  [[ -d $img ]] || hdiutil create -size $(( need_gb + 10 ))g -type SPARSEBUNDLE -fs APFS \
    -volname ClairObscurMac "$img" >/dev/null
  dest=$(hdiutil attach -nobrowse "$img" | awk -F'\t' '/\/Volumes\//{print $NF}' | tail -1)
  print "Image disque APFS montée : $dest"
fi

mkdir -p $dest
for part in dist prefix scripts config patches "Clair Obscur.app"; do
  print "==> $part"
  rsync -a --delete $ROOT/$part/ $dest/$part/
done
du -sh $dest
print "Copie terminée dans $dest"
