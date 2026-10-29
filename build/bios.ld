/* SPDX-License-Identifier: GPL-3.0-or-later
 * Copyright (C) 2026 Thibaut Lion */
/* Script de liaison d'une image de BIOS Neo Geo.
 *
 * LE BIOS EST VU À DEUX ENDROITS, et c'est ce qui dicte cette disposition : la carte le présente
 * en `$C00000`, et elle sert ses **128 premiers octets** à `$000000` tant que `biosMode` (REG_SWPBIOS)
 * tient. La table de vecteurs doit donc être à l'offset 0 de l'image, où le 68000 va chercher son
 * vecteur de reset à la mise sous tension.
 *
 * L'adresse de liaison est `$C00000` : c'est de là que le code s'exécute une fois le vecteur suivi.
 *
 * UNE IMAGE DE BIOS EST EN ROM, DONC ELLE N'A PAS DE `.data`. Les sections d'un `.c` sont nommées
 * ici plutôt que laissées orphelines : sans cela `ld` les placerait d'office à la suite du `.text`,
 * en `rx`, où une globale ne pourrait pas être écrite — et rien ne le dirait. `.bss` part donc en
 * RAM de travail, et un `.data` non vide est refusé net : il demanderait une boucle de recopie
 * ROM → RAM au reset, qu'aucune couche n'a encore.
 */
ENTRY(_reset)

MEMORY {
  bios (rx)  : ORIGIN = 0xC00000, LENGTH = 128K
  /* RAM de travail de la carte : $100000-$10FFFF, soit 64 Kio. La région
   * s'arrête pourtant à $10F300, où `harnais.s` pose sa pile superviseur — elle descend vers le
   * `.bss`, qui monte depuis $100000. Déclarer les 64 Kio entiers laisserait `ld` placer un `.bss`
   * par-dessus la pile sans un mot ; borné ici, il sort en erreur. */
  ram  (rw)  : ORIGIN = 0x100000, LENGTH = 0xF300
}

SECTIONS {
  /* Les vecteurs d'abord, sans quoi le reset ne trouverait rien à l'offset 0. */
  .vectors : { KEEP(*(.vectors)) } > bios
  /* LA TABLE DU SINUS À $C04000, PUIS LA TABLE D'ALÉA À $C04200, AU BOUT DE `.text`
   * (`src/c0/sinus.s`, `src/c0/alea.s`). Dans la même section de sortie, et non dans des sections
   * à part : `objcopy -O binary` comble l'écart entre deux sections avec des zéros (lu dans sa doc,
   * `--gap-fill`), alors que le remplissage `=0xFF` d'une section s'applique à un saut de `.`.
   * L'ancre passe par ALIGN, qui aligne l'adresse absolue. Essayés avant, mesuré : `. =
   * 0xC04200 - ADDR(.text)` est refusé par ce `ld`, et deux écritures par différence d'adresses
   * ont placé la table loin hors de la ROM. Code au-delà de $C04000 :
   * ALIGN sauterait à $C08000, et les gardes en fin de fichier refusent le lien (mesuré, avec
   * 0x3100 octets de `.space` ajoutés au `.text`). */
  .text    : {
    *(.text*) *(.rodata*)
    _fin_code = .;
    /* LA GRILLE À $C02000 EXACTEMENT (`src/c0/grille.s`), puis les deux tables : même section de
     * sortie, pour la même raison. ALIGN(0x2000) mène le code qui finit sous $C02000 à $C02000 ;
     * la garde de fin de fichier refuse le reste. La grille finit à $C04000, et l'ALIGN qui suit
     * n'y bouge donc rien. */
    . = ALIGN(0x2000);
    KEEP(*(.grille))
    _fin_grille = .;
    . = ALIGN(0x4000);
    KEEP(*(.sinus))
    _fin_sinus = .;
    KEEP(*(.alea))
    _fin_alea = .;
    /* LA ZONE HAUTE, À $C04300 : le code sans adresse imposée qui ne tient plus sous $C04000 (la
     * couche 3). Une section d'entrée `.haut`, choisie par `.section .haut, "ax"` dans le fichier :
     * un nom en `.text…` serait déjà pris par `*(.text*)` plus haut, `ld` rangeant une section au
     * premier motif qui la nomme. Dans la même section de sortie que la table, et collée à elle,
     * pour qu'aucun écart ne naisse entre les deux. Les appels qui la traversent sont des `jsr`/`jmp`
     * absolus (lu dans le code, le 2026-10-21), sauf le `bsr.w _mess_out` de `int1.s`. */
    _debut_haut = .;
    *(.haut)
    /* LA TABLE DES CHEATS, après tout le code de la zone haute (`src/c0/cheats.s`) : elle seule
     * grandit avec la base, et ne repousse ainsi aucun appel relatif. */
    KEEP(*(.cheats))
    _fin_haut = .;
  } > bios =0xFF
  .data    : { *(.data*) } > bios
  /* NOLOAD : rien à émettre dans l'image, la RAM n'étant pas initialisée au chargement. */
  .bss (NOLOAD) : { *(.bss*) *(COMMON) } > ram
  /DISCARD/ : { *(.comment) *(.note*) *(.eh_frame*) }
}

/* LA GARDE DE LA GRILLE. Le code doit s'arrêter avant $C02000 : au-delà, il recouvrirait la
 * grille que des jeux lisent (mesuré, `grille.s`). Elle tient aussi la table d'aléa, qui vient après. */
ASSERT(_fin_code <= 0xC02000,
  "le code atteint $C02000 : il recouvrirait la grille, voir src/c0/grille.s ; le code sans adresse imposee va en .haut")
ASSERT(_grille == 0xC02000 && _fin_grille == 0xC04000,
  "la grille n est plus a $C02000-$C03FFF, voir src/c0/grille.s")
/* LA GARDE DE LA TABLE DU SINUS : l'ancre et la taille, 256 mots (DECISIONS §18). */
ASSERT(_table_sinus == 0xC04000,
  "la table du sinus n est plus a $C04000, voir src/c0/sinus.s")
ASSERT(_fin_sinus - _table_sinus == 512,
  "la table du sinus ne fait plus 512 octets, voir src/c0/sinus.s")
/* LA GARDE DE LA TABLE D'ALÉA : l'ancre et la taille. */
ASSERT(_table_alea == 0xC04200,
  "la table d alea n est plus a $C04200, voir src/c0/alea.s")
ASSERT(_fin_alea - _table_alea == 256,
  "la table d alea ne fait plus 256 octets, voir src/c0/alea.s")
/* LA GARDE DE LA ZONE HAUTE : elle part juste après la table, et finit dans les 128 Kio de l'image.
 * La région `bios` refuserait déjà un débordement ; celle-ci le dit dans les termes du BIOS. */
ASSERT(_debut_haut == 0xC04300,
  "la zone haute ne part plus a $C04300, juste apres la table d alea")
ASSERT(_fin_haut <= 0xC20000,
  "la zone haute deborde des 128 Kio de l image")

ASSERT(SIZEOF(.data) == 0,
  "un .data non vide demande une recopie ROM vers RAM au reset : declarer la globale const, ou la mettre en .bss")
