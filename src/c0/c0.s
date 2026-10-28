| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| COUCHE 0 DU BIOS — mise sous tension.
|
| Quatre régions dans l'image, à des offsets qui ne se choisissent pas :
|
|   $C00000  la table de vecteurs du 68000, que la carte sert aussi à $000000 au reset ;
|   $C00400  le descripteur de deux octets : type de machine, puis nationalité ;
|   $C00402  le point d'entrée, où mène le vecteur de reset ;
|   $C00438  le tableau d'appels du BIOS, des `rts` sauf SYSTEM_RETURN, SYSTEM_INT1
|            (`int1.s`), SYSTEM_IO et CREDIT_CHECK (`io.s`), READ_CALENDAR (`cal.s`), CARD
|            et CARD_ERROR (`card.s`), FIX_CLEAR et LSP_1st (`video.s`), MESS_OUT (`mess.s`).
|
| Et une séquence : REG_SWPBIOS ($3A0003) puis REG_BRDFIX ($3A000B), puis la détection
| des emplacements — REG_SLOT ($380021) sur chacun, la table $D00124, le premier slot
| nouveau servi, sinon le premier occupé —, puis le passage de slot : la poignée de
| main du son — $01 sur REG_SOUND et l'attente de son écho —, REG_SLOT, REG_CRTFIX
| ($3A001B), REG_SWPROM ($3A0013) — ce qui met la P-ROM de la cartouche en bas de la
| carte à la place des 128 octets du BIOS —, $03, puis la remise de la main à la routine
| USER de la cartouche, à $000122 : demande d'initialisation (ou démo, slot connu),
| encadrée des écritures de $10FD80, $10FDAF et $10FDAE que le relevé du protocole montre
| autour de chaque remise. Les autres slots nouveaux reçoivent la leur l'un après l'autre,
| par SYSTEM_RETURN, chacun par le même passage.
|
| CE QU'ELLE NE FAIT PAS, et c'est délibéré : aucun test de RAM, de palette ni de VRAM,
| aucune initialisation du calendrier — l'écran de boot (`ecran.s`) ne fait que le lire —,
| aucun calcul de somme de contrôle, aucune musique d'eyecatcher ($02), et
| aucun gestionnaire d'interruption installé — elle acquitte seulement, une fois, celles
| que la puce laisse en attente à la sortie de reset.
|
| L'ADRESSE $C00402 N'EST PAS UN CHOIX. Le 68000 prend son PC de reset dans la table
| ci-dessous, mais l'en-tête d'une cartouche Neo Geo porte aussi $C00402 à son offset
| $0004 : c'est l'adresse d'entrée que le matériel et les cartouches attendent du
| BIOS. On y met donc le point d'entrée, et le code lui-même plus loin.
|
| Sources des adresses et des sémantiques, toutes publiques (NeoGeo Development Wiki) :
|   - registres $3A00xx, $3C000C, $320000   : « Memory mapped registers »
|   - commandes son $01 et $03, leur écho   : « 68k/Z80 communication »
|   - coup de pied au watchdog, sa durée    : « Watchdog »
|   - l'idiome `move.b d0,REG_DIPSW`        : « Hello world tutorial »
|   - bits de REG_IRQACK, niveaux d'IRQ    : « 68k interrupts »
|   - descripteur $400-$401                : « System ROM »
|   - en-tête de cartouche et $0122        : « 68k program header »
|   - routine USER et ses demandes         : « USER subroutine »
|   - variables $10FCEE-$10FEFC            : « BIOS RAM locations »
|   - tableau d'appels $C004xx             : « BIOS calls »
|   - table de vecteurs                    : « 68k vector table »
|
| Et un relevé mesuré, `specs/traces/protocole.md` : les écritures du BIOS de référence
| sur $10FD80, $10FDAE, $10FDAF et $320000 autour de sa remise de la main à $000122.
|
| Ce qui n'a ni source ni mesure — le choix de la demande que SYSTEM_RETURN relance, et
| les valeurs des remises que le relevé ne couvre pas — est marqué SUPPOSÉ là où il est.
| ==================================================================================

| ----------------------------------------------------------------------------------
| TOUT TIENT DANS `.vectors`, ET C'EST VOULU. Les quatre régions sont à des offsets
| imposés, et `build/bios.ld` ne place qu'une section à l'offset 0 de l'image :
| `.vectors`. Les atteindre par `.org` depuis un seul début de section est le seul moyen
| d'en répondre — répartir le fichier entre `.vectors` et `.text` laisserait l'éditeur de
| liens décider de l'écart entre les deux. `.text` sort donc vide de l'ELF, et c'est
| normal.
|
| Le drapeau est `"a"` et non `"ax"` : c'est celui de `build/harnais/harnais.s`, et
| `objcopy -O binary` recopie les sections allouées sans regarder leur bit d'exécution.
| Mesuré : les deux drapeaux donnent la même image, au sha256 près.
| ----------------------------------------------------------------------------------
        .equ    BIOS_LOGO, 0x10FB08     | la demande 1 du mode AES (`_logo_aes`)
        .section .vectors, "a"

| ----------------------------------------------------------------------------------
| LA TABLE DE VECTEURS — 32 vecteurs, $000000 à $00007F.
|
| Seuls ces 128 octets sont servis à $000000, donc la table s'arrête aux autovecteurs
| de niveau 1 à 7 ($64-$7C) : les TRAP, qui commencent à $80, tomberaient déjà dans la
| P-ROM de la cartouche.
|
| Les vecteurs 2 à 31 mènent chacun à son point d'entrée de l'écran de plantage
| (`plantage.s`), qui connaît donc l'exception exacte. Au reset le 68000 masque les
| interruptions (SR = $2700) et le BIOS ne les démasque pas tant que cette table est
| active : ne restent que les exceptions d'erreur, qui signaleraient un défaut du BIOS.
| L'écran les montre ; une exception levée par l'écran même tombe dans une boucle
| identifiable dans la trace (`_plantage_double`), qui remplace l'ancien piège.
| ----------------------------------------------------------------------------------
        .long   0x10F300                | vecteur 0 : pile superviseur, sous la RAM BIOS
        .long   _reset                  | vecteur 1 : PC de reset, soit $C00402
        .irp    n, 2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
        .long   _pl_v\n                 | vecteurs 2 à 31
        .endr

| ----------------------------------------------------------------------------------
| LE DESCRIPTEUR — $C00400 et $C00401.
|
| « System ROM » donne ces deux octets : le premier porte le type de machine (0 = AES,
| $80 = MVS), le second la nationalité (0 = Japon, 1 = US, 2 = Europe). La page les
| écrit $000400 et $000401, soit les offsets $400 et $401 de l'image de la ROM système,
| donc $C00400 et $C00401 une fois la ROM mappée — elle ne pose pas elle-même cette
| équivalence, c'est l'offset dans l'image qui la rend nécessaire, le bas de la carte
| n'appartenant au BIOS que sur ses 128 premiers octets.
|
| C'est la seule déclaration d'identité de l'image, et le démarrage la recopie dans
| $10FD82 et $10FD83 plus bas. Sans ce renvoi, les deux mêmes faits seraient affirmés à
| deux endroits et rien ne dirait lequel fait foi.
|
| EUROPE, PAS JAPON. L'image tient sur le banc la place du BIOS euro, et les jeux lisent
| BIOS_COUNTRY_CODE à leur init pour choisir leur chemin. Mesuré sous MAME : la référence
| euro publie $10FD83 = $02 ; sous $00, `neomrdo` reste noir, `flipshot` se fige et
| `kof98` reste noir, et les trois repartent quand $10FD83 est forcé à $02.
| ----------------------------------------------------------------------------------
        .org    0x400
        .byte   0x80                    | $C00400 : type de machine — MVS
        .byte   0x02                    | $C00401 : nationalité — Europe

| ----------------------------------------------------------------------------------
| LE POINT D'ENTRÉE, à $C00402.
|
| La zone d'entrée va de $C00402 à $C00437, soit 54 octets. « BIOS calls » l'écrit
| « $C00402 to $C00432» : $C00432 est l'adresse du dernier de ses neuf créneaux de six
| octets ($402 + 6 x 8), non son dernier octet — le créneau suivant, $C00438, est déjà
| SYSTEM_INT1. Le premier créneau est la mise sous tension : un saut, le code vit plus bas.
|
| LES HUIT AUTRES, VERS L'ÉCRAN DE PLANTAGE. Lu dans « 68k vector table », gabarit « For
| cartridge systems » et mesuré sur 20 cartouches du corpus : les vecteurs d'exception
| d'une cartouche y mènent — le détail, créneau par créneau, est dans `plantage.s`. Laissés à zéro, ils faisaient glisser
| l'exécution jusqu'à SYSTEM_INT1 (mesuré sur b2b,
| `measured/2026-10-17-diagnostic-b2b-minasan.tsv`, point 1). Un `jmp` absolu fait
| exactement les six octets d'un créneau.
| ----------------------------------------------------------------------------------
        .org    0x402
        .global _reset                  | `build/bios.ld` prend ce symbole pour entrée de l'ELF
_reset:
        jmp     _demarrage
        .org    0x408
        jmp     _pl_c408                | erreur de bus
        .org    0x40E
        jmp     _pl_c40e                | erreur d'adresse (gabarit : illégale aussi)
        .org    0x414
        jmp     _pl_c414                | instruction illégale, lignes A/F
        .org    0x41A
        jmp     _pl_c41a                | privilège, division, CHK, TRAPV
        .org    0x420
        jmp     _pl_c420                | trace
        .org    0x426
        jmp     _pl_c426                | division … réservés, autovecteurs 3 à 7
        .org    0x42C
        jmp     _pl_c42c                | interruption non initialisée
        .org    0x432
        jmp     _pl_c432                | interruption parasite

| ----------------------------------------------------------------------------------
| LE TABLEAU D'APPELS DU BIOS — $C00438 et au-delà, une entrée tous les 6 octets.
|
| Chaque entrée est un `rts`, sauf SYSTEM_RETURN, SYSTEM_INT1, SYSTEM_IO, CREDIT_CHECK, READ_CALENDAR, CARD,
| CARD_ERROR, FIX_CLEAR, LSP_1st et MESS_OUT. L'appelant repart avec ses variables
| inchangées, ce qui est faux mais inoffensif. Sans entrée du tout, il exécuterait le
| remplissage $FF de l'image, prendrait une exception, et la couche 0 ne rendrait plus
| la main à personne.
|
| IL VA JUSQU'À $C006FC, ET PAS JUSQU'À $C0051C. La dernière ligne de « BIOS calls » est
| « $C0059A to $C006FC », Invalid / RTS. Entre $C00522 et $C00594 la page intercale des
| entrées BIOSF_* — UPLOAD, LOADFILE, CDPLAYER, CDDACMD, VIDEOEN, PUSHCDOP, SETCDDMODE,
| RESETGAME — qu'elle marque « CD only », et sa colonne cartouche les donne Invalid. On
| les sert quand même d'un `rts` : « Invalid » dit qu'un jeu à cartouche n'a rien à y
| appeler, pas que le silicium l'en empêche, et rien de ce que j'ai lu ne ferme ces
| créneaux. Le remplissage va donc d'un bout à l'autre de la table — 114 entrées de
| $C00456 à $C006FC, dont READ_CALENDAR, la 2e, CARD et CARD_ERROR, les 4e et 5e, et FIX_CLEAR, LSP_1st et
| MESS_OUT, les 19e, 20e et 21e, sortent par un `jmp` —
| et le code vit AU-DELÀ, plus bas.
|
| CE QUE `puzzledp` APPELLE VRAIMENT, mesuré sur les 18,99 trames que couvre la trace —
| la trace du co-simulateur (non publié) plafonne en accès, pas en trames, et seuls les compteurs du banc vont
| jusqu'à 20. On compte les accès tombant à l'adresse exacte d'une entrée, et chacun est
| bien un appel distinct : les écarts entre eux valent une trame, ~811 000 périodes.
|
|   SYSTEM_IO     $C0044A   16        CREDIT_CHECK   $C00450   12
|   FIX_CLEAR     $C004C2    2        LSP_1st        $C004C8    1
|   SYSTEM_RETURN $C00444    1        total                    32
|
| Dans la seule fenêtre de jugement (T+2,07 à T+8,63), 9 de ces appels. Et 18 accès en
| espace programme y tombent dans la ROM du BIOS, sur 247 713 : les 9 autres sont le
| préfetch autour des `rts`. Un autre jeu n'appelle pas les mêmes entrées.
|
| Refaire ce comptage, sur une trace du co-simulateur (non publié) :
|   grep -oE ' C00(444|44A|450|4C2|4C8) rd ' trace.txt | sort | uniq -c
| ----------------------------------------------------------------------------------
        .org    0x438
        jmp     _systeme_int1           | SYSTEM_INT1  — routine de vblank, dans `int1.s`
        .org    0x43E
        rts                             | SYSTEM_INT2  — routine de timer
        .org    0x444
        jmp     _retour_systeme         | SYSTEM_RETURN — atteint par `jmp`, pas par `jsr`
        .org    0x44A
        jmp     _systeme_io             | SYSTEM_IO    — dans `io.s` ; ne sauve aucun registre
        .org    0x450
        jmp     _credit_check           | CREDIT_CHECK — dans `io.s`
        .org    0x456
        rts
        .space  4                       | une entrée fait 6 octets
        .org    0x45C
        jmp     _read_calendar_jeu      | READ_CALENDAR — dans `cal.s`, la date gelée s'il le faut
        .org    0x462
        rts
        .space  4
        .org    0x468
        jmp     _card                   | CARD         — dans `card.s`
        .org    0x46E
        jmp     _card_error             | CARD_ERROR   — dans `card.s`
        .org    0x474
        .rept   13                      | de $C00474 à $C004BC
        rts
        .space  4
        .endr
        .org    0x4C2
        jmp     _fix_clear              | FIX_CLEAR    — dans `video.s`
        .org    0x4C8
        jmp     _lsp_1st                | LSP_1st      — dans `video.s`
        .org    0x4CE
        jmp     _mess_out               | MESS_OUT     — dans `mess.s`
        .org    0x4D4
        .rept   93                      | de $C004D4 jusqu'à $C006FC, fin de la table
        rts
        .space  4
        .endr

| ----------------------------------------------------------------------------------
| LE CODE, HORS DE PORTÉE DU TABLEAU D'APPELS.
|
| La dernière entrée, $C006FC, occupe ses 6 octets jusqu'à $C00701 : rien de ce que
| « BIOS calls » décrit ne vit au-delà. $C00800 est donc le premier offset rond qui mette
| le code hors d'atteinte d'un `jsr $C00xxx` venu du tableau — et un offset rond se
| reconnaît dans une trace, ce qui compte quand on cherche où le 68000 est parti.
|
| LA PREMIÈRE VERSION DE CETTE COUCHE POSAIT LE CODE À $C00600, soit dans le tableau : 23
| créneaux de la plage $C0059A-$C006FC tombaient dedans, et un jeu qui en aurait appelé un
| sautait dans `_demarrage` — réécriture de REG_SWPROM et mise sous tension relancée en
| pleine partie. `puzzledp` ne les appelle pas, donc le banc n'en montrait rien : c'est le
| commentaire « jusqu'à $C0051C, sa fin » qui était faux, et le code avec lui.
|
| L'écart $C00702-$C007FF reste à zéro, par le remplissage de `.org`. Je n'ai rien trouvé
| qui y pointe ; ce n'est pas une preuve qu'il n'y a rien, seulement l'état de ce que j'ai
| lu.
| ----------------------------------------------------------------------------------
        .org    0x800

_demarrage:
        | Le 68000 sort du reset en superviseur avec les IRQ masquées. On l'écrit quand
        | même : la couche 0 tient à ce que rien ne s'exécute entre ici et la bascule.
        move.w  #0x2700, %sr
        move.l  #0x10F300, %sp

        | LE WATCHDOG D'ABORD. Écrire $300001 lui donne un coup de pied ; « Watchdog » dit
        | d'y écrire « any value », donc la donnée ne compte pas. Écrire depuis un registre
        | de données est l'idiome du « Hello world tutorial » — `move.b d0,REG_DIPSW`,
        | commenté « Kick watchdog » —, mais que %d0 soit INDÉFINI est mon choix, autorisé
        | par ce « any value » : l'exemple de « USER subroutine », lui, met d0 à zéro.
        | SON COMPTEUR arrivé à zéro, la carte tire le reset : la mise sous tension
        | recommencerait, et REG_SWPROM serait écrit une seconde fois.
        |
        | SA DURÉE EST DOCUMENTÉE, MAIS PAS VÉRIFIÉE. La section Timings de « Watchdog »
        | donne 3 244 030 cycles, « corresponds to 8 frames », et la marque « This isn't
        | verified » ; elle cite aussi MAME, 0,128762 s, soit environ 7,6 trames — les
        | deux chiffres publics ne s'accordent donc pas. Le co-simulateur (non publié) retient
        | 8 trames, ce qui est le plus exigeant des deux. Le décodage de toute
        | adresse impaire de $300000-$31FFFF, lui, est propre au co-simulateur
        | et non une donnée du wiki.
        move.b  %d0, 0x300001

        | LA POIGNÉE DE MAIN, dans cet ordre.
        move.b  %d0, 0x3A0003           | REG_SWPBIOS : table de vecteurs du BIOS
        move.b  %d0, 0x3A000B           | REG_BRDFIX  : SFIX et SM1 de la carte

        | RELÂCHER LES DEUX COIN LOCKOUTS. Lu dans « Memory mapped registers » :
        | REG_RESETCL1 ($380065) et REG_RESETCL2 ($380067) laissent flotter les lockouts 1
        | et 2, donnée « Any », par le NEO-I0 ; REG_SETCL1/2 ($3800E5/E7) font l'inverse.
        | Mesuré sous MAME sur `wjammers` : sans ces écritures, le bit pièce de $320001 ne
        | descend jamais et aucune pièce n'est acceptée ; avec elles, la pièce suivante
        | passe. La référence écrit $00 sur $380065 puis $380067, une fois, à la trame 0.
        | Ici, pour la même raison : avant la remise à $000122, donc avant tout SYSTEM_IO
        | et tout INT1 — les IRQ restent masquées jusque-là.
        move.b  %d0, 0x380065           | REG_RESETCL1 : lockout 1 relâché
        move.b  %d0, 0x380067           | REG_RESETCL2 : lockout 2 relâché

        | LES AUTRES REGISTRES DE LA CARTE, posés ici plutôt que laissés à leur état de mise
        | sous tension, qu'aucune page lue ne donne. Adresses et sens lus dans « Memory mapped
        | registers ». Valeurs : mesurées sous MAME le 2026-10-22 sur la référence (-bios euro,
        | aof, puzzledp, mslug, NVRAM neuve, tap d'écriture lua sur $380000-$3800FF,
        | $3A0000-$3A001F et $3C0006-$3C000F, 400 trames ; valeurs écrites seulement, aucun
        | PC), les trois jeux égaux ; relevé non versionné, remis à l'agent coordinateur.
        |   - REG_LSPCMODE ($3C0006) ← $4000 : mesuré, la référence l'écrit à la trame 1, avec
        |     l'acquittement des IRQ. Vitesse d'auto-animation dans l'octet haut, IRQ timer
        |     coupée dans les bits bas (lecture des bits mienne, comme à SYSTEM_RETURN plus
        |     bas, qui écrit la même valeur, mesurée elle aussi) ;
        |   - LE TIMER, REG_TIMERHIGH/LOW ($3C0008/$3C000A) : mesuré, la référence n'y écrit
        |     rien en 400 trames, ni dans REG_TIMERSTOP ($3C000E). On n'y écrit pas non plus :
        |     REG_LSPCMODE ci-dessus coupe son IRQ, et le jeu qui s'en sert le charge lui-même ;
        |   - REG_NOSHADOW ($3A0001), donnée « Any » : mesuré, la référence l'écrit une fois au
        |     boot (trames 282 à 287 selon le jeu, donnée $00). Ici dès le reset : SUPPOSÉ sans
        |     conséquence, ce BIOS n'écrivant jamais REG_SHADOW ($3A0011, lu dans le code) ;
        |   - LES VERROUS DE CARTE, REG_CRDLOCK2 ($3A0007) puis REG_CRDLOCK1 ($3A0015), donnée
        |     « Any » : mesuré, la référence les écrit à la trame 277, dans cet ordre (donnée
        |     $30), l'ordre de `card.s` aussi. Ici dès le reset ; CARD les rouvre au besoin ;
        |   - LES COMPTEURS DE PIÈCES (REG_RESETCC1/2, REG_SETCC1/2) : mesuré, la référence n'y
        |     écrit pas au boot (400 trames) ; on ne les pose donc pas non plus.
        move.w  #0x4000, 0x3C0006       | REG_LSPCMODE
        move.b  %d0, 0x3A0001           | REG_NOSHADOW
        move.b  %d0, 0x3A0007           | REG_CRDLOCK2
        move.b  %d0, 0x3A0015           | REG_CRDLOCK1

        | LA ZONE SYSTÈME DE LA BACKUP RAM, FORMATÉE SI SA SIGNATURE MANQUE. Lu dans « Backup
        | RAM » : $D00010-$D0001F porte « BACKUP RAM OK!Ç », et le BIOS, s'il ne trouve pas
        | la chaîne, teste la RAM et la réinitialise. Mesuré sous MAME (`puzzledp`, boîte
        | noire) : `BACKUP RAM OK !` — une espace avant « ! », que la page n'a pas — puis $80,
        | le « Ç » de la page si on la lit en page de code 437 (lecture mienne). Mesuré aussi :
        | `kof98`, sur une zone laissée vierge, part dans un chemin fatal (boucle sans coup de
        | pied au watchdog, IRQ masquées, reset en boucle).
        |
        | SIGNATURE PRÉSENTE : ON NE TOUCHE À RIEN. La NVRAM d'un MVS persiste d'un boot à
        | l'autre, réglages et compteurs compris.
        |
        | PAS DE TEST MÉMOIRE. La référence passe des motifs sur la zone avant de formater
        | (mesuré, trames 38-62 de `puzzledp` : $5555, $AAAA, puis une valeur tirée de
        | l'adresse). Ce boot ne teste aucune RAM ; seule la validation l'est, et le formatage.
        |
        | L'ÉTENDUE : $D00000-$D0007F. La page ne borne pas de « zone système » ; elle décrit
        | des cellules jusqu'à la comptabilité de $D08320. On s'arrête au dernier octet que les
        | dumps de la référence couvrent : au-delà, la date ($D00104), les tables de slots
        | ($D00124, « $0000 as NGH and $FFFF as game name ID » quand le slot est vide) et les
        | blocs de jeu demanderaient des valeurs ni mesurées ni toutes écrites par la page —
        | des zéros y contrediraient le $FFFF des slots vides. SUPPOSÉ donc, que rien de ce
        | qu'un jeu lit à son init ne tombe plus haut. La table des slots a son propre
        | contrôle et son propre formatage, à la fin du boot.
        |
        | LES VALEURS. Zéro partout sauf ce qui suit, mesuré après le boot de la référence
        | (dumps espacés de 160 trames) ; ce que la page en dit est noté à côté.
        |   $D0003A-3D  01 01 01 02  « Cab settings » : pièces et crédits de P1 puis P2,
        |                            « initialized to $01 », $01, $01, « $02 »
        |   $D0003E-41  01 01 01 03  mesuré ; la page couvre ces octets par « Cab settings »
        |                            sans les détailler
        |   $D00042-43  00 00        mesuré ; la page : « Game select », « initialized to 0 »,
        |                            et « Game start compulsion », 0 = activée, sans défaut
        |   $D00044     30           « Game start compulsion time », BCD, « initialized to $30 »
        |   $D00045     3B           mesuré ; dernier octet de « Cab settings », non détaillé
        |   $D00046     00           « Demo sound », « initialized to 0 » ; la même page le
        |                            nomme aussi SOUND_STOP
        |   $D00047     02           SLOT NUMBER, « 2 for slot1 »
        |   $D0004C     3B           mesuré ; PLAY_TIME_FRAME_TIMER, que la page fait partir
        |                            de $3C — `io.s` le recharge à $3C, il ne compte pas sur 3B
        |   $D00058     FF           mesuré ; « First slot number with a boot logo flag to 0 »
        |   $D0005A-5D  00 00 00 3C  le minuteur HHMMSSFF. SUPPOSÉ : la page donne les plages
        |                            (FF décompte de $3C à $00), pas la valeur de formatage, et
        |                            les dumps le montrent déjà avancé. FF à $3C, le haut de
        |                            son décompte : à $00, `io.s` compterait une seconde de plus
        |   $D0005E-5F  FF FF        mesuré ; la page les laisse dans un « ? »
        | Les cellules que `io.s` écrit en vie ($D00020-22, $D00034-35, $D00038…) partent de
        | zéro, comme les dumps de la référence.
        |
        | LA SIGNATURE EN DERNIER, après un effacement qui l'a d'abord détruite. SUPPOSÉ : elle
        | n'atteste que d'un formatage complet, et un reset au milieu doit le faire reprendre.
        | La SRAM s'ouvre par REG_SRAMUNLOCK ($3A001D) et se referme par REG_SRAMLOCK
        | ($3A000D), « Memory mapped registers » ; la donnée ne compte pas.
        lea     0xD00010, %a0
        lea     _signature_bram, %a1
        moveq   #(16 / 4) - 1, %d1
_bram_verifier:
        cmpm.l  (%a1)+, (%a0)+
        dbne    %d1, _bram_verifier
        beq.s   _bram_valide            | Z tient le dernier `cmpm` : 16 octets égaux

        move.b  %d0, 0x3A001D           | REG_SRAMUNLOCK
        lea     0xD00000, %a0
        moveq   #(0x80 / 4) - 1, %d1
_bram_vider:
        clr.l   (%a0)+
        dbra    %d1, _bram_vider
        move.l  #0x01010102, 0xD0003A   | Cab settings : pièces et crédits P1, P2
        move.l  #0x01010103, 0xD0003E
        move.l  #0x303B0002, 0xD00044   | compulsion $30, $3B, demo sound 0, 2 slots
        move.b  #0x3B, 0xD0004C         | PLAY_TIME_FRAME_TIMER
        move.b  #0xFF, 0xD00058
        move.l  #0x0000003C, 0xD0005A   | HHMMSSFF : zéro, FF en haut du décompte
        move.w  #0xFFFF, 0xD0005E
        lea     0xD00010, %a0
        lea     _signature_bram, %a1
        move.l  (%a1)+, (%a0)+
        move.l  (%a1)+, (%a0)+
        move.l  (%a1)+, (%a0)+
        move.l  (%a1)+, (%a0)+
        move.b  %d0, 0x3A000D           | REG_SRAMLOCK
_bram_valide:

        | LES PIÈCES ET LES CRÉDITS NE SURVIVENT PAS À LA MISE SOUS TENSION. MESURÉ sous MAME le
        | 2026-10-22 (`bench/multislot.lua`, `MS_SUIVRE`, -bios euro, MV-6F ;
        | `measured/2026-10-22-ecarts-remise-credit.tsv`) : à chaque boot, NVRAM neuve (trame
        | 277) comme gardée (trame 238), puzzledp seul comme avec aof, la référence écrit $00
        | sur chaque octet de $D00020-$D00039 — front de pièce, compteurs partiels $D00024/25,
        | crédits $D00034/35, minuteur d'impulsion $D00038 —, qu'ils aient porté 2 crédits,
        | 3 crédits P2 ou une pièce sur deux. Notre image les gardait d'un boot à l'autre.
        | Ici, avant la détection des slots ; sur une NVRAM neuve, le formatage ci-dessus les
        | a déjà mis à zéro.
        move.b  %d0, 0x3A001D           | REG_SRAMUNLOCK
        lea     0xD00020, %a0
        moveq   #(0x1A / 2) - 1, %d1    | 26 octets, $D00020-$D00039
1:      clr.w   (%a0)+
        dbra    %d1, 1b
        | PLAY TIME ET SES VOISINES, À CHAQUE BOOT. MESURÉ sous MAME le 2026-10-22
        | (`bench/multislot.lua`, `MS_SUIVRE` sur $D00048-$D00061, -bios euro, puzzledp ;
        | `measured/2026-10-22-piece-demo-end-boot.tsv`), NVRAM neuve (trame 277), gardée et
        | gardée avec ces 26 octets posés à d'autres valeurs (trame 238) : la référence écrit
        | $D0005E-5F ← $FF, $D00060-61 ← $00, $D00048-4B ← $00, $D0004C ← $3B, dans cet
        | ordre, quel que soit leur contenu ; $D0004D-$D00057 ne sont pas touchés.
        | LU dans « Backup RAM » : PLAY TIME, « Counter of second played on the game in hex »,
        | « Reset to 0 by SYSTEM_RETURN » (la page ne parle pas du boot) ; $D0004C,
        | PLAY_TIME_FRAME_TIMER, « start at $3C » — la référence pose $3B, on la suit ;
        | $D0005E-$D00061 marqués « ? ». Aucun des 22 jeux du corpus ne lit $D00048-$D00061
        | (`measured/2026-10-22-bram-lue-par-les-jeux.tsv`) : la mesure seule décide.
        | NON REPRIS : $D0005A-5D, que la référence pose à l'heure du calendrier à chaque boot
        | (mesuré : 21:50:29 lu, $54 $32 $1D $3C écrits — heure × 4, minute, seconde en
        | binaire, puis $3C ; l'heure de l'hôte, que MAME donne au µPD4990A). Il faudrait lire
        | le calendrier au boot pour une cellule qu'aucun jeu ne lit : on s'en tient au
        | formatage et au décompte de `io.s`.
        move.w  #0xFFFF, 0xD0005E
        clr.w   0xD00060
        clr.l   0xD00048                | PLAY TIME
        move.b  #0x3B, 0xD0004C         | PLAY_TIME_FRAME_TIMER
        move.b  %d0, 0x3A000D           | REG_SRAMLOCK

        | ACQUITTER LES TROIS INTERRUPTIONS. « 68k interrupts » donne le niveau 3
        | « pending after reset », et les bits de REG_IRQACK : 2 pour le vblank, 1 pour le
        | timer, 0 pour le reset — la page marque ce dernier d'un « ? ». Son exemple
        | `move #$0007,REG_IRQACK` les acquitte des trois d'un coup, et c'est ce qu'on
        | fait : l'IRQ est masquée ici, mais le jeu démasque, et une en attente le ferait
        | partir dans son gestionnaire avant sa propre initialisation.
        move.w  #7, 0x3C000C

        | VIDER $10F300 À $10FFFF, soit 832 mots longs. C'est PLUS QUE LA RAM BIOS : la
        | plus basse variable que « BIOS RAM locations » décrive est $10FCEE, et ce qui
        | précède est la zone où descend la pile superviseur, posée à $10F300. La couche 0
        | ne lit aucune de ces variables, mais le jeu en lit : les laisser au contenu de
        | la mise sous tension ferait dépendre son démarrage de ce qu'il y avait là.
        lea     0x10F300, %a0
        move.w  #((0x110000 - 0x10F300) / 4) - 1, %d1
_vider:
        clr.l   (%a0)+
        dbra    %d1, _vider

        | L'ÉTAT QU'ON POSE. Le type de machine et la nationalité, que le zéro du vidage
        | ferait mentir : on les prend au descripteur. Les trois variables du protocole
        | USER, elles, sont écrites à la remise de la main, plus bas.
        move.b  0xC00400, 0x10FD82      | BIOS_MVS_FLAG     ← type de machine
        move.b  0xC00401, 0x10FD83      | BIOS_COUNTRY_CODE ← nationalité
        | LA RÉGION CHOISIE À L'ÉCRAN, si les réglages du BIOS la portent (`reglages.s`) :
        | elle remplace le descripteur. Ici, avant tout ce qui la lit — l'écran de boot, le
        | pointeur des soft-DIP (`_slot_inscrit`, `dip.s`) et CARD_REGION (`card.s`). La
        | backup RAM se lit sans être déverrouillée, et la zone système vient d'être
        | validée ou formatée plus haut ; le formatage ne touche pas $D00210.
        jsr     _reglages_region
        tst.b   %d0
        bmi.s   1f                      | $FF : pas de réglage, le descripteur reste
        move.b  %d0, 0x10FD83
1:
        | LE MODE CHOISI À L'ÉCRAN (ligne MODE de `dip.s`, `reglages.s`) : $80 MVS ou $00 AES
        | dans BIOS_MVS_FLAG, à la place du descripteur. C'est ce que lisent les jeux (relevé
        | `measured/2026-10-23-mode-aes.tsv`) ; la machine, elle, reste un MVS (REG_STATUS_B
        | bit 7). Ici, avant l'écran de boot qui l'affiche. Écart voulu : DECISIONS §11.
        jsr     _reglages_mode
        cmpi.b  #0xFF, %d0
        beq.s   1f                      | pas de réglage : le descripteur reste
        move.b  %d0, 0x10FD82
1:
        | LA BORNE (FREE PLAY, NO CONTINUE, DEMO SOUND) en RAM, d'après les réglages et le mode
        | qu'on vient de poser (`reglages.s`, `_borne_ram`) : avant toute remise et tout appel du jeu.
        jsr     _borne_ram
        | EN MODE AES, LES MONNAYEURS VERROUILLÉS : la pièce est ignorée (décision D2). Lu dans
        | « Memory mapped registers » : REG_SETCL1/2 ($3800E5/E7), « coin lockout sinks
        | current », l'inverse des REG_RESETCL relâchés plus haut ; « Coin switch » : la pièce
        | n'est détectée que lockout non alimenté. Mesuré sous MAME le 2026-10-23 (parcours,
        | scène aes-piece) : la pièce ne change aucune trame ni aucun key-on. Le verrou plutôt
        | qu'un test dans SYSTEM_IO, pour que le mode MVS garde ses cycles (DECISIONS §11).
        tst.b   0x10FD82
        bmi.s   1f
        move.b  %d0, 0x3800E5           | REG_SETCL1
        move.b  %d0, 0x3800E7           | REG_SETCL2
1:
        | BIOS_MESS_POINT ← BIOS_MESS_BUFFER, avant la première remise : mesuré
        | (`measured/2026-10-17-b2b-mess-out.tsv`, point 4, trame 279). Sans lui, le pointeur
        | part de zéro et les dépôts du jeu tombent dans la P-ROM (point 3). BIOS_MESS_BUSY
        | ($10FDC2) est mesuré à 00 à la trame 276 : le vidage ci-dessus l'y a déjà mis.
        move.l  #0x10FF00, 0x10FDBE

        | LES EMPLACEMENTS : combien la carte en a, lesquels sont occupés, et la table $D00124
        | qui en découle. Mesuré sur la référence (`measured/2026-10-21-multi-slot.tsv`, MV-6F) :
        | $D00047 ← le nombre de slots de la CARTE (6, pas le nombre de cartouches), puis pour
        | chaque slot k : $D00108 ← k, REG_SLOT ($380021) ← k, en-tête lu ; puis les huit
        | entrées de la table, l'entrée k étant le slot physique k. Ici, avant l'écran de boot,
        | pour qu'il lise l'en-tête du slot servi.
        |
        | LE PARCOURS SE FAIT SOUS REG_CRTFIX, ET C'EST UNE CORRECTION DU MATÉRIEL. Jusqu'à
        | l'image n°8 il se faisait sous REG_BRDFIX, l'état du reset : sous MAME tout marchait,
        | et sur une vraie MV-2F (2026-10-24, `docs/ESSAI-MATERIEL.md`) l'en-tête de chaque
        | slot se lisait en bus flottant — GAME NGH affichait E05C, le mot qui suit
        | `move.w 0x108,%d4` dans `ecran.s`, avec ou sans cartouche. Lu (NeoGeo Development
        | Wiki) : « MVS cartridge pinout », SLOTCS « goes low when the slot is used », vient de
        | NEO-F0 SLOT0~5 sur une carte multi-slot, « tied to SYSTEMB » sur une carte à un slot,
        | et « The System ROM was written to ensure the signal is asserted when it does the
        | slot check » ; « NEO-F0 » : « SYSTEMB is used to gate the SLOT* outputs » ;
        | « Signals » : « SYSTEM: low when onboard ROMs selected ». SUPPOSÉ, la forme exacte :
        | sous REG_BRDFIX aucun slot n'est sélectionné, et rien ne tient le bus de la P-ROM.
        | MESURÉ sous MAME (`bench/acces-boot.lua`, ng_mv2f et neogeo, -bios euro, 1 et 2
        | cartouches, slot 0 vide ; `measured/2026-10-24-slot-crtfix.tsv`) : la référence
        | écrit REG_SLOT ← 0, REG_CRTFIX, REG_SLOT ← 0, puis lit l'en-tête de chaque slot,
        | puis REG_BRDFIX ; avant tout cela, $01 sur REG_SOUND et son écho.
        |
        | LE Z80 EST DONC GARÉ D'ABORD. Mesuré (`MS_SONDE_M1`, référence, 2 cartouches) :
        | sous REG_CRTFIX, chaque écriture de REG_SLOT change aussitôt la M1 que voit le Z80.
        | Garé en RAM par $01 et son écho (`_garer_z80_vite`), il ne lit plus sa ROM ;
        | REG_BRDFIX, après le parcours, lui rend la SM1 de la carte, et le passage au slot
        | servi, plus bas, n'envoie que $03.
        | SUPPOSÉ : que le pilote de la SM1 réponde à $01 dès les premières trames après le
        | reset — la référence ne l'envoie qu'à la trame 276. Sans écho, `_garer_z80_vite`
        | bascule quand même au bout de 60 trames, et le parcours reste juste : seul le Z80 en
        | pâtit. L'écho y est guetté en continu, pas une trame après l'envoi comme au passage de
        | slot : sous MAME il vient dans la trame du reset, et l'écran de boot commence alors à
        | la même trame qu'avant (mesuré, `bench/bus-flottant.lua`, BF_LIBRE). Un $01 laissé
        | dans le verrou de réponse passerait pour l'écho ; MAME l'a à $00 au reset (relevé de la
        | référence, 542 lectures à $00 avant son écho), la page ne dit rien du matériel.
        move.b  %d0, 0x3A001D           | REG_SRAMUNLOCK

        | LA TABLE EST-ELLE LÀ ? %d3 : un bit par bloc pris, 0 à 7. SUPPOSÉ, elle manque si
        | un index pris sort de 0-7 ou se répète : une SRAM à zéro tombe dans ce cas (huit
        | index 0), une table que ce BIOS a écrite jamais. Formatée alors à huit entrées vides,
        | « $0000 as NGH and $FFFF as game name ID » (« Backup RAM »). Ce test ne dépend pas
        | de la signature de $D00010 : une NVRAM signée sans table doit en recevoir une.
        lea     0xD00124, %a0
        moveq   #0, %d3
        moveq   #8-1, %d1
_slots_valider:
        move.w  2(%a0), %d2             | index de bloc
        cmpi.w  #0xFFFF, %d2
        beq.s   1f                      | entrée libre
        cmpi.w  #8, %d2
        bhs.s   _slots_formater         | index hors de 0-7
        bset    %d2, %d3                | Z ← l'ancien bit était nul
        bne.s   _slots_formater         | index déjà pris par une autre entrée
1:      addq.l  #4, %a0
        dbra    %d1, _slots_valider
        bra.s   _slots_compter

_slots_formater:
        lea     0xD00124, %a0
        moveq   #8-1, %d1
1:      move.l  #0x0000FFFF, (%a0)+     | NGH $0000, bloc $FFFF : entrée vide
        dbra    %d1, 1b

        | LE NOMBRE DE SLOTS, %d6. Lu dans « Memory mapped registers » : REG_SYSTYPE
        | ($300081) bit 6, « 0: 2 slots, 1: 4 or 6 slots » ; REG_STATUS_A ($320001) bit 5,
        | « 0:4-SLOT, 1:6-SLOT ». Mesuré sous MAME, référence et nous égaux : 6 sur `neogeo`
        | (MV-6F), 4 sur `ng_mv4f` et `ng_mv2f`, 2 sur `ng_mv1` et `ng_mv1f` — « 2 for slot1 »,
        | dit « Backup RAM » de $D00047.
_slots_compter:
        moveq   #2, %d6
        btst    #6, 0x300081            | REG_SYSTYPE
        beq.s   1f
        moveq   #4, %d6
        btst    #5, 0x320001            | REG_STATUS_A
        beq.s   1f
        moveq   #6, %d6
1:      move.b  %d6, 0xD00047           | SLOT NUMBER

        | LE PARCOURS. %d5 : un bit par slot occupé ; 16 octets de pile : le NGH de chacun.
        | UN SLOT EST OCCUPÉ si son en-tête porte « NEO-GEO » en $100-$106 (« 68k program
        | header » : « first cartridge recognition code »). Mesuré : la référence ne lit d'un
        | slot vide que $000100, et de tout l'en-tête $000100-$000106 sur un slot occupé ;
        | qu'elle compare ces sept octets à la chaîne est SUPPOSÉ, comme ce que rend la carte
        | pour un slot vide (sous MAME, autre chose que « NEO- »).
        | ET SI SON NGH N'EST PAS DÉJÀ CELUI D'UN SLOT D'AVANT. Mesuré sur la référence : sur
        | `ng_mv1`, où le slot 1 rend l'en-tête du slot 0 (lu en entier), puis sur la MV-6F avec
        | le même jeu deux fois (slots 0 et 1, 0 et 3, 1 et 2) : le second slot sort $0000 /
        | $FFFF. « Backup RAM » : « slot1 are slot2 with the second one empty ». SUPPOSÉ : que
        | ce soit le NGH qu'elle compare, et non tout l'en-tête.
        bsr     _garer_z80_vite         | clobbers %d0, %d4
        move.b  #0, 0x380021            | REG_SLOT ← 0 avant la bascule, comme la référence
        move.b  %d0, 0x3A001B           | REG_CRTFIX : la cartouche du slot répond (SLOTCS)
        lea     -16(%sp), %sp
        moveq   #0, %d5
        moveq   #0, %d1
_slots_parcourir:
        move.b  %d1, 0xD00108           | ordre mesuré : $D00108, puis REG_SLOT
        move.b  %d1, 0x380021           | REG_SLOT
        cmpi.l  #0x4E454F2D, 0x100      | « NEO- »
        bne.s   2f
        cmpi.w  #0x4745, 0x104          | « GE »
        bne.s   2f
        cmpi.b  #0x4F, 0x106            | « O »
        bne.s   2f
        move.w  0x108, %d2              | NGH, « 68k program header »
        moveq   #0, %d4                 | %d4 : chaque slot j < k déjà occupé
8:      cmp.w   %d1, %d4
        bhs.s   9f
        btst    %d4, %d5
        beq.s   1f
        move.w  %d4, %d3
        add.w   %d3, %d3
        cmp.w   (%sp,%d3.w), %d2
        beq.s   2f                      | même NGH qu'un slot d'avant : vide
1:      addq.w  #1, %d4
        bra.s   8b
9:      bset    %d1, %d5
        move.w  %d1, %d3
        add.w   %d3, %d3
        move.w  %d2, (%sp,%d3.w)
2:      addq.w  #1, %d1
        cmp.w   %d6, %d1
        blo.s   _slots_parcourir
        move.b  %d0, 0x3A000B           | REG_BRDFIX, mesuré après le parcours : la police de la carte

        | LA TABLE, HUIT ENTRÉES, l'entrée k pour le slot k (mesuré ; « Slot-N NGH number and
        | bram game block ID », « Backup RAM »). Mesuré, à l'octet :
        |   - slot vide, ou au-delà des slots de la carte : $0000 / $FFFF ;
        |   - slot dont l'entrée porte déjà ce NGH et un bloc : réécrite à l'identique ;
        |   - slot nouveau : NGH / $FFFF, le bloc venant juste avant sa demande 0, plus bas.
        | SUPPOSÉ : un NGH qui n'est plus celui de l'entrée fait un slot nouveau, et une
        | cartouche retirée perd son bloc (son entrée redevient vide). Rien de mesuré sur une
        | cartouche changée de slot ou retirée.
        lea     0xD00124, %a0
        moveq   #0, %d1
_slots_ecrire:
        btst    %d1, %d5
        beq.s   3f                      | vide
        move.w  %d1, %d2
        add.w   %d2, %d2
        move.w  (%sp,%d2.w), %d2        | NGH du slot
        cmp.w   (%a0), %d2
        bne.s   4f
        cmpi.w  #0xFFFF, 2(%a0)
        beq.s   4f
        move.w  %d2, (%a0)+             | connu : NGH, puis son bloc, à l'identique
        move.w  (%a0), (%a0)+
        bra.s   5f
4:      move.w  %d2, (%a0)+             | nouveau
        move.w  #0xFFFF, (%a0)+
        bra.s   5f
3:      clr.w   (%a0)+                  | vide
        move.w  #0xFFFF, (%a0)+
5:      addq.w  #1, %d1
        cmpi.w  #8, %d1
        blo.s   _slots_ecrire
        lea     16(%sp), %sp

        | LE PREMIER SLOT OCCUPÉ, %d1, et $D00058. Mesuré sur la référence, à chaque boot
        | (NVRAM neuve et gardée) : $D00058 ← $FF au début du parcours, puis ← le numéro du
        | premier slot occupé (0 avec puzzledp au slot 0 ; 2 avec aof seul au slot 2, relevé
        | du 2026-10-22). « Backup RAM » : « First slot number with a boot logo flag to 0 ».
        | Aucun occupé : $FF reste, et aucun slot n'est servi (`_sans_cartouche`, plus bas).
        | SYSTEM_RETURN relit $D00058 pour revenir à ce slot après les demandes 0 (`_sysret_init`).
        moveq   #0, %d1
        move.b  #0xFF, 0xD00058
        tst.b   %d5
        beq.s   _slots_aucun
6:      btst    %d1, %d5
        bne.s   5f
        addq.w  #1, %d1
        bra.s   6b
5:      move.b  %d1, 0xD00058

        | LE SLOT SERVI AU BOOT : le premier slot NOUVEAU (occupé, bloc $FFFF : il recevra son
        | bloc et sa demande 0), sinon le premier occupé. Mesuré sur la référence, 4
        | cartouches toutes nouvelles : les demandes 0 vont aux slots 0, 1, 2, 3 dans l'ordre
        | (`measured/2026-10-21-multi-slot.tsv`, c4-neuf) ; toutes connues : la demande 2 au
        | premier occupé (c4-suite). SUPPOSÉ, rien de mesuré : un slot connu avant un slot
        | nouveau ne passe pas d'abord — les nouveaux d'abord, puis le retour au premier
        | occupé, comme quand tous sont nouveaux.
7:      bsr     _premier_nouveau
        cmpi.w  #8, %d2
        bhs.s   8f
        move.w  %d2, %d1                | un nouveau : servi d'abord
8:      move.b  %d1, 0xD00108           | « Selected slot number (start at 0) »
        move.b  %d1, 0x380021           | REG_SLOT
        | AUCUN SLOT OCCUPÉ : $D00108 et REG_SLOT restent au dernier slot parcouru, comme la
        | référence (mesuré, ng_mv1 sans cartouche, `bench/multislot.lua`, MS_SUIVRE : $D00108
        | = $01, dernier REG_SLOT $01, $D00058 = $FF, table vide).
_slots_aucun:
        move.b  %d0, 0x3A000D           | REG_SRAMLOCK

        | L'ÉCRAN DE BOOT, une fois par mise sous tension (`ecran.s`) : environ trois secondes,
        | sautable par un bouton. SYSTEM_RETURN et la pièce partent plus bas et n'y passent pas.
        jsr     _ecran_boot

        | AUCUNE CARTOUCHE ($D00058 = $FF) : la main n'est remise à aucun slot. Jusqu'au
        | 2026-10-24, le slot 0 vide était servi : inscrit, demande 0 à $000122, le jeu absent
        | exécutait ce que rend le slot vide, et le watchdog relançait la carte 8 trames plus
        | tard — un boot en boucle, toutes les 192 trames sur ng_mv1 (mesuré, `bus-flottant.lua`,
        | BF_LIBRE, images d'avant et d'après le correctif). La référence, elle, garde la main et
        | affiche ses écrans de test sans un reset (mesuré, ng_mv1, -bios euro, `matrice.sh`,
        | captures ; `multislot.lua` : aucune lecture de $000122 sur 700 trames). Ici, les
        | autotests (`tests.s`), en boucle : START ou EXIT y ramènent. Sous REG_BRDFIX et
        | REG_SWPBIOS, que la détection a laissés ; le Z80 reste garé ; la backup RAM rouverte
        | pour son test, non destructif.
        cmpi.b  #0xFF, 0xD00058
        beq     _sans_cartouche

        | LA POIGNÉE DE MAIN DU SON. Jusqu'ici le Z80 exécute la SM1 de la carte, que
        | REG_BRDFIX vient de choisir ; sans ce qui suit, le jeu enverrait ses commandes à ce
        | pilote-là et non au sien, que rien ne sélectionne ni ne démarre.
        |
        | Mesuré (`protocole.md`, trace 2) : la référence écrit $01 sur $320000 (234,38),
        | relit le port (234,38 et 237,50), écrit $03 (237,51), puis remet la main à
        | $000122 (237,89). Lu (« 68k/Z80 communication ») : $01 est envoyé « just before
        | the slot is switched » — le pilote coupe le son, se met en boucle en RAM et répond
        | $01 —, et $03 demande un reset du Z80, « No reply is expected ». Lu (« Memory
        | mapped registers ») : REG_SOUND se lit pour la réponse du Z80, et REG_CRTFIX
        | ($3A001B) choisit « the cart's S ROM and M1 ROM ».
        |
        | SUPPOSÉ : que la bascule de ROM du Z80 soit REG_CRTFIX et tombe entre l'écho de $01
        | et $03. Le relevé ne suit pas $3A001B ; c'est la seule place que la page laisse —
        | après l'écho, avant le reset qui fait démarrer le Z80 sur la nouvelle ROM.
        |
        | L'ÉCHO EST LU UNE TRAME APRÈS CHAQUE ENVOI (`.Lsync`, plus bas), comme `menu.s` et
        | `jukebox.s` : lu dans la boucle même, une réponse précédente du pilote déjà à $01
        | passerait pour lui. On renvoie $01 à chaque trame, 60 fois au plus, soit ~1 s (la
        | borne d'avant, mesurée au banc avec un écho rendu impossible : $03 à 60,0 trames,
        | sans reset du watchdog ; la forme a changé, pas le compte). Puis UNE TRAME ENTRE
        | L'ÉCHO ET REG_CRTFIX, pour que le pilote soit entré dans sa boucle en RAM avant que sa
        | ROM change : mesuré chez la référence, ~3 trames entre son $01 et son $03
        | (`protocole.md`, trace 2 : 234,38 puis 237,51). SUPPOSÉ, trois choix :
        |   - le renvoi : notre boot écrit $01 trois secondes environ après le reset (l'écran de
        |     `ecran.s`, moins s'il est sauté),
        |     quand la référence attend la trame 234 ; un pilote qui n'aurait pas encore armé
        |     son NMI perdrait un envoi unique ;
        |   - la seconde : aucune page lue ne chiffre le délai de l'écho. « 68k/Z80
        |     communication » dit seulement que le BIOS SNK affiche « Z80 ERROR » et se bloque
        |     sans écho « in time » ;
        |   - la sortie de secours : passé la borne, on bascule et on envoie $03 quand même.
        |     Un jeu sans son vaut mieux qu'un écran figé, et le coup de pied du watchdog dans
        |     chaque tour de `.Lsync` empêche le reset de la carte pendant l'attente.
        | Un octet $01 déjà présent dans le verrou de réponse à la mise sous tension passerait
        | pour l'écho : la page ne dit pas ce qu'il vaut au reset, et le 68000 ne peut pas le
        | vider.
        |
        | Rien n'est attendu après $03 : la page n'en prévoit aucune réponse, et la référence
        | ne relit pas le port avant sa remise. Elle laisse 0,38 trame au Z80, nous
        | presque rien — ~500 périodes de 48 MHz au banc ; le reset doit tenir sous 100 ms
        | selon la même page, et c'est au jeu de ne pas parler à son pilote avant.
        | `wjammers` envoie sa première commande à la trame 9, mesuré au banc.
        |
        | Cette poignée de main est LE PASSAGE DE SLOT (`_passer_au_slot`, plus bas), le même
        | qu'entre deux demandes 0 : au boot, il passe au slot que la détection vient de choisir.
        | AU BOOT, SANS LE $01 NI SON ÉCHO : le Z80 est garé depuis la détection, avant l'écran
        | (`_garer_z80_vite`, depuis le retour du matériel du 2026-10-24), et REG_BRDFIX
        | l'a laissé dans sa boucle en RAM. Mesuré sur la référence (`measured/2026-10-24-slot-
        | crtfix.tsv`, trois runs) : après son parcours, elle écrit REG_SLOT, REG_CRTFIX,
        | REG_SWPROM et $03 sans renvoyer $01.
        | UNE TRAME D'ATTENTE, pour garder le chronométrage du boot des images d'avant, sur
        | lequel reposent la matrice et les scènes du parcours : la poignée de main en prenait
        | deux ici, le garage du boot en prend une sous MAME (écho dans la trame 1), et la remise
        | retombe ainsi à la trame 188 sur aof, comme l'image de main (mesuré,
        | `bench/bus-flottant.lua`, BF_LIBRE). Sans attente, elle venait deux trames plus tôt
        | et aof, kof94, garou changeaient de vifs_max ; avec le Z80 garé deux fois, deux trames
        | plus tard, et les scènes gs-fois et aes-texte échouaient. Sur le matériel, le délai de
        | l'écho n'est pas mesuré : seul le moment de la remise en dépend, pas sa justesse.
        bsr     .Lsync
        moveq   #0, %d1
        move.b  0xD00108, %d1           | le slot servi (l'écran de boot a pu prendre %d1)
        bsr     _passer_au_slot_gare

        | LA MAIN AU JEU, PAR LA DEMANDE 0 — INITIALISATION. $000122 porte un `jmp` de 6
        | octets vers la routine USER (« 68k program header » : « JMP to USER subroutine
        | (code start) »), qui lit sa demande dans $10FDAE (« USER subroutine »).
        |
        | POURQUOI 0. « USER subroutine » : la demande 0 pose les données par défaut de la
        | RAM de sauvegarde, et sur MVS ne court que « the first time the game starts on a
        | system ». La demande 1 (animation de boot) n'est pas ici : la page la dit appelée
        | par défaut sur AES seulement ; en mode AES, `_logo_aes` la donne avant la démo.
        |
        | « LA PREMIÈRE FOIS » SE LIT DANS LA TABLE DES SLOTS, mesuré
        | (`measured/2026-10-16-demande-0-slots.tsv`, kof98, puis
        | `measured/2026-10-21-multi-slot.tsv`) : l'entrée du slot servi porte un bloc au
        | boot suivant, demande 2 mode 1 ; elle n'en porte pas ($FFFF, posé par la détection
        | plus haut) au premier boot, et la référence lui donne alors son bloc juste avant la
        | demande 0 — le plus petit bloc (0-7) qu'aucune entrée ne porte, mesuré (run « trou »,
        | slots 0 et 2 : blocs 0 et 1). kof98 finit sa demande 0 par un reset voulu : la
        | rappeler à chaque boot le fait boucler.
        |
        | LES AUTRES SLOTS NOUVEAUX suivent, un par un : le jeu finit sa demande 0 par
        | SYSTEM_RETURN, dont le code 0 passe au slot nouveau suivant (`_sysret_init`).
        move.b  %d0, 0x3A001D           | REG_SRAMUNLOCK
        moveq   #0, %d1
        move.b  0xD00108, %d1           | le slot servi
        lsl.w   #2, %d1
        lea     0xD00124, %a0
        adda.w  %d1, %a0                | %a0 : son entrée
        cmpi.w  #0xFFFF, 2(%a0)
        bne.s   _slot_present
        bsr     _inscrire_slot
        | L'ÉDITEUR DE SOFT-DIP (`dip.s`), si le bouton TEST est tenu : %a1 pointe juste après
        | le bloc, la backup RAM est encore ouverte. Sinon, un test et un retour. %a3 : l'index
        | de l'entrée du jeu — une région changée la rend libre avant de relancer la machine,
        | pour que le boot suivant refasse un premier boot. Au boot seulement : les slots
        | nouveaux que SYSTEM_RETURN enchaîne n'y passent pas, SUPPOSÉ (un TEST tenu ne
        | rouvrirait l'éditeur qu'au slot servi au boot). %d6 = 1 : le slot vient d'être
        | inscrit, sa demande 0 n'a pas eu lieu (un mode changé libère alors son entrée).
        moveq   #1, %d6
        jsr     _editeur_dip
        move.b  %d0, 0x3A000D           | REG_SRAMLOCK
        bra     _remettre_a_user_init   | `bra` : SYSTEM_RETURN, plus long, l'éloigne

        | PRÉSENT : demande 2, mode 1, mesuré au boot suivant de la référence ($10FDAF ←
        | $01, $10FDAE = $02) — la même remise que la fin d'une démo (`_sysret_demo`).
        | LA RESTAURATION DE SA SAUVEGARDE, une cartouche seule comprise. Mesuré
        | (`bench/multislot.lua`, `MS_PLAGES`, référence, NVRAM gardée, 1, 2 et 4 cartouches,
        | le 2026-10-22 ; une cartouche : puzzledp, nam1975, aof, mslug) : avant sa première
        | demande 2, la référence recopie le bloc de sauvegarde du slot servi dans la RAM de
        | travail du jeu (`_restaurer_jeu`). Ce bloc a toujours été sauvé avant : un slot
        | n'a de bloc qu'après sa demande 0, que suit sa sauvegarde (`_sysret_init`).
        | APRÈS L'ÉDITEUR, juste avant la remise, comme la référence : WORK RAM (`tests.s`)
        | écrit la RAM de travail, et une restauration
        | faite avant laissait au jeu une zone détruite, sauvée à la fin de sa démo (mesuré,
        | `measured/2026-10-28-work-ram-restauree.tsv`). Puis les debug dips reposés
        | (`_dd_poser`, `debug.s`) : la restauration écrasait ceux que l'éditeur venait de poser.
_slot_present:
        bsr     _relire_dip
        moveq   #0, %d6                 | un slot connu : son entrée reste à un mode changé
        jsr     _editeur_dip            | comme plus haut : %a1 juste après le bloc
        move.b  %d0, 0x3A000D           | REG_SRAMLOCK
        moveq   #0, %d1
        move.b  0xD00108, %d1
        bsr     _restaurer_jeu
        jsr     _dd_poser               | registres rendus
        move.b  #0x02, 0x10FD81         | BIOS_SYSRET_STATUS, mesuré : voir `_sysret_demo`
        moveq   #1, %d1                 | BIOS_USER_MODE    = titre / démo
        moveq   #2, %d2                 | BIOS_USER_REQUEST = démo
        moveq   #0, %d3                 | pas de REG_SOUND de plus : celui du passage, au boot
        bra     _remettre_a_user

| AUCUNE CARTOUCHE : les autotests, sans fin (voir l'appel, après `_ecran_boot`).
_sans_cartouche:
        move.b  %d0, 0x3A001D           | REG_SRAMUNLOCK, pour le test de la backup RAM
1:      jsr     _autotests              | registres rendus
        bra.s   1b

| ----------------------------------------------------------------------------------
| L'INSCRIPTION D'UN SLOT NOUVEAU — son bloc, ses cellules, ses soft-DIP. Appelée par le
| boot et par SYSTEM_RETURN (`_sysret_init`), le slot déjà passé (`_passer_au_slot` : sa
| P-ROM est en place) et la backup RAM déverrouillée.
|
| Entrée : %a0 = son entrée de $D00124. Sortie : %a3 = l'adresse de l'index de l'entrée,
| %a1 = juste après le bloc de sauvegarde, pour `dip.s`. Clobbers %d1-%d5, %a0, %a2.
|
| CE QUE LA RÉFÉRENCE ÉCRIT POUR UN SLOT NOUVEAU, mesuré (`bench/multislot.lua`, -bios
| euro, NVRAM neuve, 4 cartouches puis slots 0 et 2 seuls, le 2026-10-22 ; b = l'index de
| bloc) : l'index dans l'entrée, $D0011A + b ← $00, $D00200 + 4 × b ← quatre $00 (run
| « trou » : le slot 2 a le bloc 1 et c'est $D0011B qui est écrit — l'index est celui du
| bloc, pas du slot), puis, la cartouche en place, $D002A0 + 16 × b ← seize octets : le
| nom du jeu (« PUZZLE DE PON!  », « ART OF FIGHTING », « NAM-1975 », « METAL SLUG »),
| que « Software DIPs » met en $00-$0F du bloc soft-DIP ; et au retour de la demande 0,
| $D00220 + 16 × b ← GAME_DIP. Le sens de $D0011A + b et de $D00200 + 4 × b n'est écrit
| dans aucune page lue ; aucun des 22 jeux du corpus ne lit $D00058, $D00104-$D00107,
| $D0011A-$D00121, $D00144-$D001A3 ni $D00200-$D0031F (mesuré, même jig, `MS_LECT_JEU`,
| un jeu seul, 4 000 trames dont une partie : seuls $D00034-$D00035, $D00046-$D00047,
| $D00100-$D00101, $D00108 et la table $D00124+ sont lus).
| Écart voulu : GAME_DIP part dans le bloc AVANT la demande 0 et non à son retour —
| l'éditeur de soft-DIP en a besoin avant la remise, et le décodage est celui qui a été
| mesuré égal à la référence à la remise (22 jeux).
| Non écrits, SUPPOSÉ sans effet (aucun lecteur au corpus) : la date $D00104 (NVRAM
| neuve) et $D00144 + 4 × k (chaque slot occupé, à chaque boot), qui demandent le
| calendrier ; $D00164-$D001A3. Ce que la référence écrit en $D00320 et au-delà au retour
| d'une demande 0 n'est pas un effacement : c'est la sauvegarde du jeu (`_sauver_jeu`).
| ----------------------------------------------------------------------------------
_inscrire_slot:
        | %d3, un bit par bloc pris ; %d1, le plus petit libre.
        lea     0xD00124, %a1
        moveq   #0, %d3
        moveq   #8-1, %d2
1:      move.w  2(%a1), %d4
        addq.l  #4, %a1
        cmpi.w  #0xFFFF, %d4
        beq.s   2f
        bset    %d4, %d3                | 0-7 : la table a été validée
2:      dbra    %d2, 1b
        moveq   #0, %d1
3:      btst    %d1, %d3
        beq.s   4f
        addq.w  #1, %d1
        bra.s   3b
4:      lea     2(%a0), %a3             | %a3 : l'index de l'entrée inscrite, pour `dip.s`
        move.w  %d1, (%a3)
        lea     0xD0011A, %a1
        clr.b   (%a1,%d1.w)             | $D0011A + b ← $00, mesuré
        move.w  %d1, %d3
        lsl.w   #2, %d3
        lea     0xD00200, %a1
        clr.l   (%a1,%d3.w)             | $D00200 + 4 × b ← $00 × 4, mesuré
        move.w  %d1, %d3
        lsl.w   #4, %d3                 | %d3 : 16 × b, pour le nom
_slot_inscrit:
        | LES SOFT-DIP AU PREMIER BOOT, mesuré (`measured/2026-10-16-soft-dip.tsv`, quatre
        | jeux) : BIOS_GAME_DIP ($10FD84-$10FD93, « BIOS RAM locations », écrit par le BIOS)
        | se décode du bloc soft-DIP de la cartouche — octets $10-$15 tels quels, puis le
        | quartet haut de $16-$1F —, puis le BIOS le recopie dans le bloc de sauvegarde du
        | jeu, $D00220 + 16 × index. Lu dans « Software DIPs » : $10-$15, deux temps en mot
        | et deux comptes en octet ; $16-$1F, dix réglages, choix par défaut dans le quartet
        | haut, nombre de choix dans le bas. Après le vidage de $10F300-$10FFFF, qui sinon
        | les effacerait ; backup RAM encore déverrouillée.
        |
        | LA RÉGION. Lu dans « 68k program header » : pointeurs longs Japon $116, USA $11A,
        | Europe $11E. Mesuré : l'Europe seule, l'image déclarant l'Europe. SUPPOSÉ : le
        | pointeur suit BIOS_COUNTRY_CODE (0, 1, 2 → $116 + 4 × code), un code hors de 0-2
        | prenant l'Europe. Le pointeur espagnol ($18E, même page) n'est pas lu.
        |
        | LES DEUX ZONES DE LA P-ROM. Lu dans « 68k memory map » : $000000-$0FFFFF, la
        | première banque fixe ; $200000-$2FFFFF, la seconde, « also used for bankswitching ».
        | Un bloc de $20 octets est accepté s'il tient entier dans l'une ou l'autre. Mesuré
        | (MAME, 22 jeux, le 2026-10-21) : mslug seul pointe dans la seconde, à $2783D0, et
        | la référence l'y décode comme les autres.
        |
        | LA BANQUE EN PLACE, celle qu'on lit : on n'écrit aucun registre de banque. Lu dans
        | « Bankswitching » : une écriture dans $200000-$2FFFFF change la banque, et « When
        | the system is reset, both latches are reset to 0, to ensure that the first bank is
        | mapped on startup » ; ce boot n'écrit rien dans cette zone avant d'ici, il lit donc
        | la première banque. Mesuré sur mslug, sous la référence comme sous nous : les 32
        | octets lus à $2783D0, à la trame 1 et à la remise, sont ceux du MiB que MAME sert
        | au boot (la région du jeu à $100000). SUPPOSÉ : que la page, écrite pour la carte
        | PROGBK1, vaille pour les autres cartes à banques, et pour le reset du watchdog ;
        | et qu'une lecture dans cette zone ne déclenche rien chez une puce spéciale.
        |
        | LE POINTEUR REFUSÉ. SUPPOSÉ, aucune page ne le traite : nul, ou un bloc qui déborde
        | de sa zone, ou hors de $000000-$2FFFFF. Refusé, GAME_DIP reste à zéro — remis à
        | zéro ici : au boot le vidage l'y a déjà mis, mais entre deux demandes 0 il porte
        | celui du slot d'avant —, et ces zéros partent quand même dans le bloc ; le nom
        | n'est pas écrit. Un pointeur impair est accepté : tout est lu par octet, sans
        | erreur d'adresse possible.
        lsl.w   #4, %d1                 | 16 × index, $70 au plus
        lea     0xD00220, %a1
        adda.w  %d1, %a1                | %a1 : le bloc de sauvegarde du jeu
        lea     0x10FD84, %a0           | %a0 : BIOS_GAME_DIP
        clr.l   (%a0)
        clr.l   4(%a0)
        clr.l   8(%a0)
        clr.l   12(%a0)
        moveq   #0, %d4
        move.b  0x10FD83, %d4           | BIOS_COUNTRY_CODE
        cmpi.b  #2, %d4
        bls.s   1f
        moveq   #2, %d4                 | hors de 0-2 : l'Europe
1:      lsl.w   #2, %d4
        lea     0x116, %a2
        move.l  (%a2,%d4.w), %d4        | pointeur du bloc soft-DIP de la région
        beq.s   _dip_copier             | nul : refusé
        cmpi.l  #0x100000 - 0x20, %d4
        bls.s   4f                      | tient dans la P-ROM fixe
        cmpi.l  #0x200000, %d4
        blo.s   _dip_copier             | déborde la P-ROM fixe, ou entre les zones : refusé
        cmpi.l  #0x300000 - 0x20, %d4
        bhi.s   _dip_copier             | déborde la zone banquée, ou au-delà : refusé
4:      movea.l %d4, %a2
        lea     0xD002A0, %a0
        adda.w  %d3, %a0                | $D002A0 + 16 × b
        moveq   #16-1, %d5
5:      move.b  (%a2)+, (%a0)+          | $00-$0F : le nom du jeu, mesuré (voir l'en-tête)
        dbra    %d5, 5b
        lea     0x10FD84, %a0           | %a0 : BIOS_GAME_DIP ; %a2 : le bloc + $10
        moveq   #6-1, %d5
2:      move.b  (%a2)+, (%a0)+          | temps et comptes, tels quels
        dbra    %d5, 2b
        moveq   #10-1, %d5
3:      move.b  (%a2)+, %d4
        lsr.b   #4, %d4                 | le choix par défaut, quartet haut
        move.b  %d4, (%a0)+
        dbra    %d5, 3b
_dip_copier:
        lea     0x10FD84, %a0
        move.l  (%a0)+, (%a1)+          | GAME_DIP → bloc de sauvegarde, 16 octets
        move.l  (%a0)+, (%a1)+
        move.l  (%a0)+, (%a1)+
        move.l  (%a0)+, (%a1)+
        rts

| ----------------------------------------------------------------------------------
| LA RELECTURE D'UN SLOT CONNU — son bloc de sauvegarde vers GAME_DIP. Appelée par le boot
| (`_slot_present`) et par SYSTEM_RETURN au retour au premier slot (`_sysret_init`) et à
| la rotation de la démo (`_sysret_rotation`).
|
| Entrée : %a0 = l'entrée de $D00124. Sortie : %a3 = l'adresse de l'index de l'entrée,
| %a1 = juste après le bloc, pour `dip.s`. Clobbers %d1, %a0.
|
| BIOS_GAME_DIP relu du bloc de sauvegarde, mesuré (relevé soft-DIP, kof98 : une valeur
| posée dans le bloc ressort dans GAME_DIP). Ni borne ni contrôle des valeurs relues :
| « Software DIPs » ne dit pas que le BIOS les valide. L'index est 0-7, la table ayant été
| validée ; un $FFFF (entrée sans bloc) laisse GAME_DIP tel quel, SUPPOSÉ sans chemin qui
| y mène. VALIDÉ DEPUIS LE 2026-10-27 (DECISIONS §23 pt 5, décision de l'utilisateur) :
| relu, GAME_DIP passe par `_dip_valider` (`dip.s`), qui remet chaque valeur hors de ses bornes
| au défaut de la cartouche, comme l'éditeur ; un bloc quelconque était servi tel quel au jeu. Au retour au premier slot, GAME_DIP porte celui du dernier slot inscrit : le
| relire est SUPPOSÉ (la référence n'a pas été relevée sur $10FD84 à ce moment), mais
| c'est ce que fait le boot suivant, mesuré.
| ----------------------------------------------------------------------------------
_relire_dip:
        lea     2(%a0), %a3             | %a3 : l'index de l'entrée du jeu, pour `dip.s`
        move.w  2(%a0), %d1             | index du bloc
        cmpi.w  #0xFFFF, %d1
        beq.s   9f
        lsl.w   #4, %d1
        lea     0xD00220, %a1
        adda.w  %d1, %a1
        lea     0x10FD84, %a0
        move.l  (%a1)+, (%a0)+          | bloc de sauvegarde → GAME_DIP, 16 octets
        move.l  (%a1)+, (%a0)+
        move.l  (%a1)+, (%a0)+
        move.l  (%a1)+, (%a0)+
        jsr     _dip_valider            | registres rendus
9:      rts

| ----------------------------------------------------------------------------------
| LE PREMIER SLOT NOUVEAU — la première entrée de $D00124 qui porte un NGH et pas de bloc
| ($FFFF), celle que la détection a posée pour une cartouche que la table ne connaissait
| pas. Sortie : %d2 = son numéro, 8 s'il n'y en a pas ; %a0 = son entrée. Clobbers
| rien d'autre. Un NGH $0000 est une entrée vide (« Backup RAM »).
| ----------------------------------------------------------------------------------
_premier_nouveau:
        lea     0xD00124, %a0
        moveq   #0, %d2
1:      tst.w   (%a0)
        beq.s   2f                      | vide
        cmpi.w  #0xFFFF, 2(%a0)
        beq.s   9f                      | nouveau
2:      addq.l  #4, %a0
        addq.w  #1, %d2
        cmpi.w  #8, %d2
        blo.s   1b
9:      rts

| ----------------------------------------------------------------------------------
| LE SLOT OCCUPÉ SUIVANT — %d1 = le premier slot après $D00108 dont l'entrée porte un NGH,
| en bouclant après le slot 7 ; le slot courant lui-même s'il est le seul. Mesuré sur la
| référence (`measured/2026-10-21-multi-slot.tsv`, synthèse point 4, et le relevé de ce lot) :
| 0 → 1 → 2 → 3 → 0 avec quatre cartouches, 0 → 2 → 0 avec le slot 1 vide (run « trou »).
| LE SLOT OCCUPÉ PRÉCÉDENT (`_slot_precedent`), pour SELECT P2 : le même parcours à
| rebours. Mesuré sur la référence (`measured/2026-10-22-multi-slot-lot4.tsv`, slots 0, 2
| et 3 occupés) : 0 → 3 → 2 → 0, le slot 1 sauté, le bouclage passant par 7 à 4 vides.
| Clobbers %d2, %d3, %d5, %a1.
| ----------------------------------------------------------------------------------
        .global _slot_suivant
_slot_precedent:
        moveq   #-1, %d5
        bra.s   _slot_voisin
_slot_suivant:
        moveq   #1, %d5
_slot_voisin:
        moveq   #0, %d1
        move.b  0xD00108, %d1
        lea     0xD00124, %a1
        moveq   #8-1-1, %d3             | les sept autres entrées au plus
1:      add.w   %d5, %d1
        andi.w  #7, %d1
        move.w  %d1, %d2
        lsl.w   #2, %d2
        tst.w   (%a1,%d2.w)
        dbne    %d3, 1b
        bne.s   9f
        move.b  0xD00108, %d1           | aucun autre : le slot courant
9:      rts

| ----------------------------------------------------------------------------------
| LA SAUVEGARDE D'UN JEU — sa zone de RAM de travail recopiée dans son bloc de la backup
| RAM (`_sauver_jeu`), ou l'inverse (`_restaurer_jeu`). Entrée : %d1 = le slot, dont la
| P-ROM est en place (l'en-tête lu est le sien). Clobbers %d2, %d3, %a0, %a1.
|
| MESURÉ sur la référence (`bench/multislot.lua`, `MS_PLAGES`, -bios euro, MV-6F, 1, 2 et
| 4 cartouches et slots 0 et 2, NVRAM neuve puis gardée, le 2026-10-22 ; adresses, tailles
| et sommes des octets recopiés, aucun octet du BIOS) :
|   - LA ZONE DU JEU : le pointeur long de $00010E et la taille en octets du mot de
|     $000112, lus dans l'en-tête de sa cartouche (« 68k program header » les nomme) ;
|     recopiée telle quelle, pointeur compris : puzzledp $100000 + $100, aof $108800 + $800,
|     nam1975 $100000 + $1000, mslug $100000 + $7E — 256, 2 048, 4 096 et 126 octets ;
|   - LE BLOC : $D00320 + $1000 × b, b l'index de bloc de l'entrée de $D00124 et non le
|     numéro de slot (« trou » : le slot 2 a le bloc 1 et sa sauvegarde va en $D01320) ;
|   - LA SAUVEGARDE suit chaque SYSTEM_RETURN qui quitte le jeu, sa P-ROM encore en place :
|     au retour de sa demande 0 (code 0), à la fin de sa démo (code 2) et à la fin d'une
|     partie (code 3) ; une cartouche seule comprise. Jamais à la pièce. La somme des octets
|     écrits dans le bloc est celle des octets lus dans la RAM ;
|   - LA RESTAURATION précède la demande 2 du boot et celle qui suit un code 0 ou 2 : le
|     bloc relu, recopié à son pointeur, la P-ROM du slot qui entre en place ; jamais avant
|     une demande 0, ni après une fin de partie (code 3 : sauvegarde, puis la démo ou le
|     titre sans restauration). La somme écrite dans la RAM est celle de la dernière
|     sauvegarde du même bloc. Une cartouche seule (relevé du 2026-10-22, puzzledp,
|     nam1975, aof, mslug) : code 0 et code 2, sauvegarde puis restauration du même bloc.
| SUPPOSÉ, aucune page ni mesure ne le traite : la zone est refusée — rien n'est recopié —
| si sa taille est nulle ou dépasse $1000 (l'écart entre deux blocs ; 114 en-têtes de
| romsets lus, aucun au-delà), si elle commence sous $100000, ou si elle finit
| au-delà de $10F200 : la pile de ce BIOS descend de $10F300 pendant la recopie, et la
| plus haute zone lue finit en $10F08E (rotd) — hors une ROM de raycaster périmée qui
| pointe $10F300, refusée. Un slot sans bloc ($FFFF) n'est pas recopié.
| ----------------------------------------------------------------------------------
_bloc_jeu:
        moveq   #0, %d2
        move.w  %d1, %d2
        lsl.w   #2, %d2
        lea     0xD00124, %a1
        move.w  2(%a1,%d2.w), %d2       | l'index de bloc
        cmpi.w  #8, %d2
        bhs.s   9f                      | $FFFF : pas de bloc
        moveq   #12, %d3
        lsl.l   %d3, %d2                | $1000 × b
        lea     0xD00320, %a1
        adda.l  %d2, %a1                | %a1 : le bloc
        movea.l 0x10E, %a0              | %a0 : la zone du jeu
        moveq   #0, %d2
        move.w  0x112, %d2              | sa taille
        beq.s   9f
        cmpi.w  #0x1000, %d2
        bhi.s   9f
        cmpa.l  #0x100000, %a0
        blo.s   9f
        cmpa.l  #0x10F200, %a0
        bhs.s   9f
        move.l  %a0, %d3
        add.l   %d2, %d3
        cmpi.l  #0x10F200, %d3
        bhi.s   9f
        subq.w  #1, %d2                 | le compte de `dbra`
        rts
9:      moveq   #-1, %d2                | refusée
        rts

| LES DEBUG DIPS (`debug.s`) : un masque posé ne part jamais en backup RAM — retiré de la zone le
| temps de la copie, remis après. Sans masque, le chemin d'avant et un `tst.w` de plus.
_sauver_jeu:
        bsr     _bloc_jeu
        tst.l   %d2
        bmi.s   9f
        tst.w   DD_MASQUE
        bne.s   .Lsauver_dd
.Lsauver_copie:
        move.b  %d0, 0x300001           | watchdog : 4 096 octets, ~0,45 trame au plus
        move.b  %d0, 0x3A001D           | REG_SRAMUNLOCK
1:      move.b  (%a0)+, (%a1)+
        dbra    %d2, 1b
        move.b  %d0, 0x3A000D           | REG_SRAMLOCK
9:      rts
.Lsauver_dd:
        jsr     _dd_retirer             | registres rendus
        movem.l %d2/%a0, -(%sp)
        bsr.s   .Lsauver_copie
        movem.l (%sp)+, %d2/%a0
        jmp     _dd_remettre            | registres rendus ; son `rts` est le nôtre

_restaurer_jeu:
        bsr     _bloc_jeu
        tst.l   %d2
        bmi.s   9f
        move.b  %d0, 0x300001           | watchdog
1:      move.b  (%a1)+, (%a0)+
        dbra    %d2, 1b
9:      rts

| ----------------------------------------------------------------------------------
| LE PASSAGE DE SLOT — le son garé, puis la cartouche du slot %d1 en place. Au boot,
| entre deux demandes 0 (SYSTEM_RETURN, `_sysret_init`) et à la rotation de la démo
| (`_sysret_rotation`).
|
| Entrée : %d1 = le slot (mot, 0-7). Clobbers %d0, %d4 ; %d1 et les registres d'adresse
| rendus. Revient sous REG_CRTFIX et REG_SWPROM : le Z80 repart sur la M1 du slot, la P-ROM
| du slot sert le bas de la carte.
|
| L'ORDRE, mesuré sur la référence (`measured/2026-10-21-multi-slot.tsv`, c4-neuf, trames
| 280, 282, 284-285, 288 : une fois par demande 0) : REG_SOUND ← $01, son écho, REG_SLOT ←
| k, REG_CRTFIX, REG_SWPROM, REG_SOUND ← $03, $D00108 ← k ; la remise vient à la trame
| suivante. La poignée de main est commentée au boot, plus haut (le renvoi de $01 à
| chaque trame, la trame entre l'écho et la bascule, la sortie de secours). Le Z80 doit
| être garé avant REG_SLOT : sous REG_CRTFIX, une écriture de REG_SLOT change aussitôt la
| M1 qu'il voit (mesuré, `MS_SONDE_M1`, voir la détection).
| SUPPOSÉ : l'écho lu peut être le $01 laissé dans le verrou par le pilote du slot d'avant,
| que son $03 a remis à zéro ; on basculerait alors sous un pilote pas encore garé. Le $03
| qui suit le remet à zéro sur la nouvelle M1 quoi qu'il ait fait entre-temps.
|
| LES CHEATS OUBLIÉS À CHAQUE PASSAGE (`_cheats_oublier`, `cheats.s`) : relevé de l'audit
| du 2026-10-21, ils survivaient sinon au changement de jeu, et un cheat d'un jeu écrirait
| ses valeurs dans la RAM d'un autre si les deux partageaient un NGH et une empreinte.
| ----------------------------------------------------------------------------------
_passer_au_slot:
        bsr.s   _garer_z80
_passer_au_slot_gare:                   | le Z80 déjà garé : le boot, après la détection
        move.b  %d1, 0x380021           | REG_SLOT : la cartouche du slot
        move.b  %d0, 0x3A001B           | REG_CRTFIX : S ROM et M1 de la cartouche
        move.b  %d0, 0x3A0013           | REG_SWPROM : sa P-ROM en bas de la carte
        move.b  #0x03, 0x320000         | REG_SOUND : reset du Z80, sur la M1 de la cartouche
        move.b  %d0, 0x3A001D           | REG_SRAMUNLOCK
        move.b  %d1, 0xD00108           | « Selected slot number (start at 0) »
        move.b  %d0, 0x3A000D           | REG_SRAMLOCK
        jmp     _cheats_oublier         | son `rts` rend la main à l'appelant

| LE Z80 GARÉ AU BOOT, VITE : $01, l'écho guetté en continu (`.Lsync_ou_echo`), renvoyé à
| chaque trame, 60 au plus ; puis ~3 000 tours (~2,5 ms) pour que le pilote entre dans sa
| boucle en RAM — SUPPOSÉ suffisant, aucune page ne chiffre ce délai. Clobbers %d0, %d4.
_garer_z80_vite:
        moveq   #60-1, %d4
1:      move.b  #0x01, 0x320000         | REG_SOUND : préparer la bascule
        bsr     .Lsync_ou_echo          | Z : l'écho vu
        dbeq    %d4, 1b
        move.w  #3000-1, %d4
2:      move.b  %d0, 0x300001           | watchdog
        dbra    %d4, 2b
        rts

| LE Z80 GARÉ EN RAM : $01 et son écho, puis une trame. Pour le passage de slot ci-dessus et
| pour la détection des emplacements, au boot. Clobbers %d0, %d4.
_garer_z80:
        moveq   #60-1, %d4              | au plus 60 envois de $01
_son_envoi:
        move.b  #0x01, 0x320000         | REG_SOUND : préparer la bascule
        bsr     .Lsync                  | une trame
        cmpi.b  #0x01, 0x320000         | l'écho de $01 ?
        dbeq    %d4, _son_envoi
        bra     .Lsync                  | une trame pour que le pilote entre en boucle

| ----------------------------------------------------------------------------------
| SYSTEM_RETURN — le jeu y saute quand sa routine USER a fini.
|
| « SYSTEM_RETURN » dit seulement que la cartouche y saute à la fin de sa routine USER.
| Ce n'est pas un retour de sous-programme : la pile porte encore les cadres que la
| cartouche a abandonnés, donc on la rebâtit.
|
| C'EST UN DISPATCH. « BIOS RAM locations », $10FD81 BIOS_SYSRET_STATUS : « Internal
| value which stores the function code that SYSTEM_RETURN will call », codes 0 à 6.
| Chez nous, qui l'écrit (lu dans le code) : le vidage du boot (0), le START avec
| crédit de `io.s` (3), le SELECT de `io.s` (4, 5), le passage au titre (2, plus bas), de
| SYSTEM_RETURN, d'une pièce ou d'une sélection, et chaque remise en démo (2,
| `_sysret_demo` et le boot).
| Personne n'écrit 6, et ce lot n'y ajoute pas d'écrivain : à la
| pièce, la référence écrit $02 et non $06 (`appel_C00438.md`, 2/41 appels, avec la
| demande 3), et aucun contrat ne montre $06. Le code 6 est donc servi pour un jeu qui
| poserait lui-même la valeur, pas atteint par notre BIOS.
|
| LE CODE 0 ENCHAÎNE LES DEMANDES 0 (`_sysret_init`), LE CODE 2 FAIT TOURNER LA DÉMO
| (`_sysret_rotation`). Les codes 4 et 5 et 1 (EL-LED) retombent sur le slot courant : la
| démo, sans changer de slot. La sélection, qui pose 4 et 5, ne passe pas par ici (mesuré :
| la référence ne la fait pas entrer par $C00444 ; `_retour_selection`). SUPPOSÉ, comme le
| traitement d'une valeur hors de 0-6 : le même chemin, celui qui ne fait que relancer la
| démo.
|
| LA SALVE SON $01/$03 : celle du passage de slot (`_passer_au_slot`), aux codes 0 et 2
| seulement et quand le slot change. Mesuré (`protocole.md`, trace 2, 239,41), la référence la fait
| aussi après la demande 0 d'une cartouche seule (le retour au slot 0 pour son logo,
| `measured/2026-10-21-multi-slot.tsv`, synthèse point 4) : pas ici, le logo n'étant pas
| écrit, et le slot ne changeant pas. Le $03 seul qui précède une demande 3 est repris
| plus bas.
| ----------------------------------------------------------------------------------
_retour_systeme:
        move.w  #0x2700, %sr
        move.l  #0x10F300, %sp
        bsr.s   _sysret_etat            | %d4 : le code ; partagé avec `_retour_demo_end`
        cmpi.b  #3, %d4
        beq     _sysret_fin_partie
        cmpi.b  #6, %d4
        beq     _sysret_piece
        cmpi.b  #2, %d4
        beq     _sysret_rotation
        cmpi.b  #1, %d4
        beq     _sysret_logo
        tst.b   %d4
        bne     _sysret_demo
        bra     _sysret_init

| L'ÉTAT DE L'ENTRÉE DE SYSTEM_RETURN, en sous-routine pour servir aussi après DEMO_END
| (`_retour_demo_end`). Sortie : %d4 = BIOS_SYSRET_STATUS, %d3 = ce qui part dans
| BIOS_SYSTEM_MODE. IRQ masquées et pile posée par l'appelant.
_sysret_etat:
        | LE CODE, LU UNE FOIS. %d3 : la valeur de BIOS_SYSTEM_MODE, mesurée par appel
        | (`appel_C00444.md`) — $00 sur l'appel du boot, code 0, et $02 sur le game over,
        | code 3 (l'attribution d'un code à chaque appel est lue, pas mesurée). Le bit 1
        | n'est décrit nulle part ; SUPPOSÉ : $02 aussi pour le code 6, l'autre code
        | d'après partie ou pièce, $00 pour tous les autres hors du code 2.
        | LE CODE 2 PORTE $02 AUSSI. MESURÉ sous MAME le 2026-10-23 (-bios euro, nam1975, fin
        | de démo à 8753 ; `measured/2026-10-23-led-et-remises.tsv`, section 3) : $10FD80 ← $02
        | à l'entrée, puis $02 encore avant la remise de la démo ; le code 0 du boot, $00.
        | Notre image posait $00 au code 2.
        move.b  0x10FD81, %d4           | BIOS_SYSRET_STATUS
        moveq   #0, %d3
        cmpi.b  #2, %d4
        beq.s   1f
        cmpi.b  #3, %d4
        beq.s   1f
        cmpi.b  #6, %d4
        bne.s   2f
1:      moveq   #2, %d3

        | L'ÉTAT DU CONTRAT, commun aux deux appels mesurés (`appel_C00444.md`, noyau).
        | `_sysret_etat_mode` : l'entrée de SELECT (`_retour_selection`), %d3 posé par lui.
2:
_sysret_etat_mode:
        move.b  %d3, 0x10FD80           | BIOS_SYSTEM_MODE : bit 7 à 0, le BIOS a le vblank
        | BIOS_FRAME_SKIP ← $FF, mesuré ; il survit à la remise d'une demande 0, et celle
        | d'une demande 2 ou 3 le pose à $09 (`_remettre_a_user`).
        move.b  #0xFF, 0x10FEE1
        | $10FE8C ← $01, mesuré, valeur unique ; aucune page ne nomme l'adresse. INT1 le
        | repose à $00 à chaque appel (`int1.s`).
        move.b  #0x01, 0x10FE8C
        | REG_LSPCMODE ← $4000, mesuré, valeur unique. « Memory mapped registers » : la
        | vitesse d'auto-animation dans l'octet haut, l'IRQ timer dans les bits bas — $4000
        | la coupe, le jeu ayant pu l'armer. La lecture des bits est la mienne.
        move.w  #0x4000, 0x3C0006
        move.w  #7, 0x3C000C            | REG_IRQACK, mesuré : les trois IRQ
        move.b  %d0, 0x300001           | watchdog, mesuré dans le noyau

        | L'ATTENTE DE LA RÉFÉRENCE N'EST PAS REPRISE. Ses deux appels se ferment par repli
        | — première sortie vers $000200 ou $000918, pas vers $000122 — et la remise vient
        | plus tard. La passe qui l'imitait, IRQ démasquées dans SYSTEM_RETURN, a été
        | retirée pour un gel de `wjammers` sous MAME, cause non isolée : on remet la main
        | tout de suite, IRQ masquées, comme le bouchon.
        rts

| CODE 0 — « Init bram/select valid game for eye-catcher » (« BIOS RAM locations »).
| D'ABORD LE SLOT NOUVEAU SUIVANT. Mesuré sur la référence (`measured/2026-10-21-multi-
| slot.tsv`, c4-neuf ; trou) : chaque jeu finit sa demande 0 par SYSTEM_RETURN, BIOS_SYSRET_
| STATUS restant à $00 depuis le boot (écrit $00 à la trame 277, rien d'autre jusqu'à la
| fin des demandes 0) ; le BIOS reprend la main (REG_SWPBIOS à la trame qui suit), passe au
| slot nouveau suivant dans l'ordre des slots — un slot vide est sauté (trou : 0 puis 2) —,
| lui inscrit son bloc et lui donne sa demande 0 mode 0, une à trois trames plus tard
| (remises aux trames 281, 283, 286, 289). « Nouveau » se lit dans la table, une entrée
| avec un NGH et sans bloc : celles d'avant ont reçu le leur.
| PUIS LE RETOUR AU PREMIER SLOT OCCUPÉ ($D00058), mesuré : après la dernière demande 0, le
| passage au slot 0 (trame 295). La référence y joue son logo puis la démo du slot ; ici
| la démo seule, demande 2 mode 1, comme au boot suivant (le logo n'est pas écrit). Slot
| déjà en place (une seule cartouche, ou le premier occupé servi en dernier) : pas de
| passage, la démo directement, comme avant ce lot.
| LA SAUVEGARDE DU JEU QUI VIENT DE FINIR SA DEMANDE 0, avant chaque passage, et la
| restauration du premier slot au retour (`_sauver_jeu`, `_restaurer_jeu`), mesurées : la
| référence sauve chaque jeu au retour de sa demande 0 (trames 282, 284, 287, 295 à quatre
| cartouches), et restaure le premier slot avant sa demande 2 (trame 762, après son logo).
| SANS PASSAGE (une cartouche seule, ou le premier occupé servi en dernier) : la même
| sauvegarde, puis la restauration du même bloc (`_sysret_meme_slot`), mesuré sur une
| cartouche seule (sauvegarde à la trame qui suit le retour, restauration avant la demande 2,
| après le logo ; puzzledp, aof, mslug, nam1975 — ce dernier sans logo).
| REG_SWPBIOS : mesuré, la référence l'écrit à la trame qui suit le retour, avant la
| salve ; ici avant le passage, qui le défait par REG_SWPROM. IRQ masquées tout du long.
_sysret_init:
        bsr     _premier_nouveau        | %d2
        cmpi.w  #8, %d2
        bhs.s   1f
        move.b  %d0, 0x3A0003           | REG_SWPBIOS
        move.w  %d2, %d7                | %d7 : le slot nouveau
        moveq   #0, %d1
        move.b  0xD00108, %d1
        bsr     _sauver_jeu             | le jeu qui sort
        move.w  %d7, %d1
        bsr     _passer_au_slot
        move.w  %d1, %d2
        lsl.w   #2, %d2
        lea     0xD00124, %a0
        adda.w  %d2, %a0                | %a0 : son entrée
        move.b  %d0, 0x3A001D           | REG_SRAMUNLOCK
        bsr     _inscrire_slot
        move.b  %d0, 0x3A000D           | REG_SRAMLOCK
        bra     _remettre_a_user_init
1:      moveq   #0, %d1
        move.b  0xD00058, %d1           | le premier slot occupé ; $FF : aucun
        bmi     _sysret_demo
        cmp.b   0xD00108, %d1
        beq.s   _sysret_meme_slot       | déjà en place
        bra     _sysret_passer

| CODE 2 — « Switch to the next slot, relaunch eye-catcher » (« BIOS RAM locations »). Le
| jeu le pose à la fin de sa démo. Mesuré sur la référence (`measured/2026-10-21-multi-
| slot.tsv`, synthèse point 4, et le relevé `MS_PLAGES` de ce lot ; 2 et 4 cartouches,
| « trou ») : REG_SWPBIOS, la sauvegarde du jeu sortant, le passage au slot occupé
| suivant (vides sautés, bouclage), la restauration du jeu entrant, puis sa demande 2 mode
| 1, dans la même trame ou la suivante (la remise à 5840 pour un retour à 5837). Pas de
| logo au retour sur le premier slot : la référence en joue un, pas nous.
| UNE SEULE CARTOUCHE : pas de passage, mais la sauvegarde puis la restauration du même
| bloc, et la démo du même slot. Mesuré (relevé du 2026-10-22, aof, nam1975) : la référence
| sauve et restaure dans la trame qui suit le retour, puis joue son logo et RESTAURE UNE
| SECONDE FOIS avant la demande 2 (aof), le même bloc, la somme égale. Sans logo, rien ne
| s'exécute entre les deux : une seule restauration ici. GAME_DIP n'est pas relu : le slot
| ne change pas. Avec passage, il est relu du bloc du jeu entrant (`_relire_dip`), SUPPOSÉ
| comme au retour du code 0.
_sysret_rotation:
        bsr     _slot_suivant           | %d1
        cmp.b   0xD00108, %d1
        bne.s   _sysret_passer
| LES TRAMES TENUES DES CODES 0 ET 2, SANS PASSAGE. MESURÉ sous MAME le 2026-10-23 (-bios euro,
| nam1975 seul, sans logo : code 0 au boot, code 2 en fin de démo ; `measured/2026-10-23-titre-
| apres-game-over.tsv`, section 4), la référence, après l'entrée de SYSTEM_RETURN (trame R) :
|   - R+1 : SYSTEM_INT1 par le vecteur du jeu, REG_SWPBIOS, REG_POUTPUT ← $00 vers 0,11, à
|     0,47 ($10FD81 ← $02 au code 2) $10FEBF ← $01 et la sauvegarde du jeu ;
|   - R+2 : SYSTEM_INT1 ; ($10FD81 ← $02 au code 0) ; la salve son et REG_SLOT sur le même slot,
|     puis la restauration ;
|   - R+3 : SYSTEM_INT1 ; REG_SRAMLOCK, $10FEBF ← $00, $10FD80 réécrit ($00 au code 0, $02 au
|     code 2), $10FEE1 ← $0A, $10FDAF, les mots $10FDB6-$10FDBD, REG_SOUND ← $03 ;
|   - R+4 : SYSTEM_INT1, $10FDAE, $10FD80 ← $82, $10FEBF ← $00, REG_SWPROM, la main.
| Notre image sauvait, restaurait et rendait la main à R+1, IRQ masquées. Repris ici, comme le
| code 3 (`_sysret_fin_partie`) et sur ses routines, SAUF la salve son et REG_SLOT sur le même
| slot (non reprise : `_passer_au_slot` tient deux trames IRQ masquées). Le titre si un crédit
| (`_sysret_demo`), demande 3, SUPPOSÉ sur ce chemin tenu. Avec un passage de slot
| (`_sysret_passer`) et à la demande 0 suivante (`_sysret_init`), rien ne change : ni mesuré
| sur une seule cartouche, ni comparable (le logo de la référence au retour au slot 0).
_sysret_meme_slot:
        move.b  0x10FD81, %d7           | le code : 0 ou 2
        bsr     _int1_du_jeu            | R+1
        move.b  %d0, 0x3A0003           | REG_SWPBIOS
        bsr     _attente_tenue          | jusqu'à ≈ 0,47
        tst.b   %d7
        beq.s   1f
        move.b  #0x02, 0x10FD81         | code 2, mesuré : à 0,47
1:      move.b  #0x01, 0x10FEBF         | BIOS_BRAM_USED, mesuré
        moveq   #0, %d1
        move.b  0xD00108, %d1
        bsr     _sauver_jeu             | %d1 rendu
        bsr     _int1_tenu              | R+2
        tst.b   %d7
        bne.s   1f
        move.b  #0x02, 0x10FD81         | code 0, mesuré : à R+2
1:      bsr     _restaurer_jeu
        bsr     _int1_tenu              | R+3
        move.b  #0x00, 0x10FEBF
        moveq   #0, %d3                 | $10FD80 réécrit : $00 au code 0…
        tst.b   %d7
        beq.s   2f
        moveq   #2, %d3                 | …$02 au code 2
2:      moveq   #2, %d2                 | BIOS_USER_REQUEST = démo
        tst.w   0xD00034                | un crédit, P1 ou P2 (`_sysret_demo`) : le titre
        beq     _remise_tenue
        moveq   #3, %d2
        bra     _remise_tenue
_sysret_passer:
        bsr.s   _changer_de_slot
        bra.s   _sysret_demo

| LE CHANGEMENT DE JEU — partagé par la rotation de la démo (ci-dessus) et la sélection
| (`_retour_selection`). Entrée : %d1 = le slot qui entre. Clobbers %d0-%d4, %d7, %a0, %a1,
| %a3 ; revient la cartouche du slot en place, son jeu restauré, son GAME_DIP relu.
_changer_de_slot:
        move.b  %d0, 0x3A0003           | REG_SWPBIOS
        move.w  %d1, %d7                | %d7 : le slot qui entre
        moveq   #0, %d1
        move.b  0xD00108, %d1
        bsr     _sauver_jeu             | le jeu qui sort, sa P-ROM en place
        move.w  %d7, %d1
        bsr     _passer_au_slot
        bsr     _restaurer_jeu          | le jeu qui entre, sa P-ROM en place
        move.w  %d1, %d2
        lsl.w   #2, %d2
        lea     0xD00124, %a0
        adda.w  %d2, %a0
        bra     _relire_dip             | son `rts` rend la main à l'appelant

| CODE 1, AU RETOUR DE LA DEMANDE 1 DU MODE AES (`_logo_aes`) : la restauration du jeu, puis
| sa démo. Mesuré sous MAME le 2026-10-23 (`aes -bios asia`, kof98 ;
| `measured/2026-10-23-mode-aes.tsv`) : la référence pose $10FD81 ← $01 avant la demande 1, et
| la démo suit son SYSTEM_RETURN. La restauration est la nôtre : l'AES n'a pas de backup RAM ;
| sur MVS, la référence restaure le slot avant sa demande 2, après son logo (code 0, plus haut).
| Un code 1 que le jeu poserait lui-même, hors de ce cas (BIOS_LOGO différent de 1) : la démo,
| comme avant.
_sysret_logo:
        cmpi.b  #1, BIOS_LOGO
        bne.s   _sysret_demo
        move.b  #2, BIOS_LOGO           | faite
        moveq   #0, %d1
        move.b  0xD00108, %d1
        bsr     _restaurer_jeu

| CODES 1, 2, 4, 5 ET DÉFAUT — la démo, et la fin du code 0. Ce BIOS ne tient pas la
| comptabilité de la RAM de sauvegarde et n'a pas d'eye-catcher à lui — « USER
| subroutine » conseille sur MVS de faire le sien depuis la demande 2. D'où la démo,
| demande 2, mode 1 (« BIOS RAM locations » : 1 = « Title/Demo »). C'est le chemin de la
| fin de la dernière demande 0 et de chaque démo qui se termine sans partie.
| BIOS_SYSRET_STATUS ← $02 AVANT LA DÉMO, mesuré : la référence l'écrit dans la trame qui
| précède chaque demande 2 donnée après son logo (trames 708, 749, 752, 762, sur 1, 2 et 4
| cartouches), et il y reste jusqu'à la fin de la démo : c'est ce qui fait de cette fin un
| code 2, donc une rotation. Sans lui, la fin de démo retombait au code 0, laissé par le boot.
| Une cartouche seule : le code 2 la ramène ici par `_sysret_rotation`, comme le code 0.
| AVEC UN CRÉDIT, LE TITRE. MESURÉ sous MAME le 2026-10-22 (-bios euro, mslug, pièce sous
| INT1 pendant la demande 0 ; `measured/2026-10-22-frame-skip-et-mode0.tsv`) : la pièce
| n'est que créditée (`io.s`, fin de `_io_commun`), le jeu finit sa demande 0, et après son
| SYSTEM_RETURN la référence donne la demande 3, pas la démo, puis COIN_SOUND au premier
| FRAME_SKIP nul. Elle passe par son logo, qui voit le crédit : 5 trames entre le retour et
| la remise, contre ~1 ici, sans logo. MESURÉ aussi pour le code 2 (même relevé, section 5 :
| crédit forcé à l'entrée de SYSTEM_RETURN, 1 et 2 cartouches) : la rotation, sauvegarde et
| restauration comprises, puis la demande 3 sur le slot suivant, sans DEMO_END. SUPPOSÉ : au
| bout de la chaîne des demandes 0 d'une carte à plusieurs slots.
| LE CRÉDIT DE P2 COMPTE, comme au code 3 : le MOT $D00034. MESURÉ sous MAME le 2026-10-23
| (-bios euro, nam1975, fin de démo par le code 2, $D00035 ← $01 posé à l'entrée de
| SYSTEM_RETURN, $D00034 à $00 ; `measured/2026-10-23-titre-apres-game-over.tsv`, section 3) :
| la référence donne le titre (demande 3), pas la démo ; notre image, qui testait l'octet
| $D00034, la démo. SUPPOSÉ pour le code 0 et les autres codes qui passent ici.
_sysret_demo:
        tst.w   0xD00034                | un crédit, P1 ou P2 : le titre
        bne     _sysret_piece
        move.b  #0x02, 0x10FD81         | BIOS_SYSRET_STATUS
        moveq   #1, %d1                 | BIOS_USER_MODE    = titre / démo
        moveq   #2, %d2                 | BIOS_USER_REQUEST = démo
        moveq   #1, %d3                 | REG_SOUND ← $03, sans attente (`_remettre_a_user`)
        bra     _sysret_remise

| CODE 3 — « After a gameover, save the playtime for bookeeping, switch to DEMO mode,
| reset the workbackup ram ». Ni comptabilité ni « workbackup ram » ici : aucune page
| ne dit ce qu'elle couvre. « Switch to DEMO mode » est le mode 1, titre / démo.
| CRÉDITS RESTANTS → TITRE, demande 3 : lu dans « USER subroutine », dont le quirk du
| double titre suppose que le BIOS appelle la commande 3 « after a game over » quand des
| crédits sont « already in the system ». Sinon, la démo.
| UN SEUL TITRE, pas le double titre du quirk. « USER subroutine » décrit le second
| appel de la commande 3 comme un probable bogue du BIOS, corrigé dans une révision
| ultérieure (à confirmer, dit la page), et $10FEC5 (BIOS_TITLE_MODE) comme le moyen
| qu'ont les jeux de l'empêcher. Un jeu qui pose $10FEC5 à 1 attend donc un seul
| titre ; un jeu qui le laisse à 0 tolère les deux. Un seul titre convient aux deux,
| c'est pourquoi $10FEC5 n'est pas lu (il est écrit depuis le 2026-10-23, la valeur mesurée,
| plus bas). Le passage au titre réarme $10FD81 à 2
| (`_sysret_piece`), ce qui empêche aussi un troisième.
| MESURÉ, NON REPRIS : la référence (-bios euro) FAIT le double titre. Sous MAME le 2026-10-23
| (aof, deux pièces, START, game over avec un crédit ; `measured/2026-10-23-titre-apres-game-
| over.tsv`, section 1) : remise du titre à R+2, puis au premier SYSTEM_IO à FRAME_SKIP nul
| (R+12), $10FDDB décompté, $10FEC5 ← $01, $10FEE0 ← $00, $10FD81 ← $06, DEMO_END, et un
| second titre (demande 3) à R+15 — le chemin de la pièce pendant la démo (`_retour_demo_end`).
| Hors de la remise de ce lot, qui ne portait que les écritures du code 3. Le test : crédit
| P1 ou P2 non nul ($D00034/$D00035, « Backup RAM », mesuré plus bas), sans regarder
| BIOS_CREDIT_DEC (SUPPOSÉ).
| LA SAUVEGARDE DU JEU D'ABORD, sans restauration. Mesuré (relevé du 2026-10-22, une
| cartouche : puzzledp, nam1975, aof ; deux : puzzledp et aof, partie sur le slot 0) : à
| la trame qui suit le retour, la référence sauve la zone du jeu dans son bloc, puis rend
| la main sur le même slot — demande 2 sans crédit, demande 3 avec (aof) —, sans relire le
| bloc. C'est cette sauvegarde qui garde les scores de la partie.
| PLAY TIME REMIS À ZÉRO, AVANT LA SAUVEGARDE. Lu dans « Backup RAM » : $D00048-$D0004B
| « Reset to 0 by SYSTEM_RETURN ». MESURÉ sous MAME le 2026-10-23 (-bios euro, nam1975, NVRAM
| neuve ; `measured/2026-10-23-comptabilite.tsv`, section 1) : au code 3, à la trame qui suit
| le retour, la référence écrit PLAY TIME ← 0 puis $D0004C ← $3B, puis sauve le jeu ; aux
| codes 0 (boot), 2 (fin de démo) et 6 (pièce, DEMO_END), elle n'écrit pas ces cellules — elles
| y valent déjà zéro, PLAY TIME ne courant qu'en partie (`io.s`). Rien d'autre n'est écrit en
| backup RAM hors de la sauvegarde du jeu : le « save the playtime for bookeeping » de la page
| ne laisse pas de trace ici.
| LE TEST DU CRÉDIT, le mot $D00034 : MESURÉ le même jour, $D00035 ← $01 posé par
| l'enveloppe en partie (crédit $D00034 à $00), la référence donne le titre après le code 3 ;
| sans lui, la démo. Le crédit de P2 compte donc.
| LES TRAMES TENUES. MESURÉ sous MAME le 2026-10-23 (-bios euro, nam1975 et aof, NVRAM neuve ;
| `measured/2026-10-23-led-et-remises.tsv`, section 4), la référence, après l'entrée de
| SYSTEM_RETURN (trame R) :
|   - à R+1, l'IRQ de vblank prise par le vecteur de la cartouche, le jeu en SYSTEM_INT1
|     ($C00438 lu), puis REG_SWPBIOS ; à 0,47 PLAY TIME ← 0, $D0004C ← $3B, $10FD81 ← $02 et la
|     sauvegarde du jeu ;
|   - SANS CRÉDIT (nam1975) : à R+2, SYSTEM_INT1 par la table du BIOS, puis à 0,38 $10FD80 ←
|     $02, $10FEE1 ← $0A, $10FDAF ← $01, les mots $10FDB8-$10FDBA, REG_SOUND ← $03 ; à R+3,
|     SYSTEM_INT1 ($10FEE1 → $09), $10FDAE ← $02, $10FD80 ← $82, REG_SWPROM, la main ;
|   - AVEC UN CRÉDIT (aof) : les écritures de 0,38 tombent à 0,92 de R+1, et la main à R+2,
|     demande 3, de même.
| Notre image rendait la main dans la trame R. Écrit ici comme `_retour_demo_end` : IRQ
| ouvertes jusqu'à ce que SYSTEM_INT1 ait tourné, puis les vblanks suivants par un appel de
| $C00438 sur un cadre fabriqué (`_int1_tenu`). L'attente jusqu'à 0,47 est un compte de
| tours (`_attente_tenue`), celle de 0,38 ou 0,92 une ligne du balayage (`_attendre_ligne`).
| BIOS_TITLE_MODE, BIOS_BRAM_USED ET LE DÉPART FORCÉ. MESURÉ sous MAME le 2026-10-23 (-bios euro,
| nam1975 sans crédit, aof avec un crédit, nam1975 avec $D00035 ← $01 posé à l'entrée ;
| `measured/2026-10-23-titre-apres-game-over.tsv`, section 1), la référence, à R+1 :
|   - à 0,47, $10FEC5 ← $00, puis $10FEBF ← $01, REG_SRAMUNLOCK, PLAY TIME et $D0004C,
|     $10FEBF ← $00, REG_SRAMLOCK, $10FEBF ← $01, REG_SRAMUNLOCK, $10FD81 ← $02, la sauvegarde ;
|     REG_SRAMLOCK et $10FEBF ← $00 seulement juste avant les écritures de 0,38 (R+2) ou 0,92
|     (R+1) — sa sauvegarde dure jusque-là, la nôtre non : le $00 est placé à l'instant mesuré ;
|   - AVEC UN CRÉDIT ($D00034, ou $D00035 seul), le mot $10FDDA ← $303B juste avant $10FD80 ← $02
|     (0,92 de R+1) : le départ forcé réarmé, qui décompte au titre — PLAYER_START 1 823 trames
|     après le retour (aof). Sans crédit, rien. Notre image laissait $10FDDA à zéro (le START
|     de la partie l'avait désarmé) : le titre d'après game over ne décomptait pas ;
|   - $10FEBF ← $00 encore avant REG_SWPROM, à la remise (`_remise_tenue`).
| « BIOS RAM locations » nomme $10FEC5 BIOS_TITLE_MODE et $10FEBF BIOS_BRAM_USED ; la bascule
| de $10FEBF autour des sections déverrouillées est la lecture du nom, pas une page. Le $10FEC5
| écrit ici n'est LU nulle part chez nous : voir UN SEUL TITRE plus haut.
_sysret_fin_partie:
        move.b  0x10FEE4, %d6           | le compteur de SYSTEM_INT1
        move.w  #2 * SYNC_TOURS - 1, %d5
        move.w  #0x2000, %sr            | le vblank, par le jeu
1:      move.b  %d0, 0x300001           | watchdog
        cmp.b   0x10FEE4, %d6
        dbne    %d5, 1b
        move.w  #0x2700, %sr
        move.b  %d0, 0x3A0003           | REG_SWPBIOS
        bsr     _attente_tenue          | jusqu'à ≈ 0,47
        move.b  #0x00, 0x10FEC5         | BIOS_TITLE_MODE, mesuré
        move.b  #0x01, 0x10FEBF         | BIOS_BRAM_USED, mesuré, et les suivants
        move.b  %d0, 0x3A001D           | REG_SRAMUNLOCK
        clr.l   0xD00048                | PLAY TIME
        move.b  #0x3B, 0xD0004C         | PLAY_TIME_FRAME_TIMER
        move.b  #0x00, 0x10FEBF
        move.b  %d0, 0x3A000D           | REG_SRAMLOCK
        move.b  #0x01, 0x10FEBF
        move.b  #0x02, 0x10FD81         | BIOS_SYSRET_STATUS, mesuré : avant la sauvegarde
        moveq   #0, %d1
        move.b  0xD00108, %d1
        bsr     _sauver_jeu
        | LE CRÉDIT DE P2 SEUL ($D00035, posé à l'entrée) : MESURÉ (même relevé, section 1), la
        | référence donne le titre et réarme le départ forcé, mais au rythme d'une fin de partie
        | sans crédit (0,38 de R+2, la main à R+3). D'où deux tests : le mot pour la demande et
        | $10FDDA, l'octet de P1 pour l'instant.
        moveq   #2, %d3                 | $10FD80 réécrit à la remise (`_remise_tenue`)
        moveq   #2, %d2                 | BIOS_USER_REQUEST = démo
        tst.w   0xD00034                | crédits P1 et P2, BCD
        beq.s   1f
        moveq   #3, %d2                 | BIOS_USER_REQUEST = titre
1:      move.w  #0x1DB, %d1             | ≈ 0,92 de R+1 (voir `_attendre_ligne`)
        tst.b   0xD00034                | le crédit de P1
        bne.s   3f
        bsr     _int1_tenu              | R+2 : SYSTEM_INT1
        move.w  #0x14D, %d1             | ≈ 0,38 de R+2
3:      bsr.s   _attendre_ligne
        move.b  #0x00, 0x10FEBF         | mesuré : à 0,38 ou 0,92, non à la fin de la sauvegarde
        cmpi.b  #3, %d2
        bne     _remise_tenue
        move.w  #0x303B, 0x10FDDA       | BIOS_COMPULSION_TIMER, $30 s et $3B trames : mesuré
        bra     _remise_tenue

| ATTENDRE LA LIGNE %d1 DU BALAYAGE : jusqu'à ce que le compteur de ligne (REG_LSPCMODE, bits
| 15-7, voir `_remettre_a_user`) soit dans [%d1, $1F0[, borné à SYNC_TOURS tours, watchdog à
| chaque tour. Une ligne plutôt qu'un compte de tours : la sauvegarde qui précède dure
| selon le jeu (0,22 trame sur aof, mesuré). La correspondance — 264 lignes par trame, $1F0
| au vblank, $1FF suivi de $F8 — est SUPPOSÉE ; elle place 0,38 à $14D et 0,92 à $1DB, et le
| banc la vérifie (`measured/2026-10-23-led-et-remises.tsv`, section 4). Clobbers %d0, %d5.
_attendre_ligne:
        move.w  #SYNC_TOURS - 1, %d5
1:      move.b  %d0, 0x300001           | watchdog
        move.w  0x3C0006, %d0
        lsr.w   #7, %d0
        cmp.w   %d1, %d0
        bcs.s   2f                      | pas encore la ligne
        cmpi.w  #0x1F0, %d0
        bcs.s   3f                      | dans la fenêtre : la ligne est passée
2:      dbra    %d5, 1b
3:      rts

| CODE 6 — « Called after a coin deposit, does nothing ». Lecture : SYSTEM_RETURN n'y
| fait rien de propre — ni slot, ni eye-catcher, ni démo relancée — et la main va là où
| la pièce mène, le titre : « USER subroutine », la demande 3 « called when a coin is
| inserted on MVS ». Mesuré dans la référence : après COIN_SOUND et DEMO_END
| (`protocole.md`, trace 7, 512,92-512,93), une demande 3 à 514,89 et non une démo ; et
| « DEMO_END subroutine » : « The System ROM then jumps to SYSTEM_RETURN ».
| SUPPOSÉ : le titre sans condition de crédit — une pièce peut ne pas faire encore un
| crédit, et la page lie la demande 3 à la pièce, pas au crédit.
_sysret_piece:
        | LE RESET DU Z80 AVANT LE TITRE : REG_SOUND ← $03 et l'attente, faits par
        | `_remettre_a_user` (%d3 = 2), après les écritures que la référence fait avant lui.
        | LE CODE SUIVANT, RÉARMÉ À 2. Mesuré : les deux passages au titre de la référence
        | écrivent $10FD81 ← $02 avec la demande 3 (`appel_C00438.md`, 2/41 appels). Lu :
        | 2 = « Switch to the next slot, relaunch eye-catcher », soit la démo chez nous.
        | Sans ce réarmement, un 3 laissé là ferait relancer le titre par chaque fin de
        | démo tant qu'un crédit reste.
        move.b  #0x02, 0x10FD81
        moveq   #1, %d1                 | BIOS_USER_MODE    = titre / démo (mesuré : $01)
        moveq   #3, %d2                 | BIOS_USER_REQUEST = titre (mesuré : $03)
        moveq   #2, %d3                 | REG_SOUND ← $03 et l'attente (`_remettre_a_user`)

_sysret_remise:
        | FRAME_SKIP : `_remettre_a_user` le pose à $09, la valeur que la référence a à sa
        | remise (mesuré, voir là) ; `io.s` le décompte.
        bra     _remettre_a_user

| ----------------------------------------------------------------------------------
| LA PIÈCE HORS PARTIE — atteinte par `jmp` depuis `_io_commun` (`io.s`), sous SYSTEM_IO
| comme sous SYSTEM_INT1. Ne revient pas.
|
| Mesuré : une pièce créditée hors partie fait repartir le jeu par une remise $000122,
| demande 3 — pièce trame 297 → remise 300, pièce 299 → remise 302, 289 sans pièce ;
| trace 9 (`protocole.md`), pièce à 242.92, $03 sur REG_SOUND à 244.41, $10FDAE ← $03
| puis $10FD80 ← $82 et la main à $000122 à 244.89. Ce sont les écritures du chemin
| `_sysret_piece`, qu'on prend donc tel quel : reset du Z80, $10FD81 ← $02, titre.
|
| LE CADRE ABANDONNÉ. Sous INT1, la pile porte le cadre d'exception de l'IRQ et nos
| registres sauvés ; sous SYSTEM_IO, le retour du jeu. Comme SYSTEM_RETURN, on ne
| dépile rien : SR masque les IRQ et la pile repart de $10F300. Un 68000 ne garde aucun
| état « interruption en cours » hors du masque de SR — l'IRQ, déjà acquittée par INT1
| ($3C000C), n'attend pas de `rte`. SUPPOSÉ : que le jeu, redémarré par sa routine USER,
| n'en attende pas davantage ; la référence fait la même remise depuis ce contexte.
| ----------------------------------------------------------------------------------
        .global _retour_piece
_retour_piece:
        move.w  #0x2700, %sr
        move.l  #0x10F300, %sp
        | BIOS_SYSTEM_MODE ← $01 : le $01 de la trace 9 (plus haut), que `_remettre_a_user`
        | écrivait pour toutes les remises jusqu'au 2026-10-23 et n'écrit plus (voir là).
        move.b  #0x01, 0x10FD80
        bra.s   _sysret_piece

| ----------------------------------------------------------------------------------
| LA PIÈCE QUI FAIT LE CRÉDIT PENDANT LA DÉMO, sous SYSTEM_IO — atteinte par `jmp` depuis
| `_systeme_io` (`io.s`), à BIOS_FRAME_SKIP nul, après COIN_SOUND. Ne revient pas.
|
| LU : « 68k program header », $00012E porte « JMP to DEMO_END subroutine » ; « DEMO_END
| subroutine », la routine « should just end by a RTS instruction », et « The System ROM
| then jumps to SYSTEM_RETURN » (la page ne parle que de SELECT, pas de la pièce).
| MESURÉ sous MAME le 2026-10-22 (`bench/multislot.lua` et une enveloppe qui relève les
| écritures du jeu entre la lecture de $00012E et celle de $000122, -bios euro, une
| cartouche ; `measured/2026-10-22-piece-demo-end.tsv`), la référence, sur puzzledp, aof,
| mslug, nam1975 et garou :
|   - dans l'appel de la pièce : COIN_SOUND ($000134 lu), puis $10FD81 ← $06 et DEMO_END
|     ($00012E lu). IRQ masquées pendant DEMO_END : aucun vecteur d'IRQ pris tant que le jeu
|     l'exécute (mslug, 5 trames ; aof, 1) ;
|   - au retour, $10FD80 ← $02 et $10FEE1 ← $FF (l'entrée de SYSTEM_RETURN, code 6) ;
|   - la trame suivante, à 0,47 : $10FD81 ← $02, $10FEE1 ← $0A, REG_SOUND ← $03 ;
|   - la remise, demande 3, au vblank d'après : deux trames après la pièce quand DEMO_END
|     rend tout de suite (puzzledp, nam1975, garou), plus tard d'autant qu'il dure.
| Le jeu, lui, travaille dans DEMO_END : aof y écrit 29 955 octets de sa RAM, mslug 58 384.
| Notre image ne l'appelait pas et rendait la main à la trame suivante.
| LES DEUX VBLANKS SERVIS. MESURÉ sous MAME le 2026-10-23 (-bios euro, puzzledp, aof, mslug,
| nam1975, garou ; `measured/2026-10-23-comptabilite.tsv`, section 3) : après DEMO_END, la
| référence laisse passer l'IRQ de vblank de la trame suivante par le vecteur de la cartouche
| — le jeu y entre en SYSTEM_INT1 ($C00438 lu), BIOS_SYSTEM_MODE ayant son bit 7 à 0 — et
| SYSTEM_INT1 sert les afficheurs, le front de pièce et l'impulsion du compteur ; puis
| REG_SWPBIOS. À 0,47 : $10FD81 ← $02, $10FD80 ← $02, $10FEE1 ← $0A, $10FDAF ← $01, les mots
| $10FDB8, $10FDB6, $10FDBC, $10FDBA ← 0, REG_SOUND ← $03. Au vblank suivant, celui de sa
| propre table (REG_SWPBIOS posé), SYSTEM_INT1 encore — FRAME_SKIP y passe de $0A à $09 —,
| puis $10FDAE ← $03, $10FD80 ← $82, REG_SWPROM et la main à $000122, SANS $10FD80 ← $01.
| Notre image tenait la trame IRQ masquées : l'impulsion du compteur finissait une trame plus
| tard, et aof écrivait 3 octets de moins entre DEMO_END et la remise (29 952).
| Ici : IRQ ouvertes jusqu'à ce que SYSTEM_INT1 ait tourné ($10FEE4, son compteur, a
| bougé), borné à ≈ 2 trames ; le second vblank, IRQ masquées, par un appel de
| $C00438 sur un cadre d'exception fabriqué — notre table de vecteurs ne mène pas
| l'IRQ 1 à SYSTEM_INT1 (`plantage.s`). SUPPOSÉ : qu'un jeu qui ne passe pas par $C00438 sous
| BIOS_SYSTEM_MODE à $02 sorte quand même par la borne.
| L'attente jusqu'à 0,47 : 3 560 tours de ~26 cycles (voir `_sysret_piece`).
| ----------------------------------------------------------------------------------
        .global _retour_demo_end
_retour_demo_end:
        move.w  #0x2700, %sr
        | $10FEE0 ← $00 AVANT DEMO_END. Aucune page ne nomme l'adresse. MESURÉ sous MAME le
        | 2026-10-23 (-bios euro ; `measured/2026-10-23-led-et-remises.tsv`, section 5) : la
        | référence l'écrit juste avant $10FD81 et DEMO_END, sur chacun des 13 appels relevés
        | dans la fenêtre de l'enveloppe (11 après une pièce, $10FD81 ← $06 ; 2 sur SELECT, ← $04).
        | Écrit au plus restreint : la valeur, à sa place, sans rôle attribué.
        move.b  #0x00, 0x10FEE0
        move.b  #0x06, 0x10FD81         | BIOS_SYSRET_STATUS, mesuré, avant DEMO_END
        jsr     0x12E                   | DEMO_END
        move.w  #0x2700, %sr
        move.l  #0x10F300, %sp          | le cadre de SYSTEM_IO est abandonné, comme à la pièce
        bsr     _sysret_etat            | l'entrée de SYSTEM_RETURN : $10FD80, $10FEE1 ← $FF…
        move.b  0x10FEE4, %d6           | le compteur de SYSTEM_INT1
        move.w  #2 * SYNC_TOURS - 1, %d5
        move.w  #0x2000, %sr            | le vblank, par le jeu
1:      move.b  %d0, 0x300001           | watchdog
        cmp.b   0x10FEE4, %d6
        dbne    %d5, 1b
        move.w  #0x2700, %sr
        move.b  %d0, 0x3A0003           | REG_SWPBIOS
        bsr     _attente_tenue          | jusqu'à ≈ 0,47
        move.b  #0x02, 0x10FD81         | mesuré, à 0,47, et ce qui suit
        moveq   #3, %d2                 | BIOS_USER_REQUEST = titre
        moveq   #2, %d3                 | $10FD80 réécrit

| LA FIN DES TRAMES TENUES, partagée avec le code 3 (`_sysret_fin_partie`), les codes 0 et 2
| (`_sysret_meme_slot`). Entrée : %d2 = la demande, %d3 = ce que $10FD80 reçoit de nouveau (la
| valeur de l'entrée de SYSTEM_RETURN, voir `_remettre_a_user`), IRQ masquées, REG_SWPBIOS
| posé. Ne revient pas. Les écritures mesurées avant la remise (voir plus haut), REG_SOUND ←
| $03 compris, puis le vblank suivant par SYSTEM_INT1, et la main.
| $10FEBF ← $00 JUSTE AVANT REG_SWPROM. MESURÉ sous MAME le 2026-10-23 (-bios euro ;
| `measured/2026-10-23-titre-apres-game-over.tsv`, section 1) : à chacune des remises tenues
| relevées — après DEMO_END (puzzledp, aof, mslug, nam1975, garou, b2b), codes 0, 2 et 3,
| SELECT —, après $10FD80 ← $82.
_remise_tenue:
        moveq   #1, %d1                 | BIOS_USER_MODE    = titre / démo
        bsr     _logo_aes               | mode AES : peut-être la demande 1 (%d1, %d2)
        | BIOS_SYSTEM_MODE de la remise, $82, ou $81 à la demande 1 (`_logo_aes`, mesuré) : choisi
        | ici, avant le vblank, pour que la remise ne prenne aucun cycle de plus (plus bas).
        moveq   #-0x7E, %d4
        cmpi.b  #1, %d2
        bne.s   1f
        moveq   #-0x7F, %d4
1:      move.b  %d3, 0x10FD80
        move.b  #0x0A, 0x10FEE1
        move.b  %d1, 0x10FDAF
        clr.w   0x10FDB8                | voir `_remettre_a_user`
        clr.w   0x10FDB6
        clr.w   0x10FDBC
        clr.w   0x10FDBA
        bsr     _commutateurs           | BIOS_P1STATUS et $10FEF8, comme `_remettre_a_user`
        jsr     _af_charger             | l'autofire du jeu servi (`autofire.s`), registres rendus
        move.b  #0x03, 0x320000         | REG_SOUND : le reset du Z80 (voir `_sysret_piece`)
        bsr     _int1_tenu              | le vblank suivant
        move.w  #0x4000, 0x3C0006       | REG_LSPCMODE, comme à toute remise
        move.b  %d2, 0x10FDAE           | BIOS_USER_REQUEST
        move.b  %d4, 0x10FD80           | BIOS_SYSTEM_MODE  : le jeu a le vblank (%d4, plus haut)
        nop                             | 16 + 4 : les 20 cycles du `move.b #0x82` d'avant
        move.b  #0x00, 0x10FEBF         | BIOS_BRAM_USED, mesuré
        move.b  %d0, 0x3A0013           | REG_SWPROM
        move.b  %d0, 0x300001
        bra     _remettre_partir

| ----------------------------------------------------------------------------------
| LES COMMUTATEURS 3 ET 2, À LA REMISE. Clobbers %d0.
_commutateurs:
        | LES COMMUTATEURS 3 ET 2 DE LA CARTE, relus à chaque remise : `_remettre_a_user`, dont la
        | demande 0 du boot, et `_remise_tenue`, dont le titre après une pièce. REG_DIPSW, actifs bas
        | (neogeo.cpp : SW:3 « Controller », Joystick / « Mahjong Panel » ; SW:2 « Cabinet »,
        | Normal / « VS Mode »). MESURÉ sous MAME le 2026-10-27 (`measured/2026-10-27-dip-2-8.tsv`,
        | sections 4 et 6), le commutateur basculé en démo : le BIOS SNK pose BIOS_P1STATUS
        | ($10FD94) à 3, « Mahjong controller », 3 trames après la pièce, pas avant ; UniBIOS 4.0
        | et le BIOS SNK japonais recopient le 2 dans $10FEF8, « BIOS_4P_REQUESTED », « $2: dip 2
        | was on » (« BIOS RAM locations »), au même instant ; tous deux dès le boot.
        | SUPPOSÉ : aux autres remises (fin de démo, game over, SELECT), que rien n'a mesurées.
        | Aucune carte 4 joueurs n'est cherchée : BIOS_4P_MODE et BIOS_4P_PLUGGED restent à 0.
        moveq   #0, %d0
        btst    #2, 0x300001
        bne.s   5f
        moveq   #3, %d0
5:      move.b  %d0, 0x10FD94           | BIOS_P1STATUS
        moveq   #0, %d0
        btst    #1, 0x300001
        bne.s   5f
        moveq   #2, %d0
5:      move.b  %d0, 0x10FEF8           | BIOS_4P_REQUESTED
        rts

| L'ATTENTE DE ≈ 0,02 À ≈ 0,47 DE LA TRAME, après REG_SWPBIOS : 3 560 tours de ~26 cycles en
| tout (voir `_sysret_piece`), et REG_POUTPUT ← $00 vers 0,11. MESURÉ sous MAME le 2026-10-23
| (-bios euro, puzzledp et nam1975 ; `measured/2026-10-23-led-et-remises.tsv`, section 1) :
| la référence écrit $00 dans REG_POUTPUT ($380001, « Joypad ports outputs », « Memory mapped
| registers ») à 0,113 de cette trame, dans la trame tenue d'après DEMO_END comme dans celle
| du code 3 — la valeur que l'appel d'avant y a laissée. Clobbers %d5.
_attente_tenue:
        move.w  #700-1, %d5
1:      move.b  %d0, 0x300001           | watchdog
        dbra    %d5, 1b
        move.b  #0x00, 0x380001         | REG_POUTPUT, mesuré
        move.w  #2860-1, %d5
2:      move.b  %d0, 0x300001
        dbra    %d5, 2b
        rts

| LE VBLANK SUIVANT PAR LE JEU : IRQ ouvertes jusqu'à ce que SYSTEM_INT1 ait tourné ($10FEE4, son
| compteur, a bougé), bornées à 2 × SYNC_TOURS tours (≈ 2 trames), watchdog à chaque tour ; puis
| masquées. La boucle de `_sysret_fin_partie` et de `_retour_demo_end`, en sous-routine pour les
| codes 0 et 2 (`_sysret_meme_slot`). Clobbers %d5, %d6.
_int1_du_jeu:
        move.b  0x10FEE4, %d6           | le compteur de SYSTEM_INT1
        move.w  #2 * SYNC_TOURS - 1, %d5
        move.w  #0x2000, %sr            | le vblank, par le jeu
1:      move.b  %d0, 0x300001           | watchdog
        cmp.b   0x10FEE4, %d6
        dbne    %d5, 1b
        move.w  #0x2700, %sr
        rts

| LE VBLANK SUIVANT, IRQ masquées : la ligne $1F0 (`.Lsync`), puis SYSTEM_INT1 par son entrée
| publique sur un cadre d'exception fabriqué, comme l'IRQ — son `rte` revient ici. Notre table
| de vecteurs ne mène pas l'IRQ 1 à SYSTEM_INT1 (`plantage.s`). Clobbers %d0 ; SYSTEM_INT1
| rend les autres registres.
_int1_tenu:
        bsr     .Lsync
        pea     3f
        move.w  #0x2700, -(%sp)
        jmp     0xC00438                | SYSTEM_INT1
3:      rts

| ----------------------------------------------------------------------------------
| LA SÉLECTION DU JEU — atteinte par `jmp` depuis `_io_select` (`io.s`), sous SYSTEM_IO,
| %d6 = $04 (SELECT P1) ou $05 (SELECT P2), le code que BIOS_SYSRET_STATUS reçoit ici. Ne revient pas ; le
| cadre abandonné est traité comme à la pièce (plus haut).
|
| MESURÉ sur la référence (`bench/multislot.lua`, `MS_PLAGES`, -bios euro, MV-6F, 1, 2 et
| 3 cartouches, NVRAM neuve et gardée, le 2026-10-22 ; `measured/2026-10-22-multi-slot-
| lot4.tsv`) :
|   - à la trame du SELECT, BIOS_SYSRET_STATUS ← $04/$05 et BIOS_SYSTEM_MODE ← $02, la main
|     reprise SANS que le jeu entre par SYSTEM_RETURN ($C00444 jamais lu) ;
|   - à la trame suivante, BIOS_SYSRET_STATUS ← $02, puis le passage de la rotation : la
|     sauvegarde du jeu sortant (S), REG_SOUND $01, l'écho, REG_SLOT, REG_CRTFIX, REG_SWPROM,
|     REG_SOUND $03, $D00108, la restauration du jeu entrant (R) ;
|   - puis la remise sur le nouveau slot, demande 3, mode 1 — le titre, pas la démo ; le
|     crédit gardé. Une à trois trames entre le SELECT et la remise.
| Ici dans la même trame que SELECT, comme la pièce (`_retour_piece`) : la référence rend
| encore la fin de cette trame au jeu, pas nous. GAME_DIP relu du bloc du jeu entrant, comme
| à la rotation (SUPPOSÉ là aussi). Le second REG_SOUND $03 que la référence écrit une
| demi-trame après le passage est repris depuis le 2026-10-23 (`_remettre_a_user`).
| DEMO_END D'ABORD. MESURÉ sous MAME le 2026-10-23 (-bios euro, puzzledp + aof, SELECT à 1200
| et à 1213, NVRAM neuve ; `measured/2026-10-23-titre-apres-game-over.tsv`, section 2), la
| référence, dans l'appel de SYSTEM_IO du SELECT : $10FEE0 ← $00, $10FD81 ← $04 (ou $05), DEMO_END
| ($00012E lu) ; à son retour $10FEE1 ← $FF, $10FD80 ← $02, $10FE8C ← $01 (l'entrée de
| SYSTEM_RETURN, `_sysret_etat`) ; puis $10FEBF ← $01 avant la sauvegarde du jeu sortant, ← $00
| après la restauration du jeu entrant, et ← $00 juste avant REG_SWPROM à la remise. « DEMO_END
| subroutine » ne parle que de SELECT (lu, voir `_retour_demo_end`). Notre image n'appelait pas
| DEMO_END.
| LES TRAMES TENUES NE SONT PAS REPRISES : la référence sert SYSTEM_INT1 aux trois vblanks entre
| le SELECT et la remise (S+1 par le vecteur du jeu, S+2 et S+3 par sa table), nous aucun —
| IRQ masquées pendant la poignée de main du son (`_passer_au_slot`, deux `.Lsync`). La remise
| tombe à S+3 chez les deux (même relevé) ; servir les vblanks en plus la repousserait.
| ----------------------------------------------------------------------------------
        .global _retour_selection
_retour_selection:
        move.w  #0x2700, %sr
        move.b  #0x00, 0x10FEE0         | mesuré, sans rôle attribué (`_retour_demo_end`)
        move.b  %d6, 0x10FD81           | BIOS_SYSRET_STATUS : 4, le suivant ; 5, le précédent
        jsr     0x12E                   | DEMO_END
        move.w  #0x2700, %sr
        move.l  #0x10F300, %sp          | le cadre de SYSTEM_IO est abandonné, comme à la pièce
        move.b  0x10FD81, %d4           | le code
        moveq   #2, %d3                 | BIOS_SYSTEM_MODE ← $02, mesuré
        bsr     _sysret_etat_mode       | $10FD80, $10FEE1 ← $FF, $10FE8C…
        bsr     _slot_suivant           | %d1
        cmpi.b  #4, %d4
        beq.s   1f
        bsr     _slot_precedent
1:      move.b  #0x01, 0x10FEBF         | BIOS_BRAM_USED, mesuré
        bsr     _changer_de_slot
        move.b  #0x00, 0x10FEBF
        move.b  #0x02, 0x10FD81         | BIOS_SYSRET_STATUS, mesuré : la démo à la suite
        moveq   #1, %d1                 | BIOS_USER_MODE    = titre / démo (mesuré : $01)
        moveq   #3, %d2                 | BIOS_USER_REQUEST = titre (mesuré : $03)
        | EN MODE AES, LA DÉMO DU JEU SUIVANT : pas de titre BIOS en AES (`_io_select_aes`,
        | `io.s` ; « USER subroutine » : sur AES, le BIOS ne va pas plus loin que la demande 2).
        | Écart voulu, DECISIONS §11.
        tst.b   0x10FD82
        bne.s   1f
        moveq   #2, %d2                 | mode AES : BIOS_USER_REQUEST = démo
1:
        | REG_SOUND ← $03 avant la remise, en plus de celui du passage : MESURÉ sous MAME le
        | 2026-10-23 (-bios euro, puzzledp + aof, SELECT ; `measured/2026-10-23-led-et-remises.tsv`,
        | section 3), la référence l'écrit à la trame qui précède la remise, après le passage.
        moveq   #1, %d3
        bra     _remettre_a_user

| ----------------------------------------------------------------------------------
| LA REMISE DE LA MAIN À USER — la seule, partagée par le boot, SYSTEM_RETURN et la
| pièce hors partie (`_retour_piece`).
|
| Entrée : %d1 = mode USER ($10FDAF), %d2 = demande USER ($10FDAE). Ne revient pas.
|
| L'ORDRE ET LES VALEURS SONT MESURÉS (`protocole.md`, trace 2, demande 3) : $10FD80 ←
| $01, puis $10FDAF ← mode, puis $10FDAE ← demande, puis $10FD80 ← $82, puis la main à
| $000122. Les valeurs de $10FD80 sont revues le 2026-10-23 sur 18 remises (plus bas).
|
| Le relevé écrit $01 deux fois dans $10FD80 sur deux trames, pendant que le BIOS de
| référence travaille ; nous n'avons rien à faire entre les deux, donc une seule
| écriture. C'est l'adresse et l'ordre qui sont reproduits, pas le compte.
|
| « BIOS RAM locations » documente pour $10FD80 « 0:BIOS wants vblank (system mode),
| $80:Ok to use vblank (game mode) » : le bit 7. Les valeurs mesurées, $01 et $82, ont
| ce bit 7 tel que la page le prévoit — système, puis jeu —, et portent en plus un bit
| bas, 0 puis 1, qu'aucune page lue ne décrit. On les reproduit telles quelles ; leur
| sens est inconnu.
|
| SUPPOSÉ : que la même séquence vaille pour les demandes 0 et 2, que le relevé ne
| couvre pas. C'est la seule remise à $000122 mesurée, et rien de ce que j'ai lu ne dit
| qu'une autre demande en appelle une autre.
| ----------------------------------------------------------------------------------
_remettre_a_user_init:
        | Mode 0 : « BIOS RAM locations » donne 0 = « Init/Boot animation » pour $10FDAF,
        | et « USER subroutine » demande d'y être pendant la demande 0. Demande 0 :
        | « 0:Init » dans la même page.
        moveq   #0, %d1                 | BIOS_USER_MODE    = initialisation
        moveq   #0, %d2                 | BIOS_USER_REQUEST = initialisation

_remettre_a_user:
        bsr     _logo_aes               | mode AES : peut-être la demande 1 (%d1, %d2)
        | LE TIMER DU LSPC COUPÉ À CHAQUE REMISE. Mesuré sous MAME (diagnostic du 2026-10-22,
        | relevé `aodk-ref-lspc-ecritures`) : la référence écrit REG_LSPCMODE ← $4000 et
        | REG_IRQACK ← 7 avant chacune des trois remises relevées — boot (trame 280), fin de
        | démo (748-751), pièce pendant la démo (949-951) —, à la trame même de la pièce.
        | `_retour_systeme` le faisait déjà ; la remise sur pièce (`_retour_piece`), non :
        | aodk, qui arme l'IRQ timer pendant sa démo, la recevait pendant que sa routine
        | USER se réinitialisait, et plantait. Ici, la même écriture couvre toutes les
        | remises ; elle double celle de `_retour_systeme` et du boot, sans effet de plus.
        move.w  #0x4000, 0x3C0006       | REG_LSPCMODE : IRQ timer coupée
        move.w  #7, 0x3C000C            | REG_IRQACK : les trois IRQ
        | BIOS_FRAME_SKIP À LA REMISE : $09 pour une demande 2 ou 3, laissé tel quel pour une
        | demande 0. MESURÉ sous MAME le 2026-10-22 (`bench/multislot.lua`, `MS_SUIVRE`, -bios
        | euro, puzzledp seul et puzzledp + aof ; `measured/2026-10-22-ecarts-remise-credit.tsv`) :
        | la référence pose $FF à la demande (pièce, SELECT, SYSTEM_RETURN), le recharge à $0A
        | la trame suivante et le décompte à $09 juste avant de rendre la main — 28 remises
        | de demande 2 ou 3 sur 28 (15 runs) entrent à $09, et $00 tombe 9 trames après. Nous
        | rendons la main sans trame tenue entre les deux : poser $FF ici le faisait recharger
        | à $0A par le premier SYSTEM_IO du jeu, et $00 tombait 11 trames après — START, le
        | son de la pièce et SELECT pris deux trames trop tard. Demande 0 : la première du boot entre à $00 (le
        | vidage de la RAM BIOS, plus haut), celle d'après un SYSTEM_RETURN à $FF
        | (`_retour_systeme`), comme chez la référence.
        | BIOS_SYSTEM_MODE AVANT LA REMISE : PLUS DE $01. MESURÉ sous MAME le 2026-10-23 (-bios
        | euro ; `measured/2026-10-23-led-et-remises.tsv`, section 3), la référence, sur 18
        | remises (boot, démo, titre après pièce, game over, fin de démo, SELECT) : $10FD80
        | ne reçoit avant la remise que la valeur de l'entrée de SYSTEM_RETURN, réécrite —
        | $00 (code 0, et la demande 0 du boot), $02 (codes 2, 3, 6, SELECT) —, puis $80 à une
        | demande 0 et $82 sinon. $01 n'y est vu que sur le chemin de son logo (b2b, pièce
        | pendant le logo : $01 puis $82), que nous n'avons pas ; les traces 2 et 9 le
        | montrent aussi, sur des chemins que ce relevé ne refait pas — d'où le $01 gardé à la
        | pièce en mode 0 (`_retour_piece`). Notre image posait $01 puis $82 à toutes.
        tst.b   %d2
        bne.s   3f
        move.b  #0x00, 0x10FD80         | demande 0 : $00, le BIOS a le vblank
        bra.s   4f
3:      move.b  #0x09, 0x10FEE1         | demande 2 ou 3 ; la demande 0 laisse FRAME_SKIP
4:      move.b  %d1, 0x10FDAF           | BIOS_USER_MODE
        | BIOS_PLAYER_MOD1-4 ($10FDB6-$10FDB9) ET LEURS COPIES ($10FDBA-$10FDBD) REMIS À ZÉRO.
        | MESURÉ sous MAME le 2026-10-23 (-bios euro, nam1975, aof, puzzledp + aof ;
        | `measured/2026-10-23-comptabilite.tsv`, section 2) : la référence écrit $0000 dans
        | les mots $10FDB8, $10FDB6, $10FDBC puis $10FDBA, juste après BIOS_USER_MODE, avant
        | CHACUNE des remises relevées — demandes 0 du boot, démo après le boot, titre après
        | une pièce, titre ou démo après un game over, démo après une fin de démo, titre après
        | SELECT. Notre image laissait le joueur « playing » ($01) d'une partie finie dans la
        | démo qui suit.
        clr.w   0x10FDB8
        clr.w   0x10FDB6
        clr.w   0x10FDBC
        clr.w   0x10FDBA
        bsr     _commutateurs           | BIOS_P1STATUS et $10FEF8 (plus bas)
        jsr     _af_charger             | l'autofire du jeu servi (`autofire.s`), registres rendus
        | REG_SOUND ← $03 AVANT LES REMISES DE SYSTEM_RETURN ET DE SELECT (%d3 non nul, demande
        | 2 ou 3), après les mots ci-dessus. MESURÉ sous MAME le 2026-10-23 (même relevé, section
        | 3) : la référence l'écrit dans la trame qui précède chaque remise de démo ou de titre,
        | après $10FDAF et ces mots — démo après le boot, après un game over, après une fin de
        | démo ; titre après pièce, game over ou SELECT. Notre image ne l'écrivait qu'avant un
        | titre. « 68k/Z80 communication » : $03 demande un reset, « No reply is expected ».
        | Pas au boot (`_slot_present`, %d3 nul) : le passage de slot vient de faire le sien.
        | L'ATTENTE (%d3 = 2, le titre de `_sysret_piece`, seul chemin qui l'avait avant ce lot) :
        | ~26 cycles par tour (`move.b` Dn vers abs.l 16, `dbra` pris 10), 3 200 tours ≈ 0,41
        | trame à 12 MHz, watchdog à chaque tour, IRQ masquées — mesuré, la référence remet la
        | main ~0,48 trame après son $03 (`protocole.md`, traces 4 et 7). Ailleurs (%d3 = 1), le
        | $03 sans attente, hors de celle de la ligne $1F0 qui suit : avec l'attente avant la
        | démo, la remise passait d'une trame, et kof94 sortait de la tolérance de la matrice de
        | non-régression (vifs 67 737 → 66 230, −2,22 % ; mesuré le 2026-10-23, l'attente seule
        | sans le $03 fait de même, le $03 seul non).
        tst.b   %d2
        beq.s   2f
        tst.b   %d3
        beq.s   2f
        move.b  #0x03, 0x320000         | REG_SOUND
        cmpi.b  #2, %d3
        bne.s   2f
        move.w  #3200-1, %d5
1:      move.b  %d0, 0x300001
        dbra    %d5, 1b
2:      move.b  %d2, 0x10FDAE           | BIOS_USER_REQUEST
        | BIOS_SYSTEM_MODE ← $80 À UNE DEMANDE 0, $82 SINON (mesuré, voir plus haut).
        moveq   #-0x7E, %d3             | $82
        tst.b   %d2
        bne.s   1f
        moveq   #-0x80, %d3             | $80
1:      cmpi.b  #1, %d2
        bne.s   1f
        moveq   #-0x7F, %d3             | $81 à la demande 1 (`_logo_aes`, mesuré)
1:      move.b  %d3, 0x10FD80           | le jeu a le vblank
        | BIOS_BRAM_USED ← $00 APRÈS $10FD80, mesuré (`_remise_tenue`) : à toutes les remises
        | relevées, demande 0 du boot comprise (2026-10-23, `measured/2026-10-23-titre-apres-
        | game-over.tsv`, section 1).
        move.b  #0x00, 0x10FEBF
        move.b  %d0, 0x300001           | un dernier coup de pied avant de partir

        | LA REMISE CALÉE SUR LE VBLANK. Mesuré sur `b2b`
        | (`measured/2026-10-17-diagnostic-b2b-minasan.tsv`, partie B2B) : la référence rend
        | la main à la phase 0,022 de la trame, nous à 0,898 ; le jeu ouvre ses IRQ avant
        | d'initialiser sa file de palette, et chez nous le vblank tombait entre les deux —
        | erreur d'adresse, boucle d'exceptions. Test causal, même relevé : attendre la
        | ligne $1F0 puis acquitter les trois IRQ ($3C000C ← 7) avant le `jmp`, et la
        | remise tombe à 0,003, plus aucune erreur sur 2000 trames ; l'acquittement seul ne
        | change rien. REG_LSPCMODE ($3C0006) se relit en compteur de ligne dans ses bits
        | 15-7 (même relevé). L'attente dure au plus une trame, sous le watchdog — et elle
        | est BORNÉE comme `.Lsync` (plus bas, même compte) : SYNC_TOURS tours de 70 cycles,
        | ≈ 2 trames, puis la main part quand même si la ligne n'a pas été vue. Un coup de
        | pied à chaque tour. Sous MAME la ligne est vue : la borne ne sert pas.
        move.w  #SYNC_TOURS - 1, %d5
1:      move.b  %d0, 0x300001           | watchdog
        move.w  0x3C0006, %d0
        lsr.w   #7, %d0
        cmpi.w  #0x1F0, %d0
        dbeq    %d5, 1b
        | L'entrée de `_retour_demo_end`, qui a servi son vblank et posé ce qui précède.
_remettre_partir:
        move.w  #7, 0x3C000C            | REG_IRQACK : vblank, timer, reset
        | LES REGISTRES DE DONNÉES À L'ENTRÉE DE USER. Mesuré sous MAME (diagnostic du
        | 2026-10-22, relevé `garou-registres-a-122-ref`, deux remises) : la référence entre
        | en $000122 avec %d2, %d3, %d6 à 0 et %d7 à $0000FFFF aux deux ; %d0 = 0, %d1 = $80,
        | %d4 = %d5 = 0 à la remise du boot (trame 280), d'autres valeurs à celle de la démo
        | (trame 501 : %d0 = 2, %d1 = $FF82, %d4 = 8, %d5 = $FF). Nous laissions des restes,
        | dont %d6 = $FFFF, valeur dont garou dépend à l'entrée (relevé
        | `garou-registres-a-122-notre`), et c'est le seul registre dont la nécessité a été
        | établie (diagnostic, sur l'image d'avant ce lot). Le reste dépend du chemin : sous
        | l'image de ce lot privée de cette seule écriture, %d6 arrive à 2 puis 1 et garou
        | passe aussi (mesuré le 2026-10-22). Les autres valeurs sont celles de la remise du
        | boot, recopiées par fidélité, sans preuve qu'un jeu en dépende ; %d6 seul (sans
        | les autres) suffit à garou, mesuré le même jour.
        | %d0 et %d5 sont posés ici parce que l'attente ci-dessus s'en sert.
        moveq   #0, %d0
        move.l  #0x80, %d1              | pas `moveq` : il étendrait le signe en $FFFFFF80
        moveq   #0, %d2
        moveq   #0, %d3
        moveq   #0, %d4
        moveq   #0, %d5
        moveq   #0, %d6
        move.l  #0xFFFF, %d7
        jmp     0x122

| ----------------------------------------------------------------------------------
| LA DEMANDE 1 DU MODE AES — l'animation de boot du jeu, à la place de la première démo de la
| mise sous tension. Appelée par les deux remises (`_remettre_a_user`, `_remise_tenue`). Entrée
| et sortie : %d1 le mode USER, %d2 la demande. Rien d'autre n'est touché.
|
| Lu dans « USER subroutine » : la demande 1 montre l'animation du jeu « when $114 = 1 », elle
| « is only called on AES », « once only at system start (before attract mode) and not again ».
| MESURÉ sous MAME le 2026-10-23 (`aes -bios asia`, six jeux ; `measured/2026-10-23-mode-aes.tsv`)
| : kof98 seul ($114 = 1) la reçoit, mode 0, juste après sa demande 0, $10FD81 ← $01 et
| BIOS_SYSTEM_MODE ← $81 avant elle ; puis la démo. Ici à chaque mise sous tension, puisque la
| demande 0 n'y revient pas (décision D5) : à la première remise d'une démo, une seule fois —
| BIOS_LOGO passe à 2 même sans animation, pour qu'un autre slot ne la reçoive pas en pleine
| rotation. Sans le mode AES, rien. $114 = 0 (l'eyecatcher du BIOS) : rien non plus, décision D6.
| BIOS_LOGO ($10FB08) : à nous, dans la zone qu'aucun jeu n'écrit (mesuré, `menu.s`), remise à
| zéro par le vidage du boot ; 1 = demande 1 donnée, 2 = faite (`.equ` en tête du fichier).
_logo_aes:
        jsr     _borne_remise           | DEMO SOUND : $D00046 selon la demande (`reglages.s`)
        cmpi.b  #2, %d2
        bne.s   9f                      | pas une démo
        tst.b   0x10FD82
        bne.s   9f                      | mode MVS
        tst.b   BIOS_LOGO
        bne.s   9f                      | déjà faite à ce boot
        move.b  #2, BIOS_LOGO
        cmpi.b  #1, 0x114               | « Eyecatcher animation flag », « 68k program header »
        bne.s   9f
        move.b  #1, BIOS_LOGO
        move.b  #0x01, 0x10FD81         | BIOS_SYSRET_STATUS, mesuré : le code 1 à son retour
        moveq   #0, %d1                 | BIOS_USER_MODE    = initialisation (mesuré : $00)
        moveq   #1, %d2                 | BIOS_USER_REQUEST = l'animation
9:      rts

| ----------------------------------------------------------------------------------
| LE PASSAGE DE LA LIGNE $1F0, pour la poignée de main du boot. Copie identique de celle de
| `ecran.s`, où sont la mesure et le compte de la borne : on attend de sortir de la ligne
| puis d'y entrer, chaque attente bornée à SYNC_TOURS tours (≈ 2 trames), watchdog à
| chaque tour. Clobbers %d0.
        .equ    WATCHDOG, 0x300001
        .equ    LSPCMODE, 0x3C0006
        .equ    SYNC_TOURS, 5800
.Lsync:
        move.l  %d1, -(%sp)
        move.w  #SYNC_TOURS - 1, %d1
1:      move.b  %d0, WATCHDOG
        move.w  LSPCMODE, %d0
        lsr.w   #7, %d0
        cmpi.w  #0x1F0, %d0
        dbne    %d1, 1b
        move.w  #SYNC_TOURS - 1, %d1
2:      move.b  %d0, WATCHDOG
        move.w  LSPCMODE, %d0
        lsr.w   #7, %d0
        cmpi.w  #0x1F0, %d0
        dbeq    %d1, 2b
        move.l  (%sp)+, %d1
        rts

| LA MÊME ATTENTE, qui s'arrête dès que REG_SOUND rend $01 : Z à 1 si l'écho est vu, à 0 si
| la ligne $1F0 est passée sans lui. Clobbers %d0.
.Lsync_ou_echo:
        move.l  %d1, -(%sp)
        move.w  #SYNC_TOURS - 1, %d1
1:      move.b  %d0, WATCHDOG
        cmpi.b  #0x01, 0x320000
        beq.s   9f
        move.w  LSPCMODE, %d0
        lsr.w   #7, %d0
        cmpi.w  #0x1F0, %d0
        dbne    %d1, 1b
        move.w  #SYNC_TOURS - 1, %d1
2:      move.b  %d0, WATCHDOG
        cmpi.b  #0x01, 0x320000
        beq.s   9f
        move.w  LSPCMODE, %d0
        lsr.w   #7, %d0
        cmpi.w  #0x1F0, %d0
        dbeq    %d1, 2b
        moveq   #1, %d0                 | Z à 0 : pas d'écho
9:      movem.l (%sp)+, %d1             | `movem` ne touche pas Z
        rts

| ----------------------------------------------------------------------------------
| LA SIGNATURE DE LA BACKUP RAM — les 16 octets de $D00010-$D0001F, mesurés : l'ASCII
| `BACKUP RAM OK !`, puis $80. Le boot la compare et, au formatage, l'écrit en dernier.
| ----------------------------------------------------------------------------------
        .balign 2
_signature_bram:
        .ascii  "BACKUP RAM OK !"
        .byte   0x80
