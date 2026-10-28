-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- CARD sans carte : pour chaque vrai appel à $C00468 (lecture d'entrée suivie d'une écriture en
-- RAM de travail, comme `appels.lua`), relève l'interface $10FDC4-$10FDCF avant l'appel, les
-- écritures faites jusqu'au retour en espace programme, avec le SP de chacune, et l'interface
-- après. La pile du BIOS ($10F200-$10F2FF) est exclue : elle porte des adresses de la référence.
-- Les accès à la zone de la carte ($800000-$8FFFFF) pendant l'appel sont comptés, lectures et
-- écritures, avec leur plage (« carte: »). Avec carte : ajouter -memc <fichier .neo>.
--   A_A=<trames> A_OUT=<sortie> mame <jeu> -bios euro ... -autoboot_script bench/card.lua
-- Juger notre image : la même commande sur un romset où elle est substituée ; les deux sorties
-- doivent porter les mêmes adresses écrites, dans le même ordre.
if not _G.Y then _G.Y={n=0,e=nil,in_=false,k=0}
local m=manager.machine; local cpu=m.devices[":maincpu"]; local p=cpu.spaces["program"]
local out=io.open(os.getenv("A_OUT"),"a")
local function iface() local t={} for a=0x10FDC4,0x10FDCF do t[#t+1]=string.format("%02X",p:read_u8(a)) end return table.concat(t," ") end
Y.tw=p:install_write_tap(0x100000,0x10FFFF,"w",function(o,d,mk)
  local ok,err=pcall(function()
  if Y.e then Y.e=nil Y.in_=true Y.k=Y.k+1 Y.w={} Y.cw=0 Y.cr=0 Y.cwmin=1e9 Y.cwmax=0 Y.crmin=1e9 Y.crmax=0
    out:write(string.format("%s f%d appel%d SP=%08X avant: %s\n",m.system.name,Y.n,Y.k,cpu.state["SP"].value,iface())) return end
  if Y.in_ and not (o>=0x10F200 and o<=0x10F2FF) then Y.w[#Y.w+1]=string.format("%06X=%04X/%04X@SP%08X",o,d,mk,cpu.state["SP"].value) end end)
  if not ok then out:write("ERR "..tostring(err).."\n") end end)
Y.tc=p:install_write_tap(0x800000,0x8FFFFF,"c",function(o,d) if Y.in_ then Y.cw=Y.cw+1 Y.cwmin=math.min(Y.cwmin,o) Y.cwmax=math.max(Y.cwmax,o) end end)
Y.tcr=p:install_read_tap(0x800000,0x8FFFFF,"cr",function(o,d) if Y.in_ then Y.cr=Y.cr+1 Y.crmin=math.min(Y.crmin,o) Y.crmax=math.max(Y.crmax,o) end end)
Y.tr=p:install_read_tap(0x100000,0x10FFFF,"r",function() Y.e=nil end)
Y.tp=p:install_read_tap(0x000000,0x0FFFFF,"p",function()
  Y.e=nil
  if Y.in_ then Y.in_=false
    out:write(string.format("  carte: lect=%d [%X-%X] ecr=%d [%X-%X]\n",Y.cr,Y.crmin,Y.crmax,Y.cw,Y.cwmin,Y.cwmax)) out:write("  ecritures: "..table.concat(Y.w," ").."\n  apres: "..iface().."\n") out:flush() end end)
Y.tb=p:install_read_tap(0xC00000,0xC1FFFF,"b",function(o)
  if o==0xC00468 and (p:read_u8(0x10FD80)&0x80)~=0 then Y.e=o elseif not Y.in_ then Y.e=nil end end)
local function F(pt,n) local x=m.ioport.ports[pt] return x and x.fields[n] end
local coin,start,ba=F(":AUDIO_COIN","Coin 1"),F(":edge:joy:START","1 Player Start"),F(":edge:joy:JOY1","P1 A")
-- A_SANS_ENTREES=1 : aucun appui injecté, pour une partie jouée à la main dans une fenêtre.
if os.getenv("A_SANS_ENTREES")=="1" then coin,start,ba=nil,nil,nil end
emu.register_frame_done(function() Y.n=Y.n+1 local c=Y.n%300
  if coin then coin:set_value((c<8) and 1 or 0) end
  if start then start:set_value((c>=100 and c<108) and 1 or 0) end
  if ba then ba:set_value((c>=200 and c<208) and 1 or 0) end
  if Y.n==tonumber(os.getenv("A_A")) then out:write(m.system.name.." fin, appels="..Y.k.."\n") out:close() m:exit() end end) end
