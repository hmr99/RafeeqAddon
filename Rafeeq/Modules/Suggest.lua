-- Rafeeq: "what to do next" panel.
--  * Nearby: active quests whose objectives are close to you -> do them now, no back-and-forth.
--  * Available: best new quests in this zone with Do / Skip.
local _, ns = ...
local L = ns.L
local Data = ns.Data

local Suggest = ns:NewModule("Suggest")
ns.Suggest = Suggest

local NEAR_YARDS = 150
local MAX_AVAILABLE = 6

local frame, hdrNear, hdrAvail
local rows = {}
local nearSet = {}     -- [questID] = distance
local available = {}

function Suggest:IsNear(questID) return nearSet[questID] end

---------------------------------------------------------------------------
local function compute()
    wipe(nearSet)
    available = {}
    if not Data.ready then return end
    local map, _, _, pc, pwx, pwy = Data:Player()
    if not pc then return end
    local Q = ns.QuestAPI
    for i = 1, Q.NumEntries() or 0 do
        local e = Q.Entry(i)
        if e and not e.isHeader and e.questID then
            local pts = ns.Nav:QuestPoints(e.questID)
            local _, d = Data:Nearest(pts)
            if d and d <= NEAR_YARDS then nearSet[e.questID] = d end
        end
    end
    local level = UnitLevel("player")
    for _, q in ipairs(Data:AvailableOnMap(map, level)) do
        local c, wx, wy = Data:World(q.point.map, q.point.x, q.point.y)
        q.dist = Data:Distance(pc, pwx, pwy, c, wx, wy) or 99999
        -- score: closer and closer-to-your-level first
        q.score = q.dist + math.abs((q.level or level) - level) * 120
        available[#available + 1] = q
    end
    table.sort(available, function(a, b) return a.score < b.score end)
end

---------------------------------------------------------------------------
local function makeRow(i)
    local r = CreateFrame("Frame", nil, frame)
    r:SetHeight(18)
    r.text = r:CreateFontString(nil, "OVERLAY")
    r.text:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    r.text:SetJustifyH("LEFT")
    r.text:SetWordWrap(false)
    local function btn(tex, tip, onClick)
        local b = CreateFrame("Button", nil, r)
        b:SetSize(16, 16)
        b:SetNormalTexture(tex)
        b:SetScript("OnClick", onClick)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tip)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return b
    end
    r.skip = btn("Interface\\Buttons\\UI-GroupLoot-Pass-Up", "Skip", function()
        if r.questID then ns.char.skipped[r.questID] = true; ns.Pins:Refresh(); Suggest:Update(true) end
    end)
    r.skip:SetPoint("RIGHT", 0, 0)
    r.go = btn("Interface\\Buttons\\UI-CheckBox-Check", "Do it - guide me", function()
        if r.isActive then ns.Nav:SetQuest(r.questID)
        elseif r.point then ns.Nav:SetPoint(r.point.map, r.point.x, r.point.y, r.label) end
    end)
    r.go:SetPoint("RIGHT", r.skip, "LEFT", -2, 0)
    r.text:SetPoint("LEFT", 0, 0)
    r.text:SetPoint("RIGHT", r.go, "LEFT", -4, 0)
    rows[i] = r
    return r
end

local function create()
    frame = CreateFrame("Frame", "RafeeqSuggest", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame:SetWidth(270)
    frame:SetPoint("TOPRIGHT", RafeeqTracker, "BOTTOMRIGHT", 0, -4)
    if frame.SetBackdrop then
        frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        frame:SetBackdropColor(0.05, 0.06, 0.08, 0.72)
        frame:SetBackdropBorderColor(0.2, 0.75, 1, 0.35)
    end
    hdrNear = frame:CreateFontString(nil, "OVERLAY")
    hdrAvail = frame:CreateFontString(nil, "OVERLAY")
end

function Suggest:Update(recompute)
    if not ns.db.suggest or not Data.ready or not ns.db.trackerShown then
        if frame then frame:Hide() end
        return
    end
    if not frame then create() end
    if recompute then compute() end
    local isAr = ns.GetLanguage() == "ar"
    for _, r in ipairs(rows) do r:Hide() end
    local y, n = -6, 0
    local function header(fs, key)
        ns.SetUIFont(fs, 13, "OUTLINE")
        fs:SetText(L(key))
        fs:SetTextColor(0.4, 0.85, 1)
        fs:ClearAllPoints()
        if isAr then fs:SetPoint("TOPRIGHT", -8, y) else fs:SetPoint("TOPLEFT", 8, y) end
        fs:Show()
        y = y - 20
    end
    local function row(questID, txt, r_, g_, b_, isActive, point)
        n = n + 1
        local r = rows[n] or makeRow(n)
        r.questID, r.isActive, r.point, r.label = questID, isActive, point, txt
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 8, y)
        r:SetPoint("TOPRIGHT", -8, y)
        r.text:SetText(txt)
        r.text:SetTextColor(r_, g_, b_)
        r.skip:SetShown(not isActive)
        r:Show()
        y = y - 19
    end

    -- nearby active quests
    local near = {}
    for id, d in pairs(nearSet) do near[#near + 1] = { id = id, d = d } end
    table.sort(near, function(a, b) return a.d < b.d end)
    if #near > 0 then
        header(hdrNear, "NEARBY_TITLE")
        for _, q in ipairs(near) do
            row(q.id, ("%s  |cff88ccff%dyd|r"):format(Data:QuestName(q.id) or "?", q.d), 0.4, 1, 0.5, true)
        end
        y = y - 4
    else
        hdrNear:Hide()
    end

    -- available quests
    if #available > 0 then
        header(hdrAvail, "AVAILABLE_TITLE")
        for i = 1, math.min(MAX_AVAILABLE, #available) do
            local q = available[i]
            local dtxt = q.dist < 99999 and ("  |cff88ccff%dyd|r"):format(q.dist) or ""
            row(q.id, ("[%d] %s%s"):format(q.level or 0, q.name or "?", dtxt), 1, 0.82, 0, false, q.point)
        end
    else
        hdrAvail:Hide()
    end

    if n == 0 then frame:Hide() return end
    frame:SetHeight(-y + 4)
    frame:SetScale(ns.db.scale or 1)
    frame:Show()
end

function Suggest:OnInit()
    for _, ev in ipairs({ "QUEST_TURNED_IN", "QUEST_ACCEPTED", "QUEST_REMOVED", "PLAYER_LEVEL_UP" }) do
        ns:On(ev, function() Data:InvalidateAvailable() end)
    end
    local t = 0
    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function(_, e)
        t = t + e
        if t > 3 then t = 0 Suggest:Update(true) end
    end)
end

function Suggest:OnRefresh() self:Update(true) end
