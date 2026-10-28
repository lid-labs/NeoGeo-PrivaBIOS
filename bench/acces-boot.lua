-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- Jig des accès de boot, sans fenêtre : la liste ordonnée de TOUS les accès du 68000 aux registres
-- ($300000-$3FFFFF) et à l'espace de la P-ROM ($000000-$0FFFFF), du reset jusqu'à la première
-- lecture de « NE » en $000100 (le début de « NEO-GEO »), puis jusqu'à la fin de cette trame.
-- Écrit pour comparer, accès par accès, ce que la référence et notre image font avant de lire
-- l'en-tête d'une cartouche (retour du matériel du 2026-10-24, docs/ESSAI-MATERIEL.md).
--
--   SDL_VIDEODRIVER=dummy SDL_MAC_BACKGROUND_APP=1 AB_OUT=<sortie.tsv> \
--   mame ng_mv2f -bios euro -hashpath <mame>/hash -rompath <roms> -cart1 mslug \
--     -video none -sound none -nothrottle -nvram_directory <neuf> \
--     -autoboot_script bench/acces-boot.lua
--
-- Réglages par l'environnement :
--   AB_OUT     TSV de sortie (obligatoire)
--   AB_FIN     trame d'arrêt si « NE » n'est jamais lu (défaut 900)
--   AB_APRES   trames relevées encore après celle de « NE », accès du BIOS seulement (défaut 0) :
--              le reste du parcours des slots et le retour à l'écran
--   AB_FLOTTANT 1 : SIMULE LE MATÉRIEL tel que le décrit le wiki (NEO-F0 : « SYSTEMB is used to
--              gate the SLOT* outputs » ; Signals : « SYSTEM: low when onboard ROMs selected ») :
--              toute lecture de $000080-$0FFFFF et $200000-$2FFFFF faite pendant que la bascule
--              BRDFIX/CRTFIX est sur BRDFIX ($3A000B, l'état du reset) rend le mot à l'adresse du
--              PC — le bus flottant que MAME rend lui-même pour un trou (`unmapped_r`). Les
--              lectures ainsi faussées sont comptées (genre F au bilan). SUPPOSÉ : que l'état du
--              reset soit BRDFIX ; le wiki ne le dit pas, et la référence écrit l'un ou l'autre
--              avant de lire l'en-tête (relevé de ce jig).
--
-- CE QUI EST RELEVÉ — des adresses, des largeurs, des valeurs ÉCRITES et des valeurs lues dans les
-- registres et dans la P-ROM du JEU. Ce jig ne consigne aucun PC, ni aucun octet de la ROM du BIOS : les lectures de
-- $000000-$00007F, que la carte sert depuis le BIOS sous REG_SWPBIOS, sortent sans donnée, comme les
-- données VRAM ($3C0002, comptées seulement). Le PC n'est lu que pour dire QUI accède (bios dans
-- $C00000-$C1FFFF, jeu sinon) et pour rendre le mot préchargé d'une lecture faussée — `docs/DECISIONS.md` §8.
--
-- Colonnes : n (rang), trame, fraction de trame, genre (R/W), adresse de l'OCTET (la paire pour un
-- mot), largeur (o octet pair, i octet impair, m mot), donnée, répétitions consécutives identiques,
-- côté. Les accès identiques consécutifs (même genre, adresse, largeur, donnée, côté) se fondent en
-- une ligne : l'attente d'un registre en boucle tient sur une.
if _G.ACCESBOOT then return end
_G.ACCESBOOT = {}
local G = _G.ACCESBOOT
local OUT = os.getenv("AB_OUT")
local m = manager.machine
if not OUT then print("ACCESBOOT: AB_OUT manquant") m:exit() return end
local FIN = tonumber(os.getenv("AB_FIN") or "900")
local APRES = tonumber(os.getenv("AB_APRES") or "0")
local trame_ne = nil
local FLOTTANT = os.getenv("AB_FLOTTANT") == "1"
local cpu = m.devices[":maincpu"]
local p = cpu.spaces["program"]
local f = io.open(OUT, "w")
f:write("n\ttrame\tfraction\tgenre\tadresse\tlargeur\tdonnee\trepet\tcote\n")

local trame, t0, PERIODE = 0, 0, 1 / 59.185
local n, der, vu_ne = 0, nil, false
local carte_fix = "BRDFIX?"          -- l'état de la bascule, SUPPOSÉ BRDFIX au reset
local faussees, interne = 0, false

local function pc() return cpu.state["PC"].value & 0xFFFFFF end
local function cote() local a = pc() return (a >= 0xC00000 and a <= 0xC1FFFF) and "bios" or "jeu" end

local function vider()
  if der then
    f:write(string.format("%d\t%d\t%.3f\t%s\t%06X\t%s\t%s\t%d\t%s\n", der.n, der.t, der.fr, der.g,
      der.a, der.l, der.d, der.r, der.c))
    der = nil
  end
end

local function noter(g, off, data, mask)
  if vu_ne and (trame > trame_ne + APRES or cote() ~= "bios") then return end
  local a, l, d
  if mask == 0xFFFF then a, l, d = off, "m", string.format("%04X", data & 0xFFFF)
  elseif mask == 0xFF00 then a, l, d = off, "o", string.format("%02X", (data >> 8) & 0xFF)
  else a, l, d = off + 1, "i", string.format("%02X", data & 0xFF) end
  if off < 0x80 and g == "R" then d = "-" end            -- vecteurs : ROM du BIOS sous SWPBIOS
  if off >= 0x3C0002 and off <= 0x3C0003 then d = "-" end -- données VRAM : comptées seulement
  local c = cote()
  if der and der.g == g and der.a == a and der.l == l and der.d == d and der.c == c then
    der.r = der.r + 1 return
  end
  vider()
  n = n + 1
  der = { n = n, t = trame, fr = (m.time:as_double() - t0) / PERIODE, g = g, a = a, l = l, d = d,
    r = 1, c = c }
end

-- La bascule BRDFIX ($3A000B) / CRTFIX ($3A001B), suivie pour AB_FLOTTANT : bit 4 de l'adresse
-- (« Registers go in pairs, bit 4 of the address is actually the data bit »).
G.t_sys = p:install_write_tap(0x3A0000, 0x3BFFFF, "ab_sys", function(off, data, mask)
  if (off & 0x0F) == 0x0A then carte_fix = (off & 0x10) ~= 0 and "CRTFIX" or "BRDFIX" end
end)

local function flotte(off)
  if not FLOTTANT or carte_fix == "CRTFIX" then return false end
  if off < 0x80 then return false end
  return off < 0x100000 or (off >= 0x200000 and off < 0x300000)
end

-- UNE ÉCRITURE DE REG_SLOT FAIT TOMBER LES TAPS DE LA P-ROM : MAME y réinstalle la ROM du slot
-- (`set_slot_idx`, `unmap_readwrite` puis `install_rom` sur $000080-$0FFFFF). On les repose deux
-- lectures du BIOS plus tard, quand le gestionnaire du nouveau slot est en place — la recette de
-- `multislot.lua`.
G.t_rw = p:install_write_tap(0x300000, 0x3FFFFF, "ab_rw", function(off, data, mask)
  noter("W", off, data, mask)
  if (off & 0xFE00F0) == 0x380020 and mask & 0xFF ~= 0 then G.retaper, G.attente = true, 2 end
end)
G.t_rr = p:install_read_tap(0x300000, 0x3FFFFF, "ab_rr", function(off, data, mask)
  if interne then return end
  noter("R", off, data, mask)
end)
G.t_pw = p:install_write_tap(0x000000, 0x0FFFFF, "ab_pw", function(off, data, mask)
  noter("W", off, data, mask)
end)
G.t_pr = p:install_read_tap(0x000000, 0x0FFFFF, "ab_pr", function(off, data, mask)
  if interne then return end
  local c = cote()
  if flotte(off) then
    interne = true
    local v = p:read_u16(pc() & 0xFFFFFE)  -- le mot préchargé, comme `unmapped_r` de MAME
    interne = false
    faussees = faussees + 1
    data = v
  end
  -- Le jeu qui tourne n'est plus relevé : seules ses lectures d'avant la fin de trame comptent.
  if c == "bios" or not vu_ne then noter("R", off, data, mask) end
  if off == 0x100 and c == "bios" and (data & 0xFFFF) == 0x4E45 and not vu_ne then
    vu_ne = true
    vider()
    f:write(string.format("#\t%d\tpremiere lecture de NE en $000100 (rang %d), bascule %s\n", trame, n, carte_fix))
    trame_ne = trame
  end
  if flotte(off) then return data end
end)
if FLOTTANT then
  G.t_p2 = p:install_read_tap(0x200000, 0x2FFFFF, "ab_p2", function(off, data, mask)
    if interne or not flotte(off) then return end
    interne = true
    local v = p:read_u16(pc() & 0xFFFFFE)
    interne = false
    faussees = faussees + 1
    return v
  end)
end

G.t_c0 = p:install_read_tap(0xC00000, 0xC1FFFF, "ab_c0", function()
  if not G.retaper then return end
  G.attente = G.attente - 1
  if G.attente > 0 then return end
  G.retaper = false
  for _, k in ipairs({ "t_pr", "t_pw", "t_p2" }) do if G[k] then G[k]:reinstall() end end
end)

emu.register_frame_done(function()
  t0 = m.time:as_double()
  trame = trame + 1
  if (trame_ne and trame > trame_ne + APRES) or trame > FIN then
    vider()
    f:write(string.format("#\tbilan\ttrames %d, accès relevés %d, NE vu %s, lectures faussées (F) %d, bascule finale %s\n",
      trame, n, tostring(vu_ne), faussees, carte_fix))
    f:close()
    m:exit()
  end
end)
