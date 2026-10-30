#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Thibaut Lion
# The player's path: each visible function of the BIOS played under MAME, and judged on what a
# player would see and hear (the screen image and the sound produced), not on the internal state
# of the BIOS. A game value read in RAM, or a bus event, only comes in as a complement. One
# PASS/FAIL verdict per scene; non-zero exit if a scene fails.
#
#   bench/parcours.sh [options] <dossier-roms> <dossier-travail>
#
#   --image <sp1>        the image to play (default: built from --sources)
#   --sources <dir>      sources to build (default: src/c0); a throwaway copy is accepted,
#                        that is how the player's path is put to the test by mutation
#                        (`bench/parcours-mutations.py`)
#   --scenes "<names>"   a subset of the scenes (default: all); only their runs run
#   --ref <tsv>          the record of the thresholds (default: measured/2026-10-23-parcours.tsv)
#   --ref-aes <tsv>      the one of the AES mode scenes (default: measured/2026-10-23-parcours-aes.tsv)
#   --ref-couv <tsv>     the one of the coverage scenes
#                        (default: measured/2026-10-23-parcours-couverture-scenes.tsv)
#   --ref-menu <tsv>     the one of the scenes of the full in-game menu, GAME SETTINGS and MEMORY EDITOR
#                        (default: measured/2026-10-23-menu-en-jeu-complet.tsv)
#   --ref-carte <tsv>    the one of the scenes of the memory card manager
#                        (default: measured/2026-10-24-parcours-carte.tsv)
#   --ref-borne <tsv>    the one of the scenes of the cabinet settings
#                        (default: measured/2026-10-25-parcours-borne.tsv)
#   --ref-cheats <tsv>   the one of the scenes of the cheat catalogue and of CHEATS/DEBUG
#                        (default: measured/2026-10-25-parcours-cheats.tsv)
#   --ref-dip <tsv>      the one of the board switches and of the gesture without a TEST button
#                        (default: measured/2026-10-25-parcours-dip-free-play.tsv)
#   --ref-ssideki <tsv>  the one of the demo-ssideki scene
#                        (default: measured/2026-10-25-parcours-ssideki.tsv)
#   --ref-crc <tsv>      the one of the scenes of the cartridge CRC32 and of the debug dips
#                        (default: measured/2026-10-25-parcours-crc-debug.tsv)
#   --ref-dip28 <tsv>    the one of board switches 2, 3 and 8
#                        (default: measured/2026-10-27-parcours-dip-2-8.tsv)
#   --ref-af <tsv>       the one of the autofire (default: measured/2026-10-27-parcours-autofire.tsv)
#   --ref-garanties <tsv> the one of the guarantees on UniBIOS defects
#                        (default: measured/2026-10-27-parcours-garanties.tsv)
#   --ref-sinus <tsv>    the one of the sine table (default: measured/2026-10-28-parcours-sinus.tsv)
#   --ref-panneau <tsv>  the one of the menus on the mahjong panel (default: measured/2026-10-28-parcours-panneau.tsv)
#   --jobs <n>           MAME runs in parallel (default: the number of cores minus two). A MAME
#                        occupies only one core; the runs are deterministic and each has its own
#                        directory, so the number of simultaneous runs changes no verdict
#   --hashpath <dir>     MAME's `hash/`, for the multi-slot software list
#   --cache <dir>        keeps the WITNESS runs (SNK BIOS, original ROMs) and reuses them when nothing
#                        they depend on has changed (see `lancer`). Without this option, nothing
#                        is kept or reused
#
# aof, puzzledp, b2b, kof98, ncombat and neogeo are needed in <roms-dir>, mslug for the scenes
# bf-banque, bf-crc-banque and dip-vierge, ng_mv1 for sans-cartouche, ng_mv2f for the dip-* and
# geste-* scenes, kizuna for dip-4p and dip-4p-off, janshin for dip-mahjong, dip-mj-off, af-mahjong
# and the pn-* scenes, viewpoin for af-tir, af-sauve and af-off, wh2 for scores-gel, mslug2 for
# cheats-vies and crc-banques, kof94 for dd-effet, dd-off and dd-connu, ssideki for demo-ssideki,
# alpham2 for alpha-trajectoire and preisle2 for howto-preisle2, non-merged (`docs/BENCH.md`,
# pitfall 1); kof98 and ncombat only run on the MV-6F, their romset read as is.
# The work directory receives the image, the substituted romsets (only sp-s2.sp1 replaced, like
# `matrice.sh`), one directory per run (son.txt, images, son.wav, mame.log, rc) and parcours.txt.
# For the reference column of the aes-* scenes, an aes.zip copied from neo-epo.bin and 000-lo.lo
# of neogeo.zip (MAME's `aes` set, -bios asia; no aes.zip in the ROMs directory).
#
# THE INSTRUMENTS. `son.lua` plays the inputs and records, per frame: the hash of the whole image
# and of chosen rectangles, the key-ons of the YM2610 (FM, ADPCM-A, ADPCM-B), the side that holds
# control at the end of the frame (a "BIOS" run of frames is a pause), the rectangle of the fix
# layer written by the BIOS; it writes the requested images. `-wavwrite` records the MIXED SOUND
# that MAME produces, `-sound none` or not: that is what is measured (RMS over a window).
# `jukebox.lua`, `autotests.lua` and `multislot.lua` play their screens. All runs of our image
# must exit MAME with 0 and carry "WRONG CHECKSUMS"; the SNK witness must not carry it.
#
# THE SCENES and their criterion. The numeric thresholds are in the record (--ref), threshold
# column, with the measurement of the image at hand of 2026-10-23 next to it; "cell" = 8 × 8
# pixels, the screen has 40 × 28 of them. Game aof unless stated otherwise.
#   boot-ecran    without input, the image of frame 100, the CLOCK line masked (it carries the
#                 host date), has the hash of the record; and the fix layer carries SPRIXE BIOS,
#                 sprixe.dev/bios, v0.1 BETA, SYSTEM MVS, REGION EUROPE, CARD NONE, GAME NGH 0044.
#   boot-saut     A at frame 60: the boot pause ends at the latest at frame "fin_max",
#                 against at least "fin_min" without A; at frame 100, fewer than "reste_max" of
#                 the lit pixels of the boot screen are still lit identically.
#   calendrier    the CLOCK line of the boot screen carries the host date at the time of the run,
#                 MM/DD/YY and the day.
#   carte         with a memory card (-memc), the image of frame 100 differs from the one without
#                 a card on the CARD line alone, by at least "cases_min" cells; text INSERTED.
#   demo-son      the demo without a coin, frames 600-3600: RMS of the sound and key-ons, relative
#                 to the same run under the SNK BIOS (-bios euro, original romset), at least
#                 "rms_ratio_min" and "keyon_ratio_min".
#   partie-credit a coin at frame 400: at frame 450, the image differs from the demo without a
#                 coin by at least "titre_min" cells (the title); a second coin at 420:
#                 the image differs from the one with one coin on the bottom text alone (y ≥ 152:
#                 "PUSH 1P OR 2P START BUTTON" and CREDITS 02), not on the logo.
#   partie-start  START at frame 500: at frame 1400, at least "cases_min" cells differ
#                 from the demo (the game, not the demo).
#   fin-demo      game lost without input, no more credit: the demo resumes; from frame
#                 3000 to 9000, at least "trames_min" frames are those of the demo without a coin,
#                 at a single offset (the game ends around frame 6960).
#   fin-titre     two coins, one game lost: at least "trames_min" frames after the
#                 game are images of the title (CREDIT 01) seen after the coin of the one-credit
#                 run, frames 405-499.
#   scores        puzzledp, a player score set in the game's RAM (1ST 1234560 SPX, like
#                 2026-10-22-sauvegarde-jeu-seul-puzzledp.tsv), MAME quit then relaunched on the
#                 same NVRAM; against the same path without the setting: the BEST PLAYERS screen of
#                 frame 4900 differs on the 1ST line alone (y 48-79), by at least "cases_min"
#                 cells.
#   dip-temps     the editor, ROUND TIME 60 → 65: in game, frame 3000, the image differs from
#                 the one of the editor quit without change in the timer alone
#                 (x 144-183, y 8-31); the fix layer of the editor carried "ROUND TIME 65".
#   dip-langue    the editor, LANGUAGE ENGLISH → SPANISH: 754 frames after the hand-over, the text
#                 of the story differs (y 152-215) by at least "cases_min" cells, and the image
#                 elsewhere by at most "hors_max".
#   region        the editor, REGION EUROPE → JAPAN: the machine restarts (RESET), the boot
#                 screen says JAPAN, and 754 frames after the hand-over the text of the story
#                 (y 128-215) differs from the European one by at least "cases_min" cells.
#   autotests     a defect injected in work RAM ($108000, bit 3, like
#                 2026-10-21-autotests.tsv): WORK RAM FAIL AT 00108000, the three others OK.
#                 The healthy run is stage 3c of `non-regression.sh`.
#   tests-sauvegarde  aof ALREADY REGISTERED (NVRAM of tests-sauv-set: first boot, save done), the
#                 self-tests without a defect from the TEST screen, START: at the hand-over ($10FD80 ← $82),
#                 the game's save area (pointer $10E, size $112) is equal to its block in backup RAM
#                 (2026-10-28-work-ram-restauree.tsv). On a fresh NVRAM, the autotests scene restored nothing
#                 to destroy: that is why it did not see the defect.
#   jukebox       codes 7F, 21, 25 ($07 before each): for each, the sound of the response
#                 window has an RMS of at least "rms_min", and at least "gain_min" times that
#                 of the control window (+1), and the chip counts more triggers.
#   menu-hud      TEST held in game: during the pause, outside the frame of the menu (the rectangle
#                 of the fix layer written by the BIOS), at most "hors_max" cells differ from
#                 the image before the frame; inside the frame, at least "cadre_min" of its cells.
#   menu-reprise  after RESUME, at least "egales_min" of the 1,500 frames are the image of the
#                 witness without menu, shifted by the duration of the pause.
#   menu-son      after RESUME, frames +30 to +1530 against the shifted witness: RMS and key-ons at
#                 least "rms_ratio_min" and "keyon_ratio_min".
#   cheats        INFINITE TIME and P1 INFINITE LIFE set to ON, RESUME: from +300 to +1500 after
#                 resuming, the digits of the timer (x 146-173, y 10-29) and the life bar of
#                 P1 (x 62-142, y 17-22) do not change, whereas they change in the witness over the
#                 same duration; as a complement, $108406 and $1092CD equal $60 (`cheats.s`) on at
#                 least "ram_min" of the 1,200 frames, read back at the end of the frame. Not
#                 before +300: the displayed timer loses one second (60 → 59) before
#                 freezing, measured at +181.
#   restart       RESTART GAME: a RESET, then at least "egales_min" of the 380 frames that
#                 follow are those of a power-on (the boot screen, then the game).
#   ms-demo       MV-6F, b2b and puzzledp, without input: the demo goes to slot 1, and the image
#                 60 frames after its hand-over is an image of the demo of puzzledp alone
#                 (frames +50 to +70 of its hand-over in demo).
#   ms-select     a coin, SELECT P1 at the title of b2b: hand-over to slot 1 in request 3, and
#                 60 frames later, the image differs from the title of puzzledp alone by "cases_max"
#                 cells at most (the countdown of the forced start).
#   ms-garde      two edges of SELECT, the second during the DEMO_END of b2b: a single
#                 DEMO_END read and a single REG_SLOT written (complement, the guard of DECISIONS §10),
#                 and the same image as under a single SELECT.
#   THE AES MODE (DECISIONS §11), thresholds in --ref-aes. Witness: SNK's AES BIOS, `aes -bios
#   asia -cart aof` (run aes-snk, START at 1000), and our image in MVS mode. The two BIOSes do not
#   hand over the demo at the same frame (476 against ~184, the reference playing its eyecatcher):
#   we compare at the best offset, like fin-demo.
#   aes-bascule   the editor, MODE MVS → AES ("up" four times, right), START: the editor
#                 showed "MODE AES", the machine restarts (RESET), the boot screen says SYSTEM
#                 AES; then, MAME relaunched on the same NVRAM without any input (run aes-demo),
#                 the boot screen of frame 100 still says AES, and it differs from that of a
#                 power-on in MVS on the SYSTEM line alone (the CLOCK line ignored),
#                 by at least "cases_min" cells.
#   aes-demo      the demo in AES mode: at least "snk_min" of its first 500 frames after the
#                 hand-over are images of the SNK AES witness (before its START), at a single
#                 offset; at most "mvs_max" are images of the demo of the MVS mode, at the
#                 best offset ("PUSH START BUTTON" instead of "INSERT COIN", no more
#                 "CREDIT 00").
#   aes-start     START at 1000 without a coin: at frame 1400, at least "cases_min" cells
#                 differ from the demo without START (the game starts, no credit asked for).
#   aes-menu      same run: from 1030 to 2400, at least "egales_min" frames are those of the SNK
#                 AES witness at the same instant after its START (the GAME LEVEL menu, what follows).
#   aes-piece     a coin at 1000 in AES mode: from 1000 to 2400, at least "egales_min" frames
#                 are those of the demo without a coin, and the key-ons from 1000 to 1300 differ by at
#                 most "keyon_max" (neither title nor COIN_SOUND).
#   aes-retour    from the AES NVRAM, the editor, MODE → MVS (left), START: the editor showed
#                 "MODE MVS", RESET, SYSTEM MVS; from 600 to 1099 (START without a coin at 1000
#                 included), at least "demo_min" frames are images of the MVS demo at a single
#                 offset; the coin at 1100 leads to the title: at least "titre_min"
#                 frames from 1100 to 1400 are images of the title of the partie run (405-499).
#   THE COVERAGE, on 2026-10-23: each function of the BIOS that no scene judged
#   (`measured/2026-10-23-parcours-couverture.tsv`, the inventory), thresholds in --ref-couv. The
#   witness is the SNK BIOS of the same region or of the same machine when there is one.
#   dip-defauts   ROUND TIME 60 → 65, then RESET TO DEFAULTS (up twice, A): the editor
#                 came back to 60, and frame 3000 is that of the editor quit without change.
#   dip-mmss      ncombat on the MV-6F, PLAY TIME 03:00 → 03:01 (an MM:SS time): at frames
#                 1300, 2000, 3000, only the TIME of the HUD changes (one second more).
#   dip-fois      puzzledp, CONTINUE INFINITE → WITHOUT by A (the maximum wraps to the minimum):
#                 the title after the lost game comes at least "avance_min" frames earlier
#                 (the CONTINUE screen does not take place).
#   region-europe, region-japon, region-usa   the demo without input of the region (Europe: fresh
#                 NVRAM; Japan, USA: set in the editor): at least "temoin_min" of the 1,000
#                 frames that follow the hand-over are those of the SNK BIOS of that region, at the
#                 best offset, at most "autre_max" those of another region.
#   autotests-palette, -vram, -backup   a defect injected like 2026-10-21-autotests.tsv (pal0,
#                 vram-bas, bram): the targeted test says FAIL AT <address>, the three others OK.
#   tests-entrees INPUT TEST: fourteen inputs (P1: directions, A-D, START; P2: A, START;
#                 coin 1, SERVICE, TEST) each light their cells, at most "cases_max",
#                 disjoint; START held 80 frames brings back the tests menu.
#   tests-barres  COLOR BARS: page 1, three red, green, blue bars of 15 increasing steps
#                 (pixels read on the image); A, page 2, three grey bars; START, the menu.
#   tests-grille  CROSSHATCH: the 1,120 cells are the grid (white at columns 0, 4 … 36, 39 and
#                 at rows 2, 6 … 26, 29, black elsewhere); START, the menu; EXIT, the TEST screen.
#   jukebox-pas   "up" (+1, $01-$03 skipped), right (+16), left (−16), down (−1): the screen
#                 shows 00, 07, 27, 17, 27, 21; START brings back the TEST screen, START starts the game.
#   jukebox-repete "up" held 60 frames: at least "crans_min" steps.
#   jukebox-stop  code 21 played, B: RMS after B at most "ratio_max" of that of the same run
#                 without B (jukebox-b0).
#   cheats-off    INFINITE TIME ON then OFF in the same pause, RESUME: the timer runs again.
#   partie-p2     two coins, START P2 at the title: at least "snk_min" of frames 500-2999 are
#                 those of the SNK BIOS at the same instant, at most "p1_max" those of a START P1.
#   partie-p2-joint a coin and START P2 in the middle of a game: P2 joins, as under SNK.
#   depart-force  a coin, nothing else: the game starts by itself "trames" ± "tolerance" frames
#                 after the title, then the frames are those of the SNK BIOS at the best offset.
#   piece-son     same run: RMS of the 56 frames of the title at least "rms_ratio_min" of the SNK BIOS
#                 (the sound of the coin, which COIN_SOUND makes the game play).
#   carte-sauve   aof, fresh card (-memc): game lost, MEMORY CARD SAVE → YES; MAME relaunched
#                 with the same card: MEMORY CARD LOAD, then the game resumed. At least
#                 "snk_min" frames equal to the SNK BIOS on its own card, at most "neuve_max"
#                 to a fresh card (CARD, CARD_ERROR which formats, the save, the read-back).
#   ms-select-p2  three cartridges, SELECT P2 at the title of b2b: the previous slot, aof, at its title.
#   ms-seule      a single cartridge on the MV-6F, SELECT at the title: nothing changes (deliberate
#                 departure).
#   aes-ms-select the AES mode on the MV-6F, SELECT in demo: slot 1, the demo of puzzledp, as
#                 under SNK's AES BIOS (`aes -cart puzzledp`), never its title.
#   aes-pause     the AES mode, SELECT in game (aof, MV-6F): the game's pause, "PAUSE", as
#                 under SNK's AES BIOS with the same SELECT.
#   aes-logo      the AES mode, kof98 ($114 = 1): request 1, its boot animation, as under
#                 SNK's AES BIOS.
#   aes-logo-fin  the AES mode, kof98 played and lost: after the game over, the demo, and request 1
#                 not again (once per power-on, decision D5).
#   aes-fin       the AES mode, STORY MODE lost: the demo (01/02) after the game over, that of
#                 SNK's AES BIOS after its own, not that of the MVS mode.
#   aes-texte     same game: P2's message at the top right, "PUSH START" as under
#                 SNK's AES BIOS: at least "trames_min" frames of the fight are an image of the
#                 witness, and each held state (≥ 10 frames of the same image of the area) is one,
#                 at most "etats_hors_max" not being one. A defect fixed on 2026-10-23:
#                 CREDIT_CHECK refused P2's request in AES mode, and aof displayed "INSERT
#                 COIN" (measured/2026-10-23-aes-credit.tsv).
#   THE COVERAGE, second batch (on 2026-10-23, same record --ref-couv):
#   carte-chercher CARD $01 provoked (`forcer.lua`, like `carte-diff.sh`) on the card that the
#                 SNK BIOS saved (run carte-sauve-snk), NGH $0044 then $0066: the interface
#                 after the call, which the game reads back, equal to that of the SNK BIOS within
#                 "octets_max", the card unchanged, and the mask different for the two NGHs.
#   carte-supprimer CARD $04 on the same card: the card equal to that of the SNK BIOS; aof relaunched
#                 on it, at least "snk_min" of frames 500-2499 equal to the SNK BIOS relaunched on
#                 its own, at most "sauve_max" to the card where the save still is.
#   carte-nom     CARD $06 (the name: 16 bytes of BIOS_CARD_START): the card equal to that of the
#                 SNK BIOS; then CARD $07 from the written card, into a buffer that nothing filled:
#                 the name read back and the response equal to the SNK BIOS, which reads back the
#                 written name.
#   tests-p2      INPUT TEST on the MV-6F (the machine that has SELECT): B, C, D, up, down, left,
#                 right of P2, SELECT P1 and P2 each light the cells of their element, and
#                 nothing else ("cases_hors_max").
#   tests-dip     same run: the eight board switches, set one by one by MAME's :DSW
#                 fields (J_DSW of `son.lua`), each light its digit and it alone.
#   dip-sans-donnees the editor on a fixture (a copy of aof's romset in which only the European
#                 pointer of the 68k header is refused, see below): SOFT DIP SETTINGS and NO
#                 SOFT DIP DATA, at most "lignes_max" lines (the region, CABINET SETTINGS, SCORE
#                 RESET, the card, the mode, the tests, the jukebox, the reset), none of ROUND TIME
#                 that the witness (run langue) shows; START hands control back to the game.
#   THE FULL IN-GAME MENU, on 2026-10-23 (GAME SETTINGS, MEMORY EDITOR, the freezes; thresholds in
#   --ref-menu). The menu opens at 2357 on aof's game (TEST 2337-2376); witness: the partie run, or
#   the boot editor set the same way (temps1, langue, temps-nc1, fois1). "R": the frame of the RESET
#   of RESTART GAME, 2418 on ncombat and 2417 on puzzledp, measured and required.
#   gs-compte     ROUND TIME 60 → 65 in game, RESUME: at the next round, at least "trames_min" frames
#                 show a timer that only ROUND TIME 65 shows (images of temps1 that the witness
#                 never has): the effect is taken without a relaunch.
#   gs-defauts    the same thing, then RESET TO DEFAULTS: ROUND TIME 60 on screen, and at most
#                 "trames_max" of those frames.
#   gs-choix      LANGUAGE → SPANISH, then the RESTART GAME line: a RESET, and 754 frames after the
#                 hand-over the text of the story differs from the English one by at least
#                 "cases_min" cells, and from the image of Spanish set at boot by at most
#                 "espagnol_max" (the setting stored in backup RAM, read back by the boot).
#   gs-mmss       ncombat (MV-6F), PLAY TIME 03:00 → 03:01, RESTART GAME: at R + 1300, 2000, 3000,
#                 the TIME of the HUD is that of temps-nc1 and not that of temps-nc0, at most
#                 "hors_max" cells of difference in all.
#   gs-fois       puzzledp, CONTINUE INFINITE → WITHOUT by A, RESTART GAME: the title after the lost
#                 game comes at least "avance_min" (dip-fois) frames earlier than with CONTINUE,
#                 within "ecart_max" of fois1.
#   gs-sans-donnees, gs-banque   GAME SETTINGS on the nosd fixture (pointer refused) and on the
#                 banque fixture (pointer at $00200100, which the boot editor accepts and GAME
#                 SETTINGS refuses in game): NO SOFT DIP DATA, at most "lignes_max" lines; RESUME
#                 hands control back.
#   me-ecran      the memory editor after GOTO 108400, and after one page: the first line carries
#                 the eight bytes that lua reads in RAM at the same frame, and the addresses go
#                 in steps of 8.
#   me-goto       GOTO 108400: the cursor and the first line; then GOTO with right, left, up:
#                 109465; GOTO abandoned by B: the cursor does not move.
#   me-octet, me-ligne, me-page   right six times (108406) then left (−1); down (+8) then up (−8);
#                 B held and down (+$40, the window too) then B held and up (−$40): the cursor
#                 displayed.
#   me-repete     "down" held 60 frames: at least "crans_min" lines.
#   me-poke       SET VALUE on $108406: $40, $41, $40 on screen, A writes; A, up, B abandons
#                 ($108406 stays $40). After RESUME, aof's HUD shows 39 (the next countdown step:
#                 it does not redraw on the write) on at least "trames_min" of the 600 frames, the
#                 witness on none at the same instant.
#   me-gel        two freezes ($108406, $1092CD): timer and P1's life frozen from +300 to +1500,
#                 the witness sees them change.
#   me-liste      same run: FROZEN 108406:60 1092CD:60 on screen.
#   me-degel      one freeze, RESUME; the menu reopened, D removes it: FROZEN NONE, the timer
#                 frozen between the two pauses, and changing after the second.
#   me-borne      GOTO 10FD84 (BIOS_GAME_DIP): READ ONLY; A does not open SET VALUE, D freezes
#                 nothing, $10FD84 unchanged.
#   THE FLOATING BUS, on 2026-10-24: on a real board, the cartridge's P-ROM only answers under
#   REG_CRTFIX (`docs/ESSAI-MATERIEL.md`, feedback of 2026-10-24). Each scene plays a screen of the
#   TEST screen twice, under `bus-flottant.lua` loaded by `son.lua` (J_FLOTTANT): under the model
#   of the hardware, then free (BF_LIBRE, the original MAME), the witness. Criterion: no floating
#   read, neither by the BIOS nor by the game, no reset, EACH frame of the interval at the hash of
#   the witness, and the labels legible on screen (words of the fix layer). No threshold:
#   everything is exact.
#   bf-editeur    aof: the editor, ROUND TIME 60 → 61 and LANGUAGE → SPANISH (two lines rewritten),
#                 START: ART OF FIGHTING, ROUND TIME, LANGUAGE SPANISH; the game takes control back.
#   bf-banque     mslug on the MV-6F, its block in the banked area ($2783D0): CONTINUE ON → OFF by
#                 A, START: METAL SLUG, DIFFICULTY, CONTINUE OFF.
#   bf-tests      aof: HARDWARE TESTS, CROSSHATCH, START, EXIT (the editor redrawn), START.
#   bf-jukebox    aof: JUKEBOX, a code, START (the editor redrawn), START.
#   sans-cartouche ng_mv1 without a cartridge, under the model, 1,500 frames without input: no
#                 reset, no floating read, each frame ended in the BIOS, HARDWARE TESTS at frames
#                 700 and 1400 (400 until 2026-10-28: detection now waits ~270 frames for a
#                 cartridge that is late, see flash-cart). Until 2026-10-24, the empty slot 0
#                 received control and the watchdog restarted the board every 192 frames
#                 (`c0.s`, `_sans_cartouche`). Mutation: cartouche-absente-servie.
#   flash-cart    aof, under the model, the cartridge silent for its first 30 frames (BF_ABSENTE),
#                 like a flash cart loading its menu: GAME NGH ..... 0044 on the boot screen, no
#                 reset, the game has control. Hardware feedback of 2026-10-28: NeoSD Pro and
#                 BackBit stopped on the boot screen, GAME NGH 0000 (`c0.s`, ATTENTE_CARTE).
#                 Mutation: carte-lente-ignoree.
#   THE MEMORY CARD MANAGER, on 2026-10-24 (`src/c0/gestion-carte.s`, thresholds in --ref-carte):
#   the TEST screen, "up" five times (MEMORY CARD, just before MODE), A. Judged on the decoded fix
#   layer and, when the card changes, on the card that MAME writes on exit (-memc), compared with
#   that of the SNK BIOS after the same CARD command (`forcer.lua`), then on what aof makes of it
#   relaunched on it. Two starting cards: the one the SNK BIOS saved (run carte-sauve-snk: aof's
#   save, one block), and a FIXTURE built here in the "Memory card" format (below): fourteen
#   saves, among them aof (NGH $0044, one block), an NGH that no registered game carries ($0202,
#   three chained blocks), twelve of one block, one free entry between two taken ones; 16 blocks
#   taken, 11 free.
#   cm-liste      the fixture: 0044 00 01 ART OF FIGHTING, 0202 01 03 without a name, then the
#                 twelve; thirteen lines visible; "down" fifteen times: the list scrolls, EXIT on
#                 the last visible line; START brings back the TEST screen (MEMORY CARD chosen),
#                 START the game.
#   cm-libres     same run: FREE BLOCKS 11.
#   cm-effacer    the SNK card: A, A (DELETE 0044-00?, then DELETED): aof's line disappears, FREE
#                 BLOCKS 27; the written card equal within "octets_max" to that of the SNK BIOS
#                 after CARD $04 (run cop-supp-snk); aof relaunched on it: at least "snk_min" of
#                 frames 500-2499 equal to the SNK BIOS relaunched on its own (cop-supp-relu-snk),
#                 at most "sauve_max" to the card where the save still is.
#   cm-annuler    same start: A, B: CANCELLED, aof's line still there, the written card equal to
#                 the byte to the starting one.
#   cm-formater   same start: FORMAT CARD, A, A: FORMATTED, FREE BLOCKS 27, no save left; the card
#                 equal within "octets_max" to that of the SNK BIOS after CARD $00 (run cop-fmt-snk).
#   cm-non-formatee a fresh card (the file that MAME creates): CARD NOT FORMATTED; A, A on FORMAT
#                 CARD: FORMATTED, FREE BLOCKS 27.
#   cm-sans-carte without a card: NO CARD; A on FORMAT CARD: NO CARD on the message line, nothing
#                 else; EXIT brings back the TEST screen.
#   cm-protegee   the fixture, the protection read by `carte-protegee.lua` (MAME has none): WRITE
#                 PROTECTED under the status; A on a save, then on FORMAT CARD: WRITE PROTECTED, and
#                 the written card equal to the byte to the fixture.
#   cm-insertion  the fixture, read "absent" until frame 399 (`carte-protegee.lua`), the screen
#                 opened at 320: NO CARD at 350, then the list and FREE BLOCKS 11 at 420, without a
#                 gesture. Then A on aof (DELETE 0044-00?), the card removed from 450 to 469 and put
#                 back: the confirmation abandoned (no message at 480), A asks DELETE again instead
#                 of erasing, B abandons; the written card equal to the fixture within
#                 "octets_max". Before 2026-10-25, the confirmation survived the card change and A
#                 erased the line.
#   bf-carte      the fixture, the screen opened, one line down, A then B, START, START, under
#                 `bus-flottant.lua` like the bf-* scenes: no floating read, each frame equal to the
#                 free witness, ART OF FIGHTING and FREE BLOCKS 11 legible: the name comes from the
#                 backup RAM, not from the cartridge.
#   aes-scores    the scores in AES mode (DECISIONS §11, D5: no request 0 at each power-on):
#                 puzzledp put in AES by the editor, the score of the scores scene set at 1500, MAME
#                 relaunched on the same NVRAM; against the same path without the setting, the BEST
#                 PLAYERS screen of frame 4900 differs on the 1ST line alone, by at least
#                 "cases_min" cells, and the boot screen says SYSTEM AES
#                 (measured/2026-10-24-scores-aes.tsv).
#   scores-gel    SCORE RESET (DECISIONS: the frozen date, `src/c0/cal.s`): wh2 on the MV-6F, the
#                 clock rendered by `horloge.lua` (MAME does not let its date be chosen). At first
#                 boot, on 2026-10-01, the editor: SCORE RESET left at ON (sg-a-on) or switched to
#                 OFF (sg-a-off, "up" six times, right), START; the initials SPX set at the top of
#                 BEST HEROES ($10E004, the game's save area), saved by the BIOS. Then MAME
#                 relaunched on each NVRAM: the same day (sg-b-meme), 38 days later (sg-b-saut,
#                 sg-b-gel). The witness: on at least "trames_min" frames, the BEST HEROES screen of
#                 the jump differs from that of the same day (wh2 has restored its factory table).
#                 The criterion: at OFF, each of these frames is that of the same day, none that of
#                 the jump; the CLOCK line of the boot screen nevertheless says 11/08/26, the real
#                 date (measured/2026-10-24-scores-date.tsv).
#   THE CABINET SETTINGS, on 2026-10-25 (`src/c0/reglages.s`, `io.s`, the CABINET SETTINGS
#   sub-screen of `dip.s`; thresholds in --ref-borne). The TEST screen, "up" seven times (CABINET
#   SETTINGS, just before SCORE RESET), A. The settings are set by a bo-set-* run (the editor, then
#   START), and judged on MAME relaunched on its NVRAM, against a bo-set-0 run that takes the same
#   path without changing anything. The witnesses of the SNK BIOS in free play carry J_DSW=1:40
#   (the board's "Free Play" switch, OFF by default, each run having its cfg); their inputs are
#   shifted by 567 frames, the gap from their hand-over in demo (751) to ours (184), checked by the
#   judge.
#   bo-ecran      the list: CABINET SETTINGS chosen after "up" seven times, just before SCORE RESET,
#                 followed by MEMORY CARD, MODE, HARDWARE TESTS, JUKEBOX, RESET TO DEFAULTS (the
#                 "up" paths one to six times unchanged); A: CABINET SETTINGS, three lines, FREE
#                 PLAY OFF, NO CONTINUE OFF, DEMO SOUND ON, START:BACK; right, down A, down right:
#                 ON, ON, OFF; START: the list, on CABINET SETTINGS; START: stored ($D0021D at 7,
#                 as a complement) and control to the game.
#   ab-ecran      the list: ABOUT chosen after "up" eight times, just before CABINET SETTINGS (the
#                 "up" paths one to seven times unchanged); A: the ABOUT screen, the name and the
#                 version, the copyright, the absence of warranty, the GPL version 3 or later, the
#                 address of the source, the hardware tester, START:BACK; START: the list, on
#                 ABOUT; START: control to the game.
#   bo-free-play  FREE PLAY ON, START without a coin at 1000: at least "snk_min" of frames
#                 1001-3099 are those of the SNK BIOS in free play at the same instant after its
#                 hand-over, the game; frame 1400, at least "cases_min" cells differ from the demo
#                 of bo-dm0; no credit. The demo before: at least "temoin_min" frames of the SNK
#                 demo in free play ("PUSH 1P OR 2P START BUTTON"), at most "autre_max" of the
#                 demo without setting.
#   bo-fp-p2      START P2 at 1000 in demo: both players start, as under the SNK BIOS in free play:
#                 at least "snk_min" frames equal at the same instant, at most "p1_max" to those of
#                 a START P1 (bo-fp).
#   bo-fp-joint   START P1 at 1000, START P2 at 2000 without a coin: P2 joins, at least "snk_min"
#                 frames from 2001 to 3099 equal to the SNK BIOS in free play, at most "seul_max" to
#                 the game without P2 (bo-fp).
#   bo-no-continue NO CONTINUE ON: two coins, START, the game lost, START at 6300 during aof's
#                 continue countdown (BIOS_PLAYER_MOD1 at 2 from 6116 to 6716): refused; at least
#                 "fin_min" of frames 6400-8699 are those of partie2 (the same path without this
#                 START: game over, the title), at most "cont_max" those of bo-cont (the START
#                 taken, without the setting: the game continues); the credit stays at 01.
#   bo-demo-muette DEMO SOUND OFF, against bo-dm0: the demo 600-2989 has an RMS of at most
#                 "demo_max" times that of the witness and at most "keyon_max" key-ons; a coin at
#                 3000, the title 3010-3289 at least "titre_min" times (its music); START at 3300,
#                 the game 3400-4399 at least "partie_min" times; after the game over, the next
#                 demo again at most "demo_max" times.
#   bo-aes        the AES mode: the three settings set to ON / ON / OFF, then MODE AES in the same
#                 screen; CABINET SETTINGS reopened says MVS ONLY three times and A changes nothing
#                 there. MAME relaunched in AES (STORY MODE lost, START at 7500 during the continue,
#                 BIOS_PLAYER_MOD1 at 2 from 7338 to 7938): the continue is taken; at least
#                 "cont_min" frames from 7500 to 8799 equal to bo-aes-cont (the same inputs without
#                 setting), at most "fin_max" to aes-histoire (without this START); the demo 300-989
#                 has an RMS of at least "demo_min" times that of bo-aes-cont: NO CONTINUE and DEMO
#                 SOUND are inert in AES, FREE PLAY masked.
#   bf-borne      under `bus-flottant.lua`, like the bf-* scenes: CABINET SETTINGS, FREE PLAY → ON,
#                 START, START: no floating read, each frame equal to the free witness, the
#                 sub-screen and ART OF FIGHTING legible.
#   THE CHEAT CATALOGUE AND CHEATS/DEBUG, on 2026-10-25 (`src/c0/cheats.s`, `menu.s`, the fourth
#   line of CABINET SETTINGS; thresholds in --ref-cheats). The whole catalogue is played by
#   `bench/cheats-catalogue.sh`; here, one of its games.
#   cheats-vies  mslug2, INFINITE LIVES set to ON by the in-game menu (TEST 1500-1539, "down"
#                 twice, A, RESUME): from 1700 to 9000, the image of the HUD's lives counter
#                 ("1UP=2", x 22-56, y 28-38) keeps the same value on at least "hud_on_min" of the
#                 frames, and at most "hud_temoin_max" in the witness that opens and closes the same
#                 menu without changing anything; the witness loses the game (BIOS_USER_MODE leaves
#                 2, the CONTINUE screen), the game under cheat lasts until 9000; the menu showed
#                 "INFINITE LIVES ON".
#   bo-cd-menu    CHEATS/DEBUG → OFF (CABINET SETTINGS, "down" three times, right), aof relaunched:
#                 the in-game menu of 2357 has neither a cheat line nor MEMORY EDITOR (the cheats
#                 run, at the default setting, shows both), RESUME, RESTART GAME and GAME SETTINGS
#                 remain; "up" from RESUME leads to GAME SETTINGS, "down" from there to RESUME.
#   THE GRID OF $C03000, on 2026-10-25 (`src/c0/grille.s`; thresholds in --ref-ssideki).
#   demo-ssideki  ssideki on the MV-6F, the demo without a coin: from 400 to 2399 frames after the
#                 hand-over (REMISE of son.lua), the number of distinct images and of key-ons,
#                 relative to the same frames of the SNK witness (ssideki, -bios euro, original
#                 romset), at least "images_ratio_min" and "keyon_ratio_min". Frozen after the
#                 intro of the stadium, the demo only replays its last images: the title, KICK
#                 OFF and the demo match do not come.
#   bo-cd-gel     same setting, a freeze set by lua at 2400 in the engine's RAM (GL_MASQUE,
#                 $108406 at $60: what D of the memory editor would have left): aof's timer changes
#                 from +300 to +1500, and $108406 only equals $60 on at most "ram_max" of the 1,200
#                 frames; the same freeze at the default setting (bo-cd-gel-on) freezes the timer:
#                 the setting acts, and it is the setting that turns it off.
#   The fourth line is added to the scenes bo-ecran (CHEATS/DEBUG ON by default) and bo-aes (in
#   AES mode, it stays ON and does not say MVS ONLY).
#   THE BOARD SWITCHES AND THE GESTURE WITHOUT A TEST BUTTON, on 2026-10-25 (`src/c0/io.s`,
#   `dip.s`, `menu.s`; thresholds in --ref-dip). On the MV-2F (`ng_mv2f -cart1 aof`, the one of
#   the hardware trial, which has a SELECT field), fresh NVRAM. Each run sets its switches by
#   J_DSW, OFF included ("1:00"); the other scenes set none, each run having its cfg: MAME leaves
#   them at OFF there, their default.
#   dip-free-play switch 7 ("Free Play") at ON, START at 1600 without a coin: from 1601 to 2400,
#                 at least "cases_min" cells differ from the demo at the same switch at frame 2000
#                 (the game), and the credit stays at 00; the demo before differs from that of the
#                 switch at OFF on at least "demo_min" of frames 600-1599 ("PUSH 1P OR 2P START
#                 BUTTON" instead of "INSERT COIN": CREDIT_CHECK no longer refuses), and it is that
#                 of the SNK BIOS at the same switch on at least "snk_min" frames (best offset:
#                 their demos do not start at the same frame), that of the SNK BIOS at OFF on at
#                 most "snk_off_max".
#   dip-fp-p2     same switch, START P2 at 1600: BIOS_START_FLAG at $03 (both players, complement),
#                 and at least "diff_min" of frames 1601-2400 differ from those of a START P1.
#   dip-fp-refus  the witness: switch at OFF, START at 1600 without a coin: refused, at least
#                 "egales_min" of frames 1601-2400 are those of the demo at OFF without START.
#   dip-fp-chaud  the switch flipped at frame 1200: OFF → ON, at least "apres_min" of frames
#                 1210-1599 are those of the demo at ON, and START at 1600 starts the game (mode
#                 2); ON → OFF, as many of those of the demo at OFF, and START refused (mode 1).
#                 The two demos have between them at most "temoins_max" equal frames: without
#                 that, the flip would not show.
#   dip-fp-reglage switch 7 at OFF (set) and FREE PLAY ON in CABINET SETTINGS (NVRAM of
#                 bo-set-fp, aof): START at 1000 without a coin starts the game (mode 2), frame 1400
#                 differs from the demo of bo-dm0 by at least "cases_min" cells: either one is
#                 enough.
#   dip-fp-cabinet switch 7 at ON, TEST held at boot, CABINET SETTINGS: FREE PLAY says DIP, right
#                 changes nothing there (DIP still), START, START: $D0021D stays at 0 (complement).
#   dip-setting   switch 1 ("Setting Mode") at ON, no key: the TEST screen (SOFT DIP SETTINGS) at
#                 500; START at 600 leaves it: the switch still at ON, DIP SWITCH 1 IS ON at 650,
#                 then control to the game, at least "avert_min" frames after START. Flipped back
#                 to OFF at 550 (ds-bascule): no warning, not even one frame (the fix layer
#                 recorded at each frame from 600 to 650), control to the game less than
#                 "direct_max" frames after START. At OFF from boot (set, the witness): no TEST
#                 screen, control to the game before 300.
#   geste-boot    START and SELECT of P1 held from 20 to 220: the TEST screen at 300; START alone,
#                 then SELECT alone (the witnesses, the partial gesture): no TEST screen, control
#                 to the game before 300. The BlueRetro adapter (brief DOWN at 17, then START,
#                 SELECT, A, B, C and D held from 20 to 80): no TEST screen, control to the game
#                 before 300; START, SELECT and A held from 20 to 220: the TEST screen at 300, like
#                 the gesture alone.
#   geste-jeu     in game (free play), START and SELECT of P1 held from 1700 to 1760: IN-GAME MENU
#                 at 1800, the game paused; START alone, then SELECT alone (the witnesses): no
#                 pause, no menu. The adapter (brief DOWN at 1697, then START, SELECT, A, B, C and D
#                 from 1700 to 1760): no pause, no menu, and the gesture count (MN_COMPTE) does not
#                 reach 20; START, SELECT and A from 1700 to 1760: the menu and the pause.
#   geste-partie  aof, mslug, samsho4 and ssideki played on the MV-2F (free play, START at 1000,
#                 then A, B, C, D, START and the directions tapped from 1100 to 6000, right held at
#                 times; never SELECT): from the game until 6000, the gesture count (MN_COMPTE,
#                 $10F800, the BIOS RAM, `menu.s`) never reaches "compte_max" and no pause of at
#                 least "pause_min" frames: the gesture is never made by accident. The gj run (the
#                 gesture made) serves as witness to the instrument: its count reaches 20, the
#                 opening threshold.
#   THE LABELS IN THE JAPAN REGION, on 2026-10-27 (measured/2026-10-27-intitules-japon.tsv; no
#   threshold: everything is exact). ssideki and bstars, their romset, our image substituted; the
#   region set by the editor (left twice: JAPAN, once: USA), START, the machine restarts. The raw
#   fix layer (J_TUILES of son.lua).
#   japon-intitules the TEST screen of the boot in JAPAN (TEST held from 560 to 1000, after the
#                 relaunch): each label of the witness, the Japanese SNK BIOS (its byte sequence,
#                 bank $3), is found as is in a row of our screen: a byte with the same glyph in
#                 both banks ($20-$5E, $61-$7B) in 8×8, at $100 + b or at $300 + b, any other at
#                 $300 + b. Sequences, not positions: the two screens do not have the same layout.
#   gs-japon      GAME SETTINGS of ssideki in JAPAN (coin 1300, START 1400, TEST 2000-2039, "up"
#                 twice, A): the eight lines of the list are those of the same path in USA, to the
#                 character (the labels of the USA block, the values of the Japanese block, equal
#                 here); no tile of banks $3/$4 in the frame.
#   gs-japon-garde bstars, whose Japan and USA blocks do not have the same structure: in JAPAN, no
#                 label of the list is a label of the USA block (seen in USA by the same path), and
#                 no $3/$4 tile in the frame.
#   THE CARTRIDGE CRC32 AND THE DEBUG DIPS, on 2026-10-25 (`src/c0/crc.s`, CARTRIDGE CRC line of
#   HARDWARE TESTS; `src/c0/debug.s`, fifth line of CABINET SETTINGS; thresholds in --ref-crc). The
#   expected CRCs are computed OUTSIDE MAME, from the romset's zip, by `bench/crc-cartouche.py`;
#   the computation time is bounded by the record.
#   crc-fixe      aof: HARDWARE TESTS, "up" twice (CARTRIDGE CRC, just before EXIT), A: READING
#                 FIXED during the computation, then FIXED 1024K and the CRC of `crc-cartouche.py`,
#                 BANKS NONE, DONE at the latest at frame "fin_max"; START brings back the tests
#                 menu on CARTRIDGE CRC, START the TEST screen, START the game.
#   crc-banques   mslug2: FIXED and BANKS 2 X 1024K, the CRCs of `crc-cartouche.py`, which are also
#                 those of the p1 and sp2 files of `-listxml`; DONE at the latest at "fin_max"; the
#                 game restarts after the three STARTs.
#   crc-miroir    aof, its P-ROM served mirrored by `crc-miroir.lua` (a board that does not decode
#                 A19): FIXED 0512K and the CRC of the 044-p1.p1 file of `-listxml`, BANKS NONE.
#   crc-flottant  aof, its bank window reading only $5700 through `crc-flottant.lua` (a cartridge
#                 without a bank chip, measured on ssideki on 2026-10-29): FIXED and its CRC like
#                 crc-fixe, BANKS NONE.
#   bf-crc        aof, like crc-fixe, under `bus-flottant.lua`, like the bf-* scenes: no floating
#                 read, each frame equal to the free witness, the expected CRC on screen.
#   bf-crc-banque mslug on the MV-6F, likewise: the banks read under REG_CRTFIX, FIXED and BANKS 1 X
#                 1024K expected.
#   dd-effet      kof94: CABINET SETTINGS, "down" four times (DEBUG DIPS), A: the screen of the
#                 sixteen bits, all at 0; A sets DIP 1 bit 0 to 1; down, right, A, A: DIP 2 bit 1
#                 set then cleared; START: the line says 0100. The game: from 600 to 6000, the
#                 bottom of the screen (x 120-215, y 184-221: DEBUG OBJE, CH CODE, ACT CODE) differs
#                 from the dd-0 witness (the same path without A) on at least "zone_min" frames;
#                 $100000 has its bit 0 on at least "ram_min" frames (complement), and the first
#                 byte of the save block ($D00320) never has it: the mask does not go to backup RAM.
#   dd-connu      kof94 ALREADY REGISTERED (NVRAM of dd-set: first boot, save done), the path of
#                 dd-1: at the hand-over ($10FD80 ← $82), $100000 has its bit 0. The save is
#                 restored after the editor; without the mask set again after it, it overwrote it
#                 until the first SYSTEM_IO.
#   dd-off        kof94: DIP 1 bit 0 set, then CHEATS/DEBUG → OFF in the same sub-screen: DEBUG
#                 DIPS says OFF and A no longer opens it; the game, from 400 to 6000, has each frame
#                 equal to the dd-0off witness (the same path without the bit), and $100000 never
#                 has its bit 0.
#   BOARD SWITCHES 2, 3 AND 8, on 2026-10-27 (`src/c0/io.s`, `c0.s`, `ecran.s`; thresholds in
#   --ref-dip28; what the reference BIOSes do: measured/2026-10-27-dip-2-8.tsv). Switches set by
#   J_DSW.
#   dip-gel       aof on the MV-2F, free play (switch 7), START at 1600, switch 8 at ON from 2000
#                 to 2300: at least "figees_min" of frames 2003-2299 equal to the previous one (the
#                 run without freeze, gel0: at most "figees_off_max"), the SNK witness likewise;
#                 from 2310 to 2799, at least "reprise_min" frames equal to those of the run without
#                 freeze 300 frames earlier (the game resumes where it was); the YM2610 writes at
#                 least "ym_ratio_min" times what the run without freeze does (the sound left to
#                 the Z80); mode 2 and no RESET during the freeze.
#   dip-gel-off   switch 8 at OFF: at most "figees_off_max" frozen frames in game (gel0); at boot
#                 (ds0), no message, control to the game before 300.
#   dip-gel-boot  at ON from frame 1, OFF at 1000: DIP SWITCH 8 IS ON and SET IT OFF TO CONTINUE
#                 at 500, no control to the game before 1000, then control at most "reprise_max"
#                 frames after; the SNK witness, black screen, hands control back after 1000 too.
#   dip-mahjong   MAME's janshin machine (mahjong panel on P1), switch 3 at ON: B of the panel at
#                 1700, on the mode choice screen, changes at least "diff_min" of frames 1702-2099
#                 compared with the run without B (the witness, Japanese SNK BIOS, likewise). As a
#                 complement, the 19 keys alone then A+H+PON and A+B: each in its row
#                 ($10FD95-$10FD97, held) and in its edge ($10FDA1-$10FDA3, one frame), like the
#                 reference (record, section 8); BIOS_P1STATUS at 3. Flipped to ON in demo (aof,
#                 MV-2F): 3 at the coin, not before.
#   dip-mj-off    same machine, switch 3 at OFF: B changes no frame (at least "egales_min" equal to
#                 the run without B); the keys of rows A-G and H-N read as a joystick in
#                 BIOS_P1CURRENT, PON to REACH not; BIOS_P1STATUS at 0.
#   dip-4p        kizuna on the MV-2F, switch 2 at ON: $10FEF8 at 2, and the bottom of the screen at
#                 frame 900 has at least "cases_min" more lit cells than at OFF (a second CREDIT
#                 counter); the witness, the Japanese SNK BIOS (the European one does not read it),
#                 likewise at frame 1460. Flipped to ON in demo: 2 at the coin.
#   dip-4p-off    switch 2 at OFF: $10FEF8 at 0; flipped back to OFF in demo: 0 at the coin.
#   THE AUTOFIRE, on 2026-10-27 (`src/c0/autofire.s`, `io.s`, `menu.s`; thresholds in --ref-af;
#   the list of games: measured/2026-10-27-autofire.tsv). viewpoin (turbo is seen there, record),
#   in game: TEST held 1000-1039, the in-game menu, "up" three times (AUTOFIRE), A, then on BUTTON
#   A a key K at 1069, START, "down" three times (RESUME), A; A held from 1300 to 2299, or tapped
#   two frames out of four (the turbo pattern at 15 shots/s). K = A toggles; left and right, where
#   they change nothing, keep the same path through the menu in the witness.
#   af-tir        A set to ON (af-t), A held: from 1300 to 2399, at least "egales_min" frames equal
#                 to the run where A is tapped in the pattern without turbo (af-m), and at least
#                 "diff_min" that differ from the run where A is held without turbo (af-r); the
#                 screen said AUTOFIRE, BUTTON A OFF then ON. As a complement, BIOS_P1CURRENT
#                 ($10FD95) follows the pattern (A seen two frames, not two) on at least "ram_min"
#                 of frames 1302-2299.
#   af-sauve      MAME relaunched on the NVRAM of af-t, without changing anything (right on ON): the
#                 screen says BUTTON A ON, and at least "egales_min" frames equal to af-t, at least
#                 "diff_min" that differ from af-sauve0; the entry of viewpoin (NGH $0051) in
#                 backup RAM ($D001B4) at the end of af-t.
#   af-off        same NVRAM, A set back to OFF (af-sauve0): at least "egales_min" frames equal to
#                 af-r, A seen held continuously; MAME relaunched on its NVRAM (af-relu), without
#                 changing anything: likewise, OFF stored; the screen of af-relu says BUTTON A OFF
#                 before its key, and the entry of viewpoin is no longer at $D001B4.
#   af-mahjong    janshin, the entry set in backup RAM (J_BRAM, NGH $0048, A at ON), switch 3 at
#                 ON, key E of the panel held from 1700 to 2099: at least "egales_min" of frames
#                 1690-2099 equal to the run without the entry, and $10FD95 (row A-G) has only E
#                 on 1702-2099; the witness, switch 3 at OFF (E is A as a joystick): at least
#                 "bascules_min" toggles of A in BIOS_P1CURRENT.
#   THE GUARANTEES ON UNIBIOS DEFECTS, on 2026-10-27 (ATTENTES §2; thresholds in --ref-garanties).
#   boot-graphismes aof, and the same cartridge with the C ROMs and S ROM replaced by noise (the
#                 "brouille" fixture: a flashcart whose graphics are not yet readable), VRAM and
#                 palettes full of noise at power-on (`vram-hasard.lua`, like the hardware): from
#                 the frame that follows the first palette write of the BIOS until the hand-over,
#                 at most "differ_max" frames differ; after the hand-over, at least "jeu_min" of
#                 frames +5 to +504 differ (the game, for its part, reads its graphics: the fixture
#                 acts). The witness: UniBIOS 4.0, same two cartridges, at least "uni_min" of frames
#                 60-249 differ (its logo, displayed from ~95 to ~250, drawn with the graphics of
#                 the cartridge, gets scrambled).
#   ms-son-slot2  the MV-6F, aof alone in slot 2 (-cart2), slot 1 empty, without input: the slot
#                 served is 1; frames 600-3600, RMS and key-ons at least "rms_ratio_min" and
#                 "keyon_ratio_min" of the SNK BIOS on the same machine (the UniBIOS 4.0 defect on a
#                 multi-slot board: the sound cut outside the first slot).
#   dip-vierge    the boot editor on a never-initialised entry: an NVRAM where slot 0 carries
#                 another NGH and arbitrary bytes in the eight soft-DIP blocks and the names
#                 (vierge-n), then one where the table knows aof but its block is arbitrary
#                 (vierge-c), set by J_BRAM; ROUND TIME 60 → 65 like temps1. Against the same path
#                 on a fresh NVRAM (vierge-0): the editor at 250 and 330 has the same fix layer, the
#                 stored block ($D00220-$D0022F) is the same to the byte, frame 3000 differs by at
#                 most "cases_max" cells; the blocks of the other entries are not touched. These two
#                 NVRAMs go through `_dip_valider` (DECISIONS §23 pt 5): only vierge-m judges the
#                 editor itself. mslug on the MV-6F, its block in the banked area, which
#                 `_dip_valider` leaves alone; the bytes of vierge-c set (vierge-set-m), CONTINUE ON
#                 → OFF like bf-banque: the editor at 250 and 330 and the stored block are those of
#                 the same path on a fresh NVRAM (vierge-m0).
#   jukebox-veille the jukebox, code 21 played, no more input (DECISIONS §25): the image of 7600
#                 is the jukebox screen, that of 7800 entirely black; the sound of 7700-7990 has at
#                 least "rms_ratio_min" of the RMS of the veille-0 witness, which C tapped at 3000
#                 and 6000 keeps lit; UP at 8000 brings back the screen without changing the code
#                 (8050: the image of 7600), UP at 8100 changes it (21 → 22).
#   cm-copier     MEMORY CARD, C on 0044-00 of the source: "CHANGE CARD AND PRESS A"; the card
#                 changed, A. On an empty card (cp-vide): COPIED, and the card carries 0044-00 with
#                 the bytes of the source; on a card that already has it (cp-cible): "OVERWRITE
#                 0044-00?", A, COPIED, same bytes; B abandons (cp-renonce): CANCELLED, then A is an
#                 ordinary A (DELETE ?). The source is never written, and the game RAM set at
#                 $100000 and $1006BE comes out intact (DECISIONS §26).
#   tests-mahjong INPUT TEST, switch 3 at ON (DECISIONS §24): the MAHJONG PANEL page, each key
#                 followed by 0 or 1. On aof's joystick, read in the three rows at once: A sets E, L
#                 and REACH to 1, B sets F and M, up sets A, H and PON, START sets START; everything
#                 else at 0; START held brings back the tests menu. The switch goes to ON with the
#                 editor open, just before INPUT TEST: the menus, opened at OFF, stay on the
#                 joystick there (DECISIONS §30). The panel itself in INPUT TEST is proven only by
#                 dip-mahjong (§24 pt 3).
#   dip-corrompue the NVRAM of vierge-c (aof known, its soft-DIP block arbitrary) relaunched
#                 WITHOUT the editor, coin and START like temps0: GAME_DIP at frame 300 is that of
#                 the witness (the same story without the bytes set), and at least "egales_min" of
#                 frames 1000-2999 are its own (DECISIONS §23 pt 5: `_dip_valider` on read-back).
#                 The block in backup RAM still carries the bytes set.
#   THE SINE TABLE, on 2026-10-28 (`src/c0/sinus.s`, DECISIONS §18; thresholds in --ref-sinus).
#   Their romset, our image substituted; the SNK witness, the original romset (-bios euro).
#   alpha-trajectoire alpham2, coin 400, START 500, "up" held 1600-1624 (the ship put in place),
#                 then one of the eight directions held 20 frames from 1640: one run per direction.
#                 The movement of the ship, from frame 1639 to 1675, read on the images (centre of
#                 the box of its colours, y 24-211), is that of the witness within "tol_px" pixels,
#                 in x as in y. Under $FF, "up" also takes it to the right.
#   howto-preisle2 preisle2, coin 400, START 500, without other input: the HOW TO PLAY screen. The
#                 image of frame 1000 (the object to pick up on screen) is that of the witness, and
#                 at least "egales_min" of frames 525-1825 are too at the same instant. Under $FF,
#                 the object never appears.
#   THE MENUS ON THE MAHJONG PANEL, on 2026-10-28 (`src/c0/panneau.s`, DECISIONS §30; thresholds in
#   --ref-panneau). janshin, our image; no witness: the references are not compared with it on the
#   image (their menus are not ours), what they do is in
#   measured/2026-10-28-panneau-menus-reference.tsv. States, read at the ">" cursor of the fix layer.
#   pn-menu-on    the editor of the TEST button, switch 3 at ON: REGION on opening; E four times,
#                 MODE MVS; I, PON, B and C change nothing there; F, HARDWARE TESTS; A opens the
#                 self-tests (WORK RAM).
#   pn-menu-off   likewise at OFF: A, H, A, H lead to MODE MVS; PON and F change nothing there; B,
#                 HARDWARE TESTS; E opens it.
#   pn-valeur     at ON, on MODE: H sets it to AES, G sets it back to MVS (right and left, the value
#                 editor).
#   pn-verrou     the switch flipped at 268, the editor open (ON → OFF, then OFF → ON): the path of
#                 pn-menu-on, then that of pn-menu-off, still lead to the self-tests (read back, E
#                 would be the A button on REGION, A too).
#   pn-jeu        the in-game menu, switch 3 at ON, opened by TEST on the mode choice screen: F
#                 leads to RESTART GAME, E to RESUME, A resumes; B at 1800 changes at least
#                 "diff_min" of frames 1802-2199 compared with the same path without B (the game
#                 still reads the panel), none before.
#   The crash screen is not here: stage 3a of `non-regression.sh` judges it.
#
# EACH SCENE CAN FAIL: `bench/parcours-mutations.py --eprouver <roms> <travail>`, one
# mutation at a time on a copy of src/c0. All put to the test on 2026-10-23 on the image that
# fixes CREDIT_CHECK (6fc2d51b…): 60 out of 60 killed, 13 min with --jobs 2; then on that of the
# full in-game menu (2b3a3662…): 85 out of 85, 26 min with --jobs 2, then on its final image
# (01180fcb…, the `tst.l` of cheats.s): 85 out of 85, 56 min, another MAME alongside. The first
# 21, the reason:
#   boot-texte (MV5)             boot-ecran   hash 3912987540 instead of the record
#   boot-sans-saut               boot-saut    pause ended at 188 with A
#   calendrier-sans-jour         calendrier   CLOCK "10/00/26 FRI"
#   carte-jamais                 carte        0 cells on the CARD line
#   demo-muette (sans CRTFIX)    demo-son     RMS 0.09 of the SNK witness
#   credit-sans-piece            partie-*     the coin changes 0 cells; START 0 cells
#   fin-sans-demo                fin-demo     3 frames equal to the demo
#   fin-sans-titre               fin-titre    20 frames of the title
#   scores-sans-sauvegarde       scores       0 cells on the 1ST line
#   dip-oublie                   dip-temps, dip-langue   timer and text unchanged
#   region-ignoree               region       0 cells in the text
#   autotests-aveugles           autotests    WORK RAM OK instead of FAIL
#   jukebox-muet                 jukebox      code 7F: RMS 0
#   menu-police (fix undone)     menu-hud     68 cells change outside the frame (the HUD)
#   menu-son ($03, fix undone)   menu-son     RMS 0.07 of the witness
#   menu-cadre-reste             menu-reprise 0 frames equal to the witness
#   cheats-inertes               cheats       the timer changes under cheat
#   restart-reprend              restart      no RESET
#   demo-sans-rotation           ms-demo      the demo stays on slot 0
#   select-ignore                ms-select    no hand-over to slot 1
#   garde-retiree                ms-garde     2 DEMO_END read
# The mutations of the AES mode, put to the test on 2026-10-23 (record --ref-aes, header):
#   mode-ignore                  aes-bascule, aes-demo
#   mode-perdu                   aes-bascule
#   start-refuse                 aes-start, aes-menu
#   piece-comptee                aes-piece
#   mode-bloque                  aes-retour
# Set aside: REG_VRAMMOD not restored at RESUME survives (aof sets its own again; nothing visible).
# Those of the coverage, one per new scene, put to the test on 2026-10-23 (record --ref-couv,
# header): aes-insert-coin (the fixed defect, reintroduced), recherche-aveugle,
# suppression-inerte, nom-jamais-ecrit, select-lu-sur-start, commutateur-decale,
# soft-dip-sans-garde, defauts-inertes, temps-perdu, a-sans-boucle,
# europe-perdue, japon-en-usa, usa-en-japon, palette-non-testee, vram-non-testee,
# backup-non-testee, entrees-eteintes, barres-sans-rouge, grille-noire, jukebox-pas-de-16,
# jukebox-sans-repetition, jukebox-b-inerte, cheat-sans-off, p2-refuse, p2-joint-refuse,
# depart-jamais, piece-muette, carte-protegee, select-p2-suivant, select-seule-pris,
# select-aes-ignore, pause-aes-retiree, logo-jamais, aes-titre-apres-partie.
# Those of the full in-game menu, 25, put to the test one by one on 2026-10-23 (record
# --ref-menu): gs-droite-inerte, gs-defauts-inertes, gs-sans-enregistrement, gs-relance-inerte,
# gs-a-comme-droite, gs-sans-ligne-vide, gs-banque-acceptee, me-octet-voisin, me-goto-inerte,
# goto-gauche-inerte, goto-b-va, me-droite-inerte, me-gauche-inerte, me-ligne-courte,
# me-haut-court, me-page-courte, me-page-haut-courte, me-sans-repetition, me-ecriture-inerte,
# valeur-haut-inerte, annuler-inerte, gels-inertes, gels-non-listes, degel-inerte,
# borne-retiree. Survived and replaced: "B writes like A" (B is read before A and exits without
# writing), become annuler-inerte. 85 mutations in all.
# Those of the floating bus, 2, on 2026-10-24: bf-intitules-prom (the four bf-* scenes, 300 to
# 456 floating reads) and bf-nom-prom (bf-editeur, bf-banque, 16). 87 mutations in all.
# That of the MV-1 without a cartridge, on 2026-10-24: cartouche-absente-servie (sans-cartouche,
# 7 resets). 88 in all.
# Those of the memory card and of the scores, 16, on 2026-10-24 (record --ref-carte):
# cm-liste-vide, cm-nom-absent, cm-blocs-faux, cm-sans-defilement (cm-liste), cm-libres-faux,
# cm-effacer-inerte, cm-sans-confirmation (cm-annuler), cm-formater-inerte (cm-formater,
# cm-non-formatee), cm-non-formatee-muette, cm-sans-carte-muette, cm-protection-ignoree,
# cm-insertion-ignoree, bf-carte-nom-prom, aes-sans-restauration (aes-scores), gel-inerte and
# score-reset-oublie (scores-gel). 104 in all. On 2026-10-25: cm-confirmation-survit
# (cm-insertion, the confirmation kept across the card change). 105 in all. Those of the
# cabinet settings, 10, on 2026-10-25 (record --ref-borne): bo-sous-ecran-inerte,
# bo-borne-oubliee (bo-ecran, bo-free-play), bo-libre-inerte (bo-free-play, bo-fp-p2,
# bo-fp-joint), bo-p2-seul, bo-credit-refuse, bo-continue-pris, bo-aes-non-masque,
# bo-aes-affiche, bo-demo-sonore, bo-demo-toujours-muette; bf-borne is added to the scenes of
# bf-intitules-prom and bf-nom-prom. 115 in all. Those of the cheat catalogue and of
# CHEATS/DEBUG, 9, on 2026-10-25 (record --ref-cheats): cat-mslug2-perdu (cheats-vies),
# cd-trouver-ignore, cd-editeur-garde, cd-dernier-choix (bo-cd-menu), cd-moteur-ignore
# (bo-cd-gel), cd-bit-perdu (bo-cd-menu, bo-cd-gel), cd-aes-masque (bo-aes), cd-ligne-absente
# (bo-ecran), cd-defaut-off (cheats). 124 in all. Those of the board switches and of the
# gesture, on 2026-10-25 (record --ref-dip): dfp-ignore, dfp-bit-faux, dfp-credit-check,
# dfp-cabinet-off, dfp-cabinet-libre, setting-ignore, setting-bit-faux, geste-boot-ignore,
# geste-boot-start-seul, geste-jeu-ignore, geste-jeu-start-seul, setting-toujours,
# geste-boot-select-seul, geste-jeu-select-seul, geste-toujours, avertissement-absent,
# avertissement-toujours; dip-fp-p2 is added to the scenes of bo-p2-seul, dip-fp-reglage to
# those of bo-libre-inerte. 141 in all. That of the grid, on 2026-10-25 (record --ref-ssideki):
# grille-haute-ff (demo-ssideki). 142 in all. Those of the BlueRetro adapter, 4, on 2026-10-27:
# geste-boot-adaptateur, geste-boot-un-bouton (geste-boot), geste-jeu-adaptateur,
# geste-jeu-un-bouton (geste-jeu). 146 in all. Those of the labels in the JAPAN region, on
# 2026-10-27: japon-filtre, japon-banque-100 (japon-intitules), gs-sans-emprunt (gs-japon),
# gs-sans-garde, gs-regle-boot (gs-japon-garde). 151 in all. Those of the cartridge CRC32 and of
# the debug dips, 12, on 2026-10-25 (record --ref-crc):
# crc-ordre-cpu (crc-fixe, crc-banques, crc-miroir), crc-sans-crtfix (bf-crc, bf-crc-banque),
# crc-banques-ignorees, crc-miroir-de-banque (crc-banques, bf-crc-banque), crc-miroir-ignore
# (crc-miroir), dd-jamais-pose, dd-ecran-inerte, dd-dip2-perdu, dd-sauve (dd-effet),
# dd-ouvert-a-off, dd-off-ignore (dd-off), dd-ligne-absente (bo-ecran). 163 in all.
# Those of switches 2, 3 and 8, 11, on 2026-10-27 (record --ref-dip28):
# gel-jamais (dip-gel), gel-toujours (dip-gel-off), gel-boot-noir, gel-boot-absent
# (dip-gel-boot), mj-jamais, mj-sans-front (dip-mahjong), mj-boot-seul (dip-mahjong, dip-4p),
# mj-toujours, mj-off-sourd (dip-mj-off), 4p-jamais (dip-4p), 4p-toujours (dip-4p-off). 174 in
# all. Those of the autofire, 7, on 2026-10-27 (record --ref-af; written, not yet put to the
# test): af-inerte, af-cadence (af-tir), af-non-sauve, af-charge-jamais (af-sauve),
# af-off-ignore, af-off-non-retire (af-off), af-mahjong-pris (af-mahjong). 181 in all.
# Those of the guarantees, 4, on 2026-10-27 (record --ref-garanties):
# boot-police-cartouche, boot-sans-lsp (boot-graphismes), vierge-inutilises,
# vierge-sans-validation (dip-vierge). 185 in all. That of the validation on read-back:
# relecture-sans-validation (dip-corrompue). 186 in all. Those of the mahjong panel page:
# mj-page-absente, mj-touche-muette (tests-mahjong). 188 in all. Those of the screen saver:
# veille-jamais, veille-reveil-agit (jukebox-veille). 190 in all. Those of the card copy:
# cp-sans-ecrasement, cp-ram-perdue, cp-inerte (cm-copier). 193 in all. slot2-muet
# (ms-son-slot2) is withdrawn: MAME restarts the Z80 without its reset, the demo sounds
# (DECISIONS §23 pt 2). Those of the sine table, on 2026-10-28 (record --ref-sinus): sinus-ff
# (alpha-trajectoire, howto-preisle2), sinus-un-ffff (howto-preisle2 alone: its one-pixel
# departure stays under the "tol_px" of alpha-trajectoire). 195 in all. Those of the save of an
# already registered game, on 2026-10-28: restauration-avant-editeur (tests-sauvegarde),
# dd-ecrase-a-la-restauration (dd-connu). 197 in all.
# Those of the menus on the
# mahjong panel, on 2026-10-28 (record --ref-panneau), put to the test alone on the image
# f1b21158…: pn-sans-traduction (pn-menu-on, pn-valeur, pn-verrou, pn-jeu), pn-sans-1b
# (pn-menu-off, pn-verrou), pn-verrou-relu (pn-verrou), pn-e-f-echangees (pn-menu-on, pn-valeur,
# pn-verrou, pn-jeu). 201 in all. boot-sans-saut follows `_panneau_p1` in `ecran.s`, put to the
# test again and killed the same day.
# That of the cartridge that is late, on 2026-10-28: carte-lente-ignoree (flash-cart). 202 in all.
# Those of the ABOUT screen, on 2026-10-28: ab-ligne-absente, ab-ne-s-ouvre-pas, ab-start-ignore
# (ab-ecran). 205 in all.
# That of the bank window that reads only one word, on 2026-10-29: crc-flottant-ignore
# (crc-flottant). 206 in all.
# That of BIOS_LOGO under GL_MASQUE, on 2026-10-30: logo-sous-les-gels (aes-logo-fin). 207 in all.
#
# WHAT IT DOES NOT COVER: the hardware, outside the model of `bus-flottant.lua`; NO SOFT DIP DATA
# on a real game (none of the 166 sets of the directory has a refused block: the scene is played
# on a fixture); the CARD commands other than provoked (no aof play session calls $01, $04, $06,
# $07); SELECT on a one-cartridge machine (MAME's aof set has no SELECT field: the two elements
# of the INPUT TEST stay unlit there, measured, hence the MV-6F); SELECT P2 in AES mode; the
# Japanese soft-DIP text outside ssideki and bstars; games other than aof, puzzledp, b2b, kof98,
# ncombat; the ear (an RMS says there is sound, not that it is the right piece). The inventory
# of each function and of its scene: measured/2026-10-23-parcours-couverture.tsv.
#
# This script traces no code: in its jigs, the PC only serves to say who has control or who
# writes, except `forcer.lua`, which logs the return address of the call it forces. No ROM is
# read outside MAME, except the 68k header of the NO SOFT DIP DATA fixture: "NEO-GEO", the area
# of two vectors and the pointer, in a copy in the work directory, the game's code never read.
# MAME without a window, never a debugger.
set -u

ICI="$(cd "$(dirname "$0")" && pwd)"
PAQUET="$(cd "$ICI/.." && pwd)"
SOURCES="$PAQUET/src/c0"
IMAGE=""
REF="$PAQUET/measured/2026-10-23-parcours.tsv"
REF_AES="$PAQUET/measured/2026-10-23-parcours-aes.tsv"
REF_COUV="$PAQUET/measured/2026-10-23-parcours-couverture-scenes.tsv"
REF_MENU="$PAQUET/measured/2026-10-23-menu-en-jeu-complet.tsv"
REF_CARTE="$PAQUET/measured/2026-10-24-parcours-carte.tsv"
REF_BORNE="$PAQUET/measured/2026-10-25-parcours-borne.tsv"
REF_CHEATS="$PAQUET/measured/2026-10-25-parcours-cheats.tsv"
REF_DIP="$PAQUET/measured/2026-10-25-parcours-dip-free-play.tsv"
REF_SSIDEKI="$PAQUET/measured/2026-10-25-parcours-ssideki.tsv"
REF_CRC="$PAQUET/measured/2026-10-25-parcours-crc-debug.tsv"
REF_DIP28="$PAQUET/measured/2026-10-27-parcours-dip-2-8.tsv"
REF_AF="$PAQUET/measured/2026-10-27-parcours-autofire.tsv"
REF_GAR="$PAQUET/measured/2026-10-27-parcours-garanties.tsv"
REF_SINUS="$PAQUET/measured/2026-10-28-parcours-sinus.tsv"
REF_PANNEAU="$PAQUET/measured/2026-10-28-parcours-panneau.tsv"
JOBS=$(( $( (sysctl -n hw.ncpu || nproc) 2>/dev/null || echo 4) - 2 )); [ "$JOBS" -ge 1 ] || JOBS=1
CACHE=""
SCENES_TOUTES="boot-ecran boot-saut calendrier carte demo-son partie-credit partie-start fin-demo fin-titre scores dip-temps dip-langue region autotests jukebox menu-hud menu-reprise menu-son cheats restart ms-demo ms-select ms-garde aes-bascule aes-demo aes-start aes-menu aes-piece aes-retour dip-defauts dip-mmss dip-fois region-europe region-japon region-usa autotests-palette autotests-vram autotests-backup tests-entrees tests-barres tests-grille jukebox-pas jukebox-stop cheats-off partie-p2 carte-sauve ms-select-p2 aes-ms-select aes-pause aes-logo aes-logo-fin aes-fin aes-texte depart-force piece-son ms-seule jukebox-repete partie-p2-joint carte-chercher carte-supprimer carte-nom tests-p2 tests-dip dip-sans-donnees gs-compte gs-defauts gs-choix gs-mmss gs-fois gs-sans-donnees gs-banque me-ecran me-goto me-octet me-ligne me-page me-repete me-poke me-gel me-liste me-degel me-borne bf-editeur bf-banque bf-tests bf-jukebox sans-cartouche flash-cart cm-liste cm-libres cm-effacer cm-annuler cm-formater cm-non-formatee cm-sans-carte cm-protegee cm-insertion bf-carte aes-scores scores-gel bo-ecran ab-ecran bo-free-play bo-fp-p2 bo-fp-joint bo-no-continue bo-demo-muette bo-aes bf-borne cheats-vies bo-cd-menu bo-cd-gel dip-free-play dip-fp-p2 dip-fp-refus dip-fp-chaud dip-fp-reglage dip-fp-cabinet dip-setting geste-boot geste-jeu geste-partie demo-ssideki japon-intitules gs-japon gs-japon-garde crc-fixe crc-banques crc-miroir crc-flottant bf-crc bf-crc-banque dd-effet dd-off dip-gel dip-gel-off dip-gel-boot dip-mahjong dip-mj-off dip-4p dip-4p-off af-tir af-sauve af-off af-mahjong boot-graphismes ms-son-slot2 dip-vierge dip-corrompue tests-mahjong jukebox-veille cm-copier alpha-trajectoire howto-preisle2 tests-sauvegarde dd-connu pn-menu-on pn-menu-off pn-valeur pn-verrou pn-jeu"
SCENES="$SCENES_TOUTES"
HASHPATH="${BIOS_HASHPATH:-}"
while [ $# -gt 0 ]; do
  case "$1" in
    --image) IMAGE="${2:?--image attend un fichier}"; shift 2 ;;
    --sources) SOURCES="${2:?--sources attend un dossier}"; shift 2 ;;
    --scenes) SCENES="${2:?--scenes attend une liste}"; shift 2 ;;
    --ref) REF="${2:?--ref attend un fichier}"; shift 2 ;;
    --ref-aes) REF_AES="${2:?--ref-aes attend un fichier}"; shift 2 ;;
    --ref-couv) REF_COUV="${2:?--ref-couv attend un fichier}"; shift 2 ;;
    --ref-menu) REF_MENU="${2:?--ref-menu attend un fichier}"; shift 2 ;;
    --ref-carte) REF_CARTE="${2:?--ref-carte attend un fichier}"; shift 2 ;;
    --ref-borne) REF_BORNE="${2:?--ref-borne attend un fichier}"; shift 2 ;;
    --ref-cheats) REF_CHEATS="${2:?--ref-cheats attend un fichier}"; shift 2 ;;
    --ref-dip) REF_DIP="${2:?--ref-dip attend un fichier}"; shift 2 ;;
    --ref-ssideki) REF_SSIDEKI="${2:?--ref-ssideki attend un fichier}"; shift 2 ;;
    --ref-crc) REF_CRC="${2:?--ref-crc attend un fichier}"; shift 2 ;;
    --ref-dip28) REF_DIP28="${2:?--ref-dip28 attend un fichier}"; shift 2 ;;
    --ref-af) REF_AF="${2:?--ref-af attend un fichier}"; shift 2 ;;
    --ref-garanties) REF_GAR="${2:?--ref-garanties attend un fichier}"; shift 2 ;;
    --ref-sinus) REF_SINUS="${2:?--ref-sinus attend un fichier}"; shift 2 ;;
    --ref-panneau) REF_PANNEAU="${2:?--ref-panneau attend un fichier}"; shift 2 ;;
    --jobs) JOBS="${2:?--jobs attend un nombre}"; shift 2 ;;
    --hashpath) HASHPATH="${2:?--hashpath attend un dossier}"; shift 2 ;;
    --cache) CACHE="${2:?--cache attend un dossier}"; shift 2 ;;
    --) shift; break ;;
    -*) echo "option inconnue : $1" >&2; exit 2 ;;
    *) break ;;
  esac
done
ROMS="${1:?usage : bench/parcours.sh [--image f | --sources d] [--scenes l] [--ref f] [--ref-aes f] [--ref-couv f] [--ref-menu f] [--ref-carte f] [--ref-borne f] [--ref-cheats f] [--ref-dip f] [--ref-ssideki f] [--ref-crc f] [--ref-dip28 f] [--ref-af f] [--ref-garanties f] [--ref-sinus f] [--ref-panneau f] [--jobs n] [--cache d] <dossier-roms> <dossier-travail>}"
WORK="${2:?dossier de travail attendu}"
case "$JOBS" in ''|*[!0-9]*|0) echo "--jobs refusé : $JOBS" >&2; exit 2 ;; esac
for s in $SCENES; do case " $SCENES_TOUTES " in *" $s "*) ;; *) echo "scène inconnue : $s" >&2; exit 2 ;; esac; done
[ -d "$ROMS" ] || { echo "dossier de ROMs introuvable : $ROMS" >&2; exit 2; }
[ -s "$REF" ] || { echo "relevé introuvable : $REF" >&2; exit 2; }
[ -s "$REF_AES" ] || { echo "relevé introuvable : $REF_AES" >&2; exit 2; }
[ -s "$REF_COUV" ] || { echo "relevé introuvable : $REF_COUV" >&2; exit 2; }
[ -s "$REF_MENU" ] || { echo "relevé introuvable : $REF_MENU" >&2; exit 2; }
[ -s "$REF_CARTE" ] || { echo "relevé introuvable : $REF_CARTE" >&2; exit 2; }
[ -s "$REF_BORNE" ] || { echo "relevé introuvable : $REF_BORNE" >&2; exit 2; }
[ -s "$REF_CHEATS" ] || { echo "relevé introuvable : $REF_CHEATS" >&2; exit 2; }
[ -s "$REF_DIP" ] || { echo "relevé introuvable : $REF_DIP" >&2; exit 2; }
[ -s "$REF_SSIDEKI" ] || { echo "relevé introuvable : $REF_SSIDEKI" >&2; exit 2; }
[ -s "$REF_CRC" ] || { echo "relevé introuvable : $REF_CRC" >&2; exit 2; }
[ -s "$REF_DIP28" ] || { echo "relevé introuvable : $REF_DIP28" >&2; exit 2; }
[ -s "$REF_AF" ] || { echo "relevé introuvable : $REF_AF" >&2; exit 2; }
[ -s "$REF_GAR" ] || { echo "relevé introuvable : $REF_GAR" >&2; exit 2; }
[ -s "$REF_SINUS" ] || { echo "relevé introuvable : $REF_SINUS" >&2; exit 2; }
[ -s "$REF_PANNEAU" ] || { echo "relevé introuvable : $REF_PANNEAU" >&2; exit 2; }
command -v mame >/dev/null || { echo "mame introuvable" >&2; exit 2; }
# MAME's hash/: next to its bin/ (Homebrew: /opt/homebrew/share/mame/hash).
[ -n "$HASHPATH" ] || HASHPATH="$(dirname "$(command -v mame)")/../share/mame/hash"
[ -s "$HASHPATH/neogeo.xml" ] || { echo "liste logicielle neogeo introuvable sous $HASHPATH (--hashpath)" >&2; exit 2; }
mkdir -p "$WORK"
ROMS="$(cd "$ROMS" && pwd)"; WORK="$(cd "$WORK" && pwd)"
REF="$(cd "$(dirname "$REF")" && pwd)/$(basename "$REF")"
REF_AES="$(cd "$(dirname "$REF_AES")" && pwd)/$(basename "$REF_AES")"
REF_COUV="$(cd "$(dirname "$REF_COUV")" && pwd)/$(basename "$REF_COUV")"
REF_MENU="$(cd "$(dirname "$REF_MENU")" && pwd)/$(basename "$REF_MENU")"
REF_CARTE="$(cd "$(dirname "$REF_CARTE")" && pwd)/$(basename "$REF_CARTE")"
REF_BORNE="$(cd "$(dirname "$REF_BORNE")" && pwd)/$(basename "$REF_BORNE")"
REF_CHEATS="$(cd "$(dirname "$REF_CHEATS")" && pwd)/$(basename "$REF_CHEATS")"
REF_DIP="$(cd "$(dirname "$REF_DIP")" && pwd)/$(basename "$REF_DIP")"
REF_SSIDEKI="$(cd "$(dirname "$REF_SSIDEKI")" && pwd)/$(basename "$REF_SSIDEKI")"
REF_CRC="$(cd "$(dirname "$REF_CRC")" && pwd)/$(basename "$REF_CRC")"
REF_DIP28="$(cd "$(dirname "$REF_DIP28")" && pwd)/$(basename "$REF_DIP28")"
REF_AF="$(cd "$(dirname "$REF_AF")" && pwd)/$(basename "$REF_AF")"
REF_GAR="$(cd "$(dirname "$REF_GAR")" && pwd)/$(basename "$REF_GAR")"
REF_SINUS="$(cd "$(dirname "$REF_SINUS")" && pwd)/$(basename "$REF_SINUS")"
REF_PANNEAU="$(cd "$(dirname "$REF_PANNEAU")" && pwd)/$(basename "$REF_PANNEAU")"
DEBUT=$(date +%s)

# ---- The image and the romsets ------------------------------------------------------------------
if [ -z "$IMAGE" ]; then
  [ -d "$SOURCES" ] || { echo "sources introuvables : $SOURCES" >&2; exit 2; }
  IMAGE="$WORK/bios.sp1"; rm -f "$IMAGE"
  BIOS_OBJ="$WORK/obj" "$PAQUET/build/construire.sh" "$SOURCES" "$IMAGE" > "$WORK/construction.log" 2>&1 \
    || { tail -5 "$WORK/construction.log"; echo "construction en échec" >&2; exit 1; }
fi
[ "$(wc -c < "$IMAGE" 2>/dev/null)" -eq 131072 ] 2>/dev/null || { echo "image refusée (131 072 octets attendus) : $IMAGE" >&2; exit 2; }
EMP="$(shasum -a 256 "$IMAGE" | cut -d' ' -f1)"
R="$WORK/roms"; mkdir -p "$R/img"
if [ "$(cat "$R/.image-sha256" 2>/dev/null)" != "$EMP" ]; then rm -f "$R"/*.zip "$R/.image-sha256"; rm -rf "$R/nosd" "$R/banque" "$R/brouille"; fi
rm -f "$R/img/sp-s2.sp1"; cp "$IMAGE" "$R/img/sp-s2.sp1"
for j in aof puzzledp b2b neogeo; do
  d="$R/$j.zip"
  [ -L "$d" ] && { echo "REFUS : $d est un lien symbolique" >&2; exit 1; }
  [ -s "$d" ] && continue
  [ -s "$ROMS/$j.zip" ] || { echo "set introuvable : $ROMS/$j.zip" >&2; exit 2; }
  rm -f "$d.part"
  cp "$ROMS/$j.zip" "$d.part" && ( cd "$R/img" && zip -q -j -X "$d.part" sp-s2.sp1 ) && mv "$d.part" "$d" || exit 1
done
echo "$EMP" > "$R/.image-sha256"
# kof98 and ncombat are only used on the MV-6F (`neogeo -cart1`): their romset is read as is
# in <roms-dir>, our image coming from neogeo.zip; none is copied.
for j in kof98 ncombat; do [ -s "$ROMS/$j.zip" ] || { echo "set introuvable : $ROMS/$j.zip" >&2; exit 2; }; done
case " $SCENES " in *" bf-banque "*|*" dip-vierge "*) [ -s "$ROMS/mslug.zip" ] || { echo "set introuvable : $ROMS/mslug.zip" >&2; exit 2; } ;; esac
# ssideki (demo-ssideki scene): on the MV-6F, like kof98; the SNK witness reads the same romset.
case " $SCENES " in *" demo-ssideki "*) [ -s "$ROMS/ssideki.zip" ] || { echo "set introuvable : $ROMS/ssideki.zip" >&2; exit 2; } ;; esac
case " $SCENES " in *" scores-gel "*) [ -s "$ROMS/wh2.zip" ] || { echo "set introuvable : $ROMS/wh2.zip" >&2; exit 2; } ;; esac
# mslug2 (scenes cheats-vies, crc-banques) and kof94 (dd-effet, dd-off, dd-connu): their romset,
# our image substituted, like aof.
copier_set() {
  local j="$1" d="$R/$1.zip"
  [ -L "$d" ] && { echo "REFUS : $d est un lien symbolique" >&2; exit 1; }
  if [ ! -s "$d" ]; then
    [ -s "$ROMS/$j.zip" ] || { echo "set introuvable : $ROMS/$j.zip" >&2; exit 2; }
    rm -f "$d.part"
    cp "$ROMS/$j.zip" "$d.part" && ( cd "$R/img" && zip -q -j -X "$d.part" sp-s2.sp1 ) && mv "$d.part" "$d" || exit 1
  fi
}
case " $SCENES " in *" cheats-vies "*|*" crc-banques "*) copier_set mslug2 ;; esac
case " $SCENES " in *" dd-effet "*|*" dd-off "*|*" dd-connu "*) copier_set kof94 ;; esac
# janshin (dip-mahjong, dip-mj-off: its own machine, the mahjong panel) and kizuna (dip-4p,
# dip-4p-off): their romset, our image substituted, like aof.
case " $SCENES " in *" dip-mahjong "*|*" dip-mj-off "*|*" af-mahjong "*|*" pn-"*) copier_set janshin ;; esac
case " $SCENES " in *" af-tir "*|*" af-sauve "*|*" af-off "*) copier_set viewpoin ;; esac
case " $SCENES " in *" dip-4p "*|*" dip-4p-off "*) copier_set kizuna ;; esac
# alpham2 (alpha-trajectoire) and preisle2 (howto-preisle2): their romset, our image substituted;
# the witness reads the original.
case " $SCENES " in *" alpha-trajectoire "*) copier_set alpham2 ;; esac
case " $SCENES " in *" howto-preisle2 "*) copier_set preisle2 ;; esac
case " $SCENES " in *" bf-crc-banque "*) [ -s "$ROMS/mslug.zip" ] || { echo "set introuvable : $ROMS/mslug.zip" >&2; exit 2; } ;; esac
# ssideki and bstars (scenes japon-intitules, gs-japon, gs-japon-garde): their romset, our image
# substituted, like aof (ssideki's zip itself carries an sp-s2.sp1, pitfall 1 of docs/BENCH.md).
for x in "ssideki|japon-intitules gs-japon" "bstars|gs-japon-garde"; do
  IFS='|' read -r j sc <<< "$x"
  besoin=0; for t in $sc; do case " $SCENES " in *" $t "*) besoin=1 ;; esac; done
  [ $besoin -eq 1 ] || continue
  d="$R/$j.zip"
  [ -L "$d" ] && { echo "REFUS : $d est un lien symbolique" >&2; exit 1; }
  if [ ! -s "$d" ]; then
    [ -s "$ROMS/$j.zip" ] || { echo "set introuvable : $ROMS/$j.zip" >&2; exit 2; }
    rm -f "$d.part"
    cp "$ROMS/$j.zip" "$d.part" && ( cd "$R/img" && zip -q -j -X "$d.part" sp-s2.sp1 ) && mv "$d.part" "$d" || exit 1
  fi
done
# The MV-1 without a cartridge (sans-cartouche scene): the machine's set, our image substituted.
case " $SCENES " in *" sans-cartouche "*)
  d="$R/ng_mv1.zip"
  [ -L "$d" ] && { echo "REFUS : $d est un lien symbolique" >&2; exit 1; }
  if [ ! -s "$d" ]; then
    [ -s "$ROMS/ng_mv1.zip" ] || { echo "set introuvable : $ROMS/ng_mv1.zip" >&2; exit 2; }
    rm -f "$d.part"
    cp "$ROMS/ng_mv1.zip" "$d.part" && ( cd "$R/img" && zip -q -j -X "$d.part" sp-s2.sp1 ) && mv "$d.part" "$d" || exit 1
  fi ;;
esac
# The MV-2F (dip-* and geste-* scenes): the machine's set, our image substituted, aof as cartridge.
case " $SCENES " in *" geste-partie "*) for j in mslug samsho4 ssideki; do
  [ -s "$ROMS/$j.zip" ] || { echo "set introuvable : $ROMS/$j.zip" >&2; exit 2; }; done ;; esac
case " $SCENES " in *" dip-"*|*" geste-"*)
  d="$R/ng_mv2f.zip"
  [ -L "$d" ] && { echo "REFUS : $d est un lien symbolique" >&2; exit 1; }
  if [ ! -s "$d" ]; then
    [ -s "$ROMS/ng_mv2f.zip" ] || { echo "set introuvable : $ROMS/ng_mv2f.zip" >&2; exit 2; }
    rm -f "$d.part"
    cp "$ROMS/ng_mv2f.zip" "$d.part" && ( cd "$R/img" && zip -q -j -X "$d.part" sp-s2.sp1 ) && mv "$d.part" "$d" || exit 1
  fi ;;
esac
# The `aes` set of the reference column: two files of neogeo.zip, copied without being read.
if [ ! -s "$R/aes/aes.zip" ]; then
  rm -rf "$R/aes"; mkdir -p "$R/aes/x"
  ( cd "$R/aes/x" && unzip -q -o "$ROMS/neogeo.zip" neo-epo.bin 000-lo.lo && zip -q -j -X ../aes.zip neo-epo.bin 000-lo.lo ) \
    || { echo "aes.zip impossible : neo-epo.bin et 000-lo.lo attendus dans $ROMS/neogeo.zip" >&2; exit 2; }
fi
# The NO SOFT DIP DATA fixture: a copy of aof's substituted romset, in which only the pointer of
# the European soft-DIP block of the 68k header ($11E, "68k program header": one long per region
# at $116, $11A, $11E) is replaced by $00180000, between the fixed P-ROM and the banked area:
# refused (`src/c0/dip.s`, THE SOFT-DIP BLOCK POINTER). Nothing else is read in the P-ROM than
# what the page publishes: "NEO-GEO" at $100, and two vectors of which only the area is checked
# (SSP in work RAM, reset in the fixed P-ROM or the BIOS); that is what proves the byte order of the file,
# each word being stored there with its bytes swapped (`load16_word_swap`). In the work
# directory only.
# THE BANKED AREA FIXTURE, same recipe, the pointer at $00200100: accepted by the boot editor
# (`dip.s`), refused by GAME SETTINGS in game (`reglages-jeu.s`, deliberate departure).
# fixture <dir> <pointer, hex>: the copy, once per image.
fixture() {
  local D="$1" PTR="$2"
  [ -s "$D/aof.zip" ] && return 0
  rm -rf "$D"; mkdir -p "$D"
  python3 -I -B - "$R/aof.zip" "$D/aof.zip.part" "$PTR" <<'PY' || { echo "fixture $D impossible" >&2; exit 1; }
import sys, zipfile
src, dst, ptr = sys.argv[1], sys.argv[2], int(sys.argv[3], 16)
zi = zipfile.ZipFile(src)
p1 = [n for n in zi.namelist() if n.endswith(".p1") and not n.startswith("sp")]
assert len(p1) == 1, f"un seul fichier p1 attendu : {p1}"
f = bytearray(zi.read(p1[0]))
mem = lambda a: f[a ^ 1]                  # byte a of the 68000: the word of the file, swapped
lng = lambda a: (mem(a) << 24) | (mem(a + 1) << 16) | (mem(a + 2) << 8) | mem(a + 3)
assert bytes(mem(0x100 + i) for i in range(7)) == b"NEO-GEO", "ordre des octets : « NEO-GEO » absent à $100"
assert 0x100000 <= lng(0) <= 0x10FFFF, "ordre des octets : le SSP n'est pas en RAM de travail"
assert lng(4) < 0x100000 or 0xC00000 <= lng(4) <= 0xC1FFFF, "ordre des octets : le reset ne vise ni la P-ROM fixe ni le BIOS"
avant = lng(0x11E)
assert 0 < avant <= 0x100000 - 0x20, "le pointeur européen d'origine n'est pas valide : la fixture ne prouverait rien"
for i in range(4):
    f[(0x11E + i) ^ 1] = (ptr >> (24 - 8 * i)) & 0xFF
assert lng(0x11E) == ptr
zo = zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED)
for n in zi.namelist():
    zo.writestr(n, bytes(f) if n == p1[0] else zi.read(n))
zo.close()
print(f"fixture : {p1[0]}, pointeur européen remplacé par ${ptr:08X}", file=sys.stderr)
PY
  mv "$D/aof.zip.part" "$D/aof.zip"
}
NOSD="$R/nosd"
BANQUE="$R/banque"
case " $SCENES " in *" dip-sans-donnees "*|*" gs-sans-donnees "*) fixture "$NOSD" 00180000 ;; esac
case " $SCENES " in *" gs-banque "*) fixture "$BANQUE" 00200100 ;; esac
# THE FIXTURE CARD of the card manager (scenes cm-*, bf-carte), in the "Memory card" format (NeoGeo
# Development Wiki) as `src/c0/card.s` reads it: a file of 2,048 bytes, byte N of the card at
# offset N (MAME's -memc file, measured on the card of the carte-sauve-snk run). Header:
# CARD_SIZE $1000 at $0A, the sums of the two FATs at $0D and $0E, sixteen spaces at $10,
# CARD_MAGIC "NEO-GEO" then $80 at the even bytes from $20 to $2E, the region at $30; the
# directory at $40, 32 entries of four bytes (sub-save, NGH, first block; $FF free); FAT 1 at
# $C0 and FAT 2 at $100 (blocks 0-4 at $02, $01 the last of a chain, otherwise the next); the
# data from block 5 on, at zero. The content of 2,048 bytes comes from no real card.
carte_fixture() {
  local D="$R/cartes"
  [ -s "$D/fixture.neo" ] && return 0
  mkdir -p "$D"
  python3 -I -B - "$D/fixture.neo" <<'PY' || { echo "carte fixture impossible" >&2; exit 1; }
import sys
c = bytearray(2048)
c[0x0A], c[0x0B] = 0x10, 0x00
c[0x10:0x20] = b" " * 16
for i, x in enumerate(b"NEO-GEO\x80"):
    c[0x20 + 2 * i] = x
c[0x30] = 0x02
for k in range(32):
    c[0x40 + 4 * k] = 0xFF
fat = [0] * 64
for b in range(5):
    fat[b] = 2
libre = [5]
def chaine(n):
    blocs = list(range(libre[0], libre[0] + n))
    libre[0] += n
    for a, b in zip(blocs, blocs[1:]):
        fat[a] = b
    fat[blocs[-1]] = 1
    return blocs[0]
# (entry, sub-save, NGH, blocks): aof; an NGH with no registered game, three blocks; entry 2 free;
# twelve of one block.
saves = [(0, 0, 0x0044, 1), (1, 1, 0x0202, 3)] + [(3 + k, k % 16, 0x0100 + k, 1) for k in range(12)]
for e, sub, ngh, n in saves:
    c[0x40 + 4 * e:0x44 + 4 * e] = bytes([sub, ngh >> 8, ngh & 0xFF, chaine(n)])
c[0xC0:0x100] = bytes(fat)
c[0x100:0x140] = bytes(fat)
c[0x0D] = c[0x0E] = sum(fat) & 0xFF
assert libre[0] == 21, libre
open(sys.argv[1], "wb").write(c)
PY
}
case " $SCENES " in *" cm-liste "*|*" cm-libres "*|*" cm-protegee "*|*" cm-insertion "*|*" bf-carte "*|*" cm-copier "*) carte_fixture ;; esac
# THE CARDS OF THE COPY (cm-copier scene), drawn from the fixture: the source, where aof's save
# (0044-00, block 5) carries a pattern; an empty formatted card; the target, the fixture itself,
# where 0044-00 already exists (at zero).
case " $SCENES " in *" cm-copier "*)
  [ -s "$R/cartes/copie-vide.neo" ] || python3 -I -B - "$R/cartes" <<'PY' || { echo "cartes de la copie impossibles" >&2; exit 1; }
import sys
d = sys.argv[1]
f = bytearray(open(d + "/fixture.neo", "rb").read())
s = bytearray(f)
for i in range(64):
    s[5 * 64 + i] = (i * 7 + 3) & 0xFF
open(d + "/copie-source.neo", "wb").write(s)
v = bytearray(f)
for k in range(32):
    v[0x40 + 4 * k:0x44 + 4 * k] = b"\xff\x00\x00\x00"
fat = [2] * 5 + [0] * 59
v[0xC0:0x100] = bytes(fat)
v[0x100:0x140] = bytes(fat)
v[0x0D] = v[0x0E] = sum(fat) & 0xFF
v[5 * 64:] = bytes(len(v) - 5 * 64)
open(d + "/copie-vide.neo", "wb").write(v)
open(d + "/copie-cible.neo", "wb").write(f)
PY
  ;;
esac
# THE "BROUILLE" FIXTURE (boot-graphismes scene): a copy of aof's substituted romset whose C ROMs
# and S ROM (`*.c<n>`, `*.s1`) are replaced by noise drawn from a fixed seed: a flashcart whose
# graphics are not yet readable at boot (ATTENTES §2). These files are overwritten without being
# read.
BROUILLE="$R/brouille"
case " $SCENES " in *" boot-graphismes "*)
  if [ ! -s "$BROUILLE/aof.zip" ]; then
    mkdir -p "$BROUILLE"
    python3 -I -B - "$R/aof.zip" "$BROUILLE/aof.zip.part" <<'PY' || { echo "fixture brouille impossible" >&2; exit 1; }
import random, re, sys, zipfile
zi, zo = zipfile.ZipFile(sys.argv[1]), zipfile.ZipFile(sys.argv[2], "w", zipfile.ZIP_DEFLATED)
g, n = random.Random(1448), 0
for nom in zi.namelist():
    if re.search(r"\.(c\d+|s1)$", nom):
        zo.writestr(nom, g.randbytes(zi.getinfo(nom).file_size)); n += 1
    else:
        zo.writestr(nom, zi.read(nom))
zo.close()
assert n == 5, f"{n} fichiers brouillés, 5 attendus (044-c1 à c4, 044-s1)"
PY
    mv "$BROUILLE/aof.zip.part" "$BROUILLE/aof.zip"
  fi ;;
esac
echo "image ${EMP:0:16}…, scènes : $SCENES"

# ---- The runs ---------------------------------------------------------------------------------------
# lancer <run> <jig> "<MAME arguments>" [VAR=value…]: in the background, at most $JOBS at a time.
# "@" in the arguments becomes the run's directory. NV_DE=<run> before the call: the NVRAM of
# that run is copied first (a restart of the machine); CARTE_DE=<run>: its memory card (an
# absolute path: that file). The host date is noted before and
# after each run, for the CLOCK line. One cfg per run (-cfg_directory): MAME keeps there the
# switches set by J_DSW, and a shared cfg left "Free Play" at ON for the following runs of the
# same game, SNK witnesses included (measured on 2026-10-25: nine scenes failing after the
# bo-snk-*).
PIDS=""
NV_DE=""
CARTE_DE=""
# THE WITNESS CACHE (--cache). A witness is a run whose name carries "snk" (the rule of `sain`)
# and that reads no romset from $R, where our image is ($R/aes excepted: the `aes` set, copied
# from neogeo.zip). Its result therefore does not depend on our image: it is reused from a
# previous run when its key is the same. The key covers everything it depends on: MAME (version
# and effective configuration, `-showconfig`, which the user's mame.ini can change), this whole
# script (the command line of `lancer`), the jigs (all the .lua of bench/, which load one
# another), the software list, the romsets of the ROMs directory (name, size, date to the
# second, links followed), the run (name, jig, BIOS, arguments, variables), the NVRAM and the
# memory card it receives from another run, and THE DAY: the machine takes the host date, which
# the CLOCK line and dates.txt record. Only a run that exited with 0 and whose two dates in
# dates.txt are that day is kept (midnight passed during the run: not kept).
empreinte_fichiers() { stat -L -f '%N %z %m' "$@" 2>/dev/null || stat -L -c '%n %s %Y' "$@"; }
if [ -n "$CACHE" ]; then
  mkdir -p "$CACHE"; CACHE="$(cd "$CACHE" && pwd)"
  CLE_BASE="$( { mame -version; mame -showconfig; cat "$ICI/parcours.sh" "$ICI"/*.lua "$HASHPATH/neogeo.xml"; \
    empreinte_fichiers "$ROMS"/*.zip; } 2>&1 | shasum -a 256 | cut -d' ' -f1)"
fi
temoin() { # temoin <name> <MAME arguments>
  case "-$1-" in *-snk-*) ;; *) return 1 ;; esac
  local a="${2//"$R"\/aes/}"
  case "$a" in *"$R"*) return 1 ;; esac
}
attendre_place() {
  local p n=0 reste="" premier=""
  for p in $PIDS; do n=$(( n + 1 )); done
  [ $n -lt "$JOBS" ] && return
  for p in $PIDS; do if [ -z "$premier" ]; then premier=$p; wait "$p"; else reste="$reste $p"; fi; done
  PIDS="$reste"
}
lancer() {
  local nom="$1" lua="$2" args="$3"; shift 3
  local o="$WORK/runs/$nom"
  rm -rf "${o:?}"; mkdir -p "$o"
  if [ -n "$NV_DE" ]; then cp -R "$WORK/runs/$NV_DE/nvram" "$o/nvram"; NV_DE=""; fi
  if [ -n "$CARTE_DE" ]; then
    case "$CARTE_DE" in /*) cp "$CARTE_DE" "$o/carte.neo" ;; *) cp "$WORK/runs/$CARTE_DE/carte.neo" "$o/carte.neo" ;; esac
    CARTE_DE=""
  fi
  local cle="" jour
  jour="$(date '+%m/%d/%y %a')"
  if [ -n "$CACHE" ] && temoin "$nom" "$args"; then
    cle="$( { echo "$CLE_BASE $jour"; echo "$nom $lua ${BIOS_RUN:-euro}"; echo "${args//"$WORK"/<W>}"; printf '%s\n' "$@"
      [ -d "$o/nvram" ] && (cd "$o/nvram" && find . -type f -exec shasum {} + | sort)
      [ -f "$o/carte.neo" ] && shasum < "$o/carte.neo"; } | shasum -a 256 | cut -c1-32)"
    if [ -s "$CACHE/$cle/rc" ]; then
      rm -rf "${o:?}"; cp -R "$CACHE/$cle" "$o"; REPRIS=$(( REPRIS + 1 )); return
    fi
  fi
  args="${args//@/$o}"
  attendre_place
  ( cd "$o" && date '+%m/%d/%y %a' > dates.txt && env "$@" J_OUT="$o" T_OUT="$o" MS_OUT="$o/ms.tsv" \
      SDL_VIDEODRIVER=dummy SDL_MAC_BACKGROUND_APP=1 \
      mame $args -bios "${BIOS_RUN:-euro}" -video none -sound none -nothrottle -seconds_to_run 400 \
      -nvram_directory "$o/nvram" -cfg_directory "$o/cfg" -skip_gameinfo -autoboot_script "$ICI/$lua" > "$o/mame.log" 2>&1
    echo $? > "$o/rc"; date '+%m/%d/%y %a' >> dates.txt
    # Kept through a copy renamed in one go: two simultaneous `parcours.sh` runs (the mutations)
    # never leave a half-written entry; the second gives up.
    if [ -n "$cle" ] && [ "$(cat "$o/rc")" = 0 ] && [ ! -e "$CACHE/$cle" ] \
       && [ "$(sort -u dates.txt)" = "$jour" ]; then
      # mkdir is atomic: a single writer per key. An mv onto a directory already there would go
      # inside it.
      t="$CACHE/.$cle.$$"   # $$: this `parcours.sh` run (BASHPID does not exist under macOS's bash 3.2)
      mkdir "$CACHE/.$cle.verrou" 2>/dev/null && cp -R "$o" "$t" && mv "$t" "$CACHE/$cle"; rm -rf "$t"
    fi ) &
  PIDS="$PIDS $!"
}
REPRIS=0
NOTRE="aof -rompath $R"
SNK="aof -rompath $ROMS"
PZ="puzzledp -rompath $R"
MS="neogeo -hashpath $HASHPATH -rompath $R;$ROMS -cart1 b2b -cart2 puzzledp"
MS3="neogeo -hashpath $HASHPATH -rompath $R;$ROMS -cart1 b2b -cart2 puzzledp -cart3 aof"
# A single cartridge on the MV-6F: the machine that has SELECT ("Next Game"), and kof98, ncombat
# without copying their romset.
MS_AOF="neogeo -hashpath $HASHPATH -rompath $R;$ROMS -cart1 aof"
MS_K98="neogeo -hashpath $HASHPATH -rompath $R;$ROMS -cart1 kof98"
MS_NC="neogeo -hashpath $HASHPATH -rompath $R;$ROMS -cart1 ncombat"
MS_MSLUG="neogeo -hashpath $HASHPATH -rompath $R;$ROMS -cart1 mslug"
MS_WH2="neogeo -hashpath $HASHPATH -rompath $R;$ROMS -cart1 wh2"
MS_SS="neogeo -hashpath $HASHPATH -rompath $R;$ROMS -cart1 ssideki"
AES_SNK="aes -cart aof -hashpath $HASHPATH -rompath $R/aes;$ROMS"
AES_SNK_PZ="aes -cart puzzledp -hashpath $HASHPATH -rompath $R/aes;$ROMS"
AES_SNK_K98="aes -cart kof98 -hashpath $HASHPATH -rompath $R/aes;$ROMS"
WAV="-wavwrite @/son.wav"
MENU_TEST="J_TESTS=2337-2376"

# The runs of each scene; each run only runs once.
runs_de() {
  case "$1" in
    boot-ecran|calendrier) echo boot ;;
    boot-saut) echo "boot boot-a" ;;
    carte) echo "boot carte" ;;
    demo-son) echo "demo demo-snk" ;;
    partie-start|fin-demo) echo "demo partie" ;;
    partie-credit) echo "demo partie partie2" ;;
    fin-titre) echo "partie partie2" ;;
    scores) echo "scores-a scores-a0 scores-b scores-b0" ;;
    dip-temps) echo "temps0 temps1" ;;
    dip-langue) echo "editeur langue" ;;
    region) echo "editeur region" ;;
    autotests) echo autotests ;;
    tests-sauvegarde) echo "tests-sauv-set tests-sauv" ;;
    jukebox) echo jukebox ;;
    menu-hud) echo menu ;;
    menu-reprise|menu-son) echo "menu partie" ;;
    cheats) echo "cheats partie" ;;
    restart) echo "restart boot" ;;
    ms-demo) echo "ms-demo pz-demo" ;;
    ms-select) echo "ms-select pz-titre" ;;
    ms-garde) echo "ms-select ms-garde" ;;
    aes-bascule) echo "aes-set aes-demo boot" ;;
    aes-demo) echo "aes-demo aes-snk demo" ;;
    aes-start) echo "aes-start aes-demo" ;;
    aes-menu) echo "aes-start aes-snk" ;;
    aes-piece) echo "aes-piece aes-demo" ;;
    aes-retour) echo "aes-retour demo partie" ;;
    dip-defauts) echo "dip-def temps0 temps1" ;;
    dip-mmss) echo "temps-nc0 temps-nc1" ;;
    dip-fois) echo "fois0 fois1" ;;
    region-europe) echo "demo demo-snk demo-snk-us" ;;
    region-japon) echo "region demo-snk-jp demo-snk-us" ;;
    region-usa) echo "region-us demo-snk-us demo-snk-jp demo-snk" ;;
    autotests-palette) echo autotests-pal ;;
    autotests-vram) echo autotests-vram ;;
    autotests-backup) echo autotests-bram ;;
    tests-entrees) echo tests-entrees ;;
    tests-barres) echo tests-barres ;;
    tests-grille) echo tests-grille ;;
    jukebox-pas) echo jukebox-b ;;
    jukebox-stop) echo "jukebox-b jukebox-b0" ;;
    cheats-off) echo "cheats-off partie" ;;
    partie-p2) echo "partie-p2 partie-p2-snk partie" ;;
    carte-sauve) echo "carte-sauve carte-sauve-snk carte-relue carte-relue-snk carte-neuve" ;;
    ms-select-p2) echo "ms-select-p2 aof-titre" ;;
    aes-ms-select) echo "aes-ms-set aes-ms-select aes-snk-pz" ;;
    aes-pause) echo "aes-m1-set aes-pause aes-snk-pause" ;;
    aes-logo) echo "aes-k98-set aes-logo aes-snk-kof98" ;;
    aes-logo-fin) echo "aes-k98-set aes-logo-fin" ;;
    aes-fin) echo "aes-set aes-histoire aes-snk-histoire demo" ;;
    aes-texte) echo "aes-set aes-histoire aes-snk-histoire" ;;
    depart-force|piece-son) echo "piece-seule piece-seule-snk" ;;
    ms-seule) echo "ms-seule ms-seule0" ;;
    jukebox-repete) echo jukebox-b0 ;;
    partie-p2-joint) echo "p2-joint p2-joint-snk partie" ;;
    carte-chercher) echo "carte-sauve-snk cop-ch44 cop-ch44-snk cop-ch66 cop-ch66-snk" ;;
    carte-supprimer) echo "carte-sauve-snk cop-supp cop-supp-snk cop-supp-relu cop-supp-relu-snk carte-relue-snk" ;;
    carte-nom) echo "carte-sauve-snk cop-nom cop-nom-snk cop-nomlu cop-nomlu-snk" ;;
    tests-p2|tests-dip) echo tests-entrees2 ;;
    dip-sans-donnees) echo "nosd langue" ;;
    gs-compte) echo "gs-65 partie temps1" ;;
    gs-defauts) echo "gs-def gs-65 partie temps1" ;;
    gs-choix) echo "gs-langue editeur langue" ;;
    gs-mmss) echo "gs-nc temps-nc0 temps-nc1" ;;
    gs-fois) echo "gs-pz fois0 fois1" ;;
    gs-sans-donnees) echo "gs-nosd gs-65" ;;
    gs-banque) echo "gs-banque gs-65" ;;
    me-ecran|me-goto|me-octet|me-ligne|me-page|me-repete) echo me-nav ;;
    me-poke) echo "me-poke partie" ;;
    me-gel|me-liste) echo "me-gel partie" ;;
    me-degel) echo "me-degel partie" ;;
    me-borne) echo me-borne ;;
    bf-editeur) echo "bf-dip bf-dip-libre" ;;
    bf-banque) echo "bf-ms bf-ms-libre" ;;
    bf-tests) echo "bf-tests bf-tests-libre" ;;
    bf-jukebox) echo "bf-juke bf-juke-libre" ;;
    sans-cartouche) echo sc-mv1 ;;
    flash-cart) echo fc ;;
    aes-scores) echo "aes-sc-a aes-sc-a0 aes-sc-b aes-sc-b0" ;;
    scores-gel) echo "sg-a-on sg-a-off sg-b-meme sg-b-saut sg-b-gel" ;;
    cm-liste|cm-libres) echo cm-liste ;;
    cm-effacer) echo "carte-sauve-snk cm-effacer cop-supp-snk cm-eff-relu cop-supp-relu-snk carte-relue-snk" ;;
    cm-annuler) echo "carte-sauve-snk cm-annuler" ;;
    cm-formater) echo "carte-sauve-snk cm-formater cop-fmt-snk" ;;
    cm-non-formatee) echo cm-neuve ;;
    cm-sans-carte) echo cm-sans ;;
    cm-protegee) echo cm-prot ;;
    cm-insertion) echo cm-insertion ;;
    bf-carte) echo "bf-carte bf-carte-libre" ;;
    bo-ecran) echo bo-ecran ;;
    ab-ecran) echo ab-ecran ;;
    bo-free-play) echo "bo-set-fp bo-fp bo-snk-fp bo-set-0 bo-dm0" ;;
    bo-fp-p2) echo "bo-set-fp bo-fp-p2 bo-snk-p2 bo-fp" ;;
    bo-fp-joint) echo "bo-set-fp bo-fp-joint bo-snk-joint bo-fp" ;;
    bo-no-continue) echo "bo-set-nc bo-nc partie2 bo-cont" ;;
    bo-demo-muette) echo "bo-set-dm bo-dm bo-set-0 bo-dm0" ;;
    bo-aes) echo "bo-set-aes bo-aes aes-set bo-aes-cont aes-histoire" ;;
    bf-borne) echo "bf-borne bf-borne-libre" ;;
    cheats-vies) echo "cv-on cv-temoin" ;;
    bo-cd-menu) echo "bo-set-cd bo-cd-menu cheats" ;;
    bo-cd-gel) echo "bo-set-cd bo-cd-gel bo-cd-gel-on" ;;
    dip-free-play) echo "df-t df-t0 df-p1 df-snk-t df-snk-t0" ;;
    dip-fp-p2) echo "df-p2 df-p1" ;;
    dip-fp-refus) echo "df-off df-t0" ;;
    dip-fp-chaud) echo "df-chaud df-froid df-t df-t0" ;;
    dip-fp-reglage) echo "bo-set-fp dfr bo-set-0 bo-dm0" ;;
    dip-fp-cabinet) echo df-cab ;;
    dip-setting) echo "ds ds0 ds-bascule" ;;
    geste-boot) echo "gb gb0 gb-sel gb-adapt gb-a" ;;
    geste-jeu) echo "gj gj0 gj-sel gj-adapt gj-a" ;;
    geste-partie) echo "gp-aof gp-mslug gp-samsho4 gp-ssideki gj" ;;
    demo-ssideki) echo "ss-notre ss-snk" ;;
    japon-intitules) echo "ij-notre ij-snk" ;;
    gs-japon) echo "gsj-ss gsu-ss" ;;
    gs-japon-garde) echo "gsj-bs gsu-bs" ;;
    crc-fixe) echo crc-aof ;;
    crc-banques) echo crc-ms2 ;;
    crc-miroir) echo crc-miroir ;;
    crc-flottant) echo crc-flottant ;;
    bf-crc) echo "bf-crc bf-crc-libre" ;;
    bf-crc-banque) echo "bf-crc-ms bf-crc-ms-libre" ;;
    dd-effet) echo "dd-1 dd-0" ;;
    dd-connu) echo "dd-set dd-connu" ;;
    dd-off) echo "dd-off dd-0off" ;;
    dip-gel) echo "gel gel0 gel-snk" ;;
    dip-gel-off) echo "gel0 ds0" ;;
    dip-gel-boot) echo "gelb gelb-snk" ;;
    dip-mahjong) echo "mj-b mj-0 mj-b-snk mj-0-snk mj-touches mj-chaud" ;;
    dip-mj-off) echo "mjo-b mjo-0 mjo-touches" ;;
    dip-4p) echo "4p 4p0 4p-snk 4p0-snk 4p-chaud" ;;
    dip-4p-off) echo "4p0 4p-retour" ;;
    af-tir) echo "af-t af-m af-r" ;;
    af-sauve) echo "af-t af-sauve af-sauve0" ;;
    af-off) echo "af-t af-sauve0 af-r af-relu" ;;
    af-mahjong) echo "mjaf mjaf0 mjoaf" ;;
    boot-graphismes) echo "bg bg-brouille bg-uni bg-uni-brouille" ;;
    ms-son-slot2) echo "s2-son s2-son-snk" ;;
    dip-vierge) echo "vierge-set-n vierge-set-c vierge-0 vierge-n vierge-c vierge-set-m vierge-m0 vierge-m" ;;
    dip-corrompue) echo "vierge-set-c vierge-set-0 corrompue corrompue-0" ;;
    tests-mahjong) echo "tests-mj" ;;
    pn-menu-on) echo "pn-on" ;;
    pn-menu-off) echo "pn-off" ;;
    pn-valeur) echo "pn-val" ;;
    pn-verrou) echo "pn-v-on pn-v-off" ;;
    pn-jeu) echo "pn-j pn-j0" ;;
    jukebox-veille) echo "veille veille-0" ;;
    cm-copier) echo "cp-vide cp-cible cp-renonce" ;;
    alpha-trajectoire) for d in h hd d bd b bg g hg; do echo "at-$d at-$d-snk"; done ;;
    howto-preisle2) echo "hp hp-snk" ;;
  esac
}
RUNS=" "
for s in $SCENES; do for r in $(runs_de "$s"); do case "$RUNS" in *" $r "*) ;; *) RUNS="$RUNS$r " ;; esac; done; done
veut() { case "$RUNS" in *" $1 "*) return 0 ;; esac; return 1; }

mkdir -p "$WORK/runs"
T0=$(date +%s)
# The longest first.
veut partie && lancer partie son.lua "$NOTRE $WAV" J_HACHES=1-9000 J_ZONES="146,10,173,29;62,17,142,22" J_IMAGES=450,1400 J_SUIVRE=108406:1 J_FIN=9000
veut demo && lancer demo son.lua "$NOTRE $WAV" J_PIECE=0 J_START=0 J_HACHES=1-9000 J_IMAGES=450,1400 J_FIN=9000
veut partie2 && lancer partie2 son.lua "$NOTRE" J_APPUIS=420:piece:8 J_HACHES=6000-9000 J_IMAGES=450 J_FIN=9000
veut scores-a && lancer scores-a son.lua "$PZ" J_PIECE=0 J_START=0 J_POSER=1500@100028=0012D680120F1708 J_FIN=7000
veut scores-a0 && lancer scores-a0 son.lua "$PZ" J_PIECE=0 J_START=0 J_FIN=7000
veut demo-snk && lancer demo-snk son.lua "$SNK $WAV" J_PIECE=0 J_START=0 J_HACHES=1-3600 J_FIN=3600
# The ssideki demo (demo-ssideki scene): without input; the SNK witness hands over around frame
# 966.
veut ss-notre && lancer ss-notre son.lua "$MS_SS" J_PIECE=0 J_START=0 J_HACHES=1-3600 J_FIN=3600
veut ss-snk && lancer ss-snk son.lua "ssideki -rompath $ROMS" J_PIECE=0 J_START=0 J_HACHES=1-3600 J_FIN=3600
# The sine table (record --ref-sinus). alpham2: "up" 1600-1624, then the direction 1640-1659;
# two images.
for x in "h|haut" "hd|haut droite" "d|droite" "bd|bas droite" "b|bas" "bg|bas gauche" "g|gauche" "hg|haut gauche"; do
  IFS='|' read -r nom dirs <<< "$x"
  ap="1600:haut:25"; for b in $dirs; do ap="$ap,1640:$b:20"; done
  veut at-$nom && lancer at-$nom son.lua "alpham2 -rompath $R" J_APPUIS=$ap J_IMAGES=1639,1675 J_FIN=1677
  veut at-$nom-snk && lancer at-$nom-snk son.lua "alpham2 -rompath $ROMS" J_APPUIS=$ap J_IMAGES=1639,1675 J_FIN=1677
done
veut hp && lancer hp son.lua "preisle2 -rompath $R" J_HACHES=500-1850 J_IMAGES=1000 J_FIN=1850
veut hp-snk && lancer hp-snk son.lua "preisle2 -rompath $ROMS" J_HACHES=500-1850 J_IMAGES=1000 J_FIN=1850
veut menu && lancer menu son.lua "$NOTRE $WAV" $MENU_TEST J_APPUIS=2380:A J_HACHES=2200-4200 J_IMAGES=2357-2400 J_FIN=4200
veut cheats && lancer cheats son.lua "$NOTRE" $MENU_TEST \
  J_APPUIS=2380:bas,2386:bas,2392:A,2398:bas,2404:A,2410:haut,2416:haut,2422:haut,2428:A \
  J_ZONES="146,10,173,29;62,17,142,22" J_HACHES=2200-4200 J_SUIVRE=108406:1,1092CD:1 J_TEXTE=2427 J_FIN=4200
veut restart && lancer restart son.lua "$NOTRE" $MENU_TEST J_APPUIS=2380:bas,2386:A J_HACHES=2300-3000 J_FIN=3000
veut boot && lancer boot son.lua "$NOTRE" J_PIECE=0 J_START=0 J_HACHES=1-400 J_TEXTE=100 J_IMAGES=100 J_FIN=400
veut boot-a && lancer boot-a son.lua "$NOTRE" J_PIECE=0 J_START=0 J_APPUIS=60:A J_HACHES=1-400 J_IMAGES=100 J_FIN=400
veut carte && lancer carte son.lua "$NOTRE -memc @/carte.neo" J_PIECE=0 J_START=0 J_TEXTE=100 J_IMAGES=100 J_FIN=200
EDIT="J_TESTS=1-260 J_PIECE=0 J_START=0"
veut editeur && lancer editeur son.lua "$NOTRE" $EDIT J_APPUIS=340:START J_REMISE=754 J_FIN=1300
veut langue && lancer langue son.lua "$NOTRE" $EDIT J_APPUIS=270:bas,280:bas,290:droite,340:START J_TEXTE=330 J_REMISE=754 J_FIN=1300
veut region && lancer region son.lua "$NOTRE" $EDIT J_APPUIS=270:gauche,280:gauche,340:START J_TEXTE=330,450 J_REMISE=754 J_HACHES=1-1600 J_FIN=1600
TEMPS="J_TESTS=1-260 J_PIECE=900 J_START=1000 J_IMAGES=3000 J_FIN=3001"
veut temps0 && lancer temps0 son.lua "$NOTRE" $TEMPS J_APPUIS=340:START
# J_HACHES and J_FIN extended for gs-compte: the timers from 65 to 61 (the last J_FIN wins).
veut temps1 && lancer temps1 son.lua "$NOTRE" $TEMPS J_TEXTE=330 J_HACHES=2300-4000 J_ZONES="146,10,173,29" J_FIN=4000 \
  J_APPUIS=270:bas,280:droite,290:droite,300:droite,310:droite,320:droite,340:START
veut autotests && lancer autotests autotests.lua "$NOTRE" T_DEFAUT=work T_ADR=0x108000 T_BIT=3 T_FIN=3000
# aof's first boot, without input: its request 0, then its save; tests-sauv starts again from
# this NVRAM.
veut tests-sauv-set && lancer tests-sauv-set son.lua "$NOTRE" J_PIECE=0 J_START=0 J_FIN=600
veut jukebox && lancer jukebox jukebox.lua "$NOTRE $WAV" J_SEQUENCE="7F 21 25" J_APRES_RAZ=07 J_JEU=500
veut ms-demo && lancer ms-demo multislot.lua "$MS" MS_FIN=2400 MS_CAPT_USER=60
veut ms-select && lancer ms-select multislot.lua "$MS" MS_FIN=1300 MS_CAPT_USER=60 MS_ENTREES=1000:piece,1050:suivant:1
veut ms-garde && lancer ms-garde multislot.lua "$MS" MS_FIN=1300 MS_CAPT_USER=60 MS_ENTREES=1000:piece,1050:suivant:1,1052:suivant:1
veut pz-demo && lancer pz-demo son.lua "$PZ" J_PIECE=0 J_START=0 J_HACHES=1-400 J_FIN=400
veut pz-titre && lancer pz-titre son.lua "$PZ" J_PIECE=400 J_START=0 J_REMISE=60 J_FIN=500
veut aes-snk && BIOS_RUN=asia lancer aes-snk son.lua "$AES_SNK" J_PIECE=0 J_START=1000 J_HACHES=1-2400 J_FIN=2400
# The flip: MODE is the fourth line going up from the first (`dip.s`).
VERS_MODE="270:haut,280:haut,290:haut,300:haut"
if veut aes-set || veut aes-demo || veut aes-start || veut aes-piece || veut aes-retour || veut aes-histoire; then
  lancer aes-set son.lua "$NOTRE" $EDIT J_APPUIS=$VERS_MODE,310:droite,340:START J_TEXTE=330,450 J_FIN=600
fi
# The scores in AES mode: puzzledp put in AES by the editor, the score of the scores scene set
# (and not set), then relaunched.
veut aes-sc-a && lancer aes-sc-a son.lua "$PZ" $EDIT J_APPUIS=$VERS_MODE,310:droite,340:START J_POSER=1500@100028=0012D680120F1708 J_FIN=7000
veut aes-sc-a0 && lancer aes-sc-a0 son.lua "$PZ" $EDIT J_APPUIS=$VERS_MODE,310:droite,340:START J_FIN=7000
# SCORE RESET: "up" six times from the first line of the editor; the clock at 2026-10-01 (a
# Thursday).
VERS_SCORES="270:haut,280:haut,290:haut,300:haut,310:haut,320:haut"
HL="J_AUSSI=$ICI/horloge.lua"
# THE CABINET SETTINGS: "up" seven times from the first line (CABINET SETTINGS), A.
VERS_BORNE="270:haut,276:haut,282:haut,288:haut,294:haut,300:haut,306:haut,320:A"
veut sg-a-on && lancer sg-a-on son.lua "$MS_WH2" $EDIT $HL HL_DATE=2610014 J_APPUIS=$VERS_SCORES,340:START J_TEXTE=335 J_POSER=1500@10E004=535058 J_FIN=6000
veut sg-a-off && lancer sg-a-off son.lua "$MS_WH2" $EDIT $HL HL_DATE=2610014 J_APPUIS=$VERS_SCORES,330:droite,340:START J_TEXTE=335 J_POSER=1500@10E004=535058 J_FIN=6000

# ---- The runs of the coverage (record --ref-couv) ----
# The SNK witnesses of the three regions, the demo without input.
veut demo-snk-jp && BIOS_RUN=japan lancer demo-snk-jp son.lua "$SNK" J_PIECE=0 J_START=0 J_HACHES=1-2200 J_FIN=2200
veut demo-snk-us && BIOS_RUN=us lancer demo-snk-us son.lua "$SNK" J_PIECE=0 J_START=0 J_HACHES=1-2200 J_FIN=2200
veut region-us && lancer region-us son.lua "$NOTRE" $EDIT J_APPUIS=270:gauche,340:START J_TEXTE=330,450 J_HACHES=1-1600 J_FIN=1600
# The editor: the reset to defaults (ROUND TIME 60 → 65, then up twice to RESET TO
# DEFAULTS and A), an MM:SS time (ncombat, PLAY TIME 03:00 → 03:01), a number of times by A
# (puzzledp, CONTINUE INFINITE → WITHOUT: A goes from the maximum to the minimum).
veut dip-def && lancer dip-def son.lua "$NOTRE" $TEMPS J_TEXTE=328,350 \
  J_APPUIS=270:bas,280:droite,290:droite,300:droite,310:droite,320:droite,330:haut,336:haut,342:A,360:START
NC="J_TESTS=1-260 J_PIECE=900 J_START=1000 J_IMAGES=1300,2000,3000 J_FIN=3001"
veut temps-nc0 && lancer temps-nc0 son.lua "$MS_NC" $NC J_APPUIS=340:START
veut temps-nc1 && lancer temps-nc1 son.lua "$MS_NC" $NC J_APPUIS=270:bas,280:droite,340:START J_TEXTE=330
FOIS="J_TESTS=1-260 J_PIECE=900 J_START=1000 J_FIN=9000"
veut fois0 && lancer fois0 son.lua "$PZ" $FOIS J_APPUIS=340:START
veut fois1 && lancer fois1 son.lua "$PZ" $FOIS J_APPUIS=270:bas,280:A,340:START J_TEXTE=330
# The failing self-tests, like 2026-10-21-autotests.tsv (runs pal0, vram-bas, bram).
veut autotests-pal && lancer autotests-pal autotests.lua "$NOTRE" T_DEFAUT=pal T_ADR=0x400A00 T_BIT=5 T_FIN=3000
veut autotests-vram && lancer autotests-vram autotests.lua "$NOTRE" T_DEFAUT=vram T_ADR=0x007123 T_BIT=15 T_FIN=3000
veut autotests-bram && lancer autotests-bram autotests.lua "$NOTRE" T_DEFAUT=bram T_ADR=0xD01234 T_BIT=7 T_FIN=3000
# The screens of the HARDWARE TESTS menu: from the first line of the editor, "up" three times
# leads to HARDWARE TESTS (MODE is at four); A opens it on WORK RAM.
VERS_TESTS="270:haut,280:haut,290:haut,300:A"
# INPUT TEST: each input in turn, TEST included (J_TESTS), then START held 80 frames.
# The mahjong panel page: switch 3 at ON from frame 1, aof's joystick (a joystick is read in
# the three rows at once): A, B, up, START, then START held 80 frames. Switch 3 goes to ON at
# 365, the editor already open: INPUT TEST reads it at its opening (370), and the menus stay
# translated as at theirs, on the joystick (at ON from boot, the joystick would be translated
# like the panel, up as A, A as up).
veut tests-mj && lancer tests-mj son.lua "$NOTRE" J_TESTS=1-260 J_PIECE=0 J_START=0 J_DSW=1:00,365:04 \
  J_APPUIS=$VERS_TESTS,330:bas,340:bas,350:bas,360:bas,370:A,420:A:8,440:B:8,460:haut:8,480:START:8,520:START:80 \
  J_TEXTE=400,424,444,464,484,640 J_FIN=660
veut tests-entrees && lancer tests-entrees son.lua "$NOTRE" J_TESTS=1-260,680-687 J_PIECE=0 J_START=0 \
  J_APPUIS=$VERS_TESTS,330:bas,340:bas,350:bas,360:bas,370:A,420:A:8,440:B:8,460:C:8,480:D:8,500:haut:8,520:bas:8,540:gauche:8,560:droite:8,580:piece:8,600:start2:8,620:START:8,640:deuxA:8,660:service:8,700:START:80 \
  J_TEXTE=365,400,810 J_IMAGES=410,424,444,464,484,504,524,544,564,584,604,624,644,664,684 J_FIN=850
veut tests-barres && lancer tests-barres son.lua "$NOTRE" $EDIT \
  J_APPUIS=$VERS_TESTS,330:bas,340:bas,350:bas,360:bas,370:bas,380:A,430:A,480:START J_TEXTE=375,500 J_IMAGES=420,470 J_FIN=520
# CROSSHATCH at "up" three times from WORK RAM (CARTRIDGE CRC at two, EXIT at one, on
# 2026-10-25); from there, "down" twice leads to EXIT.
veut tests-grille && lancer tests-grille son.lua "$NOTRE" $EDIT \
  J_APPUIS=$VERS_TESTS,330:haut,335:haut,340:haut,350:A,400:START,430:bas,435:bas,440:A J_TEXTE=345,420,470 J_IMAGES=390 J_FIN=500
# The jukebox on the keys: "up" four times from 00 to 07 ($01-$03 skipped), A; right twice
# (27), left (17), right (27), down six times (21), A; B at 900; START, START.
JUKE="270:haut,280:haut,290:A,330:haut,340:haut,350:haut,360:haut,380:A,440:droite,450:droite,470:gauche,480:droite,490:bas,500:bas,510:bas,520:bas,530:bas,540:bas,560:A"
veut jukebox-b && lancer jukebox-b son.lua "$NOTRE $WAV" $EDIT J_APPUIS=$JUKE,900:B,1300:START,1350:START \
  J_TEXTE=320,370,460,475,485,550,1330 J_FIN=1500
# The jukebox's screen saver: code 21 played at 560, then nothing; up at 8000 (the wake-up), up
# at 8100. The veille-0 witness: C tapped at 3000 and 6000, an input without effect in the
# jukebox, which keeps it lit.
VEILLE="$EDIT J_HACHES=7500-8200 J_IMAGES=7600,7800,8050 J_TEXTE=7600,8050,8150 J_FIN=8200"
veut veille && lancer veille son.lua "$NOTRE $WAV" $VEILLE J_APPUIS=$JUKE,8000:haut,8100:haut
veut veille-0 && lancer veille-0 son.lua "$NOTRE $WAV" $VEILLE J_APPUIS=$JUKE,3000:C,6000:C,8000:haut,8100:haut
# Without B, and "up" held 60 frames at 1000: the repeat.
veut jukebox-b0 && lancer jukebox-b0 son.lua "$NOTRE $WAV" $EDIT J_APPUIS=$JUKE,1000:haut:60 J_TEXTE=990,1065 J_FIN=1300
# A cheat set to ON then to OFF in the same pause, RESUME.
veut cheats-off && lancer cheats-off son.lua "$NOTRE" $MENU_TEST \
  J_APPUIS=2380:bas,2386:bas,2392:A,2398:A,2404:haut,2410:haut,2416:A \
  J_ZONES="146,10,173,29;62,17,142,22" J_HACHES=2200-4200 J_SUIVRE=108406:1 J_TEXTE=2395,2401 J_FIN=4200
# Two coins, START P2 at the title: both players start; against the SNK BIOS.
P2="J_PIECE=0 J_START=0 J_APPUIS=400:piece:8,420:piece:8,500:start2:8 J_HACHES=1-3000 J_FIN=3000"
veut partie-p2 && lancer partie-p2 son.lua "$NOTRE" $P2
veut partie-p2-snk && lancer partie-p2-snk son.lua "$SNK" $P2
# A one-player game, then a coin and START P2 during the game: P2 joins.
JOINT="J_APPUIS=1500:piece:8,1600:start2:8 J_HACHES=1-3000 J_FIN=3000"
veut p2-joint && lancer p2-joint son.lua "$NOTRE" $JOINT
veut p2-joint-snk && lancer p2-joint-snk son.lua "$SNK" $JOINT
# A coin at 400, nothing else: the sound of the coin, then the forced start from the title.
veut piece-seule && lancer piece-seule son.lua "$NOTRE $WAV" J_PIECE=400 J_START=0 J_HACHES=1-3000 J_FIN=3000
veut piece-seule-snk && lancer piece-seule-snk son.lua "$SNK $WAV" J_PIECE=400 J_START=0 J_HACHES=1-3000 J_FIN=3000
# A single cartridge on the MV-6F, SELECT at the title (one coin): ignored, deliberate departure
# (`io.s`).
veut ms-seule && lancer ms-seule son.lua "$MS_AOF" J_PIECE=1000 J_START=0 J_APPUIS=1050:select:8 J_HACHES=1000-1500 J_FIN=1500
veut ms-seule0 && lancer ms-seule0 son.lua "$MS_AOF" J_PIECE=1000 J_START=0 J_HACHES=1000-1500 J_FIN=1500
# The memory card: a game lost, MEMORY CARD SAVE (left: YES, then A); read back further down.
SAUVE="J_TIRS=6640-6900:20:gauche;6910-7100:20:A"
veut carte-sauve && lancer carte-sauve son.lua "$NOTRE -memc @/carte.neo" "$SAUVE" J_FIN=7800
veut carte-sauve-snk && lancer carte-sauve-snk son.lua "$SNK -memc @/carte.neo" "$SAUVE" J_FIN=7800
veut carte-neuve && lancer carte-neuve son.lua "$NOTRE -memc @/carte.neo" J_HACHES=1-2500 J_FIN=2500
# SELECT P2 on three cartridges: the previous slot, aof; witness, aof alone at its title.
veut ms-select-p2 && lancer ms-select-p2 multislot.lua "$MS3" MS_FIN=1300 MS_CAPT_USER=60 MS_ENTREES=1000:piece,1050:precedent:1
veut aof-titre && lancer aof-titre son.lua "$NOTRE" J_PIECE=400 J_START=0 J_REMISE=60 J_FIN=500
# The AES mode set by the editor on the MV-6F (its NVRAM is not that of the aof set), then
# relaunched.
veut aes-ms-set && lancer aes-ms-set son.lua "$MS" $EDIT J_APPUIS=$VERS_MODE,310:droite,340:START J_TEXTE=330,450 J_FIN=600
veut aes-m1-set && lancer aes-m1-set son.lua "$MS_AOF" $EDIT J_APPUIS=$VERS_MODE,310:droite,340:START J_TEXTE=330,450 J_FIN=600
veut aes-k98-set && lancer aes-k98-set son.lua "$MS_K98" $EDIT J_APPUIS=$VERS_MODE,310:droite,340:START J_TEXTE=330,450 J_FIN=600
veut aes-snk-pz && BIOS_RUN=asia lancer aes-snk-pz son.lua "$AES_SNK_PZ" J_PIECE=0 J_START=0 J_HACHES=1-2400 J_FIN=2400
veut aes-snk-kof98 && BIOS_RUN=asia lancer aes-snk-kof98 son.lua "$AES_SNK_K98" J_PIECE=0 J_START=0 J_HACHES=1-2000 J_FIN=2000
veut aes-snk-pause && BIOS_RUN=asia lancer aes-snk-pause son.lua "$AES_SNK" J_PIECE=0 J_START=1000 J_APPUIS=5600:select:8 J_HACHES=5500-6700 J_FIN=6700
# A STORY MODE game in AES (down then A at the game's menu), lost without input.
HISTOIRE="J_PIECE=0 J_START=1000 J_APPUIS=1800:bas,1830:A J_ZONES=208,0,303,15"
veut aes-snk-histoire && BIOS_RUN=asia lancer aes-snk-histoire son.lua "$AES_SNK" $HISTOIRE J_HACHES=1-8100 J_FIN=8100
# NO SOFT DIP DATA: the editor on the fixture (above), then START. Witness: the langue run.
veut nosd && lancer nosd son.lua "aof -rompath $NOSD" $EDIT J_APPUIS=340:START J_TEXTE=330 J_REMISE=754 J_FIN=1300
# The INPUT TEST on the MV-6F, the machine that has SELECT ("Next Game", "Previous Game"): P2
# besides A and START, SELECT P1 and P2, then the eight switches, each alone ON 20 frames.
DSW="600:01,620:00,640:02,660:00,680:04,700:00,720:08,740:00,760:10,780:00,800:20,820:00,840:40,860:00,880:80,900:00"
veut tests-entrees2 && lancer tests-entrees2 son.lua "$MS_AOF" J_TESTS=1-260 J_PIECE=0 J_START=0 \
  J_APPUIS=$VERS_TESTS,330:bas,340:bas,350:bas,360:bas,370:A,420:deuxB:8,440:deuxC:8,460:deuxD:8,480:deuxHaut:8,500:deuxBas:8,520:deuxGauche:8,540:deuxDroite:8,560:select:8,580:select2:8,920:START:80 \
  J_DSW=$DSW J_TEXTE=400,1040 J_IMAGES=410,424,444,464,484,504,524,544,564,584,610,650,690,730,770,810,850,890 J_FIN=1060

# ---- The runs of the full in-game menu (record --ref-menu) ----
# The menu opens at 2357 ($MENU_TEST) on RESUME; "up, up" leads to GAME SETTINGS, "up" to
# MEMORY EDITOR (`src/c0/menu.s`). One press every 6 frames, held 3 frames.
CHRONO="J_ZONES=146,10,173,29;62,17,142,22"
VERS_GS="2380:haut,2386:haut,2392:A"
# GAME SETTINGS: ROUND TIME 60 → 65 (right five times, the first line), START, then RESUME
# ("down" twice: MEMORY EDITOR, RESUME). Then the same thing and RESET TO DEFAULTS ("up"
# twice from the first line: RESTART GAME, the reset), A, and "down" twice to see ROUND TIME
# again, which the list has scrolled.
CINQ="2398:droite,2404:droite,2410:droite,2416:droite,2422:droite"
veut gs-65 && lancer gs-65 son.lua "$NOTRE" $MENU_TEST J_APPUIS=$VERS_GS,$CINQ,2428:START,2434:bas,2440:bas,2446:A \
  "$CHRONO" J_HACHES=2200-9000 J_TEXTE=2427 J_FIN=9000
veut gs-def && lancer gs-def son.lua "$NOTRE" $MENU_TEST J_APPUIS=$VERS_GS,$CINQ,2428:haut,2434:haut,2440:A,2446:bas,2452:bas,2458:START,2464:bas,2470:bas,2476:A \
  "$CHRONO" J_HACHES=2200-9000 J_TEXTE=2427,2457 J_FIN=9000
# LANGUAGE → SPANISH (down, right), then RESTART GAME ("up" twice), A: the relaunch at 2430.
veut gs-langue && lancer gs-langue son.lua "$NOTRE" $MENU_TEST J_APPUIS=$VERS_GS,2398:bas,2404:droite,2410:haut,2416:haut,2422:A \
  J_TEXTE=2409 J_REMISE=754 J_FIN=3500
# ncombat (PLAY TIME 03:00 → 03:01, right) and puzzledp (CONTINUE INFINITE → WITHOUT, A), then
# RESTART GAME ("up"), A at 2410: the relaunch at R = 2418 on ncombat and 2417 on puzzledp,
# measured on 2026-10-30 with the table of 98 games. This frame follows the phase of the watchdog wait,
# hence the cycles of the menu since its opening, where `_cheats_trouver` goes through the
# whole table for an absent game: it moved with the reading of the panel, the cheats window
# (2417), the table of 81 games (2418) and that of 98 games (2417 on puzzledp). The inputs after it are those of temps-nc1 and
# fois1, shifted by R (coin at R + 900, START at R + 1000).
veut gs-nc && lancer gs-nc son.lua "$MS_NC" $MENU_TEST J_APPUIS=$VERS_GS,2398:droite,2404:haut,2410:A,3318:piece:8,3418:START:8 \
  J_TEXTE=2403 J_IMAGES=3718,4418,5418 J_FIN=5419
veut gs-pz && lancer gs-pz son.lua "$PZ" $MENU_TEST J_APPUIS=$VERS_GS,2398:A,2404:haut,2410:A,3317:piece:8,3417:START:8 \
  J_TEXTE=2403 J_FIN=11417
# NO SOFT DIP DATA in game, on the two fixtures (above), then START and RESUME.
veut gs-nosd && lancer gs-nosd son.lua "aof -rompath $NOSD" $MENU_TEST J_APPUIS=$VERS_GS,2410:START,2416:bas,2422:bas,2428:A \
  J_TEXTE=2409 J_FIN=2700
veut gs-banque && lancer gs-banque son.lua "aof -rompath $BANQUE" $MENU_TEST J_APPUIS=$VERS_GS,2410:START,2416:bas,2422:bas,2428:A \
  J_TEXTE=2409 J_FIN=2700
# MEMORY EDITOR (`src/c0/memoire.s`). GOTO 108400: C, "up" eight times (the thousands digit,
# 0 → 8), right, "up" four times (the hundreds, 0 → 4), A; then right six times: $108406, the
# seconds of aof's round (`src/c0/cheats.s`).
VERS_ME="2380:haut,2386:A"
GOTO8400="2392:C,2398:haut,2404:haut,2410:haut,2416:haut,2422:haut,2428:haut,2434:haut,2440:haut,2446:droite,2452:haut,2458:haut,2464:haut,2470:haut,2476:A"
SIX="2482:droite,2488:droite,2494:droite,2500:droite,2506:droite,2512:droite"
# The navigation: one line (down), one page (B held, down), "down" held 60 frames; then left,
# up, B held and up; GOTO: right, left (the thousands digit), up, A; GOTO abandoned: up, B.
veut me-nav && lancer me-nav son.lua "$NOTRE" $MENU_TEST J_APPUIS=$VERS_ME,$GOTO8400,$SIX,2518:bas,2526:B:12,2530:bas,2544:bas:60,2612:gauche,2618:haut,2626:B:12,2630:haut,2644:C,2650:droite,2656:gauche,2662:haut,2668:A,2674:C,2680:haut,2686:B \
  J_TEXTE=2481,2517,2523,2541,2609,2617,2623,2641,2673,2691 J_SUIVRE=108400:2,108402:2,108404:2,108406:2,108440:2,108442:2,108444:2,108446:2 J_FIN=2700
# SET VALUE: A, left twice ($60 → $40), up ($41), down ($40), A; then A, up, B: abandoned.
# START, RESUME ("down": RESUME, A).
veut me-poke && lancer me-poke son.lua "$NOTRE" $MENU_TEST \
  J_APPUIS=$VERS_ME,$GOTO8400,$SIX,2518:A,2524:gauche,2530:gauche,2536:haut,2542:bas,2548:A,2554:A,2560:haut,2566:B,2572:START,2578:bas,2584:A \
  "$CHRONO" J_HACHES=2200-4200 J_SUIVRE=108406:1 J_TEXTE=2535,2541,2547,2565,2571 J_FIN=4200
# Two freezes: D on $108406; GOTO 1092CD (P1's life, `cheats.s`) from 8406: up (8 → 9),
# right, down twice (4 → 2), right, down four times (0 → C), right, up seven times (6 → D),
# A; D. Then START, RESUME.
veut me-gel && lancer me-gel son.lua "$NOTRE" $MENU_TEST \
  J_APPUIS=$VERS_ME,$GOTO8400,$SIX,2518:D,2524:C,2530:haut,2536:droite,2542:bas,2548:bas,2554:droite,2560:bas,2566:bas,2572:bas,2578:bas,2584:droite,2590:haut,2596:haut,2602:haut,2608:haut,2614:haut,2620:haut,2626:haut,2632:A,2638:D,2644:START,2650:bas,2656:A \
  "$CHRONO" J_HACHES=2200-4400 J_SUIVRE=108406:1,1092CD:1 J_TEXTE=2643 J_FIN=4400
# One freeze set, RESUME; the menu reopened at 3057 (TEST 3037-3076), MEMORY EDITOR on the same
# cursor, D removes it, RESUME.
veut me-degel && lancer me-degel son.lua "$NOTRE" J_TESTS=2337-2376,3037-3076 \
  J_APPUIS=$VERS_ME,$GOTO8400,$SIX,2518:D,2524:START,2530:bas,2536:A,3080:haut,3086:A,3092:D,3098:START,3104:bas,3110:A \
  "$CHRONO" J_HACHES=2200-5000 J_SUIVRE=108406:1 J_TEXTE=2523,3097 J_FIN=5000
# The BIOS area: GOTO 10FD84 (BIOS_GAME_DIP): down (0 → F), right, down three times (0 → D),
# right, "up" eight times, right, "up" four times, A; then A and D, which do nothing there.
# ---- The floating bus (`bus-flottant.lua` loaded by `son.lua`): each run twice, under the
# model of the hardware then free (the witness). BF_FIN: the last frame before `son.lua` exits.
BFM="J_FLOTTANT=$ICI/bus-flottant.lua BF_OUT=bf.tsv BF_HOTE=1"
for x in "dip|$NOTRE|270:bas,280:droite,290:bas,300:droite,340:START|330|600" \
         "ms|$MS_MSLUG|270:bas,280:bas,290:A,340:START|330|600" \
         "tests|$NOTRE|$VERS_TESTS,330:haut,335:haut,340:haut,350:A,400:START,430:bas,435:bas,440:A,500:START|345,470|700" \
         "crc|$NOTRE|$VERS_TESTS,330:haut,336:haut,342:A,950:START,980:START,1000:START|400,900,990|1100" \
         "crc-ms|$MS_MSLUG|$VERS_TESTS,330:haut,336:haut,342:A,1450:START,1480:START,1500:START|400,1400,1490|1600" \
         "juke|$NOTRE|270:haut,280:haut,290:A,330:haut,380:A,500:START,550:START|320,530|800" \
         "borne|$NOTRE|$VERS_BORNE,330:droite,370:START,390:START|325,385|600"; do
  IFS='|' read -r nom mach app txt fin <<< "$x"
  veut "bf-$nom" && lancer "bf-$nom" son.lua "$mach" $EDIT $BFM BF_FIN=$(( fin - 1 )) \
    J_APPUIS="$app" J_TEXTE="$txt" J_HACHES=1-$fin J_FIN=$fin
  veut "bf-$nom-libre" && lancer "bf-$nom-libre" son.lua "$mach" $EDIT $BFM BF_FIN=$(( fin - 1 )) BF_LIBRE=1 \
    J_APPUIS="$app" J_TEXTE="$txt" J_HACHES=1-$fin J_FIN=$fin
done
# The MV-1 without a cartridge, under the model: 1,500 frames, no input.
veut sc-mv1 && lancer sc-mv1 son.lua "ng_mv1 -rompath $R" $BFM BF_FIN=1499 J_PIECE=0 J_START=0 \
  J_TEXTE=700,1400 J_HACHES=1-1500 J_FIN=1500
# aof silent for its first 30 frames, under the model: 900 frames, no input.
veut fc && lancer fc son.lua "$NOTRE" $BFM BF_ABSENTE=30 BF_FIN=899 J_PIECE=0 J_START=0 \
  J_TEXTE=150 J_HACHES=1-900 J_FIN=900
veut me-borne && lancer me-borne son.lua "$NOTRE" $MENU_TEST \
  J_APPUIS=$VERS_ME,2392:C,2398:bas,2404:droite,2410:bas,2416:bas,2422:bas,2428:droite,2434:haut,2440:haut,2446:haut,2452:haut,2458:haut,2464:haut,2470:haut,2476:haut,2482:droite,2488:haut,2494:haut,2500:haut,2506:haut,2512:A,2518:A,2524:D,2530:START,2536:bas,2542:A \
  J_SUIVRE=10FD84:1 J_TEXTE=2517,2529 J_FIN=2700
# ---- The memory card manager (record --ref-carte): the TEST screen, "up" five times, A.
VERS_CARTE="270:haut,280:haut,290:haut,300:haut,310:haut,320:A"
FIXTURE="$R/cartes/fixture.neo"
# THE COPY: the source in place, C at 360 on 0044-00; the card removed at 400, the other
# inserted at 420 (`carte-echange.lua`, a copy in the run's directory); A at 440, then A at 470
# if overwriting is asked. The game RAM set at 330 at $100000 and $1006BE, read back after.
# cp-renonce: B at 400, the card never changed.
CP="$EDIT J_AUSSI=$ICI/carte-echange.lua J_POSER=330@100000=0123456789ABCDEF,330@1006BE=CAFE J_SUIVRE=100000:2,100002:2,100004:2,100006:2,1006BE:2"
if veut cp-vide; then CARTE_DE=$R/cartes/copie-source.neo; lancer cp-vide son.lua "$NOTRE -memc @/carte.neo" $CP \
  CE_ECHANGE=400:-,420:$R/cartes/copie-vide.neo J_APPUIS=$VERS_CARTE,360:C,440:A,480:START,500:START J_TEXTE=350,380,430,460 J_FIN=600; fi
if veut cp-cible; then CARTE_DE=$R/cartes/copie-source.neo; lancer cp-cible son.lua "$NOTRE -memc @/carte.neo" $CP \
  CE_ECHANGE=400:-,420:$R/cartes/copie-cible.neo J_APPUIS=$VERS_CARTE,360:C,440:A,470:A,510:START,530:START J_TEXTE=380,430,460,490 J_FIN=600; fi
if veut cp-renonce; then CARTE_DE=$R/cartes/copie-source.neo; lancer cp-renonce son.lua "$NOTRE -memc @/carte.neo" $CP \
  J_APPUIS=$VERS_CARTE,360:C,400:B,440:A J_TEXTE=380,420,460 J_FIN=500; fi
QUINZE="360:bas,366:bas,372:bas,378:bas,384:bas,390:bas,396:bas,402:bas,408:bas,414:bas,420:bas,426:bas,432:bas,438:bas,444:bas"
if veut cm-liste; then CARTE_DE=$FIXTURE; lancer cm-liste son.lua "$NOTRE -memc @/carte.neo" $EDIT \
  J_APPUIS=$VERS_CARTE,$QUINZE,470:START,490:START J_TEXTE=350,450,480 J_FIN=700; fi
veut cm-neuve && lancer cm-neuve son.lua "$NOTRE -memc @/carte.neo" $EDIT J_APPUIS=$VERS_CARTE,350:A,360:A J_TEXTE=345,380 J_FIN=420
veut cm-sans && lancer cm-sans son.lua "$NOTRE" $EDIT J_APPUIS=$VERS_CARTE,350:A,370:bas,380:A,400:START J_TEXTE=345,360,390 J_FIN=600
if veut cm-prot; then CARTE_DE=$FIXTURE; lancer cm-prot son.lua "$NOTRE -memc @/carte.neo" $EDIT J_AUSSI=$ICI/carte-protegee.lua \
  CP_PROTEGE=1-100000 J_APPUIS=$VERS_CARTE,350:A,360:A,370:haut,376:haut,382:A,390:A J_TEXTE=345,365,395 J_FIN=420; fi
if veut cm-insertion; then CARTE_DE=$FIXTURE; lancer cm-insertion son.lua "$NOTRE -memc @/carte.neo" $EDIT \
  J_AUSSI=$ICI/carte-protegee.lua CP_ABSENTE=1-399,450-469 J_APPUIS=$VERS_CARTE,430:A,490:A,510:B \
  J_TEXTE=350,420,440,460,480,500,520 J_FIN=540; fi
for libre in "" 1; do
  nom=bf-carte${libre:+-libre}
  if veut $nom; then CARTE_DE=$FIXTURE; lancer $nom son.lua "$NOTRE -memc @/carte.neo" $EDIT $BFM BF_FIN=699 ${libre:+BF_LIBRE=1} \
    J_APPUIS=$VERS_CARTE,350:bas,360:A,370:B,400:START,430:START J_TEXTE=345,410 J_HACHES=1-700 J_FIN=700; fi
done
# ---- The cabinet settings (record --ref-borne): set by the editor, then judged after a
# relaunch (further down).
veut bo-ecran && lancer bo-ecran son.lua "$NOTRE" $EDIT J_APPUIS=$VERS_BORNE,330:droite,340:bas,346:A,352:bas,358:droite,370:START,390:START \
  J_TEXTE=310,325,365,385 J_SUIVRE=D0021D:1 J_FIN=600
# The ABOUT screen: "up" eight times, A.
veut ab-ecran && lancer ab-ecran son.lua "$NOTRE" $EDIT J_APPUIS=${VERS_BORNE%,320:A},312:haut,320:A,360:START,390:START \
  J_TEXTE=316,340,375 J_FIN=600
for x in "0|" "fp|330:droite," "nc|330:bas,340:droite," "dm|330:bas,340:bas,350:droite," "cd|330:bas,338:bas,346:bas,354:droite,"; do
  IFS='|' read -r nom app <<< "$x"
  veut bo-set-$nom && lancer bo-set-$nom son.lua "$NOTRE" $EDIT J_APPUIS=$VERS_BORNE,${app}370:START,390:START J_TEXTE=365 J_FIN=500
done
# The three at ON / ON / OFF, then MODE AES ("down" three times from CABINET SETTINGS, right);
# CABINET SETTINGS reopened ("up" three times, A), A on FREE PLAY, START, START: the relaunch in
# AES mode.
veut bo-set-aes && lancer bo-set-aes son.lua "$NOTRE" $EDIT \
  J_APPUIS=$VERS_BORNE,330:droite,336:bas,342:droite,348:bas,354:droite,370:START,390:bas,396:bas,402:bas,408:droite,414:haut,420:haut,426:haut,432:A,440:A,450:START,470:START \
  J_TEXTE=365,410,445,460 J_FIN=700
# The SNK BIOS in free play (the board switch), the inputs shifted by 567 frames (see the
# header).
FP_SNK="J_DSW=1:40 J_HACHES=1-3700 J_SUIVRE=D00034:1,10FDB4:1 J_FIN=3700"
veut bo-snk-fp && lancer bo-snk-fp son.lua "$SNK" $FP_SNK J_PIECE=0 J_START=1567
veut bo-snk-p2 && lancer bo-snk-p2 son.lua "$SNK" $FP_SNK J_PIECE=0 J_START=0 J_APPUIS=1567:start2:8
veut bo-snk-joint && lancer bo-snk-joint son.lua "$SNK" $FP_SNK J_PIECE=0 J_START=1567 J_APPUIS=2567:start2:8
# The catalogue (cheats-vies scene): mslug2, a coin, START, A every 60 frames and right held,
# except around the menu (TEST 1500-1539); cv-on sets INFINITE LIVES to ON there, cv-temoin
# closes the menu without changing anything.
CV="mslug2 -rompath $R"
CV_E="J_TESTS=1500-1539 J_TIRS=600-1480:60:A,1700-9000:60:A J_ZONES=22,28,56,38 J_HACHES=1500-9000 J_SUIVRE=10FDAF:1,101276:1 J_FIN=9000"
veut cv-on && lancer cv-on son.lua "$CV" $CV_E J_APPUIS=1000:droite:480,1545:bas,1551:bas,1557:A,1563:haut,1569:haut,1575:A,1700:droite:7300 J_TEXTE=1560
veut cv-temoin && lancer cv-temoin son.lua "$CV" $CV_E J_APPUIS=1000:droite:480,1545:A,1700:droite:7300 J_TEXTE=1540
# CHEATS/DEBUG at ON (the default setting, fresh NVRAM): the freeze of bo-cd-gel, to prove that
# setting it acts.
veut bo-cd-gel-on && lancer bo-cd-gel-on son.lua "$NOTRE" J_POSER=2400@10FB08=000184066000 J_ZONES="146,10,173,29" J_HACHES=2200-4200 J_SUIVRE=108406:1,10FB08:2 J_FIN=4200
# The board switches and the gesture without a TEST button, on the MV-2F (record --ref-dip).
MV2="ng_mv2f -hashpath $HASHPATH -rompath $R;$ROMS -cart1 aof"
DF="J_PIECE=0 J_HACHES=1-2400 J_SUIVRE=D00034:1,10FDB4:1,10FDAF:1 J_IMAGES=2000 J_FIN=2400"
veut df-t0 && lancer df-t0 son.lua "$MV2" $DF J_DSW=1:00 J_START=0
veut df-t && lancer df-t son.lua "$MV2" $DF J_DSW=1:40 J_START=0
# The SNK BIOS on the same machine, its original romset: what its demo says at each position of
# the switch.
MV2_SNK="ng_mv2f -hashpath $HASHPATH -rompath $ROMS -cart1 aof"
veut df-snk-t && lancer df-snk-t son.lua "$MV2_SNK" $DF J_DSW=1:40 J_START=0
veut df-snk-t0 && lancer df-snk-t0 son.lua "$MV2_SNK" $DF J_DSW=1:00 J_START=0
veut df-p1 && lancer df-p1 son.lua "$MV2" $DF J_DSW=1:40 J_START=1600
veut df-p2 && lancer df-p2 son.lua "$MV2" $DF J_DSW=1:40 J_START=0 J_APPUIS=1600:start2:8
veut df-off && lancer df-off son.lua "$MV2" $DF J_DSW=1:00 J_START=1600
veut df-chaud && lancer df-chaud son.lua "$MV2" $DF J_DSW=1:00,1200:40 J_START=1600
veut df-froid && lancer df-froid son.lua "$MV2" $DF J_DSW=1:40,1200:00 J_START=1600
veut df-cab && lancer df-cab son.lua "$MV2" $EDIT J_DSW=1:40 J_APPUIS=$VERS_BORNE,330:droite,370:START,390:START \
  J_TEXTE=325,365 J_SUIVRE=D0021D:1 J_FIN=500
veut ds && lancer ds son.lua "$MV2" J_DSW=1:01 J_PIECE=0 J_START=600 J_TEXTE=500,650 J_HACHES=1-1100 J_FIN=1100
# The fix layer at each frame of the exit: a warning of a single frame would show there.
veut ds-bascule && lancer ds-bascule son.lua "$MV2" J_DSW=1:01,550:00 J_PIECE=0 J_START=600 J_TEXTE=500,$(seq -s, 600 650) J_HACHES=1-1100 J_FIN=1100
veut ds0 && lancer ds0 son.lua "$MV2" J_DSW=1:00 J_PIECE=0 J_START=0 J_TEXTE=500 J_HACHES=1-900 J_FIN=900
veut gb-sel && lancer gb-sel son.lua "$MV2" J_DSW=1:00 J_PIECE=0 J_START=0 J_APPUIS=20:select:200 J_TEXTE=300 J_HACHES=1-500 J_FIN=500
veut gj-sel && lancer gj-sel son.lua "$MV2" J_DSW=1:40 J_PIECE=0 J_START=1000 J_APPUIS=1700:select:60 J_TEXTE=1800 J_HACHES=1500-2000 J_FIN=2000
# A game played, without SELECT: four buttons tapped at coprime steps (A+B+C+D fall together),
# START every 400, the directions, right held 120 frames every 600.
GP="J_DSW=1:40 J_PIECE=0 J_START=1000 J_TIRS=1100-6000:13:A,1100-6000:17:B,1100-6000:19:C,1100-6000:23:D,1100-6000:400:START,1100-6000:29:haut,1100-6000:31:bas,1100-6000:37:gauche J_HACHES=1-6000 J_SUIVRE=10FDAF:1,10F800:2 J_FIN=6000"
for j in aof mslug samsho4 ssideki; do
  veut gp-$j && lancer gp-$j son.lua "ng_mv2f -hashpath $HASHPATH -rompath $R;$ROMS -cart1 $j" $GP \
    J_APPUIS=1500:droite:120,2100:droite:120,2700:droite:120,3300:droite:120,3900:droite:120,4500:droite:120,5100:droite:120
done
veut gb && lancer gb son.lua "$MV2" J_DSW=1:00 J_PIECE=0 J_START=0 J_APPUIS=20:START:200,20:select:200 J_TEXTE=300 J_HACHES=1-500 J_FIN=500
veut gb0 && lancer gb0 son.lua "$MV2" J_DSW=1:00 J_PIECE=0 J_START=0 J_APPUIS=20:START:200 J_TEXTE=300 J_HACHES=1-500 J_FIN=500
veut gj && lancer gj son.lua "$MV2" J_DSW=1:40 J_PIECE=0 J_START=1000 J_APPUIS=1700:START:60,1700:select:60 J_TEXTE=1800 J_HACHES=1500-2000 J_SUIVRE=10F800:2 J_FIN=2000
veut gj0 && lancer gj0 son.lua "$MV2" J_DSW=1:40 J_PIECE=0 J_START=1000 J_APPUIS=1700:START:60 J_TEXTE=1800 J_HACHES=1500-2000 J_FIN=2000
# The BlueRetro adapter at its start-up: brief DOWN, then START, SELECT, A, B, C and D held
# together ~60 frames.
# And the gesture with A held as well, which must open like the gesture alone.
ADAPT_GB="17:bas:3,20:START:60,20:select:60,20:A:60,20:B:60,20:C:60,20:D:60"
ADAPT_GJ="1697:bas:3,1700:START:60,1700:select:60,1700:A:60,1700:B:60,1700:C:60,1700:D:60"
veut gb-adapt && lancer gb-adapt son.lua "$MV2" J_DSW=1:00 J_PIECE=0 J_START=0 J_APPUIS=$ADAPT_GB J_TEXTE=300 J_HACHES=1-500 J_FIN=500
veut gb-a && lancer gb-a son.lua "$MV2" J_DSW=1:00 J_PIECE=0 J_START=0 J_APPUIS=20:START:200,20:select:200,20:A:200 J_TEXTE=300 J_HACHES=1-500 J_FIN=500
# Switches 2, 3 and 8 (record --ref-dip28). THE FREEZE: aof in free play (switch 7), START at
# 1600, switch 8 at ON from 2000 to 2300; no other input, so that the resumption is compared
# with the run without freeze.
GEL="J_PIECE=0 J_START=1600 J_HACHES=1600-2800 J_SUIVRE=10FDAF:1 J_FIN=2800"
veut gel && lancer gel son.lua "$MV2" $GEL J_DSW=1:40,2000:C0,2300:40
veut gel0 && lancer gel0 son.lua "$MV2" $GEL J_DSW=1:40
veut gel-snk && lancer gel-snk son.lua "$MV2_SNK" $GEL J_DSW=1:40,2000:C0,2300:40
# At boot: switch 8 at ON from frame 1, at OFF at 1000.
veut gelb && lancer gelb son.lua "$MV2" J_DSW=1:80,1000:00 J_PIECE=0 J_START=0 J_TEXTE=500 J_HACHES=1-1700 J_FIN=1700
veut gelb-snk && lancer gelb-snk son.lua "$MV2_SNK" J_DSW=1:80,1000:00 J_PIECE=0 J_START=0 J_TEXTE=500 J_HACHES=1-1700 J_FIN=1700
# THE MAHJONG PANEL: MAME's janshin machine (neogeo_mj, a panel on P1, no joystick), the witness
# under the Japanese SNK BIOS, the only one MAME gives it by default. Coin at 1500, START of the
# panel at 1600; B at 1700, on the mode choice screen (A or B).
MJ="janshin -hashpath $HASHPATH -rompath $R;$ROMS"
MJ_SNK="janshin -hashpath $HASHPATH -rompath $ROMS"
MJE="J_PIECE=1500 J_START=0 J_HACHES=1690-2100 J_SUIVRE=10FD94:1 J_FIN=2100"
veut mj-b && lancer mj-b son.lua "$MJ" $MJE J_DSW=1:04 J_APPUIS=1600:mjStart:8,1700:mjB:6
veut mj-0 && lancer mj-0 son.lua "$MJ" $MJE J_DSW=1:04 J_APPUIS=1600:mjStart:8
veut mj-b-snk && BIOS_RUN=japan lancer mj-b-snk son.lua "$MJ_SNK" $MJE J_DSW=1:04 J_APPUIS=1600:mjStart:8,1700:mjB:6
veut mj-0-snk && BIOS_RUN=japan lancer mj-0-snk son.lua "$MJ_SNK" $MJE J_DSW=1:04 J_APPUIS=1600:mjStart:8
veut mjo-b && lancer mjo-b son.lua "$MJ" $MJE J_DSW=1:00 J_APPUIS=1600:mjStart:8,1700:mjB:6
veut mjo-0 && lancer mjo-0 son.lua "$MJ" $MJE J_DSW=1:00 J_APPUIS=1600:mjStart:8
# Each key of the panel alone, 10 frames, every 40 frames from 1900, then A+H+PON and A+B
# (TOUCHES_MJ, the judge derives the same instants from it); the bytes of P1 and of the edges
# recorded at each frame.
TOUCHES_MJ="1600:mjStart:8"; t=1900
for k in A B C D E F G H I J K L M N Pon Chi Kan Ron Reach; do TOUCHES_MJ="$TOUCHES_MJ,$t:mj$k:10"; t=$((t + 40)); done
TOUCHES_MJ="$TOUCHES_MJ,2660:mjA:10,2660:mjH:10,2660:mjPon:10,2700:mjA:10,2700:mjB:10"
MJT="J_PIECE=1500 J_START=0 J_APPUIS=$TOUCHES_MJ J_SUIVRE=10FD94:1,10FD95:1,10FD96:1,10FD97:1,10FDA1:1,10FDA2:1,10FDA3:1 J_FIN=2740"
veut mj-touches && lancer mj-touches son.lua "$MJ" $MJT J_DSW=1:04
veut mjo-touches && lancer mjo-touches son.lua "$MJ" $MJT J_DSW=1:00
# Flipped in demo (aof, MV-2F): read back at the coin.
veut mj-chaud && lancer mj-chaud son.lua "$MV2" J_DSW=1:00,1000:04 J_PIECE=1500 J_START=0 J_SUIVRE=10FD94:1 J_FIN=1700
# SWITCH 2: kizuna on the MV-2F, the witness under the Japanese SNK BIOS (the European one does
# not read it, record).
MV2K="ng_mv2f -hashpath $HASHPATH -rompath $R;$ROMS -cart1 kizuna"
MV2K_SNK="ng_mv2f -hashpath $HASHPATH -rompath $ROMS -cart1 kizuna"
P4E="J_PIECE=0 J_START=0 J_IMAGES=900,1460 J_SUIVRE=10FEF8:1 J_FIN=1500"
veut 4p && lancer 4p son.lua "$MV2K" $P4E J_DSW=1:02
veut 4p0 && lancer 4p0 son.lua "$MV2K" $P4E J_DSW=1:00
veut 4p-snk && BIOS_RUN=japan lancer 4p-snk son.lua "$MV2K_SNK" $P4E J_DSW=1:02
veut 4p0-snk && BIOS_RUN=japan lancer 4p0-snk son.lua "$MV2K_SNK" $P4E J_DSW=1:00
veut 4p-chaud && lancer 4p-chaud son.lua "$MV2K" J_DSW=1:00,1000:02 J_PIECE=1500 J_START=0 J_SUIVRE=10FEF8:1 J_FIN=1700
veut 4p-retour && lancer 4p-retour son.lua "$MV2K" J_DSW=1:02,1000:00 J_PIECE=1500 J_START=0 J_SUIVRE=10FEF8:1 J_FIN=1700
# THE AUTOFIRE (record --ref-af): viewpoin, the in-game menu, AUTOFIRE, a key on BUTTON A
# (af_nav), RESUME; A held, or tapped in the pattern of 15 shots/s. The runs on a kept NVRAM
# (af-sauve, af-sauve0, af-relu) follow, further down.
VP="viewpoin -rompath $R"
af_nav() { echo "1045:haut,1051:haut,1057:haut,1063:A,1069:$1,1075:START,1081:bas,1087:bas,1093:bas,1099:A"; }
AF_X="J_TESTS=1000-1039 J_HACHES=1200-2400 J_SUIVRE=10FD95:1,D001B4:2,D001B6:2 J_TEXTE=1060,1066,1072,1098 J_FIN=2400"
AF_TAPE=$(seq 1300 4 2299 | sed 's/$/:A:2/' | paste -sd, -)
veut af-t && lancer af-t son.lua "$VP" $AF_X J_APPUIS=$(af_nav A),1300:A:1000
veut af-m && lancer af-m son.lua "$VP" $AF_X J_APPUIS=$(af_nav gauche),$AF_TAPE
veut af-r && lancer af-r son.lua "$VP" $AF_X J_APPUIS=$(af_nav gauche),1300:A:1000
# janshin: the "AUTF" entry, NGH $0048 (measured, the entry of slot 0 at $D00124), A at ON,
# 15 shots/s, control $A6.
MJAF="J_PIECE=1500 J_START=0 J_HACHES=1690-2100 J_SUIVRE=10FD94:1,10FD95:1,10FB40:2 J_APPUIS=1600:mjStart:8,1700:mjE:400 J_FIN=2100"
veut mjaf && lancer mjaf son.lua "$MJ" $MJAF J_BRAM=1@D001B0=41555446004811A6 J_DSW=1:04
veut mjaf0 && lancer mjaf0 son.lua "$MJ" $MJAF J_DSW=1:04
veut mjoaf && lancer mjoaf son.lua "$MJ" $MJAF J_BRAM=1@D001B0=41555446004811A6 J_DSW=1:00
# THE MENUS ON THE PANEL (DECISIONS §30; record --ref-panneau). janshin, the editor of the TEST
# button (TEST held at boot, open before 265): from REGION, "up" four times leads to MODE,
# "down" from there to HARDWARE TESTS, "confirm" opens it.
# Switch 3 at ON: E up, F down, A the A button, H right, G left; I, PON, B and C move nothing on
# these lines.
# At OFF: A and H up, B down, E the A button; PON and F move nothing.
PN="J_TESTS=1-260 J_PIECE=0 J_START=0"
PN_ON="270:mjE,280:mjE,290:mjE,300:mjE,310:mjI,320:mjPon,330:mjB,340:mjC,350:mjF,360:mjA"
PN_OFF="270:mjA,280:mjH,290:mjA,300:mjH,310:mjPon,320:mjF,350:mjB,360:mjE"
veut pn-on && lancer pn-on son.lua "$MJ" $PN J_DSW=1:04 J_APPUIS=$PN_ON J_TEXTE=265,305,345,355,400 J_FIN=420
veut pn-off && lancer pn-off son.lua "$MJ" $PN J_DSW=1:00 J_APPUIS=$PN_OFF J_TEXTE=265,305,345,355,400 J_FIN=420
veut pn-val && lancer pn-val son.lua "$MJ" $PN J_DSW=1:04 J_APPUIS=270:mjE,280:mjE,290:mjE,300:mjE,310:mjH,320:mjG \
  J_TEXTE=305,315,325 J_FIN=340
# The lock: the switch flipped at 268, the editor already open; the path of the position at
# opening still leads to the self-tests (read back, E at OFF would be the A button on REGION, A
# at ON too).
veut pn-v-on && lancer pn-v-on son.lua "$MJ" $PN J_DSW=1:04,268:00 J_APPUIS=$PN_ON J_TEXTE=265,305,345,355,400 J_FIN=420
veut pn-v-off && lancer pn-v-off son.lua "$MJ" $PN J_DSW=1:00,268:04 J_APPUIS=$PN_OFF J_TEXTE=265,305,345,355,400 J_FIN=420
# The in-game menu, switch 3 at ON: coin 1500, START 1600 (the mode choice screen), TEST held
# 1650-1689; F (RESTART GAME), E (RESUME), A; then B at 1800, or nothing (pn-j0).
PNJ="J_TESTS=1650-1689 J_PIECE=1500 J_START=0 J_DSW=1:04 J_TEXTE=1700,1710 J_HACHES=1600-2200 J_FIN=2200"
veut pn-j && lancer pn-j son.lua "$MJ" $PNJ J_APPUIS=1600:mjStart:8,1695:mjF,1705:mjE,1715:mjA,1800:mjB:6
veut pn-j0 && lancer pn-j0 son.lua "$MJ" $PNJ J_APPUIS=1600:mjStart:8,1695:mjF,1705:mjE,1715:mjA
# THE GUARANTEES ON UNIBIOS DEFECTS (record --ref-garanties). THE BOOT SCREEN: aof and the
# brouille fixture, VRAM and palettes full of noise at power-on (`vram-hasard.lua`); the
# UniBIOS 4.0 witness on the same romsets (`-bios unibios40`, read in aof's zip: our sp-s2.sp1
# is there, hence WRONG CHECKSUMS under both BIOSes).
BG="J_PIECE=0 J_START=0 J_HACHES=1-700 J_FIN=700 J_AUSSI=$ICI/vram-hasard.lua"
veut bg && lancer bg son.lua "aof -rompath $R" $BG
veut bg-brouille && lancer bg-brouille son.lua "aof -rompath $BROUILLE;$R" $BG
veut bg-uni && BIOS_RUN=unibios40 lancer bg-uni son.lua "aof -rompath $R" $BG
veut bg-uni-brouille && BIOS_RUN=unibios40 lancer bg-uni-brouille son.lua "aof -rompath $BROUILLE;$R" $BG
# THE SOUND OF SLOT 2 without a cartridge in slot 1: the MV-6F, aof as -cart2; the witness, the
# SNK BIOS on the same machine.
veut s2-son && lancer s2-son son.lua "neogeo -hashpath $HASHPATH -rompath $R;$ROMS -cart2 aof $WAV" J_PIECE=0 J_START=0 J_FIN=3600
veut s2-son-snk && lancer s2-son-snk son.lua "neogeo -hashpath $HASHPATH -rompath $ROMS -cart2 aof $WAV" J_PIECE=0 J_START=0 J_FIN=3600
# THE NEVER-INITIALISED ENTRY: two NVRAMs set by J_BRAM at the end of the demo (the game has had
# its request 0), then relaunched further down on the path of temps1. vierge-set-n: slot 0
# carries NGH $0202 at block 0, the eight soft-DIP blocks and the eight names are arbitrary;
# vierge-set-c: the table keeps aof at block 0, its soft-DIP block is arbitrary. The bytes: the
# two times outside BCD ($9999), the count and the number of times at $FF, the ten choices at
# $0F.
VIERGE="99999999FFFF0F0F0F0F0F0F0F0F0F0F"
VIERGE8="$VIERGE$VIERGE$VIERGE$VIERGE$VIERGE$VIERGE$VIERGE$VIERGE"
VIERGE_SUIV="J_SUIVRE=D00124:2,D00220:2,D00222:2,D00224:2,D00226:2,D00228:2,D0022A:2,D0022C:2,D0022E:2,D00230:2,D00232:2,D00234:2,D00236:2,D00238:2,D0023A:2,D0023C:2,D0023E:2,D002A0:2"
VIERGE_EDIT="$TEMPS J_TEXTE=250,330 J_APPUIS=270:bas,280:droite,290:droite,300:droite,310:droite,320:droite,340:START $VIERGE_SUIV"
veut vierge-set-n && lancer vierge-set-n son.lua "$NOTRE" J_PIECE=0 J_START=0 J_BRAM=390@D00124=02020000,390@D00220=$VIERGE8,390@D002A0=$VIERGE8 J_FIN=400
veut vierge-set-c && lancer vierge-set-c son.lua "$NOTRE" J_PIECE=0 J_START=0 J_BRAM=390@D00220=$VIERGE J_FIN=400
veut vierge-0 && lancer vierge-0 son.lua "$NOTRE" $VIERGE_EDIT
# mslug, its block in the banked area: `_dip_valider` does not validate it on read-back, the
# editor receives the bytes set.
# CONTINUE ON → OFF like bf-banque; the witness, the same path on a fresh NVRAM.
VIERGE_EDIT_M="$EDIT J_TEXTE=250,330 J_APPUIS=270:bas,280:bas,290:A,340:START $VIERGE_SUIV J_FIN=400"
veut vierge-set-m && lancer vierge-set-m son.lua "$MS_MSLUG" J_PIECE=0 J_START=0 J_BRAM=390@D00220=$VIERGE J_FIN=400
veut vierge-m0 && lancer vierge-m0 son.lua "$MS_MSLUG" $VIERGE_EDIT_M
# dip-corrompue: the same story as vierge-set-c, without the bytes set (the witness).
veut vierge-set-0 && lancer vierge-set-0 son.lua "$NOTRE" J_PIECE=0 J_START=0 J_FIN=400
veut gj-adapt && lancer gj-adapt son.lua "$MV2" J_DSW=1:40 J_PIECE=0 J_START=1000 J_APPUIS=$ADAPT_GJ J_TEXTE=1800 J_HACHES=1500-2000 J_SUIVRE=10F800:2 J_FIN=2000
veut gj-a && lancer gj-a son.lua "$MV2" J_DSW=1:40 J_PIECE=0 J_START=1000 J_APPUIS=1700:START:60,1700:select:60,1700:A:60 J_TEXTE=1800 J_HACHES=1500-2000 J_FIN=2000
# THE LABELS IN THE JAPAN REGION. The TEST screen of the boot: ssideki, REGION → JAPAN (left
# twice), START; the machine restarts (RESET at 349, then a second at 541, the relaunch of the
# game), TEST held from 560 to 1000 reopens the screen, in JAPAN; the raw fix layer at 1100. The
# witness: the Japanese SNK BIOS, the navigation of measured/2026-10-27-intitules-japon.tsv
# (section 1). GAME SETTINGS: the same region set, a coin at 1300, START at 1400, TEST held
# 2000-2039 (the in-game menu), "up" twice, A; the screen at 2100. In USA (left once), the same
# path: the witness of the text.
IJ="J_PIECE=0 J_START=0 J_TESTS=1-260,560-1000 J_APPUIS=270:gauche,280:gauche,340:START J_TEXTE=450,1100 J_TUILES=1100 J_FIN=1100"
veut ij-notre && lancer ij-notre son.lua "ssideki -rompath $R" $IJ
veut ij-snk && BIOS_RUN=japan lancer ij-snk son.lua "ssideki -rompath $ROMS" J_TESTS=1-1000 J_PIECE=0 J_START=0 \
  J_APPUIS=1100:bas,1115:bas,1130:A,1200:bas,1215:A J_TEXTE=1400 J_TUILES=1400 J_FIN=1400
GSJ="J_TESTS=1-260,2000-2039 J_PIECE=0 J_START=0 J_TEXTE=450,2100 J_TUILES=2100 J_FIN=2101"
GSJ_A="340:START,1300:piece:8,1400:START:8,2070:haut,2076:haut,2082:A"
for x in "gsj-ss|ssideki|270:gauche,280:gauche" "gsu-ss|ssideki|270:gauche" "gsj-bs|bstars|270:gauche,280:gauche" "gsu-bs|bstars|270:gauche"; do
  IFS='|' read -r nom j a <<< "$x"
  veut $nom && lancer $nom son.lua "$j -rompath $R" $GSJ J_APPUIS=$a,$GSJ_A
done
# The continue taken, without setting: two coins, START, the game lost, START at 6300.
veut bo-cont && lancer bo-cont son.lua "$NOTRE" J_APPUIS=420:piece:8,6300:START:8 J_HACHES=6000-9000 J_SUIVRE=D00034:1,10FDB6:1 J_FIN=9000
wait
# MAME relaunched on the NVRAM of the AES mode.
PIDS=""
# The never-initialised entry: the two NVRAMs set further up.
if veut vierge-n; then NV_DE=vierge-set-n; lancer vierge-n son.lua "$NOTRE" $VIERGE_EDIT; fi
if veut tests-sauv; then NV_DE=tests-sauv-set; lancer tests-sauv autotests.lua "$NOTRE" T_FIN=1200; fi
if veut vierge-c; then NV_DE=vierge-set-c; lancer vierge-c son.lua "$NOTRE" $VIERGE_EDIT; fi
if veut vierge-m; then NV_DE=vierge-set-m; lancer vierge-m son.lua "$MS_MSLUG" $VIERGE_EDIT_M; fi
# The corrupted entry WITHOUT the editor (DECISIONS §23 pt 5): coin at 900, START at 1000, like
# temps0.
CORROMPUE="J_PIECE=900 J_START=1000 J_HACHES=1000-3000 J_IMAGES=3000 J_SUIVRE=D00220:2,10FD84:2,10FD86:2,10FD88:2,10FD8A:2,10FD8C:2,10FD8E:2,10FD90:2,10FD92:2 J_FIN=3001"
if veut corrompue; then NV_DE=vierge-set-c; lancer corrompue son.lua "$NOTRE" $CORROMPUE; fi
if veut corrompue-0; then NV_DE=vierge-set-0; lancer corrompue-0 son.lua "$NOTRE" $CORROMPUE; fi
if veut aes-demo; then NV_DE=aes-set; lancer aes-demo son.lua "$NOTRE" J_PIECE=0 J_START=0 J_HACHES=1-2400 J_TEXTE=100 J_IMAGES=100,1400 J_FIN=2400; fi
if veut aes-start; then NV_DE=aes-set; lancer aes-start son.lua "$NOTRE" J_PIECE=0 J_START=1000 J_HACHES=1-2400 J_IMAGES=1400 J_FIN=2400; fi
if veut aes-piece; then NV_DE=aes-set; lancer aes-piece son.lua "$NOTRE" J_PIECE=1000 J_START=0 J_HACHES=1-2400 J_FIN=2400; fi
if veut aes-retour; then NV_DE=aes-set; lancer aes-retour son.lua "$NOTRE" J_TESTS=1-260 J_PIECE=1100 J_START=1000 \
  J_APPUIS=$VERS_MODE,310:gauche,340:START J_TEXTE=330,450 J_HACHES=1-1400 J_FIN=1400; fi
if veut aes-histoire; then NV_DE=aes-set; lancer aes-histoire son.lua "$NOTRE" $HISTOIRE J_HACHES=1-8800 J_FIN=8800; fi
if veut aes-ms-select; then NV_DE=aes-ms-set; lancer aes-ms-select son.lua "$MS" J_PIECE=0 J_START=0 J_APPUIS=600:select:8 J_HACHES=500-1500 J_FIN=1500; fi
if veut aes-pause; then NV_DE=aes-m1-set; lancer aes-pause son.lua "$MS_AOF" J_PIECE=0 J_START=1000 J_APPUIS=5600:select:8 J_HACHES=5600-6600 J_FIN=6600; fi
# The cabinet settings, MAME relaunched on the editor's NVRAM.
FP_NOT="J_HACHES=1-3100 J_SUIVRE=D00034:1,10FDB4:1 J_FIN=3100"
if veut bo-fp; then NV_DE=bo-set-fp; lancer bo-fp son.lua "$NOTRE" $FP_NOT J_PIECE=0 J_START=1000 J_IMAGES=1400; fi
if veut dfr; then NV_DE=bo-set-fp; lancer dfr son.lua "$NOTRE" $FP_NOT J_DSW=1:00 J_PIECE=0 J_START=1000 J_IMAGES=1400 J_SUIVRE=D00034:1,10FDB4:1,10FDAF:1; fi
if veut bo-fp-p2; then NV_DE=bo-set-fp; lancer bo-fp-p2 son.lua "$NOTRE" $FP_NOT J_PIECE=0 J_START=0 J_APPUIS=1000:start2:8; fi
if veut bo-fp-joint; then NV_DE=bo-set-fp; lancer bo-fp-joint son.lua "$NOTRE" $FP_NOT J_PIECE=0 J_START=1000 J_APPUIS=2000:start2:8; fi
# CHEATS/DEBUG at OFF: the in-game menu (up, down, A: RESUME), then the freeze set in the
# engine's RAM.
if veut bo-cd-menu; then NV_DE=bo-set-cd; lancer bo-cd-menu son.lua "$NOTRE" $MENU_TEST J_APPUIS=2380:haut,2390:bas,2400:A J_TEXTE=2375,2385,2395 J_HACHES=2200-3000 J_FIN=3000; fi
if veut bo-cd-gel; then NV_DE=bo-set-cd; lancer bo-cd-gel son.lua "$NOTRE" J_POSER=2400@10FB08=000184066000 J_ZONES="146,10,173,29" J_HACHES=2200-4200 J_SUIVRE=108406:1,10FB08:2 J_FIN=4200; fi
if veut bo-nc; then NV_DE=bo-set-nc; lancer bo-nc son.lua "$NOTRE" J_APPUIS=420:piece:8,6300:START:8 J_HACHES=6000-9000 J_SUIVRE=D00034:1,10FDB6:1 J_FIN=9000; fi
for x in "bo-dm|bo-set-dm" "bo-dm0|bo-set-0"; do
  IFS='|' read -r nom nv <<< "$x"
  if veut $nom; then NV_DE=$nv; lancer $nom son.lua "$NOTRE $WAV" J_PIECE=3000 J_START=3300 J_HACHES=1-11500 J_IMAGES=1400 J_SUIVRE=D00046:1 J_FIN=11500; fi
done
for x in "bo-aes|bo-set-aes" "bo-aes-cont|aes-set"; do
  IFS='|' read -r nom nv <<< "$x"
  if veut $nom; then NV_DE=$nv; lancer $nom son.lua "$NOTRE $WAV" J_PIECE=0 J_START=1000 J_APPUIS=1800:bas,1830:A,7500:START:8 \
    J_HACHES=1-8800 J_TEXTE=100 J_SUIVRE=10FDB6:1,10FB20:1 J_FIN=8800; fi
done
if veut aes-logo; then NV_DE=aes-k98-set; lancer aes-logo son.lua "$MS_K98" J_PIECE=0 J_START=0 J_HACHES=1-2000 J_FIN=2000; fi
# kof98 played: START, then A every 60 frames through the selection screens; it loses without input,
# game over near frame 14,056 (measured/2026-10-30-aes-logo-fin.tsv).
if veut aes-logo-fin; then NV_DE=aes-k98-set; lancer aes-logo-fin son.lua "$MS_K98" J_PIECE=0 J_START=2500 J_TIRS=2600-7000:60:A J_FIN=16000; fi
# ---- The cartridge CRC32 (record --ref-crc): HARDWARE TESTS, "up" twice, A; three STARTs.
VERS_CRC="$VERS_TESTS,330:haut,336:haut,342:A"
veut crc-aof && lancer crc-aof son.lua "$NOTRE" $EDIT J_APPUIS=$VERS_CRC,950:START,980:START,1000:START \
  J_TEXTE=340,400,$(seq -s, 500 10 940),960,990 J_FIN=1300
veut crc-miroir && lancer crc-miroir son.lua "$NOTRE" $EDIT J_AUSSI=$ICI/crc-miroir.lua J_APPUIS=$VERS_CRC,950:START,980:START,1000:START \
  J_TEXTE=400,940,960,990 J_FIN=1300
veut crc-flottant && lancer crc-flottant son.lua "$NOTRE" $EDIT J_AUSSI=$ICI/crc-flottant.lua J_APPUIS=$VERS_CRC,950:START,980:START,1000:START \
  J_TEXTE=400,940,960,990 J_FIN=1300
veut crc-ms2 && lancer crc-ms2 son.lua "mslug2 -rompath $R" $EDIT J_APPUIS=$VERS_CRC,1900:START,1930:START,1960:START \
  J_TEXTE=400,1100,$(seq -s, 1500 10 1890),1910,1940 J_FIN=2400
# ---- The debug dips: kof94, CABINET SETTINGS ("up" seven times, A), "down" four times: DEBUG
# DIPS, A.
VERS_DD="$VERS_BORNE,330:bas,336:bas,342:bas,348:bas,354:A"
DD="J_HACHES=400-6000 J_ZONES=120,184,215,221 J_SUIVRE=100000:1,D00320:1,10FB22:2 J_FIN=6000"
KOF94="kof94 -rompath $R"
veut dd-0 && lancer dd-0 son.lua "$KOF94" $EDIT J_APPUIS=$VERS_DD,380:START,390:START,400:START J_TEXTE=352,365,385 $DD
veut dd-1 && lancer dd-1 son.lua "$KOF94" $EDIT \
  J_APPUIS=$VERS_DD,360:A,366:bas,372:droite,378:A,384:A,390:START,395:START,400:START J_TEXTE=358,363,381,387,393 $DD
veut dd-off && lancer dd-off son.lua "$KOF94" $EDIT \
  J_APPUIS=$VERS_DD,360:A,366:START,372:haut,378:droite,384:bas,390:A,395:START,400:START J_TEXTE=363,369,381,387,393 $DD
veut dd-0off && lancer dd-0off son.lua "$KOF94" $EDIT \
  J_APPUIS=$VERS_DD,366:START,372:haut,378:droite,384:bas,390:A,395:START,400:START J_TEXTE=369,393 $DD
# kof94's first boot, without input: its request 0, then its save; dd-connu starts again from
# this NVRAM.
veut dd-set && lancer dd-set son.lua "$KOF94" J_PIECE=0 J_START=0 J_FIN=600
# The card of the game, read back by a new boot: MEMORY CARD LOAD, then the game resumed.
if veut carte-relue; then CARTE_DE=carte-sauve; lancer carte-relue son.lua "$NOTRE -memc @/carte.neo" J_HACHES=1-2500 J_FIN=2500; fi
if veut carte-relue-snk; then CARTE_DE=carte-sauve-snk; lancer carte-relue-snk son.lua "$SNK -memc @/carte.neo" J_HACHES=1-2500 J_FIN=2500; fi
# The CARD commands that no aof play session calls, provoked by `forcer.lua` (like
# `carte-diff.sh`), at frame 1200 of the demo, starting from the card that the SNK BIOS saved
# (run carte-sauve-snk), under both BIOSes: search for NGH $0044 and NGH $0066, delete aof's
# save, write the name (16 bytes of the buffer at BIOS_CARD_START).
COP="A_F=1200 A_FIN=1500 A_ENTREE=C00468 A_REMPLIR=107100:40"
# The interface at $10FDC4: the command, then BIOS_CARD_START $00107100, the size $0040, the NGH
# (BIOS_CARD_FCB), sub-save 0 ("CARD", like `carte-diff.sh`).
for x in "ch44 0100000000107100004000440000" "ch66 0100000000107100004000660000" \
         "supp 0400000000107100004000440000" "nom 0600000000107100004000440000" "fmt 0000000000107100004000440000"; do
  set -- $x
  if veut cop-$1; then CARTE_DE=carte-sauve-snk; lancer cop-$1 forcer.lua "$NOTRE -memc @/carte.neo" $COP A_IFACE=$2; fi
  if veut cop-$1-snk; then CARTE_DE=carte-sauve-snk; lancer cop-$1-snk forcer.lua "$SNK -memc @/carte.neo" $COP A_IFACE=$2; fi
done
# The manager on the card that the SNK BIOS saved: delete (A, A), abandon (A, B), format (down,
# A, A).
for x in "effacer|350:A,360:A|345,355,380" "annuler|350:A,360:B|355,380" "formater|350:bas,360:A,370:A|345,365,380"; do
  IFS='|' read -r nom app txt <<< "$x"
  if veut cm-$nom; then CARTE_DE=carte-sauve-snk; lancer cm-$nom son.lua "$NOTRE -memc @/carte.neo" $EDIT \
    J_APPUIS=$VERS_CARTE,$app,400:START,420:START J_TEXTE=$txt J_FIN=600; fi
done
wait
# What a game reads back afterwards: aof relaunched on the card from which the save was deleted;
# the name read back ($07) from the card where it was written, into a buffer that nothing filled.
PIDS=""
if veut cop-supp-relu; then CARTE_DE=cop-supp; lancer cop-supp-relu son.lua "$NOTRE -memc @/carte.neo" J_HACHES=1-2500 J_FIN=2500; fi
if veut cop-supp-relu-snk; then CARTE_DE=cop-supp-snk; lancer cop-supp-relu-snk son.lua "$SNK -memc @/carte.neo" J_HACHES=1-2500 J_FIN=2500; fi
if veut cm-eff-relu; then CARTE_DE=cm-effacer; lancer cm-eff-relu son.lua "$NOTRE -memc @/carte.neo" J_HACHES=1-2500 J_FIN=2500; fi
LU="A_F=1200 A_FIN=1500 A_ENTREE=C00468 A_TAMPON=107100:10 A_IFACE=0700000000107100004000440000"
if veut cop-nomlu; then CARTE_DE=cop-nom; lancer cop-nomlu forcer.lua "$NOTRE -memc @/carte.neo" $LU; fi
if veut cop-nomlu-snk; then CARTE_DE=cop-nom-snk; lancer cop-nomlu-snk forcer.lua "$SNK -memc @/carte.neo" $LU; fi
wait
# The restart of the scores: the NVRAM of the first run, MAME relaunched.
PIDS=""
if veut scores-b; then NV_DE=scores-a; lancer scores-b son.lua "$PZ" J_PIECE=0 J_START=0 J_HACHES=4000-6400 J_IMAGES=4900 J_FIN=6400; fi
if veut scores-b0; then NV_DE=scores-a0; lancer scores-b0 son.lua "$PZ" J_PIECE=0 J_START=0 J_HACHES=4000-6400 J_IMAGES=4900 J_FIN=6400; fi
# SCORE RESET: wh2 relaunched the same day, then 38 days later (2026-11-08, a Sunday).
for x in "sg-b-meme|sg-a-on|2610014" "sg-b-saut|sg-a-on|2611080" "sg-b-gel|sg-a-off|2611080"; do
  IFS='|' read -r nom nv date <<< "$x"
  if veut $nom; then NV_DE=$nv; lancer $nom son.lua "$MS_WH2" $HL HL_DATE=$date J_PIECE=0 J_START=0 J_TEXTE=100 J_HACHES=1-4000 J_FIN=4000; fi
done
for x in aes-sc-b aes-sc-b0; do
  if veut $x; then NV_DE=${x/-b/-a}; lancer $x son.lua "$PZ" J_PIECE=0 J_START=0 J_TEXTE=100 J_HACHES=4000-6400 J_IMAGES=4900 J_FIN=6400; fi
done
# The debug dips of an already registered kof94 (NVRAM of dd-set), under the model of the
# floating bus: the save restored after the editor, then the mask set again, cartridge read
# under REG_CRTFIX only.
if veut dd-connu; then NV_DE=dd-set; lancer dd-connu son.lua "$KOF94" $EDIT $BFM BF_FIN=699 \
  J_APPUIS=$VERS_DD,360:A,366:bas,372:droite,378:A,384:A,390:START,395:START,400:START J_TEXTE=393 \
  J_SUIVRE=100000:1,10FD80:1 J_FIN=700; fi
# viewpoin's autofire kept in backup RAM: MAME relaunched on the NVRAM of af-t, A left at ON or
# set back to OFF.
if veut af-sauve; then NV_DE=af-t; lancer af-sauve son.lua "$VP" $AF_X J_APPUIS=$(af_nav droite),1300:A:1000; fi
if veut af-sauve0; then NV_DE=af-t; lancer af-sauve0 son.lua "$VP" $AF_X J_APPUIS=$(af_nav A),1300:A:1000; fi
wait
PIDS=""
if veut af-relu; then NV_DE=af-sauve0; lancer af-relu son.lua "$VP" $AF_X J_APPUIS=$(af_nav gauche),1300:A:1000; fi
wait
DUREE_RUNS=$(( $(date +%s) - T0 ))

# ---- The judge --------------------------------------------------------------------------------------
# The expected CRCs, outside MAME (`crc-cartouche.py`), for the CRC scenes.
case " $SCENES " in *" crc-"*|*" bf-crc"*)
  python3 -I -B "$ICI/crc-cartouche.py" "$ROMS" aof mslug2 mslug > "$WORK/crc-attendus.tsv" \
    || { echo "crc-cartouche.py en échec" >&2; exit 1; } ;;
esac
python3 -I -B - "$WORK/runs" "$REF" "$SCENES" "$RUNS" "$REF_AES" "$REF_COUV" "$REF_MENU" "$REF_CARTE" "$R/cartes/fixture.neo" "$REF_BORNE" "$REF_CHEATS" "$REF_DIP" "$REF_SSIDEKI" "$REF_CRC" "$WORK/crc-attendus.tsv" "$REF_DIP28" "$REF_AF" "$REF_GAR" "$REF_SINUS" "$REF_PANNEAU" > "$WORK/parcours.txt" <<'PY'
import array, itertools, math, os, re, struct, sys, wave

RUNS, REF, SCENES, LANCES, REF_AES, REF_COUV, REF_MENU, REF_CARTE, FIXTURE = sys.argv[1], sys.argv[2], sys.argv[3].split(), sys.argv[4].split(), sys.argv[5], sys.argv[6], sys.argv[7], sys.argv[8], sys.argv[9]
REF_BORNE, REF_CHEATS, REF_DIP, REF_SSIDEKI = sys.argv[10], sys.argv[11], sys.argv[12], sys.argv[13]
REF_CRC, CRC_ATTENDUS = sys.argv[14], sys.argv[15]
REF_DIP28 = sys.argv[16]
REF_AF = sys.argv[17]
REF_GAR = sys.argv[18]
REF_SINUS = sys.argv[19]
REF_PANNEAU = sys.argv[20]

# The records: scene, quantity, threshold, measurement. Only the threshold judges.
SEUILS = {}
for ref in (REF, REF_AES, REF_COUV, REF_MENU, REF_CARTE, REF_BORNE, REF_CHEATS, REF_DIP, REF_SSIDEKI, REF_CRC, REF_DIP28, REF_AF, REF_GAR, REF_SINUS, REF_PANNEAU):
    for l in open(ref, encoding="utf-8"):
        if l.startswith("#") or not l.strip():
            continue
        c = l.rstrip("\n").split("\t")
        if c[0] == "scene":
            continue
        SEUILS[(c[0], c[1])] = c[2]
def S(scene, g):
    return SEUILS[(scene, g)]
def F(scene, g):
    return float(S(scene, g))

class Run:
    def __init__(self, nom):
        self.nom, self.d = nom, os.path.join(RUNS, nom)
        self.f, self.fix, self.ev, self.tu = {}, {}, [], {}
        p = os.path.join(self.d, "son.txt")
        if os.path.exists(p):
            for l in open(p, encoding="utf-8", errors="replace"):
                m = re.match(r"f(\d+) (.*)", l.rstrip("\n"))
                if not m:
                    continue
                n, r = int(m[1]), m[2]
                if r.startswith("son="):
                    self.f[n] = dict(x.split("=", 1) for x in r.split(" ") if "=" in x)
                elif r.startswith("tu"):
                    mm = re.match(r"tu(\d+) (.*)$", r)
                    if mm:
                        self.tu.setdefault(n, {})[int(mm[1])] = [int(x, 16) for x in mm[2].split()]
                elif r.startswith("fix"):
                    mm = re.match(r"fix(\d+) \|(.*)\|$", r)
                    if mm:
                        self.fix.setdefault(n, {})[int(mm[1])] = mm[2]
                else:
                    self.ev.append((n, r))
    def img(self, n):
        return image(os.path.join(self.d, "f%05d.bin" % n))
    def h(self, n):
        x = self.f.get(n, {}).get("img")
        return int(x) if x is not None else None
    def pauses(self):
        iv, a = [], None
        for n in sorted(self.f):
            if self.f[n].get("cote") == "B":
                if a is None: a = b = n
                elif n == b + 1: b = n
                else: iv.append((a, b)); a = b = n
        if a is not None: iv.append((a, b))
        return iv
    def t(self, n):
        return float(self.f[n]["t"])
    def keyon(self, n0, n1):
        return sum(int(self.f[n][k]) for n in range(n0, n1) if n in self.f for k in ("fm", "aa", "ab"))
    def rms(self, n0, n1):
        return rms(os.path.join(self.d, "son.wav"), self.t(n0), self.t(n1))
    def texte(self, n):
        return "\n".join(self.fix.get(n, {}).get(r, "") for r in range(2, 30))

def image(p):
    a = array.array("I")
    a.frombytes(open(p, "rb").read())
    return a
def rms(p, t0, t1):
    w = wave.open(p)
    r = w.getframerate()
    w.setpos(int(t0 * r))
    d = array.array("h", w.readframes(max(0, int((t1 - t0) * r))))
    return math.sqrt(sum(x * x for x in d) / max(1, len(d)))
K = (1, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53)
def hache(b):
    """The fingerprint of `son.lua` (hache), reproduced exactly."""
    h = 5381
    for i in range(0, len(b) - 63, 64):
        v = struct.unpack_from("<16I", b, i)
        h = (h * 31 + sum(x * k for x, k in zip(v, K))) % 4294967291
    return h
def cases(a, b, y0=0, y1=223, x0=0, x1=319):
    """The 8 × 8 cells where two images differ, within the given rectangle (bounds in pixels, inclusive)."""
    c = set()
    for y in range(y0, y1 + 1):
        o = y * 320
        for x in range(x0, x1 + 1):
            if a[o + x] != b[o + x]:
                c.add((x // 8, y // 8))
    return c
def allumes(a):
    return [i for i, x in enumerate(a) if (x & 255) + ((x >> 8) & 255) + ((x >> 16) & 255) > 24]

class Ecart(Exception):
    pass
def exiger(cond, msg):
    if not cond:
        raise Ecart(msg)

def sain(*noms):
    for nom in noms:
        d = os.path.join(RUNS, nom)
        rc = open(os.path.join(d, "rc")).read().strip() if os.path.exists(os.path.join(d, "rc")) else "?"
        exiger(rc == "0", f"run {nom} : MAME sorti en {rc}")
        log = open(os.path.join(d, "mame.log"), errors="replace").read()
        if "snk" in nom.split("-"):  # the SNK witness runs: demo-snk, aes-snk-*, carte-sauve-snk…
            exiger("WRONG CHECKSUMS" not in log, f"run {nom} : le témoin SNK porte WRONG CHECKSUMS")
        else:
            exiger("WRONG CHECKSUMS" in log, f"run {nom} : pas de WRONG CHECKSUMS, notre image n'est pas chargée")
        for e in ("ERREUR", "DELAI"):
            for fichier in ("son.txt", "jukebox.txt", "autotests.txt"):
                p = os.path.join(d, fichier)
                if os.path.exists(p):
                    for l in open(p, errors="replace"):
                        exiger(not re.match(r"f\d+ " + e, l), f"run {nom} : {l.strip()}")
    return [Run(n) for n in noms]

def pause_apres(run, n0):
    p = [x for x in run.pauses() if x[0] > n0]
    exiger(p, f"{run.nom} : aucune pause après la trame {n0}")
    return p[0]

LIGNE = {}
def dit(*a):
    LIGNE.setdefault("d", []).append(" ".join(str(x) for x in a))

# ---- the scenes ----
def boot_ecran():
    (b,) = sain("boot")
    t = b.texte(100)
    ligne = [r for r, s in b.fix[100].items() if "CLOCK" in s]
    exiger(len(ligne) == 1, "ligne CLOCK introuvable")
    y0 = (ligne[0] - 2) * 8
    a = b.img(100)
    allum = len(allumes(a))
    for y in range(y0, y0 + 16):
        for x in range(320):
            a[y * 320 + x] = 0
    e = hache(a.tobytes())
    dit(f"empreinte {e} (ligne CLOCK y {y0}-{y0 + 15} masquée), {allum} pixels allumés")
    exiger(str(e) == S("boot-ecran", "empreinte"), f"empreinte {e}, relevé {S('boot-ecran', 'empreinte')}")
    for x in ("SPRIXE BIOS", "sprixe.dev/bios", "v0.1 BETA", "SYSTEM ....... MVS", "REGION ....... EUROPE", "CARD ......... NONE", "GAME NGH ..... 0044"):
        exiger(x in t, f"plan fixe sans « {x} »")

def boot_saut():
    b, a = sain("boot", "boot-a")
    fb, fa = b.pauses()[0][1], a.pauses()[0][1]
    dit(f"fin de la pause du boot : {fa} avec A à 60, {fb} sans")
    exiger(fa <= F("boot-saut", "fin_max"), f"pause finie à {fa} avec A")
    exiger(fb >= F("boot-saut", "fin_min"), f"pause finie à {fb} sans A")
    ib, ia = b.img(100), a.img(100)
    al = allumes(ib)
    reste = sum(1 for i in al if ia[i] == ib[i]) / max(1, len(al))
    dit(f"trame 100 : {reste:.3f} des pixels allumés de l'écran de boot restent")
    exiger(reste <= F("boot-saut", "reste_max"), f"l'écran de boot reste ({reste:.3f})")

def calendrier():
    (b,) = sain("boot")
    l = [s for s in b.fix[100].values() if "CLOCK" in s][0]
    m = re.search(r"CLOCK \.+ (\S+ \S+)", l)
    exiger(m, f"ligne CLOCK illisible : {l.strip()}")
    dates = [x.strip().upper() for x in open(os.path.join(b.d, "dates.txt"))]
    dit(f"CLOCK « {m[1]} », hôte {dates}")
    exiger(m[1] in dates, f"CLOCK « {m[1]} », date de l'hôte {dates}")

def carte():
    b, c = sain("boot", "carte")
    lc = [r for r, s in b.fix[100].items() if "CARD" in s][0]
    y0, y1 = (lc - 2) * 8, (lc - 2) * 8 + 15
    d = cases(b.img(100), c.img(100))
    dans = [x for x in d if y0 // 8 <= x[1] <= y1 // 8]
    dit(f"{len(dans)} cases changent sur la ligne CARD, {len(d) - len(dans)} ailleurs")
    exiger(len(d) == len(dans), f"{len(d) - len(dans)} cases changent hors de la ligne CARD")
    exiger(len(dans) >= F("carte", "cases_min"), f"{len(dans)} cases sur la ligne CARD")
    exiger("CARD ......... INSERTED" in c.texte(100), "plan fixe sans « CARD ......... INSERTED »")

def demo_son():
    n, s = sain("demo", "demo-snk")
    rn, rs = n.rms(600, 3600), s.rms(600, 3600)
    kn, ks = n.keyon(600, 3600), s.keyon(600, 3600)
    dit(f"RMS {rn:.0f} / SNK {rs:.0f}, key-on {kn} / SNK {ks}")
    exiger(rs > 0 and ks > 0, "le témoin SNK est muet")
    exiger(rn >= F("demo-son", "rms_ratio_min") * rs, f"RMS {rn / rs:.2f} du témoin")
    exiger(kn >= F("demo-son", "keyon_ratio_min") * ks, f"key-on {kn / ks:.2f} du témoin")

def partie_credit():
    d, p, q = sain("demo", "partie", "partie2")
    t = cases(d.img(450), p.img(450))
    c = cases(p.img(450), q.img(450))
    bas = [x for x in c if x[1] * 8 >= 152]
    dit(f"trame 450 : la pièce change {len(t)} cases (le titre) ; la seconde pièce {len(bas)} cases en bas, {len(c) - len(bas)} ailleurs")
    exiger(len(t) >= F("partie-credit", "titre_min"), f"la pièce ne change que {len(t)} cases")
    exiger(bas, "le compteur de crédits ne change pas à la seconde pièce")
    exiger(len(c) == len(bas), f"{len(c) - len(bas)} cases changent hors du bas")

def partie_start():
    d, p = sain("demo", "partie")
    c = cases(d.img(1400), p.img(1400))
    dit(f"trame 1400 : {len(c)} cases sur 1120 diffèrent de la démo")
    exiger(len(c) >= F("partie-start", "cases_min"), f"{len(c)} cases")

def meilleur_decalage(a, b, n0, n1):
    """The shift D that makes the most frames a[k] == b[k - D] equal, k in [n0, n1)."""
    inv = {}
    for k, v in b.f.items():
        if "img" in v: inv.setdefault(v["img"], []).append(k)
    compte = {}
    for k in range(n0, n1):
        for j in inv.get(a.f.get(k, {}).get("img"), []):
            compte[k - j] = compte.get(k - j, 0) + 1
    return max(compte.items(), key=lambda x: x[1]) if compte else (None, 0)

def fin_demo():
    d, p = sain("demo", "partie")
    D, n = meilleur_decalage(p, d, 3000, 9001)
    exiger(D is not None, "aucune image de la démo après la partie")
    dit(f"après la trame 3000 : {n} trames égales à la démo sans pièce, décalage {D} (la démo reprend à la trame {190 + D} environ)")
    exiger(n >= F("fin-demo", "trames_min"), f"{n} trames égales")

def fin_titre():
    p, q = sain("partie", "partie2")
    titre = {p.f[k]["img"] for k in range(405, 500)}
    n = sum(1 for k in range(6000, 9001) if q.f.get(k, {}).get("img") in titre)
    dit(f"{n} trames du titre après la partie")
    exiger(n >= F("fin-titre", "trames_min"), f"{n} trames du titre")

def scores():
    sain("scores-a", "scores-a0")
    b, b0 = sain("scores-b", "scores-b0")
    exiger(any(x[1].startswith("POSE") for x in Run("scores-a").ev), "pas de pose au run scores-a")
    c = cases(b.img(4900), b0.img(4900))
    l1 = [x for x in c if 48 <= x[1] * 8 <= 79]
    dit(f"trame 4900 : {len(l1)} cases sur la ligne 1ST, {len(c) - len(l1)} ailleurs")
    exiger(len(c) == len(l1), f"{len(c) - len(l1)} cases hors de la ligne 1ST")
    exiger(len(l1) >= F("scores", "cases_min"), f"{len(l1)} cases sur la ligne 1ST")

def dip_temps():
    a, b = sain("temps0", "temps1")
    exiger(re.search(r"ROUND TIME +65", b.texte(330)), "l'éditeur ne montre pas ROUND TIME 65")
    c = cases(a.img(3000), b.img(3000))
    dans = [x for x in c if 18 <= x[0] <= 22 and 1 <= x[1] <= 3]
    dit(f"trame 3000 : {len(dans)} cases changent dans le chronomètre, {len(c) - len(dans)} ailleurs")
    exiger(dans, "le chronomètre ne change pas")
    exiger(len(c) == len(dans), f"{len(c) - len(dans)} cases hors du chronomètre")

def remise_image(run, k):
    p = os.path.join(run.d, "r%05d.bin" % k)
    exiger(os.path.exists(p), f"{run.nom} : pas d'image {k} trames après la remise")
    return image(p)

def dip_langue():
    e, l = sain("editeur", "langue")
    exiger(re.search(r"LANGUAGE +SPANISH", l.texte(330)), "l'éditeur ne montre pas LANGUAGE SPANISH")
    c = cases(remise_image(e, 754), remise_image(l, 754))
    dans = [x for x in c if 152 <= x[1] * 8 <= 215]
    dit(f"{len(dans)} cases changent dans le texte, {len(c) - len(dans)} ailleurs")
    exiger(len(dans) >= F("dip-langue", "cases_min"), f"{len(dans)} cases dans le texte")
    exiger(len(c) - len(dans) <= F("dip-langue", "hors_max"), f"{len(c) - len(dans)} cases hors du texte")

def region():
    e, j = sain("editeur", "region")
    exiger(re.search(r"REGION +JAPAN", j.texte(330)), "l'éditeur ne montre pas REGION JAPAN")
    exiger(any(r == "RESET" and n > 340 for n, r in j.ev), "pas de RESET après START")
    c = cases(remise_image(e, 754), remise_image(j, 754))
    dans = [x for x in c if 128 <= x[1] * 8 <= 215]
    dit(f"{len(dans)} cases changent dans le texte, {len(c) - len(dans)} ailleurs")
    exiger(len(dans) >= F("region", "cases_min"), f"{len(dans)} cases dans le texte")
    exiger("REGION ....... JAPAN" in j.texte(450), "l'écran de boot ne dit pas REGION JAPAN")

def autotests():
    sain("autotests")
    t = open(os.path.join(RUNS, "autotests", "autotests.txt"), errors="replace").read()
    for nom, motif, voulu in (("WORK", "> WORK RAM", "FAIL"), ("PALETTE", "> PALETTE RAM", "OK"),
                              ("VRAM", "> VRAM", "OK"), ("BACKUP", "> BACKUP RAM", "OK")):
        m = re.search(r"^f\d+ RESULTAT " + nom + r" duree=\d+ \|(.*)\|$", t, re.M)
        exiger(m, f"{nom} : pas de résultat")
        exiger(re.search(re.escape(motif) + r"\s+" + voulu, m[1]), f"{nom} : |{m[1].strip()}|, {voulu} attendu")
    m = re.search(r"^f\d+ DETAIL   WORK \|(.*)\|$", t, re.M)
    exiger(m and "AT 00108000" in m[1], f"le détail ne nomme pas $108000 : {m[1].strip() if m else '?'}")
    dit("WORK RAM FAIL AT 00108000, les trois autres OK")

def tests_sauvegarde():
    sain("tests-sauv-set", "tests-sauv")
    t = open(os.path.join(RUNS, "tests-sauv", "autotests.txt"), errors="replace").read()
    for nom in ("WORK", "PALETTE", "VRAM", "BACKUP"):
        exiger(re.search(r"^f\d+ RESULTAT " + nom + r" duree=\d+ \|.*\bOK\b", t, re.M), f"{nom} : pas de OK")
    m = re.search(r"^f(\d+) REMISE zone=(\S+) somme=(\d+) h=(\w+) bloc=(\d+) somme=(\d+) h=(\w+)$", t, re.M)
    exiger(m, "aucune remise au jeu relevée")
    exiger(int(m[5]) < 8, f"le jeu n'a pas de bloc ({m[5]}) : la NVRAM de tests-sauv-set n'a pas servi")
    exiger(int(m[6]) > 0, "bloc vide : la sauvegarde du premier boot n'a pas eu lieu")
    dit(f"remise trame {m[1]} : zone {m[2]} somme {m[3]}, bloc {m[5]} somme {m[6]}")
    exiger(m[4] == m[7], f"zone {m[4]} ≠ bloc {m[7]} : la sauvegarde du jeu a été détruite")

def jukebox():
    sain("jukebox")
    d = os.path.join(RUNS, "jukebox")
    lignes = [l.rstrip("\n").split("\t") for l in open(os.path.join(d, "jukebox.tsv"))][1:]
    fen = {m[1]: tuple(map(float, m.groups()[1:])) for m in
           re.finditer(r"FENETRES (\w+) controle ([\d.]+)-([\d.]+) reponse ([\d.]+)-([\d.]+)", open(os.path.join(d, "jukebox.txt")).read())}
    exiger(len(lignes) == 3, f"{len(lignes)} codes joués, 3 attendus")
    for c in lignes:
        code, ctrl_d, rep_d = c[0], int(c[5]), int(c[7])
        t = fen[code]
        rc, rr = rms(os.path.join(d, "son.wav"), t[0], t[1]), rms(os.path.join(d, "son.wav"), t[2], t[3])
        dit(f"code {code} : RMS {rr:.0f} contre {rc:.0f} au contrôle, déclenchements {rep_d} contre {ctrl_d}")
        exiger(rr >= F("jukebox", "rms_min"), f"code {code} : RMS {rr:.0f}")
        exiger(rr >= F("jukebox", "gain_min") * (rc + 1), f"code {code} : RMS {rr:.0f} contre {rc:.0f}")
        exiger(rep_d > ctrl_d, f"code {code} : déclenchements {rep_d} contre {ctrl_d}")

def menu_cadre(m):
    a, b = pause_apres(m, 1000)
    # The drawing of the frame starts at the first palette written by the BIOS in the pause:
    # before, the BIOS may write to the fix layer for the game (MESS_OUT: its CREDIT counter).
    dessin = [n for n in range(a, b + 1) if int(m.f[n]["palB"]) > 0]
    exiger(dessin, "aucune palette écrite par le BIOS pendant la pause")
    boite = None
    for n in range(dessin[0], b + 1):
        x = m.f[n].get("fixB")
        if x:
            c0, c1, r0, r1 = map(int, re.match(r"(\d+)-(\d+),(\d+)-(\d+)", x).groups())
            boite = (c0, c1, r0, r1) if not boite else (min(boite[0], c0), max(boite[1], c1), min(boite[2], r0), max(boite[3], r1))
    exiger(boite, "le BIOS n'a rien écrit au plan fixe pendant la pause")
    return a, b, boite, dessin[0]

def menu_hud():
    (m,) = sain("menu")
    a, b, (c0, c1, r0, r1), d0 = menu_cadre(m)
    # The fix layer: line r on screen at y = 8 × (r − 2) (two hidden lines at the top).
    dans = lambda x: c0 <= x[0] <= c1 and r0 - 2 <= x[1] <= r1 - 2
    c = cases(m.img(d0 - 1), m.img(b - 1))
    hors = [x for x in c if not dans(x)]
    cadre = (c1 - c0 + 1) * (r1 - r0 + 1)
    dedans = len(c) - len(hors)
    dit(f"pause {a}-{b}, cadre colonnes {c0}-{c1} lignes {r0}-{r1} ; trame {b - 1} contre {d0 - 1} : {dedans}/{cadre} cases du cadre, {len(hors)} hors du cadre {sorted(hors)[:6]}")
    exiger(len(hors) <= F("menu-hud", "hors_max"), f"{len(hors)} cases changent hors du cadre")
    exiger(dedans >= F("menu-hud", "cadre_min") * cadre, f"{dedans} cases du cadre sur {cadre}")

def reprise(m, p):
    a, b = pause_apres(m, 1000)
    pp = [x for x in p.pauses() if x[0] > 1000 and x[0] < 9000 and x[1] - x[0] > 5]
    exiger(not [x for x in pp if x[0] < b + 1600], f"le témoin a une pause : {pp}")
    return b + 1, b - a + 1

def menu_reprise():
    m, p = sain("menu", "partie")
    r, D = reprise(m, p)
    eg = sum(1 for k in range(r, r + 1500) if m.h(k) is not None and m.h(k) == p.h(k - D))
    dit(f"reprise à {r}, pause de {D} trames : {eg}/1500 trames égales au témoin")
    exiger(eg >= F("menu-reprise", "egales_min"), f"{eg} trames égales")

def menu_son():
    m, p = sain("menu", "partie")
    r, D = reprise(m, p)
    rm, rp = m.rms(r + 30, r + 1530), p.rms(r + 30 - D, r + 1530 - D)
    km, kp = m.keyon(r + 30, r + 1530), p.keyon(r + 30 - D, r + 1530 - D)
    dit(f"après la reprise : RMS {rm:.0f} / témoin {rp:.0f}, key-on {km} / témoin {kp}")
    exiger(rp > 0 and kp > 0, "le témoin est muet")
    exiger(rm >= F("menu-son", "rms_ratio_min") * rp, f"RMS {rm / rp:.2f} du témoin")
    exiger(km >= F("menu-son", "keyon_ratio_min") * kp, f"key-on {km / kp:.2f} du témoin")

def cheats():
    c, p = sain("cheats", "partie")
    t = c.texte(2427)
    exiger(re.search(r"INFINITE TIME +ON", t) and re.search(r"P1 INFINITE LIFE +ON", t), "les deux cheats ne sont pas ON au menu")
    r, D = reprise(c, p)
    for z, nom in (("z1", "chronomètre"), ("z2", "barre de vie P1")):
        fige = c.f[r + 300][z] == c.f[r + 1500][z]
        bouge = p.f[r + 300 - D][z] != p.f[r + 1500 - D][z]
        dit(f"{nom} : {'figé' if fige else 'change'} sous cheat, {'change' if bouge else 'figé'} au témoin")
        exiger(fige, f"le {nom} change sous cheat")
        exiger(bouge, f"le {nom} ne change pas au témoin : la scène ne prouve rien")
    # Read back at the end of the frame, a forced cell may carry the value the game has just
    # written (the hit taken, the second counted down) before the engine restores it at the next
    # SYSTEM_IO.
    k60 = sum(1 for k in range(r + 300, r + 1500) if c.f[k].get("m108406") == "60" and c.f[k].get("m1092CD") == "60")
    dit(f"$108406 et $1092CD à $60 sur {k60}/1200 trames")
    exiger(k60 >= F("cheats", "ram_min"), f"$108406 et $1092CD à $60 sur {k60}/1200 trames seulement")

def restart():
    s, b = sain("restart", "boot")
    rs = [n for n, r in s.ev if r == "RESET" and n > 2337]
    exiger(rs, "pas de RESET après RESTART GAME")
    k0 = rs[0]
    eg = sum(1 for k in range(1, 381) if s.h(k0 + k) is not None and s.h(k0 + k) == b.h(k))
    dit(f"RESET à {k0} ; {eg}/380 trames égales à une mise sous tension")
    exiger(eg >= F("restart", "egales_min"), f"{eg} trames égales")

def ms_lignes(nom):
    t = []
    for l in open(os.path.join(RUNS, nom, "ms.tsv"), errors="replace"):
        c = l.rstrip("\n").split("\t")
        if len(c) >= 7 and c[0].isdigit():
            t.append((int(c[0]), c[2], c[3], c[4], c[5], c[6]))
    return t
def ms_remises(nom):
    return [(n, sl, re.search(r"demande=(\w+)", note)[1]) for n, g, a, v, sl, note in ms_lignes(nom) if g == "R" and a == "000122"]

def ms_demo():
    sain("ms-demo")
    (z,) = sain("pz-demo")
    rem = [x for x in ms_remises("ms-demo") if x[0] > 300]
    exiger(rem and rem[0][1] == "01" and rem[0][2] == "02", f"pas de démo du slot 1 : {rem}")
    n = rem[0][0]
    cap = os.path.join(RUNS, "ms-demo", "f%05d.bin" % (n + 60))
    exiger(os.path.exists(cap), "pas de capture après la remise")
    rz = max(k for k, e in z.ev if e == "REMISE" and k < 300)
    e = str(hache(open(cap, "rb").read()))
    ok = [k for k in range(rz + 50, rz + 71) if z.f.get(k, {}).get("img") == e]
    dit(f"remise au slot 1 en démo à {n} ; image +60 = puzzledp seul aux trames {ok[:3]}… (remise {rz})")
    exiger(ok, "l'image après le passage n'est pas la démo de puzzledp")

def ms_capture_select(nom):
    rem = [x for x in ms_remises(nom) if x[0] > 1040]
    exiger(rem and rem[0][1] == "01" and rem[0][2] == "03", f"{nom} : pas de remise au slot 1 en titre : {rem}")
    cap = os.path.join(RUNS, nom, "f%05d.bin" % (rem[0][0] + 60))
    exiger(os.path.exists(cap), f"{nom} : pas de capture")
    return image(cap)

def ms_select():
    sain("ms-select")
    (z,) = sain("pz-titre")
    c = cases(ms_capture_select("ms-select"), remise_image(z, 60))
    dit(f"{len(c)} cases diffèrent du titre de puzzledp seul : {sorted(c)}")
    exiger(len(c) <= F("ms-select", "cases_max"), f"{len(c)} cases")

def ms_garde():
    sain("ms-select", "ms-garde")
    l = ms_lignes("ms-garde")
    de = [n for n, g, a, v, sl, note in l if g == "R" and a == "00012E" and 1040 <= n <= 1150 and "bios" in note]
    sl = [n for n, g, a, v, s, note in l if g == "W" and a == "380021" and 1040 <= n <= 1150]
    dit(f"DEMO_END lus {len(de)}, REG_SLOT écrits {len(sl)}")
    exiger(len(de) == 1, f"{len(de)} DEMO_END lus")
    exiger(len(sl) == 1, f"{len(sl)} écritures de REG_SLOT")
    exiger(ms_capture_select("ms-garde") == ms_capture_select("ms-select"), "l'image diffère du SELECT simple")

# ---- the AES mode ----
def premiere_remise(run, apres=0):
    r = [n for n, e in run.ev if e == "REMISE" and n > apres]
    exiger(r, f"{run.nom} : pas de remise après la trame {apres}")
    return r[0]

def ligne_systeme(run, n):
    return [r for r, s in run.fix.get(n, {}).items() if "SYSTEM" in s]

def bascule(run, valeur, autre):
    exiger(re.search(r"MODE +" + valeur, run.texte(330)), f"{run.nom} : l'éditeur ne montre pas MODE {valeur}")
    exiger(any(r == "RESET" and n > 340 for n, r in run.ev), f"{run.nom} : pas de RESET après START")
    exiger("SYSTEM ....... " + valeur in run.texte(450), f"{run.nom} : l'écran de boot ne dit pas SYSTEM {valeur}")

def aes_bascule():
    s, d, b = sain("aes-set", "aes-demo", "boot")
    bascule(s, "AES", "MVS")
    exiger("SYSTEM ....... AES" in d.texte(100), "relancé sur la même NVRAM, l'écran de boot ne dit plus AES")
    ls, lc = ligne_systeme(d, 100), [r for r, x in d.fix[100].items() if "CLOCK" in x]
    exiger(len(ls) == 1 and len(lc) == 1, "lignes SYSTEM et CLOCK introuvables")
    sy, cy = (ls[0] - 2) * 8 // 8, (lc[0] - 2) * 8 // 8
    c = [x for x in cases(b.img(100), d.img(100)) if not cy <= x[1] <= cy + 1]
    dans = [x for x in c if sy <= x[1] <= sy + 1]
    dit(f"écran de boot relancé : {len(dans)} cases changent sur la ligne SYSTEM, {len(c) - len(dans)} ailleurs (CLOCK ignorée)")
    exiger(len(c) == len(dans), f"{len(c) - len(dans)} cases changent hors de la ligne SYSTEM")
    exiger(len(dans) >= F("aes-bascule", "cases_min"), f"{len(dans)} cases sur la ligne SYSTEM")

def aes_demo():
    d, k, m = sain("aes-demo", "aes-snk", "demo")
    r, rk = premiere_remise(d), premiere_remise(k)
    D, n = meilleur_decalage(d, k, r + 1, r + 501)
    dit(f"remise {r} (SNK AES {rk}) : {n}/500 trames du témoin SNK AES, décalage {D}")
    exiger(D is not None and n >= F("aes-demo", "snk_min"), f"{n} trames du témoin SNK AES")
    Dm, nm = meilleur_decalage(d, m, r + 1, r + 501)
    dit(f"contre la démo du mode MVS : {nm}/500 trames égales au meilleur décalage ({Dm})")
    exiger(nm <= F("aes-demo", "mvs_max"), f"{nm} trames sont celles de la démo MVS")

def aes_start():
    s, d = sain("aes-start", "aes-demo")
    c = cases(d.img(1400), s.img(1400))
    dit(f"trame 1400 : {len(c)} cases sur 1120 diffèrent de la démo sans START")
    exiger(len(c) >= F("aes-start", "cases_min"), f"{len(c)} cases")

def aes_menu():
    s, k = sain("aes-start", "aes-snk")
    eg = sum(1 for n in range(1030, 2401) if s.h(n) is not None and s.h(n) == k.h(n))
    dit(f"de 1030 à 2400 : {eg}/1371 trames égales au témoin SNK AES après son START")
    exiger(eg >= F("aes-menu", "egales_min"), f"{eg} trames égales")

def aes_piece():
    p, d = sain("aes-piece", "aes-demo")
    eg = sum(1 for n in range(1000, 2401) if p.h(n) is not None and p.h(n) == d.h(n))
    kp, kd = p.keyon(1000, 1300), d.keyon(1000, 1300)
    dit(f"de 1000 à 2400 : {eg}/1401 trames égales à la démo sans pièce ; key-on 1000-1300 {kp} contre {kd}")
    exiger(eg >= F("aes-piece", "egales_min"), f"{eg} trames égales")
    exiger(abs(kp - kd) <= F("aes-piece", "keyon_max"), f"key-on {kp} contre {kd}")

def aes_retour():
    r, m, p = sain("aes-retour", "demo", "partie")
    bascule(r, "MVS", "AES")
    D, n = meilleur_decalage(r, m, 600, 1100)
    dit(f"de 600 à 1099 : {n}/500 trames de la démo MVS, décalage {D}")
    exiger(D is not None and n >= F("aes-retour", "demo_min"), f"{n} trames de la démo MVS")
    titre = {p.f[k]["img"] for k in range(405, 500)}
    t = sum(1 for k in range(1100, 1401) if r.f.get(k, {}).get("img") in titre)
    dit(f"après la pièce de 1100 : {t} trames du titre")
    exiger(t >= F("aes-retour", "titre_min"), f"{t} trames du titre")


# ---- the coverage (record --ref-couv) ----
def meme_instant(a, b, n0, n1):
    return sum(1 for k in range(n0, n1) if a.h(k) is not None and a.h(k) == b.h(k))

def dip_defauts():
    d, t0, t1 = sain("dip-def", "temps0", "temps1")
    exiger(re.search(r"ROUND TIME +65", d.texte(328)), "l'éditeur ne montre pas ROUND TIME 65 avant la remise")
    exiger(re.search(r"ROUND TIME +60", d.texte(350)), "RESET TO DEFAULTS ne rend pas ROUND TIME 60")
    t = cases(t0.img(3000), t1.img(3000))
    c = cases(t0.img(3000), d.img(3000))
    dit(f"trame 3000 : {len(c)} cases diffèrent de l'éditeur quitté sans changement ; ROUND TIME 65 en change {len(t)}")
    exiger(t, "ROUND TIME 65 ne change rien au témoin : la scène ne prouve rien")
    exiger(len(c) <= F("dip-defauts", "cases_max"), f"{len(c)} cases diffèrent après la remise aux défauts")

def dip_mmss():
    a, b = sain("temps-nc0", "temps-nc1")
    exiger(re.search(r"PLAY TIME +03:01", b.texte(330)), "l'éditeur ne montre pas PLAY TIME 03:01")
    for k in (1300, 2000, 3000):
        c = cases(a.img(k), b.img(k))
        # The TIME of ncombat's HUD: "02:56", columns 10-15 of line 26 (y 208-215).
        dans = [x for x in c if 10 <= x[0] <= 15 and x[1] == 26]
        dit(f"trame {k} : {len(dans)} case(s) changent dans le TIME du HUD, {len(c) - len(dans)} ailleurs")
        exiger(dans, f"trame {k} : le TIME du HUD ne change pas")
        exiger(len(c) == len(dans), f"trame {k} : {len(c) - len(dans)} cases hors du TIME")

def dip_fois():
    a, b = sain("fois0", "fois1")
    exiger(re.search(r"CONTINUE +WITHOUT", b.texte(330)), "A ne mène pas CONTINUE de INFINITE à WITHOUT")
    ra, rb = premiere_remise(a, 1001), premiere_remise(b, 1001)
    dit(f"le titre après la partie : trame {rb} sans continue, {ra} avec ({ra - rb} trames d'écran CONTINUE en moins)")
    exiger(ra - rb >= F("dip-fois", "avance_min"), f"la partie sans continue finit {ra - rb} trames plus tôt")

def region_juge(scene, nom, apres, bon, mauvais):
    runs = sain(nom, bon, *mauvais)
    r = premiere_remise(runs[0], apres)
    D, n = meilleur_decalage(runs[0], runs[1], r + 1, r + 1001)
    dit(f"remise {r} : {n}/1000 trames du témoin {bon} (décalage {D})")
    exiger(D is not None and n >= F(scene, "temoin_min"), f"{n} trames du témoin {bon}")
    for m, x in zip(mauvais, runs[2:]):
        Dm, nm = meilleur_decalage(runs[0], x, r + 1, r + 1001)
        dit(f"contre {m} : {nm}/1000 au meilleur décalage")
        exiger(nm <= F(scene, "autre_max"), f"{nm} trames du témoin {m}")

def region_europe():
    region_juge("region-europe", "demo", 0, "demo-snk", ["demo-snk-us"])
def region_japon():
    exiger("REGION ....... JAPAN" in sain("region")[0].texte(450), "l'écran de boot ne dit pas REGION JAPAN")
    region_juge("region-japon", "region", 340, "demo-snk-jp", ["demo-snk-us"])
def region_usa():
    u = sain("region-us")[0]
    exiger(re.search(r"REGION +USA", u.texte(330)), "l'éditeur ne montre pas REGION USA")
    exiger("REGION ....... USA" in u.texte(450), "l'écran de boot ne dit pas REGION USA")
    region_juge("region-usa", "region-us", 340, "demo-snk-us", ["demo-snk-jp", "demo-snk"])

def autotests_defaut(run, fautif, adr):
    sain(run)
    t = open(os.path.join(RUNS, run, "autotests.txt"), errors="replace").read()
    for nom, motif in (("WORK", "> WORK RAM"), ("PALETTE", "> PALETTE RAM"), ("VRAM", "> VRAM"), ("BACKUP", "> BACKUP RAM")):
        m = re.search(r"^f\d+ RESULTAT " + nom + r" duree=\d+ \|(.*)\|$", t, re.M)
        exiger(m, f"{nom} : pas de résultat")
        voulu = "FAIL" if nom == fautif else "OK"
        exiger(re.search(re.escape(motif) + r"\s+" + voulu, m[1]), f"{nom} : |{m[1].strip()}|, {voulu} attendu")
    m = re.search(r"^f\d+ DETAIL   " + fautif + r" \|(.*)\|$", t, re.M)
    exiger(m and "AT " + adr in m[1], f"le détail ne nomme pas {adr} : {m[1].strip() if m else '?'}")
    dit(f"{fautif} FAIL{m[1].rstrip()}, les trois autres OK")
def autotests_palette():
    autotests_defaut("autotests-pal", "PALETTE", "00400A00")
def autotests_vram():
    autotests_defaut("autotests-vram", "VRAM", "00007123")
def autotests_backup():
    autotests_defaut("autotests-bram", "BACKUP", "00D01234")

def tests_entrees():
    (t,) = sain("tests-entrees")
    exiger("HOLD START P1 1 SEC TO EXIT" in t.texte(400), "l'écran INPUT TEST n'est pas ouvert")
    repos = t.img(410)
    vus = {}
    for k, nom in ((424, "A"), (444, "B"), (464, "C"), (484, "D"), (504, "haut"), (524, "bas"), (544, "gauche"),
                   (564, "droite"), (584, "pièce 1"), (604, "START P2"), (624, "START P1"), (644, "A de P2"),
                   (664, "SERVICE"), (684, "TEST")):
        c = set(cases(repos, t.img(k)))
        exiger(c, f"{nom} n'allume rien")
        exiger(len(c) <= F("tests-entrees", "cases_max"), f"{nom} change {len(c)} cases")
        exiger(all(4 <= x[1] <= 16 for x in c), f"{nom} change des cases hors de la table des entrées : {sorted(c)}")
        for autre, d in vus.items():
            exiger(not (c & d), f"{nom} et {autre} allument les mêmes cases")
        vus[nom] = c
    dit(f"{len(vus)} entrées, chacune allume ses cases : " + ", ".join(f"{n} {len(c)}" for n, c in vus.items()))
    exiger("> INPUT TEST" in t.texte(810), "START tenu ne rend pas le menu des tests")

def tests_barres():
    (t,) = sain("tests-barres")
    exiger("> COLOR BARS" in t.texte(375), "la ligne COLOR BARS n'est pas choisie")
    rvb = lambda x: ((x >> 16) & 255, (x >> 8) & 255, x & 255)
    for k, page in ((420, "rouge, vert, bleu"), (470, "blanc")):
        a = t.img(k)
        for b, y in enumerate((56, 104, 152)):  # the three bars, lines 6-11, 12-17, 18-23
            pas = [rvb(a[y * 320 + 40 + 16 * s]) for s in range(16)]
            exiger(pas[0] == (0, 0, 0), f"{page}, barre {b + 1} : le pas 0 n'est pas noir")
            for c in range(3):
                v = [x[c] for x in pas]
                if k == 420 and c != b:
                    exiger(not any(v), f"{page}, barre {b + 1} : composante {c} non nulle")
                else:
                    exiger(all(v[s] < v[s + 1] for s in range(15)), f"{page}, barre {b + 1} : {v}")
        dit(f"trame {k}, page {page} : 3 barres de 15 pas croissants")
    exiger("> COLOR BARS" in t.texte(500), "START ne rend pas le menu des tests")

def tests_grille():
    (t,) = sain("tests-grille")
    exiger("> CROSSHATCH" in t.texte(345), "la ligne CROSSHATCH n'est pas choisie")
    a = t.img(390)
    ecarts = 0
    for row in range(2, 30):
        for col in range(40):
            px = {a[(8 * (row - 2) + dy) * 320 + 8 * col + dx] & 0xFFFFFF for dy in range(8) for dx in range(8)}
            trait = col % 4 == 0 or col == 39 or (row - 2) % 4 == 0 or row == 29
            ecarts += px != ({0xF7F7F7} if trait else {0})
    dit(f"{ecarts} case(s) sur 1 120 hors de la grille attendue (traits blancs colonnes 0, 4 … 36, 39, lignes 2, 6 … 26, 29)")
    exiger(ecarts <= F("tests-grille", "ecarts_max"), f"{ecarts} cases hors de la grille")
    exiger("> CROSSHATCH" in t.texte(420), "START ne rend pas le menu des tests")
    exiger("SOFT DIP SETTINGS" in t.texte(470), "EXIT ne rend pas l'écran TEST")

def code_jukebox(run, n):
    m = re.search(r"SOUND CODE +([0-9A-F]{2})", run.texte(n))
    return m[1] if m else None

def jukebox_pas():
    (j,) = sain("jukebox-b")
    vu = [(n, code_jukebox(j, n)) for n in (320, 370, 460, 475, 485, 550)]
    dit("codes affichés : " + ", ".join(f"{n} {c}" for n, c in vu))
    exiger([c for _, c in vu] == ["00", "07", "27", "17", "27", "21"], "00, 07, 27, 17, 27, 21 attendus")
    exiger("SOFT DIP SETTINGS" in j.texte(1330), "START ne rend pas l'écran TEST")
    exiger([n for n, e in j.ev if e == "REMISE" and n > 1350], "le second START ne lance pas le jeu")

def jukebox_stop():
    j, z = sain("jukebox-b", "jukebox-b0")
    av, ap, temoin = j.rms(600, 900), j.rms(960, 1260), z.rms(960, 1260)
    dit(f"code 21 : RMS {av:.0f} avant B, {ap:.0f} après ; sans B {temoin:.0f}")
    exiger(av >= F("jukebox-stop", "rms_min") and temoin >= F("jukebox-stop", "rms_min"), "le code 21 ne joue pas")
    exiger(ap <= F("jukebox-stop", "ratio_max") * temoin, f"après B, RMS {ap:.0f} contre {temoin:.0f} sans B")

def cheats_off():
    c, p = sain("cheats-off", "partie")
    exiger(re.search(r"INFINITE TIME +ON", c.texte(2395)) and re.search(r"INFINITE TIME +OFF", c.texte(2401)),
           "INFINITE TIME n'est pas passé à ON puis à OFF")
    r, D = reprise(c, p)
    bouge = c.f[r + 300]["z1"] != c.f[r + 1500]["z1"]
    k60 = sum(1 for k in range(r + 300, r + 1500) if c.f[k].get("m108406") == "60")
    dit(f"chronomètre {'change' if bouge else 'figé'} après OFF ; $108406 à $60 sur {k60}/1200 trames")
    exiger(bouge, "le chronomètre reste figé après OFF")
    exiger(k60 <= F("cheats-off", "ram_max"), f"$108406 à $60 sur {k60} trames")

def partie_p2():
    q, s, p = sain("partie-p2", "partie-p2-snk", "partie")
    eg, e1 = meme_instant(q, s, 500, 3000), meme_instant(q, p, 500, 3000)
    dit(f"trames 500-2999 : {eg}/2500 égales au BIOS SNK au même instant ; {e1} égales au START P1 seul")
    exiger(eg >= F("partie-p2", "snk_min"), f"{eg} trames égales au témoin SNK")
    exiger(e1 <= F("partie-p2", "p1_max"), f"{e1} trames égales à la partie à un joueur")

def carte_sauve():
    sain("carte-sauve", "carte-sauve-snk")
    rl, rs, nv = sain("carte-relue", "carte-relue-snk", "carte-neuve")
    eg, e0 = meme_instant(rl, rs, 500, 2500), meme_instant(rl, nv, 500, 2500)
    dit(f"trames 500-2499 : {eg}/2000 égales au BIOS SNK sur sa propre carte ; {e0} égales à une carte neuve")
    exiger(eg >= F("carte-sauve", "snk_min"), f"{eg} trames égales au témoin SNK")
    exiger(e0 <= F("carte-sauve", "neuve_max"), f"{e0} trames égales à une carte neuve : la sauvegarde n'est pas relue")

def ms_select_p2():
    sain("ms-select-p2")
    (z,) = sain("aof-titre")
    rem = [x for x in ms_remises("ms-select-p2") if x[0] > 1040]
    exiger(rem and rem[0][1] == "02" and rem[0][2] == "03", f"pas de remise au slot 2 en titre : {rem}")
    cap = os.path.join(RUNS, "ms-select-p2", "f%05d.bin" % (rem[0][0] + 60))
    exiger(os.path.exists(cap), "pas de capture")
    c = cases(image(cap), remise_image(z, 60))
    dit(f"SELECT P2 : slot 2 (aof) en titre à {rem[0][0]} ; {len(c)} cases diffèrent du titre d'aof seul")
    exiger(len(c) <= F("ms-select-p2", "cases_max"), f"{len(c)} cases")

def aes_ms_select():
    (m,) = sain("aes-ms-set")
    exiger(re.search(r"MODE +AES", m.texte(330)), "l'éditeur de la MV-6F ne montre pas MODE AES")
    s, k = sain("aes-ms-select", "aes-snk-pz")
    sl = [n for n, e in s.ev if e == "SLOT 01" and 600 <= n <= 700]
    ti = [n for n, e in s.ev if e == "user=01/03" and 600 <= n <= 1500]
    exiger(sl, "SELECT en démo AES : pas de passage au slot 1")
    exiger(not ti, f"SELECT en démo AES mène au titre (trame {ti[:1]})")
    D, n = meilleur_decalage(s, k, 600, 1500)
    dit(f"slot 1 à {sl[0]}, demande 2 gardée ; 600-1499 : {n}/900 trames de la démo de puzzledp sous le BIOS AES de SNK (décalage {D})")
    exiger(D is not None and n >= F("aes-ms-select", "snk_min"), f"{n} trames du témoin")

def aes_pause():
    (m,) = sain("aes-m1-set")
    exiger(re.search(r"MODE +AES", m.texte(330)), "l'éditeur de la MV-6F ne montre pas MODE AES")
    a, k = sain("aes-pause", "aes-snk-pause")
    D, n = meilleur_decalage(a, k, 5600, 6600)
    dit(f"SELECT à 5600 en partie : {n}/1000 trames égales au BIOS AES de SNK sous le même SELECT (décalage {D}) — la pause d'aof")
    exiger(D is not None and n >= F("aes-pause", "snk_min"), f"{n} trames égales")

def aes_logo():
    (m,) = sain("aes-k98-set")
    exiger(re.search(r"MODE +AES", m.texte(330)), "l'éditeur ne montre pas MODE AES sur kof98")
    l, k = sain("aes-logo", "aes-snk-kof98")
    d = [n for n, e in l.ev if e == "user=00/01"]
    exiger(d, "kof98 ne reçoit pas la demande 1")
    exiger([n for n, e in k.ev if e == "user=00/01"], "le témoin SNK ne donne pas la demande 1")
    D, n = meilleur_decalage(l, k, d[0], d[0] + 1500)
    dit(f"demande 1 à {d[0]} : {n}/1500 trames du BIOS AES de SNK (décalage {D})")
    exiger(D is not None and n >= F("aes-logo", "snk_min"), f"{n} trames du témoin")

def aes_logo_fin():
    (l,) = sain("aes-logo-fin")
    u = [(n, e) for n, e in l.ev if e.startswith("user=")]
    jeu = [n for n, e in u if e == "user=02/02"]
    exiger(jeu, "kof98 : la partie ne commence pas")
    fin = [n for n, e in u if n > jeu[0] and e == "user=01/02"]
    exiger(fin, "kof98 : pas de démo après la partie")
    redonnee = [n for n, e in u if n > jeu[0] and e == "user=00/01"]
    dit(f"partie à {jeu[0]}, démo à {fin[0]} ; demande 1 après la partie : {redonnee or 'aucune'}")
    exiger(not redonnee, f"la demande 1 redonnée après la partie, trame {redonnee[:1]}")

def aes_fin():
    h, k, m = sain("aes-histoire", "aes-snk-histoire", "demo")
    r = premiere_remise(h, 1001)
    u = [e for n, e in h.ev if n == r and e.startswith("user=")]
    exiger(u == ["user=01/02"], f"après le game over : {u}, la démo (01/02) attendue")
    D, n = meilleur_decalage(h, k, r + 1, r + 501)
    Dm, nm = meilleur_decalage(h, m, r + 1, r + 501)
    dit(f"game over, démo à {r} : {n}/500 trames du BIOS AES de SNK après le sien (décalage {D}) ; {nm} de la démo MVS")
    exiger(D is not None and n >= F("aes-fin", "snk_min"), f"{n} trames du témoin")
    exiger(nm <= F("aes-fin", "mvs_max"), f"{nm} trames de la démo MVS")

def aes_texte():
    h, k = sain("aes-histoire", "aes-snk-histoire")
    vus = {k.f[n]["z1"] for n in range(3845, 4100)}
    n = sum(1 for x in range(3845, 4100) if h.f[x]["z1"] in vus)
    avant = {k.f[x]["z1"] for x in range(1000, 3845)}
    n0 = sum(1 for x in range(1000, 3845) if h.f[x]["z1"] in avant)
    # The held states (≥ 10 frames of a same image of the area): the messages, outside the
    # animation frames, which the scrolling of the background behind rarely makes equal from one
    # BIOS to the other.
    tous = avant | vus
    etats = []
    for v, g in itertools.groupby(range(3845, 4100), lambda x: h.f[x]["z1"]):
        g = list(g)
        if len(g) >= 10:
            etats.append((g[0], len(g), v in tous))
    hors = [e for e in etats if not e[2]]
    dit(f"le message de P2 (x 208-303, y 0-15) : {n}/255 trames du combat montrent une image du témoin SNK AES ; {n0}/2845 avant le combat ; "
        f"{len(etats)} états tenus, {len(hors)} absents du témoin {[(a, b) for a, b, _ in hors]}")
    exiger(n >= F("aes-texte", "trames_min"), f"{n}/255 trames : « INSERT COIN » là où le BIOS AES de SNK fait dire « PUSH START »")
    exiger(len(hors) <= F("aes-texte", "etats_hors_max"), f"{len(hors)} messages tenus que le BIOS AES de SNK n'affiche pas (« INSERT COIN »)")

def depart_force():
    p, s = sain("piece-seule", "piece-seule-snk")
    r = premiere_remise(p, 300)
    d = [n for n, e in p.ev if e == "user=02/03"]
    ds = [n for n, e in s.ev if e == "user=02/03"]
    exiger(d and ds, f"pas de départ forcé : {d[:1]} / SNK {ds[:1]}")
    D, n = meilleur_decalage(p, s, d[0], d[0] + 800)
    dit(f"titre à {r}, départ forcé à {d[0]} ({d[0] - r} trames) ; SNK à {ds[0]} ; {n}/800 trames suivantes égales au témoin (décalage {D})")
    exiger(abs((d[0] - r) - F("depart-force", "trames")) <= F("depart-force", "tolerance"), f"départ {d[0] - r} trames après le titre")
    exiger(D is not None and n >= F("depart-force", "snk_min"), f"{n} trames égales au témoin")

def piece_son():
    p, s = sain("piece-seule", "piece-seule-snk")
    r = premiere_remise(p, 300)
    D, n = meilleur_decalage(p, s, r, r + 400)
    exiger(D is not None, "le titre ne ressemble pas à celui du témoin")
    rp, rs = p.rms(r, r + 56), s.rms(r - D, r + 56 - D)
    code = [n for n in range(r, r + 30) if "J7F" in p.f[n]["son"].split(",")]
    dit(f"titre à {r} (SNK {r - D}) : RMS {rp:.0f} contre {rs:.0f} sur 56 trames ; le jeu écrit $7F à {code[:1]}")
    exiger(rs > 0, "le témoin est muet")
    exiger(rp >= F("piece-son", "rms_ratio_min") * rs, f"RMS {rp / rs:.2f} du témoin")

def ms_seule():
    a, b = sain("ms-seule", "ms-seule0")
    eg = meme_instant(a, b, 1050, 1500)
    dit(f"SELECT au titre, cartouche seule : {eg}/450 trames égales au titre sans SELECT")
    exiger(eg >= F("ms-seule", "egales_min"), f"{eg} trames égales")

def partie_p2_joint():
    q, s, p = sain("p2-joint", "p2-joint-snk", "partie")
    eg, e1 = meme_instant(q, s, 1600, 3000), meme_instant(q, p, 1600, 3000)
    dit(f"trames 1600-2999 : {eg}/1400 égales au BIOS SNK au même instant ; {e1} égales à la partie sans P2")
    exiger(eg >= F("partie-p2-joint", "snk_min"), f"{eg} trames égales au témoin SNK")
    exiger(e1 <= F("partie-p2-joint", "seul_max"), f"{e1} trames égales à la partie sans P2")

def jukebox_repete():
    (j,) = sain("jukebox-b0")
    a, b = code_jukebox(j, 990), code_jukebox(j, 1065)
    exiger(a and b, "code illisible")
    pas = int(b, 16) - int(a, 16)
    dit(f"« haut » tenu 60 trames : {a} → {b}, {pas} crans")
    exiger(pas >= F("jukebox-repete", "crans_min"), f"{pas} crans")

# ---- the coverage, second batch: CARD forced, INPUT TEST of P2 and of the switches,
# NO SOFT DIP DATA ----
def forcer_sortie(nom):
    """The output of `forcer.lua`: the interface after the call, the buffer, and the run's card."""
    t = open(os.path.join(RUNS, nom, "o.txt"), errors="replace").read()
    exiger(re.search(r"retour apres \d+ trames", t), f"{nom} : CARD ne rend pas la main")
    ap = re.search(r"apres: ([0-9A-F ]+)", t)
    tp = re.search(r"tampon: ([0-9A-F]+)", t)
    carte = open(os.path.join(RUNS, nom, "carte.neo"), "rb").read()
    return ap[1].split() if ap else None, tp[1] if tp else None, carte

def octets(a, b):
    return sum(1 for x, y in zip(a, b) if x != y) + abs(len(a) - len(b))

def carte_chercher():
    sain("carte-sauve-snk", "cop-ch44", "cop-ch44-snk", "cop-ch66", "cop-ch66-snk")
    vu = {}
    for ngh in ("44", "66"):
        a, _, ca = forcer_sortie(f"cop-ch{ngh}")
        b, _, cb = forcer_sortie(f"cop-ch{ngh}-snk")
        d = octets(a, b)
        dit(f"NGH $00{ngh} : interface après {' '.join(a)} ; BIOS SNK {' '.join(b)} ; {d} octet(s) différent(s)")
        exiger(d <= F("carte-chercher", "octets_max"), f"NGH $00{ngh} : {d} octets de l'interface diffèrent du BIOS SNK")
        exiger(ca == cb, f"NGH $00{ngh} : la carte diffère de celle du BIOS SNK (la recherche n'écrit pas)")
        vu[ngh] = a
    # BIOS_CARD_SUB ($10FDD0, bytes 12-13 of the interface): the mask of the sub-saves.
    exiger(vu["44"][12:14] != vu["66"][12:14], "le masque est le même pour un NGH présent et un NGH absent : la scène ne prouve rien")

def carte_supprimer():
    sain("carte-sauve-snk", "cop-supp", "cop-supp-snk")
    r, s, z = sain("cop-supp-relu", "cop-supp-relu-snk", "carte-relue-snk")
    _, _, ca = forcer_sortie("cop-supp")
    _, _, cb = forcer_sortie("cop-supp-snk")
    depart = open(os.path.join(RUNS, "carte-sauve-snk", "carte.neo"), "rb").read()
    d, c0 = octets(ca, cb), octets(cb, depart)
    dit(f"après la suppression : {d} octet(s) de la carte diffèrent du BIOS SNK ; la suppression SNK en change {c0}")
    exiger(c0 > 0, "la suppression du BIOS SNK ne change pas la carte : la scène ne prouve rien")
    exiger(d <= F("carte-supprimer", "octets_max"), f"{d} octets de la carte diffèrent du BIOS SNK")
    eg, es = meme_instant(r, s, 500, 2500), meme_instant(r, z, 500, 2500)
    dit(f"aof relancé sur la carte : {eg}/2000 trames égales au BIOS SNK sur la sienne ; {es} égales à la carte sauvegardée relue")
    exiger(eg >= F("carte-supprimer", "snk_min"), f"{eg} trames égales au témoin SNK")
    exiger(es <= F("carte-supprimer", "sauve_max"), f"{es} trames égales à la carte où la sauvegarde est encore : elle n'est pas supprimée")

def carte_nom():
    sain("carte-sauve-snk", "cop-nom", "cop-nom-snk", "cop-nomlu", "cop-nomlu-snk")
    _, _, ca = forcer_sortie("cop-nom")
    _, _, cb = forcer_sortie("cop-nom-snk")
    depart = open(os.path.join(RUNS, "carte-sauve-snk", "carte.neo"), "rb").read()
    d, c0 = octets(ca, cb), octets(cb, depart)
    dit(f"le nom écrit : {d} octet(s) de la carte diffèrent du BIOS SNK ; l'écriture SNK en change {c0}")
    exiger(c0 > 0, "l'écriture du nom par le BIOS SNK ne change pas la carte : la scène ne prouve rien")
    exiger(d <= F("carte-nom", "octets_max"), f"{d} octets de la carte diffèrent du BIOS SNK")
    a, ta, _ = forcer_sortie("cop-nomlu")
    b, tb, _ = forcer_sortie("cop-nomlu-snk")
    # The pattern of `forcer.lua` (A_REMPLIR): its first 16 bytes are the written name.
    nom = "".join("%02X" % ((i * 7 + 0x31) & 0xFF) for i in range(16))
    dit(f"le nom relu : tampon {ta}, réponse ${a[2]} ; BIOS SNK {tb}, ${b[2]} ; écrit {nom}")
    exiger(tb == nom, "le BIOS SNK ne relit pas le nom écrit : la scène ne prouve rien")
    exiger(ta == tb and a == b, "le nom relu ou la réponse diffèrent du BIOS SNK")

# The INPUT TEST: the cell of each element, read in the table of `src/c0/tests.s` (ELEM: column,
# fix layer line, text); on screen, the cell (column, line − 2).
def elem(col, ligne, txt):
    return {(col + i, ligne - 2) for i in range(len(txt))}

def entrees_juge(scene, t, plan):
    repos = t.img(410)
    hors = 0
    for k, nom, voulu in plan:
        c = set(cases(repos, t.img(k)))
        h = c ^ voulu
        dit(f"{nom} (trame {k}) : {len(c & voulu)}/{len(voulu)} cases de l'élément, {len(h)} hors")
        exiger(c & voulu == voulu, f"{nom} n'allume pas son élément")
        hors += len(h)
    exiger(hors <= F(scene, "cases_hors_max"), f"{hors} cases changent hors des éléments")

def tests_p2():
    (t,) = sain("tests-entrees2")
    exiger("HOLD START P1 1 SEC TO EXIT" in t.texte(400), "l'écran INPUT TEST n'est pas ouvert")
    entrees_juge("tests-p2", t, [
        (424, "B de P2", elem(28, 9, "B")), (444, "C de P2", elem(30, 9, "C")), (464, "D de P2", elem(32, 9, "D")),
        (484, "haut de P2", elem(7, 9, "UP")), (504, "bas de P2", elem(10, 9, "DOWN")),
        (524, "gauche de P2", elem(15, 9, "LEFT")), (544, "droite de P2", elem(20, 9, "RIGHT")),
        (564, "SELECT P1", elem(13, 11, "SELECT")), (584, "SELECT P2", elem(13, 12, "SELECT"))])
    exiger("> INPUT TEST" in t.texte(1040), "START tenu ne rend pas le menu des tests")

def tests_dip():
    (t,) = sain("tests-entrees2")
    exiger("HOLD START P1 1 SEC TO EXIT" in t.texte(400), "l'écran INPUT TEST n'est pas ouvert")
    exiger(len([e for n, e in t.ev if e.startswith("DSW ")]) == 16, "les commutateurs n'ont pas été posés")
    entrees_juge("tests-dip", t, [(610 + 40 * k, f"commutateur {k + 1} (bit {k})", elem(9 + 2 * k, 18, str(k + 1))) for k in range(8)])

def dip_sans_donnees():
    n, l = sain("nosd", "langue")
    tn, tl = n.texte(330), l.texte(330)
    exiger("ROUND TIME" in tl, "l'éditeur du témoin n'a pas de ROUND TIME : la scène ne prouve rien")
    exiger("SOFT DIP SETTINGS" in tn and "NO SOFT DIP DATA" in tn, "l'éditeur ne dit pas NO SOFT DIP DATA")
    # The list: lines 7 to 27 of the fix layer (`dip.s`, CASE_LIGNE; 8 to 26 before 2026-10-24).
    ln = [n.fix[330].get(r, "").strip() for r in range(7, 28)]
    ll = [l.fix[330].get(r, "").strip() for r in range(7, 28)]
    ln, ll = [x for x in ln if x], [x for x in ll if x]
    dit(f"fixture : {len(ln)} lignes ({' / '.join(ln)}) ; témoin : {len(ll)} lignes")
    exiger(len(ln) <= F("dip-sans-donnees", "lignes_max"), f"{len(ln)} lignes : des réglages sont lus d'un bloc refusé")
    exiger(not [x for x in ln if "ROUND TIME" in x], "la fixture montre ROUND TIME")
    exiger([k for k, e in n.ev if e == "REMISE" and k > 340], "START ne rend pas la main au jeu")

# ---- the full in-game menu: GAME SETTINGS and MEMORY EDITOR (record --ref-menu) ----
def apres_pause(run):
    a, b = pause_apres(run, 1000)
    return b + 1
def chrono_65(p, t1):
    """The images of aof's timer that only show with ROUND TIME 65: those of temps1 (65 set in the boot
    editor) that the witness run (60) never shows — the values 61 to 65. Only those that last at least two
    frames: a second lasts ~60, and an image of the transition from one digit to the next, seen for a single
    frame, can be missing from the witness run through the phase alone — measured on 2026-10-25: the transition
    from 52 to 51 (frame 3818 of temps1), absent from partie, counted one "61-65" frame in gs-def on an image
    30 cycles per frame longer."""
    from collections import Counter
    n1 = Counter(t1.f[n]["z1"] for n in t1.f if "z1" in t1.f[n])
    h = {z for z, k in n1.items() if k >= 2} - {p.f[n]["z1"] for n in p.f if "z1" in p.f[n]}
    exiger(h, "temps1 ne montre aucun chronomètre que le témoin n'ait pas : la scène ne prouve rien")
    return h
def trames_65(run, h, n0):
    return sum(1 for n in run.f if n >= n0 and run.f[n].get("z1") in h)

def gs_compte():
    g, p, t1 = sain("gs-65", "partie", "temps1")
    exiger(re.search(r"ROUND TIME +65", g.texte(2427)), "GAME SETTINGS ne montre pas ROUND TIME 65")
    h = chrono_65(p, t1)
    r = apres_pause(g)
    n = trames_65(g, h, r)
    dit(f"reprise à {r} : {n} trames montrent un chronomètre de 61 à 65 ({len(h)} images de référence)")
    exiger(n >= F("gs-compte", "trames_min"), f"{n} trames du chronomètre à 61-65")

def gs_defauts():
    d, g, p, t1 = sain("gs-def", "gs-65", "partie", "temps1")
    exiger(re.search(r"ROUND TIME +65", d.texte(2427)), "GAME SETTINGS ne montre pas ROUND TIME 65 avant la remise")
    exiger(re.search(r"ROUND TIME +60", d.texte(2457)), "RESET TO DEFAULTS ne rend pas ROUND TIME 60")
    h = chrono_65(p, t1)
    nd, ng = trames_65(d, h, apres_pause(d)), trames_65(g, h, apres_pause(g))
    dit(f"chronomètre à 61-65 : {nd} trames après la remise aux défauts, {ng} sans elle")
    exiger(ng >= F("gs-compte", "trames_min"), "ROUND TIME 65 ne se voit pas sans la remise : la scène ne prouve rien")
    exiger(nd <= F("gs-defauts", "trames_max"), f"{nd} trames du chronomètre à 61-65 après la remise aux défauts")

def gs_choix():
    g, e, l = sain("gs-langue", "editeur", "langue")
    exiger(re.search(r"LANGUAGE +SPANISH", g.texte(2409)), "GAME SETTINGS ne montre pas LANGUAGE SPANISH")
    exiger(any(r == "RESET" and n > 2422 for n, r in g.ev), "pas de RESET après RESTART GAME")
    ig = remise_image(g, 754)
    c = cases(remise_image(e, 754), ig)
    dans = [x for x in c if 152 <= x[1] * 8 <= 215]
    s = cases(remise_image(l, 754), ig)
    dit(f"754 trames après la remise : {len(dans)} cases du texte diffèrent de l'anglais ; {len(s)} cases de l'espagnol posé au boot")
    exiger(len(dans) >= F("gs-choix", "cases_min"), f"{len(dans)} cases dans le texte")
    exiger(len(s) <= F("gs-choix", "espagnol_max"), f"{len(s)} cases diffèrent de l'espagnol posé au boot")

def relance(run, apres, attendu=2418):
    rs = [n for n, r in run.ev if r == "RESET" and n > apres]
    exiger(rs, f"{run.nom} : pas de RESET après RESTART GAME")
    exiger(rs[0] == attendu, f"{run.nom} : RESET à {rs[0]}, les entrées d'après sont prévues pour {attendu}")
    return rs[0]

def gs_mmss():
    g, a, b = sain("gs-nc", "temps-nc0", "temps-nc1")
    exiger(re.search(r"PLAY TIME +03:01", g.texte(2403)), "GAME SETTINGS ne montre pas PLAY TIME 03:01")
    R = relance(g, 2410)
    for k in (1300, 2000, 3000):
        ig = g.img(R + k)
        # The TIME of ncombat's HUD: columns 10-15 of line 26 (y 208-215), like dip-mmss.
        zone = lambda c: [x for x in c if 10 <= x[0] <= 15 and x[1] == 26]
        c1, c0 = cases(b.img(k), ig), cases(a.img(k), ig)
        dit(f"R + {k} : TIME {len(zone(c1))} case(s) de l'éditeur du boot à 03:01, {len(zone(c0))} de 03:00 ; {len(c1)} cases en tout contre 03:01")
        exiger(not zone(c1), f"R + {k} : le TIME n'est pas celui de PLAY TIME 03:01")
        exiger(zone(c0), f"R + {k} : le TIME est celui de 03:00")
        exiger(len(c1) <= F("gs-mmss", "hors_max"), f"R + {k} : {len(c1)} cases diffèrent de 03:01 posé au boot")

def gs_fois():
    g, a, b = sain("gs-pz", "fois0", "fois1")
    exiger(re.search(r"CONTINUE +WITHOUT", g.texte(2403)), "A ne mène pas CONTINUE de INFINITE à WITHOUT")
    R = relance(g, 2410, 2417)
    rg = premiere_remise(g, R + 1001) - R
    ra, rb = premiere_remise(a, 1001), premiere_remise(b, 1001)
    dit(f"le titre après la partie : R + {rg}, contre {rb} sans continue posé au boot et {ra} avec")
    exiger(ra - rg >= F("dip-fois", "avance_min"), f"la partie finit {ra - rg} trames plus tôt seulement")
    exiger(abs(rg - rb) <= F("gs-fois", "ecart_max"), f"{abs(rg - rb)} trames d'écart avec WITHOUT posé au boot")

def liste_gs(run, n):
    """The lines of the GAME SETTINGS list: lines 3 to 10 of the box, 12 to 19 of the screen."""
    return [x for x in (run.fix.get(n, {}).get(r, "").strip() for r in range(12, 20)) if x]

def gs_sans(nom):
    n, g = sain(nom, "gs-65")
    exiger("ROUND TIME" in g.texte(2427), "le témoin n'a pas de ROUND TIME : la scène ne prouve rien")
    l = liste_gs(n, 2409)
    dit(f"{nom} : {len(l)} lignes ({' / '.join(l)})")
    exiger("GAME SETTINGS" in n.texte(2409) and any("NO SOFT DIP DATA" in x for x in l), "GAME SETTINGS ne dit pas NO SOFT DIP DATA")
    exiger(len(l) <= F("gs-sans-donnees", "lignes_max"), f"{len(l)} lignes : des réglages sont lus d'un bloc refusé")
    exiger([k for k in n.f if k > 2430 and n.f[k].get("cote") == "J"], "RESUME ne rend pas la main au jeu")
def gs_sans_donnees():
    gs_sans("gs-nosd")
def gs_banque():
    gs_sans("gs-banque")

def me_ecran_lu(run, n):
    """The memory editor screen at frame n: the cursor address (line 0 of the box, column 20;
    screen 9, 26), and the eight lines (box 2-9, screen 11-18: the address, then 2 × 4 bytes)."""
    fx = run.fix.get(n, {})
    exiger(fx, f"pas de plan fixe à la trame {n}")
    tete = fx.get(9, "")
    exiger("MEMORY EDITOR" in tete, f"trame {n} : pas d'éditeur mémoire à l'écran")
    lignes = []
    for r in range(11, 19):
        m = re.match(r"\s*([0-9A-F]{6}) ([0-9A-F]{8}) ([0-9A-F]{8})\s*$", fx.get(r, ""))
        exiger(m, f"trame {n}, ligne {r} illisible : |{fx.get(r, '')}|")
        lignes.append((int(m[1], 16), bytes.fromhex(m[2] + m[3])))
    return int(tete[26:32], 16), lignes
def ram(run, n, a0):
    """The eight bytes at a0 read by lua at the end of the frame (J_SUIVRE, words)."""
    f = run.f[n]
    return b"".join(int(f["m%06X" % (a0 + 2 * k)], 16).to_bytes(2, "big") for k in range(4))

def me_ecran():
    (m,) = sain("me-nav")
    for n, a0 in ((2481, 0x108400), (2541, 0x108440)):
        _, l = me_ecran_lu(m, n)
        exiger(l[0][0] == a0, f"trame {n} : la première ligne est {l[0][0]:06X}, {a0:06X} attendue")
        dit(f"trame {n} : {a0:06X} {l[0][1].hex().upper()} à l'écran, {ram(m, n, a0).hex().upper()} en RAM")
        exiger(l[0][1] == ram(m, n, a0), f"trame {n} : les octets affichés ne sont pas ceux de la RAM")
        exiger([x[0] for x in l] == [a0 + 8 * k for k in range(8)], f"trame {n} : les adresses ne vont pas de 8 en 8")
def me_curseur(scene, n, voulu, ligne0=None):
    (m,) = sain("me-nav")
    c, l = me_ecran_lu(m, n)
    dit(f"trame {n} : curseur {c:06X}, première ligne {l[0][0]:06X}")
    exiger(c == voulu, f"curseur {c:06X}, {voulu:06X} attendu")
    if ligne0 is not None:
        exiger(l[0][0] == ligne0, f"première ligne {l[0][0]:06X}, {ligne0:06X} attendue")
def me_goto():
    me_curseur("me-goto", 2481, 0x108400, 0x108400)
    me_curseur("me-goto", 2673, 0x109465, 0x109460)
    (m,) = sain("me-nav")
    me_curseur("me-goto", 2691, 0x109465, 0x109460)
    exiger("GOTO ADDRESS" not in m.texte(2691), "B ne quitte pas GOTO")
def me_octet():
    me_curseur("me-octet", 2517, 0x108406)
    me_curseur("me-octet", 2617, 0x1084AD)
def me_ligne():
    me_curseur("me-ligne", 2523, 0x10840E)
    me_curseur("me-ligne", 2623, 0x1084A5)
def me_page():
    me_curseur("me-page", 2541, 0x10844E, 0x108440)
    (m,) = sain("me-nav")
    c0, l0 = me_ecran_lu(m, 2623)
    c, l = me_ecran_lu(m, 2641)
    dit(f"trame 2641 : curseur {c:06X}, première ligne {l[0][0]:06X} (avant : {l0[0][0]:06X})")
    exiger(c == 0x108465 and l[0][0] == l0[0][0] - 0x40, "B tenu et haut ne remontent pas d'une page")
def me_repete():
    (m,) = sain("me-nav")
    c, _ = me_ecran_lu(m, 2609)
    crans = (c - 0x10844E) // 8
    dit(f"« bas » tenu 60 trames : {crans} lignes ({c:06X})")
    exiger(crans >= F("me-repete", "crans_min"), f"{crans} lignes seulement")

def me_poke():
    k, p = sain("me-poke", "partie")
    for n, v, quoi in ((2535, "40", "gauche deux fois"), (2541, "41", "haut"), (2547, "40", "bas"), (2565, "41", "haut, avant B")):
        exiger(re.search(r"108400 [0-9A-F]{8} [0-9A-F]{4}" + v, k.texte(n)) and "SET VALUE" in k.texte(n),
               f"SET VALUE ne montre pas ${v} en $108406 après {quoi}")
    exiger(re.search(r"108400 [0-9A-F]{8} [0-9A-F]{4}40", k.texte(2571)) and "SET VALUE" not in k.texte(2571), "B ne renonce pas")
    exiger(k.f[2571].get("m108406") == "40", f"$108406 vaut {k.f[2571].get('m108406')} après B, $40 attendu")
    r, D = reprise(k, p)
    # aof's HUD only redraws the timer at the next countdown: $40 written, it displays 39.
    h = {p.f[n]["z1"] for n in p.f if p.f[n].get("m108406") == "39"}
    exiger(h, "le témoin ne passe pas par 39 : la scène ne prouve rien")
    n = sum(1 for x in range(r, r + 600) if k.f[x].get("z1") in h)
    nt = sum(1 for x in range(r, r + 600) if p.f[x - D].get("z1") in h)
    dit(f"reprise à {r} : {n}/600 trames montrent le 39 du témoin, {nt} au témoin au même instant")
    exiger(n >= F("me-poke", "trames_min"), f"{n} trames montrent 39")
    exiger(nt == 0, "le témoin montre 39 au même instant : la scène ne prouve rien")

def fige(c, p, r, D, z):
    return c.f[r + 300][z] == c.f[r + 1500][z], p.f[r + 300 - D][z] != p.f[r + 1500 - D][z]
def me_gel():
    c, p = sain("me-gel", "partie")
    r, D = reprise(c, p)
    for z, nom in (("z1", "chronomètre"), ("z2", "barre de vie P1")):
        f, b = fige(c, p, r, D, z)
        dit(f"{nom} : {'figé' if f else 'change'} sous gel, {'change' if b else 'figé'} au témoin")
        exiger(f, f"le {nom} change sous gel")
        exiger(b, f"le {nom} ne change pas au témoin : la scène ne prouve rien")
def me_liste():
    (c,) = sain("me-gel")
    t = c.fix.get(2643, {}).get(20, "")
    dit(f"|{t.strip()}|")
    exiger(re.search(r"FROZEN 108406:60 1092CD:[0-9A-F]{2}", t), "les deux gels ne sont pas listés")
def me_degel():
    c, p = sain("me-degel", "partie")
    exiger("FROZEN 108406:60" in c.texte(2523), "le gel n'est pas listé à la pose")
    exiger("FROZEN NONE" in c.texte(3097), "le gel est encore listé après D")
    r1 = apres_pause(c)
    p2 = [x for x in c.pauses() if x[0] > r1]
    exiger(p2, "le menu ne s'est pas rouvert")
    r2 = p2[0][1] + 1
    fige1 = len({c.f[n]["z1"] for n in range(r1 + 300, p2[0][0])}) == 1
    bouge = len({c.f[n]["z1"] for n in range(r2 + 300, r2 + 900)}) > 1
    dit(f"gel : chronomètre {'figé' if fige1 else 'change'} de {r1 + 300} à {p2[0][0]} ; après le retrait, {'il change' if bouge else 'figé'} de {r2 + 300} à {r2 + 900}")
    exiger(fige1, "le chronomètre change sous gel")
    exiger(bouge, "le chronomètre reste figé après le retrait du gel")
def me_borne():
    (m,) = sain("me-borne")
    c, _ = me_ecran_lu(m, 2517)
    t0, t1 = m.texte(2517), m.texte(2529)
    dit(f"curseur {c:06X} ; aide |{m.fix[2529].get(22, '').strip()}| ; |{m.fix[2529].get(20, '').strip()}|")
    exiger(c == 0x10FD84, f"curseur {c:06X}, 10FD84 attendu")
    exiger("READ ONLY" in t0 and "READ ONLY" in t1, "l'écran ne dit pas READ ONLY")
    exiger("SET VALUE" not in t1, "A ouvre SET VALUE dans la zone du BIOS")
    exiger("FROZEN NONE" in t1, "D gèle un octet de la zone du BIOS")
    v = {m.f[n]["m10FD84"] for n in range(2357, 2700) if n in m.f}
    exiger(len(v) == 1, f"$10FD84 a changé : {sorted(v)}")

# ---- the floating bus ----
def bf_bilan(run):
    b = [l for l in open(os.path.join(run.d, "bf.tsv"), encoding="utf-8") if l.startswith("#\tbilan")]
    exiger(b, f"{run.nom} : pas de bilan du bus flottant")
    m = re.search(r"(\d+) resets, .* lectures flottantes : (\d+) bios, (\d+) jeu", b[0])
    exiger(m, f"{run.nom} : bilan illisible")
    return int(m[1]), int(m[2]), int(m[3]), b[0]
def bf_juge(nom, mots):
    a, t = sain(nom, nom + "-libre")
    r, lb, lj, _ = bf_bilan(a)
    exiger("BF_LIBRE" in bf_bilan(t)[3], f"{t.nom} : le témoin n'est pas libre")
    n = sorted(t.f)
    diff = [k for k in n if a.h(k) != t.h(k)]
    dit(f"sous le modèle : {lb} lectures flottantes du BIOS, {lj} du jeu, {r} reset(s) ; "
        f"{len(diff)} trames sur {len(n)} différentes du témoin" + (f", la première {diff[0]}" if diff else ""))
    exiger(lb == 0 and lj == 0, f"{lb} lectures flottantes du BIOS, {lj} du jeu")
    exiger(r == 0, f"{r} reset(s) sous le modèle")
    exiger(n and t.h(n[0]) is not None, "aucune empreinte relevée")
    exiger(not diff, f"{len(diff)} trames différentes du témoin, dès la trame {diff[0] if diff else '-'}")
    for k, m in mots:
        exiger(re.search(m, a.texte(k)), f"trame {k} : le plan fixe ne montre pas « {m} »")
    exiger([k for k, e in a.ev if e == "REMISE" and k > 340], "START ne rend pas la main au jeu")
def bf_editeur():
    bf_juge("bf-dip", [(330, "ART OF FIGHTING"), (330, r"ROUND TIME +61"), (330, r"LANGUAGE +SPANISH")])
def bf_banque():
    bf_juge("bf-ms", [(330, "METAL SLUG"), (330, "DIFFICULTY"), (330, r"CONTINUE +OFF")])
def bf_tests():
    bf_juge("bf-tests", [(345, "CROSSHATCH"), (470, "ART OF FIGHTING"), (470, r"ROUND TIME +60")])
def bf_jukebox():
    bf_juge("bf-juke", [(320, "SOUND CODE"), (530, "ART OF FIGHTING"), (530, r"ROUND TIME +60")])
def sans_cartouche():
    (a,) = sain("sc-mv1")
    r, lb, lj, b = bf_bilan(a)
    m = re.search(r"(\d+) trames finies dans le jeu", b)
    exiger(m, f"{a.nom} : bilan illisible")
    jeu = int(m[1])
    n = sorted(a.f)
    hors = [k for k in n if a.f[k].get("cote") != "B"]
    dit(f"sous le modèle : {r} reset(s), {lb} lectures flottantes du BIOS, {lj} du jeu, {jeu} trames finies dans le jeu ; "
        f"{len(n)} trames relevées, {len(hors)} hors du BIOS")
    exiger(r == 0, f"{r} reset(s) : la carte redémarre en boucle")
    exiger(lb == 0 and lj == 0, f"{lb} lectures flottantes du BIOS, {lj} du jeu")
    exiger(jeu == 0 and n and not hors, f"la main quitte le BIOS ({jeu} trames dans le jeu, la première hors du BIOS : {hors[0] if hors else '-'})")
    for k in (700, 1400):
        exiger("HARDWARE TESTS" in a.texte(k), f"trame {k} : le plan fixe ne montre pas « HARDWARE TESTS »")
def flash_cart():
    (a,) = sain("fc")
    r, lb, lj, b = bf_bilan(a)
    m = re.search(r"(\d+) trames finies dans le jeu", b)
    exiger(m, f"{a.nom} : bilan illisible")
    jeu = int(m[1])
    dit(f"cartouche muette (BF_ABSENTE) : {r} reset(s), {lb} lectures flottantes du BIOS, {lj} du jeu, {jeu} trames finies dans le jeu")
    exiger("GAME NGH ..... 0044" in a.texte(150), "trame 150 : l'écran de boot ne montre pas « GAME NGH ..... 0044 »")
    exiger(r == 0, f"{r} reset(s)")
    exiger(lb == 0 and lj == 0, f"{lb} lectures flottantes du BIOS, {lj} du jeu")
    exiger(jeu > 0, "le jeu n'a jamais la main")

# ---- the memory card manager (record --ref-carte) ----
# The lines of the screen (`src/c0/gestion-carte.s`): the state at line 6, the protection at 7,
# the list from 10 to 22, the messages at 24; a line of the list: the cursor in column 3, then
# NGH, sub-save, blocks, name.
def cm_l(run, n, r):
    exiger(n in run.fix, f"{run.nom} : pas de plan fixe à la trame {n}")
    return run.fix[n].get(r, "")
def cm_liste_de(run, n):
    """The listed saves: (selected, NGH, sub-save, blocks, name)."""
    out = []
    for r in range(10, 23):
        m = re.match(r"^ {3}([> ]) ([0-9A-F]{4}) (\d\d)  (\d\d)  (.*?) *$", cm_l(run, n, r))
        if m:
            out.append((m[1] == ">", m[2], int(m[3]), int(m[4]), m[5]))
    return out
def carte_de(nom):
    return open(os.path.join(RUNS, nom, "carte.neo"), "rb").read()
def cm_ouvert(run, n):
    exiger("MEMORY CARD" in cm_l(run, n, 3), f"{run.nom}, trame {n} : l'écran MEMORY CARD n'est pas ouvert")
def remise_apres(run, n):
    exiger([k for k, e in run.ev if e == "REMISE" and k > n], f"{run.nom} : START ne rend pas la main au jeu")

def cm_liste():
    (l,) = sain("cm-liste")
    cm_ouvert(l, 350)
    v = cm_liste_de(l, 350)
    dit("trame 350 : " + " / ".join(f"{'>' if c else ''}{g} {s} {b} {n or '-'}" for c, g, s, b, n in v))
    exiger(len(v) == 13, f"{len(v)} sauvegardes visibles, 13 attendues (la fixture en a 14)")
    exiger(v[0] == (True, "0044", 0, 1, "ART OF FIGHTING"), f"première ligne : {v[0]}")
    exiger(v[1] == (False, "0202", 1, 3, ""), f"deuxième ligne : {v[1]} (trois blocs, aucun nom : NGH sans jeu inscrit)")
    exiger([x[1:4] for x in v[2:]] == [("%04X" % (0x100 + k), k % 16, 1) for k in range(11)], "les onze suivantes ne sont pas celles de la fixture")
    exiger(not [x for x in v[2:] if x[4]], "une sauvegarde sans jeu inscrit porte un nom")
    w = cm_liste_de(l, 450)
    r21, r22 = cm_l(l, 450, 21), cm_l(l, 450, 22)
    dit(f"après « bas » quinze fois : première ligne {w[0][1] if w else '-'}, avant-dernière « {r21.strip()} », dernière « {r22.strip()} »")
    exiger(w and w[0][1] == "0101", "la liste ne défile pas : la première ligne visible n'est pas la quatrième sauvegarde")
    exiger(re.search(r"^ {3}> EXIT", r22) and "FORMAT CARD" in r21, "EXIT n'est pas la dernière ligne visible, choisie")
    exiger(re.search(r"> MEMORY CARD", l.texte(480)), "START ne rend pas l'écran TEST sur MEMORY CARD")
    remise_apres(l, 490)

def cm_libres():
    (l,) = sain("cm-liste")
    e = cm_l(l, 350, 6).strip()
    dit(f"ligne d'état : « {e} »")
    exiger(e == "FREE BLOCKS 11", f"« {e} », FREE BLOCKS 11 attendu (27 blocs de données, 16 pris)")

def cm_effacer():
    sain("carte-sauve-snk", "cop-supp-snk")
    (e,) = sain("cm-effacer")
    r, s_, z = sain("cm-eff-relu", "cop-supp-relu-snk", "carte-relue-snk")
    cm_ouvert(e, 345)
    exiger(cm_liste_de(e, 345)[:1] == [(True, "0044", 0, 1, "ART OF FIGHTING")], "la sauvegarde d'aof n'est pas listée au départ")
    exiger("DELETE 0044-00? A:YES B:NO" in cm_l(e, 355, 24), f"pas de confirmation : « {cm_l(e, 355, 24).strip()} »")
    exiger("DELETED" in cm_l(e, 380, 24), f"message « {cm_l(e, 380, 24).strip()} »")
    exiger(not cm_liste_de(e, 380), "la sauvegarde est encore listée")
    exiger(cm_l(e, 380, 6).strip() == "FREE BLOCKS 27", f"état « {cm_l(e, 380, 6).strip()} »")
    ca, cb, c0 = carte_de("cm-effacer"), carte_de("cop-supp-snk"), carte_de("carte-sauve-snk")
    d = octets(ca, cb)
    dit(f"la carte : {d} octet(s) de différence avec le BIOS SNK après CARD $04 ; la suppression SNK en change {octets(cb, c0)}")
    exiger(cb != c0, "la suppression du BIOS SNK ne change pas la carte : la scène ne prouve rien")
    exiger(d <= F("cm-effacer", "octets_max"), f"{d} octets diffèrent de la carte du BIOS SNK")
    eg, es = meme_instant(r, s_, 500, 2500), meme_instant(r, z, 500, 2500)
    dit(f"aof relancé : {eg}/2000 trames égales au BIOS SNK sur sa carte effacée ; {es} à la carte où la sauvegarde est encore")
    exiger(eg >= F("cm-effacer", "snk_min"), f"{eg} trames égales au témoin SNK")
    exiger(es <= F("cm-effacer", "sauve_max"), f"{es} trames égales à la carte non effacée : la sauvegarde est relue")

def cm_annuler():
    sain("carte-sauve-snk")
    (a,) = sain("cm-annuler")
    exiger("DELETE 0044-00? A:YES B:NO" in cm_l(a, 355, 24), f"pas de confirmation : « {cm_l(a, 355, 24).strip()} »")
    exiger("CANCELLED" in cm_l(a, 380, 24), f"message « {cm_l(a, 380, 24).strip()} »")
    exiger([x[1] for x in cm_liste_de(a, 380)] == ["0044"], "la sauvegarde d'aof n'est plus listée après B")
    d = octets(carte_de("cm-annuler"), carte_de("carte-sauve-snk"))
    dit(f"B renonce : CANCELLED, la sauvegarde listée, {d} octet(s) de la carte changés")
    exiger(d == 0, f"{d} octets de la carte ont changé : B n'a pas renoncé")

def cm_formater():
    sain("carte-sauve-snk", "cop-fmt-snk")
    (f_,) = sain("cm-formater")
    exiger("FORMAT CARD? A:YES B:NO" in cm_l(f_, 365, 24), f"pas de confirmation : « {cm_l(f_, 365, 24).strip()} »")
    exiger("FORMATTED" in cm_l(f_, 380, 24), f"message « {cm_l(f_, 380, 24).strip()} »")
    exiger(not cm_liste_de(f_, 380) and cm_l(f_, 380, 6).strip() == "FREE BLOCKS 27", "la carte formatée montre encore des sauvegardes, ou pas 27 blocs libres")
    ca, cb, c0 = carte_de("cm-formater"), carte_de("cop-fmt-snk"), carte_de("carte-sauve-snk")
    d = octets(ca, cb)
    dit(f"la carte : {d} octet(s) de différence avec le BIOS SNK après CARD $00 ; son formatage en change {octets(cb, c0)}")
    exiger(cb != c0, "le formatage du BIOS SNK ne change pas la carte : la scène ne prouve rien")
    exiger(d <= F("cm-formater", "octets_max"), f"{d} octets diffèrent de la carte du BIOS SNK")

def cm_non_formatee():
    (n,) = sain("cm-neuve")
    e0, e1 = cm_l(n, 345, 6).strip(), cm_l(n, 380, 6).strip()
    dit(f"carte neuve : « {e0} » ; après FORMAT CARD, A : « {e1} », « {cm_l(n, 380, 24).strip()} »")
    exiger(e0 == "CARD NOT FORMATTED", f"« {e0} »")
    exiger(e1 == "FREE BLOCKS 27" and "FORMATTED" in cm_l(n, 380, 24), "le formatage ne rend pas une carte vide de 27 blocs")
    c = carte_de("cm-neuve")
    exiger(bytes(c[0x20:0x30:2]) == b"NEO-GEO\x80", "la carte écrite ne porte pas CARD_MAGIC")

def cm_sans_carte():
    (s_,) = sain("cm-sans")
    e, m = cm_l(s_, 345, 6).strip(), cm_l(s_, 360, 24).strip()
    dit(f"sans carte : « {e} » ; A sur FORMAT CARD : « {m} »")
    exiger(e == "NO CARD", f"« {e} »")
    exiger(m == "NO CARD", f"message « {m} »")
    exiger(re.search(r"> MEMORY CARD", s_.texte(390)), "EXIT ne rend pas l'écran TEST")
    remise_apres(s_, 400)

def cm_protegee():
    (p_,) = sain("cm-prot")
    v, m1, m2 = cm_l(p_, 345, 7).strip(), cm_l(p_, 365, 24).strip(), cm_l(p_, 395, 24).strip()
    dit(f"protégée : « {v} » ; A sur une sauvegarde : « {m1} » ; A sur FORMAT CARD : « {m2} »")
    exiger(v == "WRITE PROTECTED", f"ligne 7 : « {v} »")
    exiger(m1 == "WRITE PROTECTED" and m2 == "WRITE PROTECTED", "le refus n'est pas dit")
    exiger("> FORMAT CARD" in p_.texte(395), "le curseur n'est pas sur FORMAT CARD : la scène ne prouve rien")
    d = octets(carte_de("cm-prot"), open(FIXTURE, "rb").read())
    exiger(d == 0, f"{d} octets de la carte ont changé sous protection")

def cm_insertion():
    (i,) = sain("cm-insertion")
    e0, e1 = cm_l(i, 350, 6).strip(), cm_l(i, 420, 6).strip()
    v = cm_liste_de(i, 420)
    dit(f"carte absente : « {e0} » ; présente à 400 : « {e1} », {len(v)} sauvegardes visibles")
    exiger(e0 == "NO CARD", f"« {e0} » avant l'insertion")
    exiger(e1 == "FREE BLOCKS 11" and v and v[0][1] == "0044", "la carte insérée n'est pas relue")
    # A pending confirmation, then the card removed and reinserted: it is abandoned, nothing is
    # erased.
    m0, m1, m2 = cm_l(i, 440, 24).strip(), cm_l(i, 480, 24).strip(), cm_l(i, 500, 24).strip()
    w = cm_liste_de(i, 480)
    d = octets(carte_de("cm-insertion"), open(FIXTURE, "rb").read())
    dit(f"A : « {m0} » ; retirée à 450 : « {cm_l(i, 460, 6).strip()} » ; remise : « {m1} », puis A : « {m2} » ; "
        f"{d} octet(s) de la carte changés")
    exiger("DELETE 0044-00? A:YES B:NO" in m0, f"pas de confirmation avant le retrait : « {m0} »")
    exiger(cm_l(i, 460, 6).strip() == "NO CARD", "le retrait n'est pas vu : la scène ne prouve rien")
    exiger(w and w[0][:2] == (True, "0044"), "le curseur n'est pas sur aof à la remise : la scène ne prouve rien")
    exiger(not m1, f"la confirmation survit au changement de carte : « {m1} »")
    exiger("DELETE 0044-00? A:YES B:NO" in m2, f"A après le changement de carte : « {m2} », une nouvelle confirmation attendue")
    exiger(d <= F("cm-insertion", "octets_max"), f"{d} octets de la carte ont changé : une sauvegarde a été effacée")

def aes_scores():
    sain("aes-sc-a", "aes-sc-a0")
    b, b0 = sain("aes-sc-b", "aes-sc-b0")
    exiger(any(x[1].startswith("POSE") for x in Run("aes-sc-a").ev), "pas de pose au run aes-sc-a")
    for r in (b, b0):
        exiger("SYSTEM ....... AES" in r.texte(100), f"{r.nom} : l'écran de boot ne dit pas SYSTEM AES")
    c = cases(b.img(4900), b0.img(4900))
    l1 = [x for x in c if 48 <= x[1] * 8 <= 79]
    dit(f"mode AES, trame 4900 : {len(l1)} cases sur la ligne 1ST, {len(c) - len(l1)} ailleurs")
    exiger(len(c) == len(l1), f"{len(c) - len(l1)} cases hors de la ligne 1ST")
    exiger(len(l1) >= F("aes-scores", "cases_min"), f"{len(l1)} cases sur la ligne 1ST : le score n'a pas survécu à la relance")

def scores_gel():
    sain("sg-a-on")
    (o,) = sain("sg-a-off")
    m, s_, g = sain("sg-b-meme", "sg-b-saut", "sg-b-gel")
    exiger(re.search(r"> SCORE RESET +OFF", o.texte(335)), "l'éditeur ne montre pas SCORE RESET OFF")
    for r, d in ((m, "10/01/26 THU"), (s_, "11/08/26 SUN"), (g, "11/08/26 SUN")):
        exiger("CLOCK ........ " + d in r.texte(100), f"{r.nom} : la ligne CLOCK ne dit pas {d}")
    D = [k for k in sorted(m.f) if k > 200 and m.h(k) is not None and m.h(k) != s_.h(k)]
    eg_m = sum(1 for k in D if g.h(k) == m.h(k))
    eg_s = sum(1 for k in D if g.h(k) == s_.h(k))
    dit(f"38 jours plus tard, SCORE RESET ON : {len(D)} trames de BEST HEROES diffèrent du même jour (la table remise) ; "
        f"à OFF : {eg_m} égales au même jour, {eg_s} au saut")
    exiger(len(D) >= F("scores-gel", "trames_min"), f"{len(D)} trames : le témoin ne remet pas sa table, la scène ne prouve rien")
    exiger(eg_m == len(D) and eg_s == 0, f"à OFF, {len(D) - eg_m} trames ne sont pas celles du même jour : la table a été remise")

def bf_carte():
    bf_juge("bf-carte", [(345, "ART OF FIGHTING"), (345, "FREE BLOCKS 11"), (410, r"> MEMORY CARD")])

# ---- the cabinet settings (record --ref-borne) ----
def lignes_liste(run, n):
    return [run.fix.get(n, {}).get(r, "").strip() for r in range(7, 28) if run.fix.get(n, {}).get(r, "").strip()]

def memoire(run, n, adr):
    return int(run.f[n]["m" + adr], 16)

def bo_ecran():
    (e,) = sain("bo-ecran")
    l0, l1, l2, l3 = (lignes_liste(e, k) for k in (310, 325, 365, 385))
    dit(f"la liste, ses sept dernières lignes : {' / '.join(l0[-7:])}")
    exiger(l0[-7].startswith("> CABINET SETTINGS"), f"« haut » sept fois ne mène pas à CABINET SETTINGS : {l0[-7]}")
    for x, attendu in zip(l0[-6:], ("SCORE RESET", "MEMORY CARD", "MODE", "HARDWARE TESTS", "JUKEBOX", "RESET TO DEFAULTS")):
        exiger(x.startswith(attendu), f"« {x} » à la place de {attendu} : un chemin de touches a bougé")
    t1, t2, t3 = e.texte(325), e.texte(365), e.texte(385)
    dit(f"le sous-écran : {' / '.join(l1)} ; après les trois changements : {' / '.join(l2)}")
    exiger("CABINET SETTINGS" in t1 and "START:BACK" in t1, "le sous-écran CABINET SETTINGS ne s'ouvre pas")
    exiger(len(l1) == 5, f"{len(l1)} lignes au sous-écran, 5 attendues")
    for m in (r"> FREE PLAY +OFF", r"NO CONTINUE +OFF", r"DEMO SOUND +ON", r"CHEATS/DEBUG +ON", r"DEBUG DIPS +0000"):
        exiger(re.search(m, t1), f"trame 325 : pas de « {m} »")
    for m in (r"FREE PLAY +ON", r"NO CONTINUE +ON", r"> DEMO SOUND +OFF"):
        exiger(re.search(m, t2), f"trame 365 : pas de « {m} »")
    exiger("SOFT DIP SETTINGS" in t3 and re.search(r"> CABINET SETTINGS", t3) and "START:SAVE AND EXIT" in t3,
           "START ne rend pas la liste sur CABINET SETTINGS")
    v = memoire(e, 500, "D0021D")
    dit(f"$D0021D = {v} après START (complément)")
    exiger(v == 7, f"$D0021D vaut {v}, 7 attendu : les réglages ne sont pas enregistrés")
    exiger([k for k, x in e.ev if x == "REMISE" and k > 390], "START ne rend pas la main au jeu")

def ab_ecran():
    (e,) = sain("ab-ecran")
    l0, l2 = lignes_liste(e, 316), lignes_liste(e, 375)
    dit(f"la liste, ses huit dernières lignes : {' / '.join(l0[-8:])}")
    exiger(l0[-8].startswith("> ABOUT"), f"« haut » huit fois ne mène pas à ABOUT : {l0[-8]}")
    exiger(l0[-7].startswith("CABINET SETTINGS"), f"« {l0[-7]} » sous ABOUT, CABINET SETTINGS attendu")
    t = e.texte(340)
    dit("l'écran ABOUT : " + " / ".join(x.strip() for x in t.split("\n") if x.strip()))
    exiger("SOFT DIP SETTINGS" not in t, "A ne quitte pas la liste")
    for m in ("SPRIXE BIOS", "0.1 BETA", "COPYRIGHT 2026 THIBAUT LION", "THIS PROGRAM COMES WITH",
              "ABSOLUTELY NO WARRANTY.", "IT IS FREE SOFTWARE: YOU MAY", "REDISTRIBUTE IT UNDER THE GNU",
              "GPL VERSION 3 OR LATER.", "LICENSE AND SOURCE CODE:", "GITHUB.COM/LID-LABS/SPRIXE-BIOS",
              "HARDWARE TESTING:", "SEBASTIAN KLOETZER", "START:BACK"):
        exiger(m in t, f"trame 340 : pas de « {m} »")
    exiger("SOFT DIP SETTINGS" in e.texte(375) and l2[-8].startswith("> ABOUT"),
           "START ne rend pas la liste sur ABOUT")
    exiger([k for k, x in e.ev if x == "REMISE" and k > 390], "START ne rend pas la main au jeu")

def bo_reglage(run, m):
    exiger(re.search(m, run.texte(365)), f"{run.nom} : l'éditeur ne montre pas « {m} »")

def bo_alignes(a, k):
    # The first hand-over of the SNK BIOS (mode 01, request 00) precedes its request 2 by one
    # frame: 750 and 751, against 184 for us (direct request 2); the inputs of the witness run are
    # shifted by 567, from request 2 to request 2.
    r, rk = premiere_remise(a), premiere_remise(k)
    exiger(rk - r == 566, f"remises {r} et {rk} : l'écart n'est plus 566, les entrées du témoin ne sont plus au même instant")
    return 567

def meme_instant_d(a, b, n0, n1, d):
    """The frames of [n0, n1) equal to the witness run, at the best shift within ± 3 frames of d: the game starts on
    the frame of the press under both BIOSes, but not at the same phase of the frame (measured: 213 to 1,123 equal
    frames depending on the shift, from 565 to 568)."""
    return max(sum(1 for k in range(n0, n1) if a.h(k) is not None and a.h(k) == b.h(k + x)) for x in range(d - 3, d + 4))

def bo_free_play():
    (s,) = sain("bo-set-fp")
    bo_reglage(s, r"FREE PLAY +ON")
    f, k, t = sain("bo-fp", "bo-snk-fp", "bo-dm0")
    d = bo_alignes(f, k)
    r = premiere_remise(f)
    D, n = meilleur_decalage(f, k, r + 1, 1000)
    Dt, nt = meilleur_decalage(f, t, r + 1, 1000)
    eg = meme_instant_d(f, k, 1001, 3100, d)
    c = cases(t.img(1400), f.img(1400))
    cr = {f.f[x]["mD00034"] for x in range(900, 3100) if x in f.f}
    dit(f"la démo : {n}/{999 - r} trames de la démo SNK en free play (décalage {D}), {nt} de la démo sans réglage (décalage {Dt})")
    dit(f"START à 1000 sans pièce : {eg}/2099 trames égales au BIOS SNK en free play ; trame 1400, {len(c)} cases diffèrent de la démo ; crédits {sorted(cr)}")
    exiger(n >= F("bo-free-play", "temoin_min"), f"{n} trames de la démo SNK en free play")
    exiger(nt <= F("bo-free-play", "autre_max"), f"{nt} trames de la démo sans réglage")
    exiger(eg >= F("bo-free-play", "snk_min"), f"{eg} trames égales au BIOS SNK : la partie ne part pas comme sous lui")
    exiger(len(c) >= F("bo-free-play", "cases_min"), f"{len(c)} cases : la partie ne part pas")
    exiger(cr == {"0"}, f"crédits {sorted(cr)} : une pièce comptée")

def bo_fp_p2():
    p, k, f = sain("bo-fp-p2", "bo-snk-p2", "bo-fp")
    d = bo_alignes(p, k)
    eg, eg1 = meme_instant_d(p, k, 1001, 3100, d), meme_instant_d(p, f, 1001, 3100, 0)
    j = {p.f[x]["m10FDB4"] for x in range(1001, 1010) if x in p.f}
    dit(f"START P2 en démo : {eg}/2099 trames égales au BIOS SNK en free play, {eg1} à un START P1 ; BIOS_START_FLAG {sorted(j)}")
    exiger(eg >= F("bo-fp-p2", "snk_min"), f"{eg} trames égales au BIOS SNK")
    exiger(eg1 <= F("bo-fp-p2", "p1_max"), f"{eg1} trames égales à un START P1 : P2 ne part pas")

def bo_fp_joint():
    j, k, f = sain("bo-fp-joint", "bo-snk-joint", "bo-fp")
    d = bo_alignes(j, k)
    eg, eg1 = meme_instant_d(j, k, 2001, 3100, d), meme_instant_d(j, f, 2001, 3100, 0)
    dit(f"START P2 en partie : {eg}/1099 trames égales au BIOS SNK en free play, {eg1} à la partie sans P2")
    exiger(eg >= F("bo-fp-joint", "snk_min"), f"{eg} trames égales au BIOS SNK")
    exiger(eg1 <= F("bo-fp-joint", "seul_max"), f"{eg1} trames égales à la partie sans P2 : P2 ne se joint pas")

def bo_no_continue():
    (s,) = sain("bo-set-nc")
    bo_reglage(s, r"NO CONTINUE +ON")
    n, q, c = sain("bo-nc", "partie2", "bo-cont")
    mod = {n.f[x]["m10FDB6"] for x in range(6250, 6300) if x in n.f}
    exiger(mod == {"2"}, f"BIOS_PLAYER_MOD1 {sorted(mod)} avant le START : le continue n'est pas affiché à 6300")
    ef, ec = meme_instant(n, q, 6400, 8700), meme_instant(n, c, 6400, 8700)
    eqc = meme_instant(c, q, 6400, 8700)
    crn, crc = n.f[6400]["mD00034"], c.f[6400]["mD00034"]
    dit(f"START à 6300 pendant le continue : {ef}/2300 trames de la partie sans ce START (game over, titre), {ec} du continue pris ; "
        f"crédit {crn} (continue pris : {crc}) ; témoins entre eux {eqc}")
    exiger(eqc <= F("bo-no-continue", "cont_max"), f"le continue pris égale {eqc} trames du game over : la scène ne prouve rien")
    exiger(ef >= F("bo-no-continue", "fin_min"), f"{ef} trames du game over : le continue a été pris")
    exiger(ec <= F("bo-no-continue", "cont_max"), f"{ec} trames du continue pris")
    exiger(crn == "1", f"crédit {crn} après le START refusé")

def bo_demo_muette():
    (s,) = sain("bo-set-dm")
    bo_reglage(s, r"DEMO SOUND +OFF")
    m, t = sain("bo-dm", "bo-dm0")
    fen = [("démo", 600, 2990, "demo_max", True), ("titre", 3010, 3290, "titre_min", False), ("partie", 3400, 4400, "partie_min", False)]
    r2m, r2t = premiere_remise(m, 6000), premiere_remise(t, 6000)
    exiger(r2m == r2t, f"la démo d'après la partie : remises {r2m} et {r2t}")
    fen.append(("démo d'après la partie", r2m + 100, r2m + 1500, "demo_max", True))
    for nom, a, b, g, muet in fen:
        rm, rt = m.rms(a, b), t.rms(a, b)
        km, kt = m.keyon(a, b), t.keyon(a, b)
        dit(f"{nom} {a}-{b} : RMS {rm:.0f} contre {rt:.0f} sans le réglage, key-on {km} contre {kt}")
        exiger(rt > 0, f"{nom} : le témoin est muet, la scène ne prouve rien")
        if muet:
            exiger(rm <= F("bo-demo-muette", g) * rt, f"{nom} : RMS {rm / rt:.2f} du témoin")
            exiger(km <= F("bo-demo-muette", "keyon_max"), f"{nom} : {km} key-on")
        else:
            exiger(rm >= F("bo-demo-muette", g) * rt, f"{nom} : RMS {rm / rt:.2f} du témoin, le son n'est pas rétabli")

def bo_aes():
    (s,) = sain("bo-set-aes")
    t5, t6 = s.texte(445), s.texte(460)
    exiger(re.search(r"FREE PLAY +ON", s.texte(365)) and re.search(r"NO CONTINUE +ON", s.texte(365))
           and re.search(r"DEMO SOUND +OFF", s.texte(365)), "les trois réglages ne sont pas posés")
    exiger(len(re.findall(r"MVS ONLY", t5)) == 3 and "CABINET SETTINGS" in t5, "le sous-écran en mode AES ne dit pas MVS ONLY trois fois")
    exiger(re.search(r"CHEATS/DEBUG +ON", t5), "en mode AES, CHEATS/DEBUG ne dit pas ON : elle vaut dans les deux modes")
    exiger(re.search(r"MODE +AES", t6), "la ligne MODE ne dit pas AES")
    sain("aes-set")
    a, c, h = sain("bo-aes", "bo-aes-cont", "aes-histoire")
    exiger("SYSTEM ....... AES" in a.texte(100), "bo-aes : l'écran de boot ne dit pas SYSTEM AES")
    mod = {a.f[x]["m10FDB6"] for x in range(7450, 7500) if x in a.f}
    exiger(mod == {"2"}, f"BIOS_PLAYER_MOD1 {sorted(mod)} avant le START : le continue n'est pas affiché à 7500")
    born = {a.f[x]["m10FB20"] for x in range(300, 8800, 100) if x in a.f}
    ec, ef, ech = meme_instant(a, c, 7500, 8800), meme_instant(a, h, 7500, 8800), meme_instant(c, h, 7500, 8800)
    ra, rc = a.rms(300, 990), c.rms(300, 990)
    dit(f"mode AES, BORNE {sorted(born)} ; START à 7500 : {ec}/1300 trames du continue pris sans réglage, {ef} du game over "
        f"(témoins entre eux {ech}) ; la démo RMS {ra:.0f} contre {rc:.0f}")
    exiger(ech <= F("bo-aes", "fin_max"), f"le témoin du continue égale {ech} trames du game over : la scène ne prouve rien")
    exiger(ec >= F("bo-aes", "cont_min"), f"{ec} trames du continue pris : NO CONTINUE agit en mode AES")
    exiger(ef <= F("bo-aes", "fin_max"), f"{ef} trames du game over")
    exiger(rc > 0 and ra >= F("bo-aes", "demo_min") * rc, f"la démo RMS {ra:.0f} contre {rc:.0f} : DEMO SOUND agit en mode AES")

# ---- the cheat catalogue and CHEATS/DEBUG (record --ref-cheats) ----
def cheats_vies():
    o, t = sain("cv-on", "cv-temoin")
    exiger(re.search(r"INFINITE LIVES +ON", o.texte(1560)), "le menu ne montre pas INFINITE LIVES ON")
    def dominante(run):
        z = [run.f[k]["z1"] for k in range(1700, 9000) if k in run.f]
        return max(z.count(v) for v in set(z)) / len(z)
    fo, ft = dominante(o), dominante(t)
    fin_o = [k for k in range(1600, 9000) if k in o.f and o.f[k].get("m10FDAF") != "2"]
    fin_t = [k for k in range(1600, 9000) if k in t.f and t.f[k].get("m10FDAF") != "2"]
    dit(f"compteur de vies du HUD : même image sur {fo:.3f} des trames sous cheat, {ft:.3f} au témoin ; fin de partie : "
        f"témoin {fin_t[0] if fin_t else 'aucune'}, sous cheat {fin_o[0] if fin_o else 'aucune'}")
    exiger(fin_t, "le témoin ne perd pas la partie : la scène ne prouve rien")
    exiger(ft <= F("cheats-vies", "hud_temoin_max"), f"le HUD du témoin garde la même image sur {ft:.3f} des trames")
    exiger(fo >= F("cheats-vies", "hud_on_min"), f"le compteur de vies change sous cheat ({fo:.3f})")
    exiger(not fin_o, f"fin de partie sous cheat à la trame {fin_o[0] if fin_o else 0}")

# ---- the grid of $C03000 (record --ref-ssideki) ----
def demo_ssideki():
    o, t = sain("ss-notre", "ss-snk")
    def apres_remise(run):
        r = [n for n, e in run.ev if e == "REMISE"]
        exiger(r, f"run {run.nom} : aucune remise de la main au jeu")
        k = range(r[0] + 400, r[0] + 2400)
        exiger(all(n in run.f for n in k), f"run {run.nom} : le relevé s'arrête avant la trame {k[-1]}")
        return len({run.f[n]["img"] for n in k}), run.keyon(k[0], k[-1] + 1), r[0]
    io, ko, ro = apres_remise(o)
    it, kt, rt = apres_remise(t)
    dit(f"400 à 2399 trames après la remise (la nôtre à {ro}, celle du témoin à {rt}) : {io} images différentes "
        f"et {ko} key-on, contre {it} et {kt} au témoin SNK")
    exiger(it > 0 and kt > 0, "le témoin SNK n'a ni image ni key-on : la scène ne prouve rien")
    exiger(io >= F("demo-ssideki", "images_ratio_min") * it, f"{io} images contre {it} : la démo se fige")
    exiger(ko >= F("demo-ssideki", "keyon_ratio_min") * kt, f"{ko} key-on contre {kt} : le match de démo n'a pas lieu")

def bo_cd_menu():
    (s,) = sain("bo-set-cd")
    bo_reglage(s, r"CHEATS/DEBUG +OFF")
    m, c = sain("bo-cd-menu", "cheats")
    t0, t1, t2 = m.texte(2375), m.texte(2385), m.texte(2395)
    tc = c.texte(2427)
    dit("le menu, CHEATS/DEBUG OFF : " + " / ".join(x.strip() for x in t0.split("\n") if x.strip()))
    exiger("INFINITE TIME" in tc and "MEMORY EDITOR" in tc, "au réglage par défaut, le menu n'a pas ses cheats et MEMORY EDITOR : la scène ne prouve rien")
    for x in ("RESUME", "RESTART GAME", "GAME SETTINGS"):
        exiger(x in t0, f"le menu n'a plus {x}")
    for x in ("INFINITE", "MEMORY EDITOR"):
        exiger(x not in t0, f"le menu montre encore {x}")
    exiger(re.search(r"> *GAME SETTINGS", t1), "« haut » depuis RESUME ne mène pas à GAME SETTINGS")
    exiger(re.search(r"> *RESUME", t2), "« bas » depuis GAME SETTINGS ne mène pas à RESUME")

def bo_cd_gel():
    (s,) = sain("bo-set-cd")
    bo_reglage(s, r"CHEATS/DEBUG +OFF")
    g, o = sain("bo-cd-gel", "bo-cd-gel-on")
    def bilan(run):
        fige = run.f[2700]["z1"] == run.f[3900]["z1"]
        k60 = sum(1 for k in range(2700, 3900) if run.f[k].get("m108406") == "60")
        return fige, k60
    (fg, kg), (fo, ko) = bilan(g), bilan(o)
    dit(f"gel posé à 2400 : CHEATS/DEBUG OFF, chronomètre {'figé' if fg else 'qui change'}, $108406 à $60 sur {kg}/1 200 ; "
        f"au réglage par défaut, {'figé' if fo else 'qui change'}, {ko}/1 200")
    exiger(fo and ko >= F("bo-cd-gel", "ram_on_min"), "au réglage par défaut, le gel posé ne fige pas le chronomètre : la scène ne prouve rien")
    exiger(not fg, "CHEATS/DEBUG OFF : le chronomètre reste figé par le gel")
    exiger(kg <= F("bo-cd-gel", "ram_max"), f"CHEATS/DEBUG OFF : $108406 à $60 sur {kg} trames")

def bf_borne():
    bf_juge("bf-borne", [(325, "CABINET SETTINGS"), (325, r"FREE PLAY +OFF"), (385, "ART OF FIGHTING"), (385, r"> CABINET SETTINGS")])

# ---- the cartridge CRC32 and the debug dips (record --ref-crc) ----
def crc_attendu(jeu):
    for l in open(CRC_ATTENDUS, encoding="utf-8"):
        c = l.rstrip("\n").split("\t")
        if c[0] == jeu:
            exiger(c[1] != "-", f"{jeu} : CRC non reconstruit hors de MAME ({c[5]})")
            return c
    raise Ecart(f"{jeu} : absent de crc-attendus.tsv")

def crc_lignes(run, n):
    t = run.texte(n)
    f = re.search(r"FIXED (\d{4})K +([0-9A-F]{8})", t)
    b = re.search(r"BANKS (NONE|(\d) X 1024K +([0-9A-F]{8}))", t)
    return t, f, b

def crc_juge(run, jeu, n_fin, scene, fixe=None):
    """The CRC screen: the computation in progress, then its two lines equal to those of `crc-cartouche.py` (or to
    `fixe`), DONE at the latest on the threshold frame."""
    c = crc_attendu(jeu)
    t, f, b = crc_lignes(run, n_fin)
    dit(f"{run.nom}, trame {n_fin} : {f[0] if f else 'pas de FIXED'} / {b[0] if b else 'pas de BANKS'} ; "
        f"attendus hors de MAME : FIXED {c[1]}K {c[2]} / BANKS {c[3]} {c[4]}")
    exiger("CARTRIDGE CRC32" in t and "DONE" in t, f"trame {n_fin} : l'écran du CRC n'a pas fini")
    exiger(f, "la ligne FIXED est illisible")
    attendu_f = fixe or (c[1], c[2])
    exiger((f[1], f[2]) == attendu_f, f"FIXED {f[1]}K {f[2]}, attendu {attendu_f[0]}K {attendu_f[1]}")
    exiger(b, "la ligne BANKS est illisible")
    if fixe is None:
        exiger((b[1] if b[1] == "NONE" else (b[2], b[3])) == (c[3] if c[3] == "NONE" else (c[3], c[4])),
               f"BANKS {b[1]}, attendu {c[3]} {c[4]}")
    else:
        exiger(b[1] == "NONE", f"BANKS {b[1]}, NONE attendu")
    fini = [k for k in sorted(run.fix) if "DONE" in run.texte(k)]
    if fini:
        dit(f"DONE à la trame {fini[0]} au plus tôt des trames relevées")
    return fini[0] if fini else None

def crc_fixe():
    (a,) = sain("crc-aof")
    exiger(re.search(r"> CARTRIDGE CRC", a.texte(340)), "« haut » deux fois depuis WORK RAM ne mène pas à CARTRIDGE CRC")
    exiger(re.search(r"READING FIXED \d{4}K", a.texte(400)), "trame 400 : pas de READING FIXED pendant le calcul")
    fin = crc_juge(a, "aof", 940, "crc-fixe")
    exiger(fin is not None and fin <= F("crc-fixe", "fin_max"), f"DONE à la trame {fin}, au-delà de {S('crc-fixe', 'fin_max')}")
    exiger(re.search(r"> CARTRIDGE CRC", a.texte(960)), "START ne rend pas le menu des tests sur CARTRIDGE CRC")
    exiger("SOFT DIP SETTINGS" in a.texte(990), "START ne rend pas l'écran TEST")
    exiger([k for k, x in a.ev if x == "REMISE" and k > 1000], "START ne rend pas la main au jeu")

def crc_banques():
    (a,) = sain("crc-ms2")
    fin = crc_juge(a, "mslug2", 1890, "crc-banques")
    exiger(fin is not None and fin <= F("crc-banques", "fin_max"), f"DONE à la trame {fin}, au-delà de {S('crc-banques', 'fin_max')}")
    c = crc_attendu("mslug2")
    fichiers = dict((x.split("@")[0], x.split(":")[-1].upper()) for x in c[5].split())
    exiger(fichiers.get("241-p1.p1") == c[2] and fichiers.get("241-p2.sp2") == c[4],
           f"les CRC attendus ne sont pas ceux des fichiers de -listxml ({c[5]})")
    exiger("SOFT DIP SETTINGS" in a.texte(1940), "START ne rend pas l'écran TEST")
    exiger([k for k, x in a.ev if x == "REMISE" and k > 1960], "START ne rend pas la main au jeu")

def crc_miroir():
    (a,) = sain("crc-miroir")
    c = crc_attendu("aof")
    p1 = [x for x in c[5].split() if x.startswith("044-p1.p1@")]
    exiger(p1, "044-p1.p1 absent de -listxml")
    crc_juge(a, "aof", 940, "crc-miroir", fixe=("0512", p1[0].split(":")[-1].upper()))

def crc_flottant():
    (a,) = sain("crc-flottant")
    crc_juge(a, "aof", 940, "crc-flottant")

def bf_crc():
    c = crc_attendu("aof")
    bf_juge("bf-crc", [(400, r"READING FIXED"), (900, "FIXED %sK +%s" % (c[1], c[2])), (900, "BANKS NONE"), (990, "ART OF FIGHTING")])

def bf_crc_banque():
    c = crc_attendu("mslug")
    bf_juge("bf-crc-ms", [(1400, "FIXED %sK +%s" % (c[1], c[2])), (1400, r"BANKS %s X 1024K +%s" % (c[3], c[4])),
                          (1490, "METAL SLUG")])

def dd_bits(run, n):
    t = run.texte(n)
    m1 = re.search(r"DIP 1 +((?:[01] ){7}[01])", t)
    m2 = re.search(r"DIP 2 +((?:[01] ){7}[01])", t)
    return (m1[1].replace(" ", "") if m1 else None, m2[1].replace(" ", "") if m2 else None)

def dd_effet():
    u, z = sain("dd-1", "dd-0")
    exiger(re.search(r"> DEBUG DIPS +0000", z.texte(352)), "« bas » quatre fois ne mène pas à DEBUG DIPS, ou la ligne ne dit pas 0000")
    e = [dd_bits(u, k) for k in (358, 363, 381, 387)]
    dit(f"l'écran : DIP 1 / DIP 2 aux trames 358, 363, 381, 387 : {e}")
    exiger(e == [("00000000", "00000000"), ("10000000", "00000000"), ("10000000", "01000000"), ("10000000", "00000000")],
           "les bits à l'écran ne suivent pas A, bas, droite, A, A")
    exiger(re.search(r"> DEBUG DIPS +0100", u.texte(393)), "trame 393 : la ligne DEBUG DIPS ne dit pas 0100")
    n = [k for k in range(600, 6001) if k in u.f and k in z.f]
    zone = sum(1 for k in n if u.f[k].get("z1") != z.f[k].get("z1"))
    bit = sum(1 for k in n if int(u.f[k]["m100000"], 16) & 1)
    bloc = [k for k in sorted(u.f) if "mD00320" in u.f[k] and int(u.f[k]["mD00320"], 16) & 1]
    temoin = sum(1 for k in n if int(z.f[k]["m100000"], 16) & 1)
    dit(f"trames 600-6000 : le bas de l'écran diffère du témoin sur {zone} ; $100000 bit 0 sur {bit} (témoin {temoin}) ; "
        f"bloc de sauvegarde $D00320 bit 0 sur {len(bloc)} trames")
    exiger(temoin == 0, "le témoin a $100000 bit 0 : la scène ne prouve rien")
    exiger(zone >= F("dd-effet", "zone_min"), f"le bas de l'écran diffère du témoin sur {zone} trames seulement")
    exiger(bit >= F("dd-effet", "ram_min"), f"$100000 bit 0 sur {bit} trames seulement")
    exiger(not bloc, f"le masque est parti en backup RAM (trame {bloc[0] if bloc else 0})")

def dd_connu():
    c, = sain("dd-set", "dd-connu")[1:]
    exiger(re.search(r"> DEBUG DIPS +0100", c.texte(393)), "trame 393 : la ligne DEBUG DIPS ne dit pas 0100")
    r = [k for k in sorted(c.f) if c.f[k].get("m10FD80", "").upper() == "82"]
    exiger(r, "aucune remise au jeu ($10FD80 jamais à $82)")
    v = int(c.f[r[0]]["m100000"], 16)
    rs, lb, lj, _ = bf_bilan(c)
    dit(f"remise trame {r[0]} : $100000 = {v:02X} ; sous le modèle du bus flottant : {lb} lectures flottantes du BIOS, "
        f"{lj} du jeu, {rs} reset(s)")
    exiger(lb == 0 and lj == 0 and rs == 0, f"{lb} lectures flottantes du BIOS, {lj} du jeu, {rs} reset(s)")
    exiger(v & 1, f"$100000 = {v:02X} à la remise : le masque n'est pas posé quand le jeu part")

def dd_off():
    o, z = sain("dd-off", "dd-0off")
    exiger(re.search(r"DIP 1 +1 0 0 0 0 0 0 0", o.texte(363)), "trame 363 : DIP 1 bit 0 n'est pas mis")
    exiger(re.search(r"> DEBUG DIPS +0100", o.texte(369)), "trame 369 : la ligne DEBUG DIPS ne dit pas 0100")
    t = o.texte(381)
    exiger(re.search(r"CHEATS/DEBUG +OFF", t) and re.search(r"DEBUG DIPS +OFF", t), "trame 381 : CHEATS/DEBUG OFF ne met pas DEBUG DIPS à OFF")
    exiger("CABINET SETTINGS" in o.texte(393) and re.search(r"> DEBUG DIPS +OFF", o.texte(393)) and "DIP 1" not in o.texte(393),
           "trame 393 : A ouvre encore l'écran des debug dips")
    n = [k for k in range(400, 6001) if k in o.f and k in z.f]
    diff = [k for k in n if o.h(k) != z.h(k)]
    bit = sum(1 for k in n if int(o.f[k]["m100000"], 16) & 1)
    dit(f"trames 400-6000 : {len(diff)} sur {len(n)} différentes du témoin dd-0off ; $100000 bit 0 sur {bit}")
    exiger(n and not diff, f"{len(diff)} trames différentes du témoin, dès la trame {diff[0] if diff else '-'}")
    exiger(bit == 0, f"$100000 bit 0 sur {bit} trames sous CHEATS/DEBUG OFF")

JUGES = {"aes-bascule": aes_bascule, "aes-demo": aes_demo, "aes-start": aes_start, "aes-menu": aes_menu,
         "aes-piece": aes_piece, "aes-retour": aes_retour,
         "boot-ecran": boot_ecran, "boot-saut": boot_saut, "calendrier": calendrier, "carte": carte,
         "demo-son": demo_son, "partie-credit": partie_credit, "partie-start": partie_start,
         "fin-demo": fin_demo, "fin-titre": fin_titre, "scores": scores, "dip-temps": dip_temps,
         "dip-langue": dip_langue, "region": region, "autotests": autotests, "jukebox": jukebox,
         "menu-hud": menu_hud, "menu-reprise": menu_reprise, "menu-son": menu_son, "cheats": cheats,
         "restart": restart, "ms-demo": ms_demo, "ms-select": ms_select, "ms-garde": ms_garde,
         "dip-defauts": dip_defauts, "dip-mmss": dip_mmss, "dip-fois": dip_fois, "region-europe": region_europe,
         "region-japon": region_japon, "region-usa": region_usa, "autotests-palette": autotests_palette,
         "autotests-vram": autotests_vram, "autotests-backup": autotests_backup, "tests-entrees": tests_entrees,
         "tests-barres": tests_barres, "tests-grille": tests_grille, "jukebox-pas": jukebox_pas,
         "jukebox-stop": jukebox_stop, "cheats-off": cheats_off, "partie-p2": partie_p2, "carte-sauve": carte_sauve,
         "ms-select-p2": ms_select_p2, "aes-ms-select": aes_ms_select, "aes-pause": aes_pause, "aes-logo": aes_logo, "aes-logo-fin": aes_logo_fin,
         "aes-fin": aes_fin, "aes-texte": aes_texte, "depart-force": depart_force, "piece-son": piece_son,
         "ms-seule": ms_seule, "jukebox-repete": jukebox_repete, "partie-p2-joint": partie_p2_joint,
         "carte-chercher": carte_chercher, "carte-supprimer": carte_supprimer, "carte-nom": carte_nom,
         "tests-p2": tests_p2, "tests-dip": tests_dip, "dip-sans-donnees": dip_sans_donnees,
         "gs-compte": gs_compte, "gs-defauts": gs_defauts, "gs-choix": gs_choix, "gs-mmss": gs_mmss,
         "gs-fois": gs_fois, "gs-sans-donnees": gs_sans_donnees, "gs-banque": gs_banque,
         "me-ecran": me_ecran, "me-goto": me_goto, "me-octet": me_octet, "me-ligne": me_ligne,
         "me-page": me_page, "me-repete": me_repete, "me-poke": me_poke, "me-gel": me_gel,
         "me-liste": me_liste, "me-degel": me_degel, "me-borne": me_borne,
         "bf-editeur": bf_editeur, "bf-banque": bf_banque, "bf-tests": bf_tests, "bf-jukebox": bf_jukebox,
         "sans-cartouche": sans_cartouche, "flash-cart": flash_cart, "cm-liste": cm_liste, "cm-libres": cm_libres, "cm-effacer": cm_effacer,
         "cm-annuler": cm_annuler, "cm-formater": cm_formater, "cm-non-formatee": cm_non_formatee,
         "cm-sans-carte": cm_sans_carte, "cm-protegee": cm_protegee, "cm-insertion": cm_insertion, "bf-carte": bf_carte,
         "aes-scores": aes_scores, "scores-gel": scores_gel,
         "bo-ecran": bo_ecran, "ab-ecran": ab_ecran, "bo-free-play": bo_free_play, "bo-fp-p2": bo_fp_p2, "bo-fp-joint": bo_fp_joint,
         "bo-no-continue": bo_no_continue, "bo-demo-muette": bo_demo_muette, "bo-aes": bo_aes, "bf-borne": bf_borne,
         "cheats-vies": cheats_vies, "bo-cd-menu": bo_cd_menu, "bo-cd-gel": bo_cd_gel,
         "demo-ssideki": demo_ssideki,
         "crc-fixe": crc_fixe, "crc-banques": crc_banques, "crc-miroir": crc_miroir, "crc-flottant": crc_flottant, "bf-crc": bf_crc,
         "bf-crc-banque": bf_crc_banque, "dd-effet": dd_effet, "dd-off": dd_off}
# ---- the board switches and the gesture without a TEST button (record --ref-dip) ----
def mode_a(run, n0, n1):
    return {run.f[k]["m10FDAF"] for k in range(n0, n1) if k in run.f}

def credits_apres(run, n0):
    return {run.f[k]["mD00034"] for k in range(n0, 2400) if k in run.f}

def dip_free_play():
    t, t0, p = sain("df-t", "df-t0", "df-p1")
    c = cases(t.img(2000), p.img(2000))
    d = sum(1 for k in range(600, 1600) if t.h(k) != t0.h(k))
    cr = credits_apres(p, 300)
    m = mode_a(p, 1610, 1640)
    dit(f"START à 1600 sans pièce : mode {sorted(m)}, trame 2000 {len(c)} cases diffèrent de la démo ; crédits {sorted(cr)} ;"
        f" la démo à ON diffère de celle à OFF sur {d}/1000 trames")
    exiger(len(c) >= F("dip-free-play", "cases_min"), f"{len(c)} cases : la partie ne part pas")
    exiger(m == {"2"}, f"mode {sorted(m)} après START, 2 attendu")
    exiger(cr == {"0"}, f"crédits {sorted(cr)}")
    exiger(d >= F("dip-free-play", "demo_min"), f"{d} trames : la démo dit encore INSERT COIN")
    k, k0 = sain("df-snk-t", "df-snk-t0")
    D, n = meilleur_decalage(t, k, 600, 1600)
    D0, n0 = meilleur_decalage(t, k0, 600, 1600)
    dit(f"la démo à ON : {n}/1000 trames de celle du BIOS SNK à ON (décalage {D}), {n0} de celle du BIOS SNK à OFF (décalage {D0})")
    exiger(n >= F("dip-free-play", "snk_min"), f"{n} trames de la démo SNK au commutateur à ON : la démo ne dit pas ce qu'elle dit")
    exiger(n0 <= F("dip-free-play", "snk_off_max"), f"{n0} trames de la démo SNK à OFF")

def dip_fp_p2():
    p2, p1 = sain("df-p2", "df-p1")
    j = {p2.f[k]["m10FDB4"] for k in range(1601, 1610) if k in p2.f}
    d = 800 - meme_instant(p1, p2, 1601, 2401)
    dit(f"START P2 à 1600 : BIOS_START_FLAG {sorted(j)}, {d}/800 trames diffèrent d'un START P1")
    exiger("3" in j, f"BIOS_START_FLAG {sorted(j)} : les deux joueurs ne partent pas")
    exiger(d >= F("dip-fp-p2", "diff_min"), f"{d} trames : comme un START P1")

def dip_fp_refus():
    o, t0 = sain("df-off", "df-t0")
    e = meme_instant(o, t0, 1601, 2401)
    m = mode_a(o, 1610, 2400)
    dit(f"commutateur à OFF, START à 1600 : {e}/800 trames de la démo sans START ; mode {sorted(m)}")
    exiger(e >= F("dip-fp-refus", "egales_min"), f"{e} trames de la démo : START n'est pas refusé")
    exiger(m == {"1"}, f"mode {sorted(m)}")

def dip_fp_chaud():
    ch, fr, t, t0 = sain("df-chaud", "df-froid", "df-t", "df-t0")
    a, b = meme_instant(ch, t, 1210, 1600), meme_instant(fr, t0, 1210, 1600)
    tt = meme_instant(t, t0, 1210, 1600)
    exiger(tt <= F("dip-fp-chaud", "temoins_max"), f"les démos à ON et à OFF ont {tt} trames égales : la scène ne prouve rien")
    ma, mb = mode_a(ch, 1610, 1640), mode_a(fr, 1610, 1640)
    dit(f"OFF → ON à 1200 : {a}/390 trames de la démo à ON, START → mode {sorted(ma)} ; ON → OFF : {b}/390 de la démo à OFF,"
        f" START → mode {sorted(mb)} ; les deux démos entre elles : {tt}")
    exiger(a >= F("dip-fp-chaud", "apres_min"), f"OFF → ON : {a} trames, CREDIT_CHECK ne relit pas le commutateur")
    exiger(b >= F("dip-fp-chaud", "apres_min"), f"ON → OFF : {b} trames")
    exiger(ma == {"2"}, f"OFF → ON : START → mode {sorted(ma)}, la partie ne part pas")
    exiger(mb == {"1"}, f"ON → OFF : START → mode {sorted(mb)}, accepté sans crédit")

def dip_fp_reglage():
    (s,) = sain("bo-set-fp")
    bo_reglage(s, r"FREE PLAY +ON")
    f, t = sain("dfr", "bo-dm0")
    c = cases(t.img(1400), f.img(1400))
    m = mode_a(f, 1010, 1040)
    dit(f"commutateur à OFF, FREE PLAY ON : START à 1000 → mode {sorted(m)}, trame 1400 {len(c)} cases diffèrent de la démo")
    exiger(m == {"2"}, f"mode {sorted(m)} : START refusé")
    exiger(len(c) >= F("dip-fp-reglage", "cases_min"), f"{len(c)} cases : la partie ne part pas")

def dip_fp_cabinet():
    (c,) = sain("df-cab")
    t1, t2 = c.texte(325), c.texte(365)
    v = memoire(c, 500, "D0021D")
    dit(f"CABINET SETTINGS sous le commutateur : {' / '.join(lignes_liste(c, 325))} ; $D0021D = {v}")
    exiger(re.search(r"> FREE PLAY +DIP", t1), "FREE PLAY ne dit pas DIP")
    exiger(re.search(r"> FREE PLAY +DIP", t2), "droite a changé FREE PLAY sous le commutateur")
    exiger(re.search(r"NO CONTINUE +OFF", t1) and re.search(r"CHEATS/DEBUG +ON", t1), "les autres lignes ont bougé")
    exiger(v == 0, f"$D0021D vaut {v} : le réglage enregistré a changé")

def dip_setting():
    d, b = sain("ds", "ds-bascule")
    r = [k for k, e in d.ev if e == "REMISE"]
    rb = [k for k, e in b.ev if e == "REMISE"]
    dit(f"commutateur 1 à ON : trame 500 « {d.fix.get(500, {}).get(3, '').strip()} », trame 650 « {d.fix.get(650, {}).get(13, '').strip()} » ;"
        f" remises {r[:3]} ; rebasculé à OFF à 550 : trame 650 « {b.fix.get(650, {}).get(13, '').strip()} », remises {rb[:3]}")
    exiger("SOFT DIP SETTINGS" in d.texte(500), "l'écran TEST ne s'ouvre pas")
    exiger(not [k for k in r if k < 500], "la main au jeu avant l'écran TEST")
    exiger("DIP SWITCH 1 IS ON" in d.texte(650), "START, commutateur à ON : pas d'avertissement")
    exiger([k for k in r if k > 600], "START ne rend pas la main au jeu")
    exiger(min(k for k in r if k > 600) - 600 >= F("dip-setting", "avert_min"), "la main au jeu sans laisser lire l'avertissement")
    exiger("SOFT DIP SETTINGS" in b.texte(500), "ds-bascule : l'écran TEST ne s'ouvre pas")
    av = [k for k in range(600, 651) if "DIP SWITCH 1" in b.texte(k)]
    exiger(not av, f"rebasculé à OFF : l'avertissement quand même (trames {av[:3]})")
    exiger([k for k in rb if k > 600] and min(k for k in rb if k > 600) - 600 <= F("dip-setting", "direct_max"),
           "rebasculé à OFF : la main au jeu tarde")
    (d0,) = sain("ds0")
    r0 = [k for k, e in d0.ev if e == "REMISE"]
    dit(f"commutateur 1 à OFF : remises {r0[:2]}")
    exiger("SOFT DIP SETTINGS" not in d0.texte(500), "l'écran TEST s'ouvre commutateur 1 à OFF")
    exiger([k for k in r0 if k < 300], "commutateur 1 à OFF : pas de main au jeu")

def geste_boot():
    g, g0 = sain("gb", "gb0")
    r0 = [k for k, e in g0.ev if e == "REMISE"]
    dit(f"START + SELECT au boot : trame 300 {'écran TEST' if 'SOFT DIP SETTINGS' in g.texte(300) else 'autre'} ;"
        f" START seul : remises {r0[:2]}")
    exiger("SOFT DIP SETTINGS" in g.texte(300), "START + SELECT n'ouvre pas l'écran TEST")
    exiger("SOFT DIP SETTINGS" not in g0.texte(300), "START seul ouvre l'écran TEST")
    exiger([k for k in r0 if k < 300], "START seul : pas de main au jeu")
    (gs,) = sain("gb-sel")
    rs = [k for k, e in gs.ev if e == "REMISE"]
    dit(f"SELECT seul : remises {rs[:2]}")
    exiger("SOFT DIP SETTINGS" not in gs.texte(300), "SELECT seul ouvre l'écran TEST")
    exiger([k for k in rs if k < 300], "SELECT seul : pas de main au jeu")
    ga, gA = sain("gb-adapt", "gb-a")
    ra = [k for k, e in ga.ev if e == "REMISE"]
    dit(f"l'adaptateur (START, SELECT, A, B, C, D) : remises {ra[:2]} ; START + SELECT + A : trame 300"
        f" {'écran TEST' if 'SOFT DIP SETTINGS' in gA.texte(300) else 'autre'}")
    exiger("SOFT DIP SETTINGS" not in ga.texte(300), "l'adaptateur ouvre l'écran TEST")
    exiger([k for k in ra if k < 300], "l'adaptateur : pas de main au jeu")
    exiger("SOFT DIP SETTINGS" in gA.texte(300), "START + SELECT + A n'ouvre pas l'écran TEST")

def geste_jeu():
    g, g0 = sain("gj", "gj0")
    pg = [x for x in g.pauses() if x[0] > 1500]
    p0 = [x for x in g0.pauses() if x[0] > 1500]
    dit(f"START + SELECT en partie : pauses {pg[:2]} ; START seul : {p0[:2]}")
    exiger("IN-GAME MENU" in g.texte(1800), "START + SELECT n'ouvre pas le menu en jeu")
    exiger(pg and pg[0][1] - pg[0][0] >= F("geste-jeu", "pause_min"), "le jeu n'est pas en pause")
    exiger("IN-GAME MENU" not in g0.texte(1800), "START seul ouvre le menu")
    exiger(not p0 or p0[0][1] - p0[0][0] < F("geste-jeu", "pause_min"), f"START seul : pause {p0[:1]}")
    (gs,) = sain("gj-sel")
    ps = [x for x in gs.pauses() if x[0] > 1500]
    dit(f"SELECT seul : {ps[:2]}")
    exiger("IN-GAME MENU" not in gs.texte(1800), "SELECT seul ouvre le menu")
    exiger(not ps or ps[0][1] - ps[0][0] < F("geste-jeu", "pause_min"), f"SELECT seul : pause {ps[:1]}")
    ga, gA = sain("gj-adapt", "gj-a")
    pa = [x for x in ga.pauses() if x[0] > 1500]
    pA = [x for x in gA.pauses() if x[0] > 1500]
    ca = compte_geste(ga, 1690, 2000)
    dit(f"l'adaptateur (START, SELECT, A, B, C, D) : pauses {pa[:2]}, compte du geste au plus {ca} ;"
        f" START + SELECT + A : pauses {pA[:2]}")
    exiger("IN-GAME MENU" not in ga.texte(1800), "l'adaptateur ouvre le menu en jeu")
    exiger(not pa or pa[0][1] - pa[0][0] < F("geste-jeu", "pause_min"), f"l'adaptateur : pause {pa[:1]}")
    exiger(ca < 20, f"l'adaptateur : le compte du geste atteint {ca}")
    exiger("IN-GAME MENU" in gA.texte(1800), "START + SELECT + A n'ouvre pas le menu en jeu")
    exiger(pA and pA[0][1] - pA[0][0] >= F("geste-jeu", "pause_min"), "START + SELECT + A : le jeu n'est pas en pause")

def compte_geste(run, n0, n1):
    # MN_COMPTE, signed .w: $FFFF after a close (wait for the release), counted as 0.
    v = [int(run.f[k]["m10F800"], 16) for k in range(n0, n1) if "m10F800" in run.f.get(k, {})]
    return max([x for x in v if x < 0x8000] or [0])

def geste_partie():
    (g,) = sain("gj")
    exiger(compte_geste(g, 1700, 2000) >= 20, "le compte du témoin n'atteint pas 20 : l'instrument ne voit rien")
    for j in ("aof", "mslug", "samsho4", "ssideki"):
        (p,) = sain(f"gp-{j}")
        d = min([k for k in p.f if p.f[k].get("m10FDAF") == "2"] or [None])
        exiger(d is not None and d < 1100, f"{j} : pas de partie avant 1100")
        c = compte_geste(p, d, 6001)
        lp = max([b - a + 1 for a, b in p.pauses() if b >= d] or [0])
        en = sum(1 for k in range(d, 6001) if p.f.get(k, {}).get("m10FDAF") == "2")
        dit(f"{j} : en partie dès {d}, {en} trames en mode 2 ; compte du geste au plus {c}, plus longue pause {lp}")
        exiger(c < F("geste-partie", "compte_max"), f"{j} : le compte du geste atteint {c}")
        exiger(lp < F("geste-partie", "pause_min"), f"{j} : une pause de {lp} trames")

# ---- the labels in the JAPAN region (measured/2026-10-27-intitules-japon.tsv) ----
def intitules_snk(run, n):
    """The labels of the Japanese SNK BIOS: the rows in bank $3 (upper half), columns 6-17, as bytes, without the
    trailing spaces; one per setting."""
    r = []
    for row, t in sorted(run.tu.get(n, {}).items()):
        if any((x >> 8) & 0xF == 3 for x in t[6:18]):
            b = bytes(x & 0xFF for x in t[6:18]).rstrip(b" ")
            if b:
                r.append(b)
    return r

def lu_notre(t):
    """A row of the fix layer as bytes: None where the cell cannot be that byte. A byte whose glyph is the same in
    both banks of the card's font ($20-$5E, $61-$7B: measured/2026-10-27-intitules-japon.tsv, section 2) is
    written in 8×8 (bank 0), as $100 + b or as $300 + b; any other, only as $300 + b (the recorded rule)."""
    o = []
    for x in t:
        b, k = x & 0xFF, (x >> 8) & 0xF
        egal = 0x20 <= b <= 0x5E or 0x61 <= b <= 0x7B
        o.append(b if (k == 3 or (k in (0, 1) and egal)) else None)
    return o

def japon_intitules():
    j, k = sain("ij-notre", "ij-snk")
    exiger("REGION ....... JAPAN" in j.texte(450), "l'écran de boot ne dit pas REGION JAPAN")
    exiger("SOFT DIP SETTINGS" in j.texte(1100), "l'écran TEST n'est pas ouvert à 1100")
    ref = intitules_snk(k, 1400)
    exiger(len(ref) >= 8, f"{len(ref)} intitulés au témoin SNK : sa navigation n'a pas mené à l'écran des soft-DIP")
    rangs = [lu_notre(t) for _, t in sorted(j.tu.get(1100, {}).items())]
    def trouve(b):
        n = len(b)
        return any(all(r[i + q] == b[q] for q in range(n)) for r in rangs for i in range(len(r) - n + 1))
    manque = [b.hex() for b in ref if not trouve(b)]
    hors = sum(1 for b in ref for c in b if not 0x20 <= c <= 0x7E)
    dit(f"{len(ref)} intitulés au témoin SNK, {hors} octets hors ASCII ; {len(ref) - len(manque)} retrouvés tels quels")
    exiger(hors > 0, "le témoin n'a aucun octet hors ASCII : la scène ne prouve rien")
    exiger(not manque, f"{len(manque)} intitulés absents de notre écran, comme suite de tuiles : {manque[:3]}")

def liste_cadre(run, n):
    """GAME SETTINGS: lines 3 to 10 of the box (rows 12 to 19), ">" removed, as on screen."""
    return [run.fix.get(n, {}).get(r, "")[8:34].rstrip() for r in range(12, 20)]

def cadre_sans_banque_japon(run, n):
    """No tile from banks $3/$4 in the box (rows 9 to 22, columns 6 to 33): under the cartridge's S ROM,
    these tiles draw the game's scenery (measured/2026-10-27-intitules-japon.tsv, section 3)."""
    return [(r, c) for r, t in run.tu.get(n, {}).items() if 9 <= r <= 22 for c in range(6, 34) if (t[c] >> 8) & 0xF in (3, 4)]

def gs_japon():
    j, u = sain("gsj-ss", "gsu-ss")
    exiger("REGION ....... JAPAN" in j.texte(450), "l'écran de boot ne dit pas REGION JAPAN")
    exiger("GAME SETTINGS" in j.texte(2100) and "GAME SETTINGS" in u.texte(2100), "GAME SETTINGS n'est pas ouvert à 2100")
    lj, lu = liste_cadre(j, 2100), liste_cadre(u, 2100)
    pleins = [x for x in lu if x[:12].strip()]
    dit(f"JAPAN : {' / '.join(x for x in lj if x)}")
    exiger(len(pleins) >= 8, f"{len(pleins)} intitulés en USA : le témoin ne prouve rien")
    exiger(lj == lu, f"JAPAN et USA diffèrent : {[a for a, b in zip(lj, lu) if a != b][:3]}")
    h = cadre_sans_banque_japon(j, 2100)
    exiger(not h, f"{len(h)} cases du cadre en banque $3/$4, sous la police de la cartouche")

def gs_japon_garde():
    j, u = sain("gsj-bs", "gsu-bs")
    exiger("REGION ....... JAPAN" in j.texte(450), "l'écran de boot ne dit pas REGION JAPAN")
    lj, lu = liste_cadre(j, 2100), liste_cadre(u, 2100)
    iu = {x[:12].strip() for x in lu if x[:12].strip()} - {"RESET TO DEF", "RESTART GAME"}
    ij = [x[:12].strip() for x in lj]
    dit(f"JAPAN : {' / '.join(x for x in lj if x)} ; intitulés USA : {sorted(iu)}")
    exiger(iu, "aucun intitulé en USA : le témoin ne prouve rien")
    exiger(any("RESET TO DEFAULTS" in x for x in lj), "GAME SETTINGS n'a pas sa liste en JAPAN")
    pris = [x for x in ij if x in iu]
    exiger(not pris, f"des intitulés du bloc USA, de structure différente, en JAPAN : {pris}")
    h = cadre_sans_banque_japon(j, 2100)
    exiger(not h, f"{len(h)} cases du cadre en banque $3/$4, sous la police de la cartouche")

JUGES.update({"japon-intitules": japon_intitules, "gs-japon": gs_japon, "gs-japon-garde": gs_japon_garde})
JUGES.update({"dip-free-play": dip_free_play, "dip-fp-p2": dip_fp_p2, "dip-fp-refus": dip_fp_refus,
              "dip-fp-chaud": dip_fp_chaud, "dip-fp-cabinet": dip_fp_cabinet, "dip-setting": dip_setting,
              "geste-boot": geste_boot, "geste-jeu": geste_jeu, "dip-fp-reglage": dip_fp_reglage,
              "geste-partie": geste_partie})
# ---- The board switches 2, 3 and 8 ----
def figees_dans(run, n0, n1):
    """The frames of [n0, n1[ whose image equals that of the previous frame."""
    return sum(1 for k in range(n0, n1) if run.h(k) is not None and run.h(k) == run.h(k - 1))

def reprise_decalee(a, b, n0, n1, d):
    """The frames k of [n0, n1[ of a equal to frame k − d of b: a resumed where b was."""
    return sum(1 for k in range(n0, n1) if a.h(k) is not None and a.h(k) == b.h(k - d))

def dip_gel():
    g, g0, gs = sain("gel", "gel0", "gel-snk")
    f, f0, fs = figees_dans(g, 2003, 2300), figees_dans(g0, 2003, 2300), figees_dans(gs, 2003, 2300)
    r = reprise_decalee(g, g0, 2310, 2800, 300)
    ym, ym0 = sum(int(g.f[k]["ym"]) for k in range(2003, 2300)), sum(int(g0.f[k]["ym"]) for k in range(2003, 2300))
    reset = [k for k, e in g.ev if e == "RESET"]
    m = mode_a(g, 2003, 2300)
    dit(f"commutateur 8 à ON de 2000 à 2300, en partie : {f}/297 trames figées (sans gel {f0}, BIOS SNK {fs}) ;"
        f" après : {r}/490 trames égales au run sans gel 300 trames plus tôt ; YM2610 {ym} écritures (sans gel {ym0}) ;"
        f" mode {sorted(m)}, RESET {reset[:3]}")
    exiger(fs >= F("dip-gel", "figees_min"), f"le témoin SNK n'a que {fs} trames figées : l'instrument ne voit pas le gel")
    exiger(f >= F("dip-gel", "figees_min"), f"{f} trames figées : le jeu n'est pas suspendu")
    exiger(f0 <= F("dip-gel", "figees_off_max"), f"le run sans gel a {f0} trames figées : la scène ne prouve rien")
    exiger(r >= F("dip-gel", "reprise_min"), f"{r} trames : le jeu ne reprend pas où il était")
    exiger(ym >= F("dip-gel", "ym_ratio_min") * ym0, f"{ym} écritures au YM2610 contre {ym0} : le son est coupé")
    exiger(m == {"2"}, f"mode {sorted(m)} pendant le gel")
    exiger(not reset, f"RESET pendant le gel : {reset[:3]}")

def dip_gel_off():
    g0, d0 = sain("gel0", "ds0")
    f0 = figees_dans(g0, 2003, 2300)
    r0 = [k for k, e in d0.ev if e == "REMISE"]
    dit(f"commutateur 8 à OFF : {f0}/297 trames figées en partie ; au boot, remises {r0[:2]}")
    exiger(f0 <= F("dip-gel", "figees_off_max"), f"{f0} trames figées commutateur 8 à OFF")
    exiger("DIP SWITCH 8" not in d0.texte(500), "le message du gel, commutateur 8 à OFF")
    exiger([k for k in r0 if k < 300], "commutateur 8 à OFF : pas de main au jeu avant 300")

def dip_gel_boot():
    b, bs = sain("gelb", "gelb-snk")
    r, rs = [k for k, e in b.ev if e == "REMISE"], [k for k, e in bs.ev if e == "REMISE"]
    dit(f"commutateur 8 à ON au boot, OFF à 1000 : trame 500 « {b.fix.get(500, {}).get(11, '').strip()} » /"
        f" « {b.fix.get(500, {}).get(15, '').strip()} » ; remises {r[:2]} (BIOS SNK {rs[:2]})")
    exiger(not [k for k in rs if k < 1000] and [k for k in rs if k > 1000], f"le témoin SNK : remises {rs[:3]}")
    exiger("DIP SWITCH 8 IS ON" in b.texte(500) and "SET IT OFF TO CONTINUE" in b.texte(500), "pas de message à l'écran")
    exiger(not [k for k in r if k < 1000], f"la main au jeu commutateur 8 encore à ON : {r[:3]}")
    exiger([k for k in r if k > 1000] and min(k for k in r if k > 1000) - 1000 <= F("dip-gel-boot", "reprise_max"),
           f"le boot ne reprend pas au commutateur remis à OFF : {r[:3]}")

# The keys of TOUCHES_MJ (`parcours.sh`): (frame, keys); a key = (row, bit) — mahjong.cpp.
RANGEES_MJ = {k: (0, i) for i, k in enumerate("ABCDEFG")}
RANGEES_MJ.update({k: (1, i) for i, k in enumerate("HIJKLMN")})
RANGEES_MJ.update({k: (2, i) for i, k in enumerate(("Pon", "Chi", "Kan", "Ron", "Reach"))})
TOUCHES_MJ = [(1900 + 40 * i, (k,)) for i, k in enumerate(list("ABCDEFGHIJKLMN") + ["Pon", "Chi", "Kan", "Ron", "Reach"])]
TOUCHES_MJ += [(2660, ("A", "H", "Pon")), (2700, ("A", "B"))]

def octets_mj(run, k):
    return [memoire(run, k, a) for a in ("10FD95", "10FD96", "10FD97")], [memoire(run, k, a) for a in ("10FDA1", "10FDA2", "10FDA3")]

def dip_mahjong():
    b, z, bs, zs = sain("mj-b", "mj-0", "mj-b-snk", "mj-0-snk")
    e, es = meme_instant(b, z, 1702, 2100), meme_instant(bs, zs, 1702, 2100)
    dit(f"commutateur 3 à ON, B du panneau à 1700 (choix du mode) : {398 - e}/398 trames diffèrent du run sans B"
        f" (BIOS SNK {398 - es})")
    exiger(398 - es >= F("dip-mahjong", "diff_min"), f"le témoin SNK : {398 - es} trames, B n'y agit pas")
    exiger(398 - e >= F("dip-mahjong", "diff_min"), f"{398 - e} trames : le jeu ne voit pas B")
    exiger({memoire(b, k, "10FD94") for k in range(1600, 2100)} == {3}, "BIOS_P1STATUS n'est pas 3")
    (t,) = sain("mj-touches")
    faux = []
    for n, ks in TOUCHES_MJ:
        att = [0, 0, 0]
        for k in ks:
            r, i = RANGEES_MJ[k]
            att[r] |= 1 << i
        cur, front = octets_mj(t, n + 5)
        cur1, front1 = octets_mj(t, n + 1)
        _, front3 = octets_mj(t, n + 3)
        if cur != att or front1 != att or front3 != [0, 0, 0] or cur1 != att:
            faux.append(f"{'+'.join(ks)} : rangées {cur} fronts {front1}/{front3}, attendu {att}")
    dit(f"les {len(TOUCHES_MJ)} appuis : {len(TOUCHES_MJ) - len(faux)} lus comme la référence")
    exiger(not faux, "; ".join(faux[:3]))
    (c,) = sain("mj-chaud")
    v0, v1 = memoire(c, 1400, "10FD94"), memoire(c, 1600, "10FD94")
    dit(f"basculé à ON à 1000 : BIOS_P1STATUS {v0} à 1400, {v1} à 1600 (pièce à 1500)")
    exiger(v0 == 0 and v1 == 3, f"BIOS_P1STATUS {v0} puis {v1} : pas relu à la pièce")

def dip_mj_off():
    b, z = sain("mjo-b", "mjo-0")
    e = meme_instant(b, z, 1702, 2100)
    dit(f"commutateur 3 à OFF, B du panneau à 1700 : {e}/398 trames égales au run sans B")
    exiger(e >= F("dip-mj-off", "egales_min"), f"{e} trames : B agit commutateur 3 à OFF")
    (t,) = sain("mjo-touches")
    faux = []
    for n, ks in TOUCHES_MJ:
        att = 0
        for k in ks:
            r, i = RANGEES_MJ[k]
            if r < 2:
                att |= 1 << i
        cur = memoire(t, n + 5, "10FD96")
        if cur != att:
            faux.append(f"{'+'.join(ks)} : BIOS_P1CURRENT {cur}, attendu {att}")
    st = {memoire(t, k, "10FD94") for k in range(1600, 2740)}
    dit(f"les {len(TOUCHES_MJ)} appuis lus en joystick (rangées A-G et H-N) : {len(TOUCHES_MJ) - len(faux)} ; BIOS_P1STATUS {sorted(st)}")
    exiger(st == {0}, f"BIOS_P1STATUS {sorted(st)}")
    exiger(not faux, "; ".join(faux[:3]))

def bandeau(run, n):
    """The cells at the bottom of the screen (lines 26 to 27 of the fix layer: y 208-223) where the image is not black."""
    a = run.img(n)
    return {(x // 8, y // 8) for y in range(208, 224) for x in range(320)
            if (a[y * 320 + x] & 255) + ((a[y * 320 + x] >> 8) & 255) + ((a[y * 320 + x] >> 16) & 255) > 24}

def dip_4p():
    a, a0, s, s0 = sain("4p", "4p0", "4p-snk", "4p0-snk")
    # The demo of the SNK BIOS starts ~560 frames after ours (750 against 189): its screen is
    # taken at 1460.
    c, c0, cs, cs0 = len(bandeau(a, 900)), len(bandeau(a0, 900)), len(bandeau(s, 1460)), len(bandeau(s0, 1460))
    v = {memoire(a, k, "10FEF8") for k in range(400, 1000)}
    dit(f"kizuna, commutateur 2 à ON : $10FEF8 {sorted(v)} ; le bas de l'écran à 900 : {c} cases allumées (OFF {c0}) ;"
        f" BIOS SNK japonais, à 1460 : {cs} (OFF {cs0})")
    exiger(cs - cs0 >= F("dip-4p", "cases_min"), f"le témoin SNK : {cs} contre {cs0} cases, le second compteur n'y est pas")
    exiger(v == {2}, f"$10FEF8 {sorted(v)}")
    exiger(c - c0 >= F("dip-4p", "cases_min"), f"{c} contre {c0} cases : le second compteur CREDIT n'est pas affiché")
    (h,) = sain("4p-chaud")
    v0, v1 = memoire(h, 1400, "10FEF8"), memoire(h, 1600, "10FEF8")
    dit(f"basculé à ON à 1000 : $10FEF8 {v0} à 1400, {v1} à 1600 (pièce à 1500)")
    exiger(v0 == 0 and v1 == 2, f"$10FEF8 {v0} puis {v1} : pas relu à la pièce")

def dip_4p_off():
    a0, r = sain("4p0", "4p-retour")
    v = {memoire(a0, k, "10FEF8") for k in range(400, 1000)}
    v0, v1 = memoire(r, 1400, "10FEF8"), memoire(r, 1600, "10FEF8")
    dit(f"kizuna, commutateur 2 à OFF : $10FEF8 {sorted(v)}, le bas de l'écran {len(bandeau(a0, 900))} cases ;"
        f" basculé à OFF à 1000 : {v0} à 1400, {v1} à 1600")
    exiger(v == {0}, f"$10FEF8 {sorted(v)} commutateur à OFF")
    exiger(v0 == 2 and v1 == 0, f"$10FEF8 {v0} puis {v1} : le retour à OFF n'est pas relu à la pièce")

JUGES.update({"dip-gel": dip_gel, "dip-gel-off": dip_gel_off, "dip-gel-boot": dip_gel_boot, "dip-mahjong": dip_mahjong,
              "dip-mj-off": dip_mj_off, "dip-4p": dip_4p, "dip-4p-off": dip_4p_off})
# ---- The autofire ----
def bit_a(run, n0, n1, adr="10FD95", bit=4):
    return [(memoire(run, k, adr) >> bit) & 1 for k in range(n0, n1)]

def af_ecran(run, n, etat):
    t = run.texte(n)
    return "AUTOFIRE" in t and re.search(r"BUTTON A +" + etat, t)

def af_tir():
    t, m, r = sain("af-t", "af-m", "af-r")
    e, d = meme_instant(t, m, 1300, 2400), 1100 - meme_instant(t, r, 1300, 2400)
    a = bit_a(t, 1302, 2300)
    motif = sum(1 for i, v in enumerate(a) if v == (1 if i % 4 < 2 else 0))
    dit(f"viewpoin, A à ON, tenu : {e}/1100 trames égales au run où A est tapé, {d}/1100 qui diffèrent du run où A est"
        f" tenu sans turbo ; BIOS_P1CURRENT au motif sur {motif}/{len(a)} trames")
    exiger(re.search(r"> *AUTOFIRE", t.texte(1060)), "« haut » trois fois ne mène pas à AUTOFIRE")
    exiger(af_ecran(t, 1066, "OFF") and af_ecran(t, 1072, "ON"), "l'écran AUTOFIRE ne dit pas BUTTON A OFF puis ON")
    exiger(e >= F("af-tir", "egales_min"), f"{e} trames égales au run tapé : le jeu ne voit pas le motif")
    exiger(d >= F("af-tir", "diff_min"), f"{d} trames : le turbo ne change rien au jeu")
    exiger(motif >= F("af-tir", "ram_min"), f"BIOS_P1CURRENT au motif sur {motif} trames")

def af_sauve():
    t, s, s0 = sain("af-t", "af-sauve", "af-sauve0")
    e, d = meme_instant(s, t, 1300, 2400), 1100 - meme_instant(s, s0, 1300, 2400)
    ngh, x = memoire(t, 2399, "D001B4"), memoire(t, 2399, "D001B6")
    dit(f"NVRAM d'af-t, rien changé : {e}/1100 trames égales à af-t, {d}/1100 qui diffèrent du run remis à OFF ;"
        f" la fiche ${ngh:04X} ${x:04X}")
    exiger(af_ecran(s, 1066, "ON"), "au redémarrage, l'écran AUTOFIRE ne dit pas BUTTON A ON")
    exiger(ngh == 0x51 and x >> 8 == 0x11, f"la fiche en backup RAM : ${ngh:04X} ${x:04X}")
    exiger(e >= F("af-sauve", "egales_min"), f"{e} trames égales à af-t : le réglage n'est pas repris")
    exiger(d >= F("af-sauve", "diff_min"), f"{d} trames : la scène ne prouve rien")

def af_off():
    t, s0, r, rl = sain("af-t", "af-sauve0", "af-r", "af-relu")
    e, el = meme_instant(s0, r, 1300, 2400), meme_instant(rl, r, 1300, 2400)
    c, cl = sum(bit_a(s0, 1302, 2300)), sum(bit_a(rl, 1302, 2300))
    dit(f"A remis à OFF : {e}/1100 trames égales au run sans turbo, A vu {c}/998 trames ; relu après redémarrage :"
        f" {el}/1100, A vu {cl}/998")
    exiger(af_ecran(s0, 1066, "ON") and af_ecran(s0, 1072, "OFF"), "l'écran ne dit pas BUTTON A ON puis OFF")
    # Before its key (left, which would set back to OFF an entry left at ON), af-relu must
    # already say OFF.
    exiger(af_ecran(rl, 1066, "OFF"), "relu : l'écran AUTOFIRE ne dit pas BUTTON A OFF, la fiche ON est restée")
    exiger(memoire(s0, 2399, "D001B4") != 0x51, "la fiche de viewpoin reste en backup RAM après OFF")
    exiger(e >= F("af-off", "egales_min") and c == 998, f"A à OFF : {e} trames égales, A vu {c} : le turbo reste")
    exiger(el >= F("af-off", "egales_min") and cl == 998, f"relu : {el} trames égales, A vu {cl} : OFF n'est pas enregistré")

def af_mahjong():
    a, a0, o = sain("mjaf", "mjaf0", "mjoaf")
    e = meme_instant(a, a0, 1690, 2100)
    rang = {memoire(a, k, "10FD95") for k in range(1702, 2100)}
    b = bit_a(o, 1702, 2100)
    bascules = sum(1 for x, y in zip(b, b[1:]) if x != y)
    ch = memoire(a, 1690, "10FB40")
    dit(f"janshin, commutateur 3 à ON, fiche A à ON ($10FB40 = ${ch:04X}), E tenu : {e}/410 trames égales au run sans fiche,"
        f" rangée A-G {sorted(rang)} ; commutateur 3 à OFF : {bascules} bascules de A")
    exiger(ch == 0x1110, f"la fiche n'est pas chargée : $10FB40 = ${ch:04X}, la scène ne prouve rien")
    exiger(bascules >= F("af-mahjong", "bascules_min"), f"{bascules} bascules commutateur 3 à OFF : la scène ne prouve rien")
    exiger(e >= F("af-mahjong", "egales_min"), f"{e} trames égales au run sans fiche")
    exiger(rang == {0x10}, f"la rangée A-G vaut {sorted(rang)} : le turbo touche le panneau")

JUGES.update({"af-tir": af_tir, "af-sauve": af_sauve, "af-off": af_off, "af-mahjong": af_mahjong})
# ---- The guarantees on UniBIOS defects (record --ref-garanties) ----
def premiere_palette(run):
    """The first frame where the BIOS writes a palette: the boot screen starts (`ecran.s`, frame 0)."""
    t = [k for k in sorted(run.f) if int(run.f[k].get("palB", "0")) > 0]
    exiger(t, f"{run.nom} : aucune écriture de palette du BIOS")
    return t[0]

def differentes(a, b, n0, n1):
    return [k for k in range(n0, n1) if a.h(k) is not None and b.h(k) is not None and a.h(k) != b.h(k)]

def boot_graphismes():
    n, b = sain("bg", "bg-brouille")
    # The UniBIOS witness run: neither our image nor SNK's, and the fixture carries WRONG
    # CHECKSUMS anyway; only MAME's exit code is required.
    for x in ("bg-uni", "bg-uni-brouille"):
        rc = open(os.path.join(RUNS, x, "rc")).read().strip() if os.path.exists(os.path.join(RUNS, x, "rc")) else "?"
        exiger(rc == "0", f"run {x} : MAME sorti en {rc}")
    u, ub = Run("bg-uni"), Run("bg-uni-brouille")
    rn, rb = [k for k, e in n.ev if e == "REMISE"], [k for k, e in b.ev if e == "REMISE"]
    exiger(rn and rb and rn[0] == rb[0], f"remises {rn[:2]} et {rb[:2]}")
    k0, r = premiere_palette(n) + 1, rn[0]
    d = differentes(n, b, k0, r + 1)
    j = differentes(n, b, r + 5, r + 505)
    du = differentes(u, ub, 60, 250)
    dit(f"l'écran de boot, trames {k0}-{r} : {len(d)} diffèrent sous la cartouche brouillée {d[:5]} ; après la remise,"
        f" {len(j)}/500 ; UniBIOS 4.0, trames 60-249 (son logo) : {len(du)}/190")
    exiger(len(du) >= F("boot-graphismes", "uni_min"), f"UniBIOS : {len(du)} trames, l'instrument ne voit pas son logo brouillé")
    exiger(len(j) >= F("boot-graphismes", "jeu_min"), f"{len(j)} trames du jeu diffèrent : la fixture n'agit pas")
    exiger(len(d) <= F("boot-graphismes", "differ_max"), f"{len(d)} trames de l'écran de boot changent avec les graphismes de la cartouche : {d[:5]}")

def ms_son_slot2():
    n, s = sain("s2-son", "s2-son-snk")
    def servi(run):
        r = [k for k, e in run.ev if e == "REMISE"]
        exiger(r, f"{run.nom} : aucune remise")
        sl = [e for k, e in run.ev if e.startswith("SLOT") and k <= r[0]]
        return sl[-1] if sl else None
    rn, rs = n.rms(600, 3600), s.rms(600, 3600)
    kn, ks = n.keyon(600, 3600), s.keyon(600, 3600)
    dit(f"aof au slot 2, le slot 1 vide : {servi(n)} servi (SNK {servi(s)}) ; RMS {rn:.0f} / SNK {rs:.0f}, key-on {kn} / SNK {ks}")
    exiger(rs > 0 and ks > 0, "le témoin SNK est muet")
    exiger(servi(n) == "SLOT 01", f"le slot servi : {servi(n)}")
    exiger(rn >= F("ms-son-slot2", "rms_ratio_min") * rs, f"RMS {rn / rs:.2f} du témoin")
    exiger(kn >= F("ms-son-slot2", "keyon_ratio_min") * ks, f"key-on {kn / ks:.2f} du témoin")

def dip_vierge():
    z, n, c = sain("vierge-0", "vierge-n", "vierge-c")
    def bloc(run, k, a0=0x220):
        return [memoire(run, k, "%06X" % (0xD00000 + a)) for a in range(a0, a0 + 16, 2)]
    exiger(memoire(n, 1, "D00124") == 0x0202 and bloc(n, 1)[0] == 0x9999, f"vierge-n : la NVRAM posée n'est pas lue {bloc(n, 1)[:2]}")
    exiger(memoire(c, 1, "D00124") == 0x0044 and bloc(c, 1)[0] == 0x9999, f"vierge-c : la NVRAM posée n'est pas lue {bloc(c, 1)[:2]}")
    ref = bloc(z, 400)
    for r in (n, c):
        b = bloc(r, 400)
        img = cases(z.img(3000), r.img(3000))
        dit(f"{r.nom} : bloc enregistré {' '.join('%04X' % x for x in b)} (NVRAM neuve : {' '.join('%04X' % x for x in ref)}) ;"
            f" trame 3000, {len(img)} cases diffèrent")
        for k in (250, 330):
            exiger(r.texte(k) == z.texte(k), f"{r.nom} : l'éditeur, trame {k}, diffère de celui d'une NVRAM neuve")
        exiger(b == ref, f"{r.nom} : le bloc enregistré n'est pas celui d'une NVRAM neuve")
        exiger(len(img) <= F("dip-vierge", "cases_max"), f"{r.nom} : {len(img)} cases à la trame 3000")
    exiger(bloc(n, 400, 0x230) == bloc(n, 1, 0x230), "vierge-n : le bloc 1, d'une autre entrée, a changé")
    exiger(memoire(n, 400, "D002A0") == memoire(z, 400, "D002A0"), "vierge-n : le nom du jeu n'est pas écrit")
    # mslug: the block in the banked area, which `_dip_valider` leaves; only the editor makes
    # the values valid.
    m0, m = sain("vierge-m0", "vierge-m")
    bm, bm0 = bloc(m, 400), bloc(m0, 400)
    dit(f"vierge-m (mslug) : bloc enregistré {' '.join('%04X' % x for x in bm)} (NVRAM neuve : {' '.join('%04X' % x for x in bm0)})")
    exiger(memoire(m, 1, "D00124") == memoire(m0, 400, "D00124") and bloc(m, 1)[0] == 0x9999,
           f"vierge-m : la NVRAM posée n'est pas lue {bloc(m, 1)[:2]}")
    for k in (250, 330):
        exiger(m.texte(k) == m0.texte(k), f"vierge-m : l'éditeur, trame {k}, diffère de celui d'une NVRAM neuve")
    exiger(bm == bm0, "vierge-m : le bloc enregistré n'est pas celui d'une NVRAM neuve")

def dip_corrompue():
    c, z = sain("corrompue", "corrompue-0")
    gd = lambda r: [memoire(r, 300, "10FD%02X" % a) for a in range(0x84, 0x94, 2)]
    e = meme_instant(c, z, 1000, 3000)
    dit(f"GAME_DIP à 300 : {' '.join('%04X' % x for x in gd(c))} (témoin {' '.join('%04X' % x for x in gd(z))}) ;"
        f" {e}/2000 trames égales au témoin")
    exiger(memoire(c, 300, "D00220") == 0x9999, "le bloc posé n'est pas lu : la scène ne prouve rien")
    exiger(gd(c) == gd(z), "GAME_DIP n'est pas celui du témoin : le bloc quelconque est servi au jeu")
    exiger(e >= F("dip-corrompue", "egales_min"), f"{e} trames égales au témoin")

# The keys of the page (`tests.s`, .Lm_touches): label, column, line; the digit follows the
# label and a space.
MJ_PAGE = [(k, 5, 8 + i) for i, k in enumerate("ABCDEFG")] + [(k, 11, 8 + i) for i, k in enumerate("HIJKLMN")]
MJ_PAGE += [(k, 17, 8 + i) for i, k in enumerate(("PON", "CHI", "KAN", "RON", "REACH", "START", "SELECT"))]

def tests_mahjong():
    (t,) = sain("tests-mj")
    def etats(n):
        f, r = t.fix.get(n, {}), {}
        for k, c, l in MJ_PAGE:
            ligne = f.get(l, " " * 40)
            exiger(ligne[c:c + len(k)] == k, f"trame {n} : « {k} » absent de la ligne {l}")
            r[k] = ligne[c + 7 if c == 17 else c + 2]
        return r
    exiger("MAHJONG PANEL" in t.texte(400), "la page du panneau ne s'ouvre pas commutateur 3 à ON")
    for n, tenues in ((400, ()), (424, ("E", "L", "REACH")), (444, ("F", "M")), (464, ("A", "H", "PON")), (484, ("START",))):
        e = etats(n)
        faux = [k for k in e if e[k] != ("1" if k in tenues else "0")]
        dit(f"trame {n} : à 1 {[k for k in e if e[k] == '1']}")
        exiger(not faux, f"trame {n} : {faux} faux")
    exiger("HARDWARE TESTS" in t.texte(640) and "INPUT TEST" in t.texte(640), "START tenu ne rend pas le menu des tests")

def carte_sauv(c, ngh, sub):
    """The 64 bytes of the first block of save ngh/sub on card c, or None."""
    for k in range(32):
        e = c[0x40 + 4 * k:0x44 + 4 * k]
        if e[0] != 0xFF and e[0] == sub and (e[1] << 8 | e[2]) == ngh:
            return bytes(c[e[3] * 64:e[3] * 64 + 64])
    return None

def cm_copier():
    v, c, r = sain("cp-vide", "cp-cible", "cp-renonce")
    src = open(os.path.join(RUNS, "cp-vide", "..", "..", "roms", "cartes", "copie-source.neo"), "rb").read()
    attendu = carte_sauv(src, 0x44, 0)
    exiger(attendu and attendu != bytes(64), "la source ne porte pas le motif : la scène ne prouve rien")
    ram = lambda run, n: [memoire(run, n, a) for a in ("100000", "100002", "100004", "100006", "1006BE")]
    # The RAM read back just after COPIED, the screen still open: at START, the game takes
    # control and writes its own.
    for run, apres, msgs in ((v, 475, ((380, "CHANGE CARD AND PRESS A"), (460, "COPIED"))),
                             (c, 505, ((380, "CHANGE CARD AND PRESS A"), (460, "OVERWRITE 0044-00? A:YES B:NO"), (490, "COPIED")))):
        for n, m in msgs:
            exiger(m in cm_l(run, n, 24), f"{run.nom}, trame {n} : « {cm_l(run, n, 24).strip()} », « {m} » attendu")
        cible = open(os.path.join(run.d, "carte-420.neo"), "rb").read()
        source = open(os.path.join(run.d, "carte.neo"), "rb").read()
        dit(f"{run.nom} : 0044-00 sur la carte changée {'aux octets de la source' if carte_sauv(cible, 0x44, 0) == attendu else 'FAUX'} ;"
            f" RAM du jeu {' '.join('%04X' % x for x in ram(run, 340))} → {' '.join('%04X' % x for x in ram(run, apres))}")
        exiger(carte_sauv(cible, 0x44, 0) == attendu, f"{run.nom} : la carte changée ne porte pas la sauvegarde copiée")
        exiger(source == src, f"{run.nom} : la carte source a été écrite")
        exiger(ram(run, apres) == ram(run, 340) == [0x0123, 0x4567, 0x89AB, 0xCDEF, 0xCAFE], f"{run.nom} : la RAM du jeu n'est pas rendue")
    exiger("CHANGE CARD AND PRESS A" in cm_l(r, 380, 24) and "CANCELLED" in cm_l(r, 420, 24), "B ne renonce pas")
    exiger("DELETE 0044-00?" in cm_l(r, 460, 24), f"après le renoncement, A : « {cm_l(r, 460, 24).strip()} »")
    exiger(ram(r, 490) == [0x0123, 0x4567, 0x89AB, 0xCDEF, 0xCAFE], "cp-renonce : la RAM du jeu n'est pas rendue")
    exiger(open(os.path.join(r.d, "carte.neo"), "rb").read() == src, "cp-renonce : la carte a été écrite")

def jukebox_veille():
    v, z = sain("veille", "veille-0")
    i7600, i7800, i8050, z7800 = v.img(7600), v.img(7800), v.img(8050), z.img(7800)
    noirs = sum(1 for x in i7800 if (x & 0xFFFFFF) == 0)
    rv, rz = v.rms(7700, 7990), z.rms(7700, 7990)
    dit(f"trame 7800 : {noirs}/{len(i7800)} pixels noirs (témoin : {sum(1 for x in z7800 if (x & 0xFFFFFF) == 0)}) ;"
        f" RMS 7700-7990 {rv:.0f}, témoin {rz:.0f} ; 8050 égale à 7600 : {i8050 == i7600}")
    exiger(len(allumes(i7600)) > 0 and i7600 == z7800, "l'écran du jukebox n'est pas celui du témoin avant la veille")
    exiger(noirs == len(i7800), "l'écran n'est pas noir après ~2 min sans entrée")
    exiger(rz > 0 and rv >= F("jukebox-veille", "rms_ratio_min") * rz, f"RMS {rv:.0f} contre {rz:.0f} : le son s'arrête")
    exiger(i8050 == i7600, "le réveil ne rend pas l'écran tel quel (le HAUT du réveil a agi ?)")
    c1, c2 = v.fix.get(8050, {}).get(12, "")[15:17], v.fix.get(8150, {}).get(12, "")[15:17]
    dit(f"le code : {c1} après le réveil, {c2} après le HAUT suivant")
    exiger(c1 == "21" and c2 == "22", f"le code {c1} puis {c2}, 21 puis 22 attendus")

# ---- The menus on the mahjong panel (record --ref-panneau) ----
def choisie(run, n):
    """The line under the ">" cursor of the fix layer at frame n, without the cursor; None if there is none."""
    l = [s.strip()[1:].strip() for s in run.fix.get(n, {}).values() if s.strip().startswith(">")]
    exiger(len(l) <= 1, f"{run.nom}, trame {n} : {len(l)} curseurs")
    return " ".join(l[0].split()) if l else None
def editeur_vers_tests(run, n_mode, n_tests):
    """The editor's path: REGION on opening, MODE MVS until n_mode, HARDWARE TESTS at n_mode + 10, opened at n_tests."""
    for n, attendu in ((265, "REGION EUROPE"), (305, "MODE MVS"), (n_mode, "MODE MVS"), (n_mode + 10, "HARDWARE TESTS")):
        c = choisie(run, n)
        dit(f"{run.nom}, trame {n} : « {c} »")
        exiger(c == attendu, f"{run.nom}, trame {n} : « {c} », « {attendu} » attendu")
    t = run.texte(n_tests)
    exiger(t.splitlines() and "HARDWARE TESTS" in t and choisie(run, n_tests) == "WORK RAM", f"{run.nom} : les autotests ne s'ouvrent pas à {n_tests}")

def pn_menu_on():
    (r,) = sain("pn-on")
    editeur_vers_tests(r, 345, 400)

def pn_menu_off():
    (r,) = sain("pn-off")
    editeur_vers_tests(r, 345, 400)

def pn_valeur():
    (r,) = sain("pn-val")
    for n, attendu in ((305, "MODE MVS"), (315, "MODE AES"), (325, "MODE MVS")):
        c = choisie(r, n)
        dit(f"trame {n} : « {c} »")
        exiger(c == attendu, f"trame {n} : « {c} », « {attendu} » attendu")

def pn_verrou():
    for r in sain("pn-v-on", "pn-v-off"):
        editeur_vers_tests(r, 345, 400)

def pn_jeu():
    j, z = sain("pn-j", "pn-j0")
    for n, attendu in ((1700, "RESTART GAME"), (1710, "RESUME")):
        c = choisie(j, n)
        dit(f"menu en jeu, trame {n} : « {c} »")
        exiger("IN-GAME MENU" in j.texte(n) and c == attendu, f"trame {n} : « {c} », « {attendu} » attendu")
    p = pause_apres(j, 1650)
    e = sum(1 for n in range(1802, 2200) if j.h(n) != z.h(n))
    avant = sum(1 for n in range(1600, 1800) if j.h(n) != z.h(n))
    dit(f"pause {p[0]}-{p[1]} ; après RESUME, B à 1800 : {e}/398 trames diffèrent du run sans B ({avant} avant)")
    exiger(p[1] < 1800, f"le jeu ne reprend pas avant B (pause jusqu'à {p[1]})")
    exiger(avant == 0, f"{avant} trames diffèrent avant B : les deux runs ne font pas le même chemin")
    exiger(e >= F("pn-jeu", "diff_min"), f"{e} trames : le jeu ne voit plus B après le menu")

JUGES.update({"pn-menu-on": pn_menu_on, "pn-menu-off": pn_menu_off, "pn-valeur": pn_valeur, "pn-verrou": pn_verrou,
              "pn-jeu": pn_jeu})

JUGES.update({"boot-graphismes": boot_graphismes, "ms-son-slot2": ms_son_slot2, "dip-vierge": dip_vierge,
              "dip-corrompue": dip_corrompue, "tests-mahjong": tests_mahjong, "jukebox-veille": jukebox_veille,
              "cm-copier": cm_copier})

# ---- The sine table (record --ref-sinus) ----
# The colours of alpham2's ship, recorded on an image of the witness run (b, g, r of the bgra
# image).
VIOLET = {int.from_bytes(bytes.fromhex(h), "little") for h in ("4f266d", "6d4998", "cba0f1", "9267b6", "41162c")}
def vaisseau(run, n):
    """The centre of the bounding box of the ship's pixels in the play area (y 24-211), at frame n."""
    a, xs, ys = run.img(n), [], []
    for y in range(24, 212):
        for x in range(320):
            if a[y * 320 + x] & 0xFFFFFF in VIOLET:
                xs.append(x); ys.append(y)
    exiger(xs, f"run {run.nom} : pas de vaisseau à la trame {n}")
    return (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2

def alpha_trajectoire():
    tol = F("alpha-trajectoire", "tol_px")
    for d in ("h", "hd", "d", "bd", "b", "bg", "g", "hg"):
        o, t = sain(f"at-{d}", f"at-{d}-snk")
        (ox0, oy0), (ox1, oy1) = vaisseau(o, 1639), vaisseau(o, 1675)
        (tx0, ty0), (tx1, ty1) = vaisseau(t, 1639), vaisseau(t, 1675)
        do, dt = (ox1 - ox0, oy1 - oy0), (tx1 - tx0, ty1 - ty0)
        dit(f"{d:2} : déplacement ({do[0]:+.1f}, {do[1]:+.1f}), témoin ({dt[0]:+.1f}, {dt[1]:+.1f})")
        exiger(abs(dt[0]) + abs(dt[1]) > 0, f"{d} : le vaisseau du témoin ne bouge pas, la scène ne prouve rien")
        exiger(abs(do[0] - dt[0]) <= tol and abs(do[1] - dt[1]) <= tol,
               f"{d} : ({do[0]:+.1f}, {do[1]:+.1f}) contre ({dt[0]:+.1f}, {dt[1]:+.1f}) au témoin")

def howto_preisle2():
    o, t = sain("hp", "hp-snk")
    e = sum(1 for n in range(525, 1826) if o.h(n) is not None and o.h(n) == t.h(n))
    m = o.img(1000) == t.img(1000)
    dit(f"HOW TO PLAY : {e}/1301 trames égales au témoin au même instant ; trame 1000 égale : {m}")
    exiger(len(allumes(t.img(1000))) > 0, "le témoin est noir à la trame 1000 : la scène ne prouve rien")
    exiger(m, "la trame 1000 n'est pas celle du témoin : l'objet à ramasser n'est pas là")
    exiger(e >= F("howto-preisle2", "egales_min"), f"{e} trames égales au témoin")

JUGES.update({"alpha-trajectoire": alpha_trajectoire, "howto-preisle2": howto_preisle2})
JUGES.update({"tests-sauvegarde": tests_sauvegarde, "dd-connu": dd_connu})
# A known defect of the BIOS, not yet fixed: the scene runs and gives its verdict, "CONNU"
# instead of FAIL, without failing the player's path (quantity "bug_connu" of the record, 1).
# Once fixed, it comes out PASS: then remove the line from the record.
CONNUS = {sc for (sc, g), v in SEUILS.items() if g == "bug_connu" and v == "1"}
echecs = 0
for s in SCENES:
    LIGNE.clear()
    try:
        JUGES[s]()
        verdict, raison = "PASS", ""
    except Ecart as e:
        verdict, raison = "FAIL", str(e)
    except Exception as e:  # an absent or unreadable record is a failure, not a crash of the judge
        verdict, raison = "FAIL", f"{type(e).__name__} : {e}"
    if verdict == "FAIL" and s in CONNUS:
        verdict = "CONNU"
    elif verdict == "FAIL":
        echecs += 1
    print(f"{verdict}  {s}" + (f" — {raison}" if raison else ""))
    for d in LIGNE.get("d", []):
        print("      " + d)
sys.exit(1 if echecs else 0)
PY
rc=$?
cat "$WORK/parcours.txt"
echo "runs : $DUREE_RUNS s, ${REPRIS} témoin(s) repris du cache ; en tout $(( $(date +%s) - DEBUT )) s ; travail : $WORK"
[ $rc -eq 0 ] && echo "PARCOURS : PASS" || echo "PARCOURS : FAIL"
exit $rc
