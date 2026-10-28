| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| LES AUTOTESTS — un sous-menu de l'écran TEST (`dip.s`), ligne « HARDWARE TESTS ».
|
| Appelé par `jsr _autotests` depuis l'éditeur de soft-DIP, IRQ masquées (SR = $2700
| depuis `_demarrage`), backup RAM déverrouillée, plan fixe sur la police de la carte
| (REG_BRDFIX, posé par `dip.s`). Sortie : tous les registres rendus, palettes 0-15 de la
| banque 0 à zéro hors de la référence, banque 0 choisie ; l'appelant redessine son écran.
|
| AUCUN ORACLE : ni les tests du BIOS de référence ni ceux d'un BIOS tiers ne sont lus.
| La remise est « Couche 3 → les autotests, le 2026-10-21 » (`docs/RELECTURE-CONTRATS.md`).
| « mesuré » : un relevé nommé ; « lu dans » : une page du NeoGeo Development Wiki ;
| « SUPPOSÉ » : ni l'un ni l'autre.
|
| LES QUATRE TESTS DE MÉMOIRE, mêmes motifs partout : quatre motifs de données ($0000,
| $FFFF, $5555, $AAAA : chaque bit à 0 et à 1, bits voisins opposés), chacun écrit sur
| toute la zone puis relu ; puis deux motifs d'adresse : chaque mot reçoit une valeur tirée
| de son adresse, puis son complément, toute la zone écrite avant toute relecture — une
| ligne d'adresse collée ou court-circuitée fait que deux mots se recouvrent, et le
| premier relu porte la valeur de l'autre. Résultat : OK, ou le premier mot fautif, la
| valeur écrite et la valeur lue. Accès par mots, à des adresses paires seulement.
|   WORK RAM    $100000-$10FFFF, en deux temps (voir `.Lt_ram`).
|   PALETTE RAM $400000-$401FFF, les deux banques, par tranches dans le blanking.
|   VRAM        par REG_VRAMADDR / REG_VRAMRW / REG_VRAMMOD : $0000-$85FF et $8700-$87FF.
|   BACKUP RAM  $D00000-$D0FFFF, NON destructif : complément mot par mot.
| Puis INPUT TEST, COLOR BARS et CROSSHATCH, et CARTRIDGE CRC (`crc.s`, le 2026-10-25), juste
| avant EXIT : depuis WORK RAM, « bas » quatre et cinq fois mènent toujours à INPUT TEST et COLOR
| BARS ; CROSSHATCH est à « haut » trois fois, CARTRIDGE CRC à deux, EXIT à une.
|
| L'AFFICHAGE, comme `dip.s` : plan fixe seul, $7000 + 32 × colonne + ligne, REG_VRAMMOD à
| 32 pour écrire une ligne ; police 8×8 = tuile ASCII, 8×16 = $100/$200 + ASCII ;
| couleur du trait dans l'entrée 1, entrées 2-15 noires (`measured/2026-10-20-sfix-glyphes.tsv`).
| Palettes : 1 le texte, 2 la ligne choisie, 3 le titre, 4 l'aide, 5 OK / appuyé, 6 FAIL.
| ==================================================================================

        .section .haut, "ax"
        .global _autotests

        .equ    VRAMADDR, 0x3C0000
        .equ    VRAMRW,   0x3C0002
        .equ    VRAMMOD,  0x3C0004
        .equ    LSPCMODE, 0x3C0006
        .equ    P1CNT,    0x300000
        .equ    WATCHDOG, 0x300001      | en écriture
        .equ    DIPSW,    0x300001      | en lecture
        .equ    SYSTYPE,  0x300081
        .equ    STATUS_A, 0x320001
        .equ    P2CNT,    0x340000
        .equ    STATUS_B, 0x380000
        .equ    SRAMUNLOCK, 0x3A001D
        .equ    PALBANK0, 0x3A000F
        .equ    PALBANK1, 0x3A001F
        .equ    PALETTES, 0x400000
        .equ    FOND,     0x401FFE

        | La RAM de travail (« Memory map » : $100000-$10FFFF), en deux zones.
        .equ    RAM_BAS,  0x100000
        .equ    RAM_H,    0x10F000      | la zone haute, gardée par copie
        .equ    RAM_FIN,  0x110000
        .equ    COPIE,    0x100000      | où la zone haute est mise de côté, déjà testée
        .equ    TRANCHE,  4096          | octets entre deux coups de pied au watchdog

        | Les résultats, dans le cadre : 4 tests × R_TAILLE. +0 état (0 pas lancé, 1 OK,
        | 2 FAIL, 3 en cours), +1 banque, +2 adresse, +6 écrit, +8 lu.
        .equ    R_TAILLE, 12
        .equ    N_MEM,    4             | les tests de mémoire
        .equ    F_RES,    -(N_MEM * R_TAILLE)

        | La mise en page : la ligne du menu, colonne 3.
        .equ    CASE_TITRE, 0x7000 + 13 * 32 + 3       | 8×16, lignes 3-4
        .equ    CASE_MENU,  0x7000 + 3 * 32            | + la ligne
        .equ    CASE_AIDE1, 0x7000 + 3 * 32 + 26
        .equ    CASE_AIDE2, 0x7000 + 3 * 32 + 27
        .equ    N_LIGNES,   9

| ----------------------------------------------------------------------------------
_autotests:
        movem.l %d0-%d7/%a0-%a6, -(%sp)
        link    %a6, #F_RES
        lea     F_RES(%a6), %a0
        moveq   #(N_MEM * R_TAILLE / 4) - 1, %d0
1:      clr.l   (%a0)+
        dbra    %d0, 1b
        moveq   #0, %d7                 | %d7 : la ligne choisie
        bsr     .Lmenu
        moveq   #0, %d5                 | un bouton déjà tenu (le A qui ouvre) ne compte pas
        bsr     .Lentrees

| LA BOUCLE DU MENU, une trame par tour. %d5 : les boutons de la trame d'avant.
.Lboucle:
        bsr     .Lsync
        bsr     .Lentrees
        btst    #5, %d0                 | START : retour à l'écran TEST
        bne     .Lsortie
        btst    #0, %d0                 | haut
        beq.s   2f
        move.w  %d7, %d0
        subq.w  #1, %d7
        bpl.s   1f
        moveq   #N_LIGNES - 1, %d7
1:      bsr     .Lligne                 | l'ancienne, puis la nouvelle
        move.w  %d7, %d0
        bsr     .Lligne
        bra.s   .Lboucle
2:      btst    #1, %d0                 | bas
        beq.s   3f
        move.w  %d7, %d0
        addq.w  #1, %d7
        cmpi.w  #N_LIGNES, %d7
        bcs.s   1b
        moveq   #0, %d7
        bra.s   1b
3:      andi.b  #0x18, %d0              | A ou droite : lancer
        beq.s   .Lboucle

| LANCER LA LIGNE %d7.
        cmpi.w  #N_LIGNES - 1, %d7      | EXIT
        beq     .Lsortie
        cmpi.w  #4, %d7
        bcc.s   .Lmire
        lea     F_RES(%a6), %a3         | un test de mémoire : « TESTING » d'abord
        move.w  %d7, %d0
        mulu    #R_TAILLE, %d0
        move.b  #3, (%a3,%d0.w)
        move.w  %d7, %d0
        bsr     .Lligne
        move.w  %d7, %d0
        lsl.w   #2, %d0
        lea     .Ltests, %a0
        movea.l (%a0,%d0.w), %a0
        movem.l %d5/%d7/%a6, -(%sp)
        jsr     (%a0)                   | sortie : %d0 0 ou 1, %a2, %d1, %d2, %d3
        movem.l (%sp)+, %d5/%d7/%a6
        lea     F_RES(%a6), %a3
        move.w  %d7, %d4
        mulu    #R_TAILLE, %d4
        adda.w  %d4, %a3
        move.b  #1, (%a3)
        tst.l   %d0
        beq.s   1f
        move.b  #2, (%a3)
1:      move.b  %d3, 1(%a3)
        move.l  %a2, 2(%a3)
        move.w  %d1, 6(%a3)
        move.w  %d2, 8(%a3)
        cmpi.w  #1, %d7
        bne.s   1f
        bsr     .Lp_nettoyer
1:      cmpi.w  #2, %d7
        bne.s   .Lapres
        bsr     .Lv_remettre
        bra.s   .Lapres
.Lmire:
        move.w  %d7, %d0
        lsl.w   #2, %d0
        lea     .Ltests, %a0
        movea.l (%a0,%d0.w), %a0
        movem.l %d5/%d7/%a6, -(%sp)
        jsr     (%a0)
        movem.l (%sp)+, %d5/%d7/%a6
.Lapres:
        bsr     .Lmenu
        bsr     .Lentrees               | un bouton encore tenu ne compte pas
        bra     .Lboucle

.Lsortie:
        bsr     .Lsync
        bsr     .Lpal_zero
        unlk    %a6
        movem.l (%sp)+, %d0-%d7/%a0-%a6
        rts

| ----------------------------------------------------------------------------------
| WORK RAM. Ce que le BIOS occupe pendant ce test, lu dans le code : la pile (posée à
| $10F300 par `_demarrage`, elle descend), et les variables du BIOS de $10F300-$10FFFF
| encore lues après l'éditeur — BIOS_COUNTRY_CODE, BIOS_GAME_DIP (que l'éditeur tient
| dans sa table), BIOS_MESS_POINT, le drapeau de `plantage.s` — sans compter le cadre de
| `dip.s`, dans la pile. La profondeur de la pile ici, comptée dans le code : 4 (jsr de
| `c0.s`) + 60 (movem de `dip.s`) + 4 + 386 (son cadre, `link #F_LIEN` : 22 × 12 de table, 32
| de tampon, 4, 1, 1, 4, 4, huit octets d'états, 2, 2, 5 × 12 du sous-écran CABINET SETTINGS, et 4
| de la liste en 8×16) + 8
| (bsr, jsr) + 60 (movem ici) + 4 + 48 (ce cadre) + 16 (movem et jsr du lancement) + 12 (trois
| appels au plus ; le test n'appelle pas `.Lsync`) = 602 octets, donc rien sous $10F0A6 : la zone basse
| $100000-$10EFFF est libre et se teste sans précaution. La zone haute $10F000-$10FFFF (4 Kio) est d'abord copiée dans la zone basse
| tout juste testée, la pile y est déplacée du même écart, la zone haute est testée, puis
| recopiée. Rien d'autre n'écrit dans la RAM de travail : IRQ masquées, aucun appel au jeu.
| Enfin la zone basse hors de la copie est relue : son dernier motif d'adresse doit y être
| intact, sinon une écriture en zone haute l'a touchée (lignes A12-A15). Le sens bas → haut
| n'est pas pris : une de ces lignes collée à 1 envoie les écritures de $10E0F8-$10E2FF sur
| la pile réelle avant son déplacement, et la machine plante ou repart au lieu d'un FAIL.
| Sortie : %d0 0 ou 1, %a2 l'adresse, %d1 écrit, %d2 lu, %d3 = 0.
.Lt_ram:
        lea     RAM_BAS, %a4
        lea     RAM_H, %a5
        bsr     .Lm_complet
        tst.l   %d0
        bne.s   9f
        lea     RAM_H, %a0
        lea     COPIE, %a1
        move.w  #(0x1000 / 4) - 1, %d3
1:      move.l  (%a0)+, (%a1)+
        dbra    %d3, 1b
        suba.l  #RAM_H - COPIE, %sp     | la pile dans la copie : son contenu y est
        lea     RAM_H, %a4
        lea     RAM_FIN, %a5
        bsr     .Lm_complet             | %d0-%d2, %a2 : le résultat, gardé ci-dessous
        lea     COPIE, %a0
        lea     RAM_H, %a1
        move.w  #(0x1000 / 4) - 1, %d3
1:      move.l  (%a0)+, (%a1)+
        dbra    %d3, 1b
        adda.l  #RAM_H - COPIE, %sp
        tst.l   %d0
        bne.s   9f
        lea     COPIE + 0x1000, %a4
        lea     RAM_H, %a5
        moveq   #-1, %d1                | le dernier motif : l'adresse complémentée
        moveq   #1, %d6
        bsr     .Lm_relire_tout
9:      moveq   #0, %d3
        rts

| UN TEST COMPLET sur [%a4, %a5) : les six motifs. Clobbers %d0-%d2, %d4, %d6, %a0-%a3.
.Lm_complet:
        lea     .Lmotifs, %a3
        moveq   #6 - 1, %d4
1:      move.w  (%a3)+, %d1
        move.w  (%a3)+, %d6
        bsr.s   .Lm_ecrire_tout
        bsr.s   .Lm_relire_tout
        tst.l   %d0
        bne.s   9f
        dbra    %d4, 1b
9:      rts

| TOUTE LA ZONE [%a4, %a5), par tranches de TRANCHE octets, un coup de pied au watchdog
| entre deux (au pire la relecture du motif d'adresse : ≈ 54 cycles par mot, ≈ 110 000
| par tranche, ≈ 1/29 des 3 244 030 cycles du watchdog que cite `c0.s`). %d1, %d6 : voir `.Lm_remplir`.
.Lm_ecrire_tout:
        movea.l %a4, %a0
1:      lea     TRANCHE(%a0), %a1
        cmpa.l  %a5, %a1
        bls.s   2f
        movea.l %a5, %a1
2:      bsr.s   .Lm_remplir
        move.b  %d0, WATCHDOG
        movea.l %a1, %a0
        cmpa.l  %a5, %a0
        bcs.s   1b
        rts
.Lm_relire_tout:
        movea.l %a4, %a0
1:      lea     TRANCHE(%a0), %a1
        cmpa.l  %a5, %a1
        bls.s   2f
        movea.l %a5, %a1
2:      bsr.s   .Lm_verif
        bne.s   9f
        move.b  %d0, WATCHDOG
        movea.l %a1, %a0
        cmpa.l  %a5, %a0
        bcs.s   1b
        moveq   #0, %d0
9:      rts

| ÉCRIRE [%a0, %a1). %d6 = 0 : la donnée %d1 partout ; sinon le motif d'adresse, le mot à
| l'adresse a recevant (a >> 1) xor %d1 — 15 bits d'index de mot sur 64 Kio, donc une
| valeur par mot de la zone. Clobbers %d0, %a2.
.Lm_remplir:
        movea.l %a0, %a2
        tst.w   %d6
        bne.s   2f
1:      move.w  %d1, (%a2)+
        cmpa.l  %a1, %a2
        bcs.s   1b
        rts
2:      move.l  %a2, %d0
        lsr.l   #1, %d0
        eor.w   %d1, %d0
        move.w  %d0, (%a2)+
        cmpa.l  %a1, %a2
        bcs.s   2b
        rts

| RELIRE [%a0, %a1), mêmes valeurs. Sortie : %d0 = 0 et Z, ou %d0 = 1 avec %a2 le mot
| fautif, %d1 l'écrit, %d2 le lu. Clobbers %d0, %d2, %a2 (et %d1 sur faute d'adresse).
.Lm_verif:
        movea.l %a0, %a2
        tst.w   %d6
        bne.s   2f
1:      move.w  (%a2)+, %d2
        cmp.w   %d1, %d2
        bne.s   .Lm_faute
        cmpa.l  %a1, %a2
        bcs.s   1b
        moveq   #0, %d0
        rts
2:      move.l  %a2, %d0
        lsr.l   #1, %d0
        eor.w   %d1, %d0
        move.w  (%a2)+, %d2
        cmp.w   %d0, %d2
        bne.s   3f
        cmpa.l  %a1, %a2
        bcs.s   2b
        moveq   #0, %d0
        rts
3:      move.w  %d0, %d1
.Lm_faute:
        subq.l  #2, %a2
        moveq   #1, %d0
        rts

| ----------------------------------------------------------------------------------
| PALETTE RAM. Lu dans « Palettes » : $400000-$401FFF, deux banques choisies par
| REG_PALBANK0/1, et écrire pendant l'affichage fait de la neige. Toute la zone est donc
| touchée par tranches juste après le passage de la ligne $1F0 : 40 lignes de blanking
| SUPPOSÉ (le compteur de ligne passe de $1F0 à $1FF puis de $F8 à $10F avant
| l'affichage), ≈ 30 000 cycles. Les tranches, comptées d'après les durées d'instruction du
| 68000 (SUPPOSÉ : sans état d'attente sur la RAM de palettes) : 64 mots pour les quatre
| motifs de données plus l'écriture de l'adresse (≈ 18 000 cycles), 128 pour relire
| l'adresse et écrire son complément (≈ 12 000), 256 pour relire le complément (≈ 14 000).
| Le banc ne verrait pas la neige (MAME ne la rend pas) : le découpage n'y est pas jugé.
| La banque 0 d'abord, la 1 ensuite ; l'écran du menu clignote pendant ce temps, ses
| palettes étant sous le test. Sortie comme `.Lt_ram`, %d3 la banque fautive.
.Lt_pal:
        moveq   #0, %d3
.Lp_banque:
        bsr     .Lsync
        move.b  %d0, PALBANK0
        tst.w   %d3
        beq.s   1f
        move.b  %d0, PALBANK1
1:      lea     PALETTES, %a4
.Lp_a:  bsr     .Lsync                  | données, puis l'adresse : 64 mots par trame
        movea.l %a4, %a0
        lea     128(%a4), %a1
        lea     .Lmotifs, %a3
        moveq   #4 - 1, %d4
1:      move.w  (%a3)+, %d1
        move.w  (%a3)+, %d6
        bsr     .Lm_remplir
        bsr     .Lm_verif
        bne.s   9f
        dbra    %d4, 1b
        moveq   #0, %d1
        moveq   #1, %d6
        bsr     .Lm_remplir
        movea.l %a1, %a4
        cmpa.l  #PALETTES + 0x2000, %a4
        bcs.s   .Lp_a
        lea     PALETTES, %a4
.Lp_b:  bsr     .Lsync                  | l'adresse relue, son complément écrit
        movea.l %a4, %a0
        lea     256(%a4), %a1
        moveq   #0, %d1
        moveq   #1, %d6
        bsr     .Lm_verif
        bne.s   9f
        moveq   #-1, %d1
        bsr     .Lm_remplir
        movea.l %a1, %a4
        cmpa.l  #PALETTES + 0x2000, %a4
        bcs.s   .Lp_b
        lea     PALETTES, %a4
.Lp_c:  bsr     .Lsync                  | le complément relu
        movea.l %a4, %a0
        lea     512(%a4), %a1
        moveq   #-1, %d1
        moveq   #1, %d6
        bsr     .Lm_verif
        bne.s   9f
        movea.l %a1, %a4
        cmpa.l  #PALETTES + 0x2000, %a4
        bcs.s   .Lp_c
        addq.w  #1, %d3
        cmpi.w  #2, %d3
        bcs     .Lp_banque
        moveq   #0, %d3
        moveq   #0, %d0
9:      rts

| LES DEUX BANQUES REMISES À ZÉRO, par tranches de 1 Kio dans le blanking, la référence
| $400000 à $8000 dans chacune (« Palettes » : « always has to be pure black ($8000) » ;
| SUPPOSÉ pour la banque 1, la page ne distingue pas). La banque 0 reste choisie ; le menu
| repose ses couleurs ensuite. Clobbers %d0, %d1, %d3, %a0.
.Lp_nettoyer:
        moveq   #1, %d3
1:      bsr     .Lsync
        move.b  %d0, PALBANK0
        tst.w   %d3
        beq.s   2f
        move.b  %d0, PALBANK1
2:      lea     PALETTES, %a0
3:      bsr     .Lsync
        move.w  #256 - 1, %d1
4:      clr.l   (%a0)+
        dbra    %d1, 4b
        cmpa.l  #PALETTES + 0x2000, %a0
        bcs.s   3b
        bsr     .Lsync
        move.w  #0x8000, PALETTES
        dbra    %d3, 1b
        rts

| ----------------------------------------------------------------------------------
| VRAM. Lu dans « VRAM » : zone basse $0000-$7FFF (SCB1, carte du plan fixe à $7000,
| extension $7500-$7FFF), zone haute $8000-$87FF (SCB2-4 jusqu'à $85FF, listes de sprites
| des lignes paires et impaires $8600-$86FF, $8700-$87FF libre) ; passer d'une zone à
| l'autre en reposant REG_VRAMADDR. Les listes $8600-$86FF ne sont PAS testées : la page
| les donne au LSPC, qui les réécrit pendant l'affichage et ferait mentir la relecture
| (SUPPOSÉ quant au moment). Restent 32 768 + 1 536 + 256 mots.
| LE RYTHME, lu dans la même page (Access timing) : 12 cycles entre deux données, 16 entre
| une donnée et l'adresse suivante, 16 entre une adresse et la lecture de sa donnée. La
| lecture se fait ici en reposant l'adresse à chaque mot (la page ne dit pas qu'une lecture
| fait avancer l'adresse), puis trois `nop` (12) avant le `move.w` dont l'accès de donnée
| vient après ses mots d'extension : plus de 16, compté (SUPPOSÉ sans état d'attente).
| L'écran montre le motif pendant le test et se redessine après.
| Sortie comme `.Lt_ram`, %a2 l'adresse VRAM (mot).
.Lt_vram:
        move.w  #1, VRAMMOD
        lea     .Lmotifs, %a3
        moveq   #6 - 1, %d7
1:      move.w  (%a3)+, %d1
        move.w  (%a3)+, %d6
        bsr.s   .Lv_passe
        tst.l   %d0
        bne.s   9f
        dbra    %d7, 1b
9:      moveq   #0, %d3
        rts

| UNE PASSE : les trois zones écrites, puis relues. Clobbers %d0, %d2-%d5, %a1, %a2, %a4.
.Lv_passe:
        lea     .Lzones, %a4
        moveq   #3 - 1, %d5
1:      move.w  (%a4)+, %d3
        move.w  (%a4)+, %d4
        bsr.s   .Lv_pas
        bsr.s   .Lv_remplir
        dbra    %d5, 1b
        lea     .Lzones, %a4
        moveq   #3 - 1, %d5
2:      move.w  (%a4)+, %d3
        move.w  (%a4)+, %d4
        bsr.s   .Lv_pas
        bsr.s   .Lv_verif
        bne.s   9f
        dbra    %d5, 2b
        moveq   #0, %d0
9:      rts

| LA PREMIÈRE VALEUR %d2 et LE PAS %a1 d'une zone qui part de %d3. Données (%d6 = 0) :
| %d1 partout. Adresse : (adresse xor %d1), qui avance de +1 pour %d1 = 0 et de -1 pour
| %d1 = $FFFF.
.Lv_pas:
        move.w  %d1, %d2
        suba.l  %a1, %a1
        tst.w   %d6
        beq.s   1f
        eor.w   %d3, %d2
        addq.w  #1, %a1
        tst.w   %d1
        beq.s   1f
        subq.w  #2, %a1
1:      rts

| ÉCRIRE %d4 mots depuis l'adresse VRAM %d3, REG_VRAMMOD à 1. Entre deux données : 16
| (l'écriture) + 4 + 16 + 10 cycles. Clobbers %d2, %d4.
.Lv_remplir:
        move.w  %d3, VRAMADDR
        subq.w  #1, %d4
1:      move.w  %d2, VRAMRW
        add.w   %a1, %d2
        move.b  %d0, WATCHDOG
        dbra    %d4, 1b
        rts

| RELIRE %d4 mots depuis %d3. Faute : %d0 = 1, %a2 l'adresse, %d1 écrit, %d2 lu.
.Lv_verif:
        subq.w  #1, %d4
1:      move.w  %d3, VRAMADDR
        nop
        nop
        nop
        move.w  VRAMRW, %d0
        cmp.w   %d2, %d0
        bne.s   2f
        addq.w  #1, %d3
        add.w   %a1, %d2
        move.b  %d0, WATCHDOG
        dbra    %d4, 1b
        moveq   #0, %d0
        rts
2:      move.w  %d2, %d1
        move.w  %d0, %d2
        moveq   #0, %d0
        move.w  %d3, %d0
        movea.l %d0, %a2
        moveq   #1, %d0
        rts

| LA VRAM REMISE EN ÉTAT : zone basse et $8700-$87FF à zéro (SUPPOSÉ : rien n'y attend
| autre chose — à la mise sous tension elle est quelconque, et `ecran.s` n'y pose que
| LSP_1st et FIX_CLEAR), puis LSP_1st (`video.s`) pour SCB1 du sprite 0 et SCB2-4, comme
| l'écran de boot ; le menu repose FIX_CLEAR. $8600-$86FF n'a pas été touché.
.Lv_remettre:
        move.w  #1, VRAMMOD
        move.w  #0x0000, VRAMADDR
        moveq   #0, %d0
        move.w  #0x8000 - 1, %d1
1:      move.w  %d0, VRAMRW
        move.b  %d0, WATCHDOG
        dbra    %d1, 1b
        nop
        move.w  #0x8700, VRAMADDR
        move.w  #0x100 - 1, %d1
2:      move.w  %d0, VRAMRW
        move.b  %d0, WATCHDOG
        dbra    %d1, 2b
        jsr     _lsp_1st
        rts

| ----------------------------------------------------------------------------------
| BACKUP RAM, NON DESTRUCTIF. Lu dans « Memory map » / « Backup RAM » : $D00000-$D0FFFF, les
| données des jeux, et nos réglages ($D00210, `reglages.s`). Pour chaque mot : le lire,
| écrire son complément, le relire, remettre l'original aussitôt, puis vérifier qu'il est
| revenu. Le complément teste chaque bit dans l'état opposé au sien ; ni motif d'adresse ni
| motif fixe, qui écraseraient la zone.
| POURQUOI C'EST SÛR : IRQ masquées (SR = $2700) et aucune autre écriture, donc à tout
| instant au plus UN mot diffère de l'original, le temps de deux instructions (sa relecture,
| puis sa remise). Une coupure à ce moment-là laisse ce seul mot complémenté : sur la
| signature de `c0.s` ou le bloc de `reglages.s`, leur contrôle le refuse ; ailleurs, le jeu
| le relira tel quel. Un mot fautif est restauré avant d'être rapporté.
| LE VERROU : lu dans « Memory mapped registers », REG_SRAMUNLOCK ($3A001D) ouvre l'écriture.
| On l'écrit, mais on ne referme PAS : l'éditeur, après nous, écrit encore le bloc du jeu,
| et `c0.s` écrit REG_SRAMLOCK juste après son retour. Un watchdog à chaque mot.
.Lt_bram:
        move.b  %d0, SRAMUNLOCK
        lea     0xD00000, %a2
        move.w  #0x8000 - 1, %d4
1:      move.w  (%a2), %d1              | l'original
        move.w  %d1, %d3
        not.w   %d3
        move.w  %d3, (%a2)              | le complément
        move.w  (%a2), %d2
        move.w  %d1, (%a2)              | l'original, remis
        cmp.w   %d3, %d2
        bne.s   2f
        cmp.w   (%a2), %d1
        bne.s   3f
        addq.l  #2, %a2
        move.b  %d0, WATCHDOG
        dbra    %d4, 1b
        moveq   #0, %d0
        moveq   #0, %d3
        rts
2:      move.w  %d3, %d1                | le complément n'a pas tenu
        bra.s   4f
3:      move.w  (%a2), %d2              | l'original n'est pas revenu
4:      moveq   #1, %d0
        moveq   #0, %d3
        rts

| ----------------------------------------------------------------------------------
| INPUT TEST. Lu dans « Memory mapped registers », tous actifs à l'état bas : REG_P1CNT
| ($300000) et REG_P2CNT ($340000) bits 0-7 haut, bas, gauche, droite, A, B, C, D ;
| REG_STATUS_B ($380000) bits 0-3 START P1, SELECT P1, START P2, SELECT P2 ; REG_STATUS_A
| ($320001) bits 0, 1 pièces 1 et 2, bit 2 « Service button » ; REG_DIPSW ($300001) les
| commutateurs de la carte. REG_SYSTYPE ($300081) bit 7, le bouton TEST : mesuré actif à
| l'état bas (`dip.s`). SUPPOSÉ : les huit commutateurs aux bits 0-7, le n° n au bit n-1
| (la page nomme les fonctions bit par bit sans numéroter les commutateurs). Pièces 3 et 4
| (bits 3, 4 de REG_STATUS_A, cartes à 4 ou 6 emplacements) non affichées.
| Un élément allumé (palette 5) quand son bit est à 0, éteint (palette 4) sinon, redessiné
| à chaque trame. SORTIE : START P1 tenu 60 trames de suite (≈ 1 s), puisque START est
| lui-même testé ; le rappel est à l'écran.
| LE COMMUTATEUR 3 À ON (« Mahjong Panel ») À L'OUVERTURE : la page du panneau de mahjong
| (`.Lt_mahjong`, DECISIONS §24). Lu une fois, à l'entrée, comme le BIOS SNK japonais et
| UniBIOS 4.0 (mesuré, `measured/2026-10-27-attentes-reference.tsv`) : basculé pendant le test, la
| page ne change pas, et le voyant du commutateur s'allume comme avant.
.Lt_entrees:
        btst    #2, DIPSW
        beq     .Lt_mahjong
        bsr     .Lsync
        jsr     _fix_clear
        move.w  #32, VRAMMOD
        bsr     .Ltitre_ecran
        lea     .Le_fixes, %a3          | les étiquettes fixes : case, chaîne
1:      move.w  (%a3)+, %d1
        beq.s   2f
        move.w  #0x1000, %d3
        movea.l %a3, %a2
        bsr     .Lplacer
        bsr     .Lchaine
        movea.l %a2, %a3
        move.l  %a3, %d0
        addq.l  #1, %d0
        andi.w  #0xFFFE, %d0
        movea.l %d0, %a3
        bra.s   1b
2:      move.w  #CASE_AIDE1, %d1
        move.w  #0x4000, %d3
        lea     .Le_aide, %a2
        bsr     .Lplacer
        bsr     .Lchaine
        moveq   #0, %d6                 | trames de START P1 tenu
.Le_trame:
        bsr     .Lsync
        lea     .Le_elements, %a3
1:      move.l  (%a3)+, %d0             | le registre, 0 en fin de table
        beq.s   3f
        movea.l %d0, %a0
        move.b  (%a3)+, %d0             | le bit
        moveq   #0, %d1
        move.b  (%a3)+, %d1             | la case
        lsl.w   #8, %d1
        move.b  (%a3)+, %d1
        move.w  #0x5000, %d3            | appuyé
        move.b  (%a0), %d2
        btst    %d0, %d2
        beq.s   2f
        move.w  #0x4000, %d3            | relâché
2:      movea.l %a3, %a2
        bsr     .Lplacer
        bsr     .Lchaine
        move.l  %a2, %d0
        addq.l  #1, %d0
        andi.w  #0xFFFE, %d0
        movea.l %d0, %a3
        bra.s   1b
3:      addq.w  #1, %d6
        btst    #0, STATUS_B
        beq.s   4f
        moveq   #0, %d6
4:      cmpi.w  #60, %d6
        bcs.s   .Le_trame
        rts

| ----------------------------------------------------------------------------------
| LA PAGE DU PANNEAU DE MAHJONG, le 2026-10-27 (DECISIONS §24, décision de l'utilisateur :
| copier le BIOS SNK japonais et UniBIOS 4.0). MESURÉ chez eux (`measured/2026-10-27-attentes-
| reference.tsv`) : une page à la place des manettes, une case par touche — A à G, H à N, PON, CHI,
| KAN, RON, REACH, START, SELECT —, 1 tant qu'elle est tenue, 0 sinon ; puis les pièces, TEST et
| les commutateurs. Ici la même liste, chaque touche suivie de son 0 ou 1 (palette 5 tenue,
| 4 relâchée), et les voyants de la page ordinaire pour COIN, SERVICE, TEST et DIP. P2 n'y est pas,
| comme chez eux. Le panneau est balayé comme `_io_mahjong` (`io.s`) : REG_POUTPUT ← $09, $12, $24,
| une rangée à la fois lue dans REG_P1CNT, actif bas ; START et SELECT dans REG_STATUS_B. La sortie
| reste à $24 : le jeu pose la sienne à son premier SYSTEM_IO. Sortie de l'écran : START P1 tenu
| 60 trames, comme la page ordinaire.
.Lt_mahjong:
        bsr     .Lsync
        jsr     _fix_clear
        move.w  #32, VRAMMOD
        bsr     .Ltitre_ecran
        lea     .Lm_fixes, %a3
1:      move.w  (%a3)+, %d1
        beq.s   2f
        move.w  #0x1000, %d3
        movea.l %a3, %a2
        bsr     .Lplacer
        bsr     .Lchaine
        move.l  %a2, %d0
        addq.l  #1, %d0
        andi.w  #0xFFFE, %d0
        movea.l %d0, %a3
        bra.s   1b
2:      move.w  #CASE_AIDE1, %d1
        move.w  #0x4000, %d3
        lea     .Le_aide, %a2
        bsr     .Lplacer
        bsr     .Lchaine
        moveq   #0, %d6                 | trames de START P1 tenu
.Lm_trame:
        bsr     .Lsync
        | %d4 : les rangées en logique positive, octet 0 A-G, 1 H-N, 2 PON-REACH, 3 START/SELECT.
        move.b  #0x09, 0x380001         | REG_POUTPUT : rangée A-G
        move.b  P1CNT, %d4
        lsl.l   #8, %d4
        move.b  #0x12, 0x380001         | rangée H-N
        move.b  P1CNT, %d4
        lsl.l   #8, %d4
        move.b  #0x24, 0x380001         | rangée PON-REACH
        move.b  P1CNT, %d4
        lsl.l   #8, %d4
        move.b  STATUS_B, %d4
        not.l   %d4
        lea     .Lm_touches, %a3
1:      move.w  (%a3)+, %d1             | la case, 0 en fin de table
        beq.s   3f
        move.b  (%a3)+, %d0             | le bit dans %d4 (rangée × 8 + bit)
        addq.l  #1, %a3
        move.w  #0x4000, %d3
        moveq   #0x30, %d5              | « 0 »
        btst    %d0, %d4
        beq.s   2f
        move.w  #0x5000, %d3
        moveq   #0x31, %d5              | « 1 »
2:      movea.l %a3, %a2
        bsr     .Lplacer
        bsr     .Lchaine
        moveq   #0x20, %d2
        bsr     .Lcar
        move.w  %d5, %d2
        bsr     .Lcar
        move.l  %a2, %d0
        addq.l  #1, %d0
        andi.w  #0xFFFE, %d0
        movea.l %d0, %a3
        bra.s   1b
3:      lea     .Lm_elements, %a3       | COIN, SERVICE, TEST, DIP : les voyants de la page ordinaire
1:      move.l  (%a3)+, %d0
        beq.s   3f
        movea.l %d0, %a0
        move.b  (%a3)+, %d0
        moveq   #0, %d1
        move.b  (%a3)+, %d1
        lsl.w   #8, %d1
        move.b  (%a3)+, %d1
        move.w  #0x5000, %d3
        move.b  (%a0), %d2
        btst    %d0, %d2
        beq.s   2f
        move.w  #0x4000, %d3
2:      movea.l %a3, %a2
        bsr     .Lplacer
        bsr     .Lchaine
        move.l  %a2, %d0
        addq.l  #1, %d0
        andi.w  #0xFFFE, %d0
        movea.l %d0, %a3
        bra.s   1b
3:      addq.w  #1, %d6
        btst    #0, STATUS_B
        beq.s   4f
        moveq   #0, %d6
4:      cmpi.w  #60, %d6
        bcs     .Lm_trame
        rts

| ----------------------------------------------------------------------------------
| LES MIRES. Une tuile pleine : MESURÉ sous MAME le 2026-10-21 (notre image, aof, -bios
| euro, SFIX de la carte de MAME ; sonde lua locale non versionnée qui pose les tuiles
| $000-$7FF sous une palette dont l'entrée i est un rouge de niveau i, puis lit chaque
| case 8×8 de la capture) : $000 est pleine de l'index 1, $020 (et $120, $220) pleine de
| l'index 2, $108-$10F pleines de l'index 10 ; sous $700, aucune tuile pleine d'un autre
| index que 1, 2 ou 10, et au-delà le contenu « may vary » (« SFIX ROM »), donc pas employé. Trois index pleins,
| seize palettes : au plus 48 couleurs à la fois, quand quatre barres de 15 pas en
| demandent 60 — d'où deux pages : ROUGE, VERT, BLEU, puis BLANC. Le pas 0 est le noir du
| fond. Palette s (1-15) : entrée 1 = rouge s, 2 = vert s, 10 = bleu s (« Colors » :
| $0RGB) ; page blanche : entrée 1 = gris s. Palette 0 : entrée 1 blanche pour le texte,
| 2 noire pour le fond (tuile $020 partout). A change de page, START sort.
        .equ    T_ROUGE, 0x000
        .equ    T_VERT,  0x020
        .equ    T_BLEU,  0x108
.Lt_barres:
        moveq   #0, %d7                 | la page
        moveq   #0, %d5
        bsr     .Lentrees
.Lb_page:
        bsr     .Lsync
        bsr     .Lpal_zero
        move.w  #0x0FFF, PALETTES + 2   | palette 0, entrée 1 : le texte
        lea     PALETTES + 32, %a0      | palette 1
        moveq   #1, %d4
1:      move.w  %d4, %d0                | rouge s, ou gris s
        lsl.w   #8, %d0
        tst.w   %d7
        beq.s   2f
        move.w  %d4, %d0
        mulu    #0x111, %d0
2:      move.w  %d0, 2(%a0)
        tst.w   %d7
        bne.s   3f
        move.w  %d4, %d0
        lsl.w   #4, %d0
        move.w  %d0, 4(%a0)             | vert s
        move.w  %d4, 20(%a0)            | bleu s, entrée 10
3:      lea     32(%a0), %a0
        addq.w  #1, %d4
        cmpi.w  #16, %d4
        bcs.s   1b
        bsr     .Lfond_plein
        move.w  #32, VRAMMOD
        tst.w   %d7
        bne.s   5f
        moveq   #6, %d6                 | rouge, lignes 6-11
        move.w  #T_ROUGE, %d4
        bsr.s   .Lbarre
        moveq   #12, %d6                | vert, 12-17
        move.w  #T_VERT, %d4
        bsr.s   .Lbarre
        moveq   #18, %d6                | bleu, 18-23
        move.w  #T_BLEU, %d4
        bsr.s   .Lbarre
        lea     .Lb_rvb, %a3
        bra.s   6f
5:      moveq   #6, %d6                 | blanc, 6-23 en trois fois
        move.w  #T_ROUGE, %d4
        bsr.s   .Lbarre
        moveq   #12, %d6
        bsr.s   .Lbarre
        moveq   #18, %d6
        bsr.s   .Lbarre
        lea     .Lb_blanc, %a3
6:      moveq   #0, %d3                 | palette 0
1:      move.w  (%a3)+, %d1             | les textes : case, chaîne
        beq.s   .Lb_attente
        movea.l %a3, %a2
        bsr     .Lplacer
        bsr     .Lchaine
        move.l  %a2, %d0
        addq.l  #1, %d0
        andi.w  #0xFFFE, %d0
        movea.l %d0, %a3
        bra.s   1b
.Lb_attente:
        bsr     .Lsync
        bsr     .Lentrees
        btst    #5, %d0
        bne.s   9f
        btst    #4, %d0
        beq.s   .Lb_attente
        eori.w  #1, %d7
        bra     .Lb_page
9:      rts

| UNE BARRE : six lignes depuis %d6, tuile %d4, colonnes 4-35, deux colonnes par pas ;
| le pas 0 laissé au fond noir. REG_VRAMMOD à 32. Clobbers %d0-%d2.
.Lbarre:
        moveq   #6 - 1, %d2
1:      move.w  %d6, %d1
        addi.w  #0x7000 + 4 * 32, %d1
        move.w  %d1, VRAMADDR
        moveq   #0, %d1                 | le pas, 0-15
2:      move.w  #0x0020, %d0
        tst.w   %d1
        beq.s   3f
        move.w  %d1, %d0
        ror.w   #4, %d0                 | palette s
        or.w    %d4, %d0
3:      move.w  %d0, VRAMRW
        move.w  %d0, VRAMRW             | > 12 cycles : l'écriture d'avant en fait 16
        addq.w  #1, %d1
        cmpi.w  #16, %d1
        bcs.s   2b
        addq.w  #1, %d6
        dbra    %d2, 1b
        rts

| CROSSHATCH : des traits pleins de 8 pixels (tuile $020 sous la palette 1, entrée 2
| blanche) toutes les quatre cases, colonnes 0, 4 … 36 et 39, lignes 2, 6 … 26 et 29 —
| les bords de la zone visible (« Fix layer » : lignes 2 à 29). Pas de trait d'un pixel :
| aucune tuile de ce dessin n'est mesurée. START sort.
.Lt_grille:
        bsr     .Lsync
        bsr     .Lpal_zero
        move.w  #0x0FFF, PALETTES + 32 + 4      | palette 1, entrée 2
        move.w  #1, VRAMMOD
        move.w  #0x7000, VRAMADDR
        moveq   #0, %d4                 | la colonne
1:      moveq   #0, %d6                 | la ligne
2:      move.w  #0x0020, %d0
        move.w  %d4, %d1
        andi.w  #3, %d1
        beq.s   3f
        cmpi.w  #39, %d4
        beq.s   3f
        cmpi.w  #2, %d6
        bcs.s   4f
        cmpi.w  #29, %d6
        bhi.s   4f
        beq.s   3f
        move.w  %d6, %d1
        subq.w  #2, %d1
        andi.w  #3, %d1
        bne.s   4f
3:      move.w  #0x1020, %d0
4:      move.w  %d0, VRAMRW
        move.b  %d0, WATCHDOG
        addq.w  #1, %d6
        cmpi.w  #32, %d6
        bcs.s   2b
        addq.w  #1, %d4
        cmpi.w  #40, %d4
        bcs.s   1b
        moveq   #0, %d5
        bsr     .Lentrees
1:      bsr     .Lsync
        bsr     .Lentrees
        btst    #5, %d0
        beq.s   1b
        rts

| TOUT LE PLAN FIXE en tuile $020, palette 0 (REG_VRAMMOD à 1). Clobbers %d0, %d1.
.Lfond_plein:
        move.w  #1, VRAMMOD
        move.w  #0x7000, VRAMADDR
        move.w  #0x0020, %d0
        move.w  #40 * 32 - 1, %d1
1:      move.w  %d0, VRAMRW
        dbra    %d1, 1b
        rts

| ----------------------------------------------------------------------------------
| LE MENU, tout redessiné : palettes après le passage de la ligne $1F0, FIX_CLEAR, titre,
| lignes, aide. Clobbers %d0-%d4, %d6, %a0-%a3.
.Lmenu:
        bsr     .Lsync
        bsr     .Lpal_zero
        move.w  #0x8000, FOND           | comme `dip.s`
        lea     .Lcouleurs, %a3
        lea     PALETTES + 32 + 2, %a0  | palette 1, entrée 1
        moveq   #6 - 1, %d0
1:      move.w  (%a3)+, (%a0)
        lea     32(%a0), %a0
        dbra    %d0, 1b
        jsr     _fix_clear
        move.w  #32, VRAMMOD
        bsr.s   .Ltitre_ecran
        moveq   #0, %d0
1:      move.w  %d0, -(%sp)
        bsr     .Lligne
        move.w  (%sp)+, %d0
        addq.w  #1, %d0
        cmpi.w  #N_LIGNES, %d0
        bcs.s   1b
        move.w  #0x4000, %d3
        move.w  #CASE_AIDE1, %d1
        lea     .Ltxt_aide1, %a2
        bsr     .Lplacer
        bsr     .Lchaine
        move.w  #CASE_AIDE2, %d1
        lea     .Ltxt_aide2, %a2
        bsr     .Lplacer
        bra     .Lchaine

| LE TITRE en 8×16, palette 3. Clobbers %d1-%d3, %a2.
.Ltitre_ecran:
        move.w  #CASE_TITRE, %d1
        move.w  #0x3100, %d3
        lea     .Ltxt_titre, %a2
        bsr     .Lplacer
        bsr     .Lchaine
        move.w  #CASE_TITRE + 1, %d1
        move.w  #0x3200, %d3
        lea     .Ltxt_titre, %a2
        bsr     .Lplacer
        bra     .Lchaine

| LA LIGNE %d0 DU MENU : curseur, intitulé (16), état (12) ; pour un test de mémoire,
| la ligne suivante porte le détail d'une faute, ou des espaces. Clobbers %d0-%d4, %d6,
| %a2, %a3.
.Lligne:
        move.w  %d0, %d6
        lea     .Lrangs, %a2
        moveq   #0, %d1
        move.b  (%a2,%d6.w), %d1
        addi.w  #CASE_MENU, %d1
        bsr     .Lplacer
        move.w  #0x1000, %d3
        moveq   #0x20, %d2
        cmp.w   %d7, %d6
        bne.s   1f
        move.w  #0x2000, %d3
        moveq   #0x3E, %d2              | « > »
1:      bsr     .Lcar
        moveq   #0x20, %d2
        bsr     .Lcar
        move.w  %d6, %d0
        lsl.w   #4, %d0
        lea     .Lnoms, %a2
        adda.w  %d0, %a2
        moveq   #16, %d4
        bsr     .Lecrire
        cmpi.w  #4, %d6
        bcc     9f
        lea     F_RES(%a6), %a3
        move.w  %d6, %d0
        mulu    #R_TAILLE, %d0
        adda.w  %d0, %a3
        moveq   #0, %d0
        move.b  (%a3), %d0
        lsl.w   #2, %d0
        lsr.w   #1, %d0
        lea     .Lpal_etats, %a2
        move.w  (%a2,%d0.w), %d3
        lsl.w   #1, %d0
        lea     .Letats, %a2
        movea.l (%a2,%d0.w), %a2
        moveq   #12, %d4
        cmpi.b  #2, (%a3)
        bne.s   3f
        cmpi.w  #1, %d6                 | la palette : la banque fautive
        bne.s   3f
        lea     .Ltxt_fail_banque, %a2
        moveq   #10, %d4                | « FAIL BANK »
        bsr     .Lecrire
        moveq   #0x30, %d2
        add.b   1(%a3), %d2
        bsr     .Lcar
        lea     .Ltxt_espace, %a2
        moveq   #1, %d4
3:      bsr     .Lecrire
        | LE DÉTAIL, une ligne plus bas, colonne 5.
        lea     .Lrangs, %a2
        moveq   #0, %d1
        move.b  (%a2,%d6.w), %d1
        addi.w  #CASE_MENU + 2 * 32 + 1, %d1
        bsr     .Lplacer
        cmpi.b  #2, (%a3)
        beq.s   4f
        lea     .Ltxt_espace, %a2
        moveq   #32, %d4
        bra     .Lecrire
4:      move.w  #0x6000, %d3
        lea     .Ltxt_at, %a2
        bsr     .Lchaine
        move.l  2(%a3), %d4
        moveq   #8, %d0
        bsr     .Lhex
        lea     .Ltxt_ecrit, %a2
        bsr     .Lchaine
        move.w  6(%a3), %d4
        swap    %d4
        moveq   #4, %d0
        bsr     .Lhex
        lea     .Ltxt_lu, %a2
        bsr     .Lchaine
        move.w  8(%a3), %d4
        swap    %d4
        moveq   #4, %d0
        bra     .Lhex
9:      rts

| ----------------------------------------------------------------------------------
| L'ÉCRITURE DU TEXTE, REG_VRAMMOD à 32 : une donnée = une case vers la droite.
| `.Lplacer` pose l'adresse %d1 ; `.Lcar` écrit %d2 + %d3 (palette << 12 + décalage de
| tuile) ; entre deux données, l'appel seul tient plus de 12 cycles, et le `rts` qui suit
| la dernière plus de 16 avant l'adresse suivante (« VRAM »).
.Lplacer:
        move.w  %d1, VRAMADDR
        rts
.Lcar:
        add.w   %d3, %d2
        move.w  %d2, VRAMRW
        rts
| UNE CHAÎNE terminée par 0, %a2 avancé après le 0. Clobbers %d2.
.Lchaine:
        moveq   #0, %d2
        move.b  (%a2)+, %d2
        beq.s   1f
        bsr.s   .Lcar
        bra.s   .Lchaine
1:      rts
| %d4 CARACTÈRES de %a2, sans fin de chaîne. Clobbers %d2, %d4, %a2.
.Lecrire:
        subq.w  #1, %d4
1:      moveq   #0, %d2
        move.b  (%a2)+, %d2
        bsr.s   .Lcar
        dbra    %d4, 1b
        rts
| %d0 CHIFFRES HEXADÉCIMAUX, les hauts de %d4 d'abord. Clobbers %d0, %d2, %d4.
.Lhex:
        subq.w  #1, %d0
1:      rol.l   #4, %d4
        moveq   #0x0F, %d2
        and.w   %d4, %d2
        cmpi.w  #10, %d2
        bcs.s   2f
        addq.w  #7, %d2                 | 10-15 → « A »-« F »
2:      addi.w  #0x30, %d2
        bsr.s   .Lcar
        dbra    %d0, 1b
        rts

| LES BOUTONS DE P1, comme `dip.s`. %d5 : l'état d'avant, mis à jour ; %d0 : les fronts.
| Bits : 0 haut, 1 bas, 2 gauche, 3 droite, 4 A, 5 START. Clobbers %d1, %d2.
.Lentrees:
        move.b  P1CNT, %d2
        not.b   %d2
        andi.b  #0x1F, %d2
        move.b  STATUS_B, %d1
        not.b   %d1
        andi.b  #0x01, %d1
        lsl.b   #5, %d1
        or.b    %d1, %d2
        move.b  %d5, %d0
        not.b   %d0
        and.b   %d2, %d0
        move.b  %d2, %d5
        rts

| LE PASSAGE DE LA LIGNE $1F0, comme `dip.s` (mesuré,
| `2026-10-17-diagnostic-b2b-minasan.tsv`) ; watchdog à chaque tour. Clobbers %d0.
| BORNÉE à SYNC_TOURS tours par attente, ≈ 2 trames, ligne vue ou non : le compte est dans
| `ecran.s`, dont c'est la copie identique.
        .equ    SYNC_TOURS, 5800
.Lsync:
        move.l  %d1, -(%sp)
        move.w  #SYNC_TOURS - 1, %d1
1:      move.b  %d0, WATCHDOG
        move.w  LSPCMODE, %d0
        lsr.w   #7, %d0
        cmpi.w  #0x1F0, %d0
        dbne    %d1, 1b
        move.w  #SYNC_TOURS - 1, %d1
2:      move.b  %d0, WATCHDOG
        move.w  LSPCMODE, %d0
        lsr.w   #7, %d0
        cmpi.w  #0x1F0, %d0
        dbeq    %d1, 2b
        move.l  (%sp)+, %d1
        rts

| LES PALETTES 0-15 de la banque en place à zéro, entrées 1-15 ; la référence $400000 à
| $8000. À appeler juste après `.Lsync`. Clobbers %d0, %a0.
.Lpal_zero:
        lea     PALETTES, %a0
        move.w  #0x8000, (%a0)+
        move.w  #16 * 16 - 2, %d0
1:      clr.w   (%a0)+
        dbra    %d0, 1b
        rts

| ----------------------------------------------------------------------------------
| LES DONNÉES.
        .balign 2
.Ltests:
        .long   .Lt_ram, .Lt_pal, .Lt_vram, .Lt_bram
        .long   .Lt_entrees, .Lt_barres, .Lt_grille, _crc_cartouche
| Les motifs : valeur, puis 0 donnée / 1 adresse (xor de la valeur).
.Lmotifs:
        .word   0x0000, 0, 0xFFFF, 0, 0x5555, 0, 0xAAAA, 0, 0x0000, 1, 0xFFFF, 1
| Les zones VRAM testées : début, nombre de mots.
.Lzones:
        .word   0x0000, 0x8000, 0x8000, 0x0600, 0x8700, 0x0100
| L'entrée 1 des palettes 1 à 6, $0RGB (« Colors »). Choix d'aspect, ceux de `dip.s`.
.Lcouleurs:
        .word   0x0BBB, 0x0FE3, 0x04BF, 0x0777, 0x02F4, 0x0F44
| La ligne de chaque entrée du menu.
.Lrangs:
        .byte   7, 9, 11, 13, 16, 17, 18, 19, 21
        .balign 2
.Lnoms:                                 | 16 caractères chacun
        .ascii  "WORK RAM        "
        .ascii  "PALETTE RAM     "
        .ascii  "VRAM            "
        .ascii  "BACKUP RAM      "
        .ascii  "INPUT TEST      "
        .ascii  "COLOR BARS      "
        .ascii  "CROSSHATCH      "
        .ascii  "CARTRIDGE CRC   "
        .ascii  "EXIT            "
.Lpal_etats:                             | la palette de chaque état
        .word   0x1000, 0x5000, 0x6000, 0x2000
.Letats:
        .long   .Ltxt_espace, .Ltxt_ok, .Ltxt_fail, .Ltxt_encours
.Ltxt_espace:   .ascii  "                                  "
.Ltxt_ok:       .ascii  "OK          "
.Ltxt_fail:     .ascii  "FAIL        "
.Ltxt_fail_banque: .ascii "FAIL BANK "
.Ltxt_encours:  .ascii  "TESTING     "
.Ltxt_titre:    .asciz  "HARDWARE TESTS"
.Ltxt_aide1:    .asciz  "UP/DOWN:SELECT  A:RUN"
.Ltxt_aide2:    .asciz  "START:BACK"
.Ltxt_at:       .asciz  "AT "
.Ltxt_ecrit:    .asciz  " WROTE "
.Ltxt_lu:       .asciz  " READ "
.Le_aide:       .asciz  "HOLD START P1 1 SEC TO EXIT"
        .balign 2

| L'INPUT TEST. Une case : $7000 + 32 × colonne + ligne.
        .macro  FIXE col, ligne, txt
        .word   0x7000 + 32 * (\col) + (\ligne)
        .asciz  "\txt"
        .balign 2
        .endm
        .macro  ELEM reg, bit, col, ligne, txt
        .long   \reg
        .byte   \bit
        .byte   (0x7000 + 32 * (\col) + (\ligne)) >> 8, (0x7000 + 32 * (\col) + (\ligne)) & 0xFF
        .asciz  "\txt"
        .balign 2
        .endm
.Le_fixes:
        FIXE    3, 7, "P1"
        FIXE    3, 9, "P2"
        FIXE    3, 11, "P1"
        FIXE    3, 12, "P2"
        FIXE    3, 14, "COIN"
        FIXE    3, 18, "DIP"
        .word   0
.Le_elements:
        ELEM    P1CNT, 0, 7, 7, "UP"
        ELEM    P1CNT, 1, 10, 7, "DOWN"
        ELEM    P1CNT, 2, 15, 7, "LEFT"
        ELEM    P1CNT, 3, 20, 7, "RIGHT"
        ELEM    P1CNT, 4, 26, 7, "A"
        ELEM    P1CNT, 5, 28, 7, "B"
        ELEM    P1CNT, 6, 30, 7, "C"
        ELEM    P1CNT, 7, 32, 7, "D"
        ELEM    P2CNT, 0, 7, 9, "UP"
        ELEM    P2CNT, 1, 10, 9, "DOWN"
        ELEM    P2CNT, 2, 15, 9, "LEFT"
        ELEM    P2CNT, 3, 20, 9, "RIGHT"
        ELEM    P2CNT, 4, 26, 9, "A"
        ELEM    P2CNT, 5, 28, 9, "B"
        ELEM    P2CNT, 6, 30, 9, "C"
        ELEM    P2CNT, 7, 32, 9, "D"
        ELEM    STATUS_B, 0, 7, 11, "START"
        ELEM    STATUS_B, 1, 13, 11, "SELECT"
        ELEM    STATUS_B, 2, 7, 12, "START"
        ELEM    STATUS_B, 3, 13, 12, "SELECT"
        ELEM    STATUS_A, 0, 9, 14, "1"
        ELEM    STATUS_A, 1, 11, 14, "2"
        ELEM    STATUS_A, 2, 15, 14, "SERVICE"
        ELEM    SYSTYPE, 7, 3, 16, "TEST"
        ELEM    DIPSW, 0, 9, 18, "1"
        ELEM    DIPSW, 1, 11, 18, "2"
        ELEM    DIPSW, 2, 13, 18, "3"
        ELEM    DIPSW, 3, 15, 18, "4"
        ELEM    DIPSW, 4, 17, 18, "5"
        ELEM    DIPSW, 5, 19, 18, "6"
        ELEM    DIPSW, 6, 21, 18, "7"
        ELEM    DIPSW, 7, 23, 18, "8"
        .long   0

| LA PAGE DU PANNEAU DE MAHJONG. Une touche : la case, le bit dans %d4 de `.Lm_trame` (rangée × 8 +
| bit ; 24-31 : REG_STATUS_B), un octet libre, l'intitulé.
        .macro  TOUCHE bit, col, ligne, txt
        .word   0x7000 + 32 * (\col) + (\ligne)
        .byte   \bit, 0
        .asciz  "\txt"
        .balign 2
        .endm
.Lm_fixes:
        FIXE    3, 6, "MAHJONG PANEL"
        FIXE    3, 16, "COIN"
        FIXE    3, 20, "DIP"
        .word   0
.Lm_touches:
        TOUCHE  24, 5, 8, "A"
        TOUCHE  25, 5, 9, "B"
        TOUCHE  26, 5, 10, "C"
        TOUCHE  27, 5, 11, "D"
        TOUCHE  28, 5, 12, "E"
        TOUCHE  29, 5, 13, "F"
        TOUCHE  30, 5, 14, "G"
        TOUCHE  16, 11, 8, "H"
        TOUCHE  17, 11, 9, "I"
        TOUCHE  18, 11, 10, "J"
        TOUCHE  19, 11, 11, "K"
        TOUCHE  20, 11, 12, "L"
        TOUCHE  21, 11, 13, "M"
        TOUCHE  22, 11, 14, "N"
        TOUCHE  8, 17, 8, "PON   "
        TOUCHE  9, 17, 9, "CHI   "
        TOUCHE  10, 17, 10, "KAN   "
        TOUCHE  11, 17, 11, "RON   "
        TOUCHE  12, 17, 12, "REACH "
        TOUCHE  0, 17, 13, "START "
        TOUCHE  1, 17, 14, "SELECT"
        .word   0
.Lm_elements:
        ELEM    STATUS_A, 0, 9, 16, "1"
        ELEM    STATUS_A, 1, 11, 16, "2"
        ELEM    STATUS_A, 2, 15, 16, "SERVICE"
        ELEM    SYSTYPE, 7, 3, 18, "TEST"
        ELEM    DIPSW, 0, 9, 20, "1"
        ELEM    DIPSW, 1, 11, 20, "2"
        ELEM    DIPSW, 2, 13, 20, "3"
        ELEM    DIPSW, 3, 15, 20, "4"
        ELEM    DIPSW, 4, 17, 20, "5"
        ELEM    DIPSW, 5, 19, 20, "6"
        ELEM    DIPSW, 6, 21, 20, "7"
        ELEM    DIPSW, 7, 23, 20, "8"
        .long   0

| LES MIRES : textes sous la palette 0.
.Lb_rvb:
        FIXE    16, 3, "COLOR BARS"
        FIXE    2, 8, "R"
        FIXE    2, 14, "G"
        FIXE    2, 20, "B"
        FIXE    10, 26, "A:WHITE  START:EXIT"
        .word   0
.Lb_blanc:
        FIXE    16, 3, "COLOR BARS"
        FIXE    2, 14, "W"
        FIXE    11, 26, "A:RGB  START:EXIT"
        .word   0
        .balign 2
