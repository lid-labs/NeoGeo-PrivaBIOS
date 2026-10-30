# The trials on real hardware

Everything this package has measured was measured under MAME and on the cosim bench, except what
this file holds: the register of images tried on a real board, an **MV-2F (consolized, without a
TEST button)**. For each image: its date, what it brought, what was checked before the trial, what
the board showed and what was fixed. The videos and the raw reports stay outside the repository.
An image is identified by its CRC32 or its SHA-256.

**File names.** Since 2026-10-28, the BIOS is called Sprixe BIOS (`DECISIONS.md` §29): the
upcoming images are called `sprixe-bios-v0.1.rom` and `sprixe-bios-v0.1-byteswapped.bin`. The
register below keeps the names under which each image was sent.

## The image format

Each image is provided in both byte orders, built by `build/construire.sh`:
`rebios-v0.1.rom`, in MAME's order (`sp-s2.sp1`), to burn as is, and
`rebios-v0.1-byteswapped.bin`, swapped, for a programmer set the other way round.

MAME's order is the one the 68000 reads once the pairs are swapped: the file starts with
`10 00 00 F3`, that is the stack vector `$0010F300` in big-endian (`00 10 F3 00`). That a
programmer expects this order is ASSUMED, from the scene's practice of burning MAME's BIOS files
as is; hence the two files.

## The initial image and images no. 1 to no. 8 — from 2026-10-21 to 2026-10-23

**The initial image, on 2026-10-21**, not numbered: `src/c0` of `main` at `4d9f469c` (jukebox, #1391).

| File | CRC32 | SHA-256 |
|---|---|---|
| `rebios-v0.1.rom` | `2E64A6AF` | `83d9906386cb852c81093922091549f8a57f3e96f84c75175a4456c544d0866f` |
| `rebios-v0.1-byteswapped.bin` | `05C71B06` | `54dcad24cb4175b9c4d106f1e650ea40a02a9f9e8863eb578a87a21c29cfb85e` |

Checked before sending: this exact file, substituted under MAME (`-bios euro`), boots mslug, aof
and kof98 (`matrice.sh`, 30 s). Its CRC is the one MAME reports for our image. The trial path
requested: boot screen, game with a coin, second boot, test screen and one soft-DIP changed,
self-tests, jukebox, in-game menu, return to the original BIOS. Caveats for this image: never run
on hardware; only one slot served (slot 0); the backup RAM slot table is only partly measured
against the reference. The expected boot screen is mslug's under MAME, frame 60.

Images no. 1 to no. 8 each replaced the previous one **before any burning**; no. 8 is the first
tried on the board. Image no. 1 was checked by its mslug boot screen (frame 60), which differs
from the previous one only by the date on the CLOCK line. Images no. 2 to no. 8 were checked on
the exact file: full regression PASS, catalogue 161 games out of 164 with the verdicts of
`measured/2026-10-22-matrice-catalogue-soir.tsv` or of the cited matrix, mslug boot screen at
frame 60 equal to the previous one outside the CLOCK line (lines 153 to 167).

| No. | Date | `main` | What it adds | CRC32 `.rom` | Sum | SHA-256 `.rom` | CRC32 byteswapped |
|---|---|---|---|---|---|---|---|
| 1 | 2026-10-22 | `eeaeeac5` (#1396) | the hardware hardening, from `docs/AUDIT-2026-10-21.md` | `3D83D4C2` | — | `1db82fe1f959b3fecdb844d64fec7734abd1b22309937c4ef9d8b3ebaba8ea5e` | `5A9B62E5` |
| 2 | 2026-10-22 | `c29b5860` (#1407) | full multi-slot, game save in backup RAM, credit reset to zero at boot, START and coin at the reference's frame, DEMO_END | `9E199F82` | `FCB0` | `8e0ea5b87d49c769d1c763a7edf1685e0f94392132c95e39c97871dfc58ad173` | `8F86BD8B` |
| 3 | 2026-10-23 | `2152a2e0` (#1410) | joystick repeat, $10FD81 at START, FRAME_SKIP under INT1, the coin under INT1 | `A0CF795A` | `FAC9` | `dcb3a7c2bc6473eb62e69b5e89ff256ac8d68a759c49a2afe31ea601216d56a5` | `DB0C4010` |
| 4 | 2026-10-23 | `a84b44c2` (#1411) | PLAY TIME, player state cleared at each hand-over, the held frame of DEMO_END | `3817E1FE` | `4ACC` | `890e65f5816ef2a0047477d27dcdb05bacddafa7752bca27fe638c1bc94ee3c5` | `7A3E60AD` |
| 5 | 2026-10-23 | `bf73581b` (#1412) | the LEDs and REG_POUTPUT, the hand-overs and the held end of game | `781135D3` | `9200` | `112480d25eb3889881895ae23c00a04d33c980713f507e94b65f98202b78dbd2` | `66ECA6F7` |
| 6 | 2026-10-23 | `d95122a2` (#1414) | the single title after game over, the SELECT guard, the in-game menu that no longer cuts the game's sound (`2026-10-23-matrice-catalogue.tsv`) | `E11C2833` | `183E` | `528b7e9c7120bdabf29747eaa7993efdb2398df5a177062e1fb7314d1a60716a` | `ACCB9C6B` |
| 7 | 2026-10-23 | `14b54bb1` (#1417) | AES mode (MODE line of the editor, MVS by default, `DECISIONS.md` §11) (`measured/2026-10-23-matrice-catalogue-aes.tsv`) | `5175C745` | `CE40` | `bc6560f50412bbb23cece3f5d38a4a818c5c606ca5564b4407c983db4bc8127b` | `EDC5657D` |
| 8 | 2026-10-23 | `516016ce` (#1419) | CREDIT_CHECK in AES mode (aof shows "PUSH START" for P2); 63 scenes (`measured/2026-10-23-matrice-catalogue-credit-aes.tsv`) | `4AC27546` | `C49A` | `6fc2d51b7bf2823575e3dc0436f732314aa045de328a16ff52ff9e277d265ec6` | `BA27826C` |

## Image no. 8 on the board — 2026-10-24

**What the board showed** (MV-2F, two slots, several cartridges in both slots): the boot screen
displays correctly, but GAME NGH is **always E05C**, with or without a cartridge; no game starts
and the board reboots in a loop.

**The cause, shown under MAME and supported by the wiki, then confirmed by the diagnostic image**:
our boot read the slots' header under REG_BRDFIX, the reset state, and the reference under
REG_CRTFIX.
- MEASURED (`bench/acces-boot.lua`, `measured/2026-10-24-slot-crtfix.tsv`, ng_mv2f and MV-6F, 1 and 2
  cartridges, slot 0 empty): the reference sends $01 to the Z80 and waits for its echo, writes
  REG_SLOT ← 0, REG_CRTFIX, REG_SLOT ← 0, reads the header of each slot, then REG_BRDFIX. Image
  no. 8 read the header without ever writing REG_CRTFIX. MAME serves the cartridge in both cases,
  hence eight images without the bench seeing anything.
- READ (NeoGeo Development Wiki, 2026-10-24): "MVS cartridge pinout", SLOTCS "goes low when the
  slot is used", "On one slot boards, it's tied to SYSTEMB", "The System ROM was written to
  ensure the signal is asserted when it does the slot check"; "NEO-F0": "SYSTEMB is used to
  gate the SLOT* outputs"; "Signals": "SYSTEM: low when onboard ROMs selected".
- MEASURED, MAME served like this model (`bench/bus-flottant.lua`: under REG_BRDFIX, $000080-$0FFFFF
  and $200000-$2FFFFF return the prefetched word, like MAME's `unmapped_r` for a hole): image
  no. 8 shows **GAME NGH E05C**, the screen seen on the board; with kof98, it **reboots in a loop**
  (resets at frames 194, 387, 581, 775…): each boot sees every slot empty, redoes request 0,
  which kof98 ends with a reset. With mslug, the model lets the game start: the loop seen on the
  other cartridges is not explained by this model alone.

**Fixed** (`src/c0/c0.s`, the detection; `src/c0/ecran.s`, the NGH taken from the slot table):
the reference's order. Under the floating bus model, the fixed image no longer makes any floating
read at boot, shows 0201 for mslug in slot 0 as in slot 1, and kof98 makes only one reset (its
own) before running. Regression: stage 3f (`bench/bus-flottant.lua` on aof), which fails with the
fix removed (4 floating reads). The Z80 is parked before the detection and no longer at the boot's
slot switch, like the reference, and the hand-over falls on the same frame as before (188 on aof):
full regression PASS on image `88366706…`, matrix and 81 scenes unchanged.

**Same cause, fixed afterwards**: the boot soft-DIP editor switched to REG_BRDFIX for the board's
font, then read name and labels in the P-ROM (244 floating reads on entry under the model, "0"s
in place of the labels), and the self-tests and the jukebox redraw it on return. It now copies the
soft-DIP block to RAM under REG_CRTFIX before the switch (`dip.s`, `.Lcopier_bloc`). The five
writes of REG_BRDFIX are listed in `measured/2026-10-24-bus-flottant-ecran-test.tsv`; four `bf-*`
scenes play these screens under the model, at 0 floating reads and matching the witness run's
picture. Not judged: an exception raised during the TEST or crash screen would read its vector on
the floating bus (`DECISIONS.md` §13).

**Without a cartridge, the board rebooted in a loop**, under MAME too: the BIOS served the empty
slot 0, and the watchdog restarted the board every 192 frames. It now opens its self-tests
(`DECISIONS.md` §13 pt 3). This is probably part of the loop seen on the board without a
cartridge, without proof.

## Diagnostic image no. 1 — 2026-10-24

`diag/slots/`, built by `build/construire.sh diag/slots <output>`: with no cartridge to launch, it
shows REG_SYSTYPE, REG_STATUS_A, the word at $380000, REG_DIPSW and the Z80's echo, then for each
slot 0 to 7 the 16 bytes of $000100-$00010F read in six ways (A under REG_BRDFIX, image no. 8;
B under REG_CRTFIX, the fix; C B + REG_SWPROM; D REG_SLOT written as a word; E after 8 frames;
F as bytes), and Y if "NEO-GEO" is there. Two pages alternating every 240 frames; watchdog served,
the screen holds. Checked under MAME (ng_mv2f and neogeo, mslug in slot 0 then in slot 1, normal
bus and floating bus): 3,011 frames without a reset, the bytes read equal to those of the romset
(`4E454F2D47454F00 0201002000000010`). Under MAME, slots 6 and 7 are brought back to 5 by the jig
(MAME 0.286 exits with a segmentation fault on REG_SLOT ≥ 6, `m_slots[data]` unbounded): their
lines are valid only on the hardware. `rebios-slot-diag-1.rom` (MAME's order): CRC32 `942C132E`,
SHA-256 `290ba26cbdf5dc9f78e34f4e42b513dc69d6f3fd696a0c56219955da266e75dd`; byteswapped: CRC32
`122FDC22`.

**What the board showed, on 2026-10-25** (cartridge in slot 1, in slot 2, without a cartridge; the
bytes in `measured/2026-10-25-diag-slots-materiel.tsv`): the cartridge is read under REG_CRTFIX,
not under REG_BRDFIX. Method A (REG_BRDFIX, image no. 8) never sees "NEO-GEO", methods B to F all
see it, at its slot's index only. The board's slot 1 answers to REG_SLOT 0, slot 2 to REG_SLOT 1.
Without a cartridge, no Y (A to C). This confirms `DECISIONS.md` §13; images no. 9 to no. 11 read
the header under REG_CRTFIX (#1423). Indexes 2 to 7, absent from a two-slot board, return bytes
that are not a header, without crashing the board.

Diagnostic image no. 2 (#1435) was abandoned without a trial.

## Images no. 9 to no. 12 — 2026-10-24 and 2026-10-25

Each checked on the exact file: full regression PASS, catalogue 161 out of 164 with no game lost
(ng_mv1f not measured from no. 10 on).

| No. | Date | `main` | What it adds | Scenes | CRC32 `.rom` | Sum | SHA-256 `.rom` | CRC32 byteswapped |
|---|---|---|---|---|---|---|---|---|
| 9 | 2026-10-24 | `a8b3ffb8` (#1425) | reading the header under REG_CRTFIX (#1423), the soft-DIP editor that reads a copy of its block (#1424), self-tests without a cartridge (#1425), GAME SETTINGS and MEMORY EDITOR in the in-game menu (#1422) (`measured/2026-10-24-matrice-catalogue.tsv`) | 86 | `F9889F16` | `86A6` | `70f73d53be4b7c9bd036061e91d26ffc2d529922d4df04db8facac361f49b6cf` | `F331E3A7` |
| 10 | 2026-10-25 | `13a837d1` (#1427) | MEMORY CARD and SCORE RESET in the test screen | 98 | `B4411EDF` | `44FF` | `c4cba5b219ee7c4230ff34dbe2163c751cfcb163506d837734008940353b94e2` | `0E20CF19` |
| 11 | 2026-10-25 | `a3159605` (#1429) | CABINET SETTINGS in the test screen (FREE PLAY, NO CONTINUE, DEMO SOUND) | 106 | `1111B3F0` | `3F02` | `cdaca6b7a397ee5ff8a3820428386bb51406343316fd7addff7e506df8bdd10f` | `B997A318` |
| 12 | 2026-10-25 | `4d26ffdc` (#1432) | the cheat catalogue (35 games) and CHEATS/DEBUG in CABINET SETTINGS | 109 | `F8040392` | `F5B8` | `e5b4ea94d82df51ac3530ca731b8b432b993eb10053c5a2329d43dd161cb67d5` | `345FEAB1` |

**Image no. 12 on the board, on 2026-10-25** (switch 7 "Free Play" ON): the game starts in
slots 1 and 2, sound perfect; no input in play, START refused. ReBIOS ignored switches 1 and 7,
and the test screen was reachable only through the TEST button, absent from this board. Fixed by
#1439 (`DECISIONS.md` §17).

## Images no. 13 and no. 14 — 2026-10-25

| No. | `main` | What it adds | Scenes | CRC32 `.rom` | Sum | SHA-256 `.rom` | CRC32 byteswapped |
|---|---|---|---|---|---|---|---|
| 13 | `e7179b01` (#1439) | switch 7 honoured, the test screen on switch 1 or on START + SELECT held at boot, the in-game menu on START + SELECT | 119 | `7E672E6D` | `1E6E` | `981cd2aff816d11b0cbd2b5dc5a97a04950ed37a17fa30545027f83dd7ced0e8` | `CBA8D402` |
| 14 | `f8cb3e3f` (#1442) | the Super Sidekicks grid (`DECISIONS.md` §18); 142 mutations killed, catalogue identical game by game to the reference | 120 | `B660FA81` | `5B39` | `8f03e1deeff52bf1e7f7120dcf0c5b414f41cc0ff3bca712bd431e74b6f0fd73` | `E9437AD8` |

Each checked on the exact file: full regression PASS, catalogue 161 out of 164 with no game lost
(ng_mv1f not measured). ReBIOS's deviation on leaving the test screen with switch 1 ON
(§17 pt 4) was confirmed on the board with the original BIOS.

**Image no. 14 on the board, on 2026-10-26**: the soft-DIPs tried are honoured by the game, and
Super Sidekicks runs normally. Without a controller, switch 1 OFF: the boot screen once, then the
game; switch 1 ON: the boot screen, then the test screen. START + SELECT held at power-on: the TEST
screen, without a boot screen. START alone in play never opens the menu.
The test screen seen at every boot came from a **BlueRetro** controller adapter: when it starts
up, it holds L/R, A, B, C, D, START and SELECT for about one second, which the INPUT TEST showed;
plugged in during play, it opens the in-game menu. Fixed by #1450 (the gesture ignores the
BlueRetro). Super Sidekicks labels in the JAPAN region: #1449.

## Image no. 15 — 2026-10-28

`main` at `3830611b` (#1452, #1453, #1457, #1460). It adds to image no. 14 per-game autofire,
CARTRIDGE CRC, DEBUG DIPS, switches 2, 3 and 8, the mahjong panel page, the JUKEBOX screen saver,
card copy, GAME_DIP validation, the JAPAN labels, the gesture that ignores the BlueRetro and the
sine table (Alpha Mission II). `rebios-v0.1.rom`: CRC32 `C87FC0A6`, byte sum `951A`, SHA-256
`d54340ec83fc579a1a80fc19604d00cbe56d230738b1a95578642d2e5f57417e`; byteswapped: CRC32
`299AC253`. Checked on this exact image (#1460): full regression PASS (150 scenes), 195 mutations
killed, catalogue 161 out of 164 identical game by game to the reference (ng_mv1f not measured).
Everything new has only run under MAME. No feedback from the board yet.

**What the board showed, on 2026-10-28.** Commercial cartridges boot. The NeoSD Pro and the
BackBit stop on the boot screen, GAME NGH ..... 0000.

GAME NGH comes from the slot table, and 0000 there is an empty slot: the detection found no
cartridge. It went through the slots once, at frame 1; the reference does it at frame 276
(`measured/2026-10-24-slot-crtfix.tsv`). ASSUMED: a flash cart loads its menu after power-on and
does not yet return its header at frame 1. Under MAME, a cartridge silent for 30 frames
reproduces the screen (`measured/2026-10-28-carte-lente.tsv`). Fixed (`DECISIONS.md` §31,
flash-cart scene). Not reproduced: under MAME, the image then goes to HARDWARE TESTS, and the
board showed nothing of the sort.

## Image no. 16 — 2026-10-28

The `fix/flash-cart-detection` branch at `672dda5` (#7, `main` merged). It adds to image no. 15 the
flash cart fix (`DECISIONS.md` §31), the game save kept after the WORK RAM test, the menus on the
mahjong panel (§30), the Sprixe BIOS name and the `v0.1 BETA` boot screen.
`sprixe-bios-v0.1.rom`: CRC32 `4C2FA24C`, byte sum `28FB`, SHA-256
`6a662f7f16b5447c4ac210178abf73aaa3a784c1ae79509e49350731169aa015`; byteswapped: CRC32 `E903F17A`.
Checked on this exact image: 12 targeted scenes PASS (sans-cartouche, flash-cart, boot, multi-slot,
floating bus, AES mode). Neither the full regression nor the catalogue was run. No feedback from
the board yet.
