| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| L'ÉCRAN DE PLANTAGE — une exception que personne ne traite, affichée, puis START relance.
|
| AUCUN ORACLE : ni le BIOS de référence ni un BIOS tiers ne sont lus. La remise est
| « Couche 3 → l'écran de plantage, le 2026-10-21 » (`docs/RELECTURE-CONTRATS.md`).
| « mesuré » : un relevé nommé ; « lu dans » : une page du NeoGeo Development Wiki ;
| « SUPPOSÉ » : ni l'un ni l'autre.
|
| D'OÙ L'ON VIENT. Deux portes, un point d'entrée par porte, chacun pose son code :
|   - les créneaux $C00408-$C00432 de la zone d'entrée (`c0.s`), où mènent les tables de
|     vecteurs des cartouches. « BIOS calls » n'en dit que « $C00402 to $C00432 », « Entry
|     point (system boots here) ». Lu dans « 68k vector table », gabarit « For cartridge
|     systems » : $C00408 erreur de bus ; $C0040E erreur d'adresse ET instruction
|     illégale ; $C0041A privilège ; $C00420 trace ; $C00426 réservés et autovecteurs 3 à
|     7 ; $C0042C interruption non initialisée ; $C00432 interruption parasite.
|     MESURÉ, et ça diffère : les tables de 20 cartouches du corpus, lues par lua sous MAME
|     après la remise de la main (le 2026-10-21, notre image ; garou et trally illisibles ;
|     relevé non versionné, remis à l'agent coordinateur). Les 20 mettent l'instruction
|     illégale à $C00414, pas à $C0040E — le créneau du gabarit « For CD systems » —, et :
|       $C00408  vecteur 2, les 20 ;            $C0040E  vecteur 3, les 20 ;
|       $C00414  vecteur 4, les 20 ; lignes A/F aussi chez b2b et neomrdo ;
|       $C0041A  vecteur 8, les 20 ; division, CHK et TRAPV aussi chez lbowling ;
|       $C00420  vecteur 9, les 20 ;            $C0042C  vecteur 15, 19 sur 20 ;
|       $C00426  division/CHK/TRAPV (aof, flipshot, puzzledp), lignes A/F, réservés,
|                vecteur 15 (kof2003), autovecteurs 3 à 7 ;
|       $C00432  vecteur 24, les 20.
|     Un créneau partagé ne dit donc pas l'exception : il prend un code à lui (32 à 34),
|     affiché par la liste de ses causes possibles, sans numéro de vecteur ;
|   - la table de vecteurs du BIOS (`c0.s`, vecteurs 2 à 31), active de la mise sous
|     tension à REG_SWPROM : un vecteur, un point d'entrée, donc l'exception exacte. Ce
|     qui la prendrait est un défaut de notre propre boot (IRQ masquées tout du long) :
|     l'afficher vaut mieux que la boucle muette d'avant, et une boucle identifiable reste,
|     `_plantage_double`, pour une exception levée par ce gestionnaire lui-même.
|
| $C0040E SERT DEUX EXCEPTIONS AUX CADRES DIFFÉRENTS dans le gabarit (aucune des 20
| cartouches mesurées ne l'y suit, mais rien n'interdit qu'une autre le fasse). Lu dans
| « 68k vector table » :
| erreur d'adresse, cadre A (mot d'état, adresse d'accès, IR, SR, PC) ; instruction
| illégale, cadre B (SR, PC) ; et l'erreur d'adresse est un accès « Misaligned (odd) ».
| Le long à SP+2 est donc l'adresse d'accès, impaire, dans un cadre A, et le PC d'une
| instruction illégale, pair, dans un cadre B. On tranche sur ce bit, lu par octet.
| Mesuré (`measured/2026-10-17-diagnostic-b2b-minasan.tsv`, point 1) : sous MAME, une
| erreur d'adresse de b2b empile bien l'adresse $544505 et l'IR $34D9.
|
| LE CADRE, lu dans « 68k vector table », Stack frames : format A, +0 mot d'état (bit 4
| « 0:Write 1:Read », bit 3 « 0:Instruction », bits 2-0 code de fonction), +2 adresse
| d'accès, +6 IR, +8 SR, +10 PC ; format B, +0 SR, +2 PC. A7 affiché = la pile avant le
| cadre, SP + 14 ou SP + 6.
|
| AUCUNE NOUVELLE EXCEPTION. La pile du jeu a reçu le cadre, donc SP est pair (SUPPOSÉ,
| aucune page lue ne le dit : sur une pile impaire, l'empilement lui-même lèverait une
| erreur d'adresse, et le 68000 s'arrêterait en double faute) : on la lit par mots, rien de ce
| qu'elle contient n'est déréférencé. Le code de la porte puis les 15 registres y sont
| empilés SOUS le cadre (62 octets), qui reste intact ; tout est lu avant la première
| écriture en $10F400+. Puis la pile repart de $10F300, comme `c0.s`. SUPPOSÉ : une pile
| du jeu à moins de 62 octets au-dessus de $100000 perdrait ses registres dans la P-ROM.
| Une exception dans ce gestionnaire même, une fois la sauvegarde écrite, trouve DRAPEAU
| armé et tombe dans `_plantage_double` : la première sauvegarde est gardée, la seconde
| n'écrase rien. SUPPOSÉ : qu'avant (la lecture du cadre et la copie, accès pairs en RAM),
| rien n'en lève.
|
| LA SAUVEGARDE, en RAM du BIOS. Lu dans « Memory map » : $10F300-$10FFFF « System
| ROM-reserved RAM » ; `c0.s` la vide au boot. $10F400-$10F45B n'est écrit par aucun
| autre fichier de `src/c0/` (lu dans le code), mais LA ZONE N'EST PAS LIBRE : nam1975
| écrit $10F300-$10F4B3 (mesuré, `measured/2026-10-21-ecrivains-ram-bios.tsv`). La pile du
| jeu peut donc y être au moment de l'exception : d'où le cadre lu d'abord, et la copie des
| registres dans le sens qui ne relit rien d'écrasé. L'écran étant terminal, ce que la
| sauvegarde écrase des données du jeu n'est rendu à personne.
|
| L'ÉCRAN EST TERMINAL : rien n'est rendu au jeu, START relance la machine par le
| watchdog (`dip.s`, mesurée). Ce qui en découle :
|   - REG_BRDFIX pour la police de la carte, après la poignée de main de changement de
|     slot de `dip.s` (« 68k/Z80 communication » : $01, le pilote coupe le son, boucle en
|     RAM, répond $01). Bornée à 60 trames, puis on bascule quand même : un pilote qui ne
|     répond pas coûte une seconde, pas un écran figé. Pas de REG_CRTFIX ni de $03 au
|     retour : le reset du watchdog reprend tout (SUPPOSÉ, comme dans `dip.s`) ;
|   - l'état vidéo du jeu est écrasé, pas lu : REG_NOSHADOW (« Memory mapped registers »,
|     un jeu peut avoir assombri la sortie), la banque de palettes 0, les palettes 0 à 5,
|     le fond, LSP_1st (sprites à hauteur nulle, `video.s`), FIX_CLEAR, REG_VRAMMOD posé ;
|   - le bit 7 de $10FD80 (qui a le vblank) n'importe pas : les IRQ restent masquées
|     (SR = $2700 dès la première instruction), aucun INT1 ne court ;
|   - la palette 0 n'est pas laissée au jeu : la tuile $FF de FIX_CLEAR et la colonne $20
|     des bords sont sous elle. Entrées 1-15 à la couleur du fond, la référence $400000 à
|     $8000 (« Palettes » : « always has to be pure black ($8000) »).
| Les glyphes : 8×8 = tuile ASCII, 8×16 = $100/$200 + ASCII, trait à l'index 1, fond de
| case à l'index 2 (`measured/2026-10-20-sfix-glyphes.tsv`, `ecran.s`, `dip.s`). Ici les
| entrées 2-15 portent la couleur du fond, pour que les cases ne fassent pas de pavés noirs.
| ==================================================================================

        .section .haut, "ax"
        .global _plantage_double

        .equ    VRAMADDR, 0x3C0000
        .equ    VRAMRW,   0x3C0002
        .equ    VRAMMOD,  0x3C0004
        .equ    LSPCMODE, 0x3C0006
        .equ    WATCHDOG, 0x300001
        .equ    SOUND,    0x320000
        .equ    STATUS_B, 0x380000
        .equ    NOSHADOW, 0x3A0001
        .equ    BRDFIX,   0x3A000B
        .equ    PALBANK0, 0x3A000F
        .equ    PALETTES, 0x400000
        .equ    FOND,     0x401FFE

        | La sauvegarde. D0-D7, A0-A6 puis A7 sont contigus : A n à SV_D + 32 + 4n.
        .equ    SV_D,     0x10F400      | 15 longs, par `movem`
        .equ    SV_A7,    0x10F43C      | la pile avant le cadre
        .equ    SV_USP,   0x10F440
        .equ    SV_PC,    0x10F444
        .equ    SV_ACC,   0x10F448      | adresse d'accès, cadre A
        .equ    SV_SR,    0x10F44C
        .equ    SV_IR,    0x10F44E      | cadre A
        .equ    SV_ETAT,  0x10F450      | mot d'état, cadre A
        .equ    SV_CODE,  0x10F452      | octet haut : le vecteur ; bas : le créneau ($C004xx)
        .equ    DRAPEAU,  0x10F458      | MARQUE : le gestionnaire est déjà en cours
        .equ    MARQUE,   0x504C4E54    | « PLNT »
        .equ    C3_OU_4,  0xFF          | code de $C0040E : adresse ou illégale, à trancher
        .equ    C_426,    32            | code de $C00426 : plusieurs causes (voir l'en-tête)
        .equ    C_414,    33            | code de $C00414 : illégale, ou lignes A/F
        .equ    C_41A,    34            | code de $C0041A : privilège, ou division/CHK/TRAPV

        | Une case du plan fixe (« Fix layer ») : $7000 + 32 × colonne + ligne.
        .equ    COL,      3
        .equ    CASE_TITRE, 0x7000 + 32 * COL + 3      | 8×16, lignes 3-4
        .equ    CASE_NOM,   0x7000 + 32 * COL + 6
        .equ    CASE_VIA,   0x7000 + 32 * COL + 7
        .equ    CASE_PC,    0x7000 + 32 * COL + 9
        .equ    CASE_ACC,   0x7000 + 32 * COL + 10
        .equ    CASE_IR,    0x7000 + 32 * COL + 11
        .equ    CASE_REGS,  0x7000 + 32 * COL + 13     | D0/A0 à D7/A7, lignes 13-20
        .equ    CASE_USP,   0x7000 + 32 * COL + 21
        .equ    CASE_NGH,   0x7000 + 32 * COL + 23
        .equ    CASE_START, 0x7000 + 32 * COL + 26

        | Les couleurs, $0RGB (« Colors »). Choix d'aspect.
        .equ    C_FOND,   0x0006        | bleu nuit
        .equ    N_PAL,    5             | palettes 1 à 5, voir `.Lcouleurs`

| ----------------------------------------------------------------------------------
| LES POINTS D'ENTRÉE. Chacun : SR à $2700 d'abord (une erreur de groupe 0 ou 1 ne touche
| pas au masque, une IRQ pourrait suivre), son code empilé sans toucher un registre — sous
| le cadre, jamais en $10F400+ (voir LA SAUVEGARDE) —, puis le tronc commun. 12 octets
| chacun.
        .macro  ENTREE nom, vecteur, creneau
        .global \nom
\nom:
        move.w  #0x2700, %sr
        move.w  #((\vecteur) << 8) + (\creneau), -(%sp)
        bra.w   _pl_commun
        .endm

        | Les créneaux de la zone d'entrée, atteints par les `jmp` de `c0.s`.
        ENTREE  _pl_c408, 2, 0x08       | erreur de bus
        ENTREE  _pl_c40e, C3_OU_4, 0x0E | erreur d'adresse ou instruction illégale
        ENTREE  _pl_c414, C_414, 0x14   | instruction illégale, lignes A/F
        ENTREE  _pl_c41a, C_41A, 0x1A   | privilège, division, CHK, TRAPV
        ENTREE  _pl_c420, 9, 0x20       | trace
        ENTREE  _pl_c426, C_426, 0x26   | division … autovecteurs 3 à 7
        ENTREE  _pl_c42c, 15, 0x2C      | interruption non initialisée
        ENTREE  _pl_c432, 24, 0x32      | interruption parasite

        | La table de vecteurs du BIOS, 2 à 31 : créneau 0.
        .irp    n, 2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
        ENTREE  _pl_v\n, \n, 0
        .endr

| ----------------------------------------------------------------------------------
| LE TRONC COMMUN. Aucun registre n'a encore changé (hors SR), et rien n'est écrit en
| $10F400+ avant que le cadre soit lu : la sauvegarde pourrait le recouvrir (voir l'en-tête).
| D'abord la seule lecture du drapeau, puis les registres empilés à la suite du code, sous
| le cadre. Pile : (SP) les 15 registres, 60(SP) le code, 62(SP) le cadre.
_pl_commun:
        cmpi.l  #MARQUE, DRAPEAU
        beq.w   _plantage_double
        movem.l %d0-%d7/%a0-%a6, -(%sp)
        lea     62(%sp), %a0            | le cadre

        | $C0040E : bit 0 du long à SP+2 du cadre, lu par octet (voir l'en-tête). Le code
        | tranché est réécrit dans notre propre mot, sous le cadre.
        moveq   #0, %d0
        move.b  60(%sp), %d0            | l'octet haut du code : le vecteur
        cmpi.b  #C3_OU_4, %d0
        bne.s   1f
        moveq   #4, %d0                 | pair : instruction illégale, cadre B
        btst    #0, 5(%a0)
        beq.s   2f
        moveq   #3, %d0                 | impair : erreur d'adresse, cadre A
2:      move.b  %d0, 60(%sp)
1:      moveq   #0, %d1                 | %d1 mot d'état, %d2 adresse d'accès, %d3 IR :
        moveq   #0, %d2                 | nuls hors du cadre A
        moveq   #0, %d3
        cmpi.b  #3, %d0
        bhi.s   3f                      | 4 et plus : cadre B
        move.w  (%a0)+, %d1             | 2 et 3 : cadre A
        move.l  (%a0)+, %d2
        move.w  (%a0)+, %d3
3:      move.w  (%a0)+, %d4             | SR
        move.l  (%a0)+, %d5             | PC
        movea.l %a0, %a1                | A7 : la pile avant le cadre
        move.l  %usp, %a2
        move.w  60(%sp), %d7            | le code

        | LE CADRE EST LU. Les 15 registres, de la pile vers SV_D : les deux zones peuvent se
        | chevaucher (pile du jeu en $10F400+), d'où une copie dans le sens qui ne relit
        | rien de déjà écrasé — montante si SV_D est sous la source, descendante sinon.
        movea.l %sp, %a3
        lea     SV_D, %a4
        moveq   #15 - 1, %d6
        cmpa.l  %a3, %a4
        bhi.s   5f
4:      move.l  (%a3)+, (%a4)+
        dbra    %d6, 4b
        bra.s   7f
5:      lea     60(%a3), %a3
        lea     60(%a4), %a4
6:      move.l  -(%a3), -(%a4)
        dbra    %d6, 6b
7:      move.l  %a1, SV_A7              | le reste, depuis les registres
        move.l  %a2, SV_USP
        move.l  %d5, SV_PC
        move.l  %d2, SV_ACC
        move.w  %d4, SV_SR
        move.w  %d3, SV_IR
        move.w  %d1, SV_ETAT
        move.w  %d7, SV_CODE
        move.l  #MARQUE, DRAPEAU        | dès ici, une exception tombe dans `_plantage_double`
        movea.l #0x10F300, %sp          | la pile peut repartir

| ----------------------------------------------------------------------------------
| LE Z80 EN RAM, PUIS LA POLICE DE LA CARTE (voir l'en-tête ; même boucle que `dip.s`).
| L'écho n'est lu qu'une trame après chaque envoi, comme `menu.s` et `jukebox.s` : la
| dernière réponse du pilote du jeu peut déjà valoir $01, et la lire tout de suite la
| prendrait pour l'écho.
        moveq   #60-1, %d4
1:      move.b  #0x01, SOUND
        bsr     .Lsync
        cmpi.b  #0x01, SOUND
        dbeq    %d4, 1b
        bsr     .Lsync                  | une trame pour que le pilote entre en boucle
        move.b  %d0, BRDFIX

| L'ÉTAT VIDÉO, écrasé. Palettes juste après le passage de la ligne $1F0 (« Palettes » :
| écrire en affichage fait de la neige).
        bsr     .Lsync
        move.b  %d0, PALBANK0
        move.b  %d0, NOSHADOW
        lea     PALETTES, %a2
        move.w  #0x8000, (%a2)+         | la référence
        moveq   #15-1, %d1
1:      move.w  #C_FOND, (%a2)+         | palette 0, entrées 1-15
        dbra    %d1, 1b
        lea     .Lcouleurs, %a3
        moveq   #N_PAL-1, %d2
2:      clr.w   (%a2)+                  | entrée 0, transparente
        move.w  (%a3)+, (%a2)+          | entrée 1, le trait
        moveq   #14-1, %d1
3:      move.w  #C_FOND, (%a2)+         | entrées 2-15, le fond de case
        dbra    %d1, 3b
        dbra    %d2, 2b
        move.w  #C_FOND, FOND
        jsr     _lsp_1st
        jsr     _fix_clear
        move.w  #32, VRAMMOD            | une écriture = une colonne
        lea     VRAMRW, %a0
        lea     VRAMADDR, %a1

| ----------------------------------------------------------------------------------
| LE TEXTE. %d1 : la case de début de ligne ; %d3 : palette << 12 + décalage de tuile.
        move.w  #CASE_TITRE, %d1        | le titre, 8×16, palette 2
        move.w  #0x2100, %d3
        lea     .Ltitre, %a2
        bsr     .Lligne
        move.w  #CASE_TITRE + 1, %d1
        move.w  #0x2200, %d3
        lea     .Ltitre, %a2
        bsr     .Lligne

        | L'EXCEPTION, palette 3 : son nom, puis « VECTOR n » quand le code est exact.
        move.w  #CASE_NOM, %d1
        move.w  #0x3000, %d3
        moveq   #0, %d6
        move.b  SV_CODE, %d6
        move.w  %d6, %d0
        lsl.w   #2, %d0
        lea     .Lnoms, %a2
        movea.l (%a2,%d0.w), %a2
        bsr     .Lligne
        cmpi.w  #C_426, %d6
        bcc.s   1f
        lea     .Lvecteur, %a2
        bsr     .Ltexte
        move.w  %d6, %d4
        bsr     .Ldecimal
1:
        | LA PORTE, palette 4 : le créneau $C004xx, ou la table du BIOS.
        move.w  #CASE_VIA, %d1
        move.w  #0x4000, %d3
        lea     .Lvia_bios, %a2
        move.b  SV_CODE + 1, %d4
        beq.s   1f
        lea     .Lvia, %a2
        bsr     .Lligne
        bsr     .Lhex2
        bra.s   2f
1:      bsr     .Lligne
2:
        | PC ET SR, palette 1.
        move.w  #0x1000, %d3
        move.w  #CASE_PC, %d1
        lea     .Lpc, %a2
        bsr     .Lligne
        move.l  SV_PC, %d4
        bsr     .Lhex8
        lea     .Lsr, %a2
        bsr     .Ltexte
        move.w  SV_SR, %d4
        bsr     .Lhex4

        | LE CADRE A, erreurs de bus et d'adresse seulement.
        cmpi.w  #3, %d6
        bhi.w   .Lregistres
        move.w  #CASE_ACC, %d1
        lea     .Lacces, %a2
        bsr     .Lligne
        move.l  SV_ACC, %d4
        bsr     .Lhex8
        lea     .Lecriture, %a2         | bit 4 : 0 écriture, 1 lecture
        btst    #4, SV_ETAT + 1
        beq.s   1f
        lea     .Llecture, %a2
1:      bsr     .Ltexte
        lea     .Linstr, %a2            | bit 3 : 0 instruction
        btst    #3, SV_ETAT + 1
        beq.s   1f
        lea     .Ldonnee, %a2
1:      bsr     .Ltexte
        move.w  #CASE_IR, %d1
        lea     .Lir, %a2
        bsr     .Lligne
        move.w  SV_IR, %d4
        bsr     .Lhex4
        lea     .Letat, %a2
        bsr     .Ltexte
        move.w  SV_ETAT, %d4
        bsr     .Lhex4

        | LES 16 REGISTRES, deux colonnes : Dn puis An, ligne n.
.Lregistres:
        moveq   #0, %d7
1:      move.w  #CASE_REGS, %d1
        add.w   %d7, %d1
        lea     .Ld, %a2
        bsr     .Lligne
        moveq   #0x30, %d2
        add.w   %d7, %d2
        bsr     .Lcar
        moveq   #0x20, %d2
        bsr     .Lcar
        move.w  %d7, %d0
        lsl.w   #2, %d0
        lea     SV_D, %a3
        move.l  (%a3,%d0.w), %d4
        bsr     .Lhex8
        lea     .La, %a2
        bsr     .Ltexte
        moveq   #0x30, %d2
        add.w   %d7, %d2
        bsr     .Lcar
        moveq   #0x20, %d2
        bsr     .Lcar
        move.w  %d7, %d0
        lsl.w   #2, %d0
        lea     SV_D + 32, %a3
        move.l  (%a3,%d0.w), %d4
        bsr     .Lhex8
        addq.w  #1, %d7
        cmpi.w  #8, %d7
        bcs.s   1b

        move.w  #CASE_USP, %d1
        lea     .Lusp, %a2
        bsr     .Lligne
        move.l  SV_USP, %d4
        bsr     .Lhex8

        | LE JEU. Lu dans « 68k program header » : NGH, mot de $108. PRIS DANS LA TABLE DES
        | SLOTS ($D00124, l'entrée du slot servi $D00108), pas relu à $108 : cet écran est sous
        | REG_BRDFIX, où la cartouche ne répond pas sur le matériel (SLOTCS, la détection de
        | `c0.s` ; retour du 2026-10-24, `docs/ESSAI-MATERIEL.md`).
        move.w  #CASE_NGH, %d1
        lea     .Lngh, %a2
        bsr     .Lligne
        moveq   #0, %d4
        move.b  0xD00108, %d4           | le slot servi
        lsl.w   #2, %d4
        lea     0xD00124, %a2
        move.w  (%a2,%d4.w), %d4        | son NGH
        bsr     .Lhex4

        move.w  #CASE_START, %d1
        move.w  #0x5000, %d3
        lea     .Lstart, %a2
        bsr     .Lligne

| ----------------------------------------------------------------------------------
| L'ATTENTE DE START P1, sur front : relâché d'abord, puis appuyé — un START tenu au moment
| du plantage ne relance rien. Lu dans « Memory mapped registers » : REG_STATUS_B bit 0,
| START P1, actif à l'état bas (comme `dip.s`). Puis LA RELANCE PAR LE WATCHDOG (`dip.s`) :
| une boucle sans coup de pied, identifiable dans une trace.
        moveq   #0, %d6                 | 1 dès qu'on a vu START relâché
.Lattente:
        bsr     .Lsync
        btst    #0, STATUS_B
        beq.s   1f
        moveq   #1, %d6
        bra.s   .Lattente
1:      tst.w   %d6
        beq.s   .Lattente
        clr.l   DRAPEAU                 | sinon une exception du boot, avant son vidage, figerait
.Lrelance:
        bra.s   .Lrelance               | sans coup de pied : le watchdog mord

| UNE EXCEPTION DANS CE GESTIONNAIRE. La boucle de `_piege` (`c0.s` jusqu'ici) : coups de
| pied au watchdog, pour que la carte ne reparte pas et que l'adresse reste dans la trace.
_plantage_double:
        move.b  %d0, WATCHDOG
        bra.s   _plantage_double

| ----------------------------------------------------------------------------------
| LE PASSAGE DE LA LIGNE $1F0, comme `ecran.s` et `dip.s` (mesuré,
| `2026-10-17-diagnostic-b2b-minasan.tsv`) ; watchdog à chaque tour. Clobbers %d0.
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

| UNE LIGNE : l'adresse %d1, puis la chaîne %a2. Le `rts` du caractère précédent et le
| `bsr` tiennent plus de 16 cycles entre une donnée et l'adresse (« VRAM »).
.Lligne:
        move.w  %d1, (%a1)
| UNE CHAÎNE terminée par 0, à la suite. Clobbers %d2, %a2.
.Ltexte:
        moveq   #0, %d2
        move.b  (%a2)+, %d2
        beq.s   1f
        bsr.s   .Lcar
        bra.s   .Ltexte
1:      rts

| UN CARACTÈRE %d2 (ASCII), avec %d3. Plus de 12 cycles entre deux données, par le seul
| appel. Clobbers %d2.
.Lcar:
        add.w   %d3, %d2
        move.w  %d2, (%a0)
        rts

| %d4 EN CHIFFRES HEXADÉCIMAUX : 8 (.Lhex8), 4 (.Lhex4, mot bas) ou 2 (.Lhex2, octet
| bas). Clobbers %d2, %d4, %d5.
.Lhex2:
        ror.l   #8, %d4
        moveq   #2-1, %d5
        bra.s   .Lhexn
.Lhex4:
        swap    %d4
        moveq   #4-1, %d5
        bra.s   .Lhexn
.Lhex8:
        moveq   #8-1, %d5
.Lhexn:
        rol.l   #4, %d4
        moveq   #0x0F, %d2
        and.w   %d4, %d2
        cmpi.w  #10, %d2
        bcs.s   1f
        addq.w  #7, %d2                 | 10-15 → « A »-« F »
1:      addi.w  #0x30, %d2
        bsr.s   .Lcar
        dbra    %d5, .Lhexn
        rts

| %d4.w (0 à 99) EN DÉCIMAL, sans zéro de tête. Clobbers %d2, %d4.
.Ldecimal:
        andi.l  #0xFFFF, %d4
        divu    #10, %d4
        tst.w   %d4
        beq.s   1f
        moveq   #0x30, %d2
        add.w   %d4, %d2
        bsr.s   .Lcar
1:      swap    %d4
        moveq   #0x30, %d2
        add.w   %d4, %d2
        bra.s   .Lcar

| ----------------------------------------------------------------------------------
| LES DONNÉES.
        .balign 2
.Lcouleurs:                             | l'entrée 1 des palettes 1 à 5
        .word   0x0BBB                  | 1 les valeurs
        .word   0x0F44                  | 2 le titre
        .word   0x0FE3                  | 3 le nom de l'exception
        .word   0x0777                  | 4 la porte
        .word   0x02F4                  | 5 START

| Les noms, par code : le numéro de vecteur du 68000 (« 68k vector table »), puis 32 à 34
| pour les créneaux partagés. 0 et 1 n'arrivent pas ici. Pas de virgule : elle n'est pas
| mesurée (`measured/2026-10-20-sfix-glyphes.tsv`).
.Lnoms:
        .long   .Ln_res, .Ln_res, .Ln_bus, .Ln_adr, .Ln_ill, .Ln_div, .Ln_chk, .Ln_trapv
        .long   .Ln_priv, .Ln_trace, .Ln_linea, .Ln_linef, .Ln_res, .Ln_res, .Ln_res, .Ln_uninit
        .long   .Ln_res, .Ln_res, .Ln_res, .Ln_res, .Ln_res, .Ln_res, .Ln_res, .Ln_res
        .long   .Ln_spur, .Ln_irq, .Ln_irq, .Ln_irq, .Ln_irq, .Ln_irq, .Ln_irq, .Ln_irq
        .long   .Ln_426, .Ln_414, .Ln_41a
.Ln_bus:        .asciz  "BUS ERROR"
.Ln_adr:        .asciz  "ADDRESS ERROR"
.Ln_ill:        .asciz  "ILLEGAL INSTRUCTION"
.Ln_div:        .asciz  "DIVISION BY ZERO"
.Ln_chk:        .asciz  "CHK INSTRUCTION"
.Ln_trapv:      .asciz  "TRAPV INSTRUCTION"
.Ln_priv:       .asciz  "PRIVILEGE VIOLATION"
.Ln_trace:      .asciz  "TRACE"
.Ln_linea:      .asciz  "LINE A INSTRUCTION"
.Ln_linef:      .asciz  "LINE F INSTRUCTION"
.Ln_uninit:     .asciz  "UNINITIALIZED INTERRUPT"
.Ln_res:        .asciz  "RESERVED VECTOR"
.Ln_spur:       .asciz  "SPURIOUS INTERRUPT"
.Ln_irq:        .asciz  "INTERRUPT AUTOVECTOR"
.Ln_426:        .asciz  "DIV/CHK/TRAPV/LINE A-F/IRQ/RESERVED"
.Ln_414:        .asciz  "ILLEGAL INSTRUCTION OR LINE A/F"
.Ln_41a:        .asciz  "PRIVILEGE/DIVIDE/CHK/TRAPV"
.Ltitre:        .asciz  "SYSTEM CRASH"
.Lvecteur:      .asciz  "  VECTOR "
.Lvia:          .asciz  "ENTRY C004"
.Lvia_bios:     .asciz  "ENTRY BIOS VECTOR TABLE"
.Lpc:           .asciz  "PC "
.Lsr:           .asciz  "   SR "
.Lacces:        .asciz  "ACCESS "
.Llecture:      .asciz  " READ"
.Lecriture:     .asciz  " WRITE"
.Linstr:        .asciz  " INSTRUCTION"
.Ldonnee:       .asciz  " DATA"
.Lir:           .asciz  "IR "
.Letat:         .asciz  "   STATUS "
.Ld:            .asciz  "D"
.La:            .asciz  "   A"
.Lusp:          .asciz  "USP "
.Lngh:          .asciz  "GAME NGH "
.Lstart:        .asciz  "PRESS START TO RESTART"
        .balign 2
