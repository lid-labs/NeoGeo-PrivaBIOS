/* SPDX-License-Identifier: GPL-3.0-or-later
 * Copyright (C) 2026 Thibaut Lion */
/* Linker script for a Neo Geo BIOS image.
 *
 * THE BIOS IS SEEN AT TWO PLACES, and that is what dictates this layout: the board presents it
 * at `$C00000`, and it serves its **first 128 bytes** at `$000000` as long as `biosMode` (REG_SWPBIOS)
 * holds. The vector table must therefore be at offset 0 of the image, where the 68000 fetches its
 * reset vector at power-on.
 *
 * The link address is `$C00000`: that is where the code executes once the vector is followed.
 *
 * A BIOS IMAGE IS IN ROM, HENCE IT HAS NO `.data`. The sections of a `.c` are named
 * here rather than left orphaned: without that `ld` would place them by default after the `.text`,
 * in `rx`, where a global could not be written — and nothing would say so. `.bss` therefore goes to
 * work RAM, and a non-empty `.data` is refused outright: it would require a copy loop
 * ROM → RAM at reset, which no layer has yet.
 */
ENTRY(_reset)

MEMORY {
  bios (rx)  : ORIGIN = 0xC00000, LENGTH = 128K
  /* The board's work RAM: $100000-$10FFFF, that is 64 KiB. The region
   * nevertheless stops at $10F300, where `harnais.s` sets its supervisor stack — it grows down towards the
   * `.bss`, which grows up from $100000. Declaring the whole 64 KiB would let `ld` place a `.bss`
   * over the stack without a word; bounded here, it exits with an error. */
  ram  (rw)  : ORIGIN = 0x100000, LENGTH = 0xF300
}

SECTIONS {
  /* The vectors first, otherwise the reset would find nothing at offset 0. */
  .vectors : { KEEP(*(.vectors)) } > bios
  /* THE SINE TABLE AT $C04000, THEN THE RANDOM TABLE AT $C04200, AT THE END OF `.text`
   * (`src/c0/sinus.s`, `src/c0/alea.s`). In the same output section, and not in separate
   * sections: `objcopy -O binary` fills the gap between two sections with zeros (read in its doc,
   * `--gap-fill`), whereas the `=0xFF` fill of a section applies to a jump of `.`.
   * The anchor goes through ALIGN, which aligns the absolute address. Tried before, measured: `. =
   * 0xC04200 - ADDR(.text)` is refused by this `ld`, and two writings by difference of addresses
   * placed the table far outside the ROM. Code beyond $C04000:
   * ALIGN would jump to $C08000, and the guards at the end of the file refuse the link (measured, with
   * 0x3100 bytes of `.space` added to the `.text`). */
  .text    : {
    *(.text*) *(.rodata*)
    _fin_code = .;
    /* THE GRID AT $C02000 EXACTLY (`src/c0/grille.s`), then the two tables: same output
     * section, for the same reason. ALIGN(0x2000) brings the code that ends below $C02000 to $C02000;
     * the guard at the end of the file refuses the rest. The grid ends at $C04000, and the ALIGN that follows
     * therefore moves nothing there. */
    . = ALIGN(0x2000);
    KEEP(*(.grille))
    _fin_grille = .;
    . = ALIGN(0x4000);
    KEEP(*(.sinus))
    _fin_sinus = .;
    KEEP(*(.alea))
    _fin_alea = .;
    /* THE HIGH ZONE, AT $C04300: the code without an imposed address that no longer fits below $C04000
     * (layer 3). An input section `.haut`, chosen by `.section .haut, "ax"` in the file:
     * a name in `.text…` would already be taken by `*(.text*)` above, `ld` placing a section at the
     * first pattern that names it. In the same output section as the table, and adjacent to it,
     * so that no gap arises between the two. The calls that cross it are absolute `jsr`/`jmp`
     * (read in the code, on 2026-10-21), except the `bsr.w _mess_out` of `int1.s`. */
    _debut_haut = .;
    *(.haut)
    /* THE CHEAT TABLE, after all the code of the high zone (`src/c0/cheats.s`): it alone
     * grows with the database, and thus pushes back no relative call. */
    KEEP(*(.cheats))
    _fin_haut = .;
  } > bios =0xFF
  .data    : { *(.data*) } > bios
  /* NOLOAD: nothing to emit in the image, the RAM not being initialised at load. */
  .bss (NOLOAD) : { *(.bss*) *(COMMON) } > ram
  /DISCARD/ : { *(.comment) *(.note*) *(.eh_frame*) }
}

/* THE GRID GUARD. The code must stop before $C02000: beyond, it would cover the
 * grid that games read (measured, `grille.s`). It also holds the random table, which comes after. */
ASSERT(_fin_code <= 0xC02000,
  "le code atteint $C02000 : il recouvrirait la grille, voir src/c0/grille.s ; le code sans adresse imposee va en .haut")
ASSERT(_grille == 0xC02000 && _fin_grille == 0xC04000,
  "la grille n est plus a $C02000-$C03FFF, voir src/c0/grille.s")
/* THE SINE TABLE GUARD: the anchor and the size, 256 words (DECISIONS §18). */
ASSERT(_table_sinus == 0xC04000,
  "la table du sinus n est plus a $C04000, voir src/c0/sinus.s")
ASSERT(_fin_sinus - _table_sinus == 512,
  "la table du sinus ne fait plus 512 octets, voir src/c0/sinus.s")
/* THE RANDOM TABLE GUARD: the anchor and the size. */
ASSERT(_table_alea == 0xC04200,
  "la table d alea n est plus a $C04200, voir src/c0/alea.s")
ASSERT(_fin_alea - _table_alea == 256,
  "la table d alea ne fait plus 256 octets, voir src/c0/alea.s")
/* THE HIGH ZONE GUARD: it starts just after the table, and ends within the 128 KiB of the image.
 * The `bios` region would already refuse an overflow; this one says it in the BIOS's terms. */
ASSERT(_debut_haut == 0xC04300,
  "la zone haute ne part plus a $C04300, juste apres la table d alea")
ASSERT(_fin_haut <= 0xC20000,
  "la zone haute deborde des 128 Kio de l image")

ASSERT(SIZEOF(.data) == 0,
  "un .data non vide demande une recopie ROM vers RAM au reset : declarer la globale const, ou la mettre en .bss")
