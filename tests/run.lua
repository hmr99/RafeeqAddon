-- tests/run.lua - plays Rafeeq like a user inside the emulator and reports problems.
-- Run through tests/run.py (uses Lua 5.1 via lupa). Env:
--   QDB_PATH   path to a QuestieDB checkout (optional; without it data features are tested "off")
--   ADDON_PATH path to the Rafeeq addon folder (default ./Rafeeq)

local QDB_PATH = os.getenv("QDB_PATH")
local ADDON = os.getenv("ADDON_PATH") or "Rafeeq"
local results, current = {}, nil

---------------------------------------------------------------------------
-- 1) QuestieDB (its own emulator installs stubs; ours replaces them afterwards)
---------------------------------------------------------------------------
local qdbLoaded = type(LibQuestieDB) == "table" and QDB_PRELOADED == true

local W = dofile("tests/wow.lua")

---------------------------------------------------------------------------
-- 2) Load addon files from the TOC, watching for leaked globals
---------------------------------------------------------------------------
local ALLOWED_GLOBALS = {
    RafeeqDB = true, RafeeqCharDB = true, SLASH_RAFEEQ1 = true, SLASH_RAFEEQ2 = true,
    RafeeqTracker = true, RafeeqArrow = true, RafeeqSuggest = true, RafeeqOptions = true, RafeeqMacros = true, RafeeqLanguagePicker = true, RafeeqNavBanner = true,
}
local before = {}
for k in pairs(_G) do before[k] = true end

local ns = {}
local tocFiles = {}
for line in io.lines(ADDON .. "/Rafeeq.toc") do
    line = line:gsub("\r", "")
    if line ~= "" and not line:match("^#") then tocFiles[#tocFiles + 1] = (line:gsub("\\", "/")) end
end
for _, f in ipairs(tocFiles) do
    local chunk, err = loadfile(ADDON .. "/" .. f)
    if not chunk then
        W.errors[#W.errors + 1] = { msg = "load " .. f .. ": " .. err, trace = "" }
    else
        W.safe(chunk, "Rafeeq", ns)
    end
end

---------------------------------------------------------------------------
-- harness
---------------------------------------------------------------------------
local function check(cond, msg)
    if not cond then current.fails[#current.fails + 1] = msg end
end

local function scenario(name, fn)
    current = { name = name, fails = {} }
    local errBefore = #W.errors
    local ok, err = pcall(fn)
    if not ok then current.fails[#current.fails + 1] = "test crashed: " .. tostring(err) end
    for i = errBefore + 1, #W.errors do
        current.fails[#current.fails + 1] = "Lua error: " .. W.errors[i].msg
    end
    results[#results + 1] = current
end

local function textOf(root) return table.concat(W.textsOf(root), " | ") end
local function chatHas(pat) for _, l in ipairs(W.chat) do if l:find(pat) then return true end end return false end
local function setLog(list) W.log = list W.fire("QUEST_LOG_UPDATE") W.advance(0.5) end

---------------------------------------------------------------------------
-- 3) Scenarios: a play session
---------------------------------------------------------------------------
scenario("login", function()
    W.fire("ADDON_LOADED", "Rafeeq")
    W.fire("PLAYER_LOGIN")
    W.fire("PLAYER_ENTERING_WORLD")
    W.advance(1)
    check(RafeeqTracker and RafeeqTracker:IsShown(), "tracker not shown after login")
    check(type(RafeeqDB) == "table", "saved variables missing")
    check(RafeeqDB.language == nil, "language should not be pre-chosen on first login")
    check(RafeeqLanguagePicker and RafeeqLanguagePicker:IsShown(), "first-run language picker not shown")
    -- pick Arabic in the picker
    for _, f in ipairs(W.frames) do
        if f._parent == RafeeqLanguagePicker and f._kind == "Button" then
            for _, c in ipairs(W.frames) do
                if c._parent == f and c._kind == "FontString" and c._font and c._font:find("RafeeqArabic") then f:Click() end
            end
        end
    end
    check(RafeeqDB.language == "ar", "picker did not set Arabic")
    check(not RafeeqLanguagePicker:IsShown(), "picker did not close")
    if qdbLoaded then check(ns.Data.ready, "QuestieDB present but data layer not ready")
    else check(chatHas("QuestieDB not found") or not ns.Data.ready, "no warning when QuestieDB missing") end
end)

scenario("leaked globals", function()
    for k in pairs(_G) do
        if not before[k] and not ALLOWED_GLOBALS[k] then check(false, "unexpected global: " .. tostring(k)) end
    end
end)

scenario("empty quest log", function()
    setLog({})
    check(textOf(RafeeqTracker) ~= "", "tracker shows nothing for empty log")
end)

scenario("accept quests -> tracker", function()
    W.rewardXP = { [7] = 250, [33] = 300 }
    setLog({
        { questID = 7, title = "Kobold Camp Cleanup", level = 2, objectives = { { text = "Kobold Vermin slain: 4/10", finished = false } } },
        { questID = 33, title = "Wolves Across the Border", level = 2, objectives = { { text = "Tough Wolf Meat: 2/8", finished = false } } },
    })
    local t = textOf(RafeeqTracker)
    check(t:find("Kobold Camp Cleanup"), "quest title missing from tracker")
    check(t:find("250 xp"), "per-quest XP missing")
    check(t:find("4/10"), "objective progress missing")
end)

scenario("tracker clicks (collapse, shift = arrow)", function()
    local row
    for _, f in ipairs(W.frames) do if f.questID == 7 and f._kind == "Button" then row = f end end
    check(row, "quest row button not found")
    if not row then return end
    row:Click("LeftButton")
    check(RafeeqCharDB.collapsed[7], "left click did not collapse quest")
    row:Click("LeftButton")
    W.shift = true row:Click("LeftButton") W.shift = false
    if qdbLoaded then
        local t = ns.Nav:Target()
        check(t and t.questID == 7, "shift-click did not start the guide arrow")
    end
end)

scenario("arrow follows player", function()
    if not qdbLoaded then return end
    ns.Nav:SetQuest(7)
    W.advance(2.5)
    check(RafeeqArrow and RafeeqArrow:IsShown(), "arrow frame not visible")
    local dist = textOf(RafeeqArrow)
    check(dist:find("yd"), "arrow distance missing: " .. dist)
    W.facing = math.pi W.advance(0.2)
    W.px, W.py = 0.505, 0.376 W.advance(2.5)
    W.instance = true W.advance(0.5) W.instance = false -- no position inside instances
end)

scenario("auto-run guidance: turn hints, arrival, drift", function()
    W.map, W.px, W.py, W.facing, W.speed = 1429, 0.48, 0.42, 0, 0
    local function hintText()
        for _, f in ipairs(W.frames) do
            if f._parent == RafeeqArrow and f._kind == "FontString" and f._shown then
                for _, k in ipairs({ "NAV_AHEAD", "NAV_LEFT", "NAV_RIGHT", "NAV_BEHIND" }) do
                    if f._text == ns.L(k) then return k end
                end
            end
        end
    end
    ns.Nav:SetPoint(1429, 48, 30, "north")   W.advance(0.2)
    check(hintText() == "NAV_AHEAD", "north target while facing north should be 'ahead', got " .. tostring(hintText()))
    ns.Nav:SetPoint(1429, 40, 42, "west")    W.advance(0.2)
    check(hintText() == "NAV_LEFT", "west target while facing north should be 'turn left', got " .. tostring(hintText()))
    ns.Nav:SetPoint(1429, 56, 42, "east")    W.advance(0.2)
    check(hintText() == "NAV_RIGHT", "east target should be 'turn right', got " .. tostring(hintText()))
    ns.Nav:SetPoint(1429, 48, 55, "south")   W.advance(0.2)
    check(hintText() == "NAV_BEHIND", "south target should be 'behind', got " .. tostring(hintText()))
    -- drift: running west while the target is north
    ns.Nav:SetPoint(1429, 48, 30, "north")
    W.sounds = {} W.facing = math.pi / 2 W.speed = 7
    W.advance(3)
    check(#W.sounds >= 1 and W.sounds[1] == 846, "no drift alert while running off course")
    check(RafeeqNavBanner:IsShown(), "drift banner not shown")
    -- arrival: once only
    W.sounds = {} W.facing = 0 W.py = 0.31 W.advance(0.5) W.advance(2)
    local arrivals = 0
    for _, id in ipairs(W.sounds) do if id == 8960 then arrivals = arrivals + 1 end end
    check(arrivals == 1, "arrival alert should fire exactly once, fired " .. arrivals)
    -- options off -> silence
    RafeeqDB.arrivalAlert, RafeeqDB.driftAlert = false, false
    ns.Nav:SetPoint(1429, 48, 20, "far north") W.sounds = {} W.facing = math.pi / 2 W.advance(3)
    check(#W.sounds == 0, "alerts played while disabled")
    RafeeqDB.arrivalAlert, RafeeqDB.driftAlert = true, true
    W.speed, W.facing, W.px, W.py = 0, 0, 0.48, 0.42
    ns.Nav:Clear()
end)

scenario("arrow: walk onto the point, banner expires, same spot again", function()
    W.map, W.px, W.py, W.facing, W.speed = 1429, 0.48, 0.42, 0, 7
    local function arrivals()
        local n = 0
        for _, id in ipairs(W.sounds) do if id == 8960 then n = n + 1 end end
        return n
    end
    -- run north to a flag; arrive (~25 yd) and keep running straight onto it
    W.sounds = {}
    ns.Nav:SetPoint(1429, 48, 35, "flag") W.advance(0.2)
    W.py = 0.36 W.advance(0.2)
    check(arrivals() == 1, "no arrival alert at the flag")
    check(RafeeqNavBanner:IsShown(), "arrival banner not shown")
    W.py = 0.35 W.advance(0.2)
    check(not RafeeqArrow:IsShown(), "arrow did not clear on reaching the point")
    W.advance(5)
    check(not RafeeqNavBanner:IsShown(), "arrival banner stuck on screen after the arrow cleared")
    -- the player sets the same flag again from further away: must announce again
    W.py = 0.42 W.sounds = {}
    ns.Nav:SetPoint(1429, 48, 35, "flag") W.advance(0.2)
    W.py = 0.36 W.advance(0.2)
    check(arrivals() == 1, "re-targeting the same spot did not announce arrival again")
    ns.Nav:Clear() W.advance(4)
    W.speed, W.px, W.py = 0, 0.48, 0.42
end)

scenario("arrow never shows a stale turn hint (no data / no position)", function()
    if not qdbLoaded then return end
    local function arrowTexts() return textOf(RafeeqArrow) end
    W.map, W.px, W.py, W.facing = 1429, 0.48, 0.42, 0
    -- give the arrow a real direction first, so a stale hint would exist
    ns.Nav:SetPoint(1429, 56, 42, "east") W.advance(0.2)
    check(arrowTexts():find(ns.L("NAV_RIGHT"), 1, true), "setup: expected a turn hint")
    -- 96873 'A Pain in the Neck': QuestieDB has no drop data for its item
    W.log[#W.log + 1] = { questID = 96873, title = "A Pain in the Neck", level = 8,
        objectives = { { text = "Luminous Residue: 0/3", finished = false } } }
    ns.Nav:SetQuest(96873) W.advance(2.5)
    local t = arrowTexts()
    for _, k in ipairs({ "NAV_AHEAD", "NAV_LEFT", "NAV_RIGHT", "NAV_BEHIND" }) do
        check(not t:find(ns.L(k), 1, true), "turn hint shown without a location: " .. k)
    end
    check(t:find(ns.L("NAV_NO_DATA"), 1, true), "no-data message missing: " .. t)
    check(t:find("Durotar", 1, true), "quest zone missing from label: " .. t)
    -- a quest with data, then lose position (instance): hint must go away, target kept
    ns.Nav:SetQuest(7) W.advance(2.5)
    W.instance = true W.advance(2.5)
    t = arrowTexts()
    for _, k in ipairs({ "NAV_AHEAD", "NAV_LEFT", "NAV_RIGHT", "NAV_BEHIND" }) do
        check(not t:find(ns.L(k), 1, true), "turn hint shown with unknown position: " .. k)
    end
    W.instance = false W.advance(2.5)
    check(arrowTexts():find("yd"), "arrow did not recover after leaving the instance")
    table.remove(W.log) ns.Nav:Clear()
end)

scenario("suggestions: nearby + available + skip", function()
    if not qdbLoaded then return end
    W.done[783] = true
    W.px, W.py = 0.48, 0.42
    W.fire("QUEST_TURNED_IN", 783)
    W.advance(3.5)
    local s = RafeeqSuggest and textOf(RafeeqSuggest) or ""
    check(s ~= "", "suggestion panel empty")
    -- press Skip on the first available quest
    local skipBtn
    for _, f in ipairs(W.frames) do
        if f._kind == "Button" and f._parent and f._parent.questID and not f._parent.isActive
            and f._parent._shown and f == f._parent.skip then skipBtn = f break end
    end
    if skipBtn then
        local id = skipBtn._parent.questID
        skipBtn:Click()
        check(RafeeqCharDB.skipped[id], "skip did not record quest")
    end
end)

scenario("world map + minimap pins", function()
    WorldMapFrame:Show()
    W.advance(0.3)
    if qdbLoaded then
        local pins = 0
        for _, f in ipairs(W.frames) do if f._parent == WorldMapFrame.ScrollContainer.Child and f._shown then pins = pins + 1 end end
        check(pins > 0, "no pins on world map")
    end
    WorldMapFrame:Hide()
    W.cvars.rotateMinimap = "1" W.advance(0.3) W.cvars.rotateMinimap = "0"
end)

scenario("pins show on any map that contains the target", function()
    if not qdbLoaded then return end
    local child = WorldMapFrame.ScrollContainer.Child
    local function shownPins()
        local n = 0
        for _, f in ipairs(W.frames) do if f._parent == child and f._shown and f.data then n = n + 1 end end
        return n
    end
    ns.Pins:Refresh()
    W.viewMap = 1415 WorldMapFrame:Show() W.advance(0.3)
    check(shownPins() > 0, "no pins on the continent map for Elwynn objectives")
    WorldMapFrame:Hide()
    W.viewMap = 99999 WorldMapFrame:Show() W.advance(0.3)
    check(shownPins() == 0, "pins drawn on a map that does not contain them: " .. shownPins())
    WorldMapFrame:Hide()
    W.viewMap = nil
    -- arrow names the target zone when it is not your current zone
    W.map = 1411 ns.Nav:SetQuest(7) W.advance(2.5)
    local label = textOf(RafeeqArrow)
    check(label:find("Elwynn Forest", 1, true), "arrow label does not name the target zone: " .. label)
    W.map = 1429 W.advance(2.5)
    label = textOf(RafeeqArrow)
    check(not label:find(" - Elwynn Forest", 1, true), "zone suffix shown while already in that zone: " .. label)
    ns.Nav:Clear()
end)

scenario("quest complete -> ready + turn-in arrow", function()
    W.log[1].complete = true
    W.log[1].objectives[1].finished = true
    W.fire("QUEST_LOG_UPDATE") W.advance(2.5)
    check(textOf(RafeeqTracker) ~= "", "tracker broke on completion")
end)

scenario("automation: gossip / accept / turn-in rules", function()
    W.gossip = { active = { { questID = 7, isComplete = true } }, available = { { questID = 60, isTrivial = false } } }
    W.fire("GOSSIP_SHOW")
    check(W.gossipPicked and W.gossipPicked[1] == "active", "did not pick completed quest in gossip")
    W.gossip = { active = {}, available = { { questID = 60, isTrivial = true }, { questID = 61, isTrivial = false } } }
    W.gossipPicked = nil W.fire("GOSSIP_SHOW")
    check(W.gossipPicked and W.gossipPicked[2] == 61, "trivial quest not skipped")
    W.shift = true W.gossipPicked = nil W.fire("GOSSIP_SHOW") W.shift = false
    check(W.gossipPicked == nil, "shift did not pause automation")
    W.fire("QUEST_DETAIL") check(#W.accepted > 0, "quest not auto-accepted")
    W.questChoices = 3 W.turnedIn = {} W.fire("QUEST_COMPLETE")
    check(#W.turnedIn == 0, "auto-picked a reward when a choice was required")
    W.questChoices = 1 W.questMoney = 500 W.fire("QUEST_COMPLETE")
    check(#W.turnedIn == 0, "turned in a quest that costs gold")
    W.questMoney = 0 W.fire("QUEST_COMPLETE")
    check(#W.turnedIn == 1, "did not turn in a simple quest")
end)

scenario("merchant: sell greys + repair", function()
    W.bags = { [0] = { [1] = { quality = 0, hyperlink = "item:grey1", price = 12, stackCount = 3 },
        [2] = { quality = 4, hyperlink = "item:epic", price = 9000 },
        [3] = { quality = 0, hyperlink = "item:grey2", price = 5 },
        [4] = { quality = 0, hyperlink = "item:quest", price = 0 } } }
    W.repairCost = 700
    MerchantFrame._shown = true
    W.fire("MERCHANT_SHOW") W.advance(2)
    check(#W.sold == 2, "expected 2 greys sold, got " .. #W.sold)
    for _, l in ipairs(W.sold) do check(l ~= "item:epic", "SOLD AN EPIC ITEM") end
    check(W.repaired == "self", "did not repair")
    -- not enough gold
    W.repairCost, W.money, W.repaired = 50000, 100, nil
    W.fire("MERCHANT_SHOW") W.advance(1)
    check(W.repaired == nil, "repair attempted without gold")
    -- vendor closed mid-sale must stop selling
    W.money = 10000
    W.bags = { [0] = { [1] = { quality = 0, hyperlink = "item:g3", price = 1 }, [2] = { quality = 0, hyperlink = "item:g4", price = 1 } } }
    W.sold = {}
    W.fire("MERCHANT_SHOW") MerchantFrame._shown = false W.advance(1)
    check(#W.sold <= 1, "kept selling after vendor closed")
end)

scenario("level up: trainer reminder + ETA", function()
    W.time = W.time + 300
    W.xp = 600 W.fire("PLAYER_XP_UPDATE") W.advance(0.5)
    W.level = 6 W.xp = 20 W.fire("PLAYER_LEVEL_UP", 6) W.fire("PLAYER_XP_UPDATE") W.advance(0.5)
    check(chatHas("trainer"), "no trainer reminder at even level")
    local secs = ns.QoL:TimeToLevel()
    check(secs and secs > 0, "no time-to-level estimate")
end)

scenario("rank updater respects combat", function()
    W.spells["Heroic Strike"] = { id = 78, best = 284, cd = 0 }
    W.actions = { [1] = 78 }
    W.enterCombat()
    W.fire("LEARNED_SPELL_IN_TAB") W.advance(1)
    check(W.actions[1] == 78, "changed action bar during combat")
    W.leaveCombat() W.advance(0.2)
    check(W.actions[1] == 284, "did not upgrade rank after combat")
end)

scenario("macro maker", function()
    W.spells["Victory Rush"] = { id = 34428, cd = 0 }
    W.spells["Thunder Clap"] = { id = 6343, cd = 4000 }
    W.spells["Bloodrage"] = { id = 2687, cd = 60000 }
    W.spells["Charge"] = { id = 100, cd = 15000 }
    ns.Macros:BuildAll()
    check(W.macros.RF_ST and W.macros.RF_ST:find("Victory Rush"), "RF_ST missing spells")
    check(W.macros.RF_CD and W.macros.RF_CD:find("Bloodrage"), "RF_CD missing long cooldown")
    check(W.macros.RF_CD and not W.macros.RF_CD:find("Thunder Clap"), "RF_CD has a <7s cooldown spell")
    for n, b in pairs(W.macros) do check(#b <= 255, n .. " longer than 255") end
    W.enterCombat() ns.Macros:BuildAll() W.leaveCombat()
    check(chatHas("combat"), "no combat warning for macros")
    ns.Macros:Toggle() ns.Macros:Toggle()
end)

scenario("options: every checkbox + language", function()
    SlashCmdList.RAFEEQ("")
    for _, f in ipairs(W.frames) do
        if f._kind == "CheckButton" and f._shown then
            f._checked = not f._checked f:Click() f._checked = not f._checked f:Click()
        end
    end
    SlashCmdList.RAFEEQ("en") W.advance(0.3)
    SlashCmdList.RAFEEQ("ar") W.advance(0.3)
    SlashCmdList.RAFEEQ("")
end)

scenario("language: header toggle + option tabs", function()
    local btn = RafeeqTracker and select(1, (function()
        for _, f in ipairs(W.frames) do if f._parent and f._parent._parent == RafeeqTracker and f._kind == "Button" and f.text then return f end end
    end)())
    check(btn, "language button on tracker header not found")
    if btn then
        btn:Click() check(RafeeqDB.language == "en", "header toggle did not switch to English")
        btn:Click() check(RafeeqDB.language == "ar", "header toggle did not switch back to Arabic")
    end
    SlashCmdList.RAFEEQ("")
    local tabs = 0
    for _, f in ipairs(W.frames) do
        if f.lang and f._parent == RafeeqOptions then
            tabs = tabs + 1 f:Click() check(RafeeqDB.language == f.lang, "tab did not switch to " .. f.lang)
        end
    end
    check(tabs == 2, "expected 2 language tabs, found " .. tabs)
    SlashCmdList.RAFEEQ("lang") SlashCmdList.RAFEEQ("ar")
    SlashCmdList.RAFEEQ("")
end)

scenario("slash commands", function()
    for _, c in ipairs({ "help", "toggle", "toggle", "reset", "scale 1.2", "scale 9", "scale x", "arrow",
        "unskip", "macro", "macro", "ar", "en", "ar", "" }) do
        SlashCmdList.RAFEEQ(c) W.advance(0.2)
    end
    check(RafeeqDB.scale == 1.2, "scale command failed")
end)

scenario("long session stress", function()
    for i = 1, 60 do
        W.px = 0.40 + (i % 10) / 100
        W.facing = (i * 0.3) % (2 * math.pi)
        if i % 7 == 0 then W.fire("QUEST_LOG_UPDATE") end
        if i % 13 == 0 then WorldMapFrame:Show() elseif i % 13 == 1 then WorldMapFrame:Hide() end
        W.advance(0.5)
    end
end)

scenario("leaked globals (end of session)", function()
    for k in pairs(_G) do
        if not before[k] and not ALLOWED_GLOBALS[k] then check(false, "unexpected global: " .. tostring(k)) end
    end
end)

---------------------------------------------------------------------------
-- 4) Report
---------------------------------------------------------------------------
local failed = 0
print(("Rafeeq emulator run - QuestieDB: %s"):format(qdbLoaded and "loaded" or "not loaded"))
for _, r in ipairs(results) do
    if #r.fails == 0 then
        print("  PASS  " .. r.name)
    else
        failed = failed + 1
        print("  FAIL  " .. r.name)
        local seen = {}
        for _, f in ipairs(r.fails) do
            if not seen[f] then seen[f] = true print("        - " .. f) end
        end
    end
end
print(("%d/%d scenarios passed"):format(#results - failed, #results))
RESULT_FAILED = failed
