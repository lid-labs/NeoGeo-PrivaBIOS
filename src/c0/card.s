| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| CARD and CARD_ERROR — the entries $C00468 and $C0046E of the call table: the memory
| card.
|
| The six-byte slots of `c0.s` carry only a `jmp` to `_card` and
| `_card_error`: the game gets there by `jsr` and leaves through our `rts`.
|
| THREE KINDS OF CLAIM, and each one says so:
|   "measured"  : `measured/2026-10-19-card-sans-carte.tsv` (8 calls on 5 games, without
|                 a card) and `measured/2026-10-19-card-avec-carte.tsv` (2 KiB card,
|                 8 bits, natural and provoked calls); "point N" refers to the latter;
|   "read in"   : the pages "CARD", "CARD ERROR", "Memory card" and "Memory mapped
|                 registers" of the NeoGeo Development Wiki, consulted on 2026-10-19;
|   "ASSUMED"   : neither one nor the other, and it is said.
|
| WITHOUT A CARD, measured, in this order, on the 8 calls, then the two locks (further down):
|   $10FD00 (long)  ← the SP on entry (it points to the stacked return address) MINUS 4;
|   $10FCF4 (byte)  ← $FF, role not interpreted;
|   $10FDC6 (byte)  ← $80, BIOS_CARD_ANSWER "no card inserted" (read in "CARD").
|
| THE DETECTION. REG_STATUS_B ($380000, high byte): $FF without a card, $8F with one, measured
| (point 4). Read in "Memory card": CD1 at bit 4, CD2 at bit 5, "both must be 0"
| when the card is in place; bit 6 is the write protection.
|
| THE CARD, 8 BITS: byte N at $800000 + 2N, measured (point 4: byte $47 written at
| $80008E). Read in "Memory card": always word accesses, only the low byte counts.
|
| THE FORMATTING CRITERION: CARD_MAGIC, "NEO-GEO" then $80 at the eight even bytes from
| $20 to $2E (read in "Memory card", measured point 2). Measured (point 4): on an
| unformatted card, two reads, bytes $00 then $20, then $81 — which agrees with a
| stop at the first difference. Comparing all eight is ASSUMED; byte $00 is read at
| the same place, and its value enters no decision — ASSUMED.
|
| THE STRUCTURE, measured (point 2), and read in "Memory card": 64-byte blocks;
| header in block 0; directory $40-$BF, 32 entries (sub-save, NGH, first
| block; $FF in the 1st byte if free); FAT 1 $C0-$FF, FAT 2 $100-$13F, one entry per
| block ($00 free, $01 last, $02 reserved, otherwise the next one); data from block 5.
| Sum of a FAT ($0D, $0E) = sum of its 64 bytes, measured three times.
|
| A SINGLE GEOMETRY: CARD_SIZE = $1000, 2 KiB, 32 blocks, the only one recorded — and the
| original SNK card (read in "Memory card"). ASSUMED: a formatted card that carries
| another CARD_SIZE answers $85 without reading or writing anything more; the page says the
| size of the directory and of the FATs follows the capacity without saying how, and reading
| another card with this layout would corrupt it. 16-bit cards not handled (BIOS_CARD_TYPE
| always 0): ASSUMED, nothing measured.
|
| THE CARD REGISTERS, measured (point 4, "REGISTRES DE LA CARTE"), odd
| bytes, the data does not matter (read in "Memory mapped registers"); in order:
|   load       : REG_CRDNORMAL ($3A0019), REG_CRDBANK ($380011) ← 0, then at the end
|                REG_CRDLOCK2 ($3A0007), REG_CRDLOCK1 ($3A0015);
|   save       : the same, and REG_CRDUNLOCK1 ($3A0005) then REG_CRDUNLOCK2 ($3A0017),
|                twice, before the two locks;
|   no card    : REG_CRDLOCK2, REG_CRDLOCK1.
| Without REG_CRDNORMAL the card cannot be read, measured: the first image of this file
| read two bytes, then answered $81 on a formatted card.
| Judged against the reference (bench/carte-diff.sh): $04 does both pairs like the
| save, $00 and $06 a single pair.
| ASSUMED:
|   - the other read commands ($01, $05, $07), an unformatted card and a
|     refused geometry behave like the load;
|   - the place of the two unlocks: back to back, just before the first write to
|     the card; a FAT repaired during a save therefore makes them happen twice;
|   - without a card, the locks come after $10FDC6.
|
| NO REGISTER MODIFIED, apart from the CCR. Read in "CARD": "register contents aren't
| preserved", so the caller counts on nothing; touching nothing is our choice.
| ==================================================================================

        | In the high area since 2026-10-25: $C02000-$C03FFF is the grid (`grille.s`).
        .section .haut, "ax"
        .global _card
        .global _card_error
        .global _carte_releve

| ----------------------------------------------------------------------------------
| CARD. Writes to BIOS RAM, measured (points 1 and 3), in this order:
|   with a card: $10FD00, $10FCF4, $10FDC6 ← $00, then the answer if it is not $00;
|   formatted card: in addition, after $10FDC6 ← $00, $10FCF4 again, $10FD16, $10FD14,
|   then the eight words $10FD04-$10FD12; formatting, for its part, without a second $10FCF4
|   and $10FD14 before $10FD16 (measured in judging). The value of the second $10FCF4 is not
|   recorded: $FF, like the first, ASSUMED. Nor are those of the temporary variables: we put
|   there what "CARD" describes, as 68000 addresses (ASSUMED).
| ----------------------------------------------------------------------------------
_card:
        subq.l  #4, %sp                 | SP − 4, measured; on An, subq/addq leave the CCR
        move.l  %sp, 0x10FD00           | only write of $10FD00: no read-modify
        addq.l  #4, %sp                 | SP back as on entry
        move.b  #0xFF, 0x10FCF4
        btst    #4, 0x380000            | REG_STATUS_B, CD1
        bne.s   .Lsans_carte
        btst    #5, 0x380000            | CD2
        beq.s   .Lavec_carte
.Lsans_carte:
        move.b  #0x80, 0x10FDC6         | BIOS_CARD_ANSWER: no card inserted
        move.b  %d0, 0x3A0007           | REG_CRDLOCK2, measured
        move.b  %d0, 0x3A0015           | REG_CRDLOCK1
        rts

.Lavec_carte:
        move.b  #0x00, 0x10FDC6         | measured: $00 first
        move.b  %d0, 0x3A0019           | REG_CRDNORMAL: without it, the card cannot be read
        move.b  #0x00, 0x380011         | REG_CRDBANK ← 0, measured
        movem.l %d0-%d7/%a0-%a2/%a4-%a5, -(%sp)
        lea     0x800000, %a5           | %a5: the card, for the whole call
        move.b  0x10FDC4, %d7           | BIOS_CARD_COMMAND
        beq     .Lformater              | $00: format, without looking at the old contents
        moveq   #0, %d1
        bsr     .Llire                  | byte $00: read like the reference, unused
        lea     _card_magie, %a0
        moveq   #0x20, %d1
1:      bsr     .Llire
        cmp.b   (%a0)+, %d0
        bne     .L81                    | unformatted card
        addq.w  #2, %d1
        cmpi.w  #0x30, %d1
        bne.s   1b

| THE CARD IS FORMATTED: its geometry, then the command.
.Lprete:
        | $01: word $10FDD0 written a first time here, before the second $10FCF4 —
        | measured in judging; the value is not: $0000, the reset of the
        | mask, ASSUMED.
        cmpi.b  #1, %d7
        bne.s   1f
        move.w  #0, 0x10FDD0
1:      move.b  #0xFF, 0x10FCF4
        moveq   #0x0A, %d1              | CARD_SIZE, header word
        bsr     .Llire
        move.b  %d0, %d6
        lsl.w   #8, %d6
        moveq   #0x0B, %d1
        bsr     .Llire
        move.b  %d0, %d6
        cmpi.w  #0x1000, %d6
        bne     .L85                    | other geometry: refused, ASSUMED
        move.w  %d6, 0x10FD16           | BIOS_CARD_SIZE (temporary): CARD_SIZE
        move.w  #0, 0x10FD14            | BIOS_CARD_TYPE: 8 bits
        bsr     .Ltemporaires           | %d6: number of blocks, until the exit

        moveq   #0, %d0
        move.b  %d7, %d0
        cmpi.b  #7, %d0
        bhi     .Lfin                   | unknown command: nothing, answer $00, ASSUMED
        add.w   %d0, %d0
        move.w  .Ltable(%pc,%d0.w), %d0
        jmp     .Ltable(%pc,%d0.w)
.Ltable:
        .word   .Lfin - .Ltable         | $00: does not arrive here (`.Lformater`)
        .word   .Lmasque - .Ltable      | $01
        .word   .Lcharger - .Ltable     | $02
        .word   .Lsauver - .Ltable      | $03
        .word   .Lsupprimer - .Ltable   | $04
        .word   .L82 - .Ltable          | $05
        .word   .Lnom_ecrire - .Ltable  | $06
        .word   .Lnom_lire - .Ltable    | $07

| THE ERROR ANSWERS, then the common exit with a card.
.L81:   move.b  #0x81, 0x10FDC6         | unformatted card
        bra.s   .Lfin
.L82:   move.b  #0x82, 0x10FDC6         | data absent
        bra.s   .Lfin
.L83:   move.b  #0x83, 0x10FDC6         | FAT error
        bra.s   .Lfin
.L84:   move.b  #0x84, 0x10FDC6         | card full
        bra.s   .Lfin
.L85:   move.b  #0x85, 0x10FDC6         | write-protected, or geometry refused
.Lfin:
        move.b  %d0, 0x3A0007           | REG_CRDLOCK2, then REG_CRDLOCK1: measured
        move.b  %d0, 0x3A0015
        movem.l (%sp)+, %d0-%d7/%a0-%a2/%a4-%a5
        rts

| ----------------------------------------------------------------------------------
| $00 — FORMAT. Measured (point 2, the card that CARD_ERROR formatted then saved):
|   $00-$09 zero, CARD_SIZE $1000, $0C zero, sums $0A and $0A (5 × $02), $0F zero,
|   the name: 16 spaces, CARD_MAGIC at the even bytes, the region at $30;
|   directory: $FF in the 1st byte of the 32 entries; FAT 1 and FAT 2: blocks 0-4 at $02,
|   the rest at $00.
| THE PATTERN FIRST, measured in judging: on exit, every byte outside this structure
| carries the pattern "the word at even offset k is 2k" (point 1: "0000 0004 0008"),
| the old entry 0 and the old block 5 included — the reference fills the card, then
| writes the structure. Hence the odd bytes of CARD_MAGIC, $31-$3F, bytes 1 to 3
| of the entries and the data blocks at the pattern. Even byte k: $hh of 2k; odd k + 1:
| $ll of 2k. ASSUMED: the extent, 2 KiB of bytes (CARD_SIZE $1000, the only geometry
| served), no size being detected.
| RAM, measured in judging: $10FD14 then $10FD16, then the temporaries, without a second
| $10FCF4; a single pair of unlocks.
| THE REGION: BIOS_COUNTRY_CODE ($10FD83), which `c0.s` sets at boot from the
| descriptor; measured $02 under the euro BIOS, and our image declares Europe.
| ASSUMED: the order — pattern, directory, FAT, header, CARD_MAGIC last, so that a reset
| in the middle leaves an unformatted card rather than a half-formatted one; and CARD_SIZE
| $1000 whatever the card, the size coming from the only format recorded.
| ----------------------------------------------------------------------------------
.Lformater:
        btst    #6, 0x380000            | write protection
        bne     .L85
        bsr     .Lpaire
        moveq   #0, %d1                 | the pattern, over the 2 KiB
1:      move.w  %d1, %d0
        andi.w  #0xFFFE, %d0            | k, the even offset of the word
        add.w   %d0, %d0                | 2k
        btst    #0, %d1
        bne.s   2f                      | odd: the low byte
        lsr.w   #8, %d0                 | even: the high byte
2:      bsr     .Lecrire
        addq.w  #1, %d1
        cmpi.w  #0x800, %d1
        bne.s   1b
        moveq   #0x40, %d1
        moveq   #-1, %d0
1:      bsr     .Lecrire                | free entry
        addq.w  #4, %d1
        cmpi.w  #0xC0, %d1
        bne.s   1b
        move.w  #0xC0, %d1              | FAT 1 then FAT 2
2:      moveq   #0, %d0
        moveq   #0x3F, %d2
        and.w   %d1, %d2                | rank in the FAT
        cmpi.w  #5, %d2
        bcc.s   3f
        moveq   #2, %d0                 | blocks 0-4: reserved
3:      bsr     .Lecrire
        addq.w  #1, %d1
        cmpi.w  #0x140, %d1
        bne.s   2b
        lea     _card_entete, %a0
        moveq   #0, %d1
4:      move.b  (%a0)+, %d0
        bsr     .Lecrire
        addq.w  #1, %d1
        cmpi.w  #0x20, %d1
        bne.s   4b
        move.b  0x10FD83, %d0           | BIOS_COUNTRY_CODE → CARD_REGION
        moveq   #0x30, %d1
        bsr     .Lecrire
        lea     _card_magie, %a0
        moveq   #0x20, %d1
5:      move.b  (%a0)+, %d0
        bsr     .Lecrire
        addq.w  #2, %d1
        cmpi.w  #0x30, %d1
        bne.s   5b
        move.w  #0, 0x10FD14            | BIOS_CARD_TYPE: 8 bits
        move.w  #0x1000, 0x10FD16       | BIOS_CARD_SIZE (temporary): CARD_SIZE written
        bsr     .Ltemporaires
        bra     .Lfin

| The eight words $10FD04-$10FD12 ("CARD"), as 68000 addresses; %d6 ← 32 blocks.
.Ltemporaires:
        move.l  #0x800000 + 2 * 0x40, 0x10FD04  | BIOS_CARD_DIRECTORY_START
        moveq   #32, %d6
        move.w  %d6, 0x10FD08           | BIOS_CARD_BLOCK_NUMBER
        move.l  #0x800000 + 2 * 0xC0, 0x10FD0A  | BIOS_CARD_FAT_START (FAT 1)
        move.w  #64, 0x10FD0E           | BIOS_CARD_FAT_SIZE: 64 entries
        move.l  #0x800000 + 2 * 0x140, 0x10FD10 | BIOS_CARD_DATA_START: block 5
        rts

| ----------------------------------------------------------------------------------
| $01 — SEARCH. Measured (point 4): no write to the card; word $10FDD0
| receives the mask of the NGH's sub-saves (bit n = sub-save n), $0000 for an
| absent NGH, answer $00. The FATs are not read again: 48 to 50 reads measured, which
| one pass over the directory explains and which two FAT sums (130 reads)
| would exceed — my own reading of the counts.
| ----------------------------------------------------------------------------------
.Lmasque:
        move.w  0x10FDCE, %d3           | BIOS_CARD_FCB
        moveq   #0, %d2
        moveq   #0x40, %d1
1:      bsr     .Llire
        cmpi.b  #16, %d0
        bcc.s   2f                      | free ($FF), or outside 0-15
        move.b  %d0, %d4
        bsr     .Lngh
        cmp.w   %d3, %d0
        bne.s   2f
        bset    %d4, %d2
2:      addq.w  #4, %d1
        cmpi.w  #0xC0, %d1
        bne.s   1b
        move.w  %d2, 0x10FDD0           | BIOS_CARD_SUB, as a word
        bra     .Lfin

| ----------------------------------------------------------------------------------
| $02 — LOAD. Measured (point 3): no write to the card; after the
| temporaries, $10FDD0, then SIZE bytes to BIOS_CARD_START, then BIOS_CARD_START advanced
| by the size read. 212 reads: both FATs are read again, my own reading of the count.
| Read in "Memory card": a wrong FAT is rewritten from the other one, two wrong ones
| are an error.
| ASSUMED: the value written to $10FDD0, its own (no effect); SUB read as a byte at
| $10FDD0 (measured), outside 0-15 → $82; a chain that ends before SIZE stops the copy
| without error, START advanced by what was read; a block outside 5-31 → $83.
| ----------------------------------------------------------------------------------
.Lcharger:
        bsr     .Lfat_valider
        bne     .L83
        move.b  0x10FDD0, %d2           | BIOS_CARD_SUB, byte
        move.w  0x10FDCE, %d3           | BIOS_CARD_FCB
        cmpi.b  #16, %d2
        bcc     .L82
        bsr     .Lchercher
        tst.w   %d4
        bmi     .L82
        move.w  %d4, %d1
        addq.w  #3, %d1
        bsr     .Llire
        moveq   #0, %d4
        move.b  %d0, %d4                | %d4: the current block
        move.b  0x10FDD0, 0x10FDD0      | the recorded write, value unchanged
        movea.l 0x10FDC8, %a0           | BIOS_CARD_START
        move.w  0x10FDCC, %d5           | BIOS_CARD_SIZE: the rest to read
.Lch_bloc:
        tst.w   %d5
        beq.s   .Lch_fin
        cmpi.w  #5, %d4
        bcs     .L83
        cmp.w   %d6, %d4
        bcc     .L83
        move.w  %d4, %d1
        lsl.w   #6, %d1                 | offset of the block
        moveq   #64-1, %d3
1:      bsr     .Llire
        move.b  %d0, (%a0)+
        addq.w  #1, %d1
        subq.w  #1, %d5
        dbeq    %d3, 1b                 | end of the block, or SIZE reached
        tst.w   %d5
        beq.s   .Lch_fin
        move.w  %d4, %d1
        bsr     .Lfat_lire
        moveq   #0, %d4
        move.b  %d0, %d4
        cmpi.b  #1, %d4
        bne.s   .Lch_bloc               | $01: last block, the copy stops
.Lch_fin:
        move.l  %a0, 0x10FDC8           | START advanced, measured
        bra     .Lfin

| ----------------------------------------------------------------------------------
| $03 — SAVE. Measured (point 4): a save of the same NGH and the same SUB is
| replaced — a free block receives the data, the entry found points to it, the old block
| is freed in both FATs; otherwise a new entry. Order measured: the block number in the
| free entry, then the data, then FAT and entry found.
| The free block: the first from 5 on (measured: 6 when 5 is taken). It is chosen
| before the old one is freed (measured: 6 and not 5).
| ASSUMED: several blocks when SIZE exceeds 64 ("Memory card": size rounded to the
| multiple of 64, blocks chained by the FAT), taken in increasing order; SIZE 0 takes
| one block; the end of the last block stays intact; "the free entry" is the first
| free one before the entry found, otherwise after; not enough free blocks, or neither entry
| found nor free entry → $84; the sums before the entry; a new entry receives
| the NGH then SUB, SUB last since it marks it taken; START does not advance.
| ----------------------------------------------------------------------------------
.Lsauver:
        btst    #6, 0x380000
        bne     .L85
        bsr     .Lfat_valider
        bne     .L83
        move.b  0x10FDD0, %d2
        move.w  0x10FDCE, %d3
        cmpi.b  #16, %d2
        bcc     .L82
        bsr     .Lchercher              | %d4: found, %d5: free
        tst.w   %d4
        bmi.s   1f
        tst.w   %d5
        bpl.s   2f
        move.w  %d4, %d1                | a free entry after the one found
        addq.w  #4, %d1
        bsr     .Lentree_libre
        bra.s   2f
1:      tst.w   %d5
        bmi     .L84                    | neither a save to replace, nor a free entry
2:      moveq   #0, %d0                 | blocks requested: SIZE / 64 rounded up, 1 at least
        move.w  0x10FDCC, %d0
        addi.l  #63, %d0
        lsr.l   #6, %d0
        bne.s   3f
        moveq   #1, %d0
3:      move.w  %d0, %d7
        movea.w %d0, %a2                | %a2: blocks requested
        moveq   #0, %d2                 | free blocks
        moveq   #5, %d3
4:      move.w  %d3, %d1
        bsr     .Lfat_lire
        tst.b   %d0
        bne.s   5f
        addq.w  #1, %d2
5:      addq.w  #1, %d3
        cmp.w   %d6, %d3
        bcs.s   4b
        cmp.w   %d7, %d2
        bcs     .L84                    | card full
        bsr     .Louvrir
        moveq   #5, %d3
        bsr     .Lbloc_libre
        movea.w %d3, %a1                | %a1: first block of the save
        tst.w   %d5
        bmi.s   .Lsv_donnees
        move.w  %d5, %d1                | the block number in the free entry, measured
        addq.w  #3, %d1
        move.b  %d3, %d0
        bsr     .Lecrire
.Lsv_donnees:
        movea.l 0x10FDC8, %a0           | BIOS_CARD_START
        move.w  0x10FDCC, %d2           | the rest to write
.Lsv_bloc:
        move.w  %d3, %d1
        lsl.w   #6, %d1
1:      tst.w   %d2
        beq.s   2f
        move.b  (%a0)+, %d0
        bsr     .Lecrire
        addq.w  #1, %d1
        subq.w  #1, %d2
        moveq   #0x3F, %d0
        and.w   %d1, %d0
        bne.s   1b                      | up to the end of the block
2:      subq.w  #1, %d7
        beq.s   .Lsv_fat
        addq.w  #1, %d3                 | next block: the next free one; the FAT has
        bsr     .Lbloc_libre            | not changed yet
        bra.s   .Lsv_bloc
.Lsv_fat:
        | The chain, in both FATs: the same blocks, found again in the same way.
        move.w  %a2, %d7
        move.w  %a1, %d3
1:      move.w  %d3, %d2                | %d2: the block whose entry we write
        subq.w  #1, %d7
        beq.s   2f
        addq.w  #1, %d3
        bsr     .Lbloc_libre
        move.w  %d2, %d1
        move.b  %d3, %d0
        bsr     .Lfat_ecrire
        bra.s   1b
2:      move.w  %d2, %d1
        moveq   #1, %d0                 | last block
        bsr     .Lfat_ecrire
        tst.w   %d4
        bmi.s   3f
        move.w  %d4, %d1                | the old chain, freed
        addq.w  #3, %d1
        bsr     .Llire
        moveq   #0, %d3
        move.b  %d0, %d3
        bsr     .Lchaine_liberer
3:      bsr     .Lsommes_ecrire
        tst.w   %d4
        bmi.s   4f
        move.w  %d4, %d1                | the entry found points to the new chain
        addq.w  #3, %d1
        move.w  %a1, %d0
        bsr     .Lecrire
        bra.s   5f
4:      move.w  %d5, %d1                | new entry; its block is already set
        addq.w  #1, %d1
        move.b  0x10FDCE, %d0           | NGH, high byte
        bsr     .Lecrire
        addq.w  #1, %d1
        move.b  0x10FDCF, %d0           | NGH, low byte
        bsr     .Lecrire
        move.w  %d5, %d1
        move.b  0x10FDD0, %d0           | SUB
        bsr     .Lecrire
        | $10FDD0 written once at the end, replacement as well as new entry: measured in
        | judging. The value is not; ASSUMED: its own, SUB unchanged (the interface
        | after the call keeps it as is, measured). Byte, as in the load.
5:      move.b  0x10FDD0, 0x10FDD0
        bra     .Lfin

| ----------------------------------------------------------------------------------
| $04 — DELETE. Measured (point 4): 1st byte of the entry ← $FF, its block freed in
| both FATs, sums rewritten ($0A). ASSUMED: entry absent → $82 (read in
| "CARD": "requested data doesn't exist"); the entry before the FAT.
| ----------------------------------------------------------------------------------
.Lsupprimer:
        btst    #6, 0x380000
        bne     .L85
        bsr     .Lfat_valider
        bne     .L83
        move.b  0x10FDD0, %d2
        move.w  0x10FDCE, %d3
        cmpi.b  #16, %d2
        bcc     .L82
        bsr     .Lchercher
        tst.w   %d4
        bmi     .L82
        bsr     .Louvrir
        move.w  %d4, %d1
        addq.w  #3, %d1
        bsr     .Llire
        moveq   #0, %d3
        move.b  %d0, %d3                | first block
        move.w  %d4, %d1
        moveq   #-1, %d0
        bsr     .Lecrire                | free entry
        bsr     .Lchaine_liberer
        bsr     .Lsommes_ecrire
        bra     .Lfin

| $05 — READ THE TITLE: $82, measured on the five tries, without a write (point 4); "CARD"
| marks its entries with a "?", and a present save also answers $82. The meaning
| is therefore not taken: $82, after the detection, always. In the table above.

| ----------------------------------------------------------------------------------
| $06 — WRITE THE NAME. Measured (point 4): $0F ← $FF, $10-$1F ← the first 16 bytes
| of BIOS_CARD_START, in the order in which the record cites them (ASSUMED that it is the
| order of the writes). A single pair of unlocks, measured in judging.
| ----------------------------------------------------------------------------------
.Lnom_ecrire:
        btst    #6, 0x380000
        bne     .L85
        bsr     .Lpaire
        moveq   #0x0F, %d1
        moveq   #-1, %d0
        bsr     .Lecrire                | CARD_USERNAME_AVAILABLE
        movea.l 0x10FDC8, %a0
1:      addq.w  #1, %d1
        move.b  (%a0)+, %d0
        bsr     .Lecrire
        cmpi.w  #0x1F, %d1
        bne.s   1b
        bra     .Lfin

| ----------------------------------------------------------------------------------
| $07 — READ THE NAME. Measured (point 4): no write to the card. Measured in
| judging: $0F at $00 → $82, nothing copied to BIOS_CARD_START; $0F is
| CARD_USERNAME_AVAILABLE (read in "Memory card"). Read in "CARD": $82 also if the
| last character of the name ($1F) is 0 — kept. ASSUMED, not recorded: $0F non-zero and
| $1F non-zero, the 16 bytes go to BIOS_CARD_START.
| ----------------------------------------------------------------------------------
.Lnom_lire:
        moveq   #0x0F, %d1
        bsr     .Llire
        tst.b   %d0
        beq     .L82                    | name absent
        moveq   #0x1F, %d1
        bsr     .Llire
        tst.b   %d0
        beq     .L82
        movea.l 0x10FDC8, %a0
        moveq   #0x10, %d1
1:      bsr     .Llire
        move.b  %d0, (%a0)+
        addq.w  #1, %d1
        cmpi.w  #0x20, %d1
        bne.s   1b
        bra     .Lfin

| ==================================================================================
| THE TOOLS. Offsets in bytes of the card; %a5 = $800000, %d6 = number of blocks.
| ==================================================================================

| %d1 = offset → %d0.b = the byte; %a4 destroyed. Word access, low byte.
.Llire:
        lea     0(%a5,%d1.w), %a4
        adda.w  %d1, %a4
        move.w  (%a4), %d0
        rts

| %d1 = offset, %d0.b = the byte; %a4 destroyed.
.Lecrire:
        lea     0(%a5,%d1.w), %a4
        adda.w  %d1, %a4
        move.w  %d0, (%a4)
        rts

| The two unlocks: two pairs (`.Louvrir`, measured on $03 and $04) or a
| single one (`.Lpaire`, measured on $06); their place, ASSUMED.
.Louvrir:
        bsr     .Lpaire                 | the first pair, then the second by falling through
.Lpaire:
        move.b  %d0, 0x3A0005           | REG_CRDUNLOCK1
        move.b  %d0, 0x3A0017           | REG_CRDUNLOCK2
        rts

| %d1 = entry → %d0.w = its NGH; %d1 given back, %d7 destroyed.
.Lngh:
        addq.w  #1, %d1
        bsr     .Llire
        move.b  %d0, %d7
        lsl.w   #8, %d7
        addq.w  #1, %d1
        bsr     .Llire
        move.b  %d0, %d7
        move.w  %d7, %d0
        subq.w  #2, %d1
        rts

| %d2.b = SUB (0-15), %d3.w = NGH → %d4.w = the entry found, %d5.w = the first free one
| before it, -1 if none; %d0, %d1, %d7 destroyed. Stops at the one found: the count
| of 212 reads of the load suggests it, my own reading.
.Lchercher:
        moveq   #-1, %d4
        moveq   #-1, %d5
        moveq   #0x40, %d1
1:      bsr     .Llire
        cmpi.b  #0xFF, %d0
        bne.s   2f
        tst.w   %d5
        bpl.s   3f
        move.w  %d1, %d5
        bra.s   3f
2:      cmp.b   %d2, %d0
        bne.s   3f
        bsr     .Lngh
        cmp.w   %d3, %d0
        bne.s   3f
        move.w  %d1, %d4
        rts
3:      addq.w  #4, %d1
        cmpi.w  #0xC0, %d1
        bne.s   1b
        rts

| %d1 = first entry to look at → %d5.w = the first free one, -1 if none; %d0, %d1.
.Lentree_libre:
1:      cmpi.w  #0xC0, %d1
        bcc.s   2f
        bsr     .Llire
        cmpi.b  #0xFF, %d0
        beq.s   3f
        addq.w  #4, %d1
        bra.s   1b
2:      moveq   #-1, %d1
3:      move.w  %d1, %d5
        rts

| %d1 = block → %d0.b = its FAT 1 entry; %d1 destroyed.
.Lfat_lire:
        addi.w  #0xC0, %d1
        bra     .Llire

| %d1 = block, %d0.b = value → FAT 1 then FAT 2; %d1 destroyed.
.Lfat_ecrire:
        addi.w  #0xC0, %d1
        bsr     .Lecrire
        addi.w  #0x40, %d1
        bra     .Lecrire

| %d3 = start block → %d3 = the first free block from it on; %d0, %d1. Called
| only when the count of free ones guarantees that one is left.
.Lbloc_libre:
1:      move.w  %d3, %d1
        bsr     .Lfat_lire
        tst.b   %d0
        beq.s   2f
        addq.w  #1, %d3
        bra.s   1b
2:      rts

| %d3 = first block of a chain → its entries at $00 in both FATs; %d0-%d3, %d7.
| Stops on $01, on a block outside 5-31, or after %d6 turns (a FAT that loops).
.Lchaine_liberer:
        move.w  %d6, %d7
1:      cmpi.w  #5, %d3
        bcs.s   2f
        cmp.w   %d6, %d3
        bcc.s   2f
        move.w  %d3, %d1
        bsr     .Lfat_lire
        moveq   #0, %d2
        move.b  %d0, %d2                | the next one
        move.w  %d3, %d1
        moveq   #0, %d0
        bsr     .Lfat_ecrire
        move.w  %d2, %d3
        subq.w  #1, %d7
        bne.s   1b
2:      rts

| %d1 = start of a FAT → %d2.b = the sum of its 64 bytes; %d0, %d1, %d3.
.Lsomme:
        moveq   #0, %d2
        moveq   #64-1, %d3
1:      bsr     .Llire
        add.b   %d0, %d2
        addq.w  #1, %d1
        dbra    %d3, 1b
        rts

| The two sums recomputed and written, $0D then $0E; %d0-%d3.
.Lsommes_ecrire:
        move.w  #0xC0, %d1
        bsr     .Lsomme
        move.b  %d2, %d0
        moveq   #0x0D, %d1
        bsr     .Lecrire
        move.w  #0x100, %d1
        bsr     .Lsomme
        move.b  %d2, %d0
        moveq   #0x0E, %d1
        bra     .Lecrire

| %d1 = start of a FAT, %d4 = offset of its sum → Z if they agree; %d0-%d3.
.Lfat_ok:
        bsr     .Lsomme
        move.w  %d4, %d1
        bsr     .Llire
        cmp.b   %d0, %d2
        rts

| Read in "Memory card": a FAT whose sum is wrong is rewritten from the
| other one; two wrong ones are an error. → %d0 = 0 and Z if at least one FAT is right,
| %d0 = 1 otherwise; %d0-%d5. ASSUMED: the repair is done without looking at the write
| protection, and rewrites both sums.
.Lfat_valider:
        move.w  #0xC0, %d1
        moveq   #0x0D, %d4
        bsr     .Lfat_ok
        seq     %d5                     | %d5: FAT 1 right
        move.w  #0x100, %d1
        moveq   #0x0E, %d4
        bsr     .Lfat_ok
        beq.s   2f
        tst.b   %d5
        beq.s   9f                      | both wrong
        move.w  #0xC0, %d2              | FAT 1 over FAT 2
        move.w  #0x100, %d3
        bra.s   3f
2:      tst.b   %d5
        bne.s   8f                      | both right
        move.w  #0x100, %d2             | FAT 2 over FAT 1
        move.w  #0xC0, %d3
3:      bsr     .Louvrir
        moveq   #64-1, %d4
4:      move.w  %d2, %d1
        bsr     .Llire
        move.w  %d3, %d1
        bsr     .Lecrire
        addq.w  #1, %d2
        addq.w  #1, %d3
        dbra    %d4, 4b
        bsr     .Lsommes_ecrire
8:      moveq   #0, %d0
        rts
9:      moveq   #1, %d0
        rts

| ----------------------------------------------------------------------------------
| CARD_ERROR ($C0046E). Measured (point 5): on a refused save ($03, answer
| $81), the reference formats then redoes the save, without displaying anything. Measured in
| judging (point 4, end), in order:
|   RAM: $10FD00, the word $10FDC6, the word $10FDC4 twice, a complete format, the
|         word $10FDC4, a complete save;
|   registers: those of the format, those of the save, then REG_CRDLOCK2 and
|         REG_CRDLOCK1 once more;
|   interface on exit: $10FDC4 $03, $10FDC5 $03, $10FDC6 $00, $10FDC7 $81.
| The values of the words are not recorded; ASSUMED, those that give this state:
|   $10FDC6 ← $00:answer (the original answer kept at $10FDC7); $10FDC4 ← cmd:cmd
|   (the command kept at $10FDC5), then $00:cmd (format); after the format,
|   cmd:cmd again (the command given back).
| $10FD00 ← SP − 4 of its own call, like CARD: ASSUMED.
| Read in "CARD ERROR" (SP-S2), not measured: the format also applies to $03 on
| $83 and to $06 on $81; we do it — "silently on MVS", says the page.
| ASSUMED: the reference's card test is not taken up (ruled out by the hand-over);
| a format that fails skips the save, the rest of the sequence is done; all
| the other cases — the MESS_OUT messages, the card-full menu — return
| after $10FD00, without doing anything else.
| No register modified.
| ----------------------------------------------------------------------------------
_card_error:
        subq.l  #4, %sp                 | SP − 4, like CARD
        move.l  %sp, 0x10FD00
        addq.l  #4, %sp
        movem.l %d0-%d1, -(%sp)
        move.b  0x10FDC4, %d0           | BIOS_CARD_COMMAND
        moveq   #0, %d1
        move.b  0x10FDC6, %d1           | BIOS_CARD_ANSWER
        cmpi.b  #3, %d0
        bne.s   1f
        cmpi.b  #0x81, %d1
        beq.s   2f
        cmpi.b  #0x83, %d1
        beq.s   2f
        bra.s   9f
1:      cmpi.b  #6, %d0
        bne.s   9f
        cmpi.b  #0x81, %d1
        bne.s   9f
2:      move.w  %d1, 0x10FDC6           | $00:answer
        move.b  %d0, %d1
        lsl.w   #8, %d1
        move.b  %d0, %d1                | %d1: cmd:cmd
        move.w  %d1, 0x10FDC4           | the command kept at $10FDC5
        andi.w  #0x00FF, %d1
        move.w  %d1, 0x10FDC4           | $00: format
        bsr     _card
        move.b  %d0, %d1
        lsl.w   #8, %d1
        move.b  %d0, %d1
        move.w  %d1, 0x10FDC4           | the command given back
        tst.b   0x10FDC6
        bne.s   8f                      | format refused: no save
        bsr     _card
8:      move.b  %d0, 0x3A0007           | REG_CRDLOCK2, then REG_CRDLOCK1: measured
        move.b  %d0, 0x3A0015
9:      movem.l (%sp)+, %d0-%d1
        rts

| ----------------------------------------------------------------------------------
| THE CARD RECORD, for the manager of the TEST screen (`gestion-carte.s`): what
| the card carries, without writing anything to it or touching CARD's interface in BIOS RAM.
| Input: %a0 = a 192-byte buffer. Output: %d0.b = the state, with the codes of
| BIOS_CARD_ANSWER — $00 formatted (the buffer receives bytes $40-$FF of the card: the
| directory, then FAT 1), $80 no card, $81 unformatted, $85 another geometry
| that CARD refuses. The same criteria as CARD: the detection, CARD_MAGIC, CARD_SIZE.
| The card registers as for a load: REG_CRDNORMAL, REG_CRDBANK ← 0, then
| REG_CRDLOCK2, REG_CRDLOCK1; without a card, the two locks alone, like CARD.
| ASSUMED: that FAT 1 tells the truth; a FAT 1 whose sum is wrong is repaired only
| by the next command that writes (`.Lfat_valider`), and the record shows it as is.
| Clobbers %d0 only.
| ----------------------------------------------------------------------------------
_carte_releve:
        movem.l %d1-%d7/%a0-%a5, -(%sp)
        movea.l %a0, %a1                | %a1: the buffer
        moveq   #0, %d7
        move.b  #0x80, %d7
        btst    #4, 0x380000            | CD1
        bne.s   9f
        btst    #5, 0x380000            | CD2
        bne.s   9f
        move.b  %d0, 0x3A0019           | REG_CRDNORMAL
        move.b  #0x00, 0x380011         | REG_CRDBANK ← 0
        lea     0x800000, %a5
        move.b  #0x81, %d7
        lea     _card_magie, %a2
        moveq   #0x20, %d1
1:      bsr     .Llire
        cmp.b   (%a2)+, %d0
        bne.s   9f                      | unformatted
        addq.w  #2, %d1
        cmpi.w  #0x30, %d1
        bne.s   1b
        move.b  #0x85, %d7
        moveq   #0x0A, %d1              | CARD_SIZE
        bsr     .Llire
        move.b  %d0, %d6
        lsl.w   #8, %d6
        moveq   #0x0B, %d1
        bsr     .Llire
        move.b  %d0, %d6
        cmpi.w  #0x1000, %d6
        bne.s   9f                      | other geometry
        moveq   #0, %d7
        moveq   #0x40, %d1
2:      bsr     .Llire
        move.b  %d0, (%a1)+
        addq.w  #1, %d1
        cmpi.w  #0x100, %d1
        bne.s   2b
9:      move.b  %d0, 0x3A0007           | REG_CRDLOCK2, then REG_CRDLOCK1
        move.b  %d0, 0x3A0015
        move.l  %d7, %d0
        movem.l (%sp)+, %d1-%d7/%a0-%a5
        rts

| ----------------------------------------------------------------------------------
| THE DATA. CARD_MAGIC, its eight even bytes (read in "Memory card", measured
| point 2). The header $00-$1F of a formatted card, measured point 2: the sum $0A is
| that of five reserved blocks, 5 × $02.
| ----------------------------------------------------------------------------------
_card_magie:
        .ascii  "NEO-GEO"
        .byte   0x80
_card_entete:
        .byte   0, 0, 0, 0, 0, 0, 0, 0, 0, 0    | $00-$09
        .byte   0x10, 0x00                      | $0A: CARD_SIZE $1000
        .byte   0x00                            | $0C
        .byte   0x0A, 0x0A                      | $0D, $0E: FAT sums
        .byte   0x00                            | $0F: name absent
        .ascii  "                "              | $10-$1F: 16 spaces
        .balign 2
