local _, ns = ...

-- UI strings. Arabic is the default; English is a fallback / toggle.
local strings = {
    ar = {
        TRACKER_TITLE    = "المهام",
        READY            = "جاهزة للتسليم",
        FAILED           = "فشلت",
        NO_QUESTS        = "ما عندك مهام حالياً",
        READY_XP         = "خبرة المهام الجاهزة: %s",
        LEVEL_UP_HINT    = "تسليمها يرفعك لفل!",
        OPT_TITLE        = "رفيق - الإعدادات",
        OPT_ARABIC       = "واجهة عربية",
        OPT_LANGUAGE     = "اللغة",
        LANG_PICK        = "اختر لغة الإضافة - تقدر تغيرها أي وقت",
        OPT_AUTO_ACCEPT  = "قبول المهام تلقائياً",
        OPT_AUTO_TURNIN  = "تسليم المهام تلقائياً",
        OPT_SKIP_TRIVIAL = "تجاهل المهام الرمادية (السهلة جداً)",
        OPT_HIDE_BLIZZ   = "إخفاء متتبع المهام الأصلي",
        OPT_SHOW_XP      = "عرض الخبرة لكل مهمة",
        OPT_LOCK         = "قفل مكان المتتبع",
        OPT_SHIFT_NOTE   = "اضغط Shift عند فتح المحادثة لإيقاف الأتمتة مؤقتاً",
        OPT_SCALE        = "الحجم",
        HELP             = "الأوامر: /rf  /rf macro  /rf toggle  /rf reset  /rf scale 1.1",
        RESET_DONE       = "تمت إعادة مكان المتتبع",
        CHOICE_NEEDED    = "المهمة فيها اختيار جائزة - اختر بنفسك",
        COSTS_MONEY      = "المهمة تطلب ذهب - ما سلمتها تلقائياً",
        NEED_QDB_UPDATE  = "QuestieDB is too old - please update it",
        NO_QDB           = "QuestieDB not found - map pins, arrow and suggestions are off",
        NEARBY_TITLE     = "قريبة منك - خلصها الحين",
        AVAILABLE_TITLE  = "مهام متاحة في المنطقة",
        MACRO_TITLE      = "صانع الماكرو",
        MACRO_ST         = "هدف واحد (RF_ST)",
        MACRO_AOE        = "ضرب جماعي (RF_AOE)",
        MACRO_CD         = "كول داون فوق 7 ثواني (RF_CD)",
        MACRO_GENERATE   = "توليد تلقائي",
        MACRO_SAVE       = "حفظ الماكروات",
        MACRO_DONE       = "Macros saved: RF_ST, RF_AOE, RF_CD (open /macro to drag them to your bars)",
        MACRO_COMBAT     = "Can't edit macros in combat",
        MACRO_FULL       = "Your character macro slots are full",
        SOLD_GREYS       = "Selling %d grey items for %s",
        REPAIRED_GUILD   = "Repaired from guild bank for %s",
        REPAIR_NO_MONEY  = "Not enough gold to repair (%s)",
        REPAIRED         = "Repaired for %s",
        RANKS_UPDATED    = "Updated %d action bar spells to their highest rank",
        TRAINER_REMINDER = "Level %d - visit your class trainer for new spells",
        ETA              = "اللفل الجاي بعد %dس %dد  (%s خبرة/ساعة)",
        OPT_MAP_PINS     = "علامات المهام على الخريطة",
        OPT_MINI_PINS    = "علامات المهام على الميني ماب",
        OPT_AVAILABLE    = "إظهار المهام المتاحة (!)",
        OPT_SUGGEST      = "لوحة الاقتراحات (القريبة + المتاحة)",
        OPT_AUTO_SELL    = "بيع الرمادي تلقائياً",
        OPT_AUTO_REPAIR  = "تصليح تلقائي",
        OPT_GUILD_REPAIR = "التصليح من بنك القيلد أول",
        OPT_AUTO_RANK    = "تحديث رتب السكلات على البار",
        OPT_TRAINER      = "تذكير المدرب عند اللفل",
        OPT_ETA          = "الوقت المتوقع للفل الجاي",
        OPT_MACROS_BTN   = "صانع الماكرو",
    },
    en = {
        TRACKER_TITLE    = "Quests",
        READY            = "Ready to turn in",
        FAILED           = "Failed",
        NO_QUESTS        = "No active quests",
        READY_XP         = "XP from ready quests: %s",
        LEVEL_UP_HINT    = "Turning them in levels you up!",
        OPT_TITLE        = "Rafeeq - Options",
        OPT_ARABIC       = "Arabic interface",
        OPT_LANGUAGE     = "Language",
        LANG_PICK        = "Choose the addon language - change it any time",
        OPT_AUTO_ACCEPT  = "Auto-accept quests",
        OPT_AUTO_TURNIN  = "Auto turn-in quests",
        OPT_SKIP_TRIVIAL = "Skip trivial (grey) quests",
        OPT_HIDE_BLIZZ   = "Hide default quest tracker",
        OPT_SHOW_XP      = "Show XP per quest",
        OPT_LOCK         = "Lock tracker position",
        OPT_SHIFT_NOTE   = "Hold Shift when talking to an NPC to pause automation",
        OPT_SCALE        = "Scale",
        HELP             = "Commands: /rf (options)  /rf macro  /rf arrow  /rf toggle  /rf reset  /rf scale 1.1",
        RESET_DONE       = "Tracker position reset",
        CHOICE_NEEDED    = "Quest has a reward choice - pick it yourself",
        COSTS_MONEY      = "Quest costs gold - not turned in automatically",
        NEED_QDB_UPDATE  = "QuestieDB is too old - please update it",
        NO_QDB           = "QuestieDB not found - map pins, arrow and suggestions are off",
        NEARBY_TITLE     = "Nearby - do these now",
        AVAILABLE_TITLE  = "Available in this zone",
        MACRO_TITLE      = "Macro maker",
        MACRO_ST         = "Single target (RF_ST)",
        MACRO_AOE        = "AoE (RF_AOE)",
        MACRO_CD         = "Cooldowns over 7s (RF_CD)",
        MACRO_GENERATE   = "Auto generate",
        MACRO_SAVE       = "Save macros",
        MACRO_DONE       = "Macros saved: RF_ST, RF_AOE, RF_CD (open /macro to drag them to your bars)",
        MACRO_COMBAT     = "Can't edit macros in combat",
        MACRO_FULL       = "Your character macro slots are full",
        SOLD_GREYS       = "Selling %d grey items for %s",
        REPAIRED_GUILD   = "Repaired from guild bank for %s",
        REPAIR_NO_MONEY  = "Not enough gold to repair (%s)",
        REPAIRED         = "Repaired for %s",
        RANKS_UPDATED    = "Updated %d action bar spells to their highest rank",
        TRAINER_REMINDER = "Level %d - visit your class trainer for new spells",
        ETA              = "Next level in %dh %dm  (%s xp/hr)",
        OPT_MAP_PINS     = "Quest pins on world map",
        OPT_MINI_PINS    = "Quest pins on minimap",
        OPT_AVAILABLE    = "Show available quests (!)",
        OPT_SUGGEST      = "Suggestions panel (nearby + available)",
        OPT_AUTO_SELL    = "Auto-sell grey items",
        OPT_AUTO_REPAIR  = "Auto-repair",
        OPT_GUILD_REPAIR = "Use guild bank for repairs first",
        OPT_AUTO_RANK    = "Keep bar spells on highest rank",
        OPT_TRAINER      = "Trainer reminder on level up",
        OPT_ETA          = "Time-to-level estimate",
        OPT_MACROS_BTN   = "Macro maker",
    },
}

ns.Strings = strings

-- ns.L(key, ...) returns a display-ready string (shaped if Arabic).
function ns.L(key, ...)
    local lang = ns.GetLanguage and ns.GetLanguage() or "en"
    local s = (strings[lang] and strings[lang][key]) or strings.en[key] or key
    if select("#", ...) > 0 then s = s:format(...) end
    if lang == "ar" then s = ns.Shaper.Shape(s) end
    return s
end

ns.ARABIC_FONT = "Interface\\AddOns\\Rafeeq\\Media\\RafeeqArabic.ttf"

-- Apply the right font to a FontString for the current language.
function ns.SetUIFont(fs, size, flags)
    local lang = ns.GetLanguage and ns.GetLanguage() or "en"
    if lang == "ar" then
        fs:SetFont(ns.ARABIC_FONT, size, flags or "")
    else
        fs:SetFont(STANDARD_TEXT_FONT, size, flags or "")
    end
end
