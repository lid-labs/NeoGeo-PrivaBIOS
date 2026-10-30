-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- Clock jig, loaded with `son.lua` (J_AUSSI), windowless: the µPD4990A clock returns the date it
-- is given, and not the host's that MAME passes it. For every reader of the clock, reference
-- BIOS included: the jig only falsifies the bit that the chip outputs, at the moment it outputs it.
--   HL_DATE  "AAMMJJS": year, month, day (BCD) and day of week (0-6); the time returned is
--            12:00:00
-- THE MODEL, read in the "UPD4990" and "Memory mapped registers" pages of the NeoGeo Development
-- Wiki, and in `src/c0/cal.s` which cites them with the NEC datasheet: REG_RTCCTRL ($380051)
-- carries DATA IN on bit 0, CLK on bit 1, STB on bit 2; the chip takes DATA IN on the rising edge
-- of CLK, into a four-bit command register; STB executes the command; after "Register Shift"
-- ($1), the shift register outputs on DATA OUT (REG_STATUS_A, $320001, bit 7) one bit per rising
-- edge of CLK, the first before any edge: second, minute, hour, day (BCD, 8 bits each), day of
-- week (4), month (4, binary), year (8, BCD), least significant first. "Time Read" ($3) loads
-- the register; the jig, for its part, loads it with its date at each STB of $3.
if _G.HORLOGE then return end
_G.HORLOGE = {}
local G = _G.HORLOGE
local m = manager.machine
local p = m.devices[":maincpu"].spaces["program"]
local D = assert(os.getenv("HL_DATE"), "HL_DATE manquant")
local AA, MM, JJ, S = D:match("^(%x%x)(%x%x)(%x%x)(%d)$")
assert(AA, "HL_DATE : AAMMJJS attendu")
local mois = tonumber(MM, 10) -- BCD read as decimal: the chip's binary month
local champs = { { 0x00, 8 }, { 0x00, 8 }, { 0x12, 8 }, { tonumber(JJ, 16), 8 }, { tonumber(S), 4 }, { mois, 4 }, { tonumber(AA, 16), 8 } }
local bits = {}
for _, c in ipairs(champs) do for k = 0, c[2] - 1 do bits[#bits + 1] = (c[1] >> k) & 1 end end
local cmd, clk, idx, decale = 0, 0, 1, false
G.tw = p:install_write_tap(0x380050, 0x380051, "hl_w", function(o, d, mk)
  if mk & 0x00FF == 0 then return end
  local v = d & 0xFF
  local c = (v >> 1) & 1
  if c == 1 and clk == 0 then
    cmd = ((cmd >> 1) | ((v & 1) << 3)) & 0x0F -- least significant first: the last bit enters at the top
    if decale then idx = idx + 1 end
  end
  clk = c
  if v & 4 ~= 0 then
    if cmd == 3 then decale = false idx = 1
    elseif cmd == 1 then decale = true idx = 1 end
  end
end)
G.tr = p:install_read_tap(0x320000, 0x320001, "hl_r", function(o, d, mk)
  if not decale or mk & 0x00FF == 0 then return end
  local b = bits[idx] or 0
  return (d & 0xFF7F) | (b << 7)
end)
