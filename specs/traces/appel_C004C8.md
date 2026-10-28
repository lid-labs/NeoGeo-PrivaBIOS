# Appel `$C004C8`

**Généré par `bench/generer-contrats.py`. Ne pas éditer à la main** : le contrat tire son autorité de la trace, et une retouche la lui retire.

- Relevé sur **4 appel(s)**, trames 245.95 à 562.68 — les siennes, non celles de toute la trace
- Taille, en accès tracés : 6344, 6344, 6344, 6344
- Retour vers : `$0009BE`, `$0094EA`, `$011658`

## Écritures communes à tous les appels

Le noyau du contrat : ce que l'appel écrit à chaque fois.

| Adresse | Zone | Valeur écrite |
|---|---|---|
| `$3C0000` | lspc | 2 valeurs : `$0000`, `$8000` |
| `$3C0002` | lspc | 4 valeurs : `$0000`, `$00FF`, `$0FFF`, `$BE00` |
| `$3C0004` | lspc | 2 valeurs : `$0001`, `$0002` |

## Écritures d'une partie des appels seulement

À ne pas prendre pour le contrat : ces adresses dépendent d'un état que la trace ne montre pas.

| Adresse | Zone | Appels | Valeur écrite |
|---|---|---|---|
| `$10F2B0` | ram_jeu | 2/4 | retenue (§8 : adresse de ROM BIOS) |
| `$10F2B2` | ram_jeu | 2/4 | retenue (§8 : adresse de ROM BIOS) |
| `$10F2B4` | ram_jeu | 2/4 | 2 valeurs : `$0000`, `$0001` |
| `$10F2B6` | ram_jeu | 2/4 | 2 valeurs : `$1658`, `$94EA` |
| `$10F2F8` | ram_jeu | 2/4 | retenue (§8 : adresse de ROM BIOS) |
| `$10F2FA` | ram_jeu | 2/4 | retenue (§8 : adresse de ROM BIOS) |
| `$10F2FC` | ram_jeu | 2/4 | `$0000` |
| `$10F2FE` | ram_jeu | 2/4 | `$09BE` |

## Séquences lues dans la ROM du BIOS

Aucune suite de 4 mots contigus ou plus. Rien à trancher.

## Ce que ce contrat ne dit pas

- **Aucune valeur lue n'est portée directement** : le banc ne pose aucune donnée sur le bus pour une lecture, donc une lecture n'a pas de valeur observable. **Cela ne suffit pas à tenir §8** : une valeur lue puis empilée ou recopiée ressort dans la donnée d'une écriture, et c'est pourquoi les gardes ci-dessous existent.
- **4 site(s) ont leur valeur retenue parce qu'elle porte une adresse interne de la ROM du BIOS** : un `jsr` interne empile son adresse de retour, et §8 garde ces adresses hors du contrat. L'adresse de l'écriture reste, sa valeur non. Ces sites sont pour l'essentiel la **pile du BIOS**, que rien n'oblige une autre implémentation à reproduire — elle empilera ses propres adresses.
- **La signature de l'appel non plus.** Les paramètres passent par les registres du 68000, que le bus ne montre pas : une trace donne les effets d'un appel, pas sa signature.
- **Le nom de l'appel non plus** : ce document le désigne par son offset. La correspondance avec un nom est de la documentation publique.
