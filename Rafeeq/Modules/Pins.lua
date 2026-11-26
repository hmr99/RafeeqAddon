-- Rafeeq: world map + minimap pins for quest objectives, turn-ins and available quests.
local _, ns = ...
local L = ns.L
local Data = ns.Data

local Pins = ns:NewModule("Pins")
ns.Pins = Pins

local ICON = {
    kill      = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8",
    loot      = "Interface\\Icons\\INV_Misc_Bag_08",
    object    = "Interface\\Icons\\INV_Misc_Gear_01",
    finish    = "Interface\\GossipFrame\\ActiveQuestIcon",
    available = "Interface\\GossipFrame\\AvailableQuestIcon",
    flight    = "Interface\\TaxiFrame\\UI-Taxi-Icon-Green",
    repair    = "Interface\\GossipFrame\\VendorGossipIcon",
    inn       = "Interface\\GossipFrame\\BinderGossipIcon",
    trainer   = "Interface\\GossipFrame\\TrainerGossipIcon",
}
-- coloured ring per objective type, so pins read clearly on any map background
local RING = {
    kill = { 0.95, 0.25, 0.2 }, loot = { 1, 0.8, 0.2 }, object = { 0.3, 0.8, 1 },
    finish = { 1, 0.85, 0.1 }, available = { 1, 0.85, 0.1 },
}
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
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
local function masked(tex)
    if tex.SetMask then pcall(tex.SetMask, tex, MASK) end
end

local function makePin(parent, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    b.ring = b:CreateTexture(nil, "BACKGROUND")
    b.ring:SetAllPoints()
    b.ring:SetColorTexture(1, 1, 1, 1)
    masked(b.ring)
    b.bg = b:CreateTexture(nil, "BORDER")
    b.bg:SetPoint("TOPLEFT", 2, -2)
    b.bg:SetPoint("BOTTOMRIGHT", -2, 2)
    b.bg:SetColorTexture(0.05, 0.05, 0.08, 0.9)
    masked(b.bg)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetPoint("TOPLEFT", 3, -3)
    b.tex:SetPoint("BOTTOMRIGHT", -3, 3)
    masked(b.tex)
    b.count = b:CreateFontString(nil, "OVERLAY")
    b.count:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    b.count:SetPoint("BOTTOMRIGHT", 3, -2)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local lines = self.data.texts or { self.data.text }
        for i, line in ipairs(lines) do
            if i > 6 then GameTooltip:AddLine("...", 0.7, 0.7, 0.7) break end
            GameTooltip:AddLine(line or "", 1, 0.82, 0, true)
        end
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

local function stylePin(pin, d)
    pin.tex:SetTexture(d.icon or ICON[d.kind] or ICON.kill)
    local c = RING[d.kind] or { 0.8, 0.8, 0.8 }
    pin.ring:SetVertexColor(c[1], c[2], c[3], 1)
    pin.count:SetText((d.count or 1) > 1 and tostring(d.count) or "")
end

-- Merge pins that would overlap on screen into one pin with a count.
-- items carry sx, sy in screen pixels; available-quest pins never merge with objective pins.
local function cluster(items, cell)
    -- greedy: join the first group (same category) whose anchor is within `cell` pixels;
    -- avoids grid edges splitting pins that sit right next to each other
    local order = {}
    local cell2 = cell * cell
    for _, d in ipairs(items) do
        local cat = d.kind == "available" and "a" or "o"
        local g
        for _, cand in ipairs(order) do
            if cand.cat == cat then
                local dx, dy = cand.ax - d.sx, cand.ay - d.sy
                if dx * dx + dy * dy <= cell2 then g = cand break end
            end
        end
        if not g then
            g = { cat = cat, ax = d.sx, ay = d.sy, first = d, count = 0, sx = 0, sy = 0, texts = {}, seenText = {} }
            order[#order + 1] = g
        end
        g.count = g.count + 1
        g.sx, g.sy = g.sx + d.sx, g.sy + d.sy
        if d.text and not g.seenText[d.text] then
            g.seenText[d.text] = true
            g.texts[#g.texts + 1] = d.text
        end
    end
    local out = {}
    for _, g in ipairs(order) do
        local d = {}
        for k, v in pairs(g.first) do d[k] = v end
        d.count, d.texts = g.count, g.texts
        d.sx, d.sy = g.sx / g.count, g.sy / g.count
        out[#out + 1] = d
    end
    return out
end
Pins.Cluster = cluster

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
    -- objective/turn-in points from ANY map that fall inside the map being viewed
    -- (a Durotar target shows on the Durotar and Kalimdor maps; a city target on its zone map)
    for _, d in ipairs(self:Collect()) do
        if #list >= 400 then break end
        local x, y = Data:ProjectTo(mapID, d.map, d.x, d.y)
        if x then
            list[#list + 1] = { map = d.map, x = d.x, y = d.y, px = x, py = y, kind = d.kind,
                questID = d.questID, text = d.text }
        end
    end
    if ns.db.showAvailable then
        for _, q in ipairs(Data:AvailableOnMap(mapID, UnitLevel("player"))) do
            list[#list + 1] = { map = mapID, x = q.point.x, y = q.point.y, kind = "available", questID = q.id,
                text = ("[%d] %s"):format(q.level or 0, q.name or "?") }
        end
    end
    for _, extra in ipairs(mapExtra) do
        for _, d in ipairs(extra(mapID) or {}) do list[#list + 1] = d end
    end
    for _, d in ipairs(list) do
        local px, py = d.px or d.x, d.py or d.y
        d.sx, d.sy = (px / 100) * w * scale, (py / 100) * h * scale
    end
    list = cluster(list, 22)
    for i, d in ipairs(list) do
        local pin = mapPins[i] or makePin(child, 18)
        mapPins[i] = pin
        pin.data = d
        stylePin(pin, d)
        pin:SetScale(1 / scale)
        pin:ClearAllPoints()
        pin:SetPoint("CENTER", child, "TOPLEFT", d.sx, -d.sy)
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
    local near = {}
    for _, d in ipairs(Pins:Collect()) do
        local c, wx, wy = Data:World(d.map, d.x, d.y)
        if c == pc then
            local north, west = wx - pwx, wy - pwy
            if north * north + west * west < radius * radius then
                local px, py = -west, north
                if rotate then
                    px, py = px * cosF + py * sinF, -px * sinF + py * cosF
                end
                local item = {}
                for k, v in pairs(d) do item[k] = v end
                item.sx, item.sy = px / radius * half, -(py / radius * half)
                near[#near + 1] = item
            end
        end
    end
    for i, d in ipairs(cluster(near, 12)) do
        if i > 40 then break end
        local pin = miniPins[i] or makePin(Minimap, 14)
        miniPins[i] = pin
        pin.data = d
        stylePin(pin, d)
        pin:ClearAllPoints()
        pin:SetPoint("CENTER", Minimap, "CENTER", d.sx, -d.sy)
        pin:SetFrameLevel(Minimap:GetFrameLevel() + 5)
        pin:Show()
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
        -- map addons (MapWise) resize the canvas itself: pins are placed in canvas pixels, so follow it
        local child = canvas()
        if child and child.HookScript then
            child:HookScript("OnSizeChanged", function() Pins:RefreshWorldMap() end)
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
