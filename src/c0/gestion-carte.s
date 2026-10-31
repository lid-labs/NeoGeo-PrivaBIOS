| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| THE MEMORY CARD MANAGER — opened from the TEST screen (`dip.s`, MEMORY CARD line), by the mark
| of RESTART TO CARD (`menu.s`), or without a cartridge from HARDWARE TESTS (`tests.s`; DECISIONS
| §33): the list of the card's saves, the free blocks, deleting a save and formatting, each with a
| confirmation.
|
| NO ORACLE: neither another BIOS's manager nor a game's code is read. Written under the
| mandate of memory card batch 2, on 2026-10-24; scenes cm-* and bf-carte of `bench/parcours.sh`.
| "measured": a named record; "read in": a page of the NeoGeo Development Wiki;
| "ASSUMED": neither one nor the other.
|
| CALL: `jsr _gestion_carte` from `dip.s` or `tests.s`. All registers returned. The state at the call is
| that of the TEST screen: REG_BRDFIX (the board's font), palettes 1-4 of the caller in
| bank 0, IRQs masked, backup RAM unlocked. On return, the same, palette 5 at zero
| (like `jukebox.s`); the caller redraws its screen.
|
| WHAT IS READ, and what is not. The card through `card.s`: `_carte_releve` for the list
| (no write), CARD itself to delete ($04) and format ($00), through the interface that
| games use ("CARD": BIOS_CARD_COMMAND $10FDC4, BIOS_CARD_FCB $10FDCE, BIOS_CARD_SUB
| $10FDD0, the answer at $10FDC6). Nothing from the cartridge: under REG_BRDFIX, the P-ROM does
| not answer on the hardware (DECISIONS §13). THE GAME'S NAME therefore comes from backup RAM: the
| slot table ($D00124, NGH and block of each slot) and the name the boot copies there on the first
| launch of each game ($D002A0 + 16 × block, `c0.s`, `_inscrire_slot`). A save whose NGH is
| that of no registered game has no name; nor does a cartridge never launched on this board.
|
| THE LIST, one line per entry taken from the card's directory (its first byte is not
| $FF, read in "Memory card"), in directory order: the NGH in hexadecimal, the
| sub-save in decimal, the number of blocks of its chain in FAT 1, the name. Then two
| lines: FORMAT CARD and EXIT. Thirteen visible lines; the list scrolls with the cursor.
| THE FREE BLOCKS: the $00 entries of FAT 1, blocks 5 to 31 (blocks 0 to 4 hold
| the header, the directory and the FATs: 27 data blocks on a 2 KiB card).
| THE STATES, one line: NO CARD, CARD NOT FORMATTED, UNSUPPORTED CARD (another geometry,
| which CARD refuses too), or FREE BLOCKS; and WRITE PROTECTED below when bit 6 of
| REG_STATUS_B says so, card present (read in "Memory card").
| THE CARD CHANGED during the screen: REG_STATUS_B (bits 4-6) read again every frame; a change
| reads the card again and redraws everything.
|
| THE CONTROLS, P1, on edge (REG_P1CNT, REG_STATUS_B bit 0, active low). Up/down:
| the line, wrapping. A: on a save, DELETE ?; on FORMAT CARD, FORMAT ?; on EXIT, the
| exit. THE CONFIRMATION: A a second time acts, B or START cancel. START outside
| confirmation: the exit. Card protected, or no card: the message, nothing written.
|
| THE COPY, on 2026-10-27 (DECISIONS §26, the user's decision: one save at a
| time, like UniBIOS 4.0 without its COPY ALL). C on a save reads it through CARD ($02, the size of
| its chain: blocks × 64) into a buffer, then "CHANGE CARD AND PRESS A". A writes it through CARD ($03)
| onto the card in place; if that card already holds the same NGH and the same sub-save, "OVERWRITE
| nnnn-ss?" first, A writes, B or START cancel. B or START also cancel while waiting for the card.
| The card changed during the wait does not abandon it (that is the point), it redraws the list.
| Card protected or absent at the A: the message, the wait goes on. MEASURED on UniBIOS 4.0
| (`measured/2026-10-27-attentes-reference.tsv`): "DATA IS COPIED / CHANGE CARD AND PRESS A
| BUTTON", then "GAME IS ALREADY ON THIS CARD / DO YOU WANT TO DELETE OLD DATA ?".
| THE BUFFER'S ROOM: 27 blocks of 64 bytes at most, 1,728 bytes (a 2 KiB card, the only
| geometry served, `card.s`), when the manager's RAM has only 256 and that of the TEST screen
| ($10F464-$10FAFF) holds the copy of the soft-DIP block from `dip.s`. The buffer is therefore the
| game's work RAM, $100000-$10077F with the 192 bytes of COPY ALL, which the game does not use during
| the TEST screen; these 1,920 bytes are set aside in VRAM, $0000-$03BF (the tile map of sprites 0 to
| 14, hidden by LSP_1st at boot and never displayed by the TEST screen), before the read, and returned
| after the write or the cancel: the RAM the boot restored for the game comes out intact. VRAM writes at the pace of `tests.s`.
|
| COPY ALL, on 2026-10-31 (DECISIONS §33). D, on any line: the directory and FAT 1 kept after the
| buffer (COPIE_DIR), every save read through CARD ($02) one after the other into the buffer, then
| "CHANGE CARD AND PRESS A", the wait of the copy, states 5 and 6 of V_CONF. A reads the card in
| place again. Its directory and FAT equal to the kept ones: SAME CARD, nothing written, the wait goes
| on; that is what keeps the source from being written. Otherwise the saves are counted against
| the room, in CARD's order: SAVE wants its blocks free BEFORE it frees the old chain (`card.s`, $03),
| so a save needs its blocks at its turn, and gives back those it replaces after. Too few: NOT
| ENOUGH BLOCKS, nothing written, the wait goes on. Same NGH and sub-save on the target: "OVERWRITE
| nn SAVES?", A writes. The whole buffer holds what one card can hold; a FAT whose chains cross
| would add up to more than 27 blocks: CARD ERROR 83, like a FAT error.
|
| CARD'S INTERFACE is kept on entry and returned on exit ($10FCF4, $10FD00-$10FD17,
| $10FDC4-$10FDD1): a game does not find, at launch, the traces of a call it did not
| make. ASSUMED without effect; it is at zero at boot, the clearing in `c0.s` having put it there.
|
| THE RAM: $10F300-$10F3FF, above the BIOS stack (set at $10F300, it grows down) and below
| the save area of `plantage.s` ($10F400) — 192 bytes of the record, the kept interface, the
| variables; reset to zero on exit, as the boot had left it.
| ==================================================================================

        .section .haut, "ax"
        .global _gestion_carte

        .equ    VRAMADDR, 0x3C0000
        .equ    VRAMRW,   0x3C0002
        .equ    VRAMMOD,  0x3C0004
        .equ    LSPCMODE, 0x3C0006
        .equ    WATCHDOG, 0x300001
        .equ    STATUS_B, 0x380000
        .equ    PALETTES, 0x400000

        .equ    TAMPON,   0x10F300      | 192 bytes: the card from $40 to $FF
        .equ    T_FAT,    TAMPON + 0x80 | FAT 1 (byte $C0 of the card)
        .equ    GARDE,    0x10F3C0      | 39 bytes: CARD's interface
        .equ    V_N,      0x10F3E8      | .w the lines: saves + 2
        .equ    V_ETAT,   0x10F3EA      | .b the record: $00, $80, $81, $85
        .equ    V_STB,    0x10F3EB      | .b REG_STATUS_B & $70 at the record
        .equ    V_CONF,   0x10F3EC      | .b 0 nothing, 1 delete, 2 format, 3 copy read (the target
                                        | card awaited), 4 overwrite, 5 and 6 the same for COPY
                                        | ALL: waiting for A
        .equ    V_SUB,    0x10F3ED      | .b the copy: its sub-save
        .equ    V_NGH,    0x10F3EE      | .w its NGH
        .equ    V_TAILLE, 0x10F3F0      | .w its size in bytes
        .equ    V_ENTREE, 0x10F3F2      | .l COPY ALL: the next entry of COPIE_DIR
        .equ    V_PTR,    0x10F3F6      | .l COPY ALL: where the next save is in the buffer
        .equ    COPIE_RAM, 0x100000     | the copy's buffer (see the header, THE COPY)
        .equ    COPIE_DIR, COPIE_RAM + 27 * 64 | COPY ALL: directory ($80) and FAT 1 ($40) kept
        .equ    COPIE_MOTS, (27 * 64 + 192) / 2 | 960 words: a whole 2 KiB card, and that record
        .equ    START_C,  0x10FDC8      | BIOS_CARD_START
        .equ    SIZE_C,   0x10FDCC      | BIOS_CARD_SIZE
        .equ    RAM_FIN,  0x10F400

        .equ    CMD,      0x10FDC4      | BIOS_CARD_COMMAND
        .equ    REPONSE,  0x10FDC6      | BIOS_CARD_ANSWER
        .equ    FCB,      0x10FDCE      | BIOS_CARD_FCB, the NGH
        .equ    SUB,      0x10FDD0      | BIOS_CARD_SUB

        .equ    PAL_ALERTE, 5
        .equ    C_ALERTE, 0x0F44        | a choice of look, that of FAIL (`tests.s`)

        | The layout, in fix layer cells ($7000 + 32 × column + line).
        .equ    CASE_TITRE,  0x7000 + 14 * 32 + 3      | 8×16, lines 3-4
        .equ    CASE_ETAT,   0x7000 +  3 * 32 + 6
        .equ    CASE_PROT,   0x7000 +  3 * 32 + 7
        .equ    CASE_ENTETE, 0x7000 +  3 * 32 + 9
        .equ    LIGNE0,      10         | the first line of the list
        .equ    VISIBLES,    13         | lines 10 to 22
        .equ    CASE_MSG,    0x7000 +  3 * 32 + 24
        .equ    CASE_AIDE1,  0x7000 +  3 * 32 + 27
        .equ    CASE_AIDE2,  0x7000 +  3 * 32 + 28
        .equ    LARGEUR,     31

        .equ    F_LIGNE,  -32           | the frame: a composed line

| %a0: REG_VRAMRW; %d5: the buttons of the previous frame; %d6: the first visible line;
| %d7: the chosen line.
_gestion_carte:
        movem.l %d0-%d7/%a0-%a6, -(%sp)
        link    %a6, #F_LIGNE
        lea     GARDE, %a1              | CARD's interface, kept
        move.b  0x10FCF4, (%a1)+
        lea     0x10FD00, %a2
        moveq   #24 - 1, %d0
1:      move.b  (%a2)+, (%a1)+
        dbra    %d0, 1b
        lea     CMD, %a2
        moveq   #14 - 1, %d0
2:      move.b  (%a2)+, (%a1)+
        dbra    %d0, 2b
        lea     VRAMRW, %a0
        bsr     .Lreleve
        moveq   #0, %d7
        moveq   #0, %d6
        bsr     .Lecran
        moveq   #0, %d5
        bsr     .Lentrees               | a button already held (the A that opens) does not count

| THE LOOP, one frame per turn.
.Lboucle:
        bsr     .Lsync
        move.b  STATUS_B, %d0           | the card changed: read again, everything redrawn
        andi.b  #0x70, %d0
        cmp.b   V_STB, %d0
        beq.s   1f
        cmpi.b  #3, V_CONF              | the copy is precisely waiting for another card
        beq.s   5f
        cmpi.b  #5, V_CONF
        beq.s   5f
        cmpi.b  #3, V_CONF
        bcs.s   6f
        subq.b  #1, V_CONF              | overwrite targeted the old card: we wait for A again
        bra.s   5f
6:      clr.b   V_CONF                  | a confirmation targeted the old card: abandoned
5:      bsr     .Lreleve
        bsr     .Lborner
        bsr     .Lecran
        cmpi.b  #3, V_CONF              | 3 or 5 here
        bcs.s   1f
        lea     .Ltxt_changer, %a2
        bsr     .Lmessage
1:      bsr     .Lentrees               | %d0 the edges: 0 up, 1 down, 2 D, 4 A, 5 B, 6 START, 7 C
        tst.b   V_CONF
        bne     .Lconfirmer
        btst    #6, %d0
        bne     .Lsortie
        btst    #0, %d0                 | up
        beq.s   2f
        subq.w  #1, %d7
        bpl.s   3f
        move.w  V_N, %d7
        subq.w  #1, %d7
        bra.s   3f
2:      btst    #1, %d0                 | down
        beq.s   4f
        addq.w  #1, %d7
        cmp.w   V_N, %d7
        bcs.s   3f
        moveq   #0, %d7
3:      bsr     .Lborner
        bsr     .Lliste
        bra     .Lboucle
4:      btst    #7, %d0                 | C: copy the line's save
        bne     .Lcopier
        btst    #2, %d0                 | D: COPY ALL
        bne     .Lcopier_tout
        btst    #4, %d0                 | A
        beq     .Lboucle
        move.w  V_N, %d0
        subq.w  #1, %d0
        cmp.w   %d0, %d7
        beq     .Lsortie                | EXIT
        subq.w  #1, %d0
        cmp.w   %d0, %d7
        beq.s   .Lveut_formater
        | A save: DELETE ?
        btst    #6, STATUS_B
        bne.s   .Lprotegee
        move.b  #1, V_CONF
        bsr     .Lmsg_effacer
        bra     .Lboucle
.Lveut_formater:
        cmpi.b  #0x80, V_ETAT
        beq.s   .Lsans_carte
        btst    #6, STATUS_B
        bne.s   .Lprotegee
        move.b  #2, V_CONF
        lea     .Ltxt_formater, %a2
        bsr     .Lmessage
        bra     .Lboucle
.Lsans_carte:
        lea     .Ltxt_sans, %a2
        bsr     .Lmessage
        bra     .Lboucle
.Lprotegee:
        lea     .Ltxt_protegee, %a2
        bsr     .Lmessage
        bra     .Lboucle

| THE CONFIRMATION: A acts, B or START cancel, the rest waits.
.Lconfirmer:
        cmpi.b  #3, V_CONF
        bcc     .Lc_attente
        btst    #4, %d0
        bne.s   1f
        andi.b  #0x60, %d0
        beq     .Lboucle
        clr.b   V_CONF
        lea     .Ltxt_renonce, %a2
        bsr     .Lmessage
        bra     .Lboucle
1:      move.b  V_CONF, %d1
        clr.b   V_CONF
        cmpi.b  #2, %d1
        beq.s   2f
        move.w  %d7, %d0                | delete the line's save
        bsr     .Lentree
        move.b  #0x04, CMD
        move.b  1(%a1), FCB
        move.b  2(%a1), FCB + 1
        move.b  (%a1), SUB
        lea     .Ltxt_efface, %a2
        bra.s   3f
2:      move.b  #0x00, CMD              | format
        lea     .Ltxt_formate, %a2
3:      jsr     _card
        moveq   #0, %d4
        move.b  REPONSE, %d4
        movem.l %d4/%a2, -(%sp)         | the answer and the message, which the screen overwrites
        bsr     .Lreleve
        bsr     .Lborner
        bsr     .Lecran
        movem.l (%sp)+, %d4/%a2
        tst.b   %d4
        beq.s   4f
        lea     .Ltxt_erreur, %a2       | CARD ERROR and the answer
        lea     F_LIGNE(%a6), %a1
        moveq   #L_ERREUR - 1, %d0
5:      move.b  (%a2)+, (%a1)+
        dbra    %d0, 5b
        move.b  %d4, %d0
        bsr     .Lhex2
        clr.b   (%a1)
        lea     F_LIGNE(%a6), %a2
4:      bsr     .Lmessage
        bra     .Lboucle

| ----------------------------------------------------------------------------------
| THE COPY (see the header). C on a line: a save, the card readable, otherwise nothing.
.Lcopier:
        move.w  V_N, %d1
        subq.w  #2, %d1
        cmp.w   %d1, %d7
        bcc     .Lboucle                | FORMAT CARD, EXIT: nothing
        tst.b   V_ETAT
        bne     .Lboucle                | no readable save
        move.w  %d7, %d0
        bsr     .Lentree
        movea.l %a1, %a3
        move.b  (%a3), V_SUB
        move.b  1(%a3), V_NGH
        move.b  2(%a3), V_NGH + 1
        bsr     .Lblocs                 | %d0: the blocks of its chain
        lsl.w   #6, %d0
        move.w  %d0, V_TAILLE
        bsr     .Lmettre_de_cote
        move.b  #0x02, CMD              | LOAD
        bsr     .Lc_interface
        jsr     _card
        tst.b   REPONSE
        beq.s   1f
        bsr     .Lrendre                | read in error: nothing waits
        moveq   #0, %d4
        move.b  REPONSE, %d4
        bra     .Lc_erreur
1:      move.b  #3, V_CONF
        lea     .Ltxt_changer, %a2
        bsr     .Lmessage
        bra     .Lboucle

| THE WAIT FOR THE TARGET CARD (3) AND FOR THE OVERWRITE (4): A writes, or asks to overwrite; B or
| START cancel, the game's RAM returned.
.Lc_attente:
        cmpi.b  #5, V_CONF
        bcc     .Lt_attente
        btst    #4, %d0
        bne.s   2f
        andi.b  #0x60, %d0
        beq     .Lboucle
.Lc_abandon:
        clr.b   V_CONF
        bsr     .Lrendre
        lea     .Ltxt_renonce, %a2
        bsr     .Lmessage
        bra     .Lboucle
2:      bsr     .Lreleve                | the card in place read again: a swap that REG_STATUS_B did
        bsr     .Lborner                | not see (removed and reinserted between two frames) does not
        bsr     .Lecran                 | fool the search that follows
        cmpi.b  #0x80, V_ETAT
        beq     .Lsans_carte            | the wait goes on
        btst    #6, STATUS_B
        bne     .Lprotegee
        cmpi.b  #4, V_CONF
        beq.s   4f
        | 3: does the card in place already hold this NGH and this sub-save?
        tst.b   V_ETAT
        bne.s   4f                      | not formatted, unknown: CARD will answer
        lea     TAMPON, %a1
        moveq   #32 - 1, %d1
3:      move.b  (%a1), %d2
        cmpi.b  #0xFF, %d2
        beq.s   5f
        cmp.b   V_SUB, %d2
        bne.s   5f
        move.b  1(%a1), %d2
        cmp.b   V_NGH, %d2
        bne.s   5f
        move.b  2(%a1), %d2
        cmp.b   V_NGH + 1, %d2
        bne.s   5f
        move.b  #4, V_CONF              | already there: overwrite?
        bsr     .Lmsg_ecraser
        bra     .Lboucle
5:      addq.l  #4, %a1
        dbra    %d1, 3b
4:      clr.b   V_CONF                  | write
        move.b  #0x03, CMD              | SAVE
        bsr     .Lc_interface
        jsr     _card
        bsr     .Lrendre
        moveq   #0, %d4
        move.b  REPONSE, %d4
        lea     .Ltxt_copie, %a2
        bra.s   .Lc_fin
.Lc_erreur:
        lea     .Ltxt_copie, %a2
.Lc_fin:
        movem.l %d4/%a2, -(%sp)         | the answer and the message, which the screen overwrites
        bsr     .Lreleve
        bsr     .Lborner
        bsr     .Lecran
        movem.l (%sp)+, %d4/%a2
        tst.b   %d4
        beq.s   1f
        lea     .Ltxt_erreur, %a2       | CARD ERROR and the answer
        lea     F_LIGNE(%a6), %a1
        moveq   #L_ERREUR - 1, %d0
2:      move.b  (%a2)+, (%a1)+
        dbra    %d0, 2b
        move.b  %d4, %d0
        bsr     .Lhex2
        clr.b   (%a1)
        lea     F_LIGNE(%a6), %a2
1:      bsr     .Lmessage
        bra     .Lboucle

| ----------------------------------------------------------------------------------
| COPY ALL (see the header). D: a readable card with at least one save, otherwise nothing.
.Lcopier_tout:
        tst.b   V_ETAT
        bne     .Lboucle
        cmpi.w  #2, V_N
        beq     .Lboucle
        bsr     .Lmettre_de_cote
        lea     TAMPON, %a1
        lea     COPIE_DIR, %a2
        moveq   #192 / 4 - 1, %d1
1:      move.l  (%a1)+, (%a2)+
        dbra    %d1, 1b
        bsr     .Lt_debut
2:      bsr     .Lt_suivante
        beq.s   3f
        moveq   #0, %d1                 | crossed chains must not overflow the buffer
        move.w  V_TAILLE, %d1
        add.l   V_PTR, %d1
        cmpi.l  #COPIE_DIR, %d1
        bhi.s   4f
        move.b  #0x02, CMD              | LOAD
        bsr     .Lt_interface
        jsr     _card
        tst.b   REPONSE
        bne.s   5f
        bsr     .Lt_avancer
        bra.s   2b
3:      move.b  #5, V_CONF
        lea     .Ltxt_changer, %a2
        bsr     .Lmessage
        bra     .Lboucle
4:      bsr     .Lrendre
        move.w  #0x83, %d4              | the answer of a FAT error
        bra     .Lc_erreur
5:      bsr     .Lrendre                | read in error: nothing waits
        moveq   #0, %d4
        move.b  REPONSE, %d4
        bra     .Lc_erreur

| THE WAIT (5) AND THE OVERWRITE (6) OF COPY ALL: A goes on, B or START cancel.
.Lt_attente:
        btst    #4, %d0
        bne.s   2f
        andi.b  #0x60, %d0
        beq     .Lboucle
        bra     .Lc_abandon
2:      bsr     .Lreleve                | the card in place read again, as for the copy
        bsr     .Lborner
        bsr     .Lecran
        cmpi.b  #0x80, V_ETAT
        beq     .Lsans_carte            | the wait goes on
        btst    #6, STATUS_B
        bne     .Lprotegee
        cmpi.b  #6, V_CONF
        beq     .Lt_ecrire
        tst.b   V_ETAT
        bne     .Lt_ecrire              | not formatted, unknown: CARD will answer
        lea     TAMPON, %a1             | the source still in place: never written
        lea     COPIE_DIR, %a2
        moveq   #192 / 4 - 1, %d1
3:      cmpm.l  (%a1)+, (%a2)+
        dbne    %d1, 3b
        bne.s   4f
        lea     .Ltxt_meme, %a2
        bsr     .Lmessage
        bra     .Lboucle
4:      bsr     .Llibres                | %d3: the free blocks, save after save
        move.w  %d0, %d3
        moveq   #0, %d4                 | %d4: the saves replaced
        bsr     .Lt_debut
5:      bsr     .Lt_suivante
        beq.s   9f
        cmp.w   %d0, %d3
        bcs.s   8f
        sub.w   %d0, %d3
        lea     TAMPON, %a3
        moveq   #32 - 1, %d1
6:      move.b  (%a3), %d2
        cmpi.b  #0xFF, %d2
        beq.s   7f
        cmp.b   V_SUB, %d2
        bne.s   7f
        move.b  1(%a3), %d2
        cmp.b   V_NGH, %d2
        bne.s   7f
        move.b  2(%a3), %d2
        cmp.b   V_NGH + 1, %d2
        bne.s   7f
        addq.w  #1, %d4
        bsr     .Lblocs                 | the old chain, freed after the save
        add.w   %d0, %d3
        bra.s   5b
7:      addq.l  #4, %a3
        dbra    %d1, 6b
        bra.s   5b
8:      lea     .Ltxt_pleine, %a2
        bsr     .Lmessage
        bra     .Lboucle
9:      tst.w   %d4
        beq.s   .Lt_ecrire
        move.b  #6, V_CONF
        lea     F_LIGNE(%a6), %a1       | OVERWRITE nn SAVES? A:YES B:NO
        lea     .Ltxt_ecraser, %a2
1:      move.b  (%a2)+, (%a1)+
        bne.s   1b
        subq.l  #1, %a1
        move.w  %d4, %d0
        bsr     .Ldecimal2
        lea     .Ltxt_saves, %a2
2:      move.b  (%a2)+, (%a1)+
        bne.s   2b
        subq.l  #1, %a1
        lea     .Ltxt_oui_non, %a2
3:      move.b  (%a2)+, (%a1)+
        bne.s   3b
        lea     F_LIGNE(%a6), %a2
        bsr     .Lmessage
        bra     .Lboucle

| THE WRITE: every save in turn; the first error stops it and is shown.
.Lt_ecrire:
        clr.b   V_CONF
        bsr     .Lt_debut
1:      bsr     .Lt_suivante
        beq.s   2f
        move.b  #0x03, CMD              | SAVE
        bsr     .Lt_interface
        jsr     _card
        tst.b   REPONSE
        bne.s   2f
        bsr     .Lt_avancer
        bra.s   1b
2:      bsr     .Lrendre
        moveq   #0, %d4
        move.b  REPONSE, %d4
        lea     .Ltxt_copie, %a2
        bra     .Lc_fin

| The walk through the kept directory, from its first entry and the start of the buffer.
.Lt_debut:
        move.l  #COPIE_DIR, V_ENTREE
        move.l  #COPIE_RAM, V_PTR
        rts

| THE NEXT SAVE of the kept directory: %a3 on its entry, V_SUB, V_NGH, V_TAILLE set, %d0 its blocks
| and Z clear; none left: %d0 at 0 and Z set. An empty chain is skipped. Clobbers %d1, %d2, %a3, %a4.
.Lt_suivante:
        lea     COPIE_DIR + 0x80, %a4   | the kept FAT
1:      movea.l V_ENTREE, %a3
        cmpa.l  %a4, %a3
        bcc.s   2f
        addq.l  #4, V_ENTREE
        cmpi.b  #0xFF, (%a3)
        beq.s   1b
        bsr     .Lblocs_de
        tst.w   %d0
        beq.s   1b
        move.b  (%a3), V_SUB
        move.b  1(%a3), V_NGH
        move.b  2(%a3), V_NGH + 1
        move.w  %d0, %d1
        lsl.w   #6, %d1
        move.w  %d1, V_TAILLE
        tst.w   %d0
        rts
2:      moveq   #0, %d0
        rts

| CARD's interface for the save in turn, and the step to the next one in the buffer (clobbers %d0).
.Lt_interface:
        bsr.s   .Lc_interface
        move.l  V_PTR, START_C
        rts
.Lt_avancer:
        moveq   #0, %d0
        move.w  V_TAILLE, %d0
        add.l   %d0, V_PTR
        move.b  %d0, WATCHDOG
        rts

| CARD's interface for the copy: NGH, sub-save, the buffer, the size.
.Lc_interface:
        move.b  V_NGH, FCB
        move.b  V_NGH + 1, FCB + 1
        move.b  V_SUB, SUB
        move.l  #COPIE_RAM, START_C
        move.w  V_TAILLE, SIZE_C
        rts

| THE BUFFER SET ASIDE in VRAM, then returned (see the header). REG_VRAMMOD at 1 for the write,
| returned to 32; one read per address, three `nop` between the address and the data, like `tests.s`.
| Clobbers %d0, %d1, %a1.
.Lmettre_de_cote:
        lea     COPIE_RAM, %a1
        move.w  #1, VRAMMOD
        move.w  #0x0000, VRAMADDR
        move.w  #COPIE_MOTS - 1, %d1
1:      move.w  (%a1)+, %d0
        move.w  %d0, (%a0)
        move.b  %d0, WATCHDOG
        dbra    %d1, 1b
        move.w  #32, VRAMMOD
        rts
.Lrendre:
        lea     COPIE_RAM, %a1
        moveq   #0, %d0
        move.w  #COPIE_MOTS - 1, %d1
1:      move.w  %d0, VRAMADDR
        nop
        nop
        nop
        move.w  (%a0), (%a1)+
        addq.w  #1, %d0
        move.b  %d0, WATCHDOG
        dbra    %d1, 1b
        rts

| OVERWRITE nnnn-ss? A:YES B:NO. Clobbers %d0-%d4, %a1-%a3.
.Lmsg_ecraser:
        lea     F_LIGNE(%a6), %a1
        lea     .Ltxt_ecraser, %a2
1:      move.b  (%a2)+, (%a1)+
        bne.s   1b
        subq.l  #1, %a1
        move.b  V_NGH, %d0
        bsr     .Lhex2
        move.b  V_NGH + 1, %d0
        bsr     .Lhex2
        move.b  #0x2D, (%a1)+           | "-"
        move.b  V_SUB, %d0
        bsr     .Ldecimal2
        lea     .Ltxt_oui_non, %a2
2:      move.b  (%a2)+, (%a1)+
        bne.s   2b
        lea     F_LIGNE(%a6), %a2
        bra     .Lmessage

| THE EXIT: CARD's interface returned, the manager's RAM at zero, palette 5 too.
.Lsortie:
        lea     GARDE, %a1
        move.b  (%a1)+, 0x10FCF4
        lea     0x10FD00, %a2
        moveq   #24 - 1, %d0
1:      move.b  (%a1)+, (%a2)+
        dbra    %d0, 1b
        lea     CMD, %a2
        moveq   #14 - 1, %d0
2:      move.b  (%a1)+, (%a2)+
        dbra    %d0, 2b
        lea     TAMPON, %a1
        move.w  #(RAM_FIN - TAMPON) / 4 - 1, %d0
3:      clr.l   (%a1)+
        dbra    %d0, 3b
        bsr     .Lsync
        lea     PALETTES + PAL_ALERTE * 32, %a1
        moveq   #16 - 1, %d0
4:      clr.w   (%a1)+
        dbra    %d0, 4b
        unlk    %a6
        movem.l (%sp)+, %d0-%d7/%a0-%a6
        rts

| ----------------------------------------------------------------------------------
| THE RECORD: the card read (`_carte_releve`), the state, the number of lines. Clobbers %d0-%d2,
| %a1.
.Lreleve:
        move.b  STATUS_B, %d0
        andi.b  #0x70, %d0
        move.b  %d0, V_STB
        move.l  %a0, -(%sp)
        lea     TAMPON, %a0
        jsr     _carte_releve
        movea.l (%sp)+, %a0
        move.b  %d0, V_ETAT
        moveq   #2, %d1                 | FORMAT CARD and EXIT
        tst.b   %d0
        bne.s   2f
        lea     TAMPON, %a1
        moveq   #32 - 1, %d2
1:      cmpi.b  #0xFF, (%a1)
        beq.s   3f
        addq.w  #1, %d1
3:      addq.l  #4, %a1
        dbra    %d2, 1b
2:      move.w  %d1, V_N
        rts

| THE CURSOR IN THE LIST, and the window that shows it (%d6). Clobbers %d0.
.Lborner:
        move.w  V_N, %d0
        cmp.w   %d0, %d7
        bcs.s   1f
        move.w  %d0, %d7
        subq.w  #1, %d7
1:      cmp.w   %d6, %d7
        bcc.s   2f
        move.w  %d7, %d6                | above the window
2:      move.w  %d7, %d0
        subi.w  #VISIBLES - 1, %d0
        bls.s   3f
        cmp.w   %d6, %d0
        bls.s   3f
        move.w  %d0, %d6                | below
3:      move.w  V_N, %d0
        subi.w  #VISIBLES, %d0
        bhi.s   4f
        moveq   #0, %d6                 | everything fits
        rts
4:      cmp.w   %d0, %d6
        bls.s   5f
        move.w  %d0, %d6                | no gap at the bottom
5:      rts

| THE DIRECTORY ENTRY of the save on line %d0: %a1 on its four bytes in the
| buffer (sub-save, NGH, first block). Clobbers %d0, %a1.
.Lentree:
        lea     TAMPON, %a1
1:      cmpi.b  #0xFF, (%a1)
        beq.s   2f
        subq.w  #1, %d0
        bmi.s   3f
2:      addq.l  #4, %a1
        bra.s   1b
3:      rts

| ----------------------------------------------------------------------------------
| THE SCREEN, all of it: palettes after line $1F0 goes by, FIX_CLEAR, title, state,
| header, list, help. Clobbers %d0-%d4, %a1-%a4.
.Lecran:
        bsr     .Lsync
        lea     PALETTES + PAL_ALERTE * 32, %a1
        clr.w   (%a1)+
        move.w  #C_ALERTE, (%a1)+
        moveq   #14 - 1, %d0
1:      clr.w   (%a1)+
        dbra    %d0, 1b
        jsr     _fix_clear
        move.w  #32, VRAMMOD            | one write = one column
        move.w  #CASE_TITRE, %d1
        lea     .Ltxt_titre, %a2
        moveq   #L_TITRE, %d4
        move.w  #0x3100, %d3
        bsr     .Lecrire
        move.w  #CASE_TITRE + 1, %d1
        lea     .Ltxt_titre, %a2
        moveq   #L_TITRE, %d4
        move.w  #0x3200, %d3
        bsr     .Lecrire
        | THE STATE.
        move.b  V_ETAT, %d0
        lea     .Ltxt_sans, %a2
        cmpi.b  #0x80, %d0
        beq.s   3f
        lea     .Ltxt_non_formatee, %a2
        cmpi.b  #0x81, %d0
        beq.s   3f
        lea     .Ltxt_inconnue, %a2
        tst.b   %d0
        bne.s   3f
        lea     F_LIGNE(%a6), %a1       | FREE BLOCKS nn
        lea     .Ltxt_libres, %a2
2:      move.b  (%a2)+, (%a1)+
        bne.s   2b
        subq.l  #1, %a1
        bsr     .Llibres
        bsr     .Ldecimal2
        clr.b   (%a1)
        lea     F_LIGNE(%a6), %a2
        move.w  #0x1000, %d3
        bra.s   4f
3:      move.w  #(PAL_ALERTE << 12), %d3
4:      move.w  #CASE_ETAT, %d1
        bsr     .Lchaine
        cmpi.b  #0x80, V_ETAT
        beq.s   5f
        btst    #6, STATUS_B
        beq.s   5f
        move.w  #CASE_PROT, %d1
        lea     .Ltxt_protegee, %a2
        move.w  #(PAL_ALERTE << 12), %d3
        bsr     .Lchaine
5:      move.w  #CASE_ENTETE, %d1
        lea     .Ltxt_entete, %a2
        move.w  #0x3000, %d3
        bsr     .Lchaine
        move.w  #CASE_AIDE1, %d1
        lea     .Ltxt_aide1, %a2
        move.w  #0x4000, %d3
        bsr     .Lchaine
        move.w  #CASE_AIDE2, %d1
        lea     .Ltxt_aide2, %a2
        bsr     .Lchaine
        | then the list, by falling through

| THE VISIBLE LINES of the list. Clobbers %d0-%d4, %a1-%a4.
.Lliste:
        moveq   #0, %d4
1:      move.w  %d4, -(%sp)
        bsr.s   .Lligne
        move.w  (%sp)+, %d4
        addq.w  #1, %d4
        cmpi.w  #VISIBLES, %d4
        bcs.s   1b
        rts

| VISIBLE LINE %d4 (0 to VISIBLES - 1), that of item %d6 + %d4: composed in the frame,
| then written under palette 2 if it is chosen, 1 otherwise. Clobbers %d0-%d4, %a1-%a4.
.Lligne:
        lea     F_LIGNE(%a6), %a1
        moveq   #LARGEUR - 1, %d0
1:      move.b  #0x20, (%a1)+
        dbra    %d0, 1b
        clr.b   (%a1)
        move.w  %d4, %d1
        addi.w  #0x7000 + 3 * 32 + LIGNE0, %d1
        move.w  %d1, -(%sp)             | the cell
        move.w  #0x1000, -(%sp)         | the palette
        add.w   %d6, %d4                | the item
        cmp.w   V_N, %d4
        bcc     .Ll_ecrire              | beyond: an empty line
        lea     F_LIGNE(%a6), %a1
        cmp.w   %d7, %d4
        bne.s   2f
        move.b  #0x3E, (%a1)            | ">"
        move.w  #0x2000, (%sp)
2:      addq.l  #2, %a1
        move.w  V_N, %d0
        subq.w  #1, %d0
        lea     .Ltxt_sortie, %a2
        cmp.w   %d0, %d4
        beq.s   3f
        subq.w  #1, %d0
        lea     .Ltxt_formater_l, %a2
        cmp.w   %d0, %d4
        beq.s   3f
        | A save: NGH, sub-save, blocks, name.
        move.w  %d4, %d0
        movea.l %a1, %a3
        bsr     .Lentree                | %a1: the entry
        exg     %a1, %a3                | %a3: the entry; %a1: the line
        move.b  1(%a3), %d0
        bsr     .Lhex2
        move.b  2(%a3), %d0
        bsr     .Lhex2
        addq.l  #1, %a1
        move.b  (%a3), %d0
        bsr     .Ldecimal2
        addq.l  #2, %a1
        bsr     .Lblocs
        bsr     .Ldecimal2
        addq.l  #2, %a1
        move.b  1(%a3), %d0             | the NGH, byte by byte: the entry is at +1
        lsl.w   #8, %d0
        move.b  2(%a3), %d0
        bsr     .Lnom                   | %a2: the name, or 0
        move.l  %a2, %d0
        beq.s   .Ll_ecrire
        moveq   #16 - 1, %d0
4:      move.b  (%a2)+, (%a1)+
        dbra    %d0, 4b
        bra.s   .Ll_ecrire
3:      move.b  (%a2)+, (%a1)+          | FORMAT CARD, EXIT
        bne.s   3b
        move.b  #0x20, -1(%a1)
.Ll_ecrire:
        move.w  (%sp)+, %d3
        move.w  (%sp)+, %d1
        lea     F_LIGNE(%a6), %a2
        moveq   #LARGEUR, %d4
        bra     .Lecrire

| THE BLOCKS of save %a3: its chain in FAT 1, from the first block up to $01. A
| block outside 5-31, or more than 27 turns (a FAT that loops), stop the count. → %d0.
| `.Lblocs_de`: in the FAT at %a4 (COPY ALL). Clobbers %d1, %d2; `.Lblocs`, %a4 too.
.Lblocs:
        lea     T_FAT, %a4
.Lblocs_de:
        moveq   #0, %d0
        moveq   #0, %d1
        move.b  3(%a3), %d1
        moveq   #27 - 1, %d2
1:      cmpi.w  #5, %d1
        bcs.s   2f
        cmpi.w  #32, %d1
        bcc.s   2f
        addq.w  #1, %d0
        move.b  (%a4,%d1.w), %d1
        cmpi.b  #1, %d1
        dbeq    %d2, 1b
2:      rts

| THE FREE BLOCKS: the $00 entries of FAT 1, blocks 5 to 31. → %d0. Clobbers %d1, %a2.
.Llibres:
        moveq   #0, %d0
        lea     T_FAT + 5, %a2
        moveq   #27 - 1, %d1
1:      tst.b   (%a2)+
        bne.s   2f
        addq.w  #1, %d0
2:      dbra    %d1, 1b
        rts

| THE GAME'S NAME for NGH %d0.w, if it is registered in the slot table: %a2 on its 16 bytes
| in backup RAM, 0 otherwise. Clobbers %d1, %d2.
.Lnom:
        suba.l  %a2, %a2
        tst.w   %d0
        beq.s   9f
        lea     0xD00124, %a2
        moveq   #8 - 1, %d2
1:      cmp.w   (%a2), %d0
        bne.s   2f
        move.w  2(%a2), %d1
        cmpi.w  #8, %d1
        bcs.s   3f
2:      addq.l  #4, %a2
        dbra    %d2, 1b
        suba.l  %a2, %a2
9:      rts
3:      lsl.w   #4, %d1
        lea     0xD002A0, %a2
        adda.w  %d1, %a2
        rts

| ----------------------------------------------------------------------------------
| THE MESSAGES, line 24, under palette 5: string %a2 (terminated by 0), the line
| cleared first. Clobbers %d0-%d4, %a1, %a2.
.Lmessage:
        move.l  %a2, -(%sp)
        move.w  #CASE_MSG, %d1
        lea     .Ltxt_vide, %a2
        moveq   #LARGEUR, %d4
        moveq   #0, %d3
        bsr     .Lecrire
        movea.l (%sp)+, %a2
        move.w  #CASE_MSG, %d1
        move.w  #(PAL_ALERTE << 12), %d3
        bra     .Lchaine

| DELETE nnnn-ss?: the save on line %d7. Clobbers %d0-%d4, %a1-%a3.
.Lmsg_effacer:
        move.w  %d7, %d0
        bsr     .Lentree
        movea.l %a1, %a3
        lea     F_LIGNE(%a6), %a1
        lea     .Ltxt_effacer, %a2
1:      move.b  (%a2)+, (%a1)+
        bne.s   1b
        subq.l  #1, %a1
        move.b  1(%a3), %d0
        bsr     .Lhex2
        move.b  2(%a3), %d0
        bsr     .Lhex2
        move.b  #0x2D, (%a1)+           | "-"
        move.b  (%a3), %d0
        bsr     .Ldecimal2
        lea     .Ltxt_oui_non, %a2
2:      move.b  (%a2)+, (%a1)+
        bne.s   2b
        lea     F_LIGNE(%a6), %a2
        bra.s   .Lmessage

| TWO HEXADECIMAL DIGITS of %d0.b to (%a1)+. Clobbers %d0, %d1.
.Lhex2:
        move.b  %d0, %d1
        lsr.b   #4, %d0
        bsr.s   1f
        move.b  %d1, %d0
1:      andi.w  #0x0F, %d0
        addi.b  #0x30, %d0
        cmpi.b  #0x39, %d0
        bls.s   2f
        addq.b  #7, %d0
2:      move.b  %d0, (%a1)+
        rts

| TWO DECIMAL DIGITS of %d0 (0 to 99) to (%a1)+. Clobbers %d0.
.Ldecimal2:
        andi.l  #0xFF, %d0
        divu    #10, %d0
        addi.b  #0x30, %d0
        move.b  %d0, (%a1)+
        swap    %d0
        addi.b  #0x30, %d0
        move.b  %d0, (%a1)+
        rts

| ----------------------------------------------------------------------------------
| A STRING terminated by 0 starting at cell %d1, under %d3, REG_VRAMMOD at 32. Clobbers %d2,
| %d4, %a1, %a2.
.Lchaine:
        movea.l %a2, %a1
        moveq   #-1, %d4
1:      addq.w  #1, %d4
        tst.b   (%a1)+
        bne.s   1b
        tst.w   %d4
        beq.s   2f
| WRITE %d4 characters from %a2 starting at cell %d1, like `dip.s`. Outside $20-$7E, a
| space. Clobbers %d2, %d4, %a2.
.Lecrire:
        move.w  %d1, VRAMADDR
        subq.w  #1, %d4
1:      moveq   #0, %d2
        move.b  (%a2)+, %d2
        cmpi.b  #0x20, %d2
        bcs.s   3f
        cmpi.b  #0x7E, %d2
        bls.s   4f
3:      moveq   #0x20, %d2
4:      add.w   %d3, %d2
        move.w  %d2, (%a0)
        dbra    %d4, 1b
2:      rts

| THE BUTTONS. Bits: 0 up, 1 down, 2 D (COPY ALL), 4 A, 5 B, 6 START, 7 C (the copy). %d5
| the previous state, updated; %d0 the edges. Clobbers %d1, %d2.
.Lentrees:
        jsr     _panneau_p1             | %d0: P1, joystick or translated panel (`panneau.s`)
        move.b  %d0, %d2
        not.b   %d2
        move.b  %d2, %d1
        andi.b  #0x40, %d1              | C, bit 6 of REG_P1CNT
        add.b   %d1, %d1                | to bit 7
        btst    #7, %d2                 | D, to bit 2, where nothing else is read
        beq.s   1f
        addq.b  #4, %d1
1:      andi.b  #0x33, %d2
        or.b    %d1, %d2
        move.b  STATUS_B, %d1
        not.b   %d1
        andi.b  #0x01, %d1
        lsl.b   #6, %d1
        or.b    %d1, %d2
        move.b  %d5, %d0
        not.b   %d0
        and.b   %d2, %d0
        move.b  %d2, %d5
        rts

| LINE $1F0 GOING BY, like `dip.s`; watchdog on every turn. Clobbers %d0.
| BOUNDED at SYNC_TOURS turns per wait, ≈ 2 frames, line seen or not: the count is in
| `ecran.s`, of which this is the identical copy.
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
| THE DATA.
        .balign 2
.Ltxt_titre:
        .ascii  "MEMORY CARD"
        .equ    L_TITRE, . - .Ltxt_titre
.Ltxt_erreur:
        .ascii  "CARD ERROR "
        .equ    L_ERREUR, . - .Ltxt_erreur
.Ltxt_sans:             .asciz  "NO CARD"
.Ltxt_non_formatee:     .asciz  "CARD NOT FORMATTED"
.Ltxt_inconnue:         .asciz  "UNSUPPORTED CARD"
.Ltxt_libres:           .asciz  "FREE BLOCKS "
.Ltxt_protegee:         .asciz  "WRITE PROTECTED"
.Ltxt_entete:           .asciz  "  NGH  SUB BLK GAME"
.Ltxt_formater_l:       .asciz  "FORMAT CARD"
.Ltxt_sortie:           .asciz  "EXIT"
.Ltxt_formater:         .asciz  "FORMAT CARD? A:YES B:NO"
.Ltxt_effacer:          .asciz  "DELETE "
.Ltxt_oui_non:          .asciz  "? A:YES B:NO"
.Ltxt_efface:           .asciz  "DELETED"
.Ltxt_formate:          .asciz  "FORMATTED"
.Ltxt_renonce:          .asciz  "CANCELLED"
.Ltxt_aide1:            .asciz  "UP/DOWN  A:DELETE/FORMAT C:COPY"
.Ltxt_changer:          .asciz  "CHANGE CARD AND PRESS A  B:NO"
.Ltxt_ecraser:          .asciz  "OVERWRITE "
.Ltxt_copie:            .asciz  "COPIED"
.Ltxt_aide2:            .asciz  "D:COPY ALL  START:BACK"
.Ltxt_meme:             .asciz  "SAME CARD  B:NO"
.Ltxt_pleine:           .asciz  "NOT ENOUGH BLOCKS  B:NO"
.Ltxt_saves:            .asciz  " SAVES"
.Ltxt_vide:             .ascii  "                                "
        .balign 2
