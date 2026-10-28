# Compatibilité commerciale des BIOS Neo Geo, mesurée

17 jeux du commerce × 4 BIOS = **68 runs**, MAME 0.286, sans fenêtre, 3 500 trames chacun,
pièce et départ injectés. Relevés bruts : `../measured/2026-10-10-matrice.tsv`.
Pour rejouer : `../bench/matrice.sh`.

## Le résultat

| BIOS | jeux qui tournent | échecs |
|---|---|---|
| BIOS SNK (`euro`) | **17 / 17** | — |
| UniBIOS 4.0 | **17 / 17** | — |
| NeoPen 0.1 | 14 en jeu, 3 arrêtés sur un « press start » | à préciser |
| **nullbios 0.5** | **9 / 17** | **8** |

> Capture non publiée : une planche montrait trois jeux de la matrice côte à côte sous chacun des
> quatre BIOS.

## Les huit échecs de nullbios, en deux familles

| Jeu | Année | Symptôme | Pixels allumés | Vitesse de simulation |
|---|---|---|---|---|
| Art of Fighting | 1992 | figé au choix de personnage dès la trame 300 | 67 795 | 2 898 % |
| Metal Slug | 1996 | figé sur « LOAD? YES/NO » dès la trame 600 | 61 072 | 2 448 % |
| Super Sidekicks 4 | 1996 | écran noir | **0** | 2 269 % |
| KOF '98 | 1998 | écran noir | **0** | **56 %** |
| Garou | 1999 | écran noir | **0** | **61 %** |
| Metal Slug 3 | 2000 | écran noir | **0** | **54 %** |
| KOF 2003 | 2003 | écran noir | **0** | **54 %** |
| SVC Chaos | 2003 | écran noir | **0** | 2 821 % |

Les 60 autres runs tournent entre 1 500 et 2 900 %. Une vitesse à ~55 % signale une machine qui
s'emballe — l'hypothèse d'une boucle de reset par le watchdog n'a pas été vérifiée.

### Famille 1 — la carte mémoire, et c'était prévisible

> Capture non publiée : Art of Fighting sous nullbios, trame par trame, jusqu'au gel décrit
> ci-dessous.

Art of Fighting, trame par trame : écran-titre et `CREDIT 01` à la trame 100, **« MEMORY CARD LOAD —
YES / NO »** à 200, choix de personnage à 300, puis **la même image jusqu'à 3 500**, minuterie
bloquée à 08.

> Capture non publiée : trois des échecs de nullbios détaillés, dont l'écran « LOAD? » de Metal Slug.

Metal Slug suit le même chemin : titre, « HOW TO PLAY », puis **« LOAD? ▶YES / NO — PUSH A BUTTON »**
à la trame 700, et plus rien — alors que le banc appuie sur A toutes les 300 trames.

Ces deux-là sont exactement les deux jeux du corpus qui passent par la carte mémoire, et nullbios
renvoie `CARD` sur un `rts` nu. **Les deux tournent sous NeoPen**, qui implémente l'appel.

### Famille 2 — six écrans noirs, cause inconnue

Zéro pixel allumé sur toute la durée. Trois hypothèses ont été testées en écrivant les variables
à la place du BIOS, depuis le banc, et **les trois sont réfutées** :

| Hypothèse | Injection | Résultat |
|---|---|---|
| `bios_frame_counter` jamais tenu (`$10FE88`) | compteur incrémenté à chaque trame | **aucun changement** |
| réponse carte mémoire absente (`$10FDC6`) | `0x80` (« pas de carte ») en continu | **aucun changement** |
| contrôle de slot lisant le calendrier | date BCD en `$10FDD2`–`$10FDD8`, témoin `$10FCEF`, puis les deux | **aucun changement** |

L'injection a été vérifiée dans chaque cas — avec le compteur armé, le relevé lit bien 200, 400,
600, 800. Ce sont donc de vraies réfutations, pas des tests qui n'ont pas tourné.

Un motif apparent s'est aussi effondré : les écrans noirs **ne sont pas la cohorte d'après 1998**.
Super Sidekicks 4 est de 1996, et SVC Chaos (2003) est noir à vitesse normale. L'effondrement de
vitesse ne touche que quatre des six.

**Piste suivante** : tracer le 68000 pendant le gel. Le débogueur de MAME segfault sous
`-video none` ; il faut une fenêtre.

## Ce que le verdict ne dit pas

Le critère automatique répond « l'image change-t-elle encore ? ». Il ne suffit pas, et deux
contre-exemples l'ont prouvé pendant cette campagne :

- **une image peut changer et rester noire** — KOF '98 passait le critère tout en n'affichant rien
  pendant 58 secondes. D'où la colonne « pixels allumés », qui tranche ;
- **un écran d'attract bouge** — les 17/17 de NeoPen comptent trois jeux (Riding Hero, KOF '94,
  NAM-1975) arrêtés sur un écran « push start » avec des crédits affichés. Cause non établie :
  l'hypothèse d'un départ qui n'atteint pas le jeu n'a pas été vérifiée.

## Les quatre BIOS libres, mesurés ensemble

Deuxième campagne, **102 runs** : les 17 mêmes jeux sous six BIOS. Relevés bruts dans
`../measured/2026-10-10-matrice-6bios.tsv`.

Les deux images tierces sont construites depuis leur source par `../bench/tiers/construire.sh`, qui
**épingle les commits**. Ce qui a été mesuré, en clair, pour que n'importe qui le refasse :

| Image | Commit | sha256 de l'image |
|---|---|---|
| `neogeo-bios` | `93c02a9b` (2026-01-02) | `94bce7938643627e…` |
| NeoPen recompilé | `2b28ff0f` (2015-08-03) | `fd5e9d885b68032c…` |
| NeoPen, binaire publié de 2015 | — | `9c16c0c161503152…` |

Le script rejoué le 2026-10-10 sur la machine de mesure a produit des images **identiques à
l'octet** à celles de ce tableau. Cette reproductibilité n'est pas garantie dans le temps : les
commits sont épinglés, mais pas le digest de l'image `ubuntu:24.04` ni les versions des paquets
`apt`. Et ce document montre justement qu'une chaîne de construction différente change le résultat
de NeoPen.

| BIOS | critère automatique | en jeu à l'œil | licence |
|---|---|---|---|
| BIOS SNK (témoin) | 17 / 17 | — | propriétaire |
| UniBIOS 4.0 (témoin) | 17 / 17 | — | propriétaire |
| **NeoPen 0.1, binaire de 2015** | **17 / 17** | **~14 sur 17** | **ISC** |
| **neogeo-bios** | 15 / 17 | **11 sur 15 capturées** | GPL-3.0 |
| NeoPen recompilé depuis la source | 14 / 17 | — | ISC |
| nullbios 0.5 | 9 / 17 | — | LGPL-3.0+ |

> Captures non publiées : deux planches montraient la dernière image de chacun des 17 jeux, l'une
> sous NeoPen 2015, l'autre sous `neogeo-bios` ; c'est sur elles que la colonne « en jeu à l'œil »
> a été jugée.

**Trois constats.** Le binaire de NeoPen de 2015 est le plus compatible. `neogeo-bios` fait
**planter MAME** — segfault, sortie 139 — sur `garou` et `svc`. Et nullbios, que la première campagne avait retenu comme base, est dernier.

`neogeo-bios` fait tourner Metal Slug, KOF '98, KOF 2003 et Super Sidekicks 4, c'est-à-dire
précisément les jeux que nullbios laisse en écran noir.

**Trois réserves, et elles comptent.**

Le critère automatique dit « image non noire, qui change encore, sans alerte » — **pas « jouable »**.
Sous NeoPen, trois jeux restent sur un « push start » avec des crédits affichés : NAM-1975, Riding
Hero et KOF '94. Le `features.txt` de NeoPen l'annonce d'ailleurs en tête de ses tâches,
*« Properly use SYSTEM_RETURN, games freeze in their attract loop »*.

Les cinq échecs de `neogeo-bios` et de NeoPen recompilé sont des **plantages de MAME**, pas des
verdicts de BIOS. Trois jeux, deux images, le même segfault : c'est un motif, mais sa cause — bug
de MAME, bug de BIOS, ou interaction — n'est pas établie.

Et **NeoPen recompilé fait moins bien que son propre binaire de 2015** : 14 contre 17. Sa source
occupe pourtant 2,7 Kio de plus. Deux explications possibles et non départagées : la chaîne de
construction diffère (binutils 2.42 de 2026 contre `m68k-elf-as` de 2015), ou le code a régressé
après la release. À refaire avec la chaîne d'origine avant d'en conclure quoi que ce soit.

## Portée, et ce qu'elle n'est pas

17 jeux sur un catalogue de 178. « Huit sur dix-sept » ne veut pas dire qu'un jeu du commerce sur
deux échoue : ça veut dire que huit ont échoué sur dix-sept essayés. Le corpus a été choisi pour
des propriétés — câble de liaison, carte mémoire, jeux d'après 1998, IP non-SNK, le plus ancien du
catalogue — et non pour représenter la distribution réelle.

Tout est mesuré **sous MAME**, jamais sur matériel. La leçon de wolfmvs vaut ici : les émulateurs
peuvent être d'accord et avoir tort tous les deux.
