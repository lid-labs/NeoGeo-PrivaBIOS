-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- Provoque un appel au BIOS, sans partie : à la première trame >= A_F où le PC est hors du BIOS,
-- écrit A_IFACE (octets hex) à partir de $10FDC4, remplit A_REMPLIR ("adresse:longueur", hex,
-- motif (i*7+$31)&$FF), empile le PC courant comme adresse de retour et saute à A_ENTREE (hex).
-- Relève jusqu'au retour (premier fetch à l'adresse de retour) : écritures en RAM hors pile du
-- BIOS ($10F200-$10F2FF), regroupées ; accès à la carte, et chaque écriture sur la carte ;
-- interface après ; trames écoulées. L'interruption vblank du jeu tombe dans la fenêtre : ses
-- écritures sont dans le relevé, à écarter. Validé sur un chargement : mêmes écritures et mêmes
-- lectures de carte que l'appel naturel.
--   A_F=1200 A_FIN=1500 A_ENTREE=C00468 A_IFACE=<octets> A_OUT=<sortie> mame aof -bios euro \
--   -memc <carte.neo> ... -autoboot_script bench/forcer.lua
-- Sans A_OUT, la sortie va à J_OUT/o.txt (le dossier du run de `parcours.sh`). Après le retour,
-- « tampon: » porte les octets de la zone A_TAMPON (« adresse:longueur », défaut A_REMPLIR), tels
-- que le jeu les relirait.
if not _G.F then _G.F={n=0,actif=false}
local m=manager.machine; local cpu=m.devices[":maincpu"]; local p=cpu.spaces["program"]
local out=io.open(os.getenv("A_OUT") or (os.getenv("J_OUT").."/o.txt"),"a")
local AF=tonumber(os.getenv("A_F")); local ENT=tonumber(os.getenv("A_ENTREE"),16)
local function iface() local t={} for a=0x10FDC4,0x10FDD1 do t[#t+1]=string.format("%02X",p:read_u8(a)) end return table.concat(t," ") end
F.ram={} F.cr=0 F.cw=0 F.cwa={}
F.tw=p:install_write_tap(0x100000,0x10FFFF,"w",function(o,d,mk)
  if F.actif and not (o>=0x10F200 and o<=0x10F2FF) then F.ram[#F.ram+1]=o end end)
F.tcr=p:install_read_tap(0x800000,0x8FFFFF,"cr",function(o) if F.actif then F.cr=F.cr+1 end end)
F.sys={} F.tsys=p:install_write_tap(0x380000,0x3A001F,"sys",function(o,d,mk) if F.actif then F.sys[#F.sys+1]=string.format("%06X=%04X/%04X",o,d,mk) end end)
F.st={} F.tst=p:install_read_tap(0x380000,0x380001,"st",function(o,d,mk) if F.actif then local k=string.format("%04X/%04X",d,mk) F.st[k]=(F.st[k] or 0)+1 end end)
F.tcw=p:install_write_tap(0x800000,0x8FFFFF,"cw",function(o,d) if F.actif then F.cw=F.cw+1 F.cwa[#F.cwa+1]=string.format("%X=%02X",o,d&0xFF) end end)
local function groupe(L)
  -- A_BRUT=1 : une adresse par écriture, sans regroupement, pour un filtre adresse par adresse.
  if os.getenv("A_BRUT")=="1" then local t={} for _,x in ipairs(L) do t[#t+1]=string.format("%06X-%06X(1)",x,x) end return table.concat(t," ") end
  local s,pr,st,nb={},nil,nil,0
  for _,a in ipairs(L) do if pr and (a==pr or a==pr+1 or a==pr+2) then pr=a nb=nb+1 else
    if st then s[#s+1]=string.format("%06X-%06X(%d)",st,pr,nb) end st=a pr=a nb=1 end end
  if st then s[#s+1]=string.format("%06X-%06X(%d)",st,pr,nb) end return table.concat(s," ") end
emu.register_frame_done(function() F.n=F.n+1
  if F.n>=AF and not F.fait and cpu.state["PC"].value<0x100000 then F.fait=true
    local h=os.getenv("A_IFACE") or "" local a=0x10FDC4
    for b in string.gmatch(h,"%x%x") do p:write_u8(a,tonumber(b,16)) a=a+1 end
    for pa,pv in string.gmatch(os.getenv("A_POKE") or "","(%x+)=(%x+)") do p:write_u8(tonumber(pa,16),tonumber(pv,16)) end
    local ra,rl=string.match(os.getenv("A_REMPLIR") or "","(%x+):(%x+)")
    if ra then ra=tonumber(ra,16) for i=0,tonumber(rl,16)-1 do p:write_u8(ra+i,(i*7+0x31)&0xFF) end end
    local pc=cpu.state["PC"].value; local sp=cpu.state["SP"].value-4
    p:write_u32(sp,pc); cpu.state["SP"].value=sp; cpu.state["PC"].value=ENT
    F.ret=pc F.debut=F.n F.actif=true
    out:write(string.format("f%d appel force %06X, retour %06X, interface: %s\n",F.n,ENT,pc,iface())) out:flush()
    F.tret=p:install_read_tap(pc,pc+1,"ret",function()
      if F.actif and cpu.state["PC"].value then F.actif=false
        out:write(string.format("f%d retour apres %d trames ; ram: %s\n  carte lect=%d ecr=%d\n  apres: %s\n",
          F.n,F.n-F.debut,groupe(F.ram),F.cr,F.cw,iface()))
        local t={} for k,v in pairs(F.st) do t[#t+1]=k..":"..v end out:write("  registres ecrits: "..table.concat(F.sys," ").."\n") out:write("  REG_STATUS_B lu: "..table.concat(t," ").."\n")
        if F.cw>0 then out:write("  ecritures carte: "..table.concat(F.cwa," ").."\n") end
        local ta,tl=string.match(os.getenv("A_TAMPON") or os.getenv("A_REMPLIR") or "","(%x+):(%x+)")
        if ta then local t={} for i=0,tonumber(tl,16)-1 do t[#t+1]=string.format("%02X",p:read_u8(tonumber(ta,16)+i)) end
          out:write("  tampon: "..table.concat(t).."\n") end
        out:flush() end end)
  end
  if F.n==tonumber(os.getenv("A_FIN")) then
    if F.actif then out:write(string.format("f%d PAS DE RETOUR ; ram: %s ; carte lect=%d ecr=%d\n",F.n,groupe(F.ram),F.cr,F.cw)) end
    out:close() m:exit() end end) end
