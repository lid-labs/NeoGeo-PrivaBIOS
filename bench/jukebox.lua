-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- Jig du jukebox (`src/c0/jukebox.s`), sans fenêtre. TEST tenu au boot ouvre l'écran TEST
-- (`dip.s`) ; le jig monte à la ligne JUKEBOX, l'ouvre, et pour chaque code de la série :
-- B (le pilote relancé), une fenêtre de CONTRÔLE sans code envoyé, puis A et une fenêtre de
-- RÉPONSE. Chaque fenêtre compte les écritures du Z80 au YM2610 — ports $04-$07 de l'espace
-- I/O de :audiocpu, lu dans « Z80 port map » (« 2610WR ») —, les réponses du Z80 au 68000
-- (port $0C, « SDZ80W », même page) et les écritures du 68000 à REG_SOUND ($320000).
-- LE COMPTE BRUT NE SUFFIT PAS : mesuré sur aof le 2026-10-21, le pilote au repos écrit déjà
-- ~8 fois par trame à la puce. On compte donc aussi les DÉCLENCHEMENTS, lus dans « YM2610
-- registers » (port 0 = $04 adresse / $05 donnée, port 1 = $06 / $07) : FM key-on, registre
-- $28 du port 0, champ « Slot » non nul (SUPPOSÉ : bits 7-4, la disposition des OPN) ;
-- ADPCM-A, registre $00 du port 1, bit 7 (dump) à 0 et un des bits 5-0 à 1 ; ADPCM-B,
-- registre $10 du port 0, bit 7 (start) ; SSG, registres $08-$0A du port 0, volume non nul
-- (SUPPOSÉ : bits 4-0, mode compris). Un code « fait réagir la puce » si sa fenêtre de
-- réponse compte plus de déclenchements que sa fenêtre de contrôle.
-- Puis START (retour à l'écran TEST), START (le jeu), et un relevé du jeu sur J_JEU trames.
--
-- J_MODE=temoin : même boot, TEST tenu, mais START tout de suite sur l'écran TEST, sans
-- jukebox : le relevé du jeu sert de témoin à celui du mode jukebox. Les deux relevés du jeu
-- partent de la trame où START quitte l'écran TEST.
--
-- On ne lit AUCUN octet de ROM ni le code Z80 : seulement des écritures sur des ports et le
-- plan fixe reconstruit depuis les écritures au LSPC (comme `autotests.lua`).
--
--   J_OUT     dossier de sortie (obligatoire) : J_OUT/jukebox.txt, J_OUT/jukebox.tsv, images
--             bgra 320×224 en J_OUT/fNNNNN-<nom>.bin. jukebox.txt porte, par code, les bornes
--             des deux fenêtres en secondes de la machine (« FENETRES »), pour lire le son
--             réellement produit dans le WAV de `-wavwrite` (`bench/parcours.sh`)
--   J_MODE    jukebox (défaut) | temoin
--   J_CODES   premier et dernier code, « 00-3F » par défaut ($01-$03 sautés par l'écran)
--   J_CTRL    trames de la fenêtre de contrôle (défaut 60)
--   J_REP     trames de la fenêtre de réponse (défaut 120, ~2 s)
--   J_JEU     trames du relevé du jeu (défaut 3000)
--   J_STOP    1 (défaut) : B avant chaque code, le pilote relancé ; 0 : les codes à la suite
--   J_APRES_RAZ un code (hexadécimal) envoyé après chaque B, avant la fenêtre de contrôle
--   J_NAV=1   à la place de la série : la navigation (droite, qui ouvre, tenue 600 trames,
--             puis un appui de chaque direction, puis haut tenu 60 trames), code relevé à chaque pas
--   J_SEQUENCE codes à envoyer dans l'ordre (« 07 1A C7 »), à la place de J_CODES ; $01-$03 refusés
--   J_PREFIXE un code envoyé une fois avant la série (hexadécimal), le pilote non relancé après
--
--   SDL_VIDEODRIVER=dummy SDL_MAC_BACKGROUND_APP=1 J_OUT=<dossier> mame <jeu> -bios euro \
--     -rompath <romsets à notre image> -video none -sound none -nothrottle \
--     -nvram_directory <neuve> -autoboot_script bench/jukebox.lua
if _G.JUKEBOX then return end
_G.JUKEBOX = {}
local G = _G.JUKEBOX
local OUT = os.getenv("J_OUT")
if not OUT then print("JUKEBOX: J_OUT manquant") manager.machine:exit() return end
local MODE = os.getenv("J_MODE") or "jukebox"
local C0, C1 = (os.getenv("J_CODES") or "00-3F"):match("(%x+)-(%x+)")
C0, C1 = tonumber(C0, 16), tonumber(C1, 16)
-- L'écran n'affiche que deux chiffres : un code au-delà de $FF ne serait jamais atteint.
assert(C0 and C1 and C0 <= C1 and C1 <= 0xFF, "J_CODES hors de 00-FF : " .. tostring(os.getenv("J_CODES")))
local CTRL = tonumber(os.getenv("J_CTRL") or "60")
local REP = tonumber(os.getenv("J_REP") or "120")
local JEU = tonumber(os.getenv("J_JEU") or "3000")
local STOP = (os.getenv("J_STOP") or "1") == "1"
local APRES = os.getenv("J_APRES_RAZ") -- un code envoyé après chaque B, ex. « 07 »
local PREFIXE = os.getenv("J_PREFIXE") -- un code envoyé une fois avant la série, ex. « 07 »
local m = manager.machine
local p = m.devices[":maincpu"].spaces["program"]
local io = m.devices[":audiocpu"].spaces["io"]
local ecran = m.screens:at(1)
local function F(pt, n) local x = m.ioport.ports[pt] assert(x, pt) local f = x.fields[n] assert(f, n) return f end
local B = {
  haut = F(":edge:joy:JOY1", "P1 Up"), bas = F(":edge:joy:JOY1", "P1 Down"),
  gauche = F(":edge:joy:JOY1", "P1 Left"), droite = F(":edge:joy:JOY1", "P1 Right"), A = F(":edge:joy:JOY1", "P1 A"), B1 = F(":edge:joy:JOY1", "P1 B"),
  START = F(":edge:joy:START", "1 Player Start"), TEST = F(":TEST", "Service Mode"),
}
local tenus = {}
local out = _G.io.open(OUT .. "/jukebox.txt", "w")
local tsv = _G.io.open(OUT .. "/jukebox.tsv", "w")
local function W(fmt, ...) out:write(string.format(fmt, ...) .. "\n") out:flush() end
local n = 0

-- Les compteurs, remis à zéro par fenêtre.
local K = { ym = 0, rep = 0, son = 0, autres = 0, dec = 0, derniere_rep = -1 }
local function raz() K.ym, K.rep, K.son, K.autres, K.dec = 0, 0, 0, 0, 0 end
local reg = { [0] = 0, [1] = 0 } -- le registre choisi, par port de la puce
G.tio = io:install_write_tap(0x0000, 0xFFFF, "z80io", function(o, d)
  local port = o & 0xFF
  d = d & 0xFF
  if port >= 4 and port <= 7 then
    K.ym = K.ym + 1
    local pp = (port - 4) >> 1
    if port & 1 == 0 then reg[pp] = d
    else
      local r = reg[pp]
      if (pp == 0 and r == 0x28 and (d & 0xF0) ~= 0)
        or (pp == 1 and r == 0x00 and (d & 0x80) == 0 and (d & 0x3F) ~= 0)
        or (pp == 0 and r == 0x10 and (d & 0x80) ~= 0)
        or (pp == 0 and r >= 0x08 and r <= 0x0A and (d & 0x1F) ~= 0) then
        K.dec = K.dec + 1
      end
    end
  elseif port == 0x0C then K.rep = K.rep + 1 K.derniere_rep = d & 0xFF
  else K.autres = K.autres + 1 end
end)
G.tson = p:install_write_tap(0x320000, 0x320001, "son", function(o, d, mk)
  if o == 0x320000 and (mk & 0xFF00) ~= 0 then
    K.son = K.son + 1
    if G.jeu then G.codes_jeu[#G.codes_jeu + 1] = string.format("%02X", (d >> 8) & 0xFF) end
  end
end)

-- Le plan fixe, reconstruit.
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
local function contient(s) for r = 0, 31 do if ligne(r):find(s, 1, true) then return true end end return false end
local function image(nom)
  local f = _G.io.open(string.format("%s/f%05d-%s.bin", OUT, n, nom), "wb") f:write((ecran:pixels())) f:close()
  W("f%d IMAGE %s", n, nom)
end

local function attendre(k) for _ = 1, k do coroutine.yield() end end
local function appuyer(b, k) tenus[b] = true attendre(k or 3) tenus[b] = nil attendre(4) end
local function jusqua(pred, maxi, quoi)
  for _ = 1, maxi do if pred() then return true end coroutine.yield() end
  W("f%d DELAI %s", n, quoi) return false
end
local function fenetre(k) raz() attendre(k) return K.ym, K.dec, K.rep, K.son end
local function code_affiche() return ligne(12):sub(16, 17) end

local function scenario()
  jusqua(function() return contient("SOFT DIP SETTINGS") end, 900, "ecran TEST")
  attendre(10)
  if MODE == "jukebox" then
    -- De la ligne 0, haut deux fois : la remise (la dernière), puis JUKEBOX.
    appuyer(B.haut) appuyer(B.haut)
    W("f%d ligne choisie : JUKEBOX ? %s", n, tostring(contient("> JUKEBOX")))
    -- J_NAV : droite ouvre la ligne (`dip.s`) et reste tenue dans le jukebox.
    if os.getenv("J_NAV") == "1" then tenus[B.droite] = true else appuyer(B.A) end
    jusqua(function() return contient("SOUND CODE") end, 120, "jukebox")
    attendre(20) image("jukebox")
    W("f%d ECRAN |%s|%s|%s|", n, ligne(4), ligne(6), ligne(12))
    if os.getenv("J_NAV") == "1" then
      local function pas(quoi) W("f%d NAV %s code=%s", n, quoi, code_affiche()) end
      pas("ouverture, droite tenue")
      attendre(600) pas("droite tenue 600 trames de plus")
      tenus[B.droite] = nil attendre(4) pas("relachee")
      appuyer(B.haut) pas("haut")
      appuyer(B.bas) pas("bas")
      appuyer(B.droite) pas("droite")
      appuyer(B.gauche) pas("gauche")
      tenus[B.haut] = true attendre(60) tenus[B.haut] = nil attendre(4) pas("haut tenu 60 trames")
      tenus[B.bas] = true attendre(60) tenus[B.bas] = nil attendre(4) pas("bas tenu 60 trames")
      out:close() tsv:close() m:exit() return
    end
    tsv:write("code\tcode_affiche\tctrl_ym\tctrl_declench\tctrl_rep\tctrl_68k_son\trep_ym\trep_declench\trep_rep\trep_68k_son\tderniere_reponse\treagit\n")
    -- LA LISTE DES CODES MESURÉS : J_SEQUENCE telle quelle, sinon J_CODES. Les codes
    -- réservés $01-$03, que l'écran saute, sont écartés de la liste (refusés en J_SEQUENCE,
    -- avec une ligne au relevé). Le jig navigue jusqu'à chaque code par « haut » : la
    -- colonne `code` est celle qu'il visait, `code_affiche` celle que l'écran montre.
    local liste = {}
    local seq = os.getenv("J_SEQUENCE")
    if seq then
      -- Deux chiffres hexadécimaux par code, séparés par des espaces : tout autre jeton est refusé
      -- net, plutôt que d'être sauté sans trace.
      for jeton in seq:gmatch("%S+") do
        assert(jeton:match("^%x%x$"), "J_SEQUENCE : jeton invalide « " .. jeton .. " » (deux chiffres hexadécimaux)")
      end
      for h in seq:gmatch("%x%x") do
        local v = tonumber(h, 16)
        if v >= 1 and v <= 3 then W("f%d REFUS code reserve %02X", n, v) else liste[#liste + 1] = v end
      end
    else
      for v = C0, C1 do if v < 1 or v > 3 then liste[#liste + 1] = v end end
    end
    assert(not PREFIXE or PREFIXE:match("^%x%x?$"), "J_PREFIXE : « " .. tostring(PREFIXE) .. " » n'est pas un code hexadécimal")
    -- `pre`, pas `p` : ce nom masquerait l'espace programme, dont J_APRES_RAZ se sert plus bas.
    local pre = PREFIXE and tonumber(PREFIXE, 16)
    if pre and pre > 0xFF then
      W("f%d REFUS prefixe hors de 00-FF %X", n, pre)
    elseif pre and pre >= 1 and pre <= 3 then
      -- L'écran n'affiche jamais $01-$03 : naviguer vers l'un d'eux ne finirait pas.
      W("f%d REFUS prefixe reserve %02X", n, pre)
    elseif pre then
      local v = string.format("%02X", pre)
      while code_affiche() ~= v do appuyer(B.haut, 1) end
      appuyer(B.A) attendre(60)
      W("f%d PREFIXE %s envoye", n, v)
    end
    for _, c in ipairs(liste) do
      local v = string.format("%02X", c)
      while code_affiche() ~= v do appuyer(B.haut, 1) end
      if STOP then
        appuyer(B.B1) attendre(20)
        if APRES then
          -- Écrit par le jig à REG_SOUND, comme un jeu le fait après son reset (mesuré : aof,
          -- kof98, kof2003 envoient $07 avant tout son) ; le code de la série, lui, part par A.
          p:write_u8(0x320000, tonumber(APRES, 16)) attendre(20)
        end
      end
      local t0 = m.time:as_double()
      local cy, cd, cr, cs = fenetre(CTRL)
      local aff = code_affiche()
      K.derniere_rep = -1
      tenus[B.A] = true
      local t1 = m.time:as_double()
      local ry, rd, rr, rs = fenetre(REP)
      tenus[B.A] = nil
      -- Les bornes des deux fenêtres en temps de la machine : de quoi y lire le WAV de -wavwrite.
      W("f%d FENETRES %02X controle %.5f-%.5f reponse %.5f-%.5f", n, c, t0, t1, t1, m.time:as_double())
      tsv:write(string.format("%02X\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%s\t%s\n", c, aff, cy, cd, cr, cs, ry, rd, rr, rs,
        K.derniere_rep >= 0 and string.format("%02X", K.derniere_rep) or "-", rd > cd and "oui" or "non"))
      tsv:flush()
      if c == 0x10 then image("jukebox-10") end
    end
    appuyer(B.B1) attendre(20)
    appuyer(B.START)
    jusqua(function() return contient("SOFT DIP SETTINGS") end, 200, "retour TEST")
    attendre(10) image("ecran-test-retour")
    W("f%d ecran TEST revenu : %s", n, tostring(contient("> JUKEBOX")))
  end
  W("f%d START : sortie de l'ecran TEST", n)
  local t0 = n
  tenus[B.START] = true attendre(3) tenus[B.START] = nil
  raz()
  G.codes_jeu, G.jeu = {}, true
  local pas = {}
  for k = 1, JEU // 500 do
    attendre(500)
    pas[#pas + 1] = string.format("+%d son=%d ym=%d declench=%d rep=%d", n - t0, K.son, K.ym, K.dec, K.rep)
  end
  W("f%d JEU %s %s", n, MODE, table.concat(pas, " | "))
  W("f%d CODES_DU_JEU %s", n, table.concat(G.codes_jeu, " "))
  image("jeu")
  out:close() tsv:close() m:exit()
end
local co = coroutine.create(scenario)

G.reset = emu.add_machine_reset_notifier(function() W("f%d RESET", n) end)
emu.register_frame_done(function()
  n = n + 1
  B.TEST:set_value(n <= 260 and 1 or 0)
  for k, b in pairs(B) do if k ~= "TEST" then b:set_value(tenus[b] and 1 or 0) end end
  local ok, err = coroutine.resume(co)
  if not ok then W("f%d ERREUR %s", n, tostring(err)) out:close() m:exit() end
  local u = string.format("%02X/%02X", p:read_u8(0x10FDAF), p:read_u8(0x10FDAE))
  if u ~= G.user then G.user = u W("f%d user=%s", n, u) end
end)
