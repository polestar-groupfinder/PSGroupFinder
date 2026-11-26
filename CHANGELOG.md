# Changelog

## Unreleased

- **Hello and goodbye**: with a group formed through the finder, a small floating box (quest
  tracker style: the group's quests, your progress, the objectives left) says hello in /p after a
  5-second countdown, with the quest links and your progress; Cancel keeps quiet. When the group's
  quests are done it offers **Goodbye & leave** for 30 s (the old Leave / Stay window is gone).
  Key bindings “Say hello to the group” and “Say goodbye and leave the group”.
- **Invite / Ask**: Invite also whispers a short message naming the shared quests; for a player
  already in a group the button reads **Ask** and whispers a request to be invited instead.
- **Messages window**: the four texts (invite, ask, hello, goodbye) with a live preview;
  `{quests}` for the quests, an empty text is never sent.
- **Lighter options**: the panel shows only the master switch, the others fold under
  **Settings**; “Offer to leave”, “Say a message in /p before leaving” and “Also for a group not
  formed by the finder” are replaced by one switch, “Say hello and goodbye to the group”. The
  panel's Leave button says goodbye for a finder group only.
- **Spot players asking in chat** (on by default, read only): players without the addon who
  look for a group on one of your open quests in General, the other public channels, /say or
  /yell are listed in both panels, marked “chat”, with their line in the tooltip. A line counts
  when it links the quest, contains its whole title (accents, case and punctuation aside; a short
  title also needs an LFG word) or has an LFG word and a distinctive title word. Five minutes per
  entry, never contacted or auto-invited on their own, nothing read in an instance.
- **Announce**: a button says one short looking-for-group line for your quests (“LFG Wanted:
  Hogger, whisper me!”) in the zone's General channel by default, or the looking-for-group
  channel, /say, /yell. The language of the line is picked in a selector (FR, EN, DE, ES, IT, PT,
  RU, KO, ZH, ZHT), apart from the game language; quests are named by the client's quest link
  when it names the right quest, else by title, and the line is cut to 255 bytes. Only on a
  click, the key bind “Announce my search in chat” or `/psgf announce`, at most once a minute;
  the tooltip previews the line. The quest panel announces its one quest.
- **New icon**: two line-art people (`Media/icon-group.tga`, 64×64, drawn by
  `tools/make-icons.py`) replace the eye everywhere: header, options sidebar, goal rows, windows.
- **Quest log buttons removed**: the buttons in the game's quest log and in the Map & Quest Log
  details view were poorly integrated and relied on unverified frame names. The goal-row button
  in the Polestar guide, Alt-click and `/psgf quest <id>` remain.
- **Leave message**: said only when you leave with the finder's own Leave buttons. The game's
  `LeaveParty` is no longer wrapped (taint risk); leaving through the game says nothing.
- **Quieter chat**: the game's “No player named X is currently playing.” after an addon whisper
  to a player who logged off, and the notices of the hidden channel, are filtered out natively
  (`ChatFilter.lua`). The channel probe after login and the “player found” lines no longer print;
  a finished objective is one line. `/psgf debug` turns the filters off and traces every message
  sent and received.
- **Code layout**: `Comm.lua` split into `Protocol.lua` (formats), `Channels.lua` (channels,
  probe) and `Comm.lua` (searches, handling); `UI.lua` into `UI/`; `Polestar.lua` and `Hooks.lua`
  into `Polestar/`. Duplicated code merged (message header, sends, scoring, name helpers).
- **Compatibility code removed**: nothing was published before 1.0.0, so the `Polestar_GroupFinder`
  saved-variables migration and the pre-1.0 message and language formats are gone. The language
  field is now required in every player message.
- Tooling: `build.sh` writes to `dist/`, CI runs luacheck, the simulation and the build; the
  mock-ups folder is gone.

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
