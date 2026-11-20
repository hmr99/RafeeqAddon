-- Rafeeq: auto macro maker.
-- Builds three character macros from the spells you know:
--   RF_ST  - single-target priority
--   RF_AOE - AoE priority
--   RF_CD  - every known spell with a base cooldown over 7 s
-- In-game rule we rely on: one press casts the FIRST line that can fire (lines on cooldown or
-- not usable are passed over). Addons cannot make a macro check debuffs or stacks - Blizzard rule.
local _, ns = ...
local L = ns.L

local Macros = ns:NewModule("Macros")
ns.Macros = Macros

local MACRO_LIMIT = 255
local CD_MIN_MS = 7000
local NAMES = { st = "RF_ST", aoe = "RF_AOE", cd = "RF_CD" }

local function splitCond(entry)
    local cond, name = entry:match("^(%b[])%s*(.+)$")
    if cond then return cond, name end
    return nil, entry
end

local function spellID(name)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(name)
        return info and info.spellID
    end
    if GetSpellInfo then return select(7, GetSpellInfo(name)) end
end

local function isKnown(name)
    local id = spellID(name)
    if not id then return false end
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, id)
        if ok and known ~= nil then return known end
    end
    if IsSpellKnown then return IsSpellKnown(id) end
    return true
end

local function baseCooldown(name)
    local id = spellID(name)
    if not id or not GetSpellBaseCooldown then return 0 end
    local ms = GetSpellBaseCooldown(id)
    return ms or 0
end

-- returns macro body text
function Macros:Build(kind)
    local class = select(2, UnitClass("player"))
    local data = ns.ClassSpells[class]
    if not data then return "" end
    local list = data[kind] or {}
    local header = "#showtooltip\n"
    if data.startAttack then header = header .. "/startattack\n" end
    local body, used = header, {}
    for _, entry in ipairs(list) do
        local cond, name = splitCond(entry)
        if not used[entry] and isKnown(name) and (kind ~= "cd" or baseCooldown(name) > CD_MIN_MS) then
            local line = "/cast " .. (cond and (cond .. " ") or "") .. name .. "\n"
            if #body + #line > MACRO_LIMIT then break end
            body = body .. line
            used[entry] = true
        end
    end
    return (body:gsub("\n$", ""))
end

local function save(kind, body)
    if InCombatLockdown() then ns.Print("MACRO_COMBAT") return false end
    local name = NAMES[kind]
    local icon = "INV_MISC_QUESTIONMARK"
    local idx = GetMacroIndexByName(name)
    if idx and idx > 0 then
        EditMacro(idx, name, icon, body)
    else
        local _, perChar = GetNumMacros()
        if (perChar or 0) >= (MAX_CHARACTER_MACROS or 18) then ns.Print("MACRO_FULL") return false end
        CreateMacro(name, icon, body, true)
    end
    return true
end

function Macros:BuildAll()
    if InCombatLockdown() then ns.Print("MACRO_COMBAT") return end
    for kind in pairs(NAMES) do save(kind, self:Build(kind)) end
    ns.Print("MACRO_DONE")
end

---------------------------------------------------------------------------
-- Window: preview / edit the three macros
---------------------------------------------------------------------------
local win
local boxes = {}

local TITLES = { st = "MACRO_ST", aoe = "MACRO_AOE", cd = "MACRO_CD" }
local ORDER = { "st", "aoe", "cd" }

local function create()
    win = CreateFrame("Frame", "RafeeqMacros", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    win:SetSize(600, 330)
    win:SetPoint("CENTER")
    win:SetFrameStrata("DIALOG")
    win:SetMovable(true)
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)
    if win.SetBackdrop then
        win:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        win:SetBackdropColor(0.05, 0.06, 0.08, 0.96)
        win:SetBackdropBorderColor(0.2, 0.75, 1, 0.6)
    end
    tinsert(UISpecialFrames, "RafeeqMacros")
    local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    win.title = win:CreateFontString(nil, "OVERLAY")
    win.title:SetPoint("TOP", 0, -10)
    win.title:SetTextColor(0.4, 0.85, 1)

    for i, kind in ipairs(ORDER) do
        local x = 12 + (i - 1) * 194
        local t = win:CreateFontString(nil, "OVERLAY")
        t:SetPoint("TOPLEFT", x, -38)
        t:SetWidth(186)
        t:SetTextColor(1, 0.82, 0)
        local bg = CreateFrame("Frame", nil, win, BackdropTemplateMixin and "BackdropTemplate" or nil)
        bg:SetPoint("TOPLEFT", x, -62)
        bg:SetSize(186, 210)
        if bg.SetBackdrop then
            bg:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
            bg:SetBackdropColor(0, 0, 0, 0.5)
        end
        local eb = CreateFrame("EditBox", nil, bg)
        eb:SetMultiLine(true)
        eb:SetAutoFocus(false)
        eb:SetFont(STANDARD_TEXT_FONT, 12, "")
        eb:SetMaxLetters(MACRO_LIMIT)
        eb:SetPoint("TOPLEFT", 6, -6)
        eb:SetPoint("BOTTOMRIGHT", -6, 6)
        eb:SetScript("OnEscapePressed", eb.ClearFocus)
        boxes[kind] = { title = t, eb = eb }
    end

    local function button(textKey, x, onClick)
        local b = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
        b:SetSize(180, 26)
        b:SetPoint("BOTTOM", x, 14)
        b:SetScript("OnClick", onClick)
        b.key = textKey
        return b
    end
    win.genBtn = button("MACRO_GENERATE", -95, function()
        for _, kind in ipairs(ORDER) do boxes[kind].eb:SetText(Macros:Build(kind)) end
    end)
    win.saveBtn = button("MACRO_SAVE", 95, function()
        if InCombatLockdown() then ns.Print("MACRO_COMBAT") return end
        for _, kind in ipairs(ORDER) do save(kind, boxes[kind].eb:GetText()) end
        ns.Print("MACRO_DONE")
    end)
    win:Hide()
end

local function layout()
    ns.SetUIFont(win.title, 16, "OUTLINE")
    win.title:SetText(L("MACRO_TITLE"))
    for _, kind in ipairs(ORDER) do
        ns.SetUIFont(boxes[kind].title, 13, "")
        boxes[kind].title:SetJustifyH(ns.GetLanguage() == "ar" and "RIGHT" or "LEFT")
        boxes[kind].title:SetText(L(TITLES[kind]))
        local idx = GetMacroIndexByName(NAMES[kind])
        local body = idx and idx > 0 and select(3, GetMacroInfo(idx)) or Macros:Build(kind)
        boxes[kind].eb:SetText(body or "")
    end
    -- buttons use the game font; give them English-safe labels when Arabic glyphs unavailable
    for _, b in ipairs({ win.genBtn, win.saveBtn }) do
        local fs = b:GetFontString()
        if fs then ns.SetUIFont(fs, 13, "") end
        b:SetText(L(b.key))
    end
end

function Macros:Toggle()
    if not win then create() end
    if win:IsShown() then win:Hide() return end
    layout()
    win:Show()
end
