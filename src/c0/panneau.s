| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| P1 IN THE BIOS SCREENS — a joystick, or the mahjong panel translated into a joystick.
|
| On 2026-10-28 (DECISIONS §30). Hand-over: "Couche 3 → les menus au panneau de mahjong,
| le 2026-10-28" (`docs/RELECTURE-CONTRATS.md`). NO ORACLE: the code of the reference BIOSes
| is not read; their behaviour comes from the black-box record
| `measured/2026-10-28-panneau-menus-reference.tsv`.
|
| THREE KINDS OF CLAIMS, and each one says so:
|   "measured":  that record, named;
|   "read in":   a page of the NeoGeo Development Wiki, named;
|   "ASSUMED":   neither one nor the other, and it is said.
|
| WHAT THESE ROUTINES REPLACE: the read of REG_P1CNT ($300000) that each screen did
| itself (`ecran.s`, `dip.s`, `tests.s`, `jukebox.s`, `gestion-carte.s`, `debug.s`, `menu.s`
| and its sub-screens through `_mn_entrees`). These screens read the register as it was, under the
| REG_POUTPUT output ($380001, "Joypad ports outputs", "Memory mapped registers") that another had
| left: the panel, which only answers for the chosen row, drove nothing there (DECISIONS §24 pt 4).
| Still read as they are, and it is intended: the guards of the BlueRetro adapter (`dip.s`,
| `menu.s`, `cmpi.b #0x10`), which judge a gesture made on a joystick before any opening; the
| INPUT TEST pages (`tests.s`), which display the raw register; and P2, which stays a joystick.
|
| SWITCH 3, "Mahjong Panel" (REG_DIPSW $300001 bit 2, active low; neogeo.cpp, SW:3), READ
| AT OPENING AND NOT AFTER (`_panneau_verrou`). MEASURED (record, section "commutateur3"): the
| Japanese SNK BIOS takes it at the opening of its test menu, UniBIOS 4.0 at boot; flipped with the
| menu open, the translation stays in both. The Japanese SNK BIOS's behaviour is followed (DECISIONS §30 pt 3).
| WHERE THE LATCH IS SET: at the entry of each screen that is OPENED from the game or the boot, never
| at that of a sub-screen — the boot screen (`ecran.s`), the TEST button editor (`dip.s`, from which
| open the self-tests, the jukebox, the memory card, the cabinet and the debug dips), the self-tests
| of an MV-1 without cartridge (`c0.s`, `_sans_cartouche`), and the in-game menu (`menu.s`, from which
| open GAME SETTINGS, MEMORY EDITOR and AUTOFIRE). A sub-screen therefore inherits the value of
| the screen that opens it, and returning there does not reread it. Ruled out: rereading it in `_panneau_p1`, at
| each frame, which would change the translation of an open menu; taking it at boot only,
| like UniBIOS, which the decision did not retain. Also ruled out: BIOS_P1STATUS ($10FD94), which
| `_commutateurs` (`c0.s`) sets at each hand-over to the game — read at the hand-over, not at
| the opening, and not yet set at the first screen of the boot.
|
| THE TRANSLATION, SWITCH ON. MEASURED (record, sections "menu" and "calendrier"): in the
| menus of the two references, the panel's A, B, C, D act as buttons A, B, C, D; E goes up, F
| goes down, G goes left, H right; the other keys, I to N and PON to REACH, do nothing;
| START stays START (REG_STATUS_B, which this routine does not read). MEASURED (same record, "lecture
| brute"): under MAME, REG_POUTPUT ← $09 returns in REG_P1CNT the A-G row at bits 0-6, active
| low, A at bit 0; ← $12 the H-N row, H at bit 0. The returned byte is in the REG_P1CNT format
| ("Memory mapped registers": bits 0 up, 1 down, 2 left, 3 right, 4-7 A, B, C, D, active
| low): under $09, bits 0-3 go to bits 4-7 and bits 4-6 to bits 0-2 — a rotation
| by four —, then bit 3 is taken from bit 0 of the H-N row. ASSUMED: bit 7 of the
| A-G row, which no key lights in the record, is unused; it is replaced.
| A JOYSTICK on this switch does not read REG_POUTPUT (neogeo.cpp, io_control_w; mahjong.cpp,
| read_ctrl): it goes through the same translation, up acts as A and right, A acts as up, B down, C left,
| D nothing. This is what the references do on this switch (ASSUMED for a joystick: the
| record only played the panel).
|
| SWITCH OFF: REG_POUTPUT ← $1B then REG_P1CNT as it is, like `_io_lire` (`io.s`,
| DECISIONS §21 pt 4). MEASURED (record, sections "menu" and "lecture brute"): under $1B, the
| A-G and H-N rows merged; in the menus of the two references, A/H up, B/I down, C/J
| left, D/K right, E/L button A, F/M button B, G/N button C, no key for button D.
| On a joystick, this output changes nothing.
|
| THE OUTPUT LEFT in REG_POUTPUT ($12 when ON, $1B when OFF) on leaving a screen: the game sets its
| own at each SYSTEM_IO before reading (`_io_lire`, `_io_mahjong`), as after the panel page
| of INPUT TEST (DECISIONS §24 pt 2). ASSUMED: that no game reads REG_P1CNT itself
| before its first SYSTEM_IO without setting an output.
|
| THE DELAY between the write of the output and the read: none, like `_io_mahjong` (`io.s`), which
| the record of 2026-10-27 validated under MAME. ASSUMED on the hardware.
| ==================================================================================

        .section .haut, "ax"
        .global _panneau_verrou
        .global _panneau_p1

        .equ    P1CNT,    0x300000
        .equ    DIPSW,    0x300001      | when read: the board switches, active low
        .equ    POUTPUT,  0x380001
        | The latch: $FF switch 3 ON, $00 OFF. In the area of `menu.s` measured free
        | ($10F4B4-$10FBFF: no game write), between the debug dips ($10FB22-$10FB27,
        | `debug.s`) and the autofire ($10FB40-$10FB51, `autofire.s`); above the copy of the
        | editor's soft-DIP block ($10F464-$10FAFF, `dip.s`) and within what the work RAM test
        | keeps ($10F000-$10FFFF, `tests.s`). Reset to zero by the boot clearing (`c0.s`):
        | OFF until the first latch, the boot screen.
        .equ    PANNEAU,  0x10FB28

| ----------------------------------------------------------------------------------
| THE LATCH: switch 3 read once, at the opening of a screen (see the header). Destroys
| no register, only the condition codes.
_panneau_verrou:
        btst    #2, DIPSW               | bit 2 at 0: ON
        seq     PANNEAU
        rts

| ----------------------------------------------------------------------------------
| P1. Output: %d0.b, P1's byte in the REG_P1CNT format, active low — a joystick, or the panel
| translated according to the latch (see the header). Writes REG_POUTPUT. Destroys %d0 only.
_panneau_p1:
        tst.b   PANNEAU
        bne.s   1f
        move.b  #0x1B, POUTPUT          | OFF: the A-G and H-N rows merged
        move.b  P1CNT, %d0
        rts
1:      move.b  #0x09, POUTPUT          | ON: the A-G row
        move.b  P1CNT, %d0
        rol.b   #4, %d0                 | A-D at bits 4-7 (buttons), E, F, G at bits 0-2
        bset    #3, %d0                 | right released…
        move.b  #0x12, POUTPUT          | the H-N row
        btst    #0, P1CNT               | H, bit 0
        bne.s   2f
        bclr    #3, %d0                 | …unless H held
2:      rts
