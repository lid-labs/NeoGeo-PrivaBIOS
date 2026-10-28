-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- Jig des autotests (`src/c0/tests.s`), sans fenêtre. TEST tenu au boot ouvre l'écran TEST
-- (`dip.s`) ; le jig monte à la ligne HARDWARE TESTS, lance chaque test l'un après l'autre,
-- relève ce que l'écran affiche, sort, et laisse le jeu démarrer.
--
--   T_OUT     dossier de sortie (obligatoire) ; le relevé va dans T_OUT/autotests.txt, les
--             images (bgra 320×224) dans T_OUT/fNNNNN.bin
--   T_DEFAUT  aucun (machine saine, défaut) | work | pal | vram | bram : un défaut injecté
--             pendant le test du même nom, à l'adresse T_ADR, sur le bit T_BIT (défaut 0)
--   T_ADR     work et pal : adresse 68000 dont la LECTURE rend le bit T_BIT inversé (tap de
--             lecture, posé juste avant le lancement du test) ; vram : adresse VRAM (mot)
--             dont la lecture par REG_VRAMRW rend le bit inversé — l'adresse courante est
--             suivie par un tap d'écriture sur REG_VRAMADDR/REG_VRAMRW/REG_VRAMMOD ; bram :
--             adresse dont la PREMIÈRE écriture après le lancement reçoit le bit inversé
--             (tap d'écriture à un coup : le complément du test est faussé, l'original
--             remis ensuite est intact, ce qui laisse la backup RAM vérifiable à l'octet)
--   T_BANQUE  pal seulement : 0 ou 1, le défaut ne vaut que dans cette banque de palettes,
--             suivie par un tap d'écriture sur REG_PALBANK0/1 ($3A000F/$3A001F) ; absent :
--             les deux banques
--   T_DEFAUT=alias : une ligne d'adresse court-circuitée, simulée : toute lecture de
--             [T_ADR, T_ADR + $2000) rend le mot situé $2000 plus haut (tap de lecture) ;
--             les motifs de données passent, seul le motif d'adresse doit échouer
--   T_FIN     trame de sortie (défaut 3000)
--
-- Le plan fixe est reconstruit depuis les écritures au LSPC (comme `fixmap.lua` : MAME
-- n'expose pas la VRAM au Lua), puis décodé en texte : c'est lui qui donne les verdicts.
-- La backup RAM ($D00000-$D0FFFF) est relue octet par octet avant et après son test, et les
-- deux empreintes comparées. Toutes les références de tap sont gardées dans _G.AUTOTESTS.
if _G.AUTOTESTS then return end
_G.AUTOTESTS = {}
local G = _G.AUTOTESTS
local OUT = os.getenv("T_OUT")
if not OUT then print("AUTOTESTS: T_OUT manquant") manager.machine:exit() return end
local DEFAUT = os.getenv("T_DEFAUT") or "aucun"
local ADR = tonumber(os.getenv("T_ADR") or "0")
local BIT = tonumber(os.getenv("T_BIT") or "0")
local FIN = tonumber(os.getenv("T_FIN") or "3000")
local m = manager.machine
local p = m.devices[":maincpu"].spaces["program"]
local ecran = m.screens:at(1)
local function F(pt, n) local x = m.ioport.ports[pt] assert(x, pt) local f = x.fields[n] assert(f, n) return f end
local B = {
  haut = F(":edge:joy:JOY1", "P1 Up"), bas = F(":edge:joy:JOY1", "P1 Down"),
  droite = F(":edge:joy:JOY1", "P1 Right"),
  A = F(":edge:joy:JOY1", "P1 A"), B1 = F(":edge:joy:JOY1", "P1 B"),
  START = F(":edge:joy:START", "1 Player Start"), START2 = F(":edge:joy:START", "2 Players Start"),
  D2 = F(":edge:joy:JOY2", "P2 D"), droite2 = F(":edge:joy:JOY2", "P2 Right"),
  piece1 = F(":AUDIO_COIN", "Coin 1"), service = F(":AUDIO_COIN", "Service 1"),
  TEST = F(":TEST", "Service Mode"),
}
local tenus = {}
local out = io.open(OUT .. "/autotests.txt", "w")
local function W(fmt, ...) out:write(string.format(fmt, ...) .. "\n") out:flush() end

-- Le plan fixe, et l'adresse VRAM courante pour le défaut vram.
local X = { a = 0, mod = 1, v = {} }
G.lspc = p:install_write_tap(0x3C0000, 0x3C0005, "lspc", function(o, d)
  local r = o & 6
  if r == 0 then X.a = d elseif r == 4 then X.mod = d
  elseif r == 2 then X.v[X.a] = d X.a = (X.a + X.mod) & 0xFFFF end end)

local function ligne(row)
  local l = {}
  for col = 0, 39 do
    local t = (X.v[0x7000 + col * 32 + row] or 0) & 0xFFF
    local c = t & 0xFF
    l[#l + 1] = ((t >> 8) <= 1 and c >= 0x20 and c < 0x7F) and string.char(c) or " "
  end
  return table.concat(l)
end
local function ecranTexte() local t = {} for r = 0, 31 do t[r] = ligne(r) end return table.concat(t, "\n", 0, 31) end
local function contient(s) return ecranTexte():find(s, 1, true) ~= nil end
local function palette(col, row) return ((X.v[0x7000 + col * 32 + row] or 0) >> 12) & 0xF end

local n = 0
local function image(nom)
  local f = io.open(string.format("%s/f%05d-%s.bin", OUT, n, nom), "wb") f:write(ecran:pixels()) f:close()
  W("f%d IMAGE %s", n, nom)
end
local function vifs()
  local px, v = ecran:pixels(), 0
  for i = 1, #px, 4 do if px:byte(i) + px:byte(i + 1) + px:byte(i + 2) > 24 then v = v + 1 end end
  return v
end
local function hash_bram()
  local h, t = 0, {}
  for a = 0xD00000, 0xD0FFFF do
    local b = p:read_u8(a)
    t[#t + 1] = string.char(b)
    h = (h * 31 + b) & 0xFFFFFFFF
  end
  return h, table.concat(t)
end

-- Le scénario, une coroutine reprise à chaque trame.
local function attendre(k) for _ = 1, k do coroutine.yield() end end
local function appuyer(b, k) tenus[b] = true attendre(k or 3) tenus[b] = nil attendre(4) end
local function jusqua(pred, maxi, quoi)
  for i = 1, maxi do if pred() then return true end coroutine.yield() end
  W("f%d DELAI %s", n, quoi) return false
end
local LIGNES = { 7, 9, 11, 13 }
local NOMS = { "WORK", "PALETTE", "VRAM", "BACKUP" }
local CLEF = { work = 1, alias = 1, pal = 2, vram = 3, bram = 4 }
local BANQUE = tonumber(os.getenv("T_BANQUE") or "-1")
G.banque = 0
G.pb = p:install_write_tap(0x3A000E, 0x3A001F, "palbank", function(o)
  if o == 0x3A000F or o == 0x3A000E then G.banque = 0 elseif o == 0x3A001F or o == 0x3A001E then G.banque = 1 end end)

local function poser_defaut(k)
  if CLEF[DEFAUT] ~= k then return end
  local masque = 1 << BIT
  if DEFAUT == "work" or DEFAUT == "pal" then
    G.defaut = p:install_read_tap(ADR, ADR + 1, "defaut", function(o, d, mk)
      if o == ADR and (BANQUE < 0 or BANQUE == G.banque) then return d ~ masque end end)
  elseif DEFAUT == "alias" then
    G.defaut = p:install_read_tap(ADR, ADR + 0x1FFF, "defaut", function(o, d, mk)
      return p:read_u16((o & ~1) + 0x2000) end)
  elseif DEFAUT == "vram" then
    G.defaut = p:install_read_tap(0x3C0002, 0x3C0003, "defaut", function(o, d, mk)
      if X.a == ADR then return d ~ masque end end)
  elseif DEFAUT == "bram" then
    local fait = false
    G.defaut = p:install_write_tap(ADR, ADR + 1, "defaut", function(o, d, mk)
      if not fait and o == ADR then fait = true W("f%d DEFAUT bram ecriture %04X -> %04X", n, d, d ~ masque) return d ~ masque end end)
  end
  W("f%d DEFAUT %s pose adr=%06X bit=%d", n, DEFAUT, ADR, BIT)
end

local function scenario()
  jusqua(function() return contient("SOFT DIP SETTINGS") end, 600, "ecran TEST")
  attendre(10) image("ecran-test")
  -- Une valeur changée avant les tests (la 2e ligne, ligne 9 du plan fixe), qui doit survivre.
  local function octets(a, k) local t = {} for i = 0, k - 1 do t[#t + 1] = string.format("%02X", p:read_u8(a + i)) end return table.concat(t, " ") end
  W("f%d EDITION avant |%s| GAME_DIP %s", n, ligne(9), octets(0x10FD84, 16))
  appuyer(B.bas) appuyer(B.droite)
  W("f%d EDITION changee |%s| GAME_DIP %s", n, ligne(9), octets(0x10FD84, 16))
  -- Monter jusqu'à HARDWARE TESTS, quel que soit le nombre de lignes qui la suivent : trois
  -- « haut » fixes tombaient sur JUKEBOX depuis l'ajout de cette ligne (`dip.s`).
  for _ = 1, 20 do
    if contient("> HARDWARE TESTS") then break end
    appuyer(B.haut)
  end
  W("f%d ligne choisie : HARDWARE TESTS ? %s", n, tostring(contient("> HARDWARE TESTS")))
  appuyer(B.A)
  jusqua(function() return contient("HARDWARE TESTS") and contient("WORK RAM") end, 120, "menu")
  attendre(5) image("menu")
  for k = 1, 4 do
    if k > 1 then appuyer(B.bas) end
    poser_defaut(k)
    local h0, b0
    if k == 4 then h0, b0 = hash_bram() end
    local t0 = n
    appuyer(B.A)
    local row = LIGNES[k]
    jusqua(function() local l = ligne(row) return contient("HARDWARE TESTS") and (l:find(" OK ", 1, true) or l:find(" FAIL", 1, true)) end, 900, NOMS[k])
    attendre(3)
    W("f%d RESULTAT %s duree=%d |%s|", n, NOMS[k], n - t0, ligne(row))
    if G.defaut then G.defaut:remove() G.defaut = nil W("f%d DEFAUT retire", n) end
    W("f%d DETAIL   %s |%s|", n, NOMS[k], ligne(row + 1))
    image(NOMS[k])
    if k == 4 then
      local h1, b1 = hash_bram()
      local diff = 0
      for i = 1, #b0 do if b0:byte(i) ~= b1:byte(i) then diff = diff + 1 end end
      W("f%d BRAM avant=%08X apres=%08X octets_differents=%d", n, h0, h1, diff)
    end
  end
  -- INPUT TEST
  appuyer(B.bas) appuyer(B.A)
  jusqua(function() return contient("HOLD START P1") end, 60, "input test")
  attendre(5) image("input-repos")
  local function pal_txt(col, row) return palette(col, row) end
  W("f%d INPUT repos P1-UP=%d P1-B=%d P2-RIGHT=%d P2-D=%d COIN1=%d SERVICE=%d START2=%d TEST=%d",
    n, pal_txt(7, 7), pal_txt(28, 7), pal_txt(20, 9), pal_txt(32, 9), pal_txt(9, 14), pal_txt(15, 14), pal_txt(7, 12), pal_txt(3, 16))
  for _, b in ipairs({ B.haut, B.B1, B.droite2, B.D2, B.piece1, B.service, B.START2, B.TEST }) do tenus[b] = true end
  attendre(4)
  W("f%d INPUT appuye P1-UP=%d P1-B=%d P2-RIGHT=%d P2-D=%d COIN1=%d SERVICE=%d START2=%d TEST=%d",
    n, pal_txt(7, 7), pal_txt(28, 7), pal_txt(20, 9), pal_txt(32, 9), pal_txt(9, 14), pal_txt(15, 14), pal_txt(7, 12), pal_txt(3, 16))
  W("f%d INPUT temoins non appuyes P1-DOWN=%d P1-A=%d P2-UP=%d COIN2=%d START1=%d", n, pal_txt(10, 7), pal_txt(26, 7), pal_txt(7, 9), pal_txt(11, 14), pal_txt(7, 11))
  image("input-appuye")
  for b in pairs(tenus) do tenus[b] = nil end
  attendre(5)
  -- START tenu 30 trames : ne sort pas ; puis tenu 70 : sort.
  tenus[B.START] = true attendre(30) tenus[B.START] = nil attendre(3)
  W("f%d INPUT apres START 30 trames : toujours la ? %s", n, tostring(contient("HOLD START P1")))
  tenus[B.START] = true
  jusqua(function() return contient("WORK RAM") end, 120, "sortie input")
  W("f%d INPUT sortie apres START tenu", n)
  attendre(5) tenus[B.START] = nil attendre(5)
  W("f%d menu revenu ? %s", n, tostring(contient("HARDWARE TESTS") and contient("CROSSHATCH")))
  -- COLOR BARS
  appuyer(B.bas) appuyer(B.A)
  jusqua(function() return contient("COLOR BARS") and contient("A:WHITE") end, 60, "barres")
  attendre(5) image("barres-rvb")
  appuyer(B.A)
  jusqua(function() return contient("A:RGB") end, 60, "barres blanc")
  attendre(5) image("barres-blanc")
  appuyer(B.START)
  jusqua(function() return contient("CROSSHATCH") end, 60, "retour barres")
  -- CROSSHATCH
  appuyer(B.bas) appuyer(B.A)
  attendre(10) image("quadrillage")
  appuyer(B.START)
  jusqua(function() return contient("CROSSHATCH") end, 60, "retour quadrillage")
  attendre(5) image("menu-fin")
  -- Retour à l'écran TEST, puis le jeu.
  appuyer(B.START)
  jusqua(function() return contient("SOFT DIP SETTINGS") end, 60, "retour TEST")
  attendre(5) image("ecran-test-retour")
  W("f%d ecran TEST revenu", n)
  W("f%d EDITION apres tests |%s| GAME_DIP %s", n, ligne(9), octets(0x10FD84, 16))
  appuyer(B.START)
  W("f%d START : sortie de l'editeur ; bloc du jeu %s", n, octets(0xD00220, 16))
  attendre(400) image("jeu")
  while true do coroutine.yield() end
end
local co = coroutine.create(scenario)

G.reset = emu.add_machine_reset_notifier(function() W("f%d RESET", n) end)
emu.register_frame_done(function()
  n = n + 1
  B.TEST:set_value((n <= 260 or tenus[B.TEST]) and 1 or 0)
  for k, b in pairs(B) do if k ~= "TEST" then b:set_value(tenus[b] and 1 or 0) end end
  local ok, err = coroutine.resume(co)
  if not ok then W("f%d ERREUR %s", n, tostring(err)) end
  local u = string.format("%02X/%02X", p:read_u8(0x10FDAF), p:read_u8(0x10FDAE))
  if u ~= G.user then G.user = u W("f%d user=%s", n, u) end
  -- À la remise au jeu ($10FD80 ← $82), sa zone de sauvegarde (pointeur $10E, taille $112 de
  -- l'en-tête) et son bloc en backup RAM ($D00320 + $1000 × b), en somme et en empreinte.
  if not G.remise and p:read_u8(0x10FD80) == 0x82 then
    G.remise = true
    local function emp(a, k)
      local s, h = 0, 0
      for i = 0, k - 1 do local b = p:read_u8(a + i) s = s + b h = (h * 31 + b) & 0xFFFFFFFF end
      return s, h
    end
    local ptr, taille = p:read_u32(0x10E), p:read_u16(0x112)
    local bloc = p:read_u16(0xD00124 + 4 * p:read_u8(0xD00108) + 2)
    local zs, zh = emp(ptr, taille)
    local bs, bh = 0, 0
    if bloc < 8 then bs, bh = emp(0xD00320 + 0x1000 * bloc, taille) end
    W("f%d REMISE zone=%06X+%X somme=%d h=%08X bloc=%d somme=%d h=%08X", n, ptr, taille, zs, zh, bloc, bs, bh)
  end
  if n % 100 == 0 then W("f%d vifs=%d", n, vifs()) end
  if n >= FIN then out:close() m:exit() end
end)
