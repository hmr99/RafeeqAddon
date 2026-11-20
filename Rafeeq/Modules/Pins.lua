-- Rafeeq: world map + minimap pins for quest objectives, turn-ins and available quests.
local _, ns = ...
local L = ns.L
local Data = ns.Data

local Pins = ns:NewModule("Pins")
ns.Pins = Pins

local ICON = {
    kill      = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8",
    loot      = "Interface\\GossipFrame\\VendorGossipIcon",
    object    = "Interface\\GossipFrame\\BinderGossipIcon",
    finish    = "Interface\\GossipFrame\\ActiveQuestIcon",
    available = "Interface\\GossipFrame\\AvailableQuestIcon",
    flight    = "Interface\\TaxiFrame\\UI-Taxi-Icon-Green",
    repair    = "Interface\\GossipFrame\\VendorGossipIcon",
    inn       = "Interface\\GossipFrame\\BinderGossipIcon",
    trainer   = "Interface\\GossipFrame\\TrainerGossipIcon",
}
Pins.ICON = ICON

local KIND_LABEL = { kill = "Kill", loot = "Loot", object = "Use", finish = "Turn in", available = "New quest" }

---------------------------------------------------------------------------
-- Collect what to draw: { map, x, y, kind, questID, text }
---------------------------------------------------------------------------
local cache, dirty = {}, true

function Pins:Collect()
    if not dirty then return cache end
    dirty = false
    cache = {}
    if not Data.ready then return cache end
    local Q = ns.QuestAPI
    local n = Q and Q.NumEntries() or 0
    for i = 1, n do
        local e = Q.Entry(i)
        if e and not e.isHeader and e.questID then
            local title = e.title or ""
            if e.isComplete then
                for _, p in ipairs(Data:FinisherPoints(e.questID)) do
                    cache[#cache + 1] = { map = p.map, x = p.x, y = p.y, kind = "finish", questID = e.questID,
                        text = title }
                end
            else
                local pts = ns.Nav:QuestPoints(e.questID)
                -- tag kind per objective for icons
                for _, obj in ipairs(Data:QuestObjectives(e.questID)) do
                    for _, p in ipairs(obj.points) do
                        for _, w in ipairs(pts) do
                            if w == p then
                                cache[#cache + 1] = { map = p.map, x = p.x, y = p.y, kind = obj.kind,
                                    questID = e.questID, text = title .. "\n" .. (obj.name or "") }
                                break
                            end
                        end
                    end
                end
            end
        end
    end
    return cache
end

function Pins:MarkDirty() dirty = true end

---------------------------------------------------------------------------
-- Pin frames
---------------------------------------------------------------------------
local function makePin(parent, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    b.tex = b:CreateTexture(nil, "OVERLAY")
    b.tex:SetAllPoints()
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self.data.text or "", 1, 0.82, 0, true)
        GameTooltip:AddLine(KIND_LABEL[self.data.kind] or "", 0.7, 0.85, 1)
        GameTooltip:AddLine("Click: guide arrow here  |  Shift-click: skip quest", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:RegisterForClicks("LeftButtonUp")
    b:SetScript("OnClick", function(self)
        local d = self.data
        if IsShiftKeyDown() and d.kind == "available" then
            ns.char.skipped[d.questID] = true
            Pins:Refresh()
        elseif d.questID and d.kind ~= "available" then
            ns.Nav:SetQuest(d.questID)
        else
            ns.Nav:SetPoint(d.map, d.x, d.y, d.text)
        end
    end)
    return b
end

-- World map ------------------------------------------------------------
local mapPins, mapExtra = {}, {}

local function canvas()
    return WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child
end

function Pins:RefreshWorldMap()
    local child = canvas()
    if not child or not WorldMapFrame:IsShown() then return end
    for _, p in ipairs(mapPins) do p:Hide() end
    if not ns.db.mapPins then return end
    local mapID = WorldMapFrame:GetMapID()
    local w, h = child:GetWidth(), child:GetHeight()
    local scale = WorldMapFrame.ScrollContainer.GetCanvasScale and WorldMapFrame.ScrollContainer:GetCanvasScale() or 1
    local list = {}
    for _, d in ipairs(self:Collect()) do if d.map == mapID then list[#list + 1] = d end end
    if ns.db.showAvailable then
        for _, q in ipairs(Data:AvailableOnMap(mapID, UnitLevel("player"))) do
            list[#list + 1] = { map = mapID, x = q.point.x, y = q.point.y, kind = "available", questID = q.id,
                text = ("[%d] %s"):format(q.level or 0, q.name or "?") }
        end
    end
    for _, extra in ipairs(mapExtra) do
        for _, d in ipairs(extra(mapID) or {}) do list[#list + 1] = d end
    end
    for i, d in ipairs(list) do
        local pin = mapPins[i] or makePin(child, 16)
        mapPins[i] = pin
        pin.data = d
        pin.tex:SetTexture(d.icon or ICON[d.kind] or ICON.kill)
        pin:SetScale(1 / scale)
        pin:ClearAllPoints()
        pin:SetPoint("CENTER", child, "TOPLEFT", (d.x / 100) * w * scale, -(d.y / 100) * h * scale)
        pin:SetFrameLevel(child:GetFrameLevel() + 2000)
        pin:Show()
    end
end

-- other modules can add layers (flight paths, vendors, nodes...)
function Pins:AddMapLayer(fn) mapExtra[#mapExtra + 1] = fn end

-- Minimap --------------------------------------------------------------
local miniPins = {}
local MM_YARDS = { [0] = 233, 200, 166, 133, 100, 66 } -- outdoor radius by zoom level

local function minimapRadius()
    if C_Minimap and C_Minimap.GetViewRadius then
        local r = C_Minimap.GetViewRadius()
        if r and r > 0 then return r end
    end
    return MM_YARDS[Minimap:GetZoom()] or 150
end

local mmElapsed = 0
local function updateMinimap()
    for _, p in ipairs(miniPins) do p:Hide() end
    if not ns.db.minimapPins then return end
    local _, _, _, pc, pwx, pwy = Data:Player()
    if not pc then return end
    local radius = minimapRadius()
    local half = Minimap:GetWidth() / 2
    local rotate = GetCVar and GetCVar("rotateMinimap") == "1"
    local facing = rotate and GetPlayerFacing and GetPlayerFacing() or 0
    local cosF, sinF = math.cos(facing or 0), math.sin(facing or 0)
    local i = 0
    for _, d in ipairs(Pins:Collect()) do
        local c, wx, wy = Data:World(d.map, d.x, d.y)
        if c == pc then
            local north, west = wx - pwx, wy - pwy
            if north * north + west * west < radius * radius then
                local px, py = -west, north
                if rotate then
                    px, py = px * cosF + py * sinF, -px * sinF + py * cosF
                end
                i = i + 1
                local pin = miniPins[i] or makePin(Minimap, 12)
                miniPins[i] = pin
                pin.data = d
                pin.tex:SetTexture(ICON[d.kind] or ICON.kill)
                pin:ClearAllPoints()
                pin:SetPoint("CENTER", Minimap, "CENTER", px / radius * half, py / radius * half)
                pin:SetFrameLevel(Minimap:GetFrameLevel() + 5)
                pin:Show()
                if i >= 60 then return end
            end
        end
    end
end

function Pins:Refresh()
    dirty = true
    self:RefreshWorldMap()
    updateMinimap()
end

function Pins:OnInit()
    if WorldMapFrame then
        WorldMapFrame:HookScript("OnShow", function() Pins:RefreshWorldMap() end)
        if WorldMapFrame.OnMapChanged then
            hooksecurefunc(WorldMapFrame, "OnMapChanged", function() Pins:RefreshWorldMap() end)
        end
        if WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.OnCanvasScaleChanged then
            hooksecurefunc(WorldMapFrame.ScrollContainer, "OnCanvasScaleChanged", function() Pins:RefreshWorldMap() end)
        end
    end
    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function(_, e)
        mmElapsed = mmElapsed + e
        if mmElapsed > 0.1 then mmElapsed = 0 updateMinimap() end
    end)
    for _, ev in ipairs({ "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "PLAYER_LEVEL_UP" }) do
        ns:On(ev, function() dirty = true end)
    end
end

function Pins:OnRefresh() self:Refresh() end
