-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- Soft-DIP jig at hand-over (`src/c0/c0.s`, `_slot_inscrit`), windowless. Records, at the first
-- frame that ends with the PC in the cartridge (< $C00000: the game is in control):
--   - BIOS_COUNTRY_CODE ($10FD83) and the region's soft-DIP pointer (header $116/$11A/$11E,
--     4 × code, a code outside 0-2 taking Europe like `c0.s`);
--   - BIOS_GAME_DIP ($10FD84-$10FD93);
--   - who wrote GAME_DIP before the hand-over: a tap counts the writes made from the BIOS
--     (PC ≥ $C00000) and from the cartridge. This jig logs no PC, only these two counts;
--   - for a pointer in the banked area ($200000-$2FFFFF), the MiB of the region
--     `:cslot1:maincpu` of which the block's 32 bytes read at that address are the copy, at
--     frame 1 and at hand-over: it is the bank in place, read in the GAME's ROM only.
--     No byte of the block is written in the record.
--
--   S_OUT  output file, one "key=value" line (mandatory)
--   S_FIN  limit frame (default 900): with no hand-over by then, "remise=aucune"
--
-- No input is pressed. Fresh NVRAM: it is up to the launcher to provide it.
if _G.SOFTDIP then return end
_G.SOFTDIP = {}
local OUT = os.getenv("S_OUT")
if not OUT then print("SOFTDIP: S_OUT manquant") manager.machine:exit() return end
local FIN = tonumber(os.getenv("S_FIN") or "900")
local m = manager.machine
local cpu = m.devices[":maincpu"]
local p = cpu.spaces["program"]
local rom = m.memory.regions[":cslot1:maincpu"]

local ecr_bios, ecr_cart, apres = 0, 0, false
_G.SOFTDIP.tap = p:install_write_tap(0x10FD84, 0x10FD93, "softdip", function(off, data, mask)
  if apres then return end
  if (cpu.state["PC"].value & 0xFFFFFF) >= 0xC00000 then ecr_bios = ecr_bios + 1
  else ecr_cart = ecr_cart + 1 end
end)

local function octets(a, n)
  local t = {} for i = 0, n - 1 do t[#t + 1] = string.format("%02X", p:read_u8(a + i)) end
  return table.concat(t, " ")
end
local function pointeur()
  local code = p:read_u8(0x10FD83)
  local c = code <= 2 and code or 2
  return code, p:read_u32(0x116 + 4 * c)
end
-- The MiB of the game's region that holds, at the block's offset in its window, the 32 bytes
-- read at the banked address. Several: "ambigu"; none: "aucun".
local function banque(ptr)
  if not rom or ptr < 0x200000 or ptr > 0x2FFFE0 then return "-" end
  local lu = {} for i = 0, 31 do lu[i] = p:read_u8(ptr + i) end
  local trouves = {}
  local off = ptr - 0x200000
  for k = 0, (rom.size // 0x100000) - 1 do
    local ok = true
    for i = 0, 31 do
      -- The region is in 68000 words; read_u8 reads it in the CPU's order.
      if rom:read_u8(k * 0x100000 + off + i) ~= lu[i] then ok = false break end
    end
    if ok then trouves[#trouves + 1] = string.format("%X", k * 0x100000) end
  end
  if #trouves == 0 then return "aucun" end
  return table.concat(trouves, "+")
end

local n, fini, b1 = 0, false, "-"
emu.register_frame_done(function()
  if fini then return end
  n = n + 1
  if n == 1 then local _, ptr = pointeur() b1 = banque(ptr) end
  local pc = cpu.state["PC"].value & 0xFFFFFF
  if pc < 0xC00000 or n >= FIN then
    apres = true
    local code, ptr = pointeur()
    local f = io.open(OUT, "w")
    f:write(string.format("remise=%s pays=%02X pointeur=%06X banque_t1=%s banque_remise=%s " ..
      "ecr_bios=%d ecr_cart=%d game_dip=%s\n",
      pc < 0xC00000 and tostring(n) or "aucune", code, ptr, b1, banque(ptr),
      ecr_bios, ecr_cart, octets(0x10FD84, 16)))
    f:close()
    fini = true
    m:exit()
  end
end)
