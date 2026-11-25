# Installation — Group Finder for Polestar (PSGroupFinder) 1.0.0

Companion de [Polestar](https://www.curseforge.com/wow/addons/polestar) pour WoW: Forever 1.60.1.
**Cet addon n'a pas encore été testé dans le client de jeu.**

## Prérequis

- **WoW: Forever** installé (client 1.60.1).
- **Polestar** déjà installé et à jour (CurseForge, client Polestar, ou à la main). Sans Polestar, l'addon fonctionne quand même, avec une fenêtre autonome, mais le bouton dans l'en-tête du guide (ou sous la fenêtre) et la page d'options Polestar seront absents.

## Où déposer l'addon

Forever a son propre dossier, séparé de Retail et de Classic : **`_forever_`**.

| Système | Chemin par défaut |
|---|---|
| Windows | `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns` |
| macOS | `/Applications/World of Warcraft/_forever_/Interface/AddOns` |

Si le jeu n'est pas à cet emplacement, trouvez le dossier ainsi :

1. Ouvrez l'application **Battle.net**.
2. Sélectionnez World of Warcraft, puis la version **WoW: Forever** (menu au-dessus de Jouer).
3. Cliquez sur l'engrenage à côté de Jouer, puis **Afficher dans l'Explorateur** (Windows) ou **Afficher dans le Finder** (Mac).
4. Entrez dans `_forever_`, puis `Interface`, puis `AddOns`.

Si les dossiers `Interface` ou `AddOns` n'existent pas encore, créez-les en respectant exactement cette orthographe. Ne déposez pas l'addon dans `_retail_` ni `_classic_era_` : Forever ne le verrait pas.

## Installer

1. Fermez complètement le jeu.
2. Décompressez `PSGroupFinder-1.0.0.zip`. Vous devez obtenir un dossier `PSGroupFinder` qui contient le fichier `PSGroupFinder.toc`.
3. Placez ce dossier `PSGroupFinder` **directement** dans le dossier `AddOns` ci-dessus. Le chemin final doit être :
   `.../_forever_/Interface/AddOns/PSGroupFinder/PSGroupFinder.toc`
   (pas `AddOns/PSGroupFinder/PSGroupFinder/PSGroupFinder.toc`, ni un dossier `PSGroupFinder-1.0.0` autour).
4. Si un ancien dossier `Polestar_GroupFinder` est encore là (versions 0.x), **supprimez-le** pour éviter que les deux addons se chargent ensemble.
5. Relancez **complètement** le jeu. Un `/reload` ne suffit pas pour un nouvel addon.

## Vérifier et activer

1. Sur l'écran de choix du personnage, cliquez sur **AddOns**. Cochez **Group Finder for Polestar** (en français : **Recherche de groupe (Polestar)**) et validez.
2. Entrez en jeu. Dans Polestar : **Options > Recherche de groupe** (ou tapez `/polestar options`) : l'entrée porte une icône à deux silhouettes, comme les autres de la barre. Cochez **Activer la recherche de groupe**. Tant que c'est coupé, rien n'est envoyé ni écouté.
3. (Facultatif) Cochez **Grouper automatiquement (même quête)** seulement si vous voulez les invitations sans clic. Les deux joueurs doivent l'avoir.
4. Assignez un raccourci : Échap > Options > Raccourcis, catégorie **Polestar** :
   - « Chercher un groupe pour mes quêtes »
   - « Afficher ou masquer la recherche de groupe »
5. Tapez `/psgf test` : le chat indique, au bout de quelques secondes, quels canaux fonctionnent (vert = OK). Par défaut, une petite icône **œil** est accrochée dans l'en-tête du guide Polestar, **juste à gauche de la loupe** : clic gauche = chercher, clic droit = panneau. Si vous préférez l'ancien bouton sous la fenêtre, décochez « Bouton dans l'en-tête de Polestar ». Commande du panneau : `/psgf`.
6. **Langues de recherche** : par défaut, seule **la langue de votre jeu** (par exemple frFR → Français) est cochée. Vous pouvez en cocher d'autres une par une, ou cocher **Toutes les langues** (la liste se replie alors, et tout le monde apparaît). Un joueur apparaît dans *votre* liste si sa langue de jeu est parmi celles que vous avez cochées (ou si vous avez coché Toutes). Chaque réglage des options a une infobulle au survol.

## Utilisation

- Cliquez sur l'icône d'en-tête (ou **Chercher un groupe**, le raccourci, ou `/psgf search`) pendant une quête de kill, d'élite nommé, de loot ou de groupe. Les joueurs qui ont aussi l'addon activé, la même quête, et dont la langue de jeu est dans vos **Langues de recherche**, apparaissent dans le panneau (avec leur langue, par ex. FR) : **Chuchoter** ou **Inviter**.
- Quand un objectif est terminé, cette quête sort toute seule de la recherche ; les autres du même endroit continuent. La recherche s'arrête quand il n'en reste plus, ou avec **Arrêter** (`/psgf stop`).
- **Joueurs sur une quête** (1.1) : le petit bouton aux deux silhouettes (sous l'icône d'un objectif du guide Polestar, ou à droite de la case de suivi dans le journal de quêtes du jeu) ouvre la liste des joueurs qui ont **cette** quête, même dans une autre zone. **Rechercher pour cette quête** les interroge (une fois toutes les 15 s). Dans le guide Polestar, **Alt + clic** sur un objectif fait la même chose. `/psgf quest 33` ouvre la liste de la quête n°33.
- **Quitter le groupe** (1.1) : quand les quêtes pour lesquelles vous vous êtes groupé via l'addon sont toutes finies, une petite fenêtre demande **Quitter** ou **Rester**. Option « Dire un message dans /p avant de quitter » (désactivée par défaut, texte modifiable avec **Modifier…**) : il part seulement quand vous cliquez sur Quitter. Rien ne se fait sans clic.
- Autres commandes : `/psgf on`, `/psgf off`, `/psgf test`, `/psgf reset`, `/psgf hooks` (dit si les boutons de quête ont trouvé leur place : à copier dans un message si un bouton manque).

## Désinstallation

Fermez le jeu, puis supprimez le dossier `PSGroupFinder` dans `AddOns`. Pour enlever aussi les réglages, supprimez les fichiers `PSGroupFinder.lua` dans `World of Warcraft/_forever_/WTF/Account/<votre compte>/SavedVariables/` (et le dossier du personnage, s'il y en a un).

## Premier test à deux comptes

À faire à deux (deux comptes, ou deux personnages de la **même faction** sur le même royaume) :

1. Installez la même version de l'addon sur les deux clients, redémarrez le jeu, activez l'addon dans la liste, puis **Activer la recherche de groupe** des deux côtés. Si les deux clients n'ont pas la même langue de jeu, cochez la langue de l'autre (ou **Toutes les langues**) dans **Langues de recherche** — chacun ne voit que ce que *sa* recherche autorise.
2. Lancez `/psgf test` sur chaque compte et notez le canal annoncé.
3. Prenez **la même quête** (un kill ou un loot près de vous, par exemple au départ d'Elwynn ou de Durotar) et placez-vous **l'un près de l'autre** (surtout si le test n'a pas confirmé le canal caché : YELL et SAY n'atteignent que les joueurs proches).
4. Sur le compte A, cliquez **Chercher un groupe**. Le compte B doit apparaître dans le panneau de A (et l'inverse si B a aussi la langue de A dans sa recherche). Testez **Chuchoter** puis **Inviter**.
5. Pour la liste par quête : sur le compte B, ouvrez le journal de quêtes et cliquez sur le petit bouton de la quête commune (B peut être dans une autre zone) ; **Rechercher pour cette quête** doit faire apparaître A avec sa zone et son pourcentage. Tapez `/psgf hooks` si un bouton manque.
6. Pour la sortie de groupe : invitez A depuis le panneau, finissez la quête des deux côtés (ou abandonnez-la pour voir qu'elle ne compte pas) : la fenêtre **Quitter / Rester** doit apparaître chez chacun, et rien ne doit se passer avant votre clic.
7. Pour le groupage automatique : cochez l'option des deux côtés, et faites en sorte que chacun apparaisse chez l'autre (chacun filtre de son côté). Séparez-vous du groupe, relancez une recherche. L'invitation doit partir toute seule. Si une fenêtre d'invitation reste affichée, acceptez-la à la main et dites-le : cette partie n'est pas encore confirmée sur Forever.

Si personne n'apparaît : vérifiez que l'addon est bien activé des deux côtés, que vous avez la même quête encore à faire, que vous n'êtes pas en instance, que la langue de l'autre est dans vos Langues de recherche (ou que Toutes est cochée), et rapprochez-vous avant de relancer `/psgf test` puis une recherche (20 s de délai entre deux recherches).
