-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- Jig de l'horloge, chargé avec `son.lua` (J_AUSSI), sans fenêtre : l'horloge µPD4990A rend la date
-- qu'on lui donne, et non celle de l'hôte que MAME lui passe. Pour tout lecteur de l'horloge, BIOS
-- de référence compris : le jig ne fausse que le bit que la puce sort, au moment où elle le sort.
--   HL_DATE  « AAMMJJS » : année, mois, jour (BCD) et jour de semaine (0-6) ; l'heure rendue est
--            12:00:00
-- LE MODÈLE, lu dans les pages « UPD4990 » et « Memory mapped registers » du NeoGeo Development
-- Wiki, et dans `src/c0/cal.s` qui les cite avec la fiche NEC : REG_RTCCTRL ($380051) porte DATA IN
-- au bit 0, CLK au bit 1, STB au bit 2 ; la puce prend DATA IN au front montant de CLK, dans un
-- registre de commande de quatre bits ; STB exécute la commande ; après « Register Shift » ($1), le
-- registre à décalage sort sur DATA OUT (REG_STATUS_A, $320001, bit 7) un bit par front montant de
-- CLK, le premier avant tout front : seconde, minute, heure, jour (BCD, 8 bits chacun), jour de
-- semaine (4), mois (4, binaire), année (8, BCD), poids faible d'abord. « Time Read » ($3) charge
-- le registre ; le jig, lui, le charge de sa date à chaque STB de $3.
if _G.HORLOGE then return end
_G.HORLOGE = {}
local G = _G.HORLOGE
local m = manager.machine
local p = m.devices[":maincpu"].spaces["program"]
local D = assert(os.getenv("HL_DATE"), "HL_DATE manquant")
local AA, MM, JJ, S = D:match("^(%x%x)(%x%x)(%x%x)(%d)$")
assert(AA, "HL_DATE : AAMMJJS attendu")
local mois = tonumber(MM, 10) -- BCD lu en décimal : le mois binaire de la puce
local champs = { { 0x00, 8 }, { 0x00, 8 }, { 0x12, 8 }, { tonumber(JJ, 16), 8 }, { tonumber(S), 4 }, { mois, 4 }, { tonumber(AA, 16), 8 } }
local bits = {}
for _, c in ipairs(champs) do for k = 0, c[2] - 1 do bits[#bits + 1] = (c[1] >> k) & 1 end end
local cmd, clk, idx, decale = 0, 0, 1, false
G.tw = p:install_write_tap(0x380050, 0x380051, "hl_w", function(o, d, mk)
  if mk & 0x00FF == 0 then return end
  local v = d & 0xFF
  local c = (v >> 1) & 1
  if c == 1 and clk == 0 then
    cmd = ((cmd >> 1) | ((v & 1) << 3)) & 0x0F -- poids faible d'abord : le dernier bit entre en haut
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
