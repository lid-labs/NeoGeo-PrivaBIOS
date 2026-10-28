| SPDX-License-Identifier: GPL-3.0-or-later
| Copyright (C) 2026 Thibaut Lion
| ==================================================================================
| FIX_CLEAR ($C004C2) ET LSP_1st ($C004C8) — deux entrées du tableau d'appels, la vidéo.
|
| Les créneaux de six octets de `c0.s` ne portent qu'un `jmp` : le code vit ici, dans
| `.text`, que `build/bios.ld` lie après `.vectors`, donc au-delà de $C00800.
|
| TROIS SORTES D'AFFIRMATIONS, et chacune le dit :
|   « mesuré »  : un contrat de `specs/traces/`, nommé — `appel_C004C2.md` (8 appels),
|                 `appel_C004C8.md` (4 appels) ;
|   « lu dans » : une page du NeoGeo Development Wiki, nommée ;
|   « SUPPOSÉ » : ni l'un ni l'autre, et c'est dit.
|
| LA VRAM NE SE VOIT QUE PAR TROIS REGISTRES. Lu dans « VRAM » : REG_VRAMADDR ($3C0000)
| pose l'adresse, REG_VRAMRW ($3C0002) porte la donnée, REG_VRAMMOD ($3C0004) est le pas
| ajouté à l'adresse après chaque écriture. Ces deux appels n'écrivent rien d'autre.
|
| LE RYTHME DES ÉCRITURES. Lu dans « VRAM », Access timing : 12 cycles CPU au moins
| entre deux données, 16 entre une donnée et l'adresse qui suit. La boucle
| `move.w %d0,(%a0)` (8 cycles) + `dbra` pris (10) en met 18 entre deux données ; après
| la sortie de boucle, `dbra` non pris (14) précède l'écriture d'adresse suivante.
|
| CE QUE CES ROUTINES NE FONT PAS, délibérément : les écritures « d'une partie des
| appels seulement » des deux contrats ($10F2xx, $10FD9x-$10FEFx, $3800xx, $3A00xx,
| backup RAM). La pile $10F2xx est celle de la référence ; le reste, une SYSTEM_INT1
| tombée pendant l'appel chez elle. Les IRQ ne sont pas masquées ici, ET NOTRE INT1 ÉCRIT LES
| REGISTRES VRAM : `int1.s` appelle MESS_OUT (`mess.s`), qui pose REG_VRAMADDR, REG_VRAMMOD et
| écrit REG_VRAMRW dès que le tampon BIOS_MESS_BUFFER n'est pas vide et que BIOS_MESS_BUSY
| ($10FDC2) n'est pas levé (lu dans le code). Un FIX_CLEAR ou un LSP_1st appelé IRQ ouvertes
| avec un tampon non vide peut donc être coupé par une INT1 : la suite du remplissage repart
| de l'adresse et du pas que MESS_OUT a laissés, des cases visées restent sans écriture et
| d'autres en reçoivent une à tort. Rien ici ne s'en garde ; c'est à l'appelant de masquer
| les IRQ ou de vider le tampon avant l'appel. Le BIOS lui-même les appelle IRQ masquées.
| ==================================================================================

        | En zone haute depuis le 2026-10-25 : $C02000-$C03FFF est la grille (`grille.s`).
        .section .haut, "ax"
        .global _fix_clear
        .global _lsp_1st

| ----------------------------------------------------------------------------------
| FIX_CLEAR — atteinte par `jmp` depuis $C004C2 ; le jeu y entre par `jsr` et en
| repart par notre `rts`.
|
| Lu dans « FIX_CLEAR » : « Clears all the fix layer with tile # $FF, palette 0. The
| leftmost and rightmost columns are cleared with tile # $20, palette 0. » Lu dans
| « Fix layer » : la carte est en VRAM à $7000, 40 × 32 = 1 280 mots, un mot par case
| (palette dans les 4 bits hauts, tuile dans les 12 bas), rangés « top to bottom, and
| left to right » — une colonne fait donc 32 mots consécutifs. D'où, avec un pas de 1 :
|   $7000-$701F  colonne 0   ← $0020, 32 mots
|   $7020-$74DF  colonnes 1 à 38 ← $00FF, 38 × 32 = 1 216 mots
|   $74E0-$74FF  colonne 39  ← $0020, 32 mots
| Mesuré (`appel_C004C2.md`, noyau) : $3C0000 ← $7000 et $7020, $3C0002 ← $0020 et
| $00FF, $3C0004 ← $0001 — ces valeurs, et aucune autre. Les 5 173 à 6 279 accès par
| appel sont l'ordre de grandeur des 1 280 écritures et de leur boucle.
|
| L'ADRESSE $7020 EST REDONDANTE : l'auto-incrément y est déjà au bout de la colonne 0.
| On l'écrit parce que le contrat la montre à chaque appel. L'ordre des trois zones,
| que le contrat ne donne pas (ses listes sont triées), est SUPPOSÉ : celui des adresses.
| La colonne 39 suit la 38 sans nouvelle adresse, ce qui explique que $74E0 n'apparaisse
| pas au contrat.
|
| REGISTRES. Lu dans « FIX_CLEAR » : « register contents aren't preserved ! (Uses D0, D1,
| and A0) ». On n'use que de ces trois-là ; les autres sont rendus intacts.
| En sortie, REG_VRAMMOD vaut $0001, la seule valeur que le contrat montre.
| ----------------------------------------------------------------------------------
_fix_clear:
        lea     0x3C0002, %a0           | REG_VRAMRW
        move.w  #0x0001, 0x3C0004       | REG_VRAMMOD  : pas de 1
        move.w  #0x7000, 0x3C0000       | REG_VRAMADDR : colonne 0

        move.w  #0x0020, %d0            | tuile $20, palette 0 : le masque des bords
        moveq   #32-1, %d1
1:      move.w  %d0, (%a0)
        dbra    %d1, 1b

        move.w  #0x7020, 0x3C0000       | REG_VRAMADDR : colonne 1
        move.w  #0x00FF, %d0            | tuile $FF, palette 0 : l'espace
        move.w  #(38*32)-1, %d1
2:      move.w  %d0, (%a0)
        dbra    %d1, 2b

        move.w  #0x0020, %d0            | colonne 39, à la suite : $74E0-$74FF
        moveq   #32-1, %d1
3:      move.w  %d0, (%a0)
        dbra    %d1, 3b
        rts

| ----------------------------------------------------------------------------------
| LSP_1st — atteinte par `jmp` depuis $C004C8 ; le jeu y entre par `jsr` et en repart
| par notre `rts`.
|
| Lu dans « LSP_1st » (« LSP_1ST ($C004C8): Clear sprites ») :
|   - « all SCB2 is set to $0FFF » (réduction au maximum) ;
|   - « all SCB3 is set to $0000 » (hauteur 0, Y = 496) ;
|   - « all SCB4 is set to $BE00 » (X = 380) ;
|   - « The map of sprite #0 is set to tiles # $FF (SCB1 $0000~$0040 to $00FF,$0000) ».
| Lu dans « Sprites » : SCB2, SCB3 et SCB4 commencent à $8000, $8200 et $8400 et font
| $200 mots chacun — contigus, donc 1 536 mots d'un seul tenant depuis $8000. Lu dans
| « VRAM » : passer de la zone basse ($0000-$7FFF) à la haute exige de reposer
| l'adresse, pas de compter sur l'auto-incrément — d'où les deux adresses du contrat.
|
| Mesuré (`appel_C004C8.md`, noyau) : $3C0000 ← $0000 et $8000, $3C0002 ← $0000, $00FF,
| $0FFF, $BE00, $3C0004 ← $0001 et $0002. 6 344 accès par appel.
|
| SCB1 PAR UN PAS DE 2 — SUPPOSÉ, et c'est le choix qui pèse. Le contrat montre $0002 sur
| REG_VRAMMOD à chaque appel, et seulement deux adresses, $0000 et $8000. Un pas de 2
| depuis $0000 touche les mots pairs de la carte du sprite 0 — ses 32 numéros de tuile
| (« Sprites », SCB1 : un mot de tuile puis un mot d'attributs par tuile) — et finit à
| $0040, la borne qu'écrit la page. Les mots d'attributs (impairs) ne sont alors PAS
| écrits : les atteindre demanderait l'adresse $0001, absente du contrat. La page dit
| « $00FF,$0000 » ; je lis le « $0000 » comme l'attribut constaté, pas comme une écriture
| — lecture contestable. Sans conséquence à l'écran : SCB3 à $0000 donne au sprite 0 une
| hauteur nulle. L'autre lecture — pas de 1, paires $00FF/$0000 sur 64 mots — tient
| aussi dans le contrat, mais n'y donne aucun rôle à la valeur $0002.
|
| L'ORDRE — SUPPOSÉ. Le contrat trie ses listes, la page énumère sans ordonner. SCB1
| d'abord, la zone haute ensuite : REG_VRAMMOD sort à $0001, la valeur que FIX_CLEAR
| laisse aussi, ce qui sert un jeu qui enchaîne les deux et écrit ensuite sans reposer
| le pas. REG_VRAMADDR sort à $8600 : « VRAM address is modified », dit la page.
|
| REGISTRES. Lu dans « LSP_1st » : « Uses D0, D1, and A0 ». Comme FIX_CLEAR.
| ----------------------------------------------------------------------------------
_lsp_1st:
        lea     0x3C0002, %a0           | REG_VRAMRW

        | SCB1 du sprite 0 : 32 numéros de tuile, pas de 2.
        move.w  #0x0002, 0x3C0004       | REG_VRAMMOD  : pas de 2
        move.w  #0x0000, 0x3C0000       | REG_VRAMADDR : SCB1, sprite 0
        move.w  #0x00FF, %d0            | tuile $FF
        moveq   #32-1, %d1
1:      move.w  %d0, (%a0)
        dbra    %d1, 1b

        | SCB2, SCB3, SCB4 : 3 × 512 mots à la suite, pas de 1.
        move.w  #0x0001, 0x3C0004       | REG_VRAMMOD  : pas de 1
        move.w  #0x8000, 0x3C0000       | REG_VRAMADDR : SCB2
        move.w  #0x0FFF, %d0            | SCB2 : réduction maximale
        move.w  #512-1, %d1
2:      move.w  %d0, (%a0)
        dbra    %d1, 2b
        moveq   #0, %d0                 | SCB3 ($8200) : hauteur 0, Y = 496
        move.w  #512-1, %d1
3:      move.w  %d0, (%a0)
        dbra    %d1, 3b
        move.w  #0xBE00, %d0            | SCB4 ($8400) : X = 380
        move.w  #512-1, %d1
4:      move.w  %d0, (%a0)
        dbra    %d1, 4b
        rts
