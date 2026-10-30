#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Thibaut Lion
"""Generates the BIOS call contracts from a bus trace of the co-simulation bench.

    ./bench/generer-contrats.py <trace.txt> [<trace2.txt> ...] <output-dir> [--boot]
    ./bench/generer-contrats.py <trace.txt> [<trace2.txt> ...] <output-dir> --protocole=<site,...>
    ./bench/generer-contrats.py <trace.txt> --part-prom

This is I2 of `docs/tasks.md`: the document an implementation agent receives, and the only one, with
the public documentation (`docs/DECISIONS.md` §1). It is **generated, never written by hand** — that
is what keeps the clean room workable: nobody's code is copied, a trace is read.

WHAT IT DOES NOT NAME. A call is designated by the offset of its entry point in the BIOS
ROM, never by a function name: the offset → name mapping is public
documentation, it lives elsewhere, and mixing it in here would bring an unverifiable source into the
contract.

WHAT IT DOES NOT CARRY, and that is `DECISIONS.md` §8: the values read in the BIOS ROM do not go
into a contract, a sequence of words read there being an SNK data table and not a
behaviour. The generator does not decide on its own which side a value falls on — that criterion
cannot be automated (§8) —, it **flags** the sequences that look like one so that the
call-by-call review settles it before the contract is handed over.

DETERMINISM. Two passes over the same trace give the same bytes: no date, no absolute
path, no iteration over an unsorted dictionary enters the output. That is the acceptance
criterion of I2.
"""

import bisect
import os
import sys

# The memory map, as the co-simulator (unpublished) wires it.
ROM_BIOS = (0xC00000, 0xC1FFFF)
ZONES = (
    ("ram_bios", 0x10FCEE, 0x10FFFF),
    ("pile", 0x10F300, 0x10FCED),
    ("ram_jeu", 0x100000, 0x10F2FF),
    ("p_rom", 0x000000, 0x0FFFFF),
    ("banque_p_rom", 0x200000, 0x2FFFFF),
    ("registres_systeme", 0x300000, 0x3BFFFF),
    ("controle_hc259", 0x3A0000, 0x3AFFFF),
    ("lspc", 0x3C0000, 0x3CFFFF),
    ("palette", 0x400000, 0x401FFF),
    ("carte_memoire", 0x800000, 0x800FFF),
    ("rom_bios", *ROM_BIOS),
    ("backup_ram", 0xD00000, 0xD0FFFF),
)

# A transfer of at least this number of consecutive words read in the ROM is flagged as a possible
# table. Four and not one: an isolated word read in the ROM is the everyday lot of code that reads
# its constants, and flagging everything would amount to flagging nothing.
SEUIL_SEQUENCE = 4

# THE PUBLIC JUMP TABLE, bounds and step: $C00402 to $C006FC, one entry every 6 bytes.
# The "BIOS calls" page of the NeoGeo Development Wiki gives it, and that is what makes it
# public documentation in the sense of `DECISIONS.md` §8: the entry points are admitted there, the
# internal addresses of the code are not.
TABLE_SAUTS = (0xC00402, 0xC006FC, 6)

# The high words of a long that would point into the BIOS ROM: $C00000-$C1FFFF gives $00C0, $00C1.
MOTS_HAUTS_ROM = {f"{h:04X}" for h in range(ROM_BIOS[0] >> 16, (ROM_BIOS[1] >> 16) + 1)}


def grouper(paires):
    """The contiguous ranges of the same value, so that a contract can be read.

    A RAM clear yields hundreds of addresses carrying the same value: listed one by one,
    they drown the few values that make the contract. They are grouped when the address advances
    **by the step of the value** and the value does not change.

    THE STEP FOLLOWS THE WIDTH, and it is not a detail: a step of 2 admitted on bytes would
    merge `$10FD80` and `$10FD82` into one range, while `$10FD81` was never written — the
    range would assert a write that did not happen. A word therefore advances by 2, a byte by 1.

    A word value and a byte value never merge, even when numerically equal:
    `$0000` and `$00` are different strings, and the width of the write is part of the
    behaviour to reproduce.

    Returns triples `(start, end, value)`, `end` being `start` for a one-address range.
    The input must be sorted by address."""
    plages = []
    for adresse, valeur in paires:
        if plages:
            début, fin, val = plages[-1]
            if val == valeur and adresse - fin == (2 if len(val) == 4 else 1):
                plages[-1] = (début, adresse, val)
                continue
        plages.append((adresse, adresse, valeur))
    return plages


def octet_de_remplissage(valeur):
    """The byte a fill repeats, or `None` if this value is not one.

    COMPARING THE VALUES AS THEY ARE DOES NOT RECOGNISE A FILL. A clearing loop in
    `clr.l` writes words `$0000`, and an isolated `move.b` a byte `$00`: those are two different
    strings for the same zero fill. Measured on layer 0 — a single `$00` site among
    389 `$0000` was enough to silence the fill guard. And SNK's memory test `$5555` is the
    same fill as `$55`.

    A word whose two bytes are equal is therefore normalised to that byte. A word whose bytes
    differ is not a fill, and returns `None`."""
    if len(valeur) == 2:
        return valeur
    return valeur[:2] if valeur[:2] == valeur[2:] else None


def site_écrit(adresse, ul):
    """The address a write designates, corrected for the offset of the odd byte.

    The bench logs the **word** address and both strobes: `U.` is UDS
    alone, hence the even byte, and `.L` is LDS alone, hence the odd one. Without this correction, a
    byte write to `$3A0003` would read as `$3A0002` — another HC259 register — and `$10FD83`,
    the country code, would be confused with `$10FD82`, the machine type.

    IT IS NOT A BYTE COUNT, and it must not be read as one. A word write returns
    its even address and touches two bytes: the site `$10FDA2` of value `$0000` says both
    are. Counting the touched bytes would give 86 sites where this split gives 58, over the
    seven calls to `$C0044A` — but a site carries its width in its value, and the width is
    part of the behaviour to reproduce. Melting a word into two bytes would lose it."""
    return adresse + 1 if ul == ".L" else adresse


def valeur_écrite(ul, donnée):
    """The value written, stripped of the bus duplication.

    A BYTE WRITE PUTS THE DATA ON BOTH HALVES OF THE BUS, measured on 2026-10-11 on
    layer 0: a `$80` to `$10FD82` comes out as `8080`, a `$01` to `$10FDAF` as `0101`. Reading the
    sixteen bits would therefore give a value wrong by a factor of 257. The strobe says which half
    is the right one, and that is the one it selects.

    RAISES on a `..` strobe, which transferred nothing: the callers drop these accesses at
    collection, and raising rather than returning `None` makes a forgotten caller break outright
    instead of producing a contract with a hole.

    This function never sees a read, and the bench puts no data on the bus for a
    read: **0 non-zero lines out of 1,793,296 reads**, measured on the four traces of the lot —
    279,352, 314,093, 397,666 and 802,185. A value read therefore has no observable value.

    THAT IS NOT ENOUGH TO HOLD §8, and having believed it cost a review round: a value read then
    **pushed or copied** comes out in the data of a write. That is what a `jsr`
    internal to the BIOS does with its return address, and `valeurs_dérivées_du_pc` stops it."""
    d = int(donnée, 16)
    if ul == "UL":
        return f"{d:04X}"
    if ul == "U.":
        return f"{(d >> 8) & 0xFF:02X}"
    if ul == ".L":
        return f"{d & 0xFF:02X}"
    raise ValueError(f"strobe sans transfert : {ul!r}")


def zone(adresse):
    """The zone of the map that carries this address, or None outside the map.

    When two ranges overlap — `controle_hc259` is included in `registres_systeme` — the
    **narrowest** one wins, not the first of the list: the order of `ZONES` does not enter."""
    trouvee = None
    for nom, bas, haut in ZONES:
        if bas <= adresse <= haut and (trouvee is None or (haut - bas) < trouvee[1]):
            trouvee = (nom, haut - bas)
    return trouvee[0] if trouvee else None


def lire_trace(chemin):
    """The accesses of the trace, in order. A line reads
    `period address rd|WR UL data space` — the format of the co-simulator (unpublished). Lines that
    do not have this form are verilator's headers and warnings: they are skipped."""
    accès = []
    with open(chemin, encoding="utf-8", errors="replace") as f:
        for ligne in f:
            p = ligne.split()
            if len(p) != 6 or p[2] not in ("rd", "WR"):
                continue
            try:
                période, adresse = int(p[0]), int(p[1], 16)
            except ValueError:
                continue
            accès.append((période, adresse, p[2], p[3], p[4], p[5]))
    return accès


def retour_de_l_appelant(accès, de, avant=20, après=3):
    """The call frames rebuilt around the entry, from the most likely to the least likely.

    WHY THE PROGRAM-SPACE TRANSITION IS NOT ENOUGH TO CLOSE A CALL. It closes at the
    next exit from the BIOS ROM, which is right when the caller resumes at once — a game
    that is running. But an interrupt handler returns control **inside** the BIOS, through an `rte`:
    no transition marks it. Measured on the window 330-338, where the BIOS waits, the calls to
    `$C00438` were bounded at 46,769-46,778 accesses, that is 0.9997 to 0.9998 frame, instead of
    1,835-1,847.

    A FRAME WRITTEN AFTER THE ENTRY CAN ONLY BELONG TO THIS CALL: nothing else ran
    in between. A frame written before may be that of an older call, still alive on the
    stack. Hence the order: first the frames completed at or after the entry, nearest first; then
    those before, nearest first. Without this distinction, a game subroutine that calls the
    BIOS makes the call close on **its own** return, and the contract attributes a game write to the
    BIOS — measured on a fabricated trace, and that is the test `UneSousRoutineDuJeu`.

    WE DO NOT CHOOSE, WE PROPOSE: it is `découper` that keeps the first candidate the PC
    really returns to. A pair of zero words rebuilds `$000000`, where the PC never goes.

    THERE IS NEVER MORE THAN ONE CANDIDATE AFTER THE ENTRY **on an entry of the jump table**, and
    that is by construction: the `jmp.l` occupying the slot consumes fetches +1 to +3, so the
    only writes that fall in the later window are the pushes of the `jsr` that has just
    entered. A nested call must let the BIOS execute a few instructions before its own
    `jsr`, and its frame leaves the window. Outside the table the argument does not hold, but
    `point_entrée_public` drops these entries before a contract is written.

    Measured as support, not as proof: none of the 51 entries of the four traces of the lot has two
    later candidates. The relative order of these candidates therefore never decides anything, and a
    mutation that reverses it has no effect — it is not a coverage hole.

    THE ORDER OF THE WRITES IS NOT THAT OF THE ADDRESSES: the 68000 pushes the low PC, then SR, then
    the high PC. Frames are therefore rebuilt by address, and a frame is "completed" at the later of
    its two writes.

    THE WINDOW IS CALIBRATED ON WHAT THE HARDWARE DOES, and its margin is thin. Measured: a `jsr`
    pushes at +1 and +2 accesses from the entry; an exception pushes at -15, -13 and -12, the fetches of the
    cartridge stub that follows the vector accounting for most of the gap. A stub longer
    by six fetches would take the frame out of the window, and `découper` would fall back on the old
    bound — it then **says so** on `stderr`, instead of taking it back silently."""
    indice, valeur = {}, {}
    for j in range(max(0, de - avant), min(len(accès), de + après + 1)):
        _, adresse, sens, ul, donnée, espace = accès[j]
        if sens == "WR" and ul == "UL" and espace == "sd":
            indice[adresse], valeur[adresse] = j, donnée
    cadres = []
    for a, d in valeur.items():
        if a + 2 in valeur:
            v = (int(d, 16) << 16) | int(valeur[a + 2], 16)
            if v <= 0xFFFFFF:
                cadres.append((max(indice[a], indice[a + 2]), a, v))
    après_entrée = sorted((k - de, a, v) for k, a, v in cadres if k >= de)
    avant_entrée = sorted((de - k, a, v) for k, a, v in cadres if k < de)
    return [(a, v) for _, a, v in après_entrée] + [(a, v) for _, a, v in avant_entrée]

def découper(accès):
    """The BIOS calls: entry by program-space transition, exit on return to the caller.

    The entry is a fetch in the BIOS ROM that follows a fetch outside it. The **exit** is the
    moment the PC reaches the return address that a frame of `retour_de_l_appelant` announces, the
    first candidate that checks out winning.

    FAILING A VERIFIED CANDIDATE, fallback on the first exit from the BIOS ROM — the old criterion,
    right when the caller resumes at once. The fallback **reports itself on `stderr`**: it takes
    back a bound that can be worth a whole frame, and keeping quiet about it would suggest a fine
    measurement.

    A call left open at the end of the trace is dropped: its surface would be truncated."""
    bios = lambda a: ROM_BIOS[0] <= a <= ROM_BIOS[1]
    prog = [(i, a) for i, (_, a, _, _, _, e) in enumerate(accès) if e == "sp"]

    # The positions of each address in the fetch stream, to search by bisection instead
    # of walking again from the start: the naive search was quadratic, 1.1 s on 3.2 M
    # accesses against 0.06 s on 0.4 M.
    positions = {}
    for rang, (_, a) in enumerate(prog):
        positions.setdefault(a, []).append(rang)
    sorties = [rang for rang, (_, a) in enumerate(prog) if not bios(a)]

    entrées = [(i, a, k) for k, (i, a) in enumerate(prog)
               if k > 0 and bios(a) and not bios(prog[k - 1][1])]

    appels, replis = [], 0
    for i, entrée, rang in entrées:
        fin_, retour, par_repli = None, None, False
        for _, cible in retour_de_l_appelant(accès, i):
            suite = positions.get(cible)
            if not suite:
                continue
            k = bisect.bisect_right(suite, rang)
            if k < len(suite):
                fin_, retour = prog[suite[k]][0], cible
                break
        if fin_ is None:
            k = bisect.bisect_right(sorties, rang)
            if k < len(sorties):
                fin_, retour = prog[sorties[k]][0], prog[sorties[k]][1]
                replis += 1
                par_repli = True
        if fin_ is not None:
            # `repli` says HOW the call closed, and the protocol depends on it: a call closed
            # by fallback has no frame, so its exit point is not a `jsr` return —
            # it is the signature of an entry by `jmp`, which returns control by another `jmp`.
            appels.append({"entrée": entrée, "de": i, "à": fin_,
                           "période": accès[i][0], "retour": retour, "repli": par_repli})
    if replis:
        print(f"{replis} appel(s) fermé(s) par repli : aucun cadre d'appel reconstructible dans la "
              f"fenêtre, la borne est celle de la sortie de la ROM du BIOS et peut valoir une trame "
              f"entière.", file=sys.stderr)
    return appels
def point_entrée_public(adresse):
    """True if this address is a slot of the public jump table.

    WHY THIS FILTER. `découper` takes as "entry" any transition from the P-ROM to the BIOS
    ROM in program space. That is right for a call from the game to the BIOS, but not for the
    reverse path: if the BIOS calls a game routine by `jsr` — the wiki names some, such as
    `PLAYER_START` —, the return by `rts` brings back into the BIOS at the instruction following the `jsr`,
    which is an **internal** address. It would then be published as an entry point, in the title of
    the document and in its file name.

    None of the three SNK BIOS traces of the lot carries such an excursion: all their
    transitions fall on a slot of the table. The filter is therefore a guard, not a fix
    for an observed defect — but §8 does not rest on the luck of one set of traces."""
    bas, haut, pas = TABLE_SAUTS
    return bas <= adresse <= haut and (adresse - bas) % pas == 0


def valeurs_dérivées_du_pc(accès, de, à):
    """The sites whose written value is, or completes, an internal address of the BIOS ROM.

    THE SEQUENCE GUARD DOES NOT SEE THIS CASE, and that is why a second one is needed. A `jsr`
    internal to the BIOS pushes its return address: it is a RAM write whose **value** is
    an address of the BIOS ROM, and nothing was read in a table. The value comes from the PC.
    `DECISIONS.md` §8 keeps these addresses out of the contract, so these values must leave it.

    Measured on the seven calls to `$C0044A` of the window 505-511: **161 pairs** of words forming
    a long in `$C00000`-`$C1FFFF`, all in zone `ram_jeu`, where the BIOS stack goes down.

ONE CRITERION IS ENOUGH, and it is measured: the value **is** a high word of the range (`$00C0`,
    `$00C1`), hence the high half of a ROM address, and the next site carries its low
    half. Since `MOTS_HAUTS_ROM` is derived from the bounds of `ROM_BIOS`, any long that falls in the
    range necessarily has its high word in this set.

    The first version added a second criterion — two word writes at consecutive
    addresses whose long falls in the range — announcing that it "caught what the
    first misses". It caught nothing: on the four traces of the lot, both criteria
    give the **same set** (15, 6, 21 and 4 sites, empty symmetric difference). And it was
    weaker, because it required the order: the high word written before the low one. On `snk505`, 10
    ROM longs are written in the other order, which criterion 1 catches and the second one
    missed. It is removed.

    WHAT STILL ESCAPES, and it must be said rather than kept quiet. Two cases, both out of
    the criterion's reach:

    - an address written **byte by byte** puts no `$00C0` or `$00C1` on the bus as a
      word. None of the four traces carries a byte write of value `$C0` or `$C1`, but
      that is an observation on these traces, not a guarantee;
    - a **low half written alone** — a 16-bit offset into the ROM, without its high word —
      is not recognisable: the criterion acts only on the pair. Nothing allows it to be
      told apart from an ordinary value without knowing the content of the ROM, so this case is
      not measurable on a trace.

    Returns the set of sites to withhold. The **value** is withheld, not the address: §8 admits
    the address of a RAM write, it is the value that carries the internal address."""
    retenus = set()
    for _, adresse, sens, ul, donnée, espace in accès[de:à]:
        if sens == "WR" and ul == "UL" and espace != "sp" and donnée in MOTS_HAUTS_ROM:
            retenus.add(adresse)
            retenus.add(adresse + 2)        # the low word of the same long address
    return retenus


def séquences_suspectes(accès, de, à):
    """The transfers that look like a table copied from the BIOS ROM (§8).

    The provenance of a value is not sought — the trace does not show the registers, so
    nobody can establish it here. We count the **words read at increasing and
    contiguous addresses in the ROM, in DATA space**, and flag it beyond the threshold.

    THE DATA SPACE IS NOT A WHIM. Without this filter, the count catches the **instruction
    stream**: the 68000 prefetches, so code that executes reads by definition contiguous
    words in the ROM. Measured on `$C0044A`: 46 sequences flagged without the filter, 22 of them of
    four words — it was the execution we were seeing, not tables.

    WHAT THE FILTER MISSES, and `DECISIONS.md` §8 says it of the criterion itself: a table read in
    PC-relative mode comes out in program space, like an immediate, and so escapes the flagging.
    That is the reason why the contract is reviewed call by call instead of validating itself."""
    suspectes, début, précédente, n = [], None, None, 0
    for _, adresse, sens, _, _, espace in accès[de:à]:
        if sens == "rd" and espace == "sd" and ROM_BIOS[0] <= adresse <= ROM_BIOS[1]:
            if précédente is not None and adresse == précédente + 2:
                n += 1
            else:
                if n >= SEUIL_SEQUENCE:
                    suspectes.append((début, précédente, n))
                début, n = adresse, 1
            précédente = adresse
        else:
            if n >= SEUIL_SEQUENCE:
                suspectes.append((début, précédente, n))
            début, précédente, n = None, None, 0
    if n >= SEUIL_SEQUENCE:
        suspectes.append((début, précédente, n))
    return suspectes


def la_main_au_bios(accès):
    """For each access: was the last program-space access in the BIOS ROM?

    A call can hand control back to the cartridge along the way — measured at the START of
    `puzzledp`: the call to `$C0044A` of frame 560.23 keeps it for nearly two frames, and 15,025 of
    its 16,612 writes fall while the cartridge code is executing (zone `ram_jeu`, the game's
    start of play session). Attributing them to the call would drown the contract under a behaviour
    that is not the BIOS's, and that an implementer does not have to reproduce.

    The criterion remains that of `découper`: the program space says who has control. The 68000's
    prefetch may shift the boundary by a few accesses around a transfer; on a given trace,
    the result does not change, and the determinism of I2 holds."""
    dedans, au_bios = [], True
    for _, adresse, _, _, _, espace in accès:
        if espace == "sp":
            au_bios = ROM_BIOS[0] <= adresse <= ROM_BIOS[1]
        dedans.append(au_bios)
    return dedans


def contrat(accès, appels, entrée, dedans=None):
    """What the calls of one entry point have in common, and what sets them apart."""
    miens = [a for a in appels if a["entrée"] == entrée]
    if not miens:
        # An entry point none of whose calls closed has no contract: its surface is
        # unknown, not empty. Return None rather than crash on an empty list of periods.
        return None
    if dedans is None:
        dedans = la_main_au_bios(accès)
    écritures, valeurs, pc = [], {}, set()
    cartouche = 0
    for a in miens:
        pc |= valeurs_dérivées_du_pc(accès, a["de"], a["à"])
    for a in miens:
        w = set()
        for i in range(a["de"], a["à"]):
            _, adresse, sens, ul, donnée, espace = accès[i]
            # `..`: neither UDS nor LDS, so nothing crossed the bus. It is dropped here rather than
            # letting `valeur_écrite` return a None that would end up in a `sorted()`.
            if (sens == "WR" and ul != ".." and espace != "sp"
                    and zone(adresse) not in (None, "rom_bios")):
                if not dedans[i]:
                    cartouche += 1
                    continue
                octet = site_écrit(adresse, ul)
                w.add(octet)
                # The set of values seen at this address: a single one makes a hard contract,
                # several say "it writes here, according to a state the trace does not show".
                valeurs.setdefault(octet, set()).add(valeur_écrite(ul, donnée))
        écritures.append(w)
    toutes = sorted(set().union(*écritures)) if écritures else []
    # 811,008 periods per frame, measured between two VSYNC edges on the co-simulator.
    périodes = [accès[a["de"]][0] for a in miens] + [accès[a["à"]][0] for a in miens]
    return {
        "entrée": entrée,
        "appels": len(miens),
        "trame_de": min(périodes) / 811008,
        "trame_à": max(périodes) / 811008,
        "tailles": sorted(a["à"] - a["de"] for a in miens),
        "retours": sorted({a["retour"] for a in miens}),
        "écritures": [(adresse, zone(adresse), sum(1 for w in écritures if adresse in w),
                       sorted(valeurs.get(adresse, set())))
                      for adresse in toutes],
        "suspectes": sorted({s for a in miens for s in séquences_suspectes(accès, a["de"], a["à"])}),
        "pc": pc,
        "écritures_cartouche": cartouche,
    }


def écrire(c, dossier):
    """The document of an entry point. Markdown, so that it reads without a tool."""
    chemin = f"{dossier}/appel_{c['entrée']:06X}.md"
    stables = [e for e in c["écritures"] if e[2] == c["appels"]]
    variables = [e for e in c["écritures"] if e[2] != c["appels"]]
    # THE §8 GUARD. A value written to RAM can come out of a table read in the BIOS ROM, and §8
    # then forbids carrying the bytes: only the fact of the transfer enters the contract. It cannot
    # be proven from the trace, which does not show the registers — so as soon as a
    # sequence is flagged on this call, the values are withheld wholesale. It is coarse, and
    # that is the intended direction: doubt removes the value, it does not let it through.
    valeurs_retenues = bool(c["suspectes"])

    def colonne(vals, adresse=None):
        """The value cell: a single one seen, several, withheld, or not applicable.

        THE HC259 IS AN ADDRESSABLE LATCH: the command is carried by the address, and the bus data
        is ignored by the hardware. Displaying `2 valeurs : $FE, $FF` there would suggest a value to
        reproduce, while both have no effect. The `--boot` mode already said so of its
        handshake; a call contract is read on its own, so it must say so too."""
        if adresse is not None and zone(adresse) == "controle_hc259":
            return "sans objet — verrou adressé"
        if adresse is not None and adresse in c["pc"]:
            return "retenue (§8 : adresse de ROM BIOS)"
        if valeurs_retenues:
            return "retenue (§8)"
        if not vals:
            return "—"
        if len(vals) == 1:
            return f"`${vals[0]}`"
        return f"{len(vals)} valeurs : " + ", ".join(f"`${v}`" for v in vals[:4]) + \
               ("…" if len(vals) > 4 else "")
    with open(chemin, "w", encoding="utf-8") as f:
        f.write(f"# Appel `${c['entrée']:06X}`\n\n")
        f.write("**Généré par `bench/generer-contrats.py`. Ne pas éditer à la main** : le contrat "
                "tire son autorité de la trace, et une retouche la lui retire.\n\n")
        f.write(f"- Relevé sur **{c['appels']} appel(s)**, trames {c['trame_de']:.2f} à "
                f"{c['trame_à']:.2f} — les siennes, non celles de toute la trace\n")
        f.write(f"- Taille, en accès tracés : {', '.join(str(t) for t in c['tailles'])}\n")
        # §8: A RETURN ADDRESS CAN BE INTERNAL TO THE BIOS ROM. That is the case of an
        # interrupt handler, which returns control by an `rte` where the BIOS had been
        # interrupted — measured on `$C00438`, which comes back into the BIOS ROM. Publishing it
        # would recreate the leak that the second guard closes on the values side.
        dehors = [r for r in c["retours"] if not (ROM_BIOS[0] <= r <= ROM_BIOS[1])]
        dedans = len(c["retours"]) - len(dehors)
        morceaux = [f"`${r:06X}`" for r in dehors]
        if dedans:
            morceaux.append(f"{dedans} adresse(s) retenue(s), internes à la ROM du BIOS (§8)")
        f.write("- Retour vers : " + (", ".join(morceaux) or "—") + "\n")
        if c["écritures_cartouche"]:
            f.write(f"- **{c['écritures_cartouche']} écriture(s) hors contrat** : faites pendant "
                    f"que la cartouche avait la main (dernier accès en espace programme hors de la "
                    f"ROM du BIOS). L'appel la lui a rendue en cours de route ; ces écritures sont "
                    f"le comportement du jeu, pas celui du BIOS\n")
        f.write("\n")
        f.write("## Écritures communes à tous les appels\n\n")
        f.write("Le noyau du contrat : ce que l'appel écrit à chaque fois.\n\n")
        f.write("| Adresse | Zone | Valeur écrite |\n|---|---|---|\n")
        for adresse, z, _, vals in stables:
            f.write(f"| `${adresse:06X}` | {z} | {colonne(vals, adresse)} |\n")
        if not stables:
            f.write("| — | aucune | — |\n")
        f.write("\n## Écritures d'une partie des appels seulement\n\n")
        if variables:
            f.write("À ne pas prendre pour le contrat : ces adresses dépendent d'un état que la "
                    "trace ne montre pas.\n\n| Adresse | Zone | Appels | Valeur écrite |"
                    "\n|---|---|---|---|\n")
            for adresse, z, n, vals in variables:
                f.write(f"| `${adresse:06X}` | {z} | {n}/{c['appels']} | {colonne(vals, adresse)} |\n")
        else:
            f.write("Aucune : les appels relevés écrivent tous les mêmes adresses.\n")
        f.write("\n## Séquences lues dans la ROM du BIOS\n\n")
        if c["suspectes"]:
            # THE ADDRESSES OF THESE SEQUENCES DO NOT GO HERE: §8 excludes from the contract the
            # internal addresses of the BIOS ROM, and a sequence is there by definition. Its
            # size is given, which is enough to decide whether to look; whoever settles it has the
            # trace.
            f.write(f"**À trancher avant de remettre ce contrat** (`DECISIONS.md` §8) : une suite "
                    f"de mots lue dans la ROM peut être une table de données, qui n'entre pas dans "
                    f"un contrat. Seuil de signalement : {SEUIL_SEQUENCE} mots contigus.\n\n")
            f.write(f"**{len(c['suspectes'])} séquence(s)**, de "
                    f"{min(n for _, _, n in c['suspectes'])} à "
                    f"{max(n for _, _, n in c['suspectes'])} mots.\n\n")
            f.write("Leurs adresses ne figurent pas dans ce document : §8 garde les adresses "
                    "internes de la ROM hors du contrat. Elles se retrouvent dans la trace, que "
                    "le relecteur a.\n")
        else:
            f.write(f"Aucune suite de {SEUIL_SEQUENCE} mots contigus ou plus. Rien à trancher.\n")
        f.write("\n## Ce que ce contrat ne dit pas\n\n")
        if valeurs_retenues:
            f.write("- **Les valeurs écrites sont retenues** : une séquence est signalée ci-dessus, "
                    "et §8 interdit de porter les octets d'une table lue dans la ROM. Les adresses "
                    "restent, le transfert est signalé, les octets non.\n")
        else:
            f.write("- **Aucune valeur lue n'est portée directement** : le banc ne pose aucune "
                    "donnée sur le bus pour une lecture, donc une lecture n'a pas de valeur "
                    "observable. **Cela ne suffit pas à tenir §8** : une valeur lue puis empilée "
                    "ou recopiée ressort dans la donnée d'une écriture, et c'est pourquoi les "
                    "gardes ci-dessous existent.\n")
        if c["pc"]:
            f.write(f"- **{len(c['pc'])} site(s) ont leur valeur retenue parce qu'elle porte une "
                    f"adresse interne de la ROM du BIOS** : un `jsr` interne empile son adresse de "
                    f"retour, et §8 garde ces adresses hors du contrat. L'adresse de l'écriture "
                    f"reste, sa valeur non. Ces sites sont pour l'essentiel la **pile du BIOS**, "
                    f"que rien n'oblige une autre implémentation à reproduire — elle empilera ses "
                    f"propres adresses.\n")
        f.write("- **La signature de l'appel non plus.** Les paramètres passent par les registres "
                "du 68000, que le bus ne montre pas : une trace donne les effets d'un appel, pas "
                "sa signature.\n")
        f.write("- **Le nom de l'appel non plus** : ce document le désigne par son offset. La "
                "correspondance avec un nom est de la documentation publique.\n")
    return chemin


def contrat_boot(accès, dossier):
    """The POWER-ON contract, which is not a call and is not split as one.

    At boot, everything executes in the BIOS ROM: there is no program-space transition
    between it and the P-ROM, so `découper()` returns nothing. What the contract carries here is a
    **sequence** — the vectors read, the entry point, the register handshake, and what
    the RAM receives — and that is what layer 0 must reproduce.

    §8 HOLDS HERE TOO: the entry point enters the contract, the internal addresses of the ROM
    do not. So neither the sequence of fetches nor the addresses of the code walked through are
    carried."""
    T = 811008
    vecteurs = [a for a in accès[:8] if a[1] <= 0x0007 and a[2] == "rd"]
    # The entry point: the first fetch in the BIOS ROM, which the vector points to.
    entrée = next((a[1] for a in accès if a[5] == "sp" and ROM_BIOS[0] <= a[1] <= ROM_BIOS[1]), None)
    contrôle = [(per, site_écrit(adresse, ul), valeur_écrite(ul, donnée))
                for per, adresse, sens, ul, donnée, _ in accès
                if sens == "WR" and ul != ".." and 0x3A0000 <= adresse <= 0x3AFFFF]
    écrit, valeurs = {}, {}
    for per, adresse, sens, ul, donnée, espace in accès:
        if sens != "WR" or ul == ".." or espace == "sp":
            continue
        z = zone(adresse)
        if z in (None, "rom_bios"):
            continue
        octet = site_écrit(adresse, ul)
        e = écrit.setdefault(z, [0, set()])
        e[0] += 1
        e[1].add(octet)
        valeurs.setdefault(octet, set()).add(valeur_écrite(ul, donnée))
    susp_boot = séquences_suspectes(accès, 0, len(accès))
    # Same guard as in the call contract: a flagged sequence withholds the values wholesale.
    retenues = bool(susp_boot)
    # The BIOS RAM sites whose value does not vary over the recorded window.
    #
    # THIS IS NOT "THE STATE AT THE END OF BOOT", and the difference nearly produced a wrong
    # contract. A value constant over a window says nothing about what follows the window: on an SNK
    # dump, the first frames carry the patterns of the MEMORY TEST — `0x55`, then `0xAA`, then a
    # value derived from the address —, and the BIOS variables only mean something from
    # frame ~300 on (`docs/BENCH.md`, pitfall 7). The boot window stops at 9.2.
    #
    # Hence the guard below: if ALL these sites carry the SAME value, it is the signature of a
    # fill — test pattern, or clear — and not of a state. The contract then says so instead
    # of presenting the pattern as something to reproduce.
    # THE SECOND GUARD APPLIES HERE TOO, and it was missing. `contrat()` applied it, `contrat_boot`
    # did not: on the window 330-338, the contract published both halves of an internal return
    # address of the BIOS, at `$10FF00` and `$10FF02`. The boot window showed none of it by
    # luck — its ROM longs fall in `ram_jeu`, which this section does not publish.
    #
    # THE LEAKED ADDRESS IS NOT COPIED HERE, and that is the point: the first version of this
    # comment quoted it in clear, which recreated the leak in the very text that describes it.
    # The sites are enough to find the case again in the trace; the value need not be written.
    pc = valeurs_dérivées_du_pc(accès, 0, len(accès))
    constants = sorted((o, sorted(v)[0]) for o, v in valeurs.items()
                       if len(v) == 1 and zone(o) == "ram_bios" and o not in pc)
    retenus_pc = sum(1 for o in valeurs if zone(o) == "ram_bios" and o in pc)
    octets = {octet_de_remplissage(v) for _, v in constants}
    remplissage = len(constants) > 1 and len(octets) == 1 and None not in octets
    chemin = f"{dossier}/boot.md"
    with open(chemin, "w", encoding="utf-8") as f:
        f.write("# Mise sous tension\n\n")
        f.write("**Généré par `bench/generer-contrats.py --boot`. Ne pas éditer à la main.**\n\n")
        f.write(f"- Relevé sur les trames {accès[0][0]/T:.3f} à {accès[-1][0]/T:.3f}\n")
        f.write(f"- {len(accès)} accès tracés\n\n")
        f.write("## Le vecteur de reset\n\n")
        f.write("Les premiers accès du 68000, en espace programme, avant toute autre chose :\n\n")
        f.write("| Adresse | Octets |\n|---|---|\n")
        for _, adresse, _, ul, _, _ in vecteurs:
            f.write(f"| `${adresse:06X}` | {ul} |\n")
        f.write(f"\nPuis le premier fetch dans la ROM du BIOS tombe à "
                f"**`${entrée:06X}`** — le point d'entrée.\n" if entrée else "\n")
        f.write("\n## La poignée de main\n\n")
        f.write("Les écritures de registre du HC259, dans l'ordre. C'est **tout** ce que le boot y "
                "écrit sur la fenêtre relevée :\n\n")
        f.write("Le HC259 est un verrou adressé : **c'est l'adresse qui porte l'ordre**, et la "
                "donnée du bus est ignorée. La colonne est donnée pour mémoire, pas comme une "
                "valeur à reproduire.\n\n")
        f.write("| Trame | Octet écrit | Registre | Donnée du bus |\n|---|---|---|---|\n")
        for per, octet, val in contrôle:
            f.write(f"| {per/T:.3f} | `${octet:06X}` | `{octet & 0x1F:#04x}` | `${val}` |\n")
        if not contrôle:
            f.write("| — | — | aucune | — |\n")
        f.write("\n## Ce que la RAM et les registres reçoivent\n\n")
        f.write("| Zone | Écritures | Adresses distinctes |\n|---|---|---|\n")
        for z in sorted(écrit):
            f.write(f"| {z} | {écrit[z][0]} | {len(écrit[z][1])} |\n")
        f.write("\n## Ce que la RAM BIOS reçoit de constant sur la fenêtre\n\n")
        if retenues:
            f.write("**Retenu** : une séquence est signalée plus bas, et §8 interdit de porter les "
                    "octets d'une table lue dans la ROM.\n")
        elif remplissage:
            oct_rempl = sorted(octets)[0]
            f.write(f"**Ce n'est pas un état, c'est un remplissage** : les {len(constants)} sites "
                    f"de RAM BIOS écrits sur cette fenêtre répètent **tous** l'octet "
                    f"`${oct_rempl}`. Une valeur "
                    f"unique sur toute la zone est la signature d'un motif de test mémoire ou d'un "
                    f"vidage, pas d'un état à reproduire — sur un dump SNK, les premières trames "
                    f"écrivent `0x55`, puis `0xAA`, puis une valeur dérivée de l'adresse, et les "
                    f"variables du BIOS ne valent quelque chose qu'à partir de la trame ~300.\n\n"
                    f"La fenêtre de ce relevé s'arrête à la trame {accès[-1][0]/T:.2f}. **Pour "
                    f"obtenir l'état, il faut une fenêtre plus tardive**, et ce contrat ne la "
                    f"porte pas.\n\n"
                    f"**Ce que ce garde ne voit pas**, et qui doit rester en tête : un motif qui "
                    f"**varie avec l'adresse** — le troisième du test mémoire de SNK en est un — "
                    f"ne répète aucun octet, donc il échappe au garde et serait présenté comme "
                    f"un état.\n\n"
                    f"**Le verdict se pèse au compte**, et le garde ne le fait pas à votre place : "
                    f"il parle dès deux sites. Ici il y en a {len(constants)}, ce qui rend la "
                    f"conclusion solide ; sur deux ou trois, une valeur commune ne dirait pas "
                    f"grand-chose et c'est au relecteur d'en juger.\n")
        elif constants:
            plages = grouper(constants)
            f.write(f"Les **{len(constants)} sites de RAM BIOS** dont la valeur ne varie pas sur "
                    f"la fenêtre relevée, groupés en {len(plages)} plage(s) contiguë(s) de même "
                    f"valeur. Un site est une adresse **et une largeur** : une valeur de quatre "
                    f"chiffres est un mot, de deux un octet.\n\n"
                    f"**Constant sur une fenêtre ne veut pas dire laissé en fin de boot** : rien "
                    f"ici ne dit ce qui suit la fenêtre.\n\n| Plage | Valeur |\n|---|---|\n")
            for début, fin, val in plages:
                où = f"`${début:06X}`" if début == fin else f"`${début:06X}`-`${fin:06X}`"
                f.write(f"| {où} | `${val}` |\n")
        else:
            f.write("Aucun site de RAM BIOS ne reçoit une valeur constante sur cette fenêtre.\n")
        if retenus_pc:
            f.write(f"\n**{retenus_pc} site(s) de RAM BIOS sont écartés de ce qui précède** parce "
                    f"que leur valeur porte une adresse interne de la ROM du BIOS — une adresse de "
                    f"retour empilée, le plus souvent. `DECISIONS.md` §8 les garde hors du "
                    f"contrat.\n")
        susp = susp_boot
        f.write("\n## Séquences lues dans la ROM du BIOS\n\n")
        if susp:
            f.write(f"**À trancher** (`DECISIONS.md` §8) : **{len(susp)} séquence(s)** de "
                    f"{min(n for _, _, n in susp)} à {max(n for _, _, n in susp)} mots, lues en "
                    f"espace donnée. Leurs adresses ne figurent pas ici, §8 gardant les adresses "
                    f"internes de la ROM hors du contrat.\n")
        else:
            f.write(f"Aucune suite de {SEUIL_SEQUENCE} mots contigus ou plus lue en espace "
                    f"donnée. Rien à trancher.\n")
        f.write("\n## Ce que ce contrat ne dit pas\n\n")
        f.write("- **Ni les adresses internes de la ROM du BIOS, ni la suite de ses fetchs** : "
                "`DECISIONS.md` §8 les garde hors du contrat. Seul le point d'entrée y figure.\n")
        if retenues:
            f.write("- **Les valeurs écrites sont retenues** : voir la séquence signalée ci-dessus "
                    "et `DECISIONS.md` §8.\n")
        else:
            f.write("- **Aucune valeur lue n'est portée directement** : le banc ne pose aucune "
                    "donnée sur le bus pour une lecture. Cela ne suffit pas à tenir §8 — une "
                    "valeur lue puis empilée ressort dans la donnée d'une écriture —, d'où les "
                    "gardes.\n")
        f.write("- **Ni l'ordre des écritures en RAM**, hors poignée de main.\n")
    return chemin


def protocole_trace(accès, sites):
    """The protocol events of a trace: writes to the tracked sites, hand-overs.

    WHY THIS MODE EXISTS. `USER` is not a BIOS entry but the cartridge's routine
    (`docs/tasks.md`): no call contract says what the BIOS writes BEFORE handing control
    to it, nor when it hands it over. These writes fall outside any bounded call, hence outside the
    contracts — this mode records them, on the sites the operator gives. The generator **names
    nothing**: the choice of sites is sourced in the review (§8), not here.

    A HAND-OVER IS NOT A CALL RETURN. The BIOS → cartridge transitions in program
    space are of two kinds: the bound of a call closed by a verified frame — an `rts`,
    already covered by the call contracts — and everything else: the exit of a call entered by
    `jmp` (closed by fallback, without a frame), or an excursion in the middle of a call. That rest is the
    protocol, and that is what is chronicled.

    WHO HAS CONTROL follows `la_main_au_bios`: a game write on a tracked site is seen, but
    marked as its own — it is not a BIOS behaviour to reproduce."""
    appels = découper(accès)
    dedans = la_main_au_bios(accès)
    pc = valeurs_dérivées_du_pc(accès, 0, len(accès))
    retenues = bool(séquences_suspectes(accès, 0, len(accès)))
    bios = lambda a: ROM_BIOS[0] <= a <= ROM_BIOS[1]

    # The writes AND the reads that touch a tracked site. `touchés` follows the width: a
    # word covers its even byte and the odd one, and an odd tracked site must see the word that
    # writes it go by. A READ IS A PROTOCOL FACT TOO: a BIOS that polls the answer of a
    # port reads it in a loop, and keeping these reads quiet would suggest a blind send. Its value
    # is not observable (the bench puts no data on the bus for a read): the
    # chronicle says so, it invents no byte.
    écritures = []
    for i, (période, adresse, sens, ul, donnée, espace) in enumerate(accès):
        if ul == ".." or espace == "sp":
            continue
        touchés = {adresse, adresse + 1} if ul == "UL" else {site_écrit(adresse, ul)}
        if touchés.isdisjoint(sites):
            continue
        if sens == "rd":
            valeur = "lecture — valeur non observable"
        elif retenues or adresse in pc:
            valeur = "retenue (§8)"
        else:
            valeur = f"`${valeur_écrite(ul, donnée)}`"
        écritures.append((période, site_écrit(adresse, ul), valeur,
                          "bios" if dedans[i] else "cartouche"))

    # Repeated events are folded: a BIOS that rewrites the same site every frame would make
    # a document of hundreds of identical lines, where the transition that matters can no longer be
    # seen.
    repliées = []
    for période, site, valeur, main in écritures:
        if repliées and repliées[-1][1:4] == (site, valeur, main):
            première, _, _, _, _, compte = repliées[-1]
            repliées[-1] = (première, site, valeur, main, période, compte + 1)
        else:
            repliées.append((période, site, valeur, main, période, 1))

    # The BIOS → cartridge transitions, minus the call returns verified by a frame.
    retours_vérifiés = {a["à"] for a in appels if not a["repli"]}
    spans = [(a["de"], a["à"], a["entrée"]) for a in appels]
    remises, retours = [], {}
    précédent_bios = None
    for i, (période, adresse, _, _, _, espace) in enumerate(accès):
        if espace != "sp":
            continue
        if précédent_bios and not bios(adresse):
            if i in retours_vérifiés:
                retours[adresse] = retours.get(adresse, 0) + 1
            else:
                contexte = "—"
                for de, à, entrée in spans:
                    if de <= i <= à:
                        contexte = (f"appel entré à `${entrée:06X}`" if point_entrée_public(entrée)
                                    else "appel entré à une adresse interne (§8)")
                        break
                remises.append((période, adresse, contexte))
        précédent_bios = bios(adresse)
    return {
        "trame_de": accès[0][0] / 811008,
        "trame_à": accès[-1][0] / 811008,
        "écritures": repliées,
        "remises": remises,
        "retours": sorted(retours.items()),
        "retenues": retenues,
    }


def écrire_protocole(sections, sites, dossier):
    """The protocol document: one section per trace, chronology of the tracked sites and of the
    hand-overs. Markdown, same rules as the contracts — §8 included."""
    T = 811008
    chemin = f"{dossier}/protocole.md"
    with open(chemin, "w", encoding="utf-8") as f:
        f.write("# Protocole — sites suivis et remises de main\n\n")
        f.write("**Généré par `bench/generer-contrats.py --protocole`. Ne pas éditer à la "
                "main.**\n\n")
        f.write("Sites suivis, donnés par l'opérateur — leur choix se source dans la relecture "
                "(`DECISIONS.md` §8), ce document ne les nomme pas :\n\n")
        f.write("| Site | Zone |\n|---|---|\n")
        for s in sites:
            f.write(f"| `${s:06X}` | {zone(s) or 'hors carte'} |\n")
        f.write("\nUne **remise de main** est une transition BIOS → cartouche en espace programme "
                "qui n'est pas le retour vérifié d'un appel : la sortie d'un appel entré par "
                "`jmp`, ou une excursion au milieu d'un appel. Les retours d'appel vérifiés sont "
                "comptés à part — ils relèvent des contrats d'appel.\n")
        for n, s in enumerate(sections, 1):
            f.write(f"\n## Trace {n} — trames {s['trame_de']:.2f} à {s['trame_à']:.2f}\n\n")
            f.write("### Accès aux sites suivis\n\n")
            if s["écritures"]:
                if s["retenues"]:
                    f.write("**Valeurs retenues en bloc** : une séquence lue dans la ROM du BIOS "
                            "est signalée sur cette trace, et §8 retire alors les valeurs "
                            "(`DECISIONS.md`).\n\n")
                f.write("| Trame | Site | Valeur | La main | Répétitions |\n|---|---|---|---|---|\n")
                for première, site, valeur, main, dernière, compte in s["écritures"]:
                    rép = ("1" if compte == 1
                           else f"× {compte}, jusqu'à la trame {dernière / T:.2f}")
                    f.write(f"| {première / T:.2f} | `${site:06X}` | {valeur} | {main} | {rép} |\n")
            else:
                f.write("Aucune sur cette trace.\n")
            f.write("\n### Remises de main (BIOS → cartouche)\n\n")
            if s["remises"]:
                f.write("| Trame | Vers | Contexte |\n|---|---|---|\n")
                for période, cible, contexte in s["remises"]:
                    f.write(f"| {période / T:.2f} | `${cible:06X}` | {contexte} |\n")
            else:
                f.write("Aucune sur cette trace.\n")
            if s["retours"]:
                f.write("\nRetours d'appel vérifiés, non listés — ils relèvent des contrats "
                        "d'appel : "
                        + ", ".join(f"{compte} vers `${cible:06X}`"
                                    for cible, compte in s["retours"]) + ".\n")
        f.write("\n## Ce que ce document ne dit pas\n\n")
        f.write("- **Ni les adresses internes de la ROM du BIOS, ni la suite de ses fetchs** "
                "(`DECISIONS.md` §8) : les cibles listées sont hors de sa ROM par construction, "
                "et le contexte d'une remise ne nomme que les crans de la table publique.\n")
        f.write("- **Pas la cause d'une remise** : la trace montre où le PC va, pas pourquoi. "
                "Relier une écriture de site à la remise qui la suit est une lecture, pas une "
                "donnée.\n")
        f.write("- **Pas les registres du 68000** : une valeur passée par registre ne laisse pas "
                "de trace sur le bus.\n")
    return chemin


def part_prom(accès, de=None, à=None):
    """The share of program-space accesses that fall in the cartridge's P-ROM.

    Judge of condition 3 of C0 (`docs/tasks.md`): after the `SWPROM` switch, the program must
    execute from the cartridge and not from the BIOS ROM. Under the SNK BIOS the share goes from
    0.0 % before the switch to 96.9 % after
    (`measured/2026-10-11-espaces-adressage-puzzledp.tsv`).

THE FIRST 128 BYTES FOLLOW `biosMode`, and that is the whole point of the count. The co-simulator
    (unpublished) serves `a < 0x80` from the **BIOS** as long as `biosMode` holds, and from the
    **cartridge** after — it clears it on `SWPROM`. Always excluding them would undercount the
    cartridge after the switch; never excluding them would pass the reads of the reset vector off as
    cartridge at boot. The judge therefore follows the state in the trace: `$3A0003` sets it,
    `$3A0013` clears it, and the initial state is set as at power-on.

    THE `$2xxxxx` BANK IS NOT COUNTED: the co-simulator serves it from the same P-ROM buffer,
    so cartridge code executes there too, but the C0 criterion is about `$00xxxx` and
    counting it would change the quantity without saying so.

    `de` and `à` bound the window in frames; without them, it is that of the trace."""
    T = 811008
    bios_bas = True          # at power-on, the BIOS is at the bottom of the map
    dans = total = 0
    for période, adresse, sens, ul, _, espace in accès:
        if sens == "WR" and 0x3A0000 <= adresse <= 0x3AFFFF:
            octet = adresse + (1 if ul == ".L" else 0)
            if (octet & 0x1F) == 0x03:   bios_bas = True    # SWPBIOS
            elif (octet & 0x1F) == 0x13: bios_bas = False   # SWPROM
            continue
        if espace != "sp":
            continue
        trame = période / T
        if (de is not None and trame < de) or (à is not None and trame > à):
            continue
        total += 1
        if adresse > 0x0FFFFF:
            continue
        if adresse < 0x80 and bios_bas:
            continue         # served by the BIOS, not by the cartridge
        dans += 1
    if not total:
        return None
    return dans, total, 100.0 * dans / total


def main(argv):
    boot = "--boot" in argv
    part = "--part-prom" in argv
    proto = next((o[len("--protocole="):] for o in argv if o.startswith("--protocole=")), None)
    bornes = [None, None]
    for o in argv:
        for i, pré in enumerate(("--de=", "--a=")):
            if o.startswith(pré):
                try:
                    bornes[i] = float(o[len(pré):])
                except ValueError:
                    print(f"borne non numérique : {o}", file=sys.stderr)
                    return 2
    argv = [a for a in argv
            if a not in ("--boot", "--part-prom")
            and not a.startswith("--de=") and not a.startswith("--a=")
            and not a.startswith("--protocole=")]
    if part:
        if len(argv) < 2:
            print("usage: ./bench/generer-contrats.py <trace.txt> --part-prom "
                  "[--de=<trame>] [--a=<trame>]", file=sys.stderr)
            return 2
        accès = lire_trace(argv[1])
        r = part_prom(accès, de=bornes[0], à=bornes[1])
        if not accès or r is None:
            bornes_dites = (f"la fenêtre [{bornes[0]}, {bornes[1]}]"
                            if bornes != [None, None] else "cette trace")
            print(f"aucun accès en espace programme dans {bornes_dites}", file=sys.stderr)
            return 2
        dans, total, pct = r
        f0 = bornes[0] if bornes[0] is not None else accès[0][0] / 811008
        f1 = bornes[1] if bornes[1] is not None else accès[-1][0] / 811008
        print(f"trames {f0:.2f} à {f1:.2f} : {dans} / {total} accès en espace programme servis "
              f"par la cartouche = {pct:.1f} %")
        return 0
    if len(argv) < 3:
        print(__doc__.split("\n\n")[1].strip(), file=sys.stderr)
        return 2
    if boot and len(argv) != 3:
        print("--boot prend une seule trace : celle du démarrage.", file=sys.stderr)
        return 2
    # Refuse rather than create: a directory made from a mistyped argument scatters the
    # contracts without anyone noticing.
    if not os.path.isdir(argv[-1]):
        print(f"dossier de sortie introuvable : {argv[-1]}", file=sys.stderr)
        return 2
    if proto is not None:
        try:
            sites = sorted({int(s, 16) for s in proto.split(",") if s})
        except ValueError:
            print(f"site non hexadécimal dans --protocole={proto}", file=sys.stderr)
            return 2
        if not sites:
            print("--protocole= demande au moins un site, en hexadécimal.", file=sys.stderr)
            return 2
        sections = []
        for chemin in argv[1:-1]:
            a = lire_trace(chemin)
            if not a:
                print(f"aucun accès lisible dans {chemin} — la trace porte-t-elle le champ "
                      f"d'espace d'adressage ?", file=sys.stderr)
                return 2
            sections.append(protocole_trace(a, set(sites)))
        print(écrire_protocole(sections, sites, argv[-1]))
        return 0
    # SEVERAL TRACES MAKE ONE CONTRACT, and it is a matter of correctness before being one of
    # convenience: a write stable over the calls of a single window may be stable only in
    # its regime — measured on `$C0044A`, whose window with the BIOS waiting and the one with the
    # game running do not give the same core. Each trace is SPLIT SEPARATELY: concatenating before
    # splitting would fabricate, at the junction of two files, a false program-space
    # transition, hence a phantom call.
    accès, appels, dedans = [], [], []
    for chemin in argv[1:-1]:
        a = lire_trace(chemin)
        if not a:
            print(f"aucun accès lisible dans {chemin} — la trace porte-t-elle le champ d'espace "
                  f"d'adressage ? (six champs par ligne, voir le README du banc)", file=sys.stderr)
            return 2
        if boot:
            print(contrat_boot(a, argv[-1]))
            return 0
        décalage = len(accès)
        for ap in découper(a):
            appels.append({**ap, "de": ap["de"] + décalage, "à": ap["à"] + décalage})
        accès.extend(a)
        dedans.extend(la_main_au_bios(a))
    if not appels:
        print("aucun appel délimité : la trace ne contient aucune transition d'espace programme "
              "entre la ROM du BIOS et le reste de la carte", file=sys.stderr)
        return 2
    écartés = 0
    for entrée in sorted({a["entrée"] for a in appels}):
        # Outside the public table, the address is internal: no title, no file name.
        if not point_entrée_public(entrée):
            print(f"point d'entrée hors de la table de sauts publique : aucun contrat écrit. "
                  f"C'est probablement un retour depuis une routine du jeu appelée par le BIOS, "
                  f"et l'adresse est interne — `DECISIONS.md` §8 la garde hors du contrat. "
                  f"La trace la porte, pour qui doit trancher.", file=sys.stderr)
            écartés += 1
            continue
        c = contrat(accès, appels, entrée, dedans)
        if c is None:
            print(f"point d'entrée ${entrée:06X} : aucun appel fermé dans la trace, pas de "
                  f"contrat écrit. Sa surface serait tronquée.", file=sys.stderr)
            écartés += 1
            continue
        print(écrire(c, argv[-1]))
    if écartés:
        print(f"{écartés} point(s) d'entrée écarté(s) : voir ci-dessus.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
