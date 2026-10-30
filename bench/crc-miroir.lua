-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- A 512 KiB P-ROM seen as on a board that does not decode A19: its upper half a mirror of the
-- lower one, in the fixed P-ROM ($080000-$0FFFFF returns $000000-$07FFFF) and in the bank window
-- ($280000-$2FFFFF returns $200000-$27FFFF), through two read taps. ASSUMED: this is how the
-- hardware serves it; MAME, for its part, puts zeros beyond the file
-- (`measured/2026-10-25-crc-cartouche.tsv`).
-- Loaded by `son.lua` (J_AUSSI), it plays no input. For the CARTRIDGE CRC screen (`src/c0/crc.s`),
-- scene crc-miroir of `parcours.sh`: FIXED 0512K and the file's CRC, which `-listxml` publishes.
if _G.CRCMIROIR then return end
local p = manager.machine.devices[":maincpu"].spaces["program"]
_G.CRCMIROIR = {
  p:install_read_tap(0x080000, 0x0FFFFF, "miroir-fixe", function(o) return p:read_u16((o & ~1) - 0x80000) end),
  p:install_read_tap(0x280000, 0x2FFFFF, "miroir-fenetre", function(o) return p:read_u16((o & ~1) - 0x80000) end),
}
