# Sprixe BIOS and UniBIOS 4.0

The UniBIOS column comes from its author's release notes (v1.3 to v4.0) and public forum
threads; its binary was never opened. The Sprixe BIOS column is measured, each line by its own
test scene. "Not found" means absent from the notes and threads we could read, which is not proof
that UniBIOS lacks it.

## Playing

| Topic | UniBIOS 4.0 | Sprixe BIOS |
|---|---|---|
| Per-game autofire | ? **Not found**. Not in any release note we read. | ✓ **Yes**. A, B, C and D set one by one, at 10, 15 or 30 shots per second, remembered for each game. It only reaches games that read the controls through the BIOS: 89 of the 164 we measured. |
| Cheats | ✓ **Yes**. A database of more than 1,570 cheats, plus Patch Memory (v2.0). | ◐ **Smaller**. 64 cheats for 56 games, found by observing the games. Far fewer than UniBIOS. |
| Cheats and debug switched off by the operator | ? **Not found**. RetroAchievements bans UniBIOS as a whole because of cheats and debug (RetroArch #18989, April 2026). | ✓ **Yes**. CHEATS/DEBUG OFF in cabinet settings removes the cheats, the memory editor and the debug dips. |
| Soft-DIPs during a game | ✓ **Yes**. From the in-game menu (v4.0). | ✓ **Yes**. GAME SETTINGS in the in-game menu, and the editor at boot. |
| Soft-DIPs of a game never launched | ✕ **Known issue**. Listed by its author as a v4.0 limit: the entry gets corrupted. We only saw this page through a search snippet. | ✓ **Handled**. The editor shows the cartridge defaults and saves a clean entry. A garbled entry left by another BIOS is checked value by value before the game sees it. |

## Saving

| Topic | UniBIOS 4.0 | Sprixe BIOS |
|---|---|---|
| High scores | ✓ **Yes**. On the memory card, AES mode included (v3.1). Forum users report scores that are neither saved nor read back (v3.1 to v3.3). | ◐ **Partly**. Kept in backup RAM in MVS and AES modes, with SCORE RESET to stop the periodic wipe. Not saved on the memory card. |
| Memory card manager | ✓ **Yes**. Reachable in every mode. | ◐ **Partly**. In the test screen only: list, free blocks, delete, format, and copy one save to another card. No COPY ALL. |

## Operators and repair

| Topic | UniBIOS 4.0 | Sprixe BIOS |
|---|---|---|
| Free play, no continue, silent demo | ? **Not found**. Not in the release notes we read. | ✓ **Yes**. FREE PLAY, NO CONTINUE and DEMO SOUND in cabinet settings. Board switch 7 also gives free play. |
| Board without a TEST button | ? **Not documented** | ✓ **Yes**. Switch 1, or START + SELECT held at power-on, opens the test screen. Found on the tester's consolized MV-2F. |
| Cartridge CRC32 | ✓ **Yes**. Since v1.3. | ✓ **Yes**. The fixed P-ROM and each bank, as the 68000 reads them. SMA and PVC protected cartridges are not recognised yet. |
| RAM and VRAM viewers, debug dips | ✓ **Yes**. RAM and VRAM viewers, debug dips, developer mode. | ◐ **Partly**. RAM editor with value freezing, and debug dips. No VRAM viewer. |
| Input test | ✓ **Yes**. 4-player adapter and mahjong panel (v3.2). | ◐ **Partly**. Joysticks and the mahjong panel. No 4-player page. |

## Boot and multi-slot

| Topic | UniBIOS 4.0 | Sprixe BIOS |
|---|---|---|
| Boot screen on flash and homebrew carts | ✕ **Known issue**. The logo is drawn with the cartridge's graphics and comes out scrambled on slow flash boards (several forum threads, 2018 on). Under MAME, with the cartridge graphics replaced by noise, it scrambles in 155 of 190 frames. | ✓ **Yes**. The boot screen uses only the BIOS font. Same noise test: not one frame changes. |
| Multi-slot boards | ✕ **Reported**. v4.0 is reported to boot to a black screen or EXCEPTION ERROR HANDLING, and to lose sound on slot 2 and up. Forums advise v3.2. We could not reproduce it under MAME. | ✓ **Yes**. MV-6F under MAME: rotating demo, SELECT for P1 and P2, sound on slot 2 with slot 1 empty. Real MV-2F: games boot from both slots. |

## Look and extras

| Topic | UniBIOS 4.0 | Sprixe BIOS |
|---|---|---|
| Screen saver, menu colours | ✓ **Yes**. Screen saver (v2.3), menu colours (v4.0). | ◐ **Partly**. Screen saver in the jukebox: black screen after about two minutes, music keeps playing. No menu colours. |
| US-style credit display, Arcade VS, PC-2-NEO, PICKnMIX | ✓ **Yes** | ✕ **No** |
| Licence | Personal use only: no sale on chips, no redistribution, no modification. | GPL-3.0-or-later. Our own code, not derived from SNK or UniBIOS. The source code is on GitHub. |
| Development | Last release, v4.0, in May 2018. | Active since October 2026. |
