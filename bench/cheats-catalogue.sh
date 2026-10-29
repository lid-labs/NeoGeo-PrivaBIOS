#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Thibaut Lion
# Le catalogue des cheats (`src/c0/cheats.s`) joué par le BIOS lui-même : pour chaque jeu, un
# cheat mis à ON par le menu en jeu, contre un témoin qui ouvre et ferme le même menu sans rien
# changer. Jugé sur l'écran ou sur le cours de la partie, la RAM n'y venant qu'en complément.
#
#   bench/cheats-catalogue.sh [--image <sp1> | --sources <dossier>] [--jeux "<romsets>"] [--jobs n]
#                             <dossier-roms> <dossier-travail>
#
# LES CRITÈRES, par genre (colonne « genre » de la table plus bas) :
#   temps  INFINITE TIME. Le menu s'ouvre au début d'un round, à la trame T (TEST tenu de T à T + 39).
#          Sur les trames T + 200 à T + 800, relevées toutes les 10, l'image du chronomètre (le
#          rectangle « zone » autour des chiffres, ses pixels choisis par la colonne « pixels »)
#          garde la même valeur sur au moins TEMPS_ON_MIN des relevés sous cheat, et au plus
#          TEMPS_TEMOIN_MAX au témoin, où le chronomètre descend. Pas un compte de valeurs
#          distinctes : un KO, ou le décor que laissent voir certains cadres, en ajoutent sous cheat
#          comme au témoin. En complément, la cellule vaut la valeur de la table, ou une de moins
#          (le jeu a décompté depuis le dernier appel du moteur), sur au moins RAM_MIN des relevés.
# Dans les deux genres, le tap du mode menu de `cheats.lua` exige que le moteur du BIOS n'ait écrit
# que l'adresse du cheat, et qu'il n'ait rien écrit au témoin.
#
# LES ENTRÉES. « f » (combat) : pièce à 400, START à 500, A toutes les 60 trames de 600 à 3500,
# droite tenue à partir de 2000 ; « s » (tir, action) : pièce, START, A toutes les 60 trames, droite
# tenue à partir de 1000, C toutes les 400 trames à partir de 1500. Le joueur ne joue pas : il meurt,
# il perd ses rounds. Aucune entrée planifiée de T − 10 à T + 150 : le menu reçoit les siennes.
#
# LA CADENCE. --jobs runs MAME à la fois (défaut : le nombre de cœurs moins deux ; un MAME n'occupe
# qu'un cœur, et chaque run a son dossier, donc leur nombre ne change aucun verdict). Les runs
# partent les plus longs d'abord (FIN décroissante) : douze des treize « vies » à 12 000 trames,
# en fin de table, partaient en dernier et faisaient attendre tout le monde à la fin. Pas de cache ici : le témoin ouvre et ferme le
# menu de NOTRE BIOS, il dépend de l'image comme le run du cheat.
#
# Salle blanche : aucune base de cheats tierce, aucun code de jeu lu ni tracé ; le PC ne sert qu'à
# dire si une écriture vient du BIOS. MAME sans fenêtre, un dossier de cfg et de NVRAM par run.
# Mesures et seuils : measured/2026-10-25-cheats-table.tsv (une ligne par cheat) et
# measured/2026-10-25-cheats-catalogue.tsv (les verdicts de ce script).
set -u

ICI="$(cd "$(dirname "$0")" && pwd)"
PAQUET="$(cd "$ICI/.." && pwd)"
SOURCES="$PAQUET/src/c0"
IMAGE=""
JOBS=$(( $( (sysctl -n hw.ncpu || nproc) 2>/dev/null || echo 4) - 2 )); [ "$JOBS" -ge 1 ] || JOBS=1
JEUX=""
while [ $# -gt 0 ]; do
  case "$1" in
    --image) IMAGE="${2:?}"; shift 2 ;;
    --sources) SOURCES="${2:?}"; shift 2 ;;
    --jeux) JEUX="${2:?}"; shift 2 ;;
    --jobs) JOBS="${2:?}"; shift 2 ;;
    -*) echo "option inconnue : $1" >&2; exit 2 ;;
    *) break ;;
  esac
done
ROMS="${1:?usage : bench/cheats-catalogue.sh [--image f | --sources d] [--jeux l] [--jobs n] <roms> <travail>}"
WORK="${2:?dossier de travail attendu}"
case "$JOBS" in ''|*[!0-9]*|0*) echo "--jobs refusé : $JOBS" >&2; exit 2 ;; esac
command -v mame >/dev/null || { echo "mame introuvable" >&2; exit 2; }
mkdir -p "$WORK"; ROMS="$(cd "$ROMS" && pwd)"; WORK="$(cd "$WORK" && pwd)"

# Seuils (voir l'en-tête).
TEMPS_ON_MIN=0.6
TEMPS_TEMOIN_MAX=0.35
RAM_MIN=0.9

# jeu  k  nom  adr  valeur  genre  entrées  T  FIN  zone(x0,y0,x1,y1)  pixels de la zone
# Les pixels : « brut », toutes les couleurs (un chronomètre dans un cadre opaque) ; « clair »,
# R + V + B > 600 ; sinon la couleur des chiffres (COULEURS plus bas), pour qu'un décor qui défile
# derrière eux ne compte pas. Choisis le 2026-10-25 sur des images des runs, le rectangle autour
# des chiffres à l'œil.
# Absent de la table : INFINITE TIME de kof95. Sous cheat, le chronomètre garde son image sur tous
# les relevés, mais aucun T essayé ne donne un témoin qui décompte sans KO dans la fenêtre (round 2 :
# 0,38 des relevés à la même image ; round 3 : un KO sous cheat). Sa preuve est celle de la recherche
# (`measured/2026-10-25-cheats-table.tsv`), et kof95 a ici P1 INFINITE LIFE.
TABLE="$(cat <<'EOF'
kof95	1	P1 INFINITE LIFE	108221	CF	vies	f	1610	12000	-	-
kof99	0	INFINITE TIME	10A7E7	32	temps	f	2950	4250	144,12,176,36	brut
kof2000	0	INFINITE TIME	10A7E6	60	temps	f	2750	4050	146,16,176,31	vert
kof2002	0	INFINITE TIME	10A7D3	32	temps	f	2320	3620	146,16,173,31	brut
samsho	0	INFINITE TIME	100A08	99	temps	f	1360	2660	140,38,179,59	clair
samsho2	0	INFINITE TIME	100AC6	99	temps	f	1330	2630	140,34,179,57	clair
samsho4	0	INFINITE TIME	108369	3C	temps	f	1480	2780	142,30,177,49	rouge
samsho5	0	INFINITE TIME	10836A	60	temps	f	1120	2420	142,30,177,49	jaune
samsh5sp	0	INFINITE TIME	10836A	60	temps	f	1160	2460	160,32,176,47	jaune
fatfury3	0	INFINITE TIME	105680	60	temps	f	1600	2900	146,16,175,31	jaune
fatfursp	0	INFINITE TIME	10092A	60	temps	f	1350	2650	144,8,176,30	rouge
lastblad	0	INFINITE TIME	10E32B	60	temps	f	1190	2490	144,14,176,31	jaune
aof2	0	INFINITE TIME	108406	60	temps	f	1200	2500	146,16,176,31	brut
wh1	0	INFINITE TIME	10B008	99	temps	f	1240	2540	142,12,177,41	rouge
wh2	0	INFINITE TIME	10C109	99	temps	f	1190	2490	142,16,177,41	clair
svc	0	INFINITE TIME	10AC14	60	temps	f	1270	2570	150,18,168,38	jaune
breakrev	0	INFINITE TIME	107C27	63	temps	f	1120	2420	160,9,176,30	brut
karnovr	0	INFINITE TIME	103A70	63	temps	f	1230	2530	160,14,176,33	brut
doubledr	0	INFINITE TIME	102242	99	temps	f	1140	2440	142,8,176,25	blanc
mslug2	0	INFINITE LIVES	101276	02	vies	s	1500	12000	-	-
mslugx	0	INFINITE LIVES	101288	02	vies	s	1500	12000	-	-
mslug3	0	INFINITE LIVES	1002BB	02	vies	s	1500	12000	-	-
mslug4	0	INFINITE LIVES	100A89	02	vies	s	1500	12000	-	-
mslug5	0	INFINITE LIVES	100A41	02	vies	s	1500	12000	-	-
pulstar	0	INFINITE LIVES	10132A	02	vies	s	1500	12000	-	-
blazstar	0	INFINITE LIVES	101BA1	02	vies	s	1500	12000	-	-
androdun	0	INFINITE LIVES	100343	03	vies	s	1500	12000	-	-
gpilots	0	INFINITE LIVES	103F37	03	vies	s	1500	12000	-	-
lresort	0	INFINITE LIVES	108030	02	vies	s	1500	12000	-	-
maglord	0	INFINITE LIVES	103B00	02	vies	s	1500	12000	-	-
s1945p	0	INFINITE LIVES	1000E9	02	vies	s	1500	12000	-	-
zedblade	0	INFINITE LIVES	100229	03	vies	s	1500	12000	-	-
b2b	0	INFINITE LIVES	106907	04	vies	s	1500	12000	-	-
bjourney	0	INFINITE LIVES	107000	02	vies	s	1500	12000	-	-
ctomaday	0	INFINITE LIVES	104026	02	vies	s	1500	12000	-	-
ganryu	0	INFINITE LIVES	1004A1	03	vies	s	1500	12000	-	-
ncombat	0	INFINITE LIVES	102402	03	vies	s	1500	12000	-	-
neobombe	0	INFINITE LIVES	101658	02	vies	s	1500	12000	-	-
neomrdo	0	INFINITE LIVES	10465B	02	vies	s	1500	12000	-	-
preisle2	0	INFINITE LIVES	105055	03	vies	s	1500	12000	-	-
sengoku2	0	INFINITE LIVES	1001AF	03	vies	s	1500	20000	-	-
sengoku3	0	INFINITE LIVES	1083E1	02	vies	s	1500	12000	-	-
shocktr2	0	INFINITE LIVES	10905B	03	vies	s	1500	12000	-	-
sonicwi2	0	INFINITE LIVES	100615	02	vies	s	1500	12000	-	-
sonicwi3	0	INFINITE LIVES	10E89B	02	vies	s	1500	12000	-	-
spinmast	0	INFINITE LIVES	105015	02	vies	s	1500	12000	-	-
superspy	0	INFINITE LIVES	10181F	08	vies	s	1500	12000	-	-
twinspri	0	INFINITE LIVES	103745	03	vies	s	1500	12000	-	-
viewpoin	0	INFINITE LIVES	108D99	03	vies	s	1500	12000	-	-
zupapa	0	INFINITE LIVES	1002C1	03	vies	s	1500	12000	-	-
kof99	1	P1 INFINITE LIFE	108422	00	vies	f	1600	15000	-	-
karnovr	1	P1 INFINITE LIFE	103A74	0F	vies	f	1600	15000	-	-
kof96	0	P1 INFINITE LIFE	108422	00	vies	f	1600	15000	-	-
ninjamas	0	P1 INFINITE LIFE	100050	D0	vies	f	1600	15000	-	-
rotd	0	P1 INFINITE LIFE	1023E6	10	vies	f	1600	15000	-	-
EOF
)"

# ---- L'image et les romsets (seul sp-s2.sp1 remplacé, comme `matrice.sh`) ----
if [ -z "$IMAGE" ]; then
  IMAGE="$WORK/bios.sp1"; rm -f "$IMAGE"
  BIOS_OBJ="$WORK/obj" "$PAQUET/build/construire.sh" "$SOURCES" "$IMAGE" > "$WORK/construction.log" 2>&1 \
    || { tail -5 "$WORK/construction.log"; echo "construction en échec" >&2; exit 1; }
fi
[ "$(wc -c < "$IMAGE" 2>/dev/null)" -eq 131072 ] 2>/dev/null || { echo "image refusée : $IMAGE" >&2; exit 2; }
EMP="$(shasum -a 256 "$IMAGE" | cut -d' ' -f1)"
R="$WORK/roms"; mkdir -p "$R/img"
if [ "$(cat "$R/.image-sha256" 2>/dev/null)" != "$EMP" ]; then rm -f "$R"/*.zip "$R/.image-sha256"; fi
rm -f "$R/img/sp-s2.sp1"; cp "$IMAGE" "$R/img/sp-s2.sp1"
[ -n "$JEUX" ] || JEUX="$(printf '%s\n' "$TABLE" | cut -f1 | sort -u | tr '\n' ' ')"
for j in $JEUX; do
  d="$R/$j.zip"
  [ -L "$d" ] && { echo "REFUS : $d est un lien symbolique" >&2; exit 1; }
  [ -s "$d" ] && continue
  [ -s "$ROMS/$j.zip" ] || { echo "set introuvable : $ROMS/$j.zip" >&2; exit 2; }
  cp "$ROMS/$j.zip" "$d.part" && ( cd "$R/img" && zip -q -j -X "$d.part" sp-s2.sp1 ) && mv "$d.part" "$d" || exit 1
done
echo "$EMP" > "$R/.image-sha256"
echo "image ${EMP:0:16}…, jeux : $JEUX"

# ---- Les runs : deux par cheat, au plus $JOBS à la fois ----
PIDS=""
attendre_place() {
  local p n=0 reste="" premier=""
  for p in $PIDS; do n=$(( n + 1 )); done
  [ $n -lt "$JOBS" ] && return
  for p in $PIDS; do if [ -z "$premier" ]; then premier=$p; wait "$p"; else reste="$reste $p"; fi; done
  PIDS="$reste"
}
# Les images des runs temps : trois, ou une toutes les 20 trames avec CAT_DENSE=1 (pour choisir le
# rectangle du chronomètre).
images() {
  if [ -n "${CAT_DENSE:-}" ]; then seq -s, $(( $1 + 200 )) 20 $(( $1 + 1200 )); else echo "$(( $1 + 200 )),$(( $1 + 700 )),$(( $1 + 1200 ))"; fi
}
# pixels <genre> : les variables de `cheats.lua` pour la zone (voir la table).
pixels() {
  case "$1" in
    brut) echo "C_SEUIL=0" ;;
    clair) echo "C_SEUIL=600" ;;
    jaune) echo "C_COULEUR=180,255,160,255,0,120" ;;
    blanc) echo "C_COULEUR=180,255,180,255,180,255" ;;
    vert) echo "C_COULEUR=0,120,150,255,0,120" ;;
    rouge) echo "C_COULEUR=180,255,0,80,0,80" ;;
  esac
}
# entrees <f|s> <T> : le plan, coupé de T − 10 à T + 150.
entrees() {
  local T=$1 a=$(( $1 - 10 )) b=$(( $1 + 150 )) out="400-407:piece,500-507:START" x
  case "$2" in
    f) x="600-3500%60:A 2000-40000:droite" ;;
    s) x="600-40000%60:A 1000-40000:droite 1500-40000%400:C" ;;
  esac
  local seg d f r bt
  for seg in $x; do
    d=${seg%%-*}; r=${seg#*-}; f=${r%%[%:]*}; bt=${r#"$f"}
    [ "$d" -lt "$a" ] && out="$out,$d-$(( f < a ? f : a ))$bt"
    [ "$f" -gt "$b" ] && out="$out,$(( d > b ? d : b ))-$f$bt"
  done
  echo "$out"
}
lancer() {
  local nom="$1"; shift
  local jeu="$1"; shift
  local o="$WORK/runs/$nom"
  rm -rf "${o:?}"; mkdir -p "$o"
  attendre_place
  ( cd "$o" && env "$@" C_OUT="$o" C_MODE=menu SDL_VIDEODRIVER=dummy SDL_MAC_BACKGROUND_APP=1 \
      mame "$jeu" -rompath "$R" -bios euro -video none -sound none -nothrottle -seconds_to_run 900 \
      -nvram_directory "$o/nvram" -cfg_directory "$o/cfg" -skip_gameinfo \
      -autoboot_script "$ICI/cheats.lua" > "$o/mame.log" 2>&1
    echo $? > "$o/rc" ) &
  PIDS="$PIDS $!"
}
T0=$(date +%s)
while IFS=$'\t' read -r jeu k nom adr val genre ent T FIN zone seuil; do
  case " $JEUX " in *" $jeu "*) ;; *) continue ;; esac
  E="$(entrees "$T" "$ent")"
  # Les appuis du menu (`menu.s`) : le cheat k est la ligne 2 + k ; « bas » 2 + k fois, A, puis
  # « haut » 2 + k fois jusqu'à RESUME, A. Le témoin : A sur RESUME.
  on="" n=$(( T + 45 ))
  for i in $(seq 0 $(( k + 1 ))); do on="$on$n:bas,"; n=$(( n + 6 )); done
  on="$on$n:A,"; n=$(( n + 6 ))
  for i in $(seq 0 $(( k + 1 ))); do on="$on$n:haut,"; n=$(( n + 6 )); done
  on="$on$n:A"
  Z=""; [ "$zone" != "-" ] && Z="C_ZONE=$zone $(pixels "$seuil") C_IMAGES=$(images "$T")"
  lancer "$jeu-$k-on" "$jeu" C_ENTREES="$E" C_MENU="$T" C_APPUIS="$on" C_SUIVRE="$adr:1,10FDAF:1" C_FIN="$FIN" C_PAS=10 ${Z:+$Z}
  lancer "$jeu-$k-temoin" "$jeu" C_ENTREES="$E" C_MENU="$T" C_APPUIS="$(( T + 45 )):A" C_SUIVRE="$adr:1,10FDAF:1" C_FIN="$FIN" C_PAS=10 ${Z:+$Z}
done < <(printf '%s\n' "$TABLE" | sort -t$'\t' -k9,9nr)
wait
echo "runs : $(( $(date +%s) - T0 )) s"

# ---- Le juge ----
printf '%s\n' "$TABLE" > "$WORK/table.tsv"
python3 -I -B - "$WORK/runs" "$JEUX" "$TEMPS_ON_MIN" "$TEMPS_TEMOIN_MAX" "$RAM_MIN" "$WORK/table.tsv" > "$WORK/catalogue.txt" <<'PY'
import os, re, sys
RUNS, JEUX = sys.argv[1], sys.argv[2].split()
ON_MIN, TEM_MAX, RAM_MIN = float(sys.argv[3]), float(sys.argv[4]), float(sys.argv[5])
def lire(nom):
    d = os.path.join(RUNS, nom)
    rc = open(os.path.join(d, "rc")).read().strip()
    log = open(os.path.join(d, "mame.log"), errors="replace").read()
    j = {"rc": rc, "wrong": "WRONG CHECKSUMS" in log, "zone": {}, "val": {}, "user": {}, "ecrits": None, "entete": None}
    for l in open(os.path.join(d, "cheats.txt"), errors="replace"):
        m = re.match(r"f(\d+) (.*)", l.strip())
        if not m: continue
        n, r = int(m[1]), m[2]
        if r.startswith("zone="): j["zone"][n] = r[5:]
        elif r.startswith("ngh="): j["entete"] = r
        elif r.startswith("ecritures du moteur"):
            mm = re.match(r"ecritures du moteur : (\d+) (.*) ; pile", r)
            j["ecrits"] = (int(mm[1]), mm[2].split()) if mm else (0, [])
        else:
            for k, v in re.findall(r"([0-9A-F]{6})=([0-9A-F]+)", r):
                (j["user"] if k == "10FDAF" else j["val"]).setdefault(n, int(v, 16))
    return j
echecs = 0
for l in open(sys.argv[6], encoding="utf-8"):
    if not l.strip(): continue
    jeu, k, nom, adr, val, genre, ent, T, FIN, zone, seuil = l.rstrip("\n").split("\t")
    if jeu not in JEUX: continue
    T, FIN, val = int(T), int(FIN), int(val, 16)
    raison, dit = [], []
    try:
        on, te = lire(f"{jeu}-{k}-on"), lire(f"{jeu}-{k}-temoin")
        for x, nm in ((on, "on"), (te, "témoin")):
            if x["rc"] != "0": raison.append(f"{nm} : MAME sorti en {x['rc']}")
            if not x["wrong"]: raison.append(f"{nm} : pas de WRONG CHECKSUMS")
        ne, adrs = on["ecrits"] or (0, [])
        dit.append(f"{on['entete']} ; moteur : {ne} écritures {' '.join(adrs)} ; témoin {te['ecrits'][0] if te['ecrits'] else '?'}")
        # Le tap voit le bus 16 bits : un octet écrit est relevé à l'adresse paire de son mot.
        if not adrs or any(int(a.split("x")[0], 16) != int(adr, 16) & ~1 for a in adrs): raison.append(f"le moteur a écrit {adrs}, {adr} seule attendue")
        if te["ecrits"] and te["ecrits"][0]: raison.append("le moteur a écrit au témoin")
        fen = range(T + 200, T + 801)
        vals = [on["val"][n] for n in fen if n in on["val"]]
        # Relue en fin de trame, une cellule forcée peut porter ce que le jeu vient d'en ôter (un
        # décompte d'une trame) avant que le moteur la rétablisse au SYSTEM_IO suivant.
        ram = sum(1 for v in vals if val - 1 <= v <= val) / max(1, len(vals))
        if genre == "temps":
            def dominante(x):
                z = [x["zone"][n] for n in fen if n in x["zone"]]
                return max(z.count(v) for v in set(z)) / len(z), len(set(z))
            (fo, no), (ft, nt) = dominante(on), dominante(te)
            dit.append(f"chronomètre : son image la plus fréquente sur {fo:.2f} des relevés sous cheat ({no} images), {ft:.2f} au témoin ({nt}) ; ${adr} à ${val:02X} sur {ram:.2f}")
            if fo < ON_MIN: raison.append(f"le chronomètre sous cheat n'a son image la plus fréquente que sur {fo:.2f} des relevés")
            if ft > TEM_MAX: raison.append(f"le témoin garde la même image sur {ft:.2f} des relevés : la scène ne prouve rien")
        else:
            fin_t = [n for n in sorted(te["user"]) if n > T and te["user"][n] != 2]
            fin_o = [n for n in sorted(on["user"]) if n > T and on["user"][n] != 2]
            dit.append(f"fin de partie : témoin {fin_t[0] if fin_t else 'aucune'}, sous cheat {fin_o[0] if fin_o else 'aucune'} (FIN {FIN}) ; ${adr} à ${val:02X} sur {ram:.2f}")
            if not fin_t: raison.append("le témoin ne perd pas la partie : la scène ne prouve rien")
            if fin_o: raison.append(f"fin de partie sous cheat à {fin_o[0]}")
        if ram < RAM_MIN: raison.append(f"la cellule à la valeur sur {ram:.2f} des relevés")
    except Exception as e:
        raison.append(f"{type(e).__name__} : {e}")
    v = "FAIL" if raison else "PASS"
    echecs += bool(raison)
    print(f"{v}  {jeu} {nom}" + (f" — {'; '.join(raison)}" if raison else ""))
    for d in dit: print("      " + d)
sys.exit(1 if echecs else 0)
PY
rc=$?
cat "$WORK/catalogue.txt"
echo "en tout $(( $(date +%s) - T0 )) s ; travail : $WORK"
[ $rc -eq 0 ] && echo "CATALOGUE : PASS" || echo "CATALOGUE : FAIL"
exit $rc
