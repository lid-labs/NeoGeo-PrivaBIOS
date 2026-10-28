-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- Jig de l'éditeur de soft-DIP (`src/c0/dip.s`), sans fenêtre. Tient le bouton TEST de la
-- carte (champ `:TEST` « Service Mode » de MAME) de la trame 1 à E_TEST, presse des boutons de
-- P1 aux trames voulues, relève le bloc de sauvegarde et BIOS_GAME_DIP, et écrit des images.
--
--   E_OUT      dossier de sortie (obligatoire) ; le relevé va dans E_OUT/editeur.txt
--   E_TEST     dernière trame où TEST est tenu (0 : jamais ; défaut 0)
--   E_APPUIS   « trame:bouton » séparés par des virgules, bouton parmi haut bas gauche droite
--              A START ; chaque appui dure 3 trames
--   E_RELEVES  trames où relever $D00124-$D00143, $D00220-$D0029F, $10FD84-$10FD93, les
--              réglages du BIOS ($D00210-$D0021F, `src/c0/reglages.s`) et BIOS_COUNTRY_CODE
--   E_IMAGES   trames dont l'image (bgra 320×224, comme bios-probe.lua) est écrite
--   E_FIN      trame de sortie de MAME (défaut 1200) ; vifs relevés toutes les 100 trames
--
-- Aucune entrée n'est pressée en dehors de celles-ci : pas de pièce, pas de START du banc.
--   E_OUT=… E_TEST=260 E_APPUIS=270:bas,280:droite,300:START mame kof98 -bios euro \
--     -video none -nvram_directory <neuf> -autoboot_script bench/editeur.lua
-- Le script est relu à chaque reset de la machine (watchdog, ou reset voulu d'un jeu) : la
-- garde _G le fait ne s'installer qu'une fois, et chaque reset est relevé avec sa trame.
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
  -- Chaque changement de la demande USER ($10FDAF mode, $10FDAE demande) : on y lit si un
  -- boot remet la main en demande 0 (premier boot du jeu) ou en demande 2.
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
