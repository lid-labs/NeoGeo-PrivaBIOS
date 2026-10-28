#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Thibaut Lion
# Non-régression locale du BIOS : un verdict PASS/FAIL par étage, sortie non nulle au premier échec.
#
#   bench/non-regression.sh [options] <dossier-roms> <dossier-travail>
#
#   --rapide              étages 0 et 1, puis un sous-ensemble court : la matrice sur aof, garou et
#                         kof98, l'écran de plantage en erreur d'adresse, les soft-DIP des 22 jeux,
#                         les autotests (le seul jig du sous-ensemble qui passe par l'écran TEST) ;
#                         pas d'étage 4
#   --sources <dossier>   sources à construire (défaut : src/c0) ; une copie jetable hors du dépôt
#                         est acceptée, c'est ainsi que le harnais s'éprouve par mutation
#   --matrice-ref <tsv>   relevé de référence de la matrice
#                         (défaut : measured/2026-10-22-repetition-et-start-matrice.tsv)
#   --jobs <n>            runs MAME en parallèle (défaut : le nombre de cœurs moins deux)
#
# Les runs de référence, qui ne dépendent pas de notre image (colonnes snk et unibios40 de la matrice,
# témoins SNK du parcours), sont gardés dans <dossier-travail>/cache-temoins et repris par la passe
# suivante du même jour sur le même dossier (`matrice.sh`, BIOS_CACHE ; `parcours.sh --cache`).
# Le dossier de travail reçoit les objets de la construction (BIOS_OBJ de `build/construire.sh`,
# pour ne jamais se mêler à une autre construction), l'image, les romsets substitués, les sorties
# brutes de chaque run et `resume.txt`.
#
# LES ÉTAGES, et leur critère. Chaque relevé de référence est versionné dans `measured/` :
#
#   0  `python3 -I -B bench/test_generer_contrats.py` : code de sortie 0, « OK », au moins un test.
#   1  `build/construire.sh <sources> <travail>/bios.sp1`, objets dans <travail>/obj : 131 072 octets.
#   2  `bench/matrice.sh`, sans nullbios, notre image en variante, sur les jeux du relevé de
#      référence (lus dedans, pas en dur). Pour la colonne de notre image (la seule colonne du
#      relevé qui n'est ni snk, ni unibios40, ni nullbios) : même verdict au caractère près, contrôle
#      ok, et |vifs_max - référence| ≤ 2 % de la référence, jeu par jeu. Colonnes snk et
#      unibios40 : contrôle ok sur tous les jeux — la santé de l'instrument, pas un jugement.
#   3  Les jigs, chacun contre son relevé ; tous les runs doivent sortir de MAME en 0 et porter
#      « WRONG CHECKSUMS » (la preuve que notre image est chargée, comme `matrice.sh`) :
#      3a plantage.lua, aof, P_MODE=adr puis ill : « VERIF total ok=27 ecart=0 » puis « ok=24
#         ecart=0 » (2026-10-21-ecran-plantage.tsv, après revue), et un RESET après le START.
#      3b softdip.lua, les jeux de 2026-10-22-soft-dip-multi-slot-lot1.tsv : une remise, et
#         GAME_DIP égal à la colonne game_dip_snk, à l'octet.
#      3c autotests.lua, aof sain : WORK, PALETTE, VRAM et BACKUP rendent « OK », aucun FAIL ni
#         DELAI, backup « octets_differents=0 » (2026-10-21-autotests.tsv, run « sain »).
#      3d menu.lua, aof, TEST tenu à la trame 1500, A sur RESUME à 1600 : le menu s'ouvre et se
#         ferme, adresse VRAM retrouvée, VRAM et palettes avant/après 0 octet différent, RAM de
#         travail différente seulement dans $10F4C0-$10FB07 (les zones du menu et des cheats,
#         celles qu'exclut l'empreinte de `menu.lua` ; 2026-10-21-menu-en-jeu.tsv).
#      3e editeur.lua, aof, NVRAM neuve, TEST tenu jusqu'à 260, bas, droite (ROUND TIME), START :
#         à la trame 265 un bloc de sauvegarde égal à GAME_DIP ; à la trame 500, ce bloc et
#         GAME_DIP ont l'octet 4 augmenté de 1 et lui seul, et le jeu a la main (USER mode 01)
#         (2026-10-20-editeur-soft-dip.tsv, aof run 1 : 3C → 3D).
#      3f bus-flottant.lua, aof, 700 trames : la cartouche ne répond que sous REG_CRTFIX, comme
#         sur le matériel (en-tête du jig). Aucune lecture flottante, aucun reset, et le jeu a la
#         main. L'image n°8 (6fc2d51b…) y lit 9 fois le bus flottant au boot (son GAME NGH E05C,
#         celui d'une vraie MV-2F, 2026-10-24) ; measured/2026-10-24-slot-crtfix.tsv.
#   En --rapide, l'étage 3 ne garde que 3a (adr), 3b et 3c.
#   4  En complet seulement : `bench/parcours.sh` sur la même image, --jobs du script — le parcours
#      du joueur, 158 scènes jugées sur l'image et le son (`-wavwrite`) contre un témoin ou une
#      empreinte, seuils dans measured/2026-10-23-parcours.tsv, pour les six du mode AES
#      measured/2026-10-23-parcours-aes.tsv, pour les 34 de la couverture
#      measured/2026-10-23-parcours-couverture-scenes.tsv, pour les 18 du menu en jeu complet
#      measured/2026-10-23-menu-en-jeu-complet.tsv, pour les 12 de la carte mémoire et des scores
#      measured/2026-10-24-parcours-carte.tsv, pour les 8 des réglages de la borne (FREE PLAY, NO CONTINUE,
#      DEMO SOUND) measured/2026-10-25-parcours-borne.tsv, pour les 3 du catalogue des cheats et de CHEATS/DEBUG
#      measured/2026-10-25-parcours-cheats.tsv, pour les 10 des commutateurs de la carte et du geste sans
#      bouton TEST measured/2026-10-25-parcours-dip-free-play.tsv, pour demo-ssideki (la grille de grille.s)
#      measured/2026-10-25-parcours-ssideki.tsv, pour les 7 du CRC32 de la cartouche et des debug dips
#      measured/2026-10-25-parcours-crc-debug.tsv : toutes PASS. Une scène dont le relevé
#      porte « bug_connu » à 1 sortirait « CONNU » sans faire échouer l'étage ; aucune ne le porte
#      depuis la correction de CREDIT_CHECK en mode AES (aes-texte). Son en-tête porte les
#      critères ; `bench/parcours-mutations.py --eprouver` prouve que chacune sait échouer
#      (202 mutations). Huit scènes, bf-*, rejouent l'écran TEST sous `bus-flottant.lua` ;
#      sans-cartouche joue ng_mv1 sans cartouche sous le même modèle (il faut ng_mv1.zip), flash-cart
#      aof muette sur ses 30 premières trames, et
#      scores-gel joue wh2 sur la MV-6F (il faut wh2.zip), cheats-vies et crc-banques jouent mslug2 (il faut mslug2.zip),
#      dd-effet et dd-off kof94 (il faut kof94.zip),
#      les scènes dip-* et geste-* la MV-2F (il faut ng_mv2f.zip ; mslug, samsho4 et ssideki pour geste-partie),
#      demo-ssideki joue ssideki sur la MV-6F (il faut ssideki.zip), alpha-trajectoire et howto-preisle2
#      (la table du sinus, measured/2026-10-28-parcours-sinus.tsv) alpham2 et preisle2.
#
# TEMPS RÉELS, mesurés le 2026-10-22 sur l'image de main (sha256 1db82fe1…), machine à 14 cœurs,
# --jobs 4, un autre agent faisant tourner MAME en même temps, d'une charge variable :
#   complet, trois passes : étage 0 0-1 s, étage 1 1 s, étage 2 108 / 112 / 848 s, étage 3
#     18 / 153 / 19 s — 128 / 266 / 868 s en tout. Les deux passes lentes ne viennent pas des
#     verdicts, identiques : à 153 s, trois runs soft-DIP sont restés ~135 s hors émulation (leur
#     vitesse moyenne est normale, cause non identifiée) ; à 848 s, des runs de matrice tombés à
#     298 % de vitesse au lieu de ~2 000 %
#   complet avec l'étage 4, le 2026-10-23 sur l'image de main (528b7e9c…), --jobs 2, deux autres MAME
#     à côté : 1 / 1 / 200 / 33 / 131 s, 366 s en tout ; le parcours seul, --jobs 2, 97 à 131 s
#   complet avec l'étage 4 à 63 scènes, le 2026-10-23 sur l'image qui corrige CREDIT_CHECK en mode
#     AES (6fc2d51b…), --jobs 2 : 0 / 1 / 145 / 27 / 268 s, 441 s en tout
#   complet avec l'étage 4 à 81 scènes (le menu en jeu complet), le 2026-10-23 sur 01180fcb…, --jobs 2,
#     un autre MAME à côté : 0 / 2 / 199 / 38 / 459 s, 698 s en tout
#   complet avec l'étage 4 à 85 scènes (les quatre du bus flottant), le 2026-10-24 sur 16c58ca2…, --jobs 2,
#     les mutations du parcours tournant à côté : 1 / 1 / 199 / 49 / 500 s
#   complet avec l'étage 4 à 86 scènes (sans-cartouche), le 2026-10-24 sur 70f73d53…, --jobs 2, les
#     mutations du parcours et un catalogue tournant à côté : 1 / 3 / 204 / 51 / 587 s
#   rapide, deux passes : étage 0 0 s, étage 1 2 s, étage 2 24 / 25 s, étage 3 19 / 15 s —
#     45 / 42 s en tout (la seconde sur une mutation, arrêtée à 3c)
#
# CE QUE CE HARNAIS NE COUVRE PAS : le matériel ; la colonne nullbios ; le son hors de l'étage 4
# (les étages 0-3 ne l'écoutent pas) ; la région us ; une vitesse d'émulation (relevée, jamais
# jugée) ; les jeux hors du corpus de 22, et, pour l'étage 4, hors de aof, puzzledp, b2b, kof98 et
# ncombat.
#
# Salle blanche : aucune ROM n'est lue ici hors de MAME, qui la charge ; MAME sans fenêtre,
# NVRAM isolée par run, jamais de débogueur. Aucune ROM n'est versionnée.
set -u

ICI="$(cd "$(dirname "$0")" && pwd)"
PAQUET="$(cd "$ICI/.." && pwd)"
RAPIDE=0
SOURCES="$PAQUET/src/c0"
MREF="$PAQUET/measured/2026-10-22-repetition-et-start-matrice.tsv"
SREF="$PAQUET/measured/2026-10-22-soft-dip-multi-slot-lot1.tsv"
JOBS=$(( $( (sysctl -n hw.ncpu || nproc) 2>/dev/null || echo 4) - 2 )); [ "$JOBS" -ge 1 ] || JOBS=1
while [ $# -gt 0 ]; do
  case "$1" in
    --rapide) RAPIDE=1; shift ;;
    --sources) SOURCES="${2:?--sources attend un dossier}"; shift 2 ;;
    --matrice-ref) MREF="${2:?--matrice-ref attend un fichier}"; shift 2 ;;
    --jobs) JOBS="${2:?--jobs attend un nombre}"; shift 2 ;;
    --) shift; break ;;
    -*) echo "option inconnue : $1" >&2; exit 2 ;;
    *) break ;;
  esac
done
ROMS="${1:?usage : bench/non-regression.sh [--rapide] [--sources d] [--matrice-ref f] [--jobs n] <dossier-roms> <dossier-travail>}"
WORK="${2:?dossier de travail attendu}"
case "$JOBS" in ''|*[!0-9]*|0) echo "--jobs refusé : $JOBS" >&2; exit 2 ;; esac
[ -d "$ROMS" ] || { echo "dossier de ROMs introuvable : $ROMS" >&2; exit 2; }
[ -d "$SOURCES" ] || { echo "sources introuvables : $SOURCES" >&2; exit 2; }
for f in "$MREF" "$SREF"; do [ -s "$f" ] || { echo "relevé introuvable : $f" >&2; exit 2; }; done
command -v mame >/dev/null || { echo "mame introuvable" >&2; exit 2; }
mkdir -p "$WORK"
ROMS="$(cd "$ROMS" && pwd)"; WORK="$(cd "$WORK" && pwd)"
SOURCES="$(cd "$SOURCES" && pwd)"
MREF="$(cd "$(dirname "$MREF")" && pwd)/$(basename "$MREF")"
IMG="$WORK/bios.sp1"
RESUME="$WORK/resume.txt"
: > "$RESUME"
DEBUT=$(date +%s)

# Le juge : du python3 de la bibliothèque standard, une sous-commande par critère. Il écrit ses
# constats sur la sortie, et sort en 1 au moindre écart.
juger() {
  python3 -I -B - "$@" <<'PY'
import os, re, sys

def lignes(chemin):
    with open(chemin, encoding="utf-8") as f:
        return [l.rstrip("\n") for l in f if l.strip() and not l.startswith("#")]

def table(chemin):
    l = lignes(chemin)
    tete = l[0].split("\t")
    return [dict(zip(tete, x.split("\t"))) for x in l[1:]]

def jeux(chemin):
    vus = []
    for r in table(chemin):
        if r["jeu"] not in vus:
            vus.append(r["jeu"])
    return vus

ecarts = []
def ecart(msg):
    ecarts.append(msg)
    print("  ECART " + msg)

def fin(quoi):
    if ecarts:
        print(f"  {quoi} : {len(ecarts)} écart(s)")
        sys.exit(1)
    print(f"  {quoi} : conforme")

cmd, args = sys.argv[1], sys.argv[2:]

if cmd == "jeux":
    print(" ".join(jeux(args[0])))

elif cmd == "matrice":
    ref, mes, notre = table(args[0]), table(args[1]), args[2]
    retenus = args[3].split()
    cols = sorted({r["bios"] for r in ref} - {"snk", "unibios40", "nullbios"})
    if len(cols) != 1:
        print(f"  le relevé de référence doit avoir UNE colonne d'image, il en a {cols}")
        sys.exit(1)
    col = cols[0]
    R = {(r["jeu"], r["bios"]): r for r in ref}
    M = {(r["jeu"], r["bios"]): r for r in mes}
    for j in retenus:
        for b in ("snk", "unibios40"):
            m = M.get((j, b))
            if m is None: ecart(f"{j}/{b} : run absent")
            elif m["controle"] != "ok": ecart(f"{j}/{b} : contrôle {m['controle']} (instrument)")
        r, m = R.get((j, col)), M.get((j, notre))
        if r is None: ecart(f"{j} : absent du relevé de référence"); continue
        if m is None: ecart(f"{j}/{notre} : run absent"); continue
        if m["controle"] != "ok": ecart(f"{j}/{notre} : contrôle {m['controle']}")
        if m["verdict"] != r["verdict"]: ecart(f"{j}/{notre} : verdict « {m['verdict']} », référence « {r['verdict']} »")
        try:
            v, vr = int(m["vifs_max"]), int(r["vifs_max"])
        except ValueError:
            ecart(f"{j}/{notre} : vifs illisibles ({m['vifs_max']!r} / {r['vifs_max']!r})"); continue
        # 2 % de la référence ; une référence nulle n'admet que 0.
        if abs(v - vr) * 100 > 2 * vr or (vr == 0 and v != 0):
            ecart(f"{j}/{notre} : vifs {v}, référence {vr} ({(v - vr) * 100 / max(vr, 1):+.2f} %)")
        else:
            print(f"  {j:10s} {m['verdict']:32s} vifs {v:6d} / {vr:6d}")
    fin(f"matrice, {len(retenus)} jeu(x), colonne {col} de la référence")

elif cmd == "plantage":
    chemin, ok_attendu, start = args[0], int(args[1]), int(args[2])
    t = open(chemin, encoding="utf-8").read()
    m = re.search(r"^VERIF total ok=(\d+) ecart=(\d+)$", t, re.M)
    if not m: ecart("aucune ligne « VERIF total »")
    elif (int(m[1]), int(m[2])) != (ok_attendu, 0):
        ecart(f"ok={m[1]} ecart={m[2]}, attendu ok={ok_attendu} ecart=0")
        for l in t.splitlines():
            if l.startswith("VERIF") and l.endswith("ECART"): print("    " + l)
    resets = [int(x) for x in re.findall(r"^f(\d+) RESET$", t, re.M)]
    if not any(r > start for r in resets): ecart(f"aucun RESET après le START de la trame {start}")
    fin(f"plantage {os.path.basename(os.path.dirname(chemin))}")

elif cmd == "softdip":
    ref, dossier = table(args[0]), args[1]
    for r in ref:
        f = os.path.join(dossier, r["jeu"], "softdip.txt")
        if not os.path.exists(f): ecart(f"{r['jeu']} : pas de relevé"); continue
        t = open(f, encoding="utf-8").read()
        rem = re.search(r"remise=(\S+)", t)
        gd = re.search(r"game_dip=([0-9A-F ]+)$", t.strip())
        if not rem or rem[1] == "aucune": ecart(f"{r['jeu']} : pas de remise"); continue
        if not gd or gd[1].strip() != r["game_dip_snk"].strip():
            ecart(f"{r['jeu']} : GAME_DIP {gd[1].strip() if gd else '?'}, référence {r['game_dip_snk']}")
    fin(f"soft-DIP, {len(ref)} jeux contre game_dip_snk")

elif cmd == "autotests":
    t = open(args[0], encoding="utf-8").read()
    for nom, motif in (("WORK", "> WORK RAM"), ("PALETTE", "> PALETTE RAM"), ("VRAM", "> VRAM"), ("BACKUP", "> BACKUP RAM")):
        m = re.search(r"^f\d+ RESULTAT " + nom + r" duree=(\d+) \|(.*)\|$", t, re.M)
        if not m: ecart(f"{nom} : pas de RESULTAT"); continue
        if not re.search(re.escape(motif) + r"\s+OK\s", m[2]) or "FAIL" in m[2]: ecart(f"{nom} : |{m[2].strip()}|")
        else: print(f"  {nom:8s} OK en {m[1]} trames")
    for mot in ("DELAI", "ERREUR"):
        for l in re.findall(r"^f\d+ " + mot + r".*$", t, re.M): ecart(l)
    b = re.search(r"BRAM avant=\S+ apres=\S+ octets_differents=(\d+)", t)
    if not b or b[1] != "0": ecart(f"backup : {b[0] if b else 'pas de relevé'}")
    fin("autotests aof")

elif cmd == "menu":
    d = args[0]
    t = open(os.path.join(d, "menu.txt"), encoding="utf-8").read()
    if "MENU OUVERT" not in t: ecart("le menu ne s'est pas ouvert")
    m = re.search(r"MENU FERME adr_retrouvee=(\d+)", t)
    if not m: ecart("le menu ne s'est pas refermé")
    elif m[1] != "1": ecart("adresse VRAM non retrouvée")
    for k in ("vram", "pal", "ram"):
        try:
            a = open(os.path.join(d, f"avant-{k}.bin"), "rb").read()
            p = open(os.path.join(d, f"apres-{k}.bin"), "rb").read()
        except OSError:
            ecart(f"{k} : relevé avant/après absent"); continue
        if len(a) != len(p): ecart(f"{k} : tailles {len(a)} / {len(p)}"); continue
        # Deux relevés vides seraient « identiques » sans rien avoir comparé.
        if len(a) == 0: ecart(f"{k} : relevé avant/après vide"); continue
        diff = [i for i in range(len(a)) if a[i] != p[i]]
        if k == "ram":
            hors = [0x100000 + i for i in diff if not (0xF4C0 <= i <= 0xFB07)]
            if hors: ecart(f"RAM : {len(hors)} octet(s) différent(s) hors de $10F4C0-$10FB07, dont ${hors[0]:06X}")
            else: print(f"  RAM      {len(diff)} octet(s) différent(s), tous dans $10F4C0-$10FB07")
        elif diff: ecart(f"{k} : {len(diff)} octet(s) différent(s)")
        else: print(f"  {k:8s} 0 octet différent sur {len(a)}")
    fin("menu en jeu aof")

elif cmd == "editeur":
    t = open(args[0], encoding="utf-8").read()
    def releve(f):
        r = {}
        for nom, val in re.findall(r"^f" + str(f) + r" (bloc\d|GAME_DIP) ([0-9A-F ]+)$", t, re.M):
            r[nom] = val.split()
        return r
    a, b = releve(265), releve(500)
    if "GAME_DIP" not in a or "GAME_DIP" not in b: ecart("relevés des trames 265 et 500 absents")
    else:
        blocs = [k for k in sorted(a) if k.startswith("bloc") and a[k] == a["GAME_DIP"]]
        if len(blocs) != 1: ecart(f"{len(blocs)} bloc(s) égal(aux) à GAME_DIP à la trame 265, 1 attendu")
        else:
            k = blocs[0]
            voulu = list(a["GAME_DIP"]); voulu[4] = "%02X" % ((int(voulu[4], 16) + 1) & 0xFF)
            if b["GAME_DIP"] != voulu: ecart(f"GAME_DIP {' '.join(b['GAME_DIP'])}, attendu {' '.join(voulu)}")
            if b.get(k) != voulu: ecart(f"{k} {' '.join(b.get(k, []))}, attendu {' '.join(voulu)}")
            if not ecarts: print(f"  octet 4 {a['GAME_DIP'][4]} -> {voulu[4]} dans GAME_DIP et {k}")
    if not re.search(r"^f\d+ user=01/", t, re.M): ecart("le jeu n'a jamais eu la main (USER mode 01)")
    fin("éditeur de soft-DIP aof")
PY
}

# ---- Le compte rendu --------------------------------------------------------------------------
T0=0
etage() { T0=$(date +%s); echo; echo "=== étage $1"; }
conclure() {  # conclure <étage> <rc>
  local duree=$(( $(date +%s) - T0 )) verdict=PASS
  [ "$2" -eq 0 ] || verdict=FAIL
  printf '%s  %4d s  %s\n' "$verdict" "$duree" "$1" >> "$RESUME"
  if [ "$2" -ne 0 ]; then finir 1; fi
}
finir() {
  echo; echo "=== résumé ($(( $(date +%s) - DEBUT )) s en tout, travail : $WORK)"
  cat "$RESUME"
  [ "$1" -eq 0 ] && echo "NON-RÉGRESSION : PASS" || echo "NON-RÉGRESSION : FAIL"
  exit "$1"
}

# ---- Les runs MAME ----------------------------------------------------------------------------
# Un romset par jeu, le seul membre sp-s2.sp1 remplacé par notre image, fabriqué par un fichier
# temporaire comme dans `matrice.sh` : interrompu, il ne laisse pas un romset au BIOS d'origine.
romset() {
  local j="$1" d="$WORK/roms/$1.zip"
  [ -L "$d" ] && { echo "REFUS : $d est un lien symbolique" >&2; return 1; }
  [ -s "$d" ] && return 0
  [ -s "$ROMS/$j.zip" ] || { echo "set introuvable : $ROMS/$j.zip" >&2; return 1; }
  rm -f "$d.part"
  cp "$ROMS/$j.zip" "$d.part" && ( cd "$WORK/roms/img" && zip -q -j -X "$d.part" sp-s2.sp1 ) && mv "$d.part" "$d"
}
# lancer <jeu> <dossier> <jig.lua> [VAR=valeur…] : en arrière-plan, au plus $JOBS à la fois ; le
# code de sortie de MAME va dans <dossier>/rc. NVRAM neuve : le dossier est vidé avant.
PIDS=""
lancer() {
  local j="$1" o="$2" lua="$3" p n=0 reste=""; shift 3
  rm -rf "$o"; mkdir -p "$o"
  # File d'attente : au-delà de $JOBS runs en cours, on attend le plus ancien.
  for p in $PIDS; do n=$(( n + 1 )); done
  if [ $n -ge "$JOBS" ]; then
    for p in $PIDS; do if [ -z "${premier:-}" ]; then premier=$p; wait "$p"; else reste="$reste $p"; fi; done
    PIDS="$reste"; unset premier
  fi
  ( cd "$o" && env "$@" SDL_VIDEODRIVER=dummy SDL_MAC_BACKGROUND_APP=1 \
      mame "$j" -rompath "$WORK/roms" -bios euro -video none -sound none -nothrottle \
      -seconds_to_run 120 -nvram_directory "$o/nvram" -cfg_directory "$o/cfg" -skip_gameinfo \
      -autoboot_script "$ICI/$lua" > "$o/mame.log" 2>&1; echo $? > "$o/rc" ) &
  PIDS="$PIDS $!"
}
# Ce qui précède le juge, pour chaque run : MAME sorti en 0 et l'image substituée.
runs_sains() {
  local o bon=0
  for o in "$@"; do
    if [ "$(cat "$o/rc" 2>/dev/null)" != 0 ]; then echo "  ECART $o : MAME sorti en $(cat "$o/rc" 2>/dev/null || echo '?')"; bon=1
    elif ! grep -q 'WRONG CHECKSUMS' "$o/mame.log"; then echo "  ECART $o : pas de WRONG CHECKSUMS, notre image n'est pas chargée"; bon=1
    fi
  done
  return $bon
}

# ---- 0. Les tests du générateur de contrats ----------------------------------------------------
etage "0 : tests du générateur de contrats"
sortie=$(cd "$PAQUET" && python3 -I -B bench/test_generer_contrats.py 2>&1); rc=$?
echo "$sortie" | tail -3
if [ $rc -eq 0 ] && echo "$sortie" | tail -1 | grep -qx 'OK' && echo "$sortie" | grep -Eq '^Ran [1-9][0-9]* tests?'; then rc=0; else rc=1; fi
conclure "0 tests du générateur" $rc

# ---- 1. La construction ------------------------------------------------------------------------
etage "1 : construction de $SOURCES"
rm -f "$IMG"
BIOS_OBJ="$WORK/obj" "$PAQUET/build/construire.sh" "$SOURCES" "$IMG"; rc=$?
if [ $rc -eq 0 ] && [ "$(wc -c < "$IMG" 2>/dev/null)" -eq 131072 ] 2>/dev/null; then
  echo "  image $(shasum -a 256 "$IMG" | cut -c1-16)…"
else rc=1; fi
conclure "1 construction" $rc

mkdir -p "$WORK/roms/img"
rm -f "$WORK/roms/img/sp-s2.sp1"; cp "$IMG" "$WORK/roms/img/sp-s2.sp1"
# Un romset déjà là porte peut-être une autre image : tout est refait si l'empreinte a changé.
EMP="$(shasum -a 256 "$IMG" | cut -d' ' -f1)"
if [ "$(cat "$WORK/roms/.image-sha256" 2>/dev/null)" != "$EMP" ]; then
  rm -f "$WORK/roms/"*.zip "$WORK/roms/.image-sha256"
fi

# ---- 2. La matrice -----------------------------------------------------------------------------
etage "2 : matrice contre $(basename "$MREF")"
if [ $RAPIDE = 1 ]; then JEUX_M="aof garou kof98"; else JEUX_M="$(juger jeux "$MREF")" || conclure "2 liste des jeux de $MREF illisible" 1; fi
# Aucun jeu à jouer, c'est aucun jugement : la matrice serait déclarée conforme sur zéro jeu.
[ -n "$JEUX_M" ] || conclure "2 aucun jeu dans $MREF" 1
rm -rf "$WORK/matrice"; mkdir -p "$WORK/matrice"
# Les jeux répartis en $JOBS matrices indépendantes, chacune dans son dossier : `matrice.sh` est
# séquentiel, et ses dossiers de travail ne se partagent pas.
k=0; LOTS=""
for j in $JEUX_M; do
  lot="$WORK/matrice/lot$(( k % JOBS ))"
  [ -e "$lot" ] || LOTS="$LOTS $lot"
  echo "$j" >> "$lot"; k=$(( k + 1 ))
done
pids=""
for lot in $LOTS; do
  ( BIOS_SANS_NULLBIOS=1 BIOS_JEUX="$(tr '\n' ' ' < "$lot")" BIOS_VARIANTES="sprixe=$IMG" \
      BIOS_CACHE="$WORK/cache-temoins/matrice" \
      "$ICI/matrice.sh" "$ROMS" "$lot.d" > "$lot.tsv" 2> "$lot.err"; echo $? > "$lot.rc" ) &
  pids="$pids $!"
done
wait $pids
rc=0
for lot in $LOTS; do
  [ "$(cat "$lot.rc")" = 0 ] || { echo "  matrice.sh sorti en $(cat "$lot.rc") :"; tail -3 "$lot.err"; rc=1; }
done
{ head -1 "$WORK/matrice/lot0.tsv"; for lot in $LOTS; do tail -n +2 "$lot.tsv"; done; } > "$WORK/matrice.tsv"
[ $rc -eq 0 ] && { juger matrice "$MREF" "$WORK/matrice.tsv" sprixe "$JEUX_M"; rc=$?; }
conclure "2 matrice ($(echo $JEUX_M | wc -w | tr -d ' ') jeux)" $rc

# ---- 3. Les jigs -------------------------------------------------------------------------------
etage "3 : jigs"
J="$WORK/jigs"; rm -rf "$J"; mkdir -p "$J"
JEUX_S="$(juger jeux "$SREF")" || conclure "3b liste des jeux de $SREF illisible" 1
[ -n "$JEUX_S" ] || conclure "3b aucun jeu dans $SREF" 1
rc=0
for j in aof $JEUX_S; do romset "$j" || rc=1; done
[ $rc -eq 0 ] && echo "$EMP" > "$WORK/roms/.image-sha256"
conclure_si_echec() { [ "$2" -eq 0 ] || conclure "$1" "$2"; }
conclure_si_echec "3 romsets substitués" $rc

PIDS=""
lancer aof "$J/plantage-adr" plantage.lua P_OUT="$J/plantage-adr" P_MODE=adr
lancer aof "$J/autotests" autotests.lua T_OUT="$J/autotests"
if [ $RAPIDE = 0 ]; then
  lancer aof "$J/plantage-ill" plantage.lua P_OUT="$J/plantage-ill" P_MODE=ill
  lancer aof "$J/menu" menu.lua J_OUT="$J/menu" J_APPUIS=1600:A
  lancer aof "$J/editeur" editeur.lua E_OUT="$J/editeur" E_TEST=260 \
    E_APPUIS=270:bas,280:droite,300:START E_RELEVES=265,500 E_FIN=600
  lancer aof "$J/flottant" bus-flottant.lua BF_OUT="$J/flottant/bf.tsv" BF_FIN=700
fi
for j in $JEUX_S; do lancer "$j" "$J/softdip/$j" softdip.lua S_OUT="$J/softdip/$j/softdip.txt"; done
wait

# Jugés dans l'ordre, et le premier écart arrête tout ; un seul temps pour l'étage, les runs
# s'étant chevauchés.
echo "--- 3a plantage"
runs_sains "$J/plantage-adr" && juger plantage "$J/plantage-adr/plantage.txt" 27 1700; rc=$?
if [ $rc -eq 0 ] && [ $RAPIDE = 0 ]; then
  runs_sains "$J/plantage-ill" && juger plantage "$J/plantage-ill/plantage.txt" 24 1700; rc=$?
fi
conclure_si_echec "3a plantage" $rc
echo "--- 3b soft-DIP"
dossiers=""; for j in $JEUX_S; do dossiers="$dossiers $J/softdip/$j"; done
runs_sains $dossiers && juger softdip "$SREF" "$J/softdip"; rc=$?
conclure_si_echec "3b soft-DIP" $rc
echo "--- 3c autotests"
runs_sains "$J/autotests" && juger autotests "$J/autotests/autotests.txt"; rc=$?
conclure_si_echec "3c autotests" $rc
if [ $RAPIDE = 0 ]; then
  echo "--- 3d menu en jeu"
  runs_sains "$J/menu" && juger menu "$J/menu"; rc=$?
  conclure_si_echec "3d menu en jeu" $rc
  echo "--- 3e éditeur de soft-DIP"
  runs_sains "$J/editeur" && juger editeur "$J/editeur/editeur.txt"; rc=$?
  conclure_si_echec "3e éditeur" $rc
  echo "--- 3f bus flottant"
  bilan=$(grep '^#.bilan' "$J/flottant/bf.tsv" 2>/dev/null); echo "  ${bilan#*bilan?}"
  runs_sains "$J/flottant" \
    && echo "$bilan" | grep -q ' 0 resets, ' \
    && echo "$bilan" | grep -q 'lectures flottantes : 0 bios, 0 jeu' \
    && ! echo "$bilan" | grep -q ' 0 trames finies dans le jeu'; rc=$?
  conclure_si_echec "3f bus flottant" $rc
  conclure "3 jigs (3a-3f)" 0
else
  conclure "3 jigs (3a adr, 3b, 3c)" 0
  finir 0
fi

# ---- 4. Le parcours du joueur (complet seulement) ----------------------------------------------
etage "4 : parcours du joueur"
"$ICI/parcours.sh" --image "$IMG" --jobs "$JOBS" --cache "$WORK/cache-temoins/parcours" "$ROMS" "$WORK/parcours" | grep -E '^(PASS|FAIL|CONNU|runs|PARCOURS)'
rc=${PIPESTATUS[0]}
conclure "4 parcours ($(grep -c '^PASS' "$WORK/parcours/parcours.txt" 2>/dev/null || echo 0) scènes PASS)" $rc
finir 0
