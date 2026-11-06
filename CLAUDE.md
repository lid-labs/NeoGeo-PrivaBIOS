# CLAUDE.md

Guidance for AI coding agents working in this repository. Humans: see [`README.md`](README.md) and
[`CONTRIBUTING.md`](CONTRIBUTING.md), which this file summarises and never overrides.

## The project

PrivaBIOS is a free replacement BIOS for the Neo Geo MVS arcade board, written from scratch in
68000 assembly (`src/c0/*.s`, GNU `as` syntax, `|` starts a comment), GPL-3.0-or-later. It is tested
game by game under MAME, with Lua jigs and shell/Python drivers in `bench/`. The public repository is
`lid-labs/NeoGeo-PrivaBIOS` (`lid-labs/privabios` until 2026-11-06, still shown by the ABOUT screen
and redirected: never create a repository under that name again); it was first published as Sprixe
BIOS and developed under the working name ReBIOS, which still appear in dated notes, ReBIOS also in
the backup RAM signature.

## Absolute rules

1. **Clean room** ([`CONTRIBUTING.md`](CONTRIBUTING.md#clean-room-rules),
   [`docs/METHOD.md`](docs/METHOD.md)). Never read, disassemble, decompile, step through or copy the
   code or ROM bytes of the SNK BIOS, UniBIOS, another third-party BIOS or a game. Observing them
   running under MAME is allowed: picture, sound, RAM, registers, access counts, and watchpoints that
   tell which program counter writes a RAM cell. Never use a third-party cheat database (UniBIOS,
   MAME's `cheat.xml`, websites) for its addresses, values or code, except the MAME XML Cheats
   Collection through `bench/cheats-importer.py`; the titles of a list may be read to decide what to
   look for. If unsure whether something crosses the line, stop and ask.
2. **No ROM, dump, capture of a commercial game or value read from a third-party ROM** is ever
   committed. `bench/garde-publication.sh` (run by the CI) fails on tracked ROM files, machine
   paths, personal e-mail addresses and Google Drive links anywhere, and on private ticket numbers
   (`#NNNN`) in `src/`, `bench/` and `build/`. Keep local paths out of tracked files.
3. **Every change the player can see comes with a scene and a mutation**: a scene in
   `bench/parcours.sh` judged on picture or sound against a reference run, thresholds recorded in
   `measured/`, and a mutation in `bench/parcours-mutations.py` that the scene catches
   (`--eprouver`). A scene that cannot fail proves nothing.
4. **A deliberate change of behaviour gets a new recorded result, never a looser threshold.**
5. **A deliberate difference from the original BIOS** is written, with its reason and what would
   reverse it, in [`docs/DECISIONS.md`](docs/DECISIONS.md).
6. **Rule of evidence**: notes distinguish what was *measured here*, *read in a named source* or
   *assumed*, and keep refuted hypotheses. A claim without a source is a defect.

## Commands

```bash
# Build (Docker plus python3 on the host; amd64 emulation on Apple Silicon).
./build/construire.sh src/c0 privabios.sp1

# The image must match build/expected-sha256.txt. A source change that changes the image
# updates that file in the same commit.
shasum -a 256 privabios.sp1; cat build/expected-sha256.txt

# Generator tests and the sine table check (no MAME, also run by the CI).
python3 -I bench/test_generer_contrats.py
python3 -I -B bench/generer-sinus.py --verifier

# Regression under MAME, with your own non-merged ROM sets in $ROMS (full, or short subset).
bench/non-regression.sh "$ROMS" <work-dir>
bench/non-regression.sh --rapide "$ROMS" <work-dir>

# Prove that every scene can fail.
python3 -I -B bench/parcours-mutations.py --eprouver "$ROMS" <work-dir>
```

- The CI builds, checks the SHA-256, runs the generators' tests and `garde-publication.sh`. **It does
  not run MAME**: the full regression is run locally, and the pull request says it passed.
- MAME runs are deterministic, one core each, so running them in parallel changes no verdict.
  See [Speed](docs/BENCH.md#speed) for which scripts do so by default.
- Work directories go **outside the repository**. Python is run with `-I`.
- Each script documents its usage in its header.

## Bench pitfalls

Read [`docs/BENCH.md`](docs/BENCH.md#pitfalls-all-paid-for) before touching the bench. In short:
game zips are non-merged and MAME looks in them before `neogeo.zip`; `WRONG CHECKSUMS` in MAME's
log proves the BIOS substitution is active; never write through a symbolic link; a picture signature
covers every pixel; "the picture changes" is not "the game runs"; never press Start and Coin
together; the SNK BIOS's RAM means nothing before about frame 300; each run gets its own cfg folder.

## Where to look

| Question | File |
|---|---|
| How it was written and tested | [`docs/METHOD.md`](docs/METHOD.md) |
| Build, reproducibility, other images | [`docs/BUILD.md`](docs/BUILD.md) |
| The bench: scripts, speed, cache, pitfalls | [`docs/BENCH.md`](docs/BENCH.md) |
| Why each behaviour is what it is | [`docs/DECISIONS.md`](docs/DECISIONS.md) |
| Each menu screen and the key that leads to it | [`docs/MENUS.md`](docs/MENUS.md) |
| Which games autofire reaches | [`docs/AUTOFIRE.md`](docs/AUTOFIRE.md) |
| What was checked on the imported cheats | [`docs/CHEATS.md`](docs/CHEATS.md) |
| Runs on real hardware | [`docs/ESSAI-MATERIEL.md`](docs/ESSAI-MATERIEL.md) |
| What testers should try on real hardware | [`docs/TESTING.md`](docs/TESTING.md) |
| Game counts, matrix by matrix | [`measured/HISTORIQUE.md`](measured/HISTORIQUE.md) |
| Contracts drawn from the original BIOS | `specs/traces/`, generated by `bench/generer-contrats.py` |
| Releases | [`docs/RELEASE.md`](docs/RELEASE.md) |
| The website | [`docs/SITE.md`](docs/SITE.md), sources in `site/` |

Issue numbers (`#NNNN`) in `docs/` and `measured/` refer to the original private tracker, and paths
such as `packages/…` or `cosim.sh` to the private monorepo where the BIOS was first developed.

## Language

Write all new text in English: docs, code comments, commit messages, pull requests. Still in
French, on purpose: identifiers (labels, script names, options such as `--eprouver`), the dated
notes (`AUDIT-2026-10-21.md`, `ATTENTES.md`, `RELECTURE-CONTRATS.md`, `tasks.md`) and quotes of
their headings, the measurement records `measured/*.tsv`, and the runtime messages of the bench
and build scripts (messages, usage lines, output columns, which other scripts and recorded results
read) and of the assembler and linker (`.error` in `src/c0/cheats.s`, `ASSERT` in
`build/bios.ld`); a Python script that prints its docstring as usage prints it in English.
`specs/traces/` is generator output, in French too: never edit it by hand.

## Changes and commits

- `CHANGELOG.md`: one line under `## [Unreleased]` for any change a user can notice.
- Public figures (scenes, mutations, games, cheats) are repeated across `README.md` (badges and
  text), `docs/BENCH.md`, `docs/COMPARISON.md`, `site/index.html`, `site/guide/` and
  `CHANGELOG.md`: grep for the old figure and update every copy.
- Conventional commits (`feat(cheats): …`, `fix(bench): …`, `docs: …`), signed off for the DCO:
  `git commit -s`.
