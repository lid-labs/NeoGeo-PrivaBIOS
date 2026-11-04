# Decisions, and what would overturn them

Taken from 2026-10-10 on, at the end of the measurement campaign. Each decision carries **what
would overturn it**, so that it can be reopened without retracing the path. §1 to §3 and §28 state
the decision in force; the method is detailed in `docs/METHOD.md`.

## 0. The feature target: UniBIOS parity, no more, no less

**Decided.** The BIOS aims at what UniBIOS 4.0 offers, and stops there. A save state on a NeoSD
cartridge is a **wish**, not a commitment.

What "UniBIOS parity" covers, and where each piece already exists:

| Feature | Where it exists today |
|---|---|
| Region and mode at run time, persisted | NeoPen (`configmenu.s`) + neogeo-bios's backup RAM |
| Soft DIPs, hardware test, self-tests, checksum | neogeo-bios, which has the most complete ones |
| Memory card, calendar | neogeo-bios |
| In-game menu, exception handler, themes | NeoPen |
| **Cheats** | **to be written** |
| **Jukebox** | **to be written** |
| High scores and their resets | to be written |

No line of code is taken from them: since §1, this column bounds the scope and nothing more.

**Two of these features are missing from both bases, and only one is really costly.** The cheat
engine fits in a few hundred bytes — writing to memory from an overlay; it is the **per-game table,
identified by CRC**, that is endless. UniBIOS has twenty years of accumulation of it. The target is
therefore stated as "N games", never "the cheats".

**The jukebox is bounded by the hardware**: the 68000 does not talk to the YM2610 but to the Z80,
and the BIOS controls the sound only while its own Z80 ROM runs — so **outside games only**. That is
why UniBIOS has a jukebox and not an in-game sound monitor.

**What would overturn it**: nothing on the feature side. On the other hand, if the save state went
from wish to requirement, its lock would have to be lifted first — see "Still to be decided".

## 1. The base: zero, and a clean room

**Decided on 2026-10-11.** The BIOS is written **from scratch**. None of the free bases measured is
taken over:

| Base | Licence | Commercial games | What it brings |
|---|---|---|---|
| **NeoPen**, source rebuilt | **ISC** | **14 / 17** | region changed on the fly, menus, exceptions, themes |
| *(for the record: its 2015 binary)* | ISC | *17 / 17* | — |
| **neogeo-bios** | **GPL-3.0** | 15 / 17 | memory card, calendar, soft DIPs, self-tests, in C |
| nullbios 0.5 | LGPL-3.0+ | **9 / 17** | — |

**The method.** No code from SNK, UniBIOS or any game was copied or disassembled. The SNK BIOS was
**observed while it ran**: under MAME (picture, sound, RAM, read counts per address) and, early on,
through **bus traces in a co-simulation** (addresses, times and values of writes; reads carry no
value in them). The bench draws **contracts** from them (`specs/traces/`), bounded by §8. The code
is written by fresh **implementation agents**, whose only inputs are those contracts and public
documentation. The audit of 2026-10-10 read the sources of NeoPen and `neogeo-bios`: no one who read
them writes the BIOS. Game PCs, recorded under MAME, were used for diagnosis.

**What the method guarantees, and what it does not.** It bears on what is **given** to the agents,
because that is what can be controlled; it says nothing of what a model may have seen during its
training. It had one incident, logged in §28: four words of the SNK ROM recorded during an
investigation, then a value derived again by a fresh agent.

**The checkpoint held, on 2026-10-11.** Layer 0 — the boot handshake, which public documentation
does not cover — was written by an agent that had only the contract and public documentation;
99.99% of program-space accesses are served by the cartridge over the judging window, and the game
runs (`tasks.md`, C0).

**What would overturn it**: a part of the BIOS that could not be written without reading someone's
code.

## 2. The licence: GPL-3.0-or-later

**Decided on 2026-10-28.** See §28.

## 3. The code lives in a public repository

**Decided on 2026-10-28.** The BIOS, its bench, its contracts, its records and these notes are
published in their own repository, without the history of the private repository where they were
written. See §28.

## 4. Contributing upstream: lapsed, except for one report

**Lapsed with §1**: no base any more, so no fork, and nothing of our code to send upstream.

What remains, and is worth doing: reporting to `neogeo-bios` that its build fails at 96% without
`libc6-dev-m68k-cross`, missing from its README's requirements, and giving it the bench that
reproduces its failures. That is documentation and measurement, not code.

**The constraint not to miss**: writing code for them requires reading their source, and whoever
does so can no longer write ours (§1). The report does not require it.

**What would overturn it**: the failure of §1's check — layer 0 not writable from the trace alone.
Taking over a base would give this section its purpose back.

## 5. The attribution is engraved in the boot screen

**Decided.** At start-up the BIOS will show its name, its version and a URL that identifies it,
briefly and skippably. The user's choices, on 2026-10-20, open to revision: the name "ReBIOS", the
URL "sprixe.dev/rebios", about one second, skippable with any button; then, after the first video
("you can barely read it"), about three seconds with a reminder "PRESS A BUTTON TO SKIP". Written in
`src/c0/ecran.s`. Revised on 2026-10-28 with the name (§29): the screen says "SPRIXE BIOS" and
"sprixe.dev/bios"; on 2026-11-04 (§34), "PRIVABIOS" and "privabios.com".

**Why.** Whoever burns an image must know what they are running and where to find its sources; the
screen says so at every start-up.

**The font is the one in the motherboard's SFIX** (choice of 2026-10-20). The BIOS's text is shown
on the fix layer, whose tiles the LSPC reads only from an S ROM — at boot, the motherboard's SFIX: a
font stored in our image would not show. A font of our own would therefore need an SFIX of our own,
that is a second chip to replace, and under MAME an `sfix.sfix` that would also serve the other
BIOSes. We keep a single chip, like UniBIOS; the tile numbers of the standard SFIX are recorded from
the screen, without reading the ROM (`measured/2026-10-20-sfix-glyphes.tsv`). An SFIX of our own
remains possible later, as a separate edition: our BIOS cannot know which one is fitted, it would
take two builds.

What makes it costly, and it must be known before drawing: since §1 the screen is a **creation**,
and **the room for it is not a given**.

**The trade-off not to miss**: a boot screen costs time, and we want a fast start-up. Brief, and
skippable.

## 6. The name

"ReBIOS" was a working name (2026-10-20). On 2026-10-28, the name becomes "Sprixe BIOS": see §29;
on 2026-11-04, "PrivaBIOS": see §34.

## 7. The compatibility target is written in black and white

**Decided.** The BIOS's README will name the games it targets, and it will not be "the Neo Geo".

**Why.** NeoPen announced "compatibility with all games before adding features"; nullbios
**narrowed its target**, and its README says so.

What we have: a **differential oracle**. We do not need to know what `SYSTEM_IO` is supposed to do;
we need ours to make Metal Slug behave as SNK's does. That can be checked and automated.

**The limit not to forget**: a differential specification gives compatibility on the games we own,
not on the 161 others. The tax is reduced, not abolished.

## 8. What the generated contract is allowed to contain

Settled on 2026-10-11, after #1326 recorded a first contract and its review showed that the rule
written the day before — "the records carry only addresses" — bounded the wrong object: the clean
room of §1 rests on what the implementer **receives**, so on the contract, not on the bench's
records.

| In the contract | Why |
|---|---|
| The **addresses** read and written **outside the BIOS ROM** (`$C00000`-`$C1FFFF`), the **order** of accesses, the **counts** | Interface behaviour |
| The **written values** in RAM, registers and palette | Produced by execution, and necessary: without them, the implementer has nothing to reproduce the effect with |
| **Outside the contract**: the addresses **inside** the BIOS ROM, other than entry points, and the **data tables** it reads there | A sequence of words read from the ROM is an **SNK data table**, not a behaviour |

**The criterion cannot be automated as things stand.** The trace gives, per access, the address, the
value and the address space, not the 68000's registers: it does not say where a written value comes
from. And a table read PC-relative also comes out in program space, like an immediate. §8 sets the
boundary; deciding which side a value falls on remains a judgement to make on each call.

**Two things changed on 2026-10-11, and they move the boundary to the tool's side.**

A read has no observable value: the bench puts no data on the bus for a read — **0 non-zero line in
1,793,296 reads**, measured on four traces. A value read from the BIOS ROM therefore cannot enter a
contract **directly**.

**But that does not hold §8 by itself, and having written so was a mistake**: a value read then
pushed or copied comes out in the data of a write, which is observable. The read side closes one
door, not the family.

On the write side, the generator no longer merely flags: as soon as a sequence is flagged, it
**withholds the values as a block** and keeps only the addresses, the contract saying why. The grain
is the **entry point**, not the call: a table flagged on only one of the seven calls to `$C0044A`
withholds the values of all seven. It is coarse both ways — the withholding goes beyond the table,
and beyond the call — and that is the intended direction: doubt removes the value instead of letting
it through. Judgement remains required in the other direction, since a table read PC-relative
escapes flagging.

**A value can carry an address that §8 forbids, and the per-sequence guard does not see it.** A
`jsr` internal to the BIOS pushes its return address: it is a RAM write whose value is a BIOS ROM
address, without any table having been read. The family is "any value derived from the PC", and it
was found in review after the first guard had been judged sufficient. A second guard therefore
withholds, site by site, the values that are or complete an address in `$C00000`-`$C1FFFF` —
measured, 161 pairs over the seven calls to `$C0044A`. The write's address stays in the contract,
its value does not.

What this teaches about §8: the boundary is not held by a list of cases, but by asking **where what
is written comes from**. A value is admissible only if nothing in its origin ties it to the ROM's
content.

**A third guard protects against a mistake the first version made**: a value constant over a window
is not a state. On an SNK dump, the first frames write the memory-test patterns, and the boot
contract announced `$5555` everywhere as "the state a layer must reproduce". The generator now
refuses to call a state an area whose sites **all** carry the same value: it is the signature of a
fill, and it says so.

**Who decides, and when**: the contract is reviewed call by call **before** being handed to the
implementation agents, and §8 is the criterion of that review. The rule of §1 therefore bears on
"what is given to them": what can be controlled here is the act of reviewing, not an automatic
filter.

For a copied table, the contract carries **the fact of the transfer** — "this call copies N words
from such area to such area" — and not the bytes. The implementer needs to know that a copy takes
place; the table, they produce themselves.

**Entry points are admitted** (`$C0044A`, `$C00450`, `$C004C2`, recorded by #1326): the BIOS's jump
table is public documentation. The **internal** addresses of its code are not, and do not get in.

**The survey of existing BIOSes is never handed to an implementation agent**
(`RELECTURE-CONTRATS.md`). It is not published, nor are the internal addresses of the SNK, UniBIOS
and neodebug images it carried.

**What this decision does not guarantee.** It bounds what is passed on, not what a model saw in
training — same reservation as in §1. And it is not legal advice: it is a rule of worksite hygiene.

## 9. A single title after game over: the reference's double title is not copied

**Decided on 2026-10-23**, by the user.

**What the reference does.** After a game over with one credit left, the SNK BIOS (`-bios euro`)
puts the title back at R+2, then restarts it a second time at R+15, through DEMO_END (measured under
MAME, aof: `measured/2026-10-23-titre-apres-game-over.tsv`, section 1).

**Why we do not copy it.** The "USER subroutine" page of the NeoGeo Development Wiki describes this
second call as a probable BIOS bug, fixed in a later revision ("to be confirmed", says the page),
and gives games $10FEC5 (BIOS_TITLE_MODE) to prevent it. A game that sets $10FEC5 to 1 expects a
single title; a game that leaves it at 0 tolerates both. A single title therefore suits both cases.

**What it costs.** An accepted departure from the reference: PLAYER_START comes at R+1811 instead of
R+1823 on this path (same record). The detail and the code are in `src/c0/c0.s`, header of code 3,
"UN SEUL TITRE".

## 10. SELECT is ignored during a SELECT in progress

**Decided on 2026-10-23**, by the user: a defect of the reference is fixed when we can, provided
the departure is documented.

**What the reference does.** SELECT makes the BIOS call the DEMO_END routine of the game being left.
b2b calls SYSTEM_IO from that routine; a second press of SELECT at that moment is taken, and
DEMO_END is called again while the first call has not finished, and that call is never resumed
(measured under MAME, b2b and puzzledp: `measured/2026-10-23-titre-apres-game-over.tsv`, section 6).

**Why we fix it.** The game's routine is re-entered halfway through, and the saving of its RAM to
backup RAM follows. On the measured run, the saved sum is the same with or without the second press;
nothing guarantees that another game copes as well.

**What ReBIOS does.** `_io_select` (`src/c0/io.s`) ignores SELECT as long as $10FD81 is $04 or $05,
values set before DEMO_END and returned to $02 before the hand-over. Measured
(`measured/2026-10-23-garde-select.tsv`): a single DEMO_END, a single slot change, the hand-over two
frames earlier than without the guard; a simple SELECT is unchanged, and a SELECT after the
hand-over is taken again. Not measured: SELECT P2, which goes through the same guard.

## 11. AES mode on an MVS board

**Decided on 2026-10-23**, by the user (D1 to D3 and D5); D4, D6 and D7 are the default options
proposed and not contested.

**What it is.** A MODE line (MVS / AES, D7) in the BIOS's editor, saved in backup RAM (`$D00217`,
`src/c0/reglages.s`), MVS by default. In AES, the BIOS writes $00 to BIOS_MVS_FLAG ($10FD82) and the
games build their console version themselves: PUSH START, CREDITS, option menus. No image for a real
console (D1). Measurements against SNK's AES BIOS (`aes -bios asia`, six games):
`measured/2026-10-23-mode-aes.tsv`; scenes: `measured/2026-10-23-parcours-aes.tsv`.

**The deliberate departures.**

1. **The mode is not the machine.** BIOS_MVS_FLAG tells games the mode; what depends on the hardware
   (the SELECT bits of the raw register, at the boot screen and in the in-game menu) reads
   REG_STATUS_B bit 7, which stays MVS.
2. **No request 0 at every power-on** (D5): scores stay in backup RAM, as in MVS. Changing mode
   frees a game's entry only if this boot has just registered it.
3. **The coin is ignored** (D2): the coin mechanisms are locked at boot (REG_SETCL1/2). START alone
   starts the game, on the frame of the press, as with SNK.
4. **$10FD81 ← 3 at START**, where SNK leaves it at 2: the end of a game comes back through code 3,
   the demo on the same slot, instead of moving to the next slot of a multi-slot board.
5. **Multi-slot kept** (D3). SELECT is taken only in the demo and leads to the demo of the next game,
   never to a title: it is the most restricted behaviour, since the AES has only one slot and
   provides no reference.
6. **Request 1** (the boot animation, games with $114 = 1) is given once per power-on, before the
   first demo. On return, the game is restored from backup RAM, which the AES does not have.
7. **No BIOS eyecatcher** (D6), **the soft-DIP editor is kept** (D4).
8. **The MODE line is not under REGION**, to keep the key paths of the records.
9. ASSUMED: START refused in mode 0 (requests 0 and 1), not measured on SNK.
10. **CREDIT_CHECK refuses no request in AES mode**, like SNK, which never writes
   $10FDB0-$10FDB3: the game reads its request again, and aof shows "PUSH START" for P2 instead of
   "INSERT COIN" (`measured/2026-10-23-aes-credit.tsv`). Remaining departure: the word $10FDB2
   (P3/P4) stays written at $0000, ASSUMED without effect, since aof and puzzledp set it themselves
   before each call. A refusal in MVS executes two more instructions.

**MVS mode is not byte-identical to `main` over the whole matrix**, and that is not required. The
MVS instructions executed in game are the same, but the BIOS's addresses move, and three games of
the matrix (garou, samsho2, ssideki4) diverge after 1800 to 3300 frames as soon as the layout
changes, even by a single word that is never executed: `measured/2026-10-23-disposition-mvs.tsv`.
Any PR that changes the size of the code has the same effect. The criterion therefore remains no
regression.

## 12. GAME SETTINGS and MEMORY EDITOR in the in-game menu

Two more screens in the in-game menu (`reglages-jeu.s`, `memoire.s`), on 2026-10-23. What differs
from the boot editor or from the previous state:

1. **GAME SETTINGS refuses a soft-DIP block in the banked area** (`$200000-$2FFFFF`), which the boot
   editor accepts: during a game, the game may have changed bank since boot.
2. **The values received are not made valid on entering** GAME SETTINGS: a value the player does not
   touch stays the one the game sees.
3. **A change is taken when the game reads the byte again.** The six games measured read soft-DIPs
   again during a game, but some bytes are read only in the demo, at the title or at request 0
   (`measured/2026-10-23-menu-en-jeu-complet.tsv`, section 1). The screen therefore says "SOME
   CHANGES NEED RESTART", and the RESTART GAME line saves then restarts through the watchdog.
4. **`CH_MAX` goes from 6 cheats to 4** (raised to 16 in §32, in a scrolling window): the menu frame
   (10 + N lines) must fit in the 392 saved cells. The current table has at most 3. The frame
   without cheats has two more lines than before.
5. **The memory editor shows `$100000-$10FFFF`, read-only from `$10F300`** (the BIOS's RAM): neither
   writing nor freezing. The freeze engine also refuses these addresses on its own.
6. **Four freezes at most**, rewritten at every call of SYSTEM_IO during a game, forgotten at boot,
   at RESTART GAME and at every slot change, like the cheats.
7. **The in-game hook costs 4 more cycles per call**: a single `tst.l` tests cheats and freezes. Two
   separate tests (26 cycles) took svc out of the matrix's tolerance, through timing and not through
   layout (same record, section 3).

The cheat search is not done: it needs a record of the game's RAM (62 KiB, or a bitmap of 7.8 KiB)
where the free area measured offers only about 1.8 KiB.

## 13. The cartridge is read only under REG_CRTFIX

On the hardware, the P-ROM does not answer under REG_BRDFIX (`ESSAI-MATERIEL.md`, report of
2026-10-24). MAME serves it in both states; `bench/bus-flottant.lua` models the hardware, and the
bench applies it at boot (stage 3f) and to the BIOS's screens (scenes `bf-*`).

1. **The boot soft-DIP editor reads a copy**: the block (name, values, labels) is copied to RAM under
   REG_CRTFIX before the switch, into `$10F464-$10FAFF`, the in-game menu's RAM, unused at boot and
   cleared on exit. 1,692 bytes, 138 labels; beyond that, the cell stays blank. No measured game
   comes close.
2. **Not fixed, for want of a possible scene**: an exception raised during the test screen or the
   crash screen reads its vector under REG_SWPROM and REG_BRDFIX, so on a floating bus. None
   happened in the runs.
3. **Without a cartridge, ReBIOS opens its self-tests in a loop**, instead of serving the empty slot
   0. The previous image handed over to it; the watchdog restarted the board every 192 frames, under
   MAME (MV-1, MV-2F, MV-4F without a cartridge). Like the reference, measured, $D00108 and REG_SLOT
   stay at the last slot scanned. The reference's test screens are not copied: these are ours
   (`measured/2026-10-24-machines-sans-cartouche.tsv`, scene `sans-cartouche`).

## 14. The memory card manager and SCORE RESET

Two more lines in the test screen, on 2026-10-24: MEMORY CARD (`gestion-carte.s`) and SCORE RESET
(`cal.s`, `reglages.s`).

1. **Both lines are placed before MODE**: MEMORY CARD at "up" five times, SCORE RESET at six. Near
   HARDWARE TESTS or the JUKEBOX, they would have moved the existing key paths ("up" ×1 to ×4). The
   editor's list starts at line 7 instead of 8, the help moves to lines 28 and 29.
2. **The manager never reads the cartridge**: a game's name comes from backup RAM (slot table
   `$D00124`, names at `$D002A0`). A save of a game never launched on this BIOS has no name.
3. **It goes through CARD, the games' interface**, to delete (`$04`) and format (`$00`), and gives it
   back as it was on exit (`$10FCF4`, `$10FD00-$10FD17`, `$10FDC4-$10FDD1`). A read-only scan,
   `_carte_releve`, is added to `card.s`. Its RAM, `$10F300-$10F3FF`, is cleared on exit.
4. **FAT 1 is shown as it is**, and repaired only by the next command that writes.
5. **SCORE RESET at OFF freezes the date READ_CALENDAR returns to games**, at the date it was set to
   OFF; the time stays true, the boot screen keeps the true date, no restart is requested. Of 32
   games that call it, 16 rewrite a table of their save after a jump of 38 days
   (`measured/2026-10-24-scores-date.tsv`). The jump is measured by faking the clock under MAME
   (`bench/horloge.lua`), not on a real board.
6. **No scores on the card**: our backup RAM already keeps them from one boot to the next, AES mode
   included (`measured/2026-10-24-scores-aes.tsv`). With UniBIOS, the feature makes up for the lack
   of backup RAM on a real console, and we have no console image (D1).

## 15. The cabinet settings: FREE PLAY, NO CONTINUE, DEMO SOUND

A sub-screen of the test screen, on 2026-10-25 (`reglages.s`, `io.s`, `dip.s`, `c0.s`).
Measurements: `measured/2026-10-25-free-play.tsv`; thresholds:
`measured/2026-10-25-parcours-borne.tsv`.

1. **A sub-screen, CABINET SETTINGS, at "up" seven times**, just before SCORE RESET: the "up" ×1 to
   ×6 paths do not move. Three more lines in the list would have made it overflow. The list now has
   22 entries for 21 lines: a cartridge with the 14 possible settings would write its last line over
   the help. The largest number recorded is 12, and nothing protects that case.
2. **The three settings fit in `$D0021D`**, bits 0 to 2 (FREE PLAY, NO CONTINUE, DEMO SOUND OFF),
   saved by the list's START without a restart. A copy in RAM, `$10FB20`, is read again at every
   START; its bit 7 says that CREDIT_CHECK refuses nothing (AES mode or FREE PLAY).
3. **The board's "Freeplay" switch stays ignored**, as before this batch: the setting is in the test
   screen. **Revised the same day (§17)**: this choice was wrong, the switch is honoured.
4. **In free play, a credit present is removed at START.** The SNK BIOS removes none.
5. **NO CONTINUE refuses START only to the player whose continue is shown** (`BIOS_PLAYER_MOD` at 2),
   free play included; joining a game or starting one is not affected.
6. **DEMO SOUND OFF sets `$D00046` to 1 during demos only**; the title that follows a coin and the
   game keep their sound. The SNK BIOS also cuts the title music.
7. **In AES mode, all three are inert and show MVS ONLY**: START already starts there without a
   credit, continues are not paid for there, and aof plays its demo sound there whatever `$D00046`
   is.
8. **The bench gives each run of `parcours.sh` its own MAME cfg folder.** MAME keeps switch settings
   in a per-game cfg: runs in free play had left the switch ON there for the following witness runs.
   The idea of free play ON by default under MAME 0.286 is refuted.

## 16. The cheat catalogue and CHEATS/DEBUG

On 2026-10-25 (`cheats.s`, `menu.s`, `reglages.s`, `dip.s`). One cheat per line:
`measured/2026-10-25-cheats-table.tsv`; search: `2026-10-25-cheats-recherche.tsv`; judging through
the menu: `bench/cheats-catalogue.sh`, `2026-10-25-cheats-catalogue.tsv`.

1. **The table goes from 3 to 35 games, 40 cheats**, all found black-box: RAM recorded by lua under
   MAME, cell forced, effect seen on screen. No third-party cheat database, no code read.
2. **One cheat per new game is judged through the BIOS's menu** (`cheats-catalogue.sh`, 32 of 32).
   kof95's INFINITE TIME is not among them: no witness run counts down without a KO in the window;
   its proof is the forcing by lua and the contact sheet of pictures.
3. **A time cheat that blocks the game's progress is discarded** (kof96, kof98). For the KOFs, we
   force the countdown between two seconds, not the seconds: forced, the round no longer starts.
4. **The value written is the one the game sets at the start**, under its default soft-DIPs; a game
   set to more lives is brought back to that value.
5. **CHEATS/DEBUG is the fourth line of CABINET SETTINGS**, bit 3 of `$D0021D`, ON by default (a
   block from before this setting reads it as zero, so ON). Active in both modes: the in-game menu
   exists in AES too.
6. **At OFF, the in-game menu loses its cheats and MEMORY EDITOR**, and the engine switches off,
   without writing, any cheat or freeze already active. GAME SETTINGS stays: these are the game's
   soft-DIPs, already settable in the test screen.
7. **The OFF test is only on the path of an active cheat, and the menu loop keeps its cycles**: two
   more tests there brought the RESTART GAME restart on ncombat forward by one frame (scene
   `gs-mmss`).

## 17. Board switches 1 and 7, and the gesture without a TEST button

On 2026-10-25, after image no. 12 (`io.s`, `dip.s`, `menu.s`). The tester, with a consolized MV-2F
without a TEST button or a coin mechanism, switch 7 ON, could neither start a game nor open a menu.
Measurements: `measured/2026-10-25-dip-free-play.tsv`; thresholds:
`measured/2026-10-25-parcours-dip-free-play.tsv`.

1. **Switch 7, "Free Play" (REG_DIPSW bit 6), counts as FREE PLAY in CABINET SETTINGS: either one
   suffices**, in MVS mode. Under MAME, the SNK BIOS and UniBIOS 4.0, on MV-2F and MV-6F, start the
   game at START without a coin (P2: both players) and read the switch again while running, in both
   directions. It is read only on the refusal paths (START refused, CREDIT_CHECK): an accepted START
   keeps its cycles.
2. **CABINET SETTINGS then shows FREE PLAY DIP, locked.** The saved setting is not touched and comes
   back when the switch goes back to OFF.
3. **Switch 1, "Setting Mode", opens the test screen at boot**, as with both reference BIOSes, which
   do not read it again while running.
4. **DELIBERATE DEPARTURE: START leaves the test screen even with switch 1 ON.** Under MAME, both
   reference BIOSes show "DIP-SW 1 OFF !!" and give control back only once the switch is set back to
   OFF. Confirmed on 2026-10-25 by the tester on an MV-2F with the original SP-S2 chip.
   ReBIOS shows "DIP SWITCH 1 IS ON" for 180 frames (or until the switch is flipped), then starts the
   game. Set back to OFF before START, no warning, like the SNK BIOS.
5. **P1's START + SELECT held open the test screen at boot, and the in-game menu during a game**, in
   addition to the TEST button. SELECT because an MVS game does not see it: held for one second
   during a game under the SNK BIOS, it changes no picture on 154 of the 157 games measured, and the
   three others differ only by one frame or vary from one run to another. A game played normally
   (aof, mslug, samsho4, ssideki) does not trigger the gesture; nor does START alone or SELECT alone.
   **Since 2026-10-27 (#1450), the gesture is refused if P1's A, B, C and D are all four held**, at
   boot as during a game (REG_P1CNT bits 4 to 7). With one, two or three of them held, it works as on
   its own. The source is hardware: report on image no. 14 (`ESSAI-MATERIEL.md`), the tester
   recorded in INPUT TEST that the BlueRetro adapter holds L/R, A, B, C, D, START and SELECT for
   about one second when it starts up, which opened the test screen at every boot and the in-game
   menu when it was plugged in during a game. The first rule, "A to D released", is discarded: a
   player who brushes A would see the gesture refused. It is a departure specific to ReBIOS, since
   the SNK BIOS does not have this gesture. Scenes: `geste-boot` and `geste-jeu`, runs of the
   adapter and of START + SELECT + A.
6. **The held-TEST path keeps its cycles to the cycle**; the gesture costs 30 cycles per SYSTEM_IO
   call when START is not held. Two more cycles on the TEST path brought the RESET of scene
   `gs-fois` forward by one frame.
7. **The `chrono_65` judge now keeps only pictures of at least two frames.** The picture of a change
   from 52 to 51, seen for one frame, was counted as "61-65" by the phase alone: scene `gs-defauts`
   failed by one frame with no change in the behaviour judged.
8. **Switches 2 to 6 and 8 are only displayed** (INPUT TEST, scene `tests-dip`): comparing them to
   the reference is a batch to come. **Done on 2026-10-27: §21.**

## 18. A generated grid at `$C02000-$C03FFF`, for the Super Sidekicks demo

On 2026-10-25 (`grille.s`, `build/bios.ld`). Measurements: `measured/2026-10-25-ssideki-demo.tsv`;
thresholds: `measured/2026-10-25-parcours-ssideki.tsv`.

1. **ssideki reads the BIOS ROM as a grid of 64 × 64 bytes in two planes**, the upper one at
   `$C03000`, the lower one at `$C02000`, without ever writing it. Our `$FF` fill froze its demo
   after the stadium intro, at the tester's as under MAME.
2. **The bytes are ours**: a 16-bit congruential generator draws them from 0 to 3 for the upper
   plane, from 1 to 63 for the lower plane. No reference byte is recorded or copied.
3. **These ranges are the only ones tried that play the demo and five sessions without blocking.**
   Lower plane at 0, or drawn from 1 to 254, or other upper planes: a game blocks, or the demo loses
   half of its pictures.
4. **The link holds the address**: `build/bios.ld` refuses the link if the code reaches `$C02000`.
   `card.s`, `mess.s` and `video.s` move to the high area. The `bsr.w _mess_out` call in `int1.s`
   stays relative: a `jsr`, two more cycles at every INT1, made `scores-gel` fail.
5. **The proof**: scene `demo-ssideki` (pictures and key-ons compared to the SNK witness run) and
   mutation `grille-haute-ff`, killed.
6. **`$C04000-$C041FF` carries a sine table** since 2026-10-28 (#1458, `sinus.s`, generated
   by `bench/generer-sinus.py`): T[i] = round(65536·|sin(2πi/256)|), and `$0001` for 1.0 (indices
   64 and 192). alpham2, preisle2 and lresort read it; under `$FF`, "up" also took alpham2's ship to
   the right. `$0000` freezes it, `$FFFF` shifts it by one pixel, `$0001` makes it equal to the SNK
   witness run to the pixel. kof98, ssideki and bstars2, which read the `$FF`, lose nothing there.
   Method: tables placed in our image, the game judged on screen (`measured/2026-10-28-sinus.tsv`).
   **An incident preceded it** (§28): the agent of the first investigation had recorded four words
   of the SNK ROM, which guided its choice of how to encode 1.0. That encoding was derived again by a
   fresh agent, without access to those records, by measuring the game on our image only. Proof:
   scenes `alpha-trajectoire` and `howto-preisle2`, mutations `sinus-ff` and `sinus-un-ffff`.
7. **The other readers, measured on 2026-10-27 and not fixed** (#1446,
   `measured/2026-10-27-lecteurs-rom-bios.tsv`). socbrawl blocks on a THROW IN, in the demo as during
   a game, because of the upper plane at 0..3 that ssideki's intro requires; no grid tried holds both
   games. The user's decision of 2026-10-27: the grid stays ssideki's, and socbrawl's blocking is a
   known defect. 3countb, bstars2 and fbfrenzy have no defect seen: their picture difference from
   the witness run does not follow the grid. The catalogue verdict sees none of these differences.

## 19. Soft-DIP labels in the JAPAN region

On 2026-10-27, after image no. 14 (#1449; `dip.s`, `reglages-jeu.s`). In the JAPAN region, the test
screen and GAME SETTINGS showed Super Sidekicks' labels blank: the Japanese block encodes them
outside ASCII, and `.Lecrire` replaced those bytes with a space. Measurements:
`measured/2026-10-27-intitules-japon.tsv`; scenes: `japon-intitules`, `gs-japon`, `gs-japon-garde`.

1. **The Japanese SNK BIOS writes each byte b of a label or a choice as tile $300 + b (top) and
   $400 + b (bottom)**, ASCII included; the game's name stays at $100/$200 + b (section 1, ssideki,
   `-bios japan`, fix layer reconstructed, no ROM byte read).
2. **Both banks of the board's font have the same glyph for 90 of the 95 ASCII bytes**: not for
   $5F, $60 nor $7C-$7E (section 2). ssideki's labels use $7C-$7E for a kanji.
3. **The cartridges' S ROM does not have these glyphs**: 0 identical tile out of 50 for ssideki,
   kof98, mslug, aof and samsho4 (section 3).
4. **Boot test screen, layout observed on the Japanese SNK BIOS, the user's decision of
   2026-10-27**: in the JAPAN region, if the block's labels carry a byte outside $20-$7E, the whole list goes to 8×16, two rows per entry,
   in a scrolling window of ten entries. A byte in $20-$5E or $61-$7B is written as $100/$200 + b,
   any other as $300/$400 + b. A block entirely in ASCII, or another region: the previous 8×8 list,
   unchanged. The CABINET SETTINGS sub-screen stays in 8×8.
5. **GAME SETTINGS during a game, DEPARTURE SPECIFIC TO REBIOS**: point 4 does not apply there. The
   fix layer stays on the cartridge's S ROM there (REG_BRDFIX would cut off the game's M1,
   `menu.s`), and point 3 says that the game's scenery would show there. In the JAPAN region, the
   labels of the settings and choices therefore come from the USA block (pointer $11A), if its
   structure is that of the Japanese block: bytes $10-$15 equal, and the number of choices (low
   nibble) of $16-$1F. Values, defaults and saving remain those of the Japanese block. USA block
   null, outside the fixed P-ROM or of a different structure: the Japanese labels, filtered
   as before (a non-ASCII byte as a space).
   Seen on screen on ssideki (borrowing) and bstars (guard) only: that the same structure means the
   same settings in the same order remains assumed elsewhere.
6. **The default (high nibble of $16-$1F) is masked** in the comparison: it does not change the place
   of a label, and Japan's defaults remain the ones used. Of the 161 games in the catalogue, 115
   have equal blocks, 25 differ only by their defaults (the guard lets them through), 19 have
   another structure and 2 a refused pointer (section 4). bstars, whose structure differs, judges the
   guard. Bytes $10-$15 are still compared by value, as the decision requires: 2020bb, ncommand,
   tpgolf and wjammers, which differ there only by the value of a time or a count, keep their
   filtered Japanese labels.
7. **The game's name does not come from the USA block.** GAME SETTINGS does not show it; the test
   screen keeps it in 8×8, as the SNK BIOS keeps it in ASCII.

## 20. The cartridge CRC32 and the debug dips

Written on 2026-10-25, re-applied on main on 2026-10-27 after #1452 and #1453 (#1444; `crc.s`,
`debug.s`, `tests.s`, `dip.s`, `cheats.s`, `c0.s`). Measurements: `measured/2026-10-25-crc-cartouche.tsv`
and `2026-10-25-debug-dips.tsv`; thresholds: `2026-10-25-parcours-crc-debug.tsv`.

1. **CARTRIDGE CRC is a line of HARDWARE TESTS, just before EXIT.** From WORK RAM, "down" four and
   five times still lead to INPUT TEST and COLOR BARS; CROSSHATCH moves to "up" three times,
   CARTRIDGE CRC is at two, EXIT at one.
2. **Two CRC32s, the fixed P-ROM and the banks, read under REG_CRTFIX** (§13), each word low byte
   first: the order of MAME's files. FIXED is `$000000-$0FFFFF`, halved as long as the upper half is
   the mirror of the lower one (ASSUMED: a 512 KiB chip seen twice on a board). BANKS follows the
   word at `$2FFFF0` (read in `neogeo.cpp`) up to the first bank already seen, judged on sixteen 4 KiB slices (REFUTED on
   2026-11-02 as a proof of a mirror: rotd has 7 banks, those of one parity differ in one 4 KiB
   block, and the screen shows 2); none if the window
   equals the fixed P-ROM, and nothing is then written to `$2FFFF0`. None either, since
   2026-10-29, if the window reads only one word, nothing written either: a real ssideki cartridge,
   without a bank chip, returns `$5700` everywhere there (`measured/2026-10-29-crc-ssideki-materiel.tsv`).
3. **The CRC is that of what the 68000 reads, not that of a file.** It equals the one
   `bench/crc-cartouche.py` computes from the zip on 138 of the 154 sets recorded
   (`measured/2026-11-02-crc-recensement.tsv`), and both CRCs of `hash/neogeo.xml` for mslug2 and
   kof97. Under MAME, a 512 KiB P-ROM is followed by zeros and gives a 1 MiB CRC. Of the 8 sets that
   differ, kof98, kof2002, matrim, samsho5, samsh5sp and sbp are changed by MAME at load, and
   fatfursp's bank reads differ from run to run. kof98's FIXED differs from its `p1` with no word
   on the screen: the 68000 cannot tell a clear P-ROM from a decrypted one, so there is nothing to
   test. The eighth, rotd, is a defect: see point 2's signature, above. Protected cartridges are
   point 12.
4. **The header word at `$10A` is not used**: it differs from the size of the P files on 44 of the
   119 sets recorded.
5. **DEBUG DIPS is the fifth line of CABINET SETTINGS**: it moves no path. A screen of sixteen bits,
   DIP 1 and DIP 2; the line shows the mask in hexadecimal. Not in the in-game menu: one more line
   there moved the records' paths and the cycles of its loop (§16 pt 7).
6. **An OR mask, not a value**, on the two bytes that the long at `$10E` points to (read in the
   wiki, "Debug DIPs"). These bytes are game data on 36 of the 128 games recorded. The mask is
   rewritten at every SYSTEM_IO by the cheat engine (bit 15 of `GL_MASQUE`), in the demo as during a
   game: kof94 clears `$100000` at every demo start.
7. **Never saved**: RAM only, forgotten at boot and at every slot change; `_sauver_jeu` removes it
   from the area while copying to backup RAM. A bit the game would set at the same place goes to
   zero in the save.
8. **Under CHEATS/DEBUG OFF, the line says OFF, does not open, and the mask is forgotten** on leaving
   the test screen.
9. **The effect is seen only on kof94** (DIP 1 bit 0: DEBUG OBJE, a sprite viewer); samsho2,
   tophuntr and sengoku2 show a tool under a byte at `$FF`. Elsewhere, the effect remains ASSUMED.
10. **The editor's frame goes to five sub-screen lines**, the 8×16 list of §19 kept: 602 bytes of
    stack under the self-tests (`tests.s`). The low code ends at `$C01C98`, under the guard of §18.
11. **Proof**: 7 scenes (`crc-*`, `bf-crc*`, `dd-*`) and 12 mutations. On the re-applied image
    `8c8caefa…`, the seven scenes and `geste-boot`, `japon-intitules`, `gs-fois`, `tests-grille`,
    `bf-tests`, `bo-ecran`, `gs-japon`, run alone, PASS. Full proof (NR, mutations, catalogue) at
    the final pass.
12. **SMA and PVC cartridges are recognised, and their banks are not read** (2026-10-31, `crc.s`;
    `measured/2026-10-31-crc-protegees.tsv`). Read in MAME 0.286: an SMA cartridge reads `$9A37` at
    `$2FE446` and banks through a scrambled word at an address of its own; a PVC cartridge has RAM
    at `$2FE000-$2FFFFF` and its bank registers inside it. So `$2FFFF0` does not select their banks,
    and the old BANKS figure described nothing. The screen says which protection, BANKS NOT READ,
    and FIXED IS NO FILE CRC. The FIXED figure stays: it is still what the 68000 reads, and two
    copies of a cartridge can be compared by it, but on all seven it differs from the one
    `bench/crc-cartouche.py` computes from the zip. Only a read at `$2FE446` happens on SMA. PVC is
    probed by two complementary words at `$2FE000`, put back; a floating bus cannot return both.
    That test runs even when the window reads a single word, as svc's does at reset. Nothing is
    written at `$2FFFF0`. ASSUMED: the same behaviour on real SMA and PVC boards, none tried yet;
    a run on one showing a normal BANKS line would reverse this. kof2003's screen stays black, as
    before (no font), though its state is right.
13. **The PVC test writes only on a PVC game's NGH** (2026-10-31, `crc.s`;
    `measured/2026-10-31-crc-sans-ecriture.tsv`). Point 12 first ran it on any cartridge whose window
    differs from the fixed P-ROM, so a real ssideki would take a write that point 2 refuses, and no one
    knows what a flash cart does with it: MAME shows nothing of that. The word at `$108` must now be
    0268, 0269 or 0271, the IDs of Metal Slug 5, SVC Chaos and KOF 2003 in the comments of MAME
    0.286's `neogeo.cpp`. In the catalogue, 3 sets of 164 carry one of them, those three. ASSUMED: a real
    cartridge carries the same number. So a normal cartridge takes no write at `$2FE000`. The bank
    words at `$2FFFF0` remain: any cartridge whose window is neither the fixed P-ROM nor a single
    word takes them, whether it has a bank chip or not, as nothing on this screen can tell. Read in
    the code, not played by a scene: one of these numbers on a cartridge that fails the RAM test
    stays normal. The price, measured under MAME with another word served at `$108`: no protection
    is named. svc and mslug5 say BANKS NONE and take no write in the window; kof2003 says
    BANKS 1 X 1024K, a figure that describes nothing, and takes three words at `$2FFFF0`. All three
    return to the game, its picture 900 frames later equal to that of a run with its own number.
    A hack keeping the number is still recognised. Ruled out: a test without a write, as a read
    cannot tell RAM from a floating bus or a bank. A read-only sign of PVC, or a hack seen in use,
    would reverse this.

## 21. Board switches 2 to 6 and 8

On 2026-10-27 (#1445; `io.s`, `c0.s`, `ecran.s`). The user's decisions of the same day, on the
record first made black-box: `measured/2026-10-27-dip-2-8.tsv`. Thresholds:
`measured/2026-10-27-parcours-dip-2-8.tsv`.

1. **Switch 8, "Freeze": as observed on the SNK BIOS and UniBIOS 4.0.** At ON, the game is suspended
   from the next call of SYSTEM_IO or SYSTEM_INT1, in the demo as during a game: the picture no
   longer moves, inputs no longer reach it, the watchdog is served, and the Z80 carries on (its
   driver still writes to the YM2610). Set back to OFF, the game resumes where it was, without a
   RESET. Under MAME, both references freeze 297 to 299 frames out of 299 and resume offset by the
   duration of the freeze (sections 2 and 3); ReBIOS likewise (scene `dip-gel`). ASSUMED: that the
   reference masks IRQs during the freeze, as we do; only that the picture no longer moves is
   measured.
2. **DELIBERATE DEPARTURE: at boot, a message.** Both references stop on a black screen after their
   memory test. ReBIOS stops at the same point of its boot, before its screen, but shows DIP SWITCH 8
   IS ON and SET IT OFF TO CONTINUE: a black screen is taken for a breakdown. Set back to OFF, the
   boot resumes (scene `dip-gel-boot`). Outside boot, the freeze goes through SYSTEM_IO and
   SYSTEM_INT1: in the BIOS's screens (test screen, in-game menu), neither ours nor the references'
   has been tried.
3. **Switch 3, "Mahjong Panel": as observed on the SNK BIOS.** At ON, BIOS_P1STATUS ($10FD94) is 3 and
   the panel is scanned at every call through REG_POUTPUT ($09, $12, $24): rows A-G, H-N and PON to
   REACH held in $10FD95, $10FD96 and $10FD97, their edges in $10FDA1, $10FDA2 and $10FDA3, without
   repeat. The mapping was measured key by key, under the three reference BIOSes, before writing the
   code (section 8): complete, the three identical. P2 stays an ordinary joystick. A joystick on this
   switch is read there in all three rows at once, as with SNK (section 4): the edge becomes the
   level, a direction held is seen at every frame.
4. **The panel at OFF, defect fixed.** Our image read no key of a panel, in any position (section
   5). With switch 3 at OFF, the reference reads it as a joystick, rows A-G and H-N merged: ReBIOS
   writes $1B to REG_POUTPUT before reading the joysticks, as it does (scene `dip-mj-off`). On a
   joystick, this output changes nothing. It costs one write per call.
5. **Switch 2, "VS Mode": as observed on UniBIOS and the Japanese SNK BIOS.** Copied into $10FEF8,
   BIOS_4P_REQUESTED ("BIOS RAM locations": $2, "dip 2 was on"). The European SNK BIOS does not do
   it. kizuna then shows a second CREDIT counter (scene `dip-4p`). **No 4-player adapter**:
   BIOS_4P_MODE and BIOS_4P_PLUGGED stay at 0.
6. **Switches 2 and 3 are read again at every hand-over**, boot included: the reference picks them
   up again at the coin, three frames later (sections 4 and 6; scenes `dip-mahjong`, `dip-4p`).
   ASSUMED: at the other hand-overs (end of demo, game over, SELECT), which nothing has measured.
7. **Switches 4, 5 and 6: nothing on the BIOS side.** Neither the SNK BIOS nor UniBIOS changes one
   frame of a game for them (section 1); they are only displayed in their test screens
   (COMMUNICATION, NETWORK ID; section 7). ridhero reads switch 6 itself, under the three BIOSes,
   ReBIOS included (992 game frames out of 1001 equal to the previous one against 836 under SNK;
   MAME: "runs in slow-mo"): it is the game, and our image serves it without doing anything.
8. **No switch names in INPUT TEST**: it keeps its eight indicators (§17 pt 8).
9. **The three switches act in AES mode too**: they are board switches, and ReBIOS's AES mode exists
   only on an MVS board (§11). ASSUMED without consequence: a game in AES mode does not read
   BIOS_4P_REQUESTED differently.
10. **The cost in cycles**: per call of SYSTEM_IO or SYSTEM_INT1, a test of switch 8, the write of
    $1B and a test of BIOS_P1STATUS, about 70 cycles. Run alone on the batch's image
    (66c240b7…), nineteen existing scenes sensitive to timing (boot, hand-overs, `gs-fois`,
    `gs-mmss`, `scores-gel`, `aes-texte`, `dip-*`, `geste-*`, `ms-select`…) stay PASS. Full proof
    (NR, mutations, catalogue) at the final pass.
11. **Proof**: 7 scenes (`dip-gel`, `dip-gel-off`, `dip-gel-boot`, `dip-mahjong`, `dip-mj-off`,
    `dip-4p`, `dip-4p-off`), each against a reference witness run, and 11 mutations written. The
    mahjong panel is added to `bench/son.lua` (`mjA` to `mjReach`, `mjStart`).

## 22. Per-game autofire, in the in-game menu

On 2026-10-27 (#1454; `autofire.s`, `io.s`, `menu.s`, `c0.s`). The user's decisions of the same
day: in the in-game menu, per game, kept in backup RAM; A, B, C and D separately; 15 shots/s by
default, 30 and 10 as options; the list of games documented. No known Neo Geo BIOS offers it.
Measurement it rests on: `measured/2026-10-27-autofire.tsv` (164 games); player's list:
`docs/AUTOFIRE.md`; thresholds: `measured/2026-10-27-parcours-autofire.tsv`.

1. **The turbo is in SYSTEM_IO, between reading the joystick and storing it in RAM.** The game sees
   it if it reads BIOS_P1CURRENT and the cells that follow, not if it reads REG_P1CNT itself.
   Measured with a prototype outside the repository, P1's A, at 15 shots/s: 89 games see it as a
   player tapping, 25 get it irregularly (they also read the register, or do not call SYSTEM_IO once
   per frame: the pattern advances one step per call), 35 do not see it, 15 are not measured. B, C,
   D and P2 are not measured.
2. **Constant cost**, turbo active or not, button held or not: neither branch nor Scc, two tables
   per phase (buttons released, next phase) prepared when the setting changes, ~112 cycles per
   joystick and per call. A few games diverge for a few cycles (measured during the prototype): a
   cost that varied with the setting would make a game with the setting a different game.
3. **The phase restarts from 0 as soon as no button of the setting is held**: the first press fires
   instantly. One phase per player; **P1 and P2 follow the same setting** (choice made alone: the
   game is set, not the player; one setting per player would double the screen).
4. **Mahjong panel (switch 3 ON): no turbo**, P2 included. The panel scan (`_io_mahjong`) does not
   go through the computation; its keys do not have A to D in the same sense (scene `af-mahjong`).
5. **An AUTOFIRE line between the cheats and GAME SETTINGS**, at "up" three times from RESUME: the
   records' "down", "down, down", "up" and "up, up" paths do not move. The frame keeps its ten lines
   (the empty line under MEMORY EDITOR leaves room for it). It stays under CHEATS/DEBUG OFF: it is
   neither a cheat nor a debugging tool. §20 pt 5 ruled out one more line for the debug dips: this
   one is requested in the in-game menu, and the place chosen avoids the two obstacles named, the
   paths and the loop's cycles.
6. **GAME SETTINGS opens with the previous cycles.** A first version of the selection took 20 more
   cycles when the menu opened: with those of the turbo, the RESTART GAME restart came one frame
   earlier (scenes `restart` and `gs-mmss`, RESET at 2393 and 2417 instead of 2394 and 2418), while
   each alone passed. The selection goes through `subq #2` and `blt` with the same cycles, and both
   scenes pass again.
7. **The sub-screen**: BUTTON A to D (OFF, ON), RATE (10/S, 15/S, 30/S); right, left, A as in
   GAME SETTINGS; START goes back. The change applies instantly; START saves it. No "TURBO" indicator
   during the game (choice made alone: the game's screen is not ours, the in-game menu touches it
   only while paused).
8. **In backup RAM, `$D001B0-$D0020F`**: the signature "AUTF", then 23 records of 4 bytes (NGH,
   setting, check), the most recent first; a game at the default setting has no record; beyond
   23 games, the least recently set loses its own. An area not documented by "Backup RAM", with no
   write by a game or the BIOS measured on 21 games, no read on 22; `$D00144-$D001A3`, where the
   reference stores slot dates, is left alone.
9. **The game is the NGH of the served slot's entry** (`$D00124`), written at boot from the header:
   the cheats' NGH, without reading the cartridge (§13). Loaded at every hand-over to the game,
   before waiting for line $1F0. **In RAM, `$10FB40-$10FB51`**, in the menu's area measured as free;
   the prototype read `$10FB40-$10FB41` back unchanged during the 158 sessions measured.
10. **Proof**: 4 scenes (`af-tir` against A tapped with the same pattern, `af-sauve` after a
    restart, `af-off`, `af-mahjong`) and 7 mutations written. On the batch's image (8a328fb6…), run
    alone with twenty-one existing scenes that the code touches (in-game menu, cheats, GAME SETTINGS,
    RESTART, SYSTEM_IO, hand-overs, switches), PASS. Full proof (NR, mutations, catalogue)
    at the final pass.

## 23. The guarantees on UniBIOS's defects

On 2026-10-27 (#1448; `dip.s`). Three scenes fix what ReBIOS does where UniBIOS has a known defect
(`ATTENTES.md` §2). Thresholds and measurements: `measured/2026-10-27-parcours-garanties.tsv`.

1. **The boot screen reads no cartridge graphics** (scene `boot-graphismes`). It uses only the fix
   layer under REG_BRDFIX, the board's font, and hides the sprites through LSP_1st before drawing.
   Measured under MAME: with aof's C ROMs and S ROM replaced by noise, and the VRAM and palettes
   filled with noise at power-on as on the hardware, none of frames 4 to 188 changes. UniBIOS 4.0's
   logo scrambles under the same conditions (155 frames out of 190): the scene's defect reproduces
   under MAME. Frames 2 and 3, before the BIOS's first palette, show the power-on noise and are not
   judged: a few frames of snow at start-up, which every BIOS has, and not a logo.
2. **Slot 2's sound without a cartridge in slot 1** (scene `ms-son-slot2`): on the MV-6F, slot 1 is
   served and the demo sounds at 1.21 of the SNK BIOS's RMS. Under MAME, UniBIOS 4.0 sounds there
   too (RMS 2,378): UniBIOS's defect on a multi-slot board is not reproduced, and the scene fixes our
   behaviour, nothing more. On the hardware: not measured. Resetting the Z80 outside the first slot
   has no mutation: under MAME, the Z80 deprived of its reset restarts and the demo sounds (RMS 2,969
   against 2,958), measured.
3. **The boot editor on an entry never initialised** (scene `dip-vierge`): a slot whose table
   carries another game, or that knows the game but whose soft-DIP block is arbitrary. The editor
   shows the cartridge's defaults and saves the block a new NVRAM would have, and the neighbouring
   blocks are not touched. Since pt 5, these two entries reach the editor already validated, and the
   final pass saw the mutations of `.Linutilises` and `.Lnormaliser` survive there: the scene judges
   them on mslug, whose block, in the banked area, escapes `_dip_valider` (run `vierge-m`), and both
   are caught there.
4. **Fixed: the unused settings.** The scene found that the editor saved as they were the bytes of
   the settings that the cartridge declares unused (a time $FFFF, a count $FF, a setting without
   choices). They now take, on entering the editor, the value that registration writes there
   (`.Linutilises`). No line shows them: the player sees nothing changed. GAME SETTINGS during a game
   is not touched (§12 pt 2).
5. **Fixed on the user's decision of 2026-10-27: a known entry with an arbitrary block.**
   Measured first: without going through the editor, the block was served as it was to the game,
   and aof's game changed entirely at frame 3000 (Japanese text, timer at 98), whereas an NVRAM with
   the same history without these bytes was equal to it to the pixel. `_relire_dip` (`c0.s`) now
   calls `_dip_valider` (`dip.s`): the editor's rules, value by value — an unused setting takes what
   the cartridge declares, a value out of its bounds the cartridge's default, a valid value is not
   touched. Scene `dip-corrompue`: GAME_DIP and the 2,000 frames of the game equal to the witness
   run. Three choices made by the agent: the correction is per value and not per whole entry (like
   the editor); only GAME_DIP is corrected, the backup RAM block keeping its bytes until the
   editor's next START; a soft-DIP block in the banked area (mslug) is not validated, since the bank
   in place is certain only at first boot. The cost: a few hundred cycles at each reread (boot of a
   known slot, multi-slot rotation and selection), in a wait with IRQs masked; the scenes of those
   paths, run alone, stay PASS. Such an entry arises from backup RAM left by another BIOS, from a
   request 0 that does not come back under the SNK BIOS (kof98 ends its own with a reset), or from a
   worn battery.

## 24. The mahjong panel page in INPUT TEST

On 2026-10-27 (#1448; `tests.s`). The user's decision of the same day, on the record made black-box
(`measured/2026-10-27-attentes-reference.tsv`): the behaviour observed on the Japanese SNK BIOS and
UniBIOS 4.0; no 4-player page here. The scene judges states, without a threshold.

1. **Switch 3 ON when INPUT TEST opens: the MAHJONG PANEL page** replaces the joysticks' page: A to
   G, H to N, PON, CHI, KAN, RON, REACH, START, SELECT, each followed by 0 or 1 (held), then the
   COIN, SERVICE, TEST and DIP indicators of the ordinary page. P2 is not on it, as with both
   references. The switch is read only at opening, like them: flipped during the test, the page
   stays, and the `tests-dip` scenes keep their page.
2. **The panel is scanned like `_io_mahjong`** (§21 pt 3): REG_POUTPUT ← $09, $12, $24, one row at a
   time. The output stays at $24 on leaving; the game sets its own at its first SYSTEM_IO.
3. **The proof on a joystick** (scene `tests-mahjong`): a joystick is read in all three rows at once
   (§21 pt 3), A lights E, L and REACH, B F and M, up A, H and PON. The panel's key-by-key mapping is
   proved only by `dip-mahjong` (§21), whose scan the page reuses.
4. **OBSERVED, NOT FIXED: the BIOS's menus cannot be navigated with the panel.** On MAME's janshin
   machine, with switch 3 ON as OFF, the panel's A and B do not move the editor's line: the boot does
   not write REG_POUTPUT before its screens, and the panel answers only for a selected row. The
   Japanese SNK BIOS and UniBIOS 4.0 enter HARDWARE TEST with the panel's A, switch 3 ON. On a
   mahjong cabinet, the page is therefore reachable only with a joystick plugged in as P1. Fixing it
   requires choosing which panel keys drive the menus: a decision. **Lifted by §30.**

## 25. The JUKEBOX screen saver

On 2026-10-27 (#1448; `jukebox.s`). The user's decision of the same day: the behaviour observed on
UniBIOS 4.0, in its JUKEBOX; here in the JUKEBOX only, not on CROSSHATCH. Threshold: `measured/2026-10-27-parcours-garanties.tsv`.

1. **Measured on UniBIOS 4.0** (`measured/2026-10-27-attentes-reference.tsv`): in its JUKEBOX
   PLAYER, the screen goes entirely black ~7,220 frames after the last input, the music continues, a
   key brings it back; nothing like it over 31 min in its main menu, its TEST menu or its in-game
   menu.
2. **Here, 7,100 frames without input** (~2 min): entries 1 of palettes 1-4, the only colours of
   this screen, go to zero just after line $1F0 is passed. The Z80 is not touched.
3. **Any P1 input counts**, C and D included, which the jukebox does not use; an input held prevents
   the black screen.
4. **The wake-up frame does nothing else**: no code, no step, no exit. A key held afterwards no
   longer has an edge.
5. **REG_SHADOW is not used**: it darkens without switching off, and this screen already sets its
   palettes.
6. **Proof**: scene `jukebox-veille`, against a witness run that tapping C keeps lit: 71,680 black
   pixels out of 71,680 at frame 7800, the same RMS as the witness run, the code unchanged at
   wake-up then 21 → 22.

## 26. Copying a save in MEMORY CARD

On 2026-10-27 (#1448; `gestion-carte.s`). The user's decision of the same day: one save at a time,
through a RAM buffer, "CHANGE CARD AND PRESS A", a confirmation before overwriting; no COPY ALL.

1. **Measured on UniBIOS 4.0** (`measured/2026-10-27-attentes-reference.tsv`): COPY GAME DATA, A on a
   save, "DATA IS COPIED / CHANGE CARD AND PRESS A BUTTON", then on a card that already has it "GAME
   IS ALREADY ON THIS CARD / DO YOU WANT TO DELETE OLD DATA ?".
2. **C on a save** reads it through CARD $02 (blocks of its chain × 64 bytes), then "CHANGE CARD AND
   PRESS A B:NO". C was taken nowhere in this screen; A keeps DELETE, and B stays "no".
3. **A reads the card in place again before anything else**, then asks "OVERWRITE nnnn-ss?" if it
   already carries the same NGH and the same sub-save, otherwise writes through CARD $03. Measured
   under MAME: removed and put back between two frames, a card does not change REG_STATUS_B, and the
   search was done on the old card's list. Card missing or protected at A: the message, the wait
   continues. B or START cancel.
4. **The room in RAM.** The largest save on a 2 KiB card (the only geometry served, `card.s`) is 27
   blocks, 1,728 bytes. The manager's RAM has only 256 ($10F300-$10F3FF), and that of the test
   screen ($10F464-$10FAFF) holds the copy of the soft-DIP block from `dip.s`. The buffer is
   therefore the game's work RAM, $100000-$1006BF, whose 1,728 bytes are set aside in VRAM
   ($0000-$035F, the tile map of sprites 0 to 13, hidden since boot) before the read and given back
   after the write or the cancel. Measured: a pattern set at $100000 and $1006BE comes out intact.
   The WORK RAM self-tests, for their part, rewrite the game's RAM below $10F000 without giving it
   back (read in `tests.s`): not changed here.
5. **Cards larger than 2 KiB are not concerned**: REG_CRDBANK stays at 0 and CARD refuses any other
   geometry ($85).
6. **Proof**: scene `cm-copier`, the card changed by `bench/carte-echange.lua` (removed, then another
   inserted twenty frames later): copy to an empty card, overwrite confirmed, cancel; the source
   never written.

## 27. No menu colour setting

On 2026-10-27, the user's decision (#1448). UniBIOS 4.0 announces it in its notes, but no colour
setting was found in its screens under MAME (main menu, GENERAL BIOS SETTINGS, REGION SETUP, in-game
menu, TEST menu: `measured/2026-10-27-attentes-reference.tsv`), and no request from the scene cites
it (`ATTENTES.md` §3). Without a reference or a request, ReBIOS does not have it.

## 28. The licence: GPL-3.0-or-later, and the source published

**Decided on 2026-10-28.** Sprixe BIOS is published with its sources, under **GPL-3.0-or-later**.

**Why publish.** The clean room becomes verifiable by anyone, with sources, contracts and records to
back it; contributions become possible.

**Why the GPL-3.0.** A permissive licence (MIT, ISC) would let a third party take the code and close
it again; a non-commercial licence would no longer be open source. The GPL-3.0 lets everyone modify,
redistribute and burn to a chip, provided they supply the sources of what is distributed.

**The sine table incident, on 2026-10-28.** During the first investigation into the drift of
alpham2's ship (#1458), the agent in charge of the investigation recorded four words of the SNK BIOS
ROM (`$C04000`, `$C04080`, `$C04100`, `$C04180`). It deleted them, but they guided its choice of how
to encode 1.0. A fresh agent, without access to those records, derived that encoding again by
measuring the game on our image only: `$0001`, identical to the witness run to the pixel in eight
directions (`measured/2026-10-28-sinus.tsv`, §18 pt 6). That value, and only that one, is in the
code. The files of the first investigation are not published.

**What would overturn it**: the discovery of an element derived from third-party code that could not
be removed or rewritten. It would be removed, then rewritten in a clean room.

## 29. The name: Sprixe BIOS

**Decided on 2026-10-28 by the user. Replaces the working name of §6. Replaced by §34 on
2026-11-04.** The BIOS is called
**Sprixe BIOS**, in two words. The boot screen says "SPRIXE BIOS" and "sprixe.dev/bios" (§5).

**Why.**

- A free software project, `ReBIOS-Project/ReBIOS`, has already carried that name since 2026-10-16. It too
  is BIOS firmware: legacy boot on a UEFI PC. It predates our choice of
  2026-10-20.
- "ReBIOS" is descriptive, hence a weak trademark.
- "SprixeBIOS", in one word, is hard to pronounce.

**The trademark.** The one we aim for is **SPRIXE** alone; it is not registered to date.

**What does not change.** History keeps "ReBIOS": the dated entries of this file, of
`CHANGELOG.md` and of the register in `ESSAI-MATERIEL.md`, and the images already sent under that
name. The backup RAM signature (`REBIOS`, `src/c0/reglages.s`) is an internal format that is not
displayed: it stays, so that settings already saved on a board remain valid.

**What would overturn it**: prior rights on SPRIXE in these classes, found before filing.

## 30. The BIOS's menus with the mahjong panel

**Decided on 2026-10-28 by the user (#1455), on the black-box record of the same day**
(`measured/2026-10-28-panneau-menus-reference.tsv`). It lifts the "observed, not fixed" of §24 pt 4.
The Japanese SNK BIOS and UniBIOS 4.0 are driven identically there; we take over that behaviour.

1. **Switch 3 ON: the panel translated into a joystick.** A, B, C, D act as buttons A, B, C, D;
   E goes up, F goes down, G goes left, H right; START stays START. The other keys (I to N, PON
   to REACH) do nothing in the menus.
2. **Switch 3 OFF: the panel read as a joystick**, REG_POUTPUT at $1B, as in §21 pt 4:
   A/H up, B/I down, C/J left, D/K right, E/L button A, F/M button B, G/N button C. Button D
   has no key, with the references as here.
3. **The switch is read when the menu opens**, like the Japanese SNK BIOS; UniBIOS reads it at
   boot. Flipped with the menu open, the translation stays that of the opening, with both.
4. **Outside this batch**: the in-game menu opens with START + SELECT, and the panel has no SELECT;
   it stays inaccessible on a mahjong cabinet. What the references do during a game has not been
   measured.

## 31. A slow cartridge: the slot scan repeated up to frame 270

**Decided on 2026-10-28 in autonomous mode, to be confirmed by the user**, on the hardware report
of the same day (`ESSAI-MATERIEL.md`, image no. 15): the NeoSD Pro and the BackBit stopped on the
boot screen, GAME NGH 0000, an empty slot.

1. **The departure from the reference.** It scans the slots once, around frame 276
   (`measured/2026-10-24-slot-crtfix.tsv`). We scan them from boot, so that the boot screen shows
   the header of the served slot, and, as long as none is occupied, at every frame up to 270
   scans (`c0.s`, ATTENTE_CARTE). A cartridge found at the first scan waits for nothing.
2. **Why not a single scan at frame 276**: every boot would wait 4.5 s more, and all the timing on
   which the matrix and the scenes rest would move.
3. **The price**: without a cartridge, the boot screen comes about 4.5 s later (scene
   sans-cartouche, HARDWARE TESTS judged at frame 700 instead of 400).
4. **ASSUMED**: that a flash cart is silent during its first frames; measured only under MAME,
   where a cartridge silent for 30 frames (`bus-flottant.lua`, BF_ABSENTE) is found
   (`measured/2026-10-28-carte-lente.tsv`). **Not covered**: a slow flash cart next to a prompt
   cartridge, which the first scan finds without it.

## 32. Up to 16 cheats per game, in a scrolling window

**Decided on 2026-10-29 with the user**: enlarge the cheat catalogue without a ceiling of 4 per game,
still found under MAME, without a third-party database.

1. **16, no more**: one bit per cheat in CH_ETATS, which stays a word contiguous to GL_MASQUE. The
   hook thus keeps its single `tst.l` without cheat or freeze, whose cycles count (`cheats.s`).
2. **A window in the menu, not a sub-screen**: 4 cheat lines at most (3 since §33), which scroll behind the
   selection. The key paths stay those from before: cheat k at "down" k + 2 times, AUTOFIRE,
   GAME SETTINGS and MEMORY EDITOR at "up" 3, 2 and 1 times.
3. **The table at the end of the high area** (`build/bios.ld`, section `.cheats`): in the middle of
   the code, it pushed `_mess_out` out of reach of the `bsr.w` in `int1.s`.
4. **The record format does not change** (32 bytes). Measured on 2026-10-29: the high area ends
   at $C0B416, that is 84 KiB free, room for more than 2,000 records.

## 33. The card manager from the in-game menu, and COPY ALL

On 2026-10-31 (public issue 57; `menu.s`, `dip.s`, `tests.s`, `gestion-carte.s`). The choice of the menus was left
open by the ticket; points 2, 4, 5, 11 and 12 follow the user's review of the pull request, the same day.

1. **One way in more: RESTART TO CARD, in the in-game menu.** A player already reaches the test
   screen at every boot, so a boot gesture would add nothing; play is what had no way in.
2. **It restarts the machine: the game in progress is lost, and the label says so.** The manager needs
   the whole fix layer and, to copy, 1,920 bytes of RAM set aside in VRAM, $0000-$03BF; during a
   pause, neither is ours (MN_FIX holds 392 cells, and the VRAM is the game's). UniBIOS manages the
   card "in every mode" (`ATTENTES.md` §1), not read further: this is a **deliberate difference**.
   What would reverse it: a windowed manager and a buffer measured free during play.
3. **The way there is a mark in backup RAM**, $D001A8, which `dip.s` reads at boot and clears: the
   boot clears the RAM, the mark must outlive it. $D001A8-$D001AF is undocumented, and no write was
   measured there on 21 games (`reglages.s`, header); ASSUMED for the rest of the catalogue. Power cut between the mark and the boot: the manager
   opens once, nothing else. The opening goes through the test screen, which sets up what the manager
   expects; START returns to it.
4. **The line is at "up" four times**, just before AUTOFIRE, so no earlier key path moves. The frame
   does not grow, 28 × 14 being all that MN_FIX holds, and keeps its blank line under the help: it
   shows 3 cheats instead of 4, and the scroll of §32 does the rest.
5. **Not reached**: the title and the demo, where the in-game menu does not open: that would need a
   new gesture for a rarer need. The user accepted this, and the lost game of point 2. **The machine
   without a cartridge is reached**: the line of HARDWARE TESTS that says EXIT says MEMORY CARD there,
   since EXIT would only lead back to the same screen. No new gesture, and no line moves.
6. **COPY ALL is D, on any line**: no new line, so the paths of the list stay ("up" × 2 is FORMAT CARD).
   D was free; the help says it. On the mahjong panel, D is the panel's D key.
7. **The source is never written.** A rereads the card in place; its directory and FAT 1 equal to the
   kept ones: SAME CARD, nothing written. A card that really is another one with the same layout is
   refused too: the price of not comparing the data. The copy of one save (§26) keeps its behaviour:
   A on the source then OVERWRITE rewrites the same bytes.
8. **Nothing is written that cannot finish.** SAVE wants its blocks free before it frees the old chain
   (`card.s`, $03): the count follows that order, and a card too full says NOT ENOUGH BLOCKS before the
   first write. A single confirmation covers every overwritten save. A write error stops the
   copy where it is and shows CARD ERROR: the saves written so far stay.
9. **The room**: the buffer of §26 grows by 192 bytes, the kept directory and FAT, and its VRAM
   by 96 words, up to the tile map of sprite 14. A FAT with crossed chains adds up to more than 27
   blocks: CARD ERROR 83, nothing overflows.
10. **Proof**: scenes `cm-copier-tout`, `menu-carte`, `menu-carte-non` and `sans-cartouche-carte`,
    mutations `ct-*`, `mc-*`, `menu-sans-marge` and `sc-carte-inerte`
    (`measured/2026-10-31-parcours-copie-tout.tsv`).
11. **RESTART TO CARD asks first**: A or START turn the line into LOSE GAME? A:YES, A alone goes on,
    B, START, UP or DOWN give the line back. Unlike RESTART GAME, a player comes here to manage a
    card, and the line sits next to AUTOFIRE: a single A must not lose the game. What would
    reverse it: nothing measured, a choice of the user.
12. **Hidden under CHEATS/DEBUG OFF**: that setting keeps players out, and this line leads to FORMAT
    CARD. AUTOFIRE and GAME SETTINGS move up one line of the frame, so "down" × 2 is AUTOFIRE there,
    and "up" × 3 is RESTART GAME. The test screen keeps its MEMORY CARD line: it needs a gesture at boot.

## 34. The name: PrivaBIOS

**Decided on 2026-11-04 by the user. Replaces §29.** The BIOS is called **PrivaBIOS**, in one word,
from its author's pseudonym (privaloops). The boot screen says "PRIVABIOS" and "privabios.com"
(§5), the ABOUT screen "GITHUB.COM/LID-LABS/PRIVABIOS"; the release files are called
`privabios-<version>.rom` and `privabios-<version>-byteswapped.bin`.

**Why.**

- SPRIX Inc. holds SPRIX trademarks in class 9, which covers software and firmware
  (international marks 1767190, filed 2023-10-23, and 1914317, filed 2026-03-05; read on
  data.inpi.fr in November 2026). SPRIXE, one letter away, would likely meet an opposition: assumed,
  not checked by a lawyer.
- An invented word is distinctive. A descriptive one ("Big BIOS", "Grand BIOS") would be a weak
  trademark, for a BIOS, with no hold on others using the same words.
- On data.inpi.fr, on 2026-11-04: no PRIVABIOS mark. The closest is PRIVA NURO (Priva Holding
  B.V., classes 9 and 42), greenhouse automation; that it does not conflict is assumed, not
  checked by a lawyer. The domain `privabios.com` is held since the same day.

**The trademark.** PRIVABIOS is not filed: the user files it if the project finds its users.

**What does not change.** History keeps "Sprixe BIOS" and "ReBIOS": the dated entries, the
releases v0.1.0-beta.1 and beta.2 and their file names, the `sprixe` column of the bench's
matrices (an identifier that recorded results read), and the backup RAM signature `REBIOS` (§29).

**What would overturn it**: prior rights on PRIVABIOS, or on a close mark in class 9 or 42,
found before filing.

## Still to be decided

- **The save state lock**: is there a write path to a flash cart? No public document describes
  it, and it alone decides whether the feature is possible. The two other obstacles can be measured
  here — the capture time (~140 KiB readable, that is about four frames of freeze, to be estimated
  to the cycle) and the cost of the in-game hook.
- **The cause of MAME's segfaults** on `garou` and `svc`, the only result of the campaign that we
  cannot interpret.
- ~~**Arm the bench's watchdog.**~~ **Settled, and done on 2026-10-11** (task I3): the cosim bench
  (not published) keeps a countdown of 8 frames, reloaded at every write to `$300001` and decremented
  on the VSYNC edge; at zero, the reset pin is pulled. A BIOS that forgets to kick it is therefore
  reset instead of passing the bench. Demonstrated on both sides: the harness, which never kicks it,
  is reset at frames 8 and 16; layer 0, which does, records no reset over 20 frames. The memory card
  and the calendar **are** modelled, only the date being frozen.
