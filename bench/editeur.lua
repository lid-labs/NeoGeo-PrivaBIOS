-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- Soft-DIP editor jig (`src/c0/dip.s`), windowless. Holds the board's TEST button (MAME's
-- `:TEST` "Service Mode" field) from frame 1 to E_TEST, presses P1 buttons at the wanted
-- frames, records the save block and BIOS_GAME_DIP, and writes pictures.
--
--   E_OUT      output folder (mandatory); the record goes to E_OUT/editeur.txt
--   E_TEST     last frame where TEST is held (0: never; default 0)
--   E_APPUIS   "frame:button" separated by commas, button among haut bas gauche droite
--              A START; each press lasts 3 frames
--   E_RELEVES  frames at which to record $D00124-$D00143, $D00220-$D0029F, $10FD84-$10FD93, the
--              BIOS settings ($D00210-$D0021F, `src/c0/reglages.s`) and BIOS_COUNTRY_CODE
--   E_IMAGES   frames whose picture (bgra 320×224, like bios-probe.lua) is written
--   E_FIN      MAME exit frame (default 1200); vifs recorded every 100 frames
--
-- No input is pressed apart from these: no coin, no START from the bench.
--   E_OUT=… E_TEST=260 E_APPUIS=270:bas,280:droite,300:START mame kof98 -bios euro \
--     -video none -nvram_directory <neuf> -autoboot_script bench/editeur.lua
-- The script is reread at each machine reset (watchdog, or a game's intended reset): the
-- _G guard makes it install only once, and each reset is recorded with its frame.
if _G.EDITEUR then return end
_G.EDITEUR = {}
local OUT = os.getenv("E_OUT")
if not OUT then print("EDITEUR: E_OUT manquant") manager.machine:exit() return end
local TEST_FIN = tonumber(os.getenv("E_TEST") or "0")
local FIN = tonumber(os.getenv("E_FIN") or "1200")
local m = manager.machine
local p = m.devices[":maincpu"].spaces["program"]
local ecran = m.screens:at(1)
local function F(pt, n) local x = m.ioport.ports[pt] return x and x.fields[n] end
local champs = {
  haut = F(":edge:joy:JOY1", "P1 Up"), bas = F(":edge:joy:JOY1", "P1 Down"),
  gauche = F(":edge:joy:JOY1", "P1 Left"), droite = F(":edge:joy:JOY1", "P1 Right"),
  A = F(":edge:joy:JOY1", "P1 A"), START = F(":edge:joy:START", "1 Player Start"),
}
for nom in pairs({ haut = 1, bas = 1, gauche = 1, droite = 1, A = 1, START = 1 }) do
  assert(champs[nom], "champ MAME introuvable pour le bouton " .. nom)
end
local test = F(":TEST", "Service Mode")
assert(test, "champ MAME :TEST « Service Mode » introuvable")
local appuis = {}
for t, b in (os.getenv("E_APPUIS") or ""):gmatch("(%d+):(%a+)") do
  assert(champs[b], "bouton inconnu : " .. b)
  appuis[#appuis + 1] = { tonumber(t), champs[b] }
end
local releves, images = {}, {}
for n in (os.getenv("E_RELEVES") or ""):gmatch("%d+") do releves[tonumber(n)] = true end
for n in (os.getenv("E_IMAGES") or ""):gmatch("%d+") do images[tonumber(n)] = true end
local out = io.open(OUT .. "/editeur.txt", "w")
local function octets(a, n)
  local t = {} for i = 0, n - 1 do t[#t + 1] = string.format("%02X", p:read_u8(a + i)) end
  return table.concat(t, " ")
end
local function vifs(px)
  local v = 0 for i = 1, #px, 4 do if px:byte(i) + px:byte(i + 1) + px:byte(i + 2) > 24 then v = v + 1 end end
  return v
end
local n, fini = 0, false
_G.EDITEUR.reset = emu.add_machine_reset_notifier(function()
  out:write(string.format("f%d RESET\n", n)) out:flush() end)
emu.register_frame_done(function()
  if fini then return end
  n = n + 1
  test:set_value((n <= TEST_FIN) and 1 or 0)
  local tenus = {}
  for _, a in ipairs(appuis) do if n >= a[1] and n < a[1] + 3 then tenus[a[2]] = true end end
  for _, c in pairs(champs) do c:set_value(tenus[c] and 1 or 0) end
  -- Each change of the USER request ($10FDAF mode, $10FDAE request): it shows whether a boot
  -- hands over in request 0 (first boot of the game) or in request 2.
  local u = string.format("%02X/%02X", p:read_u8(0x10FDAF), p:read_u8(0x10FDAE))
  if u ~= _G.EDITEUR.user then _G.EDITEUR.user = u out:write(string.format("f%d user=%s\n", n, u)) end
  if releves[n] then
    out:write(string.format("f%d slots %s\n", n, octets(0xD00124, 32)))
    for b = 0, 7 do out:write(string.format("f%d bloc%d %s\n", n, b, octets(0xD00220 + 16 * b, 16))) end
    out:write(string.format("f%d GAME_DIP %s\n", n, octets(0x10FD84, 16)))
    out:write(string.format("f%d usermode=%02X userreq=%02X\n", n, p:read_u8(0x10FDAF), p:read_u8(0x10FDAE)))
    out:write(string.format("f%d pays=%02X reglages %s\n", n, p:read_u8(0x10FD83), octets(0xD00210, 16)))
  end
  if images[n] or n % 100 == 0 then
    local px = ecran:pixels()
    if images[n] then local f = io.open(string.format("%s/f%05d.bin", OUT, n), "wb") f:write(px) f:close() end
    if n % 100 == 0 then out:write(string.format("f%d vifs=%d pays=%02X\n", n, vifs(px), p:read_u8(0x10FD83))) end
  end
  out:flush()
  if n >= FIN then fini = true out:close() m:exit() end
end)
