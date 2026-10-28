| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| LES RÉGLAGES DU BIOS EN BACKUP RAM — la région, le mode MVS / AES depuis le 2026-10-23,
| SCORE RESET (la date gelée pour les jeux, `cal.s`) depuis le 2026-10-24, et les réglages de la
| borne (FREE PLAY, NO CONTINUE, DEMO SOUND, sous-écran CABINET SETTINGS de `dip.s`) depuis le
| 2026-10-25, CHEATS/DEBUG compris (le même jour, `cheats.s`, `menu.s`).
|
| La remise est « Couche 3 → la région à chaud et la sauvegarde des réglages du BIOS, le
| 2026-10-20 » (`docs/RELECTURE-CONTRATS.md`). « mesuré » : un relevé nommé ; « lu dans » :
| une page du NeoGeo Development Wiki ; « SUPPOSÉ » : ni l'un ni l'autre.
|
| L'EMPLACEMENT : $D00210-$D0021F, seize octets juste sous les blocs soft-DIP ($D00220).
| Lu dans « Backup RAM » : $D001A8-$D0021F n'y est pas documenté ; la page n'y place ni
| cellule ni table. Hors de tout ce que notre code écrit : `_bram_vider` s'arrête à
| $D0007F, la table des emplacements est $D00124-$D00143, les blocs soft-DIP partent de
| $D00220, `io.s` et `card.s` restent sous $D00060. Mesuré sous MAME le 2026-10-20, notre
| image sans réglage, tap d'écriture sur $D00000-$D0FFFF (`bench/bram-ecrivains.lua`),
| ~3 700 trames de pièces et de START sur 21 jeux du corpus (garou : MAME segfault avant
| le relevé) : aucune écriture, ni du jeu ni du BIOS, dans $D00150-$D0021F. Les jeux
| n'écrivent qu'à partir de $D00320 (kof98, mslug3), leurs blocs.
|   SUPPOSÉ : qu'aucun autre jeu du catalogue n'y écrive, et que le BIOS de référence
|   n'y range rien qu'un passage par lui sur la même NVRAM laisserait — la signature
|   et la somme ci-dessous font retomber sur le descripteur dans ce cas.
|
| LE FORMAT, à nous :
|   $D00210-$D00215  « REBIOS », la signature
|   $D00216          la région : 0 Japon, 1 USA, 2 Europe (« BIOS RAM locations »,
|                    BIOS_COUNTRY_CODE)
|   $D00217          le mode : 1 MVS, 2 AES ; 0, la valeur d'un bloc d'avant ce réglage, et
|                    toute autre valeur : pas de réglage, le descripteur $C00400 reste
|   $D00218          SCORE RESET : 0 ON, les jeux lisent la vraie date ; 1 OFF, ils lisent la
|                    date gelée qui suit ; toute autre valeur vaut ON
|   $D00219-$D0021C  la date gelée : année, mois, jour (BCD), jour de semaine — la date de
|                    l'horloge quand SCORE RESET est passé à OFF ; à zéro sinon
|   $D0021D          la borne, un bit par réglage : 0 FREE PLAY, 1 NO CONTINUE, 2 DEMO SOUND
|                    OFF, 3 CHEATS/DEBUG OFF ; les autres bits à zéro, ignorés. Zéro dans un bloc
|                    d'avant ces réglages : tout à leur défaut, CHEATS/DEBUG à ON compris
|   $D0021E          réservé aux réglages à venir, écrit à zéro
|   $D0021F          le contrôle : la somme des octets $D00216-$D0021F vaut $FF
| Valide : signature, contrôle, et une région de 0 à 2. Sinon on retombe sur le descripteur
| ($C00401 pour la région, $C00400 pour le mode). Un réglage à venir prendra un octet
| réservé, et devra être recopié tel quel par tout écrivain du bloc : `.Lecrire` relit le
| bloc avant de réécrire la somme.
|
| LE MODE N'EST PAS LA MACHINE. Il dit ce que BIOS_MVS_FLAG ($10FD82) annonce aux jeux
| (« BIOS RAM locations » : « System type. 0:AES, 0x80:MVS ») ; la carte reste un MVS, que le
| matériel dit lui-même (REG_STATUS_B bit 7, lu par `ecran.s` et `menu.s`). Le mode AES sur
| carte MVS est l'écart voulu de `docs/DECISIONS.md` §11.
| ==================================================================================

        .section .haut, "ax"
        .global _reglages_region
        .global _reglages_mode
        .global _reglages_ecrire_region
        .global _reglages_ecrire_mode
        .global _reglages_scores
        .global _reglages_ecrire_scores
        .global _reglages_borne
        .global _reglages_ecrire_borne
        .global _borne_remise

        .equ    BLOC,     0xD00210
        .equ    REGION,   0xD00216
        .equ    MODE,     0xD00217
        .equ    SCORES,   0xD00218
        .equ    GEL,      0xD00219
        .equ    BORNE_BR, 0xD0021D
        .equ    CONTROLE, 0xD0021F

| LA RÉGION DES RÉGLAGES. Sortie : %d0.b la région (0-2) si le bloc est valide, $FF sinon.
| Lecture seule : la backup RAM se lit verrouillée (REG_SRAMLOCK ne protège que
| l'écriture, lu dans « Memory mapped registers »). Clobbers %d0, %d1, %a0, %a1.
_reglages_region:
        bsr.s   .Lvalide
        bne.s   .Linvalide
        move.b  REGION, %d0
        rts
.Linvalide:
        moveq   #-1, %d0
        rts

| LE MODE DES RÉGLAGES. Sortie : %d0.b la valeur de BIOS_MVS_FLAG qu'il demande, $80 (MVS)
| ou $00 (AES), et $FF sans réglage. Lecture seule. Clobbers %d0, %d1, %a0, %a1.
_reglages_mode:
        bsr.s   .Lvalide
        bne.s   .Linvalide
        move.b  MODE, %d0
        subq.b  #1, %d0
        beq.s   1f                      | 1 : MVS
        subq.b  #1, %d0
        bne.s   .Linvalide              | ni 1 ni 2 : pas de réglage
        rts                             | 2 : AES, %d0 = $00
1:      move.b  #0x80, %d0
        rts

| SCORE RESET. Sortie : %d0.b 1 si le bloc est valide et la date des jeux gelée (OFF), 0
| sinon. Lecture seule. Clobbers %d0, %d1, %a0, %a1.
_reglages_scores:
        bsr.s   .Lvalide
        bne.s   1f
        cmpi.b  #1, SCORES
        bne.s   1f
        moveq   #1, %d0
        rts
1:      moveq   #0, %d0
        rts

| LE BLOC EST-IL VALIDE ? Z à 1 si la signature, le contrôle et la région le sont.
| Clobbers %d0, %d1, %a0, %a1.
.Lvalide:
        lea     BLOC, %a0
        lea     .Lsignature, %a1
        moveq   #6-1, %d1
1:      cmpm.b  (%a1)+, (%a0)+
        dbne    %d1, 1b
        bne.s   9f
        moveq   #0, %d0                 | %a0 est sur $D00216 : la somme des dix octets
        moveq   #10-1, %d1
2:      add.b   (%a0)+, %d0
        dbra    %d1, 2b
        cmpi.b  #0xFF, %d0
        bne.s   9f
        cmpi.b  #2, REGION
        bhi.s   9f
        moveq   #0, %d0                 | Z = 1
        rts
9:      moveq   #-1, %d0                | Z = 0
        rts

| ÉCRIRE LA RÉGION %d0.b (0-2), le mode du bloc gardé s'il est valide. La backup RAM doit être
| déverrouillée par l'appelant. Clobbers %d0-%d3, %a0, %a1.
_reglages_ecrire_region:
        move.b  %d0, %d2
        moveq   #0, %d3                 | bloc invalide : pas de mode
        bsr.s   .Lvalide
        bne.s   .Lecrire
        move.b  MODE, %d3
        bra.s   .Lecrire

| ÉCRIRE LE MODE %d0.b (1 MVS, 2 AES), la région du bloc gardée s'il est valide, sinon la
| région en cours (BIOS_COUNTRY_CODE, celle du descripteur : sans bloc valide, `c0.s` n'en
| a pas posé d'autre). Déverrouillée par l'appelant. Clobbers %d0-%d3, %a0, %a1.
_reglages_ecrire_mode:
        move.b  %d0, %d3
        move.b  0x10FD83, %d2
        bsr.s   .Lvalide
        bne.s   1f
        move.b  REGION, %d2
1:      cmpi.b  #2, %d2
        bls.s   .Lecrire
        moveq   #2, %d2                 | hors de 0-2 : l'Europe, comme `c0.s`
| LE BLOC RÉÉCRIT : %d2 la région, %d3 le mode. Bloc valide : les octets réservés sont gardés ;
| sinon ils partent à zéro. La signature en dernier, comme `c0.s` pour la sienne : un reset
| au milieu laisse un bloc invalide.
.Lecrire:
        bsr.s   .Lvalide
        lea     BLOC, %a0
        beq.s   1f
        clr.l   4(%a0)                  | invalide : tout à zéro ; $D00210-13 juste après
        clr.l   8(%a0)
        clr.l   12(%a0)
1:      clr.l   (%a0)                   | la signature d'abord détruite
        move.b  %d2, REGION
        move.b  %d3, MODE
| LE BLOC SCELLÉ, %a0 sur BLOC et la signature détruite : la somme, puis la signature.
.Lsceller:
        moveq   #0, %d1                 | la somme des octets $D00216-$D0021E
        lea     REGION, %a1
        moveq   #9-1, %d2
2:      add.b   (%a1)+, %d1
        dbra    %d2, 2b
        not.b   %d1                     | avec le contrôle, la somme vaut $FF
        move.b  %d1, CONTROLE
        lea     .Lsignature, %a1
        moveq   #6-1, %d2
3:      move.b  (%a1)+, (%a0)+
        dbra    %d2, 3b
        rts

| ÉCRIRE SCORE RESET %d0.b (0 ON, 1 OFF) ; à OFF, la date du moment ($10FDD2-$10FDD5, que
| l'appelant vient de lire par `_read_calendar`) devient la date gelée. Bloc valide : région et
| mode gardés ; sinon un bloc neuf, la région en cours (BIOS_COUNTRY_CODE) et pas de mode. La
| signature détruite d'abord, comme `.Lecrire`. Déverrouillée par l'appelant. Clobbers %d0-%d3,
| %a0-%a2.
_reglages_ecrire_scores:
        move.b  %d0, -(%sp)
        bsr     .Lvalide
        beq.s   1f
        move.b  0x10FD83, %d2
        cmpi.b  #2, %d2
        bls.s   2f
        moveq   #2, %d2                 | hors de 0-2 : l'Europe, comme `c0.s`
2:      moveq   #0, %d3
        bsr     .Lecrire                | un bloc neuf, valide
1:      lea     BLOC, %a0
        clr.l   (%a0)                   | la signature d'abord détruite
        move.b  (%sp)+, %d0
        move.b  %d0, SCORES
        lea     GEL, %a1
        lea     0x10FDD2, %a2
        moveq   #4 - 1, %d1
3:      moveq   #0, %d2
        tst.b   %d0
        beq.s   4f
        move.b  (%a2), %d2              | à OFF : la date du moment
4:      move.b  %d2, (%a1)+
        addq.l  #1, %a2
        dbra    %d1, 3b
        bra     .Lsceller

| ----------------------------------------------------------------------------------
| LA BORNE — FREE PLAY, NO CONTINUE, DEMO SOUND (le sous-écran CABINET SETTINGS de `dip.s`).
| Mesures : `measured/2026-10-25-free-play.tsv` ; écarts : `docs/DECISIONS.md` §15.
|
| LA COPIE EN RAM, BORNE ($10FB20, .b) : ce que `io.s` lit à chaque START et à chaque refus de
| CREDIT_CHECK, sans revalider le bloc. Dans la zone mesurée libre de `menu.s` ($10F4B4-$10FBFF :
| aucun jeu n'y écrit), au-dessus de l'éditeur mémoire ($10FB1C-$10FB1F) ; remise à zéro par le
| vidage du boot, puis posée ici. Bits :
|   0 FREE PLAY, 1 NO CONTINUE, 2 DEMO SOUND OFF — ceux du bloc, mais à zéro en mode AES ;
|   3 CHEATS/DEBUG OFF — celui du bloc, dans les deux modes : le menu en jeu existe aussi en AES ;
|   7 CREDIT_CHECK ne refuse aucune demande : le mode AES (DECISIONS §11, point 10) ou FREE PLAY.
| EN MODE AES, LES TROIS SONT INERTES. FREE PLAY : START y part déjà sans crédit et la pièce est
| ignorée (D2). NO CONTINUE : il n'y a pas de continue payant. DEMO SOUND : mesuré le 2026-10-25,
| aof en mode AES joue le son de sa démo avec $D00046 à 1 comme à 0 (RMS 2 688 dans les deux cas,
| relevé ci-dessus) — le jeu ne lit pas la cellule en AES.
        .equ    BORNE,    0x10FB20

| LA BORNE DES RÉGLAGES. Sortie : %d0.b les bits du bloc s'il est valide (bits 0-3), 0 sinon.
| Lecture seule. Clobbers %d0, %d1, %a0, %a1.
_reglages_borne:
        bsr     .Lvalide
        bne.s   1f
        moveq   #0x0F, %d0
        and.b   BORNE_BR, %d0
        rts
1:      moveq   #0, %d0
        rts

| LA COPIE EN RAM POSÉE (voir plus haut), d'après le bloc et BIOS_MVS_FLAG ($10FD82) : au boot, après
| le mode (`c0.s`), et à la sortie de l'éditeur (`dip.s`). Rend tous les registres.
        .global _borne_ram
_borne_ram:
        movem.l %d0-%d1/%a0-%a1, -(%sp)
        bsr.s   _reglages_borne
        tst.b   0x10FD82
        bmi.s   1f
        andi.b  #0x08, %d0              | mode AES : les trois inertes, CHEATS/DEBUG gardé
1:      btst    #0, %d0
        bne.s   2f
        tst.b   0x10FD82
        bmi.s   3f
2:      bset    #7, %d0                 | FREE PLAY ou AES : CREDIT_CHECK ne refuse rien
3:      move.b  %d0, BORNE
        movem.l (%sp)+, %d0-%d1/%a0-%a1
        rts

| ÉCRIRE LA BORNE %d0.b (bits 0-3) ; région, mode et SCORE RESET gardés si le bloc est valide,
| sinon un bloc neuf, comme `_reglages_ecrire_scores`. Déverrouillée par l'appelant. Clobbers
| %d0-%d3, %a0, %a1.
_reglages_ecrire_borne:
        move.b  %d0, -(%sp)
        bsr     .Lvalide
        beq.s   1f
        move.b  0x10FD83, %d2
        cmpi.b  #2, %d2
        bls.s   2f
        moveq   #2, %d2                 | hors de 0-2 : l'Europe, comme `c0.s`
2:      moveq   #0, %d3
        bsr     .Lecrire                | un bloc neuf, valide
1:      lea     BLOC, %a0
        clr.l   (%a0)                   | la signature d'abord détruite
        move.b  (%sp)+, %d0
        andi.b  #0x0F, %d0
        move.b  %d0, BORNE_BR
        bra     .Lsceller

| DEMO SOUND À LA REMISE — appelé par les deux remises de la main au jeu (`_logo_aes`, `c0.s`),
| %d2 la demande. « Backup RAM » (NeoGeo Development Wiki) : $D00046 « Demo sound (1=Without) »,
| et SOUND_STOP, « No sound at all if non-zero (except coinage sound effect) ». Ce sont les jeux qui
| la lisent : mesuré le 2026-10-25 (`measured/2026-10-25-free-play.tsv`, section 3), douze jeux
| sur douze muets en démo sous notre image comme sous le BIOS SNK avec $D00046 à 1, le son de la
| pièce gardé ; le titre d'après la pièce aussi muet (aof : RMS 618, la pièce seule, contre 2 143),
| et la partie non (RMS égaux à 1 % près). Le BIOS SNK laisse la cellule à 1 tout du long ; ici
| elle ne vaut 1 qu'à une remise de DÉMO (demande 2) avec DEMO SOUND OFF, 0 à toute autre : le
| titre d'après une pièce retrouve sa musique (aof, cellule remise à 0 à la pièce : RMS 2 125,
| 88 key-on, comme sans le réglage). Écart voulu, DECISIONS §15. La cellule n'est écrite que si
| elle change : avec DEMO SOUND ON et une cellule à 0, une lecture et rien d'autre. Rend tous les
| registres ; la backup RAM est rendue verrouillée.
_borne_remise:
        move.l  %d0, -(%sp)
        moveq   #0, %d0
        cmpi.b  #2, %d2
        bne.s   1f                      | pas une démo : le son
        btst    #2, BORNE
        beq.s   1f                      | DEMO SOUND ON (ou mode AES)
        moveq   #1, %d0                 | « 1=Without »
1:      cmp.b   0xD00046, %d0
        beq.s   9f
        move.b  %d0, 0x3A001D           | REG_SRAMUNLOCK
        move.b  %d0, 0xD00046
        move.b  %d0, 0x3A000D           | REG_SRAMLOCK
9:      move.l  (%sp)+, %d0
        rts

.Lsignature:
        .ascii  "REBIOS"
        .balign 2
