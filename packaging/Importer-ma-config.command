#!/bin/zsh
# Importer ma config Clair Obscur — à lancer sur le Mac qui reçoit le jeu.
# Trouve l'image chiffrée « ClairObscurPrive » (créée par preparer-transfert.sh sur ton
# autre Mac), l'ouvre (mot de passe demandé ici même), importe le jeu, tes sauvegardes,
# ta session Steam et D3DMetal dans l'app « Clair Obscur », puis lance le jeu.
# Aucun mot de passe n'est enregistré nulle part.
set -u

APP=${COE_APP:-"/Applications/Clair Obscur.app"}   # COE_APP : pour les tests
COE="$APP/Contents/Resources/coe/coe"
export COE_ROOT="$HOME/Library/Application Support/ClairObscurMac"
GAME="Program Files (x86)/Steam/steamapps/common/Expedition 33"

titre() { print -P "\n%F{cyan}%B$1%b%f" }
ok()    { print -P "%F{green}✓%f $1" }
stop()  { print -P "\n%F{red}✗ $1%f"; print "\nAppuie sur Entrée pour fermer."; [[ -n ${COE_TEST:-} ]] || read; exit 1 }

clear
print -P "%B Clair Obscur : import de ta config%b\n"

# 1. L'app doit être installée
titre "1/5  App « Clair Obscur »"
[[ -x $COE ]] || stop "L'app n'est pas dans Applications : ouvre le DMG et glisse « Clair Obscur » dans Applications."
ok "trouvée"

# 2. Trouver et ouvrir l'image chiffrée
titre "2/5  Image ClairObscurPrive"
IMP=/Volumes/ClairObscurPrive
if [[ ! -d $IMP/prefix ]]; then
  img=""
  for d in ~/Downloads ~/Desktop ~/Documents /Volumes/*; do
    [[ -d $d/ClairObscurPrive.sparsebundle ]] && { img=$d/ClairObscurPrive.sparsebundle; break }
  done
  [[ -n $img ]] || stop "ClairObscurPrive.sparsebundle introuvable (Téléchargements, Bureau, Documents ou clé USB)."
  ok "trouvée : $img"
  print "Tape le mot de passe de l'image (il ne s'affiche pas pendant la frappe) :"
  hdiutil attach -nobrowse "$img" >/dev/null || stop "Ouverture impossible (mot de passe incorrect ?)."
fi
[[ -d $IMP/prefix ]] || stop "L'image ouverte ne contient pas d'environnement de jeu."
ok "ouverte"

# 3. Fermer le jeu/Steam et mettre de côté un environnement sans le jeu
titre "3/5  Préparation"
"$COE" kill >/dev/null 2>&1
if [[ -d "$COE_ROOT/prefix/drive_c/$GAME" ]]; then
  print "Le jeu est déjà installé ici : rien à importer."
else
  if [[ -d $COE_ROOT/prefix ]]; then
    side="$COE_ROOT/prefix-sans-jeu-$(date +%Y%m%d-%H%M%S)"
    mv "$COE_ROOT/prefix" "$side" && ok "environnement sans le jeu mis de côté : ${side:t}"
  fi

  # 4. Import
  titre "4/5  Import (environ 45 Go, 5 à 15 minutes)"
  mkdir -p "$COE_ROOT/config"
  total=$(du -sk "$IMP/prefix" | cut -f1)
  rsync -a "$IMP/prefix/" "$COE_ROOT/prefix/" &
  pid=$!
  while kill -0 $pid 2>/dev/null; do
    sleep 10
    done_k=$(du -sk "$COE_ROOT/prefix" 2>/dev/null | cut -f1)
    printf "\r  %3d %%  (%d / %d Go)  " $(( done_k * 100 / total )) $(( done_k / 1048576 )) $(( total / 1048576 ))
  done
  wait $pid || stop "La copie a échoué (place disque ?)."
  print; ok "jeu, sauvegardes et session Steam importés"

  # Nom d'utilisateur Windows : garde la session Steam valide
  w=$(grep '^WIN_USERNAME=' "$IMP/config/coe.conf" 2>/dev/null)
  if [[ -n $w ]]; then
    if [[ -f $COE_ROOT/config/coe.conf ]]; then
      sed -i '' "s/^WIN_USERNAME=.*/$w/" "$COE_ROOT/config/coe.conf"
    else
      print -r -- "$w" > "$COE_ROOT/config/coe.conf"
    fi
    ok "nom d'utilisateur Windows repris"
  fi
fi

# D3DMetal, si l'app ne l'a pas encore
if [[ ! -d $COE_ROOT/dist/wine/lib/external/D3DMetal.framework && -d $IMP/d3dmetal/redist/lib ]]; then
  "$COE" install-d3dmetal "$IMP/d3dmetal" >/dev/null 2>&1 && ok "D3DMetal installé"
fi

# 5. Ranger l'image (elle contient ta session Steam) et lancer le jeu
titre "5/5  Rangement et lancement"
src=$(hdiutil info | awk -v v="$IMP" '/^image-path/ {p=$0; sub(/^image-path *: */, "", p)} index($0, v) {print p; exit}')
hdiutil detach "$IMP" -quiet && ok "image éjectée"
if [[ -n $src && -d $src ]]; then
  if [[ $(stat -f %d "$src") != $(stat -f %d "$HOME") ]]; then
    print "  L'image est sur un disque externe : supprime-la de ce disque toi-même ($src)."
  elif mv "$src" ~/.Trash/ 2>/dev/null \
       || osascript -e "tell application \"Finder\" to delete POSIX file \"$src\"" >/dev/null 2>&1; then
    ok "image mise à la corbeille : vide la corbeille pour l'effacer (elle contient ta session Steam)"
  else
    print "  Mets toi-même à la corbeille : $src (elle contient ta session Steam)."
  fi
fi
if [[ -n ${COE_TEST:-} ]]; then print "TEST : pas de lancement"; else open "$APP" && ok "lancement du jeu"; fi

print -P "\n%F{green}%BTerminé.%b%f Tu peux fermer cette fenêtre."
