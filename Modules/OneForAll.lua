-- OneForAll draws its own quest icons on the map (MapQuests.lua): a "!" where a
-- quest can be picked up and a "?" where a finished quest is turned in. They are
-- plain frames on the map canvas, kept in OneForAll.MapQuests._pool; each icon
-- has .spot = { avail = {...}, turnin = {...} }. Keep "?" (turn-ins), hide "!".
-- Its giver walking-route lines and any other OneForAll canvas frames are left
-- unclaimed, so the filter hides them.
--
-- OneForAll only draws on zone and continent maps (and only while Questie is not
-- loaded). So on the world view, while the filter is on, this module draws its
-- own "?" for each completed quest, at the turn-in location OneForAll's data
-- gives (OneForAll.QuestPinLoc, read only - OneForAll itself is not changed).
local _, ns = ...

local function OFA()
    local ofa = rawget(_G, "OneForAll")
    return type(ofa) == "table" and ofa or nil
end
local function MQ()
    local ofa = OFA()
    return ofa and ofa.MapQuests or nil
end

local inPool = setmetatable({}, { __mode = "k" })

local function IndexPool()
    local mq = MQ()
    local pool = mq and mq._pool
    if type(pool) ~= "table" then return end
    for _, pin in ipairs(pool) do inPool[pin] = true end
end

---------------------------------------------------------------------------
-- Our own world-view turn-in markers
---------------------------------------------------------------------------
local WORLD_SIZE = 16
local ours = setmetatable({}, { __mode = "k" }) -- frames we drew (always kept)
local markers, nUsed = {}, 0
local rectCache = {} -- [zoneMapID] = { x0, y0, w, h } on the world map, or false

local function IsWorldView(mapID)
    if not mapID then return false end
    if mapID == 947 then return true end
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    local types = Enum and Enum.UIMapType
    return info and types and (info.mapType == types.World or info.mapType == types.Cosmic) or false
end

local function ZoneRectOn(zoneMapID, worldMapID)
    local key = zoneMapID .. ":" .. worldMapID
    local r = rectCache[key]
    if r ~= nil then return r or nil end
    r = false
    if C_Map and C_Map.GetMapRectOnMap then
        local ok, x0, x1, y0, y1 = pcall(C_Map.GetMapRectOnMap, zoneMapID, worldMapID)
        if ok and x0 and x1 and y0 and y1 and x1 > x0 and y1 > y0 then
            r = { x0, y0, x1 - x0, y1 - y0 }
        end
    end
    rectCache[key] = r
    return r or nil
end

local function HideMarkers()
    for i = 1, nUsed do markers[i]:Hide(); markers[i].quests = nil end
    nUsed = 0
end

local function MarkerOnEnter(self)
    if not self.quests then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(self.label or "Turn in", 1, 0.82, 0)
    for _, e in ipairs(self.quests) do GameTooltip:AddLine(e.title, 0.3, 1, 0.3) end
    GameTooltip:AddLine("Click: show quest details", 0.6, 0.6, 1)
    GameTooltip:Show()
end

local function MarkerOnClick(self)
    local e = self.quests and self.quests[1]
    if not e then return end
    if QuestMapFrame_ShowQuestDetails then pcall(QuestMapFrame_ShowQuestDetails, e.questID)
    elseif QuestMapFrame_OpenToQuestDetails then pcall(QuestMapFrame_OpenToQuestDetails, e.questID) end
end

local function AcquireMarker(canvas)
    nUsed = nUsed + 1
    local m = markers[nUsed]
    if not m then
        m = CreateFrame("Button", nil, canvas)
        m.tex = m:CreateTexture(nil, "OVERLAY")
        m.tex:SetAllPoints()
        if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("QuestTurnin") then
            m.tex:SetAtlas("QuestTurnin")
        else
            m.tex:SetTexture("Interface\\GossipFrame\\ActiveQuestIcon")
        end
        m:SetScript("OnEnter", MarkerOnEnter)
        m:SetScript("OnLeave", GameTooltip_Hide)
        m:SetScript("OnClick", MarkerOnClick)
        markers[nUsed] = m
        ours[m] = true
    end
    return m
end

local module

local function DrawWorldMarkers()
    HideMarkers()
    if not (module and module.drawing) then return end
    local ofa = OFA()
    if not (ofa and type(ofa.QuestPinLoc) == "function") then return end
    local mq = MQ()
    if mq and type(mq.QuestieLoaded) == "function" and mq.QuestieLoaded() then return end -- Questie draws these
    if not (WorldMapFrame and WorldMapFrame:IsShown()) then return end
    local mapID = WorldMapFrame:GetMapID()
    if not IsWorldView(mapID) then return end
    local canvas = WorldMapFrame:GetCanvas()
    local w, h = canvas:GetWidth(), canvas:GetHeight()
    if not (w and h and w > 0 and h > 0) then return end
    local scale = 1
    local sc = WorldMapFrame.ScrollContainer
    if sc and sc.GetCanvasScale then scale = 1 / math.max(0.1, sc:GetCanvasScale() or 1) end

    -- group completed quests by turn-in spot
    local spots, order = {}, {}
    for _, e in ipairs(ns.questList) do
        if e.complete then
            local ok, loc = pcall(ofa.QuestPinLoc, e.questID, true)
            if ok and type(loc) == "table" and loc.mapID and loc.x and loc.y then
                local rect = ZoneRectOn(loc.mapID, mapID)
                if rect then
                    local key = loc.mapID .. ":" .. loc.x .. ":" .. loc.y
                    local s = spots[key]
                    if not s then
                        s = { x = rect[1] + (loc.x / 100) * rect[3], y = rect[2] + (loc.y / 100) * rect[4],
                              label = loc.label, quests = {} }
                        spots[key] = s; order[#order + 1] = s
                    end
                    s.quests[#s.quests + 1] = e
                end
            end
        end
    end

    local level = canvas:GetFrameLevel() + 2000
    for _, s in ipairs(order) do
        local m = AcquireMarker(canvas)
        m.quests, m.label = s.quests, s.label
        m:SetSize(WORLD_SIZE, WORLD_SIZE)
        m:SetScale(scale)
        m:SetFrameLevel(level)
        m:ClearAllPoints()
        m:SetPoint("CENTER", canvas, "TOPLEFT", s.x * w / scale, -s.y * h / scale)
        m:Show()
    end
end

local pending = false
local function ScheduleDraw()
    if pending then return end
    pending = true
    C_Timer.After(0, function() pending = false; DrawWorldMarkers() end)
end

---------------------------------------------------------------------------

module = ns.MapFilter:RegisterModule({
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
        if WorldMapFrame then
            if WorldMapFrame.OnMapChanged then hooksecurefunc(WorldMapFrame, "OnMapChanged", ScheduleDraw) end
            WorldMapFrame:HookScript("OnShow", ScheduleDraw)
            WorldMapFrame:HookScript("OnHide", HideMarkers)
        end
        ns.OnScan(ScheduleDraw)
    end,

    OnEnable = function(self)
        self.drawing = true
        ScheduleDraw()
    end,

    OnDisable = function(self)
        self.drawing = false
        HideMarkers()
    end,

    ClassifyFrame = function(frame)
        if ours[frame] then return true end
        if not inPool[frame] then
            IndexPool()
            if not inPool[frame] then return nil end
        end
        local spot = rawget(frame, "spot")
        if type(spot) ~= "table" then return false end
        return type(spot.turnin) == "table" and #spot.turnin > 0
    end,
})
