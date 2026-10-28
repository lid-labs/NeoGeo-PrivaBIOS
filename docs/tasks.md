# Tâches — l'écriture du BIOS

Découpage du travail d'écriture, arrêté le 2026-10-11. **Ce fichier ne décide rien** :
`DECISIONS.md` décide. Il dit dans quel ordre écrire et comment juger, pas à partir de quoi — et
depuis que §1 est tranché, la réponse à « à partir de quoi » est **rien** : le code est écrit depuis zéro.

**Qui écrit.** Des agents d'implémentation indépendants, neufs, dont les seules entrées sont le contrat
généré par le banc et la documentation publique (§1). Le code est dans `src/c0/`.

**Non publiés.** `cosim.sh`, `cosim.cpp` et `board.h` sont le co-simulateur (`BENCH.md`), et
`docker/sprixe-ngdevkit/build.sh` la chaîne de cartouches du dépôt privé : ce dépôt ne les porte pas.

## Le principe

**Une tâche = un contrat mesurable + la commande qui le juge.** Pas de tâche dont on ne sache pas
dire, par une commande, si elle est finie.

**Le contrat est généré par le banc, jamais écrit à la main.** C'est ce qui garde la salle blanche
propre : on ne recopie le code de personne, on relit une trace de bus. Les **noms** d'appel
ci-dessous sont ceux de la documentation publique ; leurs **contrats** n'y sont pas — c'est le
constat de `DECISIONS.md` §1, « le wiki ne donne ni paramètres, ni valeurs de retour, ni registres
écrasés pour la quasi-totalité des appels ».

### Ce que le bus donne, et ce qu'il reste à prouver

Question posée : un contrat d'appel est-il lisible depuis une trace de bus, sans lire le code de
personne ? Ce qui est **mesuré**, c'est que la surface est petite et bornée — le 2026-10-11, sur
`puzzledp` sous BIOS SNK `sp-s2.sp1`, 400 000 accès 68000 tracés à partir de la trame 330,
2 334 écritures :

| Zone | Adresses distinctes | Écritures |
|---|---|---|
| RAM de travail du jeu (100000-10F2FF) | 43 | 904 |
| **RAM BIOS (10FCEE-10FFFF)** | **32** | 362 |
| Pile et RAM sous la RAM BIOS (10F300-10FCED) | 7 | 36 |
| Registres LSPC (3C000x) | 4 | 904 |
| Registres système (watchdog, entrées, sortie) | 6 | 72 |
| RAM de palette (40xxxx) | 6 | 24 |
| Backup RAM MVS (D0xxxx) | 3 | 32 |

**32 adresses de RAM BIOS, pas 82.** Le chiffre de 82 annoncé en conversation le 2026-10-10 ne se
reproduit pas sur la trace conservée ; les 10 registres, si — 4 LSPC et 6 système. Ne pas reprendre
le 82.

Ce relevé porte sur une **fenêtre de 8,5 trames** — trames 330,0 à 338,5 —, et non sur les 360 :
`COSIM_TRACE` plafonne en **accès**, pas en trames, et la trace conservée a été prise à partir de
la trame 330.

**Et dans cette fenêtre, c'est le BIOS qui exécute, pas le jeu.** Mesuré le 2026-10-11 sur la trace
conservée : **331 020 lectures dans la ROM BIOS (`$C0xxxx`) contre 80 aux adresses basses**, et
aucune écriture à `SWPROM`. Les deux seules écritures de registre de contrôle y verrouillent et
déverrouillent la SRAM de sauvegarde (`$3A000D` et `$3A001D`, `neogeo-bus.ts:1413,1429`) : **aucun
registre ne bascule la carte**. Le libellé « RAM de travail du jeu » de la table ci-dessus nomme donc une **zone mémoire**, pas son
écrivain : ces 904 écritures sont celles du BIOS.

**La carte bascule vers la cartouche à la trame 502,9** : `SWPROM` ($3A0013) y est écrit une fois, précédé d'un
`SWPBIOS` à 501,9, et ce sont les deux seules écritures de bascule sur les trames 300 à 672. Elles
tombent dans la fenêtre de l'injection de pièce de boot, trames 500 à 510. Le régime
d'écritures change au même endroit — ~290 par trame de 300 à 499, puis **3 439 par trame** sur
500-549, dont 7 712 écritures de palette sur la seule tranche 500-509. Deux relevés, pris sur une
trace régénérée de 950 trames (commande ci-dessus, avec `COSIM_TRACE_WR=1 COSIM_TRACE_FROM=300`) :
`measured/2026-10-11-regimes-trace-puzzledp.tsv` par tranches de 10 trames, et
`measured/2026-10-11-bascule-carte-puzzledp.tsv` pour les registres datés.

Trois conséquences, et elles portent sur le découpage lui-même :

- **la couche 1 n'a pas de trace de référence conservée** : « un jeu tourne » demande une fenêtre
  après la trame 503, et la seule relevée — 505,0 à 511,5, ci-dessous — n'a pas sa trace gardée ;
- **le boot n'est pas non plus couvert**, alors qu'il est le périmètre de la couche 0 ;
- **le critère de C0 est à écrire** (voir C0). La bascule tombe à la trame 502,9 sous BIOS SNK. La
  part des lectures en zone basse, **tous espaces confondus**, passe de **0,02 % à 84,8 %** entre
  les deux fenêtres — 80 sur 397 666 avant, 236 763 sur 279 352 après
  (`measured/2026-10-11-zones-de-lecture-puzzledp.tsv`). La trace qui l'a produit est antérieure au
  champ d'espace : ce chiffre ne dit rien des accès en espace programme.

**Un premier contrat a été relevé**, sur un point d'entrée : les 7 appels à `$C0044A` de la
fenêtre des trames 504,97-511,53 écrivent **34 adresses communes aux sept**, et 16 qui ne le sont pas — deux blocs de
8 mots consécutifs, `$10F2AE`-`$10F2BC` sur 5 appels puis `$10F262`-`$10F270` sur 2
(`measured/2026-10-11-contrat-c0044a-puzzledp.tsv`). Noyau stable et partie variable groupée, donc,
sur **un** point d'entrée, un jeu et un BIOS. Que le découpage tranche la question de
`DECISIONS.md` §1 reste à établir : §1 porte toujours « supposé ».

La trace est hors dépôt (`bios-trace-snk-puzzledp-360t.txt`, 11 Mo, non versionnée). Elle
se régénère depuis le co-simulateur LSPC/FX68K (non publié ici, voir `docs/BENCH.md`) :

```bash
COSIM_TRACE=400000 COSIM_TRACE_FROM=330 ./cosim.sh $ROMS/puzzledp.zip 360 sp-s2.sp1 \
    2> trace.txt
```

**`COSIM_TRACE_FROM=330` n'est pas une option de confort** : sans lui, le plafond de 400 000 accès
est consommé par le boot — il n'y en a plus un seul passé la trame 9,2 —, et la trace obtenue ne
porte pas sur ce que la table ci-dessus décrit. `COSIM_TRACE_WR=1` ne garde que les écritures, et
repousse d'autant la trame où le plafond tombe. `--pad=` joue la manette (I1).

**Ce qu'un différentiel coûte** : au débit mesuré du couple `fx68k` + `lspc2_a2`, 0,26 s par trame
simulée, une trace de 360 trames demande environ une minute et demie,
une de 900 environ quatre. Deux traces par tâche jugée.

## Les quatre couches

| Couche | Contenu | Juge |
|---|---|---|
| 0 — ça démarre | Table de vecteurs, descripteur `$400`, table de sauts `$438`, `RESET`, poignée de main `SWPBIOS` + texte du BIOS, saut vers `USER` par `SWPROM` | Voir C0 |
| 1 — un jeu tourne | `USER`, `SYSTEM_INT1`, `SYSTEM_IO`, `SYSTEM_RETURN`, crédits, soft-DIP depuis l'en-tête, backup RAM | `matrice.sh` avec notre image en variante : un nombre sur le corpus |
| 2 — les services | `MESS_OUT`, `FIX_CLEAR`, `LSP_1st`, `CARD`, calendrier, `CONTROLLER_SETUP` | Différentiel par appel : même jeu sous SNK et sous le nôtre, les deux traces comparées |
| 3 — BIOS alternatif | Police, écran de boot, persistance, région à chaud, éditeur de soft-DIP, autotests, menu in-game, gestionnaire de plantage, cheats, jukebox | **Aucun oracle** : SNK ne l'a jamais écrit |

**L'oracle s'arrête à la couche 2.** À dire avant de promettre la même rigueur partout : la
couche 3 n'a pas de trace de référence, puisque SNK n'a jamais écrit ces fonctions. Son acceptation
est visuelle, ou demande des tests à écrire.

**Le juge d'une tâche n'est pas celui d'une couche.** Une tâche se juge au différentiel, trace
contre trace. Une couche se juge à `matrice.sh`, qui note une **image de BIOS entière** sur le
corpus de romsets qu'on lui donne — 17 jeux au relevé du 2026-10-10 (`COMPATIBILITE.md`).

### Le piège d'ordonnancement

**Ne pas attaquer la couche 3 avant d'avoir fini la 2.**

## Format d'une entrée

```
## <appel ou lot>
Contrat     : specs/traces/appel_<offset>.md  (généré par le banc, non édité à la main)
              Le générateur **ne nomme rien** : il désigne un appel par son offset, et c'est
              voulu — la correspondance avec un nom public est de la documentation, pas de
              l'outil. Les noms et les crans ci-dessous viennent de la page « BIOS calls » du
              NeoGeo Development Wiki ; les tâches qui ne sont pas une entrée de la table le
              disent.
Dépend de   : <tâche>
Accepté si  : <la commande, et l'écart admis>
```

Une ligne `Pourquoi` s'ajoute quand elle porte un motif que le reste ne dit pas. Pas autrement.

# Instrument

Trois tâches qui ne produisent pas de BIOS, et sans lesquelles aucune autre n'a de contrat.

## I1 — porter l'injection d'entrées sur `cosim.sh` — **fait**
Contrat     : aucun, c'est de l'outillage
Dépend de   : rien
Accepté si  : `cosim.sh` accepte `--pad=` à la syntaxe de `cosim-frame.sh`, et deux traces du
              même jeu, avec et sans plan, divergent à partir de la trame injectée
Fait le     : 2026-10-11. `parse_pad` vit dans `board.h`, les deux bancs l'appellent,
              `cosim.sh` prend `--pad=` et le passe par `COSIM_PAD`. Mesure d'acceptation
              dans le CHANGELOG de la racine
Pourquoi    : sans plan de manette, aucune trace ne couvre ce qu'une pièce et un départ
              déclenchent, et les couches 1 et 2 restent sans spécification. `board.h` portait
              déjà `PadSegment`, `port_p1`, `pad_start` et `pad_coin` : seul le parseur du plan
              manquait, et il est désormais dans l'en-tête partagé, pas en double

## I2 — générer la spécification
Contrat     : c'est lui qui produit les contrats, dans `specs/traces/`
Dépend de   : I1
Accepté si  : un document par appel de la couche 1, et un second passage les régénère à l'octet
Pourquoi    : c'est ce document, et lui seul, que reçoit l'implémenteur. §1 lui interdit NeoPen
              et `neogeo-bios` : le contrat généré et la documentation publique sont tout ce qu'il
              a le droit de lire, donc une tâche sans contrat est une tâche qu'il ne peut pas faire
Terrain     : déblayé le 2026-10-11, et il a changé la tâche. Trois acquis et un manque :
              1. **les appels se repèrent, mais pas par la plage qu'on croyait.** Les points
                 d'entrée relevés là où le jeu tourne sont `$C0044A` (7 fois, un par trame),
                 `$C00450` et `$C004C2` — tous au-delà de `$C0043F`, la plage que ce fichier
                 retenait. Qu'elle ne reçoive alors **aucun** accès a été vu sur la trace, qui
                 n'est pas conservée : seuls les points d'entrée ci-dessus sont versionnés ;
              2. **la fenêtre utile commence à la trame 500**, le jeu ne prenant la main qu'à
                 502,9 (voir plus haut). Les traces d'avant ne spécifient que le BIOS en attente ;
              3. **la table de sauts ne se lit pas dans la ROM SNK** : ses offsets et ses noms
                 sont de la documentation publique, et désassembler l'image serait sortir de la
                 salle blanche. Le générateur découpe par offset et ne nomme rien ; la
                 correspondance offset → nom est une donnée séparée, sourcée ;
              4. **le premier geste est fait** : la trace porte désormais l'espace d'adressage,
                 lu sur les `FC` du 68000 (`cosim.cpp`, champ `sp`/`sd`/`up`/`ud`/`cs`), et son
                 format est documenté dans le README du banc. Sur la fenêtre 330-336,4 :
                 **248 140 accès en espace programme, 51 854 en espace donnée, 6 acquittements
                 d'interruption** (`measured/2026-10-11-espaces-adressage-puzzledp.tsv`, trace
                 régénérable par `COSIM_TRACE=300000 COSIM_TRACE_FROM=330 ./cosim.sh
                 $ROMS/puzzledp.zip 340`, non conservée). L'entrée dans un appel se
                 reconnaît donc à son espace, là où l'adresse seule ne le disait pas.

                 **Espace programme n'est pas « fetch d'instruction »** : `fx68k.sv:391` met le
                 bit `FC1` à 1 aussi quand l'accès est PC-relatif, et le 68000 préfetche. Le champ
                 répond « dans quel espace », pas « est-ce une instruction »

              5. **le critère de retour est trouvé, et ce n'est pas la pile** : le retour d'un
                 appel est la **transition inverse en espace programme**, du BIOS vers la P-ROM.
                 Les 9 appels des trames 504,97-511,53 se délimitent ainsi, et les 7 appels à
                 `$C0044A` reviennent tous à la même adresse, `$00026A`
                 (`measured/2026-10-11-appels-delimites-puzzledp.tsv`). Un appel fait 65 à
                 5 173 accès, médiane 722, là où une trame de cette fenêtre en compte ~45 700.
                 Trace régénérable par `COSIM_TRACE=300000 COSIM_TRACE_FROM=505 ./cosim.sh
                 $ROMS/puzzledp.zip 515` ; le découpage qui en tire ces nombres, non

              **Une limite de l'oracle** : le bus ne montre pas les **registres du 68000**, donc
              une trace ne donne pas l'affectation registre → paramètre. Les effets mémoire d'un
              appel s'y lisent, sa signature non — elle viendra de la documentation publique, ou
              manquera. Ce que le contrat a le droit de porter est tranché par `DECISIONS.md` §8.

              6. **le générateur existe** : `bench/generer-contrats.py`, python3 et
                 bibliothèque standard seule, et **ses tests sont à côté**
                 (`bench/test_generer_contrats.py`, `python3` et `unittest`, hors de `npm test`).
                 Il découpe par offset, ne nomme rien, et rend un
                 document par point d'entrée dans `specs/traces/`. **Un second passage régénère à
                 l'octet** — le critère d'acceptation de I2. Ses comptes ont été confrontés à un
                 relevé fait à la main sur `$C0044A` : 34 adresses stables et 16 variables des
                 deux côtés — **sous la convention d'alors**, qui portait l'adresse de mot. La
                 correction d'adresse du point 7 les porte à 42 et 16, et l'écart se prouve :
                 50 adresses de mot, plus les **8 mots dont les deux octets sont écrits
                 séparément**, font 58 sites. L'ancienne convention fondait ces paires en une
                 ligne, et c'est cela qu'elle perdait

              7. **les contrats portent les valeurs écrites** depuis le 2026-10-11. Une écriture
                 d'octet du 68000 pose la donnée sur **les deux moitiés** du bus — un `$80` vers
                 `$10FD82` sort `8080` —, donc le strobe dit laquelle lire : `U.` l'octet pair,
                 `.L` l'impair, `UL` le mot. Sans cette lecture une valeur serait fausse d'un
                 facteur 257, et `$10FD83` se confondrait avec `$10FD82`. Un contrat porte des
                 **sites** — une adresse *et* une largeur —, non des octets : 58 sites sur
                 `$C0044A` là où les octets touchés font 86, la largeur étant à reproduire.
                 Le contrat distingue une adresse qui reçoit **toujours la même valeur** — un
                 contrat dur — d'une qui en reçoit plusieurs, ce qui ne dit que « il écrit ici,
                 d'après un état que la trace ne montre pas »

              8. **la borne de fin d'un appel suit l'adresse empilée** depuis le 2026-10-12, et
                 non plus la sortie de la ROM du BIOS. L'ancienne borne est juste quand l'appelant
                 reprend aussitôt — un jeu qui tourne — et fausse pour un gestionnaire
                 d'interruption, qui rend la main **dans** le BIOS par un `rte` sans qu'aucune
                 transition le marque : les appels à `$C00438` étaient délimités à **46 769 à
                 46 778 accès**, soit 0,9997 à 0,9998 trame, au lieu de 1 835 à 1 847. Dans le régime où l'ancienne borne était juste,
                 la nouvelle donne le même résultat à l'octet — 722-738, 65 et 5 173 sur la
                 fenêtre 505-511 —, donc les trois contrats d'alors sont inchangés

              **La couverture est faite le 2026-10-14**, sur quatre fenêtres de `puzzledp` qui
              portent les événements de la couche 1 — le BIOS en attente, la pièce de boot et la
              bascule, le START et le début de partie, une pièce injectée en cours de partie
              (`--pad`). **La fenêtre décide de ce qu'on peut contractualiser**, mesuré :
              → `measured/2026-10-14-points-entree-par-fenetre.tsv`, qui remplace le relevé du
              2026-10-11 et porte les comptes par fenêtre.

              Les contrats versionnés sont depuis générés des **quatre traces à la fois** : le
              noyau se calcule sur l'union des régimes, une écriture stable dans une seule
              fenêtre pouvant n'être stable que dans son régime — mesuré sur `$C00438`, dont
              trois écritures LSPC quittent le noyau dès que le régime « jeu en cours » entre.
              Même date, l'autre défaut : un appel qui rend la main à la cartouche en cours de
              route se voyait attribuer ses écritures — 15 025 écritures du démarrage de partie
              du jeu sur l'appel à `$C0044A` du START. Le générateur les écarte désormais, sur
              le critère de l'espace programme, et le document compte ce qu'il écarte.

              **Un trou demeure, et il est mesuré : `$C00444` (`SYSTEM_RETURN`) ne se déclenche
              sur aucune des fenêtres relevées** — ni la pièce de boot, ni le START, ni une pièce
              en cours de partie. Son contrat demande un autre déclencheur, ou un autre jeu ; la
              tâche `SYSTEM_RETURN` de la couche 1 le dit.

## I3 — armer le watchdog du banc — **fait**
Contrat     : aucun, c'est de l'outillage
Dépend de   : rien
Accepté si  : un BIOS qui cesse de donner du pied se fait réinitialiser dans la trace
Fait le     : 2026-10-11. `board.h` tient un compte à rebours de 8 trames, rechargé à chaque
              écriture sur `0x300001` et décrémenté sur le front VSYNC ; à zéro, `cosim.cpp` tient
              la broche de reset basse 64 périodes. Démontré des deux côtés : l'auto-test du cœur,
              qui ne donne aucun coup de pied, est réinitialisé aux trames 8 puis 16 ; `puzzledp`
              sous BIOS SNK donne 1 020 210 coups de pied sur 520 trames — 1 962 par trame — et
              n'est **jamais** réinitialisé, donc aucun relevé existant ne bouge. Le compteur
              `watchdog_resets` entre au relevé de chaque trame, et `COSIM_WATCHDOG_TRACE=1` dit
              chaque reset sur stderr
Pourquoi    : `board.h` comptait les coups de pied et les avalait — un BIOS qui oublierait d'en
              donner passerait le banc et planterait la machine. La carte mémoire et le calendrier,
              eux, **sont** modélisés, la date seule étant figée : la phrase contraire de `DECISIONS.md` est périmée

# Couche 0 — ça démarre

## Deux prérequis d'outillage, constatés et levés le 2026-10-11

Ils ne sont pas dans les dépendances de C0 ci-dessous, et ils la bloquaient tous les deux. Les
écrire ici évite de les redécouvrir le jour où l'image disparaît à nouveau.

**1. La chaîne 68000 — levé le 2026-10-11.** `m68k-neogeo-elf-gcc` vit dans l'image
`sprixe-bios-build`, construite localement depuis `docker/Dockerfile` ; `build/construire.sh` la
construit quand elle manque, et rien n'est tiré d'un registre. L'image est épinglée à `linux/amd64`, les PPA ngdevkit ne publiant pas d'arm64 : sur un Mac Apple
Silicon elle tourne en émulation.

**2. Le chemin de build — levé le 2026-10-11.** `docker/sprixe-ngdevkit/build.sh` compile des
**cartouches** : il dépose `out/{p1,m1,v1}.rom` avec une P-ROM de 512 Kio, alors qu'un BIOS est une
image de **128 Kio** mappée en `$C00000`. `build/construire.sh` est cette autre cible :

```bash
./build/construire.sh build/harnais obj/harnais.sp1
```

Il assemble les `.s` et les `.c` du dossier par la chaîne du conteneur, lie par `build/bios.ld` —
vecteurs à l'offset 0, le reste en `$C00000` —, pade à 131 072 octets et **inverse les octets par
paires** : `board.h` applique `word_swap` au BIOS qu'il charge, donc une image en big-endian
natif y entrerait à l'envers.

**Le banc charge une image à soi** sans modification : un zip à part, et un nom de BIOS absent du
romset du jeu. Le dossier est hors du dépôt, l'image n'ayant pas à y entrer.

```bash
mkdir -p /tmp/sprixe-harnais
cp obj/harnais.sp1 /tmp/sprixe-harnais/sprixe.sp1
(cd /tmp/sprixe-harnais && zip -q harnais-bios.zip sprixe.sp1)
# depuis le co-simulateur LSPC/FX68K (non publié ici, voir docs/BENCH.md)
COSIM_TRACE=400 COSIM_WATCHDOG_TRACE=1 BIOS_ZIP=/tmp/sprixe-harnais/harnais-bios.zip \
  ./cosim.sh $ROMS/puzzledp.zip 20 sprixe.sp1
```

Vérifié de bout en bout par `build/harnais/`, qui n'est **pas** la couche 0 — il écrit un motif en
RAM et boucle. Sur sa trace : les quatre lectures de vecteur, le saut à `$C00008` (juste après les
huit octets de vecteurs), l'écriture `100000 WR UL 5A17 sd`, et **deux resets du watchdog** sur
20 trames, puisqu'il ne lui donne aucun coup de pied. Relevé :
`measured/2026-10-11-harnais-chaine-de-build.tsv`.

**Les deux sont levés** : plus aucun manque d'outillage ne bloque C0, dont l'écriture revient aux
agents d'implémentation de `DECISIONS.md` §1. Son « Dépend de : I2 » tient toujours, lui.


## C0 — vecteurs, descripteur, poignée de main, saut vers `USER` — **faite**
Contrat     : specs/traces/boot.md
Dépend de   : I2
Accepté si  : `cosim.sh` sur `puzzledp`, notre image, avec espace d'adressage (I2). Deux traces, la
              capture plafonnant en accès et non en trames : une depuis la trame 0 (condition 1),
              une depuis `COSIM_TRACE_FROM` avant T+2 (conditions 2 et 3, T inconnu d'avance) :
              1. `specs/traces/boot.md` régénéré sur notre image porte les mêmes **quatre mots de
                 vecteur** (`$000000`-`$000006`, en espace programme, avant tout autre accès) et
                 les mêmes **deux écritures HC259**, `$3A0003` puis `$3A000B`, dans cet ordre.
                 Ces deux points-là seulement : les comptes d'écritures en RAM ne sont pas un
                 contrat à reproduire, ils décrivent le boot de SNK
              2. `SWPROM` (`$3A0013`) est écrit **une seule fois**, à la trame T
              3. de **T+2,07 à T+8,63** — décalage et largeur de la mesure SNK, soit 6,56
                 trames —, **au moins 50 %** des accès en espace programme tombent dans la P-ROM
              Seuil : SNK mesure 0,0 % (48 sur 248 140, trames 329,97-336,38) avant la bascule et
              96,9 % (234 390 sur 241 934, trames 504,97-511,53) après, sous `sp-s2.sp1`
              (`measured/2026-10-11-espaces-adressage-puzzledp.tsv`). 50 % est un **arrondi
              au-dessus du médian de ces deux mesures**, qui vaut 48,45 % ; aucune mesure ne
              l'établit comme frontière
Juge        : `./bench/generer-contrats.py trace.txt --part-prom --de=506.97 --a=513.53`, les
              deux bornes étant T+2,07 et T+8,63 — ici avec le T de SNK, 504,9, pour l'exemple ;
              sans chevrons, qu'un shell lirait comme des redirections. Il
              retrouve les deux chiffres SNK au chiffre près, et compte comme P-ROM
              `$000080`-`$0FFFFF` : les 128 premiers octets en sont exclus, `board.h` les
              servant depuis le BIOS tant que `biosMode` tient. La banque `$2xxxxx` n'est pas
              comptée non plus
              Ne garantit pas : que le saut passe par `USER` (un BIOS qui retombe en boucle dans la
              P-ROM sans l'appeler satisfait 3), ni que ce soient des fetchs plutôt que du
              préfetch ou des lectures PC-relatives, ni que le jeu tourne juste — c'est le rôle de
              `USER`, qui en dépend
Acquis      : le banc bascule sur l'écriture `SWPROM`, la trace porte l'espace
              d'adressage (I2), et SNK date la bascule à la trame 502,9 (SWPBIOS 501,9)
Pourquoi    : petite exprès. Elle valide la chaîne de bout en bout — écrire, compiler, mesurer,
              comparer — avant qu'une tâche coûteuse en dépende
Faite le    : 2026-10-11, par un agent d'implémentation (`DECISIONS.md` §1), dans `src/c0/c0.s`. Les
              trois conditions sont remplies, et les chiffres ont été refaits
              à part du rapport de l'agent :
              1. les quatre mots de vecteur sont les quatre premiers accès de la trace, puis le
                 fetch tombe à `$C00402` ; `$3A0003` puis `$3A000B`, dans cet ordre
              2. `$3A0013` écrit **une fois**, à la période 100 847, soit **T = trame 0,124348**
              3. **247 695 / 247 713 = 99,99 %** sur la fenêtre, bornée en **périodes** et non en
                 trames arrondies — 1 779 633,56 à 7 099 846,04, soit les trames 2,19434773 à
                 8,75434773. Le juge et une lecture directe de la trace donnent le même couple
                 aux mêmes bornes. Seuil : 50 %. Un accès se trouve à moins de 0,0001 trame de la
                 borne haute, donc des bornes à 4 décimales rendent 247 696 / 247 714 : l'écart
                 est un artefact de troncature, et le relevé le dit
              Les 18 accès restants sont dans la ROM du BIOS, dont 9 sur une entrée du tableau
              d'appels. → `measured/2026-10-11-verdict-couche0-puzzledp.tsv`
              **Le jeu tourne vraiment**, ce que la condition 3 ne garantit pas : `vsync_hz` à
              59,186 dès la trame 1, les écritures VRAM qui montent de 160 à 31 545, 19 IRQ
              prises, 3 commandes son, zéro période en HALT, zéro reset du watchdog et le piège
              d'exception jamais atteint. → `measured/2026-10-11-couche0-le-jeu-tourne.tsv`
Placement   : le code vit à partir de `$C00800`, **au-delà de la table d'appels**, dont « BIOS
              calls » donne la fin à `$C006FC` et non à `$C0051C`. La première version le posait à
              `$C00600` : 23 créneaux documentés y tombaient, et un jeu qui en aurait appelé un
              aurait sauté dans la mise sous tension, réécrivant `$3A0013`. `puzzledp` ne les
              appelle pas, donc le banc n'en montrait rien — c'était une mine, pas un bug observé.
              Le remplissage de `rts` couvre désormais les **116 créneaux** de `$C0044A` à
              `$C006FC`, entrées Neo Geo CD comprises ; relevé vérifié octet par octet, et zéro
              accès dans `$C00600`-`$C00684` sur la trace
Écarts      : **six gestes de plus** que les quatre régions, de deux natures. Deux ajoutent de la
              **surface de BIOS** que le périmètre ne nommait pas, forcés par le jeu et signalés
              par l'agent ; quatre posent de l'**état de mise sous tension** — coup de pied au
              watchdog, acquittement des IRQ en attente, vidage de 3 328 octets de RAM, recopie du
              descripteur. Ces quatre-là sont des comportements de BIOS, non de simples moyens :
              « mise sous tension, et rien d'autre » les couvre, « quatre choses » non. Le **tableau d'appels** `$C00438`-`$C006FC` est rempli de
              `rts` : sans eux le premier appel à SYSTEM_IO exécute le remplissage `$FF` de l'image
              et part en exception. Et **SYSTEM_RETURN** (`$C00444`) est du vrai code, la
              cartouche y arrivant par un `jmp` — un `rts` repartirait sur une adresse périmée ;
              son bouchon d'alors a cédé la place au dispatch (SYSTEM_RETURN, plus bas)
Supposé     : **une seule chose**, et `c0.s` la nomme deux fois comme telle — le contrat de
              `SYSTEM_RETURN`. Le wiki dit que la cartouche y arrive par un `jmp`, rien de plus ;
              l'implémentation d'alors était un bouchon. Tout le reste du fichier est soit mesuré sur la trace, soit attribué à une
              page nommée du NeoGeo Development Wiki — y compris les bits de `REG_IRQACK` et les
              variables de RAM BIOS, qui étaient supposés au premier jet et ont été sourcés depuis
              (« 68k interrupts », « BIOS RAM locations »)
Descripteur : `$C00400` vaut `$80` (MVS) et `$C00401` vaut `$02` (Europe), d'après la page « System
              ROM ». Deux réserves : la page les situe à `$000400`/`$000401`, l'équivalence avec
              l'offset `$400` de l'image venant de ce que le BIOS n'occupe le bas de la carte que
              sur 128 octets ; et elle décrit les ROM système d'origine, sans dire qu'un BIOS tiers
              doive les suivre. MVS est dicté par le banc, qui modélise une MVS. **La nationalité
              est l'Europe** depuis #1365, mesure à l'appui (`c0.s`, « EUROPE, PAS JAPON »). Le démarrage **recopie** le descripteur dans `$10FD82` et
              `$10FD83` au lieu de coder les valeurs en dur, pour n'avoir qu'une source de
              vérité. Après la bascule, `puzzledp` lit l'octet `$10FD82` **64 fois** et `$10FD83`
              **23 fois** sur l'étendue de la trace, qui s'arrête à la trame 18,99 —
              `COSIM_TRACE` plafonne en accès, non en trames. Donc la recopie sert. Recompter, sur la trace que
              produit la commande de jugement ci-dessus :
              `grep -cE ' 10FD82 rd U\. ' trace.txt` et `grep -cE ' 10FD82 rd \.L ' trace.txt` —
              le banc journalise l'adresse de **mot** avec les strobes, donc `U.` est l'octet pair
              et `.L` l'impair

# Couche 1 — un jeu tourne

Toutes jugées de la même façon : `cosim.sh` sur `puzzledp` avec notre image, trace diffée contre
celle de SNK, **zéro écart sur les adresses de RAM BIOS**. Le jeu se change quand l'appel ne se
déclenche pas sur `puzzledp` ; le contrat dit alors lequel.

## USER — **faite**
Contrat     : `specs/traces/protocole.md` — aucun contrat d'appel, `USER` étant la routine de la
              **cartouche** : c'est le protocole autour d'elle qui est tracé, par le mode
              `--protocole` du générateur (ajouté pour cette tâche), sites `$10FD80`, `$10FDAE`
              et `$10FDAF` sourcés « BIOS RAM locations ». Généré le 2026-10-14 des quatre
              fenêtres, régénéré à l'octet, relu au titre de §8 : voir `RELECTURE-CONTRATS.md`
Dépend de   : C0
Accepté si  : différentiel sur `puzzledp`, zéro écart sur les adresses de RAM BIOS
Faite le    : 2026-10-14, par un agent d'implémentation (§1), dans `src/c0/c0.s` : une remise unique,
              `_remettre_a_user`, reproduit l'ordre mesuré — `$10FD80` ← `$01`, `$10FDAF` ←
              mode, `$10FDAE` ← demande, `$10FD80` ← `$82`, main à `$000122`. Le boot part en
              demande 0 (SUPPOSÉ argumenté dans le fichier : MVS sans pièce, « USER
              subroutine »), SYSTEM_RETURN relance en demande 2 mode 1. Vérifié à part du
              rapport de l'agent : relevé régénéré sur notre image, mêmes adresses dans le même
              ordre autour des deux remises, et la cartouche répond par la même suite
              d'écritures que sous le BIOS de référence (`$02`/`$82`, puis `$10FDAF` ← `$01`)
Reste       : le relevé ne couvre pas ce que le BIOS de référence fait entre les trames 9,2
              et 330 — une éventuelle demande 0 de SNK n'est portée par aucune fenêtre

## SYSTEM_INT1 — **faite**
Contrat     : specs/traces/appel_C00438.md  (`SYSTEM_INT1`, cran 9) — généré le 2026-10-12,
              **consolidé le 2026-10-14** sur deux fenêtres : 16 appels (48 depuis), deux régimes (867 accès
              quand le jeu tourne, 1 835 à 1 887 en attente). Relu au titre de §8 aux deux dates :
              voir `RELECTURE-CONTRATS.md`. Ses deux adresses de **retour** sont internes à la
              ROM du BIOS et retenues — un gestionnaire d'interruption revient là où le BIOS
              s'était interrompu
Dépend de   : C0
Accepté si  : différentiel sur `puzzledp`, zéro écart sur les adresses de RAM BIOS
Faite le    : 2026-10-14, par un agent d'implémentation (§1), dans `src/c0/int1.s` — l'entrée `$C00438`
              de `c0.s` porte le `jmp`. Ses suppositions sont marquées dans le fichier
              (registres tous préservés, tampon MESS_OUT ramené sans être interprété, crédits
              non comptés — hors du noyau). Différentiel refait à part du rapport de l'agent :
              **zéro écart sur les 37 adresses de RAM BIOS du noyau**, 22 valeurs dures sur 22
              identiques hors entrées injectées — les 8 restantes portent les entrées du plan
              de test, que les fenêtres SNK n'avaient pas
Corrigée le : 2026-10-15 — **la sortie est un `rte`, pas un `rts`** : les jeux entrent dans INT1
              depuis leur gestionnaire de vblank sans empiler d'adresse de retour, et le `rts`
              dépilait le cadre d'exception comme adresse de retour (saut à `$040000`, exception,
              piège, watchdog toutes les 8 trames — le profil des figés de la matrice). Mesuré
              sur `joyjoy` sous notre image, recoupé par les « Retour vers » du contrat
              consolidé, des PC interrompus. L'acquittement suit le contrat consolidé sur deux
              jeux : `$0007` en mode système (SUPPOSÉ : une demande timer n'y a pas de preneur),
              `$0004` en mode jeu. Différentiel réel depuis `joyjoy`, qui appelle INT1 à chaque
              vblank : zéro écart sur les 37 adresses de RAM BIOS du noyau, et notre `$3C000C`
              reçoit `$0007` — dans l'ensemble mesuré de la référence
Mesuré      : **`puzzledp` n'appelle jamais `$C00438` sous notre image** — 0 fetch sur
              950 trames, pièces et START injectés. Cause lue dans la trace : le jeu écrit
              `$80` dans `$10FD80` (« mode jeu ») dès la trame 1,9, et un jeu n'appelle INT1
              que quand le BIOS réclame le vblank. Sous SNK, 15 des 16 appels relevés viennent
              du régime d'attente, que notre BIOS n'a pas. Le différentiel est donc passé par
              une **variante jetable** (`$C0044A` détourné vers `_systeme_int1`, non versionnée,
              refaite indépendamment pour le verdict ci-dessus) — même famille de trou que
              SYSTEM_RETURN : l'appel existe, son déclencheur n'arrive pas sur ce jeu

## SYSTEM_IO — **faite**
Contrat     : specs/traces/appel_C0044A.md  (`SYSTEM_IO`, cran 12) — **consolidé le 2026-10-14**
              sur trois fenêtres, 32 appels (80 depuis), trois régimes : attente de START, START et début de
              partie, pièce en cours de partie. Relu au titre de §8 : voir `RELECTURE-CONTRATS.md`
Dépend de   : I1, USER
Accepté si  : différentiel sur `puzzledp`, pièce et départ injectés, zéro écart sur les adresses
              de RAM BIOS
Faite le    : 2026-10-15, par un agent d'implémentation (§1), dans `src/c0/io.s` : `_io_commun`, la
              routine partagée avec INT1 (« SYSTEM_INT1 » : INT1 appelle SYSTEM_IO), et l'entrée
              publique seule remet la main au jeu — COIN_SOUND `$000134` à la pièce, PLAYER_START
              `$000128` au START avec crédit, les deux mesurées (`protocole.md`). Différentiel
              refait à part du rapport de l'agent, pièce et START injectés : **zéro écart sur les
              30 adresses de RAM BIOS et les 4 de backup RAM du noyau**, et l'appel du START rend
              la main au jeu comme la référence (16 466 écritures hors contrat, le même compte).
              Le contrat d'INT1 revérifié par variante jetable après le refactoring : 37/37.
              Écartés, dits dans `io.s` : départ forcé, `$10FEE0`/`$10FEE2`/`$D0002C`/`$D00039`
              (non documentés), comptabilité datée (sans calendrier), partie gratuite,
              verrouillage des monnayeurs, pièces 3 et 4, bouton service, DEMO_END, et le passage
              démo → titre sur pièce (demande USER 3), qui relève du protocole USER

## SYSTEM_RETURN — **faite**
Faite le    : 2026-10-15 au soir, par un agent d'implémentation (§1), au **dispatch sur `$10FD81`** que
              la doc publique décrit : état du contrat posé, puis codes 0/1/2/4/5 → démo,
              3 → titre si crédit (reset `$03` du Z80 avant, mesuré), 6 → titre, inconnu → démo.
              Deux faits mesurés par la passe : **le code 6 est inatteignable chez nous** — la
              référence écrit `$02` à la pièce, pas `$06`, et rien n'a été inventé contre la
              mesure — et **`wjammers` ne repasse jamais par SYSTEM_RETURN après son init**
              (1 300 trames, 3 pièces) : le gel des passes réfutées venait d'ailleurs, cause
              jamais isolée. Témoins MAME : puzzledp, joyjoy, wjammers, trally, nam1975 jouent.
              Différentiel : noyau RAM BIOS complet, plus `$10FDAE`/`$10FDAF` — notre remise se
              fait dans l'appel, la référence après son repli ; écart dit. `$10FEE1` remis à 0
              avant la remise : écart délibéré au contrat, SUPPOSÉ dit dans le fichier
Historique  : **contrat prêt, implémentation réfutée une fois** (détail ci-dessous)
Contrat     : specs/traces/appel_C00444.md  (`SYSTEM_RETURN`, cran 11) — **généré le 2026-10-15
              au soir**, de la neuvième trace (le game over de `nam1975`, trames 5 315-5 330),
              consolidé avec l'appel interne du boot de la référence (238,80). Relu au titre de
              §8 : voir `RELECTURE-CONTRATS.md`
Dépend de   : USER
Accepté si  : différentiel sur `puzzledp`, zéro écart sur les adresses de RAM BIOS — **et aucune
              régression à la matrice** : le différentiel seul ne suffit pas, c'est la leçon
              ci-dessous
Réfutée le  : 2026-10-15 au soir — une implémentation au contrat (mode système, état posé,
              attente de deux INT1, puis salve son à la position mesurée) **passe son
              différentiel (noyau 6/6, zéro écart) et gèle pourtant `wjammers` sous MAME à la
              pièce**, dans ses deux versions. La bissection a innocenté `$3C0006` et réfuté
              « demande 3 quand un crédit est là » (pire : gel dès 100). Le banc ne voit pas ce
              gel : ses réponses son forcées le masquent. **Préalables à la reprise** : une sonde
              lua côté MAME (PC et variables au moment du gel) — **faite depuis, `bench/sonde.lua`**
              — et la recherche en doc publique
              sur le cycle demande/mode au retour. Le code vit au bouchon de la
              couche 0, qui fait tourner 13/17
Lu le       : 2026-10-15 au soir, « BIOS RAM locations » (wiki) — **`$10FD81`
              (BIOS_SYSRET_STATUS) est « le code de fonction que SYSTEM_RETURN appellera »**,
              documenté code par code : 0 init backup RAM / sélection eye-catcher, 1 LED,
              2 slot suivant + eye-catcher, 3 après game over → mode démo, 4/5 changement de
              slot (select), **6 après une pièce → « does nothing »**. L'appel est donc un
              dispatch sur `$10FD81`, pas une routine unique — notre bouchon, qui relance
              toujours la démo, contredit le code 6, ce qui colle au gel de `wjammers` à la
              pièce. Notre SYSTEM_IO écrit déjà `$10FD81` ← `$03` au START (mesuré, contrat
              C0044A). La prochaine passe implémente le dispatch ; la demande 3 au titre est
              « called when a coin is inserted on MVS only » (« USER subroutine »), et
              `$10FEC5` (BIOS_TITLE_MODE) porte le quirk du double titre après game over
Chassé le   : 2026-10-15, sur 4 000 trames de `puzzledp` sous BIOS SNK
              (`measured/2026-10-15-chasse-c00444-puzzledp.tsv`). Deux faits : **le BIOS SNK
              exécute lui-même `$C00444` à la trame 238,8**, pendant son propre boot — la seule
              fenêtre mesurée à ce jour ; et **aucun
              déclenchement côté cartouche** entre le départ de partie (560) et la trame 4 000 —
              `puzzledp` sans entrées n'atteint pas le game over en 67 s. Candidat suivant : un
              jeu qui meurt sans entrées (`nam1975`, ~7 000 trames)
Trouvé le   : 2026-10-15 au soir, sur `nam1975` en écritures seules : **le game over du joueur
              laissé sans entrées, à la trame ~5 321** (~90 s) — le BIOS de référence y écrit
              mode `$01` puis demande `$02`, la signature de SYSTEM_RETURN relançant la démo.
              La fenêtre 5 315-5 330 est la fenêtre du contrat ; sa trace complète et la
              génération du contrat sont le prochain lot

## Crédits et soft-DIP de l'en-tête — **faits**
Contrat     : specs/traces/appel_C00450.md  (`CREDIT_CHECK`, cran 13) — **consolidé le
              2026-10-14** sur trois fenêtres, 23 appels (69 depuis), relu au titre de §8 — et l'en-tête de la
              cartouche, qui n'est pas un appel
Dépend de   : SYSTEM_IO
Accepté si  : différentiel sur `puzzledp`, pièce injectée, zéro écart sur les adresses de RAM BIOS
Fait le     : 2026-10-15, pour les **crédits** : `_credit_check` (`src/c0/io.s`) au contrat —
              différentiel refait à part, zéro écart (2 adresses de RAM BIOS du noyau) — et le
              créditage d'une pièce dans `_io_crediter` (compteur `$D00024`+joueur, crédit BCD
              `$D00034`/`35` par `abcd`, réglages `$D0003A`-`$D0003D`, zéro lu comme 1 sur une
              backup RAM non initialisée — SUPPOSÉ, dit dans le fichier)
Corrigé le  : 2026-10-16 — trois réfutations par la mesure (jig lua et sonde sur `wjammers`) :
              le boot **relâche les coin lockouts** (`REG_RESETCL1/2`, sans quoi MAME ne
              présente jamais la pièce sur `$320001` et aucun crédit n'entre) ; la garde START
              porte sur le **crédit du joueur**, non sur `BIOS_CREDIT_DEC` (la référence accepte
              un START avec DEC à zéro) ; la déduction est **1 crédit par joueur parti**
              (mesuré `$02`→`$01` et `$01`→`$00`, demande du jeu ignorée), non « DEC relu ».
              Vérifié : `wjammers` lance une partie (mode 2), cellules identiques à la
              référence ; relevé `measured/2026-10-16-matrice-start-credit.tsv`
Soft-DIP    : **faits le 2026-10-16** — la mesure qui manquait est venue de `kof98`, qui lit
              `BIOS_GAME_DIP` à son init. Au premier boot d'un jeu, le boot décode le bloc
              soft-DIP de la cartouche (pointeur de la région, `$11E` pour l'Europe) : 6 octets
              tels quels, puis le quartet haut de 10 réglages, et les recopie dans le bloc de
              sauvegarde du jeu ; aux boots suivants, il les relit de ce bloc. Juge : un jig
              (4 jeux) égal à la référence octet pour octet, et la relecture du bloc prouvée
              (`measured/2026-10-16-soft-dip.tsv`, `measured/2026-10-16-matrice-soft-dip.tsv`)

## Backup RAM — **faite**
Contrat     : la zone `backup_ram` des contrats d'appel — aucune entrée de la table n'y est
              dédiée
Dépend de   : SYSTEM_IO
Accepté si  : différentiel sur `puzzledp`, zéro écart sur la zone `D0xxxx` — 3 adresses au relevé
              du 2026-10-11
Complétée le : 2026-10-16 — le boot **formate la zone système** quand la signature
              « BACKUP RAM OK ! » + $80 ($D00010-$D0001F, mesurée ; la page « Backup RAM » du
              wiki la documente) manque : valeurs mesurées (réglages monnayeur $01…$03,
              compteurs, minuteurs), zéros ailleurs sur $D00000-$D0007F, signature écrite en
              dernier, et rien touché quand elle est présente (persistance NVRAM). Déclencheur :
              kof98 reboote au watchdog après lecture de la zone vierge ; sa cause restante est
              en aval (relevé `measured/2026-10-16-matrice-format-backup.tsv`)
Faite le    : 2026-10-15, par le même lot que SYSTEM_IO : les 3 adresses du relevé du 2026-10-11
              (`$D00020`-`$D00022`, le front de pièce) sont dans le noyau apparié, comme
              `$D0005D` ; les chemins à état communs collent (`$D00024`, `$D00034`, `$D00038`,
              `$D0004C`). Trois familles restent écartées, dites dans `io.s` : `$D0002C`/`$D00039`
              (non documentés), la **comptabilité datée** `$D08324`-`$D0A1D2` (demande le
              calendrier, couche 2), la partie gratuite `$D00042`. `$D0005C` n'apparaît que chez
              nous : la cascade des secondes, que les fenêtres SNK ne traversent pas

## Table d'aléa — **faite**
Contrat     : pas de contrat généré possible — les jeux déclencheurs sont hors banc cosim.
              Remise : `measured/2026-10-16-kof98-diagnostic-remise.tsv` et la relecture du même
              jour dans `RELECTURE-CONTRATS.md`
Dépend de   : C0
Accepté si  : matrice 20 sans régression, et `svc` qui joue
Faite le    : 2026-10-16 (`src/c0/alea.s`, ancrée par `build/bios.ld`). Des jeux lisent la ROM
              du BIOS en `$C04200-$C042FF` comme table d'aléa et exigent des tirages différents
              modulo 9 ; sur du padding `$FF`, boucle infinie et reboot au watchdog. Une
              permutation de 0..255, calculée, et une garde de lien qui refuse tout code au-delà
              de `$C04000`. `svc` joue (`measured/2026-10-16-matrice-table-alea.tsv`)
Reste       : levé par le lot suivant pour `kof98` et `mslug3` (la demande 0 au premier boot
              seulement) ; `garou` reste rouge

## La demande 0 au premier boot seulement — la table des slots — **faite**
Contrat     : pas de contrat généré — jeux hors banc cosim. Remise :
              `measured/2026-10-16-demande-0-slots.tsv` et la relecture du même jour
Dépend de   : USER, Backup RAM
Accepté si  : jig `kof98` deux runs sur la même NVRAM (demande 0 une fois, puis demande 2), et
              matrice 20 sans régression
Faite le    : 2026-10-16 (`src/c0/c0.s`, fin du boot). La référence ne remet la main en
              demande 0 qu'au premier boot d'un jeu : elle inscrit son NGH dans la table des
              slots (`$D00124`, huit entrées NGH + bloc), et au boot suivant elle le retrouve et
              remet la main en demande 2, mode 1. `kof98` finit sa demande 0 par un reset voulu :
              rappelée à chaque boot, elle le faisait boucler. `kof98` et `mslug3` jouent
              (`measured/2026-10-16-matrice-demande-0.tsv`)
Reste       : `garou`, qui faisait planter MAME, joue depuis le 2026-10-22 (« départs refusés »,
              plus bas). Et le non tranché de la remise, dit SUPPOSÉ dans `c0.s` : la date `$D00104`, le
              parcours de `$D00108`, le slot libre, la table pleine

## Le départ forcé (« game start compulsion ») — **fait**
Contrat     : pas de contrat généré — remise : `measured/2026-10-17-diagnostic-b2b-minasan.tsv`
              (partie MINASAN) et la relecture du même jour
Dépend de   : SYSTEM_IO, crédits
Accepté si  : jig `minasan` (pièces à 300 et 900, sans START : la partie part seule), et
              matrice du corpus sans régression
Fait le     : 2026-10-17 (`src/c0/io.s`, `_io_crediter` et `_io_compulsion`). Une pièce arme
              `$10FDDA` à `$D00044` (30 s, BCD) ; au titre, SYSTEM_IO le décompte, et le passage
              des secondes à 00 prend le chemin d'un START du joueur 1. `minasan` joue
              (`measured/2026-10-17-matrice-depart-force.tsv`, 20/22)
Reste       : le décompte suspendu pendant FRAME_SKIP (11 trames d'écart avec la référence),
              SUPPOSÉ dans `io.s` ; `b2b` (remise trop près du vblank, puis écran noir non
              diagnostiqué)

**Sortie de couche** : `matrice.sh` avec notre image en variante rend un nombre sur le corpus. La
couche est finie quand ce nombre ne monte plus en corrigeant la couche 1 seule.

Premier nombre, le 2026-10-15 : **6/17** (SNK 17/17, UniBIOS 17/17, nullbios 9/17 à la campagne
de référence) — `measured/2026-10-15-matrice-couche1.tsv`, qui dit le compte croisé
verdict × vifs et ses cas limites (samsho2, wjammers, trally). **Sept jeux figent dès la
trame 100, écran noir** (et garou dès 300) : cause non
diagnostiquée à ce relevé. C'est le prochain gain du
nombre : diagnostiquer un figé (le plus petit : `joyjoy`), sous SNK puis sous notre image.

Deuxième nombre, le même jour : **11/17** après le correctif `rte` de SYSTEM_INT1
(`measured/2026-10-15-matrice-couche1-rte.tsv`) — le diagnostic de `joyjoy` a mené au `rts`
dépilant le cadre d'exception, et la correction débloque joyjoy, mslug, ridhero, samsho2 et
ssideki4. Restent six : garou, kof98, mslug3, svc (écran noir, une autre famille), trally (joue
2 600 trames puis fige), wjammers (image riche gelée dès 100). Causes non diagnostiquées.

Premier nombre sur le **catalogue complet**, le même soir : **117/164** (SNK 162, UniBIOS 162,
nullbios 93) — `measured/2026-10-15-matrice-catalogue.tsv`, mesuré sur l'image du handshake
(#1358). Les 46 jeux qui jouent sous SNK et pas sous nous se classent, à vue de noms et sans
diagnostic : P-ROM chiffrées ou à banques, machines multi-slot sans cartouche (`ng_mv*`), et
une vingtaine à diagnostiquer. Les planches SNK|sprixe sont hors dépôt,
non versionnées.

Troisième nombre, le même jour : **13/17** après le handshake son du boot et la bascule de la
M1 cartouche (`measured/2026-10-15-matrice-couche1-son.tsv`) — le diagnostic de `wjammers` a
montré un pilote son qui attend une réponse que notre boot muet ne provoquait pas, et la passe
de l'agent d'implémentation a trouvé plus profond : REG_CRTFIX n'était jamais écrit, le Z80 exécutait la SM1 de la
carte. wjammers et trally se débloquent. **Restent quatre, deux familles** : garou, mslug3, svc —
les trois jeux à protection SMA/PVC du corpus, figés noirs — et kof98 (« joue » noir à ~58 %).
Le banc cosim ne peut pas les héberger (plusieurs P-ROM, qu'il ne concatène pas) : leur
diagnostic passera par une sonde lua sous MAME ou une extension du banc.

**La suite, le 2026-10-16.** Le relevé passe de 17 à **20 jeux** : `magdrop2`, `flipshot` et
`neomrdo` s'y ajoutent, et les 17 premiers restent les témoins. Les chiffres comptent « joue »
avec des pixels allumés.

| Étape | PR | Sur 20 | Témoins /17 | Ce qui bouge |
|---|---|---|---|---|
| pièces, START, déduction | #1364 | 14 | 13 | `magdrop2` se débloque |
| code pays Europe | #1365 | 15 | 13 | `flipshot` |
| FRAME_SKIP | #1366 | 15 | 13 | `neomrdo` sort du noir, reste figé |
| FIX_CLEAR, LSP_1st | #1367 | 16 | 13 | `neomrdo` ; la famille des poses est close |
| formatage backup | #1368 | 16 | 13 | aucun gain, `kof98` change de cause |
| table d'aléa | #1369 | 17 | 14 | `svc` |
| demande 0 au premier boot | #1370 | **19** | **16** | `kof98`, `mslug3` |
| soft-DIP de la cartouche | #1371 | 19 | 16 | aucun gain attendu : fidélité des réglages |

Le 2026-10-17, le corpus passe à **22 jeux** avec `b2b` et `minasan`, rouges au catalogue : 19/22
sur l'image de #1371, **20/22** avec le départ forcé (`minasan`), **21/22** avec MESS_OUT (`b2b`).

Au catalogue complet, le 2026-10-19 : **157/164** sur l'image de #1375, contre 155 le 2026-10-16
(`measured/2026-10-19-matrice-catalogue.tsv`).

Au corpus, `garou` (MAME plantait) restait le seul rouge ; il joue depuis le 2026-10-22. Chaque ligne a son
relevé daté dans `measured/` (`2026-10-16-matrice-*.tsv`), et `measured/HISTORIQUE.md` les
reprend toutes, essais rejetés compris.

# Couche 2 — les services

## MESS_OUT — **faite**
Contrat     : pas de contrat généré — `b2b`, le jeu qui l'exige, n'est
              pas au banc cosim. Remise : `measured/2026-10-17-b2b-mess-out.tsv` et la page
              « MESS_OUT », relecture du 2026-10-17
Dépend de   : couche 1
Accepté si  : différentiel par appel (`bench/mess-diff.lua`) sans écart sur `b2b`, et matrice du
              corpus sans régression
Faite le    : 2026-10-17 (`src/c0/mess.s`, l'entrée `$C004CE` et SYSTEM_INT1). Les quatorze
              commandes de la page ; `BIOS_MESS_POINT` posé à `$10FF00` au boot. Livrée avec la
              remise calée sur le vblank (`c0.s`), sans laquelle `b2b` boucle en exception. `b2b`
              joue ; 407 listes communes, 407 sorties LSPC égales
              (`measured/2026-10-17-matrice-mess-out.tsv`, 21/22)
Reste       : les commandes que `b2b` n'emploie pas ne sont jugées par aucune mesure — polices
              des commandes 8 et 9, signe de l'auto-incrément, état initial d'un appel : SUPPOSÉ
              dans `mess.s`

## FIX_CLEAR — **faite**
Contrat     : specs/traces/appel_C004C2.md  (`FIX_CLEAR`, cran 32)
Dépend de   : couche 1
Accepté si  : différentiel, zéro écart sur les écritures VRAM du plan fix
Faite le    : 2026-10-16 (`src/c0/video.s`), déclenchée par le diagnostic de `neomrdo` : le jeu
              joue derrière un plan fix jamais effacé. Jugée au noyau du contrat (les trois
              registres LSPC, valeurs reproduites) et à la matrice — `neomrdo` passe à
              « joue, pose 0 », `wjammers`/`magdrop2`/`flipshot` perdent leurs poses
              (`measured/2026-10-16-matrice-fix-clear.tsv`). Le différentiel par appel n'a pas
              couru : il reste dû si un écart réapparaît

## LSP_1st — **faite**
Contrat     : specs/traces/appel_C004C8.md  (`LSP_1st`, cran 33)
Dépend de   : couche 1
Accepté si  : différentiel, zéro écart sur les registres LSPC — 4 adresses au relevé du 2026-10-11
Faite le    : 2026-10-16, même lot et mêmes juges que FIX_CLEAR. Lecture SCB1 au pas de 2
              (seule qui donne un rôle au `$0002` du contrat), les attributs impairs non
              écrits — SUPPOSÉ, dit dans `video.s`

## CONTROLLER_SETUP
Contrat     : prévu specs/traces/appel_C004D4.md  (`CONTROLLER_SETUP`, cran 35), non généré
Dépend de   : I1, couche 1
Accepté si  : différentiel avec plan de manette, zéro écart sur les adresses de RAM BIOS
Témoins     : aucun jeu du catalogue ne l'appelle en 3 000 trames sous SNK
              (`measured/2026-10-19-appels-catalogue.tsv`)

## CARD — **faite**, avec et sans carte, et CARD_ERROR
Contrat     : pas de contrat généré (`CARD`, cran 17) — les jeux qui
              l'appellent ne vont pas jusqu'à l'appel au banc cosim. Remises :
              `measured/2026-10-19-card-sans-carte.tsv` et `2026-10-19-card-avec-carte.tsv`,
              relectures du 2026-10-19
Dépend de   : couche 1
Accepté si  : différentiel sur un jeu qui écrit la carte, zéro écart sur les adresses de RAM BIOS
              et sur la zone `800xxx`, que le banc modélise
Témoins     : 82 jeux du catalogue l'appellent, 1 à 3 fois chacun en 3 000 trames sous SNK, dont
              11 des 22 du corpus (`measured/2026-10-19-appels-catalogue.tsv`). Ils jouaient avec
              le `rts` : la matrice ne juge pas ce service
Faite le    : 2026-10-19 (`src/c0/card.s`). Sans carte : `$10FD00` ← SP d'entrée − 4,
              `$10FCF4` ← `$FF`, BIOS_CARD_ANSWER ← `$80` (#1377, `bench/card.lua`). Avec carte :
              les huit commandes sur une carte 8 bits de 2 Kio, et CARD_ERROR (`$C0046E`), qui
              formate puis refait une sauvegarde refusée. Jugée par `bench/carte-diff.sh` : 13 appels
              provoqués sous SNK et sous notre image, mêmes cartes de départ ; mêmes réponses,
              écritures en RAM de CARD, octets de carte et registres de carte, 13 sur 13. Corpus
              21/22 (`measured/2026-10-19-matrice-card-avec-carte.tsv`)
Reste       : les cartes 16 bits et de plus de 2 Kio, les sauvegardes sur plusieurs blocs, le sens
              de la commande `$05`, les autres cas de CARD_ERROR : SUPPOSÉ dans `card.s`, non jugés

## Calendrier — **READ_CALENDAR faite**, reste SETUP_CALENDAR
Contrat     : prévus specs/traces/appel_C0045C.md et `appel_C00462.md` (`READ_CALENDAR` cran 15,
              `SETUP_CALENDAR` cran 16), non générés. Remise de READ_CALENDAR :
              `measured/2026-10-19-read-calendar.tsv`, relecture du 2026-10-19
Dépend de   : couche 1
Accepté si  : différentiel, zéro écart sur les adresses de RAM BIOS
Pourquoi    : la date du banc est figée : rien de temporel n'est exercé
Témoins     : `READ_CALENDAR` appelé par 35 jeux du catalogue en 3 000 trames sous SNK, `blazstar`
              309 fois, et 4 du corpus ; `SETUP_CALENDAR` par aucun
              (`measured/2026-10-19-appels-catalogue.tsv`)
Faite le    : 2026-10-19, READ_CALENDAR (`src/c0/cal.s`) : commandes `$3` et `$1` au µPD4990A,
              52 bits lus, sept octets BCD en `$10FDD2-$10FDD8`. Jugée par `bench/cal.lua` sur
              blazstar et trally : mêmes accès et mêmes écritures que SNK, même date ; corpus
              21/22 (`measured/2026-10-19-matrice-read-calendar.tsv`)
Reste       : SETUP_CALENDAR, qu'aucun jeu du catalogue n'appelle ; l'initialisation de l'horloge
              au boot de la référence (commandes `$8` puis `$7`), hors service

## Le multi-slot, mesuré le 2026-10-21

Notre BIOS sert toujours le slot 0. La référence, mesurée sous MAME sur la MV-6F (`neogeo`, six
emplacements ; il faut `-hashpath` vers le dossier `hash` de MAME pour monter `-cart1`…`-cart6`
depuis des romsets), fait ceci (`measured/2026-10-21-multi-slot.tsv`, jig `bench/multislot.lua`) :

- **Détection**, une fois par boot, dans une trame : $D00047 ← nombre de slots de la carte (6, pas
  le nombre de cartouches), puis pour k = 0 à 5 : $D00108 ← k, REG_SLOT ← k, lecture de l'en-tête
  ($000100…) ; un slot vide est sauté.
- **Table** : l'entrée k de $D00124 est le **slot physique k** (huit entrées écrites), index de bloc
  au plus petit libre dans l'ordre des slots ; au premier boot, une demande 0 par slot nouveau.
  Notre `c0.s` cherche au contraire le NGH dans la table.
- **Démo** : le BIOS ne change de slot que quand le jeu lui rend la main (SYSTEM_RETURN, code 2) ;
  passage en trois trames ($01, écho, REG_SLOT, REG_CRTFIX, REG_SWPROM, $03, demande 2) ; slots
  vides sautés ; le logo au retour sur le slot 0.
- **Sélection** : SELECT P1 / P2 (bits 9 et 11 du mot de REG_STATUS_B), avec un crédit seulement,
  sur l'écran titre : codes 4 et 5 de SYSTEM_RETURN, puis demande 3 sur le nouveau slot.

Restent à établir : le contenu des écritures de sauvegarde au changement de slot, $D00144+, $D00109,
et la MV-2F réelle (MAME 0.286 a aussi `ng_mv1`, `ng_mv1f`, `ng_mv2f` et `ng_mv4f`, mais donne
la MV-2F à quatre slots ; il faut un zip `ng_mvXf` substitué dans le rompath). L'écriture se découpe en quatre lots, jugés par le
même jig sur notre image : détection et table, premier boot par slot, rotation de la démo, sélection.

**Lot 1 fait** (2026-10-22, `c0.s`) : $D00047 d'après REG_SYSTYPE et REG_STATUS_A (6, 4 ou 2), la
boucle $D00108 / REG_SLOT, la table indexée par slot physique — égale à l'octet à la référence sur
13 runs, y compris un slot vide entre deux, une cartouche seule au slot 1 et le même jeu monté deux
fois (le doublon de NGH compte comme slot vide, mesuré sur la référence et lu dans « Backup RAM ») —,
et le premier slot occupé servi (`measured/2026-10-22-multi-slot-lot1.tsv`). Les autres slots gardent
leur NGH avec un bloc $FFFF : leur demande 0 est le lot 2. Non écrits : $D00058, $D0011A+k, la date
$D00104, $D00144+, $D00164+, le nom du jeu en $D002A0+.

**Lot 2 fait** (2026-10-22, `c0.s`, `cheats.s`) : au premier boot, chaque slot nouveau reçoit son
bloc au plus petit libre, son nom ($D002A0+16b), ses soft-DIP décodés de SA cartouche, et sa demande
0, l'un après l'autre par SYSTEM_RETURN (code 0), avec le passage de slot dans l'ordre mesuré ($01,
écho, REG_SLOT, CRTFIX, SWPROM, $03) — que le boot emploie désormais aussi. Table, blocs et noms
égaux à la référence sur 9 runs (`measured/2026-10-22-multi-slot-lot2.tsv`) ; une cartouche seule
garde exactement ses remises. Les cheats sont oubliés à chaque passage. Non écrits, et lus par aucun
des 22 jeux (`2026-10-22-bram-lue-par-les-jeux.tsv`) : la date $D00104/$D00144+, $D00164-$D001A3,
$D0011E-$D00121. Pas de logo au retour sur le premier slot (la référence en joue un).

**Lot 3 fait** (2026-10-22, `c0.s`) : la rotation de la démo. Mesuré d'abord : à chaque fin de jeu
(SYSTEM_RETURN), la référence sauve la zone de données du jeu (pointeur $00010E, taille $000112 de son
en-tête) en $D00320 + $1000 × bloc, et la restaure avant chaque demande 2. Notre code 2 passe au slot
occupé suivant (vides sautés, bouclage) avec la même sauvegarde et la même restauration : structure,
adresses, tailles et sommes égales à la référence sur 6 runs, deux tours complets compris
(`measured/2026-10-22-multi-slot-lot3.tsv`). Les cheats sont oubliés au passage
(`2026-10-22-cheats-au-passage.tsv`).

**Sauvegarde du jeu seul faite** (2026-10-22, `c0.s`) : la référence sauve et restaure aussi le jeu
seul — sauvegarde aux codes 0, 2 et 3 de SYSTEM_RETURN, restauration avant la demande 2 du boot et
après un code 0 ou 2, jamais après un code 3. Notre image fait la même suite, à la seconde
restauration près que la référence fait après son logo : structure et sommes égales sur puzzledp,
nam1975 et mslug ; aof a la même structure, mais des sommes qui diffèrent d'un octet du jeu, timing
d'avant ce lot (`measured/2026-10-22-sauvegarde-jeu-seul*.tsv`). Preuve visible : un score posé
dans la table de puzzledp survit au redémarrage, comme sous la référence ; l'image d'avant le
perdait (`2026-10-22-sauvegarde-jeu-seul-puzzledp.tsv`).

**Lot 4 fait** (2026-10-22, `io.s`, `c0.s`) : la sélection. Mesuré sur la référence (11 runs, 1 à 3
cartouches, slot vide entre deux) : au titre (demande 3, mode 1) avec un crédit, SELECT P1 écrit
$10FD81 ← $04 et passe au slot occupé suivant, SELECT P2 ← $05 et au précédent, vides sautés,
bouclage dans les deux sens ; pris au front seulement, et pas avant que FRAME_SKIP ($10FEE1) soit à
zéro ; ignoré en démo sans crédit et en partie ; le crédit n'est pas touché. La trame suivante :
sauvegarde du jeu sortant, passage de slot, restauration du jeu entrant, remise en demande 3 mode 1.
Notre image fait la même suite sur 6 runs (`measured/2026-10-22-multi-slot-lot4*.tsv`). Écarts :
**une cartouche seule ignore SELECT chez nous**, alors que la référence relance son titre avec
sauvegarde et restauration du même bloc (choix restreint, le comportement d'avant ce lot) ;
**FRAME_SKIP atteint zéro deux trames plus tard que chez la référence après une remise**, si bien qu'un
SELECT à 10 trames n'est pris qu'à 12 — le même mécanisme sert START et la pièce, ouvert. Vu en
passant, hors lot : la référence remet le crédit $D00034 à zéro au boot NVRAM gardée, pas nous ; et
une pièce qui ne fait pas encore de crédit (deux pièces par crédit) mène chez nous au titre, pas chez
elle.

**Les trois écarts du lot 4 sont corrigés** (2026-10-22, `c0.s`, `io.s`), chacun mesuré d'abord
(`measured/2026-10-22-ecarts-remise-credit*.tsv`) : FRAME_SKIP entre à $09 à chaque demande 2 ou 3,
comme la référence (28 remises sur 28), et atteint $00 neuf trames après, au lieu de onze — START, la
pièce et SELECT ne prennent plus deux trames de retard ; au boot, $D00020-$D00039 (front de pièce,
compteurs partiels, crédits) est remis à zéro, NVRAM neuve comme gardée ; une pièce qui ne fait pas
encore de crédit arme le départ forcé et joue COIN_SOUND sans quitter la démo. Restent ouverts : à la
pièce qui fait le crédit, la référence appelle DEMO_END et rend la main deux trames plus tard ; au
boot, elle remet aussi PLAY TIME ($D00048-$D0004B) à zéro et pose $D0004C, $D0005A-$D00061.

**La pièce qui fait le crédit passe par DEMO_END** (2026-10-22, `io.s`, `c0.s`, `int1.s`) : mesuré
(`measured/2026-10-22-piece-demo-end*.tsv`, DEMO_END observé par un tap de lecture sur $00012E de la
cartouche), la référence crédite, joue COIN_SOUND, écrit $10FD81 ← $06 et appelle DEMO_END dans le
même SYSTEM_IO, IRQ masquées ; au retour $10FD80 ← $02, puis la trame suivante $10FD81 ← $02 et la
remise en demande 3. Certains jeux y travaillent vraiment (aof, mslug, b2b — qui rappelle SYSTEM_IO
depuis DEMO_END, d'où une garde contre la réentrée). Notre image fait la même suite, trames comprises,
sur puzzledp, aof, mslug, nam1975 et garou. Au boot, PLAY TIME ($D00048-$D0004B) ← 0, $D0004C ← $3B,
$D0005E-$D00061 ← $FFFF0000, comme la référence ; $D0005A-$D0005D, qu'elle tire de l'heure du
calendrier et qu'aucun des 22 jeux ne lit, n'est pas repris. La matrice de référence du harnais
devient `2026-10-22-piece-demo-end-matrice.tsv` : la pièce de la sonde en démo rend désormais le
titre une trame plus tard, comme la référence, et svc diverge en partie (vifs −2,7 %), verdicts égaux.

**Le crédit en trop de garou et d'alpham2 ne vient pas du décompte** (2026-10-22,
`measured/2026-10-22-credit-au-depart*.tsv`) : sur aof et mslug, nos
écritures du crédit égalent la référence trame pour trame. garou relance la machine après sa demande
0 ; la référence refait alors son test mémoire et la pièce de la sonde à la trame 300 tombe pendant
ce second boot, où elle n'est pas créditée ; chez nous la démo tourne déjà et la pièce crédite. Sans
cette pièce, nos écritures égalent celles de la référence et CREDITS vaut 09 : c'est l'instrument.
alpham2 diverge en jeu dès la trame 611 ; il lit
$C04000-$C041FF comme une table du sinus, que nous remplissions de $FF. Elle y est depuis le
2026-10-28 (#1458, `DECISIONS.md` §18 pt 6) : la valeur retenue ($0001 pour 1,0) a été redérivée
par un agent neuf, par la seule mesure du jeu sur notre image, après qu'un premier agent eut relevé
quatre mots de la ROM SNK (`DECISIONS.md` §28) ; les octets essayés le
2026-10-22 n'y changeaient rien au crédit.

**La répétition du joystick et $10FD81 au START égalent la référence** (2026-10-22, `io.s`,
`measured/2026-10-22-repetition-et-start*.tsv`), mesuré sur alpham2 et aof, 386 trames :
tout changement de l'état courant recharge le minuteur à $10 et pose REPEAT ← courant ; sinon il
décompte, et sous zéro recharge $08 et pose REPEAT ← courant — première répétition à 17 trames, puis
toutes les 9, et le cycle $08 → $00 tourne même sans rien tenu. $10FEE8-$10FEF3 est, à chaque trame,
la copie des douze octets $10FD94-$10FD9F ; nous y écrivions $0000. Au START, $10FD81 ← $03 n'est
écrit qu'après PLAYER_START et si le jeu a gardé un bit de $10FDB4, après $10FDDA ← 0 et avant le
décompte. CREDIT_CHECK écrit le mot $10FDB2 en premier, comme la référence. Les blocs de manette
égalent la référence sur 386 trames sur 386 (243 différaient). La matrice de référence du harnais
devient `2026-10-22-repetition-et-start-matrice.tsv` : svc s'écarte de +2,6 % de la précédente, et
se rapproche de la colonne snk (écart moyen 2 571 → 344 vifs sur 25 relevés). Reste, vu en passant :
à la pièce créditée, la référence écrit $D00034 avant $10FDDA ← $30, nous l'inverse.

**FRAME_SKIP sous INT1, la pièce sous INT1, et le code 2 avec un crédit** (2026-10-23, `int1.s`, `io.s`,
`c0.s`, `measured/2026-10-22-frame-skip-et-mode0*.tsv`) : mslug appelle SYSTEM_INT1 cinq trames après
une remise avant son premier SYSTEM_IO, et la référence décompte FRAME_SKIP à chacun de ces appels ;
notre image aussi désormais ($00 à remise + 9 au lieu de + 14 ; l'écart d'un chiffre de TIME est
fermé). Une pièce créditée sous INT1 ne remet plus au titre : elle crédite et marque le son, et le
premier SYSTEM_IO où FRAME_SKIP est nul joue COIN_SOUND puis DEMO_END, aux trames de la référence. Un
SYSTEM_RETURN code 2 avec un crédit présent donne le titre (après la rotation en multi-slot), mesuré en
forçant le crédit, une et deux cartouches. À la pièce, $D00024 puis $D00034 précèdent l'armement du
départ forcé, comme la référence. Les 21 runs du multi-slot et de la sauvegarde sont inchangés. Non
reproductible sans logo : une pièce prise pendant le logo de la référence (b2b, trame 3300), et le
titre d'une pièce prise sous INT1 en demande 0, qui vient chez nous 4 trames plus tôt.

**La comptabilité suit la référence** (2026-10-23, `io.s`, `int1.s`, `c0.s`,
`measured/2026-10-23-comptabilite*.tsv`) : PLAY TIME compte pendant la partie, à chaque SYSTEM_IO et
SYSTEM_INT1, gardé par la copie précédente $10FDBA-$10FDBD ; le minuteur de trame descend de $3B à
$00, puis l'appel suivant écrit $FF, recharge $3B et ajoute la seconde (nous la comptions une trame
trop tôt) ; seul le code 3 remet PLAY TIME à zéro. Les mots $10FDB6-$10FDBD sont remis à zéro avant
chaque remise ; nous ne le faisions jamais, et après une fin de partie la démo gardait PLAYER_MOD à 3.
La trame tenue de `_retour_demo_end` laisse passer le vblank du jeu puis appelle SYSTEM_INT1 comme la
référence (LED, impulsion du compteur $D00038, REG_SWPBIOS), et n'écrit plus $10FD80 ← $01. À la
pièce : marque du son, COIN_SOUND, puis l'impulsion. L'affichage LED2 lisait déjà $D00035, comme la
référence. Le relevé DEMO_END est désormais égal sur toutes ses colonnes (aof : 29 955 écritures).

**Les LED et les remises suivent la référence** (2026-10-23, `io.s`, `c0.s`,
`measured/2026-10-23-led-et-remises*.tsv`) : un seul afficheur par appel, LED1 si $10FE8B est pair,
LED2 s'il est impair, la donnée après le crédit puis REG_POUTPUT ← $12, $1B, $00, comme la référence
(2 341 appels sur 2 341, page « Memory mapped registers ») ; FRAME_SKIP ← $01 après un PLAYER_START
accepté ; $10FD80 reçoit la valeur d'entrée de SYSTEM_RETURN puis $80 ou $82, et REG_SOUND ← $03
précède chaque remise de démo ou de titre ; au code 3, la remise vient deux ou trois trames après le
retour, SYSTEM_INT1 servi entre-temps, comme la référence. $D0002C, $D00039 et $10FEE0, sans rôle
documenté, reçoivent les valeurs mesurées à leurs places. L'attente après REG_SOUND n'est gardée que
sur le titre : étendue à la démo, elle repoussait la remise d'une trame et kof94 sortait de la
tolérance.

**Le titre après game over et SELECT suivent la référence** (2026-10-23, `c0.s`, `io.s`,
`measured/2026-10-23-titre-apres-game-over*.tsv`) : au code 3, $10FEC5 ← $00, $10FEBF bascule
autour de la sauvegarde, et avec un crédit le départ forcé est réarmé au titre ($10FDDA ← $303B) —
notre titre d'après game over décompte désormais ; $10FEBF ← $00 avant REG_SWPROM à chaque remise
(18 sur 18 chez la référence). SELECT décompte le départ forcé, écrit $10FEE0 ← 0, $10FD81 ← $04
et appelle DEMO_END, comme la référence. La fin de démo teste le crédit sur le mot $D00034-$D00035.
Aux codes 0 et 2 sur le même slot, la remise vient à R+4, SYSTEM_INT1 servi entre-temps, comme la
référence : la démo du boot part trois trames plus tard, et svc, garou, lbowling se rapprochent de la
colonne snk.

**Le parcours du joueur** (2026-10-23, `bench/parcours.sh`, étage 4 de la non-régression en
complet) : 23 scènes, chaque fonction jugée par son effet à l'écran ou au son mixé (`-wavwrite`)
contre un témoin, région et soft-DIP jugés DANS le jeu ; seuils dans
`measured/2026-10-23-parcours.tsv`. `bench/parcours-mutations.py --eprouver` : 21 mutations sur 21
tuées, dont les deux défauts de #1414. Une fonction livrée sans sa scène n'est pas finie.

**Le mode AES** (2026-10-23, `DECISIONS.md` §11) : la ligne MODE de l'éditeur pose BIOS_MVS_FLAG à
$00, et les jeux construisent leur version console. Mesuré contre le BIOS AES de SNK (`aes -bios
asia`, six jeux) : START sans pièce à la trame de l'appui, jamais de demande 3, la demande 1 de kof98
de même durée, la démo et le menu console égaux au pixel sur la plupart des trames
(`measured/2026-10-23-mode-aes.tsv`). Six scènes au parcours, qui en compte désormais 29, et cinq
mutations, 26 sur 26 tuées (`measured/2026-10-23-parcours-aes.tsv`). Non mesurés : SELECT et
multi-slot en AES (aucune référence), SELECT en partie, la carte mémoire, les autres régions. Le mode
MVS n'est pas identique à l'octet à main sur trois jeux de la matrice, par la seule disposition du
code (`measured/2026-10-23-disposition-mvs.tsv`).

**CRC32 de la cartouche et debug dips** (2026-10-25, réappliqués sur main le 2026-10-27, #1444) :
HARDWARE TESTS gagne CARTRIDGE CRC, juste avant EXIT (CROSSHATCH passe à « haut » trois fois), le
CRC32 de la P-ROM fixe et des banques lues sous REG_CRTFIX, égal au calcul hors de MAME sur 8 jeux
sur 10 (`measured/2026-10-25-crc-cartouche.tsv`). CABINET SETTINGS gagne DEBUG DIPS, un masque posé
à chaque SYSTEM_IO et jamais enregistré, éteint sous CHEATS/DEBUG OFF ; effet vu sur kof94
(`measured/2026-10-25-debug-dips.tsv`). 7 scènes et 12 mutations de plus : 130 scènes, 163
mutations, 147 fonctions au tableau de couverture. Scènes du lot PASS seules sur l'image
`8c8caefa…` ; NR, mutations et catalogue à la passe finale. Écarts : `DECISIONS.md` §20.

**Catalogue des cheats et CHEATS/DEBUG** (2026-10-25, pistes 3 et 6 de `ATTENTES.md` §4) : les
cheats couvrent 35 jeux (40 cheats, dont INFINITE TIME sur 22 jeux et INFINITE LIVES sur 14),
trouvés en boîte noire et relevés un par ligne dans
`measured/2026-10-25-cheats-table.tsv`. CABINET SETTINGS gagne CHEATS/DEBUG : à OFF, le menu en jeu
n'offre plus ni cheat ni MEMORY EDITOR, et aucun cheat ou gel ne reste actif. 3 scènes et 9 mutations
de plus : 109 scènes, 124 mutations sur 124 tuées, 127 fonctions sur 127 couvertes ; 32 cheats sur 32
jugés par le menu (`bench/cheats-catalogue.sh`) ; catalogue inchangé, 161 jeux sur 164. Écarts :
`DECISIONS.md` §16.

**Réglages de la borne** (2026-10-25, piste 4 de `ATTENTES.md` §4) : dans l'écran TEST, CABINET
SETTINGS (« haut » sept fois) ouvre FREE PLAY, NO CONTINUE et DEMO SOUND, enregistrés en backup RAM
sans relance. FREE PLAY fait partir START sans pièce, P2 compris ; NO CONTINUE refuse le continue ;
DEMO SOUND OFF coupe le son des démos seulement. Inertes en mode AES. 8 scènes et 10 mutations de
plus : 106 scènes, 115 mutations sur 115 tuées, 121 fonctions sur 121 couvertes ; catalogue
inchangé, 161 jeux sur 164. Mesures : `measured/2026-10-25-free-play.tsv` ; écarts :
`DECISIONS.md` §15. Le banc donne désormais à chaque run du parcours son propre cfg MAME.

**Gestionnaire de carte mémoire et SCORE RESET** (2026-10-24, piste 1 de `ATTENTES.md` §4, en
partie) : dans l'écran TEST, MEMORY CARD (« haut » cinq fois) liste les sauvegardes de la carte,
avec le nom du jeu et les blocs libres, efface une sauvegarde ou formate la carte après confirmation,
et dit NO CARD, CARD NOT FORMATTED ou WRITE PROTECTED ; SCORE RESET (« haut » six fois) gèle à OFF la
date que READ_CALENDAR rend aux jeux, et wh2 garde alors ses records après un saut de date
(`measured/2026-10-24-scores-date.tsv`). 12 scènes et 17 mutations de plus : 98 scènes, 105 mutations
sur 105 tuées, 112 fonctions sur 112 couvertes. Écarts : `DECISIONS.md` §14. Les scores ne sont pas
sauvés sur la carte : la backup RAM les garde déjà d'un boot à l'autre, mode AES compris
(`measured/2026-10-24-scores-aes.tsv`), et 65 des 161 jeux ont une zone qui dépasse une carte vide.
Restent la copie entre cartes et le gestionnaire hors de l'écran TEST.

**GAME SETTINGS et MEMORY EDITOR dans le menu en jeu** (2026-10-23, pistes 2 et 3 de `ATTENTES.md`
§4, en partie) : depuis RESUME, « haut » mène à l'éditeur mémoire (GOTO, SET VALUE, quatre gels
listés à l'écran) et « haut, haut » aux soft-DIP du jeu, avec RESET TO DEFAULTS et RESTART GAME.
18 scènes et 25 mutations de plus : 81 scènes, 85 mutations sur 85 tuées, 94 fonctions sur 94
couvertes. Écarts : `DECISIONS.md` §12. Restent la recherche de cheat (place en RAM) et le
visualiseur de VRAM.

**Toutes les fonctions testées** (2026-10-23, demandé par l'utilisateur : « tous les menus / features
doivent être testés ») : 76 fonctions recensées dans `measured/2026-10-23-parcours-couverture.tsv`,
chacune avec sa scène et sa mutation. Le parcours compte 63 scènes, 60 mutations sur 60 tuées. Les
nouvelles scènes couvrent l'éditeur (remise aux défauts, temps MM:SS, nombre de fois), les trois
régions contre le BIOS SNK de la même région, chaque autotest, les pas du jukebox, les crédits
(START P2, P2 qui rejoint, départ forcé, son de la pièce), la carte mémoire (sauvegarde et relecture
par aof, recherche, effacement, nom), SELECT en multi-slot et en AES, la pause en AES, la demande 1
de kof98 et NO SOFT DIP DATA, sur une copie d'aof dont seul le pointeur soft-DIP de l'en-tête est
refusé. Elles ont trouvé un défaut, corrigé : en mode AES, CREDIT_CHECK refusait la demande de P2 et
aof affichait « INSERT COIN » (`DECISIONS.md` §11, point 10 ; `measured/2026-10-23-aes-credit.tsv`).
Restent supposés : la numérotation physique des commutateurs DIP, et les commandes CARD autres que
la sauvegarde, que l'on provoque sans qu'un jeu connu les appelle.

**Le menu en jeu ne touche plus au son ni à la police** (2026-10-23, `menu.s`, signalé par
l'utilisateur en jouant à mslug) : la commande $03 de la reprise rendait le pilote son du jeu muet
(key-on FM 0 sur 218 sur mslug, 0 sur 361 sur aof), et REG_BRDFIX brouillait le HUD pendant la
pause. Plus de poignée de main, de bascule ni de $03 : le texte s'écrit avec la police de la
cartouche, comme UniBIOS (observé en boîte noire) ; FM 212/218 sur mslug, 363/361 sur aof. Limite :
kof2003, sans police dans sa S ROM, déduit. Relevés : `measured/2026-10-23-menu-en-jeu-son.tsv`,
`-plan-fixe.tsv`, `measured/2026-10-23-unibios-menu-en-jeu.tsv` ; jig `bench/son.lua`. La
non-régression ne juge pas le son : ce défaut ne s'y voyait pas.

**Deux écarts voulus à la référence** (2026-10-23, décision de l'utilisateur) : un seul titre après
game over (`DECISIONS.md` §9) ; SELECT ignoré pendant le DEMO_END d'un SELECT en cours, $10FD81 à
$04 ou $05 (`DECISIONS.md` §10, `measured/2026-10-23-garde-select.tsv`).

**Restent ouverts** :
- DEMO_END après une pièce prise pendant le logo de la référence (b2b) : sans logo chez nous ;
- la salve son et REG_SLOT sur le même slot aux codes 0 et 2 ; SYSTEM_INT1 servi pendant la tenue de
  SELECT ; $10FEE1 avant $10FD80 à l'entrée de SYSTEM_RETURN ; REG_SRAMLOCK après REG_SWPROM ; la
  relecture des manettes sous REG_POUTPUT $12 et $1B ; nam1975, pièce en partie sous INT1 sans
  COIN_SOUND chez la référence (`measured/2026-10-23-led-et-remises.tsv`) ;
- dragonsh, resté sur l'écran de debug du jeu.

**garou ne sort plus de MAME depuis ce lot** (image b0537dd1, deux passages) : il affiche le jeu,
mais à la trame 3500 il n'est pas en partie (10 crédits contre 9 sous la référence, en combat). La
cause du segfault d'avant n'est pas isolée — seule piste : REG_SLOT désormais écrit au boot ; son
départ en partie est à diagnostiquer (`measured/2026-10-22-matrice-multi-slot-lot1.tsv`).

**Les départs refusés sont corrigés** (2026-10-22, `io.s`, `c0.s`) : le catalogue rejoué la nuit du
21 montrait des jeux comptés « joue » qui ne démarrent pas de partie, et aodk qui plante. Cinq causes,
chacune prouvée en forçant la valeur de la référence (`measured/2026-10-22-departs-refuses.tsv`) :
la demande de P2 comparée au crédit commun ($D00034) ; pas de remise sur une pièce au titre ; le
minuteur de départ forcé mis à zéro au départ accepté ; REG_LSPCMODE et IRQACK posés avant chaque
remise ; D0-D7 posés comme la référence à l'entrée en $000122 (D6 = 0 débloque garou). **Le corpus
passe à 22/22** : garou entre en partie. Hors corpus, aodk, shocktr2, sbp, trally, cyberlip et
ncommand partent (`2026-10-22-matrice-departs-jeux.tsv`). Restent incertains : alpham2 (10 crédits
contre 9, minuteur de répétition des manettes à mesurer) ; dragonsh n'est pas une cause BIOS (son
outil de debug, déclenché par le timing du plan d'entrées). **Leçon** : « joue » et les vifs ne
disent pas qu'une partie démarre ; regarder les captures.

**Le départ de P2 suit la référence** (2026-10-22, `io.s`) : mesuré sur cyberlip, kof94 et aof, le
crédit est commun ($D00034, que la pièce 2 crédite aussi) ; à chaque START, BIOS_START_FLAG reçoit
d'abord les joueurs pressés puis la décision ; au titre, P2 demande deux crédits et les deux joueurs
partent ensemble ; en partie, P2 rejoint avec un crédit. Notre image différait sur les 18 cas × jeux
mesurés, elle est égale à la référence sur les 18 (`measured/2026-10-22-depart-p2.tsv`). SUPPOSÉ : le
mode 0 suit le titre ; START P1 et P2 au même front.

# Couche 3 — le BIOS alternatif

**Aucun oracle.** Ces fonctions n'existent dans aucun BIOS SNK, donc aucune trace ne les juge.
Chaque entrée reste sans `Accepté si` tant que son critère n'est pas écrit : acceptation visuelle
consignée par une capture, ou test à écrire.

**La police est relevée** (2026-10-20) : celle du SFIX de la carte mère, 8×16 en deux tuiles
(`$100` + ASCII en haut, `$200` + ASCII en bas) et 8×8 (`$000` + ASCII), palette 0
(`measured/2026-10-20-sfix-glyphes.tsv`, choix dans `DECISIONS.md` §5).

**L'écran de boot est écrit** (2026-10-20, `src/c0/ecran.s`) : titre décodé, lignes d'état,
pause avec rappel, fondu, 180 trames, sautable. Accepté sur captures image par image sous MAME
(mslug, trames 1-200) et corpus 21/22 (`measured/2026-10-20-matrice-ecran-boot.tsv`). Les captures ne sont
pas versionnées : elles montrent les glyphes dessinés du SFIX, octets d'une ROM
SNK. Le saut est mesuré (START du banc à la trame 100, écran noir à la 103). Reste à juger : l'écran
sur une vraie carte.

**L'éditeur de soft-DIP est écrit** (2026-10-20, `src/c0/dip.s`) : bouton TEST tenu au boot, les
réglages du jeu avec leurs intitulés de cartouche, enregistrés dans le bloc de sauvegarde du jeu
et dans BIOS_GAME_DIP. Accepté au jig `bench/editeur.lua` sous MAME (kof98 et aof : la valeur
choisie arrive aux deux endroits, le jeu démarre, la valeur est relue au boot suivant) et corpus
21/22 (`measured/2026-10-20-editeur-soft-dip.tsv`, `2026-10-20-matrice-editeur-soft-dip.tsv`).
Restent à éprouver : un réglage de temps sur une vraie cartouche, le son après l'éditeur à
l'oreille, une vraie carte.

**La région à chaud est écrite** (2026-10-20, `src/c0/reglages.s`, une ligne REGION dans `dip.s`) :
JAPAN, USA ou EUROPE choisie à l'écran TEST, gardée en backup RAM ($D00210-$D0021F, signée), la
machine relancée par le watchdog. Le bloc garde de la place pour d'autres réglages du BIOS. Jugé
par région contre le BIOS SNK de la même région : 21/22 dans les trois, garou seul
(`measured/2026-10-20-matrice-par-region.tsv`, `2026-10-20-region-a-chaud.tsv`). Restent : les
intitulés soft-DIP japonais (kana du SFIX non relevés), la relance sur une vraie carte. Changer
de région réinscrit le jeu : ses soft-DIP reviennent aux défauts de la nouvelle région.

**L'écran de plantage est écrit** (2026-10-21, `src/c0/plantage.s`) : les créneaux $C00408-$C00432
de la zone d'entrée, où mènent les vecteurs d'exception des cartouches, et les vecteurs 2-31 du
BIOS mènent à un écran qui nomme l'exception et montre PC, SR, l'adresse d'accès, les registres
et le NGH ; START relance par le watchdog. Accepté au jig `bench/plantage.lua` (erreur d'adresse
et instruction illégale provoquées sur aof et mslug, valeurs affichées égales au cadre empilé) et
corpus 21/22 (`measured/2026-10-21-ecran-plantage.tsv`, `2026-10-21-vecteurs-cartouches.tsv`).
Restent non provoquées : erreur de bus, trace, interruptions parasites.

**Les autotests sont écrits** (2026-10-21, `src/c0/tests.s`, ligne HARDWARE TESTS de l'écran TEST) :
RAM de travail, RAM de palettes (deux banques), VRAM (sauf $8600-$86FF, réécrite par le LSPC),
backup RAM non destructive, test des entrées, barres de couleur et quadrillage. Chaque test de
mémoire sait échouer : un défaut injecté par lua le fait passer au rouge à la bonne adresse, une
ligne d'adresse court-circuitée comprise ; la backup RAM ressort identique à l'octet
(`measured/2026-10-21-autotests.tsv`). Corpus 21/22. Restent : la neige et les temps d'accès sur
une vraie carte, le son (programme Z80 à écrire).

**La place est ouverte** (2026-10-21, `build/bios.ld`) : une zone de code `.haut` suit la table
d'aléa, de $C04300 à la fin de la ROM. La couche 3 (`ecran.s`, `dip.s`, `reglages.s`, `tests.s`,
`plantage.s`) y est rangée par `.section .haut, "ax"` ; les couches 0 à 2 restent en bas. Libre :
~9,0 Kio en bas, ~100 Kio en haut (image `9dccf8cb…`). Un fichier de la couche 3 se range en haut ; un branchement
entre les deux zones passe par `jsr`/`jmp` absolu.

**Le menu en jeu est écrit** (2026-10-21, `src/c0/menu.s`, crochet dans SYSTEM_IO) : TEST tenu
pendant la partie met le jeu en pause sous un cadre RESUME / RESTART GAME ; RESUME rend le plan
fixe, les palettes, REG_VRAMMOD et l'adresse VRAM du jeu à l'octet (aof, mslug, kof98), la RAM
hors de $10F4C0-$10FB07 (`menu.s`, `cheats.s`). Contreparties d'alors, retirées le 2026-10-23
(plus bas) : le pilote son relancé, le plan fixe hors cadre lu dans le SFIX. Relevés :
`measured/2026-10-21-menu-en-jeu.tsv` et ses trois mesures. Les cheats s'y ajouteront. À
reprendre : la zone de `plantage.s` ($10F400-$10F45B) est écrite par nam1975.

**Les cheats sont écrits** (2026-10-21, `src/c0/cheats.s`, lignes ON/OFF dans le menu en jeu) :
une table par jeu (NGH + empreinte de l'en-tête 68k), un moteur qui écrit les valeurs des cheats
actifs à chaque SYSTEM_IO. **Sept cheats sur trois jeux, tous trouvés par mesure ici** (recherche
en RAM sous MAME, puis preuve causale en forçant la cellule), aucune base tierce : mslug (vies,
bombes, temps), aof (temps, vie P1), kof94 (temps, vie P1). Relevés :
`measured/2026-10-21-cheats-recherche.tsv` (comment chacun a été trouvé), `2026-10-21-cheats-par-le-menu.tsv`,
`2026-10-21-cheats-apres-revue.tsv`, `2026-10-21-cases-curieuses.tsv`. Les états ne survivent pas à une relance (choix prudent ; le
bloc de réglages a la place s'il faut les garder). Étendre la table = refaire la recherche, jeu
par jeu (`DECISIONS.md` §0).

**Défaut trouvé en route, corrigé le même jour** : le bloc soft-DIP de mslug est à $2783D0, dans
la zone banquée de la P-ROM, et `c0.s` refusait tout pointeur au-delà de $0FFFE0 ; la partie
partait à 0 vie, ce que la matrice ne voyait pas. Un bloc est désormais accepté dans
$000000-$0FFFFF ou $200000-$2FFFFF, lu avec la banque en place (celle du reset). BIOS_GAME_DIP
égal à la référence sur 22 jeux sur 22 (`measured/2026-10-21-soft-dip-zone-banquee.tsv`).
**Leçon** : « joue » à la matrice ne dit rien des réglages que le jeu a reçus ; la table de
GAME_DIP contre la référence est un juge à garder.

Le contenu — tout à écrire, §1 ne reprenant rien, la table du §0 ne bornant que le périmètre :
police, écran de boot, éditeur de soft-DIP, région à chaud et sa persistance, gestionnaire de plantage, autotests,
menu en jeu, cheats (faits pour trois jeux), jukebox (fait).

Deux bornes déjà connues, à ne pas redécouvrir :

- **les cheats** : le moteur tient en quelques centaines d'octets, c'est la table par jeu qui est
  sans fin. La cible s'énonce « N jeux », jamais « les cheats » (§0) ;
- **le jukebox** : hors jeu seulement. Le BIOS ne commande le son que lorsque sa propre ROM Z80
  tourne (§0).
- **le jukebox et la police** : REG_BRDFIX et REG_CRTFIX basculent ENSEMBLE la S ROM et la M1 du
  Z80. Notre police (le SFIX) et le pilote son de la cartouche s'excluent donc ; le menu en jeu
  écrit depuis le 2026-10-23 avec la police de la cartouche, plus bas. Mesuré le
  2026-10-21 (`measured/2026-10-21-police-cartouche.tsv`) : la S ROM de 21 jeux sur 22 range
  chiffres, majuscules et « : - / . » lisibles aux numéros de tuile du SFIX, en 8×8 (20 identiques
  au pixel) comme en 8×16 (11 identiques, 10 en police fine lisible) ; kof2003 seul n'a rien à
  ces places. Un jukebox peut donc écrire son texte avec la police de la cartouche.
- **le jukebox est écrit** (2026-10-21, `src/c0/jukebox.s`, ligne JUKEBOX de l'écran TEST) : le
  pilote son de la cartouche relancé, le texte en police de la cartouche, un code de $00 à $FF
  envoyé par A ($01-$03 sautés), B relance le pilote pour couper. Mesuré (`measured/2026-10-21-jukebox.tsv`) :
  aof, kof98, kof2003 n'émettent qu'après $07, que mslug éteint — d'où l'aide « PLAY 07 FIRST IF
  SILENT » plutôt qu'un $07 automatique. Le retour au jeu ne change rien à son son. Reste : une
  liste des codes utiles par jeu, qui se mesurerait comme les cheats ; l'écoute.

# Ce que ce découpage ne couvre pas

- **Le mandat des agents qui écrivent** (§1). Ce fichier dit quoi écrire et comment le juger, pas
  comment constituer une équipe qui n'a lu aucune source amont. La couche 0 est le premier test de
  ce mandat autant que de l'oracle.
- **Le save state sur cartouche NeoSD** : souhait, pas engagement, et son verrou — existe-t-il une
  voie d'écriture vers une cartouche flash ? — n'est pas levé.
- **Les anomalies ouvertes** : les segfauts de MAME sur `garou` et `svc`, les six écrans noirs de
  nullbios, et le prérequis manquant du README de `neogeo-bios` (`libc6-dev-m68k-cross`), qui est
  la première contribution amont identifiée (§4). Aucune n'est sur le chemin de ces tâches.
