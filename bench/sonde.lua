-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- MAME diagnostic probe: the 68000's PC and chosen RAM addresses, at each frame.
--
-- It is the co-simulator's view (unpublished) carried into the real MAME — real Z80, YM2610
-- and M1 included. It exists because the bench MASKS sound-related freezes (it forces the Z80's
-- answers, measured on `wjammers`: alive on the bench, frozen under MAME): diagnosing these
-- freezes has no other instrument than MAME itself.
--
-- Settings through the environment, since an autoboot lua receives no arguments:
--   SONDE_OUT   output TSV file (mandatory)
--   SONDE_RAM   addresses to read as a byte at each frame, hexadecimal, separated by
--               commas (e.g. "10FD80,10FDAE,10005A"); empty = none
--   SONDE_DE    first recorded frame (default 0)
--   SONDE_A     last recorded frame (default 3500); the machine stops right after
--
-- The input plan is THE MATRIX'S (bios-probe.lua): coin, start and button A on three disjoint
-- slots of a 300-frame cycle — never coin and start together, which open UniBIOS's in-game
-- menu. Same plan so that both instruments measure the same scenario (the frame of a freeze
-- then compares from one record to the other).
--
-- The PC is read once per frame, at vblank: it is coarse on purpose — a wait loop that holds
-- whole frames leaves its address there on each line, and that is what we are looking for.
-- Code that only passes through does not show there; that is not the point.
local OUT = os.getenv("SONDE_OUT")
local RAM = os.getenv("SONDE_RAM") or ""
local DE  = tonumber(os.getenv("SONDE_DE") or "0")
local A   = tonumber(os.getenv("SONDE_A") or "3500")
if not OUT then print("SONDE: SONDE_OUT manquant") manager.machine:exit() return end

local adresses = {}
for jeton in RAM:gmatch("[^,]+") do
  local h = jeton:gsub("^%s+", ""):gsub("%s+$", "")
  h = h:match("^0[xX](%x+)$") or h   -- the 0x prefix drops; "0" alone stays a valid address
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
  f:flush()                     -- a MAME stop before SONDE_A then loses nothing written
end)
