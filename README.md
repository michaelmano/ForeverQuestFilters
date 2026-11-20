# Forever Quest Filters

A WoW Forever addon that filters quests by completion: show only completed-quest
markers on the world map, and filter or sort the quest log so quests that are
ready to turn in come first.

Map addons like Questie, Forever Quest Pins and OneForAll each draw their own
markers, and none of them can show only turn-ins. Forever Quest Filters sits on
top of them: one checkbox hides everything except the quests you can hand in.

## Features

- **Choose which quest markers the map shows.** One setting, four choices:
  - **All markers**: no filtering.
  - **Ready to turn in**: only where completed quests are handed in (Questie's
    turn-in icons, OneForAll's `?` icons, the game's own completed quest pins).
  - **Tracked quests**: only the quests you're tracking: their objectives and,
    once complete, their turn-in.
  - **Tracked + ready to turn in**: your tracked quests' markers plus every
    turn-in.

  With any filter on, quest start `!` markers and other addons' map icons are
  hidden. Your player arrow, party members, death markers, zone highlights,
  labels, your map waypoint and TomTom waypoints stay visible. Tracking follows
  Questie's tracker when it's on, otherwise the game's.
- **Hand-in route.** Builds a short route from where you are to every NPC you
  can turn a completed quest in to, then guides you along it with waypoints.
- **Hold-to-peek keybind.** Hold a key to see only ready-to-turn-in markers for
  a moment and let go to go back. There's also a toggle keybind.
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
| OneForAll | `?` turn-in icons stay, `!` icons and walking routes are hidden. On the world view, where OneForAll draws nothing, `?` markers for your completed quests are added from OneForAll's turn-in data |
| TomTom | Waypoints (`/way`, corpse waypoint) always stay |
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

- **Quest markers**: pick one of **All markers**, **Ready to turn in (N)**,
  **Tracked quests** or **Tracked + ready to turn in**. N is the number of
  quests in your log ready to turn in. Your choice is remembered between
  sessions.
- **Sortable quest list...**: opens the quest list window.
- **Create hand-in route...**: opens the hand-in route (see below).

### Quest log

Open the quest log's settings dropdown. Under **Show Quest Objectives**:

- **Completed quests only**
- **Sort completed quests first**
- **Create hand-in route (N)...**: opens the hand-in route; N is how many
  quests are ready to turn in

Both settings are saved between sessions. While either one is on, the game's
quest list is hidden and the addon draws its own list in the same place.
Clicking a quest opens its details as usual. The quest log's search box doesn't
filter the addon's list.

### Hand-in route

**Create hand-in route...** in either dropdown (or `/fqf route`) lists every stop in order: the NPC,
the zone, the walking distance from the previous stop, and the quests handed in
there. Quests turned in to the same NPC are one stop, and for an NPC that stands
in more than one place, the closest spot is used.

- **Start** sets a waypoint to the first stop: TomTom's arrow if TomTom is
  loaded, otherwise the game's own map waypoint. Once everything at a stop is
  handed in, the waypoint moves on to the next stop by itself.
- With TomTom (`/way`) loaded, **Show all stops in TomTom** puts every remaining
  stop on the map as a numbered TomTom waypoint, with the arrow on the current
  one. The route's waypoints are tagged as Forever Quest Filters in TomTom.
- Click any stop to set the waypoint there instead.
- **Recalculate** rebuilds the route from where you are now. **Stop** clears the
  waypoint.

How the route is built: it finishes the continent you're on first, then the
others. On each continent it goes to the nearest next stop, then reorders stops
wherever that makes the trip shorter. Distances are straight lines, so flight
paths, boats and terrain aren't taken into account: it's a short route, not a
guaranteed shortest one.

Turn-in locations come from Questie, or OneForAll's data when Questie is off.
Completed quests with no known location are listed at the bottom.

### Keybinds

Under Options → Keybindings → Forever Quest Filters:

- **Toggle quest marker filter (off / last used)**
- **Hold to show ready-to-turn-in markers**
- **Toggle sortable quest list**

### Slash commands

| Command | Does |
|---|---|
| `/fqf` | Quest marker filter off, or back to the last one used |
| `/fqf mode all\|turnin\|tracked\|both` | Pick which quest markers show |
| `/fqf route` | Create the hand-in route |
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

    -- hand-in route: report turn-in spots, add(questID, uiMapID, x, y, npcName)
    -- CollectTurnIns = function(self, add) end,

    -- optional:
    -- Init      = function(self) end,  -- once, when the addon is loaded
    -- OnEnable  = function(self) end,  -- filter turned on
    -- OnDisable = function(self) end,  -- filter turned off
})
```

## Known limitations

- On the fully zoomed-out world view, turn-in markers come from Questie, or
  from OneForAll's data when Questie is off. With neither, there are none to show.
- In Forever's stitched map mode, Questie's markers may not be filtered.
- Quests under a collapsed zone in the quest log may be missing from the
  sortable list until that zone is expanded.

## License

MIT. See [LICENSE](LICENSE).
