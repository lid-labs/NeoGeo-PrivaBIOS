# Method

How Sprixe BIOS was written, and how it is tested. This page says what was done, including what
went wrong. The decisions behind it are in [`DECISIONS.md`](DECISIONS.md) (§1, §8, §28, in French).

## What was not done

No code from SNK, from UniBIOS or from any game was copied or disassembled, and no code or data
block from their ROMs is in this repository. The only values that come from cartridges are game
identifiers (NGH numbers) and the soft-DIP settings the BIOS itself copies to RAM.

## What was done

**1. The original BIOS was observed while it ran.**

- **Under MAME** (0.286), with Lua scripts in `bench/`: the picture (each frame hashed in full), the
  sound (`-wavwrite`), the RAM and registers the BIOS writes and their values, and how many times
  each address is read. Some scripts read the 68000 program counter (PC) to tell whether an access
  came from the BIOS or from the cartridge, and `bench/sonde.lua` samples it once per frame to find
  where a game is stuck.
- **Early on (from 11 October 2026, during the first days), through bus traces in a
  co-simulation**: the SNK BIOS ran on a Verilator simulation of a 68000 core (FX68K) and of the Neo
  Geo video chip, with a cartridge (`puzzledp` for the versioned traces). A trace records, for each bus access, its address, direction, address space and
  time, and the data of writes. Reads carry no data in these traces (0 non-zero value in 1,793,296
  reads, measured on four traces), so no byte of the ROM appears in them.

**2. Contracts were drawn from those observations.** `bench/generer-contrats.py` turns a trace into
a contract per BIOS entry point (`specs/traces/`). The contracts handed to the agents that wrote the
code name calls only by their entry point in the public jump table and withhold what could carry ROM
content: addresses inside the BIOS ROM other than entry points, data tables read from it, and any
written value derived from the program counter (for example a return address pushed on the stack).
Each contract was then reviewed by hand before use; what was handed over and what was withheld is
logged in [`RELECTURE-CONTRATS.md`](RELECTURE-CONTRATS.md). That rule bounds the contracts, not the
whole repository: the diagnostic records (`measured/`, `specs/traces/`) contain program counters and
data addresses of games and of the original BIOS, taken by observation and without the content of
its ROM.

**3. The code was written by agents that had, about the original, only those contracts and
observations**, plus public documentation: the NeoGeo Development Wiki, and MAME's driver source as a
hardware reference. Each layer went to a fresh agent.

We browsed the public source of the other free Neo Geo BIOS projects (NeoPen, nullbios,
neogeo-bios) to survey the state of the art. None of that code was used: the agents that wrote
Sprixe BIOS received only the generated contracts and public documentation.

**4. Game program counters were used for diagnosis.** When a game hung, rebooted or refused to
start, its PC told where it was waiting; the cause was then confirmed by forcing a value on our image
and watching the game. These PCs are kept in `measured/`. What the game's code does at those
addresses is described as behaviour (what it reads, what it writes, how long it waits), not as
instructions.

**What this does not guarantee.** The method controls what the agents were given. It says nothing
about what a language model may have seen during its training.

## The sine table incident

Several games read a sine table from the BIOS ROM at `$C04000-$C041FF`. In Sprixe BIOS that area was
filled with `$FF`, and Alpha Mission II's ship drifted sideways.

During the first investigation (28 October 2026), the agent in charge read four words of the SNK
BIOS ROM, at `$C04000`, `$C04080`, `$C04100` and `$C04180`. It deleted them, but they had already
guided its choice of how to encode 1.0 in the table.

The encoding was then derived again by a fresh agent that had no access to those notes, by measuring
the game on our own image only: tables placed in our image, the ship's movement compared on screen
with the SNK BIOS in eight directions. `$0000` freezes the ship, `$FFFF` shifts it by one pixel,
`$0001` matches the SNK BIOS to the pixel ([`measured/2026-10-28-sinus.tsv`](../measured/2026-10-28-sinus.tsv)).
That value, and only that one, is in the code (`bench/generer-sinus.py`, `src/c0/sinus.s`). The
notes of the first investigation are not published.

## The bench

The bench runs under MAME with your own ROM sets; none are provided. See [`BENCH.md`](BENCH.md).

- **The catalogue** (`bench/matrice.sh`) boots every game of the set under Sprixe BIOS, the SNK BIOS
  and UniBIOS 4.0, and judges whether each one plays: the whole picture hashed per frame, crossed
  with the count of lit pixels, since a changing picture is not proof that a game runs.
- **Scenes** (`bench/parcours.sh`): one or more per BIOS function the player can see. A scene plays a
  short sequence (a coin, START, a menu, a held button) and compares the picture and the mixed sound
  with a reference run. 150 scenes as of 28 October 2026.
- **Mutations** (`bench/parcours-mutations.py`): each one breaks a single visible function of the BIOS
  on purpose, and the scene that judges it must fail. A scene that cannot fail proves nothing. 195
  mutations, all caught, on 28 October 2026.
- **Regression** (`bench/non-regression.sh`) chains the generator's tests, the build, the game matrix,
  the measuring scripts against their recorded results, and the scenes.

## Where Sprixe BIOS differs on purpose

When the SNK BIOS does something we consider a defect, Sprixe BIOS may do otherwise. Each such
difference is written down with its reason and its measurement in `DECISIONS.md` (for example §9,
§10, §17, §21).

## Limits

MAME is not the hardware. One real board, an MV-2F, has run Sprixe BIOS; it found defects MAME did
not show ([`ESSAI-MATERIEL.md`](ESSAI-MATERIEL.md)). Other boards and the AES console are untested.
