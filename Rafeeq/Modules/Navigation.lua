-- Rafeeq: navigation arrow. Points to a fixed spot, or follows a quest
-- (nearest unfinished objective spawn, then the turn-in NPC once complete).
local _, ns = ...
local L = ns.L
local Data = ns.Data

local Nav = ns:NewModule("Navigation")
ns.Nav = Nav

local atan2, pi = math.atan2 or math.atan, math.pi
local target -- { mode="point"|"quest", map,x,y,label, questID }
local frame, arrow, dist, label, hint, banner
local elapsed = 0

---------------------------------------------------------------------------
-- Which objective points are still needed for a quest
---------------------------------------------------------------------------
local function unfinishedNames(questID)
    local names = {}
    local objs = C_QuestLog and C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(questID)
    for _, o in ipairs(objs or {}) do
        if not o.finished and o.text then names[#names + 1] = o.text:lower() end
    end
    return names
end

function Nav:QuestPoints(questID)
    local complete = C_QuestLog and (C_QuestLog.ReadyForTurnIn and C_QuestLog.ReadyForTurnIn(questID)
        or C_QuestLog.IsComplete and C_QuestLog.IsComplete(questID))
    if complete then return Data:FinisherPoints(questID), true end
    local need = unfinishedNames(questID)
    local pts = {}
    for _, obj in ipairs(Data:QuestObjectives(questID)) do
        local wanted = #need == 0
        if obj.name then
            local n = obj.name:lower()
            for _, t in ipairs(need) do
                if t:find(n, 1, true) then wanted = true break end
            end
        else
            wanted = true
        end
        if wanted then for _, p in ipairs(obj.points) do pts[#pts + 1] = p end end
    end
    return pts, false
end

---------------------------------------------------------------------------
function Nav:SetPoint(map, x, y, text)
    arrivedKey = nil
    target = { mode = "point", map = map, x = x, y = y, label = text }
    self:Show()
end

function Nav:SetQuest(questID)
    arrivedKey = nil
    target = { mode = "quest", questID = questID }
    self:Recompute()
    self:Show()
end

function Nav:Clear()
    target = nil
    if frame then frame:Hide() end
end

function Nav:Target() return target end

function Nav:Recompute()
    if not target or target.mode ~= "quest" then return end
    local pts, turnIn = self:QuestPoints(target.questID)
    local p = Data:Nearest(pts)
    local qname = Data:QuestName(target.questID) or ("#" .. target.questID)
    if p then
        target.map, target.x, target.y = p.map, p.x, p.y
        target.label = (turnIn and "> " or "") .. qname
    else
        target.map = nil
        target.label = qname
    end
end

local function create()
    frame = CreateFrame("Frame", "RafeeqArrow", UIParent)
    frame:SetSize(64, 84)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetScript("OnDragStart", function(self) if not ns.db.locked then self:StartMoving() end end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        ns.db.arrowPoint = { p, rp, x, y }
    end)
    frame:SetScript("OnMouseUp", function(_, btn) if btn == "RightButton" then Nav:Clear() end end)

    arrow = frame:CreateTexture(nil, "ARTWORK")
    arrow:SetSize(48, 48)
    arrow:SetPoint("TOP", 0, 0)
    arrow:SetTexture("Interface\\Minimap\\MinimapArrow")

    dist = frame:CreateFontString(nil, "OVERLAY")
    dist:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
    dist:SetPoint("TOP", arrow, "BOTTOM", 0, -2)

    label = frame:CreateFontString(nil, "OVERLAY")
    label:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    label:SetPoint("TOP", dist, "BOTTOM", 0, -2)
    label:SetTextColor(1, 0.82, 0)
    label:SetWidth(220)
    label:SetWordWrap(false)

    -- turn hint for auto-run: "turn left / right / straight ahead / behind you"
    hint = frame:CreateFontString(nil, "OVERLAY")
    hint:SetPoint("TOP", label, "BOTTOM", 0, -3)

    -- big on-screen alert (arrival / drift); our own frame so Arabic renders
    banner = CreateFrame("Frame", "RafeeqNavBanner", UIParent)
    banner:SetSize(600, 40)
    banner:SetPoint("TOP", UIParent, "TOP", 0, -200)
    banner.text = banner:CreateFontString(nil, "OVERLAY")
    banner.text:SetPoint("CENTER")
    banner:Hide()

    local pt = ns.db.arrowPoint
    if pt then frame:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4])
    else frame:SetPoint("TOP", UIParent, "TOP", 0, -140) end

    frame:SetScript("OnUpdate", function(_, e)
        elapsed = elapsed + e
        if elapsed < 0.05 then return end
        elapsed = 0
        Nav:Tick()
    end)
    frame:Hide()
end

local function playAlert(kind)
    if not PlaySound then return end
    local kit = SOUNDKIT or {}
    local id = kind == "arrive" and (kit.READY_CHECK or 8960) or (kit.IG_QUEST_LOG_ABANDON_QUEST or 846)
    pcall(PlaySound, id, "Master")
end

local bannerUntil = 0
local function showBanner(key, r, g, b)
    if not banner then return end
    ns.SetUIFont(banner.text, 22, "OUTLINE")
    banner.text:SetText(L(key))
    banner.text:SetTextColor(r, g, b)
    banner:Show()
    bannerUntil = GetTime() + 3
end

-- normalise to -pi..pi ; positive = target is to your LEFT (facing is counter-clockwise)
local function normAngle(a)
    a = (a + pi) % (2 * pi) - pi
    return a
end

local function hintKey(rel)
    local a = math.abs(rel)
    if a < 0.35 then return "NAV_AHEAD", 0.3, 1, 0.4 end          -- within ~20 degrees
    if a > 2.6 then return "NAV_BEHIND", 1, 0.3, 0.3 end           -- beyond ~150 degrees
    if rel > 0 then return "NAV_LEFT", 1, 0.85, 0.3 end
    return "NAV_RIGHT", 1, 0.85, 0.3
end

local function isMoving()
    if GetUnitSpeed then
        local ok, speed = pcall(GetUnitSpeed, "player")
        if ok and type(speed) == "number" then return speed > 0 end
    end
    return IsPlayerMoving and IsPlayerMoving() or false
end

local arrivedKey      -- point we already announced
local driftSince, lastDriftAlert = nil, -99

local recomputeTimer = 0
function Nav:Tick()
    if not target then frame:Hide() return end
    recomputeTimer = recomputeTimer + 0.05
    if target.mode == "quest" and recomputeTimer > 2 then
        recomputeTimer = 0
        self:Recompute()
    end
    label:SetText(target.label or "")
    if not target.map then
        arrow:Hide()
        dist:SetText("?")
        return
    end
    local _, _, _, pc, pwx, pwy = Data:Player()
    local tc, twx, twy = Data:World(target.map, target.x, target.y)
    local d = Data:Distance(pc, pwx, pwy, tc, twx, twy)
    if not d then
        arrow:Hide()
        dist:SetText("--")
        return
    end
    arrow:Show()
    -- world X = north, world Y = west; facing is radians CCW from north
    local bearing = atan2(twy - pwy, twx - pwx)
    local facing = GetPlayerFacing and GetPlayerFacing() or 0
    local rel
    if facing then
        rel = normAngle(bearing - facing)
        arrow:SetRotation(rel)
        -- colour: green when roughly ahead, red when behind
        local t = math.abs(rel) / pi
        arrow:SetVertexColor(t * 2 > 1 and 1 or t * 2, t * 2 > 1 and (2 - t * 2) or 1, 0.1)
    end
    dist:SetText(("%d yd"):format(d))

    -- turn hint
    if rel and ns.db.turnHints then
        local key, r, g, b = hintKey(rel)
        ns.SetUIFont(hint, 14, "OUTLINE")
        hint:SetText(L(key))
        hint:SetTextColor(r, g, b)
        hint:Show()
    else
        hint:Hide()
    end

    -- arrival alert: once per target point
    local key = ("%s:%.1f:%.1f"):format(target.map, target.x, target.y)
    if ns.db.arrivalAlert and d <= (ns.db.arrivalYards or 30) and arrivedKey ~= key then
        arrivedKey = key
        playAlert("arrive")
        showBanner("NAV_ARRIVED", 0.3, 1, 0.4)
    end

    -- drift alert: running for 2s+ while the target is more than ~60 degrees off
    local now = GetTime()
    if ns.db.driftAlert and rel and d > (ns.db.arrivalYards or 30) and isMoving() and math.abs(rel) > 1.05 then
        driftSince = driftSince or now
        if now - driftSince > 2 and now - lastDriftAlert > 6 then
            lastDriftAlert = now
            playAlert("drift")
            showBanner("NAV_DRIFT", 1, 0.6, 0.2)
        end
    else
        driftSince = nil
    end
    if banner and banner:IsShown() and now > bannerUntil then banner:Hide() end

    if target.mode == "point" and d < 8 then self:Clear() end
end

function Nav:Show()
    if not frame then create() end
    frame:Show()
end

function Nav:OnInit()
    -- quest finished or turned in -> move on
    ns:On("QUEST_TURNED_IN", function(_, questID)
        if target and target.mode == "quest" and target.questID == questID then Nav:Clear() end
    end)
    ns:On("QUEST_LOG_UPDATE", function()
        if target and target.mode == "quest" then recomputeTimer = 99 end
    end)
end
