-- Forever Quest Pins only draws "!" markers for quests you haven't accepted,
-- so all of them are hidden. It can also draw outside the map canvas
-- (stitched/gamepad mode), so instead of hiding pins one by one, its refresh is
-- paused and its pins cleared while the filter is on.
local _, ns = ...

local function MP() return ForeverQuestPins and ForeverQuestPins.MapPins end

local function ClearPins()
    local mp = MP()
    if not mp then return end
    if mp.CancelPendingRefresh then pcall(mp.CancelPendingRefresh, mp) end
    if mp.Clear then pcall(mp.Clear, mp) end
end

local module
module = ns.MapFilter:RegisterModule({
    name = "ForeverQuestPins",
    addon = "ForeverQuestPins",
    priority = 50,

    Init = function()
        local mp = MP()
        if not mp or mp._fqfHooked or type(mp.Refresh) ~= "function" then return end
        local orig = mp.Refresh
        mp.Refresh = function(self, ...)
            if module.suppressing then ClearPins(); return end
            return orig(self, ...)
        end
        mp._fqfHooked = true
    end,

    OnEnable = function(self)
        self.suppressing = true
        ClearPins()
    end,

    OnDisable = function(self)
        self.suppressing = false
        local mp = MP()
        if mp and mp.Refresh then pcall(mp.Refresh, mp, "fqf-restore") end
    end,

    Classify = function(_, template)
        if template == "ForeverQuestPinsMapPinTemplate" then return false end
        return nil
    end,
})
