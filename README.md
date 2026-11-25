# Group Finder for Polestar (PSGroupFinder)

Module **optionnel** pour [Polestar](https://github.com/fitzforge/polestar) (WoW: Forever 1.60.1) :
trouve les joueurs qui font **la même quête que vous, près de vous** (mobs à tuer, élite nommé,
objets à looter sur des monstres, quêtes de groupe) et propose de les **chuchoter** ou de les
**inviter**. Le groupage peut être **automatique** (option, désactivée par défaut).

Addon séparé : il ne modifie pas Polestar et fonctionne aussi sans lui (fenêtre autonome).
Licence GPL-3.0-or-later (compatible avec Polestar, GPL-3.0).

## Installation

La procédure détaillée (chemins Windows et Mac, activation, premier test à deux
comptes) est dans [INSTALLATION.md](INSTALLATION.md). En bref :

1. Installez d'abord [Polestar](https://www.curseforge.com/wow/addons/polestar).
2. Décompressez `PSGroupFinder-1.0.0.zip` dans
   `World of Warcraft/_forever_/Interface/AddOns/` : vous devez obtenir
   `.../AddOns/PSGroupFinder/PSGroupFinder.toc` (pas un dossier dans un dossier).
   Si vous aviez l'ancienne version `Polestar_GroupFinder`, supprimez ce dossier.
3. Redémarrez complètement le jeu (un `/reload` ne charge pas un nouvel addon).

## Utilisation

- **Activer** : `/psgf on`, ou cochez « Activer la recherche de groupe » dans le panneau.
  **Désactivé par défaut** : tant que c’est coupé, l’addon ne rejoint aucun canal,
  n’envoie et n’écoute rien.
- **Chercher un groupe** :
  - par défaut, une **icône dans l'en-tête** du guide Polestar, juste à gauche de la loupe
    (clic gauche = chercher, clic droit = panneau ; grisée si l'addon est coupé, colorée
    si une recherche est en cours). Option « Bouton dans l'en-tête de Polestar » : en la
    décochant, l'ancien bouton sous la fenêtre réapparaît (c'est aussi le repli si
    l'accroche d'en-tête échoue) ;
  - ou le bouton du panneau ;
  - ou un **raccourci** : Échap > Options > Raccourcis > *Polestar* >
    « Chercher un groupe pour mes quêtes » (et « Afficher ou masquer la recherche de groupe ») ;
  - ou `/psgf search`.
- **Recherche en cours** : un clic ouvre une *session* sur vos quêtes pertinentes (le panneau
  les liste). Dès qu'un **objectif est terminé** (journal de quêtes : plus d'objectif ouvert,
  « prête à rendre » ou quête retirée), la quête **sort de la recherche** (1 s après la dernière
  mise à jour du journal), une recherche mise à jour part vers les joueurs trouvés (et le canal
  caché / la guilde), et la recherche **continue pour les autres quêtes** du même endroit. Quand
  il n'en reste aucune, la recherche s'arrête et un message `X` prévient les autres. Elle s'arrête
  aussi si vous désactivez l'addon, entrez en instance, cliquez **Arrêter** (`/psgf stop`) ou
  que le groupe est complet (5).
- **Résultats** : le panneau (collé à droite de la fenêtre Polestar, à gauche si l'écran n'a pas
  la place, sinon fenêtre déplaçable) liste les joueurs trouvés, triés par quêtes en commun
  (l'étape Polestar en cours d'abord), distance (mètres, sinon « même zone »), déjà groupé ou
  non, état de l'invitation automatique. Chaque ligne indique la langue du joueur (ex. `FR`).
  Boutons **Chuchoter** et **Inviter** (à votre clic). Survol d'une ligne : toutes les quêtes communes.
- **Langues de recherche** : par défaut, seule la langue du client (`GetLocale()`, ex. frFR →
  Français) est cochée. Vous pouvez en cocher d'autres une par une. « Toutes les langues »
  (décochée par défaut) grise les autres cases et affiche tout le monde. Le filtrage est
  **unilatéral** : un joueur apparaît chez vous si sa langue de jeu est dans votre recherche
  (ou si vous avez coché Toutes). Chacun filtre de son côté ; pour le groupage automatique,
  il faut donc que chacun apparaisse chez l'autre. Un peer v0.2 sans langue n'est visible
  que si Toutes est cochée. Réglable dans le panneau et dans les options Polestar.
- **Groupage automatique** (option « Grouper automatiquement (même quête) », **désactivée par
  défaut**) : après *votre* recherche, l'addon invite le joueur trouvé (ou lui demande de vous
  inviter) et accepte son invitation, sans clic. Il faut que **les deux** aient l'option. Qui
  invite : celui qui est déjà en groupe (et chef) invite le solo ; deux solos : l'identifiant de
  session le plus bas invite (l'autre lui envoie un message `G`) ; deux groupes : personne. Même
  faction obligatoire, groupe de 5 maximum, jamais en instance. Une invitation n'est acceptée
  que d'un joueur *attendu* (qui a lancé une recherche avec l'option et à qui vous avez répondu,
  ou à qui vous avez demandé).
- **Options** (sauvegardées dans `PSGroupFinderDB`), dans le panneau **et**, avec Polestar,
  dans une page « Recherche de groupe » des options de Polestar (activer, grouper automatiquement,
  bouton d'en-tête, langues, position, répondre, raccourcis, test des canaux) :
  - activer / désactiver ; grouper automatiquement ;
  - bouton dans l'en-tête de Polestar (activé par défaut) ;
  - langues de recherche (défaut : langue du jeu seulement ; « Toutes » est opt-in) ;
  - partager ma position (sinon seule la zone est envoyée) ;
  - répondre aux recherches sur mes quêtes.
  - proposer de quitter quand les quêtes du groupe sont finies (activé par défaut), et dire un
    message dans /p avant de quitter (désactivé par défaut, texte modifiable) ;
- **Liste par quête** (1.1) : un petit bouton (deux silhouettes) ouvre le panneau en « mode quête »,
  la liste des joueurs qui ont **cette** quête, où qu'ils soient, avec leur zone, leur progression,
  Chuchoter et Inviter ; **Rechercher pour cette quête** les interroge (quête identifiée par son
  numéro). Le bouton est :
  1. dans la fenêtre de guide Polestar, sous l'icône de l'objectif, à gauche de la sous-ligne ;
  2. proposé dans l'infobulle de l'objectif (« Alt-clic : voir les joueurs sur cette quête ») ;
  3. dans le journal de quêtes du jeu, à droite de la case de suivi de chaque quête.
  Sans Polestar il reste celui du journal et `/psgf quest <id>`.
- **Quitter le groupe** (1.1) : pour un groupe formé via l'addon, quand toutes les quêtes pour
  lesquelles vous vous êtes groupé sont finies, une fenêtre propose **Quitter** / **Rester**.
  Le message dans /p (option) et la sortie du groupe ne se font **que dans le clic sur Quitter**.
- **Commandes** : `/psgf` (panneau), `/psgf search`, `/psgf stop`, `/psgf on|off`, `/psgf test`
  (teste les canaux), `/psgf reset` (replace le panneau), `/psgf quest <id>` (liste d'une quête),
  `/psgf hooks` (ce qui a été trouvé chez Polestar et dans le journal), `/psgf debug`.

## Ce qui est envoyé

Seulement quand c’est activé, en messages d’addon cachés (préfixe `PSGF`, ≤ 255 octets) :

| Message | Quand | Contenu |
|---|---|---|
| Recherche `S` | votre clic / raccourci, au plus toutes les 20 s ; renvoyée **sans clic** (canal caché, guilde, chuchotement aux joueurs trouvés) quand un objectif est terminé | jusqu’à ~12 IDs de quêtes restantes avec leur type (kill, élite nommé, loot, groupe), carte, x/y (si partagé), niveau, classe, taille du groupe, drapeaux (`g` groupage auto, faction `A`/`H`), langue du client (ex. `f`) |
| Réponse `R` | en chuchotement d’addon au chercheur, au plus 1×/20 s par joueur | uniquement les IDs des quêtes **en commun**, votre carte/position, niveau, classe, drapeaux, langue du client |
| Fin `X` | dernière quête terminée, arrêt, groupe complet | votre identifiant de session : les autres vous retirent de leur liste |
| Demande `G` | option groupage auto, chuchoté au joueur qui doit vous inviter | les IDs des quêtes en commun |
| Recherche de quête `Q` (1.1) | votre clic sur un bouton de quête, au plus toutes les 15 s | l'identifiant d'**une** quête, carte, x/y (si partagé), niveau, classe, taille du groupe, drapeaux, langue du client |
| Réponse de quête `A` (1.1) | en chuchotement au demandeur, si vous avez la quête dans le journal (quelle que soit la zone), au plus 1×/20 s par demandeur et par quête | cet identifiant et votre progression en % (100 : terminée ou à rendre), votre position, niveau, classe, langue |
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
| `Polestar.RegisterOptions` (ARCHITECTURE.md « Options registry », hors docs/API.md), sous `pcall` | **semi-interne** | page « Recherche de groupe » dans les options de Polestar |
| champ public `icon` de `RegisterOptions` (chemin complet vers `Media/icon-group`) | **API publique** du registre | icône de notre entrée dans la barre latérale, même taille (16×16) et rendu monochrome que Guide, Map, Questing et Discovery |
| `UI.Options.Kit.pages`, `Options.Grouped.NavItems`, `Widgets.NavRowAfter` | **internes**, sous `pcall` | repli si la page groupée des options n'envoie pas l'icône aux lignes indentées |
| `Polestar.Theme.GuideReach`, `Polestar.Theme.Skin(…, "checkbox" / "close")`, `Theme.Hex` | **Skin API publique** | éviter les onglets du bord bas, cases et bouton de fermeture au look Polestar |
| `Polestar.UI.ShowOptions(clé)` | **interne**, sous `pcall` | bouton « Options » du panneau (masqué si absent) |
| `Polestar.Engine.GetGuide()` / `GetLiveStep()` et `step.goals[].quest` | **interne**, appelé sous `pcall` | mettre les quêtes de l’étape en cours en tête |
| `Polestar.Compat.GetPlayerMapPosition()` | **interne**, sous `pcall` | position (sinon `C_Map`) |
| `Polestar.Theme.GuideParts().rows` (les lignes d'objectif, « pooled »), et sur chaque ligne `psGoal`, `Icon`, `Check`, `Alt` | `rows` documenté dans la référence des skins ; les champs de ligne sont **internes** | bouton de quête sous l'icône de l'objectif |
| `Polestar.QuestClickTips(questID, lines)` et `Polestar.QuestRowClick(questID, button)` | **internes** (appelées par nom à chaque infobulle / clic) ; enveloppées sous `pcall`, l'original passe toujours en premier | ligne d'aide « Alt-clic » et Alt-clic |

Si un élément interne change dans une version de Polestar, l’addon retombe sur le journal de
quêtes du client et `C_Map`. Sans Polestar, ou avec une version d’API différente, c’est une
fenêtre autonome.

## Journal de quêtes du jeu (1.1)

Le bouton par quête s'accroche à **`QuestScrollFrame.titleFramePool`** (le journal Carte et
quêtes, boutons de titre avec `.questID` et `.Checkbox`), sinon aux enfants de son contenu qui
portent un `questID`, sinon aux boutons `QuestLogTitle1…N` du journal classique. Le bouton est un
**enfant** du bouton de titre (il suit les lignes recyclées) ; il est replacé après les
fonctions de mise à jour du journal (`hooksecurefunc` seulement : on ne remplace rien, et on
n'appelle jamais `QuestMapFrame_OpenToQuestDetails`, qui fait du taint chez Polestar, #2924) et
toutes les 0,5 s tant qu'un journal est affiché. Les noms de frames de Forever n'ont **pas** pu
être vérifiés hors jeu (ils viennent du code du journal de la version Retail et de ce que dit
Questie) : `/psgf hooks` dit ce qui a été trouvé.

## Limites du groupage automatique (à confirmer en jeu)

- **Invitation** : `InviteUnit` peut être appelé depuis un gestionnaire d'événement, sans touche
  (des addons Forever d'auto-invitation le font) ; seul le **chef** (ou un joueur solo) peut
  inviter, 5 membres maximum, **même faction** (et même ruleset), pas d'invitation de guilde
  automatisable.
- **Acceptation** : `AcceptGroup()` sur `PARTY_INVITE_REQUEST` est documenté pour Classic, mais
  **non confirmé sur Forever**. Si le client refuse, la fenêtre d'invitation reste affichée et un
  message dans le chat demande d'accepter à la main.
- Pas de `SendChatMessage` (SAY/YELL) sans action matérielle : les mises à jour sans clic
  passent par le canal caché, la guilde et le chuchotement d'addon. Un joueur joint seulement par
  YELL/SAY garde l'ancienne liste jusqu'à expiration de son entrée (5 min).
- Les noms de session servent à décider qui invite ; deux clients avec des versions
  différentes (v0.1 / v0.2) ne se comprennent pas pour les nouvelles fonctions.

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
- **Fragilités de la 1.1** (rien n'a été vu dans le client) : noms des frames du journal de
  Forever ; hauteur de ligne d'objectif Polestar (≥ 36 pour placer le bouton sous l'icône, sinon
  à gauche de la case à cocher) ; `QuestClickTips` / `QuestRowClick` / `row.psGoal` sont internes à
  Polestar (sans eux : ni ligne d'aide ni Alt-clic, le bouton reste) ; une version 1.0.x
  ne répond pas aux recherches de quête (elle les ignore). Le message dans /p passe par
  `SendChatMessage` dans le clic sur Quitter ; si Forever le refuse, le groupe est quand même quitté.
- Testé uniquement hors jeu : `luac` + `luacheck` + une simulation multi-clients (recherche, session, retrait des quêtes, groupage auto, recherche de quête, boutons, offre de quitter) avec un faux
  API WoW et un faux Polestar (`lua5.1 tests/sim.lua`). Pas encore testé dans le client.

## Développement

```
luacheck PSGroupFinder      # lint (config .luacheckrc)
lua5.1 tests/sim.lua               # simulation multi-clients
./build.sh                         # zip versionné dans ../polestar-groupfinder-release/
```

Inspiré par les descriptions publiques de Group Up, QuestScout et Group Quest Finder
(CurseForge, « All Rights Reserved ») : **aucun code de ces addons n’a été lu ni copié**.
