-- Rafeeq: data layer over QuestieDB (LibQuestieDB). All features here degrade to "no data"
-- when QuestieDB is missing, so the tracker/automation keep working without it.
local _, ns = ...

local Data = {}
ns.Data = Data

local band = bit and bit.band
local sqrt = math.sqrt

Data.ready = false

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------
local areaToUiMap = {}
local raceMask, classMask

local function loadStringTable(src)
    if type(src) ~= "string" then return type(src) == "table" and src or {} end
    local f = loadstring(src)
    if not f then return {} end
    local ok, t = pcall(f)
    return ok and type(t) == "table" and t or {}
end

function Data:Init()
    local lib = _G.LibQuestieDB
    if not lib or not _G.QuestDB or not _G.NpcDB then return false end
    if lib.RequireContract then
        local ok = pcall(lib.RequireContract, 4)
        if not ok then ns.Print("NEED_QDB_UPDATE") return false end
    end
    local zdb = lib.Support and lib.Support.Get and lib.Support.Get("ZoneDB")
    if zdb and zdb.private then
        local base = loadStringTable(zdb.private.areaIdToUiMapId)
        local over = loadStringTable(zdb.private.areaIdToUiMapIdOverride)
        for k, v in pairs(base) do areaToUiMap[k] = v end
        for k, v in pairs(over) do areaToUiMap[k] = v end
    end
    local enum = lib.Enum or {}
    local raceID = select(3, UnitRace("player"))
    raceMask = enum.raceMaskById and enum.raceMaskById[raceID]
    local classFile = select(2, UnitClass("player"))
    classMask = enum.classKeys and enum.classKeys[classFile]
    self.npcFlags = enum.npcFlags or {}
    self.lib = lib
    self.ready = true
    return true
end

function Data:UiMap(areaID)
    local m = areaToUiMap[areaID]
    if m and m > 0 then return m end
    return nil
end

---------------------------------------------------------------------------
-- Geometry: map % -> world yards, player position
---------------------------------------------------------------------------
local worldCache = {}

-- x, y are 0-100 percentages. Returns continentID, worldX(north), worldY(west)
function Data:World(uiMapID, x, y)
    local key = uiMapID * 1e8 + math.floor(x * 100) * 1e4 + math.floor(y * 100)
    local c = worldCache[key]
    if c then return c[1], c[2], c[3] end
    if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
    local cont, pos = C_Map.GetWorldPosFromMapPos(uiMapID, CreateVector2D(x / 100, y / 100))
    if not cont or not pos then return nil end
    local wx, wy = pos:GetXY()
    worldCache[key] = { cont, wx, wy }
    return cont, wx, wy
end

-- Project a point from its own map onto another map (city, zone or continent).
-- Returns x, y in 0-100 on targetMap, or nil when it falls outside that map.
local projCache = {}
function Data:ProjectTo(targetMap, srcMap, x, y)
    if srcMap == targetMap then return x, y end
    if not (C_Map and C_Map.GetMapPosFromWorldPos and CreateVector2D) then return nil end
    local key = targetMap * 1e12 + srcMap * 1e8 + math.floor(x * 100) * 1e4 + math.floor(y * 100)
    local c = projCache[key]
    if c then return c[1], c[2] end
    local cont, wx, wy = self:World(srcMap, x, y)
    local px, py
    if cont then
        local ok, _, pos = pcall(C_Map.GetMapPosFromWorldPos, cont, CreateVector2D(wx, wy), targetMap)
        if ok and pos then
            local mx, my = pos:GetXY()
            if mx and my and mx >= 0 and mx <= 1 and my >= 0 and my <= 1 then px, py = mx * 100, my * 100 end
        end
    end
    projCache[key] = px and { px, py } or { nil, nil }
    return px, py
end

function Data:MapName(uiMapID)
    local info = uiMapID and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(uiMapID)
    return info and info.name or nil
end

function Data:Player()
    if not C_Map then return nil end
    local map = C_Map.GetBestMapForUnit("player")
    if not map then return nil end
    local pos = C_Map.GetPlayerMapPosition(map, "player")
    if not pos then return nil end
    local px, py = pos:GetXY()
    if not px or (px == 0 and py == 0) then return nil end
    local cont, wx, wy = self:World(map, px * 100, py * 100)
    return map, px * 100, py * 100, cont, wx, wy
end

function Data:Distance(cont1, x1, y1, cont2, x2, y2)
    if not cont1 or cont1 ~= cont2 then return nil end
    local dx, dy = x2 - x1, y2 - y1
    return sqrt(dx * dx + dy * dy)
end

---------------------------------------------------------------------------
-- Spawns -> points { map=uiMapID, x=, y= }
---------------------------------------------------------------------------
local function addSpawns(out, spawns, limit)
    if type(spawns) ~= "table" then return end
    for areaID, list in pairs(spawns) do
        local map = Data:UiMap(areaID)
        if map and type(list) == "table" then
            local seen = {}
            for _, p in ipairs(list) do
                local x, y = p[1], p[2]
                if x and y and x >= 0 and y >= 0 then
                    -- de-duplicate points closer than ~1.5% of the map
                    local cell = math.floor(x / 1.5) * 1000 + math.floor(y / 1.5)
                    if not seen[cell] then
                        seen[cell] = true
                        out[#out + 1] = { map = map, x = x, y = y }
                        if limit and #out >= limit then return end
                    end
                end
            end
        end
    end
end

function Data:NpcPoints(npcID, limit)
    local out = {}
    if self.ready then addSpawns(out, NpcDB.Get(npcID, "spawns"), limit) end
    return out
end

function Data:ObjectPoints(objID, limit)
    local out = {}
    if self.ready and ObjectDB then addSpawns(out, ObjectDB.Get(objID, "spawns"), limit) end
    return out
end

function Data:NpcName(id) return self.ready and NpcDB.Get(id, "name") or nil end
function Data:ItemName(id) return self.ready and ItemDB and ItemDB.Get(id, "name") or nil end
function Data:ObjectName(id) return self.ready and ObjectDB and ObjectDB.Get(id, "name") or nil end
-- zone name for a quest (zoneOrSort > 0 is an area ID), for when there is no exact location
function Data:QuestZoneName(questID)
    if not self.ready then return nil end
    local area = QuestDB.Get(questID, "zoneOrSort")
    if not area or area <= 0 then return nil end
    local map = self:UiMap(area)
    local info = map and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(map)
    return info and info.name or nil
end

function Data:QuestName(id) return self.ready and QuestDB.Get(id, "name") or nil end

---------------------------------------------------------------------------
-- Quest objectives: list of { kind="kill"|"loot"|"object", id=, name=, points={...} }
---------------------------------------------------------------------------
local objCache = {}

function Data:QuestObjectives(questID)
    if not self.ready then return {} end
    local c = objCache[questID]
    if c then return c end
    local list = {}
    local obj = QuestDB.Get(questID, "objectives") or {}
    -- [1] creatures
    for _, row in ipairs(obj[1] or {}) do
        local npc = row[1]
        list[#list + 1] = { kind = "kill", id = npc, name = self:NpcName(npc), points = self:NpcPoints(npc, 60) }
    end
    -- [2] objects
    for _, row in ipairs(obj[2] or {}) do
        local o = row[1]
        list[#list + 1] = { kind = "object", id = o, name = self:ObjectName(o), points = self:ObjectPoints(o, 60) }
    end
    -- [3] items: where they drop
    for _, row in ipairs(obj[3] or {}) do
        local item = row[1]
        local pts, sources = {}, {}
        local npcs = ItemDB and ItemDB.Get(item, "npcDrops") or {}
        for i, npc in ipairs(npcs) do
            if i > 12 then break end
            sources[#sources + 1] = npc
            for _, p in ipairs(self:NpcPoints(npc, 25)) do pts[#pts + 1] = p end
        end
        for i, o in ipairs(ItemDB and ItemDB.Get(item, "objectDrops") or {}) do
            if i > 6 then break end
            for _, p in ipairs(self:ObjectPoints(o, 25)) do pts[#pts + 1] = p end
        end
        list[#list + 1] = { kind = "loot", id = item, name = self:ItemName(item), points = pts, sources = sources }
    end
    -- [5] kill credit groups
    for _, row in ipairs(obj[5] or {}) do
        local npcs = row[1]
        if type(npcs) == "table" then
            local pts = {}
            for i, npc in ipairs(npcs) do
                if i > 8 then break end
                for _, p in ipairs(self:NpcPoints(npc, 25)) do pts[#pts + 1] = p end
            end
            list[#list + 1] = { kind = "kill", id = row[2] or npcs[1], name = self:NpcName(row[2] or npcs[1]), points = pts }
        end
    end
    objCache[questID] = list
    return list
end

-- where to turn in
function Data:FinisherPoints(questID)
    if not self.ready then return {} end
    local fin = QuestDB.Get(questID, "finishedBy") or {}
    local out = {}
    for _, npc in ipairs(fin[1] or {}) do
        for _, p in ipairs(self:NpcPoints(npc, 5)) do p.npc = npc; out[#out + 1] = p end
    end
    for _, o in ipairs(fin[2] or {}) do
        for _, p in ipairs(self:ObjectPoints(o, 5)) do out[#out + 1] = p end
    end
    return out
end

function Data:StarterPoints(questID)
    if not self.ready then return {} end
    local st = QuestDB.Get(questID, "startedBy") or {}
    local out = {}
    for _, npc in ipairs(st[1] or {}) do
        for _, p in ipairs(self:NpcPoints(npc, 5)) do p.npc = npc; out[#out + 1] = p end
    end
    for _, o in ipairs(st[2] or {}) do
        for _, p in ipairs(self:ObjectPoints(o, 5)) do out[#out + 1] = p end
    end
    return out
end

-- nearest point to the player from a list; returns point, distanceYards
function Data:Nearest(points)
    local _, _, _, pc, pwx, pwy = self:Player()
    if not pc then return nil end
    local best, bestD
    for _, p in ipairs(points) do
        local c, wx, wy = self:World(p.map, p.x, p.y)
        local d = self:Distance(pc, pwx, pwy, c, wx, wy)
        if d and (not bestD or d < bestD) then best, bestD = p, d end
    end
    return best, bestD
end

---------------------------------------------------------------------------
-- Quest state & availability
---------------------------------------------------------------------------
local function isDone(id)
    return C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(id)
end
local function inLog(id)
    if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
        return C_QuestLog.GetLogIndexForQuestID(id) ~= nil
    end
    return false
end
Data.IsDone, Data.InLog = isDone, inLog

local staticOK -- [questID] = true for race/class-eligible, non-special quests

local function buildStatic()
    staticOK = {}
    local ids = QuestDB.GetAllIds and QuestDB.GetAllIds() or {}
    for _, id in ipairs(ids) do
        local races, classes, special, skill = QuestDB.Get(id, "requiredRaces"), QuestDB.Get(id, "requiredClasses"),
            QuestDB.Get(id, "specialFlags"), QuestDB.Get(id, "requiredSkill")
        local ok = true
        if races and races ~= 0 and raceMask and band and band(races, raceMask) == 0 then ok = false end
        if ok and classes and classes ~= 0 and classMask and band and band(classes, classMask) == 0 then ok = false end
        if ok and special and special ~= 0 then ok = false end      -- repeatable / event-gated
        if ok and skill then ok = false end                          -- profession quests: later version
        if ok then staticOK[id] = true end
    end
end

local function prereqsMet(id)
    local single = QuestDB.Get(id, "preQuestSingle")
    if type(single) == "table" and #single > 0 then
        local any = false
        for _, q in ipairs(single) do if isDone(q) then any = true break end end
        if not any then return false end
    end
    local group = QuestDB.Get(id, "preQuestGroup")
    if type(group) == "table" then
        for _, q in ipairs(group) do if not isDone(q) then return false end end
    end
    local excl = QuestDB.Get(id, "exclusiveTo")
    if type(excl) == "table" then
        for _, q in ipairs(excl) do if isDone(q) or inLog(q) then return false end end
    end
    local nxt = QuestDB.Get(id, "nextQuestInChain")
    if nxt and nxt ~= 0 and (isDone(nxt) or inLog(nxt)) then return false end
    return true
end

-- Available quests whose giver is on `uiMapID`. Returns list of { id, name, level, point }
local availCache = {}
function Data:InvalidateAvailable() availCache = {} end

function Data:AvailableOnMap(uiMapID, playerLevel)
    if not self.ready or not uiMapID then return {} end
    local key = uiMapID .. ":" .. playerLevel
    local all = availCache[key]
    if not all then
        all = self:_ComputeAvailable(uiMapID, playerLevel)
        availCache[key] = all
    end
    local skipped = ns.char and ns.char.skipped or {}
    local out = {}
    for _, q in ipairs(all) do
        if not skipped[q.id] and not inLog(q.id) then out[#out + 1] = q end
    end
    return out
end

function Data:_ComputeAvailable(uiMapID, playerLevel)
    if not staticOK then buildStatic() end
    local out = {}
    for id in pairs(staticOK) do
        if not isDone(id) and not inLog(id) then
            local req = QuestDB.Get(id, "requiredLevel") or 1
            local lvl = QuestDB.Get(id, "questLevel") or req
            if lvl == -1 then lvl = playerLevel end
            if req <= playerLevel and lvl >= playerLevel - 5 and lvl <= playerLevel + 5 then
                local pts = self:StarterPoints(id)
                for _, p in ipairs(pts) do
                    if p.map == uiMapID then
                        if prereqsMet(id) then
                            out[#out + 1] = { id = id, name = QuestDB.Get(id, "name"), level = lvl, point = p }
                        end
                        break
                    end
                end
            end
        end
    end
    return out
end

-- NPCs with a given flag on a map (vendors, repair, innkeepers, flight masters, trainers)
local flagCache = {}
function Data:NpcsWithFlag(flagName, uiMapID, limit)
    local key = flagName .. ":" .. uiMapID
    if flagCache[key] then return flagCache[key] end
    local out = {}
    flagCache[key] = out
    if not self.ready or not band then return out end
    local flag = self.npcFlags[flagName]
    if not flag or not NpcDB.GetAllIds then return out end
    self._npcIds = self._npcIds or NpcDB.GetAllIds()
    for _, id in ipairs(self._npcIds) do
        local f = NpcDB.Get(id, "npcFlags")
        local friendly = f and band(f, flag) ~= 0 and NpcDB.Get(id, "friendlyToFaction")
        local myFaction = UnitFactionGroup("player") == "Horde" and "H" or "A"
        if friendly and (friendly == "AH" or friendly == myFaction or friendly == "HA") then
            for _, p in ipairs(self:NpcPoints(id, 3)) do
                if p.map == uiMapID then
                    p.npc = id
                    out[#out + 1] = p
                    if limit and #out >= limit then return out end
                end
            end
        end
    end
    return out
end

function Data:Reset()
    objCache = {}
end
