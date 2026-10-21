# ClairObscurMac

Faire tourner **Clair Obscur: Expedition 33** (version Steam Windows) sur un Mac Apple Silicon,
avec un Wine **compilé soi-même** et le traducteur DirectX 12 → Metal d'Apple (D3DMetal),
sans CrossOver, Whisky ni Porting Kit.

Testé sur macOS 27.0.1 : MacBook Pro **M1 Max** et **M2 Max**.

## Ce que contient ce dépôt

| Fichier | Rôle |
|---|---|
| `scripts/build-deps.sh` | compile FreeType, GnuTLS (+ nettle, gmp) et SDL2 en x86_64 |
| `scripts/build-wine.sh` | compile Wine (sources CrossOver 26.3.0, base Wine 11.0) en x86_64 + 32 bits (wow64) |
| `patches/` | 2 correctifs Wine nécessaires pour compiler sur macOS 27 |
| `scripts/coe` | le lanceur : installe D3DMetal, crée l'environnement Windows, lance Steam et le jeu |
| `config/profiles/` | profils `Engine.ini` du jeu (réglages Unreal Engine) |
| `Clair Obscur.app` | app à double-cliquer qui lance le jeu |
| `scripts/import-steam-registry.py` | reprend la connexion Steam d'un ancien environnement Wine |
| `scripts/exporter.sh` | copie l'installation complète vers un disque externe (pour un autre Mac) |
| `scripts/analyse-video.sh` | découpe une vidéo de jeu en images pour repérer les bugs graphiques |

**Ce dépôt ne contient rien d'Apple ni du jeu.** D3DMetal se télécharge sur le site développeur
d'Apple (gratuit, identifiant Apple requis), et le jeu s'achète sur Steam.

## Prérequis

- Mac Apple Silicon. **M2 ou plus récent recommandé** (voir « Nanite » plus bas).
- macOS 27 avec les Command Line Tools (`xcode-select --install`) et Rosetta (`softwareupdate --install-rosetta`).
- Homebrew : `brew install bison mingw-w64 freetype`
- Le *Game Porting Toolkit 4* d'Apple (`Evaluation_environment_for_Windows_games_4.0*.dmg`).
- Environ 60 Go libres (dont ~45 Go pour le jeu).

## Installation

```bash
scripts/build-deps.sh          # ~15 min
scripts/build-wine.sh          # ~30 min
scripts/coe install-d3dmetal ~/Downloads/Evaluation_environment_for_Windows_games_4.0_beta_3.dmg
cp config/coe.conf.example config/coe.conf   # puis y mettre son nom d'utilisateur
scripts/coe setup              # crée l'environnement Windows
scripts/coe play --hud         # lance le jeu, avec le compteur de FPS Metal
```

`coe setup` importe Steam, le jeu et les sauvegardes depuis un wrapper Porting Kit existant
(chemin `OLD_PREFIX` en tête de `scripts/coe`). Sans wrapper existant, il faut installer
Steam pour Windows dans le prefix et y télécharger le jeu.

## Ce qu'on a appris en chemin

**macOS 27 : les outils de compilation d'Apple sont arm64 uniquement.** Ils ne tournent plus sous
Rosetta (`libxcrun.dylib` sans tranche x86_64). Tout est donc compilé en natif arm64 avec
`-arch x86_64` (compilation croisée). Les outils de Wine (`winebuild`, `widl`…) sont compilés à part
en arm64 (correctif `0001`).

**Wine de CodeWeavers sans Vulkan** : un ajout de CodeWeavers dans `win32u/vulkan.c` suppose Vulkan
présent (correctif `0002`). D3DMetal parle directement à Metal, Vulkan est inutile ici.

**Steam** :
- l'interface web de Steam (CEF) ne fonctionne sous Wine qu'avec
  `-no-cef-sandbox -cef-in-process-gpu -cef-disable-gpu` ;
- ce Wine répond toujours « crossover » à `GetUserName`, sauf avec `CX_REPORT_REAL_USERNAME=1`.
  Or Wine dérive la clé de `CryptProtectData` du nom d'utilisateur, et Steam y chiffre son jeton de
  connexion : le nom (`WIN_USERNAME` dans `config/coe.conf`) doit rester le même partout ;
- une 2e instance de `steam.exe -applaunch` ne transmet pas l'ordre à la 1re : `coe play`
  redémarre Steam avec l'ordre de lancement.

**Nanite et les puces M1.** Sur un M1 / M1 Max, les fleurs s'affichent en carrés, les cadres de
fenêtres en panneaux plats, les murs en facettes et le lierre en triangles. Ce n'est pas un bug de
transparence : Nanite a besoin d'opérations atomiques 64 bits que le GPU du M1 n'a pas (elles
existent à partir du M2). Sans Nanite, Unreal Engine affiche des modèles de secours très simplifiés.
Preuve : `r.Nanite=0` ne change ni l'image ni les FPS sur M1. **Aucun réglage ni aucun wrapper ne
peut corriger ça sur M1.** Sur M2 Max, les vraies fleurs s'affichent.

**MetalFX** : avec `D3DM_ENABLE_METALFX=1` (activé par `coe`), D3DMetal convertit le DLSS du jeu
en MetalFX, l'upscaler d'Apple. Choisir DLSS dans les options graphiques du jeu.

## Problèmes connus

- La fenêtre de connexion de Steam reste noire : il faut une connexion Steam déjà enregistrée
  (importée d'un autre environnement). Le jeu, lui, s'affiche normalement.
- Saccades les premières minutes : D3DMetal compile les shaders et les garde en cache ensuite.

## Licence

Scripts sous licence MIT (voir `LICENSE`). Les correctifs du dossier `patches/` modifient Wine et
sont, comme Wine, sous licence LGPL 2.1 ou ultérieure.

Clair Obscur: Expedition 33 est un jeu de Sandfall Interactive. Game Porting Toolkit et D3DMetal
sont des logiciels d'Apple. Ce projet n'est affilié ni à l'un ni à l'autre.
