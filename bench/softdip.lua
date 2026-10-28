-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- Jig des soft-DIP à la remise (`src/c0/c0.s`, `_slot_inscrit`), sans fenêtre. Relève, à la
-- première trame qui finit avec le PC dans la cartouche (< $C00000 : le jeu a la main) :
--   - BIOS_COUNTRY_CODE ($10FD83) et le pointeur soft-DIP de la région (en-tête $116/$11A/$11E,
--     4 × code, un code hors de 0-2 prenant l'Europe comme `c0.s`) ;
--   - BIOS_GAME_DIP ($10FD84-$10FD93) ;
--   - qui a écrit GAME_DIP avant la remise : un tap compte les écritures faites depuis le BIOS
--     (PC ≥ $C00000) et depuis la cartouche. Ce jig ne consigne aucun PC, seulement ces deux comptes ;
--   - pour un pointeur dans la zone banquée ($200000-$2FFFFF), le MiB de la région
--     `:cslot1:maincpu` dont les 32 octets du bloc lus à cette adresse sont la copie, à la
--     trame 1 et à la remise : c'est la banque en place, lue dans la ROM du JEU seulement.
--     Aucun octet du bloc n'est écrit au relevé.
--
--   S_OUT  fichier de sortie, une ligne « clé=valeur » (obligatoire)
--   S_FIN  trame limite (défaut 900) : sans remise d'ici là, « remise=aucune »
--
-- Aucune entrée n'est pressée. NVRAM neuve : c'est au lanceur de la donner.
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
-- Le MiB de la région du jeu qui porte, à l'offset du bloc dans sa fenêtre, les 32 octets lus
-- à l'adresse banquée. Plusieurs : « ambigu » ; aucun : « aucun ».
local function banque(ptr)
  if not rom or ptr < 0x200000 or ptr > 0x2FFFE0 then return "-" end
  local lu = {} for i = 0, 31 do lu[i] = p:read_u8(ptr + i) end
  local trouves = {}
  local off = ptr - 0x200000
  for k = 0, (rom.size // 0x100000) - 1 do
    local ok = true
    for i = 0, 31 do
      -- La région est en mots 68000 ; read_u8 la lit dans l'ordre du CPU.
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
