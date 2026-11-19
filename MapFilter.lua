local _, ns = ...
local MapFilter = {}
ns.MapFilter = MapFilter

--[[ Module registry
  Each module teaches the filter about one source of map markers. A module is a table:

    ns.MapFilter:RegisterModule({
        name     = "Questie",          -- unique; shown in /fqf modules
        addon    = "Questie",          -- optional: only used when this addon is loaded
        priority = 50,                 -- lower runs first (default 100)

        -- Is this pin yours? Return true  = it's a completed-quest marker, keep it
        --                           false = yours, hide it
        --                           nil   = not yours, ask the next module
        Classify = function(pin, template) end,

        Init      = function(self) end, -- once, when its addon is loaded
        OnEnable  = function(self) end, -- filter turned on
        OnDisable = function(self) end, -- filter turned off
    })

  Pins no module claims are hidden (other addons' markers), except base-map pins
  (player arrow, highlights, labels...) which always stay.
  "/fqf module <name> off" makes the filter leave that module's markers visible.
]]

local modules = {}
local toggled, peeking = false, false
local hidden = setmetatable({}, { __mode = "k" })
local ticker, scheduled

local function IsActive() return toggled or peeking end
MapFilter.IsActive = IsActive
function MapFilter.IsToggled() return toggled end

local function IsAddOnLoadedCompat(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded(name) end
    return IsAddOnLoaded and IsAddOnLoaded(name)
end

local function Usable(m)
    return not m.addon or IsAddOnLoadedCompat(m.addon)
end

local function Enabled(m)
    return not (ns.db and ns.db.disabledModules and ns.db.disabledModules[m.name])
end

local function SafeCall(m, method, ...)
    if type(m[method]) == "function" then
        local ok, err = pcall(m[method], m, ...)
        if not ok then ns.Print(("module %s %s error: %s"):format(m.name, method, tostring(err))) end
    end
end

local function TryInit(m)
    if not m.initialized and Usable(m) then
        m.initialized = true
        SafeCall(m, "Init")
        if IsActive() and Enabled(m) then SafeCall(m, "OnEnable") end
    end
end

function MapFilter:RegisterModule(m)
    assert(type(m) == "table" and m.name, "module needs a name")
    m.priority = m.priority or 100
    for i, existing in ipairs(modules) do
        if existing.name == m.name then table.remove(modules, i); break end
    end
    modules[#modules + 1] = m
    table.sort(modules, function(a, b) return a.priority < b.priority end)
    if ns.ready then TryInit(m) end
    return m
end

function MapFilter:GetModules() return modules end

-- Decide one pin: true = keep visible, false = hide.
local function ShouldKeep(pin, template)
    for _, m in ipairs(modules) do
        if m.initialized and m.Classify then
            local ok, verdict = pcall(m.Classify, pin, template)
            if ok and verdict ~= nil then
                if not Enabled(m) then return true end -- user said leave this addon alone
                return verdict and true or false
            end
        end
    end
    return false -- unknown marker from some other addon: hide it
end

local function ForEachActivePin(fn)
    local map = WorldMapFrame
    if not map or type(map.pinPools) ~= "table" then return end
    for template, pool in pairs(map.pinPools) do
        if type(template) == "string" and type(pool) == "table" and pool.EnumerateActive then
            local ok, iter, state, ctl = pcall(pool.EnumerateActive, pool)
            if ok and iter then
                for pin in iter, state, ctl do fn(template, pin) end
            end
        end
    end
end

-- Same as ShouldKeep, for frames an addon parented straight onto the map canvas
-- (not through the map's pin system). Unclaimed ones are hidden.
local function FrameOwner(frame)
    for _, m in ipairs(modules) do
        if m.initialized and m.ClassifyFrame then
            local ok, verdict = pcall(m.ClassifyFrame, frame)
            if ok and verdict ~= nil then return m, verdict end
        end
    end
end

-- Blizzard's own non-pin canvas frames: the map tile layers (zoomed out, the
-- continent map is several of these). Never touch them.
local function IsBlizzardCanvasFrame(frame)
    local pools = { rawget(WorldMapFrame, "detailLayerPool") }
    for _, pool in ipairs(pools) do
        if type(pool) == "table" and pool.IsActive then
            local ok, active = pcall(pool.IsActive, pool, frame)
            if ok and active then return true end
        end
    end
    -- detail layers carry their tile textures in .textures / .DetailTiles
    if rawget(frame, "textures") or rawget(frame, "DetailTiles") or rawget(frame, "layerIndex") then
        return true
    end
    return false
end

-- Unclaimed frames are only hidden when they look like a marker: icon-sized,
-- or an overlay made only of lines (e.g. walking-route lines). Anything big
-- with textures (map tiles, overlays, highlights) is left alone.
local MAX_MARKER_SIZE = 80
local function LooksLikeMarker(frame)
    local w, h = frame:GetWidth() or 0, frame:GetHeight() or 0
    if w > 0 and h > 0 and w <= MAX_MARKER_SIZE and h <= MAX_MARKER_SIZE then return true end
    local regions = { frame:GetRegions() }
    if #regions == 0 then return false end
    for _, r in ipairs(regions) do
        if not (r.GetObjectType and r:GetObjectType() == "Line") then return false end
    end
    return true
end

local function ShouldKeepFrame(frame)
    local m, verdict = FrameOwner(frame)
    if not m then
        if IsBlizzardCanvasFrame(frame) or not LooksLikeMarker(frame) then return true end
        return false
    end
    if not Enabled(m) then return true end
    return verdict and true or false
end

-- Canvas frames are faded (alpha 0, mouse off) instead of hidden: their addon
-- shows and hides them on its own schedule, and a Hide() we later undo could
-- bring back a marker the addon had removed in the meantime.
local faded = setmetatable({}, { __mode = "k" }) -- [frame] = { alpha, mouse }

local function Fade(frame)
    if faded[frame] then
        if frame:GetAlpha() > 0 then frame:SetAlpha(0) end -- the addon reset it
        return
    end
    faded[frame] = { frame:GetAlpha(), frame.IsMouseEnabled and frame:IsMouseEnabled() }
    frame:SetAlpha(0)
    if frame.EnableMouse then frame:EnableMouse(false) end
end

local function Unfade(frame)
    local saved = faded[frame]
    if not saved then return end
    faded[frame] = nil
    frame:SetAlpha(saved[1] or 1)
    if saved[2] and frame.EnableMouse then frame:EnableMouse(true) end
end

local function CanvasChildren()
    local canvas = WorldMapFrame.GetCanvas and WorldMapFrame:GetCanvas()
        or (WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child)
    if not canvas then return {} end
    return { canvas:GetChildren() }
end

local function ApplyFilter()
    scheduled = false
    if not IsActive() or not WorldMapFrame or not WorldMapFrame:IsShown() then return end
    local isPin = {}
    ForEachActivePin(function(template, pin)
        isPin[pin] = true
        if pin:IsShown() and not ShouldKeep(pin, template) then
            pin:Hide()
            hidden[pin] = true
        end
    end)
    for _, frame in ipairs(CanvasChildren()) do
        if not isPin[frame] and frame:IsShown() then
            if ShouldKeepFrame(frame) then Unfade(frame) else Fade(frame) end
        end
    end
end
MapFilter.Apply = ApplyFilter

local function ScheduleApply()
    if scheduled or not IsActive() then return end
    scheduled = true
    C_Timer.After(0, ApplyFilter)
end

local function RestorePins()
    local activeSet = {}
    ForEachActivePin(function(_, pin) activeSet[pin] = true end)
    for pin in pairs(hidden) do
        if activeSet[pin] then pin:Show() end
    end
    wipe(hidden)
    for frame in pairs(faded) do Unfade(frame) end
end

local function StateChanged(wasActive)
    local nowActive = IsActive()
    if nowActive ~= wasActive then
        for _, m in ipairs(modules) do
            if m.initialized and Enabled(m) then SafeCall(m, nowActive and "OnEnable" or "OnDisable") end
        end
        if nowActive then
            ApplyFilter()
            if not ticker then ticker = C_Timer.NewTicker(0.25, ApplyFilter) end
        else
            if ticker then ticker:Cancel(); ticker = nil end
            RestorePins()
        end
    end
end

function MapFilter:Toggle()
    local was = IsActive()
    toggled = not toggled
    StateChanged(was)
end

function MapFilter:Peek(down)
    local was = IsActive()
    peeking = down and true or false
    StateChanged(was)
end

function MapFilter:SetModuleEnabled(name, on)
    for _, m in ipairs(modules) do
        if m.name:lower() == name:lower() then
            ns.db.disabledModules = ns.db.disabledModules or {}
            local wasOn = Enabled(m)
            ns.db.disabledModules[m.name] = (not on) or nil
            if IsActive() and m.initialized and wasOn ~= on then
                SafeCall(m, on and "OnEnable" or "OnDisable")
                if not on then RestorePins() end
                ApplyFilter()
            end
            ns.Print(("module %s %s"):format(m.name, on and "on" or "off (its markers are left visible)"))
            return
        end
    end
    ns.Print("no module named " .. name .. " (see /fqf modules)")
end

function MapFilter:ListModules()
    for _, m in ipairs(modules) do
        local state = not Usable(m) and "|cff888888addon not loaded|r"
            or (Enabled(m) and "|cff20ff20on|r" or "|cffff5555off|r")
        ns.Print(("%s (priority %d): %s"):format(m.name, m.priority, state))
    end
end

function MapFilter:OnAddonLoaded()
    if not ns.ready then return end
    for _, m in ipairs(modules) do TryInit(m) end
end

function MapFilter:Init()
    ns.ready = true
    for _, m in ipairs(modules) do TryInit(m) end
    if not WorldMapFrame then return end

    hooksecurefunc(WorldMapFrame, "AcquirePin", ScheduleApply)
    if WorldMapFrame.OnMapChanged then hooksecurefunc(WorldMapFrame, "OnMapChanged", ScheduleApply) end
    WorldMapFrame:HookScript("OnShow", ScheduleApply)

end

function MapFilter:Debug()
    if ns.Menu and ns.Menu.discoveredTag then ns.Print("quest log settings menu: " .. ns.Menu.discoveredTag) end
    local counts = {}
    ForEachActivePin(function(template, pin)
        local c = counts[template] or { n = 0, kept = 0, owner = "unclaimed (hidden)" }
        c.n = c.n + 1
        for _, m in ipairs(modules) do
            if m.initialized and m.Classify then
                local ok, v = pcall(m.Classify, pin, template)
                if ok and v ~= nil then c.owner = m.name; break end
            end
        end
        if ShouldKeep(pin, template) then c.kept = c.kept + 1 end
        counts[template] = c
    end)
    if not next(counts) then ns.Print("No pins found (open the world map first).") end
    for template, c in pairs(counts) do
        ns.Print(("%s: %d pins, %d kept, module: %s"):format(template, c.n, c.kept, c.owner))
    end

    -- Frames addons put straight on the canvas, outside the pin system.
    local isPin = {}
    ForEachActivePin(function(_, pin) isPin[pin] = true end)
    local n = 0
    for _, frame in ipairs(CanvasChildren()) do
        if not isPin[frame] and frame:IsShown() then
            n = n + 1
            local m = FrameOwner(frame)
            local tex
            for _, r in ipairs({ frame:GetRegions() }) do
                if r.GetTexture and r:IsShown() then
                    tex = (r.GetAtlas and r:GetAtlas()) or r:GetTexture()
                    if tex then break end
                end
            end
            if n <= 15 then
                ns.Print(("canvas frame %s: texture %s, size %dx%d, module: %s, %s"):format(
                    frame:GetName() or frame:GetDebugName() or "?", tostring(tex),
                    frame:GetWidth() or 0, frame:GetHeight() or 0,
                    m and m.name or "none", ShouldKeepFrame(frame) and "kept" or "hidden"))
            end
        end
    end
    if n > 15 then ns.Print(("...and %d more canvas frames"):format(n - 15)) end
end
