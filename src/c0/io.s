| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| SYSTEM_IO ($C0044A) ET CREDIT_CHECK ($C00450) — deux entrées du tableau d'appels.
|
| Les créneaux de six octets de `c0.s` ne portent qu'un `jmp` : le code vit ici, dans
| `.text`, que `build/bios.ld` lie après `.vectors`, donc au-delà de $C00800.
|
| TROIS SORTES D'AFFIRMATIONS, et chacune le dit :
|   « mesuré »  : un contrat de `specs/traces/`, nommé — `appel_C0044A.md` (80 appels),
|                 `appel_C00450.md` (69), `appel_C00438.md` (48, INT1) ; les ratios en /32,
|                 /23 et /16 ci-dessous datent de leurs versions de 32, 23 et 16 appels,
|                 `protocole.md` (les remises de main) ;
|   « lu dans » : une page du NeoGeo Development Wiki, nommée ;
|   « SUPPOSÉ » : ni l'un ni l'autre, et c'est dit.
|
| LA STRUCTURE. « SYSTEM_INT1 » dit qu'INT1 appelle SYSTEM_IO : la lecture des entrées,
| le front de pièce, le crédit, les afficheurs et le minuteur sont donc UNE routine,
| `_io_commun`, qu'appellent l'entrée publique `_systeme_io` et `_systeme_int1`
| (`int1.s`). Les deux noyaux mesurés se recouvrent presque : celui de $C00438 a en plus
| $300001, $3C000C, $10FEE4, $10FE8C, $10FEC6 et les variables de MESS_OUT, que
| `int1.s` garde pour lui — $10FE8C et $10FEC6 ne sont PAS dans le noyau de $C0044A.
|
| COIN_SOUND ET PLAYER_START NE SONT QUE DANS L'ENTRÉE PUBLIQUE. Ni l'un ni l'autre
| n'est appelé depuis INT1 : le relevé du protocole ne montre aucune
| remise à $000134 ni à $000128 pendant les trames où INT1 crédite une pièce (trace 2,
| trame 500.9) — elles ne partent que d'un appel entré à $C0044A (traces 3 et 4). La
| remise au titre d'une pièce hors partie, elle, ne part que de SYSTEM_IO depuis le
| 2026-10-22 (fin de `_io_commun`).
|
| LE DÉPART FORCÉ (« game start compulsion »), écarté jusqu'au 2026-10-17 : armé à la
| pièce (`_io_crediter`), décompté et déclenché au titre (`_io_compulsion`). Mesuré :
| `measured/2026-10-17-diagnostic-b2b-minasan.tsv`, partie MINASAN.
|
| CE QUE CES ROUTINES NE FONT PAS, délibérément :
|   - DEMO_END ($00012E) hors des cas mesurés, la pièce qui fait le crédit pendant la démo
|     (`_io_fin_demo`, le 2026-10-22) et SELECT (`_io_select`, le 2026-10-23) ;
|   - donner un sens à $10FEE0, $D0002C, $D00039 : aucune page ne les nomme. Depuis le
|     2026-10-23, leurs valeurs mesurées sont écrites à leurs places, sans plus
|     (`_io_crediter`, `_io_commun` ; $10FEE0 dans `_retour_demo_end`, `c0.s`) ;
|   - les écritures éparses de comptabilité $D08324-$D0A1D2 (1/32, paires $0000/$0001 ou
|     $0002) : « Backup RAM » les place dans les blocs de données journalières et
|     mensuelles, datées « YYMMDDdd » ; sans calendrier, pas de date, donc écartées ;
|   - $D00042 (« Game select », « 1=Free », que le lot du 2026-10-25 n'a pas mesuré), le
|     verrouillage des monnayeurs ($3800E5/E7), les pièces 3 et 4 et le bouton service ;
|   - la pile du BIOS de référence ($10F25E-$10F2BC, « retenue (§8) ») : nos propres
|     adresses de retour la remplacent.
| ==================================================================================

        .text
        .global _systeme_io
        .global _credit_check
        .global _io_commun
        .global _io_temps

        .equ    BORNE, 0x10FB20         | la borne en RAM (`reglages.s`, `_borne_ram`)
        .equ    DIPSW, 0x300001         | en lecture : les commutateurs de la carte, actifs bas
        | L'autofire en RAM, posé par `autofire.s` (sa disposition y est décrite).
        .equ    AF_MASQUE, 0x10FB41
        .equ    AF_PH1,   0x10FB42
        .equ    AF_PH2,   0x10FB43
        .equ    AF_REL,   0x10FB44
        .equ    AF_SUIV,  0x10FB4C

| ----------------------------------------------------------------------------------
| SYSTEM_IO, L'ENTRÉE PUBLIQUE — atteinte par `jmp` depuis $C0044A, donc le jeu y est
| entré par `jsr` et en repart par notre `rts`.
|
| AUCUN REGISTRE N'EST SAUVEGARDÉ. Lu dans « SYSTEM_IO » : « This call does NOT save
| registers ». On suit la page, et c'est aussi ce qui laisse PLAYER_START et COIN_SOUND,
| appelés d'ici, user de tous les registres.
| ----------------------------------------------------------------------------------
_systeme_io:
        | %d7 DU JEU RENDU INTACT : il l'était avant que `_io_commun` ne le lise comme
        | drapeau (sous SYSTEM_IO ici, sous INT1 dans `int1.s`) ; on ne change pas ce que
        | l'appel rend au jeu.
        move.l  %d7, -(%sp)
        moveq   #1, %d7                 | sous SYSTEM_IO (fin de `_io_commun`)
        bsr     _io_commun             | %d6 : pièces acceptées à cette trame
        move.l  (%sp)+, %d7
        | LE MENU EN JEU (`menu.s`, zone haute, d'où le `jsr` absolu) : le geste, à chaque
        | appel, et le menu s'il est fait. Rend tous les registres.
        jsr     _menu_en_jeu

        | BIOS_FRAME_SKIP ($10FEE1), lu dans « BIOS RAM locations » : « Number of frames to
        | skip in the routine which checks demo_end or if the player has pressed start »,
        | « Decremented in SYSTEM_IO ». Mesuré (`protocole.md`, trace 9) : $FF posé à
        | chaque demande, $0A à la trame suivante (239.41, 244.41), puis −1 par trame jusqu'à
        | $00 (254.00). Une remise de demande 2 ou 3 entre désormais à $09 (`c0.s`,
        | `_remettre_a_user`, mesuré là) : la recharge ci-dessous ne sert plus qu'après une
        | demande 0 donnée par SYSTEM_RETURN, entrée à $FF — mesuré chez la référence, $0A
        | posé sous le jeu deux trames après cette remise (relevé du 2026-10-22).
        | SUPPOSÉ : la recharge $FF → $0A faite ici, sans décompte la même trame.
        | Non nul : ni START ni COIN_SOUND ; `_io_commun`, au-dessus, a crédité quand même
        | (mesuré sous MAME sur `neomrdo` : crédit posé pendant le décompte).
        | %d0 ÉTENDU À ZÉRO avant les remises (COIN_SOUND plus bas, PLAYER_START dans
        | `_io_start`) : sinon ses bits 8-31 sont ceux du jeu à l'entrée de l'appel. Mesuré
        | sous MAME le 2026-10-21 sur `flipshot` : sa routine PLAYER_START ($0007DA) choisit
        | où sauter d'après %d0 tel que le BIOS le laisse, octets 8-15 compris — un octet
        | 8-15 non nul l'envoie à $0000565D, erreur d'adresse.
        | Le code de `menu.s` ajouté, ses cycles déplacent l'instant où le vblank interrompt le
        | jeu, donc ce qu'il laisse dans %d0 : le défaut, latent, est apparu au START de la
        | trame 1 300 du banc. SUPPOSÉ : que le BIOS de référence remette %d0 à zéro de même
        | (le jeu tourne sous lui) ; rien d'autre ne le dit.
        moveq   #0, %d0
        move.b  0x10FEE1, %d0
        beq.s   3f
        cmpi.b  #0xFF, %d0
        bne.s   1f
        move.b  #0x0A, 0x10FEE1
        bra.s   2f
1:      subq.b  #1, 0x10FEE1

        | LE SON DIFFÉRÉ. Mesuré sous MAME sur `neomrdo` : pièce vers la trame 243, pendant
        | le décompte, et COIN_SOUND vers la trame 255, la première après le zéro — trace 9,
        | remise à $000134 à 255.15, depuis un appel entré à $C0044A. La pièce est donc
        | mémorisée. La cellule, $10FEE2 : aucune page ne la nomme ; mesuré, `appel_C0044A.md`
        | l'écrit sur 3/80 appels, $00 ou $01, et `appel_C00438.md` sur 3/48, $01 seulement —
        | une marque posée, puis effacée par SYSTEM_IO. Qu'elle porte ce son-là est SUPPOSÉ,
        | comme sa valeur $01. INT1 la pose aussi dans la référence ; ici, seulement pour
        | une pièce hors partie (`_io_son_piece`).
2:      tst.b   %d6
        beq.s   4f
        cmpi.b  #2, 0x10FDAF
        bcs.s   4f                      | hors partie : déjà marquée (`_io_son_piece`)
        move.b  #0x01, 0x10FEE2
4:      bra     _io_temps               | le temps de jeu, en fin d'appel

        | COIN_SOUND, à FRAME_SKIP nul : pièce de cette trame, ou pièce mémorisée. Mesuré :
        | `protocole.md`, trace 4, remise à $000134 depuis un appel entré à $C0044A, à la
        | trame de la pièce. « 68k program header » : $000134 porte « JMP to COIN_SOUND
        | subroutine » ; la page ne dit pas comment le BIOS l'atteint. SUPPOSÉ : par `jsr`,
        | le jeu revenant par `rts`, et une fois par trame quelle que soit la pièce — et dès
        | la pièce acceptée, même si elle ne fait pas encore un crédit.
        | L'APPEL LUI-MÊME est fait dans `_io_commun` (`_io_son_piece`), pièce de cette trame
        | comme pièce mémorisée, à la place que la référence lui donne : il est déjà parti ici.
3:

| ----------------------------------------------------------------------------------
| LE DÉPART FORCÉ (« game start compulsion »). Sortie : %d4 = bit 0 à 1 si le minuteur
| vient d'atteindre 00/00, que `_io_start` ajoute à l'appui de START P1 — le départ suit
| alors le chemin d'un START, sans dupliquer drapeau, PLAYER_START ni déduction.
|
| Lu dans « BIOS RAM locations » : $10FDDA (BIOS_COMPULSION_TIMER) en secondes BCD,
| $10FDDB le minuteur de trames, « When it underflows, the timer is reset to 59 and
| START_COMPULSION_TIMER is decremented ». Lu dans « PLAYER START subroutine » : la
| routine est aussi appelée « when the time runs out while the game's title screen is
| being displayed ». Mesuré (relevé MINASAN, `measured/2026-10-17-diagnostic-b2b-minasan.tsv`) :
| −1 par trame de $3B à $00, puis seconde −1 et $3B ; à 00/00, mode titre et un crédit,
| $000128 atteint avec $10FDB4 = $01, puis mode 2 et un crédit déduit. Mesuré aussi (même
| relevé, deux pièces) : recharge à 901, 00 et PLAYER_START à 2700, soit 1799 trames,
| 30 s — le départ tombe quand les secondes passent de 01 à 00, sans seconde de plus à
| 00/3B (mesuré sous MAME sur notre image avant cette correction : départ à 2771).
| « Titre » = BIOS_USER_MODE ($10FDAF) à 1, « Title/Demo » (« BIOS RAM locations »), ET
| BIOS_USER_REQUEST ($10FDAE) à 3 : la démo sans crédit ne décompte pas. Mesuré sous MAME le 2026-10-22
| (-bios euro, puzzledp, deux pièces par crédit ; `measured/2026-10-22-ecarts-remise-
| credit.tsv`) : armé à $30 par une pièce sans crédit pendant la démo, $10FDDA y reste 400
| trames, jusqu'à la pièce suivante.
| LA DÉMO AVEC UN CRÉDIT DÉCOMPTE. Mesuré sous MAME le 2026-10-22 (-bios euro, puzzledp et
| mslug ; `measured/2026-10-22-piece-demo-end.tsv`) : à la pièce qui fait le crédit pendant
| la démo, $10FDDB passe de $3B à $3A dans l'appel même qui appelle DEMO_END (à la trame
| de la pièce, ou au premier FRAME_SKIP nul si elle tombe pendant le saut). D'où la
| condition : titre, ou démo avec un crédit. SUPPOSÉ : le titre sans crédit décompte
| encore (jamais vu chez la référence, qui n'y va pas sans crédit) — on n'y change rien.
| Lu dans « Backup RAM » : $D00043, « Game start compulsion (0 = enabled, 1 =
| disabled) » ; honoré ici. SUPPOSÉ : toute valeur non nulle désactive.
|
| SUPPOSÉ : ici, sous FRAME_SKIP nul, et non à chaque appel. Le déclenchement passe par
| `_io_start`, qui n'est atteint qu'à FRAME_SKIP nul ; un 00/00 atteint pendant le saut
| serait perdu, ou demanderait une cellule qu'aucune page ne nomme. « BIOS RAM
| locations » dit le saut couvrant « the routine which checks [...] if the player has
| pressed start » ; que le départ forcé en soit, c'est la supposition.
| Un minuteur à 00/00 est désarmé : rien ne décompte ni ne redéclenche sans nouvelle
| pièce. SUPPOSÉ : un départ refusé (pas de crédit P1, ou PLAYER_START qui efface le
| bit) n'est pas retenté.
| ----------------------------------------------------------------------------------
_io_compulsion:
        moveq   #0, %d4                 | pas de départ forcé
        cmpi.b  #1, 0x10FDAF
        bne.s   _io_select              | hors du titre : pas de décompte
        cmpi.b  #3, 0x10FDAE
        beq.s   2f                      | le titre décompte
        tst.b   0xD00034
        beq.s   _io_select              | la démo sans crédit : pas de décompte
2:      tst.b   0xD00043
        bne.s   _io_select              | désactivé
        tst.w   0x10FDDA
        beq.s   _io_select              | 00/00 : désarmé
        move.b  0x10FDDB, %d1
        subq.b  #1, %d1
        bcc.s   1f                      | pas sous zéro
        move.b  0x10FDDA, %d2           | secondes ≥ 01 ici : pas d'emprunt
        moveq   #1, %d3
        move.w  #0, %ccr                | X à 0 avant `sbcd`
        sbcd    %d3, %d2
        move.b  %d2, 0x10FDDA
        moveq   #0, %d1                 | secondes passées de 01 à 00 : 00/00, départ
        tst.b   %d2
        beq.s   1f
        moveq   #0x3B, %d1
1:      move.b  %d1, 0x10FDDB
        tst.w   0x10FDDA
        bne.s   _io_select
        moveq   #1, %d4                 | 00/00 atteint : START P1 forcé

| ----------------------------------------------------------------------------------
| LA SÉLECTION DU JEU PAR SELECT, sur une carte à plusieurs slots. Ne revient pas si elle
| part (`_retour_selection`, `c0.s`) ; sinon, la suite : la fin de démo, START.
| APRÈS LE DÉPART FORCÉ. MESURÉ sous MAME le 2026-10-23 (-bios euro, puzzledp + aof, SELECT
| aux trames 1200 et 1213 ; `measured/2026-10-23-titre-apres-game-over.tsv`, section 2), la
| référence, dans l'appel du SELECT : $10FDDB décompté, $380031 ← $FF, $10FEE0 ← $00,
| $10FD81 ← $04, puis DEMO_END ($00012E lu). Notre image testait SELECT avant le décompte,
| et n'appelait pas DEMO_END. $10FEE0, $10FD81 et DEMO_END : `_retour_selection`. SUPPOSÉ, la
| garde de %d4 : un départ forcé tombé dans le même appel passe avant SELECT, la référence
| testant START avant lui (le $FF de `_io_verrous_hauts`, « à la fin du test de START »).
| GARDE DE RÉENTRÉE, ÉCART VOULU (`docs/DECISIONS.md` §10). MESURÉ sous MAME le 2026-10-23 (b2b +
| puzzledp, SELECT à 1050 puis à 1052 ; `measured/2026-10-23-titre-apres-game-over.tsv`,
| section 6) : b2b appelle SYSTEM_IO depuis le DEMO_END du SELECT, et la référence y prend le
| second front : DEMO_END rappelé alors que le premier n'a pas fini, qui n'est jamais repris.
| On corrige : la routine du jeu, rentrée à mi-course, précède la sauvegarde de sa RAM. Ici,
| SELECT est ignoré tant que $10FD81 vaut $04/$05 : posé par `_retour_selection` avant
| DEMO_END, rendu à $02 avant la remise. Mesuré : `measured/2026-10-23-garde-select.tsv`.
|
| MESURÉ sur la référence (`bench/multislot.lua`, -bios euro, MV-6F, le 2026-10-22 ;
| `measured/2026-10-22-multi-slot-lot4.tsv`) :
|   - SELECT P1 (« Next Game » chez MAME, bit 1 de REG_STATUS_B) → BIOS_SYSRET_STATUS ←
|     $04 et le slot occupé suivant ; SELECT P2 (« Previous Game », bit 3) → $05 et le slot
|     occupé précédent ; vides sautés, bouclage dans les deux sens (2 et 3 cartouches, un
|     slot vide entre deux) ;
|   - pris au titre avec un crédit (demande 3, mode 1, $D00034 ≠ 0), NVRAM neuve comme
|     gardée ; ignoré en démo sans crédit, en partie avec ou sans crédit, et au titre
|     tant que BIOS_FRAME_SKIP n'est pas à zéro : un SELECT 9 trames après la remise est
|     perdu, un à 10 trames pris, à la trame où FRAME_SKIP est lu à $00 — la règle de START
|     ici, d'où la place de ce test. La remise pose FRAME_SKIP à $09 comme la référence
|     (`c0.s`, `_remettre_a_user`) : pris à 10 trames chez nous aussi ;
|   - au front seulement : tenu 80 trames, un seul changement ;
|   - le crédit n'est pas touché.
| Le crédit n'est jamais vu à zéro au titre chez la référence (une pièce qui ne fait pas
| de crédit n'y mène pas, mesuré) ni non nul en démo (le boot remet $D00034 à zéro) : le
| test est donc le plus étroit qui couvre les cas mesurés, demande 3 ET crédit, SUPPOSÉ.
| Lu dans « BIOS RAM locations » : « Game selection can only be done on MVS systems when
| this byte is < 2 » ($10FDAF), et BIOS_STATCHANGE sans ses bits SELECT sur MVS (`_io_commun`),
| d'où la lecture de BIOS_STATCHANGE_RAW ($10FEDD). Sur AES (BIOS_MVS_FLAG nul), rien.
| SUPPOSÉ : les deux SELECT au même front, P1 l'emporte.
|
| UNE CARTOUCHE SEULE : SELECT IGNORÉ, ÉCART VOULU. Mesuré, la référence fait le même
| chemin sur le slot même (code 4 ou 5, sauvegarde puis restauration du même bloc, titre
| relancé) ; le mandat de ce lot tient la cartouche seule et le MVS mono-slot inchangés.
| ----------------------------------------------------------------------------------
_io_select:
        tst.b   %d4
        bne.s   _io_fin_demo            | le départ forcé vient de tomber : START d'abord
        tst.b   0x10FD82                | BIOS_MVS_FLAG : le mode AES a sa règle, plus bas
        beq.s   _io_select_aes
        cmpi.b  #1, 0x10FDAF            | BIOS_USER_MODE : titre / démo
        bne.s   _io_fin_demo
        cmpi.b  #3, 0x10FDAE            | BIOS_USER_REQUEST : titre
        bne.s   _io_fin_demo
        tst.b   0xD00034                | un crédit
        beq.s   _io_fin_demo
_io_select_garde:
        cmpi.b  #4, 0x10FD81            | un SELECT en cours (DEMO_END du jeu) : ignoré
        beq.s   _io_fin_demo
        cmpi.b  #5, 0x10FD81
        beq.s   _io_fin_demo
        move.b  0x10FEDD, %d0           | BIOS_STATCHANGE_RAW : appuis nouveaux
        moveq   #4, %d6                 | SELECT P1 : code 4, le suivant
        btst    #1, %d0
        bne.s   1f
        moveq   #5, %d6                 | SELECT P2 : code 5, le précédent
        btst    #3, %d0
        beq.s   _io_fin_demo
1:      jsr     _slot_suivant           | %d1 ; clobbers %d2, %d3, %d5, %a1
        cmp.b   0xD00108, %d1
        beq.s   _io_fin_demo            | aucun autre slot occupé : ignoré
        bsr     _io_verrous_hauts
        jmp     _retour_selection       | `c0.s`, %d6 : le code ; ne revient pas

| SELECT EN MODE AES — sur une carte MVS à plusieurs slots, le multi-slot étant gardé
| (décision D3). La règle MVS ne s'y applique pas : elle veut le titre du BIOS avec un crédit,
| et le mode AES n'a ni l'un ni l'autre. LA VOIE LA PLUS RESTREINTE, ÉCART VOULU (DECISIONS
| §11) : SELECT n'est pris qu'en démo (mode 1, demande 2), avec la même garde de réentrée et le
| même saut de FRAME_SKIP qu'en MVS, et il mène à la démo du jeu suivant (`_retour_selection`),
| jamais au titre. En partie, le BIOS n'y touche pas : le jeu le reçoit (BIOS_STATCHANGE, sa
| pause). Aucune référence : l'AES n'a qu'un slot.
_io_select_aes:
        cmpi.b  #1, 0x10FDAF            | BIOS_USER_MODE : titre / démo
        bne.s   _io_fin_demo
        cmpi.b  #2, 0x10FDAE            | BIOS_USER_REQUEST : la démo
        bne.s   _io_fin_demo
        bra.s   _io_select_garde

| ----------------------------------------------------------------------------------
| LA FIN DE LA DÉMO PAR LA PIÈCE. MESURÉ sous MAME le 2026-10-22 (-bios euro, une
| cartouche, `measured/2026-10-22-piece-demo-end.tsv`) : la pièce qui fait le crédit
| pendant la démo mène, dans le même appel et après COIN_SOUND, à DEMO_END puis au titre
| (`_retour_demo_end`, `c0.s`). Pendant le décompte de BIOS_FRAME_SKIP, la référence
| crédite seulement, et sonne puis appelle DEMO_END au premier appel qui le lit à $00 (pièce
| 3 ou 7 trames après la remise de la démo : les deux à la trame 760 sur puzzledp) — d'où la
| place de ce test, après le saut, comme START et SELECT, et après le départ forcé : la
| référence décompte $10FDDB une fois dans cet appel-là (voir `_io_compulsion`).
| SUPPOSÉ, la condition : démo (mode 1, demande 2) et un crédit, plutôt qu'une marque de la
| pièce — la référence n'est jamais en démo avec un crédit hors de ce cas (le boot l'efface).
| ----------------------------------------------------------------------------------
_io_fin_demo:
        cmpi.b  #1, 0x10FDAF            | BIOS_USER_MODE : titre / démo
        bne.s   _io_start
        cmpi.b  #2, 0x10FDAE            | BIOS_USER_REQUEST : la démo
        bne.s   _io_start
        tst.b   0xD00034                | un crédit
        beq.s   _io_start
        | PAS DE SECONDE ENTRÉE PENDANT DEMO_END. Mesuré sous MAME le 2026-10-22 (b2b, pièce à
        | la trame 3300) : un jeu peut appeler SYSTEM_IO depuis sa routine DEMO_END (la
        | référence y reste 35 trames sur b2b) ; chez nous, la démo et le crédit tenant
        | toujours, l'appel rappelait DEMO_END, sans fin, et la machine repartait à zéro.
        | SUPPOSÉ, la garde : BIOS_SYSRET_STATUS à $06, posé juste avant DEMO_END
        | (`_retour_demo_end`) et rendu à $02 après lui.
        cmpi.b  #6, 0x10FD81
        beq.s   _io_start
        bsr     _io_verrous_hauts
        jmp     _retour_demo_end        | `c0.s` : ne revient pas

| ----------------------------------------------------------------------------------
| START AVEC CRÉDIT.
|
| Lu dans « PLAYER START subroutine » : le BIOS l'appelle quand un bouton START est
| pressé et que le joueur « has enough credits » ; BIOS_START_FLAG ($10FDB4) porte les
| joueurs en bits actifs à 1 — « The 4 LSBs correspond to the player who pushed start »
| (« BIOS RAM locations ») —, la routine les laisse à 1 si la partie peut partir, les
| efface sinon, et « After returning, the System ROM deducts credits according to
| BIOS_CREDIT_DEC » — démenti par la mesure, voir LA DÉDUCTION plus bas.
|
| Mesuré (`appel_C0044A.md`, l'appel de 84 043 accès ; `protocole.md`, trace 3, remise
| à $000128 depuis $C0044A) : $10FDB4 ← $01, $10FD81 ← $03, $D00034 ← $00, et la main
| au jeu en cours de route — ses 16 466 écritures sont le démarrage de la partie.
|
| « ASSEZ DE CRÉDITS » : un crédit du joueur non nul, sans regarder BIOS_CREDIT_DEC.
| Mesuré sous MAME sur `wjammers` : la référence accepte un START avec $D00034 = $01 alors
| que $10FDB0 vaut $00 au moment de la décision — elle remet $10FDB0 à zéro chaque
| trame où la demande du jeu dépasse le crédit (au titre, $0202 demandé pour 1 crédit).
| Ni « DEC nul → refus » ni « demande > crédit → refus », que portait la garde
| précédente : la mesure les réfute toutes deux. Crédit en BCD, donc tout octet non nul
| vaut au moins 1. La partie gratuite ($D00042) reste écartée de ce lot.
| Le bit de START P1 est le bit 0 de BIOS_STATCHANGE, celui de P2 le bit 2
| (« BIOS RAM locations », disposition de REG_STATUS_B) ; dans BIOS_START_FLAG, P1 est
| le bit 0 et P2 le bit 1 — mesuré, START P2 seul y fait écrire $02 par la référence.
|
| LE DÉPART DE P2, et les deux écritures de BIOS_START_FLAG. Mesuré sous MAME le
| 2026-10-22 sous la référence (`-bios euro`), cyberlip, kof94 et aof, mêmes plans
| d'entrées que notre image (relevé « départ de P2 », valeurs de RAM écrites par la
| référence) :
|   - à chaque front de START, $10FDB4 reçoit d'abord les bits des joueurs pressés
|     ($01 pour P1, $02 pour P2), puis la décision : les bits acceptés, ou $00 — sans
|     crédit ($D00034 à $00, en démo comme en partie), la référence écrit $02 puis $00
|     et n'appelle pas PLAYER_START ;
|   - en partie (mode 2), START P2 avec $D00034 = $01 et $D00035 = $00 : $10FDB4 ← $02,
|     PLAYER_START, puis un crédit ôté de $D00034 si le jeu garde le bit (kof94 : P2
|     rejoint, $D00034 $01 → $00) ; aucun si le jeu l'efface (cyberlip, aof) ;
|   - au titre (mode 1), START P2 fait partir LES DEUX joueurs : avec $D00034 = $02,
|     $10FDB4 ← $02 puis $03, PLAYER_START avec $03, et deux crédits ôtés de $D00034
|     ($02 → $01 → $00) ; avec $D00034 = $01, $02 puis $00, rien d'autre ;
|   - $D00035 n'est jamais lu comme crédit ni écrit hors du boot : le crédit est commun
|     (de même CREDIT_CHECK, plus bas, et la pièce 2, `_io_crediter`).
| SUPPOSÉ : le mode 0 suit la règle du titre (seuls le titre, la démo sans crédit et la
| partie ont été mesurés) ; START P1 et P2 au même front — jamais mesuré — : P1 d'abord,
| P2 en partie s'il reste un crédit après lui ; un START P1 en partie avec un crédit,
| comme P2 (mesuré sous la référence : sbp, PLAYER_START appelé, relevé des départs
| refusés).
| ----------------------------------------------------------------------------------
_io_start:
        moveq   #0, %d0                 | étendu à zéro : voir `_systeme_io`
        move.b  0x10FDAD, %d0           | BIOS_STATCHANGE : appuis nouveaux
        or.b    %d4, %d0                | plus le START P1 forcé (`_io_compulsion`)
        moveq   #0, %d1                 | les joueurs pressés, en bits de BIOS_START_FLAG
        btst    #0, %d0
        beq.s   1f
        bset    #0, %d1
1:      btst    #2, %d0
        beq.s   2f
        bset    #1, %d1
2:      tst.b   %d1
        beq     9f
        btst    #1, BORNE               | NO CONTINUE : voir `_io_sans_continue`
        bne     _io_sans_continue
_io_presses:
        move.b  %d1, 0x10FDB4           | première écriture : les pressés (mesuré)

        | LA DÉCISION, %d2 : les joueurs acceptés. Crédit commun $D00034, BCD — l'ordre
        | des octets BCD est celui des entiers, d'où les `cmpi` non signés.
        | Le mode AES, sans crédit, est refusé ici et repris au refus (`_io_start_refus`).
        moveq   #0, %d2
        move.b  0xD00034, %d3
        btst    #0, %d1
        beq.s   1f
        tst.b   %d3
        beq.s   1f                      | crédit nul : P1 refusé
        bset    #0, %d2
1:      btst    #1, %d1
        beq.s   2f
        cmpi.b  #2, 0x10FDAF            | BIOS_USER_MODE : en partie ?
        beq.s   3f
        cmpi.b  #2, %d3                 | titre : les deux joueurs, deux crédits
        bcs.s   2f
        moveq   #3, %d2
        bra.s   2f
3:      moveq   #1, %d5                 | partie : un crédit pour P2...
        btst    #0, %d2
        beq.s   4f
        moveq   #2, %d5                 | ...plus celui de P1 accepté au même front
4:      cmp.b   %d5, %d3
        bcs.s   2f
        bset    #1, %d2
2:      move.b  %d2, 0x10FDB4           | seconde écriture : la décision (mesuré)
        beq     _io_start_refus         | refusé : ni PLAYER_START ni déduction, en MVS

        | PLAYER_START. « 68k program header » : $000128 porte « JMP to PLAYER_START
        | subroutine ». SUPPOSÉ : par `jsr`, retour par `rts` — le contrat montre l'appel
        | revenir au jeu par $00026A après ce détour. Tous les registres sont perdus.
        jsr     0x128

        | LA DÉDUCTION : un crédit par joueur laissé à 1 dans BIOS_START_FLAG, relu après
        | le retour (le jeu peut effacer un joueur pendant PLAYER_START), ôté du crédit
        | commun $D00034 pour P2 aussi (mesuré, voir l'en-tête : kof94 et le titre à deux). Mesuré sous MAME
        | sur `wjammers`, monnayeur par défaut « 1 coin 1 credit » : la référence déduit 1
        | avec 2 crédits ($02 → $01) alors que le jeu demande $0202 et que $10FDB0 vaut
        | $00 avant comme après la décision, et 1 avec 1 crédit alors que DEC vaut encore
        | $00 au retour — le jeu ne pose $0101 qu'à la trame suivante. La phrase du wiki
        | citée plus haut ne vaut donc pas dans ce régime. SUPPOSÉ : le 1 est le réglage
        | « crédits par start » à sa valeur par défaut ; les soft-DIP sont hors de ce lot.
        | Soustraction BCD : « Backup RAM » donne les crédits en BCD. La garde a vu un
        | crédit non nul, mais rien ne dit qu'un PLAYER_START ne le consomme pas lui-même :
        | si le crédit est à zéro au retour, l'emprunt de `sbcd` le dit et le crédit reste
        | à zéro au lieu de reboucler à $99 — SUPPOSÉ, rien ne documente ce cas.
        move.b  0x10FDB4, %d1
        | LE DÉPART FORCÉ EST DÉSARMÉ QUAND LA PARTIE PART. Mesuré sous MAME (diagnostic du
        | 2026-10-22, $10FDB4 et $10FDDA écrits par la référence, relevés `sbp` et `trally`) :
        | après le retour de PLAYER_START, si le jeu a laissé son bit, la référence écrit le
        | mot $10FDDA ← $0000 (sbp 400, trally 700) ; si le jeu l'a effacé — START en pleine
        | partie, sbp 700 et 1000, trally 1000 —, elle n'y touche pas. Sans cela, sbp
        | restait au titre (mode 1) avec son crédit déduit, à chaque START ; forcé à zéro
        | sous notre image, il passe en mode 2 (diagnostic, même relevé).
        | BIOS_SYSRET_STATUS ($10FD81) ← 3, sous la même condition et juste après. Lu dans
        | « BIOS RAM locations » : 3 = « After a gameover, save the playtime for bookeeping,
        | switch to DEMO mode, reset the workbackup ram » ; le SYSTEM_RETURN de fin de partie
        | le lit (`c0.s`, `_retour_systeme`). MESURÉ sous la référence
        | (`measured/2026-10-22-repetition-et-start.tsv` : aof, mslug, alpham2, garou) : écrit
        | après le retour de PLAYER_START, après $10FDDA et avant la déduction, seulement si
        | le jeu a laissé un bit — aucun START effacé par le jeu ne l'écrit. Notre image
        | l'écrivait avant PLAYER_START, à tout START accepté.
        | BIOS_FRAME_SKIP ← $01 D'ABORD, sous la même condition. MESURÉ sous MAME le 2026-10-23
        | (-bios euro, nam1975 et aof, START à 2100 ; `measured/2026-10-23-led-et-remises.tsv`,
        | section 2), la référence : $10FEE1 ← $01, puis $10FDDA, $10FD81, la déduction ; à
        | l'appel suivant, le décompte à $00. Un START effacé par le jeu (aof, P2 en partie) ne
        | l'écrit pas. Notre image le laissait à $00 : START et le son de pièce étaient lus dès
        | l'appel suivant, une trame avant la référence.
        tst.b   %d1
        beq.s   7f
        move.b  #0x01, 0x10FEE1         | BIOS_FRAME_SKIP
        move.w  #0, 0x10FDDA            | BIOS_COMPULSION_TIMER et son minuteur de trames
        move.b  #3, 0x10FD81
7:      move.b  %d0, 0x3A001D           | REG_SRAMUNLOCK
        moveq   #1, %d3                 | un crédit par joueur parti
        btst    #0, %d1
        beq.s   3f
        move.b  0xD00034, %d2
        move.w  #0, %ccr                | X à 0 avant `sbcd`
        sbcd    %d3, %d2
        bcc.s   6f
        moveq   #0, %d2                 | emprunt : pas sous zéro
6:      move.b  %d2, 0xD00034
3:      btst    #1, %d1
        beq.s   4f
        move.b  0xD00034, %d2           | P2 aussi : le crédit commun
        move.w  #0, %ccr
        sbcd    %d3, %d2
        bcc.s   6f
        moveq   #0, %d2
6:      move.b  %d2, 0xD00034
4:      move.b  %d0, 0x3A000D           | REG_SRAMLOCK
9:      bsr.s   _io_verrous_hauts
        bra     _io_temps               | le temps de jeu, en fin d'appel

| START EN MODE AES, SANS CRÉDIT — atteint par le refus de `_io_start`, seul chemin où le mode
| est testé : un START accepté en MVS garde ses cycles à l'identique (DECISIONS §11). %d1 : les
| joueurs pressés.
| MESURÉ sous MAME le 2026-10-23 (`aes -bios asia` ; `measured/2026-10-23-mode-aes.tsv`), aof,
| kof98, mslug, samsho2, puzzledp, kof94 : en démo comme en partie, PLAYER_START à la trame de
| l'appui, $10FDB4 ← $01 pour START P1, $02 pour P2 seul (pas $03 : P2 ne fait pas partir les
| deux) ; ni $10FEE1 (FRAME_SKIP) ni $10FD81 écrits, aucun crédit. Décision D2.
| ÉCART VOULU : $10FD81 ← 3 quand le jeu garde un joueur, comme en MVS, là où la référence AES
| le laisse à $02 — la fin de partie revient alors par le code 3, la démo sur le même slot (le
| code 2 la ferait tourner au slot suivant sur une carte à plusieurs slots) ; la démo d'après
| game over tombe à R+3 chez les deux (mesuré). Le second $10FDB4, $00 au refus, est réécrit.
| SUPPOSÉ : le mode 0 (demande 0 ou 1 en cours) refusé, comme le MVS le refuse sans crédit au
| boot ; non mesuré chez la référence.
_io_start_refus:
        tst.b   0x10FD82
        bne.s   _io_libre               | MVS : refusé, sauf FREE PLAY
        tst.b   0x10FDAF
        beq.s   9b                      | mode 0 : refusé
        move.b  %d1, 0x10FDB4           | les pressés, acceptés
        moveq   #0, %d0                 | étendu à zéro : voir `_systeme_io`
        jsr     0x128                   | PLAYER_START
        tst.b   0x10FDB4
        beq.s   9b
        move.w  #0, 0x10FDDA            | BIOS_COMPULSION_TIMER, comme en MVS
        move.b  #3, 0x10FD81
        bra.s   9b

| LES VERROUS DES AFFICHEURS REMONTÉS ($380031 ← $FF), à la fin du test de START — après la
| déduction, avant DEMO_END, la sélection et le temps de jeu. MESURÉ sous MAME le 2026-10-23
| (-bios euro, puzzledp, nam1975, puzzledp + aof ; `measured/2026-10-23-led-et-remises.tsv`,
| section 1), la référence : ce $FF n'est écrit que par un SYSTEM_IO qui lit FRAME_SKIP à $00
| — après le décompte du départ forcé, après PLAYER_START et la déduction, juste avant
| DEMO_END ou SELECT. Compté sur les 17 runs de la référence : 2 132 appels sur 2 133 (le
| dernier : le PLAYER_START de puzzledp, qui ne rend la main que deux trames plus tard, $FF
| à son retour) ; aucun des 130 appels pendant le saut ni des 63 sous INT1 — 9 $FF suivent un
| INT1 plus loin dans la trame, écrits par les trames tenues du code 2 et de SELECT.
_io_verrous_hauts:
        move.b  #0xFF, 0x380031         | REG_LEDLATCHES
        rts

| FREE PLAY, EN MODE MVS — atteint par le refus de `_io_start`, comme le mode AES : un START
| accepté avec un crédit garde ses cycles à l'identique. %d1 : les joueurs pressés.
| MESURÉ sous MAME le 2026-10-25 (`measured/2026-10-25-free-play.tsv`, section 1), le BIOS SNK
| (-bios euro, aof) avec le commutateur « Free Play » de la carte : START P1 en démo, sans pièce,
| fait partir la partie à l'appui (PLAYER_START, $10FDB4 = $01, mode 2) ; START P2 en démo fait
| partir les deux ($03) ; en partie, START P2 joint P2 ($02) ; aucun crédit n'est jamais ôté, et
| la démo d'aof dit « PUSH 1P OR 2P START BUTTON » au lieu d'« INSERT COIN » (CREDIT_CHECK, plus
| bas, ne refuse plus rien : bit 7 de BORNE). Ici le même chemin, sous le réglage FREE PLAY (bit
| 0 de BORNE, à zéro en mode AES). Le mode 0 est refusé, comme le BIOS SNK le fait pendant son
| logo (START à la trame 600, mesuré). ÉCART, DECISIONS §15 : un crédit présent est ôté par le
| START accepté plus haut, là où le BIOS SNK n'en ôte aucun.
| DEMO SOUND : un départ depuis la démo remet $D00046 à 0 (`reglages.s`, `_borne_remise`).
| LE COMMUTATEUR 7 DE LA CARTE, « Freeplay » (REG_DIPSW $300001 bit 6, actif bas : « Memory
| mapped registers » ; « Free Play », masque $40, SW:7, dans la source de MAME), depuis le
| 2026-10-25 : l'un OU l'autre suffit. MESURÉ sous MAME 0.286 (`measured/2026-10-25-dip-free-play.tsv`),
| le BIOS SNK et UniBIOS 4.0, ng_mv2f et MV-6F, aof, samsho4, ssideki, mslug : à ON, START P1 sans
| pièce lance la partie, START P2 les deux joueurs, aucun crédit ôté ; et le commutateur est lu
| À CHAUD, dans les deux sens, dès la trame qui suit la bascule. D'où la lecture ici, à chaque
| refus, et non au boot : ce chemin n'est pris que par un START refusé, et un START accepté
| avec un crédit garde ses cycles.
_io_libre:
        btst    #0, BORNE
        bne.s   8f                      | FREE PLAY de CABINET SETTINGS
        btst    #6, DIPSW
        bne     9b                      | ni l'un ni le commutateur : refusé
8:      tst.b   0x10FDAF
        beq     9b                      | mode 0 : refusé
        cmpi.b  #1, 0x10FDAF
        bne.s   1f                      | en partie : les pressés
        btst    #1, %d1
        beq.s   1f
        moveq   #3, %d1                 | titre ou démo, START P2 : les deux joueurs
1:      move.b  %d1, 0x10FDB4
        moveq   #0, %d0                 | étendu à zéro : voir `_systeme_io`
        jsr     0x128                   | PLAYER_START
        tst.b   0x10FDB4
        beq     9b
        move.b  #0x01, 0x10FEE1         | BIOS_FRAME_SKIP, comme un START accepté
        move.w  #0, 0x10FDDA
        move.b  #3, 0x10FD81
        tst.b   0xD00046
        beq     9b
        move.b  %d0, 0x3A001D           | REG_SRAMUNLOCK
        clr.b   0xD00046                | la démo est finie : le son
        move.b  %d0, 0x3A000D           | REG_SRAMLOCK
        bra     9b

| NO CONTINUE (« 1CC ») — un START n'est pas pris pour un joueur dont le jeu offre le continue.
| Lu dans « BIOS RAM locations » : BIOS_PLAYER_MOD1 ($10FDB6), « 0:Never played, 1:Playing,
| 2:Continue option being displayed, 3:Game over », posé par le jeu ; P2 à $10FDB7 (mesuré : le
| mot $0303 au game over d'aof à deux joueurs). MESURÉ sous MAME le 2026-10-25 (même relevé,
| section 2) : aof, puzzledp et kof94 posent $02 pendant leur décompte de continue (aof de 6116 à
| 6716, puzzledp de 7424 à 8003), et un START à ce moment passe par PLAYER_START, ôte un crédit et
| remet le joueur à $01 — le continue est donc pris par le BIOS. Atteint depuis `_io_start`, bit
| 1 de BORNE (à zéro en mode AES : pas de continue payant). LE PLUS RESTREINT : seul le joueur à
| $02 est retiré des pressés ; un joueur à $03 (game over) qui rejoint une partie en cours, ou le
| départ d'une nouvelle partie au titre, ne changent pas. Sans plus aucun pressé, rien n'est écrit,
| comme sans START. Avec FREE PLAY, le continue est refusé aussi.
_io_sans_continue:
        cmpi.b  #2, 0x10FDB6
        bne.s   1f
        bclr    #0, %d1                 | P1 : son continue n'est pas pris
1:      cmpi.b  #2, 0x10FDB7
        bne.s   2f
        bclr    #1, %d1                 | P2 de même
2:      tst.b   %d1
        bne     _io_presses
        bra     9b

| ----------------------------------------------------------------------------------
| CREDIT_CHECK — atteint par `jmp` depuis $C00450 ; le jeu y entre par `jsr` (mesuré :
| retour vers $0013FC sur `puzzledp`) et en repart par notre `rts`.
|
| Lu dans « CREDIT_CHECK » : le jeu pose le crédit voulu dans BIOS_CREDIT_DEC1 ($10FDB0)
| et BIOS_CREDIT_DEC2 ($10FDB1) ; si un joueur n'a pas assez de crédits, sa variable est
| mise à 0. Crédits : $D00034 et $D00035, BCD (« Backup RAM »).
|
| Mesuré (`appel_C00450.md`) : $10FDB1 ← $00 et le MOT $10FDB2 ← $0000 à chaque appel,
| $10FDB0 ← $00 sur 10/23 — les appels où P1 n'a pas son crédit. Mesuré sur notre image :
| `puzzledp` écrit $0101 dans $10FDB0 avant chaque appel, donc DEC2 vaut 1 et P2, sans
| crédit, est remis à zéro à chaque fois.
|
| SUPPOSÉ : P3 et P4 n'ont jamais de crédit (aucune carte 4 joueurs gérée), donc leurs
| deux octets $10FDB2-$10FDB3 sont remis à zéro sans condition, en un mot — la largeur
| est celle du contrat. Le registre %d0 est rendu intact : la page ne dit rien des
| registres, et c'est le choix qui ne peut pas casser l'appelant.
|
| LA DEMANDE DE P2 SE COMPARE AU CRÉDIT COMMUN, $D00034, pas à $D00035. Mesuré sous
| MAME (diagnostic du 2026-10-22, relevés `cyberlip-` et `ncommand-credit-check-ref`) :
| en partie (mode 2), DEC2 = $01 est laissé avec $D00034 à $01, $02 ou $03 et $D00035 à
| $00 ; remis à zéro avec $D00034 à $00. Chez nous, comparé à $D00035 (toujours $00 au
| monnayeur par défaut), il tombait à chaque appel : P2 ne pouvait jamais se joindre.
| AU TITRE (mode 1), mesuré (relevés `trally-` et `dragonsh-credit-check-ref`) : DEC2 =
| $01 remis à zéro avec un crédit (65/66 et 96/96 appels), laissé avec deux (100/100).
| SUPPOSÉ, la règle qui couvre ces comptes : au titre, P2 veut un crédit de plus que sa
| demande — celui de P1, qui part avant lui. Seule la demande $01 a été mesurée.
|
| L'ORDRE : le mot $10FDB2 d'abord, puis $10FDB0, puis $10FDB1 — MESURÉ sous la référence
| (`measured/2026-10-22-repetition-et-start.tsv`, aof, mslug, alpham2, garou : tous les appels).
| Les décisions ne dépendent pas l'une de l'autre ; seul l'ordre des écritures change.
|
| EN MODE AES, AUCUNE DEMANDE N'EST REFUSÉE. MESURÉ sous MAME le 2026-10-23 (`aes -bios asia`,
| aof en STORY MODE puis puzzledp en démo ; `measured/2026-10-23-aes-credit.tsv`) : la
| référence n'écrit jamais $10FDB0-$10FDB3 après la première trame, appels de CREDIT_CHECK
| compris (8 sur aof, 8 496 sur puzzledp) ; le jeu relit la demande qu'il a posée ($01 pour P2),
| et aof affiche alors « PUSH START » pour P2 au lieu d'« INSERT COIN ». Chez nous, crédit nul
| en mode AES (la pièce est ignorée, D2) : P2 tombait à $00 à chaque appel. Aucun jeu ne lit
| $D00034 lui-même (même relevé). Le test du mode n'est que sur les deux chemins de refus : un
| appel MVS dont la demande passe garde ses instructions à l'identique (DECISIONS §11). Le mot
| $10FDB2 reste écrit en AES, là où la référence ne l'écrit pas : SUPPOSÉ sans effet, aof et
| puzzledp y posent eux-mêmes $0000 avant chaque appel (mesuré, même relevé).
| FREE PLAY DE MÊME, depuis le 2026-10-25 : le test lit le bit 7 de BORNE, posé au boot pour le mode
| AES et pour FREE PLAY (`reglages.s`, `_borne_ram`) — même largeur, mêmes cycles que le test de
| BIOS_MVS_FLAG qu'il remplace. Mesuré : sous le BIOS SNK en free play, la démo d'aof dit « PUSH
| 1P OR 2P START BUTTON » (`measured/2026-10-25-free-play.tsv`, section 1) ; sous la nôtre aussi.
| LE COMMUTATEUR 7 DE LA CARTE DE MÊME, relu à chaque refus (voir `_io_libre`) : sous les deux BIOS
| de référence, la démo passe d'« INSERT COIN » à « PUSH 1P OR 2P START BUTTON » dans les dix
| trames qui suivent la bascule, et retour (`measured/2026-10-25-dip-free-play.tsv`, section 2).
| Un `btst` et un `beq` de plus, sur les deux chemins de refus seulement : une demande qui passe
| garde ses instructions.
| ----------------------------------------------------------------------------------
_credit_check:
        move.l  %d0, -(%sp)
        move.w  #0, 0x10FDB2            | P3 et P4
        move.b  0xD00034, %d0           | crédit P1
        cmp.b   0x10FDB0, %d0
        bcc.s   1f                      | crédit ≥ demande : on laisse
        tst.b   BORNE                   | bit 7 : mode AES ou FREE PLAY, la demande reste (plus haut)
        bmi.s   1f
        btst    #6, DIPSW               | le commutateur 7 à ON (bit à 0) : de même
        beq.s   1f
        move.b  #0, 0x10FDB0
1:      move.b  0xD00034, %d0           | crédit commun, pour P2 aussi (voir plus haut)
        cmpi.b  #1, 0x10FDAF            | BIOS_USER_MODE : titre / démo ?
        bne.s   3f                      | hors du titre : crédit ≥ demande suffit
        cmp.b   0x10FDB1, %d0
        bhi.s   2f                      | titre : crédit > demande, on laisse
        bra.s   4f
3:      cmp.b   0x10FDB1, %d0
        bcc.s   2f
4:      tst.b   BORNE                   | AES ou FREE PLAY : la demande de P2 reste, « PUSH START » (mesuré)
        bmi.s   2f
        btst    #6, DIPSW               | le commutateur 7 de même
        beq.s   2f
        move.b  #0, 0x10FDB1
2:      move.l  (%sp)+, %d0
        rts

| ----------------------------------------------------------------------------------
| LA PARTIE COMMUNE À SYSTEM_IO ET À SYSTEM_INT1.
|
| Aucune entrée ; les remises au jeu sont dans `_systeme_io`, sauf celle d'une pièce hors
| partie, qui part d'ici et ne revient pas (fin de la routine). Entrée : %d7.b non nul
| sous SYSTEM_IO, nul sous INT1. Sortie : %d6 = masque
| des pièces acceptées à cette trame (bit 0 : pièce 1, bit 1 : pièce 2 ; bit 7 : l'une
| d'elles a fait un crédit, posé par `_io_crediter`). Registres
| détruits : %d0-%d3, %d6, %a0.
|
| Tout ce qui suit jusqu'aux afficheurs est le noyau des deux contrats : `appel_C0044A.md`
| et `appel_C00438.md` écrivent les mêmes sites, de la même largeur.
| ----------------------------------------------------------------------------------
_io_commun:
        | LE COMMUTATEUR 8, « FREEZE » (REG_DIPSW bit 7, actif bas ; neogeo.cpp, SW:8). MESURÉ sous
        | MAME le 2026-10-27 (`measured/2026-10-27-dip-2-8.tsv`, sections 2 et 3), le BIOS SNK et
        | UniBIOS 4.0 : à ON, le jeu est suspendu dès la trame suivante, en démo comme en partie —
        | l'image figée, les entrées ne lui parviennent plus —, le Z80 continue, le watchdog est
        | servi ; remis à OFF, le jeu reprend où il était. `tst.b` : le bit 7 est le signe.
        tst.b   DIPSW
        bpl     _io_gel
_io_lire:
        | LE PANNEAU DE MAHJONG, COMMUTATEUR 3 À OFF : la référence le lit comme un joystick, les
        | rangées A-G et H-N confondues (même relevé, section 8). REG_POUTPUT ($380001, « Joypad
        | ports outputs ») choisit les rangées du panneau, trois bits par joueur (neogeo.cpp,
        | io_control_w ; mahjong.cpp, read_ctrl) : $1B, les rangées 0 et 1 des deux joueurs. Un
        | joystick ne lit pas cette sortie : rien ne change pour lui.
        move.b  #0x1B, 0x380001
        | COMMUTATEUR 3 À ON (BIOS_P1STATUS à 3, posé à la remise : `_commutateurs`, `c0.s`) :
        | le balayage du panneau, `_io_mahjong`.
        cmpi.b  #3, 0x10FD94
        beq     _io_mahjong
        | LES DEUX MANETTES. REG_P1CNT ($300000) et REG_P2CNT ($340000), actives à l'état
        | bas (« Memory mapped registers ») ; « BIOS RAM locations » les veut en logique
        | positive, d'où le `not`.
        |
        | L'AUTOFIRE (`autofire.s`, DECISIONS §22), entre la lecture du registre et la mise en RAM :
        | le jeu le voit s'il lit BIOS_P1CURRENT et les octets qui suivent, pas s'il lit le registre
        | lui-même (mesuré, `measured/2026-10-27-autofire.tsv`). Un bouton du réglage, tenu, est vu
        | relâché aux phases de AF_REL ; la phase avance d'une case de AF_SUIV à chaque appel, et
        | repart de 0 quand aucun bouton du réglage n'est tenu. P1 et P2 suivent le même réglage,
        | chacun sa phase. COÛT CONSTANT, turbo actif ou non, bouton tenu ou non : ni branchement
        | ni Scc, ~112 cycles par manette — mesuré, quelques jeux divergent pour quelques cycles.
        | Les tables à zéro (vidage du boot) ne changent rien aux entrées. Le panneau de
        | mahjong (`_io_mahjong`) n'y passe pas : pas d'autofire commutateur 3 à ON, P2 compris.
        lea     AF_REL, %a0
        move.b  0x300000, %d0
        not.b   %d0
        move.b  %d0, %d2
        and.b   AF_MASQUE, %d2          | un bouton du réglage tenu ?
        neg.b   %d2                     | X à 1 si oui
        subx.b  %d2, %d2                | $FF tenu, $00 sinon
        moveq   #0, %d1
        move.b  AF_PH1, %d1
        move.b  0(%a0,%d1.w), %d3       | les boutons vus relâchés à cette phase
        and.b   %d0, %d3
        eor.b   %d3, %d0
        and.b   AF_SUIV-AF_REL(%a0,%d1.w), %d2 | la phase suivante, 0 si rien n'est tenu
        move.b  %d2, AF_PH1
        lea     0x10FD94, %a0           | bloc P1 : BIOS_P1STATUS, puis $10FD95-$10FD99
        bsr     _io_manette
        lea     AF_REL, %a0             | P2, de même
        move.b  0x340000, %d0
        not.b   %d0
        move.b  %d0, %d2
        and.b   AF_MASQUE, %d2
        neg.b   %d2
        subx.b  %d2, %d2
        moveq   #0, %d1
        move.b  AF_PH2, %d1
        move.b  0(%a0,%d1.w), %d3
        and.b   %d0, %d3
        eor.b   %d3, %d0
        and.b   AF_SUIV-AF_REL(%a0,%d1.w), %d2
        move.b  %d2, AF_PH2
        lea     0x10FD9A, %a0           | bloc P2, même disposition : $10FD9B-$10FD9F
        bsr     _io_manette

        | P3 ET P4. Mesuré, à chaque appel et toujours à zéro : l'octet $10FDA1 puis les mots
        | $10FDA2 et $10FDA4, l'octet $10FDA7 puis les mots $10FDA8 et $10FDAA — les mêmes
        | cinq octets PREVIOUS..TIMER que P1, au même décalage dans leurs blocs de six
        | (« BIOS RAM locations » : P2, P3, P4 « same layout as P1 »). SUPPOSÉ : aucune
        | carte 4 joueurs n'est gérée ici, donc ces joueurs n'ont pas d'entrées, et zéro est
        | leur état. La largeur des écritures est celle du contrat, elle en fait partie.
        clr.b   0x10FDA1
        clr.w   0x10FDA2
        clr.w   0x10FDA4
        clr.b   0x10FDA7
        clr.w   0x10FDA8
        clr.w   0x10FDAA
_io_start_select:

        | START ET SELECT. REG_STATUS_B ($380000), lu dans « Memory mapped registers » : bit
        | 0 Start P1, 1 Select P1, 2 Start P2, 3 Select P2. SUPPOSÉ actifs à l'état bas,
        | comme les autres entrées de la page — elle ne le dit que pour REG_STATUS_A. Les
        | variables suivent la disposition de « BIOS RAM locations » — bits 0 à 3 pour P1 et
        | P2, dans le même ordre —, d'où un simple masque $0F.
        move.b  0x380000, %d0
        not.b   %d0
        andi.b  #0x0F, %d0              | %d0 : états courants, bruts
        move.b  0x10FEDC, %d1           | les états de la trame précédente
        move.b  %d0, 0x10FEDC           | BIOS_STATCURNT_RAW
        not.b   %d1
        and.b   %d0, %d1                | %d1 : appuis nouveaux
        move.b  %d1, 0x10FEDD           | BIOS_STATCHANGE_RAW
        | $10FEDE et $10FEDF : mesuré, $00 à chaque appel, en octet, dans les deux contrats.
        | Aucune page ne les nomme ; SUPPOSÉ : on écrit la valeur mesurée, sans sens attribué.
        move.b  #0, 0x10FEDE
        move.b  #0, 0x10FEDF
        | « BIOS RAM locations » : « On MVS the select bits are always read as 0 » pour
        | BIOS_STATCURNT et BIOS_STATCHANGE, et la note manque aux versions RAW. On ne garde
        | donc que les bits Start ($55) quand BIOS_MVS_FLAG ($10FD82) est non nul. C'est le
        | MODE : en mode AES, le jeu reçoit ses SELECT (sa pause), sur une carte MVS aussi.
        moveq   #-1, %d2
        tst.b   0x10FD82
        beq.s   2f
        moveq   #0x55, %d2
2:      and.b   %d2, %d0
        and.b   %d2, %d1
        move.b  %d0, 0x10FDAC           | BIOS_STATCURNT
        move.b  %d1, 0x10FDAD           | BIOS_STATCHANGE

        | BIOS_FRAME_COUNTER, long à $10FE88 : « Frame counter, updated by SYSTEM_IO » (« BIOS
        | RAM locations »). Mesuré : le mot $10FE88 à $0000, le mot $10FE8A croissant d'un
        | par appel — un long incrémenté, qui écrit ses deux mots.
        addq.l  #1, 0x10FE88

        | $10FEE8-$10FEF3 : six mots, écrits à chaque appel dans les deux contrats — $0000
        | aux quatre premiers sites de chaque moitié, 9 valeurs croissantes sur $10FEEC et
        | $10FEF2. Aucune page ne les nomme. MESURÉ sous la référence
        | (`measured/2026-10-22-repetition-et-start.tsv`, alpham2 et aof, 386 trames chacun) :
        | les douze octets sont, à chaque fin de trame, ceux des blocs P1 et P2
        | ($10FD94-$10FD9F), écrits en six mots après eux — d'où les valeurs du minuteur sur
        | $10FEEC et $10FEF2. Le sens de cette copie reste inconnu : on la fait, sans plus.
        move.w  0x10FD94, 0x10FEE8
        move.w  0x10FD96, 0x10FEEA
        move.w  0x10FD98, 0x10FEEC
        move.w  0x10FD9A, 0x10FEEE
        move.w  0x10FD9C, 0x10FEF0
        move.w  0x10FD9E, 0x10FEF2

        | LES AFFICHEURS DE CRÉDITS, PREMIER TEMPS : les verrous remontés, avant la backup
        | RAM ; la donnée et la descente viennent après le crédit (plus bas, avant le verrou).
        move.b  #0xFF, 0x380031         | REG_LEDLATCHES : verrous hauts

        | LA BACKUP RAM. REG_SRAMUNLOCK ($3A001D) puis REG_SRAMLOCK ($3A000D), lus dans
        | « Memory mapped registers » : écriture d'octet, donnée ignorée. Mesuré : les deux
        | sont dans le noyau des deux contrats. Toutes les écritures en $D0xxxx sont entre eux.
        move.b  %d0, 0x3A001D           | déverrouiller

        | LE FRONT DE PIÈCE. « Backup RAM » : $D00020/$D00021 portent l'ancienne et la
        | nouvelle valeur de REG_STATUS_A, $D00022 une valeur temporaire de la recherche du
        | front. Mesuré : les trois octets écrits à chaque appel. REG_STATUS_A ($320001),
        | « Memory mapped registers » : pièces 1 à 4 aux bits 0, 1, 3 et 4, actives à l'état
        | bas. SUPPOSÉ : la valeur est rangée COMPLÉMENTÉE, en logique positive. La page dit
        | « value of REG_STATUS_A » sans plus ; mesuré, les deux sites reçoivent $00, $C0 et
        | $C1 sous INT1, $40, $41, $C0 et $C1 sous SYSTEM_IO — les bits 6 et 7 sont ceux du
        | calendrier, qu'on recopie sans les lire.
        | SUPPOSÉ encore : $D00022 garde le masque des pièces passées de 0 à 1 dans cette
        | logique positive, c'est-à-dire insérées depuis la trame d'avant.
        move.b  0xD00021, %d1           | l'ancienne valeur, déjà complémentée
        move.b  0x320001, %d0           | la nouvelle, brute
        not.b   %d0
        move.b  %d1, 0xD00020
        move.b  %d0, 0xD00021
        not.b   %d1
        and.b   %d1, %d0                | insérées maintenant, absentes avant
        andi.b  #0x1B, %d0              | les quatre pièces
        move.b  %d0, 0xD00022

        | CRÉDITER. Pièce 1 → joueur 1, pièce 2 → joueur 2 ; les pièces 3 et 4 sont écartées.
        | Le son de la pièce AVANT l'impulsion du compteur (`_io_son_piece`, plus bas).
        | EN MODE AES, AUCUNE PIÈCE N'ARRIVE ICI : les monnayeurs sont verrouillés au boot
        | (`c0.s`, REG_SETCL1/2), décision D2. Rien n'est testé ici, pour que le mode MVS garde
        | ses cycles à l'identique (DECISIONS §11).
        moveq   #0, %d6
        btst    #0, %d0
        beq.s   2f
        moveq   #0, %d1                 | joueur 1
        bsr     _io_crediter
        bset    #0, %d6
2:      btst    #1, %d0
        beq.s   3f
        moveq   #1, %d1                 | joueur 2
        bsr     _io_crediter
        bset    #1, %d6
3:      bsr     _io_son_piece

        | $D0002C ET $D00039, APRÈS LE SON. Voir `_io_crediter` : $D0002C revient à $00, puis
        | $D00039 ← $00, à chaque pièce 1 acceptée, que COIN_SOUND parte à cet appel ou non.
        btst    #0, %d6
        beq.s   1f
        move.b  #0x00, 0xD0002C
        move.b  #0x00, 0xD00039
1:
        | L'IMPULSION DU COMPTEUR DE PIÈCES 1 — après le crédit et le son : une pièce de cette
        | trame la (re)lance à $1F, sinon elle décompte. « Memory mapped registers » :
        | REG_SETCC1 ($3800E1) « Coin counter 1 sinks current », REG_RESETCC1 ($380061)
        | « floats », donnée « Any ».
        | Mesuré : $3800E1 ← $10 sur 16/32 appels de $C0044A et 1/16 de $C00438 ; $D00038,
        | octet, sur 17/32 et 2/16, de $16 à $1F, et $1E/$1F dans INT1 à la trame de la
        | pièce. Ce que ces comptes laissent lire, et que rien ne documente — « Backup RAM »
        | marque $D00036-$D00039 « undocumented » : $D00038 décompte depuis $1F à partir de
        | la pièce, et chaque trame où il est non nul, la suivante comprise, tient le
        | compteur en tirage de courant. SUPPOSÉ donc : ce rôle de minuteur d'impulsion, la
        | valeur de départ $1F reprise de la mesure, le relâchement par REG_RESETCC1 à zéro
        | — le contrat ne voit jamais ce zéro, le décompte n'y arrivant pas dans ses fenêtres.
        | La donnée $10 sur $3800E1 est la valeur mesurée ; la page dit qu'elle est ignorée.
        | L'ORDRE, MESURÉ sous la référence le 2026-10-23 (`measured/2026-10-23-comptabilite.tsv`,
        | section 4) : à la pièce, $D00038 ← $1F seul ; aux trames suivantes, $D00038 puis
        | REG_SETCC1, les deux après le front de pièce.
        | SUPPOSÉ : pas d'impulsion du compteur 2. Aucune mesure n'en montre, et lui donner
        | un minuteur demanderait une adresse que rien ne désigne.
        btst    #0, %d6
        beq.s   4f
        move.b  #0x1F, 0xD00038         | l'impulsion du compteur 1 part
        bra.s   5f
4:      tst.b   0xD00038
        beq.s   5f
        subq.b  #1, 0xD00038
        move.b  #0x10, 0x3800E1         | REG_SETCC1
        tst.b   0xD00038
        bne.s   5f
        move.b  #0x10, 0x380061         | REG_RESETCC1 : impulsion finie
5:
        | LE TEMPS DE JEU ET LA COPIE $10FDBA-$10FDBD : plus loin, `_io_temps`.
        | LE MINUTEUR HHMMSSFF de $D0005A-$D0005D, lu dans « Backup RAM » : FF décompte de
        | $3C à $00, SS et MM comptent de $00 à $3B, HH par pas de 4 jusqu'à $60. Mesuré :
        | $D0005D, octet, écrit à chaque appel dans les deux contrats — un décompte. Les trois
        | autres octets ne bougent qu'au passage d'une seconde, ce qui ne tombe pas dans les
        | fenêtres mesurées. SUPPOSÉ : la cadence exacte du rechargement (FF vaut $00 une
        | trame, puis $3C) et le retour de HH à zéro après $60.
        tst.b   0xD0005D
        beq.s   3f
        subq.b  #1, 0xD0005D
        bra.s   8f
3:      move.b  #0x3C, 0xD0005D
        lea     0xD0005C, %a0           | SS, puis MM à $D0005B
        moveq   #1, %d1                 | deux tours de `dbra` : SS, MM
4:      addq.b  #1, (%a0)
        cmpi.b  #0x3C, (%a0)
        bcs.s   8f                      | pas de débordement : la cascade s'arrête
        move.b  #0, (%a0)
        subq.l  #1, %a0
        dbra    %d1, 4b
        addq.b  #4, 0xD0005A            | MM a débordé : HH, par pas de 4
        cmpi.b  #0x60, 0xD0005A
        bls.s   8f
        move.b  #0, 0xD0005A
8:
        | LES AFFICHEURS DE CRÉDITS, SECOND TEMPS. « Memory mapped registers » : REG_LEDDATA
        | ($380041) porte la donnée, REG_LEDLATCHES ($380031) la verrouille — « Latch LED1
        | data », « Latch LED2 data », « LED data is latched on 1 to 0 transition ». « MV-LED » :
        | chiffres en BCD. « Backup RAM » : crédits internes de P1 et P2 en BCD à $D00034 et
        | $D00035. SUPPOSÉ : la donnée est le crédit COMPLÉMENTÉ — rien ne le dit, les valeurs
        | mesurées le laissent lire ($FF pour zéro, $FE pour un).
        | MESURÉ sous MAME le 2026-10-23 (-bios euro, 17 runs sur puzzledp, nam1975, aof, mslug,
        | garou, b2b ; `measured/2026-10-23-led-et-remises.tsv`, section 1), la référence, sous
        | SYSTEM_IO comme sous INT1 : UN afficheur par appel, LED1 ($380031 ← $EF) quand l'octet
        | bas de BIOS_FRAME_COUNTER ($10FE8B, déjà avancé) est pair, LED2 ($DF) quand il est
        | impair (2 341 appels sur 2 341) ; la donnée après le
        | crédit et le minuteur de $D0005D, avant REG_SRAMLOCK (une pièce de cet appel est donc
        | affichée), la descente après lui, puis REG_POUTPUT ← $12, $1B, $00, puis — sous
        | SYSTEM_IO à FRAME_SKIP nul seulement — $380031 ← $FF, à la fin du test de START
        | (`_io_verrous_hauts`) ; sous INT1 et pendant le saut, le verrou reste bas jusqu'au $FF
        | du début de l'appel suivant. Notre image verrouillait les deux, avant le front de
        | pièce, et n'écrivait que $00 dans REG_POUTPUT.
        | REG_POUTPUT ($380001), « Joypad ports outputs » (« Memory mapped registers ») : les
        | valeurs mesurées, dans l'ordre mesuré, et rien d'autre. La référence relit les manettes
        | et REG_STATUS_B sous $12 et sous $1B (mêmes relevés, lectures sans valeur) : pas ici.
        | SUPPOSÉ : sur une manette ordinaire, ces sorties ne changent pas ce qu'on lit — nous
        | lisons une fois, plus haut, comme avant.
        lea     0xD00034, %a0           | LED1 : crédit de P1
        moveq   #-17, %d1               | $EF : bit 4 à 0
        btst    #0, 0x10FE8B
        beq.s   1f
        addq.l  #1, %a0                 | LED2 : crédit de P2
        moveq   #-33, %d1               | $DF : bit 5 à 0
1:      move.b  (%a0), %d0
        not.b   %d0
        move.b  %d0, 0x380041           | REG_LEDDATA
        move.b  %d0, 0x3A000D           | reverrouiller la backup RAM
        move.b  %d1, 0x380031           | REG_LEDLATCHES : la descente verrouille
        move.b  #0x12, 0x380001         | REG_POUTPUT, mesuré
        move.b  #0x1B, 0x380001
        move.b  #0x00, 0x380001

        | LA PIÈCE HORS PARTIE RAMÈNE LE TITRE. Mesuré : une pièce créditée hors partie
        | déclenche une nouvelle remise USER, ~3 trames après elle (pièce 297 → remise
        | 300, pièce 299 → 302, 289 sans pièce) ; trace 9 de `protocole.md`, à 242.92 —
        | la main au BIOS, sous la pièce —, $10FEE1 ← $FF et $10FD80 ← $01, puis demande 3
        | à 244.89 ; trace 4, la même suite de 500.92 à 502.89. Lu : « USER subroutine »,
        | la demande 3 « is called when a coin is inserted on MVS ».
        | « HORS PARTIE » = BIOS_USER_MODE ($10FDAF) < 2. Lu dans « BIOS RAM locations » :
        | 0 init, 1 titre / démo, 2 jeu, et « Game selection can only be done on MVS
        | systems when this byte is < 2 » — le seuil où le BIOS peut reprendre la main.
        | Mesuré : la pièce de 242.92 tombe avec $10FDAF à $00 (écrit par la cartouche à
        | 238.77), donc le mode 0 en est. SUPPOSÉ : une valeur au-delà de 2, que la page ne
        | décrit pas, compte comme une partie — on ne coupe pas ce qu'on ne connaît pas.
        | SEULE UNE PIÈCE QUI FAIT UN CRÉDIT (bit 7 de %d6, `_io_crediter`). MESURÉ sous MAME
        | le 2026-10-22 (`bench/multislot.lua`, -bios euro, puzzledp, deux pièces par crédit
        | posées dans la NVRAM, $D0003A ← $02 ; `measured/2026-10-22-ecarts-remise-credit.tsv`) :
        | la pièce qui ne fait pas encore de crédit, pendant la démo, est comptée ($D00024 ←
        | $01) et sonnée (COIN_SOUND à sa trame), sans $10FD81 ni remise — la démo continue ;
        | la seconde fait le crédit, puis $10FD81 ← $06 et la demande 3. Notre image menait
        | la première au titre, sans crédit.
        | LE SON SURVIT À LA REMISE. Mesuré sous MAME sur `neomrdo` : pièce ~243, COIN_SOUND
        | ~255, au premier SYSTEM_IO à FRAME_SKIP nul après la remise. La marque $10FEE2
        | (`_systeme_io`) est donc posée avant de partir (`_io_son_piece`) : la remise ne l'efface pas, et
        | `_systeme_io` ne l'aurait pas posée sous INT1 ni à FRAME_SKIP nul.
        | SUPPOSÉ : la remise part tout de suite, là où la référence rend encore ~2 trames
        | au jeu avant elle (trace 9, $000200 à 243.88).
        | PAS DE REMISE SI LE TITRE EST DÉJÀ DEMANDÉ. Mesuré sous MAME (diagnostic du
        | 2026-10-22, relevé `trally`) : une pièce au titre (mode 1, BIOS_USER_REQUEST
        | $10FDAE à 3) est créditée par la référence sans nouvelle remise ; chez nous, la
        | remise relançait le titre à chaque pièce et le jeu ne partait pas. Une pièce
        | pendant la démo (demande 2) garde la remise, mesuré (relevés `garou`, `sbp`,
        | `aodk` : $10FD80 ← $02, $10FD81 ← $06, puis demande 3). La marque du son est posée
        | dans les deux cas : sous SYSTEM_IO, COIN_SOUND part à cette trame et l'efface
        | (`_io_son_piece`) ; sous INT1, au premier SYSTEM_IO à FRAME_SKIP nul — mesuré le
        | 2026-10-22 (mslug, plus bas).
        | La marque elle-même est posée à la pièce, avant l'impulsion (`_io_son_piece`).
        tst.b   %d6
        beq.s   1f
        cmpi.b  #2, 0x10FDAF
        bcc.s   1f                      | mode ≥ 2 : la pièce ne fait que créditer
        btst    #7, %d6
        beq.s   1f                      | pas de crédit fait : ni remise ni titre
        cmpi.b  #3, 0x10FDAE
        beq.s   1f                      | titre déjà demandé : crédit et son seulement
        | LA DÉMO SOUS SYSTEM_IO (%d7 non nul, posé par `_systeme_io` ; `int1.s` le met à
        | zéro) : rien ici, `_io_fin_demo` fait COIN_SOUND, DEMO_END puis le titre, mesuré.
        | SOUS INT1, RIEN NON PLUS : le crédit et la marque du son seulement. MESURÉ sous MAME
        | le 2026-10-22 (-bios euro, mslug ; `measured/2026-10-22-frame-skip-et-mode0.tsv`) :
        | une pièce prise sous INT1 pendant la démo (deux trames après sa remise) n'est que
        | créditée, et la démo continue jusqu'au premier SYSTEM_IO qui lit FRAME_SKIP à $00 —
        | COIN_SOUND, $10FD81 ← $06, DEMO_END, puis le titre (`_io_fin_demo`) ; prise sous INT1
        | pendant la demande 0, elle n'est que créditée, le jeu finit sa demande 0, et c'est
        | après son SYSTEM_RETURN que la référence donne le titre (`_sysret_demo`, `c0.s`).
        | En mode 0 sous SYSTEM_IO, le chemin d'avant, qu'aucun relevé ne couvre.
        tst.b   %d7
        beq.s   1f
        cmpi.b  #2, 0x10FDAE
        bne.s   2f
        cmpi.b  #1, 0x10FDAF
        beq.s   1f
2:      jmp     _retour_piece           | `c0.s` : pile et SR repris, titre, ne revient pas
1:      rts

| ----------------------------------------------------------------------------------
| LE SON DE LA PIÈCE, dans `_io_commun`, après le crédit et avant l'impulsion du compteur.
| %d6 : les pièces de cet appel ; %d7 : non nul sous SYSTEM_IO. Détruit %d1.
|
| MESURÉ sous MAME le 2026-10-23 (-bios euro, puzzledp, aof, mslug, nam1975, garou, b2b ;
| `measured/2026-10-23-comptabilite.tsv`, section 4), la référence, sous SYSTEM_IO à
| FRAME_SKIP nul, dans l'ordre : $D00024, $D00034, $10FDDA, $10FDDB, puis $10FEE2 ← $01,
| $10FEE2 ← $00, COIN_SOUND ($000134 lu), puis $D00038 ← $1F — la backup RAM encore
| déverrouillée ; et pour une pièce mémorisée (prise pendant le saut de FRAME_SKIP),
| $10FEE2 ← $00 puis COIN_SOUND, avant le décompte de $D00038. Notre image posait
| l'impulsion d'abord, la marque après le verrou, et appelait COIN_SOUND au retour de
| `_io_commun`, la marque effacée après lui. Sous INT1 et pendant le saut, la marque seule,
| avant l'impulsion (`2026-10-22-frame-skip-et-mode0.tsv`, section 3).
| La marque n'est posée que hors partie (mode < 2), comme avant. SUPPOSÉ : COIN_SOUND au même
| point en partie et en mode 0 (non mesuré) ; un seul appel pour deux pièces de la même trame.
| ----------------------------------------------------------------------------------
_io_son_piece:
        moveq   #3, %d1
        and.b   %d6, %d1
        beq.s   1f                      | pas de pièce : la marque seule décide
        cmpi.b  #2, 0x10FDAF            | BIOS_USER_MODE
        bcc.s   2f                      | en partie : pas de marque
        move.b  #0x01, 0x10FEE2         | COIN_SOUND différé
        bra.s   2f
1:      tst.b   0x10FEE2
        beq.s   9f                      | ni pièce ni marque
2:      tst.b   %d7
        beq.s   9f                      | sous INT1 : la marque seule
        tst.b   0x10FEE1
        bne.s   9f                      | FRAME_SKIP non nul : différé
        clr.b   0x10FEE2
        movem.l %d0-%d7/%a0-%a6, -(%sp)
        moveq   #0, %d0                 | étendu à zéro : voir `_systeme_io`
        jsr     0x134                   | COIN_SOUND
        movem.l (%sp)+, %d0-%d7/%a0-%a6
9:      rts

| ----------------------------------------------------------------------------------
| LE TEMPS DE JEU, ET LA COPIE $10FDBA-$10FDBD — en fin de SYSTEM_IO (après le saut de
| FRAME_SKIP et START, `_systeme_io` et `_io_start`) et en fin de SYSTEM_INT1 (`int1.s`), backup
| RAM déverrouillée à part. Détruit %d1, %a0.
|
| « Backup RAM » : $D0004C est un minuteur de trames qui part de $3C et décompte à chaque
| trame ; à zéro, PLAY TIME ($D00048-$D0004B, secondes en hexadécimal) avance et le minuteur
| repart. Mesuré : $D0004C écrit sur 20/32 appels de $C0044A, 20 valeurs distinctes, jamais
| sous INT1 dans ce contrat.
| $10FDBA-$10FDBD : mesuré, sur 23/32 appels de $C0044A, le mot $10FDBA ($0000 ou $0100) et
| le mot $10FDBC ($0000). « BIOS RAM locations » ne nomme pas ces quatre octets, qui suivent
| BIOS_PLAYER_MOD1-4 ($10FDB6-$10FDB9) ; ils en sont la copie, tenue à chaque appel de
| BIOS_USER_MODE = 2 (SUPPOSÉ jusqu'ici, mesuré ci-dessous).
| MESURÉ sous MAME le 2026-10-23 (-bios euro, nam1975 et aof, pièce(s) 2000, START 2100 ;
| `measured/2026-10-23-comptabilite.tsv`, section 1), la référence :
|   - en partie, une SECONDE section déverrouillée après le saut de FRAME_SKIP et START
|     (après la déduction du crédit à la trame du START), sous SYSTEM_IO comme sous INT1 :
|     $D0004C, puis la copie $10FDBA-$10FDBD de $10FDB6-$10FDB9 ;
|   - le minuteur ne court que si la copie D'AVANT porte un joueur à 1 (« playing ») : aof,
|     qui pose $10FDB6 ← $01 après cette section, ne compte pas à la trame qui suit le
|     START, nam1975, qui le pose avant, si — premier décompte à START + 1 et + 2, première
|     seconde à START + 60 et + 61, comme la référence ; notre image comptait à START + 1
|     sur les deux, la copie et le minuteur étant faits dans `_io_commun` ;
|   - la seconde tombe SOUS zéro : $D0004C de $3B à $00, puis $FF, rechargé à $3B, et PLAY
|     TIME avance dans le même appel — 60 trames par seconde. Notre image avançait à $00 et
|     rechargeait $3C : une trame plus tôt. Le boot pose $3B (`c0.s`, `_bram_valide`) : la
|     garde d'un minuteur à zéro n'a plus d'objet, $00 étant un état du décompte.
_io_temps:
        cmpi.b  #2, 0x10FDAF            | BIOS_USER_MODE : en partie
        bne.s   9f
        move.b  %d0, 0x3A001D           | REG_SRAMUNLOCK
        lea     0x10FDBA, %a0           | la copie d'avant
        moveq   #3, %d1
1:      cmpi.b  #1, (%a0)+
        dbeq    %d1, 1b
        bne.s   2f                      | aucun joueur en jeu
        subq.b  #1, 0xD0004C
        bcc.s   2f
        move.b  #0x3B, 0xD0004C
        addq.l  #1, 0xD00048            | PLAY TIME, une seconde de plus
2:      move.w  0x10FDB6, 0x10FDBA
        move.w  0x10FDB8, 0x10FDBC
        move.b  %d0, 0x3A000D           | REG_SRAMLOCK
9:      rts

| ----------------------------------------------------------------------------------
| UNE PIÈCE ACCEPTÉE. %d1 : le joueur (0 ou 1). Backup RAM déverrouillée par l'appelant.
|
| Lu dans « Backup RAM » : $D00024-$D00025 « internal coin counter », qui n'est pas le
| crédit ; $D0003A/$D0003B le nombre de pièces requis et de crédits ajoutés pour P1,
| $D0003C/$D0003D pour P2 ; $D00034/$D00035 les crédits, BCD.
| Mesuré (`appel_C0044A.md` et `appel_C00438.md`, à la pièce) : $D00024 reçoit $00 et $01
| sur le même appel, $D00034 reçoit $01. Les deux pièces créditent $D00034 (plus bas).
|
| SUPPOSÉ : $D00024 + joueur compte les pièces de ce joueur ; arrivé au nombre requis, il
| revient à zéro et le crédit avance — d'où $01 puis $00. Un réglage à zéro, ce que
| laisse une backup RAM que ce BIOS n'initialise pas, vaut 1. Le crédit plafonne à $99,
| le maximum de deux chiffres BCD — rien ne dit ce que fait le BIOS de référence au-delà.
| Un crédit fait pose le bit 7 de %d6, que lit la remise au titre (`_io_commun`).
| Détruit %d2, %d3, %a0.
| ----------------------------------------------------------------------------------
_io_crediter:
        | LE DÉPART FORCÉ S'ARME (voir `_io_compulsion`). Mesuré (relevé MINASAN) : à la
        | pièce, $10FDDA ← $30 et $10FDDB ← $3B, et une seconde pièce recharge $30. Lu dans
        | « Backup RAM » : $D00044, « Game start compulsion time », BCD, « initialized to
        | $30 » — la recharge en est lue. ARMÉ À TOUTE PIÈCE, MÊME SANS CRÉDIT FAIT : mesuré
        | sous MAME le 2026-10-22 (-bios euro, puzzledp, deux pièces par crédit ;
        | `measured/2026-10-22-ecarts-remise-credit.tsv`), $10FDDA ← $30 à la pièce qui ne
        | fait que compter, en démo comme au titre (où elle recharge un décompte en cours).
        | SUPPOSÉ : quel que soit le joueur et le mode, sous INT1 comme sous SYSTEM_IO.
        | ARMÉ APRÈS LE COMPTE ET LE CRÉDIT (en `9:`, plus bas). MESURÉ sous la référence le
        | 2026-10-22 (`measured/2026-10-22-frame-skip-et-mode0.tsv`, mslug et puzzledp, une et
        | deux pièces par crédit) : $D00024, puis $D00034 s'il y a crédit, puis $10FDDA et
        | $10FDDB. Notre image armait d'abord ; mêmes valeurs.
        lea     0xD00024, %a0
        addq.b  #1, (%a0, %d1.w)        | une pièce de plus
        | $D0002C ← $01 APRÈS LE COMPTE, pour la pièce 1. « Backup RAM » laisse $D00026-$D0002F
        | et $D00036-$D00039 sans description. MESURÉ sous MAME le 2026-10-23 (-bios euro ;
        | `measured/2026-10-23-led-et-remises.tsv`, section 5), la référence, à chaque pièce 1
        | acceptée — démo, partie, pièce qui ne fait pas encore de crédit, sous SYSTEM_IO comme
        | sous INT1 : $D00024 compté, $D0002C ← $01, puis le crédit, et après le son $D0002C ←
        | $00 et $D00039 ← $00 (`_io_commun`). Écrit au plus restreint : ces valeurs, à ces
        | places, pour la pièce 1 seule (la pièce 2 n'est pas mesurée) ; le rôle reste inconnu.
        tst.w   %d1
        bne.s   1f
        move.b  #0x01, 0xD0002C
1:      lea     0xD0003A, %a0
        add.w   %d1, %a0                | deux octets de réglage par joueur :
        move.b  (%a0, %d1.w), %d2       | pièces requises, à $D0003A + 2 × joueur
        bne.s   1f
        moveq   #1, %d2
1:      lea     0xD00024, %a0
        cmp.b   (%a0, %d1.w), %d2
        bhi.s   9f                      | pas encore assez de pièces
        move.b  #0, (%a0, %d1.w)
        lea     0xD0003B, %a0
        add.w   %d1, %a0
        move.b  (%a0, %d1.w), %d3       | crédits ajoutés
        bne.s   2f
        moveq   #1, %d3
        | LE CRÉDIT EST COMMUN : $D00034, pour la pièce 2 aussi. Mesuré sous MAME le
        | 2026-10-22 sous la référence (`-bios euro`, relevé « départ de P2 », cyberlip,
        | kof94, aof) : une pièce 2 fait écrire $D00034 ← $02, jamais $D00035, que la
        | référence n'écrit qu'au boot ; START P2 puis le titre à deux en ôtent les deux.
        | Notre image créditait $D00035, que ni START P2 ni CREDIT_CHECK ne lisent plus.
2:      move.b  0xD00034, %d2
        move.w  #0, %ccr                | X à 0 avant `abcd`
        abcd    %d3, %d2
        bcc.s   3f
        move.b  #0x99, %d2              | plafond BCD
3:      move.b  %d2, 0xD00034
        bset    #7, %d6                 | un crédit fait
9:      move.b  0xD00044, 0x10FDDA      | le départ forcé s'arme (voir plus haut)
        move.b  #0x3B, 0x10FDDB
        rts

| ----------------------------------------------------------------------------------
| LE GEL DU COMMUTATEUR 8 (voir `_io_commun`). IRQ masquées : le vblank du jeu ne tourne pas
| non plus. Le watchdog servi à chaque tour, le commutateur relu jusqu'à OFF, puis la lecture
| des entrées reprend comme si rien n'était arrivé. SUPPOSÉ : que la référence masque les IRQ ;
| mesuré seulement que l'image ne bouge plus (297 à 299 trames sur 299).
_io_gel:
        move.w  %sr, -(%sp)
        ori.w   #0x0700, %sr
1:      move.b  %d0, 0x300001           | watchdog
        tst.b   DIPSW
        bpl.s   1b
        move.w  (%sp)+, %sr
        bra     _io_lire

| ----------------------------------------------------------------------------------
| LE PANNEAU DE MAHJONG, COMMUTATEUR 3 À ON. MESURÉ sous MAME le 2026-10-27
| (`measured/2026-10-27-dip-2-8.tsv`, section 8 ; machine janshin, -bios japan, euro et
| unibios40, les trois identiques), chaque touche du panneau seule puis A+H+PON et A+B :
|   - BIOS_P1STATUS ($10FD94) à 3, « Mahjong controller » (« BIOS RAM locations ») ;
|   - $10FD95, $10FD96 et $10FD97 : les rangées A-G, H-N et PON, CHI, KAN, RON, REACH, une
|     touche par bit, du bit 0, en logique positive, tant qu'elle est tenue ;
|   - $10FDA1, $10FDA2 et $10FDA3 : les mêmes rangées, une trame seulement, à l'appui (le front) ;
|   - aucune répétition ; $10FD98 et $10FD99 ne bougent pas.
| REG_POUTPUT reçoit $09, $12 et $24 (même relevé, section 4) : une rangée à la fois, la même
| pour les deux joueurs. Un joystick sur le même commutateur s'y lit dans les trois rangées à
| la fois (section 4 : CURRENT, PREVIOUS et CHANGE égaux, mesurés sur ssideki).
| P2 reste une manette ordinaire. P3 et P4 : à zéro, sauf les trois fronts.
_io_mahjong:
        lea     0x10FD95, %a0
        move.b  #0x09, 0x380001         | rangée A-G
        bsr.s   .Lmj_rangee
        move.b  %d1, %d2
        move.b  #0x12, 0x380001         | rangée H-N
        bsr.s   .Lmj_rangee
        move.b  %d1, %d3
        move.b  #0x24, 0x380001         | rangée PON-REACH
        bsr.s   .Lmj_rangee
        lea     0x10FD9A, %a0           | P2, comme dans `_io_commun`
        move.b  0x340000, %d0
        not.b   %d0
        move.b  %d1, -(%sp)
        bsr     _io_manette
        move.b  (%sp)+, %d1
        move.b  %d2, 0x10FDA1           | les fronts
        move.b  %d3, 0x10FDA2
        move.b  %d1, 0x10FDA3
        clr.w   0x10FDA4
        clr.b   0x10FDA7
        clr.w   0x10FDA8
        clr.w   0x10FDAA
        bra     _io_start_select
| Une rangée : lue sous la sortie posée, rangée à (%a0)+ ; %d1 son front. Clobbers %d0.
.Lmj_rangee:
        move.b  0x300000, %d0
        not.b   %d0
        move.b  (%a0), %d1
        move.b  %d0, (%a0)+
        not.b   %d1
        and.b   %d0, %d1
        rts

| ----------------------------------------------------------------------------------
| UNE MANETTE. %a0 : le bloc de six octets du joueur (STATUS, puis les cinq qui suivent) ;
| %d0 : ses entrées courantes en logique positive. Détruit %d1.
|
| Lu dans « BIOS RAM locations » : PREVIOUS (+1) les entrées de la trame d'avant, CURRENT
| (+2) celles-ci, CHANGE (+3) les appuis nouveaux, REPEAT (+4) « Active edge + repeat every
| 8 frames after 16 frames », TIMER (+5) « Repeat timer (counts down from 8 to 0) ».
| Mesuré : les cinq octets écrits à chaque appel, en octet ; STATUS (+0) jamais.
|
| LE MINUTEUR, la page ne tenant pas ensemble (16 trames, un minuteur qui descend de 8) :
| MESURÉ sous la référence (`measured/2026-10-22-repetition-et-start.tsv`, alpham2 et aof,
| valeurs trame par trame, appuis de 1 à 41 trames, directions et boutons ajoutés ou lâchés) :
|   - CURRENT différent de l'ancien — appui OU relâchement, autre chose tenu ou non :
|     TIMER ← $10, REPEAT ← CURRENT (l'état entier, pas le seul front) ;
|   - sinon TIMER décompte ; passé sous zéro, il recharge $08 et REPEAT ← CURRENT, au-dessus
|     REPEAT ← 0. Première répétition 17 trames après l'appui, puis toutes les 9 ; rien de
|     tenu, il tourne de $08 à $00 sans fin.
| L'ordre, mesuré de même : TIMER (deux écritures à la recharge, $FF puis $08), REPEAT, puis
| PREVIOUS, CURRENT, CHANGE.
| ----------------------------------------------------------------------------------
_io_manette:
        move.b  2(%a0), %d1            | l'ancien CURRENT
        cmp.b   %d0, %d1
        beq.s   1f
        move.b  #0x10, 5(%a0)          | TIMER : l'état a changé
        move.b  %d0, 4(%a0)            | REPEAT
        bra.s   3f
1:      subq.b  #1, 5(%a0)             | TIMER : l'état tient
        bcc.s   2f
        move.b  #8, 5(%a0)             | TIMER : passé sous zéro
        move.b  %d0, 4(%a0)            | REPEAT
        bra.s   3f
2:      move.b  #0, 4(%a0)             | REPEAT
3:      move.b  %d1, 1(%a0)            | PREVIOUS
        move.b  %d0, 2(%a0)            | CURRENT
        not.b   %d1
        and.b   %d0, %d1
        move.b  %d1, 3(%a0)            | CHANGE
        rts
