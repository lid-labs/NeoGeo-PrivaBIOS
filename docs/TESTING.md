# Testing on real hardware

PrivaBIOS has run on one real board so far, an MV-2F ([`ESSAI-MATERIEL.md`](ESSAI-MATERIEL.md)).
Everything else was measured under MAME. This page says what is most worth trying on a real board,
and how to report it. Reports that something works are as useful as reports that it does not.

## The image to test

The current image is release
[v0.1.0-beta.3](https://github.com/lid-labs/NeoGeo-PrivaBIOS/releases/tag/v0.1.0-beta.3):

| File | CRC32 | Use |
|---|---|---|
| `privabios-0.1.0-beta.3.rom` | `462044E7` | MAME byte order: burn it as is first |
| `privabios-0.1.0-beta.3-byteswapped.bin` | `C5B19350` | bytes swapped in pairs, if the board shows nothing with the first |

The SHA-256 of both files are in the release's `SHA256SUMS`. Burn and install as the README says
([Installation](../README.md#on-an-mvs-board)), and write down your board's settings first: scores
and settings in backup RAM could be lost.

## What to try, most wanted first

The menus are described in [`MENUS.md`](MENUS.md). The test screen opens with TEST held at
power-on, or START + SELECT held, or board switch 1 at ON.

1. **Flash carts: NeoSD Pro, BackBit** ([#52](https://github.com/lid-labs/NeoGeo-PrivaBIOS/issues/52)).
   Does the flash cart's menu appear, and do games start from it? Image 15 stopped at the boot
   screen on both.
2. **A 4 or 6 slot board** ([#53](https://github.com/lid-labs/NeoGeo-PrivaBIOS/issues/53)). Boot from
   each slot, including with slot 1 empty; sound on slot 2 and beyond; the rotating demo; SELECT
   for player 1 and player 2.
3. **SMA and PVC cartridges** ([#72](https://github.com/lid-labs/NeoGeo-PrivaBIOS/issues/72)): SMA is
   kof99, garou, mslug3, kof2000; PVC is mslug5, svc, kof2003. Open HARDWARE TESTS, then CARTRIDGE
   CRC: the screen should name the protection and say BANKS NOT READ. Then check that the game
   starts normally. On kof2003 the screen stays black under MAME: say what your board shows.
4. **Any other board and any game.** Does the boot screen show, does the game start, does a full
   credit play through to game over? The in-game menu (TEST, or START + SELECT, held about a third
   of a second during play): do the cheats and autofire work on your game?

## Known issues, no need to report

- CARTRIDGE CRC shows 2 banks on rotd; it has 7 ([#74](https://github.com/lid-labs/NeoGeo-PrivaBIOS/issues/74)).
- Autofire reaches only the games that read the controls through the BIOS
  ([`AUTOFIRE.md`](AUTOFIRE.md)).
- Imported cheats are checked not to freeze the game, not to do what their title says
  ([`CHEATS.md`](CHEATS.md)).

## How to report

Open an issue with the
[hardware report](https://github.com/lid-labs/NeoGeo-PrivaBIOS/issues/new?template=hardware_report.yml)
form. Always give the board, the CRC32 of the file you burnt, and the cartridge or flash cart. A
photo or a short video of the screen helps a lot. Never attach a ROM, a dump or a link to one.
