# Historique des matrices

Une ligne par matrice jouée sur notre BIOS, **essais rejetés compris** : c'est souvent là que se
lit le chemin réel. Chaque ligne renvoie à son relevé quand il existe. Un essai dont les lignes
ne sont pas versionnées le dit, et cite le rapport d'où vient son chiffre.

Règle de comptage : un jeu compte s'il **« joue », que son `vifs_max` n'est pas nul et que son
`controle` est `ok`**. Un écran noir qui change encore n'est pas un jeu qui tourne (piège 5
de `docs/BENCH.md`). La clause du contrôle n'est écrite que depuis le 2026-10-22 (en-tête de
`2026-10-22-matrice-catalogue.tsv`) : 117, 155 et 157 sont comptés sans elle ; les en-têtes du
2026-10-16 et du 2026-10-19 en retirent irrmaze (substitution absente) : 116, 154, 156. Pas recompté.

À compléter à chaque matrice, livrée ou rejetée.

## Le point de départ : les BIOS existants

Campagne du 2026-10-10 (PR #1314), corpus de 17 jeux, critère automatique d'alors.
Relevé `2026-10-10-matrice-6bios.tsv`, lecture dans `docs/COMPATIBILITE.md`.

| BIOS | Sur 17 |
|---|---|
| SNK (témoin) | 17 |
| UniBIOS 4.0 (témoin) | 17 |
| NeoPen 0.1, binaire de 2015 | 17 |
| neogeo-bios | 15 |
| NeoPen recompilé | 14 |
| nullbios 0.5 | 9 |

## Notre BIOS, livré

| Date | PR | Corpus | Nombre | Ce qui bouge | Relevé |
|---|---|---|---|---|---|
| 2026-10-15 | #1355 | 17 | **6** | premier nombre de la couche 1 ; sept jeux figent dès la trame 100 | `2026-10-15-matrice-couche1.tsv` |
| 2026-10-15 | #1357 | 17 | **11** | SYSTEM_INT1 sort par `rte` : joyjoy, mslug, ridhero, samsho2, ssideki4 | `2026-10-15-matrice-couche1-rte.tsv` |
| 2026-10-15 | #1358 | 17 | **13** | handshake son et REG_CRTFIX : wjammers, trally | `2026-10-15-matrice-couche1-son.tsv` |
| 2026-10-15 | #1362 | 164 | **117** | catalogue complet, image de #1358 (SNK 162, UniBIOS 162, nullbios 93) | `2026-10-15-matrice-catalogue.tsv` |
| 2026-10-16 | #1364 | 20 | **14** (13/17) | pièces, START, déduction : magdrop2 ; le corpus passe à 20 | `2026-10-16-matrice-start-credit.tsv` |
| 2026-10-16 | #1365 | 20 | **15** (13/17) | code pays Europe : flipshot | `2026-10-16-matrice-code-pays.tsv` |
| 2026-10-16 | #1366 | 20 | **15** (13/17) | FRAME_SKIP : neomrdo sort du noir, reste figé | `2026-10-16-matrice-frame-skip.tsv` |
| 2026-10-16 | #1367 | 20 | **16** (13/17) | FIX_CLEAR, LSP_1st : neomrdo ; la famille des poses est close | `2026-10-16-matrice-fix-clear.tsv` |
| 2026-10-16 | #1368 | 20 | **16** (13/17) | formatage backup : aucun gain, kof98 change de cause | `2026-10-16-matrice-format-backup.tsv` |
| 2026-10-16 | #1369 | 20 | **17** (14/17) | table d'aléa : svc | `2026-10-16-matrice-table-alea.tsv` |
| 2026-10-16 | #1370 | 20 | **19** (16/17) | demande 0 au premier boot : kof98, mslug3 | `2026-10-16-matrice-demande-0.tsv` |
| 2026-10-16 | #1371 | 19 | **19** | soft-DIP de la cartouche, garou exclu (MAME y plante) : aucun gain attendu | `2026-10-16-matrice-soft-dip.tsv` |
| 2026-10-16 | — | 164 | **155** | catalogue complet, image de #1371 (SNK 162, UniBIOS 162, nullbios 88) : 39 gagnés, vliner perdu (il fige aussi sous SNK) | `2026-10-16-matrice-catalogue.tsv` |
| 2026-10-17 | #1374 | 22 | **20** | départ forcé (« game start compulsion ») : minasan ; le corpus passe à 22 avec b2b et minasan | `2026-10-17-matrice-depart-force.tsv` |
| 2026-10-17 | #1375 | 22 | **21** | MESS_OUT et la remise calée sur le vblank : b2b ; reste garou | `2026-10-17-matrice-mess-out.tsv` |
| 2026-10-19 | — | 164 | **157** | catalogue complet, image de #1375 (SNK 162, UniBIOS 162, nullbios 88) : b2b et minasan gagnés, aucun perdu ; irrmaze compté sans substitution, 156 sans lui | `2026-10-19-matrice-catalogue.tsv` |
| 2026-10-19 | #1377 | 22 | **21** | CARD sans carte : aucun gain attendu, fidélité au service (8 appels égaux à la référence) | `2026-10-19-matrice-card.tsv` |
| 2026-10-19 | #1378 | 22 | **21** | READ_CALENDAR : aucun gain attendu, mêmes accès à l'horloge et mêmes écritures que la référence | `2026-10-19-matrice-read-calendar.tsv` |
| 2026-10-19 | #1379 | 22 | **21** | CARD avec carte et CARD_ERROR : aucun gain attendu (la matrice n'insère pas de carte) ; 13 appels provoqués égaux à la référence | `2026-10-19-matrice-card-avec-carte.tsv` |
| 2026-10-20 | — | 22 | **21** | écran de boot (≈ 180 trames de plus au démarrage) : aucun gain attendu, aucune régression | `2026-10-20-matrice-ecran-boot.tsv` |
| 2026-10-20 | — | 22 | **21** | éditeur de soft-DIP (TEST tenu au boot ; le banc ne le presse pas) : aucun gain attendu, colonne sprixe identique ligne à ligne | `2026-10-20-matrice-editeur-soft-dip.tsv` |
| 2026-10-20 | — | 22 | **21** | région à chaud : Europe identique ligne à ligne ; Japon et USA 21/22 aussi, chacun contre le BIOS SNK de sa région (22/22) | `2026-10-20-matrice-par-region.tsv` |
| 2026-10-21 | — | 22 | **21** | écran de plantage : aucun jeu du corpus ne l'atteint ; garou sort de MAME pendant notre écran de boot, sans exception 68000 | `2026-10-21-matrice-ecran-plantage.tsv` |
| 2026-10-21 | — | 22 | **21** | autotests (ouverts par TEST, le banc ne le presse pas) : colonne sprixe identique | `2026-10-21-matrice-autotests.tsv` |
| 2026-10-21 | — | 22 | **21** | couche 3 déplacée au-dessus de la table d'aléa ($C04300) : colonnes identiques | `2026-10-21-matrice-zone-haute.tsv` |
| 2026-10-21 | — | 22 | **21** | menu en jeu (crochet dans SYSTEM_IO) : verdicts identiques ; vifs de neomrdo et svc bougent (cycles) ; flipshot réparé en route (`io.s`) | `2026-10-21-matrice-menu-en-jeu.tsv` |
| 2026-10-21 | — | 22 | **21** | cheats (moteur dans SYSTEM_IO, inactif sans choix) : verdicts identiques | `2026-10-21-matrice-cheats.tsv` |
| 2026-10-21 | — | 22 | **21** | soft-DIP en zone banquée : mslug reçoit enfin ses réglages (3 vies) ; verdicts identiques — la matrice ne voyait pas le défaut | `2026-10-21-matrice-soft-dip-zone-banquee.tsv` |
| 2026-10-21 | — | 22 | **21** | jukebox (écran TEST, le banc ne l'ouvre pas) : verdicts identiques | `2026-10-21-matrice-jukebox.tsv` |
| 2026-10-22 | catalogue | 164 | **158** | catalogue complet sur main 433d86e9 (toute la couche 3) : 156 → 158 en excluant les contrôles non ok (161 à la règle écrite) ; aodk perdu (erreur d'adresse, en diagnostic) ; plusieurs jeux comptés « joue » ne démarrent pas de partie (captures) | `2026-10-22-matrice-catalogue.tsv` |
| 2026-10-22 | — | 22 | **21** | multi-slot lot 1 (détection, table par slot) : 21 inchangés ; garou ne plante plus (vifs 70804) mais ne démarre pas de partie, non compté | `2026-10-22-matrice-multi-slot-lot1.tsv` |
| 2026-10-22 | — | 22 | **21** | durcissement matériel : verdicts égaux, boot de 2 trames plus long | `2026-10-22-matrice-durcissement.tsv` |
| 2026-10-22 | — | 22 | **22** | départs refusés (cinq causes prouvées) : garou entre en partie ; trally part enfin (vifs 44526 → 71490) ; hors corpus, aodk, shocktr2, sbp jouent, cyberlip et ncommand partent | `2026-10-22-matrice-departs.tsv` |
| 2026-10-22 | catalogue | 164 | **161** | catalogue complet sur main 64b9d7e3 (#1406, image 738d507f…), sans nullbios : 158 → 161, aodk, garou et shocktr2 gagnés, aucun perdu ; irrmaze seul contrôle non ok ; dragonsh compté par la règle mais resté sur l'écran de debug du jeu ; garou et alpham2 affichent un crédit de plus que sous SNK | `2026-10-22-matrice-catalogue-soir.tsv` |
| 2026-10-22 | — | 22 | **22** | la pièce qui fait le crédit passe par DEMO_END, PLAY TIME au boot : verdicts égaux ; svc −2,7 % de vifs (la pièce en démo rend le titre une trame plus tard, comme la référence), d'où la nouvelle référence du harnais | `2026-10-22-piece-demo-end-matrice.tsv` |
| 2026-10-22 | — | 22 | **22** | répétition du joystick, $10FD81 au START, ordre de CREDIT_CHECK : verdicts égaux ; svc +2,6 % de vifs, plus près de la colonne snk (écart moyen 2 571 → 344), d'où la nouvelle référence du harnais | `2026-10-22-repetition-et-start-matrice.tsv` |
| 2026-10-23 | — | 22 | **22** | FRAME_SKIP sous INT1, la pièce sous INT1, le code 2 avec un crédit : verdicts égaux, sous la tolérance ; svc −1 % (plus loin de la colonne snk, mais un INT1 allongé de 4 `nop` sans rien changer d'autre le déplace déjà : sa partie suit le nombre de cycles d'INT1) ; référence du harnais inchangée | `2026-10-22-frame-skip-et-mode0-matrice.tsv` |
| 2026-10-23 | — | 22 | **22** | comptabilité (PLAY TIME, $10FDB6-$10FDBD, trame tenue de DEMO_END) : verdicts égaux, trois vifs déplacés sous la tolérance (svc et neomrdo plus près de la colonne snk, garou un peu plus loin) ; référence du harnais inchangée | `2026-10-23-comptabilite-matrice.tsv` |
| 2026-10-23 | — | 22 | **22** | LED, REG_POUTPUT, $10FD80 et REG_SOUND aux remises, trames tenues du code 3 : verdicts égaux, svc −1,96 % et neomrdo sous la tolérance (plus loin de la colonne snk) ; un premier essai sortait kof94 à −2,22 % (l'attente après REG_SOUND étendue à la démo), écarté ; référence du harnais inchangée | `2026-10-23-led-et-remises-matrice.tsv` |
| 2026-10-23 | — | 22 | **22** | titre après game over, SELECT par DEMO_END, trames tenues des codes 0 et 2 : verdicts égaux ; svc, garou, lbowling et neomrdo bougent sous la tolérance, tous plus près de la colonne snk (la démo du boot part trois trames plus tard) ; référence du harnais inchangée | `2026-10-23-titre-apres-game-over-matrice.tsv` |
| 2026-10-23 | catalogue | 164 | **161** | catalogue complet sur main 9789d1f4 (#1413, image ea0de49e…) puis d95122a2 (#1414, image 528b7e9c…, celle remise pour l'essai sur carte), sans nullbios : verdicts de la colonne sprixe identiques entre les deux images, aucun jeu gagné ni perdu ; SNK 162, UniBIOS 162 ; non comptés : irrmaze (contrôle), mvstemp et vliner (figés) | `2026-10-23-matrice-catalogue.tsv` |
| 2026-10-23 | catalogue | 164 | **161** | catalogue complet sur main 14b54bb1 (#1417, le mode AES, image bc6560f5…, celle remise pour l'essai sur carte), mode MVS, sans nullbios : aucun jeu gagné ni perdu ; kof97 pose 100 trames, trois vifs bougent sous la règle ; SNK 162, UniBIOS 162 ; mêmes non comptés | `2026-10-23-matrice-catalogue-aes.tsv` |
| 2026-10-23 | catalogue | 164 | **161** | catalogue complet sur main 516016ce (#1419, CREDIT_CHECK en AES, image 6fc2d51b…, celle remise pour l'essai sur carte), mode MVS, sans nullbios : aucun jeu gagné ni perdu, verdicts égaux ; six vifs bougent de moins de 0,4 % ; SNK 162, UniBIOS 162 | `2026-10-23-matrice-catalogue-credit-aes.tsv` |
| 2026-10-24 | catalogue | 164 | **161** | catalogue complet sur l'image 70f73d53… (#1425, celle de main a8b3ffb8, remise pour l'essai sur carte, image n°9), sans nullbios : aucun jeu perdu ; ng_mv1f mesuré en plus, hors des 164 (joue) ; SNK 162, UniBIOS 162 ; non comptés : irrmaze (contrôle), mvstemp et vliner (figés) | `2026-10-24-matrice-catalogue.tsv` |
| 2026-10-25 | catalogue | 164 | **161** | catalogue complet sur l'image c4cba5b2… (#1427, celle de main 13a837d1, remise pour l'essai sur carte, image n°10), colonne sprixe seule, sans nullbios : aucun jeu perdu contre `2026-10-24-matrice-catalogue.tsv` ; ng_mv1f hors des moitiés ; non comptés : irrmaze (contrôle), mvstemp et vliner (figés). Sorties non versionnées | — |
| 2026-10-25 | catalogue | 164 | **161** | catalogue complet sur l'image cdaca6b7… (#1429, celle de main a3159605, remise pour l'essai sur carte, image n°11), colonne sprixe seule, sans nullbios : aucun jeu perdu contre `2026-10-24-matrice-catalogue.tsv` ; ng_mv1f hors des moitiés ; non comptés : irrmaze (contrôle), mvstemp et vliner (figés). Sorties non versionnées | — |
| 2026-10-25 | catalogue | 164 | **161** | catalogue complet sur l'image e5b4ea94… (#1432, celle de main 4d26ffdc, remise pour l'essai sur carte, image n°12), sans nullbios : verdicts égaux jeu par jeu à `2026-10-24-matrice-catalogue.tsv` ; ng_mv1f hors des moitiés ; non comptés : irrmaze (contrôle), mvstemp et vliner (figés). Sorties non versionnées | — |
| 2026-10-25 | catalogue | 164 | **161** | catalogue complet sur l'image 981cd2af… (#1439, celle de main e7179b01, remise pour l'essai sur carte, image n°13), sans nullbios : verdicts égaux jeu par jeu à `2026-10-24-matrice-catalogue.tsv` ; ng_mv1f hors des moitiés ; non comptés : irrmaze (contrôle), mvstemp et vliner (figés). Sorties non versionnées | — |
| 2026-10-25 | catalogue | 164 | **161** | catalogue complet sur l'image 8f03e1de… (#1442, celle de main f8cb3e3f, remise pour l'essai sur carte, image n°14), sans nullbios : verdicts égaux jeu par jeu à `2026-10-24-matrice-catalogue.tsv` ; ng_mv1f hors des moitiés ; non comptés : irrmaze (contrôle), mvstemp et vliner (figés). Sorties non versionnées | — |

## Essais rejetés, le 2026-10-16

Le diagnostic de kof98, garou et mslug3 a coûté neuf images d'essai avant la cause. Toutes
partent de l'image de #1368, et aucune n'a été livrée telle quelle.

| Essai | Ce qu'il change | Résultat | Source |
|---|---|---|---|
| jetable-sr | SR `$2000` écrit à la remise | kof98 ne reboote plus mais fige | relevé `2026-10-16-kof98-diagnostic-remise.tsv` |
| jetable-tblseule | table d'aléa seule, sur 1 jeu | kof98 sort du tirage, puis reboote | idem |
| jetable-tbl | table + SR `$2000` à la remise | **18/20** : kof98, garou, mslug3, svc jouent ; flipshot et kof94 cassent | idem, lignes versionnées |
| jetable4 | table + attente IRQ ouvertes avant la remise | 9/10 jeux sensibles : neomrdo fige | idem, lignes versionnées |
| vI (agent) | table + attente + garde de pièce | 7/10 : kof98, garou, mslug3 rouges | rapport de l'agent, non versionné |
| vE' (agent) | vI + remise IRQ ouvertes | 8/10 : kof94 et flipshot rouges | idem |
| vE'' (agent) | vI + remise ouverte calée sur le vblank | 8/10 : les mêmes | idem |
| vK (agent) | vI + `$80 \| mode` à la remise | 7/10 : comme vI | idem |
| table seule | la table d'aléa, rien d'autre, sur 6 jeux | 4/6, exactement le gain de vI : l'attente et la garde de pièce sont retirées | rapport de session, non versionné |

Trois hypothèses ont été réfutées par test causal, sans matrice : poser les soft-DIP, poser la
zone backup par jeu, changer le mode de la remise. La cause était ailleurs : la demande 0 n'est
appelée qu'au premier boot d'un jeu (#1370).

## Essais rejetés, le 2026-10-17

| Essai | Ce qu'il change | Résultat | Source |
|---|---|---|---|
| jetable-vbl | toute remise attend la ligne `$1F0` puis acquitte les IRQ | 19/22, les mêmes que #1371 : b2b ne fait plus d'erreur d'adresse mais reste noir (MESS_OUT manquait ; livrée avec lui) | `2026-10-17-matrice-remise-vblank.tsv` |
