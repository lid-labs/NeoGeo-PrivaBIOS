| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| LES CHEATS — une table par jeu, un moteur qui écrit en RAM de travail les valeurs des
| cheats actifs à chaque appel de SYSTEM_IO, et leurs lignes dans le menu en jeu (`menu.s`).
|
| AUCUN ORACLE : ni le BIOS de référence, ni un BIOS tiers, ni une base de cheats tierce
| (celle d'UniBIOS, le cheat.xml de MAME, un site de codes) ne sont lus. La remise est
| « Couche 3 → les cheats, le 2026-10-21 » (`docs/RELECTURE-CONTRATS.md`).
| « mesuré » : jig `bench/cheats.lua` sous MAME 0.286, -bios euro, -video none, notre image,
| le 2026-10-21 (relevés remis à l'agent coordinateur) ; « lu dans » : une page du NeoGeo
| Development Wiki ; « SUPPOSÉ » : ni l'un ni l'autre.
|
| LE FORMAT DE LA TABLE, `_cheats_table`, des mots big-endian :
|   par jeu, la macro JEU : NGH (.w), EMPREINTE (.w), NOMBRE de cheats (.w, 1 à CH_MAX),
|   puis NOMBRE fiches de FICHE = 32 octets, la macro CHEAT :
|     +0   le nom, 16 caractères ASCII complétés d'espaces ;
|     +16  deux écritures de 8 octets : adresse (.l, $100000-$10F2FF), taille (.w : 1 octet,
|          2 mot, 0 pas d'écriture), valeur (.w ; l'octet bas pour une taille 1).
|   La table finit par un NGH nul. Les gardes de la macro refusent au lien une adresse hors de
|   la RAM de travail du jeu, un mot à une adresse impaire, un nom de plus de 16 caractères.
|
| L'IDENTIFICATION, à chaque ouverture du menu (`_cheats_trouver`) — c'est là seulement que la
| table sert, puisqu'aucun cheat n'est actif avant d'avoir été choisi dans le menu. NGH : le mot
| $000108, « 68k program header ». EMPREINTE : la somme sur 16 bits des 64 mots $000100-$00017E
| de la P-ROM (le même en-tête : nom, NGH, tailles, pointeurs, les sauts USER, PLAYER_START,
| DEMO_END, COIN_SOUND). Hors des 128 premiers octets que REG_SWPBIOS échange (« Memory mapped
| registers »), et dans la P-ROM fixe : lue telle que le jeu la voit. SUPPOSÉ : qu'une autre
| révision du même NGH déplace au moins un de ces pointeurs ; aucune n'est dans le corpus, et
| mesuré seulement que les 21 jeux qui bootent ont des couples NGH/EMPREINTE distincts, puis les
| 32 du catalogue du 2026-10-25, dont les NGH le sont déjà (`measured/2026-10-25-cheats-table.tsv`).
|
| LES ÉTATS, $10FB00-$10FB07 : CH_ENTREE (.l, la première fiche du jeu, 0 sans entrée), CH_NB
| (.w), CH_ETATS (.w, un bit par cheat, bit 0 = la première fiche). Zone mesurée libre : des taps
| d'écriture sur 22 jeux ne montrent aucune écriture de jeu entre $10F4B4 et $10FBFF
| (`measured/2026-10-21-ecrivains-ram-bios.tsv`) ; le menu prend $10F4C0-$10F7FF et
| $10F800-$10FAFF, sa pile descend de $10FB00 exclu. Le vidage du boot (`c0.s`) les met à zéro :
| perdus à la relance, comme le veut la remise (mesuré : RESTART GAME avec un cheat actif,
| CH_ETATS à 0 après le reset, plus aucune écriture du moteur). Et perdus à chaque passage
| de slot (`_cheats_oublier`, appelé par `_passer_au_slot` de `c0.s`) : relevé de l'audit du
| 2026-10-21, ils survivaient sinon au changement de jeu.
|
| LE MOTEUR, `_cheats_appliquer`, appelé au début du crochet du menu (`menu.s`), donc à chaque
| appel de SYSTEM_IO. Aucun cheat actif : le `bsr`, un `tst.w` d'adresse absolue, un `beq` pris
| et le `rts`, rien d'écrit. Actifs, et en partie seulement (BIOS_USER_MODE
| $10FDAF = 2, « BIOS RAM locations ») : CH_ENTREE confronté à la table (la première fiche
| d'un jeu, sinon CH_ETATS remis à zéro), puis les écritures des fiches actives, et rien d'autre.
| Une écriture par trame suffit, mesuré pour chaque cheat de la table : le jeu peut décompter
| entre deux appels, la valeur revient à l'appel suivant (vblank, mesuré dans `menu.s`).
|
| LES GELS, le cheat personnalisé de l'éditeur mémoire (`memoire.s`), le 2026-10-23 : GL_MAX
| octets de la RAM de travail du jeu, chacun réécrit à sa valeur à chaque appel, par le même
| moteur et aux mêmes conditions (en partie seulement). GL_MASQUE (.w, un bit par gel), puis
| GL_MAX fiches de 4 octets : le décalage depuis $100000 (.w), la valeur (.b), un octet libre.
| BORNÉS à l'application même, pas seulement à la pose : un décalage de $F300 ou plus (la zone du
| BIOS, $10F300-$10FFFF, où vivent ces états et la sauvegarde du menu) n'est jamais écrit, et
| son bit est éteint — même garde que CH_ENTREE, rien ne protégeant cette RAM d'un jeu. Le bit 15
| de GL_MASQUE est celui des DEBUG DIPS (`debug.s`, le 2026-10-25) : le moteur les pose à chaque appel,
| en démo comme en partie, par le même `tst.l` sans cheat ni gel ; les bits 0 à GL_MAX − 1 restent
| ceux des gels, dans l'octet bas que `memoire.s` lit. Zone
| $10FB08-$10FB1B, mesurée libre comme les états des cheats ; vidée au boot, et oubliée avec eux
| à chaque passage de slot.
|
| CHEATS/DEBUG OFF (sous-écran CABINET SETTINGS de `dip.s`, bit 3 de la copie BORNE_RAM, $10FB20,
| `reglages.s`), le 2026-10-25 : `_cheats_trouver` ne donne plus d'entrée (le menu n'a plus de
| ligne de cheat, `menu.s`), et le moteur, s'il trouve encore un cheat ou un gel actif, les éteint
| tous sans rien écrire. Ce test n'est que dans la branche des cheats actifs : sans cheat ni gel,
| le crochet garde son seul `tst.l` (DECISIONS §12, point 7).
| ==================================================================================

        .section .haut, "ax"
        .global _cheats_appliquer
        .global _cheats_trouver
        .global _cheats_oublier
        .global CH_ENTREE, CH_NB, CH_ETATS
        .global GL_MASQUE, GL_TABLE

        .equ    CH_ENTREE, 0x10FB00     | .l la première fiche du jeu ; 0 : pas d'entrée
        .equ    CH_NB,     0x10FB04     | .w nombre de cheats du jeu
        .equ    CH_ETATS,  0x10FB06     | .w un bit par cheat actif
        .equ    FICHE,     32
        | CH_MAX : un bit de CH_ETATS par cheat, donc 16. Le menu en montre MN_VIS à la fois et fait
        | défiler les autres (`menu.s`) ; CH_ETATS reste un mot, contigu à GL_MASQUE pour le `tst.l`.
        .equ    CH_MAX,    16
        .equ    GL_MASQUE, 0x10FB08     | .w un bit par gel actif ; CONTIGU à CH_ETATS (le `tst.l`)
        .equ    GL_TABLE,  0x10FB0A     | GL_MAX × (.w décalage, .b valeur, .b libre)
        .equ    GL_MAX,    4
        .equ    GL_BORNE,  0xF300       | $10F300 : la zone du BIOS, jamais écrite
        .equ    BORNE_RAM, 0x10FB20     | .b la borne en RAM (`reglages.s`) ; bit 3 : CHEATS/DEBUG OFF

| ----------------------------------------------------------------------------------
| LE MOTEUR. Ne détruit aucun registre, seulement les codes de condition.
_cheats_appliquer:
        | UN SEUL TEST sans cheat ni gel : CH_ETATS et GL_MASQUE, contigus, d'un `tst.l` (20 cycles
        | contre 16 au `tst.w` d'avant les gels). Mesuré (matrice, svc, le 2026-10-23,
        | `measured/2026-10-23-menu-en-jeu-complet.tsv`, section 3) : un `tst.w` de plus par appel
        | (deux instructions, 26 cycles) suffit à faire diverger la partie de svc, vifs 67805 au lieu
        | de 66944 ; le `tst.l` seul la laisse égale à main.
        tst.l   CH_ETATS
        beq.w   9f                      | .w : 10 cycles pris, comme .s (la cible est trop loin)
        btst    #3, BORNE_RAM           | CHEATS/DEBUG OFF : tout éteint, rien d'écrit
        bne.w   .Lcoupes
        tst.w   GL_MASQUE
        beq.s   1f
        bsr.s   .Lgels
1:      tst.w   CH_ETATS
        beq.s   9f
        cmpi.b  #2, 0x10FDAF            | en partie seulement
        bne.s   9f
        movem.l %d0-%d3/%a0-%a2, -(%sp)
        | CH_ENTREE VALIDÉ avant toute écriture : il doit être la première fiche d'un jeu de
        | `_cheats_table`, exactement là où `_cheats_trouver` le pose, et CH_ETATS ne garde que
        | les bits de ses fiches. SUPPOSÉ, garde : la RAM $10FB00-$10FB07 n'est écrite que par
        | ce fichier et `menu.s` (lu dans le code), mais rien ne la protège d'un jeu ; un
        | pointeur ou des bits quelconques feraient écrire des valeurs de la table n'importe où.
        | Hors de la table : CH_ETATS remis à zéro, rien d'écrit.
        move.l  CH_ENTREE, %d1
        lea     _cheats_table, %a0
6:      move.w  (%a0)+, %d2             | NGH ; 0 : fin de table
        beq.s   8f
        addq.l  #2, %a0                 | l'empreinte
        move.w  (%a0)+, %d2             | le nombre de fiches, 1 à CH_MAX
        cmpa.l  %d1, %a0
        beq.s   7f
        lsl.w   #5, %d2                 | × FICHE
        adda.w  %d2, %a0
        bra.s   6b
7:      moveq   #1, %d0                 | %d0 : CH_ETATS & (2^nombre - 1)
        lsl.w   %d2, %d0                | 16 : le mot passe à 0, et le masque à $FFFF
        subq.w  #1, %d0
        and.w   CH_ETATS, %d0
1:      lsr.w   #1, %d0                 | le bit de cette fiche dans X/C
        bcc.s   4f
        lea     16(%a0), %a1            | ses deux écritures
        moveq   #2 - 1, %d1
2:      movea.l (%a1)+, %a2
        move.w  (%a1)+, %d2             | taille
        move.w  (%a1)+, %d3             | valeur
        subq.w  #1, %d2
        bmi.s   4f                      | 0 : rien de plus pour cette fiche
        bne.s   3f
        move.b  %d3, (%a2)
        bra.s   5f
3:      move.w  %d3, (%a2)
5:      dbra    %d1, 2b
4:      lea     FICHE(%a0), %a0
        tst.w   %d0
        bne.s   1b
        bra.s   3f
8:      clr.w   CH_ETATS                | CH_ENTREE hors de la table
3:      movem.l (%sp)+, %d0-%d3/%a0-%a2
9:      rts
.Lcoupes:
        clr.l   CH_ETATS                | CH_ETATS et GL_MASQUE, contigus
        rts

| LES GELS (voir l'en-tête). Ne détruit aucun registre, seulement les codes de condition.
.Lgels:
        tst.w   GL_MASQUE               | bit 15 : les debug dips (`debug.s`), en démo comme en partie
        bpl.s   1f
        jsr     _dd_appliquer           | registres rendus
1:      cmpi.b  #2, 0x10FDAF            | en partie seulement
        bne.s   9f
        movem.l %d0-%d2/%a0-%a1, -(%sp)
        lea     GL_TABLE, %a0
        lea     0x100000, %a1
        moveq   #0, %d0                 | le gel
1:      btst    %d0, GL_MASQUE + 1
        beq.s   3f
        moveq   #0, %d1
        move.w  (%a0), %d1
        cmpi.l  #GL_BORNE, %d1
        bcs.s   2f
        bclr    %d0, GL_MASQUE + 1      | hors de la RAM du jeu : éteint, rien d'écrit
        bra.s   3f
2:      move.b  2(%a0), (%a1,%d1.l)
3:      addq.l  #4, %a0
        addq.w  #1, %d0
        cmpi.w  #GL_MAX, %d0
        bcs.s   1b
        andi.w  #0x8000 + (1 << GL_MAX) - 1, GL_MASQUE  | au-delà de GL_MAX : éteints, sauf le 15
        movem.l (%sp)+, %d0-%d2/%a0-%a1
9:      rts

| ----------------------------------------------------------------------------------
| L'IDENTIFICATION (voir l'en-tête). Pose CH_ENTREE et CH_NB ; sans entrée, 0 et 0, et
| CH_ETATS remis à zéro. CHEATS/DEBUG OFF : jamais d'entrée. Clobbers %d0-%d4, %a0.
_cheats_trouver:
        btst    #3, BORNE_RAM
        bne.s   8f
        lea     0x100, %a0
        moveq   #0, %d0
        moveq   #64 - 1, %d1
1:      add.w   (%a0)+, %d0
        dbra    %d1, 1b
        move.w  0x108, %d1              | NGH
        lea     _cheats_table, %a0
2:      move.w  (%a0)+, %d2
        beq.s   8f                      | fin de table
        move.w  (%a0)+, %d3
        move.w  (%a0)+, %d4
        cmp.w   %d1, %d2
        bne.s   3f
        cmp.w   %d0, %d3
        bne.s   3f
        move.l  %a0, CH_ENTREE
        move.w  %d4, CH_NB
        rts
3:      lsl.w   #5, %d4                 | × FICHE
        adda.w  %d4, %a0
        bra.s   2b
8:      clr.l   CH_ENTREE
        clr.w   CH_NB
        clr.w   CH_ETATS
        rts

| ----------------------------------------------------------------------------------
| L'OUBLI, à chaque passage de slot : aucune entrée, aucun cheat actif. Ne touche à aucun
| registre ; les codes de condition seuls.
_cheats_oublier:
        clr.l   CH_ENTREE
        clr.w   CH_NB
        clr.w   CH_ETATS
        clr.w   GL_MASQUE               | les gels du jeu qu'on quitte, et ses debug dips
        clr.w   DD_MASQUE               | (`debug.s`)
        rts

| ----------------------------------------------------------------------------------
| LA TABLE.
        | Les gardes sont écrites en différences (`.iflt`, `.ifgt`, `.ifne`) : une première écriture
        | en `(a < b) | (a > c)` laissait passer une adresse hors bornes (mesuré, image d'essai).
        | .Lch_attendu / .Lch_compte : les CHEAT annoncés par le dernier JEU, et ceux vus depuis.
        .set    .Lch_attendu, 0
        .set    .Lch_compte, 0

        .macro  COMPTE_JUSTE
        .ifne   .Lch_compte - .Lch_attendu
        .error  "JEU : le nombre annoncé n'est pas celui des CHEAT qui suivent"
        .endif
        .endm

        .macro  JEU ngh, empreinte, nombre
        COMPTE_JUSTE
        .ifeq   \ngh
        .error  "JEU : un NGH nul terminerait la table"
        .endif
        .iflt   \nombre - 1
        .error  "JEU : de 1 à CH_MAX cheats"
        .endif
        .ifgt   \nombre - CH_MAX
        .error  "JEU : de 1 à CH_MAX cheats"
        .endif
        .set    .Lch_attendu, \nombre
        .set    .Lch_compte, 0
        .word   \ngh, \empreinte, \nombre
        .endm

        .macro  FIN_TABLE
        COMPTE_JUSTE
        .word   0                       | fin de table
        .endm

        .macro  ECRITURE adr, taille, valeur
        .iflt   \taille
        .error  "CHEAT : taille 0, 1 ou 2"
        .endif
        .ifgt   \taille - 2
        .error  "CHEAT : taille 0, 1 ou 2"
        .endif
        .if     \taille
        .if     \adr < 0x100000
        .error  "CHEAT : adresse sous la RAM de travail du jeu"
        .endif
        .if     \adr >= 0x10F300
        .error  "CHEAT : adresse au-dessus de la RAM de travail du jeu"
        .endif
        .if     (\taille == 2) & (\adr & 1)
        .error  "CHEAT : un mot à une adresse impaire"
        .endif
        .endif
        .long   \adr
        .word   \taille, \valeur
        .endm

        .macro  CHEAT nom, a1, t1, v1, a2=0, t2=0, v2=0
.Lnom\@:
        .ascii  "\nom"
        .if     (. - .Lnom\@) > 16
        .error  "CHEAT : nom de plus de 16 caractères"
        .endif
        .fill   16 - (. - .Lnom\@), 1, 0x20
        ECRITURE \a1, \t1, \v1
        ECRITURE \a2, \t2, \v2
        .set    .Lch_compte, .Lch_compte + 1
        .endm

| LES CHEATS, tous mesurés (jig `bench/cheats.lua`, modes `releve` puis `forcer` : la cellule
| trouvée par filtrage de relevés de RAM sur une partie aux entrées planifiées, puis forcée par
| lua à chaque trame, l'effet constaté à l'écran et sur le cours de la partie). Relevés de la
| recherche remis à l'agent coordinateur.
        | SA SECTION, `.cheats`, liée au bout de la zone haute (`build/bios.ld`) : au milieu du code,
        | la table qui grandit repoussait `_mess_out` hors de portée du `bsr.w` de `int1.s` (mesuré
        | le 2026-10-29, « relocation truncated to fit » avec neuf cheats de plus). Lue par `lea`
        | absolu et par CH_ENTREE, elle peut être n'importe où dans l'image.
        .section .cheats, "a"
        .balign 2
_cheats_table:
        | METAL SLUG. Mesuré : vies $100377 (−1 à chaque mort ; forcé à 3, aucune fin de partie
        | en 11 morts, le témoin finit à la 4e — BIOS_GAME_DIP posé par lua à 3 vies, voir
        | ci-dessous) ; bombes $1004C0 (−1 par grenade, 10 à chaque vie ; forcé, BOMB reste 10) ;
        | temps de la mission $106E93 (secondes, binaire, 60 au départ ; forcé, 60 à l'écran
        | 5 400 trames durant). Sous notre image, son bloc soft-DIP ($2783D0) est hors de la
        | P-ROM fixe et `c0.s` le refuse : GAME_DIP reste à zéro, la partie part à 0 vie et le
        | compteur passe de 0 à $FF à la première mort, sans fin de partie (mesuré).
        JEU     0x0201, 0x33C2, 3
        CHEAT   "INFINITE LIVES",  0x100377, 1, 0x03
        CHEAT   "INFINITE BOMBS",  0x1004C0, 1, 0x0A
        CHEAT   "INFINITE TIME",   0x106E93, 1, 0x3C
        | ART OF FIGHTING. Mesuré : secondes du round $108406 (BCD, $60 au départ ; forcé, 60 à
        | l'écran, et la partie finit comme le témoin) ; vie de P1 $1092CD ($60 au départ, 0 au
        | KO ; forcée, jauge pleine, aucune fin de partie en 8 000 trames, le témoin finit à 6 079).
        JEU     0x0044, 0x42B6, 2
        CHEAT   "INFINITE TIME",   0x108406, 1, 0x60
        CHEAT   "P1 INFINITE LIFE", 0x1092CD, 1, 0x60
        | THE KING OF FIGHTERS '94. Mesuré : le décompte de trames de la seconde $10882F (50 → 0,
        | puis −1 aux secondes $10882E) ; forcé à 50, TIME reste 60 et le décompte de fin de
        | round, qui écrit $10882E sans passer par lui, se déroule. Forcer $10882E lui-même gèle
        | le jeu au KO (mesuré : jauge vide, plus rien ne suit). Vie de P1 $108221 ($CF au départ ;
        | forcée, jauge pleine, aucune fin de partie en 9 000 trames, le témoin finit à 8 466).
        JEU     0x0055, 0x4489, 2
        CHEAT   "INFINITE TIME",   0x10882F, 1, 0x32
        CHEAT   "P1 INFINITE LIFE", 0x108221, 1, 0xCF
        | LE CATALOGUE DU 2026-10-25 : un cheat ou deux par jeu, chacun trouvé et prouvé comme ceux du
        | dessus (relevé autonome `measured/2026-10-25-cheats-table.tsv` : méthode, mesure, effet vu
        | à l'écran, jig ; la recherche, `2026-10-25-cheats-recherche.tsv`), et activé par le menu en
        | jeu sous `bench/cheats-catalogue.sh`. INFINITE TIME : le chronomètre affiché ne descend plus,
        | et le round se finit encore par KO. INFINITE LIVES : plus de fin de partie.
        | THE KING OF FIGHTERS '95 : comme kof94, le décompte de trames de la seconde ($32 à 0) à côté
        | des secondes $10A836 (BCD), qu'on ne force pas (forcées, le round ne démarre plus) ; vie de
        | P1 $CF au début du round.
        JEU     0x0084, 0x0A7E, 2
        CHEAT   "INFINITE TIME",   0x10A837, 1, 0x32
        CHEAT   "P1 INFINITE LIFE", 0x108221, 1, 0xCF
        | THE KING OF FIGHTERS '99 : le décompte de trames de la seconde, secondes en $10A7E6.
        | Le 2026-10-29 : $108422, les dégâts subis par P1 (0 au round, montent aux coups ; forcé à 0).
        JEU     0x0251, 0xB157, 2
        CHEAT   "INFINITE TIME",   0x10A7E7, 1, 0x32
        CHEAT   "P1 INFINITE LIFE", 0x108422, 1, 0x00
        | THE KING OF FIGHTERS 2000 : les secondes, BCD.
        JEU     0x0257, 0xE65C, 1
        CHEAT   "INFINITE TIME",   0x10A7E6, 1, 0x60
        | THE KING OF FIGHTERS 2002 : le décompte de trames de la seconde, secondes en $10A7D2.
        JEU     0x0265, 0xC423, 1
        CHEAT   "INFINITE TIME",   0x10A7D3, 1, 0x32
        | SAMURAI SHODOWN : les secondes, BCD, 99 au départ.
        JEU     0x0045, 0x39BC, 1
        CHEAT   "INFINITE TIME",   0x100A08, 1, 0x99
        | SAMURAI SHODOWN II : les secondes, BCD, 99 au départ.
        JEU     0x0063, 0xB2EF, 1
        CHEAT   "INFINITE TIME",   0x100AC6, 1, 0x99
        | SAMURAI SHODOWN IV : le décompte de trames de la seconde ($3C), secondes en $108368.
        JEU     0x0222, 0x2643, 1
        CHEAT   "INFINITE TIME",   0x108369, 1, 0x3C
        | SAMURAI SHODOWN V : les secondes, BCD.
        JEU     0x0270, 0x1B2F, 1
        CHEAT   "INFINITE TIME",   0x10836A, 1, 0x60
        | SAMURAI SHODOWN V SPECIAL : les secondes, BCD.
        JEU     0x0272, 0x1851, 1
        CHEAT   "INFINITE TIME",   0x10836A, 1, 0x60
        | FATAL FURY 3 : les secondes, BCD.
        JEU     0x0069, 0xEF51, 1
        CHEAT   "INFINITE TIME",   0x105680, 1, 0x60
        | FATAL FURY SPECIAL : les secondes, BCD.
        JEU     0x0058, 0x189F, 1
        CHEAT   "INFINITE TIME",   0x10092A, 1, 0x60
        | THE LAST BLADE : les secondes, BCD.
        JEU     0x0234, 0xB3E9, 1
        CHEAT   "INFINITE TIME",   0x10E32B, 1, 0x60
        | ART OF FIGHTING 2 : les secondes, BCD, la même cellule qu'aof.
        JEU     0x0056, 0x2DFA, 1
        CHEAT   "INFINITE TIME",   0x108406, 1, 0x60
        | WORLD HEROES : les secondes, BCD, 99 au départ.
        JEU     0x0053, 0x783E, 1
        CHEAT   "INFINITE TIME",   0x10B008, 1, 0x99
        | WORLD HEROES 2 : les secondes, BCD, 99 au départ.
        JEU     0x0057, 0x1419, 1
        CHEAT   "INFINITE TIME",   0x10C109, 1, 0x99
        | SNK VS. CAPCOM : les secondes, BCD.
        JEU     0x0269, 0xD6D2, 1
        CHEAT   "INFINITE TIME",   0x10AC14, 1, 0x60
        | BREAKERS REVENGE : les secondes, binaire, 99 au départ.
        JEU     0x0245, 0xB255, 1
        CHEAT   "INFINITE TIME",   0x107C27, 1, 0x63
        | KARNOV'S REVENGE : les secondes, binaire, 99 au départ.
        | Le 2026-10-29 : $103A74, l'octet haut du mot de la vie de P1 ($0FFF au plus haut).
        JEU     0x0066, 0x6A32, 2
        CHEAT   "INFINITE TIME",   0x103A70, 1, 0x63
        CHEAT   "P1 INFINITE LIFE", 0x103A74, 1, 0x0F
        | DOUBLE DRAGON : les secondes, BCD, 99 au départ.
        JEU     0x0082, 0x1CB9, 1
        CHEAT   "INFINITE TIME",   0x102242, 1, 0x99
        | METAL SLUG 2 : les vies, 2 au départ de la partie (HUD 1UP=2).
        JEU     0x0241, 0xBE57, 1
        CHEAT   "INFINITE LIVES",  0x101276, 1, 0x02
        | METAL SLUG X : les vies, 2 au départ.
        JEU     0x0250, 0x92D4, 1
        CHEAT   "INFINITE LIVES",  0x101288, 1, 0x02
        | METAL SLUG 3 : les vies, 2 au départ.
        JEU     0x0256, 0xE095, 1
        CHEAT   "INFINITE LIVES",  0x1002BB, 1, 0x02
        | METAL SLUG 4 : les vies, 2 au départ.
        JEU     0x0263, 0xD875, 1
        CHEAT   "INFINITE LIVES",  0x100A89, 1, 0x02
        | METAL SLUG 5 : les vies, 2 au départ.
        JEU     0x0268, 0x1581, 1
        CHEAT   "INFINITE LIVES",  0x100A41, 1, 0x02
        | PULSTAR : les vies, 2 au départ.
        JEU     0x0089, 0xA232, 1
        CHEAT   "INFINITE LIVES",  0x10132A, 1, 0x02
        | BLAZING STAR : les vies, 2 au départ.
        JEU     0x0239, 0xA454, 1
        CHEAT   "INFINITE LIVES",  0x101BA1, 1, 0x02
        | ANDRO DUNOS : les vies, 3 au départ.
        JEU     0x0049, 0x03FF, 1
        CHEAT   "INFINITE LIVES",  0x100343, 1, 0x03
        | GHOST PILOTS : les vies, 3 au départ.
        JEU     0x0020, 0xA0C5, 1
        CHEAT   "INFINITE LIVES",  0x103F37, 1, 0x03
        | LAST RESORT : les vies, 2 au départ.
        JEU     0x0024, 0x03A4, 1
        CHEAT   "INFINITE LIVES",  0x108030, 1, 0x02
        | MAGICIAN LORD : les vies, 2 au départ.
        JEU     0x0005, 0x9330, 1
        CHEAT   "INFINITE LIVES",  0x103B00, 1, 0x02
        | STRIKERS 1945 PLUS : les vies, 2 au départ.
        JEU     0x0254, 0xD5FF, 1
        CHEAT   "INFINITE LIVES",  0x1000E9, 1, 0x02
        | ZED BLADE : les vies, 3 au départ.
        JEU     0x0076, 0x9553, 1
        CHEAT   "INFINITE LIVES",  0x100229, 1, 0x03
        | LES VIES DES JEUX D'ACTION, le 2026-10-29 (`bench/cheats-recherche.py`, sous-commande action :
        | un relevé du scénario action filtré, puis chaque candidat forcé seul dès la trame 700,
        | contre
        | un témoin). Retenue : la cellule dont le forçage ôte toute fin de partie en 12 000 trames
        | sans
        | figer l'image, quand le témoin perd la sienne ; la valeur est la plus haute du relevé.
        | Relevés
        | et autres candidats : `measured/2026-10-29-cheats-action-recherche.tsv`.
        | BANG BANG BUSTERS : les vies, 4 au plus haut ; le témoin perd la partie à la trame 4860.
        JEU     0x0071, 0xE928, 1
        CHEAT   "INFINITE LIVES",  0x106907, 1, 0x04
        | BLUE'S JOURNEY : les vies, 2 au plus haut ; le témoin perd la partie à la trame 3846.
        JEU     0x0022, 0xC32D, 1
        CHEAT   "INFINITE LIVES",  0x107000, 1, 0x02
        | CAPTAIN TOMADAY : les vies, 2 au plus haut ; le témoin perd la partie à la trame 3831.
        JEU     0x0249, 0xE6CD, 1
        CHEAT   "INFINITE LIVES",  0x104026, 1, 0x02
        | GANRYU : les vies, 3 au plus haut ; le témoin perd la partie à la trame 4912.
        JEU     0x0252, 0x0111, 1
        CHEAT   "INFINITE LIVES",  0x1004A1, 1, 0x03
        | NINJA COMBAT : les vies, 3 au plus haut ; le témoin perd la partie à la trame 5956.
        JEU     0x0009, 0x8C0D, 1
        CHEAT   "INFINITE LIVES",  0x102402, 1, 0x03
        | NEO BOMBERMAN : les vies, 2 au plus haut ; le témoin perd la partie à la trame 2500.
        JEU     0x0093, 0x5602, 1
        CHEAT   "INFINITE LIVES",  0x101658, 1, 0x02
        | NEO MR. DO! : les vies, 2 au plus haut ; le témoin perd la partie à la trame 5227.
        JEU     0x0207, 0x94A1, 1
        CHEAT   "INFINITE LIVES",  0x10465B, 1, 0x02
        | PREHISTORIC ISLE 2 : les vies, 3 au plus haut ; le témoin perd la partie à la trame 5119.
        JEU     0x0255, 0x8E0D, 1
        CHEAT   "INFINITE LIVES",  0x105055, 1, 0x03
        | SENGOKU 2 : les vies, 3 au plus haut ; le témoin perd la partie à la trame 4646.
        JEU     0x0040, 0xCEF6, 1
        CHEAT   "INFINITE LIVES",  0x1001AF, 1, 0x03
        | SENGOKU 3 : les vies, 2 au plus haut ; le témoin perd la partie à la trame 7669.
        JEU     0x0261, 0x83B6, 1
        CHEAT   "INFINITE LIVES",  0x1083E1, 1, 0x02
        | SHOCK TROOPERS 2ND SQUAD : les vies, 3 au plus haut ; le témoin perd la partie à la trame
        | 4699.
        JEU     0x0246, 0x5240, 1
        CHEAT   "INFINITE LIVES",  0x10905B, 1, 0x03
        | AERO FIGHTERS 2 : les vies, 2 au plus haut ; le témoin perd la partie à la trame 6646.
        JEU     0x0075, 0xECD1, 1
        CHEAT   "INFINITE LIVES",  0x100615, 1, 0x02
        | AERO FIGHTERS 3 : les vies, 2 au plus haut ; le témoin perd la partie à la trame 2517.
        JEU     0x0097, 0x63E9, 1
        CHEAT   "INFINITE LIVES",  0x10E89B, 1, 0x02
        | SPIN MASTER : les vies, 2 au plus haut ; le témoin perd la partie à la trame 9562.
        JEU     0x0062, 0x915F, 1
        CHEAT   "INFINITE LIVES",  0x105015, 1, 0x02
        | THE SUPER SPY : 8 au plus haut ; SUPPOSÉ des vies, peut-être l'énergie (le cheat ôte la
        | fin de partie) ; le témoin perd la partie à la trame 9666.
        JEU     0x0011, 0xB441, 1
        CHEAT   "INFINITE LIVES",  0x10181F, 1, 0x08
        | TWINKLE STAR SPRITES : les vies, 3 au plus haut ; le témoin perd la partie à la trame
        | 9296.
        JEU     0x0224, 0xC6FE, 1
        CHEAT   "INFINITE LIVES",  0x103745, 1, 0x03
        | VIEWPOINT : les vies, 3 au plus haut ; le témoin perd la partie à la trame 5989.
        JEU     0x0051, 0x691F, 1
        CHEAT   "INFINITE LIVES",  0x108D99, 1, 0x03
        | ZUPAPA! : les vies, 3 au plus haut ; le témoin perd la partie à la trame 6482.
        JEU     0x0070, 0xEC13, 1
        CHEAT   "INFINITE LIVES",  0x1002C1, 1, 0x03
        | LES VIES DE P1 DE JEUX DE COMBAT, le 2026-10-29 (`bench/cheats-recherche.py` releve, puis
        | bisecter en scénario actif ou faible : P1 tape un peu, et gagne au temps quand sa vie est
        | forcée) ; les barres de P1 vues pleines sur les bandeaux du HUD, celle de P2 entamée.
        | THE KING OF FIGHTERS '96 : $108422, les dégâts subis par P1, forcés à 0.
        JEU     0x0214, 0xEB0F, 1
        CHEAT   "P1 INFINITE LIFE", 0x108422, 1, 0x00
        | NINJA MASTER'S : $100050, la vie de P1, $D0 au plus haut.
        JEU     0x0217, 0x4720, 1
        CHEAT   "P1 INFINITE LIFE", 0x100050, 1, 0xD0
        | RAGE OF THE DRAGONS : $1023E6, la vie de P1, $10 au plus haut.
        JEU     0x0264, 0x8D79, 1
        CHEAT   "P1 INFINITE LIFE", 0x1023E6, 1, 0x10
        FIN_TABLE
        .balign 2
