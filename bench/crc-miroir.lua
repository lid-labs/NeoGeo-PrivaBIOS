-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- Une P-ROM de 512 Kio vue comme sur une carte qui ne décode pas A19 : sa moitié haute miroir de la
-- basse, dans la P-ROM fixe ($080000-$0FFFFF rend $000000-$07FFFF) et dans la fenêtre des banques
-- ($280000-$2FFFFF rend $200000-$27FFFF), par deux taps de lecture. SUPPOSÉ : c'est ainsi que le
-- matériel la sert ; MAME, lui, met des zéros au-delà du fichier (`measured/2026-10-25-crc-cartouche.tsv`).
-- Chargé par `son.lua` (J_AUSSI), il ne joue aucune entrée. Pour l'écran CARTRIDGE CRC (`src/c0/crc.s`),
-- scène crc-miroir de `parcours.sh` : FIXED 0512K et le CRC du fichier, que `-listxml` publie.
if _G.CRCMIROIR then return end
local p = manager.machine.devices[":maincpu"].spaces["program"]
_G.CRCMIROIR = {
  p:install_read_tap(0x080000, 0x0FFFFF, "miroir-fixe", function(o) return p:read_u16((o & ~1) - 0x80000) end),
  p:install_read_tap(0x280000, 0x2FFFFF, "miroir-fenetre", function(o) return p:read_u16((o & ~1) - 0x80000) end),
}
