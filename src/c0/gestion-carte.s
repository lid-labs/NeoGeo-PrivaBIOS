| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| LE GESTIONNAIRE DE LA CARTE MÉMOIRE — ouvert depuis l'écran TEST (`dip.s`, ligne MEMORY
| CARD) : la liste des sauvegardes de la carte, les blocs libres, l'effacement d'une
| sauvegarde et le formatage, chacun avec une confirmation.
|
| AUCUN ORACLE : ni le gestionnaire d'un autre BIOS ni le code d'un jeu ne sont lus. Écrit sous le
| mandat du lot 2 de la carte mémoire, le 2026-10-24 ; scènes cm-* et bf-carte de `bench/parcours.sh`.
| « mesuré » : un relevé nommé ; « lu dans » : une page du NeoGeo Development Wiki ;
| « SUPPOSÉ » : ni l'un ni l'autre.
|
| APPEL : `jsr _gestion_carte` depuis `dip.s`. Tous les registres rendus. L'état à l'appel est
| celui de l'écran TEST : REG_BRDFIX (la police de la carte), palettes 1-4 de `dip.s` dans la
| banque 0, IRQ masquées, backup RAM déverrouillée. Au retour, le même, la palette 5 à zéro
| (comme `jukebox.s`) ; `dip.s` redessine son écran.
|
| CE QUI EST LU, et ce qui ne l'est pas. La carte par `card.s` : `_carte_releve` pour la liste
| (aucune écriture), CARD lui-même pour effacer ($04) et formater ($00), par l'interface que
| les jeux emploient (« CARD » : BIOS_CARD_COMMAND $10FDC4, BIOS_CARD_FCB $10FDCE, BIOS_CARD_SUB
| $10FDD0, la réponse à $10FDC6). Rien de la cartouche : sous REG_BRDFIX, la P-ROM ne répond
| pas sur le matériel (DECISIONS §13). LE NOM DU JEU vient donc de la backup RAM : la table des
| slots ($D00124, NGH et bloc de chaque slot) et le nom que le boot y recopie au premier lancement
| de chaque jeu ($D002A0 + 16 × bloc, `c0.s`, `_inscrire_slot`). Une sauvegarde dont le NGH n'est
| celui d'aucun jeu inscrit n'a pas de nom ; une cartouche jamais lancée sur cette carte non plus.
|
| LA LISTE, une ligne par entrée prise du répertoire de la carte (son premier octet n'est pas
| $FF, lu dans « Memory card »), dans l'ordre du répertoire : le NGH en hexadécimal, la
| sous-sauvegarde en décimal, le nombre de blocs de sa chaîne dans la FAT 1, le nom. Puis deux
| lignes : FORMAT CARD et EXIT. Treize lignes visibles ; la liste défile avec le curseur.
| LES BLOCS LIBRES : les entrées $00 de la FAT 1, blocs 5 à 31 (les blocs 0 à 4 portent
| l'en-tête, le répertoire et les FAT : 27 blocs de données sur une carte de 2 Kio).
| LES ÉTATS, une ligne : NO CARD, CARD NOT FORMATTED, UNSUPPORTED CARD (une autre géométrie,
| que CARD refuse aussi), ou FREE BLOCKS ; et WRITE PROTECTED en dessous quand le bit 6 de
| REG_STATUS_B le dit, carte présente (lu dans « Memory card »).
| LA CARTE CHANGÉE pendant l'écran : REG_STATUS_B (bits 4-6) relu à chaque trame ; un changement
| relit la carte et redessine tout.
|
| LES COMMANDES, P1, sur front (REG_P1CNT, REG_STATUS_B bit 0, actifs à l'état bas). Haut/bas :
| la ligne, en boucle. A : sur une sauvegarde, DELETE ? ; sur FORMAT CARD, FORMAT ? ; sur EXIT, la
| sortie. LA CONFIRMATION : A une seconde fois agit, B ou START renoncent. START hors
| confirmation : la sortie. Carte protégée, ou sans carte : le message, rien d'écrit.
|
| LA COPIE, le 2026-10-27 (DECISIONS §26, décision de l'utilisateur : une sauvegarde à la
| fois, comme UniBIOS 4.0 sans son COPY ALL). C sur une sauvegarde la lit par CARD ($02, la taille de
| sa chaîne : blocs × 64) dans un tampon, puis « CHANGE CARD AND PRESS A ». A l'écrit par CARD ($03)
| sur la carte en place ; si cette carte porte déjà le même NGH et la même sous-sauvegarde, « OVERWRITE
| nnnn-ss? » d'abord, A écrit, B ou START renoncent. B ou START renoncent aussi en attendant la carte.
| La carte changée pendant l'attente ne l'abandonne pas (c'est le but), elle redessine la liste.
| Carte protégée ou absente au A : le message, l'attente continue. MESURÉ chez UniBIOS 4.0
| (`measured/2026-10-27-attentes-reference.tsv`) : « DATA IS COPIED / CHANGE CARD AND PRESS A
| BUTTON », puis « GAME IS ALREADY ON THIS CARD / DO YOU WANT TO DELETE OLD DATA ? ».
| LA PLACE DU TAMPON : 27 blocs de 64 octets au plus, 1 728 octets (une carte de 2 Kio, seule
| géométrie servie, `card.s`), quand la RAM du gestionnaire n'en a que 256 et que celle de l'écran TEST
| ($10F464-$10FAFF) tient la copie du bloc soft-DIP de `dip.s`. Le tampon est donc la RAM de travail du
| jeu, $100000-$1006BF, que le jeu n'emploie pas pendant l'écran TEST ; ses 1 728 octets sont mis de
| côté en VRAM, $0000-$035F (la carte des tuiles des sprites 0 à 13, masqués par LSP_1st au boot et
| jamais affichés par l'écran TEST), avant la lecture, et rendus après l'écriture ou le renoncement :
| la RAM que le boot a restaurée pour le jeu ressort intacte. Écritures VRAM au rythme de `tests.s`.
|
| L'INTERFACE DE CARD est gardée à l'entrée et rendue à la sortie ($10FCF4, $10FD00-$10FD17,
| $10FDC4-$10FDD1) : un jeu ne trouve pas, au lancement, les traces d'un appel qu'il n'a pas
| fait. SUPPOSÉ sans effet ; elle est à zéro au boot, le vidage de `c0.s` l'y ayant mise.
|
| LA RAM : $10F300-$10F3FF, au-dessus de la pile du BIOS (posée à $10F300, elle descend) et sous
| la sauvegarde de `plantage.s` ($10F400) — 192 octets du relevé, l'interface gardée, quatre
| variables ; remise à zéro à la sortie, comme le boot l'avait laissée.
| ==================================================================================

        .section .haut, "ax"
        .global _gestion_carte

        .equ    VRAMADDR, 0x3C0000
        .equ    VRAMRW,   0x3C0002
        .equ    VRAMMOD,  0x3C0004
        .equ    LSPCMODE, 0x3C0006
        .equ    WATCHDOG, 0x300001
        .equ    P1CNT,    0x300000
        .equ    STATUS_B, 0x380000
        .equ    PALETTES, 0x400000

        .equ    TAMPON,   0x10F300      | 192 octets : la carte de $40 à $FF
        .equ    T_FAT,    TAMPON + 0x80 | la FAT 1 (octet $C0 de la carte)
        .equ    GARDE,    0x10F3C0      | 39 octets : l'interface de CARD
        .equ    V_N,      0x10F3E8      | .w les lignes : sauvegardes + 2
        .equ    V_ETAT,   0x10F3EA      | .b le relevé : $00, $80, $81, $85
        .equ    V_STB,    0x10F3EB      | .b REG_STATUS_B & $70 au relevé
        .equ    V_CONF,   0x10F3EC      | .b 0 rien, 1 effacer, 2 formater, 3 copie lue (la carte
                                        | cible attendue), 4 écraser : en attente de A
        .equ    V_SUB,    0x10F3ED      | .b la copie : sa sous-sauvegarde
        .equ    V_NGH,    0x10F3EE      | .w son NGH
        .equ    V_TAILLE, 0x10F3F0      | .w sa taille en octets
        .equ    COPIE_RAM, 0x100000     | le tampon de la copie (voir l'en-tête, LA COPIE)
        .equ    COPIE_MOTS, 27 * 64 / 2 | 864 mots, la plus grande sauvegarde d'une carte de 2 Kio
        .equ    START_C,  0x10FDC8      | BIOS_CARD_START
        .equ    SIZE_C,   0x10FDCC      | BIOS_CARD_SIZE
        .equ    RAM_FIN,  0x10F400

        .equ    CMD,      0x10FDC4      | BIOS_CARD_COMMAND
        .equ    REPONSE,  0x10FDC6      | BIOS_CARD_ANSWER
        .equ    FCB,      0x10FDCE      | BIOS_CARD_FCB, le NGH
        .equ    SUB,      0x10FDD0      | BIOS_CARD_SUB

        .equ    PAL_ALERTE, 5
        .equ    C_ALERTE, 0x0F44        | choix d'aspect, celui de FAIL (`tests.s`)

        | La mise en page, en cases du plan fixe ($7000 + 32 × colonne + ligne).
        .equ    CASE_TITRE,  0x7000 + 14 * 32 + 3      | 8×16, lignes 3-4
        .equ    CASE_ETAT,   0x7000 +  3 * 32 + 6
        .equ    CASE_PROT,   0x7000 +  3 * 32 + 7
        .equ    CASE_ENTETE, 0x7000 +  3 * 32 + 9
        .equ    LIGNE0,      10         | la première ligne de la liste
        .equ    VISIBLES,    13         | lignes 10 à 22
        .equ    CASE_MSG,    0x7000 +  3 * 32 + 24
        .equ    CASE_AIDE1,  0x7000 +  3 * 32 + 27
        .equ    CASE_AIDE2,  0x7000 +  3 * 32 + 28
        .equ    LARGEUR,     31

        .equ    F_LIGNE,  -32           | le cadre : une ligne composée

| %a0 : REG_VRAMRW ; %d5 : les boutons de la trame d'avant ; %d6 : la première ligne visible ;
| %d7 : la ligne choisie.
_gestion_carte:
        movem.l %d0-%d7/%a0-%a6, -(%sp)
        link    %a6, #F_LIGNE
        lea     GARDE, %a1              | l'interface de CARD, gardée
        move.b  0x10FCF4, (%a1)+
        lea     0x10FD00, %a2
        moveq   #24 - 1, %d0
1:      move.b  (%a2)+, (%a1)+
        dbra    %d0, 1b
        lea     CMD, %a2
        moveq   #14 - 1, %d0
2:      move.b  (%a2)+, (%a1)+
        dbra    %d0, 2b
        lea     VRAMRW, %a0
        bsr     .Lreleve
        moveq   #0, %d7
        moveq   #0, %d6
        bsr     .Lecran
        moveq   #0, %d5
        bsr     .Lentrees               | un bouton déjà tenu (le A qui ouvre) ne compte pas

| LA BOUCLE, une trame par tour.
.Lboucle:
        bsr     .Lsync
        move.b  STATUS_B, %d0           | la carte changée : relue, tout redessiné
        andi.b  #0x70, %d0
        cmp.b   V_STB, %d0
        beq.s   1f
        cmpi.b  #3, V_CONF              | la copie attend justement une autre carte
        beq.s   5f
        cmpi.b  #4, V_CONF
        bne.s   6f
        move.b  #3, V_CONF              | écraser visait l'ancienne carte : on attend de nouveau A
        bra.s   5f
6:      clr.b   V_CONF                  | une confirmation visait l'ancienne carte : abandonnée
5:      bsr     .Lreleve
        bsr     .Lborner
        bsr     .Lecran
        cmpi.b  #3, V_CONF
        bne.s   1f
        lea     .Ltxt_changer, %a2
        bsr     .Lmessage
1:      bsr     .Lentrees               | %d0 les fronts : 0 haut, 1 bas, 4 A, 5 B, 6 START, 7 C
        tst.b   V_CONF
        bne     .Lconfirmer
        btst    #6, %d0
        bne     .Lsortie
        btst    #0, %d0                 | haut
        beq.s   2f
        subq.w  #1, %d7
        bpl.s   3f
        move.w  V_N, %d7
        subq.w  #1, %d7
        bra.s   3f
2:      btst    #1, %d0                 | bas
        beq.s   4f
        addq.w  #1, %d7
        cmp.w   V_N, %d7
        bcs.s   3f
        moveq   #0, %d7
3:      bsr     .Lborner
        bsr     .Lliste
        bra     .Lboucle
4:      btst    #7, %d0                 | C : copier la sauvegarde de la ligne
        bne     .Lcopier
        btst    #4, %d0                 | A
        beq     .Lboucle
        move.w  V_N, %d0
        subq.w  #1, %d0
        cmp.w   %d0, %d7
        beq     .Lsortie                | EXIT
        subq.w  #1, %d0
        cmp.w   %d0, %d7
        beq.s   .Lveut_formater
        | Une sauvegarde : DELETE ?
        btst    #6, STATUS_B
        bne.s   .Lprotegee
        move.b  #1, V_CONF
        bsr     .Lmsg_effacer
        bra     .Lboucle
.Lveut_formater:
        cmpi.b  #0x80, V_ETAT
        beq.s   .Lsans_carte
        btst    #6, STATUS_B
        bne.s   .Lprotegee
        move.b  #2, V_CONF
        lea     .Ltxt_formater, %a2
        bsr     .Lmessage
        bra     .Lboucle
.Lsans_carte:
        lea     .Ltxt_sans, %a2
        bsr     .Lmessage
        bra     .Lboucle
.Lprotegee:
        lea     .Ltxt_protegee, %a2
        bsr     .Lmessage
        bra     .Lboucle

| LA CONFIRMATION : A agit, B ou START renoncent, le reste attend.
.Lconfirmer:
        cmpi.b  #3, V_CONF
        bcc     .Lc_attente
        btst    #4, %d0
        bne.s   1f
        andi.b  #0x60, %d0
        beq     .Lboucle
        clr.b   V_CONF
        lea     .Ltxt_renonce, %a2
        bsr     .Lmessage
        bra     .Lboucle
1:      move.b  V_CONF, %d1
        clr.b   V_CONF
        cmpi.b  #2, %d1
        beq.s   2f
        move.w  %d7, %d0                | effacer la sauvegarde de la ligne
        bsr     .Lentree
        move.b  #0x04, CMD
        move.b  1(%a1), FCB
        move.b  2(%a1), FCB + 1
        move.b  (%a1), SUB
        lea     .Ltxt_efface, %a2
        bra.s   3f
2:      move.b  #0x00, CMD              | formater
        lea     .Ltxt_formate, %a2
3:      jsr     _card
        moveq   #0, %d4
        move.b  REPONSE, %d4
        movem.l %d4/%a2, -(%sp)         | la réponse et le message, que l'écran écrase
        bsr     .Lreleve
        bsr     .Lborner
        bsr     .Lecran
        movem.l (%sp)+, %d4/%a2
        tst.b   %d4
        beq.s   4f
        lea     .Ltxt_erreur, %a2       | CARD ERROR et la réponse
        lea     F_LIGNE(%a6), %a1
        moveq   #L_ERREUR - 1, %d0
5:      move.b  (%a2)+, (%a1)+
        dbra    %d0, 5b
        move.b  %d4, %d0
        bsr     .Lhex2
        clr.b   (%a1)
        lea     F_LIGNE(%a6), %a2
4:      bsr     .Lmessage
        bra     .Lboucle

| ----------------------------------------------------------------------------------
| LA COPIE (voir l'en-tête). C sur une ligne : une sauvegarde, la carte lisible, sinon rien.
.Lcopier:
        move.w  V_N, %d1
        subq.w  #2, %d1
        cmp.w   %d1, %d7
        bcc     .Lboucle                | FORMAT CARD, EXIT : rien
        tst.b   V_ETAT
        bne     .Lboucle                | pas de sauvegarde lisible
        move.w  %d7, %d0
        bsr     .Lentree
        movea.l %a1, %a3
        move.b  (%a3), V_SUB
        move.b  1(%a3), V_NGH
        move.b  2(%a3), V_NGH + 1
        bsr     .Lblocs                 | %d0 : les blocs de sa chaîne
        lsl.w   #6, %d0
        move.w  %d0, V_TAILLE
        bsr     .Lmettre_de_cote
        move.b  #0x02, CMD              | CHARGER
        bsr     .Lc_interface
        jsr     _card
        tst.b   REPONSE
        beq.s   1f
        bsr     .Lrendre                | lue en erreur : rien n'attend
        moveq   #0, %d4
        move.b  REPONSE, %d4
        bra     .Lc_erreur
1:      move.b  #3, V_CONF
        lea     .Ltxt_changer, %a2
        bsr     .Lmessage
        bra     .Lboucle

| L'ATTENTE DE LA CARTE CIBLE (3) ET DE L'ÉCRASEMENT (4) : A écrit, ou demande d'écraser ; B ou START
| renoncent, la RAM du jeu rendue.
.Lc_attente:
        btst    #4, %d0
        bne.s   2f
        andi.b  #0x60, %d0
        beq     .Lboucle
        clr.b   V_CONF
        bsr     .Lrendre
        lea     .Ltxt_renonce, %a2
        bsr     .Lmessage
        bra     .Lboucle
2:      bsr     .Lreleve                | la carte en place relue : un échange que REG_STATUS_B n'a pas
        bsr     .Lborner                | vu (retirée et remise entre deux trames) ne trompe pas la
        bsr     .Lecran                 | recherche qui suit
        cmpi.b  #0x80, V_ETAT
        beq     .Lsans_carte            | l'attente continue
        btst    #6, STATUS_B
        bne     .Lprotegee
        cmpi.b  #4, V_CONF
        beq.s   4f
        | 3 : la carte en place porte-t-elle déjà ce NGH et cette sous-sauvegarde ?
        tst.b   V_ETAT
        bne.s   4f                      | non formatée, inconnue : CARD répondra
        lea     TAMPON, %a1
        moveq   #32 - 1, %d1
3:      move.b  (%a1), %d2
        cmpi.b  #0xFF, %d2
        beq.s   5f
        cmp.b   V_SUB, %d2
        bne.s   5f
        move.b  1(%a1), %d2
        cmp.b   V_NGH, %d2
        bne.s   5f
        move.b  2(%a1), %d2
        cmp.b   V_NGH + 1, %d2
        bne.s   5f
        move.b  #4, V_CONF              | déjà là : écraser ?
        bsr     .Lmsg_ecraser
        bra     .Lboucle
5:      addq.l  #4, %a1
        dbra    %d1, 3b
4:      clr.b   V_CONF                  | écrire
        move.b  #0x03, CMD              | SAUVEGARDER
        bsr     .Lc_interface
        jsr     _card
        bsr     .Lrendre
        moveq   #0, %d4
        move.b  REPONSE, %d4
        lea     .Ltxt_copie, %a2
        bra.s   .Lc_fin
.Lc_erreur:
        lea     .Ltxt_copie, %a2
.Lc_fin:
        movem.l %d4/%a2, -(%sp)         | la réponse et le message, que l'écran écrase
        bsr     .Lreleve
        bsr     .Lborner
        bsr     .Lecran
        movem.l (%sp)+, %d4/%a2
        tst.b   %d4
        beq.s   1f
        lea     .Ltxt_erreur, %a2       | CARD ERROR et la réponse
        lea     F_LIGNE(%a6), %a1
        moveq   #L_ERREUR - 1, %d0
2:      move.b  (%a2)+, (%a1)+
        dbra    %d0, 2b
        move.b  %d4, %d0
        bsr     .Lhex2
        clr.b   (%a1)
        lea     F_LIGNE(%a6), %a2
1:      bsr     .Lmessage
        bra     .Lboucle

| L'interface de CARD pour la copie : NGH, sous-sauvegarde, le tampon, la taille.
.Lc_interface:
        move.b  V_NGH, FCB
        move.b  V_NGH + 1, FCB + 1
        move.b  V_SUB, SUB
        move.l  #COPIE_RAM, START_C
        move.w  V_TAILLE, SIZE_C
        rts

| LE TAMPON MIS DE CÔTÉ en VRAM, puis rendu (voir l'en-tête). REG_VRAMMOD à 1 pour l'écriture, rendu
| à 32 ; une lecture par adresse, trois `nop` entre l'adresse et la donnée, comme `tests.s`.
| Clobbers %d0, %d1, %a1.
.Lmettre_de_cote:
        lea     COPIE_RAM, %a1
        move.w  #1, VRAMMOD
        move.w  #0x0000, VRAMADDR
        move.w  #COPIE_MOTS - 1, %d1
1:      move.w  (%a1)+, %d0
        move.w  %d0, (%a0)
        move.b  %d0, WATCHDOG
        dbra    %d1, 1b
        move.w  #32, VRAMMOD
        rts
.Lrendre:
        lea     COPIE_RAM, %a1
        moveq   #0, %d0
        move.w  #COPIE_MOTS - 1, %d1
1:      move.w  %d0, VRAMADDR
        nop
        nop
        nop
        move.w  (%a0), (%a1)+
        addq.w  #1, %d0
        move.b  %d0, WATCHDOG
        dbra    %d1, 1b
        rts

| OVERWRITE nnnn-ss? A:YES B:NO. Clobbers %d0-%d4, %a1-%a3.
.Lmsg_ecraser:
        lea     F_LIGNE(%a6), %a1
        lea     .Ltxt_ecraser, %a2
1:      move.b  (%a2)+, (%a1)+
        bne.s   1b
        subq.l  #1, %a1
        move.b  V_NGH, %d0
        bsr     .Lhex2
        move.b  V_NGH + 1, %d0
        bsr     .Lhex2
        move.b  #0x2D, (%a1)+           | « - »
        move.b  V_SUB, %d0
        bsr     .Ldecimal2
        lea     .Ltxt_oui_non, %a2
2:      move.b  (%a2)+, (%a1)+
        bne.s   2b
        lea     F_LIGNE(%a6), %a2
        bra     .Lmessage

| LA SORTIE : l'interface de CARD rendue, la RAM du gestionnaire à zéro, la palette 5 aussi.
.Lsortie:
        lea     GARDE, %a1
        move.b  (%a1)+, 0x10FCF4
        lea     0x10FD00, %a2
        moveq   #24 - 1, %d0
1:      move.b  (%a1)+, (%a2)+
        dbra    %d0, 1b
        lea     CMD, %a2
        moveq   #14 - 1, %d0
2:      move.b  (%a1)+, (%a2)+
        dbra    %d0, 2b
        lea     TAMPON, %a1
        move.w  #(RAM_FIN - TAMPON) / 4 - 1, %d0
3:      clr.l   (%a1)+
        dbra    %d0, 3b
        bsr     .Lsync
        lea     PALETTES + PAL_ALERTE * 32, %a1
        moveq   #16 - 1, %d0
4:      clr.w   (%a1)+
        dbra    %d0, 4b
        unlk    %a6
        movem.l (%sp)+, %d0-%d7/%a0-%a6
        rts

| ----------------------------------------------------------------------------------
| LE RELEVÉ : la carte lue (`_carte_releve`), l'état, le nombre de lignes. Clobbers %d0-%d2,
| %a1.
.Lreleve:
        move.b  STATUS_B, %d0
        andi.b  #0x70, %d0
        move.b  %d0, V_STB
        move.l  %a0, -(%sp)
        lea     TAMPON, %a0
        jsr     _carte_releve
        movea.l (%sp)+, %a0
        move.b  %d0, V_ETAT
        moveq   #2, %d1                 | FORMAT CARD et EXIT
        tst.b   %d0
        bne.s   2f
        lea     TAMPON, %a1
        moveq   #32 - 1, %d2
1:      cmpi.b  #0xFF, (%a1)
        beq.s   3f
        addq.w  #1, %d1
3:      addq.l  #4, %a1
        dbra    %d2, 1b
2:      move.w  %d1, V_N
        rts

| LE CURSEUR DANS LA LISTE, et la fenêtre qui le montre (%d6). Clobbers %d0.
.Lborner:
        move.w  V_N, %d0
        cmp.w   %d0, %d7
        bcs.s   1f
        move.w  %d0, %d7
        subq.w  #1, %d7
1:      cmp.w   %d6, %d7
        bcc.s   2f
        move.w  %d7, %d6                | au-dessus de la fenêtre
2:      move.w  %d7, %d0
        subi.w  #VISIBLES - 1, %d0
        bls.s   3f
        cmp.w   %d6, %d0
        bls.s   3f
        move.w  %d0, %d6                | au-dessous
3:      move.w  V_N, %d0
        subi.w  #VISIBLES, %d0
        bhi.s   4f
        moveq   #0, %d6                 | tout tient
        rts
4:      cmp.w   %d0, %d6
        bls.s   5f
        move.w  %d0, %d6                | pas de vide en bas
5:      rts

| L'ENTRÉE DU RÉPERTOIRE de la sauvegarde de la ligne %d0 : %a1 sur ses quatre octets dans le
| tampon (sous-sauvegarde, NGH, premier bloc). Clobbers %d0, %a1.
.Lentree:
        lea     TAMPON, %a1
1:      cmpi.b  #0xFF, (%a1)
        beq.s   2f
        subq.w  #1, %d0
        bmi.s   3f
2:      addq.l  #4, %a1
        bra.s   1b
3:      rts

| ----------------------------------------------------------------------------------
| L'ÉCRAN, tout entier : palettes après le passage de la ligne $1F0, FIX_CLEAR, titre, état,
| en-tête, liste, aide. Clobbers %d0-%d4, %a1-%a3.
.Lecran:
        bsr     .Lsync
        lea     PALETTES + PAL_ALERTE * 32, %a1
        clr.w   (%a1)+
        move.w  #C_ALERTE, (%a1)+
        moveq   #14 - 1, %d0
1:      clr.w   (%a1)+
        dbra    %d0, 1b
        jsr     _fix_clear
        move.w  #32, VRAMMOD            | une écriture = une colonne
        move.w  #CASE_TITRE, %d1
        lea     .Ltxt_titre, %a2
        moveq   #L_TITRE, %d4
        move.w  #0x3100, %d3
        bsr     .Lecrire
        move.w  #CASE_TITRE + 1, %d1
        lea     .Ltxt_titre, %a2
        moveq   #L_TITRE, %d4
        move.w  #0x3200, %d3
        bsr     .Lecrire
        | L'ÉTAT.
        move.b  V_ETAT, %d0
        lea     .Ltxt_sans, %a2
        cmpi.b  #0x80, %d0
        beq.s   3f
        lea     .Ltxt_non_formatee, %a2
        cmpi.b  #0x81, %d0
        beq.s   3f
        lea     .Ltxt_inconnue, %a2
        tst.b   %d0
        bne.s   3f
        lea     F_LIGNE(%a6), %a1       | FREE BLOCKS nn
        lea     .Ltxt_libres, %a2
2:      move.b  (%a2)+, (%a1)+
        bne.s   2b
        subq.l  #1, %a1
        bsr     .Llibres
        bsr     .Ldecimal2
        clr.b   (%a1)
        lea     F_LIGNE(%a6), %a2
        move.w  #0x1000, %d3
        bra.s   4f
3:      move.w  #(PAL_ALERTE << 12), %d3
4:      move.w  #CASE_ETAT, %d1
        bsr     .Lchaine
        cmpi.b  #0x80, V_ETAT
        beq.s   5f
        btst    #6, STATUS_B
        beq.s   5f
        move.w  #CASE_PROT, %d1
        lea     .Ltxt_protegee, %a2
        move.w  #(PAL_ALERTE << 12), %d3
        bsr     .Lchaine
5:      move.w  #CASE_ENTETE, %d1
        lea     .Ltxt_entete, %a2
        move.w  #0x3000, %d3
        bsr     .Lchaine
        move.w  #CASE_AIDE1, %d1
        lea     .Ltxt_aide1, %a2
        move.w  #0x4000, %d3
        bsr     .Lchaine
        move.w  #CASE_AIDE2, %d1
        lea     .Ltxt_aide2, %a2
        bsr     .Lchaine
        | puis la liste, en tombant

| LES LIGNES VISIBLES de la liste. Clobbers %d0-%d4, %a1-%a3.
.Lliste:
        moveq   #0, %d4
1:      move.w  %d4, -(%sp)
        bsr.s   .Lligne
        move.w  (%sp)+, %d4
        addq.w  #1, %d4
        cmpi.w  #VISIBLES, %d4
        bcs.s   1b
        rts

| LA LIGNE VISIBLE %d4 (0 à VISIBLES - 1), celle de l'élément %d6 + %d4 : composée dans le cadre,
| puis écrite sous la palette 2 si elle est choisie, 1 sinon. Clobbers %d0-%d4, %a1-%a3.
.Lligne:
        lea     F_LIGNE(%a6), %a1
        moveq   #LARGEUR - 1, %d0
1:      move.b  #0x20, (%a1)+
        dbra    %d0, 1b
        clr.b   (%a1)
        move.w  %d4, %d1
        addi.w  #0x7000 + 3 * 32 + LIGNE0, %d1
        move.w  %d1, -(%sp)             | la case
        move.w  #0x1000, -(%sp)         | la palette
        add.w   %d6, %d4                | l'élément
        cmp.w   V_N, %d4
        bcc     .Ll_ecrire              | au-delà : une ligne vide
        lea     F_LIGNE(%a6), %a1
        cmp.w   %d7, %d4
        bne.s   2f
        move.b  #0x3E, (%a1)            | « > »
        move.w  #0x2000, (%sp)
2:      addq.l  #2, %a1
        move.w  V_N, %d0
        subq.w  #1, %d0
        lea     .Ltxt_sortie, %a2
        cmp.w   %d0, %d4
        beq.s   3f
        subq.w  #1, %d0
        lea     .Ltxt_formater_l, %a2
        cmp.w   %d0, %d4
        beq.s   3f
        | Une sauvegarde : NGH, sous-sauvegarde, blocs, nom.
        move.w  %d4, %d0
        movea.l %a1, %a3
        bsr     .Lentree                | %a1 : l'entrée
        exg     %a1, %a3                | %a3 : l'entrée ; %a1 : la ligne
        move.b  1(%a3), %d0
        bsr     .Lhex2
        move.b  2(%a3), %d0
        bsr     .Lhex2
        addq.l  #1, %a1
        move.b  (%a3), %d0
        bsr     .Ldecimal2
        addq.l  #2, %a1
        bsr     .Lblocs
        bsr     .Ldecimal2
        addq.l  #2, %a1
        move.b  1(%a3), %d0             | le NGH, octet par octet : l'entrée est en +1
        lsl.w   #8, %d0
        move.b  2(%a3), %d0
        bsr     .Lnom                   | %a2 : le nom, ou 0
        move.l  %a2, %d0
        beq.s   .Ll_ecrire
        moveq   #16 - 1, %d0
4:      move.b  (%a2)+, (%a1)+
        dbra    %d0, 4b
        bra.s   .Ll_ecrire
3:      move.b  (%a2)+, (%a1)+          | FORMAT CARD, EXIT
        bne.s   3b
        move.b  #0x20, -1(%a1)
.Ll_ecrire:
        move.w  (%sp)+, %d3
        move.w  (%sp)+, %d1
        lea     F_LIGNE(%a6), %a2
        moveq   #LARGEUR, %d4
        bra     .Lecrire

| LES BLOCS de la sauvegarde %a3 : sa chaîne dans la FAT 1, du premier bloc jusqu'à $01. Un
| bloc hors de 5-31, ou plus de 27 tours (une FAT qui boucle), arrêtent le compte. → %d0.
| Clobbers %d1, %d2, %a2.
.Lblocs:
        moveq   #0, %d0
        moveq   #0, %d1
        move.b  3(%a3), %d1
        moveq   #27 - 1, %d2
1:      cmpi.w  #5, %d1
        bcs.s   2f
        cmpi.w  #32, %d1
        bcc.s   2f
        addq.w  #1, %d0
        lea     T_FAT, %a2
        move.b  (%a2,%d1.w), %d1
        cmpi.b  #1, %d1
        dbeq    %d2, 1b
2:      rts

| LES BLOCS LIBRES : les entrées $00 de la FAT 1, blocs 5 à 31. → %d0. Clobbers %d1, %a2.
.Llibres:
        moveq   #0, %d0
        lea     T_FAT + 5, %a2
        moveq   #27 - 1, %d1
1:      tst.b   (%a2)+
        bne.s   2f
        addq.w  #1, %d0
2:      dbra    %d1, 1b
        rts

| LE NOM DU JEU de NGH %d0.w, s'il est inscrit dans la table des slots : %a2 sur ses 16 octets
| en backup RAM, 0 sinon. Clobbers %d1, %d2.
.Lnom:
        suba.l  %a2, %a2
        tst.w   %d0
        beq.s   9f
        lea     0xD00124, %a2
        moveq   #8 - 1, %d2
1:      cmp.w   (%a2), %d0
        bne.s   2f
        move.w  2(%a2), %d1
        cmpi.w  #8, %d1
        bcs.s   3f
2:      addq.l  #4, %a2
        dbra    %d2, 1b
        suba.l  %a2, %a2
9:      rts
3:      lsl.w   #4, %d1
        lea     0xD002A0, %a2
        adda.w  %d1, %a2
        rts

| ----------------------------------------------------------------------------------
| LES MESSAGES, ligne 24, sous la palette 5 : la chaîne %a2 (terminée par 0), la ligne
| effacée d'abord. Clobbers %d0-%d4, %a1, %a2.
.Lmessage:
        move.l  %a2, -(%sp)
        move.w  #CASE_MSG, %d1
        lea     .Ltxt_vide, %a2
        moveq   #LARGEUR, %d4
        moveq   #0, %d3
        bsr     .Lecrire
        movea.l (%sp)+, %a2
        move.w  #CASE_MSG, %d1
        move.w  #(PAL_ALERTE << 12), %d3
        bra     .Lchaine

| DELETE nnnn-ss? : la sauvegarde de la ligne %d7. Clobbers %d0-%d4, %a1-%a3.
.Lmsg_effacer:
        move.w  %d7, %d0
        bsr     .Lentree
        movea.l %a1, %a3
        lea     F_LIGNE(%a6), %a1
        lea     .Ltxt_effacer, %a2
1:      move.b  (%a2)+, (%a1)+
        bne.s   1b
        subq.l  #1, %a1
        move.b  1(%a3), %d0
        bsr     .Lhex2
        move.b  2(%a3), %d0
        bsr     .Lhex2
        move.b  #0x2D, (%a1)+           | « - »
        move.b  (%a3), %d0
        bsr     .Ldecimal2
        lea     .Ltxt_oui_non, %a2
2:      move.b  (%a2)+, (%a1)+
        bne.s   2b
        lea     F_LIGNE(%a6), %a2
        bra.s   .Lmessage

| DEUX CHIFFRES HEXADÉCIMAUX de %d0.b à (%a1)+. Clobbers %d0, %d1.
.Lhex2:
        move.b  %d0, %d1
        lsr.b   #4, %d0
        bsr.s   1f
        move.b  %d1, %d0
1:      andi.w  #0x0F, %d0
        addi.b  #0x30, %d0
        cmpi.b  #0x39, %d0
        bls.s   2f
        addq.b  #7, %d0
2:      move.b  %d0, (%a1)+
        rts

| DEUX CHIFFRES DÉCIMAUX de %d0 (0 à 99) à (%a1)+. Clobbers %d0.
.Ldecimal2:
        andi.l  #0xFF, %d0
        divu    #10, %d0
        addi.b  #0x30, %d0
        move.b  %d0, (%a1)+
        swap    %d0
        addi.b  #0x30, %d0
        move.b  %d0, (%a1)+
        rts

| ----------------------------------------------------------------------------------
| UNE CHAÎNE terminée par 0 à partir de la case %d1, sous %d3, REG_VRAMMOD à 32. Clobbers %d2,
| %d4, %a1, %a2.
.Lchaine:
        movea.l %a2, %a1
        moveq   #-1, %d4
1:      addq.w  #1, %d4
        tst.b   (%a1)+
        bne.s   1b
        tst.w   %d4
        beq.s   2f
| ÉCRIRE %d4 caractères de %a2 à partir de la case %d1, comme `dip.s`. Hors de $20-$7E, une
| espace. Clobbers %d2, %d4, %a2.
.Lecrire:
        move.w  %d1, VRAMADDR
        subq.w  #1, %d4
1:      moveq   #0, %d2
        move.b  (%a2)+, %d2
        cmpi.b  #0x20, %d2
        bcs.s   3f
        cmpi.b  #0x7E, %d2
        bls.s   4f
3:      moveq   #0x20, %d2
4:      add.w   %d3, %d2
        move.w  %d2, (%a0)
        dbra    %d4, 1b
2:      rts

| LES BOUTONS. Bits : 0 haut, 1 bas, 2 gauche, 3 droite, 4 A, 5 B, 6 START, 7 C (la copie). %d5
| l'état d'avant, mis à jour ; %d0 les fronts. Clobbers %d1, %d2.
.Lentrees:
        move.b  P1CNT, %d2
        not.b   %d2
        move.b  %d2, %d1
        andi.b  #0x40, %d1              | C, bit 6 de REG_P1CNT
        add.b   %d1, %d1                | au bit 7
        andi.b  #0x3F, %d2
        or.b    %d1, %d2
        move.b  STATUS_B, %d1
        not.b   %d1
        andi.b  #0x01, %d1
        lsl.b   #6, %d1
        or.b    %d1, %d2
        move.b  %d5, %d0
        not.b   %d0
        and.b   %d2, %d0
        move.b  %d2, %d5
        rts

| LE PASSAGE DE LA LIGNE $1F0, comme `dip.s` ; watchdog à chaque tour. Clobbers %d0.
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

| ----------------------------------------------------------------------------------
| LES DONNÉES.
        .balign 2
.Ltxt_titre:
        .ascii  "MEMORY CARD"
        .equ    L_TITRE, . - .Ltxt_titre
.Ltxt_erreur:
        .ascii  "CARD ERROR "
        .equ    L_ERREUR, . - .Ltxt_erreur
.Ltxt_sans:             .asciz  "NO CARD"
.Ltxt_non_formatee:     .asciz  "CARD NOT FORMATTED"
.Ltxt_inconnue:         .asciz  "UNSUPPORTED CARD"
.Ltxt_libres:           .asciz  "FREE BLOCKS "
.Ltxt_protegee:         .asciz  "WRITE PROTECTED"
.Ltxt_entete:           .asciz  "  NGH  SUB BLK GAME"
.Ltxt_formater_l:       .asciz  "FORMAT CARD"
.Ltxt_sortie:           .asciz  "EXIT"
.Ltxt_formater:         .asciz  "FORMAT CARD? A:YES B:NO"
.Ltxt_effacer:          .asciz  "DELETE "
.Ltxt_oui_non:          .asciz  "? A:YES B:NO"
.Ltxt_efface:           .asciz  "DELETED"
.Ltxt_formate:          .asciz  "FORMATTED"
.Ltxt_renonce:          .asciz  "CANCELLED"
.Ltxt_aide1:            .asciz  "UP/DOWN  A:DELETE/FORMAT C:COPY"
.Ltxt_changer:          .asciz  "CHANGE CARD AND PRESS A  B:NO"
.Ltxt_ecraser:          .asciz  "OVERWRITE "
.Ltxt_copie:            .asciz  "COPIED"
.Ltxt_aide2:            .asciz  "START:BACK"
.Ltxt_vide:             .ascii  "                                "
        .balign 2
