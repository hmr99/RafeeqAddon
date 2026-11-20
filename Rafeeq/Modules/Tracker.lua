local _, ns = ...
local L = ns.L

local Tracker = ns:NewModule("Tracker")
ns.Tracker = Tracker

local WIDTH = 270
local PAD = 8
local MAX_LINES = 60
local GAME_FONT = STANDARD_TEXT_FONT

---------------------------------------------------------------------------
-- API compatibility (modern C_QuestLog first, classic globals as fallback)
---------------------------------------------------------------------------
local Q = {}

function Q.NumEntries()
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
        return (C_QuestLog.GetNumQuestLogEntries())
    end
    return (GetNumQuestLogEntries())
end

-- returns { title, questID, level, isHeader, isComplete(bool), isFailed(bool), logIndex }
function Q.Entry(i)
    if C_QuestLog and C_QuestLog.GetInfo then
        local info = C_QuestLog.GetInfo(i)
        if not info then return nil end
        if info.isHidden then return nil end
        local e = {
            title = info.title, questID = info.questID, isHeader = info.isHeader,
            level = info.difficultyLevel or info.level, logIndex = i,
        }
        if not e.isHeader and e.questID then
            local ready = C_QuestLog.ReadyForTurnIn and C_QuestLog.ReadyForTurnIn(e.questID)
            local complete = C_QuestLog.IsComplete and C_QuestLog.IsComplete(e.questID)
            e.isComplete = (ready or complete) and true or false
            e.isFailed = C_QuestLog.IsFailed and C_QuestLog.IsFailed(e.questID) or false
        end
        return e
    end
    local title, level, _, isHeader, _, isComplete, _, questID = GetQuestLogTitle(i)
    if not title then return nil end
    return {
        title = title, questID = questID, level = level, isHeader = isHeader,
        isComplete = isComplete == 1, isFailed = isComplete == -1, logIndex = i,
    }
end

-- returns array of { text, finished }
function Q.Objectives(e)
    if C_QuestLog and C_QuestLog.GetQuestObjectives and e.questID then
        local objs = C_QuestLog.GetQuestObjectives(e.questID)
        if objs then return objs end
    end
    local out = {}
    if GetNumQuestLeaderBoards then
        for j = 1, GetNumQuestLeaderBoards(e.logIndex) or 0 do
            local text, _, finished = GetQuestLogLeaderBoard(j, e.logIndex)
            out[#out + 1] = { text = text, finished = finished }
        end
    end
    return out
end

function Q.RewardXP(e)
    if not GetQuestLogRewardXP or not e.questID then return 0 end
    local ok, xp = pcall(GetQuestLogRewardXP, e.questID)
    if ok and xp and xp > 0 then return xp end
    -- classic-style: needs the entry selected
    if SelectQuestLogEntry then
        local prev = GetQuestLogSelection and GetQuestLogSelection()
        SelectQuestLogEntry(e.logIndex)
        ok, xp = pcall(GetQuestLogRewardXP)
        if prev then SelectQuestLogEntry(prev) end
        if ok and xp then return xp end
    end
    return 0
end

ns.QuestAPI = Q

local function fmtNum(n)
    if BreakUpLargeNumbers then return BreakUpLargeNumbers(n) end
    return tostring(n)
end

local function diffColor(level)
    if level and GetQuestDifficultyColor then
        local c = GetQuestDifficultyColor(level)
        if c then return c.r, c.g, c.b end
    end
    return 1, 0.82, 0
end

---------------------------------------------------------------------------
-- Frame
---------------------------------------------------------------------------
local frame, header, title, count, footer, footerHint, etaLine
local rows, lines = {}, {}

local function savePosition()
    local p, _, rp, x, y = frame:GetPoint()
    ns.db.point = { p, rp, x, y }
end

local function applyPosition()
    frame:ClearAllPoints()
    local pt = ns.db.point
    if pt then
        frame:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4])
    else
        frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -80, -220)
    end
end

local function createFrame()
    frame = CreateFrame("Frame", "RafeeqTracker", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame:SetSize(WIDTH, 60)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetFrameStrata("LOW")
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
        })
        frame:SetBackdropColor(0.05, 0.06, 0.08, 0.72)
        frame:SetBackdropBorderColor(0.2, 0.75, 1, 0.35)
    end

    header = CreateFrame("Button", nil, frame)
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:SetHeight(24)
    header:RegisterForDrag("LeftButton")
    header:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    header:SetScript("OnDragStart", function()
        if not ns.db.locked then frame:StartMoving() end
    end)
    header:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        savePosition()
    end)
    header:SetScript("OnClick", function(_, btn)
        if btn == "RightButton" then
            if ns.OpenOptions then ns.OpenOptions() end
        else
            ns.char.allCollapsed = not ns.char.allCollapsed
            Tracker:Update()
        end
    end)

    local bar = header:CreateTexture(nil, "BACKGROUND")
    bar:SetAllPoints()
    bar:SetColorTexture(0.2, 0.75, 1, 0.12)

    title = header:CreateFontString(nil, "OVERLAY")
    -- quick language switch on the header: shows the language you'd switch TO
    header.lang = CreateFrame("Button", nil, header)
    header.lang:SetSize(26, 18)
    header.lang.text = header.lang:CreateFontString(nil, "OVERLAY")
    header.lang.text:SetPoint("CENTER")
    local lbg = header.lang:CreateTexture(nil, "BACKGROUND")
    lbg:SetAllPoints()
    lbg:SetColorTexture(0.2, 0.75, 1, 0.25)
    header.lang:SetScript("OnClick", function()
        ns.SetLanguage(ns.GetLanguage() == "ar" and "en" or "ar")
    end)
    header.lang:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Language / " .. ns.Shaper.Shape("اللغة"))
        GameTooltip:Show()
    end)
    header.lang:SetScript("OnLeave", function() GameTooltip:Hide() end)

    count = header:CreateFontString(nil, "OVERLAY")
    count:SetFont(GAME_FONT, 12, "OUTLINE")
    count:SetTextColor(0.7, 0.85, 1)

    footer = frame:CreateFontString(nil, "OVERLAY")
    footer:SetPoint("BOTTOMLEFT", PAD, 6)
    footer:SetPoint("BOTTOMRIGHT", -PAD, 6)
    footer:SetWordWrap(false)

    footerHint = frame:CreateFontString(nil, "OVERLAY")
    footerHint:SetPoint("BOTTOMLEFT", footer, "TOPLEFT", 0, 2)
    footerHint:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, 2)
    footerHint:SetWordWrap(false)
    footerHint:SetTextColor(1, 0.85, 0.2)

    etaLine = frame:CreateFontString(nil, "OVERLAY")
    etaLine:SetWordWrap(false)
    etaLine:SetTextColor(0.75, 0.75, 0.75)

    applyPosition()
end

local function getRow(i)
    local r = rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, frame)
    r:SetHeight(18)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r.text = r:CreateFontString(nil, "OVERLAY")
    r.text:SetFont(GAME_FONT, 13, "OUTLINE")
    r.text:SetPoint("LEFT", 0, 0)
    r.text:SetJustifyH("LEFT")
    r.text:SetWordWrap(false)
    r.xp = r:CreateFontString(nil, "OVERLAY")
    r.xp:SetFont(GAME_FONT, 11, "OUTLINE")
    r.xp:SetPoint("RIGHT", 0, 0)
    r.xp:SetTextColor(0.55, 0.8, 1)
    r.text:SetPoint("RIGHT", r.xp, "LEFT", -4, 0)
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.06)
    r:SetScript("OnClick", function(self, btn)
        local id = self.questID
        if not id then return end
        if btn == "RightButton" then
            if QuestMapFrame_OpenToQuestDetails then
                QuestMapFrame_OpenToQuestDetails(id)
            elseif ToggleQuestLog then
                ToggleQuestLog()
            end
        elseif IsShiftKeyDown() then
            if ns.Data and ns.Data.ready and ns.Nav then
                ns.Nav:SetQuest(id)
            elseif C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
                C_SuperTrack.SetSuperTrackedQuestID(id)
            end
        else
            ns.char.collapsed[id] = not ns.char.collapsed[id] or nil
            Tracker:Update()
        end
    end)
    rows[i] = r
    return r
end

local function getLine(i)
    local l = lines[i]
    if l then return l end
    l = frame:CreateFontString(nil, "OVERLAY")
    l:SetJustifyH("LEFT")
    l:SetWordWrap(true)
    lines[i] = l
    return l
end

---------------------------------------------------------------------------
-- Rendering
---------------------------------------------------------------------------
function Tracker:Update()
    if not frame then return end
    if not ns.db.trackerShown then frame:Hide() return end
    frame:Show()
    frame:SetScale(ns.db.scale or 1)

    local isAr = ns.GetLanguage() == "ar"
    ns.SetUIFont(title, isAr and 15 or 13, "OUTLINE")
    title:ClearAllPoints()
    count:ClearAllPoints()
    if isAr then
        title:SetPoint("RIGHT", header, "RIGHT", -PAD, 0)
        count:SetPoint("LEFT", header, "LEFT", PAD, 0)
    else
        title:SetPoint("LEFT", header, "LEFT", PAD, 0)
        count:SetPoint("RIGHT", header, "RIGHT", -PAD, 0)
    end
    title:SetText(L("TRACKER_TITLE"))
    header.lang:ClearAllPoints()
    if isAr then
        header.lang:SetPoint("LEFT", count, "RIGHT", 6, 0)
        header.lang.text:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
        header.lang.text:SetText("EN")
    else
        header.lang:SetPoint("RIGHT", count, "LEFT", -6, 0)
        header.lang.text:SetFont(ns.ARABIC_FONT, 12, "OUTLINE")
        header.lang.text:SetText(ns.Shaper.Shape("ع"))
    end
    title:SetTextColor(0.4, 0.85, 1)

    for _, r in ipairs(rows) do r:Hide() end
    for _, l in ipairs(lines) do l:Hide() end

    local y = -28
    local nRow, nLine, used = 0, 0, 0
    local quests, readyXP = 0, 0
    local width = WIDTH - PAD * 2

    local function addLine(text, font, size, r, g, b, justify, indent)
        nLine = nLine + 1
        local l = getLine(nLine)
        l:SetFont(font, size, "OUTLINE")
        l:SetWidth(width - (indent or 0))
        l:ClearAllPoints()
        if justify == "RIGHT" then
            l:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD - (indent or 0), y)
        else
            l:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + (indent or 0), y)
        end
        l:SetJustifyH(justify or "LEFT")
        l:SetText(text)
        l:SetTextColor(r, g, b)
        l:Show()
        y = y - math.max(l:GetStringHeight(), size) - 2
        used = used + 1
    end

    local collapsedAll = ns.char.allCollapsed
    local n = Q.NumEntries() or 0
    for i = 1, n do
        local e = Q.Entry(i)
        if e and not e.isHeader and e.questID then
            quests = quests + 1
            local xp = ns.db.showXP and Q.RewardXP(e) or 0
            if e.isComplete then readyXP = readyXP + xp end

            if not collapsedAll and used < MAX_LINES then
                nRow = nRow + 1
                local row = getRow(nRow)
                row.questID = e.questID
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, y)
                row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, y)
                local r, g, b = diffColor(e.level)
                local mark = ns.char.collapsed[e.questID] and "+ " or ""
                if ns.Suggest and ns.Suggest:IsNear(e.questID) then mark = "|cff44ff66>>|r " .. mark end
                row.text:SetText(("%s[%d] %s"):format(mark, e.level or 0, e.title or "?"))
                row.text:SetTextColor(r, g, b)
                row.xp:SetText(xp > 0 and (fmtNum(xp) .. " xp") or "")
                row:Show()
                y = y - 18
                used = used + 1

                if not ns.char.collapsed[e.questID] then
                    if e.isFailed then
                        addLine(L("FAILED"), isAr and ns.ARABIC_FONT or GAME_FONT, 12, 1, 0.3, 0.3,
                            isAr and "RIGHT" or "LEFT", 10)
                    elseif e.isComplete then
                        addLine(L("READY"), isAr and ns.ARABIC_FONT or GAME_FONT, 12, 0.3, 1, 0.4,
                            isAr and "RIGHT" or "LEFT", 10)
                    else
                        for _, o in ipairs(Q.Objectives(e)) do
                            if o.text and o.text ~= "" then
                                local cr, cg, cb = 0.85, 0.85, 0.85
                                if o.finished then cr, cg, cb = 0.45, 0.85, 0.45 end
                                addLine("- " .. o.text, GAME_FONT, 12, cr, cg, cb, "LEFT", 10)
                            end
                        end
                    end
                end
                y = y - 3
            end
        end
    end

    count:SetText(("%d/%d"):format(quests, (MAX_QUESTS or C_QuestLog and C_QuestLog.GetMaxNumQuestsCanAccept
        and C_QuestLog.GetMaxNumQuestsCanAccept()) or 20))

    if quests == 0 and not collapsedAll then
        addLine(L("NO_QUESTS"), isAr and ns.ARABIC_FONT or GAME_FONT, 12, 0.6, 0.6, 0.6,
            isAr and "RIGHT" or "LEFT", 0)
    end

    -- footer: XP waiting in completed quests
    footerHint:Hide()
    if ns.db.showXP and readyXP > 0 then
        ns.SetUIFont(footer, 12, "OUTLINE")
        footer:SetJustifyH(isAr and "RIGHT" or "LEFT")
        footer:SetText(L("READY_XP", fmtNum(readyXP)))
        footer:SetTextColor(0.55, 0.8, 1)
        footer:Show()
        y = y - 20
        local need = (UnitXPMax("player") or 0) - (UnitXP("player") or 0)
        if need > 0 and readyXP >= need then
            ns.SetUIFont(footerHint, 12, "OUTLINE")
            footerHint:SetJustifyH(isAr and "RIGHT" or "LEFT")
            footerHint:SetText(L("LEVEL_UP_HINT"))
            footerHint:Show()
            y = y - 18
        end
    else
        footer:Hide()
    end

    -- time to level
    etaLine:Hide()
    local secs, perHour
    if ns.QoL then secs, perHour = ns.QoL:TimeToLevel() end
    if ns.db.showETA and secs and perHour and UnitLevel("player") < (GetMaxPlayerLevel and GetMaxPlayerLevel() or 60) then
        ns.SetUIFont(etaLine, 11, "OUTLINE")
        etaLine:ClearAllPoints()
        local anchor = footerHint:IsShown() and footerHint or (footer:IsShown() and footer or nil)
        if anchor then
            etaLine:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 2)
            etaLine:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", 0, 2)
        else
            etaLine:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, 6)
            etaLine:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, 6)
        end
        etaLine:SetJustifyH(isAr and "RIGHT" or "LEFT")
        local h, m = math.floor(secs / 3600), math.floor(secs % 3600 / 60)
        etaLine:SetText(L("ETA", h, m, fmtNum(math.floor(perHour))))
        etaLine:Show()
        y = y - 16
    end

    frame:SetHeight(math.max(-y + 6, 30))
end

-- coalesce bursts of quest events into one redraw
local pending = false
local function queueUpdate()
    if pending then return end
    pending = true
    C_Timer.After(0.15, function()
        pending = false
        Tracker:Update()
    end)
end

---------------------------------------------------------------------------
-- Default tracker hiding
---------------------------------------------------------------------------
local hiddenParent = CreateFrame("Frame")
hiddenParent:Hide()
local blizzFrames = { "ObjectiveTrackerFrame", "QuestWatchFrame", "WatchFrame" }

local function applyBlizzard()
    for _, name in ipairs(blizzFrames) do
        local f = _G[name]
        if f then
            if ns.db.hideBlizzard then
                f:SetParent(hiddenParent)
            elseif f:GetParent() == hiddenParent then
                f:SetParent(UIParent)
            end
        end
    end
end

---------------------------------------------------------------------------
function Tracker:OnInit()
    createFrame()
    for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "QUEST_LOG_UPDATE", "QUEST_WATCH_UPDATE",
        "UNIT_QUEST_LOG_CHANGED", "QUEST_TURNED_IN", "QUEST_ACCEPTED", "QUEST_REMOVED",
        "PLAYER_LEVEL_UP", "PLAYER_XP_UPDATE" }) do
        pcall(ns.On, ns, ev, queueUpdate)
    end
    ns:On("PLAYER_ENTERING_WORLD", applyBlizzard)
end

function Tracker:OnRefresh()
    applyPosition()
    applyBlizzard()
    self:Update()
end
