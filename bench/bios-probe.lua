-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- MAME probe for comparing Neo Geo BIOSes, windowless (-video none).
--
-- It captures the screen AND the BIOS variables in RAM at fixed frames. The frames are fixed ON
-- PURPOSE: BIOSes have very different boot times — one frame for nullbios against ~300 for an
-- SNK dump — and that is precisely one of the differences we want to see.
--
-- Settings through the environment, since an autoboot lua receives no arguments:
--   BIOS_OUT     output folder (mandatory)
--   BIOS_SHOTS   frames at which to record, separated by commas
--   BIOS_IMAGES  frames at which to write the picture (default: all those of BIOS_SHOTS)
--
-- Under -video none, manager.machine.video:snapshot() produces NO file, for lack of rendering.
-- screen:pixels() is the only windowless way; it returns THREE values (the bytes, the width, the
-- height), and writing them all appends "320224" in ASCII at the end of each capture.
local OUT = os.getenv("BIOS_OUT")
local SHOTS = os.getenv("BIOS_SHOTS") or "100,300,600,900,1200,1800,2400,3000,3500"
local IMAGES = os.getenv("BIOS_IMAGES") or SHOTS
if not OUT then print("BIOSPROBE: BIOS_OUT manquant") manager.machine:exit() return end

local shot, img = {}, {}
for n in SHOTS:gmatch("%d+") do shot[tonumber(n)] = true end
for n in IMAGES:gmatch("%d+") do img[tonumber(n)] = true end

local function F(p, n) local pt = manager.machine.ioport.ports[p]; return pt and pt.fields[n] end
-- vliner has no joystick port: MAME puts its coin in :IN5 and its panel in :DSW. Without these
-- fallbacks nothing reaches it and it stays on its GAME CONFIG screen, read as frozen under all
-- three BIOSes; Stop/Double Up leaves that screen. Its Bet/Small and Start/Collect wait for frame
-- 1000: on that screen Start opens a setting (measured), and every BIOS has left it by frame 900.
-- Without a bet Start changes nothing: 35 records identical, only the coins move the picture.
local coin    = F(":AUDIO_COIN", "Coin 1") or F(":IN5", "Coin 1")
local joyStart = F(":edge:joy:START", "1 Player Start")
local start   = joyStart or F(":DSW", "Start/Collect")
local mise    = F(":DSW", "Bet/Small")
local boutonA = F(":edge:joy:JOY1", "P1 A") or F(":DSW", "Stop/Double Up")
local ecran   = manager.machine.screens:at(1)

-- SPATIALLY COMPLETE signature: every pixel contributes to it. A first version summed one byte
-- in 257; it missed the small digits of a timer and declared "frozen" a game that was running.
-- Measured on League Bowling: constant sum while TIME went from 06 to 00.
-- vifs counts the lit pixels, and it is what tells a black screen from a picture.
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

  -- NEVER the coin and start at the same time: START+COIN opens UniBIOS's in-game menu, and the
  -- bench then measures that menu instead of the game. Three disjoint slots in a 300-frame
  -- cycle: coin, then start, then A — some BIOSes wait for an action button at their menu.
  local c = frame % 300
  if coin    then coin:set_value((c >= 0 and c < 8) and 1 or 0) end
  if start   then start:set_value((c >= 100 and c < 108 and (joyStart or frame >= 1000)) and 1 or 0) end
  if mise    then mise:set_value((c >= 50 and c < 58 and frame >= 1000) and 1 or 0) end
  if boutonA then boutonA:set_value((c >= 200 and c < 208) and 1 or 0) end

  if not shot[frame] then return end

  -- The memory space is reread at each record rather than at load: at the boot of an SNK dump,
  -- the work RAM successively holds 0x55, 0xAA then a value derived from its address — these
  -- are the three patterns of its memory test, and they look deceptively like a floating bus.
  -- The BIOS variables are only readable once that test is over (around frame 300).
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
