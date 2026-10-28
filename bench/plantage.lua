-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- Jig de l'écran de plantage (`src/c0/plantage.s`), sans fenêtre. Provoque une exception pendant
-- que le jeu tourne, relit l'écran affiché, presse START, et suit la relance.
--
--   P_OUT      dossier de sortie (obligatoire) ; le relevé va dans P_OUT/plantage.txt
--   P_MODE     adr : JMP vers une adresse impaire écrit en RAM à P_RAM, PC posé dessus
--              (erreur d'adresse au fetch, groupe 0)
--              ill : ILLEGAL ($4AFC) écrit en RAM de travail à P_RAM, PC posé dessus
--   P_TRAME    trame de l'injection (défaut 1500)
--   P_RAM      adresse de l'ILLEGAL en mode ill (défaut $10E000)
--   P_START    trame de START P1, tenu 3 trames (défaut P_TRAME + 200)
--   P_IMAGES   trames dont l'image (bgra 320×224) est écrite
--   P_FIN      trame de sortie (défaut P_START + 1500)
--
-- Avant l'injection, les registres D0-D7 et A0-A6 reçoivent des motifs reconnaissables ; A7, SR
-- et USP sont relevés tels quels. À P_START - 1, le plan fixe reconstruit (comme `fixmap.lua`,
-- depuis les écritures au LSPC, la VRAM n'étant pas exposée au Lua) est décodé en texte et
-- confronté aux valeurs attendues : une ligne « VERIF » par champ, ok ou ECART.
-- Le relevé note aussi la table de vecteurs de la cartouche ($000000-$00007F, lue après la
-- remise de la main), le premier créneau $C00402-$C00437 exécuté, chaque reset et chaque
-- changement de la demande USER ($10FDAF/$10FDAE). Aucune autre entrée n'est pressée.
if _G.PLANTAGE then return end
_G.PLANTAGE = {}
local OUT = os.getenv("P_OUT")
if not OUT then print("PLANTAGE: P_OUT manquant") manager.machine:exit() return end
local MODE = os.getenv("P_MODE") or "adr"
local TRAME = tonumber(os.getenv("P_TRAME") or "1500")
local RAM = tonumber(os.getenv("P_RAM") or "0x10E000")
local START = tonumber(os.getenv("P_START") or tostring(TRAME + 200))
local FIN = tonumber(os.getenv("P_FIN") or tostring(START + 1500))
local m = manager.machine
local cpu = m.devices[":maincpu"]
local p = cpu.spaces["program"]
local ecran = m.screens:at(1)
local champ = m.ioport.ports[":edge:joy:START"].fields["1 Player Start"]
assert(champ, "champ START introuvable")
local images = {}
for n in (os.getenv("P_IMAGES") or ""):gmatch("%d+") do images[tonumber(n)] = true end
local out = io.open(OUT .. "/plantage.txt", "w")
local function W(fmt, ...) out:write(string.format(fmt, ...) .. "\n") out:flush() end

-- Le plan fixe, reconstruit depuis REG_VRAMADDR / REG_VRAMRW / REG_VRAMMOD.
local X = { a = 0, mod = 1, v = {} }
_G.PLANTAGE.tap = p:install_write_tap(0x3C0000, 0x3C0005, "lspc", function(o, d)
  local r = o & 6
  if r == 0 then X.a = d elseif r == 4 then X.mod = d
  elseif r == 2 then X.v[X.a] = d X.a = (X.a + X.mod) & 0xFFFF end end)
-- Le premier créneau de la zone d'entrée exécuté après l'injection.
local injecte, creneau = false, nil
-- Le cadre tel que le 68000 l'empile : les écritures sous A7 entre l'injection et le premier
-- créneau exécuté. C'est le témoin indépendant de ce que l'écran doit montrer.
local cadre = {}
_G.PLANTAGE.tapc = p:install_read_tap(0xC00408, 0xC00437, "creneau", function(o)
  if injecte and not creneau then creneau = o end end)
local function poser_tap_cadre(a7)
  _G.PLANTAGE.tapf = p:install_write_tap(a7 - 14, a7 - 1, "cadre", function(o, d, mk)
    if injecte and not creneau then
      local w = cadre[o & ~1] or 0
      if mk == 0xFFFF then w = d elseif mk == 0xFF00 then w = (w & 0xFF) | (d & 0xFF00) else w = (w & 0xFF00) | (d & 0xFF) end
      cadre[o & ~1] = w
    end end)
end

local n = 0
_G.PLANTAGE.reset = emu.add_machine_reset_notifier(function() W("f%d RESET", n) end)
local attendu = {}

local function texte_fix()
  local lignes = {}
  for row = 0, 31 do
    local l = {}
    for col = 0, 39 do
      local t = (X.v[0x7000 + col * 32 + row] or 0) & 0xFFF
      local c = t & 0xFF
      if (t >> 8) <= 1 and c >= 0x20 and c < 0x7F then l[#l + 1] = string.char(c) else l[#l + 1] = " " end
    end
    lignes[row] = table.concat(l)
  end
  return lignes
end

local function vifs(px)
  local v = 0 for i = 1, #px, 4 do if px:byte(i) + px:byte(i + 1) + px:byte(i + 2) > 24 then v = v + 1 end end
  return v
end

emu.register_frame_done(function()
  n = n + 1
  champ:set_value((n >= START and n < START + 3) and 1 or 0)
  local u = string.format("%02X/%02X", p:read_u8(0x10FDAF), p:read_u8(0x10FDAE))
  if u ~= _G.PLANTAGE.user then _G.PLANTAGE.user = u W("f%d user=%s", n, u) end

  if n == TRAME - 1 then
    local t = {}
    for v = 0, 31 do t[#t + 1] = string.format("%08X", p:read_u32(v * 4)) end
    W("f%d vecteurs-cartouche %s", n, table.concat(t, " "))
  end

  if n == TRAME then
    local s = cpu.state
    for i = 0, 7 do s["D" .. i].value = 0xD0000000 + i * 0x01111111 end
    for i = 0, 6 do s["A" .. i].value = 0x00A00000 + i * 0x00011110 end
    attendu.A7 = s["SP"].value
    attendu.SR = s["SR"].value & 0xFFFF
    attendu.USP = s["USP"].value
    poser_tap_cadre(attendu.A7)
    local pc0 = s["PC"].value
    if MODE == "ill" then
      p:write_u16(RAM, 0x4AFC)
      s["PC"].value = RAM
      attendu.PC = RAM
    else
      -- JMP vers une adresse impaire, écrit en RAM : le fetch de la cible lève l'erreur
      -- d'adresse sans qu'aucune instruction du jeu ne s'exécute après la pose des registres
      -- (poser le PC impair directement laissait MAME finir une instruction de sa file).
      attendu.ACC = (pc0 | 1) ~ 0x100
      p:write_u16(RAM, 0x4EF9) p:write_u32(RAM + 2, attendu.ACC)
      s["PC"].value = RAM
    end
    injecte = true
    W("f%d INJECTION mode=%s pc_avant=%08X sp=%08X sr=%04X usp=%08X pc_pose=%08X",
      n, MODE, pc0, attendu.A7, attendu.SR, attendu.USP, s["PC"].value)
  end

  if n == START - 1 then
    W("f%d creneau=%s", n, creneau and string.format("%06X", creneau) or "aucun")
    local L = texte_fix()
    for row = 2, 29 do W("f%d fix%02d |%s|", n, row, L[row]) end
    local tout = table.concat(L, "\n", 0, 31)
    local compte = { ok = 0, ecart = 0 }
    local function verif(nom, motif, valeur, chiffres)
      local lu = tout:match(motif)
      local att = valeur and string.format("%0" .. chiffres .. "X", valeur) or "?"
      local bon = (lu == att)
      compte[bon and "ok" or "ecart"] = compte[bon and "ok" or "ecart"] + 1
      W("VERIF %-5s attendu=%s affiche=%s %s", nom, att, lu or "absent", bon and "ok" or "ECART")
    end
    for i = 0, 7 do verif("D" .. i, "D" .. i .. " (%x+)", 0xD0000000 + i * 0x01111111, 8) end
    for i = 0, 6 do verif("A" .. i, "A" .. i .. " (%x+)", 0x00A00000 + i * 0x00011110, 8) end
    verif("A7", "A7 (%x+)", attendu.A7, 8)
    verif("USP", "USP (%x+)", attendu.USP, 8)
    verif("SR", "SR (%x+)", attendu.SR, 4)
    verif("NGH", "NGH (%x+)", p:read_u16(0x108), 4)
    -- Le cadre empilé : format A (14 octets) pour l'erreur d'adresse, B (6) pour l'illégale.
    local b = attendu.A7 - ((MODE == "ill") and 6 or 14)
    local function mot(k) return cadre[b + k] end
    local function long(k) return mot(k) and mot(k + 2) and ((mot(k) << 16) | mot(k + 2)) end
    local t = {} for k = 0, attendu.A7 - b - 2, 2 do t[#t + 1] = mot(k) and string.format("%04X", mot(k)) or "----" end
    W("cadre empile a %08X : %s", b, table.concat(t, " "))
    -- Le nom et la porte, comparés au texte exact : un code mal posé dans une entrée.
    local function verif_texte(nom, motif, att)
      local lu = tout:match(motif)
      local bon = (lu == att)
      compte[bon and "ok" or "ecart"] = compte[bon and "ok" or "ecart"] + 1
      W("VERIF %-5s attendu=%s affiche=%s %s", nom, att, lu or "absent", bon and "ok" or "ECART")
    end
    local NOM = { adr = "ADDRESS ERROR  VECTOR 3", ill = "ILLEGAL INSTRUCTION OR LINE A/F" }
    local ENTRY = { adr = "ENTRY C0040E", ill = "ENTRY C00414" }
    verif_texte("NOM", "\n   ([^\n]-)%s*\n   ENTRY", NOM[MODE])
    verif_texte("ENTRY", "(ENTRY [%w ]-)%s*\n", ENTRY[MODE])
    if MODE == "ill" then
      verif("PC", "PC (%x+)", attendu.PC, 8)
      verif("PCcad", "PC (%x+)", long(2), 8)
      verif("SRcad", "SR (%x+)", mot(0), 4)
    else
      verif("ACClua", "ACCESS (%x+)", attendu.ACC, 8)
      verif("ETAT", "STATUS (%x+)", mot(0), 4)
      verif("ACC", "ACCESS (%x+)", long(2), 8)
      verif("IR", "IR (%x+)", mot(6), 4)
      verif("SRcad", "SR (%x+)", mot(8), 4)
      verif("PC", "PC (%x+)", long(10), 8)
    end
    W("VERIF total ok=%d ecart=%d", compte.ok, compte.ecart)
  end

  if images[n] or n % 100 == 0 then
    local px = ecran:pixels()
    if images[n] then local f = io.open(string.format("%s/f%05d.bin", OUT, n), "wb") f:write(px) f:close() end
    if n % 100 == 0 then W("f%d vifs=%d", n, vifs(px)) end
  end
  if n >= FIN then out:close() m:exit() end
end)
