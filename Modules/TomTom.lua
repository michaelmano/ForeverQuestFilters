-- TomTom waypoints (/way, the corpse waypoint, etc.) are never quest clutter:
-- always keep them. TomTom draws them through HereBeDragons map pins; the pin's
-- icon is TomTom's waypoint button, which carries .point (its waypoint, with .uid).
local _, ns = ...

local function IsTomTomIcon(icon)
    if type(icon) ~= "table" then return false end
    local point = rawget(icon, "point")
    return type(point) == "table" and rawget(point, "uid") ~= nil and rawget(point, "worldmap") == icon
end

ns.MapFilter:RegisterModule({
    name = "TomTom",
    addon = "TomTom",
    priority = 40, -- before Questie, which shares the HereBeDragons pin template
    Classify = function(pin)
        if IsTomTomIcon(rawget(pin, "icon")) then return true end
        return nil
    end,
    ClassifyFrame = function(frame)
        if IsTomTomIcon(frame) then return true end
        return nil
    end,
})
