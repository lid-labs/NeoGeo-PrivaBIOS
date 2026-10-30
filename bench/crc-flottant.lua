-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- A cartridge without a bank chip, whose $200000-$2FFFFF window reads only a single word: $5700,
-- the one a real ssideki cartridge read (`measured/2026-10-29-crc-ssideki-materiel.tsv`), through
-- a read tap. MAME, for its part, serves the fixed P-ROM there. Loaded by `son.lua` (J_AUSSI), it
-- plays no input. For the CARTRIDGE CRC screen (`src/c0/crc.s`), scene crc-flottant of
-- `parcours.sh`: BANKS NONE.
if _G.CRCFLOTTANT then return end
local p = manager.machine.devices[":maincpu"].spaces["program"]
_G.CRCFLOTTANT = {
  p:install_read_tap(0x200000, 0x2FFFFF, "fenetre-flottante", function(o, d, m) return 0x5700 end),
}
