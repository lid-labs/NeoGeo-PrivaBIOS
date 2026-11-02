# Imported cheats: what was checked

Sprixe BIOS has 1,709 cheats for 154 games. 1,568 of them come from the MAME XML Cheats
Collection (Pugsy and contributors), through `bench/cheats-importer.py`. This page says what was checked on those 1,568, game by game.

## What was measured, and what was not

Measured on 2026-11-01 under MAME 0.286, with `bench/cheats-recherche.py importes`. For each game,
a test run plays the game with no cheat. Then each cheat gets its own run: the same inputs, the
cheat's values written from frame 3600 to frame 4210 (once only for one-shot cheats), and pictures
taken at frames 4000, 4100 and 4200.

- **ok**: MAME did not stop, the picture did not freeze, and the game did not leave play before the
  test run did, over 610 frames (less on 5 games, where the test run leaves play first). It does
  **not** say that the cheat does what its title says.
- **Leave play**: the game left play before the test run. The four cheats concerned are FINISH
  cheats, which is what they announce.
- **Not judged**: the test run could not serve as a reference, so none of the game's cheats was
  judged.
- The values were written by the bench, not by the BIOS cheat engine, and not through the in-game
  menu.
- A control cheat that freezes fatfury1 was caught as frozen: the check can fail.

Counts: 1,464 ok, 4 leave play, 100 not judged, none freezes the game or stops MAME. The detail,
cheat by cheat: `measured/2026-11-01-cheats-importes-passe.tsv`. Cheat names are shown as the
in-game menu shows them, cut at 16 characters.

## Cheats that are not "ok"

### Leave play (4)

| Game | Cheat |
|---|---|
| kof2003 | FINISH THIS ROUN |
| pspikes2 | FINISH GAME NOW! |
| savagere | FINISH THIS ROUN |
| wh2j | FINISH THIS ROUN |

### Could not be judged (100)

15 games, all their imported cheats.

| Game | Cheats | Why |
|---|---:|---|
| bakatono | 1 | the bench refuses the set (no `:edge:joy` port) |
| irrmaze | 2 | the bench refuses the set (no `:edge:joy` port) |
| janshin | 1 | the bench refuses the set (no `:edge:joy` port) |
| lasthope | 1 | the test run is not in play at frame 3600 |
| minasan | 3 | the bench refuses the set (no `:edge:joy` port) |
| nam1975 | 13 | the test run is not in play at frame 3600 |
| neobombe | 1 | the test run is not in play at frame 3600 |
| pbobbl2n | 3 | the test run is not in play at frame 3600 |
| pbobblen | 15 | the test run is not in play at frame 3600 |
| popbounc | 3 | the bench refuses the set (no `:edge:joy` port) |
| puzzldpr | 16 | the test run is not in play at frame 3600 |
| puzzledp | 16 | the test run is not in play at frame 3600 |
| quizkof | 5 | the test run is not in play at frame 3600 |
| s1945p | 15 | the test run is not in play at frame 3600 |
| zintrckb | 5 | the test run is not in play at frame 3600 |

## Game by game

| Game | Cheats | ok | Leave play | Not judged |
|---|---:|---:|---:|---:|
| 2020bb | 4 | 4 |  |  |
| 3countb | 1 | 1 |  |  |
| alpham2 | 14 | 14 |  |  |
| androdun | 12 | 12 |  |  |
| aodk | 5 | 5 |  |  |
| aof | 14 | 14 |  |  |
| aof2 | 15 | 15 |  |  |
| aof3 | 15 | 15 |  |  |
| b2b | 1 | 1 |  |  |
| bakatono | 1 |  |  | 1 |
| bangbead | 16 | 16 |  |  |
| bjourney | 14 | 14 |  |  |
| blazstar | 2 | 2 |  |  |
| breakers | 9 | 9 |  |  |
| breakrev | 9 | 9 |  |  |
| bstars | 8 | 8 |  |  |
| bstars2 | 12 | 12 |  |  |
| burningf | 13 | 13 |  |  |
| crswd2bl | 4 | 4 |  |  |
| crsword | 8 | 8 |  |  |
| ctomaday | 14 | 14 |  |  |
| cyberlip | 14 | 14 |  |  |
| diggerma | 6 | 6 |  |  |
| doubledr | 15 | 15 |  |  |
| eightman | 14 | 14 |  |  |
| fatfursp | 7 | 7 |  |  |
| fatfury1 | 15 | 15 |  |  |
| fatfury2 | 15 | 15 |  |  |
| fatfury3 | 15 | 15 |  |  |
| fbfrenzy | 4 | 4 |  |  |
| fightfev | 15 | 15 |  |  |
| flipshot | 13 | 13 |  |  |
| galaxyfg | 10 | 10 |  |  |
| ganryu | 12 | 12 |  |  |
| garou | 15 | 15 |  |  |
| ghostlop | 3 | 3 |  |  |
| goalx3 | 5 | 5 |  |  |
| gowcaizr | 5 | 5 |  |  |
| gpilots | 7 | 7 |  |  |
| gururin | 15 | 15 |  |  |
| ironclad | 15 | 15 |  |  |
| irrmaze | 2 |  |  | 2 |
| janshin | 1 |  |  | 1 |
| joyjoy | 16 | 16 |  |  |
| karnovr | 14 | 14 |  |  |
| kizuna | 4 | 4 |  |  |
| kof2000 | 15 | 15 |  |  |
| kof2001 | 16 | 16 |  |  |
| kof2002 | 15 | 15 |  |  |
| kof2003 | 15 | 14 | 1 |  |
| kof94 | 10 | 10 |  |  |
| kof95 | 14 | 14 |  |  |
| kof96 | 14 | 14 |  |  |
| kof97 | 15 | 15 |  |  |
| kof98 | 15 | 15 |  |  |
| kof99 | 14 | 14 |  |  |
| kotm | 8 | 8 |  |  |
| kotm2 | 14 | 14 |  |  |
| lastblad | 15 | 15 |  |  |
| lastbld2 | 15 | 15 |  |  |
| lasthope | 1 |  |  | 1 |
| lbowling | 4 | 4 |  |  |
| legendos | 6 | 6 |  |  |
| lresort | 14 | 14 |  |  |
| magdrop2 | 5 | 5 |  |  |
| magdrop3 | 16 | 16 |  |  |
| maglord | 14 | 14 |  |  |
| mahretsu | 2 | 2 |  |  |
| marukodq | 4 | 4 |  |  |
| matrim | 5 | 5 |  |  |
| miexchng | 2 | 2 |  |  |
| minasan | 3 |  |  | 3 |
| moshougi | 16 | 16 |  |  |
| mslug | 8 | 8 |  |  |
| mslug2 | 13 | 13 |  |  |
| mslug3 | 14 | 14 |  |  |
| mslug4 | 12 | 12 |  |  |
| mslug5 | 13 | 13 |  |  |
| mslugx | 15 | 15 |  |  |
| mutnat | 15 | 15 |  |  |
| nam1975 | 13 |  |  | 13 |
| ncombat | 15 | 15 |  |  |
| ncommand | 5 | 5 |  |  |
| neobombe | 1 |  |  | 1 |
| neocup98 | 5 | 5 |  |  |
| neodrift | 8 | 8 |  |  |
| neomrdo | 3 | 3 |  |  |
| ninjamas | 11 | 11 |  |  |
| nitd | 14 | 14 |  |  |
| overtop | 4 | 4 |  |  |
| panicbom | 4 | 4 |  |  |
| pbobbl2n | 3 |  |  | 3 |
| pbobblen | 15 |  |  | 15 |
| pgoal | 2 | 2 |  |  |
| pnyaa | 2 | 2 |  |  |
| popbounc | 3 |  |  | 3 |
| preisle2 | 8 | 8 |  |  |
| pspikes2 | 7 | 6 | 1 |  |
| pulstar | 2 | 2 |  |  |
| puzzldpr | 16 |  |  | 16 |
| puzzledp | 16 |  |  | 16 |
| quizdai2 | 11 | 11 |  |  |
| quizdais | 7 | 7 |  |  |
| quizkof | 5 |  |  | 5 |
| ragnagrd | 3 | 3 |  |  |
| rbff1 | 15 | 15 |  |  |
| rbff2 | 15 | 15 |  |  |
| rbffspec | 16 | 16 |  |  |
| ridhero | 7 | 7 |  |  |
| roboarmy | 5 | 5 |  |  |
| rotd | 14 | 14 |  |  |
| s1945p | 15 |  |  | 15 |
| samsh5sp | 14 | 14 |  |  |
| samsho | 14 | 14 |  |  |
| samsho2 | 15 | 15 |  |  |
| samsho3 | 15 | 15 |  |  |
| samsho4 | 15 | 15 |  |  |
| samsho5 | 15 | 15 |  |  |
| savagere | 3 | 2 | 1 |  |
| sdodgeb | 5 | 5 |  |  |
| sengoku | 16 | 16 |  |  |
| sengoku2 | 14 | 14 |  |  |
| sengoku3 | 14 | 14 |  |  |
| shocktr2 | 14 | 14 |  |  |
| shocktro | 16 | 16 |  |  |
| socbrawl | 12 | 12 |  |  |
| sonicwi2 | 8 | 8 |  |  |
| sonicwi3 | 14 | 14 |  |  |
| spinmast | 7 | 7 |  |  |
| ssideki | 9 | 9 |  |  |
| ssideki2 | 16 | 16 |  |  |
| ssideki3 | 5 | 5 |  |  |
| ssideki4 | 9 | 9 |  |  |
| stakwin | 16 | 16 |  |  |
| stakwin2 | 15 | 15 |  |  |
| strhoop | 10 | 10 |  |  |
| superspy | 5 | 5 |  |  |
| svc | 15 | 15 |  |  |
| tophuntr | 5 | 5 |  |  |
| tpgolf | 4 | 4 |  |  |
| trally | 1 | 1 |  |  |
| turfmast | 16 | 16 |  |  |
| twinspri | 13 | 13 |  |  |
| twsoc96 | 6 | 6 |  |  |
| viewpoin | 10 | 10 |  |  |
| wakuwak7 | 16 | 16 |  |  |
| wh1 | 15 | 15 |  |  |
| wh2 | 7 | 7 |  |  |
| wh2j | 8 | 7 | 1 |  |
| whp | 15 | 15 |  |  |
| wjammers | 12 | 12 |  |  |
| zedblade | 14 | 14 |  |  |
| zintrckb | 5 |  |  | 5 |
| zupapa | 15 | 15 |  |  |
