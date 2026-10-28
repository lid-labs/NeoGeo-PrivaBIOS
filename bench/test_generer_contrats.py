#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Thibaut Lion
"""Tests du générateur de contrats. `unittest` de la bibliothèque standard, rien à installer.

    python3 bench/test_generer_contrats.py

POURQUOI CE FICHIER EXISTE. Les lots qui ont construit `generer-contrats.py` ont affirmé plusieurs
vérifications « sur une trace fabriquée » — les trois chemins de décodage d'un strobe, et la
mutation d'une table de cinq mots en table de trois pour éprouver le garde de §8. Aucune de ces
traces n'était versionnée, donc aucune de ces affirmations n'était revérifiable : une review l'a
relevé, et c'était justifié. Les traces sont ici, dans le code des tests, et elles se rejouent.

Les traces sont **fabriquées**, pas capturées : elles n'ont pas à ressembler à une exécution
réelle, seulement à poser le cas que chaque test interroge. Une trace capturée est dans
`measured/` ou dans un relevé ; celles-ci sont des agrès.
"""

import contextlib
import importlib.util
import io
import os
import sys
import tempfile
import unittest

# PAS DE BYTECODE : un `.pyc` périmé a déjà fait passer 38 tests contre une version du générateur
# qui n'était plus sur le disque, et invalidé une campagne de mutation entière. `python3 -I`
# ignore `PYTHONDONTWRITEBYTECODE`, donc on le pose ici.
sys.dont_write_bytecode = True

_ici = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("gc", os.path.join(_ici, "generer-contrats.py"))
g = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(g)


def trace(lignes):
    """Un fichier de trace jetable, au format du banc : `période adresse sens strobe donnée espace`.

    Les périodes sont engendrées ici : aucun test n'en dépend, et les écrire à la main inviterait
    à se tromper sans que rien ne le dise."""
    texte = "".join(f"{1000 + 20 * i:10d} {a:06X} {s} {u} {d} {e}\n"
                    for i, (a, s, u, d, e) in enumerate(lignes))
    f = tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False, encoding="utf-8")
    f.write(texte)
    f.close()
    return f.name


def appel(corps, entrée=0xC0044A):
    """Un appel délimité : un accès hors ROM BIOS, l'entrée, le corps, puis le retour.

    `découper` délimite un appel par la transition d'espace programme, donc il faut l'encadrer."""
    return ([(0x000100, "rd", "UL", "0000", "sp"), (entrée, "rd", "UL", "0000", "sp")]
            + corps + [(0x000104, "rd", "UL", "0000", "sp")])


def écrire_contrat(lignes, entrée=0xC0044A):
    """Le texte du contrat d'un point d'entrée, pour une trace fabriquée."""
    chemin = trace(lignes)
    try:
        accès = g.lire_trace(chemin)
        appels = g.découper(accès)
        with tempfile.TemporaryDirectory() as d:
            with io.open(g.écrire(g.contrat(accès, appels, entrée), d), encoding="utf-8") as f:
                return f.read()
    finally:
        os.unlink(chemin)


class Décodage(unittest.TestCase):
    """Les trois chemins de `valeur_écrite`, et la résolution de l'adresse d'octet.

    UNE ÉCRITURE D'OCTET POSE LA DONNÉE SUR LES DEUX MOITIÉS DU BUS : c'est le fait mesuré qui
    rend ces tests nécessaires. Lire les seize bits d'un `$80` rendrait `$8080`."""

    def test_octet_pair(self):
        self.assertEqual(g.valeur_écrite("U.", "8080"), "80")
        self.assertEqual(g.site_écrit(0x10FD82, "U."), 0x10FD82)

    def test_octet_impair(self):
        self.assertEqual(g.valeur_écrite(".L", "0101"), "01")
        # Le décalage de l'octet impair : $10FD83, le code pays, et non $10FD82, le type machine.
        self.assertEqual(g.site_écrit(0x10FD82, ".L"), 0x10FD83)

    def test_mot(self):
        self.assertEqual(g.valeur_écrite("UL", "1234"), "1234")
        self.assertEqual(g.site_écrit(0x10FD84, "UL"), 0x10FD84)

    def test_sans_strobe_lève(self):
        """Un strobe `..` n'a rien transféré : lever plutôt que rendre une valeur fausse."""
        with self.assertRaises(ValueError):
            g.valeur_écrite("..", "0000")

    def test_les_trois_dans_un_contrat(self):
        texte = écrire_contrat(appel([
            (0x10FD82, "WR", "U.", "8080", "sd"),
            (0x10FD82, "WR", ".L", "0101", "sd"),
            (0x10FD84, "WR", "UL", "1234", "sd"),
        ]))
        self.assertIn("| `$10FD82` | ram_bios | `$80` |", texte)
        self.assertIn("| `$10FD83` | ram_bios | `$01` |", texte)
        self.assertIn("| `$10FD84` | ram_bios | `$1234` |", texte)


class GardeDesTables(unittest.TestCase):
    """Le garde de §8 sur les tables lues dans la ROM du BIOS.

    LA MUTATION EST D'UN SEUL PARAMÈTRE entre les deux tests : la longueur de la suite lue, 5 mots
    contre 3, de part et d'autre du seuil de `SEUIL_SEQUENCE`. Deux traces qui diffèrent par
    autre chose ne prouveraient pas que c'est le seuil qui décide."""

    @staticmethod
    def _avec_table(mots):
        return appel(
            [(0xC05000 + 2 * i, "rd", "UL", "0000", "sd") for i in range(mots)]
            + [(0x10FD90 + 2 * i, "WR", "UL", f"{0xAB00 + i:04X}", "sd") for i in range(5)]
        )

    def test_au_dessus_du_seuil_retient(self):
        texte = écrire_contrat(self._avec_table(g.SEUIL_SEQUENCE + 1))
        self.assertIn("retenue (§8)", texte)
        self.assertNotIn("`$AB00`", texte)

    def test_sous_le_seuil_porte_les_valeurs(self):
        texte = écrire_contrat(self._avec_table(g.SEUIL_SEQUENCE - 1))
        self.assertIn("`$AB00`", texte)
        self.assertNotIn("retenue (§8)", texte)

    def test_le_seuil_est_bien_le_discriminant(self):
        """Les deux cas ne diffèrent que par la longueur de la suite."""
        a = self._avec_table(g.SEUIL_SEQUENCE + 1)
        b = self._avec_table(g.SEUIL_SEQUENCE - 1)
        écart = {l for l in a} ^ {l for l in b}
        self.assertTrue(all(0xC05000 <= l[0] <= 0xC05FFF for l in écart), écart)


class ValeursDérivéesDuPc(unittest.TestCase):
    """Une adresse de retour empilée est une écriture dont la valeur est une adresse de ROM BIOS.

    §8 garde ces adresses hors du contrat, et le garde des tables ne les voit pas : rien n'est lu
    dans une table, la valeur vient du PC."""

    def test_le_mot_haut_et_son_successeur_sortent(self):
        # Les écritures sont posées LOIN de l'entrée, hors de la fenêtre où `découper` cherche
        # le cadre de l'appelant : ici on éprouve le garde de §8, pas la délimitation.
        texte = écrire_contrat(appel(
            [(0xC0044C + 2 * i, "rd", "UL", "0000", "sp") for i in range(8)]
            + [(0x10F2AE, "WR", "UL", "00C1", "sd"),   # moitié haute d'une adresse de ROM BIOS
               (0x10F2B0, "WR", "UL", "1234", "sd")]   # sa moitié basse
        ))
        self.assertIn("retenue (§8 : adresse de ROM BIOS)", texte)
        self.assertNotIn("`$00C1`", texte)
        self.assertNotIn("`$1234`", texte)

    def test_insensible_a_l_ordre_d_ecriture(self):
        """Le mot bas peut être écrit avant le haut : mesuré sur du BIOS SNK réel."""
        texte = écrire_contrat(appel(
            [(0xC0044C + 2 * i, "rd", "UL", "0000", "sp") for i in range(8)]
            + [(0x10F2B0, "WR", "UL", "1234", "sd"),
               (0x10F2AE, "WR", "UL", "00C1", "sd")]
        ))
        self.assertNotIn("`$1234`", texte)

    def test_une_valeur_ordinaire_reste(self):
        texte = écrire_contrat(appel([(0x10FD90, "WR", "UL", "1234", "sd")]))
        self.assertIn("`$1234`", texte)


class Groupement(unittest.TestCase):
    """`grouper` avance du pas de la valeur : 2 pour un mot, 1 pour un octet.

    Un pas de 2 admis sur des octets ferait fusionner `$10FD80` et `$10FD82` en une plage alors
    que `$10FD81` n'a jamais été écrit — la plage affirmerait une écriture qui n'a pas eu lieu."""

    def test_octets_contigus_fusionnent(self):
        self.assertEqual(len(g.grouper([(0x10FD80, "00"), (0x10FD81, "00")])), 1)

    def test_octets_avec_un_trou_ne_fusionnent_pas(self):
        self.assertEqual(len(g.grouper([(0x10FD80, "00"), (0x10FD82, "00")])), 2)

    def test_mots_contigus_fusionnent(self):
        paires = [(0x10FD80, "0000"), (0x10FD82, "0000"), (0x10FD84, "0000")]
        self.assertEqual(g.grouper(paires), [(0x10FD80, 0x10FD84, "0000")])

    def test_un_mot_et_un_octet_ne_fusionnent_pas(self):
        """`$0000` et `$00` sont le même nombre et deux largeurs : la largeur est à reproduire."""
        self.assertEqual(len(g.grouper([(0x10FD80, "0000"), (0x10FD82, "00")])), 2)


class OctetDeRemplissage(unittest.TestCase):
    """Un mot dont les deux octets sont égaux est le même remplissage que cet octet.

    Sans cette normalisation, un seul site `$00` parmi des centaines de `$0000` suffisait à faire
    taire le garde du remplissage."""

    def test_un_octet(self):
        self.assertEqual(g.octet_de_remplissage("55"), "55")

    def test_un_mot_repete(self):
        self.assertEqual(g.octet_de_remplissage("5555"), "55")
        self.assertEqual(g.octet_de_remplissage("0000"), "00")

    def test_un_mot_non_repete_n_est_pas_un_remplissage(self):
        self.assertIsNone(g.octet_de_remplissage("1234"))


class PointEntréePublic(unittest.TestCase):
    """Seuls les crans de la table de sauts publique se publient comme points d'entrée."""

    def test_les_crans_connus(self):
        for adresse in (0xC00402, 0xC00438, 0xC0044A, 0xC00450, 0xC004C2, 0xC006FC):
            self.assertTrue(g.point_entrée_public(adresse), f"${adresse:06X}")

    def test_hors_grille(self):
        """Une adresse interne — un retour après un `jsr` du BIOS vers le jeu — est refusée."""
        self.assertFalse(g.point_entrée_public(0xC0044C))
        self.assertFalse(g.point_entrée_public(0xC00500))

    def test_hors_bornes(self):
        self.assertFalse(g.point_entrée_public(0xC00400))
        self.assertFalse(g.point_entrée_public(0xC00702))


class Zones(unittest.TestCase):
    """`zone` rend la plage la plus étroite, pas la première de la liste."""

    def test_le_plus_etroit_gagne(self):
        # $3A0003 est dans `controle_hc259`, lui-même inclus dans `registres_systeme`.
        self.assertEqual(g.zone(0x3A0003), "controle_hc259")

    def test_hors_carte(self):
        self.assertIsNone(g.zone(0xF00000))



# ---------------------------------------------------------------------------------------------
# LES DEUX CHEMINS QUE LES TESTS CI-DESSUS NE TOUCHAIENT PAS, et c'est une review qui l'a montré :
# `contrat_boot` et `main`. Deux des quatre gardes y vivent, et quatre mutations survivaient aux
# 23 premiers tests — dont le retrait de `o not in pc` dans `contrat_boot`, qui EST le défaut que
# le tour 5 avait corrigé. Un test qui ne couvre pas le chemin d'un correctif ne protège pas ce
# correctif.
# ---------------------------------------------------------------------------------------------


def écrire_boot(lignes):
    """Le texte du contrat de mise sous tension, pour une trace fabriquée."""
    chemin = trace(lignes)
    try:
        accès = g.lire_trace(chemin)
        with tempfile.TemporaryDirectory() as d:
            with io.open(g.contrat_boot(accès, d), encoding="utf-8") as f:
                return f.read()
    finally:
        os.unlink(chemin)


class ContratDeBoot(unittest.TestCase):
    """Les gardes du mode `--boot`, qui avaient chacun leur mutation survivante."""

    def test_le_garde_pc_s_applique_au_boot(self):
        """Le défaut du tour 5 : `contrat_boot` publiait l'adresse de retour empilée."""
        texte = écrire_boot([
            (0x000000, "rd", "UL", "0000", "sp"),
            (0x10FF00, "WR", "UL", "00C1", "sd"),   # moitié haute d'une adresse de ROM BIOS
            (0x10FF02, "WR", "UL", "1234", "sd"),   # sa moitié basse
            (0x10FE00, "WR", "UL", "ABCD", "sd"),   # une valeur ordinaire, qui doit rester
        ])
        self.assertNotIn("`$00C1`", texte)
        self.assertNotIn("`$1234`", texte)
        self.assertIn("site(s) de RAM BIOS sont écartés", texte)
        self.assertIn("`$ABCD`", texte)

    def test_le_garde_des_tables_s_applique_au_boot(self):
        """Une table lue dans la ROM retient les valeurs, côté boot aussi."""
        texte = écrire_boot(
            [(0x000000, "rd", "UL", "0000", "sp")]
            + [(0xC05000 + 2 * i, "rd", "UL", "0000", "sd") for i in range(g.SEUIL_SEQUENCE + 1)]
            + [(0x10FE00, "WR", "UL", "ABCD", "sd")]
        )
        self.assertIn("Retenu", texte)
        self.assertNotIn("`$ABCD`", texte)

    def test_un_remplissage_n_est_pas_un_etat(self):
        """Tous les sites au même octet de remplissage : le contrat refuse de parler d'état."""
        texte = écrire_boot(
            [(0x000000, "rd", "UL", "0000", "sp")]
            + [(0x10FE00 + 2 * i, "WR", "UL", "5555", "sd") for i in range(6)]
        )
        self.assertIn("ce n'est pas un état, c'est un remplissage".upper()[:20].lower(),
                      texte.lower())
        self.assertIn("`$55`", texte)

    def test_des_valeurs_distinctes_donnent_un_etat(self):
        """Le contrôle du test précédent : deux octets de remplissage différents, donc un état."""
        texte = écrire_boot([
            (0x000000, "rd", "UL", "0000", "sp"),
            (0x10FE00, "WR", "UL", "5555", "sd"),
            (0x10FE02, "WR", "UL", "1234", "sd"),
        ])
        self.assertNotIn("remplissage", texte)
        self.assertIn("`$1234`", texte)

    def test_la_poignee_de_main_resout_l_octet(self):
        """`$3A0003` et non `$3A0002` : le registre du HC259 est choisi par l'adresse d'octet."""
        texte = écrire_boot([
            (0x000000, "rd", "UL", "0000", "sp"),
            (0x3A0002, "WR", ".L", "0000", "sd"),
        ])
        self.assertIn("`$3A0003`", texte)
        self.assertNotIn("| `$3A0002` |", texte)


class FiltreDesPointsEntrée(unittest.TestCase):
    """`main` ne publie pas un point d'entrée hors de la table de sauts publique.

    Son adresse serait interne à la ROM du BIOS, et elle paraîtrait en titre du document comme
    dans son nom de fichier."""

    @staticmethod
    def _publie(entrée):
        """Les fichiers que `main` écrit pour une trace dont l'appel entre à `entrée`."""
        chemin = trace(appel([(0x10FD90, "WR", "UL", "1234", "sd")], entrée=entrée))
        try:
            with tempfile.TemporaryDirectory() as d:
                # `main` écrit sur stdout et stderr : on les détourne pour que la sortie des
                # tests reste lisible, pas pour cacher quoi que ce soit.
                with contextlib.redirect_stdout(io.StringIO()), \
                     contextlib.redirect_stderr(io.StringIO()):
                    g.main(["gen", chemin, d])
                return sorted(os.listdir(d))
        finally:
            os.unlink(chemin)

    def test_un_cran_de_la_table_est_publie(self):
        self.assertEqual(self._publie(0xC0044A), ["appel_C0044A.md"])

    def test_une_adresse_interne_ne_l_est_pas(self):
        """`$C0044C` suit `$C0044A` de deux octets : c'est dans le code, pas un cran."""
        self.assertEqual(self._publie(0xC0044C), [])


class SeuilDesSéquences(unittest.TestCase):
    """Le seuil est **fixé**, pas seulement encadré.

    Les tests de `GardeDesTables` éprouvent SEUIL_SEQUENCE + 1 et SEUIL_SEQUENCE - 1, ce qui laisse
    passer un `>=` changé en `>` : une table de la longueur exacte du seuil serait alors publiée en
    clair. Une review l'a mesuré."""

    def test_a_la_longueur_exacte_du_seuil_les_valeurs_sortent(self):
        texte = écrire_contrat(GardeDesTables._avec_table(g.SEUIL_SEQUENCE))
        self.assertIn("retenue (§8)", texte)
        self.assertNotIn("`$AB00`", texte)



# ---------------------------------------------------------------------------------------------
# LA BORNE DE FIN D'UN APPEL, que les tests ci-dessus ne touchaient pas : six mutations sur sept
# y survivaient, dont la publication d'une adresse de retour interne. Une review l'a mesuré.
# ---------------------------------------------------------------------------------------------


# L'ADRESSE INTERNE DES FIXTURES EST FABRIQUÉE — `$C10004`, pas celle d'un BIOS réel. Les lots
# précédents ont recopié deux fois une adresse mesurée dans le texte qui la décrit ; une fixture
# n'a besoin que d'une adresse DANS la plage `$C00000`-`$C1FFFF`, pas de la bonne.


def délimiter(lignes):
    """Les appels qu'un découpage trouve dans une trace fabriquée, stderr avalé."""
    chemin = trace(lignes)
    try:
        with contextlib.redirect_stderr(io.StringIO()) as err:
            ap = g.découper(g.lire_trace(chemin))
        return ap, err.getvalue()
    finally:
        os.unlink(chemin)


class BorneDeFinDAppel(unittest.TestCase):
    """La sortie d'un appel suit l'adresse empilée, pas la sortie de la ROM du BIOS."""

    def test_un_jsr_ferme_sur_l_adresse_empilee(self):
        ap, _ = délimiter([
            (0x000100, "rd", "UL", "0000", "sp"),
            (0xC0044A, "rd", "UL", "0000", "sp"),
            (0x10F2BA, "WR", "UL", "0000", "sd"),   # le `jsr` empile le retour…
            (0x10F2BC, "WR", "UL", "026A", "sd"),   # … soit $00026A
            (0xC0044C, "rd", "UL", "0000", "sp"),
            (0x00026A, "rd", "UL", "0000", "sp"),
        ])
        self.assertEqual([a["retour"] for a in ap], [0x00026A])

    def test_une_interruption_ferme_dans_le_bios(self):
        """Un `rte` rend la main DANS le BIOS : aucune transition ne le marque.

        LA PROFONDEUR DU CADRE EST CELLE QUI A ÉTÉ MESURÉE : -15, -13 et -12 accès de l'entrée, les
        huit fetches du stub de cartouche et la lecture du vecteur comptant pour l'essentiel de
        l'écart. Une fixture qui le poserait à -2 passerait avec une fenêtre `avant` beaucoup plus
        courte, et les huit appels réels à `$C00438` retomberaient alors sur le repli sans qu'aucun
        test ne le dise — mesuré."""
        ap, _ = délimiter(
            [(0xC10000, "rd", "UL", "0000", "sp"),   # le BIOS tourne
             (0x10F2FA, "WR", "UL", "0004", "sd"),   # l'exception empile le PC bas…
             (0xFFFFF2, "rd", "UL", "0000", "cs"),   # … l'acquittement d'interruption…
             (0x10F2F6, "WR", "UL", "2000", "sd"),   # … puis SR…
             (0x10F2F8, "WR", "UL", "00C1", "sd"),   # … puis le PC haut : $C10004
             (0x000064, "rd", "UL", "0000", "sd"),   # le vecteur d'autovecteur
             (0x000066, "rd", "UL", "0000", "sd")]
            # Les huit fetches du stub de la cartouche, qui font la profondeur du cadre.
            + [(0x000200 + 2 * i, "rd", "UL", "0000", "sp") for i in range(8)]
            + [(0xC00438, "rd", "UL", "0000", "sp"),   # l'entrée du gestionnaire
               (0xC0043A, "rd", "UL", "0000", "sp"),
               (0xC10004, "rd", "UL", "0000", "sp"),   # le `rte` : retour dans le BIOS
               (0xC10006, "rd", "UL", "0000", "sp")]
        )
        self.assertEqual([(a["entrée"], a["retour"]) for a in ap], [(0xC00438, 0xC10004)])

    def test_une_sous_routine_du_jeu_ne_vole_pas_la_borne(self):
        """Régression : un cadre déjà vivant sur la pile fermait l'appel trop tôt.

        Le jeu appelle une sous-routine, qui appelle le BIOS. Deux cadres sont dans la fenêtre ;
        seul celui écrit APRÈS l'entrée appartient à cet appel."""
        ap, _ = délimiter([
            (0x000100, "rd", "UL", "0000", "sp"),
            (0x10F2BE, "WR", "UL", "0000", "sd"),   # le jeu empile le retour de SA sous-routine
            (0x10F2C0, "WR", "UL", "0106", "sd"),
            (0x000500, "rd", "UL", "0000", "sp"),
            (0xC0044A, "rd", "UL", "0000", "sp"),
            (0x10F2BA, "WR", "UL", "0000", "sd"),   # le `jsr` du BIOS empile $000504
            (0x10F2BC, "WR", "UL", "0504", "sd"),
            (0xC0044C, "rd", "UL", "0000", "sp"),
            (0x000504, "rd", "UL", "0000", "sp"),   # le BIOS rend la main à la sous-routine
            (0x000106, "rd", "UL", "0000", "sp"),
        ])
        self.assertEqual([a["retour"] for a in ap], [0x000504])

    def test_un_cadre_imbrique_hors_fenetre_est_ignore(self):
        """Le cadre d'un `jsr` interne au BIOS tombe au-delà de `après`, donc il n'est pas candidat.

        C'EST CE QUI REND L'ORDRE DES CANDIDATS POSTÉRIEURS SANS OBJET, et non une règle de
        priorité : un appel imbriqué doit laisser le BIOS exécuter quelques instructions avant son
        propre `jsr`, donc son cadre sort de la fenêtre. Ce test vérifie que le cadre à +4/+5 est
        ignoré ; il ne teste **pas** un arbitrage entre deux candidats postérieurs, qui n'existe
        pas sur une entrée de la table de sauts."""
        ap, _ = délimiter([
            (0x000100, "rd", "UL", "0000", "sp"),
            (0xC0044A, "rd", "UL", "0000", "sp"),
            (0x10F2BA, "WR", "UL", "0000", "sd"),   # le `jsr` du jeu empile $00026A
            (0x10F2BC, "WR", "UL", "026A", "sd"),
            (0xC0044C, "rd", "UL", "0000", "sp"),
            (0x10F2B6, "WR", "UL", "00C0", "sd"),   # un `jsr` interne empile $C00500
            (0x10F2B8, "WR", "UL", "0500", "sd"),
            (0xC00600, "rd", "UL", "0000", "sp"),
            (0xC00500, "rd", "UL", "0000", "sp"),   # le `rts` interne
            (0x00026A, "rd", "UL", "0000", "sp"),   # le `rts` de l'appel
        ])
        self.assertEqual([a["retour"] for a in ap], [0x00026A])

    def test_la_borne_est_le_premier_fetch_du_retour(self):
        """L'appelant peut repasser plusieurs fois à son adresse de retour : la borne est la
        première.

        Sans ce test, prendre la seconde occurrence passait les 39 autres — et changeait **toutes**
        les tailles d'appel des deux traces réelles, mesuré."""
        ap, _ = délimiter([
            (0x000100, "rd", "UL", "0000", "sp"),
            (0xC0044A, "rd", "UL", "0000", "sp"),
            (0x10F2BA, "WR", "UL", "0000", "sd"),
            (0x10F2BC, "WR", "UL", "026A", "sd"),
            (0xC0044C, "rd", "UL", "0000", "sp"),
            (0x00026A, "rd", "UL", "0000", "sp"),   # le retour : la borne est ICI
            (0x00026C, "rd", "UL", "0000", "sp"),
            (0x00026A, "rd", "UL", "0000", "sp"),   # l'appelant y repasse, une boucle
        ])
        self.assertEqual(len(ap), 1)
        # Quatre accès depuis l'entrée : le premier $00026A, pas le second.
        self.assertEqual(ap[0]["à"] - ap[0]["de"], 4)

    def test_sans_cadre_le_repli_se_signale(self):
        """Le repli reprend une borne qui peut valoir une trame : il ne doit pas être muet."""
        ap, err = délimiter([
            (0x000100, "rd", "UL", "0000", "sp"),
            (0xC00444, "rd", "UL", "0000", "sp"),   # entré par `jmp` : rien n'est empilé
            (0xC00446, "rd", "UL", "0000", "sp"),
            (0x000122, "rd", "UL", "0000", "sp"),
        ])
        self.assertEqual([a["retour"] for a in ap], [0x000122])
        self.assertIn("repli", err)


class RetourInterneAuBios(unittest.TestCase):
    """§8 : une adresse de retour dans la ROM du BIOS ne se publie pas.

    Un gestionnaire d'interruption revient là où le BIOS s'était interrompu, donc son retour est
    une adresse interne. Aucun garde antérieur ne le couvrait : ils portent sur les valeurs
    écrites, pas sur l'adresse de retour que le contrat annonce en tête."""

    LIGNES = [
        (0xC10000, "rd", "UL", "0000", "sp"),
        (0x10F2FA, "WR", "UL", "0004", "sd"),
        (0x10F2F6, "WR", "UL", "2000", "sd"),
        (0x10F2F8, "WR", "UL", "00C1", "sd"),
        (0x000200, "rd", "UL", "0000", "sp"),
        (0xC00438, "rd", "UL", "0000", "sp"),
        (0x10FD95, "WR", "U.", "1111", "sd"),
        (0xC10004, "rd", "UL", "0000", "sp"),
    ]

    def test_elle_est_retenue_et_comptee(self):
        chemin = trace(self.LIGNES)
        try:
            accès = g.lire_trace(chemin)
            appels = g.découper(accès)
            with tempfile.TemporaryDirectory() as d:
                with io.open(g.écrire(g.contrat(accès, appels, 0xC00438), d), encoding="utf-8") as f:
                    texte = f.read()
        finally:
            os.unlink(chemin)
        self.assertNotIn("$C10004", texte)
        self.assertIn("internes à la ROM du BIOS", texte)

    def test_un_retour_hors_du_bios_est_publie(self):
        """Le contrôle : sans quoi le test précédent passerait en ne publiant jamais rien."""
        texte = écrire_contrat(appel([(0x10FD95, "WR", "U.", "1111", "sd")]))
        self.assertIn("- Retour vers : `$000104`", texte)


class AucunAppelFerme(unittest.TestCase):
    """`contrat()` rendait `min()` sur une liste vide quand aucun appel ne se fermait."""

    def test_contrat_rend_none(self):
        chemin = trace([
            (0x000100, "rd", "UL", "0000", "sp"),
            (0xC0044A, "rd", "UL", "0000", "sp"),
            (0x10F2BA, "WR", "UL", "00FF", "sd"),   # un retour vers $00FFFFFF…
            (0x10F2BC, "WR", "UL", "FFFF", "sd"),   # … où le PC ne va jamais
            (0xC0044C, "rd", "UL", "0000", "sp"),   # et aucune sortie de la ROM ensuite
        ])
        try:
            accès = g.lire_trace(chemin)
            with contextlib.redirect_stderr(io.StringIO()):
                appels = g.découper(accès)
            self.assertIsNone(g.contrat(accès, appels, 0xC0044A))
        finally:
            os.unlink(chemin)


class ÉcrituresDeLaCartouche(unittest.TestCase):
    """Une écriture faite pendant que la cartouche a la main n'entre pas au contrat.

    Mesuré au START de `puzzledp` : l'appel à `$C0044A` de la trame 560,23 rend la main à la
    cartouche en cours de route, et 15 025 de ses 16 612 écritures sont le démarrage de partie du
    jeu — le contrat faisait 604 Ko et noyait les 42 écritures du BIOS. Le critère est celui de
    `la_main_au_bios` : le dernier accès en espace programme dit qui écrit."""

    def _trace_avec_excursion(self):
        return [
            (0x000100, "rd", "UL", "0000", "sp"),   # le jeu tourne
            (0xC0044A, "rd", "UL", "0000", "sp"),   # l'entrée
            (0x10F2BA, "WR", "UL", "0000", "sd"),   # le `jsr` empile $00026A
            (0x10F2BC, "WR", "UL", "026A", "sd"),
            (0xC0044C, "rd", "UL", "0000", "sp"),
            (0x10FD90, "WR", "UL", "1234", "sd"),   # écriture du BIOS : au contrat
            (0x000300, "rd", "UL", "0000", "sp"),   # le BIOS rend la main à la cartouche…
            (0x100100, "WR", "UL", "5678", "sd"),   # … qui écrit chez elle : hors contrat
            (0x000302, "rd", "UL", "0000", "sp"),
            (0xC00800, "rd", "UL", "0000", "sp"),   # la cartouche rend la main au BIOS
            (0x10FD92, "WR", "UL", "9ABC", "sd"),   # écriture du BIOS, après reprise : au contrat
            (0x00026A, "rd", "UL", "0000", "sp"),   # le retour, la borne
        ]

    def test_l_ecriture_du_jeu_est_ecartee_et_comptee(self):
        chemin = trace(self._trace_avec_excursion())
        try:
            accès = g.lire_trace(chemin)
            with contextlib.redirect_stderr(io.StringIO()):
                appels = g.découper(accès)
            c = g.contrat(accès, appels, 0xC0044A)
            sites = [adresse for adresse, _, _, _ in c["écritures"]]
            self.assertIn(0x10FD90, sites)
            self.assertIn(0x10FD92, sites)
            self.assertNotIn(0x100100, sites)
            self.assertEqual(c["écritures_cartouche"], 1)
        finally:
            os.unlink(chemin)

    def test_le_document_dit_ce_qu_il_ecarte(self):
        with contextlib.redirect_stderr(io.StringIO()):
            texte = écrire_contrat(self._trace_avec_excursion())
        self.assertIn("1 écriture(s) hors contrat", texte)

    def test_sans_excursion_rien_n_est_ecarte(self):
        with contextlib.redirect_stderr(io.StringIO()):
            texte = écrire_contrat(appel([(0x10FD90, "WR", "UL", "1234", "sd")]))
        self.assertNotIn("hors contrat", texte)


class PlusieursTraces(unittest.TestCase):
    """Un contrat se calcule sur l'union des appels de toutes les traces données.

    C'est une question de justesse : une écriture stable sur les appels d'une seule fenêtre peut
    n'être stable que dans son régime, et un contrat dur faux ferait coder la valeur en dur par
    l'implémenteur. Le cas fondateur : `$C0044A` vu du BIOS en attente et vu du jeu en cours."""

    def _appel_qui_écrit(self, valeur):
        return [
            (0x000100, "rd", "UL", "0000", "sp"),
            (0xC0044A, "rd", "UL", "0000", "sp"),
            (0x10F2BA, "WR", "UL", "0000", "sd"),   # le `jsr` empile $00026A
            (0x10F2BC, "WR", "UL", "026A", "sd"),
            (0xC0044C, "rd", "UL", "0000", "sp"),
            (0x10FD90, "WR", "UL", valeur, "sd"),
            (0x00026A, "rd", "UL", "0000", "sp"),
        ]

    def test_le_noyau_s_etend_sur_toutes_les_traces(self):
        t1, t2 = trace(self._appel_qui_écrit("1111")), trace(self._appel_qui_écrit("2222"))
        try:
            with tempfile.TemporaryDirectory() as d:
                with contextlib.redirect_stdout(io.StringIO()), \
                        contextlib.redirect_stderr(io.StringIO()):
                    code = g.main(["gc", t1, t2, d])
                self.assertEqual(code, 0)
                with io.open(os.path.join(d, "appel_C0044A.md"), encoding="utf-8") as f:
                    texte = f.read()
            # Deux appels, un par trace ; la valeur, stable dans chaque fenêtre prise seule,
            # est plurielle sur l'union — c'est ce que la fusion doit révéler.
            self.assertIn("Relevé sur **2 appel(s)**", texte)
            self.assertIn("2 valeurs : `$1111`, `$2222`", texte)
        finally:
            os.unlink(t1)
            os.unlink(t2)


def écrire_protocole_doc(lignes, sites):
    """Le texte du document de protocole, pour une trace fabriquée et des sites suivis."""
    chemin = trace(lignes)
    try:
        accès = g.lire_trace(chemin)
        with contextlib.redirect_stderr(io.StringIO()):
            s = g.protocole_trace(accès, set(sites))
        with tempfile.TemporaryDirectory() as d:
            with io.open(g.écrire_protocole([s], sorted(sites), d), encoding="utf-8") as f:
                return f.read()
    finally:
        os.unlink(chemin)


class Protocole(unittest.TestCase):
    """Le mode `--protocole` : chronique des sites suivis et des remises de main.

    `USER` n'a pas de contrat d'appel — les écritures du BIOS avant la remise de main tombent
    hors de tout appel délimité, et c'est ce mode qui les relève (`docs/tasks.md`, tâche USER)."""

    # Une remise par `jmp` : entrée au cran $C00444, écriture d'un site suivi, sortie par `jmp`
    # vers $000122 — aucun cadre empilé, donc l'appel se ferme par repli.
    JMP_PUIS_REMISE = [
        (0x000100, "rd", "UL", "0000", "sp"),
        (0xC00444, "rd", "UL", "0000", "sp"),
        (0x10FDAE, "WR", "U.", "0202", "sd"),
        (0xC00446, "rd", "UL", "0000", "sp"),
        (0x000122, "rd", "UL", "0000", "sp"),
    ]

    def test_une_ecriture_du_bios_sur_un_site_suivi(self):
        texte = écrire_protocole_doc(self.JMP_PUIS_REMISE, [0x10FDAE])
        self.assertIn("| `$10FDAE` | `$02` | bios |", texte)

    def test_un_site_non_suivi_ne_parait_pas(self):
        texte = écrire_protocole_doc(self.JMP_PUIS_REMISE, [0x10FDAF])
        self.assertNotIn("`$02`", texte)

    def test_la_remise_par_jmp_est_listee_avec_son_contexte(self):
        texte = écrire_protocole_doc(self.JMP_PUIS_REMISE, [0x10FDAE])
        self.assertIn("| `$000122` | appel entré à `$C00444` |", texte)

    def test_un_retour_verifie_n_est_pas_une_remise(self):
        """Le contrôle : un appel fermé par un cadre (`jsr`/`rts`) relève des contrats d'appel."""
        texte = écrire_protocole_doc([
            (0x000100, "rd", "UL", "0000", "sp"),
            (0xC0044A, "rd", "UL", "0000", "sp"),
            (0x10F2BA, "WR", "UL", "0000", "sd"),   # le `jsr` empile $00026A
            (0x10F2BC, "WR", "UL", "026A", "sd"),
            (0xC0044C, "rd", "UL", "0000", "sp"),
            (0x00026A, "rd", "UL", "0000", "sp"),
        ], [0x10FDAE])
        self.assertIn("Aucune sur cette trace.", texte.split("### Remises de main")[1])
        self.assertIn("1 vers `$00026A`", texte)

    def test_une_ecriture_de_la_cartouche_est_marquee(self):
        texte = écrire_protocole_doc([
            (0x000100, "rd", "UL", "0000", "sp"),
            (0x10FDAE, "WR", "U.", "0303", "sd"),
        ], [0x10FDAE])
        self.assertIn("| `$10FDAE` | `$03` | cartouche |", texte)

    def test_le_garde_pc_retient_la_valeur(self):
        """Une paire de mots qui forme une adresse de ROM BIOS : la valeur sort, le site reste."""
        texte = écrire_protocole_doc([
            (0xC00402, "rd", "UL", "0000", "sp"),
            (0x10FF00, "WR", "UL", "00C1", "sd"),
            (0x10FF02, "WR", "UL", "1234", "sd"),
        ], [0x10FF00])
        self.assertIn("retenue (§8)", texte)
        self.assertNotIn("`$00C1`", texte)

    def test_le_garde_des_tables_retient_en_bloc(self):
        texte = écrire_protocole_doc(
            [(0xC00402, "rd", "UL", "0000", "sp")]
            + [(0xC05000 + 2 * i, "rd", "UL", "0000", "sd") for i in range(g.SEUIL_SEQUENCE + 1)]
            + [(0x10FDAE, "WR", "U.", "0202", "sd")],
            [0x10FDAE])
        self.assertIn("Valeurs retenues en bloc", texte)
        self.assertNotIn("`$02`", texte)

    def test_un_mot_couvre_le_site_impair_suivi(self):
        """Suivre `$10FDAF` doit voir passer le mot écrit à `$10FDAE`, qui couvre les deux octets."""
        texte = écrire_protocole_doc([
            (0xC00402, "rd", "UL", "0000", "sp"),
            (0x10FDAE, "WR", "UL", "0201", "sd"),
        ], [0x10FDAF])
        self.assertIn("| `$10FDAE` | `$0201` | bios |", texte)

    def test_les_repetitions_se_replient(self):
        texte = écrire_protocole_doc([
            (0xC00402, "rd", "UL", "0000", "sp"),
            (0x10FDAE, "WR", "U.", "0202", "sd"),
            (0x10FDAE, "WR", "U.", "0202", "sd"),
            (0x10FDAE, "WR", "U.", "0202", "sd"),
        ], [0x10FDAE])
        self.assertIn("× 3", texte)

    def test_une_lecture_d_un_site_suivi_parait_sans_valeur(self):
        """Un BIOS qui scrute un port le lit en boucle : la chronique porte le fait, pas d'octet."""
        texte = écrire_protocole_doc([
            (0xC00402, "rd", "UL", "0000", "sp"),
            (0x320000, "WR", "U.", "0101", "sd"),
            (0x320000, "rd", "U.", "0000", "sd"),
        ], [0x320000])
        self.assertIn("| `$320000` | `$01` | bios |", texte)
        self.assertIn("| `$320000` | lecture — valeur non observable | bios |", texte)

    def test_une_lecture_d_un_site_non_suivi_ne_parait_pas(self):
        texte = écrire_protocole_doc([
            (0xC00402, "rd", "UL", "0000", "sp"),
            (0x320002, "rd", "U.", "0000", "sd"),
        ], [0x320000])
        self.assertNotIn("lecture", texte.split("### Accès aux sites suivis")[1].split("###")[0])

    def test_la_ligne_de_commande(self):
        chemin = trace(self.JMP_PUIS_REMISE)
        try:
            with tempfile.TemporaryDirectory() as d:
                with contextlib.redirect_stdout(io.StringIO()), \
                        contextlib.redirect_stderr(io.StringIO()):
                    self.assertEqual(g.main(["gen", chemin, d, "--protocole=10FDAE,10FDAF"]), 0)
                    self.assertIn("protocole.md", os.listdir(d))
                    self.assertEqual(g.main(["gen", chemin, d, "--protocole=XYZ"]), 2)
        finally:
            os.unlink(chemin)


# LA TABLE DU SINUS. Un autre générateur, `generer-sinus.py`, testé ici pour que l'étage 0
# de `non-regression.sh` le couvre sans étage de plus : le `.s` versionné est-il bien sa sortie ?
_spec_s = importlib.util.spec_from_file_location("gs", os.path.join(_ici, "generer-sinus.py"))
gs = importlib.util.module_from_spec(_spec_s)
_spec_s.loader.exec_module(gs)


class TableSinus(unittest.TestCase):
    def test_le_s_versionné_est_la_sortie_du_générateur(self):
        with io.open(gs.SORTIE, encoding="utf-8") as f:
            self.assertEqual(f.read(), gs.source(), "relancer bench/generer-sinus.py")

    def test_formule(self):
        t = gs.table()
        self.assertEqual(len(t), 256)
        self.assertEqual((t[0], t[64], t[128], t[192]), (0, 1, 0, 1))
        self.assertEqual(t[32], 0xB505)                       # 65536 · sin(π/4) = 46340,95
        for i in range(256):
            self.assertEqual(t[i], t[(i + 128) % 256])         # |sin| : période d'un demi-tour
            self.assertEqual(t[i], t[(128 - i) % 256])         # symétrie autour du quart de tour

    def test_une_ligne_par_huit_mots_indice_unique(self):
        lignes = [l for l in gs.source().splitlines() if ".word" in l]
        self.assertEqual(len(lignes), 32)
        self.assertEqual(len(set(lignes)), 32)                 # les mutations visent une ligne


if __name__ == "__main__":
    unittest.main(verbosity=2)
