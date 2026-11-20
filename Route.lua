-- Hand-in route: the shortest tour that turns in every completed quest.
--
-- Turn-in locations come from the map modules (a module can define
-- CollectTurnIns(add); see Modules/Questie.lua and Modules/OneForAll.lua).
-- A quest can have several turn-in spots (an NPC with more than one spawn);
-- the route picks whichever is closest when it gets there.
--
-- Route: start at the player, finish the current continent first, then the
-- others (biggest first). Within a continent: nearest next stop, then 2-opt
-- swaps to shorten it. Distances are straight lines in yards; flight paths,
-- boats and terrain aren't known, so it's a short route, not a proven shortest.
local _, ns = ...
local Route = {}
ns.Route = Route

local MERGE_YARDS = 15 -- turn-ins this close together are one stop

---------------------------------------------------------------------------
-- Coordinates: zone (0-1) -> world yards, one converter for everything so
-- all distances are comparable.
---------------------------------------------------------------------------
local converter
local function Converter()
    if converter ~= nil then return converter end
    converter = false
    local hbd = LibStub and LibStub("HereBeDragons-2.0", true)
    if not hbd and rawget(_G, "QuestieLoader") then
        local ok, m = pcall(QuestieLoader.ImportModule, QuestieLoader, "HBD")
        if ok then hbd = m end
    end
    if type(hbd) == "table" and hbd.GetWorldCoordinatesFromZone then
        converter = function(mapID, x, y)
            local ok, wx, wy, inst = pcall(hbd.GetWorldCoordinatesFromZone, hbd, x, y, mapID)
            if ok and wx then return wx, wy, inst end
        end
    elseif C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D then
        converter = function(mapID, x, y)
            local ok, inst, pos = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(x, y))
            if ok and pos then return pos.x, pos.y, inst end
        end
    end
    return converter
end

local function ToWorld(mapID, x, y)
    local conv = Converter()
    if conv and mapID and x and y then return conv(mapID, x, y) end
end

local function PlayerWorld()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return end
    local mapID = C_Map.GetBestMapForUnit("player")
    local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return end
    local x, y = pos:GetXY()
    local wx, wy, inst = ToWorld(mapID, x, y)
    if wx then return { wx = wx, wy = wy, inst = inst } end
end

local function Dist(a, b)
    local dx, dy = a.wx - b.wx, a.wy - b.wy
    return math.sqrt(dx * dx + dy * dy)
end

local function MapName(mapID)
    local info = mapID and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    return info and info.name or "?"
end

local function ContinentName(mapID)
    local types = Enum and Enum.UIMapType
    local id, guard = mapID, 0
    while id and guard < 10 do
        local info = C_Map.GetMapInfo(id)
        if not info then break end
        if types and info.mapType == types.Continent then return info.name end
        id, guard = info.parentMapID, guard + 1
    end
    return MapName(mapID)
end

---------------------------------------------------------------------------
-- Gather turn-in candidates from the modules
---------------------------------------------------------------------------
local function Collect()
    local byQuest = {} -- [questID] = { candidates }
    local function add(questID, mapID, x, y, npcName)
        if not (questID and ns.IsQuestComplete(questID)) then return end
        if x and x > 1 then x, y = x / 100, y / 100 end
        local wx, wy, inst = ToWorld(mapID, x, y)
        if not wx then return end
        local list = byQuest[questID]
        if not list then list = {}; byQuest[questID] = list end
        local c = { questID = questID, mapID = mapID, x = x, y = y, wx = wx, wy = wy, inst = inst, name = npcName }
        for _, o in ipairs(list) do
            if o.inst == inst and Dist(o, c) < 1 then return end -- duplicate
        end
        list[#list + 1] = c
    end
    for _, m in ipairs(ns.MapFilter:GetModules()) do
        if m.initialized and m.CollectTurnIns then
            local ok, err = pcall(m.CollectTurnIns, m, add)
            if not ok then ns.Print(("route: %s failed: %s"):format(m.name, tostring(err))) end
        end
    end
    return byQuest
end

---------------------------------------------------------------------------
-- Build the route
---------------------------------------------------------------------------
local function PathLength(stops, start)
    local total, prev = 0, start
    for _, s in ipairs(stops) do
        if prev then total = total + Dist(prev, s) end
        prev = s
    end
    return total
end

-- 2-opt on an open path (the start, if given, stays fixed before stop 1)
local function TwoOpt(stops, start)
    local n = #stops
    if n < 3 then return end
    local improved, passes = true, 0
    while improved and passes < 50 do
        improved, passes = false, passes + 1
        for i = 1, n - 1 do
            for k = i + 1, n do
                local a = (i == 1) and start or stops[i - 1]
                local b, c, d = stops[i], stops[k], stops[k + 1]
                local before = (a and Dist(a, b) or 0) + (d and Dist(c, d) or 0)
                local after = (a and Dist(a, c) or 0) + (d and Dist(b, d) or 0)
                if after + 0.01 < before then
                    local lo, hi = i, k
                    while lo < hi do stops[lo], stops[hi] = stops[hi], stops[lo]; lo, hi = lo + 1, hi - 1 end
                    improved = true
                end
            end
        end
    end
end

-- Greedy nearest-stop walk inside one continent. Each step goes to the
-- closest candidate of any quest still to do; every other open quest with a
-- turn-in within MERGE_YARDS of that spot is handed in there too.
local function Greedy(quests, inst, start)
    local open = {}
    for questID, list in pairs(quests) do
        for _, c in ipairs(list) do
            if c.inst == inst then open[questID] = list; break end
        end
    end
    local stops, cur = {}, start
    while next(open) do
        local best, bestD
        for _, list in pairs(open) do
            for _, c in ipairs(list) do
                if c.inst == inst then
                    local d = cur and Dist(cur, c) or 0
                    if not bestD or d < bestD then best, bestD = c, d end
                end
            end
        end
        if not best then break end
        local stop = { wx = best.wx, wy = best.wy, inst = inst, mapID = best.mapID, x = best.x, y = best.y,
                       name = best.name, quests = {} }
        for questID, list in pairs(open) do
            for _, c in ipairs(list) do
                if c.inst == inst and Dist(c, best) <= MERGE_YARDS then
                    stop.quests[#stop.quests + 1] = questID
                    open[questID] = nil
                    if not stop.name then stop.name = c.name end
                    break
                end
            end
        end
        stops[#stops + 1] = stop
        cur = stop
    end
    return stops
end

local function Build()
    local quests = Collect()
    local player = PlayerWorld()

    -- continents that have turn-ins, player's first, then by quest count
    local count = {}
    for _, list in pairs(quests) do
        local seen = {}
        for _, c in ipairs(list) do
            if not seen[c.inst] then seen[c.inst] = true; count[c.inst] = (count[c.inst] or 0) + 1 end
        end
    end
    local insts = {}
    for inst in pairs(count) do insts[#insts + 1] = inst end
    table.sort(insts, function(a, b)
        if player and (a == player.inst) ~= (b == player.inst) then return a == player.inst end
        return count[a] > count[b]
    end)

    local route, missing = {}, {}
    local remaining = {}
    for q, list in pairs(quests) do remaining[q] = list end
    for _, inst in ipairs(insts) do
        local start = (player and player.inst == inst) and player or nil
        local legs = Greedy(remaining, inst, start)
        TwoOpt(legs, start)
        for i, s in ipairs(legs) do
            for _, q in ipairs(s.quests) do remaining[q] = nil end
            local prev = (i == 1) and start or legs[i - 1]
            s.leg = prev and Dist(prev, s) or nil
            s.firstOnContinent = (i == 1)
            s.continent = ContinentName(s.mapID)
            route[#route + 1] = s
        end
    end
    -- completed quests with no known turn-in spot
    for _, e in ipairs(ns.questList) do
        if e.complete and not quests[e.questID] then missing[#missing + 1] = e end
    end
    return route, missing
end

---------------------------------------------------------------------------
-- Waypoints (TomTom if loaded, else the game's map waypoint)
---------------------------------------------------------------------------
local tomtomUIDs = {}
Route.stops, Route.missing, Route.current = {}, {}, nil

local function ClearWaypoints()
    local tt = rawget(_G, "TomTom")
    if tt and tt.RemoveWaypoint then
        for _, uid in ipairs(tomtomUIDs) do pcall(tt.RemoveWaypoint, tt, uid) end
    end
    wipe(tomtomUIDs)
end

local function StopTitle(i, s)
    return ("Hand-in %d: %s"):format(i, s.name or MapName(s.mapID))
end

local StopDone -- defined below

local function AddTomTom(tt, i, s, crazy)
    local ok, uid = pcall(tt.AddWaypoint, tt, s.mapID, s.x, s.y, {
        title = StopTitle(i, s), from = "ForeverQuestFilters",
        persistent = false, crazy = crazy, minimap = true, world = true,
    })
    if ok and uid then tomtomUIDs[#tomtomUIDs + 1] = uid end
end

local function PointTo(i)
    local s = Route.stops[i]
    Route.current = s and i or nil
    ClearWaypoints()
    if not s then return end
    local tt = rawget(_G, "TomTom")
    if tt and tt.AddWaypoint then
        -- with "show all stops", every unfinished stop gets a numbered
        -- waypoint; the arrow points at the current one (added last)
        if ns.db.routeAllWaypoints then
            for k, other in ipairs(Route.stops) do
                if k ~= i and not StopDone(other) then AddTomTom(tt, k, other, false) end
            end
        end
        AddTomTom(tt, i, s, true)
    elseif C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
        pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(s.mapID, s.x, s.y))
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
            pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
        end
    end
    ns.Print(("%s (%s)"):format(StopTitle(i, s), MapName(s.mapID)))
end

function StopDone(s)
    for _, q in ipairs(s.quests) do
        if ns.IsQuestComplete(q) then return false end -- still in the log, ready
    end
    return true
end

-- after a turn-in: when the current stop is finished, point to the next one
local function Advance()
    local i = Route.current
    if not i then return end
    while Route.stops[i] and StopDone(Route.stops[i]) do i = i + 1 end
    if i ~= Route.current then
        if Route.stops[i] then PointTo(i) else
            Route.current = nil
            ClearWaypoints()
            ns.Print("hand-in route finished")
        end
    end
    Route:Render()
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local frame, content, summary
local lines, nLines = {}, 0

local function Line(h)
    nLines = nLines + 1
    local l = lines[nLines]
    if not l then
        l = CreateFrame("Button", nil, content)
        l.text = l:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        l.text:SetPoint("LEFT", 2, 0)
        l.text:SetPoint("RIGHT", -2, 0)
        l.text:SetJustifyH("LEFT")
        l.text:SetWordWrap(false)
        l.hl = l:CreateTexture(nil, "HIGHLIGHT")
        l.hl:SetAllPoints()
        l.hl:SetColorTexture(1, 1, 1, 0.08)
        l:SetScript("OnClick", function(self) if self.stopIndex then PointTo(self.stopIndex); Route:Render() end end)
        lines[nLines] = l
    end
    l.stopIndex = nil
    l:EnableMouse(false)
    l:SetHeight(h)
    l:Show()
    return l
end

function Route:Render()
    if not frame or not frame:IsShown() then return end
    for i = 1, nLines do lines[i]:Hide() end
    nLines = 0
    local y, total = -2, 0
    local function place(l, indent)
        l:ClearAllPoints()
        l:SetPoint("TOPLEFT", content, "TOPLEFT", indent, y)
        l:SetPoint("RIGHT", content, "RIGHT")
        y = y - l:GetHeight()
    end
    for i, s in ipairs(self.stops) do
        if s.firstOnContinent then
            local h = Line(20)
            h.text:SetFontObject("GameFontNormal")
            h.text:SetTextColor(1, 0.82, 0)
            h.text:SetText(i == 1 and s.continent or ("Travel to " .. s.continent))
            place(h, 2)
        end
        local done = StopDone(s)
        local l = Line(16)
        l.text:SetFontObject("GameFontNormalSmall")
        local mark = (self.current == i) and "|cff20ff20>|r " or ""
        local dist = s.leg and ("  |cff999999%d yd|r"):format(math.floor(s.leg + 0.5)) or ""
        l.text:SetText(("%s%d. %s - %s%s"):format(mark, i, s.name or "?", MapName(s.mapID), dist))
        if done then l.text:SetTextColor(0.5, 0.5, 0.5) else l.text:SetTextColor(1, 1, 1) end
        l.stopIndex = i
        l:EnableMouse(true)
        place(l, 6)
        for _, q in ipairs(s.quests) do
            local e = ns.questInfo[q]
            local ql = Line(14)
            ql.text:SetFontObject("GameFontHighlightSmall")
            ql.text:SetText("- " .. (e and e.title or ("Quest " .. q)))
            if done or not ns.IsQuestComplete(q) then ql.text:SetTextColor(0.5, 0.5, 0.5) else ql.text:SetTextColor(0.3, 1, 0.3) end
            place(ql, 18)
        end
        total = total + (s.leg or 0)
    end
    if #self.missing > 0 then
        local h = Line(20)
        h.text:SetFontObject("GameFontNormal")
        h.text:SetTextColor(1, 0.5, 0.3)
        h.text:SetText("No turn-in location known")
        place(h, 2)
        for _, e in ipairs(self.missing) do
            local ql = Line(14)
            ql.text:SetFontObject("GameFontHighlightSmall")
            ql.text:SetTextColor(0.8, 0.8, 0.8)
            ql.text:SetText("- " .. e.title)
            place(ql, 18)
        end
    end
    if #self.stops == 0 and #self.missing == 0 then
        local l = Line(20)
        l.text:SetFontObject("GameFontDisable")
        l.text:SetText("No completed quests to hand in")
        place(l, 6)
    end
    content:SetHeight(math.max(1, -y + 4))
    local quests = 0
    for _, s in ipairs(self.stops) do quests = quests + #s.quests end
    summary:SetText(("%d quests, %d stops, about %d yd walking"):format(quests, #self.stops, math.floor(total + 0.5)))
end

local function BuildFrame()
    frame = CreateFrame("Frame", "ForeverQuestFiltersRoute", UIParent, "BackdropTemplate")
    frame:SetSize(340, 440)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        ns.db.routePoint = { p, rp, x, y }
    end)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    local pt = ns.db.routePoint
    if pt then frame:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4]) else frame:SetPoint("CENTER", 180, 0) end
    tinsert(UISpecialFrames, "ForeverQuestFiltersRoute")

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText("Hand-in Route")
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)
    summary = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    summary:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)

    local start = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    start:SetSize(100, 22)
    start:SetPoint("TOPLEFT", 10, -46)
    start:SetText("Start")
    start:SetScript("OnClick", function()
        for i, s in ipairs(Route.stops) do
            if not StopDone(s) then PointTo(i); break end
        end
        Route:Render()
    end)
    local recalc = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    recalc:SetSize(100, 22)
    recalc:SetPoint("LEFT", start, "RIGHT", 6, 0)
    recalc:SetText("Recalculate")
    recalc:SetScript("OnClick", function() Route:Create() end)
    local stop = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    stop:SetSize(100, 22)
    stop:SetPoint("LEFT", recalc, "RIGHT", 6, 0)
    stop:SetText("Stop")
    stop:SetScript("OnClick", function() Route.current = nil; ClearWaypoints(); Route:Render() end)

    -- TomTom (the /way addon): optionally put every stop on the map at once
    local all = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    all:SetSize(22, 22)
    all:SetPoint("TOPLEFT", start, "BOTTOMLEFT", -2, -2)
    local allLabel = all:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    allLabel:SetPoint("LEFT", all, "RIGHT", 0, 1)
    allLabel:SetText("Show all stops in TomTom")
    all:SetScript("OnShow", function(self) self:SetChecked(ns.db.routeAllWaypoints and true or false) end)
    all:SetScript("OnClick", function(self)
        ns.db.routeAllWaypoints = self:GetChecked() and true or false
        if Route.current then PointTo(Route.current) end
    end)
    all:SetShown(rawget(_G, "TomTom") ~= nil)

    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", 12, 10)
    hint:SetPoint("BOTTOMRIGHT", -12, 10)
    hint:SetJustifyH("LEFT")
    hint:SetText("Click a stop to set a waypoint. Straight-line distances.")

    local scroll = CreateFrame("ScrollFrame", "ForeverQuestFiltersRouteScroll", frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, rawget(_G, "TomTom") and -98 or -74)
    scroll:SetPoint("BOTTOMRIGHT", -30, 26)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(290, 1)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(self, w) content:SetWidth(w) end)
    frame:SetScript("OnShow", function() Route:Render() end)
    frame:Hide()
end

-- Build (or rebuild) the route from where you are now and show it.
function Route:Create()
    if not Converter() then
        ns.Print("can't create a route: no map coordinate support found")
        return
    end
    ns.ScanLog()
    local wasRunning = self.current ~= nil
    self.stops, self.missing = Build()
    self.current = nil
    ClearWaypoints()
    if not frame then BuildFrame() end
    frame:Show()
    self:Render()
    if wasRunning and self.stops[1] then PointTo(1); self:Render() end
end

function Route:Toggle()
    if frame and frame:IsShown() then frame:Hide() else self:Create() end
end

function Route:Init()
    ns.OnScan(Advance)
end
