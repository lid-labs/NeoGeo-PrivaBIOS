# Relecture des contrats avant remise

`DECISIONS.md` §8 n'est pas automatisable : la trace donne l'adresse, la valeur et l'espace
d'adressage, jamais les registres du 68000, donc elle ne dit pas d'où vient une valeur écrite. §8
fixe la frontière ; décider de quel côté tombe chaque élément reste un jugement. Ce fichier porte
ces jugements, un par remise, parce qu'un geste sans trace n'a pas eu lieu.

**Ce qu'une entrée doit dire** : le contrat remis, à qui, ce qui a été écarté, et ce qui a été
gardé malgré un doute — avec ce qui le lève.

## `specs/traces/boot.md` → couche 0, le 2026-10-11

Un seul élément demandait un jugement : le contrat annonce que le premier fetch dans la ROM du
BIOS tombe à **`$C00402`**. Une adresse *dans* la ROM du BIOS est hors contrat par §8, sauf si
c'est un point d'entrée — la table de sauts étant publique.

**Gardé**, sur une source publique : le NeoGeo Development Wiki porte `$C00402` à `$C00432` en
première ligne de son tableau d'appels, libellé « Entry point (system boots here) »
(`wiki.neogeodev.org`, page « BIOS calls », consultée le 2026-10-11). C'est donc un point
d'entrée documenté, et §8 les admet.

> Le premier état de cette relecture appuyait sur autre chose : les trois points d'entrée que §8
> admet déjà tombent sur un pas de 6 octets depuis `$C00402` (crans 12, 13 et 32). **Cet argument
> ne concluait pas.** `$C00438` est à 54 octets de `$C00402`, soit 6 × 9 : les trois adresses
> tombent donc aussi sur son pas, et le wiki en fait précisément le début du tableau, `$C00402`
> étant la zone d'entrée qui le précède. Un pas de 6 ne distingue pas une base de n'importe quelle
> adresse 6n avant elle. La conclusion tenait, sa preuve non.

**Rien d'autre n'a été écarté** : le contrat ne porte ni adresse interne au-delà de ce point
d'entrée, ni suite de mots lue en espace donnée — il le dit, et la section « Séquences lues dans la
ROM du BIOS » est vide.

**Non remis**, et ce n'est pas le contrat : l'état des lieux des BIOS existants (non publié), qui
porte les adresses internes d'UniBIOS, de NeoPen et de nullbios. Elles ne concernent pas SNK, mais le mandat du §1
porte sur ce qu'on donne, et un implémenteur n'a aucun besoin de savoir où un autre BIOS place son
code.

**Ce que cette remise ne couvre pas** : le contrat ne porte pas les **valeurs** écrites, que §8
autorise pourtant. La couche 0 s'en passe — les registres du HC259 se pilotent par l'adresse, la
donnée du bus étant ignorée —, mais une couche suivante en aura besoin, et c'est l'un des deux
restes d'I2.

## `specs/traces/appel_C00438.md` → `SYSTEM_INT1`, le 2026-10-12

**Le contrat n'a pas été remis du premier coup, et c'est la relecture qui l'a arrêté.** Généré
d'abord avec la borne d'appel d'alors, il annonçait « le noyau du contrat » sur **46 769 à
46 778 accès**, soit 0,9997 à 0,9998 trame. `découper` fermait un appel à la sortie suivante de la ROM du BIOS, ce qui
est juste quand l'appelant reprend aussitôt, mais faux pour un gestionnaire d'interruption : il
rend la main **dans** le BIOS, par un `rte`, et rien ne le marque. Le contrat spécifiait donc la
boucle d'attente du BIOS en croyant spécifier le vblank. Corrigé avant remise — la borne suit
maintenant l'adresse empilée —, l'appel fait **1 835 à 1 847 accès**.

**Deux jugements, tous deux tranchés en faveur de la retenue.**

| Élément | Décision |
|---|---|
| `$C00438` comme point d'entrée | **gardé** : cran 9 de la table de sauts publique, `$C00402 + 6 × 9` |
| les deux adresses de **retour** | **retenues** : internes à la ROM du BIOS. Un gestionnaire d'interruption revient là où le BIOS s'était interrompu, donc son retour est une adresse interne — la publier referait la fuite que le second garde ferme du côté des valeurs |

**Vérifié après coup** : la seule adresse de la plage `$C00000`-`$C1FFFF` que le document porte est
`$C00438`. Les sites, eux, restent — §8 admet l'adresse d'une écriture en RAM : 38 en `ram_jeu`
dont 12 à valeur retenue, 37 en `ram_bios`, 4 en `lspc`, 4 en `registres_systeme`, 4 en
`backup_ram`, 2 en `controle_hc259`.

**Ce que ce contrat ne couvre pas** : la fenêtre 329,97-338,52 est celle du BIOS en attente. Ce que
`SYSTEM_INT1` fait quand un jeu tourne n'y est pas, et ce n'est pas le même code qui s'exécute.

> Levé le 2026-10-14 : le contrat est depuis consolidé sur deux fenêtres, et le régime « jeu en
> cours » y est — voir le complément ci-dessous.

## `specs/traces/appel_C00438.md`, consolidé → couche 1, le 2026-10-14

Le contrat du 2026-10-12 a été régénéré sur **deux fenêtres** — le BIOS en attente (trames
329,97-342,79) et la bascule (497,97-510,86) — et le document a changé : 16 appels au lieu de 8,
un régime court de 867 accès quand le jeu tourne, et un **noyau plus petit**. Les écritures LSPC
`$3C0000`, `$3C0002` et `$3C0004`, communes à tous les appels de la fenêtre d'attente, ne le sont
plus : le régime court ne les fait pas. Les publier en noyau aurait fait coder un contrat dur faux.
La relecture du 2026-10-12 portait sur un document différent ; celle-ci la complète sans la
remplacer.

**Les deux jugements du 2026-10-12 tiennent** : `$C00438` est le cran 9 de la table publique, et
les adresses de retour, internes à la ROM du BIOS, restent retenues.

**Vérifié après coup** : la seule adresse de la plage `$C00000`-`$C1FFFF` que le document porte
est `$C00438` ; aucune séquence suspecte signalée.

## `specs/traces/appel_C0044A.md` → couche 1, le 2026-10-14

Consolidé sur trois fenêtres — bascule, START, pièce en cours de partie : 32 appels, trois régimes.

| Élément | Décision |
|---|---|
| `$C0044A` comme point d'entrée | **gardé** : cran 12 de la table de sauts publique |
| le retour `$00026A` | **gardé** : adresse dans la P-ROM de `puzzledp`, pas dans la ROM du BIOS. §8 protège le code SNK du BIOS ; l'adresse d'où le jeu appelle est un fait de la trace, et l'implémenteur n'a pas de code de jeu à reproduire |
| 18 sites à valeur retenue | **retenus par le garde PC** : la pile du BIOS porte des adresses internes |
| **16 466 écritures écartées** | **gardé, avec sa limite** : l'appel de la trame 560,23 rend la main à la cartouche près de deux trames, et ces écritures sont le démarrage de partie du jeu. Le critère — le dernier accès en espace programme dit qui a la main — est mécanique ; le préfetch du 68000 peut décaler la frontière d'une instruction autour d'un transfert, et les écritures écartées restent lisibles dans la trace pour qui doit trancher un cas douteux |

**Vérifié après coup** : la seule adresse `$C0xxxx` du document est `$C0044A` ; aucune séquence
suspecte.

## `specs/traces/appel_C00450.md` → couche 1, le 2026-10-14

Consolidé sur trois fenêtres, 23 appels, l'appel le plus court du relevé (63-65 accès). Deux
jugements, sans surprise après les précédents : `$C00450` est le cran 13 de la table publique,
**gardé** ; les deux sites de pile à valeur retenue le sont par le garde PC. Le retour `$0013FC`
et le cadre `$0000`/`$13FC` que le jeu empile en appelant sont des adresses de la P-ROM de
`puzzledp`, publiés au même titre que le retour de `$C0044A`.

**Vérifié après coup** : la seule adresse `$C0xxxx` du document est `$C00450` ; aucune séquence
suspecte.

## `specs/traces/protocole.md` → tâche USER, le 2026-10-14

Le document est généré par le mode `--protocole` du générateur, sur les quatre traces des
fenêtres de la couche 1, régénéré à l'octet. **Le choix des sites suivis est de l'opérateur, et
c'est lui qu'il faut sourcer** : `$10FDAE`, `$10FDAF` et `$10FD80` viennent de « BIOS RAM
locations » (NeoGeo Development Wiki), qui les documente comme la demande USER, le mode USER et
le mode système. Le document lui-même ne les nomme pas, comme le reste du générateur.

| Élément | Décision |
|---|---|
| les valeurs écrites sur les sites (`$01`, `$02`, `$03`, `$82`…) | **gardées** : produites par l'exécution, écrites en RAM, aucune ne porte une adresse de ROM BIOS — le garde PC n'a rien signalé |
| les cibles des remises de main (`$000122`, `$000128`, `$000134`, `$000200`, `$00026A`) | **gardées** : adresses de la P-ROM de `puzzledp`, même régime que les retours déjà publiés par les contrats d'appel |
| les contextes des remises | **gardés** : seuls des crans de la table publique y paraissent (`$C0044A`, `$C004C2`) |
| séquences lues dans la ROM | aucune signalée |

**Vérifié après coup** : les seules adresses `$C0xxxx` du document sont `$C0044A` et `$C004C2`,
deux crans publics.

**Ce que cette remise ne couvre pas** : la **cause** des remises — relier une écriture de site à
la remise qui la suit est une lecture, le document le dit — et tout ce qui tombe **entre la
trame 9,2 et la trame 330** : si le BIOS SNK fait une demande USER d'initialisation pendant son
test mémoire, aucune fenêtre relevée ne la porte. Le premier passage à `$000122` visible est
celui de la trame 502,89, demande `$03`.

## `specs/traces/appel_C00444.md` → SYSTEM_RETURN, le 2026-10-15 au soir

Le contrat naît de la **neuvième trace** : la fenêtre du game over de `nam1975` (trames
5 315-5 330), trouvée par la chasse en écritures seules — le joueur laissé sans entrées meurt,
et la cartouche rend la main à `$C00444` à 5 319,88. Deux appels relevés : l'interne du
boot (238,80, 3 712 accès) et celui-ci (33 820 accès).

| Élément | Décision |
|---|---|
| `$C00444` point d'entrée | **gardé** : cran 11 de la table publique |
| les retours `$000200` et `$000918` | **gardés** : adresses des P-ROM — ce sont des bornes de **repli** (entrée sans cadre empilé), et elles disent un fait : après SYSTEM_RETURN, le BIOS de référence reste en mode système et appelle la cartouche à son rythme d'attente ; la remise à `$122` (demande 2) tombe ~2 trames plus tard, **hors de l'appel délimité** — `protocole.md` la porte |
| `$3C0006` ← `$4000`, `$10FEE1` ← `$FF`, `$3C000C` ← `$0007` | **gardés** : valeurs d'exécution sur registres et RAM, §8 les admet. `$10FEE1` ← `$FF` résout au passage « qui pose FRAME_SKIP », question ouverte du contrat de SYSTEM_IO |
| 6 sites de pile à valeur retenue | garde PC, comme toujours |

**Effet de la consolidation sur les autres contrats**, consigné sans les remettre : le noyau
d'INT1 passe de 84 à 82 sites (deux sites de pile), celui de CREDIT_CHECK de 6 à 1 — `nam1975`
y prend un chemin plus court que `puzzledp`. Fait de contrat ; le SYSTEM_IO livré n'est pas en
écart (écrire plus que le noyau n'en est pas un).

**Vérifié après coup** : la seule adresse `$C0xxxx` du document est `$C00444` ; aucune séquence
signalée ; les quatre contrats touchés régénérés à l'octet.

## `specs/traces/protocole.md`, étendu au port son → handshake son, le 2026-10-15

Régénéré sur **huit traces** (les six de la consolidation, plus deux fenêtres de boot SNK :
0-69,6 plafonnée en accès, et 228-251, celle du handshake) avec un **quatrième site suivi** :
`$320000` — REG_SOUND, « Memory mapped registers » —, choix d'opérateur motivé par le diagnostic
de `wjammers`, dont le pilote son attend une réponse que notre boot muet ne provoque jamais. Le
mode `--protocole` chronique désormais aussi les **lectures** des sites suivis (« lecture —
valeur non observable ») : un BIOS qui scrute une réponse la lit en boucle, et taire ces lectures
ferait croire à un envoi aveugle. Deux tests de plus, mutation éprouvée.

| Élément | Décision |
|---|---|
| les commandes écrites sur `$320000` (`$01`, `$03`, `$02`) | **gardées** : valeurs produites par l'exécution, écrites sur un registre — §8 les admet ; aucune séquence signalée, garde PC muet |
| les lectures des sites | **gardées comme faits** : adresse et ordre seulement, aucune valeur — le banc n'en observe pas |
| la fenêtre 228-251 comble le trou du relevé USER | la première remise de SNK (demande 0, trame 237,89) et son SYSTEM_RETURN interne (238,80) y sont — la réserve « entre 9,2 et 330 » de la remise USER du 2026-10-14 est levée pour ce segment |

**Vérifié après coup** : les seules adresses `$C0xxxx` du document sont quatre crans publics
(`$C00438`, `$C00444`, `$C0044A`, `$C004C2`), en contexte de remises ; régénéré à l'octet.

## `specs/traces/appel_C00438.md`, consolidé avec `joyjoy` → correction d'INT1, le 2026-10-15

Les contrats sont désormais générés de **six traces et deux jeux** : les quatre fenêtres de
`puzzledp` et deux fenêtres de `joyjoy` (498-530 et 558-580 sous BIOS SNK). La consolidation
multi-jeux a été déclenchée par un diagnostic — sous notre image, `joyjoy` se fige — et elle a
révélé un fait de contrat : **`$3C000C` passe de la valeur unique `$0004` à « 2 valeurs :
`$0004`, `$0007` »** — l'INT1 de référence acquitte aussi le timer, sur un chemin que
`puzzledp`, qui n'arme jamais le timer, ne prend pas. Il ne manquait pas une fenêtre : il
manquait un jeu. **La cause du figement, elle, était ailleurs**, et c'est la passe
d'implémentation qui l'a mesurée : les jeux entrent dans INT1 sans empiler d'adresse de retour, notre `rts` dépilait le
cadre d'exception — le « niveau 2 collé » du diagnostic initial était un symptôme du plantage,
pas un timer orphelin. Les « Retour vers » du contrat — des PC interrompus — portaient déjà la
signature du `rte`.

| Élément | Décision |
|---|---|
| `$C00438` point d'entrée, retours internes retenus | **inchangés** : les jugements du 2026-10-12 et du 2026-10-14 tiennent |
| les retours nouveaux (`$000122`, `$0011E8`-`$0012C6`) | **gardés** : adresses des P-ROM de `puzzledp` et `joyjoy` — les sites d'appel des jeux, même régime que `$00026A` |
| 25 valeurs du noyau devenues multi-états ou retenues | la consolidation fait son travail : des valeurs stables d'un seul jeu ne l'étaient que dans son régime |
| ~4 100 écritures partielles de palette | **gardées en partielles** : l'écran d'attente de SNK, marqué « à ne pas prendre pour le contrat » — §8 admet adresses et valeurs de palette |

**Vérifié après coup** : la seule adresse `$C0xxxx` du document est `$C00438` ; aucune séquence
signalée ; régénéré à l'octet.

**Consolidés sans être remis, même date** : `appel_C0044A.md` — son noyau fond de 39 à 9 sites,
les appels de `joyjoy` n'écrivant pas les 30 autres : SNK y a un chemin court que `puzzledp` ne
prend jamais. Fait de contrat, pas défaut du SYSTEM_IO livré (écrire plus que le noyau n'est pas
un écart) ; sa relecture complète se refera à sa prochaine remise. `appel_C004C2.md` reste de la
couche 2, non remis.

## Régénérés sans être remis, le 2026-10-14

`appel_C004C2.md` (consolidé, 3 appels) et `appel_C004C8.md` (créé, 3 appels) sont de la
**couche 2** : leur relecture se fera à leur remise, comme les autres. Les versionner relus
d'avance affaiblirait la règle — une relecture vaut pour le document qu'on remet, et ils peuvent
encore changer avec de nouvelles fenêtres.

## Faits mesurés → coin lockout et garde START, le 2026-10-16

La remise n'est pas un contrat régénéré : c'est le diagnostic de la famille « aucun jeu ne lance
de partie sous notre image », mesuré sous MAME (jig lua jetable, `wjammers`, plan d'entrées de la
matrice). Elle porte quatre faits et deux pages de wiki, rien d'autre.

| Élément | Décision |
|---|---|
| sous notre image, le bit pièce de `$320001` ne descend jamais ; après une écriture d'octet sur `$380065` et `$380067`, la pièce suivante apparaît et notre détection de front fonctionne sans autre changement | **gardé** : mesure causale sur notre propre image |
| la référence écrit un octet `$00` sur `$380065` et `$380067`, une fois, à la trame 0 | **gardé sans les PC** : comportement boîte noire (adresse, donnée, trame) ; les adresses des instructions de la référence sont retenues — elles guideraient vers son code |
| la référence accepte un START à crédit `$01` alors que `$10FDB0` vaut `$00` à la décision — elle le remet elle-même à zéro chaque trame où la demande du jeu (`$0202` au titre) dépasse le crédit — puis le crédit passe à `$00` | **gardé** : valeurs de RAM BIOS et de backup RAM, le régime même du différentiel ; conséquence : la garde « DEC nul → refuse » de notre `_io_start` est réfutée, la garde porte sur le crédit |
| sous notre image, le jeu pose DEC `$0101` chaque trame et notre `_credit_check` le remet à zéro : conforme — le crédit valait réellement zéro (NVRAM résiduelle lue `$01` par une sonde antérieure, run non isolé) | **gardé comme mise en garde** : il dit au correcteur que `_credit_check` n'est pas en cause |
| wiki « Memory mapped registers » : `REG_RESETCL1` `$380065`, `REG_RESETCL2` `$380067`, « coin lockout 1/2 floats », donnée quelconque, NEO-I0 | **gardé** : source publique nommée |

**Vérifié après coup** : aucune adresse `$C1xxxx` (PC de la référence) dans la remise ; aucune
séquence d'instructions ; les valeurs citées sont des registres matériels, de la RAM BIOS et de
la backup RAM, que §8 admet.

**Complément, même jour — la déduction au START.** Mesure discriminante (jig lua, `wjammers`,
deux pièces puis START) : la référence déduit **1 crédit** (`$D00034` passe de `$02` à `$01`)
alors que la demande du jeu au titre vaut `$0202` et que `$10FDB0` est lu `$00` avant comme après
la décision ; à un seul crédit, la déduction tombe à `$00` alors que le jeu ne pose son DEC
qu'à la trame suivante. La déduction n'est donc ni « DEC d'avant », ni « DEC relu au retour de
PLAYER_START » (ce que portait notre code), ni la demande du jeu : c'est **un crédit par joueur
parti** — le réglage « crédits par start », `1` en configuration par défaut, les soft-DIP étant
hors lot. Remis à l'agent : ces valeurs de backup RAM et de RAM BIOS (régime du différentiel),
sans aucun PC de la référence. La phrase du wiki « deducts credits according to BIOS_CREDIT_DEC »
est citée comme démentie par la mesure dans ce régime.

## Faits mesurés → code pays du descripteur, le 2026-10-16

Diagnostic de `neomrdo` (figé noir sous notre image, vivant sous SNK, UniBIOS et nullbios),
mesuré sous MAME par taps lua. La remise porte trois faits et une page de wiki.

| Élément | Décision |
|---|---|
| le jeu lit `$10FD83` à son init (taps de lecture) et y trouve `$00` chez nous, `$02` sous nullbios ; ses écritures de palette vont alors à `$400740` au lieu de `$400000` — mêmes couleurs, écran noir | **gardé** : lectures et valeurs de RAM BIOS, régime du différentiel ; les PC du jeu cités sont ceux de `neomrdo`, pas d'un BIOS |
| test causal sur notre image : un tap qui force `$10FD83` à `$02` rend l'écran à `neomrdo`, anime `flipshot`, allume `kof98` | **gardé** : mesure causale sur notre propre image |
| la référence euro pose `$10FD82=$80`, `$10FD83=$02` (sonde, `neomrdo`, trames 300+) | **gardé** : valeurs de RAM BIOS, aucun PC de référence |
| wiki « BIOS RAM locations » : `$10FD83` BIOS_COUNTRY_CODE, 0 Japon, 1 USA, 2 Europe | **gardé** : source publique nommée |

**Vérifié après coup** : aucune adresse `$C1xxxx` ni séquence de la référence dans la remise.

## Dixième trace (pièce pendant FRAME_SKIP) → consolidation générale, le 2026-10-16

Une trace nouvelle — boot SNK sur `puzzledp`, trames 228 à 262, **pièce injectée aux trames
242-250** (`--pad=242-250:coin`) — rejoint les neuf existantes, et `$10FEE1` (BIOS_FRAME_SKIP,
« BIOS RAM locations ») devient le cinquième site suivi du protocole. Elle a été levée pour le
mécanisme que le diagnostic de `neomrdo` a montré : la référence arme FRAME_SKIP à chaque
remise, et une pièce pendant le décompte ne sonne COIN_SOUND qu'au premier zéro.

| Élément | Décision |
|---|---|
| les valeurs de `$10FEE1` chroniquées (`$FF` aux remises — 234.30, 238.80, 242.92 —, recharge `$0A`, décompte, lectures ×3 par trame) | **gardées** : valeurs de RAM BIOS, régime du différentiel |
| la remise interne déclenchée par la pièce (242.92 : `$10FEE1`←`$FF` et `$10FD80`←`$01` dans le même souffle) | **gardée** : c'est le fait central — l'armement suit la remise, pas la pièce |
| les contrats d'appel consolidés (48 appels d'INT1, 65 de SYSTEM_IO, re-comptages en cascade) | **gardés** : la consolidation fait son travail ; aucun site nouveau hors RAM BIOS/backup/registres |
| le fetch de la remise à `$000134` (COIN_SOUND) à la trame ~255,1, première à FS nul | **gardé** : adresse publique du « 68k program header » |

**Vérifié après coup** : les seules adresses `$C0xxxx` des documents sont les crans publics ;
aucune adresse `$C1xxxx` ; régénérés à l'octet depuis les dix traces (base de 8 reproduite à
l'octet avant l'ajout, composition confirmée).

**Complément, même jour — la pièce relance la remise.** Mesuré (MAME, `neomrdo`, boîte noire) :
la remise de la référence se décale derrière la pièce — pièce à la trame 297 → crédit 298 →
remise `$82` à 300 ; pièce 299 → 302 ; sans pièce, 289. La trace 9 porte le même fait côté bus :
à 242.92, `$10FEE1`←`$FF` et `$10FD80`←`$01` tombent au même instant que la pièce, la main au
BIOS. Une pièce créditée hors partie déclenche donc une **nouvelle remise USER** (le passage au
titre du MVS), et le jeu repart avec le crédit déjà en place — il ne voit jamais un crédit
tomber au milieu de son init. Remis à l'agent : ces trames et valeurs, aucune adresse
d'instruction de la référence.

## `appel_C004C2.md` et `appel_C004C8.md` → FIX_CLEAR et LSP_1st, le 2026-10-16

Première remise de ces deux contrats de couche 2 (régénérés le 2026-10-14, consolidés depuis,
jamais remis). Le déclencheur est mesuré : `neomrdo` appelle les deux crans à son init et au
START (fetchs relevés aux trames 2 et 100 sous notre image), nos bouchons ne font rien, et le
plan fix du titre recouvre la partie — le jeu joue (pages VRAM identiques à la référence à
l'unité près) derrière un écran que rien n'efface.

| Élément | Décision |
|---|---|
| noyau de `$C004C2` : `$3C0000` ← `$7000`/`$7020`, `$3C0002` ← `$0020`/`$00FF`, `$3C0004` ← `$0001` | **gardé** : registres LSPC, valeurs d'exécution — §8 les admet |
| noyau de `$C004C8` : `$3C0000` ← `$0000`/`$8000`, `$3C0002` ← 4 valeurs, `$3C0004` ← `$0001`/`$0002` | **gardé** : idem |
| la traîne « 2/8 » et « 2/4 » (sites `$10FD9x`, compteurs, backup) | **gardée avec mise en garde à l'agent** : c'est une SYSTEM_INT1 tombée pendant l'appel, pas le corps de l'appel — ne pas l'imiter |
| sites `$10F2xx` aux valeurs retenues | **gardés tels quels** : la pile du BIOS, §8 retient déjà leurs valeurs ; une autre implémentation empile les siennes |

**Vérifié après coup** : les seules adresses `$C0xxxx` sont les deux crans publics ; aucune
séquence à trancher (les contrats le disent) ; régénérés à l'octet.

## Faits mesurés → formatage de la backup RAM au boot, le 2026-10-16

Diagnostic de `kof98` (reboote au watchdog sous notre image : longue init sans kick, IRQ
masquées, après lecture de la zone backup système). La remise porte des faits mesurés sous MAME
et une page de wiki ; la trace cosim de la fenêtre n'a pas pu servir — **le boot de la référence
au banc ne passe pas par le test/formatage backup** (aucune écriture `$D0001x` sur 335 trames
tracées, alors que MAME les montre), vraisemblablement un état d'environnement que le banc force
autrement (calendrier) ; biais d'instrument consigné ici.

| Élément | Décision |
|---|---|
| le boot de la référence teste la backup (patterns `$5555`, `$AAAA`, valeur dérivée de l'adresse — trames 38-62 sur `puzzledp`) puis écrit la signature ASCII « BACKUP RAM OK ! » suivie de `$80` à `$D00010-$D0001F` (~trame 74) | **gardé** : valeurs de backup RAM, mesure boîte noire sans aucun PC |
| l'état stable formaté, mesuré par dumps espacés (335 et 495, `kof98`) : signature ; `$D0003A-$D00041` = `01 01 01 02 01 01 01 03` ; `$D00044-45` = `30 3B` ; `$D00046-47` = `00 02` ; `$D0004C` = `3B` ; `$D00058` = `FF` ; `$D0005A-5D` = minuteur vivant (seules les secondes bougent entre les deux dumps) ; `$D0005E-5F` = `FF FF` | **gardé** : idem ; la part vivante est signalée comme telle |
| test causal : la zone posée par tap à la trame 1 sous notre image sort `kof98` du noir (écran allumé, encore statique — d'autres causes restent) | **gardé** : mesure causale sur notre propre image |
| wiki « Backup RAM » : la structure de la zone système et son invalidation/formatage par le BIOS | **gardé** : source publique, l'agent lira la page |

**Vérifié après coup** : aucun PC de la référence, aucune séquence d'instructions.

## Faits mesurés → table d'aléa, attente de la remise, pièce au boot, le 2026-10-16

Diagnostic de `kof98` (joue noir ~59 %) qui a emporté la famille des FIGE (`garou`, `mslug3`,
`svc`) : trois causes, trois tests causaux, relevé
`measured/2026-10-16-kof98-diagnostic-remise.tsv`. Aucun contrat généré ne peut porter ce lot —
les quatre jeux sont hors banc cosim (P-ROM chiffrées ou à banques) : la remise porte des faits
mesurés sous MAME (sonde, jigs à taps, NVRAM isolée) et des pages publiques.

| Élément | Décision |
|---|---|
| le jeu lit des octets à `$C04200-$C042FF` comme table d'aléa, et reste bloqué quand la fenêtre est remplie de `$FF` ; fenêtre `$C04200-$C042FF`, lectures voisines `$C04000+k×$40` (k=0..7, constantes tolérées) | **gardé** : adresses et exigence fonctionnelle, mesurées au tap sur notre propre image ; aucune valeur de la ROM SNK n'a été relevée ni ne passe — le contenu de la table est à écrire par l'agent (octets à nous, variés sur la fenêtre) |
| les PC où le jeu reste bloqué (fenêtres `$0033A0-$003500` et `$096550-$096590`) et les adresses qu'il lit pendant ce temps : `$3C0006`, `$100090`, `$10008E`, table | **gardé** : adresses du jeu, relevées chez nous ; contexte du critère, rien à imiter |
| sous SNK, le BIOS attend IRQ ouvertes (SR échantillonné `$2000`, INT1 vivant — `$10FEE4` avance de 1/trame) avant la remise, puis remet la main masquée (premières trames du jeu à IPL 7) ; le jeu rouvre lui-même | **gardé** : structure du protocole, SR et compteurs mesurés boîte noire |
| les PC du BIOS de référence relevés pendant ce diagnostic (attente, écrivains de la remise) | **écartés** : adresses d'instructions de la référence, elles ne passent jamais |
| durée de l'attente : variable selon le jeu (longue sur `puzzledp`, ~1-2 trames sur `kof98`) ; piste « drapeau eye-catcher de l'en-tête `$114` » (wiki « 68k program header ») non confirmée — `kof94` la casse au grain de mesure disponible | **gardé comme non-tranché** : la condition de sortie de l'attente est au choix de l'agent, dite SUPPOSÉ ; un seuil fixe de ticks d'INT1 a suffi aux dix jeux testés (jetable 4) |
| sous SNK, une pièce aux trames 0-8 du boot ne change pas la première remise ; chez nous `_retour_piece` relance USER au titre depuis le boot et `neomrdo` fige dès 1000 (jetable 4) | **gardé** : fait mesuré avec et sans pièce ; la garde à écrire est « pas de relance avant la première remise », son mécanisme est au choix de l'agent |
| tests causaux (quatre images jetables : SR seul, table seule, les deux, attente+table) et leurs matrices | **gardés** : mesures sur nos propres images, c'est le critère du lot |
| pages publiques : « SYSTEM_INT1 », « 68k interrupts », « BIOS RAM locations », « 68k program header » | **gardées** : l'agent les lira lui-même |

**Vérifié après coup** : aucune adresse d'instruction de la référence dans la remise ; aucune
valeur lue dans la ROM SNK ; les seules adresses `$C0xxxx` remises sont la fenêtre de données
`$C04000-$C042FF` et les crans publics déjà connus.

**Complément, même jour — les soft-DIP et la zone backup par jeu.** Les trois remises
alternatives de l'agent (remise ouverte, ouverte au vblank, `$80 | mode`) ont été jugées sur
les dix et rejetées : la remise masquée de vI reste. La sonde de la boucle fatale de `kof98`
sous vI (`$00B40C-$00B456`) relève ce qu'elle lit : `BIOS_GAME_DIP` (`$10FD84-$10FD92`, octet
par octet), la zone backup `$D00108`, `$D00128-$D00140`, et `$C00402`.

| Élément | Décision |
|---|---|
| sous la référence, le BIOS écrit la zone backup par jeu `$D00100-$D0014E` à la trame 77, puis `$10FD84-$10FD92` aux trames 276-279, juste avant la remise (~280) — main au BIOS, tap d'écriture, adresses seules | **gardé** : adresses de RAM BIOS et de backup, mesure boîte noire ; ni valeur ni PC de la référence |
| les lectures de la boucle de `kof98` sous notre image (adresses ci-dessus) | **gardé** : relevé chez nous |
| le lien de cause « ces zones vides font mourir `kof98`, `garou`, `mslug3` » | **gardé comme hypothèse** : non prouvé — l'agent reçoit le moyen de le réfuter, pas la conclusion |
| wiki « 68k program header » (pointeurs des soft-DIP par région) et « Software DIPs » (structure, défauts) ; « BIOS RAM locations » pour `BIOS_GAME_DIP` | **gardé** : sources publiques, l'agent les lit ; les valeurs viennent de l'en-tête de chaque cartouche |

**Issue de ces remises.** Seule la table d'aléa est livrée (`src/c0/alea.s`). L'attente avant
la remise et la garde de la pièce, écrites par l'agent, ont été retirées : la table seule
donne exactement le même gain (mesuré, six jeux), elles n'en ajoutaient aucun. L'hypothèse des
soft-DIP et celle de la zone backup par jeu sont réfutées par test causal (le relevé le dit) ;
rien n'en est passé dans le code.

## Faits mesurés → la table des slots et la demande 0 au premier boot seulement, le 2026-10-16

Diagnostic de `kof98`, `garou`, `mslug3` (reboot ou gel sans fin) : la demande 0 de `kof98`
s'achève par une temporisation volontaire vers le reset, et la référence ne l'appelle qu'au
premier boot du jeu. Relevé `measured/2026-10-16-demande-0-slots.tsv`. Hors banc cosim : la
remise porte des faits mesurés sous MAME et une page publique.

| Élément | Décision |
|---|---|
| premier boot : `$D00124` ← NGH du jeu, `$D00126` ← `$FFFF` puis `$0000`, `$D00104-$D00107` ← `2610 1605`, `$D00108` parcouru ; remise en demande 0 | **gardé** : adresses et valeurs de backup RAM, écrivain par tap, aucun PC de la référence |
| boot suivant : entrée retrouvée, réécrite à l'identique ; remise en demande 2, mode 1 (`$10FDAF` ← `$01`, `$10FDAE` = `$02`) | **gardé** : idem |
| le gestionnaire de demande 0 de `kof98` (adresses de la cartouche) et sa temporisation | **gardé** : code du jeu, contexte du critère, rien à imiter |
| test causal : la remise forcée en demande 2 / mode 1 fait jouer `kof98` (PC de sa démo, aucun reboot) et avancer `mslug3` | **gardé** : mesure sur notre image |
| le rôle de `$D00104-$D00107` et de `$D00108`, le choix d'un slot libre, la table pleine | **non tranché** : SUPPOSÉ à dire par l'agent, après lecture du wiki « Backup RAM » |

**Vérifié après coup** : aucune adresse d'instruction ni octet du BIOS de référence dans la remise.

**Issue de cette remise.** Écrite par l'agent dans `c0.s` (table cherchée par NGH, inscrite si
absente, formatée si incohérente). `kof98` et `mslug3` jouent. `garou` passe du gel au segfault
de MAME, cause non établie (relevé). La date `$D00104-$D00107` n'est pas écrite : ce BIOS ne
lit pas l'horloge, et la valeur mesurée était le jour de la mesure.

## Faits mesurés → les soft-DIP de la cartouche dans BIOS_GAME_DIP, le 2026-10-16

La dernière tâche ouverte de la couche 1. La mesure qui manquait vient du diagnostic de la
table des slots : `kof98` lit `BIOS_GAME_DIP` et le recopie dans son bloc de sauvegarde. Relevé
`measured/2026-10-16-soft-dip.tsv`, quatre jeux, sous MAME.

| Élément | Décision |
|---|---|
| `BIOS_GAME_DIP` à la première remise, et le bloc soft-DIP Europe de la cartouche (pointeur long en `$11E`) : 6 octets recopiés, puis le quartet haut de 10 octets | **gardé** : valeurs de RAM BIOS écrites par la référence, et octets de la cartouche ; la règle se vérifie sur les quatre jeux sans exception |
| boot suivant : `BIOS_GAME_DIP` relu depuis le bloc de sauvegarde (`$D00220 + 16 × index`), prouvé par une valeur posée dans le bloc | **gardé** : mesure boîte noire, backup RAM |
| premier boot : c'est le BIOS qui remplit le bloc (aucun écrivain cartouche sur `puzzledp`) | **gardé** : idem ; la trame exacte n'est pas relevée |
| pages publiques « Software DIPs », « 68k program header » (pointeurs Japon `$116`, USA `$11A`, Europe `$11E`), « Backup RAM » | **gardé** : l'agent les lit |
| un pointeur nul ou hors ROM, les autres régions | **non tranché** : SUPPOSÉ à dire par l'agent |

**Vérifié après coup** : aucune adresse d'instruction ni octet du BIOS de référence.

**Issue de cette remise.** Écrite par l'agent dans `c0.s`, sur les deux chemins de la table des
slots. Égale à la référence octet pour octet sur les quatre jeux, relecture du bloc prouvée.
Choix SUPPOSÉ dits dans le code : le pointeur suit `BIOS_COUNTRY_CODE` (`$116 + 4 × code`, l'Europe
hors de 0-2) ; un pointeur nul ou hors de la P-ROM fixe est refusé et laisse les zéros ; un
pointeur impair est accepté, la lecture se faisant octet par octet.

## Faits mesurés → le départ forcé (« game start compulsion »), le 2026-10-17

Diagnostic de `minasan`, qui reste à son écran de sélection, « TIME » figé, sous notre BIOS.
Relevé `measured/2026-10-17-diagnostic-b2b-minasan.tsv`, sous MAME, une puis deux pièces, sans
START.

| Élément | Décision |
|---|---|
| à la pièce : `$10FDDA` ← `$30` (BCD), `$10FDDB` ← `$3B` ; une seconde pièce recharge `$10FDDA` à `$30` | **gardé** : valeurs de RAM BIOS écrites par la référence, relevées par trame |
| décompte : `$10FDDB` −1 par trame de `$3B` à `$00`, puis `$10FDDA` −1 (BCD) et `$10FDDB` ← `$3B` ; une seconde toutes les 60 trames | **gardé** : idem |
| à `$00`/`$00`, mode titre (`$10FDAF` = 1) et un crédit : `$000128` atteint avec `$10FDB4` = `$01`, puis mode 2 et un crédit déduit — le chemin d'un START du joueur 1 | **gardé** : idem, plus le fetch de `$000128` (adresse de la cartouche) |
| `$D00044` = `$30` après le formatage, « Game start compulsion time », « initialized to $30 » | **gardé** : déjà dans `c0.s`, et la page « Backup RAM » |
| environ 25 trames sans décompte juste après la pièce | **écarté** : non expliqué, sans effet sur le critère |
| le drapeau d'activation (`$D00042`/`$D00043`, « 0 = activée ») | **non tranché** : SUPPOSÉ à dire par l'agent, après lecture de « Backup RAM » |

**Vérifié après coup** : aucune adresse d'instruction ni octet du BIOS de référence dans la remise.

**Issue de cette remise.** Écrite par l'agent dans `io.s` : armement dans `_io_crediter`,
décompte et déclenchement dans `_io_compulsion`, le START P1 forcé par un bit ajouté à l'appui
que lit `_io_start`. `$D00043` honoré (lu dans « Backup RAM »). Une correction après jig : le
départ tombait une seconde trop tard (à 00/3B épuisé) ; il tombe au passage des secondes à 00.
`minasan` joue, 20/22. Choix SUPPOSÉ dits dans le code : décompte sous FRAME_SKIP nul (11 trames
d'écart), armement à toute pièce, départ refusé non retenté, joueur 1 seul.

## Faits mesurés → MESS_OUT et la remise calée sur le vblank, le 2026-10-17

Diagnostic de `b2b`. Relevés `measured/2026-10-17-diagnostic-b2b-minasan.tsv` (partie B2B : la
remise) et `measured/2026-10-17-b2b-mess-out.tsv` (MESS_OUT), sous MAME. Pas de contrat généré :
`b2b` n'est pas au banc cosim, et la tâche MESS_OUT de `tasks.md` en prévoyait un.

| Élément | Décision |
|---|---|
| la remise : SNK rend la main à 0,022 de trame, nous à 0,898 ; le jeu ouvre ses IRQ avant d'initialiser sa file de palette, le vblank (ligne `$1F0`) tombe avant | **gardé** : phases et adresses de la cartouche |
| test causal : attendre que `$3C0006` (bits 15-7) vaille `$1F0`, puis `$3C000C` ← 7, avant le `jmp $122` de toute remise : plus d'erreur d'adresse, corpus 19/22 sans régression | **gardé** : mesure sur notre image |
| MESS_OUT appelé par le jeu à `$C004CE` (655 fois sous SNK, trames 400-1300) ; l'essentiel des écritures VRAM passe par le BIOS | **gardé** : comptes |
| `$10FDBE` ← `$0010FF00` au boot (trame 279), avant la remise ; remis à `$10FF00` à la fin de chaque appel ; `$10FDC2` ← 01 pendant, 00 après | **gardé** : valeurs de RAM BIOS écrites par la référence |
| un appel décomposé : la liste de `b2b` lue (commandes 3, 1, 7, 5, 7, 0) et les écritures `$3C0000`/`$3C0002` qui en sortent | **gardé** : données de la cartouche et sorties LSPC |
| `$10FEC6` ← `$0010FECA` pendant l'appel | **écarté** : usage interne, non interprété |
| la pile du BIOS pendant l'appel (`$10F200-$10F2FF`) | **écarté** : elle porte des adresses de la référence ; exclue des relevés et de l'instrument |
| la page « MESS_OUT » (tampon, quatorze commandes, appel depuis SYSTEM_INT1) | **gardé** : l'agent la lit |
| les polices des commandes 8 et 9 (numéros de tuiles du plan fixe) | **non tranché** : SUPPOSÉ à dire par l'agent, d'après la page |

L'instrument du critère : `bench/mess-diff.lua` — pour chaque appel, l'entrée lue et la sortie
LSPC et RAM BIOS ; une même entrée doit donner la même sortie sous SNK et sous notre image.

**Vérifié après coup** : aucune adresse d'instruction ni octet du BIOS de référence dans la remise.

**Issue de cette remise.** Écrite par l'agent : `mess.s` (nouveau), l'entrée `$C004CE` et
SYSTEM_INT1 qui l'appellent, `BIOS_MESS_POINT` posé au boot, et la remise calée sur la ligne
`$1F0` dans `c0.s`. `b2b` joue : sur 407 listes vues sous SNK et chez nous, 407 sorties LSPC
égales ; corpus 21/22. Choix SUPPOSÉ dits dans le code : les polices des commandes 8 et 9, le
signe de l'auto-incrément, l'état initial de chaque appel, les cas limites des sous-listes, et
une garde sur un pointeur de fin hors du tampon.

## Faits mesurés → CARD sans carte mémoire, le 2026-10-19

Pas de diagnostic derrière ce lot : les 164 jeux du catalogue tournent sans lui, mais 82 l'appellent
sous SNK (`measured/2026-10-19-appels-catalogue.tsv`), et notre entrée `$C00468` est un `rts`.
Relevé `measured/2026-10-19-card-sans-carte.tsv`, sous MAME, sans carte insérée, 8 appels sur
5 jeux. Pas de contrat généré : le banc cosim ne passe pas ces jeux jusqu'à l'appel.

| Élément | Décision |
|---|---|
| `$10FD00` (long) ← le SP à l'entrée du service, adresse de retour empilée, **moins 4** | **gardé** : écriture en RAM BIOS par la référence, la valeur étant le SP du jeu, non une adresse de la référence. Remis d'abord sans le « moins 4 » : corrigé après le jig (voir l'issue) |
| `$10FCF4` (octet) ← `$FF` | **gardé** : écriture en RAM BIOS par la référence ; rôle non interprété |
| `$10FDC6` (octet) ← `$80`, dans cet ordre, après les deux autres | **gardé** : idem, et la page « CARD » (« aucune carte insérée ») |
| les mêmes écritures pour les commandes `$01` et `$02` ; aucune écriture en zone carte ; retour dans la trame | **gardé** : relevé |
| la pile du BIOS pendant l'appel (`$10F200-$10F2FF`) | **écarté** : elle porte des adresses de la référence ; exclue du relevé et du jig |
| la page « CARD » (variables, commandes, codes de réponse) | **gardé** : l'agent la lit |
| les commandes autres que `$01` et `$02`, le régime avec carte | **non tranché** : SUPPOSÉ à dire par l'agent ; le régime avec carte est un autre lot |

L'instrument du critère : `bench/card.lua`, passé sous SNK et sous notre image sur les 5 jeux du
relevé ; mêmes adresses écrites, dans le même ordre, même `$10FDC6` après.

**Vérifié avant la remise** : aucune adresse d'instruction ni octet du BIOS de référence.

**Issue de cette remise.** Écrite par l'agent : `card.s` (nouveau) et l'entrée `$C00468` dans
`c0.s`. La première image écrivait le SP d'entrée : le jig sous notre image a montré l'écart de 4
sur les 8 appels, la remise a été corrigée et l'agent a repris `_card`. Ensuite, mêmes écritures
et mêmes valeurs que SNK sur les 8 appels ; corpus 21/22. Choix SUPPOSÉ dits dans le code : les
commandes autres que `$01` et `$02`, BIOS_CARD_SUB non écrit, aucun registre modifié.

## Faits mesurés → READ_CALENDAR, le 2026-10-19

Pas de diagnostic derrière ce lot : 35 jeux du catalogue appellent `$C0045C` sous SNK
(`measured/2026-10-19-appels-catalogue.tsv`), notre entrée est un `rts`. Relevé
`measured/2026-10-19-read-calendar.tsv`, sous MAME, sur blazstar et trally. Pas de contrat
généré : le banc cosim fige la date et ne passe pas ces jeux jusqu'à l'appel.

| Élément | Décision |
|---|---|
| la séquence vers REG_RTCCTRL (`$380051`) : commandes `$3` puis `$1`, bits DATA IN/CLK/STB = 0/1/2, poids faible d'abord, puis 52 lectures du bit 7 de REG_STATUS_A (`$320001`) suivies chacune d'un coup d'horloge | **gardé** : accès matériels relevés, et le protocole de la puce, public |
| le décodage des 52 bits, et le mois lu en binaire, écrit en BCD | **gardé** : relevé, un appel décodé contre ses écritures |
| les sept écritures `$10FDD8`, `$10FDD7`, `$10FDD6`, `$10FDD4`, `$10FDD5`, `$10FDD3`, `$10FDD2`, dans cet ordre | **gardé** : écritures en RAM BIOS par la référence ; noms et formats dans « READ CALENDAR » |
| l'écart minimal de 4,5 µs entre deux écritures à l'horloge | **gardé** : relevé ; le minimum qui fait foi est celui de la fiche technique, que l'agent lit |
| les commandes `$8` puis `$7` et une lecture complète au boot de la référence | **écarté** : hors de ce service ; une tâche du boot, à mesurer seule |
| la pile du BIOS pendant l'appel (`$10F200-$10F2FF`) | **écarté** : adresses de la référence ; exclue du relevé et du jig |
| les pages « READ CALENDAR », « UPD4990 », « Memory mapped registers », et la fiche technique officielle du µPD4990A | **gardé** : l'agent les lit |
| SETUP_CALENDAR (`$C00462`), le signal TP | **non tranché** : hors lot, aucun jeu du catalogue n'appelle `$C00462` |

L'instrument du critère : `bench/cal.lua`, sous SNK et sous notre image sur blazstar et trally ;
mêmes accès à l'horloge, mêmes écritures en RAM dans le même ordre, et des valeurs cohérentes avec
l'heure du passage.

**Vérifié avant la remise** : aucune adresse d'instruction ni octet du BIOS de référence.

**Issue de cette remise.** Écrite par l'agent : `cal.s` (nouveau) et l'entrée `$C0045C` dans
`c0.s`. Chaque appel complet fait les mêmes accès à l'horloge et les mêmes écritures en RAM que
SNK, à la même date ; corpus 21/22. Écart minimal entre deux écritures à l'horloge : 3,83 µs,
contre 4,5 chez SNK et 1 au minimum de la fiche technique. Choix SUPPOSÉ dits dans le code :
l'attente après chaque commande, les registres rendus intacts, les interruptions laissées
ouvertes, la conversion d'un mois hors de 1 à 12, le quartet haut du jour de semaine.

## Faits mesurés → CARD avec carte et CARD_ERROR, le 2026-10-19

Suite de CARD sans carte (#1377). Relevé `measured/2026-10-19-card-avec-carte.tsv`, sous MAME
avec `-memc` : une partie d'aof jouée à la main pour la carte formatée par la référence, puis
des appels provoqués sans fenêtre (`bench/forcer.lua`), validés sur un chargement naturel.

| Élément | Décision |
|---|---|
| détection : REG_STATUS_B (`$380000`, octet haut) `$FF` sans carte → `$80`, `$8F` avec ; carte non formatée → `$81` après lecture des octets `$00` et `$20` de la carte | **gardé** : accès matériels et réponses relevés ; registre nommé dans « Memory mapped registers » |
| carte 8 bits : octet N de la carte à `$800000 + 2N` | **gardé** : relevé (écriture à `$80008E` = octet `$47`) |
| la structure d'une carte formatée : en-tête, CARD_MAGIC aux octets pairs, région, répertoire de 32 entrées, deux FAT, blocs de 64 octets | **gardé** : octets écrits sur la carte par la référence, et la page « Memory card » |
| somme d'une FAT = somme de ses octets | **gardé** : relevé trois fois |
| les effets des commandes `$00`-`$04`, `$06`, `$07` sur la carte, l'interface et les réponses ; le masque de `$01` dans le mot `$10FDD0` ; SUB à l'octet `$10FDD0` | **gardé** : relevé |
| les écritures de `$10FD04`-`$10FD16` pendant un appel | **gardé** : écritures en RAM BIOS ; noms et rôles dans la page « CARD » |
| `$05` répond `$82` aux cinq essais | **gardé** comme constat ; le sens de la commande reste à l'agent, d'après la page |
| CARD_ERROR (`$C0046E`) sur une sauvegarde refusée `$81` : test, formatage, puis la sauvegarde, en 3 trames, sans affichage | **gardé** : relevé |
| le test de la carte de la référence (motifs `$AA`/`$55`, carte entière réécrite au boot d'une carte vierge) | **écarté** : propre à la référence ; le formatage n'en dépend pas, la taille vient de CARD_SIZE ou de la page |
| la pile du BIOS (`$10F200-$10F2FF`), le bloc de données d'aof | **écarté** : adresses de la référence ; données du jeu, sans rôle dans le format |
| cartes 16 bits, sauvegardes sur plusieurs blocs, autres réponses de CARD_ERROR | **non tranché** : SUPPOSÉ à dire par l'agent, d'après la page |
| ajouté après le premier jugement : les registres de la carte écrits pendant l'appel (REG_CRDNORMAL, REG_CRDBANK, REG_CRDUNLOCK1/2, REG_CRDLOCK2/1) et leur ordre, par cas | **gardé** : accès matériels relevés ; la première image, qui ne posait pas REG_CRDNORMAL, ne lisait pas la carte |

L'instrument du critère : `bench/forcer.lua` sous SNK et sous notre image, mêmes appels, mêmes
cartes de départ ; mêmes réponses, mêmes écritures en RAM BIOS, mêmes octets de carte à la sortie
— hors ce que le test de la référence touche, à expliquer.

**Vérifié avant la remise** : aucune adresse d'instruction ni octet du BIOS de référence.

**Issue de cette remise.** Écrite par l'agent : `card.s` étendu, CARD_ERROR, et l'entrée
`$C0046E` dans `c0.s`. Quatre jugements par `bench/carte-diff.sh` avant l'égalité. Chacun a
apporté des faits que la remise ne portait pas, relevés sous la référence puis transmis à
l'agent, et consignés au point 4 du relevé :
- les registres de la carte : sans REG_CRDNORMAL, la carte ne se lit pas ;
- `$10FDD0` écrit par `$01` et `$03` ;
- une seule paire de déverrouillages pour `$00` et `$06` ;
- `$07` qui lit l'octet `$0F` ;
- le formatage, qui remplit la carte du motif avant d'écrire la structure ;
- la séquence de CARD_ERROR et son interface de sortie.

Résultat : 13 appels sur 13 égaux à la référence ; corpus 21/22. Choix SUPPOSÉ dits dans le code :
une seule géométrie (8 bits, 2 Kio), `$05` à `$82`, les valeurs des écritures que le relevé ne
donne pas, les autres cas de CARD_ERROR.

## Couche 3 → l'écran de boot, le 2026-10-20

Première tâche de la couche 3 : **aucun oracle**, SNK n'ayant jamais écrit cet écran. Rien n'est
tiré du BIOS de référence ; la remise se compose du relevé des glyphes, des pages publiques et
des choix de l'utilisateur. Le critère est visuel : une capture image par image sous MAME, plus le
corpus sans régression.

| Élément | Décision |
|---|---|
| les glyphes : police 8×16 (haut `$100`+ASCII, bas `$200`+ASCII), 8×8 (`$000`+ASCII), fond `$020`, palette 0 | **gardé** : `measured/2026-10-20-sfix-glyphes.tsv`, numéros de tuile écrits en VRAM |
| les minuscules, le point, les deux-points et les chiffres que le menu ne montre pas, à la même règle ASCII | **non tranché** : SUPPOSÉ, d'après la page « SFIX ROM » ; la capture d'acceptation tranche |
| les choix de l'utilisateur (2026-10-20) : le nom « ReBIOS », l'URL « sprixe.dev/rebios », environ 1 s, sautable par n'importe quel bouton ; trois temps — le titre qui se décode, des lignes qui affichent l'état réel de la machine, un fondu au noir | **gardé** : décision, `DECISIONS.md` §5 |
| aucune ligne qui affirme ce que le BIOS ne fait pas : pas de « RAM OK », le boot ne teste aucune RAM (`c0.s`) | **gardé** : règle de preuve |
| les sources des lignes : la date par `_read_calendar` (`cal.s`), la carte par REG_STATUS_B (`$FF` sans carte, `$8F` avec, relevé `2026-10-19-card-avec-carte.tsv`), le type de machine et la région par le descripteur `$C00400`/`$C00401`, le NGH dans l'en-tête de la cartouche (page « 68k program header ») | **gardé** : notre code, nos relevés, pages publiques |
| les pages « Fix layer », « Palettes », « VRAM », « Memory mapped registers », « Controllers » | **gardé** : l'agent les lit |
| le son | **écarté** : une option pour plus tard, il faudrait notre propre programme Z80 |
| les sprites | **écarté** : leurs tuiles sont dans la puce C de la cartouche, différente d'un jeu à l'autre |

**Vérifié avant la remise** : aucune adresse d'instruction ni octet du BIOS de référence.

**Issue de cette remise.** Écrite par l'agent : `ecran.s` (nouveau, 1 208 octets de code) et
l'appel dans `c0.s`, après BIOS_MESS_POINT et avant la poignée de main du son. Deux faits mesurés
sur nos propres captures, et non sur la référence, sont venus en cours de route : les minuscules
existent à leur place ASCII, et le trait des glyphes est l'index de couleur 1 (une même couleur
sur les entrées 1 à 15 faisait des blocs pleins). Consignés au relevé des glyphes, points 5 et 6.
Corpus 21/22. Choix SUPPOSÉ dits dans le code : la banque de palettes 0, la palette 0 sous la
tuile `$FF` hors MAME, l'affichage d'une région ou d'un jour hors table. Après la première
vidéo, l'utilisateur a demandé un écran plus long : 180 trames, rappel « PRESS A BUTTON TO SKIP »
qui clignote. Le saut est mesuré (START du banc à la trame 100, écran noir à la 103).

## Couche 3 → l'éditeur de soft-DIP, le 2026-10-20

Deuxième tâche de la couche 3, **sans oracle** comme la première : le menu de réglage de SNK n'est
pas lu, et rien n'en est tiré. La remise se compose de notre relevé des soft-DIP, de notre code,
des pages publiques et des choix retenus ci-dessous. Le critère : la valeur choisie à l'écran
arrive dans le bloc de sauvegarde du jeu et dans BIOS_GAME_DIP, relue au jig sous MAME, plus le
corpus sans régression.

| Élément | Décision |
|---|---|
| le décodage du bloc soft-DIP de la cartouche : $00-$0F le nom, $10-$15 deux temps en mot et deux comptes en octet, $16-$1F dix réglages, défaut dans le quartet haut et nombre de choix dans le bas | **gardé** : `measured/2026-10-16-soft-dip.tsv`, quatre jeux, et « Software DIPs » |
| la table des emplacements ($D00124) et le bloc de sauvegarde du jeu, $D00220 + 16 × index | **gardé** : notre code (`c0.s`, `_slot_inscrit` et `_slot_present`), mesuré au même relevé |
| les intitulés des réglages et de leurs choix, à la suite du bloc, 12 caractères chacun ; l'encodage des temps et des comptes, et la valeur qui les désactive | **gardé** : l'agent les lit dans « Software DIPs », et ce que la page ne tranche pas reste SUPPOSÉ dans le code |
| l'entrée dans l'éditeur : le bouton TEST de la carte, tenu à la fin de l'écran de boot | **gardé** : interprétation retenue sans supervision, la plus proche de l'existant — sur MVS, c'est par ce bouton qu'on entre dans les réglages. Le registre qui le porte est lu dans « Memory mapped registers » |
| l'emplacement : après la lecture de la table des emplacements, avant la remise de la main, backup RAM déverrouillée | **gardé** : c'est là seulement qu'on connaît le bloc du jeu |
| les glyphes 8×8 (`$000` + ASCII) et 8×16, palette dans l'entrée 1 | **gardé** : `measured/2026-10-20-sfix-glyphes.tsv`, points 1 à 6 |
| les manettes : REG_P1CNT, REG_STATUS_B | **gardé** : « Memory mapped registers », déjà lus par `ecran.s` |
| le menu de réglage du BIOS de référence, son aspect, ses textes | **écarté** : aucune lecture de la référence |
| la région à chaud, les autres réglages du BIOS, la sortie vers un menu | **écarté** : hors de ce lot |

**Vérifié avant la remise** : aucune adresse d'instruction ni octet du BIOS de référence. Les
octets de cartouche du relevé sont ceux qu'un jeu publie dans son propre en-tête.

**Issue de cette remise.** Écrits par l'agent : `dip.s` (nouveau, 1 658 octets avec les
chaînes), deux `jsr _editeur_dip` dans `c0.s`, et le jig `bench/editeur.lua`. Un débord, signalé
et gardé : à l'emplacement remis, le boot a déjà écrit REG_CRTFIX, et revenir à la police de la
carte bascule aussi la M1 du Z80 (« Memory mapped registers »). L'éditeur refait donc, sur son
seul chemin, la poignée de main de changement de slot de « 68k/Z80 communication » ; mesuré sur
aof, le pilote son revient dans la même boucle et reçoit la même suite de commandes. Le bouton
TEST est mesuré actif à l'état bas. Relevé : `measured/2026-10-20-editeur-soft-dip.tsv` ; corpus
21/22, colonne sprixe identique à celle de l'écran de boot.

## Couche 3 → la région à chaud et la sauvegarde des réglages du BIOS, le 2026-10-20

Troisième tâche de la couche 3. Choisir la région (Japon, USA, Europe) sans changer de puce, la
garder d'un boot à l'autre. Pas d'oracle pour l'écran ; un juge pour l'effet : sous MAME, notre
image réglée sur une région doit faire jouer le corpus comme le BIOS SNK **de cette région**
(`-bios japan`, `-bios us`, `-bios euro`), compté par `matrice.sh`, sans rien lire de ces BIOS.

| Élément | Décision |
|---|---|
| BIOS_COUNTRY_CODE ($10FD83) posé au boot depuis le descripteur $C00401 | **gardé** : notre code (`c0.s`), « BIOS RAM locations » |
| sous $00 avec l'image Europe, neomrdo noir, flipshot figé, kof98 noir | **gardé, à rejuger** : mesuré en #1365, mais contre la référence euro ; la matrice par région dira si c'est la région ou un écart de notre image |
| le pointeur du bloc soft-DIP suit la région ($116 + 4 × code) | **gardé** : `c0.s`, `dip.s`, « 68k program header » |
| la zone système de la backup RAM, $D00000-$D0007F, et ses cellules mesurées | **gardé** : `c0.s` (`_bram_vider`) ; le réglage du BIOS se loge hors des cellules connues, avec une signature qui fait retomber sur le descripteur si elle manque |
| l'écran : une ligne REGION en tête de l'éditeur ouvert par TEST (`dip.s`) ; un changement s'enregistre puis relance la machine | **gardé** : interprétation retenue sans supervision, la plus proche de l'existant — un seul écran de réglage, et une relance plutôt qu'un changement en vol, les jeux lisant la région à leur init |
| le mode MVS/AES à chaud | **écarté** : hors de ce lot |
| le menu, l'aspect et les textes du BIOS de référence | **écarté** : aucune lecture de la référence |

**Vérifié avant la remise** : aucune adresse d'instruction ni octet du BIOS de référence. Les
BIOS SNK des trois régions ne servent que de colonne de comparaison dans la matrice, sans lecture.

**Issue de cette remise.** Écrits par l'agent : `reglages.s` (nouveau), la ligne REGION de
`dip.s`, la lecture du réglage dans `c0.s`, `ecran.s` qui affiche la région en place,
`bench/bram-ecrivains.lua`, et `BIOS_REF` dans `matrice.sh`. L'emplacement $D00210-$D0021F est
mesuré libre sur le corpus. Un défaut trouvé en route et corrigé : la relance d'un premier boot
faisait sauter la demande 0 (kof98) ; l'entrée inscrite à ce boot est libérée. L'écart de #1365
sous $00 ne se reproduit plus : Japon et USA 21/22, comme leurs références SNK à 22/22 hors
garou. Relevés : `measured/2026-10-20-region-a-chaud.tsv`, `2026-10-20-matrice-par-region.tsv`.

## Couche 3 → l'écran de plantage, le 2026-10-21

Quatrième tâche de la couche 3, sans oracle. Quand le 68000 prend une exception qu'aucun code ne
traite (erreur de bus, d'adresse, instruction illégale, division par zéro…), afficher ce qui
s'est passé au lieu d'un écran figé, puis relancer la machine sur START. Critère : une exception
provoquée sous MAME (jig) donne l'écran avec les bonnes valeurs, et le corpus ne régresse pas.

| Élément | Décision |
|---|---|
| les créneaux de la zone d'entrée $C00402-$C00437 vers lesquels pointent les tables de vecteurs des cartouches | **gardé** : l'agent lit lesquels dans « 68k vector table » et « BIOS calls » ; aujourd'hui ils sont remplis de zéros (`c0.s`), et b2b y a déjà sauté (handoff de #1375) |
| la table de vecteurs du BIOS lui-même, vecteurs 2 à 31 sur `_piege` | **gardé** : `c0.s` ; ils peuvent mener au même écran |
| le cadre d'exception du 68000 (groupe 0 : mot d'état, adresse d'accès, instruction ; autres : SR et PC) | **gardé** : documentation publique du 68000, lue par l'agent |
| l'affichage : plan fixe, glyphes 8×8 et 8×16, palette dans l'entrée 1, synchro ligne $1F0, watchdog | **gardé** : `ecran.s`, `dip.s`, `measured/2026-10-20-sfix-glyphes.tsv` |
| le plan fixe lit peut-être la S ROM de la cartouche au moment de l'exception | **gardé, à traiter** : `dip.s` a mesuré que REG_BRDFIX bascule aussi la M1 du Z80 ; l'écran est terminal et finit par une relance, le son du jeu peut être coupé |
| la relance par le watchdog | **gardé** : `dip.s` / `reglages.s`, mesurée en #1383 |
| le gestionnaire d'exceptions de NeoPen, son aspect, ses textes | **écarté** : aucune lecture d'un BIOS tiers |

**Vérifié avant la remise** : aucune adresse d'instruction ni octet du BIOS de référence.

**Issue de cette remise.** Écrits par l'agent : `plantage.s` (nouveau, 2 156 octets), les huit
créneaux $C00408-$C00432 et les vecteurs 2-31 du BIOS dans `c0.s` (`_piege` remplacé par une
boucle identifiable, réservée à une exception dans le gestionnaire), le jig `bench/plantage.lua`.
Un fait mesuré contredit le modèle de la page : l'instruction illégale des 20 cartouches lues va à
$C00414, pas à $C0040E ; le gestionnaire traite les deux. garou sort de MAME pendant notre écran
de boot, sans exception 68000. Relevés : `measured/2026-10-21-ecran-plantage.tsv`,
`2026-10-21-vecteurs-cartouches.tsv`, `2026-10-21-matrice-ecran-plantage.tsv`.

## Couche 3 → les autotests, le 2026-10-21

Cinquième tâche de la couche 3, sans oracle : des tests du matériel ouverts depuis l'écran TEST.
Le critère : chaque test rend « OK » sous MAME sur une machine saine, et **chaque test de mémoire
sait échouer** — un défaut injecté par lua le fait passer au rouge —, plus le corpus sans
régression.

| Élément | Décision |
|---|---|
| l'écran TEST de `dip.s` (soft-DIP, REGION, RESET TO DEFAULTS) et ses commandes | **gardé** : notre code ; une ligne de plus y ouvre les tests, START en revient |
| la carte mémoire : RAM de travail, RAM de palettes, VRAM et ses registres, backup RAM | **gardé** : « Memory map », « VRAM », « Palettes », « Memory mapped registers », lus par l'agent |
| les tests destructifs : la RAM de travail et la VRAM se vident au boot de toute façon ; la backup RAM porte les données des jeux et nos réglages | **gardé** : RAM de travail hors de la zone du BIOS en cours d'usage, palettes, VRAM testées ; backup RAM en lecture seule ou non destructive, l'agent dit laquelle |
| les manettes, START/SELECT, pièces, TEST : `io.s`, `ecran.s`, `dip.s` | **gardé** : notre code et « Memory mapped registers » |
| les mires (barres de couleur, quadrillage) sur le plan fixe | **gardé** : glyphes mesurés, `measured/2026-10-20-sfix-glyphes.tsv` ; une tuile pleine n'est pas mesurée, l'agent la mesure ou s'en passe |
| le test du son | **écarté** : il faudrait notre propre programme Z80 (`DECISIONS.md` §0) |
| les tests du BIOS de référence et de neogeo-bios, leur aspect, leurs textes | **écarté** : aucune lecture |

**Vérifié avant la remise** : aucune adresse d'instruction ni octet du BIOS de référence.

**Issue de cette remise.** Écrits par l'agent : `tests.s` (nouveau, 3 180 octets), la ligne
HARDWARE TESTS de `dip.s`, le jig `bench/autotests.lua`. Deux écarts à la remise, gardés : la
backup RAM n'est pas reverrouillée en sortie de test (l'éditeur écrit encore le bloc du jeu après,
et `c0.s` verrouille au retour), et $8600-$86FF n'est pas testée (« VRAM » : réécrite par le LSPC
en affichage). Un fait mesuré : sous $700, trois index de tuile pleine seulement dans le SFIX
(`measured/2026-10-21-sfix-tuiles-pleines.tsv`), d'où des barres en deux pages. Relevés :
`2026-10-21-autotests.tsv`, `2026-10-21-matrice-autotests.tsv`.

## Couche 3 → le menu en jeu, le 2026-10-21

Sixième tâche de la couche 3, sans oracle : un menu qu'on ouvre **pendant la partie**, qui met le
jeu en pause, puis le rend tel qu'il était. C'est la première fonction de la couche 3 qui
s'exécute pendant que le jeu a la main ; son premier devoir est de ne rien casser. Critère : sous
MAME, menu ouvert puis refermé en cours de partie, le jeu reprend avec un plan fixe, des palettes
et une RAM identiques à l'octet à ceux d'avant l'ouverture ; corpus sans régression.

| Élément | Décision |
|---|---|
| le crochet : SYSTEM_IO ($C0044A), que les jeux appellent à chaque trame (`io.s`, protocole mesuré) | **gardé** : notre code ; le menu s'ouvre de là, dans l'appel du jeu |
| le geste : START P1 + SELECT P1 tenus | **gardé** : interprétation retenue sans supervision. START + pièce ouvre le menu d'UniBIOS (`BENCH.md`, piège 6) mais une pièce crédite chez nous ; SELECT ne crédite rien. L'agent vérifie que SELECT P1 existe sous MAME et qu'aucun jeu du corpus ne le lit en partie |
| ce que le menu touche et doit rendre : le plan fixe (VRAM $7000-$74FF), REG_VRAMMOD et l'adresse VRAM, les palettes qu'il emploie, la banque de palettes, REG_CRTFIX/BRDFIX et le Z80 | **gardé** : sauvegarde et restauration ; où sauvegarder se mesure (une zone que ni le jeu ni le BIOS n'écrit), dans la RAM BIOS ou ailleurs |
| le contenu : RESUME, RESTART GAME (relance par le watchdog, #1383) | **gardé** : le plus restreint ; les cheats viendront s'y ajouter |
| les IRQ du jeu pendant la pause | **gardé** : masquées le temps du menu, rendues à la sortie ; watchdog servi |
| le menu en jeu d'UniBIOS et de NeoPen, leur aspect, leurs textes | **écarté** : aucune lecture d'un BIOS tiers |

**Vérifié avant la remise** : aucune adresse d'instruction ni octet du BIOS de référence.

**Issue de cette remise.** Écrits par l'agent : `menu.s` (nouveau, section `.haut`), le crochet
dans `io.s`, le jig `bench/menu.lua`. **Le geste a changé en cours de lot** : START + SELECT P1
est inaccessible sur MVS (pas de SELECT sous MAME pour ces sets, cinq jeux lisent $380000 en
partie) ; TEST tenu le remplace, que seul ridhero lit en partie. Choix sur le Z80, faute de sortie
documentée sans reset : le pilote son est relancé à la reprise. Un défaut latent de `io.s` révélé
et corrigé (%d0 non étendu avant PLAYER_START, flipshot). Relevés : `measured/2026-10-21-menu-en-jeu.tsv`,
`2026-10-21-test-tenu-en-partie.tsv`, `2026-10-21-ecrivains-ram-bios.tsv`,
`2026-10-21-appels-system-io-ipl.tsv`, `2026-10-21-matrice-menu-en-jeu.tsv`.

## Couche 3 → les cheats, le 2026-10-21

Septième tâche de la couche 3. `DECISIONS.md` §0 borne la fonction : le moteur tient en quelques
centaines d'octets, la table par jeu est sans fin, la cible s'énonce « N jeux ». Ce lot pose le
moteur, le format de la table et une première table **mesurée ici**. Critère : sous MAME, un
cheat activé dans le menu en jeu produit son effet en partie (relevé par lua), et désactivé, le
jeu se comporte comme le témoin ; corpus sans régression.

| Élément | Décision |
|---|---|
| le moteur : à chaque SYSTEM_IO, écrire en RAM de travail les valeurs des cheats actifs | **gardé** : notre crochet (`io.s`, `menu.s`) ; une écriture par trame, rien d'autre |
| l'activation : des lignes dans le menu en jeu (`menu.s`), un état par cheat | **gardé** : notre code ; les états vivent en RAM BIOS, perdus à la relance |
| l'identification du jeu : le NGH de l'en-tête ($000108), plus une somme de contrôle de quelques mots de la P-ROM pour écarter les révisions | **gardé** : « 68k program header » ; la somme est calculée par le BIOS, rien n'est recopié |
| les cheats eux-mêmes : adresses et valeurs **trouvées par mesure** sous MAME (recherche en RAM par lua sur des parties instrumentées : vies, temps, crédits du jeu) | **gardé** : relevé versionné, adresses et valeurs seulement |
| les tables de cheats existantes (celles d'UniBIOS, le cheat.xml de MAME et ses dérivés) | **écarté** : ni lues ni reprises, leur licence n'est pas la nôtre et la salle blanche s'y applique |

**Vérifié avant la remise** : aucune adresse d'instruction ni octet du BIOS de référence ; aucune
table de cheats tierce.

**Issue de cette remise.** Écrits par l'agent : `cheats.s` (nouveau : table, moteur), les lignes
de cheats et le cadre agrandi de `menu.s` (sauvegarde déplacée en $10F4C0-$10F7EB, mesurée libre),
le jig `bench/cheats.lua`. Sept cheats sur mslug, aof et kof94, chacun trouvé par filtrage de la
RAM puis prouvé en forçant la cellule, contre un témoin ; aucune base tierce lue. Un écart : la
table est cherchée à l'ouverture du menu et non au boot. Un défaut hors lot révélé : le refus des
pointeurs soft-DIP au-delà de $0FFFE0 laisse mslug à 0 vie. Relevés : `measured/2026-10-21-cheats-*.tsv`,
`2026-10-21-cases-curieuses.tsv`, `2026-10-21-empreintes-corpus.tsv`, `2026-10-21-matrice-cheats.tsv`.

## Couche 1 → les soft-DIP hors de la P-ROM fixe, le 2026-10-21

Correction d'un défaut de la couche 1, trouvé pendant les cheats : le bloc soft-DIP de mslug est à
$2783D0, dans la zone banquée de la P-ROM ($200000-$2FFFFF), et `c0.s` refuse tout pointeur
au-delà de $0FFFE0. BIOS_GAME_DIP reste à zéro, la partie part à 0 vie. La couche 1 a un oracle :
le juge est la référence, mesurée sous MAME.

| Élément | Décision |
|---|---|
| BIOS_GAME_DIP ($10FD84-$10FD93) relevé sous la référence à la remise, jeu par jeu, sur les 22 jeux du corpus, contre le nôtre | **gardé** : valeurs de RAM écrites par la référence (`DECISIONS.md` §8), comme `measured/2026-10-16-soft-dip.tsv` |
| le décodage du bloc et la table des emplacements | **gardé** : `c0.s`, `measured/2026-10-16-soft-dip.tsv` |
| la zone banquée : registre de banque et banque en place au boot | **gardé** : « Memory map » et « P-ROM bank switching » du wiki, lus par l'agent ; ce que la page ne tranche pas se mesure ou reste SUPPOSÉ |
| le refus d'un pointeur nul ou hors de la cartouche | **gardé** : un pointeur en dehors de $000000-$2FFFFF reste refusé |
| le code du BIOS de référence | **écarté** : aucune lecture |

**Vérifié avant la remise** : aucune adresse d'instruction ni octet du BIOS de référence.

**Issue de cette remise.** Écrits par l'agent : les bornes du pointeur soft-DIP dans `c0.s` et
`dip.s` (zone fixe ou zone banquée, bloc entier dans sa zone), le jig `bench/softdip.lua`. Mesuré
contre la référence avant de corriger : 21/22 égaux, mslug seul en écart ; après, 22/22, et mslug
part avec ses 3 vies trame pour trame comme sous la référence. Relevé :
`measured/2026-10-21-soft-dip-zone-banquee.tsv`.

## Couche 3 → le jukebox, le 2026-10-21

Huitième tâche de la couche 3, sans oracle : écouter les sons du jeu inséré hors partie, depuis
l'écran TEST. Le BIOS n'a pas de programme Z80 à lui : il envoie des codes au pilote son de la
cartouche. Ce pilote ne tourne que sous REG_CRTFIX, qui donne aussi au plan fixe la S ROM de la
cartouche : le texte s'écrit donc avec la police du jeu. Critère : sous MAME, chaque code envoyé
fait réagir la puce son (écritures du Z80 au YM2610), l'écran est lisible avec la police de la
cartouche, et le retour à l'écran TEST puis au jeu se fait sans régression.

| Élément | Décision |
|---|---|
| la police de la cartouche aux places du SFIX : 21 jeux sur 22, kof2003 sans rien | **gardé** : `measured/2026-10-21-police-cartouche.tsv` |
| le protocole des codes son ($01 changement de slot, $03 reset, les autres au pilote du jeu) | **gardé** : « 68k/Z80 communication », lu par l'agent ; notre poignée de main (`c0.s`, `dip.s`, `menu.s`) |
| l'entrée : une ligne JUKEBOX dans l'écran TEST (`dip.s`) ; la sortie revient à cet écran | **gardé** : interprétation retenue sans supervision, hors partie seulement (`DECISIONS.md` §0) |
| les commandes : un numéro de 0 à 255 qu'on fait défiler, A l'envoie, un geste pour couper le son | **gardé** : interprétation ; les codes réservés au protocole ne s'envoient pas comme des sons |
| une liste des numéros « utiles » par jeu | **écarté** : elle se mesurerait jeu par jeu, comme les cheats ; ce lot affiche tous les numéros |
| le jukebox d'UniBIOS, son aspect, ses textes | **écarté** : aucune lecture d'un BIOS tiers |

**Vérifié avant la remise** : aucune adresse d'instruction ni octet du BIOS de référence.

**Issue de cette remise.** Écrits par l'agent : `jukebox.s` (nouveau, section `.haut`), la ligne
JUKEBOX de `dip.s`, le jig `bench/jukebox.lua`. Le jig compte les déclenchements de la puce son,
pas les écritures brutes. Un fait mesuré a décidé de l'aide : trois des quatre pilotes mesurés
attendent $07 après leur relance, le quatrième (mslug) s'éteint dessus ; pas de $07 automatique,
une ligne « PLAY 07 FIRST IF SILENT ». Relevés : `measured/2026-10-21-jukebox.tsv`,
`2026-10-21-matrice-jukebox.tsv`.

## Couche 1 → le multi-slot, mesure d'abord, le 2026-10-21

Notre BIOS sert toujours le slot 0 (`c0.s`, `clr.b 0xD00108`). Sur une carte à plusieurs slots
(MV-2F, MV-4F, MV-6F), la référence fait davantage : elle sait quels slots portent une cartouche,
fait tourner les démos, et laisse choisir le jeu. La machine `neogeo` de MAME est une MV-6F à six
emplacements (`-cart1` … `-cart6`) : la référence s'y observe avec plusieurs cartouches. Ce lot
**mesure seulement** ; l'écriture viendra au lot suivant, jugée contre cette mesure.

| Élément | Décision |
|---|---|
| ce que la référence écrit et lit pendant le boot et l'attente avec 1, 2 puis 4 cartouches : REG_SLOT, la RAM BIOS et la backup RAM liées aux slots ($D00108, la table $D00124, $10FDxx), les remises de main (USER, demande, mode) | **gardé** : écritures et lectures de registres et de RAM, comptes et valeurs (`DECISIONS.md` §8), relevés par lua comme les jigs existants |
| les pages « Memory mapped registers » (REG_SLOT), « Backup RAM », « BIOS RAM locations », « 68k/Z80 communication » (changement de slot) | **gardé** : lues par l'agent |
| le comportement visible : quel jeu tourne en démo, combien de temps, le geste qui choisit un jeu | **gardé** : captures et relevés de trames |
| le code du BIOS de référence, ses adresses d'instruction | **écarté** : aucune lecture, aucun PC versionné |

**Vérifié avant la remise** : aucune adresse d'instruction ni octet du BIOS de référence.

**Issue de cette remise.** Mesure seule : `bench/multislot.lua` et le relevé, versionné en extrait
(`measured/2026-10-21-multi-slot.tsv` : en-tête, synthèse, événements et registres du multi-slot ;
le relevé complet, 67 455 lignes, reste hors dépôt). Garde §8 appliquée : les octets de
$D00020-$D00022 et quelques-uns en $D001C0/$D0035B, qui pourraient former une adresse de la ROM de
référence, sont masqués (« retenu »). Un piège du jig : un changement de slot fait réinstaller par
MAME les gestionnaires de la P-ROM, ce qui efface les taps posés dessus ; le jig les repose.

## Couche 1 → le multi-slot, lot 1 : détection et table, le 2026-10-21

Premier des quatre lots d'écriture du multi-slot. Juge : `bench/multislot.lua` sur notre image,
comparé au relevé de la référence `measured/2026-10-21-multi-slot.tsv` (runs c2-neuf, c4-neuf,
c4-suite, le slot vide), et la matrice à une cartouche sans régression.

| Élément | Décision |
|---|---|
| la détection : $D00047 ← nombre de slots de la carte (d'après REG_SYSTYPE), boucle $D00108 / REG_SLOT sur les slots, en-tête lu, slot vide sauté | **gardé** : mesuré, relevé du 2026-10-21 ; ce que REG_SYSTYPE dit du nombre de slots se lit dans « Memory mapped registers » |
| la table $D00124 indexée par slot physique (huit entrées), index de bloc au plus petit libre dans l'ordre des slots | **gardé** : mesuré, même relevé ; remplace la recherche du NGH de `c0.s` |
| ce lot sert toujours le premier slot occupé après la détection ; la demande 0 par slot, la rotation et la sélection viennent aux lots 2 à 4 | **gardé** : découpage de `docs/tasks.md` |
| la signature d'une cartouche présente (ce qui distingue un slot vide) | **gardé** : mesuré (lectures de la référence à $000100 sur slot vide et occupé) ; le critère exact reste à l'agent, SUPPOSÉ dit |
| le code et les adresses d'instruction de la référence | **écarté** : aucune lecture |

**Vérifié avant la remise** : aucune adresse d'instruction ni octet du BIOS de référence.

**Issue de cette remise.** Écrit par l'agent : la détection et la table dans `c0.s` (+212 octets),
l'option `MS_SONDE_M1` de `bench/multislot.lua` (quelle M1 voit le Z80). Le critère de slot occupé :
« NEO-GEO » en $100-$106, et un NGH pas déjà vu à un slot précédent (mesuré sur la référence :
`ng_mv1` rend au slot 1 l'en-tête du slot 0, et le même jeu monté deux fois donne $0000/$FFFF). La
poignée de main du son n'a pas bougé : notre boucle tourne sous REG_BRDFIX, le Z80 reste sur la SM1
de la carte (sonde M1). Relevés : `measured/2026-10-22-multi-slot-lot1.tsv`,
`2026-10-22-soft-dip-multi-slot-lot1.tsv` (GAME_DIP égal à la référence, 22/22).

## Toutes couches → le durcissement matériel, le 2026-10-22

Un audit en lecture seule (quatre agents, 2026-10-21) a relevé ce qui marche sous MAME et risque de
casser sur une vraie carte, et des copies de code qui ont divergé. Aucun défaut critique établi. Ce
lot corrige ceux qui se corrigent sans mesure nouvelle sur matériel, avant le premier essai
(`docs/ESSAI-MATERIEL.md`). Juge : aucune régression sous MAME (corpus, jigs de la couche 3, table
du multi-slot), chaque correction dite dans le code avec sa source.

| Élément | Décision |
|---|---|
| les bits SELECT de REG_STATUS_B lus au repos à 1 par l'écran de boot et par RESUME du menu, alors qu'« BIOS RAM locations » dit qu'ils se lisent toujours 0 sur MVS et que `io.s` les masque déjà | **gardé** : ne pas les compter sur MVS ($10FD82), comme `io.s` |
| toutes les attentes de trame exigent la ligne $1F0 exacte, sans borne (six copies de `.Lsync`, la remise de `c0.s`) | **gardé** : une borne de temps qui laisse passer si la ligne n'est jamais vue, le watchdog servi |
| la palette 0 jamais posée par l'écran de boot ni l'éditeur, alors que FIX_CLEAR met la tuile $020 (pleine de l'index 2, mesuré) sous elle | **gardé** : la poser à noir, comme `plantage.s` |
| la poignée de main $01 : `c0.s`, `dip.s`, `plantage.s` lisent l'écho dans la boucle même ; `menu.s`, `jukebox.s` attendent une trame | **gardé** : aligner sur la forme qui attend une trame |
| REG_NOSHADOW, le timer et REG_LSPCMODE, les compteurs de pièces, les verrous de carte jamais posés au boot | **gardé** : les poser au boot aux valeurs que la référence écrit au boot (valeurs écrites, admises par §8, relevées au banc ou sous MAME) ; ce qui n'est pas mesurable reste SUPPOSÉ |
| `plantage.s` écrit sa sauvegarde avant de lire le cadre d'exception (nam1975 écrit $10F300-$10F4B3) | **gardé** : lire le cadre d'abord |
| le moteur de cheats écrit d'après CH_ENTREE sans le valider | **gardé** : n'écrire que si CH_ENTREE pointe dans la table de la ROM |
| `video.s` affirme qu'INT1 n'écrit aucun registre VRAM (faux depuis MESS_OUT), `plantage.s:58-60` (zone dite libre), le compte de pile de `tests.s` | **gardé** : commentaires corrigés |
| la relecture VRAM après une écriture de donnée (`menu.s`, `tests.s`), le reset du Z80 par le watchdog, l'initialisation du µPD4990A | **écarté** de ce lot : à mesurer (banc LSPC, matériel) |

**Vérifié avant la remise** : aucune adresse d'instruction ni octet du BIOS de référence.

**Issue de cette remise.** Écrites par l'agent : les huit corrections, dans `c0.s`, `ecran.s`,
`dip.s`, `tests.s`, `menu.s`, `plantage.s`, `jukebox.s`, `cheats.s`, `video.s`, et `bench/autotests.lua`
réparé (ses trois « haut » tombaient sur JUKEBOX depuis #1391). Les valeurs posées au boot viennent
d'une mesure de la référence (`measured/2026-10-22-registres-au-boot.tsv`) ; REG_RESETCC, que la
référence ne pose pas, n'est pas posé. Corpus : verdicts égaux ; jigs de la couche 3 égaux à leurs
relevés ; table du multi-slot inchangée. État de chaque constat : `docs/AUDIT-2026-10-21.md`.

## Couche 1 → les départs refusés, le 2026-10-22

Le catalogue rejoué la nuit du 2026-10-21 (`measured/2026-10-22-matrice-catalogue.tsv`) a montré,
captures à l'appui, des jeux comptés « joue » qui ne démarrent pas de partie, et aodk qui plante en
jeu. Un diagnostic (mesure seule, sous la référence et sous notre image, même plan d'entrées) a
établi cinq causes dans notre BIOS, chacune prouvée en forçant sous notre image la valeur de la
référence. La couche 1 a un oracle : la référence fait foi.

| Élément | Décision |
|---|---|
| CREDIT_CHECK : la demande de P2 comparée à $D00035 chez nous, à $D00034 (le crédit commun) chez la référence (cyberlip, ncommand) | **gardé** : comparer à $D00034, comme la demande de P1 ; la règle exacte au titre (1 crédit) reste à mesurer |
| une pièce au titre (mode 1, demande 3) relance chez nous la remise USER ; la référence crédite seulement (trally) | **gardé** : pas de remise si la demande vaut déjà 3 ; crédit et COIN_SOUND seulement |
| au START avec crédit, la référence met BIOS_COMPULSION_TIMER à zéro ($10FDDA/$10FDDB), pas nous (sbp) | **gardé** |
| la remise sur pièce ne coupe pas le timer du LSPC ; la référence écrit REG_LSPCMODE ← $4000 et IRQACK ← 7 (aodk) | **gardé** : le même préambule que `_retour_systeme` |
| à la remise USER, nos registres de données sont des restes ; la référence entre en $000122 avec D0-D6 = 0 (sauf D1 = $80) et D7 = $FFFF (garou : D6 = 0 le débloque) | **gardé** : poser ces valeurs avant le saut, mesurées |
| le minuteur de répétition des manettes ($10FD99/$10FD9F), qui tourne en continu chez la référence (alpham2) | **écarté** de ce lot : mesuré, mais son effet n'est pas prouvé |
| dragonsh : son outil de debug et son plantage | **écarté** : pas une cause BIOS (la référence, au même timing relatif, fait de même) |

**Vérifié avant la remise** : aucune adresse d'instruction ni octet du BIOS de référence ; les
valeurs de registres et de RAM sont des valeurs écrites ou présentées par la référence (§8).

**Issue de cette remise.** Écrites par l'agent : les cinq corrections dans `io.s` et `c0.s`. Un
écart à la remise, mesuré : le minuteur de départ forcé n'est remis à zéro qu'après PLAYER_START et
seulement si le jeu garde le bit (la référence ne le fait pas sur un START en jeu). Corpus 22/22,
jigs du harnais PASS ; seule la matrice de trally change, en mieux. Relevés :
`measured/2026-10-22-departs-refuses.tsv`, `2026-10-22-matrice-departs.tsv` (nouvelle référence du
harnais), `2026-10-22-matrice-departs-jeux.tsv`.

## Couche 1 → le départ du joueur 2, le 2026-10-22

Une relecture (#1399) a relevé que `_io_start` teste encore le crédit de P2 ($D00035) pour poser le
bit P2 de BIOS_START_FLAG, alors que CREDIT_CHECK compare désormais la demande de P2 au crédit commun
($D00034), comme la référence. Le banc n'appuie que sur START P1 : le départ de P2 n'a jamais été
mesuré. Mesurer d'abord, sous la référence, puis corriger.

| Élément | Décision |
|---|---|
| ce que la référence fait d'un START P2 : crédit lu ($D00034 ou $D00035), bit posé dans $10FDB4, déduction, PLAYER_START, en mode titre et en partie (P2 qui rejoint) | **gardé** : mesuré par jig, valeurs de RAM écrites par la référence (§8) |
| `_io_start` (`io.s`) aligné sur la mesure | **gardé** |
| le code de la référence | **écarté** : aucune lecture |

**Vérifié avant la remise** : aucune adresse d'instruction ni octet du BIOS de référence.

**Issue de cette remise.** Mesuré d'abord : la référence ne faisait pas comme nous (crédit commun,
pièce 2 comprise ; double écriture de BIOS_START_FLAG ; deux crédits pour P2 au titre). Écrit par
l'agent dans `io.s` (`_io_start`, la déduction, `_io_crediter`). Égalité avec la référence sur les 18
cas × jeux ; harnais complet PASS (le banc n'appuie que sur START P1 : l'étage 2 ne bouge pas).
Relevés : `measured/2026-10-22-depart-p2*.tsv`. Hors lot, vus en passant : `_sysret_fin_partie`
teste encore le mot $D00034/$D00035 (sans effet) ; à la pièce qui fait passer au titre, la référence
met $10FDB6-$10FDB9 à zéro, pas nous.

## Couche 1 → le multi-slot, lot 2 : le premier boot par slot, le 2026-10-22

Deuxième lot du multi-slot (lot 1 : #1395). Mesuré (`measured/2026-10-21-multi-slot.tsv`, runs c4-neuf
et c4-suite) : au premier boot, la référence donne une demande 0 à chaque slot nouveau, l'un après
l'autre, avec le passage son et slot complet entre deux, et inscrit à chacun un bloc de sauvegarde
au plus petit libre ; au boot suivant, la table est réécrite à l'identique et aucune demande 0.

| Élément | Décision |
|---|---|
| la séquence des remises du premier boot (trames 281, 283, 286, 289 sur c4-neuf), le passage par slot ($01, écho, REG_SLOT, REG_CRTFIX, REG_SWPROM, $03), le retour au BIOS entre deux (SYSTEM_RETURN après la demande 0) | **gardé** : mesuré, même relevé ; le juge est `bench/multislot.lua` sur notre image, table et remises comparées à c4-neuf et c4-suite |
| le nom du jeu inscrit à $D002A0+, la date $D00104/$D00144+, $D0011A+k, $D00058 | **gardé si mesurable** au même relevé, sinon SUPPOSÉ dit ; ce que le jeu lit de ces cellules décide de la priorité |
| la rotation de la démo et la sélection | **écarté** : lots 3 et 4 |
| les états des cheats au changement de jeu (audit : CH_ETATS survit sans reset) | **gardé** : remis à zéro à chaque passage de slot |
| le code de la référence | **écarté** : aucune lecture |

**Vérifié avant la remise** : aucune adresse d'instruction ni octet du BIOS de référence.

**Issue de cette remise.** Écrits par l'agent : `_passer_au_slot`, `_inscrire_slot`, `_relire_dip`,
`_premier_nouveau` et le code 0 de SYSTEM_RETURN dans `c0.s` (+266 octets), `_cheats_oublier` dans
`cheats.s`, l'option `MS_LECT_JEU` du jig. La séquence de la référence a été mesurée d'abord (jig,
valeurs seulement). Un écart voulu, dit : GAME_DIP recopié dans le bloc avant la demande 0 (la
référence le fait au retour), pour l'éditeur de soft-DIP ; les blocs restent égaux. Relevés :
`measured/2026-10-22-multi-slot-lot2.tsv`, `2026-10-22-bram-lue-par-les-jeux.tsv`.

## Couche 1 → le multi-slot, lot 3 : la rotation de la démo, le 2026-10-22

Troisième lot du multi-slot. Mesuré (`measured/2026-10-21-multi-slot.tsv`) : la référence ne change
de slot que quand le jeu lui rend la main en fin de démo (SYSTEM_RETURN code 2) ; le passage prend
trois trames : (1) en-tête $00010E-$000112 du jeu sortant lu et écritures en backup RAM hors table
(sa sauvegarde, SUPPOSÉ au relevé), (2) le passage son et slot, (3) la remise en demande 2 au slot
occupé suivant ; les slots vides sont sautés ; retour au slot 0 avec le logo.

| Élément | Décision |
|---|---|
| le passage au slot occupé suivant sur SYSTEM_RETURN code 2, demande 2 mode 1, slots vides sautés, bouclage | **gardé** : mesuré ; `_passer_au_slot` du lot 2 |
| la sauvegarde du jeu sortant (pointeur et taille lus en $00010E/$000112 de son en-tête, recopie en backup RAM) et sa restauration au retour | **gardé** : mesurer d'abord son contenu chez la référence (où, combien, quand), puis l'écrire ; la page « 68k program header » nomme ces champs |
| le logo SNK au retour sur le slot 0 | **écarté** : pas le nôtre ; au plus notre propre écran, et seulement si l'utilisateur le demande |
| les cheats au passage | **gardé** : déjà oubliés par `_passer_au_slot` (lot 2) ; à constater ici |
| la sélection par SELECT | **écarté** : lot 4 |

**Vérifié avant la remise** : aucune adresse d'instruction ni octet du BIOS de référence.

**Issue de cette remise.** Mesuré d'abord (`MS_PLAGES` du jig, 8 runs de 12 000 à 32 000 trames) :
la sauvegarde et la restauration du jeu, et BIOS_SYSRET_STATUS ← $02 avant chaque demande 2 (sans
quoi la fin de démo restait au code 0 chez nous). Écrits par l'agent dans `c0.s` (+308 octets) :
`_slots_occupes`, `_slot_suivant`, `_bloc_jeu`, `_sauver_jeu`, `_restaurer_jeu`, le code 2 en
rotation, la sauvegarde au code 0 et la restauration au boot à partir de deux slots. Écart voulu
dit : une cartouche seule ne sauve ni ne restaure, à reprendre au lot suivant. Relevés :
`measured/2026-10-22-multi-slot-lot3*.tsv`, `2026-10-22-cheats-au-passage.tsv`.

## Couche 1 → la sauvegarde du jeu avec une cartouche seule, le 2026-10-22

Le lot 3 du multi-slot (#1403) a mesuré que la référence sauve la zone de données du jeu (pointeur
$00010E, taille $000112 de l'en-tête) en $D00320 + $1000 × bloc à chaque SYSTEM_RETURN qui quitte le
jeu, et la restaure avant chaque demande 2 — **y compris avec une cartouche seule**, et au boot
suivant. C'est ce qui garde les hiscores et l'état du jeu d'une mise sous tension à l'autre. Notre
image ne le fait qu'à partir de deux slots occupés.

| Élément | Décision |
|---|---|
| la sauvegarde et la restauration du jeu seul, aux moments mesurés chez la référence (fin de démo, fin de partie, boot avec NVRAM gardée) | **gardé** : les routines du lot 3 (`_sauver_jeu`, `_restaurer_jeu`) ; mesurer d'abord les moments exacts sur une cartouche seule |
| le premier boot (NVRAM neuve) : rien à restaurer avant la première sauvegarde | **gardé** : ne restaurer qu'un bloc déjà sauvé (la référence le fait-elle sur bloc vierge ? mesurer) |
| le code de la référence | **écarté** : aucune lecture |

**Vérifié avant la remise** : aucune adresse d'instruction ni octet du BIOS de référence.

**Issue de cette remise** : sauvegarde à la fin de partie (code 3) et, sans passage de slot, aux codes
0 et 2, suivie de la restauration du même bloc ; restauration au boot une cartouche seule comprise
(`_slots_occupes` retiré). Mesuré d'abord sur la référence : le bloc n'est restauré qu'après une
sauvegarde, la question du bloc vierge ne se pose donc pas. Écart voulu dit : la seconde
restauration de la référence, après son logo, n'est pas reproduite (nous n'avons pas de logo).
Relevés : `measured/2026-10-22-sauvegarde-jeu-seul*.tsv`.

## Couche 1 → multi-slot, lot 4 : la sélection, le 2026-10-22

Dernier des quatre lots de `docs/tasks.md` (§ multi-slot). Lu dans « BIOS RAM locations » (wiki) :
les codes 4 et 5 de BIOS_SYSRET_STATUS ($10FD81) sont le changement de slot demandé par le joueur.
Mesuré le 2026-10-21 sur la référence (`measured/2026-10-21-multi-slot.tsv`) : SELECT P1 / P2 (bits
9 et 11 du mot de REG_STATUS_B), un crédit présent, sur l'écran titre ; codes 4 et 5, puis demande 3
sur le nouveau slot. Notre image ignore SELECT sur MVS depuis l'audit du 2026-10-21.

| Élément | Décision |
|---|---|
| les moments, le sens (P1 en avant, P2 en arrière ?), la condition de crédit, ce qui est sauvé et restauré, la remise sur le nouveau slot | **gardé** : à mesurer d'abord sur la référence au jig `bench/multislot.lua`, puis égaler |
| les routines des lots 1 à 3 (`_slot_suivant`, `_sysret_passer`, `_sauver_jeu`, `_restaurer_jeu`) | **gardé** : les réutiliser |
| SELECT en cartouche seule, sur MVS mono-slot, et l'AES | **gardé** : ne rien changer à ce qui est mesuré aujourd'hui (non-régression) |
| le code de la référence | **écarté** : aucune lecture |

**Vérifié avant la remise** : aucune adresse d'instruction ni octet du BIOS de référence.

**Issue de cette remise** : `_io_select` (`io.s`) prend SELECT au front, au titre, avec un crédit et un
autre slot occupé, et écrit le code 4 ou 5 ; `_retour_selection` (`c0.s`) sauve, change de slot
(`_changer_de_slot`, extrait de `_sysret_passer`), restaure et remet en demande 3 ; `_slot_suivant`
généralisé par un pas (`_slot_voisin`, `_slot_precedent`). Écart à la remise : la mesure montre que la
référence ne l'ignore pas avec une cartouche seule ; nous gardons SELECT ignoré dans ce cas, comme
avant le lot. Relevés : `measured/2026-10-22-multi-slot-lot4*.tsv`.

## Couche 1 → trois écarts vus au lot 4 du multi-slot, le 2026-10-22

Relevés en passant par le lot 4 (`measured/2026-10-22-multi-slot-lot4.tsv`), chacun touche aussi une
cartouche seule :

| Élément | Décision |
|---|---|
| FRAME_SKIP ($10FEE1) atteint $00 deux trames plus tard que chez la référence après une remise ; START, la pièce et SELECT attendent d'autant | **gardé** : mesurer, trame par trame, quand la référence l'écrit et à quelle valeur après chaque type de remise, puis égaler |
| au boot avec la NVRAM gardée, la référence remet le crédit $D00034 à zéro ; notre image le garde | **gardé** : mesurer sur quelles conditions (MVS, NVRAM gardée, réglage de crédits), puis égaler |
| à deux pièces par crédit, une pièce qui ne fait pas encore de crédit mène chez nous au titre, pas chez la référence | **gardé** : mesurer ce que la référence fait de cette pièce (compteur partiel, demande 3 ou non), puis égaler |
| le code de la référence | **écarté** : aucune lecture |

**Vérifié avant la remise** : aucune adresse d'instruction ni octet du BIOS de référence.

**Issue de cette remise** : les trois écarts étaient réels et sont égalés sur les cas mesurés.
`_remettre_a_user` (`c0.s`) pose FRAME_SKIP à $09 aux demandes 2 et 3 ; `_bram_valide` remet
$D00020-$D00039 à zéro au boot ; `_io_crediter`, `_io_commun` et `_io_compulsion` (`io.s`) arment le
départ forcé à toute pièce, ne rendent le titre qu'à un crédit fait, et ne décomptent qu'au titre —
ce dernier point SUPPOSÉ (le relevé ne sépare pas la démo de l'absence de crédit). Relevés :
`measured/2026-10-22-ecarts-remise-credit*.tsv`.

## Couche 1 → la pièce qui fait le crédit, et PLAY TIME au boot, le 2026-10-22

Laissés ouverts par #1406 (`measured/2026-10-22-ecarts-remise-credit.tsv`) :

| Élément | Décision |
|---|---|
| à la pièce qui fait le crédit, la référence appelle COIN_SOUND puis DEMO_END ($00012E) dans la trame et rend la main deux trames plus tard ; nous rendons la main à la trame suivante, le son différé après FRAME_SKIP | **gardé** : mesurer trame par trame (appel de $00012E observé par sa première écriture ou par un tap de lecture du vecteur, son, remise), puis égaler ; DEMO_END est lu dans « USER subroutine » / « Cartridge header » (wiki) |
| au boot, la référence remet PLAY TIME ($D00048-$D0004B) à zéro et pose $D0004C, $D0005A-$D0005D, $D0005E-$D00061 | **gardé** : mesurer les valeurs et les conditions (neuve / gardée), chercher dans la doc publique ce que portent ces cellules, puis égaler ce qui est établi |
| le code de la référence | **écarté** : aucune lecture |

**Vérifié avant la remise** : aucune adresse d'instruction ni octet du BIOS de référence.

**Issue de cette remise** : `_io_fin_demo` (`io.s`), après COIN_SOUND et le décompte du départ forcé,
gardé par $10FD81 = $06 contre la réentrée ; `_retour_demo_end` (`c0.s`) écrit $06, appelle DEMO_END
IRQ masquées, entre dans SYSTEM_RETURN (`_sysret_etat`, extrait de `_retour_systeme`), tient une
trame et remet en demande 3 ; `%d7` sert de drapeau « sous SYSTEM_IO », rendu au jeu, et INT1 le met
à zéro (`int1.s`). Au boot, les quatre écritures constantes de la référence ; $D0005A-$D0005D (l'heure
du calendrier) écarté, au plus restreint. Relevés : `measured/2026-10-22-piece-demo-end*.tsv`.

## Couche 1 → le crédit au départ de garou et d'alpham2, le 2026-10-22

Vu au catalogue du soir (`measured/2026-10-22-matrice-catalogue-soir.tsv`, captures à la trame
3500) : en partie, garou et alpham2 affichent CREDITS 10 sous notre image, 09 sous la référence,
avec les mêmes pièces de la sonde. Le départ ne décompte pas le crédit chez nous sur ces jeux, ou il
le décompte ailleurs.

| Élément | Décision |
|---|---|
| où et quand la référence décompte le crédit au départ de ces deux jeux ($D00034/$D00035, BIOS_CREDIT_DEC $10FDB0-$10FDB3, CREDIT_DOWN, $10FDB6-$10FDB9), comparé à un jeu où nous sommes déjà égaux | **gardé** : mesurer trame par trame, chez la référence et chez nous, puis égaler |
| le code de la référence et celui des jeux | **écarté** : aucune lecture |

**Vérifié avant la remise** : aucune adresse d'instruction ni octet du BIOS de référence.

**Issue de cette remise** : rien d'écrit dans `src/c0/`. garou : l'instrument (la pièce de la sonde
à la trame 300 tombe dans le second boot de la référence) ; alpham2 : la partie diverge, pas le
crédit. Deux des écarts vus en passant, sans effet sur le crédit, restent à reprendre : le minuteur de
répétition du joystick et le moment de $10FD81 ← $03 au START. Relevés :
`measured/2026-10-22-credit-au-depart*.tsv`.

## Couche 1 → la répétition du joystick et $10FD81 au START, le 2026-10-22

Vus en passant par le diagnostic du crédit de garou et d'alpham2 (`measured/2026-10-22-credit-au-depart.tsv`,
§ « écarts vus en passant ») :

| Élément | Décision |
|---|---|
| le minuteur de répétition (`_io_manette`) : la référence recharge $10 à tout changement d'état, $08 à zéro, et cycle $08 → $00 sans rien tenu (première répétition à 17 trames, puis toutes les 9) ; nous 16 puis 8, et $00 sans rien tenu | **gardé** : remesurer sur deux jeux, puis égaler |
| $10FD81 ← $03 au START : la référence l'écrit après PLAYER_START, seulement si le jeu garde le bit ; nous avant, à tout START avec crédit | **gardé** : remesurer, puis égaler |
| l'ordre d'écriture de CREDIT_CHECK (la référence écrit le mot $10FDB2 avant $10FDB1 ; mêmes valeurs) | **gardé** : égaler si c'est sans risque |
| le code de la référence | **écarté** : aucune lecture |

**Vérifié avant la remise** : aucune adresse d'instruction ni octet du BIOS de référence.

**Issue de cette remise** : les trois écarts étaient réels et sont égalés (`io.s` : `_io_manette`,
`_io_commun`, `_io_start`, `_credit_check`). Au-delà de la remise, mesuré et repris : la copie des
blocs de manette en $10FEE8-$10FEF3. Le déphasage du minuteur de P2 au repos vient de l'instrument
(les deux BIOS rendent la main au jeu à des trames différentes). Relevés :
`measured/2026-10-22-repetition-et-start*.tsv`.

## Couche 1 → FRAME_SKIP hors SYSTEM_IO, DEMO_END en mode 0, le 2026-10-22

Laissés ouverts par #1407 et #1409 (`measured/2026-10-22-piece-demo-end.tsv`,
`2026-10-22-repetition-et-start.tsv`) :

| Élément | Décision |
|---|---|
| mslug : après une remise, la référence décompte FRAME_SKIP ($10FEE1) sans que le jeu appelle SYSTEM_IO ; chez nous le minuteur du titre repart 5 trames plus tard (un chiffre TIME d'écart à l'écran) | **gardé** : mesurer qui décompte et quand (INT1 ? le vblank du BIOS ?), puis égaler |
| la pièce qui fait le crédit prise en mode 0 ou sous INT1 : la référence appelle aussi DEMO_END (b2b, trame 3312) ; nous gardons l'ancien chemin | **gardé** : mesurer, puis égaler |
| à la pièce créditée, la référence écrit $D00034 avant $10FDDA ← $30 ; nous l'inverse | **gardé** : égaler si rien d'autre ne bouge |
| le code de la référence | **écarté** : aucune lecture |

**Vérifié avant la remise** : aucune adresse d'instruction ni octet du BIOS de référence.

**Issue de cette remise** : les trois écarts étaient réels. Décompte de FRAME_SKIP sous INT1
(`int1.s`), la pièce sous INT1 sans remise immédiate (`io.s`, `_io_commun`), le code 2 avec un crédit
vers le titre (`c0.s`, `_sysret_demo`, mesuré en forçant le crédit), l'ordre à la pièce
(`_io_crediter`). Ce que la référence fait pendant son logo n'est pas reproduit : nous n'en avons pas.
Relevés : `measured/2026-10-22-frame-skip-et-mode0*.tsv`.

## Couche 1 → la comptabilité de la backup RAM et la trame tenue, le 2026-10-23

Petits écarts laissés ouverts par les lots du 2026-10-22 (`docs/tasks.md`, « Restent ouverts », et
les relevés `2026-10-22-piece-demo-end.tsv`, `2026-10-22-frame-skip-et-mode0.tsv`) :

| Élément | Décision |
|---|---|
| PLAY TIME ($D00048-$D0004B) « Reset to 0 by SYSTEM_RETURN » (wiki « Backup RAM ») : à quels codes, et ce que la référence y écrit le reste du temps (compte-t-elle le temps de jeu ?) | **gardé** : mesurer, puis égaler |
| $10FDB6-$10FDB9 remis à zéro par la référence à la pièce qui mène au titre | **gardé** : remesurer, puis égaler |
| l'affichage LED2 (crédits) : lit-il $D00035 ou $D00034 chez la référence ; notre `_sysret_fin_partie` teste le mot $D00034 | **gardé** : mesurer, puis égaler |
| pendant la trame tenue de `_retour_demo_end`, la référence sert son vblank (LED, impulsion du compteur de pièces $D00038, REG_SWPBIOS) ; $10FD80 ← $01 avant la remise sur ce chemin ; l'ordre marque du son / COIN_SOUND / impulsion $D00038 ← $1F et $10FEE2 ← $00 | **gardé** : égaler ce qui est mesuré |
| le code de la référence | **écarté** : aucune lecture |

**Vérifié avant la remise** : aucune adresse d'instruction ni octet du BIOS de référence.

**Issue de cette remise** : PLAY TIME, les mots $10FDB6-$10FDBD et la trame tenue étaient de vrais
écarts, égalés (`_io_temps`, `_io_son_piece` dans `io.s` ; `_remettre_a_user`, `_sysret_fin_partie`,
`_retour_demo_end` dans `c0.s` ; `int1.s`). LED2 : aucun écart. Risque dit : la trame tenue ouvre de
nouveau les interruptions, ce qu'un lot avait retiré après un gel de wjammers dans SYSTEM_RETURN ;
l'attente est bornée et wjammers passe la matrice. Relevés : `measured/2026-10-23-comptabilite*.tsv`.

## Couche 1 → les LED, et les petits écarts des remises, le 2026-10-23

Vus en passant par la remise de la comptabilité (`measured/2026-10-23-comptabilite.tsv`, « vu en
passant ») :

| Élément | Décision |
|---|---|
| la cadence des LED : la référence en verrouille une par appel, en alternance, après le crédit, et écrit REG_POUTPUT $12, $1B, $00 ; nous les deux à chaque appel, et $00 seulement | **gardé** : mesurer sur les registres d'E/S, lire « Memory mapped registers » (wiki), égaler |
| FRAME_SKIP ← $01 après PLAYER_START (nous $00) | **gardé** : remesurer, égaler |
| REG_SOUND ← $03 avant les remises de démo ; $10FD80 $00/$80 à la demande 0 (nous $01/$82) | **gardé** : remesurer, égaler |
| les trois trames que la référence tient au code 3 avant de rendre la main (nous la suivante) | **gardé** : remesurer, égaler |
| $D0002C, $D00039 et $10FEE0 écrits à la pièce | **gardé** : mesurer les valeurs et chercher leur rôle dans la doc publique ; égaler au plus restreint |
| le code de la référence | **écarté** : aucune lecture |

**Vérifié avant la remise** : aucune adresse d'instruction ni octet du BIOS de référence.

**Issue de cette remise** : quatre écarts réels égalés (LED et REG_POUTPUT, FRAME_SKIP ← $01,
$10FD80 et REG_SOUND aux remises, trames tenues du code 3), le cinquième ($D0002C, $D00039, $10FEE0)
repris au plus restreint, sans rôle attribué. Non repris : la double lecture des manettes sous
REG_POUTPUT. Vus en passant : le départ forcé réarmé au titre d'après game over, DEMO_END à SELECT.
Relevés : `measured/2026-10-23-led-et-remises*.tsv`.

## Couche 1 → le titre après game over, DEMO_END à SELECT, le 2026-10-23

Vus en passant par la remise des LED (`measured/2026-10-23-led-et-remises.tsv`) et par sa relecture :

| Élément | Décision |
|---|---|
| au code 3 avec un crédit, la référence réarme le départ forcé au titre ($10FDDA ← $30) ; notre titre d'après game over ne décompte pas ; elle écrit aussi $10FEC5 ← $00 et bascule $10FEBF | **gardé** : remesurer, égaler |
| SELECT : la référence décompte le départ forcé, écrit $10FEE0 ← 0, $10FD81 ← $04, puis appelle DEMO_END ; pas nous | **gardé** : remesurer, égaler |
| `_sysret_demo` teste le crédit sur l'octet $D00034, la fin de partie sur le mot $D00034-$D00035 : que fait la référence au code 2 avec un crédit sur $D00035 seul ? | **gardé** : mesurer (crédit forcé), égaler |
| les trames tenues des codes 0, 2 et de SELECT (quatre trames entre le retour et la remise chez la référence) | **gardé** : remesurer, égaler si rien d'autre ne bouge |
| le code de la référence | **écarté** : aucune lecture |

**Vérifié avant la remise** : aucune adresse d'instruction ni octet du BIOS de référence.

**Issue de cette remise** : les quatre écarts étaient réels ; trois égalés en entier (code 3, SELECT,
crédit sur le mot), le quatrième en partie (trames tenues des codes 0 et 2 sur le même slot, sans la
salve son ni REG_SLOT). Remesuré en passant, hors remise : la référence fait le double titre après game
over ; la décision « un seul titre » de `c0.s` est gardée, tranchée le 2026-10-23 (`DECISIONS.md` §9). Relevés :
`measured/2026-10-23-titre-apres-game-over*.tsv`.

## Couche 3 → le menu en jeu sans le Z80 ni le SFIX, le 2026-10-23

Signalé par l'utilisateur en jouant à mslug : plus de son après RESUME, HUD brouillé pendant la pause.

| Élément | Décision |
|---|---|
| mesurer le son après la reprise en key-on YM2610 (FM, ADPCM-A, ADPCM-B) contre un témoin sans menu | **gardé** |
| ce que fait UniBIOS de son menu en jeu : écritures à REG_SOUND, REG_BRDFIX/REG_CRTFIX, palettes, en boîte noire | **gardé** : valeurs et trames seulement |
| le code d'UniBIOS, du BIOS de référence ou des jeux | **écarté** : aucune lecture |

**Vérifié avant la remise** : aucune adresse d'instruction ni octet de BIOS tiers.

**Issue de cette remise** : la commande $03 seule rend le pilote muet (injectée sans menu, même
silence) ; rejouer les commandes du jeu ne le répare pas sur mslug. UniBIOS ne touche ni au Z80 ni
au SFIX et écrit avec la police de la cartouche. Correction retenue : la même. Relevés :
`measured/2026-10-23-menu-en-jeu-son.tsv`, `-plan-fixe.tsv`, `measured/2026-10-23-unibios-menu-en-jeu.tsv`.

## Couche 1 et 3 → le mode AES sur une carte MVS, le 2026-10-23

Demandé par l'utilisateur, décisions D1 à D7 (`DECISIONS.md` §11).

| Élément | Décision |
|---|---|
| ce que fait le BIOS AES de SNK sous `aes -bios asia` : BIOS_MVS_FLAG, demandes USER, START sans pièce, game over, en boîte noire | **gardé** : valeurs écrites, trames, empreintes d'image |
| les pages « USER subroutine », « BIOS RAM locations », « Memory mapped registers », « 68k program header » | **gardé** |
| le code du BIOS AES, du BIOS MVS de référence ou des jeux | **écarté** : aucune lecture |

**Vérifié avant la remise** : aucune adresse d'instruction ni octet de BIOS tiers ; le PC n'est lu que
pour dire qui écrit.

**Issue de cette remise** : le mode AES, mesuré contre la référence sur six jeux
(`measured/2026-10-23-mode-aes.tsv`, `-parcours-aes.tsv`). Le mode MVS garde ses instructions, pas ses
adresses (`measured/2026-10-23-disposition-mvs.tsv`).

## Couche 1 → CREDIT_CHECK en mode AES, le 2026-10-23

Trouvé par la scène `aes-texte` du parcours : en mode AES, aof affiche « INSERT COIN » pour P2 là où
le BIOS AES de SNK affiche « PUSH START ».

| Élément | Décision |
|---|---|
| ce que les jeux lisent et ce que le BIOS AES de SNK écrit autour de CREDIT_CHECK ($10FDB0-$10FDB3, $D00034), en boîte noire | **gardé** : valeurs écrites et lues, trames |
| le code du BIOS AES, du BIOS MVS de référence ou des jeux | **écarté** : aucune lecture |

**Issue de cette remise** : la référence ne touche jamais la demande en AES ; CREDIT_CHECK fait de même
en mode AES, le mode MVS gardant ses instructions sur le chemin accepté
(`measured/2026-10-23-aes-credit.tsv`, DECISIONS §11 point 10).

## Couche 3 → les menus au panneau de mahjong, le 2026-10-28

Demandé par l'utilisateur (#1455), décisions de `DECISIONS.md` §30.

| Élément | Décision |
|---|---|
| ce que font le BIOS SNK japonais et UniBIOS 4.0 de chaque touche du panneau dans leurs menus, et quand ils lisent le commutateur 3, en boîte noire (`measured/2026-10-28-panneau-menus-reference.tsv`) | **gardé** : effets à l'écran, valeurs écrites à REG_POUTPUT, trames |
| l'octet de P1CNT que rend MAME par touche selon REG_POUTPUT (même relevé, « lecture brute ») | **gardé** : c'est le matériel émulé, pas un BIOS |
| les pages « Memory mapped registers » et « BIOS RAM locations » | **gardé** |
| le code des BIOS de référence ou des jeux | **écarté** : aucune lecture |

**Vérifié avant la remise** : aucune adresse d'instruction ni octet de BIOS tiers dans le relevé.
