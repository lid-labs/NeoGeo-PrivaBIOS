| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| LAYER 0 OF THE BIOS — power-on.
|
| Four regions in the image, at offsets that are not a matter of choice:
|
|   $C00000  the 68000 vector table, which the board also serves at $000000 on reset;
|   $C00400  the two-byte descriptor: machine type, then nationality;
|   $C00402  the entry point, where the reset vector leads;
|   $C00438  the BIOS call table, `rts` entries except SYSTEM_RETURN, SYSTEM_INT1
|            (`int1.s`), SYSTEM_IO and CREDIT_CHECK (`io.s`), READ_CALENDAR (`cal.s`), CARD
|            and CARD_ERROR (`card.s`), FIX_CLEAR and LSP_1st (`video.s`), MESS_OUT (`mess.s`).
|
| And a sequence: REG_SWPBIOS ($3A0003) then REG_BRDFIX ($3A000B), then slot detection —
| REG_SLOT ($380021) on each one, the table $D00124, the first new slot served, otherwise
| the first occupied one —, then the slot hand-over: the sound handshake — $01 on
| REG_SOUND and waiting for its echo —, REG_SLOT, REG_CRTFIX ($3A001B), REG_SWPROM
| ($3A0013) — which puts the cartridge P-ROM at the bottom of the board in place of the
| BIOS's 128 bytes —, $03, then the hand-over to the cartridge's USER routine, at
| $000122: initialisation request (or demo, known slot), framed by the writes to $10FD80,
| $10FDAF and $10FDAE that the protocol record shows around each hand-over. The other new
| slots receive theirs one after the other, through SYSTEM_RETURN, each by the same
| passage.
|
| WHAT IT DOES NOT DO, and this is deliberate: no RAM, palette or VRAM test, no calendar
| initialisation — the boot screen (`ecran.s`) only reads it —, no checksum computation,
| no eyecatcher music ($02), and no interrupt handler installed — it only acknowledges,
| once, those the chip leaves pending on leaving reset.
|
| THE ADDRESS $C00402 IS NOT A CHOICE. The 68000 takes its reset PC from the table
| below, but a Neo Geo cartridge header also carries $C00402 at its offset $0004: it is
| the entry address that the hardware and the cartridges expect from the BIOS. So the
| entry point goes there, and the code itself further on.
|
| Sources of the addresses and semantics, all public (NeoGeo Development Wiki):
|   - registers $3A00xx, $3C000C, $320000   : "Memory mapped registers"
|   - sound commands $01 and $03, their echo : "68k/Z80 communication"
|   - kicking the watchdog, its duration     : "Watchdog"
|   - the idiom `move.b d0,REG_DIPSW`        : "Hello world tutorial"
|   - REG_IRQACK bits, IRQ levels           : "68k interrupts"
|   - descriptor $400-$401                 : "System ROM"
|   - cartridge header and $0122           : "68k program header"
|   - USER routine and its requests        : "USER subroutine"
|   - variables $10FCEE-$10FEFC            : "BIOS RAM locations"
|   - call table $C004xx                   : "BIOS calls"
|   - vector table                         : "68k vector table"
|
| And a measured record, `specs/traces/protocole.md`: the reference BIOS's writes to
| $10FD80, $10FDAE, $10FDAF and $320000 around its hand-over to $000122.
|
| What has neither source nor measurement — the choice of the request that SYSTEM_RETURN
| relaunches, and the values of the hand-overs the record does not cover — is marked
| ASSUMED where it is.
| ==================================================================================

| ----------------------------------------------------------------------------------
| EVERYTHING FITS IN `.vectors`, AND THAT IS INTENDED. The four regions are at imposed
| offsets, and `build/bios.ld` places only one section at offset 0 of the image:
| `.vectors`. Reaching them by `.org` from a single section start is the only way to
| answer for them — splitting the file between `.vectors` and `.text` would let the linker
| decide the gap between the two. `.text` therefore comes out of the ELF empty, and that
| is normal.
|
| The flag is `"a"` and not `"ax"`: it is the one in `build/harnais/harnais.s`, and
| `objcopy -O binary` copies the allocated sections without looking at their execute bit.
| Measured: both flags give the same image, to the sha256.
| ----------------------------------------------------------------------------------
        .equ    BIOS_LOGO, 0x10FB08     | request 1 of the AES mode (`_logo_aes`)
        .section .vectors, "a"

| ----------------------------------------------------------------------------------
| THE VECTOR TABLE — 32 vectors, $000000 to $00007F.
|
| Only these 128 bytes are served at $000000, so the table stops at the level 1 to 7
| autovectors ($64-$7C): the TRAPs, which start at $80, would already fall in the
| cartridge P-ROM.
|
| Vectors 2 to 31 each lead to their own entry point of the crash screen (`plantage.s`),
| which therefore knows the exact exception. On reset the 68000 masks interrupts
| (SR = $2700) and the BIOS does not unmask them while this table is active: only the
| error exceptions remain, which would signal a BIOS defect. The screen shows them; an
| exception raised by the screen itself falls into a loop identifiable in the trace
| (`_plantage_double`), which replaces the old trap.
| ----------------------------------------------------------------------------------
        .long   0x10F300                | vector 0: supervisor stack, below the BIOS RAM
        .long   _reset                  | vector 1: reset PC, i.e. $C00402
        .irp    n, 2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
        .long   _pl_v\n                 | vectors 2 to 31
        .endr

| ----------------------------------------------------------------------------------
| THE DESCRIPTOR — $C00400 and $C00401.
|
| "System ROM" gives these two bytes: the first carries the machine type (0 = AES,
| $80 = MVS), the second the nationality (0 = Japan, 1 = US, 2 = Europe). The page writes
| them $000400 and $000401, i.e. offsets $400 and $401 of the system ROM image, hence
| $C00400 and $C00401 once the ROM is mapped — it does not state this equivalence
| itself, it is the offset in the image that makes it necessary, the bottom of the board
| belonging to the BIOS only over its first 128 bytes.
|
| It is the image's only declaration of identity, and the boot copies it into $10FD82
| and $10FD83 below. Without this cross-reference, the same two facts would be asserted
| in two places and nothing would say which one is authoritative.
|
| EUROPE, NOT JAPAN. On the bench the image stands in for the euro BIOS, and games read
| BIOS_COUNTRY_CODE at their init to choose their path. Measured under MAME: the euro
| reference publishes $10FD83 = $02; under $00, `neomrdo` stays black, `flipshot` freezes
| and `kof98` stays black, and all three run again when $10FD83 is forced to $02.
| ----------------------------------------------------------------------------------
        .org    0x400
        .byte   0x80                    | $C00400: machine type — MVS
        .byte   0x02                    | $C00401: nationality — Europe

| ----------------------------------------------------------------------------------
| THE ENTRY POINT, at $C00402.
|
| The entry area runs from $C00402 to $C00437, i.e. 54 bytes. "BIOS calls" writes it
| "$C00402 to $C00432": $C00432 is the address of the last of its nine six-byte slots
| ($402 + 6 x 8), not its last byte — the next slot, $C00438, is already SYSTEM_INT1.
| The first slot is power-on: a jump, the code lives further down.
|
| THE OTHER EIGHT, TO THE CRASH SCREEN. Read in "68k vector table", template "For
| cartridge systems", and measured on 20 cartridges of the corpus: a cartridge's
| exception vectors lead there — the detail, slot by slot, is in `plantage.s`. Left at
| zero, they let execution slide down to SYSTEM_INT1 (measured on b2b,
| `measured/2026-10-17-diagnostic-b2b-minasan.tsv`, point 1). An absolute `jmp` is
| exactly the six bytes of a slot.
| ----------------------------------------------------------------------------------
        .org    0x402
        .global _reset                  | `build/bios.ld` takes this symbol as the ELF entry
_reset:
        jmp     _demarrage
        .org    0x408
        jmp     _pl_c408                | bus error
        .org    0x40E
        jmp     _pl_c40e                | address error (template: illegal too)
        .org    0x414
        jmp     _pl_c414                | illegal instruction, lines A/F
        .org    0x41A
        jmp     _pl_c41a                | privilege, division, CHK, TRAPV
        .org    0x420
        jmp     _pl_c420                | trace
        .org    0x426
        jmp     _pl_c426                | division … reserved, autovectors 3 to 7
        .org    0x42C
        jmp     _pl_c42c                | uninitialised interrupt
        .org    0x432
        jmp     _pl_c432                | spurious interrupt

| ----------------------------------------------------------------------------------
| THE BIOS CALL TABLE — $C00438 and beyond, one entry every 6 bytes.
|
| Each entry is an `rts`, except SYSTEM_RETURN, SYSTEM_INT1, SYSTEM_IO, CREDIT_CHECK,
| READ_CALENDAR, CARD, CARD_ERROR, FIX_CLEAR, LSP_1st and MESS_OUT. The caller leaves
| with its variables unchanged, which is wrong but harmless. With no entry at all, it
| would execute the image's $FF fill, take an exception, and layer 0 would no longer
| hand control to anyone.
|
| IT RUNS UP TO $C006FC, AND NOT UP TO $C0051C. The last line of "BIOS calls" is
| "$C0059A to $C006FC", Invalid / RTS. Between $C00522 and $C00594 the page inserts
| BIOSF_* entries — UPLOAD, LOADFILE, CDPLAYER, CDDACMD, VIDEOEN, PUSHCDOP, SETCDDMODE,
| RESETGAME — which it marks "CD only", and its cartridge column gives them as Invalid.
| They are served with an `rts` anyway: "Invalid" says a cartridge game has nothing to
| call there, not that the silicon prevents it, and nothing I have read closes these
| slots. The fill therefore runs from one end of the table to the other — 114 entries
| from $C00456 to $C006FC, of which READ_CALENDAR, the 2nd, CARD and CARD_ERROR, the 4th
| and 5th, and FIX_CLEAR, LSP_1st and MESS_OUT, the 19th, 20th and 21st, exit through a
| `jmp` — and the code lives BEYOND, further down.
|
| WHAT `puzzledp` REALLY CALLS, measured over the 18.99 frames the trace covers — the
| co-simulator's trace (unpublished) caps out on accesses, not on frames, and only the
| bench counters go up to 20. We count the accesses landing on the exact address of an
| entry, and each one is indeed a distinct call: the gaps between them are worth one
| frame, ~811,000 periods.
|
|   SYSTEM_IO     $C0044A   16        CREDIT_CHECK   $C00450   12
|   FIX_CLEAR     $C004C2    2        LSP_1st        $C004C8    1
|   SYSTEM_RETURN $C00444    1        total                    32
|
| In the only judgement window (T+2.07 to T+8.63), 9 of these calls. And 18 accesses in
| program space land there in the BIOS ROM, out of 247,713: the other 9 are the prefetch
| around the `rts`. Another game does not call the same entries.
|
| Redoing this count, on a co-simulator trace (unpublished):
|   grep -oE ' C00(444|44A|450|4C2|4C8) rd ' trace.txt | sort | uniq -c
| ----------------------------------------------------------------------------------
        .org    0x438
        jmp     _systeme_int1           | SYSTEM_INT1  — vblank routine, in `int1.s`
        .org    0x43E
        rts                             | SYSTEM_INT2  — timer routine
        .org    0x444
        jmp     _retour_systeme         | SYSTEM_RETURN — reached by `jmp`, not by `jsr`
        .org    0x44A
        jmp     _systeme_io             | SYSTEM_IO    — in `io.s`; saves no register
        .org    0x450
        jmp     _credit_check           | CREDIT_CHECK — in `io.s`
        .org    0x456
        rts
        .space  4                       | an entry is 6 bytes
        .org    0x45C
        jmp     _read_calendar_jeu      | READ_CALENDAR — in `cal.s`, the frozen date if needed
        .org    0x462
        rts
        .space  4
        .org    0x468
        jmp     _card                   | CARD         — in `card.s`
        .org    0x46E
        jmp     _card_error             | CARD_ERROR   — in `card.s`
        .org    0x474
        .rept   13                      | from $C00474 to $C004BC
        rts
        .space  4
        .endr
        .org    0x4C2
        jmp     _fix_clear              | FIX_CLEAR    — in `video.s`
        .org    0x4C8
        jmp     _lsp_1st                | LSP_1st      — in `video.s`
        .org    0x4CE
        jmp     _mess_out               | MESS_OUT     — in `mess.s`
        .org    0x4D4
        .rept   93                      | from $C004D4 up to $C006FC, end of the table
        rts
        .space  4
        .endr

| ----------------------------------------------------------------------------------
| THE CODE, OUT OF REACH OF THE CALL TABLE.
|
| The last entry, $C006FC, occupies its 6 bytes up to $C00701: nothing that "BIOS calls"
| describes lives beyond. $C00800 is therefore the first round offset that puts the code
| out of reach of a `jsr $C00xxx` coming from the table — and a round offset is
| recognisable in a trace, which matters when looking for where the 68000 went.
|
| THE FIRST VERSION OF THIS LAYER PUT THE CODE AT $C00600, i.e. inside the table: 23
| slots of the range $C0059A-$C006FC fell in it, and a game that had called one would
| jump into `_demarrage` — REG_SWPROM rewritten and power-on relaunched in the middle of
| a game. `puzzledp` does not call them, so the bench showed nothing of it: it was the
| comment "up to $C0051C, its end" that was wrong, and the code with it.
|
| The gap $C00702-$C007FF stays at zero, through the `.org` fill. I have found nothing
| that points there; that is not proof that there is nothing, only the state of what I
| have read.
| ----------------------------------------------------------------------------------
        .org    0x800

_demarrage:
        | The 68000 comes out of reset in supervisor mode with IRQs masked. We write it
        | anyway: layer 0 insists that nothing runs between here and the switch.
        move.w  #0x2700, %sr
        move.l  #0x10F300, %sp

        | THE WATCHDOG FIRST. Writing $300001 kicks it; "Watchdog" says to write "any
        | value" there, so the data does not matter. Writing from a data register is the
        | idiom of the "Hello world tutorial" — `move.b d0,REG_DIPSW`, commented "Kick
        | watchdog" —, but %d0 being UNDEFINED is my choice, allowed by that "any value":
        | the example in "USER subroutine", for its part, sets d0 to zero.
        | ITS COUNTER once at zero, the board fires the reset: power-on would start over,
        | and REG_SWPROM would be written a second time.
        |
        | ITS DURATION IS DOCUMENTED, BUT NOT VERIFIED. The Timings section of "Watchdog"
        | gives 3,244,030 cycles, "corresponds to 8 frames", and marks it "This isn't
        | verified"; it also cites MAME, 0.128762 s, i.e. about 7.6 frames — the two public
        | figures therefore do not agree. The co-simulator (unpublished) keeps 8 frames,
        | which is the more demanding of the two. The decoding of any odd address in
        | $300000-$31FFFF, for its part, is specific to the co-simulator and not a wiki
        | datum.
        move.b  %d0, 0x300001

        | THE HANDSHAKE, in this order.
        move.b  %d0, 0x3A0003           | REG_SWPBIOS: BIOS vector table
        move.b  %d0, 0x3A000B           | REG_BRDFIX: the board's SFIX and SM1

        | RELEASING THE TWO COIN LOCKOUTS. Read in "Memory mapped registers":
        | REG_RESETCL1 ($380065) and REG_RESETCL2 ($380067) let lockouts 1 and 2 float, data
        | "Any", through the NEO-I0; REG_SETCL1/2 ($3800E5/E7) do the opposite.
        | Measured under MAME on `wjammers`: without these writes, the coin bit of $320001
        | never goes down and no coin is accepted; with them, the next coin goes through.
        | The reference writes $00 to $380065 then $380067, once, at frame 0.
        | Here, for the same reason: before the hand-over to $000122, hence before any
        | SYSTEM_IO and any INT1 — the IRQs stay masked until then.
        move.b  %d0, 0x380065           | REG_RESETCL1: lockout 1 released
        move.b  %d0, 0x380067           | REG_RESETCL2: lockout 2 released

        | THE BOARD'S OTHER REGISTERS, set here rather than left in their power-on state,
        | which no page read gives. Addresses and meanings read in "Memory mapped
        | registers". Values: measured under MAME on 2026-10-22 on the reference (-bios
        | euro, aof, puzzledp, mslug, fresh NVRAM, lua write tap on $380000-$3800FF,
        | $3A0000-$3A001F and $3C0006-$3C000F, 400 frames; values written only, no PC), the
        | three games equal; record not versioned, handed to the coordinating agent.
        |   - REG_LSPCMODE ($3C0006) ← $4000: measured, the reference writes it at frame 1,
        |     with the IRQ acknowledgement. Auto-animation speed in the high byte, timer IRQ
        |     disabled in the low bits (my reading of the bits, as at SYSTEM_RETURN below,
        |     which writes the same value, measured as well);
        |   - THE TIMER, REG_TIMERHIGH/LOW ($3C0008/$3C000A): measured, the reference writes
        |     nothing there in 400 frames, nor in REG_TIMERSTOP ($3C000E). We do not write
        |     there either: REG_LSPCMODE above disables its IRQ, and the game that uses it
        |     loads it itself;
        |   - REG_NOSHADOW ($3A0001), data "Any": measured, the reference writes it once at
        |     boot (frames 282 to 287 depending on the game, data $00). Here from reset:
        |     ASSUMED without consequence, this BIOS never writing REG_SHADOW ($3A0011, read
        |     in the code);
        |   - THE CARD LOCKS, REG_CRDLOCK2 ($3A0007) then REG_CRDLOCK1 ($3A0015), data
        |     "Any": measured, the reference writes them at frame 277, in this order (data
        |     $30), also the order of `card.s`. Here from reset; CARD reopens them as needed;
        |   - THE COIN COUNTERS (REG_RESETCC1/2, REG_SETCC1/2): measured, the reference does
        |     not write them at boot (400 frames); so we do not set them either.
        move.w  #0x4000, 0x3C0006       | REG_LSPCMODE
        move.b  %d0, 0x3A0001           | REG_NOSHADOW
        move.b  %d0, 0x3A0007           | REG_CRDLOCK2
        move.b  %d0, 0x3A0015           | REG_CRDLOCK1

        | THE SYSTEM AREA OF THE BACKUP RAM, FORMATTED IF ITS SIGNATURE IS MISSING. Read in
        | "Backup RAM": $D00010-$D0001F carries "BACKUP RAM OK!Ç", and the BIOS, if it does
        | not find the string, tests the RAM and reinitialises it. Measured under MAME
        | (`puzzledp`, black box): `BACKUP RAM OK !` — a space before "!", which the page
        | does not have — then $80, the page's "Ç" if read in code page 437 (my reading).
        | Measured as well: `kof98`, on an area left blank, goes down a fatal path (loop
        | without kicking the watchdog, IRQs masked, reset in a loop).
        |
        | SIGNATURE PRESENT: WE TOUCH NOTHING. An MVS's NVRAM persists from one boot to the
        | next, settings and counters included.
        |
        | NO MEMORY TEST. The reference runs patterns over the area before formatting
        | (measured, frames 38-62 of `puzzledp`: $5555, $AAAA, then a value derived from the
        | address). This boot tests no RAM; only the validation is, and the formatting.
        |
        | THE EXTENT: $D00000-$D0007F. The page does not bound a "system area"; it describes
        | cells up to the bookkeeping at $D08320. We stop at the last byte the reference's
        | dumps cover: beyond, the date ($D00104), the slot tables ($D00124, "$0000 as NGH
        | and $FFFF as game name ID" when the slot is empty) and the game blocks would
        | require values neither measured nor all written by the page — zeros there would
        | contradict the $FFFF of empty slots. ASSUMED therefore, that nothing a game reads
        | at its init falls higher. The slot table has its own check and its own
        | formatting, at the end of the boot.
        |
        | THE VALUES. Zero everywhere except what follows, measured after the reference's
        | boot (dumps spaced 160 frames apart); what the page says of them is noted beside.
        |   $D0003A-3D  01 01 01 02  "Cab settings": coins and credits of P1 then P2,
        |                            "initialized to $01", $01, $01, "$02"
        |   $D0003E-41  01 01 01 03  measured; the page covers these bytes under "Cab
        |                            settings" without detailing them
        |   $D00042-43  00 00        measured; the page: "Game select", "initialized to 0",
        |                            and "Game start compulsion", 0 = enabled, no default
        |   $D00044     30           "Game start compulsion time", BCD, "initialized to $30"
        |   $D00045     3B           measured; last byte of "Cab settings", not detailed
        |   $D00046     00           "Demo sound", "initialized to 0"; the same page also
        |                            names it SOUND_STOP
        |   $D00047     02           SLOT NUMBER, "2 for slot1"
        |   $D0004C     3B           measured; PLAY_TIME_FRAME_TIMER, which the page starts
        |                            at $3C — `io.s` reloads it at $3C, it does not rely on 3B
        |   $D00058     FF           measured; "First slot number with a boot logo flag to 0"
        |   $D0005A-5D  00 00 00 3C  the HHMMSSFF timer. ASSUMED: the page gives the ranges
        |                            (FF counts down from $3C to $00), not the formatting
        |                            value, and the dumps show it already advanced. FF at
        |                            $3C, the top of its countdown: at $00, `io.s` would
        |                            count one second more
        |   $D0005E-5F  FF FF        measured; the page leaves them in a "?"
        | The cells that `io.s` writes at run time ($D00020-22, $D00034-35, $D00038…) start
        | from zero, like the reference's dumps.
        |
        | THE SIGNATURE LAST, after an erase that first destroyed it. ASSUMED: it attests
        | only to a complete formatting, and a reset in the middle must make it start over.
        | The SRAM is opened by REG_SRAMUNLOCK ($3A001D) and closed again by REG_SRAMLOCK
        | ($3A000D), "Memory mapped registers"; the data does not matter.
        lea     0xD00010, %a0
        lea     _signature_bram, %a1
        moveq   #(16 / 4) - 1, %d1
_bram_verifier:
        cmpm.l  (%a1)+, (%a0)+
        dbne    %d1, _bram_verifier
        beq.s   _bram_valide            | Z holds the last `cmpm`: 16 equal bytes

        move.b  %d0, 0x3A001D           | REG_SRAMUNLOCK
        lea     0xD00000, %a0
        moveq   #(0x80 / 4) - 1, %d1
_bram_vider:
        clr.l   (%a0)+
        dbra    %d1, _bram_vider
        move.l  #0x01010102, 0xD0003A   | Cab settings: coins and credits P1, P2
        move.l  #0x01010103, 0xD0003E
        move.l  #0x303B0002, 0xD00044   | compulsion $30, $3B, demo sound 0, 2 slots
        move.b  #0x3B, 0xD0004C         | PLAY_TIME_FRAME_TIMER
        move.b  #0xFF, 0xD00058
        move.l  #0x0000003C, 0xD0005A   | HHMMSSFF: zero, FF at the top of the countdown
        move.w  #0xFFFF, 0xD0005E
        lea     0xD00010, %a0
        lea     _signature_bram, %a1
        move.l  (%a1)+, (%a0)+
        move.l  (%a1)+, (%a0)+
        move.l  (%a1)+, (%a0)+
        move.l  (%a1)+, (%a0)+
        move.b  %d0, 0x3A000D           | REG_SRAMLOCK
_bram_valide:

        | COINS AND CREDITS DO NOT SURVIVE POWER-ON. MEASURED under MAME on 2026-10-22
        | (`bench/multislot.lua`, `MS_SUIVRE`, -bios euro, MV-6F;
        | `measured/2026-10-22-ecarts-remise-credit.tsv`): at every boot, fresh NVRAM (frame
        | 277) as well as kept (frame 238), puzzledp alone as well as with aof, the reference
        | writes $00 to each byte of $D00020-$D00039 — coin edge, partial counters
        | $D00024/25, credits $D00034/35, pulse timer $D00038 —, whether they held 2 credits,
        | 3 P2 credits or one coin out of two. Our image kept them from one boot to the next.
        | Here, before slot detection; on a fresh NVRAM, the formatting above has already set
        | them to zero.
        move.b  %d0, 0x3A001D           | REG_SRAMUNLOCK
        lea     0xD00020, %a0
        moveq   #(0x1A / 2) - 1, %d1    | 26 bytes, $D00020-$D00039
1:      clr.w   (%a0)+
        dbra    %d1, 1b
        | PLAY TIME AND ITS NEIGHBOURS, AT EVERY BOOT. MEASURED under MAME on 2026-10-22
        | (`bench/multislot.lua`, `MS_SUIVRE` on $D00048-$D00061, -bios euro, puzzledp;
        | `measured/2026-10-22-piece-demo-end-boot.tsv`), fresh NVRAM (frame 277), kept, and
        | kept with these 26 bytes set to other values (frame 238): the reference writes
        | $D0005E-5F ← $FF, $D00060-61 ← $00, $D00048-4B ← $00, $D0004C ← $3B, in this
        | order, whatever their content; $D0004D-$D00057 are not touched.
        | READ in "Backup RAM": PLAY TIME, "Counter of second played on the game in hex",
        | "Reset to 0 by SYSTEM_RETURN" (the page does not mention the boot); $D0004C,
        | PLAY_TIME_FRAME_TIMER, "start at $3C" — the reference sets $3B, we follow it;
        | $D0005E-$D00061 marked "?". None of the 22 games of the corpus reads $D00048-$D00061
        | (`measured/2026-10-22-bram-lue-par-les-jeux.tsv`): the measurement alone decides.
        | NOT TAKEN OVER: $D0005A-5D, which the reference sets to the calendar time at every
        | boot (measured: 21:50:29 read, $54 $32 $1D $3C written — hour × 4, minute, second in
        | binary, then $3C; the host's time, which MAME gives to the µPD4990A). It would mean
        | reading the calendar at boot for a cell no game reads: we stick to the formatting
        | and to the countdown of `io.s`.
        move.w  #0xFFFF, 0xD0005E
        clr.w   0xD00060
        clr.l   0xD00048                | PLAY TIME
        move.b  #0x3B, 0xD0004C         | PLAY_TIME_FRAME_TIMER
        move.b  %d0, 0x3A000D           | REG_SRAMLOCK

        | ACKNOWLEDGING THE THREE INTERRUPTS. "68k interrupts" gives level 3 "pending after
        | reset", and the bits of REG_IRQACK: 2 for the vblank, 1 for the timer, 0 for the
        | reset — the page marks the latter with a "?". Its example `move #$0007,REG_IRQACK`
        | acknowledges all three at once, and that is what we do: the IRQ is masked here,
        | but the game unmasks, and a pending one would send it into its handler before its
        | own initialisation.
        move.w  #7, 0x3C000C

        | CLEARING $10F300 TO $10FFFF, i.e. 832 longwords. That is MORE THAN THE BIOS RAM:
        | the lowest variable that "BIOS RAM locations" describes is $10FCEE, and what
        | precedes is the area where the supervisor stack, set at $10F300, grows down. Layer
        | 0 reads none of these variables, but the game does: leaving them at their power-on
        | content would make its start depend on what happened to be there.
        lea     0x10F300, %a0
        move.w  #((0x110000 - 0x10F300) / 4) - 1, %d1
_vider:
        clr.l   (%a0)+
        dbra    %d1, _vider

        | THE STATE WE SET. The machine type and the nationality, which the zero of the
        | clearing would falsify: we take them from the descriptor. The three variables of
        | the USER protocol, for their part, are written at the hand-over, further down.
        move.b  0xC00400, 0x10FD82      | BIOS_MVS_FLAG     ← machine type
        move.b  0xC00401, 0x10FD83      | BIOS_COUNTRY_CODE ← nationality
        | THE REGION CHOSEN ON SCREEN, if the BIOS settings carry it (`reglages.s`): it
        | replaces the descriptor. Here, before everything that reads it — the boot screen,
        | the soft-DIP pointer (`_slot_inscrit`, `dip.s`) and CARD_REGION (`card.s`). The
        | backup RAM can be read without being unlocked, and the system area has just been
        | validated or formatted above; the formatting does not touch $D00210.
        jsr     _reglages_region
        tst.b   %d0
        bmi.s   1f                      | $FF: no setting, the descriptor stays
        move.b  %d0, 0x10FD83
1:
        | THE MODE CHOSEN ON SCREEN (MODE line of `dip.s`, `reglages.s`): $80 MVS or $00 AES
        | in BIOS_MVS_FLAG, in place of the descriptor. That is what games read (record
        | `measured/2026-10-23-mode-aes.tsv`); the machine, for its part, stays an MVS
        | (REG_STATUS_B bit 7). Here, before the boot screen that displays it. Deliberate
        | departure: DECISIONS §11.
        jsr     _reglages_mode
        cmpi.b  #0xFF, %d0
        beq.s   1f                      | no setting: the descriptor stays
        move.b  %d0, 0x10FD82
1:
        | THE CABINET (FREE PLAY, NO CONTINUE, DEMO SOUND) in RAM, from the settings and the
        | mode just set (`reglages.s`, `_borne_ram`): before any hand-over and any game call.
        jsr     _borne_ram
        | IN AES MODE, THE COIN MECHANISMS LOCKED: the coin is ignored (decision D2). Read in
        | "Memory mapped registers": REG_SETCL1/2 ($3800E5/E7), "coin lockout sinks
        | current", the opposite of the REG_RESETCL released above; "Coin switch": the coin
        | is detected only with the lockout unpowered. Measured under MAME on 2026-10-23
        | (walkthrough, scene aes-piece): the coin changes no frame and no key-on. The lock
        | rather than a test in SYSTEM_IO, so that MVS mode keeps its cycles (DECISIONS §11).
        tst.b   0x10FD82
        bmi.s   1f
        move.b  %d0, 0x3800E5           | REG_SETCL1
        move.b  %d0, 0x3800E7           | REG_SETCL2
1:
        | BIOS_MESS_POINT ← BIOS_MESS_BUFFER, before the first hand-over: measured
        | (`measured/2026-10-17-b2b-mess-out.tsv`, point 4, frame 279). Without it, the
        | pointer starts from zero and the game's deposits fall into the P-ROM (point 3).
        | BIOS_MESS_BUSY ($10FDC2) is measured at 00 at frame 276: the clearing above has
        | already put it there.
        move.l  #0x10FF00, 0x10FDBE

        | THE SLOTS: how many the board has, which ones are occupied, and the table $D00124
        | that follows from it. Measured on the reference (`measured/2026-10-21-multi-slot.tsv`,
        | MV-6F): $D00047 ← the number of slots of the BOARD (6, not the number of
        | cartridges), then for each slot k: $D00108 ← k, REG_SLOT ($380021) ← k, header
        | read; then the eight entries of the table, entry k being physical slot k. Here,
        | before the boot screen, so that it reads the header of the slot served.
        |
        | THE SCAN IS DONE UNDER REG_CRTFIX, AND THAT IS A CORRECTION FROM THE HARDWARE. Up to
        | image no. 8 it was done under REG_BRDFIX, the reset state: under MAME everything
        | worked, and on a real MV-2F (2026-10-24, `docs/ESSAI-MATERIEL.md`) each slot's
        | header read as floating bus — GAME NGH displayed E05C, the word following
        | `move.w 0x108,%d4` in `ecran.s`, with or without a cartridge. Read (NeoGeo
        | Development Wiki): "MVS cartridge pinout", SLOTCS "goes low when the slot is used",
        | comes from NEO-F0 SLOT0~5 on a multi-slot board, "tied to SYSTEMB" on a one-slot
        | board, and "The System ROM was written to ensure the signal is asserted when it
        | does the slot check"; "NEO-F0": "SYSTEMB is used to gate the SLOT* outputs";
        | "Signals": "SYSTEM: low when onboard ROMs selected". ASSUMED, the exact form: under
        | REG_BRDFIX no slot is selected, and nothing holds the P-ROM bus.
        | MEASURED under MAME (`bench/acces-boot.lua`, ng_mv2f and neogeo, -bios euro, 1 and
        | 2 cartridges, slot 0 empty; `measured/2026-10-24-slot-crtfix.tsv`): the reference
        | writes REG_SLOT ← 0, REG_CRTFIX, REG_SLOT ← 0, then reads each slot's header, then
        | REG_BRDFIX; before all that, $01 on REG_SOUND and its echo.
        |
        | THE Z80 IS THEREFORE PARKED FIRST. Measured (`MS_SONDE_M1`, reference, 2
        | cartridges): under REG_CRTFIX, each write to REG_SLOT immediately changes the M1 the
        | Z80 sees. Parked in RAM by $01 and its echo (`_garer_z80_vite`), it no longer reads
        | its ROM; REG_BRDFIX, after the scan, gives it back the board's SM1, and the passage
        | to the slot served, further down, sends only $03.
        | ASSUMED: that the SM1 driver answers $01 from the first frames after reset — the
        | reference sends it only at frame 276. Without an echo, `_garer_z80_vite` switches
        | anyway after 60 frames, and the scan stays correct: only the Z80 suffers from it.
        | The echo is watched for continuously there, not one frame after the send as in the
        | slot passage: under MAME it comes within the reset frame, and the boot screen then
        | starts at the same frame as before (measured, `bench/bus-flottant.lua`, BF_LIBRE).
        | A $01 left in the reply latch would pass for the echo; MAME has it at $00 on reset
        | (record of the reference, 542 reads at $00 before its echo), the page says nothing
        | about the hardware.
        move.b  %d0, 0x3A001D           | REG_SRAMUNLOCK

        | IS THE TABLE THERE? %d3: one bit per block taken, 0 to 7. ASSUMED, it is missing if
        | a taken index falls outside 0-7 or repeats: an SRAM at zero falls into this case
        | (eight index 0), a table this BIOS wrote never does. Formatted then with eight empty
        | entries, "$0000 as NGH and $FFFF as game name ID" ("Backup RAM"). This test does not
        | depend on the signature at $D00010: a signed NVRAM without a table must receive one.
        lea     0xD00124, %a0
        moveq   #0, %d3
        moveq   #8-1, %d1
_slots_valider:
        move.w  2(%a0), %d2             | block index
        cmpi.w  #0xFFFF, %d2
        beq.s   1f                      | free entry
        cmpi.w  #8, %d2
        bhs.s   _slots_formater         | index outside 0-7
        bset    %d2, %d3                | Z ← the old bit was zero
        bne.s   _slots_formater         | index already taken by another entry
1:      addq.l  #4, %a0
        dbra    %d1, _slots_valider
        bra.s   _slots_compter

_slots_formater:
        lea     0xD00124, %a0
        moveq   #8-1, %d1
1:      move.l  #0x0000FFFF, (%a0)+     | NGH $0000, block $FFFF: empty entry
        dbra    %d1, 1b

        | THE NUMBER OF SLOTS, %d6. Read in "Memory mapped registers": REG_SYSTYPE
        | ($300081) bit 6, "0: 2 slots, 1: 4 or 6 slots"; REG_STATUS_A ($320001) bit 5,
        | "0:4-SLOT, 1:6-SLOT". Measured under MAME, reference and us equal: 6 on `neogeo`
        | (MV-6F), 4 on `ng_mv4f` and `ng_mv2f`, 2 on `ng_mv1` and `ng_mv1f` — "2 for slot1",
        | says "Backup RAM" of $D00047.
_slots_compter:
        moveq   #2, %d6
        btst    #6, 0x300081            | REG_SYSTYPE
        beq.s   1f
        moveq   #4, %d6
        btst    #5, 0x320001            | REG_STATUS_A
        beq.s   1f
        moveq   #6, %d6
1:      move.b  %d6, 0xD00047           | SLOT NUMBER

        | THE SCAN. %d5: one bit per occupied slot; 16 bytes of stack: the NGH of each.
        | A SLOT IS OCCUPIED if its header carries "NEO-GEO" at $100-$106 ("68k program
        | header": "first cartridge recognition code"). Measured: the reference reads only
        | $000100 of an empty slot, and the whole header $000100-$000106 on an occupied slot;
        | that it compares these seven bytes with the string is ASSUMED, as is what the board
        | returns for an empty slot (under MAME, something other than "NEO-").
        | AND IF ITS NGH IS NOT ALREADY THAT OF AN EARLIER SLOT. Measured on the reference: on
        | `ng_mv1`, where slot 1 returns the header of slot 0 (read in full), then on the
        | MV-6F with the same game twice (slots 0 and 1, 0 and 3, 1 and 2): the second slot
        | comes out $0000 / $FFFF. "Backup RAM": "slot1 are slot2 with the second one empty".
        | ASSUMED: that it is the NGH it compares, and not the whole header.
        |
        | NO SLOT OCCUPIED: THE SCAN IS REDONE AT EVERY FRAME, up to ATTENTE_CARTE frames, for
        | a flash cart that does not yet return its header (`DECISIONS.md` §31). The reference
        | scans around frame 276 (`measured/2026-10-24-slot-crtfix.tsv`); measured under MAME,
        | `measured/2026-10-28-carte-lente.tsv`. ASSUMED, and not covered: a slow flash cart
        | next to a prompt cartridge, which the first scan finds without it.
        .equ    ATTENTE_CARTE, 270
        bsr     _garer_z80_vite         | clobbers %d0, %d4
        move.w  #ATTENTE_CARTE - 1, %d7
        lea     -16(%sp), %sp
_slots_essai:
        move.b  #0, 0x380021            | REG_SLOT ← 0 before the switch, like the reference
        move.b  %d0, 0x3A001B           | REG_CRTFIX: the slot's cartridge answers (SLOTCS)
        moveq   #0, %d5
        moveq   #0, %d1
_slots_parcourir:
        move.b  %d1, 0xD00108           | measured order: $D00108, then REG_SLOT
        move.b  %d1, 0x380021           | REG_SLOT
        cmpi.l  #0x4E454F2D, 0x100      | "NEO-"
        bne.s   2f
        cmpi.w  #0x4745, 0x104          | "GE"
        bne.s   2f
        cmpi.b  #0x4F, 0x106            | "O"
        bne.s   2f
        move.w  0x108, %d2              | NGH, "68k program header"
        moveq   #0, %d4                 | %d4: each slot j < k already occupied
8:      cmp.w   %d1, %d4
        bhs.s   9f
        btst    %d4, %d5
        beq.s   1f
        move.w  %d4, %d3
        add.w   %d3, %d3
        cmp.w   (%sp,%d3.w), %d2
        beq.s   2f                      | same NGH as an earlier slot: empty
1:      addq.w  #1, %d4
        bra.s   8b
9:      bset    %d1, %d5
        move.w  %d1, %d3
        add.w   %d3, %d3
        move.w  %d2, (%sp,%d3.w)
2:      addq.w  #1, %d1
        cmp.w   %d6, %d1
        blo.s   _slots_parcourir
        move.b  %d0, 0x3A000B           | REG_BRDFIX, measured after the scan: the board's font
        tst.b   %d5
        bne.s   1f                      | one slot occupied
        tst.w   %d7
        beq.s   1f                      | limit reached: none
        bsr     .Lsync                  | one frame, watchdog included
        subq.w  #1, %d7
        bra.s   _slots_essai
1:

        | THE TABLE, EIGHT ENTRIES, entry k for slot k (measured; "Slot-N NGH number and bram
        | game block ID", "Backup RAM"). Measured, to the byte:
        |   - empty slot, or beyond the board's slots: $0000 / $FFFF;
        |   - slot whose entry already carries this NGH and a block: rewritten identically;
        |   - new slot: NGH / $FFFF, the block coming just before its request 0, further down.
        | ASSUMED: an NGH that is no longer the entry's makes a new slot, and a removed
        | cartridge loses its block (its entry becomes empty again). Nothing measured on a
        | cartridge moved to another slot or removed.
        lea     0xD00124, %a0
        moveq   #0, %d1
_slots_ecrire:
        btst    %d1, %d5
        beq.s   3f                      | empty
        move.w  %d1, %d2
        add.w   %d2, %d2
        move.w  (%sp,%d2.w), %d2        | NGH of the slot
        cmp.w   (%a0), %d2
        bne.s   4f
        cmpi.w  #0xFFFF, 2(%a0)
        beq.s   4f
        move.w  %d2, (%a0)+             | known: NGH, then its block, identically
        move.w  (%a0), (%a0)+
        bra.s   5f
4:      move.w  %d2, (%a0)+             | new
        move.w  #0xFFFF, (%a0)+
        bra.s   5f
3:      clr.w   (%a0)+                  | empty
        move.w  #0xFFFF, (%a0)+
5:      addq.w  #1, %d1
        cmpi.w  #8, %d1
        blo.s   _slots_ecrire
        lea     16(%sp), %sp

        | THE FIRST OCCUPIED SLOT, %d1, and $D00058. Measured on the reference, at every boot
        | (fresh and kept NVRAM): $D00058 ← $FF at the start of the scan, then ← the number of
        | the first occupied slot (0 with puzzledp in slot 0; 2 with aof alone in slot 2,
        | record of 2026-10-22). "Backup RAM": "First slot number with a boot logo flag to 0".
        | None occupied: $FF stays, and no slot is served (`_sans_cartouche`, further down).
        | SYSTEM_RETURN rereads $D00058 to come back to this slot after the requests 0
        | (`_sysret_init`).
        moveq   #0, %d1
        move.b  #0xFF, 0xD00058
        tst.b   %d5
        beq.s   _slots_aucun
6:      btst    %d1, %d5
        bne.s   5f
        addq.w  #1, %d1
        bra.s   6b
5:      move.b  %d1, 0xD00058

        | THE SLOT SERVED AT BOOT: the first NEW slot (occupied, block $FFFF: it will receive
        | its block and its request 0), otherwise the first occupied one. Measured on the
        | reference, 4 cartridges all new: the requests 0 go to slots 0, 1, 2, 3 in order
        | (`measured/2026-10-21-multi-slot.tsv`, c4-neuf); all known: request 2 to the first
        | occupied one (c4-suite). ASSUMED, nothing measured: a known slot before a new slot
        | does not go first — the new ones first, then the return to the first occupied one,
        | as when all are new.
7:      bsr     _premier_nouveau
        cmpi.w  #8, %d2
        bhs.s   8f
        move.w  %d2, %d1                | a new one: served first
8:      move.b  %d1, 0xD00108           | "Selected slot number (start at 0)"
        move.b  %d1, 0x380021           | REG_SLOT
        | NO SLOT OCCUPIED: $D00108 and REG_SLOT stay at the last slot scanned, like the
        | reference (measured, ng_mv1 without a cartridge, `bench/multislot.lua`, MS_SUIVRE:
        | $D00108 = $01, last REG_SLOT $01, $D00058 = $FF, empty table).
_slots_aucun:
        move.b  %d0, 0x3A000D           | REG_SRAMLOCK

        | THE BOOT SCREEN, once per power-on (`ecran.s`): about three seconds, skippable by a
        | button. SYSTEM_RETURN and the coin start further down and do not go through it.
        jsr     _ecran_boot

        | NO CARTRIDGE ($D00058 = $FF): control is handed to no slot. Until 2026-10-24, the
        | empty slot 0 was served: registered, request 0 to $000122, the absent game executed
        | whatever the empty slot returns, and the watchdog restarted the board 8 frames
        | later — a boot loop, every 192 frames on ng_mv1 (measured, `bus-flottant.lua`,
        | BF_LIBRE, images from before and after the fix). The reference, for its part, keeps
        | control and displays its test screens without a reset (measured, ng_mv1, -bios
        | euro, `matrice.sh`, captures; `multislot.lua`: no read of $000122 over 700 frames).
        | Here, the self-tests (`tests.s`), in a loop: START or EXIT bring you back there.
        | Under REG_BRDFIX and REG_SWPBIOS, which the detection left; the Z80 stays parked;
        | the backup RAM reopened for its test, non-destructive.
        cmpi.b  #0xFF, 0xD00058
        beq     _sans_cartouche

        | THE SOUND HANDSHAKE. Up to here the Z80 executes the board's SM1, which REG_BRDFIX
        | has just chosen; without what follows, the game would send its commands to that
        | driver and not to its own, which nothing selects or starts.
        |
        | Measured (`protocole.md`, trace 2): the reference writes $01 to $320000 (234.38),
        | rereads the port (234.38 and 237.50), writes $03 (237.51), then hands over to
        | $000122 (237.89). Read ("68k/Z80 communication"): $01 is sent "just before the slot
        | is switched" — the driver cuts the sound, loops in RAM and answers $01 —, and $03
        | requests a Z80 reset, "No reply is expected". Read ("Memory mapped registers"):
        | REG_SOUND is read for the Z80's reply, and REG_CRTFIX ($3A001B) chooses "the cart's
        | S ROM and M1 ROM".
        |
        | ASSUMED: that the Z80's ROM switch is REG_CRTFIX and falls between the echo of $01
        | and $03. The record does not follow $3A001B; it is the only place the page leaves —
        | after the echo, before the reset that makes the Z80 start on the new ROM.
        |
        | THE ECHO IS READ ONE FRAME AFTER EACH SEND (`.Lsync`, further down), like `menu.s`
        | and `jukebox.s`: read in the loop itself, a previous reply of the driver already at
        | $01 would pass for it. We resend $01 at every frame, 60 times at most, i.e. ~1 s
        | (the earlier limit, measured on the bench with an echo made impossible: $03 at 60.0
        | frames, without a watchdog reset; the form changed, not the count). Then ONE FRAME
        | BETWEEN THE ECHO AND REG_CRTFIX, so that the driver has entered its RAM loop before
        | its ROM changes: measured on the reference, ~3 frames between its $01 and its $03
        | (`protocole.md`, trace 2: 234.38 then 237.51). ASSUMED, three choices:
        |   - the resend: our boot writes $01 about three seconds after reset (the screen of
        |     `ecran.s`, less if it is skipped),
        |     when the reference waits for frame 234; a driver that had not yet armed its NMI
        |     would lose a single send;
        |   - the second: no page read puts a figure on the echo delay. "68k/Z80
        |     communication" only says that the SNK BIOS displays "Z80 ERROR" and locks up
        |     without an echo "in time";
        |   - the emergency exit: past the limit, we switch and send $03 anyway. A game
        |     without sound is better than a frozen screen, and the watchdog kick in each
        |     round of `.Lsync` prevents the board reset during the wait.
        | A $01 byte already present in the reply latch at power-on would pass for the echo:
        | the page does not say what it holds on reset, and the 68000 cannot empty it.
        |
        | Nothing is awaited after $03: the page provides for no reply to it, and the
        | reference does not reread the port before its hand-over. It leaves 0.38 frame to
        | the Z80, we almost nothing — ~500 periods of 48 MHz on the bench; the reset must
        | hold under 100 ms according to the same page, and it is up to the game not to talk
        | to its driver before. `wjammers` sends its first command at frame 9, measured on
        | the bench.
        |
        | This handshake is THE SLOT PASSAGE (`_passer_au_slot`, further down), the same as
        | between two requests 0: at boot, it passes to the slot the detection has just
        | chosen. AT BOOT, WITHOUT THE $01 OR ITS ECHO: the Z80 has been parked since the
        | detection, before the screen (`_garer_z80_vite`, since the hardware feedback of
        | 2026-10-24), and REG_BRDFIX left it in its RAM loop. Measured on the reference
        | (`measured/2026-10-24-slot-crtfix.tsv`, three runs): after its scan, it writes
        | REG_SLOT, REG_CRTFIX, REG_SWPROM and $03 without resending $01.
        | ONE FRAME OF WAITING, to keep the boot timing of the earlier images, on which the
        | matrix and the walkthrough scenes rely: the handshake took two here, the boot
        | parking takes one under MAME (echo within frame 1), and the hand-over thus falls
        | back to frame 188 on aof, like the main image (measured, `bench/bus-flottant.lua`,
        | BF_LIBRE). Without waiting, it came two frames earlier and aof, kof94, garou
        | changed vifs_max; with the Z80 parked twice, two frames later, and the scenes
        | gs-fois and aes-texte failed. On the hardware, the echo delay is not measured: only
        | the moment of the hand-over depends on it, not its correctness.
        bsr     .Lsync
        moveq   #0, %d1
        move.b  0xD00108, %d1           | the slot served (the boot screen may have taken %d1)
        bsr     _passer_au_slot_gare

        | CONTROL TO THE GAME, THROUGH REQUEST 0 — INITIALISATION. $000122 carries a 6-byte
        | `jmp` to the USER routine ("68k program header": "JMP to USER subroutine (code
        | start)"), which reads its request in $10FDAE ("USER subroutine").
        |
        | WHY 0. "USER subroutine": request 0 sets the default data of the backup RAM, and on
        | MVS only runs "the first time the game starts on a system". Request 1 (boot
        | animation) is not here: the page says it is called by default on AES only; in AES
        | mode, `_logo_aes` gives it before the demo.
        |
        | "THE FIRST TIME" IS READ FROM THE SLOT TABLE, measured
        | (`measured/2026-10-16-demande-0-slots.tsv`, kof98, then
        | `measured/2026-10-21-multi-slot.tsv`): the entry of the slot served carries a block
        | at the next boot, request 2 mode 1; it carries none ($FFFF, set by the detection
        | above) at the first boot, and the reference then gives it its block just before
        | request 0 — the smallest block (0-7) that no entry carries, measured (run "trou",
        | slots 0 and 2: blocks 0 and 1). kof98 ends its request 0 with an intended reset:
        | calling it again at every boot makes it loop.
        |
        | THE OTHER NEW SLOTS follow, one by one: the game ends its request 0 with
        | SYSTEM_RETURN, whose code 0 passes to the next new slot (`_sysret_init`).
        move.b  %d0, 0x3A001D           | REG_SRAMUNLOCK
        moveq   #0, %d1
        move.b  0xD00108, %d1           | the slot served
        lsl.w   #2, %d1
        lea     0xD00124, %a0
        adda.w  %d1, %a0                | %a0: its entry
        cmpi.w  #0xFFFF, 2(%a0)
        bne.s   _slot_present
        bsr     _inscrire_slot
        | THE SOFT-DIP EDITOR (`dip.s`), if the TEST button is held: %a1 points just after the
        | block, the backup RAM is still open. Otherwise, a test and a return. %a3: the index
        | of the game's entry — a changed region frees it before restarting the machine, so
        | that the next boot does a first boot again. At boot only: the new slots that
        | SYSTEM_RETURN chains do not go through it, ASSUMED (a held TEST would reopen the
        | editor only at the slot served at boot). %d6 = 1: the slot has just been
        | registered, its request 0 has not taken place (a changed mode then frees its entry).
        moveq   #1, %d6
        jsr     _editeur_dip
        move.b  %d0, 0x3A000D           | REG_SRAMLOCK
        bra     _remettre_a_user_init   | `bra`: SYSTEM_RETURN, longer, moves it away

        | PRESENT: request 2, mode 1, measured at the reference's next boot ($10FDAF ← $01,
        | $10FDAE = $02) — the same hand-over as the end of a demo (`_sysret_demo`).
        | THE RESTORATION OF ITS SAVE, a single cartridge included. Measured
        | (`bench/multislot.lua`, `MS_PLAGES`, reference, kept NVRAM, 1, 2 and 4 cartridges,
        | on 2026-10-22; one cartridge: puzzledp, nam1975, aof, mslug): before its first
        | request 2, the reference copies the save block of the slot served into the game's
        | work RAM (`_restaurer_jeu`). This block has always been saved before: a slot has a
        | block only after its request 0, which its save follows (`_sysret_init`).
        | AFTER THE EDITOR, just before the hand-over, like the reference: WORK RAM
        | (`tests.s`) writes the work RAM, and a restoration
        | done before left the game a destroyed area, saved at the end of its demo (measured,
        | `measured/2026-10-28-work-ram-restauree.tsv`). Then the debug dips set again
        | (`_dd_poser`, `debug.s`): the restoration overwrote those the editor had just set.
_slot_present:
        bsr     _relire_dip
        moveq   #0, %d6                 | a known slot: its entry stays on a changed mode
        jsr     _editeur_dip            | as above: %a1 just after the block
        move.b  %d0, 0x3A000D           | REG_SRAMLOCK
        moveq   #0, %d1
        move.b  0xD00108, %d1
        bsr     _restaurer_jeu
        jsr     _dd_poser               | registers preserved
        move.b  #0x02, 0x10FD81         | BIOS_SYSRET_STATUS, measured: see `_sysret_demo`
        moveq   #1, %d1                 | BIOS_USER_MODE    = title / demo
        moveq   #2, %d2                 | BIOS_USER_REQUEST = demo
        moveq   #0, %d3                 | no further REG_SOUND: the passage's one, at boot
        bra     _remettre_a_user

| NO CARTRIDGE: the self-tests, endlessly (see the call, after `_ecran_boot`).
_sans_cartouche:
        move.b  %d0, 0x3A001D           | REG_SRAMUNLOCK, for the backup RAM test
        jsr     _panneau_verrou         | switch 3, at opening (`panneau.s`)
1:      jsr     _autotests              | registers preserved
        bra.s   1b

| ----------------------------------------------------------------------------------
| THE REGISTRATION OF A NEW SLOT — its block, its cells, its soft-DIPs. Called by the
| boot and by SYSTEM_RETURN (`_sysret_init`), with the slot already passed
| (`_passer_au_slot`: its P-ROM is in place) and the backup RAM unlocked.
|
| Input: %a0 = its entry in $D00124. Output: %a3 = the address of the entry's index,
| %a1 = just after the save block, for `dip.s`. Clobbers %d1-%d5, %a0, %a2.
|
| WHAT THE REFERENCE WRITES FOR A NEW SLOT, measured (`bench/multislot.lua`, -bios euro,
| fresh NVRAM, 4 cartridges then slots 0 and 2 alone, on 2026-10-22; b = the block
| index): the index in the entry, $D0011A + b ← $00, $D00200 + 4 × b ← four $00 (run
| "trou": slot 2 has block 1 and it is $D0011B that is written — the index is that of
| the block, not of the slot), then, with the cartridge in place, $D002A0 + 16 × b ←
| sixteen bytes: the game's name ("PUZZLE DE PON!  ", "ART OF FIGHTING", "NAM-1975",
| "METAL SLUG"), which "Software DIPs" puts at $00-$0F of the soft-DIP block; and on
| return from request 0, $D00220 + 16 × b ← GAME_DIP. The meaning of $D0011A + b and of
| $D00200 + 4 × b is written in no page read; none of the 22 games of the corpus reads
| $D00058, $D00104-$D00107, $D0011A-$D00121, $D00144-$D001A3 or $D00200-$D0031F
| (measured, same jig, `MS_LECT_JEU`, one game alone, 4,000 frames including a game:
| only $D00034-$D00035, $D00046-$D00047, $D00100-$D00101, $D00108 and the table
| $D00124+ are read).
| Deliberate departure: GAME_DIP goes into the block BEFORE request 0 and not on its
| return — the soft-DIP editor needs it before the hand-over, and the decoding is the one
| that was measured equal to the reference at the hand-over (22 games).
| Not written, ASSUMED without effect (no reader in the corpus): the date $D00104 (fresh
| NVRAM) and $D00144 + 4 × k (each occupied slot, at every boot), which require the
| calendar; $D00164-$D001A3. What the reference writes at $D00320 and beyond on return
| from a request 0 is not an erase: it is the game's save (`_sauver_jeu`).
| ----------------------------------------------------------------------------------
_inscrire_slot:
        | %d3, one bit per block taken; %d1, the smallest free one.
        lea     0xD00124, %a1
        moveq   #0, %d3
        moveq   #8-1, %d2
1:      move.w  2(%a1), %d4
        addq.l  #4, %a1
        cmpi.w  #0xFFFF, %d4
        beq.s   2f
        bset    %d4, %d3                | 0-7: the table has been validated
2:      dbra    %d2, 1b
        moveq   #0, %d1
3:      btst    %d1, %d3
        beq.s   4f
        addq.w  #1, %d1
        bra.s   3b
4:      lea     2(%a0), %a3             | %a3: the index of the registered entry, for `dip.s`
        move.w  %d1, (%a3)
        lea     0xD0011A, %a1
        clr.b   (%a1,%d1.w)             | $D0011A + b ← $00, measured
        move.w  %d1, %d3
        lsl.w   #2, %d3
        lea     0xD00200, %a1
        clr.l   (%a1,%d3.w)             | $D00200 + 4 × b ← $00 × 4, measured
        move.w  %d1, %d3
        lsl.w   #4, %d3                 | %d3: 16 × b, for the name
_slot_inscrit:
        | THE SOFT-DIPS AT FIRST BOOT, measured (`measured/2026-10-16-soft-dip.tsv`, four
        | games): BIOS_GAME_DIP ($10FD84-$10FD93, "BIOS RAM locations", written by the BIOS)
        | is decoded from the cartridge's soft-DIP block — bytes $10-$15 as they are, then
        | the high nibble of $16-$1F —, then the BIOS copies it into the game's save block,
        | $D00220 + 16 × index. Read in "Software DIPs": $10-$15, two times as words and two
        | counts as bytes; $16-$1F, ten settings, default choice in the high nibble, number
        | of choices in the low one. After the clearing of $10F300-$10FFFF, which would
        | otherwise erase them; backup RAM still unlocked.
        |
        | THE REGION. Read in "68k program header": long pointers Japan $116, USA $11A,
        | Europe $11E. Measured: Europe alone, the image declaring Europe. ASSUMED: the
        | pointer follows BIOS_COUNTRY_CODE (0, 1, 2 → $116 + 4 × code), a code outside 0-2
        | taking Europe. The Spanish pointer ($18E, same page) is not read.
        |
        | THE TWO AREAS OF THE P-ROM. Read in "68k memory map": $000000-$0FFFFF, the first
        | fixed bank; $200000-$2FFFFF, the second, "also used for bankswitching". A block of
        | $20 bytes is accepted if it fits entirely in one or the other. Measured (MAME, 22
        | games, on 2026-10-21): mslug alone points into the second, at $2783D0, and the
        | reference decodes it there like the others.
        |
        | THE BANK IN PLACE, the one we read: we write no bank register. Read in
        | "Bankswitching": a write into $200000-$2FFFFF changes the bank, and "When the
        | system is reset, both latches are reset to 0, to ensure that the first bank is
        | mapped on startup"; this boot writes nothing into that area before here, so it
        | reads the first bank. Measured on mslug, under the reference as under us: the 32
        | bytes read at $2783D0, at frame 1 and at the hand-over, are those of the MiB that
        | MAME serves at boot (the game's region at $100000). ASSUMED: that the page, written
        | for the PROGBK1 board, holds for the other bank boards, and for the watchdog reset;
        | and that a read in that area triggers nothing in a special chip.
        |
        | THE REFUSED POINTER. ASSUMED, no page deals with it: null, or a block that
        | overflows its area, or outside $000000-$2FFFFF. Refused, GAME_DIP stays at zero —
        | reset to zero here: at boot the clearing has already put it there, but between two
        | requests 0 it carries that of the previous slot —, and these zeros go into the
        | block anyway; the name is not written. An odd pointer is accepted: everything is
        | read by byte, with no address error possible.
        lsl.w   #4, %d1                 | 16 × index, $70 at most
        lea     0xD00220, %a1
        adda.w  %d1, %a1                | %a1: the game's save block
        lea     0x10FD84, %a0           | %a0: BIOS_GAME_DIP
        clr.l   (%a0)
        clr.l   4(%a0)
        clr.l   8(%a0)
        clr.l   12(%a0)
        moveq   #0, %d4
        move.b  0x10FD83, %d4           | BIOS_COUNTRY_CODE
        cmpi.b  #2, %d4
        bls.s   1f
        moveq   #2, %d4                 | outside 0-2: Europe
1:      lsl.w   #2, %d4
        lea     0x116, %a2
        move.l  (%a2,%d4.w), %d4        | pointer to the region's soft-DIP block
        beq.s   _dip_copier             | null: refused
        cmpi.l  #0x100000 - 0x20, %d4
        bls.s   4f                      | fits in the fixed P-ROM
        cmpi.l  #0x200000, %d4
        blo.s   _dip_copier             | overflows the fixed P-ROM, or between the areas: refused
        cmpi.l  #0x300000 - 0x20, %d4
        bhi.s   _dip_copier             | overflows the banked area, or beyond: refused
4:      movea.l %d4, %a2
        lea     0xD002A0, %a0
        adda.w  %d3, %a0                | $D002A0 + 16 × b
        moveq   #16-1, %d5
5:      move.b  (%a2)+, (%a0)+          | $00-$0F: the game's name, measured (see the header)
        dbra    %d5, 5b
        lea     0x10FD84, %a0           | %a0: BIOS_GAME_DIP; %a2: the block + $10
        moveq   #6-1, %d5
2:      move.b  (%a2)+, (%a0)+          | times and counts, as they are
        dbra    %d5, 2b
        moveq   #10-1, %d5
3:      move.b  (%a2)+, %d4
        lsr.b   #4, %d4                 | the default choice, high nibble
        move.b  %d4, (%a0)+
        dbra    %d5, 3b
_dip_copier:
        lea     0x10FD84, %a0
        move.l  (%a0)+, (%a1)+          | GAME_DIP → save block, 16 bytes
        move.l  (%a0)+, (%a1)+
        move.l  (%a0)+, (%a1)+
        move.l  (%a0)+, (%a1)+
        rts

| ----------------------------------------------------------------------------------
| THE REREAD OF A KNOWN SLOT — its save block to GAME_DIP. Called by the boot
| (`_slot_present`) and by SYSTEM_RETURN on the return to the first slot (`_sysret_init`)
| and at the demo rotation (`_sysret_rotation`).
|
| Input: %a0 = the entry in $D00124. Output: %a3 = the address of the entry's index,
| %a1 = just after the block, for `dip.s`. Clobbers %d1, %a0.
|
| BIOS_GAME_DIP reread from the save block, measured (soft-DIP record, kof98: a value
| set in the block comes out in GAME_DIP). No bound or check on the values reread:
| "Software DIPs" does not say the BIOS validates them. The index is 0-7, the table having
| been validated; a $FFFF (entry without a block) leaves GAME_DIP as is, ASSUMED with no
| path leading there. VALIDATED SINCE 2026-10-27 (DECISIONS §23 pt 5, the user's
| decision): once reread, GAME_DIP goes through `_dip_valider` (`dip.s`), which resets
| each value outside its bounds to the cartridge's default, like the editor; an
| arbitrary block used to be served to the game as is. On the return to the first slot,
| GAME_DIP carries that of the last slot registered: rereading it is ASSUMED (the
| reference has not been recorded on $10FD84 at that moment), but it is what the next
| boot does, measured.
| ----------------------------------------------------------------------------------
_relire_dip:
        lea     2(%a0), %a3             | %a3: the index of the game's entry, for `dip.s`
        move.w  2(%a0), %d1             | block index
        cmpi.w  #0xFFFF, %d1
        beq.s   9f
        lsl.w   #4, %d1
        lea     0xD00220, %a1
        adda.w  %d1, %a1
        lea     0x10FD84, %a0
        move.l  (%a1)+, (%a0)+          | save block → GAME_DIP, 16 bytes
        move.l  (%a1)+, (%a0)+
        move.l  (%a1)+, (%a0)+
        move.l  (%a1)+, (%a0)+
        jsr     _dip_valider            | registers preserved
9:      rts

| ----------------------------------------------------------------------------------
| THE FIRST NEW SLOT — the first entry of $D00124 that carries an NGH and no block
| ($FFFF), the one the detection set for a cartridge the table did not know. Output:
| %d2 = its number, 8 if there is none; %a0 = its entry. Clobbers nothing else. An NGH
| $0000 is an empty entry ("Backup RAM").
| ----------------------------------------------------------------------------------
_premier_nouveau:
        lea     0xD00124, %a0
        moveq   #0, %d2
1:      tst.w   (%a0)
        beq.s   2f                      | empty
        cmpi.w  #0xFFFF, 2(%a0)
        beq.s   9f                      | new
2:      addq.l  #4, %a0
        addq.w  #1, %d2
        cmpi.w  #8, %d2
        blo.s   1b
9:      rts

| ----------------------------------------------------------------------------------
| THE NEXT OCCUPIED SLOT — %d1 = the first slot after $D00108 whose entry carries an NGH,
| wrapping around after slot 7; the current slot itself if it is the only one. Measured
| on the reference (`measured/2026-10-21-multi-slot.tsv`, summary point 4, and the record
| of this batch): 0 → 1 → 2 → 3 → 0 with four cartridges, 0 → 2 → 0 with slot 1 empty
| (run "trou").
| THE PREVIOUS OCCUPIED SLOT (`_slot_precedent`), for SELECT P2: the same scan in
| reverse. Measured on the reference (`measured/2026-10-22-multi-slot-lot4.tsv`, slots 0,
| 2 and 3 occupied): 0 → 3 → 2 → 0, slot 1 skipped, the wrap-around going through 7 to 4
| empty.
| Clobbers %d2, %d3, %d5, %a1.
| ----------------------------------------------------------------------------------
        .global _slot_suivant
_slot_precedent:
        moveq   #-1, %d5
        bra.s   _slot_voisin
_slot_suivant:
        moveq   #1, %d5
_slot_voisin:
        moveq   #0, %d1
        move.b  0xD00108, %d1
        lea     0xD00124, %a1
        moveq   #8-1-1, %d3             | the seven other entries at most
1:      add.w   %d5, %d1
        andi.w  #7, %d1
        move.w  %d1, %d2
        lsl.w   #2, %d2
        tst.w   (%a1,%d2.w)
        dbne    %d3, 1b
        bne.s   9f
        move.b  0xD00108, %d1           | no other: the current slot
9:      rts

| ----------------------------------------------------------------------------------
| THE SAVE OF A GAME — its work RAM area copied into its backup RAM block (`_sauver_jeu`),
| or the reverse (`_restaurer_jeu`). Input: %d1 = the slot, whose P-ROM is in place (the
| header read is its own). Clobbers %d2, %d3, %a0, %a1.
|
| MEASURED on the reference (`bench/multislot.lua`, `MS_PLAGES`, -bios euro, MV-6F, 1, 2
| and 4 cartridges and slots 0 and 2, fresh then kept NVRAM, on 2026-10-22; addresses,
| sizes and sums of the bytes copied, no BIOS byte):
|   - THE GAME'S AREA: the long pointer at $00010E and the size in bytes of the word at
|     $000112, read in its cartridge's header ("68k program header" names them); copied
|     as is, pointer included: puzzledp $100000 + $100, aof $108800 + $800, nam1975
|     $100000 + $1000, mslug $100000 + $7E — 256, 2,048, 4,096 and 126 bytes;
|   - THE BLOCK: $D00320 + $1000 × b, b the block index of the entry in $D00124 and not
|     the slot number ("trou": slot 2 has block 1 and its save goes to $D01320);
|   - THE SAVE follows each SYSTEM_RETURN that leaves the game, its P-ROM still in place:
|     on return from its request 0 (code 0), at the end of its demo (code 2) and at the
|     end of a game (code 3); a single cartridge included. Never on the coin. The sum of
|     the bytes written into the block is that of the bytes read in the RAM;
|   - THE RESTORATION precedes the boot's request 2 and the one following a code 0 or 2:
|     the block reread, copied to its pointer, the P-ROM of the incoming slot in place;
|     never before a request 0, nor after the end of a game (code 3: save, then the demo
|     or the title without restoration). The sum written into the RAM is that of the last
|     save of the same block. A single cartridge (record of 2026-10-22, puzzledp,
|     nam1975, aof, mslug): code 0 and code 2, save then restoration of the same block.
| ASSUMED, no page or measurement deals with it: the area is refused — nothing is copied —
| if its size is zero or exceeds $1000 (the gap between two blocks; 114 romset headers
| read, none beyond), if it starts below $100000, or if it ends beyond $10F200: this
| BIOS's stack grows down from $10F300 during the copy, and the highest area read ends at
| $10F08E (rotd) — except an outdated raycaster ROM that points to $10F300, refused. A
| slot without a block ($FFFF) is not copied.
| ----------------------------------------------------------------------------------
_bloc_jeu:
        moveq   #0, %d2
        move.w  %d1, %d2
        lsl.w   #2, %d2
        lea     0xD00124, %a1
        move.w  2(%a1,%d2.w), %d2       | the block index
        cmpi.w  #8, %d2
        bhs.s   9f                      | $FFFF: no block
        moveq   #12, %d3
        lsl.l   %d3, %d2                | $1000 × b
        lea     0xD00320, %a1
        adda.l  %d2, %a1                | %a1: the block
        movea.l 0x10E, %a0              | %a0: the game's area
        moveq   #0, %d2
        move.w  0x112, %d2              | its size
        beq.s   9f
        cmpi.w  #0x1000, %d2
        bhi.s   9f
        cmpa.l  #0x100000, %a0
        blo.s   9f
        cmpa.l  #0x10F200, %a0
        bhs.s   9f
        move.l  %a0, %d3
        add.l   %d2, %d3
        cmpi.l  #0x10F200, %d3
        bhi.s   9f
        subq.w  #1, %d2                 | the `dbra` count
        rts
9:      moveq   #-1, %d2                | refused
        rts

| THE DEBUG DIPS (`debug.s`): a mask that is set never goes into backup RAM — removed from
| the area for the time of the copy, put back after. Without a mask, the earlier path and
| one more `tst.w`.
_sauver_jeu:
        bsr     _bloc_jeu
        tst.l   %d2
        bmi.s   9f
        tst.w   DD_MASQUE
        bne.s   .Lsauver_dd
.Lsauver_copie:
        move.b  %d0, 0x300001           | watchdog: 4,096 bytes, ~0.45 frame at most
        move.b  %d0, 0x3A001D           | REG_SRAMUNLOCK
1:      move.b  (%a0)+, (%a1)+
        dbra    %d2, 1b
        move.b  %d0, 0x3A000D           | REG_SRAMLOCK
9:      rts
.Lsauver_dd:
        jsr     _dd_retirer             | registers preserved
        movem.l %d2/%a0, -(%sp)
        bsr.s   .Lsauver_copie
        movem.l (%sp)+, %d2/%a0
        jmp     _dd_remettre            | registers preserved; its `rts` is ours

_restaurer_jeu:
        bsr     _bloc_jeu
        tst.l   %d2
        bmi.s   9f
        move.b  %d0, 0x300001           | watchdog
1:      move.b  (%a1)+, (%a0)+
        dbra    %d2, 1b
9:      rts

| ----------------------------------------------------------------------------------
| THE SLOT PASSAGE — the sound parked, then the cartridge of slot %d1 in place. At boot,
| between two requests 0 (SYSTEM_RETURN, `_sysret_init`) and at the demo rotation
| (`_sysret_rotation`).
|
| Input: %d1 = the slot (word, 0-7). Clobbers %d0, %d4; %d1 and the address registers
| preserved. Returns under REG_CRTFIX and REG_SWPROM: the Z80 restarts on the slot's M1,
| the slot's P-ROM serves the bottom of the board.
|
| THE ORDER, measured on the reference (`measured/2026-10-21-multi-slot.tsv`, c4-neuf,
| frames 280, 282, 284-285, 288: once per request 0): REG_SOUND ← $01, its echo, REG_SLOT
| ← k, REG_CRTFIX, REG_SWPROM, REG_SOUND ← $03, $D00108 ← k; the hand-over comes at the
| next frame. The handshake is commented at boot, above (the resend of $01 at every
| frame, the frame between the echo and the switch, the emergency exit). The Z80 must be
| parked before REG_SLOT: under REG_CRTFIX, a write to REG_SLOT immediately changes the
| M1 it sees (measured, `MS_SONDE_M1`, see the detection).
| ASSUMED: the echo read may be the $01 left in the latch by the previous slot's driver,
| which its $03 reset to zero; we would then switch under a driver not yet parked. The
| $03 that follows resets it to zero on the new M1 whatever it did in the meantime.
|
| THE CHEATS FORGOTTEN AT EACH PASSAGE (`_cheats_oublier`, `cheats.s`): finding of the
| audit of 2026-10-21, otherwise they survived the change of game, and a cheat of one
| game would write its values into another's RAM if the two shared an NGH and a
| fingerprint.
| ----------------------------------------------------------------------------------
_passer_au_slot:
        bsr.s   _garer_z80
_passer_au_slot_gare:                   | the Z80 already parked: the boot, after the detection
        move.b  %d1, 0x380021           | REG_SLOT: the slot's cartridge
        move.b  %d0, 0x3A001B           | REG_CRTFIX: the cartridge's S ROM and M1
        move.b  %d0, 0x3A0013           | REG_SWPROM: its P-ROM at the bottom of the board
        move.b  #0x03, 0x320000         | REG_SOUND: Z80 reset, on the cartridge's M1
        move.b  %d0, 0x3A001D           | REG_SRAMUNLOCK
        move.b  %d1, 0xD00108           | "Selected slot number (start at 0)"
        move.b  %d0, 0x3A000D           | REG_SRAMLOCK
        jmp     _cheats_oublier         | its `rts` hands control back to the caller

| THE Z80 PARKED AT BOOT, QUICKLY: $01, the echo watched for continuously
| (`.Lsync_ou_echo`), resent at every frame, 60 at most; then ~3,000 rounds (~2.5 ms) for
| the driver to enter its RAM loop — ASSUMED sufficient, no page puts a figure on this
| delay. Clobbers %d0, %d4.
_garer_z80_vite:
        moveq   #60-1, %d4
1:      move.b  #0x01, 0x320000         | REG_SOUND: prepare the switch
        bsr     .Lsync_ou_echo          | Z: the echo seen
        dbeq    %d4, 1b
        move.w  #3000-1, %d4
2:      move.b  %d0, 0x300001           | watchdog
        dbra    %d4, 2b
        rts

| THE Z80 PARKED IN RAM: $01 and its echo, then one frame. For the slot passage above and
| for the slot detection, at boot. Clobbers %d0, %d4.
_garer_z80:
        moveq   #60-1, %d4              | at most 60 sends of $01
_son_envoi:
        move.b  #0x01, 0x320000         | REG_SOUND: prepare the switch
        bsr     .Lsync                  | one frame
        cmpi.b  #0x01, 0x320000         | the echo of $01?
        dbeq    %d4, _son_envoi
        bra     .Lsync                  | one frame for the driver to enter its loop

| ----------------------------------------------------------------------------------
| SYSTEM_RETURN — the game jumps there when its USER routine has finished.
|
| "SYSTEM_RETURN" only says that the cartridge jumps there at the end of its USER routine.
| It is not a subroutine return: the stack still carries the frames the cartridge
| abandoned, so we rebuild it.
|
| IT IS A DISPATCH. "BIOS RAM locations", $10FD81 BIOS_SYSRET_STATUS: "Internal value
| which stores the function code that SYSTEM_RETURN will call", codes 0 to 6.
| In our code, who writes it (read in the code): the boot's clearing (0), the START with
| credit of `io.s` (3), the SELECT of `io.s` (4, 5), the passage to the title (2, below),
| from SYSTEM_RETURN, a coin or a selection, and each hand-over into demo (2,
| `_sysret_demo` and the boot).
| Nobody writes 6, and this batch adds no writer for it: on the coin, the reference
| writes $02 and not $06 (`appel_C00438.md`, 2/41 calls, with request 3), and no
| contract shows $06. Code 6 is therefore served for a game that would set the value
| itself, not reached by our BIOS.
|
| CODE 0 CHAINS THE REQUESTS 0 (`_sysret_init`), CODE 2 ROTATES THE DEMO
| (`_sysret_rotation`). Codes 4 and 5 and 1 (EL-LED) fall back on the current slot: the
| demo, without changing slot. The selection, which sets 4 and 5, does not come through
| here (measured: the reference does not make it enter through $C00444;
| `_retour_selection`). ASSUMED, as is the handling of a value outside 0-6: the same
| path, the one that only relaunches the demo.
|
| THE $01/$03 SOUND BURST: that of the slot passage (`_passer_au_slot`), at codes 0 and 2
| only and when the slot changes. Measured (`protocole.md`, trace 2, 239.41), the
| reference also does it after the request 0 of a single cartridge (the return to slot 0
| for its logo, `measured/2026-10-21-multi-slot.tsv`, summary point 4): not here, the
| logo not being written, and the slot not changing. The lone $03 that precedes a
| request 3 is taken over further down.
| ----------------------------------------------------------------------------------
_retour_systeme:
        move.w  #0x2700, %sr
        move.l  #0x10F300, %sp
        bsr.s   _sysret_etat            | %d4: the code; shared with `_retour_demo_end`
        cmpi.b  #3, %d4
        beq     _sysret_fin_partie
        cmpi.b  #6, %d4
        beq     _sysret_piece
        cmpi.b  #2, %d4
        beq     _sysret_rotation
        cmpi.b  #1, %d4
        beq     _sysret_logo
        tst.b   %d4
        bne     _sysret_demo
        bra     _sysret_init

| THE STATE ON ENTRY TO SYSTEM_RETURN, as a subroutine so as to serve also after DEMO_END
| (`_retour_demo_end`). Output: %d4 = BIOS_SYSRET_STATUS, %d3 = what goes into
| BIOS_SYSTEM_MODE. IRQs masked and stack set by the caller.
_sysret_etat:
        | THE CODE, READ ONCE. %d3: the value of BIOS_SYSTEM_MODE, measured per call
        | (`appel_C00444.md`) — $00 on the boot call, code 0, and $02 on the game over,
        | code 3 (the attribution of a code to each call is read, not measured). Bit 1 is
        | described nowhere; ASSUMED: $02 also for code 6, the other after-game or coin
        | code, $00 for all the others apart from code 2.
        | CODE 2 CARRIES $02 TOO. MEASURED under MAME on 2026-10-23 (-bios euro, nam1975, end
        | of demo at 8753; `measured/2026-10-23-led-et-remises.tsv`, section 3): $10FD80 ← $02
        | on entry, then $02 again before the demo's hand-over; the boot's code 0, $00.
        | Our image set $00 at code 2.
        move.b  0x10FD81, %d4           | BIOS_SYSRET_STATUS
        moveq   #0, %d3
        cmpi.b  #2, %d4
        beq.s   1f
        cmpi.b  #3, %d4
        beq.s   1f
        cmpi.b  #6, %d4
        bne.s   2f
1:      moveq   #2, %d3

        | THE CONTRACT STATE, common to the two measured calls (`appel_C00444.md`, core).
        | `_sysret_etat_mode`: the SELECT entry (`_retour_selection`), %d3 set by it.
2:
_sysret_etat_mode:
        move.b  %d3, 0x10FD80           | BIOS_SYSTEM_MODE: bit 7 at 0, the BIOS has the vblank
        | BIOS_FRAME_SKIP ← $FF, measured; it survives the hand-over of a request 0, and that
        | of a request 2 or 3 sets it to $09 (`_remettre_a_user`).
        move.b  #0xFF, 0x10FEE1
        | $10FE8C ← $01, measured, single value; no page names the address. INT1 sets it back
        | to $00 at each call (`int1.s`).
        move.b  #0x01, 0x10FE8C
        | REG_LSPCMODE ← $4000, measured, single value. "Memory mapped registers": the
        | auto-animation speed in the high byte, the timer IRQ in the low bits — $4000
        | disables it, the game possibly having armed it. The reading of the bits is mine.
        move.w  #0x4000, 0x3C0006
        move.w  #7, 0x3C000C            | REG_IRQACK, measured: the three IRQs
        move.b  %d0, 0x300001           | watchdog, measured in the core

        | THE REFERENCE'S WAIT IS NOT TAKEN OVER. Its two calls close by fallback — first
        | exit to $000200 or $000918, not to $000122 — and the hand-over comes later. The
        | pass that imitated it, IRQs unmasked in SYSTEM_RETURN, was removed for a freeze of
        | `wjammers` under MAME, cause not isolated: we hand control back right away, IRQs
        | masked, like the stub.
        rts

| CODE 0 — "Init bram/select valid game for eye-catcher" ("BIOS RAM locations").
| FIRST THE NEXT NEW SLOT. Measured on the reference (`measured/2026-10-21-multi-
| slot.tsv`, c4-neuf; trou): each game ends its request 0 with SYSTEM_RETURN, BIOS_SYSRET_
| STATUS staying at $00 since the boot (written $00 at frame 277, nothing else until the
| end of the requests 0); the BIOS takes control back (REG_SWPBIOS at the next frame),
| passes to the next new slot in slot order — an empty slot is skipped (trou: 0 then 2) —,
| registers its block and gives it its request 0 mode 0, one to three frames later
| (hand-overs at frames 281, 283, 286, 289). "New" is read in the table, an entry with an
| NGH and without a block: the earlier ones have received theirs.
| THEN THE RETURN TO THE FIRST OCCUPIED SLOT ($D00058), measured: after the last request
| 0, the passage to slot 0 (frame 295). The reference plays its logo there then the
| slot's demo; here the demo alone, request 2 mode 1, as at the next boot (the logo is not
| written). Slot already in place (a single cartridge, or the first occupied one served
| last): no passage, the demo directly, as before this batch.
| THE SAVE OF THE GAME THAT HAS JUST FINISHED ITS REQUEST 0, before each passage, and the
| restoration of the first slot on return (`_sauver_jeu`, `_restaurer_jeu`), measured: the
| reference saves each game on return from its request 0 (frames 282, 284, 287, 295 with
| four cartridges), and restores the first slot before its request 2 (frame 762, after
| its logo).
| WITHOUT PASSAGE (a single cartridge, or the first occupied one served last): the same
| save, then the restoration of the same block (`_sysret_meme_slot`), measured on a single
| cartridge (save at the frame following the return, restoration before request 2, after
| the logo; puzzledp, aof, mslug, nam1975 — the latter without a logo).
| REG_SWPBIOS: measured, the reference writes it at the frame following the return, before
| the burst; here before the passage, which undoes it through REG_SWPROM. IRQs masked
| throughout.
_sysret_init:
        bsr     _premier_nouveau        | %d2
        cmpi.w  #8, %d2
        bhs.s   1f
        move.b  %d0, 0x3A0003           | REG_SWPBIOS
        move.w  %d2, %d7                | %d7: the new slot
        moveq   #0, %d1
        move.b  0xD00108, %d1
        bsr     _sauver_jeu             | the outgoing game
        move.w  %d7, %d1
        bsr     _passer_au_slot
        move.w  %d1, %d2
        lsl.w   #2, %d2
        lea     0xD00124, %a0
        adda.w  %d2, %a0                | %a0: its entry
        move.b  %d0, 0x3A001D           | REG_SRAMUNLOCK
        bsr     _inscrire_slot
        move.b  %d0, 0x3A000D           | REG_SRAMLOCK
        bra     _remettre_a_user_init
1:      moveq   #0, %d1
        move.b  0xD00058, %d1           | the first occupied slot; $FF: none
        bmi     _sysret_demo
        cmp.b   0xD00108, %d1
        beq.s   _sysret_meme_slot       | already in place
        bra     _sysret_passer

| CODE 2 — "Switch to the next slot, relaunch eye-catcher" ("BIOS RAM locations"). The
| game sets it at the end of its demo. Measured on the reference (`measured/2026-10-21-multi-
| slot.tsv`, summary point 4, and the `MS_PLAGES` record of this batch; 2 and 4
| cartridges, "trou"): REG_SWPBIOS, the save of the outgoing game, the passage to the next
| occupied slot (empty ones skipped, wrap-around), the restoration of the incoming game,
| then its request 2 mode 1, in the same frame or the next (the hand-over at 5840 for a
| return at 5837). No logo on the return to the first slot: the reference plays one, we
| do not.
| A SINGLE CARTRIDGE: no passage, but the save then the restoration of the same block, and
| the demo of the same slot. Measured (record of 2026-10-22, aof, nam1975): the reference
| saves and restores in the frame following the return, then plays its logo and RESTORES
| A SECOND TIME before request 2 (aof), the same block, the sum equal. Without a logo,
| nothing runs between the two: a single restoration here. GAME_DIP is not reread: the
| slot does not change. With a passage, it is reread from the incoming game's block
| (`_relire_dip`), ASSUMED as on return from code 0.
_sysret_rotation:
        bsr     _slot_suivant           | %d1
        cmp.b   0xD00108, %d1
        bne.s   _sysret_passer
| THE HELD FRAMES OF CODES 0 AND 2, WITHOUT PASSAGE. MEASURED under MAME on 2026-10-23 (-bios
| euro, nam1975 alone, no logo: code 0 at boot, code 2 at end of demo; `measured/2026-10-23-
| titre-apres-game-over.tsv`, section 4), the reference, after the entry into SYSTEM_RETURN
| (frame R):
|   - R+1: SYSTEM_INT1 through the game's vector, REG_SWPBIOS, REG_POUTPUT ← $00 around
|     0.11, at 0.47 ($10FD81 ← $02 at code 2) $10FEBF ← $01 and the game's save;
|   - R+2: SYSTEM_INT1; ($10FD81 ← $02 at code 0); the sound burst and REG_SLOT on the same
|     slot, then the restoration;
|   - R+3: SYSTEM_INT1; REG_SRAMLOCK, $10FEBF ← $00, $10FD80 rewritten ($00 at code 0, $02
|     at code 2), $10FEE1 ← $0A, $10FDAF, the words $10FDB6-$10FDBD, REG_SOUND ← $03;
|   - R+4: SYSTEM_INT1, $10FDAE, $10FD80 ← $82, $10FEBF ← $00, REG_SWPROM, control.
| Our image saved, restored and handed control back at R+1, IRQs masked. Taken over here,
| like code 3 (`_sysret_fin_partie`) and on its routines, EXCEPT the sound burst and
| REG_SLOT on the same slot (not taken over: `_passer_au_slot` holds two frames with IRQs
| masked). The title if a credit (`_sysret_demo`), request 3, ASSUMED on this held path.
| With a slot passage (`_sysret_passer`) and at the next request 0 (`_sysret_init`),
| nothing changes: neither measured on a single cartridge, nor comparable (the
| reference's logo on the return to slot 0).
_sysret_meme_slot:
        move.b  0x10FD81, %d7           | the code: 0 or 2
        bsr     _int1_du_jeu            | R+1
        move.b  %d0, 0x3A0003           | REG_SWPBIOS
        bsr     _attente_tenue          | until ≈ 0.47
        tst.b   %d7
        beq.s   1f
        move.b  #0x02, 0x10FD81         | code 2, measured: at 0.47
1:      move.b  #0x01, 0x10FEBF         | BIOS_BRAM_USED, measured
        moveq   #0, %d1
        move.b  0xD00108, %d1
        bsr     _sauver_jeu             | %d1 preserved
        bsr     _int1_tenu              | R+2
        tst.b   %d7
        bne.s   1f
        move.b  #0x02, 0x10FD81         | code 0, measured: at R+2
1:      bsr     _restaurer_jeu
        bsr     _int1_tenu              | R+3
        move.b  #0x00, 0x10FEBF
        moveq   #0, %d3                 | $10FD80 rewritten: $00 at code 0…
        tst.b   %d7
        beq.s   2f
        moveq   #2, %d3                 | …$02 at code 2
2:      moveq   #2, %d2                 | BIOS_USER_REQUEST = demo
        tst.w   0xD00034                | a credit, P1 or P2 (`_sysret_demo`): the title
        beq     _remise_tenue
        moveq   #3, %d2
        bra     _remise_tenue
_sysret_passer:
        bsr.s   _changer_de_slot
        bra.s   _sysret_demo

| THE CHANGE OF GAME — shared by the demo rotation (above) and the selection
| (`_retour_selection`). Input: %d1 = the incoming slot. Clobbers %d0-%d4, %d7, %a0, %a1,
| %a3; returns with the slot's cartridge in place, its game restored, its GAME_DIP reread.
_changer_de_slot:
        move.b  %d0, 0x3A0003           | REG_SWPBIOS
        move.w  %d1, %d7                | %d7: the incoming slot
        moveq   #0, %d1
        move.b  0xD00108, %d1
        bsr     _sauver_jeu             | the outgoing game, its P-ROM in place
        move.w  %d7, %d1
        bsr     _passer_au_slot
        bsr     _restaurer_jeu          | the incoming game, its P-ROM in place
        move.w  %d1, %d2
        lsl.w   #2, %d2
        lea     0xD00124, %a0
        adda.w  %d2, %a0
        bra     _relire_dip             | its `rts` hands control back to the caller

| CODE 1, ON RETURN FROM REQUEST 1 OF THE AES MODE (`_logo_aes`): the restoration of the
| game, then its demo. Measured under MAME on 2026-10-23 (`aes -bios asia`, kof98;
| `measured/2026-10-23-mode-aes.tsv`): the reference sets $10FD81 ← $01 before request 1,
| and the demo follows its SYSTEM_RETURN. The restoration is ours: the AES has no backup
| RAM; on MVS, the reference restores the slot before its request 2, after its logo (code
| 0, above). A code 1 the game would set itself, outside this case (BIOS_LOGO other than
| 1): the demo, as before.
_sysret_logo:
        cmpi.b  #1, BIOS_LOGO
        bne.s   _sysret_demo
        move.b  #2, BIOS_LOGO           | done
        moveq   #0, %d1
        move.b  0xD00108, %d1
        bsr     _restaurer_jeu

| CODES 1, 2, 4, 5 AND DEFAULT — the demo, and the end of code 0. This BIOS does not keep
| the bookkeeping of the backup RAM and has no eye-catcher of its own — "USER
| subroutine" advises on MVS to do one's own from request 2. Hence the demo, request 2,
| mode 1 ("BIOS RAM locations": 1 = "Title/Demo"). It is the path of the end of the last
| request 0 and of each demo that ends without a game.
| BIOS_SYSRET_STATUS ← $02 BEFORE THE DEMO, measured: the reference writes it in the frame
| preceding each request 2 given after its logo (frames 708, 749, 752, 762, on 1, 2 and 4
| cartridges), and it stays there until the end of the demo: that is what makes this end
| a code 2, hence a rotation. Without it, the end of demo fell back to code 0, left by the
| boot.
| A single cartridge: code 2 brings it back here through `_sysret_rotation`, like code 0.
| WITH A CREDIT, THE TITLE. MEASURED under MAME on 2026-10-22 (-bios euro, mslug, coin
| under INT1 during request 0; `measured/2026-10-22-frame-skip-et-mode0.tsv`): the coin
| is only credited (`io.s`, end of `_io_commun`), the game finishes its request 0, and
| after its SYSTEM_RETURN the reference gives request 3, not the demo, then COIN_SOUND at
| the first zero FRAME_SKIP. It goes through its logo, which sees the credit: 5 frames
| between the return and the hand-over, against ~1 here, without a logo. MEASURED as well
| for code 2 (same record, section 5: credit forced on entry to SYSTEM_RETURN, 1 and 2
| cartridges): the rotation, save and restoration included, then request 3 on the next
| slot, without DEMO_END. ASSUMED: at the end of the chain of requests 0 of a board with
| several slots.
| P2'S CREDIT COUNTS, as at code 3: the WORD $D00034. MEASURED under MAME on 2026-10-23
| (-bios euro, nam1975, end of demo through code 2, $D00035 ← $01 set on entry to
| SYSTEM_RETURN, $D00034 at $00; `measured/2026-10-23-titre-apres-game-over.tsv`, section
| 3): the reference gives the title (request 3), not the demo; our image, which tested
| the byte $D00034, the demo. ASSUMED for code 0 and the other codes that come through
| here.
_sysret_demo:
        tst.w   0xD00034                | a credit, P1 or P2: the title
        bne     _sysret_piece
        move.b  #0x02, 0x10FD81         | BIOS_SYSRET_STATUS
        moveq   #1, %d1                 | BIOS_USER_MODE    = title / demo
        moveq   #2, %d2                 | BIOS_USER_REQUEST = demo
        moveq   #1, %d3                 | REG_SOUND ← $03, without waiting (`_remettre_a_user`)
        bra     _sysret_remise

| CODE 3 — "After a gameover, save the playtime for bookeeping, switch to DEMO mode,
| reset the workbackup ram". Neither bookkeeping nor "workbackup ram" here: no page says
| what it covers. "Switch to DEMO mode" is mode 1, title / demo.
| CREDITS REMAINING → TITLE, request 3: read in "USER subroutine", whose double-title
| quirk assumes the BIOS calls command 3 "after a game over" when credits are "already
| in the system". Otherwise, the demo.
| A SINGLE TITLE, not the quirk's double title. "USER subroutine" describes the second
| call of command 3 as a probable BIOS bug, fixed in a later revision (to be confirmed,
| says the page), and $10FEC5 (BIOS_TITLE_MODE) as the means games have to prevent it. A
| game that sets $10FEC5 to 1 therefore expects a single title; a game that leaves it at
| 0 tolerates both. A single title suits both, which is why $10FEC5 is not read (it has
| been written since 2026-10-23, the measured value, below). The passage to the title
| rearms $10FD81 to 2 (`_sysret_piece`), which also prevents a third.
| MEASURED, NOT TAKEN OVER: the reference (-bios euro) DOES the double title. Under MAME on
| 2026-10-23 (aof, two coins, START, game over with one credit; `measured/2026-10-23-titre-
| apres-game-over.tsv`, section 1): hand-over of the title at R+2, then at the first
| SYSTEM_IO with zero FRAME_SKIP (R+12), $10FDDB counted down, $10FEC5 ← $01, $10FEE0 ←
| $00, $10FD81 ← $06, DEMO_END, and a second title (request 3) at R+15 — the path of the
| coin during the demo (`_retour_demo_end`). Outside the hand-over of this batch, which
| carried only the writes of code 3. The test: P1 or P2 credit non-zero
| ($D00034/$D00035, "Backup RAM", measured below), without looking at BIOS_CREDIT_DEC
| (ASSUMED).
| THE GAME'S SAVE FIRST, without restoration. Measured (record of 2026-10-22, one
| cartridge: puzzledp, nam1975, aof; two: puzzledp and aof, game on slot 0): at the frame
| following the return, the reference saves the game's area into its block, then hands
| control back on the same slot — request 2 without credit, request 3 with (aof) —,
| without rereading the block. It is this save that keeps the game's scores.
| PLAY TIME RESET TO ZERO, BEFORE THE SAVE. Read in "Backup RAM": $D00048-$D0004B "Reset
| to 0 by SYSTEM_RETURN". MEASURED under MAME on 2026-10-23 (-bios euro, nam1975, fresh
| NVRAM; `measured/2026-10-23-comptabilite.tsv`, section 1): at code 3, at the frame
| following the return, the reference writes PLAY TIME ← 0 then $D0004C ← $3B, then saves
| the game; at codes 0 (boot), 2 (end of demo) and 6 (coin, DEMO_END), it does not write
| these cells — they are already zero there, PLAY TIME running only during a game
| (`io.s`). Nothing else is written to backup RAM apart from the game's save: the page's
| "save the playtime for bookeeping" leaves no trace here.
| THE CREDIT TEST, the word $D00034: MEASURED the same day, $D00035 ← $01 set by the
| wrapper during a game (credit $D00034 at $00), the reference gives the title after code
| 3; without it, the demo. P2's credit therefore counts.
| THE HELD FRAMES. MEASURED under MAME on 2026-10-23 (-bios euro, nam1975 and aof, fresh
| NVRAM; `measured/2026-10-23-led-et-remises.tsv`, section 4), the reference, after the
| entry into SYSTEM_RETURN (frame R):
|   - at R+1, the vblank IRQ taken through the cartridge's vector, the game in SYSTEM_INT1
|     ($C00438 read), then REG_SWPBIOS; at 0.47 PLAY TIME ← 0, $D0004C ← $3B, $10FD81 ←
|     $02 and the game's save;
|   - WITHOUT CREDIT (nam1975): at R+2, SYSTEM_INT1 through the BIOS's table, then at 0.38
|     $10FD80 ← $02, $10FEE1 ← $0A, $10FDAF ← $01, the words $10FDB8-$10FDBA, REG_SOUND ←
|     $03; at R+3, SYSTEM_INT1 ($10FEE1 → $09), $10FDAE ← $02, $10FD80 ← $82, REG_SWPROM,
|     control;
|   - WITH A CREDIT (aof): the writes of 0.38 fall at 0.92 of R+1, and control at R+2,
|     request 3, likewise.
| Our image handed control back within frame R. Written here like `_retour_demo_end`:
| IRQs open until SYSTEM_INT1 has run, then the following vblanks through a call of
| $C00438 on a fabricated frame (`_int1_tenu`). The wait until 0.47 is a count of rounds
| (`_attente_tenue`), that of 0.38 or 0.92 a scan line (`_attendre_ligne`).
| BIOS_TITLE_MODE, BIOS_BRAM_USED AND THE FORCED START. MEASURED under MAME on 2026-10-23
| (-bios euro, nam1975 without credit, aof with one credit, nam1975 with $D00035 ← $01 set
| on entry; `measured/2026-10-23-titre-apres-game-over.tsv`, section 1), the reference,
| at R+1:
|   - at 0.47, $10FEC5 ← $00, then $10FEBF ← $01, REG_SRAMUNLOCK, PLAY TIME and $D0004C,
|     $10FEBF ← $00, REG_SRAMLOCK, $10FEBF ← $01, REG_SRAMUNLOCK, $10FD81 ← $02, the save;
|     REG_SRAMLOCK and $10FEBF ← $00 only just before the writes of 0.38 (R+2) or 0.92
|     (R+1) — its save lasts until then, ours does not: the $00 is placed at the measured
|     instant;
|   - WITH A CREDIT ($D00034, or $D00035 alone), the word $10FDDA ← $303B just before
|     $10FD80 ← $02 (0.92 of R+1): the forced start rearmed, which counts down at the
|     title — PLAYER_START 1,823 frames after the return (aof). Without credit, nothing.
|     Our image left $10FDDA at zero (the game's START had disarmed it): the title after
|     game over did not count down;
|   - $10FEBF ← $00 again before REG_SWPROM, at the hand-over (`_remise_tenue`).
| "BIOS RAM locations" names $10FEC5 BIOS_TITLE_MODE and $10FEBF BIOS_BRAM_USED; the
| toggling of $10FEBF around the unlocked sections is a reading of the name, not a page.
| The $10FEC5 written here is READ nowhere in our code: see A SINGLE TITLE above.
_sysret_fin_partie:
        move.b  0x10FEE4, %d6           | the SYSTEM_INT1 counter
        move.w  #2 * SYNC_TOURS - 1, %d5
        move.w  #0x2000, %sr            | the vblank, through the game
1:      move.b  %d0, 0x300001           | watchdog
        cmp.b   0x10FEE4, %d6
        dbne    %d5, 1b
        move.w  #0x2700, %sr
        move.b  %d0, 0x3A0003           | REG_SWPBIOS
        bsr     _attente_tenue          | until ≈ 0.47
        move.b  #0x00, 0x10FEC5         | BIOS_TITLE_MODE, measured
        move.b  #0x01, 0x10FEBF         | BIOS_BRAM_USED, measured, and the following ones
        move.b  %d0, 0x3A001D           | REG_SRAMUNLOCK
        clr.l   0xD00048                | PLAY TIME
        move.b  #0x3B, 0xD0004C         | PLAY_TIME_FRAME_TIMER
        move.b  #0x00, 0x10FEBF
        move.b  %d0, 0x3A000D           | REG_SRAMLOCK
        move.b  #0x01, 0x10FEBF
        move.b  #0x02, 0x10FD81         | BIOS_SYSRET_STATUS, measured: before the save
        moveq   #0, %d1
        move.b  0xD00108, %d1
        bsr     _sauver_jeu
        | P2'S CREDIT ALONE ($D00035, set on entry): MEASURED (same record, section 1), the
        | reference gives the title and rearms the forced start, but at the pace of an end of
        | game without credit (0.38 of R+2, control at R+3). Hence two tests: the word for the
        | request and $10FDDA, P1's byte for the instant.
        moveq   #2, %d3                 | $10FD80 rewritten at the hand-over (`_remise_tenue`)
        moveq   #2, %d2                 | BIOS_USER_REQUEST = demo
        tst.w   0xD00034                | P1 and P2 credits, BCD
        beq.s   1f
        moveq   #3, %d2                 | BIOS_USER_REQUEST = title
1:      move.w  #0x1DB, %d1             | ≈ 0.92 of R+1 (see `_attendre_ligne`)
        tst.b   0xD00034                | P1's credit
        bne.s   3f
        bsr     _int1_tenu              | R+2: SYSTEM_INT1
        move.w  #0x14D, %d1             | ≈ 0.38 of R+2
3:      bsr.s   _attendre_ligne
        move.b  #0x00, 0x10FEBF         | measured: at 0.38 or 0.92, not at the end of the save
        cmpi.b  #3, %d2
        bne     _remise_tenue
        move.w  #0x303B, 0x10FDDA       | BIOS_COMPULSION_TIMER, $30 s and $3B frames: measured
        bra     _remise_tenue

| WAITING FOR SCAN LINE %d1: until the line counter (REG_LSPCMODE, bits 15-7, see
| `_remettre_a_user`) is in [%d1, $1F0[, bounded to SYNC_TOURS rounds, watchdog at each
| round. A line rather than a count of rounds: the save that precedes lasts according to
| the game (0.22 frame on aof, measured). The correspondence — 264 lines per frame, $1F0
| at vblank, $1FF followed by $F8 — is ASSUMED; it places 0.38 at $14D and 0.92 at $1DB,
| and the bench verifies it (`measured/2026-10-23-led-et-remises.tsv`, section 4).
| Clobbers %d0, %d5.
_attendre_ligne:
        move.w  #SYNC_TOURS - 1, %d5
1:      move.b  %d0, 0x300001           | watchdog
        move.w  0x3C0006, %d0
        lsr.w   #7, %d0
        cmp.w   %d1, %d0
        bcs.s   2f                      | not yet the line
        cmpi.w  #0x1F0, %d0
        bcs.s   3f                      | in the window: the line has passed
2:      dbra    %d5, 1b
3:      rts

| CODE 6 — "Called after a coin deposit, does nothing". Reading: SYSTEM_RETURN does
| nothing of its own there — no slot, no eye-catcher, no demo relaunched — and control
| goes where the coin leads, the title: "USER subroutine", request 3 "called when a coin
| is inserted on MVS". Measured in the reference: after COIN_SOUND and DEMO_END
| (`protocole.md`, trace 7, 512.92-512.93), a request 3 at 514.89 and not a demo; and
| "DEMO_END subroutine": "The System ROM then jumps to SYSTEM_RETURN".
| ASSUMED: the title with no credit condition — a coin may not yet make a credit, and the
| page ties request 3 to the coin, not to the credit.
_sysret_piece:
        | THE Z80 RESET BEFORE THE TITLE: REG_SOUND ← $03 and the wait, done by
        | `_remettre_a_user` (%d3 = 2), after the writes the reference does before it.
        | THE NEXT CODE, REARMED TO 2. Measured: the reference's two passages to the title
        | write $10FD81 ← $02 with request 3 (`appel_C00438.md`, 2/41 calls). Read:
        | 2 = "Switch to the next slot, relaunch eye-catcher", i.e. the demo in our code.
        | Without this rearming, a 3 left there would make each end of demo relaunch the
        | title as long as a credit remains.
        move.b  #0x02, 0x10FD81
        moveq   #1, %d1                 | BIOS_USER_MODE    = title / demo (measured: $01)
        moveq   #3, %d2                 | BIOS_USER_REQUEST = title (measured: $03)
        moveq   #2, %d3                 | REG_SOUND ← $03 and the wait (`_remettre_a_user`)

_sysret_remise:
        | FRAME_SKIP: `_remettre_a_user` sets it to $09, the value the reference has at its
        | hand-over (measured, see there); `io.s` counts it down.
        bra     _remettre_a_user

| ----------------------------------------------------------------------------------
| THE COIN OUTSIDE A GAME — reached by `jmp` from `_io_commun` (`io.s`), under SYSTEM_IO
| as under SYSTEM_INT1. Does not return.
|
| Measured: a coin credited outside a game makes the game restart through a hand-over at
| $000122, request 3 — coin frame 297 → hand-over 300, coin 299 → hand-over 302, 289
| without a coin; trace 9 (`protocole.md`), coin at 242.92, $03 on REG_SOUND at 244.41,
| $10FDAE ← $03 then $10FD80 ← $82 and control to $000122 at 244.89. These are the
| writes of the `_sysret_piece` path, which we therefore take as is: Z80 reset, $10FD81
| ← $02, title.
|
| THE ABANDONED FRAME. Under INT1, the stack carries the IRQ's exception frame and our
| saved registers; under SYSTEM_IO, the game's return. Like SYSTEM_RETURN, we pop
| nothing: SR masks the IRQs and the stack starts again from $10F300. A 68000 keeps no
| "interrupt in progress" state outside the SR mask — the IRQ, already acknowledged by
| INT1 ($3C000C), does not wait for an `rte`. ASSUMED: that the game, restarted by its
| USER routine, does not expect more of it; the reference makes the same hand-over from
| this context.
| ----------------------------------------------------------------------------------
        .global _retour_piece
_retour_piece:
        move.w  #0x2700, %sr
        move.l  #0x10F300, %sp
        | BIOS_SYSTEM_MODE ← $01: the $01 of trace 9 (above), which `_remettre_a_user` wrote
        | for all hand-overs until 2026-10-23 and no longer writes (see there).
        move.b  #0x01, 0x10FD80
        bra.s   _sysret_piece

| ----------------------------------------------------------------------------------
| THE COIN THAT MAKES THE CREDIT DURING THE DEMO, under SYSTEM_IO — reached by `jmp` from
| `_systeme_io` (`io.s`), at zero BIOS_FRAME_SKIP, after COIN_SOUND. Does not return.
|
| READ: "68k program header", $00012E carries "JMP to DEMO_END subroutine"; "DEMO_END
| subroutine", the routine "should just end by a RTS instruction", and "The System ROM
| then jumps to SYSTEM_RETURN" (the page only mentions SELECT, not the coin).
| MEASURED under MAME on 2026-10-22 (`bench/multislot.lua` and a wrapper that records the
| game's writes between the read of $00012E and that of $000122, -bios euro, one
| cartridge; `measured/2026-10-22-piece-demo-end.tsv`), the reference, on puzzledp, aof,
| mslug, nam1975 and garou:
|   - in the coin call: COIN_SOUND ($000134 read), then $10FD81 ← $06 and DEMO_END
|     ($00012E read). IRQs masked during DEMO_END: no IRQ vector taken while the game
|     executes it (mslug, 5 frames; aof, 1);
|   - on return, $10FD80 ← $02 and $10FEE1 ← $FF (the entry into SYSTEM_RETURN, code 6);
|   - the next frame, at 0.47: $10FD81 ← $02, $10FEE1 ← $0A, REG_SOUND ← $03;
|   - the hand-over, request 3, at the vblank after: two frames after the coin when
|     DEMO_END returns right away (puzzledp, nam1975, garou), later by as much as it lasts.
| The game, for its part, works in DEMO_END: aof writes 29,955 bytes of its RAM there,
| mslug 58,384. Our image did not call it and handed control back at the next frame.
| THE TWO VBLANKS SERVED. MEASURED under MAME on 2026-10-23 (-bios euro, puzzledp, aof,
| mslug, nam1975, garou; `measured/2026-10-23-comptabilite.tsv`, section 3): after
| DEMO_END, the reference lets the vblank IRQ of the next frame through the cartridge's
| vector — the game enters SYSTEM_INT1 there ($C00438 read), BIOS_SYSTEM_MODE having its
| bit 7 at 0 — and SYSTEM_INT1 serves the displays, the coin edge and the counter pulse;
| then REG_SWPBIOS. At 0.47: $10FD81 ← $02, $10FD80 ← $02, $10FEE1 ← $0A, $10FDAF ← $01,
| the words $10FDB8, $10FDB6, $10FDBC, $10FDBA ← 0, REG_SOUND ← $03. At the next vblank,
| that of its own table (REG_SWPBIOS set), SYSTEM_INT1 again — FRAME_SKIP goes from $0A
| to $09 there —, then $10FDAE ← $03, $10FD80 ← $82, REG_SWPROM and control to $000122,
| WITHOUT $10FD80 ← $01.
| Our image held the frame with IRQs masked: the counter pulse ended one frame later, and
| aof wrote 3 bytes fewer between DEMO_END and the hand-over (29,952).
| Here: IRQs open until SYSTEM_INT1 has run ($10FEE4, its counter, has moved), bounded to
| ≈ 2 frames; the second vblank, IRQs masked, through a call of $C00438 on a fabricated
| exception frame — our vector table does not lead IRQ 1 to SYSTEM_INT1 (`plantage.s`).
| ASSUMED: that a game that does not go through $C00438 under BIOS_SYSTEM_MODE at $02
| exits through the bound anyway.
| The wait until 0.47: 3,560 rounds of ~26 cycles (see `_sysret_piece`).
| ----------------------------------------------------------------------------------
        .global _retour_demo_end
_retour_demo_end:
        move.w  #0x2700, %sr
        | $10FEE0 ← $00 BEFORE DEMO_END. No page names the address. MEASURED under MAME on
        | 2026-10-23 (-bios euro; `measured/2026-10-23-led-et-remises.tsv`, section 5): the
        | reference writes it just before $10FD81 and DEMO_END, on each of the 13 calls
        | recorded in the wrapper's window (11 after a coin, $10FD81 ← $06; 2 on SELECT,
        | ← $04). Written in the most restricted form: the value, in its place, with no role
        | attributed.
        move.b  #0x00, 0x10FEE0
        move.b  #0x06, 0x10FD81         | BIOS_SYSRET_STATUS, measured, before DEMO_END
        jsr     0x12E                   | DEMO_END
        move.w  #0x2700, %sr
        move.l  #0x10F300, %sp          | the SYSTEM_IO frame is abandoned, as on the coin
        bsr     _sysret_etat            | the entry into SYSTEM_RETURN: $10FD80, $10FEE1 ← $FF…
        move.b  0x10FEE4, %d6           | the SYSTEM_INT1 counter
        move.w  #2 * SYNC_TOURS - 1, %d5
        move.w  #0x2000, %sr            | the vblank, through the game
1:      move.b  %d0, 0x300001           | watchdog
        cmp.b   0x10FEE4, %d6
        dbne    %d5, 1b
        move.w  #0x2700, %sr
        move.b  %d0, 0x3A0003           | REG_SWPBIOS
        bsr     _attente_tenue          | until ≈ 0.47
        move.b  #0x02, 0x10FD81         | measured, at 0.47, and what follows
        moveq   #3, %d2                 | BIOS_USER_REQUEST = title
        moveq   #2, %d3                 | $10FD80 rewritten

| THE END OF THE HELD FRAMES, shared with code 3 (`_sysret_fin_partie`), codes 0 and 2
| (`_sysret_meme_slot`). Input: %d2 = the request, %d3 = what $10FD80 receives again (the
| value on entry to SYSTEM_RETURN, see `_remettre_a_user`), IRQs masked, REG_SWPBIOS set.
| Does not return. The writes measured before the hand-over (see above), REG_SOUND ← $03
| included, then the next vblank through SYSTEM_INT1, and control.
| $10FEBF ← $00 JUST BEFORE REG_SWPROM. MEASURED under MAME on 2026-10-23 (-bios euro;
| `measured/2026-10-23-titre-apres-game-over.tsv`, section 1): at each of the held
| hand-overs recorded — after DEMO_END (puzzledp, aof, mslug, nam1975, garou, b2b), codes
| 0, 2 and 3, SELECT —, after $10FD80 ← $82.
_remise_tenue:
        moveq   #1, %d1                 | BIOS_USER_MODE    = title / demo
        bsr     _logo_aes               | AES mode: perhaps request 1 (%d1, %d2)
        | BIOS_SYSTEM_MODE of the hand-over, $82, or $81 at request 1 (`_logo_aes`, measured):
        | chosen here, before the vblank, so that the hand-over takes no extra cycle (below).
        moveq   #-0x7E, %d4
        cmpi.b  #1, %d2
        bne.s   1f
        moveq   #-0x7F, %d4
1:      move.b  %d3, 0x10FD80
        move.b  #0x0A, 0x10FEE1
        move.b  %d1, 0x10FDAF
        clr.w   0x10FDB8                | see `_remettre_a_user`
        clr.w   0x10FDB6
        clr.w   0x10FDBC
        clr.w   0x10FDBA
        bsr     _commutateurs           | BIOS_P1STATUS and $10FEF8, like `_remettre_a_user`
        jsr     _af_charger             | the served game's autofire (`autofire.s`), registers preserved
        move.b  #0x03, 0x320000         | REG_SOUND: the Z80 reset (see `_sysret_piece`)
        bsr     _int1_tenu              | the next vblank
        move.w  #0x4000, 0x3C0006       | REG_LSPCMODE, as at every hand-over
        move.b  %d2, 0x10FDAE           | BIOS_USER_REQUEST
        move.b  %d4, 0x10FD80           | BIOS_SYSTEM_MODE: the game has the vblank (%d4, above)
        nop                             | 16 + 4: the 20 cycles of the earlier `move.b #0x82`
        move.b  #0x00, 0x10FEBF         | BIOS_BRAM_USED, measured
        move.b  %d0, 0x3A0013           | REG_SWPROM
        move.b  %d0, 0x300001
        bra     _remettre_partir

| ----------------------------------------------------------------------------------
| BOARD SWITCHES 3 AND 2, AT THE HAND-OVER. Clobbers %d0.
_commutateurs:
        | BOARD SWITCHES 3 AND 2, reread at each hand-over: `_remettre_a_user`, including
        | the boot's request 0, and `_remise_tenue`, including the title after a coin.
        | REG_DIPSW, active low (neogeo.cpp: SW:3 "Controller", Joystick / "Mahjong Panel";
        | SW:2 "Cabinet", Normal / "VS Mode"). MEASURED under MAME on 2026-10-27
        | (`measured/2026-10-27-dip-2-8.tsv`, sections 4 and 6), the switch flipped during
        | the demo: the SNK BIOS sets BIOS_P1STATUS ($10FD94) to 3, "Mahjong controller", 3
        | frames after the coin, not before; UniBIOS 4.0 and the Japanese SNK BIOS copy the
        | 2 into $10FEF8, "BIOS_4P_REQUESTED", "$2: dip 2 was on" ("BIOS RAM locations"), at
        | the same instant; both from boot.
        | ASSUMED: at the other hand-overs (end of demo, game over, SELECT), which nothing
        | has measured. No 4-player board is looked for: BIOS_4P_MODE and BIOS_4P_PLUGGED
        | stay at 0.
        moveq   #0, %d0
        btst    #2, 0x300001
        bne.s   5f
        moveq   #3, %d0
5:      move.b  %d0, 0x10FD94           | BIOS_P1STATUS
        moveq   #0, %d0
        btst    #1, 0x300001
        bne.s   5f
        moveq   #2, %d0
5:      move.b  %d0, 0x10FEF8           | BIOS_4P_REQUESTED
        rts

| THE WAIT FROM ≈ 0.02 TO ≈ 0.47 OF THE FRAME, after REG_SWPBIOS: 3,560 rounds of ~26
| cycles in all (see `_sysret_piece`), and REG_POUTPUT ← $00 around 0.11. MEASURED under
| MAME on 2026-10-23 (-bios euro, puzzledp and nam1975;
| `measured/2026-10-23-led-et-remises.tsv`, section 1): the reference writes $00 into
| REG_POUTPUT ($380001, "Joypad ports outputs", "Memory mapped registers") at 0.113 of
| this frame, in the held frame after DEMO_END as in that of code 3 — the value the
| previous call left there. Clobbers %d5.
_attente_tenue:
        move.w  #700-1, %d5
1:      move.b  %d0, 0x300001           | watchdog
        dbra    %d5, 1b
        move.b  #0x00, 0x380001         | REG_POUTPUT, measured
        move.w  #2860-1, %d5
2:      move.b  %d0, 0x300001
        dbra    %d5, 2b
        rts

| THE NEXT VBLANK THROUGH THE GAME: IRQs open until SYSTEM_INT1 has run ($10FEE4, its
| counter, has moved), bounded to 2 × SYNC_TOURS rounds (≈ 2 frames), watchdog at each
| round; then masked. The loop of `_sysret_fin_partie` and of `_retour_demo_end`, as a
| subroutine for codes 0 and 2 (`_sysret_meme_slot`). Clobbers %d5, %d6.
_int1_du_jeu:
        move.b  0x10FEE4, %d6           | the SYSTEM_INT1 counter
        move.w  #2 * SYNC_TOURS - 1, %d5
        move.w  #0x2000, %sr            | the vblank, through the game
1:      move.b  %d0, 0x300001           | watchdog
        cmp.b   0x10FEE4, %d6
        dbne    %d5, 1b
        move.w  #0x2700, %sr
        rts

| THE NEXT VBLANK, IRQs masked: line $1F0 (`.Lsync`), then SYSTEM_INT1 through its public
| entry on a fabricated exception frame, like the IRQ — its `rte` returns here. Our vector
| table does not lead IRQ 1 to SYSTEM_INT1 (`plantage.s`). Clobbers %d0; SYSTEM_INT1
| preserves the other registers.
_int1_tenu:
        bsr     .Lsync
        pea     3f
        move.w  #0x2700, -(%sp)
        jmp     0xC00438                | SYSTEM_INT1
3:      rts

| ----------------------------------------------------------------------------------
| THE GAME SELECTION — reached by `jmp` from `_io_select` (`io.s`), under SYSTEM_IO,
| %d6 = $04 (SELECT P1) or $05 (SELECT P2), the code BIOS_SYSRET_STATUS receives here.
| Does not return; the abandoned frame is handled as for the coin (above).
|
| MEASURED on the reference (`bench/multislot.lua`, `MS_PLAGES`, -bios euro, MV-6F, 1, 2
| and 3 cartridges, fresh and kept NVRAM, on 2026-10-22; `measured/2026-10-22-multi-slot-
| lot4.tsv`):
|   - at the SELECT frame, BIOS_SYSRET_STATUS ← $04/$05 and BIOS_SYSTEM_MODE ← $02,
|     control taken back WITHOUT the game entering through SYSTEM_RETURN ($C00444 never
|     read);
|   - at the next frame, BIOS_SYSRET_STATUS ← $02, then the rotation's passage: the save
|     of the outgoing game (S), REG_SOUND $01, the echo, REG_SLOT, REG_CRTFIX, REG_SWPROM,
|     REG_SOUND $03, $D00108, the restoration of the incoming game (R);
|   - then the hand-over on the new slot, request 3, mode 1 — the title, not the demo; the
|     credit kept. One to three frames between the SELECT and the hand-over.
| Here within the same frame as SELECT, like the coin (`_retour_piece`): the reference
| still gives the end of that frame back to the game, we do not. GAME_DIP reread from the
| incoming game's block, as at the rotation (ASSUMED there too). The second REG_SOUND $03
| that the reference writes half a frame after the passage has been taken over since
| 2026-10-23 (`_remettre_a_user`).
| DEMO_END FIRST. MEASURED under MAME on 2026-10-23 (-bios euro, puzzledp + aof, SELECT at
| 1200 and at 1213, fresh NVRAM; `measured/2026-10-23-titre-apres-game-over.tsv`, section
| 2), the reference, in the SYSTEM_IO call of the SELECT: $10FEE0 ← $00, $10FD81 ← $04 (or
| $05), DEMO_END ($00012E read); on its return $10FEE1 ← $FF, $10FD80 ← $02, $10FE8C ← $01
| (the entry into SYSTEM_RETURN, `_sysret_etat`); then $10FEBF ← $01 before the save of
| the outgoing game, ← $00 after the restoration of the incoming game, and ← $00 just
| before REG_SWPROM at the hand-over. "DEMO_END subroutine" only mentions SELECT (read, see
| `_retour_demo_end`). Our image did not call DEMO_END.
| THE HELD FRAMES ARE NOT TAKEN OVER: the reference serves SYSTEM_INT1 at the three
| vblanks between the SELECT and the hand-over (S+1 through the game's vector, S+2 and S+3
| through its table), we serve none — IRQs masked during the sound handshake
| (`_passer_au_slot`, two `.Lsync`). The hand-over falls at S+3 for both (same record);
| serving the vblanks on top would push it back.
| ----------------------------------------------------------------------------------
        .global _retour_selection
_retour_selection:
        move.w  #0x2700, %sr
        move.b  #0x00, 0x10FEE0         | measured, with no role attributed (`_retour_demo_end`)
        move.b  %d6, 0x10FD81           | BIOS_SYSRET_STATUS: 4, the next; 5, the previous
        jsr     0x12E                   | DEMO_END
        move.w  #0x2700, %sr
        move.l  #0x10F300, %sp          | the SYSTEM_IO frame is abandoned, as on the coin
        move.b  0x10FD81, %d4           | the code
        moveq   #2, %d3                 | BIOS_SYSTEM_MODE ← $02, measured
        bsr     _sysret_etat_mode       | $10FD80, $10FEE1 ← $FF, $10FE8C…
        bsr     _slot_suivant           | %d1
        cmpi.b  #4, %d4
        beq.s   1f
        bsr     _slot_precedent
1:      move.b  #0x01, 0x10FEBF         | BIOS_BRAM_USED, measured
        bsr     _changer_de_slot
        move.b  #0x00, 0x10FEBF
        move.b  #0x02, 0x10FD81         | BIOS_SYSRET_STATUS, measured: the demo afterwards
        moveq   #1, %d1                 | BIOS_USER_MODE    = title / demo (measured: $01)
        moveq   #3, %d2                 | BIOS_USER_REQUEST = title (measured: $03)
        | IN AES MODE, THE NEXT GAME'S DEMO: no BIOS title in AES (`_io_select_aes`, `io.s`;
        | "USER subroutine": on AES, the BIOS goes no further than request 2).
        | Deliberate departure, DECISIONS §11.
        tst.b   0x10FD82
        bne.s   1f
        moveq   #2, %d2                 | AES mode: BIOS_USER_REQUEST = demo
1:
        | REG_SOUND ← $03 before the hand-over, on top of the passage's one: MEASURED under
        | MAME on 2026-10-23 (-bios euro, puzzledp + aof, SELECT;
        | `measured/2026-10-23-led-et-remises.tsv`, section 3), the reference writes it at the
        | frame preceding the hand-over, after the passage.
        moveq   #1, %d3
        bra     _remettre_a_user

| ----------------------------------------------------------------------------------
| THE HAND-OVER TO USER — the only one, shared by the boot, SYSTEM_RETURN and the coin
| outside a game (`_retour_piece`).
|
| Input: %d1 = USER mode ($10FDAF), %d2 = USER request ($10FDAE). Does not return.
|
| THE ORDER AND THE VALUES ARE MEASURED (`protocole.md`, trace 2, request 3): $10FD80 ←
| $01, then $10FDAF ← mode, then $10FDAE ← request, then $10FD80 ← $82, then control to
| $000122. The values of $10FD80 were revised on 2026-10-23 over 18 hand-overs (below).
|
| The record writes $01 twice into $10FD80 over two frames, while the reference BIOS
| works; we have nothing to do between the two, hence a single write. It is the address
| and the order that are reproduced, not the count.
|
| "BIOS RAM locations" documents for $10FD80 "0:BIOS wants vblank (system mode),
| $80:Ok to use vblank (game mode)": bit 7. The measured values, $01 and $82, have this
| bit 7 as the page provides — system, then game —, and carry in addition a low bit, 0
| then 1, that no page read describes. We reproduce them as they are; their meaning is
| unknown.
|
| ASSUMED: that the same sequence holds for requests 0 and 2, which the record does not
| cover. It is the only hand-over to $000122 measured, and nothing I have read says that
| another request calls for another one.
| ----------------------------------------------------------------------------------
_remettre_a_user_init:
        | Mode 0: "BIOS RAM locations" gives 0 = "Init/Boot animation" for $10FDAF, and
        | "USER subroutine" asks to be in it during request 0. Request 0: "0:Init" in the
        | same page.
        moveq   #0, %d1                 | BIOS_USER_MODE    = initialisation
        moveq   #0, %d2                 | BIOS_USER_REQUEST = initialisation

_remettre_a_user:
        bsr     _logo_aes               | AES mode: perhaps request 1 (%d1, %d2)
        | THE LSPC TIMER DISABLED AT EACH HAND-OVER. Measured under MAME (diagnosis of
        | 2026-10-22, record `aodk-ref-lspc-ecritures`): the reference writes REG_LSPCMODE ←
        | $4000 and REG_IRQACK ← 7 before each of the three hand-overs recorded — boot (frame
        | 280), end of demo (748-751), coin during the demo (949-951) —, at the very frame of
        | the coin. `_retour_systeme` already did it; the hand-over on coin (`_retour_piece`)
        | did not: aodk, which arms the timer IRQ during its demo, received it while its USER
        | routine was reinitialising, and crashed. Here, the same write covers all hand-overs;
        | it duplicates that of `_retour_systeme` and of the boot, with no further effect.
        move.w  #0x4000, 0x3C0006       | REG_LSPCMODE: timer IRQ disabled
        move.w  #7, 0x3C000C            | REG_IRQACK: the three IRQs
        | BIOS_FRAME_SKIP AT THE HAND-OVER: $09 for a request 2 or 3, left as is for a
        | request 0. MEASURED under MAME on 2026-10-22 (`bench/multislot.lua`, `MS_SUIVRE`,
        | -bios euro, puzzledp alone and puzzledp + aof;
        | `measured/2026-10-22-ecarts-remise-credit.tsv`): the reference sets $FF at the
        | request (coin, SELECT, SYSTEM_RETURN), reloads it at $0A the next frame and counts
        | it down to $09 just before handing control back — 28 hand-overs of request 2 or 3
        | out of 28 (15 runs) enter at $09, and $00 falls 9 frames later. We hand control back
        | without a held frame between the two: setting $FF here made it reload at $0A
        | through the game's first SYSTEM_IO, and $00 fell 11 frames later — START, the coin
        | sound and SELECT taken two frames too late. Request 0: the first one of the boot
        | enters at $00 (the clearing of the BIOS RAM, above), the one after a SYSTEM_RETURN
        | at $FF (`_retour_systeme`), as with the reference.
        | BIOS_SYSTEM_MODE BEFORE THE HAND-OVER: NO MORE $01. MEASURED under MAME on 2026-10-23
        | (-bios euro; `measured/2026-10-23-led-et-remises.tsv`, section 3), the reference, over
        | 18 hand-overs (boot, demo, title after coin, game over, end of demo, SELECT):
        | $10FD80 receives before the hand-over only the value on entry to SYSTEM_RETURN,
        | rewritten — $00 (code 0, and the boot's request 0), $02 (codes 2, 3, 6, SELECT) —,
        | then $80 at a request 0 and $82 otherwise. $01 is seen there only on the path of its
        | logo (b2b, coin during the logo: $01 then $82), which we do not have; traces 2 and 9
        | show it too, on paths this record does not redo — hence the $01 kept on the coin in
        | mode 0 (`_retour_piece`). Our image set $01 then $82 at all of them.
        tst.b   %d2
        bne.s   3f
        move.b  #0x00, 0x10FD80         | request 0: $00, the BIOS has the vblank
        bra.s   4f
3:      move.b  #0x09, 0x10FEE1         | request 2 or 3; request 0 leaves FRAME_SKIP
4:      move.b  %d1, 0x10FDAF           | BIOS_USER_MODE
        | BIOS_PLAYER_MOD1-4 ($10FDB6-$10FDB9) AND THEIR COPIES ($10FDBA-$10FDBD) RESET TO ZERO.
        | MEASURED under MAME on 2026-10-23 (-bios euro, nam1975, aof, puzzledp + aof;
        | `measured/2026-10-23-comptabilite.tsv`, section 2): the reference writes $0000 into
        | the words $10FDB8, $10FDB6, $10FDBC then $10FDBA, just after BIOS_USER_MODE, before
        | EACH of the hand-overs recorded — the boot's requests 0, demo after the boot, title
        | after a coin, title or demo after a game over, demo after an end of demo, title after
        | SELECT. Our image left the player "playing" ($01) from a finished game in the
        | following demo.
        clr.w   0x10FDB8
        clr.w   0x10FDB6
        clr.w   0x10FDBC
        clr.w   0x10FDBA
        bsr     _commutateurs           | BIOS_P1STATUS and $10FEF8 (below)
        jsr     _af_charger             | the served game's autofire (`autofire.s`), registers preserved
        | REG_SOUND ← $03 BEFORE THE HAND-OVERS OF SYSTEM_RETURN AND OF SELECT (%d3 non-zero,
        | request 2 or 3), after the words above. MEASURED under MAME on 2026-10-23 (same
        | record, section 3): the reference writes it in the frame preceding each hand-over of
        | demo or title, after $10FDAF and these words — demo after the boot, after a game
        | over, after an end of demo; title after coin, game over or SELECT. Our image wrote it
        | only before a title. "68k/Z80 communication": $03 requests a reset, "No reply is
        | expected". Not at boot (`_slot_present`, %d3 zero): the slot passage has just done
        | its own.
        | THE WAIT (%d3 = 2, the title of `_sysret_piece`, the only path that had it before this
        | batch): ~26 cycles per round (`move.b` Dn to abs.l 16, `dbra` taken 10), 3,200 rounds
        | ≈ 0.41 frame at 12 MHz, watchdog at each round, IRQs masked — measured, the reference
        | hands control back ~0.48 frame after its $03 (`protocole.md`, traces 4 and 7).
        | Elsewhere (%d3 = 1), the $03 without a wait, apart from that of line $1F0 that
        | follows: with the wait before the demo, the hand-over slipped by one frame, and kof94
        | left the tolerance of the non-regression matrix (vifs 67,737 → 66,230, −2.22%;
        | measured on 2026-10-23, the wait alone without the $03 does the same, the $03 alone
        | does not).
        tst.b   %d2
        beq.s   2f
        tst.b   %d3
        beq.s   2f
        move.b  #0x03, 0x320000         | REG_SOUND
        cmpi.b  #2, %d3
        bne.s   2f
        move.w  #3200-1, %d5
1:      move.b  %d0, 0x300001
        dbra    %d5, 1b
2:      move.b  %d2, 0x10FDAE           | BIOS_USER_REQUEST
        | BIOS_SYSTEM_MODE ← $80 AT A REQUEST 0, $82 OTHERWISE (measured, see above).
        moveq   #-0x7E, %d3             | $82
        tst.b   %d2
        bne.s   1f
        moveq   #-0x80, %d3             | $80
1:      cmpi.b  #1, %d2
        bne.s   1f
        moveq   #-0x7F, %d3             | $81 at request 1 (`_logo_aes`, measured)
1:      move.b  %d3, 0x10FD80           | the game has the vblank
        | BIOS_BRAM_USED ← $00 AFTER $10FD80, measured (`_remise_tenue`): at all the hand-overs
        | recorded, the boot's request 0 included (2026-10-23, `measured/2026-10-23-titre-apres-
        | game-over.tsv`, section 1).
        move.b  #0x00, 0x10FEBF
        move.b  %d0, 0x300001           | one last kick before leaving

        | THE HAND-OVER ALIGNED ON THE VBLANK. Measured on `b2b`
        | (`measured/2026-10-17-diagnostic-b2b-minasan.tsv`, part B2B): the reference hands
        | control back at phase 0.022 of the frame, we at 0.898; the game opens its IRQs before
        | initialising its palette queue, and in our case the vblank fell between the two —
        | address error, exception loop. Causal test, same record: waiting for line $1F0 then
        | acknowledging the three IRQs ($3C000C ← 7) before the `jmp`, and the hand-over falls
        | at 0.003, no more errors over 2000 frames; the acknowledgement alone changes
        | nothing. REG_LSPCMODE ($3C0006) reads back as a line counter in its bits 15-7 (same
        | record). The wait lasts at most one frame, under the watchdog — and it is BOUNDED
        | like `.Lsync` (below, same count): SYNC_TOURS rounds of 70 cycles, ≈ 2 frames, then
        | control goes anyway if the line has not been seen. A kick at each round. Under MAME
        | the line is seen: the bound is not used.
        move.w  #SYNC_TOURS - 1, %d5
1:      move.b  %d0, 0x300001           | watchdog
        move.w  0x3C0006, %d0
        lsr.w   #7, %d0
        cmpi.w  #0x1F0, %d0
        dbeq    %d5, 1b
        | The entry of `_retour_demo_end`, which has served its vblank and set what precedes.
_remettre_partir:
        move.w  #7, 0x3C000C            | REG_IRQACK: vblank, timer, reset
        | THE DATA REGISTERS ON ENTRY TO USER. Measured under MAME (diagnosis of 2026-10-22,
        | record `garou-registres-a-122-ref`, two hand-overs): the reference enters $000122
        | with %d2, %d3, %d6 at 0 and %d7 at $0000FFFF at both; %d0 = 0, %d1 = $80, %d4 = %d5
        | = 0 at the boot's hand-over (frame 280), other values at that of the demo (frame
        | 501: %d0 = 2, %d1 = $FF82, %d4 = 8, %d5 = $FF). We left leftovers, including %d6 =
        | $FFFF, a value garou depends on at entry (record `garou-registres-a-122-notre`), and
        | it is the only register whose necessity has been established (diagnosis, on the
        | image from before this batch). The rest depends on the path: under this batch's
        | image deprived of this single write, %d6 arrives at 2 then 1 and garou passes too
        | (measured on 2026-10-22). The other values are those of the boot's hand-over,
        | copied for fidelity, without proof that a game depends on them; %d6 alone (without
        | the others) suffices for garou, measured the same day.
        | %d0 and %d5 are set here because the wait above uses them.
        moveq   #0, %d0
        move.l  #0x80, %d1              | not `moveq`: it would sign-extend to $FFFFFF80
        moveq   #0, %d2
        moveq   #0, %d3
        moveq   #0, %d4
        moveq   #0, %d5
        moveq   #0, %d6
        move.l  #0xFFFF, %d7
        jmp     0x122

| ----------------------------------------------------------------------------------
| REQUEST 1 OF THE AES MODE — the game's boot animation, in place of the first demo after
| power-on. Called by the two hand-overs (`_remettre_a_user`, `_remise_tenue`). Input and
| output: %d1 the USER mode, %d2 the request. Nothing else is touched.
|
| Read in "USER subroutine": request 1 shows the game's animation "when $114 = 1", it "is
| only called on AES", "once only at system start (before attract mode) and not again".
| MEASURED under MAME on 2026-10-23 (`aes -bios asia`, six games;
| `measured/2026-10-23-mode-aes.tsv`): kof98 alone ($114 = 1) receives it, mode 0, just
| after its request 0, $10FD81 ← $01 and BIOS_SYSTEM_MODE ← $81 before it; then the demo.
| Here at every power-on, since request 0 does not come back there (decision D5): at the
| first hand-over of a demo, once only — BIOS_LOGO goes to 2 even without an animation, so
| that another slot does not receive it in the middle of the rotation. Without AES mode,
| nothing. $114 = 0 (the BIOS's eyecatcher): nothing either, decision D6.
| BIOS_LOGO ($10FB08): ours, in the area no game writes (measured, `menu.s`), reset to
| zero by the boot's clearing; 1 = request 1 given, 2 = done (`.equ` at the top of the
| file).
_logo_aes:
        jsr     _borne_remise           | DEMO SOUND: $D00046 according to the request (`reglages.s`)
        cmpi.b  #2, %d2
        bne.s   9f                      | not a demo
        tst.b   0x10FD82
        bne.s   9f                      | MVS mode
        tst.b   BIOS_LOGO
        bne.s   9f                      | already done at this boot
        move.b  #2, BIOS_LOGO
        cmpi.b  #1, 0x114               | "Eyecatcher animation flag", "68k program header"
        bne.s   9f
        move.b  #1, BIOS_LOGO
        move.b  #0x01, 0x10FD81         | BIOS_SYSRET_STATUS, measured: code 1 on its return
        moveq   #0, %d1                 | BIOS_USER_MODE    = initialisation (measured: $00)
        moveq   #1, %d2                 | BIOS_USER_REQUEST = the animation
9:      rts

| ----------------------------------------------------------------------------------
| THE PASSAGE OF LINE $1F0, for the boot handshake. Identical copy of the one in
| `ecran.s`, where the measurement and the bound's count are: we wait to leave the line
| then to enter it, each wait bounded to SYNC_TOURS rounds (≈ 2 frames), watchdog at
| each round. Clobbers %d0.
        .equ    WATCHDOG, 0x300001
        .equ    LSPCMODE, 0x3C0006
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

| THE SAME WAIT, which stops as soon as REG_SOUND returns $01: Z at 1 if the echo is seen,
| at 0 if line $1F0 has passed without it. Clobbers %d0.
.Lsync_ou_echo:
        move.l  %d1, -(%sp)
        move.w  #SYNC_TOURS - 1, %d1
1:      move.b  %d0, WATCHDOG
        cmpi.b  #0x01, 0x320000
        beq.s   9f
        move.w  LSPCMODE, %d0
        lsr.w   #7, %d0
        cmpi.w  #0x1F0, %d0
        dbne    %d1, 1b
        move.w  #SYNC_TOURS - 1, %d1
2:      move.b  %d0, WATCHDOG
        cmpi.b  #0x01, 0x320000
        beq.s   9f
        move.w  LSPCMODE, %d0
        lsr.w   #7, %d0
        cmpi.w  #0x1F0, %d0
        dbeq    %d1, 2b
        moveq   #1, %d0                 | Z at 0: no echo
9:      movem.l (%sp)+, %d1             | `movem` does not touch Z
        rts

| ----------------------------------------------------------------------------------
| THE BACKUP RAM SIGNATURE — the 16 bytes of $D00010-$D0001F, measured: the ASCII
| `BACKUP RAM OK !`, then $80. The boot compares it and, when formatting, writes it last.
| ----------------------------------------------------------------------------------
        .balign 2
_signature_bram:
        .ascii  "BACKUP RAM OK !"
        .byte   0x80
