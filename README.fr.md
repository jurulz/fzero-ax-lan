# F-Zero AX LAN pour Dolphin

[English](README.md) | **Français**

Faites tourner **F-Zero AX** (carte arcade Triforce) sur un [Dolphin](https://dolphin-emu.org) modifié, avec des **bornes liées** (mode VS en réseau local), des **sorties pour les lampes** et le **retour de force**.

> **Dolphin modifié, non officiel.** Le `Dolphin.exe` des releases est un **build modifié et non officiel de [Dolphin](https://dolphin-emu.org)** (GPL-2.0 ou plus récente) : commit upstream `66d8a892203d76a1f7349ed07526089b828e3835` plus les patches de [`dolphin/patches/`](dolphin/patches/). Il n'est ni conçu, ni soutenu, ni approuvé par le Dolphin Emulator Project : **ne leur signalez pas de problèmes avec ce build**, ouvrez plutôt un ticket (« issue ») ici. Ne l'utilisez pas pour le netplay ni pour autre chose qui attend un build officiel.

> Les fenêtres des outils (patcher, réglages du retour de force) sont **en anglais** ; les noms de boutons ci-dessous sont donc donnés en anglais.

## En bref

Il vous faut votre propre ISO **F-Zero AX (Japan) (Rev E)** (ID du jeu `GFZJ8P`, SHA-1 `73f3ddec23c85bc65ae51ed2ce8973231dadaeb1`, détails [plus bas](#quelle-iso-)) et deux PC Windows ou plus sur le même réseau.

1. Téléchargez le zip de la release et décompressez-le sur **chaque** PC.
2. Copiez votre ISO dans `Game\`.
3. Lancez `FZero_LAN_Patcher.exe` sur chaque PC : choisissez *This cabinet is* (1 sur le premier PC, 2 sur le deuxième...), le nombre de bornes et l'IP réelle de chacune, puis **APPLY**, **Dolphin firewall** (une seule fois) et **Launch game**.
4. Sur l'écran *CHECKING NETWORK*, `1 OK` et `2 OK` signifient que vous êtes liés.

Le menu test / service (touche `T`) est facultatif et demande **votre propre** `segaboot.gcm` dans `Dolphin-FZero\User\Triforce\` (voir [plus bas](#facultatif--le-menu-test--service-segabootgcm)). Tout le reste fonctionne sans lui.

Le retour de force et les lampes sont facultatifs : voir [LISEZ-MOI.txt](LISEZ-MOI.txt) (une page) ou les sections ci-dessous.

## Contenu du dépôt

| Dossier | Contenu |
|---|---|
| [`dolphin/`](dolphin/) | Patches pour Dolphin (liaison réseau entre bornes, sorties de la borne, retour de force intégré, quelques correctifs). À appliquer sur le commit upstream `66d8a89`. |
| [`patcher/`](patcher/) | `FZero_LAN_Patcher.ahk` : modifie le `main.dol` du jeu (numéro de borne, nombre de bornes, vérifications du moteur et du lecteur de cartes) **dans votre propre ISO**, écrit la configuration de Dolphin, crée la règle de pare-feu. |
| [`ffb/`](ffb/) | Fenêtre de réglage du retour de force (`FFB_Settings.ahk`) et pont externe facultatif (`DolphinFFBBridge.cs`). |
| [`tools/`](tools/) | `listen_dolphin_outputs.ps1` : enregistre les sorties (lampes / volant) de Dolphin, pour le diagnostic. |
| [`docs/`](docs/) | Fonctionnement de la liaison, protocole des sorties, retour de force, notes sur le protocole du volant, détail du patch du `main.dol`, compilation (en anglais). |

> **Aucun jeu et aucun firmware ne sont fournis, et il n'y en aura pas.** Il vous faut votre propre copie, obtenue légalement, de
> *F-Zero AX (Japan) (Rev E)* (`GFZJ8P`). Le firmware du menu service `segaboot.gcm` est facultatif et vous devez le fournir vous-même.
> Ce projet n'est pas affilié à Sega, Nintendo, Namco ni à l'équipe Dolphin, et n'est pas approuvé par eux.

## Quelle ISO ?

Exactement ce dump (`.iso` / `.gcm` non compressé), **avant** de le patcher :

| | |
|---|---|
| Nom | **F-Zero AX (Japan) (Rev E)** |
| ID du jeu | `GFZJ8P` (les 6 premiers octets du fichier) |
| Taille | 435 995 904 octets |
| SHA-1 | `73f3ddec23c85bc65ae51ed2ce8973231dadaeb1` |
| MD5 | `9070d5677e0950ceb086bced1f8cc423` |
| CRC32 | `9b1aebaf` |

Vérifiez avec `Get-FileHash -Algorithm SHA1 "F-Zero AX (Japan) (Rev E).iso"` dans PowerShell. Ces empreintes sont celles du fichier **d'origine** : APPLY modifie l'ISO sur place (une copie du `main.dol` d'origine est gardée à côté), son empreinte change donc ensuite.

Les autres révisions ou variantes **ne sont pas prises en charge** et le patcher les refuse (il vérifie l'ID du jeu, la taille du `main.dol` et le code autour de chaque endroit modifié). Les images compressées (RVZ, WIA, GCZ, CISO) doivent d'abord être converties en ISO (Dolphin : clic droit sur le jeu > Propriétés > Convertir le fichier). Un dossier extrait (`sys\` et `files\`) de la même version fonctionne aussi.

## Facultatif : le menu test / service (`segaboot.gcm`)

Les menus test et service de la borne sont fournis par le firmware de démarrage Triforce, `segaboot.gcm`. Il **n'est ni inclus ni distribué ici** : vous devez fournir votre propre copie et la placer dans `Dolphin-FZero\User\Triforce\segaboot.gcm` (le zip de la release contient un fichier d'indication dans ce dossier). Appuyez ensuite sur `T` une fois le jeu chargé (le mappage hybride du patcher permet d'utiliser le clavier pour cela).

Sans lui, le jeu, la liaison, les lampes et le retour de force ne sont pas touchés ; seuls les menus test / service sont indisponibles (le patcher affiche un message quand le fichier manque).

## État du projet

Testé sur deux PC de bornes (Windows 10 LTSC 1809, accès par Chrome Remote Desktop) :

- Fonctionne : mode VS lié entre deux bornes, lampes dans BackForceFeeder, retour de force avec vJoy + BackForceFeeder, contournement du contrôle du moteur et du nettoyage du lecteur de cartes, menu test, modification d'une ISO sur place.
- **Non testé** : retour de force avec un volant USB classique (Logitech, Thrustmaster, Fanatec...), trois ou quatre bornes liées, Windows 11, les libellés arcade de la fenêtre de la manette Triforce (présents dans le programme, non vérifiés à l'écran).
- Les adresses modifiées ne valent que pour le `main.dol` **Rev E** (SHA-1 `708c0860f61cbabbaae6568fd290c400c5c37c60`).

## Démarrage détaillé

1. Téléchargez le dernier zip de release (il contient un Dolphin prêt à l'emploi, le patcher et les outils) et décompressez-le **sur chaque PC de borne** (même build partout).
2. Mettez votre ISO dans `Game\`.
3. Lancez `FZero_LAN_Patcher.exe` (ou le `.ahk` avec [AutoHotkey v2](https://www.autohotkey.com)) :
   - *This cabinet is* : Cabinet 1 sur le premier PC, Cabinet 2 sur le deuxième...
   - *Number of cabinets* et l'**adresse IP réelle de chacune** (PC sur le même réseau).
   - **APPLY**, puis **Dolphin firewall** (une seule fois), puis **Launch game**.
4. Sur l'écran *CHECKING NETWORK*, `1 OK` et `2 OK` signifient que les bornes se voient.

Détails, options et dépannage : [docs/LINK.md](docs/LINK.md) (en anglais).

## Contrôles

Dolphin pilote la carte de base Triforce par un mappage de manette GameCube. Voici ce que fait chaque contrôle dans F-Zero AX (les titres des groupes de la fenêtre de la manette Triforce le disent aussi) :

| Contrôle GameCube (mappage) | Fonction arcade | Touche par défaut |
|---|---|---|
| Stick de contrôle, axe X | Volant | Gauche / Droite |
| Gâchette R (analogique) | Pédale d'accélérateur | `W` |
| Gâchette L (analogique) | Pédale de frein | `Q` |
| A | Bouton Boost | `X` |
| X | Palette gauche | `C` |
| Y | Palette droite | `V` |
| Start | Bouton Start | `Entrée` |
| Croix D : Droite / Gauche / Haut / Bas | Changement de vue 1 / 2 / 3 / 4 | `H` / `F` / `R` / `G` |
| Groupe « Triforce » : Test | Bouton Test (menu service) | `T` |
| Groupe « Triforce » : Service | Bouton Service | `S` |
| Groupe « Triforce » : Coin | Pièce / crédit | `1` |

Inutilisés par le jeu : B, Z, C-Stick, axe Y du stick. Le patcher peut ajouter les touches du clavier pour Test / Service / Coin **en plus** d'une manette ou d'un périphérique vJoy (« mappage hybride »).

## Retour de force

Dolphin (ce fork) calcule une force à partir de la position que le jeu demande au volant et de la position réelle du volant (axe X du stick de la manette 1), et l'envoie comme effet de *force constante* à un périphérique à retour de force : vJoy (piloté par BackForceFeeder), ou un vrai volant via DirectInput. Ouvrez `FFB\FFB_Settings.exe` pour l'activer et le régler (préréglages, raideur, amortissement, tests, état en direct).

- Dans le patcher, **décochez « Bypass the motor check »** : sinon le jeu n'initialise jamais le volant et n'envoie aucun ordre.
- Un pont séparé (`DolphinFFBBridge.exe`) reste disponible comme mode alternatif.

Tout le détail, y compris l'utilisation d'un volant USB de type Logitech et que faire quand la force est trop faible : [docs/FFB.md](docs/FFB.md) (en anglais).

## Lampes et logiciels de borne

Dolphin diffuse le même protocole de *sorties réseau* que MAME / Flycast sur `127.0.0.1:8000` (lampes, état du volant). [BackForceFeeder](https://github.com/njz3/vJoyIOFeederWithFFB) peut l'utiliser : dans son éditeur de « control set », mettez `Exec. process name = Dolphin` et `Output type = MAME_NET`. Protocole et noms : [docs/OUTPUTS.md](docs/OUTPUTS.md).

## Compilation

Dolphin lui-même (Visual Studio 2022, CMake) et les petits outils : [docs/BUILD.md](docs/BUILD.md). En bref :

```
git clone https://github.com/dolphin-emu/dolphin.git && cd dolphin
git checkout 66d8a892203d76a1f7349ed07526089b828e3835
git submodule update --init --recursive
git am ../fzero-ax-lan/dolphin/patches/*.patch      # dans Git Bash
cmake --preset ninja-release-x64 && cmake --build --preset ninja-build-release-x64
```

## Fonctionnement et notes

- [docs/LINK.md](docs/LINK.md) : comment fonctionne la liaison entre bornes et comment le patcher la prépare.
- [docs/WHEEL_PROTOCOL.md](docs/WHEEL_PROTOCOL.md) : ce que le jeu envoie au volant à retour de force (mesuré sur de vraies courses).
- [docs/PATCHES.md](docs/PATCHES.md) : quels octets du `main.dol` le patcher modifie, et pourquoi.

## Licence

Les patches de Dolphin et tout le reste de ce dépôt sont sous licence **GPL-2.0 ou plus récente** (voir [LICENSE](LICENSE)), comme Dolphin. Les composants tiers fournis dans le zip de la release et leurs licences sont listés dans [NOTICE.md](NOTICE.md).
