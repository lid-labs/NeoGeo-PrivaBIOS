-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- La mise sous tension du matériel : la VRAM et la RAM de palettes pleines de bruit, avant la première instruction
-- du BIOS. Sous MAME, mesuré le 2026-10-27 sur aof : la VRAM relevée à la trame 1 (SCB1 à SCB3, plan fixe) est à zéro,
-- et une VRAM bruitée seule n'y change aucune image du boot, les palettes de MAME restant noires. Chargé avec `son.lua` par
-- J_AUSSI (scène boot-graphismes de `parcours.sh`) ; ne joue aucune entrée. Le bruit vient d'une graine fixe :
-- deux runs le reçoivent identique. Écrit au chargement du script, avant la première trame.
local m = manager.machine
local vr = emu.item(m.devices[":spritegen"].items["0/m_videoram"])
local p = m.devices[":maincpu"].spaces["program"]
local x = 1448
local function tirer() x = (x * 1103515245 + 12345) % 2147483648 return (x >> 8) & 0xFFFF end
for i = 0, vr.count - 1 do vr:write(i, tirer()) end
for a = 0x400000, 0x401FFE, 2 do p:write_u16(a, tirer()) end
