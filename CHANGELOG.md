# Changelog

## 1.0.0 — 2026-11-25

First version meant to be installed in game (not tested in the client). Nothing was published
before this: the 0.1, 0.2, 1.0.1 and 1.1 identifiers were only local steps.

- The addon folder is named **PSGroupFinder**. Displayed title: “Group Finder for Polestar” /
  “Recherche de groupe (Polestar)”. Saved variables: `PSGroupFinderDB` / `PSGroupFinderCharDB`.
- Search for players on the same quests (kill, named elite, loot, group), addon channels
  (CHANNEL, YELL, SAY, GUILD; replies by whisper), panel (Whisper / Invite only on your click).
- A search is a session: quests leave the search when their objective is done; the search
  continues for the others, then stops. Option “Group automatically (same quest)”, off by default.
- Button in the Polestar guide header, immediately to the left of the magnifying glass (on by
  default): monochrome eye icon (`Media/icon-eye.tga`, drawn for this addon; fallback: the two
  silhouettes `Media/icon-group` if the file is missing). Left click searches **without** opening
  the panel (accent icon + chat message), right click opens or closes the panel (including the
  per-quest list). Fallback: “Find a group” button under the window. Internal hook on
  `Theme.GuideParts().nav.Lookup`, under pcall.
- During an active search with no result, the panel shows “Searching… no player found yet.”
- Search languages (a single setting). Each player broadcasts their client language. By default
  only that language is ticked; others can be added, or “All languages” can be ticked, which
  **folds and hides** the list (accordion: the section resizes, with no gap). Unilateral
  filtering. An older peer with no language is visible only if All is ticked.
- “Group Finder” page in Polestar’s options. Every setting, key bind and button has a **tooltip**
  on hover (public `help` field of `RegisterOptions`, frFR and enUS). The sidebar entry uses
  **the same eye** as the header (`Media/icon-eye`, 16×16, monochrome like the others). Public
  `icon` field, full path. Internal fallback under pcall if the grouped options page does not
  send the icon to indented rows. The language list uses `needs` to hide the rows when “All” is
  ticked, plus `Widgets.RefreshAll` and `Options.Relayout` (under pcall) so the card shrinks;
  greying remains a last resort.
- **Players on this quest**: a small button (the eye) opens the panel in quest mode (name, level,
  class, language, zone, progress, distance or “other zone”, Whisper / Invite) with **Search for
  this quest**. A second click on the same trigger (objective row, Alt-click, quest log, details
  view, header right-click) closes the pane; a click for another quest switches to it.
  1. Polestar guide window: under the objective icon, to the left of the sub-line;
  2. objective tooltip: help line “Alt-click: see the players on this quest” and Alt-click
     (other clicks stay with Polestar);
  3. game quest log: one button per quest, **to the right** of the tracking checkbox (2–4 px,
     same column if there is no checkbox); the title is shortened so it does not run under the
     button;
  4. Map & Quest Log details view (details on the right): an eye button to the left of **Back**,
     or failing that to the right of **Track**, for the displayed quest.
  Also `/psgf quest <id>` and `/psgf hooks` (frame, id, button, anchor).
- **Protocol**: `Q` messages (“who has quest N?”) and `A` (whispered reply with the percentage),
  regardless of zone. Same language rules, 15 s pause between two quest searches, send limits.
- **Leave the group** when every quest you grouped for through the addon is done: **Leave** /
  **Stay** window. Option: a /p message (editable text, default FR/EN according to the client).
  The message is sent when you leave — **Leave** on that window, the panel’s **Leave the group**
  button (visible only while in a group), or leaving through the game (portrait, `/leave`,
  `LeaveParty`) — never on its own. Pre-hook of `LeaveParty` / `C_PartyInfo.LeaveParty` so the
  message is said **before** leaving, with a guard against a double send. A group joined by hand
  is never offered or announced, unless the option “Also when leaving a group not formed by the
  finder” (`leaveMsgAny`, off by default) is on.
