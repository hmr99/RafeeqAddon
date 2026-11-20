-- Rafeeq: Arabic shaper
-- WoW's text renderer has no Arabic shaping and draws everything left-to-right.
-- This converts Arabic text to Unicode presentation forms (connected letters)
-- and reorders it to visual order, so it renders correctly with an Arabic font.

local _, ns = ...
ns = ns or {}

local Shaper = {}
ns.Shaper = Shaper

local floor, char, byte = math.floor, string.char, string.byte
local tinsert, tconcat = table.insert, table.concat

---------------------------------------------------------------------------
-- UTF-8 helpers (Lua 5.1 has no utf8 library)
---------------------------------------------------------------------------
local function decode(s)
    local out, i, n = {}, 1, #s
    while i <= n do
        local c = byte(s, i)
        local cp, len
        if c < 0x80 then cp, len = c, 1
        elseif c >= 0xF0 then
            cp = (c % 0x08) * 0x40000 + (byte(s, i + 1) % 0x40) * 0x1000
               + (byte(s, i + 2) % 0x40) * 0x40 + (byte(s, i + 3) % 0x40)
            len = 4
        elseif c >= 0xE0 then
            cp = (c % 0x10) * 0x1000 + (byte(s, i + 1) % 0x40) * 0x40 + (byte(s, i + 2) % 0x40)
            len = 3
        elseif c >= 0xC0 then
            cp = (c % 0x20) * 0x40 + (byte(s, i + 1) % 0x40)
            len = 2
        else
            cp, len = 0xFFFD, 1
        end
        out[#out + 1] = cp
        i = i + len
    end
    return out
end

local function encode(cp)
    if cp < 0x80 then return char(cp)
    elseif cp < 0x800 then
        return char(0xC0 + floor(cp / 0x40), 0x80 + cp % 0x40)
    elseif cp < 0x10000 then
        return char(0xE0 + floor(cp / 0x1000), 0x80 + floor(cp / 0x40) % 0x40, 0x80 + cp % 0x40)
    end
    return char(0xF0 + floor(cp / 0x40000), 0x80 + floor(cp / 0x1000) % 0x40,
        0x80 + floor(cp / 0x40) % 0x40, 0x80 + cp % 0x40)
end

---------------------------------------------------------------------------
-- Forms: { isolated, final, initial, medial }  (initial/medial nil = right-joining only)
---------------------------------------------------------------------------
local FORMS = {}
local function dual(cp, base) FORMS[cp] = { base, base + 1, base + 2, base + 3 } end
local function right(cp, base) FORMS[cp] = { base, base + 1 } end

FORMS[0x0621] = { 0xFE80 }               -- hamza: never joins
right(0x0622, 0xFE81) right(0x0623, 0xFE83) right(0x0624, 0xFE85) right(0x0625, 0xFE87)
dual(0x0626, 0xFE89)  right(0x0627, 0xFE8D) dual(0x0628, 0xFE8F)  right(0x0629, 0xFE93)
dual(0x062A, 0xFE95)  dual(0x062B, 0xFE99)  dual(0x062C, 0xFE9D)  dual(0x062D, 0xFEA1)
dual(0x062E, 0xFEA5)  right(0x062F, 0xFEA9) right(0x0630, 0xFEAB) right(0x0631, 0xFEAD)
right(0x0632, 0xFEAF) dual(0x0633, 0xFEB1)  dual(0x0634, 0xFEB5)  dual(0x0635, 0xFEB9)
dual(0x0636, 0xFEBD)  dual(0x0637, 0xFEC1)  dual(0x0638, 0xFEC5)  dual(0x0639, 0xFEC9)
dual(0x063A, 0xFECD)  dual(0x0641, 0xFED1)  dual(0x0642, 0xFED5)  dual(0x0643, 0xFED9)
dual(0x0644, 0xFEDD)  dual(0x0645, 0xFEE1)  dual(0x0646, 0xFEE5)  dual(0x0647, 0xFEE9)
right(0x0648, 0xFEED) right(0x0649, 0xFEEF) dual(0x064A, 0xFEF1)
-- Persian / extended letters
dual(0x067E, 0xFB56)  dual(0x0686, 0xFB7A)  right(0x0698, 0xFB8A) dual(0x06A9, 0xFB8E)
dual(0x06AF, 0xFB92)  dual(0x06CC, 0xFBFC)

local TATWEEL = 0x0640
local LAM = 0x0644
local LAM_ALEF = { [0x0622] = 0xFEF5, [0x0623] = 0xFEF7, [0x0625] = 0xFEF9, [0x0627] = 0xFEFB }

local function isTransparent(cp)
    return (cp >= 0x064B and cp <= 0x065F) or cp == 0x0670
end

local function joinsNext(cp)   -- can connect to the following letter
    if cp == TATWEEL then return true end
    local f = FORMS[cp]
    return f ~= nil and f[3] ~= nil
end

local function joinsPrev(cp)   -- can connect to the preceding letter
    if cp == TATWEEL then return true end
    local f = FORMS[cp]
    return f ~= nil and f[2] ~= nil
end

local function isArabic(cp)
    return (cp >= 0x0600 and cp <= 0x06FF) or (cp >= 0xFB50 and cp <= 0xFDFF)
        or (cp >= 0xFE70 and cp <= 0xFEFF)
end

local function isLTR(cp)
    return (cp >= 0x30 and cp <= 0x39) or (cp >= 0x41 and cp <= 0x5A) or (cp >= 0x61 and cp <= 0x7A)
        or (cp >= 0xC0 and cp <= 0x24F) or (cp >= 0x0660 and cp <= 0x0669)
end

local MIRROR = { [0x28] = 0x29, [0x29] = 0x28, [0x5B] = 0x5D, [0x5D] = 0x5B,
                 [0x7B] = 0x7D, [0x7D] = 0x7B, [0x3C] = 0x3E, [0x3E] = 0x3C }

function Shaper.HasArabic(s)
    if type(s) ~= "string" then return false end
    -- Arabic block lead bytes: D8-DB (U+0600-06FF), EF AD-BB (presentation forms)
    return s:find("[\216-\219]") ~= nil or s:find("\239[\173-\187]") ~= nil
end

-- neighbour lookup that skips harakat
local function prevBase(cps, i)
    local j = i - 1
    while j >= 1 and isTransparent(cps[j]) do j = j - 1 end
    return cps[j]
end
local function nextBase(cps, i)
    local j = i + 1
    while j <= #cps and isTransparent(cps[j]) do j = j + 1 end
    return cps[j], j
end

local function shapeLogical(cps)
    local out, i, n = {}, 1, #cps
    while i <= n do
        local cp = cps[i]
        local f = FORMS[cp]
        if f then
            local p = prevBase(cps, i)
            local connectPrev = p ~= nil and joinsNext(p) and joinsPrev(cp)
            local nx, nxIdx = nextBase(cps, i)
            -- lam + alef ligature
            if cp == LAM and nx and LAM_ALEF[nx] then
                local lig = LAM_ALEF[nx]
                out[#out + 1] = connectPrev and (lig + 1) or lig
                for k = i + 1, nxIdx - 1 do out[#out + 1] = cps[k] end -- keep harakat
                i = nxIdx + 1
            else
                local connectNext = nx ~= nil and joinsNext(cp) and joinsPrev(nx)
                local form
                if connectPrev and connectNext then form = f[4]
                elseif connectPrev then form = f[2]
                elseif connectNext then form = f[3]
                end
                out[#out + 1] = form or f[1]
                i = i + 1
            end
        else
            out[#out + 1] = cp
            i = i + 1
        end
    end
    return out
end

-- Simplified bidi: base direction RTL; runs of Latin/digits stay LTR.
local function toVisual(cps)
    local n = #cps
    local cls = {}
    for i = 1, n do
        local cp = cps[i]
        if isLTR(cp) then cls[i] = "L"
        elseif isArabic(cp) then cls[i] = "R"
        else cls[i] = "N" end
    end
    -- neutrals between two L's belong to the L run (e.g. "1,200" or "Elwynn Forest")
    for i = 1, n do
        if cls[i] == "N" then
            local a = i - 1
            while a >= 1 and cls[a] == "N" do a = a - 1 end
            local b = i + 1
            while b <= n and cls[b] == "N" do b = b + 1 end
            if a >= 1 and b <= n and cls[a] == "L" and cls[b] == "L" then cls[i] = "l" end
        end
    end
    -- reverse everything
    local rev, rcls = {}, {}
    for i = n, 1, -1 do
        local cp = cps[i]
        if cls[i] == "N" and MIRROR[cp] then cp = MIRROR[cp] end
        rev[#rev + 1] = cp
        rcls[#rcls + 1] = cls[i]
    end
    -- un-reverse LTR runs
    local i = 1
    while i <= n do
        if rcls[i] == "L" or rcls[i] == "l" then
            local j = i
            while j + 1 <= n and (rcls[j + 1] == "L" or rcls[j + 1] == "l") do j = j + 1 end
            local a, b = i, j
            while a < b do rev[a], rev[b] = rev[b], rev[a]; a, b = a + 1, b - 1 end
            i = j + 1
        else
            i = i + 1
        end
    end
    return rev
end

local cache, cacheCount = {}, 0

-- Shape a plain string (no |c color codes inside). Non-Arabic strings pass through.
function Shaper.Shape(s)
    if not Shaper.HasArabic(s) then return s end
    local hit = cache[s]
    if hit then return hit end
    local cps = toVisual(shapeLogical(decode(s)))
    local parts = {}
    for k = 1, #cps do parts[k] = encode(cps[k]) end
    local result = tconcat(parts)
    if cacheCount > 1000 then cache, cacheCount = {}, 0 end
    cache[s] = result
    cacheCount = cacheCount + 1
    return result
end

Shaper._decode, Shaper._encode = decode, encode
return Shaper
