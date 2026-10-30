#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Thibaut Lion
"""The cheat search under MAME (`src/c0/cheats.s`): RAM records filtered, then forcings.

    python3 -I -B bench/cheats-recherche.py releve [--jeux "<romsets>"] [--garder] [--jobs n] <roms> <travail>
    python3 -I -B bench/cheats-recherche.py action [--scenario s] [--jeux "<romsets>"] [--fin n] [--garder] <roms> <travail>
    python3 -I -B bench/cheats-recherche.py forcer <forcages.tsv> [--depuis n] [--fin n] [--images l] [--suivre l] <roms> <travail>
    python3 -I -B bench/cheats-recherche.py bisecter <candidats.tsv> --categorie c [--scenario s] [--depuis n] [--fin n]
        [--max n] [--jeux "<romsets>"] <roms> <travail>

BISECTER. The candidates of one category forced all together, then the group that holds cut in two.
The defaults (actif scenario, --depuis 3600) are those of fighting games; in action, --depuis 700.
Forcing several cells sometimes breaks the game and masks the right one (on 2026-10-29): `forcer`,
one by one, is safer.

ACTION. One run per game in one scenario (action, saut, immobile; saut2 and action2 for P2 alone,
see SCENARIOS), then the expected-sequence filter (`filtre_suite`): lives, bombs, time, in
<travail>/candidats-action.tsv.

RELEVE. Each game plays two scenarios under `bench/cheats.lua` (releve mode, RAM $100000-$10F2FF
every PAS frames), our image as sp-s2.sp1:
  passif  coin at 400, START at 500, A every 60 frames from 600 to 3500 (the selection), right held
          from 2000 on: P1 walks forward without hitting, takes blows, loses its rounds;
  actif   the same, then from 3600 on A, B and C hammered while walking forward: P2 takes some too.
The record is filtered as soon as the run ends, then deleted (`candidats.tsv` remains). The filters:
  temps   a byte that loses 1 (binary or BCD) at intervals of 20 to 200 frames, 6 times in a row
          at least (a rise, a new round, resets the sequence to zero);
  vie     a byte that only goes down in steps, only goes back up to its maximum (a new round, in
          stages or at once), 3 drops at least, 4 distinct values, and goes below half
          of that maximum; ranked by KO, then by distinct values; recorded in both
          scenarios: P1's life if it drops in passif, P2's life if it drops only in actif;
  jauge   in actif, a byte that goes up in steps (5 rises at least, 4 distinct values), only
          rarely comes back down (a gauge emptied by a super), and does not move in passif — or
          less: P1 does not hit there.
The filters read only the records; they rank, they prove nothing.

FORCER. For each line of <forcages.tsv>, written by hand or taken from the candidates (game, category,
hex address, size, hex value, scenario), a `forcer` run (the cell written by lua every frame from
--depuis, 3600) and the witness of the same scenario, up to --fin (12,000); in the log, the changes of
BIOS_USER_MODE ($10FDAF) give the game over, and the images (--images, 4600, 5600, 6600 by default)
serve the sheets and the HUD judge (`hud`).

Clean room: no third-party cheat database. MAME's debugger (watchpoints, `bench/cheats.lua`
watch mode) may tell WHO writes a cell; no game code is copied.
"""
import argparse, collections, concurrent.futures as cf, hashlib, os, shutil, subprocess, sys
import numpy as np

ICI = os.path.dirname(os.path.abspath(__file__))
PAQUET = os.path.dirname(ICI)
PAS = 10
FIN = 9000
TAILLE = 0xF300
SCENARIOS = {
    "passif": "400-407:piece,500-507:START,600-3500%60:A,2000-40000:droite",
    "actif": "400-407:piece,500-507:START,600-3500%60:A,2000-40000:droite,"
             "3600-40000%8:A,3602-40000%12:B,3604-40000%16:C",
    # P1 hits a little: it still loses its rounds, but a forced life makes it win on time.
    "faible": "400-407:piece,500-507:START,600-3500%60:A,2000-40000:droite,3600-40000%90:A",
    # Action games: P1 shoots nonstop, walks forward, jumps now and then and drops a bomb;
    # it dies, and loses its lives one by one.
    "action": "400-407:piece,500-507:START,600-40000%6:A,1000-40000:droite,"
              "1500-40000%300:B,1650-40000%400:C",
    # Die fast, without shooting (the user's idea, on 2026-10-29): walk forward jumping into
    # the enemies (B, the jump of most action games), or stay in place.
    "saut": "400-407:piece,500-507:START,1000-40000:droite,1000-40000%20:B",
    "immobile": "400-407:piece,500-507:START",
    # P2 alone (on 2026-10-29): its coin, its START, and it walks forward jumping; P1 does not play.
    # Its lives, its bombs and its game over then read like P1's.
    "saut2": "400-407:pieceDeux,500-507:startDeux,1000-40000:droiteDeux,1000-40000%20:bDeux",
    "action2": "400-407:pieceDeux,500-507:startDeux,600-40000%6:aDeux,1000-40000:droiteDeux,"
               "1500-40000%300:bDeux,1650-40000%400:cDeux",
}
COMBAT_SC = ("passif", "actif")
COMBAT = ("aof aof2 aof3 breakers breakrev doubledr fatfursp fatfury1 fatfury2 fatfury3 fightfev "
          "galaxyfg garou gowcaizr kabukikl karnovr kizuna kof94 kof95 kof96 kof97 kof98 kof99 "
          "kof2000 kof2001 kof2002 kof2003 kotm kotm2 lastblad lastbld2 matrim ninjamas ragnagrd "
          "rbff1 rbff2 rbffspec rotd samsho samsho2 samsho3 samsho4 samsho5 samsh5sp savagere svc "
          "wakuwak7 wh1 wh2 wh2j whp").split()


def image(travail):
    """Our image, built from src/c0 in the work directory."""
    sortie = os.path.join(travail, "bios.sp1")
    env = dict(os.environ, BIOS_OBJ=os.path.join(travail, "obj"))
    subprocess.run([os.path.join(PAQUET, "build/construire.sh"), os.path.join(PAQUET, "src/c0"), sortie],
                   env=env, check=True, stdout=subprocess.DEVNULL)
    return sortie


def romset(roms, travail, jeu, img):
    """The game's set, sp-s2.sp1 replaced by our image (as `cheats-catalogue.sh`)."""
    r = os.path.join(travail, "roms")
    os.makedirs(os.path.join(r, "img"), exist_ok=True)
    d = os.path.join(r, jeu + ".zip")
    if os.path.islink(d):
        sys.exit(f"REFUS : {d} est un lien symbolique")
    if not os.path.exists(d):
        shutil.copy(img, os.path.join(r, "img", "sp-s2.sp1"))
        shutil.copy(os.path.join(roms, jeu + ".zip"), d + ".part")
        subprocess.run(["zip", "-q", "-j", "-X", d + ".part", os.path.join(r, "img", "sp-s2.sp1")], check=True)
        os.rename(d + ".part", d)
    return r


def mame(jeu, rompath, sortie, env):
    """A windowless MAME run, under `cheats.lua`, cfg and NVRAM apart."""
    shutil.rmtree(sortie, ignore_errors=True)
    os.makedirs(sortie)
    e = dict(os.environ, C_OUT=sortie, SDL_VIDEODRIVER="dummy", SDL_MAC_BACKGROUND_APP="1", **env)
    with open(os.path.join(sortie, "mame.log"), "w") as log:
        rc = subprocess.run(["mame", jeu, "-rompath", rompath, "-bios", "euro", "-video", "none", "-sound", "none",
                             "-nothrottle", "-seconds_to_run", "900", "-nvram_directory", os.path.join(sortie, "nvram"),
                             "-cfg_directory", os.path.join(sortie, "cfg"), "-skip_gameinfo",
                             "-autoboot_script", os.path.join(ICI, "cheats.lua")],
                            cwd=sortie, env=e, stdout=log, stderr=subprocess.STDOUT).returncode
    return rc


def effacer(sortie):
    """The RAM record of a run (~55 MB) removed, present or not."""
    for x in ("ram.bin", "ram.idx"):
        try:
            os.remove(os.path.join(sortie, x))
        except FileNotFoundError:
            pass


def journal(sortie):
    """NGH, fingerprint, and the frames where BIOS_USER_MODE changes, read in the jig's log."""
    ngh = emp = None
    user = []
    for l in open(os.path.join(sortie, "cheats.txt")):
        if " ngh=" in l:
            ngh, emp = l.split("ngh=")[1].split()[0], l.split("empreinte=")[1].split()[0]
        if " user=" in l:
            user.append((int(l[1:].split()[0]), l.split("user=")[1].strip()))
    return ngh, emp, user


def fin_de_partie(user):
    """The frame where BIOS_USER_MODE leaves 2 for the first time after reaching it; "" otherwise."""
    vu = False
    for n, x in user:
        if x == "02":
            vu = True
        elif vu:
            return n
    return ""


def releve(sortie):
    """The records, one line per recorded frame: uint8 [n, TAILLE]."""
    b = np.fromfile(os.path.join(sortie, "ram.bin"), dtype=np.uint8)
    return b[: len(b) // TAILLE * TAILLE].reshape(-1, TAILLE)


def bcd_moins_un(a, b):
    """b = a − 1 in BCD (two valid digits)."""
    ok = ((a & 0x0F) <= 9) & ((a >> 4) <= 9) & ((b & 0x0F) <= 9) & ((b >> 4) <= 9)
    da = (a >> 4).astype(int) * 10 + (a & 0x0F)
    db = (b >> 4).astype(int) * 10 + (b & 0x0F)
    return ok & (db == da - 1)


def filtre_temps(R):
    """The cells of a timer: the longest run of regular "−1" (see the header)."""
    out = []
    v = R.astype(np.int16)
    for a in np.nonzero((np.diff(v, axis=0) != 0).sum(axis=0) >= 6)[0]:
        s = v[:, a]
        ch = np.nonzero(np.diff(s))[0]
        suite, best, dern = 0, 0, None
        for i in ch:
            x, y = s[i], s[i + 1]
            moins = (y == x - 1) or bool(bcd_moins_un(np.uint8(x), np.uint8(y)))
            if moins and dern is not None and 2 <= i - dern <= 20 and suite > 0:
                suite += 1
            elif moins:
                suite = 1
            else:
                suite = 0
            best = max(best, suite)
            dern = i
        if best >= 6:
            out.append((a, best, int(s.max())))
    return sorted(out, key=lambda x: -x[1])


def profil_vie(s):
    """(drops, rises up to the maximum, interrupted rises, max, min, KO) of a series of bytes.
    A rise can happen in stages (the bar that fills at the start of the round): it counts
    if it reaches the maximum before any drop."""
    d = np.diff(s.astype(np.int16))
    m = int(s.max())
    au_max = interrompues = ko = 0
    monte = False
    bas, debut, baisses = m, 0, 0
    for i, x in enumerate(d):
        # A KO: the round ends at the lowest, after 300 frames at least (30 records) and 2 drops;
        # a flag blinking between a few values does not make one.
        if x > 0 and not monte and bas * 8 <= m and i - debut >= 30 and baisses >= 2:
            ko += 1
        if x > 0:
            monte = True
            if s[i + 1] == m:
                au_max, monte, bas, debut, baisses = au_max + 1, False, m, i, 0
        elif x < 0:
            bas, baisses = min(bas, int(s[i + 1])), baisses + 1
            if monte:
                interrompues, monte = interrompues + 1, False
    return int((d < 0).sum()), au_max, interrompues, m, int(s.min()), ko


def filtre_vie(R):
    """{(address, size, direction): ((KO, distinct values), full value, empty value)}. Life can
    be a byte or a word (big-endian, even address), and count what remains (direction +) or the
    damage taken (direction −, the series inverted: it goes up at each blow and back to 0 at the
    next round). 4 values at least: a blinking flag has only 2. Ranked by KO first: the
    life of a player who loses their rounds falls to 0 before each rise, the timer and
    most copies do not."""
    out = {}
    w = (R[:, 0::2].astype(np.int32) << 8) | R[:, 1::2]
    for taille, X, plein in ((1, R.astype(np.int32), 0xFF), (2, w, 0xFFFF)):
        for sens, Y in (("+", X), ("-", plein - X)):
            for a in np.nonzero((np.diff(Y, axis=0) < 0).sum(axis=0) >= 3)[0]:
                b, am, autres, m, mn, ko = profil_vie(Y[:, a])
                nv = len(np.unique(Y[:, a]))
                if not (am >= 1 and autres == 0 and b <= 400 and nv >= 4 and m - mn >= 8):
                    continue
                if sens == "+" and not (m >= 8 and mn * 2 < m):
                    continue
                if taille == 2 and int(X[:, a].max()) < 0x100:
                    continue                # a byte, already seen at the odd address
                pleine, vide = (m, mn) if sens == "+" else (plein - m, plein - mn)
                out[(a * taille, taille, sens)] = ((ko, nv), pleine, vide)
    return out


def filtre_jauge(R, Rp):
    """(address, rises, max): in actif, a byte that goes up in steps and does not move, or less, in
    passif (see the header)."""
    out = []
    d = np.diff(R.astype(np.int16), axis=0)
    for a in np.nonzero((d > 0).sum(axis=0) >= 5)[0]:
        s = R[:, a]
        dd = d[:, a]
        hausses, baisses = int((dd > 0).sum()), int((dd < 0).sum())
        if baisses * 3 > hausses or len(np.unique(s)) < 4 or hausses > 300:
            continue
        hp = int((np.diff(Rp[:, a].astype(np.int16)) > 0).sum()) if Rp is not None else 0
        if hp * 2 >= hausses:
            continue
        out.append((a, hausses, int(s.max())))
    return sorted(out, key=lambda x: -x[1])


def cmd_releve(a):
    travail = os.path.abspath(a.travail)
    os.makedirs(travail, exist_ok=True)
    img = image(travail)
    jeux = a.jeux.split() if a.jeux else COMBAT
    rp = None
    for j in jeux:
        rp = romset(os.path.abspath(a.roms), travail, j, img)
    print(f"image {hashlib.sha256(open(img, 'rb').read()).hexdigest()[:16]}…, {len(jeux)} jeux, {a.jobs} jobs")

    def run(job):
        jeu, sc = job
        o = os.path.join(travail, "runs", f"{jeu}-{sc}")
        rc = mame(jeu, rp, o, {"C_MODE": "releve", "C_ENTREES": SCENARIOS[sc], "C_FIN": str(FIN), "C_PAS": str(PAS)})
        return jeu, sc, rc

    with cf.ThreadPoolExecutor(a.jobs) as ex:
        for jeu, sc, rc in ex.map(run, [(j, s) for j in jeux for s in COMBAT_SC]):
            print(f"{jeu}-{sc} rc={rc}", flush=True)

    lignes = ["jeu\tngh\tempreinte\tcategorie\tadresse\tscore\tmax\tfin_passif\tfin_actif"]
    for jeu in jeux:
        o = {s: os.path.join(travail, "runs", f"{jeu}-{s}") for s in COMBAT_SC}
        try:
            filtrer_combat(jeu, o, lignes)
        finally:
            if not a.garder:
                for s in COMBAT_SC:
                    effacer(o[s])
    open(os.path.join(travail, "candidats.tsv"), "w").write("\n".join(lignes) + "\n")
    print(f"{len(lignes) - 1} candidats : {os.path.join(travail, 'candidats.tsv')}")


def filtrer_combat(jeu, o, lignes):
    """The candidates of a fighting game (see the header), appended to `lignes`."""
    try:
        Rp, Ra = releve(o["passif"]), releve(o["actif"])
        ngh, emp, up = journal(o["passif"])
        _, _, ua = journal(o["actif"])
    except (FileNotFoundError, ValueError):
        print(f"{jeu} : relevé absent")
        return
    base = f"{jeu}\t{ngh}\t{emp}"
    f = f"\t{fin_de_partie(up)}\t{fin_de_partie(ua)}"
    for adr, sc, m in filtre_temps(Rp)[:6]:
        lignes.append(f"{base}\ttemps\t{0x100000 + adr:06X}\t{sc}\t{m:02X}{f}")
    vp, va = filtre_vie(Rp), filtre_vie(Ra)
    rang = lambda d: sorted(d.items(), key=lambda x: (-x[1][0][0], -x[1][0][1]))
    for (adr, t, sens), ((ko, nv), pleine, vide) in rang(vp)[:10]:
        lignes.append(f"{base}\tvie_p1\t{0x100000 + adr:06X}\t{ko}/{nv}\t{t}:{pleine:X}:{vide:X}:{sens}{f}")
    constant = lambda adr, t: len(np.unique(Rp[:, adr])) <= 2 and (t == 1 or len(np.unique(Rp[:, adr + 1])) <= 2)
    p2 = {k: v for k, v in va.items() if k not in vp and constant(k[0], k[1])}
    for (adr, t, sens), ((ko, nv), pleine, vide) in rang(p2)[:8]:
        lignes.append(f"{base}\tvie_p2\t{0x100000 + adr:06X}\t{ko}/{nv}\t{t}:{pleine:X}:{vide:X}:{sens}{f}")
    for adr, h, m in filtre_jauge(Ra, Rp)[:8]:
        lignes.append(f"{base}\tjauge\t{0x100000 + adr:06X}\t{h}\t{m:02X}{f}")


def cmd_forcer(a):
    travail = os.path.abspath(a.travail)
    img = image(travail)
    jobs, temoins = [], set()
    for l in open(a.candidats):
        c = l.rstrip("\n").split("\t")
        if len(c) < 6 or c[0] == "jeu" or c[0].startswith("#"):
            continue
        jeu, cat, adr, taille, val, sc = c[:6]
        jobs.append((jeu, sc, f"{cat}-{adr}", f"{adr}:{taille}:{val}"))
        temoins.add((jeu, sc))
    rp = None
    for jeu in {j[0] for j in jobs}:
        rp = romset(os.path.abspath(a.roms), travail, jeu, img)
    jobs += [(jeu, sc, "temoin", "") for jeu, sc in sorted(temoins)]
    images = a.images

    def run(job):
        jeu, sc, nom, f = job
        o = os.path.join(travail, "forcer", f"{jeu}-{sc}-{nom}")
        env = {"C_MODE": "forcer" if f else "releve", "C_ENTREES": SCENARIOS[sc], "C_FIN": str(a.fin),
               "C_PAS": "50", "C_DEPUIS": str(a.depuis), "C_FORCER": f, "C_IMAGES": images,
               "C_SUIVRE": a.suivre.get(jeu, "")}
        rc = mame(jeu, rp, o, env)
        effacer(o)
        # Frozen: three identical images (a forcing that blocks the game does not lose the play
        # session either, but it proves nothing). Fewer than three images, no conclusion: a single
        # one is always "identical" to itself (on 2026-10-29, a pass with one image declared
        # everything frozen).
        imgs = [os.path.join(o, f"f{int(x):05d}.bin") for x in images.split(",")[:3]]
        imgs = [x for x in imgs if os.path.exists(x)]
        h = {hashlib.sha256(open(x, "rb").read()).hexdigest() for x in imgs}
        try:
            u = journal(o)[2]
        except FileNotFoundError:          # MAME did not start the jig
            u = []
        return jeu, sc, nom, rc, u, "fige" if len(imgs) >= 3 and len(h) == 1 else ""

    jobs.sort(key=lambda j: j[0])
    with cf.ThreadPoolExecutor(a.jobs) as ex:
        res = list(ex.map(run, jobs))
    lignes = ["jeu\tscenario\trun\trc\tfin_de_partie\tfige\tbios_user_mode"]
    for jeu, sc, nom, rc, u, fige in res:
        lignes.append(f"{jeu}\t{sc}\t{nom}\t{rc}\t{fin_de_partie(u)}\t{fige}\t{' '.join(f'{n}:{x}' for n, x in u)}")
    open(os.path.join(travail, "forcer.tsv"), "w").write("\n".join(lignes) + "\n")
    print("\n".join(lignes))


ACTION = ("alpham2 b2b bjourney blazstar burningf crswd2bl crsword ctomaday cyberlip eightman ganryu "
          "gpilots ironclad legendos lresort maglord mslug mslug2 mslug3 mslug4 mslug5 mslugx mutnat "
          "nam1975 ncombat ncommand neobombe neomrdo nitd preisle2 pulstar roboarmy s1945p sengoku "
          "sengoku2 sengoku3 shocktr2 shocktro sonicwi2 sonicwi3 spinmast superspy tophuntr twinspri "
          "viewpoin zedblade zupapa").split()


def filtre_suite(R, departs, remise, min_baisses, max_baisses=60, ecart=(1, 40), fin_k=None):
    """The bytes that follow EXACTLY the expected sequence of a counter: v0, v0 − 1, v0 − 2…
    (the user's idea, on 2026-10-29: look for the 3s at the start, keep those that go to 2
    after the death, then to 1…). The sequence is read on the successive distinct values of the
    byte, from its first value v0 on, and, without reset, down to 0: what follows belongs to the
    demo or to the next play session. Each step must be − 1, or, with reset, 0 → $FF or
    if `remise`, a return to v0 (a life, a round, a reloaded bomb). Each start of `departs`
    is tried in binary and in BCD. `ecart`: the median gap between two drops, in records (an
    animation counter changes at every record). `fin_k`: the record of the game over; an
    out-of-sequence step beyond it closes the sequence instead of discarding it. Returns (address,
    encoded start, drops, records of the drops), the longest sequences first."""
    out = {}
    for v0 in departs:
        for f in ((lambda v: v,) if v0 < 10 else (lambda v: v, lambda v: (v // 10) * 16 + v % 10)):
            for a in np.nonzero((R == f(v0)).any(axis=0))[0]:
                s = R[:, a]
                k = int(np.argmax(s == f(v0)))
                if k > len(s) // 2:
                    continue
                e, baisses, quand, ok = v0, 0, [], True
                prec = int(s[k])
                for t in range(k + 1, len(s)):
                    x = int(s[t])
                    if x == prec:
                        continue
                    if e >= 1 and x == f(e - 1) or e == 0 and x == 0xFF:
                        e, baisses = e - 1, baisses + 1
                        quand.append(t)
                        if e <= 0 and not remise:
                            break               # the last life: the sequence stops, the demo resets the counter
                    elif remise and x == f(v0):
                        e = v0
                    else:
                        ok = fin_k is not None and t > fin_k
                        break
                    prec = x
                if not ok or not min_baisses <= baisses <= max_baisses:
                    continue
                if ecart and len(quand) >= 2 and not ecart[0] <= np.median(np.diff(quand)) <= ecart[1]:
                    continue
                if a not in out or out[a][1] < baisses:
                    out[a] = (f(v0), baisses, tuple(quand))
    return sorted(((a, v, b, q) for a, (v, b, q) in out.items()), key=lambda x: -x[2])


def cmd_action(a):
    """The record of action games: one run per game (--scenario, action by default), filtered then
    deleted."""
    travail = os.path.abspath(a.travail)
    os.makedirs(travail, exist_ok=True)
    img = image(travail)
    jeux = a.jeux.split() if a.jeux else ACTION
    rp = None
    for j in jeux:
        rp = romset(os.path.abspath(a.roms), travail, j, img)

    def run(jeu):
        o = os.path.join(travail, "runs", f"{jeu}-{a.scenario}")
        mame(jeu, rp, o, {"C_MODE": "releve", "C_ENTREES": SCENARIOS[a.scenario], "C_FIN": str(a.fin), "C_PAS": str(PAS)})
        try:
            ngh, emp, u = journal(o)
        except FileNotFoundError:          # MAME did not start the jig: the game is dropped, not the sweep
            return jeu, []
        fin = fin_de_partie(u)
        lignes = []
        try:
            R = releve(o)
            idx = [int(x) for x in open(os.path.join(o, "ram.idx"))][: len(R)]
        except (FileNotFoundError, ValueError):
            effacer(o)
            return jeu, [f"{jeu}\t{ngh}\t{emp}\t-\t-\t-\t-\t{fin}"]
        base = f"{jeu}\t{ngh}\t{emp}"
        # The play-session window: from 700 (the lives set after START) to 1,000 frames after the
        # game over, where the demo and the next play session reset the counters (records of
        # 2026-10-29).
        garde = [k for k, n in enumerate(idx) if n >= 700 and (not fin or n <= fin + 1000)]
        R, idx = R[garde], [idx[k] for k in garde]
        # The expected sequences: lives from 1 to 5 at the start, without reset; bombs from 2 to 10,
        # reloaded; time at 30, 50, 59 (minutes:seconds), 60, 90 or 99, reset at each life or stage.
        fk = next((k for k, n in enumerate(idx) if fin and n >= fin), None)
        vies = filtre_suite(R, range(1, 6), False, 2, 12, None, fk)
        # The lives: those that drop when P1 dies. The copies of one cell drop at the
        # same records; the last life is lost shortly before the game over. Ranked by the gap
        # between the last drop and the game over, then by the size of the group of simultaneous
        # drops (the cell and its display copies).
        groupe = collections.Counter(tuple(t // 3 for t in q) for _, _, _, q in vies)
        vies.sort(key=lambda c: (abs(c[3][-1] - fk) if fk is not None else 0, -groupe[tuple(t // 3 for t in c[3])]))
        cats = (("vies", vies),
                ("bombes", filtre_suite(R, range(2, 11), True, 2, 40, (1, 40), fk)),
                ("temps", filtre_suite(R, (30, 50, 59, 60, 90, 99), True, 6, 400, (2, 30), fk)))
        for cat, cands in cats:
            for adr, v, b, _ in cands[:8]:
                lignes.append(f"{base}\t{cat}\t{0x100000 + adr:06X}\t{b}\t1:{v:X}:0:+\t{fin}")
        if not a.garder:
            effacer(o)
        return jeu, lignes

    out = ["jeu\tngh\tempreinte\tcategorie\tadresse\tscore\tvaleurs\tfin"]
    with cf.ThreadPoolExecutor(a.jobs) as ex:
        for jeu, lignes in ex.map(run, jeux):
            print(f"{jeu} : {len(lignes)} candidats", flush=True)
            out += lignes
    open(os.path.join(travail, "candidats-action.tsv"), "w").write("\n".join(out) + "\n")


def cmd_bisecter(a):
    """The candidates of one category forced all together, then the group that holds cut in two,
    down to one cell. Holds: the witness loses the play session, the forced run does not, and its
    images move."""
    travail = os.path.abspath(a.travail)
    img = image(travail)
    cand = {}
    for l in open(a.candidats):
        c = l.rstrip("\n").split("\t")
        if len(c) < 7 or c[3] != a.categorie or (a.jeux and c[0] not in a.jeux.split()):
            continue
        t, pleine, vide, _ = c[6].split(":")
        v = vide if a.categorie == "vie_p2" else pleine
        x = f"{c[4]}:{t}:{v}"
        if x not in cand.setdefault(c[0], []) and len(cand[c[0]]) < a.max:
            cand[c[0]].append(x)
    rp = None
    for jeu in cand:
        rp = romset(os.path.abspath(a.roms), travail, jeu, img)
    sc = a.scenario

    def run(job):
        jeu, nom, f = job
        o = os.path.join(travail, "bisecter", f"{jeu}-{sc}-{nom}")
        env = {"C_MODE": "forcer" if f else "releve", "C_ENTREES": SCENARIOS[sc], "C_FIN": str(a.fin),
               "C_PAS": "50", "C_DEPUIS": str(a.depuis), "C_FORCER": f, "C_IMAGES": "4600,5600,6600"}
        mame(jeu, rp, o, env)
        effacer(o)
        imgs = [os.path.join(o, f"f{x}.bin") for x in ("04600", "05600", "06600")]
        imgs = [x for x in imgs if os.path.exists(x)]
        h = {hashlib.sha256(open(x, "rb").read()).hexdigest() for x in imgs}
        try:
            u = journal(o)[2]
        except FileNotFoundError:
            u = []
        return jeu, nom, fin_de_partie(u), len(imgs) == 3 and len(h) == 1

    with cf.ThreadPoolExecutor(a.jobs) as ex:
        temoin = {j: fin for j, _, fin, _ in ex.map(run, [(j, "temoin", "") for j in cand])}
        groupes = {j: [cand[j]] for j in cand if temoin[j] != ""}
        trouves = {j: [] for j in cand}
        tour = 0
        while any(groupes.values()):
            tour += 1
            jobs = [(j, f"t{tour}-{k}", ",".join(g)) for j in groupes for k, g in enumerate(groupes[j])]
            suite = {j: [] for j in groupes}
            for jeu, nom, fin, fige in ex.map(run, jobs):
                g = groupes[jeu][int(nom.split("-")[1])]
                tient = fin == "" and not fige
                print(f"{jeu} tour {tour} : {len(g)} cellule(s) {'tient' if tient else 'non'} "
                      f"(fin {fin or 'aucune'}{', figé' if fige else ''})", flush=True)
                if tient and len(g) == 1:
                    trouves[jeu].append(g[0])
                elif tient:
                    suite[jeu] += [g[: len(g) // 2], g[len(g) // 2:]]
            groupes = suite
    lignes = ["jeu\tcategorie\tscenario\ttemoin_fin\ttrouves"]
    for j in sorted(cand):
        lignes.append(f"{j}\t{a.categorie}\t{sc}\t{temoin[j]}\t{' '.join(trouves[j])}")
    sortie = os.path.join(travail, f"bisecter-{a.categorie}-{sc}.tsv")
    open(sortie, "w").write("\n".join(lignes) + "\n")
    print("\n".join(lignes))


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sp = p.add_subparsers(dest="cmd", required=True)
    r = sp.add_parser("releve")
    r.add_argument("--jeux", default="")
    r.add_argument("--garder", action="store_true", help="garder les relevés (ram.bin), pour regarder une série")
    f = sp.add_parser("forcer")
    f.add_argument("candidats", metavar="forcages.tsv")
    f.add_argument("--fin", type=int, default=12000)
    f.add_argument("--images", default="4600,5600,6600", help="trames des images, virgules")
    f.add_argument("--suivre", default="", type=lambda x: dict(y.split("=") for y in x.split() if y),
                   help="« jeu=adr:taille » séparés d'espaces : la cellule relevée au journal toutes les 50 trames")
    f.add_argument("--depuis", type=int, default=3600,
                   help="trame du premier forçage : 3600 après la sélection d'un jeu de combat, 700 en action")
    ac = sp.add_parser("action")
    ac.add_argument("--jeux", default="")
    ac.add_argument("--garder", action="store_true")
    ac.add_argument("--scenario", default="action", choices=("action", "saut", "immobile", "saut2", "action2"))
    ac.add_argument("--fin", type=int, default=FIN)
    bi = sp.add_parser("bisecter")
    bi.add_argument("candidats")
    bi.add_argument("--categorie", required=True, choices=("vie_p1", "vie_p2", "vies"))
    bi.add_argument("--scenario", default="actif", choices=tuple(SCENARIOS))
    bi.add_argument("--jeux", default="")
    bi.add_argument("--max", type=int, default=24, help="candidats par jeu, au plus")
    bi.add_argument("--fin", type=int, default=15000)
    bi.add_argument("--depuis", type=int, default=3600, help="trame du premier forçage (700 en action)")
    for x in (r, f, bi, ac):
        x.add_argument("--jobs", type=int, default=12)
        x.add_argument("roms")
        x.add_argument("travail")
    a = p.parse_args()
    {"releve": cmd_releve, "forcer": cmd_forcer, "bisecter": cmd_bisecter, "action": cmd_action}[a.cmd](a)


if __name__ == "__main__":
    main()
