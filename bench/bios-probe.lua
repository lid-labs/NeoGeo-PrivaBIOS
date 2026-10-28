-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- Sonde MAME de comparaison de BIOS Neo Geo, sans fenêtre (-video none).
--
-- Elle capture l'écran ET les variables du BIOS en RAM à des trames fixes. Les trames sont fixes
-- EXPRÈS : les BIOS ont des temps de boot très différents — une trame pour nullbios contre ~300
-- pour un dump SNK — et c'est justement un des écarts qu'on veut voir.
--
-- Réglages par l'environnement, un lua d'autoboot ne recevant pas d'arguments :
--   BIOS_OUT     dossier de sortie (obligatoire)
--   BIOS_SHOTS   trames où relever, séparées par des virgules
--   BIOS_IMAGES  trames où écrire l'image (défaut : toutes celles de BIOS_SHOTS)
--
-- Sous -video none, manager.machine.video:snapshot() ne produit AUCUN fichier, faute de rendu.
-- screen:pixels() est la seule voie sans fenêtre ; il rend TROIS valeurs (les octets, la largeur,
-- la hauteur), et les écrire toutes ajoute « 320224 » en ASCII à la fin de chaque capture.
local OUT = os.getenv("BIOS_OUT")
local SHOTS = os.getenv("BIOS_SHOTS") or "100,300,600,900,1200,1800,2400,3000,3500"
local IMAGES = os.getenv("BIOS_IMAGES") or SHOTS
if not OUT then print("BIOSPROBE: BIOS_OUT manquant") manager.machine:exit() return end

local shot, img = {}, {}
for n in SHOTS:gmatch("%d+") do shot[tonumber(n)] = true end
for n in IMAGES:gmatch("%d+") do img[tonumber(n)] = true end

local function F(p, n) local pt = manager.machine.ioport.ports[p]; return pt and pt.fields[n] end
local coin    = F(":AUDIO_COIN", "Coin 1")
local start   = F(":edge:joy:START", "1 Player Start")
local boutonA = F(":edge:joy:JOY1", "P1 A")
local ecran   = manager.machine.screens:at(1)

-- Signature SPATIALEMENT COMPLÈTE : chaque pixel y contribue. Une première version sommait un
-- octet sur 257 ; elle ratait les petits chiffres d'une minuterie et déclarait « figé » un jeu qui
-- tournait. Mesuré sur League Bowling : somme constante pendant que TIME passait de 06 à 00.
-- vifs compte les pixels allumés, et c'est lui qui distingue un écran noir d'une image.
local function resume(px)
  local h, vifs, n = 5381, 0, #px
  for i = 1, n, 4 do
    local b, g, r = px:byte(i), px:byte(i + 1), px:byte(i + 2)
    h = (h * 33 + b) % 2147483647
    h = (h * 33 + g) % 2147483647
    h = (h * 33 + r) % 2147483647
    if b + g + r > 24 then vifs = vifs + 1 end
  end
  return h, vifs
end

local index = io.open(OUT .. "/index.txt", "w")
local frame = 0

emu.register_frame_done(function()
  frame = frame + 1

  -- JAMAIS la pièce et le départ en même temps : START+COIN ouvre le menu in-game d'UniBIOS, et
  -- le banc mesure alors ce menu au lieu du jeu. Trois créneaux disjoints dans un cycle de 300
  -- trames : pièce, puis départ, puis A — certains BIOS attendent un bouton d'action à leur menu.
  local c = frame % 300
  if coin    then coin:set_value((c >= 0 and c < 8) and 1 or 0) end
  if start   then start:set_value((c >= 100 and c < 108) and 1 or 0) end
  if boutonA then boutonA:set_value((c >= 200 and c < 208) and 1 or 0) end

  if not shot[frame] then return end

  -- L'espace mémoire se relit à chaque relevé plutôt qu'au chargement : au boot d'un dump SNK, la
  -- RAM de travail porte successivement 0x55, 0xAA puis une valeur dérivée de son adresse — ce
  -- sont les trois motifs de son test mémoire, et ils ressemblent à s'y méprendre à du bus
  -- flottant. Les variables du BIOS ne sont lisibles qu'une fois ce test fini (vers la trame 300).
  local mem = manager.machine.devices[":maincpu"].spaces["program"]
  local px = ecran:pixels()
  if img[frame] then
    local f = io.open(string.format("%s/f%05d.bin", OUT, frame), "wb")
    f:write(px) f:close()
  end
  local som, vifs = resume(px)

  index:write(string.format(
    "frame=%d somme=%d vifs=%d sysmode=%02x mvsflag=%02x pays=%02x " ..
    "userreq=%02x usermode=%02x framecnt=%d " ..
    "p1stat=%02x p1prev=%02x p1cur=%02x p1chg=%02x p1rep=%02x p1tim=%02x " ..
    "statcur=%02x statchg=%02x slotchk=%02x z80chk=%02x\n",
    frame, som, vifs,
    mem:read_u8(0x10FD80), mem:read_u8(0x10FD82), mem:read_u8(0x10FD83),
    mem:read_u8(0x10FDAE), mem:read_u8(0x10FDAF), mem:read_u32(0x10FE88),
    mem:read_u8(0x10FD94), mem:read_u8(0x10FD95), mem:read_u8(0x10FD96),
    mem:read_u8(0x10FD97), mem:read_u8(0x10FD98), mem:read_u8(0x10FD99),
    mem:read_u8(0x10FDAC), mem:read_u8(0x10FDAD),
    mem:read_u8(0x10FCEF), mem:read_u8(0x10FCEE)))
  index:flush()
end)
