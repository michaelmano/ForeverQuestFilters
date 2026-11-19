local ADDON, ns = ...
ForeverQuestFilters = ns

BINDING_HEADER_FQF = "Forever Quest Filters"
BINDING_NAME_FQF_TOGGLE_COMPLETED = "Toggle completed-only map markers"
BINDING_NAME_FQF_PEEK_COMPLETED = "Hold to show completed-only map markers"
BINDING_NAME_FQF_TOGGLE_LIST = "Toggle sortable quest list"

local DEFAULTS = {
    sortMode = "completed", -- completed | level | log
    completedOnly = false,
    listPoint = nil,
    disabledModules = {},
    questLogCompletedOnly = false,
    questLogSortCompleted = false,
}

ns.questInfo = {}   -- [questID] = entry
ns.questList = {}   -- array of entries in log order
ns.listeners = {}

function ns.Print(msg)
    print("|cff33ff99Forever Quest Filters|r: " .. tostring(msg))
end

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g, h = pcall(fn, ...)
    if ok then return a, b, c, d, e, f, g, h end
end

local function NumEntries()
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
        return Call(C_QuestLog.GetNumQuestLogEntries) or 0
    end
    return Call(GetNumQuestLogEntries) or 0
end

local function EntryAt(i)
    -- returns title, level, isHeader, questID, isComplete, isFailed
    if C_QuestLog and C_QuestLog.GetInfo then
        local info = Call(C_QuestLog.GetInfo, i)
        if not info then return end
        if info.isHeader then return info.title, nil, true end
        local id = info.questID
        local complete = info.isComplete == true or info.isComplete == 1
        if not complete and id and C_QuestLog.IsComplete then
            complete = Call(C_QuestLog.IsComplete, id) and true or false
        end
        if not complete and id and C_QuestLog.ReadyForTurnIn then
            complete = Call(C_QuestLog.ReadyForTurnIn, id) and true or false
        end
        local failed = id and C_QuestLog.IsFailed and Call(C_QuestLog.IsFailed, id) or false
        return info.title, info.level, false, id, complete, failed and true or false
    end
    local title, level, _, isHeader, _, isComplete, _, id = Call(GetQuestLogTitle, i)
    return title, level, isHeader, id, isComplete == 1 or isComplete == true, isComplete == -1
end

function ns.ScanLog()
    wipe(ns.questInfo)
    wipe(ns.questList)
    local zone
    for i = 1, NumEntries() do
        local title, level, isHeader, id, complete, failed = EntryAt(i)
        if isHeader then
            zone = title
        elseif title and id and id ~= 0 then
            local e = {
                index = i, title = title, level = level or 0, questID = id,
                complete = complete and not failed, failed = failed, zone = zone or "",
            }
            ns.questInfo[id] = e
            ns.questList[#ns.questList + 1] = e
        end
    end
    for _, fn in ipairs(ns.listeners) do pcall(fn) end
end

function ns.CompletedCount()
    local n = 0
    for _, e in ipairs(ns.questList) do if e.complete then n = n + 1 end end
    return n
end

function ns.IsQuestComplete(questID)
    if not questID or questID == 0 then return false end
    local e = ns.questInfo[questID]
    if e then return e.complete end
    if C_QuestLog and C_QuestLog.IsComplete then
        return Call(C_QuestLog.IsComplete, questID) and true or false
    end
    return false
end

function ns.OnScan(fn) ns.listeners[#ns.listeners + 1] = fn end

local pending = false
local function ScheduleScan()
    if pending then return end
    pending = true
    C_Timer.After(0.1, function() pending = false; ns.ScanLog() end)
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("QUEST_LOG_UPDATE")
f:RegisterEvent("QUEST_ACCEPTED")
f:RegisterEvent("QUEST_REMOVED")
f:RegisterEvent("QUEST_TURNED_IN")
f:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON then
            ForeverQuestFiltersDB = ForeverQuestFiltersDB or {}
            for k, v in pairs(DEFAULTS) do
                if ForeverQuestFiltersDB[k] == nil then ForeverQuestFiltersDB[k] = v end
            end
            ns.db = ForeverQuestFiltersDB
        end
        if ns.MapFilter and ns.MapFilter.OnAddonLoaded then ns.MapFilter:OnAddonLoaded(arg1) end
        -- the quest log code may load after us (Blizzard_WorldMap)
        if ns.ready and ns.QuestLogFilter then ns.QuestLogFilter:Init() end
        if ns.ready and ns.Menu then ns.Menu:OnAddonLoaded() end
    elseif event == "PLAYER_LOGIN" then
        if ns.MapFilter then ns.MapFilter:Init() end
        if ns.QuestList then ns.QuestList:Init() end
        if ns.QuestLogFilter then ns.QuestLogFilter:Init() end
        if ns.Menu then ns.Menu:Init() end
        ScheduleScan()
    elseif event == "UNIT_QUEST_LOG_CHANGED" then
        if arg1 == "player" then ScheduleScan() end
    else
        ScheduleScan()
    end
end)

SLASH_FOREVERQUESTFILTERS1 = "/fqf"
SLASH_FOREVERQUESTFILTERS2 = "/questfilters"
SlashCmdList.FOREVERQUESTFILTERS = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "log" then
        ns.QuestLogFilter:Toggle()
        ns.Print("quest log completed-only: " .. (ns.db.questLogCompletedOnly and "on" or "off"))
    elseif msg == "sort" then
        ns.QuestLogFilter:ToggleSort()
        ns.Print("quest log sort completed first: " .. (ns.db.questLogSortCompleted and "on" or "off"))
    elseif msg == "list" then
        ns.QuestList:Toggle()
    elseif msg == "map" or msg == "" then
        ns.MapFilter:Toggle()
    elseif msg == "debug" then
        ns.MapFilter:Debug()
    elseif msg == "modules" then
        ns.MapFilter:ListModules()
    elseif msg:match("^module ") then
        local name, state = msg:match("^module%s+(%S+)%s*(%S*)")
        if name then ns.MapFilter:SetModuleEnabled(name, state ~= "off") end
    else
        ns.Print("/fqf  - toggle completed-only map markers")
        ns.Print("/fqf log  - toggle completed-only in the quest log")
        ns.Print("/fqf sort  - toggle completed-first sorting in the quest log")
        ns.Print("/fqf list  - toggle the sortable quest list")
        ns.Print("/fqf modules  - list filter modules")
        ns.Print("/fqf module <name> on|off  - off leaves that addon's markers visible")
        ns.Print("/fqf debug  - list map pin templates on the current map and their module")
    end
end
