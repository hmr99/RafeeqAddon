-- Rafeeq: objective guide card.
-- Sits under the guide arrow while it follows a quest and says, in the player's language,
-- exactly what to do: who to kill, what to collect and who drops it, what to use, or who to
-- turn the quest in to - with a 3D model of the mob or the item's icon and live progress.
local _, ns = ...
local L = ns.L
local Data = ns.Data

local Guide = ns:NewModule("Guide")
ns.Guide = Guide

local WIDTH = 310
local MAX_STEPS = 4
local GAME_FONT = STANDARD_TEXT_FONT

local card, title, areaLine
local steps = {}
local currentQuest
local elapsed = 0

---------------------------------------------------------------------------
-- Build the steps for a quest from QuestieDB + the live quest log
---------------------------------------------------------------------------
local function liveObjectives(questID)
    local out = {}
    local objs = C_QuestLog and C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(questID)
    for _, o in ipairs(objs or {}) do
        if o.text and o.text ~= "" then out[#out + 1] = { text = o.text, finished = o.finished } end
    end
    return out
end

-- "Kobold Vermin slain: 4/10" -> "4/10"
local function progressOf(text)
    return text and text:match("(%d+%s*/%s*%d+)%s*$")
end

local function matchLive(name, live)
    if not name then return nil end
    local n = name:lower()
    for _, o in ipairs(live) do
        if o.text:lower():find(n, 1, true) then return o end
    end
end

local function namesOf(ids, getter, max)
    local out, seen = {}, {}
    for _, id in ipairs(ids or {}) do
        local n = getter(Data, id)
        if n and not seen[n] then
            seen[n] = true
            out[#out + 1] = n
            if #out >= (max or 3) then break end
        end
    end
    return table.concat(out, ", ")
end

local function isComplete(questID)
    if not C_QuestLog then return false end
    return (C_QuestLog.ReadyForTurnIn and C_QuestLog.ReadyForTurnIn(questID))
        or (C_QuestLog.IsComplete and C_QuestLog.IsComplete(questID)) or false
end

-- returns list of { verb=key, names=, progress=, done=, npc=, icon=, subVerb=key, subNames= }
function Guide:Steps(questID)
    local list = {}
    if isComplete(questID) then
        local who = Data:FinisherName(questID)
        local _, npc = Data:FinisherName(questID)
        list[1] = { verb = "GUIDE_TURNIN", names = who or "?", npc = npc,
            icon = "Interface\\GossipFrame\\ActiveQuestIcon" }
        return list
    end
    local live = liveObjectives(questID)
    local seen = {}
    for _, obj in ipairs(Data:QuestObjectives(questID)) do
        local key = obj.kind .. ":" .. tostring(obj.id)
        if not seen[key] then
            seen[key] = true
            local lo = matchLive(obj.name, live)
            local step = { names = obj.name or "?", progress = lo and progressOf(lo.text), done = lo and lo.finished }
            if obj.kind == "kill" then
                step.verb, step.npc = "GUIDE_KILL", obj.id
                step.icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"
            elseif obj.kind == "object" then
                step.verb = "GUIDE_USE"
                step.icon = "Interface\\Icons\\INV_Misc_Gear_01"
            else -- loot
                step.verb = "GUIDE_COLLECT"
                step.icon = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(obj.id))
                    or (GetItemIcon and GetItemIcon(obj.id)) or "Interface\\Icons\\INV_Misc_Bag_08"
                if obj.sources and #obj.sources > 0 then
                    step.subVerb, step.subNames = "GUIDE_DROPS", namesOf(obj.sources, Data.NpcName, 3)
                    step.npc = obj.sources[1]
                elseif obj.objSources and #obj.objSources > 0 then
                    step.subVerb, step.subNames = "GUIDE_FROM_OBJ", namesOf(obj.objSources, Data.ObjectName, 2)
                end
            end
            list[#list + 1] = step
        end
    end
    if #list == 0 then
        -- no QuestieDB detail: fall back to the quest log's own objective lines
        for _, o in ipairs(live) do
            list[#list + 1] = { verb = "GUIDE_GOAL", names = o.text, done = o.finished,
                icon = "Interface\\GossipFrame\\AvailableQuestIcon" }
        end
        if #list == 0 then
            list[1] = { verb = "GUIDE_NO_DATA", names = "", icon = "Interface\\GossipFrame\\AvailableQuestIcon" }
        end
    end
    -- unfinished steps first
    table.sort(list, function(a, b) return (a.done and 1 or 0) < (b.done and 1 or 0) end)
    return list
end

---------------------------------------------------------------------------
-- UI
---------------------------------------------------------------------------
local function fontFor(fs, size)
    ns.SetUIFont(fs, size, "OUTLINE")
end

local function makeStep(i)
    local r = CreateFrame("Frame", nil, card)
    r:SetSize(WIDTH - 16, 56)
    r.iconBg = r:CreateTexture(nil, "BACKGROUND")
    r.iconBg:SetSize(50, 50)
    r.iconBg:SetColorTexture(0, 0, 0, 0.55)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(40, 40)
    -- 3D model of the mob (PlayerModel); falls back to the icon when the client has no model
    r.model = CreateFrame("PlayerModel", nil, r)
    r.model:SetSize(50, 50)
    r.verb = r:CreateFontString(nil, "OVERLAY")
    r.names = r:CreateFontString(nil, "OVERLAY")
    r.names:SetFont(GAME_FONT, 13, "OUTLINE")
    r.sub = r:CreateFontString(nil, "OVERLAY")
    r.subNames = r:CreateFontString(nil, "OVERLAY")
    r.subNames:SetFont(GAME_FONT, 12, "OUTLINE")
    for _, fs in ipairs({ r.verb, r.names, r.sub, r.subNames }) do fs:SetWordWrap(true) end
    steps[i] = r
    return r
end

local function create()
    card = CreateFrame("Frame", "RafeeqGuide", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    card:SetWidth(WIDTH)
    card:SetFrameStrata("MEDIUM")
    if card.SetBackdrop then
        card:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        card:SetBackdropColor(0.04, 0.06, 0.09, 0.85)
        card:SetBackdropBorderColor(0.95, 0.76, 0.3, 0.55)
    end
    title = card:CreateFontString(nil, "OVERLAY")
    title:SetFont(GAME_FONT, 14, "OUTLINE")
    title:SetTextColor(1, 0.82, 0)
    title:SetWordWrap(false)
    areaLine = card:CreateFontString(nil, "OVERLAY")
    areaLine:SetWordWrap(true)
    card:Hide()
    -- OnUpdate never runs on a hidden frame, so the card is driven by its own (always shown) ticker
    local ticker = CreateFrame("Frame")
    ticker:SetScript("OnUpdate", function(_, e)
        elapsed = elapsed + e
        if elapsed > 0.5 then elapsed = 0 Guide:Refresh() end
    end)
end

local function anchorCard()
    card:ClearAllPoints()
    if RafeeqArrow then
        card:SetPoint("TOP", RafeeqArrow, "BOTTOM", 0, -6)
    else
        card:SetPoint("TOP", UIParent, "TOP", 0, -240)
    end
end

local function setModel(r, npc)
    r.model:Hide()
    if not npc or not r.model.SetCreature then return false end
    local ok = pcall(r.model.SetCreature, r.model, npc)
    if not ok then return false end
    if r.model.SetPortraitZoom then pcall(r.model.SetPortraitZoom, r.model, 0.6) end
    r.model:Show()
    return true
end

function Guide:Refresh()
    if not card then return end
    local t = ns.Nav and ns.Nav:Target()
    if not ns.db.guideCard or not t or t.mode ~= "quest" or not Data.ready then
        card:Hide()
        currentQuest = nil
        return
    end
    currentQuest = t.questID
    anchorCard()
    local isAr = ns.GetLanguage() == "ar"
    local just = isAr and "RIGHT" or "LEFT"
    local pad = 8

    title:ClearAllPoints()
    title:SetPoint("TOPLEFT", pad, -8)
    title:SetPoint("TOPRIGHT", -pad, -8)
    title:SetJustifyH(just)
    title:SetText(Data:QuestName(t.questID) or "?")

    local y = -30
    local list = self:Steps(t.questID)
    for i = 1, MAX_STEPS do
        local r = steps[i]
        local s = list[i]
        if not s then
            if r then r:Hide() end
        else
            r = r or makeStep(i)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", card, "TOPLEFT", pad, y)
            -- picture side follows reading direction
            r.iconBg:ClearAllPoints()
            if isAr then r.iconBg:SetPoint("TOPRIGHT", 0, 0) else r.iconBg:SetPoint("TOPLEFT", 0, 0) end
            r.icon:ClearAllPoints()
            r.icon:SetPoint("CENTER", r.iconBg, "CENTER")
            r.model:ClearAllPoints()
            r.model:SetPoint("CENTER", r.iconBg, "CENTER")
            local hasModel = ns.db.guideModels and setModel(r, s.npc)
            r.icon:SetTexture(s.icon)
            r.icon:SetShown(not hasModel)

            local textW = WIDTH - 16 - 58
            local function place(fs, prev, gap)
                fs:ClearAllPoints()
                fs:SetWidth(textW)
                fs:SetJustifyH(just)
                if prev then
                    fs:SetPoint("TOP", prev, "BOTTOM", 0, -(gap or 1))
                elseif isAr then
                    fs:SetPoint("TOPRIGHT", r, "TOPRIGHT", -58, 0)
                else
                    fs:SetPoint("TOPLEFT", r, "TOPLEFT", 58, 0)
                end
            end

            fontFor(r.verb, 14)
            ns.SetLText(r.verb, textW, s.verb)
            if s.done then r.verb:SetTextColor(0.45, 0.85, 0.45) else r.verb:SetTextColor(0.4, 0.85, 1) end
            place(r.verb)

            local names = s.names or ""
            if s.progress then names = names .. "  (" .. s.progress .. ")" end
            if s.done then names = names .. "  |cff66ff66OK|r" end
            r.names:SetText(names)
            r.names:SetTextColor(1, 1, 1)
            place(r.names, r.verb)

            local h = r.verb:GetStringHeight() + r.names:GetStringHeight() + 4
            if s.subVerb and s.subNames and s.subNames ~= "" then
                fontFor(r.sub, 12)
                ns.SetLText(r.sub, textW, s.subVerb)
                r.sub:SetTextColor(0.75, 0.75, 0.75)
                place(r.sub, r.names, 3)
                r.subNames:SetText(s.subNames)
                r.subNames:SetTextColor(1, 0.82, 0)
                place(r.subNames, r.sub)
                r.sub:Show() r.subNames:Show()
                h = h + r.sub:GetStringHeight() + r.subNames:GetStringHeight() + 4
            else
                r.sub:Hide() r.subNames:Hide()
            end
            h = math.max(h, 52)
            r:SetHeight(h)
            r:Show()
            y = y - h - 6
        end
    end

    -- "you are there" line, driven by the arrow's distance
    local d = ns.Nav:Distance()
    if d and d <= (ns.db.areaYards or 40) then
        fontFor(areaLine, 13)
        ns.SetLText(areaLine, WIDTH - 2 * pad, isComplete(t.questID) and "GUIDE_AT_TURNIN" or "GUIDE_IN_AREA")
        areaLine:SetTextColor(0.4, 1, 0.5)
        areaLine:ClearAllPoints()
        areaLine:SetPoint("TOPLEFT", pad, y)
        areaLine:SetPoint("TOPRIGHT", -pad, y)
        areaLine:SetJustifyH(just)
        areaLine:Show()
        y = y - areaLine:GetStringHeight() - 6
    else
        areaLine:Hide()
    end

    card:SetHeight(-y + 4)
    card:SetScale(ns.db.scale or 1)
    card:Show()
end

function Guide:OnInit()
    create()
    ns:On("QUEST_LOG_UPDATE", function() if currentQuest then Guide:Refresh() end end)
end

function Guide:OnRefresh() self:Refresh() end
