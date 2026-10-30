| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| MESS_OUT — the $C004CE entry of the call table, and the routine that SYSTEM_INT1 calls.
|
| The six-byte slot in `c0.s` holds only a `jmp` to `_mess_out`: the game arrives there
| by `jsr` (measured: 655 calls from `b2b` to $C004CE under the reference,
| `measured/2026-10-17-b2b-mess-out.tsv`, point 1) and leaves by our `rts`. INT1 (`int1.s`)
| calls it by `bsr`, its registers already saved.
|
| THREE KINDS OF CLAIMS, and each one says so:
|   "measured": `measured/2026-10-17-b2b-mess-out.tsv` (point 4, one call from `b2b`
|                 broken down, and the protocol of the variables);
|   "read in": a page of the NeoGeo Development Wiki, named — here mostly "MESS_OUT",
|                 its text and its screenshot, which renders the page's example list;
|   "ASSUMED": neither, and it says so.
|
| THE BUFFER, read in "MESS_OUT": from BIOS_MESS_BUFFER ($10FF00, constant) up to
| BIOS_MESS_POINT ($10FDBE, long). Each entry is a long: non-zero, a pointer to a
| command list in ROM or in RAM; zero, the list follows directly in the buffer. The
| commands are words: the low byte is the command number, the high byte a parameter
| for 2, 8, 9, C and D (read in the page's bit diagrams).
|
| THE CURRENT VRAM ADDRESS (%d1) IS NOT THE HARDWARE'S: it is the last one the BIOS
| set in $3C0000. Measured on the `b2b` call: $820D (command 3), one datum written,
| then command 5 with +$0200 sets $840D — the base, without the advance the write gave to
| the LSPC's address. Read in the "MESS_OUT" screenshot, same law: the "$0005,$0001"
| ("Next line") bring each line back to the starting column, and the repetition of C then D
| stays on a single line, the hardware advancing by VRAM_MOD on its own between them.
|
| THE STATE OF A CALL is in registers, and only for the duration of the call — no RAM
| variable is written outside $10FDBE and $10FDC2, which are the only ones the measurement
| attributes to MESS_OUT. ASSUMED, therefore: the data format (command 1), the data pointer
| (commands 4 and 6) and the current address start again at each call from:
|   byte format, high byte $00, end code $FF (the one in the page's example);
|   null data pointer; current address 0.
| The page says the format "stays the same until command 1 is used again", without saying
| whether it survives from one call to the next; the measured `b2b` list sets its own every time.
|
| ALL REGISTERS ARE RETURNED INTACT. ASSUMED: "MESS_OUT" says nothing of what the
| call preserves; it is the choice that cannot break a caller. VRAM_MOD ($3C0004)
| is not restored: commands 2, 8 and 9 set it, and it is an LSPC register.
|
| THE SPACING OF VRAM ACCESSES, read in "VRAM": at least 12 cycles between two data
| writes, 16 between a datum and the address that follows. The write loops below
| take at least 26 cycles per iteration, and an address never follows a datum without the
| decoding of a command or a loop exit between the two.
| ==================================================================================

        | In the high zone since 2026-10-25: $C02000-$C03FFF is the grid (`grille.s`).
        .section .haut, "ax"
        .global _mess_out

| ----------------------------------------------------------------------------------
| THE ENTRY. Measured: $10FDC2 ← 01 during the call, then $10FDBE ← $0010FF00 and $10FDC2 ← 00
| after the LSPC writes, in that order. Read in "MESS_OUT" and "BIOS RAM locations":
| BIOS_MESS_BUSY non-zero, the game is modifying the buffer ("1:Skip MESS_OUT") — we do not
| touch it, pointer included.
|
| A POINTER OUTSIDE ]$10FF00, $110000] EXECUTES NOTHING. ASSUMED, a guard: beyond the
| RAM, the walk would read anything as commands. Measured, the case exists: without
| initialisation, `b2b` left $00002F9C in $10FDBE (point 3 of the record). A pointer
| below $10FF00 already falls into the walk's `bcc`.
| ----------------------------------------------------------------------------------
_mess_out:
        tst.b   0x10FDC2
        bne.s   .Locc
        movem.l %d0-%d7/%a0-%a6, -(%sp)
        move.b  #1, 0x10FDC2            | BIOS_MESS_BUSY raised

        lea     0x3C0000, %a4           | REG_VRAMADDR ; +2 REG_VRAMRW ; +4 REG_VRAMMOD
        lea     0x10FF00, %a2           | BIOS_MESS_BUFFER: the entry to read
        movea.l 0x10FDBE, %a3           | BIOS_MESS_POINT: the end of the buffer
        cmpa.l  #0x110000, %a3
        bhi.s   .Lfin
        moveq   #0, %d1                 | current VRAM address, ASSUMED (header)
        move.w  #0x0001, %d2            | format: bytes, ended by code...
        move.w  #0x00FF, %d3            | ... high byte $00, code $FF — ASSUMED (header)
        suba.l  %a1, %a1                | data pointer (4, 6), ASSUMED (header)

.Lentree:
        cmpa.l  %a3, %a2
        bcc.s   .Lfin                   | unsigned: $10FF00 ≥ end, buffer empty
        move.l  (%a2)+, %d0
        beq.s   .Ldirecte
        movea.l %d0, %a0                | a pointer to a list
        bsr     _mess_liste
        bra.s   .Lentree
.Ldirecte:
        movea.l %a2, %a0                | null long: the list follows in the buffer...
        bsr     _mess_liste
        movea.l %a0, %a2                | ... and the next entry after its end word
        bra.s   .Lentree

.Lfin:
        move.l  #0x10FF00, 0x10FDBE     | BIOS_MESS_POINT ← BIOS_MESS_BUFFER, measured
        move.b  #0, 0x10FDC2            | BIOS_MESS_BUSY lowered, measured
        movem.l (%sp)+, %d0-%d7/%a0-%a6
.Locc:
        rts

| ----------------------------------------------------------------------------------
| A LIST, from %a0, up to its command 0. On exit, %a0 follows the end word.
|
| SUB-LISTS (A, B) push the return address on the 68000 stack, %d7 counts
| the depth. Read in "MESS_OUT": "The call stack seems to be 5 addresses deep".
| ASSUMED, what overflows it: a sixth nested call is skipped, its pointer consumed.
| ASSUMED again, what the page does not say: a command 0 in a sub-list counts as a
| return (B) there, and a B in the top list counts as an end (0) there — the top list thus
| keeps its position, which a direct list requires for the next entry to be found.
| A command beyond $D is treated as 0, ASSUMED: what follows is no longer read.
|
| Registers: %d0 the command word, %d1 the current address, %d2/%d3 the format, %d4-%d6
| scratch, %d7 the depth; %a0 the list, %a1 the data pointer, %a4 the
| LSPC, %a6 the source of an output.
| ----------------------------------------------------------------------------------
_mess_liste:
        moveq   #0, %d7
.Lsuivante:
        move.w  (%a0)+, %d0
        moveq   #0, %d4
        move.b  %d0, %d4
        cmpi.b  #0x0D, %d4
        bls.s   1f
        moveq   #0, %d4                 | unknown: as 0
1:      add.w   %d4, %d4
        move.w  .Ltable(%pc,%d4.w), %d4
        jmp     .Ltable(%pc,%d4.w)
.Ltable:
        .word   .Lc0-.Ltable, .Lc1-.Ltable, .Lc2-.Ltable, .Lc3-.Ltable
        .word   .Lc4-.Ltable, .Lc5-.Ltable, .Lc6-.Ltable, .Lc7-.Ltable
        .word   .Lc8-.Ltable, .Lc8-.Ltable, .LcA-.Ltable, .Lc0-.Ltable
        .word   .LcC-.Ltable, .LcC-.Ltable

| 0 and B — end of list, or return from a sub-list (see above).
.Lc0:
        tst.w   %d7
        beq.s   .Lc0_fin
        movea.l (%sp)+, %a0
        subq.w  #1, %d7
        bra     .Lsuivante
.Lc0_fin:
        rts

| 1 — the format, read in "MESS_OUT": bit 9 of the command word, 0 bytes / 1 words;
| bit 8, 0 end code / 1 size. The next word: in bytes, the constant high byte and
| the end code or the size in the low byte; in words, the end code or the size.
.Lc1:
        move.w  %d0, %d2
        move.w  (%a0)+, %d3
        bra     .Lsuivante

| 2 — VRAM_MOD ← the high byte. ASSUMED: sign-extended. The page asks the question ("Is
| the value sign-extended or not ?") without answering it; "VRAM" says REG_VRAMMOD is signed.
.Lc2:
        move.w  %d0, %d4
        asr.w   #8, %d4
        move.w  %d4, 4(%a4)
        bra     .Lsuivante

| 3 — VRAM address ← the next word, set at once (measured: $3C0000 ← $820D).
.Lc3:
        move.w  (%a0)+, %d1
        move.w  %d1, (%a4)
        bra     .Lsuivante

| 4 — data pointer ← the next long, and the output from it. Read in "MESS_OUT":
| "Actual writes to VRAM are done with this command". The pointer stays after the last
| datum read, end code included, for command 6: the page's screenshot shows
| "MESSAGE 2" resumed just after the $FF of "MESSAGE 1".
.Lc4:
        movea.l (%a0)+, %a1
| 6 — resume the output where the previous one stopped.
.Lc6:
        movea.l %a1, %a6
        bsr     .Lsortir
        movea.l %a6, %a1
        bra     .Lsuivante

| 5 — current address += the next word, set at once (measured: +$0200 from $820D,
| $3C0000 ← $840D).
.Lc5:
        add.w   (%a0)+, %d1
        move.w  %d1, (%a4)
        bra     .Lsuivante

| 7 — the data follow the command, in the current format (measured: in words of size
| 1, $3C0002 ← $0984). The list resumes at the next even word: the padding byte the
| page asks for when the data end on an odd address. ASSUMED: the pointer
| of command 6 is not changed by it — the page links 6 only to 4.
.Lc7:
        movea.l %a0, %a6
        bsr     .Lsortir
.Lpair:
        move.l  %a6, %d4
        addq.l  #1, %d4
        bclr    #0, %d4
        movea.l %d4, %a0
        bra     .Lsuivante

| A — call the sub-list of the next long (see above for the depth).
.LcA:
        movea.l (%a0)+, %a6
        cmpi.w  #5, %d7
        bcc     .Lsuivante              | ASSUMED: beyond 5, skipped
        move.l  %a0, -(%sp)
        movea.l %a6, %a0
        addq.w  #1, %d7
        bra     .Lsuivante

| C and D — the next word written N times, N the high byte of the command. D increments
| the low byte each time, without carry: read in "MESS_OUT", $42FE gives $42FE,
| $42FF, $4200, $4201. ASSUMED: N = 0 writes nothing.
.LcC:
        moveq   #0, %d6
        move.w  %d0, %d6
        lsr.w   #8, %d6
        move.w  (%a0)+, %d4
        bra.s   2f
1:      move.w  %d4, 2(%a4)
        cmpi.b  #0x0D, %d0
        bne.s   2f
        addq.b  #1, %d4
2:      dbf     %d6, 1b
        bra     .Lsuivante

| 8 and 9 — text in the 8×16 font, read in "MESS_OUT": the high byte of the command is
| the constant high byte of the data (the character set), the bytes follow up to the
| code $FF, and VRAM_MOD goes to $20 — one column per character. The list resumes at the
| next even word, as for 7.
|
| A CHARACTER IS TWO TILES, the upper one at the current address, the lower one on the
| line below: the page says so for 9 ("upper", "lower"), and its screenshot renders the
| text of 8 and of 9 on two lines of tiles. So we write the upper row from
| the current address, then the lower one from the current address + 1, which BECOMES
| the current address. Read in the screenshot: "ABCDE" (command 8) on line 7, then
| "$0005,$0001" and the text of 9 on line 9, then "$0005,$0002" and the sub-lists
| on line 12 — each text did leave the current address on its second line.
| ASSUMED: starting from the current address, and not from where the hardware was left.
|
| THE TILES. Command 9, read in "MESS_OUT": $00-$1F → $080+c upper and $0C0+c lower,
| $60-$7F → $0A0+(c-$60) upper and $0E0+(c-$60) lower, always in page 0 "irrespective
| of the selected fontset"; the rest as command 8. ASSUMED: page 0 forces
| bits 11-8 of the tile to 0 and keeps the palette (bits 15-12) of the high byte.
| Command 8, ENTIRELY ASSUMED for the lower tile, which the page does not give: the
| upper tile is (high byte × $100) + c, like a byte datum of command 1, and
| the lower one the same + $100, in the next page. No source read says so; the
| content of the system tile ROM is not an input of this clean room.
.Lc8:
        moveq   #0, %d5
        move.w  %d0, %d5
        clr.b   %d5                     | %d5 = high byte × $100
        move.w  #0x20, 4(%a4)           | VRAM_MOD ← $20
        move.w  %d1, (%a4)
        moveq   #0, %d6                 | the upper row
        bsr     .Lrangee
        addq.w  #1, %d1
        move.w  %d1, (%a4)
        moveq   #1, %d6                 | the lower row
        bsr     .Lrangee
        bra.s   .Lpair

| One row of tiles of an 8 or 9 text, from %a0 up to the $FF; %a6 follows it afterwards.
.Lrangee:
        movea.l %a0, %a6
.Lr_car:
        moveq   #0, %d4
        move.b  (%a6)+, %d4
        cmpi.b  #0xFF, %d4
        beq.s   .Lr_fin
        cmpi.b  #9, %d0
        bne.s   .Lr_latin
        cmpi.b  #0x20, %d4
        bcs.s   .Lr_hira                | $00-$1F
        cmpi.b  #0x60, %d4
        bcs.s   .Lr_latin
        cmpi.b  #0x80, %d4
        bcc.s   .Lr_latin
        addi.w  #0x40, %d4              | $60-$7F → $0A0-$0BF
        bra.s   .Lr_kana
.Lr_hira:
        addi.w  #0x80, %d4              | $00-$1F → $080-$09F
.Lr_kana:
        tst.w   %d6
        beq.s   1f
        addi.w  #0x40, %d4              | the lower one: $0C0-$0DF, $0E0-$0FF
1:      or.w    %d5, %d4
        andi.w  #0xF0FF, %d4            | page 0, palette kept — ASSUMED
        bra.s   .Lr_ecrire
.Lr_latin:
        or.w    %d5, %d4
        tst.w   %d6
        beq.s   .Lr_ecrire
        addi.w  #0x100, %d4             | the lower one: next page — ASSUMED
.Lr_ecrire:
        move.w  %d4, 2(%a4)
        bra.s   .Lr_car
.Lr_fin:
        rts

| ----------------------------------------------------------------------------------
| THE DATA OUTPUT, from %a6, in the format %d2/%d3 (command 1). On exit, %a6
| follows the last datum read, end code included. A size of 0 writes nothing, ASSUMED;
| the end code itself is never written (read in "MESS_OUT", screenshot: "MESSAGE 1"
| and "MESSAGE 2" separated by an $FF that is not displayed).
| ----------------------------------------------------------------------------------
.Lsortir:
        btst    #9, %d2
        bne.s   .Ls_mots
        btst    #8, %d2
        bne.s   .Ls_octets_taille
.Ls_octets_fin:
        move.w  %d3, %d4                | constant high byte...
        move.b  (%a6)+, %d4             | ... and the datum in the low byte
        cmp.b   %d3, %d4                | the end code?
        beq.s   .Ls_fin
        move.w  %d4, 2(%a4)
        bra.s   .Ls_octets_fin
.Ls_octets_taille:
        moveq   #0, %d6
        move.b  %d3, %d6                | size ≤ $FF
        bra.s   2f
1:      move.w  %d3, %d4
        move.b  (%a6)+, %d4
        move.w  %d4, 2(%a4)
2:      dbf     %d6, 1b
        rts
.Ls_mots:
        btst    #8, %d2
        bne.s   .Ls_mots_taille
.Ls_mots_fin:
        move.w  (%a6)+, %d4
        cmp.w   %d3, %d4
        beq.s   .Ls_fin
        move.w  %d4, 2(%a4)
        bra.s   .Ls_mots_fin
.Ls_mots_taille:
        move.w  %d3, %d6                | size ≤ $FFFF: `dbf` counts on 16 bits
        bra.s   2f
1:      move.w  (%a6)+, 2(%a4)
2:      dbf     %d6, 1b
.Ls_fin:
        rts
