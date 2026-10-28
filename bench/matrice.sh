#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Thibaut Lion
# Matrice de compatibilité : chaque jeu, sous chaque BIOS, sans fenêtre.
#
#   bench/matrice.sh <dossier-roms> <dossier-travail>
#
# Réglages par l'environnement :
#   BIOS_NULLBIOS  zip contenant sp-s2.sp1, le nullbios (obligatoire sans BIOS_SANS_NULLBIOS=1)
#   BIOS_SANS_NULLBIOS  1 : pas de colonne nullbios. Elle n'est qu'un repère tiers, et ses runs
#                  lents (54 à 63 % de vitesse sur garou, kof98, kof2003, mslug3) pèsent 70 % du
#                  temps émulé d'une matrice à quatre colonnes — calculé depuis les vitesses de
#                  measured/2026-10-22-matrice-durcissement.tsv, pas chronométré.
#   BIOS_VARIANTES BIOS supplémentaires à comparer, « nom=chemin » séparés par des espaces.
#                  Le chemin est soit une image 68000 brute de 128 Kio, soit un zip qui contient
#                  un membre sp-s2.sp1. Exemple :
#                    BIOS_VARIANTES="neopen=$HOME/neopen.sp1 neogeo-bios=$HOME/build/sp-s2.sp1"
#                  Les noms `snk`, `unibios40` et `nullbios` sont réservés, et un chemin contenant
#                  une espace n'est pas supporté — la liste se découpe sur les blancs.
#   BIOS_JEUX      sets à mesurer, séparés par des espaces (défaut : tous les *.zip du dossier)
#   BIOS_SECONDES  durée émulée par run (défaut 62, soit ~3 720 trames)
#   BIOS_SHOTS     trames de relevé (défaut : toutes les 100 jusqu'à 3 500)
#   BIOS_IMAGES    trames dont l'image est écrite (défaut 3500)
#   BIOS_REF       jeu de BIOS SNK de la colonne `snk`, nom MAME (défaut euro ; japan, us…).
#                  Les variantes restent sous `-bios euro` : c'est le membre sp-s2.sp1 du set
#                  euro qu'elles remplacent, et leur région est la leur, pas celle-ci.
#   BIOS_CACHE     dossier où garder les runs des colonnes snk et unibios40, et d'où les reprendre :
#                  ils ne dépendent d'aucune image à l'essai. La clé couvre MAME (version et
#                  configuration effective, `-showconfig`), ce script, bios-probe.lua, le jour (la
#                  machine prend la date de l'hôte), le jeu, son romset et neogeo.zip (nom, taille,
#                  date à la seconde), le BIOS et les réglages BIOS_SECONDES, BIOS_SHOTS, BIOS_IMAGES.
#                  Seul un run sorti en 0, commencé et fini le même jour, est gardé. La colonne
#                  vitesse_pct d'un run repris est celle du run d'origine (relevée, jamais jugée)
#
# AUCUNE ROM N'EST VERSIONNÉE dans ce dépôt, ni BIOS ni jeu. Le dossier de ROMs est à toi.
#
# TROIS PIÈGES, tous payés pendant l'écriture de ce banc :
#
#  1. LES ZIPS DE JEUX SONT NON-MERGED : chacun embarque sa PROPRE copie complète du set BIOS.
#     MAME regarde le zip du jeu AVANT neogeo.zip, donc substituer dans neogeo.zip ne fait RIEN.
#     Un BIOS entièrement à zéro a produit un run identique au vrai avant qu'on s'en aperçoive.
#     La substitution se fait donc DANS le zip du jeu, ce que fait ce script.
#  2. MAME accepte un BIOS au mauvais CRC en affichant « WRONG CHECKSUMS … the machine might not
#     run correctly ». Cette ligne dans le journal est la PREUVE que la substitution est active ;
#     son absence veut dire que MAME a trouvé le vrai BIOS ailleurs.
#  3. NE JAMAIS ÉCRIRE À TRAVERS UN LIEN SYMBOLIQUE. Une première version liait les ROMs de
#     l'utilisateur dans le dossier de travail puis ouvrait ces chemins en écriture : elle a
#     tronqué un romset à 22 octets. Ce script copie, et refuse d'écrire sur un lien.
set -eu

ROMS="${1:?dossier des romsets attendu}"
WORK="${2:?dossier de travail attendu}"
ICI="$(cd "$(dirname "$0")" && pwd)"
# Tout chemin devient absolu AVANT le premier sous-shell : plus bas, chaque run fait un `cd`, et
# un chemin relatif s'y résoudrait depuis le nouveau répertoire — c'est-à-dire, pour les variantes
# non substituées, dans le dossier de ROMs de l'utilisateur.
mkdir -p "$WORK"
ROMS="$(cd "$ROMS" && pwd)"
WORK="$(cd "$WORK" && pwd)"
NULLBIOS="${BIOS_NULLBIOS:-}"
AUTRES="${BIOS_VARIANTES:-}"
SECONDES="${BIOS_SECONDES:-62}"
SHOTS="${BIOS_SHOTS:-$(seq -s, 100 100 3500)}"
IMAGES="${BIOS_IMAGES:-3500}"
REF="${BIOS_REF:-euro}"
case "$REF" in ''|*[!a-z0-9-]*) echo "BIOS_REF refusé : $REF"; exit 1 ;; esac

command -v mame >/dev/null || { echo "mame introuvable"; exit 1; }
# Un nom inconnu de MAME le fait retomber sur le BIOS par défaut, sans erreur ni « WRONG
# CHECKSUMS » : la colonne `snk` mesurerait l'Europe sous le nom d'une autre région. On le
# confronte donc à la liste que MAME publie lui-même.
mame -listbios neogeo 2>/dev/null | awk 'NR > 1 {print $1}' | grep -qx -- "$REF" \
  || { echo "BIOS_REF inconnu de MAME pour neogeo : $REF"; exit 1; }
# `rm -f` avant chaque écriture : il supprime un éventuel lien symbolique au lieu d'écrire à
# travers lui. C'est la même précaution que le refus plus bas, appliquée aux images de BIOS.
mkdir -p "$WORK/M"
if [ "${BIOS_SANS_NULLBIOS:-0}" = 1 ]; then
  VARIANTES=""
else
  [ -n "$NULLBIOS" ] || { echo "BIOS_NULLBIOS attendu (zip contenant sp-s2.sp1), ou BIOS_SANS_NULLBIOS=1"; exit 1; }
  mkdir -p "$WORK/img/nullbios"
  rm -f "$WORK/img/nullbios/sp-s2.sp1"
  unzip -p "$NULLBIOS" sp-s2.sp1 > "$WORK/img/nullbios/sp-s2.sp1"
  VARIANTES="nullbios"
fi

# Chaque variante de BIOS_VARIANTES est déposée sous le même nom de membre, sp-s2.sp1, puisque c'est
# ce fichier que `-bios euro` fait charger à MAME. Un zip est accepté aussi bien qu'une image nue :
# les projets tiers livrent tantôt l'un, tantôt l'autre, et exiger un format ferait recopier à la
# main ce que deux lignes font ici.
for paire in $AUTRES; do
  case "$paire" in *=*) ;; *) echo "variante mal formée, « nom=chemin » attendu : $paire"; exit 1 ;; esac
  nom="${paire%%=*}"; src="${paire#*=}"
  # Jeu de caractères restreint, plutôt qu'une comparaison insensible à la casse : le nom devient un
  # composant de chemin, et le système de fichiers de macOS ignore la casse. `NullBIOS` passerait
  # donc les contrôles ci-dessous tout en désignant le MÊME dossier que `nullbios`, dont il
  # écraserait l'image — deux lignes de matrice mesurant le même BIOS, chacune avec `controle=ok`.
  case "$nom" in ''|.|..|*[!a-z0-9._-]*) echo "nom de variante refusé : $nom"; exit 1 ;; esac
  # NOMS RÉSERVÉS. `snk` et `unibios40` désignent les BIOS d'origine dans la boucle de mesure plus
  # bas : une variante ainsi nommée y serait prise pour eux, mesurée SANS substitution, et sortirait
  # `controle=ok`. C'est l'invariant du paquet contourné par le nom. `nullbios` est déjà pris.
  case " snk unibios40 nullbios " in *" $nom "*) echo "nom de variante réservé : $nom"; exit 1 ;; esac
  case " $VARIANTES " in *" $nom "*) echo "variante en double : $nom"; exit 1 ;; esac
  [ -s "$src" ] || { echo "image introuvable pour $nom : $src"; exit 1; }
  mkdir -p "$WORK/img/$nom"
  rm -f "$WORK/img/$nom/sp-s2.sp1"
  if unzip -l "$src" >/dev/null 2>&1; then
    unzip -p "$src" sp-s2.sp1 > "$WORK/img/$nom/sp-s2.sp1"
  else
    cp "$src" "$WORK/img/$nom/sp-s2.sp1"
  fi
  taille=$(wc -c < "$WORK/img/$nom/sp-s2.sp1")
  [ "$taille" -eq 131072 ] || { echo "$nom : image de $taille octets, 131072 attendus"; exit 1; }
  VARIANTES="$VARIANTES $nom"
done

JEUX="${BIOS_JEUX:-$(cd "$ROMS" && ls *.zip 2>/dev/null | sed 's/\.zip$//' | tr '\n' ' ')}"
[ -n "$JEUX" ] || { echo "aucun jeu dans $ROMS"; exit 1; }
for g in $JEUX; do
  case "$g" in */*|..*) echo "nom de set refusé : $g"; exit 1 ;; esac
  # Vérifié ici plutôt que découvert plus bas : sans ce contrôle, un set absent sortait une erreur
  # de `cp` au milieu de la fabrication des variantes, loin de sa cause.
  [ -s "$ROMS/$g.zip" ] || { echo "set introuvable : $ROMS/$g.zip"; exit 1; }
done

# Un romset par variante, obtenu en remplaçant le seul membre sp-s2.sp1 d'une COPIE du zip du jeu.
#
# DEUX PRÉCAUTIONS, et elles gardent toutes deux contre le même accident : mesurer un BIOS en
# croyant en mesurer un autre, sans aucun message.
#
#  - un romset déjà présent n'est réutilisé que si l'empreinte de l'image injectée est la MÊME.
#    Sans ce contrôle, changer BIOS_NULLBIOS ou BIOS_VARIANTES entre deux runs dans le même dossier
#    de travail laissait l'ancienne image en place et la matrice mesurait le BIOS précédent ;
#  - la fabrication passe par un fichier temporaire renommé seulement après un `zip` réussi. Une
#    interruption entre la copie et le `zip` laissait sinon un romset portant le BIOS SNK
#    d'origine, que le run suivant acceptait comme s'il était substitué.
for v in $VARIANTES; do
  mkdir -p "$WORK/v-$v"
  empreinte="$(shasum -a 256 "$WORK/img/$v/sp-s2.sp1" | cut -d' ' -f1)"
  marqueur="$WORK/v-$v/.image-sha256"
  # Un marqueur périmé (ou lien) tombe AVANT de refaire les romsets : interrompu en route, il ne les attesterait plus.
  { [ ! -L "$marqueur" ] && [ "$(cat "$marqueur" 2>/dev/null)" = "$empreinte" ]; } || rm -f "$marqueur"
  for g in $JEUX; do
    d="$WORK/v-$v/$g.zip"
    [ -L "$d" ] && { echo "REFUS : $d est un lien symbolique"; exit 1; }
    if [ -s "$d" ] && [ "$(cat "$marqueur" 2>/dev/null)" = "$empreinte" ]; then continue; fi
    rm -f "$d.part"
    cp "$ROMS/$g.zip" "$d.part"
    ( cd "$WORK/img/$v" && zip -q -j -X "$d.part" sp-s2.sp1 )
    mv "$d.part" "$d"
  done
  # Le marqueur n'est posé qu'une fois TOUS les romsets de la variante fabriqués : interrompu
  # avant, le run suivant les refait tous plutôt que d'en accepter un au hasard.
  echo "$empreinte" > "$marqueur"
done

CACHE="${BIOS_CACHE:-}"
if [ -n "$CACHE" ]; then
  mkdir -p "$CACHE"; CACHE="$(cd "$CACHE" && pwd)"
  empreinte_fichiers() { stat -L -f '%N %z %m' "$@" 2>/dev/null || stat -L -c '%n %s %Y' "$@"; }
  CLE_BASE="$( { mame -version; mame -showconfig; cat "$ICI/matrice.sh" "$ICI/bios-probe.lua"; \
    empreinte_fichiers "$ROMS/neogeo.zip"; echo "$SECONDES $SHOTS $IMAGES"; } 2>&1 | shasum -a 256 | cut -d' ' -f1)"
fi

printf '%s\t%s\t%s\t%s\t%s\t%s\n' jeu bios verdict vifs_max vitesse_pct controle
for g in $JEUX; do
  for v in snk unibios40 $VARIANTES; do
    case "$v" in
      snk)       RP="$ROMS"; B="$REF" ;;
      unibios40) RP="$ROMS"; B=unibios40 ;;
      *)         RP="$WORK/v-$v"; B=euro ;;
    esac
    O="$WORK/M/$g-$v"; rm -rf "$O"; mkdir -p "$O"
    rc=0
    cle=""
    jour="$(date '+%Y-%m-%d')"
    case "$v" in snk|unibios40)
      if [ -n "$CACHE" ]; then
        cle="$( { echo "$CLE_BASE $jour $g $v $B"; empreinte_fichiers "$ROMS/$g.zip"; } | shasum -a 256 | cut -c1-32)"
      fi ;;
    esac
    if [ -n "$cle" ] && [ -s "$CACHE/$cle/rc" ]; then
      rm -rf "$O"; cp -R "$CACHE/$cle" "$O"; rc=$(cat "$O/rc")
    else
    # NVRAM isolée par run ($O est neuf) : sans cela, MAME partage son dossier nvram/<jeu>/
    # entre tous les runs du même jeu, BIOS confondus — un crédit laissé par un run se relit
    # sous le suivant, et le déterminisme annoncé plus haut ne tient plus dès qu'un BIOS crédite.
    # SDL_MAC_BACKGROUND_APP : sans lui, chaque run passe au premier plan sur macOS, même sans fenêtre.
    # cfg isolé de même : sans -cfg_directory, MAME réécrit à sa sortie les cfg du dossier de
    # l'utilisateur (son mame.ini en fixe un, absolu), réglages des touches compris.
    ( cd "$WORK" && SDL_VIDEODRIVER=dummy SDL_MAC_BACKGROUND_APP=1 BIOS_OUT="$O" BIOS_SHOTS="$SHOTS" BIOS_IMAGES="$IMAGES" \
      mame "$g" -rompath "$RP" -video none -sound none -nothrottle -seconds_to_run "$SECONDES" \
      -nvram_directory "$O/nvram" -cfg_directory "$O/cfg" \
      -skip_gameinfo -bios "$B" -autoboot_script "$ICI/bios-probe.lua" >"$O/mame.log" 2>&1 ) || rc=$?
    echo "$rc" > "$O/rc"
    # Gardé par une copie renommée d'un coup, comme `parcours.sh` : jamais d'entrée à moitié écrite.
    if [ -n "$cle" ] && [ "$rc" -eq 0 ] && [ ! -e "$CACHE/$cle" ] && [ "$(date '+%Y-%m-%d')" = "$jour" ]; then
      t="$CACHE/.$cle.$$"
      # Une écriture de cache qui échoue ne fait pas échouer la matrice (set -e).
      if mkdir "$CACHE/.$cle.verrou" 2>/dev/null && cp -R "$O" "$t"; then mv "$t" "$CACHE/$cle" || true; fi; rm -rf "$t"
    fi
    fi

    # LA PREUVE QUE LA SUBSTITUTION A PRIS, lue à chaque run plutôt que supposée. MAME signale
    # « WRONG CHECKSUMS » quand l'image de BIOS ne correspond pas au CRC qu'il attend : cette ligne
    # doit donc être présente pour une variante, et absente pour un BIOS d'origine. Sans ce
    # contrôle, une substitution muette faisait mesurer le BIOS SNK sous le nom d'une variante —
    # exactement l'accident que les gardes de fabrication ferment en amont, laissé ouvert en aval.
    controle=ok
    case "$v" in
      snk|unibios40) grep -q 'WRONG CHECKSUMS' "$O/mame.log" && controle='ALERTE:crc-inattendu' ;;
      *)             grep -q 'WRONG CHECKSUMS' "$O/mame.log" || controle='ALERTE:substitution-absente' ;;
    esac
    [ "$rc" -ne 0 ] && controle="ALERTE:mame-exit-$rc"
    [ -s "$O/index.txt" ] || controle='ALERTE:aucun-releve'

    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$g" "$v" \
      "$("$ICI/verdict.sh" "$O/index.txt")" \
      "$(grep -ao 'vifs=[0-9]*' "$O/index.txt" 2>/dev/null | cut -d= -f2 | sort -n | tail -1)" \
      "$(grep -ao 'Average speed: [0-9.]*' "$O/mame.log" | tail -1 | awk '{print $3}')" \
      "$controle"
  done
done
