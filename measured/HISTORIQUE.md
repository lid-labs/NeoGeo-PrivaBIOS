# History of the matrices

One line per matrix run on our BIOS, **rejected trials included**: that is often where the real
path can be read. Each line points to its record when there is one. A trial whose lines are not
versioned says so, and cites the report its figure comes from.

Counting rule: a game counts if it **"plays", its `vifs_max` is not zero and its `controle` is
`ok`**. A black screen that still changes is not a game that runs (pitfall 5 of
`docs/BENCH.md`). The control clause has been written only since 2026-10-22 (header of
`2026-10-22-matrice-catalogue.tsv`): 117, 155 and 157 are counted without it; the headers of
2026-10-16 and 2026-10-19 remove irrmaze from them (substitution missing): 116, 154, 156. Not
recounted.

To be completed at each matrix, delivered or rejected.

## The starting point: the existing BIOSes

Campaign of 2026-10-10 (PR #1314), corpus of 17 games, automatic criterion of the time.
Record `2026-10-10-matrice-6bios.tsv`, reading in `docs/COMPATIBILITE.md`.

| BIOS | Out of 17 |
|---|---|
| SNK (witness) | 17 |
| UniBIOS 4.0 (witness) | 17 |
| NeoPen 0.1, 2015 binary | 17 |
| neogeo-bios | 15 |
| NeoPen rebuilt | 14 |
| nullbios 0.5 | 9 |

## Our BIOS, delivered

| Date | PR | Corpus | Count | What moves | Record |
|---|---|---|---|---|---|
| 2026-10-15 | #1355 | 17 | **6** | first count of layer 1; seven games freeze from frame 100 | `2026-10-15-matrice-couche1.tsv` |
| 2026-10-15 | #1357 | 17 | **11** | SYSTEM_INT1 exits through `rte`: joyjoy, mslug, ridhero, samsho2, ssideki4 | `2026-10-15-matrice-couche1-rte.tsv` |
| 2026-10-15 | #1358 | 17 | **13** | sound handshake and REG_CRTFIX: wjammers, trally | `2026-10-15-matrice-couche1-son.tsv` |
| 2026-10-15 | #1362 | 164 | **117** | full catalogue, image of #1358 (SNK 162, UniBIOS 162, nullbios 93) | `2026-10-15-matrice-catalogue.tsv` |
| 2026-10-16 | #1364 | 20 | **14** (13/17) | coins, START, deduction: magdrop2; the corpus goes to 20 | `2026-10-16-matrice-start-credit.tsv` |
| 2026-10-16 | #1365 | 20 | **15** (13/17) | Europe country code: flipshot | `2026-10-16-matrice-code-pays.tsv` |
| 2026-10-16 | #1366 | 20 | **15** (13/17) | FRAME_SKIP: neomrdo comes out of the black, stays frozen | `2026-10-16-matrice-frame-skip.tsv` |
| 2026-10-16 | #1367 | 20 | **16** (13/17) | FIX_CLEAR, LSP_1st: neomrdo; the family of stalls is closed | `2026-10-16-matrice-fix-clear.tsv` |
| 2026-10-16 | #1368 | 20 | **16** (13/17) | backup formatting: no gain, kof98 changes cause | `2026-10-16-matrice-format-backup.tsv` |
| 2026-10-16 | #1369 | 20 | **17** (14/17) | random table: svc | `2026-10-16-matrice-table-alea.tsv` |
| 2026-10-16 | #1370 | 20 | **19** (16/17) | request 0 at first boot: kof98, mslug3 | `2026-10-16-matrice-demande-0.tsv` |
| 2026-10-16 | #1371 | 19 | **19** | cartridge soft-DIPs, garou excluded (MAME crashes on it): no gain expected | `2026-10-16-matrice-soft-dip.tsv` |
| 2026-10-16 | — | 164 | **155** | full catalogue, image of #1371 (SNK 162, UniBIOS 162, nullbios 88): 39 gained, vliner lost (it also freezes under SNK) | `2026-10-16-matrice-catalogue.tsv` |
| 2026-10-17 | #1374 | 22 | **20** | forced start ("game start compulsion"): minasan; the corpus goes to 22 with b2b and minasan | `2026-10-17-matrice-depart-force.tsv` |
| 2026-10-17 | #1375 | 22 | **21** | MESS_OUT and the hand-over aligned on the vblank: b2b; garou remains | `2026-10-17-matrice-mess-out.tsv` |
| 2026-10-19 | — | 164 | **157** | full catalogue, image of #1375 (SNK 162, UniBIOS 162, nullbios 88): b2b and minasan gained, none lost; irrmaze counted without substitution, 156 without it | `2026-10-19-matrice-catalogue.tsv` |
| 2026-10-19 | #1377 | 22 | **21** | CARD without a card: no gain expected, fidelity of the service (8 calls equal to the reference) | `2026-10-19-matrice-card.tsv` |
| 2026-10-19 | #1378 | 22 | **21** | READ_CALENDAR: no gain expected, same clock accesses and same writes as the reference | `2026-10-19-matrice-read-calendar.tsv` |
| 2026-10-19 | #1379 | 22 | **21** | CARD with a card and CARD_ERROR: no gain expected (the matrix inserts no card); 13 provoked calls equal to the reference | `2026-10-19-matrice-card-avec-carte.tsv` |
| 2026-10-20 | — | 22 | **21** | boot screen (≈ 180 more frames at startup): no gain expected, no regression | `2026-10-20-matrice-ecran-boot.tsv` |
| 2026-10-20 | — | 22 | **21** | soft-DIP editor (TEST held at boot; the bench does not press it): no gain expected, sprixe column identical line by line | `2026-10-20-matrice-editeur-soft-dip.tsv` |
| 2026-10-20 | — | 22 | **21** | region on the fly: Europe identical line by line; Japan and USA 21/22 too, each against the SNK BIOS of its region (22/22) | `2026-10-20-matrice-par-region.tsv` |
| 2026-10-21 | — | 22 | **21** | crash screen: no game of the corpus reaches it; garou exits MAME during our boot screen, without a 68000 exception | `2026-10-21-matrice-ecran-plantage.tsv` |
| 2026-10-21 | — | 22 | **21** | self-tests (opened by TEST, the bench does not press it): sprixe column identical | `2026-10-21-matrice-autotests.tsv` |
| 2026-10-21 | — | 22 | **21** | layer 3 moved above the random table ($C04300): columns identical | `2026-10-21-matrice-zone-haute.tsv` |
| 2026-10-21 | — | 22 | **21** | in-game menu (hook in SYSTEM_IO): verdicts identical; lit pixels of neomrdo and svc move (cycles); flipshot repaired along the way (`io.s`) | `2026-10-21-matrice-menu-en-jeu.tsv` |
| 2026-10-21 | — | 22 | **21** | cheats (engine in SYSTEM_IO, inactive with nothing chosen): verdicts identical | `2026-10-21-matrice-cheats.tsv` |
| 2026-10-21 | — | 22 | **21** | soft-DIPs in the banked area: mslug finally receives its settings (3 lives); verdicts identical — the matrix did not see the defect | `2026-10-21-matrice-soft-dip-zone-banquee.tsv` |
| 2026-10-21 | — | 22 | **21** | jukebox (test screen, the bench does not open it): verdicts identical | `2026-10-21-matrice-jukebox.tsv` |
| 2026-10-22 | catalogue | 164 | **158** | full catalogue on main 433d86e9 (all of layer 3): 156 → 158 excluding the non-ok controls (161 by the written rule); aodk lost (address error, under diagnosis); several games counted "plays" do not start a game (captures) | `2026-10-22-matrice-catalogue.tsv` |
| 2026-10-22 | — | 22 | **21** | multi-slot batch 1 (detection, table per slot): 21 unchanged; garou no longer crashes (lit pixels 70804) but does not start a game, not counted | `2026-10-22-matrice-multi-slot-lot1.tsv` |
| 2026-10-22 | — | 22 | **21** | hardware hardening: verdicts equal, boot 2 frames longer | `2026-10-22-matrice-durcissement.tsv` |
| 2026-10-22 | — | 22 | **22** | refused starts (five proven causes): garou enters a game; trally finally starts (lit pixels 44526 → 71490); outside the corpus, aodk, shocktr2, sbp play, cyberlip and ncommand start | `2026-10-22-matrice-departs.tsv` |
| 2026-10-22 | catalogue | 164 | **161** | full catalogue on main 64b9d7e3 (#1406, image 738d507f…), without nullbios: 158 → 161, aodk, garou and shocktr2 gained, none lost; irrmaze the only non-ok control; dragonsh counted by the rule but stayed on the game's debug screen; garou and alpham2 show one more credit than under SNK | `2026-10-22-matrice-catalogue-soir.tsv` |
| 2026-10-22 | — | 22 | **22** | the coin that makes the credit goes through DEMO_END, PLAY TIME at boot: verdicts equal; svc −2.7% lit pixels (the coin during the demo returns the title one frame later, like the reference), hence the harness's new reference | `2026-10-22-piece-demo-end-matrice.tsv` |
| 2026-10-22 | — | 22 | **22** | joystick repeat, $10FD81 at START, order of CREDIT_CHECK: verdicts equal; svc +2.6% lit pixels, closer to the snk column (mean gap 2,571 → 344), hence the harness's new reference | `2026-10-22-repetition-et-start-matrice.tsv` |
| 2026-10-23 | — | 22 | **22** | FRAME_SKIP under INT1, the coin under INT1, code 2 with a credit: verdicts equal, under the tolerance; svc −1% (further from the snk column, but an INT1 lengthened by 4 `nop` without changing anything else already moves it: its game follows the number of INT1 cycles); harness reference unchanged | `2026-10-22-frame-skip-et-mode0-matrice.tsv` |
| 2026-10-23 | — | 22 | **22** | bookkeeping (PLAY TIME, $10FDB6-$10FDBD, held frame of DEMO_END): verdicts equal, three lit-pixel counts moved under the tolerance (svc and neomrdo closer to the snk column, garou a little further); harness reference unchanged | `2026-10-23-comptabilite-matrice.tsv` |
| 2026-10-23 | — | 22 | **22** | LEDs, REG_POUTPUT, $10FD80 and REG_SOUND at the hand-overs, held frames of code 3: verdicts equal, svc −1.96% and neomrdo under the tolerance (further from the snk column); a first trial put kof94 out at −2.22% (the wait after REG_SOUND extended to the demo), discarded; harness reference unchanged | `2026-10-23-led-et-remises-matrice.tsv` |
| 2026-10-23 | — | 22 | **22** | title after game over, SELECT through DEMO_END, held frames of codes 0 and 2: verdicts equal; svc, garou, lbowling and neomrdo move under the tolerance, all closer to the snk column (the boot demo starts three frames later); harness reference unchanged | `2026-10-23-titre-apres-game-over-matrice.tsv` |
| 2026-10-23 | catalogue | 164 | **161** | full catalogue on main 9789d1f4 (#1413, image ea0de49e…) then d95122a2 (#1414, image 528b7e9c…, the one handed over for the board trial), without nullbios: verdicts of the sprixe column identical between the two images, no game gained or lost; SNK 162, UniBIOS 162; not counted: irrmaze (control), mvstemp and vliner (frozen) | `2026-10-23-matrice-catalogue.tsv` |
| 2026-10-23 | catalogue | 164 | **161** | full catalogue on main 14b54bb1 (#1417, AES mode, image bc6560f5…, the one handed over for the board trial), MVS mode, without nullbios: no game gained or lost; kof97 stalls 100 frames, three lit-pixel counts move under the rule; SNK 162, UniBIOS 162; same not counted | `2026-10-23-matrice-catalogue-aes.tsv` |
| 2026-10-23 | catalogue | 164 | **161** | full catalogue on main 516016ce (#1419, CREDIT_CHECK in AES, image 6fc2d51b…, the one handed over for the board trial), MVS mode, without nullbios: no game gained or lost, verdicts equal; six lit-pixel counts move by less than 0.4%; SNK 162, UniBIOS 162 | `2026-10-23-matrice-catalogue-credit-aes.tsv` |
| 2026-10-24 | catalogue | 164 | **161** | full catalogue on image 70f73d53… (#1425, the one of main a8b3ffb8, handed over for the board trial, image no. 9), without nullbios: no game lost; ng_mv1f measured in addition, outside the 164 (plays); SNK 162, UniBIOS 162; not counted: irrmaze (control), mvstemp and vliner (frozen) | `2026-10-24-matrice-catalogue.tsv` |
| 2026-10-25 | catalogue | 164 | **161** | full catalogue on image c4cba5b2… (#1427, the one of main 13a837d1, handed over for the board trial, image no. 10), sprixe column only, without nullbios: no game lost against `2026-10-24-matrice-catalogue.tsv`; ng_mv1f outside the halves; not counted: irrmaze (control), mvstemp and vliner (frozen). Outputs not versioned | — |
| 2026-10-25 | catalogue | 164 | **161** | full catalogue on image cdaca6b7… (#1429, the one of main a3159605, handed over for the board trial, image no. 11), sprixe column only, without nullbios: no game lost against `2026-10-24-matrice-catalogue.tsv`; ng_mv1f outside the halves; not counted: irrmaze (control), mvstemp and vliner (frozen). Outputs not versioned | — |
| 2026-10-25 | catalogue | 164 | **161** | full catalogue on image e5b4ea94… (#1432, the one of main 4d26ffdc, handed over for the board trial, image no. 12), without nullbios: verdicts equal game by game to `2026-10-24-matrice-catalogue.tsv`; ng_mv1f outside the halves; not counted: irrmaze (control), mvstemp and vliner (frozen). Outputs not versioned | — |
| 2026-10-25 | catalogue | 164 | **161** | full catalogue on image 981cd2af… (#1439, the one of main e7179b01, handed over for the board trial, image no. 13), without nullbios: verdicts equal game by game to `2026-10-24-matrice-catalogue.tsv`; ng_mv1f outside the halves; not counted: irrmaze (control), mvstemp and vliner (frozen). Outputs not versioned | — |
| 2026-10-25 | catalogue | 164 | **161** | full catalogue on image 8f03e1de… (#1442, the one of main f8cb3e3f, handed over for the board trial, image no. 14), without nullbios: verdicts equal game by game to `2026-10-24-matrice-catalogue.tsv`; ng_mv1f outside the halves; not counted: irrmaze (control), mvstemp and vliner (frozen). Outputs not versioned | — |

## Rejected trials, 2026-10-16

The diagnosis of kof98, garou and mslug3 cost nine trial images before the cause. All start from
the image of #1368, and none was delivered as is.

| Trial | What it changes | Result | Source |
|---|---|---|---|
| jetable-sr | SR `$2000` written at the hand-over | kof98 no longer reboots but freezes | record `2026-10-16-kof98-diagnostic-remise.tsv` |
| jetable-tblseule | random table alone, on 1 game | kof98 gets past the draw, then reboots | same |
| jetable-tbl | table + SR `$2000` at the hand-over | **18/20**: kof98, garou, mslug3, svc play; flipshot and kof94 break | same, lines versioned |
| jetable4 | table + wait with IRQs open before the hand-over | 9/10 sensitive games: neomrdo freezes | same, lines versioned |
| vI (agent) | table + wait + coin guard | 7/10: kof98, garou, mslug3 red | agent's report, not versioned |
| vE' (agent) | vI + hand-over with IRQs open | 8/10: kof94 and flipshot red | same |
| vE'' (agent) | vI + open hand-over aligned on the vblank | 8/10: the same ones | same |
| vK (agent) | vI + `$80 \| mode` at the hand-over | 7/10: like vI | same |
| table alone | the random table, nothing else, on 6 games | 4/6, exactly vI's gain: the wait and the coin guard are removed | session report, not versioned |

Three hypotheses were refuted by causal test, without a matrix: setting the soft-DIPs, setting the
per-game backup area, changing the mode of the hand-over. The cause was elsewhere: request 0 is
called only at a game's first boot (#1370).

## Rejected trials, 2026-10-17

| Trial | What it changes | Result | Source |
|---|---|---|---|
| jetable-vbl | every hand-over waits for line `$1F0` then acknowledges the IRQs | 19/22, the same as #1371: b2b no longer makes an address error but stays black (MESS_OUT was missing; delivered with it) | `2026-10-17-matrice-remise-vblank.tsv` |
