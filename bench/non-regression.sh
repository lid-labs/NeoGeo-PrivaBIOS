#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Thibaut Lion
# Local regression check of the BIOS: one PASS/FAIL verdict per stage, non-zero exit at the first failure.
#
#   bench/non-regression.sh [options] <dossier-roms> <dossier-travail>
#
#   --rapide              stages 0 and 1, then a short subset: the matrix on aof, garou and
#                         kof98, the crash screen on an address error, the soft-DIPs of the 22 games,
#                         the self-tests (the only jig of the subset that goes through the TEST screen);
#                         no stage 4
#   --sources <dossier>   sources to build (default: src/c0); a throwaway copy outside the repository
#                         is accepted, that is how the harness is proven by mutation
#   --matrice-ref <tsv>   reference record of the matrix
#                         (default: measured/2026-10-22-repetition-et-start-matrice.tsv)
#   --jobs <n>            MAME runs in parallel (default: the number of cores minus two)
#
# The reference runs, which do not depend on our image (snk and unibios40 columns of the matrix,
# SNK witness runs of the player's path), are kept in <dossier-travail>/cache-temoins and reused by the
# next pass of the same day on the same folder (`matrice.sh`, BIOS_CACHE; `parcours.sh --cache`).
# The work folder receives the build objects (BIOS_OBJ of `build/construire.sh`,
# so as never to mix with another build), the image, the substituted romsets, the raw
# outputs of each run and `resume.txt`.
#
# THE STAGES, and their criterion. Each reference record is versioned in `measured/`:
#
#   0  `python3 -I -B bench/test_generer_contrats.py`: exit code 0, "OK", at least one test.
#   1  `build/construire.sh <sources> <travail>/bios.sp1`, objects in <travail>/obj: 131,072 bytes.
#   2  `bench/matrice.sh`, without nullbios, our image as a variant, on the games of the reference
#      record (read in it, not hard-coded). For the column of our image (the only column of the
#      record that is neither snk, nor unibios40, nor nullbios): same verdict to the character, check
#      ok, and |vifs_max - reference| ≤ 2% of the reference, game by game. Columns snk and
#      unibios40: check ok on all games — the health of the instrument, not a judgement.
#   3  The jigs, each against its record; all runs must exit MAME with 0 and carry
#      "WRONG CHECKSUMS" (the proof that our image is loaded, as in `matrice.sh`):
#      3a plantage.lua, aof, P_MODE=adr then ill: "VERIF total ok=27 ecart=0" then "ok=24
#         ecart=0" (2026-10-21-ecran-plantage.tsv, after review), and a RESET after the START.
#      3b softdip.lua, the games of 2026-10-22-soft-dip-multi-slot-lot1.tsv: one hand-over, and
#         GAME_DIP equal to the game_dip_snk column, to the byte.
#      3c autotests.lua, healthy aof: WORK, PALETTE, VRAM and BACKUP return "OK", no FAIL nor
#         DELAI, backup "octets_differents=0" (2026-10-21-autotests.tsv, "sain" run).
#      3d menu.lua, aof, TEST held at frame 1500, A on RESUME at 1600: the menu opens and
#         closes, VRAM address found again, VRAM and palettes before/after 0 bytes different, work
#         RAM different only in $10F4C0-$10FB07 (the zones of the menu and the cheats,
#         those that the fingerprint of `menu.lua` excludes; 2026-10-21-menu-en-jeu.tsv).
#      3e editeur.lua, aof, new NVRAM, TEST held until 260, down, right (ROUND TIME), START:
#         at frame 265 a save block equal to GAME_DIP; at frame 500, this block and
#         GAME_DIP have byte 4 increased by 1 and only it, and the game has control (USER mode 01)
#         (2026-10-20-editeur-soft-dip.tsv, aof run 1: 3C → 3D).
#      3f bus-flottant.lua, aof, 700 frames: the cartridge answers only under REG_CRTFIX, as
#         on the hardware (jig header). No floating read, no reset, and the game has
#         control. Image no. 8 (6fc2d51b…) reads the floating bus 9 times there at boot (its GAME NGH E05C,
#         that of a real MV-2F, 2026-10-24); measured/2026-10-24-slot-crtfix.tsv.
#   In --rapide, stage 3 keeps only 3a (adr), 3b and 3c.
#   4  In full mode only: `bench/parcours.sh` on the same image, the script's --jobs — the
#      player's path, 159 scenes judged on picture and sound (`-wavwrite`) against a witness run or a
#      fingerprint, thresholds in measured/2026-10-23-parcours.tsv, for the six of the AES mode
#      measured/2026-10-23-parcours-aes.tsv, for the 34 of the coverage
#      measured/2026-10-23-parcours-couverture-scenes.tsv, for the 18 of the full in-game menu
#      measured/2026-10-23-menu-en-jeu-complet.tsv, for the 12 of the memory card and the scores
#      measured/2026-10-24-parcours-carte.tsv, for the 8 of the cabinet settings (FREE PLAY, NO CONTINUE,
#      DEMO SOUND) measured/2026-10-25-parcours-borne.tsv, for the 3 of the cheat catalogue and of CHEATS/DEBUG
#      measured/2026-10-25-parcours-cheats.tsv, for the 10 of the board switches and of the gesture without
#      TEST button measured/2026-10-25-parcours-dip-free-play.tsv, for demo-ssideki (the grid of grille.s)
#      measured/2026-10-25-parcours-ssideki.tsv, for the 7 of the cartridge CRC32 and the debug dips
#      measured/2026-10-25-parcours-crc-debug.tsv: all PASS. A scene whose record
#      carries "bug_connu" at 1 would come out "CONNU" without failing the stage; none carries it
#      since the fix of CREDIT_CHECK in AES mode (aes-texte). Its header carries the
#      criteria; `bench/parcours-mutations.py --eprouver` proves that each one can fail
#      (205 mutations). Eight scenes, bf-*, replay the TEST screen under `bus-flottant.lua`;
#      sans-cartouche plays ng_mv1 without a cartridge under the same model (ng_mv1.zip is needed), flash-cart
#      aof muted over its first 30 frames, and
#      scores-gel plays wh2 on the MV-6F (wh2.zip is needed), cheats-vies and crc-banques play mslug2 (mslug2.zip is needed),
#      dd-effet and dd-off kof94 (kof94.zip is needed),
#      the dip-* and geste-* scenes the MV-2F (ng_mv2f.zip is needed; mslug, samsho4 and ssideki for geste-partie),
#      demo-ssideki plays ssideki on the MV-6F (ssideki.zip is needed), alpha-trajectoire and howto-preisle2
#      (the sine table, measured/2026-10-28-parcours-sinus.tsv) alpham2 and preisle2.
#
# REAL TIMES, measured on 2026-10-22 on the image of main (sha256 1db82fe1…), 14-core machine,
# --jobs 4, another agent running MAME at the same time, with a variable load:
#   full, three passes: stage 0 0-1 s, stage 1 1 s, stage 2 108 / 112 / 848 s, stage 3
#     18 / 153 / 19 s — 128 / 266 / 868 s in all. The two slow passes do not come from the
#     verdicts, identical: at 153 s, three soft-DIP runs stayed ~135 s outside emulation (their
#     average speed is normal, cause not identified); at 848 s, matrix runs dropped to
#     298% speed instead of ~2,000%
#   full with stage 4, on 2026-10-23 on the image of main (528b7e9c…), --jobs 2, two other MAMEs
#     alongside: 1 / 1 / 200 / 33 / 131 s, 366 s in all; the player's path alone, --jobs 2, 97 to 131 s
#   full with stage 4 at 63 scenes, on 2026-10-23 on the image that fixes CREDIT_CHECK in
#     AES mode (6fc2d51b…), --jobs 2: 0 / 1 / 145 / 27 / 268 s, 441 s in all
#   full with stage 4 at 81 scenes (the full in-game menu), on 2026-10-23 on 01180fcb…, --jobs 2,
#     another MAME alongside: 0 / 2 / 199 / 38 / 459 s, 698 s in all
#   full with stage 4 at 85 scenes (the four of the floating bus), on 2026-10-24 on 16c58ca2…, --jobs 2,
#     the mutations of the player's path running alongside: 1 / 1 / 199 / 49 / 500 s
#   full with stage 4 at 86 scenes (sans-cartouche), on 2026-10-24 on 70f73d53…, --jobs 2, the
#     mutations of the player's path and a catalogue running alongside: 1 / 3 / 204 / 51 / 587 s
#   quick, two passes: stage 0 0 s, stage 1 2 s, stage 2 24 / 25 s, stage 3 19 / 15 s —
#     45 / 42 s in all (the second on a mutation, stopped at 3c)
#
# WHAT THIS HARNESS DOES NOT COVER: the hardware; the nullbios column; sound outside stage 4
# (stages 0-3 do not listen to it); the us region; an emulation speed (recorded, never
# judged); games outside the corpus of 22, and, for stage 4, outside aof, puzzledp, b2b, kof98 and
# ncombat.
#
# Clean room: no ROM is read here outside MAME, which loads it; MAME with no window,
# NVRAM isolated per run, never a debugger. No ROM is versioned.
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

# The judge: standard-library python3, one subcommand per criterion. It writes its
# findings to the output, and exits with 1 at the slightest deviation.
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

# ---- The report -------------------------------------------------------------------------------
T0=0
etage() { T0=$(date +%s); echo; echo "=== étage $1"; }
conclure() {  # conclure <stage> <rc>
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

# ---- The MAME runs ----------------------------------------------------------------------------
# One romset per game, the sole sp-s2.sp1 member replaced by our image, built through a temporary
# file as in `matrice.sh`: interrupted, it does not leave a romset with the original BIOS.
romset() {
  local j="$1" d="$WORK/roms/$1.zip"
  [ -L "$d" ] && { echo "REFUS : $d est un lien symbolique" >&2; return 1; }
  [ -s "$d" ] && return 0
  [ -s "$ROMS/$j.zip" ] || { echo "set introuvable : $ROMS/$j.zip" >&2; return 1; }
  rm -f "$d.part"
  cp "$ROMS/$j.zip" "$d.part" && ( cd "$WORK/roms/img" && zip -q -j -X "$d.part" sp-s2.sp1 ) && mv "$d.part" "$d"
}
# lancer <jeu> <dossier> <jig.lua> [VAR=valeur…]: in the background, at most $JOBS at a time; MAME's
# exit code goes into <dossier>/rc. New NVRAM: the folder is emptied first.
PIDS=""
lancer() {
  local j="$1" o="$2" lua="$3" p n=0 reste=""; shift 3
  rm -rf "$o"; mkdir -p "$o"
  # Queue: beyond $JOBS runs in progress, we wait for the oldest.
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
# What comes before the judge, for each run: MAME exited with 0 and the image substituted.
runs_sains() {
  local o bon=0
  for o in "$@"; do
    if [ "$(cat "$o/rc" 2>/dev/null)" != 0 ]; then echo "  ECART $o : MAME sorti en $(cat "$o/rc" 2>/dev/null || echo '?')"; bon=1
    elif ! grep -q 'WRONG CHECKSUMS' "$o/mame.log"; then echo "  ECART $o : pas de WRONG CHECKSUMS, notre image n'est pas chargée"; bon=1
    fi
  done
  return $bon
}

# ---- 0. The tests of the contract generator ----------------------------------------------------
etage "0 : tests du générateur de contrats"
sortie=$(cd "$PAQUET" && python3 -I -B bench/test_generer_contrats.py 2>&1); rc=$?
echo "$sortie" | tail -3
if [ $rc -eq 0 ] && echo "$sortie" | tail -1 | grep -qx 'OK' && echo "$sortie" | grep -Eq '^Ran [1-9][0-9]* tests?'; then rc=0; else rc=1; fi
conclure "0 tests du générateur" $rc

# ---- 1. The build ------------------------------------------------------------------------------
etage "1 : construction de $SOURCES"
rm -f "$IMG"
BIOS_OBJ="$WORK/obj" "$PAQUET/build/construire.sh" "$SOURCES" "$IMG"; rc=$?
if [ $rc -eq 0 ] && [ "$(wc -c < "$IMG" 2>/dev/null)" -eq 131072 ] 2>/dev/null; then
  echo "  image $(shasum -a 256 "$IMG" | cut -c1-16)…"
else rc=1; fi
conclure "1 construction" $rc

mkdir -p "$WORK/roms/img"
rm -f "$WORK/roms/img/sp-s2.sp1"; cp "$IMG" "$WORK/roms/img/sp-s2.sp1"
# A romset already there may carry another image: everything is redone if the hash has changed.
EMP="$(shasum -a 256 "$IMG" | cut -d' ' -f1)"
if [ "$(cat "$WORK/roms/.image-sha256" 2>/dev/null)" != "$EMP" ]; then
  rm -f "$WORK/roms/"*.zip "$WORK/roms/.image-sha256"
fi

# ---- 2. The matrix -----------------------------------------------------------------------------
etage "2 : matrice contre $(basename "$MREF")"
if [ $RAPIDE = 1 ]; then JEUX_M="aof garou kof98"; else JEUX_M="$(juger jeux "$MREF")" || conclure "2 liste des jeux de $MREF illisible" 1; fi
# No game to play means no judgement: the matrix would be declared compliant on zero games.
[ -n "$JEUX_M" ] || conclure "2 aucun jeu dans $MREF" 1
rm -rf "$WORK/matrice"; mkdir -p "$WORK/matrice"
# The games split into $JOBS independent matrices, each in its own folder: `matrice.sh` is
# sequential, and its work folders are not shared.
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

# ---- 3. The jigs -------------------------------------------------------------------------------
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

# Judged in order, and the first deviation stops everything; a single time for the stage, the runs
# having overlapped.
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

# ---- 4. The player's path (full mode only) -----------------------------------------------------
etage "4 : parcours du joueur"
"$ICI/parcours.sh" --image "$IMG" --jobs "$JOBS" --cache "$WORK/cache-temoins/parcours" "$ROMS" "$WORK/parcours" | grep -E '^(PASS|FAIL|CONNU|runs|PARCOURS)'
rc=${PIPESTATUS[0]}
conclure "4 parcours ($(grep -c '^PASS' "$WORK/parcours/parcours.txt" 2>/dev/null || echo 0) scènes PASS)" $rc
finir 0
