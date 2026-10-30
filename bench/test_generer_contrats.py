#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Thibaut Lion
"""Tests of the contract generator. Standard-library `unittest`, nothing to install.

    python3 bench/test_generer_contrats.py

WHY THIS FILE EXISTS. The lots that built `generer-contrats.py` claimed several
checks "on a fabricated trace" — the three decoding paths of a strobe, and the
mutation of a five-word table into a three-word table to test the §8 guard. None of these
traces was versioned, so none of these claims could be checked again: a review
pointed it out, and rightly so. The traces are here, in the test code, and they replay.

The traces are **fabricated**, not captured: they need not resemble a real
execution, only set up the case each test questions. A captured trace is in
`measured/` or in a record; these ones are jigs.
"""

import contextlib
import importlib.util
import io
import os
import sys
import tempfile
import unittest

# NO BYTECODE: a stale `.pyc` has already made 38 tests pass against a version of the generator
# that was no longer on disk, and invalidated a whole mutation campaign. `python3 -I`
# ignores `PYTHONDONTWRITEBYTECODE`, so it is set here.
sys.dont_write_bytecode = True

_ici = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("gc", os.path.join(_ici, "generer-contrats.py"))
g = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(g)


def trace(lignes):
    """A throwaway trace file, in the bench format: `period address direction strobe data space`.

    The periods are generated here: no test depends on them, and writing them by hand would invite
    mistakes without anything saying so."""
    texte = "".join(f"{1000 + 20 * i:10d} {a:06X} {s} {u} {d} {e}\n"
                    for i, (a, s, u, d, e) in enumerate(lignes))
    f = tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False, encoding="utf-8")
    f.write(texte)
    f.close()
    return f.name


def appel(corps, entrée=0xC0044A):
    """A bounded call: an access outside the BIOS ROM, the entry, the body, then the return.

    `découper` bounds a call by the program-space transition, so it has to be framed."""
    return ([(0x000100, "rd", "UL", "0000", "sp"), (entrée, "rd", "UL", "0000", "sp")]
            + corps + [(0x000104, "rd", "UL", "0000", "sp")])


def écrire_contrat(lignes, entrée=0xC0044A):
    """The text of the contract of an entry point, for a fabricated trace."""
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
    """The three paths of `valeur_écrite`, and the resolution of the byte address.

    A BYTE WRITE PUTS THE DATA ON BOTH HALVES OF THE BUS: that is the measured fact that
    makes these tests necessary. Reading the sixteen bits of a `$80` would give `$8080`."""

    def test_octet_pair(self):
        self.assertEqual(g.valeur_écrite("U.", "8080"), "80")
        self.assertEqual(g.site_écrit(0x10FD82, "U."), 0x10FD82)

    def test_octet_impair(self):
        self.assertEqual(g.valeur_écrite(".L", "0101"), "01")
        # The offset of the odd byte: $10FD83, the country code, and not $10FD82, the machine type.
        self.assertEqual(g.site_écrit(0x10FD82, ".L"), 0x10FD83)

    def test_mot(self):
        self.assertEqual(g.valeur_écrite("UL", "1234"), "1234")
        self.assertEqual(g.site_écrit(0x10FD84, "UL"), 0x10FD84)

    def test_sans_strobe_lève(self):
        """A `..` strobe transferred nothing: raise rather than return a wrong value."""
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
    """The §8 guard on tables read in the BIOS ROM.

    THE MUTATION IS OF A SINGLE PARAMETER between the two tests: the length of the sequence read, 5
    words against 3, on either side of the `SEUIL_SEQUENCE` threshold. Two traces that differ in
    anything else would not prove that it is the threshold that decides."""

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
        """The two cases differ only in the length of the sequence."""
        a = self._avec_table(g.SEUIL_SEQUENCE + 1)
        b = self._avec_table(g.SEUIL_SEQUENCE - 1)
        écart = {l for l in a} ^ {l for l in b}
        self.assertTrue(all(0xC05000 <= l[0] <= 0xC05FFF for l in écart), écart)


class ValeursDérivéesDuPc(unittest.TestCase):
    """A pushed return address is a write whose value is a BIOS ROM address.

    §8 keeps these addresses out of the contract, and the table guard does not see them: nothing is
    read in a table, the value comes from the PC."""

    def test_le_mot_haut_et_son_successeur_sortent(self):
        # The writes are placed FAR from the entry, outside the window where `découper` looks for
        # the caller's frame: here the §8 guard is tested, not the bounding.
        texte = écrire_contrat(appel(
            [(0xC0044C + 2 * i, "rd", "UL", "0000", "sp") for i in range(8)]
            + [(0x10F2AE, "WR", "UL", "00C1", "sd"),   # high half of a BIOS ROM address
               (0x10F2B0, "WR", "UL", "1234", "sd")]   # its low half
        ))
        self.assertIn("retenue (§8 : adresse de ROM BIOS)", texte)
        self.assertNotIn("`$00C1`", texte)
        self.assertNotIn("`$1234`", texte)

    def test_insensible_a_l_ordre_d_ecriture(self):
        """The low word can be written before the high one: measured on real SNK BIOS."""
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
    """`grouper` advances by the step of the value: 2 for a word, 1 for a byte.

    A step of 2 admitted on bytes would merge `$10FD80` and `$10FD82` into one range while
    `$10FD81` was never written — the range would assert a write that did not happen."""

    def test_octets_contigus_fusionnent(self):
        self.assertEqual(len(g.grouper([(0x10FD80, "00"), (0x10FD81, "00")])), 1)

    def test_octets_avec_un_trou_ne_fusionnent_pas(self):
        self.assertEqual(len(g.grouper([(0x10FD80, "00"), (0x10FD82, "00")])), 2)

    def test_mots_contigus_fusionnent(self):
        paires = [(0x10FD80, "0000"), (0x10FD82, "0000"), (0x10FD84, "0000")]
        self.assertEqual(g.grouper(paires), [(0x10FD80, 0x10FD84, "0000")])

    def test_un_mot_et_un_octet_ne_fusionnent_pas(self):
        """`$0000` and `$00` are the same number and two widths: the width is to be reproduced."""
        self.assertEqual(len(g.grouper([(0x10FD80, "0000"), (0x10FD82, "00")])), 2)


class OctetDeRemplissage(unittest.TestCase):
    """A word whose two bytes are equal is the same fill as that byte.

    Without this normalisation, a single `$00` site among hundreds of `$0000` was enough to
    silence the fill guard."""

    def test_un_octet(self):
        self.assertEqual(g.octet_de_remplissage("55"), "55")

    def test_un_mot_repete(self):
        self.assertEqual(g.octet_de_remplissage("5555"), "55")
        self.assertEqual(g.octet_de_remplissage("0000"), "00")

    def test_un_mot_non_repete_n_est_pas_un_remplissage(self):
        self.assertIsNone(g.octet_de_remplissage("1234"))


class PointEntréePublic(unittest.TestCase):
    """Only the slots of the public jump table are published as entry points."""

    def test_les_crans_connus(self):
        for adresse in (0xC00402, 0xC00438, 0xC0044A, 0xC00450, 0xC004C2, 0xC006FC):
            self.assertTrue(g.point_entrée_public(adresse), f"${adresse:06X}")

    def test_hors_grille(self):
        """An internal address — a return after a `jsr` from the BIOS to the game — is refused."""
        self.assertFalse(g.point_entrée_public(0xC0044C))
        self.assertFalse(g.point_entrée_public(0xC00500))

    def test_hors_bornes(self):
        self.assertFalse(g.point_entrée_public(0xC00400))
        self.assertFalse(g.point_entrée_public(0xC00702))


class Zones(unittest.TestCase):
    """`zone` returns the narrowest range, not the first of the list."""

    def test_le_plus_etroit_gagne(self):
        # $3A0003 is in `controle_hc259`, itself included in `registres_systeme`.
        self.assertEqual(g.zone(0x3A0003), "controle_hc259")

    def test_hors_carte(self):
        self.assertIsNone(g.zone(0xF00000))



# ---------------------------------------------------------------------------------------------
# THE TWO PATHS THE TESTS ABOVE DID NOT TOUCH, and a review showed it:
# `contrat_boot` and `main`. Two of the four guards live there, and four mutations survived the
# first 23 tests — among them the removal of `o not in pc` in `contrat_boot`, which IS the defect
# that round 5 had fixed. A test that does not cover the path of a fix does not protect that
# fix.
# ---------------------------------------------------------------------------------------------


def écrire_boot(lignes):
    """The text of the power-on contract, for a fabricated trace."""
    chemin = trace(lignes)
    try:
        accès = g.lire_trace(chemin)
        with tempfile.TemporaryDirectory() as d:
            with io.open(g.contrat_boot(accès, d), encoding="utf-8") as f:
                return f.read()
    finally:
        os.unlink(chemin)


class ContratDeBoot(unittest.TestCase):
    """The guards of the `--boot` mode, which each had their surviving mutation."""

    def test_le_garde_pc_s_applique_au_boot(self):
        """The defect of round 5: `contrat_boot` published the pushed return address."""
        texte = écrire_boot([
            (0x000000, "rd", "UL", "0000", "sp"),
            (0x10FF00, "WR", "UL", "00C1", "sd"),   # high half of a BIOS ROM address
            (0x10FF02, "WR", "UL", "1234", "sd"),   # its low half
            (0x10FE00, "WR", "UL", "ABCD", "sd"),   # an ordinary value, which must remain
        ])
        self.assertNotIn("`$00C1`", texte)
        self.assertNotIn("`$1234`", texte)
        self.assertIn("site(s) de RAM BIOS sont écartés", texte)
        self.assertIn("`$ABCD`", texte)

    def test_le_garde_des_tables_s_applique_au_boot(self):
        """A table read in the ROM withholds the values, on the boot side too."""
        texte = écrire_boot(
            [(0x000000, "rd", "UL", "0000", "sp")]
            + [(0xC05000 + 2 * i, "rd", "UL", "0000", "sd") for i in range(g.SEUIL_SEQUENCE + 1)]
            + [(0x10FE00, "WR", "UL", "ABCD", "sd")]
        )
        self.assertIn("Retenu", texte)
        self.assertNotIn("`$ABCD`", texte)

    def test_un_remplissage_n_est_pas_un_etat(self):
        """All the sites at the same fill byte: the contract refuses to speak of a state."""
        texte = écrire_boot(
            [(0x000000, "rd", "UL", "0000", "sp")]
            + [(0x10FE00 + 2 * i, "WR", "UL", "5555", "sd") for i in range(6)]
        )
        self.assertIn("ce n'est pas un état, c'est un remplissage".upper()[:20].lower(),
                      texte.lower())
        self.assertIn("`$55`", texte)

    def test_des_valeurs_distinctes_donnent_un_etat(self):
        """The control of the previous test: two different fill bytes, hence a state."""
        texte = écrire_boot([
            (0x000000, "rd", "UL", "0000", "sp"),
            (0x10FE00, "WR", "UL", "5555", "sd"),
            (0x10FE02, "WR", "UL", "1234", "sd"),
        ])
        self.assertNotIn("remplissage", texte)
        self.assertIn("`$1234`", texte)

    def test_la_poignee_de_main_resout_l_octet(self):
        """`$3A0003` and not `$3A0002`: the HC259 register is chosen by the byte address."""
        texte = écrire_boot([
            (0x000000, "rd", "UL", "0000", "sp"),
            (0x3A0002, "WR", ".L", "0000", "sd"),
        ])
        self.assertIn("`$3A0003`", texte)
        self.assertNotIn("| `$3A0002` |", texte)


class FiltreDesPointsEntrée(unittest.TestCase):
    """`main` does not publish an entry point outside the public jump table.

    Its address would be internal to the BIOS ROM, and it would appear in the title of the document
    as in its file name."""

    @staticmethod
    def _publie(entrée):
        """The files `main` writes for a trace whose call enters at `entrée`."""
        chemin = trace(appel([(0x10FD90, "WR", "UL", "1234", "sd")], entrée=entrée))
        try:
            with tempfile.TemporaryDirectory() as d:
                # `main` writes to stdout and stderr: they are redirected so that the output of the
                # tests stays readable, not to hide anything.
                with contextlib.redirect_stdout(io.StringIO()), \
                     contextlib.redirect_stderr(io.StringIO()):
                    g.main(["gen", chemin, d])
                return sorted(os.listdir(d))
        finally:
            os.unlink(chemin)

    def test_un_cran_de_la_table_est_publie(self):
        self.assertEqual(self._publie(0xC0044A), ["appel_C0044A.md"])

    def test_une_adresse_interne_ne_l_est_pas(self):
        """`$C0044C` follows `$C0044A` by two bytes: it is inside the code, not a slot."""
        self.assertEqual(self._publie(0xC0044C), [])


class SeuilDesSéquences(unittest.TestCase):
    """The threshold is **pinned**, not just bracketed.

    The `GardeDesTables` tests try SEUIL_SEQUENCE + 1 and SEUIL_SEQUENCE - 1, which lets
    a `>=` changed into `>` through: a table of exactly the threshold length would then be published
    in clear. A review measured it."""

    def test_a_la_longueur_exacte_du_seuil_les_valeurs_sortent(self):
        texte = écrire_contrat(GardeDesTables._avec_table(g.SEUIL_SEQUENCE))
        self.assertIn("retenue (§8)", texte)
        self.assertNotIn("`$AB00`", texte)



# ---------------------------------------------------------------------------------------------
# THE END BOUND OF A CALL, which the tests above did not touch: six mutations out of seven
# survived there, among them the publication of an internal return address. A review measured it.
# ---------------------------------------------------------------------------------------------


# THE INTERNAL ADDRESS OF THE FIXTURES IS FABRICATED — `$C10004`, not that of a real BIOS. Earlier
# lots twice copied a measured address into the text that describes it; a fixture
# needs only an address INSIDE the range `$C00000`-`$C1FFFF`, not the right one.


def délimiter(lignes):
    """The calls a split finds in a fabricated trace, stderr swallowed."""
    chemin = trace(lignes)
    try:
        with contextlib.redirect_stderr(io.StringIO()) as err:
            ap = g.découper(g.lire_trace(chemin))
        return ap, err.getvalue()
    finally:
        os.unlink(chemin)


class BorneDeFinDAppel(unittest.TestCase):
    """The exit of a call follows the pushed address, not the exit from the BIOS ROM."""

    def test_un_jsr_ferme_sur_l_adresse_empilee(self):
        ap, _ = délimiter([
            (0x000100, "rd", "UL", "0000", "sp"),
            (0xC0044A, "rd", "UL", "0000", "sp"),
            (0x10F2BA, "WR", "UL", "0000", "sd"),   # the `jsr` pushes the return…
            (0x10F2BC, "WR", "UL", "026A", "sd"),   # … that is $00026A
            (0xC0044C, "rd", "UL", "0000", "sp"),
            (0x00026A, "rd", "UL", "0000", "sp"),
        ])
        self.assertEqual([a["retour"] for a in ap], [0x00026A])

    def test_une_interruption_ferme_dans_le_bios(self):
        """An `rte` returns control INSIDE the BIOS: no transition marks it.

        THE FRAME DEPTH IS THE ONE THAT WAS MEASURED: -15, -13 and -12 accesses from the entry, the
        eight fetches of the cartridge stub and the read of the vector accounting for most of
        the gap. A fixture that placed it at -2 would pass with a much shorter `avant` window,
        and the eight real calls to `$C00438` would then fall back on the fallback without any
        test saying so — measured."""
        ap, _ = délimiter(
            [(0xC10000, "rd", "UL", "0000", "sp"),   # the BIOS is running
             (0x10F2FA, "WR", "UL", "0004", "sd"),   # the exception pushes the low PC…
             (0xFFFFF2, "rd", "UL", "0000", "cs"),   # … the interrupt acknowledge…
             (0x10F2F6, "WR", "UL", "2000", "sd"),   # … then SR…
             (0x10F2F8, "WR", "UL", "00C1", "sd"),   # … then the high PC: $C10004
             (0x000064, "rd", "UL", "0000", "sd"),   # the autovector vector
             (0x000066, "rd", "UL", "0000", "sd")]
            # The eight fetches of the cartridge stub, which make the depth of the frame.
            + [(0x000200 + 2 * i, "rd", "UL", "0000", "sp") for i in range(8)]
            + [(0xC00438, "rd", "UL", "0000", "sp"),   # the handler's entry
               (0xC0043A, "rd", "UL", "0000", "sp"),
               (0xC10004, "rd", "UL", "0000", "sp"),   # the `rte`: return into the BIOS
               (0xC10006, "rd", "UL", "0000", "sp")]
        )
        self.assertEqual([(a["entrée"], a["retour"]) for a in ap], [(0xC00438, 0xC10004)])

    def test_une_sous_routine_du_jeu_ne_vole_pas_la_borne(self):
        """Regression: a frame already alive on the stack closed the call too early.

        The game calls a subroutine, which calls the BIOS. Two frames are in the window;
        only the one written AFTER the entry belongs to this call."""
        ap, _ = délimiter([
            (0x000100, "rd", "UL", "0000", "sp"),
            (0x10F2BE, "WR", "UL", "0000", "sd"),   # the game pushes the return of ITS subroutine
            (0x10F2C0, "WR", "UL", "0106", "sd"),
            (0x000500, "rd", "UL", "0000", "sp"),
            (0xC0044A, "rd", "UL", "0000", "sp"),
            (0x10F2BA, "WR", "UL", "0000", "sd"),   # the BIOS `jsr` pushes $000504
            (0x10F2BC, "WR", "UL", "0504", "sd"),
            (0xC0044C, "rd", "UL", "0000", "sp"),
            (0x000504, "rd", "UL", "0000", "sp"),   # the BIOS returns control to the subroutine
            (0x000106, "rd", "UL", "0000", "sp"),
        ])
        self.assertEqual([a["retour"] for a in ap], [0x000504])

    def test_un_cadre_imbrique_hors_fenetre_est_ignore(self):
        """The frame of a `jsr` internal to the BIOS falls beyond `après`, so it is not a candidate.

        THAT IS WHAT MAKES THE ORDER OF THE LATER CANDIDATES IRRELEVANT, and not a priority
        rule: a nested call must let the BIOS execute a few instructions before its
        own `jsr`, so its frame leaves the window. This test checks that the frame at +4/+5 is
        ignored; it does **not** test an arbitration between two later candidates, which does not
        exist on an entry of the jump table."""
        ap, _ = délimiter([
            (0x000100, "rd", "UL", "0000", "sp"),
            (0xC0044A, "rd", "UL", "0000", "sp"),
            (0x10F2BA, "WR", "UL", "0000", "sd"),   # the game's `jsr` pushes $00026A
            (0x10F2BC, "WR", "UL", "026A", "sd"),
            (0xC0044C, "rd", "UL", "0000", "sp"),
            (0x10F2B6, "WR", "UL", "00C0", "sd"),   # an internal `jsr` pushes $C00500
            (0x10F2B8, "WR", "UL", "0500", "sd"),
            (0xC00600, "rd", "UL", "0000", "sp"),
            (0xC00500, "rd", "UL", "0000", "sp"),   # the internal `rts`
            (0x00026A, "rd", "UL", "0000", "sp"),   # the call's `rts`
        ])
        self.assertEqual([a["retour"] for a in ap], [0x00026A])

    def test_la_borne_est_le_premier_fetch_du_retour(self):
        """The caller may pass its return address several times: the bound is the
        first.

        Without this test, taking the second occurrence passed the 39 others — and changed **all**
        the call sizes of the two real traces, measured."""
        ap, _ = délimiter([
            (0x000100, "rd", "UL", "0000", "sp"),
            (0xC0044A, "rd", "UL", "0000", "sp"),
            (0x10F2BA, "WR", "UL", "0000", "sd"),
            (0x10F2BC, "WR", "UL", "026A", "sd"),
            (0xC0044C, "rd", "UL", "0000", "sp"),
            (0x00026A, "rd", "UL", "0000", "sp"),   # the return: the bound is HERE
            (0x00026C, "rd", "UL", "0000", "sp"),
            (0x00026A, "rd", "UL", "0000", "sp"),   # the caller passes there again, a loop
        ])
        self.assertEqual(len(ap), 1)
        # Four accesses from the entry: the first $00026A, not the second.
        self.assertEqual(ap[0]["à"] - ap[0]["de"], 4)

    def test_sans_cadre_le_repli_se_signale(self):
        """The fallback takes back a bound that can be worth a frame: it must not be silent."""
        ap, err = délimiter([
            (0x000100, "rd", "UL", "0000", "sp"),
            (0xC00444, "rd", "UL", "0000", "sp"),   # entered by `jmp`: nothing is pushed
            (0xC00446, "rd", "UL", "0000", "sp"),
            (0x000122, "rd", "UL", "0000", "sp"),
        ])
        self.assertEqual([a["retour"] for a in ap], [0x000122])
        self.assertIn("repli", err)


class RetourInterneAuBios(unittest.TestCase):
    """§8: a return address in the BIOS ROM is not published.

    An interrupt handler comes back where the BIOS had been interrupted, so its return is
    an internal address. No earlier guard covered it: they bear on the written
    values, not on the return address the contract announces at its head."""

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
        """The control: without it the previous test would pass by never publishing anything."""
        texte = écrire_contrat(appel([(0x10FD95, "WR", "U.", "1111", "sd")]))
        self.assertIn("- Retour vers : `$000104`", texte)


class AucunAppelFerme(unittest.TestCase):
    """`contrat()` returned `min()` on an empty list when no call closed."""

    def test_contrat_rend_none(self):
        chemin = trace([
            (0x000100, "rd", "UL", "0000", "sp"),
            (0xC0044A, "rd", "UL", "0000", "sp"),
            (0x10F2BA, "WR", "UL", "00FF", "sd"),   # a return to $00FFFFFF…
            (0x10F2BC, "WR", "UL", "FFFF", "sd"),   # … where the PC never goes
            (0xC0044C, "rd", "UL", "0000", "sp"),   # and no exit from the ROM afterwards
        ])
        try:
            accès = g.lire_trace(chemin)
            with contextlib.redirect_stderr(io.StringIO()):
                appels = g.découper(accès)
            self.assertIsNone(g.contrat(accès, appels, 0xC0044A))
        finally:
            os.unlink(chemin)


class ÉcrituresDeLaCartouche(unittest.TestCase):
    """A write made while the cartridge has control does not enter the contract.

    Measured at the START of `puzzledp`: the call to `$C0044A` of frame 560.23 hands control to the
    cartridge along the way, and 15,025 of its 16,612 writes are the game's start of play
    session — the contract weighed 604 KB and drowned the 42 BIOS writes. The criterion is that of
    `la_main_au_bios`: the last program-space access says who writes."""

    def _trace_avec_excursion(self):
        return [
            (0x000100, "rd", "UL", "0000", "sp"),   # the game is running
            (0xC0044A, "rd", "UL", "0000", "sp"),   # the entry
            (0x10F2BA, "WR", "UL", "0000", "sd"),   # the `jsr` pushes $00026A
            (0x10F2BC, "WR", "UL", "026A", "sd"),
            (0xC0044C, "rd", "UL", "0000", "sp"),
            (0x10FD90, "WR", "UL", "1234", "sd"),   # BIOS write: in the contract
            (0x000300, "rd", "UL", "0000", "sp"),   # the BIOS hands control to the cartridge…
            (0x100100, "WR", "UL", "5678", "sd"),   # … which writes in its own space: out of the contract
            (0x000302, "rd", "UL", "0000", "sp"),
            (0xC00800, "rd", "UL", "0000", "sp"),   # the cartridge hands control back to the BIOS
            (0x10FD92, "WR", "UL", "9ABC", "sd"),   # BIOS write, after resuming: in the contract
            (0x00026A, "rd", "UL", "0000", "sp"),   # the return, the bound
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
    """A contract is computed on the union of the calls of all the given traces.

    It is a matter of correctness: a write stable over the calls of a single window may
    be stable only in its regime, and a wrong hard contract would make the implementer hard-code
    the value. The founding case: `$C0044A` seen from the BIOS waiting and seen from the game
    running."""

    def _appel_qui_écrit(self, valeur):
        return [
            (0x000100, "rd", "UL", "0000", "sp"),
            (0xC0044A, "rd", "UL", "0000", "sp"),
            (0x10F2BA, "WR", "UL", "0000", "sd"),   # the `jsr` pushes $00026A
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
            # Two calls, one per trace; the value, stable in each window taken alone,
            # is plural on the union — that is what the merge must reveal.
            self.assertIn("Relevé sur **2 appel(s)**", texte)
            self.assertIn("2 valeurs : `$1111`, `$2222`", texte)
        finally:
            os.unlink(t1)
            os.unlink(t2)


def écrire_protocole_doc(lignes, sites):
    """The text of the protocol document, for a fabricated trace and tracked sites."""
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
    """The `--protocole` mode: chronicle of the tracked sites and of the hand-overs.

    `USER` has no call contract — the BIOS writes before the hand-over fall
    outside any bounded call, and it is this mode that records them (`docs/tasks.md`, task USER)."""

    # A hand-over by `jmp`: entry at slot $C00444, write of a tracked site, exit by `jmp`
    # to $000122 — no frame pushed, so the call closes by fallback.
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
        """The control: a call closed by a frame (`jsr`/`rts`) belongs to the call contracts."""
        texte = écrire_protocole_doc([
            (0x000100, "rd", "UL", "0000", "sp"),
            (0xC0044A, "rd", "UL", "0000", "sp"),
            (0x10F2BA, "WR", "UL", "0000", "sd"),   # the `jsr` pushes $00026A
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
        """A pair of words forming a BIOS ROM address: the value goes, the site stays."""
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
        """Tracking `$10FDAF` must see the word written at `$10FDAE` go by, which covers both bytes."""
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
        """A BIOS that polls a port reads it in a loop: the chronicle carries the fact, no byte."""
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


# THE SINE TABLE. Another generator, `generer-sinus.py`, tested here so that stage 0
# of `non-regression.sh` covers it without one more stage: is the versioned `.s` really its output?
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
        self.assertEqual(t[32], 0xB505)                       # 65536 · sin(π/4) = 46340.95
        for i in range(256):
            self.assertEqual(t[i], t[(i + 128) % 256])         # |sin|: period of half a turn
            self.assertEqual(t[i], t[(128 - i) % 256])         # symmetry around the quarter turn

    def test_une_ligne_par_huit_mots_indice_unique(self):
        lignes = [l for l in gs.source().splitlines() if ".word" in l]
        self.assertEqual(len(lignes), 32)
        self.assertEqual(len(set(lignes)), 32)                 # the mutations target one line


if __name__ == "__main__":
    unittest.main(verbosity=2)
