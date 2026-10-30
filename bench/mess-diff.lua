-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- MESS_OUT differential. For each call of $C004CE made while the game is in control
-- ($10FD80 bit 7), from frame DE to A: INPUT = the data reads outside BIOS RAM
-- ($10F000-$10FEFF excluded: stack and variables) and outside BIOS ROM; OUTPUT = the LSPC writes
-- ($3C0000-$3C000F) and BIOS RAM writes ($10FD80-$10FFFF except $10FEC6-$10FEC9). One line per
-- call: "E <entrée>\tS <sortie>". The PC is read only to locate the side (BIOS or game) and the
-- return from the call; this jig logs none.
--   Y_DE=1 Y_A=2500 Y_OUT=<sortie.txt> mame b2b -bios euro -rompath <roms> -video none \
--     -sound none -nothrottle -seconds_to_run 60 -nvram_directory <vide> -autoboot_script bench/mess-diff.lua
-- Comparing two outputs: the same E line must give the same S line.
if not _G.Y then _G.Y={n=0,on=false,e={},s={},nb=0}
local cpu=manager.machine.devices[":maincpu"]; local p=cpu.spaces["program"]
local DE,A=tonumber(os.getenv("Y_DE")),tonumber(os.getenv("Y_A"))
local f=io.open(os.getenv("Y_OUT"),"w")
local function pc() return cpu.state["PC"].value end
Y.t1=p:install_read_tap(0xC004CE,0xC004CF,"e",function(o) if o==0xC004CE and not Y.on and Y.n>=DE and (p:read_u8(0x10FD80)&0x80)~=0 then Y.on=true Y.e={} Y.s={} end end)
local function lu(o,d)
  if not Y.on then return end
  if o<0xC00000 and o==pc() then Y.on=false Y.nb=Y.nb+1 f:write("E "..table.concat(Y.e," ").."\tS "..table.concat(Y.s," ").."\n") return end
  if pc()>=0xC00000 and not (o>=0x10F000 and o<0x10FF00) and #Y.e<4000 then Y.e[#Y.e+1]=string.format("%06X=%04X",o,d) end
end
Y.t2=p:install_read_tap(0x000000,0x2FFFFF,"r",lu)
Y.t3=p:install_write_tap(0x3C0000,0x3C000F,"v",function(o,d) if Y.on and #Y.s<8000 then Y.s[#Y.s+1]=string.format("%06X=%04X",o,d) end end)
Y.t4=p:install_write_tap(0x10FD80,0x10FFFF,"m",function(o,d) if Y.on and not (o>=0x10FEC6 and o<=0x10FEC9) and #Y.s<8000 then Y.s[#Y.s+1]=string.format("%06X=%04X",o,d) end end)
-- input plan of the probe: coin, START, button A every 300 frames
local function F(pt,n) local x=manager.machine.ioport.ports[pt] return x and x.fields[n] end
local coin,start,ba=F(":AUDIO_COIN","Coin 1"),F(":edge:joy:START","1 Player Start"),F(":edge:joy:JOY1","P1 A")
emu.register_frame_done(function() Y.n=Y.n+1 local c=Y.n%300
  if coin then coin:set_value((c<8) and 1 or 0) end if start then start:set_value((c>=100 and c<108) and 1 or 0) end if ba then ba:set_value((c>=200 and c<208) and 1 or 0) end
  if Y.n==A then f:close() print("APPELS "..Y.nb) manager.machine:exit() end end) end
