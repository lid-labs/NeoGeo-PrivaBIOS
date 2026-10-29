# Changelog

All notable changes to Sprixe BIOS are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

- In-game menu: a game can have up to 16 cheats (4 before). The menu shows 4 at a time and scrolls,
  with "CHEATS 5-8/12" under the title when some are hidden.
- Site: the comparison table no longer lists scores on memory card.

### Fixed

- README: the status line no longer says that no release exists.
- Cartridge CRC32: a cartridge without bank chips no longer shows a bank. On a real Super Sidekicks
  cartridge, the bank window read the same word everywhere and the screen showed BANKS 1 X 1024K;
  it now shows BANKS NONE (`measured/2026-10-29-crc-ssideki-materiel.tsv`).

## [0.1.0-beta.1] - 2026-10-28

First public pre-release. Development history before it (October 2026) is summarised in `docs/`
(in French).

### Added

- Boot of a cartridge and the system calls games rely on: controls, credits, timer interrupt, sound
  handshake, memory card, calendar.
- Boot screen drawn with the BIOS font only; any button skips it.
- Soft-DIP editor at boot (TEST held, START + SELECT held, or board switch 1 ON), with region and
  MVS/AES mode. Soft-DIP labels in the JAPAN region.
- In-game menu (START + SELECT or TEST held about a third of a second): resume, restart, per-game
  cheats, autofire, GAME SETTINGS and a memory editor with value freezing.
- Per-game autofire on buttons A to D, at 10, 15 or 30 shots per second.
- Cheats for 35 games (40 cheats).
- Cabinet settings: FREE PLAY, NO CONTINUE, DEMO SOUND, CHEATS/DEBUG, DEBUG DIPS.
- Board DIP switches 1, 2, 3, 7 and 8: settings at power-on, VS mode, mahjong panel, free play,
  freeze (with a message at power-on).
- Hardware tests, input test (joysticks and mahjong panel), colour bars, crosshatch, cartridge CRC32.
- Memory card manager: list, free blocks, delete, format, copy one save to another card.
- High scores kept in backup RAM, and SCORE RESET.
- Jukebox, with a screen saver.
- Multi-slot boards: SELECT changes game.
- AES mode on an MVS board.
- A sine table where games expect one in the BIOS ROM ($C04000-$C041FF).
- Soft-DIP blocks left by another BIOS are checked value by value before a game reads them.
- An ABOUT screen in the TEST menu, just above CABINET SETTINGS (`src/c0/about.s`): name and
  version, copyright, no-warranty notice, the GPL version 3 or later, where to find the source, and
  the hardware tester. One `ab-ecran` scene, three mutations.
- README: badges, an animated boot screen and a gallery of screenshots (`docs/screenshots/`),
  taken under MAME with a homebrew cartridge.
- The website, in `site/`: a static page published by GitHub Pages at bios.sprixe.dev once the
  repository is public (`.github/workflows/pages.yml`, activation steps in `docs/SITE.md`).
- README: a Thanks section, for the hardware tester.
- Release process: a tag `vX.Y.Z` on `main` builds the image and opens a draft GitHub release with
  both byte orders, `SHA256SUMS` and the version's section of this file as notes
  (`.github/workflows/release.yml`, `build/release.py`, `docs/RELEASE.md`).
- The BIOS menus can be driven from a mahjong panel (`src/c0/panneau.s`, `docs/DECISIONS.md` §30).
  With board switch 3 ON, A-D act as buttons A-D, E/F as up/down and G/H as left/right; with it
  OFF, the panel reads as a joystick. The switch is read when a menu opens, as the Japanese SNK
  BIOS and UniBIOS 4.0 were observed to do (`measured/2026-10-28-panneau-menus-reference.tsv`).
  The in-game menu stays out of reach from the panel, which has no SELECT. Five `pn-*` scenes,
  four mutations.

### Changed

- Boot screen layout: less margin at the top (title on line 4 instead of 6), the status block two
  lines higher, and two blank lines between it and PRESS A BUTTON TO SKIP. The version reads
  `v0.1 BETA`, centred under the URL (`src/c0/ecran.s`). Screenshots `boot.png`, `boot.gif` and
  `social-preview.png` retaken.

### Fixed

- NeoSD Pro and BackBit stopped on the boot screen with GAME NGH 0000, an empty slot. The slots
  were read once, on the first frame, likely before a flash cart has loaded its menu (not yet
  confirmed on the board). They are now read again on each frame while none is found, for up to
  270 frames, about when the original BIOS reads them (`src/c0/c0.s`, `ATTENTE_CARTE`,
  `docs/DECISIONS.md` §31). Without a cartridge, the boot screen comes about 4.5 s later. New
  scene `flash-cart`, mutation `carte-lente-ignoree`.
- HARDWARE TESTS → WORK RAM no longer erases the save of a game already registered in backup RAM.
  The save was restored to work RAM before the TEST screen, the RAM test overwrote it, and the end
  of the demo wrote the damaged area back to backup RAM. It is now restored after the soft-DIP
  editor, then the debug dips are set again (`src/c0/c0.s`,
  `measured/2026-10-28-work-ram-restauree.tsv`). Scenes `tests-sauvegarde` and `dd-connu`, two
  mutations.

[Unreleased]: https://github.com/lid-labs/sprixe-bios/compare/v0.1.0-beta.1...HEAD
[0.1.0-beta.1]: https://github.com/lid-labs/sprixe-bios/releases/tag/v0.1.0-beta.1
