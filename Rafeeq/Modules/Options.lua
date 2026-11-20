local _, ns = ...
local L = ns.L

local Options = ns:NewModule("Options")

-- language choices (native names, each in a font that can draw it)
ns.LANG_TABS = {
    { lang = "ar", text = ns.Shaper.Shape("العربية"), font = ns.ARABIC_FONT },
    { lang = "en", text = "English", font = STANDARD_TEXT_FONT },
}
local win
local widgets = {}

local ITEMS = {
    { key = "autoAccept",   label = "OPT_AUTO_ACCEPT" },
    { key = "autoTurnIn",   label = "OPT_AUTO_TURNIN" },
    { key = "skipTrivial",  label = "OPT_SKIP_TRIVIAL" },
    { key = "hideBlizzard", label = "OPT_HIDE_BLIZZ" },
    { key = "showXP",       label = "OPT_SHOW_XP" },
    { key = "locked",       label = "OPT_LOCK" },
    { key = "mapPins",      label = "OPT_MAP_PINS" },
    { key = "minimapPins",  label = "OPT_MINI_PINS" },
    { key = "showAvailable", label = "OPT_AVAILABLE" },
    { key = "suggest",      label = "OPT_SUGGEST" },
    { key = "autoSell",     label = "OPT_AUTO_SELL" },
    { key = "autoRepair",   label = "OPT_AUTO_REPAIR" },
    { key = "guildRepair",  label = "OPT_GUILD_REPAIR" },
    { key = "autoRank",     label = "OPT_AUTO_RANK" },
    { key = "trainerReminder", label = "OPT_TRAINER" },
    { key = "showETA",      label = "OPT_ETA" },
    { key = "turnHints",    label = "OPT_TURN_HINTS" },
    { key = "arrivalAlert", label = "OPT_ARRIVAL" },
    { key = "driftAlert",   label = "OPT_DRIFT" },
}

local function layout()
    local isAr = ns.GetLanguage() == "ar"
    ns.SetUIFont(win.title, 16, "OUTLINE")
    win.title:SetText(L("OPT_TITLE"))

    -- language tabs: the active one is lit
    for _, tab in ipairs(win.langTabs) do
        local active = ns.GetLanguage() == tab.lang
        tab.bg:SetColorTexture(0.2, 0.75, 1, active and 0.45 or 0.08)
        tab.label:SetTextColor(active and 1 or 0.7, active and 1 or 0.7, active and 1 or 0.7)
    end

    for i, w in ipairs(widgets) do
        local item = ITEMS[i]
        local y = -74 - (i - 1) * 25
        w.cb:ClearAllPoints()
        w.label:ClearAllPoints()
        if isAr then
            w.cb:SetPoint("TOPRIGHT", win, "TOPRIGHT", -16, y)
            w.label:SetPoint("RIGHT", w.cb, "LEFT", -4, 0)
            w.label:SetJustifyH("RIGHT")
        else
            w.cb:SetPoint("TOPLEFT", win, "TOPLEFT", 16, y)
            w.label:SetPoint("LEFT", w.cb, "RIGHT", 4, 0)
            w.label:SetJustifyH("LEFT")
        end
        ns.SetUIFont(w.label, 13, "")
        w.label:SetText(L(item.label))
        w.cb:SetChecked(ns.db[item.key] and true or false)
    end

    local y = -74 - #ITEMS * 25 - 6
    win.scaleLabel:ClearAllPoints()
    ns.SetUIFont(win.scaleLabel, 13, "")
    win.scaleLabel:SetText(L("OPT_SCALE") .. "  " .. ("%.2f"):format(ns.db.scale or 1))
    win.scaleLabel:SetPoint("TOP", win, "TOP", 0, y)

    win.note:ClearAllPoints()
    ns.SetUIFont(win.note, 11, "")
    win.note:SetText(L("OPT_SHIFT_NOTE"))
    win.note:SetPoint("BOTTOM", win, "BOTTOM", 0, 12)
    local fs = win.macroBtn:GetFontString()
    if fs then ns.SetUIFont(fs, 13, "") end
    win.macroBtn:SetText(L("OPT_MACROS_BTN"))
end

local function create()
    win = CreateFrame("Frame", "RafeeqOptions", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    win:SetSize(360, 74 + #ITEMS * 25 + 110)
    win:SetPoint("CENTER")
    win:SetFrameStrata("DIALOG")
    win:SetMovable(true)
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)
    win:SetClampedToScreen(true)
    if win.SetBackdrop then
        win:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        win:SetBackdropColor(0.05, 0.06, 0.08, 0.95)
        win:SetBackdropBorderColor(0.2, 0.75, 1, 0.6)
    end
    tinsert(UISpecialFrames, "RafeeqOptions") -- Esc closes it

    win.title = win:CreateFontString(nil, "OVERLAY")
    win.title:SetPoint("TOP", 0, -12)
    win.title:SetTextColor(0.4, 0.85, 1)

    local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    win.langTabs = {}
    for i, def in ipairs(ns.LANG_TABS) do
        local tab = CreateFrame("Button", nil, win)
        tab:SetSize(120, 24)
        tab:SetPoint("TOP", (i == 1) and 62 or -62, -38) -- Arabic on the right, English on the left
        tab.bg = tab:CreateTexture(nil, "BACKGROUND")
        tab.bg:SetAllPoints()
        tab.label = tab:CreateFontString(nil, "OVERLAY")
        tab.label:SetPoint("CENTER")
        tab.label:SetFont(def.font, 14, "")
        tab.label:SetText(def.text)
        tab.lang = def.lang
        tab:SetScript("OnClick", function() ns.SetLanguage(def.lang) end)
        win.langTabs[i] = tab
    end

    for i, item in ipairs(ITEMS) do
        local cb = CreateFrame("CheckButton", nil, win, "UICheckButtonTemplate")
        cb:SetSize(24, 24)
        local label = win:CreateFontString(nil, "OVERLAY")
        label:SetTextColor(0.95, 0.95, 0.95)
        label:SetWidth(270)
        cb:SetScript("OnClick", function(self)
            ns.db[item.key] = self:GetChecked() and true or false
            ns:Refresh()
        end)
        widgets[i] = { cb = cb, label = label }
    end

    win.scaleLabel = win:CreateFontString(nil, "OVERLAY")
    win.scaleLabel:SetTextColor(0.95, 0.95, 0.95)

    local function scaleButton(text, delta, xOff)
        local b = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
        b:SetSize(28, 22)
        b:SetText(text)
        b:SetPoint("TOP", win.scaleLabel, "BOTTOM", xOff, -6)
        b:SetScript("OnClick", function()
            local v = (ns.db.scale or 1) + delta
            ns.db.scale = math.max(0.6, math.min(1.8, math.floor(v * 100 + 0.5) / 100))
            ns:Refresh()
        end)
    end
    scaleButton("-", -0.05, -20)
    scaleButton("+", 0.05, 20)

    local mb = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    mb:SetSize(160, 24)
    mb:SetPoint("BOTTOM", 0, 34)
    mb:SetScript("OnClick", function() ns.Macros:Toggle() end)
    win.macroBtn = mb

    win.note = win:CreateFontString(nil, "OVERLAY")
    win.note:SetWidth(310)
    win.note:SetTextColor(0.6, 0.7, 0.8)
    win:Hide()
end

function ns.OpenOptions()
    if not win then create() end
    if win:IsShown() then win:Hide() return end
    layout()
    win:Show()
end

function Options:OnRefresh()
    if win and win:IsShown() then layout() end
end

---------------------------------------------------------------------------
-- First-run language picker
---------------------------------------------------------------------------
local picker
function ns.ShowLanguagePicker()
    if not picker then
        picker = CreateFrame("Frame", "RafeeqLanguagePicker", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        picker:SetSize(340, 130)
        picker:SetPoint("CENTER", 0, 120)
        picker:SetFrameStrata("DIALOG")
        if picker.SetBackdrop then
            picker:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
            picker:SetBackdropColor(0.05, 0.06, 0.08, 0.96)
            picker:SetBackdropBorderColor(0.2, 0.75, 1, 0.8)
        end
        local t1 = picker:CreateFontString(nil, "OVERLAY")
        t1:SetPoint("TOP", 0, -12)
        t1:SetFont(ns.ARABIC_FONT, 14, "")
        t1:SetText(ns.Shaper.Shape(ns.Strings.ar.LANG_PICK))
        local t2 = picker:CreateFontString(nil, "OVERLAY")
        t2:SetPoint("TOP", t1, "BOTTOM", 0, -4)
        t2:SetFont(STANDARD_TEXT_FONT, 12, "")
        t2:SetText(ns.Strings.en.LANG_PICK)
        for i, def in ipairs(ns.LANG_TABS) do
            local b = CreateFrame("Button", nil, picker)
            b:SetSize(130, 34)
            b:SetPoint("BOTTOM", (i == 1) and 72 or -72, 16)
            local bg = b:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(0.2, 0.75, 1, 0.3)
            local hl = b:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0.15)
            local fs = b:CreateFontString(nil, "OVERLAY")
            fs:SetPoint("CENTER")
            fs:SetFont(def.font, 16, "")
            fs:SetText(def.text)
            b:SetScript("OnClick", function()
                ns.SetLanguage(def.lang)
                picker:Hide()
            end)
        end
    end
    picker:Show()
end
