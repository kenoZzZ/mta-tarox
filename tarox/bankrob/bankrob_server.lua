--[[
    bankrob_server.lua
    Bankraub-System V4.2 (Code-Formatierung verbessert)
    ERWEITERT: Zusätzliche Item-Belohnungen (Farbcode-Fix V2), Alarm-Sound
    ANGEPASST V4.2.1: Initiale Export-Prüfung verbessert

    - Mehrstufiger Raub (Tür 1, Tür 2, Safes)
    - Benötigt spezifische Items (Dietrich, Bohrer, C4)
    - Zeitgesteuerte Aktionen mit Bewegungsabbruch
    - Dynamische Belohnung basierend auf Zeit seit letztem Raub
    - Robbery-Timer und Spieler-im-Bank-Anzeige (Client-seitig)
    - Polizei-Benachrichtigung
    - Bank-Cooldown nach erfolgreichem oder fehlgeschlagenem Raub
    - Synchronisation für Spieler, die während eines Raubs/Cooldowns wieder beitreten
    - Info-Marker für aktuellen Belohnungsstatus
    - Inaktivitäts-Reset, wenn Safes nicht rechtzeitig gesprengt werden
    - Türen bleiben nach erfolgreichem Raub 10 Min. für Flucht offen
]]

-- ////////////////////////////////////////////////////////////////////
-- // KONFIGURATION & KONSTANTEN
-- ////////////////////////////////////////////////////////////////////

-- ITEM IDs
local ITEM_ID_DIETRICH = 3
local ITEM_ID_BOHRER = 8
local ITEM_ID_C4 = 9

-- ITEM IDs für Belohnungen
local ITEM_ID_DIAMANT = 14
local ITEM_ID_SILBERBARREN = 13
local ITEM_ID_GOLDBARREN = 10

-- OBJEKT MODELLE
local MODEL_TUER1 = 3109
local MODEL_TUER2 = 2634
local MODEL_SAFE_GESCHLOSSEN = 2332
local MODEL_SAFE_OFFEN = 1829

-- BANK INTERIOR EINSTELLUNGEN
local BANK_INTERIOR_ID = 3
local BANK_INTERIOR_DIMENSION_START = 1
local BANK_INTERIOR_SPAWN_POS = { x = 374.67, y = 173.80, z = 1008.38 }

-- MARKER POSITIONEN
local EINGANGS_MARKER_POS = { x = -1749.44666, y = 867.55786, z = 25.08594 }
local AUSGANGS_MARKER_POS = { x = 390.10000610352, y = 173.81563, z = 1008.4 }
local AUSGANG_WELT_POS = { x = EINGANGS_MARKER_POS.x + 2, y = EINGANGS_MARKER_POS.y, z = EINGANGS_MARKER_POS.z }

local MARKER_TUER1_POS = { x = 372.10000610352, y = 167.60000610352, z = 1008.4 }
local MARKER_TUER2_POS = { x = 369.89999389648, y = 162.30000305176, z = 1013.3 + 1 }
local MARKER_SAFES_POS = { x = 329.60000610352, y = 174, z = 1013.4 + 1 }
local REWARD_INFO_MARKER_POS = { x = 359.23608, y = 163.15186, z = 1008.78281 }
-- OBJEKT POSITIONEN
local TUER1_GESCHLOSSEN_POS = { x = 372.79998779297, y = 166.60000610352, z = 1008.5999755859, rx = 0, ry = 0, rz = 90 }
local TUER1_GEOEFFNET_POS = { x = 371.3, y = 166.60000610352, z = 1008.5999755859, rx = 0, ry = 0, rz = 90 }
local TUER2_GESCHLOSSEN_POS = { x = 368.89999389648, y = 162.19999694824, z = 1014.299987793, rx = 0, ry = 0, rz = 270 }
local TUER2_GEOEFFNET_POS = { x = 368.89999389648, y = 160.57, z = 1014.299987793, rx = 0, ry = 0, rz = 270 }
local SAFES_EXPLOSION_POS = { x = 328.0, y = 174.0, z = 1014.0 }
local SAFE_POSITIONS = {
    { id = 1, x = 327.59998779297, y = 173.10000610352, z = 1013.700012207, rx = 0, ry = 0, rz = 90, object = nil, isLooted = false },
    { id = 2, x = 327.59998779297, y = 174.0,           z = 1013.700012207, rx = 0, ry = 0, rz = 90, object = nil, isLooted = false },
    { id = 3, x = 327.59998779297, y = 174.89999389648, z = 1013.700012207, rx = 0, ry = 0, rz = 90, object = nil, isLooted = false },
    { id = 4, x = 327.59998779297, y = 173.5,           z = 1014.5999755859, rx = 0, ry = 0, rz = 90, object = nil, isLooted = false },
    { id = 5, x = 327.59998779297, y = 174.39999389648, z = 1014.5999755859, rx = 0, ry = 0, rz = 90, object = nil, isLooted = false },
    { id = 6, x = 327.59998779297, y = 174.0,           z = 1015.5,           rx = 0, ry = 0, rz = 90, object = nil, isLooted = false },
}

-- ZEITEN & DAUER
local ANIMATION_DURATION = 15 * 1000
local TUER1_OFFEN_DAUER_NORMAL = 55 * 60 * 1000
local TUER2_OFFEN_DAUER_NORMAL = 55 * 60 * 1000
local TUER_OFFEN_NACH_RAUB_DAUER = 10 * 60 * 1000
local ROBBERY_STALL_TIMEOUT = 10 * 60 * 1000
local C4_DETONATION_DELAY = 5 * 1000
local ROBBERY_TIMER_DURATION = 5 * 60 * 1000
local BANK_COOLDOWN_DURATION = 60 * 60 * 1000
local MIN_POLICE_FOR_ROBBERY = 0 -- Sollte für Tests auf 0 bleiben, später erhöhen

-- BELOHNUNGSSYSTEM
local STANDARD_REWARD_AMOUNT = 650000
local REWARD_INCREASE_INTERVAL = 15 * 60 * 1000
local REWARD_INCREASE_PERCENTAGE = 0.10
local MAX_REWARD_INCREASE_FACTOR = 1.10 -- Max. 110% des Standard-Rewards als Bonus
local lastSuccessfulRobEndTime = 0
local currentRewardBonusFactor = 0

-- STATUSVARIABLEN
local tuer1_Object, tuer2_Object
local tuer1_IsOpen, tuer2_IsOpen = false, false
local tuer1_CloseTimer, tuer2_CloseTimer
local tuer1_Marker, tuer2_Marker, safesMarker, rewardInfoMarker
local eingangsMarkerElement, ausgangsMarkerElement
local safesAreBreached = false
local bankRobberyActive = false
local bankRobberyEndTime = 0
local bankRobberyParticipants = {}
local policeNotificationActive = false
local bankCooldownActive = false
local bankCooldownEndTime = 0
local robberyInfoUpdateTimer, mainRobberyTimer, robberyStallTimer
local currentActionPlayer = nil
local playerActionTimer, playerMovementCheckTimer
local playerActionStartX, playerActionStartY, playerActionStartZ = 0,0,0

-- ////////////////////////////////////////////////////////////////////
-- // HILFSFUNKTIONEN
-- ////////////////////////////////////////////////////////////////////
function getPlayerAccountID(player)
    if not isElement(player) then return nil end
    return getElementData(player, "account_id")
end

function isPlayerEligibleForReward(player)
    if not isElement(player) then return false end
    local fid, _ = getPlayerFractionAndRank(player) -- Annahme: getPlayerFractionAndRank ist global
    local evilFactions = { [4] = true, [5] = true, [6] = true } -- Cosa, Mocro, Yakuza
    return evilFactions[fid] or fid == 0 -- Zivilisten können auch teilnehmen/belohnt werden
end

function isPlayerInEvilFaction(player)
    if not isElement(player) then return false end
    local playerFractionID, _ = getPlayerFractionAndRank(player)
    if not playerFractionID then return false end
    local evilFactions = { [4] = true, [5] = true, [6] = true }
    return evilFactions[playerFractionID] or false
end

function getPlayerFromAccountID(accountID) -- Wieder hinzugefügt, falls benötigt
    if not accountID then return nil end; accountID = tonumber(accountID)
    if not accountID then return nil end
    for _, p in ipairs(getElementsByType("player")) do
        local pAccID = getElementData(p, "account_id")
        if pAccID and tonumber(pAccID) == accountID then return p end
    end
    return nil
end

function getOnlinePoliceCount()
    local count = 0
    for _, player in ipairs(getElementsByType("player")) do
        if getElementData(player, "account_id") then
            local fid, _ = getPlayerFractionAndRank(player)
            if fid == 1 or fid == 2 then count = count + 1 end -- Police oder Swat
        end
    end
    return count
end

function notifyParticipants(message, r, g, b, sound)
    for accId, _ in pairs(bankRobberyParticipants) do
        local player = getPlayerFromAccountID(accId)
        if isElement(player) and getElementInterior(player) == BANK_INTERIOR_ID and getElementDimension(player) == BANK_INTERIOR_DIMENSION_START then
            outputChatBox(message, player, r, g, b)
            if sound then playSoundFrontEnd(player, sound) end
        end
    end
end

function sendRobberyInfoToClients()
    if not bankRobberyActive then
        if isTimer(robberyInfoUpdateTimer) then killTimer(robberyInfoUpdateTimer); robberyInfoUpdateTimer = nil; end
        return
    end
    local onlineCops = getOnlinePoliceCount()
    local robbersInBankCount = 0
    for accId, _ in pairs(bankRobberyParticipants) do
        local p = getPlayerFromAccountID(accId)
        if isElement(p) and getElementInterior(p) == BANK_INTERIOR_ID and getElementDimension(p) == BANK_INTERIOR_DIMENSION_START then
            robbersInBankCount = robbersInBankCount + 1
        end
    end
    -- An alle Spieler im Bank-Interior senden, nicht nur Teilnehmer
    for _, p_client in ipairs(getElementsByType("player")) do
        if isElement(p_client) and getElementInterior(p_client) == BANK_INTERIOR_ID and getElementDimension(p_client) == BANK_INTERIOR_DIMENSION_START then
            triggerClientEvent(p_client, "bankrob:updateRobberyInfo", resourceRoot, onlineCops, robbersInBankCount)
        end
    end
end

-- ////////////////////////////////////////////////////////////////////
-- // BELOHNUNGSSYSTEM LOGIK
-- ////////////////////////////////////////////////////////////////////
function calculateCurrentRewardBonus()
    if lastSuccessfulRobEndTime == 0 then currentRewardBonusFactor = 0; return end
    local timeAfterCooldownForBonus = getTickCount() - (lastSuccessfulRobEndTime + BANK_COOLDOWN_DURATION)
    if timeAfterCooldownForBonus <= 0 then currentRewardBonusFactor = 0; return end

    if timeAfterCooldownForBonus < REWARD_INCREASE_INTERVAL then
        currentRewardBonusFactor = 0
    else
        local bonusIntervals = math.floor(timeAfterCooldownForBonus / REWARD_INCREASE_INTERVAL)
        currentRewardBonusFactor = math.min(MAX_REWARD_INCREASE_FACTOR, bonusIntervals * REWARD_INCREASE_PERCENTAGE)
    end
end

function getFormattedRewardStatus()
    calculateCurrentRewardBonus()
    local totalAbsoluteReward = math.floor(STANDARD_REWARD_AMOUNT * (1 + currentRewardBonusFactor))
    local formattedTotalAmount = tostring(totalAbsoluteReward):gsub("(?%d)(?=(%d%d%d)+$)", "%1.")
    local formattedStandardAmount = tostring(STANDARD_REWARD_AMOUNT):gsub("(?%d)(?=(%d%d%d)+$)", "%1.")

    if currentRewardBonusFactor == 0 then
        return "Aktuelle Belohnung: Standard ($" .. formattedStandardAmount .. ")"
    else
        return string.format("Aktuelle Belohnung: Standard + %.0f%% Bonus ($%s)", currentRewardBonusFactor * 100, formattedTotalAmount)
    end
end

-- ... (Marker Erstellung, Objekt Erstellung, Aktionsmarker Handling, Aktionen Durchführen, Tür-Reset, Inaktivitäts-Reset bleiben strukturell sehr ähnlich)
-- Die Hauptänderung ist die Überprüfung der `exports.tarox` Funktionen.

-- ////////////////////////////////////////////////////////////////////
-- // MARKER ERSTELLUNG & HANDLING
-- ////////////////////////////////////////////////////////////////////
function createBankMarkers()
    if isElement(eingangsMarkerElement) then destroyElement(eingangsMarkerElement) end
    eingangsMarkerElement = createMarker(EINGANGS_MARKER_POS.x, EINGANGS_MARKER_POS.y, EINGANGS_MARKER_POS.z - 1, "cylinder", 1.5, 0, 255, 0, 150)
    if isElement(eingangsMarkerElement) then
        addEventHandler("onMarkerHit", eingangsMarkerElement,
            function(hitElement, matchingDimension)
                if getElementType(hitElement) ~= "player" or not matchingDimension or isPedInVehicle(hitElement) then return end
                local canEnter = true
                local playerFractionID, _ = getPlayerFractionAndRank(hitElement)
                if bankRobberyActive then
                    local playerAccID = getPlayerAccountID(hitElement)
                    if not bankRobberyParticipants[playerAccID] and playerFractionID ~= 1 and playerFractionID ~= 2 then
                        outputChatBox("Die Bank wird gerade ausgeraubt. Zutritt nur für beteiligte Parteien.", hitElement, 255,100,0)
                        canEnter = false
                    end
                end
                if canEnter then
                    fadeCamera(hitElement, false, 0.5)
                    setTimer(function(player)
                        if isElement(player) then
                            setElementInterior(player, BANK_INTERIOR_ID)
                            setElementDimension(player, BANK_INTERIOR_DIMENSION_START)
                            setElementPosition(player, BANK_INTERIOR_SPAWN_POS.x, BANK_INTERIOR_SPAWN_POS.y, BANK_INTERIOR_SPAWN_POS.z)
                            fadeCamera(player, true, 0.5)
                            if bankRobberyActive then
                                triggerClientEvent(player, "bankrob:startRobberyTimer", player, math.max(0, bankRobberyEndTime - getTickCount()))
                                sendRobberyInfoToClients() -- Client informieren, sobald er drin ist
                            end
                            if bankCooldownActive then
                                triggerClientEvent(player, "bankrob:cooldownUpdate", player, math.max(0, bankCooldownEndTime - getTickCount()))
                            end
                        end
                    end, 500, 1, hitElement)
                end
            end
        )
    else outputDebugString("[BankRob ERROR] EingangsMarker konnte nicht erstellt werden!") end

    if isElement(ausgangsMarkerElement) then destroyElement(ausgangsMarkerElement) end
    ausgangsMarkerElement = createMarker(AUSGANGS_MARKER_POS.x, AUSGANGS_MARKER_POS.y, AUSGANGS_MARKER_POS.z - 1, "cylinder", 1.5, 255, 0, 0, 150)
    if isElement(ausgangsMarkerElement) then
        setElementInterior(ausgangsMarkerElement, BANK_INTERIOR_ID)
        setElementDimension(ausgangsMarkerElement, BANK_INTERIOR_DIMENSION_START)
        addEventHandler("onMarkerHit", ausgangsMarkerElement,
            function(hitElement, matchingDimension)
                if getElementType(hitElement) ~= "player" or not matchingDimension or isPedInVehicle(hitElement) then return end
                fadeCamera(hitElement, false, 0.5)
                setTimer(function(player)
                    if isElement(player) then
                        setElementInterior(player, 0); setElementDimension(player, 0)
                        setElementPosition(player, AUSGANG_WELT_POS.x, AUSGANG_WELT_POS.y, AUSGANG_WELT_POS.z)
                        fadeCamera(player, true, 0.5)
                        local fidExt, _ = getPlayerFractionAndRank(player)
                        if fidExt ~=1 and fidExt ~=2 then
                            triggerClientEvent(player, "bankrob:stopRobberyTimer", player)
                            if getElementData(player, "isPlayingBankAlarm") then
                                triggerClientEvent(player, "bankrob:playAlarmSound", resourceRoot, false)
                                setElementData(player, "isPlayingBankAlarm", false)
                            end
                        end
                    end
                end, 500, 1, hitElement)
            end
        )
    else outputDebugString("[BankRob ERROR] AusgangsMarker konnte nicht erstellt werden!") end

    if isElement(tuer1_Marker) then destroyElement(tuer1_Marker); tuer1_Marker = nil; end
    if not tuer1_IsOpen and not (bankCooldownActive and getTickCount() < bankCooldownEndTime) then
        tuer1_Marker = createMarker(MARKER_TUER1_POS.x, MARKER_TUER1_POS.y, MARKER_TUER1_POS.z - 1, "cylinder", 1.2, 255, 200, 0, 180)
        if isElement(tuer1_Marker) then
            setElementInterior(tuer1_Marker, BANK_INTERIOR_ID); setElementDimension(tuer1_Marker, BANK_INTERIOR_DIMENSION_START)
            setElementData(tuer1_Marker, "bankAction", "tuer1Knacken"); addEventHandler("onMarkerHit", tuer1_Marker, handleActionMarkerHit)
        else outputDebugString("[BankRob ERROR] tuer1_Marker konnte nicht erstellt werden!") end
    end

    if isElement(rewardInfoMarker) then destroyElement(rewardInfoMarker) end
    rewardInfoMarker = createMarker(REWARD_INFO_MARKER_POS.x, REWARD_INFO_MARKER_POS.y, REWARD_INFO_MARKER_POS.z -1, "cylinder", 1.0, 0, 220, 220, 100)
    if isElement(rewardInfoMarker) then
        setElementInterior(rewardInfoMarker, BANK_INTERIOR_ID); setElementDimension(rewardInfoMarker, BANK_INTERIOR_DIMENSION_START)
        addEventHandler("onMarkerHit", rewardInfoMarker,
            function(hitElement, matchingDimension)
                if getElementType(hitElement) ~= "player" or not matchingDimension or isPedInVehicle(hitElement) then return end
                if isPlayerEligibleForReward(hitElement) then outputChatBox(getFormattedRewardStatus(), hitElement, 0, 220, 220) end
            end
        )
    else outputDebugString("[BankRob ERROR] RewardInfoMarker konnte nicht erstellt werden!") end
    --outputDebugString("[BankRob] Bank-Marker erstellt/aktualisiert.")
end

-- ////////////////////////////////////////////////////////////////////
-- // OBJEKT ERSTELLUNG & HANDLING
-- ////////////////////////////////////////////////////////////////////
function createBankObjects()
    if isElement(tuer1_Object) then destroyElement(tuer1_Object) end
    tuer1_Object = createObject(MODEL_TUER1, TUER1_GESCHLOSSEN_POS.x, TUER1_GESCHLOSSEN_POS.y, TUER1_GESCHLOSSEN_POS.z, TUER1_GESCHLOSSEN_POS.rx, TUER1_GESCHLOSSEN_POS.ry, TUER1_GESCHLOSSEN_POS.rz)
    if isElement(tuer1_Object) then setElementInterior(tuer1_Object, BANK_INTERIOR_ID); setElementDimension(tuer1_Object, BANK_INTERIOR_DIMENSION_START); setElementFrozen(tuer1_Object, true); tuer1_IsOpen = false
    else outputDebugString("[BankRob ERROR] tuer1_Object Erstellung fehlgeschlagen!") end

    if isElement(tuer2_Object) then destroyElement(tuer2_Object) end
    tuer2_Object = createObject(MODEL_TUER2, TUER2_GESCHLOSSEN_POS.x, TUER2_GESCHLOSSEN_POS.y, TUER2_GESCHLOSSEN_POS.z, TUER2_GESCHLOSSEN_POS.rx, TUER2_GESCHLOSSEN_POS.ry, TUER2_GESCHLOSSEN_POS.rz)
    if isElement(tuer2_Object) then setElementInterior(tuer2_Object, BANK_INTERIOR_ID); setElementDimension(tuer2_Object, BANK_INTERIOR_DIMENSION_START); setElementFrozen(tuer2_Object, true); tuer2_IsOpen = false
    else outputDebugString("[BankRob ERROR] tuer2_Object Erstellung fehlgeschlagen!") end

    for i, safeData in ipairs(SAFE_POSITIONS) do
        if isElement(safeData.object) then destroyElement(safeData.object) end
        local safeObj = createObject(MODEL_SAFE_GESCHLOSSEN, safeData.x, safeData.y, safeData.z, safeData.rx, safeData.ry, safeData.rz)
        if isElement(safeObj) then setElementInterior(safeObj, BANK_INTERIOR_ID); setElementDimension(safeObj, BANK_INTERIOR_DIMENSION_START); setElementFrozen(safeObj, true); SAFE_POSITIONS[i].object = safeObj; SAFE_POSITIONS[i].isLooted = false
        else outputDebugString("[BankRob ERROR] Safe #"..i.." Erstellung fehlgeschlagen!") end
    end
    safesAreBreached = false
    --outputDebugString("[BankRob] Bank-Objekte (Türen, Safes) erstellt.")
end

-- ////////////////////////////////////////////////////////////////////
-- // AKTIONSMARKER HANDLING
-- ////////////////////////////////////////////////////////////////////
function handleActionMarkerHit(hitElement, matchingDimension)
    if getElementType(hitElement) ~= "player" or not matchingDimension or isPedInVehicle(hitElement) then return end
    if currentActionPlayer and currentActionPlayer ~= hitElement then outputChatBox("Ein anderer Spieler führt gerade eine Aktion aus.", hitElement, 255,100,0); return end
    if bankCooldownActive and getTickCount() < bankCooldownEndTime then local remCD = math.ceil((bankCooldownEndTime-getTickCount())/1000/60); outputChatBox("Bank noch für ca. "..remCD.." Min. im Cooldown.", hitElement,255,100,0); return end
    if bankRobberyActive then outputChatBox("Der Bankraub ist bereits im Gange!", hitElement, 255,100,0); return end

    local action = getElementData(source, "bankAction")
    if not isPlayerInEvilFaction(hitElement) then outputChatBox("Nur Mitglieder krimineller Organisationen können dies tun.", hitElement,255,0,0); return end

    local message, requiredItem, actionType = "", nil, ""
    local hasItemResult = false

    if action == "tuer1Knacken" then
        if tuer1_IsOpen then outputChatBox("Diese Tür ist bereits offen.", hitElement,0,150,255); return end
        hasItemResult = exports.tarox:hasPlayerItem(hitElement, ITEM_ID_DIETRICH, 1)
        if not hasItemResult then outputChatBox("Du benötigst einen Dietrich.", hitElement,255,100,0); return end
        message, requiredItem, actionType = "Tür mit Dietrich knacken? (15 Sek.)", ITEM_ID_DIETRICH, "tuer1Knacken"
    elseif action == "tuer2Bohren" then
        if tuer2_IsOpen then outputChatBox("Diese Tür ist bereits offen.", hitElement,0,150,255); return end
        hasItemResult = exports.tarox:hasPlayerItem(hitElement, ITEM_ID_BOHRER, 1)
        if not hasItemResult then outputChatBox("Du benötigst einen Bohrer.", hitElement,255,100,0); return end
        message, requiredItem, actionType = "Tresortür aufbohren? (15 Sek.)", ITEM_ID_BOHRER, "tuer2Bohren"
    elseif action == "safesSprengen" then
        if safesAreBreached then outputChatBox("Safes sind bereits offen.", hitElement,0,150,255); return end
        hasItemResult = exports.tarox:hasPlayerItem(hitElement, ITEM_ID_C4, 1)
        if not hasItemResult then outputChatBox("Du benötigst C4.", hitElement,255,100,0); return end
        message, requiredItem, actionType = "C4 an Safes platzieren? (15 Sek. Vorbereitung)", ITEM_ID_C4, "safesSprengen"
    else return end
    triggerClientEvent(hitElement, "bankrob:requestActionConfirmation", hitElement, message, actionType, requiredItem)
end

-- ////////////////////////////////////////////////////////////////////
-- // AKTIONEN DURCHFÜHREN
-- ////////////////////////////////////////////////////////////////////
function startPlayerAction(player, actionName, successCallback, failureCallback, requiredItem)
    if currentActionPlayer then return false end
    currentActionPlayer = player; setElementData(player, "bankrob:isDoingAction", true)
    playerActionStartX, playerActionStartY, playerActionStartZ = getElementPosition(player)
    setPedAnimation(player, "SCRATCHING", "sclng_r", -1, true, false, false, false)
    toggleAllControls(player, false, true, false)

    playerMovementCheckTimer = setTimer(function()
        if not isElement(currentActionPlayer) then cancelPlayerAction("Spieler nicht mehr gültig", failureCallback); return end
        local cX,cY,cZ = getElementPosition(currentActionPlayer)
        if getDistanceBetweenPoints3D(playerActionStartX,playerActionStartY,playerActionStartZ,cX,cY,cZ) > 0.5 then cancelPlayerAction("Spieler hat sich bewegt",failureCallback) end
    end, 500, 0)

    playerActionTimer = setTimer(function()
        if not isElement(currentActionPlayer) then cancelPlayerAction("Spieler nicht mehr gültig", failureCallback); return end
        local itemTakenSuccessfully = true
        if requiredItem then
            local itemTaken, takeMsg = exports.tarox:takePlayerItemByID(currentActionPlayer, requiredItem, 1)
            if not itemTaken then
                itemTakenSuccessfully = false
                outputChatBox("Fehler: Item konnte nicht entfernt werden: "..(takeMsg or "Unbekannt"), currentActionPlayer, 255,0,0)
            end
        end
        clearPlayerActionTimers()
        if isElement(currentActionPlayer) then
            setPedAnimation(currentActionPlayer, false); toggleAllControls(currentActionPlayer, true, true, true); removeElementData(currentActionPlayer, "bankrob:isDoingAction")
            if itemTakenSuccessfully then successCallback(currentActionPlayer)
            elseif failureCallback then failureCallback(currentActionPlayer) end
        end
        currentActionPlayer = nil
    end, ANIMATION_DURATION, 1)
    outputChatBox("Aktion '"..actionName.."' gestartet... Nicht bewegen!", player,0,150,255)
    return true
end

function cancelPlayerAction(reason, callback)
    local player = currentActionPlayer; if not player then return end; currentActionPlayer = nil; clearPlayerActionTimers()
    if isElement(player) then outputChatBox("Aktion abgebrochen: "..reason, player,255,0,0); setPedAnimation(player,false); toggleAllControls(player,true,true,true); removeElementData(player,"bankrob:isDoingAction"); if callback then callback(player)end end
end

function clearPlayerActionTimers()
    if isTimer(playerActionTimer)then killTimer(playerActionTimer);playerActionTimer=nil end
    if isTimer(playerMovementCheckTimer)then killTimer(playerMovementCheckTimer);playerMovementCheckTimer=nil end
end

addEvent("bankrob:confirmAction", true)
addEventHandler("bankrob:confirmAction", root, function(actionType, itemUsed)
    local player = client
    if not isElement(player) or (currentActionPlayer and currentActionPlayer ~= player) then return end
    local success = false
    local failureFunc = function(p) outputChatBox("Aktion fehlgeschlagen.", p, 255,0,0) end -- Allgemeine Fehlerfunktion

    if actionType == "tuer1Knacken" then
        if tuer1_IsOpen then outputChatBox("Tür 1 ist schon offen.", player,255,100,0); return end
        success = startPlayerAction(player, "Tür 1 knacken",
            function(p)
                if not isElement(tuer1_Object)then outputDebugString("[BankRob ERROR] tuer1_Object ungültig!");return end
                moveObject(tuer1_Object,2000,TUER1_GEOEFFNET_POS.x,TUER1_GEOEFFNET_POS.y,TUER1_GEOEFFNET_POS.z,TUER1_GEOEFFNET_POS.rx-TUER1_GESCHLOSSEN_POS.rx,TUER1_GEOEFFNET_POS.ry-TUER1_GESCHLOSSEN_POS.ry,TUER1_GEOEFFNET_POS.rz-TUER1_GESCHLOSSEN_POS.rz)
                tuer1_IsOpen=true; outputChatBox("Tür 1 erfolgreich geknackt!",p,0,255,0)
                if isElement(tuer1_Marker)then destroyElement(tuer1_Marker);tuer1_Marker=nil end
                if not tuer2_IsOpen then if isElement(tuer2_Marker)then destroyElement(tuer2_Marker)end;tuer2_Marker=createMarker(MARKER_TUER2_POS.x,MARKER_TUER2_POS.y,MARKER_TUER2_POS.z-1,"cylinder",1.2,255,150,0,180);setElementInterior(tuer2_Marker,BANK_INTERIOR_ID);setElementDimension(tuer2_Marker,BANK_INTERIOR_DIMENSION_START);setElementData(tuer2_Marker,"bankAction","tuer2Bohren");addEventHandler("onMarkerHit",tuer2_Marker,handleActionMarkerHit);startRobberyStallTimer()end
                if isTimer(tuer1_CloseTimer)then killTimer(tuer1_CloseTimer)end;tuer1_CloseTimer=setTimer(resetTuer1State,TUER1_OFFEN_DAUER_NORMAL,1,false)
            end, failureFunc, ITEM_ID_DIETRICH
        )
    elseif actionType == "tuer2Bohren" then
        if tuer2_IsOpen then outputChatBox("Tür 2 ist schon offen.", player,255,100,0); return end
        success = startPlayerAction(player, "Tür 2 aufbohren",
            function(p)
                if not isElement(tuer2_Object)then outputDebugString("[BankRob ERROR] tuer2_Object ungültig!");return end
                moveObject(tuer2_Object,3000,TUER2_GEOEFFNET_POS.x,TUER2_GEOEFFNET_POS.y,TUER2_GEOEFFNET_POS.z,TUER2_GEOEFFNET_POS.rx-TUER2_GESCHLOSSEN_POS.rx,TUER2_GEOEFFNET_POS.ry-TUER2_GESCHLOSSEN_POS.ry,TUER2_GEOEFFNET_POS.rz-TUER2_GESCHLOSSEN_POS.rz)
                tuer2_IsOpen=true; outputChatBox("Tresortür 2 erfolgreich aufgebohrt!",p,0,255,0)
                if isElement(tuer2_Marker)then destroyElement(tuer2_Marker);tuer2_Marker=nil end
                if not safesAreBreached then if isElement(safesMarker)then destroyElement(safesMarker)end;safesMarker=createMarker(MARKER_SAFES_POS.x,MARKER_SAFES_POS.y,MARKER_SAFES_POS.z-1,"cylinder",1.5,255,100,0,180);setElementInterior(safesMarker,BANK_INTERIOR_ID);setElementDimension(safesMarker,BANK_INTERIOR_DIMENSION_START);setElementData(safesMarker,"bankAction","safesSprengen");addEventHandler("onMarkerHit",safesMarker,handleActionMarkerHit);startRobberyStallTimer()end
                if isTimer(tuer2_CloseTimer)then killTimer(tuer2_CloseTimer)end;tuer2_CloseTimer=setTimer(resetTuer2State,TUER2_OFFEN_DAUER_NORMAL,1,false)
            end, failureFunc, ITEM_ID_BOHRER
        )
    elseif actionType == "safesSprengen" then
        if safesAreBreached then outputChatBox("Safes sind schon offen.", player,255,100,0); return end
        success = startPlayerAction(player, "C4 an Safes anbringen",
            function(p)
                outputChatBox("C4 platziert! Zündung in "..(C4_DETONATION_DELAY/1000).." Sek...",p,255,50,0)
                if isElement(safesMarker)then destroyElement(safesMarker);safesMarker=nil end
                if isTimer(robberyStallTimer)then killTimer(robberyStallTimer);robberyStallTimer=nil;end
                setTimer(function()
                    if (bankCooldownActive and getTickCount()<bankCooldownEndTime)or bankRobberyActive then return end
                    createExplosion(SAFES_EXPLOSION_POS.x,SAFES_EXPLOSION_POS.y,SAFES_EXPLOSION_POS.z,12,p,-1.0,false)
                    safesAreBreached=true
                    for i,safeData in ipairs(SAFE_POSITIONS)do if isElement(safeData.object)then setElementModel(safeData.object,MODEL_SAFE_OFFEN);setElementData(safeData.object,"isLootable",true);setElementData(safeData.object,"safeID",safeData.id);removeEventHandler("onElementClicked",safeData.object,handleSafeClicked);addEventHandler("onElementClicked",safeData.object,handleSafeClicked)end end
                    startBankRobbery(p)
                end,C4_DETONATION_DELAY,1)
            end, failureFunc, ITEM_ID_C4
        )
    end
    if not success and currentActionPlayer == player then currentActionPlayer = nil end
end)

-- Tür-Reset Funktionen (resetTuer1State, resetTuer2State) und Inaktivitäts-Reset (startRobberyStallTimer) bleiben strukturell gleich.

-- ////////////////////////////////////////////////////////////////////
-- // INAKTIVITÄTS-RESET LOGIK
-- ////////////////////////////////////////////////////////////////////
function startRobberyStallTimer()
    if isTimer(robberyStallTimer) then killTimer(robberyStallTimer) end
    outputDebugString("[BankRob] Inaktivitäts-Timer gestartet (" .. ROBBERY_STALL_TIMEOUT/1000/60 .. " Min).")
    robberyStallTimer = setTimer(function()
        if not bankRobberyActive and not safesAreBreached and (tuer1_IsOpen or tuer2_IsOpen) then
            outputChatBox("Bankraubversuch wegen Inaktivität zurückgesetzt.", root, 255, 100, 0)
            outputDebugString("[BankRob] Inaktivitäts-Timeout erreicht. Reset wird durchgeführt.")
            resetBankRobberyState(false)
        end
        robberyStallTimer = nil
    end, ROBBERY_STALL_TIMEOUT, 1)
end

-- ////////////////////////////////////////////////////////////////////
-- // HAUPT-BANKRAUB LOGIK
-- ////////////////////////////////////////////////////////////////////
function startBankRobbery(initiator)
    if bankRobberyActive or (bankCooldownActive and getTickCount() < bankCooldownEndTime) then outputChatBox("Bank nicht ausraubbar.", initiator,255,100,0); return end
    local onlineCops = getOnlinePoliceCount()
    if onlineCops < MIN_POLICE_FOR_ROBBERY then
        outputChatBox("Nicht genügend Polizisten ("..MIN_POLICE_FOR_ROBBERY.." benötigt).", initiator,255,100,0)
        safesAreBreached = false
        for i,safeData in ipairs(SAFE_POSITIONS)do if isElement(safeData.object)then removeEventHandler("onElementClicked",safeData.object,handleSafeClicked);setElementData(safeData.object,"isLootable",false);setElementModel(safeData.object,MODEL_SAFE_GESCHLOSSEN)end end
        if tuer2_IsOpen and not isElement(safesMarker)then if isElement(safesMarker)then destroyElement(safesMarker)end;safesMarker=createMarker(MARKER_SAFES_POS.x,MARKER_SAFES_POS.y,MARKER_SAFES_POS.z-1,"cylinder",1.5,255,100,0,180);setElementInterior(safesMarker,BANK_INTERIOR_ID);setElementDimension(safesMarker,BANK_INTERIOR_DIMENSION_START);setElementData(safesMarker,"bankAction","safesSprengen");addEventHandler("onMarkerHit",safesMarker,handleActionMarkerHit)end; return
    end
    if isTimer(robberyStallTimer)then killTimer(robberyStallTimer);robberyStallTimer=nil;end
    bankRobberyActive=true;bankCooldownActive=false;bankRobberyEndTime=getTickCount()+ROBBERY_TIMER_DURATION
    setPlayerWantedLevel(initiator,(getElementData(initiator,"wanted")or 0)+20)
    bankRobberyParticipants={};local initiatorAccID=getPlayerAccountID(initiator);if initiatorAccID then bankRobberyParticipants[initiatorAccID]=true end
    for _,player in ipairs(getElementsByType("player"))do if isElement(player)and getElementData(player,"account_id")then if getElementInterior(player)==BANK_INTERIOR_ID and getElementDimension(player)==BANK_INTERIOR_DIMENSION_START then local pAccID=getPlayerAccountID(player);if pAccID and isPlayerEligibleForReward(player)then bankRobberyParticipants[pAccID]=true end;triggerClientEvent(player,"bankrob:startRobberyTimer",player,ROBBERY_TIMER_DURATION);if player~=initiator and isPlayerInEvilFaction(player)then outputChatBox("Bankraub gestartet!",player,255,165,0);setPlayerWantedLevel(player,(getElementData(player,"wanted")or 0)+10)end;triggerClientEvent(player,"bankrob:playAlarmSound",resourceRoot,true);setElementData(player,"isPlayingBankAlarm",true)end;local fid,_=getPlayerFractionAndRank(player);if fid==1 or fid==2 then outputChatBox("[ALARM] Bankraub!",player,255,50,50);triggerClientEvent(player,"bankrob:startPoliceNotification",player,EINGANGS_MARKER_POS.x,EINGANGS_MARKER_POS.y,EINGANGS_MARKER_POS.z,"Hauptbank");policeNotificationActive=true end end end
    if not isTimer(robberyInfoUpdateTimer)then robberyInfoUpdateTimer=setTimer(sendRobberyInfoToClients,3000,0)end;sendRobberyInfoToClients()
    if isTimer(mainRobberyTimer)then killTimer(mainRobberyTimer)end;mainRobberyTimer=setTimer(resetBankRobberyState,ROBBERY_TIMER_DURATION,1,true)
    outputChatBox("Bankraub gestartet! Zeit: "..(ROBBERY_TIMER_DURATION/1000/60).." Min.",initiator,255,165,0)
end

-- resetBankRobberyState bleibt strukturell gleich, die givePlayerItem Aufrufe sind wichtig.
function resetBankRobberyState(completedSuccessfully)
    local wasActive = bankRobberyActive
    bankRobberyActive = false; bankCooldownActive = true
    bankCooldownEndTime = getTickCount() + BANK_COOLDOWN_DURATION
    if isTimer(robberyInfoUpdateTimer) then killTimer(robberyInfoUpdateTimer); robberyInfoUpdateTimer = nil end
    if isTimer(mainRobberyTimer) then killTimer(mainRobberyTimer); mainRobberyTimer = nil end
    if isTimer(robberyStallTimer) then killTimer(robberyStallTimer); robberyStallTimer = nil; end

    for _, playerInBank in ipairs(getElementsByType("player")) do
        if isElement(playerInBank) and getElementData(playerInBank, "isPlayingBankAlarm") then
            triggerClientEvent(playerInBank, "bankrob:playAlarmSound", resourceRoot, false)
            setElementData(playerInBank, "isPlayingBankAlarm", false)
        end
    end

    local message = ""; local soundId = 16
    if wasActive then message = completedSuccessfully and "Bankraub erfolgreich abgeschlossen!" or "Bankraub fehlgeschlagen!"; if completedSuccessfully then soundId = 15 end
    elseif safesAreBreached then message = "Der Versuch, die Safes zu sprengen, wurde unterbrochen."
    else message = "Der Bankraubversuch wurde abgebrochen." end

    local eligibleWinners = {}
    if completedSuccessfully and wasActive then
        for accId, _ in pairs(bankRobberyParticipants) do local p = getPlayerFromAccountID(accId); if isElement(p) and getElementInterior(p)==BANK_INTERIOR_ID and getElementDimension(p)==BANK_INTERIOR_DIMENSION_START and isPlayerEligibleForReward(p)then table.insert(eligibleWinners,p)end end
        if #eligibleWinners > 0 then
            calculateCurrentRewardBonus(); local totalRewardPool = STANDARD_REWARD_AMOUNT*(1+currentRewardBonusFactor)
            outputChatBox("Gesamtbeute: $"..string.format("%.0f",totalRewardPool):gsub("(?%d)(?=(%d%d%d)+$)","%1.").." (Bonus: "..string.format("%.0f",currentRewardBonusFactor*100).."%)",root,0,200,50)
            local remainingPool=totalRewardPool;local shares={}; for i=1,#eligibleWinners do local share;if i==#eligibleWinners then share=remainingPool else local avgShare=remainingPool/(#eligibleWinners-i+1);local maxShare=math.min(remainingPool,avgShare*1.5);share=math.random(0,math.floor(maxShare))end;share=math.floor(share);shares[eligibleWinners[i]]=share;remainingPool=remainingPool-share;if remainingPool<0 then remainingPool=0 end end
            if remainingPool>0 and #eligibleWinners>0 and shares[eligibleWinners[#eligibleWinners]]then shares[eligibleWinners[#eligibleWinners]]=shares[eligibleWinners[#eligibleWinners]]+remainingPool elseif remainingPool>0 and #eligibleWinners==1 and shares[eligibleWinners[1]]then shares[eligibleWinners[1]]=shares[eligibleWinners[1]]+remainingPool end
            for winner,shareAmount in pairs(shares)do if isElement(winner)and type(shareAmount)=="number"and shareAmount>0 then givePlayerMoney(winner,shareAmount);local perc=0;if totalRewardPool>0 then perc=(shareAmount/totalRewardPool)*100 end;outputChatBox(string.format("Dein Anteil: $%s (ca. %.1f%%)",tostring(shareAmount):gsub("(?%d)(?=(%d%d%d)+$)","%1."),perc),winner,0,220,80)elseif isElement(winner)and(type(shareAmount)~="number"or shareAmount==0)then outputChatBox("Kein direkter Anteil diesmal.",winner,150,150,150)end end
            lastSuccessfulRobEndTime=getTickCount(); notifyParticipants(message,0,200,50,soundId)
            if math.random(1,100)<=5 then local randomWinnerIndex=math.random(1,#eligibleWinners);local luckyPlayer=eligibleWinners[randomWinnerIndex];if isElement(luckyPlayer)then if exports.tarox:givePlayerItem(luckyPlayer,ITEM_ID_DIAMANT,1)then outputChatBox("Zusätzlich zur Beute hast du einen Diamanten erhalten!",luckyPlayer,0,220,80)end end end
            for _,winner_item in ipairs(eligibleWinners)do if isElement(winner_item)then local randSilber=math.random(1,100);local silberAmount=0;if randSilber<=10 then silberAmount=3 elseif randSilber<=30 then silberAmount=2 elseif randSilber<=65 then silberAmount=1 end;if silberAmount>0 then if exports.tarox:givePlayerItem(winner_item,ITEM_ID_SILBERBARREN,silberAmount)then outputChatBox(string.format("Du hast zusätzlich %dx Silberbarren erhalten!",silberAmount),winner_item,192,192,192)end end;local randGold=math.random(1,100);local goldAmount=0;if randGold<=2 then goldAmount=3 elseif randGold<=7 then goldAmount=2 elseif randGold<=17 then goldAmount=1 end;if goldAmount>0 then if exports.tarox:givePlayerItem(winner_item,ITEM_ID_GOLDBARREN,goldAmount)then outputChatBox(string.format("Du hast zusätzlich %dx Goldbarren erhalten!",goldAmount),winner_item,255,215,0)end end end end
        else notifyParticipants(message,255,165,0,soundId) end
    else notifyParticipants(message,255,165,0,soundId) end
    triggerClientEvent(root,"bankrob:stopRobberyTimer",root);triggerClientEvent(root,"bankrob:cooldownUpdate",root,BANK_COOLDOWN_DURATION)
    if policeNotificationActive then triggerClientEvent(root,"bankrob:stopPoliceNotification",root,"Hauptbank");policeNotificationActive=false end
    safesAreBreached=false; for i,sD in ipairs(SAFE_POSITIONS)do if isElement(sD.object)then removeEventHandler("onElementClicked",sD.object,handleSafeClicked);setElementData(sD.object,"isLootable",false);setElementModel(sD.object,MODEL_SAFE_GESCHLOSSEN)end;SAFE_POSITIONS[i].isLooted=false end
    bankRobberyParticipants={}; local closeDelayT1=(completedSuccessfully and wasActive)and TUER_OFFEN_NACH_RAUB_DAUER or 1000; local closeDelayT2=(completedSuccessfully and wasActive)and TUER_OFFEN_NACH_RAUB_DAUER or 1000
    if isTimer(tuer1_CloseTimer)then killTimer(tuer1_CloseTimer)end;tuer1_CloseTimer=setTimer(resetTuer1State,closeDelayT1,1,true)
    if isTimer(tuer2_CloseTimer)then killTimer(tuer2_CloseTimer)end;tuer2_CloseTimer=setTimer(resetTuer2State,closeDelayT2,1,true)
    if isElement(tuer1_Marker)then destroyElement(tuer1_Marker);tuer1_Marker=nil end;if isElement(tuer2_Marker)then destroyElement(tuer2_Marker);tuer2_Marker=nil end;if isElement(safesMarker)then destroyElement(safesMarker);safesMarker=nil end
    setTimer(createBankMarkers,BANK_COOLDOWN_DURATION+1000,1)
    outputChatBox("Bankraub-Sequenz beendet. Cooldown: "..(BANK_COOLDOWN_DURATION/1000/60).." Min.",root,255,100,0)
end

-- Looten der Safes (handleSafeClicked) bleibt strukturell gleich.
function handleSafeClicked(button,state,player)if button~="left"or state~="down"then return end;if not bankRobberyActive or not getElementData(source,"isLootable")then return end;if not isPlayerEligibleForReward(player)then outputChatBox("Nur berechtigte Spieler.",player,255,100,0)return end;local sID=getElementData(source,"safeID")if not sID then return end;local sD=nil;for i,s in ipairs(SAFE_POSITIONS)do if s.id==sID then sD=s;break end end;if not sD or sD.isLooted then outputChatBox("Safe leer.",player,255,100,0)return end;SAFE_POSITIONS[sD.id].isLooted=true;setElementData(source,"isLootable",false);outputChatBox("Safe gesichert.",player,150,200,255)end

-- Synchronisation bei Reconnect (onPlayerLoginSuccess) bleibt strukturell gleich.
addEventHandler("onPlayerLoginSuccess",root,function()local p=source;local pAccID=getPlayerAccountID(p)if not pAccID then return end;setTimer(function(lP,accID)if not isElement(lP)then return end;if bankRobberyActive and bankRobberyParticipants[accID]then local rT=bankRobberyEndTime-getTickCount()if rT>0 then triggerClientEvent(lP,"bankrob:startRobberyTimer",lP,rT); if getElementInterior(lP)==BANK_INTERIOR_ID and getElementDimension(lP)==BANK_INTERIOR_DIMENSION_START then triggerClientEvent(lP, "bankrob:playAlarmSound", resourceRoot, true); setElementData(lP, "isPlayingBankAlarm", true) end; if getElementInterior(lP)~=BANK_INTERIOR_ID or getElementDimension(lP)~=BANK_INTERIOR_DIMENSION_START then fadeCamera(lP,false,0.5)setTimer(function(pl)if isElement(pl)then setElementInterior(pl,BANK_INTERIOR_ID)setElementDimension(pl,BANK_INTERIOR_DIMENSION_START)setElementPosition(pl,BANK_INTERIOR_SPAWN_POS.x,BANK_INTERIOR_SPAWN_POS.y,BANK_INTERIOR_SPAWN_POS.z)fadeCamera(pl,true,0.5)end end,500,1,lP)end;outputChatBox("Nimmst wieder am Bankraub teil!",lP,255,165,0)else triggerClientEvent(lP,"bankrob:stopRobberyTimer",lP); triggerClientEvent(lP, "bankrob:playAlarmSound", resourceRoot, false); setElementData(lP, "isPlayingBankAlarm", false) end elseif bankCooldownActive then local rCD=bankCooldownEndTime-getTickCount()if rCD>0 then triggerClientEvent(lP,"bankrob:cooldownUpdate",lP,rCD)end end;sendRobberyInfoToClients()end,1500,1,p,pAccID)end)

-- ////////////////////////////////////////////////////////////////////
-- // RESOURCE START/STOP
-- ////////////////////////////////////////////////////////////////////
addEventHandler("onResourceStart",resourceRoot,function()
    -- Verbesserte Überprüfung der Exporte
    if not getPlayerFractionAndRank then
        outputDebugString("[BankRob ERROR] Kritischer Export 'getPlayerFractionAndRank' fehlt! Bankraub-System wird möglicherweise nicht korrekt funktionieren.")
        -- Hier könnte man entscheiden, die Ressource zu stoppen oder nur eine Warnung auszugeben.
    end
    if not exports.tarox or
       not exports.tarox.givePlayerItem or
       not exports.tarox.takePlayerItemByID or
       not exports.tarox.hasPlayerItem or
       not exports.tarox.getItemDefinition then
        outputDebugString("[BankRob ERROR] Wichtige Item-API Exporte aus 'tarox' fehlen! Bankraub-System wird möglicherweise nicht korrekt funktionieren.")
        -- return -- Beendet die Funktion, wenn kritische Exporte fehlen.
    end
    createBankObjects()
    createBankMarkers()
    --outputDebugString("[BankRob] System (V4.2.1 - DB Fehlerbehandlung) gestartet.")
end)

addEventHandler("onResourceStop",resourceRoot,function()
    clearPlayerActionTimers();
    if isTimer(tuer1_CloseTimer)then killTimer(tuer1_CloseTimer);tuer1_CloseTimer=nil end
    if isTimer(tuer2_CloseTimer)then killTimer(tuer2_CloseTimer);tuer2_CloseTimer=nil end
    if isTimer(robberyInfoUpdateTimer)then killTimer(robberyInfoUpdateTimer);robberyInfoUpdateTimer=nil end
    if isTimer(mainRobberyTimer)then killTimer(mainRobberyTimer);mainRobberyTimer=nil end
    if isTimer(robberyStallTimer)then killTimer(robberyStallTimer);robberyStallTimer=nil end
    if isElement(eingangsMarkerElement)then destroyElement(eingangsMarkerElement);eingangsMarkerElement=nil end
    if isElement(ausgangsMarkerElement)then destroyElement(ausgangsMarkerElement);ausgangsMarkerElement=nil end
    if isElement(tuer1_Marker)then destroyElement(tuer1_Marker);tuer1_Marker=nil end
    if isElement(tuer2_Marker)then destroyElement(tuer2_Marker);tuer2_Marker=nil end
    if isElement(safesMarker)then destroyElement(safesMarker);safesMarker=nil end
    if isElement(rewardInfoMarker)then destroyElement(rewardInfoMarker);rewardInfoMarker=nil end
    if isElement(tuer1_Object)then destroyElement(tuer1_Object);tuer1_Object=nil end
    if isElement(tuer2_Object)then destroyElement(tuer2_Object);tuer2_Object=nil end
    for i,sD in ipairs(SAFE_POSITIONS)do if isElement(sD.object)then destroyElement(sD.object);SAFE_POSITIONS[i].object=nil end end

    for _, playerInGame in ipairs(getElementsByType("player")) do
        if getElementData(playerInGame, "isPlayingBankAlarm") then
            triggerClientEvent(playerInGame, "bankrob:playAlarmSound", resourceRoot, false)
            setElementData(playerInGame, "isPlayingBankAlarm", false)
        end
    end
    --outputDebugString("[BankRob] System gestoppt.")
end)

addEventHandler("onPlayerQuit",root,function()
    local pAccID=getPlayerAccountID(source)
    if source==currentActionPlayer then cancelPlayerAction("Spieler hat Spiel verlassen.", nil)end; -- callback nil, da Spieler weg
    if bankRobberyActive and pAccID and bankRobberyParticipants[pAccID]then
        bankRobberyParticipants[pAccID]=nil;
        sendRobberyInfoToClients() -- Aktualisiere Info, da ein Räuber weniger
    end
    if getElementData(source, "isPlayingBankAlarm") then
        setElementData(source, "isPlayingBankAlarm", false)
    end
end)