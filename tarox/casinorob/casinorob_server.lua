-- casinorob_server.lua
-- Basierend auf bankrob_server.lua V4.2, angepasst für Casino-Raub
-- HINZUGEFÜGT: Schwebender Text für Belohnungsmarker & sichtbares C4-Objekt
-- ERWEITERT: Zusätzliche Item-Belohnungen (Farbcode-Fix V2), Alarm-Sound
-- ANGEPASST V4.2.1: Verbesserte Export-Prüfung und Fehlerbehandlung für Item-Operationen

-- ////////////////////////////////////////////////////////////////////
-- // HILFSFUNKTION FÜR ZAHLENFORMATIERUNG
-- ////////////////////////////////////////////////////////////////////
function formatWithThousandSep(number)
    if type(number) ~= "number" then return tostring(number) end
    local s = string.format("%.0f", number)
    local len = #s
    if len <= 3 then return s end
    local res = ""
    for i=1,len do
        res = res .. s:sub(i,i)
        if (len-i) % 3 == 0 and i ~= len and s:sub(i+1,i+1) ~= '-' then
            res = res .. "."
        end
    end
    return res
end

-- ////////////////////////////////////////////////////////////////////
-- // KONFIGURATION & KONSTANTEN
-- ////////////////////////////////////////////////////////////////////

-- ITEM IDs (Casino-spezifisch)
local ITEM_ID_LAPTOP_CASINO    = 11
local ITEM_ID_CROWBAR_CASINO   = 12
local ITEM_ID_C4_CASINO        = 9
-- ITEM IDs für Belohnungen
local ITEM_ID_GOLDEN_CHIP = 15
local ITEM_ID_SILBERBARREN = 13
local ITEM_ID_GOLDBARREN = 10

-- OBJEKT MODELLE (Casino-spezifisch)
local MODEL_LAPTOP_TUER_CASINO  = 1499
local MODEL_CROWBAR_TUER_CASINO = 2885
local MODEL_C4_TUER_CASINO      = 2634 -- Tresortür-Modell
local VISIBLE_C4_MODEL_ID       = 354  -- Modell für das sichtbare C4

-- CASINO INTERIOR EINSTELLUNGEN
local CASINO_INTERIOR_ID          = 1
local CASINO_INTERIOR_DIMENSION   = 0 -- Standard-Dimension für Casino Caligula's
local CASINO_INTERIOR_SPAWN_POS   = { x = 2235.88965, y = 1698.91797, z = 1008.35938 } -- Spawn im Casino

-- MARKER POSITIONEN
local CASINO_EINGANGS_MARKER_POS  = { x = 2165.60620, y = 2164.15283, z = 10.82031 } -- Haupteingang Caligula's
local CASINO_AUSGANGS_MARKER_POS  = { x = 2233.91870, y = 1714.02490, z = 1012.31866 } -- Ausgang im Casino (Nähe Tresorraum-Zugang)
local CASINO_AUSGANG_WELT_POS     = { x = 2163.71582, y = 2160.75879, z = 10.82031 } -- Ziel nach Verlassen des Casinos
local MARKER_LAPTOP_TUER_POS    = { x = 2147.83447, y = 1605.93347, z = 1006.17450 } -- Vor der ersten Tür
local MARKER_CROWBAR_TUER_POS   = { x = 2144.29761, y = 1605.16443, z = 993.56836 }  -- Vor der zweiten Tür (Gitter)
local MARKER_C4_TUER_POS        = { x = 2144.23291, y = 1625.39453, z = 993.68817 }  -- Vor der Tresortür
local CASINO_REWARD_INFO_MARKER_POS = { x = 2238.80, y = 1678.55, z = 1008.55 } -- Im Casino, um Belohnung anzuzeigen

-- OBJEKT POSITIONEN
local LAPTOP_TUER_GESCHLOSSEN_POS = { x = 2147.1000976562, y = 1604.6999511719, z = 1005.200012207, rx = 0, ry = 0, rz = 0 }
local LAPTOP_TUER_GEOEFFNET_POS   = { x = 2145.5,          y = 1604.6999511719, z = 1005.200012207, rx = 0, ry = 0, rz = 0 } -- Tür schwingt nach innen links
local CROWBAR_TUER_GESCHLOSSEN_POS = { x = 2144.3000488281, y = 1606.5999755859, z = 999.29998779297, rx = 0, ry = 0, rz = 0 } -- Gittertür
local CROWBAR_TUER_GEOEFFNET_POS   = { x = 2144.3000488281, y = 1606.5999755859, z = 1003.200012207, rx = 0, ry = 0, rz = 0 } -- Gittertür geht nach oben auf
local C4_TUER_GESCHLOSSEN_POS      = { x = 2144.1999511719, y = 1627.3000488281, z = 994.27001953125, rx = 0, ry = 0, rz = 180 } -- Tresortür
local C4_TUER_GEOEFFNET_POS        = { x = 2146.1,          y = 1627.3000488281, z = 994.27001953125, rx = 0, ry = 0, rz = 180 } -- Tresortür schwingt nach außen
local C4_EXPLOSION_POS             = { x = C4_TUER_GESCHLOSSEN_POS.x + 1, y = C4_TUER_GESCHLOSSEN_POS.y, z = C4_TUER_GESCHLOSSEN_POS.z}

local VISIBLE_C4_POS = { -- Position für das sichtbare C4-Objekt an der Tresortür
    x = C4_TUER_GESCHLOSSEN_POS.x - 0.5, -- Etwas vor der Tür
    y = C4_TUER_GESCHLOSSEN_POS.y,
    z = C4_TUER_GESCHLOSSEN_POS.z + 0.5, -- Mittig auf der Tür
    rx = 90, ry = 0, rz = C4_TUER_GESCHLOSSEN_POS.rz -- Ggf. anpassen, damit es an der Tür "klebt"
}

-- ZEITEN & DAUER
local CASINO_ANIMATION_DURATION         = 15 * 1000 -- Dauer für Hacken, Aufbrechen, C4 platzieren
local CASINO_PREP_DOOR_OPEN_DURATION    = 55 * 60 * 1000 -- Wie lange bleiben Laptop- & Brechstangen-Tür offen
local CASINO_FINAL_DOOR_OPEN_DURATION   = 10 * 60 * 1000 -- Wie lange bleibt Tresortür nach erfolgreichem Raub offen
local CASINO_ROBBERY_STALL_TIMEOUT      = 10 * 60 * 1000 -- Zeit bis Reset bei Inaktivität nach Tür 1/2 Öffnung
local CASINO_C4_DETONATION_DELAY        = 5 * 1000  -- Zeit bis C4 explodiert nach Platzierung
local CASINO_ROBBERY_TIMER_DURATION     = 5 * 60 * 1000 -- Zeit zum Plündern, nachdem Tresortür offen ist
local CASINO_COOLDOWN_DURATION          = getDevelopmentMode() and (2 * 60 * 1000) or (75 * 60 * 1000) -- Cooldown des Casinos
local CASINO_MIN_POLICE_FOR_ROBBERY     = 0 -- Mindestanzahl Cops für Raubstart (Test: 0)

-- BELOHNUNGSSYSTEM
local CASINO_STANDARD_REWARD_AMOUNT         = 750000
local CASINO_REWARD_INCREASE_INTERVAL       = 20 * 60 * 1000 -- Alle 20 Min nach Cooldown-Ende
local CASINO_REWARD_INCREASE_PERCENTAGE     = 0.05  -- Erhöhung um 5%
local CASINO_MAX_REWARD_INCREASE_FACTOR     = 0.15  -- Max. 15% Bonus
local casinoLastSuccessfulRobEndTime        = 0
local casinoCurrentRewardBonusFactor        = 0

-- STATUSVARIABLEN
local laptopTuer_Object, crowbarTuer_Object, c4Tuer_Object
local laptopTuer_IsOpen, crowbarTuer_IsOpen, c4Tuer_IsOpen = false, false, false
local laptopTuer_CloseTimer, crowbarTuer_CloseTimer, c4Tuer_CloseTimer
local laptopTuer_Marker, crowbarTuer_Marker, c4Tuer_Marker, casinoRewardInfoMarker
local casinoEingangsMarkerElement, casinoAusgangsMarkerElement
local casinoRobberyActive               = false
local casinoRobberyEndTime              = 0
local casinoRobberyParticipants         = {}
local casinoPoliceNotificationActive    = false
local casinoCooldownActive              = false
local casinoCooldownEndTime             = 0
local casinoRobberyInfoUpdateTimer, casinoMainRobberyTimer, casinoRobberyStallTimer
local casinoRewardUpdateDisplayTimer    = nil
local casinoCurrentActionPlayer           = nil
local casinoPlayerActionTimer, casinoPlayerMovementCheckTimer
local casinoPlayerActionStartX, casinoPlayerActionStartY, casinoPlayerActionStartZ = 0,0,0
local CASINO_NAME_FOR_BLIP = "Caligula's Casino"
local tempC4Object = nil -- Für das sichtbare C4-Objekt

-- ////////////////////////////////////////////////////////////////////
-- // HILFSFUNKTIONEN
-- ////////////////////////////////////////////////////////////////////
function getCasinoPlayerAccountID(player)
    if not isElement(player) then return nil end
    return getElementData(player, "account_id")
end

function isCasinoPlayerEligibleForReward(player)
    if not isElement(player) then return false end
    local fid, _ = getPlayerFractionAndRank(player)
    local evilFactions = { [4] = true, [5] = true, [6] = true }
    return evilFactions[fid] or fid == 0
end

function isCasinoPlayerInEvilFaction(player)
    if not isElement(player) then return false end
    local playerFractionID, _ = getPlayerFractionAndRank(player)
    if not playerFractionID then return false end
    local evilFactions = { [4] = true, [5] = true, [6] = true }
    return evilFactions[playerFractionID] or false
end

function getCasinoOnlinePoliceCount()
    local count = 0
    for _, player in ipairs(getElementsByType("player")) do
        if getElementData(player, "account_id") then
            local fid, _ = getPlayerFractionAndRank(player)
            if fid == 1 or fid == 2 then count = count + 1 end
        end
    end
    return count
end

function getCasinoPlayerFromAccountID(accountID)
    if not accountID then return nil end; accountID = tonumber(accountID)
    if not accountID then return nil end
    for _, p in ipairs(getElementsByType("player")) do
        local pAccID = getElementData(p, "account_id")
        if pAccID and tonumber(pAccID) == accountID then return p end
    end; return nil
end

function notifyCasinoParticipants(message, r, g, b, sound)
    for accId, _ in pairs(casinoRobberyParticipants) do
        local player = getCasinoPlayerFromAccountID(accId)
        if isElement(player) and getElementInterior(player) == CASINO_INTERIOR_ID and getElementDimension(player) == CASINO_INTERIOR_DIMENSION then
            outputChatBox(message, player, r, g, b)
            if sound then playSoundFrontEnd(player, sound) end
        end
    end
end

function sendCasinoRobberyInfoToClients()
    if not casinoRobberyActive then
        if isTimer(casinoRobberyInfoUpdateTimer) then killTimer(casinoRobberyInfoUpdateTimer); casinoRobberyInfoUpdateTimer = nil; end
        return
    end
    local onlineCops = getCasinoOnlinePoliceCount()
    local robbersInCasinoCount = 0
    for accId, _ in pairs(casinoRobberyParticipants) do
        local p = getCasinoPlayerFromAccountID(accId)
        if isElement(p) and getElementInterior(p) == CASINO_INTERIOR_ID and getElementDimension(p) == CASINO_INTERIOR_DIMENSION then
            robbersInCasinoCount = robbersInCasinoCount + 1
        end
    end
    triggerClientEvent(root, "casinorob:updateRobberyInfo", resourceRoot, onlineCops, robbersInCasinoCount)
end

-- ////////////////////////////////////////////////////////////////////
-- // BELOHNUNGSSYSTEM LOGIK
-- ////////////////////////////////////////////////////////////////////
function calculateCasinoCurrentRewardBonus()
    if casinoLastSuccessfulRobEndTime == 0 then casinoCurrentRewardBonusFactor = 0; return end
    local timeAfterCooldownForBonus = getTickCount() - (casinoLastSuccessfulRobEndTime + CASINO_COOLDOWN_DURATION)
    if timeAfterCooldownForBonus <= 0 then casinoCurrentRewardBonusFactor = 0; return end

    if timeAfterCooldownForBonus < CASINO_REWARD_INCREASE_INTERVAL then
        casinoCurrentRewardBonusFactor = 0
    else
        local bonusIntervals = math.floor(timeAfterCooldownForBonus / CASINO_REWARD_INCREASE_INTERVAL)
        casinoCurrentRewardBonusFactor = math.min(CASINO_MAX_REWARD_INCREASE_FACTOR, bonusIntervals * CASINO_REWARD_INCREASE_PERCENTAGE)
    end
end

function getCasinoCurrentTotalRewardAmount()
    calculateCasinoCurrentRewardBonus()
    return math.floor(CASINO_STANDARD_REWARD_AMOUNT * (1 + casinoCurrentRewardBonusFactor))
end

function getCasinoFormattedRewardStatus()
    local totalAbsoluteReward = getCasinoCurrentTotalRewardAmount()
    local formattedTotalAmount = formatWithThousandSep(totalAbsoluteReward)
    local formattedStandardAmount = formatWithThousandSep(CASINO_STANDARD_REWARD_AMOUNT)

    if casinoCurrentRewardBonusFactor == 0 then
        return "Aktuelle Belohnung: Standard ($" .. formattedStandardAmount .. ")"
    else
        return string.format("Aktuelle Belohnung: Standard + %.0f%% Bonus ($%s)", casinoCurrentRewardBonusFactor * 100, formattedTotalAmount)
    end
end

function sendCurrentCasinoRewardToClients()
    local currentTotalReward = getCasinoCurrentTotalRewardAmount()
    local playersInCasino = {}
    for _, player in ipairs(getElementsByType("player")) do
        if isElement(player) and getElementData(player, "account_id") then
            if getElementInterior(player) == CASINO_INTERIOR_ID and getElementDimension(player) == CASINO_INTERIOR_DIMENSION then
                table.insert(playersInCasino, player)
            end
        end
    end
    if #playersInCasino > 0 then
        triggerClientEvent(playersInCasino, "casinorob:updateRewardDisplay", resourceRoot, currentTotalReward)
    end
end

-- Marker und Objekt Erstellung, Aktionsmarker, Aktionen Durchführen, Tür Reset, Inaktivitäts-Reset bleiben strukturell sehr ähnlich zu bankrob_server.lua
-- Hauptunterschiede sind die spezifischen Items, Modelle, Positionen und die Anzahl der Türen.
-- Die Fehlerbehandlung für Item-Operationen (`exports.tarox:hasPlayerItem`, `exports.tarox:takePlayerItemByID`, `exports.tarox:givePlayerItem`)
-- wird wie in bankrob_server.lua gehandhabt, basierend auf den (erwarteten) Rückgabewerten dieser Funktionen.

-- ////////////////////////////////////////////////////////////////////
-- // MARKER ERSTELLUNG & HANDLING
-- ////////////////////////////////////////////////////////////////////
function createCasinoMarkers()
    if isElement(casinoEingangsMarkerElement) then destroyElement(casinoEingangsMarkerElement) end
    casinoEingangsMarkerElement = createMarker(CASINO_EINGANGS_MARKER_POS.x, CASINO_EINGANGS_MARKER_POS.y, CASINO_EINGANGS_MARKER_POS.z - 1, "cylinder", 1.5, 0, 255, 0, 150)
    if isElement(casinoEingangsMarkerElement) then
        addEventHandler("onMarkerHit", casinoEingangsMarkerElement,
            function(hitElement, matchingDimension)
                if getElementType(hitElement) ~= "player" or not matchingDimension or isPedInVehicle(hitElement) then return end
                local canEnter = true; local playerFractionID, _ = getPlayerFractionAndRank(hitElement)
                if casinoRobberyActive then local playerAccID=getCasinoPlayerAccountID(hitElement); if not casinoRobberyParticipants[playerAccID]and playerFractionID~=1 and playerFractionID~=2 then outputChatBox("Casino wird ausgeraubt.",hitElement,255,100,0);canEnter=false end end
                if canEnter then fadeCamera(hitElement,false,0.5);setTimer(function(player)if isElement(player)then setElementInterior(player,CASINO_INTERIOR_ID);setElementDimension(player,CASINO_INTERIOR_DIMENSION);setElementPosition(player,CASINO_INTERIOR_SPAWN_POS.x,CASINO_INTERIOR_SPAWN_POS.y,CASINO_INTERIOR_SPAWN_POS.z);fadeCamera(player,true,0.5);sendCurrentCasinoRewardToClients();if casinoRobberyActive then triggerClientEvent(player,"casinorob:startRobberyTimer",player,math.max(0,casinoRobberyEndTime-getTickCount()));sendCasinoRobberyInfoToClients()end;if casinoCooldownActive then triggerClientEvent(player,"casinorob:cooldownUpdate",player,math.max(0,casinoCooldownEndTime-getTickCount()))end end end,500,1,hitElement)end
            end
        )
    else outputDebugString("[CasinoRob ERROR] EingangsMarker konnte nicht erstellt werden!") end

    if isElement(casinoAusgangsMarkerElement) then destroyElement(casinoAusgangsMarkerElement) end
    casinoAusgangsMarkerElement = createMarker(CASINO_AUSGANGS_MARKER_POS.x, CASINO_AUSGANGS_MARKER_POS.y, CASINO_AUSGANGS_MARKER_POS.z - 1, "cylinder", 1.5, 255, 0, 0, 150)
    if isElement(casinoAusgangsMarkerElement) then setElementInterior(casinoAusgangsMarkerElement,CASINO_INTERIOR_ID);setElementDimension(casinoAusgangsMarkerElement,CASINO_INTERIOR_DIMENSION)
        addEventHandler("onMarkerHit",casinoAusgangsMarkerElement,
            function(hitElement,matchingDimension)
                if getElementType(hitElement)~="player"or not matchingDimension or isPedInVehicle(hitElement)then return end
                fadeCamera(hitElement,false,0.5);setTimer(function(player)if isElement(player)then setElementInterior(player,0);setElementDimension(player,0);setElementPosition(player,CASINO_AUSGANG_WELT_POS.x,CASINO_AUSGANG_WELT_POS.y,CASINO_AUSGANG_WELT_POS.z);fadeCamera(player,true,0.5);local fidExt,_=getPlayerFractionAndRank(player);if fidExt~=1 and fidExt~=2 then triggerClientEvent(player,"casinorob:stopRobberyTimer",player);if getElementData(player,"isPlayingCasinoAlarm")then triggerClientEvent(player,"casinorob:playAlarmSound",resourceRoot,false);setElementData(player,"isPlayingCasinoAlarm",false)end end;triggerClientEvent(player,"casinorob:stopRewardDisplay",player)end end,500,1,hitElement)
            end
        )
    else outputDebugString("[CasinoRob ERROR] AusgangsMarker konnte nicht erstellt werden!") end

    if isElement(laptopTuer_Marker) then destroyElement(laptopTuer_Marker); laptopTuer_Marker = nil; end
    if not laptopTuer_IsOpen and not (casinoCooldownActive and getTickCount() < casinoCooldownEndTime) then
        laptopTuer_Marker = createMarker(MARKER_LAPTOP_TUER_POS.x, MARKER_LAPTOP_TUER_POS.y, MARKER_LAPTOP_TUER_POS.z - 1, "cylinder", 1.2, 255, 200, 0, 180)
        if isElement(laptopTuer_Marker) then setElementInterior(laptopTuer_Marker,CASINO_INTERIOR_ID);setElementDimension(laptopTuer_Marker,CASINO_INTERIOR_DIMENSION);setElementData(laptopTuer_Marker,"casinoAction","laptopTuerHacken");addEventHandler("onMarkerHit",laptopTuer_Marker,handleCasinoActionMarkerHit)
        else outputDebugString("[CasinoRob ERROR] laptopTuer_Marker konnte nicht erstellt werden!") end
    end

    if isElement(casinoRewardInfoMarker) then destroyElement(casinoRewardInfoMarker) end
    casinoRewardInfoMarker = createMarker(CASINO_REWARD_INFO_MARKER_POS.x, CASINO_REWARD_INFO_MARKER_POS.y, CASINO_REWARD_INFO_MARKER_POS.z -1, "cylinder", 1.0, 0, 220, 220, 100)
    if isElement(casinoRewardInfoMarker) then setElementInterior(casinoRewardInfoMarker,CASINO_INTERIOR_ID);setElementDimension(casinoRewardInfoMarker,CASINO_INTERIOR_DIMENSION);setElementData(casinoRewardInfoMarker,"isCasinoRewardDisplayMarker",true,true)
        addEventHandler("onMarkerHit",casinoRewardInfoMarker, function(hitElement,matchingDimension)if getElementType(hitElement)~="player"or not matchingDimension or isPedInVehicle(hitElement)then return end;if isCasinoPlayerEligibleForReward(hitElement)then outputChatBox(getCasinoFormattedRewardStatus(),hitElement,0,220,220)end end)
    else outputDebugString("[CasinoRob ERROR] CasinoRewardInfoMarker konnte nicht erstellt werden!") end
    --outputDebugString("[CasinoRob] Casino-Marker erstellt/aktualisiert."); sendCurrentCasinoRewardToClients()
end

-- ////////////////////////////////////////////////////////////////////
-- // OBJEKT ERSTELLUNG & HANDLING
-- ////////////////////////////////////////////////////////////////////
function createCasinoObjects()
    if isElement(laptopTuer_Object) then destroyElement(laptopTuer_Object) end
    laptopTuer_Object=createObject(MODEL_LAPTOP_TUER_CASINO,LAPTOP_TUER_GESCHLOSSEN_POS.x,LAPTOP_TUER_GESCHLOSSEN_POS.y,LAPTOP_TUER_GESCHLOSSEN_POS.z,LAPTOP_TUER_GESCHLOSSEN_POS.rx,LAPTOP_TUER_GESCHLOSSEN_POS.ry,LAPTOP_TUER_GESCHLOSSEN_POS.rz)
    if isElement(laptopTuer_Object)then setElementInterior(laptopTuer_Object,CASINO_INTERIOR_ID);setElementDimension(laptopTuer_Object,CASINO_INTERIOR_DIMENSION);setElementFrozen(laptopTuer_Object,true);laptopTuer_IsOpen=false else outputDebugString("[CasinoRob ERROR] laptopTuer_Object Erstellung fehlgeschlagen!")end
    if isElement(crowbarTuer_Object)then destroyElement(crowbarTuer_Object)end
    crowbarTuer_Object=createObject(MODEL_CROWBAR_TUER_CASINO,CROWBAR_TUER_GESCHLOSSEN_POS.x,CROWBAR_TUER_GESCHLOSSEN_POS.y,CROWBAR_TUER_GESCHLOSSEN_POS.z,CROWBAR_TUER_GESCHLOSSEN_POS.rx,CROWBAR_TUER_GESCHLOSSEN_POS.ry,CROWBAR_TUER_GESCHLOSSEN_POS.rz)
    if isElement(crowbarTuer_Object)then setElementInterior(crowbarTuer_Object,CASINO_INTERIOR_ID);setElementDimension(crowbarTuer_Object,CASINO_INTERIOR_DIMENSION);setElementFrozen(crowbarTuer_Object,true);crowbarTuer_IsOpen=false else outputDebugString("[CasinoRob ERROR] crowbarTuer_Object Erstellung fehlgeschlagen!")end
    if isElement(c4Tuer_Object)then destroyElement(c4Tuer_Object)end
    c4Tuer_Object=createObject(MODEL_C4_TUER_CASINO,C4_TUER_GESCHLOSSEN_POS.x,C4_TUER_GESCHLOSSEN_POS.y,C4_TUER_GESCHLOSSEN_POS.z,C4_TUER_GESCHLOSSEN_POS.rx,C4_TUER_GESCHLOSSEN_POS.ry,C4_TUER_GESCHLOSSEN_POS.rz)
    if isElement(c4Tuer_Object)then setElementInterior(c4Tuer_Object,CASINO_INTERIOR_ID);setElementDimension(c4Tuer_Object,CASINO_INTERIOR_DIMENSION);setElementFrozen(c4Tuer_Object,true);c4Tuer_IsOpen=false else outputDebugString("[CasinoRob ERROR] c4Tuer_Object Erstellung fehlgeschlagen!")end
    --outputDebugString("[CasinoRob] Casino-Objekte (Türen) erstellt.")
end

-- ////////////////////////////////////////////////////////////////////
-- // AKTIONSMARKER HANDLING
-- ////////////////////////////////////////////////////////////////////
function handleCasinoActionMarkerHit(hitElement, matchingDimension)
    if getElementType(hitElement)~="player"or not matchingDimension or isPedInVehicle(hitElement)then return end
    if casinoCurrentActionPlayer and casinoCurrentActionPlayer~=hitElement then outputChatBox("Anderer Spieler führt Aktion aus.",hitElement,255,100,0);return end
    if casinoCooldownActive and getTickCount()<casinoCooldownEndTime then local remCD=math.ceil((casinoCooldownEndTime-getTickCount())/1000/60);outputChatBox("Casino noch für ca. "..remCD.." Min. im Cooldown.",hitElement,255,100,0);return end
    if casinoRobberyActive then local act=getElementData(source,"casinoAction");if act=="laptopTuerHacken"or act=="crowbarTuerOeffnen"then outputChatBox("Casinoraub läuft! Aktion nicht mehr möglich.",hitElement,255,100,0);return end end
    local action=getElementData(source,"casinoAction")
    if not isCasinoPlayerInEvilFaction(hitElement)then outputChatBox("Nur für kriminelle Organisationen.",hitElement,255,0,0);return end
    local message,requiredItem,actionType = "",nil,""; local hasItemResult = false

    if action=="laptopTuerHacken"then if laptopTuer_IsOpen then outputChatBox("Tür bereits offen.",hitElement,0,150,255);return end
        hasItemResult = exports.tarox:hasPlayerItem(hitElement,ITEM_ID_LAPTOP_CASINO,1)
        if not hasItemResult then outputChatBox("Benötigst Laptop.",hitElement,255,100,0);return end
        message,requiredItem,actionType="Tür mit Laptop hacken? ("..(CASINO_ANIMATION_DURATION/1000).." Sek.)",ITEM_ID_LAPTOP_CASINO,"laptopTuerHacken"
    elseif action=="crowbarTuerOeffnen"then if crowbarTuer_IsOpen then outputChatBox("Tür bereits offen.",hitElement,0,150,255);return end
        hasItemResult = exports.tarox:hasPlayerItem(hitElement,ITEM_ID_CROWBAR_CASINO,1)
        if not hasItemResult then outputChatBox("Benötigst Brechstange.",hitElement,255,100,0);return end
        message,requiredItem,actionType="Tür mit Brechstange aufbrechen? ("..(CASINO_ANIMATION_DURATION/1000).." Sek.)",ITEM_ID_CROWBAR_CASINO,"crowbarTuerOeffnen"
    elseif action=="c4TuerSprengen"then if c4Tuer_IsOpen then outputChatBox("Tür bereits offen.",hitElement,0,150,255);return end
        hasItemResult = exports.tarox:hasPlayerItem(hitElement,ITEM_ID_C4_CASINO,1)
        if not hasItemResult then outputChatBox("Benötigst C4.",hitElement,255,100,0);return end
        message,requiredItem,actionType="C4 an Tresortür platzieren? ("..(CASINO_ANIMATION_DURATION/1000).." Sek. Vorbereitung)",ITEM_ID_C4_CASINO,"c4TuerSprengen"
    else return end
    triggerClientEvent(hitElement,"casinorob:requestActionConfirmation",hitElement,message,actionType,requiredItem)
end

-- ////////////////////////////////////////////////////////////////////
-- // AKTIONEN DURCHFÜHREN
-- ////////////////////////////////////////////////////////////////////
function startCasinoPlayerAction(player, actionName, successCallback, failureCallback, requiredItem, animationLib, animationName)
    if casinoCurrentActionPlayer then return false end
    casinoCurrentActionPlayer=player;setElementData(player,"casinorob:isDoingAction",true)
    casinoPlayerActionStartX,casinoPlayerActionStartY,casinoPlayerActionStartZ=getElementPosition(player)
    if animationLib and animationName then setPedAnimation(player,animationLib,animationName,-1,true,false,false,false)else setPedAnimation(player,"SCRATCHING","sclng_r",-1,true,false,false,false)end
    toggleAllControls(player,false,true,false)
    casinoPlayerMovementCheckTimer=setTimer(function()if not isElement(casinoCurrentActionPlayer)then cancelCasinoPlayerAction("Spieler ungültig",failureCallback);return end;local cX,cY,cZ=getElementPosition(casinoCurrentActionPlayer);if getDistanceBetweenPoints3D(casinoPlayerActionStartX,casinoPlayerActionStartY,casinoPlayerActionStartZ,cX,cY,cZ)>0.7 then cancelCasinoPlayerAction("Spieler bewegt",failureCallback)end end,500,0)
    casinoPlayerActionTimer=setTimer(function()
        if not isElement(casinoCurrentActionPlayer)then cancelCasinoPlayerAction("Spieler ungültig",failureCallback);return end
        local itemTakenSuccessfully=true
        if requiredItem then
            local itemTaken, takeMsg = exports.tarox:takePlayerItemByID(casinoCurrentActionPlayer,requiredItem,1) -- Rückgabewerte prüfen
            if not itemTaken then itemTakenSuccessfully=false;outputChatBox("Fehler: Item nicht entfernbar: "..(takeMsg or ""),casinoCurrentActionPlayer,255,0,0)end
        end
        clearCasinoPlayerActionTimers()
        if isElement(casinoCurrentActionPlayer)then setPedAnimation(casinoCurrentActionPlayer,false);toggleAllControls(casinoCurrentActionPlayer,true,true,true);removeElementData(casinoCurrentActionPlayer,"casinorob:isDoingAction");if itemTakenSuccessfully then successCallback(casinoCurrentActionPlayer)elseif failureCallback then failureCallback(casinoCurrentActionPlayer)end end
        casinoCurrentActionPlayer=nil
    end,CASINO_ANIMATION_DURATION,1)
    outputChatBox("Aktion '"..actionName.."' gestartet... Nicht bewegen!",player,0,150,255);return true
end

function cancelCasinoPlayerAction(reason, callback)
    local player=casinoCurrentActionPlayer;if not player then return end;casinoCurrentActionPlayer=nil;clearCasinoPlayerActionTimers()
    if isElement(player)then outputChatBox("Aktion abgebrochen: "..reason,player,255,0,0);setPedAnimation(player,false);toggleAllControls(player,true,true,true);removeElementData(player,"casinorob:isDoingAction");if callback then callback(player)end end
end

function clearCasinoPlayerActionTimers()
    if isTimer(casinoPlayerActionTimer)then killTimer(casinoPlayerActionTimer);casinoPlayerActionTimer=nil end
    if isTimer(casinoPlayerMovementCheckTimer)then killTimer(casinoPlayerMovementCheckTimer);casinoPlayerMovementCheckTimer=nil end
end

addEvent("casinorob:confirmAction", true)
addEventHandler("casinorob:confirmAction", root, function(actionType, itemUsed)
    local player = client
    if not isElement(player) or (casinoCurrentActionPlayer and casinoCurrentActionPlayer ~= player) then return end
    local success = false
    local failureFunc = function(p) outputChatBox("Aktion fehlgeschlagen.",p,255,0,0) end

    if actionType == "laptopTuerHacken" then
        if laptopTuer_IsOpen then outputChatBox("Tür bereits offen.",player,255,100,0);return end
        success=startCasinoPlayerAction(player,"Laptop Tür hacken",
            function(p)
                if not isElement(laptopTuer_Object)then outputDebugString("[CasinoRob ERROR] laptopTuer_Object ungültig!");return end
                moveObject(laptopTuer_Object,1500,LAPTOP_TUER_GEOEFFNET_POS.x,LAPTOP_TUER_GEOEFFNET_POS.y,LAPTOP_TUER_GEOEFFNET_POS.z,LAPTOP_TUER_GEOEFFNET_POS.rx-LAPTOP_TUER_GESCHLOSSEN_POS.rx,LAPTOP_TUER_GEOEFFNET_POS.ry-LAPTOP_TUER_GESCHLOSSEN_POS.ry,LAPTOP_TUER_GEOEFFNET_POS.rz-LAPTOP_TUER_GESCHLOSSEN_POS.rz)
                laptopTuer_IsOpen=true;outputChatBox("Laptop Tür gehackt!",p,0,255,0)
                if isElement(laptopTuer_Marker)then destroyElement(laptopTuer_Marker);laptopTuer_Marker=nil end
                if not crowbarTuer_IsOpen then if isElement(crowbarTuer_Marker)then destroyElement(crowbarTuer_Marker)end;crowbarTuer_Marker=createMarker(MARKER_CROWBAR_TUER_POS.x,MARKER_CROWBAR_TUER_POS.y,MARKER_CROWBAR_TUER_POS.z-1,"cylinder",1.2,255,150,0,180);setElementInterior(crowbarTuer_Marker,CASINO_INTERIOR_ID);setElementDimension(crowbarTuer_Marker,CASINO_INTERIOR_DIMENSION);setElementData(crowbarTuer_Marker,"casinoAction","crowbarTuerOeffnen");addEventHandler("onMarkerHit",crowbarTuer_Marker,handleCasinoActionMarkerHit);startCasinoRobberyStallTimer()end
                if isTimer(laptopTuer_CloseTimer)then killTimer(laptopTuer_CloseTimer)end;laptopTuer_CloseTimer=setTimer(resetLaptopTuerState,CASINO_PREP_DOOR_OPEN_DURATION,1,false)
            end, function(p) failureFunc(p); createCasinoMarkers() end, ITEM_ID_LAPTOP_CASINO,"DEALER","DEALER_DEAL_LOOP"
        )
    elseif actionType == "crowbarTuerOeffnen" then
        if crowbarTuer_IsOpen then outputChatBox("Tür bereits offen.",player,255,100,0);return end
        success=startCasinoPlayerAction(player,"Brechstangen Tür öffnen",
            function(p)
                if not isElement(crowbarTuer_Object)then outputDebugString("[CasinoRob ERROR] crowbarTuer_Object ungültig!");return end
                moveObject(crowbarTuer_Object,1500,CROWBAR_TUER_GEOEFFNET_POS.x,CROWBAR_TUER_GEOEFFNET_POS.y,CROWBAR_TUER_GEOEFFNET_POS.z,CROWBAR_TUER_GEOEFFNET_POS.rx-CROWBAR_TUER_GESCHLOSSEN_POS.rx,CROWBAR_TUER_GEOEFFNET_POS.ry-CROWBAR_TUER_GESCHLOSSEN_POS.ry,CROWBAR_TUER_GEOEFFNET_POS.rz-CROWBAR_TUER_GESCHLOSSEN_POS.rz)
                crowbarTuer_IsOpen=true;outputChatBox("Brechstangen Tür geöffnet!",p,0,255,0)
                if isElement(crowbarTuer_Marker)then destroyElement(crowbarTuer_Marker);crowbarTuer_Marker=nil end
                if not c4Tuer_IsOpen then if isElement(c4Tuer_Marker)then destroyElement(c4Tuer_Marker)end;c4Tuer_Marker=createMarker(MARKER_C4_TUER_POS.x,MARKER_C4_TUER_POS.y,MARKER_C4_TUER_POS.z-1,"cylinder",1.2,255,100,0,180);setElementInterior(c4Tuer_Marker,CASINO_INTERIOR_ID);setElementDimension(c4Tuer_Marker,CASINO_INTERIOR_DIMENSION);setElementData(c4Tuer_Marker,"casinoAction","c4TuerSprengen");addEventHandler("onMarkerHit",c4Tuer_Marker,handleCasinoActionMarkerHit);startCasinoRobberyStallTimer()end
                if isTimer(crowbarTuer_CloseTimer)then killTimer(crowbarTuer_CloseTimer)end;crowbarTuer_CloseTimer=setTimer(resetCrowbarTuerState,CASINO_PREP_DOOR_OPEN_DURATION,1,false)
            end, function(p) failureFunc(p); if laptopTuer_IsOpen then createCasinoMarkers() end end, ITEM_ID_CROWBAR_CASINO,"SWORD","AXE_Chop_Loop"
        )
    elseif actionType == "c4TuerSprengen" then
        if c4Tuer_IsOpen then outputChatBox("Tür bereits offen.",player,255,100,0);return end
        success=startCasinoPlayerAction(player,"C4 an Tresortür anbringen",
            function(p)
                outputChatBox("C4 platziert! Zündung in "..(CASINO_C4_DETONATION_DELAY/1000).." Sek...",p,255,50,0)
                if isElement(c4Tuer_Marker)then destroyElement(c4Tuer_Marker);c4Tuer_Marker=nil end
                if isTimer(casinoRobberyStallTimer)then killTimer(casinoRobberyStallTimer);casinoRobberyStallTimer=nil;end
                if isElement(tempC4Object)then destroyElement(tempC4Object)end;tempC4Object=createObject(VISIBLE_C4_MODEL_ID,VISIBLE_C4_POS.x,VISIBLE_C4_POS.y,VISIBLE_C4_POS.z,VISIBLE_C4_POS.rx,VISIBLE_C4_POS.ry,VISIBLE_C4_POS.rz)
                if isElement(tempC4Object)then setElementInterior(tempC4Object,CASINO_INTERIOR_ID);setElementDimension(tempC4Object,CASINO_INTERIOR_DIMENSION);setElementFrozen(tempC4Object,true)else outputDebugString("[CasinoRob ERROR] Sichtbares C4 nicht erstellt!")end
                setTimer(function()
                    if(casinoCooldownActive and getTickCount()<casinoCooldownEndTime)or casinoRobberyActive then if isElement(tempC4Object)then destroyElement(tempC4Object);tempC4Object=nil;end;return end
                    if isElement(tempC4Object)then destroyElement(tempC4Object);tempC4Object=nil;end
                    createExplosion(C4_EXPLOSION_POS.x,C4_EXPLOSION_POS.y,C4_EXPLOSION_POS.z,12)
                    if not isElement(c4Tuer_Object)then outputDebugString("[CasinoRob ERROR] c4Tuer_Object ungültig!");return end
                    moveObject(c4Tuer_Object,1500,C4_TUER_GEOEFFNET_POS.x,C4_TUER_GEOEFFNET_POS.y,C4_TUER_GEOEFFNET_POS.z,C4_TUER_GEOEFFNET_POS.rx-C4_TUER_GESCHLOSSEN_POS.rx,C4_TUER_GEOEFFNET_POS.ry-C4_TUER_GESCHLOSSEN_POS.ry,C4_TUER_GEOEFFNET_POS.rz-C4_TUER_GESCHLOSSEN_POS.rz)
                    c4Tuer_IsOpen=true;startCasinoRobbery(p)
                end,CASINO_C4_DETONATION_DELAY,1)
            end, function(p) failureFunc(p); if crowbarTuer_IsOpen and not isElement(c4Tuer_Marker)and not c4Tuer_IsOpen then c4Tuer_Marker=createMarker(MARKER_C4_TUER_POS.x,MARKER_C4_TUER_POS.y,MARKER_C4_TUER_POS.z-1,"cylinder",1.2,255,100,0,180);setElementInterior(c4Tuer_Marker,CASINO_INTERIOR_ID);setElementDimension(c4Tuer_Marker,CASINO_INTERIOR_DIMENSION);setElementData(c4Tuer_Marker,"casinoAction","c4TuerSprengen");addEventHandler("onMarkerHit",c4Tuer_Marker,handleCasinoActionMarkerHit)end end,ITEM_ID_C4_CASINO,"BOMBER","BOMB_Place_Loop"
        )
    end
    if not success and casinoCurrentActionPlayer == player then casinoCurrentActionPlayer = nil end
end)

-- ////////////////////////////////////////////////////////////////////
-- // TÜREN ZURÜCKSETZEN
-- ////////////////////////////////////////////////////////////////////
function resetLaptopTuerState(forceCloseImmediately)
    forceCloseImmediately=forceCloseImmediately or false;if isTimer(laptopTuer_CloseTimer)then killTimer(laptopTuer_CloseTimer);laptopTuer_CloseTimer=nil end
    if isElement(laptopTuer_Object)and laptopTuer_IsOpen then moveObject(laptopTuer_Object,1500,LAPTOP_TUER_GESCHLOSSEN_POS.x,LAPTOP_TUER_GESCHLOSSEN_POS.y,LAPTOP_TUER_GESCHLOSSEN_POS.z,LAPTOP_TUER_GESCHLOSSEN_POS.rx-LAPTOP_TUER_GEOEFFNET_POS.rx,LAPTOP_TUER_GESCHLOSSEN_POS.ry-LAPTOP_TUER_GEOEFFNET_POS.ry,LAPTOP_TUER_GESCHLOSSEN_POS.rz-LAPTOP_TUER_GEOEFFNET_POS.rz);laptopTuer_IsOpen=false;outputChatBox("Casino Laptop Tür geschlossen.",root,255,150,0);if not(casinoCooldownActive and getTickCount()<casinoCooldownEndTime)and not casinoRobberyActive and not isElement(laptopTuer_Marker)then createCasinoMarkers()end;if isElement(crowbarTuer_Marker)and not crowbarTuer_IsOpen then destroyElement(crowbarTuer_Marker);crowbarTuer_Marker=nil end;if forceCloseImmediately and isTimer(casinoRobberyStallTimer)then if not crowbarTuer_IsOpen and not c4Tuer_IsOpen then killTimer(casinoRobberyStallTimer);casinoRobberyStallTimer=nil;outputDebugString("[CasinoRob] Stall Timer (Laptop Tür Reset).")end end end
end
function resetCrowbarTuerState(forceCloseImmediately)
    forceCloseImmediately=forceCloseImmediately or false;if isTimer(crowbarTuer_CloseTimer)then killTimer(crowbarTuer_CloseTimer);crowbarTuer_CloseTimer=nil end
    if isElement(crowbarTuer_Object)and crowbarTuer_IsOpen then moveObject(crowbarTuer_Object,1500,CROWBAR_TUER_GESCHLOSSEN_POS.x,CROWBAR_TUER_GESCHLOSSEN_POS.y,CROWBAR_TUER_GESCHLOSSEN_POS.z,CROWBAR_TUER_GESCHLOSSEN_POS.rx-CROWBAR_TUER_GEOEFFNET_POS.rx,CROWBAR_TUER_GESCHLOSSEN_POS.ry-CROWBAR_TUER_GEOEFFNET_POS.ry,CROWBAR_TUER_GESCHLOSSEN_POS.rz-CROWBAR_TUER_GEOEFFNET_POS.rz);crowbarTuer_IsOpen=false;outputChatBox("Casino Brechstangen Tür geschlossen.",root,255,150,0);if not(casinoCooldownActive and getTickCount()<casinoCooldownEndTime)and not casinoRobberyActive and laptopTuer_IsOpen and not isElement(crowbarTuer_Marker)then createCasinoMarkers()end;if isElement(c4Tuer_Marker)and not c4Tuer_IsOpen then destroyElement(c4Tuer_Marker);c4Tuer_Marker=nil end;if forceCloseImmediately and isTimer(casinoRobberyStallTimer)then if not c4Tuer_IsOpen then killTimer(casinoRobberyStallTimer);casinoRobberyStallTimer=nil;outputDebugString("[CasinoRob] Stall Timer (Brechstangen Tür Reset).")end end end
end
function resetC4TuerState()
    if isElement(c4Tuer_Object)and c4Tuer_IsOpen then moveObject(c4Tuer_Object,1500,C4_TUER_GESCHLOSSEN_POS.x,C4_TUER_GESCHLOSSEN_POS.y,C4_TUER_GESCHLOSSEN_POS.z,C4_TUER_GESCHLOSSEN_POS.rx-C4_TUER_GEOEFFNET_POS.rx,C4_TUER_GESCHLOSSEN_POS.ry-C4_TUER_GEOEFFNET_POS.ry,C4_TUER_GESCHLOSSEN_POS.rz-C4_TUER_GEOEFFNET_POS.rz);c4Tuer_IsOpen=false;outputChatBox("Casino Tresortür geschlossen.",root,255,150,0);if not(casinoCooldownActive and getTickCount()<casinoCooldownEndTime)and not casinoRobberyActive and crowbarTuer_IsOpen and not isElement(c4Tuer_Marker)then createCasinoMarkers()end end
end

-- ////////////////////////////////////////////////////////////////////
-- // INAKTIVITÄTS-RESET LOGIK
-- ////////////////////////////////////////////////////////////////////
function startCasinoRobberyStallTimer()
    if isTimer(casinoRobberyStallTimer)then killTimer(casinoRobberyStallTimer)end
    outputDebugString("[CasinoRob] Inaktivitäts-Timer gestartet ("..CASINO_ROBBERY_STALL_TIMEOUT/1000/60 .." Min).")
    casinoRobberyStallTimer=setTimer(function()if not casinoRobberyActive and(laptopTuer_IsOpen or crowbarTuer_IsOpen)and not c4Tuer_IsOpen then outputChatBox("Casino-Raubversuch wegen Inaktivität zurückgesetzt.",root,255,100,0);outputDebugString("[CasinoRob] Inaktivitäts-Timeout erreicht. Reset.");resetCasinoRobberyState(false)end;casinoRobberyStallTimer=nil end,CASINO_ROBBERY_STALL_TIMEOUT,1)
end

-- ////////////////////////////////////////////////////////////////////
-- // HAUPT-CASINORAUB LOGIK
-- ////////////////////////////////////////////////////////////////////
function startCasinoRobbery(initiator)
    if casinoRobberyActive or(casinoCooldownActive and getTickCount()<casinoCooldownEndTime)then outputChatBox("Casino nicht ausraubbar.",initiator,255,100,0);return end
    local onlineCops=getCasinoOnlinePoliceCount()
    if onlineCops<CASINO_MIN_POLICE_FOR_ROBBERY then outputChatBox("Nicht genügend Polizisten ("..CASINO_MIN_POLICE_FOR_ROBBERY.." benötigt).",initiator,255,100,0);if isElement(tempC4Object)then destroyElement(tempC4Object);tempC4Object=nil;end;c4Tuer_IsOpen=false;if not isElement(c4Tuer_Marker)and crowbarTuer_IsOpen then c4Tuer_Marker=createMarker(MARKER_C4_TUER_POS.x,MARKER_C4_TUER_POS.y,MARKER_C4_TUER_POS.z-1,"cylinder",1.2,255,100,0,180);setElementInterior(c4Tuer_Marker,CASINO_INTERIOR_ID);setElementDimension(c4Tuer_Marker,CASINO_INTERIOR_DIMENSION);setElementData(c4Tuer_Marker,"casinoAction","c4TuerSprengen");addEventHandler("onMarkerHit",c4Tuer_Marker,handleCasinoActionMarkerHit)end;return end
    if isTimer(casinoRobberyStallTimer)then killTimer(casinoRobberyStallTimer);casinoRobberyStallTimer=nil;end
    casinoRobberyActive=true;casinoCooldownActive=false;casinoRobberyEndTime=getTickCount()+CASINO_ROBBERY_TIMER_DURATION
    setPlayerWantedLevel(initiator,(getElementData(initiator,"wanted")or 0)+25)
    casinoRobberyParticipants={};local initiatorAccID=getCasinoPlayerAccountID(initiator);if initiatorAccID then casinoRobberyParticipants[initiatorAccID]=true end
    for _,player in ipairs(getElementsByType("player"))do if isElement(player)and getElementData(player,"account_id")then if getElementInterior(player)==CASINO_INTERIOR_ID and getElementDimension(player)==CASINO_INTERIOR_DIMENSION then local pAccID=getCasinoPlayerAccountID(player);if pAccID and isCasinoPlayerEligibleForReward(player)then casinoRobberyParticipants[pAccID]=true end;triggerClientEvent(player,"casinorob:startRobberyTimer",player,CASINO_ROBBERY_TIMER_DURATION);if player~=initiator and isCasinoPlayerInEvilFaction(player)then outputChatBox("Casinoraub begonnen!",player,255,165,0);setPlayerWantedLevel(player,(getElementData(player,"wanted")or 0)+15)end;triggerClientEvent(player,"casinorob:playAlarmSound",resourceRoot,true);setElementData(player,"isPlayingCasinoAlarm",true)end;local fid,_=getPlayerFractionAndRank(player);if fid==1 or fid==2 then outputChatBox("[ALARM] Einbruch im "..CASINO_NAME_FOR_BLIP.."!",player,255,50,50);triggerClientEvent(player,"casinorob:startPoliceNotification",player,CASINO_EINGANGS_MARKER_POS.x,CASINO_EINGANGS_MARKER_POS.y,CASINO_EINGANGS_MARKER_POS.z,CASINO_NAME_FOR_BLIP);casinoPoliceNotificationActive=true end end end
    if not isTimer(casinoRobberyInfoUpdateTimer)then casinoRobberyInfoUpdateTimer=setTimer(sendCasinoRobberyInfoToClients,3000,0)end;sendCasinoRobberyInfoToClients()
    if isTimer(casinoMainRobberyTimer)then killTimer(casinoMainRobberyTimer)end;casinoMainRobberyTimer=setTimer(resetCasinoRobberyState,CASINO_ROBBERY_TIMER_DURATION,1,true)
    outputChatBox("Casinoraub gestartet! Tresortür offen! Zeit: "..(CASINO_ROBBERY_TIMER_DURATION/1000/60).." Min.",initiator,255,165,0)
end

function resetCasinoRobberyState(completedSuccessfully)
    local wasActive=casinoRobberyActive;casinoRobberyActive=false;casinoCooldownActive=true;casinoCooldownEndTime=getTickCount()+CASINO_COOLDOWN_DURATION
    if isTimer(casinoRobberyInfoUpdateTimer)then killTimer(casinoRobberyInfoUpdateTimer);casinoRobberyInfoUpdateTimer=nil end
    if isTimer(casinoMainRobberyTimer)then killTimer(casinoMainRobberyTimer);casinoMainRobberyTimer=nil end
    if isTimer(casinoRobberyStallTimer)then killTimer(casinoRobberyStallTimer);casinoRobberyStallTimer=nil;end
    if isElement(tempC4Object)then destroyElement(tempC4Object);tempC4Object=nil;outputDebugString("[CasinoRob] Sichtbares C4 entfernt.")end
    for _,playerInCasino in ipairs(getElementsByType("player"))do if isElement(playerInCasino)and getElementData(playerInCasino,"isPlayingCasinoAlarm")then triggerClientEvent(playerInCasino,"casinorob:playAlarmSound",resourceRoot,false);setElementData(playerInCasino,"isPlayingCasinoAlarm",false)end end
    local message="";local soundId=16;if wasActive then message=completedSuccessfully and"Casinoraub erfolgreich!"or"Casinoraub fehlgeschlagen!";if completedSuccessfully then soundId=15 end else message="Casinoraubversuch abgebrochen."end
    local eligibleWinners={};if completedSuccessfully and wasActive then for accId,_ in pairs(casinoRobberyParticipants)do local p=getCasinoPlayerFromAccountID(accId);if isElement(p)and getElementInterior(p)==CASINO_INTERIOR_ID and getElementDimension(p)==CASINO_INTERIOR_DIMENSION and isCasinoPlayerEligibleForReward(p)then table.insert(eligibleWinners,p)end end
        if #eligibleWinners>0 then local totalRewardPool=getCasinoCurrentTotalRewardAmount();outputChatBox("Gesamtbeute: $"..formatWithThousandSep(totalRewardPool).." (Bonus: "..string.format("%.0f",casinoCurrentRewardBonusFactor*100).."%)",root,0,200,50);local moneyPerPlayer=math.floor(totalRewardPool/#eligibleWinners)
            for _,winner in ipairs(eligibleWinners)do if isElement(winner)and moneyPerPlayer>0 then givePlayerMoney(winner,moneyPerPlayer);outputChatBox(string.format("Dein Anteil: $%s",formatWithThousandSep(moneyPerPlayer)),winner,0,220,80)end end
            casinoLastSuccessfulRobEndTime=getTickCount();notifyCasinoParticipants(message,0,200,50,soundId)
            if math.random(1,100)<=5 then local randomWinnerIndex=math.random(1,#eligibleWinners);local luckyPlayer=eligibleWinners[randomWinnerIndex];if isElement(luckyPlayer)then local itemGiven,itemMsg=exports.tarox:givePlayerItem(luckyPlayer,ITEM_ID_GOLDEN_CHIP,1);if itemGiven then outputChatBox("Zusätzlich zur Beute hast du einen Golden Chip erhalten!",luckyPlayer,255,215,0)else outputChatBox("Zusatz-Item (Golden Chip) konnte nicht gegeben werden: "..(itemMsg or ""), luckyPlayer,255,100,0)end end end
            for _,winner_item in ipairs(eligibleWinners)do if isElement(winner_item)then local randSilber=math.random(1,100);local silberAmount=0;if randSilber<=10 then silberAmount=3 elseif randSilber<=30 then silberAmount=2 elseif randSilber<=65 then silberAmount=1 end;if silberAmount>0 then local itemGivenS,itemMsgS=exports.tarox:givePlayerItem(winner_item,ITEM_ID_SILBERBARREN,silberAmount);if itemGivenS then outputChatBox(string.format("Du hast zusätzlich %dx Silberbarren erhalten!",silberAmount),winner_item,192,192,192)else outputChatBox("Zusatz-Item (Silber) konnte nicht gegeben werden: "..(itemMsgS or ""), winner_item,255,100,0)end end;local randGold=math.random(1,100);local goldAmount=0;if randGold<=2 then goldAmount=3 elseif randGold<=7 then goldAmount=2 elseif randGold<=17 then goldAmount=1 end;if goldAmount>0 then local itemGivenG,itemMsgG=exports.tarox:givePlayerItem(winner_item,ITEM_ID_GOLDBARREN,goldAmount);if itemGivenG then outputChatBox(string.format("Du hast zusätzlich %dx Goldbarren erhalten!",goldAmount),winner_item,255,215,0)else outputChatBox("Zusatz-Item (Gold) konnte nicht gegeben werden: "..(itemMsgG or ""), winner_item,255,100,0)end end end end
        else notifyCasinoParticipants(message.." Keine Teilnehmer für Belohnung.",255,165,0,soundId)end
    else notifyCasinoParticipants(message,255,165,0,soundId)end
    triggerClientEvent(root,"casinorob:stopRobberyTimer",root);triggerClientEvent(root,"casinorob:cooldownUpdate",root,CASINO_COOLDOWN_DURATION);sendCurrentCasinoRewardToClients()
    if casinoPoliceNotificationActive then triggerClientEvent(root,"casinorob:stopPoliceNotification",root,CASINO_NAME_FOR_BLIP);casinoPoliceNotificationActive=false end
    casinoRobberyParticipants={};local closeDelayPrep=(completedSuccessfully and wasActive)and CASINO_FINAL_DOOR_OPEN_DURATION or 1000;local closeDelayC4=(completedSuccessfully and wasActive)and CASINO_FINAL_DOOR_OPEN_DURATION or 1000
    if isTimer(laptopTuer_CloseTimer)then killTimer(laptopTuer_CloseTimer)end;laptopTuer_CloseTimer=setTimer(resetLaptopTuerState,closeDelayPrep,1,true)
    if isTimer(crowbarTuer_CloseTimer)then killTimer(crowbarTuer_CloseTimer)end;crowbarTuer_CloseTimer=setTimer(resetCrowbarTuerState,closeDelayPrep,1,true)
    if isTimer(c4Tuer_CloseTimer)then killTimer(c4Tuer_CloseTimer)end;c4Tuer_CloseTimer=setTimer(resetC4TuerState,closeDelayC4,1)
    setTimer(createCasinoMarkers,CASINO_COOLDOWN_DURATION+1000,1);outputChatBox("Casino-Raubsequenz beendet. Cooldown: "..(CASINO_COOLDOWN_DURATION/1000/60).." Min.",root,255,100,0)
end

-- ////////////////////////////////////////////////////////////////////
-- // SYNCHRONISATION BEI RECONNECT & RESOURCE START/STOP
-- ////////////////////////////////////////////////////////////////////
addEventHandler("onPlayerLoginSuccess", root, function()
    local p=source;local pAccID=getCasinoPlayerAccountID(p);if not pAccID then return end
    setTimer(function(loggedInPlayer,accID)if not isElement(loggedInPlayer)then return end;if casinoRobberyActive and casinoRobberyParticipants[accID]then local rT=casinoRobberyEndTime-getTickCount();if rT>0 then triggerClientEvent(loggedInPlayer,"casinorob:startRobberyTimer",loggedInPlayer,rT);if getElementInterior(loggedInPlayer)==CASINO_INTERIOR_ID and getElementDimension(loggedInPlayer)==CASINO_INTERIOR_DIMENSION then triggerClientEvent(loggedInPlayer,"casinorob:playAlarmSound",resourceRoot,true);setElementData(loggedInPlayer,"isPlayingCasinoAlarm",true)end;if getElementInterior(loggedInPlayer)~=CASINO_INTERIOR_ID or getElementDimension(loggedInPlayer)~=CASINO_INTERIOR_DIMENSION then fadeCamera(loggedInPlayer,false,0.5);setTimer(function(pl)if isElement(pl)then setElementInterior(pl,CASINO_INTERIOR_ID);setElementDimension(pl,CASINO_INTERIOR_DIMENSION);setElementPosition(pl,CASINO_INTERIOR_SPAWN_POS.x,CASINO_INTERIOR_SPAWN_POS.y,CASINO_INTERIOR_SPAWN_POS.z);fadeCamera(pl,true,0.5)end end,500,1,loggedInPlayer)end;outputChatBox("Nimmst wieder am Casinoraub teil!",loggedInPlayer,255,165,0)else triggerClientEvent(loggedInPlayer,"casinorob:stopRobberyTimer",loggedInPlayer);triggerClientEvent(loggedInPlayer,"casinorob:playAlarmSound",resourceRoot,false);setElementData(loggedInPlayer,"isPlayingCasinoAlarm",false)end elseif casinoCooldownActive then local rCD=casinoCooldownEndTime-getTickCount();if rCD>0 then triggerClientEvent(loggedInPlayer,"casinorob:cooldownUpdate",loggedInPlayer,rCD)end end;sendCasinoRobberyInfoToClients();sendCurrentCasinoRewardToClients()end,1500,1,p,pAccID)
end)

addEventHandler("onResourceStart",resourceRoot,function()
    if not getPlayerFractionAndRank or not exports.tarox or not exports.tarox.givePlayerItem or not exports.tarox.takePlayerItemByID or not exports.tarox.hasPlayerItem or not exports.tarox.getItemDefinition then
        outputDebugString("[CasinoRob ERROR] Wichtige Exporte (getPlayerFractionAndRank, Item-API) fehlen! CasinoRaub-System wird möglicherweise nicht korrekt funktionieren.")
        -- return -- Optional: Ressource stoppen, wenn kritische Exporte fehlen
    end
    createCasinoObjects(); createCasinoMarkers()
    if isTimer(casinoRewardUpdateDisplayTimer) then killTimer(casinoRewardUpdateDisplayTimer) end
    casinoRewardUpdateDisplayTimer = setTimer(sendCurrentCasinoRewardToClients, CASINO_REWARD_INCREASE_INTERVAL, 0) -- Regelmäßiges Update für den Reward-Display
    --outputDebugString("[CasinoRob] CasinoRaub System (V4.2.1 - DB Fehlerbehandlung) gestartet.")
end)

addEventHandler("onResourceStop",resourceRoot,function()
    clearCasinoPlayerActionTimers()
    if isTimer(laptopTuer_CloseTimer)then killTimer(laptopTuer_CloseTimer);laptopTuer_CloseTimer=nil end
    if isTimer(crowbarTuer_CloseTimer)then killTimer(crowbarTuer_CloseTimer);crowbarTuer_CloseTimer=nil end
    if isTimer(c4Tuer_CloseTimer)then killTimer(c4Tuer_CloseTimer);c4Tuer_CloseTimer=nil end
    if isTimer(casinoRobberyInfoUpdateTimer)then killTimer(casinoRobberyInfoUpdateTimer);casinoRobberyInfoUpdateTimer=nil end
    if isTimer(casinoMainRobberyTimer)then killTimer(casinoMainRobberyTimer);casinoMainRobberyTimer=nil end
    if isTimer(casinoRobberyStallTimer)then killTimer(casinoRobberyStallTimer);casinoRobberyStallTimer=nil end
    if isTimer(casinoRewardUpdateDisplayTimer)then killTimer(casinoRewardUpdateDisplayTimer);casinoRewardUpdateDisplayTimer=nil end
    if isElement(tempC4Object)then destroyElement(tempC4Object);tempC4Object=nil end
    if isElement(casinoEingangsMarkerElement)then destroyElement(casinoEingangsMarkerElement);casinoEingangsMarkerElement=nil end
    if isElement(casinoAusgangsMarkerElement)then destroyElement(casinoAusgangsMarkerElement);casinoAusgangsMarkerElement=nil end
    if isElement(laptopTuer_Marker)then destroyElement(laptopTuer_Marker);laptopTuer_Marker=nil end
    if isElement(crowbarTuer_Marker)then destroyElement(crowbarTuer_Marker);crowbarTuer_Marker=nil end
    if isElement(c4Tuer_Marker)then destroyElement(c4Tuer_Marker);c4Tuer_Marker=nil end
    if isElement(casinoRewardInfoMarker)then destroyElement(casinoRewardInfoMarker);casinoRewardInfoMarker=nil end
    if isElement(laptopTuer_Object)then destroyElement(laptopTuer_Object);laptopTuer_Object=nil end
    if isElement(crowbarTuer_Object)then destroyElement(crowbarTuer_Object);crowbarTuer_Object=nil end
    if isElement(c4Tuer_Object)then destroyElement(c4Tuer_Object);c4Tuer_Object=nil end
    for _,playerInGame in ipairs(getElementsByType("player"))do if getElementData(playerInGame,"isPlayingCasinoAlarm")then triggerClientEvent(playerInGame,"casinorob:playAlarmSound",resourceRoot,false);setElementData(playerInGame,"isPlayingCasinoAlarm",false)end end
    --outputDebugString("[CasinoRob] System gestoppt.")
end)

addEventHandler("onPlayerQuit",root,function()
    local pAccID=getCasinoPlayerAccountID(source)
    if source==casinoCurrentActionPlayer then cancelCasinoPlayerAction("Spieler hat Spiel verlassen.",nil)end
    if casinoRobberyActive and pAccID and casinoRobberyParticipants[pAccID]then casinoRobberyParticipants[pAccID]=nil;sendCasinoRobberyInfoToClients()end
    if getElementData(source,"isPlayingCasinoAlarm")then setElementData(source,"isPlayingCasinoAlarm",false)end
end)