# Commercial compatibility of Neo Geo BIOSes, measured

17 commercial games × 4 BIOSes = **68 runs**, MAME 0.286, no window, 3,500 frames each, coin and
start injected. Raw records: `../measured/2026-10-10-matrice.tsv`.
To replay: `../bench/matrice.sh`.

## The result

| BIOS | games that run | failures |
|---|---|---|
| SNK BIOS (`euro`) | **17 / 17** | — |
| UniBIOS 4.0 | **17 / 17** | — |
| NeoPen 0.1 | 14 in game, 3 stopped on a "press start" | to be determined |
| **nullbios 0.5** | **9 / 17** | **8** |

> Unpublished capture: a contact sheet showed three games of the matrix side by side under each of
> the four BIOSes.

## The eight nullbios failures, in two families

| Game | Year | Symptom | Lit pixels | Simulation speed |
|---|---|---|---|---|
| Art of Fighting | 1992 | frozen at character select from frame 300 | 67,795 | 2,898% |
| Metal Slug | 1996 | frozen on "LOAD? YES/NO" from frame 600 | 61,072 | 2,448% |
| Super Sidekicks 4 | 1996 | black screen | **0** | 2,269% |
| KOF '98 | 1998 | black screen | **0** | **56%** |
| Garou | 1999 | black screen | **0** | **61%** |
| Metal Slug 3 | 2000 | black screen | **0** | **54%** |
| KOF 2003 | 2003 | black screen | **0** | **54%** |
| SVC Chaos | 2003 | black screen | **0** | 2,821% |

The other 60 runs run at between 1,500 and 2,900%. A speed of ~55% signals a machine that is
racing — the hypothesis of a reset loop by the watchdog was not verified.

### Family 1 — the memory card, and it was predictable

> Unpublished capture: Art of Fighting under nullbios, frame by frame, up to the freeze described
> below.

Art of Fighting, frame by frame: title screen and `CREDIT 01` at frame 100, **"MEMORY CARD LOAD —
YES / NO"** at 200, character select at 300, then **the same picture up to 3,500**, timer stuck
at 08.

> Unpublished capture: three of the nullbios failures in detail, including Metal Slug's "LOAD?"
> screen.

Metal Slug follows the same path: title, "HOW TO PLAY", then **"LOAD? ▶YES / NO — PUSH A BUTTON"**
at frame 700, and nothing more — while the bench presses A every 300 frames.

These two are exactly the two games of the corpus that go through the memory card, and nullbios
returns `CARD` on a bare `rts`. **Both run under NeoPen**, which implements the call.

### Family 2 — six black screens, cause unknown

Zero lit pixels over the whole run. Three hypotheses were tested by writing the variables in place
of the BIOS, from the bench, and **all three are refuted**:

| Hypothesis | Injection | Result |
|---|---|---|
| `bios_frame_counter` never maintained (`$10FE88`) | counter incremented every frame | **no change** |
| memory card response missing (`$10FDC6`) | `0x80` ("no card") continuously | **no change** |
| slot check reading the calendar | BCD date at `$10FDD2`–`$10FDD8`, flag `$10FCEF`, then both | **no change** |

The injection was verified in each case — with the counter armed, the record does read 200, 400,
600, 800. These are therefore real refutations, not tests that did not run.

An apparent pattern also collapsed: the black screens **are not the post-1998 cohort**.
Super Sidekicks 4 is from 1996, and SVC Chaos (2003) is black at normal speed. The speed collapse
affects only four of the six.

**Next lead**: trace the 68000 during the freeze. MAME's debugger segfaults under
`-video none`; a window is needed.

## What the verdict does not say

The automatic criterion answers "is the picture still changing?". That is not enough, and two
counter-examples proved it during this campaign:

- **a picture can change and stay black** — KOF '98 passed the criterion while showing nothing
  for 58 seconds. Hence the "lit pixels" column, which settles it;
- **an attract screen moves** — NeoPen's 17/17 includes three games (Riding Hero, KOF '94,
  NAM-1975) stopped on a "push start" screen with credits displayed. Cause not established:
  the hypothesis of a start that does not reach the game was not verified.

## The four free BIOSes, measured together

Second campaign, **102 runs**: the same 17 games under six BIOSes. Raw records in
`../measured/2026-10-10-matrice-6bios.tsv`.

The two third-party images are built from their source by `../bench/tiers/construire.sh`, which
**pins the commits**. What was measured, spelled out, so that anyone can redo it:

| Image | Commit | sha256 of the image |
|---|---|---|
| `neogeo-bios` | `93c02a9b` (2026-01-02) | `94bce7938643627e…` |
| NeoPen rebuilt | `2b28ff0f` (2015-08-03) | `fd5e9d885b68032c…` |
| NeoPen, binary published in 2015 | — | `9c16c0c161503152…` |

The script replayed on 2026-10-10 on the measuring machine produced images **identical to the
byte** to those of this table. This reproducibility is not guaranteed over time: the commits are
pinned, but not the digest of the `ubuntu:24.04` image nor the versions of the `apt` packages.
And this document shows precisely that a different build chain changes NeoPen's result.

| BIOS | automatic criterion | in game, by eye | licence |
|---|---|---|---|
| SNK BIOS (witness) | 17 / 17 | — | proprietary |
| UniBIOS 4.0 (witness) | 17 / 17 | — | proprietary |
| **NeoPen 0.1, 2015 binary** | **17 / 17** | **~14 of 17** | **ISC** |
| **neogeo-bios** | 15 / 17 | **11 of 15 captured** | GPL-3.0 |
| NeoPen rebuilt from source | 14 / 17 | — | ISC |
| nullbios 0.5 | 9 / 17 | — | LGPL-3.0+ |

> Unpublished captures: two contact sheets showed the last picture of each of the 17 games, one
> under NeoPen 2015, the other under `neogeo-bios`; the "in game, by eye" column was judged on
> them.

**Three findings.** NeoPen's 2015 binary is the most compatible. `neogeo-bios` **crashes MAME** —
segfault, exit 139 — on `garou` and `svc`. And nullbios, which the first campaign had chosen as a
base, is last.

`neogeo-bios` runs Metal Slug, KOF '98, KOF 2003 and Super Sidekicks 4, that is, precisely the
games that nullbios leaves on a black screen.

**Three caveats, and they matter.**

The automatic criterion says "picture not black, still changing, no warning" — **not "playable"**.
Under NeoPen, three games stay on a "push start" with credits displayed: NAM-1975, Riding Hero and
KOF '94. NeoPen's `features.txt` actually announces it at the top of its tasks,
*"Properly use SYSTEM_RETURN, games freeze in their attract loop"*.

The five failures of `neogeo-bios` and of rebuilt NeoPen are **MAME crashes**, not BIOS verdicts.
Three games, two images, the same segfault: it is a pattern, but its cause — MAME bug, BIOS bug,
or interaction — is not established.

And **rebuilt NeoPen does worse than its own 2015 binary**: 14 against 17. Yet its source takes up
2.7 KiB more. Two possible explanations, not settled: the build chain differs (binutils 2.42 from
2026 against `m68k-elf-as` from 2015), or the code regressed after the release. To be redone with
the original chain before concluding anything.

## Scope, and what it is not

17 games out of a catalogue of 178. "Eight out of seventeen" does not mean that one commercial game
in two fails: it means that eight failed out of seventeen tried. The corpus was chosen for
properties — link cable, memory card, post-1998 games, non-SNK IP, the oldest of the catalogue —
and not to represent the real distribution.

Everything is measured **under MAME**, never on hardware. The lesson of wolfmvs applies here:
emulators can agree and both be wrong.
