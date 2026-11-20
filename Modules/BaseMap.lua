-- Base map pins that are not "markers": always kept, even while filtering.
-- Includes your death / corpse markers.
local _, ns = ...

local KEEP_PATTERNS = {
    "Unit", "GroupMember", "Highlight", "Exploration", "FogOfWar",
    "Label", "MapLink", "Ping", "WaypointLocation", "Navigation",
    "Corpse", "Death",
}

ns.MapFilter:RegisterModule({
    name = "BaseMap",
    priority = 0,
    Classify = function(_, template)
        for _, p in ipairs(KEEP_PATTERNS) do
            if template:find(p, 1, true) then return true end
        end
        return nil
    end,
})
