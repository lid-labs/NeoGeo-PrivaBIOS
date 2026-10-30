# Autofire: the games where it works

Sprixe BIOS has an autofire set game by game, in the in-game menu (`MENUS.md`, AUTOFIRE). It does
not work on every game, and that is not something a setting would change: it is the game that
decides where it reads its joystick. This page says, game by game, what was measured.

## Why it does not work everywhere

The BIOS reads the joystick every frame and stores what it read in its RAM; autofire acts there, by
making the game see the button released part of the time. A game that reads those BIOS locations
sees the turbo. A game that reads the joystick itself, directly on the hardware, does not see it,
and no BIOS can do anything about that. In between, some games read both, or do not ask the BIOS
for their inputs exactly once per frame: the turbo is irregular there.

## What was measured, and what was not

Measured on 2026-10-27 under MAME, on 164 games, before the function went into the BIOS (a
prototype that computes the turbo the same way): for each game, a scripted session, player 1's A
button held with the turbo, compared with the same button tapped by hand at the same rate. "Works"
means that the two sessions are identical, frame by frame: **the game sees the turbo**. This does
not promise more shots on screen: a game may ignore presses that come too close together, or have
nothing to fire with A.

- Only **player 1's A** was measured. B, C, D and player 2 go through the same computation and are
  assumed to follow, without measurement.
- A single session per game, in the first seconds of play.
- The classification follows the default rate, 15 shots/s; when another rate gives another
  result, the line says so. The detail, rate by rate: `measured/2026-10-27-autofire.tsv`.
- With board switch 3 at ON (mahjong panel), autofire is off, player 2 included.

## The turbo works (89)

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
- Power Spikes II (NGM-068) (`pspikes2`) — 30 shots/s: partial, 10 shots/s: works
- Prehistoric Isle 2 (`preisle2`)
- Puzzle Bobble / Bust-A-Move (Neo-Geo, NGM-083) (`pbobblen`)
- Puzzle Bobble 2 / Bust-A-Move Again (Neo-Geo) (`pbobbl2n`)
- Puzzle De Pon! (`puzzledp`)
- Puzzle De Pon! R! (`puzzldpr`)
- Puzzled / Joy Joy Kid (NGM-021 ~ NGH-021) (`joyjoy`)
- Quiz Daisousa Sen - The Last Count Down (NGM-023 ~ NGH-023) (`quizdais`) — 30 shots/s: works, 10 shots/s: partial
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

## Partial or irregular (25)

- Aggressors of Dark Kombat / Tsuukai GANGAN Koushinkyoku (ADM-008 ~ ADH-008) (`aodk`)
- Art of Fighting 2 / Ryuuko no Ken 2 (NGM-056) (`aof2`)
- Art of Fighting 3 - The Path of the Warrior / Art of Fighting - Ryuuko no Ken Gaiden (`aof3`)
- Bang Bang Busters (2010 NCI release) (`b2b`)
- Crossed Swords (ALM-002 ~ ALH-002) (`crsword`)
- Digger Man (prototype) (`diggerma`)
- Football Frenzy (NGM-034 ~ NGH-034) (`fbfrenzy`)
- Ghostlop (prototype) (`ghostlop`) — 30 shots/s: works, 10 shots/s: works
- Goal! Goal! Goal! (`goalx3`) — 30 shots/s: works, 10 shots/s: works
- Metal Slug 2 - Super Vehicle-001/II (NGM-2410 ~ NGH-2410) (`mslug2`)
- Metal Slug 5 (NGM-2680) (`mslug5`)
- Nightmare in the Dark (`nitd`)
- Ninja Commando (`ncommand`)
- Ninja Master's - Haoh-ninpo-cho (`ninjamas`) — 30 shots/s: works, 10 shots/s: partial
- Panic Bomber (`panicbom`)
- Pulstar (`pulstar`)
- Samurai Shodown / Samurai Spirits (NGM-045) (`samsho`) — 30 shots/s: partial, 10 shots/s: works
- Samurai Shodown II / Shin Samurai Spirits - Haohmaru Jigokuhen (NGM-063 ~ NGH-063) (`samsho2`)
- Stakes Winner / Stakes Winner - GI Kinzen Seiha e no Michi (`stakwin`)
- The King of Fighters '98 - The Slugfest / King of Fighters '98 - Dream Match Never Ends (NGM-2420) (`kof98`)
- The King of Fighters '99 - Millennium Battle (NGM-2510) (`kof99`)
- The King of Fighters 2001 (NGM-262?) (`kof2001`)
- The King of Fighters 2002 (NGM-2650 ~ NGH-2650) (`kof2002`)
- World Heroes (ALM-005) (`wh1`) — 30 shots/s: partial, 10 shots/s: works
- World Heroes 2 (ALM-006 ~ ALH-006) (`wh2`)

## No effect: the game reads the joystick itself (35)

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

## Not measured (15)

- Bakatonosama Mahjong Manyuuki (MOM-002 ~ MOH-002) (`bakatono`) — no standard joystick (panel or controller specific to the game)
- Eight Man (NGM-025 ~ NGH-025) (`eightman`) — A has no visible effect in the scripted session
- Janshin Densetsu - Quest of Jongmaster (`janshin`) — no standard joystick (panel or controller specific to the game)
- Minasan no Okagesamadesu! Dai Sugoroku Taikai (MOM-001 ~ MOH-001) (`minasan`) — no standard joystick (panel or controller specific to the game)
- MVS-TEMP 'SubSystem Ver1.4' (Nazca development board) (`mvstemp`) — A has no visible effect in the scripted session
- Neo-Geo MV-1 (`ng_mv1`) — the machine without a cartridge, not a game
- Neo-Geo MV-2F (`ng_mv2f`) — the machine without a cartridge, not a game
- Neo-Geo MV-4F (`ng_mv4f`) — the machine without a cartridge, not a game
- Pop 'n Bounce / Gapporin (`popbounc`) — no standard joystick (panel or controller specific to the game)
- Riding Hero (NGM-006 ~ NGH-006) (`ridhero`) — A has no visible effect in the scripted session
- Robo Army (`roboarmy`) — A has no visible effect in the scripted session
- Soccer Brawl (NGM-031) (`socbrawl`) — A has no visible effect in the scripted session
- The Irritating Maze / Ultra Denryu Iraira Bou (`irrmaze`) — MAME does not load another BIOS for this game
- Thrash Rally (ALM-003 ~ ALH-003) (`trally`) — A has no visible effect in the scripted session
- V-Liner (v0.7a) (`vliner`) — no standard joystick (panel or controller specific to the game)

