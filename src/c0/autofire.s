| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| AUTOFIRE — set game by game in the in-game menu (`menu.s`, AUTOFIRE line), kept in backup RAM
| per game, applied by SYSTEM_IO (`io.s`, `_io_commun`). On 2026-10-27 (DECISIONS §22).
|
| NO ORACLE: no known Neo Geo BIOS has an autofire, and none is read. "measured": a named
| record; "read in": a page of the NeoGeo Development Wiki; "ASSUMED": neither one nor
| the other.
|
| WHAT THE GAME SEES. The turbo applies to the inputs that SYSTEM_IO stores in RAM (BIOS_P1CURRENT
| and the following ones, "BIOS RAM locations"): a game that reads REG_P1CNT itself does not see
| it. MEASURED on 2026-10-27 (prototype outside the repository, P1's A, 164 games, one scripted
| session each; `measured/2026-10-27-autofire.tsv`, readable list: `docs/AUTOFIRE.md`).
|
| THE SETTING, one byte: bits 4 to 7 the buttons A, B, C, D (the bits of REG_P1CNT), bits 0 and 1
| the rate — 0: 10 shots/s (6 frames: 3 pressed, 3 released), 1: 15 (2 and 2), 2: 30 (1 and 1),
| at 60 calls of SYSTEM_IO per second; 3 counts as 1. Default, DEFAUT: no button, 15 shots/s. P1
| and P2 follow the same setting, each with its own phase (`io.s`).
|
| IN RAM, $10FB40-$10FB51, in the BIOS area measured free ($10F4B4-$10FBFF: no game write,
| 22 games, `measured/2026-10-21-ecrivains-ram-bios.tsv`; and $10FB40-$10FB41 reread
| unchanged during the 158 sessions of the autofire measurement). Cleared at boot (`c0.s`): tables
| at zero, inputs unchanged.
|   AF_REGLAGE  .b the setting of the served game
|   AF_MASQUE   .b its buttons (bits 4-7)
|   AF_PH1/2    .b the phase of P1, of P2: 0 to P − 1
|   AF_REL      6 .b, per phase: the buttons seen released (the mask at phases ≥ P/2, 0 before)
|   AF_SUIV     6 .b, per phase: the next phase (k + 1, 0 after P − 1), 8 bytes further on
|
| IN BACKUP RAM, $D001B0-$D0020F, ours. Read in "Backup RAM": $D001A8-$D0021F is not
| documented there. MEASURED (`reglages.s`, header): no write, neither from the game nor from the
| BIOS, in $D00150-$D0021F, 21 games; none of the 22 games of
| `measured/2026-10-22-bram-lue-par-les-jeux.tsv` reads there. $D00144-$D001A3 is left alone: the
| reference stores slot dates there (`c0.s`).
|   $D001B0-$D001B3  "AUTF", the signature; absent, the table is empty
|   $D001B4-$D0020F  23 records of 4 bytes, the most recently set first: NGH (.w), setting
|                    (.b), check (.b) such that the sum of the four bytes is $FF. A record
|                    whose sum is not $FF is free (a record at zero is).
| A game at the default setting has no record. Beyond 23 games, the record of the game set
| least recently is lost. ASSUMED: that no other BIOS run on the same NVRAM writes there;
| a damaged record then only counts for one game, and the signature resets the table to empty.
|
| THE GAME is its NGH, that of the served slot's entry in the slot table ($D00124 + 4 ×
| $D00108, "Backup RAM"), which the boot detection writes there from the cartridge header: the
| same NGH as the cheats' one ($000108), without reading the cartridge, hence without concern for
| REG_CRTFIX (DECISIONS §13). NGH $0000 (empty slot): no record, the default setting.
|
| THE LOADING, `_af_charger`, at each hand-over to the game (`c0.s`, with `_commutateurs`):
| boot, SYSTEM_RETURN, slot switch, coin outside a game. Before the wait for line $1F0 of the
| hand-over: its cycles do not change its instant.
| ==================================================================================

        .section .haut, "ax"
        .global _af_charger
        .global _af_ecran

        .equ    AF_REGLAGE, 0x10FB40
        .equ    AF_MASQUE, 0x10FB41
        .equ    AF_PH1,    0x10FB42
        .equ    AF_PH2,    0x10FB43
        .equ    AF_REL,    0x10FB44     | 6 bytes
        .equ    AF_SUIV,   0x10FB4C     | 6 bytes, AF_REL + 8 (`io.s`)
        .equ    DEFAUT,    0x01         | no button, 15 shots/s
        .equ    TABLE,     0xD001B0
        .equ    FICHES,    0xD001B4
        .equ    NFICHES,   23
        .equ    SRAMUNLOCK, 0x3A001D
        .equ    SRAMLOCK,  0x3A000D
        | The screen, under the menu's stack, like GAME SETTINGS (a single sub-screen at a time).
        .equ    AF_CHOIX,  0x10F900     | .w the chosen line, 0-3 the buttons, 4 the rate
        .equ    AF_CHANGE, 0x10F902     | .w non-zero: the setting has changed
        .equ    NLIGNES,   5
        .equ    L_LISTE,   3

| ----------------------------------------------------------------------------------
| THE LOADING (see the header). Returns all registers.
_af_charger:
        movem.l %d0-%d3/%a0, -(%sp)
        bsr.s   .Lngh
        bsr     .Lchercher
        moveq   #DEFAUT, %d0
        cmpa.w  #0, %a0
        beq.s   1f
        move.b  2(%a0), %d0
1:      bsr.s   .Lappliquer
        movem.l (%sp)+, %d0-%d3/%a0
        rts

| THE NGH OF THE SERVED GAME, in %d1.w (0: none). Clobbers %d0, %a0.
.Lngh:
        moveq   #0, %d0
        move.b  0xD00108, %d0
        andi.w  #7, %d0
        lsl.w   #2, %d0
        lea     0xD00124, %a0
        move.w  (%a0,%d0.w), %d1
        rts

| THE SETTING %d0.b IN RAM: setting, mask, tables, phases at 0. Clobbers %d0-%d3, %a0.
.Lappliquer:
        move.b  %d0, AF_REGLAGE
        move.b  %d0, %d2
        andi.b  #0xF0, %d2              | %d2: the mask
        move.b  %d2, AF_MASQUE
        andi.w  #3, %d0
        move.b  .Lperiodes(%pc,%d0.w), %d0  | %d0: the period P
        lea     AF_REL, %a0
        moveq   #0, %d1                 | %d1: the phase k
1:      moveq   #0, %d3
        move.b  %d0, %d3
        lsr.b   #1, %d3                 | P/2
        clr.b   (%a0)
        cmp.b   %d3, %d1
        bcs.s   2f
        cmp.b   %d0, %d1
        bcc.s   2f
        move.b  %d2, (%a0)              | P/2 ≤ k < P: released
2:      move.b  %d1, %d3
        addq.b  #1, %d3
        cmp.b   %d0, %d3
        bcs.s   3f
        moveq   #0, %d3                 | after P − 1, or outside the period: 0
3:      move.b  %d3, AF_SUIV-AF_REL(%a0)
        addq.l  #1, %a0
        addq.b  #1, %d1
        cmpi.b  #6, %d1
        bcs.s   1b
        clr.w   AF_PH1                  | AF_PH1 and AF_PH2
        rts
.Lperiodes: .byte 6, 4, 2, 4             | 10, 15, 30 shots/s; 3 counts as 15

| THE RECORD OF NGH %d1.w in %a0, 0 if none (table without signature, zero NGH, or absent).
| Clobbers %d0, %d2, %a0.
.Lchercher:
        tst.w   %d1
        beq.s   8f
        cmpi.l  #0x41555446, TABLE      | "AUTF"
        bne.s   8f
        lea     FICHES, %a0
        moveq   #NFICHES - 1, %d2
1:      cmp.w   (%a0), %d1
        bne.s   2f
        bsr.s   .Lsomme
        cmpi.b  #0xFF, %d0
        beq.s   9f
2:      addq.l  #4, %a0
        dbra    %d2, 1b
8:      suba.l  %a0, %a0
9:      rts

| The sum of the four bytes of record %a0, in %d0.b. Clobbers %d0.
.Lsomme:
        move.b  (%a0), %d0
        add.b   1(%a0), %d0
        add.b   2(%a0), %d0
        add.b   3(%a0), %d0
        rts

| THE SAVING of setting %d0.b for NGH %d1.w (non-zero): its record removed, then, if it is not
| the default, a new record at the head. The backup RAM is unlocked for the time of the write
| (locked on call: `io.s` closes it again before the menu hook). Clobbers %d0-%d3, %a0, %a1.
.Lenregistrer:
        move.b  %d0, %d3                | %d3: the setting
        move.b  %d0, SRAMUNLOCK
        cmpi.l  #0x41555446, TABLE
        beq.s   1f
        move.l  #0x41555446, TABLE      | new table: signature, free records
        lea     FICHES, %a0
        moveq   #NFICHES - 1, %d2
2:      clr.l   (%a0)+
        dbra    %d2, 2b
1:      bsr.s   .Lchercher
        cmpa.w  #0, %a0
        beq.s   3f
        | Removed: the following records move up one place, the last one is freed.
        lea     FICHES + 4 * NFICHES, %a1
4:      lea     4(%a0), %a0
        cmpa.l  %a1, %a0
        bcc.s   5f
        move.l  (%a0), -4(%a0)
        bra.s   4b
5:      clr.l   -4(%a1)
3:      cmpi.b  #DEFAUT, %d3
        beq.s   9f
        | At the head: the first 22 move down one place, the 23rd is lost.
        lea     FICHES + 4 * NFICHES, %a0
        lea     FICHES + 4 * (NFICHES - 1), %a1
        moveq   #NFICHES - 2, %d2
6:      move.l  -(%a1), -(%a0)
        dbra    %d2, 6b
        lea     FICHES, %a0
        move.w  %d1, (%a0)
        move.b  %d3, 2(%a0)
        moveq   #-1, %d0                | the check: $FF − (NGH high + NGH low + setting)
        sub.b   (%a0), %d0
        sub.b   1(%a0), %d0
        sub.b   %d3, %d0
        move.b  %d0, 3(%a0)
9:      move.b  %d0, SRAMLOCK
        rts

| ----------------------------------------------------------------------------------
| THE AUTOFIRE SCREEN, a sub-screen of the in-game menu, called by `menu.s` (which closes it). The
| frame of the sub-screens (28 × 14, `menu.s`), the cartridge's font:
|   1  AUTOFIRE (title)
|   3-6  BUTTON A … BUTTON D, OFF or ON (column 15)
|   7  RATE, 10/S, 15/S or 30/S
|   12 P1+P2, SAVED FOR THIS GAME
|   13 L/R/A:CHANGE START:BACK
| THE CONTROLS, P1 on edge, like GAME SETTINGS: up/down the line, wrapping; right ON or
| the rate above, left OFF or the rate below, bounded; A toggles, or the next rate,
| wrapping. Each change takes effect at once (RAM); START saves it if there was
| one, and returns control to the menu.
_af_ecran:
        bsr     _mn_sous_ouvrir
        clr.l   AF_CHOIX                | AF_CHOIX and AF_CHANGE
        bsr     .Ltout
.Lboucle:
        bsr     _mn_sync
        bsr     _mn_entrees
        btst    #8, %d0
        bne.s   .Lsortie
        move.w  AF_CHOIX, %d1
        btst    #0, %d0                 | up
        beq.s   2f
        subq.w  #1, %d1
        bpl.s   1f
        moveq   #NLIGNES - 1, %d1
1:      move.w  %d1, AF_CHOIX
        bsr     .Ltout
        bra.s   .Lboucle
2:      btst    #1, %d0                 | down
        beq.s   2f
        addq.w  #1, %d1
        cmpi.w  #NLIGNES, %d1
        bcs.s   1b
        moveq   #0, %d1
        bra.s   1b
2:      moveq   #1, %d2                 | right
        btst    #3, %d0
        bne.s   3f
        moveq   #-1, %d2                | left
        btst    #2, %d0
        bne.s   3f
        moveq   #2, %d2                 | A
        btst    #4, %d0
        beq.s   .Lboucle
3:      bsr.s   .Lchanger
        bra.s   .Lboucle

.Lsortie:
        tst.w   AF_CHANGE
        beq.s   9f
        bsr     .Lngh
        tst.w   %d1
        beq.s   9f                      | no game: nothing saved
        moveq   #0, %d0
        move.b  AF_REGLAGE, %d0
        bsr     .Lenregistrer
9:      rts

| THE CHOSEN LINE CHANGED, %d2 the direction (1 right, −1 left, 2 A). Clobbers %d0-%d4, %d6, %a0-%a3.
.Lchanger:
        move.b  AF_REGLAGE, %d0
        move.w  AF_CHOIX, %d1
        cmpi.w  #4, %d1
        beq.s   5f
        addq.w  #4, %d1                 | the button's bit
        cmpi.w  #2, %d2
        bne.s   1f
        bchg    %d1, %d0                | A: toggle
        bra.s   8f
1:      tst.w   %d2
        bmi.s   2f
        bset    %d1, %d0                | right: ON
        bra.s   8f
2:      bclr    %d1, %d0                | left: OFF
        bra.s   8f
5:      move.b  %d0, %d1                | the rate, 0 to 2 (3 counts as 1)
        andi.b  #3, %d1
        cmpi.b  #3, %d1
        bne.s   1f
        moveq   #1, %d1
1:      cmpi.w  #2, %d2
        bne.s   2f
        addq.b  #1, %d1                 | A: the next one, wrapping
        cmpi.b  #3, %d1
        bcs.s   4f
        moveq   #0, %d1
        bra.s   4f
2:      add.b   %d2, %d1                | right, left: bounded to 0-2
        bpl.s   3f
        moveq   #0, %d1
3:      cmpi.b  #2, %d1
        bls.s   4f
        moveq   #2, %d1
4:      andi.b  #0xF0, %d0
        or.b    %d1, %d0
8:      cmp.b   AF_REGLAGE, %d0
        beq.s   9f
        bsr     .Lappliquer
        move.w  #1, AF_CHANGE
        bra.s   .Ltout
9:      rts

| ----------------------------------------------------------------------------------
| THE WHOLE SCREEN: the 14 lines of the frame. Clobbers %d0-%d4, %d6, %a0-%a3.
.Ltout:
        moveq   #0, %d4
.Lt_ligne:
        bsr     _mn_vider
        cmpi.w  #1, %d4
        bne.s   1f
        lea     .Ltxt_titre, %a3
        moveq   #L_TITRE, %d4
        moveq   #(28 - L_TITRE) / 2, %d0
        moveq   #1, %d1                 | the title
        bsr     _mn_texte
        moveq   #1, %d4
        bra.s   .Lt_ecrire
1:      cmpi.w  #12, %d4
        bne.s   1f
        lea     .Ltxt_aide1, %a3
        moveq   #L_AIDE1, %d4
        moveq   #1, %d0
        moveq   #0, %d1
        bsr     _mn_texte
        moveq   #12, %d4
        bra.s   .Lt_ecrire
1:      cmpi.w  #13, %d4
        bne.s   1f
        lea     .Ltxt_aide2, %a3
        moveq   #L_AIDE2, %d4
        moveq   #2, %d0
        moveq   #0, %d1
        bsr     _mn_texte
        moveq   #13, %d4
        bra.s   .Lt_ecrire
1:      move.w  %d4, %d0
        subq.w  #L_LISTE, %d0
        bcs.s   .Lt_ecrire
        cmpi.w  #NLIGNES, %d0
        bcc.s   .Lt_ecrire
        move.w  %d4, -(%sp)
        bsr.s   .Lentree
        move.w  (%sp)+, %d4
.Lt_ecrire:
        bsr     _mn_ligne
        addq.w  #1, %d4
        cmpi.w  #14, %d4
        bcs     .Lt_ligne
        rts

| LINE %d0 of the list in MN_BUF: ">" and the choice's palette if it is chosen,
| the label (column 2), the value (column 15). Clobbers %d0-%d2, %a0-%a3.
.Lentree:
        cmp.w   AF_CHOIX, %d0
        bne.s   2f
        move.b  #0x3E, MN_BUF + 1       | ">"
        lea     MN_COUL, %a0
        moveq   #28 - 1, %d1
1:      move.b  #2, (%a0)+
        dbra    %d1, 1b
2:      lea     MN_BUF + 2, %a1
        lea     MN_BUF + 15, %a2
        move.b  AF_REGLAGE, %d2
        cmpi.w  #4, %d0
        beq.s   5f
        lea     .Ltxt_bouton, %a3       | "BUTTON" and the letter
        moveq   #7 - 1, %d1
3:      move.b  (%a3)+, (%a1)+
        dbra    %d1, 3b
        moveq   #0x41, %d1              | A, B, C, D
        add.b   %d0, %d1
        move.b  %d1, (%a1)
        lea     .Ltxt_off, %a3
        addq.w  #4, %d0
        btst    %d0, %d2
        beq.s   4f
        lea     .Ltxt_on, %a3
        bra.s   4f
5:      lea     .Ltxt_cadence, %a3
        moveq   #4 - 1, %d1
3:      move.b  (%a3)+, (%a1)+
        dbra    %d1, 3b
        andi.w  #3, %d2
        cmpi.w  #3, %d2
        bne.s   6f
        moveq   #1, %d2
6:      lea     .Ltxt_cadences, %a3
        lsl.w   #2, %d2
        adda.w  %d2, %a3
4:      move.b  (%a3)+, (%a2)+          | three or four characters, the space included
        move.b  (%a3)+, (%a2)+
        move.b  (%a3)+, (%a2)+
        move.b  (%a3)+, (%a2)+
        rts

| ----------------------------------------------------------------------------------
| THE DATA.
        .balign 2
.Ltxt_titre:
        .ascii  "AUTOFIRE"
        .equ    L_TITRE, . - .Ltxt_titre
.Ltxt_bouton:
        .ascii  "BUTTON "
.Ltxt_cadence:
        .ascii  "RATE"
.Ltxt_on:
        .ascii  "ON  "
.Ltxt_off:
        .ascii  "OFF "
.Ltxt_cadences:                         | in the order of the codes: 0, 1, 2
        .ascii  "10/S15/S30/S"
.Ltxt_aide1:
        .ascii  "P1+P2, SAVED FOR THIS GAME"
        .equ    L_AIDE1, . - .Ltxt_aide1
.Ltxt_aide2:
        .ascii  "L/R/A:CHANGE START:BACK"
        .equ    L_AIDE2, . - .Ltxt_aide2
        .balign 2
