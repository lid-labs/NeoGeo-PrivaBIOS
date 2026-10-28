| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| READ_CALENDAR — l'entrée $C0045C du tableau d'appels : la date et l'heure du µPD4990A.
|
| Le créneau de six octets de `c0.s` ne porte qu'un `jmp` vers `_read_calendar` : le jeu y
| arrive par `jsr` et repart par notre `rts`.
|
| TROIS SORTES D'AFFIRMATIONS, et chacune le dit :
|   « mesuré »  : `measured/2026-10-19-read-calendar.tsv`, sous MAME, 311 appels complets
|                 sur blazstar et trally ;
|   « lu dans » : les pages « READ CALENDAR », « UPD4990 » et « Memory mapped registers »
|                 du NeoGeo Development Wiki, et la fiche NEC du µPD4990A (« IC-1755,
|                 1st edition, March 1997 »), consultées le 2026-10-19 ;
|   « SUPPOSÉ » : ni l'un ni l'autre, et c'est dit.
|
| LES ACCÈS, mesuré (point 1) : REG_RTCCTRL ($380051), DATA IN = bit 0, CLK = bit 1,
| STB = bit 2 ; REG_STATUS_A ($320001), bit 7. La commande $3 puis la commande $1, quatre
| bits chacune, poids faible d'abord, chaque bit écrit D, D|CLK, D, puis STB, 0 ; puis 52
| fois : lire le bit 7, CLK, 0. Soit 132 écritures et 52 lectures. Lu dans la fiche, p. 7 :
| [0,0,1,1] « Time Read » copie les compteurs dans le registre à décalage, [0,0,0,1]
| « Register Shift » le fait sortir sur DATA OUT, un bit par coup d'horloge.
|
| LES 52 BITS, mesuré (point 2), et lu dans la fiche, p. 4, figure 1 : seconde, minute,
| heure, jour (8 bits BCD chacun), jour de semaine (4), mois (4, en BINAIRE — « except
| months in hexadecimal »), année (8, BCD), puis les 4 bits du registre de commande, lus et
| non écrits.
|
| LES SEPT ÉCRITURES, mesuré (point 3), dans cet ordre : $10FDD8 seconde, $10FDD7 minute,
| $10FDD6 heure, $10FDD4 jour, $10FDD5 jour de semaine, $10FDD3 mois converti en BCD,
| $10FDD2 année. Rien d'autre en RAM de travail, la pile mise à part.
|
| L'ÉCART ENTRE DEUX ÉCRITURES. Lu dans la fiche, p. 2 (A.C. characteristics, à
| VDD − VSS = 2,0 V) et figures 2 (p. 11) et 5 (p. 13) : tDSU, tDHLD, tHLD et tSTB valent
| 1 µs au minimum ; « CLK Input Frequency » DC à 500 kHz, rapport cyclique 50 %, donc 1 µs
| par demi-période. À 12 MHz, 1 µs = 12 cycles. Compté sur le code ci-dessous, cycles des
| seules instructions exécutées entre deux écritures : 38 au moins (CLK puis 0, STB puis 0),
| soit 3,2 µs — en dessous des 4,5 µs mesurées sous la référence, au-dessus du minimum de
| la fiche. Une interruption ne fait qu'allonger un écart.
|
| LE DÉLAI DE « TIME READ », lu dans la fiche, p. 11 : le nouveau mode est valide au plus
| 20 µs après STB en Time Read (td2), 1 µs dans les autres (td1). SUPPOSÉ : la fiche ne dit
| pas si CLK peut battre pendant td2 ; on l'attend après chaque commande, et la première
| écriture qui suit le 0 de STB en est à 332 cycles au moins, 27,7 µs.
|
| AUCUN REGISTRE MODIFIÉ, hors CCR. SUPPOSÉ : « READ CALENDAR » ne dit rien de ce que
| l'appel préserve ; ne rien toucher est le choix qui ne casse aucun appelant. Le SR n'est
| pas touché, les interruptions restent ouvertes : le relevé voit un appel de la référence
| quitter la ROM du BIOS en son milieu, une interruption probablement (sa « limite de
| l'instrument »).
|
| HORS LOT, rien n'est écrit : l'initialisation de l'horloge au boot ($8 puis $7, point 4
| du relevé), SETUP_CALENDAR ($C00462) et le signal TP.
| ==================================================================================

        .text
        .global _read_calendar
        .global _read_calendar_jeu

| ----------------------------------------------------------------------------------
| READ_CALENDAR POUR LES JEUX, l'entrée $C0045C : `_read_calendar`, puis, si le réglage SCORE
| RESET est à OFF (`reglages.s`, `dip.s`), la date gelée par-dessus la vraie — année, mois, jour
| et jour de semaine ($10FDD2-$10FDD5) ; l'heure reste celle de l'horloge. L'écran de boot
| appelle `_read_calendar` lui-même : sa ligne CLOCK garde la vraie date.
| POURQUOI : des jeux remettent leurs tables de records aux valeurs d'usine quand la date qu'ils
| lisent a changé depuis la dernière fois. Mesuré le 2026-10-24 (`measured/2026-10-24-scores-
| date.tsv`) : 32 jeux du catalogue appellent READ_CALENDAR ; après un saut de 38 jours de
| l'horloge, 16 d'entre eux réécrivent une table de leur sauvegarde, et des initiales posées en tête
| disparaissent (aof, wh2, kof2001 ; à l'écran, BEST HEROES de wh2 : « SPX », puis les initiales
| d'usine). Une date qui ne bouge plus ne déclenche plus rien. UniBIOS 4.0 a une option de ce nom (`docs/ATTENTES.md`
| §1) ; son mécanisme n'est pas lu. SUPPOSÉ : qu'aucun jeu ne se serve de la date pour autre
| chose qu'un affichage ou ces remises — le réglage est à ON par défaut, la vraie date.
| Aucun registre modifié, hors CCR, comme `_read_calendar`.
| ----------------------------------------------------------------------------------
_read_calendar_jeu:
        bsr.s   _read_calendar
        movem.l %d0-%d1/%a0-%a1, -(%sp)
        jsr     _reglages_scores        | %d0.b : 1, la date des jeux est gelée
        tst.b   %d0
        beq.s   1f
        move.b  0xD00219, 0x10FDD2      | année, mois, jour, jour de semaine gelés
        move.b  0xD0021A, 0x10FDD3
        move.b  0xD0021B, 0x10FDD4
        move.b  0xD0021C, 0x10FDD5
1:      movem.l (%sp)+, %d0-%d1/%a0-%a1
        rts

_read_calendar:
        movem.l %d0-%d4/%a0-%a1, -(%sp)
        lea     0x380051, %a0           | REG_RTCCTRL
        lea     0x320001, %a1           | REG_STATUS_A, bit 7 : DATA OUT
        moveq   #3, %d1                 | Time Read
        bsr     .Lcommande
        moveq   #1, %d1                 | Register Shift
        bsr     .Lcommande

        | 52 bits, le premier lu au poids faible : %d2 = jour:heure:minute:seconde,
        | %d3.w = année:mois:jour de semaine, puis 4 bits de commande jetés.
        moveq   #31, %d4
1:      bsr     .Lbit
        roxr.l  #1, %d2                 | X ← le bit lu, il entre en haut
        dbra    %d4, 1b
        moveq   #15, %d4
2:      bsr     .Lbit
        roxr.w  #1, %d3
        dbra    %d4, 2b
        moveq   #3, %d4
3:      bsr     .Lbit
        dbra    %d4, 3b

        move.b  %d2, 0x10FDD8           | seconde
        lsr.l   #8, %d2
        move.b  %d2, 0x10FDD7           | minute
        lsr.l   #8, %d2
        move.b  %d2, 0x10FDD6           | heure
        lsr.l   #8, %d2
        move.b  %d2, 0x10FDD4           | jour
        moveq   #0x0F, %d0
        and.b   %d3, %d0
        move.b  %d0, 0x10FDD5           | jour de semaine
        move.b  %d3, %d0
        lsr.b   #4, %d0                 | mois en binaire, 0 à 15
        cmpi.b  #10, %d0
        bcs.s   4f
        addq.b  #6, %d0                 | 10 à 15 → $10 à $15
4:      move.b  %d0, 0x10FDD3           | mois en BCD
        lsr.w   #8, %d3
        move.b  %d3, 0x10FDD2           | année
        movem.l (%sp)+, %d0-%d4/%a0-%a1
        rts

| Une commande de quatre bits (%d1), poids faible d'abord, puis STB et l'attente de td2.
| Écarts minimaux, en cycles hors écritures : 42 dans un bit, 60 d'un bit au suivant,
| 38 de STB à 0.
.Lcommande:
        moveq   #3, %d4
1:      moveq   #1, %d0
        and.b   %d1, %d0
        bsr     .Lecrire                | D
        or.b    #2, %d0
        bsr     .Lecrire                | D|CLK
        and.b   #1, %d0
        bsr     .Lecrire                | D
        lsr.b   #1, %d1
        dbra    %d4, 1b
        moveq   #4, %d0
        bsr     .Lecrire                | STB
        moveq   #0, %d0
        bsr     .Lecrire                | 0
        moveq   #23, %d0                | 4 + 23 × 10 + 14 = 248 cycles, 20,7 µs : td2
2:      dbra    %d0, 2b
        rts

| Un bit : le bit 7 de REG_STATUS_A part dans X, puis un coup d'horloge. Rien après le
| `add.b` ne touche X (`moveq`, `move`, `bsr`, `rts`) : l'appelant le reprend par `roxr`.
| Écarts minimaux : 38 cycles de CLK à 0, 94 de 0 au CLK du bit suivant.
.Lbit:
        move.b  (%a1), %d0
        add.b   %d0, %d0                | X ← bit 7
        moveq   #2, %d0
        bsr     .Lecrire                | CLK
        moveq   #0, %d0
        bsr     .Lecrire                | 0
        rts

.Lecrire:
        move.b  %d0, (%a0)
        rts
