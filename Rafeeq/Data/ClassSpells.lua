-- Rafeeq: starting spell priorities for the auto macro maker.
-- Order = priority: the game casts the first line that can fire this press, so put
-- cooldown/proc spells first and the filler last. Spells you don't know are dropped.
-- These are starting templates; edit the generated macros freely in-game.
local _, ns = ...

ns.ClassSpells = {
    WARRIOR = {
        st  = { "Victory Rush", "Execute", "Overpower", "Mortal Strike", "Bloodthirst", "Shield Slam", "Revenge",
                "Heroic Strike" },
        aoe = { "Thunder Clap", "Whirlwind", "Demoralizing Shout", "Cleave" },
        cd  = { "Recklessness", "Death Wish", "Sweeping Strikes", "Bloodrage", "Berserker Rage", "Intercept",
                "Mortal Strike", "Bloodthirst", "Whirlwind", "Thunder Clap", "Shield Slam", "Concussion Blow" },
        startAttack = true,
    },
    ROGUE = {
        st  = { "Riposte", "Ghostly Strike", "Hemorrhage", "Sinister Strike" },
        aoe = { "Blade Flurry", "Sinister Strike" },
        cd  = { "Adrenaline Rush", "Blade Flurry", "Cold Blood", "Preparation", "Riposte", "Ghostly Strike",
                "Kidney Shot", "Gouge" },
        startAttack = true,
    },
    MAGE = {
        st  = { "Fire Blast", "Frostbolt" },
        aoe = { "Frost Nova", "Cone of Cold", "Blast Wave", "Arcane Explosion" },
        cd  = { "Arcane Power", "Presence of Mind", "Combustion", "Cold Snap", "Fire Blast", "Cone of Cold",
                "Blast Wave", "Frost Nova" },
    },
    PRIEST = {
        st  = { "Mind Blast", "Mind Flay", "Smite" },
        aoe = { "Holy Nova", "Mind Blast", "Smite" },
        cd  = { "Power Infusion", "Inner Focus", "Mind Blast", "Psychic Scream", "Silence", "Vampiric Embrace" },
    },
    WARLOCK = {
        st  = { "Conflagrate", "Shadowburn", "Death Coil", "Shadow Bolt" },
        aoe = { "Hellfire", "Rain of Fire" },
        cd  = { "Amplify Curse", "Conflagrate", "Shadowburn", "Death Coil", "Howl of Terror" },
    },
    HUNTER = {
        st  = { "Kill Command", "Aimed Shot", "Arcane Shot", "Mongoose Bite", "Raptor Strike", "Steady Shot" },
        aoe = { "Multi-Shot", "Volley", "Explosive Trap" },
        cd  = { "Bestial Wrath", "Rapid Fire", "Intimidation", "Aimed Shot", "Arcane Shot", "Multi-Shot",
                "Kill Command", "Counterattack", "Wyvern Sting" },
        startAttack = false,
    },
    SHAMAN = {
        st  = { "Stormstrike", "Earth Shock", "Lightning Bolt" },
        aoe = { "Chain Lightning", "Fire Nova Totem", "Magma Totem" },
        cd  = { "Elemental Mastery", "Stormstrike", "Nature's Swiftness", "Earth Shock", "Chain Lightning",
                "Fire Nova Totem" },
        startAttack = true,
    },
    PALADIN = {
        st  = { "Hammer of Wrath", "Judgement", "Exorcism", "Holy Shock", "Crusader Strike" },
        aoe = { "Consecration", "Holy Wrath" },
        cd  = { "Divine Favor", "Holy Shield", "Judgement", "Exorcism", "Holy Shock", "Hammer of Justice",
                "Consecration", "Holy Wrath", "Hammer of Wrath", "Repentance" },
        startAttack = true,
    },
    DRUID = {
        -- form-aware: [form:1] bear, [form:3] cat (Classic numbering)
        st  = { "[form:1] Maul", "[form:3] Shred", "[form:3] Claw", "[noform] Wrath" },
        aoe = { "[form:1] Swipe", "[form:1] Demoralizing Roar", "[noform] Hurricane" },
        cd  = { "[form:1] Enrage", "[form:1] Bash", "[form:1] Frenzied Regeneration", "[form:3] Tiger's Fury",
                "Nature's Swiftness", "Barkskin", "Hurricane", "Faerie Fire (Feral)" },
        startAttack = true,
    },
}
