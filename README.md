# Community Group Finder for Polestar (PSGroupFinder)

An **optional** module for [Polestar](https://github.com/fitzforge/polestar) (WoW: Forever 1.60.1):
it finds players who are on **the same quest as you, near you** (kills, named elites, loot from
mobs, group quests) and lets you **whisper** or **invite** them. Grouping can be **automatic**
(an option, off by default). It is a separate addon: it does not modify Polestar and also works
without it (standalone window). Licence: GPL-3.0-or-later.

> Work in progress: this version is being ported into Polestar itself. It has not been tested in
> the game client yet; screenshots will follow. Renders of the windows beside Polestar's guide
> (drawn, not captured in game): [the panel and its settings view](docs/mockup/panel.png),
> [the message box, both styles](docs/mockup/message-box.png), [Say hello](docs/mockup/hello.gif),
> the options page's [Essentials](docs/mockup/options-essentials.png) and
> [Messages](docs/mockup/options-messages-1.png) ([scrolled](docs/mockup/options-messages-2.png)) tabs.

## Installation

1. Install [Polestar](https://www.curseforge.com/wow/addons/polestar) first.
2. Download `PSGroupFinder-<version>.zip` from the
   [releases page](https://github.com/polestar-groupfinder/PSGroupFinder/releases) (under
   **Assets**, not “Source code”), or build it with `./build.sh`.
3. Unzip it into `World of Warcraft/_forever_/Interface/AddOns/`. The final path must be exactly
   `AddOns/PSGroupFinder/PSGroupFinder.toc`.
4. Fully restart the game (a `/reload` does not load a new addon), tick **Community Group
   Finder for Polestar** in the AddOns list, then `/psgf on`.

## Features

- **Find a group**: **Community Group Finder** in the Polestar guide's “⋯” menu opens the panel,
  whose **Find a group** starts the search; also a key binding or `/psgf search`. A search is a
  session on your relevant quests: a quest leaves it once its objectives are done, the others
  stay, and it stops when none remain, on **Stop**, in an instance or when your group is full.
- **Results**: players found, best first (shared quests, Polestar's current step, distance), with
  their language, their progress on the shared quest (“7/10 Kobold Vermin slain”), and two icon
  buttons: **Whisper** (speech bubble) and **Invite** (two people and a plus). Searches go over the addon's hidden channel, which
  every player running it joins (no /say, /yell or guild). A player already in a group shows **Ask** instead:
  you cannot invite them, so it whispers a request to be invited. Invite and Ask also whisper a
  short message. Only on your click.
- **Players on this quest**: the small button under a Polestar objective icon (or Alt-click on
  the objective, or `/psgf quest <id>`) lists the players who have that quest, in any zone, with
  their zone and progress; **Search for this quest** asks everyone.
- **Announce**: says one looking-for-group line (“LFG [Quest], whisper me!”) in the zone's
  **General** channel (or the looking-for-group channel, /say, /yell), for players who do not
  have the addon. Only on your click, key binding or `/psgf announce`, at most once a minute; the
  tooltip previews the line.
- **Message box**: when a group formed through the finder gets together, a small box offers
  **Say hello** for 5 seconds, only on your click or key; then the chance is gone. Two styles:
  **Polestar** (the group's quests and the objectives left, as counts, then the message) and
  **Compact** (the message and the buttons). When every quest you grouped for is done, it offers
  **Goodbye & leave** for 30 seconds (the goodbye message, then you leave). The panel's **Leave
  the group** also says goodbye for a finder group; leaving through the game says nothing.
- **Messages**: announce, invite, ask, hello and goodbye, each with its own switch (on by
  default), all in English by default for everyone and editable, with a live preview. `{quests}` is replaced by the quest links, `{progress}` by
  the quest links with what is left (“[The Defias Brotherhood] 4/12 Defias Pillager slain”). An
  empty text is never sent.
- **Auto-grouping** (off by default, needed on both sides): after your search, the addon invites
  the player found (or asks them to invite you) and accepts their invitation. Same faction, party
  of 5 at most, never in an instance, only from a player the finder expects.
- **Search languages** (grouping only): your game language by default; tick others, or **All
  languages**. Only the languages played in the game's region are offered (Europe: EN, FR, DE,
  ES, IT, PT, RU; the Americas: EN, ES, PT; Korea, Taiwan, China: their own and EN; every
  language when the region is unknown), plus your own. A player appears on your list if their
  game language is in your search.
- **Quiet chat**: the game's notices about the addon's own traffic are hidden; `/psgf debug`
  shows them and traces every message.

## Options

The panel has two views. The main one holds Find a group / Stop, Announce, the search in
progress and the players found. The **cog** in its title bar opens the settings view: the master
switch, the grouping and party settings, where Announce speaks, the channel's test,
**Messages…** and Polestar's options page.

The “Group Finder” page in Polestar's options has two tabs:

| Tab | Sections |
|---|---|
| Essentials | Group Finder (enable, test the channel); Grouping (group automatically, off; let others find me when they search, off: answers their searches with a hidden whisper; show others my distance, on: sends your map position); Search languages; Key bindings (search, panel) |
| Messages | Message box (show it when grouping, on; style: Polestar or Compact); then one section per message (Hello, Goodbye, Announce, Invite, Ask to join): its switch, its text, its key binding where it has one |

Nothing acts on its own by default: answering other players' searches and auto-grouping are
opt-in; hello, goodbye and announce only ever go out on a click or a key.

The texts are in **Messages…** (panel and options page). Commands: `/psgf` (panel), `/psgf
search`, `/psgf stop`, `/psgf announce`, `/psgf on|off`, `/psgf test` (tests the channels),
`/psgf reset`, `/psgf quest <id>`, `/psgf hooks`, `/psgf debug`.

## What is sent

Only while the addon is on, as hidden addon messages (prefix `PSGF`, ≤ 255 bytes), on the hidden
`PSGroupFinder` channel, answers and updates by whisper. No /say or /yell (Forever's client
refuses addon messages there) and no guild: the finder talks to the players who run it. The formats are in [`Protocol.lua`](PSGroupFinder/Protocol.lua).

| Message | When | Contents |
|---|---|---|
| Search `S` | your click / key bind, at most every 20 s; when a quest leaves your search (also while grouped), sent again on the channel and to the players found | up to ~10 quest IDs with their kind (kill, named, loot, group) and objective counts (“@4/12;0/5”, numbers only), map, x/y (if shared), level, class, party size, flags (auto-group, faction), client language |
| Reply `R` | only with “Let others find me when they search” on (off by default): whisper to the searcher, at most once per 20 s per player | only the IDs of **shared** quests with their objective counts, your map/position, level, class, flags, language |
| End `X` | your search ends (last quest done, stop, group full) | your session id: the others drop you from their list |
| Request `G` | auto-group (off by default), whispered to the player who should invite you | the IDs of the shared quests |
| Quest search `Q` | your click on a quest button, at most every 15 s | the id of **one** quest, map, x/y, level, class, party size, flags, language |
| Quest reply `A` | only with answers on: whisper to the asker, if you have the quest, rate-limited | that id and your progress in %, your position, level, class, language |
| Test `T` | only when you ask: the Test button or `/psgf test` | a random id (we listen for our own echo) |

Never free text, never the whole quest log, nothing inside an instance. The visible chat lines
the addon can say are the **Announce** line and the messages of the **Messages** window, each
only on your click or key.

## Channels and detection

The hidden `PSGroupFinder` channel is joined 6 s after login (so it does not take /1 or /2) and
removed from the chat tabs; searches go out on it. The panel colours it from what happened:
green = our own message came back, yellow = accepted with no echo, red = refused, grey = not
joined yet; `/psgf test` checks it on request and details the result.
Rate: a small queue (burst of 4, then ~0.8 msg/s), retried on `AddonMessageThrottle`.

## Integration with Polestar

| Uses | Status in Polestar | For |
|---|---|---|
| `Polestar.API.version == 1`, `Polestar.On("STEP_CHANGED" / "GUIDE_CHANGED" / "TABS_CHANGED")`, `Polestar.Compat.IsOnQuest` / `IsQuestReadyForTurnIn` | **public API** (docs/API.md) | know when the step changes, filter quests |
| `Polestar.Theme.Skin`, `Font`, `Color`, `Hex`, `OnChanged`, `GuideParts().window` | **public Skin API** | paint our frames, dock beside the guide window |
| `Polestar.RegisterOptions` (with the public `icon` and `help` fields) | **semi-internal** (ARCHITECTURE.md “Options registry”), under `pcall` | “Group Finder” page in Polestar's options, one section per category |
| `Polestar.Free.MenuItems()` | **internal**, wrapped under `pcall` (the original runs first) | our row in the guide's “⋯” menu |
| `UI.ShowOptions(key)`, `UI.Options.Relayout`, `Widgets.RefreshAll`, `Options.Kit.pages` / `Grouped.NavItems` / `Widgets.NavRowAfter` | **internal**, under `pcall` | panel “Options” button, language rows folding at once, sidebar icon |
| `Polestar.Engine.GetGuide()` / `GetLiveStep()` and `step.goals[].quest`, `Compat.GetPlayerMapPosition()` | **internal**, under `pcall` | current step's quests first, position (otherwise `C_Map`) |
| `GuideParts().rows` and on each row `psGoal`, `Icon`, `Check`, `Alt`; `Polestar.QuestClickTips` / `QuestRowClick` | rows documented in the skin reference, the rest **internal**; wrapped under `pcall`, the original always runs first | goal-row button, tooltip help line and Alt-click |

If an internal hook changes in a Polestar version, that piece falls back or stays hidden; without
Polestar, or with another API version, the addon is a standalone window.

## Known limits / to test in game

- **CHANNEL**: searching players worked over the hidden channel in a two-player test on
  Forever; if a client refuses it, `/psgf test` says so and searching cannot work there.
- **Accepting an invitation** with `AcceptGroup()` is documented for Classic but **unconfirmed on
  Forever**; if the client refuses, the invitation window stays and a chat line says so.
- Trial / veteran accounts cannot send addon messages.
- “Item” quests do not say whether the item comes from a mob or the ground: they all count as
  “loot”. “Named elite” is a heuristic: a kill objective that asks for exactly 1 mob.
- Only players **who have this addon and have enabled it** answer.
- Tested out of game only (`luacheck` and a multi-client simulation with a fake WoW API and a
  fake Polestar). Not yet tested in the client.

## Development

```
luacheck PSGroupFinder        # lint (config .luacheckrc)
lua5.1 tests/sim.lua          # multi-client simulation
./build.sh                    # versioned zip in dist/
python3 tools/make-icons.py   # redraws Media/icon-group.tga (needs Pillow)
```

CI runs the first three on every push (`.github/workflows/ci.yml`).

| File | Role |
|---|---|
| `Core.lua` | settings, internal message bus, events, slash commands, key bindings |
| `Locales.lua`, `Lang.lua` | interface strings (English); search languages (for grouping only) |
| `Throttle.lua`, `Protocol.lua`, `Channels.lua`, `Comm.lua` | send queue; message formats; channels and probes; searches and message handling |
| `ChatFilter.lua` | hides the game's notices about our own traffic (off in debug mode) |
| `Quests.lua`, `Session.lua`, `Matcher.lua` | which quests count; the search in progress; the players found and their order |
| `Group.lua`, `Leave.lua`, `Messages.lua`, `Announce.lua` | auto-grouping; the finder group from hello to goodbye; the editable messages; the public announce |
| `UI/` | shared widgets, the main panel, the quest panel, the Messages window, the party box |
| `Polestar/` | Polestar detection and live step, guide menu rows and docking, options page, goal-row button |

Inspired by the public descriptions of Group Up, QuestScout and Group Quest Finder
(CurseForge, “All Rights Reserved”): **none of those addons' code was read or copied**.
