# Les essais sur matériel réel

Tout ce que ce paquet a mesuré l'a été sous MAME et au banc cosim, sauf ce que tient ce fichier : le
registre des images essayées sur une vraie carte, une **MV-2F (consolisée, sans bouton TEST)**. Pour
chaque image : sa date, ce qu'elle apportait, ce qui a été vérifié avant l'essai, ce que la carte a
montré et ce qui a été corrigé. Les vidéos et les retours bruts restent hors dépôt. Une image se
reconnaît à son CRC32 ou à son SHA-256.

**Les noms des fichiers.** Depuis le 2026-10-28, le BIOS s'appelle Sprixe BIOS (`DECISIONS.md` §29) :
les images à venir s'appellent `sprixe-bios-v0.1.rom` et `sprixe-bios-v0.1-byteswapped.bin`. Le
registre ci-dessous garde les noms sous lesquels chaque image est partie.

## Le format des images

Chaque image est fournie dans les deux ordres d'octets, construite par `build/construire.sh` :
`rebios-v0.1.rom`, dans l'ordre de MAME (`sp-s2.sp1`), à graver tel quel, et
`rebios-v0.1-byteswapped.bin`, inversé, pour un graveur réglé à l'envers.

L'ordre de MAME est celui que lit le 68000 une fois les paires échangées : le fichier commence par
`10 00 00 F3`, soit le vecteur de pile `$0010F300` en big-endian (`00 10 F3 00`). Qu'un graveur
attende cet ordre est SUPPOSÉ, d'après l'usage de la scène de graver les fichiers de BIOS de MAME
tels quels ; d'où les deux fichiers.

## L'image initiale et les images n°1 à n°8 — du 2026-10-21 au 2026-10-23

**L'image initiale, le 2026-10-21**, non numérotée : `src/c0` de `main` à `4d9f469c` (jukebox, #1391).

| Fichier | CRC32 | SHA-256 |
|---|---|---|
| `rebios-v0.1.rom` | `2E64A6AF` | `83d9906386cb852c81093922091549f8a57f3e96f84c75175a4456c544d0866f` |
| `rebios-v0.1-byteswapped.bin` | `05C71B06` | `54dcad24cb4175b9c4d106f1e650ea40a02a9f9e8863eb578a87a21c29cfb85e` |

Vérifié avant l'envoi : ce fichier exact, substitué sous MAME (`-bios euro`), démarre mslug, aof
et kof98 (`matrice.sh`, 30 s). Son CRC est celui que MAME rapporte pour notre image. Le parcours
d'essai demandé : écran de boot, jeu avec une pièce, second démarrage, écran TEST et un soft-DIP
changé, autotests, jukebox, menu en jeu, retour au BIOS d'origine. Réserves de cette image : jamais
tournée sur du matériel ; un seul slot servi (le slot 0) ; la table des emplacements de la backup
RAM n'est mesurée qu'en partie contre la référence. L'écran de boot attendu est celui de mslug sous
MAME, trame 60.

Les images n°1 à n°8 ont chacune remplacé la précédente **avant toute gravure** ; la n°8 est la
première essayée sur la carte. L'image n°1 a été vérifiée par son écran de boot de mslug (trame 60),
qui ne diffère du précédent que par la date de la ligne CLOCK. Les images n°2 à n°8 ont été
vérifiées sur le fichier exact : non-régression complète PASS, catalogue 161 jeux sur 164 aux
verdicts de `measured/2026-10-22-matrice-catalogue-soir.tsv` ou de la matrice citée, écran de boot
de mslug à la trame 60 égal au précédent hors de la ligne CLOCK (lignes 153 à 167).

| N° | Date | `main` | Ce qu'elle ajoute | CRC32 `.rom` | Somme | SHA-256 `.rom` | CRC32 inversée |
|---|---|---|---|---|---|---|---|
| 1 | 2026-10-22 | `eeaeeac5` (#1396) | le durcissement matériel, d'après `docs/AUDIT-2026-10-21.md` | `3D83D4C2` | — | `1db82fe1f959b3fecdb844d64fec7734abd1b22309937c4ef9d8b3ebaba8ea5e` | `5A9B62E5` |
| 2 | 2026-10-22 | `c29b5860` (#1407) | multi-slot complet, sauvegarde du jeu en backup RAM, crédit remis à zéro au boot, START et pièce à la trame de la référence, DEMO_END | `9E199F82` | `FCB0` | `8e0ea5b87d49c769d1c763a7edf1685e0f94392132c95e39c97871dfc58ad173` | `8F86BD8B` |
| 3 | 2026-10-23 | `2152a2e0` (#1410) | la répétition du joystick, $10FD81 au START, FRAME_SKIP sous INT1, la pièce sous INT1 | `A0CF795A` | `FAC9` | `dcb3a7c2bc6473eb62e69b5e89ff256ac8d68a759c49a2afe31ea601216d56a5` | `DB0C4010` |
| 4 | 2026-10-23 | `a84b44c2` (#1411) | PLAY TIME, l'état des joueurs effacé à chaque remise, la trame tenue de DEMO_END | `3817E1FE` | `4ACC` | `890e65f5816ef2a0047477d27dcdb05bacddafa7752bca27fe638c1bc94ee3c5` | `7A3E60AD` |
| 5 | 2026-10-23 | `bf73581b` (#1412) | les LED et REG_POUTPUT, les remises et la fin de partie tenue | `781135D3` | `9200` | `112480d25eb3889881895ae23c00a04d33c980713f507e94b65f98202b78dbd2` | `66ECA6F7` |
| 6 | 2026-10-23 | `d95122a2` (#1414) | le titre unique après game over, la garde de SELECT, le menu en jeu qui ne coupe plus le son du jeu (`2026-10-23-matrice-catalogue.tsv`) | `E11C2833` | `183E` | `528b7e9c7120bdabf29747eaa7993efdb2398df5a177062e1fb7314d1a60716a` | `ACCB9C6B` |
| 7 | 2026-10-23 | `14b54bb1` (#1417) | le mode AES (ligne MODE de l'éditeur, MVS par défaut, `DECISIONS.md` §11) (`measured/2026-10-23-matrice-catalogue-aes.tsv`) | `5175C745` | `CE40` | `bc6560f50412bbb23cece3f5d38a4a818c5c606ca5564b4407c983db4bc8127b` | `EDC5657D` |
| 8 | 2026-10-23 | `516016ce` (#1419) | CREDIT_CHECK en mode AES (aof affiche « PUSH START » pour P2) ; 63 scènes (`measured/2026-10-23-matrice-catalogue-credit-aes.tsv`) | `4AC27546` | `C49A` | `6fc2d51b7bf2823575e3dc0436f732314aa045de328a16ff52ff9e277d265ec6` | `BA27826C` |

## Image n°8 sur la carte — 2026-10-24

**Ce que la carte a montré** (MV-2F, deux slots, plusieurs cartouches dans les deux slots) : l'écran
de boot s'affiche juste, mais GAME NGH vaut **toujours E05C**, avec ou sans cartouche ; aucun jeu ne
démarre et la carte redémarre en boucle.

**La cause, démontrée sous MAME et appuyée par le wiki, puis confirmée par l'image de diagnostic** :
notre boot lisait l'en-tête des slots sous REG_BRDFIX, l'état du reset, et la référence sous
REG_CRTFIX.
- MESURÉ (`bench/acces-boot.lua`, `measured/2026-10-24-slot-crtfix.tsv`, ng_mv2f et MV-6F, 1 et 2
  cartouches, slot 0 vide) : la référence envoie $01 au Z80 et attend son écho, écrit REG_SLOT ← 0,
  REG_CRTFIX, REG_SLOT ← 0, lit l'en-tête de chaque slot, puis REG_BRDFIX. L'image n°8 lisait
  l'en-tête sans jamais écrire REG_CRTFIX. MAME sert la cartouche dans les deux cas, d'où huit
  images sans que le banc voie rien.
- LU (NeoGeo Development Wiki, 2026-10-24) : « MVS cartridge pinout », SLOTCS « goes low when the
  slot is used », « On one slot boards, it's tied to SYSTEMB », « The System ROM was written to
  ensure the signal is asserted when it does the slot check » ; « NEO-F0 » : « SYSTEMB is used to
  gate the SLOT* outputs » ; « Signals » : « SYSTEM: low when onboard ROMs selected ».
- MESURÉ, MAME servi comme ce modèle (`bench/bus-flottant.lua` : sous REG_BRDFIX, $000080-$0FFFFF
  et $200000-$2FFFFF rendent le mot préchargé, comme `unmapped_r` de MAME pour un trou) : l'image
  n°8 affiche **GAME NGH E05C**, l'écran vu sur la carte ; avec kof98, elle **redémarre en boucle**
  (resets aux trames 194, 387, 581, 775…) : chaque boot voit tous les slots vides, refait la
  demande 0, que kof98 finit par un reset. Avec mslug, le modèle laisse le jeu démarrer : la boucle
  vue sur les autres cartouches n'est pas expliquée par ce seul modèle.

**Corrigé** (`src/c0/c0.s`, la détection ; `src/c0/ecran.s`, le NGH pris dans la table des slots) :
l'ordre de la référence. Sous le modèle du bus flottant, l'image corrigée ne fait plus aucune lecture
flottante au boot, affiche 0201 pour mslug au slot 0 comme au slot 1, et kof98 ne fait qu'un reset
(le sien) avant de tourner. Non-régression : étage 3f (`bench/bus-flottant.lua` sur aof), qui
échoue sur la correction retirée (4 lectures flottantes). Le Z80 est garé avant la détection et non
plus au passage de slot du boot, comme la référence, et la remise tombe à la même trame qu'avant
(188 sur aof) : non-régression complète PASS sur l'image `88366706…`, matrice et 81 scènes
inchangées.

**Même cause, corrigé ensuite** : l'éditeur de soft-DIP du boot passait sous REG_BRDFIX pour la
police de la carte, puis lisait nom et intitulés dans la P-ROM (244 lectures flottantes à l'entrée
sous le modèle, des « 0 » à la place des intitulés), et les autotests et le jukebox le redessinent
au retour. Il recopie désormais le bloc soft-DIP en RAM sous REG_CRTFIX avant la bascule
(`dip.s`, `.Lcopier_bloc`). Les cinq écritures de REG_BRDFIX sont recensées dans
`measured/2026-10-24-bus-flottant-ecran-test.tsv` ; quatre scènes `bf-*` jouent ces écrans sous le
modèle, à 0 lecture flottante et à l'image du témoin. Non jugé : une exception levée pendant
l'écran TEST ou de plantage lirait son vecteur en bus flottant (`DECISIONS.md` §13).

**Sans cartouche, la carte redémarrait en boucle**, sous MAME aussi : le BIOS servait le slot 0 vide,
et le watchdog relançait la carte toutes les 192 trames. Il ouvre désormais ses autotests
(`DECISIONS.md` §13, point 3). C'est sans doute une part de la boucle vue sur la carte sans
cartouche, sans preuve.

## Image de diagnostic n°1 — 2026-10-24

`diag/slots/`, construite par `build/construire.sh diag/slots <sortie>` : sans cartouche à lancer,
elle affiche REG_SYSTYPE, REG_STATUS_A, le mot de $380000, REG_DIPSW et l'écho du Z80, puis pour
chaque slot 0 à 7 les 16 octets de $000100-$00010F lus de six façons (A sous REG_BRDFIX, l'image
n°8 ; B sous REG_CRTFIX, la correction ; C B + REG_SWPROM ; D REG_SLOT écrit en mot ; E après 8
trames ; F en octets), et Y si « NEO-GEO » y est. Deux pages alternées toutes les 240 trames ;
watchdog servi, l'écran tient. Vérifiée sous MAME (ng_mv2f et neogeo, mslug au slot 0 puis au slot
1, bus normal et bus flottant) : 3 011 trames sans reset, les octets lus égaux à ceux du romset
(`4E454F2D47454F00 0201002000000010`). Sous MAME, les slots 6 et 7 sont ramenés à 5 par le jig
(MAME 0.286 sort en erreur de segmentation sur REG_SLOT ≥ 6, `m_slots[data]` non borné) : leurs
lignes ne valent que sur le matériel. `rebios-slot-diag-1.rom` (ordre de MAME) : CRC32 `942C132E`,
SHA-256 `290ba26cbdf5dc9f78e34f4e42b513dc69d6f3fd696a0c56219955da266e75dd` ; inversée : CRC32
`122FDC22`.

**Ce que la carte a montré, le 2026-10-25** (cartouche au slot 1, au slot 2, sans cartouche ; les
octets dans `measured/2026-10-25-diag-slots-materiel.tsv`) : la cartouche se lit sous REG_CRTFIX,
pas sous REG_BRDFIX. La méthode A (REG_BRDFIX, l'image n°8) ne voit jamais « NEO-GEO », les méthodes
B à F le voient toutes, au seul index de son slot. Le slot 1 de la carte répond à REG_SLOT 0, le
slot 2 à REG_SLOT 1. Sans cartouche, aucun Y (A à C). Cela confirme `DECISIONS.md` §13 ; les images
n°9 à n°11 lisent l'en-tête sous REG_CRTFIX (#1423). Les index 2 à 7, absents d'une carte à deux
slots, rendent des octets qui ne sont pas un en-tête, sans planter la carte.

L'image de diagnostic n°2 (#1435) a été abandonnée sans essai.

## Images n°9 à n°12 — 2026-10-24 et 2026-10-25

Chacune vérifiée sur le fichier exact : non-régression complète PASS, catalogue 161 sur 164 sans
jeu perdu (ng_mv1f non mesuré à partir de la n°10).

| N° | Date | `main` | Ce qu'elle ajoute | Scènes | CRC32 `.rom` | Somme | SHA-256 `.rom` | CRC32 inversée |
|---|---|---|---|---|---|---|---|---|
| 9 | 2026-10-24 | `a8b3ffb8` (#1425) | la lecture de l'en-tête sous REG_CRTFIX (#1423), l'éditeur de soft-DIP qui lit une copie de son bloc (#1424), les autotests sans cartouche (#1425), GAME SETTINGS et MEMORY EDITOR dans le menu en jeu (#1422) (`measured/2026-10-24-matrice-catalogue.tsv`) | 86 | `F9889F16` | `86A6` | `70f73d53be4b7c9bd036061e91d26ffc2d529922d4df04db8facac361f49b6cf` | `F331E3A7` |
| 10 | 2026-10-25 | `13a837d1` (#1427) | MEMORY CARD et SCORE RESET dans l'écran TEST | 98 | `B4411EDF` | `44FF` | `c4cba5b219ee7c4230ff34dbe2163c751cfcb163506d837734008940353b94e2` | `0E20CF19` |
| 11 | 2026-10-25 | `a3159605` (#1429) | CABINET SETTINGS dans l'écran TEST (FREE PLAY, NO CONTINUE, DEMO SOUND) | 106 | `1111B3F0` | `3F02` | `cdaca6b7a397ee5ff8a3820428386bb51406343316fd7addff7e506df8bdd10f` | `B997A318` |
| 12 | 2026-10-25 | `4d26ffdc` (#1432) | le catalogue des cheats (35 jeux) et CHEATS/DEBUG dans CABINET SETTINGS | 109 | `F8040392` | `F5B8` | `e5b4ea94d82df51ac3530ca731b8b432b993eb10053c5a2329d43dd161cb67d5` | `345FEAB1` |

**Image n°12 sur la carte, le 2026-10-25** (commutateur 7 « Free Play » à ON) : le jeu démarre aux
slots 1 et 2, son parfait ; aucune entrée en partie, START refusé. ReBIOS ignorait les commutateurs
1 et 7, et l'écran TEST n'était accessible que par le bouton TEST, absent de cette carte. Corrigé
par #1439 (`DECISIONS.md` §17).

## Images n°13 et n°14 — 2026-10-25

| N° | `main` | Ce qu'elle ajoute | Scènes | CRC32 `.rom` | Somme | SHA-256 `.rom` | CRC32 inversée |
|---|---|---|---|---|---|---|---|
| 13 | `e7179b01` (#1439) | le commutateur 7 honoré, l'écran TEST au commutateur 1 ou à START + SELECT tenus au boot, le menu en jeu à START + SELECT | 119 | `7E672E6D` | `1E6E` | `981cd2aff816d11b0cbd2b5dc5a97a04950ed37a17fa30545027f83dd7ced0e8` | `CBA8D402` |
| 14 | `f8cb3e3f` (#1442) | la grille de Super Sidekicks (`DECISIONS.md` §18) ; 142 mutations tuées, catalogue identique jeu par jeu à la référence | 120 | `B660FA81` | `5B39` | `8f03e1deeff52bf1e7f7120dcf0c5b414f41cc0ff3bca712bd431e74b6f0fd73` | `E9437AD8` |

Chacune vérifiée sur le fichier exact : non-régression complète PASS, catalogue 161 sur 164 sans
jeu perdu (ng_mv1f non mesuré). L'écart de ReBIOS à la sortie de l'écran TEST commutateur 1 à ON
(§17 pt 4) a été confirmé sur la carte avec le BIOS d'origine.

**Image n°14 sur la carte, le 2026-10-26** : les soft-DIP essayés sont respectés par le jeu, et
Super Sidekicks tourne normalement. Sans manette, commutateur 1 à OFF : l'écran de boot une fois,
puis le jeu ; commutateur 1 à ON : l'écran de boot, puis l'écran TEST. START + SELECT tenus à
l'allumage : l'écran TEST, sans écran de boot. START seul en partie n'ouvre jamais le menu.
L'écran TEST vu à chaque démarrage venait d'un adaptateur de manette **BlueRetro** : à sa mise en
route, il tient environ une seconde L/R, A, B, C, D, START et SELECT, ce que l'INPUT TEST a montré ;
branché en partie, il ouvre le menu en jeu. Corrigé par #1450 (le geste ignore le BlueRetro).
Intitulés de Super Sidekicks en région JAPAN : #1449.

## Image n°15 — 2026-10-28

`main` à `3830611b` (#1452, #1453, #1457, #1460). Elle ajoute à l'image n°14 l'autofire par jeu,
CARTRIDGE CRC, DEBUG DIPS, les commutateurs 2, 3 et 8, la page du panneau de mahjong, l'économiseur
du JUKEBOX, la copie de carte, la validation de GAME_DIP, les intitulés JAPAN, le geste qui ignore
le BlueRetro et la table du sinus (Alpha Mission II). `rebios-v0.1.rom` : CRC32 `C87FC0A6`, somme
des octets `951A`, SHA-256 `d54340ec83fc579a1a80fc19604d00cbe56d230738b1a95578642d2e5f57417e` ;
inversée : CRC32 `299AC253`. Vérifié sur cette image exacte (#1460) : non-régression complète PASS
(150 scènes), 195 mutations tuées, catalogue 161 sur 164 identique jeu par jeu à la référence
(ng_mv1f non mesuré). Tout ce qui est neuf n'a tourné que sous MAME. Pas encore de retour de la
carte.

**Ce que la carte a montré, le 2026-10-28.** Les cartouches du commerce démarrent. Le NeoSD Pro et
le BackBit s'arrêtent sur l'écran de boot, GAME NGH ..... 0000 ; la DarkSoft donne un écran noir,
mais elle ne démarre pas non plus une fois le BIOS d'origine remis, où l'autotest SNK se bloque au
test de la WORK RAM : ce second symptôme n'est pas imputé à cette image.

GAME NGH vient de la table des slots, et 0000 y est un slot vide : la détection n'a trouvé aucune
cartouche. Elle parcourait les slots une fois, à la trame 1 ; la référence le fait à la trame 276
(`measured/2026-10-24-slot-crtfix.tsv`). SUPPOSÉ : un flash cart charge son menu après la mise sous
tension et ne rend pas encore son en-tête à la trame 1. Sous MAME, une cartouche muette sur 30
trames reproduit l'écran (`measured/2026-10-28-carte-lente.tsv`). Corrigé (`DECISIONS.md` §31,
scène flash-cart). Non reproduit : sous MAME, l'image passe ensuite aux HARDWARE TESTS, et la carte
n'en a rien montré.
