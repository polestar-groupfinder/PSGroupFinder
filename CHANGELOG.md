# Changelog

## Unreleased

- **Demo mode (temporary)**: `/psgf demo` plays the flow alone in game with three made-up
  players fed through the real receiving code; nothing is sent while it is on, every outgoing
  message, invite and leave is printed instead. The calls that act on the world (invite, leave,
  chat lines, group state) now go through one helper each in `Core.lua`.

- **Draining button**: the message box no longer shows its countdown in brackets; the time left
  drains the main button's accent colour, and the pointer on the box pauses it, so a
  last-moment click still lands.
- **Open the finder near my quest** (off by default): when Polestar's arrow brings you within
  about 120 m of an objective of a kill, named, loot or group quest, the panel opens, once per
  step, out of combat and outside instances. Nothing is sent.
- The channel line and its Test button leave the panel's settings view; the test stays on
  Polestar's page and as `/psgf test`, and the main view still warns when the channel is down.

- **Chat reading removed**: the beta “Spot players asking in chat” is gone.
- **Search languages by region**: only the languages played in the game's region are offered
  (`GetCurrentRegion`), plus the client's own; all of them when the region is unknown.
- **Messages tab**: Polestar's page gets an Essentials tab and a Messages tab: the message box
  (on/off and its style) and one section per message with its own switch, its text (opens the
  Messages window on it) and its key binding. Each message is on by default; with Announce off
  its button goes, with goodbye off the box only offers to leave.
- **Message box styles**: Polestar (the group's quests and objectives, then the message) and
  Compact (the message and the buttons).
- Polestar's options page is named **Group Finder** (it sits in Polestar's own settings, so the
  short name fits its sidebar); the panel and the guide menu row keep “Community Group Finder”.
- **Clearer labels**: “Let others find me when they search” (was “Answer searches for my
  quests”), “Show others my distance” (was “Share my map position”), “Show the message box when
  grouping” (was “Say hello and goodbye to the group”); the Messages window says when each text
  is sent. The search languages are set on Polestar's options page (in the panel's settings view
  only without it).
- **Tidier panel**: the settings move behind a cog in the title bar (a settings view in the same
  panel: on/off, the categories, languages, where Announce speaks, Messages,
  Polestar's options). The main view keeps Find a group / Stop, Announce, the search in progress
  and the players; while off, it only says so with a Turn on button. The channel line shows only
  when the channel does not work.
- **Player rows**: the second line shows the player's progress on the shared quest, small
  (“Kobold Camp Cleanup  7/10 Kobold Vermin slain”), and Whisper / Invite are icon buttons (a
  speech bubble; two people and a plus, which asks to join for a player already in a group).
  Searches and answers carry each quest's objective counts, numbers only (“@4/12;0/5”); the
  reader names them from its own quest log. Clients older than this one drop those entries.
- **Community Group Finder**: the new name, so that it is not taken for the game's own Group
  Finder (key I), which Polestar already points to.
- **One channel**: searches go over the finder's hidden channel only (no guild), answers and
  updates by whisper. Auto-group stays an option the player turns on.
- **One row in the guide menu**: “Community Group Finder” opens the panel, where Find a group
  is; the separate Find a group row is gone.
- **No /say or /yell for searches**: Forever's client refuses addon messages there; searches go
  over the hidden channel and the guild, answers by whisper.
- **Nothing acts on its own by default**: “Answer searches for my quests” is now off by default,
  and the channels are tested only when you ask (Test button, `/psgf test`), no longer after
  login. Auto-group and chat reading stay off by default; hello, goodbye and announce are click
  or key only.
- **Guide menu instead of a header icon**: Polestar's guide header has no slot for another
  addon, so the header icon, its fallback button under the window and the “Button in the
  Polestar header” option are gone; the guide's “⋯” menu gets **Find a group** and **Group
  Finder** (opens the panel). The goal-row button stays.
- **Progress as counts**: `{progress}` and the party box show what is left as x/y (“[The Defias
  Brotherhood] 4/12 Defias Pillager slain”, “(done)”).
- Renders of the panel, the guide menu and Say hello beside Polestar's own guide window replace
  the earlier mock-up (`docs/mockup/`).
- **Hello and goodbye**: with a group formed through the finder, a small floating box (quest
  tracker style: the group's quests, your progress, the objectives left) offers **Say hello** for
  5 seconds, only on your click or its key binding; after that the chance is gone. When the
  group's quests are done it offers **Goodbye & leave** for 30 s (the old Leave / Stay window is
  gone). Key bindings “Say hello to the group” and “Say goodbye and leave the group”.
- **Invite / Ask**: Invite also whispers a short message naming the shared quests; for a player
  already in a group the button reads **Ask** and whispers a request to be invited instead.
- **Messages window**: the five texts (announce, invite, ask, hello, goodbye), in English by
  default for every client, editable, with a live preview. `{quests}` stands for the quest links,
  `{progress}` for the quest links with your progress; the text box's tooltip says so. An empty
  text is never sent. The announce line no longer has a language selector.
- **Lighter, sorted options**: the panel shows only the master switch; the others fold under
  **Settings**, by category (Grouping, Party, Chat (beta), Interface), like the sections of
  Polestar's options page. “Offer to leave”, “Say a message in /p before leaving” and “Also for a
  group not formed by the finder” are replaced by one switch, “Say hello and goodbye to the
  group”. The panel's Leave button says goodbye for a finder group only.
- **English only**: the French interface strings, the French titles in the TOC, the outdated
  screenshots, infographic and mock-up, and INSTALLATION.md are removed (the README has the
  install steps). Search languages remain, for grouping only.
- **Spot players asking in chat** (beta, off by default, read only): players without the addon who
  look for a group on one of your open quests in General, the other public channels, /say or
  /yell are listed in both panels, marked “chat”, with their line in the tooltip. A line counts
  when it links the quest, contains its whole title (accents, case and punctuation aside; a short
  title also needs an LFG word) or has an LFG word and a distinctive title word. Five minutes per
  entry, never contacted or auto-invited on their own, nothing read in an instance.
- **Announce**: a button says one short looking-for-group line for your quests (“LFG Wanted:
  Hogger, whisper me!”, the editable announce message) in the zone's General channel by default,
  or the looking-for-group channel, /say, /yell. Quests are named by the client's quest link when
  it names the right quest, else by title, and the line is cut to 255 bytes. Only on a click, the
  key bind “Announce my search in chat” or `/psgf announce`, at most once a minute; the tooltip
  previews the line. The quest panel announces its one quest.
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
