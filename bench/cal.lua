-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- READ_CALENDAR : pour chaque vrai appel à $C0045C (lecture d'entrée suivie d'une écriture en RAM
-- de travail, comme `appels.lua`), relève les accès à l'horloge — écritures à $380050-$380051
-- (REG_RTCCTRL), lectures à $320000-$320001 (REG_STATUS_A) — et les écritures en RAM hors pile
-- du BIOS ($10F200-$10F2FF, exclue : adresses de la référence), jusqu'au retour en espace
-- programme. Une lecture en espace programme au milieu d'un appel (une interruption,
-- supposé) ferme la fenêtre avant sa fin : l'appel sort alors tronqué. Hors appel, les écritures à l'horloge sont gardées en une chaîne (le boot).
-- Écrit aussi le plus petit écart entre deux écritures à l'horloge pendant un appel.
--   A_A=<trames> A_MAX=<appels détaillés> A_OUT=<sortie> mame <jeu> -bios euro ... \
--   -autoboot_script bench/cal.lua
if not _G.Y then _G.Y={n=0,e=nil,in_=false,k=0,hors={w=0,r=0}}
local m=manager.machine; local cpu=m.devices[":maincpu"]; local p=cpu.spaces["program"]
local out=io.open(os.getenv("A_OUT"),"a")
local MAX=tonumber(os.getenv("A_MAX") or "3")
local function log(s) if Y.k<=MAX then Y.w[#Y.w+1]=s end end
Y.tw=p:install_write_tap(0x100000,0x10FFFF,"w",function(o,d,mk)
  if Y.e then Y.e=nil Y.in_=true Y.k=Y.k+1 Y.w={} Y.nw=0 Y.nr=0 Y.ram={} return end
  if Y.in_ and not (o>=0x10F200 and o<=0x10F2FF) then Y.ram[#Y.ram+1]=string.format("%06X=%04X/%04X",o,d,mk) end end)
Y.tx=p:install_write_tap(0x380050,0x380051,"x",function(o,d,mk)
  local t=manager.machine.time:as_double()
  if Y.lt then local dt=(t-Y.lt)*1e6 if Y.in_ then if not Y.mindt or dt<Y.mindt then Y.mindt=dt end end end Y.lt=t
  if Y.in_ then Y.nw=Y.nw+1 log(string.format("W%04X/%04X",d,mk)) else Y.hors.w=Y.hors.w+1
    Y.hs=(Y.hs or "")..string.format("%X",d&0xff) Y.hf=Y.hf or Y.n end end)
Y.ty=p:install_read_tap(0x320000,0x320001,"y",function(o,d,mk)
  if Y.in_ then Y.nr=Y.nr+1 log(string.format("R%04X/%04X",d,mk)) else Y.hors.r=Y.hors.r+1 end end)
Y.tr=p:install_read_tap(0x100000,0x10FFFF,"r",function() Y.e=nil end)
Y.tp=p:install_read_tap(0x000000,0x0FFFFF,"p",function()
  Y.e=nil
  if Y.in_ then Y.in_=false
    out:write(string.format("%s f%d appel%d horloge W=%d R=%d ram: %s\n",m.system.name,Y.n,Y.k,Y.nw,Y.nr,table.concat(Y.ram," ")))
    if Y.k<=MAX then out:write("  seq: "..table.concat(Y.w," ").."\n") end out:flush() end end)
Y.tb=p:install_read_tap(0xC00000,0xC1FFFF,"b",function(o)
  if o==0xC0045C and (p:read_u8(0x10FD80)&0x80)~=0 then Y.e=o elseif not Y.in_ then Y.e=nil end end)
local function F(pt,n) local x=m.ioport.ports[pt] return x and x.fields[n] end
local coin,start,ba=F(":AUDIO_COIN","Coin 1"),F(":edge:joy:START","1 Player Start"),F(":edge:joy:JOY1","P1 A")
emu.register_frame_done(function() Y.n=Y.n+1 local c=Y.n%300
  if coin then coin:set_value((c<8) and 1 or 0) end
  if start then start:set_value((c>=100 and c<108) and 1 or 0) end
  if ba then ba:set_value((c>=200 and c<208) and 1 or 0) end
  if Y.n==tonumber(os.getenv("A_A")) then
    if Y.hs then out:write("hors appel des f"..Y.hf.." : "..Y.hs.."\n") end
    out:write(string.format("dt min entre ecritures horloge, en appel : %.3f us\n",Y.mindt or -1))
    out:write(string.format("%s fin, appels=%d, horloge hors appel W=%d R=%d\n",m.system.name,Y.k,Y.hors.w,Y.hors.r)) out:close() m:exit() end end) end
