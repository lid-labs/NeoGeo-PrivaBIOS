# Appel `$C00450`

**Généré par `bench/generer-contrats.py`. Ne pas éditer à la main** : le contrat tire son autorité de la trace, et une retouche la lui retire.

- Relevé sur **69 appel(s)**, trames 250.90 à 5330.90 — les siennes, non celles de toute la trace
- Taille, en accès tracés : 56, 56, 56, 56, 56, 56, 56, 56, 56, 56, 56, 56, 56, 56, 56, 56, 56, 56, 63, 63, 63, 63, 63, 63, 63, 63, 63, 63, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65
- Retour vers : `$0013FC`, `$001BF8`, `$001C10`

## Écritures communes à tous les appels

Le noyau du contrat : ce que l'appel écrit à chaque fois.

| Adresse | Zone | Valeur écrite |
|---|---|---|
| `$10FDB2` | ram_bios | `$0000` |

## Écritures d'une partie des appels seulement

À ne pas prendre pour le contrat : ces adresses dépendent d'un état que la trace ne montre pas.

| Adresse | Zone | Appels | Valeur écrite |
|---|---|---|---|
| `$10F2E6` | ram_jeu | 18/69 | retenue (§8 : adresse de ROM BIOS) |
| `$10F2E8` | ram_jeu | 18/69 | retenue (§8 : adresse de ROM BIOS) |
| `$10F2EA` | ram_jeu | 36/69 | `$0000` |
| `$10F2EC` | ram_jeu | 36/69 | 2 valeurs : `$1BF8`, `$1C10` |
| `$10F2F4` | ram_jeu | 33/69 | retenue (§8 : adresse de ROM BIOS) |
| `$10F2F6` | ram_jeu | 33/69 | retenue (§8 : adresse de ROM BIOS) |
| `$10F2F8` | ram_jeu | 33/69 | `$0000` |
| `$10F2FA` | ram_jeu | 33/69 | `$13FC` |
| `$10FDB0` | ram_bios | 28/69 | `$00` |
| `$10FDB1` | ram_bios | 51/69 | `$00` |

## Séquences lues dans la ROM du BIOS

Aucune suite de 4 mots contigus ou plus. Rien à trancher.

## Ce que ce contrat ne dit pas

- **Aucune valeur lue n'est portée directement** : le banc ne pose aucune donnée sur le bus pour une lecture, donc une lecture n'a pas de valeur observable. **Cela ne suffit pas à tenir §8** : une valeur lue puis empilée ou recopiée ressort dans la donnée d'une écriture, et c'est pourquoi les gardes ci-dessous existent.
- **4 site(s) ont leur valeur retenue parce qu'elle porte une adresse interne de la ROM du BIOS** : un `jsr` interne empile son adresse de retour, et §8 garde ces adresses hors du contrat. L'adresse de l'écriture reste, sa valeur non. Ces sites sont pour l'essentiel la **pile du BIOS**, que rien n'oblige une autre implémentation à reproduire — elle empilera ses propres adresses.
- **La signature de l'appel non plus.** Les paramètres passent par les registres du 68000, que le bus ne montre pas : une trace donne les effets d'un appel, pas sa signature.
- **Le nom de l'appel non plus** : ce document le désigne par son offset. La correspondance avec un nom est de la documentation publique.
