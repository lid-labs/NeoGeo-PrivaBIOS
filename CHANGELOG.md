# Changelog

All notable changes to Sprixe BIOS are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0] - Unreleased

First public version. Development history before this release (October 2026) is summarised in
`docs/` (in French).

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
