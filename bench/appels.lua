-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- Counts the game's REAL calls to the entries of the BIOS call table ($C00438-$C006FC),
-- windowless. Under MAME, a `jsr` reads the first word of the target THEN pushes the return
-- address (measured on 2026-10-19 on b2b): a read at an entry address is counted only if the
-- next access on the bus is a write to work RAM. The prefetch, which reads the neighbouring
-- entries without pushing anything, is thus set aside (without this filter, unused entries come
-- out with 2 to 4 reads per game).
-- A call through `jmp` (SYSTEM_RETURN) pushes nothing and is therefore NOT counted. Only the
-- calls made while the game is in control ($10FD80 bit 7) count. Input plan of the probe.
--   A_A=3000 A_OUT=<sortie> mame <jeu> -bios euro ... -autoboot_script bench/appels.lua
-- Output: a line "<jeu> <entrée>:<appels> ..." appended to A_OUT.
if not _G.Y then _G.Y={n=0,c={},e=nil}
local m=manager.machine; local cpu=m.devices[":maincpu"]; local p=cpu.spaces["program"]
Y.tw=p:install_write_tap(0x100000,0x10FFFF,"w",function() if Y.e then Y.c[Y.e]=(Y.c[Y.e] or 0)+1 Y.e=nil end end)
Y.tr=p:install_read_tap(0x100000,0x10FFFF,"r",function() Y.e=nil end)
Y.tp=p:install_read_tap(0x000000,0x0FFFFF,"p",function() Y.e=nil end)
Y.tb=p:install_read_tap(0xC00000,0xC1FFFF,"b",function(o)
  if o>=0xC00438 and o<=0xC006FC and (o-0xC00438)%6==0 and (p:read_u8(0x10FD80)&0x80)~=0 then Y.e=o else Y.e=nil end end)
local function F(pt,n) local x=m.ioport.ports[pt] return x and x.fields[n] end
local coin,start,ba=F(":AUDIO_COIN","Coin 1"),F(":edge:joy:START","1 Player Start"),F(":edge:joy:JOY1","P1 A")
emu.register_frame_done(function() Y.n=Y.n+1 local c=Y.n%300
  if coin then coin:set_value((c<8) and 1 or 0) end
  if start then start:set_value((c>=100 and c<108) and 1 or 0) end
  if ba then ba:set_value((c>=200 and c<208) and 1 or 0) end
  if Y.n==tonumber(os.getenv("A_A")) then
    local ks={} for k in pairs(Y.c) do ks[#ks+1]=k end table.sort(ks)
    local s=m.system.name for _,k in ipairs(ks) do s=s..string.format(" %06X:%d",k,Y.c[k]) end
    local f=io.open(os.getenv("A_OUT"),"a") f:write(s.."\n") f:close() m:exit() end end) end
