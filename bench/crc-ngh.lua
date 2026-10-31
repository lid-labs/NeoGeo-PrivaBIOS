-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- A cartridge whose NGH was changed, a hack for instance: the word at $108 reads CRCNGH (hex),
-- through a read tap, from the boot on. Loaded by `son.lua` (J_AUSSI), it plays no input. For the
-- CARTRIDGE CRC screen (`src/c0/crc.s`), scenes crc-hack-* of `parcours.sh`.
if _G.CRCNGH then return end
local v = tonumber(os.getenv("CRCNGH"), 16)
local p = manager.machine.devices[":maincpu"].spaces["program"]
_G.CRCNGH = {
  p:install_read_tap(0x108, 0x109, "ngh-change", function(o, d, m) return v end),
}
