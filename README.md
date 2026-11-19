# Forever Quest Filters

A WoW Forever addon that filters quests by completion: show only completed-quest
markers on the world map, and filter or sort the quest log so quests that are
ready to turn in come first.

Map addons like Questie, Forever Quest Pins and OneForAll each draw their own
markers, and none of them can show only turn-ins. Forever Quest Filters sits on
top of them: one checkbox hides everything except the quests you can hand in.

## Features

- **Completed quests only on the map.** Hides every quest marker except
  completed quests (Questie's turn-in icons, OneForAll's `?` icons, the game's
  own completed quest pins). Quest start `!` markers, objective icons and other
  addons' map icons are hidden too. Your player arrow, party members, zone
  highlights, labels and your map waypoint stay visible.
- **Hold-to-peek keybind.** Hold a key to see completed-only markers for a
  moment and let go to bring everything back. There's also a toggle keybind.
- **Quest log filtering and sorting.** Show only completed quests in the quest
  log, and/or sort completed quests to the top of each zone.
- **Sortable quest list window.** A separate list of every quest in your log,
  sortable by completed first, level, or quest log order.
- **Modules per addon.** Support for each map addon lives in its own small file
  and only switches on when that addon is loaded, so adding a new addon is one
  new file.

## Supported addons

| Addon | What happens while the filter is on |
|---|---|
| Questie | Turn-in icons stay, all other icons are hidden |
| Forever Quest Pins | All `!` quest start markers are hidden |
| OneForAll | `?` turn-in icons stay, `!` icons and walking routes are hidden |
| Leatrix Maps | Its POI icons are hidden; revealed areas and overlays stay |
| WoW Forever (default) | Quest pins stay only for completed quests |
| Anything else | Small icons drawn on the map are hidden |

None of these addons are required. Each module is idle unless its addon is loaded.

## Installation

1. Download or clone this repository.
2. Put the `ForeverQuestFilters` folder in
   `World of Warcraft/_forever_/Interface/AddOns/`.
3. Restart the game or type `/reload`.

## Usage

### World map

Open the world map's filter dropdown. At the bottom, under
**Forever Quest Filters**:

- **Completed quests only (N)**: toggles completed-only markers. N is the number
  of quests in your log ready to turn in.
- **Sortable quest list...**: opens the quest list window.

### Quest log

Open the quest log's settings dropdown. Under **Show Quest Objectives**:

- **Completed quests only**
- **Sort completed quests first**

Both settings are saved between sessions. While either one is on, the game's
quest list is hidden and the addon draws its own list in the same place.
Clicking a quest opens its details as usual. The quest log's search box doesn't
filter the addon's list.

### Keybinds

Under Options → Keybindings → Forever Quest Filters:

- **Toggle completed-only map markers**
- **Hold to show completed-only map markers**
- **Toggle sortable quest list**

### Slash commands

| Command | Does |
|---|---|
| `/fqf` | Toggle completed-only map markers |
| `/fqf log` | Toggle completed quests only in the quest log |
| `/fqf sort` | Toggle completed-first sorting in the quest log |
| `/fqf list` | Toggle the sortable quest list window |
| `/fqf modules` | List modules and whether each is on |
| `/fqf module <name> on\|off` | Off leaves that addon's markers visible while filtering |
| `/fqf debug` | List the markers on the current map and which module handles each |

`/questfilters` works in place of `/fqf`.

## Adding support for another addon

Each module tells the filter which of one addon's markers to keep. To add one:

1. Open the map with the filter on and run `/fqf debug`. It lists every marker
   type on the map and any icons drawn straight onto the map, with their
   texture, size and module.
2. Copy `Modules/_TEMPLATE.lua.txt` to `Modules/<AddonName>.lua`.
3. Fill in the classify function. Return `true` to keep a marker, `false` to
   hide it, or `nil` if it isn't that addon's marker.
4. Add the file to `ForeverQuestFilters.toc` with the other `Modules\` lines.

A minimal module:

```lua
local _, ns = ...

ns.MapFilter:RegisterModule({
    name = "MyAddon",
    addon = "MyAddon",   -- folder name; skipped if the addon isn't loaded
    priority = 50,       -- lower runs first

    -- map pins: true = keep, false = hide, nil = not mine
    Classify = function(pin, template)
        if template ~= "MyAddonPinTemplate" then return nil end
        return false
    end,

    -- frames drawn straight onto the map (not map pins), same return values
    -- ClassifyFrame = function(frame) return nil end,

    -- optional:
    -- Init      = function(self) end,  -- once, when the addon is loaded
    -- OnEnable  = function(self) end,  -- filter turned on
    -- OnDisable = function(self) end,  -- filter turned off
})
```

## Known limitations

- On the fully zoomed-out world view, there may be no turn-in markers to show,
  depending on which addons draw at that zoom level.
- In Forever's stitched map mode, Questie's markers may not be filtered.
- Quests under a collapsed zone in the quest log may be missing from the
  sortable list until that zone is expanded.

## License

MIT. See [LICENSE](LICENSE).
