| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| SYSTEM_INT1 — l'entrée $C00438 du tableau d'appels, la routine de vblank du BIOS.
|
| Le créneau de six octets de `c0.s` ne porte qu'un `jmp` vers `_systeme_int1` : le code
| vit ici, dans `.text`, que `build/bios.ld` lie après la fin de `.vectors`, donc au-delà
| de $C00800 et hors de portée du tableau d'appels.
|
| TROIS SORTES D'AFFIRMATIONS, et chacune le dit :
|   « mesuré »  : le contrat `specs/traces/appel_C00438.md`, relevé sur 48 appels du BIOS
|                 de référence — ses « Écritures communes à tous les appels » font le noyau ;
|   « lu dans » : une page du NeoGeo Development Wiki, nommée ;
|   « SUPPOSÉ » : ni l'un ni l'autre, et c'est dit.
|
| Ce que « SYSTEM_INT1 » dit de l'appel : routine de vblank du BIOS, « Multi-purpose VBL
| call », qui appelle MESS_OUT et SYSTEM_IO, tient son propre compteur de trames et un
| drapeau qui saute MESS_OUT et SYSTEM_IO (BIOS_INT1_SKIP, $10FEE3). Rien de plus : ni les
| registres préservés, ni les variables écrites. Le reste vient du contrat.
|
| MESS_OUT est l'interpréteur de `mess.s`, le même que derrière l'entrée publique $C004CE :
| le tampon est exécuté, pas seulement vidé (depuis le 2026-10-17, mesuré sur `b2b`,
| `measured/2026-10-17-b2b-mess-out.tsv`).
|
| CE QUE CETTE ROUTINE NE FAIT PAS, délibérément — tout est hors du noyau du contrat :
|   - elle n'appelle ni COIN_SOUND, ni PLAYER_START, ni DEMO_END, que « SYSTEM_IO » cite :
|     la routine SYSTEM_IO qu'elle partage avec $C0044A (`io.s`) crédite une pièce, mais
|     ces remises-là sont propres à l'entrée publique, comme la remise au titre d'une
|     pièce hors partie (`io.s`, fin de `_io_commun`) : d'ici, la pièce n'est que créditée ;
|   - elle ne lit pas le calendrier : le contrat n'écrit pas REG_RTCCTRL ($380051).
| ==================================================================================

        .text
        .global _systeme_int1

| ----------------------------------------------------------------------------------
| L'ENTRÉE. Le jeu y arrive depuis son gestionnaire de vblank, sans rien
| empiler : sous la pile, le cadre d'exception de l'IRQ (mesuré sur NOTRE image et
| `joyjoy` : SR et PC $0000129E empilés, puis l'entrée en $C00438). La sortie est donc un
| `rte` qui rend la main au code interrompu — le contrat cite bien $00129E dans ses
| « Retour vers ». On ne touche pas à SR : `rte` le restaure.
|
| LES REGISTRES SONT TOUS RENDUS INTACTS. SUPPOSÉ : aucune page ne dit ce que SYSTEM_INT1
| préserve. « SYSTEM_IO » écrit en gras que cet appel-là « does NOT save registers », ce
| qui laisse entendre que la règle n'est pas générale ; préserver d0-d7/a0-a6 est le choix
| qui ne peut pas casser un appelant. Le contrat montre bien des écritures de pile sous
| $10F300 ($10F2AA-$10F2F4, mesuré), mais leurs valeurs sont celles du BIOS de référence et
| n'ont pas à être reproduites : celles-ci sont les nôtres.
| ----------------------------------------------------------------------------------
_systeme_int1:
        movem.l %d0-%d7/%a0-%a6, -(%sp)

        | LE WATCHDOG. $300001 est dans le noyau (mesuré, valeurs variables) ; « Watchdog »
        | dit d'y écrire « any value » et que les routines de vblank s'en chargent d'habitude.
        move.b  %d0, 0x300001

        | ACQUITTER. Mesuré : $3C000C reçoit à chaque appel $0004 ou $0007. « 68k
        | interrupts » : bit 2 = v-blank, bit 1 = timer, bit 0 = reset. « Timer interrupt » :
        | le timer ne repart pas sans acquittement. « Memory mapped registers » : REG_LSPCMODE
        | se relit en compteur de ligne, le BIOS ne peut donc pas savoir si le timer est armé.
        | SUPPOSÉ, la condition : BIOS_SYSTEM_MODE ($10FD80) bit 7 à 0, « BIOS wants vblank
        | (system mode) » (« BIOS RAM locations ») — le jeu n'y tient pas les IRQ, une
        | demande timer n'a pas de preneur : on acquitte tout ($0007). Bit 7 à 1, le jeu a
        | le vblank et peut se servir du timer : on n'acquitte que le vblank ($0004).
        move.w  #4, %d0
        tst.b   0x10FD80
        bmi.s   1f
        moveq   #7, %d0
1:      move.w  %d0, 0x3C000C

        | BIOS_INT1_FRAME_COUNTER. Mesuré : $10FEE4, octet, 16 valeurs croissantes sur 16
        | appels — une par appel. « BIOS RAM locations » le place à $10FEE4 (« Frame
        | counter, only used in SYSTEM_INT1 ») ; la page « SYSTEM_INT1 » écrit $10FDD4, mais
        | le contrat n'écrit rien à $10FDD4 : on suit la mesure.
        addq.b  #1, 0x10FEE4

        | BIOS_INT1_SKIP ($10FEE3), lu dans « SYSTEM_INT1 » et « BIOS RAM locations » :
        | non nul, MESS_OUT et SYSTEM_IO sont sautés. Le boot de `c0.s` le laisse à zéro.
        tst.b   0x10FEE3
        bne.s   .Lfin

        | MESS_OUT (`mess.s`) : il sauve lui-même ses registres, et ne fait rien si
        | BIOS_MESS_BUSY est levé.
        | En zone haute, mais un `bsr.w` et non un `jsr` : 2 cycles de moins à chaque INT1, ceux
        | d'avant le déplacement (le `jsr` faisait échouer scores-gel, mesuré). `ld` refuse le lien
        | si l'écart dépasse 32 Kio.
        bsr.w   _mess_out
        | SYSTEM_IO : la routine commune de `io.s`, la même que derrière $C0044A — lu dans
        | « SYSTEM_INT1 », qui dit qu'INT1 l'appelle. Ni COIN_SOUND ni PLAYER_START d'ici.
        moveq   #0, %d7                 | sous INT1 (fin de `_io_commun`, `io.s`)
        bsr     _io_commun

        | BIOS_FRAME_SKIP ($10FEE1) DÉCOMPTÉ ICI AUSSI. MESURÉ sous MAME le 2026-10-22 (-bios
        | euro, `bench/multislot.lua` et une enveloppe qui relève les lectures de $C00438 et
        | $C0044A et chaque écriture de $10FEE1 ; `measured/2026-10-22-frame-skip-et-mode0.tsv`) :
        | après une remise, mslug appelle SYSTEM_INT1 cinq trames avant son premier SYSTEM_IO, et
        | la référence décompte FRAME_SKIP de 1 à chacun de ces appels ; $FF n'y est pas touché
        | (la recharge à $0A vient d'ailleurs), $00 non plus. Notre image ne décomptait que sous
        | SYSTEM_IO : le titre de mslug repartait 5 trames plus tard. SUPPOSÉ : le décompte
        | sauté avec SYSTEM_IO quand BIOS_INT1_SKIP est levé, et une seule fois par trame —
        | aucun des six jeux relevés n'appelle INT1 et SYSTEM_IO dans la même trame.
        move.b  0x10FEE1, %d0
        beq.s   1f
        cmpi.b  #0xFF, %d0
        beq.s   1f
        subq.b  #1, 0x10FEE1
1:
        | LE TEMPS DE JEU, après le décompte (`io.s`, `_io_temps`, mesuré là).
        bsr     _io_temps

        | Deux sites du noyau d'INT1 que celui de $C0044A n'a pas (mesuré, en comparant
        | `appel_C00438.md` et `appel_C0044A.md`) : ils restent donc ici, hors de SYSTEM_IO.
        | $10FE8C : $00 à chaque appel, en octet ; aucune page ne le nomme.
        move.b  #0, 0x10FE8C
        | $10FEC6-$10FEC9 : le mot $0010 puis le mot $FECA à chaque appel, soit le long
        | $0010FECA. Contrat dur, écrit tel quel. Aucune page ne nomme l'adresse ; SUPPOSÉ :
        | un pointeur, qui désigne l'adresse juste au-dessus de lui.
        move.l  #0x10FECA, 0x10FEC6

.Lfin:
        movem.l (%sp)+, %d0-%d7/%a0-%a6
        rte
