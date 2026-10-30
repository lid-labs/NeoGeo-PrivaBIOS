#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Thibaut Lion
"""Les mutations du parcours (`bench/parcours.sh`) : chacune casse UNE fonction visible du BIOS,
pour prouver que la scène qui la juge sait échouer.

    python3 -I -B bench/parcours-mutations.py --liste
    python3 -I -B bench/parcours-mutations.py <nom> <copie-des-sources>
    python3 -I -B bench/parcours-mutations.py --eprouver [--paralleles n] <dossier-roms> <dossier-travail> [noms…]

La copie est modifiée en place ; elle doit être hors du dépôt (refus sinon). Chaque mutation
remplace des passages exacts des sources et refuse de s'appliquer si l'un n'y est pas une et une
seule fois : une mutation qui ne s'applique plus ne prouve rien, elle doit le dire.

--eprouver, pour chaque mutation (toutes par défaut) : copie `src/c0` dans le dossier de travail,
applique la mutation, et lance `parcours.sh --sources <copie> --scenes <ses scènes>`. Elle est
« tuée » si CHACUNE des scènes visées sort FAIL. Une ligne par mutation, dans l'ordre où elles
finissent, puis le compte ; sortie en 1 si une mutation survit.

LES MUTATIONS SONT ÉPROUVÉES EN PARALLÈLE : chacune a sa copie des sources et son dossier, et rien
ne passe de l'une à l'autre. --paralleles n à la fois (défaut : la moitié des cœurs moins un),
chacune avec `parcours.sh --jobs 2`. Les runs témoins (BIOS SNK) ne dépendent d'aucune mutation :
un seul cache (`parcours.sh --cache`, <dossier-travail>/cache-temoins) les sert à toutes.
"""
import concurrent.futures
import os
import re
import shutil
import subprocess
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
PAQUET = os.path.dirname(ICI)
DEPOT = PAQUET

# nom : (scènes qui doivent échouer, fichier, [(passage, remplacement)…], ce que ça casse)
MUTATIONS = {
    "boot-texte": (
        "boot-ecran", "ecran.s",
        [('        .asciz  "MVS"\n', '        .asciz  "MV5"            | MUTATION\n')],
        "l'écran de boot affiche MV5 au lieu de MVS",
    ),
    "boot-sans-saut": (
        "boot-saut", "ecran.s",
        [("        bsr.s   .Lsync\n        jsr     _panneau_p1             | %d0 : P1, manette ou panneau traduit (`panneau.s`)\n",
          "        bsr.s   .Lsync\n        rts                     | MUTATION : aucun bouton lu\n"
          "        jsr     _panneau_p1             | %d0 : P1, manette ou panneau traduit (`panneau.s`)\n")],
        "l'écran de boot ne lit plus les boutons : A ne le saute plus",
    ),
    "calendrier-sans-jour": (
        "calendrier", "cal.s",
        [("        move.b  %d2, 0x10FDD4           | jour\n",
          "        nop                             | MUTATION : le jour n'est plus écrit\n")],
        "READ_CALENDAR n'écrit plus le jour du mois",
    ),
    "carte-jamais": (
        "carte", "ecran.s",
        [("        andi.b  #0x30, %d0\n        bne.s   1f\n        lea     .Lavec_carte, %a2\n",
          "        andi.b  #0x30, %d0\n        bra.s   1f              | MUTATION\n        lea     .Lavec_carte, %a2\n")],
        "l'écran de boot dit NONE même avec une carte",
    ),
    "demo-muette": (
        "demo-son", "c0.s",
        [("        move.b  %d0, 0x3A001B           | REG_CRTFIX : S ROM et M1 de la cartouche\n",
          "        nop                             | MUTATION : pas de REG_CRTFIX\n")],
        "le passage de slot ne rend plus la M1 de la cartouche au Z80",
    ),
    "credit-sans-piece": (
        "partie-credit partie-start", "io.s",
        [("        addq.b  #1, (%a0, %d1.w)        | une pièce de plus\n",
          "        nop                             | MUTATION : la pièce n'est pas comptée\n")],
        "une pièce ne fait plus de crédit",
    ),
    "fin-sans-demo": (
        "fin-demo", "c0.s",
        [("        moveq   #2, %d2                 | BIOS_USER_REQUEST = démo\n"
          "        tst.w   0xD00034                | crédits P1 et P2, BCD\n",
          "        moveq   #3, %d2                 | MUTATION : le titre même sans crédit\n"
          "        tst.w   0xD00034                | crédits P1 et P2, BCD\n")],
        "après un game over sans crédit, le titre au lieu de la démo",
    ),
    "fin-sans-titre": (
        "fin-titre", "c0.s",
        [("        moveq   #3, %d2                 | BIOS_USER_REQUEST = titre\n1:      move.w  #0x1DB, %d1",
          "        moveq   #2, %d2                 | MUTATION : la démo même avec un crédit\n1:      move.w  #0x1DB, %d1")],
        "après un game over avec un crédit, la démo au lieu du titre",
    ),
    "scores-sans-sauvegarde": (
        "scores", "c0.s",
        [("_sauver_jeu:\n        bsr     _bloc_jeu\n",
          "_sauver_jeu:\n        rts                     | MUTATION : rien n'est sauvé\n        bsr     _bloc_jeu\n")],
        "la zone de sauvegarde du jeu n'est plus copiée en backup RAM",
    ),
    "dip-oublie": (
        "dip-temps dip-langue", "dip.s",
        [("        movea.l F_BLOC(%a6), %a2\n        movea.l %a5, %a1\n",
          "        movea.l F_BLOC(%a6), %a1        | MUTATION : le bloc recopié sur GAME_DIP\n"
          "        movea.l %a5, %a2\n")],
        "START de l'éditeur rend à GAME_DIP les valeurs d'avant : le réglage est perdu",
    ),
    "region-ignoree": (
        "region", "c0.s",
        [("        move.b  %d0, 0x10FD83\n1:\n",
          "        nop                             | MUTATION : la région choisie n'est pas posée\n1:\n")],
        "la région enregistrée n'est plus appliquée au boot",
    ),
    "autotests-aveugles": (
        "autotests", "tests.s",
        [("        cmp.w   %d1, %d2\n        bne.s   .Lm_faute\n",
          "        cmp.w   %d1, %d2\n        nop                     | MUTATION\n"),
         ("        cmp.w   %d0, %d2\n        bne.s   3f\n",
          "        cmp.w   %d0, %d2\n        nop                     | MUTATION\n")],
        "le test mémoire ne compare plus ce qu'il relit",
    ),
    "jukebox-muet": (
        "jukebox", "jukebox.s",
        [("        move.b  %d7, SOUND\n", "        nop                     | MUTATION : A n'envoie rien\n")],
        "A n'envoie plus le code du jukebox",
    ),
    "menu-police": (
        "menu-hud", "menu.s",
        [("        bsr     .Lmise_en_page\n\n",
          "        bsr     .Lmise_en_page\n"
          "        move.b  %d0, 0x3A000B           | MUTATION : REG_BRDFIX, la police de la carte\n\n"),
         ("        bsr     .Lrendre_fix\n        move.w  MN_MOD, VRAMMOD\n",
          "        bsr     .Lrendre_fix\n"
          "        move.b  %d0, 0x3A001B           | MUTATION : REG_CRTFIX au retour\n        move.w  MN_MOD, VRAMMOD\n")],
        "REG_BRDFIX à l'ouverture du menu et REG_CRTFIX au retour, comme avant le correctif, sans le $03",
    ),
    "menu-son": (
        "menu-son", "menu.s",
        [("        bsr     .Lrendre_fix\n        move.w  MN_MOD, VRAMMOD\n",
          "        bsr     .Lrendre_fix\n"
          "        move.b  #0x03, 0x320000         | MUTATION : le reset du pilote d'avant le correctif\n"
          "        moveq   #8 - 1, %d4\n"
          "7:      bsr     .Lsync\n"
          "        dbra    %d4, 7b\n        move.w  MN_MOD, VRAMMOD\n")],
        "le $03 remis à la reprise du menu en jeu, comme avant le correctif",
    ),
    # Éprouvée et écartée : REG_VRAMMOD non rendu à la reprise survit (aof repose le sien avant
    # d'écrire), elle ne casse rien de visible sur ce jeu.
    "menu-cadre-reste": (
        "menu-reprise", "menu.s",
        [("        bsr     .Lrendre_fix\n        move.w  MN_MOD, VRAMMOD\n", "        nop                     | MUTATION : le plan fixe du jeu non rendu\n        move.w  MN_MOD, VRAMMOD\n")],
        "RESUME ne rend plus le plan fixe du jeu : le cadre reste à l'écran",
    ),
    "cheats-inertes": (
        "cheats", "cheats.s",
        [("        move.b  %d3, (%a2)\n", "        nop                     | MUTATION : le moteur n'écrit plus\n")],
        "le moteur des cheats n'écrit plus les valeurs d'un octet",
    ),
    "restart-reprend": (
        "restart", "menu.s",
        [("        beq.w   .Lrelance\n", "        beq.w   .Lreprendre             | MUTATION\n")],
        "RESTART GAME fait un RESUME",
    ),
    "demo-sans-rotation": (
        "ms-demo", "c0.s",
        [("_sysret_rotation:\n        bsr     _slot_suivant           | %d1\n",
          "_sysret_rotation:\n        bra     _sysret_meme_slot       | MUTATION : la démo reste sur son slot\n"
          "        bsr     _slot_suivant           | %d1\n")],
        "la fin de démo ne passe plus au slot suivant",
    ),
    "select-ignore": (
        "ms-select", "io.s",
        [("        moveq   #4, %d6                 | SELECT P1 : code 4, le suivant\n        btst    #1, %d0\n        bne.s   1f\n",
          "        moveq   #4, %d6                 | SELECT P1 : code 4, le suivant\n        btst    #1, %d0\n        nop                     | MUTATION\n")],
        "SELECT P1 n'est plus pris au titre",
    ),
    "garde-retiree": (
        "ms-garde", "io.s",
        [("        cmpi.b  #4, 0x10FD81            | un SELECT en cours (DEMO_END du jeu) : ignoré\n"
          "        beq.s   _io_fin_demo\n"
          "        cmpi.b  #5, 0x10FD81\n"
          "        beq.s   _io_fin_demo\n", "")],
        "la garde de SELECT retirée (DECISIONS §10)",
    ),
    # Le mode AES (DECISIONS §11).
    "mode-ignore": (
        "aes-bascule aes-demo", "c0.s",
        [("        move.b  %d0, 0x10FD82\n1:\n",
          "        nop                             | MUTATION : le mode choisi n'est pas posé\n1:\n")],
        "le mode enregistré n'est plus posé dans BIOS_MVS_FLAG au boot",
    ),
    "mode-perdu": (
        "aes-bascule", "dip.s",
        [("        jsr     _reglages_ecrire_mode\n",
          "        nop                             | MUTATION : le mode n'est pas enregistré\n"
          "        nop\n        nop\n")],
        "START de l'éditeur relance la machine sans enregistrer le mode",
    ),
    "start-refuse": (
        "aes-start aes-menu", "io.s",
        [("        bne.s   _io_libre               | MVS : refusé, sauf FREE PLAY\n        tst.b   0x10FDAF\n",
          "        bra     _io_libre               | MUTATION : START sans crédit refusé en AES aussi\n        tst.b   0x10FDAF\n")],
        "en mode AES, START sans crédit est refusé comme en MVS",
    ),
    "piece-comptee": (
        "aes-piece", "c0.s",
        [("        bmi.s   1f\n        move.b  %d0, 0x3800E5           | REG_SETCL1\n",
          "        bra.s   1f                      | MUTATION : monnayeurs jamais verrouillés\n"
          "        move.b  %d0, 0x3800E5           | REG_SETCL1\n")],
        "en mode AES, les monnayeurs restent ouverts : la pièce fait un crédit, COIN_SOUND et le titre",
    ),
    "mode-bloque": (
        "aes-retour", "dip.s",
        [(".Lch_mode:                              | 0 MVS, 1 AES\n        moveq   #0, %d0\n"
          "        move.b  F_MODE(%a6), %d0\n        moveq   #0, %d3\n",
          ".Lch_mode:                              | 0 MVS, 1 AES\n        moveq   #0, %d0\n"
          "        move.b  F_MODE(%a6), %d0\n        moveq   #1, %d3                 | MUTATION : AES au minimum\n")],
        "la ligne MODE ne redescend plus à MVS",
    ),
    # La couverture (relevé measured/2026-10-23-parcours-couverture-scenes.tsv).
    "defauts-inertes": (
        "dip-defauts", "dip.s",
        [(".Ldefauts:\n        bsr.s   _dip_defauts\n",
          ".Ldefauts:\n        bra     .Ltout                  | MUTATION : la remise aux défauts ne remet rien\n"
          "        bsr.s   _dip_defauts\n")],
        "RESET TO DEFAULTS redessine l'écran sans rendre les défauts",
    ),
    "temps-perdu": (
        "dip-mmss", "dip.s",
        [("        move.w  %d4, (%a5,%d1.w)\n        rts\n.Lch_region:",
          "        nop                             | MUTATION : le temps changé n'est pas écrit\n"
          "        rts\n.Lch_region:")],
        "un réglage de temps (MM:SS) changé n'est pas écrit dans GAME_DIP",
    ),
    "a-sans-boucle": (
        "dip-fois", "dip.s",
        [("        ble.s   3b\n        move.w  %d3, %d0\n        rts\n",
          "        ble.s   3b\n        move.w  %d4, %d0                | MUTATION : A reste au maximum\n        rts\n")],
        "A ne repart plus au minimum après le maximum",
    ),
    "europe-perdue": (
        "region-europe", "c0.s",
        [("        move.b  0xC00401, 0x10FD83      | BIOS_COUNTRY_CODE ← nationalité\n",
          "        move.b  #1, 0x10FD83            | MUTATION : USA au lieu de la nationalité\n")],
        "sans réglage, la région est USA au lieu de celle du descripteur (Europe)",
    ),
    "japon-en-usa": (
        "region-japon", "c0.s",
        [("        move.b  %d0, 0x10FD83\n1:\n",
          "        tst.b   %d0\n        bne.s   9f\n        moveq   #1, %d0                 | MUTATION : JAPAN posé USA\n"
          "9:      move.b  %d0, 0x10FD83\n1:\n")],
        "la région JAPAN enregistrée est appliquée USA",
    ),
    "usa-en-japon": (
        "region-usa", "c0.s",
        [("        move.b  %d0, 0x10FD83\n1:\n",
          "        cmpi.b  #1, %d0\n        bne.s   9f\n        moveq   #0, %d0                 | MUTATION : USA posé JAPAN\n"
          "9:      move.b  %d0, 0x10FD83\n1:\n")],
        "la région USA enregistrée est appliquée JAPAN",
    ),
    "palette-non-testee": (
        "autotests-palette", "tests.s",
        [(".Lt_pal:\n        moveq   #0, %d3\n",
          ".Lt_pal:\n        moveq   #0, %d3\n        moveq   #0, %d0                 | MUTATION : rien de testé, OK\n        rts\n")],
        "PALETTE RAM rend OK sans rien tester",
    ),
    "vram-non-testee": (
        "autotests-vram", "tests.s",
        [(".Lt_vram:\n        move.w  #1, VRAMMOD\n",
          ".Lt_vram:\n        moveq   #0, %d0                 | MUTATION : rien de testé, OK\n        moveq   #0, %d3\n        rts\n"
          "        move.w  #1, VRAMMOD\n")],
        "VRAM rend OK sans rien tester",
    ),
    "backup-non-testee": (
        "autotests-backup", "tests.s",
        [(".Lt_bram:\n        move.b  %d0, SRAMUNLOCK\n",
          ".Lt_bram:\n        moveq   #0, %d0                 | MUTATION : rien de testé, OK\n        moveq   #0, %d3\n        rts\n"
          "        move.b  %d0, SRAMUNLOCK\n")],
        "BACKUP RAM rend OK sans rien tester",
    ),
    "entrees-eteintes": (
        "tests-entrees", "tests.s",
        [("        move.w  #0x5000, %d3            | appuyé\n",
          "        move.w  #0x4000, %d3            | MUTATION : un appui n'allume rien\n")],
        "INPUT TEST n'allume plus une entrée appuyée",
    ),
    "barres-sans-rouge": (
        "tests-barres", "tests.s",
        [("2:      move.w  %d0, 2(%a0)\n",
          "2:      nop                             | MUTATION : l'entrée 1 (rouge, gris) jamais écrite\n")],
        "COLOR BARS n'écrit plus le rouge de la page 1 ni le gris de la page 2",
    ),
    "grille-noire": (
        "tests-grille", "tests.s",
        [("        move.w  #0x0FFF, PALETTES + 32 + 4      | palette 1, entrée 2\n",
          "        nop                                     | MUTATION : les traits restent noirs\n")],
        "CROSSHATCH n'écrit plus la couleur des traits",
    ),
    "jukebox-pas-de-16": (
        "jukebox-pas", "jukebox.s",
        [("        moveq   #16, %d1                | droite\n",
          "        moveq   #1, %d1                 | MUTATION : droite fait +1\n")],
        "droite avance le code de 1 au lieu de 16",
    ),
    "jukebox-b-inerte": (
        "jukebox-stop", "jukebox.s",
        [("        move.b  #0x03, SOUND\n        bsr     .Lattendre\n        bra     .Lboucle\n",
          "        nop                             | MUTATION : B n'envoie rien\n        bsr     .Lattendre\n        bra     .Lboucle\n")],
        "B ne relance plus le pilote : le morceau continue",
    ),
    "cheat-sans-off": (
        "cheats-off", "menu.s",
        [("        bchg    %d1, %d2\n", "        bset    %d1, %d2                | MUTATION : A met à ON, jamais à OFF\n")],
        "une ligne de cheat ne repasse plus à OFF",
    ),
    "p2-refuse": (
        "partie-p2", "io.s",
        [("        cmpi.b  #2, %d3                 | titre : les deux joueurs, deux crédits\n        bcs.s   2f\n        moveq   #3, %d2\n",
          "        cmpi.b  #2, %d3                 | titre : les deux joueurs, deux crédits\n        bcs.s   2f\n"
          "        nop                             | MUTATION : START P2 refusé au titre\n")],
        "START P2 au titre, avec deux crédits, est refusé",
    ),
    "carte-protegee": (
        "carte-sauve", "card.s",
        [(".Lsauver:\n        btst    #6, 0x380000\n        bne     .L85\n",
          ".Lsauver:\n        bra     .L85                    | MUTATION : toute sauvegarde refusée\n"
          "        btst    #6, 0x380000\n        bne     .L85\n")],
        "CARD refuse toute sauvegarde ($85, protégée en écriture)",
    ),
    "select-p2-suivant": (
        "ms-select-p2", "io.s",
        [("        moveq   #5, %d6                 | SELECT P2 : code 5, le précédent\n",
          "        moveq   #4, %d6                 | MUTATION : SELECT P2 mène au suivant\n")],
        "SELECT P2 passe au slot suivant au lieu du précédent",
    ),
    "select-aes-ignore": (
        "aes-ms-select", "io.s",
        [("        bra.s   _io_select_garde\n",
          "        bra     _io_fin_demo            | MUTATION : SELECT ignoré en démo AES\n")],
        "en mode AES, SELECT n'est plus pris en démo",
    ),
    "pause-aes-retiree": (
        "aes-pause", "io.s",
        [("        moveq   #-1, %d2\n        tst.b   0x10FD82\n        beq.s   2f\n        moveq   #0x55, %d2\n",
          "        moveq   #-1, %d2\n        tst.b   0x10FD82\n        nop                             | MUTATION : SELECT retiré en AES aussi\n"
          "        moveq   #0x55, %d2\n")],
        "en mode AES, les bits SELECT sont retirés de BIOS_STATCHANGE : le jeu ne se met plus en pause",
    ),
    "logo-jamais": (
        "aes-logo", "c0.s",
        [("        tst.b   BIOS_LOGO\n        bne.s   9f                      | déjà faite à ce boot\n",
          "        tst.b   BIOS_LOGO\n        bra.s   9f                      | MUTATION : jamais de demande 1\n")],
        "en mode AES, la demande 1 n'est jamais donnée",
    ),
    "aes-titre-apres-partie": (
        "aes-fin", "c0.s",
        [("        moveq   #2, %d2                 | BIOS_USER_REQUEST = démo\n        tst.w   0xD00034                | crédits P1 et P2, BCD\n",
          "        moveq   #2, %d2                 | BIOS_USER_REQUEST = démo\n        tst.b   0x10FD82\n        bne.s   9f\n"
          "        moveq   #3, %d2                 | MUTATION : en AES, le titre après game over\n"
          "9:      tst.w   0xD00034                | crédits P1 et P2, BCD\n")],
        "en mode AES, le game over mène au titre au lieu de la démo",
    ),
    "piece-muette": (
        "piece-son", "io.s",
        [("        jsr     0x134                   | COIN_SOUND\n",
          "        nop                             | MUTATION : COIN_SOUND jamais appelé\n")],
        "la pièce ne fait plus appeler COIN_SOUND : pas de son de pièce",
    ),
    "depart-jamais": (
        "depart-force", "io.s",
        [("        moveq   #1, %d4                 | 00/00 atteint : START P1 forcé\n",
          "        nop                             | MUTATION : pas de départ forcé\n")],
        "le minuteur du titre arrive à 00/00 sans faire partir le jeu",
    ),
    "select-seule-pris": (
        "ms-seule", "io.s",
        [("        beq.s   _io_fin_demo            | aucun autre slot occupé : ignoré\n",
          "        nop                             | MUTATION : SELECT pris sur une cartouche seule\n")],
        "SELECT relance le titre du même slot sur une cartouche seule (le chemin de la référence)",
    ),
    "jukebox-sans-repetition": (
        "jukebox-repete", "jukebox.s",
        [("        subq.w  #1, %d6\n        bne     .Lboucle\n        moveq   #DELAI2, %d6\n",
          "        subq.w  #1, %d6\n        bra     .Lboucle                | MUTATION : pas de répétition\n        moveq   #DELAI2, %d6\n")],
        "une direction tenue n'avance plus le code",
    ),
    "p2-joint-refuse": (
        "partie-p2-joint", "io.s",
        [("4:      cmp.b   %d5, %d3\n        bcs.s   2f\n        bset    #1, %d2\n",
          "4:      cmp.b   %d5, %d3\n        bcs.s   2f\n        nop                             | MUTATION : P2 refusé en partie\n")],
        "en partie, START P2 avec un crédit est refusé",
    ),
    "aes-insert-coin": (
        "aes-texte", "io.s",
        [("4:      tst.b   BORNE                   | AES ou FREE PLAY : la demande de P2 reste, « PUSH START » (mesuré)\n"
          "        bmi.s   2f\n",
          "4:      nop                             | MUTATION : le défaut d'avant, P2 refusé en AES\n")],
        "en mode AES, CREDIT_CHECK refuse de nouveau la demande de P2 : aof affiche « INSERT COIN »",
    ),
    "recherche-aveugle": (
        "carte-chercher", "card.s",
        [("        bset    %d4, %d2\n", "        nop                             | MUTATION : aucune sous-sauvegarde trouvée\n")],
        "CARD $01 rend un masque vide même pour un NGH présent",
    ),
    "suppression-inerte": (
        "carte-supprimer", "card.s",
        [("        .word   .Lsupprimer - .Ltable   | $04\n", "        .word   .Lfin - .Ltable         | $04 MUTATION : rien supprimé\n")],
        "CARD $04 répond sans rien supprimer",
    ),
    "nom-jamais-ecrit": (
        "carte-nom", "card.s",
        [("        .word   .Lnom_ecrire - .Ltable  | $06\n", "        .word   .Lfin - .Ltable         | $06 MUTATION : nom jamais écrit\n")],
        "CARD $06 répond sans écrire le nom",
    ),
    "select-lu-sur-start": (
        "tests-p2", "tests.s",
        [('        ELEM    STATUS_B, 1, 13, 11, "SELECT"\n', '        ELEM    STATUS_B, 0, 13, 11, "SELECT"   | MUTATION : le bit de START P1\n')],
        "INPUT TEST allume SELECT P1 sur le bit de START P1",
    ),
    "commutateur-decale": (
        "tests-dip", "tests.s",
        [('        ELEM    DIPSW, 3, 15, 18, "4"\n', '        ELEM    DIPSW, 4, 15, 18, "4"     | MUTATION : le bit du 5\n')],
        "INPUT TEST montre le commutateur 5 sous le chiffre 4",
    ),
    "soft-dip-sans-garde": (
        "dip-sans-donnees", "dip.s",
        [("        blo.s   2f                      | déborde la P-ROM fixe, ou entre les zones\n",
          "        nop                             | MUTATION : un bloc entre les zones est accepté\n")],
        "l'éditeur lit un bloc soft-DIP refusé, entre la P-ROM fixe et la zone banquée",
    ),
    # Le menu en jeu complet, le 2026-10-23 (relevé --ref-menu, en-tête) : une par scène, et une par
    # fonction que sa scène juge avec d'autres (la relance et l'enregistrement de GAME SETTINGS).
    "gs-droite-inerte": (
        "gs-compte gs-mmss", "reglages-jeu.s",
        [("2:      moveq   #1, %d2                 | droite\n",
          "2:      moveq   #0, %d2                 | MUTATION : droite ne change rien\n")],
        "GAME SETTINGS : droite ne change plus la valeur",
    ),
    "gs-defauts-inertes": (
        "gs-defauts", "reglages-jeu.s",
        [("        bsr     _dip_defauts\n", "        nop                             | MUTATION : rien n'est remis\n")],
        "GAME SETTINGS : RESET TO DEFAULTS ne remet rien",
    ),
    "gs-sans-enregistrement": (
        "gs-choix gs-mmss gs-fois", "reglages-jeu.s",
        [(".Lenregistrer:\n        tst.w   GS_CHANGE\n",
          ".Lenregistrer:\n        rts                     | MUTATION : rien en backup RAM\n        tst.w   GS_CHANGE\n")],
        "GAME SETTINGS n'écrit plus le bloc du jeu : RESTART GAME relit les valeurs d'avant",
    ),
    "gs-relance-inerte": (
        "gs-choix", "reglages-jeu.s",
        [("        bra     _mn_relancer\n", "        rts                             | MUTATION : pas de relance\n")],
        "GAME SETTINGS : RESTART GAME enregistre sans relancer",
    ),
    "gs-a-comme-droite": (
        "gs-fois", "reglages-jeu.s",
        [("        moveq   #2, %d2                 | A\n", "        moveq   #1, %d2                 | MUTATION : A comme droite, borné\n")],
        "GAME SETTINGS : A ne repart plus au minimum après le maximum",
    ),
    "gs-sans-ligne-vide": (
        "gs-sans-donnees", "reglages-jeu.s",
        [("        lea     T_ENTREE(%a2), %a2\n        addq.w  #1, %d6\n        bra.s   3f\n",
          "        bra.s   3f                      | MUTATION : la ligne NO SOFT DIP DATA écrasée\n")],
        "GAME SETTINGS ne dit plus NO SOFT DIP DATA",
    ),
    "gs-banque-acceptee": (
        "gs-banque", "reglages-jeu.s",
        [("        bcs.s   1f\n        suba.l  %a3, %a3                | la zone banquée : refusée (voir l'en-tête)\n",
          "        bra.s   1f                      | MUTATION : la zone banquée acceptée\n"
          "        suba.l  %a3, %a3                | la zone banquée : refusée (voir l'en-tête)\n")],
        "GAME SETTINGS lit un bloc soft-DIP de la zone banquée, en partie",
    ),
    "me-octet-voisin": (
        "me-ecran", "memoire.s",
        [("        moveq   #0, %d2\n        move.b  (%a0,%d1.l), %d2\n        moveq   #0, %d3                 | le rôle\n",
          "        moveq   #0, %d2\n        move.b  1(%a0,%d1.l), %d2       | MUTATION : l'octet suivant\n        moveq   #0, %d3                 | le rôle\n")],
        "l'éditeur mémoire affiche l'octet voisin de celui de l'adresse",
    ),
    "me-goto-inerte": (
        "me-goto", "memoire.s",
        [("        move.w  ME_VAL, %d1\n        move.w  %d1, ME_ADR\n",
          "        move.w  ME_VAL, %d1\n        nop                             | MUTATION : GOTO n'y va pas\n")],
        "GOTO ne déplace plus le curseur",
    ),
    "me-droite-inerte": (
        "me-octet", "memoire.s",
        [("2:      btst    #3, %d0                 | droite\n        beq.s   2f\n        addq.w  #1, %d1\n",
          "2:      btst    #3, %d0                 | droite\n        beq.s   2f\n        nop                             | MUTATION\n")],
        "droite ne passe plus à l'octet suivant",
    ),
    "me-gauche-inerte": (
        "me-octet", "memoire.s",
        [("2:      btst    #2, %d0                 | gauche\n        beq.s   2f\n        subq.w  #1, %d1\n",
          "2:      btst    #2, %d0                 | gauche\n        beq.s   2f\n        nop                             | MUTATION\n")],
        "gauche ne revient plus à l'octet précédent",
    ),
    "me-haut-court": (
        "me-ligne", "memoire.s",
        [("        moveq   #-8, %d2\n", "        moveq   #-1, %d2                | MUTATION : haut d'un octet\n")],
        "haut recule d'un octet au lieu d'une ligne",
    ),
    "me-page-haut-courte": (
        "me-page", "memoire.s",
        [("        moveq   #-64, %d2\n", "        moveq   #-8, %d2                | MUTATION : une page d'une ligne\n")],
        "B + haut recule d'une ligne au lieu d'une page",
    ),
    "goto-gauche-inerte": (
        "me-goto", "memoire.s",
        [("        move.w  ME_CHIF, %d2\n        btst    #2, %d0\n        beq.s   1f\n        subq.w  #1, %d2\n",
          "        move.w  ME_CHIF, %d2\n        btst    #2, %d0\n        beq.s   1f\n        nop                             | MUTATION\n")],
        "GOTO : gauche ne revient plus au chiffre précédent",
    ),
    "goto-b-va": (
        "me-goto", "memoire.s",
        [("3:      btst    #5, %d0                 | B : rien\n        bne.s   8f\n",
          "3:      nop                             | MUTATION : B ne renonce pas\n        nop\n")],
        "GOTO : B ne quitte plus le mode",
    ),
    "valeur-haut-inerte": (
        "me-poke", "memoire.s",
        [("        btst    #0, %d0\n        beq.s   1f\n        addq.b  #1, %d1\n",
          "        btst    #0, %d0\n        beq.s   1f\n        nop                             | MUTATION\n")],
        "SET VALUE : haut n'ajoute plus 1",
    ),
    # Une première version, « B écrit comme A » (A ou B à l'écriture), a survécu : B est lu avant A et
    # sort sans écrire. Celle-ci retire la sortie par B.
    "annuler-inerte": (
        "me-poke", "memoire.s",
        [("        btst    #5, %d0                 | B : rien d'écrit\n        bne.s   8f\n",
          "        nop                             | MUTATION : B ne renonce plus\n")],
        "SET VALUE : B ne quitte plus la saisie",
    ),
    "me-ligne-courte": (
        "me-ligne", "memoire.s",
        [("        moveq   #8, %d2\n        btst    #5, %d5\n", "        moveq   #1, %d2                 | MUTATION : une ligne d'un octet\n        btst    #5, %d5\n")],
        "bas avance d'un octet au lieu d'une ligne",
    ),
    "me-page-courte": (
        "me-page", "memoire.s",
        [("        moveq   #64, %d2\n", "        moveq   #8, %d2                 | MUTATION : une page d'une ligne\n")],
        "B + bas avance d'une ligne au lieu d'une page",
    ),
    "me-sans-repetition": (
        "me-repete", "memoire.s",
        [("        or.w    %d1, %d0\n", "        nop                             | MUTATION : pas de répétition\n")],
        "une direction tenue ne se répète plus",
    ),
    "me-ecriture-inerte": (
        "me-poke", "memoire.s",
        [("        move.b  ME_VAL + 1, (%a0,%d1.l)\n", "        nop                             | MUTATION : rien d'écrit\n")],
        "SET VALUE n'écrit plus l'octet",
    ),
    "gels-inertes": (
        "me-gel", "cheats.s",
        [("1:      cmpi.b  #2, 0x10FDAF            | en partie seulement\n",
          "1:      rts                     | MUTATION : aucun gel appliqué\n        cmpi.b  #2, 0x10FDAF            | en partie seulement\n")],
        "les gels ne sont plus réécrits",
    ),
    "gels-non-listes": (
        "me-liste", "memoire.s",
        [(".Lc_gels:\n", ".Lc_gels:\n        rts                     | MUTATION : la liste n'est pas dessinée\n")],
        "l'éditeur mémoire ne liste plus les gels",
    ),
    "degel-inerte": (
        "me-degel", "memoire.s",
        [("        bclr    %d3, GL_MASQUE + 1      | dégelé\n", "        nop                             | MUTATION : D ne dégèle pas\n")],
        "D sur un octet gelé ne le dégèle plus",
    ),
    "borne-retiree": (
        "me-borne", "memoire.s",
        [("2:      cmpi.w  #BORNE, %d1\n        bcc     .Lboucle                | la zone du BIOS : ni A ni D\n",
          "2:      nop                             | MUTATION : la zone du BIOS modifiable\n")],
        "A et D agissent dans la zone du BIOS",
    ),
    # Le bus flottant (le 2026-10-24) : la copie du bloc soft-DIP défaite, l'écran TEST relit la
    # P-ROM sous REG_BRDFIX, comme l'image n°8 sur le matériel.
    "bf-intitules-prom": (
        "bf-editeur bf-banque bf-tests bf-jukebox bf-borne", "dip.s",
        [("        add.l   %d0, 6(%a0)\n", "        nop                             | MUTATION : intitulés lus dans la P-ROM\n")],
        "les intitulés de l'éditeur lus dans la P-ROM sous REG_BRDFIX",
    ),
    "bf-nom-prom": (
        "bf-editeur bf-banque bf-borne", "dip.s",
        [("5:      lea     COPIE, %a3\n", "5:      nop                             | MUTATION : le nom lu dans la P-ROM\n")],
        "le nom du jeu de l'éditeur lu dans la P-ROM sous REG_BRDFIX",
    ),
    "cartouche-absente-servie": (
        "sans-cartouche", "c0.s",
        [("        cmpi.b  #0xFF, 0xD00058\n        beq     _sans_cartouche\n",
          "        nop                             | MUTATION : le slot vide reçoit la main\n")],
        "sans cartouche, la main remise au slot vide : le watchdog relance la carte en boucle",
    ),
    # Le flash cart (le 2026-10-28) : un seul parcours des slots, à la trame 1, comme avant ce lot.
    "carte-lente-ignoree": (
        "flash-cart", "c0.s",
        [("        .equ    ATTENTE_CARTE, 270\n", "        .equ    ATTENTE_CARTE, 1        | MUTATION : un seul parcours\n")],
        "une cartouche muette aux premières trames passe pour un slot vide : le boot finit dans les autotests",
    ),
    # Le gestionnaire de la carte mémoire (le 2026-10-24) : une mutation par fonction de l'écran MEMORY CARD.
    "cm-liste-vide": (
        "cm-liste", "gestion-carte.s",
        [("1:      cmpi.b  #0xFF, (%a1)\n        beq.s   3f\n        addq.w  #1, %d1\n",
          "1:      cmpi.b  #0xFF, (%a1)\n        bra.s   3f              | MUTATION : aucune sauvegarde comptée\n        addq.w  #1, %d1\n")],
        "la liste ne montre aucune sauvegarde",
    ),
    "cm-nom-absent": (
        "cm-liste", "gestion-carte.s",
        [(".Lnom:\n        suba.l  %a2, %a2\n        tst.w   %d0\n",
          ".Lnom:\n        suba.l  %a2, %a2\n        rts                     | MUTATION : jamais de nom\n        tst.w   %d0\n")],
        "le nom du jeu n'est plus cherché dans la backup RAM",
    ),
    "cm-blocs-faux": (
        "cm-liste", "gestion-carte.s",
        [("        cmpi.b  #1, %d1\n        dbeq    %d2, 1b\n",
          "        cmpi.b  #1, %d1\n        bra.s   2f              | MUTATION : le premier bloc seul\n        dbeq    %d2, 1b\n")],
        "une sauvegarde de plusieurs blocs est comptée pour un",
    ),
    "cm-sans-defilement": (
        "cm-liste", "gestion-carte.s",
        [("        move.w  %d0, %d6                | au-dessous\n",
          "        nop                             | MUTATION : la fenêtre ne descend pas\n")],
        "la liste ne défile pas vers le bas",
    ),
    "cm-libres-faux": (
        "cm-libres", "gestion-carte.s",
        [("        lea     T_FAT + 5, %a2\n", "        lea     T_FAT + 4, %a2              | MUTATION : un bloc trop tôt\n")],
        "les blocs libres comptés depuis le bloc 4",
    ),
    "cm-effacer-inerte": (
        "cm-effacer", "gestion-carte.s",
        [("        move.b  #0x04, CMD\n", "        move.b  #0x07, CMD              | MUTATION : une lecture du nom au lieu de l'effacement\n")],
        "A, A sur une sauvegarde ne l'efface pas",
    ),
    "cm-sans-confirmation": (
        "cm-annuler", "gestion-carte.s",
        [(".Lconfirmer:\n        cmpi.b  #3, V_CONF\n        bcc     .Lc_attente\n        btst    #4, %d0\n",
          ".Lconfirmer:\n        cmpi.b  #3, V_CONF\n        bcc     .Lc_attente\n"
          "        btst    #5, %d0                 | MUTATION : B confirme aussi\n        bne.s   1f\n        btst    #4, %d0\n")],
        "B confirme l'effacement au lieu d'y renoncer",
    ),
    "cm-formater-inerte": (
        "cm-formater cm-non-formatee", "gestion-carte.s",
        [("2:      move.b  #0x00, CMD              | formater\n",
          "2:      move.b  #0x07, CMD              | MUTATION : rien n'est formaté\n")],
        "FORMAT CARD, A, A ne formate pas",
    ),
    "cm-non-formatee-muette": (
        "cm-non-formatee", "gestion-carte.s",
        [("        lea     .Ltxt_non_formatee, %a2\n", "        lea     .Ltxt_sans, %a2                 | MUTATION : NO CARD\n")],
        "une carte non formatée est dite absente",
    ),
    "cm-sans-carte-muette": (
        "cm-sans-carte", "gestion-carte.s",
        [(".Lveut_formater:\n        cmpi.b  #0x80, V_ETAT\n        beq.s   .Lsans_carte\n",
          ".Lveut_formater:\n        cmpi.b  #0x80, V_ETAT\n        nop                             | MUTATION : pas de refus sans carte\n")],
        "FORMAT CARD sans carte demande une confirmation au lieu de dire NO CARD",
    ),
    "cm-protection-ignoree": (
        "cm-protegee", "gestion-carte.s",
        [("        | Une sauvegarde : DELETE ?\n        btst    #6, STATUS_B\n        bne.s   .Lprotegee\n",
          "        | Une sauvegarde : DELETE ?\n        nop                             | MUTATION : la protection n'est pas lue\n")],
        "une carte protégée propose l'effacement",
    ),
    "cm-insertion-ignoree": (
        "cm-insertion", "gestion-carte.s",
        [("        cmp.b   V_STB, %d0\n        beq.s   1f\n",
          "        cmp.b   V_STB, %d0\n        bra.s   1f              | MUTATION : la carte n'est jamais relue\n")],
        "une carte insérée pendant l'écran n'est pas relue",
    ),
    "cm-confirmation-survit": (
        "cm-insertion", "gestion-carte.s",
        [("6:      clr.b   V_CONF                  | une confirmation visait l'ancienne carte : abandonnée\n",
          "6:      nop                             | MUTATION : la confirmation survit\n")],
        "une confirmation en attente survit au changement de carte : A efface la sauvegarde de la nouvelle",
    ),
    "aes-sans-restauration": (
        "aes-scores", "c0.s",
        [("_restaurer_jeu:\n        bsr     _bloc_jeu\n",
          "_restaurer_jeu:\n        tst.b   0x10FD82                | MUTATION : rien de restauré en mode AES\n"
          "        beq.s   9f\n        bsr     _bloc_jeu\n")],
        "en mode AES, la sauvegarde du jeu n'est plus restaurée au boot : ses scores repartent des défauts",
    ),
    "gel-inerte": (
        "scores-gel", "cal.s",
        [("        tst.b   %d0\n        beq.s   1f\n        move.b  0xD00219, 0x10FDD2",
          "        tst.b   %d0\n        bra.s   1f              | MUTATION : la vraie date aux jeux\n        move.b  0xD00219, 0x10FDD2")],
        "SCORE RESET OFF ne gèle plus la date que READ_CALENDAR rend aux jeux",
    ),
    "score-reset-oublie": (
        "scores-gel", "dip.s",
        [("        jsr     _reglages_ecrire_scores\n", "        nop                             | MUTATION : SCORE RESET jamais enregistré\n")],
        "l'éditeur n'enregistre plus SCORE RESET",
    ),
    "bf-carte-nom-prom": (
        "bf-carte", "gestion-carte.s",
        [("        lea     0xD002A0, %a2\n", "        lea     0x000200, %a2           | MUTATION : le nom lu dans la P-ROM\n")],
        "le nom du jeu lu dans la cartouche sous REG_BRDFIX",
    ),
    # Les réglages de la borne, le 2026-10-25 (relevé --ref-borne de bench/parcours.sh).
    "bo-sous-ecran-inerte": (
        "bo-ecran", "dip.s",
        [(".Lch_borne:\n        move.w  %d6, F_SV_D6(%a6)\n",
          ".Lch_borne:\n        rts                             | MUTATION : le sous-écran ne s'ouvre pas\n        move.w  %d6, F_SV_D6(%a6)\n")],
        "A sur CABINET SETTINGS n'ouvre plus le sous-écran",
    ),
    "bo-borne-oubliee": (
        "bo-ecran bo-free-play", "dip.s",
        [("        jsr     _reglages_ecrire_borne\n", "        nop                             | MUTATION : la borne jamais enregistrée\n")],
        "l'éditeur n'enregistre plus les réglages de la borne",
    ),
    "bo-libre-inerte": (
        "bo-free-play bo-fp-p2 bo-fp-joint dip-fp-reglage", "io.s",
        [("        btst    #0, BORNE\n        bne.s   8f                      | FREE PLAY de CABINET SETTINGS\n",
          "        btst    #0, BORNE\n        nop                             | MUTATION : FREE PLAY ignoré\n")],
        "FREE PLAY ON (commutateur 7 à OFF) : START sans crédit reste refusé",
    ),
    "bo-p2-seul": (
        "bo-fp-p2 dip-fp-p2", "io.s",
        [("        moveq   #3, %d1                 | titre ou démo, START P2 : les deux joueurs\n",
          "        nop                             | MUTATION : START P2 ne fait partir que P2\n")],
        "en free play, START P2 en démo ne fait plus partir les deux joueurs",
    ),
    "bo-credit-refuse": (
        "bo-free-play", "reglages.s",
        [("1:      btst    #0, %d0\n        bne.s   2f\n", "1:      btst    #0, %d0\n        nop                             | MUTATION\n")],
        "FREE PLAY ne pose plus le bit 7 de BORNE : CREDIT_CHECK refuse, aof dit INSERT COIN en démo",
    ),
    "bo-continue-pris": (
        "bo-no-continue", "io.s",
        [("        btst    #1, BORNE               | NO CONTINUE : voir `_io_sans_continue`\n        bne     _io_sans_continue\n", "")],
        "NO CONTINUE ON : le continue est pris quand même",
    ),
    "bo-aes-non-masque": (
        "bo-aes", "reglages.s",
        [("        andi.b  #0x08, %d0              | mode AES : les trois inertes, CHEATS/DEBUG gardé\n", "        nop                             | MUTATION : rien de masqué en mode AES\n")],
        "en mode AES, les réglages de la borne agissent : NO CONTINUE refuse le continue",
    ),
    "bo-aes-affiche": (
        "bo-aes", "dip.s",
        [("        cmpi.b  #1, F_MODE(%a6)\n        bne.s   1f\n        lea     .Ltxt_mvs_seul, %a3\n",
          "        cmpi.b  #1, F_MODE(%a6)\n        bra.s   1f                      | MUTATION\n        lea     .Ltxt_mvs_seul, %a3\n")],
        "le sous-écran ne dit plus MVS ONLY en mode AES",
    ),
    "bo-demo-sonore": (
        "bo-demo-muette", "reglages.s",
        [("        btst    #2, BORNE\n        beq.s   1f                      | DEMO SOUND ON (ou mode AES)\n",
          "        btst    #2, BORNE\n        bra.s   1f                      | MUTATION : DEMO SOUND OFF ignoré\n")],
        "DEMO SOUND OFF : la démo garde son son",
    ),
    "bo-demo-toujours-muette": (
        "bo-demo-muette", "reglages.s",
        [("        cmpi.b  #2, %d2\n        bne.s   1f                      | pas une démo : le son\n", "")],
        "DEMO SOUND OFF coupe aussi le titre après la pièce (le comportement du BIOS SNK)",
    ),
    # Le catalogue des cheats et CHEATS/DEBUG, le 2026-10-25 (relevé --ref-cheats de bench/parcours.sh).
    "cat-mslug2-perdu": (
        "cheats-vies", "cheats.s",
        # Sans le nombre de cheats, qui change à chaque lot : la mutation reste applicable.
        [("        JEU     0x0241, 0xBE57, ", "        | MUTATION : le NGH de mslug2 faussé\n        JEU     0x0242, 0xBE57, ")],
        "l'entrée de mslug2 n'est plus reconnue : pas de ligne INFINITE LIVES",
    ),
    "cd-trouver-ignore": (
        "bo-cd-menu", "cheats.s",
        [("_cheats_trouver:\n        btst    #3, BORNE_RAM\n        bne.s   8f\n", "_cheats_trouver:\n")],
        "CHEATS/DEBUG OFF : le menu offre encore les cheats du jeu",
    ),
    "cd-editeur-garde": (
        "bo-cd-menu", "menu.s",
        [("3:      cmpi.w  #7, %d0                 | MEMORY EDITOR, CHEATS/DEBUG OFF : la ligne en blanc\n        bne.s   7f\n"
          "        btst    #3, BORNE_RAM\n        bne.s   9f\n", "3:\n")],
        "CHEATS/DEBUG OFF : la ligne MEMORY EDITOR reste affichée",
    ),
    "cd-dernier-choix": (
        "bo-cd-menu", "menu.s",
        [("        subq.w  #1, %d1                 | CHEATS/DEBUG OFF : GAME SETTINGS est le dernier\n",
          "        nop                             | MUTATION : la ligne en blanc reste choisissable\n")],
        "CHEATS/DEBUG OFF : « haut » depuis RESUME mène à la ligne en blanc de MEMORY EDITOR, qui l'ouvre",
    ),
    "cd-moteur-ignore": (
        "bo-cd-gel", "cheats.s",
        [("        btst    #3, BORNE_RAM           | CHEATS/DEBUG OFF : tout éteint, rien d'écrit\n        bne.w   .Lcoupes\n", "")],
        "CHEATS/DEBUG OFF : un gel déjà actif s'applique encore",
    ),
    "cd-bit-perdu": (
        "bo-cd-menu bo-cd-gel", "reglages.s",
        [("        andi.b  #0x0F, %d0\n        move.b  %d0, BORNE_BR\n", "        andi.b  #0x07, %d0              | MUTATION\n        move.b  %d0, BORNE_BR\n")],
        "CHEATS/DEBUG n'est pas enregistré : la machine relancée l'a de nouveau à ON",
    ),
    "cd-aes-masque": (
        "bo-aes", "dip.s",
        [("        cmpi.b  #15, %d0\n        beq.s   1f                      | CHEATS/DEBUG : dans les deux modes\n", "")],
        "en mode AES, CHEATS/DEBUG dit MVS ONLY comme les trois autres",
    ),
    "cd-ligne-absente": (
        "bo-ecran", "dip.s",
        [("        cmpi.b  #17, %d0\n        bcs.s   2b\n        moveq   #5, %d6\n",
          "        cmpi.b  #15, %d0                | MUTATION : trois lignes\n        bcs.s   2b\n        moveq   #3, %d6\n")],
        "le sous-écran CABINET SETTINGS n'a plus sa ligne CHEATS/DEBUG",
    ),
    "grille-haute-ff": (
        "demo-ssideki", "grille.s",
        [("        .byte   grille_x >> 14\n", "        .byte   0xFF                    | MUTATION : le plan haut au remplissage d'avant\n")],
        "le plan $C03000-$C03FFF de la grille revient à $FF : la démo de ssideki se fige après l'intro du stade",
    ),
    "cd-defaut-off": (
        "cheats", "reglages.s",
        [("3:      move.b  %d0, BORNE\n", "3:      bset    #3, %d0                 | MUTATION : CHEATS/DEBUG à OFF par défaut\n        move.b  %d0, BORNE\n")],
        "CHEATS/DEBUG est à OFF sans qu'on l'ait choisi : le menu n'a plus les cheats d'aof",
    ),
    "dfp-ignore": (
        "dip-free-play dip-fp-p2 dip-fp-chaud", "io.s",
        [("        btst    #6, DIPSW\n        bne     9b                      | ni l'un ni le commutateur : refusé\n",
          "        btst    #6, DIPSW\n        bra     9b                      | MUTATION : le commutateur 7 ignoré\n")],
        "le commutateur Free Play de la carte à ON : START sans crédit reste refusé",
    ),
    "dfp-bit-faux": (
        "dip-free-play dip-fp-p2", "io.s",
        [("        btst    #6, DIPSW\n        bne     9b                      | ni l'un ni le commutateur : refusé\n",
          "        btst    #7, DIPSW               | MUTATION : le bit du commutateur 8\n        bne     9b\n")],
        "START lit le commutateur 8 (« Freeze ») au lieu du 7",
    ),
    "dfp-credit-check": (
        "dip-free-play dip-fp-chaud", "io.s",
        [("        btst    #6, DIPSW               | le commutateur 7 à ON (bit à 0) : de même\n        beq.s   1f\n", ""),
         ("        btst    #6, DIPSW               | le commutateur 7 de même\n        beq.s   2f\n", "")],
        "CREDIT_CHECK ignore le commutateur : la démo dit INSERT COIN en free play",
    ),
    "dfp-cabinet-off": (
        "dip-fp-cabinet", "dip.s",
        [("1:      cmpi.b  #12, %d0\n        bne.s   4f\n", "1:      cmpi.b  #12, %d0\n        bra.s   4f                      | MUTATION\n")],
        "CABINET SETTINGS affiche FREE PLAY OFF sous le commutateur à ON",
    ),
    "dfp-cabinet-libre": (
        "dip-fp-cabinet", "dip.s",
        [("        btst    #6, DIPSW               | « Freeplay », bit 6 à 0 : ON\n        beq     .Lch_fin\n",
          "        btst    #6, DIPSW               | MUTATION : le verrou retiré\n        nop\n")],
        "FREE PLAY se change sous le commutateur : le réglage enregistré bouge",
    ),
    "setting-ignore": (
        "dip-setting", "dip.s",
        [("        btst    #0, DIPSW               | le commutateur 1, « Setting Mode », à ON\n        beq.s   1f\n", "")],
        "le commutateur 1 de la carte n'ouvre plus l'écran TEST",
    ),
    "setting-bit-faux": (
        "dip-setting", "dip.s",
        [("        btst    #0, DIPSW               | le commutateur 1, « Setting Mode », à ON\n",
          "        btst    #1, DIPSW               | MUTATION : le commutateur 2\n")],
        "l'écran TEST lit le commutateur 2 au lieu du 1",
    ),
    "geste-boot-ignore": (
        "geste-boot", "dip.s",
        [("        btst    #1, STATUS_B\n        beq.s   3f\n2:      rts\n", "        btst    #1, STATUS_B\n2:      rts\n")],
        "START + SELECT au boot n'ouvre plus l'écran TEST",
    ),
    "geste-boot-start-seul": (
        "geste-boot", "dip.s",
        [("        btst    #1, STATUS_B\n        beq.s   3f\n2:      rts\n", "        bra.s   1f                      | MUTATION : SELECT oublié\n2:      rts\n")],
        "START seul tenu au boot ouvre l'écran TEST",
    ),
    "geste-jeu-ignore": (
        "geste-jeu", "menu.s",
        [("4:      btst    #0, STATUS_B\n        bne.s   1f\n", "4:      bra.s   1f                      | MUTATION : TEST seul\n")],
        "START + SELECT en partie n'ouvre plus le menu en jeu",
    ),
    "geste-jeu-start-seul": (
        "geste-jeu", "menu.s",
        [("        btst    #1, STATUS_B\n        beq.s   5f\n1:      clr.w   MN_COMPTE\n",
          "        bra.s   3b                      | MUTATION : SELECT oublié\n1:      clr.w   MN_COMPTE\n")],
        "START seul tenu en partie ouvre le menu en jeu",
    ),
    "setting-toujours": (
        "dip-setting", "dip.s",
        [("        btst    #0, DIPSW               | le commutateur 1, « Setting Mode », à ON\n        beq.s   1f\n",
          "        btst    #0, DIPSW               | le commutateur 1, « Setting Mode », à ON\n        bra.s   1f                      | MUTATION\n")],
        "l'écran TEST s'ouvre à chaque boot, commutateur 1 à OFF compris",
    ),
    "geste-boot-select-seul": (
        "geste-boot", "dip.s",
        [("        btst    #0, STATUS_B            | START et SELECT de P1 tenus (voir l'en-tête)\n        bne.s   2f\n",
          "        nop                             | MUTATION : START oublié\n")],
        "SELECT seul tenu au boot ouvre l'écran TEST",
    ),
    "geste-jeu-select-seul": (
        "geste-jeu", "menu.s",
        [("4:      btst    #0, STATUS_B\n        bne.s   1f\n", "4:      nop                             | MUTATION : START oublié\n")],
        "SELECT seul tenu en partie ouvre le menu en jeu",
    ),
    "geste-toujours": (
        "geste-partie", "menu.s",
        [("4:      btst    #0, STATUS_B\n        bne.s   1f\n        btst    #1, STATUS_B\n        beq.s   5f\n",
          "4:      bra.s   3b                      | MUTATION : le geste toujours fait\n")],
        "le menu en jeu s'ouvre sans geste : une partie jouée normalement le rencontre",
    ),
    "avertissement-absent": (
        "dip-setting", "dip.s",
        [("        bne.s   1f\n        bsr     .Lavertir\n", "        bne.s   1f\n        nop                             | MUTATION\n")],
        "START, commutateur 1 encore à ON : le jeu sans avertissement",
    ),
    "avertissement-toujours": (
        "dip-setting", "dip.s",
        [("        btst    #0, DIPSW               | « Setting Mode » : bit 0 à 0, ON\n        bne.s   1f\n        bsr     .Lavertir\n",
          "        btst    #0, DIPSW               | « Setting Mode » : bit 0 à 0, ON\n        nop                             | MUTATION\n        bsr     .Lavertir\n")],
        "l'avertissement même commutateur 1 rebasculé à OFF",
    ),
    "geste-boot-adaptateur": (
        "geste-boot", "dip.s",
        [("        bcs.s   2b                      | les quatre tenus : le geste est refusé\n",
          "        nop                             | MUTATION : A, B, C et D non vérifiés\n")],
        "l'adaptateur BlueRetro (START, SELECT, A, B, C et D tenus) ouvre l'écran TEST au boot",
    ),
    "geste-boot-un-bouton": (
        "geste-boot", "dip.s",
        [("3:      cmpi.b  #0x10, P1CNT\n", "3:      cmpi.b  #0xF0, P1CNT            | MUTATION : un seul des quatre suffit\n")],
        "START + SELECT + A au boot n'ouvre plus l'écran TEST",
    ),
    "geste-jeu-adaptateur": (
        "geste-jeu", "menu.s",
        [("        bra.s   1b                      | les quatre tenus : refusé\n",
          "        bra.s   3b                      | MUTATION : A, B, C et D non vérifiés\n")],
        "l'adaptateur BlueRetro (START, SELECT, A, B, C et D tenus) ouvre le menu en jeu",
    ),
    "geste-jeu-un-bouton": (
        "geste-jeu", "menu.s",
        [("5:      cmpi.b  #0x10, P1CNT\n", "5:      cmpi.b  #0xF0, P1CNT            | MUTATION : un seul des quatre suffit\n")],
        "START + SELECT + A en partie n'ouvre plus le menu en jeu",
    ),
    # Les intitulés en région JAPAN (measured/2026-10-27-intitules-japon.tsv).
    "japon-filtre": (
        "japon-intitules", "dip.s",
        [("2:      addi.w  #0x200, %d2             | $300 / $400 + b\n",
          "2:      moveq   #0x20, %d2              | MUTATION : le filtre remis, une espace\n")],
        "l'écran TEST du boot en JAPAN rend en espaces les octets hors ASCII des intitulés",
    ),
    "japon-banque-100": (
        "japon-intitules", "dip.s",
        [("2:      addi.w  #0x200, %d2             | $300 / $400 + b\n",
          "2:      nop                             | MUTATION : $100 / $200 + b au lieu de $300 / $400\n")],
        "l'écran TEST du boot en JAPAN écrit les octets hors ASCII dans la banque ASCII ($100 au lieu de $300)",
    ),
    "gs-sans-emprunt": (
        "gs-japon", "reglages-jeu.s",
        [("        beq.s   4b\n        nop\n3:      move.w  #0x0400, (%a2)",
          "        nop                             | MUTATION : pas d'emprunt au bloc USA\n        nop\n3:      move.w  #0x0400, (%a2)")],
        "GAME SETTINGS en JAPAN garde les intitulés du bloc japonais, en espaces",
    ),
    "gs-sans-garde": (
        "gs-japon-garde", "reglages-jeu.s",
        [("2:      cmp.b   %d2, %d3\n        bne.s   9f\n",
          "2:      cmp.b   %d2, %d3\n        nop                     | MUTATION : la structure n'est pas comparée\n")],
        "GAME SETTINGS en JAPAN emprunte les intitulés d'un bloc USA de structure différente (bstars)",
    ),
    "gs-regle-boot": (
        "gs-japon-garde", "menu.s",
        [("2:      moveq   #0x20, %d0\n3:      moveq   #0, %d1\n",
          "2:      addi.w  #0x300, %d0             | MUTATION : la règle du boot sous la S ROM\n3:      moveq   #0, %d1\n")],
        "un octet hors ASCII s'écrit en tuile $300 + b sous la police de la cartouche, dans le cadre du menu",
    ),
    # Le CRC32 de la cartouche et les debug dips, le 2026-10-25 (relevé --ref-crc).
    "crc-ordre-cpu": (
        "crc-fixe crc-banques crc-miroir", "crc.s",
        [("        moveq   #0, %d2\n        move.b  %d1, %d2                | l'octet bas, le premier du fichier\n",
          "        rol.w   #8, %d1                 | MUTATION : l'octet haut d'abord\n        moveq   #0, %d2\n        move.b  %d1, %d2\n")],
        "le CRC somme les octets dans l'ordre du 68000, plus dans celui des fichiers de MAME",
    ),
    "crc-sans-crtfix": (
        "bf-crc bf-crc-banque", "crc.s",
        [("        move.b  %d0, CRTFIX             | la cartouche répond, sa S ROM au plan fixe\n",
          "        nop                             | MUTATION : la P-ROM lue sous REG_BRDFIX\n")],
        "le CRC lit la P-ROM sous REG_BRDFIX : du bus flottant sur le matériel",
    ),
    "crc-banques-ignorees": (
        "crc-banques bf-crc-banque", "crc.s",
        [("        bne.s   .Lbanques\n", "        nop                             | MUTATION : jamais de banque\n")],
        "l'écran dit BANKS NONE même quand la fenêtre n'est pas la P-ROM fixe",
    ),
    "crc-miroir-ignore": (
        "crc-miroir", "crc.s",
        [("1:      cmpi.l  #0x10000, %d6           | 64 Kio au moins\n        bls.s   2f\n",
          "1:      bra.s   2f                      | MUTATION : jamais de miroir\n")],
        "une P-ROM de 512 Kio vue en miroir est sommée sur 1 Mio",
    ),
    "crc-flottant-ignore": (
        "crc-flottant", "crc.s",
        [("        bsr     .Lconstante\n        beq.s   .Lsans_banque\n",
          "        nop                             | MUTATION : la fenêtre constante compte\n")],
        "une fenêtre qui ne lit qu'un mot (pas de puce de banques) est comptée comme une banque",
    ),
    "crc-miroir-de-banque": (
        "crc-banques bf-crc-banque", "crc.s",
        [("        beq.s   .Lb_miroir\n", "        nop                             | MUTATION : un miroir compte\n")],
        "les banques miroirs entrent dans le CRC, huit banques comptées",
    ),
    "dd-jamais-pose": (
        "dd-effet", "debug.s",
        [("        bset    #7, GL_MASQUE           | le bit 15 du mot\n", "        nop                             | MUTATION\n")],
        "le moteur ne pose jamais les debug dips : une seule écriture, que kof94 efface",
    ),
    "dd-ecran-inerte": (
        "dd-effet", "debug.s",
        [("        bchg    %d0, %d1\n", "        nop                             | MUTATION : A ne bascule rien\n")],
        "A ne bascule aucun bit de l'écran DEBUG DIPS",
    ),
    "dd-dip2-perdu": (
        "dd-effet", "debug.s",
        [("1:      eori.w  #1, %d6\n", "1:      nop                             | MUTATION : haut et bas inertes\n")],
        "haut et bas ne mènent plus à la rangée DIP 2",
    ),
    "dd-sauve": (
        "dd-effet", "c0.s",
        [("        jsr     _dd_retirer             | registres rendus\n", "        nop                             | MUTATION : le masque sauvé\n")],
        "les debug dips partent en backup RAM avec la sauvegarde du jeu",
    ),
    "dd-ouvert-a-off": (
        "dd-off", "dip.s",
        [("        btst    #3, F_BORNE(%a6)\n        bne     .Lch_fin\n        jsr     _debug_dips             | registres rendus\n",
          "        jsr     _debug_dips             | MUTATION : ouvert sous CHEATS/DEBUG OFF\n")],
        "sous CHEATS/DEBUG OFF, la ligne DEBUG DIPS s'ouvre encore",
    ),
    "dd-off-ignore": (
        "dd-off", "debug.s",
        [("_dd_poser:\n        movem.l %d2/%a0, -(%sp)\n        btst    #3, BORNE_RAM\n        bne.s   8f\n",
          "_dd_poser:\n        movem.l %d2/%a0, -(%sp)\n")],
        "sous CHEATS/DEBUG OFF, le masque est encore posé à la sortie de l'écran TEST",
    ),
    "dd-ligne-absente": (
        "bo-ecran", "dip.s",
        [("        cmpi.b  #17, %d0\n        bcs.s   2b\n        moveq   #5, %d6\n",
          "        cmpi.b  #16, %d0                | MUTATION : quatre lignes\n        bcs.s   2b\n        moveq   #4, %d6\n")],
        "le sous-écran CABINET SETTINGS n'a plus sa ligne DEBUG DIPS",
    ),
    # L'écran ABOUT (`about.s`), le 2026-10-28.
    "ab-ligne-absente": (
        "ab-ecran", "dip.s",
        [("        move.b  #17, (%a2)              | ABOUT, avant CABINET SETTINGS\n        clr.b   1(%a2)\n"
          "        move.l  #.Ltxt_apropos, 6(%a2)\n        lea     T_ENTREE(%a2), %a2\n        addq.w  #1, %d6\n",
          "                                        | MUTATION : pas de ligne ABOUT\n")],
        "l'écran TEST n'a plus de ligne ABOUT",
    ),
    "ab-ne-s-ouvre-pas": (
        "ab-ecran", "dip.s",
        [("        jsr     _a_propos               | registres rendus\n",
          "        nop                             | MUTATION : ABOUT ne s'ouvre pas\n")],
        "A sur la ligne ABOUT n'ouvre pas l'écran",
    ),
    "ab-start-ignore": (
        "ab-ecran", "about.s",
        [("        btst    #5, %d0                 | START : retour\n        beq.s   .Lboucle\n",
          "        bra.s   .Lboucle                | MUTATION : START ignoré\n")],
        "START ne referme plus l'écran ABOUT",
    ),
    # Les commutateurs 2, 3 et 8 de la carte (DECISIONS §21).
    "gel-jamais": (
        "dip-gel", "io.s",
        [("        tst.b   DIPSW\n        bpl     _io_gel\n",
          "        tst.b   DIPSW\n        nop                             | MUTATION : jamais de gel\n")],
        "le commutateur 8 à ON ne suspend plus le jeu",
    ),
    "gel-toujours": (
        "dip-gel-off", "io.s",
        [("        tst.b   DIPSW\n        bpl     _io_gel\n",
          "        tst.b   DIPSW\n        bmi     _io_gel                 | MUTATION : le sens du commutateur inversé\n"),
         ("        tst.b   DIPSW\n        bpl.s   1b\n",
          "        tst.b   DIPSW\n        bmi.s   1b                      | MUTATION\n")],
        "le jeu suspendu commutateur 8 à OFF",
    ),
    "gel-boot-noir": (
        "dip-gel-boot", "ecran.s",
        [("        move.w  #0xF000, %d3\n        move.w  #CASE_GEL1, %d1\n",
          "        bra.s   1f                      | MUTATION : l'écran noir, comme la référence\n"
          "        move.w  #0xF000, %d3\n        move.w  #CASE_GEL1, %d1\n")],
        "au boot, le gel sans message",
    ),
    "gel-boot-absent": (
        "dip-gel-boot", "ecran.s",
        [("        bmi.s   .Lsans_gel\n", "        bra.s   .Lsans_gel              | MUTATION\n")],
        "au boot, le commutateur 8 ignoré : la main au jeu malgré lui",
    ),
    "mj-jamais": (
        "dip-mahjong", "c0.s",
        [("        moveq   #3, %d0\n5:      move.b  %d0, 0x10FD94           | BIOS_P1STATUS\n",
          "        moveq   #0, %d0                 | MUTATION\n5:      move.b  %d0, 0x10FD94           | BIOS_P1STATUS\n")],
        "le commutateur 3 à ON n'est jamais pris : le panneau lu comme un joystick",
    ),
    "mj-sans-front": (
        "dip-mahjong", "io.s",
        [("        move.b  %d2, 0x10FDA1           | les fronts\n",
          "        clr.b   0x10FDA1                | MUTATION : pas de front pour la rangée A-G\n")],
        "le front de la rangée A-G n'est plus écrit",
    ),
    "mj-boot-seul": (
        "dip-mahjong dip-4p", "c0.s",
        [("        bsr     _commutateurs           | BIOS_P1STATUS et $10FEF8, comme `_remettre_a_user`\n",
          "        nop                             | MUTATION : pas relus à la pièce\n")],
        "les commutateurs 2 et 3 ne sont plus relus à la pièce",
    ),
    "mj-toujours": (
        "dip-mj-off", "c0.s",
        [("        btst    #2, 0x300001\n        bne.s   5f\n",
          "        btst    #2, 0x300001\n        nop                             | MUTATION\n")],
        "le panneau toujours balayé en mahjong, commutateur 3 à OFF compris",
    ),
    "mj-off-sourd": (
        "dip-mj-off", "io.s",
        [("        move.b  #0x1B, 0x380001\n        | COMMUTATEUR 3 À ON",
          "        nop                             | MUTATION : la sortie $00 de la trame d'avant\n        | COMMUTATEUR 3 À ON")],
        "commutateur 3 à OFF, le panneau n'est plus lu (le défaut d'avant le correctif)",
    ),
    "4p-jamais": (
        "dip-4p", "c0.s",
        [("        moveq   #2, %d0\n5:      move.b  %d0, 0x10FEF8           | BIOS_4P_REQUESTED\n",
          "        moveq   #0, %d0                 | MUTATION\n5:      move.b  %d0, 0x10FEF8           | BIOS_4P_REQUESTED\n")],
        "le commutateur 2 n'est jamais recopié dans $10FEF8",
    ),
    "4p-toujours": (
        "dip-4p-off", "c0.s",
        [("        btst    #1, 0x300001\n        bne.s   5f\n",
          "        btst    #1, 0x300001\n        nop                             | MUTATION\n")],
        "$10FEF8 à 2 quel que soit le commutateur 2",
    ),
    # L'autofire, 7, le 2026-10-27 (relevé --ref-af).
    "af-inerte": (
        "af-tir", "io.s",
        [("        move.b  AF_PH1, %d1\n        move.b  0(%a0,%d1.w), %d3       | les boutons vus relâchés à cette phase\n"
          "        and.b   %d0, %d3\n        eor.b   %d3, %d0\n",
          "        move.b  AF_PH1, %d1\n        move.b  0(%a0,%d1.w), %d3       | les boutons vus relâchés à cette phase\n"
          "        and.b   %d0, %d3\n        nop                             | MUTATION : rien de relâché\n")],
        "le turbo de P1 ne relâche jamais le bouton tenu",
    ),
    "af-cadence": (
        "af-tir", "autofire.s",
        [(".Lperiodes: .byte 6, 4, 2, 4", ".Lperiodes: .byte 6, 6, 2, 4             | MUTATION : 15 tirs/s à 10")],
        "15 tirs/s donne le motif de 10",
    ),
    "af-non-sauve": (
        "af-sauve", "autofire.s",
        [("        move.b  AF_REGLAGE, %d0\n        bsr     .Lenregistrer\n",
          "        move.b  AF_REGLAGE, %d0\n        nop                             | MUTATION : rien en backup RAM\n")],
        "le réglage n'est plus enregistré en backup RAM",
    ),
    "af-charge-jamais": (
        "af-sauve", "c0.s",
        [("        jsr     _af_charger             | l'autofire du jeu servi (`autofire.s`), registres rendus\n"
          "        move.b  #0x03, 0x320000         | REG_SOUND : le reset du Z80",
          "        nop                             | MUTATION : pas chargé à la remise\n"
          "        move.b  #0x03, 0x320000         | REG_SOUND : le reset du Z80"),
         ("        bsr     _commutateurs           | BIOS_P1STATUS et $10FEF8 (plus bas)\n"
          "        jsr     _af_charger             | l'autofire du jeu servi (`autofire.s`), registres rendus\n",
          "        bsr     _commutateurs           | BIOS_P1STATUS et $10FEF8 (plus bas)\n"
          "        nop                             | MUTATION : pas chargé à la remise\n")],
        "la fiche du jeu n'est plus chargée à la remise de la main",
    ),
    "af-off-ignore": (
        "af-off", "autofire.s",
        [("        bchg    %d1, %d0                | A : bascule\n",
          "        bset    %d1, %d0                | MUTATION : A met à ON, jamais à OFF\n")],
        "A sur une ligne de bouton ne repasse plus à OFF",
    ),
    "af-off-non-retire": (
        "af-off", "autofire.s",
        [("1:      bsr.s   .Lchercher\n        cmpa.w  #0, %a0\n        beq.s   3f\n",
          "1:      bsr.s   .Lchercher\n        cmpa.w  #0, %a0\n        bra.s   3f                      | MUTATION\n")],
        "un jeu remis au défaut garde sa fiche : OFF n'est pas enregistré",
    ),
    "af-mahjong-pris": (
        "af-mahjong", "io.s",
        [("        cmpi.b  #3, 0x10FD94\n        beq     _io_mahjong\n",
          "        cmpi.b  #3, 0x10FD94\n        nop                             | MUTATION\n        nop\n")],
        "commutateur 3 à ON, le panneau passe par le chemin des manettes et son turbo",
    ),
    # Les garanties sur les défauts d'UniBIOS (DECISIONS §23).
    "boot-police-cartouche": (
        "boot-graphismes", "ecran.s",
        [("        jsr     _fix_clear\n        | L'heure",
          "        jsr     _fix_clear\n        move.b  %d0, 0x3A001B           | MUTATION : REG_CRTFIX, la S ROM de la cartouche\n"
          "        | L'heure")],
        "l'écran de boot s'écrit avec la police de la cartouche",
    ),
    "boot-sans-lsp": (
        "boot-graphismes", "ecran.s",
        [("        jsr     _lsp_1st\n        jsr     _fix_clear\n        | L'heure",
          "        jsr     _fix_clear              | MUTATION : les sprites de la mise sous tension laissés\n        | L'heure")],
        "l'écran de boot laisse affichés les sprites que la VRAM porte à la mise sous tension",
    ),
    "vierge-inutilises": (
        "dip-vierge", "dip.s",
        [("2:      bsr     .Linutilises\n", "2:      nop                             | MUTATION\n")],
        "les réglages inutilisés d'une entrée jamais initialisée sont enregistrés tels quels",
    ),
    "vierge-sans-validation": (
        "dip-vierge", "dip.s",
        [("1:      bsr     .Lnormaliser\n        lea     T_ENTREE(%a2), %a2\n        dbra    %d7, 1b\n",
          "1:      nop                             | MUTATION : les valeurs reçues affichées telles quelles\n"
          "        lea     T_ENTREE(%a2), %a2\n        dbra    %d7, 1b\n")],
        "l'éditeur montre et enregistre les octets d'une entrée jamais initialisée",
    ),
    "relecture-sans-validation": (
        "dip-corrompue", "c0.s",
        [("        jsr     _dip_valider            | registres rendus\n",
          "        nop                             | MUTATION : GAME_DIP relu sans validation\n        nop\n        nop\n")],
        "un bloc soft-DIP quelconque d'un jeu connu est servi tel quel au jeu",
    ),
    "mj-page-absente": (
        "tests-mahjong", "tests.s",
        [("        btst    #2, DIPSW\n        beq     .Lt_mahjong\n",
          "        btst    #2, DIPSW\n        nop                             | MUTATION : jamais la page du panneau\n        nop\n")],
        "INPUT TEST montre les manettes commutateur 3 à ON",
    ),
    "mj-touche-muette": (
        "tests-mahjong", "tests.s",
        [("        move.b  #0x12, 0x380001         | rangée H-N\n        move.b  P1CNT, %d4\n",
          "        move.b  #0x12, 0x380001         | rangée H-N\n        move.b  #0xFF, %d4              | MUTATION : rangée H-N jamais lue\n")],
        "la rangée H-N de la page du panneau reste à 0",
    ),
    "veille-jamais": (
        "jukebox-veille", "jukebox.s",
        [("        bsr     .Leteindre\n", "        nop                             | MUTATION : jamais d'écran noir\n")],
        "le jukebox reste allumé sans entrée",
    ),
    "veille-reveil-agit": (
        "jukebox-veille", "jukebox.s",
        [("        moveq   #0, %d6\n        bra     .Lboucle\n7:      moveq   #0, %d3\n",
          "        moveq   #0, %d6\n        bra.s   9f                      | MUTATION : le réveil agit aussi\n7:      moveq   #0, %d3\n")],
        "la touche qui réveille le jukebox change aussi le code",
    ),
    "cp-sans-ecrasement": (
        "cm-copier", "gestion-carte.s",
        [("        move.b  #4, V_CONF              | déjà là : écraser ?\n        bsr     .Lmsg_ecraser\n        bra     .Lboucle\n",
          "        bra.s   4f                      | MUTATION : écrasé sans demander\n        bsr     .Lmsg_ecraser\n        bra     .Lboucle\n")],
        "la copie écrase une sauvegarde de la carte cible sans demander",
    ),
    "cp-ram-perdue": (
        "cm-copier", "gestion-carte.s",
        [("        jsr     _card\n        bsr     .Lrendre\n",
          "        jsr     _card\n        nop                             | MUTATION : la RAM du jeu non rendue\n        nop\n")],
        "la copie laisse la sauvegarde dans la RAM du jeu",
    ),
    # La table du sinus (DECISIONS §18).
    "sinus-ff": (
        "alpha-trajectoire howto-preisle2", "sinus.s",
        [("_table_sinus:\n", "_table_sinus:\n        .fill   256, 2, 0xFFFF          | MUTATION : la zone au remplissage d'avant\n        .if 0\n"),
         ("  | 248\n", "  | 248\n        .endif\n")],
        "$C04000-$C041FF revient à $FF : « haut » mène aussi à droite dans alpham2, l'objet de HOW TO PLAY n'apparaît pas",
    ),
    "sinus-un-ffff": (
        "howto-preisle2", "sinus.s",
        [("        .word   0x0001, 0xFFEC, 0xFFB1, 0xFF4E, 0xFEC4, 0xFE13, 0xFD3B, 0xFC3B  | 64\n",
          "        .word   0xFFFF, 0xFFEC, 0xFFB1, 0xFF4E, 0xFEC4, 0xFE13, 0xFD3B, 0xFC3B  | 64\n"),
         ("        .word   0x0001, 0xFFEC, 0xFFB1, 0xFF4E, 0xFEC4, 0xFE13, 0xFD3B, 0xFC3B  | 192\n",
          "        .word   0xFFFF, 0xFFEC, 0xFFB1, 0xFF4E, 0xFEC4, 0xFE13, 0xFD3B, 0xFC3B  | 192\n")],
        "1,0 codé $FFFF : le vaisseau d'alpham2 s'écarte d'un pixel, HOW TO PLAY de preisle2 diverge du témoin",
    ),
    "cp-inerte": (
        "cm-copier", "gestion-carte.s",
        [("4:      btst    #7, %d0                 | C : copier la sauvegarde de la ligne\n        bne     .Lcopier\n",
          "4:      btst    #7, %d0                 | C : copier la sauvegarde de la ligne\n        nop                             | MUTATION\n        nop\n")],
        "C ne copie pas",
    ),
    # Les menus au panneau de mahjong (DECISIONS §30).
    "pn-sans-traduction": (
        "pn-menu-on pn-valeur pn-verrou pn-jeu", "panneau.s",
        [("        tst.b   PANNEAU\n        bne.s   1f\n",
          "        tst.b   PANNEAU\n        nop                             | MUTATION : jamais traduit\n")],
        "commutateur 3 à ON, le panneau lu comme à OFF dans les menus",
    ),
    "pn-sans-1b": (
        "pn-menu-off pn-verrou", "panneau.s",
        [("        move.b  #0x1B, POUTPUT          | OFF : les rangées A-G et H-N confondues\n",
          "        nop                             | MUTATION : REG_POUTPUT laissé tel quel à OFF\n        nop\n        nop\n")],
        "commutateur 3 à OFF, P1 lu sous la sortie qu'un autre a laissée",
    ),
    "pn-verrou-relu": (
        "pn-verrou", "panneau.s",
        [("_panneau_p1:\n        tst.b   PANNEAU\n",
          "_panneau_p1:\n        bsr.s   _panneau_verrou         | MUTATION : relu à chaque lecture\n        tst.b   PANNEAU\n")],
        "le commutateur relu à chaque trame : basculé menu ouvert, la traduction change",
    ),
    "pn-e-f-echangees": (
        "pn-menu-on pn-valeur pn-verrou pn-jeu", "panneau.s",
        [("        rol.b   #4, %d0                 | A-D aux bits 4-7 (boutons), E, F, G aux bits 0-2\n",
          "        rol.b   #4, %d0                 | A-D aux bits 4-7 (boutons), E, F, G aux bits 0-2\n"
          "        move.l  %d1, -(%sp)             | MUTATION : E et F échangés (bits 0 et 1)\n"
          "        move.b  %d0, %d1\n        andi.b  #0xFC, %d0\n"
          "        lsr.b   #1, %d1\n        bcc.s   8f\n        bset    #1, %d0\n"
          "8:      lsr.b   #1, %d1\n        bcc.s   9f\n        bset    #0, %d0\n"
          "9:      move.l  (%sp)+, %d1\n")],
        "E descend et F monte",
    ),
    "restauration-avant-editeur": (
        "tests-sauvegarde", "c0.s",
        [("_slot_present:\n        bsr     _relire_dip\n",
          "_slot_present:\n        movea.l %a0, %a4                | MUTATION : restauré avant l'éditeur\n"
          "        moveq   #0, %d1\n        move.b  0xD00108, %d1\n        bsr     _restaurer_jeu\n"
          "        movea.l %a4, %a0\n        bsr     _relire_dip\n"),
         ("        moveq   #0, %d1\n        move.b  0xD00108, %d1\n        bsr     _restaurer_jeu\n"
          "        jsr     _dd_poser               | registres rendus\n",
          "        jsr     _dd_poser               | registres rendus\n")],
        "la sauvegarde d'un jeu déjà inscrit restaurée avant l'écran TEST : WORK RAM la détruit",
    ),
    "dd-ecrase-a-la-restauration": (
        "dd-connu", "c0.s",
        [("        bsr     _restaurer_jeu\n        jsr     _dd_poser               | registres rendus\n",
          "        bsr     _restaurer_jeu\n        nop                             | MUTATION : masque non reposé\n")],
        "la restauration d'un jeu déjà inscrit écrase les debug dips posés par l'écran TEST",
    ),
}


def appliquer(nom, dossier):
    if nom not in MUTATIONS:
        sys.exit(f"mutation inconnue : {nom} (--liste)")
    dossier = os.path.realpath(dossier)
    if dossier == DEPOT or dossier.startswith(DEPOT + os.sep):
        sys.exit(f"refus : {dossier} est dans le dépôt ; muter une copie jetable")
    _, fichier, paires, _ = MUTATIONS[nom]
    chemin = os.path.join(dossier, fichier)
    texte = open(chemin, encoding="utf-8").read()
    for avant, apres in paires:
        k = texte.count(avant)
        if k != 1:
            sys.exit(f"mutation {nom} : un passage est {k} fois dans {fichier}, 1 attendu")
        texte = texte.replace(avant, apres)
    open(chemin, "w", encoding="utf-8").write(texte)


def eprouver_une(nom, roms, travail):
    """Une mutation : sa copie, son parcours. Rend (tuée, ligne de verdict). Une mutation qui ne
    s'applique plus (`appliquer` sort par sys.exit) ou toute autre erreur donne une ligne ERREUR, comptée
    comme survivante : dans un thread du pool, une exception ne s'afficherait qu'à la fin."""
    try:
        return _eprouver_une(nom, roms, travail)
    except BaseException as e:  # SystemExit compris
        return False, f"ERREUR\t{nom}\t{MUTATIONS[nom][0]}\t{e}"


def _eprouver_une(nom, roms, travail):
    scenes = MUTATIONS[nom][0].split()
    d = os.path.join(travail, nom)
    src = os.path.join(d, "src")
    if os.path.isdir(src):
        shutil.rmtree(src)
    os.makedirs(d, exist_ok=True)
    shutil.copytree(os.path.join(PAQUET, "src", "c0"), src)
    appliquer(nom, src)
    p = subprocess.run([os.path.join(ICI, "parcours.sh"), "--sources", src, "--scenes", " ".join(scenes),
                        "--jobs", "2", "--cache", os.path.join(travail, "cache-temoins"),
                        roms, os.path.join(d, "travail")], capture_output=True, text=True)
    verdicts = {s: v for v, s in re.findall(r"^(PASS|FAIL)  (\S+)", p.stdout, re.M)}
    tuee = all(verdicts.get(s) == "FAIL" for s in scenes)
    raisons = "; ".join(l.strip() for l in p.stdout.splitlines() if l.startswith("FAIL  ")) or "aucun FAIL"
    with open(os.path.join(d, "parcours.out"), "w") as f:
        f.write(p.stdout + p.stderr)
    return tuee, f"{'TUEE' if tuee else 'SURVIT'}\t{nom}\t{' '.join(scenes)}\t{raisons}"


def eprouver(roms, travail, noms, paralleles):
    travail = os.path.realpath(travail)
    if travail == DEPOT or travail.startswith(DEPOT + os.sep):
        sys.exit(f"refus : {travail} est dans le dépôt")
    os.makedirs(travail, exist_ok=True)
    noms = noms or list(MUTATIONS)
    inconnues = [n for n in noms if n not in MUTATIONS]
    if inconnues:
        sys.exit(f"mutation(s) inconnue(s) : {' '.join(inconnues)}")
    survivantes = 0
    with concurrent.futures.ThreadPoolExecutor(max_workers=paralleles) as pool:
        for f in concurrent.futures.as_completed([pool.submit(eprouver_une, n, roms, travail) for n in noms]):
            tuee, ligne = f.result()
            survivantes += not tuee
            print(ligne, flush=True)
    print(f"{survivantes} mutation(s) survivante(s)")
    return 1 if survivantes else 0


if __name__ == "__main__":
    a = sys.argv[1:]
    if a == ["--liste"]:
        for nom, (scenes, fichier, _, quoi) in MUTATIONS.items():
            print(f"{nom}\t{scenes}\t{fichier}\t{quoi}")
    elif len(a) >= 3 and a[0] == "--eprouver":
        a = a[1:]
        paralleles = max(1, (os.cpu_count() or 4) // 2 - 1)
        if a[0] == "--paralleles":
            if len(a) < 2 or not a[1].isdigit():
                sys.exit(__doc__)
            paralleles = int(a[1])
            a = a[2:]
        if paralleles < 1 or len(a) < 2:
            sys.exit(__doc__)
        sys.exit(eprouver(a[0], a[1], a[2:], paralleles))
    elif len(a) == 2:
        appliquer(a[0], a[1])
        print(f"mutation {a[0]} appliquée à {a[1]}")
    else:
        sys.exit(__doc__)
