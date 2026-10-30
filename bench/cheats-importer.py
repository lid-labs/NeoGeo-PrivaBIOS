#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Thibaut Lion
"""Imports cheats from the MAME XML Cheats Collection (Pugsy and contributors) into `src/c0/cheats.s`.

    python3 -I -B bench/cheats-importer.py <cheat-dir> <ngh.tsv> <cheats.s> <record.tsv>

<cheat-dir> holds the collection's <romset>.xml, <ngh.tsv> the lines "romset NGH fingerprint".

Only what the engine can do is kept: a cheat with at most two unconditional writes to work RAM (a
.pd counts as its two words), every frame or once (UNEFOIS). The cheats already in the table come
first, a game never exceeds CH_MAX, and a cell is not forced twice nor set twice to one value.
"""
import collections
import re
import sys
import xml.etree.ElementTree as E

CH_MAX = 16
ACTION = re.compile(r"^\s*maincpu\.p([bwd])@([0-9A-Fa-f]+)\s*=\s*([0-9A-Fa-f]+)\s*$")
# When a game has more cheats than room, the usual ones go first.
PRIORITE = ["time", "energy|life|health", "lives", "invinc", "power|pow|gauge", "bomb|ammo|weapon", "."]
ABREGES = [("INFINITE", "INF"), ("ALWAYS HAVE ", ""), ("ALWAYS ", ""), ("MAXIMUM", "MAX"), ("MINIMUM", "MIN"),
           ("ENERGY", "ENRG"), ("POWER", "POW"), ("WEAPON", "WEAP"), ("CHARACTER", "CHAR"), ("SPECIAL", "SPEC"),
           ("AMMUNITION", "AMMO"), ("CONTINUES", "CONT"), ("ENABLE ", ""), ("PLAYER ", "P"), ("INVINCIBILITY", "INVINCIBLE")]


def ecritures(cheat):
    """The writes [(address, size, value)] of a cheat the engine can run; None otherwise."""
    if cheat.find("parameter") is not None:
        return None
    w, etats = [], set()
    for s in cheat.findall("script"):
        etats.add(s.get("state", "run"))
        if s.get("condition"):
            return None
        for a in s.findall("action"):
            m = ACTION.match(a.text or "")
            if a.get("condition") or not m:
                return None
            t, adr, val = m[1], int(m[2], 16), int(m[3], 16)
            if t == "b" and val <= 0xFF:
                w.append((adr, 1, val))
            elif t == "w" and val <= 0xFFFF:
                w.append((adr, 2, val))
            elif t == "d" and val <= 0xFFFFFFFF:
                w += [(adr, 2, val >> 16), (adr + 2, 2, val & 0xFFFF)]
            else:
                return None
    if not 1 <= len(w) <= 2 or etats not in ({"run"}, {"on"}):
        return None
    for adr, t, _ in w:
        if not 0x100000 <= adr <= 0x10F2FF or (t == 2 and adr & 1):
            return None
    return w, etats == {"on"}


def nom(desc, pris):
    """A name of at most 16 characters, unique in the game."""
    n = re.sub(r"[^A-Z0-9 &+\-.!/]", " ", desc.upper())
    n = re.sub(r"\b(\d)UP\b", r"P\1", n)
    n = re.sub(r"\s+", " ", n).strip()
    for a, b in ABREGES:
        if len(n) > 16:
            n = n.replace(a, b)
    n = n[:16].rstrip()
    if not n:
        return None
    i, base = 2, n
    while n in pris:
        n = f"{base[:14].rstrip()} {i}"
        i += 1
    pris.add(n)
    return n


def rang(desc):
    return next(i for i, p in enumerate(PRIORITE) if re.search(p, desc, re.I))


def lire(chemin):
    """The importable cheats of a game: (desc, writes), the usual ones first."""
    r = E.fromstring(open(chemin, errors="replace").read())
    c = [(x.get("desc", "").strip(), ecritures(x)) for x in r.findall("cheat")]
    c = [(d, *e) for d, e in c if d and e]
    return sorted(c, key=lambda x: (x[2], rang(x[0])))


def ligne(n, w, unefois):
    v = [f'"{n}"']
    for adr, t, val in w:
        v += [f"0x{adr:06X}", str(t), f"0x{val:0{2 * t}X}"]
    return ("        UNEFOIS " if unefois else "        CHEAT   ") + ", ".join(v)


def main():
    rep, tsv, src, rec = sys.argv[1:5]
    jeux = {}
    for l in open(tsv):
        j, ngh, emp = l.split()
        jeux[(int(ngh, 16), int(emp, 16))] = j
    L = open(src, encoding="utf-8").read().split("\n")
    # The blocks of the table: JEU line, last CHEAT line, cells already used, names.
    blocs, cur = {}, None
    for i, l in enumerate(L):
        m = re.match(r"\s+JEU\s+0x([0-9A-Fa-f]+),\s*0x([0-9A-Fa-f]+),\s*(\d+)", l)
        if m:
            cur = (int(m[1], 16), int(m[2], 16))
            blocs[cur] = dict(jeu=i, fin=i, nb=int(m[3]), cases=set(), noms=set())
        c = re.match(r'\s+(CHEAT|UNEFOIS)\s+"([^"]*)",\s*(0x[0-9A-Fa-f]+),\s*\d,\s*(0x[0-9A-Fa-f]+)', l)
        if c and cur:
            b = blocs[cur]
            b["fin"] = i
            b["noms"].add(c[2])
            if c[1] == "CHEAT":
                b["cases"].add(int(c[3], 16))
            b["cases"].add((int(c[3], 16), int(c[4], 16)))
    ajouts = collections.defaultdict(list)
    nouveaux, journal = [], ["jeu\tngh\tempreinte\tnom\tintitule MAME\tecritures"]
    for cle, j in sorted(jeux.items(), key=lambda x: x[1]):
        try:
            cand = lire(f"{rep}/{j}.xml")
        except (OSError, E.ParseError):
            continue
        b = blocs.get(cle, dict(nb=0, cases=set(), noms=set()))
        pris, add = set(b["noms"]), []
        for desc, w, unefois in cand:
            if b["nb"] + len(add) >= CH_MAX:
                break
            if unefois and any((a, v) in b["cases"] for a, _, v in w):
                continue
            if not unefois and any(a in b["cases"] for a, _, _ in w):
                continue
            n = nom(desc, pris)
            if not n:
                continue
            b["cases"] |= {(a, v) for a, _, v in w}
            if not unefois:
                b["cases"] |= {a for a, _, _ in w}
            add.append(ligne(n, w, unefois))
            journal.append(f"{j}\t{cle[0]:04X}\t{cle[1]:04X}\t{n}\t{desc}\t" + " ".join(f"{a:06X}/{t}/{v:X}" for a, t, v in w))
        if not add:
            continue
        if cle in blocs:
            ajouts[b["fin"]] = add
            L[b["jeu"]] = re.sub(r"(,\s*)\d+(\s*)$", rf"\g<1>{b['nb'] + len(add)}\2", L[b["jeu"]])
        else:
            nouveaux += [f"        JEU     0x{cle[0]:04X}, 0x{cle[1]:04X}, {len(add)}", *add]
    fin = max(b["fin"] for b in blocs.values())
    S = []
    for i, l in enumerate(L):
        S.append(l)
        S += ajouts.get(i, [])
        if i == fin and nouveaux:
            S += ["        | The games below come from the MAME XML Cheats Collection (`bench/cheats-importer.py`),",
                  "        | not proven one by one here.", *nouveaux]
    open(src, "w", encoding="utf-8").write("\n".join(S))
    open(rec, "w", encoding="utf-8").write("\n".join(journal) + "\n")
    print(len(journal) - 1, "cheats importés,", len(nouveaux) and sum(x.lstrip().startswith("JEU") for x in nouveaux), "jeux nouveaux")


main()
