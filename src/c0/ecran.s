| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| L'ÉCRAN DE BOOT « Sprixe BIOS » — environ trois secondes, sautable, une seule fois par boot.
|
| Appelé par `jsr` depuis `_demarrage` (`c0.s`), après la pose de BIOS_MESS_POINT et avant
| la poignée de main du son. Ni SYSTEM_RETURN ni la pièce n'y passent : leur chemin
| (`_retour_systeme`, `_retour_piece`) part plus bas, à la remise de la main.
|
| AUCUN ORACLE : SNK n'a jamais écrit cet écran. C'est une création (`docs/DECISIONS.md`
| §5) ; la remise est « Couche 3 → l'écran de boot, le 2026-10-20 »
| (`docs/RELECTURE-CONTRATS.md`). Le critère est la capture sous MAME.
|
| TROIS SORTES D'AFFIRMATIONS, et chacune le dit :
|   « mesuré »  : un relevé de `measured/`, nommé ;
|   « lu dans » : une page du NeoGeo Development Wiki, nommée ;
|   « SUPPOSÉ » : ni l'un ni l'autre, et c'est dit.
|
| LA CHRONOLOGIE, en trames comptées par le compteur de ligne (une trame = un passage de la
| ligne $1F0, comme la remise de `c0.s`), 180 en tout avec PAUSE = 126, ≈ 3,04 s à
| 59,185 Hz :
|   0       synchronisation, palettes posées, textes fixes et valeurs écrits en noir ;
|   1-12    le titre se décode : ses lettres vont par paires, la paire p (0 à 5) tire des
|           glyphes au hasard, puis se fige à la trame 2 + 2p, de gauche à droite ; l'espace
|           du titre reste vide ;
|   13      l'URL et la version s'allument ;
|   13-20   un reflet blanc balaie le titre, une paire de lettres par trame ;
|   21-45   cinq lignes d'état, une toutes les 5 trames : l'étiquette s'imprime, puis la
|           valeur s'allume en vert en trois paliers (2, 3 et 4 trames après) ;
|   46-171  tout reste affiché, PAUSE trames ; le rappel « PRESS A BUTTON TO SKIP »
|           clignote en bas, 16 trames allumé, 16 éteint ;
|   172-179 fondu : chaque couleur à 7/8, 6/8 … 0/8 de sa valeur, noire à la dernière
|           trame ; le rappel s'y éteint depuis sa phase du moment (éteint avec PAUSE = 126).
| Les bornes 46-171 et 172-179 suivent PAUSE (T_FONDU = 46 + PAUSE, T_FIN = T_FONDU + 7).
| Un bouton pressé (A, B, C, D, START, SELECT hors MVS, P1 ou P2) saute à la sortie dès la
| trame suivante.
|
| LE SEUL PLAN : LE PLAN FIXE. Lu dans « Fix layer » : carte à $7000, 40 × 32 mots rangés
| de haut en bas puis de gauche à droite — l'adresse d'une case est $7000 + 32 × colonne +
| ligne —, palette dans les 4 bits hauts, et seules les 16 premières palettes servent ;
| 28 lignes affichées, deux cachées en haut, donc les lignes 2 à 29 sont visibles.
|
| LES GLYPHES, mesuré (`measured/2026-10-20-sfix-glyphes.tsv`) : police 8×16 en deux cases
| empilées, haut = tuile $100 + code ASCII, bas = tuile $200 + code ASCII. Mesurés au relevé :
| les majuscules A B C D E F G H I K L M N O P R S T U W X, les chiffres 0 1 2 6, « / » et
| l'espace. Le reste, que la remise laissait SUPPOSÉ à la même règle ASCII, est MESURÉ sur nos
| captures sous MAME (mslug, -bios euro, SFIX de la carte de MAME, trame 50, le 2026-10-20 ;
| non versionnées) : les minuscules de « ReBIOS », « sprixe.dev/rebios » et « v0.1 », le
| point, les chiffres 3 à 9, J Q V Y Z, « : », « - », « ? » et « ! » s'y lisent tous à leur
| place ASCII. Les minuscules autres que c, d, e, i, o, p, r, s, v, x n'ont pas été vues,
| sauf le « b » de « sprixe.dev/bios », lu à sa place ASCII sur notre capture du 2026-10-28
| (aof, -bios euro, trame 100 ; non versionnée).
| Les glyphes tirés au hasard ne viennent que des caractères du relevé.
|
| LES COULEURS. Lu dans « Palettes » : RAM de palettes à $400000, 256 palettes de 16
| entrées, l'entrée 0 transparente ; la couleur de référence ($400000) « always has to be
| pure black ($8000) », le fond (backdrop) est la dernière couleur de la banque, $401FFE ;
| la banque se choisit par REG_PALBANK0/1, adresses lues dans « Memory mapped registers »
| ($3A000F / $3A001F, octet impair, donnée indifférente) ; écrire en affichage fait de la
| neige, d'où toutes les écritures de palette juste après le passage de la ligne $1F0.
| Lu dans « Colors » : bit 15 « Dark », bits 14-12 les bits bas de R, G, B, puis R, G, B sur
| quatre bits chacun en $0RGB. On n'emploie que ce $0RGB ; le fondu en réduit chaque quartet.
| LES INDEX DES GLYPHES, mesuré sur une capture d'essai (mêmes conditions que ci-dessus :
| entrée 1 rouge, 2 verte, 3 à 15 bleues) : le trait des glyphes 8×16 est l'index 1, le fond
| de leurs cases l'index 2, et aucun pixel bleu. Chaque palette porte donc sa couleur dans
| l'entrée 1 et du noir dans les entrées 2 à 15 — le fond des cases se confond avec le fond
| d'écran. FIX_CLEAR met ses tuiles $FF et $020 sous la palette 0, et la $020 est pleine de
| l'index 2 (`measured/2026-10-21-sfix-tuiles-pleines.tsv`) : la palette 0 est donc posée à la
| trame 0 avec les autres, entrées 1 à 15 noires, comme `plantage.s` — son contenu à la mise
| sous tension n'est écrit nulle part. Elle est remise à zéro à la sortie, avec les autres.
| Palettes employées, 1 à 14, et la palette 0 en noir :
|   1-6  une par paire de lettres du titre ;   7  URL et version ;   8  les étiquettes ;
|   9-13 une par valeur de ligne, pour qu'elles s'allument chacune à son tour ;
|   14   le rappel, qui clignote seul.
| Par paire et non par lettre : « SPRIXE BIOS » a onze caractères, et seules les 16
| premières palettes servent au plan fixe, la 0 étant prise par FIX_CLEAR et la 15 par le
| message du commutateur 8.
| La banque 0 est choisie : SUPPOSÉ, rien ne dit laquelle est en place à la mise sous
| tension ; le jeu choisit la sienne.
|
| LE RYTHME DES ÉCRITURES VRAM, lu dans « VRAM » (cf. `video.s`) : 12 cycles au moins entre
| deux données, 16 entre une donnée et l'adresse suivante. `.Lglyphe` tient 12 cycles entre
| ses deux données (`addi.w` 8 + `nop` 4) et rend la main par `subi.w` (8) et `rts` (16)
| avant toute adresse suivante.
|
| L'ÉTAT RENDU AU JEU : plan fixe effacé par FIX_CLEAR (REG_VRAMMOD à 1), palettes 0 à 14
| (entrées 1-15) et le fond remis à zéro, la référence laissée à $8000 (« Palettes » : « always
| has to be pure black ($8000) »), registres rendus intacts. Restent
| changés, par la demande de la remise : les sprites masqués par LSP_1st, la banque de
| palettes 0, et $10FDD2-$10FDD8 que READ_CALENDAR a remplis — le jeu les relit à son appel.
| Le code de boot qui suit (`c0.s`) ne suppose aucun registre hors %sp : il pose tous ceux
| qu'il lit, et %d0 n'y sert que de donnée « any value ». On sauve quand même tout.
|
| LES IRQ RESTENT MASQUÉES (SR = $2700, posé par `_demarrage`). Le watchdog reçoit un coup
| de pied à chaque tour des attentes de ligne, donc plusieurs fois par trame.
| ==================================================================================

        .section .haut, "ax"
        .global _ecran_boot

        .equ    VRAMADDR, 0x3C0000
        .equ    VRAMRW,   0x3C0002
        .equ    LSPCMODE, 0x3C0006
        .equ    WATCHDOG, 0x300001
        .equ    P2CNT,    0x340000
        .equ    STATUS_B, 0x380000
        .equ    PALBANK0, 0x3A000F
        .equ    PALETTES, 0x400000
        .equ    FOND,     0x401FFE

        | Une case du plan fixe, colonne c, ligne l (« Fix layer »).
        .equ    CASE_TITRE,   0x7000 + 14 * 32 + 6     | « SPRIXE BIOS », 11 caractères, colonnes 14-24
        .equ    CASE_URL,     0x7000 + 12 * 32 + 10    | 15 caractères, colonnes 12-26
        .equ    CASE_VERSION, 0x7000 + 18 * 32 + 12    | 4 caractères, colonnes 18-21
        .equ    CASE_LIGNES,  0x7000 +  7 * 32 + 17    | étiquettes, colonnes 7-20
        .equ    CASE_VALEURS, 0x7000 + 22 * 32 + 17    | valeurs, depuis la colonne 22
        .equ    CASE_RAPPEL,  0x7000 +  9 * 32 + 27    | 22 caractères, colonnes 9-30, lignes 27-28
        .equ    CASE_GEL1,    0x7000 + 11 * 32 + 11    | « DIP SWITCH 8 IS ON », colonnes 11-28, lignes 11-12
        .equ    CASE_GEL2,    0x7000 +  9 * 32 + 15    | 22 caractères, colonnes 9-30, lignes 15-16

        | Les couleurs, en $0RGB (« Colors »). Choix d'aspect, sans autre raison.
        .equ    C_TITRE,  0x04BF        | bleu ciel, le titre figé
        .equ    C_TIRAGE, 0x0346        | bleu sombre, une lettre qui se cherche
        .equ    C_MI,     0x09DF        | bord du reflet
        .equ    C_BLANC,  0x0FFF        | cœur du reflet
        .equ    C_DOUX,   0x0777        | URL et version
        .equ    C_ETIQ,   0x0BBB        | étiquettes
        .equ    C_VERT,   0x02F4        | valeurs
        .equ    C_RAPPEL, 0x0999        | le rappel, allumé

        | LA PAUSE, en trames : tout reste affiché, le rappel clignote. Le seul réglage de durée ;
        | décodage, lignes et fondu gardent la leur.
        .equ    PAUSE,    126
        .equ    T_PAUSE,  46            | première trame de pause, les lignes finies
        .equ    T_FONDU,  T_PAUSE + PAUSE
        .equ    T_FIN,    T_FONDU + 7   | dernière trame ; la trame 0 est la synchronisation
        .equ    N_PAL,    14            | palettes employées, 1 à N_PAL
        .equ    N_TITRE,  11            | caractères du titre, deux par palette 1 à 6

_ecran_boot:
        movem.l %d0-%d7/%a0-%a6, -(%sp)
        movea.l %sp, %a6                | la pile de l'entrée, pour sauter à la sortie
        move.b  %d0, WATCHDOG
        | LE COMMUTATEUR 3 lu ici, à l'ouverture, et pas après : P1 dans cet écran et ceux qu'il ouvre
        | (`panneau.s`, DECISIONS §30).
        jsr     _panneau_verrou

        | UN ÉCRAN PROPRE : la VRAM est quelconque à la mise sous tension. LSP_1st masque
        | les sprites, FIX_CLEAR remplit le plan fixe et laisse REG_VRAMMOD à 1 (`video.s`).
        jsr     _lsp_1st
        jsr     _fix_clear
        | L'heure, une fois : READ_CALENDAR range la date en BCD à $10FDD2-$10FDD8 (`cal.s`).
        jsr     _read_calendar

        lea     VRAMRW, %a0
        lea     VRAMADDR, %a1

        | TRAME 0. Palettes après le passage de la ligne $1F0 : tout ce qu'on écrit ensuite
        | est noir, sauf les lettres du titre, sombres.
        bsr     .Lsync
        move.b  %d0, PALBANK0
        move.w  #0x8000, PALETTES       | référence : « pure black ($8000) », « Palettes »
        move.w  #0x8000, FOND           | le fond en noir
        moveq   #0, %d5                 | la palette 0, sous FIX_CLEAR : entrées 1-15 noires
        moveq   #0, %d6
        bsr     .Lpalette
        moveq   #1, %d4
1:      move.w  %d4, %d5
        move.w  #C_TIRAGE, %d6
        cmpi.w  #6, %d4
        bls.s   2f
        moveq   #0, %d6
2:      bsr     .Lpalette
        addq.w  #1, %d4
        cmpi.w  #N_PAL, %d4
        bls.s   1b

        | LE COMMUTATEUR 8, « FREEZE », À ON AU BOOT. Le BIOS SNK et UniBIOS 4.0 s'arrêtent
        | écran noir juste après leur test mémoire et repartent quand il revient à OFF (mesuré,
        | `measured/2026-10-27-dip-2-8.tsv`, section 3). ÉCART VOULU (DECISIONS §21) : le même
        | arrêt, mais deux lignes le disent, au lieu d'un écran noir qu'on prendrait pour une panne.
        tst.b   0x300001                | REG_DIPSW, bit 7 actif bas : le signe
        bmi.s   .Lsans_gel
        moveq   #15, %d5
        move.w  #C_BLANC, %d6
        bsr     .Lpalette
        move.w  #0xF000, %d3
        move.w  #CASE_GEL1, %d1
        lea     .Lgel1, %a2
        bsr     .Ltexte
        move.w  #CASE_GEL2, %d1
        lea     .Lgel2, %a2
        bsr     .Ltexte
1:      bsr     .Lsync                  | watchdog servi à chaque tour
        tst.b   0x300001
        bpl.s   1b
        moveq   #15, %d5
        moveq   #0, %d6
        bsr     .Lpalette
        jsr     _fix_clear
        lea     VRAMRW, %a0
        lea     VRAMADDR, %a1
.Lsans_gel:

        | Les textes fixes, sous des palettes encore noires.
        move.w  #0x7000, %d3
        move.w  #CASE_URL, %d1
        lea     .Lurl, %a2
        bsr     .Ltexte
        move.w  #CASE_VERSION, %d1
        lea     .Lversion, %a2
        bsr     .Ltexte
        move.w  #0xE000, %d3
        move.w  #CASE_RAPPEL, %d1
        lea     .Lrappel, %a2
        bsr     .Ltexte

        | LES VALEURS, lues une fois et écrites tout de suite, chacune sous sa palette.
        |
        | SYSTÈME, palette 9 : LE MODE, BIOS_MVS_FLAG ($10FD82 ; « BIOS RAM locations », 0 AES,
        | $80 MVS), que `c0.s` pose avant cet écran — le descripteur, ou le mode choisi à
        | l'éditeur (`reglages.s`). Il n'affiche donc plus le descripteur : un MVS en mode AES
        | dit AES, ce que voient les jeux (DECISIONS §11).
        move.w  #0x9000, %d3
        move.w  #CASE_VALEURS, %d1
        lea     .Lmvs, %a2
        tst.b   0x10FD82
        bmi.s   1f
        lea     .Laes, %a2
1:      bsr     .Ltexte

        | RÉGION, palette 10. Lu dans « System ROM » : 0 Japon, 1 US, 2 Europe. Hors de 0-2,
        | « UNKNOWN » — SUPPOSÉ, aucune page ne nomme d'autre valeur. Lue dans
        | BIOS_COUNTRY_CODE, que `c0.s` pose avant cet écran : le descripteur, ou la région
        | choisie à l'éditeur (`reglages.s`).
        move.w  #0xA000, %d3
        move.w  #CASE_VALEURS + 2, %d1
        moveq   #0, %d0
        move.b  0x10FD83, %d0
        cmpi.b  #3, %d0
        bcs.s   1f
        moveq   #3, %d0
1:      lsl.w   #2, %d0
        lea     .Lregions, %a2
        movea.l (%a2,%d0.w), %a2
        bsr     .Ltexte

        | L'HORLOGE, palette 11, « MM/DD/YY DDD ». Mesuré (`2026-10-19-read-calendar.tsv`,
        | point 3) : $10FDD3 mois, $10FDD4 jour, $10FDD2 année, en BCD — deux quartets, donc
        | deux chiffres —, $10FDD5 jour de semaine, dimanche = 0 (lu dans « READ CALENDAR »,
        | cité au même relevé). Un jour de semaine hors de 0-6 n'affiche rien : SUPPOSÉ.
        move.w  #0xB000, %d3
        move.w  #CASE_VALEURS + 4, %d1
        move.b  0x10FDD3, %d4
        bsr     .Lhex2
        moveq   #0x2F, %d2           | « / »
        bsr     .Lcar
        move.b  0x10FDD4, %d4
        bsr     .Lhex2
        moveq   #0x2F, %d2           | « / »
        bsr     .Lcar
        move.b  0x10FDD2, %d4
        bsr     .Lhex2
        addi.w  #32, %d1                | une case de fond entre l'année et le jour
        moveq   #0, %d0
        move.b  0x10FDD5, %d0
        cmpi.b  #6, %d0
        bhi.s   1f
        lsl.w   #2, %d0
        lea     .Ljours, %a2
        adda.w  %d0, %a2
        bsr     .Ltexte
1:

        | LA CARTE MÉMOIRE, palette 12. Lu dans « Memory mapped registers » : REG_STATUS_B,
        | bits 5-4 à 00 quand la carte est « correctly inserted ». Mesuré
        | (`2026-10-19-card-avec-carte.tsv`) : l'octet haut de $380000 vaut $FF sans carte,
        | $8F avec — bits 5-4 à 11 puis 00.
        move.w  #0xC000, %d3
        move.w  #CASE_VALEURS + 6, %d1
        lea     .Lsans_carte, %a2
        move.b  STATUS_B, %d0
        andi.b  #0x30, %d0
        bne.s   1f
        lea     .Lavec_carte, %a2
1:      bsr     .Ltexte

        | LE JEU, palette 13. Lu dans « 68k program header » : le NGH est le mot de $108,
        | « NGH number in BCD ». Quatre chiffres hexadécimaux : un NGH conforme n'en montre que
        | de décimaux. PRIS DANS LA TABLE DES SLOTS ($D00124, l'entrée du slot servi $D00108),
        | que la détection de `c0.s` vient d'écrire sous REG_CRTFIX — PAS RELU À $108 : cet
        | écran tourne sous REG_BRDFIX, la police de la carte, et sur le matériel la cartouche
        | n'y répond pas (SLOTCS, voir la détection). L'image n°8 le relisait : E05C sur une
        | vraie MV-2F, le mot qui suivait cette lecture. Slot servi vide : 0000.
        move.w  #0xD000, %d3
        move.w  #CASE_VALEURS + 8, %d1
        moveq   #0, %d4
        move.b  0xD00108, %d4           | le slot servi
        lsl.w   #2, %d4
        lea     0xD00124, %a2
        move.w  (%a2,%d4.w), %d4        | son NGH
        ror.w   #8, %d4
        bsr     .Lhex2
        ror.w   #8, %d4
        bsr     .Lhex2

        | ------------------------------------------------------------------------------
        | LES TRAMES 1 À T_FIN. %d7 : la trame. %a0, %a1, %a6 et %d7 ne changent pas.
        moveq   #1, %d7
.Lboucle:
        bsr     .Ltrame

        | LE TITRE QUI SE DÉCODE, trames 1 à 12.
        cmpi.w  #12, %d7
        bhi.s   .Lapres_decode
        moveq   #0, %d4                 | %d4 : la lettre, 0 à N_TITRE - 1
        move.w  #CASE_TITRE, %d1
.Ldecode:
        lea     .Ltitre, %a2
        moveq   #0, %d2
        move.b  (%a2,%d4.w), %d2        | la lettre figée
        cmpi.b  #0x20, %d2              | l'espace ne se décode pas
        beq.s   .Ldecode_poser
        move.w  %d4, %d5
        lsr.w   #1, %d5                 | sa paire, 0 à 5
        add.w   %d5, %d5
        addq.w  #2, %d5                 | sa trame de fixation : 2 + 2 × paire
        cmp.w   %d5, %d7
        bcs.s   .Ldecode_hasard
        bne.s   .Ldecode_poser
        move.w  %d4, %d5                | figée à cette trame : sa couleur de titre
        lsr.w   #1, %d5
        addq.w  #1, %d5
        move.w  #C_TITRE, %d6
        bsr     .Lpalette               | %d2 rendu intact
        bra.s   .Ldecode_poser
.Ldecode_hasard:
        | Tirage : _table_alea (`alea.s`, une permutation de 0-255) à l'index N_TITRE × trame
        | + lettre, ses 5 bits bas choisissant parmi 32 caractères mesurés.
        move.w  %d7, %d2
        mulu    #N_TITRE, %d2
        add.w   %d4, %d2
        andi.w  #0xFF, %d2
        lea     _table_alea, %a2
        move.b  (%a2,%d2.w), %d2
        andi.w  #31, %d2
        lea     .Lhasard, %a2
        move.b  (%a2,%d2.w), %d2
.Ldecode_poser:
        move.w  %d4, %d0
        lsr.w   #1, %d0
        addq.w  #1, %d0
        ror.w   #4, %d0                 | palette 1 + paire dans les 4 bits hauts
        or.w    %d0, %d2
        bsr     .Lglyphe
        addi.w  #32, %d1
        addq.w  #1, %d4
        cmpi.w  #N_TITRE, %d4
        bcs.s   .Ldecode
.Lapres_decode:

        | L'URL ET LA VERSION, trame 13.
        cmpi.w  #13, %d7
        bne.s   1f
        moveq   #7, %d5
        move.w  #C_DOUX, %d6
        bsr     .Lpalette
1:

        | LE REFLET, trames 13 à 20 : la paire h = trame - 13 en blanc, ses voisines en
        | demi-teinte, les autres en couleur de titre. h = 6 et 7 finissent de sortir.
        cmpi.w  #13, %d7
        bcs.s   .Lapres_reflet
        cmpi.w  #20, %d7
        bhi.s   .Lapres_reflet
        move.w  %d7, %d3
        subi.w  #13, %d3
        moveq   #0, %d4
1:      move.w  #C_TITRE, %d6
        move.w  %d4, %d0
        sub.w   %d3, %d0
        beq.s   2f
        bpl.s   3f
        neg.w   %d0
3:      cmpi.w  #1, %d0
        bne.s   4f
        move.w  #C_MI, %d6
        bra.s   4f
2:      move.w  #C_BLANC, %d6
4:      move.w  %d4, %d5
        addq.w  #1, %d5
        bsr     .Lpalette
        addq.w  #1, %d4
        cmpi.w  #6, %d4
        bcs.s   1b
.Lapres_reflet:

        | LES LIGNES, trames 21 à 45 : ligne k = (trame - 21) / 5, phase = son reste.
        | Phase 0 : l'étiquette s'imprime ; phases 2, 3, 4 : la valeur s'allume.
        move.w  %d7, %d3
        subi.w  #21, %d3
        bcs.s   .Lapres_lignes
        cmpi.w  #24, %d3
        bhi.s   .Lapres_lignes
        moveq   #0, %d4
2:      cmpi.w  #5, %d3
        bcs.s   3f
        subq.w  #5, %d3
        addq.w  #1, %d4
        bra.s   2b
3:      tst.w   %d3
        bne.s   5f
        tst.w   %d4                     | la première ligne allume les étiquettes
        bne.s   4f
        moveq   #8, %d5
        move.w  #C_ETIQ, %d6
        bsr     .Lpalette
4:      move.w  %d4, %d0
        mulu    #15, %d0
        lea     .Letiquettes, %a2
        adda.w  %d0, %a2
        move.w  %d4, %d1
        add.w   %d1, %d1
        addi.w  #CASE_LIGNES, %d1
        move.w  #0x8000, %d3
        bsr     .Ltexte
        bra.s   .Lapres_lignes
5:      cmpi.w  #2, %d3
        bcs.s   .Lapres_lignes
        lea     .Lrampe - 2, %a2
        move.b  (%a2,%d3.w), %d3        | 3, 6 puis 8 huitièmes
        move.w  #C_VERT, %d6
        bsr     .Lattenuer
        move.w  %d4, %d5
        addi.w  #9, %d5
        bsr     .Lpalette
.Lapres_lignes:

        | LE RAPPEL QUI CLIGNOTE, de T_PAUSE à T_FONDU - 1 : allumé quand le bit 4 de
        | (trame - T_PAUSE) est nul, soit 16 trames allumé, 16 éteint.
        cmpi.w  #T_PAUSE, %d7
        bcs.s   1f
        cmpi.w  #T_FONDU, %d7
        bcc.s   1f
        move.w  %d7, %d0
        subi.w  #T_PAUSE, %d0
        move.w  #C_RAPPEL, %d6
        btst    #4, %d0
        beq.s   2f
        moveq   #0, %d6
2:      moveq   #14, %d5
        bsr     .Lpalette
1:

        | LE FONDU, trames T_FONDU à T_FIN : chaque palette à (T_FIN - trame)/8 de sa
        | couleur finale. Le rappel y part de la phase où le clignotement l'a laissé.
        cmpi.w  #T_FONDU, %d7
        bcs.s   .Lapres_fondu
        moveq   #1, %d4
1:      move.w  %d4, %d0
        add.w   %d0, %d0
        lea     .Lfinales - 2, %a2
        move.w  (%a2,%d0.w), %d6
        move.w  #T_FIN, %d3
        sub.w   %d7, %d3
        bsr     .Lattenuer
        move.w  %d4, %d5
        bsr     .Lpalette
        addq.w  #1, %d4
        cmpi.w  #N_PAL, %d4
        bls.s   1b
.Lapres_fondu:

        addq.w  #1, %d7
        cmpi.w  #T_FIN, %d7
        bls     .Lboucle

| ----------------------------------------------------------------------------------
| LA SORTIE, commune à la fin et au saut. Les palettes d'abord, juste après le passage de
| la ligne $1F0, pour que leur remise à zéro tombe dans le blanking et ne fasse pas de
| neige ; FIX_CLEAR ensuite, ses 1 280 écritures VRAM n'ayant pas à tenir dans le blanking.
.Lsortie:
        movea.l %a6, %sp
        bsr     .Lsync
        moveq   #0, %d4                 | palette 0 comprise, posée à la trame 0
1:      move.w  %d4, %d5
        moveq   #0, %d6
        bsr     .Lpalette
        addq.w  #1, %d4
        cmpi.w  #N_PAL, %d4
        bls.s   1b
        | La référence n'est pas remise à zéro : elle reste au $8000 du tour 0.
        clr.w   FOND
        jsr     _fix_clear              | REG_VRAMMOD laissé à 1
        move.b  %d0, WATCHDOG
        movem.l (%sp)+, %d0-%d7/%a0-%a6
        rts

| ----------------------------------------------------------------------------------
| UNE TRAME, puis les boutons. Lu dans « Memory mapped registers » : REG_P1CNT ($300000)
| et REG_P2CNT ($340000), bits 7-4 D, C, B, A, actifs à l'état bas ; REG_STATUS_B
| ($380000), bits 3-0 SELECT P2, START P2, SELECT P1, START P1, actifs à l'état bas. Les
| directions (bits 3-0 des manettes) et les pièces (REG_STATUS_A) ne sont pas lues : une
| pièce n'est donc pas consommée ici.
.Ltrame:
        bsr.s   .Lsync
        jsr     _panneau_p1             | %d0 : P1, manette ou panneau traduit (`panneau.s`)
        andi.b  #0xF0, %d0
        cmpi.b  #0xF0, %d0
        bne.s   .Lsortie
        move.b  P2CNT, %d0
        andi.b  #0xF0, %d0
        cmpi.b  #0xF0, %d0
        bne.s   .Lsortie
        | SELECT SUR MVS NE COMPTE PAS. Lu dans « BIOS RAM locations » : « On MVS the select
        | bits are always read as 0 ». SUPPOSÉ : que le registre brut ne porte pas non plus de
        | SELECT fiable sur MVS ; au repos à l'état actif, il sauterait l'écran dès la trame 1.
        | On ne garde alors que les deux START (bits 0 et 2). C'est une question de MACHINE,
        | pas de mode : REG_STATUS_B bit 7, « 0:AES 1:MVS » (« Memory mapped registers ») ; un
        | MVS en mode AES reste un MVS (DECISIONS §11).
        move.b  STATUS_B, %d0
        not.b   %d0
        andi.b  #0x0F, %d0
        tst.b   STATUS_B                | la machine : bit 7, le signe — `tst` plutôt que
        bpl.s   1f                      | `btst`, les cycles du `tst.b 0x10FD82` d'avant
        andi.b  #0x05, %d0
1:      tst.b   %d0
        bne.s   .Lsortie
        rts

| LE PASSAGE DE LA LIGNE $1F0. Mesuré (`2026-10-17-diagnostic-b2b-minasan.tsv`, cité par
| `c0.s`) : REG_LSPCMODE se relit en compteur de ligne dans ses bits 15-7. On attend d'en
| sortir, puis d'y entrer : un seul retour par trame, même si l'appelant a été bref.
| BORNÉE : chaque attente rend la main après SYNC_TOURS tours, ligne vue ou non, pour qu'un
| compteur de ligne qui ne passerait jamais par $1F0 sur une carte ne fige pas le BIOS. Un
| tour fait 70 cycles sans état d'attente (`move.b` Dn vers abs.l 16, `move.w` abs.l 16,
| `lsr.w #7` 20, `cmpi.w` 8, `dbcc` pris 10) : 5 800 tours ≈ 406 000 cycles ≈ 2,0 trames à
| 12 MHz (202 750 cycles par trame à 59,185 Hz). Un état d'attente sur les registres ne
| ferait qu'allonger la borne. Sous MAME la ligne est vue à chaque trame : la borne ne
| sert pas. Le watchdog reçoit un coup de pied à chaque tour. Copie identique dans
| `dip.s`, `tests.s`, `menu.s`, `plantage.s`, `jukebox.s`. Clobbers %d0.
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
| UN GLYPHE 8×16. %d1 : la case du haut ; %d2 : palette << 12 | code ASCII, rendu intact.
| REG_VRAMMOD à 1 : la case du bas est la suivante (« Fix layer », de haut en bas).
.Lglyphe:
        move.w  %d1, (%a1)              | REG_VRAMADDR
        addi.w  #0x100, %d2
        move.w  %d2, (%a0)              | haut : $100 + ASCII
        addi.w  #0x100, %d2             | 8 cycles
        nop                             | 4 : 12 entre les deux données
        move.w  %d2, (%a0)              | bas : $200 + ASCII
        subi.w  #0x200, %d2
        rts

| UN CARACTÈRE. %d2 : code ASCII ; %d3 : palette << 12 ; %d1 avance d'une colonne.
.Lcar:
        or.w    %d3, %d2
        bsr.s   .Lglyphe
        addi.w  #32, %d1
        rts

| UNE CHAÎNE terminée par 0. %a2 : la chaîne ; %d1, %d3 comme `.Lcar`. Clobbers %d2, %a2.
.Ltexte:
        moveq   #0, %d2
        move.b  (%a2)+, %d2
        beq.s   1f
        bsr.s   .Lcar
        bra.s   .Ltexte
1:      rts

| UN OCTET EN DEUX CHIFFRES HEXADÉCIMAUX. %d4.b : l'octet, rendu intact. Clobbers %d2.
.Lhex2:
        move.b  %d4, %d2
        lsr.b   #4, %d2
        bsr.s   .Lchiffre
        move.b  %d4, %d2
.Lchiffre:
        andi.w  #0x0F, %d2
        cmpi.w  #10, %d2
        bcs.s   1f
        addq.w  #7, %d2                 | 10-15 → « A »-« F »
1:      addi.w  #0x30, %d2              | « 0 »
        bra.s   .Lcar

| UNE PALETTE. %d5 : son numéro (1-15) ; %d6 : la couleur du trait, l'entrée 1 ; les
| entrées 2 à 15 à zéro (voir l'en-tête, les index des glyphes). Clobbers %d0, %d5, %a2.
.Lpalette:
        lea     PALETTES + 2, %a2
        lsl.w   #5, %d5                 | 16 entrées de 2 octets
        adda.w  %d5, %a2
        move.w  %d6, (%a2)+
        moveq   #14-1, %d0
1:      clr.w   (%a2)+
        dbra    %d0, 1b
        rts

| UNE COULEUR ATTÉNUÉE. %d6 : $0RGB ; %d3 : facteur 0 à 8. Chaque quartet devient
| quartet × facteur / 8 ; résultat dans %d6. Clobbers %d0, %d2, %d5.
.Lattenuer:
        moveq   #0, %d0
        rol.w   #4, %d6                 | RGB0
        moveq   #3-1, %d5
1:      rol.w   #4, %d6                 | R, puis G, puis B dans le quartet bas
        moveq   #0x0F, %d2
        and.w   %d6, %d2
        mulu    %d3, %d2
        lsr.w   #3, %d2
        lsl.w   #4, %d0
        or.w    %d2, %d0
        dbra    %d5, 1b
        move.w  %d0, %d6
        rts

| ----------------------------------------------------------------------------------
| LES DONNÉES.
        .balign 2
.Lfinales:                              | la couleur finale des palettes 1 à 14, pour le fondu
        .word   C_TITRE, C_TITRE, C_TITRE, C_TITRE, C_TITRE, C_TITRE
        .word   C_DOUX, C_ETIQ
        .word   C_VERT, C_VERT, C_VERT, C_VERT, C_VERT
        | Le rappel part de sa phase à T_FONDU, bit 4 de PAUSE : éteint, il le reste.
        .word   C_RAPPEL * (1 - ((PAUSE >> 4) & 1))
.Lregions:
        .long   .Ljapon, .Lusa, .Leurope, .Linconnue
.Lrampe:
        .byte   3, 6, 8
.Ltitre:
        .ascii  "SPRIXE BIOS"
| 32 caractères, tous mesurés ; les six derniers répètent les premiers.
.Lhasard:
        .ascii  "ABCDEFGHIKLMNOPRSTUWX0126/ABCDEF"
.Lurl:
        .asciz  "sprixe.dev/bios"
.Lversion:
        .asciz  "v0.1"
.Lrappel:
        .asciz  "PRESS A BUTTON TO SKIP"
| Cinq étiquettes de 14 caractères, 15 octets chacune avec le zéro.
.Letiquettes:
        .asciz  "SYSTEM ......."
        .asciz  "REGION ......."
        .asciz  "CLOCK ........"
        .asciz  "CARD ........."
        .asciz  "GAME NGH ....."
.Lmvs:
        .asciz  "MVS"
.Laes:
        .asciz  "AES"
.Ljapon:
        .asciz  "JAPAN"
.Lusa:
        .asciz  "USA"
.Leurope:
        .asciz  "EUROPE"
.Linconnue:
        .asciz  "UNKNOWN"
.Lsans_carte:
        .asciz  "NONE"
.Lgel1:
        .asciz  "DIP SWITCH 8 IS ON"
.Lgel2:
        .asciz  "SET IT OFF TO CONTINUE"
.Lavec_carte:
        .asciz  "INSERTED"
| Lu dans « READ CALENDAR » : dimanche = 0. Quatre octets par jour.
.Ljours:
        .asciz  "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"
        .balign 2
