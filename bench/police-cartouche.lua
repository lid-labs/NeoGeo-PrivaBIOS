-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- Jig of the CARTRIDGE's font, no window: does the S ROM store digits, capitals,
-- space and ": - / ." at the SFIX's tile numbers? A question from the jukebox, which will display text
-- under REG_CRTFIX (the fix layer then reads the S ROM) because the game's sound driver is running.
--
-- NO ROM byte is read, neither from the cartridge nor from the board: a test pattern is set in the fix
-- layer and the SCREEN is read. The same pattern is rendered twice, from the S ROM then from the SFIX,
-- by switching only the source of the fix layer (item `0/m_fixed_layer_source` of `:spritegen`, which
-- REG_BRDFIX / REG_CRTFIX set in MAME). REG_BRDFIX itself is not touched: it also switches
-- the Z80's M1 (`src/c0/dip.s`), and the game would lose its sound driver between two captures.
--
-- THE TEST PATTERN. 41 glyphs: 0-9, A-Z, space, ": - / .". In 8×8, tile = ASCII code; in 8×16,
-- tile $100 + ASCII at the top, $200 + ASCII at the bottom (measured/2026-10-20-sfix-glyphes.tsv). All
-- the cells under palette 15. 21 glyphs per line, columns 4 to 24:
--   8×8: rows 6 and 8 of the fix layer;  8×16: rows 12-13 and 16-17 (two lines are enough).
--
-- THE COLOUR INDEXES, decoded to the pixel by five captures and not guessed. At capture "plane b"
-- (b = 0..3), entry i of palette 15 is magenta if bit b of i is 1, cyan otherwise; at the
-- "witness" capture, all entries 1-15 are yellow. A pixel that is yellow in the witness and magenta or
-- cyan in the four planes carries the index that its four bits spell; any other pixel is index 0,
-- transparent, through which the game is seen. The decoding is done outside MAME (analysis script) on
-- the raw captures: this jig only writes pictures.
--
-- THE GAME KEEPS RUNNING, and it rewrites fix layer and palettes. Two taps replace the data
-- of any game write that would fall in a cell of the pattern (VRAM address read in the item
-- `m_vram_offset`, the one the write is going to touch) or in palette 15 ($4001E0-$4001FF, whatever
-- the bank). And the wanted state is rewritten at each end of frame, in the current bank.
-- A game that changed bank during the sequence would show palette 15 of the other bank,
-- without our colours, and its pixels would pass for index 0: a tap therefore counts the writes
-- to REG_PALBANK0 / REG_PALBANK1 ($3A000F / $3A001F) that change bank during the sequence,
-- and a non-zero count invalidates the run. (The item `0/m_palette_bank` of the machine does not allow
-- writing both banks: measured on 2026-10-21, on aof and kof98 this name designates a byte that
-- is 6 or 0, not the bank.)
--
-- SEQUENCE, from frame P_DEBUT (default 1200, the game is in attract). Each state is
-- held TENIR = 3 frames and captured at the end of the third. Measured on mslug on 2026-10-21: a
-- capture taken at the end of the frame that follows the setting still shows the previous state (the picture that
-- `pixels()` returns lags by one frame); holding three frames leaves one frame of margin.
--   DEBUT          : record of the fix-layer source as the game left it (1 expected)
--   then 5 states  : S ROM, planes 0-3 then witness    → P_OUT/cart-{p0,p1,p2,p3,t}.bin
--   then 5 states  : SFIX, same five captures          → P_OUT/sfix-{p0,p1,p2,p3,t}.bin
-- Each .bin is MAME's raw screen (32 bits per pixel, 320×224). P_OUT/releve.txt carries
-- the fix-layer source recorded at P_DEBUT, and the count of palette bank switches.
--
--   P_OUT    output folder (mandatory)
--   P_DEBUT  start frame (default 1200)
--   P_OCTETS a list of bytes in hexadecimal ("00 16 80 A7 …"). Given, it REPLACES the pattern of the
--            41 glyphs: each byte b is set in 8×16 at $300 + b (top), $400 + b (bottom), 21 per
--            line, columns 4 to 24, rows 8-9, 12-13, 16-17… The bank of the board's Japanese
--            font (measured/2026-10-27-intitules-japon.tsv). Absent: the original pattern.
--   P_BANQUE with P_OCTETS: the top bank, 3 by default (1: $100 + b at the top, $200 + b at the bottom,
--            the ASCII font — the witness of the equivalence of the two banks)
--
-- No input is pressed. New NVRAM: it is up to the launcher to provide it.
--   SDL_VIDEODRIVER=dummy SDL_MAC_BACKGROUND_APP=1 P_OUT=<dossier> mame <jeu> -bios euro \
--     -video none -sound none -nothrottle -nvram_directory <neuve> -autoboot_script bench/police-cartouche.lua
if _G.POLICE then return end -- the script is reread at each reset: install only once
_G.POLICE = {}
local OUT = os.getenv("P_OUT")
if not OUT then print("POLICE: P_OUT manquant") manager.machine:exit() return end
local DEBUT = tonumber(os.getenv("P_DEBUT") or "1200")
local m = manager.machine
local p = m.devices[":maincpu"].spaces["program"]
local ecran = m.screens:at(1)
local sg = m.devices[":spritegen"]
local vram = emu.item(sg.items["0/m_videoram"])
local voff = emu.item(sg.items["0/m_vram_offset"])
local source = emu.item(sg.items["0/m_fixed_layer_source"])

local GLYPHES = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ :-/."
local PAL = 15
-- Neo Geo colours: bit 15 "dark", bits 14-12 the low bits of R, G, B, then R, G, B on 4 bits.
local MAGENTA, CYAN, JAUNE = 0x5F0F, 0x30FF, 0x6FF0

-- The test pattern: fix-layer VRAM address ($7000 + column × 32 + row) → entry (palette, tile).
local mire = {}
local OCTETS = os.getenv("P_OCTETS")
if OCTETS then
  local BQ = tonumber(os.getenv("P_BANQUE") or "3") << 8
  local i = 0
  for h in OCTETS:gmatch("%x+") do
    local c = tonumber(h, 16)
    local col, k = 4 + i % 21, i // 21
    local l16 = 8 + 4 * k
    mire[0x7000 + col * 32 + l16] = (PAL << 12) | (BQ + c)
    mire[0x7000 + col * 32 + l16 + 1] = (PAL << 12) | (BQ + 0x100 + c)
    i = i + 1
  end
else
  for i = 1, #GLYPHES do
    local c = GLYPHES:byte(i)
    local col, k = 4 + (i - 1) % 21, (i - 1) // 21
    local l8, l16 = 6 + 2 * k, 12 + 4 * k
    mire[0x7000 + col * 32 + l8] = (PAL << 12) | c
    mire[0x7000 + col * 32 + l16] = (PAL << 12) | (0x100 + c)
    mire[0x7000 + col * 32 + l16 + 1] = (PAL << 12) | (0x200 + c)
  end
end

-- The state of palette 15 wanted for the next render: nil as long as the sequence has not started.
local couleurs = nil
local function couleurs_plan(b)
  local t = { [0] = 0 }
  for i = 1, 15 do t[i] = ((i >> b) & 1) == 1 and MAGENTA or CYAN end
  return t
end
local function couleurs_temoin()
  local t = { [0] = 0 }
  for i = 1, 15 do t[i] = JAUNE end
  return t
end

local actif = false -- the taps replace only once the sequence has started
_G.POLICE.tvram = p:install_write_tap(0x3C0002, 0x3C0003, "mire", function(o, d, mk)
  if not actif then return end
  local v = mire[voff:read(0)]
  if v then return v end
end)
_G.POLICE.tpal = p:install_write_tap(0x400000 + PAL * 32, 0x400000 + PAL * 32 + 31, "pal", function(o, d, mk)
  if not actif or not couleurs then return end
  return couleurs[(o & 31) >> 1]
end)

-- Many games rewrite the same bank at each frame: only a CHANGE of bank counts.
local bascules, derniere = 0, nil
_G.POLICE.tbanque = p:install_write_tap(0x3A000E, 0x3A001F, "banque", function(o, d, mk)
  if (o ~= 0x3A000E and o ~= 0x3A001E) or (mk & 0x00FF) == 0 then return end
  if actif and derniere and derniere ~= o then bascules = bascules + 1 end
  derniere = o
end)

local function poser()
  for a, v in pairs(mire) do vram:write(a, v) end
  for i = 0, 15 do p:write_u16(0x400000 + PAL * 32 + 2 * i, couleurs[i]) end
end

-- The ten captures: (fix-layer source, colours, file name).
local etapes = {}
for _, s in ipairs({ { 1, "cart" }, { 0, "sfix" } }) do
  for b = 0, 3 do etapes[#etapes + 1] = { s[1], couleurs_plan(b), s[2] .. "-p" .. b } end
  etapes[#etapes + 1] = { s[1], couleurs_temoin(), s[2] .. "-t" }
end

local out = io.open(OUT .. "/releve.txt", "w")
local function W(fmt, ...) out:write(string.format(fmt, ...) .. "\n") out:flush() end
local TENIR = 3
local n, e = 0, 0
emu.register_frame_done(function()
  n = n + 1
  if n < DEBUT then return end
  if n == DEBUT then
    W("f%d source_plan_fixe=%d (1 = S ROM, REG_CRTFIX)", n, source:read(0))
    actif = true
  elseif (n - DEBUT) % TENIR ~= 0 then
    poser() -- the state is held: rewritten at each frame, against the game's writes
    return
  else
    local f = io.open(string.format("%s/%s.bin", OUT, etapes[e][3]), "wb")
    f:write((ecran:pixels())) f:close()
  end
  e = e + 1
  if e > #etapes then
    W("f%d fin bascules_banque_palettes=%d", n, bascules)
    out:close() m:exit() return
  end
  source:write(0, etapes[e][1])
  couleurs = etapes[e][2]
  poser()
end)
