-- Completed-only / completed-first for the quest log beside the world map.
--
-- The game's own list is never rearranged or re-laid out (doing that from an
-- addon made the map jitter and taint). Instead, while either option is on, the
-- game's list is made invisible (alpha 0) and our own list is drawn in exactly
-- the same place, on the same parchment, from the same quest log data.
-- Turning both options off just makes the game's list visible again.
local _, ns = ...
local QuestLogFilter = {}
ns.QuestLogFilter = QuestLogFilter

local overlay, scroll, content
local pool, used = {}, 0
local hookedFrame = false

local HEADER_H, QUEST_H, OBJ_H = 22, 17, 14

function QuestLogFilter:IsOn() return ns.db and ns.db.questLogCompletedOnly end
function QuestLogFilter:IsSorted() return ns.db and ns.db.questLogSortCompleted end
local function Wanted() return QuestLogFilter:IsOn() or QuestLogFilter:IsSorted() end

local function SetGameListAlpha(a)
    if not QuestScrollFrame then return end
    if QuestScrollFrame.Contents then QuestScrollFrame.Contents:SetAlpha(a) end
    local bar = QuestScrollFrame.ScrollBar or rawget(_G, "QuestScrollFrameScrollBar")
    if bar then bar:SetAlpha(a) end
end

local function OpenQuest(questID)
    if QuestMapFrame_ShowQuestDetails then
        pcall(QuestMapFrame_ShowQuestDetails, questID)
    elseif QuestMapFrame_OpenToQuestDetails then
        pcall(QuestMapFrame_OpenToQuestDetails, questID)
    end
end

local function LevelColor(level)
    if GetQuestDifficultyColor and level and level > 0 then
        local ok, c = pcall(GetQuestDifficultyColor, level)
        if ok and c then return c.r, c.g, c.b end
    end
    return 1, 0.82, 0
end

local function Row()
    used = used + 1
    local r = pool[used]
    if not r then
        r = CreateFrame("Button", nil, content)
        r.text = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        r.text:SetPoint("LEFT", 0, 0)
        r.text:SetPoint("RIGHT", -34, 0)
        r.text:SetJustifyH("LEFT")
        r.text:SetWordWrap(false)
        r.tag = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        r.tag:SetPoint("RIGHT", -2, 0)
        r.hl = r:CreateTexture(nil, "HIGHLIGHT")
        r.hl:SetAllPoints()
        r.hl:SetColorTexture(1, 1, 1, 0.08)
        r:SetScript("OnClick", function(self) if self.questID then OpenQuest(self.questID) end end)
        r:SetScript("OnEnter", function(self)
            if not self.questID then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.title or "")
            GameTooltip:AddLine("Click: show quest details", 0.6, 0.6, 1)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", GameTooltip_Hide)
        pool[used] = r
    end
    r.questID, r.title = nil, nil
    r.tag:SetText("")
    r:EnableMouse(false)
    r:Show()
    return r
end

local function Objectives(questID)
    if not (C_QuestLog and C_QuestLog.GetQuestObjectives) then return {} end
    local ok, list = pcall(C_QuestLog.GetQuestObjectives, questID)
    return ok and type(list) == "table" and list or {}
end

function QuestLogFilter:Render()
    if not overlay or not overlay:IsShown() then return end
    for i = 1, used do pool[i]:Hide() end
    used = 0

    -- sections in quest log order (zone headers), quests inside them
    local sections, byZone = {}, {}
    for _, e in ipairs(ns.questList) do
        if not self:IsOn() or e.complete then
            local s = byZone[e.zone]
            if not s then s = { zone = e.zone, quests = {} }; byZone[e.zone] = s; sections[#sections + 1] = s end
            s.quests[#s.quests + 1] = e
        end
    end
    if self:IsSorted() then
        for _, s in ipairs(sections) do
            table.sort(s.quests, function(a, b)
                if a.complete ~= b.complete then return a.complete end
                return a.index < b.index
            end)
        end
    end

    local width = scroll:GetWidth()
    content:SetWidth(width)
    local y = -4
    local function place(r, h, indent)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", content, "TOPLEFT", indent, y)
        r:SetPoint("RIGHT", content, "RIGHT", 0, 0)
        r:SetHeight(h)
        y = y - h
    end

    if #sections == 0 then
        local r = Row()
        r.text:SetFontObject("GameFontDisable")
        r.text:SetText(self:IsOn() and "No completed quests" or "No quests")
        place(r, HEADER_H, 8)
    end
    for _, s in ipairs(sections) do
        if s.zone ~= "" then
            local h = Row()
            h.text:SetFontObject(rawget(_G, "GameFontNormalMed2") or GameFontNormal)
            h.text:SetTextColor(1, 0.82, 0)
            h.text:SetText(s.zone)
            place(h, HEADER_H, 4)
        end
        for _, e in ipairs(s.quests) do
            local r = Row()
            r.text:SetFontObject("GameFontNormal")
            r.questID, r.title = e.questID, e.title
            r:EnableMouse(true)
            r.text:SetText(e.title)
            if e.complete then
                r.text:SetTextColor(0.3, 1, 0.3)
                r.tag:SetText("|cff20ff20Done|r")
            elseif e.failed then
                r.text:SetTextColor(1, 0.3, 0.3)
                r.tag:SetText("|cffff3333Failed|r")
            else
                r.text:SetTextColor(LevelColor(e.level))
            end
            place(r, QUEST_H, 14)
            if not e.complete then
                for _, o in ipairs(Objectives(e.questID)) do
                    if o.text and o.text ~= "" then
                        local ob = Row()
                        ob.text:SetFontObject("GameFontHighlightSmall")
                        if o.finished then ob.text:SetTextColor(0.5, 0.5, 0.5) else ob.text:SetTextColor(0.85, 0.85, 0.85) end
                        ob.text:SetText("- " .. o.text)
                        place(ob, OBJ_H, 24)
                    end
                end
            else
                local ob = Row()
                ob.text:SetFontObject("GameFontHighlightSmall")
                ob.text:SetTextColor(0.85, 0.85, 0.85)
                ob.text:SetText("- Ready for turn-in")
                place(ob, OBJ_H, 24)
            end
        end
        y = y - 4
    end
    content:SetHeight(math.max(1, -y + 4))
end

local function Build()
    if overlay or not QuestScrollFrame then return overlay ~= nil end
    overlay = CreateFrame("Frame", "ForeverQuestFiltersLogOverlay", QuestScrollFrame)
    local top = QuestScrollFrame.SearchBox
    if top and top.IsShown and top:IsShown() then
        overlay:SetPoint("TOPLEFT", top, "BOTTOMLEFT", -6, -4)
    else
        overlay:SetPoint("TOPLEFT", QuestScrollFrame, "TOPLEFT", 0, 0)
    end
    overlay:SetPoint("BOTTOMRIGHT", QuestScrollFrame, "BOTTOMRIGHT", 0, 0)
    overlay:SetFrameLevel(QuestScrollFrame:GetFrameLevel() + 20)
    overlay:EnableMouse(true) -- the invisible game rows underneath can't be clicked

    scroll = CreateFrame("ScrollFrame", "ForeverQuestFiltersLogScroll", overlay, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 2, 0)
    scroll:SetPoint("BOTTOMRIGHT", -24, 2)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function() QuestLogFilter:Render() end)
    overlay:SetScript("OnShow", function() QuestLogFilter:Render() end)
    overlay:Hide()
    return true
end

function QuestLogFilter:Update()
    if not Build() then return end
    if Wanted() then
        SetGameListAlpha(0)
        overlay:Show()
        self:Render()
    else
        overlay:Hide()
        SetGameListAlpha(1)
    end
end

function QuestLogFilter:Toggle()
    ns.db.questLogCompletedOnly = not ns.db.questLogCompletedOnly
    self:Update()
end

function QuestLogFilter:ToggleSort()
    ns.db.questLogSortCompleted = not ns.db.questLogSortCompleted
    self:Update()
end

function QuestLogFilter:Init()
    if not QuestScrollFrame then return end
    if not hookedFrame then
        hookedFrame = true
        QuestScrollFrame:HookScript("OnShow", function() QuestLogFilter:Update() end)
        ns.OnScan(function() if overlay and overlay:IsShown() then QuestLogFilter:Render() end end)
    end
    self:Update()
end
