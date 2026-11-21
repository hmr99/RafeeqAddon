local ADDON, ns = ...

ns.version = "0.4.1-beta1"

local defaults = {
    language     = nil, -- chosen on first login (picker), changeable any time
    autoAccept   = true,
    autoTurnIn   = true,
    skipTrivial  = true,
    hideBlizzard = true,
    showXP       = true,
    locked       = false,
    scale        = 1.0,
    trackerShown = true,
    mapPins      = true,
    minimapPins  = true,
    showAvailable = true,
    suggest      = true,
    autoSell     = true,
    autoRepair   = true,
    guildRepair  = false,
    autoRank     = true,
    trainerReminder = true,
    showETA      = true,
    turnHints    = true,
    arrivalAlert = true,
    arrivalYards = 30,
    driftAlert   = true,
    point        = nil, -- { point, relPoint, x, y }
}

local function applyDefaults(db, def)
    for k, v in pairs(def) do
        if db[k] == nil then db[k] = v end
    end
end

-- Chat frames use the game font (no Arabic glyphs), so chat output is English.
function ns.Print(key, ...)
    local s = (ns.Strings.en[key] or key)
    if select("#", ...) > 0 then s = s:format(...) end
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffRafeeq:|r " .. s)
end

function ns.GetLanguage()
    return (ns.db and ns.db.language) or "en"
end

function ns.SetLanguage(lang)
    if lang ~= "ar" and lang ~= "en" then return end
    ns.db.language = lang
    ns:Refresh()
end

-- tiny module/event system
ns.modules = {}
function ns:NewModule(name)
    local m = { name = name }
    self.modules[#self.modules + 1] = m
    return m
end

-- Called when a setting changes so modules can react.
function ns:Refresh()
    for _, m in ipairs(self.modules) do
        if m.OnRefresh then m:OnRefresh() end
    end
end

local frame = CreateFrame("Frame")
ns.eventFrame = frame
local handlers = {}

function ns:On(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        frame:RegisterEvent(event)
    end
    table.insert(handlers[event], fn)
end

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= ADDON then return end
        RafeeqDB = RafeeqDB or {}
        RafeeqCharDB = RafeeqCharDB or {}
        applyDefaults(RafeeqDB, defaults)
        ns.db = RafeeqDB
        ns.char = RafeeqCharDB
        ns.char.collapsed = ns.char.collapsed or {}
        ns.char.skipped = ns.char.skipped or {}
        for _, m in ipairs(ns.modules) do
            if m.OnInit then m:OnInit() end
        end
        return
    end
    local list = handlers[event]
    if list then
        for i = 1, #list do list[i](event, ...) end
    end
end)
frame:RegisterEvent("ADDON_LOADED")

ns:On("PLAYER_LOGIN", function()
    if not ns.Data:Init() then
        if not _G.LibQuestieDB then ns.Print("NO_QDB") end
    end
    ns:Refresh()
    if not ns.db.language and ns.ShowLanguagePicker then ns.ShowLanguagePicker() end
end)

-- Slash commands
SLASH_RAFEEQ1 = "/rafeeq"
SLASH_RAFEEQ2 = "/rf"
SlashCmdList.RAFEEQ = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")
    if cmd == "" or cmd == "options" or cmd == "config" then
        if ns.OpenOptions then ns.OpenOptions() end
    elseif cmd == "macro" or cmd == "macros" then
        ns.Macros:Toggle()
    elseif cmd == "arrow" then
        ns.Nav:Clear()
    elseif cmd == "unskip" then
        wipe(ns.char.skipped)
        ns:Refresh()
    elseif cmd == "toggle" then
        ns.db.trackerShown = not ns.db.trackerShown
        ns:Refresh()
    elseif cmd == "reset" then
        ns.db.point = nil
        ns.db.scale = 1.0
        ns:Refresh()
        ns.Print("RESET_DONE")
    elseif cmd == "scale" then
        local v = tonumber(arg)
        if v and v >= 0.5 and v <= 2 then
            ns.db.scale = v
            ns:Refresh()
        end
    elseif cmd == "ar" or cmd == "en" then
        ns.SetLanguage(cmd)
    elseif cmd == "lang" or cmd == "language" then
        ns.SetLanguage(ns.GetLanguage() == "ar" and "en" or "ar")
    else
        ns.Print("HELP")
    end
end
