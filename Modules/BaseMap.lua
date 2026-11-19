-- Base map pins that are not "markers": always kept, even while filtering.
local _, ns = ...

local KEEP_PATTERNS = {
    "Unit", "GroupMember", "Highlight", "Exploration", "FogOfWar",
    "Label", "MapLink", "Ping", "WaypointLocation", "Navigation",
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
