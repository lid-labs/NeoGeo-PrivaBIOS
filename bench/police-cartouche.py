#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Thibaut Lion
"""Decodes the captures of bench/police-cartouche.lua and classifies each glyph.

  bench/police-cartouche.py <game-run-dir> <sheet-png>  -> prints one JSON line of results
  bench/police-cartouche.py --octets "<hex …>" <game-run-dir> <sheet-png> [<witness-dir>]
      -> the test pattern of P_OCTETS (police-cartouche.lua): each byte in 8×16 at $300/$400 + b,
         classified identique / vide / autre against the SFIX (sfix-vide: the SFIX has no stroke there).
         The sheet: the SFIX on top, the S ROM below, one byte per column. With a witness
         (a run of the same list under P_BANQUE=1), "banques" compares the SFIX of the two runs:
         is the stroke of $300/$400 + b that of $100/$200 + b?
"""
import json, sys, zlib, struct
import numpy as np

GLYPHES = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ :-/."
# bytes stored by pixels(): B, G, R
MAG, CYA, JAU = (255, 0, 255), (255, 255, 0), (0, 255, 255)


def charge(d, nom):
    a = np.fromfile(f"{d}/{nom}.bin", np.uint8).reshape(224, 320, 4)[:, :, :3]
    return a


def eq(a, c):
    return (a[:, :, 0] == c[0]) & (a[:, :, 1] == c[1]) & (a[:, :, 2] == c[2])


def decode(d, src):
    """Map of indices 0-15 of the whole screen; -1 = inconsistent (background imitating a colour)."""
    t = charge(d, f"{src}-t")
    nz = eq(t, JAU)
    idx = np.zeros((224, 320), np.int16)
    ok = np.ones((224, 320), bool)
    for b in range(4):
        p = charge(d, f"{src}-p{b}")
        m, c = eq(p, MAG), eq(p, CYA)
        ok &= ~nz | (m | c)
        idx |= (m.astype(np.int16) << b)
    idx[~nz] = 0
    idx[nz & ~ok] = -1
    return idx


def cases(idx):
    """glyph -> (8x8 map, 8x16 map) of indices."""
    r = {}
    for i, ch in enumerate(GLYPHES):
        col, k = 4 + i % 21, i // 21
        l8, l16 = 6 + 2 * k, 12 + 4 * k
        x = col * 8
        y8, y16 = l8 * 8 - 16, l16 * 8 - 16
        r[ch] = (idx[y8:y8 + 8, x:x + 8].copy(), idx[y16:y16 + 16, x:x + 8].copy())
    return r


def hausdorff(a, b):
    """Hausdorff distance between two non-empty masks, in pixels, minimised over a shift
    of -1 to +1 pixel on each axis: the largest gap between a stroke pixel of one and the
    nearest stroke pixel of the other. It tolerates another thickness and another drawing of the
    same character (a thin stroke inside a bold stroke costs 1), but not a missing or extra
    stroke, which leaves pixels far from everything."""
    pa = np.argwhere(a)
    pb = np.argwhere(b)
    best = 1e9
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            q = pa + (dy, dx)
            d = np.sqrt(((q[:, None, :] - pb[None, :, :]) ** 2).sum(-1))
            best = min(best, max(d.min(1).max(), d.min(0).max()))
    return best


SEUIL = 2.0  # pixels


def classe(ch, cart, sfix_tous, k):
    """identique / lisible / vide / autre, on the stroke mask (index 1);
    the SFIX stroke is index 1 (measured/2026-10-20-sfix-glyphes.tsv, point 6)."""
    mc = cart == 1
    ms = sfix_tous[ch][k] == 1
    if (cart == -1).any():
        return "incoherent", 0.0
    if np.array_equal(mc, ms):
        return "identique", 1.0
    if not mc.any():
        return "vide", 0.0
    # lisible: a stroke at most SEUIL pixels from the SFIX one, in the Hausdorff sense. The SFIX
    # space has no stroke: a stroke in its place is "autre". The verdict is confirmed by eye
    # on the sheet; it does not say the character is the right one, only that it has its shape.
    if not ms.any():
        return "autre", -1.0
    h = hausdorff(mc, ms)
    return ("lisible" if h <= SEUIL else "autre"), h


def png(chemin, rgb):
    h, w, _ = rgb.shape
    brut = b"".join(b"\x00" + rgb[y].tobytes() for y in range(h))
    def bloc(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    with open(chemin, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + bloc(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
                + bloc(b"IDAT", zlib.compress(brut, 9)) + bloc(b"IEND", b""))


# sheet colours: 0 black, 1 white (the stroke), 2 dark grey, 3-15 blue, -1 red
COUL = {0: (0, 0, 0), 1: (255, 255, 255), 2: (70, 70, 70), -1: (255, 0, 0)}


def planche(chemin, cart, sfix, verdicts):
    """Two strips per size: SFIX on top, S ROM below, a coloured edge per verdict."""
    Z = 3
    teinte = {"identique": (0, 160, 0), "lisible": (0, 90, 200), "vide": (90, 90, 90),
              "autre": (220, 120, 0), "incoherent": (255, 0, 0)}
    n = len(GLYPHES)
    cw = 10
    hauteur = (8 + 2 + 8 + 4) + (16 + 2 + 16 + 4)
    img = np.full((hauteur, n * cw, 3), 30, np.uint8)
    def pose(m, y, x):
        for v in np.unique(m):
            c = COUL.get(int(v), (60, 120, 255))
            img[y:y + m.shape[0], x:x + m.shape[1]][m == v] = c
    for i, ch in enumerate(GLYPHES):
        x = i * cw + 1
        for k, y0, hh in ((0, 0, 8), (1, 22, 16)):
            pose(sfix[ch][k], y0, x)
            pose(cart[ch][k], y0 + hh + 2, x)
            img[y0 + 2 * hh + 2: y0 + 2 * hh + 3, x - 1:x + 9] = teinte[verdicts[k][ch][0]]
    img = img.repeat(Z, 0).repeat(Z, 1)
    png(chemin, img)


def octets(liste, d, sortie, temoin=None):
    """The test pattern of P_OCTETS: same layout as police-cartouche.lua (21 per row, columns 4 to
    24, lines 8-9, 12-13…). Exact equality of the stroke only: the question is "does the S ROM carry
    this SFIX glyph?", not "does it have a similar drawing of it"."""
    c, s = decode(d, "cart"), decode(d, "sfix")
    r, bandes = {}, []
    for i, h in enumerate(liste):
        col, k = 4 + i % 21, i // 21
        x, y = col * 8, (8 + 4 * k) * 8 - 16
        mc, ms = c[y:y + 16, x:x + 8], s[y:y + 16, x:x + 8]
        if (mc == -1).any() or (ms == -1).any():
            r[h] = "incoherent"
        elif not (ms == 1).any():
            r[h] = "sfix-vide"
        elif np.array_equal(mc == 1, ms == 1):
            r[h] = "identique"
        elif not (mc == 1).any():
            r[h] = "vide"
        else:
            r[h] = "autre"
        bandes.append((ms, mc))
    Z, cw = 4, 10
    img = np.full((16 * 2 + 6, len(liste) * cw, 3), 30, np.uint8)
    for i, paire in enumerate(bandes):
        for j, m in enumerate(paire):
            blk = img[j * 19:j * 19 + 16, i * cw + 1:i * cw + 9]
            blk[m == 1] = COUL[1]
            blk[m > 1] = (60, 120, 255)
            blk[m == -1] = COUL[-1]
    png(sortie, img.repeat(Z, 0).repeat(Z, 1))
    v = list(r.values())
    res = {"compte": {k: v.count(k) for k in sorted(set(v))}, "detail": r}
    if temoin:
        t = decode(temoin, "sfix")
        b = {}
        for i, h in enumerate(liste):
            col, k = 4 + i % 21, i // 21
            x, y = col * 8, (8 + 4 * k) * 8 - 16
            ms, mt = s[y:y + 16, x:x + 8], t[y:y + 16, x:x + 8]
            b[h] = ("incoherent" if (ms == -1).any() or (mt == -1).any()
                    else "identique" if np.array_equal(ms == 1, mt == 1) else "autre")
        w = list(b.values())
        res["banques"] = {k: w.count(k) for k in sorted(set(w))}
        res["banques_detail"] = b
    print(json.dumps(res))


def main():
    if sys.argv[1] == "--octets":
        return octets(sys.argv[2].split(), sys.argv[3], sys.argv[4], sys.argv[5] if len(sys.argv) > 5 else None)
    d, sortie = sys.argv[1], sys.argv[2]
    c, s = cases(decode(d, "cart")), cases(decode(d, "sfix"))
    verdicts = [{}, {}]
    for k in (0, 1):
        for ch in GLYPHES:
            verdicts[k][ch] = classe(ch, c[ch][k], s, k)
    planche(sortie, c, s, verdicts)
    # indices present in the test pattern, by source and by size (for the report)
    def index(src, k):
        return sorted({int(v) for ch in GLYPHES for v in np.unique(src[ch][k])})
    print(json.dumps({
        "v8": {ch: verdicts[0][ch][0] for ch in GLYPHES},
        "v16": {ch: verdicts[1][ch][0] for ch in GLYPHES},
        "s8": {ch: round(float(verdicts[0][ch][1]), 2) for ch in GLYPHES},
        "s16": {ch: round(float(verdicts[1][ch][1]), 2) for ch in GLYPHES},
        "idx_cart8": index(c, 0), "idx_cart16": index(c, 1),
        "idx_sfix8": index(s, 0), "idx_sfix16": index(s, 1),
    }))


main()
