# Appel `$C004C2`

**Généré par `bench/generer-contrats.py`. Ne pas éditer à la main** : le contrat tire son autorité de la trace, et une retouche la lui retire.

- Relevé sur **8 appel(s)**, trames 245.77 à 563.65 — les siennes, non celles de toute la trace
- Taille, en accès tracés : 5173, 5173, 5173, 5173, 5173, 5173, 6279, 6279
- Retour vers : `$0009B2`, `$00118C`, `$003292`, `$006FE2`, `$01164C`
- **180 écriture(s) hors contrat** : faites pendant que la cartouche avait la main (dernier accès en espace programme hors de la ROM du BIOS). L'appel la lui a rendue en cours de route ; ces écritures sont le comportement du jeu, pas celui du BIOS

## Écritures communes à tous les appels

Le noyau du contrat : ce que l'appel écrit à chaque fois.

| Adresse | Zone | Valeur écrite |
|---|---|---|
| `$3C0000` | lspc | 2 valeurs : `$7000`, `$7020` |
| `$3C0002` | lspc | 2 valeurs : `$0020`, `$00FF` |
| `$3C0004` | lspc | `$0001` |

## Écritures d'une partie des appels seulement

À ne pas prendre pour le contrat : ces adresses dépendent d'un état que la trace ne montre pas.

| Adresse | Zone | Appels | Valeur écrite |
|---|---|---|---|
| `$10F2A6` | ram_jeu | 2/8 | retenue (§8 : adresse de ROM BIOS) |
| `$10F2A8` | ram_jeu | 2/8 | retenue (§8 : adresse de ROM BIOS) |
| `$10F2AA` | ram_jeu | 2/8 | retenue (§8 : adresse de ROM BIOS) |
| `$10F2AC` | ram_jeu | 2/8 | retenue (§8 : adresse de ROM BIOS) |
| `$10F2AE` | ram_jeu | 2/8 | retenue (§8 : adresse de ROM BIOS) |
| `$10F2B0` | ram_jeu | 5/8 | retenue (§8 : adresse de ROM BIOS) |
| `$10F2B2` | ram_jeu | 5/8 | retenue (§8 : adresse de ROM BIOS) |
| `$10F2B4` | ram_jeu | 5/8 | 3 valeurs : `$0000`, `$0001`, `$026A` |
| `$10F2B6` | ram_jeu | 3/8 | 2 valeurs : `$164C`, `$3292` |
| `$10F2F0` | ram_jeu | 1/8 | retenue (§8 : adresse de ROM BIOS) |
| `$10F2F2` | ram_jeu | 3/8 | retenue (§8 : adresse de ROM BIOS) |
| `$10F2F4` | ram_jeu | 3/8 | retenue (§8 : adresse de ROM BIOS) |
| `$10F2F6` | ram_jeu | 3/8 | retenue (§8 : adresse de ROM BIOS) |
| `$10F2F8` | ram_jeu | 4/8 | retenue (§8 : adresse de ROM BIOS) |
| `$10F2FA` | ram_jeu | 4/8 | retenue (§8 : adresse de ROM BIOS) |
| `$10F2FC` | ram_jeu | 4/8 | `$0000` |
| `$10F2FE` | ram_jeu | 4/8 | 2 valeurs : `$09B2`, `$118C` |
| `$10FD95` | ram_bios | 2/8 | `$00` |
| `$10FD96` | ram_bios | 2/8 | `$00` |
| `$10FD97` | ram_bios | 2/8 | `$00` |
| `$10FD98` | ram_bios | 2/8 | `$00` |
| `$10FD99` | ram_bios | 2/8 | 2 valeurs : `$00`, `$03` |
| `$10FD9B` | ram_bios | 2/8 | `$00` |
| `$10FD9C` | ram_bios | 2/8 | `$00` |
| `$10FD9D` | ram_bios | 2/8 | `$00` |
| `$10FD9E` | ram_bios | 2/8 | `$00` |
| `$10FD9F` | ram_bios | 2/8 | 2 valeurs : `$00`, `$03` |
| `$10FDA1` | ram_bios | 2/8 | `$00` |
| `$10FDA2` | ram_bios | 2/8 | `$0000` |
| `$10FDA4` | ram_bios | 2/8 | `$0000` |
| `$10FDA7` | ram_bios | 2/8 | `$00` |
| `$10FDA8` | ram_bios | 2/8 | `$0000` |
| `$10FDAA` | ram_bios | 2/8 | `$0000` |
| `$10FDAC` | ram_bios | 2/8 | `$00` |
| `$10FDAD` | ram_bios | 2/8 | `$00` |
| `$10FE88` | ram_bios | 2/8 | `$0000` |
| `$10FE8A` | ram_bios | 2/8 | 2 valeurs : `$0009`, `$010B` |
| `$10FEDC` | ram_bios | 2/8 | `$00` |
| `$10FEDD` | ram_bios | 2/8 | `$00` |
| `$10FEDE` | ram_bios | 2/8 | `$00` |
| `$10FEDF` | ram_bios | 2/8 | `$00` |
| `$10FEE1` | ram_bios | 2/8 | `$08` |
| `$10FEE8` | ram_bios | 2/8 | `$0000` |
| `$10FEEA` | ram_bios | 2/8 | `$0000` |
| `$10FEEC` | ram_bios | 2/8 | 2 valeurs : `$0000`, `$0003` |
| `$10FEEE` | ram_bios | 2/8 | `$0000` |
| `$10FEF0` | ram_bios | 2/8 | `$0000` |
| `$10FEF2` | ram_bios | 2/8 | 2 valeurs : `$0000`, `$0003` |
| `$380001` | registres_systeme | 2/8 | 3 valeurs : `$00`, `$12`, `$1B` |
| `$380031` | registres_systeme | 2/8 | 2 valeurs : `$DF`, `$FF` |
| `$380041` | registres_systeme | 2/8 | `$FF` |
| `$3800E1` | registres_systeme | 2/8 | `$10` |
| `$3A000D` | controle_hc259 | 2/8 | sans objet — verrou adressé |
| `$3A001D` | controle_hc259 | 2/8 | sans objet — verrou adressé |
| `$D00020` | backup_ram | 2/8 | `$C1` |
| `$D00021` | backup_ram | 2/8 | 2 valeurs : `$41`, `$C1` |
| `$D00022` | backup_ram | 2/8 | `$00` |
| `$D00038` | backup_ram | 2/8 | `$1C` |
| `$D0005D` | backup_ram | 2/8 | 2 valeurs : `$21`, `$33` |

## Séquences lues dans la ROM du BIOS

Aucune suite de 4 mots contigus ou plus. Rien à trancher.

## Ce que ce contrat ne dit pas

- **Aucune valeur lue n'est portée directement** : le banc ne pose aucune donnée sur le bus pour une lecture, donc une lecture n'a pas de valeur observable. **Cela ne suffit pas à tenir §8** : une valeur lue puis empilée ou recopiée ressort dans la donnée d'une écriture, et c'est pourquoi les gardes ci-dessous existent.
- **14 site(s) ont leur valeur retenue parce qu'elle porte une adresse interne de la ROM du BIOS** : un `jsr` interne empile son adresse de retour, et §8 garde ces adresses hors du contrat. L'adresse de l'écriture reste, sa valeur non. Ces sites sont pour l'essentiel la **pile du BIOS**, que rien n'oblige une autre implémentation à reproduire — elle empilera ses propres adresses.
- **La signature de l'appel non plus.** Les paramètres passent par les registres du 68000, que le bus ne montre pas : une trace donne les effets d'un appel, pas sa signature.
- **Le nom de l'appel non plus** : ce document le désigne par son offset. La correspondance avec un nom est de la documentation publique.
