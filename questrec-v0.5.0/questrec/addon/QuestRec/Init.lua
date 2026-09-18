-- QuestRec
-- Phase 1, Step 2: character identity plus talent-derived specialization.

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")

-- ---------------------------------------------------------------
-- Character basics
-- ---------------------------------------------------------------

local function GetCharacterBasics()
    local name  = UnitName("player")
    local realm = GetRealmName()
    local level = UnitLevel("player")

    -- UnitClass returns a localized name ("Warlock") and an uppercase
    -- token ("WARLOCK"). Send the token to a backend: it does not change
    -- with the client's language.
    local className, classToken = UnitClass("player")

    return {
        characterName = name,
        realmName     = realm,
        level         = level,
        class         = className,
        classToken    = classToken,
    }
end

-- ---------------------------------------------------------------
-- Specialization
--
-- Classic Era has no GetSpecialization. Spec is whichever talent tree
-- holds the most points.
--
-- GetTalentTabInfo signature, confirmed on Classic Era 1.15.9:
--   id, name, description, icon, pointsSpent, background,
--   previewPointsSpent, isUnlocked
--
-- The id is the stable identifier (302 is Affliction on every client).
-- The name is localized, so it is display text only. Never key off it.
-- ---------------------------------------------------------------

-- Returns a table {id, name, points} or nil if there is no spec yet.
local function GetSpec()
    if UnitLevel("player") < 10 then
        return nil
    end

    local bestId, bestName, bestPoints = nil, nil, 0

    for i = 1, GetNumTalentTabs() do
        local id, name, _, _, pointsSpent = GetTalentTabInfo(i)
        pointsSpent = pointsSpent or 0

        -- Strictly greater than, so a tie keeps the lower tab index.
        if pointsSpent > bestPoints then
            bestId, bestName, bestPoints = id, name, pointsSpent
        end
    end

    if bestPoints == 0 then
        return nil
    end

    return { id = bestId, name = bestName, points = bestPoints }
end

-- Independent count, used only by the diagnostic as a cross-check.
-- Sums the rank of every talent in a tree. Should always equal the
-- pointsSpent that GetTalentTabInfo reports.
local function CountPointsByRank(tabIndex)
    local total = 0
    for i = 1, GetNumTalents(tabIndex) do
        local rank = select(5, GetTalentInfo(tabIndex, i))
        total = total + (rank or 0)
    end
    return total
end

-- ---------------------------------------------------------------
-- Output
-- ---------------------------------------------------------------

local function PrintCharacterBasics()
    local c = GetCharacterBasics()
    local spec = GetSpec()

    print("|cff00ff00QuestRec|r")
    print("  Character: " .. c.characterName .. " of " .. c.realmName)
    print("  Level: " .. c.level)
    print("  Class: " .. c.class .. " (" .. c.classToken .. ")")

    if spec then
        print("  Spec: " .. spec.name .. " [id " .. spec.id .. "], "
            .. spec.points .. " points")
    elseif c.level < 10 then
        print("  Spec: none yet, talents unlock at level 10")
    else
        print("  Spec: none, no talent points spent")
    end
end

-- Diagnostic. Compares the reported pointsSpent against an independent
-- rank count. A mismatch means one of the two reads is wrong.
local function PrintTalentDiagnostic()
    print("|cff00ff00QuestRec|r talent diagnostic")
    print("  tabs: " .. GetNumTalentTabs())

    for i = 1, GetNumTalentTabs() do
        local id, name, _, _, reported = GetTalentTabInfo(i)
        local counted = CountPointsByRank(i)
        local flag = (reported == counted) and "match" or "MISMATCH"

        print("  " .. name .. " [id " .. id .. "] reported "
            .. tostring(reported) .. ", counted " .. counted
            .. " (" .. flag .. ")")
    end

    local spec = GetSpec()
    print("  resolved spec: " .. (spec and (spec.name .. " [id " .. spec.id .. "]") or "none"))
end

-- ---------------------------------------------------------------
-- Events and commands
-- ---------------------------------------------------------------

frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        print("|cff00ff00QuestRec|r loaded. Type /qr to see your character data.")
    end
end)

SLASH_QUESTREC1 = "/qr"
SLASH_QUESTREC2 = "/questrec"
SlashCmdList["QUESTREC"] = function(msg)
    local cmd = strlower(strtrim(msg or ""))

    if cmd == "talents" then
        PrintTalentDiagnostic()
    else
        PrintCharacterBasics()
    end
end
