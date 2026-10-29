# Ce que la scène attend d'un BIOS Neo Geo

Recherche documentaire du 2026-10-23, demandée par l'utilisateur : recenser les fonctions d'UniBIOS
et ses défauts connus, puis ce que la communauté réclame d'un BIOS. Ce document est figé à cette date :
l'état de Sprixe BIOS face à ces attentes est dans `COMPARISON.md` et `DECISIONS.md`.

**Salle blanche.** Pour cette recherche, on n'a lu que des descriptions publiques : notes de
version, wikis, messages de forum. Aucune ROM, aucun binaire et aucun code n'a été ouvert. Le code
du BIOS libre en C de `neogeo-projects/neogeo-bios` n'est pas lu ici (`DECISIONS.md` §1 à §3).

**Ce qui n'a pas pu être lu.** `unibios.free.fr` ne répond pas, ni sa page des limites connues.
Reddit et KLOV sont refusés par l'extension du navigateur, et ConsoleMods par une page Cloudflare.
La recherche est réservée aux membres sur arcade-projects, misterfpga.org et shmups. On a lu les fils
publics de neo-geo.com/forums, d'arcade-projects et d'AtariAge, plus des issues GitHub.

Les notes de version d'UniBIOS sont celles que leur auteur a postées sur neo-geo.com/forums : v1.3
(2004-03-24), v2.0 (2004-08-21), v2.3 (2006-10-04), v3.1 (2012-09-01), v3.2 (2014-02-28) et v4.0
(2018-05-06). « Tendance » veut dire trois sources ou plus, d'auteurs différents ; sinon, anecdote.

## 1. Les fonctions d'UniBIOS

| Fonction d'UniBIOS (version) | Ce qu'en dit la scène |
|---|---|
| Base de plus de 1 570 cheats et « Patch Memory » (2.0) | Les cheats sont cités comme une raison d'installer UniBIOS (wiki neogeodev, RetroRGB 2020-03-20) ; demande de les réordonner (3.2, 2014) |
| Scores sauvés sur carte mémoire, AES compris (3.1) ; option qui coupe la remise à zéro périodique des scores sur une trentaine de jeux MVS (4.0) | **Tendance, 7 sources** : la fonction d'UniBIOS la plus citée. La plainte inverse est aussi fréquente : scores ni sauvés ni relus (3.1 à 3.3) |
| Gestionnaire de carte mémoire accessible dans tous les modes | — |
| Soft-DIP depuis le menu en jeu ; 1UP START remet les défauts (4.0) | **Tendance, 3 sources** : régler le jeu sans redémarrer |
| Visualiseur de RAM et de VRAM (1.3, 2.3), debug dips, mode développeur | Sert au diagnostic d'une carte (neo-geo.com, `mv2-crosshatch`, 2026-07-09) |
| Vérification CRC32 de la cartouche (1.3) | — |
| Test des manettes 4 joueurs et mahjong (3.2) | — |
| Économiseur d'écran (2.3), couleurs des menus (4.0) | — |
| Affichage des crédits à l'américaine, mode Arcade VS | — |
| PC-2-NEO, transfert par câble (3.0, USB en 3.1) ; PICKnMIX pour la carte 161-en-1 (4.0, « totally unsupported ») | Niche ; un patch de la scène, « BackToMenu », ramène la 161-en-1 à sa liste (AtariAge, 2026-09-15) |

Non trouvés dans les notes d'UniBIOS lues : le **free play** et la **comptabilité** de la borne.

## 2. Les défauts connus d'UniBIOS

| Défaut | Attesté par |
|---|---|
| **v4.0 sur multi-slot** : écran noir ou « EXCEPTION ERROR HANDLING » au boot, son coupé sur les slots 2 et suivants. La scène conseille la 3.2 | **Tendance** : arcade-projects `threads/resolved-unibios-bug-4-slot-mvs-failure-to-boot.33132` (2025-02-22, trois participants), `ng-dev-team-mvs-carts-4-slot-issues-solved.29662` (2024-05), neo-geo.com (2024-06, 2025-01) |
| **Logo brouillé** sur les cartouches flash (Darksoft) et homebrew : UniBIOS dessine son logo avec les graphismes de la cartouche, pas encore lisibles au boot d'une carte lente | **Tendance** : arcade-projects `games-with-issues.5220` p. 3 (2018-03), itch.io (Shinobi), TCRF |
| **Scores ni sauvés ni relus** sur carte, erreur à l'écran des scores (Neo Bomberman, New Turf Masters) | **Tendance** : neo-geo.com 2013, 2015, 2018 ; arcade-projects 2018-03 |
| **Erreurs avec les cartouches Darksoft** (sprites manquants, crash de KOF98, « please wait ») | **Tendance** : `darksoft-neo-multi-help-thread.5055` p. 18, `games-with-issues.5220` (2018-2019) |
| Entrer dans les soft-DIP d'un jeu jamais lancé corrompt son entrée (4.0, limite officielle) | `unibios.free.fr/knownissues.html`, d'après un extrait de moteur de recherche : page non lue |
| SELECT ajoute un crédit (les pièces sont reportées sur SELECT) | arcade-projects, fil Darksoft (anecdote) |
| v2.0 efface toute la backup RAM au premier lancement et à chaque mise à jour | notes de la v2.0 |
| Soft-DIP AES perdus après un soft reboot (introduit en 3.1, corrigé en 4.0) | notes de la v4.0 |
| Les tables de scores remplissent une carte SNK de 2 Ko | neo-geo.com, fil 3.1 (auteur d'UniBIOS, 2012-09) |
| Sur AES, pas de son en démo et texte corrompu (NAM-1975, « Winners don't use drugs ») en mode MVS | FAQ d'UniBIOS, citée sur neo-geo.com (2025-03-26) |
| Banni en bloc par RetroAchievements, à cause des cheats et du debug | RetroArch #18989 (2026-04-29) |

## 3. Ce que la scène demande

Base mince : la plupart des recherches de forum sont réservées aux membres, et Reddit n'a pas été lu.

**Tendances**
- **Scores sauvés, sur AES aussi** (7 sources, voir §1).
- **UniBIOS dans l'AES+**, la console annoncée pour le 2026-11-12 (4 sources, AtariAge `topic/389647` et
  neo-geo.com `neo-geo-aes.273486`, 2026-04 à 2026-09). On craint que les flashcarts soient verrouillées.
- **Des réglages qui restent** : la région et le mode retombent au défaut d'un lancement à l'autre
  (Atari-Forum, libretro 2019, misterfpga 2023).
- **Soft-DIP et cheats depuis le menu du jeu** (3 sources, 2014-2018).

**Anecdotes**
- Réglages de borne communs à tous les jeux : « one credit per coin », démo muette (MiSTer
  NeoGeo_MiSTer #236, 2025-11-04, ouverte).
- Mode 1cc et menu soft-DIP en jeu (backlog de `neogeo-projects/neogeo-bios`, #3 et #4, 2025-07).
- Logo personnalisable (Darksoft, 2018-03-14).
- Restreindre les cheats et le debug plutôt que bannir le BIOS entier (RetroArch #18989).
- Un BIOS libre adopté par MAME (`neogeo-projects/neogeo-bios` #8, 2025).
- Changer de jeu par UP/DOWN + START sur multi-slot (2010) ; selon l'auteur d'UniBIOS, c'est déjà possible.

**Non trouvé** dans ce qui a été lu : des demandes sur le temps de boot, l'eyecatcher, la langue, la
mise à jour du BIOS ou les save states.

## 4. Ce que cela suggère pour Sprixe BIOS

Ce sont des pistes, pas des décisions. Chacune ferait un lot, avec sa scène au parcours
(`DECISIONS.md` et la règle de `docs/tasks.md` : une fonction livrée sans scène n'est pas finie).

1. **Scores sur carte mémoire en mode AES**, et un gestionnaire de carte (copier, effacer, formater).
   C'est la demande la plus fréquente.
2. **Soft-DIP depuis le menu en jeu**, en reprenant l'éditeur existant.
3. **Étendre la base de cheats** au-delà de trois jeux.
4. **Réglages de borne communs** : free play, 1cc, démo muette.
5. **Deux scènes qui fixent nos garanties sur les défauts d'UniBIOS** : l'écran de boot ne lit aucun
   graphisme de la cartouche ; le son du slot 2 sans cartouche au slot 1, sur MV-6F.
6. **Une option qui coupe les cheats et le debug**, pour qu'un BIOS reste admissible là où
   RetroAchievements bannit UniBIOS.
