#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Thibaut Lion
"""Génère les contrats d'appel du BIOS depuis une trace de bus du banc de co-simulation.

    ./bench/generer-contrats.py <trace.txt> [<trace2.txt> ...] <dossier-de-sortie> [--boot]
    ./bench/generer-contrats.py <trace.txt> [<trace2.txt> ...] <dossier-de-sortie> --protocole=<site,...>
    ./bench/generer-contrats.py <trace.txt> --part-prom

C'est I2 de `docs/tasks.md` : le document qu'un agent d'implémentation reçoit, et le seul, avec la
documentation publique (`docs/DECISIONS.md` §1). Il est **généré, jamais écrit à la main** — c'est
ce qui garde la salle blanche praticable : on ne recopie le code de personne, on relit une trace.

CE QU'IL NE NOMME PAS. Un appel est désigné par l'offset de son point d'entrée dans la ROM du
BIOS, jamais par un nom de fonction : la correspondance offset → nom est de la documentation
publique, elle vit ailleurs, et la mêler ici ferait entrer une source non vérifiable dans le
contrat.

CE QU'IL NE PORTE PAS, et c'est `DECISIONS.md` §8 : les valeurs lues dans la ROM du BIOS n'entrent
pas dans un contrat, une suite de mots lue là étant une table de données SNK et non un
comportement. Le générateur ne décide pas tout seul de quel côté tombe une valeur — ce critère
n'est pas automatisable (§8) —, il **signale** les séquences qui y ressemblent pour que la
relecture appel par appel tranche avant de remettre le contrat.

DÉTERMINISME. Deux passages sur la même trace rendent les mêmes octets : aucune date, aucun chemin
absolu, aucun parcours de dictionnaire non trié n'entre dans la sortie. C'est le critère
d'acceptation de I2.
"""

import bisect
import os
import sys

# La carte mémoire, telle que le co-simulateur (non publié) la câble.
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

# Un transfert d'au moins ce nombre de mots consécutifs lus dans la ROM est signalé comme une table
# possible. Quatre et non un : un mot isolé lu dans la ROM est le lot courant d'un code qui lit ses
# constantes, et tout signaler reviendrait à ne rien signaler.
SEUIL_SEQUENCE = 4

# LA TABLE DE SAUTS PUBLIQUE, bornes et pas : $C00402 à $C006FC, une entrée tous les 6 octets.
# La page « BIOS calls » du NeoGeo Development Wiki la donne, et c'est ce qui en fait de la
# documentation publique au sens de `DECISIONS.md` §8 : les points d'entrée y sont admis, les
# adresses internes du code non.
TABLE_SAUTS = (0xC00402, 0xC006FC, 6)

# Les mots hauts d'un long qui pointerait dans la ROM du BIOS : $C00000-$C1FFFF donne $00C0, $00C1.
MOTS_HAUTS_ROM = {f"{h:04X}" for h in range(ROM_BIOS[0] >> 16, (ROM_BIOS[1] >> 16) + 1)}


def grouper(paires):
    """Les plages contiguës de même valeur, pour qu'un contrat se lise.

    Un vidage de RAM rend des centaines d'adresses portant la même valeur : listées une par une,
    elles noient les quelques valeurs qui font le contrat. On les regroupe quand l'adresse avance
    **du pas de la valeur** et que celle-ci ne change pas.

    LE PAS SUIT LA LARGEUR, et ce n'est pas un détail : un pas de 2 admis sur des octets ferait
    fusionner `$10FD80` et `$10FD82` en une plage, alors que `$10FD81` n'a jamais été écrit — la
    plage affirmerait une écriture qui n'a pas eu lieu. Un mot avance donc de 2, un octet de 1.

    Une valeur de mot et une valeur d'octet ne fusionnent jamais, même numériquement égales :
    `$0000` et `$00` sont des chaînes différentes, et la largeur de l'écriture fait partie du
    comportement à reproduire.

    Rend des triplets `(début, fin, valeur)`, `fin` valant `début` sur une plage d'une adresse.
    L'entrée doit être triée par adresse."""
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
    """L'octet qu'un remplissage répète, ou `None` si cette valeur n'en est pas un.

    COMPARER LES VALEURS TELLES QUELLES NE RECONNAÎT PAS UN REMPLISSAGE. Une boucle de vidage en
    `clr.l` écrit des mots `$0000`, et un `move.b` isolé un octet `$00` : ce sont deux chaînes
    différentes pour le même remplissage à zéro. Mesuré sur la couche 0 — un seul site `$00` parmi
    389 `$0000` suffisait à faire taire le garde du remplissage. Et le `$5555` du test mémoire de
    SNK est le même remplissage que `$55`.

    On normalise donc un mot dont les deux octets sont égaux sur cet octet. Un mot dont ils
    diffèrent n'est pas un remplissage, et rend `None`."""
    if len(valeur) == 2:
        return valeur
    return valeur[:2] if valeur[:2] == valeur[2:] else None


def site_écrit(adresse, ul):
    """L'adresse qu'une écriture désigne, corrigée du décalage de l'octet impair.

    Le banc journalise l'adresse de **mot** et les deux strobes : `U.` est UDS
    seul, donc l'octet pair, et `.L` est LDS seul, donc l'impair. Sans cette correction, une
    écriture d'octet sur `$3A0003` se lirait `$3A0002` — un autre registre du HC259 — et `$10FD83`,
    le code pays, se confondrait avec `$10FD82`, le type de machine.

    CE N'EST PAS UN COMPTE D'OCTETS, et il ne faut pas le lire comme tel. Une écriture de mot rend
    son adresse paire et touche deux octets : le site `$10FDA2` de valeur `$0000` dit que les deux
    le sont. Compter les octets touchés donnerait 86 sites là où ce découpage en rend 58, sur les
    sept appels à `$C0044A` — mais un site porte sa largeur dans sa valeur, et la largeur fait
    partie du comportement à reproduire. Fondre un mot en deux octets la perdrait."""
    return adresse + 1 if ul == ".L" else adresse


def valeur_écrite(ul, donnée):
    """La valeur écrite, dépouillée de la duplication du bus.

    UNE ÉCRITURE D'OCTET POSE LA DONNÉE SUR LES DEUX MOITIÉS DU BUS, mesuré le 2026-10-11 sur la
    couche 0 : un `$80` vers `$10FD82` sort `8080`, un `$01` vers `$10FDAF` sort `0101`. Lire les
    seize bits rendrait donc une valeur fausse d'un facteur 257. Le strobe dit quelle moitié est
    la bonne, et c'est celle qu'il sélectionne.

    LÈVE sur un strobe `..`, qui n'a rien transféré : les appelants écartent ces accès à la
    collecte, et lever plutôt que rendre `None` fait qu'un appelant oublié casse franchement au
    lieu de produire un contrat avec un trou.

    Cette fonction ne voit jamais de lecture, et le banc ne pose aucune donnée sur le bus pour une
    lecture : **0 ligne non nulle sur 1 793 296 lectures**, mesuré sur les quatre traces du lot —
    279 352, 314 093, 397 666 et 802 185. Une valeur lue n'a donc pas de valeur observable.

    CELA NE SUFFIT PAS À TENIR §8, et l'avoir cru a coûté un tour de review : une valeur lue puis
    **empilée ou recopiée** ressort dans la donnée d'une écriture. C'est ce que fait un `jsr`
    interne au BIOS avec son adresse de retour, et c'est `valeurs_dérivées_du_pc` qui l'arrête."""
    d = int(donnée, 16)
    if ul == "UL":
        return f"{d:04X}"
    if ul == "U.":
        return f"{(d >> 8) & 0xFF:02X}"
    if ul == ".L":
        return f"{d & 0xFF:02X}"
    raise ValueError(f"strobe sans transfert : {ul!r}")


def zone(adresse):
    """La zone de la carte qui porte cette adresse, ou None hors carte.

    Quand deux plages se recouvrent — `controle_hc259` est inclus dans `registres_systeme` — c'est
    la plus **étroite** qui gagne, pas la première de la liste : l'ordre de `ZONES` n'entre pas."""
    trouvee = None
    for nom, bas, haut in ZONES:
        if bas <= adresse <= haut and (trouvee is None or (haut - bas) < trouvee[1]):
            trouvee = (nom, haut - bas)
    return trouvee[0] if trouvee else None


def lire_trace(chemin):
    """Les accès de la trace, dans l'ordre. Une ligne vaut
    `période adresse rd|WR UL donnée espace` — le format du co-simulateur (non publié). Les lignes qui n'ont
    pas cette forme sont les en-têtes et les avertissements de verilator : on les passe."""
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
    """Les cadres d'appel reconstruits autour de l'entrée, du plus probable au moins probable.

    POURQUOI LA TRANSITION D'ESPACE PROGRAMME NE SUFFIT PAS À FERMER UN APPEL. Elle ferme à la
    sortie suivante de la ROM du BIOS, ce qui est juste quand l'appelant reprend aussitôt — un jeu
    qui tourne. Mais un gestionnaire d'interruption rend la main **dans** le BIOS, par un `rte` :
    aucune transition ne le marque. Mesuré sur la fenêtre 330-338, où le BIOS attend, les appels à
    `$C00438` étaient délimités à 46 769-46 778 accès, soit 0,9997 à 0,9998 trame, au lieu de
    1 835-1 847.

    UN CADRE ÉCRIT APRÈS L'ENTRÉE NE PEUT APPARTENIR QU'À CET APPEL : rien d'autre n'a tourné
    entre-temps. Un cadre écrit avant peut être celui d'un appel plus ancien, encore vivant sur la
    pile. D'où l'ordre : d'abord les cadres complétés à l'entrée ou après, du plus proche ; puis
    ceux d'avant, du plus proche. Sans cette distinction, une sous-routine du jeu qui appelle le
    BIOS fait fermer l'appel sur **son** retour à elle, et le contrat attribue au BIOS une écriture
    du jeu — mesuré sur une trace fabriquée, et c'est le test `UneSousRoutineDuJeu`.

    ON NE CHOISIT PAS, ON PROPOSE : c'est `découper` qui retient le premier candidat auquel le PC
    revient vraiment. Une paire de mots nuls reconstruit `$000000`, où le PC ne va jamais.

    IL N'Y A JAMAIS PLUS D'UN CANDIDAT APRÈS L'ENTRÉE **sur une entrée de la table de sauts**, et
    c'est par construction : le `jmp.l` qui occupe le cran consomme les fetches +1 à +3, donc les
    seules écritures qui tombent dans la fenêtre postérieure sont les empilements du `jsr` qui vient
    d'entrer. Un appel imbriqué doit laisser le BIOS exécuter quelques instructions avant son propre
    `jsr`, et son cadre sort de la fenêtre. Hors de la table l'argument ne tient pas, mais
    `point_entrée_public` écarte ces entrées avant qu'un contrat s'écrive.

    Mesuré en appui, non en preuve : aucune des 51 entrées des quatre traces du lot n'a deux
    candidats postérieurs. L'ordre relatif de ces candidats ne décide donc jamais de rien, et une
    mutation qui l'inverse est sans effet — ce n'est pas un trou de couverture.

    L'ORDRE DES ÉCRITURES N'EST PAS CELUI DES ADRESSES : le 68000 empile le PC bas, puis SR, puis le
    PC haut. On reconstruit donc par adresse, et un cadre est « complété » à la plus tardive de ses
    deux écritures.

    LA FENÊTRE EST CALIBRÉE SUR CE QUE LE MATÉRIEL FAIT, et sa marge est mince. Mesuré : un `jsr`
    empile à +1 et +2 accès de l'entrée ; une exception empile à -15, -13 et -12, les fetches du
    stub de cartouche qui suit le vecteur comptant pour l'essentiel de l'écart. Un stub plus long
    de six fetches sortirait le cadre de la fenêtre, et `découper` retomberait sur l'ancienne
    borne — il le **dit** alors sur `stderr`, au lieu de la reprendre en silence."""
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
    """Les appels du BIOS : entrée par transition d'espace programme, sortie au retour à l'appelant.

    L'entrée est un fetch dans la ROM du BIOS qui suit un fetch hors d'elle. La **sortie** est le
    moment où le PC atteint l'adresse de retour qu'un cadre de `retour_de_l_appelant` annonce, le
    premier candidat qui se vérifie l'emportant.

    À DÉFAUT DE CANDIDAT VÉRIFIÉ, repli sur la première sortie de la ROM du BIOS — l'ancien critère,
    juste quand l'appelant reprend aussitôt. Le repli **se signale sur `stderr`** : il reprend une
    borne qui peut valoir une trame entière, et le taire laisserait croire à une mesure fine.

    Un appel laissé ouvert en fin de trace est écarté : sa surface serait tronquée."""
    bios = lambda a: ROM_BIOS[0] <= a <= ROM_BIOS[1]
    prog = [(i, a) for i, (_, a, _, _, _, e) in enumerate(accès) if e == "sp"]

    # Les positions de chaque adresse dans le flux de fetches, pour chercher par dichotomie au lieu
    # de reparcourir depuis le début : la recherche naïve était quadratique, 1,1 s sur 3,2 M
    # d'accès contre 0,06 s sur 0,4 M.
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
            # `repli` dit COMMENT l'appel s'est fermé, et le protocole en dépend : un appel fermé
            # par repli n'a pas de cadre, donc son point de sortie n'est pas un retour de `jsr` —
            # c'est la signature d'une entrée par `jmp`, qui rend la main par un autre `jmp`.
            appels.append({"entrée": entrée, "de": i, "à": fin_,
                           "période": accès[i][0], "retour": retour, "repli": par_repli})
    if replis:
        print(f"{replis} appel(s) fermé(s) par repli : aucun cadre d'appel reconstructible dans la "
              f"fenêtre, la borne est celle de la sortie de la ROM du BIOS et peut valoir une trame "
              f"entière.", file=sys.stderr)
    return appels
def point_entrée_public(adresse):
    """Vrai si cette adresse est un cran de la table de sauts publique.

    POURQUOI CE FILTRE. `découper` tient pour « entrée » toute transition de la P-ROM vers la ROM
    du BIOS en espace programme. C'est juste pour un appel du jeu vers le BIOS, mais pas pour le
    chemin inverse : si le BIOS appelle une routine du jeu par `jsr` — le wiki en nomme, comme
    `PLAYER_START` —, le retour par `rts` ramène dans le BIOS à l'instruction suivant le `jsr`,
    qui est une adresse **interne**. Elle serait alors publiée comme point d'entrée, en titre du
    document et dans son nom de fichier.

    Aucune des trois traces de BIOS SNK du lot ne porte une telle excursion : toutes leurs
    transitions tombent sur un cran de la table. Le filtre est donc une garde, pas un correctif
    d'un défaut observé — mais §8 ne se tient pas sur la chance d'un jeu de traces."""
    bas, haut, pas = TABLE_SAUTS
    return bas <= adresse <= haut and (adresse - bas) % pas == 0


def valeurs_dérivées_du_pc(accès, de, à):
    """Les sites dont la valeur écrite est, ou complète, une adresse interne de la ROM du BIOS.

    LE GARDE PAR SÉQUENCE NE VOIT PAS CE CAS, et c'est pourquoi il en faut un second. Un `jsr`
    interne au BIOS empile son adresse de retour : c'est une écriture en RAM dont la **valeur** est
    une adresse de la ROM du BIOS, et rien n'a été lu dans une table. La valeur vient du PC.
    `DECISIONS.md` §8 garde ces adresses hors du contrat, donc ces valeurs doivent en sortir.

    Mesuré sur les sept appels à `$C0044A` de la fenêtre 505-511 : **161 paires** de mots formant
    un long dans `$C00000`-`$C1FFFF`, toutes en zone `ram_jeu`, là où descend la pile du BIOS.

UN SEUL CRITÈRE SUFFIT, et c'est mesuré : la valeur **est** un mot haut de la plage (`$00C0`,
    `$00C1`), donc la moitié haute d'une adresse de ROM, et le site suivant en porte la moitié
    basse. Comme `MOTS_HAUTS_ROM` se déduit des bornes de `ROM_BIOS`, tout long qui tombe dans la
    plage a forcément son mot haut dans cet ensemble.

    La première version ajoutait un second critère — deux écritures de mot à des adresses
    consécutives dont le long tombe dans la plage — en annonçant qu'il « rattrapait ce que le
    premier manque ». Il ne rattrapait rien : sur les quatre traces du lot, les deux critères
    rendent le **même ensemble** (15, 6, 21 et 4 sites, différence symétrique vide). Et il était
    plus faible, parce qu'il exigeait l'ordre : le mot haut écrit avant le bas. Sur `snk505`, 10
    longs de ROM sont écrits dans l'autre ordre, que le critère 1 attrape et que le second
    manquait. Il est retiré.

    CE QUI ÉCHAPPE ENCORE, et il faut le dire plutôt que de le taire. Deux cas, tous deux hors de
    portée du critère :

    - une adresse écrite **octet par octet** ne fait passer aucun `$00C0` ni `$00C1` sur le bus en
      mot. Aucune des quatre traces ne porte d'écriture d'octet de valeur `$C0` ou `$C1`, mais
      c'est un constat sur ces traces, pas une garantie ;
    - une **moitié basse écrite seule** — un offset de 16 bits dans la ROM, sans son mot haut —
      n'est pas reconnaissable : le critère n'agit que sur la paire. Rien ne permet de la
      distinguer d'une valeur ordinaire sans connaître le contenu de la ROM, donc ce cas n'est
      pas mesurable sur une trace.

    Rend l'ensemble des sites à retenir. On retient la **valeur**, pas l'adresse : §8 admet
    l'adresse d'une écriture en RAM, c'est la valeur qui porte l'adresse interne."""
    retenus = set()
    for _, adresse, sens, ul, donnée, espace in accès[de:à]:
        if sens == "WR" and ul == "UL" and espace != "sp" and donnée in MOTS_HAUTS_ROM:
            retenus.add(adresse)
            retenus.add(adresse + 2)        # le mot bas de la même adresse longue
    return retenus


def séquences_suspectes(accès, de, à):
    """Les transferts qui ressemblent à une table recopiée depuis la ROM du BIOS (§8).

    On ne cherche pas la provenance d'une valeur — la trace ne montre pas les registres, donc
    personne ne peut l'établir ici. On compte les **mots lus à des adresses croissantes et
    contiguës dans la ROM, en espace DONNÉE**, et on le signale au-delà du seuil.

    L'ESPACE DONNÉE N'EST PAS UN CAPRICE. Sans ce filtre, le compte attrape le **flux
    d'instructions** : le 68000 préfetche, donc un code qui s'exécute lit par définition des mots
    contigus dans la ROM. Mesuré sur `$C0044A` : 46 séquences signalées sans le filtre, dont 22 de
    quatre mots — c'est l'exécution qu'on voyait, pas des tables.

    CE QUE LE FILTRE RATE, et `DECISIONS.md` §8 le dit du critère lui-même : une table lue en mode
    PC-relatif sort en espace programme, comme un immédiat, et échappe donc au signalement. C'est
    la raison pour laquelle le contrat se relit appel par appel au lieu de se valider tout seul."""
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
    """Pour chaque accès : le dernier accès en espace programme était-il dans la ROM du BIOS ?

    Un appel peut rendre la main à la cartouche en cours de route — mesuré au START de `puzzledp` :
    l'appel à `$C0044A` de la trame 560,23 la garde près de deux trames, et 15 025 de ses 16 612
    écritures tombent pendant que le code de la cartouche s'exécute (zone `ram_jeu`, le démarrage
    de partie du jeu). Les attribuer à l'appel noierait le contrat sous un comportement qui n'est
    pas celui du BIOS, et qu'un implémenteur n'a pas à reproduire.

    Le critère reste celui de `découper` : l'espace programme dit qui a la main. Le préfetch du
    68000 peut décaler la frontière de quelques accès autour d'un transfert ; sur une même trace,
    le résultat ne change pas, et le déterminisme de I2 tient."""
    dedans, au_bios = [], True
    for _, adresse, _, _, _, espace in accès:
        if espace == "sp":
            au_bios = ROM_BIOS[0] <= adresse <= ROM_BIOS[1]
        dedans.append(au_bios)
    return dedans


def contrat(accès, appels, entrée, dedans=None):
    """Ce que les appels d'un même point d'entrée ont en commun, et ce qui les sépare."""
    miens = [a for a in appels if a["entrée"] == entrée]
    if not miens:
        # Un point d'entrée dont aucun appel ne s'est fermé n'a pas de contrat : sa surface est
        # inconnue, pas vide. Rendre None plutôt que de planter sur une liste de périodes vide.
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
            # `..` : ni UDS ni LDS, donc rien n'a traversé le bus. On l'écarte ici plutôt que
            # de laisser `valeur_écrite` rendre un None qui finirait dans un `sorted()`.
            if (sens == "WR" and ul != ".." and espace != "sp"
                    and zone(adresse) not in (None, "rom_bios")):
                if not dedans[i]:
                    cartouche += 1
                    continue
                octet = site_écrit(adresse, ul)
                w.add(octet)
                # L'ensemble des valeurs vues à cette adresse : une seule fait un contrat dur,
                # plusieurs disent « il écrit ici, d'après un état que la trace ne montre pas ».
                valeurs.setdefault(octet, set()).add(valeur_écrite(ul, donnée))
        écritures.append(w)
    toutes = sorted(set().union(*écritures)) if écritures else []
    # 811 008 périodes par trame, mesuré entre deux fronts de VSYNC au co-simulateur.
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
    """Le document d'un point d'entrée. Markdown, pour qu'il se lise sans outil."""
    chemin = f"{dossier}/appel_{c['entrée']:06X}.md"
    stables = [e for e in c["écritures"] if e[2] == c["appels"]]
    variables = [e for e in c["écritures"] if e[2] != c["appels"]]
    # LE GARDE §8. Une valeur écrite en RAM peut sortir d'une table lue dans la ROM du BIOS, et §8
    # interdit alors de porter les octets : seul le fait du transfert entre dans le contrat. On ne
    # peut pas le prouver depuis la trace, qui ne montre pas les registres — donc dès qu'une
    # séquence est signalée sur cet appel, les valeurs sont retenues en bloc. C'est grossier, et
    # c'est le sens voulu : le doute retire la valeur, il ne la laisse pas passer.
    valeurs_retenues = bool(c["suspectes"])

    def colonne(vals, adresse=None):
        """La cellule de valeur : une seule vue, plusieurs, retenue, ou sans objet.

        LE HC259 EST UN VERROU ADRESSÉ : l'ordre est porté par l'adresse, et la donnée du bus est
        ignorée par le matériel. Afficher `2 valeurs : $FE, $FF` y ferait croire à une valeur à
        reproduire, alors que les deux sont sans effet. Le mode `--boot` le disait déjà de sa
        poignée de main ; un contrat d'appel se lit seul, donc il doit le dire aussi."""
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
        # §8 : UNE ADRESSE DE RETOUR PEUT ÊTRE INTERNE À LA ROM DU BIOS. C'est le cas d'un
        # gestionnaire d'interruption, qui rend la main par un `rte` là où le BIOS s'était
        # interrompu — mesuré sur `$C00438`, qui revient dans la ROM du BIOS. La publier referait la
        # fuite que le second garde ferme du côté des valeurs.
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
            # LES ADRESSES DE CES SÉQUENCES N'ENTRENT PAS ICI : §8 exclut du contrat les adresses
            # internes de la ROM du BIOS, et une séquence y est par définition. On en donne la
            # taille, qui suffit à décider s'il faut regarder ; celui qui tranche a la trace.
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
    """Le contrat de la MISE SOUS TENSION, qui n'est pas un appel et ne se découpe pas comme tel.

    Au boot, tout s'exécute dans la ROM du BIOS : il n'y a aucune transition d'espace programme
    entre elle et la P-ROM, donc `découper()` ne rend rien. Ce que le contrat porte ici est une
    **séquence** — les vecteurs lus, le point d'entrée, la poignée de main des registres, et ce que
    la RAM reçoit — et c'est ce que la couche 0 doit reproduire.

    §8 TIENT ICI AUSSI : le point d'entrée entre dans le contrat, les adresses internes de la ROM
    non. On ne porte donc ni la suite des fetchs, ni les adresses du code parcouru."""
    T = 811008
    vecteurs = [a for a in accès[:8] if a[1] <= 0x0007 and a[2] == "rd"]
    # Le point d'entrée : le premier fetch dans la ROM du BIOS, vers lequel le vecteur pointe.
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
    # Même garde qu'au contrat d'appel : une séquence signalée retient les valeurs en bloc.
    retenues = bool(susp_boot)
    # Les sites de RAM BIOS dont la valeur ne varie pas sur la fenêtre relevée.
    #
    # CE N'EST PAS « L'ÉTAT EN FIN DE BOOT », et la différence a failli produire un contrat faux.
    # Une valeur constante sur une fenêtre ne dit rien de ce qui suit la fenêtre : sur un dump SNK,
    # les premières trames portent les motifs du TEST MÉMOIRE — `0x55`, puis `0xAA`, puis une
    # valeur dérivée de l'adresse —, et les variables du BIOS ne valent quelque chose qu'à partir
    # de la trame ~300 (`docs/BENCH.md`, piège 7). La fenêtre de boot s'arrête à 9,2.
    #
    # D'où le garde ci-dessous : si TOUS ces sites portent la MÊME valeur, c'est la signature d'un
    # remplissage — motif de test, ou vidage — et non d'un état. Le contrat le dit alors au lieu
    # de présenter le motif comme quelque chose à reproduire.
    # LE SECOND GARDE VAUT ICI AUSSI, et il y manquait. `contrat()` l'appliquait, `contrat_boot`
    # non : sur la fenêtre 330-338, le contrat publiait les deux moitiés d'une adresse de retour
    # interne du BIOS, en `$10FF00` et `$10FF02`. La fenêtre de boot n'en montrait rien par
    # chance — ses longs de ROM tombent en `ram_jeu`, que cette section ne publie pas.
    #
    # L'ADRESSE FUITÉE N'EST PAS RECOPIÉE ICI, et c'est le point : la première version de ce
    # commentaire la citait en clair, ce qui refaisait la fuite dans le texte même qui la décrit.
    # Les sites suffisent à retrouver le cas sur la trace ; la valeur n'a pas à être écrite.
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
    """Les événements du protocole d'une trace : écritures sur les sites suivis, remises de main.

    POURQUOI CE MODE EXISTE. `USER` n'est pas une entrée du BIOS mais la routine de la cartouche
    (`docs/tasks.md`) : aucun contrat d'appel ne dit ce que le BIOS écrit AVANT de lui remettre la
    main, ni quand il la remet. Ces écritures tombent hors de tout appel délimité, donc hors des
    contrats — ce mode les relève, sur les sites que l'opérateur donne. Le générateur **ne nomme
    rien** : le choix des sites se source dans la relecture (§8), pas ici.

    UNE REMISE DE MAIN N'EST PAS UN RETOUR D'APPEL. Les transitions BIOS → cartouche en espace
    programme sont de deux natures : la borne d'un appel fermé par un cadre vérifié — un `rts`,
    déjà couvert par les contrats d'appel — et tout le reste : la sortie d'un appel entré par
    `jmp` (fermé par repli, sans cadre), ou une excursion au milieu d'un appel. Ce reste est le
    protocole, et c'est ce qu'on chronique.

    QUI A LA MAIN suit `la_main_au_bios` : une écriture du jeu sur un site suivi se voit, mais
    marquée comme sienne — elle n'est pas un comportement du BIOS à reproduire."""
    appels = découper(accès)
    dedans = la_main_au_bios(accès)
    pc = valeurs_dérivées_du_pc(accès, 0, len(accès))
    retenues = bool(séquences_suspectes(accès, 0, len(accès)))
    bios = lambda a: ROM_BIOS[0] <= a <= ROM_BIOS[1]

    # Les écritures ET les lectures qui touchent un site suivi. `touchés` suit la largeur : un
    # mot couvre son octet pair et l'impair, et un site suivi impair doit voir passer le mot qui
    # l'écrit. UNE LECTURE EST UN FAIT DE PROTOCOLE AUSSI : un BIOS qui scrute la réponse d'un
    # port la lit en boucle, et taire ces lectures ferait croire à un envoi aveugle. Sa valeur
    # n'est pas observable (le banc ne pose aucune donnée sur le bus pour une lecture) : la
    # chronique le dit, elle n'invente pas d'octet.
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

    # Les événements répétés se replient : un BIOS qui réécrit le même site à chaque trame ferait
    # un document de centaines de lignes identiques, où la transition qui compte ne se voit plus.
    repliées = []
    for période, site, valeur, main in écritures:
        if repliées and repliées[-1][1:4] == (site, valeur, main):
            première, _, _, _, _, compte = repliées[-1]
            repliées[-1] = (première, site, valeur, main, période, compte + 1)
        else:
            repliées.append((période, site, valeur, main, période, 1))

    # Les transitions BIOS → cartouche, moins les retours d'appel vérifiés par un cadre.
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
    """Le document du protocole : une section par trace, chronologie des sites suivis et des
    remises de main. Markdown, mêmes règles que les contrats — §8 compris."""
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
    """La part des accès en espace programme qui tombent dans la P-ROM de la cartouche.

    Juge de la condition 3 de C0 (`docs/tasks.md`) : après la bascule `SWPROM`, le programme doit
    s'exécuter depuis la cartouche et non depuis la ROM du BIOS. Sous BIOS SNK la part passe de
    0,0 % avant la bascule à 96,9 % après
    (`measured/2026-10-11-espaces-adressage-puzzledp.tsv`).

LES 128 PREMIERS OCTETS SUIVENT `biosMode`, et c'est tout l'objet du compte. Le co-simulateur
    (non publié) sert `a < 0x80` depuis le **BIOS** tant que `biosMode` tient, et depuis la **cartouche** après —
    il le lève sur `SWPROM`. Les exclure toujours sous-compterait la cartouche après la
    bascule ; ne jamais les exclure ferait passer les lectures du vecteur de reset pour de la
    cartouche au boot. Le juge suit donc l'état dans la trace : `$3A0003` l'arme, `$3A0013` le
    lève, et l'état initial est armé comme à la mise sous tension.

    LA BANQUE `$2xxxxx` N'EST PAS COMPTÉE : le co-simulateur la sert depuis le même tampon de P-ROM,
    donc du code de cartouche s'y exécute aussi, mais le critère de C0 porte sur `$00xxxx` et la
    compter changerait la grandeur sans le dire.

    `de` et `à` bornent la fenêtre en trames ; sans eux, c'est celle de la trace."""
    T = 811008
    bios_bas = True          # à la mise sous tension, le BIOS est en bas de la carte
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
            continue         # servi par le BIOS, pas par la cartouche
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
    # Refuser plutôt que créer : un dossier fabriqué depuis un argument mal tapé disperse les
    # contrats sans que personne ne le voie.
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
    # PLUSIEURS TRACES FONT UN SEUL CONTRAT, et c'est une question de justesse avant d'être du
    # confort : une écriture stable sur les appels d'une seule fenêtre peut n'être stable que dans
    # son régime — mesuré sur `$C0044A`, dont la fenêtre du BIOS en attente et celle du jeu en
    # cours ne donnent pas le même noyau. Chaque trace est DÉCOUPÉE SÉPARÉMENT : concaténer avant
    # de découper fabriquerait, à la jointure de deux fichiers, une fausse transition d'espace
    # programme, donc un appel fantôme.
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
        # Hors de la table publique, l'adresse est interne : ni titre, ni nom de fichier.
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
