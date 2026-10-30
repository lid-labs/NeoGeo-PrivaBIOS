-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- Boot-access jig, windowless: the ordered list of ALL the 68000's accesses to the registers
-- ($300000-$3FFFFF) and to the P-ROM space ($000000-$0FFFFF), from reset up to the first read of
-- "NE" at $000100 (the start of "NEO-GEO"), then up to the end of that frame.
-- Written to compare, access by access, what the reference and our image do before reading a
-- cartridge's header (hardware feedback of 2026-10-24, docs/ESSAI-MATERIEL.md).
--
--   SDL_VIDEODRIVER=dummy SDL_MAC_BACKGROUND_APP=1 AB_OUT=<sortie.tsv> \
--   mame ng_mv2f -bios euro -hashpath <mame>/hash -rompath <roms> -cart1 mslug \
--     -video none -sound none -nothrottle -nvram_directory <neuf> \
--     -autoboot_script bench/acces-boot.lua
--
-- Settings through the environment:
--   AB_OUT     output TSV (mandatory)
--   AB_FIN     stop frame if "NE" is never read (default 900)
--   AB_APRES   frames still recorded after the "NE" one, BIOS accesses only (default 0): the
--              rest of the slot walk and the return to the screen
--   AB_FLOTTANT 1: SIMULATES THE HARDWARE as the wiki describes it (NEO-F0: "SYSTEMB is used to
--              gate the SLOT* outputs"; Signals: "SYSTEM: low when onboard ROMs selected"):
--              any read of $000080-$0FFFFF and $200000-$2FFFFF made while the BRDFIX/CRTFIX
--              switch is on BRDFIX ($3A000B, the reset state) returns the word at the PC's
--              address — the floating bus that MAME itself returns for a hole (`unmapped_r`). The
--              reads thus falsified are counted (kind F in the summary). ASSUMED: that the reset
--              state is BRDFIX; the wiki does not say so, and the reference writes one or the
--              other before reading the header (record of this jig).
--
-- WHAT IS RECORDED — addresses, widths, WRITTEN values and values read in the registers and in
-- the GAME's P-ROM. This jig logs no PC, nor any byte of the BIOS ROM: the reads of
-- $000000-$00007F, which the board serves from the BIOS under REG_SWPBIOS, come out without data,
-- like the VRAM data ($3C0002, counted only). The PC is read only to say WHO accesses (bios in
-- $C00000-$C1FFFF, game otherwise) and to return the prefetched word of a falsified read —
-- `docs/DECISIONS.md` §8.
--
-- Columns: n (rank), frame, frame fraction, kind (R/W), address of the BYTE (the even one for a
-- word), width (o even byte, i odd byte, m word), data, identical consecutive repetitions, side.
-- Identical consecutive accesses (same kind, address, width, data, side) merge into one line:
-- waiting on a register in a loop fits on one.
if _G.ACCESBOOT then return end
_G.ACCESBOOT = {}
local G = _G.ACCESBOOT
local OUT = os.getenv("AB_OUT")
local m = manager.machine
if not OUT then print("ACCESBOOT: AB_OUT manquant") m:exit() return end
local FIN = tonumber(os.getenv("AB_FIN") or "900")
local APRES = tonumber(os.getenv("AB_APRES") or "0")
local trame_ne = nil
local FLOTTANT = os.getenv("AB_FLOTTANT") == "1"
local cpu = m.devices[":maincpu"]
local p = cpu.spaces["program"]
local f = io.open(OUT, "w")
f:write("n\ttrame\tfraction\tgenre\tadresse\tlargeur\tdonnee\trepet\tcote\n")

local trame, t0, PERIODE = 0, 0, 1 / 59.185
local n, der, vu_ne = 0, nil, false
local carte_fix = "BRDFIX?"          -- the switch's state, ASSUMED BRDFIX at reset
local faussees, interne = 0, false

local function pc() return cpu.state["PC"].value & 0xFFFFFF end
local function cote() local a = pc() return (a >= 0xC00000 and a <= 0xC1FFFF) and "bios" or "jeu" end

local function vider()
  if der then
    f:write(string.format("%d\t%d\t%.3f\t%s\t%06X\t%s\t%s\t%d\t%s\n", der.n, der.t, der.fr, der.g,
      der.a, der.l, der.d, der.r, der.c))
    der = nil
  end
end

local function noter(g, off, data, mask)
  if vu_ne and (trame > trame_ne + APRES or cote() ~= "bios") then return end
  local a, l, d
  if mask == 0xFFFF then a, l, d = off, "m", string.format("%04X", data & 0xFFFF)
  elseif mask == 0xFF00 then a, l, d = off, "o", string.format("%02X", (data >> 8) & 0xFF)
  else a, l, d = off + 1, "i", string.format("%02X", data & 0xFF) end
  if off < 0x80 and g == "R" then d = "-" end            -- vectors: BIOS ROM under SWPBIOS
  if off >= 0x3C0002 and off <= 0x3C0003 then d = "-" end -- VRAM data: counted only
  local c = cote()
  if der and der.g == g and der.a == a and der.l == l and der.d == d and der.c == c then
    der.r = der.r + 1 return
  end
  vider()
  n = n + 1
  der = { n = n, t = trame, fr = (m.time:as_double() - t0) / PERIODE, g = g, a = a, l = l, d = d,
    r = 1, c = c }
end

-- The BRDFIX ($3A000B) / CRTFIX ($3A001B) switch, tracked for AB_FLOTTANT: bit 4 of the address
-- ("Registers go in pairs, bit 4 of the address is actually the data bit").
G.t_sys = p:install_write_tap(0x3A0000, 0x3BFFFF, "ab_sys", function(off, data, mask)
  if (off & 0x0F) == 0x0A then carte_fix = (off & 0x10) ~= 0 and "CRTFIX" or "BRDFIX" end
end)

local function flotte(off)
  if not FLOTTANT or carte_fix == "CRTFIX" then return false end
  if off < 0x80 then return false end
  return off < 0x100000 or (off >= 0x200000 and off < 0x300000)
end

-- A WRITE TO REG_SLOT DROPS THE P-ROM TAPS: MAME reinstalls the slot's ROM there
-- (`set_slot_idx`, `unmap_readwrite` then `install_rom` on $000080-$0FFFFF). We put them back two
-- BIOS reads later, when the new slot's handler is in place — the recipe of `multislot.lua`.
G.t_rw = p:install_write_tap(0x300000, 0x3FFFFF, "ab_rw", function(off, data, mask)
  noter("W", off, data, mask)
  if (off & 0xFE00F0) == 0x380020 and mask & 0xFF ~= 0 then G.retaper, G.attente = true, 2 end
end)
G.t_rr = p:install_read_tap(0x300000, 0x3FFFFF, "ab_rr", function(off, data, mask)
  if interne then return end
  noter("R", off, data, mask)
end)
G.t_pw = p:install_write_tap(0x000000, 0x0FFFFF, "ab_pw", function(off, data, mask)
  noter("W", off, data, mask)
end)
G.t_pr = p:install_read_tap(0x000000, 0x0FFFFF, "ab_pr", function(off, data, mask)
  if interne then return end
  local c = cote()
  if flotte(off) then
    interne = true
    local v = p:read_u16(pc() & 0xFFFFFE)  -- the prefetched word, like MAME's `unmapped_r`
    interne = false
    faussees = faussees + 1
    data = v
  end
  -- The running game is no longer recorded: only its reads before the end of the frame count.
  if c == "bios" or not vu_ne then noter("R", off, data, mask) end
  if off == 0x100 and c == "bios" and (data & 0xFFFF) == 0x4E45 and not vu_ne then
    vu_ne = true
    vider()
    f:write(string.format("#\t%d\tpremiere lecture de NE en $000100 (rang %d), bascule %s\n", trame, n, carte_fix))
    trame_ne = trame
  end
  if flotte(off) then return data end
end)
if FLOTTANT then
  G.t_p2 = p:install_read_tap(0x200000, 0x2FFFFF, "ab_p2", function(off, data, mask)
    if interne or not flotte(off) then return end
    interne = true
    local v = p:read_u16(pc() & 0xFFFFFE)
    interne = false
    faussees = faussees + 1
    return v
  end)
end

G.t_c0 = p:install_read_tap(0xC00000, 0xC1FFFF, "ab_c0", function()
  if not G.retaper then return end
  G.attente = G.attente - 1
  if G.attente > 0 then return end
  G.retaper = false
  for _, k in ipairs({ "t_pr", "t_pw", "t_p2" }) do if G[k] then G[k]:reinstall() end end
end)

emu.register_frame_done(function()
  t0 = m.time:as_double()
  trame = trame + 1
  if (trame_ne and trame > trame_ne + APRES) or trame > FIN then
    vider()
    f:write(string.format("#\tbilan\ttrames %d, accès relevés %d, NE vu %s, lectures faussées (F) %d, bascule finale %s\n",
      trame, n, tostring(vu_ne), faussees, carte_fix))
    f:close()
    m:exit()
  end
end)
