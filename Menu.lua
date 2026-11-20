-- Dropdown entries:
--   * the quest log's settings dropdown (QuestScrollFrame.SettingsDropdown):
--     our quest log options right under the game's "Show Quest Objectives"
--   * the world map's filter dropdown: our "Forever Quest Filters" section
--     with the map option and the sortable list
local _, ns = ...
local Menu_ = {}
ns.Menu = Menu_

-- Names Blizzard may use for the quest log settings menu. The real one is also
-- detected the first time that dropdown opens (see DiscoverLogTag).
local LOG_MENU_TAGS = {
    "MENU_QUEST_MAP_FRAME_SETTINGS",
    "MENU_QUEST_LOG_SETTINGS",
    "MENU_QUEST_SCROLL_FRAME_SETTINGS",
    "MENU_QUEST_MAP_SETTINGS",
}
local registered = {}
Menu_.discoveredTag = nil

local function ElementText(desc)
    if MenuUtil and MenuUtil.GetElementText then
        local ok, t = pcall(MenuUtil.GetElementText, desc)
        if ok and type(t) == "string" then return t end
    end
    local t = rawget(desc, "text")
    return type(t) == "string" and t or nil
end

local function FindObjectivesIndex(root)
    if not root.EnumerateElementDescriptions then return nil end
    local want = rawget(_G, "SHOW_QUEST_OBJECTIVES_ON_MAP_TEXT")
    local i = 0
    for _, desc in root:EnumerateElementDescriptions() do
        i = i + 1
        local text = ElementText(desc)
        if text and ((want and text == want) or text:lower():find("quest objectives", 1, true)) then
            return i
        end
    end
end

local function LogItems()
    return {
        MenuUtil.CreateCheckbox("Completed quests only",
            function() return ns.QuestLogFilter:IsOn() end,
            function() ns.QuestLogFilter:Toggle() end),
        MenuUtil.CreateCheckbox("Sort completed quests first",
            function() return ns.QuestLogFilter:IsSorted() end,
            function() ns.QuestLogFilter:ToggleSort() end),
    }
end

local function ModifyLogMenu(_, root)
    local items = LogItems()
    local at = FindObjectivesIndex(root)
    if at then
        for k = #items, 1, -1 do root:Insert(items[k], at + 1) end -- bottom-up keeps order
    else
        root:CreateDivider()
        for _, item in ipairs(items) do root:Insert(item) end
    end
end

local function RegisterLogTag(tag)
    if type(tag) ~= "string" or registered[tag] then return false end
    registered[tag] = true
    Menu.ModifyMenu(tag, ModifyLogMenu)
    return true
end

-- Read the tag of the menu the settings dropdown just opened.
local function OpenMenuTag(dropdown)
    local candidates = {}
    local function add(desc)
        if type(desc) == "table" and desc.GetTag then
            local ok, tag = pcall(desc.GetTag, desc)
            if ok and tag then candidates[#candidates + 1] = tag end
        end
    end
    local menu = rawget(dropdown, "menu")
    if type(menu) == "table" and menu.GetMenuDescription then
        local ok, d = pcall(menu.GetMenuDescription, menu); if ok then add(d) end
    end
    if dropdown.GetMenuDescription then
        local ok, d = pcall(dropdown.GetMenuDescription, dropdown); if ok then add(d) end
    end
    add(rawget(dropdown, "menuDescription"))
    return candidates[1]
end

local function DiscoverLogTag()
    local dd = QuestScrollFrame and QuestScrollFrame.SettingsDropdown
    if not dd or Menu_.hookedDropdown == dd then return end
    Menu_.hookedDropdown = dd -- kept on our table, not written onto Blizzard's frame
    dd:HookScript("OnMouseDown", function(self)
        C_Timer.After(0, function()
            local tag = OpenMenuTag(self)
            if tag then
                Menu_.discoveredTag = tag
                if RegisterLogTag(tag) then
                    ns.Print("found the quest log settings menu - close and reopen it to see the new options")
                end
            end
        end)
    end)
end

local function ModifyMapMenu(_, root)
    root:CreateDivider()
    root:CreateTitle("Forever Quest Filters")
    root:Insert(MenuUtil.CreateCheckbox(
        ("Completed quests only (%d)"):format(ns.CompletedCount()),
        function() return ns.MapFilter.IsToggled() end,
        function() ns.MapFilter:Toggle() end))
    root:Insert(MenuUtil.CreateCheckbox("Tracked quests only",
        function() return ns.MapFilter.IsTrackedOnly() end,
        function() ns.MapFilter:ToggleTracked() end))
    if MenuUtil.CreateButton then
        root:Insert(MenuUtil.CreateButton("Sortable quest list...", function() ns.QuestList:Toggle() end))
        root:Insert(MenuUtil.CreateButton("Create hand-in route...", function() ns.Route:Create() end))
    end
end

function Menu_:Init()
    if not (Menu and Menu.ModifyMenu and MenuUtil and MenuUtil.CreateCheckbox) then
        ns.Print("dropdown menus not available; use /fqf, /fqf log, /fqf sort and /fqf list instead")
        return
    end
    if not registered.MENU_WORLD_MAP_TRACKING then
        registered.MENU_WORLD_MAP_TRACKING = true
        Menu.ModifyMenu("MENU_WORLD_MAP_TRACKING", ModifyMapMenu)
    end
    for _, tag in ipairs(LOG_MENU_TAGS) do RegisterLogTag(tag) end
    DiscoverLogTag()
end

-- the quest log's frames can load after us
function Menu_:OnAddonLoaded()
    if Menu and Menu.ModifyMenu then DiscoverLogTag() end
end
