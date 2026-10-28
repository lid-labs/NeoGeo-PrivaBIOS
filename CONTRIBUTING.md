# Contributing to Sprixe BIOS

Thank you for helping. Questions and ideas go to
[Discussions](https://github.com/lid-labs/sprixe-bios/discussions); bugs and compatibility reports go
to [Issues](https://github.com/lid-labs/sprixe-bios/issues), using the templates.

## Clean-room rules

Sprixe BIOS contains no code from SNK, UniBIOS or any game, and must stay that way
([`docs/METHOD.md`](docs/METHOD.md)).

You may observe a BIOS or a game while it runs: the picture, the sound, the RAM and the registers,
how many times each address is accessed, and the addresses and timing of accesses on the bus, as the
files in `measured/` do. You may use public documentation (the NeoGeo Development Wiki, MAME's
driver source as a hardware reference).

You must never, for the SNK BIOS, UniBIOS, any other third-party BIOS or a game:

- read, disassemble or decompile the code or the bytes of its ROM;
- step through its code in a debugger;
- copy its code or any byte of its ROM.

If you are unsure whether something you saw or used crosses this line, say so in the pull request
before writing code.

Never commit a ROM, a dump, a capture of a commercial game or a value read from a third-party ROM.

`bench/garde-publication.sh`, run by the CI, fails on machine paths, personal e-mail addresses,
Google Drive links, private ticket numbers in `src/`, `bench/` and `build/`, and tracked ROM files.

## Every function has a scene and a mutation

A change the player can see comes with:

1. **a scene** in `bench/parcours.sh` that judges it on what the player sees or hears, against a
   reference run, with its thresholds recorded in `measured/`;
2. **a mutation** in `bench/parcours-mutations.py` that breaks it on purpose, and the proof that the
   scene fails on it (`--eprouver`).

A scene that cannot fail proves nothing. If a behaviour differs on purpose from the original BIOS,
write the difference and its reason in `docs/DECISIONS.md`.

## Testing locally

The bench runs under MAME with **your own** ROM sets; this repository never provides any. See
[`docs/BENCH.md`](docs/BENCH.md). Before opening a pull request:

```bash
python3 -I bench/test_generer_contrats.py
./build/construire.sh src/c0 /tmp/sprixe-bios.sp1
bench/non-regression.sh "$ROMS" <work-dir>
```

The CI only builds the image, checks its SHA-256 and runs the generators' tests; it does not run
MAME. The full regression run is your responsibility, and the pull request says that it passed.

## Changelog

Add a line to `CHANGELOG.md` under `Unreleased` for any change a user can notice.

## Sign-off (DCO)

Commits must be signed off under the [Developer Certificate of Origin](https://developercertificate.org/):

```bash
git commit -s
```

The `Signed-off-by:` line certifies that you have the right to submit the change under the project's
licence, GPL-3.0-or-later.

## Language

Code comments and the technical notes in `docs/` are in French. Issues, pull requests and
discussions can be in English or French.
