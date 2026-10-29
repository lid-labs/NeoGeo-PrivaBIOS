-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- Une cartouche sans puce de banques, dont la fenêtre $200000-$2FFFFF ne lit qu'un seul mot : $5700,
-- celui qu'a lu une vraie cartouche ssideki (`measured/2026-10-29-crc-ssideki-materiel.tsv`), par un
-- tap de lecture. MAME, lui, y sert la P-ROM fixe. Chargé par `son.lua` (J_AUSSI), il ne joue aucune
-- entrée. Pour l'écran CARTRIDGE CRC (`src/c0/crc.s`), scène crc-flottant de `parcours.sh` : BANKS NONE.
if _G.CRCFLOTTANT then return end
local p = manager.machine.devices[":maincpu"].spaces["program"]
_G.CRCFLOTTANT = {
  p:install_read_tap(0x200000, 0x2FFFFF, "fenetre-flottante", function(o, d, m) return 0x5700 end),
}
