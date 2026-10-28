# L'autofire : les jeux où il marche

Sprixe BIOS a un autofire réglable jeu par jeu, dans le menu en jeu (`MENUS.md`, AUTOFIRE). Il ne marche
pas sur tous les jeux, et ce n'est pas un réglage qui y changerait quelque chose : c'est le jeu qui
décide où il lit sa manette. Cette page dit, jeu par jeu, ce qui a été mesuré.

## Pourquoi il ne marche pas partout

Le BIOS lit la manette à chaque trame et range ce qu'il a lu dans sa RAM ; l'autofire agit là, en
faisant voir au jeu le bouton relâché une partie du temps. Un jeu qui lit ces cases du BIOS voit le
turbo. Un jeu qui lit la manette lui-même, directement sur le matériel, ne le voit pas, et aucun BIOS
n'y peut rien. Entre les deux, certains jeux lisent les deux, ou ne demandent pas leurs entrées au BIOS
exactement une fois par trame : le turbo y est irrégulier.

## Ce qui a été mesuré, et ce qui ne l'a pas été

Mesuré le 2026-10-27 sous MAME, sur 164 jeux, avant que la fonction n'entre dans le BIOS (un
prototype qui calcule le turbo comme lui) : pour chaque jeu, une partie scriptée, le bouton A du
joueur 1 tenu avec le turbo, comparé au même bouton tapé à la main au même rythme. « Marche » veut
dire que les deux parties sont identiques, image par image : **le jeu voit le turbo**. Cela ne promet
pas plus de tirs à l'écran : un jeu peut ignorer des appuis trop rapprochés, ou n'avoir rien à
tirer avec A.

- Seul **A du joueur 1** a été mesuré. B, C, D et le joueur 2 passent par le même calcul et sont
  supposés suivre, sans mesure.
- Une seule partie par jeu, dans les premières secondes de jeu.
- Le classement suit la cadence par défaut, 15 tirs/s ; quand une autre cadence donne un autre
  résultat, la ligne le dit. Le détail, cadence par cadence : `measured/2026-10-27-autofire.tsv`.
- Avec le commutateur 3 de la carte à ON (panneau de mahjong), l'autofire est coupé, joueur 2 compris.

## Le turbo marche (89)

- 2020 Super Baseball (set 1) (`2020bb`)
- Alpha Mission II / ASO II - Last Guardian (NGM-007 ~ NGH-007) (`alpham2`)
- Art of Fighting / Ryuuko no Ken (NGM-044 ~ NGH-044) (`aof`)
- Bang Bead (`bangbead`)
- Baseball Stars 2 (`bstars2`)
- Baseball Stars Professional (NGM-002) (`bstars`)
- Breakers (`breakers`)
- Breakers Revenge (`breakrev`)
- Burning Fight (NGM-018 ~ NGH-018) (`burningf`)
- Captain Tomaday (`ctomaday`)
- Chibi Maruko-chan: Maruko Deluxe Quiz (`marukodq`)
- Choutetsu Brikin'ger / Iron Clad (prototype) (`ironclad`)
- Crossed Swords 2 (bootleg of CD version) (`crswd2bl`)
- Cyber-Lip (NGM-010) (`cyberlip`)
- Double Dragon (Neo-Geo) (`doubledr`)
- Far East of Eden - Kabuki Klash / Tengai Makyou - Shin Den (`kabukikl`)
- Fatal Fury - King of Fighters / Garou Densetsu - Shukumei no Tatakai (NGM-033 ~ NGH-033) (`fatfury1`)
- Fatal Fury 2 / Garou Densetsu 2 - Arata-naru Tatakai (NGM-047 ~ NGH-047) (`fatfury2`)
- Fatal Fury 3 - Road to the Final Victory / Garou Densetsu 3 - Haruka-naru Tatakai (NGM-069 ~ NGH-069) (`fatfury3`)
- Fatal Fury Special / Garou Densetsu Special (NGM-058 ~ NGH-058, set 1) (`fatfursp`)
- Fight Fever / Wang Jung Wang (set 1) (`fightfev`)
- Flip Shot (`flipshot`)
- Galaxy Fight - Universal Warriors (`galaxyfg`)
- Garou - Mark of the Wolves (NGM-2530) (`garou`)
- Ghost Pilots (NGM-020 ~ NGH-020) (`gpilots`)
- Idol Mahjong Final Romance 2 (Neo-Geo, bootleg of CD version) (`froman2b`)
- Karnov's Revenge / Fighter's History Dynamite (`karnovr`)
- King of the Monsters (set 1) (`kotm`)
- King of the Monsters 2 - The Next Thing (NGM-039 ~ NGH-039) (`kotm2`)
- Kizuna Encounter - Super Tag Battle / Fu'un Super Tag Battle (`kizuna`)
- Last Resort (`lresort`)
- League Bowling (NGM-019 ~ NGH-019) (`lbowling`)
- Legend of Success Joe / Ashita no Joe Densetsu (`legendos`)
- Mahjong Kyo Retsuden (NGM-004 ~ NGH-004) (`mahretsu`)
- Metal Slug - Super Vehicle-001 (`mslug`)
- Mutation Nation (NGM-014 ~ NGH-014) (`mutnat`)
- Neo Bomberman (`neobombe`)
- Neo Drift Out - New Technology (`neodrift`)
- Neo Mr. Do! (`neomrdo`)
- Neo Turf Masters / Big Tournament Golf (`turfmast`)
- Neo-Geo Cup '98 - The Road to the Victory (`neocup98`)
- Over Top (`overtop`)
- Pleasure Goal / Futsal - 5 on 5 Mini Soccer (NGM-219) (`pgoal`)
- Pochi and Nyaa (Ver 2.02) (`pnyaa`)
- Power Spikes II (NGM-068) (`pspikes2`) — 30 tirs/s : partiel, 10 tirs/s : marche
- Prehistoric Isle 2 (`preisle2`)
- Puzzle Bobble / Bust-A-Move (Neo-Geo, NGM-083) (`pbobblen`)
- Puzzle Bobble 2 / Bust-A-Move Again (Neo-Geo) (`pbobbl2n`)
- Puzzle De Pon! (`puzzledp`)
- Puzzle De Pon! R! (`puzzldpr`)
- Puzzled / Joy Joy Kid (NGM-021 ~ NGH-021) (`joyjoy`)
- Quiz Daisousa Sen - The Last Count Down (NGM-023 ~ NGH-023) (`quizdais`) — 30 tirs/s : marche, 10 tirs/s : partiel
- Quiz King of Fighters (SAM-080 ~ SAH-080) (`quizkof`)
- Quiz Meitantei Neo & Geo - Quiz Daisousa Sen part 2 (NGM-042 ~ NGH-042) (`quizdai2`)
- Ragnagard / Shin-Oh-Ken (`ragnagrd`)
- Real Bout Fatal Fury / Real Bout Garou Densetsu (NGM-095 ~ NGH-095) (`rbff1`)
- Real Bout Fatal Fury 2 - The Newcomers / Real Bout Garou Densetsu 2 - The Newcomers (NGM-2400) (`rbff2`)
- Real Bout Fatal Fury Special / Real Bout Garou Densetsu Special (`rbffspec`)
- Samurai Shodown III / Samurai Spirits - Zankurou Musouken (NGM-087) (`samsho3`)
- Samurai Shodown IV - Amakusa's Revenge / Samurai Spirits - Amakusa Kourin (NGM-222 ~ NGH-222) (`samsho4`)
- Samurai Shodown V / Samurai Spirits Zero (NGM-2700, set 1) (`samsho5`)
- Samurai Shodown V Special / Samurai Spirits Zero Special (NGM-2720) (`samsh5sp`)
- Savage Reign / Fu'un Mokushiroku - Kakutou Sousei (`savagere`)
- Shock Troopers (set 1) (`shocktro`)
- Shock Troopers - 2nd Squad (`shocktr2`)
- Shougi no Tatsujin - Master of Shougi (`moshougi`)
- SNK vs. Capcom - SVC Chaos (NGM-2690 ~ NGH-2690) (`svc`)
- Spin Master / Miracle Adventure (`spinmast`)
- Stakes Winner 2 (`stakwin2`)
- Super Bubble Pop (`sbp`)
- Super Sidekicks / Tokuten Ou (`ssideki`)
- Super Sidekicks 2 - The World Championship / Tokuten Ou 2 - Real Fight Football (NGM-061 ~ NGH-061) (`ssideki2`)
- Super Sidekicks 3 - The Next Glory / Tokuten Ou 3 - Eikou e no Chousen (`ssideki3`)
- Tecmo World Soccer '96 (`twsoc96`)
- The King of Fighters 2000 (NGM-2570 ~ NGH-2570) (`kof2000`)
- The King of Fighters 2003 (NGM-2710, Export) (`kof2003`)
- The Super Spy (NGM-011 ~ NGH-011) (`superspy`)
- The Ultimate 11 - The SNK Football Championship / Tokuten Ou - Honoo no Libero (`ssideki4`)
- Top Hunter - Roddy & Cathy (NGM-046) (`tophuntr`)
- Top Player's Golf (NGM-003 ~ NGH-003) (`tpgolf`)
- Twinkle Star Sprites (`twinspri`)
- Viewpoint (`viewpoin`)
- Waku Waku 7 (`wakuwak7`)
- Windjammers / Flying Power Disc (`wjammers`)
- World Heroes 2 Jet (ADM-007 ~ ADH-007) (`wh2j`)
- World Heroes Perfect (`whp`)
- Zed Blade / Operation Ragnarok (`zedblade`)
- Zintrick / Oshidashi Zentrix (bootleg of CD version) (`zintrckb`)
- Zupapa! (`zupapa`)

## Partiel ou irrégulier (25)

- Aggressors of Dark Kombat / Tsuukai GANGAN Koushinkyoku (ADM-008 ~ ADH-008) (`aodk`)
- Art of Fighting 2 / Ryuuko no Ken 2 (NGM-056) (`aof2`)
- Art of Fighting 3 - The Path of the Warrior / Art of Fighting - Ryuuko no Ken Gaiden (`aof3`)
- Bang Bang Busters (2010 NCI release) (`b2b`)
- Crossed Swords (ALM-002 ~ ALH-002) (`crsword`)
- Digger Man (prototype) (`diggerma`)
- Football Frenzy (NGM-034 ~ NGH-034) (`fbfrenzy`)
- Ghostlop (prototype) (`ghostlop`) — 30 tirs/s : marche, 10 tirs/s : marche
- Goal! Goal! Goal! (`goalx3`) — 30 tirs/s : marche, 10 tirs/s : marche
- Metal Slug 2 - Super Vehicle-001/II (NGM-2410 ~ NGH-2410) (`mslug2`)
- Metal Slug 5 (NGM-2680) (`mslug5`)
- Nightmare in the Dark (`nitd`)
- Ninja Commando (`ncommand`)
- Ninja Master's - Haoh-ninpo-cho (`ninjamas`) — 30 tirs/s : marche, 10 tirs/s : partiel
- Panic Bomber (`panicbom`)
- Pulstar (`pulstar`)
- Samurai Shodown / Samurai Spirits (NGM-045) (`samsho`) — 30 tirs/s : partiel, 10 tirs/s : marche
- Samurai Shodown II / Shin Samurai Spirits - Haohmaru Jigokuhen (NGM-063 ~ NGH-063) (`samsho2`)
- Stakes Winner / Stakes Winner - GI Kinzen Seiha e no Michi (`stakwin`)
- The King of Fighters '98 - The Slugfest / King of Fighters '98 - Dream Match Never Ends (NGM-2420) (`kof98`)
- The King of Fighters '99 - Millennium Battle (NGM-2510) (`kof99`)
- The King of Fighters 2001 (NGM-262?) (`kof2001`)
- The King of Fighters 2002 (NGM-2650 ~ NGH-2650) (`kof2002`)
- World Heroes (ALM-005) (`wh1`) — 30 tirs/s : partiel, 10 tirs/s : marche
- World Heroes 2 (ALM-006 ~ ALH-006) (`wh2`)

## Sans effet : le jeu lit la manette lui-même (35)

- 3 Count Bout / Fire Suplex (NGM-043 ~ NGH-043) (`3countb`)
- Aero Fighters 2 / Sonic Wings 2 (`sonicwi2`)
- Aero Fighters 3 / Sonic Wings 3 (`sonicwi3`)
- Andro Dunos (NGM-049 ~ NGH-049) (`androdun`)
- Blazing Star (`blazstar`)
- Blue's Journey / Raguy (ALM-001 ~ ALH-001) (`bjourney`)
- Dragon's Heaven (development board) (`dragonsh`)
- Ganryu / Musashi Ganryuki (`ganryu`)
- Gururin (`gururin`)
- Jockey Grand Prix (set 1) (`jockeygp`)
- Last Hope (bootleg AES to MVS conversion, no coin support) (`lasthope`)
- Magical Drop II (`magdrop2`)
- Magical Drop III (`magdrop3`)
- Magician Lord (NGM-005) (`maglord`)
- Matrimelee / Shin Gouketsuji Ichizoku Toukon (NGM-2660 ~ NGH-2660) (`matrim`)
- Metal Slug 3 (NGM-2560) (`mslug3`)
- Metal Slug 4 (NGM-2630) (`mslug4`)
- Metal Slug X - Super Vehicle-001 (NGM-2500 ~ NGH-2500) (`mslugx`)
- Money Puzzle Exchanger / Money Idol Exchanger (`miexchng`)
- NAM-1975 (NGM-001 ~ NGH-001) (`nam1975`)
- Ninja Combat (NGM-009) (`ncombat`)
- Rage of the Dragons (NGM-2640?) (`rotd`)
- Sengoku / Sengoku Denshou (NGM-017 ~ NGH-017) (`sengoku`)
- Sengoku 2 / Sengoku Denshou 2 (`sengoku2`)
- Sengoku 3 / Sengoku Densho 2001 (set 1) (`sengoku3`)
- Street Hoop / Street Slam / Dunk Dream (DEM-004 ~ DEH-004) (`strhoop`)
- Strikers 1945 Plus (`s1945p`)
- Super Dodge Ball / Kunio no Nekketsu Toukyuu Densetsu (`sdodgeb`)
- The King of Fighters '94 (NGM-055 ~ NGH-055) (`kof94`)
- The King of Fighters '95 (NGM-084) (`kof95`)
- The King of Fighters '96 (NGM-214) (`kof96`)
- The King of Fighters '97 (NGM-2320) (`kof97`)
- The Last Blade / Bakumatsu Roman - Gekka no Kenshi (NGM-2340) (`lastblad`)
- The Last Blade 2 / Bakumatsu Roman - Dai Ni Maku Gekka no Kenshi (NGM-2430 ~ NGH-2430) (`lastbld2`)
- Voltage Fighter - Gowcaizer / Choujin Gakuen Gowcaizer (`gowcaizr`)

## Non mesuré (15)

- Bakatonosama Mahjong Manyuuki (MOM-002 ~ MOH-002) (`bakatono`) — pas de manette standard (panneau ou commande propre au jeu)
- Eight Man (NGM-025 ~ NGH-025) (`eightman`) — A sans effet visible dans la partie scriptée
- Janshin Densetsu - Quest of Jongmaster (`janshin`) — pas de manette standard (panneau ou commande propre au jeu)
- Minasan no Okagesamadesu! Dai Sugoroku Taikai (MOM-001 ~ MOH-001) (`minasan`) — pas de manette standard (panneau ou commande propre au jeu)
- MVS-TEMP 'SubSystem Ver1.4' (Nazca development board) (`mvstemp`) — A sans effet visible dans la partie scriptée
- Neo-Geo MV-1 (`ng_mv1`) — la machine sans cartouche, pas un jeu
- Neo-Geo MV-2F (`ng_mv2f`) — la machine sans cartouche, pas un jeu
- Neo-Geo MV-4F (`ng_mv4f`) — la machine sans cartouche, pas un jeu
- Pop 'n Bounce / Gapporin (`popbounc`) — pas de manette standard (panneau ou commande propre au jeu)
- Riding Hero (NGM-006 ~ NGH-006) (`ridhero`) — A sans effet visible dans la partie scriptée
- Robo Army (`roboarmy`) — A sans effet visible dans la partie scriptée
- Soccer Brawl (NGM-031) (`socbrawl`) — A sans effet visible dans la partie scriptée
- The Irritating Maze / Ultra Denryu Iraira Bou (`irrmaze`) — MAME ne charge pas d’autre BIOS pour ce jeu
- Thrash Rally (ALM-003 ~ ALH-003) (`trally`) — A sans effet visible dans la partie scriptée
- V-Liner (v0.7a) (`vliner`) — pas de manette standard (panneau ou commande propre au jeu)

