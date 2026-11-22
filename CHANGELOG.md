# Changelog

All notable changes to Forever Quest Filters.

## [1.0.4] - 2026-11-22

### Added
- **Untrack all quests.** A new "Untrack all quests" button sits above "Create hand-in route" in the quest log settings dropdown and the world map filter dropdown. It shows how many quests are tracked and untracks them all, in Questie's tracker when it's on and in the game's watch list. Also available as `/fqf untrack`.
- This changelog.

## [1.0.3] - 2026-11-20

### Changed
- Release zips and GitHub releases are named `ForeverQuestFilters-<version>`, without the `-forever` flavour suffix.

## [1.0.2] - 2026-11-20

### Added
- **Skip quests on the hand-in route.** Each quest in the route window has a checkbox to skip it. The route is rebuilt without skipped quests, which are listed at the bottom with a checkbox to put them back. Skips are saved until the quest leaves your quest log.
- Release workflow (BigWigs Packager) that bumps the version, tags it, and uploads the addon to CurseForge and GitHub Releases.
- CurseForge project ID in the `.toc`.

## [1.0.1] - 2026-11-20

First release. (The `.toc` started at 1.0.0, but 1.0.0 was never tagged or released on its own.)

### Added
- **Sortable quest list.** A movable window listing your quests, sorted by completed first, by level or in quest log order. Opened with `/fqf list` or a keybind.
- **World map marker filter.** Hides map markers you don't need, with a hold-to-peek keybind and `/fqf` to switch it off and back to the last choice. Pick one of:
  - All markers
  - Ready to turn in
  - Tracked quests
  - Tracked + ready to turn in

  Choose from the world map filter dropdown or with `/fqf mode all|turnin|tracked|both`. Tracking follows Questie's tracker when it's enabled, otherwise the game's watch list. The setting is remembered across reloads.
- **Addon support modules** (`/fqf modules`, `/fqf module <name> on|off`):
  - Questie
  - Forever Quest Pins
  - The game's own quest pins
  - OneForAll: keeps turn-in icons and hides quest start icons and walking routes. While the filter is on and Questie isn't loaded, it also draws a turn-in marker for each completed quest on the world view.
  - Leatrix Maps: hides its POI icons and leaves its map overlays alone.
  - TomTom: keeps `/way` and corpse waypoints.
  - Base map pins (including death/corpse markers) always stay visible.
  - A template for adding modules for other addons.
- **Quest log options.** "Completed quests only" and "Sort completed quests first" in the quest log settings dropdown (`/fqf log`, `/fqf sort`). These draw a filtered, sorted list in place of the game's list without rearranging the game's own rows.
- **Hand-in route.** Builds a short route through the turn-in NPCs of every completed quest, starting from you: your current continent first, then the nearest next stop, then 2-opt reordering. Shown in a window, with guidance through TomTom or the game's map waypoint that moves to the next stop after each hand-in. Optionally adds every remaining stop as a numbered TomTom waypoint. Turn-in spots come from Questie and OneForAll. Opened with `/fqf route` or from the world map filter and quest log settings dropdowns.
- `/fqf debug` lists map pin templates on the current map, grouped by canvas frame, showing which module handles each one and whether kept markers are drawn.
- README and license.

[1.0.4]: https://github.com/michaelmano/ForeverQuestFilters/compare/1.0.3...1.0.4
[1.0.3]: https://github.com/michaelmano/ForeverQuestFilters/compare/1.0.2...1.0.3
[1.0.2]: https://github.com/michaelmano/ForeverQuestFilters/compare/1fbbb78...1.0.2
[1.0.1]: https://github.com/michaelmano/ForeverQuestFilters/tree/1fbbb78
