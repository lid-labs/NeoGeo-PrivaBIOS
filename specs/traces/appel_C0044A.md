# Appel `$C0044A`

**Généré par `bench/generer-contrats.py`. Ne pas éditer à la main** : le contrat tire son autorité de la trace, et une retouche la lui retire.

- Relevé sur **80 appel(s)**, trames 245.88 à 5330.93 — les siennes, non celles de toute la trace
- Taille, en accès tracés : 199, 722, 722, 722, 722, 722, 722, 722, 722, 726, 726, 726, 726, 726, 726, 726, 726, 726, 726, 734, 738, 738, 753, 753, 753, 753, 757, 757, 757, 757, 765, 799, 815, 865, 865, 865, 865, 869, 869, 869, 869, 871, 873, 877, 877, 889, 889, 889, 890, 890, 890, 890, 890, 890, 890, 890, 890, 893, 893, 894, 894, 894, 894, 894, 894, 894, 894, 903, 904, 904, 905, 906, 907, 907, 908, 908, 908, 981, 1244, 84043
- Retour vers : `$000134`, `$00026A`, `$000EE4`, `$0014E0`
- **16477 écriture(s) hors contrat** : faites pendant que la cartouche avait la main (dernier accès en espace programme hors de la ROM du BIOS). L'appel la lui a rendue en cours de route ; ces écritures sont le comportement du jeu, pas celui du BIOS

## Écritures communes à tous les appels

Le noyau du contrat : ce que l'appel écrit à chaque fois.

| Adresse | Zone | Valeur écrite |
|---|---|---|
| `$10FE88` | ram_bios | `$0000` |
| `$10FE8A` | ram_bios | 65 valeurs : `$0009`, `$000A`, `$000B`, `$000C`… |
| `$10FEDE` | ram_bios | `$00` |
| `$10FEDF` | ram_bios | `$00` |
| `$380031` | registres_systeme | 3 valeurs : `$DF`, `$EF`, `$FF` |
| `$3A001D` | controle_hc259 | sans objet — verrou adressé |
| `$D00020` | backup_ram | 4 valeurs : `$40`, `$41`, `$C0`, `$C1` |
| `$D00021` | backup_ram | 4 valeurs : `$40`, `$41`, `$C0`, `$C1` |
| `$D00022` | backup_ram | 3 valeurs : `$00`, `$01`, `$80` |

## Écritures d'une partie des appels seulement

À ne pas prendre pour le contrat : ces adresses dépendent d'un état que la trace ne montre pas.

| Adresse | Zone | Appels | Valeur écrite |
|---|---|---|---|
| `$10F25E` | ram_jeu | 1/80 | retenue (§8 : adresse de ROM BIOS) |
| `$10F260` | ram_jeu | 1/80 | retenue (§8 : adresse de ROM BIOS) |
| `$10F262` | ram_jeu | 6/80 | retenue (§8 : adresse de ROM BIOS) |
| `$10F264` | ram_jeu | 6/80 | retenue (§8 : adresse de ROM BIOS) |
| `$10F266` | ram_jeu | 6/80 | retenue (§8 : adresse de ROM BIOS) |
| `$10F268` | ram_jeu | 6/80 | retenue (§8 : adresse de ROM BIOS) |
| `$10F26A` | ram_jeu | 6/80 | retenue (§8 : adresse de ROM BIOS) |
| `$10F26C` | ram_jeu | 6/80 | retenue (§8 : adresse de ROM BIOS) |
| `$10F26E` | ram_jeu | 5/80 | `$0000` |
| `$10F270` | ram_jeu | 5/80 | `$026A` |
| `$10F2A2` | ram_jeu | 3/80 | retenue (§8 : adresse de ROM BIOS) |
| `$10F2A4` | ram_jeu | 3/80 | retenue (§8 : adresse de ROM BIOS) |
| `$10F2A6` | ram_jeu | 10/80 | retenue (§8 : adresse de ROM BIOS) |
| `$10F2A8` | ram_jeu | 10/80 | retenue (§8 : adresse de ROM BIOS) |
| `$10F2AA` | ram_jeu | 20/80 | retenue (§8 : adresse de ROM BIOS) |
| `$10F2AC` | ram_jeu | 20/80 | retenue (§8 : adresse de ROM BIOS) |
| `$10F2AE` | ram_jeu | 61/80 | retenue (§8 : adresse de ROM BIOS) |
| `$10F2B0` | ram_jeu | 61/80 | retenue (§8 : adresse de ROM BIOS) |
| `$10F2B2` | ram_jeu | 59/80 | retenue (§8 : adresse de ROM BIOS) |
| `$10F2B4` | ram_jeu | 59/80 | retenue (§8 : adresse de ROM BIOS) |
| `$10F2B6` | ram_jeu | 53/80 | retenue (§8 : adresse de ROM BIOS) |
| `$10F2B8` | ram_jeu | 53/80 | retenue (§8 : adresse de ROM BIOS) |
| `$10F2BA` | ram_jeu | 41/80 | `$0000` |
| `$10F2BC` | ram_jeu | 41/80 | `$026A` |
| `$10F2EA` | ram_jeu | 13/80 | retenue (§8 : adresse de ROM BIOS) |
| `$10F2EC` | ram_jeu | 13/80 | retenue (§8 : adresse de ROM BIOS) |
| `$10F2EE` | ram_jeu | 13/80 | retenue (§8 : adresse de ROM BIOS) |
| `$10F2F0` | ram_jeu | 13/80 | retenue (§8 : adresse de ROM BIOS) |
| `$10F2F2` | ram_jeu | 13/80 | retenue (§8 : adresse de ROM BIOS) |
| `$10F2F4` | ram_jeu | 13/80 | retenue (§8 : adresse de ROM BIOS) |
| `$10F2F6` | ram_jeu | 13/80 | `$0000` |
| `$10F2F8` | ram_jeu | 13/80 | `$0EE4` |
| `$10FD81` | ram_bios | 2/80 | `$03` |
| `$10FD95` | ram_bios | 79/80 | `$00` |
| `$10FD96` | ram_bios | 79/80 | `$00` |
| `$10FD97` | ram_bios | 79/80 | `$00` |
| `$10FD98` | ram_bios | 79/80 | `$00` |
| `$10FD99` | ram_bios | 79/80 | 10 valeurs : `$00`, `$01`, `$02`, `$03`… |
| `$10FD9B` | ram_bios | 79/80 | `$00` |
| `$10FD9C` | ram_bios | 79/80 | `$00` |
| `$10FD9D` | ram_bios | 79/80 | `$00` |
| `$10FD9E` | ram_bios | 79/80 | `$00` |
| `$10FD9F` | ram_bios | 79/80 | 10 valeurs : `$00`, `$01`, `$02`, `$03`… |
| `$10FDA1` | ram_bios | 79/80 | `$00` |
| `$10FDA2` | ram_bios | 79/80 | `$0000` |
| `$10FDA4` | ram_bios | 79/80 | `$0000` |
| `$10FDA7` | ram_bios | 79/80 | `$00` |
| `$10FDA8` | ram_bios | 79/80 | `$0000` |
| `$10FDAA` | ram_bios | 79/80 | `$0000` |
| `$10FDAC` | ram_bios | 79/80 | 2 valeurs : `$00`, `$01` |
| `$10FDAD` | ram_bios | 79/80 | 2 valeurs : `$00`, `$01` |
| `$10FDB4` | ram_bios | 2/80 | `$01` |
| `$10FDBA` | ram_bios | 37/80 | 3 valeurs : `$0000`, `$0100`, `$0300` |
| `$10FDBC` | ram_bios | 37/80 | `$0000` |
| `$10FDDA` | ram_bios | 3/80 | 2 valeurs : `$0000`, `$303B` |
| `$10FDDB` | ram_bios | 12/80 | 12 valeurs : `$0C`, `$0D`, `$16`, `$17`… |
| `$10FEDC` | ram_bios | 79/80 | 2 valeurs : `$00`, `$01` |
| `$10FEDD` | ram_bios | 79/80 | 2 valeurs : `$00`, `$01` |
| `$10FEE0` | ram_bios | 2/80 | `$00` |
| `$10FEE1` | ram_bios | 34/80 | 9 valeurs : `$00`, `$01`, `$02`, `$03`… |
| `$10FEE2` | ram_bios | 3/80 | 2 valeurs : `$00`, `$01` |
| `$10FEE8` | ram_bios | 79/80 | `$0000` |
| `$10FEEA` | ram_bios | 79/80 | `$0000` |
| `$10FEEC` | ram_bios | 79/80 | 9 valeurs : `$0000`, `$0001`, `$0002`, `$0003`… |
| `$10FEEE` | ram_bios | 79/80 | `$0000` |
| `$10FEF0` | ram_bios | 79/80 | `$0000` |
| `$10FEF2` | ram_bios | 79/80 | 9 valeurs : `$0000`, `$0001`, `$0002`, `$0003`… |
| `$380001` | registres_systeme | 79/80 | 3 valeurs : `$00`, `$12`, `$1B` |
| `$380041` | registres_systeme | 79/80 | 2 valeurs : `$FE`, `$FF` |
| `$380061` | registres_systeme | 4/80 | `$00` |
| `$3800E1` | registres_systeme | 34/80 | `$10` |
| `$3A000D` | controle_hc259 | 79/80 | sans objet — verrou adressé |
| `$D00024` | backup_ram | 1/80 | 2 valeurs : `$00`, `$01` |
| `$D0002C` | backup_ram | 1/80 | 2 valeurs : `$00`, `$01` |
| `$D00034` | backup_ram | 3/80 | 2 valeurs : `$00`, `$01` |
| `$D00038` | backup_ram | 39/80 | 20 valeurs : `$0C`, `$0D`, `$0E`, `$0F`… |
| `$D00039` | backup_ram | 1/80 | `$00` |
| `$D0004C` | backup_ram | 28/80 | 20 valeurs : `$0C`, `$0D`, `$0E`, `$0F`… |
| `$D0005D` | backup_ram | 79/80 | 48 valeurs : `$06`, `$07`, `$08`, `$09`… |
| `$D08324` | backup_ram | 2/80 | `$0000` |
| `$D08326` | backup_ram | 2/80 | `$0001` |
| `$D095B4` | backup_ram | 2/80 | `$0000` |
| `$D095B6` | backup_ram | 2/80 | `$0001` |
| `$D09B24` | backup_ram | 2/80 | `$0000` |
| `$D09B26` | backup_ram | 2/80 | `$0001` |
| `$D09BA4` | backup_ram | 1/80 | `$0000` |
| `$D09BA6` | backup_ram | 1/80 | `$0002` |
| `$D09DE4` | backup_ram | 2/80 | `$0000` |
| `$D09DE6` | backup_ram | 2/80 | `$0001` |
| `$D0A0B4` | backup_ram | 1/80 | `$0000` |
| `$D0A0B6` | backup_ram | 1/80 | `$0002` |
| `$D0A174` | backup_ram | 2/80 | `$0000` |
| `$D0A176` | backup_ram | 2/80 | `$0001` |
| `$D0A1D0` | backup_ram | 2/80 | `$0000` |
| `$D0A1D2` | backup_ram | 2/80 | `$0001` |

## Séquences lues dans la ROM du BIOS

Aucune suite de 4 mots contigus ou plus. Rien à trancher.

## Ce que ce contrat ne dit pas

- **Aucune valeur lue n'est portée directement** : le banc ne pose aucune donnée sur le bus pour une lecture, donc une lecture n'a pas de valeur observable. **Cela ne suffit pas à tenir §8** : une valeur lue puis empilée ou recopiée ressort dans la donnée d'une écriture, et c'est pourquoi les gardes ci-dessous existent.
- **26 site(s) ont leur valeur retenue parce qu'elle porte une adresse interne de la ROM du BIOS** : un `jsr` interne empile son adresse de retour, et §8 garde ces adresses hors du contrat. L'adresse de l'écriture reste, sa valeur non. Ces sites sont pour l'essentiel la **pile du BIOS**, que rien n'oblige une autre implémentation à reproduire — elle empilera ses propres adresses.
- **La signature de l'appel non plus.** Les paramètres passent par les registres du 68000, que le bus ne montre pas : une trace donne les effets d'un appel, pas sa signature.
- **Le nom de l'appel non plus** : ce document le désigne par son offset. La correspondance avec un nom est de la documentation publique.
