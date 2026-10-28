| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| IMAGE DE DIAGNOSTIC DES SLOTS — un sp1 autonome, pour UN essai sur une vraie carte.
|
| Ce n'est pas ReBIOS : aucune cartouche n'est lancée. Au reset, l'image lit les registres
| système, puis, pour chaque slot 0 à 7 et pour six façons d'y accéder, les 16 octets de
| $000100-$00010F (le début de l'en-tête, « 68k program header » : « NEO-GEO » puis le
| NGH). Elle les affiche en hexadécimal avec la police de la carte (SFIX, plan fixe), et
| tient l'écran indéfiniment en donnant ses coups de pied au watchdog.
|
| POURQUOI, et ce que chaque variante teste (docs/ESSAI-MATERIEL.md, retour du 2026-10-24) :
| l'image n°8 lisait l'en-tête sous REG_BRDFIX et trouvait le bus flottant sur une MV-2F.
| Hypothèse principale (SLOTCS gaté par SYSTEMB, wiki « NEO-F0 », « MVS cartridge pinout »,
| « Signals ») : la cartouche ne répond que sous REG_CRTFIX. Les variantes :
|   A  REG_BRDFIX, vecteurs du BIOS, REG_SLOT octet à $380021, lectures en mots — l'image n°8 ;
|   B  REG_CRTFIX, sinon comme A — la correction, et l'ordre mesuré de la référence ;
|   C  B plus REG_SWPROM pendant la lecture ;
|   D  B, mais REG_SLOT écrit en mot à $380020 (le numéro dans l'octet bas) ;
|   E  B, puis 8 trames d'attente entre le choix du slot et la lecture ;
|   F  B, lectures en octets (16 `move.b`), comme la référence.
| A est mesuré en premier, pour tous les slots, avant toute écriture de REG_CRTFIX.
|
| L'ÉCRAN, police 8×8 (tuile = code ASCII, palette dans les 4 bits hauts ; `src/c0/dip.s`,
| `measured/2026-10-20-sfix-glyphes.tsv`), plan fixe $7000 + 32 × colonne + ligne, lignes 2
| à 29 visibles (« Fix layer »). Deux pages, alternées toutes les 240 trames (~4 s) :
| page 1 les variantes A, B, C ; page 2 D, E, F. Une ligne par slot et par variante :
|   « 0B 4E454F2D47454F00 0201xxxxxxxxxxxx Y » : slot, variante, 16 octets, et Y si les
| sept premiers sont « NEO-GEO » — colonnes 1 à 38, la première et la dernière laissées au
| bord de l'écran. En tête : REG_SYSTYPE ($300081), REG_STATUS_A ($320001),
| le mot de $380000 (REG_STATUS_B dans l'octet haut, « Memory mapped registers »),
| REG_DIPSW ($300001), et si le Z80 a répondu $01 (Z80 OK ou NO).
|
| Sources : NeoGeo Development Wiki — « Memory mapped registers », « Fix layer »,
| « Palettes », « VRAM », « Watchdog », « 68k/Z80 communication », « Sprites » (taille 0 dans
| SCB3 : sprite non affiché). Aucun code de BIOS ni de jeu lu.
| ==================================================================================
        .equ    WATCHDOG, 0x300001
        .equ    DIPSW,    0x300001
        .equ    SYSTYPE,  0x300081
        .equ    STATUS_A, 0x320001
        .equ    SOUND,    0x320000
        .equ    STATUS_B, 0x380000
        .equ    REGSLOT,  0x380021
        .equ    SWPBIOS,  0x3A0003
        .equ    SWPROM,   0x3A0013
        .equ    BRDFIX,   0x3A000B
        .equ    CRTFIX,   0x3A001B
        .equ    PALBANK0, 0x3A001F
        .equ    VRAMADDR, 0x3C0000
        .equ    VRAMRW,   0x3C0002
        .equ    VRAMMOD,  0x3C0004
        .equ    LSPCMODE, 0x3C0006
        .equ    IRQACK,   0x3C000C
        .equ    PALETTES, 0x400000
        .equ    FOND,     0x401FFE
        .equ    RES,      0x100000      | 6 variantes × 8 slots × 16 octets
        .equ    VARS,     0x100400      | registres lus au boot, 8 octets
        .equ    SYNC_TOURS, 5800

        .section .vectors, "a"
        .long   0x10F300
        .long   _reset
        .rept   30
        .long   _exception
        .endr

        .org    0x400
        .byte   0x80, 0x02              | MVS, Europe (« System ROM »)
        .org    0x402
        .global _reset
_reset:
        jmp     _diag

        .org    0x800
_diag:
        move.w  #0x2700, %sr
        move.l  #0x10F300, %sp
        move.b  %d0, WATCHDOG
        move.b  %d0, SWPBIOS
        move.b  %d0, BRDFIX
        move.b  %d0, PALBANK0
        move.w  #0x4000, LSPCMODE
        move.w  #7, IRQACK

        | LES REGISTRES, avant tout le reste.
        lea     VARS, %a0
        move.b  SYSTYPE, (%a0)+
        move.b  STATUS_A, (%a0)+
        move.w  STATUS_B, %d0
        move.w  %d0, (%a0)+
        move.b  DIPSW, (%a0)+
        clr.b   (%a0)+                  | Z80 : 0 pas de réponse

        | A : sous REG_BRDFIX, comme au reset, tous les slots d'abord.
        moveq   #0, %d6                 | variante
        bsr     _variante

        | LE Z80 GARÉ ($01, son écho, 60 trames au plus) avant la première bascule REG_CRTFIX,
        | qui change sa ROM ; puis une trame.
        moveq   #60-1, %d4
1:      move.b  #0x01, SOUND
        bsr     _sync
        cmpi.b  #0x01, SOUND
        dbeq    %d4, 1b
        bne.s   2f
        move.b  #1, VARS + 5
2:      bsr     _sync

        moveq   #1, %d6
3:      bsr     _variante               | B à F
        addq.w  #1, %d6
        cmpi.w  #6, %d6
        blo.s   3b
        move.b  #0, REGSLOT
        move.b  %d0, BRDFIX
        move.b  %d0, SWPBIOS

        bsr     _ecran_init
        moveq   #0, %d7                 | trames
_boucle:
        bsr     _sync
        moveq   #0, %d0
        move.w  %d7, %d0
        divu    #240, %d0
        andi.w  #1, %d0                 | la page, 0 ou 1
        bsr     _page
        addq.w  #1, %d7
        bra.s   _boucle

| ----------------------------------------------------------------------------------
| UNE VARIANTE %d6 (0-5) sur les huit slots. Résultat à RES + 128 × %d6 + 16 × slot.
| Revient sous REG_BRDFIX et REG_SWPBIOS, REG_SLOT à 0.
_variante:
        moveq   #0, %d5                 | slot
        move.w  %d6, %d0
        lsl.w   #7, %d0
        lea     RES, %a1
        adda.w  %d0, %a1
1:      move.b  %d0, WATCHDOG
        tst.w   %d6
        beq.s   2f                      | A : REG_BRDFIX
        bsr.s   _choisir                | REG_SLOT, REG_CRTFIX, REG_SLOT : l'ordre de la référence
        move.b  %d0, CRTFIX
2:      bsr.s   _choisir
        cmpi.w  #4, %d6
        bne.s   5f
        moveq   #8-1, %d4               | E : 8 trames
6:      bsr     _sync
        dbra    %d4, 6b
5:      cmpi.w  #2, %d6
        bne.s   7f
        move.b  %d0, SWPROM             | C : les vecteurs de la cartouche
7:      lea     0x100, %a0
        cmpi.w  #5, %d6
        beq.s   8f
        move.w  (%a0)+, (%a1)+          | en mots
        move.w  (%a0)+, (%a1)+
        move.w  (%a0)+, (%a1)+
        move.w  (%a0)+, (%a1)+
        move.w  (%a0)+, (%a1)+
        move.w  (%a0)+, (%a1)+
        move.w  (%a0)+, (%a1)+
        move.w  (%a0)+, (%a1)+
        bra.s   9f
8:      moveq   #16-1, %d4              | F : en octets
10:     move.b  (%a0)+, (%a1)+
        dbra    %d4, 10b
9:      move.b  %d0, SWPBIOS
        move.b  %d0, BRDFIX
        addq.w  #1, %d5
        cmpi.w  #8, %d5
        blo.s   1b
        move.b  #0, REGSLOT
        rts

| LE SLOT %d5 dans REG_SLOT : en octet à $380021, ou en mot à $380020 pour la variante D.
_choisir:
        cmpi.w  #3, %d6
        bne.s   1f
        move.w  %d5, 0x380020           | D : REG_SLOT en mot
        rts
1:      move.b  %d5, REGSLOT
        rts

| ----------------------------------------------------------------------------------
| LE PASSAGE DE LA LIGNE $1F0 (« LSPC » : le compteur de ligne dans REG_LSPCMODE, bits 7-15),
| borné, watchdog à chaque tour — la même attente que `src/c0/c0.s`. Clobbers %d0.
_sync:
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
| L'ÉCRAN : palettes, fond noir, sprites cachés (SCB3 à zéro : taille 0), plan fixe vidé.
_ecran_init:
        bsr     _sync
        lea     PALETTES, %a0
        move.w  #0x100 - 1, %d1         | palettes 0 à 15, 16 entrées
1:      clr.w   (%a0)+
        dbra    %d1, 1b
        clr.w   FOND
        move.w  #0x7FFF, PALETTES + 0x20 + 2    | palette 1, entrée 1 : blanc
        move.w  #0x6FF0, PALETTES + 0x40 + 2    | palette 2, entrée 1 : jaune
        move.w  #0x60F0, PALETTES + 0x60 + 2    | palette 3, entrée 1 : vert
        lea     VRAMRW, %a0
        move.w  #1, VRAMMOD
        move.w  #0x8200, VRAMADDR       | SCB3 : 512 mots à zéro
        nop
        nop
        move.w  #0x200 - 1, %d1
2:      move.b  %d0, WATCHDOG
        clr.w   (%a0)
        dbra    %d1, 2b
        nop
        nop
        move.w  #0x7000, VRAMADDR       | plan fixe : 40 × 32, tuile $020 palette 0
        nop
        nop
        move.w  #0x500 - 1, %d1
3:      move.b  %d0, WATCHDOG
        move.w  #0x0020, (%a0)
        dbra    %d1, 3b
        nop
        nop
        move.w  #32, VRAMMOD            | une écriture : une colonne à droite
        rts

| ----------------------------------------------------------------------------------
| UNE PAGE (%d0 = 0 ou 1), redessinée à chaque trame : en-tête, légende, 24 lignes de
| résultats, pied avec le compteur de trames %d7.
_page:
        movem.l %d0-%d7/%a0-%a3, -(%sp)
        move.w  %d0, %d6                | la page
        | ligne 2 : le titre
        moveq   #2, %d1
        moveq   #1, %d2
        move.w  #0x2000, %d3
        lea     .Ltitre, %a2
        bsr     _texte
        | ligne 3 : les registres
        moveq   #3, %d1
        moveq   #1, %d2
        move.w  #0x1000, %d3
        lea     .Lsys, %a2
        bsr     _texte                  | %d2 : la colonne suivante
        move.b  VARS, %d4
        bsr     _hex2
        lea     .Lsta, %a2
        bsr     _texte
        move.b  VARS + 1, %d4
        bsr     _hex2
        lea     .Lstb, %a2
        bsr     _texte
        move.b  VARS + 2, %d4
        bsr     _hex2
        move.b  VARS + 3, %d4
        bsr     _hex2
        lea     .Ldip, %a2
        bsr     _texte
        move.b  VARS + 4, %d4
        bsr     _hex2
        lea     .Lz80ok, %a2
        tst.b   VARS + 5
        bne.s   1f
        lea     .Lz80no, %a2
1:      bsr     _texte
        | ligne 4 : la légende de la page
        moveq   #4, %d1
        moveq   #1, %d2
        move.w  #0x2000, %d3
        lea     .Lleg1, %a2
        tst.w   %d6
        beq.s   2f
        lea     .Lleg2, %a2
2:      bsr     _texte
        | lignes 5 à 28 : slot-major, trois variantes par slot
        moveq   #5, %d1
        moveq   #0, %d5                 | slot
3:      moveq   #0, %d4
        move.w  %d6, %d0
        mulu    #3, %d0                 | première variante de la page
        move.w  %d0, %d7
        moveq   #3-1, %d0
4:      bsr     _resultat               | slot %d5, variante %d7, ligne %d1
        addq.w  #1, %d1
        addq.w  #1, %d7
        dbra    %d0, 4b
        addq.w  #1, %d5
        cmpi.w  #8, %d5
        blo.s   3b
        | ligne 29 : la page et le compteur
        movem.l (%sp)+, %d0-%d7/%a0-%a3
        movem.l %d0-%d7/%a0-%a3, -(%sp)
        moveq   #29, %d1
        moveq   #1, %d2
        move.w  #0x2000, %d3
        lea     .Lpage1, %a2
        tst.w   %d0
        beq.s   5f
        lea     .Lpage2, %a2
5:      bsr     _texte
        move.w  %d7, %d4
        lsr.w   #8, %d4
        bsr     _hex2
        move.w  %d7, %d4
        bsr     _hex2
        movem.l (%sp)+, %d0-%d7/%a0-%a3
        rts

| UNE LIGNE DE RÉSULTAT : slot %d5, variante %d7 (0-5), ligne %d1. Préserve %d0, %d1, %d5-%d7.
_resultat:
        movem.l %d0/%d5-%d7, -(%sp)
        moveq   #1, %d2
        move.w  #0x1000, %d3
        move.w  %d5, %d4
        bsr     _chiffre
        move.w  %d7, %d4
        addi.w  #0x41, %d4              | « A » + variante
        bsr     _car
        moveq   #0x20, %d4
        bsr     _car
        move.w  %d7, %d0
        lsl.w   #7, %d0
        move.w  %d5, %d4
        lsl.w   #4, %d4
        add.w   %d4, %d0
        lea     RES, %a3
        adda.w  %d0, %a3                | les 16 octets
        moveq   #16-1, %d5
1:      move.b  (%a3)+, %d4
        bsr     _hex2
        cmpi.w  #8, %d5
        bne.s   2f
        moveq   #0x20, %d4              | une espace après le 8e octet
        bsr     _car
2:      dbra    %d5, 1b
        moveq   #0x20, %d4
        bsr     _car
        | « NEO-GEO » aux sept premiers octets ?
        suba.w  #16, %a3
        lea     .Lneogeo, %a2
        moveq   #7-1, %d5
3:      cmpm.b  (%a2)+, (%a3)+
        dbne    %d5, 3b
        bne.s   4f
        move.w  #0x3000, %d3            | vert
        moveq   #0x59, %d4              | « Y »
        bra.s   5f
4:      moveq   #0x2D, %d4              | « - »
5:      bsr     _car
        movem.l (%sp)+, %d0/%d5-%d7
        rts

| ----------------------------------------------------------------------------------
| L'ÉCRITURE DANS LE PLAN FIXE : ligne %d1, colonne %d2, palette %d3 (déjà décalée de 12).
| _texte : la chaîne %a2 (terminée par 0) ; _hex2 : l'octet %d4 en deux chiffres ;
| _chiffre : le quartet bas de %d4 ; _car : le caractère %d4. Chacune avance %d2.
| Clobbers %d4 (et %a2 pour _texte).
_texte:
        moveq   #0, %d4
        move.b  (%a2)+, %d4
        beq.s   1f
        bsr.s   _car
        bra.s   _texte
1:      rts

_hex2:
        move.w  %d4, -(%sp)
        lsr.b   #4, %d4
        bsr.s   _chiffre
        move.w  (%sp)+, %d4
_chiffre:
        andi.w  #0x0F, %d4
        cmpi.w  #10, %d4
        bcs.s   1f
        addq.w  #7, %d4
1:      addi.w  #0x30, %d4
_car:
        move.l  %d0, -(%sp)
        move.w  %d2, %d0
        lsl.w   #5, %d0
        add.w   %d1, %d0
        addi.w  #0x7000, %d0
        move.w  %d0, VRAMADDR
        andi.w  #0xFF, %d4
        or.w    %d3, %d4
        nop
        nop
        move.w  %d4, VRAMRW
        addq.w  #1, %d2
        move.l  (%sp)+, %d0
        rts

| ----------------------------------------------------------------------------------
| UNE EXCEPTION : la ligne 30 cachée ne se voit pas, donc ligne 29, et l'on reste là, le
| watchdog servi — l'écran ne redémarre jamais.
_exception:
        move.w  #0x2700, %sr
        move.l  #0x10F300, %sp
        moveq   #29, %d1
        moveq   #24, %d2
        move.w  #0x2000, %d3
        lea     .Lexc, %a2
        bsr     _texte
1:      move.b  %d0, WATCHDOG
        bra.s   1b

.Ltitre:  .asciz "REBIOS SLOT DIAG 1"
.Lsys:    .asciz "SYS "
.Lsta:    .asciz " STA "
.Lstb:    .asciz " STB "
.Ldip:    .asciz " DIP "
.Lz80ok:  .asciz " Z80 OK"
.Lz80no:  .asciz " Z80 NO"
.Lleg1:   .asciz "A BRDFIX  B CRTFIX  C CRTFIX+SWPROM"
.Lleg2:   .asciz "D SLOT WORD  E 8 FRAMES  F BYTE READ"
.Lpage1:  .asciz "PAGE 1/2  FRAME "
.Lpage2:  .asciz "PAGE 2/2  FRAME "
.Lexc:    .asciz "EXCEPTION"
.Lneogeo: .ascii "NEO-GEO"
        .balign 2
