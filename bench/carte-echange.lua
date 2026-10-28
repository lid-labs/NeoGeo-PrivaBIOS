-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- Jig du changement de carte mémoire, chargé avec `son.lua` (J_AUSSI), sans fenêtre : à une trame donnée, la carte
-- en place est retirée (MAME l'écrit dans son fichier) et une autre insérée, comme un joueur qui change de carte.
-- Scène cm-copier de `parcours.sh`. Ne joue aucune entrée.
--   CE_ECHANGE  « trame:chemin » séparés par des virgules : à la fin de cette trame, la carte de ce fichier ; « - »
--               pour chemin : la carte retirée seulement (sinon l'échange se fait entre deux trames, sans absence)
--               Le fichier n'est pas chargé tel quel : il est recopié d'abord dans J_OUT, « carte-<trame>.neo »,
--               et c'est la copie que MAME charge, puis réécrit au retrait ; la fixture reste intacte
--   CE_OUT      un fichier où noter « f<n> CARTE <chemin> » à chaque échange
if _G.CARTEECH then return end
_G.CARTEECH = {}
local m = manager.machine
local img = nil
for tag, i in pairs(m.images) do if tag:find("memcard") then img = i end end
assert(img, "pas de carte mémoire dans cette machine")
local ech = {}
for t, f in (os.getenv("CE_ECHANGE") or ""):gmatch("(%d+):([^,]+)") do ech[tonumber(t)] = f end
local out = os.getenv("CE_OUT") and io.open(os.getenv("CE_OUT"), "w")
local n = 0
emu.register_frame_done(function()
  n = n + 1
  local f = ech[n]
  if f then
    img:unload()
    if f ~= "-" then
      local c = string.format("%s/carte-%d.neo", os.getenv("J_OUT"), n)
      local s = assert(io.open(f, "rb")) local d = s:read("a") s:close()
      local o = assert(io.open(c, "wb")) o:write(d) o:close()
      img:load(c)
      f = c
    end
    if out then out:write(string.format("f%d CARTE %s %s\n", n, f, tostring(img.exists))) out:flush() end
  end
end)
