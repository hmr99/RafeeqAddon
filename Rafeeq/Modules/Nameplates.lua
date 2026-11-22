-- Rafeeq: quest marks on nameplates.
-- Mobs you must kill, mobs that drop an item you need, and NPCs who give or take a quest get an
-- icon over their nameplate (with progress) and a glow whose style, colour and strength you choose.
-- Blizzard rules: nameplates and quest info are locked inside instances, and unit names can be
-- "secret" in combat - we never compare a secret value; marks placed before combat stay.
local _, ns = ...
local L = ns.L
local Data = ns.Data

local Plates = ns:NewModule("Nameplates")
ns.Nameplates = Plates

Plates.STYLES = { "soft", "ring", "pulse" }
Plates.COLORS = {
    gold = { 1, 0.82, 0.2 }, red = { 1, 0.25, 0.2 }, green = { 0.3, 1, 0.4 },
    blue = { 0.3, 0.7, 1 }, purple = { 0.75, 0.4, 1 },
}
Plates.COLOR_ORDER = { "gold", "red", "green", "blue", "purple" }

local ICON = {
    kill   = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8",
    loot   = "Interface\\Icons\\INV_Misc_Bag_08",
    giver  = "Interface\\GossipFrame\\AvailableQuestIcon",
    finish = "Interface\\GossipFrame\\ActiveQuestIcon",
}
local GLOW_TEX = "Interface\\GLUES\\Models\\UI_Draenei\\GenericGlow64"
local RING_TEX = "Interface\\Buttons\\UI-ActionButton-Border"

local marks = {}       -- [unitToken] = overlay frame
local pool = {}
local wanted           -- { [name] = { kind=, progress= } } rebuilt on quest changes
local pulseT = 0

---------------------------------------------------------------------------
-- What to mark: names from QuestieDB + the live quest log
---------------------------------------------------------------------------
local function isSecret(v)
    return issecretvalue and issecretvalue(v) or false
end

local function live(questID)
    local out = {}
    local objs = C_QuestLog and C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(questID)
    for _, o in ipairs(objs or {}) do
        if o.text then out[#out + 1] = o end
    end
    return out
end

local function progressFor(name, objs)
    local n = name and name:lower()
    for _, o in ipairs(objs) do
        if n and o.text:lower():find(n, 1, true) then
            return o.finished, o.text:match("(%d+%s*/%s*%d+)%s*$")
        end
    end
end

local function put(map, name, kind, progress)
    if not name or name == "" then return end
    local cur = map[name]
    -- a mob you must kill outranks one that only drops something
    if not cur or (cur.kind == "loot" and kind == "kill") then map[name] = { kind = kind, progress = progress } end
end

function Plates:Rebuild()
    wanted = {}
    if not Data.ready then return end
    local Q = ns.QuestAPI
    for i = 1, (Q and Q.NumEntries() or 0) do
        local e = Q.Entry(i)
        if e and not e.isHeader and e.questID then
            if e.isComplete then
                local who = Data:FinisherName(e.questID)
                put(wanted, who, "finish")
            else
                local objs = live(e.questID)
                for _, obj in ipairs(Data:QuestObjectives(e.questID)) do
                    local done, prog = progressFor(obj.name, objs)
                    if not done then
                        if obj.kind == "kill" then
                            put(wanted, obj.name, "kill", prog)
                        elseif obj.kind == "loot" then
                            for _, npc in ipairs(obj.sources or {}) do
                                put(wanted, Data:NpcName(npc), "loot", prog)
                            end
                        end
                    end
                end
            end
        end
    end
    -- quest givers in this zone (available quests you have not skipped)
    if ns.db.showAvailable then
        local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        for _, q in ipairs(map and Data:AvailableOnMap(map, UnitLevel("player")) or {}) do
            local npc = q.point and q.point.npc
            if npc and not wanted[Data:NpcName(npc) or ""] then put(wanted, Data:NpcName(npc), "giver") end
        end
    end
end

---------------------------------------------------------------------------
-- Overlay frames
---------------------------------------------------------------------------
local function acquire()
    local f = table.remove(pool)
    if f then return f end
    f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(110, 30)
    f.glow = f:CreateTexture(nil, "BACKGROUND")
    f.glow:SetPoint("CENTER")
    f.glow:SetBlendMode("ADD")
    f.icon = f:CreateTexture(nil, "OVERLAY")
    f.icon:SetSize(22, 22)
    f.text = f:CreateFontString(nil, "OVERLAY")
    f.text:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    return f
end

local function release(unit)
    local f = marks[unit]
    if not f then return end
    f:Hide()
    f:ClearAllPoints()
    f:SetParent(UIParent)
    marks[unit] = nil
    pool[#pool + 1] = f
end

local function style(f, kind)
    local db = ns.db
    local c = Plates.COLORS[db.plateGlowColor] or Plates.COLORS.gold
    local a = db.plateGlowStrength or 0.7
    if not db.plateGlow then
        f.glow:Hide()
    else
        local ok
        if db.plateGlowStyle == "ring" then
            ok = f.glow:SetTexture(RING_TEX)
            f.glow:SetSize(150, 56)
        else
            ok = f.glow:SetTexture(GLOW_TEX)
            f.glow:SetSize(170, 60)
        end
        if ok == false then
            -- texture missing on this client: fall back to a soft oval
            f.glow:SetTexture("Interface\\Buttons\\WHITE8X8")
            if f.glow.SetMask then pcall(f.glow.SetMask, f.glow, "Interface\\CharacterFrame\\TempPortraitAlphaMask") end
        end
        f.glow:SetVertexColor(c[1], c[2], c[3])
        f.glow:SetAlpha(a)
        f.glow:Show()
    end
    f.icon:SetTexture(ICON[kind] or ICON.kill)
    f.icon:ClearAllPoints()
    f.icon:SetPoint("BOTTOM", f, "TOP", 0, 2)
    f.text:ClearAllPoints()
    f.text:SetPoint("LEFT", f.icon, "RIGHT", 2, 0)
end

local function markUnit(unit)
    if not ns.db.plateMarks or not wanted then release(unit) return end
    if IsInInstance and IsInInstance() then release(unit) return end -- locked by the game in instances
    local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unit)
    if not plate then release(unit) return end
    local name = UnitName(unit)
    -- check secrecy FIRST: even comparing a secret value to nil is not allowed
    if isSecret(name) or name == nil then return end -- unknown right now: keep whatever is there
    local w = wanted[name]
    if not w then release(unit) return end
    local f = marks[unit] or acquire()
    marks[unit] = f
    f:SetParent(plate)
    f:ClearAllPoints()
    f:SetPoint("CENTER", plate, "CENTER", 0, 0)
    f:SetFrameLevel((plate.GetFrameLevel and plate:GetFrameLevel() or 1) + 10)
    style(f, w.kind)
    f.text:SetText(w.progress or "")
    f:Show()
end

function Plates:RefreshAll()
    if not wanted then self:Rebuild() end
    local plates = C_NamePlate and C_NamePlate.GetNamePlates and C_NamePlate.GetNamePlates() or {}
    local seen = {}
    for _, plate in ipairs(plates) do
        local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
        if unit then seen[unit] = true markUnit(unit) end
    end
    for unit in pairs(marks) do if not seen[unit] then release(unit) end end
end

-- make sure the plates we need are actually shown (enemy + friendly NPC nameplates, max range)
function Plates:ApplyCVars()
    if not (ns.db.plateMarks and ns.db.plateCVars and SetCVar and not InCombatLockdown()) then return end
    pcall(SetCVar, "nameplateShowEnemies", "1")
    pcall(SetCVar, "nameplateShowFriendlyNPCs", "1")
    local cur = tonumber(GetCVar and GetCVar("nameplateMaxDistance") or "") or 0
    if cur < 41 then pcall(SetCVar, "nameplateMaxDistance", "41") end
end

---------------------------------------------------------------------------
function Plates:OnInit()
    local dirty = true
    local function rebuildSoon() dirty = true end
    for _, ev in ipairs({ "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED",
        "PLAYER_LEVEL_UP", "ZONE_CHANGED_NEW_AREA" }) do
        ns:On(ev, rebuildSoon)
    end
    ns:On("NAME_PLATE_UNIT_ADDED", function(_, unit) if wanted then markUnit(unit) end end)
    ns:On("NAME_PLATE_UNIT_REMOVED", function(_, unit) release(unit) end)
    ns:On("PLAYER_LOGIN", function() Plates:ApplyCVars() end)

    local t = 0
    local ticker = CreateFrame("Frame")
    ticker:SetScript("OnUpdate", function(_, e)
        -- pulse style: breathe the glow
        if ns.db.plateGlow and ns.db.plateGlowStyle == "pulse" then
            pulseT = pulseT + e
            local base = ns.db.plateGlowStrength or 0.7
            local a = base * (0.45 + 0.55 * (0.5 + 0.5 * math.sin(pulseT * 4)))
            for _, f in pairs(marks) do f.glow:SetAlpha(a) end
        end
        t = t + e
        if t < 0.5 then return end
        t = 0
        if dirty then dirty = false Plates:Rebuild() end
        Plates:RefreshAll()
    end)
end

function Plates:OnRefresh()
    self:ApplyCVars()
    wanted = nil
    self:RefreshAll()
end
