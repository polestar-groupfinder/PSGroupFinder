# Installation — Group Finder for Polestar (PSGroupFinder) 1.0.0

Companion to [Polestar](https://www.curseforge.com/wow/addons/polestar) for WoW: Forever 1.60.1.
**This addon has not yet been tested in the game client.**

## Requirements

- **WoW: Forever** installed (client 1.60.1).
- **Polestar** already installed and up to date (CurseForge, the Polestar client, or by hand).
  Without Polestar the addon still works, with a standalone window, but the button in the guide
  header (or under the window) and the Polestar options page will be missing.

## Where to put the addon

Forever has its own folder, separate from Retail and Classic: **`_forever_`**.

| System | Default path |
|---|---|
| Windows | `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns` |
| macOS | `/Applications/World of Warcraft/_forever_/Interface/AddOns` |

If the game is not in that location, find the folder as follows:

1. Open the **Battle.net** app.
2. Select World of Warcraft, then the **WoW: Forever** version (menu above Play).
3. Click the gear next to Play, then **Show in Explorer** (Windows) or **Show in Finder** (Mac).
4. Open `_forever_`, then `Interface`, then `AddOns`.

If the `Interface` or `AddOns` folders do not exist yet, create them with exactly that spelling.
Do not put the addon in `_retail_` or `_classic_era_`: Forever would not see it.

## Install

1. Fully quit the game.
2. Unzip `PSGroupFinder-1.0.0.zip`. You should get a `PSGroupFinder` folder that contains the
   file `PSGroupFinder.toc`.
3. Place that `PSGroupFinder` folder **directly** in the `AddOns` folder above. The final path
   must be:
   `.../_forever_/Interface/AddOns/PSGroupFinder/PSGroupFinder.toc`
   (not `AddOns/PSGroupFinder/PSGroupFinder/PSGroupFinder.toc`, and not a wrapping
   `PSGroupFinder-1.0.0` folder).
4. **Fully** restart the game. A `/reload` is not enough for a new addon.

## Check and enable

1. On the character-select screen, click **AddOns**. Tick **Group Finder for Polestar**
   (on a French client the title is **Recherche de groupe (Polestar)**) and confirm.
2. Enter the game. In Polestar: **Options > Group Finder** (or type `/polestar options`): the
   entry uses the same **group icon** (two people) as the header button, monochrome like the
   other sidebar icons. Tick **Enable the group finder**. While that is off, nothing is sent or listened to.
3. (Optional) Tick **Group automatically (same quest)** only if you want invitations without a
   click. Both players must have it on.
4. Bind a key: Esc > Options > Key Bindings, **Polestar** category:
   - “Find a group for my quests”
   - “Show or hide the group finder”
5. Type `/psgf test`: after a few seconds, chat reports which channels work (green = OK).
   By default a small **group icon** (two people) is hooked in the Polestar guide header,
   **immediately to the left of the magnifying glass**: left click = search, right click = panel. If you prefer the
   older button under the window, uncheck “Button in the Polestar header”. Panel command: `/psgf`.
6. **Search languages**: by default only **your game language** (for example enUS → English) is
   ticked. You can tick others one by one, or tick **All languages** (the list then folds, and
   everyone appears). A player appears on *your* list if their game language is among those you
   ticked (or if you ticked All). Every options control has a tooltip on hover.

## Usage

- Click the header icon (or **Find a group**, the key bind, or `/psgf search`) while on a kill,
  named-elite, loot or group quest. Players who also have the addon on, the same quest, and whose
  game language is in your **Search languages**, appear in the panel (with their language, e.g.
  EN): **Whisper** or **Invite**.
- When an objective is done, that quest leaves the search on its own; the others in the same
  place continue. The search stops when none remain, or with **Stop** (`/psgf stop`).
- **Players on a quest**: the small group button under a Polestar guide objective icon opens the list of players who have **this** quest, even in another zone. A
  second click closes the pane; a click for another quest switches to it. **Search for this quest**
  queries them (once every 15 s). In the Polestar guide, **Alt + click** on an objective does the
  same. `/psgf quest 33` opens the list for quest #33.
- **Leave the group** (1.1): when every quest you grouped for through the addon is done, a small
  window asks **Leave** or **Stay**. Option “Say a message in /p before leaving” (off by default,
  text editable with **Edit…**): it is sent when you click Leave or the panel’s **Leave the group**
  (visible only while in a group). Leaving through the game (portrait, `/leave`) says nothing.
  Option “Also when leaving a group not formed by the finder” for a group you joined by hand
  (off by default). Nothing happens on its own.
- Other commands: `/psgf on`, `/psgf off`, `/psgf test`, `/psgf reset`, `/psgf hooks` (reports
  whether the buttons found their place in the Polestar guide: copy that into a message if a
  button is missing), `/psgf debug` (shows the addon's traffic and notices in chat).

## Uninstall

Quit the game, then delete the `PSGroupFinder` folder in `AddOns`. To remove the settings as
well, delete the `PSGroupFinder.lua` files in
`World of Warcraft/_forever_/WTF/Account/<your account>/SavedVariables/` (and in the character
folder, if there is one).

## First test with two accounts

Do this with two people (two accounts, or two characters of the **same faction** on the same realm):

1. Install the same version of the addon on both clients, restart the game, enable the addon in
   the list, then **Enable the group finder** on both sides. If the two clients are not in the
   same game language, tick the other’s language (or **All languages**) in **Search languages** —
   each side only sees what *its* search allows.
2. Run `/psgf test` on each account and note the channel reported.
3. Take **the same quest** (a kill or loot near you, for example at the start of Elwynn or
   Durotar) and stand **close to each other** (especially if the test did not confirm the hidden
   channel: YELL and SAY only reach nearby players).
4. On account A, click **Find a group**. Account B should appear in A’s panel (and the other way
   around if B also has A’s language in their search). Try **Whisper**, then **Invite**.
5. For the per-quest list: on account B, click the small group button under the quest's
   objective in the Polestar guide (B may be in another zone); a second click should close the
   pane. **Search for this quest** should show A with their zone and percentage. Type `/psgf hooks` if
   a button is missing.
6. For leaving the group: invite A from the panel, finish the quest on both sides (or abandon it
   to see that it does not count): the **Leave / Stay** window should appear for each of you, and
   nothing should happen before your click. The panel’s **Leave the group** button should also
   send the /p message if that option is on, only once.
7. For auto-grouping: tick the option on both sides, and make sure each appears on the other’s
   list (each side filters on its own). Leave the group, start a search again. The invitation
   should go out on its own. If an invitation window stays on screen, accept it by hand and
   mention it: this part is not yet confirmed on Forever.

If nobody appears: check that the addon is enabled on both sides, that you still have the same
quest to do, that you are not in an instance, that the other’s language is in your Search
languages (or that All is ticked), and move closer before running `/psgf test` and a search
again (20 s delay between two searches).
