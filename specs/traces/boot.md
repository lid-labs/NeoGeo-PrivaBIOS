# Mise sous tension

**Généré par `bench/generer-contrats.py --boot`. Ne pas éditer à la main.**

- Relevé sur les trames 0.000 à 9.215
- 400000 accès tracés

## Le vecteur de reset

Les premiers accès du 68000, en espace programme, avant toute autre chose :

| Adresse | Octets |
|---|---|
| `$000000` | UL |
| `$000002` | UL |
| `$000004` | UL |
| `$000006` | UL |

Puis le premier fetch dans la ROM du BIOS tombe à **`$C00402`** — le point d'entrée.

## La poignée de main

Les écritures de registre du HC259, dans l'ordre. C'est **tout** ce que le boot y écrit sur la fenêtre relevée :

Le HC259 est un verrou adressé : **c'est l'adresse qui porte l'ordre**, et la donnée du bus est ignorée. La colonne est donnée pour mémoire, pas comme une valeur à reproduire.

| Trame | Octet écrit | Registre | Donnée du bus |
|---|---|---|---|
| 0.014 | `$3A0003` | `0x03` | `$00` |
| 0.014 | `$3A000B` | `0x0b` | `$00` |

## Ce que la RAM et les registres reçoivent

| Zone | Écritures | Adresses distinctes |
|---|---|---|
| controle_hc259 | 2 | 2 |
| lspc | 2 | 2 |
| pile | 1271 | 1271 |
| ram_bios | 393 | 393 |
| ram_jeu | 31190 | 31104 |
| registres_systeme | 53049 | 5 |

## Ce que la RAM BIOS reçoit de constant sur la fenêtre

**Ce n'est pas un état, c'est un remplissage** : les 393 sites de RAM BIOS écrits sur cette fenêtre répètent **tous** l'octet `$55`. Une valeur unique sur toute la zone est la signature d'un motif de test mémoire ou d'un vidage, pas d'un état à reproduire — sur un dump SNK, les premières trames écrivent `0x55`, puis `0xAA`, puis une valeur dérivée de l'adresse, et les variables du BIOS ne valent quelque chose qu'à partir de la trame ~300.

La fenêtre de ce relevé s'arrête à la trame 9.21. **Pour obtenir l'état, il faut une fenêtre plus tardive**, et ce contrat ne la porte pas.

**Ce que ce garde ne voit pas**, et qui doit rester en tête : un motif qui **varie avec l'adresse** — le troisième du test mémoire de SNK en est un — ne répète aucun octet, donc il échappe au garde et serait présenté comme un état.

**Le verdict se pèse au compte**, et le garde ne le fait pas à votre place : il parle dès deux sites. Ici il y en a 393, ce qui rend la conclusion solide ; sur deux ou trois, une valeur commune ne dirait pas grand-chose et c'est au relecteur d'en juger.

## Séquences lues dans la ROM du BIOS

Aucune suite de 4 mots contigus ou plus lue en espace donnée. Rien à trancher.

## Ce que ce contrat ne dit pas

- **Ni les adresses internes de la ROM du BIOS, ni la suite de ses fetchs** : `DECISIONS.md` §8 les garde hors du contrat. Seul le point d'entrée y figure.
- **Aucune valeur lue n'est portée directement** : le banc ne pose aucune donnée sur le bus pour une lecture. Cela ne suffit pas à tenir §8 — une valeur lue puis empilée ressort dans la donnée d'une écriture —, d'où les gardes.
- **Ni l'ordre des écritures en RAM**, hors poignée de main.
