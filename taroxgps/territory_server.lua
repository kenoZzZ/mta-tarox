-- taroxgps/territory_server.lua (ERWEITERTE VERSION 5.3 - Integriert in Payday)

local territories = {}
local activeConquests = {}
local territoriesInPreparation = {}

-- Konfiguration
local PREPARATION_DURATION_MS = 5 * 60 * 1000
local CONQUEST_RANK_REQUIREMENT = 5
local CONQUEST_FACTION_IDS = { [4] = true, [5] = true, [6] = true }
local CONQUEST_DURATION_MS = 60 * 1000
local CONQUEST_CHECK_INTERVAL_MS = 1000
local MINIMUM_DEFENDERS_ONLINE = 0

function getOnlineFactionMemberCount(factionId)
    local count = 0
    if not factionId or factionId == 0 then return 0 end
    for _, player in ipairs(getElementsByType("player")) do
        if isElement(player) and getElementData(player, "loggedin") then
            local pFid, _ = exports.tarox:getPlayerFractionAndRank(player)
            if pFid == factionId then
                count = count + 1
            end
        end
    end
    return count
end

function notifyFactionMembers(factionId, message, r, g, b)
    if not factionId or factionId == 0 then return end
    r, g, b = r or 255, g or 165, b or 0
    for _, player in ipairs(getElementsByType("player")) do
        if isElement(player) and getElementData(player, "loggedin") then
            local pFid, _ = exports.tarox:getPlayerFractionAndRank(player)
            if pFid == factionId then
                outputChatBox(message, player, r, g, b, true)
            end
        end
    end
end

function loadTerritoriesFromDB()
    local result, err = exports.datenbank:queryDatabase("SELECT id, name, posX, posY, sizeX, sizeY, owner_faction_id FROM territories")
    if not result then
        outputServerLog("[Territory] Fehler beim Laden der Gebiete: " .. (err or "Unbekannt"))
        return
    end
    territories = {}
    for _, row in ipairs(result) do
        row.id = tonumber(row.id)
        row.posX = tonumber(row.posX); row.posY = tonumber(row.posY)
        row.sizeX = tonumber(row.sizeX); row.sizeY = tonumber(row.sizeY)
        row.owner_faction_id = tonumber(row.owner_faction_id) or 0
        territories[row.id] = row
    end
end

function syncAllTerritoriesToClients()
    if #getElementsByType("player") > 0 and territories and next(territories) ~= nil then
        triggerClientEvent(root, "territories:syncAll", resourceRoot, territories)
    end
end

function canPlayerStartConquest(player)
    if not isElement(player) then return false end
    local fid, rank = exports.tarox:getPlayerFractionAndRank(player)
    return rank >= CONQUEST_RANK_REQUIREMENT and CONQUEST_FACTION_IDS[fid]
end

addEvent("territory:playerHitPickup", true)
addEventHandler("territory:playerHitPickup", root, function(territoryId)
    local player = client
    if canPlayerStartConquest(player) then
        if not activeConquests[territoryId] and not territoriesInPreparation[territoryId] then
            triggerClientEvent(player, "territory:startConquestUI", player, territoryId)
        else
            outputChatBox("Dieses Gebiet wird bereits erobert oder ein Angriff wird vorbereitet!", player, 255, 100, 0)
        end
    end
end)

function startActualConquest(territoryId, attackerPlayer, attackerFid, defenderFid)
    local territoryData = territories[territoryId]
    if not territoryData then return end

    if getOnlineFactionMemberCount(attackerFid) < 1 then
        if defenderFid ~= 0 then
            notifyFactionMembers(defenderFid, "Der Angriff auf '"..territoryData.name.."' wurde abgebrochen, da keine Angreifer mehr online sind.", 0, 150, 200)
        end
        return
    end

    if defenderFid ~= 0 and getOnlineFactionMemberCount(defenderFid) < MINIMUM_DEFENDERS_ONLINE then
        notifyFactionMembers(attackerFid, "Der Angriff auf '"..territoryData.name.."' wurde abgebrochen, da nicht mehr genügend Verteidiger online sind.", 0, 150, 200)
        return
    end

    activeConquests[territoryId] = {
        initiatingPlayer = attackerPlayer,
        initiatingFactionId = attackerFid,
        isPaused = false,
        statusChecker = setTimer(checkTerritoryStatus, CONQUEST_CHECK_INTERVAL_MS, 0, territoryId),
        mainTimer = setTimer(onConquestTimerEnd, CONQUEST_DURATION_MS, 1, territoryId)
    }

    local attackerFactionName = exports.tarox:getFractionNameFromID(attackerFid)
    
    notifyFactionMembers(attackerFid, "ANGRIFF! Haltet das Gebiet '" .. territoryData.name .. "' für 1 Minute!", 255, 100, 0)
    if defenderFid ~= 0 then
        notifyFactionMembers(defenderFid, "!! ANGRIFF JETZT !! '"..attackerFactionName.."' greift '" .. territoryData.name .. "' an! Verteidigt das Gebiet!", 255, 50, 50)
    end

    triggerClientEvent(root, "territory:updateConquestState", resourceRoot, territoryId, CONQUEST_DURATION_MS, false)
end

function beginConquestAfterPreparation(territoryId)
    local prepData = territoriesInPreparation[territoryId]
    if not prepData then return end
    
    territoriesInPreparation[territoryId] = nil
    
    startActualConquest(territoryId, prepData.attacker, prepData.attackerFid, prepData.defenderFid)
end

addEvent("territory:requestConquestStart", true)
addEventHandler("territory:requestConquestStart", root, function(territoryId)
    local player = client
    if not canPlayerStartConquest(player) then
        outputChatBox("Du erfüllst die Bedingungen nicht mehr, um eine Eroberung zu starten.", player, 255, 0, 0)
        return
    end
    if activeConquests[territoryId] or territoriesInPreparation[territoryId] then
        outputChatBox("Zu spät! Jemand anderes ist bereits dabei, dieses Gebiet zu erobern.", player, 255, 0, 0)
        return
    end

    local territoryData = territories[territoryId]
    if not territoryData then return end

    local owner_faction_id = territoryData.owner_faction_id or 0
    local attackerFid, _ = exports.tarox:getPlayerFractionAndRank(player)

    if attackerFid == owner_faction_id then
        outputChatBox("Du kannst kein Gebiet deiner eigenen Fraktion angreifen.", player, 255, 100, 0)
        return
    end

    if owner_faction_id > 0 then
        local defenderCount = getOnlineFactionMemberCount(owner_faction_id)
        if defenderCount < MINIMUM_DEFENDERS_ONLINE then
            outputChatBox("Angriff nicht möglich. Die verteidigende Fraktion hat nicht genügend Mitglieder (mind. " .. MINIMUM_DEFENDERS_ONLINE .. ") online.", player, 255, 100, 0)
            return
        end
        
        local attackingFactionName = exports.tarox:getFractionNameFromID(attackerFid)
        local defendingFactionName = exports.tarox:getFractionNameFromID(owner_faction_id)
        
        outputChatBox("Die Vorbereitung zur Eroberung von '"..territoryData.name.."' hat begonnen! Der Angriff startet in 5 Minuten.", player, 255, 165, 0)
        
        notifyFactionMembers(attackerFid, "Unsere Fraktion bereitet einen Angriff auf das Gebiet '" .. territoryData.name .. "' vor! Beginn in 5 Minuten.", 0, 200, 50)
        notifyFactionMembers(owner_faction_id, "!! WARNUNG: Die Fraktion '"..attackingFactionName.."' greift unser Gebiet '" .. territoryData.name .. "' an! Beginn in 5 Minuten.", 220, 50, 50)
        
        triggerClientEvent(root, "territory:startPreparationPhase", resourceRoot, territoryData.name, attackingFactionName, defendingFactionName, attackerFid, owner_faction_id, PREPARATION_DURATION_MS, player)

        territoriesInPreparation[territoryId] = {
            startTime = getTickCount(),
            attacker = player,
            attackerFid = attackerFid,
            defenderFid = owner_faction_id
        }
        
        setTimer(beginConquestAfterPreparation, PREPARATION_DURATION_MS, 1, territoryId)
    else
        outputChatBox("Du greifst das neutrale Gebiet '"..territoryData.name.."' an. Der Kampf beginnt sofort!", player, 255, 165, 0)
        startActualConquest(territoryId, player, attackerFid, 0)
    end
end)


function checkTerritoryStatus(territoryId)
    local conquest = activeConquests[territoryId]
    if not conquest then return end
    local territoryData = territories[territoryId]
    if not territoryData then cancelConquest(territoryId, "Gebietsdaten verloren."); return end
    local playersInTerritory = getElementsWithinRange(territoryData.posX, territoryData.posY, 20, 200, "player")
    if not playersInTerritory then playersInTerritory = {} end
    local initiatorsPresent = 0
    local enemiesPresent = 0
    for _, p in ipairs(playersInTerritory) do
        local pX, pY, _ = getElementPosition(p)
        local dist = getDistanceBetweenPoints2D(territoryData.posX, territoryData.posY, pX, pY)
        if dist <= territoryData.sizeX / 2 then
            local pFid, _ = exports.tarox:getPlayerFractionAndRank(p)
            if pFid == conquest.initiatingFactionId then
                initiatorsPresent = initiatorsPresent + 1
            elseif CONQUEST_FACTION_IDS[pFid] then
                enemiesPresent = enemiesPresent + 1
            end
        end
    end
    if initiatorsPresent == 0 then
        cancelConquest(territoryId, "Die angreifende Fraktion hat das Gebiet verlassen.")
        return
    end
    if enemiesPresent > 0 and not conquest.isPaused then
        pauseTimer(conquest.mainTimer)
        conquest.isPaused = true
        outputChatBox("Eroberung pausiert! Feindliche Fraktion im Gebiet!", root, 255, 150, 0)
        triggerClientEvent(root, "territory:updateConquestState", resourceRoot, territoryId, 0, true)
    elseif enemiesPresent == 0 and conquest.isPaused then
        unpauseTimer(conquest.mainTimer)
        conquest.isPaused = false
        local remainingTime = getTimerDetails(conquest.mainTimer)
        outputChatBox("Eroberung wird fortgesetzt!", root, 0, 255, 0)
        triggerClientEvent(root, "territory:updateConquestState", resourceRoot, territoryId, remainingTime, false)
    end
end

function onConquestTimerEnd(territoryId)
    local conquest = activeConquests[territoryId]
    if not conquest or conquest.isPaused then
        if conquest then cancelConquest(territoryId, "Timer Ende, aber Eroberung war pausiert.") end
        return
    end
    local territoryData = territories[territoryId]
    local playersInTerritory = getElementsWithinRange(territoryData.posX, territoryData.posY, 20, 200, "player")
    if not playersInTerritory then playersInTerritory = {} end
    local enemiesPresent = 0
    for _, p in ipairs(playersInTerritory) do
        local pX, pY, _ = getElementPosition(p)
        local dist = getDistanceBetweenPoints2D(territoryData.posX, territoryData.posY, pX, pY)
        if dist <= territoryData.sizeX / 2 then
            local pFid, _ = exports.tarox:getPlayerFractionAndRank(p)
            if pFid ~= conquest.initiatingFactionId and CONQUEST_FACTION_IDS[pFid] then
                enemiesPresent = enemiesPresent + 1
            end
        end
    end
    if enemiesPresent > 0 then
        cancelConquest(territoryId, "Feinde waren am Ende der Zeit im Gebiet.")
    else
        setTerritoryOwner(territoryId, conquest.initiatingFactionId)
        local factionName = exports.tarox:getFractionNameFromID(conquest.initiatingFactionId)
        outputChatBox("Die Fraktion '" .. factionName .. "' hat das Gebiet '"..territoryData.name.."' erfolgreich erobert!", root, 0, 255, 100)
        cleanupConquest(territoryId, true)
    end
end

function setTerritoryOwner(territoryId, newFactionId)
    if not territories[territoryId] then return false end
    local success, err = exports.datenbank:executeDatabase("UPDATE territories SET owner_faction_id = ? WHERE id = ?", newFactionId, territoryId)
    if success then
        territories[territoryId].owner_faction_id = newFactionId
        triggerClientEvent(root, "territories:updateSingle", resourceRoot, territoryId, newFactionId)
        return true
    else
        outputServerLog("[Territory] Fehler beim Ändern des Gebietsbesitzers: " .. (err or "Unbekannt"))
        return false
    end
end

function cancelConquest(territoryId, reason)
    local conquest = activeConquests[territoryId]
    if not conquest then return end
    outputChatBox("Eroberung abgebrochen: " .. reason, root, 255, 100, 0)
    cleanupConquest(territoryId, false)
end

function cleanupConquest(territoryId, success)
    local conquest = activeConquests[territoryId]
    if not conquest then return end
    if isTimer(conquest.statusChecker) then killTimer(conquest.statusChecker) end
    if isTimer(conquest.mainTimer) then killTimer(conquest.mainTimer) end
    activeConquests[territoryId] = nil
    triggerClientEvent(root, "territory:conquestFinished", resourceRoot, territoryId, success)
end

-- ######################################################################
-- ## NEU: GEBIETS-AUSZAHLUNGSFUNKTION (für Payday-Export) ##
-- ######################################################################

local RANK_PAYOUTS = {
    [1] = 337, [2] = 494, [3] = 792, [4] = 1223, [5] = 3641,
}

function getTerritoryPayoutForPlayer(player)
    if not isElement(player) or not getElementData(player, "loggedin") then
        return 0
    end

    local pFid, pRank = exports.tarox:getPlayerFractionAndRank(player)
    if not pFid or pFid == 0 or not pRank or pRank == 0 or not RANK_PAYOUTS[pRank] then
        return 0
    end

    -- Zähle die Gebiete der Spieler-Fraktion
    local factionTerritoryCount = 0
    if territories and next(territories) ~= nil then
        for _, territoryData in pairs(territories) do
            if territoryData.owner_faction_id == pFid then
                factionTerritoryCount = factionTerritoryCount + 1
            end
        end
    end

    if factionTerritoryCount > 0 then
        local payoutPerTerritory = RANK_PAYOUTS[pRank]
        local totalPayout = factionTerritoryCount * payoutPerTerritory
        return totalPayout
    end

    return 0
end


-- ## Event Handler ## --

addEventHandler("onResourceStart", resourceRoot, function()
    loadTerritoriesFromDB()
    setTimer(syncAllTerritoriesToClients, 2000, 1)
    outputServerLog("[Territory] System geladen. Auszahlung erfolgt nun über das Payday-System.")
end)

addEvent("territories:requestSync", true)
addEventHandler("territories:requestSync", root, function()
    if client and isElement(client) and territories and next(territories) ~= nil then
        triggerClientEvent(client, "territories:syncAll", resourceRoot, territories)
    end
end)

addEventHandler("onPlayerQuit", root, function()
    for id, conquest in pairs(activeConquests) do
        if conquest.initiatingPlayer == source then
            cancelConquest(id, "Der Anführer hat das Spiel verlassen.")
        end
    end
end)

addEventHandler("onPlayerWasted", root, function()
    for id, _ in pairs(activeConquests) do
        checkTerritoryStatus(id)
    end
end)

addEventHandler("onPlayerJoin", root, function()
    setTimer(function(player)
        if isElement(player) and territories and next(territories) ~= nil then
            triggerClientEvent(player, "territories:syncAll", player, territories)
        end
    end, 2500, 1, source)
end)