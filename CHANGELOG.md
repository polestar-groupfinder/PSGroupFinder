# Changelog

## 1.0.1 — 2026-11-25

- Options Polestar : cocher « Toutes les langues » grise immédiatement **toutes** les autres langues (cochées ou non), via le `disabled` natif de Polestar et un `Widgets.RefreshAll` (les toggles `get`/`set` ne déclenchent pas `SETTING_CHANGED`, donc les lignes sœurs ne se redessinaient pas au clic). L'état mémorisé reste visible, atténué. Même comportement dans le sélecteur du panneau.
- Clic gauche sur l'icône d'en-tête (et le bouton sous la fenêtre) : lance ou relance la recherche **sans** ouvrir le panneau (icône accent + message de chat). Clic droit : ouvre ou ferme le panneau.
- Pendant une recherche active sans résultat, le panneau affiche « Recherche en cours… aucun joueur pour l'instant » (au lieu d'inviter à cliquer sur Chercher un groupe).

## 1.0.0 — 2026-11-25

Première version destinée à être installée en jeu (non testée dans le client).

- Le dossier de l'addon s'appelle désormais **PSGroupFinder** (plus `Polestar_GroupFinder`), pour ne pas être effacé par une mise à jour manuelle de Polestar. Titre affiché : « Group Finder for Polestar » / « Recherche de groupe (Polestar) ».
- Variables sauvegardées : `PSGroupFinderDB` / `PSGroupFinderCharDB`. Les réglages d'une éventuelle 0.x sont repris seulement si l'ancien addon est encore chargé une fois ; sinon ce n'est pas grave (rien n'avait été publié).
- Fichiers de packaging : `.pkgmeta` (dépendance CurseForge `polestar`), `CHANGELOG.md`. L'identifiant CurseForge reste un placeholder commenté dans le `.toc`.
- Bouton dans l'en-tête du guide Polestar, juste à gauche de la loupe (activé par défaut) : clic gauche pour chercher, clic droit pour le panneau. L'icône est grisée si l'addon est coupé, colorée si une recherche est en cours. Sans API publique pour l'ajouter : accroche sur `Theme.GuideParts().nav.Lookup` (interne) sous pcall, avec repli sur le bouton sous la fenêtre.
- Langues de recherche (un seul réglage). Chaque joueur diffuse la langue de son client (`GetLocale()`, ex. `f`). Par défaut, seule cette langue est cochée ; on peut en ajouter d'autres, ou cocher « Toutes les langues » (les autres cases se grisent). Le filtrage est unilatéral : on liste un joueur si sa langue de jeu est dans notre recherche (ou si Toutes est cochée). Le groupage auto se fait de chaque côté selon sa propre recherche. Un peer v0.2 sans langue n'est visible que si Toutes est cochée. La liste affiche la langue (ex. FR).
- Le reste reprend les fonctions de la 0.2.0 : session de recherche multi-quêtes, retrait automatique d'un objectif terminé, groupage automatique optionnel, page d'options dans Polestar, corrections d'interface.

## 0.2.0 — 2026-11-25

- Une recherche est une session : les quêtes quittent la recherche quand leur objectif est terminé ; la recherche continue pour les autres, puis s'arrête.
- Option « Grouper automatiquement (même quête) », désactivée par défaut.
- Page « Recherche de groupe » dans les options de Polestar.
- Panneau à hauteur dynamique, cases et fermeture au thème Polestar, placement à gauche si le bord droit manque de place.

## 0.1.0 — 2026-11-25

- Première version : recherche de joueurs sur les mêmes quêtes (kill, élite nommé, loot, groupe), canaux d'addon, panneau et bouton sous la fenêtre Polestar, mode autonome.
