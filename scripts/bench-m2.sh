#!/bin/zsh
# Un essai de FPS sur le M2 Max : relance le jeu avec un profil (et des variables),
# attend que le joueur soit en jeu (GPU > 12 ms), laisse le décor se charger,
# puis mesure 30 s. Usage : bench-m2.sh <profil> [--env K=V ...]
profile=${1:?profil}; shift
ssh -o BatchMode=yes m2max "open ~/ClairObscurMac/Clair\ Obscur.app --args --hud --profile $profile $*"
print "Jeu relancé avec « $profile » $* — en attente de « Continuer → Confirmer »..."
sleep 30
for i in {1..150}; do
  r=$(ssh -o BatchMode=yes -o ConnectTimeout=8 m2max '~/ClairObscurMac/scripts/coe fps 5 2>/dev/null' 2>/dev/null)
  g=$(print -r -- "$r" | sed -nE 's/.*GPU ([0-9.]+) ms.*/\1/p')
  [[ -n $g ]] && (( g > 12 )) && break
  sleep 4
done
sleep 25
print "=== $profile $* ==="
ssh -o BatchMode=yes m2max '~/ClairObscurMac/scripts/coe fps 30'
