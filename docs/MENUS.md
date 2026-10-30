# The map of Sprixe BIOS menus

Where each screen is, and the key that leads to it. Read in the code on 2026-10-25 (main at
`703cf222`), AUTOFIRE added on 2026-10-27 (#1454), ABOUT on 2026-10-28:
the labels are those of the screen, the source of each screen is in parentheses. The controls
are player 1's, edge-triggered (a press counts once).

```
Power-on
├── Boot screen (ecran.s) ── a button skips it
├── TEST held, or START + SELECT held, or switch 1 at ON ──► SOFT DIP SETTINGS (dip.s)
│     ├── REGION
│     ├── the cartridge's settings (depending on the game)
│     ├── ABOUT ──► legal notices and credits (about.s)
│     ├── CABINET SETTINGS ──► FREE PLAY, NO CONTINUE, DEMO SOUND, CHEATS/DEBUG (reglages.s), DEBUG DIPS (debug.s)
│     ├── SCORE RESET
│     ├── MEMORY CARD ──► list of saves, FORMAT CARD, EXIT (gestion-carte.s)
│     ├── MODE
│     ├── HARDWARE TESTS ──► WORK RAM … CROSSHATCH, CARTRIDGE CRC (crc.s), EXIT (tests.s)
│     ├── JUKEBOX (jukebox.s)
│     └── RESET TO DEFAULTS
└── The game
      ├── TEST, or START + SELECT, held ~1/3 s during play ──► IN-GAME MENU (menu.s)
      │     ├── RESUME
      │     ├── RESTART GAME
      │     ├── the game's cheats, ON/OFF (cheats.s)
      │     ├── AUTOFIRE (autofire.s)
      │     ├── GAME SETTINGS (reglages-jeu.s)
      │     └── MEMORY EDITOR (memoire.s)
      ├── SELECT outside play, multi-slot ──► next game (P1) or previous (P2)
      └── a 68000 exception ──► SYSTEM CRASH (plantage.s)
```

## The TEST screen: SOFT DIP SETTINGS

**Getting in**: hold the board's TEST button at power-on, until the screen appears. It opens
after the boot screen, before the game. Without a TEST button (a consolized MVS), two other paths:

- hold P1's START and SELECT together from power-on: they skip the boot screen and
  open this one. Refused if A, B, C and D are all four held at the same time, which the
  BlueRetro adapter does when it starts up; with one, two or three of them, the gesture works;
- set board switch 1 ("Setting Mode") to ON: the screen opens at every power-on
  as long as it stays there. START still leaves it: left at ON, DIP SWITCH 1 IS ON shows for
  about three seconds (or until it is switched back), then the game; switched back to OFF during
  the screen, the game right away. Under MAME, the SNK BIOS and UniBIOS refuse to leave it while it
  is at ON ("DIP-SW 1 OFF !!").

**Controls**: UP/DOWN chooses the line, wrapping around; LEFT/RIGHT changes the value; A goes to the
next value and starts over after the last one (for a one-button cabinet); START
saves and starts the game.

**The shortest path: "up" from the first line**, because the list wraps around and the
number of cartridge settings varies from one game to another. These paths do not depend on the game:

| "up" × | Line | What it does |
|---|---|---|
| 0 | REGION | JAPAN, USA, EUROPE; once changed, START restarts the machine in that region |
| 1 | RESET TO DEFAULTS | LEFT, RIGHT or A resets the cartridge's settings to their defaults |
| 2 | JUKEBOX | LEFT, RIGHT or A opens it |
| 3 | HARDWARE TESTS | LEFT, RIGHT or A opens it |
| 4 | MODE | MVS, AES; once changed, START restarts the machine in that mode |
| 5 | MEMORY CARD | LEFT, RIGHT or A opens the card manager |
| 6 | SCORE RESET | ON, OFF; at OFF, the games that erase their high scores when the date changes keep them |
| 7 | CABINET SETTINGS | LEFT, RIGHT or A opens the cabinet settings |
| 8 | ABOUT | LEFT, RIGHT or A opens the legal notices and the credits |

The cartridge's settings start at "down" once. REGION, MODE, SCORE RESET and CABINET
SETTINGS are not cartridge settings: RESET TO DEFAULTS does not touch them.

In the JAPAN region, when the cartridge gives its labels in Japanese, the list is written in large
characters, like the Japanese SNK BIOS: two rows per line, ten lines on screen, and the list
scrolls with the chosen line. The controls and the "up" paths do not change
(`DECISIONS.md` §19).

### ABOUT

The name and the version, the copyright, the absence of warranty, the licence (GPL version 3 or
later), the address of the source and the hardware tester. START goes back to the list.

### CABINET SETTINGS

Five lines; UP/DOWN chooses, LEFT, RIGHT or A changes the value. START goes back to the list, and
it is the list's START that saves, without a restart.

| Line | Values | Effect |
|---|---|---|
| FREE PLAY | OFF, ON, DIP | START starts a game without a coin, P2 included. DIP: board switch 7 is at ON, which is enough; the line no longer changes |
| NO CONTINUE | OFF, ON | START is refused during the continue countdown |
| DEMO SOUND | ON, OFF | At OFF, the demos are silent; title and play keep the sound |
| CHEATS/DEBUG | ON, OFF | At OFF, the in-game menu no longer offers cheats or MEMORY EDITOR |
| DEBUG DIPS | the mask in hexadecimal, or OFF | LEFT, RIGHT or A opens the debug dips screen; OFF under CHEATS/DEBUG OFF, and the line does not open |

In AES mode, the first three show MVS ONLY and have no effect; CHEATS/DEBUG applies in both
modes. Board switch 7 ("Free Play") puts the cabinet in free play like FREE PLAY ON,
and it is read again while the machine is on. Details: `DECISIONS.md` §15 and §16.

**DEBUG DIPS**: two rows of eight bits, DIP 1 and DIP 2. LEFT/RIGHT chooses the bit, UP/DOWN the
row, A toggles it; START goes back. The chosen bits are set to 1 in the two bytes that the game
reads for its debugging tools, every frame, in the demo as in play; they are never
saved and are cleared at power-off (`DECISIONS.md` §20).

### MEMORY CARD

UP/DOWN chooses a save (NGH, sub-number, blocks, game name), FORMAT CARD or EXIT. A on
a save erases it, A on FORMAT CARD formats the card; both ask for confirmation (A yes,
B no). C on a save copies it: CHANGE CARD AND PRESS A, the card is changed, A writes it; if the
new card already has that save, OVERWRITE ? asks for confirmation. B gives up. START goes back. No card: NO CARD; blank card: CARD NOT FORMATTED; protected card:
WRITE PROTECTED.

### HARDWARE TESTS

UP/DOWN chooses, wrapping around from WORK RAM, A starts, START goes back.

| "up" × | Test | What it shows |
|---|---|---|
| — | WORK RAM, PALETTE RAM, VRAM, BACKUP RAM | OK, or FAIL with the address, the value written and the value read |
| — | INPUT TEST ("down" × 4) | the state of the inputs; START held 1 s to leave. Board switch 3 at ON on opening: the mahjong panel page, 0 or 1 per key (A to N, PON to REACH, START, SELECT) |
| — | COLOR BARS ("down" × 5) | colour bars; A changes page |
| 3 | CROSSHATCH | an alignment test pattern |
| 2 | CARTRIDGE CRC | the CRC32 of the cartridge's P-ROM, FIXED then BANKS, to compare with the romset's; START stops the computation (`DECISIONS.md` §20) |
| 1 | EXIT | back to the list |

### JUKEBOX

UP/DOWN changes the code by 1, LEFT/RIGHT by 16, A plays, B stops, START leaves. Codes 01 to 03
are skipped. If nothing plays, the screen suggests code 07 (PLAY 07 FIRST IF SILENT). After about
two minutes without touching anything, the screen goes black and the music keeps playing; a key
turns it back on without doing anything else (`DECISIONS.md` §25).

## The in-game menu: IN-GAME MENU

**Getting in**: during play (not in the demo), hold TEST about 1/3 s, or P1's START and SELECT
together (without a TEST button), except with A, B, C and D all four held (the BlueRetro adapter, as at
boot). The game pauses, the music keeps playing.

**Controls**: UP/DOWN chooses, A or START confirms. On a cheat line, A or START toggles ON/OFF
and the menu stays open. A game has up to 16 cheats; the frame shows 4, and the list scrolls behind
the cursor. Beyond 4, the line under the title says which ones are shown ("CHEATS 5-8/12").

| From RESUME | Line | What it does |
|---|---|---|
| — | RESUME | returns the game where it was |
| "down" × 1 | RESTART GAME | restarts the machine |
| "down" × 2 and following | one cheat per line, up to 16 | only for the games in the table (`measured/2026-10-25-cheats-table.tsv`) |
| "up" × 3 | AUTOFIRE | autofire for A, B, C and D, kept for this game |
| "up" × 2 | GAME SETTINGS | the game's soft-DIPs, during play |
| "up" × 1 | MEMORY EDITOR | the game's RAM |

**Under CHEATS/DEBUG at OFF**, the cheats and MEMORY EDITOR disappear: "up" × 1 then leads to
GAME SETTINGS, "up" × 2 to AUTOFIRE.

### AUTOFIRE

Four lines BUTTON A to BUTTON D, each OFF or ON, then RATE: 15/S by default, 30/S or 10/S
(shots per second). UP/DOWN chooses; RIGHT sets ON (or the rate above), LEFT sets OFF (or
the rate below), A toggles (or goes to the next rate); START goes back.

A button at ON, held, fires by itself: the game sees it pressed then released, at the chosen rate,
and the first press goes out right away. The setting applies to players 1 and 2, and it is kept for
this game, even with the machine off: each game has its own, and a game that was never set has
none. It only has an effect on the games that read the joystick through the BIOS: the list, game by
game, is in `AUTOFIRE.md`. Off with the mahjong panel (switch 3 at ON). Details: `DECISIONS.md` §22.

### GAME SETTINGS

The cartridge's settings, then RESET TO DEFAULTS and RESTART GAME; neither REGION nor MODE. In the
JAPAN region, the labels are those the cartridge gives for the USA, when its two lists of settings
have the same shape; otherwise they stay blank (`DECISIONS.md` §19).
UP/DOWN chooses, LEFT, RIGHT or A changes, START goes back. Some games only read a setting again
at the start of a round or of a game (SOME CHANGES NEED RESTART): RESTART GAME saves and
restarts.

### MEMORY EDITOR

| Screen | Controls |
|---|---|
| The page | UP/DOWN changes line (8 bytes), LEFT/RIGHT byte; B held + UP/DOWN changes page; A edits, C goes to an address, D freezes the byte or unfreezes it; START goes back |
| SET VALUE | UP/DOWN changes by 1, LEFT/RIGHT by $10; A writes, B cancels |
| GOTO ADDRESS | LEFT/RIGHT chooses the digit, UP/DOWN changes it; A confirms, B cancels |

The window covers the work RAM, $100000-$10FFFF, wrapping around. The BIOS area
($10F300-$10FFFF) is shown as READ ONLY: A and D do nothing there. The frozen bytes are listed at
the bottom (FROZEN); the engine writes them again every frame.

## The other screens

- **The boot screen**: SYSTEM, REGION, CLOCK, CARD, GAME NGH, then PRESS A BUTTON TO SKIP; a
  button skips the wait.
- **Board switch 8 ("Freeze") at ON at boot**: before the boot screen, DIP SWITCH 8 IS
  ON and SET IT OFF TO CONTINUE, until it is switched back; the SNK BIOS stays on a black screen.
  In a game, it freezes play without showing anything, like the SNK BIOS (`DECISIONS.md` §21).
- **SELECT on a multi-slot board**: SELECT P1 goes to the next game, SELECT P2 to the previous one;
  the conditions are in `io.s`.
- **SYSTEM CRASH**: the exception or its possible causes, the registers and the game's NGH; START restarts.
- **Without a cartridge**: the machine opens HARDWARE TESTS instead of rebooting in a loop
  (`DECISIONS.md` §13).
