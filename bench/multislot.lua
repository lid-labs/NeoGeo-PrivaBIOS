-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- Multi-slot jig, no window: what the BIOS does on a board with several slots
-- (MAME's `neogeo` machine is an MV-6F, `-cart1` … `-cart6`). Measurement only: it
-- presses only the inputs it is given, and touches nothing else — except, if asked
-- to, the bytes that MS_POSER writes into the game's RAM.
--
--   SDL_VIDEODRIVER=dummy SDL_MAC_BACKGROUND_APP=1 MS_OUT=<sortie.tsv> \
--   mame neogeo -bios euro -hashpath <mame>/hash -rompath $ROMS \
--     -cart1 puzzledp -cart2 aof -video none -sound none -nothrottle \
--     -nvram_directory <neuf> -autoboot_script bench/multislot.lua
--
-- The games are named through the `neogeo` software list; without `-hashpath` to MAME's
-- `hash/`, it cannot be found and `-cart1 puzzledp` fails ("No such file or directory").
--
-- Settings through the environment, since an autoboot lua receives no arguments:
--   MS_OUT        output TSV (mandatory), one line per event
--   MS_FIN        last frame (default 6000); the machine stops just after
--   MS_ENTREES    inputs to press, "frame:name[:duration]" separated by commas, duration 8 by
--                 default. Names: piece, start, start2, suivant, precedent (the two game
--                 selection buttons of an MVS, "Next Game" / "Previous Game" in MAME), a, test
--   MS_IMAGES     frames at which to write the raw screen (bgra, 320 × 224) into MS_DIR, separated by
--                 commas
--   MS_DIR        folder of the captures (default: that of MS_OUT)
--   MS_CAPT_USER  n: a capture n frames after each hand-over of control to the USER entry
--                 ($000122), 60 at most — the screen of the game the BIOS has just launched
--   MS_PLAFOND    lines at most per noisy address (default 200, see "the noise")
--   MS_SONDE_PROM 1: also records the ranges of the cartridge's P-ROM that the BIOS reads
--   MS_DETAIL     <de>-<a>: each read by the BIOS outside its ROM and the work RAM, over
--                 these frames (see below)
--   MS_SONDE_M1   1: the M1 the Z80 sees (slot recognised), under REG_CRTFIX only (see below)
--   MS_LECT_JEU   1: the reads the GAME makes in $D00000-$D003FF (system zone of the backup
--                 RAM), counted per address and output in the summary (kind R, "lu par jeu") — to
--                 know whether a game reads a cell that the BIOS keeps there
--   MS_PLAGES     1: the game saves, as ranges per frame (kind P, see below), and
--                 each entry of SYSTEM_RETURN with its code (line E "C00444")
--   MS_VIDAGES    frames at which to write the save zone of the served game and its backup RAM block,
--                 in hexadecimal, into MS_DIR (see below)
--   MS_POSER      <trame>@<adresse>=<octets hex>, separated by commas: writes these bytes
--                 into the game's work RAM at the end of the frame (see below)
--   MS_SUIVRE     hexadecimal addresses of RAM or backup RAM bytes, separated by
--                 commas ($100000-$10FFFF and $D00000-$D0FFFF only): at the end of the frame, one
--                 E line per byte whose value has changed — the credit $D00034, the mode and the
--                 request $10FDAF/$10FDAE through a gesture, without depending on who writes them
--
-- WHAT IS RECORDED — register and RAM addresses with the values written; this jig logs
-- no PC nor any byte read in the BIOS ROM (`docs/DECISIONS.md` §8). The PC is read only to tell WHO
-- writes (bios if it is in $C00000-$C1FFFF, game otherwise), and only that side is written:
--   - the writes to $380000-$3800FF (REG_SLOT at $380021, EL/LED outputs…) and to the system
--     latches $3A0000-$3A001F (BRDFIX, CRTFIX, SWPROM, SRAMLOCK…);
--   - REG_SOUND: each write, and per frame the number of reads and how many returned $01,
--     the echo of "68k/Z80 communication";
--   - per frame, the number of reads of REG_STATUS_B ($380000), REG_P1CNT / REG_DIPSW
--     ($300000/1), REG_SYSTYPE ($300081) and REG_STATUS_A ($320001), when it changes;
--   - the reads of the cartridge header $000100-$00013F made by the BIOS, with the slot
--     that the NGH read at $000108 designates (compared with that of each region `:cslotN:maincpu`: only
--     the ROM of the GAMES is reread); the read of $000122, the USER entry, with the request and the
--     mode of the moment;
--   - the writes to backup RAM: one by one on $D00000-$D003FF, summarised beyond 400 per
--     frame (a fill: count and distinct values), counted per frame beyond that; a
--     value that could form an address of the BIOS ROM comes out "retenu" (see the guard);
--   - the writes to a few BIOS variables ($10FCEF, $10FD80-$10FD83, $10FDAE, $10FDAF,
--     $10FEE1), one line when the value changes for a given writer;
--   - at the end of the frame: the side that has control when it changes, and the slot whose
--     P-ROM MAME then serves (the NGH at $000108, reread by the jig outside the taps) when it changes.
--
-- Columns: frame, fraction of the frame elapsed (the screen does not give its line to lua, the
-- machine's clock does), kind (W write, R read, E state, I input, B noise summary), address,
-- value, last value written to REG_SLOT, note. The buffered lines (backup RAM,
-- header) come out at the end of the frame: sort on (frame, fraction) for the chronology.
if _G.MULTISLOT then return end
_G.MULTISLOT = {}
local G = _G.MULTISLOT
local OUT = os.getenv("MS_OUT")
if not OUT then print("MULTISLOT: MS_OUT manquant") manager.machine:exit() return end
local FIN = tonumber(os.getenv("MS_FIN") or "6000")
local DIR = os.getenv("MS_DIR") or OUT:match("^(.*)/[^/]*$") or "."
local PLAFOND = tonumber(os.getenv("MS_PLAFOND") or "200")
local CAPT_USER = tonumber(os.getenv("MS_CAPT_USER") or "")
local images = {}
for n in (os.getenv("MS_IMAGES") or ""):gmatch("%d+") do images[tonumber(n)] = true end
G.capt_prevues = {}

local m = manager.machine
local cpu = m.devices[":maincpu"]
local p = cpu.spaces["program"]
local ecran = m.screens:at(1)

-- The NGH of each mounted cartridge, read in the game's ROM ($108, BCD word of the header).
local ngh = {}
for k = 1, 6 do
  local r = m.memory.regions[":cslot" .. k .. ":maincpu"]
  if r then ngh[k] = (r:read_u8(0x108) << 8) | r:read_u8(0x109) end
end
local function slot_de(mot)
  local s = {}
  for k = 1, 6 do if ngh[k] and ngh[k] == mot then s[#s + 1] = tostring(k - 1) end end
  return #s > 0 and table.concat(s, "+") or "aucun"
end

local f = io.open(OUT, "w")
f:write("trame\tfraction\tgenre\tadresse\tvaleur\tslot\tnote\n")
local cartes = {}
for k = 1, 6 do
  local r = m.memory.regions[":cslot" .. k .. ":maincpu"]
  cartes[#cartes + 1] = ngh[k] and string.format("%d:%04X(sauv %06X+%04X)", k - 1, ngh[k],
    (r:read_u8(0x10F) << 16) | (r:read_u8(0x110) << 8) | r:read_u8(0x111),
    (r:read_u8(0x112) << 8) | r:read_u8(0x113)) or (k - 1) .. ":vide"
end
f:write("#\tcartes (slot:NGH)\t" .. table.concat(cartes, " ") .. "\n")

local trame, reg_slot, interne = 1, "-", false
local t0, PERIODE = 0, 1 / 59.185
local function fraction() return (m.time:as_double() - t0) / PERIODE end
local function ligne(genre, adr, val, note)
  f:write(string.format("%d\t%.2f\t%s\t%s\t%s\t%s\t%s\n", trame, fraction(), genre, adr, val,
    reg_slot, note or ""))
end
local function cote() return (cpu.state["PC"].value & 0xFFFFFF) >= 0xC00000 and "bios" or "jeu" end

-- A tap receives the even address of the word and the mask of the bytes touched: each byte is returned.
local function octets(off, data, mask, fn)
  if mask & 0xFF00 ~= 0 then fn(off, (data >> 8) & 0xFF) end
  if mask & 0x00FF ~= 0 then fn(off + 1, data & 0xFF) end
end

local NOMS = {
  [0x380001] = "REG_POUTPUT", [0x380021] = "REG_SLOT", [0x380031] = "REG_LEDLATCHES",
  [0x380041] = "REG_LEDDATA", [0x380051] = "REG_RTCCTRL",
  [0x3A0001] = "REG_NOSHADOW", [0x3A0011] = "REG_SHADOW", [0x3A0003] = "REG_SWPBIOS",
  [0x3A0013] = "REG_SWPROM", [0x3A0005] = "REG_CRDUNLOCK1", [0x3A0015] = "REG_CRDLOCK1",
  [0x3A0007] = "REG_CRDLOCK2", [0x3A0017] = "REG_CRDUNLOCK2", [0x3A0009] = "REG_CRDREGSEL",
  [0x3A0019] = "REG_CRDNORMAL", [0x3A000B] = "REG_BRDFIX", [0x3A001B] = "REG_CRTFIX",
  [0x3A000D] = "REG_SRAMLOCK", [0x3A001D] = "REG_SRAMUNLOCK", [0x3A000F] = "REG_PALBANK0",
  [0x3A001F] = "REG_PALBANK1",
}

-- THE NOISE. An address rewritten identically makes no line, and an address that has
-- already made PLAFOND lines makes no more: its writes are counted and come out at the end of the run (kind
-- "B"). Without that, the EL/LED outputs and the backup RAM counters, rewritten at each
-- frame, make up 99% of the record. REG_SLOT and the ROM latches escape both filters.
local der_val, n_lig, tues, ident = {}, {}, {}, {}
local function plafond(adr)
  n_lig[adr] = (n_lig[adr] or 0) + 1
  if n_lig[adr] > PLAFOND then tues[adr] = (tues[adr] or 0) + 1 return false end
  return true
end
local function filtre(adr, v)
  if der_val[adr] == v then ident[adr] = (ident[adr] or 0) + 1 return false end
  der_val[adr] = v
  return plafond(adr)
end
local LIBRES = { [0x380021] = true, [0x3A000B] = true, [0x3A001B] = true, [0x3A0013] = true,
  [0x3A0003] = true }

-- MS_SONDE_M1=1: WHICH M1 THE Z80 SEES, just before each write to REG_SLOT, REG_BRDFIX,
-- REG_CRTFIX or REG_SOUND and at the end of the frame; an E line "Z80:0000" when it changes. Under
-- REG_CRTFIX only: the first 256 bytes of the Z80's space are compared with those of the
-- region `:cslotN:audiocpu` of each mounted cartridge, and only the recognised slot comes out. Under
-- REG_BRDFIX, it is the board's SM1, an SNK ROM: nothing is read (`docs/DECISIONS.md` §8).
-- The tap runs BEFORE the write it sees: the line tells the state that the write is going to change.
local SONDE_M1 = os.getenv("MS_SONDE_M1") == "1"
local fixe, m1_avant = "brd", nil
local z80 = SONDE_M1 and m.devices[":audiocpu"].spaces["program"]
local function sonde_m1(moment)
  if not SONDE_M1 then return end
  local vu = "SM1 de la carte (non lue)"
  if fixe == "crt" then
    local s = {}
    for k = 1, 6 do
      local r = m.memory.regions[":cslot" .. k .. ":audiocpu"]
      if r then
        local pareil = true
        for i = 0, 255 do if z80:read_u8(i) ~= r:read_u8(i) then pareil = false break end end
        if pareil then s[#s + 1] = tostring(k - 1) end
      end
    end
    vu = "M1 du slot " .. (#s > 0 and table.concat(s, "+") or "aucun")
  end
  if vu ~= m1_avant then m1_avant = vu ligne("E", "Z80:0000", vu, "M1 vue par le Z80, avant " .. moment) end
end

G.t_io = p:install_write_tap(0x380000, 0x3800FF, "ms_io", function(off, data, mask)
  if interne then return end
  octets(off, data, mask, function(a, v)
    if a == 0x380021 then sonde_m1("REG_SLOT") end
    if a == 0x380021 then reg_slot = string.format("%02X", v) G.retaper, G.attente = true, 2 end
    if LIBRES[a] or filtre(a, v) then
      ligne("W", string.format("%06X", a), string.format("%02X", v), (NOMS[a] or "") .. " par " .. cote())
    end
  end)
end)
-- The system latches go in pairs, bit 4 of the address being the data ("Memory
-- mapped registers"): the filtered "value" is therefore the half of the pair touched.
G.t_sys = p:install_write_tap(0x3A0000, 0x3A001F, "ms_sys", function(off, data, mask)
  if interne then return end
  octets(off, data, mask, function(a, v)
    if a & 1 == 0 then return end
    if a == 0x3A000B or a == 0x3A001B then
      sonde_m1(NOMS[a])
      fixe = a == 0x3A000B and "brd" or "crt"
    end
    if LIBRES[a] or filtre(a & ~0x10, a) then
      ligne("W", string.format("%06X", a), "-", (NOMS[a] or "") .. " par " .. cote())
    end
  end)
end)

-- The reads of status registers are counted per frame; the count makes a line only when
-- it differs from that of the previous frame. Their value is an input, not a fact of the BIOS.
local lect, lect_avant = {}, {}
local function compter(nom) lect[nom] = (lect[nom] or 0) + 1 end

-- REG_SOUND: writes one by one, reads counted per frame.
local son_lect, son_echo = 0, 0
G.t_sonw = p:install_write_tap(0x320000, 0x320001, "ms_sonw", function(off, data, mask)
  if interne then return end
  if mask & 0xFF00 ~= 0 then
    sonde_m1("REG_SOUND")
    ligne("W", "320000", string.format("%02X", (data >> 8) & 0xFF), "REG_SOUND par " .. cote())
  end
end)
G.t_sonr = p:install_read_tap(0x320000, 0x320001, "ms_sonr", function(off, data, mask)
  if interne then return end
  if mask & 0xFF00 ~= 0 then
    son_lect = son_lect + 1
    if (data >> 8) & 0xFF == 0x01 then son_echo = son_echo + 1 end
  end
  if mask & 0x00FF ~= 0 then compter("320001 REG_STATUS_A") end
end)
-- REG_STATUS_B carries the game selection buttons: its value read (an input of the board, not a
-- byte of the BIOS) makes a line when it changes, to see whether a gesture reaches the 68000.
local stb_avant
G.t_stb = p:install_read_tap(0x380000, 0x380001, "ms_stb", function(off, data, mask)
  if interne then return end
  compter("380000 REG_STATUS_B")
  if data ~= stb_avant then
    stb_avant = data
    ligne("R", "380000", string.format("%04X", data & 0xFFFF), "REG_STATUS_B lu (mot), par " .. cote())
  end
end)
G.t_p1 = p:install_read_tap(0x300000, 0x300001, "ms_p1", function(off, data, mask)
  if interne then return end
  if mask & 0xFF00 ~= 0 then compter("300000 REG_P1CNT") end
  if mask & 0x00FF ~= 0 then compter("300001 REG_DIPSW") end
end)
G.t_st = p:install_read_tap(0x300080, 0x300081, "ms_st", function(off, data, mask)
  if not interne then compter("300081 REG_SYSTYPE") end
end)

-- The cartridge header read by the BIOS: one line per read, at most 64 per frame (beyond that,
-- a summary). At $000108, the slot that the NGH read designates — the value is written only if it
-- designates no mounted cartridge, that is, what MAME returns for an empty slot.
-- The reads by the cartridge itself are only counted.
local ent_tampon, ent_n, ent_jeu, ent_jeu_avant = {}, 0, 0, 0
G.t_ent = p:install_read_tap(0x000100, 0x00013F, "ms_ent", function(off, data, mask)
  if interne then return end
  if cote() ~= "bios" then ent_jeu = ent_jeu + 1 return end
  ent_n = ent_n + 1
  local note = "en-tete lu par bios"
  if off == 0x108 then
    local mot = data & 0xFFFF
    local sl = slot_de(mot)
    note = note .. ", NGH du slot " .. sl .. (sl == "aucun" and string.format(" (mot %04X)", mot) or "")
  elseif off == 0x122 then
    note = string.format("entree USER lue, demande=%02X mode=%02X", p:read_u8(0x10FDAE), p:read_u8(0x10FDAF))
    G.pl_fermer = true
    if CAPT_USER and #G.capt_prevues < 60 then
      G.capt_prevues[#G.capt_prevues + 1] = trame + CAPT_USER
      images[trame + CAPT_USER] = true
    end
  end
  if ent_n <= 64 then ent_tampon[#ent_tampon + 1] = { trame, fraction(), off, reg_slot, note } end
end)

-- MS_SONDE_PROM=1: every read of $000000-$0FFFFF made BY THE BIOS, summarised per frame in
-- ranges of 256 bytes. Costly, the tap seeing every read by the game: for a short pass.
local prom = {}
if os.getenv("MS_SONDE_PROM") == "1" then
  G.t_prom = p:install_read_tap(0x000000, 0x0FFFFF, "ms_prom", function(off, data, mask)
    if interne or cote() ~= "bios" then return end
    local k = off >> 8
    prom[k] = (prom[k] or 0) + 1
  end)
end

-- MS_DETAIL=<de>-<a>: during these frames, each read made by the BIOS outside its ROM and
-- the work RAM (P-ROM, banked zone, registers, palette, memory card, backup RAM), one
-- line per read, address only. To see what the BIOS queries around a gesture.
local det_de, det_a = (os.getenv("MS_DETAIL") or ""):match("^(%d+)-(%d+)$")
det_de, det_a = tonumber(det_de), tonumber(det_a)
if det_de then
  local function tap_detail(debut, fin)
    return p:install_read_tap(debut, fin, "ms_det", function(off, data, mask)
      if interne or trame < det_de or trame > det_a or cote() ~= "bios" then return end
      local note = "lu par bios (detail)"
      if off == 0x108 then note = note .. ", NGH du slot " .. slot_de(data & 0xFFFF) end
      ligne("R", string.format("%06X", off), "-", note)
    end)
  end
  G.d1 = tap_detail(0x000000, 0x0FFFFF)
  G.d2 = tap_detail(0x200000, 0x3FFFFF)
  G.d3 = tap_detail(0x400000, 0xBFFFFF)
  G.d4 = tap_detail(0xD00000, 0xD0FFFF)
end

-- A SLOT CHANGE ERASES THE CARTRIDGE TAPS. MAME reinstalls the handlers of
-- $000000-$0FFFFF and of the banked zone on the selected slot, and in doing so overwrites the taps set
-- on them: measured, no header read was seen any more after the first write to
-- REG_SLOT, while the backup RAM received the NGH of the next slot. The REG_SLOT tap cannot
-- set them again itself (it runs BEFORE the write): it raises a flag, and the tap set on
-- the BIOS ROM reinstalls them at the second read that follows — the first may be the
-- prefetch of the next instruction, done before the write. This tap records NOTHING: it
-- serves only as a signal, and neither the address nor the value it sees leave the jig.
local function retaper()
  G.retaper = false
  for _, k in ipairs({ "t_ent", "t_prom", "d1", "d2" }) do if G[k] then G[k]:reinstall() end end
end
-- With MS_PLAGES, each entry of SYSTEM_RETURN also outputs an E line "C00444" (public entry
-- point) carrying the code the game leaves in BIOS_SYSRET_STATUS ($10FD81, RAM):
-- one per frame at most, the prefetch being able to reread the address.
G.t_signal = p:install_read_tap(0xC00000, 0xC1FFFF, "ms_signal", function(off)
  if off == 0xC00444 and G.pl_ecouter then
    if os.getenv("MS_PLAGES") == "1" and G.sysret_trame ~= trame then
      G.sysret_trame = trame
      interne = true
      local code = p:read_u8(0x10FD81)
      interne = false
      ligne("E", "C00444", string.format("%02X", code), "SYSTEM_RETURN, code laisse par le jeu")
    end
    G.pl_ecouter(true) G.pl_fermer = false
  end
  if not G.retaper then return end
  G.attente = G.attente - 1
  if G.attente <= 0 then retaper() end
end)

-- MS_PLAGES=1: THE GAME SAVES. What the BIOS reads and writes, per frame, in contiguous
-- ranges of bytes: in the backup RAM from $D00320, where the first save begins
-- (measured; its writes below $D00400 also come out line by line), and in the game's work
-- RAM $100000-$10F2FF, reads and writes. One "P" line per range: start and end, number
-- of accesses, and for a write the 16-bit sum of the bytes written — enough to tell that a
-- copy carries what it read, without outputting a byte. The values are those of the
-- game (its RAM, its save), never a byte of the BIOS ROM (`docs/DECISIONS.md` §8).
-- The work RAM is listened to only while the BIOS has control: from boot to the first
-- hand-over ($000122 read by the BIOS), then from each entry of SYSTEM_RETURN ($C00444, public
-- entry point, seen by the signal tap further down and not recorded) to the next hand-over — otherwise
-- every access by the game would go through lua. A hand-over closes the listening at the end of its frame.
local PLAGES = os.getenv("MS_PLAGES") == "1"
local pl = { bw = {}, br = {}, rw = {}, rr = {} }   -- address → count; bw/rw: and sum
local pl_somme = { bw = {}, rw = {} }
local function pl_note(t, a, v)
  pl[t][a] = (pl[t][a] or 0) + 1
  if v and pl_somme[t] then pl_somme[t][a] = ((pl_somme[t][a] or 0) + v) & 0xFFFF end
end
local function pl_vider()
  local NOMS_PL = { bw = "BRAM ecrite par bios", br = "BRAM lue par bios",
    rw = "RAM de travail ecrite par bios", rr = "RAM de travail lue par bios" }
  for _, t in ipairs({ "br", "bw", "rr", "rw" }) do
    local as = {} for a in pairs(pl[t]) do as[#as + 1] = a end table.sort(as)
    local i = 1
    while i <= #as do
      local j, n, s = i, 0, 0
      while j + 1 <= #as and as[j + 1] == as[j] + 1 do j = j + 1 end
      for k = i, j do
        n = n + pl[t][as[k]]
        if pl_somme[t] then s = (s + pl_somme[t][as[k]]) & 0xFFFF end
      end
      ligne("P", string.format("%06X-%06X", as[i], as[j]), "n=" .. n,
        NOMS_PL[t] .. string.format(", %d octets", as[j] - as[i] + 1) ..
        (pl_somme[t] and string.format(", somme %04X", s) or ""))
      i = j + 1
    end
  end
  pl = { bw = {}, br = {}, rw = {}, rr = {} }
  pl_somme = { bw = {}, rw = {} }
end
local function pl_ecouter(oui)
  if not PLAGES then return end
  if oui and not G.t_rr then
    G.t_rr = p:install_read_tap(0x100000, 0x10F2FF, "ms_rr", function(off, data, mask)
      if interne or cote() ~= "bios" then return end
      octets(off, data, mask, function(a) pl_note("rr", a) end)
    end)
    G.t_rw = p:install_write_tap(0x100000, 0x10F2FF, "ms_rw", function(off, data, mask)
      if interne or cote() ~= "bios" then return end
      octets(off, data, mask, function(a, v) pl_note("rw", a, v) end)
    end)
  elseif not oui and G.t_rr then
    G.t_rr:remove() G.t_rw:remove() G.t_rr, G.t_rw = nil, nil
  end
end
G.pl_ecouter = pl_ecouter
if PLAGES then
  pl_ecouter(true)
  G.t_br = p:install_read_tap(0xD00320, 0xD0FFFF, "ms_br", function(off, data, mask)
    if interne or cote() ~= "bios" then return end
    octets(off, data, mask, function(a) pl_note("br", a) end)
  end)
end

-- Backup RAM. The cap alone, not the filter of identical rewrites: a rewrite there is
-- a fact (the record of 2026-10-16 shows one), and the memory test of the first boot leaves
-- in each byte a value that a useful write may repeat — filtered, it would disappear
-- (measured: $D00047 was missing from the record). The counters rewritten at each frame reach the
-- cap in a few seconds, and their count comes out in the summary.
-- The frame's buffer comes out line by line, except a fill, summarised in one line: more than
-- REMPLI writes in the frame (the memory test makes 1,024, the
-- first boot of the reference with four cartridges ~250). Two zones still come out line
-- by line, they are the point of it: $D00040-$D0005F (number of slots, logo flag) and
-- $D00100-$D001FF (date, selected slot, bookkeeping, slot table and what follows it).
local REMPLI = 400
local function utile(a) return (a >= 0xD00040 and a <= 0xD0005F) or (a >= 0xD00100 and a <= 0xD001FF) end
local bram_n, bram_vals, bram_hors, bram_tampon = 0, {}, 0, {}
G.t_bram = p:install_write_tap(0xD00000, 0xD0FFFF, "ms_bram", function(off, data, mask)
  if interne then return end
  octets(off, data, mask, function(a, v)
    if a > 0xD003FF then
      bram_hors = bram_hors + 1
      if PLAGES and cote() == "bios" then pl_note("bw", a, v) end
      return
    end
    if PLAGES and a >= 0xD00320 and cote() == "bios" then pl_note("bw", a, v) end
    if not plafond(a) then return end
    bram_n = bram_n + 1
    bram_vals[v] = true
    if bram_n <= REMPLI or utile(a) then
      bram_tampon[#bram_tampon + 1] = { trame, fraction(), a, v, reg_slot, cote() }
    end
  end)
end)

-- BIOS variables: one line when the value changes for a given writer.
local SUIVIES = { [0x10FCEF] = "BIOS_SLOTCHECK", [0x10FD80] = "BIOS_SYSTEM_MODE",
  [0x10FD81] = "BIOS_SYSRET_STATUS", [0x10FD82] = "BIOS_MVS_FLAG", [0x10FD83] = "BIOS_COUNTRY_CODE",
  [0x10FDAE] = "BIOS_USER_REQUEST", [0x10FDAF] = "BIOS_USER_MODE", [0x10FEE1] = "BIOS_FRAME_SKIP" }
local dernier = {}
local function tap_var(debut, fin)
  return p:install_write_tap(debut, fin, "ms_var", function(off, data, mask)
    if interne then return end
    octets(off, data, mask, function(a, v)
      if not SUIVIES[a] then return end
      local qui = cote()
      -- CONTROL TAKEN BACK WITHOUT SYSTEM_RETURN. Measured (reference, on 2026-10-22): at SELECT, the
      -- BIOS writes BIOS_SYSRET_STATUS ← $04 or $05 and takes back control without the game entering
      -- through $C00444 (the coin, $06, does the same; it is not opened here, so that the
      -- records of earlier batches replay identically). MS_PLAGES therefore also opens
      -- the listening of the work RAM on these two writes, without which the save of the outgoing
      -- game would appear there only on the backup RAM side.
      if a == 0x10FD81 and qui == "bios" and (v == 4 or v == 5) and G.pl_ecouter then
        G.pl_ecouter(true) G.pl_fermer = false
      end
      if dernier[a .. qui] ~= v then
        dernier[a .. qui] = v
        ligne("W", string.format("%06X", a), string.format("%02X", v), SUIVIES[a] .. " par " .. qui)
      end
    end)
  end)
end
G.t_v1 = tap_var(0x10FCEE, 0x10FCEF)
G.t_v2 = tap_var(0x10FD80, 0x10FD83)
G.t_v3 = tap_var(0x10FDAE, 0x10FDAF)
G.t_v4 = tap_var(0x10FEE0, 0x10FEE1)

-- Inputs.
local function F(pt, n) local x = m.ioport.ports[pt] return x and x.fields[n] end
local CHAMPS = {
  piece = F(":AUDIO_COIN", "Coin 1"), start = F(":edge:joy:START", "1 Player Start"),
  start2 = F(":edge:joy:START", "2 Players Start"), suivant = F(":SYSTEM", "Next Game"),
  precedent = F(":SYSTEM", "Previous Game"), a = F(":edge:joy:JOY1", "P1 A"),
  test = F(":TEST", "Service Mode"),
}
local plan = {}
for de, nom, duree in (os.getenv("MS_ENTREES") or ""):gmatch("(%d+):(%a+):?(%d*)") do
  if not CHAMPS[nom] then print("MULTISLOT: entrée inconnue " .. nom) m:exit() return end
  plan[#plan + 1] = { de = tonumber(de), a = tonumber(de) + (tonumber(duree) or 8), nom = nom }
end

local function vider_trame()
  local cles = {} for k in pairs(lect) do cles[#cles + 1] = k end
  for k in pairs(lect_avant) do if not lect[k] then cles[#cles + 1] = k end end
  table.sort(cles)
  for _, k in ipairs(cles) do
    if lect[k] ~= lect_avant[k] then
      local a, nom = k:match("^(%S+) (.*)$")
      ligne("R", a, "n=" .. (lect[k] or 0), nom .. ", lectures par trame")
    end
  end
  lect_avant, lect = lect, {}
  if son_lect > 0 then ligne("R", "320000", "n=" .. son_lect, "REG_SOUND lu, dont $01 x" .. son_echo) end
  son_lect, son_echo = 0, 0

  if ent_n <= 64 then
    for _, e in ipairs(ent_tampon) do
      f:write(string.format("%d\t%.2f\tR\t%06X\t-\t%s\t%s\n", e[1], e[2], e[3], e[4], e[5]))
    end
  else
    ligne("R", "000100-00013F", "n=" .. ent_n, "en-tete lu par bios, resume")
  end
  if ent_jeu ~= ent_jeu_avant then
    ligne("R", "000100-00013F", "n=" .. ent_jeu, "en-tete lu par jeu, lectures par trame")
  end
  ent_jeu_avant, ent_tampon, ent_n, ent_jeu = ent_jeu, {}, 0, 0

  local ks = {} for k in pairs(prom) do ks[#ks + 1] = k end table.sort(ks)
  for _, k in ipairs(ks) do
    ligne("R", string.format("%06X-%06X", k << 8, (k << 8) + 0xFF), "n=" .. prom[k], "P-ROM lue par bios")
  end
  prom = {}

  -- THE GUARD OF §8. A value written to backup RAM may be an address of the BIOS ROM
  -- (a saved pointer). Within the frame, a byte $C0 or $C1 followed by two bytes written at the
  -- following addresses forms a value of $C00000-$C1FFFF: these three bytes, and the high byte
  -- that precedes them if it was written, come out "retenu". Deliberately coarse — measured, it withholds
  -- mostly $D00020-$D00022, rewritten at each frame, which are perhaps only status bits.
  local vu, retenu = {}, {}
  for _, e in ipairs(bram_tampon) do vu[e[3]] = e[4] end
  for a, v in pairs(vu) do
    if (v == 0xC0 or v == 0xC1) and vu[a + 1] and vu[a + 2] then
      retenu[a], retenu[a + 1], retenu[a + 2] = true, true, true
      if vu[a - 1] then retenu[a - 1] = true end
    end
  end
  for _, e in ipairs(bram_tampon) do
    if bram_n <= REMPLI or utile(e[3]) then
      local v = retenu[e[3]] and "retenu" or string.format("%02X", e[4])
      f:write(string.format("%d\t%.2f\tW\t%06X\t%s\t%s\tBRAM par %s\n", e[1], e[2], e[3], v, e[5], e[6]))
    end
  end
  if bram_n > REMPLI then
    local vs = {} for v in pairs(bram_vals) do vs[#vs + 1] = string.format("%02X", v) end table.sort(vs)
    ligne("W", "D00000-D003FF", "n=" .. bram_n, "BRAM resume (hors D00100-D001FF, ligne a ligne), valeurs " ..
      table.concat(vs, " ", 1, math.min(#vs, 8)) .. (#vs > 8 and " ..." or ""))
  end
  if bram_hors > 0 then ligne("W", "D00400-D0FFFF", "n=" .. bram_hors, "BRAM hors table") end
  if PLAGES then
    pl_vider()
    if G.pl_fermer then pl_ecouter(false) G.pl_fermer = false end
  end
  bram_n, bram_vals, bram_hors, bram_tampon = 0, {}, 0, {}
end

-- MS_LECT_JEU=1: each read of $D00000-$D003FF whose PC is outside the BIOS ROM, counted
-- per byte read. Nothing is written except in the summary: the address and the count, never the value.
local lect_jeu = {}
if os.getenv("MS_LECT_JEU") == "1" then
  G.t_ljeu = p:install_read_tap(0xD00000, 0xD003FF, "ms_ljeu", function(off, data, mask)
    if interne or cote() ~= "jeu" then return end
    octets(off, data, mask, function(a) lect_jeu[a] = (lect_jeu[a] or 0) + 1 end)
  end)
end

local function bilan()
  local ls = {} for a in pairs(lect_jeu) do ls[#ls + 1] = a end table.sort(ls)
  for _, a in ipairs(ls) do
    ligne("R", string.format("%06X", a), "n=" .. lect_jeu[a], "BRAM lue par jeu, sur le run")
  end
  local as = {} for a in pairs(n_lig) do as[#as + 1] = a end table.sort(as)
  for _, a in ipairs(as) do
    if tues[a] or ident[a] then
      ligne("B", string.format("%06X", a), "-", string.format("lignes=%d tues=%d identiques=%d",
        math.min(n_lig[a], PLAFOND), tues[a] or 0, ident[a] or 0))
    end
  end
end

-- MS_VIDAGES=<trame>,<trame>…: at the end of these frames, the save zone of the served game
-- (pointer $00010E and size $000112 of its cartridge header) and its backup RAM block
-- ($D00320 + $1000 × the block index of its entry in $D00124), in hexadecimal, into
-- MS_DIR/zone-fNNNNN.hex. These are bytes of the GAME (its RAM, its save), never of the BIOS
-- ROM (`docs/DECISIONS.md` §8): enough to see a score found again from one boot to the next.
local vidages = {}
for n in (os.getenv("MS_VIDAGES") or ""):gmatch("%d+") do vidages[tonumber(n)] = true end
local function vider_zone()
  interne = true
  local zone = p:read_u32(0x10E)
  local taille = p:read_u16(0x112)
  local slot = p:read_u8(0xD00108)
  local bloc = p:read_u16(0xD00124 + 4 * (slot & 7) + 2)
  local function hex(base, n)
    local t = {}
    for i = 0, n - 1 do t[#t + 1] = string.format("%02X", p:read_u8(base + i)) end
    return table.concat(t)
  end
  local g = io.open(string.format("%s/zone-f%05d.hex", DIR, trame), "w")
  g:write(string.format("trame %d slot %d bloc %04X zone %06X taille %04X\n", trame, slot, bloc, zone, taille))
  if taille > 0 and taille <= 0x1000 then
    g:write("ram " .. hex(zone, taille) .. "\n")
    if bloc < 8 then g:write("bram " .. hex(0xD00320 + 0x1000 * bloc, taille) .. "\n") end
  end
  g:close()
  interne = false
  ligne("E", "-", "-", string.format("vidage zone-f%05d", trame))
end

-- MS_POSER=<trame>@<adresse>=<octets hex>,…: at the end of these frames, writes these bytes into the
-- GAME's work RAM ($100000-$10F2FF only) — a score set in its save zone, to
-- see whether the BIOS carries it from one boot to the next. The only action of the jig that touches the machine.
local poses = {}
for t, a, h in (os.getenv("MS_POSER") or ""):gmatch("(%d+)@(%x+)=(%x+)") do
  poses[#poses + 1] = { t = tonumber(t), a = tonumber(a, 16), h = h }
end
local function poser()
  for _, e in ipairs(poses) do
    if e.t == trame and e.a >= 0x100000 and e.a + #e.h // 2 - 1 <= 0x10F2FF then
      interne = true
      for i = 0, #e.h // 2 - 1 do p:write_u8(e.a + i, tonumber(e.h:sub(2 * i + 1, 2 * i + 2), 16)) end
      interne = false
      ligne("E", string.format("%06X", e.a), e.h, "pose dans la RAM du jeu (MS_POSER)")
    end
  end
end

-- MS_SUIVRE=<adresse>,…: the value of these bytes at the end of the frame, an E line when it changes.
-- Values of RAM and backup RAM, read by the jig outside the taps; never the BIOS ROM
-- (`docs/DECISIONS.md` §8): an address outside the two zones is ignored.
local suivies, suivi_avant = {}, {}
for h in (os.getenv("MS_SUIVRE") or ""):gmatch("%x+") do
  local a = tonumber(h, 16)
  if (a >= 0x100000 and a <= 0x10FFFF) or (a >= 0xD00000 and a <= 0xD0FFFF) then suivies[#suivies + 1] = a end
end
local function suivre()
  if #suivies == 0 then return end
  interne = true
  for _, a in ipairs(suivies) do
    local v = p:read_u8(a)
    if v ~= suivi_avant[a] then
      suivi_avant[a] = v
      ligne("E", string.format("%06X", a), string.format("%02X", v), "valeur en fin de trame (MS_SUIVRE)")
    end
  end
  interne = false
end

local main_a, slot_mappe = nil, nil
emu.register_frame_done(function()
  if G.retaper then retaper() end
  sonde_m1("la fin de trame")
  vider_trame()

  -- The state at the end of the frame: who has control, which slot MAME serves.
  local c = cote()
  if c ~= main_a then main_a = c ligne("E", "-", c, "main") end
  interne = true
  local s = slot_de(p:read_u16(0x108))
  interne = false
  if s ~= slot_mappe then slot_mappe = s ligne("E", "000108", s, "slot dont MAME sert la P-ROM") end

  suivre()
  poser()
  if vidages[trame] then vider_zone() end
  if images[trame] then
    local px = ecran:pixels()
    local g = io.open(string.format("%s/f%05d.bin", DIR, trame), "wb") g:write(px) g:close()
    ligne("E", "-", "-", string.format("capture f%05d", trame))
  end
  f:flush()

  t0 = m.time:as_double()
  trame = trame + 1
  for _, e in ipairs(plan) do
    if trame == e.de then CHAMPS[e.nom]:set_value(1) ligne("I", "-", e.nom, "presse") end
    if trame == e.a then CHAMPS[e.nom]:set_value(0) end
  end
  if trame > FIN then bilan() f:close() m:exit() end
end)
