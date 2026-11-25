# Polestar Group Finder

Module **optionnel** pour [Polestar](https://github.com/fitzforge/polestar) (WoW: Forever 1.60.1) :
trouve les joueurs qui font **la même quête que vous, près de vous** (mobs à tuer, élite nommé,
objets à looter sur des monstres, quêtes de groupe) et propose de les **chuchoter** ou de les
**inviter**, toujours sur votre clic.

Addon séparé : il ne modifie pas Polestar et fonctionne aussi sans lui (fenêtre autonome).
Licence GPL-3.0-or-later (compatible avec Polestar, GPL-3.0).

## Installation

1. Décompressez `Polestar_GroupFinder.zip` dans
   `World of Warcraft/_forever_/Interface/AddOns/` : vous devez obtenir
   `.../AddOns/Polestar_GroupFinder/Polestar_GroupFinder.toc`.
2. Redémarrez complètement le jeu (un `/reload` ne charge pas un nouvel addon).
3. Polestar est conseillé, pas obligatoire (`## OptionalDeps: Polestar`).

## Utilisation

- **Activer** : `/psgf on`, ou cochez « Activer la recherche de groupe » dans le panneau.
  **Désactivé par défaut** : tant que c’est coupé, l’addon ne rejoint aucun canal,
  n’envoie et n’écoute rien.
- **Chercher un groupe** :
  - le bouton **« Chercher un groupe »** accroché sous la fenêtre de guide Polestar
    (clic gauche = chercher, clic droit = panneau) ;
  - ou le bouton du panneau ;
  - ou un **raccourci** : Échap > Options > Raccourcis > *Polestar* >
    « Chercher un groupe pour mes quêtes » (et « Afficher ou masquer la recherche de groupe ») ;
  - ou `/psgf search`.
- **Résultats** : le panneau (collé à droite de la fenêtre Polestar, sinon fenêtre déplaçable)
  liste les joueurs trouvés, triés par quêtes en commun (l’étape Polestar en cours d’abord),
  distance (en mètres/yards, sinon « même zone »), déjà groupé ou non. Boutons **Chuchoter**
  et **Inviter**. Rien n’est automatique.
- **Options** (sauvegardées dans `PolestarGroupFinderDB`) :
  - partager ma position (sinon seule la zone est envoyée) ;
  - répondre aux recherches sur mes quêtes.
- **Commandes** : `/psgf` (panneau), `/psgf search`, `/psgf on|off`, `/psgf test`
  (teste les canaux), `/psgf reset` (replace le panneau), `/psgf debug`.

## Ce qui est envoyé

Seulement quand c’est activé, en messages d’addon cachés (préfixe `PSGF`, ≤ 255 octets) :

| Message | Quand | Contenu |
|---|---|---|
| Recherche `S` | votre clic / raccourci, au plus toutes les 20 s | jusqu’à ~12 IDs de quêtes pertinentes avec leur type (kill, élite nommé, loot, groupe), carte, x/y (si partagé), niveau, classe, taille du groupe |
| Réponse `R` | en chuchotement d’addon au chercheur, au plus 1×/min par joueur | uniquement les IDs des quêtes **en commun**, votre carte/position, niveau, classe |
| Test `T` | `/psgf test`, ou une fois après activation | un identifiant aléatoire (on écoute son propre écho) |

Jamais de texte libre, jamais tout le journal de quêtes, rien en instance.

## Canaux et détection

Ordre essayé : **CHANNEL** (canal caché `PSGroupFinder`, retiré des onglets de chat et rejoint
6 s après la connexion pour ne pas prendre /1 ou /2), puis **YELL**, **SAY** (portée limitée),
**GUILD**. Les réponses passent en **WHISPER**.

L’addon détecte en jeu ce qui marche :

- code de retour de `C_ChatInfo.SendAddonMessage` (`InvalidChannel`,
  `AddonMessageThrottle`, `NotInGuild`…) ;
- **écho** : un message qui revient prouve que le canal fonctionne.

Le panneau affiche chaque canal en couleur : vert = écho reçu, jaune = accepté sans écho,
rouge = refusé, gris = indisponible. `/psgf test` détaille le résultat dans le chat.
Une recherche part sur le meilleur canal public, plus la guilde si vous en avez une.

Débit : file maison (rafale de 4, puis ~0,8 msg/s), nouvel essai sur `AddonMessageThrottle`.
La recherche elle-même part immédiatement, dans l’appel du clic ou de la touche (SAY/YELL
peuvent exiger une action matérielle).

## Intégration avec Polestar

| Utilise | Statut chez Polestar | Pour |
|---|---|---|
| `Polestar.API.version == 1`, `Polestar.On("STEP_CHANGED" / "GUIDE_CHANGED" / "TABS_CHANGED")`, `Polestar.Compat.IsOnQuest` / `IsQuestReadyForTurnIn` | **API publique** (docs/API.md) | savoir quand l’étape change, filtrer les quêtes |
| `Polestar.Theme.Skin`, `Font`, `OnChanged` | **Skin API publique** (capability `theme.functions`) | peindre le panneau et le bouton au look du joueur |
| `Polestar.Theme.GuideParts().window` | **Skin API publique** (capability `guideParts`) | accrocher le bouton sous la fenêtre de guide et le panneau à sa droite |
| `Polestar.Engine.GetGuide()` / `GetLiveStep()` et `step.goals[].quest` | **interne**, appelé sous `pcall` | mettre les quêtes de l’étape en cours en tête |
| `Polestar.Compat.GetPlayerMapPosition()` | **interne**, sous `pcall` | position (sinon `C_Map`) |

Si un élément interne change dans une version de Polestar, l’addon retombe sur le journal de
quêtes du client et `C_Map`. Sans Polestar, ou avec une version d’API différente, c’est une
fenêtre autonome.

## Limites connues / à tester en jeu

- **Canal CHANNEL** : WoW Classic interdit les messages d’addon sur canal custom depuis 1.13.3.
  Sur Forever, ils renvoyaient `InvalidChannel (7)` au lancement (6 nov. 2026), puis un joueur a
  écrit « appears to be fixed », sans confirmation de Blizzard. **Lancez `/psgf test`** pour
  savoir. Sans CHANNEL, YELL/SAY ne touchent que les joueurs proches (c’est souvent ce qu’on
  veut pour une quête de kill) et GUILD que votre guilde.
- Les comptes d’essai / vétérans ne peuvent pas envoyer de messages d’addon (1.60.1).
- Les quêtes de type « item » ne disent pas si l’objet vient d’un monstre ou du sol : toutes
  comptent comme « loot ».
- « Élite nommé » est une heuristique : objectif de kill qui demande exactement 1 mob.
- Les noms Forever ont un nom de famille (« Ana Smith ») : le chuchotement et l’invitation
  utilisent le nom tel que le serveur l’envoie. À vérifier en jeu, surtout entre royaumes.
- Seuls les autres joueurs **qui ont cet addon et l’ont activé** répondent.
- Testé uniquement hors jeu : `luac` + `luacheck` + une simulation de 4 clients avec un faux
  API WoW et un faux Polestar (`lua5.1 tests/sim.lua`). Pas encore testé dans le client.

## Développement

```
luacheck Polestar_GroupFinder      # lint (config .luacheckrc)
lua5.1 tests/sim.lua               # simulation multi-clients
./build.sh                         # zip dans ../polestar-groupfinder-release/
```

Inspiré par les descriptions publiques de Group Up, QuestScout et Group Quest Finder
(CurseForge, « All Rights Reserved ») : **aucun code de ces addons n’a été lu ni copié**.
