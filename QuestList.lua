local _, ns = ...
local QuestList = {}
ns.QuestList = QuestList

local ROW_HEIGHT = 18
local frame, content, sortButton, onlyCheck, header
local rows = {}

local SORT_LABELS = {
    completed = "Sort: Completed first",
    level = "Sort: Level",
    log = "Sort: Quest log order",
}
local SORT_ORDER = { "completed", "level", "log" }

local function Sorted()
    local list = {}
    for _, e in ipairs(ns.questList) do
        if not ns.db.completedOnly or e.complete then list[#list + 1] = e end
    end
    local mode = ns.db.sortMode
    if mode == "completed" then
        table.sort(list, function(a, b)
            if a.complete ~= b.complete then return a.complete end
            if a.level ~= b.level then return a.level < b.level end
            return a.index < b.index
        end)
    elseif mode == "level" then
        table.sort(list, function(a, b)
            if a.level ~= b.level then return a.level < b.level end
            return a.index < b.index
        end)
    end
    return list
end

local function LevelColor(level)
    if GetQuestDifficultyColor then
        local ok, c = pcall(GetQuestDifficultyColor, level)
        if ok and c then return c.r, c.g, c.b end
    end
    return 1, 0.82, 0
end

local function ShowTooltip(row)
    local e = row.entry
    if not e then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(e.title)
    if e.zone ~= "" then GameTooltip:AddLine(e.zone, 0.7, 0.7, 0.7) end
    if e.complete then GameTooltip:AddLine("Ready to turn in", 0.2, 1, 0.2) end
    if e.failed then GameTooltip:AddLine("Failed", 1, 0.2, 0.2) end
    local objectives = C_QuestLog and C_QuestLog.GetQuestObjectives
        and select(2, pcall(C_QuestLog.GetQuestObjectives, e.questID))
    if type(objectives) == "table" then
        for _, o in ipairs(objectives) do
            if o.text and o.text ~= "" then
                if o.finished then GameTooltip:AddLine(o.text, 0.5, 0.5, 0.5)
                else GameTooltip:AddLine(o.text, 1, 1, 1) end
            end
        end
    end
    GameTooltip:AddLine("Click: open on the map", 0.6, 0.6, 1)
    GameTooltip:Show()
end

local function OpenQuest(e)
    if QuestMapFrame_OpenToQuestDetails then
        pcall(QuestMapFrame_OpenToQuestDetails, e.questID)
    elseif ToggleQuestLog then
        ToggleQuestLog()
    end
end

local function GetRow(i)
    local row = rows[i]
    if row then return row end
    row = CreateFrame("Button", nil, content)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
    row:SetPoint("RIGHT", content, "RIGHT")
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.level = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.level:SetPoint("LEFT", 4, 0)
    row.level:SetWidth(26)
    row.level:SetJustifyH("LEFT")
    row.status = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.status:SetPoint("RIGHT", -4, 0)
    row.title = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.title:SetPoint("LEFT", row.level, "RIGHT", 2, 0)
    row.title:SetPoint("RIGHT", row.status, "LEFT", -4, 0)
    row.title:SetJustifyH("LEFT")
    row.title:SetWordWrap(false)
    row:SetScript("OnEnter", ShowTooltip)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row:SetScript("OnClick", function(self) if self.entry then OpenQuest(self.entry) end end)
    rows[i] = row
    return row
end

function QuestList:Refresh()
    if not frame or not frame:IsShown() then return end
    sortButton:SetText(SORT_LABELS[ns.db.sortMode] or SORT_LABELS.completed)
    onlyCheck:SetChecked(ns.db.completedOnly)
    local list = Sorted()
    for i, e in ipairs(list) do
        local row = GetRow(i)
        row.entry = e
        row.level:SetText(e.level > 0 and e.level or "")
        row.level:SetTextColor(LevelColor(e.level))
        row.title:SetText(e.title)
        if e.complete then
            row.title:SetTextColor(0.3, 1, 0.3)
            row.status:SetText("|cff20ff20Done|r")
        elseif e.failed then
            row.title:SetTextColor(1, 0.3, 0.3)
            row.status:SetText("|cffff3333Failed|r")
        else
            row.title:SetTextColor(1, 1, 1)
            row.status:SetText("")
        end
        row:Show()
    end
    for i = #list + 1, #rows do rows[i]:Hide(); rows[i].entry = nil end
    content:SetHeight(math.max(1, #list * ROW_HEIGHT))
    header:SetText(("%d / %d quests completed"):format(ns.CompletedCount(), #ns.questList))
end

local function Build()
    frame = CreateFrame("Frame", "ForeverQuestFiltersList", UIParent, "BackdropTemplate")
    frame:SetSize(320, 420)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        ns.db.listPoint = { p, rp, x, y }
    end)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    local pt = ns.db.listPoint
    if pt then frame:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4])
    else frame:SetPoint("CENTER") end
    tinsert(UISpecialFrames, "ForeverQuestFiltersList") -- Esc closes it

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText("Forever Quest Filters")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)

    header = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    header:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)

    sortButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    sortButton:SetSize(170, 22)
    sortButton:SetPoint("TOPLEFT", 10, -46)
    sortButton:SetScript("OnClick", function()
        local cur = ns.db.sortMode
        for i, m in ipairs(SORT_ORDER) do
            if m == cur then ns.db.sortMode = SORT_ORDER[i % #SORT_ORDER + 1]; break end
        end
        QuestList:Refresh()
    end)

    onlyCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    onlyCheck:SetSize(24, 24)
    onlyCheck:SetPoint("LEFT", sortButton, "RIGHT", 6, 0)
    local label = onlyCheck:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", onlyCheck, "RIGHT", 0, 1)
    label:SetText("Completed only")
    onlyCheck:SetScript("OnClick", function(self)
        ns.db.completedOnly = self:GetChecked() and true or false
        QuestList:Refresh()
    end)

    local scroll = CreateFrame("ScrollFrame", "ForeverQuestFiltersListScroll", frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -74)
    scroll:SetPoint("BOTTOMRIGHT", -30, 10)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(280, 1)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(self, w) content:SetWidth(w) end)

    frame:SetScript("OnShow", function() QuestList:Refresh() end)
    frame:Hide()
end

function QuestList:Init()
    Build()
    ns.OnScan(function() QuestList:Refresh() end)
end

function QuestList:Toggle()
    if not frame then return end
    if frame:IsShown() then frame:Hide() else ns.ScanLog(); frame:Show() end
end
