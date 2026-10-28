-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- Jig des scores, chargé avec `son.lua` (J_AUSSI), sans fenêtre : la zone de sauvegarde du jeu d'un
-- boot à l'autre, et l'horloge que le jeu lit. `son.lua` joue les entrées et quitte MAME ; celui-ci ne
-- fait que relever (et, si on le lui demande, fausser la date que le BIOS donne au jeu).
--
-- LA ZONE DU JEU : le pointeur long de $00010E et la taille du mot de $000112 (« 68k program
-- header »), lus dans la région de la cartouche montée (`:cslot1:maincpu`), jamais sur le bus.
-- C'est la zone que le BIOS recopie en backup RAM (`src/c0/c0.s`, `_sauver_jeu`).
--
-- Réglages :
--   SC_OUT     fichier de sortie (obligatoire)
--   SC_DUMPS   trames où écrire la zone en hexadécimal (« f<n> ZONE <hex> »)
--   SC_FENETRE « a-b » : les octets de la zone que le JEU écrit sur ces trames, qu'il change ou non
--              leur valeur, comptés au bilan (« f<n> ECRITS jeu=<k> changes=<c> »)
--   SC_DATE    « AAMMJJ » (BCD) : la date que le BIOS écrit pour le jeu ($10FDD2 année, $10FDD3 mois,
--              $10FDD4 jour ; « BIOS RAM locations ») est remplacée par celle-ci au vol — une date
--              d'horloge que MAME ne laisse pas choisir (il prend celle de l'hôte)
--
-- CE QUI EST RELEVÉ — ce jig ne consigne aucun PC ni aucun octet de ROM de BIOS (`docs/DECISIONS.md`
-- §8) ; le PC n'est lu que pour dire qui écrit (bios dans $C00000-$C1FFFF, jeu sinon) :
--   « f<n> Z bios=<k> jeu=<k> » : les écritures dans la zone, par côté, sur une trame qui en a ;
--   « f<n> RESTAURE <hex> » (si SC_RESTAURE=1) : la zone telle que le BIOS vient de l'écrire en entier
--     (sa dernière adresse écrite par le BIOS), avant que le jeu y touche ;
--   « f<n> CAL » : un appel du jeu à READ_CALENDAR ($C0045C, « BIOS calls »), compté comme
--     `appels.lua` (la lecture de l'entrée suivie d'une écriture en RAM de travail, le jeu ayant la
--     main, $10FD80 bit 7) ;
--   « f<n> DATE <aa mm jj> » : la date écrite par le BIOS (après substitution) quand elle change ;
--   « f<n> CALLU <k> » : les lectures par le jeu de $10FDD2-$10FDD8 sur la trame.
if _G.SCORES then return end
_G.SCORES = {}
local G = _G.SCORES
local m = manager.machine
local cpu = m.devices[":maincpu"]
local p = cpu.spaces["program"]
local OUT = assert(os.getenv("SC_OUT"), "SC_OUT manquant")
local f = io.open(OUT, "w")
local function W(fmt, ...) f:write(string.format(fmt, ...) .. "\n") f:flush() end
local function cote() local a = cpu.state["PC"].value & 0xFFFFFF return (a >= 0xC00000 and a < 0xC20000) and "bios" or "jeu" end

local rg = m.memory.regions[":cslot1:maincpu"]
assert(rg, "région :cslot1:maincpu introuvable")
local function l32(a) return (rg:read_u8(a) << 24) | (rg:read_u8(a + 1) << 16) | (rg:read_u8(a + 2) << 8) | rg:read_u8(a + 3) end
-- La région porte les mots octets inversés (`load16_word_swap`) quand « NEO-GEO » ne s'y lit pas tel quel.
local inv = rg:read_u8(0x100) ~= 0x4E
local function oct(a) return rg:read_u8(inv and (a ~ 1) or a) end
local Z0 = (oct(0x10E) << 24) | (oct(0x10F) << 16) | (oct(0x110) << 8) | oct(0x111)
local ZN = (oct(0x112) << 8) | oct(0x113)
local NGH = (oct(0x108) << 8) | oct(0x109)
W("# ngh %04X zone %06X+%04X%s", NGH, Z0, ZN, inv and " (mots inversés)" or "")

local n = 0
local dumps = {}
for x in (os.getenv("SC_DUMPS") or ""):gmatch("%d+") do dumps[tonumber(x)] = true end
local F0, F1 = (os.getenv("SC_FENETRE") or "0-0"):match("(%d+)-(%d+)") F0, F1 = tonumber(F0), tonumber(F1)
local ecrits, changes = {}, {}
local zb, zj = 0, 0
if ZN > 0 and ZN <= 0x1000 and Z0 >= 0x100000 and Z0 + ZN <= 0x110000 then
  local RESTAURE = os.getenv("SC_RESTAURE") == "1"
  local DER = Z0 + ZN - 1
  G.tz = p:install_write_tap(Z0 & ~1, (Z0 + ZN - 1) | 1, "sc_zone", function(o, d, mk)
    if cote() == "bios" then
      zb = zb + 1
      local fin = (o == DER and mk & 0xFF00 ~= 0) or (o + 1 == DER and mk & 0x00FF ~= 0)
      if RESTAURE and fin then
        G.moi = true
        local t = {} for a = Z0, DER - 1 do t[#t + 1] = string.format("%02X", p:read_u8(a)) end
        G.moi = false
        t[#t + 1] = string.format("%02X", (o == DER) and ((d >> 8) & 0xFF) or (d & 0xFF))
        W("f%d RESTAURE %s", n + 1, table.concat(t))
      end
      return
    end
    zj = zj + 1
    if n >= F0 and n <= F1 then
      local function un(a, v) if a >= Z0 and a < Z0 + ZN then ecrits[a] = true if p:read_u8(a) ~= v then changes[a] = true end end end
      if mk & 0xFF00 ~= 0 then un(o, (d >> 8) & 0xFF) end
      if mk & 0x00FF ~= 0 then un(o + 1, d & 0xFF) end
    end
  end)
end

-- READ_CALENDAR appelé par le jeu, la méthode d'`appels.lua`.
local e = false
G.tw = p:install_write_tap(0x100000, 0x10FFFF, "sc_w", function() if e then e = false W("f%d CAL", n) end end)
G.tr = p:install_read_tap(0x100000, 0x10FFFF, "sc_r", function() e = false end)
G.tp = p:install_read_tap(0x000000, 0x0FFFFF, "sc_p", function() e = false end)
G.tb = p:install_read_tap(0xC0045C, 0xC0045D, "sc_b", function() e = (p:read_u8(0x10FD80) & 0x80) ~= 0 end)

local lus = 0
G.tl = p:install_read_tap(0x10FDD2, 0x10FDD9, "sc_l", function(o, d, mk) if not G.moi and cote() == "jeu" then lus = lus + 1 end end)
local AA, MM, JJ = (os.getenv("SC_DATE") or ""):match("^(%x%x)(%x%x)(%x%x)$")
local date = {}
G.td = p:install_write_tap(0x10FDD2, 0x10FDD5, "sc_d", function(o, d, mk)
  if cote() ~= "bios" or not AA then return end
  local v = { [0x10FDD2] = tonumber(AA, 16), [0x10FDD3] = tonumber(MM, 16), [0x10FDD4] = tonumber(JJ, 16) }
  local hi, lo = v[o], v[o + 1]
  local r = d
  if hi and mk & 0xFF00 ~= 0 then r = (r & 0x00FF) | (hi << 8) end
  if lo and mk & 0x00FF ~= 0 then r = (r & 0xFF00) | lo end
  return r
end)
local der = nil

emu.register_frame_done(function()
  n = n + 1
  if zb + zj > 0 then W("f%d Z bios=%d jeu=%d", n, zb, zj) zb, zj = 0, 0 end
  if lus > 0 then W("f%d CALLU %d", n, lus) lus = 0 end
  G.moi = true
  local d = string.format("%02X %02X %02X", p:read_u8(0x10FDD2), p:read_u8(0x10FDD3), p:read_u8(0x10FDD4))
  if d ~= der then der = d W("f%d DATE %s", n, d) end
  if dumps[n] and ZN > 0 then
    local t = {} for a = Z0, Z0 + ZN - 1 do t[#t + 1] = string.format("%02X", p:read_u8(a)) end
    W("f%d ZONE %s", n, table.concat(t))
  end
  G.moi = false
  if n == F1 then
    local k, c = 0, 0 for _ in pairs(ecrits) do k = k + 1 end for _ in pairs(changes) do c = c + 1 end
    W("f%d ECRITS jeu=%d changes=%d sur %d", n, k, c, ZN)
    -- Les décalages écrits, en plages « a-b » (hexadécimal, depuis le début de la zone).
    local t, a0, a1 = {}, nil, nil
    for a = Z0, Z0 + ZN do
      if ecrits[a] then if not a0 then a0 = a end a1 = a
      elseif a0 then t[#t + 1] = string.format("%X-%X", a0 - Z0, a1 - Z0) a0 = nil end
    end
    W("f%d ECRITS_OFF %s", n, table.concat(t, " "))
  end
end)
