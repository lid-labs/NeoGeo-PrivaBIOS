-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- Jig de la carte mémoire protégée ou retirée, chargé avec `son.lua` (J_AUSSI), sans fenêtre. MAME
-- ne sait pas protéger une carte en écriture : sa machine rend le bit 6 de REG_STATUS_B à 0 dès
-- qu'une carte est là (`neogeo.cpp`, `get_memcard_status` : « we are always write enabled »). Ce jig
-- fausse donc la LECTURE de REG_STATUS_B ($380000, l'octet haut ; « Memory card » : CD1 bit 4, CD2
-- bit 5, protection bit 6), rien d'autre : la carte de MAME, elle, accepte toujours l'écriture.
--   CP_PROTEGE  « a-b » séparés par des virgules : sur ces trames, le bit 6 lu à 1 (protégée)
--   CP_ABSENTE  « a-b » : sur ces trames, les bits 4, 5 et 6 lus à 1, comme MAME sans carte
-- Une ligne « f<n> CP <état> » à chaque changement, dans le son.txt de `son.lua` n'étant pas
-- accessible ici : dans CP_OUT s'il est posé.
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
