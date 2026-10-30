-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (C) 2026 Thibaut Lion
-- The hardware's power-on: the VRAM and the palette RAM full of noise, before the BIOS's first
-- instruction. Under MAME, measured on 2026-10-27 on aof: the VRAM recorded at frame 1 (SCB1 to
-- SCB3, fix layer) is zero, and a noisy VRAM alone changes no boot picture there, MAME's palettes
-- staying black. Loaded with `son.lua` through J_AUSSI (scene boot-graphismes of `parcours.sh`);
-- plays no input. The noise comes from a fixed seed: two runs receive it identical. Written when
-- the script is loaded, before the first frame.
local m = manager.machine
local vr = emu.item(m.devices[":spritegen"].items["0/m_videoram"])
local p = m.devices[":maincpu"].spaces["program"]
local x = 1448
local function tirer() x = (x * 1103515245 + 12345) % 2147483648 return (x >> 8) & 0xFFFF end
for i = 0, vr.count - 1 do vr:write(i, tirer()) end
for a = 0x400000, 0x401FFE, 2 do p:write_u16(a, tirer()) end
