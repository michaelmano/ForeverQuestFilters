-- Forever's own quest markers, plus any other addon pin that carries a questID:
-- keep it if that quest is complete in your log, hide it otherwise.
-- Runs last among the quest modules so addon-specific modules win.
local _, ns = ...

ns.MapFilter:RegisterModule({
    name = "BlizzardQuests",
    priority = 90,
    Classify = function(pin)
        local questID = rawget(pin, "questID")
        if not questID then return nil end
        return ns.MapFilter:KeepQuest(questID, ns.IsQuestComplete(questID))
    end,
})
