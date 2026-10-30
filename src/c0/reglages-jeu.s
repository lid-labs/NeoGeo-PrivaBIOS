| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| GAME SETTINGS — the cartridge's soft-DIPs, set during the game, from the in-game menu
| (`menu.s`). On 2026-10-23.
|
| NO ORACLE: no BIOS's settings menu is read. "measured": a named record; "read in": a page of
| the NeoGeo Development Wiki; "ASSUMED": neither.
|
| THE ENGINE IS THAT OF THE BOOT EDITOR (`dip.s`): the block pointer (`_dip_bloc`, the current
| region), the settings table (`_dip_table`: time, count, number of times, multiple choice), the
| step of a value (`_dip_pas_valeur`), the defaults (`_dip_defauts`), the text of a value
| (`_dip_valeur`). Neither the region nor the mode is here: they stay at boot.
| DEPARTURE FROM THE BOOT EDITOR: a block in the banked area ($200000-$2FFFFF) is refused here.
| At boot it is read in the bank in place; during a game, the game may have switched bank, and
| the table read would be that of another piece of its ROM — wrong bounds, hence out-of-bounds
| values written into GAME_DIP. ASSUMED: no game of the corpus shows it, for want of having
| measured one. The values received are not made valid on entry (the boot editor does it): a
| value the player does not touch stays the one the game sees.
|
| THE LABELS IN THE JAPAN REGION, on 2026-10-27 (DECISIONS §19). The Japanese block encodes its
| labels outside ASCII, and the screen rendered them as spaces. The Japanese SNK BIOS writes them
| at $300/$400 + byte under the board's font; MEASURED (`measured/2026-10-27-intitules-japon.tsv`,
| section 3): the S ROM of five cartridges has none of these glyphs at those tiles, and REG_BRDFIX
| would cut off the game's M1 (`menu.s`). DEPARTURE SPECIFIC TO REBIOS: in the JAPAN region, the
| labels (those of the settings and those of the choices) come from the cartridge's USA block
| (pointer $11A, "68k program header"), at the same place in its block, if its structure is that
| of the Japanese block: bytes $10-$15 equal (time, count, number of times), and for $16-$1F the
| number of choices (low nibble) alone. The high nibble, the default, does not enter the
| comparison: the table, the values and the saving remain those of the Japanese block, and a
| default does not change the place of a label; MEASURED (same record, section 4): 25 games of
| the catalogue differ only in their defaults. USA block null, outside the fixed P-ROM (refused
| like the Japanese block here), or of different structure: the Japanese block's labels, as
| spaces, as before. ASSUMED: that a same structure means the same settings in the same order;
| seen on screen on ssideki alone (scene gs-japon).
|
| WHEN THE EFFECT IS TAKEN. Each step writes BIOS_GAME_DIP ($10FD84-$10FD93, "BIOS RAM
| locations") at once. The game takes it when it reads it again. Measured under MAME 0.286 on
| 2026-10-23 (read tap on $10FD84-$10FD93, the game's reads only: PC < $C00000, read and not
| logged; coin at 400, START at 500, 9,000 frames; `measured/2026-10-23-menu-en-jeu-complet.tsv`,
| section 1): six games out of six read bytes again DURING THE GAME, some at every frame (aof
| byte 13, kof98 11, mslug 7 and 13, puzzledp 6, 8, 9, samsho2 7 and 14), others at one moment
| of the game (aof byte 4, ROUND TIME, at the start of each round: frames 1897 and 4191); others
| still are only read at the title or the demo (aof 6, 8, 11; puzzledp 5, CONTINUE), or at request 0
| (kof98, all sixteen, frames 186-187). Hence the help line "SOME CHANGES NEED RESTART", and the
| RESTART GAME line: it saves and restarts, and the boot reads the block again (`_relire_dip`).
|
| THE SAVING, as at boot: GAME_DIP copied into the game's block, $D00220 + 16 × index, the index
| being that of the entry of the slot served ($D00124 + 4 × $D00108, + 2; `c0.s`). On return
| (START) and before RESTART GAME, if a value has changed; an index outside 0-7: nothing
| written. REG_SRAMUNLOCK then REG_SRAMLOCK: the backup RAM is locked at the call, `_io_commun`
| closing it again before the menu hook (`io.s`).
|
| THE SCREEN, the frame of the menu's sub-screens (28 × 14, `menu.s`), the cartridge's font:
|   0  —
|   1  GAME SETTINGS (title)
|   3-10  eight lines of the list, which scrolls: ">", the label (12 characters from the
|         cartridge, column 2), the value (column 15); the chosen line under the choice palette
|   12 SOME CHANGES NEED RESTART
|   13 L/R/A:CHANGE START:BACK
| The list: the cartridge's settings, RESET TO DEFAULTS, RESTART GAME; without a block (refused,
| or null), NO SOFT DIP DATA in place of the settings.
|
| THE CONTROLS, P1 on edge, like the boot editor: up/down the line, wrapping;
| right/left the value, bounded; A the next one, wrapping. On RESET TO DEFAULTS, right,
| left or A restore the defaults; on RESTART GAME, they save and restart. START:
| saves and hands back to the menu.
| ==================================================================================

        .section .haut, "ax"
        .global _reglages_jeu_ecran

        .equ    GAME_DIP,  0x10FD84
        .equ    SRAMUNLOCK, 0x3A001D
        .equ    SRAMLOCK,  0x3A000D
        | Under the menu's stack, in its area measured free (`menu.s`).
        .equ    GS_N,      0x10F900     | .w lines of the list
        .equ    GS_CHOIX,  0x10F902     | .w the chosen line
        .equ    GS_HAUT,   0x10F904     | .w the first line displayed
        .equ    GS_CHANGE, 0x10F906     | .w non-zero: a value has changed
        .equ    GS_TABLE,  0x10F908     | N_MAX × T_ENTREE → $10F9D4
        .equ    T_ENTREE,  12           | the format of `dip.s`
        .equ    N_MAX,     17           | 2 times + 2 counts + 10 multiple-choice + the reset + the restart
        .equ    VISIBLES,  8
        .equ    L_LISTE,   3            | the frame line of the first line displayed
        | Kinds, those of `dip.s` (0 time, 1 count, 2 number of times, 3 multiple choice, 4 reset), and:
        .equ    G_SANS,    9            | NO SOFT DIP DATA
        .equ    G_RELANCE, 10           | RESTART GAME

_reglages_jeu_ecran:
        bsr     _mn_sous_ouvrir
        lea     GAME_DIP, %a5
        bsr     _dip_bloc               | %a3: the soft-DIP block, 0 if refused
        cmpa.l  #0x100000, %a3
        bcs.s   1f
        suba.l  %a3, %a3                | the banked area: refused (see the header)
1:      lea     GS_TABLE, %a4
        movea.l %a4, %a2
        moveq   #0, %d6
        move.l  %a3, %d0
        bne.s   2f
        move.b  #G_SANS, (%a2)
        clr.b   1(%a2)
        move.l  #.Ltxt_sans, 6(%a2)
        lea     T_ENTREE(%a2), %a2
        addq.w  #1, %d6
        bra.s   3f
4:      bsr     .Lusa                   | in the JAPAN region: the USA block's labels
        bra.s   3f
| THE CYCLES. RESTART GAME restarts through the watchdog, and the frame of the RESET follows to
| within a few cycles those of the opening of this screen: 26 more cycles moved it one frame
| earlier on ncombat (scene gs-mmss), 60 on puzzledp (gs-fois), measured on 2026-10-27. Outside
| Japan, the test (tst.b 16, beq.s not taken 8, nop 4: 28) is therefore given back further down,
| identically: two bytes of the entry set with a single word (16 fewer) and two RAM words
| cleared with a single long (12).
2:      bsr     _dip_table
        tst.b   0x10FD83                | BIOS_COUNTRY_CODE: 0, JAPAN
        beq.s   4b
        nop
3:      move.w  #0x0400, (%a2)          | kind 4, the reset; byte 1 at zero
        move.l  #.Ltxt_defaut, 6(%a2)
        lea     T_ENTREE(%a2), %a2
        addq.w  #1, %d6
        move.b  #G_RELANCE, (%a2)
        clr.b   1(%a2)
        move.l  #.Ltxt_relance, 6(%a2)
        addq.w  #1, %d6
        move.w  %d6, GS_N
        clr.w   GS_CHOIX
        clr.l   GS_HAUT                 | GS_HAUT and GS_CHANGE
        bsr     .Ltout

| THE LOOP, one frame per turn, one action per frame, START first.
.Lboucle:
        bsr     _mn_sync
        bsr     _mn_entrees
        btst    #8, %d0
        bne.s   .Lsortie
        move.w  GS_CHOIX, %d1
        btst    #0, %d0                 | up
        beq.s   2f
        subq.w  #1, %d1
        bpl.s   1f
        move.w  GS_N, %d1
        subq.w  #1, %d1
1:      move.w  %d1, GS_CHOIX
        bsr     .Ltout
        bra.s   .Lboucle
2:      btst    #1, %d0                 | down
        beq.s   2f
        addq.w  #1, %d1
        cmp.w   GS_N, %d1
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
        bsr.s   .Lenregistrer
        rts

| THE CHOSEN LINE CHANGED, %d2 the direction. Clobbers %d0-%d4, %d6, %a2, %a4.
.Lchanger:
        move.w  GS_CHOIX, %d0
        mulu    #T_ENTREE, %d0
        lea     GS_TABLE, %a2
        adda.w  %d0, %a2
        move.b  (%a2), %d0
        cmpi.b  #4, %d0
        bcs.s   1f
        beq.s   2f
        cmpi.b  #G_RELANCE, %d0
        bne.s   9f
        bsr.s   .Lenregistrer           | RESTART GAME: saved, then the watchdog
        bra     _mn_relancer
1:      bsr     _dip_pas_valeur         | a setting: GAME_DIP at once
        bra.s   3f
2:      lea     GS_TABLE, %a4           | RESET TO DEFAULTS
        move.w  GS_N, %d6
        bsr     _dip_defauts
3:      move.w  #1, GS_CHANGE
        bra.s   .Ltout
9:      rts

| GAME_DIP INTO THE GAME'S BLOCK (see the header), if a value has changed. Clobbers %d1, %a0, %a1.
.Lenregistrer:
        tst.w   GS_CHANGE
        beq.s   9f
        moveq   #0, %d1
        move.b  0xD00108, %d1           | the slot served
        andi.w  #7, %d1
        lsl.w   #2, %d1
        lea     0xD00124, %a0
        move.w  2(%a0,%d1.w), %d1       | the index of its block
        cmpi.w  #7, %d1
        bhi.s   9f
        lsl.w   #4, %d1
        lea     0xD00220, %a1
        adda.w  %d1, %a1
        lea     GAME_DIP, %a0
        move.b  %d0, SRAMUNLOCK
        move.l  (%a0)+, (%a1)+
        move.l  (%a0)+, (%a1)+
        move.l  (%a0)+, (%a1)+
        move.l  (%a0)+, (%a1)+
        move.b  %d0, SRAMLOCK
        clr.w   GS_CHANGE
9:      rts

| ----------------------------------------------------------------------------------
| THE WHOLE SCREEN: the list window realigned on the chosen line, then the 14 lines of the
| frame. Clobbers %d0-%d4, %d6, %a0-%a3.
.Ltout:
        move.w  GS_CHOIX, %d0
        move.w  GS_HAUT, %d1
        cmp.w   %d1, %d0
        bcc.s   1f
        move.w  %d0, %d1                | above the window
1:      move.w  %d1, %d2
        addq.w  #VISIBLES, %d2
        cmp.w   %d2, %d0
        bcs.s   2f
        move.w  %d0, %d1                | below
        subq.w  #VISIBLES - 1, %d1
2:      move.w  %d1, GS_HAUT
        moveq   #0, %d4                 | the frame line
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
        cmpi.w  #VISIBLES, %d0
        bcc.s   .Lt_ecrire
        add.w   GS_HAUT, %d0            | the entry of this line
        cmp.w   GS_N, %d0
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

| ENTRY %d0 into MN_BUF: ">" and the choice palette if it is chosen, the label, the
| value. Clobbers %d0-%d4, %a0-%a3.
.Lentree:
        move.w  %d0, %d1
        mulu    #T_ENTREE, %d1
        lea     GS_TABLE, %a2
        adda.w  %d1, %a2
        cmp.w   GS_CHOIX, %d0
        bne.s   2f
        move.b  #0x3E, MN_BUF + 1       | ">"
        lea     MN_COUL, %a0
        moveq   #28 - 1, %d1
1:      move.b  #2, (%a0)+
        dbra    %d1, 1b
2:      moveq   #12, %d4                | the label
        move.b  (%a2), %d0
        cmpi.b  #4, %d0
        bne.s   1f
        moveq   #L_DEFAUT, %d4
1:      cmpi.b  #G_SANS, %d0
        bne.s   1f
        moveq   #L_SANS, %d4
1:      movea.l 6(%a2), %a3
        lea     MN_BUF + 2, %a1
        bsr     _dip_copier
        cmpi.b  #4, (%a2)
        bcc.s   9f
        lea     MN_BUF + 15, %a1        | the value
        bsr     _dip_valeur
9:      rts

| ----------------------------------------------------------------------------------
| THE BORROWING FROM THE USA BLOCK (see the header, THE LABELS IN THE JAPAN REGION), in the JAPAN
| region only (the test is in the caller). %a3: the Japanese block,
| non-null, below $100000; %a4 to %a2: the entries `_dip_table` has just filled. USA block
| refused, or of different structure: nothing changes. Clobbers %d0-%d3, %a0, %a1.
.Lusa:
        move.l  0x11A, %d0              | the USA block's pointer ("68k program header")
        beq.s   9f
        cmpi.l  #0x100000 - 0x20, %d0
        bhi.s   9f                      | outside the fixed P-ROM: refused, like the Japanese block here
        movea.l %d0, %a0
        moveq   #0x10, %d1              | the structure, bytes $10-$1F
1:      move.b  (%a3,%d1.w), %d2
        move.b  (%a0,%d1.w), %d3
        cmpi.w  #0x16, %d1
        bcs.s   2f
        andi.b  #0x0F, %d2              | a multiple-choice setting: its number of choices alone,
        andi.b  #0x0F, %d3              | the default (high nibble) stays Japan's
2:      cmp.b   %d2, %d3
        bne.s   9f
        addq.w  #1, %d1
        cmpi.w  #0x20, %d1
        bcs.s   1b
        sub.l   %a3, %d0                | from the Japanese block to the USA block
        movea.l %a4, %a1
3:      cmpa.l  %a2, %a1
        bhs.s   9f
        add.l   %d0, 6(%a1)             | kinds 0 to 3: the label, at the same place in the USA block
        lea     T_ENTREE(%a1), %a1
        bra.s   3b
9:      rts

| ----------------------------------------------------------------------------------
| THE DATA.
        .balign 2
.Ltxt_titre:
        .ascii  "GAME SETTINGS"
        .equ    L_TITRE, . - .Ltxt_titre
.Ltxt_sans:
        .ascii  "NO SOFT DIP DATA"
        .equ    L_SANS, . - .Ltxt_sans
.Ltxt_defaut:
        .ascii  "RESET TO DEFAULTS"
        .equ    L_DEFAUT, . - .Ltxt_defaut
.Ltxt_relance:
        .ascii  "RESTART GAME"           | 12 characters, like a label
.Ltxt_aide1:
        .ascii  "SOME CHANGES NEED RESTART"
        .equ    L_AIDE1, . - .Ltxt_aide1
.Ltxt_aide2:
        .ascii  "L/R/A:CHANGE START:BACK"
        .equ    L_AIDE2, . - .Ltxt_aide2
        .balign 2
