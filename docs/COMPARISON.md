# Sprixe BIOS and UniBIOS 4.0

UniBIOS is the reference of the Neo Geo scene, and this page exists to describe the two as they
are. Each UniBIOS cell says where it comes from:

- **Documented**: read on the [official site](http://unibios.free.fr/), all of it read on
  2026-10-30: its feature, requirements, how-it-works, FAQ, known issues, PICKnMIX, PC-2-NEO and CD
  pages, the screenshots, and the release notes `download/whatsnew.txt` (v1.0 to v4.0). The binary
  was never opened.
- **Reported**: public forum threads, not the author. `docs/ATTENTES.md` lists them, with the
  threads we could read and those we could not.
- **Measured here**: observed running under MAME 0.286.

The Sprixe BIOS column is measured, each line by its own test scene. Everything is under MAME
unless it says otherwise, and judged on picture or sound: Sprixe BIOS has run on one real board so
far. A feature found neither on the site nor in the threads is not set against anything: those
are in [Not compared](#not-compared).

## Playing

| Topic | UniBIOS 4.0 | Sprixe BIOS |
|---|---|---|
| Autofire | ◐ **As cheats**. Documented for the Metal Slug series, Sonic Wings 2 and 3, Ghost Pilots and Zed Blade (v2.1). | ◐ **As a setting**. A, B, C and D set one by one, at 10, 15 or 30 shots per second, remembered for each game. It only reaches games that read the controls through the BIOS: 89 of the 164 we measured. |
| Cheats | ✓ **Yes**. More than 1,570 cheats, plus Patch Memory (v2.0) to add your own. | ◐ **Smaller**. 136 cheats for 94 games, found by observing the games. Far fewer than UniBIOS. |
| Soft-DIPs | ◐ **In test mode**. Also in the main menu on AES, after a soft reboot. The in-game menu has no soft-DIP entry (site screenshot; entries measured here on 2026-10-23). | ✓ **Yes**. GAME SETTINGS in the in-game menu, and the editor at boot. |
| Soft-DIPs of a game never launched | ✕ **Documented limit**. Entering test mode by B+C+D before a new game has booted once corrupts its entry; the author's advice is to let it boot first. | ✓ **Handled**. The editor shows the cartridge defaults and saves a clean entry. A garbled entry left by another BIOS is checked value by value before the game sees it. |
| Region and system mode | ✓ **Yes**. Region, and arcade or console, from the main menu. | ✓ **Yes**. REGION and MODE in the editor at boot. |

## Saving

| Topic | UniBIOS 4.0 | Sprixe BIOS |
|---|---|---|
| High scores | ✓ **Yes**. On the memory card, AES hardware included (v3.1, "not fully tested" in its notes), with an option that stops the periodic wipe on MVS (v4.0). Forum users report scores neither saved nor read back (v3.1 to v3.3). | ◐ **Partly**. Kept in backup RAM in MVS and AES modes, with SCORE RESET to stop the periodic wipe. Not saved on the memory card. |
| Memory card manager | ✓ **Yes**. Reachable in every mode. | ◐ **Partly**. In the test screen only: list, free blocks, delete, format, and copy one save to another card. No COPY ALL. |

## Operators and repair

| Topic | UniBIOS 4.0 | Sprixe BIOS |
|---|---|---|
| Keeping players out | ✓ **Yes**. Enable Arcade Protect (v2.1) puts the button codes behind the test button; the notes advise also disabling the in-game menu and input crossing. | ✓ **Yes**. CHEATS/DEBUG OFF in cabinet settings removes the cheats, the memory editor and the debug dips. |
| Board without a TEST button | ✓ **Yes**. B+C+D on the splash screen opens test mode, with no JAMMA wiring. | ✓ **Yes**. Switch 1, or START + SELECT held at power-on, opens the test screen. |
| Cartridge CRC32 | ✓ **Yes**. Since v1.1, against a database. Protected banks are shown as custom (v1.2). | ✓ **Yes**. The fixed P-ROM and each bank, as the 68000 reads them. SMA and PVC protected cartridges are not recognised yet. |
| RAM and VRAM viewers, debug dips | ✓ **Yes**. RAM and VRAM viewers, debug dips, developer mode. | ◐ **Partly**. RAM editor with value freezing, and debug dips. No VRAM viewer. |
| Crash screen | ✓ **Yes**. 68000 status on screen (v1.3). | ✓ **Yes**. SYSTEM CRASH: the exception, the registers and the game's NGH. |
| Input test | ✓ **Yes**. 4-player adapter and mahjong panel (v3.2). | ◐ **Partly**. Joysticks and the mahjong panel. No 4-player page. |

## Boot and multi-slot

| Topic | UniBIOS 4.0 | Sprixe BIOS |
|---|---|---|
| Boot on flash and homebrew carts | ◐ **Reported**. Forum threads, 2018 on, describe a logo that comes out scrambled on slow flash boards; the author's known issues do not list it. v4.0 adds fixes specific to the NeoSD. Measured here, with the cartridge graphics replaced by noise: the logo scrambles in 155 of 190 frames. | ◐ **Not confirmed**. The boot screen uses only the BIOS font, and the same noise test changes no frame. But image 15 stopped at boot on a real NeoSD Pro and a real BackBit, and the fix in image 16 has no feedback yet. |
| Multi-slot boards | ◐ **Designed for them, with a documented bug**. Sound is missing when slot 1 is empty (known issues, "introduced in v4"), and fonts when KOF2003 is in slot 1 of a 4 or 6 slot board. Forums also report black screens and EXCEPTION ERROR HANDLING at boot on v4.0, and advise v3.2. Neither the missing sound nor these boots were reproduced here, under MAME; that says nothing of the boards where they were reported. | ◐ **Tested on two**. MV-6F under MAME: rotating demo, SELECT for P1 and P2, sound on slot 2 with slot 1 empty. Real MV-2F: games boot from both slots. Not tested on a real 4 or 6 slot board. |

## Hardware

| Topic | UniBIOS 4.0 | Sprixe BIOS |
|---|---|---|
| Systems | ✓ **MVS, AES and CD**. All MVS types, slot 1 and multi-slot, AES, and the three CD models (v3.3). | ◐ **MVS only**. An AES mode on MVS boards. No image for the AES console or CD systems. |
| Real boards | ✓ **Its user base**. Installers and users over about twenty years. | ◐ **One**. A single MV-2F so far. |
| Compatibility under MAME | 162 of 164 games play in our catalogue, judged on the picture. | 161 of 164, same test. Not evidence for real hardware. |

## Look and extras

| Topic | UniBIOS 4.0 | Sprixe BIOS |
|---|---|---|
| Jukebox | ✓ **Yes**. In the notes since v1.1, with fade-out (v2.1). | ✓ **Yes**. Outside games. |
| Screen saver, menu colours | ✓ **Yes**. In-game menu blanking and menu colours (v2.3), jukebox screen saver (v3.1). | ◐ **Partly**. Screen saver in the jukebox: black screen after about two minutes, music keeps playing. No menu colours. |
| Arcade VS | ✓ **Yes**. Hard DIP 2, with separate coin inputs (v1.1). | ◐ **Partly**. Switch 2 passes the request to the games; kizuna then shows a second CREDIT counter. No 4-player adapter. |
| US-style credit display, PC-2-NEO, PICKnMIX, overclock detection, coin and select remapping for joypads | ✓ **Yes** | ✕ **No** |
| Code | A patched SNK BIOS, new code by its author (Razoola). | Written from scratch in 68000 assembly by coding agents, no SNK or UniBIOS code ([`METHOD.md`](METHOD.md)). |
| Licence | Free to download since March 2020. Personal use only: no distribution, no sale, no alteration, and original hardware required. | GPL-3.0-or-later. The source code is on GitHub. |
| Development | v4.0 in May 2018; PC-2-NEO updated in January 2025. | Beta, started in October 2026. |

## Not compared

Sprixe BIOS has these. We found nothing about them on UniBIOS's site, which is no evidence either
way, so they get no column:

- NO CONTINUE and DEMO SOUND in cabinet settings.

Free play is not listed: board switch 7 gives it whatever the BIOS, and UniBIOS's FAQ says so.
