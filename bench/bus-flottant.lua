-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- Jig du bus flottant, sans fenêtre : MAME servi comme le matériel que décrit le wiki, où la
-- cartouche ne répond que sous REG_CRTFIX. Pour juger un BIOS sur ce que MAME, plus permissif,
-- ne montre pas (retour du matériel du 2026-10-24, `docs/ESSAI-MATERIEL.md`, essai 1).
--
--   SDL_VIDEODRIVER=dummy SDL_MAC_BACKGROUND_APP=1 BF_OUT=<sortie.tsv> \
--   mame ng_mv2f -bios euro -hashpath <mame>/hash -rompath <roms> -cart1 mslug \
--     -video none -sound none -nothrottle -nvram_directory <neuf> \
--     -autoboot_script bench/bus-flottant.lua
--
-- LE MODÈLE, et d'où il vient (NeoGeo Development Wiki, consulté le 2026-10-24) :
--   - « MVS cartridge pinout », SLOTCS : « SLOTCS goes low when the slot is used », « On
--     multi-slot boards, the signals come from NEO-F0 SLOT0~5. On one slot boards, it's tied to
--     SYSTEMB », et « The System ROM was written to ensure the signal is asserted when it does
--     the slot check » ;
--   - « NEO-F0 » : « SYSTEMB is used to gate the SLOT* outputs » ;
--   - « Signals » : « SYSTEM: low when onboard ROMs selected », « SYSTEMB: inverted SYSTEM » —
--     les ROM de la carte étant la SFIX et la SM1 que choisit REG_BRDFIX ($3A000B), REG_CRTFIX
--     ($3A001B) choisissant celles de la cartouche (« Memory mapped registers »).
-- D'où, SUPPOSÉ dans sa forme exacte : sous REG_BRDFIX, aucun slot n'est sélectionné et rien ne
-- tient le bus sur $000000-$0FFFFF ni sur $200000-$2FFFFF — sauf $000000-$00007F sous
-- REG_SWPBIOS, que la carte sert depuis le BIOS. MESURÉ sur une MV-2F (essai sur matériel, 2026-10-24) : notre
-- image n°8 lit $000108 sous REG_BRDFIX et y trouve E05C, quelle que soit la cartouche, et le
-- mot suivant son `move.w 0x108,%d4` dans `ecran.s` est E05C. MESURÉ sous MAME (`acces-boot.lua`) :
-- la référence écrit REG_CRTFIX juste avant de lire l'en-tête de chaque slot, et REG_BRDFIX après.
--
-- CE QUE LE JIG REND pour une lecture flottante : le mot à l'adresse du PC — ce que MAME rend
-- lui-même pour un trou de la carte (`unmapped_r` : « the last word on the data bus, which is
-- almost always the opcode of the next instruction due to prefetch »). L'état des bascules au
-- reset est celui de MAME (HC259 à zéro : BRDFIX, vecteurs du BIOS).
--
-- Réglages par l'environnement :
--   BF_OUT     TSV de sortie (obligatoire)
--   BF_FIN     dernière trame (défaut 900)
--   BF_IMAGES  trames où écrire l'écran brut (bgra, 320 × 224) dans BF_DIR, séparées par des virgules
--   BF_DIR     dossier des captures (défaut : celui de BF_OUT)
--   BF_TEST    <de>-<a> : le bouton TEST tenu sur ces trames (l'éditeur de soft-DIP du boot)
--   BF_LIBRE   1 : ne fausse rien — le même relevé sur le MAME d'origine, en témoin
--   BF_SLOT_MAX n : borne REG_SLOT pour MAME (voir plus bas), 6 pour l'image de diagnostic
--   BF_ABSENTE n : la cartouche rend $FFFF, ce que MAME rend pour un slot vide, sur ses trames 0 à
--              n-1, sous l'une et l'autre bascule — un flash cart qui charge encore son menu à la
--              mise sous tension (retour du matériel du 2026-10-28, `docs/ESSAI-MATERIEL.md`).
--              SUPPOSÉ : ce qu'un flash cart rend pendant ce temps, et combien de temps il le
--              rend ; rien n'en est mesuré. Une lecture flottante sous REG_BRDFIX reste comptée et
--              rendue comme telle : seule la cartouche servie est muette
--   BF_HOTE    1 : chargé par un autre jig (`son.lua`, J_FLOTTANT), qui joue les entrées et quitte
--              MAME : ce jig n'y touche pas, et à BF_FIN il écrit son bilan sans quitter
--
-- CE QUI EST RELEVÉ — ce jig ne consigne aucun PC ni aucun octet de la ROM du BIOS (`docs/DECISIONS.md`
-- §8) : le PC n'est lu que pour dire qui lit (bios dans $C00000-$C1FFFF, jeu sinon) et à rendre le mot préchargé.
-- Lignes : F (lectures faussées, par trame et par côté, les 40 premières avec leur adresse), R
-- (reset de la machine, watchdog compris), J (le jeu a la main en fin de trame — PC sous
-- $100000 — pour la première fois depuis le dernier reset), B (bascule changée), et un bilan
-- qui compte les trames finies dans le jeu.
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

-- Les bascules par paires, le bit 4 de l'adresse faisant la donnée (« Memory mapped registers ») :
-- $3A0003/$3A0013 les vecteurs, $3A000B/$3A001B les ROM du plan fixe et du Z80.
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

-- UNE ÉCRITURE DE REG_SLOT FAIT TOMBER LES TAPS DE LA P-ROM (MAME y réinstalle la ROM du slot,
-- `set_slot_idx`) : reposés deux lectures du BIOS plus tard, la recette de `multislot.lua`.
-- BF_SLOT_MAX=n : une écriture de REG_SLOT au-delà de n-1 devient n-1. MAME 0.286 indexe son
-- tableau de six slots par la donnée sans la borner (`mvs_state::io_control_w`, `m_slots[data]`) :
-- 6 et 7 le font sortir en erreur de segmentation, mesuré avec l'image de diagnostic. Sur
-- ng_mv2f, 5 n'est pas monté et MAME garde alors le slot d'avant, comme pour 2 à 4.
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

-- Un reset de la machine (le watchdog compris) remet le HC259 à zéro chez MAME : BRDFIX, vecteurs
-- du BIOS. Le premier reset, celui de la mise sous tension, n'est pas compté.
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
