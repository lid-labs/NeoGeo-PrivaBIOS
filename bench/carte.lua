-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- La carte mémoire, vue de partout : chaque vrai appel du jeu à une entrée du tableau d'appels
-- (comme `appels.lua` : lecture d'entrée suivie d'une écriture en RAM), sauf les entrées appelées
-- à chaque trame ($C00438, $C0044A, $C00450, $C004C2, $C004C8, $C004CE), avec l'interface
-- $10FDC4-$10FDD0 au moment de l'appel ; et chaque trame où la carte ($800000-$8FFFFF) est lue
-- ou écrite, avec ses comptes et ses plages, que l'accès vienne d'un appel ou non. Sert là où le
-- BIOS formate ou sauvegarde sur plusieurs trames, hors de l'entrée CARD.
--   A_SANS_ENTREES=1 A_OUT=<sortie> mame <jeu> -bios euro -memc <carte.neo> ... \
--   -autoboot_script bench/carte.lua
-- Aucun appui n'est injecté : le script est fait pour une partie jouée à la main.
if not _G.Y then _G.Y={n=0,e=nil}
local m=manager.machine; local p=m.devices[":maincpu"].spaces["program"]
local out=io.open(os.getenv("A_OUT"),"a")
local frequentes={[0xC00438]=1,[0xC0044A]=1,[0xC00450]=1,[0xC004C2]=1,[0xC004C8]=1,[0xC004CE]=1}
local function iface() local t={} for a=0x10FDC4,0x10FDD0 do t[#t+1]=string.format("%02X",p:read_u8(a)) end return table.concat(t," ") end
local function zero() Y.cr,Y.cw,Y.r0,Y.r1,Y.w0,Y.w1=0,0,1e9,0,1e9,0 end zero()
Y.tw=p:install_write_tap(0x100000,0x10FFFF,"w",function()
  if Y.e then out:write(string.format("f%d appel %06X interface: %s\n",Y.n,Y.e,iface())) out:flush() Y.e=nil end end)
Y.tr=p:install_read_tap(0x100000,0x10FFFF,"r",function() Y.e=nil end)
Y.tp=p:install_read_tap(0x000000,0x0FFFFF,"p",function() Y.e=nil end)
Y.tb=p:install_read_tap(0xC00000,0xC1FFFF,"b",function(o)
  if o>=0xC00438 and o<=0xC006FC and (o-0xC00438)%6==0 and not frequentes[o] and (p:read_u8(0x10FD80)&0x80)~=0 then Y.e=o else Y.e=nil end end)
Y.tcr=p:install_read_tap(0x800000,0x8FFFFF,"cr",function(o) Y.cr=Y.cr+1 Y.r0=math.min(Y.r0,o) Y.r1=math.max(Y.r1,o) end)
Y.tcw=p:install_write_tap(0x800000,0x8FFFFF,"cw",function(o) Y.cw=Y.cw+1 Y.w0=math.min(Y.w0,o) Y.w1=math.max(Y.w1,o) end)
emu.register_frame_done(function() Y.n=Y.n+1
  if Y.cr+Y.cw>0 then
    out:write(string.format("f%d carte lect=%d [%X-%X] ecr=%d [%X-%X] interface: %s\n",Y.n,Y.cr,Y.r0,Y.r1,Y.cw,Y.w0,Y.w1,iface())) out:flush() zero() end end)
end
