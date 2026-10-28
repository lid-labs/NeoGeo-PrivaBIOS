| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| P1 DANS LES ÉCRANS DU BIOS — une manette, ou le panneau de mahjong traduit en manette.
|
| Le 2026-10-28 (DECISIONS §30). Remise : « Couche 3 → les menus au panneau de mahjong,
| le 2026-10-28 » (`docs/RELECTURE-CONTRATS.md`). AUCUN ORACLE : le code des BIOS de référence
| n'est pas lu ; leur comportement vient du relevé en boîte noire
| `measured/2026-10-28-panneau-menus-reference.tsv`.
|
| TROIS SORTES D'AFFIRMATIONS, et chacune le dit :
|   « mesuré »  : ce relevé, nommé ;
|   « lu dans » : une page du NeoGeo Development Wiki, nommée ;
|   « SUPPOSÉ » : ni l'un ni l'autre, et c'est dit.
|
| CE QUE CES ROUTINES REMPLACENT : la lecture de REG_P1CNT ($300000) que chaque écran faisait
| lui-même (`ecran.s`, `dip.s`, `tests.s`, `jukebox.s`, `gestion-carte.s`, `debug.s`, `menu.s`
| et ses sous-écrans par `_mn_entrees`). Ces écrans lisaient le registre tel quel, sous la sortie
| REG_POUTPUT ($380001, « Joypad ports outputs », « Memory mapped registers ») qu'un autre avait
| laissée : le panneau, qui ne répond qu'à la rangée choisie, n'y menait rien (DECISIONS §24 pt 4).
| Restent lues telles quelles, et c'est voulu : les gardes de l'adaptateur BlueRetro (`dip.s`,
| `menu.s`, `cmpi.b #0x10`), qui jugent un geste fait sur une manette avant toute ouverture ; les
| pages d'INPUT TEST (`tests.s`), qui affichent le registre brut ; et P2, qui reste une manette.
|
| LE COMMUTATEUR 3, « Mahjong Panel » (REG_DIPSW $300001 bit 2, actif bas ; neogeo.cpp, SW:3), LU
| À L'OUVERTURE ET PAS APRÈS (`_panneau_verrou`). MESURÉ (relevé, section « commutateur3 ») : le BIOS
| SNK japonais le prend à l'ouverture de son menu de test, UniBIOS 4.0 au boot ; basculé menu
| ouvert, la traduction reste chez les deux. On reprend le comportement du BIOS SNK japonais (DECISIONS §30 pt 3).
| OÙ LE VERROU SE POSE : à l'entrée de chaque écran qu'on OUVRE depuis le jeu ou le boot, jamais
| à celle d'un sous-écran — l'écran de boot (`ecran.s`), l'éditeur du bouton TEST (`dip.s`, d'où
| s'ouvrent les autotests, le jukebox, la carte mémoire, la borne et les debug dips), les autotests
| d'une MV-1 sans cartouche (`c0.s`, `_sans_cartouche`), et le menu en jeu (`menu.s`, d'où
| s'ouvrent GAME SETTINGS, MEMORY EDITOR et AUTOFIRE). Un sous-écran hérite donc de la valeur de
| l'écran qui l'ouvre, et y revenir ne la relit pas. Écarté : le relire dans `_panneau_p1`, à
| chaque trame, qui changerait la traduction d'un menu ouvert ; le prendre au boot seulement,
| comme UniBIOS, que la décision n'a pas retenu. Écarté aussi : BIOS_P1STATUS ($10FD94), que
| `_commutateurs` (`c0.s`) pose à chaque remise de la main au jeu — lu à la remise, pas à
| l'ouverture, et pas encore posé au premier écran du boot.
|
| LA TRADUCTION, COMMUTATEUR À ON. MESURÉ (relevé, sections « menu » et « calendrier ») : dans les
| menus des deux références, A, B, C, D du panneau font les boutons A, B, C, D ; E monte, F
| descend, G va à gauche, H à droite ; les autres touches, I à N et PON à REACH, ne font rien ;
| START reste START (REG_STATUS_B, que cette routine ne lit pas). MESURÉ (même relevé, « lecture
| brute ») : sous MAME, REG_POUTPUT ← $09 rend dans REG_P1CNT la rangée A-G aux bits 0-6, actifs
| bas, A au bit 0 ; ← $12 la rangée H-N, H au bit 0. L'octet rendu est au format de REG_P1CNT
| (« Memory mapped registers » : bits 0 haut, 1 bas, 2 gauche, 3 droite, 4-7 A, B, C, D, actifs
| bas) : sous $09, les bits 0-3 vont aux bits 4-7 et les bits 4-6 aux bits 0-2 — une rotation
| de quatre —, puis le bit 3 est pris au bit 0 de la rangée H-N. SUPPOSÉ : le bit 7 de la
| rangée A-G, qu'aucune touche n'allume au relevé, ne sert pas ; il est remplacé.
| Une MANETTE sur ce commutateur ne lit pas REG_POUTPUT (neogeo.cpp, io_control_w ; mahjong.cpp,
| read_ctrl) : elle passe la même traduction, haut fait A et droite, A fait haut, B bas, C gauche,
| D rien. C'est ce que font les références sur ce commutateur (SUPPOSÉ pour une manette : le
| relevé n'a joué que le panneau).
|
| COMMUTATEUR À OFF : REG_POUTPUT ← $1B puis REG_P1CNT tel quel, comme `_io_lire` (`io.s`,
| DECISIONS §21 pt 4). MESURÉ (relevé, sections « menu » et « lecture brute ») : sous $1B, les
| rangées A-G et H-N confondues ; dans les menus des deux références, A/H haut, B/I bas, C/J
| gauche, D/K droite, E/L bouton A, F/M bouton B, G/N bouton C, aucune touche pour le bouton D.
| Sur une manette, cette sortie ne change rien.
|
| LA SORTIE LAISSÉE dans REG_POUTPUT ($12 à ON, $1B à OFF) en quittant un écran : le jeu pose la
| sienne à chaque SYSTEM_IO avant de lire (`_io_lire`, `_io_mahjong`), comme après la page du
| panneau d'INPUT TEST (DECISIONS §24 pt 2). SUPPOSÉ : qu'aucun jeu ne lise REG_P1CNT lui-même
| avant son premier SYSTEM_IO sans poser de sortie.
|
| LE DÉLAI entre l'écriture de la sortie et la lecture : aucun, comme `_io_mahjong` (`io.s`), que
| le relevé du 2026-10-27 a validé sous MAME. SUPPOSÉ sur le matériel.
| ==================================================================================

        .section .haut, "ax"
        .global _panneau_verrou
        .global _panneau_p1

        .equ    P1CNT,    0x300000
        .equ    DIPSW,    0x300001      | en lecture : les commutateurs de la carte, actifs bas
        .equ    POUTPUT,  0x380001
        | Le verrou : $FF commutateur 3 à ON, $00 à OFF. Dans la zone mesurée libre de `menu.s`
        | ($10F4B4-$10FBFF : aucune écriture de jeu), entre les debug dips ($10FB22-$10FB27,
        | `debug.s`) et l'autofire ($10FB40-$10FB51, `autofire.s`) ; au-dessus de la copie du
        | bloc soft-DIP de l'éditeur ($10F464-$10FAFF, `dip.s`) et dans ce que le test de la RAM de
        | travail garde ($10F000-$10FFFF, `tests.s`). Remis à zéro par le vidage du boot (`c0.s`) :
        | OFF jusqu'au premier verrou, l'écran de boot.
        .equ    PANNEAU,  0x10FB28

| ----------------------------------------------------------------------------------
| LE VERROU : le commutateur 3 lu une fois, à l'ouverture d'un écran (voir l'en-tête). Ne détruit
| aucun registre, seulement les codes de condition.
_panneau_verrou:
        btst    #2, DIPSW               | bit 2 à 0 : ON
        seq     PANNEAU
        rts

| ----------------------------------------------------------------------------------
| P1. Sortie : %d0.b, l'octet de P1 au format de REG_P1CNT, actif bas — une manette, ou le panneau
| traduit selon le verrou (voir l'en-tête). Écrit REG_POUTPUT. Détruit %d0 seul.
_panneau_p1:
        tst.b   PANNEAU
        bne.s   1f
        move.b  #0x1B, POUTPUT          | OFF : les rangées A-G et H-N confondues
        move.b  P1CNT, %d0
        rts
1:      move.b  #0x09, POUTPUT          | ON : la rangée A-G
        move.b  P1CNT, %d0
        rol.b   #4, %d0                 | A-D aux bits 4-7 (boutons), E, F, G aux bits 0-2
        bset    #3, %d0                 | droite relâchée…
        move.b  #0x12, POUTPUT          | la rangée H-N
        btst    #0, P1CNT               | H, bit 0
        bne.s   2f
        bclr    #3, %d0                 | …sauf H tenue
2:      rts
