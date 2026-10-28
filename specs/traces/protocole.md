# Protocole — sites suivis et remises de main

**Généré par `bench/generer-contrats.py --protocole`. Ne pas éditer à la main.**

Sites suivis, donnés par l'opérateur — leur choix se source dans la relecture (`DECISIONS.md` §8), ce document ne les nomme pas :

| Site | Zone |
|---|---|
| `$10FD80` | ram_bios |
| `$10FDAE` | ram_bios |
| `$10FDAF` | ram_bios |
| `$10FEE1` | ram_bios |
| `$320000` | registres_systeme |

Une **remise de main** est une transition BIOS → cartouche en espace programme qui n'est pas le retour vérifié d'un appel : la sortie d'un appel entré par `jmp`, ou une excursion au milieu d'un appel. Les retours d'appel vérifiés sont comptés à part — ils relèvent des contrats d'appel.

## Trace 1 — trames 0.00 à 69.58

### Accès aux sites suivis

| Trame | Site | Valeur | La main | Répétitions |
|---|---|---|---|---|
| 4.18 | `$10FD80` | `$5555` | bios | 1 |
| 4.18 | `$10FDAE` | `$5555` | bios | 1 |
| 4.20 | `$10FEE0` | `$5555` | bios | 1 |
| 12.22 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 12.22 | `$10FDAE` | lecture — valeur non observable | bios | 1 |
| 12.26 | `$10FEE0` | lecture — valeur non observable | bios | 1 |
| 16.46 | `$10FD80` | `$AAAA` | bios | 1 |
| 16.46 | `$10FDAE` | `$AAAA` | bios | 1 |
| 16.48 | `$10FEE0` | `$AAAA` | bios | 1 |
| 24.50 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 24.51 | `$10FDAE` | lecture — valeur non observable | bios | 1 |
| 24.54 | `$10FEE0` | lecture — valeur non observable | bios | 1 |
| 29.38 | `$10FD80` | `$FD80` | bios | 1 |
| 29.38 | `$10FDAE` | `$FDAE` | bios | 1 |
| 29.41 | `$10FEE0` | `$FEE0` | bios | 1 |
| 38.07 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 38.08 | `$10FDAE` | lecture — valeur non observable | bios | 1 |
| 38.12 | `$10FEE0` | lecture — valeur non observable | bios | 1 |

### Remises de main (BIOS → cartouche)

Aucune sur cette trace.

## Trace 2 — trames 227.97 à 250.97

### Accès aux sites suivis

| Trame | Site | Valeur | La main | Répétitions |
|---|---|---|---|---|
| 234.30 | `$10FEE1` | `$FF` | bios | 1 |
| 234.38 | `$320000` | `$01` | bios | 1 |
| 234.38 | `$320000` | lecture — valeur non observable | bios | 1 |
| 234.49 | `$10FEE0` | `$0000` | bios | 1 |
| 234.50 | `$10FDAE` | `$0000` | bios | 1 |
| 234.50 | `$10FD80` | `$0000` | bios | 1 |
| 237.47 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 237.47 | `$10FD80` | `$00` | bios | 1 |
| 237.50 | `$320000` | lecture — valeur non observable | bios | 1 |
| 237.51 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 237.51 | `$10FDAF` | `$00` | bios | 1 |
| 237.51 | `$320000` | `$03` | bios | 1 |
| 237.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 237.88 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 237.89 |
| 237.89 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 237.89 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 237.89 | `$10FDAE` | `$00` | bios | 1 |
| 237.89 | `$10FD80` | `$80` | bios | 1 |
| 238.77 | `$10FDAE` | lecture — valeur non observable | cartouche | 1 |
| 238.77 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 238.77 | `$10FD80` | `$00` | cartouche | 1 |
| 238.77 | `$10FDAF` | `$00` | cartouche | 1 |
| 238.80 | `$10FEE1` | `$FF` | bios | 1 |
| 238.80 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 238.80 | `$10FD80` | `$00` | bios | 1 |
| 238.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 238.88 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 238.89 |
| 238.89 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 239.40 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 239.40 | `$10FD80` | `$00` | bios | 1 |
| 239.41 | `$320000` | lecture — valeur non observable | bios | 1 |
| 239.41 | `$320000` | `$01` | bios | 1 |
| 239.41 | `$320000` | lecture — valeur non observable | bios | 1 |
| 239.41 | `$320000` | `$03` | bios | 1 |
| 239.41 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 239.41 | `$10FD80` | `$00` | bios | 1 |
| 239.41 | `$10FEE1` | `$0A` | bios | 1 |
| 239.41 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 239.41 | `$10FDAF` | `$00` | bios | 1 |
| 239.41 | `$10FD80` | `$01` | bios | 1 |
| 239.41 | `$320000` | `$03` | bios | 1 |
| 239.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 239.88 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 239.89 |
| 239.89 | `$10FEE1` | `$09` | bios | 1 |
| 239.89 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 240.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 240.90 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 240.91 |
| 240.91 | `$10FEE1` | `$08` | bios | 1 |
| 240.91 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 241.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 241.91 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 241.92 |
| 241.92 | `$10FEE1` | `$07` | bios | 1 |
| 241.92 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 242.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 242.90 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 242.91 |
| 242.91 | `$10FEE1` | `$06` | bios | 1 |
| 242.91 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 243.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 243.90 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 243.91 |
| 243.91 | `$10FEE1` | `$05` | bios | 1 |
| 243.91 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 244.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 244.90 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 244.91 |
| 244.91 | `$10FEE1` | `$04` | bios | 1 |
| 244.91 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 245.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 245.90 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 245.91 |
| 245.91 | `$10FEE1` | `$03` | bios | 1 |
| 245.91 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 245.92 | `$320000` | `$02` | bios | 1 |
| 246.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 246.90 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 246.91 |
| 246.91 | `$10FEE1` | `$02` | bios | 1 |
| 246.91 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 247.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 247.90 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 247.91 |
| 247.91 | `$10FEE1` | `$01` | bios | 1 |
| 247.91 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 248.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 248.90 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 248.91 |
| 248.91 | `$10FEE1` | `$00` | bios | 1 |
| 248.91 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 249.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 249.90 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 249.91 |
| 249.91 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 249.91 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 250.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 250.90 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 250.91 |
| 250.91 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 250.91 | `$10FDAF` | lecture — valeur non observable | bios | 1 |

### Remises de main (BIOS → cartouche)

| Trame | Vers | Contexte |
|---|---|---|
| 237.88 | `$000200` | — |
| 237.89 | `$000122` | — |
| 238.88 | `$000200` | appel entré à `$C00444` |
| 239.88 | `$000200` | — |
| 240.88 | `$000200` | — |
| 241.88 | `$000200` | — |
| 242.88 | `$000200` | — |
| 243.88 | `$000200` | — |
| 244.88 | `$000200` | — |
| 245.88 | `$000200` | — |
| 246.88 | `$000200` | — |
| 247.88 | `$000200` | — |
| 248.88 | `$000200` | — |
| 249.88 | `$000200` | — |
| 250.88 | `$000200` | — |

## Trace 3 — trames 329.97 à 342.79

### Accès aux sites suivis

| Trame | Site | Valeur | La main | Répétitions |
|---|---|---|---|---|
| 330.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 330.90 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 330.91 |
| 330.91 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 330.91 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 331.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 331.90 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 331.91 |
| 331.91 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 331.91 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 332.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 332.90 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 332.91 |
| 332.91 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 332.91 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 333.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 333.90 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 333.91 |
| 333.91 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 333.91 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 334.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 334.90 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 334.91 |
| 334.91 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 334.91 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 335.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 335.90 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 335.91 |
| 335.91 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 335.91 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 336.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 336.90 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 336.91 |
| 336.91 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 336.91 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 337.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 337.90 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 337.91 |
| 337.91 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 337.91 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 338.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 338.90 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 338.91 |
| 338.91 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 338.91 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 339.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 339.90 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 339.91 |
| 339.91 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 339.91 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 340.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 340.90 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 340.91 |
| 340.91 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 340.91 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 341.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 341.90 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 341.91 |
| 341.91 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 341.91 | `$10FDAF` | lecture — valeur non observable | bios | 1 |

### Remises de main (BIOS → cartouche)

| Trame | Vers | Contexte |
|---|---|---|
| 330.88 | `$000200` | — |
| 331.88 | `$000200` | — |
| 332.88 | `$000200` | — |
| 333.88 | `$000200` | — |
| 334.88 | `$000200` | — |
| 335.88 | `$000200` | — |
| 336.88 | `$000200` | — |
| 337.88 | `$000200` | — |
| 338.88 | `$000200` | — |
| 339.88 | `$000200` | — |
| 340.88 | `$000200` | — |
| 341.88 | `$000200` | — |

## Trace 4 — trames 497.97 à 510.86

### Accès aux sites suivis

| Trame | Site | Valeur | La main | Répétitions |
|---|---|---|---|---|
| 498.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 498.90 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 498.91 |
| 498.91 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 498.91 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 499.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 499.90 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 499.91 |
| 499.91 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 499.91 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 500.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 500.90 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 500.91 |
| 500.91 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 500.91 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 500.92 | `$10FEE1` | `$FF` | bios | 1 |
| 500.92 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 500.92 | `$10FD80` | `$01` | bios | 1 |
| 501.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 501.88 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 501.89 |
| 501.89 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 502.41 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 502.41 | `$10FD80` | `$01` | bios | 1 |
| 502.41 | `$10FEE1` | `$0A` | bios | 1 |
| 502.41 | `$10FDAF` | `$01` | bios | 1 |
| 502.41 | `$320000` | `$03` | bios | 1 |
| 502.88 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 502.89 |
| 502.89 | `$10FEE1` | `$09` | bios | 1 |
| 502.89 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 502.89 | `$10FDAE` | `$03` | bios | 1 |
| 502.89 | `$10FD80` | `$82` | bios | 1 |
| 503.77 | `$10FDAE` | lecture — valeur non observable | cartouche | 1 |
| 503.77 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 503.77 | `$10FD80` | `$02` | cartouche | 1 |
| 503.77 | `$10FDAF` | `$01` | cartouche | 1 |
| 503.77 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 503.77 | `$10FD80` | `$82` | cartouche | 1 |
| 503.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 503.89 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 503.90 |
| 503.90 | `$10FEE1` | `$08` | bios | 1 |
| 503.90 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 504.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 505.00 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 505.01 |
| 505.01 | `$10FEE1` | `$07` | bios | 1 |
| 505.01 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 505.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 506.00 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 506.01 |
| 506.01 | `$10FEE1` | `$06` | bios | 1 |
| 506.01 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 506.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 506.88 | `$320000` | `$03` | cartouche | 1 |
| 506.89 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 506.90 |
| 506.90 | `$10FEE1` | `$05` | bios | 1 |
| 506.90 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 507.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 507.89 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 507.90 |
| 507.90 | `$10FEE1` | `$04` | bios | 1 |
| 507.90 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 508.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 508.89 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 508.90 |
| 508.90 | `$10FEE1` | `$03` | bios | 1 |
| 508.90 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 508.90 |
| 509.06 | `$10FDAF` | `$01` | cartouche | 1 |
| 509.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 509.89 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 509.90 |
| 509.90 | `$10FEE1` | `$02` | bios | 1 |
| 509.90 | `$10FDAF` | lecture — valeur non observable | bios | 1 |

### Remises de main (BIOS → cartouche)

| Trame | Vers | Contexte |
|---|---|---|
| 498.88 | `$000200` | — |
| 499.88 | `$000200` | — |
| 500.88 | `$000200` | — |
| 501.88 | `$000200` | — |
| 502.89 | `$000122` | — |
| 503.88 | `$000200` | appel entré à `$C004C2` |

Retours d'appel vérifiés, non listés — ils relèvent des contrats d'appel : 7 vers `$00026A`, 1 vers `$0009B2`, 1 vers `$0009BE`, 1 vers `$0013FC`, 1 vers `$003292`.

## Trace 5 — trames 557.97 à 571.18

### Accès aux sites suivis

| Trame | Site | Valeur | La main | Répétitions |
|---|---|---|---|---|
| 558.23 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 558.24 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 558.25 |
| 558.25 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 558.25 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 558.25 |
| 558.25 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 558.25 | `$10FDAF` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 558.26 |
| 558.26 | `$10FDAE` | lecture — valeur non observable | cartouche | 1 |
| 558.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 559.23 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 559.24 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 559.25 |
| 559.25 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 559.25 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 559.25 |
| 559.25 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 559.25 | `$10FDAF` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 559.26 |
| 559.26 | `$10FDAE` | lecture — valeur non observable | cartouche | 1 |
| 559.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 560.23 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 560.24 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 560.25 |
| 560.25 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 560.25 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 560.25 | `$10FDAF` | `$02` | cartouche | 1 |
| 562.18 | `$10FEE1` | `$01` | bios | 1 |
| 562.19 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 562.19 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 562.19 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 562.20 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 562.20 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 562.21 |
| 562.21 | `$10FEE1` | `$00` | bios | 1 |
| 562.21 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 562.22 |
| 562.37 | `$10FDAF` | lecture — valeur non observable | cartouche | × 2, jusqu'à la trame 562.37 |
| 562.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 562.88 | `$10FDAF` | lecture — valeur non observable | cartouche | 1 |
| 562.88 | `$320000` | `$22` | cartouche | 1 |
| 562.88 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 562.89 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 562.90 |
| 562.90 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 562.90 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 562.90 |
| 562.90 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 562.90 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 562.90 |
| 563.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 563.88 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 563.89 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 563.90 |
| 563.90 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 563.90 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 563.90 |
| 563.90 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 563.90 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 563.90 |
| 564.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 564.88 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 564.89 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 564.90 |
| 564.90 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 564.90 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 564.90 |
| 564.90 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 564.90 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 564.90 |
| 565.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 565.95 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 565.96 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 565.97 |
| 565.97 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 565.97 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 565.97 |
| 565.97 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 565.97 | `$10FDAF` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 565.98 |
| 565.98 | `$10FDAF` | lecture — valeur non observable | cartouche | 1 |
| 566.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 566.95 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 566.96 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 566.97 |
| 566.97 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 566.97 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 566.97 |
| 566.97 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 566.97 | `$10FDAF` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 566.98 |
| 566.98 | `$10FDAF` | lecture — valeur non observable | cartouche | 1 |
| 567.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 567.95 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 567.96 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 567.97 |
| 567.97 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 567.97 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 567.97 |
| 567.97 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 567.97 | `$10FDAF` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 567.98 |
| 567.98 | `$10FDAF` | lecture — valeur non observable | cartouche | 1 |
| 568.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 568.95 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 568.96 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 568.97 |
| 568.97 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 568.97 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 568.97 |
| 568.97 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 568.97 | `$10FDAF` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 568.98 |
| 568.98 | `$10FDAF` | lecture — valeur non observable | cartouche | 1 |
| 569.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 569.95 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 569.96 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 569.97 |
| 569.97 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 569.97 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 569.97 |
| 569.97 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 569.97 | `$10FDAF` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 569.98 |
| 569.98 | `$10FDAF` | lecture — valeur non observable | cartouche | 1 |
| 570.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 570.95 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 570.96 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 570.97 |
| 570.97 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 570.97 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 570.97 |
| 570.97 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 570.97 | `$10FDAF` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 570.98 |
| 570.98 | `$10FDAF` | lecture — valeur non observable | cartouche | 1 |

### Remises de main (BIOS → cartouche)

| Trame | Vers | Contexte |
|---|---|---|
| 560.25 | `$000128` | appel entré à `$C0044A` |

Retours d'appel vérifiés, non listés — ils relèvent des contrats d'appel : 13 vers `$00026A`, 9 vers `$0013FC`, 1 vers `$0094EA`, 1 vers `$01164C`, 1 vers `$011658`.

## Trace 6 — trames 597.97 à 610.85

### Accès aux sites suivis

| Trame | Site | Valeur | La main | Répétitions |
|---|---|---|---|---|
| 597.97 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 597.97 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 597.97 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 597.97 |
| 597.97 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 597.97 | `$10FDAF` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 597.98 |
| 597.99 | `$10FDAF` | lecture — valeur non observable | cartouche | 1 |
| 598.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 598.95 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 598.96 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 598.97 |
| 598.97 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 598.97 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 598.97 |
| 598.97 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 598.97 | `$10FDAF` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 598.98 |
| 598.99 | `$10FDAF` | lecture — valeur non observable | cartouche | 1 |
| 599.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 599.95 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 599.96 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 599.97 |
| 599.97 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 599.97 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 599.97 |
| 599.97 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 599.97 | `$10FDAF` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 599.98 |
| 599.98 | `$10FDAF` | lecture — valeur non observable | cartouche | 1 |
| 600.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 600.95 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 600.96 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 600.97 |
| 600.97 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 600.97 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 600.97 |
| 600.97 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 600.97 | `$10FDAF` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 600.98 |
| 600.99 | `$10FDAF` | lecture — valeur non observable | cartouche | 1 |
| 601.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 601.88 | `$320000` | `$7F` | cartouche | 1 |
| 601.95 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 601.97 |
| 601.97 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 601.97 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 601.97 |
| 601.97 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 601.97 | `$10FDAF` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 601.98 |
| 601.98 | `$10FDAF` | lecture — valeur non observable | cartouche | 1 |
| 602.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 602.95 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 602.97 |
| 602.97 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 602.97 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 602.97 |
| 602.97 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 602.97 | `$10FDAF` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 602.98 |
| 602.98 | `$10FDAF` | lecture — valeur non observable | cartouche | 1 |
| 603.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 603.96 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 603.97 |
| 603.97 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 603.97 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 603.97 |
| 603.97 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 603.97 | `$10FDAF` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 603.98 |
| 603.98 | `$10FDAF` | lecture — valeur non observable | cartouche | 1 |
| 604.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 604.95 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 604.97 |
| 604.97 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 604.97 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 604.97 |
| 604.97 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 604.97 | `$10FDAF` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 604.98 |
| 604.98 | `$10FDAF` | lecture — valeur non observable | cartouche | 1 |
| 605.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 605.95 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 605.97 |
| 605.97 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 605.97 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 605.97 |
| 605.97 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 605.97 | `$10FDAF` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 605.98 |
| 605.98 | `$10FDAF` | lecture — valeur non observable | cartouche | 1 |
| 606.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 606.95 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 606.97 |
| 606.97 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 606.97 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 606.97 |
| 606.97 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 606.97 | `$10FDAF` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 606.98 |
| 606.98 | `$10FDAF` | lecture — valeur non observable | cartouche | 1 |
| 607.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 607.95 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 607.97 |
| 607.97 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 607.97 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 607.97 |
| 607.97 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 607.97 | `$10FDAF` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 607.98 |
| 607.98 | `$10FDAF` | lecture — valeur non observable | cartouche | 1 |
| 608.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 608.95 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 608.97 |
| 608.97 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 608.97 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 608.97 |
| 608.97 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 608.97 | `$10FDAF` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 608.98 |
| 608.98 | `$10FDAF` | lecture — valeur non observable | cartouche | 1 |
| 609.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 609.95 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 609.97 |
| 609.97 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 609.97 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 609.97 |
| 609.97 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 609.97 | `$10FDAF` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 609.98 |
| 609.98 | `$10FDAF` | lecture — valeur non observable | cartouche | 1 |

### Remises de main (BIOS → cartouche)

| Trame | Vers | Contexte |
|---|---|---|
| 597.97 | `$00026A` | — |
| 600.96 | `$000134` | appel entré à `$C0044A` |

Retours d'appel vérifiés, non listés — ils relèvent des contrats d'appel : 12 vers `$00026A`, 13 vers `$0013FC`.

## Trace 7 — trames 499.97 à 518.85

### Accès aux sites suivis

| Trame | Site | Valeur | La main | Répétitions |
|---|---|---|---|---|
| 500.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 500.90 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 500.91 |
| 500.91 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 500.92 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 500.92 | `$10FEE1` | `$FF` | bios | 1 |
| 500.92 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 500.92 | `$10FD80` | `$01` | bios | 1 |
| 501.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 501.88 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 501.89 |
| 501.89 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 502.41 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 502.41 | `$10FD80` | `$01` | bios | 1 |
| 502.41 | `$10FEE1` | `$0A` | bios | 1 |
| 502.41 | `$10FDAF` | `$01` | bios | 1 |
| 502.41 | `$320000` | `$03` | bios | 1 |
| 502.88 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 502.89 |
| 502.89 | `$10FEE1` | `$09` | bios | 1 |
| 502.89 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 502.89 | `$10FDAE` | `$03` | bios | 1 |
| 502.89 | `$10FD80` | `$82` | bios | 1 |
| 502.89 | `$10FDAE` | lecture — valeur non observable | cartouche | 1 |
| 502.90 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 502.90 | `$10FD80` | `$02` | cartouche | 1 |
| 503.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 503.88 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 503.89 |
| 503.89 | `$10FEE1` | `$08` | bios | 1 |
| 503.89 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 504.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 504.88 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 504.89 |
| 504.89 | `$10FEE1` | `$07` | bios | 1 |
| 504.89 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 505.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 505.88 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 505.89 |
| 505.89 | `$10FEE1` | `$06` | bios | 1 |
| 505.89 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 506.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 506.88 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 506.89 |
| 506.89 | `$10FEE1` | `$05` | bios | 1 |
| 506.89 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 507.38 | `$10FDAF` | `$01` | cartouche | 1 |
| 507.38 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 507.38 | `$10FD80` | `$82` | cartouche | 1 |
| 507.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 507.90 | `$10FDAF` | lecture — valeur non observable | cartouche | 1 |
| 507.90 | `$320000` | `$07` | cartouche | 1 |
| 507.90 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 507.92 |
| 507.92 | `$10FEE1` | `$04` | bios | 1 |
| 507.92 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 507.92 | `$10FDAF` | lecture — valeur non observable | cartouche | 1 |
| 508.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 508.90 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 508.91 |
| 508.91 | `$10FEE1` | `$03` | bios | 1 |
| 508.91 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 509.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 509.90 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 509.92 |
| 509.92 | `$10FEE1` | `$02` | bios | 1 |
| 509.92 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 510.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 510.90 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 510.91 |
| 510.91 | `$10FEE1` | `$01` | bios | 1 |
| 510.91 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 511.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 511.90 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 511.92 |
| 511.92 | `$10FEE1` | `$00` | bios | 1 |
| 511.92 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 512.07 | `$10FDAE` | lecture — valeur non observable | cartouche | 1 |
| 512.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 512.92 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 512.93 |
| 512.93 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 512.93 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 512.93 |
| 512.93 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 512.93 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 512.93 | `$10FEE1` | `$FF` | bios | 1 |
| 512.93 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 512.93 | `$10FD80` | `$02` | bios | 1 |
| 513.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 513.88 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 513.89 |
| 513.89 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 514.35 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 514.35 | `$10FD80` | `$02` | bios | 1 |
| 514.35 | `$10FEE1` | `$0A` | bios | 1 |
| 514.35 | `$10FDAF` | `$01` | bios | 1 |
| 514.35 | `$320000` | `$03` | bios | 1 |
| 514.88 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 514.89 |
| 514.89 | `$10FEE1` | `$09` | bios | 1 |
| 514.89 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 514.89 | `$10FDAE` | `$03` | bios | 1 |
| 514.89 | `$10FD80` | `$82` | bios | 1 |
| 514.89 | `$10FDAE` | lecture — valeur non observable | cartouche | 1 |
| 514.90 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 514.90 | `$10FD80` | `$02` | cartouche | 1 |
| 515.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 515.88 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 515.89 |
| 515.89 | `$10FEE1` | `$08` | bios | 1 |
| 515.89 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 516.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 516.88 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 516.89 |
| 516.89 | `$10FEE1` | `$07` | bios | 1 |
| 516.89 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 517.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 517.88 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 517.88 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 517.89 |
| 517.89 | `$10FEE1` | `$06` | bios | 1 |
| 517.89 | `$10FDAF` | lecture — valeur non observable | bios | 1 |

### Remises de main (BIOS → cartouche)

| Trame | Vers | Contexte |
|---|---|---|
| 500.88 | `$0012C6` | — |
| 501.88 | `$0012C6` | appel entré à `$C00438` |
| 502.89 | `$000122` | appel entré à `$C00438` |
| 503.89 | `$001292` | appel entré à `$C00438` |
| 504.89 | `$00129E` | appel entré à `$C00438` |
| 505.89 | `$0011E8` | appel entré à `$C00438` |
| 506.89 | `$0011E8` | appel entré à `$C00438` |
| 512.92 | `$000134` | appel entré à `$C0044A` |
| 512.93 | `$00012E` | appel entré à une adresse interne (§8) |
| 513.88 | `$0012C6` | appel entré à une adresse interne (§8) |
| 514.89 | `$000122` | appel entré à `$C00438` |
| 515.89 | `$001296` | appel entré à `$C00438` |
| 516.89 | `$001296` | appel entré à `$C00438` |
| 517.89 | `$0011F4` | appel entré à `$C00438` |

Retours d'appel vérifiés, non listés — ils relèvent des contrats d'appel : 2 vers `$00118C`, 5 vers `$0014E0`.

## Trace 8 — trames 557.97 à 570.76

### Accès aux sites suivis

| Trame | Site | Valeur | La main | Répétitions |
|---|---|---|---|---|
| 558.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 558.90 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 558.91 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 558.92 |
| 558.92 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 558.92 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 558.92 |
| 558.92 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 558.92 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 558.92 |
| 558.92 | `$10FDAF` | lecture — valeur non observable | cartouche | 1 |
| 559.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 559.90 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 559.91 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 559.92 |
| 559.92 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 559.92 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 559.92 |
| 559.92 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 559.92 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 559.92 |
| 559.92 | `$10FDAF` | lecture — valeur non observable | cartouche | 1 |
| 560.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 560.90 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 560.91 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 560.92 |
| 560.92 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 560.92 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 560.92 | `$10FDAF` | lecture — valeur non observable | cartouche | 1 |
| 560.92 | `$10FDAF` | `$02` | cartouche | 1 |
| 560.92 | `$10FEE1` | `$01` | bios | 1 |
| 560.93 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 560.93 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 560.93 | `$10FDAF` | lecture — valeur non observable | cartouche | 1 |
| 561.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 561.88 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 561.88 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 561.89 |
| 561.89 | `$10FEE1` | `$00` | bios | 1 |
| 561.89 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 562.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 562.88 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 562.88 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 562.89 |
| 562.89 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 562.89 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 562.89 |
| 562.90 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 562.90 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 562.90 |
| 563.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 563.90 | `$10FDAF` | lecture — valeur non observable | cartouche | 1 |
| 563.90 | `$320000` | `$20` | cartouche | 1 |
| 563.90 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 563.91 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 563.92 |
| 563.92 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 563.92 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 563.92 |
| 563.92 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 563.92 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 563.92 |
| 564.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 564.93 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 564.93 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 564.94 |
| 564.94 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 564.94 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 564.94 |
| 564.94 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 564.94 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 564.94 |
| 565.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 566.20 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 566.20 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 566.22 |
| 566.22 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 566.22 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 566.22 |
| 566.22 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 566.22 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 566.22 |
| 566.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 566.92 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 566.93 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 566.94 |
| 566.94 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 566.94 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 566.94 |
| 566.94 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 566.94 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 566.94 |
| 567.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 567.92 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 567.92 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 567.93 |
| 567.93 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 567.93 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 567.93 |
| 567.94 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 567.94 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 567.94 |
| 568.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 568.92 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 568.92 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 568.93 |
| 568.93 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 568.93 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 568.93 |
| 568.93 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 568.93 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 568.94 |
| 569.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 569.92 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 569.92 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 569.93 |
| 569.93 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 569.93 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 569.93 |
| 569.94 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 569.94 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 569.94 |

### Remises de main (BIOS → cartouche)

| Trame | Vers | Contexte |
|---|---|---|
| 560.92 | `$000128` | appel entré à `$C0044A` |

Retours d'appel vérifiés, non listés — ils relèvent des contrats d'appel : 12 vers `$0014E0`, 1 vers `$006FE2`.

## Trace 9 — trames 227.97 à 262.97

### Accès aux sites suivis

| Trame | Site | Valeur | La main | Répétitions |
|---|---|---|---|---|
| 234.30 | `$10FEE1` | `$FF` | bios | 1 |
| 234.38 | `$320000` | `$01` | bios | 1 |
| 234.38 | `$320000` | lecture — valeur non observable | bios | 1 |
| 234.49 | `$10FEE0` | `$0000` | bios | 1 |
| 234.50 | `$10FDAE` | `$0000` | bios | 1 |
| 234.50 | `$10FD80` | `$0000` | bios | 1 |
| 237.47 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 237.47 | `$10FD80` | `$00` | bios | 1 |
| 237.50 | `$320000` | lecture — valeur non observable | bios | 1 |
| 237.51 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 237.51 | `$10FDAF` | `$00` | bios | 1 |
| 237.51 | `$320000` | `$03` | bios | 1 |
| 237.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 237.88 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 237.89 |
| 237.89 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 237.89 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 237.89 | `$10FDAE` | `$00` | bios | 1 |
| 237.89 | `$10FD80` | `$80` | bios | 1 |
| 238.77 | `$10FDAE` | lecture — valeur non observable | cartouche | 1 |
| 238.77 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 238.77 | `$10FD80` | `$00` | cartouche | 1 |
| 238.77 | `$10FDAF` | `$00` | cartouche | 1 |
| 238.80 | `$10FEE1` | `$FF` | bios | 1 |
| 238.80 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 238.80 | `$10FD80` | `$00` | bios | 1 |
| 238.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 238.88 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 238.89 |
| 238.89 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 239.40 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 239.40 | `$10FD80` | `$00` | bios | 1 |
| 239.41 | `$320000` | lecture — valeur non observable | bios | 1 |
| 239.41 | `$320000` | `$01` | bios | 1 |
| 239.41 | `$320000` | lecture — valeur non observable | bios | 1 |
| 239.41 | `$320000` | `$03` | bios | 1 |
| 239.41 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 239.41 | `$10FD80` | `$00` | bios | 1 |
| 239.41 | `$10FEE1` | `$0A` | bios | 1 |
| 239.41 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 239.41 | `$10FDAF` | `$00` | bios | 1 |
| 239.41 | `$10FD80` | `$01` | bios | 1 |
| 239.41 | `$320000` | `$03` | bios | 1 |
| 239.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 239.88 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 239.89 |
| 239.89 | `$10FEE1` | `$09` | bios | 1 |
| 239.89 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 240.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 240.90 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 240.91 |
| 240.91 | `$10FEE1` | `$08` | bios | 1 |
| 240.91 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 241.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 241.91 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 241.92 |
| 241.92 | `$10FEE1` | `$07` | bios | 1 |
| 241.92 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 242.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 242.90 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 242.91 |
| 242.91 | `$10FEE1` | `$06` | bios | 1 |
| 242.91 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 242.92 | `$10FEE1` | `$FF` | bios | 1 |
| 242.92 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 242.92 | `$10FD80` | `$01` | bios | 1 |
| 243.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 243.88 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 243.89 |
| 243.89 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 244.41 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 244.41 | `$10FD80` | `$01` | bios | 1 |
| 244.41 | `$10FEE1` | `$0A` | bios | 1 |
| 244.41 | `$10FDAF` | `$01` | bios | 1 |
| 244.41 | `$320000` | `$03` | bios | 1 |
| 244.88 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 244.89 |
| 244.89 | `$10FEE1` | `$09` | bios | 1 |
| 244.89 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 244.89 | `$10FDAE` | `$03` | bios | 1 |
| 244.89 | `$10FD80` | `$82` | bios | 1 |
| 245.77 | `$10FDAE` | lecture — valeur non observable | cartouche | 1 |
| 245.77 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 245.77 | `$10FD80` | `$02` | cartouche | 1 |
| 245.77 | `$10FDAF` | `$01` | cartouche | 1 |
| 245.77 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 245.77 | `$10FD80` | `$82` | cartouche | 1 |
| 245.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 245.89 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 245.90 |
| 245.90 | `$10FEE1` | `$08` | bios | 1 |
| 245.90 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 246.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 247.00 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 247.01 |
| 247.01 | `$10FEE1` | `$07` | bios | 1 |
| 247.01 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 247.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 248.00 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 248.01 |
| 248.01 | `$10FEE1` | `$06` | bios | 1 |
| 248.01 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 248.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 248.88 | `$320000` | `$03` | cartouche | 1 |
| 248.89 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 248.90 |
| 248.90 | `$10FEE1` | `$05` | bios | 1 |
| 248.90 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 249.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 249.89 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 249.90 |
| 249.90 | `$10FEE1` | `$04` | bios | 1 |
| 249.90 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 250.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 250.89 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 250.90 |
| 250.90 | `$10FEE1` | `$03` | bios | 1 |
| 250.90 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 250.90 |
| 251.06 | `$10FDAF` | `$01` | cartouche | 1 |
| 251.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 251.89 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 251.90 |
| 251.90 | `$10FEE1` | `$02` | bios | 1 |
| 251.90 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 252.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 252.89 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 252.90 |
| 252.90 | `$10FEE1` | `$01` | bios | 1 |
| 252.90 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 253.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 253.88 | `$320000` | `$07` | cartouche | 1 |
| 253.99 | `$10FEE1` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 254.00 |
| 254.00 | `$10FEE1` | `$00` | bios | 1 |
| 254.00 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 254.01 |
| 254.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 255.15 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 255.17 |
| 255.17 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 255.17 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 255.17 |
| 255.17 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 255.17 | `$10FDAF` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 255.17 |
| 255.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 256.15 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 256.16 |
| 256.17 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 256.17 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 256.17 |
| 256.17 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 256.17 | `$10FDAF` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 256.17 |
| 256.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 256.88 | `$320000` | `$7F` | cartouche | 1 |
| 257.15 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 257.17 |
| 257.17 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 257.17 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 257.17 |
| 257.17 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 257.17 | `$10FDAF` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 257.17 |
| 257.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 258.15 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 258.16 |
| 258.16 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 258.16 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 258.17 |
| 258.17 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 258.17 | `$10FDAF` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 258.17 |
| 258.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 259.15 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 259.16 |
| 259.16 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 259.16 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 259.17 |
| 259.17 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 259.17 | `$10FDAF` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 259.17 |
| 259.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 260.15 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 260.15 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 260.17 |
| 260.17 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 260.17 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 260.17 |
| 260.17 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 260.17 | `$10FDAF` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 260.17 |
| 260.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 261.15 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 261.15 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 261.16 |
| 261.17 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 261.17 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 261.17 |
| 261.17 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 261.17 | `$10FDAF` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 261.17 |
| 261.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |
| 262.15 | `$10FDAF` | lecture — valeur non observable | bios | 1 |
| 262.15 | `$10FEE1` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 262.17 |
| 262.17 | `$10FD80` | lecture — valeur non observable | bios | 1 |
| 262.17 | `$10FDAF` | lecture — valeur non observable | bios | × 2, jusqu'à la trame 262.17 |
| 262.17 | `$10FEE1` | lecture — valeur non observable | bios | 1 |
| 262.17 | `$10FDAF` | lecture — valeur non observable | bios | × 3, jusqu'à la trame 262.17 |
| 262.88 | `$10FD80` | lecture — valeur non observable | cartouche | 1 |

### Remises de main (BIOS → cartouche)

| Trame | Vers | Contexte |
|---|---|---|
| 237.88 | `$000200` | — |
| 237.89 | `$000122` | — |
| 238.88 | `$000200` | appel entré à `$C00444` |
| 239.88 | `$000200` | — |
| 240.88 | `$000200` | — |
| 241.88 | `$000200` | — |
| 242.88 | `$000200` | — |
| 243.88 | `$000200` | — |
| 244.89 | `$000122` | — |
| 245.88 | `$000200` | appel entré à `$C004C2` |
| 255.15 | `$000134` | appel entré à `$C0044A` |

Retours d'appel vérifiés, non listés — ils relèvent des contrats d'appel : 17 vers `$00026A`, 1 vers `$0009B2`, 1 vers `$0009BE`, 10 vers `$0013FC`, 1 vers `$003292`.

## Ce que ce document ne dit pas

- **Ni les adresses internes de la ROM du BIOS, ni la suite de ses fetchs** (`DECISIONS.md` §8) : les cibles listées sont hors de sa ROM par construction, et le contexte d'une remise ne nomme que les crans de la table publique.
- **Pas la cause d'une remise** : la trace montre où le PC va, pas pourquoi. Relier une écriture de site à la remise qui la suit est une lecture, pas une donnée.
- **Pas les registres du 68000** : une valeur passée par registre ne laisse pas de trace sur le bus.
