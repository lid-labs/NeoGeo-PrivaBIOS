# Changelog

All notable changes to Sprixe BIOS are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

- `docs/COMPARISON.md`: boot on flash carts is reported on a real BackBit, on an image older than
  the current one; the NeoSD Pro has no feedback yet.

### Fixed

- Compatibility bench: `irrmaze` now really runs Sprixe BIOS, and `vliner` gets past its setup screen,
  which was not a freeze. The MAME catalogue reads 163 of 164 under Sprixe BIOS, the SNK BIOS and
  UniBIOS 4.0; only `mvstemp` stays out, black under all three. The BIOS image does not change.

## [0.1.0-beta.2] - 2026-10-31

### Added

- Cartridge CRC32: under MAME, SMA and PVC protected cartridges are recognised; no real SMA or PVC
  board tried yet. The screen names the protection, says BANKS NOT READ and that FIXED is no file's
  CRC, where it used to show bank figures that meant nothing. The PVC test writes only on the NGH
  numbers of the three PVC games, so a PVC cartridge with a changed NGH is not named, and its bank
  line means nothing. Scenes `crc-sma`, `crc-pvc`,
  one for each of the five other protected sets and three `crc-hack-*`, eight mutations.
- MEMORY CARD: D copies every save to another card, asks before overwriting, refuses a card without
  the room, and never writes the source card (SAME CARD). In-game menu: RESTART TO CARD, after a
  confirmation, restarts the machine into the card manager; hidden under CHEATS/DEBUG OFF. A machine
  without a cartridge reaches the manager too, from HARDWARE TESTS. Scenes `cm-copier-tout`,
  `menu-carte`, `menu-carte-non` and `sans-cartouche-carte`, twelve mutations.
- In-game menu: the frame keeps a blank line under the help, and shows 3 cheats at a time, not 4.
- 1,568 cheats imported from the MAME XML Cheats Collection (Pugsy and contributors): 154 games and
  1,709 cheats in all, among them one-shot cheats that switch themselves off once applied, and
  one entry per value for selections, six values at most.
  Imported cheats are checked not to freeze the game, not proven one by one.
- Cheats for 46 more games, 77 cheats: INFINITE LIVES for 26 action games, P2 INF. LIVES for 23
  action games (P2 playing alone), P1 INFINITE LIFE for five
  fighting games, INFINITE TIME for fourteen more games (Ganryu, Burning Fight, Metal Slug 2 and 4, eight
  fighting games, Street Hoop, Super Sidekicks), NO GAME OVER for nine puzzle, quiz and sport games.
- INFINITE TIME for ten more fighting games: Art of Fighting 3, Breakers, Fatal Fury 2, Garou,
  Gowcaizer, The King of Fighters '98, The Last Blade 2, Ninja Master's, Savage Reign and World
  Heroes Perfect (#21).
- INFINITE BOMBS for Metal Slug 2, 3, 4 and 5 (#22).
- NO GAME OVER for Gururin, Thrash Rally and Zintrick, and P2 INF. LIVES for Twinkle Star Sprites
  (#23).
- INFINITE LIVES for Ninja Commando (#24).
- INFINITE TIME for The King of Fighters 2003, Real Bout Fatal Fury and Kizuna Encounter.
- INFINITE TIME for The King of Fighters '97 and P1 INFINITE LIFE for Samurai Shodown V Special. 98 games
  and 141 cheats in all.
- `bench/cheats-catalogue.sh`: a `tres-clair` pixel mode (R + G + B > 700), for white digits over a
  light background.
- `bench/cheats-recherche.py`, the tool that searches for cheats under MAME.
- `bench/cheats-recherche.py`: `action` takes any scenario (`passif` for fighting games); a `bombe`
  scenario, and the matching `b` entries in
  `bench/cheats-catalogue.sh`.
- `CLAUDE.md`, guidance for AI coding agents. New text in the repository is written in English.

### Changed

- In-game menu: a game can have up to 16 cheats (4 before). The menu shows 4 at a time and scrolls,
  with "CHEATS 5-8/12" under the title when some are hidden.
- `docs/MENUS.md`: the CARTRIDGE CRC screen says its picture stays black on kof2003.
- Site: a "Why another BIOS?" section replaces the comparison table, which stays in
  `docs/COMPARISON.md`. The README has the same section, shorter.
- `docs/DECISIONS.md` and source comments: behaviours observed on other BIOSes are no longer
  described as copied.
- `docs/COMPARISON.md`: comparison with UniBIOS redone from its official site, read in
  full, with no row resting on an absence of evidence. The site now says that coding agents wrote
  the code, the site and the README warn about the beta and backup RAM, and the site's button reads
  "Build v0.1 beta".
- Notes in English: `docs/DECISIONS.md`, `MENUS.md`, `AUTOFIRE.md`, `COMPATIBILITE.md`,
  `ESSAI-MATERIEL.md` and `measured/HISTORIQUE.md`.
- Code comments in English: `src/c0/`, `diag/slots/`, `build/harnais/`, `build/bios.ld`. The image
  is unchanged.
- Comments and headers of `bench/` and the build scripts in English. Runtime output of the
  bench scripts is unchanged.

### Fixed

- Formatting now clears the whole backup RAM, like the SNK BIOS. It stopped at `$D0007F`: under MAME,
  from a backup RAM holding other data, samsho4 then showed its anti-copy WARNING, and so did the SNK
  BIOS. A tester's board showed the same WARNING after our BIOS, and clearing its backup RAM cured it;
  that this was the cause on that board is not proven.
- `bench/parcours-mutations.py --verifier`, run by the CI: an edited source comment can no longer
  break a mutation unnoticed. Two had been broken that way.
- Source comments that contradicted the code next to them (cycle counts, menu line numbers, the
  Z80 parking, the calendar call), and the CI's description in CONTRIBUTING and README.
- AES mode: kof98's boot animation (request 1) no longer comes back after a game over. Its
  flag shared a byte with the cheat engine's freeze mask, which cleared it at the start of a game.
- `diag/slots` and `build/harnais` link again: they lacked the grid and sine table windows that
  `build/bios.ld` requires. The CI now builds both.
- `bench/cheats-catalogue.sh`: the samsho2 timer zone leaves out the bar above the digits (#16).
- `bench/parcours-mutations.py`: the `cat-mslug2-perdu` mutation no longer depends on the number of
  Metal Slug 2 cheats; it had stopped applying when that number changed.
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

[Unreleased]: https://github.com/lid-labs/sprixe-bios/compare/v0.1.0-beta.2...HEAD
[0.1.0-beta.2]: https://github.com/lid-labs/sprixe-bios/compare/v0.1.0-beta.1...v0.1.0-beta.2
[0.1.0-beta.1]: https://github.com/lid-labs/sprixe-bios/releases/tag/v0.1.0-beta.1
