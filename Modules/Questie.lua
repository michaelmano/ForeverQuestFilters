-- Questie draws its icons through HereBeDragons pins: each map pin holds a
-- Questie icon frame in pin.icon, whose .data.Type is "complete" for turn-ins.
local _, ns = ...

ns.MapFilter:RegisterModule({
    name = "Questie",
    addon = "Questie",
    priority = 50,
    Classify = function(pin, template)
        if not template:find("HereBeDragonsPins", 1, true) then return nil end
        local icon = rawget(pin, "icon")
        local data = type(icon) == "table" and rawget(icon, "data")
        if type(data) ~= "table" or data.Type == nil then return nil end -- another HBD user (e.g. TomTom)
        return data.Type == "complete"
    end,
})
