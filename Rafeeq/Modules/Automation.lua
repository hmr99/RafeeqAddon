local _, ns = ...

local Auto = ns:NewModule("Automation")

local function paused()
    return IsShiftKeyDown()
end

local function isTrivialLevel(level)
    if not level or not GetQuestDifficultyColor then return false end
    -- grey = trivial; compare with the trivial color table if the client exposes it
    local c = GetQuestDifficultyColor(level)
    local grey = QuestDifficultyColors and QuestDifficultyColors.trivial
    return grey and c and c.r == grey.r and c.g == grey.g and c.b == grey.b or false
end

---------------------------------------------------------------------------
-- Gossip window (modern C_GossipInfo)
---------------------------------------------------------------------------
local function onGossip()
    if paused() or not C_GossipInfo then return end
    local db = ns.db

    if db.autoTurnIn and C_GossipInfo.GetActiveQuests then
        for _, q in ipairs(C_GossipInfo.GetActiveQuests() or {}) do
            if q.isComplete then
                C_GossipInfo.SelectActiveQuest(q.questID)
                return
            end
        end
    end
    if db.autoAccept and C_GossipInfo.GetAvailableQuests then
        for _, q in ipairs(C_GossipInfo.GetAvailableQuests() or {}) do
            if not (db.skipTrivial and q.isTrivial) then
                C_GossipInfo.SelectAvailableQuest(q.questID)
                return
            end
        end
    end
end

---------------------------------------------------------------------------
-- Old-style quest greeting window
---------------------------------------------------------------------------
local function onGreeting()
    if paused() then return end
    local db = ns.db
    if db.autoTurnIn and GetNumActiveQuests then
        for i = 1, GetNumActiveQuests() do
            local _, isComplete = GetActiveTitle(i)
            if isComplete then SelectActiveQuest(i) return end
        end
    end
    if db.autoAccept and GetNumAvailableQuests then
        for i = 1, GetNumAvailableQuests() do
            local isTrivial = GetAvailableQuestInfo and select(1, GetAvailableQuestInfo(i))
            if not (db.skipTrivial and isTrivial) then
                SelectAvailableQuest(i)
                return
            end
        end
    end
end

---------------------------------------------------------------------------
-- Quest detail / progress / reward
---------------------------------------------------------------------------
local function onDetail()
    if paused() or not ns.db.autoAccept then return end
    if QuestGetAutoAccept and QuestGetAutoAccept() then
        if AcknowledgeAutoAcceptQuest then AcknowledgeAutoAcceptQuest() end
        return
    end
    -- trivial filtering happens at the gossip/greeting step (detail window has no level API everywhere)
    AcceptQuest()
end

local function onAcceptConfirm()
    if paused() or not ns.db.autoAccept then return end
    ConfirmAcceptQuest()
    if StaticPopup_Hide then StaticPopup_Hide("QUEST_ACCEPT") end
end

local function onProgress()
    if paused() or not ns.db.autoTurnIn then return end
    if IsQuestCompletable() then CompleteQuest() end
end

local function onComplete()
    if paused() or not ns.db.autoTurnIn then return end
    if GetQuestMoneyToGet and GetQuestMoneyToGet() > 0 then
        ns.Print("COSTS_MONEY")
        return
    end
    local choices = GetNumQuestChoices() or 0
    if choices > 1 then
        ns.Print("CHOICE_NEEDED")
        return
    end
    GetQuestReward(choices)
end

function Auto:OnInit()
    pcall(ns.On, ns, "GOSSIP_SHOW", onGossip)
    pcall(ns.On, ns, "QUEST_GREETING", onGreeting)
    pcall(ns.On, ns, "QUEST_DETAIL", onDetail)
    pcall(ns.On, ns, "QUEST_ACCEPT_CONFIRM", onAcceptConfirm)
    pcall(ns.On, ns, "QUEST_PROGRESS", onProgress)
    pcall(ns.On, ns, "QUEST_COMPLETE", onComplete)
end

ns.IsTrivialLevel = isTrivialLevel
