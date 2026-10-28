-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- Jig du multi-slot, sans fenêtre : ce que le BIOS fait sur une carte à plusieurs emplacements
-- (la machine `neogeo` de MAME est une MV-6F, `-cart1` … `-cart6`). Mesure seulement : il ne
-- presse que les entrées qu'on lui donne, et ne touche à rien d'autre — sauf, si on le lui
-- demande, les octets que MS_POSER écrit dans la RAM du jeu.
--
--   SDL_VIDEODRIVER=dummy SDL_MAC_BACKGROUND_APP=1 MS_OUT=<sortie.tsv> \
--   mame neogeo -bios euro -hashpath <mame>/hash -rompath $ROMS \
--     -cart1 puzzledp -cart2 aof -video none -sound none -nothrottle \
--     -nvram_directory <neuf> -autoboot_script bench/multislot.lua
--
-- Les jeux se nomment par la liste logicielle `neogeo` ; sans `-hashpath` vers le `hash/` de
-- MAME, elle est introuvable et `-cart1 puzzledp` échoue (« No such file or directory »).
--
-- Réglages par l'environnement, un lua d'autoboot ne recevant pas d'arguments :
--   MS_OUT        TSV de sortie (obligatoire), une ligne par évènement
--   MS_FIN        dernière trame (défaut 6000) ; la machine s'arrête juste après
--   MS_ENTREES    entrées à presser, « trame:nom[:durée] » séparées par des virgules, durée 8 par
--                 défaut. Noms : piece, start, start2, suivant, precedent (les deux boutons de
--                 choix du jeu d'une MVS, « Next Game » / « Previous Game » chez MAME), a, test
--   MS_IMAGES     trames où écrire l'écran brut (bgra, 320 × 224) dans MS_DIR, séparées par des
--                 virgules
--   MS_DIR        dossier des captures (défaut : celui de MS_OUT)
--   MS_CAPT_USER  n : une capture n trames après chaque remise de la main à l'entrée USER
--                 ($000122), 60 au plus — l'écran du jeu que le BIOS vient de lancer
--   MS_PLAFOND    lignes au plus par adresse bruyante (défaut 200, voir « le bruit »)
--   MS_SONDE_PROM 1 : relève aussi les plages de la P-ROM de la cartouche que le BIOS lit
--   MS_DETAIL     <de>-<a> : chaque lecture du BIOS hors de sa ROM et de la RAM de travail, sur
--                 ces trames (voir plus bas)
--   MS_SONDE_M1   1 : la M1 que voit le Z80 (slot reconnu), sous REG_CRTFIX seulement (voir plus bas)
--   MS_LECT_JEU   1 : les lectures que fait le JEU dans $D00000-$D003FF (zone système de la backup
--                 RAM), comptées par adresse et sorties au bilan (genre R, « lu par jeu ») — pour
--                 savoir si un jeu lit une cellule que le BIOS y tient
--   MS_PLAGES     1 : les sauvegardes de jeu, en plages par trame (genre P, voir plus bas), et
--                 chaque entrée de SYSTEM_RETURN avec son code (ligne E « C00444 »)
--   MS_VIDAGES    trames où écrire la zone de sauvegarde du jeu servi et son bloc de backup RAM,
--                 en hexadécimal, dans MS_DIR (voir plus bas)
--   MS_POSER      <trame>@<adresse>=<octets hex>, séparés par des virgules : écrit ces octets
--                 dans la RAM de travail du jeu en fin de trame (voir plus bas)
--   MS_SUIVRE     adresses hexadécimales d'octets de RAM ou de backup RAM, séparées par des
--                 virgules ($100000-$10FFFF et $D00000-$D0FFFF seulement) : en fin de trame, une
--                 ligne E par octet dont la valeur a changé — le crédit $D00034, le mode et la
--                 demande $10FDAF/$10FDAE à travers un geste, sans dépendre de qui les écrit
--
-- CE QUI EST RELEVÉ — des adresses de registres et de RAM avec les valeurs écrites ; ce jig ne
-- consigne aucun PC ni aucun octet lu dans la ROM du BIOS (`docs/DECISIONS.md` §8). Le PC n'est lu que pour dire QUI
-- écrit (bios s'il est dans $C00000-$C1FFFF, jeu sinon), et ce côté seul est écrit :
--   - les écritures sur $380000-$3800FF (REG_SLOT à $380021, sorties EL/LED…) et sur les bascules
--     système $3A0000-$3A001F (BRDFIX, CRTFIX, SWPROM, SRAMLOCK…) ;
--   - REG_SOUND : chaque écriture, et par trame le nombre de lectures et combien rendaient $01,
--     l'écho de « 68k/Z80 communication » ;
--   - par trame, le nombre de lectures de REG_STATUS_B ($380000), REG_P1CNT / REG_DIPSW
--     ($300000/1), REG_SYSTYPE ($300081) et REG_STATUS_A ($320001), quand il change ;
--   - les lectures de l'en-tête de cartouche $000100-$00013F faites par le BIOS, avec le slot
--     que désigne le NGH lu à $000108 (comparé à celui de chaque région `:cslotN:maincpu` : seule
--     la ROM des JEUX est relue) ; la lecture de $000122, l'entrée USER, avec la demande et le
--     mode du moment ;
--   - les écritures en backup RAM : une par une sur $D00000-$D003FF, résumées au-delà de 400 par
--     trame (un remplissage : compte et valeurs distinctes), comptées par trame au-delà ; une
--     valeur qui pourrait former une adresse de la ROM du BIOS sort « retenu » (voir le garde) ;
--   - les écritures sur quelques variables du BIOS ($10FCEF, $10FD80-$10FD83, $10FDAE, $10FDAF,
--     $10FEE1), une ligne quand la valeur change pour un écrivain donné ;
--   - en fin de trame : le côté qui a la main quand il change, et le slot dont MAME sert alors la
--     P-ROM (le NGH à $000108, relu par le jig hors des taps) quand il change.
--
-- Colonnes : trame, fraction de trame écoulée (l'écran ne donne pas sa ligne à lua, l'horloge de
-- la machine si), genre (W écriture, R lecture, E état, I entrée, B bilan du bruit), adresse,
-- valeur, dernière valeur écrite dans REG_SLOT, note. Les lignes mises en tampon (backup RAM,
-- en-tête) sortent en fin de trame : trier sur (trame, fraction) pour la chronologie.
if _G.MULTISLOT then return end
_G.MULTISLOT = {}
local G = _G.MULTISLOT
local OUT = os.getenv("MS_OUT")
if not OUT then print("MULTISLOT: MS_OUT manquant") manager.machine:exit() return end
local FIN = tonumber(os.getenv("MS_FIN") or "6000")
local DIR = os.getenv("MS_DIR") or OUT:match("^(.*)/[^/]*$") or "."
local PLAFOND = tonumber(os.getenv("MS_PLAFOND") or "200")
local CAPT_USER = tonumber(os.getenv("MS_CAPT_USER") or "")
local images = {}
for n in (os.getenv("MS_IMAGES") or ""):gmatch("%d+") do images[tonumber(n)] = true end
G.capt_prevues = {}

local m = manager.machine
local cpu = m.devices[":maincpu"]
local p = cpu.spaces["program"]
local ecran = m.screens:at(1)

-- Le NGH de chaque cartouche montée, lu dans la ROM du jeu ($108, mot BCD de l'en-tête).
local ngh = {}
for k = 1, 6 do
  local r = m.memory.regions[":cslot" .. k .. ":maincpu"]
  if r then ngh[k] = (r:read_u8(0x108) << 8) | r:read_u8(0x109) end
end
local function slot_de(mot)
  local s = {}
  for k = 1, 6 do if ngh[k] and ngh[k] == mot then s[#s + 1] = tostring(k - 1) end end
  return #s > 0 and table.concat(s, "+") or "aucun"
end

local f = io.open(OUT, "w")
f:write("trame\tfraction\tgenre\tadresse\tvaleur\tslot\tnote\n")
local cartes = {}
for k = 1, 6 do
  local r = m.memory.regions[":cslot" .. k .. ":maincpu"]
  cartes[#cartes + 1] = ngh[k] and string.format("%d:%04X(sauv %06X+%04X)", k - 1, ngh[k],
    (r:read_u8(0x10F) << 16) | (r:read_u8(0x110) << 8) | r:read_u8(0x111),
    (r:read_u8(0x112) << 8) | r:read_u8(0x113)) or (k - 1) .. ":vide"
end
f:write("#\tcartes (slot:NGH)\t" .. table.concat(cartes, " ") .. "\n")

local trame, reg_slot, interne = 1, "-", false
local t0, PERIODE = 0, 1 / 59.185
local function fraction() return (m.time:as_double() - t0) / PERIODE end
local function ligne(genre, adr, val, note)
  f:write(string.format("%d\t%.2f\t%s\t%s\t%s\t%s\t%s\n", trame, fraction(), genre, adr, val,
    reg_slot, note or ""))
end
local function cote() return (cpu.state["PC"].value & 0xFFFFFF) >= 0xC00000 and "bios" or "jeu" end

-- Un tap reçoit l'adresse paire du mot et le masque des octets touchés : on rend chaque octet.
local function octets(off, data, mask, fn)
  if mask & 0xFF00 ~= 0 then fn(off, (data >> 8) & 0xFF) end
  if mask & 0x00FF ~= 0 then fn(off + 1, data & 0xFF) end
end

local NOMS = {
  [0x380001] = "REG_POUTPUT", [0x380021] = "REG_SLOT", [0x380031] = "REG_LEDLATCHES",
  [0x380041] = "REG_LEDDATA", [0x380051] = "REG_RTCCTRL",
  [0x3A0001] = "REG_NOSHADOW", [0x3A0011] = "REG_SHADOW", [0x3A0003] = "REG_SWPBIOS",
  [0x3A0013] = "REG_SWPROM", [0x3A0005] = "REG_CRDUNLOCK1", [0x3A0015] = "REG_CRDLOCK1",
  [0x3A0007] = "REG_CRDLOCK2", [0x3A0017] = "REG_CRDUNLOCK2", [0x3A0009] = "REG_CRDREGSEL",
  [0x3A0019] = "REG_CRDNORMAL", [0x3A000B] = "REG_BRDFIX", [0x3A001B] = "REG_CRTFIX",
  [0x3A000D] = "REG_SRAMLOCK", [0x3A001D] = "REG_SRAMUNLOCK", [0x3A000F] = "REG_PALBANK0",
  [0x3A001F] = "REG_PALBANK1",
}

-- LE BRUIT. Une adresse réécrite à l'identique ne fait pas de ligne, et une adresse qui en a
-- déjà fait PLAFOND n'en fait plus : ses écritures se comptent et sortent en fin de run (genre
-- « B »). Sans cela, les sorties EL/LED et les compteurs de la backup RAM, réécrits à chaque
-- trame, font 99 % du relevé. REG_SLOT et les bascules de ROM échappent aux deux filtres.
local der_val, n_lig, tues, ident = {}, {}, {}, {}
local function plafond(adr)
  n_lig[adr] = (n_lig[adr] or 0) + 1
  if n_lig[adr] > PLAFOND then tues[adr] = (tues[adr] or 0) + 1 return false end
  return true
end
local function filtre(adr, v)
  if der_val[adr] == v then ident[adr] = (ident[adr] or 0) + 1 return false end
  der_val[adr] = v
  return plafond(adr)
end
local LIBRES = { [0x380021] = true, [0x3A000B] = true, [0x3A001B] = true, [0x3A0013] = true,
  [0x3A0003] = true }

-- MS_SONDE_M1=1 : QUELLE M1 LE Z80 VOIT, juste avant chaque écriture de REG_SLOT, REG_BRDFIX,
-- REG_CRTFIX ou REG_SOUND et en fin de trame ; une ligne E « Z80:0000 » quand ça change. Sous
-- REG_CRTFIX seulement : les 256 premiers octets de l'espace du Z80 sont comparés à ceux de la
-- région `:cslotN:audiocpu` de chaque cartouche montée, et seul le slot reconnu sort. Sous
-- REG_BRDFIX, c'est la SM1 de la carte, une ROM SNK : rien n'est lu (`docs/DECISIONS.md` §8).
-- Le tap passe AVANT l'écriture qu'il voit : la ligne dit l'état qu'elle va changer.
local SONDE_M1 = os.getenv("MS_SONDE_M1") == "1"
local fixe, m1_avant = "brd", nil
local z80 = SONDE_M1 and m.devices[":audiocpu"].spaces["program"]
local function sonde_m1(moment)
  if not SONDE_M1 then return end
  local vu = "SM1 de la carte (non lue)"
  if fixe == "crt" then
    local s = {}
    for k = 1, 6 do
      local r = m.memory.regions[":cslot" .. k .. ":audiocpu"]
      if r then
        local pareil = true
        for i = 0, 255 do if z80:read_u8(i) ~= r:read_u8(i) then pareil = false break end end
        if pareil then s[#s + 1] = tostring(k - 1) end
      end
    end
    vu = "M1 du slot " .. (#s > 0 and table.concat(s, "+") or "aucun")
  end
  if vu ~= m1_avant then m1_avant = vu ligne("E", "Z80:0000", vu, "M1 vue par le Z80, avant " .. moment) end
end

G.t_io = p:install_write_tap(0x380000, 0x3800FF, "ms_io", function(off, data, mask)
  if interne then return end
  octets(off, data, mask, function(a, v)
    if a == 0x380021 then sonde_m1("REG_SLOT") end
    if a == 0x380021 then reg_slot = string.format("%02X", v) G.retaper, G.attente = true, 2 end
    if LIBRES[a] or filtre(a, v) then
      ligne("W", string.format("%06X", a), string.format("%02X", v), (NOMS[a] or "") .. " par " .. cote())
    end
  end)
end)
-- Les bascules système vont par paires, le bit 4 de l'adresse faisant la donnée (« Memory
-- mapped registers ») : la « valeur » filtrée est donc la moitié de la paire touchée.
G.t_sys = p:install_write_tap(0x3A0000, 0x3A001F, "ms_sys", function(off, data, mask)
  if interne then return end
  octets(off, data, mask, function(a, v)
    if a & 1 == 0 then return end
    if a == 0x3A000B or a == 0x3A001B then
      sonde_m1(NOMS[a])
      fixe = a == 0x3A000B and "brd" or "crt"
    end
    if LIBRES[a] or filtre(a & ~0x10, a) then
      ligne("W", string.format("%06X", a), "-", (NOMS[a] or "") .. " par " .. cote())
    end
  end)
end)

-- Les lectures de registres d'état se comptent par trame ; le compte ne fait une ligne que quand
-- il diffère de celui de la trame précédente. Leur valeur est une entrée, pas un fait du BIOS.
local lect, lect_avant = {}, {}
local function compter(nom) lect[nom] = (lect[nom] or 0) + 1 end

-- REG_SOUND : écritures une par une, lectures comptées par trame.
local son_lect, son_echo = 0, 0
G.t_sonw = p:install_write_tap(0x320000, 0x320001, "ms_sonw", function(off, data, mask)
  if interne then return end
  if mask & 0xFF00 ~= 0 then
    sonde_m1("REG_SOUND")
    ligne("W", "320000", string.format("%02X", (data >> 8) & 0xFF), "REG_SOUND par " .. cote())
  end
end)
G.t_sonr = p:install_read_tap(0x320000, 0x320001, "ms_sonr", function(off, data, mask)
  if interne then return end
  if mask & 0xFF00 ~= 0 then
    son_lect = son_lect + 1
    if (data >> 8) & 0xFF == 0x01 then son_echo = son_echo + 1 end
  end
  if mask & 0x00FF ~= 0 then compter("320001 REG_STATUS_A") end
end)
-- REG_STATUS_B porte les boutons de choix du jeu : sa valeur lue (une entrée de la carte, pas un
-- octet du BIOS) fait une ligne quand elle change, pour voir si un geste arrive jusqu'au 68000.
local stb_avant
G.t_stb = p:install_read_tap(0x380000, 0x380001, "ms_stb", function(off, data, mask)
  if interne then return end
  compter("380000 REG_STATUS_B")
  if data ~= stb_avant then
    stb_avant = data
    ligne("R", "380000", string.format("%04X", data & 0xFFFF), "REG_STATUS_B lu (mot), par " .. cote())
  end
end)
G.t_p1 = p:install_read_tap(0x300000, 0x300001, "ms_p1", function(off, data, mask)
  if interne then return end
  if mask & 0xFF00 ~= 0 then compter("300000 REG_P1CNT") end
  if mask & 0x00FF ~= 0 then compter("300001 REG_DIPSW") end
end)
G.t_st = p:install_read_tap(0x300080, 0x300081, "ms_st", function(off, data, mask)
  if not interne then compter("300081 REG_SYSTYPE") end
end)

-- L'en-tête de cartouche lu par le BIOS : une ligne par lecture, au plus 64 par trame (au-delà,
-- un résumé). À $000108, le slot que désigne le NGH lu — la valeur n'est écrite que si elle ne
-- désigne aucune cartouche montée, c'est-à-dire ce que MAME rend pour un emplacement vide.
-- Les lectures de la cartouche elle-même ne sont que comptées.
local ent_tampon, ent_n, ent_jeu, ent_jeu_avant = {}, 0, 0, 0
G.t_ent = p:install_read_tap(0x000100, 0x00013F, "ms_ent", function(off, data, mask)
  if interne then return end
  if cote() ~= "bios" then ent_jeu = ent_jeu + 1 return end
  ent_n = ent_n + 1
  local note = "en-tete lu par bios"
  if off == 0x108 then
    local mot = data & 0xFFFF
    local sl = slot_de(mot)
    note = note .. ", NGH du slot " .. sl .. (sl == "aucun" and string.format(" (mot %04X)", mot) or "")
  elseif off == 0x122 then
    note = string.format("entree USER lue, demande=%02X mode=%02X", p:read_u8(0x10FDAE), p:read_u8(0x10FDAF))
    G.pl_fermer = true
    if CAPT_USER and #G.capt_prevues < 60 then
      G.capt_prevues[#G.capt_prevues + 1] = trame + CAPT_USER
      images[trame + CAPT_USER] = true
    end
  end
  if ent_n <= 64 then ent_tampon[#ent_tampon + 1] = { trame, fraction(), off, reg_slot, note } end
end)

-- MS_SONDE_PROM=1 : toute lecture de $000000-$0FFFFF faite PAR LE BIOS, résumée par trame en
-- plages de 256 octets. Coûteux, le tap voyant chaque lecture du jeu : pour une passe courte.
local prom = {}
if os.getenv("MS_SONDE_PROM") == "1" then
  G.t_prom = p:install_read_tap(0x000000, 0x0FFFFF, "ms_prom", function(off, data, mask)
    if interne or cote() ~= "bios" then return end
    local k = off >> 8
    prom[k] = (prom[k] or 0) + 1
  end)
end

-- MS_DETAIL=<de>-<a> : pendant ces trames, chaque lecture faite par le BIOS hors de sa ROM et de
-- la RAM de travail (P-ROM, zone banquée, registres, palette, carte mémoire, backup RAM), une
-- ligne par lecture, adresse seule. Pour voir ce que le BIOS interroge autour d'un geste.
local det_de, det_a = (os.getenv("MS_DETAIL") or ""):match("^(%d+)-(%d+)$")
det_de, det_a = tonumber(det_de), tonumber(det_a)
if det_de then
  local function tap_detail(debut, fin)
    return p:install_read_tap(debut, fin, "ms_det", function(off, data, mask)
      if interne or trame < det_de or trame > det_a or cote() ~= "bios" then return end
      local note = "lu par bios (detail)"
      if off == 0x108 then note = note .. ", NGH du slot " .. slot_de(data & 0xFFFF) end
      ligne("R", string.format("%06X", off), "-", note)
    end)
  end
  G.d1 = tap_detail(0x000000, 0x0FFFFF)
  G.d2 = tap_detail(0x200000, 0x3FFFFF)
  G.d3 = tap_detail(0x400000, 0xBFFFFF)
  G.d4 = tap_detail(0xD00000, 0xD0FFFF)
end

-- UN CHANGEMENT DE SLOT EFFACE LES TAPS DE LA CARTOUCHE. MAME réinstalle les gestionnaires de
-- $000000-$0FFFFF et de la zone banquée sur le slot choisi, et ce faisant écrase les taps posés
-- dessus : mesuré, aucune lecture d'en-tête n'était plus vue après la première écriture de
-- REG_SLOT, alors que la backup RAM recevait le NGH du slot suivant. Le tap de REG_SLOT ne peut
-- pas les reposer lui-même (il passe AVANT l'écriture) : il lève un drapeau, et le tap posé sur
-- la ROM du BIOS les réinstalle à la deuxième lecture qui suit — la première peut être le
-- préchargement de l'instruction suivante, fait avant l'écriture. Ce tap ne relève RIEN : il ne
-- sert que de signal, et ni l'adresse ni la valeur qu'il voit ne sortent du jig.
local function retaper()
  G.retaper = false
  for _, k in ipairs({ "t_ent", "t_prom", "d1", "d2" }) do if G[k] then G[k]:reinstall() end end
end
-- Avec MS_PLAGES, chaque entrée de SYSTEM_RETURN sort aussi une ligne E « C00444 » (point
-- d'entrée public) portant le code que le jeu laisse dans BIOS_SYSRET_STATUS ($10FD81, RAM) :
-- une par trame au plus, le préchargement pouvant relire l'adresse.
G.t_signal = p:install_read_tap(0xC00000, 0xC1FFFF, "ms_signal", function(off)
  if off == 0xC00444 and G.pl_ecouter then
    if os.getenv("MS_PLAGES") == "1" and G.sysret_trame ~= trame then
      G.sysret_trame = trame
      interne = true
      local code = p:read_u8(0x10FD81)
      interne = false
      ligne("E", "C00444", string.format("%02X", code), "SYSTEM_RETURN, code laisse par le jeu")
    end
    G.pl_ecouter(true) G.pl_fermer = false
  end
  if not G.retaper then return end
  G.attente = G.attente - 1
  if G.attente <= 0 then retaper() end
end)

-- MS_PLAGES=1 : LES SAUVEGARDES DE JEU. Ce que le BIOS lit et écrit, par trame, en plages
-- contiguës d'octets : dans la backup RAM dès $D00320, où commence la première sauvegarde
-- (mesuré ; ses écritures sous $D00400 sortent aussi ligne à ligne), et dans la RAM de travail du
-- jeu $100000-$10F2FF, lectures et écritures. Une ligne « P » par plage : début et fin, nombre
-- d'accès, et pour une écriture la somme sur 16 bits des octets écrits — de quoi dire qu'une
-- recopie emporte ce qu'elle a lu, sans sortir un octet. Les valeurs sont celles du
-- jeu (sa RAM, sa sauvegarde), jamais un octet de la ROM du BIOS (`docs/DECISIONS.md` §8).
-- La RAM de travail n'est écoutée que pendant que le BIOS a la main : du boot à la première
-- remise ($000122 lue par le BIOS), puis de chaque entrée de SYSTEM_RETURN ($C00444, point
-- d'entrée public, vu par le tap-signal plus bas et non relevé) à la remise suivante — sinon
-- chaque accès du jeu passerait par lua. Une remise ferme l'écoute à la fin de sa trame.
local PLAGES = os.getenv("MS_PLAGES") == "1"
local pl = { bw = {}, br = {}, rw = {}, rr = {} }   -- adresse → compte ; bw/rw : et somme
local pl_somme = { bw = {}, rw = {} }
local function pl_note(t, a, v)
  pl[t][a] = (pl[t][a] or 0) + 1
  if v and pl_somme[t] then pl_somme[t][a] = ((pl_somme[t][a] or 0) + v) & 0xFFFF end
end
local function pl_vider()
  local NOMS_PL = { bw = "BRAM ecrite par bios", br = "BRAM lue par bios",
    rw = "RAM de travail ecrite par bios", rr = "RAM de travail lue par bios" }
  for _, t in ipairs({ "br", "bw", "rr", "rw" }) do
    local as = {} for a in pairs(pl[t]) do as[#as + 1] = a end table.sort(as)
    local i = 1
    while i <= #as do
      local j, n, s = i, 0, 0
      while j + 1 <= #as and as[j + 1] == as[j] + 1 do j = j + 1 end
      for k = i, j do
        n = n + pl[t][as[k]]
        if pl_somme[t] then s = (s + pl_somme[t][as[k]]) & 0xFFFF end
      end
      ligne("P", string.format("%06X-%06X", as[i], as[j]), "n=" .. n,
        NOMS_PL[t] .. string.format(", %d octets", as[j] - as[i] + 1) ..
        (pl_somme[t] and string.format(", somme %04X", s) or ""))
      i = j + 1
    end
  end
  pl = { bw = {}, br = {}, rw = {}, rr = {} }
  pl_somme = { bw = {}, rw = {} }
end
local function pl_ecouter(oui)
  if not PLAGES then return end
  if oui and not G.t_rr then
    G.t_rr = p:install_read_tap(0x100000, 0x10F2FF, "ms_rr", function(off, data, mask)
      if interne or cote() ~= "bios" then return end
      octets(off, data, mask, function(a) pl_note("rr", a) end)
    end)
    G.t_rw = p:install_write_tap(0x100000, 0x10F2FF, "ms_rw", function(off, data, mask)
      if interne or cote() ~= "bios" then return end
      octets(off, data, mask, function(a, v) pl_note("rw", a, v) end)
    end)
  elseif not oui and G.t_rr then
    G.t_rr:remove() G.t_rw:remove() G.t_rr, G.t_rw = nil, nil
  end
end
G.pl_ecouter = pl_ecouter
if PLAGES then
  pl_ecouter(true)
  G.t_br = p:install_read_tap(0xD00320, 0xD0FFFF, "ms_br", function(off, data, mask)
    if interne or cote() ~= "bios" then return end
    octets(off, data, mask, function(a) pl_note("br", a) end)
  end)
end

-- Backup RAM. Le plafond seul, pas le filtre des réécritures à l'identique : une réécriture y est
-- un fait (le relevé du 2026-10-16 en montre une), et le test mémoire du premier boot laisse
-- dans chaque octet une valeur qu'une écriture utile peut répéter — filtrée, elle disparaîtrait
-- (mesuré : $D00047 manquait au relevé). Les compteurs réécrits à chaque trame atteignent le
-- plafond en quelques secondes, et leur compte sort au bilan.
-- Le tampon de la trame sort ligne à ligne, sauf un remplissage, résumé en une ligne : plus de
-- REMPLI écritures dans la trame (le test mémoire en fait 1 024, le
-- premier boot de la référence avec quatre cartouches ~250). Deux zones sortent quand même ligne
-- à ligne, c'en est l'objet : $D00040-$D0005F (nombre de slots, drapeau du logo) et
-- $D00100-$D001FF (date, slot choisi, comptabilité, table des slots et ce qui la suit).
local REMPLI = 400
local function utile(a) return (a >= 0xD00040 and a <= 0xD0005F) or (a >= 0xD00100 and a <= 0xD001FF) end
local bram_n, bram_vals, bram_hors, bram_tampon = 0, {}, 0, {}
G.t_bram = p:install_write_tap(0xD00000, 0xD0FFFF, "ms_bram", function(off, data, mask)
  if interne then return end
  octets(off, data, mask, function(a, v)
    if a > 0xD003FF then
      bram_hors = bram_hors + 1
      if PLAGES and cote() == "bios" then pl_note("bw", a, v) end
      return
    end
    if PLAGES and a >= 0xD00320 and cote() == "bios" then pl_note("bw", a, v) end
    if not plafond(a) then return end
    bram_n = bram_n + 1
    bram_vals[v] = true
    if bram_n <= REMPLI or utile(a) then
      bram_tampon[#bram_tampon + 1] = { trame, fraction(), a, v, reg_slot, cote() }
    end
  end)
end)

-- Variables du BIOS : une ligne quand la valeur change pour un écrivain donné.
local SUIVIES = { [0x10FCEF] = "BIOS_SLOTCHECK", [0x10FD80] = "BIOS_SYSTEM_MODE",
  [0x10FD81] = "BIOS_SYSRET_STATUS", [0x10FD82] = "BIOS_MVS_FLAG", [0x10FD83] = "BIOS_COUNTRY_CODE",
  [0x10FDAE] = "BIOS_USER_REQUEST", [0x10FDAF] = "BIOS_USER_MODE", [0x10FEE1] = "BIOS_FRAME_SKIP" }
local dernier = {}
local function tap_var(debut, fin)
  return p:install_write_tap(debut, fin, "ms_var", function(off, data, mask)
    if interne then return end
    octets(off, data, mask, function(a, v)
      if not SUIVIES[a] then return end
      local qui = cote()
      -- LA MAIN REPRISE SANS SYSTEM_RETURN. Mesuré (référence, le 2026-10-22) : à SELECT, le
      -- BIOS écrit BIOS_SYSRET_STATUS ← $04 ou $05 et reprend la main sans que le jeu entre
      -- par $C00444 (la pièce, $06, fait de même ; elle n'est pas ouverte ici, pour que les
      -- relevés des lots d'avant se rejouent à l'identique). MS_PLAGES ouvre donc aussi
      -- l'écoute de la RAM de travail sur ces deux écritures, sans quoi la sauvegarde du jeu
      -- sortant n'y paraîtrait que du côté de la backup RAM.
      if a == 0x10FD81 and qui == "bios" and (v == 4 or v == 5) and G.pl_ecouter then
        G.pl_ecouter(true) G.pl_fermer = false
      end
      if dernier[a .. qui] ~= v then
        dernier[a .. qui] = v
        ligne("W", string.format("%06X", a), string.format("%02X", v), SUIVIES[a] .. " par " .. qui)
      end
    end)
  end)
end
G.t_v1 = tap_var(0x10FCEE, 0x10FCEF)
G.t_v2 = tap_var(0x10FD80, 0x10FD83)
G.t_v3 = tap_var(0x10FDAE, 0x10FDAF)
G.t_v4 = tap_var(0x10FEE0, 0x10FEE1)

-- Entrées.
local function F(pt, n) local x = m.ioport.ports[pt] return x and x.fields[n] end
local CHAMPS = {
  piece = F(":AUDIO_COIN", "Coin 1"), start = F(":edge:joy:START", "1 Player Start"),
  start2 = F(":edge:joy:START", "2 Players Start"), suivant = F(":SYSTEM", "Next Game"),
  precedent = F(":SYSTEM", "Previous Game"), a = F(":edge:joy:JOY1", "P1 A"),
  test = F(":TEST", "Service Mode"),
}
local plan = {}
for de, nom, duree in (os.getenv("MS_ENTREES") or ""):gmatch("(%d+):(%a+):?(%d*)") do
  if not CHAMPS[nom] then print("MULTISLOT: entrée inconnue " .. nom) m:exit() return end
  plan[#plan + 1] = { de = tonumber(de), a = tonumber(de) + (tonumber(duree) or 8), nom = nom }
end

local function vider_trame()
  local cles = {} for k in pairs(lect) do cles[#cles + 1] = k end
  for k in pairs(lect_avant) do if not lect[k] then cles[#cles + 1] = k end end
  table.sort(cles)
  for _, k in ipairs(cles) do
    if lect[k] ~= lect_avant[k] then
      local a, nom = k:match("^(%S+) (.*)$")
      ligne("R", a, "n=" .. (lect[k] or 0), nom .. ", lectures par trame")
    end
  end
  lect_avant, lect = lect, {}
  if son_lect > 0 then ligne("R", "320000", "n=" .. son_lect, "REG_SOUND lu, dont $01 x" .. son_echo) end
  son_lect, son_echo = 0, 0

  if ent_n <= 64 then
    for _, e in ipairs(ent_tampon) do
      f:write(string.format("%d\t%.2f\tR\t%06X\t-\t%s\t%s\n", e[1], e[2], e[3], e[4], e[5]))
    end
  else
    ligne("R", "000100-00013F", "n=" .. ent_n, "en-tete lu par bios, resume")
  end
  if ent_jeu ~= ent_jeu_avant then
    ligne("R", "000100-00013F", "n=" .. ent_jeu, "en-tete lu par jeu, lectures par trame")
  end
  ent_jeu_avant, ent_tampon, ent_n, ent_jeu = ent_jeu, {}, 0, 0

  local ks = {} for k in pairs(prom) do ks[#ks + 1] = k end table.sort(ks)
  for _, k in ipairs(ks) do
    ligne("R", string.format("%06X-%06X", k << 8, (k << 8) + 0xFF), "n=" .. prom[k], "P-ROM lue par bios")
  end
  prom = {}

  -- LE GARDE DE §8. Une valeur écrite en backup RAM peut être une adresse de la ROM du BIOS
  -- (un pointeur sauvegardé). Dans la trame, un octet $C0 ou $C1 suivi de deux octets écrits aux
  -- adresses suivantes forme une valeur de $C00000-$C1FFFF : ces trois octets, et l'octet fort
  -- qui les précède s'il a été écrit, sortent « retenu ». Grossier exprès — mesuré, il retient
  -- surtout $D00020-$D00022, réécrits à chaque trame, qui ne sont peut-être que des bits d'état.
  local vu, retenu = {}, {}
  for _, e in ipairs(bram_tampon) do vu[e[3]] = e[4] end
  for a, v in pairs(vu) do
    if (v == 0xC0 or v == 0xC1) and vu[a + 1] and vu[a + 2] then
      retenu[a], retenu[a + 1], retenu[a + 2] = true, true, true
      if vu[a - 1] then retenu[a - 1] = true end
    end
  end
  for _, e in ipairs(bram_tampon) do
    if bram_n <= REMPLI or utile(e[3]) then
      local v = retenu[e[3]] and "retenu" or string.format("%02X", e[4])
      f:write(string.format("%d\t%.2f\tW\t%06X\t%s\t%s\tBRAM par %s\n", e[1], e[2], e[3], v, e[5], e[6]))
    end
  end
  if bram_n > REMPLI then
    local vs = {} for v in pairs(bram_vals) do vs[#vs + 1] = string.format("%02X", v) end table.sort(vs)
    ligne("W", "D00000-D003FF", "n=" .. bram_n, "BRAM resume (hors D00100-D001FF, ligne a ligne), valeurs " ..
      table.concat(vs, " ", 1, math.min(#vs, 8)) .. (#vs > 8 and " ..." or ""))
  end
  if bram_hors > 0 then ligne("W", "D00400-D0FFFF", "n=" .. bram_hors, "BRAM hors table") end
  if PLAGES then
    pl_vider()
    if G.pl_fermer then pl_ecouter(false) G.pl_fermer = false end
  end
  bram_n, bram_vals, bram_hors, bram_tampon = 0, {}, 0, {}
end

-- MS_LECT_JEU=1 : chaque lecture de $D00000-$D003FF dont le PC est hors de la ROM du BIOS, comptée
-- par octet lu. Rien n'est écrit qu'au bilan : l'adresse et le compte, jamais la valeur.
local lect_jeu = {}
if os.getenv("MS_LECT_JEU") == "1" then
  G.t_ljeu = p:install_read_tap(0xD00000, 0xD003FF, "ms_ljeu", function(off, data, mask)
    if interne or cote() ~= "jeu" then return end
    octets(off, data, mask, function(a) lect_jeu[a] = (lect_jeu[a] or 0) + 1 end)
  end)
end

local function bilan()
  local ls = {} for a in pairs(lect_jeu) do ls[#ls + 1] = a end table.sort(ls)
  for _, a in ipairs(ls) do
    ligne("R", string.format("%06X", a), "n=" .. lect_jeu[a], "BRAM lue par jeu, sur le run")
  end
  local as = {} for a in pairs(n_lig) do as[#as + 1] = a end table.sort(as)
  for _, a in ipairs(as) do
    if tues[a] or ident[a] then
      ligne("B", string.format("%06X", a), "-", string.format("lignes=%d tues=%d identiques=%d",
        math.min(n_lig[a], PLAFOND), tues[a] or 0, ident[a] or 0))
    end
  end
end

-- MS_VIDAGES=<trame>,<trame>… : en fin de ces trames, la zone de sauvegarde du jeu servi
-- (pointeur $00010E et taille $000112 de l'en-tête de sa cartouche) et son bloc de backup RAM
-- ($D00320 + $1000 × l'index de bloc de son entrée de $D00124), en hexadécimal, dans
-- MS_DIR/zone-fNNNNN.hex. Ce sont des octets du JEU (sa RAM, sa sauvegarde), jamais de la ROM
-- du BIOS (`docs/DECISIONS.md` §8) : de quoi voir un score retrouvé d'un boot à l'autre.
local vidages = {}
for n in (os.getenv("MS_VIDAGES") or ""):gmatch("%d+") do vidages[tonumber(n)] = true end
local function vider_zone()
  interne = true
  local zone = p:read_u32(0x10E)
  local taille = p:read_u16(0x112)
  local slot = p:read_u8(0xD00108)
  local bloc = p:read_u16(0xD00124 + 4 * (slot & 7) + 2)
  local function hex(base, n)
    local t = {}
    for i = 0, n - 1 do t[#t + 1] = string.format("%02X", p:read_u8(base + i)) end
    return table.concat(t)
  end
  local g = io.open(string.format("%s/zone-f%05d.hex", DIR, trame), "w")
  g:write(string.format("trame %d slot %d bloc %04X zone %06X taille %04X\n", trame, slot, bloc, zone, taille))
  if taille > 0 and taille <= 0x1000 then
    g:write("ram " .. hex(zone, taille) .. "\n")
    if bloc < 8 then g:write("bram " .. hex(0xD00320 + 0x1000 * bloc, taille) .. "\n") end
  end
  g:close()
  interne = false
  ligne("E", "-", "-", string.format("vidage zone-f%05d", trame))
end

-- MS_POSER=<trame>@<adresse>=<octets hex>,… : en fin de ces trames, écrit ces octets dans la RAM
-- de travail du JEU ($100000-$10F2FF seulement) — un score posé dans sa zone de sauvegarde, pour
-- voir si le BIOS l'emporte d'un boot à l'autre. Le seul geste du jig qui touche la machine.
local poses = {}
for t, a, h in (os.getenv("MS_POSER") or ""):gmatch("(%d+)@(%x+)=(%x+)") do
  poses[#poses + 1] = { t = tonumber(t), a = tonumber(a, 16), h = h }
end
local function poser()
  for _, e in ipairs(poses) do
    if e.t == trame and e.a >= 0x100000 and e.a + #e.h // 2 - 1 <= 0x10F2FF then
      interne = true
      for i = 0, #e.h // 2 - 1 do p:write_u8(e.a + i, tonumber(e.h:sub(2 * i + 1, 2 * i + 2), 16)) end
      interne = false
      ligne("E", string.format("%06X", e.a), e.h, "pose dans la RAM du jeu (MS_POSER)")
    end
  end
end

-- MS_SUIVRE=<adresse>,… : la valeur de ces octets en fin de trame, une ligne E quand elle change.
-- Des valeurs de RAM et de backup RAM, lues par le jig hors des taps ; jamais la ROM du BIOS
-- (`docs/DECISIONS.md` §8) : une adresse hors des deux zones est ignorée.
local suivies, suivi_avant = {}, {}
for h in (os.getenv("MS_SUIVRE") or ""):gmatch("%x+") do
  local a = tonumber(h, 16)
  if (a >= 0x100000 and a <= 0x10FFFF) or (a >= 0xD00000 and a <= 0xD0FFFF) then suivies[#suivies + 1] = a end
end
local function suivre()
  if #suivies == 0 then return end
  interne = true
  for _, a in ipairs(suivies) do
    local v = p:read_u8(a)
    if v ~= suivi_avant[a] then
      suivi_avant[a] = v
      ligne("E", string.format("%06X", a), string.format("%02X", v), "valeur en fin de trame (MS_SUIVRE)")
    end
  end
  interne = false
end

local main_a, slot_mappe = nil, nil
emu.register_frame_done(function()
  if G.retaper then retaper() end
  sonde_m1("la fin de trame")
  vider_trame()

  -- L'état en fin de trame : qui a la main, quel slot MAME sert.
  local c = cote()
  if c ~= main_a then main_a = c ligne("E", "-", c, "main") end
  interne = true
  local s = slot_de(p:read_u16(0x108))
  interne = false
  if s ~= slot_mappe then slot_mappe = s ligne("E", "000108", s, "slot dont MAME sert la P-ROM") end

  suivre()
  poser()
  if vidages[trame] then vider_zone() end
  if images[trame] then
    local px = ecran:pixels()
    local g = io.open(string.format("%s/f%05d.bin", DIR, trame), "wb") g:write(px) g:close()
    ligne("E", "-", "-", string.format("capture f%05d", trame))
  end
  f:flush()

  t0 = m.time:as_double()
  trame = trame + 1
  for _, e in ipairs(plan) do
    if trame == e.de then CHAMPS[e.nom]:set_value(1) ligne("I", "-", e.nom, "presse") end
    if trame == e.a then CHAMPS[e.nom]:set_value(0) end
  end
  if trame > FIN then bilan() f:close() m:exit() end
end)
