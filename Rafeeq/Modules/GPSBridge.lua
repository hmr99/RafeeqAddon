-- Rafeeq: bridge to AzerothGPS (optional, when the player has it installed).
-- AzerothGPS draws routes that follow the roads and has a turn-by-turn arrow. It takes stops from other
-- addons through its documented doors: the "/way #<uiMapID> x y title" command (its own, or TomTom's
-- which it hooks) and "/agps clear". We only call those - nothing of AzerothGPS is copied or changed.
-- While the bridge is active Rafeeq's own arrow steps aside (AzerothGPS's arrow follows the road) and
-- the step-by-step card sits under AzerothGPS's arrow.
local _, ns = ...
local Data = ns.Data

local GPS = ns:NewModule("GPSBridge")
ns.GPSBridge = GPS

local RESEND_YARDS = 60  -- in quest mode, only re-route when the target moved this far
local sent              -- { quest=, map=, x=, y=, cont=, wx=, wy= } last stop we gave AzerothGPS

local function wayHandler()
    -- whoever owns /way (AzerothGPS itself when TomTom is absent, else TomTom - AzerothGPS hooks it)
    for key, fn in pairs(SlashCmdList) do
        if type(fn) == "function" then
            for i = 1, 9 do
                local cmd = _G["SLASH_" .. key .. i]
                if not cmd then break end
                if cmd:lower() == "/way" then return fn end
            end
        end
    end
end

function GPS:Available()
    return type(_G.AzerothGPS) == "table" and type(SlashCmdList.AZEROTHGPS) == "function" and wayHandler() ~= nil
end

function GPS:Active()
    return ns.db.gpsBridge and self:Available()
end

-- force: clear even if we did not send the current route. AzerothGPS keeps its route over a /reload
-- while we forget what we sent, so before giving it a new stop we always clear: otherwise the old stop
-- stays and "fastest order" sends the player there first.
local function clearRoute(force)
    if (sent or force) and type(SlashCmdList.AZEROTHGPS) == "function" then
        pcall(SlashCmdList.AZEROTHGPS, "clear")
    end
    sent = nil
end

local function cleanTitle(s)
    -- '#' at the end of a /way line means an icon in AzerothGPS; keep titles plain
    return (tostring(s or "Rafeeq"):gsub("#", ""):gsub("[\r\n]", " "))
end

-- Called by the arrow whenever its target is set or moves.
function GPS:Sync()
    if not self:Active() then
        if sent then clearRoute() end
        return
    end
    local t = ns.Nav and ns.Nav:Target()
    if not t or not t.map then return end
    local cont, wx, wy = Data:World(t.map, t.x, t.y)
    if sent and sent.quest == t.questID and sent.mode == t.mode then
        -- same quest/point: only follow big moves (a different objective cluster), not every recompute
        if sent.map == t.map and math.abs(sent.x - t.x) < 0.05 and math.abs(sent.y - t.y) < 0.05 then return end
        local d = cont and Data:Distance(sent.cont, sent.wx, sent.wy, cont, wx, wy)
        if d and d < RESEND_YARDS then return end
    end
    local way = wayHandler()
    if not way then return end
    clearRoute(true)
    local title = t.questID and Data:QuestName(t.questID) or t.label
    local ok = pcall(way, ("#%d %.2f %.2f %s"):format(t.map, t.x, t.y, cleanTitle(title)))
    if ok then
        sent = { quest = t.questID, mode = t.mode, map = t.map, x = t.x, y = t.y, cont = cont, wx = wx, wy = wy }
    end
end

function GPS:OnTargetCleared()
    if sent then clearRoute() end
end

-- AzerothGPS has a route from us: it is the one giving directions now (its arrow, its directions
-- text or just the line on its map). Rafeeq's straight-line arrow must not contradict it.
function GPS:Guiding()
    return self:Active() and sent ~= nil
end

-- the card moves under AzerothGPS's arrow when that window is shown
function GPS:ArrowAnchor()
    if self:Active() and sent and _G.AzerothGPSArrow and _G.AzerothGPSArrow:IsShown() then
        return _G.AzerothGPSArrow
    end
end

function GPS:OnRefresh()
    if not self:Active() then
        if sent then clearRoute() end
    else
        self:Sync()
    end
end
