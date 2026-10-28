-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- Jig de diagnostic du son et du plan fixe autour d'un menu en jeu, et observateur du parcours
-- (`bench/parcours.sh`). Sans fenêtre.
-- Ce jig ne trace aucun code : il compte des écritures (valeur, trame) et classe chacune « B » (BIOS,
-- PC dans $C00000-$C1FFFF) ou « J » (jeu) ; il ne consigne pas le PC.
--   J_OUT       dossier (obligatoire) ; relevé J_OUT/son.txt
--   J_PIECE, J_START   trames (8 trames tenues) ; défauts 400, 500 ; 0 : jamais
--   J_GESTE, J_TENIR   TEST tenu (si J_TEST=1)
--   J_TESTS     « a-b » séparés par des virgules : TEST tenu de la trame a à la trame b, en plus
--   J_APPUIS    « trame:bouton[:durée] » (piece, START, haut, bas, gauche, droite, A, B, C, D,
--               piece2, start2, deuxA, service, select, select2, et pour P2 deuxB, deuxC,
--               deuxD, deuxHaut, deuxBas, deuxGauche, deuxDroite, et le panneau de mahjong mjA…mjReach,
--               mjStart : voir plus bas)
--   J_DSW       « trame:bits » (hex) séparés par des virgules : à partir de cette trame, les
--               commutateurs de la carte dont le bit est à 1 dans « bits » sont mis à ON (le bit
--               de REG_DIPSW à 0, actif bas), les autres à OFF ; par les champs de :DSW de MAME
--   « f<n> SLOT <v> » : chaque écriture de REG_SLOT (voir plus bas)
--   J_TIRS      « de-à:pas:bouton » : appuis de 3 trames
--   J_IMAGES    trames d'image bgra 320×224, « a-b » pour un intervalle
--   J_HACHES    « de-à » : à chaque trame de l'intervalle, « img= » l'empreinte de l'image
--               ENTIÈRE (chaque pixel y entre : `docs/BENCH.md`, piège 4)
--   J_ZONES     « x0,y0,x1,y1 » séparés par des « ; » (pixels, bornes comprises) : dans l'intervalle
--               de J_HACHES, « zK= » l'empreinte de chaque rectangle, K à partir de 1 — ce
--               qu'affiche une zone de l'écran (un chronomètre, une barre de vie)
--   J_SUIVRE    « adr:taille » (hex, taille 1 ou 2), virgules : la valeur à chaque trame, « m »
--               suivi de l'adresse — une valeur du jeu en RAM, en complément de l'écran
--   J_REMISE    « k » séparés par des virgules : l'image k trames après la dernière remise de
--               la main au jeu — une nouvelle valeur du couple mode/demande ($10FDAF/$10FDAE)
--               avec le mode 01 : le premier boot, la relance d'un changement de région, le
--               titre après une pièce —, en J_OUT/rKKKKK.bin. Un instant du JEU, quel que soit
--               le temps que le BIOS a pris avant ; une remise plus tardive la réécrit
--   J_TEXTE     trames où écrire le plan fixe décodé (lignes 2 à 29, « fixNN |…| »),
--               reconstruit depuis les écritures au LSPC comme `autotests.lua`
--   J_TUILES    trames où écrire le plan fixe BRUT, même reconstruction : « fNN tuNN » puis les 40
--               entrées de la ligne en hexadécimal (palette sur 4 bits, tuile sur 12), lignes 2 à
--               29 — les tuiles hors de la police ASCII, que J_TEXTE rend en espaces
--   J_INJ       « trame:code » : un code écrit par lua à REG_SOUND
--   J_POSER     « trame@adr=octets » (hex), virgules : ces octets écrits par lua dans la RAM du
--               jeu en fin de trame — un score de joueur simulé, comme MS_POSER de `multislot.lua`
--   J_BRAM      « trame@adr=octets » (hex), virgules : ces octets écrits dans la backup RAM ($D0xxxx) en
--               fin de trame, par la mémoire partagée « :saveram » de MAME, que REG_SRAMLOCK ne
--               protège pas — un réglage de la borne posé comme l'aurait laissé un autre BIOS
--   J_FIN       sortie
--   J_FLOTTANT  chemin de `bus-flottant.lua`, chargé avec ce jig : la cartouche servie comme le
--               matériel, seulement sous REG_CRTFIX (son en-tête) ; BF_OUT, BF_FIN (avant J_FIN)
--               et BF_HOTE=1 sont à poser aussi, BF_LIBRE=1 pour le témoin sans le modèle
-- Chaque ligne de trame porte aussi « t= » (le temps de la machine en secondes, pour caler le
-- WAV de `-wavwrite` sur les trames) et « cote= » : B si la trame finit avec le PC dans le BIOS,
-- J sinon. Une suite de trames « cote=B » est une pause du jeu (menu en jeu, écran TEST).
-- « fixB=c0-c1,r0-r1 » : le rectangle (colonnes, lignes) des cases du plan fixe que le BIOS a
-- écrites dans la trame, quand il en a écrit — le cadre du menu en jeu, par exemple.
if _G.SONJIG then return end
_G.SONJIG = {}
if os.getenv("J_FLOTTANT") then dofile(os.getenv("J_FLOTTANT")) end
-- J_AUSSI : un autre jig chargé avec celui-ci (`scores.lua`, `carte-protegee.lua`), qui ne joue aucune entrée.
if os.getenv("J_AUSSI") then for x in os.getenv("J_AUSSI"):gmatch("[^;]+") do dofile(x) end end
local OUT = os.getenv("J_OUT")
local function N(v, d) return tonumber(os.getenv(v) or d) end
local PIECE, START, GESTE, TENIR = N("J_PIECE", "400"), N("J_START", "500"), N("J_GESTE", "1500"), N("J_TENIR", "40")
local TEST, FIN = N("J_TEST", "0"), N("J_FIN", "2400")
local H0, H1 = (os.getenv("J_HACHES") or "0-0"):match("(%d+)-(%d+)") H0, H1 = tonumber(H0), tonumber(H1)
local m = manager.machine
local cpu = m.devices[":maincpu"]
local p = cpu.spaces["program"]
local ecran = m.screens:at(1)
local function F(pt, nom) local x = m.ioport.ports[pt] return x and x.fields[nom] end
-- Sous `aes` (la console de MAME, colonne de référence du mode AES de `parcours.sh`), les
-- manettes sont sous :ctrl1 et il n'y a ni pièce ni TEST : un bouton absent n'est refusé que
-- s'il est demandé (J_APPUIS, J_PIECE, J_START).
local function J(n) return F(":edge:joy:JOY1", "P1 " .. n) or F(":ctrl1:joy:JOY", "P1 " .. n) end
-- piece2, start2 : la pièce et le START de P2 ; deuxA : le bouton A de P2 ; service : le bouton
-- SERVICE ; select, select2 : SELECT P1 et P2 — « Next Game »
-- et « Previous Game » de la MV-6F (`neogeo`), « P1/P2 Select » de la console ; un set à une
-- cartouche n'en a pas (`src/c0/menu.s`, LE GESTE).
local champs = {
  piece = F(":AUDIO_COIN", "Coin 1"), piece2 = F(":AUDIO_COIN", "Coin 2"),
  START = F(":edge:joy:START", "1 Player Start") or F(":ctrl1:joy:START_SELECT", "P1 Start"),
  start2 = F(":edge:joy:START", "2 Players Start") or F(":ctrl2:joy:START_SELECT", "P2 Start"),
  select = F(":SYSTEM", "Next Game") or F(":ctrl1:joy:START_SELECT", "P1 Select"),
  select2 = F(":SYSTEM", "Previous Game") or F(":ctrl2:joy:START_SELECT", "P2 Select"),
  haut = J("Up"), bas = J("Down"), gauche = J("Left"), droite = J("Right"),
  A = J("A"), B = J("B"), C = J("C"), D = J("D"),
  deuxA = F(":edge:joy:JOY2", "P2 A") or F(":ctrl2:joy:JOY", "P2 A"), service = F(":AUDIO_COIN", "Service 1"),
  deuxB = F(":edge:joy:JOY2", "P2 B"), deuxC = F(":edge:joy:JOY2", "P2 C"), deuxD = F(":edge:joy:JOY2", "P2 D"),
  deuxHaut = F(":edge:joy:JOY2", "P2 Up"), deuxBas = F(":edge:joy:JOY2", "P2 Down"),
  deuxGauche = F(":edge:joy:JOY2", "P2 Left"), deuxDroite = F(":edge:joy:JOY2", "P2 Right"),
  mjStart = F(":ctrl1:mahjong:START_SELECT", "P1 Start"),
}
-- Le panneau de mahjong de P1 (machine `janshin` de MAME, neogeo_mj ; mahjong.cpp : trois rangées MJ.0 A-G,
-- MJ.1 H-N, MJ.2 PON, CHI, KAN, RON, REACH) : « mjA » à « mjN », « mjPon », « mjChi », « mjKan », « mjRon »,
-- « mjReach », et « mjStart » ; absents des autres machines.
for i, k in ipairs({ "A", "B", "C", "D", "E", "F", "G" }) do champs["mj" .. k] = F(":ctrl1:mahjong:MJ.0", "P1 Mahjong " .. k) end
for i, k in ipairs({ "H", "I", "J", "K", "L", "M", "N" }) do champs["mj" .. k] = F(":ctrl1:mahjong:MJ.1", "P1 Mahjong " .. k) end
for i, k in ipairs({ "Pon", "Chi", "Kan", "Ron", "Reach" }) do champs["mj" .. k] = F(":ctrl1:mahjong:MJ.2", "P1 Mahjong " .. k) end
-- Les commutateurs de la carte : les champs de :DSW, chacun posé par sa valeur de configuration
-- (`user_value`, bits du masque du champ) ; mesuré le 2026-10-23 sous MAME 0.286 (aof) : chaque
-- champ posé seul abaisse son bit de REG_DIPSW ($300001) et lui seul.
local dsw = {}
for t, v in (os.getenv("J_DSW") or ""):gmatch("(%d+):(%x+)") do dsw[#dsw + 1] = { tonumber(t), tonumber(v, 16) } end
local dsw_champs = {}
if #dsw > 0 then
  local pt = m.ioport.ports[":DSW"]
  assert(pt, "port :DSW introuvable")
  for _, f in pairs(pt.fields) do dsw_champs[#dsw_champs + 1] = f end
end
-- Rien n'est posé avant la première trame de J_DSW : les champs gardent la valeur que MAME charge, celle
-- du cfg du jeu s'il en a un, sinon tous OFF. MAME y enregistre les commutateurs posés à la sortie : un
-- cfg partagé entre runs les transmet (`measured/2026-10-25-free-play.tsv`, section 0). « 1:00 » met
-- tout à OFF quel que soit le cfg.
local dsw_pose = -1
assert(PIECE == 0 or champs.piece, "champ introuvable : piece")
assert(START == 0 or champs.START, "champ introuvable : START")
local test = F(":TEST", "Service Mode")
local appuis = {}
for t, b, d in (os.getenv("J_APPUIS") or ""):gmatch("(%d+):(%a+%d?):?(%d*)") do
  assert(champs[b], "bouton inconnu ou absent : " .. b)
  appuis[#appuis + 1] = { tonumber(t), b, tonumber(d) or 3 } end
for a, z, s, b in (os.getenv("J_TIRS") or ""):gmatch("(%d+)-(%d+):(%d+):(%a+)") do
  for t = tonumber(a), tonumber(z), tonumber(s) do appuis[#appuis + 1] = { t, b, 3 } end end
local tests = {}
for a, z in (os.getenv("J_TESTS") or ""):gmatch("(%d+)-(%d+)") do tests[#tests + 1] = { tonumber(a), tonumber(z) } end
local zones = {}
for a, b, c, d in (os.getenv("J_ZONES") or ""):gmatch("(%d+),(%d+),(%d+),(%d+)") do
  zones[#zones + 1] = { tonumber(a), tonumber(b), tonumber(c), tonumber(d) } end
local suivre = {}
for a, t in (os.getenv("J_SUIVRE") or ""):gmatch("(%x+):(%d)") do suivre[#suivre + 1] = { tonumber(a, 16), tonumber(t) } end
local dumps = {}
for x in (os.getenv("J_DUMPS") or ""):gmatch("%d+") do dumps[tonumber(x)] = true end
local images = {}
for x in (os.getenv("J_IMAGES") or ""):gmatch("[%d-]+") do
  local a, z = x:match("^(%d+)-(%d+)$")
  if a then for k = tonumber(a), tonumber(z) do images[k] = true end
  elseif tonumber(x) then images[tonumber(x)] = true end
end
local remises = {}
for k in (os.getenv("J_REMISE") or ""):gmatch("%d+") do remises[tonumber(k)] = true end
local remise = nil
local poses = {}
for t, a, v in (os.getenv("J_POSER") or ""):gmatch("(%d+)@(%x+)=(%x+)") do poses[#poses + 1] = { tonumber(t), tonumber(a, 16), v } end
local bram = {}
for t, a, v in (os.getenv("J_BRAM") or ""):gmatch("(%d+)@(%x+)=(%x+)") do bram[#bram + 1] = { tonumber(t), tonumber(a, 16) - 0xD00000, v } end
local textes = {}
for n in (os.getenv("J_TEXTE") or ""):gmatch("%d+") do textes[tonumber(n)] = true end
local tuiles = {}
for n in (os.getenv("J_TUILES") or ""):gmatch("%d+") do tuiles[tonumber(n)] = true end
local out = io.open(OUT .. "/son.txt", "w")
local function W(fmt, ...) out:write(string.format(fmt, ...) .. "\n") out:flush() end
local function src() local pc = cpu.state["PC"].value return (pc >= 0xC00000 and pc < 0xC20000) and "B" or "J" end

local n = 0
local son, bascules = {}, {}
local pal = { B = 0, J = 0 }
local fixw = { B = 0, J = 0 }
-- YM2610 : ports 4/5 (A), 6/7 (B). Compteurs par trame.
local ym = { w = 0, fm = 0, adpcma = 0, adpcmb = 0, ssg = 0 }
local adrA, adrB = 0, 0
_G.SONJIG.tson = p:install_write_tap(0x320000, 0x320001, "son", function(o, d, mk)
  if (mk & 0xFF00) ~= 0 then son[#son + 1] = string.format("%s%02X", src(), (d >> 8) & 0xFF) end end)
_G.SONJIG.tbas = p:install_write_tap(0x3A0000, 0x3A001F, "bas", function(o, d, mk)
  local a = o | (((mk & 0xFF) ~= 0) and 1 or 0)
  if a == 0x3A000B or a == 0x3A001B or a == 0x3A0003 or a == 0x3A0013 or a == 0x3A000F or a == 0x3A001F then
    bascules[#bascules + 1] = string.format("%s%06X", src(), a) end end)
-- REG_SLOT ($380021, « Memory mapped registers ») : « f<n> SLOT <v> » à chaque écriture — le slot
-- servi d'une MV-6F, que le couple mode/demande ne dit pas (un SELECT en démo garde 01/02).
_G.SONJIG.tslot = p:install_write_tap(0x380020, 0x380021, "slot", function(o, d, mk)
  if (mk & 0xFF) ~= 0 then W("f%d SLOT %02X", n, d & 0xFF) end end)
_G.SONJIG.tpal = p:install_write_tap(0x400000, 0x401FFF, "pal", function() local s = src() pal[s] = pal[s] + 1 end)
-- Le plan fixe reconstruit (REG_VRAMADDR / REG_VRAMRW / REG_VRAMMOD), et les écritures comptées.
local X = { a = 0, mod = 1, v = {} }
local fixB = nil -- le rectangle des cases du plan fixe écrites par le BIOS dans la trame
_G.SONJIG.tvr = p:install_write_tap(0x3C0000, 0x3C0005, "vr", function(o, d)
  local r = o & 6
  if r == 0 then X.a = d elseif r == 4 then X.mod = d
  elseif r == 2 then
    local s = src() fixw[s] = fixw[s] + 1
    if s == "B" and X.a >= 0x7000 and X.a < 0x7500 then
      local col, row = (X.a - 0x7000) // 32, (X.a - 0x7000) % 32
      local b = fixB or { col, col, row, row }
      fixB = { math.min(b[1], col), math.max(b[2], col), math.min(b[3], row), math.max(b[4], row) }
    end
    X.v[X.a] = d X.a = (X.a + X.mod) & 0xFFFF
  end end)
local function ligne(row)
  local l = {}
  for col = 0, 39 do
    local t = (X.v[0x7000 + col * 32 + row] or 0) & 0xFFF
    local c = t & 0xFF
    l[#l + 1] = ((t >> 8) <= 1 and c >= 0x20 and c < 0x7F) and string.char(c) or " "
  end
  return table.concat(l)
end
local zio = m.devices[":audiocpu"].spaces["io"]
_G.SONJIG.tym = zio:install_write_tap(0x0000, 0xFFFF, "ym", function(o, d)
  local b = o & 0xFF
  if b < 4 or b > 7 then return end
  ym.w = ym.w + 1
  if b == 4 then adrA = d & 0xFF
  elseif b == 6 then adrB = d & 0xFF
  elseif b == 5 then
    if adrA == 0x28 and (d & 0xF0) ~= 0 then ym.fm = ym.fm + 1
    elseif adrA == 0x10 and (d & 0x80) ~= 0 then ym.adpcmb = ym.adpcmb + 1
    elseif adrA < 0x0E then ym.ssg = ym.ssg + 1 end
  elseif b == 7 then
    if adrB == 0x00 and (d & 0x80) == 0 and (d & 0x3F) ~= 0 then ym.adpcma = ym.adpcma + 1 end
  end end)
local banques = {}
_G.SONJIG.tbk = zio:install_read_tap(0x0000, 0xFFFF, "bk", function(o, d)
  local b = o & 0xFF
  if b >= 8 and b <= 11 then banques[#banques + 1] = string.format("%d:%02X", b - 8, (o >> 8) & 0xFF) end
  return d end)
local reponse = -1
-- Après un reset, la prochaine remise compte même si le couple n'a pas changé entre-temps.
_G.SONJIG.reset = emu.add_machine_reset_notifier(function() W("f%d RESET", n) _G.SONJIG.user = "reset" end)

-- L'empreinte de l'image entière, 16 pixels par pas : chaque pixel y entre, avec son poids.
local up = string.unpack
local function hache(px)
  local h = 5381
  for i = 1, #px - 63, 64 do
    local a, b, c, d, e, f, g, hh, i2, j, k, l, mm, nn, o, q = up("<I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4", px, i)
    h = (h * 31 + a + b * 3 + c * 5 + d * 7 + e * 11 + f * 13 + g * 17 + hh * 19 + i2 * 23 + j * 29
      + k * 31 + l * 37 + mm * 41 + nn * 43 + o * 47 + q * 53) % 4294967291
  end
  return h
end

-- Celle d'un rectangle : chaque pixel du rectangle, ligne par ligne (320 pixels de 4 octets).
local function hache_zone(px, z)
  local h = 5381
  for y = z[2], z[4] do
    local i = (y * 320 + z[1]) * 4 + 1
    for _ = z[1], z[3] do h = (h * 33 + up("<I4", px, i)) % 4294967291 i = i + 4 end
  end
  return h
end

emu.register_frame_done(function()
  n = n + 1
  local tenus = {}
  if PIECE > 0 and n >= PIECE and n < PIECE + 8 then tenus.piece = true end
  if START > 0 and n >= START and n < START + 8 then tenus.START = true end
  local t_test = TEST == 1 and n >= GESTE and n < GESTE + TENIR
  for _, w in ipairs(tests) do if n >= w[1] and n <= w[2] then t_test = true end end
  if test then test:set_value(t_test and 1 or 0) end
  for _, a in ipairs(appuis) do if n >= a[1] and n < a[1] + a[3] then tenus[a[2]] = true end end
  for k, c in pairs(champs) do c:set_value(tenus[k] and 1 or 0) end
  local on = nil
  for _, d in ipairs(dsw) do if n >= d[1] then on = d[2] end end
  if on and on ~= dsw_pose then
    dsw_pose = on
    for _, f in ipairs(dsw_champs) do f.user_value = (~on) & f.mask end
    W("f%d DSW %02X", n, on)
  end
  local u = string.format("%02X/%02X", p:read_u8(0x10FDAF), p:read_u8(0x10FDAE))
  if u ~= _G.SONJIG.user then
    if u:sub(1, 2) == "01" then remise = n W("f%d REMISE", n) end
    _G.SONJIG.user = u W("f%d user=%s", n, u)
  end
  if remise and remises[n - remise] then
    local f = io.open(string.format("%s/r%05d.bin", OUT, n - remise), "wb") f:write((ecran:pixels())) f:close()
    W("f%d IMAGE r%05d", n, n - remise)
  end
  local extra = {}
  if n >= H0 and n <= H1 then
    local px = ecran:pixels()
    extra[#extra + 1] = "img=" .. hache(px)
    for k, z in ipairs(zones) do extra[#extra + 1] = string.format("z%d=%d", k, hache_zone(px, z)) end
  end
  for _, s in ipairs(suivre) do
    extra[#extra + 1] = string.format("m%06X=%X", s[1], s[2] == 1 and p:read_u8(s[1]) or p:read_u16(s[1])) end
  if fixB then extra[#extra + 1] = string.format("fixB=%d-%d,%d-%d", fixB[1], fixB[2], fixB[3], fixB[4]) fixB = nil end
  W("f%d son=%s bas=%s ym=%d fm=%d aa=%d ab=%d ssg=%d palB=%d palJ=%d vrB=%d vrJ=%d t=%.5f cote=%s%s", n,
    table.concat(son, ","), table.concat(bascules, ","), ym.w, ym.fm, ym.adpcma, ym.adpcmb, ym.ssg,
    pal.B, pal.J, fixw.B, fixw.J, m.time:as_double(), src(), #extra > 0 and (" " .. table.concat(extra, " ")) or "")
  if #banques > 0 then W("f%d BANQUES %s", n, table.concat(banques, ",")) banques = {} end
  local r = p:read_u8(0x320000)
  if r ~= reponse then reponse = r W("f%d REPONSE %02X", n, r) end
  son, bascules = {}, {}
  for t, v in (os.getenv("J_INJ") or ""):gmatch("(%d+):(%x+)") do
    if tonumber(t) == n then _G.SONJIG.inj = true p:write_u8(0x320000, tonumber(v, 16)) _G.SONJIG.inj = false
      W("f%d INJ %s", n, v) end end
  for _, x in ipairs(poses) do
    if x[1] == n then
      for i = 0, #x[3] // 2 - 1 do p:write_u8(x[2] + i, tonumber(x[3]:sub(2 * i + 1, 2 * i + 2), 16)) end
      W("f%d POSE %06X=%s", n, x[2], x[3])
    end
  end
  for _, x in ipairs(bram) do
    if x[1] == n then
      local sh = m.memory.shares[":saveram"]
      for i = 0, #x[3] // 2 - 1 do sh:write_u8(x[2] + i, tonumber(x[3]:sub(2 * i + 1, 2 * i + 2), 16)) end
      W("f%d BRAM %06X=%s", n, x[2] + 0xD00000, x[3])
    end
  end
  son = {}
  ym = { w = 0, fm = 0, adpcma = 0, adpcmb = 0, ssg = 0 }
  pal = { B = 0, J = 0 } fixw = { B = 0, J = 0 }
  if textes[n] then for row = 2, 29 do W("f%d fix%02d |%s|", n, row, ligne(row)) end end
  if tuiles[n] then
    for row = 2, 29 do
      local l = {}
      for col = 0, 39 do l[#l + 1] = string.format("%04X", X.v[0x7000 + col * 32 + row] or 0) end
      W("f%d tu%02d %s", n, row, table.concat(l, " "))
    end
  end
  if dumps[n] then
    local sg = m.devices[":spritegen"] local vr = emu.item(sg.items["0/m_videoram"])
    local t = {} for i = 0, vr.count - 1 do t[#t + 1] = string.pack(">I2", vr:read(i)) end
    local f = io.open(string.format("%s/d%05d-vram.bin", OUT, n), "wb") f:write(table.concat(t)) f:close()
    t = {} for a = 0x400000, 0x401FFF, 2 do t[#t + 1] = string.pack(">I2", p:read_u16(a)) end
    f = io.open(string.format("%s/d%05d-pal.bin", OUT, n), "wb") f:write(table.concat(t)) f:close()
  end
  if images[n] then
    local f = io.open(string.format("%s/f%05d.bin", OUT, n), "wb") f:write((ecran:pixels())) f:close()
  end
  if n >= FIN then out:close() m:exit() end
end)
