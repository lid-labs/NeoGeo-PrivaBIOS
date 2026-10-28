-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- Jig du menu en jeu (`src/c0/menu.s`), sans fenêtre. Met un jeu en partie (pièce puis START),
-- tient le bouton TEST de la carte, choisit une ligne du menu, et relève ce que le menu rend.
--
--   J_OUT      dossier de sortie (obligatoire) ; le relevé va dans J_OUT/menu.txt
--   J_PIECE    trame de la pièce (défaut 400), J_START celle de START (défaut 500), 8 trames
--   J_GESTE    première trame du geste (défaut 1500), tenu J_TENIR trames (défaut 40)
--   J_TEST     1 : TEST tenu pendant le geste (champ MAME `:TEST` « Service Mode ») ; 0 : rien
--              — le run témoin, où le menu ne s'ouvre pas et où le jeu vit les mêmes entrées
--   J_APPUIS   « trame:bouton » séparés par des virgules (bas, haut, A, START), 3 trames
--   J_IMAGES   trames dont l'image (bgra 320×224) est écrite
--   J_HACHES   « de-à » : à chaque trame de cet intervalle, une empreinte de la RAM de travail,
--              de la VRAM, de la RAM de palettes et de l'image (pour aligner un run sur son
--              témoin), et le compte des écritures de REG_SOUND et du Z80 vers le YM2610
--   J_DUMPS    trames où écrire les mêmes fichiers que les relevés « avant » / « après »,
--              nommés dNNNNN-{ram,vram,pal}.bin
--   J_PALS_LIBRES  palettes (1-15, virgules) à laisser libres : à J_GESTE + 15, la colonne 0
--              du plan fixe (masquée à l'écran) reçoit une case sous chacune des autres, pour
--              forcer le repli de `.Lchoisir_palettes` ; écrit dans la VRAM de MAME
--   J_FIN      trame de sortie (défaut 2400)
--
-- LES RELEVÉS « AVANT » ET « APRÈS », à l'instruction près, par deux taps sur MN_SR ($10F802,
-- `menu.s`) : l'écriture qui ouvre le menu, et la lecture qui le referme (MN_COMPTE à $FFFF).
-- Chacun écrit J_OUT/{avant,apres}-{ram,vram,pal}.bin : $100000-$10FFFF, la VRAM entière
-- (item `0/m_videoram` de `:spritegen`), $400000-$401FFF (la banque en place), plus l'adresse
-- VRAM et le pas que MAME tient (items `m_vram_offset`, `m_vram_modulo`).
-- Le script est relu à chaque reset de la machine : la garde _G le fait ne s'installer qu'une fois.
if _G.MENUJIG then return end
_G.MENUJIG = {}
local OUT = os.getenv("J_OUT")
if not OUT then print("MENUJIG: J_OUT manquant") manager.machine:exit() return end
local function N(v, d) return tonumber(os.getenv(v) or d) end
local PIECE, START, GESTE, TENIR = N("J_PIECE", "400"), N("J_START", "500"), N("J_GESTE", "1500"), N("J_TENIR", "40")
local TEST, FIN = N("J_TEST", "1"), N("J_FIN", "2400")
local H0, H1 = (os.getenv("J_HACHES") or "0-0"):match("(%d+)-(%d+)") H0, H1 = tonumber(H0), tonumber(H1)
local m = manager.machine
local cpu = m.devices[":maincpu"]
local p = cpu.spaces["program"]
local ecran = m.screens:at(1)
local sg = m.devices[":spritegen"]
local vram = emu.item(sg.items["0/m_videoram"])
local voff = emu.item(sg.items["0/m_vram_offset"])
local vmod = emu.item(sg.items["0/m_vram_modulo"])
local function F(pt, nom) local x = m.ioport.ports[pt] return x and x.fields[nom] end
local champs = {
  piece = F(":AUDIO_COIN", "Coin 1"), START = F(":edge:joy:START", "1 Player Start"),
  haut = F(":edge:joy:JOY1", "P1 Up"), bas = F(":edge:joy:JOY1", "P1 Down"), A = F(":edge:joy:JOY1", "P1 A"),
}
for k, c in pairs(champs) do assert(c, "champ MAME introuvable : " .. k) end
local test = F(":TEST", "Service Mode")
assert(test, "champ MAME :TEST « Service Mode » introuvable")
local appuis = {}
for t, b in (os.getenv("J_APPUIS") or ""):gmatch("(%d+):(%a+)") do
  assert(champs[b], "bouton inconnu : " .. b) appuis[#appuis + 1] = { tonumber(t), b } end
local libres, forcer = {}, os.getenv("J_PALS_LIBRES")
for v in (forcer or ""):gmatch("%d+") do libres[tonumber(v)] = true end
local dumps = {}
for n in (os.getenv("J_DUMPS") or ""):gmatch("%d+") do dumps[tonumber(n)] = true end
local images = {}
for n in (os.getenv("J_IMAGES") or ""):gmatch("%d+") do images[tonumber(n)] = true end
local out = io.open(OUT .. "/menu.txt", "w")
local function W(fmt, ...) out:write(string.format(fmt, ...) .. "\n") out:flush() end

local n, occupe = 0, false
local son, ym = {}, 0

local function releve(nom)
  occupe = true
  local t = {}
  for a = 0x100000, 0x10FFFF, 4 do t[#t + 1] = string.pack(">I4", p:read_u32(a)) end
  local f = io.open(OUT .. "/" .. nom .. "-ram.bin", "wb") f:write(table.concat(t)) f:close()
  t = {}
  for i = 0, vram.count - 1 do t[#t + 1] = string.pack(">I2", vram:read(i)) end
  f = io.open(OUT .. "/" .. nom .. "-vram.bin", "wb") f:write(table.concat(t)) f:close()
  t = {}
  for a = 0x400000, 0x401FFF, 2 do t[#t + 1] = string.pack(">I2", p:read_u16(a)) end
  f = io.open(OUT .. "/" .. nom .. "-pal.bin", "wb") f:write(table.concat(t)) f:close()
  W("f%d %s pc=%06X sr=%04X sp=%08X vram_offset=%04X vram_modulo=%04X ligne=%d", n, nom,
    cpu.state["PC"].value, cpu.state["SR"].value, cpu.state["SP"].value, voff:read(0), vmod:read(0),
    p:read_u16(0x3C0006) >> 7)
  occupe = false
end

-- L'ouverture et la fermeture du menu.
_G.MENUJIG.tav = p:install_write_tap(0x10F802, 0x10F803, "avant", function()
  if not occupe and n > 0 and cpu.state["PC"].value >= 0xC04300 then W("f%d MENU OUVERT", n) releve("avant") end end)
_G.MENUJIG.tap = p:install_read_tap(0x10F802, 0x10F803, "apres", function()
  if not occupe and p:read_u16(0x10F800) == 0xFFFF then
    W("f%d MENU FERME adr_retrouvee=%d adr=%04X palettes=%d,%d,%d usage=%04X", n, p:read_u16(0x10F84A),
      p:read_u16(0x10F848), p:read_u16(0x10F872), p:read_u16(0x10F874), p:read_u16(0x10F876), p:read_u16(0x10F878))
    releve("apres") end end)
-- Le son : ce que le 68000 envoie au Z80, et ce que le Z80 écrit au YM2610 (ports 4-7).
_G.MENUJIG.tson = p:install_write_tap(0x320000, 0x320001, "son", function(o, d, mk)
  if not occupe and (mk & 0xFF00) ~= 0 then son[#son + 1] = string.format("%02X", (d >> 8) & 0xFF) end end)
local zio = m.devices[":audiocpu"].spaces["io"]
_G.MENUJIG.tym = zio:install_write_tap(0x0000, 0xFFFF, "ym", function(o)
  local b = o & 0xFF if b >= 4 and b <= 7 then ym = ym + 1 end end)
_G.MENUJIG.reset = emu.add_machine_reset_notifier(function() W("f%d RESET", n) end)

local function hache(s, h) for i = 1, #s, 7 do h = (h * 31 + s:byte(i)) % 2147483647 end return h end
local function empreintes()
  occupe = true
  local h = 5381
  for a = 0x100000, 0x10FFFF, 4 do
    -- hors calendrier (horloge de l'hôte, $10FDD2-$10FDD9), hors zones du menu ($10F4C0-$10F7FF,
    -- $10F800-$10FAFF) et des états des cheats ($10FB00-$10FB07, `cheats.s`)
    if not (a >= 0x10FDD0 and a < 0x10FDDC) and not (a >= 0x10F4C0 and a < 0x10FB08) then
      h = (h * 33 + p:read_u32(a)) % 2147483647 end
  end
  local v = 5381 for i = 0, vram.count - 1 do v = (v * 33 + vram:read(i)) % 2147483647 end
  local c = 5381 for a = 0x400000, 0x401FFF, 2 do c = (c * 33 + p:read_u16(a)) % 2147483647 end
  occupe = false
  local px = ecran:pixels()
  return h, v, c, hache(px, 5381)
end

emu.register_frame_done(function()
  n = n + 1
  local tenus = {}
  if n >= PIECE and n < PIECE + 8 then tenus.piece = true end
  if n >= START and n < START + 8 then tenus.START = true end
  test:set_value((TEST == 1 and n >= GESTE and n < GESTE + TENIR) and 1 or 0)
  for _, a in ipairs(appuis) do if n >= a[1] and n < a[1] + 3 then tenus[a[2]] = true end end
  for k, c in pairs(champs) do c:set_value(tenus[k] and 1 or 0) end
  local u = string.format("%02X/%02X", p:read_u8(0x10FDAF), p:read_u8(0x10FDAE))
  if u ~= _G.MENUJIG.user then _G.MENUJIG.user = u W("f%d user=%s", n, u) end
  if n >= H0 and n <= H1 then
    local h, v, c, i = empreintes()
    W("f%d H ram=%d vram=%d pal=%d img=%d son=%s ym=%d", n, h, v, c, i, table.concat(son, ","), ym)
  elseif #son > 0 or n % 100 == 0 then
    W("f%d son=%s ym=%d", n, table.concat(son, ","), ym)
  end
  son, ym = {}, 0
  if forcer and n == GESTE + 15 then
    local row = 0
    for pal = 1, 15 do if not libres[pal] then vram:write(0x7000 + row, (pal << 12) | 0x20) row = row + 1 end end
    W("f%d plan fixe force : %d cases en colonne 0, palettes libres %s", n, row, forcer)
  end
  if dumps[n] then releve(string.format("d%05d", n)) end
  if images[n] then
    local f = io.open(string.format("%s/f%05d.bin", OUT, n), "wb") f:write((ecran:pixels())) f:close()
  end
  if n >= FIN then out:close() m:exit() end
end)
