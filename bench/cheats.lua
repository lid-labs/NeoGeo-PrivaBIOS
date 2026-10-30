-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- Jig des cheats (`src/c0/cheats.s`), sans fenêtre. Trois usages, choisis par C_MODE :
--
--   releve  la RECHERCHE : le jeu joue des entrées planifiées, et la RAM de travail du jeu
--           ($100000-$10F2FF) est écrite toutes les C_PAS trames dans C_OUT/ram.bin, à la suite
--           (61 184 octets par relevé ; la trame de chaque relevé dans C_OUT/ram.idx). Le
--           filtrage se fait hors de MAME, sur ces relevés.
--   forcer  la PREUVE CAUSALE : à partir de C_DEPUIS, C_FORCER (« adr:taille:valeur », hex,
--           taille 1 ou 2, virgules) est écrit à chaque trame par lua ; le reste comme `releve`.
--   menu    LE CHEAT PAR LE BIOS : le menu en jeu ouvert par TEST tenu (C_MENU, trame), puis les
--           appuis de C_APPUIS ; lua n'écrit que C_FORCER, s'il est donné (BIOS_GAME_DIP, pour
--           un jeu dont `c0.s` ne décode pas les soft-DIP). Un tap d'écriture sur la RAM de
--           travail du jeu relève toute écriture faite depuis la zone haute du BIOS (PC ≥
--           $C04300) hors de la pile : c'est ce que le moteur écrit, et rien d'autre ne doit
--           y paraître. Le journal en donne les adresses et les comptes, à la dernière trame.
--
-- Communs :
--   C_OUT      dossier de sortie (obligatoire) ; journal C_OUT/cheats.txt
--   C_ENTREES  « a-b:bouton » (tenu des trames a à b) ou « a-b%p:bouton » (tenu la première
--              moitié de chaque période de p trames entre a et b), virgules. Boutons : piece,
--              START, haut, bas, gauche, droite, A, B, C, D ; pour P2, pieceDeux, startDeux,
--              droiteDeux, aDeux, bDeux, cDeux (des lettres seules : le motif est %a+)
--   C_APPUIS   « trame:bouton », 3 trames chacun (mode menu, comme `menu.lua`)
--   C_MENU     trame où TEST est tenu, 40 trames (mode menu) ; « a,b » pour deux ouvertures
--   C_SUIVRE   « adr:taille » (hex), virgules : valeurs écrites au journal toutes les C_PAS trames
--   C_PAS      période des relevés et du suivi (défaut 10)
--   C_IMAGES   trames dont l'image (bgra 320×224) est écrite en C_OUT/fNNNNN.bin
--   C_ZONE     « x0,y0,x1,y1 » (pixels, bornes comprises) : toutes les C_PAS trames, « zone= »
--              l'empreinte de ce rectangle de l'écran au journal — ce qu'affiche un chronomètre.
--              L'empreinte ne porte que les pixels clairs (R + V + B > C_SEUIL, défaut 600) : les
--              chiffres d'un chronomètre, sans le décor qui défile derrière eux ; C_SEUIL=0 : les
--              couleurs mêmes, pour un chronomètre dans un cadre opaque ; C_COULEUR « r0,r1,v0,v1,b0,b1 »
--              (bornes comprises, 0-255) : les pixels de cette couleur, celle des chiffres
--   L'en-tête du jeu, à la trame 600 : « ngh= » le mot $000108 et « empreinte= » la somme 16 bits
--   des 64 mots $000100-$00017E, ce que `_cheats_trouver` calcule (`src/c0/cheats.s`).
--   C_FIN      trame de sortie
--
-- La RAM de la recherche s'arrête à $10F2FF : au-dessus, c'est la pile et la RAM du BIOS, que le
-- jeu ne tient pas pour sienne (« BIOS RAM locations »). Le script est relu à chaque reset de la
-- machine (RESTART GAME) : la garde _G le fait ne s'installer qu'une fois.
if _G.CHJIG then return end
_G.CHJIG = {}
local OUT = os.getenv("C_OUT")
if not OUT then print("CHJIG: C_OUT manquant") manager.machine:exit() return end
local MODE = os.getenv("C_MODE") or "releve"
local PAS = tonumber(os.getenv("C_PAS") or "10")
local FIN = tonumber(os.getenv("C_FIN") or "3000")
local DEPUIS = tonumber(os.getenv("C_DEPUIS") or "0")
local m = manager.machine
local cpu = m.devices[":maincpu"]
local p = cpu.spaces["program"]
local ecran = m.screens:at(1)
local function F(pt, nom) local x = m.ioport.ports[pt] return x and x.fields[nom] end
local champs = {
  piece = F(":AUDIO_COIN", "Coin 1"), START = F(":edge:joy:START", "1 Player Start"),
  haut = F(":edge:joy:JOY1", "P1 Up"), bas = F(":edge:joy:JOY1", "P1 Down"),
  gauche = F(":edge:joy:JOY1", "P1 Left"), droite = F(":edge:joy:JOY1", "P1 Right"),
  A = F(":edge:joy:JOY1", "P1 A"), B = F(":edge:joy:JOY1", "P1 B"),
  C = F(":edge:joy:JOY1", "P1 C"), D = F(":edge:joy:JOY1", "P1 D"),
  pieceDeux = F(":AUDIO_COIN", "Coin 2"), startDeux = F(":edge:joy:START", "2 Players Start"),
  droiteDeux = F(":edge:joy:JOY2", "P2 Right"), aDeux = F(":edge:joy:JOY2", "P2 A"),
  bDeux = F(":edge:joy:JOY2", "P2 B"), cDeux = F(":edge:joy:JOY2", "P2 C"),
}
for k, c in pairs(champs) do assert(c, "champ MAME introuvable : " .. k) end
local test = F(":TEST", "Service Mode")
assert(test, "champ MAME :TEST « Service Mode » introuvable")

local plans = {}
for a, b, per, bt in (os.getenv("C_ENTREES") or ""):gmatch("(%d+)-(%d+)%%?(%d*):(%a+)") do
  assert(champs[bt], "bouton inconnu : " .. bt)
  plans[#plans + 1] = { tonumber(a), tonumber(b), tonumber(per), bt }
end
local appuis = {}
for t, bt in (os.getenv("C_APPUIS") or ""):gmatch("(%d+):(%a+)") do
  assert(champs[bt], "bouton inconnu : " .. bt) appuis[#appuis + 1] = { tonumber(t), bt } end
local menus = {}
for t in (os.getenv("C_MENU") or ""):gmatch("%d+") do menus[#menus + 1] = tonumber(t) end
local forcer = {}
for a, t, v in (os.getenv("C_FORCER") or ""):gmatch("(%x+):(%d):(%x+)") do
  forcer[#forcer + 1] = { tonumber(a, 16), tonumber(t), tonumber(v, 16) } end
local suivre = {}
for a, t in (os.getenv("C_SUIVRE") or ""):gmatch("(%x+):(%d)") do suivre[#suivre + 1] = { tonumber(a, 16), tonumber(t) } end
local images = {}
for x in (os.getenv("C_IMAGES") or ""):gmatch("%d+") do images[tonumber(x)] = true end
local zone = nil
do
  local x0, y0, x1, y1 = (os.getenv("C_ZONE") or ""):match("(%d+),(%d+),(%d+),(%d+)")
  if x0 then zone = { tonumber(x0), tonumber(y0), tonumber(x1), tonumber(y1) } end
end
-- L'empreinte d'un rectangle de l'image (bgra, 320 de large) : FNV-1a 32 bits sur le masque de ses
-- pixels clairs, un bit par pixel.
local SEUIL = tonumber(os.getenv("C_SEUIL") or "600")
local COUL = nil
do
  local t = {} for x in (os.getenv("C_COULEUR") or ""):gmatch("%d+") do t[#t + 1] = tonumber(x) end
  if #t == 6 then COUL = t end
end
local function hache_zone(px)
  local h = 2166136261
  for y = zone[2], zone[4] do
    local o = (y * 320 + zone[1]) * 4
    for x = 0, zone[3] - zone[1] do
      local b, v, r = px:byte(o + 4 * x + 1, o + 4 * x + 3)
      if COUL then
        local dedans = r >= COUL[1] and r <= COUL[2] and v >= COUL[3] and v <= COUL[4] and b >= COUL[5] and b <= COUL[6]
        h = ((h ~ (dedans and 1 or 0)) * 16777619) & 0xFFFFFFFF
      elseif SEUIL == 0 then
        h = ((((((h ~ b) * 16777619) & 0xFFFFFFFF ~ v) * 16777619) & 0xFFFFFFFF ~ r) * 16777619) & 0xFFFFFFFF
      else
        h = ((h ~ ((b + v + r > SEUIL) and 1 or 0)) * 16777619) & 0xFFFFFFFF
      end
    end
  end
  return h
end

local out = io.open(OUT .. "/cheats.txt", "w")
local function W(fmt, ...) out:write(string.format(fmt, ...) .. "\n") out:flush() end
local ram, idx
if MODE == "releve" or MODE == "forcer" then
  ram = io.open(OUT .. "/ram.bin", "wb") idx = io.open(OUT .. "/ram.idx", "w")
end

-- Le tap du mode menu, sur la RAM de travail du jeu seule ($100000-$10F2FF) : au-dessus, la RAM
-- du BIOS, où le menu ($10F4C0-$10FAFF) et les états des cheats ($10FB00-$10FB07) vivent.
-- Les écritures dans la pile du jeu (de SP − 64 à $10F2FF : adresses de retour et registres
-- sauvés par le crochet) sont comptées à part, sans détail — sauf si l'adresse est celle d'une
-- écriture d'un cheat du jeu, lue dans la table du BIOS par CH_ENTREE ($10FB00) et CH_NB
-- ($10FB04) : un cheat qui viserait la pile reste compté comme écriture du moteur.
local ecrits, nb_ecrits, nb_pile, trames = {}, 0, 0, {}
local n = 0
local cibles, cibles_de = {}, -1
local function est_cible(o)
  local e = p:read_u32(0x10FB00)
  if e ~= cibles_de then
    cibles, cibles_de = {}, e
    if e ~= 0 then
      for k = 0, p:read_u16(0x10FB04) - 1 do
        for w = 0, 1 do
          local f = e + 32 * k + 16 + 8 * w
          local a, t = p:read_u32(f), p:read_u16(f + 4)
          if t == 1 then cibles[a & ~1] = true elseif t == 2 then cibles[a] = true end
        end
      end
    end
  end
  return cibles[o & ~1]
end
if MODE == "menu" then
  _G.CHJIG.tap = p:install_write_tap(0x100000, 0x10F2FF, "moteur", function(o, d, mk)
    local pc = cpu.state["PC"].value
    if pc >= 0xC04300 and pc < 0xC20000 then
      if o >= cpu.state["SP"].value - 64 and not est_cible(o) then nb_pile = nb_pile + 1
      else
        nb_ecrits = nb_ecrits + 1
        trames[n + 1] = true         -- la trame en cours
        local k = string.format("%06X", o)
        ecrits[k] = (ecrits[k] or 0) + 1
      end
    end
  end)
  _G.CHJIG.reset = emu.add_machine_reset_notifier(function() W("f%d RESET", n) end)
end

local function lire(a, t) if t == 1 then return p:read_u8(a) else return p:read_u16(a) end end

emu.register_frame_done(function()
  n = n + 1
  local tenus = {}
  for _, x in ipairs(plans) do
    if n >= x[1] and n <= x[2] then
      if not x[3] then tenus[x[4]] = true
      elseif (n - x[1]) % x[3] < x[3] // 2 then tenus[x[4]] = true end
    end
  end
  for _, a in ipairs(appuis) do if n >= a[1] and n < a[1] + 3 then tenus[a[2]] = true end end
  local t_test = false
  for _, t in ipairs(menus) do if n >= t and n < t + 40 then t_test = true end end
  test:set_value(t_test and 1 or 0)
  for k, c in pairs(champs) do c:set_value(tenus[k] and 1 or 0) end
  if (MODE == "forcer" or MODE == "menu") and n >= DEPUIS then
    for _, f in ipairs(forcer) do if f[2] == 1 then p:write_u8(f[1], f[3]) else p:write_u16(f[1], f[3]) end end
  end
  local u = p:read_u8(0x10FDAF)
  if u ~= _G.CHJIG.user then _G.CHJIG.user = u W("f%d user=%02X", n, u) end
  if n == 600 then
    local s = 0
    for a = 0x100, 0x17E, 2 do s = (s + p:read_u16(a)) & 0xFFFF end
    W("f%d ngh=%04X empreinte=%04X", n, p:read_u16(0x108), s)
  end
  if zone and n % PAS == 0 then W("f%d zone=%08X", n, hache_zone(ecran:pixels())) end
  if n % PAS == 0 then
    if ram then
      local t = {}
      for a = 0x100000, 0x10F2FF, 4 do t[#t + 1] = string.pack(">I4", p:read_u32(a)) end
      ram:write(table.concat(t)) idx:write(n .. "\n")
    end
    if #suivre > 0 then
      local v = {}
      for _, s in ipairs(suivre) do v[#v + 1] = string.format("%06X=%X", s[1], lire(s[1], s[2])) end
      W("f%d %s etats=%04X", n, table.concat(v, " "), p:read_u16(0x10FB06))
    end
  end
  if images[n] then
    local f = io.open(string.format("%s/f%05d.bin", OUT, n), "wb") f:write((ecran:pixels())) f:close()
  end
  if n >= FIN then
    if MODE == "menu" then
      local t = {} for k, c in pairs(ecrits) do t[#t + 1] = k .. "x" .. c end table.sort(t)
      W("f%d ecritures du moteur : %d %s ; pile : %d", n, nb_ecrits, table.concat(t, " "), nb_pile)
      -- les trames où le moteur a écrit, en intervalles
      local iv, debut = {}, nil
      for i = 1, n + 1 do
        if trames[i] and not debut then debut = i
        elseif not trames[i] and debut then iv[#iv + 1] = debut .. "-" .. (i - 1) debut = nil end
      end
      W("f%d trames ecrites par le moteur : %s", n, #iv > 0 and table.concat(iv, " ") or "aucune")
    end
    if ram then ram:close() idx:close() end
    out:close() m:exit()
  end
end)
