# Performances mesurées

MacBook Pro **M2 Max** (GPU 38 cœurs), macOS 27.0.1, D3DMetal 4.0 bêta 3, écran interne 120 Hz.
Réglages du jeu : préréglage **Moyen** (choisi par la détection automatique du jeu),
sortie 1728×1117, rendu interne à 50 %.

## Méthode

Même endroit à chaque fois (marché aux fleurs de Lumière), personnage et caméra immobiles,
25 s de chargement du décor puis **30 s de mesure** (`scripts/bench-m2.sh <profil>`).

Les mesures viennent du HUD Metal (`coe play --hud` active `MTL_HUD_LOG_ENABLED`) : une ligne
`metal-HUD:` par seconde avec le temps de chaque image et son temps GPU. Steam lance le jeu
avec sa sortie standard vers `/dev/null` ; le correctif Wine `0003` la redirige vers le journal
quand `COE_STDOUT_TO_STDERR` est défini. `coe fps 30` calcule ensuite les FPS moyens, le
« 1 % bas » et le temps GPU.

## Résultats

| Profil | Ce qui change | FPS moyens | GPU par image |
|---|---|---|---|
| référence (`equilibre`) | réglages du jeu : FSR 4, Lumen, effets, synchro 120 Hz | 51,0 | 19,6 ms |
| `perf-vsm` | ombres classiques au lieu des ombres virtuelles | 50,5 | 19,7 ms |
| `equilibre` + `D3DM_MTL4=0` | moteur Metal 3 de D3DMetal | 51,6 | 19,9 ms |
| `perf-metalfx` | FSR 4 → DLSS (MetalFX) / TSR | 50,2 | 18,7 ms |
| `perf-effets` | brouillard volumétrique, éclairage des particules, flou, profondeur de champ, aberration coupés | 55,6 | 18,0 ms |
| `perf-lumen` | Lumen (éclairage global + reflets) coupé | 58,2 | 17,2 ms |
| **`fluide`** | effets + FSR 4 → DLSS/TSR + reflets en espace écran + Nanite allégé + synchro coupée | **57,1** | 17,4 ms |
| **`fps-max`** | `fluide` + éclairage global en espace écran | **66,7** | 14,7 ms |
| `perf-plancher` (diagnostic) | tout coupé, Nanite compris : image dégradée | 77,0 | 13,0 ms |

À titre de comparaison, le **M1 Max** (GPU 32 cœurs, préréglage Élevé, sans Nanite possible)
tournait à 32-36 FPS au même endroit, avec 28-30 ms de GPU par image.

## Ce qu'on en retient

- **Le GPU limite**, pas le processeur. Même à un rendu interne de 864×558, il faut ~13 ms par
  image : une bonne part vient du rendu de base et de la traduction DirectX 12 → Metal.
- **La synchro verticale à 120 Hz** fait alterner 60 et 40 FPS dès qu'une image dépasse 16,7 ms.
  Le réglage du jeu est stocké dans la sauvegarde ; `r.VSync=0` dans `Engine.ini` l'emporte.
- Les plus gros leviers : **Lumen** (~2,5 ms), **les effets** (~1,7 ms), **Nanite** (~2,5 ms,
  mais c'est lui qui affiche les vraies fleurs : à garder), **FSR 4** (~1 ms).
- Sans effet mesurable : ombres virtuelles, moteur Metal 3, allègements fins de Lumen, des
  ombres, du bloom et du ciel au préréglage Moyen.
- Les pics isolés (75 à 250 ms) au premier lancement d'un profil sont la compilation des
  shaders ; ils disparaissent une fois le cache de D3DMetal rempli.
