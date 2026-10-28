| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| L'ÉDITEUR DE SOFT-DIP — ouvert au boot quand le bouton TEST de la carte est tenu.
|
| Appelé par `jsr` depuis `c0.s`, sur les deux chemins de la table des emplacements
| (`_slot_inscrit` après `_dip_copier`, `_slot_present` après la relecture du bloc), avant
| REG_SRAMLOCK : la backup RAM est encore déverrouillée. Entrée : %a1 pointe JUSTE APRÈS
| le bloc de sauvegarde du jeu ($D00220 + 16 × index + 16), où les deux chemins le
| laissent ; BIOS_GAME_DIP ($10FD84-$10FD93) et ce bloc y sont égaux. %a3 : l'index de
| l'entrée du jeu dans la table des emplacements, sur les deux chemins ; %d6, 1 si ce boot
| vient de l'inscrire, 0 sinon. Sortie :
| tous les registres rendus intacts — sauf si la région a changé, où l'on ne revient pas
| (voir LA SORTIE). Bouton non tenu : un `btst` et un `rts`, rien d'autre.
|
| AUCUN ORACLE : le menu de réglage du BIOS de référence n'est pas lu. Les remises sont
| « Couche 3 → l'éditeur de soft-DIP, le 2026-10-20 » et « Couche 3 → la région à chaud
| et la sauvegarde des réglages du BIOS, le 2026-10-20 » (`docs/RELECTURE-CONTRATS.md`).
|
| LA LIGNE REGION, en tête, toujours là : JAPAN, USA, EUROPE (0, 1, 2, « BIOS RAM
| locations »), partant de BIOS_COUNTRY_CODE. Elle n'est pas un réglage de la cartouche :
| la remise aux défauts ne la touche pas, et les intitulés soft-DIP affichés restent ceux
| de la région en cours. Changée, elle s'enregistre au START (`reglages.s`) et la machine
| repart.
| LA LIGNE MODE, après les réglages de la cartouche et avant HARDWARE TESTS : MVS, AES (décision
| D7), partant de BIOS_MVS_FLAG ($10FD82). Comme REGION, elle n'est pas un réglage de la
| cartouche ; changée, elle s'enregistre au START (`reglages.s`) et la machine repart. Mais
| l'entrée d'un jeu connu n'est pas libérée : le mode ne change pas le bloc soft-DIP lu, et
| une demande 0 effacerait les scores que la décision D5 garde. Celle d'un jeu que ce boot
| vient d'inscrire (%d6 = 1, `c0.s`) l'est : sa demande 0 n'a pas encore eu lieu, et le boot
| suivant restaurerait un bloc jamais sauvé (mesuré sous MAME le 2026-10-23, aof, NVRAM
| neuve : sans cela, la démo suit la relance sans demande 0). PAS SOUS REGION : les chemins de touches
| des relevés (ROUND TIME à « bas », LANGUAGE à « bas, bas ») restent ceux d'avant ; depuis la
| première ligne, « haut » quatre fois y mène, quel que soit le jeu. DECISIONS §11.
| « mesuré » : un relevé nommé ; « lu dans » : une page du NeoGeo Development Wiki ;
| « SUPPOSÉ » : ni l'un ni l'autre.
|
| LE BOUTON TEST. Lu dans « Memory mapped registers » : REG_SYSTYPE ($300081), bit 7
| « Test button », sans niveau actif. Mesuré sous MAME le 2026-10-20 (kof98, -bios euro,
| notre image, champ `:TEST` « Service Mode ») : $80 relâché, $00 tenu — actif à l'état bas.
| SANS BOUTON TEST, depuis le 2026-10-25 (une MVS consolisée n'en a pas), deux autres entrées,
| lues au même instant, juste après l'écran de boot :
|   - le commutateur 1 de la carte, « Setting Mode » (REG_DIPSW $300001 bit 0, actif bas :
|     « Memory mapped registers » ; masque $01, SW:1, dans la source de MAME) à ON. MESURÉ
|     (`measured/2026-10-25-dip-free-play.tsv`, section 4) : le BIOS SNK et UniBIOS 4.0 ouvrent
|     alors leur menu de test à chaque mise sous tension, ne le lisent pas à chaud (basculé en
|     démo, rien), et EXIT y affiche « DIP-SW 1 OFF !! » tant qu'il reste à ON ; basculé à OFF, la
|     machine repart dans le jeu ; basculé à OFF avant EXIT, la sortie se fait sans message (SNK :
|     la machine repart). ÉCART VOULU : ici START en sort toujours. Commutateur encore à ON, un
|     avertissement (DIP SWITCH 1 IS ON) reste AVERT_TRAMES trames à l'écran, ou jusqu'à ce qu'on le
|     bascule, puis le jeu — on ne retient pas dans un menu qui n'a pas accès à la carte (`.Lavertir`).
|     Rebasculé à OFF pendant l'écran, pas d'avertissement. Il rouvre l'écran à chaque boot tant
|     qu'il est à ON (un changement de région, qui relance, y ramène donc) ;
|   - START et SELECT de P1 tenus ensemble (REG_STATUS_B bits 0 et 1, actifs bas), le geste du
|     menu en jeu (`menu.s`, LE GESTE) : ils sautent l'écran de boot, et tenus jusqu'ici, ouvrent
|     l'éditeur. Aucun jeu ne tourne encore : rien d'autre ne les lit. Mesuré sous MAME : au repos,
|     $380000 vaut $FF sur aof, ng_mv1, ng_mv1f, ng_mv2f, ng_mv4f et la MV-6F — SELECT n'y est pas
|     lu actif. SUPPOSÉ sur le matériel : un SELECT lu actif au repos ferait de START seul tenu au
|     boot l'entrée de l'éditeur, START restant ce qui en sort.
|     REFUSÉ, depuis le 2026-10-27, si A, B, C et D de P1 sont tenus TOUS LES QUATRE
|     (REG_P1CNT $300000 bits 4-7, actifs bas : « Memory mapped registers ») ; un, deux ou trois
|     d'entre eux tenus, il ouvre l'éditeur comme seul. CONSTATÉ sur le matériel par le testeur le
|     2026-10-26 (image n°14, `docs/ESSAI-MATERIEL.md`) : l'adaptateur BlueRetro tient environ une
|     seconde L/R, A, B, C, D, START et SELECT à sa mise en route, et ouvrait l'écran TEST à chaque
|     boot. Les quatre à la fois, c'est sa signature ; « A-D relâchés » refuserait le geste au joueur
|     qui frôle A. SUPPOSÉ : qu'aucune autre manette ne tienne les quatre à la mise sous tension.
|     TEST et le commutateur 1 n'en dépendent pas. DECISIONS §17 pt 5.
|
| LE BLOC SOFT-DIP DE LA CARTOUCHE, lu dans « Software DIPs » : $00-$0F le nom ; $10-$13
| deux temps en mot, minutes puis secondes en BCD, minutes « up to 29 », $FFFF = inutilisé ;
| $14 un compte de 1 à 99, $15 un nombre de fois de 0 (« WITHOUT ») à 100 (« INFINITE »),
| $FF = inutilisé ; $16-$1F dix réglages à choix, défaut dans le quartet haut, nombre de
| choix dans le bas ; à partir de $20, des intitulés de 12 caractères : un par réglage
| spécial, puis pour chaque réglage à choix son intitulé suivi d'un par choix. Mesuré le
| 2026-10-20 sur les intitulés de kof98 et aof (lus par lua dans leur P-ROM, non
| versionnés) : un réglage spécial inutilisé ne prend aucun intitulé (kof98 n'en a aucun et
| ses intitulés commencent au premier réglage à choix ; aof, un compte, commence par le
| sien), et la suite de la table tombe juste sur les deux jeux.
|   SUPPOSÉ : un réglage à choix dont le nombre est 0 ne prend aucun intitulé et ne
|   s'affiche pas (la page ne le dit que pour l'entrée « NEXT PAGE » ; aof met la sienne
|   à 1 choix, affichée telle quelle, sans effet). Les secondes bornées à 59, le temps
|   éditable de 00:00 à 29:59, par pas d'une seconde.
| Le pointeur du bloc suit la région comme dans `c0.s` (`_slot_inscrit`), avec les mêmes
| zones et le même refus (nul, ou bloc qui ne tient pas entier dans $000000-$0FFFFF ou dans
| $200000-$2FFFFF, lue dans la banque en place : voir `c0.s`) : refusé, l'écran ne montre
| que la ligne de remise aux défauts, sans effet, et START enregistre GAME_DIP tel qu'il
| est. Un intitulé qui déborderait de la zone de son bloc s'affiche en blanc. Un caractère
| hors de $20-$7E devient une espace, sauf dans la liste en 8×16 (plus bas).
|
| LES VALEURS REÇUES, rendues valides à l'entrée. Un temps qui n'est pas du BCD dans les
| bornes, un compte ou un choix hors de ses bornes prend le défaut de la cartouche s'il est
| valide, sinon le minimum (00:00, 1, 0, choix 0). SUPPOSÉ : la page laisse ouverte la
| question de la validation des valeurs. Un réglage inutilisé prend la valeur que la cartouche
| déclare, comme à l'inscription (`.Linutilises`) : il n'était pas touché, et le START
| enregistrait les octets d'une entrée jamais initialisée.
|
| LE PLAN FIXE ET LE Z80. À cet appel, le boot a déjà écrit REG_CRTFIX : le plan fixe lit
| la S ROM de la cartouche, sans la police de la carte. Lu dans « Memory mapped
| registers » (cité par `c0.s`) : REG_BRDFIX ($3A000B) et REG_CRTFIX ($3A001B) basculent
| ensemble la S ROM ET la M1 du Z80. Revenir à la police de la carte couperait donc la ROM
| sous le pilote son du jeu. On refait la poignée de main que la page prévoit pour un
| changement de slot (« 68k/Z80 communication ») : $01, le pilote coupe le son, boucle en
| RAM et répond $01 ; REG_BRDFIX ; l'éditeur ; REG_CRTFIX ; $03, le reset du Z80, « under
| 100ms », sans réponse. SUPPOSÉ : attendre 8 trames (≈ 135 ms) après le $03 du boot avant
| d'envoyer $01, pour que le pilote fraîchement réinitialisé l'entende ; l'écho attendu
| 60 trames au plus, puis on bascule quand même, comme `c0.s`. Le $01 de l'écho du boot
| pourrait rester dans le verrou de réponse et passer pour un écho : la page ne dit pas
| comment le vider. Mesuré sur aof (MAME, jig lua local, le 2026-10-20) : sans l'éditeur,
| le verrou vaut $80 à la trame 200, avec lui $01 — l'écho vu est donc le vrai ; après la
| sortie, le Z80 retourne dans la même boucle ($013E-$0146) que sans l'éditeur, et le jeu
| lui envoie la même suite de commandes (3, 19 puis 25 écritures de REG_SOUND relevées de
| 100 en 100 trames), cent trames plus tard : le temps passé dans l'éditeur.
|
| LA COPIE. Sous REG_BRDFIX, la P-ROM de la cartouche ne répond pas sur le matériel (retour du
| 2026-10-24, `docs/ESSAI-MATERIEL.md` ; SLOTCS, `c0.s`) : lus après la bascule, le nom et les
| intitulés étaient le bus flottant — 244 lectures sur aof comme sur mslug sous
| `bench/bus-flottant.lua`, des rangées de « Q » à l'écran. MAME, lui, sert la P-ROM sous les
| deux. Le bloc est donc recopié en RAM avant la bascule, puis l'écran ne lit que la copie :
| le nom, les temps et choix, et les intitulés, jusqu'à la fin de la table ou de la zone du bloc,
| 1 692 octets au plus (138 intitulés ; au-delà, la case reste en blanc, comme un intitulé hors
| de sa zone). Écartés : rester sous REG_CRTFIX, l'écran prendrait la police de la cartouche ;
| basculer autour de chaque lecture, la S ROM changerait sous le plan fixe en pleine image. La
| place : la RAM du menu en jeu et de ses écrans, qu'aucun n'emploie au boot, effacée à la sortie
| (le vidage de `c0.s` l'y avait laissée à zéro). Le test de la RAM de travail (`tests.s`) garde
| $10F000-$10FFFF, donc la copie.
|
| L'AFFICHAGE, comme `ecran.s` (lu dans « Fix layer », « Palettes », « VRAM » ; mesuré
| dans `measured/2026-10-20-sfix-glyphes.tsv`) : plan fixe seul, $7000 + 32 × colonne +
| ligne, lignes 2 à 29 visibles ; police 8×8 = tuile ASCII, 8×16 = $100/$200 + ASCII (et
| $300/$400 + octet, la liste en 8×16) ;
| chaque palette porte sa couleur dans l'entrée 1, du noir dans 2 à 15. Ici REG_VRAMMOD
| vaut 32 : une écriture avance d'une colonne, une ligne de texte s'écrit d'une seule
| adresse. Le trait des glyphes 8×8 à l'index 1 : mesuré sur nos captures de l'éditeur
| (non versionnées).
| Palettes : 1 le texte, 2 la ligne choisie, 3 le titre et le nom, 4 l'aide ; et la palette
| 0, entrées 1-15 noires, comme `ecran.s` et `plantage.s` : FIX_CLEAR met sous elle sa tuile
| $020, pleine de l'index 2 (`measured/2026-10-21-sfix-tuiles-pleines.tsv`). Écrites
| une fois, juste après le passage de la ligne $1F0 ; seules les cases changent ensuite.
|
| LA LISTE EN 8×16, le 2026-10-27 (DECISIONS §19, décision de l'utilisateur). En région JAPAN,
| si les intitulés copiés (de l'octet $20 du bloc à COPIE_FIN) portent au moins un octet hors de
| $20-$7E, toute la liste passe en 8×16 : deux rangées par entrée, une fenêtre de FENETRE = 10
| entrées (rangées 7 à 26) qui suit la ligne choisie, comme GAME SETTINGS. MESURÉ
| (`measured/2026-10-27-intitules-japon.tsv`) : le BIOS SNK japonais écrit chaque octet b d'un
| intitulé ou d'un choix en $300 + b (haut) et $400 + b (bas), palette 0 (section 1) ; sous la
| police de la carte, $300/$400 + b et $100/$200 + b ont le même glyphe pour $20-$5E et $61-$7B,
| pas pour $5F, $60, $7C-$7E (section 2, 90 sur 95) — d'où `.Lecrire16` : $100/$200 + b pour les
| premiers, $300/$400 + b pour tout autre, la règle de SNK. Le nom et le titre ne changent pas ;
| le sous-écran CABINET SETTINGS reste en 8×8. Un bloc tout en ASCII, ou une autre région : la
| liste en 8×8 d'avant, à l'octet près, et l'écriture d'une ligne n'y coûte que deux tests
| (`.Lligne`, `.Lv_fin`). SUPPOSÉ : que la police de la carte ait ces glyphes sur le matériel
| comme sous MAME (le SFIX de MAME, lu à l'écran seulement).
|
| LA LIGNE SCORE RESET, juste avant MEMORY CARD (« haut » six fois) : ON, les jeux lisent la vraie
| date ; OFF, READ_CALENDAR leur rend la date du jour où le réglage est passé à OFF (`cal.s`), et
| les jeux qui remettent leurs records à zéro quand la date change ne le font plus. Comme REGION et
| MODE, ce n'est pas un réglage de la cartouche ; changé, il s'enregistre au START (`reglages.s`,
| avec la date lue à ce moment), sans relance : le jeu ne lit la date qu'en l'appelant.
| LA LIGNE HARDWARE TESTS, avant la remise aux défauts, toujours là : droite, gauche ou A
| ouvrent les autotests (`tests.s`), qui rendent la main sur START ; l'écran est alors
| redessiné, les valeurs en cours d'édition gardées (elles sont dans GAME_DIP, que le test
| de la RAM de travail préserve). LA LIGNE JUKEBOX la suit, de même : `jukebox.s`, qui rend
| le Z80 et le plan fixe dans l'état de cet écran. LA LIGNE MEMORY CARD, de même, ouvre le
| gestionnaire de la carte mémoire (`gestion-carte.s`) ; elle est juste avant MODE, et non
| près des deux autres, pour garder les chemins de touches des relevés (« haut » une fois
| mène à la remise, deux au jukebox, trois aux tests, quatre au mode) : « haut » cinq fois
| y mène, quel que soit le jeu.
| LA LIGNE CABINET SETTINGS, juste avant SCORE RESET (« haut » sept fois, le 2026-10-25) : droite,
| gauche ou A ouvrent un sous-écran de cinq lignes, les réglages de la borne (`reglages.s`) —
| FREE PLAY (OFF, ON), NO CONTINUE (OFF, ON), DEMO SOUND (ON, OFF), et CHEATS/DEBUG (ON, OFF ; à
| OFF, le menu en jeu n'offre plus ni cheats ni MEMORY EDITOR, `menu.s`, et le moteur des cheats
| et des gels n'écrit plus rien, `cheats.s`) ; START y rend la liste, sur la
| même ligne, et c'est le START de la liste qui enregistre, sans relance. Un sous-écran plutôt que
| trois lignes : mesuré le 2026-10-25 sur 159 jeux (bloc européen, les
| réglages utilisés comptés), jusqu'à 12 réglages de cartouche (froman2b, pspikes2, tophuntr,
| turfmast) : 19 lignes aujourd'hui, 22 avec trois lignes de plus, quand la liste en tient 21 ; 20
| avec une. Placée là, elle ne déplace aucun chemin de touches des relevés (« haut » une à six fois,
| « bas » vers les réglages de la cartouche). En mode AES (la ligne MODE à AES), les trois premières
| valeurs disent MVS ONLY et ne changent pas : elles sont inertes en AES (`reglages.s`, `_borne_ram`).
| CHEATS/DEBUG, elle, vaut dans les deux modes : le menu en jeu s'ouvre aussi en AES.
| La cinquième ligne, DEBUG DIPS (le 2026-10-25), ouvre l'écran des debug dips (`debug.s`) ; sa
| valeur est leur masque en hexadécimal, ou OFF, et alors elle ne s'ouvre pas, sous CHEATS/DEBUG
| OFF. Après les quatre autres, elle ne déplace aucun chemin (« bas » trois fois mène toujours à
| CHEATS/DEBUG).
|
| LES COMMANDES, P1 seul, sur front (relâché → appuyé). Lu dans « Memory mapped
| registers » : REG_P1CNT ($300000) bits 0-4 haut, bas, gauche, droite, A ; REG_STATUS_B
| ($380000) bit 0 START P1 ; actifs à l'état bas. Haut/bas : la ligne, en boucle.
| Droite/gauche : la valeur, bornée. A : la valeur suivante, qui repart au minimum après
| le maximum — pour une borne à un seul bouton. Sur la dernière ligne, droite, gauche ou A
| remettent les défauts de la cartouche. START : enregistre et sort.
|
| L'ENREGISTREMENT : les 16 octets de GAME_DIP, au format de `_dip_copier` (temps et
| comptes tels quels, puis un index de choix par octet), recopiés dans le bloc du jeu.
| L'ÉTAT RENDU : plan fixe effacé par FIX_CLEAR (REG_VRAMMOD à 1), palettes 0-4 et le fond
| à zéro, la référence $400000 laissée à $8000, registres intacts. IRQ masquées tout du
| long (SR = $2700 depuis `_demarrage`) ; coup de pied au watchdog dans chaque attente.
| ==================================================================================

        .section .haut, "ax"
        .global _editeur_dip
        | LE MOTEUR, partagé avec GAME SETTINGS du menu en jeu (`menu.s`) : le pointeur du bloc,
        | la table des réglages, le pas d'une valeur, les défauts, le texte d'une valeur.
        .global _dip_bloc, _dip_table, _dip_pas_valeur, _dip_defauts, _dip_valeur, _dip_copier

        .equ    VRAMADDR, 0x3C0000
        .equ    VRAMRW,   0x3C0002
        .equ    VRAMMOD,  0x3C0004
        .equ    LSPCMODE, 0x3C0006
        .equ    WATCHDOG, 0x300001
        .equ    DIPSW,    0x300001      | en lecture : les commutateurs de la carte, actifs bas
        .equ    P1CNT,    0x300000
        .equ    SYSTYPE,  0x300081
        .equ    SOUND,    0x320000
        .equ    STATUS_B, 0x380000
        .equ    BRDFIX,   0x3A000B
        .equ    CRTFIX,   0x3A001B
        .equ    PALBANK0, 0x3A000F
        .equ    PALETTES, 0x400000
        .equ    FOND,     0x401FFE
        .equ    GAME_DIP, 0x10FD84
        | La copie du bloc soft-DIP (voir l'en-tête, LA COPIE) : la RAM du menu en jeu, de GAME
        | SETTINGS et de l'éditeur mémoire (`menu.s`, `reglages-jeu.s`, `memoire.s`), au-dessus du
        | drapeau de `plantage.s` ($10F458-$10F45B) et sous les cheats ($10FB00).
        .equ    COPIE_FIN, 0x10F460     | .l la fin de ce qui a été copié
        .equ    COPIE,     0x10F464     | le bloc, à partir de son octet $00
        .equ    COPIE_LIM, 0x10FB00     | 1 692 octets : le nom, les temps et choix, 138 intitulés

        | La mise en page, en cases du plan fixe.
        .equ    CASE_TITRE, 0x7000 + 11 * 32 + 3       | 8×16, lignes 3-4
        .equ    CASE_NOM,   0x7000 + 12 * 32 + 6       | 16 caractères
        .equ    CASE_LIGNE, 0x7000 +  3 * 32 + 7       | ligne 0 de la liste, colonne 3
        | L'aide aux lignes 28 et 29 : la liste en tient 21, lignes 7 à 27, juste sous le nom.
        .equ    CASE_AIDE1, 0x7000 +  3 * 32 + 28
        .equ    CASE_AIDE2, 0x7000 +  3 * 32 + 29
        .equ    LARGEUR,    31          | une ligne de liste : colonnes 3 à 33
        .equ    COL_VALEUR, 19          | la valeur en colonne 22

        | Les couleurs, $0RGB (« Colors »). Choix d'aspect.
        .equ    C_TEXTE,  0x0BBB
        .equ    C_CHOISI, 0x0FE3
        .equ    C_TITRE,  0x04BF
        .equ    C_AIDE,   0x0777

        | Le cadre de pile : la table des lignes, un tampon de ligne, le bloc.
        .equ    N_MAX,    22            | la région + 4 spéciaux + 10 à choix + la borne
                                        | + les scores + la carte + le mode + les tests
                                        | + le jukebox + la remise
        .equ    T_ENTREE, 12            | +0 genre, +1 octet de GAME_DIP, +2 nombre de
                                        | choix, +3 défaut, +4 temps par défaut, +6 intitulé
        .equ    F_TABLE,  -(N_MAX * T_ENTREE)
        .equ    F_TAMPON, F_TABLE - 32
        .equ    F_BLOC,   F_TAMPON - 4
        .equ    F_REGION, F_BLOC - 1    | la région affichée, 0-2
        .equ    F_REGION0, F_BLOC - 2   | la région à l'entrée
        .equ    F_INSCRIT, F_REGION0 - 4 | %a3 reçu : l'index de l'entrée du jeu
        .equ    F_SOFTDIP, F_INSCRIT - 4 | le bloc soft-DIP de la cartouche, 0 si refusé
        .equ    F_MODE,   F_SOFTDIP - 1 | le mode affiché : 0 MVS, 1 AES
        .equ    F_MODE0,  F_SOFTDIP - 2 | le mode à l'entrée
        .equ    F_NOUVEAU, F_SOFTDIP - 3 | %d6 reçu : 1, le slot vient d'être inscrit
        .equ    F_SCORES, F_SOFTDIP - 4 | SCORE RESET affiché : 0 ON, 1 OFF
        .equ    F_SCORES0, F_SOFTDIP - 5 | SCORE RESET à l'entrée
        .equ    F_BORNE,  F_SOFTDIP - 6 | la borne affichée, bits de `reglages.s`
        .equ    F_BORNE0, F_SOFTDIP - 7 | la borne à l'entrée
        .equ    F_SOUS,   F_SOFTDIP - 8 | 1 : le sous-écran CABINET SETTINGS est ouvert
        .equ    F_SV_D6,  F_SOFTDIP - 10 | .w le nombre de lignes de la liste, sous-écran ouvert
        .equ    F_SV_D7,  F_SOFTDIP - 12 | .w sa ligne choisie
        .equ    F_TABLE_B, F_SV_D7 - 5 * T_ENTREE | les cinq lignes du sous-écran
        .equ    F_HAUT,   F_TABLE_B - 2 | .w la liste en 8×16 : la première entrée affichée
        .equ    F_GRAND,  F_TABLE_B - 3 | 1 : la liste en 8×16 (voir l'en-tête, LA LISTE EN 8×16)
        .equ    F_GRAND0, F_TABLE_B - 4 | F_GRAND, gardé pendant le sous-écran
        .equ    F_LIEN,   F_TABLE_B - 4
        .equ    FENETRE,  10            | la liste en 8×16 : dix entrées, rangées 7 à 26
        | Genres : 0 temps, 1 compte, 2 nombre de fois, 3 à choix, 4 remise aux défauts,
        | 5 la région, 6 les autotests, 7 le jukebox, 8 le mode, 9 la carte mémoire,
        | 10 SCORE RESET, 11 CABINET SETTINGS ; au sous-écran, 12 FREE PLAY, 13 NO CONTINUE,
        | 14 DEMO SOUND, 15 CHEATS/DEBUG (le bit 0, 1, 2, 3 de la borne : genre - 12), 16 DEBUG DIPS
        | (`debug.s`).

_editeur_dip:
        btst    #7, SYSTYPE             | TEST tenu : bit 7 à 0 (mesuré, voir l'en-tête)
        beq.s   1f
        btst    #0, DIPSW               | le commutateur 1, « Setting Mode », à ON
        beq.s   1f
        btst    #0, STATUS_B            | START et SELECT de P1 tenus (voir l'en-tête)
        bne.s   2f
        btst    #1, STATUS_B
        beq.s   3f
2:      rts
| A, B, C ET D DE P1 TENUS TOUS LES QUATRE (REG_P1CNT bits 4-7 à 0, actifs bas) : la mise en
| route de l'adaptateur BlueRetro, pas un joueur (voir l'en-tête). Une seule lecture : bits 4-7
| à 0, l'octet est sous $10. À part, après le `rts` : TEST, le commutateur 1, START seul et
| SELECT absent gardent leurs cycles d'avant.
3:      cmpi.b  #0x10, P1CNT
        bcs.s   2b                      | les quatre tenus : le geste est refusé
1:      movem.l %d0-%d7/%a0-%a6, -(%sp)
        | LE COMMUTATEUR 3 lu ici, à l'ouverture, et pas après : P1 dans cet écran et ceux qu'il ouvre
        | (`panneau.s`, DECISIONS §30).
        jsr     _panneau_verrou
        link    %a6, #F_LIEN
        move.b  %d6, F_NOUVEAU(%a6)
        move.l  %a3, F_INSCRIT(%a6)
        lea     -16(%a1), %a2
        move.l  %a2, F_BLOC(%a6)        | le bloc de sauvegarde du jeu
        lea     GAME_DIP, %a5

        bsr     _dip_bloc               | %a3 : le bloc soft-DIP, 0 si refusé
        move.l  %a3, F_SOFTDIP(%a6)     | `.Lligne` écrase %a3 : `.Lecran` le relit ici
        bra     .Lapres_bloc

| LE POINTEUR DU BLOC SOFT-DIP, comme `_slot_inscrit` (`c0.s`). Sortie : %a3, 0 si refusé.
| Clobbers %d4, %a2.
_dip_bloc:
        suba.l  %a3, %a3
        moveq   #0, %d4
        move.b  0x10FD83, %d4           | BIOS_COUNTRY_CODE
        cmpi.b  #2, %d4
        bls.s   1f
        moveq   #2, %d4
1:      lsl.w   #2, %d4
        lea     0x116, %a2
        move.l  (%a2,%d4.w), %d4
        beq.s   2f
        cmpi.l  #0x100000 - 0x20, %d4
        bls.s   3f                      | tient dans la P-ROM fixe
        cmpi.l  #0x200000, %d4
        blo.s   2f                      | déborde la P-ROM fixe, ou entre les zones
        cmpi.l  #0x300000 - 0x20, %d4
        bhi.s   2f                      | déborde la zone banquée, ou au-delà
3:      movea.l %d4, %a3
2:      rts

.Lapres_bloc:
        | LA RÉGION EN COURS : BIOS_COUNTRY_CODE, que `c0.s` a pris aux réglages du BIOS
        | ou au descripteur. Hors de 0-2, l'Europe, comme le pointeur ci-dessus.
        move.b  0x10FD83, %d0
        cmpi.b  #2, %d0
        bls.s   1f
        moveq   #2, %d0
1:      move.b  %d0, F_REGION(%a6)
        move.b  %d0, F_REGION0(%a6)
        | LE MODE EN COURS : BIOS_MVS_FLAG, que `c0.s` a pris aux réglages ou au descripteur.
        moveq   #0, %d0                 | bit 7 à 1 : MVS
        tst.b   0x10FD82
        bmi.s   1f
        moveq   #1, %d0                 | AES
1:      move.b  %d0, F_MODE(%a6)
        move.b  %d0, F_MODE0(%a6)
        | SCORE RESET EN COURS : celui des réglages (`reglages.s`), ON sans bloc valide.
        jsr     _reglages_scores        | clobbers %d0, %d1, %a0, %a1
        move.b  %d0, F_SCORES(%a6)
        move.b  %d0, F_SCORES0(%a6)
        | LA BORNE EN COURS : celle des réglages, 0 sans bloc valide.
        jsr     _reglages_borne         | clobbers %d0, %d1, %a0, %a1
        move.b  %d0, F_BORNE(%a6)
        move.b  %d0, F_BORNE0(%a6)
        clr.b   F_SOUS(%a6)
        clr.b   F_GRAND(%a6)
        clr.w   F_HAUT(%a6)

        | LA TABLE DES LIGNES. %a2 : l'entrée à remplir ; %a1 : le prochain intitulé ;
        | %d6 : le nombre de lignes. Tout est lu par octet : un bloc impair est accepté.
        | La région d'abord, toujours là, même sans bloc soft-DIP.
        lea     F_TABLE(%a6), %a4
        movea.l %a4, %a2
        moveq   #0, %d6
        move.b  #5, (%a2)
        clr.b   1(%a2)
        lea     .Ltxt_region, %a1
        bsr     .Lentree
        move.l  %a3, %d0
        beq     .Ltable_fin
        bsr     _dip_table
        bsr     .Lcopier_bloc           | le bloc en RAM : rien n'est plus lu dans la P-ROM
        bsr     .Lgrand
        bra     .Ltable_fin

| LA LISTE EN 8×16 (voir l'en-tête) : région JAPAN, et un octet hors de $20-$7E dans les intitulés
| copiés, de l'octet $20 du bloc à COPIE_FIN. Clobbers %d0, %a0, %a1.
.Lgrand:
        tst.b   F_REGION0(%a6)          | 0 : JAPAN
        bne.s   9f
        lea     COPIE + 0x20, %a0
        movea.l COPIE_FIN, %a1
1:      cmpa.l  %a1, %a0
        bhs.s   9f
        move.b  (%a0)+, %d0
        cmpi.b  #0x20, %d0
        bcs.s   2f
        cmpi.b  #0x7E, %d0
        bls.s   1b
2:      move.b  #1, F_GRAND(%a6)
9:      rts

| LES LIGNES DES RÉGLAGES DE LA CARTOUCHE (genres 0 à 3), du bloc %a3 (non nul). %a2 : l'entrée
| à remplir, avancée ; %d6 : le nombre de lignes, augmenté. Clobbers %d0-%d2, %a1.
_dip_table:
        lea     0x20(%a3), %a1
        moveq   #0, %d1                 | les deux temps, octets $10 et $12
.Lt_temps:
        move.b  0x10(%a3,%d1.w), %d2
        lsl.w   #8, %d2
        move.b  0x11(%a3,%d1.w), %d2
        cmpi.w  #0xFFFF, %d2
        beq.s   1f                      | inutilisé : ni ligne ni intitulé
        clr.b   (%a2)
        move.b  %d1, 1(%a2)
        move.w  %d2, 4(%a2)
        bsr     .Lentree
1:      addq.w  #2, %d1
        cmpi.w  #4, %d1
        bcs.s   .Lt_temps
.Lt_comptes:                            | %d1 = 4 puis 5 : genres 1 et 2
        move.b  0x10(%a3,%d1.w), %d2
        cmpi.b  #0xFF, %d2
        beq.s   1f
        move.b  %d1, %d0
        subq.b  #3, %d0
        move.b  %d0, (%a2)
        move.b  %d1, 1(%a2)
        move.b  %d2, 3(%a2)
        bsr     .Lentree
1:      addq.w  #1, %d1
        cmpi.w  #6, %d1
        bcs.s   .Lt_comptes
.Lt_choix:                              | %d1 = 6 à 15
        move.b  0x10(%a3,%d1.w), %d2
        moveq   #0x0F, %d0
        and.b   %d2, %d0                | le nombre de choix
        beq.s   1f                      | 0 : SUPPOSÉ, ni ligne ni intitulé
        move.b  #3, (%a2)
        move.b  %d1, 1(%a2)
        move.b  %d0, 2(%a2)
        lsr.b   #4, %d2
        move.b  %d2, 3(%a2)
        bsr     .Lentree
        mulu    #12, %d0                | les intitulés des choix
        adda.w  %d0, %a1
1:      addq.w  #1, %d1
        cmpi.w  #16, %d1
        bcs.s   .Lt_choix
        rts
.Ltable_fin:
        move.b  #11, (%a2)              | CABINET SETTINGS, avant SCORE RESET
        clr.b   1(%a2)
        move.l  #.Ltxt_borne, 6(%a2)
        lea     T_ENTREE(%a2), %a2
        addq.w  #1, %d6
        move.b  #10, (%a2)              | SCORE RESET, avant la carte
        clr.b   1(%a2)
        move.l  #.Ltxt_scores, 6(%a2)
        lea     T_ENTREE(%a2), %a2
        addq.w  #1, %d6
        move.b  #9, (%a2)               | la carte mémoire, avant le mode
        clr.b   1(%a2)
        move.l  #.Ltxt_carte, 6(%a2)
        lea     T_ENTREE(%a2), %a2
        addq.w  #1, %d6
        move.b  #8, (%a2)               | le mode, avant les autotests
        clr.b   1(%a2)
        move.l  #.Ltxt_mode, 6(%a2)
        lea     T_ENTREE(%a2), %a2
        addq.w  #1, %d6
        move.b  #6, (%a2)               | les autotests, avant la remise
        clr.b   1(%a2)
        move.l  #.Ltxt_tests, 6(%a2)
        lea     T_ENTREE(%a2), %a2
        addq.w  #1, %d6
        move.b  #7, (%a2)               | le jukebox, après les tests
        clr.b   1(%a2)
        move.l  #.Ltxt_jukebox, 6(%a2)
        lea     T_ENTREE(%a2), %a2
        addq.w  #1, %d6
        move.b  #4, (%a2)               | la remise aux défauts, toujours la dernière
        clr.b   1(%a2)
        move.l  #.Ltxt_defaut, 6(%a2)
        addq.w  #1, %d6

        | LES VALEURS REÇUES, rendues valides.
        lea     T_ENTREE(%a4), %a2      | après la région
        move.w  %d6, %d7
        subi.w  #8 + 1, %d7             | les lignes de réglage : région, borne, scores,
                                        | carte, mode, tests, jukebox, remise exclus
        bmi.s   2f
1:      bsr     .Lnormaliser
        lea     T_ENTREE(%a2), %a2
        dbra    %d7, 1b
2:      bsr     .Linutilises

        | LE Z80 EN RAM, PUIS LA POLICE DE LA CARTE (voir l'en-tête).
        moveq   #8-1, %d4
1:      bsr     .Lsync
        dbra    %d4, 1b
        | L'écho n'est lu qu'une trame après chaque envoi, comme `menu.s` et `jukebox.s` : lu
        | dans la boucle même, une réponse précédente du pilote déjà à $01 passerait pour lui.
        moveq   #60-1, %d4
2:      move.b  #0x01, SOUND
        bsr     .Lsync
        cmpi.b  #0x01, SOUND
        dbeq    %d4, 2b
        bsr     .Lsync                  | une trame pour que le pilote entre en boucle
        move.b  %d0, BRDFIX

        lea     VRAMRW, %a0
        moveq   #0, %d7                 | %d7 : la ligne choisie
        bsr     .Lecran

        | L'ÉTAT DES BOUTONS À L'ENTRÉE : un bouton déjà tenu ne compte pas.
        moveq   #0, %d5
        bsr     .Lentrees
        bra     .Lboucle

| L'ÉCRAN, tout entier. Palettes après le passage de la ligne $1F0, puis tout le texte.
| Appelé à l'entrée et au retour des autotests. Clobbers %d0-%d4, %a1-%a3.
.Lecran:
        bsr     .Lsync
        move.b  %d0, PALBANK0           | la banque 0, celle de `ecran.s`
        move.w  #0x8000, PALETTES       | référence : « pure black ($8000) », « Palettes »
        move.w  #0x8000, FOND
        moveq   #0, %d1                 | la palette 0, sous FIX_CLEAR : entrées 1-15 noires
        moveq   #0, %d2                 | (voir l'en-tête, L'AFFICHAGE)
        bsr     .Lpalette
        moveq   #1, %d1
        move.w  #C_TEXTE, %d2
        bsr     .Lpalette
        moveq   #2, %d1
        move.w  #C_CHOISI, %d2
        bsr     .Lpalette
        moveq   #3, %d1
        move.w  #C_TITRE, %d2
        bsr     .Lpalette
        moveq   #4, %d1
        move.w  #C_AIDE, %d2
        bsr     .Lpalette
        jsr     _fix_clear
        move.w  #32, VRAMMOD            | une écriture = une colonne

        move.w  #CASE_TITRE, %d1        | le titre en 8×16
        bsr     .Ltitre
        move.w  #0x3100, %d3
        bsr     .Lecrire
        move.w  #CASE_TITRE + 1, %d1
        bsr     .Ltitre
        move.w  #0x3200, %d3
        bsr     .Lecrire
        move.w  #CASE_NOM, %d1          | le nom du jeu, octets $00-$0F du bloc
        lea     .Ltxt_sans, %a2
        move.l  F_SOFTDIP(%a6), %d0
        beq.s   1f
        movea.l %d0, %a2
1:      moveq   #16, %d4
        move.w  #0x3000, %d3
        bsr     .Lecrire
        move.w  #CASE_AIDE1, %d1
        lea     .Ltxt_aide1, %a2
        moveq   #L_AIDE1, %d4
        move.w  #0x4000, %d3
        bsr     .Lecrire
        move.w  #CASE_AIDE2, %d1
        lea     .Ltxt_aide2, %a2
        moveq   #L_AIDE2, %d4
        tst.b   F_SOUS(%a6)
        beq.s   1f
        lea     .Ltxt_aide2_b, %a2
        moveq   #L_AIDE2_B, %d4
1:      move.w  #0x4000, %d3
        bsr     .Lecrire
        bra     .Ltout

| LE TITRE, %a2 et %d4 : celui de la liste, ou CABINET SETTINGS au sous-écran.
.Ltitre:
        lea     .Ltxt_titre, %a2
        moveq   #L_TITRE, %d4
        tst.b   F_SOUS(%a6)
        beq.s   1f
        lea     .Ltxt_borne, %a2
        moveq   #L_BORNE, %d4
1:      rts

| ----------------------------------------------------------------------------------
| LA BOUCLE, une trame par tour. Une seule action par trame, START d'abord.
.Lboucle:
        bsr     .Lsync
        bsr     .Lentrees
        btst    #5, %d0
        bne     .Lstart
        btst    #0, %d0                 | haut
        beq.s   2f
        move.w  %d7, %d0
        subq.w  #1, %d7
        bpl.s   1f
        move.w  %d6, %d7
        subq.w  #1, %d7
1:      bsr     .Lligne                 | l'ancienne ligne, puis la nouvelle
        move.w  %d7, %d0
        bsr     .Lligne
        bra.s   .Lboucle
2:      btst    #1, %d0                 | bas
        beq.s   2f
        move.w  %d7, %d0
        addq.w  #1, %d7
        cmp.w   %d6, %d7
        bcs.s   1b
        moveq   #0, %d7
        bra.s   1b
2:      moveq   #1, %d2                 | droite
        btst    #3, %d0
        bne.s   3f
        moveq   #-1, %d2                | gauche
        btst    #2, %d0
        bne.s   3f
        moveq   #2, %d2                 | A
        btst    #4, %d0
        beq.s   .Lboucle
3:      bsr     .Lchanger
        bra.s   .Lboucle

| START : au sous-écran, le retour à la liste, sur la ligne CABINET SETTINGS ; sinon la sortie.
.Lstart:
        tst.b   F_SOUS(%a6)
        beq.s   .Lsortie
        clr.b   F_SOUS(%a6)
        move.b  F_GRAND0(%a6), F_GRAND(%a6)
        lea     F_TABLE(%a6), %a4
        move.w  F_SV_D6(%a6), %d6
        move.w  F_SV_D7(%a6), %d7
        bsr     .Lecran
        bsr     .Lentrees               | START encore tenu ne compte pas
        bra     .Lboucle

| ----------------------------------------------------------------------------------
| LA SORTIE : GAME_DIP dans le bloc, l'écran rendu, la cartouche remise sous le Z80. Le
| commutateur 1 encore à ON : l'avertissement d'abord (voir l'en-tête).
.Lsortie:
        btst    #0, DIPSW               | « Setting Mode » : bit 0 à 0, ON
        bne.s   1f
        bsr     .Lavertir
1:
        movea.l F_BLOC(%a6), %a2
        movea.l %a5, %a1
        move.l  (%a1)+, (%a2)+          | GAME_DIP → bloc de sauvegarde, 16 octets
        move.l  (%a1)+, (%a2)+
        move.l  (%a1)+, (%a2)+
        move.l  (%a1)+, (%a2)+
        lea     COPIE_FIN, %a2          | la copie effacée : ces variables à zéro, comme le boot
        move.w  #(COPIE_LIM - COPIE_FIN) / 4 - 1, %d4
1:      clr.l   (%a2)+
        dbra    %d4, 1b
        bsr     .Lsync
        moveq   #0, %d4                 | palette 0 comprise
1:      move.w  %d4, %d1
        moveq   #0, %d2
        bsr     .Lpalette
        addq.w  #1, %d4
        cmpi.w  #4, %d4
        bls.s   1b
        clr.w   FOND                    | la référence reste à $8000
        jsr     _fix_clear              | REG_VRAMMOD laissé à 1
        move.b  %d0, CRTFIX             | S ROM et M1 de la cartouche
        move.b  #0x03, SOUND            | reset du Z80, sur la M1 de la cartouche
        move.b  %d0, WATCHDOG

        | LA RÉGION OU LE MODE A CHANGÉ : on l'enregistre, puis la machine repart. Les jeux lisent
        | la région à leur init (relevé cité par `c0.s`), et le boot en tire le
        | pointeur des soft-DIP et CARD_REGION : seul un boot complet les remet d'accord.
        | LA RELANCE PAR LE WATCHDOG, pas par un saut au vecteur de reset. Lu dans
        | « Watchdog » : sans coup de pied, il « resets the whole system », au bout
        | d'environ 8 trames. Un `jmp` vers $C00402 ne referait que le 68000 et laisserait
        | REG_CRTFIX, la banque de palettes et le pilote son dans l'état de l'éditeur.
        | SUPPOSÉ : que « whole system » couvre le Z80 et ces bascules. Mesuré (jig
        | `bench/editeur.lua`, aof et kof98, le 2026-10-20) : START à la trame 300, RESET à 309, puis l'écran de boot et BIOS_COUNTRY_CODE
        | réglé dès le boot suivant. Backup RAM reverrouillée avant ; IRQ masquées.
        | L'ENTRÉE DU JEU REDEVIENT LIBRE (%a3 à l'entrée, `c0.s` ; index $FFFF, sa
        | convention), qu'il vienne d'être inscrit ou qu'il l'ait été avant. Le boot suivant
        | le réinscrit comme un premier boot : demande 0, et les soft-DIP par défaut du bloc
        | de la nouvelle région. Sinon il relirait GAME_DIP décodé sous l'ancienne région,
        | dont un choix peut sortir des bornes du nouveau bloc. Ce que ça coûte : les
        | soft-DIP choisis sont perdus, et la demande 0 réinitialise les données que le jeu
        | garde en backup RAM (« USER subroutine », cité par `c0.s`). Mesuré sur kof98
        | (même jig) : sans cette ligne, remise en demande 2 après la relance ; avec, sa
        | demande 0 revient (son reset volontaire à la trame 501).
        | LE MODE, par le même chemin, l'entrée du jeu gardée (voir l'en-tête).
        | SCORE RESET CHANGÉ : enregistré, avec la date lue maintenant, sans relance.
        move.b  F_SCORES(%a6), %d0
        cmp.b   F_SCORES0(%a6), %d0
        beq.s   6f
        jsr     _read_calendar          | registres rendus ; $10FDD2-$10FDD5 : la date
        move.b  F_SCORES(%a6), %d0
        jsr     _reglages_ecrire_scores
        | LA BORNE CHANGÉE : enregistrée, sans relance, et sa copie en RAM reposée (`reglages.s`).
6:      move.b  F_BORNE(%a6), %d0
        cmp.b   F_BORNE0(%a6), %d0
        beq.s   7f
        jsr     _reglages_ecrire_borne
        jsr     _borne_ram
        | LES DEBUG DIPS (`debug.s`) : posés dans la zone du jeu, ou oubliés sous CHEATS/DEBUG OFF.
7:      jsr     _dd_poser               | registres rendus
        moveq   #0, %d4                 | rien d'enregistré
        move.b  F_REGION(%a6), %d0
        cmp.b   F_REGION0(%a6), %d0
        beq.s   3f
        movea.l F_INSCRIT(%a6), %a2
        move.w  #0xFFFF, (%a2)
        jsr     _reglages_ecrire_region
        moveq   #1, %d4
3:      move.b  F_MODE(%a6), %d0
        cmp.b   F_MODE0(%a6), %d0
        beq.s   4f
        tst.b   F_NOUVEAU(%a6)
        beq.s   5f                      | un jeu connu : son entrée reste
        movea.l F_INSCRIT(%a6), %a2
        move.w  #0xFFFF, (%a2)
5:      move.b  F_MODE(%a6), %d0
        addq.b  #1, %d0                 | 1 MVS, 2 AES (`reglages.s`)
        jsr     _reglages_ecrire_mode
        moveq   #1, %d4
4:      tst.b   %d4
        beq.s   1f
        move.b  %d0, 0x3A000D           | REG_SRAMLOCK
2:      bra.s   2b                      | sans coup de pied : le watchdog mord
1:      unlk    %a6
        movem.l (%sp)+, %d0-%d7/%a0-%a6
        rts

| ----------------------------------------------------------------------------------
| LE BLOC SOFT-DIP RECOPIÉ EN RAM (voir l'en-tête, LA COPIE), tant que REG_CRTFIX tient : le nom
| et tous les intitulés, de %a3 à %a1 (la fin que `_dip_table` laisse), sans dépasser la zone du
| bloc ni la copie. Puis les intitulés de la table (%a4 à %a2, genres 0 à 3) et le bloc
| (F_SOFTDIP, %a3) visent la copie. Clobbers %d0-%d2, %a0, %a1.
.Lcopier_bloc:
        move.l  %a1, %d1
        sub.l   %a3, %d1                | la taille : $20 + 12 × intitulés
        move.l  #0x100000, %d2          | la fin de la zone du bloc
        cmpa.l  %d2, %a3
        blo.s   1f
        move.l  #0x300000, %d2
1:      sub.l   %a3, %d2
        cmp.l   %d2, %d1
        bls.s   1f
        move.l  %d2, %d1                | pas au-delà de sa zone
1:      cmpi.l  #COPIE_LIM - COPIE, %d1
        bls.s   1f
        move.l  #COPIE_LIM - COPIE, %d1 | pas au-delà de la copie
1:      lea     COPIE, %a0
        movea.l %a3, %a1
        move.l  %a0, %d0
        add.l   %d1, %d0
        move.l  %d0, COPIE_FIN
        subq.w  #1, %d1
2:      move.b  (%a1)+, (%a0)+
        dbra    %d1, 2b
        move.l  #COPIE, %d0
        sub.l   %a3, %d0                | de la P-ROM à la copie
        movea.l %a4, %a0
3:      cmpa.l  %a2, %a0
        bhs.s   5f
        cmpi.b  #3, (%a0)
        bhi.s   4f                      | la région : une chaîne du BIOS
        add.l   %d0, 6(%a0)
4:      lea     T_ENTREE(%a0), %a0
        bra.s   3b
5:      lea     COPIE, %a3
        move.l  %a3, F_SOFTDIP(%a6)
        rts

| ----------------------------------------------------------------------------------
| UNE ENTRÉE DE TABLE : son intitulé, %a1, puis au suivant. Avance %a2 et %d6.
.Lentree:
        move.l  %a1, 6(%a2)
        lea     12(%a1), %a1
        lea     T_ENTREE(%a2), %a2
        addq.w  #1, %d6
        rts

| LES BOUTONS. %d5 : l'état de la trame d'avant, mis à jour ; %d0 : les fronts.
| Bits : 0 haut, 1 bas, 2 gauche, 3 droite, 4 A, 5 START. Clobbers %d1, %d2.
.Lentrees:
        jsr     _panneau_p1             | %d0 : P1, manette ou panneau traduit (`panneau.s`)
        move.b  %d0, %d2
        not.b   %d2
        andi.b  #0x1F, %d2
        move.b  STATUS_B, %d1
        not.b   %d1
        andi.b  #0x01, %d1
        lsl.b   #5, %d1
        or.b    %d1, %d2
        move.b  %d5, %d0
        not.b   %d0
        and.b   %d2, %d0
        move.b  %d2, %d5
        rts

| L'ENTRÉE DE LA LIGNE %d0 dans %a2.
.Ladresse:
        move.w  %d0, %d1
        mulu    #T_ENTREE, %d1
        lea     (%a4,%d1.w), %a2
        rts

| ----------------------------------------------------------------------------------
| CHANGER LA VALEUR DE LA LIGNE CHOISIE. %d2 : +1 droite, -1 gauche, 2 A (suivant,
| en boucle). Puis la ligne est réécrite. Clobbers %d0-%d4, %a2.
.Lchanger:
        move.w  %d7, %d0
        bsr.s   .Ladresse
        move.b  (%a2), %d0
        cmpi.b  #4, %d0
        beq     .Ldefauts
        cmpi.b  #5, %d0
        beq     .Lch_region
        cmpi.b  #6, %d0
        beq     .Lch_tests
        cmpi.b  #7, %d0
        beq     .Lch_jukebox
        cmpi.b  #8, %d0
        beq     .Lch_mode
        cmpi.b  #9, %d0
        beq     .Lch_carte
        cmpi.b  #10, %d0
        beq     .Lch_scores
        cmpi.b  #11, %d0
        beq     .Lch_borne
        cmpi.b  #16, %d0
        beq     .Lch_debug
        cmpi.b  #12, %d0
        bcc     .Lch_bval
        bsr.s   _dip_pas_valeur
        bra     .Lch_fin

| UN PAS SUR LA VALEUR D'UN RÉGLAGE DE LA CARTOUCHE (genres 0 à 3), l'entrée %a2, dans GAME_DIP
| (%a5). %d2 : +1, -1, ou 2 (A : le suivant, en boucle). Clobbers %d0-%d4.
_dip_pas_valeur:
        moveq   #0, %d1
        move.b  1(%a2), %d1             | l'octet de GAME_DIP
        tst.b   (%a2)
        beq.s   .Lch_temps
        bsr     .Lbornes                | %d3 min, %d4 max
        moveq   #0, %d0
        move.b  (%a5,%d1.w), %d0
        bsr     .Lpas
        move.b  %d0, (%a5,%d1.w)
        rts
.Lch_temps:
        | En secondes : minutes × 60 + secondes, bornées à 0-1799 (29:59).
        move.w  %d2, -(%sp)             | le sens, que `.Lbcd_bin` écrase
        move.w  (%a5,%d1.w), %d4
        move.w  %d4, %d0
        lsr.w   #8, %d0
        bsr     .Lbcd_bin
        mulu    #60, %d0
        move.w  %d0, %d3
        move.w  %d4, %d0
        andi.w  #0xFF, %d0
        bsr     .Lbcd_bin
        add.w   %d3, %d0
        moveq   #0, %d3
        move.w  #1799, %d4
        move.w  (%sp)+, %d2
        bsr     .Lpas
        andi.l  #0xFFFF, %d0
        divu    #60, %d0               | minutes au mot bas, secondes au haut
        move.w  %d0, %d3
        bsr     .Lbin_bcd
        move.b  %d3, %d4
        lsl.w   #8, %d4
        swap    %d0
        move.w  %d0, %d3
        bsr     .Lbin_bcd
        move.b  %d3, %d4
        move.w  %d4, (%a5,%d1.w)
        rts
.Lch_region:                            | 0 Japon, 1 USA, 2 Europe
        moveq   #0, %d0
        move.b  F_REGION(%a6), %d0
        moveq   #0, %d3
        moveq   #2, %d4
        bsr.s   .Lpas
        move.b  %d0, F_REGION(%a6)
        bra.s   .Lch_fin
.Lch_mode:                              | 0 MVS, 1 AES
        moveq   #0, %d0
        move.b  F_MODE(%a6), %d0
        moveq   #0, %d3
        moveq   #1, %d4
        bsr.s   .Lpas
        move.b  %d0, F_MODE(%a6)
        bra.s   .Lch_fin
.Lch_scores:                            | 0 ON, 1 OFF
        moveq   #0, %d0
        move.b  F_SCORES(%a6), %d0
        moveq   #0, %d3
        moveq   #1, %d4
        bsr.s   .Lpas
        move.b  %d0, F_SCORES(%a6)
.Lch_fin:
        move.w  %d7, %d0
        bra     .Lligne
.Lch_tests:
        jsr     _autotests              | registres rendus
        bra.s   1f
.Lch_jukebox:
        movea.l F_SOFTDIP(%a6), %a1     | le nom du jeu ; registres rendus
        jsr     _jukebox
        bra.s   1f
.Lch_carte:
        jsr     _gestion_carte          | registres rendus
        bra.s   1f
.Lch_debug:                             | CHEATS/DEBUG OFF (affiché) : la ligne ne s'ouvre pas
        btst    #3, F_BORNE(%a6)
        bne     .Lch_fin
        jsr     _debug_dips             | registres rendus
1:      bsr     .Lecran
        bra     .Lentrees               | un bouton encore tenu (START) ne compte pas

| UN PAS. %d0 : la valeur ; %d2 : le sens ; %d3, %d4 : les bornes. Résultat dans %d0.
.Lpas:
        cmpi.w  #2, %d2
        beq.s   2f
        add.w   %d2, %d0
        cmp.w   %d3, %d0
        bge.s   1f
        move.w  %d3, %d0
1:      cmp.w   %d4, %d0
        ble.s   3f
        move.w  %d4, %d0
3:      rts
2:      addq.w  #1, %d0                 | A : le suivant, puis le minimum
        cmp.w   %d4, %d0
        ble.s   3b
        move.w  %d3, %d0
        rts

| LE SOUS-ÉCRAN CABINET SETTINGS : la liste gardée (%d6, %d7), la table des cinq lignes, l'écran.
.Lch_borne:
        move.w  %d6, F_SV_D6(%a6)
        move.w  %d7, F_SV_D7(%a6)
        move.b  #1, F_SOUS(%a6)
        move.b  F_GRAND(%a6), F_GRAND0(%a6)
        clr.b   F_GRAND(%a6)            | le sous-écran reste en 8×8 : du texte du BIOS
        lea     F_TABLE_B(%a6), %a4
        movea.l %a4, %a2
        moveq   #12, %d0
        lea     .Ltxt_libre, %a1        | cinq intitulés de 12 caractères, à la suite
2:      move.b  %d0, (%a2)
        clr.b   1(%a2)
        move.l  %a1, 6(%a2)
        lea     12(%a1), %a1
        lea     T_ENTREE(%a2), %a2
        addq.b  #1, %d0
        cmpi.b  #17, %d0
        bcs.s   2b
        moveq   #5, %d6
        moveq   #0, %d7
        bsr     .Lecran
        bra     .Lentrees
| UNE VALEUR DE LA BORNE (genres 12 à 15) : le bit genre - 12 de F_BORNE, borné à 0-1 par `.Lpas`.
| La ligne MODE à AES : rien ne change (MVS ONLY), sauf CHEATS/DEBUG, qui vaut dans les deux modes.
| FREE PLAY sous le commutateur 7 de la carte à ON : rien ne change non plus, la valeur dit DIP
| (`.Lv_borne`) ; le bit enregistré reste ce qu'il était.
.Lch_bval:
        cmpi.b  #15, %d0
        beq.s   1f
        cmpi.b  #1, F_MODE(%a6)
        beq     .Lch_fin
        cmpi.b  #12, %d0
        bne.s   1f
        btst    #6, DIPSW               | « Freeplay », bit 6 à 0 : ON
        beq     .Lch_fin
1:      moveq   #0, %d1
        move.b  %d0, %d1
        subi.w  #12, %d1                | le bit
        moveq   #0, %d0
        btst    %d1, F_BORNE(%a6)
        beq.s   2f
        moveq   #1, %d0
2:      moveq   #0, %d3
        moveq   #1, %d4
        bsr     .Lpas
        bclr    %d1, F_BORNE(%a6)
        tst.w   %d0
        beq.s   3f
        bset    %d1, F_BORNE(%a6)
3:      cmpi.w  #3, %d1                 | CHEATS/DEBUG : la ligne DEBUG DIPS change avec elle
        bne     .Lch_fin
        bra     .Ltout

| LES DÉFAUTS DE LA CARTOUCHE, sur toutes les lignes, puis tout est réécrit.
.Ldefauts:
        bsr.s   _dip_defauts
        bra     .Ltout

| LES DÉFAUTS DE LA CARTOUCHE sur les %d6 entrées de la table %a4 : seuls les genres 0 à 3
| (les réglages) sont touchés. Clobbers %d0-%d4, %a2.
_dip_defauts:
        movea.l %a4, %a2
        move.w  %d6, %d4
        subq.w  #1, %d4
        bmi.s   3f
1:      cmpi.b  #4, (%a2)               | ni la remise, ni la région, ni les tests…
        bcc.s   5f
        moveq   #0, %d1
        move.b  1(%a2), %d1
        tst.b   (%a2)
        bne.s   2f
        move.w  4(%a2), (%a5,%d1.w)
        bra.s   4f
2:      move.b  3(%a2), (%a5,%d1.w)
4:      move.w  %d4, -(%sp)
        bsr     .Lnormaliser            | un défaut invalide tombe au minimum
        move.w  (%sp)+, %d4
5:      lea     T_ENTREE(%a2), %a2
        dbra    %d4, 1b
3:      rts

| ----------------------------------------------------------------------------------
| LA VALIDATION DE GAME_DIP À LA RELECTURE (`_relire_dip`, `c0.s`), le 2026-10-27 (DECISIONS
| §23 pt 5, décision de l'utilisateur). Les règles de l'éditeur, sans sa table : un
| réglage que la cartouche déclare inutilisé prend la valeur qu'elle déclare (`.Linutilises`) ;
| un temps hors du BCD de 00:00 à 29:59, un compte hors de 1-99, un nombre de fois hors de 0-100,
| un choix hors de 0 à nombre - 1 prend le défaut de la cartouche s'il est valide, sinon le
| minimum (`.Lnormaliser`). Une valeur valide n'est pas touchée : un bloc que l'éditeur ou
| l'inscription a écrit ressort tel quel. Lu sous REG_CRTFIX, que le passage de slot vient de
| poser. Rien si le pointeur du bloc est refusé, ni s'il est dans la zone banquée : la banque en
| place n'est sûre qu'au premier boot (`c0.s`, LA BANQUE EN PLACE), et valider contre une autre
| banque remettrait aux défauts des valeurs justes. GAME_DIP seul : le bloc de la backup RAM
| garde ses octets jusqu'au prochain START de l'éditeur. Registres rendus.
        .global _dip_valider
_dip_valider:
        movem.l %d0-%d5/%a0-%a3, -(%sp)
        bsr     _dip_bloc               | %a3 ; clobbers %d4, %a2
        move.l  %a3, %d0
        beq     9f
        cmpa.l  #0x100000, %a3
        bcc     9f                      | zone banquée : pas de validation
        lea     0x10(%a3), %a0          | les octets $10-$1F du bloc de la cartouche
        lea     GAME_DIP, %a1
        moveq   #0, %d1                 | les deux temps, octets 0 et 2
1:      move.b  (%a0,%d1.w), %d2
        lsl.w   #8, %d2
        move.b  1(%a0,%d1.w), %d2       | le temps de la cartouche
        cmpi.w  #0xFFFF, %d2
        beq.s   2f                      | inutilisé : $FFFF
        move.w  %d2, %d5
        move.w  (%a1,%d1.w), %d2
        bsr     .Ltemps_valide
        beq.s   3f                      | valide : gardé
        move.w  %d5, %d2
        bsr     .Ltemps_valide
        beq.s   2f                      | le défaut
        moveq   #0, %d2                 | 00:00
2:      move.w  %d2, (%a1,%d1.w)
3:      addq.w  #2, %d1
        cmpi.w  #4, %d1
        bcs.s   1b
4:      move.b  (%a0,%d1.w), %d2        | le compte (octet 4), le nombre de fois (octet 5)
        cmpi.b  #0xFF, %d2
        beq.s   6f                      | inutilisé : $FF
        moveq   #1, %d3
        moveq   #99, %d4
        cmpi.w  #5, %d1
        bne.s   5f
        moveq   #0, %d3
        moveq   #100, %d4
5:      move.b  (%a1,%d1.w), %d0
        cmp.b   %d3, %d0
        bcs.s   51f
        cmp.b   %d4, %d0
        bls.s   7f                      | valide : gardé
51:     cmp.b   %d3, %d2
        bcs.s   52f
        cmp.b   %d4, %d2
        bls.s   6f                      | le défaut
52:     move.b  %d3, %d2                | le minimum
6:      move.b  %d2, (%a1,%d1.w)
7:      addq.w  #1, %d1
        cmpi.w  #6, %d1
        bcs.s   4b
8:      move.b  (%a0,%d1.w), %d2        | les dix choix, octets 6 à 15
        moveq   #0x0F, %d4
        and.b   %d2, %d4                | le nombre de choix
        lsr.b   #4, %d2                 | le défaut
        tst.b   %d4
        beq.s   10f                     | aucun choix : la valeur de l'inscription
        cmp.b   (%a1,%d1.w), %d4
        bhi.s   11f                     | valide : gardé
        cmp.b   %d2, %d4
        bhi.s   10f                     | le défaut
        moveq   #0, %d2
10:     move.b  %d2, (%a1,%d1.w)
11:     addq.w  #1, %d1
        cmpi.w  #16, %d1
        bcs.s   8b
9:      movem.l (%sp)+, %d0-%d5/%a0-%a3
        rts

| ----------------------------------------------------------------------------------
| LES RÉGLAGES INUTILISÉS, remis à ce que la cartouche déclare (DECISIONS §23) : un temps
| $FFFF, un compte $FF, un réglage à choix sans choix (quartet bas nul) prennent dans GAME_DIP la
| valeur que `_slot_inscrit` (`c0.s`) y écrit à l'inscription — le mot ou l'octet tel quel, le
| quartet haut pour un choix. Aucune ligne ne les montre et `.Lnormaliser` ne les voit pas : sans
| cela, une entrée jamais initialisée (une backup RAM laissée par un autre jeu, un autre BIOS)
| gardait ses octets dans le bloc enregistré au START (mesuré, scène `dip-vierge`). Lu dans la
| copie ; rien sans bloc. Clobbers %d0-%d2, %a0.
.Linutilises:
        tst.l   F_SOFTDIP(%a6)
        beq.s   9f
        lea     COPIE + 0x10, %a0
        moveq   #0, %d1                 | les deux temps, octets 0 et 2
1:      cmpi.b  #0xFF, (%a0,%d1.w)
        bne.s   2f
        cmpi.b  #0xFF, 1(%a0,%d1.w)
        bne.s   2f
        move.w  #0xFFFF, (%a5,%d1.w)
2:      addq.w  #2, %d1
        cmpi.w  #4, %d1
        bcs.s   1b
3:      cmpi.b  #0xFF, (%a0,%d1.w)      | les deux comptes, octets 4 et 5
        bne.s   4f
        move.b  #0xFF, (%a5,%d1.w)
4:      addq.w  #1, %d1
        cmpi.w  #6, %d1
        bcs.s   3b
5:      move.b  (%a0,%d1.w), %d2        | les dix choix, octets 6 à 15
        moveq   #0x0F, %d0
        and.b   %d2, %d0
        bne.s   6f
        lsr.b   #4, %d2
        move.b  %d2, (%a5,%d1.w)
6:      addq.w  #1, %d1
        cmpi.w  #16, %d1
        bcs.s   5b
9:      rts

| ----------------------------------------------------------------------------------
| UNE VALEUR RENDUE VALIDE, celle de l'entrée %a2. Clobbers %d0-%d4.
.Lnormaliser:
        moveq   #0, %d1
        move.b  1(%a2), %d1
        tst.b   (%a2)
        bne.s   .Ln_octet
        move.w  (%a5,%d1.w), %d2
        bsr.s   .Ltemps_valide
        beq.s   9f
        move.w  4(%a2), %d2
        bsr.s   .Ltemps_valide
        beq.s   1f
        moveq   #0, %d2                 | 00:00
1:      move.w  %d2, (%a5,%d1.w)
9:      rts
.Ln_octet:
        bsr.s   .Lbornes
        moveq   #0, %d2
        move.b  (%a5,%d1.w), %d2
        cmp.w   %d3, %d2
        bcs.s   1f
        cmp.w   %d4, %d2
        bls.s   9b
1:      moveq   #0, %d2
        move.b  3(%a2), %d2             | le défaut de la cartouche
        cmp.w   %d3, %d2
        bcs.s   2f
        cmp.w   %d4, %d2
        bls.s   3f
2:      move.w  %d3, %d2                | le minimum
3:      move.b  %d2, (%a5,%d1.w)
        rts

| UN TEMPS EN BCD, %d2.w : Z à 1 s'il est valide (00:00 à 29:59). Clobbers %d0.
.Ltemps_valide:
        cmpi.w  #0x2959, %d2
        bhi.s   1f
        move.w  %d2, %d0
        andi.w  #0x000F, %d0
        cmpi.w  #9, %d0
        bhi.s   1f
        move.w  %d2, %d0
        andi.w  #0x00F0, %d0
        cmpi.w  #0x50, %d0
        bhi.s   1f
        move.w  %d2, %d0
        andi.w  #0x0F00, %d0
        cmpi.w  #0x0900, %d0
        bhi.s   1f
        moveq   #0, %d0                 | Z = 1
        rts
1:      moveq   #1, %d0                 | Z = 0
        rts

| LES BORNES d'une entrée de genre 1 à 3 (%a2) : %d3 min, %d4 max. Lu dans « Software
| DIPs » : compte 1 à 99, nombre de fois 0 à 100, choix 0 à nombre - 1.
.Lbornes:
        moveq   #0, %d3
        moveq   #100, %d4
        cmpi.b  #2, (%a2)
        beq.s   1f
        bhi.s   2f
        moveq   #1, %d3
        moveq   #99, %d4
        rts
2:      moveq   #0, %d4
        move.b  2(%a2), %d4
        subq.w  #1, %d4
1:      rts

| BCD → binaire, %d0.w (un octet BCD valide) → %d0.w. Clobbers %d2.
.Lbcd_bin:
        move.w  %d0, %d2
        lsr.w   #4, %d2
        mulu    #10, %d2
        andi.w  #0x0F, %d0
        add.w   %d2, %d0
        rts

| Binaire → BCD, %d3.w (0 à 99) → %d3.b. Clobbers %d2.
.Lbin_bcd:
        andi.l  #0xFFFF, %d3
        divu    #10, %d3
        move.w  %d3, %d2
        lsl.w   #4, %d2
        swap    %d3
        or.w    %d2, %d3
        rts

| ----------------------------------------------------------------------------------
| TOUTES LES LIGNES de la liste. Clobbers %d0-%d4, %a1, %a2.
.Ltout:
        moveq   #0, %d0
1:      move.w  %d0, -(%sp)
        bsr.s   .Lligne
        move.w  (%sp)+, %d0
        addq.w  #1, %d0
        cmp.w   %d6, %d0
        bcs.s   1b
        rts

| LA LIGNE %d0 : curseur, intitulé, valeur, composés dans le tampon puis écrits sous la
| palette 2 si elle est choisie, 1 sinon. Clobbers %d0-%d4, %a1, %a2.
| La liste en 8×16 : la fenêtre de FENETRE entrées d'abord recalée sur la ligne choisie, %d7 ;
| si elle bouge, toute la liste est réécrite ; une ligne hors de la fenêtre ne s'écrit pas.
.Lligne:
        tst.b   F_GRAND(%a6)
        beq.s   .Lligne8
        move.w  F_HAUT(%a6), %d1
        cmp.w   %d1, %d7
        bcc.s   1f
        move.w  %d7, %d1                | au-dessus de la fenêtre
        bra.s   2f
1:      move.w  %d1, %d2
        addi.w  #FENETRE, %d2
        cmp.w   %d2, %d7
        bcs.s   3f
        move.w  %d7, %d1                | en dessous
        subi.w  #FENETRE - 1, %d1
2:      move.w  %d1, F_HAUT(%a6)
        bra     .Ltout
3:      cmp.w   %d1, %d0
        bcs.s   9f                      | hors de la fenêtre
        cmp.w   %d2, %d0
        bcs.s   .Lligne8
9:      rts
.Lligne8:
        lea     F_TAMPON(%a6), %a1
        moveq   #LARGEUR - 1, %d1
1:      move.b  #0x20, (%a1)+
        dbra    %d1, 1b
        lea     F_TAMPON(%a6), %a1
        move.w  #0x1000, %d3
        cmp.w   %d7, %d0
        bne.s   1f
        move.b  #0x3E, (%a1)            | « > »
        move.w  #0x2000, %d3
1:      move.w  %d3, -(%sp)
        move.w  %d0, -(%sp)
        bsr     .Ladresse
        addq.l  #2, %a1
        moveq   #12, %d4                | l'intitulé
        cmpi.b  #4, (%a2)
        bne.s   1f
        moveq   #L_DEFAUT, %d4
1:      cmpi.b  #6, (%a2)
        bne.s   1f
        moveq   #L_TESTS, %d4
1:      cmpi.b  #7, (%a2)
        bne.s   1f
        moveq   #L_JUKEBOX, %d4
1:      cmpi.b  #9, (%a2)
        bne.s   1f
        moveq   #L_CARTE, %d4
1:      cmpi.b  #11, (%a2)
        bne.s   1f
        moveq   #L_BORNE, %d4
1:      movea.l 6(%a2), %a3             | %a3 est libre une fois l'écran posé
        bsr     .Lcopier
        lea     F_TAMPON + COL_VALEUR(%a6), %a1
        move.b  (%a2), %d0
        cmpi.b  #5, %d0
        beq.s   .Lv_region
        cmpi.b  #8, %d0
        beq.s   .Lv_mode
        cmpi.b  #10, %d0
        beq.s   .Lv_scores
        cmpi.b  #12, %d0
        bcc     .Lv_borne
        bsr.s   _dip_valeur
        bra     .Lv_fin

| LE TEXTE DE LA VALEUR d'un réglage de la cartouche (genres 0 à 3 ; les autres : rien), l'entrée
| %a2, à (%a1)+. Clobbers %d0-%d4, %a3.
_dip_valeur:
        moveq   #0, %d1
        move.b  1(%a2), %d1
        moveq   #0, %d2
        move.b  (%a5,%d1.w), %d2
        move.b  (%a2), %d0
        beq     .Lv_temps
        subq.b  #2, %d0
        bcs.s   .Lv_nombre              | genre 1
        beq.s   .Lv_fois                | genre 2
        subq.b  #1, %d0
        bne.s   9f                      | genres 4 et plus : pas de valeur
        | Genre 3 : l'intitulé du choix, à intitulé + 12 × (choix + 1).
        addq.w  #1, %d2
        mulu    #12, %d2
        movea.l 6(%a2), %a3
        adda.l  %d2, %a3
        moveq   #12, %d4
        bra     .Lcopier
9:      rts
.Lv_region:                             | six caractères par région
        moveq   #0, %d2
        move.b  F_REGION(%a6), %d2
        mulu    #6, %d2
        lea     .Ltxt_regions, %a3
        adda.w  %d2, %a3
        moveq   #6, %d4
        bsr     .Lcopier
        bra.s   .Lv_fin
.Lv_mode:                               | trois caractères par mode
        moveq   #0, %d2
        move.b  F_MODE(%a6), %d2
        mulu    #3, %d2
        lea     .Ltxt_modes, %a3
        adda.w  %d2, %a3
        moveq   #3, %d4
        bsr     .Lcopier
        bra.s   .Lv_fin
.Lv_scores:                             | trois caractères : ON, OFF
        moveq   #0, %d2
        move.b  F_SCORES(%a6), %d2
        mulu    #3, %d2
        lea     .Ltxt_on_off, %a3
        adda.w  %d2, %a3
        moveq   #3, %d4
        bsr     .Lcopier
        bra.s   .Lv_fin
.Lv_fois:
        | Lu dans « Software DIPs » : 0 « WITHOUT », 100 « INFINITE ».
        lea     .Ltxt_sans_fois, %a3
        moveq   #7, %d4
        tst.w   %d2
        beq.s   1f
        lea     .Ltxt_infini, %a3
        moveq   #8, %d4
        cmpi.w  #100, %d2
        bne.s   .Lv_nombre
1:      bra     .Lcopier
.Lv_nombre:
        bra     .Ldecimal
.Lv_temps:
        | MM:SS, deux octets BCD validés à l'entrée.
        move.b  (%a5,%d1.w), %d2
        bsr     .Lbcd_ascii
        move.b  #0x3A, (%a1)+           | « : »
        move.b  1(%a5,%d1.w), %d2
        bra     .Lbcd_ascii
.Lv_fin:
        move.w  (%sp)+, %d1             | la ligne
        tst.b   F_GRAND(%a6)
        bne.s   .Lv_fin16
        addi.w  #CASE_LIGNE, %d1
        move.w  (%sp)+, %d3             | la palette
        lea     F_TAMPON(%a6), %a2
        moveq   #LARGEUR, %d4
        bra     .Lecrire
| En 8×16 : deux rangées par entrée, à partir de la rangée 7 ; le haut en $100 + b, le bas en
| $200 + b, ou $300 / $400 + b (`.Lecrire16`).
.Lv_fin16:
        sub.w   F_HAUT(%a6), %d1
        add.w   %d1, %d1
        addi.w  #CASE_LIGNE, %d1
        move.w  (%sp)+, %d3             | la palette
        addi.w  #0x100, %d3
        lea     F_TAMPON(%a6), %a2
        moveq   #LARGEUR, %d4
        bsr     .Lecrire16
        addq.w  #1, %d1
        addi.w  #0x100, %d3
        lea     F_TAMPON(%a6), %a2
        moveq   #LARGEUR, %d4
        bra     .Lecrire16
.Lv_borne:                              | trois caractères, ou MVS ONLY à la ligne MODE AES
        cmpi.b  #16, %d0
        beq.s   .Lv_debug
        cmpi.b  #15, %d0
        beq.s   1f                      | CHEATS/DEBUG : dans les deux modes
        cmpi.b  #1, F_MODE(%a6)
        bne.s   1f
        lea     .Ltxt_mvs_seul, %a3
        moveq   #L_MVS_SEUL, %d4
        bsr     .Lcopier
        bra     .Lv_fin
| FREE PLAY SOUS LE COMMUTATEUR 7 DE LA CARTE (REG_DIPSW bit 6 à 0) : DIP, et verrouillé
| (`.Lch_bval`). Le commutateur suffit à mettre la borne en free play (`io.s`, `_io_libre`) :
| OFF serait faux, ON tairait d'où il vient et laisserait croire qu'on peut l'ôter ici. Relu à
| chaque écriture de la ligne : à l'ouverture du sous-écran et à chaque touche.
1:      cmpi.b  #12, %d0
        bne.s   4f
        btst    #6, DIPSW
        bne.s   4f
        lea     .Ltxt_dip, %a3
        moveq   #3, %d4
        bsr     .Lcopier
        bra     .Lv_fin
4:      moveq   #0, %d2
        move.b  %d0, %d2
        subi.w  #12, %d2                | le bit
        moveq   #0, %d3
        btst    %d2, F_BORNE(%a6)
        beq.s   2f
        moveq   #1, %d3
2:      cmpi.w  #2, %d2                 | DEMO SOUND, CHEATS/DEBUG : bit à 1, OFF (« ON OFF »)
        bcc.s   3f
        eori.w  #1, %d3                 | FREE PLAY, NO CONTINUE : bit à 1, ON
3:      mulu    #3, %d3
        lea     .Ltxt_on_off, %a3
        adda.w  %d3, %a3
        moveq   #3, %d4
        bsr     .Lcopier
        bra     .Lv_fin

| DEBUG DIPS : OFF sous CHEATS/DEBUG OFF (affiché), sinon le masque de `debug.s` en quatre
| chiffres hexadécimaux, DIP 1 puis DIP 2.
.Lv_debug:
        lea     .Ltxt_on_off + 3, %a3
        moveq   #3, %d4
        btst    #3, F_BORNE(%a6)
        bne.s   2f
        move.w  DD_MASQUE, %d2
        moveq   #4 - 1, %d4
1:      rol.w   #4, %d2
        moveq   #0x0F, %d3
        and.w   %d2, %d3
        addi.b  #0x30, %d3
        cmpi.b  #0x39, %d3
        bls.s   3f
        addq.b  #7, %d3
3:      move.b  %d3, (%a1)+
        dbra    %d4, 1b
        bra     .Lv_fin
2:      bsr     .Lcopier
        bra     .Lv_fin

| COPIER %d4 octets de %a3 vers (%a1)+. Un intitulé de la cartouche qui ne tiendrait pas
| entier dans $000000-$0FFFFF ou dans $200000-$2FFFFF n'est pas copié : la case reste en
| blanc. De même un intitulé de la copie en RAM de l'éditeur (`.Lcopier_bloc`) qui ne tiendrait
| pas entier avant COPIE_FIN. Clobbers %d2, %d4, %a3.
_dip_copier:
.Lcopier:
        move.l  %a3, %d2
        cmpi.l  #0xC00000, %d2
        bcc.s   1f                      | une chaîne du BIOS
        cmpi.l  #0x200000, %d2
        bcc.s   4f
        addi.l  #12, %d2
        cmpi.l  #0x100000, %d2
        bls.s   1f                      | dans la P-ROM fixe
        cmpa.l  #COPIE, %a3
        blo.s   2f                      | déborde la P-ROM fixe
        cmp.l   COPIE_FIN, %d2
        bhi.s   2f                      | déborde la copie
        bra.s   1f
4:      addi.l  #12, %d2
        cmpi.l  #0x300000, %d2
        bhi.s   2f                      | déborde la zone banquée, ou au-delà
1:      subq.w  #1, %d4
3:      move.b  (%a3)+, (%a1)+
        dbra    %d4, 3b
        rts
2:      adda.w  %d4, %a1
        rts

| UN NOMBRE, %d2.w de 0 à 999, en décimal sans zéro de tête, à (%a1)+. Clobbers %d2-%d3.
.Ldecimal:
        moveq   #0, %d3                 | 1 dès qu'un chiffre est sorti
        andi.l  #0xFFFF, %d2
        divu    #100, %d2
        tst.w   %d2
        beq.s   1f
        addi.b  #0x30, %d2
        move.b  %d2, (%a1)+
        moveq   #1, %d3
1:      clr.w   %d2
        swap    %d2
        divu    #10, %d2
        tst.w   %d3
        bne.s   2f
        tst.w   %d2
        beq.s   3f
2:      addi.b  #0x30, %d2
        move.b  %d2, (%a1)+
3:      swap    %d2
        addi.b  #0x30, %d2
        move.b  %d2, (%a1)+
        rts

| UN OCTET BCD, %d2.b, en deux chiffres à (%a1)+. Clobbers %d2, %d3.
.Lbcd_ascii:
        move.b  %d2, %d3
        lsr.b   #4, %d3
        addi.b  #0x30, %d3
        move.b  %d3, (%a1)+
        andi.b  #0x0F, %d2
        addi.b  #0x30, %d2
        move.b  %d2, (%a1)+
        rts

| ----------------------------------------------------------------------------------
| ÉCRIRE %d4 caractères de %a2 à partir de la case %d1, REG_VRAMMOD à 32 : une ligne.
| %d3 : palette << 12 + décalage de tuile ($000 en 8×8, $100 / $200 en 8×16). Hors de
| $20-$7E, une espace. Rythme (« VRAM ») : entre deux données, la boucle tient plus de
| 12 cycles ; après la dernière, `dbra` non pris (14) et `rts` (16) avant toute adresse.
| Clobbers %d2, %d4, %a2.
.Lecrire:
        move.w  %d1, VRAMADDR
        subq.w  #1, %d4
1:      moveq   #0, %d2
        move.b  (%a2)+, %d2
        cmpi.b  #0x20, %d2
        bcs.s   2f
        cmpi.b  #0x7E, %d2
        bls.s   3f
2:      moveq   #0x20, %d2
3:      add.w   %d3, %d2
        move.w  %d2, (%a0)
        dbra    %d4, 1b
        rts

| ÉCRIRE EN 8×16, LA LISTE EN 8×16 SEULE (voir l'en-tête) : comme `.Lecrire`, %d3 portant $100 (le
| haut) ou $200 (le bas), sans filtre. Un octet dont le glyphe est le même dans les deux banques
| ($20-$5E, $61-$7B) reste en $100 / $200 + b ; tout autre en $300 / $400 + b. Rythme (« VRAM ») :
| comme `.Lecrire`, plus de 12 cycles entre deux données ; `dbra` non pris (14) et `rts` (16) avant
| toute adresse. Clobbers %d2, %d4, %a2 ; %d1 et %d3 rendus.
.Lecrire16:
        move.w  %d1, VRAMADDR
        subq.w  #1, %d4
1:      moveq   #0, %d2
        move.b  (%a2)+, %d2
        cmpi.b  #0x20, %d2
        bcs.s   2f
        cmpi.b  #0x7C, %d2
        bcc.s   2f
        cmpi.b  #0x5F, %d2
        bcs.s   3f
        cmpi.b  #0x61, %d2
        bcc.s   3f
2:      addi.w  #0x200, %d2             | $300 / $400 + b
3:      add.w   %d3, %d2
        move.w  %d2, (%a0)
        dbra    %d4, 1b
        rts

| L'AVERTISSEMENT DU COMMUTATEUR 1 : l'écran effacé, deux lignes, puis AVERT_TRAMES trames ou le
| commutateur rebasculé à OFF, au premier des deux. Clobbers %d0-%d5, %a0, %a2.
        .equ    AVERT_TRAMES, 180       | ~3 s, choix
.Lavertir:
        bsr     .Lsync
        jsr     _fix_clear              | %a0 sur REG_VRAMRW
        move.w  #32, VRAMMOD
        move.w  #0x7000 + 11 * 32 + 13, %d1
        lea     .Ltxt_avert1, %a2
        moveq   #L_AVERT1, %d4
        move.w  #0x2000, %d3            | palette 2, la couleur de la ligne choisie
        bsr     .Lecrire
        move.w  #0x7000 + 6 * 32 + 15, %d1
        lea     .Ltxt_avert2, %a2
        moveq   #L_AVERT2, %d4
        move.w  #0x1000, %d3
        bsr     .Lecrire
        move.w  #AVERT_TRAMES - 1, %d5
1:      bsr     .Lsync
        btst    #0, DIPSW
        dbne    %d5, 1b
        rts

| LE PASSAGE DE LA LIGNE $1F0, comme `ecran.s` (mesuré, `2026-10-17-diagnostic-b2b-minasan.tsv`) :
| on attend d'en sortir puis d'y entrer, coup de pied au watchdog à chaque tour. Clobbers %d0.
| BORNÉE à SYNC_TOURS tours par attente, ≈ 2 trames, ligne vue ou non : le compte est dans
| `ecran.s`, dont c'est la copie identique.
        .equ    SYNC_TOURS, 5800
.Lsync:
        move.l  %d1, -(%sp)
        move.w  #SYNC_TOURS - 1, %d1
1:      move.b  %d0, WATCHDOG
        move.w  LSPCMODE, %d0
        lsr.w   #7, %d0
        cmpi.w  #0x1F0, %d0
        dbne    %d1, 1b
        move.w  #SYNC_TOURS - 1, %d1
2:      move.b  %d0, WATCHDOG
        move.w  LSPCMODE, %d0
        lsr.w   #7, %d0
        cmpi.w  #0x1F0, %d0
        dbeq    %d1, 2b
        move.l  (%sp)+, %d1
        rts

| UNE PALETTE, comme `ecran.s` mais d'autres registres (%d5 et %d6 tiennent l'état) :
| %d1 son numéro, %d2 la couleur de l'entrée 1, les entrées 2 à 15 à zéro. Clobbers %d0,
| %d1, %a2.
.Lpalette:
        lea     PALETTES + 2, %a2
        lsl.w   #5, %d1
        adda.w  %d1, %a2
        move.w  %d2, (%a2)+
        moveq   #14-1, %d0
1:      clr.w   (%a2)+
        dbra    %d0, 1b
        rts

| ----------------------------------------------------------------------------------
| LES DONNÉES.
        .balign 2
.Ltxt_titre:
        .ascii  "SOFT DIP SETTINGS"
        .equ    L_TITRE, . - .Ltxt_titre
.Ltxt_sans:
        .ascii  "NO SOFT DIP DATA"
.Ltxt_defaut:
        .ascii  "RESET TO DEFAULTS"
        .equ    L_DEFAUT, . - .Ltxt_defaut
.Ltxt_tests:
        .ascii  "HARDWARE TESTS"
        .equ    L_TESTS, . - .Ltxt_tests
.Ltxt_jukebox:
        .ascii  "JUKEBOX"
        .equ    L_JUKEBOX, . - .Ltxt_jukebox
.Ltxt_carte:
        .ascii  "MEMORY CARD"
        .equ    L_CARTE, . - .Ltxt_carte
.Ltxt_aide1:
        .ascii  "UP/DOWN:SELECT  LEFT/RIGHT/A:CHANGE"
        .equ    L_AIDE1, . - .Ltxt_aide1
.Ltxt_aide2:
        .ascii  "START:SAVE AND EXIT"
        .equ    L_AIDE2, . - .Ltxt_aide2
.Ltxt_aide2_b:
        .ascii  "START:BACK"
        .equ    L_AIDE2_B, . - .Ltxt_aide2_b
.Ltxt_borne:
        .ascii  "CABINET SETTINGS"
        .equ    L_BORNE, . - .Ltxt_borne
.Ltxt_libre:                            | les cinq intitulés du sous-écran, 12 caractères
        .ascii  "FREE PLAY   "
        .ascii  "NO CONTINUE "
        .ascii  "DEMO SOUND  "
        .ascii  "CHEATS/DEBUG"
        .ascii  "DEBUG DIPS  "
.Ltxt_mvs_seul:
        .ascii  "MVS ONLY"
        .equ    L_MVS_SEUL, . - .Ltxt_mvs_seul
.Ltxt_region:
        .ascii  "REGION      "          | 12 caractères, comme un intitulé de cartouche
.Ltxt_regions:
        .ascii  "JAPAN USA   EUROPE"    | 0, 1, 2 (« BIOS RAM locations »)
.Ltxt_mode:
        .ascii  "MODE        "          | 12 caractères, comme REGION
.Ltxt_modes:
        .ascii  "MVSAES"                | 0, 1 (décision D7)
.Ltxt_scores:
        .ascii  "SCORE RESET "          | 12 caractères, comme REGION
.Ltxt_on_off:
        .ascii  "ON OFF"                | 0, 1
.Ltxt_dip:
        .ascii  "DIP"                   | FREE PLAY par le commutateur de la carte
.Ltxt_avert1:
        .ascii  "DIP SWITCH 1 IS ON"
        .equ    L_AVERT1, . - .Ltxt_avert1
.Ltxt_avert2:
        .ascii  "SET IT OFF FOR A NORMAL BOOT"
        .equ    L_AVERT2, . - .Ltxt_avert2
.Ltxt_sans_fois:
        .ascii  "WITHOUT"
.Ltxt_infini:
        .ascii  "INFINITE"
        .balign 2
