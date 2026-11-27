-- tests/wow.lua - a small WoW: Forever client emulator for Rafeeq.
-- Simulates the API surface Rafeeq touches, a mutable game world (W), events, timers,
-- OnUpdate, combat lockdown, and records every Lua error raised inside handlers
-- (the way the real client's error frame would).
--
-- Usage (from Lua 5.1):  local W = dofile("tests/wow.lua")
-- Then load QuestieDB (optional) and the addon files, then drive W.fire / W.advance.

local W = {
    errors = {},       -- { msg, trace }
    chat = {},         -- chat lines
    time = 0,
    combat = false,
    level = 5, xp = 100, xpMax = 1000, money = 10000,
    class = "WARRIOR", race = "Human", raceId = 1, faction = "Alliance",
    map = 1429, px = 0.48, py = 0.42, facing = 0,
    log = {},          -- { {questID=, title=, level=, objectives={{text=,finished=}}, complete=bool} }
    done = {},         -- [questID] = true
    bags = {},         -- [bag] = { [slot] = {quality=,hyperlink=,stackCount=,price=} }
    actions = {},      -- [slot] = spellID
    spells = {},       -- [name] = { id=, cd=ms, known=true }
    macros = {},       -- [name] = body
    gossip = nil,      -- { active={...}, available={...} }
    questChoices = 0, questMoney = 0,
    sold = {}, repaired = nil, accepted = {}, turnedIn = {},
    cvars = { rotateMinimap = "0" },
    geo = {
        [1429] = { oN = 0, oW = 0, W = 3000, H = 2000 },          -- Elwynn (same projection as before)
        [1411] = { oN = 0, oW = -3000, W = 3000, H = 2000 },      -- zone right next to it (east)
        [1415] = { oN = 3000, oW = 4500, W = 12000, H = 8000 },   -- continent containing both
        [99999] = { oN = 90000, oW = 90000, W = 1000, H = 800 }, -- far-away map with no quests
        [1438] = { cont = 1, oN = 10000, oW = 2000, W = 3000, H = 3000 }, -- Teldrassil (Kalimdor)
        [291] = { cont = 36, oN = 0, oW = 0, W = 500, H = 400 },         -- a dungeon (own continent)
    },
}

local unpack = unpack or table.unpack

local function noop() end

local function record(err)
    W.errors[#W.errors + 1] = { msg = tostring(err), trace = debug.traceback("", 2) }
end

-- run a handler like the client does: errors are caught and recorded, never thrown
function W.safe(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then record(err) end
    return ok
end

---------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------
local frames, eventFrames = {}, {}
W.frames = frames

local Frame = {}
Frame.__index = function(t, k)
    local v = rawget(Frame, k)
    if v ~= nil then return v end
    -- widget methods we don't model are harmless no-ops; plain data fields stay nil like in WoW
    if type(k) == "string" and k:match("^[A-Z]") then return noop end
    return nil
end

local function newObject(kind, name, parent)
    local o = setmetatable({
        _kind = kind, _name = name, _parent = parent, _shown = kind ~= "Frame" or true,
        _scripts = {}, _events = {}, _text = "", _w = 100, _h = 100, _scale = 1, _level = 1,
        _children = {}, _points = {},
    }, Frame)
    if name then _G[name] = o end
    frames[#frames + 1] = o
    return o
end

function Frame:CreateFontString() return newObject("FontString", nil, self) end
function Frame:CreateTexture() return newObject("Texture", nil, self) end
function Frame:SetScript(n, f) self._scripts[n] = f end
function Frame:GetScript(n) return self._scripts[n] end
function Frame:HookScript(n, f)
    local old = self._scripts[n]
    self._scripts[n] = function(...) if old then old(...) end f(...) end
end
function Frame:RegisterEvent(e)
    if type(e) ~= "string" or not W.knownEvents[e] then
        error("Attempt to register unknown event \"" .. tostring(e) .. "\"", 2)
    end
    self._events[e] = true
    eventFrames[self] = true
end
function Frame:UnregisterEvent(e) self._events[e] = nil end
function Frame:Show() self._shown = true if self._scripts.OnShow then W.safe(self._scripts.OnShow, self) end end
function Frame:Hide() self._shown = false if self._scripts.OnHide then W.safe(self._scripts.OnHide, self) end end
function Frame:IsShown() return self._shown end
function Frame:IsVisible() return self._shown end
function Frame:SetShown(v) if v then self:Show() else self:Hide() end end
function Frame:SetText(t)
    if t ~= nil and type(t) ~= "string" and type(t) ~= "number" then
        error("SetText: bad argument #1 (string expected, got " .. type(t) .. ")", 2)
    end
    self._text = t and tostring(t) or ""
end
function Frame:GetText() return self._text end
function Frame:SetFont(path, size)
    if type(path) ~= "string" or type(size) ~= "number" then error("SetFont: bad arguments", 2) end
    self._font = path
    return true
end
function Frame:GetStringHeight() return 12 end
function Frame:GetStringWidth() return #self._text * 6 end
-- like WoW, OnSizeChanged fires when the size really changes
local function sized(self, w, h)
    local changed = w ~= self._w or h ~= self._h
    self._w, self._h = w, h
    if changed and self._scripts.OnSizeChanged then W.safe(self._scripts.OnSizeChanged, self, w, h) end
end
function Frame:SetWidth(w) sized(self, w, self._h) end
function Frame:SetHeight(h)
    if type(h) ~= "number" or h ~= h then error("SetHeight: bad argument", 2) end
    sized(self, self._w, h)
end
function Frame:SetSize(w, h) sized(self, w, h) end
function Frame:GetWidth() return self._w end
function Frame:GetHeight() return self._h end
function Frame:SetScale(s)
    if type(s) ~= "number" or s <= 0 then error("SetScale: scale must be > 0", 2) end
    self._scale = s
end
function Frame:GetScale() return self._scale end
function Frame:SetPoint(...)
    local a = { ... }
    for i = 2, #a do
        if type(a[i]) == "number" and a[i] ~= a[i] then error("SetPoint: NaN offset", 2) end
    end
    self._points[#self._points + 1] = a
end
function Frame:ClearAllPoints() self._points = {} end
function Frame:GetPoint()
    local p = self._points[#self._points]
    if p and type(p[2]) ~= "string" then return p[1], p[2], p[3], p[4], p[5] end
    return "TOPRIGHT", UIParent, "TOPRIGHT", -80, -220
end
function Frame:StopMovingOrSizing()
    -- a drag "moves" the frame: tests set self._dragTo = { x, y } before OnDragStop
    if self._dragTo then self:ClearAllPoints() self:SetPoint("TOPLEFT", UIParent, "TOPLEFT", self._dragTo[1], self._dragTo[2]) end
end
function Frame:GetFrameLevel() return self._level end
function Frame:SetFrameLevel(l) self._level = l end
function Frame:GetParent() return self._parent end
function Frame:SetParent(p) self._parent = p end
function Frame:SetChecked(v) self._checked = v and true or false end
function Frame:GetChecked() return self._checked end
function Frame:GetFontString()
    self._fs = self._fs or newObject("FontString", nil, self)
    return self._fs
end
function Frame:SetRotation(r)
    if type(r) ~= "number" or r ~= r then error("SetRotation: bad radians", 2) end
    self._rot = r
end
function Frame:SetTexture(t) self._tex = t end
function Frame:EnableMouse(v) self._mouse = v and true or false end
function Frame:SetAlpha(a)
    if type(a) ~= "number" then error("SetAlpha: number expected", 2) end
    self._alpha = a
end
function Frame:GetTexture() return self._tex end
function Frame:StartMoving()
    if self._movable ~= true then error("Frame is not movable", 2) end
end
function Frame:SetMovable(v) self._movable = v end
function Frame:Click(btn) if self._scripts.OnClick then W.safe(self._scripts.OnClick, self, btn or "LeftButton") end end
function Frame:GetZoom() return 0 end

function CreateFrame(kind, name, parent, template)
    local f = newObject(kind or "Frame", name, parent)
    if template and template:find("CloseButton") then f._template = template end
    return f
end

UIParent = newObject("Frame", "UIParent")
Minimap = newObject("Frame", "Minimap")
Minimap._w, Minimap._h = 140, 140
GameTooltip = newObject("Frame", "GameTooltip")
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) W.chat[#W.chat + 1] = m end }
UISpecialFrames = {}
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
BackdropTemplateMixin = {}
NUM_BAG_SLOTS = 4
MAX_CHARACTER_MACROS = 18
SlashCmdList = {}
MerchantFrame = newObject("Frame", "MerchantFrame")
MerchantFrame._shown = false

-- World map with a scroll canvas
WorldMapFrame = newObject("Frame", "WorldMapFrame")
WorldMapFrame._shown = false
WorldMapFrame.ScrollContainer = newObject("Frame")
WorldMapFrame.ScrollContainer.Child = newObject("Frame")
WorldMapFrame.ScrollContainer.Child._w, WorldMapFrame.ScrollContainer.Child._h = 1002, 668
WorldMapFrame.ScrollContainer.GetCanvasScale = function() return 1 end
WorldMapFrame.ScrollContainer.OnCanvasScaleChanged = noop
WorldMapFrame.OnMapChanged = noop
WorldMapFrame.GetMapID = function() return W.viewMap or W.map end
ObjectiveTrackerFrame = newObject("Frame", "ObjectiveTrackerFrame")

---------------------------------------------------------------------------
-- Lua/WoW globals
---------------------------------------------------------------------------
tinsert, tremove = table.insert, table.remove
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
strsplit = function(d, s) local out = {} for p in (s .. d):gmatch("(.-)" .. d) do out[#out + 1] = p end return unpack(out) end
function hooksecurefunc(a, b, c)
    local t, name, fn = _G, a, b
    if type(a) == "table" then t, name, fn = a, b, c end
    local old = t[name]
    t[name] = function(...) local r = { old(...) } W.safe(fn, ...) return unpack(r) end
end
bit = {
    -- WoW's bit library works on 32-bit integers: bits 32+ are lost.
    band = function(a, b)
        a, b = a % 4294967296, b % 4294967296
        local r, p = 0, 1
        while a > 0 and b > 0 do
            local x, y = a % 2, b % 2
            if x == 1 and y == 1 then r = r + p end
            a, b, p = (a - x) / 2, (b - y) / 2, p * 2
        end
        return r
    end,
}
function GetTime() return W.time end
function GetLocale() return "enUS" end
function BreakUpLargeNumbers(n) return tostring(n) end
function GetCoinTextureString(c) return c .. "c" end
function InCombatLockdown() return W.combat end
function IsShiftKeyDown() return W.shift or false end
function IsControlKeyDown() return W.ctrl or false end
W.cursor = { 500, 500 }
function GetCursorPosition() return W.cursor[1], W.cursor[2] end
function GetCVar(k) return W.cvars[k] end
function GetPlayerFacing() return W.facing end
function GetMaxPlayerLevel() return 60 end
W.sounds = {}
SOUNDKIT = { READY_CHECK = 8960, IG_QUEST_LOG_ABANDON_QUEST = 846 }
function PlaySound(id) W.sounds[#W.sounds + 1] = id return true end
function GetUnitSpeed() return W.speed or 0, 7, 7, 4.7 end

-- unit
function UnitLevel() return W.level end
function UnitXP() return W.xp end
function UnitXPMax() return W.xpMax end
function UnitClass() return W.class:sub(1, 1) .. W.class:sub(2):lower(), W.class, 1 end
function UnitRace() return W.race, W.race, W.raceId end
function UnitFactionGroup() return W.faction end
W.plates = {}   -- [unit] = { name=, secret=bool }
function UnitName(unit)
    local p = unit and W.plates[unit]
    if p then
        if p.secret then return W.SECRET end
        return p.name
    end
    return "Tester"
end
-- secret values (Midnight/Forever): an opaque value addons may not compare or do maths on
W.SECRET = setmetatable({}, { __eq = function() error("attempt to compare a secret value", 2) end,
    __concat = function() error("attempt to concatenate a secret value", 2) end,
    __index = function() error("attempt to index a secret value", 2) end })
function issecretvalue(v) return rawequal(v, W.SECRET) end
function IsInInstance() return W.inInstance or false, W.inInstance and "party" or "none" end
C_NamePlate = {
    GetNamePlateForUnit = function(unit)
        local p = W.plates[unit]
        if not p then return nil end
        p.frame = p.frame or CreateFrame("Frame")
        p.frame.namePlateUnitToken = unit
        return p.frame
    end,
    GetNamePlates = function()
        local out = {}
        for unit in pairs(W.plates) do out[#out + 1] = C_NamePlate.GetNamePlateForUnit(unit) end
        return out
    end,
}
function GetMoney() return W.money end

-- quest log
local function entry(i) return W.log[i] end
C_QuestLog = {
    GetNumQuestLogEntries = function() return #W.log end,
    GetInfo = function(i)
        local q = entry(i)
        if not q then return nil end
        return { title = q.title, questID = q.questID, level = q.level, difficultyLevel = q.level,
            isHeader = q.isHeader or false, isHidden = false }
    end,
    IsComplete = function(id) for _, q in ipairs(W.log) do if q.questID == id then return q.complete end end return false end,
    ReadyForTurnIn = function(id) for _, q in ipairs(W.log) do if q.questID == id then return q.complete end end return false end,
    IsFailed = function() return false end,
    GetQuestObjectives = function(id)
        for _, q in ipairs(W.log) do if q.questID == id then return q.objectives or {} end end
        return {}
    end,
    GetMaxNumQuestsCanAccept = function() return 25 end,
    IsQuestFlaggedCompleted = function(id) return W.done[id] or false end,
    GetLogIndexForQuestID = function(id) for i, q in ipairs(W.log) do if q.questID == id then return i end end end,
}
function GetQuestLogRewardXP(id) return W.rewardXP and W.rewardXP[id] or 100 end
function GetQuestDifficultyColor(level)
    local d = (level or 0) - W.level
    if d >= 5 then return { r = 1, g = 0.1, b = 0.1 } end
    if d >= 3 then return { r = 1, g = 0.5, b = 0.25 } end
    if d >= -2 then return { r = 1, g = 1, b = 0 } end
    if d >= -5 then return { r = 0.25, g = 0.75, b = 0.25 } end
    return { r = 0.5, g = 0.5, b = 0.5 }
end
QuestDifficultyColors = { trivial = { r = 0.5, g = 0.5, b = 0.5 } }

-- quest dialogs
function QuestGetAutoAccept() return false end
function AcceptQuest() W.accepted[#W.accepted + 1] = W.dialogQuest or true end
function ConfirmAcceptQuest() W.accepted[#W.accepted + 1] = "confirm" end
function IsQuestCompletable() return W.completable ~= false end
function CompleteQuest() W.completeClicked = true end
function GetNumQuestChoices() return W.questChoices end
function GetQuestMoneyToGet() return W.questMoney end
function GetQuestReward(c) W.turnedIn[#W.turnedIn + 1] = c end
C_GossipInfo = {
    GetActiveQuests = function() return W.gossip and W.gossip.active or {} end,
    GetAvailableQuests = function() return W.gossip and W.gossip.available or {} end,
    SelectActiveQuest = function(id) W.gossipPicked = { "active", id } end,
    SelectAvailableQuest = function(id) W.gossipPicked = { "available", id } end,
}

-- map
function CreateVector2D(x, y) return { x = x, y = y, GetXY = function(s) return s.x, s.y end } end
C_Map = {
    GetBestMapForUnit = function() return W.map end,
    GetMapInfo = function(id) return { mapID = id, name = ({ [1411] = "Durotar", [1429] = "Elwynn Forest", [1438] = "Teldrassil", [291] = "The Deadmines" })[id] or ("Map " .. id) } end,
    GetPlayerMapPosition = function() if W.instance then return nil end return CreateVector2D(W.px, W.py) end,
    -- fake geography on continent 0: each map is a rectangle (oN/oW = world north/west of its
    -- top-left corner, W/H = size in yards). Elwynn (1429) and Durotar (1411) sit inside the
    -- continent map 1415; map 99999 is far from both.
    GetWorldPosFromMapPos = function(map, v)
        local m = W.geo[map] or W.geo[1429]
        return m.cont or 0, CreateVector2D(m.oN - v.y * m.H, m.oW - v.x * m.W)
    end,
    GetMapPosFromWorldPos = function(cont, v, map)
        local m = W.geo[map]
        if not m or (m.cont or 0) ~= cont then return nil end
        local wx, wy = v:GetXY()
        return map, CreateVector2D((m.oW - wy) / m.W, (m.oN - wx) / m.H)
    end,
}
C_Minimap = { GetViewRadius = function() return 200 end }
-- user waypoint + super-track (the in-world diamond)
UiMapPoint = { CreateFromCoordinates = function(map, x, y)
    if type(map) ~= "number" or x < 0 or x > 1 or y < 0 or y > 1 then error("UiMapPoint: bad coordinates", 2) end
    return { uiMapID = map, position = CreateVector2D(x, y) }
end }
C_Map.SetUserWaypoint = function(p) W.waypoint = p end
C_Map.ClearUserWaypoint = function() W.waypoint = nil end
C_Map.HasUserWaypoint = function() return W.waypoint ~= nil end
C_Map.CanSetUserWaypointOnMap = function(map) return map ~= 99999 end
function SetCVar(k, v) W.cvars[k] = tostring(v) end
-- as in the game: one thing is super-tracked at a time, so tracking a quest drops the waypoint's diamond
C_SuperTrack = {
    SetSuperTrackedQuestID = function(id) W.superTracked = id if id and id ~= 0 then W.superTrackedWaypoint = false end end,
    GetSuperTrackedQuestID = function() return W.superTracked or 0 end,
    SetSuperTrackedUserWaypoint = function(on) W.superTrackedWaypoint = on if on then W.superTracked = 0 end end,
    IsSuperTrackingUserWaypoint = function() return W.superTrackedWaypoint == true and W.waypoint ~= nil end,
}

-- containers / merchant
C_Container = {
    GetContainerNumSlots = function(bag) local b = W.bags[bag] return b and 16 or 0 end,
    GetContainerItemInfo = function(bag, slot)
        local it = W.bags[bag] and W.bags[bag][slot]
        if not it then return nil end
        return { quality = it.quality, hyperlink = it.hyperlink, stackCount = it.stackCount or 1, hasNoValue = it.price == 0 }
    end,
    UseContainerItem = function(bag, slot)
        if not MerchantFrame._shown then error("UseContainerItem outside merchant would equip/use the item", 2) end
        local it = W.bags[bag] and W.bags[bag][slot]
        if it then W.sold[#W.sold + 1] = it.hyperlink W.money = W.money + (it.price or 0) * (it.stackCount or 1) W.bags[bag][slot] = nil end
    end,
}
function GetItemInfo(link)
    for _, b in pairs(W.bags) do for _, it in pairs(b) do if it.hyperlink == link then
        return link, link, it.quality, 1, 1, "", "", 1, "", 0, it.price or 0
    end end end
    return nil
end
function CanMerchantRepair() return W.canRepair ~= false end
function GetRepairAllCost() return W.repairCost or 0, (W.repairCost or 0) > 0 end
function RepairAllItems(guild)
    if guild then W.repaired = "guild" else
        if W.money < (W.repairCost or 0) then error("not enough money", 2) end
        W.money = W.money - (W.repairCost or 0) W.repaired = "self"
    end
    W.repairCost = 0
end
function CanGuildBankRepair() return W.guildRepair or false end
function GetGuildBankWithdrawMoney() return W.guildMoney or 0 end

-- spells / actions / macros
C_Spell = {
    GetSpellInfo = function(n)
        if type(n) == "number" then
            for name, s in pairs(W.spells) do if s.id == n then return { spellID = s.id, name = name } end end
            return nil
        end
        local base = n:gsub("%(.-%)", "")
        local s = W.spells[n] or W.spells[base]
        if s and s.known ~= false then return { spellID = s.best or s.id, name = n } end
    end,
    GetSpellName = function(id)
        for name, s in pairs(W.spells) do if s.id == id or s.best == id then return name end end
    end,
    PickupSpell = function(id) W.cursor = id end,
}
C_SpellBook = { IsSpellKnown = function(id)
    for _, s in pairs(W.spells) do if (s.id == id or s.best == id) then return s.known ~= false end end
    return false
end }
function GetSpellBaseCooldown(id)
    for _, s in pairs(W.spells) do if s.id == id or s.best == id then return s.cd or 0 end end
    return 0
end
function GetActionInfo(slot) local id = W.actions[slot] if id then return "spell", id end end
function GetCursorInfo() return W.cursor and "spell" or nil end
function PlaceAction(slot)
    if W.combat then error("PlaceAction blocked in combat (protected)", 2) end
    W.actions[slot], W.cursor = W.cursor, W.actions[slot]
end
function ClearCursor() W.cursor = nil end
function GetMacroIndexByName(n) local i = 0 for k in pairs(W.macros) do i = i + 1 if k == n then return i end end return 0 end
function GetNumMacros() local n = 0 for _ in pairs(W.macros) do n = n + 1 end return 0, n end
function GetMacroInfo(i) local n = 0 for k, v in pairs(W.macros) do n = n + 1 if n == i then return k, "", v end end end
function CreateMacro(name, icon, body)
    if W.combat then error("CreateMacro blocked in combat", 2) end
    if #body > 255 then error("macro body too long: " .. #body, 2) end
    W.macros[name] = body
end
function EditMacro(i, name, icon, body)
    if W.combat then error("EditMacro blocked in combat", 2) end
    if #body > 255 then error("macro body too long: " .. #body, 2) end
    W.macros[name] = body
end

---------------------------------------------------------------------------
-- Timers, events, time
---------------------------------------------------------------------------
local timers = {}
C_Timer = { After = function(sec, fn)
    if type(fn) ~= "function" then error("C_Timer.After: callback must be a function", 2) end
    timers[#timers + 1] = { at = W.time + sec, fn = fn }
end }

W.knownEvents = {}
for e in ([[ADDON_LOADED PLAYER_LOGIN PLAYER_ENTERING_WORLD QUEST_LOG_UPDATE QUEST_WATCH_UPDATE
UNIT_QUEST_LOG_CHANGED QUEST_TURNED_IN QUEST_ACCEPTED QUEST_REMOVED PLAYER_LEVEL_UP PLAYER_XP_UPDATE
GOSSIP_SHOW QUEST_GREETING QUEST_DETAIL QUEST_ACCEPT_CONFIRM QUEST_PROGRESS QUEST_COMPLETE MERCHANT_SHOW
MERCHANT_CLOSED LEARNED_SPELL_IN_TAB LEARNED_SPELL_IN_SKILL_LINE PLAYER_REGEN_ENABLED PLAYER_REGEN_DISABLED
ZONE_CHANGED_NEW_AREA ZONE_CHANGED SPELLS_CHANGED NAME_PLATE_UNIT_ADDED NAME_PLATE_UNIT_REMOVED]]):gmatch("%S+") do W.knownEvents[e] = true end

function W.fire(event, ...)
    if not W.knownEvents[event] then error("test fired unknown event " .. event) end
    for f in pairs(eventFrames) do
        if f._events[event] and f._scripts.OnEvent then W.safe(f._scripts.OnEvent, f, event, ...) end
    end
end

-- advance game time; runs due timers and OnUpdate of shown frames every `step`
function W.advance(sec, step)
    step = step or 0.05
    local target = W.time + sec
    while W.time < target - 1e-9 do
        W.time = math.min(target, W.time + step)
        local due = {}
        for i = #timers, 1, -1 do
            if timers[i].at <= W.time then due[#due + 1] = table.remove(timers, i) end
        end
        for i = #due, 1, -1 do W.safe(due[i].fn) end
        for _, f in ipairs(frames) do
            local u = f._scripts.OnUpdate
            if u and f._shown then W.safe(u, f, step) end
        end
    end
end

function W.enterCombat() W.combat = true W.fire("PLAYER_REGEN_DISABLED") end
function W.leaveCombat() W.combat = false W.fire("PLAYER_REGEN_ENABLED") end

function W.say(s) W.chat[#W.chat + 1] = s end

-- collect every visible text in a frame tree (for assertions)
function W.textsOf(root)
    local out = {}
    for _, f in ipairs(frames) do
        local p, inside = f, false
        while p do if p == root then inside = true break end p = p._parent end
        if inside and f._shown and f._text and f._text ~= "" then out[#out + 1] = f._text end
    end
    return out
end

return W
