-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- Who writes where in backup RAM: a write tap on $D00000-$D0FFFF, windowless. Used to choose
-- an area that neither our BIOS nor the games write (`src/c0/reglages.s`). Under OUR image
-- only: under a reference BIOS, the recorded PC would be an address of the reference.
--
--   B_OUT  output file (mandatory); B_FIN exit frame (default 3700)
--
-- Inputs: the cycle of `bios-probe.lua` — coin, START, A, never together — to play a session.
-- Output, per written 16-byte line: the address, the number of writes, the first and the last
-- frame, and the PC of the first write, BIOS side ($C0xxxx) or game.
-- The tap is kept in _G: without a live reference, MAME collects it and the record comes out
-- empty.
if _G.BRAM then return end
_G.BRAM = {}
local OUT = os.getenv("B_OUT")
if not OUT then print("BRAM: B_OUT manquant") manager.machine:exit() return end
local FIN = tonumber(os.getenv("B_FIN") or "3700")
local m = manager.machine
local cpu = m.devices[":maincpu"]
local p = cpu.spaces["program"]
local function F(pt, n) local x = m.ioport.ports[pt] return x and x.fields[n] end
local coin, start, A = F(":AUDIO_COIN", "Coin 1"), F(":edge:joy:START", "1 Player Start"), F(":edge:joy:JOY1", "P1 A")
assert(coin and start and A, "champ MAME introuvable : pièce, START ou A ; le relevé serait fait sans partie")
local n, lignes = 0, {}
_G.BRAM.tap = p:install_write_tap(0xD00000, 0xD0FFFF, "bram", function(adr, donnee, masque)
  local l = adr & ~0xF
  local e = lignes[l]
  if not e then e = { c = 0, t0 = n, pc = cpu.state["PC"].value } lignes[l] = e end
  e.c = e.c + 1
  e.t1 = n
end)
-- The record is written when the machine stops, whatever the cause (B_FIN, or
-- -seconds_to_run if a game slows the emulation down to the point of not reaching it).
local function ecrire()
  if _G.BRAM.ecrit then return end
  _G.BRAM.ecrit = true
  local f = io.open(OUT, "w")
  local cles = {}
  for l in pairs(lignes) do cles[#cles + 1] = l end
  table.sort(cles)
  f:write(string.format("trames=%d\n", n))
  for _, l in ipairs(cles) do
    local e = lignes[l]
    f:write(string.format("%06X n=%d t=%d-%d pc=%06X\n", l, e.c, e.t0, e.t1, e.pc))
  end
  f:close()
end
_G.BRAM.arret = emu.add_machine_stop_notifier(ecrire)
emu.register_frame_done(function()
  n = n + 1
  local c = n % 300
  coin:set_value((c < 8) and 1 or 0)
  start:set_value((c >= 100 and c < 108) and 1 or 0)
  A:set_value((c >= 200 and c < 208) and 1 or 0)
  if n == FIN then ecrire() m:exit() end
end)
