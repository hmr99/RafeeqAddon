-- Rafeeq: bridge to MapWise (optional, when the player has it installed). Since 0.10.0 this is
-- Rafeeq's only route hand-off; the AzerothGPS one is switched off.
-- MapWise enhances the Blizzard world map and plans routes over roads, flight paths and boats, with
-- its own minimap line, checkpoints and an in-world marker. It has no documented API for other
-- addons; it exposes its namespace as the global MapWiseAPI. We only call a few of its entry points,
-- every call is guarded and wrapped in pcall, and nothing of MapWise is copied or changed:
--   * RouteNavigation:State()            is a MapWise route being navigated right now?
--   * QuestRouting:Start(questID, mode)  route to a quest (MapWise picks objective / turn-in itself)
--   * RoutePlanner:World(map, x, y, n) + RouteUI:RouteTo(goal, true)   route to a point (x, y in 0-1)
--   * QuestRouting:Stop() / RouteNavigation:Stop()                     end a route we started
-- Two parts:
--   1. Always: MapWise and Rafeeq share the game's single user waypoint (the in-world diamond). While a
--      MapWise route is navigated, Rafeeq leaves that slot alone so the two never fight over it.
--   2. Option mapwiseBridge: "guide me" in Rafeeq hands the target to MapWise, and Rafeeq's
--      straight-line arrow steps aside while MapWise guides along the roads. If MapWise refuses (in
--      combat, map not built yet, an unknown MapWise version) Rafeeq guides by itself as before.
local _, ns = ...

local MW = ns:NewModule("MapWiseBridge")
ns.MapWiseBridge = MW

local SUPPORTED_MAJOR = 3   -- entry points checked against MapWise 3.0.x
local GRACE = 8             -- seconds MapWise gets to plan the route before Rafeeq guides by itself
local sent                  -- { quest = id } or { map=, x=, y= } : the route we gave MapWise
local stateCache, stateAt = nil, -1
local broken                -- a MapWise call raised an error: leave MapWise alone for this session

-- pcall a MapWise method; an error means its internals changed, so the bridge switches itself off
local function call(obj, name, ...)
    local ok, a = pcall(obj[name], obj, ...)
    if not ok then broken = true stateCache = false return false end
    return true, a
end

local function api()
    local A = _G.MapWiseAPI
    if type(A) ~= "table" then return nil end
    return A
end

local function major(A)
    local v = A.version
    if (type(v) ~= "string" and type(v) ~= "number") and C_AddOns and C_AddOns.GetAddOnMetadata then
        v = C_AddOns.GetAddOnMetadata("MapWise", "Version")
    end
    return tonumber(tostring(v or ""):match("^(%d+)"))
end

local function fn(t, name) return type(t) == "table" and type(t[name]) == "function" end

-- MapWise is loaded, is a version we know, and its navigation can be read.
function MW:Present()
    local A = api()
    return not broken and A ~= nil and major(A) == SUPPORTED_MAJOR and fn(A.RouteNavigation, "State")
end

-- the parts needed to start a route from Rafeeq
function MW:CanRoute()
    local A = api()
    if not self:Present() then return false end
    return fn(A.RoutePlanner, "World") and fn(A.RouteUI, "RouteTo") and type(A.UI) == "table" and A.UI.frame ~= nil
end

function MW:Active()
    return ns.db.mapwiseBridge and self:CanRoute()
end

-- Is MapWise navigating a route right now (any route, ours or the player's own)?
-- Read at most twice a second: State() re-syncs MapWise's route each call.
function MW:Navigating()
    if not self:Present() then return false end
    local now = GetTime()
    if now - stateAt < 0.5 then return stateCache end
    stateAt = now
    local ok, n = call(api().RouteNavigation, "State")
    stateCache = ok and type(n) == "table" and n.active == true and not n.paused and not n.stopped and not n.arrived
    return stateCache
end

function MW:Invalidate() stateAt = -1 end

-- Rafeeq handed its target to MapWise and MapWise is guiding it (or still planning it, for a few
-- seconds): our straight-line arrow and our waypoint step aside. MapWise plans routes in the
-- background, so its navigation starts a moment after RouteTo / Start returned.
function MW:Guiding()
    if not sent or not ns.db.mapwiseBridge then return false end
    if self:Navigating() then sent.seen = true return true end
    if not sent.seen and GetTime() - sent.at < GRACE then return true end
    return false
end

-- The game has one user waypoint (the in-world diamond). While MapWise navigates any route, or
-- is about to navigate ours, it owns that slot and Rafeeq must not move it.
function MW:OwnsWaypoint()
    return self:Guiding() or self:Navigating()
end

local function questRouting(A)
    return fn(A.QuestRouting, "Start") and type(A.ModernUI) == "table" and A.ModernUI.ready
end

local function routeToPoint(A, map, x, y, title)
    local okGoal, goal = call(A.RoutePlanner, "World", map, x / 100, y / 100, title)
    if not okGoal or type(goal) ~= "table" then return false end
    local ok, started = call(A.RouteUI, "RouteTo", goal, true)
    return ok and started == true
end

-- Called when the player picks a target in Rafeeq ("guide me", a pin, a tracker click).
function MW:Send(t)
    if not t or not self:Active() then return false end
    local A = api()
    local ok = false
    if t.mode == "quest" and t.questID and questRouting(A) then
        local called, started = call(A.QuestRouting, "Start", t.questID, "auto")
        ok = called and started == true
        if ok then sent = { quest = t.questID, at = GetTime() } end
    end
    if not ok and not broken and t.map and t.x and t.y then
        local title = t.questID and ns.Data:QuestName(t.questID) or t.label or "Rafeeq"
        ok = routeToPoint(A, t.map, t.x, t.y, title)
        if ok then sent = { map = t.map, x = t.x, y = t.y, at = GetTime() } end
    end
    if not ok then sent = nil end
    self:Invalidate()
    return ok
end

-- Rafeeq's target was cleared: end the route we started (never one the player made in MapWise).
function MW:OnTargetCleared()
    if not sent then return end
    local A = api()
    if A then
        if sent.quest and fn(A.QuestRouting, "Stop") then
            call(A.QuestRouting, "Stop")
        elseif fn(A.RouteNavigation, "Stop") then
            call(A.RouteNavigation, "Stop")
        end
    end
    sent = nil
    self:Invalidate()
end

function MW:Sent() return sent end

function MW:OnRefresh()
    if not ns.db.mapwiseBridge and sent then self:OnTargetCleared() end
end
