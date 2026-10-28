| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| HARNAIS DE CHAÎNE — ce n'est PAS la couche 0, et ça ne prétend rien faire démarrer.
|
| Son seul rôle est de prouver que `build/construire.sh` produit une image que le co-simulateur
| (non publié) charge et que le 68000 exécute : il écrit un motif reconnaissable en RAM, puis boucle. Si la trace du
| co-simulateur porte cette écriture, la chaîne va de la source à l'image chargée.
|
| Il ne donne volontairement aucun coup de pied au watchdog : le banc doit donc le réinitialiser
| toutes les huit trames (I3), ce qui se vérifie dans la même trace.
|
| Écrire le BIOS revient à des agents d'implémentation (`docs/DECISIONS.md` §1). Ce fichier est de
| l'outillage, pas une implémentation.

        .section .vectors, "a"
        .long   0x10F300        | pile superviseur, sous la RAM BIOS
        .long   _reset          | vecteur de reset : où le 68000 saute

        .text
        .global _reset
_reset:
        move.w  #0x5A17, 0x100000   | le motif, à la première adresse de RAM de travail
boucle:
        bra.s   boucle
