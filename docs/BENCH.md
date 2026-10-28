# The test bench

Everything here runs locally, under MAME, with **your own** ROM sets. This repository contains no ROM,
neither BIOS nor game, and never will. The scripts take paths as arguments; the examples below use
`$ROMS` for a folder of **non-merged** MAME sets.

The scripts' own documentation is in their headers (in French). This page is the map.

## Requirements

- MAME (results in `measured/` were taken with 0.286), `zip`, `python3`, Docker (for the build).
- A folder of non-merged sets, including `neogeo.zip`. The SNK and UniBIOS 4.0 columns use the BIOS
  options of your MAME `neogeo` set (`-bios euro`, `-bios unibios40`, …).
- The regression run needs, besides the 17 games of the reference matrix, kof98, ncombat, ng_mv1,
  wh2, mslug, mslug2, ssideki, bstars, kof94, ng_mv2f, janshin, kizuna, viewpoin, alpham2 and
  preisle2.

## What is in `bench/`

| Script | What it does |
|---|---|
| `matrice.sh` | Compatibility matrix: each game under each BIOS, no window. |
| `parcours.sh` | The player's path: the scenes, each judged on picture and sound against a reference run. |
| `parcours-mutations.py` | Mutations that break one visible function each; `--eprouver` proves each scene can fail. |
| `non-regression.sh` | Chains the stages below, PASS/FAIL per stage, exits non-zero at the first failure. |
| `test_generer_contrats.py` | Tests of the contract generator (synthetic traces, no MAME). |
| `generer-contrats.py` | Turns a bus trace from the co-simulator into contracts (`specs/traces/`). |
| `generer-sinus.py` | Generates `src/c0/sinus.s`; `--verifier` checks the versioned file. |
| `*.lua` | MAME jigs: each measures one behaviour (taps on reads and writes, frame hashes, inputs). |
| `tiers/construire.sh` | Builds the free third-party BIOSes (NeoPen, neogeo-bios) at pinned commits, for comparison. |

## Running

```bash
# The compatibility matrix on every zip of the folder (no nullbios column).
BIOS_SANS_NULLBIOS=1 bench/matrice.sh "$ROMS" /tmp/bios-work

# One game, pictures at several frames.
BIOS_SANS_NULLBIOS=1 BIOS_JEUX=aof BIOS_IMAGES=100,200,300,3500 bench/matrice.sh "$ROMS" /tmp/bios-work

# Regression: full, or a short subset.
bench/non-regression.sh "$ROMS" /tmp/bios-nr
bench/non-regression.sh --rapide "$ROMS" /tmp/bios-nr

# Prove that every scene can fail.
python3 -I -B bench/parcours-mutations.py --eprouver "$ROMS" /tmp/bios-mut
```

`matrice.sh` takes extra BIOSes to compare in `BIOS_VARIANTES` (`name=path`, space-separated), and
the nullbios column from `BIOS_NULLBIOS` (a zip containing `sp-s2.sp1`). Runs are deterministic: two
runs of the same configuration give identical output, except the speed column.

`non-regression.sh` stages: 0, the generator's tests; 1, the build; 2, the game matrix against
`measured/2026-10-22-repetition-et-start-matrice.tsv`; 3, six jigs, each against its recorded
result; 4 (full run only), `parcours.sh`. A deliberate change of behaviour needs a new recorded
result, not a looser threshold.

As of 28 October 2026: 158 scenes and 204 mutations, all caught.

Work directories, captures and MAME state are written under the work directory you pass, outside the
repository.

## Pitfalls, all paid for

1. **Game zips are non-merged**: each carries its own full copy of the BIOS set, and MAME looks in
   the game's zip **before** `neogeo.zip`. Replacing the BIOS in `neogeo.zip` alone does nothing — a
   BIOS made entirely of zeros once gave a run identical to the real one.
2. **`WRONG CHECKSUMS` in MAME's log proves the substitution is active.** Its absence means MAME
   found the original BIOS elsewhere. `matrice.sh` checks it on every run (column `controle`).
3. **Never write through a symbolic link.** An early version of the bench linked the user's ROMs, then
   opened those paths for writing, and truncated a set to 22 bytes. The scripts copy, and refuse to
   write through a link.
4. **A picture signature must cover every pixel.** Sampling one byte in 257 missed the digits of a
   timer and declared a game frozen while it was running.
5. **"The picture changes" does not mean "the game runs".** A game passed that test while staying
   black for 58 seconds. Always cross it with the count of lit pixels.
6. **Never press Start and Coin together**: on UniBIOS that opens its in-game menu, and the bench then
   measures the menu instead of the game.
7. **At boot, the SNK BIOS's work RAM shows its memory-test patterns** (`0x55`, `0xAA`, then a value
   derived from each address). Its variables mean something only from about frame 300.
8. **MAME keeps DIP switch settings in a per-game cfg.** Each scene run gets its own cfg folder;
   otherwise a free-play run leaves the switch on for the next reference run.

## The co-simulator

The contracts in `specs/traces/` come from bus traces of a co-simulation: a Verilator model of a
68000 core (FX68K) and of the Neo Geo video chip, running the SNK BIOS with a cartridge. That
co-simulator is not published in this repository. It is needed only to regenerate traces and
contracts; the generator's tests use synthetic traces, and the versioned contracts are its output.
Commands that mention `cosim.sh` in `docs/` and `measured/` refer to it.

## Rule of evidence

The notes in `docs/` and `measured/` distinguish what was **measured here**, what was **read in a
named source**, and what is **assumed**, and they record **refuted** hypotheses alongside results.
A claim without a source is a defect.
