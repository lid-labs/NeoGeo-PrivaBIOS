-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- Sonde de diagnostic MAME : le PC du 68000 et des adresses de RAM choisies, à chaque trame.
--
-- C'est le regard du co-simulateur (non publié) porté dans le vrai MAME — Z80, YM2610 et M1 réels compris.
-- Elle existe parce que le banc MASQUE les gels liés au son (il force les réponses du Z80,
-- mesuré sur `wjammers` : vivant au banc, gelé sous MAME) : le diagnostic de ces gels n'a
-- pas d'autre instrument que MAME lui-même.
--
-- Réglages par l'environnement, un lua d'autoboot ne recevant pas d'arguments :
--   SONDE_OUT   fichier TSV de sortie (obligatoire)
--   SONDE_RAM   adresses à lire en octet à chaque trame, hexadécimal, séparées par des
--               virgules (ex. "10FD80,10FDAE,10005A") ; vide = aucune
--   SONDE_DE    première trame relevée (défaut 0)
--   SONDE_A     dernière trame relevée (défaut 3500) ; la machine s'arrête juste après
--
-- Le plan d'entrées est CELUI DE LA MATRICE (bios-probe.lua) : pièce, départ et bouton A sur
-- trois créneaux disjoints d'un cycle de 300 trames — jamais pièce et départ ensemble, qui
-- ouvrent le menu in-game d'UniBIOS. Même plan pour que les deux instruments mesurent le
-- même scénario (la trame d'un gel se compare alors d'un relevé à l'autre).
--
-- Le PC est lu une fois par trame, au vblank : c'est grossier exprès — une boucle d'attente
-- qui tient des trames entières y laisse son adresse à chaque ligne, et c'est elle qu'on
-- cherche. Un code qui ne fait que passer ne s'y voit pas ; ce n'est pas l'objet.
local OUT = os.getenv("SONDE_OUT")
local RAM = os.getenv("SONDE_RAM") or ""
local DE  = tonumber(os.getenv("SONDE_DE") or "0")
local A   = tonumber(os.getenv("SONDE_A") or "3500")
if not OUT then print("SONDE: SONDE_OUT manquant") manager.machine:exit() return end

local adresses = {}
for jeton in RAM:gmatch("[^,]+") do
  local h = jeton:gsub("^%s+", ""):gsub("%s+$", "")
  h = h:match("^0[xX](%x+)$") or h   -- le préfixe 0x tombe ; « 0 » seul reste une adresse valide
  if not h:match("^%x+$") then
    print("SONDE: adresse invalide dans SONDE_RAM : " .. jeton) manager.machine:exit() return
  end
  adresses[#adresses + 1] = tonumber(h, 16)
end

local cpu  = manager.machine.devices[":maincpu"]
local prog = cpu.spaces["program"]

local function F(p, n) local pt = manager.machine.ioport.ports[p]; return pt and pt.fields[n] end
local coin    = F(":AUDIO_COIN", "Coin 1")
local start   = F(":edge:joy:START", "1 Player Start")
local boutonA = F(":edge:joy:JOY1", "P1 A")

local f = io.open(OUT, "w")
local entete = "trame\tpc"
for _, a in ipairs(adresses) do entete = entete .. string.format("\t%06X", a) end
f:write(entete .. "\n")

local frame = 0
emu.register_frame_done(function()
  frame = frame + 1

  local c = frame % 300
  if coin    then coin:set_value((c >= 0 and c < 8) and 1 or 0) end
  if start   then start:set_value((c >= 100 and c < 108) and 1 or 0) end
  if boutonA then boutonA:set_value((c >= 200 and c < 208) and 1 or 0) end

  if frame < DE then return end
  if frame > A then f:close() manager.machine:exit() return end

  local ligne = string.format("%d\t%06X", frame, cpu.state["PC"].value & 0xFFFFFF)
  for _, a in ipairs(adresses) do
    ligne = ligne .. string.format("\t%02X", prog:read_u8(a))
  end
  f:write(ligne .. "\n")
  f:flush()                     -- un arrêt de MAME avant SONDE_A ne perd alors rien d'écrit
end)
