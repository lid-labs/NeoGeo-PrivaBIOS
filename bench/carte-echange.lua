-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- Memory card change jig, loaded with `son.lua` (J_AUSSI), windowless: at a given frame, the
-- card in place is removed (MAME writes it to its file) and another one inserted, like a player
-- changing cards. Scene cm-copier of `parcours.sh`. Plays no input.
--   CE_ECHANGE  "frame:path" separated by commas: at the end of that frame, the card of that
--               file; "-" as path: the card removed only (otherwise the swap happens between two
--               frames, with no absence)
--               The file is not loaded as is: it is first copied into J_OUT,
--               "carte-<trame>.neo", and it is the copy that MAME loads, then rewrites on
--               removal; the fixture stays intact
--   CE_OUT      a file in which to note "f<n> CARTE <chemin>" at each swap
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
