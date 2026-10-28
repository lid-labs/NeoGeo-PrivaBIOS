| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| LE CRC32 DE LA CARTOUCHE — un écran du sous-menu HARDWARE TESTS (`tests.s`), ligne
| CARTRIDGE CRC, juste avant EXIT. Il calcule le CRC32 de la P-ROM du slot servi, telle que
| le 68000 la voit, pour qu'on le compare à celui que MAME publie pour le même romset
| (`hash/neogeo.xml`, `-listxml`) ou qu'on calcule depuis le zip.
|
| APPEL : `jsr _crc_cartouche` depuis `tests.s`, dans l'état des autotests : IRQ masquées,
| REG_BRDFIX (police de la carte), REG_SWPROM posé par le passage au slot (`c0.s` ; rien ne le
| repose ici : sans cartouche, le boot laisse REG_SWPBIOS, et seul l'en-tête $100 est lu, puis
| NO CARTRIDGE ; le Z80, qui n'y a pas de pilote garé, voit alors une M1 absente), le
| pilote son du jeu garé dans sa boucle en RAM (`dip.s`), palettes 1-6 de `tests.s` dans la
| banque 0 (le trait à l'entrée 1, noir ailleurs). Tous les registres rendus. Au retour :
| REG_BRDFIX, la banque de la P-ROM remise à 0 si on l'a changée, le plan fixe à redessiner
| (`tests.s` le fait).
|
| AUCUN ORACLE : ni le BIOS de référence ni un BIOS tiers ne sont lus, ni le code d'un jeu.
| « mesuré » : un relevé nommé ; « lu dans » : une page du NeoGeo Development Wiki ou le
| source de MAME 0.286 ; « SUPPOSÉ » : ni l'un ni l'autre.
|
| LA CARTOUCHE NE RÉPOND QUE SOUS REG_CRTFIX (DECISIONS §13) : tout le calcul se fait sous
| lui, et l'écran avec. REG_CRTFIX bascule aussi la M1 du Z80 (lu dans « Memory mapped
| registers ») ; le pilote est garé en RAM (`dip.s`) et on n'écrit pas REG_SOUND : il ne lit
| pas sa ROM pendant ce temps. Le texte est donc dans la POLICE DE LA CARTOUCHE, en 8×8 aux
| places du SFIX, comme `jukebox.s` : 0-9, A-Z, espace, « : - / . » seulement
| (`measured/2026-10-21-police-cartouche.tsv`, 20 jeux identiques sur 22 ; kof2003 sans police,
| l'écran y est noir). Écartés : basculer autour de chaque lecture, la S ROM changerait sous le
| plan fixe en pleine image, des milliers de fois.
|
| CE QUI EST SOMMÉ, en deux CRC32 (polynôme réfléchi $EDB88320, départ et fin complémentés : le
| CRC de zip et de MAME) :
|   FIXED  $000000-$0FFFFF, la P-ROM fixe, vecteurs compris (REG_SWPROM). Sa taille est réduite
|          de moitié tant que la moitié haute est le miroir exact de la basse, jusqu'à 64 Kio :
|          SUPPOSÉ, une puce de 512 Kio sur une carte à 1 Mio d'adresses y apparaît deux fois,
|          sa ligne A19 n'étant pas câblée. MAME, lui, met des zéros au-delà du fichier (mesuré
|          sur aof, `measured/2026-10-25-crc-cartouche.tsv`) : sous MAME, une P-ROM de 512 Kio
|          donne donc un CRC de 1 Mio, qui n'est pas celui du fichier.
|   BANKS  $200000-$2FFFFF, banque après banque, à la suite dans un seul CRC. Lu dans le
|          source de MAME (`neogeo.cpp`, `write_banksel`) : le mot écrit en $2FFFF0 choisit
|          la banque (bits 0-2), la banque n étant le Mio n + 1 de la P-ROM, et une banque
|          au-delà de la ROM retombe sur la banque 0 ; une cartouche d'1 Mio au plus garde
|          sa P-ROM fixe dans la fenêtre. D'où, sans lire le code du jeu :
|            - la fenêtre égale à la P-ROM fixe, mot pour mot : PAS DE BANQUE, et rien n'est
|              écrit en $2FFFF0 (sous MAME, écrire 0 y pointerait hors de la ROM, mesuré) ;
|            - sinon, banques 0, 1, 2… jusqu'à la première dont le CRC égale celui d'une
|              banque d'avant (un miroir, ou la retombée sur la 0), huit au plus. Elle n'est
|              pas comptée, et son octet n'entre pas dans le CRC des banques.
|          Puis la banque 0, celle du reset sous MAME (`init_cpu`). SUPPOSÉ sur le matériel.
| L'ORDRE DES OCTETS est celui des fichiers de MAME : chaque mot octet bas d'abord
| (`ROM_LOAD16_WORD_SWAP`). Une P-ROM d'1 Mio suivie d'une seule puce de banques donne alors les
| deux CRC de `hash/neogeo.xml` (mslug2 : 2A53C5DA et 38883F44, mesuré). Une puce rangée
| autrement (mslug, moitiés croisées) ou déchiffrée au chargement (kof98) ne le peut pas : le
| CRC est celui de ce que le 68000 lit, le banc le recalcule depuis le zip
| (`bench/crc-cartouche.py`).
| Les cartouches protégées qui banquent ailleurs qu'en $2FFFF0 (lu dans `neogeo.cpp` : SMA,
| PVC, à $2FFFC0, $2FFFE4…) ne sont pas reconnues : leurs banques sont celles que $2FFFF0
| donne sous MAME, rien de plus.
|
| LA DURÉE : ~170 cycles par mot (compté ci-dessous), ~7,5 s par Mio à 12 MHz, plus une banque
| relue pour voir qu'elle est un miroir. Le watchdog est servi tous les 4 Kio ; le compte de
| Kio lus s'affiche tous les 64 Kio ; START arrête le calcul et rend le menu.
|
| L'AFFICHAGE : plan fixe seul, $7000 + 32 × colonne + ligne, REG_VRAMMOD à 32. Effacement :
| la tuile $020 sous la palette 7, mise à zéro (comme `jukebox.s` : quel que soit son dessin
| dans la S ROM, elle est noire). Palettes de `tests.s` : 1 le texte, 3 le titre, 4 l'aide,
| 5 les CRC.
| ==================================================================================

        .section .haut, "ax"
        .global _crc_cartouche

        .equ    VRAMADDR, 0x3C0000
        .equ    VRAMRW,   0x3C0002
        .equ    VRAMMOD,  0x3C0004
        .equ    LSPCMODE, 0x3C0006
        .equ    WATCHDOG, 0x300001
        .equ    STATUS_B, 0x380000
        .equ    BRDFIX,   0x3A000B
        .equ    CRTFIX,   0x3A001B
        .equ    PALETTES, 0x400000
        .equ    BANQUE,   0x2FFFF0      | le mot de banque (`neogeo.cpp`, `write_banksel`)
        .equ    FENETRE,  0x200000

        .equ    PAL_VIDE, 7
        .equ    MIO,      0x100000
        .equ    BLOC,     0x1000        | 4 Kio entre deux coups de pied au watchdog
        .equ    N_BANQUES, 8

        | Les lignes, colonne 3.
        .equ    CASE_TITRE,  0x7000 + 3 * 32 + 3
        .equ    CASE_SLOT,   0x7000 + 3 * 32 + 6
        .equ    CASE_FIXE,   0x7000 + 3 * 32 + 9
        .equ    CASE_BANQ,   0x7000 + 3 * 32 + 12
        .equ    CASE_ETAT,   0x7000 + 3 * 32 + 16
        .equ    CASE_AIDE1,  0x7000 + 3 * 32 + 25
        .equ    CASE_AIDE2,  0x7000 + 3 * 32 + 26
        .equ    COL_CRC,     22         | le CRC en colonne 22 sur les lignes FIXED et BANKS

        | Le cadre : la signature de chaque banque, l'état.
        .equ    F_CRCB,   -(N_BANQUES * 4)
        .equ    F_NB,     F_CRCB - 2    | .w le nombre de banques
        .equ    F_ECRIT,  F_NB - 2      | .w 1 si $2FFFF0 a été écrit
        .equ    F_ARRET,  F_ECRIT - 2   | .w 1 si START a arrêté le calcul
        .equ    F_KIO,    F_ARRET - 2   | .w Kio lus dans la zone en cours
        .equ    F_ZONE,   F_KIO - 2     | .w la zone en cours : 0 la fixe, 1 + n la banque n
        .equ    F_TOUCHE, F_ZONE - 2    | .w START déjà tenu
        .equ    F_TOTAL,  F_TOUCHE

| ----------------------------------------------------------------------------------
_crc_cartouche:
        movem.l %d0-%d7/%a0-%a6, -(%sp)
        link    %a6, #F_TOTAL
        clr.w   F_ECRIT(%a6)
        clr.w   F_ARRET(%a6)
        clr.w   F_NB(%a6)
        move.w  #1, F_TOUCHE(%a6)       | le A qui ouvre ne compte pas ; START non plus
        bsr     .Lsync
        move.b  %d0, CRTFIX             | la cartouche répond, sa S ROM au plan fixe
        lea     PALETTES + PAL_VIDE * 32, %a0
        moveq   #16 - 1, %d0
1:      clr.w   (%a0)+
        dbra    %d0, 1b
        bsr     .Leffacer
        move.w  #32, VRAMMOD
        move.w  #CASE_TITRE, %d1
        move.w  #0x3000, %d3
        lea     .Ltxt_titre, %a2
        bsr     .Lchaine_en
        move.w  #CASE_AIDE1, %d1
        move.w  #0x4000, %d3
        lea     .Ltxt_ordre, %a2
        bsr     .Lchaine_en

        | UNE CARTOUCHE ? « NEO-GEO » en $100 (« 68k program header »), comme le boot (`c0.s`).
        cmpi.l  #0x4E454F2D, 0x100      | « NEO- »
        bne.s   .Lsans
        cmpi.w  #0x4745, 0x104          | « GE »
        bne.s   .Lsans
        cmpi.b  #0x4F, 0x106            | « O »
        beq.s   .Lavec
.Lsans:
        move.w  #CASE_ETAT, %d1
        move.w  #0x1000, %d3
        lea     .Ltxt_sans, %a2
        bsr     .Lchaine_en
        bra     .Lfini

.Lavec:
        | SLOT n (1 à 6 : $D00108 + 1, « Backup RAM ») et le NGH ($108, BCD).
        move.w  #CASE_SLOT, %d1
        move.w  #0x1000, %d3
        lea     .Ltxt_slot, %a2
        bsr     .Lchaine_en
        moveq   #0, %d2
        move.b  0xD00108, %d2
        addi.w  #0x31, %d2
        bsr     .Lcar
        lea     .Ltxt_ngh, %a2
        bsr     .Lchaine
        move.w  0x108, %d4
        swap    %d4
        moveq   #4, %d0
        bsr     .Lhex

        | LA P-ROM FIXE : sa taille, par les miroirs ; puis son CRC.
        move.l  #MIO, %d6
1:      cmpi.l  #0x10000, %d6           | 64 Kio au moins
        bls.s   2f
        move.l  %d6, %d0
        lsr.l   #1, %d0
        suba.l  %a0, %a0                | la moitié basse
        movea.l %d0, %a1                | la haute
        bsr     .Legal
        bne.s   2f
        lsr.l   #1, %d6
        bra.s   1b
2:      move.w  #CASE_FIXE, %d1
        move.w  #0x1000, %d3
        lea     .Ltxt_fixe, %a2
        bsr     .Lchaine_en
        move.l  %d6, %d0
        bsr     .Lkio
        clr.w   F_ZONE(%a6)
        moveq   #-1, %d7                | %d7 : le CRC, complémenté au départ
        suba.l  %a0, %a0
        move.l  %d6, %d5
        bsr     .Lsommer
        tst.w   F_ARRET(%a6)
        bne     .Lfini
        not.l   %d7
        move.w  #CASE_FIXE + COL_CRC * 32, %d1
        bsr     .Lcrc_ecrire

        | LES BANQUES. La fenêtre égale à la P-ROM fixe : aucune.
        lea     FENETRE, %a1
        suba.l  %a0, %a0
        move.l  #MIO, %d0
        bsr     .Legal
        bne.s   .Lbanques
        move.w  #CASE_BANQ, %d1
        move.w  #0x1000, %d3
        lea     .Ltxt_sans_banque, %a2
        bsr     .Lchaine_en
        bra     .Ltermine

.Lbanques:
        move.w  #1, F_ECRIT(%a6)
        moveq   #-1, %d7                | le CRC de toutes les banques, à la suite
        moveq   #0, %d6                 | %d6 : la banque
.Lb_une:
        move.w  %d6, BANQUE
        | SA SIGNATURE : le CRC de seize tranches de 4 Kio, une tous les 64 Kio (~0,5 s). Égale à
        | celle d'une banque d'avant : un miroir, fin, sans elle. SUPPOSÉ : deux banques
        | différentes ne s'accordent pas sur ces 64 Kio répartis.
        move.l  %d7, -(%sp)
        moveq   #-1, %d7
        lea     .Ltable, %a1
        lea     FENETRE, %a3
        moveq   #16 - 1, %d5
1:      movea.l %a3, %a0
        move.w  #BLOC / 2 - 1, %d4
        bsr     .Lcrc_mots
        move.b  %d0, WATCHDOG
        adda.l  #0x10000, %a3
        dbra    %d5, 1b
        lea     F_CRCB(%a6), %a3
        move.w  %d6, %d0
        bra.s   3f
2:      cmp.l   (%a3)+, %d7
        beq.s   .Lb_miroir
3:      dbra    %d0, 2b
        move.l  %d7, (%a3)              | %a3 : l'entrée de cette banque
        move.l  (%sp)+, %d7
        | SON CRC, à la suite des autres.
        move.w  %d6, %d0
        addq.w  #1, %d0
        move.w  %d0, F_ZONE(%a6)
        lea     FENETRE, %a0
        move.l  #MIO, %d5
        bsr     .Lsommer
        tst.w   F_ARRET(%a6)
        bne     .Lfini
        addq.w  #1, %d6
        move.w  %d6, F_NB(%a6)
        cmpi.w  #N_BANQUES, %d6
        bcs     .Lb_une
        bra.s   .Lb_fin
.Lb_miroir:
        move.l  (%sp)+, %d7
.Lb_fin:
        not.l   %d7
        move.w  #CASE_BANQ, %d1
        move.w  #0x1000, %d3
        lea     .Ltxt_banques, %a2
        bsr     .Lchaine_en
        moveq   #0x30, %d2
        add.w   F_NB(%a6), %d2
        bsr     .Lcar
        lea     .Ltxt_x1024, %a2
        bsr     .Lchaine
        move.w  #CASE_BANQ + COL_CRC * 32, %d1
        bsr     .Lcrc_ecrire

.Ltermine:
        move.w  #CASE_ETAT, %d1
        move.w  #0x5000, %d3
        lea     .Ltxt_fini, %a2
        bsr     .Lchaine_en

| LA FIN : l'aide, puis START rend le menu (un START tenu depuis le calcul ne compte pas).
.Lfini:
        tst.w   F_ECRIT(%a6)
        beq.s   1f
        move.w  #0, BANQUE              | la banque du reset (`init_cpu`)
1:      tst.w   F_ARRET(%a6)
        bne.s   .Lsortie
        move.w  #CASE_AIDE2, %d1
        move.w  #0x4000, %d3
        lea     .Ltxt_retour, %a2
        bsr     .Lchaine_en
1:      bsr     .Lsync
        bsr     .Lstart
        beq.s   1b
.Lsortie:
        bsr     .Lsync
        move.b  %d0, BRDFIX
        unlk    %a6
        movem.l (%sp)+, %d0-%d7/%a0-%a6
        rts

| ----------------------------------------------------------------------------------
| SOMMER %d5 octets depuis %a0, CRC courant %d7, par blocs de BLOC octets : un coup de pied
| au watchdog par bloc ; tous les 16 blocs, le compte de Kio à l'écran et START regardé.
| Clobbers %d0-%d5, %a0-%a2. F_ARRET à 1 si START.
.Lsommer:
        clr.w   F_KIO(%a6)
        bsr     .Lprogres
        lea     .Ltable, %a1
1:      move.w  #BLOC / 2 - 1, %d4
        bsr.s   .Lcrc_mots
        move.b  %d0, WATCHDOG
        addq.w  #4, F_KIO(%a6)
        move.w  F_KIO(%a6), %d0
        andi.w  #63, %d0
        bne.s   2f
        movem.l %d5/%a0/%a1, -(%sp)
        bsr     .Lprogres
        bsr     .Lstart
        movem.l (%sp)+, %d5/%a0/%a1
        beq.s   2f
        move.w  #1, F_ARRET(%a6)
        rts
2:      subi.l  #BLOC, %d5
        bhi.s   1b
        rts

| LE CRC DE %d4 + 1 MOTS depuis %a0, table %a1, CRC courant %d7 (réfléchi, complémenté par
| l'appelant). Chaque mot octet bas d'abord, l'ordre des fichiers de MAME. Compté (temps du
| 68000, sans état d'attente SUPPOSÉ) : 8 + 2 × (4 + 4 + 4 + 24 + 8 + 18 + 8) + 22 + 10, ≈ 172
| cycles par mot. Clobbers %d1, %d2, %d4, %a0.
.Lcrc_mots:
1:      move.w  (%a0)+, %d1
        moveq   #0, %d2
        move.b  %d1, %d2                | l'octet bas, le premier du fichier
        eor.b   %d7, %d2
        lsr.l   #8, %d7
        add.w   %d2, %d2
        add.w   %d2, %d2
        move.l  (%a1,%d2.w), %d2
        eor.l   %d2, %d7
        lsr.w   #8, %d1                 | l'octet haut ; le haut du mot à zéro
        eor.b   %d7, %d1
        lsr.l   #8, %d7
        add.w   %d1, %d1
        add.w   %d1, %d1
        move.l  (%a1,%d1.w), %d1
        eor.l   %d1, %d7
        dbra    %d4, 1b
        rts

| %d0 OCTETS ÉGAUX en %a0 et %a1 ? Z si oui. Par blocs de BLOC octets, un coup de pied au
| watchdog par bloc (~22 cycles par mot). Clobbers %d0, %d1, %d2, %a0, %a1.
.Legal:
1:      move.w  #BLOC / 2 - 1, %d1
2:      cmpm.w  (%a0)+, (%a1)+
        dbne    %d1, 2b
        bne.s   9f
        move.b  %d1, WATCHDOG
        subi.l  #BLOC, %d0
        bhi.s   1b
        moveq   #0, %d0                 | Z
9:      rts

| LA LIGNE D'ÉTAT : « READING FIXED 0512K » ou « READING BANK 2 0512K ». Clobbers %d0-%d4, %a2.
.Lprogres:
        move.w  #CASE_ETAT, %d1
        move.w  #0x1000, %d3
        lea     .Ltxt_lit, %a2
        bsr     .Lchaine_en
        move.w  F_ZONE(%a6), %d0
        bne.s   1f
        lea     .Ltxt_lit_fixe, %a2
        bsr     .Lchaine
        bra.s   2f
1:      lea     .Ltxt_lit_banque, %a2
        bsr     .Lchaine
        moveq   #0x2F, %d2              | « 0 » - 1 : la zone 1 est la banque 0
        add.w   F_ZONE(%a6), %d2
        bsr     .Lcar
        moveq   #0x20, %d2
        bsr     .Lcar
2:      moveq   #0, %d0
        move.w  F_KIO(%a6), %d0
        lsl.l   #8, %d0                 | Kio → octets, pour `.Lkio`
        lsl.l   #2, %d0                 | puis `.Lkio`, juste en dessous

| %d0 OCTETS en Kio décimaux sur quatre chiffres, puis « K » (de 0 à 9999 Kio). Clobbers %d0-%d2,
| %d4, %a2.
.Lkio:
        lsr.l   #8, %d0
        lsr.l   #2, %d0
        moveq   #4 - 1, %d4
        lea     .Lpuissances, %a2
1:      moveq   #0x30, %d2
        move.w  (%a2)+, %d1
2:      cmp.w   %d1, %d0
        bcs.s   3f
        sub.w   %d1, %d0
        addq.w  #1, %d2
        bra.s   2b
3:      bsr.s   .Lcar
        dbra    %d4, 1b
        moveq   #0x4B, %d2              | « K »
        bra.s   .Lcar

| LE CRC %d7 en huit chiffres hexadécimaux, palette 5, à la case %d1. Clobbers %d0, %d2-%d4.
.Lcrc_ecrire:
        move.w  %d1, VRAMADDR
        move.w  #0x5000, %d3
        move.l  %d7, %d4
        moveq   #8, %d0
        bra.s   .Lhex

| START P1, sur front : NZ si pressé à l'instant (REG_STATUS_B bit 0, actif bas, « Memory
| mapped registers »). F_TOUCHE garde l'état d'avant. Clobbers %d0.
.Lstart:
        moveq   #0, %d0
        btst    #0, STATUS_B
        seq     %d0                     | $FF tenu
        andi.w  #1, %d0
        move.w  F_TOUCHE(%a6), -(%sp)
        move.w  %d0, F_TOUCHE(%a6)
        tst.w   (%sp)+
        beq.s   1f
        moveq   #0, %d0
1:      tst.w   %d0
        rts

| L'EFFACEMENT : chaque case du plan fixe en tuile $020 sous PAL_VIDE (REG_VRAMMOD à 1).
| Clobbers %d0, %d1.
.Leffacer:
        move.w  #1, VRAMMOD
        move.w  #0x7000, VRAMADDR
        move.w  #(PAL_VIDE << 12) + 0x020, %d0
        move.w  #40 * 32 - 1, %d1
1:      move.w  %d0, VRAMRW             | 18 cycles par tour : au-dessus des 12 (« VRAM »)
        dbra    %d1, 1b
        rts

| L'ÉCRITURE, REG_VRAMMOD à 32 (voir `tests.s`) : `.Lchaine_en` pose l'adresse %d1 puis écrit
| la chaîne %a2 sous %d3 ; `.Lcar` écrit %d2 + %d3. Clobbers %d2, %a2.
.Lchaine_en:
        move.w  %d1, VRAMADDR
.Lchaine:
        moveq   #0, %d2
        move.b  (%a2)+, %d2
        beq.s   1f
        bsr.s   .Lcar
        bra.s   .Lchaine
1:      rts
.Lcar:
        add.w   %d3, %d2
        move.w  %d2, VRAMRW
        rts
| %d0 CHIFFRES HEXADÉCIMAUX, les hauts de %d4 d'abord. Clobbers %d0, %d2, %d4.
.Lhex:
        subq.w  #1, %d0
1:      rol.l   #4, %d4
        moveq   #0x0F, %d2
        and.w   %d4, %d2
        cmpi.w  #10, %d2
        bcs.s   2f
        addq.w  #7, %d2
2:      addi.w  #0x30, %d2
        bsr.s   .Lcar
        dbra    %d0, 1b
        rts

| LE PASSAGE DE LA LIGNE $1F0, copie de celle de `tests.s` (bornée, watchdog à chaque tour).
| Clobbers %d0.
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

| ----------------------------------------------------------------------------------
| LES DONNÉES.
        .balign 2
.Lpuissances:
        .word   1000, 100, 10, 1
.Ltxt_titre:      .asciz  "CARTRIDGE CRC32"
.Ltxt_ordre:      .asciz  "BYTES IN MAME FILE ORDER"
.Ltxt_sans:       .asciz  "NO CARTRIDGE"
.Ltxt_slot:       .asciz  "SLOT "
.Ltxt_ngh:        .asciz  "   NGH "
.Ltxt_fixe:       .asciz  "FIXED "
.Ltxt_sans_banque: .asciz "BANKS NONE"
.Ltxt_banques:    .asciz  "BANKS "
.Ltxt_x1024:      .asciz  " X 1024K"
.Ltxt_lit:        .asciz  "READING "
.Ltxt_lit_fixe:   .asciz  "FIXED "
.Ltxt_lit_banque: .asciz  "BANK "
.Ltxt_fini:       .asciz  "DONE                    "
.Ltxt_retour:     .asciz  "START:BACK"
        .balign 4

| LA TABLE du CRC32 réfléchi, $EDB88320 : l'entrée i est i passé huit fois par le registre à
| décalage. Calculée par l'assembleur, aucune valeur recopiée.
.Ltable:
        .set    i, 0
        .rept   256
        .set    c, i
        .rept   8
        .if     c & 1
        .set    c, (c >> 1) ^ 0xEDB88320
        .else
        .set    c, c >> 1
        .endif
        .endr
        .long   c
        .set    i, i + 1
        .endr
