# Changelog

## 1.0.0 — 2026-11-25

Première version destinée à être installée en jeu (non testée dans le client). Rien n'a été publié avant : les identifiants 0.1, 0.2, 1.0.1 et 1.1 n'étaient que des étapes locales.

- Le dossier de l'addon s'appelle **PSGroupFinder**. Titre affiché : « Group Finder for Polestar » / « Recherche de groupe (Polestar) ». Variables sauvegardées : `PSGroupFinderDB` / `PSGroupFinderCharDB`.
- Recherche de joueurs sur les mêmes quêtes (kill, élite nommé, loot, groupe), canaux d'addon (CHANNEL, YELL, SAY, GUILD ; réponses en chuchotement), panneau (Chuchoter / Inviter sur votre clic seulement).
- Une recherche est une session : les quêtes quittent la recherche quand leur objectif est terminé ; la recherche continue pour les autres, puis s'arrête. Option « Grouper automatiquement (même quête) », désactivée par défaut.
- Bouton dans l'en-tête du guide Polestar, juste à gauche de la loupe (activé par défaut) : clic gauche pour chercher **sans** ouvrir le panneau (icône accent + message de chat), clic droit pour ouvrir ou fermer le panneau. Repli : bouton « Chercher un groupe » sous la fenêtre. Accroche interne sur `Theme.GuideParts().nav.Lookup`, sous pcall.
- Pendant une recherche active sans résultat, le panneau affiche « Recherche en cours… aucun joueur pour l'instant ».
- Langues de recherche (un seul réglage). Chaque joueur diffuse la langue de son client. Par défaut, seule cette langue est cochée ; on peut en ajouter d'autres, ou cocher « Toutes les langues » (toutes les autres cases se grisent tout de suite, y compris les non cochées). Filtrage unilatéral. Un peer plus ancien sans langue n'est visible que si Toutes est cochée.
- Page « Recherche de groupe » dans les options de Polestar. L'entrée de la barre latérale porte **la même icône que le bouton d'en-tête** (deux silhouettes, 16×16, monochrome comme les autres). Champ public `icon` de `RegisterOptions`, chemin complet vers notre texture `Media/icon-group`. Repli interne sous pcall si la page groupée des options n'envoie pas l'icône aux lignes indentées.
- **Liste par quête** : un petit bouton (deux silhouettes) ouvre le panneau en mode quête (nom, niveau, classe, langue, zone, progression, distance ou « autre zone », Chuchoter / Inviter) avec **Rechercher pour cette quête**.
  1. fenêtre de guide Polestar : sous l'icône de l'objectif, à gauche de la sous-ligne ;
  2. infobulle d'un objectif : ligne d'aide « Alt-clic : voir les joueurs sur cette quête » et Alt-clic (les autres clics restent à Polestar) ;
  3. journal de quêtes du jeu : un bouton par quête, après la case de suivi, quelle que soit la zone.
  Aussi `/psgf quest <id>` et `/psgf hooks`.
- **Protocole** : messages `Q` (« qui a la quête N ? ») et `A` (réponse chuchotée avec le pourcentage), quelle que soit la zone. Mêmes règles de langue, pause de 15 s entre deux recherches de quête, limites d'envoi.
- **Quitter le groupe** quand les quêtes pour lesquelles vous vous êtes groupé via l'addon sont toutes finies : fenêtre **Quitter** / **Rester**. Option : message dans /p (texte modifiable, défaut FR/EN selon le client). Le message et `LeaveParty` ne partent **que dans le clic sur Quitter**, jamais automatiquement. Un groupe formé à la main n'est jamais proposé.
