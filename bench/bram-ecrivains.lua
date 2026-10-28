-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- Qui écrit où en backup RAM : un tap d'écriture sur $D00000-$D0FFFF, sans fenêtre. Sert à
-- choisir une zone que ni notre BIOS ni les jeux n'écrivent (`src/c0/reglages.s`). Sous NOTRE
-- image seulement : sous un BIOS de référence, le PC relevé serait une adresse de la référence.
--
--   B_OUT  fichier de sortie (obligatoire) ; B_FIN trame de sortie (défaut 3700)
--
-- Entrées : le cycle de `bios-probe.lua` — pièce, START, A, jamais ensemble — pour jouer une
-- partie. Sortie, par ligne de 16 octets écrite : l'adresse, le nombre d'écritures, la première
-- et la dernière trame, et le PC de la première écriture, côté BIOS ($C0xxxx) ou jeu.
-- Le tap est gardé dans _G : sans référence vivante, MAME le ramasse et le relevé sort vide.
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
-- Le relevé s'écrit à l'arrêt de la machine, quelle qu'en soit la cause (B_FIN, ou
-- -seconds_to_run si un jeu ralentit l'émulation au point de ne pas l'atteindre).
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
