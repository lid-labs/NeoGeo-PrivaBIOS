| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| THE BIOS SETTINGS IN BACKUP RAM — the region, the MVS / AES mode since 2026-10-23,
| SCORE RESET (the frozen date for the games, `cal.s`) since 2026-10-24, and the cabinet
| settings (FREE PLAY, NO CONTINUE, DEMO SOUND, CABINET SETTINGS sub-screen of `dip.s`) since
| 2026-10-25, CHEATS/DEBUG included (the same day, `cheats.s`, `menu.s`).
|
| The hand-over is "Couche 3 → la région à chaud et la sauvegarde des réglages du BIOS, le
| 2026-10-20" (`docs/RELECTURE-CONTRATS.md`). "measured": a named record; "read in":
| a page of the NeoGeo Development Wiki; "ASSUMED": neither.
|
| THE LOCATION: $D00210-$D0021F, sixteen bytes just below the soft-DIP blocks ($D00220).
| Read in "Backup RAM": $D001A8-$D0021F is not documented there; the page places neither
| cell nor table there. Outside everything our code writes: `_bram_vider` stops at
| $D0007F, the slot table is $D00124-$D00143, the soft-DIP blocks start at
| $D00220, `io.s` and `card.s` stay below $D00060. Measured under MAME on 2026-10-20, our
| image without settings, write tap on $D00000-$D0FFFF (`bench/bram-ecrivains.lua`),
| ~3,700 frames of coins and START on 21 games of the corpus (garou: MAME segfault before
| the record): no write, neither by the game nor by the BIOS, in $D00150-$D0021F. The games
| write only from $D00320 on (kof98, mslug3), their blocks.
|   ASSUMED: that no other game in the catalogue writes there, and that the reference BIOS
|   stores nothing there that a pass through it on the same NVRAM would leave — the signature
|   and the sum below fall back on the descriptor in that case.
|
| THE FORMAT, our own:
|   $D00210-$D00215  "REBIOS", the signature
|   $D00216          the region: 0 Japan, 1 USA, 2 Europe ("BIOS RAM locations",
|                    BIOS_COUNTRY_CODE)
|   $D00217          the mode: 1 MVS, 2 AES; 0, the value of a block from before this setting, and
|                    any other value: no setting, the descriptor $C00400 stands
|   $D00218          SCORE RESET: 0 ON, the games read the real date; 1 OFF, they read the
|                    frozen date that follows; any other value counts as ON
|   $D00219-$D0021C  the frozen date: year, month, day (BCD), day of week — the date of
|                    the clock when SCORE RESET was switched to OFF; zero otherwise
|   $D0021D          the cabinet, one bit per setting: 0 FREE PLAY, 1 NO CONTINUE, 2 DEMO SOUND
|                    OFF, 3 CHEATS/DEBUG OFF; the other bits zero, ignored. Zero in a block
|                    from before these settings: all at their default, CHEATS/DEBUG at ON included
|   $D0021E          reserved for future settings, written as zero
|   $D0021F          the check: the sum of bytes $D00216-$D0021F is $FF
| Valid: signature, check, and a region from 0 to 2. Otherwise we fall back on the descriptor
| ($C00401 for the region, $C00400 for the mode). A future setting will take a reserved
| byte, and must be copied as is by every writer of the block: `.Lecrire` rereads the
| block before rewriting the sum.
|
| THE MODE IS NOT THE MACHINE. It says what BIOS_MVS_FLAG ($10FD82) announces to the games
| ("BIOS RAM locations": "System type. 0:AES, 0x80:MVS"); the board remains an MVS, which the
| hardware itself says (REG_STATUS_B bit 7, read by `ecran.s` and `menu.s`). AES mode on an
| MVS board is the intended departure of `docs/DECISIONS.md` §11.
| ==================================================================================

        .section .haut, "ax"
        .global _reglages_region
        .global _reglages_mode
        .global _reglages_ecrire_region
        .global _reglages_ecrire_mode
        .global _reglages_scores
        .global _reglages_ecrire_scores
        .global _reglages_borne
        .global _reglages_ecrire_borne
        .global _borne_remise

        .equ    BLOC,     0xD00210
        .equ    REGION,   0xD00216
        .equ    MODE,     0xD00217
        .equ    SCORES,   0xD00218
        .equ    GEL,      0xD00219
        .equ    BORNE_BR, 0xD0021D
        .equ    CONTROLE, 0xD0021F

| THE REGION OF THE SETTINGS. Output: %d0.b the region (0-2) if the block is valid, $FF otherwise.
| Read only: the backup RAM is read locked (REG_SRAMLOCK protects only
| writing, read in "Memory mapped registers"). Clobbers %d0, %d1, %a0, %a1.
_reglages_region:
        bsr.s   .Lvalide
        bne.s   .Linvalide
        move.b  REGION, %d0
        rts
.Linvalide:
        moveq   #-1, %d0
        rts

| THE MODE OF THE SETTINGS. Output: %d0.b the value of BIOS_MVS_FLAG it asks for, $80 (MVS)
| or $00 (AES), and $FF without a setting. Read only. Clobbers %d0, %d1, %a0, %a1.
_reglages_mode:
        bsr.s   .Lvalide
        bne.s   .Linvalide
        move.b  MODE, %d0
        subq.b  #1, %d0
        beq.s   1f                      | 1: MVS
        subq.b  #1, %d0
        bne.s   .Linvalide              | neither 1 nor 2: no setting
        rts                             | 2: AES, %d0 = $00
1:      move.b  #0x80, %d0
        rts

| SCORE RESET. Output: %d0.b 1 if the block is valid and the games' date frozen (OFF), 0
| otherwise. Read only. Clobbers %d0, %d1, %a0, %a1.
_reglages_scores:
        bsr.s   .Lvalide
        bne.s   1f
        cmpi.b  #1, SCORES
        bne.s   1f
        moveq   #1, %d0
        rts
1:      moveq   #0, %d0
        rts

| IS THE BLOCK VALID? Z set if the signature, the check and the region are.
| Clobbers %d0, %d1, %a0, %a1.
.Lvalide:
        lea     BLOC, %a0
        lea     .Lsignature, %a1
        moveq   #6-1, %d1
1:      cmpm.b  (%a1)+, (%a0)+
        dbne    %d1, 1b
        bne.s   9f
        moveq   #0, %d0                 | %a0 is on $D00216: the sum of the ten bytes
        moveq   #10-1, %d1
2:      add.b   (%a0)+, %d0
        dbra    %d1, 2b
        cmpi.b  #0xFF, %d0
        bne.s   9f
        cmpi.b  #2, REGION
        bhi.s   9f
        moveq   #0, %d0                 | Z = 1
        rts
9:      moveq   #-1, %d0                | Z = 0
        rts

| WRITE THE REGION %d0.b (0-2), the block's mode kept if it is valid. The backup RAM must be
| unlocked by the caller. Clobbers %d0-%d3, %a0, %a1.
_reglages_ecrire_region:
        move.b  %d0, %d2
        moveq   #0, %d3                 | invalid block: no mode
        bsr.s   .Lvalide
        bne.s   .Lecrire
        move.b  MODE, %d3
        bra.s   .Lecrire

| WRITE THE MODE %d0.b (1 MVS, 2 AES), the block's region kept if it is valid, otherwise the
| current region (BIOS_COUNTRY_CODE, the descriptor's: without a valid block, `c0.s` has
| set no other). Unlocked by the caller. Clobbers %d0-%d3, %a0, %a1.
_reglages_ecrire_mode:
        move.b  %d0, %d3
        move.b  0x10FD83, %d2
        bsr.s   .Lvalide
        bne.s   1f
        move.b  REGION, %d2
1:      cmpi.b  #2, %d2
        bls.s   .Lecrire
        moveq   #2, %d2                 | outside 0-2: Europe, as `c0.s`
| THE BLOCK REWRITTEN: %d2 the region, %d3 the mode. Valid block: the reserved bytes are kept;
| otherwise they go to zero. The signature last, as `c0.s` does for its own: a reset
| in the middle leaves an invalid block.
.Lecrire:
        bsr.s   .Lvalide
        lea     BLOC, %a0
        beq.s   1f
        clr.l   4(%a0)                  | invalid: all to zero; $D00210-13 just after
        clr.l   8(%a0)
        clr.l   12(%a0)
1:      clr.l   (%a0)                   | the signature destroyed first
        move.b  %d2, REGION
        move.b  %d3, MODE
| THE BLOCK SEALED, %a0 on BLOC and the signature destroyed: the sum, then the signature.
.Lsceller:
        moveq   #0, %d1                 | the sum of bytes $D00216-$D0021E
        lea     REGION, %a1
        moveq   #9-1, %d2
2:      add.b   (%a1)+, %d1
        dbra    %d2, 2b
        not.b   %d1                     | with the check, the sum is $FF
        move.b  %d1, CONTROLE
        lea     .Lsignature, %a1
        moveq   #6-1, %d2
3:      move.b  (%a1)+, (%a0)+
        dbra    %d2, 3b
        rts

| WRITE SCORE RESET %d0.b (0 ON, 1 OFF); at OFF, the current date ($10FDD2-$10FDD5, which
| the caller has just read through `_read_calendar`) becomes the frozen date. Valid block: region and
| mode kept; otherwise a new block, the current region (BIOS_COUNTRY_CODE) and no mode. The
| signature destroyed first, as in `.Lecrire`. Unlocked by the caller. Clobbers %d0-%d3,
| %a0-%a2.
_reglages_ecrire_scores:
        move.b  %d0, -(%sp)
        bsr     .Lvalide
        beq.s   1f
        move.b  0x10FD83, %d2
        cmpi.b  #2, %d2
        bls.s   2f
        moveq   #2, %d2                 | outside 0-2: Europe, as `c0.s`
2:      moveq   #0, %d3
        bsr     .Lecrire                | a new block, valid
1:      lea     BLOC, %a0
        clr.l   (%a0)                   | the signature destroyed first
        move.b  (%sp)+, %d0
        move.b  %d0, SCORES
        lea     GEL, %a1
        lea     0x10FDD2, %a2
        moveq   #4 - 1, %d1
3:      moveq   #0, %d2
        tst.b   %d0
        beq.s   4f
        move.b  (%a2), %d2              | at OFF: the current date
4:      move.b  %d2, (%a1)+
        addq.l  #1, %a2
        dbra    %d1, 3b
        bra     .Lsceller

| ----------------------------------------------------------------------------------
| THE CABINET — FREE PLAY, NO CONTINUE, DEMO SOUND (the CABINET SETTINGS sub-screen of `dip.s`).
| Measurements: `measured/2026-10-25-free-play.tsv`; departures: `docs/DECISIONS.md` §15.
|
| THE COPY IN RAM, BORNE ($10FB20, .b): what `io.s` reads at every START and every refusal by
| CREDIT_CHECK, without revalidating the block. In the zone of `menu.s` measured free
| ($10F4B4-$10FBFF: no game writes there), above the memory editor ($10FB1C-$10FB1F); reset to
| zero by the boot clear, then set here. Bits:
|   0 FREE PLAY, 1 NO CONTINUE, 2 DEMO SOUND OFF — those of the block, but zero in AES mode;
|   3 CHEATS/DEBUG OFF — the block's, in both modes: the in-game menu exists in AES too;
|   7 CREDIT_CHECK refuses no request: AES mode (DECISIONS §11, point 10) or FREE PLAY.
| IN AES MODE, ALL THREE ARE INERT. FREE PLAY: START already goes there without credit and the
| coin is ignored (D2). NO CONTINUE: there is no paid continue. DEMO SOUND: measured on 2026-10-25,
| aof in AES mode plays its demo sound with $D00046 at 1 as at 0 (RMS 2,688 in both cases,
| record above) — the game does not read the cell in AES.
        .equ    BORNE,    0x10FB20

| THE CABINET OF THE SETTINGS. Output: %d0.b the block's bits if it is valid (bits 0-3), 0 otherwise.
| Read only. Clobbers %d0, %d1, %a0, %a1.
_reglages_borne:
        bsr     .Lvalide
        bne.s   1f
        moveq   #0x0F, %d0
        and.b   BORNE_BR, %d0
        rts
1:      moveq   #0, %d0
        rts

| THE COPY IN RAM SET (see above), from the block and BIOS_MVS_FLAG ($10FD82): at boot, after
| the mode (`c0.s`), and on leaving the editor (`dip.s`). Returns all registers.
        .global _borne_ram
_borne_ram:
        movem.l %d0-%d1/%a0-%a1, -(%sp)
        bsr.s   _reglages_borne
        tst.b   0x10FD82
        bmi.s   1f
        andi.b  #0x08, %d0              | AES mode: the three inert, CHEATS/DEBUG kept
1:      btst    #0, %d0
        bne.s   2f
        tst.b   0x10FD82
        bmi.s   3f
2:      bset    #7, %d0                 | FREE PLAY or AES: CREDIT_CHECK refuses nothing
3:      move.b  %d0, BORNE
        movem.l (%sp)+, %d0-%d1/%a0-%a1
        rts

| WRITE THE CABINET %d0.b (bits 0-3); region, mode and SCORE RESET kept if the block is valid,
| otherwise a new block, as `_reglages_ecrire_scores`. Unlocked by the caller. Clobbers
| %d0-%d3, %a0, %a1.
_reglages_ecrire_borne:
        move.b  %d0, -(%sp)
        bsr     .Lvalide
        beq.s   1f
        move.b  0x10FD83, %d2
        cmpi.b  #2, %d2
        bls.s   2f
        moveq   #2, %d2                 | outside 0-2: Europe, as `c0.s`
2:      moveq   #0, %d3
        bsr     .Lecrire                | a new block, valid
1:      lea     BLOC, %a0
        clr.l   (%a0)                   | the signature destroyed first
        move.b  (%sp)+, %d0
        andi.b  #0x0F, %d0
        move.b  %d0, BORNE_BR
        bra     .Lsceller

| DEMO SOUND AT THE HAND-OVER — called by both hand-overs to the game (`_logo_aes`, `c0.s`),
| %d2 the request. "Backup RAM" (NeoGeo Development Wiki): $D00046 "Demo sound (1=Without)",
| and SOUND_STOP, "No sound at all if non-zero (except coinage sound effect)". It is the games that
| read it: measured on 2026-10-25 (`measured/2026-10-25-free-play.tsv`, section 3), twelve games
| out of twelve silent in demo under our image as under the SNK BIOS with $D00046 at 1, the coin
| sound kept; the title after the coin silent too (aof: RMS 618, the coin alone, against 2,143),
| and the game not (RMS equal to within 1%). The SNK BIOS leaves the cell at 1 throughout; here
| it is 1 only at a DEMO hand-over (request 2) with DEMO SOUND OFF, 0 at any other: the
| title after a coin gets its music back (aof, cell reset to 0 at the coin: RMS 2,125,
| 88 key-ons, as without the setting). Intended departure, DECISIONS §15. The cell is written
| only if it changes: with DEMO SOUND ON and a cell at 0, one read and nothing else. Returns all
| registers; the backup RAM is left locked.
_borne_remise:
        move.l  %d0, -(%sp)
        moveq   #0, %d0
        cmpi.b  #2, %d2
        bne.s   1f                      | not a demo: the sound
        btst    #2, BORNE
        beq.s   1f                      | DEMO SOUND ON (or AES mode)
        moveq   #1, %d0                 | "1=Without"
1:      cmp.b   0xD00046, %d0
        beq.s   9f
        move.b  %d0, 0x3A001D           | REG_SRAMUNLOCK
        move.b  %d0, 0xD00046
        move.b  %d0, 0x3A000D           | REG_SRAMLOCK
9:      move.l  (%sp)+, %d0
        rts

.Lsignature:
        .ascii  "REBIOS"
        .balign 2
