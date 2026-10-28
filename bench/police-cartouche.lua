-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- Jig de la police de la CARTOUCHE, sans fenêtre : la S ROM range-t-elle chiffres, majuscules,
-- espace et « : - / . » aux numéros de tuile du SFIX ? Question du jukebox, qui affichera du texte
-- sous REG_CRTFIX (le plan fixe lit alors la S ROM) parce que le pilote son du jeu tourne.
--
-- On ne lit AUCUN octet de ROM, ni de la cartouche ni de la carte : on pose une mire dans le plan
-- fixe et on lit l'ÉCRAN. La même mire est rendue deux fois, depuis la S ROM puis depuis le SFIX,
-- en basculant la seule source du plan fixe (item `0/m_fixed_layer_source` de `:spritegen`, que
-- REG_BRDFIX / REG_CRTFIX posent chez MAME). On ne touche pas à REG_BRDFIX lui-même : il bascule
-- aussi la M1 du Z80 (`src/c0/dip.s`), et le jeu perdrait son pilote son entre deux captures.
--
-- LA MIRE. 41 glyphes : 0-9, A-Z, espace, « : - / . ». En 8×8, tuile = code ASCII ; en 8×16,
-- tuile $100 + ASCII en haut, $200 + ASCII en bas (measured/2026-10-20-sfix-glyphes.tsv). Toutes
-- les cases sous la palette 15. 21 glyphes par ligne, colonnes 4 à 24 :
--   8×8  : lignes 6 et 8 du plan fixe ;  8×16 : lignes 12-13 et 16-17 (deux rangées suffisent).
--
-- LES INDEX DE COULEUR, décodés au pixel par cinq captures et non devinés. À la capture « plan b »
-- (b = 0..3), l'entrée i de la palette 15 est magenta si le bit b de i vaut 1, cyan sinon ; à la
-- capture « témoin », toutes les entrées 1-15 sont jaunes. Un pixel jaune au témoin et magenta ou
-- cyan aux quatre plans porte l'index qu'épellent ses quatre bits ; tout autre pixel est l'index 0,
-- transparent, par lequel on voit le jeu. Le décodage est fait hors de MAME (script d'analyse) sur
-- les captures brutes : ce jig n'écrit que des images.
--
-- LE JEU CONTINUE DE TOURNER, et il réécrit plan fixe et palettes. Deux taps remplacent la donnée
-- de toute écriture du jeu qui tomberait dans une case de la mire (adresse VRAM lue dans l'item
-- `m_vram_offset`, celle que l'écriture va toucher) ou dans la palette 15 ($4001E0-$4001FF, quelle
-- que soit la banque). Et l'état voulu est réécrit à chaque fin de trame, dans la banque en place.
-- Un jeu qui changerait de banque pendant la séquence montrerait la palette 15 de l'autre banque,
-- sans nos couleurs, et ses pixels passeraient pour l'index 0 : un tap compte donc les écritures
-- de REG_PALBANK0 / REG_PALBANK1 ($3A000F / $3A001F) qui changent de banque pendant la séquence,
-- et un compte non nul invalide le run. (L'item `0/m_palette_bank` de la machine ne permet pas
-- d'écrire les deux banques : mesuré le 2026-10-21, sur aof et kof98 ce nom désigne un octet qui
-- vaut 6 ou 0, pas la banque.)
--
-- SÉQUENCE, à partir de la trame P_DEBUT (défaut 1200, le jeu est en attract). Chaque état est
-- tenu TENIR = 3 trames et capturé à la fin de la troisième. Mesuré sur mslug le 2026-10-21 : une
-- capture faite à la fin de la trame qui suit la pose montre encore l'état d'avant (l'image que
-- rend `pixels()` retarde d'une trame) ; tenir trois trames laisse une trame de marge.
--   DEBUT          : relevé de la source du plan fixe telle que le jeu l'a laissée (1 attendu)
--   puis 5 états   : S ROM, plans 0-3 puis témoin       → P_OUT/cart-{p0,p1,p2,p3,t}.bin
--   puis 5 états   : SFIX, mêmes cinq captures          → P_OUT/sfix-{p0,p1,p2,p3,t}.bin
-- Chaque .bin est l'écran brut de MAME (32 bits par pixel, 320×224). P_OUT/releve.txt porte
-- la source du plan fixe relevée à P_DEBUT, et le compte des bascules de banque de palettes.
--
--   P_OUT    dossier de sortie (obligatoire)
--   P_DEBUT  trame de départ (défaut 1200)
--   P_OCTETS une liste d'octets en hexadécimal (« 00 16 80 A7 … »). Donnée, elle REMPLACE la mire des
--            41 glyphes : chaque octet b est posé en 8×16 à $300 + b (haut), $400 + b (bas), 21 par
--            rangée, colonnes 4 à 24, lignes 8-9, 12-13, 16-17… La banque de la police japonaise de
--            la carte (measured/2026-10-27-intitules-japon.tsv). Absente : la mire d'origine.
--   P_BANQUE avec P_OCTETS : la banque du haut, 3 par défaut (1 : $100 + b en haut, $200 + b en bas,
--            la police ASCII — le témoin de l'équivalence des deux banques)
--
-- Aucune entrée n'est pressée. NVRAM neuve : c'est au lanceur de la donner.
--   SDL_VIDEODRIVER=dummy SDL_MAC_BACKGROUND_APP=1 P_OUT=<dossier> mame <jeu> -bios euro \
--     -video none -sound none -nothrottle -nvram_directory <neuve> -autoboot_script bench/police-cartouche.lua
if _G.POLICE then return end -- le script est relu à chaque reset : ne s'installer qu'une fois
_G.POLICE = {}
local OUT = os.getenv("P_OUT")
if not OUT then print("POLICE: P_OUT manquant") manager.machine:exit() return end
local DEBUT = tonumber(os.getenv("P_DEBUT") or "1200")
local m = manager.machine
local p = m.devices[":maincpu"].spaces["program"]
local ecran = m.screens:at(1)
local sg = m.devices[":spritegen"]
local vram = emu.item(sg.items["0/m_videoram"])
local voff = emu.item(sg.items["0/m_vram_offset"])
local source = emu.item(sg.items["0/m_fixed_layer_source"])

local GLYPHES = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ :-/."
local PAL = 15
-- Couleurs Neo Geo : bit 15 « dark », bits 14-12 les bits bas de R, G, B, puis R, G, B sur 4 bits.
local MAGENTA, CYAN, JAUNE = 0x5F0F, 0x30FF, 0x6FF0

-- La mire : adresse VRAM du plan fixe ($7000 + colonne × 32 + ligne) → entrée (palette, tuile).
local mire = {}
local OCTETS = os.getenv("P_OCTETS")
if OCTETS then
  local BQ = tonumber(os.getenv("P_BANQUE") or "3") << 8
  local i = 0
  for h in OCTETS:gmatch("%x+") do
    local c = tonumber(h, 16)
    local col, k = 4 + i % 21, i // 21
    local l16 = 8 + 4 * k
    mire[0x7000 + col * 32 + l16] = (PAL << 12) | (BQ + c)
    mire[0x7000 + col * 32 + l16 + 1] = (PAL << 12) | (BQ + 0x100 + c)
    i = i + 1
  end
else
  for i = 1, #GLYPHES do
    local c = GLYPHES:byte(i)
    local col, k = 4 + (i - 1) % 21, (i - 1) // 21
    local l8, l16 = 6 + 2 * k, 12 + 4 * k
    mire[0x7000 + col * 32 + l8] = (PAL << 12) | c
    mire[0x7000 + col * 32 + l16] = (PAL << 12) | (0x100 + c)
    mire[0x7000 + col * 32 + l16 + 1] = (PAL << 12) | (0x200 + c)
  end
end

-- L'état de la palette 15 voulu pour le prochain rendu : nil tant que la séquence n'a pas commencé.
local couleurs = nil
local function couleurs_plan(b)
  local t = { [0] = 0 }
  for i = 1, 15 do t[i] = ((i >> b) & 1) == 1 and MAGENTA or CYAN end
  return t
end
local function couleurs_temoin()
  local t = { [0] = 0 }
  for i = 1, 15 do t[i] = JAUNE end
  return t
end

local actif = false -- les taps ne remplacent qu'une fois la séquence lancée
_G.POLICE.tvram = p:install_write_tap(0x3C0002, 0x3C0003, "mire", function(o, d, mk)
  if not actif then return end
  local v = mire[voff:read(0)]
  if v then return v end
end)
_G.POLICE.tpal = p:install_write_tap(0x400000 + PAL * 32, 0x400000 + PAL * 32 + 31, "pal", function(o, d, mk)
  if not actif or not couleurs then return end
  return couleurs[(o & 31) >> 1]
end)

-- Bien des jeux réécrivent la même banque à chaque trame : seul un CHANGEMENT de banque compte.
local bascules, derniere = 0, nil
_G.POLICE.tbanque = p:install_write_tap(0x3A000E, 0x3A001F, "banque", function(o, d, mk)
  if (o ~= 0x3A000E and o ~= 0x3A001E) or (mk & 0x00FF) == 0 then return end
  if actif and derniere and derniere ~= o then bascules = bascules + 1 end
  derniere = o
end)

local function poser()
  for a, v in pairs(mire) do vram:write(a, v) end
  for i = 0, 15 do p:write_u16(0x400000 + PAL * 32 + 2 * i, couleurs[i]) end
end

-- Les dix captures : (source du plan fixe, couleurs, nom du fichier).
local etapes = {}
for _, s in ipairs({ { 1, "cart" }, { 0, "sfix" } }) do
  for b = 0, 3 do etapes[#etapes + 1] = { s[1], couleurs_plan(b), s[2] .. "-p" .. b } end
  etapes[#etapes + 1] = { s[1], couleurs_temoin(), s[2] .. "-t" }
end

local out = io.open(OUT .. "/releve.txt", "w")
local function W(fmt, ...) out:write(string.format(fmt, ...) .. "\n") out:flush() end
local TENIR = 3
local n, e = 0, 0
emu.register_frame_done(function()
  n = n + 1
  if n < DEBUT then return end
  if n == DEBUT then
    W("f%d source_plan_fixe=%d (1 = S ROM, REG_CRTFIX)", n, source:read(0))
    actif = true
  elseif (n - DEBUT) % TENIR ~= 0 then
    poser() -- l'état tient : réécrit à chaque trame, contre les écritures du jeu
    return
  else
    local f = io.open(string.format("%s/%s.bin", OUT, etapes[e][3]), "wb")
    f:write((ecran:pixels())) f:close()
  end
  e = e + 1
  if e > #etapes then
    W("f%d fin bascules_banque_palettes=%d", n, bascules)
    out:close() m:exit() return
  end
  source:write(0, etapes[e][1])
  couleurs = etapes[e][2]
  poser()
end)
