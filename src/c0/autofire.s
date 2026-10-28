| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| L'AUTOFIRE — réglé jeu par jeu dans le menu en jeu (`menu.s`, ligne AUTOFIRE), gardé en backup
| RAM par jeu, appliqué par SYSTEM_IO (`io.s`, `_io_commun`). Le 2026-10-27 (DECISIONS §22).
|
| AUCUN ORACLE : aucun BIOS Neo Geo connu n'a d'autofire, et aucun n'est lu. « mesuré » : un
| relevé nommé ; « lu dans » : une page du NeoGeo Development Wiki ; « SUPPOSÉ » : ni l'un ni
| l'autre.
|
| CE QUE LE JEU VOIT. Le turbo s'applique aux entrées que SYSTEM_IO range en RAM (BIOS_P1CURRENT et
| la suite, « BIOS RAM locations ») : un jeu qui lit lui-même REG_P1CNT ne le voit pas. MESURÉ le
| 2026-10-27 (prototype hors dépôt, A de P1, 164 jeux, une partie scriptée chacun ;
| `measured/2026-10-27-autofire.tsv`, liste lisible : `docs/AUTOFIRE.md`).
|
| LE RÉGLAGE, un octet : bits 4 à 7 les boutons A, B, C, D (les bits de REG_P1CNT), bits 0 et 1 la
| cadence — 0 : 10 tirs/s (6 trames : 3 appuyé, 3 relâché), 1 : 15 (2 et 2), 2 : 30 (1 et 1), à 60
| appels de SYSTEM_IO par seconde ; 3 vaut 1. Défaut, DEFAUT : aucun bouton, 15 tirs/s. P1 et P2
| suivent le même réglage, chacun sa phase (`io.s`).
|
| EN RAM, $10FB40-$10FB51, dans la zone du BIOS mesurée libre ($10F4B4-$10FBFF : aucune écriture
| de jeu, 22 jeux, `measured/2026-10-21-ecrivains-ram-bios.tsv` ; et $10FB40-$10FB41 relus
| inchangés pendant les 158 parties de la mesure de l'autofire). Vidée au boot (`c0.s`) : tables à
| zéro, entrées inchangées.
|   AF_REGLAGE  .b le réglage du jeu servi
|   AF_MASQUE   .b ses boutons (bits 4-7)
|   AF_PH1/2    .b la phase de P1, de P2 : 0 à P − 1
|   AF_REL      6 .b, par phase : les boutons vus relâchés (le masque aux phases ≥ P/2, 0 avant)
|   AF_SUIV     6 .b, par phase : la phase suivante (k + 1, 0 après P − 1), 8 octets plus loin
|
| EN BACKUP RAM, $D001B0-$D0020F, à nous. Lu dans « Backup RAM » : $D001A8-$D0021F n'y est pas
| documenté. MESURÉ (`reglages.s`, en-tête) : aucune écriture, ni du jeu ni du BIOS, dans
| $D00150-$D0021F, 21 jeux ; aucun des 22 jeux de `measured/2026-10-22-bram-lue-par-les-jeux.tsv`
| n'y lit. $D00144-$D001A3 est laissé : la référence y range des dates de slot (`c0.s`).
|   $D001B0-$D001B3  « AUTF », la signature ; absente, la table est vide
|   $D001B4-$D0020F  23 fiches de 4 octets, la plus récemment réglée d'abord : NGH (.w), réglage
|                    (.b), contrôle (.b) tel que la somme des quatre octets vaille $FF. Une fiche
|                    dont la somme n'est pas $FF est libre (une fiche à zéro l'est).
| Un jeu au réglage par défaut n'a pas de fiche. Au-delà de 23 jeux, la fiche du jeu réglé le
| moins récemment est perdue. SUPPOSÉ : qu'aucun autre BIOS passé sur la même NVRAM n'y écrive ;
| une fiche abîmée ne vaut alors que pour un jeu, et la signature remet la table à vide.
|
| LE JEU est son NGH, celui de l'entrée du slot servi dans la table des slots ($D00124 + 4 ×
| $D00108, « Backup RAM »), que la détection du boot y écrit depuis l'en-tête de la cartouche : le
| même NGH que celui des cheats ($000108), sans lire la cartouche, donc sans souci de REG_CRTFIX
| (DECISIONS §13). NGH $0000 (slot vide) : pas de fiche, le réglage par défaut.
|
| LE CHARGEMENT, `_af_charger`, à chaque remise de la main au jeu (`c0.s`, avec `_commutateurs`) :
| boot, SYSTEM_RETURN, passage de slot, pièce hors partie. Avant l'attente de la ligne $1F0 de la
| remise : ses cycles n'en changent pas l'instant.
| ==================================================================================

        .section .haut, "ax"
        .global _af_charger
        .global _af_ecran

        .equ    AF_REGLAGE, 0x10FB40
        .equ    AF_MASQUE, 0x10FB41
        .equ    AF_PH1,    0x10FB42
        .equ    AF_PH2,    0x10FB43
        .equ    AF_REL,    0x10FB44     | 6 octets
        .equ    AF_SUIV,   0x10FB4C     | 6 octets, AF_REL + 8 (`io.s`)
        .equ    DEFAUT,    0x01         | aucun bouton, 15 tirs/s
        .equ    TABLE,     0xD001B0
        .equ    FICHES,    0xD001B4
        .equ    NFICHES,   23
        .equ    SRAMUNLOCK, 0x3A001D
        .equ    SRAMLOCK,  0x3A000D
        | L'écran, sous la pile du menu, comme GAME SETTINGS (un seul sous-écran à la fois).
        .equ    AF_CHOIX,  0x10F900     | .w la ligne choisie, 0-3 les boutons, 4 la cadence
        .equ    AF_CHANGE, 0x10F902     | .w non nul : le réglage a changé
        .equ    NLIGNES,   5
        .equ    L_LISTE,   3

| ----------------------------------------------------------------------------------
| LE CHARGEMENT (voir l'en-tête). Rend tous les registres.
_af_charger:
        movem.l %d0-%d3/%a0, -(%sp)
        bsr.s   .Lngh
        bsr     .Lchercher
        moveq   #DEFAUT, %d0
        cmpa.w  #0, %a0
        beq.s   1f
        move.b  2(%a0), %d0
1:      bsr.s   .Lappliquer
        movem.l (%sp)+, %d0-%d3/%a0
        rts

| LE NGH DU JEU SERVI, dans %d1.w (0 : aucun). Clobbers %d0, %a0.
.Lngh:
        moveq   #0, %d0
        move.b  0xD00108, %d0
        andi.w  #7, %d0
        lsl.w   #2, %d0
        lea     0xD00124, %a0
        move.w  (%a0,%d0.w), %d1
        rts

| LE RÉGLAGE %d0.b EN RAM : réglage, masque, tables, phases à 0. Clobbers %d0-%d3, %a0.
.Lappliquer:
        move.b  %d0, AF_REGLAGE
        move.b  %d0, %d2
        andi.b  #0xF0, %d2              | %d2 : le masque
        move.b  %d2, AF_MASQUE
        andi.w  #3, %d0
        move.b  .Lperiodes(%pc,%d0.w), %d0  | %d0 : la période P
        lea     AF_REL, %a0
        moveq   #0, %d1                 | %d1 : la phase k
1:      moveq   #0, %d3
        move.b  %d0, %d3
        lsr.b   #1, %d3                 | P/2
        clr.b   (%a0)
        cmp.b   %d3, %d1
        bcs.s   2f
        cmp.b   %d0, %d1
        bcc.s   2f
        move.b  %d2, (%a0)              | P/2 ≤ k < P : relâchés
2:      move.b  %d1, %d3
        addq.b  #1, %d3
        cmp.b   %d0, %d3
        bcs.s   3f
        moveq   #0, %d3                 | après P − 1, ou hors de la période : 0
3:      move.b  %d3, AF_SUIV-AF_REL(%a0)
        addq.l  #1, %a0
        addq.b  #1, %d1
        cmpi.b  #6, %d1
        bcs.s   1b
        clr.w   AF_PH1                  | AF_PH1 et AF_PH2
        rts
.Lperiodes: .byte 6, 4, 2, 4             | 10, 15, 30 tirs/s ; 3 vaut 15

| LA FICHE DU NGH %d1.w dans %a0, 0 si aucune (table sans signature, NGH nul, ou absente).
| Clobbers %d0, %d2, %a0.
.Lchercher:
        tst.w   %d1
        beq.s   8f
        cmpi.l  #0x41555446, TABLE      | « AUTF »
        bne.s   8f
        lea     FICHES, %a0
        moveq   #NFICHES - 1, %d2
1:      cmp.w   (%a0), %d1
        bne.s   2f
        bsr.s   .Lsomme
        cmpi.b  #0xFF, %d0
        beq.s   9f
2:      addq.l  #4, %a0
        dbra    %d2, 1b
8:      suba.l  %a0, %a0
9:      rts

| La somme des quatre octets de la fiche %a0, dans %d0.b. Clobbers %d0.
.Lsomme:
        move.b  (%a0), %d0
        add.b   1(%a0), %d0
        add.b   2(%a0), %d0
        add.b   3(%a0), %d0
        rts

| L'ENREGISTREMENT du réglage %d0.b pour le NGH %d1.w (non nul) : sa fiche ôtée, puis, s'il n'est
| pas le défaut, une fiche neuve en tête. La backup RAM est déverrouillée le temps de l'écriture
| (verrouillée à l'appel : `io.s` la referme avant le crochet du menu). Clobbers %d0-%d3, %a0, %a1.
.Lenregistrer:
        move.b  %d0, %d3                | %d3 : le réglage
        move.b  %d0, SRAMUNLOCK
        cmpi.l  #0x41555446, TABLE
        beq.s   1f
        move.l  #0x41555446, TABLE      | table neuve : signature, fiches libres
        lea     FICHES, %a0
        moveq   #NFICHES - 1, %d2
2:      clr.l   (%a0)+
        dbra    %d2, 2b
1:      bsr.s   .Lchercher
        cmpa.w  #0, %a0
        beq.s   3f
        | Ôtée : les fiches suivantes remontent d'une place, la dernière est libérée.
        lea     FICHES + 4 * NFICHES, %a1
4:      lea     4(%a0), %a0
        cmpa.l  %a1, %a0
        bcc.s   5f
        move.l  (%a0), -4(%a0)
        bra.s   4b
5:      clr.l   -4(%a1)
3:      cmpi.b  #DEFAUT, %d3
        beq.s   9f
        | En tête : les 22 premières descendent d'une place, la 23e est perdue.
        lea     FICHES + 4 * NFICHES, %a0
        lea     FICHES + 4 * (NFICHES - 1), %a1
        moveq   #NFICHES - 2, %d2
6:      move.l  -(%a1), -(%a0)
        dbra    %d2, 6b
        lea     FICHES, %a0
        move.w  %d1, (%a0)
        move.b  %d3, 2(%a0)
        moveq   #-1, %d0                | le contrôle : $FF − (NGH haut + NGH bas + réglage)
        sub.b   (%a0), %d0
        sub.b   1(%a0), %d0
        sub.b   %d3, %d0
        move.b  %d0, 3(%a0)
9:      move.b  %d0, SRAMLOCK
        rts

| ----------------------------------------------------------------------------------
| L'ÉCRAN AUTOFIRE, un sous-écran du menu en jeu, appelé par `menu.s` (qui le ferme). Le cadre
| des sous-écrans (28 × 14, `menu.s`), la police de la cartouche :
|   1  AUTOFIRE (titre)
|   3-6  BUTTON A … BUTTON D, OFF ou ON (colonne 15)
|   7  RATE, 10/S, 15/S ou 30/S
|   12 P1+P2, SAVED FOR THIS GAME
|   13 L/R/A:CHANGE START:BACK
| LES COMMANDES, P1 sur front, comme GAME SETTINGS : haut/bas la ligne, en boucle ; droite ON ou
| la cadence au-dessus, gauche OFF ou la cadence au-dessous, bornées ; A bascule, ou la cadence
| suivante en boucle. Chaque changement vaut à l'instant (RAM) ; START l'enregistre s'il y en a eu
| un, et rend la main au menu.
_af_ecran:
        bsr     _mn_sous_ouvrir
        clr.l   AF_CHOIX                | AF_CHOIX et AF_CHANGE
        bsr     .Ltout
.Lboucle:
        bsr     _mn_sync
        bsr     _mn_entrees
        btst    #8, %d0
        bne.s   .Lsortie
        move.w  AF_CHOIX, %d1
        btst    #0, %d0                 | haut
        beq.s   2f
        subq.w  #1, %d1
        bpl.s   1f
        moveq   #NLIGNES - 1, %d1
1:      move.w  %d1, AF_CHOIX
        bsr     .Ltout
        bra.s   .Lboucle
2:      btst    #1, %d0                 | bas
        beq.s   2f
        addq.w  #1, %d1
        cmpi.w  #NLIGNES, %d1
        bcs.s   1b
        moveq   #0, %d1
        bra.s   1b
2:      moveq   #1, %d2                 | droite
        btst    #3, %d0
        bne.s   3f
        moveq   #-1, %d2                | gauche
        btst    #2, %d0
        bne.s   3f
        moveq   #2, %d2                 | A
        btst    #4, %d0
        beq.s   .Lboucle
3:      bsr.s   .Lchanger
        bra.s   .Lboucle

.Lsortie:
        tst.w   AF_CHANGE
        beq.s   9f
        bsr     .Lngh
        tst.w   %d1
        beq.s   9f                      | aucun jeu : rien d'enregistré
        moveq   #0, %d0
        move.b  AF_REGLAGE, %d0
        bsr     .Lenregistrer
9:      rts

| LA LIGNE CHOISIE CHANGÉE, %d2 le sens (1 droite, −1 gauche, 2 A). Clobbers %d0-%d4, %d6, %a0-%a3.
.Lchanger:
        move.b  AF_REGLAGE, %d0
        move.w  AF_CHOIX, %d1
        cmpi.w  #4, %d1
        beq.s   5f
        addq.w  #4, %d1                 | le bit du bouton
        cmpi.w  #2, %d2
        bne.s   1f
        bchg    %d1, %d0                | A : bascule
        bra.s   8f
1:      tst.w   %d2
        bmi.s   2f
        bset    %d1, %d0                | droite : ON
        bra.s   8f
2:      bclr    %d1, %d0                | gauche : OFF
        bra.s   8f
5:      move.b  %d0, %d1                | la cadence, 0 à 2 (3 vaut 1)
        andi.b  #3, %d1
        cmpi.b  #3, %d1
        bne.s   1f
        moveq   #1, %d1
1:      cmpi.w  #2, %d2
        bne.s   2f
        addq.b  #1, %d1                 | A : la suivante, en boucle
        cmpi.b  #3, %d1
        bcs.s   4f
        moveq   #0, %d1
        bra.s   4f
2:      add.b   %d2, %d1                | droite, gauche : bornée à 0-2
        bpl.s   3f
        moveq   #0, %d1
3:      cmpi.b  #2, %d1
        bls.s   4f
        moveq   #2, %d1
4:      andi.b  #0xF0, %d0
        or.b    %d1, %d0
8:      cmp.b   AF_REGLAGE, %d0
        beq.s   9f
        bsr     .Lappliquer
        move.w  #1, AF_CHANGE
        bra.s   .Ltout
9:      rts

| ----------------------------------------------------------------------------------
| TOUT L'ÉCRAN : les 14 lignes du cadre. Clobbers %d0-%d4, %d6, %a0-%a3.
.Ltout:
        moveq   #0, %d4
.Lt_ligne:
        bsr     _mn_vider
        cmpi.w  #1, %d4
        bne.s   1f
        lea     .Ltxt_titre, %a3
        moveq   #L_TITRE, %d4
        moveq   #(28 - L_TITRE) / 2, %d0
        moveq   #1, %d1                 | le titre
        bsr     _mn_texte
        moveq   #1, %d4
        bra.s   .Lt_ecrire
1:      cmpi.w  #12, %d4
        bne.s   1f
        lea     .Ltxt_aide1, %a3
        moveq   #L_AIDE1, %d4
        moveq   #1, %d0
        moveq   #0, %d1
        bsr     _mn_texte
        moveq   #12, %d4
        bra.s   .Lt_ecrire
1:      cmpi.w  #13, %d4
        bne.s   1f
        lea     .Ltxt_aide2, %a3
        moveq   #L_AIDE2, %d4
        moveq   #2, %d0
        moveq   #0, %d1
        bsr     _mn_texte
        moveq   #13, %d4
        bra.s   .Lt_ecrire
1:      move.w  %d4, %d0
        subq.w  #L_LISTE, %d0
        bcs.s   .Lt_ecrire
        cmpi.w  #NLIGNES, %d0
        bcc.s   .Lt_ecrire
        move.w  %d4, -(%sp)
        bsr.s   .Lentree
        move.w  (%sp)+, %d4
.Lt_ecrire:
        bsr     _mn_ligne
        addq.w  #1, %d4
        cmpi.w  #14, %d4
        bcs     .Lt_ligne
        rts

| LA LIGNE %d0 de la liste dans MN_BUF : « > » et la palette du choix si elle est choisie,
| l'intitulé (colonne 2), la valeur (colonne 15). Clobbers %d0-%d2, %a0-%a3.
.Lentree:
        cmp.w   AF_CHOIX, %d0
        bne.s   2f
        move.b  #0x3E, MN_BUF + 1       | « > »
        lea     MN_COUL, %a0
        moveq   #28 - 1, %d1
1:      move.b  #2, (%a0)+
        dbra    %d1, 1b
2:      lea     MN_BUF + 2, %a1
        lea     MN_BUF + 15, %a2
        move.b  AF_REGLAGE, %d2
        cmpi.w  #4, %d0
        beq.s   5f
        lea     .Ltxt_bouton, %a3       | « BUTTON » et la lettre
        moveq   #7 - 1, %d1
3:      move.b  (%a3)+, (%a1)+
        dbra    %d1, 3b
        moveq   #0x41, %d1              | A, B, C, D
        add.b   %d0, %d1
        move.b  %d1, (%a1)
        lea     .Ltxt_off, %a3
        addq.w  #4, %d0
        btst    %d0, %d2
        beq.s   4f
        lea     .Ltxt_on, %a3
        bra.s   4f
5:      lea     .Ltxt_cadence, %a3
        moveq   #4 - 1, %d1
3:      move.b  (%a3)+, (%a1)+
        dbra    %d1, 3b
        andi.w  #3, %d2
        cmpi.w  #3, %d2
        bne.s   6f
        moveq   #1, %d2
6:      lea     .Ltxt_cadences, %a3
        lsl.w   #2, %d2
        adda.w  %d2, %a3
4:      move.b  (%a3)+, (%a2)+          | trois ou quatre caractères, l'espace compris
        move.b  (%a3)+, (%a2)+
        move.b  (%a3)+, (%a2)+
        move.b  (%a3)+, (%a2)+
        rts

| ----------------------------------------------------------------------------------
| LES DONNÉES.
        .balign 2
.Ltxt_titre:
        .ascii  "AUTOFIRE"
        .equ    L_TITRE, . - .Ltxt_titre
.Ltxt_bouton:
        .ascii  "BUTTON "
.Ltxt_cadence:
        .ascii  "RATE"
.Ltxt_on:
        .ascii  "ON  "
.Ltxt_off:
        .ascii  "OFF "
.Ltxt_cadences:                         | dans l'ordre des codes : 0, 1, 2
        .ascii  "10/S15/S30/S"
.Ltxt_aide1:
        .ascii  "P1+P2, SAVED FOR THIS GAME"
        .equ    L_AIDE1, . - .Ltxt_aide1
.Ltxt_aide2:
        .ascii  "L/R/A:CHANGE START:BACK"
        .equ    L_AIDE2, . - .Ltxt_aide2
        .balign 2
