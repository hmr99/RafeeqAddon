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
local arrivedKey      -- point we already announced (reset on every new target)
local bannerUntil = 0

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
---------------------------------------------------------------------------
-- In-world marker: Blizzard's diamond (user waypoint + super-track) follows the arrow's target.
-- Needs the CVar showInGameNavigation; we turn it on while the option is enabled.
---------------------------------------------------------------------------
local ourWaypoint      -- "map:x:y" of the waypoint we placed, nil when none
local function waypointAPI()
    return C_Map and C_Map.SetUserWaypoint and C_Map.ClearUserWaypoint and UiMapPoint
        and UiMapPoint.CreateFromCoordinates
end

-- MapWise (when installed) navigates with the same single user waypoint; while it does, the slot is
-- its own and Rafeeq neither places, clears nor re-super-tracks it.
local function mapwiseOwns()
    local B = ns.MapWiseBridge
    if not B then return false end
    local ok, owns = pcall(B.OwnsWaypoint, B)
    return ok and owns
end

local function clearWaypoint()
    if ourWaypoint and waypointAPI() and not mapwiseOwns() then pcall(C_Map.ClearUserWaypoint) end
    ourWaypoint = nil
end

local function syncWaypoint()
    if not ns.db.worldMarker or not waypointAPI() then
        clearWaypoint()
        return
    end
    if not target or not target.map then return end -- keep the last marker while we have no new spot
    if mapwiseOwns() then ourWaypoint = nil return end -- placed again once MapWise is done
    local key = ("%d:%.1f:%.1f"):format(target.map, target.x, target.y)
    if key == ourWaypoint then return end
    if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(target.map) then return end
    local ok = pcall(function()
        local point = UiMapPoint.CreateFromCoordinates(target.map, target.x / 100, target.y / 100)
        C_Map.SetUserWaypoint(point)
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
            C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        end
    end)
    if ok then ourWaypoint = key end
end
Nav.SyncWaypoint = syncWaypoint

-- The on-screen diamond needs three things to stay true: the CVar on, our waypoint still placed, and the
-- waypoint super-tracked. The game moves the super-track to a quest on its own (accepting a quest, a click in
-- its tracker) and other addons can clear the waypoint or the CVar; the pin then stays on the map and
-- minimap but the diamond is gone from the world. Checked about once a second, put back when lost.
local function keepDiamond()
    if not ns.db.worldMarker or not waypointAPI() then return end
    if mapwiseOwns() then ourWaypoint = nil return end
    if not ourWaypoint then
        if target and target.map then syncWaypoint() end -- MapWise finished: our diamond comes back
        return
    end
    if GetCVar and SetCVar and GetCVar("showInGameNavigation") ~= "1" then
        pcall(SetCVar, "showInGameNavigation", "1")
    end
    if C_Map.HasUserWaypoint and not C_Map.HasUserWaypoint() then
        ourWaypoint = nil
        syncWaypoint()
        return
    end
    local ST = C_SuperTrack
    if ST and ST.IsSuperTrackingUserWaypoint and ST.SetSuperTrackedUserWaypoint
        and not ST.IsSuperTrackingUserWaypoint() then
        pcall(ST.SetSuperTrackedUserWaypoint, true)
    end
end

-- tell the AzerothGPS bridge (if any) where we are heading
local function syncGPS()
    if ns.GPSBridge then pcall(ns.GPSBridge.Sync, ns.GPSBridge) end
end

-- the player picked a new target: offer it to MapWise (if installed and the option is on)
local function sendMapWise()
    if ns.MapWiseBridge and target then pcall(ns.MapWiseBridge.Send, ns.MapWiseBridge, target) end
end

function Nav:ApplyWorldMarkerSetting()
    if ns.db.worldMarker and SetCVar then pcall(SetCVar, "showInGameNavigation", "1") end
    if ns.db.worldMarker then syncWaypoint() else clearWaypoint() end
end

function Nav:SetPoint(map, x, y, text)
    arrivedKey = nil
    target = { mode = "point", map = map, x = x, y = y, label = text }
    sendMapWise()
    syncWaypoint()
    syncGPS()
    self:Show()
end

function Nav:SetQuest(questID)
    arrivedKey = nil
    target = { mode = "quest", questID = questID }
    if ns.char then ns.char.cardQuest, ns.char.cardClosed = questID, false end
    self:Recompute()
    sendMapWise()
    syncWaypoint()
    syncGPS()
    self:Show()
end

function Nav:Clear()
    target = nil
    lastDistance = nil
    clearWaypoint()
    if ns.GPSBridge then pcall(ns.GPSBridge.OnTargetCleared, ns.GPSBridge) end
    if ns.MapWiseBridge then pcall(ns.MapWiseBridge.OnTargetCleared, ns.MapWiseBridge) end
    if frame then frame:Hide() end
end

function Nav:Target() return target end

local lastDistance
function Nav:Distance() return lastDistance end

function Nav:Recompute()
    if not target or target.mode ~= "quest" then return end
    local pts, turnIn = self:QuestPoints(target.questID)
    local p = Data:Nearest(pts)
    if not p and pts[1] then
        -- you know where you are, but no point shares your continent: aim at one anyway so the
        -- arrow can say "another continent" and name the zone instead of "position unknown"
        local _, _, _, pc = Data:Player()
        if pc then p = pts[1] end
    end
    local qname = Data:QuestName(target.questID) or ("#" .. target.questID)
    target.noData = (#pts == 0)
    if p then
        target.map, target.x, target.y = p.map, p.x, p.y
        target.label = (turnIn and "> " or "") .. qname
        -- say which zone the target is in when it is not the one you are standing in
        local here = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        if here and here ~= p.map then
            local zone = Data:MapName(p.map)
            if zone then target.label = target.label .. " - " .. zone end
        end
    elseif target.noData then
        -- QuestieDB has no spawn/drop data for this objective: say where the quest is, not a guess
        target.map = nil
        local zone = Data:QuestZoneName(target.questID)
        target.label = zone and (qname .. " - " .. zone) or qname
    else
        -- points exist but your position is unknown right now (instance, loading): keep the last target
        target.label = (turnIn and "> " or "") .. qname
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
    -- own timer: the arrow frame (and its OnUpdate) may hide while the banner is up
    banner:SetScript("OnUpdate", function(self)
        if GetTime() > bannerUntil then self:Hide() end
    end)
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

local driftSince, lastDriftAlert = nil, -99

local recomputeTimer, diamondTimer = 0, 0
function Nav:Tick()
    if not target then frame:Hide() return end
    -- while AzerothGPS routes along the roads, our straight-line arrow would contradict it: hide it
    -- (the logic keeps running for the card, the diamond and the arrival alert)
    local guiding = (ns.GPSBridge and ns.GPSBridge:Guiding()) or (ns.MapWiseBridge and ns.MapWiseBridge:Guiding())
    frame:SetAlpha(guiding and 0 or 1)
    frame:EnableMouse(not guiding)
    recomputeTimer = recomputeTimer + 0.05
    diamondTimer = diamondTimer + 0.05
    if diamondTimer >= 1 then
        diamondTimer = 0
        keepDiamond()
    end
    if target.mode == "quest" and recomputeTimer > 2 then
        recomputeTimer = 0
        self:Recompute()
        syncWaypoint() -- the nearest objective changed -> move the diamond with it
        syncGPS()
    end
    label:SetText(target.label or "")
    local function noDirection(textKey)
        -- never leave a turn hint on screen when there is no direction to give
        arrow:Hide()
        dist:SetText("--")
        if textKey then
            ns.SetUIFont(hint, 13, "OUTLINE")
            hint:SetText(L(textKey))
            hint:SetTextColor(0.7, 0.7, 0.7)
            hint:Show()
        else
            hint:Hide()
        end
    end
    if not target.map then
        noDirection(target.noData and "NAV_NO_DATA" or "NAV_NO_POSITION")
        return
    end
    local _, _, _, pc, pwx, pwy = Data:Player()
    local tc, twx, twy = Data:World(target.map, target.x, target.y)
    local d = Data:Distance(pc, pwx, pwy, tc, twx, twy)
    lastDistance = d
    if not d then
        noDirection(pc and "NAV_OTHER_CONTINENT" or "NAV_NO_POSITION")
        return
    end
    -- quest objectives are an AREA, not a pin: once inside it, stop steering and say so
    local inArea = target.mode == "quest" and d <= (ns.db.areaYards or 40)
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
    if inArea then
        ns.SetUIFont(hint, 14, "OUTLINE")
        hint:SetText(L("NAV_IN_AREA"))
        hint:SetTextColor(0.4, 1, 0.5)
        hint:Show()
    elseif rel and ns.db.turnHints then
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
    local arriveAt = target.mode == "quest" and (ns.db.areaYards or 40) or (ns.db.arrivalYards or 30)
    -- in quest mode the nearest spawn keeps changing inside the area: announce the quest once
    if target.mode == "quest" then key = "q" .. tostring(target.questID) end
    if ns.db.arrivalAlert and d <= arriveAt and arrivedKey ~= key then
        arrivedKey = key
        playAlert("arrive")
        showBanner(target.mode == "quest" and "NAV_ARRIVED_QUEST" or "NAV_ARRIVED", 0.3, 1, 0.4)
    end

    -- drift alert: running for 2s+ while the target is more than ~60 degrees off
    local now = GetTime()
    if ns.db.driftAlert and not guiding and rel and not inArea and d > (ns.db.arrivalYards or 30) and isMoving() and math.abs(rel) > 1.05 then
        driftSince = driftSince or now
        if now - driftSince > 2 and now - lastDriftAlert > 6 then
            lastDriftAlert = now
            playAlert("drift")
            showBanner("NAV_DRIFT", 1, 0.6, 0.2)
        end
    else
        driftSince = nil
    end

    if target.mode == "point" and d < 8 then self:Clear() end
end

function Nav:Show()
    if not frame then create() end
    frame:Show()
end

function Nav:OnRefresh() self:ApplyWorldMarkerSetting() end

function Nav:OnInit()
    ns:On("PLAYER_LOGIN", function() Nav:ApplyWorldMarkerSetting() end)
    -- quest finished or turned in -> move on
    ns:On("QUEST_TURNED_IN", function(_, questID)
        if target and target.mode == "quest" and target.questID == questID then Nav:Clear() end
    end)
    -- quest abandoned (or otherwise dropped from the log) -> stop guiding to it
    ns:On("QUEST_REMOVED", function(_, questID)
        if target and target.mode == "quest" and target.questID == questID then
            Nav:Clear()
            if ns.Guide and ns.Guide.Refresh then pcall(ns.Guide.Refresh, ns.Guide) end
        end
    end)
    ns:On("QUEST_LOG_UPDATE", function()
        if target and target.mode == "quest" then recomputeTimer = 99 end
    end)
end
