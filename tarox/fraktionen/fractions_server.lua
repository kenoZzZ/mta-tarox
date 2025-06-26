-- tarox/fraktionen/fractions_server.lua
-- Version 3.3 (Nametag-Farben integriert)

local FRACTION_NAMES = {
    [0] = "Civil",
    [1] = "Police",
    [2] = "Swat",
    [3] = "Medic",
    [4] = "Cosa Nostra",
    [5] = "Mocro Mafia",
    [6] = "Yakuza",
    [7] = "Mechanic"
}
local POLICE_FRACTION_ID_CONST = 1
local MECHANIC_FRACTION_ID_CONST = 7

_G.FRACTION_SKINS = {
    [1] = {280, 281, 282, 283, 288},
    [2] = {285, 285, 285, 285, 285},
    [3] = {274, 274, 274, 274, 274},
    [4] = {297, 298, 124, 125, 126},
    [5] = {296, 296, 296, 296, 296},
    [6] = {186, 187, 227, 228, 294},
    [7] = {50, 50, 50, 50, 50}
}

_G.DEFAULT_CIVIL_SKIN = 29

local BANK_INTERIOR_ID_CHECK = 3
local BANK_INTERIOR_DIMENSION_CHECK = 1
local CASINO_INTERIOR_ID_CHECK = 1
local CASINO_INTERIOR_DIMENSION_CHECK = 0

-- NEU: Zentrale Definition der Fraktions-Nametag-Farben (RGB)
_G.FACTION_NAMETAG_COLORS = {
    ["Civil"]       = {r = 220, g = 220, b = 220},   -- Hellgrau (Fallback)
    ["Police"]      = {r = 0, g = 123, b = 255},   -- Hellblau
    ["Swat"]        = {r = 52, g = 58, b = 64},    -- Dunkelgrau/Schwarz
    ["Medic"]       = {r = 40, g = 167, b = 69},   -- Grün
    ["Cosa Nostra"] = {r = 139, g = 0, b = 0},     -- Dunkelrot (Beispiel, bitte anpassen!)
    ["Mocro Mafia"] = {r = 128, g = 0, b = 128},   -- Lila
    ["Yakuza"]      = {r = 220, g = 53, b = 69},    -- Rot
    ["Mechanic"]    = {r = 0, g = 100, b = 200}    -- Dunkleres Blau
    -- Füge hier weitere Fraktionen und ihre Farben hinzu, falls nötig
}

function getFractionNameFromID(fid)
    return FRACTION_NAMES[fid] or "Civil"
end
_G.getFractionNameFromID = getFractionNameFromID --

-- NEU: Funktion, um die RGB-Farbe einer Fraktion zu bekommen
function getFractionNametagColor(fractionID)
    local fName = getFractionNameFromID(fractionID) --
    if fName and _G.FACTION_NAMETAG_COLORS[fName] then
        local color = _G.FACTION_NAMETAG_COLORS[fName]
        return color.r, color.g, color.b
    end
    local defaultColor = _G.FACTION_NAMETAG_COLORS["Civil"] or {r = 255, g = 255, b = 255}
    return defaultColor.r, defaultColor.g, defaultColor.b
end
_G.getFractionNametagColor = getFractionNametagColor

function getPlayerFractionAndRank(player)
    if not isElement(player) then return 0, 0 end
    local accID = getElementData(player, "account_id")
    if not accID then
        return 0, 0
    end

    local fractionDataResult, errMsg = exports.datenbank:queryDatabase("SELECT fraction_id, rank_level FROM fraction_members WHERE account_id=? LIMIT 1", accID) --
    if not fractionDataResult then
        return 0, 0
    end

    if fractionDataResult and fractionDataResult[1] then
        local fid = tonumber(fractionDataResult[1].fraction_id) or 0
        local lvl = tonumber(fractionDataResult[1].rank_level) or 0
        return fid, lvl
    end
    return 0, 0
end
_G.getPlayerFractionAndRank = getPlayerFractionAndRank --

function refreshPlayerFractionData(player)
    if not isElement(player) then return end
    local accID = getElementData(player, "account_id")
    local playerName = getPlayerName(player)
    local currentFid, currentLvl = 0,0 

    if not accID then
        setElementData(player, "group", "Civil", true) --
        setElementData(player, "rank", "-", true) --
        setElementData(player, "policeImDienst", false, true) --
        setElementData(player, "medicImDienst", false, true) --
        setElementData(player, "mechanicImDienst", false, true) --
        local r_tag, g_tag, b_tag = getFractionNametagColor(0) 
        setElementData(player, "nametagColorR", r_tag, true)
        setElementData(player, "nametagColorG", g_tag, true)
        setElementData(player, "nametagColorB", b_tag, true)
        triggerEvent("onPlayerFactionChange", player) --
        return
    end

    currentFid, currentLvl = getPlayerFractionAndRank(player) --
    local fracName = getFractionNameFromID(currentFid) --
    local onDutyStatusFromDB = 0

    if currentFid > 0 then
        local dutyResult, dutyErrMsg = exports.datenbank:queryDatabase("SELECT on_duty FROM fraction_members WHERE account_id=? AND fraction_id=?", accID, currentFid) --
        if dutyResult and dutyResult[1] then
            onDutyStatusFromDB = tonumber(dutyResult[1].on_duty) or 0
        end
    end

    local isActuallyOnDuty = (onDutyStatusFromDB == 1)

    setElementData(player, "group", fracName, true) --
    setElementData(player, "rank", (currentFid > 0 and "Lvl: "..currentLvl or "-"), true) --

    setElementData(player, "policeImDienst", false, true) --
    setElementData(player, "medicImDienst", false, true)   --
    setElementData(player, "mechanicImDienst", false, true) --

    if currentFid > 0 then
        if currentFid == POLICE_FRACTION_ID_CONST then --
            setElementData(player, "policeImDienst", isActuallyOnDuty, true) --
        elseif currentFid == 3 then 
            setElementData(player, "medicImDienst", isActuallyOnDuty, true) --
        elseif currentFid == MECHANIC_FRACTION_ID_CONST then --
            setElementData(player, "mechanicImDienst", isActuallyOnDuty, true) --
        end
    end

    local r_tag, g_tag, b_tag = getFractionNametagColor(currentFid)
    setElementData(player, "nametagColorR", r_tag, true)
    setElementData(player, "nametagColorG", g_tag, true)
    setElementData(player, "nametagColorB", b_tag, true)
    
    triggerEvent("onPlayerFactionChange", player) --
end
_G.refreshPlayerFractionData = refreshPlayerFractionData --

function updateFractionSkinInDB(accID, fracID, rankLevel)
    local skin = _G.DEFAULT_CIVIL_SKIN --
    if fracID > 0 and _G.FRACTION_SKINS[fracID] then --
        skin = _G.FRACTION_SKINS[fracID][math.min(rankLevel, #_G.FRACTION_SKINS[fracID])] or _G.DEFAULT_CIVIL_SKIN --
    end
    exports.datenbank:executeDatabase("UPDATE account SET fraction_skin=? WHERE id=?", skin, accID) --
end
_G.updateFractionSkinInDB = updateFractionSkinInDB --

function invitePlayerToFraction(leader, fracID, targetName, rankLevel)
    if not isElement(leader) then return false, "Leader-Element ungültig." end
    if not targetName or targetName == "" then return false, "Kein Zielname angegeben." end
    local leaderFID, leaderLvl = getPlayerFractionAndRank(leader) --
    if leaderFID ~= fracID or leaderLvl < 5 then return false, "Du bist kein Leader in Fraktion "..tostring(fracID) end
    local targetPlayer = getPlayerFromName(targetName)
    if not targetPlayer then return false, "Spieler '"..targetName.."' nicht gefunden." end
    local targetAccID = getElementData(targetPlayer, "account_id")
    if not targetAccID then return false, "Zielspieler hat keine account_id." end

    rankLevel = tonumber(rankLevel) or 1
    rankLevel = math.max(1, math.min(rankLevel,5))

    local oldFractionID_invite, _ = getPlayerFractionAndRank(targetPlayer) --
    if oldFractionID_invite == POLICE_FRACTION_ID_CONST and fracID ~= POLICE_FRACTION_ID_CONST then --
        if exports.tarox and type(exports.tarox.clearPlayerPoliceWeaponsAndDutyWhenKickedOrFactionChanged) == "function" then --
            exports.tarox:clearPlayerPoliceWeaponsAndDutyWhenKickedOrFactionChanged(targetPlayer) --
        end
    elseif oldFractionID_invite == MECHANIC_FRACTION_ID_CONST and fracID ~= MECHANIC_FRACTION_ID_CONST then --
        if exports.tarox and type(exports.tarox.clearPlayerMechanicToolsAndDutyWhenKickedOrFactionChanged) == "function" then --
            exports.tarox:clearPlayerMechanicToolsAndDutyWhenKickedOrFactionChanged(targetPlayer) --
        end
    end

    exports.datenbank:executeDatabase("DELETE FROM fraction_members WHERE account_id=?", targetAccID) --
    exports.datenbank:executeDatabase("INSERT INTO fraction_members (account_id, fraction_id, rank_level, on_duty) VALUES (?,?,?,0)", targetAccID, fracID, rankLevel) --

    updateFractionSkinInDB(targetAccID, fracID, rankLevel) --
    refreshPlayerFractionData(targetPlayer) --
    return true, "OK"
end
_G.invitePlayerToFraction = invitePlayerToFraction --

function setPlayerFractionRank(leader, fracID, targetName, newRankStr)
    if not isElement(leader) then return false, "Leader-Element ungültig." end
    local leaderFID, leaderLvl = getPlayerFractionAndRank(leader) --
    if leaderFID ~= fracID or leaderLvl < 5 then return false, "Du bist kein Leader in Fraktion "..tostring(fracID) end
    local targetPlayer = getPlayerFromName(targetName)
    if not targetPlayer then return false, "Spieler '"..targetName.."' nicht gefunden." end
    local accID = getElementData(targetPlayer, "account_id")
    if not accID then return false, "Zielspieler hat keine account_id." end

    local newRank = tonumber(newRankStr) or 1
    newRank = math.max(1, math.min(newRank, 5))
    exports.datenbank:executeDatabase("UPDATE fraction_members SET rank_level=? WHERE account_id=? AND fraction_id=?", newRank, accID, fracID) --
    updateFractionSkinInDB(accID, fracID, newRank) --
    refreshPlayerFractionData(targetPlayer) --
    triggerEvent("onPlayerRankChange", targetPlayer) --
    return true, "OK"
end
_G.setPlayerFractionRank = setPlayerFractionRank --

function kickPlayerFromFraction(leader, fracID, targetName)
    if not isElement(leader) then return false, "Leader-Element ungültig." end
    local leaderFID, leaderLvl = getPlayerFractionAndRank(leader) --
    if leaderFID ~= fracID or leaderLvl < 5 then return false, "Du bist kein Leader in Fraktion "..tostring(fracID) end
    local targetPlayer = getPlayerFromName(targetName)
    if not targetPlayer then return false, "Spieler '"..targetName.."' nicht gefunden." end
    local targetAccID = getElementData(targetPlayer, "account_id")
    if not targetAccID then return false, "Zielspieler hat keine account_id." end
    local targetFID_beforeKick, _ = getPlayerFractionAndRank(targetPlayer) --

    exports.datenbank:executeDatabase("DELETE FROM fraction_members WHERE account_id=? AND fraction_id=?", targetAccID, fracID) --
    if targetFID_beforeKick == POLICE_FRACTION_ID_CONST and fracID == POLICE_FRACTION_ID_CONST then --
        if exports.tarox and type(exports.tarox.clearPlayerPoliceWeaponsAndDutyWhenKickedOrFactionChanged) == "function" then --
            exports.tarox:clearPlayerPoliceWeaponsAndDutyWhenKickedOrFactionChanged(targetPlayer) --
        end
    elseif targetFID_beforeKick == MECHANIC_FRACTION_ID_CONST and fracID == MECHANIC_FRACTION_ID_CONST then --
        if exports.tarox and type(exports.tarox.clearPlayerMechanicToolsAndDutyWhenKickedOrFactionChanged) == "function" then --
            exports.tarox:clearPlayerMechanicToolsAndDutyWhenKickedOrFactionChanged(targetPlayer) --
        end
    end
    updateFractionSkinInDB(targetAccID, 0, 1) --
    refreshPlayerFractionData(targetPlayer) --
    return true, "OK"
end
_G.kickPlayerFromFraction = kickPlayerFromFraction --

function canPlayerUseFactionSpawnCommand(player)
    if not isElement(player) then return false, "Ungültiger Spieler." end
    if (getElementData(player, "wanted") or 0) > 0 then
        return false, "Du kannst diesen Befehl nicht mit aktiven Wanteds benutzen!"
    end
    local playerInterior = getElementInterior(player)
    local playerDimension = getElementDimension(player)
    if (playerInterior == BANK_INTERIOR_ID_CHECK and playerDimension == BANK_INTERIOR_DIMENSION_CHECK) or --
       (playerInterior == CASINO_INTERIOR_ID_CHECK and playerDimension == CASINO_INTERIOR_DIMENSION_CHECK) then --
        return false, "Du kannst diesen Befehl nicht während eines aktiven Raubüberfalls verwenden!"
    end
    return true, ""
end
_G.canPlayerUseFactionSpawnCommand = canPlayerUseFactionSpawnCommand --

function refreshAllPlayersFractionData()
    for _, p in ipairs(getElementsByType("player")) do
        refreshPlayerFractionData(p) --
    end
end
_G.refreshAllPlayersFractionData = refreshAllPlayersFractionData --

addEventHandler("onPlayerLoginSuccess", root, function(thePlayer) --
    if not isElement(thePlayer) then return end
    setTimer(function(playerToRefresh)
        if isElement(playerToRefresh) then
             refreshPlayerFractionData(playerToRefresh) --
        end
    end, 350, 1, thePlayer)
end)

local function isAdmin(player)
    return ((getElementData(player, "adminLevel") or 0) >= 1) --
end

addCommandHandler("addfr", function(adminPlayer, cmd, targetName, fractionIDStr, rankLevelStr) --
    if not isAdmin(adminPlayer) then outputChatBox("❌ Du bist kein Admin!", adminPlayer, 255, 0, 0); return; end
    if not targetName or not fractionIDStr then outputChatBox("Usage: /addfr <Name> <fractionID> [rankLevel]", adminPlayer, 255,255,0); return; end
    local targetPlayer = getPlayerFromName(targetName)
    if not targetPlayer then outputChatBox("❌ Spieler '"..targetName.."' nicht gefunden!", adminPlayer, 255, 0, 0); return; end
    local targetAccID = getElementData(targetPlayer, "account_id")
    if not targetAccID then outputChatBox("❌ Spieler hat keine account_id!", adminPlayer, 255, 0, 0); return; end
    local newFractionID = tonumber(fractionIDStr)
    if not newFractionID or not FRACTION_NAMES[newFractionID] then outputChatBox("❌ Ungültige fractionID!", adminPlayer, 255, 0, 0); return; end --
    local rankLevel = tonumber(rankLevelStr) or 1
    rankLevel = math.max(1, math.min(rankLevel, 5))
    local oldFractionID, _ = getPlayerFractionAndRank(targetPlayer) --
    exports.datenbank:executeDatabase("DELETE FROM fraction_members WHERE account_id=?", targetAccID) --
    if newFractionID ~= 0 then
        exports.datenbank:executeDatabase("INSERT INTO fraction_members (account_id, fraction_id, rank_level, on_duty) VALUES (?,?,?,0)", targetAccID, newFractionID, rankLevel) --
    end
    if oldFractionID == POLICE_FRACTION_ID_CONST and newFractionID ~= POLICE_FRACTION_ID_CONST then --
        if exports.tarox and type(exports.tarox.clearPlayerPoliceWeaponsAndDutyWhenKickedOrFactionChanged) == "function" then --
            exports.tarox:clearPlayerPoliceWeaponsAndDutyWhenKickedOrFactionChanged(targetPlayer) --
        end
    elseif oldFractionID == MECHANIC_FRACTION_ID_CONST and newFractionID ~= MECHANIC_FRACTION_ID_CONST then --
        if exports.tarox and type(exports.tarox.clearPlayerMechanicToolsAndDutyWhenKickedOrFactionChanged) == "function" then --
            exports.tarox:clearPlayerMechanicToolsAndDutyWhenKickedOrFactionChanged(targetPlayer) --
        end
    end
    updateFractionSkinInDB(targetAccID, newFractionID, rankLevel) --
    refreshPlayerFractionData(targetPlayer) --
    local fracNameDisplay = getFractionNameFromID(newFractionID) --
    if newFractionID ~= 0 then
        outputChatBox("✅ Du hast '"..targetName.."' in Fraktion "..fracNameDisplay.." (Rank="..rankLevel..") gesetzt!", adminPlayer, 0,255,0)
        outputChatBox("✅ Du wurdest in Fraktion "..fracNameDisplay.." aufgenommen (Rank="..rankLevel..")!", targetPlayer, 0,255,0)
    else
        outputChatBox("✅ Du hast '"..targetName.."' zu Zivilist gesetzt!", adminPlayer, 0,255,0)
        outputChatBox("✅ Du bist nun Zivilist!", targetPlayer, 0,255,0)
    end
end)

function addToFactionTreasury(fractionID, amount)
    if not FRACTION_NAMES[fractionID] then --
        return false, "Invalid fraction ID"
    end
    if type(amount) ~= "number" or amount <= 0 then
        return false, "Invalid amount"
    end
    local currentBalanceResult, errMsg = exports.datenbank:queryDatabase("SELECT balance FROM faction_treasuries WHERE fraction_id = ?", fractionID) --
    if not currentBalanceResult then
        return false, "Database query error"
    end
    local currentBalance = 0
    if currentBalanceResult and currentBalanceResult[1] then
        currentBalance = tonumber(currentBalanceResult[1].balance) or 0
    end
    local newBalance = currentBalance + amount
    local success, updateErrMsg
    if currentBalanceResult and currentBalanceResult[1] then
        success, updateErrMsg = exports.datenbank:executeDatabase("UPDATE faction_treasuries SET balance = ? WHERE fraction_id = ?", newBalance, fractionID) --
    else
        success, updateErrMsg = exports.datenbank:executeDatabase("INSERT INTO faction_treasuries (fraction_id, balance) VALUES (?, ?)", fractionID, newBalance) --
    end
    if not success then
        outputDebugString("[Fractions] DB-Fehler beim Schreiben des neuen Kontostands für Fraktion " .. fractionID .. ": " .. (updateErrMsg or "Unbekannt"))
        return false, "Database update error"
    end
    return true, "Success"
end
if exports and exports.tarox then 
    exports.tarox.addToFactionTreasury = addToFactionTreasury --
else
    outputDebugString("[Fractions Warning] tarox-Export nicht gefunden für addToFactionTreasury.")
end

--outputDebugString("[Fractions Server] Fraktionssystem (V3.3 - Nametag-Farben) geladen.")