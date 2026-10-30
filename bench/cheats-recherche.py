#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Thibaut Lion
"""La recherche des cheats sous MAME (`src/c0/cheats.s`) : relevés de RAM filtrés, puis forçages.

    python3 -I -B bench/cheats-recherche.py releve [--jeux "<romsets>"] [--garder] [--jobs n] <roms> <travail>
    python3 -I -B bench/cheats-recherche.py action [--scenario s] [--jeux "<romsets>"] [--fin n] [--garder] <roms> <travail>
    python3 -I -B bench/cheats-recherche.py forcer <forcages.tsv> [--depuis n] [--fin n] [--images l] [--suivre l] <roms> <travail>
    python3 -I -B bench/cheats-recherche.py bisecter <candidats.tsv> --categorie c [--scenario s] [--depuis n] [--fin n]
        [--max n] [--jeux "<romsets>"] <roms> <travail>

BISECTER. Les candidats d'une catégorie forcés tous ensemble, puis le groupe qui tient coupé en deux.
Les défauts (scénario actif, --depuis 3600) sont ceux du combat ; en action, --depuis 700. Forcer à
plusieurs cellules casse parfois le jeu et masque la bonne (le 2026-10-29) : `forcer`, une à une, est
plus sûr.

ACTION. Un run par jeu dans un scénario (action, saut, immobile, bombe ; saut2 et action2 pour P2 seul,
voir SCENARIOS), puis le filtre de suite attendue (`filtre_suite`) : vies, bombes, temps, dans
<travail>/candidats-action.tsv.

RELEVE. Chaque jeu joue deux scénarios sous `bench/cheats.lua` (mode releve, RAM $100000-$10F2FF
toutes les PAS trames), notre image en sp-s2.sp1 :
  passif  pièce à 400, START à 500, A toutes les 60 trames de 600 à 3500 (la sélection), droite tenue
          à partir de 2000 : P1 avance sans frapper, prend des coups, perd ses rounds ;
  actif   le même, puis à partir de 3600 A, B et C martelés en avançant : P2 en prend aussi.
Le relevé est filtré dès la fin du run, puis effacé (`candidats.tsv` reste). Les filtres :
  temps   un octet qui perd 1 (binaire ou BCD) à des intervalles de 20 à 200 trames, 6 fois de suite
          au moins (une hausse, un nouveau round, remet la suite à zéro) ;
  vie     un octet qui ne baisse que par pas, ne remonte qu'à son maximum (un nouveau round, par
          paliers ou d'un coup), 3 baisses au moins, 4 valeurs distinctes, et descend sous la
          moitié de ce maximum ; rangés par KO, puis par valeurs distinctes ; relevé dans les
          deux scénarios : vie de P1 s'il baisse en passif, vie de P2 s'il ne baisse qu'en actif ;
  jauge   en actif, un octet qui monte par pas (5 hausses au moins, 4 valeurs distinctes), ne
          redescend que rarement (une jauge vidée par une super), et ne bouge pas en passif — ou
          moins : P1 n'y frappe pas.
Les filtres ne lisent que les relevés ; ils rangent, ils ne prouvent rien.

FORCER. Pour chaque ligne de <forcages.tsv>, écrit à la main ou tiré des candidats (jeu, catégorie,
adresse hex, taille, valeur hex, scénario), un run `forcer` (la cellule écrite par lua à chaque trame dès --depuis, 3600) et le
témoin du même scénario, jusqu'à --fin (12 000) ; au journal, les changements de BIOS_USER_MODE
($10FDAF) donnent la fin de partie, et les images (--images, 4600, 5600, 6600 par défaut) servent
aux planches et au juge du HUD (`hud`).

Salle blanche : aucune base de cheats tierce. Le débogueur de MAME (watchpoints, `bench/cheats.lua`
mode watch) peut dire QUI écrit une cellule ; aucun code de jeu n'est copié.
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
    # P1 frappe un peu : il perd encore ses rounds, mais une vie forcée lui fait gagner au temps.
    "faible": "400-407:piece,500-507:START,600-3500%60:A,2000-40000:droite,3600-40000%90:A",
    # Les jeux d'action : P1 tire sans cesse, avance, saute de temps en temps et lâche une bombe ;
    # il meurt, et perd ses vies une à une.
    "action": "400-407:piece,500-507:START,600-40000%6:A,1000-40000:droite,"
              "1500-40000%300:B,1650-40000%400:C",
    # Mourir vite, sans tirer (l'idée de l'utilisateur, le 2026-10-29) : avancer en sautant dans
    # les ennemis (B, le saut de la plupart des jeux d'action), ou rester sur place.
    "saut": "400-407:piece,500-507:START,1000-40000:droite,1000-40000%20:B",
    "immobile": "400-407:piece,500-507:START",
    # Les bombes (Metal Slug 2 à 5, le 2026-10-30) : P1 tire, avance et lâche une bombe toutes les
    # 60 trames ; le compteur descend vite, et remonte à 10 à chaque vie.
    "bombe": "400-407:piece,500-507:START,600-40000%6:A,1000-40000:droite,1000-40000%60:C",
    # P2 seul (le 2026-10-29) : sa pièce, son START, et il avance en sautant ; P1 ne joue pas. Ses
    # vies, ses bombes et sa fin de partie se lisent alors comme celles de P1.
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
    """Notre image, construite depuis src/c0 dans le dossier de travail."""
    sortie = os.path.join(travail, "bios.sp1")
    env = dict(os.environ, BIOS_OBJ=os.path.join(travail, "obj"))
    subprocess.run([os.path.join(PAQUET, "build/construire.sh"), os.path.join(PAQUET, "src/c0"), sortie],
                   env=env, check=True, stdout=subprocess.DEVNULL)
    return sortie


def romset(roms, travail, jeu, img):
    """Le set du jeu, sp-s2.sp1 remplacé par notre image (comme `cheats-catalogue.sh`)."""
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
    """Un run MAME sans fenêtre, sous `cheats.lua`, cfg et NVRAM à part."""
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
    """Le relevé de RAM d'un run (~55 Mo) ôté, présent ou non."""
    for x in ("ram.bin", "ram.idx"):
        try:
            os.remove(os.path.join(sortie, x))
        except FileNotFoundError:
            pass


def journal(sortie):
    """NGH, empreinte, et les trames où BIOS_USER_MODE change, lus au journal du jig."""
    ngh = emp = None
    user = []
    for l in open(os.path.join(sortie, "cheats.txt")):
        if " ngh=" in l:
            ngh, emp = l.split("ngh=")[1].split()[0], l.split("empreinte=")[1].split()[0]
        if " user=" in l:
            user.append((int(l[1:].split()[0]), l.split("user=")[1].strip()))
    return ngh, emp, user


def fin_de_partie(user):
    """La trame où BIOS_USER_MODE quitte 2 pour la première fois après y être venu ; « » sinon."""
    vu = False
    for n, x in user:
        if x == "02":
            vu = True
        elif vu:
            return n
    return ""


def releve(sortie):
    """Les relevés, une ligne par trame relevée : uint8 [n, TAILLE]."""
    b = np.fromfile(os.path.join(sortie, "ram.bin"), dtype=np.uint8)
    return b[: len(b) // TAILLE * TAILLE].reshape(-1, TAILLE)


def bcd_moins_un(a, b):
    """b = a − 1 en BCD (deux chiffres valides)."""
    ok = ((a & 0x0F) <= 9) & ((a >> 4) <= 9) & ((b & 0x0F) <= 9) & ((b >> 4) <= 9)
    da = (a >> 4).astype(int) * 10 + (a & 0x0F)
    db = (b >> 4).astype(int) * 10 + (b & 0x0F)
    return ok & (db == da - 1)


def filtre_temps(R):
    """Les cellules d'un chronomètre : la plus longue suite de « −1 » réguliers (voir l'en-tête)."""
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
    """(baisses, remontées jusqu'au maximum, remontées interrompues, max, min, KO) d'une série d'octets.
    Une remontée peut se faire par paliers (la barre qui se remplit au début du round) : elle compte
    si elle atteint le maximum avant toute baisse."""
    d = np.diff(s.astype(np.int16))
    m = int(s.max())
    au_max = interrompues = ko = 0
    monte = False
    bas, debut, baisses = m, 0, 0
    for i, x in enumerate(d):
        # Un KO : le round finit au plus bas, après 300 trames au moins (30 relevés) et 2 baisses ;
        # un drapeau qui clignote entre quelques valeurs n'en fait pas.
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
    """{(adresse, taille, sens): ((KO, valeurs distinctes), valeur pleine, valeur vide)}. La vie peut
    être un octet ou un mot (big-endian, adresse paire), et compter ce qui reste (sens +) ou les
    dégâts subis (sens −, la série inversée : elle monte à chaque coup et revient à 0 au round
    suivant). 4 valeurs au moins : un drapeau qui clignote n'en a que 2. Rangées par KO d'abord : la
    vie d'un joueur qui perd ses rounds tombe à 0 avant chaque remontée, le chronomètre et la
    plupart des copies non."""
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
                    continue                # un octet, déjà vu à l'adresse impaire
                pleine, vide = (m, mn) if sens == "+" else (plein - m, plein - mn)
                out[(a * taille, taille, sens)] = ((ko, nv), pleine, vide)
    return out


def filtre_jauge(R, Rp):
    """(adresse, hausses, max) : en actif, un octet qui monte par pas et ne bouge pas, ou moins, en
    passif (voir l'en-tête)."""
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
    """Les candidats d'un jeu de combat (voir l'en-tête), à la suite de `lignes`."""
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
        # Figé : trois images identiques (un forçage qui bloque le jeu ne perd pas la partie non plus,
        # mais il ne prouve rien). Moins de trois images, on ne conclut pas : une seule est toujours
        # « identique » à elle-même (le 2026-10-29, un passage à une image a tout déclaré figé).
        imgs = [os.path.join(o, f"f{int(x):05d}.bin") for x in images.split(",")[:3]]
        imgs = [x for x in imgs if os.path.exists(x)]
        h = {hashlib.sha256(open(x, "rb").read()).hexdigest() for x in imgs}
        try:
            u = journal(o)[2]
        except FileNotFoundError:          # MAME n'a pas démarré le jig
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
    """Les octets qui suivent EXACTEMENT la suite attendue d'un compteur : v0, v0 − 1, v0 − 2…
    (l'idée de l'utilisateur, le 2026-10-29 : chercher les 3 au départ, garder ceux qui passent à 2
    après la mort, puis à 1…). La suite est lue sur les valeurs successives distinctes de l'octet,
    à partir de sa première valeur v0, et, sans remise, jusqu'à 0 : ce qui suit appartient à la démo
    ou à la partie suivante. Chaque pas doit être − 1, ou, avec remise, 0 → $FF ou
    si `remise`, un retour à v0 (une vie, un round, une bombe rechargée). Chaque départ de `departs`
    est essayé en binaire et en BCD. `ecart` : l'écart médian entre deux baisses, en relevés (un
    compteur d'animation change à chaque relevé). `fin_k` : le relevé de la fin de partie ; un pas
    hors suite au-delà clôt la suite au lieu de l'écarter. Rend (adresse, départ codé, baisses,
    relevés des baisses), les plus longues suites d'abord."""
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
                            break               # la dernière vie : la suite s'arrête, la démo remet le compteur
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
    """Le relevé des jeux d'action : un run par jeu (--scenario, action par défaut), filtré puis effacé."""
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
        except FileNotFoundError:          # MAME n'a pas démarré le jig : le jeu est écarté, pas le balayage
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
        # La fenêtre de la partie : de 700 (les vies posées après START) à 1 000 trames après la fin
        # de partie, où la démo et la partie suivante remettent les compteurs (relevés du 2026-10-29).
        garde = [k for k, n in enumerate(idx) if n >= 700 and (not fin or n <= fin + 1000)]
        R, idx = R[garde], [idx[k] for k in garde]
        # Les suites attendues : les vies de 1 à 5 au départ, sans remise ; les bombes de 2 à 10,
        # rechargées ; le temps à 30, 50, 59 (minutes:secondes), 60, 90 ou 99, remis à chaque vie ou stage.
        fk = next((k for k, n in enumerate(idx) if fin and n >= fin), None)
        vies = filtre_suite(R, range(1, 6), False, 2, 12, None, fk)
        # Les vies : celles qui baissent quand P1 meurt. Les copies d'une même cellule baissent aux
        # mêmes relevés ; la dernière vie se perd peu avant la fin de partie. Rangées par l'écart
        # entre la dernière baisse et la fin de partie, puis par la taille du groupe de baisses
        # simultanées (la cellule et ses copies d'affichage).
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
    """Les candidats d'une catégorie forcés tous ensemble, puis le groupe qui tient coupé en deux,
    jusqu'à une cellule. Tient : le témoin perd la partie, le run forcé non, et ses images bougent."""
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
    ac.add_argument("--scenario", default="action", choices=("action", "saut", "immobile", "bombe", "saut2", "action2"))
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
