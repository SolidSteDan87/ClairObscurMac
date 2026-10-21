#!/bin/zsh
# Clair Obscur.app : premier lancement guidé (Rosetta, D3DMetal, Windows + Steam),
# puis lancement du jeu via coe. Les données du joueur vont dans
# ~/Library/Application Support/ClairObscurMac, jamais dans l'app.
CONTENTS=${0:A:h:h}
RES=$CONTENTS/Resources
COE=$RES/coe/coe
export COE_ROOT="$HOME/Library/Application Support/ClairObscurMac"
mkdir -p "$COE_ROOT/logs" "$COE_ROOT/config/profiles" "$COE_ROOT/dist"
exec >> "$COE_ROOT/logs/app.log" 2>&1
print "=== $(date) ==="

# COE_NO_DIALOG=1 : pas de fenêtres (tests automatiques), messages dans le journal
message() {
  [[ -n ${COE_NO_DIALOG:-} ]] && { print "MESSAGE : $1"; return 0 }
  osascript -e "display dialog \"$1\" buttons {\"OK\"} default button 1 with title \"Clair Obscur\" with icon note" >/dev/null 2>&1
}
erreur() {
  [[ -n ${COE_NO_DIALOG:-} ]] && { print "ERREUR : $1"; exit 1 }
  osascript -e "display dialog \"$1\" buttons {\"OK\"} default button 1 with title \"Clair Obscur\" with icon stop" >/dev/null 2>&1
  exit 1
}

# 1. Rosetta (Wine et le jeu sont des programmes Intel)
arch -x86_64 /usr/bin/true 2>/dev/null \
  || erreur "Rosetta est nécessaire.\n\nOuvre le Terminal et tape :\nsoftwareupdate --install-rosetta"

# 2. Copie modifiable de notre Wine (D3DMetal s'y ajoute), refaite à chaque nouvelle version
version=$(<$RES/VERSION)
if [[ $(cat "$COE_ROOT/dist/.version" 2>/dev/null) != $version ]]; then
  rm -rf "$COE_ROOT/dist/wine"
  cp -cR $RES/wine "$COE_ROOT/dist/wine" || erreur "Copie de Wine impossible (voir le journal)."
  # Fichiers copiés depuis l'app : on retire l'attribut « téléchargé d'Internet »,
  # sinon macOS bloquerait chaque bibliothèque de Wine une par une.
  xattr -dr com.apple.quarantine "$COE_ROOT/dist/wine" 2>/dev/null
  print -r -- $version > "$COE_ROOT/dist/.version"
  [[ -d $COE_ROOT/d3dmetal/redist/lib ]] && $COE install-d3dmetal "$COE_ROOT/d3dmetal"
fi
cp -f $RES/profiles/*.ini "$COE_ROOT/config/profiles/"
if [[ ! -f $COE_ROOT/config/coe.conf ]]; then
  # Profil par défaut selon la puissance du GPU : « air » pour les petits GPU
  # (MacBook Air, M1/M2/M3 de base), « beau » pour les Pro/Max.
  gpu_cores=$(system_profiler SPDisplaysDataType 2>/dev/null | awk -F': ' '/Total Number of Cores/{print $2; exit}')
  profil=beau; (( ${gpu_cores:-0} < 16 )) && profil=air
  print "GPU : ${gpu_cores:-?} cœurs -> profil $profil"
  sed -e "s/^WIN_USERNAME=.*/WIN_USERNAME=$USER/" -e "s/^DEFAULT_PROFILE=.*/DEFAULT_PROFILE=$profil/" \
    $RES/coe.conf.example > "$COE_ROOT/config/coe.conf"
  # Sur M1, le GPU ne peut pas faire tourner Nanite (pas d'atomiques 64 bits).
  if sysctl -n machdep.cpu.brand_string | grep -q "Apple M1"; then
    message "Ce Mac a une puce M1 : son GPU ne peut pas faire tourner Nanite.\n\nLe jeu marchera, mais une partie du décor sera très simplifiée (fleurs carrées, fenêtres sans cadre). C'est une limite de la puce, pas un bug de l'app."
  fi
fi

# 2b. Import d'une image chiffrée « ClairObscurPrive » préparée sur un autre de tes Mac
#     (scripts/preparer-transfert.sh) : jeu, sauvegardes, session Steam, D3DMetal.
IMP=/Volumes/ClairObscurPrive
GAME="Program Files (x86)/Steam/steamapps/common/Expedition 33"
if [[ -d $IMP/prefix && ! -d "$COE_ROOT/prefix/drive_c/$GAME" ]]; then
  message "Image « ClairObscurPrive » détectée : import du jeu, de tes sauvegardes et de ta session Steam. Environ 10 minutes pour 45 Go, ne ferme pas l'app."
  # Un environnement sans le jeu (ex. Steam neuf installé avant d'ouvrir l'image) est mis de côté
  if [[ -d $COE_ROOT/prefix ]]; then
    $COE kill >/dev/null 2>&1
    mv "$COE_ROOT/prefix" "$COE_ROOT/prefix-sans-jeu-$(date +%Y%m%d-%H%M%S)"
  fi
  rsync -a "$IMP/prefix/" "$COE_ROOT/prefix/" || erreur "Import impossible (voir le journal)."
  w=$(grep '^WIN_USERNAME=' $IMP/config/coe.conf 2>/dev/null)
  [[ -n $w ]] && sed -i '' "s/^WIN_USERNAME=.*/$w/" "$COE_ROOT/config/coe.conf"
  if [[ -d $IMP/d3dmetal/redist/lib && ! -d $COE_ROOT/dist/wine/lib/external/D3DMetal.framework ]]; then
    $COE install-d3dmetal "$IMP/d3dmetal" || erreur "Installation de D3DMetal impossible (voir le journal)."
  fi
  message "Import terminé. Tu peux éjecter l'image « ClairObscurPrive », puis la supprimer de la clé : elle contient ta session Steam."
fi

# 3. D3DMetal d'Apple : pas redistribuable, chacun le télécharge chez Apple
if [[ ! -d $COE_ROOT/dist/wine/lib/external/D3DMetal.framework ]]; then
  message "Il faut le traducteur D3DMetal d'Apple (gratuit, identifiant Apple requis).\n\n1. Sur la page qui va s'ouvrir, télécharge « Evaluation environment for Windows games 4 ».\n2. Reviens ici, clique sur OK et choisis ce fichier .dmg."
  open "https://developer.apple.com/download/all/?q=game%20porting%20toolkit"
  f=$(osascript -e 'POSIX path of (choose file with prompt "Choisis le fichier .dmg du Game Porting Toolkit d'"'"'Apple" of type {"dmg", "com.apple.disk-image-udif"})' 2>/dev/null) || exit 0
  $COE install-d3dmetal "$f" || erreur "Installation de D3DMetal impossible (voir le journal)."
fi

# 4. Environnement Windows + Steam
if [[ ! -f "$COE_ROOT/prefix/drive_c/Program Files (x86)/Steam/steam.exe" ]]; then
  message "Création de l'environnement Windows et installation de Steam : quelques minutes.\n\nEnsuite, connecte-toi à Steam et installe Clair Obscur: Expedition 33, puis relance cette app."
  $COE setup || erreur "Installation impossible (voir le journal)."
fi

# COE_TEST=1 : test automatique, on s'arrête avant d'ouvrir Steam ou le jeu
[[ -n ${COE_TEST:-} ]] && { print "TEST : installation terminée"; exit 0 }

# 5. Jeu pas encore installé : Steam seul ; sinon le jeu
if [[ ! -d "$COE_ROOT/prefix/drive_c/Program Files (x86)/Steam/steamapps/common/Expedition 33" ]]; then
  exec $COE steam
fi
exec $COE play "$@"
