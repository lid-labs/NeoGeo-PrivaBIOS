-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- Reconstruit le plan fixe ($7000-$74FF) depuis les écritures du 68000 au LSPC — VRAMADDR
-- ($3C0000), VRAMRW ($3C0002), VRAMMOD ($3C0004, l'auto-incrément) —, sans lire la VRAM, que MAME
-- n'expose pas au Lua. Aux trames A_SHOTS, écrit A_DIR/fixNNNNN.txt : 32 lignes de 40 entrées
-- (palette sur 4 bits, tuile sur 12), ligne par ligne de l'écran. Une écriture faite par DMA ou
-- avant le chargement du script échappe au relevé.
--   A_SHOTS=900 A_FIN=901 A_DIR=<dossier> mame <jeu> ... -autoboot_script bench/fixmap.lua
if not _G.X then _G.X={n=0,a=0,mod=1,v={}}
local m=manager.machine; local p=m.devices[":maincpu"].spaces["program"]
X.t=p:install_write_tap(0x3C0000,0x3C0005,"lspc",function(o,d,mk)
  local r=o&6
  if r==0 then X.a=d elseif r==4 then X.mod=d
  elseif r==2 then X.v[X.a]=d X.a=(X.a+X.mod)&0xFFFF end end)
local sh={} for t in string.gmatch(os.getenv("A_SHOTS") or "","%d+") do sh[tonumber(t)]=true end
emu.register_frame_done(function() X.n=X.n+1
  if sh[X.n] then local f=io.open(string.format("%s/fix%05d.txt",os.getenv("A_DIR"),X.n),"w")
    for row=0,31 do local l={} for col=0,39 do l[#l+1]=string.format("%04X",X.v[0x7000+col*32+row] or 0) end f:write(table.concat(l," ").."\n") end f:close() end
  if X.n==tonumber(os.getenv("A_FIN")) then m:exit() end end) end
