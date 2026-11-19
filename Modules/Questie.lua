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
        -- data.Id is the quest; "complete" is its turn-in icon. Anything else
        -- (available "!", objectives) only passes in tracked-only mode.
        return ns.MapFilter:KeepQuest(data.Id, data.Type == "complete")
    end,
})
