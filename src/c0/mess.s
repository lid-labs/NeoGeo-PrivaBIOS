| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| MESS_OUT — l'entrée $C004CE du tableau d'appels, et la routine que SYSTEM_INT1 appelle.
|
| Le créneau de six octets de `c0.s` ne porte qu'un `jmp` vers `_mess_out` : le jeu y
| arrive par `jsr` (mesuré : 655 appels de `b2b` à $C004CE sous la référence,
| `measured/2026-10-17-b2b-mess-out.tsv`, point 1) et repart par notre `rts`. INT1 (`int1.s`)
| l'appelle par `bsr`, ses registres déjà sauvés.
|
| TROIS SORTES D'AFFIRMATIONS, et chacune le dit :
|   « mesuré »  : `measured/2026-10-17-b2b-mess-out.tsv` (point 4, un appel de `b2b`
|                 décomposé, et le protocole des variables) ;
|   « lu dans » : une page du NeoGeo Development Wiki, nommée — ici surtout « MESS_OUT »,
|                 son texte et sa capture d'écran, qui rend la liste d'exemple de la page ;
|   « SUPPOSÉ » : ni l'un ni l'autre, et c'est dit.
|
| LE TAMPON, lu dans « MESS_OUT » : de BIOS_MESS_BUFFER ($10FF00, constante) jusqu'à
| BIOS_MESS_POINT ($10FDBE, long). Chaque entrée est un long : non nul, un pointeur vers une
| liste de commandes en ROM ou en RAM ; nul, la liste suit directement dans le tampon. Les
| commandes sont des mots : l'octet bas est le numéro de commande, l'octet haut un paramètre
| pour 2, 8, 9, C et D (lu dans les schémas de bits de la page).
|
| L'ADRESSE VRAM COURANTE (%d1) N'EST PAS CELLE DU MATÉRIEL : c'est la dernière que le BIOS
| a posée dans $3C0000. Mesuré sur l'appel de `b2b` : $820D (commande 3), une donnée écrite,
| puis la commande 5 de +$0200 pose $840D — la base, sans l'avance que l'écriture a donnée à
| l'adresse du LSPC. Lu dans la capture de « MESS_OUT », même loi : les « $0005,$0001 »
| (« Next line ») ramènent chaque ligne à la colonne de départ, et la répétition de C puis D
| reste sur une seule ligne, le matériel avançant seul de VRAM_MOD entre elles.
|
| L'ÉTAT D'UN APPEL est en registres, et seulement le temps de l'appel — aucune variable
| de RAM n'est écrite hors $10FDBE et $10FDC2, qui sont les seules que la mesure attribue à
| MESS_OUT. SUPPOSÉ, donc : le format de données (commande 1), le pointeur de données
| (commandes 4 et 6) et l'adresse courante repartent à chaque appel de :
|   format octets, octet haut $00, code de fin $FF (celui de l'exemple de la page) ;
|   pointeur de données nul ; adresse courante 0.
| La page dit que le format « stays the same until command 1 is used again », sans dire
| s'il survit d'un appel à l'autre ; la liste de `b2b` mesurée pose le sien à chaque fois.
|
| LES REGISTRES SONT TOUS RENDUS INTACTS. SUPPOSÉ : « MESS_OUT » ne dit rien de ce que
| l'appel préserve ; c'est le choix qui ne peut pas casser un appelant. VRAM_MOD ($3C0004)
| n'est pas rendu : les commandes 2, 8 et 9 le posent, et c'est un registre du LSPC.
|
| L'ESPACEMENT DES ACCÈS VRAM, lu dans « VRAM » : 12 cycles au moins entre deux écritures de
| donnée, 16 entre une donnée et l'adresse qui suit. Les boucles d'écriture ci-dessous
| tiennent au moins 26 cycles par tour, et une adresse ne suit jamais une donnée sans le
| décodage d'une commande ou une sortie de boucle entre les deux.
| ==================================================================================

        | En zone haute depuis le 2026-10-25 : $C02000-$C03FFF est la grille (`grille.s`).
        .section .haut, "ax"
        .global _mess_out

| ----------------------------------------------------------------------------------
| L'ENTRÉE. Mesuré : $10FDC2 ← 01 pendant l'appel, puis $10FDBE ← $0010FF00 et $10FDC2 ← 00
| après les écritures LSPC, dans cet ordre. Lu dans « MESS_OUT » et « BIOS RAM locations » :
| BIOS_MESS_BUSY non nul, le jeu modifie le tampon (« 1:Skip MESS_OUT ») — on n'y touche pas,
| pointeur compris.
|
| UN POINTEUR HORS DE ]$10FF00, $110000] N'EXÉCUTE RIEN. SUPPOSÉ, garde : au-delà de la
| RAM, le parcours lirait n'importe quoi comme des commandes. Mesuré, le cas existe : sans
| initialisation, `b2b` a laissé $00002F9C dans $10FDBE (point 3 du relevé). Un pointeur
| en dessous de $10FF00 tombe déjà dans le `bcc` du parcours.
| ----------------------------------------------------------------------------------
_mess_out:
        tst.b   0x10FDC2
        bne.s   .Locc
        movem.l %d0-%d7/%a0-%a6, -(%sp)
        move.b  #1, 0x10FDC2            | BIOS_MESS_BUSY levé

        lea     0x3C0000, %a4           | REG_VRAMADDR ; +2 REG_VRAMRW ; +4 REG_VRAMMOD
        lea     0x10FF00, %a2           | BIOS_MESS_BUFFER : l'entrée à lire
        movea.l 0x10FDBE, %a3           | BIOS_MESS_POINT  : la fin du tampon
        cmpa.l  #0x110000, %a3
        bhi.s   .Lfin
        moveq   #0, %d1                 | adresse VRAM courante, SUPPOSÉ (en-tête)
        move.w  #0x0001, %d2            | format : octets, fin par code...
        move.w  #0x00FF, %d3            | ... octet haut $00, code $FF — SUPPOSÉ (en-tête)
        suba.l  %a1, %a1                | pointeur de données (4, 6), SUPPOSÉ (en-tête)

.Lentree:
        cmpa.l  %a3, %a2
        bcc.s   .Lfin                   | non signé : $10FF00 ≥ fin, tampon vide
        move.l  (%a2)+, %d0
        beq.s   .Ldirecte
        movea.l %d0, %a0                | un pointeur vers une liste
        bsr     _mess_liste
        bra.s   .Lentree
.Ldirecte:
        movea.l %a2, %a0                | long nul : la liste suit dans le tampon...
        bsr     _mess_liste
        movea.l %a0, %a2                | ... et l'entrée suivante après son mot de fin
        bra.s   .Lentree

.Lfin:
        move.l  #0x10FF00, 0x10FDBE     | BIOS_MESS_POINT ← BIOS_MESS_BUFFER, mesuré
        move.b  #0, 0x10FDC2            | BIOS_MESS_BUSY rabaissé, mesuré
        movem.l (%sp)+, %d0-%d7/%a0-%a6
.Locc:
        rts

| ----------------------------------------------------------------------------------
| UNE LISTE, depuis %a0, jusqu'à sa commande 0. En sortie, %a0 suit le mot de fin.
|
| LES SOUS-LISTES (A, B) empilent l'adresse de retour sur la pile du 68000, %d7 en compte
| la profondeur. Lu dans « MESS_OUT » : « The call stack seems to be 5 addresses deep ».
| SUPPOSÉ, ce qui en déborde : un sixième appel imbriqué est sauté, son pointeur consommé.
| SUPPOSÉ encore, ce que la page ne dit pas : une commande 0 dans une sous-liste y vaut un
| retour (B), et un B dans la liste de tête y vaut une fin (0) — la liste de tête garde
| ainsi sa position, ce qu'exige une liste directe pour que l'entrée suivante se trouve.
| Une commande au-delà de $D est traitée comme 0, SUPPOSÉ : la suite ne se lit plus.
|
| Registres : %d0 le mot de commande, %d1 l'adresse courante, %d2/%d3 le format, %d4-%d6
| des brouillons, %d7 la profondeur ; %a0 la liste, %a1 le pointeur de données, %a4 le
| LSPC, %a6 la source d'une sortie.
| ----------------------------------------------------------------------------------
_mess_liste:
        moveq   #0, %d7
.Lsuivante:
        move.w  (%a0)+, %d0
        moveq   #0, %d4
        move.b  %d0, %d4
        cmpi.b  #0x0D, %d4
        bls.s   1f
        moveq   #0, %d4                 | inconnue : comme 0
1:      add.w   %d4, %d4
        move.w  .Ltable(%pc,%d4.w), %d4
        jmp     .Ltable(%pc,%d4.w)
.Ltable:
        .word   .Lc0-.Ltable, .Lc1-.Ltable, .Lc2-.Ltable, .Lc3-.Ltable
        .word   .Lc4-.Ltable, .Lc5-.Ltable, .Lc6-.Ltable, .Lc7-.Ltable
        .word   .Lc8-.Ltable, .Lc8-.Ltable, .LcA-.Ltable, .Lc0-.Ltable
        .word   .LcC-.Ltable, .LcC-.Ltable

| 0 et B — fin de liste, ou retour de sous-liste (voir plus haut).
.Lc0:
        tst.w   %d7
        beq.s   .Lc0_fin
        movea.l (%sp)+, %a0
        subq.w  #1, %d7
        bra     .Lsuivante
.Lc0_fin:
        rts

| 1 — le format, lu dans « MESS_OUT » : bit 9 du mot de commande, 0 octets / 1 mots ;
| bit 8, 0 code de fin / 1 taille. Le mot suivant : en octets, l'octet haut constant et
| le code de fin ou la taille dans l'octet bas ; en mots, le code de fin ou la taille.
.Lc1:
        move.w  %d0, %d2
        move.w  (%a0)+, %d3
        bra     .Lsuivante

| 2 — VRAM_MOD ← l'octet haut. SUPPOSÉ : étendu en signe. La page pose la question (« Is
| the value sign-extended or not ? ») sans y répondre ; « VRAM » dit REG_VRAMMOD signé.
.Lc2:
        move.w  %d0, %d4
        asr.w   #8, %d4
        move.w  %d4, 4(%a4)
        bra     .Lsuivante

| 3 — adresse VRAM ← le mot suivant, posée aussitôt (mesuré : $3C0000 ← $820D).
.Lc3:
        move.w  (%a0)+, %d1
        move.w  %d1, (%a4)
        bra     .Lsuivante

| 4 — pointeur de données ← le long suivant, et la sortie depuis lui. Lu dans « MESS_OUT » :
| « Actual writes to VRAM are done with this command ». Le pointeur reste après la dernière
| donnée lue, code de fin compris, pour la commande 6 : la capture de la page montre
| « MESSAGE 2 » repris juste après le $FF de « MESSAGE 1 ».
.Lc4:
        movea.l (%a0)+, %a1
| 6 — reprendre la sortie là où la précédente s'est arrêtée.
.Lc6:
        movea.l %a1, %a6
        bsr     .Lsortir
        movea.l %a6, %a1
        bra     .Lsuivante

| 5 — adresse courante += le mot suivant, posée aussitôt (mesuré : +$0200 depuis $820D,
| $3C0000 ← $840D).
.Lc5:
        add.w   (%a0)+, %d1
        move.w  %d1, (%a4)
        bra     .Lsuivante

| 7 — les données suivent la commande, dans le format courant (mesuré : en mots de taille
| 1, $3C0002 ← $0984). La liste reprend au mot pair suivant : l'octet de bourrage que la
| page demande quand les données finissent sur une adresse impaire. SUPPOSÉ : le pointeur
| de la commande 6 n'en est pas changé — la page ne lie 6 qu'à 4.
.Lc7:
        movea.l %a0, %a6
        bsr     .Lsortir
.Lpair:
        move.l  %a6, %d4
        addq.l  #1, %d4
        bclr    #0, %d4
        movea.l %d4, %a0
        bra     .Lsuivante

| A — appeler la sous-liste du long suivant (voir plus haut pour la profondeur).
.LcA:
        movea.l (%a0)+, %a6
        cmpi.w  #5, %d7
        bcc     .Lsuivante              | SUPPOSÉ : au-delà de 5, sauté
        move.l  %a0, -(%sp)
        movea.l %a6, %a0
        addq.w  #1, %d7
        bra     .Lsuivante

| C et D — le mot suivant écrit N fois, N l'octet haut de la commande. D incrémente
| l'octet bas à chaque fois, sans retenue : lu dans « MESS_OUT », $42FE donne $42FE,
| $42FF, $4200, $4201. SUPPOSÉ : N = 0 n'écrit rien.
.LcC:
        moveq   #0, %d6
        move.w  %d0, %d6
        lsr.w   #8, %d6
        move.w  (%a0)+, %d4
        bra.s   2f
1:      move.w  %d4, 2(%a4)
        cmpi.b  #0x0D, %d0
        bne.s   2f
        addq.b  #1, %d4
2:      dbf     %d6, 1b
        bra     .Lsuivante

| 8 et 9 — texte en police 8×16, lu dans « MESS_OUT » : l'octet haut de la commande est
| l'octet haut constant des données (le jeu de caractères), les octets suivent jusqu'au
| code $FF, et VRAM_MOD passe à $20 — une colonne par caractère. La liste reprend au mot
| pair suivant, comme pour 7.
|
| UN CARACTÈRE FAIT DEUX TUILES, celle du haut à l'adresse courante, celle du bas à la
| ligne d'en dessous : la page le dit pour 9 (« upper », « lower »), et sa capture rend le
| texte de 8 et de 9 sur deux lignes de tuiles. On écrit donc la rangée du haut depuis
| l'adresse courante, puis celle du bas depuis l'adresse courante + 1, qui DEVIENT
| l'adresse courante. Lu dans la capture : « ABCDE » (commande 8) à la ligne 7, puis
| « $0005,$0001 » et le texte de 9 à la ligne 9, puis « $0005,$0002 » et les sous-listes
| à la ligne 12 — chaque texte a bien laissé l'adresse courante sur sa seconde ligne.
| SUPPOSÉ : partir de l'adresse courante, et non de celle où le matériel en est resté.
|
| LES TUILES. Commande 9, lu dans « MESS_OUT » : $00-$1F → $080+c en haut et $0C0+c en bas,
| $60-$7F → $0A0+(c-$60) en haut et $0E0+(c-$60) en bas, toujours en page 0 « irrespective
| of the selected fontset » ; le reste comme la commande 8. SUPPOSÉ : la page 0 force les
| bits 11-8 de la tuile à 0 et garde la palette (bits 15-12) de l'octet haut.
| Commande 8, SUPPOSÉ ENTIÈREMENT pour la tuile du bas, que la page ne donne pas : la
| tuile du haut est (octet haut × $100) + c, comme une donnée octet de la commande 1, et
| celle du bas la même + $100, dans la page suivante. Aucune source lue ne le dit ; le
| contenu de la ROM de tuiles système n'est pas une entrée de cette salle blanche.
.Lc8:
        moveq   #0, %d5
        move.w  %d0, %d5
        clr.b   %d5                     | %d5 = octet haut × $100
        move.w  #0x20, 4(%a4)           | VRAM_MOD ← $20
        move.w  %d1, (%a4)
        moveq   #0, %d6                 | la rangée du haut
        bsr     .Lrangee
        addq.w  #1, %d1
        move.w  %d1, (%a4)
        moveq   #1, %d6                 | la rangée du bas
        bsr     .Lrangee
        bra.s   .Lpair

| Une rangée de tuiles d'un texte 8 ou 9, depuis %a0 jusqu'au $FF ; %a6 le suit après.
.Lrangee:
        movea.l %a0, %a6
.Lr_car:
        moveq   #0, %d4
        move.b  (%a6)+, %d4
        cmpi.b  #0xFF, %d4
        beq.s   .Lr_fin
        cmpi.b  #9, %d0
        bne.s   .Lr_latin
        cmpi.b  #0x20, %d4
        bcs.s   .Lr_hira                | $00-$1F
        cmpi.b  #0x60, %d4
        bcs.s   .Lr_latin
        cmpi.b  #0x80, %d4
        bcc.s   .Lr_latin
        addi.w  #0x40, %d4              | $60-$7F → $0A0-$0BF
        bra.s   .Lr_kana
.Lr_hira:
        addi.w  #0x80, %d4              | $00-$1F → $080-$09F
.Lr_kana:
        tst.w   %d6
        beq.s   1f
        addi.w  #0x40, %d4              | le bas : $0C0-$0DF, $0E0-$0FF
1:      or.w    %d5, %d4
        andi.w  #0xF0FF, %d4            | page 0, palette gardée — SUPPOSÉ
        bra.s   .Lr_ecrire
.Lr_latin:
        or.w    %d5, %d4
        tst.w   %d6
        beq.s   .Lr_ecrire
        addi.w  #0x100, %d4             | le bas : page suivante — SUPPOSÉ
.Lr_ecrire:
        move.w  %d4, 2(%a4)
        bra.s   .Lr_car
.Lr_fin:
        rts

| ----------------------------------------------------------------------------------
| LA SORTIE DES DONNÉES, depuis %a6, dans le format %d2/%d3 (commande 1). En sortie, %a6
| suit la dernière donnée lue, code de fin compris. Une taille 0 n'écrit rien, SUPPOSÉ ;
| le code de fin, lui, n'est jamais écrit (lu dans « MESS_OUT », capture : « MESSAGE 1 »
| et « MESSAGE 2 » séparés par un $FF qui ne s'affiche pas).
| ----------------------------------------------------------------------------------
.Lsortir:
        btst    #9, %d2
        bne.s   .Ls_mots
        btst    #8, %d2
        bne.s   .Ls_octets_taille
.Ls_octets_fin:
        move.w  %d3, %d4                | octet haut constant...
        move.b  (%a6)+, %d4             | ... et la donnée en bas
        cmp.b   %d3, %d4                | le code de fin ?
        beq.s   .Ls_fin
        move.w  %d4, 2(%a4)
        bra.s   .Ls_octets_fin
.Ls_octets_taille:
        moveq   #0, %d6
        move.b  %d3, %d6                | taille ≤ $FF
        bra.s   2f
1:      move.w  %d3, %d4
        move.b  (%a6)+, %d4
        move.w  %d4, 2(%a4)
2:      dbf     %d6, 1b
        rts
.Ls_mots:
        btst    #8, %d2
        bne.s   .Ls_mots_taille
.Ls_mots_fin:
        move.w  (%a6)+, %d4
        cmp.w   %d3, %d4
        beq.s   .Ls_fin
        move.w  %d4, 2(%a4)
        bra.s   .Ls_mots_fin
.Ls_mots_taille:
        move.w  %d3, %d6                | taille ≤ $FFFF : `dbf` compte sur 16 bits
        bra.s   2f
1:      move.w  (%a6)+, 2(%a4)
2:      dbf     %d6, 1b
.Ls_fin:
        rts
