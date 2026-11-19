-- OneForAll draws its own quest icons on the map (MapQuests.lua): a "!" where a
-- quest can be picked up and a "?" where a finished quest is turned in. They are
-- plain frames on the map canvas, kept in OneForAll.MapQuests._pool; each icon
-- has .spot = { avail = {...}, turnin = {...} }. Keep "?" (turn-ins), hide "!".
-- (OneForAll only draws these while Questie is NOT loaded.)
-- Its giver walking-route lines and any other OneForAll canvas frames are left
-- unclaimed, so the filter hides them.
local _, ns = ...

local function MQ()
    local ofa = rawget(_G, "OneForAll")
    return type(ofa) == "table" and ofa.MapQuests or nil
end

local inPool = setmetatable({}, { __mode = "k" })

local function IndexPool()
    local mq = MQ()
    local pool = mq and mq._pool
    if type(pool) ~= "table" then return end
    for _, pin in ipairs(pool) do inPool[pin] = true end
end

ns.MapFilter:RegisterModule({
    name = "OneForAll",
    addon = "OneForAll",
    priority = 50,

    Init = function()
        local mq = MQ()
        if mq and type(mq.Refresh) == "function" then
            -- re-filter right after OneForAll repaints, so its "!" never flashes up
            hooksecurefunc(mq, "Refresh", function()
                IndexPool()
                if ns.MapFilter.IsActive() then ns.MapFilter.Apply() end
            end)
        end
        IndexPool()
    end,

    ClassifyFrame = function(frame)
        if not inPool[frame] then
            IndexPool()
            if not inPool[frame] then return nil end
        end
        local spot = rawget(frame, "spot")
        if type(spot) ~= "table" then return false end
        return type(spot.turnin) == "table" and #spot.turnin > 0
    end,
})
