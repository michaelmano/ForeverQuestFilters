-- Leatrix Maps draws on the map canvas directly:
--   * its own POI icons (dungeons, portals, travel...): frames flagged .isLeaMapsPin -> hidden
--   * everything else (revealed fog, discovery-area overlays, click catcher,
--     hover labels) is part of the map's look -> always kept
local _, ns = ...

ns.MapFilter:RegisterModule({
    name = "LeatrixMaps",
    addon = "Leatrix_Maps",
    priority = 50,
    ClassifyFrame = function(frame)
        if rawget(frame, "isLeaMapsPin") then return false end
        return nil
    end,
})
