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

    -- Hand-in route: every turn-in icon Questie has placed (one per NPC spawn),
    -- read from Questie's map pin registry. Works with the map closed.
    CollectTurnIns = function(_, add)
        local loader = rawget(_G, "QuestieLoader")
        if not loader then return end
        local ok, hbdPins = pcall(loader.ImportModule, loader, "HBDPins")
        local pins = ok and type(hbdPins) == "table" and hbdPins.worldmapPins
        if type(pins) ~= "table" then return end
        for icon in pairs(pins) do
            local data = type(icon) == "table" and rawget(icon, "data")
            if type(data) == "table" and data.Type == "complete" and data.Id then
                add(data.Id, rawget(icon, "UiMapID"), rawget(icon, "x"), rawget(icon, "y"), data.Name)
            end
        end
    end,
})
