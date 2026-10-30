-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- Floating-bus jig, no window: MAME served like the hardware the wiki describes, where the
-- cartridge answers only under REG_CRTFIX. To judge a BIOS on what MAME, more permissive,
-- does not show (hardware feedback of 2026-10-24, `docs/ESSAI-MATERIEL.md`, test 1).
--
--   SDL_VIDEODRIVER=dummy SDL_MAC_BACKGROUND_APP=1 BF_OUT=<sortie.tsv> \
--   mame ng_mv2f -bios euro -hashpath <mame>/hash -rompath <roms> -cart1 mslug \
--     -video none -sound none -nothrottle -nvram_directory <neuf> \
--     -autoboot_script bench/bus-flottant.lua
--
-- THE MODEL, and where it comes from (NeoGeo Development Wiki, consulted on 2026-10-24):
--   - "MVS cartridge pinout", SLOTCS: "SLOTCS goes low when the slot is used", "On
--     multi-slot boards, the signals come from NEO-F0 SLOT0~5. On one slot boards, it's tied to
--     SYSTEMB", and "The System ROM was written to ensure the signal is asserted when it does
--     the slot check";
--   - "NEO-F0": "SYSTEMB is used to gate the SLOT* outputs";
--   - "Signals": "SYSTEM: low when onboard ROMs selected", "SYSTEMB: inverted SYSTEM" —
--     the board's ROMs being the SFIX and the SM1 that REG_BRDFIX ($3A000B) selects, REG_CRTFIX
--     ($3A001B) selecting those of the cartridge ("Memory mapped registers").
-- Hence, ASSUMED in its exact form: under REG_BRDFIX, no slot is selected and nothing
-- holds the bus on $000000-$0FFFFF nor on $200000-$2FFFFF — except $000000-$00007F under
-- REG_SWPBIOS, which the board serves from the BIOS. MEASURED on an MV-2F (hardware test, 2026-10-24): our
-- image no. 8 reads $000108 under REG_BRDFIX and finds E05C there, whatever the cartridge, and the
-- word following its `move.w 0x108,%d4` in `ecran.s` is E05C. MEASURED under MAME (`acces-boot.lua`):
-- the reference writes REG_CRTFIX just before reading the header of each slot, and REG_BRDFIX after.
--
-- WHAT THE JIG RETURNS for a floating read: the word at the PC's address — what MAME returns
-- itself for a hole in the map (`unmapped_r`: "the last word on the data bus, which is
-- almost always the opcode of the next instruction due to prefetch"). The state of the latches at
-- reset is MAME's (HC259 at zero: BRDFIX, BIOS vectors).
--
-- Settings through the environment:
--   BF_OUT     output TSV (mandatory)
--   BF_FIN     last frame (default 900)
--   BF_IMAGES  frames at which to write the raw screen (bgra, 320 × 224) into BF_DIR, comma-separated
--   BF_DIR     folder of the captures (default: that of BF_OUT)
--   BF_TEST    <de>-<a>: the TEST button held over these frames (the boot soft-DIP editor)
--   BF_LIBRE   1: falsifies nothing — the same record on the original MAME, as a witness
--   BF_SLOT_MAX n: bounds REG_SLOT for MAME (see below), 6 for the diagnostic image
--   BF_ABSENTE n: the cartridge returns $FFFF, what MAME returns for an empty slot, over its frames 0 to
--              n-1, under either latch — a flash cart still loading its menu at
--              power-on (hardware feedback of 2026-10-28, `docs/ESSAI-MATERIEL.md`).
--              ASSUMED: what a flash cart returns during that time, and for how long it
--              returns it; none of it is measured. A floating read under REG_BRDFIX is still counted and
--              returned as such: only the served cartridge is silent
--   BF_HOTE    1: loaded by another jig (`son.lua`, J_FLOTTANT), which plays the inputs and quits
--              MAME: this jig does not touch them, and at BF_FIN it writes its summary without quitting
--
-- WHAT IS RECORDED — this jig logs no PC nor any byte of the BIOS ROM (`docs/DECISIONS.md`
-- §8): the PC is read only to tell who reads (bios in $C00000-$C1FFFF, game otherwise) and to return the prefetched word.
-- Lines: F (falsified reads, per frame and per side, the first 40 with their address), R
-- (machine reset, watchdog included), J (the game has control at the end of the frame — PC below
-- $100000 — for the first time since the last reset), B (latch changed), and a summary
-- that counts the frames finished in the game.
if _G.BUSFLOTTANT then return end
_G.BUSFLOTTANT = {}
local G = _G.BUSFLOTTANT
local m = manager.machine
local OUT = os.getenv("BF_OUT")
if not OUT then print("BUSFLOTTANT: BF_OUT manquant") m:exit() return end
local FIN = tonumber(os.getenv("BF_FIN") or "900")
local DIR = os.getenv("BF_DIR") or OUT:match("^(.*)/[^/]*$") or "."
local LIBRE = os.getenv("BF_LIBRE") == "1"
local HOTE = os.getenv("BF_HOTE") == "1"
local ABSENTE = tonumber(os.getenv("BF_ABSENTE") or "0")
local fini = false
local images = {}
for k in (os.getenv("BF_IMAGES") or ""):gmatch("%d+") do images[tonumber(k)] = true end
local test_de, test_a = (os.getenv("BF_TEST") or ""):match("^(%d+)-(%d+)$")
test_de, test_a = tonumber(test_de), tonumber(test_a)
local cpu = m.devices[":maincpu"]
local p = cpu.spaces["program"]
local ecran = m.screens[":screen"]
local f = io.open(OUT, "w")
f:write("trame\tgenre\tadresse\tcote\tnote\n")

local trame, interne = 0, false
local carte_rom, vecteurs = "BRDFIX", "SWPBIOS"
local faux = { bios = 0, jeu = 0 }
local faux_trame = { bios = 0, jeu = 0 }
local faux_detail, resets, trames_jeu, jeu_vu = 0, 0, 0, false

local function pc() return cpu.state["PC"].value & 0xFFFFFF end
local function cote() local a = pc() return (a >= 0xC00000 and a <= 0xC1FFFF) and "bios" or "jeu" end
local function ligne(g, adr, c, note) if fini then return end f:write(string.format("%d\t%s\t%s\t%s\t%s\n", trame, g, adr, c, note or "")) end

-- The latches in pairs, bit 4 of the address being the data ("Memory mapped registers"):
-- $3A0003/$3A0013 the vectors, $3A000B/$3A001B the ROMs of the fix layer and of the Z80.
G.t_sys = p:install_write_tap(0x3A0000, 0x3BFFFF, "bf_sys", function(off, data, mask)
  local k = off & 0x0F
  if k == 0x0A then
    local v = (off & 0x10) ~= 0 and "CRTFIX" or "BRDFIX"
    if v ~= carte_rom then carte_rom = v ligne("B", string.format("%06X", (off & 0xFFFFFF) | 1), cote(), v) end
  elseif k == 0x02 then
    vecteurs = (off & 0x10) ~= 0 and "SWPROM" or "SWPBIOS"
  end
end)

local function flotte(off)
  if LIBRE or carte_rom == "CRTFIX" then return false end
  if off < 0x80 then return vecteurs == "SWPROM" end
  return off < 0x100000 or (off >= 0x200000 and off < 0x300000)
end

local function lecture(off, data, mask)
  if interne then return end
  local c = cote()
  if not flotte(off) then
    if trame < ABSENTE and (off >= 0x80 or vecteurs == "SWPROM") then return 0xFFFF end
    return
  end
  faux[c] = faux[c] + 1
  faux_trame[c] = faux_trame[c] + 1
  if faux_detail < 40 then
    faux_detail = faux_detail + 1
    ligne("F", string.format("%06X", off), c, "lecture flottante")
  end
  interne = true
  local v = p:read_u16(pc() & 0xFFFFFE)
  interne = false
  if mask == 0xFF00 then return (v & 0xFF00) | (data & 0x00FF) end
  if mask == 0x00FF then return (data & 0xFF00) | (v & 0x00FF) end
  return v
end

G.t_p1 = p:install_read_tap(0x000000, 0x0FFFFF, "bf_p1", lecture)
G.t_p2 = p:install_read_tap(0x200000, 0x2FFFFF, "bf_p2", lecture)

-- A WRITE TO REG_SLOT DROPS THE P-ROM TAPS (MAME reinstalls the slot's ROM there,
-- `set_slot_idx`): set again two BIOS reads later, the recipe of `multislot.lua`.
-- BF_SLOT_MAX=n: a write to REG_SLOT beyond n-1 becomes n-1. MAME 0.286 indexes its
-- array of six slots by the data without bounding it (`mvs_state::io_control_w`, `m_slots[data]`):
-- 6 and 7 make it exit with a segmentation fault, measured with the diagnostic image. On
-- ng_mv2f, 5 is not mounted and MAME then keeps the previous slot, as for 2 to 4.
local SLOT_MAX = tonumber(os.getenv("BF_SLOT_MAX") or "")
G.t_io = p:install_write_tap(0x380000, 0x39FFFF, "bf_io", function(off, data, mask)
  if (off & 0xF0) ~= 0x20 or mask & 0xFF == 0 then return end
  G.retaper, G.attente = true, 2
  if SLOT_MAX and (data & 0xFF) >= SLOT_MAX then return (data & 0xFF00) | (SLOT_MAX - 1) end
end)
G.t_c0 = p:install_read_tap(0xC00000, 0xC1FFFF, "bf_c0", function()
  if not G.retaper then return end
  G.attente = G.attente - 1
  if G.attente > 0 then return end
  G.retaper = false
  G.t_p1:reinstall() G.t_p2:reinstall()
end)

-- A machine reset (the watchdog included) sets the HC259 back to zero in MAME: BRDFIX, BIOS
-- vectors. The first reset, the power-on one, is not counted.
G.reset = emu.add_machine_reset_notifier(function()
  carte_rom, vecteurs, jeu_vu = "BRDFIX", "SWPBIOS", false
  if trame > 0 then resets = resets + 1 ligne("R", "-", "-", "reset de la machine") end
end)

local test = nil
for _, port in pairs(m.ioport.ports) do
  for _, fld in pairs(port.fields) do if fld.name == "Service Mode" or fld.name == "Test Switch" then test = test or fld end end
end

emu.register_frame_done(function()
  if fini then return end
  if pc() < 0x100000 then
    trames_jeu = trames_jeu + 1
    if not jeu_vu then jeu_vu = true ligne("J", "-", "jeu", "le jeu a la main (" .. carte_rom .. ")") end
  end
  if faux_trame.bios + faux_trame.jeu > 0 then
    ligne("F", "-", "-", string.format("trame : %d par le bios, %d par le jeu", faux_trame.bios, faux_trame.jeu))
    faux_trame.bios, faux_trame.jeu = 0, 0
  end
  if images[trame] then
    local g = io.open(string.format("%s/f%05d.bin", DIR, trame), "wb") g:write(ecran:pixels()) g:close()
  end
  f:flush()
  trame = trame + 1
  if test and test_de then
    if trame == test_de then test:set_value(1) end
    if trame == test_a then test:set_value(0) end
  end
  if trame > FIN then
    f:write(string.format("#\tbilan\t%d trames, %d resets, %d trames finies dans le jeu, lectures flottantes : %d bios, %d jeu, bascule finale %s%s\n",
      trame, resets, trames_jeu, faux.bios, faux.jeu, carte_rom, LIBRE and " (BF_LIBRE : rien de fausse)" or ""))
    f:close()
    fini = true
    if not HOTE then m:exit() end
  end
end)
