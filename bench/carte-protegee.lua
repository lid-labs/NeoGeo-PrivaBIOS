-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- Protected or removed memory card jig, loaded with `son.lua` (J_AUSSI), windowless. MAME
-- cannot write-protect a card: its machine returns bit 6 of REG_STATUS_B at 0 as soon as a card
-- is there (`neogeo.cpp`, `get_memcard_status`: "we are always write enabled"). This jig
-- therefore falsifies the READ of REG_STATUS_B ($380000, the high byte; "Memory card": CD1 bit 4,
-- CD2 bit 5, protection bit 6), nothing else: MAME's card, for its part, always accepts writes.
--   CP_PROTEGE  "a-b" separated by commas: on these frames, bit 6 read as 1 (protected)
--   CP_ABSENTE  "a-b": on these frames, bits 4, 5 and 6 read as 1, like MAME without a card
-- One line "f<n> CP <état>" at each change, the son.txt of `son.lua` not being accessible
-- here: in CP_OUT if it is set.
if _G.CARTEPROT then return end
_G.CARTEPROT = {}
local G = _G.CARTEPROT
local m = manager.machine
local p = m.devices[":maincpu"].spaces["program"]
local function plages(v)
  local t = {}
  for a, b in (os.getenv(v) or ""):gmatch("(%d+)-(%d+)") do t[#t + 1] = { tonumber(a), tonumber(b) } end
  return t
end
local PROT, ABS = plages("CP_PROTEGE"), plages("CP_ABSENTE")
local function dans(t, n) for _, x in ipairs(t) do if n >= x[1] and n <= x[2] then return true end end return false end
local n, etat = 0, ""
local out = os.getenv("CP_OUT") and io.open(os.getenv("CP_OUT"), "w")
G.t = p:install_read_tap(0x380000, 0x380001, "cp_stb", function(o, d, mk)
  if mk & 0xFF00 == 0 then return end
  local ou = 0
  if dans(ABS, n) then ou = 0x7000 elseif dans(PROT, n) then ou = 0x4000 end
  if ou ~= 0 then return d | ou end
end)
emu.register_frame_done(function()
  n = n + 1
  local e = dans(ABS, n) and "absente" or (dans(PROT, n) and "protegee" or "normale")
  if e ~= etat then etat = e if out then out:write(string.format("f%d CP %s\n", n, e)) out:flush() end end
end)
