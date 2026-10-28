| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| CARD et CARD_ERROR — les entrées $C00468 et $C0046E du tableau d'appels : la carte
| mémoire.
|
| Les créneaux de six octets de `c0.s` ne portent qu'un `jmp` vers `_card` et
| `_card_error` : le jeu y arrive par `jsr` et repart par notre `rts`.
|
| TROIS SORTES D'AFFIRMATIONS, et chacune le dit :
|   « mesuré »  : `measured/2026-10-19-card-sans-carte.tsv` (8 appels sur 5 jeux, sans
|                 carte) et `measured/2026-10-19-card-avec-carte.tsv` (carte de 2 Kio,
|                 8 bits, appels naturels et provoqués) ; « point N » renvoie à ce dernier ;
|   « lu dans » : les pages « CARD », « CARD ERROR », « Memory card » et « Memory mapped
|                 registers » du NeoGeo Development Wiki, consultées le 2026-10-19 ;
|   « SUPPOSÉ » : ni l'un ni l'autre, et c'est dit.
|
| SANS CARTE, mesuré, dans cet ordre, aux 8 appels, puis les deux verrouillages (plus bas) :
|   $10FD00 (long)  ← le SP à l'entrée (il pointe l'adresse de retour empilée) MOINS 4 ;
|   $10FCF4 (octet) ← $FF, rôle non interprété ;
|   $10FDC6 (octet) ← $80, BIOS_CARD_ANSWER « no card inserted » (lu dans « CARD »).
|
| LA DÉTECTION. REG_STATUS_B ($380000, octet haut) : $FF sans carte, $8F avec, mesuré
| (point 4). Lu dans « Memory card » : CD1 au bit 4, CD2 au bit 5, « both must be 0 »
| quand la carte est en place ; le bit 6 est la protection d'écriture.
|
| LA CARTE, 8 BITS : l'octet N à $800000 + 2N, mesuré (point 4 : l'octet $47 écrit à
| $80008E). Lu dans « Memory card » : accès toujours en mots, l'octet bas seul porte.
|
| LE CRITÈRE DE FORMATAGE : CARD_MAGIC, « NEO-GEO » puis $80 aux huit octets pairs de
| $20 à $2E (lu dans « Memory card », mesuré point 2). Mesuré (point 4) : sur une carte
| non formatée, deux lectures, octets $00 puis $20, puis $81 — ce qui s'accorde avec un
| arrêt à la première différence. Comparer les huit est SUPPOSÉ ; l'octet $00 est lu à
| la même place, et sa valeur n'entre dans aucune décision — SUPPOSÉ.
|
| LA STRUCTURE, mesurée (point 2), et lue dans « Memory card » : blocs de 64 octets ;
| en-tête au bloc 0 ; répertoire $40-$BF, 32 entrées (sous-sauvegarde, NGH, premier
| bloc ; $FF au 1er octet si libre) ; FAT 1 $C0-$FF, FAT 2 $100-$13F, une entrée par
| bloc ($00 libre, $01 dernier, $02 réservé, sinon le suivant) ; données dès le bloc 5.
| Somme d'une FAT ($0D, $0E) = somme de ses 64 octets, mesuré trois fois.
|
| UNE SEULE GÉOMÉTRIE : CARD_SIZE = $1000, 2 Kio, 32 blocs, la seule relevée — et la
| carte SNK d'origine (lu dans « Memory card »). SUPPOSÉ : une carte formatée qui porte un
| autre CARD_SIZE répond $85 sans rien lire ni écrire de plus ; la page dit que la taille
| du répertoire et des FAT suit la capacité sans dire comment, et lire une autre carte
| avec ce plan la corromprait. Cartes 16 bits non traitées (BIOS_CARD_TYPE toujours 0) :
| SUPPOSÉ, rien de mesuré.
|
| LES REGISTRES DE LA CARTE, mesuré (point 4, « REGISTRES DE LA CARTE »), octets
| impairs, la donnée ne compte pas (lu dans « Memory mapped registers ») ; dans l'ordre :
|   chargement : REG_CRDNORMAL ($3A0019), REG_CRDBANK ($380011) ← 0, puis à la fin
|                REG_CRDLOCK2 ($3A0007), REG_CRDLOCK1 ($3A0015) ;
|   sauvegarde : les mêmes, et REG_CRDUNLOCK1 ($3A0005) puis REG_CRDUNLOCK2 ($3A0017),
|                deux fois, avant les deux verrouillages ;
|   sans carte : REG_CRDLOCK2, REG_CRDLOCK1.
| Sans REG_CRDNORMAL la carte ne se lit pas, mesuré : la première image de ce fichier
| lisait deux octets, puis répondait $81 sur une carte formatée.
| Jugé contre la référence (bench/carte-diff.sh) : $04 fait les deux paires comme la
| sauvegarde, $00 et $06 une seule paire.
| SUPPOSÉ :
|   - les autres commandes de lecture ($01, $05, $07), une carte non formatée et une
|     géométrie refusée font comme le chargement ;
|   - la place des deux déverrouillages : d'affilée, juste avant la première écriture sur
|     la carte ; une FAT réparée pendant une sauvegarde les fait donc passer deux fois ;
|   - sans carte, les verrouillages viennent après $10FDC6.
|
| AUCUN REGISTRE MODIFIÉ, hors CCR. Lu dans « CARD » : « register contents aren't
| preserved », donc l'appelant ne compte sur rien ; ne rien toucher est notre choix.
| ==================================================================================

        | En zone haute depuis le 2026-10-25 : $C02000-$C03FFF est la grille (`grille.s`).
        .section .haut, "ax"
        .global _card
        .global _card_error
        .global _carte_releve

| ----------------------------------------------------------------------------------
| CARD. Écritures en RAM BIOS, mesuré (points 1 et 3), dans cet ordre :
|   avec carte : $10FD00, $10FCF4, $10FDC6 ← $00, puis la réponse si elle n'est pas $00 ;
|   carte formatée : en plus, après $10FDC6 ← $00, $10FCF4 de nouveau, $10FD16, $10FD14,
|   puis les huit mots $10FD04-$10FD12 ; le formatage, lui, sans second $10FCF4 et
|   $10FD14 avant $10FD16 (mesuré au jugement). La valeur du second $10FCF4 n'est pas relevée :
|   $FF, comme le premier, SUPPOSÉ. Celles des variables temporaires non plus : on y met
|   ce que « CARD » décrit, en adresses du 68000 (SUPPOSÉ).
| ----------------------------------------------------------------------------------
_card:
        subq.l  #4, %sp                 | SP − 4, mesuré ; sur An, subq/addq laissent le CCR
        move.l  %sp, 0x10FD00           | seule écriture de $10FD00 : pas de lecture-modification
        addq.l  #4, %sp                 | SP rendu tel qu'à l'entrée
        move.b  #0xFF, 0x10FCF4
        btst    #4, 0x380000            | REG_STATUS_B, CD1
        bne.s   .Lsans_carte
        btst    #5, 0x380000            | CD2
        beq.s   .Lavec_carte
.Lsans_carte:
        move.b  #0x80, 0x10FDC6         | BIOS_CARD_ANSWER : aucune carte insérée
        move.b  %d0, 0x3A0007           | REG_CRDLOCK2, mesuré
        move.b  %d0, 0x3A0015           | REG_CRDLOCK1
        rts

.Lavec_carte:
        move.b  #0x00, 0x10FDC6         | mesuré : $00 d'abord
        move.b  %d0, 0x3A0019           | REG_CRDNORMAL : sans lui, la carte ne se lit pas
        move.b  #0x00, 0x380011         | REG_CRDBANK ← 0, mesuré
        movem.l %d0-%d7/%a0-%a2/%a4-%a5, -(%sp)
        lea     0x800000, %a5           | %a5 : la carte, toute la durée de l'appel
        move.b  0x10FDC4, %d7           | BIOS_CARD_COMMAND
        beq     .Lformater              | $00 : formater, sans regarder l'ancien contenu
        moveq   #0, %d1
        bsr     .Llire                  | octet $00 : lu comme la référence, sans usage
        lea     _card_magie, %a0
        moveq   #0x20, %d1
1:      bsr     .Llire
        cmp.b   (%a0)+, %d0
        bne     .L81                    | carte non formatée
        addq.w  #2, %d1
        cmpi.w  #0x30, %d1
        bne.s   1b

| LA CARTE EST FORMATÉE : sa géométrie, puis la commande.
.Lprete:
        | $01 : le mot $10FDD0 écrit une première fois ici, avant le second $10FCF4 —
        | mesuré au jugement ; la valeur ne l'est pas : $0000, la remise à zéro du
        | masque, SUPPOSÉ.
        cmpi.b  #1, %d7
        bne.s   1f
        move.w  #0, 0x10FDD0
1:      move.b  #0xFF, 0x10FCF4
        moveq   #0x0A, %d1              | CARD_SIZE, mot de l'en-tête
        bsr     .Llire
        move.b  %d0, %d6
        lsl.w   #8, %d6
        moveq   #0x0B, %d1
        bsr     .Llire
        move.b  %d0, %d6
        cmpi.w  #0x1000, %d6
        bne     .L85                    | autre géométrie : refusée, SUPPOSÉ
        move.w  %d6, 0x10FD16           | BIOS_CARD_SIZE (temporaire) : CARD_SIZE
        move.w  #0, 0x10FD14            | BIOS_CARD_TYPE : 8 bits
        bsr     .Ltemporaires           | %d6 : nombre de blocs, jusqu'à la sortie

        moveq   #0, %d0
        move.b  %d7, %d0
        cmpi.b  #7, %d0
        bhi     .Lfin                   | commande inconnue : rien, réponse $00, SUPPOSÉ
        add.w   %d0, %d0
        move.w  .Ltable(%pc,%d0.w), %d0
        jmp     .Ltable(%pc,%d0.w)
.Ltable:
        .word   .Lfin - .Ltable         | $00 : n'arrive pas ici (`.Lformater`)
        .word   .Lmasque - .Ltable      | $01
        .word   .Lcharger - .Ltable     | $02
        .word   .Lsauver - .Ltable      | $03
        .word   .Lsupprimer - .Ltable   | $04
        .word   .L82 - .Ltable          | $05
        .word   .Lnom_ecrire - .Ltable  | $06
        .word   .Lnom_lire - .Ltable    | $07

| LES RÉPONSES D'ERREUR, puis la sortie commune avec carte.
.L81:   move.b  #0x81, 0x10FDC6         | carte non formatée
        bra.s   .Lfin
.L82:   move.b  #0x82, 0x10FDC6         | donnée absente
        bra.s   .Lfin
.L83:   move.b  #0x83, 0x10FDC6         | erreur de FAT
        bra.s   .Lfin
.L84:   move.b  #0x84, 0x10FDC6         | carte pleine
        bra.s   .Lfin
.L85:   move.b  #0x85, 0x10FDC6         | protégée en écriture, ou géométrie refusée
.Lfin:
        move.b  %d0, 0x3A0007           | REG_CRDLOCK2, puis REG_CRDLOCK1 : mesuré
        move.b  %d0, 0x3A0015
        movem.l (%sp)+, %d0-%d7/%a0-%a2/%a4-%a5
        rts

| ----------------------------------------------------------------------------------
| $00 — FORMATER. Mesuré (point 2, la carte que CARD_ERROR a formatée puis sauvée) :
|   $00-$09 zéro, CARD_SIZE $1000, $0C zéro, sommes $0A et $0A (5 × $02), $0F zéro,
|   le nom : 16 espaces, CARD_MAGIC aux octets pairs, la région à $30 ;
|   répertoire : $FF au 1er octet des 32 entrées ; FAT 1 et FAT 2 : blocs 0-4 à $02,
|   le reste à $00.
| LE MOTIF D'ABORD, mesuré au jugement : à la sortie, tout octet hors de cette structure
| porte le motif « le mot à l'offset pair k vaut 2k » (point 1 : « 0000 0004 0008 »),
| l'ancienne entrée 0 et l'ancien bloc 5 compris — la référence remplit la carte, puis
| écrit la structure. D'où les octets impairs de CARD_MAGIC, $31-$3F, les octets 1 à 3
| des entrées et les blocs de données au motif. Octet pair k : $hh de 2k ; impair k + 1 :
| $ll de 2k. SUPPOSÉ : l'étendue, 2 Kio d'octets (CARD_SIZE $1000, la seule géométrie
| servie), aucune taille n'étant détectée.
| RAM, mesuré au jugement : $10FD14 puis $10FD16, puis les temporaires, sans second
| $10FCF4 ; une seule paire de déverrouillages.
| LA RÉGION : BIOS_COUNTRY_CODE ($10FD83), que `c0.s` pose au boot d'après le
| descripteur ; mesuré $02 sous le BIOS euro, et notre image déclare l'Europe.
| SUPPOSÉ : l'ordre — motif, répertoire, FAT, en-tête, CARD_MAGIC en dernier, pour qu'un reset
| au milieu laisse une carte non formatée plutôt qu'à moitié ; et CARD_SIZE $1000 quelle
| que soit la carte, la taille venant du seul format relevé.
| ----------------------------------------------------------------------------------
.Lformater:
        btst    #6, 0x380000            | protection d'écriture
        bne     .L85
        bsr     .Lpaire
        moveq   #0, %d1                 | le motif, sur les 2 Kio
1:      move.w  %d1, %d0
        andi.w  #0xFFFE, %d0            | k, l'offset pair du mot
        add.w   %d0, %d0                | 2k
        btst    #0, %d1
        bne.s   2f                      | impair : l'octet bas
        lsr.w   #8, %d0                 | pair : l'octet haut
2:      bsr     .Lecrire
        addq.w  #1, %d1
        cmpi.w  #0x800, %d1
        bne.s   1b
        moveq   #0x40, %d1
        moveq   #-1, %d0
1:      bsr     .Lecrire                | entrée libre
        addq.w  #4, %d1
        cmpi.w  #0xC0, %d1
        bne.s   1b
        move.w  #0xC0, %d1              | FAT 1 puis FAT 2
2:      moveq   #0, %d0
        moveq   #0x3F, %d2
        and.w   %d1, %d2                | rang dans la FAT
        cmpi.w  #5, %d2
        bcc.s   3f
        moveq   #2, %d0                 | blocs 0-4 : réservés
3:      bsr     .Lecrire
        addq.w  #1, %d1
        cmpi.w  #0x140, %d1
        bne.s   2b
        lea     _card_entete, %a0
        moveq   #0, %d1
4:      move.b  (%a0)+, %d0
        bsr     .Lecrire
        addq.w  #1, %d1
        cmpi.w  #0x20, %d1
        bne.s   4b
        move.b  0x10FD83, %d0           | BIOS_COUNTRY_CODE → CARD_REGION
        moveq   #0x30, %d1
        bsr     .Lecrire
        lea     _card_magie, %a0
        moveq   #0x20, %d1
5:      move.b  (%a0)+, %d0
        bsr     .Lecrire
        addq.w  #2, %d1
        cmpi.w  #0x30, %d1
        bne.s   5b
        move.w  #0, 0x10FD14            | BIOS_CARD_TYPE : 8 bits
        move.w  #0x1000, 0x10FD16       | BIOS_CARD_SIZE (temporaire) : CARD_SIZE écrit
        bsr     .Ltemporaires
        bra     .Lfin

| Les huit mots $10FD04-$10FD12 (« CARD »), en adresses du 68000 ; %d6 ← 32 blocs.
.Ltemporaires:
        move.l  #0x800000 + 2 * 0x40, 0x10FD04  | BIOS_CARD_DIRECTORY_START
        moveq   #32, %d6
        move.w  %d6, 0x10FD08           | BIOS_CARD_BLOCK_NUMBER
        move.l  #0x800000 + 2 * 0xC0, 0x10FD0A  | BIOS_CARD_FAT_START (FAT 1)
        move.w  #64, 0x10FD0E           | BIOS_CARD_FAT_SIZE : 64 entrées
        move.l  #0x800000 + 2 * 0x140, 0x10FD10 | BIOS_CARD_DATA_START : bloc 5
        rts

| ----------------------------------------------------------------------------------
| $01 — RECHERCHE. Mesuré (point 4) : aucune écriture sur la carte ; le mot $10FDD0
| reçoit le masque des sous-sauvegardes du NGH (bit n = sous-sauvegarde n), $0000 pour un
| NGH absent, réponse $00. Les FAT ne sont pas relues : 48 à 50 lectures mesurées, ce
| qu'un passage du répertoire explique et que deux sommes de FAT (130 lectures)
| dépasseraient — lecture mienne des comptes.
| ----------------------------------------------------------------------------------
.Lmasque:
        move.w  0x10FDCE, %d3           | BIOS_CARD_FCB
        moveq   #0, %d2
        moveq   #0x40, %d1
1:      bsr     .Llire
        cmpi.b  #16, %d0
        bcc.s   2f                      | libre ($FF), ou hors de 0-15
        move.b  %d0, %d4
        bsr     .Lngh
        cmp.w   %d3, %d0
        bne.s   2f
        bset    %d4, %d2
2:      addq.w  #4, %d1
        cmpi.w  #0xC0, %d1
        bne.s   1b
        move.w  %d2, 0x10FDD0           | BIOS_CARD_SUB, en mot
        bra     .Lfin

| ----------------------------------------------------------------------------------
| $02 — CHARGER. Mesuré (point 3) : aucune écriture sur la carte ; après les
| temporaires, $10FDD0, puis SIZE octets à BIOS_CARD_START, puis BIOS_CARD_START avancé
| de la taille lue. 212 lectures : les deux FAT sont relues, lecture mienne du compte.
| Lu dans « Memory card » : une FAT fausse est réécrite d'après l'autre, deux fausses
| sont une erreur.
| SUPPOSÉ : la valeur écrite dans $10FDD0, la sienne (aucun effet) ; SUB lu à l'octet
| $10FDD0 (mesuré), hors de 0-15 → $82 ; une chaîne qui finit avant SIZE arrête la copie
| sans erreur, START avancé de ce qui a été lu ; un bloc hors de 5-31 → $83.
| ----------------------------------------------------------------------------------
.Lcharger:
        bsr     .Lfat_valider
        bne     .L83
        move.b  0x10FDD0, %d2           | BIOS_CARD_SUB, octet
        move.w  0x10FDCE, %d3           | BIOS_CARD_FCB
        cmpi.b  #16, %d2
        bcc     .L82
        bsr     .Lchercher
        tst.w   %d4
        bmi     .L82
        move.w  %d4, %d1
        addq.w  #3, %d1
        bsr     .Llire
        moveq   #0, %d4
        move.b  %d0, %d4                | %d4 : le bloc courant
        move.b  0x10FDD0, 0x10FDD0      | l'écriture relevée, valeur inchangée
        movea.l 0x10FDC8, %a0           | BIOS_CARD_START
        move.w  0x10FDCC, %d5           | BIOS_CARD_SIZE : le reste à lire
.Lch_bloc:
        tst.w   %d5
        beq.s   .Lch_fin
        cmpi.w  #5, %d4
        bcs     .L83
        cmp.w   %d6, %d4
        bcc     .L83
        move.w  %d4, %d1
        lsl.w   #6, %d1                 | offset du bloc
        moveq   #64-1, %d3
1:      bsr     .Llire
        move.b  %d0, (%a0)+
        addq.w  #1, %d1
        subq.w  #1, %d5
        dbeq    %d3, 1b                 | fin du bloc, ou SIZE atteint
        tst.w   %d5
        beq.s   .Lch_fin
        move.w  %d4, %d1
        bsr     .Lfat_lire
        moveq   #0, %d4
        move.b  %d0, %d4
        cmpi.b  #1, %d4
        bne.s   .Lch_bloc               | $01 : dernier bloc, la copie s'arrête
.Lch_fin:
        move.l  %a0, 0x10FDC8           | START avancé, mesuré
        bra     .Lfin

| ----------------------------------------------------------------------------------
| $03 — SAUVEGARDER. Mesuré (point 4) : une sauvegarde du même NGH et du même SUB est
| remplacée — un bloc libre reçoit les données, l'entrée trouvée le pointe, l'ancien bloc
| est libéré dans les deux FAT ; sinon une nouvelle entrée. Ordre mesuré : le numéro de
| bloc dans l'entrée libre, puis les données, puis FAT et entrée trouvée.
| Le bloc libre : le premier à partir de 5 (mesuré : 6 quand 5 est pris). Il est choisi
| avant que l'ancien soit libéré (mesuré : 6 et non 5).
| SUPPOSÉ : plusieurs blocs quand SIZE dépasse 64 (« Memory card » : taille arrondie au
| multiple de 64, blocs chaînés par la FAT), pris dans l'ordre croissant ; SIZE 0 prend
| un bloc ; la fin du dernier bloc reste intacte ; « l'entrée libre » est la première
| libre avant l'entrée trouvée, sinon après ; pas assez de blocs libres, ou ni entrée
| trouvée ni entrée libre → $84 ; les sommes avant l'entrée ; une nouvelle entrée reçoit
| le NGH puis SUB, SUB en dernier puisqu'il la marque prise ; START n'avance pas.
| ----------------------------------------------------------------------------------
.Lsauver:
        btst    #6, 0x380000
        bne     .L85
        bsr     .Lfat_valider
        bne     .L83
        move.b  0x10FDD0, %d2
        move.w  0x10FDCE, %d3
        cmpi.b  #16, %d2
        bcc     .L82
        bsr     .Lchercher              | %d4 : trouvée, %d5 : libre
        tst.w   %d4
        bmi.s   1f
        tst.w   %d5
        bpl.s   2f
        move.w  %d4, %d1                | une entrée libre après la trouvée
        addq.w  #4, %d1
        bsr     .Lentree_libre
        bra.s   2f
1:      tst.w   %d5
        bmi     .L84                    | ni sauvegarde à remplacer, ni entrée libre
2:      moveq   #0, %d0                 | blocs demandés : SIZE / 64 arrondi, 1 au moins
        move.w  0x10FDCC, %d0
        addi.l  #63, %d0
        lsr.l   #6, %d0
        bne.s   3f
        moveq   #1, %d0
3:      move.w  %d0, %d7
        movea.w %d0, %a2                | %a2 : blocs demandés
        moveq   #0, %d2                 | blocs libres
        moveq   #5, %d3
4:      move.w  %d3, %d1
        bsr     .Lfat_lire
        tst.b   %d0
        bne.s   5f
        addq.w  #1, %d2
5:      addq.w  #1, %d3
        cmp.w   %d6, %d3
        bcs.s   4b
        cmp.w   %d7, %d2
        bcs     .L84                    | carte pleine
        bsr     .Louvrir
        moveq   #5, %d3
        bsr     .Lbloc_libre
        movea.w %d3, %a1                | %a1 : premier bloc de la sauvegarde
        tst.w   %d5
        bmi.s   .Lsv_donnees
        move.w  %d5, %d1                | le numéro de bloc dans l'entrée libre, mesuré
        addq.w  #3, %d1
        move.b  %d3, %d0
        bsr     .Lecrire
.Lsv_donnees:
        movea.l 0x10FDC8, %a0           | BIOS_CARD_START
        move.w  0x10FDCC, %d2           | le reste à écrire
.Lsv_bloc:
        move.w  %d3, %d1
        lsl.w   #6, %d1
1:      tst.w   %d2
        beq.s   2f
        move.b  (%a0)+, %d0
        bsr     .Lecrire
        addq.w  #1, %d1
        subq.w  #1, %d2
        moveq   #0x3F, %d0
        and.w   %d1, %d0
        bne.s   1b                      | jusqu'à la fin du bloc
2:      subq.w  #1, %d7
        beq.s   .Lsv_fat
        addq.w  #1, %d3                 | bloc suivant : le libre suivant ; la FAT n'a
        bsr     .Lbloc_libre            | pas encore changé
        bra.s   .Lsv_bloc
.Lsv_fat:
        | La chaîne, dans les deux FAT : les mêmes blocs, retrouvés de la même façon.
        move.w  %a2, %d7
        move.w  %a1, %d3
1:      move.w  %d3, %d2                | %d2 : le bloc dont on écrit l'entrée
        subq.w  #1, %d7
        beq.s   2f
        addq.w  #1, %d3
        bsr     .Lbloc_libre
        move.w  %d2, %d1
        move.b  %d3, %d0
        bsr     .Lfat_ecrire
        bra.s   1b
2:      move.w  %d2, %d1
        moveq   #1, %d0                 | dernier bloc
        bsr     .Lfat_ecrire
        tst.w   %d4
        bmi.s   3f
        move.w  %d4, %d1                | l'ancienne chaîne, libérée
        addq.w  #3, %d1
        bsr     .Llire
        moveq   #0, %d3
        move.b  %d0, %d3
        bsr     .Lchaine_liberer
3:      bsr     .Lsommes_ecrire
        tst.w   %d4
        bmi.s   4f
        move.w  %d4, %d1                | l'entrée trouvée pointe la nouvelle chaîne
        addq.w  #3, %d1
        move.w  %a1, %d0
        bsr     .Lecrire
        bra.s   5f
4:      move.w  %d5, %d1                | nouvelle entrée ; son bloc est déjà posé
        addq.w  #1, %d1
        move.b  0x10FDCE, %d0           | NGH, octet haut
        bsr     .Lecrire
        addq.w  #1, %d1
        move.b  0x10FDCF, %d0           | NGH, octet bas
        bsr     .Lecrire
        move.w  %d5, %d1
        move.b  0x10FDD0, %d0           | SUB
        bsr     .Lecrire
        | $10FDD0 écrit une fois à la fin, remplacement comme nouvelle entrée : mesuré au
        | jugement. La valeur ne l'est pas ; SUPPOSÉ : la sienne, SUB inchangé (l'interface
        | après l'appel le garde tel quel, mesuré). Octet, comme au chargement.
5:      move.b  0x10FDD0, 0x10FDD0
        bra     .Lfin

| ----------------------------------------------------------------------------------
| $04 — SUPPRIMER. Mesuré (point 4) : 1er octet de l'entrée ← $FF, son bloc libéré dans
| les deux FAT, sommes réécrites ($0A). SUPPOSÉ : entrée absente → $82 (lu dans
| « CARD » : « requested data doesn't exist ») ; l'entrée avant la FAT.
| ----------------------------------------------------------------------------------
.Lsupprimer:
        btst    #6, 0x380000
        bne     .L85
        bsr     .Lfat_valider
        bne     .L83
        move.b  0x10FDD0, %d2
        move.w  0x10FDCE, %d3
        cmpi.b  #16, %d2
        bcc     .L82
        bsr     .Lchercher
        tst.w   %d4
        bmi     .L82
        bsr     .Louvrir
        move.w  %d4, %d1
        addq.w  #3, %d1
        bsr     .Llire
        moveq   #0, %d3
        move.b  %d0, %d3                | premier bloc
        move.w  %d4, %d1
        moveq   #-1, %d0
        bsr     .Lecrire                | entrée libre
        bsr     .Lchaine_liberer
        bsr     .Lsommes_ecrire
        bra     .Lfin

| $05 — LIRE LE TITRE : $82, mesuré aux cinq essais, sans écriture (point 4) ; « CARD »
| marque ses entrées d'un « ? », et une sauvegarde présente répond aussi $82. Le sens
| n'est donc pas pris : $82, après la détection, toujours. Dans la table plus haut.

| ----------------------------------------------------------------------------------
| $06 — ÉCRIRE LE NOM. Mesuré (point 4) : $0F ← $FF, $10-$1F ← les 16 premiers octets
| de BIOS_CARD_START, dans l'ordre où le relevé les cite (SUPPOSÉ qu'il soit celui des
| écritures). Une seule paire de déverrouillages, mesuré au jugement.
| ----------------------------------------------------------------------------------
.Lnom_ecrire:
        btst    #6, 0x380000
        bne     .L85
        bsr     .Lpaire
        moveq   #0x0F, %d1
        moveq   #-1, %d0
        bsr     .Lecrire                | CARD_USERNAME_AVAILABLE
        movea.l 0x10FDC8, %a0
1:      addq.w  #1, %d1
        move.b  (%a0)+, %d0
        bsr     .Lecrire
        cmpi.w  #0x1F, %d1
        bne.s   1b
        bra     .Lfin

| ----------------------------------------------------------------------------------
| $07 — LIRE LE NOM. Mesuré (point 4) : aucune écriture sur la carte. Mesuré au
| jugement : $0F à $00 → $82, rien copié à BIOS_CARD_START ; $0F est
| CARD_USERNAME_AVAILABLE (lu dans « Memory card »). Lu dans « CARD » : $82 aussi si le
| dernier caractère du nom ($1F) vaut 0 — gardé. SUPPOSÉ, non relevé : $0F non nul et
| $1F non nul, les 16 octets vont à BIOS_CARD_START.
| ----------------------------------------------------------------------------------
.Lnom_lire:
        moveq   #0x0F, %d1
        bsr     .Llire
        tst.b   %d0
        beq     .L82                    | nom absent
        moveq   #0x1F, %d1
        bsr     .Llire
        tst.b   %d0
        beq     .L82
        movea.l 0x10FDC8, %a0
        moveq   #0x10, %d1
1:      bsr     .Llire
        move.b  %d0, (%a0)+
        addq.w  #1, %d1
        cmpi.w  #0x20, %d1
        bne.s   1b
        bra     .Lfin

| ==================================================================================
| LES OUTILS. Offsets en octets de la carte ; %a5 = $800000, %d6 = nombre de blocs.
| ==================================================================================

| %d1 = offset → %d0.b = l'octet ; %a4 détruit. Accès en mot, octet bas.
.Llire:
        lea     0(%a5,%d1.w), %a4
        adda.w  %d1, %a4
        move.w  (%a4), %d0
        rts

| %d1 = offset, %d0.b = l'octet ; %a4 détruit.
.Lecrire:
        lea     0(%a5,%d1.w), %a4
        adda.w  %d1, %a4
        move.w  %d0, (%a4)
        rts

| Les deux déverrouillages : deux paires (`.Louvrir`, mesuré sur $03 et $04) ou une
| seule (`.Lpaire`, mesuré sur $06) ; leur place, SUPPOSÉ.
.Louvrir:
        bsr     .Lpaire                 | la première paire, puis la seconde en tombant
.Lpaire:
        move.b  %d0, 0x3A0005           | REG_CRDUNLOCK1
        move.b  %d0, 0x3A0017           | REG_CRDUNLOCK2
        rts

| %d1 = entrée → %d0.w = son NGH ; %d1 rendu, %d7 détruit.
.Lngh:
        addq.w  #1, %d1
        bsr     .Llire
        move.b  %d0, %d7
        lsl.w   #8, %d7
        addq.w  #1, %d1
        bsr     .Llire
        move.b  %d0, %d7
        move.w  %d7, %d0
        subq.w  #2, %d1
        rts

| %d2.b = SUB (0-15), %d3.w = NGH → %d4.w = l'entrée trouvée, %d5.w = la première libre
| avant elle, -1 si aucune ; %d0, %d1, %d7 détruits. S'arrête à la trouvée : le compte
| de 212 lectures du chargement le suggère, lecture mienne.
.Lchercher:
        moveq   #-1, %d4
        moveq   #-1, %d5
        moveq   #0x40, %d1
1:      bsr     .Llire
        cmpi.b  #0xFF, %d0
        bne.s   2f
        tst.w   %d5
        bpl.s   3f
        move.w  %d1, %d5
        bra.s   3f
2:      cmp.b   %d2, %d0
        bne.s   3f
        bsr     .Lngh
        cmp.w   %d3, %d0
        bne.s   3f
        move.w  %d1, %d4
        rts
3:      addq.w  #4, %d1
        cmpi.w  #0xC0, %d1
        bne.s   1b
        rts

| %d1 = première entrée à regarder → %d5.w = la première libre, -1 si aucune ; %d0, %d1.
.Lentree_libre:
1:      cmpi.w  #0xC0, %d1
        bcc.s   2f
        bsr     .Llire
        cmpi.b  #0xFF, %d0
        beq.s   3f
        addq.w  #4, %d1
        bra.s   1b
2:      moveq   #-1, %d1
3:      move.w  %d1, %d5
        rts

| %d1 = bloc → %d0.b = son entrée de FAT 1 ; %d1 détruit.
.Lfat_lire:
        addi.w  #0xC0, %d1
        bra     .Llire

| %d1 = bloc, %d0.b = valeur → FAT 1 puis FAT 2 ; %d1 détruit.
.Lfat_ecrire:
        addi.w  #0xC0, %d1
        bsr     .Lecrire
        addi.w  #0x40, %d1
        bra     .Lecrire

| %d3 = bloc de départ → %d3 = le premier bloc libre à partir de lui ; %d0, %d1. Appelé
| seulement quand le compte des libres garantit qu'il en reste un.
.Lbloc_libre:
1:      move.w  %d3, %d1
        bsr     .Lfat_lire
        tst.b   %d0
        beq.s   2f
        addq.w  #1, %d3
        bra.s   1b
2:      rts

| %d3 = premier bloc d'une chaîne → ses entrées à $00 dans les deux FAT ; %d0-%d3, %d7.
| S'arrête sur $01, sur un bloc hors de 5-31, ou après %d6 tours (une FAT qui boucle).
.Lchaine_liberer:
        move.w  %d6, %d7
1:      cmpi.w  #5, %d3
        bcs.s   2f
        cmp.w   %d6, %d3
        bcc.s   2f
        move.w  %d3, %d1
        bsr     .Lfat_lire
        moveq   #0, %d2
        move.b  %d0, %d2                | le suivant
        move.w  %d3, %d1
        moveq   #0, %d0
        bsr     .Lfat_ecrire
        move.w  %d2, %d3
        subq.w  #1, %d7
        bne.s   1b
2:      rts

| %d1 = début d'une FAT → %d2.b = la somme de ses 64 octets ; %d0, %d1, %d3.
.Lsomme:
        moveq   #0, %d2
        moveq   #64-1, %d3
1:      bsr     .Llire
        add.b   %d0, %d2
        addq.w  #1, %d1
        dbra    %d3, 1b
        rts

| Les deux sommes recalculées et écrites, $0D puis $0E ; %d0-%d3.
.Lsommes_ecrire:
        move.w  #0xC0, %d1
        bsr     .Lsomme
        move.b  %d2, %d0
        moveq   #0x0D, %d1
        bsr     .Lecrire
        move.w  #0x100, %d1
        bsr     .Lsomme
        move.b  %d2, %d0
        moveq   #0x0E, %d1
        bra     .Lecrire

| %d1 = début d'une FAT, %d4 = offset de sa somme → Z si elles s'accordent ; %d0-%d3.
.Lfat_ok:
        bsr     .Lsomme
        move.w  %d4, %d1
        bsr     .Llire
        cmp.b   %d0, %d2
        rts

| Lu dans « Memory card » : une FAT dont la somme est fausse est réécrite d'après
| l'autre ; deux fausses sont une erreur. → %d0 = 0 et Z si une FAT au moins est juste,
| %d0 = 1 sinon ; %d0-%d5. SUPPOSÉ : la réparation se fait sans regarder la protection
| d'écriture, et réécrit les deux sommes.
.Lfat_valider:
        move.w  #0xC0, %d1
        moveq   #0x0D, %d4
        bsr     .Lfat_ok
        seq     %d5                     | %d5 : FAT 1 juste
        move.w  #0x100, %d1
        moveq   #0x0E, %d4
        bsr     .Lfat_ok
        beq.s   2f
        tst.b   %d5
        beq.s   9f                      | les deux fausses
        move.w  #0xC0, %d2              | FAT 1 sur FAT 2
        move.w  #0x100, %d3
        bra.s   3f
2:      tst.b   %d5
        bne.s   8f                      | les deux justes
        move.w  #0x100, %d2             | FAT 2 sur FAT 1
        move.w  #0xC0, %d3
3:      bsr     .Louvrir
        moveq   #64-1, %d4
4:      move.w  %d2, %d1
        bsr     .Llire
        move.w  %d3, %d1
        bsr     .Lecrire
        addq.w  #1, %d2
        addq.w  #1, %d3
        dbra    %d4, 4b
        bsr     .Lsommes_ecrire
8:      moveq   #0, %d0
        rts
9:      moveq   #1, %d0
        rts

| ----------------------------------------------------------------------------------
| CARD_ERROR ($C0046E). Mesuré (point 5) : sur une sauvegarde refusée ($03, réponse
| $81), la référence formate puis refait la sauvegarde, sans rien afficher. Mesuré au
| jugement (point 4, fin), dans l'ordre :
|   RAM : $10FD00, le mot $10FDC6, le mot $10FDC4 deux fois, un formatage complet, le
|         mot $10FDC4, une sauvegarde complète ;
|   registres : ceux du formatage, ceux de la sauvegarde, puis REG_CRDLOCK2 et
|         REG_CRDLOCK1 une fois de plus ;
|   interface à la sortie : $10FDC4 $03, $10FDC5 $03, $10FDC6 $00, $10FDC7 $81.
| Les valeurs des mots ne sont pas relevées ; SUPPOSÉ, celles qui donnent cet état :
|   $10FDC6 ← $00:réponse (la réponse d'origine gardée à $10FDC7) ; $10FDC4 ← cmd:cmd
|   (la commande gardée à $10FDC5), puis $00:cmd (formater) ; après le formatage,
|   cmd:cmd de nouveau (la commande rendue).
| $10FD00 ← SP − 4 de son propre appel, comme CARD : SUPPOSÉ.
| Lu dans « CARD ERROR » (SP-S2), non mesuré : le formatage vaut aussi pour $03 sur
| $83 et pour $06 sur $81 ; on le fait — « silently on MVS », dit la page.
| SUPPOSÉ : le test de la carte de la référence n'est pas repris (écarté par la remise) ;
| un formatage qui échoue saute la sauvegarde, le reste de la séquence est fait ; tous
| les autres cas — les messages de MESS_OUT, le menu de la carte pleine — rendent la
| main après $10FD00, sans rien faire d'autre.
| Aucun registre modifié.
| ----------------------------------------------------------------------------------
_card_error:
        subq.l  #4, %sp                 | SP − 4, comme CARD
        move.l  %sp, 0x10FD00
        addq.l  #4, %sp
        movem.l %d0-%d1, -(%sp)
        move.b  0x10FDC4, %d0           | BIOS_CARD_COMMAND
        moveq   #0, %d1
        move.b  0x10FDC6, %d1           | BIOS_CARD_ANSWER
        cmpi.b  #3, %d0
        bne.s   1f
        cmpi.b  #0x81, %d1
        beq.s   2f
        cmpi.b  #0x83, %d1
        beq.s   2f
        bra.s   9f
1:      cmpi.b  #6, %d0
        bne.s   9f
        cmpi.b  #0x81, %d1
        bne.s   9f
2:      move.w  %d1, 0x10FDC6           | $00:réponse
        move.b  %d0, %d1
        lsl.w   #8, %d1
        move.b  %d0, %d1                | %d1 : cmd:cmd
        move.w  %d1, 0x10FDC4           | la commande gardée à $10FDC5
        andi.w  #0x00FF, %d1
        move.w  %d1, 0x10FDC4           | $00 : formater
        bsr     _card
        move.b  %d0, %d1
        lsl.w   #8, %d1
        move.b  %d0, %d1
        move.w  %d1, 0x10FDC4           | la commande rendue
        tst.b   0x10FDC6
        bne.s   8f                      | formatage refusé : pas de sauvegarde
        bsr     _card
8:      move.b  %d0, 0x3A0007           | REG_CRDLOCK2, puis REG_CRDLOCK1 : mesuré
        move.b  %d0, 0x3A0015
9:      movem.l (%sp)+, %d0-%d1
        rts

| ----------------------------------------------------------------------------------
| LE RELEVÉ DE LA CARTE, pour le gestionnaire de l'écran TEST (`gestion-carte.s`) : ce que
| la carte porte, sans rien y écrire ni toucher à l'interface de CARD en RAM BIOS.
| Entrée : %a0 = un tampon de 192 octets. Sortie : %d0.b = l'état, aux codes de
| BIOS_CARD_ANSWER — $00 formatée (le tampon reçoit les octets $40-$FF de la carte : le
| répertoire, puis la FAT 1), $80 sans carte, $81 non formatée, $85 une autre géométrie
| que CARD refuse. Les mêmes critères que CARD : la détection, CARD_MAGIC, CARD_SIZE.
| Les registres de la carte comme un chargement : REG_CRDNORMAL, REG_CRDBANK ← 0, puis
| REG_CRDLOCK2, REG_CRDLOCK1 ; sans carte, les deux verrouillages seuls, comme CARD.
| SUPPOSÉ : que la FAT 1 dise vrai ; une FAT 1 dont la somme est fausse n'est réparée que
| par la commande suivante qui écrit (`.Lfat_valider`), et le relevé la montre telle quelle.
| Clobbers %d0 seul.
| ----------------------------------------------------------------------------------
_carte_releve:
        movem.l %d1-%d7/%a0-%a5, -(%sp)
        movea.l %a0, %a1                | %a1 : le tampon
        moveq   #0, %d7
        move.b  #0x80, %d7
        btst    #4, 0x380000            | CD1
        bne.s   9f
        btst    #5, 0x380000            | CD2
        bne.s   9f
        move.b  %d0, 0x3A0019           | REG_CRDNORMAL
        move.b  #0x00, 0x380011         | REG_CRDBANK ← 0
        lea     0x800000, %a5
        move.b  #0x81, %d7
        lea     _card_magie, %a2
        moveq   #0x20, %d1
1:      bsr     .Llire
        cmp.b   (%a2)+, %d0
        bne.s   9f                      | non formatée
        addq.w  #2, %d1
        cmpi.w  #0x30, %d1
        bne.s   1b
        move.b  #0x85, %d7
        moveq   #0x0A, %d1              | CARD_SIZE
        bsr     .Llire
        move.b  %d0, %d6
        lsl.w   #8, %d6
        moveq   #0x0B, %d1
        bsr     .Llire
        move.b  %d0, %d6
        cmpi.w  #0x1000, %d6
        bne.s   9f                      | autre géométrie
        moveq   #0, %d7
        moveq   #0x40, %d1
2:      bsr     .Llire
        move.b  %d0, (%a1)+
        addq.w  #1, %d1
        cmpi.w  #0x100, %d1
        bne.s   2b
9:      move.b  %d0, 0x3A0007           | REG_CRDLOCK2, puis REG_CRDLOCK1
        move.b  %d0, 0x3A0015
        move.l  %d7, %d0
        movem.l (%sp)+, %d1-%d7/%a0-%a5
        rts

| ----------------------------------------------------------------------------------
| LES DONNÉES. CARD_MAGIC, ses huit octets pairs (lu dans « Memory card », mesuré
| point 2). L'en-tête $00-$1F d'une carte formatée, mesuré point 2 : la somme $0A est
| celle de cinq blocs réservés, 5 × $02.
| ----------------------------------------------------------------------------------
_card_magie:
        .ascii  "NEO-GEO"
        .byte   0x80
_card_entete:
        .byte   0, 0, 0, 0, 0, 0, 0, 0, 0, 0    | $00-$09
        .byte   0x10, 0x00                      | $0A : CARD_SIZE $1000
        .byte   0x00                            | $0C
        .byte   0x0A, 0x0A                      | $0D, $0E : sommes des FAT
        .byte   0x00                            | $0F : nom absent
        .ascii  "                "              | $10-$1F : 16 espaces
        .balign 2
