-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- Diagnostic jig for the sound and the fix layer around an in-game menu, and observer of the player's path
-- (`bench/parcours.sh`). No window.
-- This jig traces no code: it counts writes (value, frame) and classes each one "B" (BIOS,
-- PC in $C00000-$C1FFFF) or "J" (game); it does not log the PC.
--   J_OUT       folder (mandatory); record J_OUT/son.txt
--   J_PIECE, J_START   frames (8 frames held); defaults 400, 500; 0: never
--   J_GESTE, J_TENIR   TEST held (if J_TEST=1)
--   J_TESTS     "a-b" separated by commas: TEST held from frame a to frame b, in addition
--   J_APPUIS    "frame:button[:duration]" (piece, START, haut, bas, gauche, droite, A, B, C, D,
--               piece2, start2, deuxA, service, select, select2, and for P2 deuxB, deuxC,
--               deuxD, deuxHaut, deuxBas, deuxGauche, deuxDroite, and the mahjong panel mjA…mjReach,
--               mjStart: see below)
--   J_DSW       "frame:bits" (hex) separated by commas: from that frame on, the
--               board switches whose bit is 1 in "bits" are set to ON (the bit
--               of REG_DIPSW at 0, active low), the others to OFF; through the fields of MAME's :DSW
--   "f<n> SLOT <v>": each write to REG_SLOT (see below)
--   J_TIRS      "from-to:step:button": presses of 3 frames
--   J_IMAGES    picture frames bgra 320×224, "a-b" for a range
--   J_HACHES    "from-to": at each frame of the range, "img=" the hash of the WHOLE
--               picture (every pixel goes into it: `docs/BENCH.md`, pitfall 4)
--   J_ZONES     "x0,y0,x1,y1" separated by ";" (pixels, bounds included): within the range
--               of J_HACHES, "zK=" the hash of each rectangle, K from 1 — what
--               a zone of the screen displays (a timer, a life bar)
--   J_SUIVRE    "adr:size" (hex, size 1 or 2), commas: the value at each frame, "m"
--               followed by the address — a game value in RAM, in addition to the screen
--   J_REMISE    "k" separated by commas: the picture k frames after the last hand-over of
--               control to the game — a new value of the mode/request pair ($10FDAF/$10FDAE)
--               with mode 01: the first boot, the restart after a region change, the
--               title after a coin —, in J_OUT/rKKKKK.bin. An instant of the GAME, whatever
--               the time the BIOS took before; a later hand-over rewrites it
--   J_TEXTE     frames at which to write the decoded fix layer (rows 2 to 29, "fixNN |…|"),
--               rebuilt from the writes to the LSPC as in `autotests.lua`
--   J_TUILES    frames at which to write the RAW fix layer, same rebuild: "fNN tuNN" then the 40
--               entries of the row in hexadecimal (palette on 4 bits, tile on 12), rows 2 to
--               29 — the tiles outside the ASCII font, which J_TEXTE renders as spaces
--   J_INJ       "frame:code": a code written by lua to REG_SOUND
--   J_POSER     "frame@adr=bytes" (hex), commas: these bytes written by lua into the game's
--               RAM at the end of the frame — a simulated player score, like MS_POSER of `multislot.lua`
--   J_BRAM      "frame@adr=bytes" (hex), commas: these bytes written into the backup RAM ($D0xxxx) at the
--               end of the frame, through MAME's shared memory ":saveram", which REG_SRAMLOCK does not
--               protect — a cabinet setting set as another BIOS would have left it
--   J_FIN       exit
--   J_FLOTTANT  path of `bus-flottant.lua`, loaded with this jig: the cartridge served like the
--               hardware, only under REG_CRTFIX (its header); BF_OUT, BF_FIN (before J_FIN)
--               and BF_HOTE=1 must be set too, BF_LIBRE=1 for the witness without the model
-- Each frame line also carries "t=" (the machine time in seconds, to align the
-- WAV of `-wavwrite` with the frames) and "cote=": B if the frame ends with the PC in the BIOS,
-- J otherwise. A run of "cote=B" frames is a pause of the game (in-game menu, TEST screen).
-- "fixB=c0-c1,r0-r1": the rectangle (columns, rows) of the fix-layer cells that the BIOS
-- wrote in the frame, when it wrote any — the border of the in-game menu, for example.
if _G.SONJIG then return end
_G.SONJIG = {}
if os.getenv("J_FLOTTANT") then dofile(os.getenv("J_FLOTTANT")) end
-- J_AUSSI: another jig loaded with this one (`scores.lua`, `carte-protegee.lua`), which plays no input.
if os.getenv("J_AUSSI") then for x in os.getenv("J_AUSSI"):gmatch("[^;]+") do dofile(x) end end
local OUT = os.getenv("J_OUT")
local function N(v, d) return tonumber(os.getenv(v) or d) end
local PIECE, START, GESTE, TENIR = N("J_PIECE", "400"), N("J_START", "500"), N("J_GESTE", "1500"), N("J_TENIR", "40")
local TEST, FIN = N("J_TEST", "0"), N("J_FIN", "2400")
local H0, H1 = (os.getenv("J_HACHES") or "0-0"):match("(%d+)-(%d+)") H0, H1 = tonumber(H0), tonumber(H1)
local m = manager.machine
local cpu = m.devices[":maincpu"]
local p = cpu.spaces["program"]
local ecran = m.screens:at(1)
local function F(pt, nom) local x = m.ioport.ports[pt] return x and x.fields[nom] end
-- Under `aes` (MAME's console, reference column of the AES mode of `parcours.sh`), the
-- joypads are under :ctrl1 and there is neither coin nor TEST: a missing button is refused only
-- if it is requested (J_APPUIS, J_PIECE, J_START).
local function J(n) return F(":edge:joy:JOY1", "P1 " .. n) or F(":ctrl1:joy:JOY", "P1 " .. n) end
-- piece2, start2: P2's coin and START; deuxA: P2's A button; service: the SERVICE
-- button; select, select2: SELECT P1 and P2 — "Next Game"
-- and "Previous Game" of the MV-6F (`neogeo`), "P1/P2 Select" of the console; a one-cartridge
-- set has none (`src/c0/menu.s`, THE GESTURE).
local champs = {
  piece = F(":AUDIO_COIN", "Coin 1"), piece2 = F(":AUDIO_COIN", "Coin 2"),
  START = F(":edge:joy:START", "1 Player Start") or F(":ctrl1:joy:START_SELECT", "P1 Start"),
  start2 = F(":edge:joy:START", "2 Players Start") or F(":ctrl2:joy:START_SELECT", "P2 Start"),
  select = F(":SYSTEM", "Next Game") or F(":ctrl1:joy:START_SELECT", "P1 Select"),
  select2 = F(":SYSTEM", "Previous Game") or F(":ctrl2:joy:START_SELECT", "P2 Select"),
  haut = J("Up"), bas = J("Down"), gauche = J("Left"), droite = J("Right"),
  A = J("A"), B = J("B"), C = J("C"), D = J("D"),
  deuxA = F(":edge:joy:JOY2", "P2 A") or F(":ctrl2:joy:JOY", "P2 A"), service = F(":AUDIO_COIN", "Service 1"),
  deuxB = F(":edge:joy:JOY2", "P2 B"), deuxC = F(":edge:joy:JOY2", "P2 C"), deuxD = F(":edge:joy:JOY2", "P2 D"),
  deuxHaut = F(":edge:joy:JOY2", "P2 Up"), deuxBas = F(":edge:joy:JOY2", "P2 Down"),
  deuxGauche = F(":edge:joy:JOY2", "P2 Left"), deuxDroite = F(":edge:joy:JOY2", "P2 Right"),
  mjStart = F(":ctrl1:mahjong:START_SELECT", "P1 Start"),
}
-- P1's mahjong panel (MAME's `janshin` machine, neogeo_mj; mahjong.cpp: three rows MJ.0 A-G,
-- MJ.1 H-N, MJ.2 PON, CHI, KAN, RON, REACH): "mjA" to "mjN", "mjPon", "mjChi", "mjKan", "mjRon",
-- "mjReach", and "mjStart"; absent from the other machines.
for i, k in ipairs({ "A", "B", "C", "D", "E", "F", "G" }) do champs["mj" .. k] = F(":ctrl1:mahjong:MJ.0", "P1 Mahjong " .. k) end
for i, k in ipairs({ "H", "I", "J", "K", "L", "M", "N" }) do champs["mj" .. k] = F(":ctrl1:mahjong:MJ.1", "P1 Mahjong " .. k) end
for i, k in ipairs({ "Pon", "Chi", "Kan", "Ron", "Reach" }) do champs["mj" .. k] = F(":ctrl1:mahjong:MJ.2", "P1 Mahjong " .. k) end
-- The board switches: the fields of :DSW, each one set through its configuration value
-- (`user_value`, bits of the field's mask); measured on 2026-10-23 under MAME 0.286 (aof): each
-- field set alone lowers its bit of REG_DIPSW ($300001) and only it.
local dsw = {}
for t, v in (os.getenv("J_DSW") or ""):gmatch("(%d+):(%x+)") do dsw[#dsw + 1] = { tonumber(t), tonumber(v, 16) } end
local dsw_champs = {}
if #dsw > 0 then
  local pt = m.ioport.ports[":DSW"]
  assert(pt, "port :DSW introuvable")
  for _, f in pairs(pt.fields) do dsw_champs[#dsw_champs + 1] = f end
end
-- Nothing is set before the first frame of J_DSW: the fields keep the value MAME loads, that
-- of the game's cfg if it has one, otherwise all OFF. MAME records there the switches set at exit: a
-- cfg shared between runs passes them on (`measured/2026-10-25-free-play.tsv`, section 0). "1:00" sets
-- everything to OFF whatever the cfg.
local dsw_pose = -1
assert(PIECE == 0 or champs.piece, "champ introuvable : piece")
assert(START == 0 or champs.START, "champ introuvable : START")
local test = F(":TEST", "Service Mode")
local appuis = {}
for t, b, d in (os.getenv("J_APPUIS") or ""):gmatch("(%d+):(%a+%d?):?(%d*)") do
  assert(champs[b], "bouton inconnu ou absent : " .. b)
  appuis[#appuis + 1] = { tonumber(t), b, tonumber(d) or 3 } end
for a, z, s, b in (os.getenv("J_TIRS") or ""):gmatch("(%d+)-(%d+):(%d+):(%a+)") do
  for t = tonumber(a), tonumber(z), tonumber(s) do appuis[#appuis + 1] = { t, b, 3 } end end
local tests = {}
for a, z in (os.getenv("J_TESTS") or ""):gmatch("(%d+)-(%d+)") do tests[#tests + 1] = { tonumber(a), tonumber(z) } end
local zones = {}
for a, b, c, d in (os.getenv("J_ZONES") or ""):gmatch("(%d+),(%d+),(%d+),(%d+)") do
  zones[#zones + 1] = { tonumber(a), tonumber(b), tonumber(c), tonumber(d) } end
local suivre = {}
for a, t in (os.getenv("J_SUIVRE") or ""):gmatch("(%x+):(%d)") do suivre[#suivre + 1] = { tonumber(a, 16), tonumber(t) } end
local dumps = {}
for x in (os.getenv("J_DUMPS") or ""):gmatch("%d+") do dumps[tonumber(x)] = true end
local images = {}
for x in (os.getenv("J_IMAGES") or ""):gmatch("[%d-]+") do
  local a, z = x:match("^(%d+)-(%d+)$")
  if a then for k = tonumber(a), tonumber(z) do images[k] = true end
  elseif tonumber(x) then images[tonumber(x)] = true end
end
local remises = {}
for k in (os.getenv("J_REMISE") or ""):gmatch("%d+") do remises[tonumber(k)] = true end
local remise = nil
local poses = {}
for t, a, v in (os.getenv("J_POSER") or ""):gmatch("(%d+)@(%x+)=(%x+)") do poses[#poses + 1] = { tonumber(t), tonumber(a, 16), v } end
local bram = {}
for t, a, v in (os.getenv("J_BRAM") or ""):gmatch("(%d+)@(%x+)=(%x+)") do bram[#bram + 1] = { tonumber(t), tonumber(a, 16) - 0xD00000, v } end
local textes = {}
for n in (os.getenv("J_TEXTE") or ""):gmatch("%d+") do textes[tonumber(n)] = true end
local tuiles = {}
for n in (os.getenv("J_TUILES") or ""):gmatch("%d+") do tuiles[tonumber(n)] = true end
local out = io.open(OUT .. "/son.txt", "w")
local function W(fmt, ...) out:write(string.format(fmt, ...) .. "\n") out:flush() end
local function src() local pc = cpu.state["PC"].value return (pc >= 0xC00000 and pc < 0xC20000) and "B" or "J" end

local n = 0
local son, bascules = {}, {}
local pal = { B = 0, J = 0 }
local fixw = { B = 0, J = 0 }
-- YM2610: ports 4/5 (A), 6/7 (B). Counters per frame.
local ym = { w = 0, fm = 0, adpcma = 0, adpcmb = 0, ssg = 0 }
local adrA, adrB = 0, 0
_G.SONJIG.tson = p:install_write_tap(0x320000, 0x320001, "son", function(o, d, mk)
  if (mk & 0xFF00) ~= 0 then son[#son + 1] = string.format("%s%02X", src(), (d >> 8) & 0xFF) end end)
_G.SONJIG.tbas = p:install_write_tap(0x3A0000, 0x3A001F, "bas", function(o, d, mk)
  local a = o | (((mk & 0xFF) ~= 0) and 1 or 0)
  if a == 0x3A000B or a == 0x3A001B or a == 0x3A0003 or a == 0x3A0013 or a == 0x3A000F or a == 0x3A001F then
    bascules[#bascules + 1] = string.format("%s%06X", src(), a) end end)
-- REG_SLOT ($380021, "Memory mapped registers"): "f<n> SLOT <v>" at each write — the served
-- slot of an MV-6F, which the mode/request pair does not tell (a SELECT in demo keeps 01/02).
_G.SONJIG.tslot = p:install_write_tap(0x380020, 0x380021, "slot", function(o, d, mk)
  if (mk & 0xFF) ~= 0 then W("f%d SLOT %02X", n, d & 0xFF) end end)
_G.SONJIG.tpal = p:install_write_tap(0x400000, 0x401FFF, "pal", function() local s = src() pal[s] = pal[s] + 1 end)
-- The fix layer rebuilt (REG_VRAMADDR / REG_VRAMRW / REG_VRAMMOD), and the writes counted.
local X = { a = 0, mod = 1, v = {} }
local fixB = nil -- the rectangle of the fix-layer cells written by the BIOS in the frame
_G.SONJIG.tvr = p:install_write_tap(0x3C0000, 0x3C0005, "vr", function(o, d)
  local r = o & 6
  if r == 0 then X.a = d elseif r == 4 then X.mod = d
  elseif r == 2 then
    local s = src() fixw[s] = fixw[s] + 1
    if s == "B" and X.a >= 0x7000 and X.a < 0x7500 then
      local col, row = (X.a - 0x7000) // 32, (X.a - 0x7000) % 32
      local b = fixB or { col, col, row, row }
      fixB = { math.min(b[1], col), math.max(b[2], col), math.min(b[3], row), math.max(b[4], row) }
    end
    X.v[X.a] = d X.a = (X.a + X.mod) & 0xFFFF
  end end)
local function ligne(row)
  local l = {}
  for col = 0, 39 do
    local t = (X.v[0x7000 + col * 32 + row] or 0) & 0xFFF
    local c = t & 0xFF
    l[#l + 1] = ((t >> 8) <= 1 and c >= 0x20 and c < 0x7F) and string.char(c) or " "
  end
  return table.concat(l)
end
local zio = m.devices[":audiocpu"].spaces["io"]
_G.SONJIG.tym = zio:install_write_tap(0x0000, 0xFFFF, "ym", function(o, d)
  local b = o & 0xFF
  if b < 4 or b > 7 then return end
  ym.w = ym.w + 1
  if b == 4 then adrA = d & 0xFF
  elseif b == 6 then adrB = d & 0xFF
  elseif b == 5 then
    if adrA == 0x28 and (d & 0xF0) ~= 0 then ym.fm = ym.fm + 1
    elseif adrA == 0x10 and (d & 0x80) ~= 0 then ym.adpcmb = ym.adpcmb + 1
    elseif adrA < 0x0E then ym.ssg = ym.ssg + 1 end
  elseif b == 7 then
    if adrB == 0x00 and (d & 0x80) == 0 and (d & 0x3F) ~= 0 then ym.adpcma = ym.adpcma + 1 end
  end end)
local banques = {}
_G.SONJIG.tbk = zio:install_read_tap(0x0000, 0xFFFF, "bk", function(o, d)
  local b = o & 0xFF
  if b >= 8 and b <= 11 then banques[#banques + 1] = string.format("%d:%02X", b - 8, (o >> 8) & 0xFF) end
  return d end)
local reponse = -1
-- After a reset, the next hand-over counts even if the pair has not changed in the meantime.
_G.SONJIG.reset = emu.add_machine_reset_notifier(function() W("f%d RESET", n) _G.SONJIG.user = "reset" end)

-- The hash of the whole picture, 16 pixels per step: every pixel goes into it, with its weight.
local up = string.unpack
local function hache(px)
  local h = 5381
  for i = 1, #px - 63, 64 do
    local a, b, c, d, e, f, g, hh, i2, j, k, l, mm, nn, o, q = up("<I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4", px, i)
    h = (h * 31 + a + b * 3 + c * 5 + d * 7 + e * 11 + f * 13 + g * 17 + hh * 19 + i2 * 23 + j * 29
      + k * 31 + l * 37 + mm * 41 + nn * 43 + o * 47 + q * 53) % 4294967291
  end
  return h
end

-- That of a rectangle: every pixel of the rectangle, row by row (320 pixels of 4 bytes).
local function hache_zone(px, z)
  local h = 5381
  for y = z[2], z[4] do
    local i = (y * 320 + z[1]) * 4 + 1
    for _ = z[1], z[3] do h = (h * 33 + up("<I4", px, i)) % 4294967291 i = i + 4 end
  end
  return h
end

emu.register_frame_done(function()
  n = n + 1
  local tenus = {}
  if PIECE > 0 and n >= PIECE and n < PIECE + 8 then tenus.piece = true end
  if START > 0 and n >= START and n < START + 8 then tenus.START = true end
  local t_test = TEST == 1 and n >= GESTE and n < GESTE + TENIR
  for _, w in ipairs(tests) do if n >= w[1] and n <= w[2] then t_test = true end end
  if test then test:set_value(t_test and 1 or 0) end
  for _, a in ipairs(appuis) do if n >= a[1] and n < a[1] + a[3] then tenus[a[2]] = true end end
  for k, c in pairs(champs) do c:set_value(tenus[k] and 1 or 0) end
  local on = nil
  for _, d in ipairs(dsw) do if n >= d[1] then on = d[2] end end
  if on and on ~= dsw_pose then
    dsw_pose = on
    for _, f in ipairs(dsw_champs) do f.user_value = (~on) & f.mask end
    W("f%d DSW %02X", n, on)
  end
  local u = string.format("%02X/%02X", p:read_u8(0x10FDAF), p:read_u8(0x10FDAE))
  if u ~= _G.SONJIG.user then
    if u:sub(1, 2) == "01" then remise = n W("f%d REMISE", n) end
    _G.SONJIG.user = u W("f%d user=%s", n, u)
  end
  if remise and remises[n - remise] then
    local f = io.open(string.format("%s/r%05d.bin", OUT, n - remise), "wb") f:write((ecran:pixels())) f:close()
    W("f%d IMAGE r%05d", n, n - remise)
  end
  local extra = {}
  if n >= H0 and n <= H1 then
    local px = ecran:pixels()
    extra[#extra + 1] = "img=" .. hache(px)
    for k, z in ipairs(zones) do extra[#extra + 1] = string.format("z%d=%d", k, hache_zone(px, z)) end
  end
  for _, s in ipairs(suivre) do
    extra[#extra + 1] = string.format("m%06X=%X", s[1], s[2] == 1 and p:read_u8(s[1]) or p:read_u16(s[1])) end
  if fixB then extra[#extra + 1] = string.format("fixB=%d-%d,%d-%d", fixB[1], fixB[2], fixB[3], fixB[4]) fixB = nil end
  W("f%d son=%s bas=%s ym=%d fm=%d aa=%d ab=%d ssg=%d palB=%d palJ=%d vrB=%d vrJ=%d t=%.5f cote=%s%s", n,
    table.concat(son, ","), table.concat(bascules, ","), ym.w, ym.fm, ym.adpcma, ym.adpcmb, ym.ssg,
    pal.B, pal.J, fixw.B, fixw.J, m.time:as_double(), src(), #extra > 0 and (" " .. table.concat(extra, " ")) or "")
  if #banques > 0 then W("f%d BANQUES %s", n, table.concat(banques, ",")) banques = {} end
  local r = p:read_u8(0x320000)
  if r ~= reponse then reponse = r W("f%d REPONSE %02X", n, r) end
  son, bascules = {}, {}
  for t, v in (os.getenv("J_INJ") or ""):gmatch("(%d+):(%x+)") do
    if tonumber(t) == n then _G.SONJIG.inj = true p:write_u8(0x320000, tonumber(v, 16)) _G.SONJIG.inj = false
      W("f%d INJ %s", n, v) end end
  for _, x in ipairs(poses) do
    if x[1] == n then
      for i = 0, #x[3] // 2 - 1 do p:write_u8(x[2] + i, tonumber(x[3]:sub(2 * i + 1, 2 * i + 2), 16)) end
      W("f%d POSE %06X=%s", n, x[2], x[3])
    end
  end
  for _, x in ipairs(bram) do
    if x[1] == n then
      local sh = m.memory.shares[":saveram"]
      for i = 0, #x[3] // 2 - 1 do sh:write_u8(x[2] + i, tonumber(x[3]:sub(2 * i + 1, 2 * i + 2), 16)) end
      W("f%d BRAM %06X=%s", n, x[2] + 0xD00000, x[3])
    end
  end
  son = {}
  ym = { w = 0, fm = 0, adpcma = 0, adpcmb = 0, ssg = 0 }
  pal = { B = 0, J = 0 } fixw = { B = 0, J = 0 }
  if textes[n] then for row = 2, 29 do W("f%d fix%02d |%s|", n, row, ligne(row)) end end
  if tuiles[n] then
    for row = 2, 29 do
      local l = {}
      for col = 0, 39 do l[#l + 1] = string.format("%04X", X.v[0x7000 + col * 32 + row] or 0) end
      W("f%d tu%02d %s", n, row, table.concat(l, " "))
    end
  end
  if dumps[n] then
    local sg = m.devices[":spritegen"] local vr = emu.item(sg.items["0/m_videoram"])
    local t = {} for i = 0, vr.count - 1 do t[#t + 1] = string.pack(">I2", vr:read(i)) end
    local f = io.open(string.format("%s/d%05d-vram.bin", OUT, n), "wb") f:write(table.concat(t)) f:close()
    t = {} for a = 0x400000, 0x401FFF, 2 do t[#t + 1] = string.pack(">I2", p:read_u16(a)) end
    f = io.open(string.format("%s/d%05d-pal.bin", OUT, n), "wb") f:write(table.concat(t)) f:close()
  end
  if images[n] then
    local f = io.open(string.format("%s/f%05d.bin", OUT, n), "wb") f:write((ecran:pixels())) f:close()
  end
  if n >= FIN then out:close() m:exit() end
end)
