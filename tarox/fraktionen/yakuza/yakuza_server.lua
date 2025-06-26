-- tarox/fraktionen/yakuza/yakuza_server.lua
-- Nutzt die zentrale Spawn-Prüfungsfunktion aus fractions_server.lua
-- ANGEPASST V1.1: Verbesserte Fehlerbehandlung
-- ANGEPASST V1.2: Waffengeben aus onPlayerLoginSuccess entfernt

local FRACTION_ID = 6
local fractionName = "Yakuza"
local yakuzaSpawn = { x = -2178.63281, y = 702.67426, z = 53.89062, rot = 0 }
local yakuzaSkins = { [1]=186, [2]=187, [3]=227, [4]=228, [5]=294 } -- Skins für Yakuza
local yakuzaTeleporters = {
    { outsideX = -2173.5, outsideY = 682.2, outsideZ = 55.16410,  outsideInt = 0, outsideDim = 0, insideX  = 140.19109, insideY  = 1369.02148, insideZ  = 1083.86377, insideInt= 5, insideDim= 0, markerSize = 1.5, markerColor = {255, 0, 0, 150} },
    { outsideX = -2169.9, outsideY = 685.7, outsideZ = 89.9, outsideInt = 0, outsideDim = 0, insideX  = 140.2, insideY  = 1381.2, insideZ  = 1088.3, insideInt= 5, insideDim= 0, markerSize = 1.5, markerColor = {255, 0, 0, 150} },
}
local yakuzaVehiclesConfig = {
    { model = 468, x = -2179.4, y = 636.1, z = 49.2, rot = 0,   minRank = 1 },
    { model = 405, x = -2188.1, y = 636.9, z = 49.4, rot = 0,   minRank = 1 },
    { model = 579, x = -2201.8, y = 637.0, z = 49.5, rot = 0,   minRank = 3 },
}
local yakuzaVehicles = {}
local despawnTimers = {}

addEventHandler("onResourceStart", resourceRoot, function()
    local db_check = exports.datenbank:getConnection()
    if not db_check then
        outputDebugString("[Yakuza] WARNUNG bei onResourceStart: Keine DB-Verbindung!", 1)
    end

    for _, data in ipairs(yakuzaVehiclesConfig) do
        local veh = createVehicle(data.model, data.x, data.y, data.z, 0, 0, data.rot)
        if veh then
            setElementData(veh, "yakuzaVehicle", true)
            setElementData(veh, "minRank", data.minRank or 1)
            setVehicleColor(veh, 255, 0, 0)
            yakuzaVehicles[veh] = { model = data.model, x = data.x, y = data.y, z = data.z, rot = data.rot, minRank = data.minRank or 1 }
        else
            outputDebugString("[Yakuza] FEHLER: Fahrzeug Model " .. data.model .. " konnte nicht erstellt werden!", 2)
        end
    end

    for i, tpData in ipairs(yakuzaTeleporters) do
        local markerOut = createMarker(tpData.outsideX, tpData.outsideY, tpData.outsideZ - 1, "cylinder", tpData.markerSize or 1.5, tpData.markerColor[1], tpData.markerColor[2], tpData.markerColor[3], tpData.markerColor[4])
        if isElement(markerOut) then
            setElementInterior(markerOut, tpData.outsideInt); setElementDimension(markerOut, tpData.outsideDim)
            setElementData(markerOut, "teleporterData", {  targetX = tpData.insideX, targetY = tpData.insideY, targetZ = tpData.insideZ, targetInt = tpData.insideInt, targetDim = tpData.insideDim })
            addEventHandler("onMarkerHit", markerOut, function(hitPlayer, matchingDimension) if matchingDimension and getElementType(hitPlayer)=="player" and not isPedInVehicle(hitPlayer) then handleYakuzaTeleporterHit(hitPlayer, source) end end)
        else
            outputDebugString("[Yakuza] FEHLER: Teleporter-Marker (Außen) "..i.." konnte nicht erstellt werden!", 2)
        end

        local markerIn = createMarker(tpData.insideX, tpData.insideY, tpData.insideZ - 1, "cylinder", tpData.markerSize or 1.5, tpData.markerColor[1], tpData.markerColor[2], tpData.markerColor[3], tpData.markerColor[4])
        if isElement(markerIn) then
            setElementInterior(markerIn, tpData.insideInt); setElementDimension(markerIn, tpData.insideDim)
            setElementData(markerIn, "teleporterData", { targetX = tpData.outsideX, targetY = tpData.outsideY, targetZ = tpData.outsideZ, targetInt = tpData.outsideInt, targetDim = tpData.outsideDim })
            addEventHandler("onMarkerHit", markerIn, function(hitPlayer, matchingDimension) if matchingDimension and getElementType(hitPlayer)=="player" and not isPedInVehicle(hitPlayer) then handleYakuzaTeleporterHit(hitPlayer, source) end end)
        else
            outputDebugString("[Yakuza] FEHLER: Teleporter-Marker (Innen) "..i.." konnte nicht erstellt werden!", 2)
        end
    end
    --outputDebugString("[Yakuza] Yakuza Script (Server V1.2 - Waffenlogik in onLoginSuccess entfernt) geladen.")
end)

function handleYakuzaTeleporterHit(hitPlayer, marker)
    local fid, rank = _G.getPlayerFractionAndRank and _G.getPlayerFractionAndRank(hitPlayer) or getPlayerFractionAndRank(hitPlayer)
    if fid ~= FRACTION_ID then
        outputChatBox("[Yakuza] Only for Yakuza!", hitPlayer, 255, 0, 0)
        return
    end
    if getElementData(hitPlayer, "isTeleporting") then return end
    local data = getElementData(marker, "teleporterData")
    if not data then return end
    setElementData(hitPlayer, "isTeleporting", true)
    fadeCamera(hitPlayer, false, 1)
    setTimer(function()
        if isElement(hitPlayer) then
            setElementInterior(hitPlayer, data.targetInt or 0)
            setElementDimension(hitPlayer, data.targetDim or 0)
            setElementPosition(hitPlayer, data.targetX, data.targetY, (data.targetZ or 0)+1)
            fadeCamera(hitPlayer, true, 1)
            setTimer(function() if isElement(hitPlayer) then setElementData(hitPlayer, "isTeleporting", false) end end, 2000, 1)
        end
    end, 1000, 1)
end

-- NEUER, ROBUSTER CODE für Yakuza
addEventHandler("onVehicleStartEnter", root, function(player, seat)
    if seat == 0 and getElementData(source, "yakuzaVehicle") then
        -- Hole Fraktion und Rang des Spielers
        local fid, rank = getPlayerFractionAndRank(player)

        -- Prüfe, ob der Spieler überhaupt in der Yakuza ist
        if fid ~= FRACTION_ID then
            cancelEvent()
            outputChatBox("[Yakuza] Only for Yakuza!", player, 255, 0, 0)
            return
        end

        -- Hole den minimal benötigten Rang aus den Fahrzeugdaten
        local minRankNeeded = getElementData(source, "minRank") or 5

        -- Sichere Überprüfung, um den "nil with number" Fehler zu verhindern
        local playerRankNum = tonumber(rank)
        local minRankNum = tonumber(minRankNeeded)

        if type(playerRankNum) ~= "number" or type(minRankNum) ~= "number" then
            outputDebugString("[Yakuza] FEHLER: Ungültige Rang-Daten für Vergleich. Spieler-Rang: "..tostring(rank)..", Min. Rang: "..tostring(minRankNeeded))
            cancelEvent() -- Sicherheitshalber abbrechen
            return
        end

        -- Jetzt der eigentliche Vergleich mit den sicheren Zahlenwerten
        if playerRankNum < minRankNum then
            outputChatBox("[Yakuza] Your Rank ("..playerRankNum..") is not high enough (min. Rank " .. minRankNum .. ")!", player, 255, 100, 0)
            cancelEvent()
            return
        end
    end
end)

addEventHandler("onVehicleExit", root, function(player)
    if getElementData(source, "yakuzaVehicle") then
        local vehicle = source
        if despawnTimers[vehicle] then killTimer(despawnTimers[vehicle]); despawnTimers[vehicle] = nil; end
        outputChatBox("[Yakuza] You have exited the vehicle. It will despawn in 10 minutes unless you re-enter!", player, 255,165,0)
        despawnTimers[vehicle] = setTimer(function(veh)
            if isElement(veh) and not getVehicleOccupant(veh) then
                respawnYakuzaVehicle(veh)
            end
        end, 600000, 1, vehicle)
    end
end)

addEventHandler("onVehicleEnter", root, function(player, seat)
    if seat == 0 and getElementData(source, "yakuzaVehicle") then
        local vehicle = source
        if despawnTimers[vehicle] then
            killTimer(despawnTimers[vehicle])
            despawnTimers[vehicle] = nil
            outputChatBox("[Yakuza] The despawn timer has been canceled because you re-entered!", player, 0,255,0)
        end
    end
end)

addEventHandler("onVehicleExplode", root, function()
    if not isElement(source) then return end
    if getElementData(source, "yakuzaVehicle") then
        setTimer(respawnYakuzaVehicle, 5000, 1, source)
    end
end)

function respawnYakuzaVehicle(vehicle)
    if not isElement(vehicle) or not yakuzaVehicles[vehicle] then return end
    local spawnData = yakuzaVehicles[vehicle]
    local originalMinRank = spawnData.minRank
    destroyElement(vehicle)
    local newVehicle = createVehicle(spawnData.model, spawnData.x, spawnData.y, spawnData.z, 0, 0, spawnData.rot)
    if not isElement(newVehicle) then
        outputDebugString("[Yakuza] createVehicle failed, model="..tostring(spawnData.model), 1)
        return
    end
    setElementData(newVehicle, "yakuzaVehicle", true)
    setElementData(newVehicle, "minRank", originalMinRank)
    setVehicleColor(newVehicle, 255, 0, 0)
    yakuzaVehicles[newVehicle] = spawnData
end

-- tarox/fraktionen/yakuza/yakuza_server.lua

-- ERSETZE die alte Funktion mit dieser:
local function giveYakuzaWeapons(player, rank)
    -- Die Funktion überprüft jetzt nur noch, ob ein gültiger Rang übergeben wurde.
    if not rank or rank < 1 then return end

    takeAllWeapons(player)
    local meleeWeapon = 8
    if rank == 1 then 
        giveWeapon(player, 22, 30)
        giveWeapon(player, meleeWeapon, 1)
    elseif rank == 2 then 
        giveWeapon(player, 24, 14)
        giveWeapon(player, meleeWeapon, 1)
        giveWeapon(player, 25, 15)
    elseif rank == 3 then 
        giveWeapon(player, 24, 21)
        giveWeapon(player, meleeWeapon, 1)
        giveWeapon(player, 25, 20)
        giveWeapon(player, 28, 60)
    elseif rank == 4 then 
        giveWeapon(player, 24, 28)
        giveWeapon(player, meleeWeapon, 1)
        giveWeapon(player, 25, 25)
        giveWeapon(player, 28, 90)
        giveWeapon(player, 30, 30)
        giveWeapon(player, 16, 1)
    elseif rank == 5 then 
        giveWeapon(player, 24, 35)
        giveWeapon(player, meleeWeapon, 1)
        giveWeapon(player, 25, 30)
        giveWeapon(player, 28, 120)
        giveWeapon(player, 30, 60)
        giveWeapon(player, 16, 2)
        giveWeapon(player, 34, 7)
    end
end

addCommandHandler("yakuza", function(player)
    local fid, lvl = _G.getPlayerFractionAndRank and _G.getPlayerFractionAndRank(player) or getPlayerFractionAndRank(player)
    if fid ~= FRACTION_ID then
        outputChatBox("[Yakuza] You are not a Yakuza!", player,255,0,0)
        return
    end
    triggerClientEvent(player, "openYakuzaWindow", player)
end)

-- tarox/fraktionen/yakuza/yakuza_server.lua

-- ERSETZE den alten Event-Handler mit diesem:
addEvent("onYakuzaRequestSpawn", true)
addEventHandler("onYakuzaRequestSpawn", root, function()
    local player = source
    local canSpawn, reason = _G.canPlayerUseFactionSpawnCommand and _G.canPlayerUseFactionSpawnCommand(player) or canPlayerUseFactionSpawnCommand(player)
    if not canSpawn then
        outputChatBox(reason or "Spawn nicht möglich.", player, 255, 100, 0)
        return
    end

    local fid, rank = getPlayerFractionAndRank(player)
    -- Diese Zeile wird hier auch hinzugefügt, um Fehler zu vermeiden.
    rank = rank or 0

    if fid ~= FRACTION_ID then
        outputChatBox("[Yakuza] You are not a Yakuza!", source, 255, 0, 0)
        return
    end
    local skinID = yakuzaSkins[rank] or yakuzaSkins[1]
    spawnPlayer(source, yakuzaSpawn.x, yakuzaSpawn.y, yakuzaSpawn.z, yakuzaSpawn.rot, skinID)
    fadeCamera(source, true)
    setCameraTarget(source, source)
    
    -- HIER IST DIE WICHTIGE ÄNDERUNG im Aufruf:
    giveYakuzaWeapons(source, rank)
    
    outputChatBox("[Yakuza] You spawned as Yakuza (Rank "..rank..")", source, 0, 255, 0)
end)

addEvent("onYakuzaRequestLeave", true)
addEventHandler("onYakuzaRequestLeave", root, function()
    local player = source
    local fid, rank = _G.getPlayerFractionAndRank and _G.getPlayerFractionAndRank(player) or getPlayerFractionAndRank(player)
    if fid ~= FRACTION_ID then
        outputChatBox("[Yakuza] You are not a Yakuza", source, 255, 0, 0)
        return
    end
    local accID = getElementData(source, "account_id")
    if not accID then
        outputChatBox("[Yakuza] account_id nicht gefunden!", source, 255,0,0)
        return
    end

    local deleteSuccess, errMsg = exports.datenbank:executeDatabase("DELETE FROM fraction_members WHERE account_id=? AND fraction_id=?", accID, FRACTION_ID)
    if not deleteSuccess then
        outputChatBox("[Yakuza] Fehler beim Verlassen der Fraktion (Datenbankfehler): " .. (errMsg or "Unbekannt"), source, 255,0,0)
        outputDebugString("[Yakuza] FEHLER: DB DELETE für AccID " .. accID .. " fehlgeschlagen: " .. (errMsg or "Unbekannt"), 2)
        return
    end

    if type(_G.refreshPlayerFractionData) == "function" then
        _G.refreshPlayerFractionData(source)
    else
        outputDebugString("[Yakuza] WARNUNG: _G.refreshPlayerFractionData nicht gefunden nach Fraktionsaustritt.")
    end

    takeAllWeapons(source)
    local standardSkinResult, skinErrMsg = exports.datenbank:queryDatabase("SELECT standard_skin FROM account WHERE id=? LIMIT 1", accID)
    local standardSkin = (_G.DEFAULT_CIVIL_SKIN or 0)
    if not standardSkinResult then
        outputDebugString("[Yakuza] DB Fehler beim Laden des Standard-Skins (Leave) für AccID " .. accID .. ": " .. (skinErrMsg or "Unbekannt"))
    elseif standardSkinResult and standardSkinResult[1] and tonumber(standardSkinResult[1].standard_skin) then
        standardSkin = tonumber(standardSkinResult[1].standard_skin)
    end

    setElementModel(source, standardSkin)
    outputChatBox("[Yakuza] You got removed from the Yakuza", source, 255,200,0)
end)

addEventHandler("onPlayerLoginSuccess", root, function()
    local player = source
    local accID = getElementData(player, "account_id")
    if not accID then return end

    local fid, rank = getPlayerFractionAndRank(player)
    if fid == FRACTION_ID then
        local skinID = yakuzaSkins[rank] or yakuzaSkins[1]
        if getElementModel(player) ~= skinID then
            -- setElementModel(player, skinID) -- Wird von login_server.lua's loadAndSetPlayerSkin gehandhabt
        end
        --outputDebugString("[Yakuza] onPlayerLoginSuccess: Daten für Yakuza Mitglied "..getPlayerName(player).." verarbeitet.")
    end
end)

addEventHandler("onResourceStop", resourceRoot, function()
    outputDebugString("[Yakuza] Yakuza Script (Server V1.2) gestoppt.")
end)