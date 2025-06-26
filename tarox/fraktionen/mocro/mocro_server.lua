-- tarox/fraktionen/mocro/mocro_server.lua
-- Nutzt die zentrale Spawn-Prüfungsfunktion aus fractions_server.lua
-- ANGEPASST V1.1: Verbesserte Fehlerbehandlung
-- ANGEPASST V1.2: Waffengeben aus onPlayerLoginSuccess entfernt

local FRACTION_ID  = 5
local fractionName = "Mocro Mafia"
local MOCO_VEHICLE_COLOR = {128, 0, 128}
local mocroSpawn = { x = -2459.23438, y = -139.27902, z = 25.91920, rot = 0 }
local mocroSkins = { [1]=296, [2]=296, [3]=296, [4]=296, [5]=296 } -- Skins für Mocro Mafia
local mocroGatesConfig = {
    { index = 1, model = 980, closedPos = {x=-2490, y=-129.19999, z=27.39999, rx=0, ry=0, rz=270}, openPos = {x=-2490, y=-117.69999, z=27.39999, rx=0, ry=0, rz=270}, moveTime = 2000, checkRadius = 7 },
    { index = 2, model = 980, closedPos = {x=-2446.19999, y=-80.80000, z=35.5,      rx=0, ry=0, rz=180}, openPos = {x=-2437, y=-80.80000,  z=35.5,      rx=0, ry=0, rz=180}, moveTime = 2000, checkRadius = 7 },
    { index = 3, model = 980, closedPos = {x=-2431.39990, y=-166.39999, z=37.09999, rx=0, ry=0, rz=89},  openPos = {x=-2431.39990, y=-173,        z=37.09999, rx=0, ry=0, rz=89},  moveTime = 2000, checkRadius = 7 },
}
local mocroGates = {}
local mocroGateCheckTimer = nil
local GATE_CHECK_INTERVAL = 3000
local INTERIOR_ID_MOCRO = 9
local INTERIOR_DIMENSION_MOCRO = 0
local mocroTeleportersConfig = {
    { name = "Haupteingang", posA = { x = -2443.77515, y = -122.669,    z = 26.0,       int = 0, dim = 0 }, posB = { x = 2317.59302,  y = -1026.04333, z = 1050.21777, int = INTERIOR_ID_MOCRO, dim = INTERIOR_DIMENSION_MOCRO }, color = {128, 0, 128, 150} },
    { name = "Nebenausgang", posA = { x = -2450.19995, y = -125.09999, z = 51.79999,   int = 0, dim = 0 }, posB = { x = 2316.94946,  y = -1010.68982, z = 1054.71875,  int = INTERIOR_ID_MOCRO, dim = INTERIOR_DIMENSION_MOCRO }, color = {128, 0, 128, 150} },
}
local mocroTeleporterMarkers = {}
local mocroVehiclesConfig = {
    { model=487, x=-2442.39941, y=-133.09960, z=52.09999, rot=0,   minRank=4 }, { model=487, x=-2442.59960, y=-118,        z=52.09999, rot=0,   minRank=4 },
    { model=402, x=-2473.30004, y=-134,        z=25.60000, rot=90,  minRank=1 }, { model=560, x=-2466.89990, y=-134,        z=25.60000, rot=90,  minRank=1 },
    { model=559, x=-2477.39990, y=-124.30000, z=25.60000, rot=90,  minRank=2 }, { model=475, x=-2471.19995, y=-124.40000, z=25.60000, rot=90,  minRank=3 },
    { model=405, x=-2466.60009, y=-119.69999, z=25.60000, rot=180, minRank=2 }, { model=518, x=-2466.39990, y=-112.30000, z=25.70000, rot=180, minRank=1 },
    { model=489, x=-2447,       y=-87.80000,  z=34.09999, rot=0,   minRank=3 },
}
local mocroVehicles = {}
local despawnTimers = {}

function checkMocroNearGates()
    for index, gateInfo in pairs(mocroGates) do
        if isElement(gateInfo.element) then
            local cfg = gateInfo.config
            local gx, gy, gz = cfg.closedPos.x, cfg.closedPos.y, cfg.closedPos.z
            local radius = cfg.checkRadius or 7
            local isMemberNearby = false
            local dimension = getElementDimension(gateInfo.element)
            local interior = getElementInterior(gateInfo.element)
            local nearbyPlayers = getElementsWithinRange(gx, gy, gz, radius, "player")
            for _, player in ipairs(nearbyPlayers) do
                if getElementDimension(player) == dimension and getElementInterior(player) == interior then
                    local fid, _ = _G.getPlayerFractionAndRank and _G.getPlayerFractionAndRank(player) or getPlayerFractionAndRank(player)
                    if fid == FRACTION_ID then
                        isMemberNearby = true
                        break
                    end
                end
            end
            if isMemberNearby and not gateInfo.isOpen then openMocroGate(index)
            elseif not isMemberNearby and gateInfo.isOpen then closeMocroGate(index)
            end
        end
    end
end

function openMocroGate(index)
    local gateInfo = mocroGates[index]
    if not gateInfo or gateInfo.isOpen or not isElement(gateInfo.element) then return end
    local cfg = gateInfo.config
    moveObject(gateInfo.element, cfg.moveTime, cfg.openPos.x, cfg.openPos.y, cfg.openPos.z, cfg.openPos.rx - cfg.closedPos.rx, cfg.openPos.ry - cfg.closedPos.ry, cfg.openPos.rz - cfg.closedPos.rz)
    gateInfo.isOpen = true
end

function closeMocroGate(index)
    local gateInfo = mocroGates[index]
    if not gateInfo or not gateInfo.isOpen or not isElement(gateInfo.element) then return end
    local cfg = gateInfo.config
    moveObject(gateInfo.element, cfg.moveTime, cfg.closedPos.x, cfg.closedPos.y, cfg.closedPos.z, cfg.closedPos.rx - cfg.openPos.rx, cfg.closedPos.ry - cfg.openPos.ry, cfg.closedPos.rz - cfg.openPos.rz)
    gateInfo.isOpen = false
end

function handleMocroTeleporterHit(hitElement, matchingDimension)
    if getElementType(hitElement) ~= "player" or isPedInVehicle(hitElement) or not matchingDimension then return end
    if not getElementData(hitElement, "account_id") then return end
    local fid, _ = _G.getPlayerFractionAndRank and _G.getPlayerFractionAndRank(hitElement) or getPlayerFractionAndRank(hitElement)
    if fid ~= FRACTION_ID then outputChatBox("Access denied.", hitElement, 255, 0, 0); return end
    if getElementData(hitElement, "isTeleporting") then return end
    local targetData = getElementData(source, "teleporterTarget")
    if not targetData or not targetData.x or not targetData.y or not targetData.z then
        outputDebugString("[MocroMafia] FEHLER: Invalid teleporter target data!", 2)
        outputChatBox("Teleport error.", hitElement, 255, 0, 0)
        return
    end
    setElementData(hitElement, "isTeleporting", true)
    fadeCamera(hitElement, false, 1.0)
    setTimer(function(player, data)
        if isElement(player) then
            setElementPosition(player, data.x, data.y, data.z + 0.1)
            setElementInterior(player, data.int or 0)
            setElementDimension(player, data.dim or 0)
            fadeCamera(player, true, 1.0)
            setTimer(function(p) if isElement(p) then removeElementData(p, "isTeleporting") end end, 1500, 1, player)
        end
    end, 1000, 1, hitElement, targetData)
end

function respawnMocroVehicle(vehicleToRespawn)
    if not isElement(vehicleToRespawn) then return end
    local vehicleConfig = mocroVehicles[vehicleToRespawn]
    if not vehicleConfig then
        if isElement(vehicleToRespawn) then destroyElement(vehicleToRespawn) end
        if despawnTimers[vehicleToRespawn] and isTimer(despawnTimers[vehicleToRespawn]) then killTimer(despawnTimers[vehicleToRespawn]) end
        despawnTimers[vehicleToRespawn] = nil
        mocroVehicles[vehicleToRespawn] = nil
        return
    end
    local originalMinRank = vehicleConfig.minRank or 1
    mocroVehicles[vehicleToRespawn] = nil
    if despawnTimers[vehicleToRespawn] and isTimer(despawnTimers[vehicleToRespawn]) then killTimer(despawnTimers[vehicleToRespawn]) end
    despawnTimers[vehicleToRespawn] = nil
    if isElement(vehicleToRespawn) then destroyElement(vehicleToRespawn) end
    local newVeh = createVehicle(vehicleConfig.model, vehicleConfig.x, vehicleConfig.y, vehicleConfig.z, 0, 0, vehicleConfig.rot)
    if newVeh then
        setElementData(newVeh, "mocroVehicle", true)
        setElementData(newVeh, "minRank", originalMinRank)
        setVehicleColor(newVeh, MOCO_VEHICLE_COLOR[1], MOCO_VEHICLE_COLOR[2], MOCO_VEHICLE_COLOR[3])
        mocroVehicles[newVeh] = vehicleConfig
    else
        outputDebugString("[MocroMafia] FEHLER: Respawn createVehicle failed: Model " .. vehicleConfig.model, 2)
    end
end

-- tarox/fraktionen/mocro/mocro_server.lua

-- ERSETZE die alte Funktion mit dieser:
local function giveMocroWeapons(player, rank)
    -- Die Funktion überprüft jetzt nur noch, ob ein gültiger Rang übergeben wurde.
    if not rank or rank < 1 then return end

    takeAllWeapons(player)
    local meleeWeapon = 4
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
        giveWeapon(player, 32, 60)
    elseif rank == 4 then 
        giveWeapon(player, 24, 28)
        giveWeapon(player, meleeWeapon, 1)
        giveWeapon(player, 25, 25)
        giveWeapon(player, 32, 90)
        giveWeapon(player, 30, 30)
        giveWeapon(player, 16, 1)
    elseif rank == 5 then 
        giveWeapon(player, 24, 35)
        giveWeapon(player, meleeWeapon, 1)
        giveWeapon(player, 25, 30)
        giveWeapon(player, 32, 120)
        giveWeapon(player, 30, 60)
        giveWeapon(player, 16, 2)
        giveWeapon(player, 34, 7)
    end
end

addEventHandler("onResourceStart", resourceRoot, function()
    local db_check = exports.datenbank:getConnection()
    if not db_check then
        outputDebugString("[MocroMafia] WARNUNG bei onResourceStart: Keine DB-Verbindung!", 1)
    end
    for i, cfg in ipairs(mocroGatesConfig) do
        local gate = createObject(cfg.model, cfg.closedPos.x, cfg.closedPos.y, cfg.closedPos.z, cfg.closedPos.rx, cfg.closedPos.ry, cfg.closedPos.rz)
        if isElement(gate) then setObjectBreakable(gate, false); mocroGates[cfg.index] = { element = gate, isOpen = false, config = cfg }; else outputDebugString("[MocroMafia] FEHLER: Gate #"..cfg.index.." konnte nicht erstellt werden!", 2) end
    end
    if #mocroGatesConfig > 0 then if isTimer(mocroGateCheckTimer) then killTimer(mocroGateCheckTimer) end; mocroGateCheckTimer = setTimer(checkMocroNearGates, GATE_CHECK_INTERVAL, 0); end
    local vehicleCount = 0
    for i, data in ipairs(mocroVehiclesConfig) do
        local veh = createVehicle(data.model, data.x, data.y, data.z, 0, 0, data.rot)
        if veh then setElementData(veh, "mocroVehicle", true); setElementData(veh, "minRank", data.minRank or 1); setVehicleColor(veh, MOCO_VEHICLE_COLOR[1], MOCO_VEHICLE_COLOR[2], MOCO_VEHICLE_COLOR[3]); mocroVehicles[veh] = { model = data.model, x = data.x, y = data.y, z = data.z, rot = data.rot, minRank = data.minRank or 1 }; vehicleCount = vehicleCount + 1; else outputDebugString("[MocroMafia] FEHLER: Fahrzeug Model " .. data.model .. " konnte nicht erstellt werden!", 2) end
    end
    local markerCount = 0
    for i, pairData in ipairs(mocroTeleportersConfig) do
        local pairName = pairData.name or "Paar " .. i
        if pairData.posA and pairData.posB and pairData.posA.x and pairData.posB.x and pairData.color then
            local markerA = createMarker(pairData.posA.x, pairData.posA.y, pairData.posA.z - 1, "cylinder", 1.5, unpack(pairData.color)); if isElement(markerA) then setElementInterior(markerA, pairData.posA.int or 0); setElementDimension(markerA, pairData.posA.dim or 0); setElementData(markerA, "teleporterTarget", pairData.posB); addEventHandler("onMarkerHit", markerA, handleMocroTeleporterHit); table.insert(mocroTeleporterMarkers, markerA); markerCount = markerCount + 1; else outputDebugString("[MocroMafia] FEHLER: Marker A für '" .. pairName .. "' konnte nicht erstellt werden!", 2) end
            local markerB = createMarker(pairData.posB.x, pairData.posB.y, pairData.posB.z - 1, "cylinder", 1.5, unpack(pairData.color)); if isElement(markerB) then setElementInterior(markerB, pairData.posB.int or 0); setElementDimension(markerB, pairData.posB.dim or 0); setElementData(markerB, "teleporterTarget", pairData.posA); addEventHandler("onMarkerHit", markerB, handleMocroTeleporterHit); table.insert(mocroTeleporterMarkers, markerB); markerCount = markerCount + 1; else outputDebugString("[MocroMafia] FEHLER: Marker B für '" .. pairName .. "' konnte nicht erstellt werden!", 2) end
        else outputDebugString("[MocroMafia] FEHLER: Ungültige posA/posB Daten für Teleporter " .. pairName, 2) end
    end
    outputDebugString("[MocroMafia] Mocro Mafia Script (Server V1.2 - Waffenlogik in onLoginSuccess entfernt) geladen.")
end)

addEventHandler("onResourceStop", resourceRoot, function()
    if isTimer(mocroGateCheckTimer) then killTimer(mocroGateCheckTimer); mocroGateCheckTimer = nil end
    for _, gateInfo in pairs(mocroGates) do if isElement(gateInfo.element) then destroyElement(gateInfo.element) end end; mocroGates = {}
    for veh, _ in pairs(mocroVehicles) do if isElement(veh) then destroyElement(veh) end end; mocroVehicles = {}
    for _, timer in pairs(despawnTimers) do if isTimer(timer) then killTimer(timer) end end; despawnTimers = {}
    for _, marker in ipairs(mocroTeleporterMarkers) do if isElement(marker) then destroyElement(marker) end end; mocroTeleporterMarkers = {}
    outputDebugString("[MocroMafia] Mocro Mafia Script (Server V1.2) gestoppt.")
end)

-- NEUER, ROBUSTER CODE für Mocro Mafia
addEventHandler("onVehicleStartEnter", root, function(player, seat)
    if seat == 0 and getElementData(source, "mocroVehicle") then
        if not getElementData(player, "account_id") then cancelEvent(); return end

        local fid, rank = getPlayerFractionAndRank(player)

        if fid ~= FRACTION_ID then
            outputChatBox("["..fractionName.."] Nur für Mitglieder!", player, 255, 0, 0)
            cancelEvent()
            return
        end

        local minRankNeeded = getElementData(source, "minRank") or 5

        -- Sichere Überprüfung, um den "nil with number" Fehler zu verhindern
        local playerRankNum = tonumber(rank)
        local minRankNum = tonumber(minRankNeeded)

        if type(playerRankNum) ~= "number" or type(minRankNum) ~= "number" then
            outputDebugString("[Mocro] FEHLER: Ungültige Rang-Daten für Vergleich. Spieler-Rang: "..tostring(rank)..", Min. Rang: "..tostring(minRankNeeded))
            cancelEvent() -- Sicherheitshalber abbrechen, um unberechtigten Zugriff zu verhindern
            return
        end

        -- Jetzt der eigentliche Vergleich mit den sicheren Zahlenwerten
        if playerRankNum < minRankNum then
            outputChatBox("["..fractionName.."] Dein Rang ("..playerRankNum..") ist nicht hoch genug (min. Rang " .. minRankNum .. ").", player, 255, 100, 0)
            cancelEvent()
            return
        end

        -- Despawn-Timer-Logik (bleibt erhalten)
        if despawnTimers[source] and isTimer(despawnTimers[source]) then
            killTimer(despawnTimers[source])
            despawnTimers[source] = nil
            outputChatBox("["..fractionName.."] Despawn-Timer abgebrochen.", player, 0, 255, 150)
        end
    end
end)

addEventHandler("onVehicleExit", root, function(player, seat)
    if seat == 0 and getElementData(source, "mocroVehicle") then
        local vehicleElement = source
        if not despawnTimers[vehicleElement] or not isTimer(despawnTimers[vehicleElement]) then
            local despawnTimeMinutes = 10
            outputChatBox("["..fractionName.."] Fahrzeug despawnt in " .. despawnTimeMinutes .. " Minuten, wenn leer.", player, 255, 165, 0)
            despawnTimers[vehicleElement] = setTimer(respawnMocroVehicle, despawnTimeMinutes * 60 * 1000, 1, vehicleElement)
        end
    end
end)

addEventHandler("onVehicleExplode", root, function()
    if not isElement(source) then return end
    if getElementData(source, "mocroVehicle") then
        setTimer(respawnMocroVehicle, 5000, 1, source)
    end
end)

addCommandHandler("mocro", function(player)
    if not getElementData(player, "account_id") then outputChatBox("Bitte logge dich zuerst ein.", player, 255, 165, 0); return end
    local fid, _ = _G.getPlayerFractionAndRank and _G.getPlayerFractionAndRank(player) or getPlayerFractionAndRank(player)
    if fid ~= FRACTION_ID then outputChatBox("Du bist kein Mitglied der " .. fractionName .. ".", player, 255, 0, 0); return; end
    triggerClientEvent(player, "openMocroWindow", player)
end)

-- tarox/fraktionen/mocro/mocro_server.lua

-- ERSETZE den alten Event-Handler mit diesem:
addEvent("onMocroRequestSpawn", true)
addEventHandler("onMocroRequestSpawn", root, function()
    local player = source
    local canSpawn, reason = _G.canPlayerUseFactionSpawnCommand and _G.canPlayerUseFactionSpawnCommand(player) or canPlayerUseFactionSpawnCommand(player)
    if not canSpawn then
        outputChatBox(reason or "Spawn nicht möglich.", player, 255, 100, 0)
        return
    end

    local fid, rank = getPlayerFractionAndRank(player)
    rank = rank or 0 

    if fid ~= FRACTION_ID then
        outputChatBox("[Mocro] You are not a Mocro!", source, 255, 0, 0)
        return
    end
    local skinID = mocroSkins[rank] or mocroSkins[1]
    spawnPlayer(source, mocroSpawn.x, mocroSpawn.y, mocroSpawn.z, mocroSpawn.rot, skinID)
    fadeCamera(source, true)
    setCameraTarget(source, source)
    
    -- HIER IST DIE WICHTIGE ÄNDERUNG im Aufruf:
    giveMocroWeapons(source, rank)

    outputChatBox("["..fractionName.."] Du wurdest als "..fractionName.." (Rank " .. rank .. ") gespawnt!", player, MOCO_VEHICLE_COLOR[1], MOCO_VEHICLE_COLOR[2], MOCO_VEHICLE_COLOR[3])
end)

addEvent("onMocroRequestLeave", true)
addEventHandler("onMocroRequestLeave", root, function()
    local player = source
    local accID = getElementData(player, "account_id")
    if not accID then return end
    local fid, _ = _G.getPlayerFractionAndRank and _G.getPlayerFractionAndRank(player) or getPlayerFractionAndRank(player)
    if fid ~= FRACTION_ID then outputChatBox("You are not a member.", player, 255, 0, 0); return end

    local success, errMsg = exports.datenbank:executeDatabase("DELETE FROM fraction_members WHERE account_id=? AND fraction_id=?", accID, FRACTION_ID)
    if success then
        if type(_G.refreshPlayerFractionData) == "function" then _G.refreshPlayerFractionData(player)
        else outputDebugString("[MocroMafia] WARNUNG: _G.refreshPlayerFractionData nicht gefunden nach Fraktionsaustritt.") end

        takeAllWeapons(player)
        local standardSkinResult, skinErrMsg = exports.datenbank:queryDatabase("SELECT standard_skin FROM account WHERE id=? LIMIT 1", accID)
        local standardSkin = (_G.DEFAULT_CIVIL_SKIN or 0)
        if not standardSkinResult then
            outputDebugString("[MocroMafia] DB Fehler beim Laden des Standard-Skins (Leave) für AccID " .. accID .. ": " .. (skinErrMsg or "Unbekannt"))
        elseif standardSkinResult and standardSkinResult[1] and tonumber(standardSkinResult[1].standard_skin) then
            standardSkin = tonumber(standardSkinResult[1].standard_skin)
        end
        setElementModel(player, standardSkin)
        outputChatBox("Du hast die " .. fractionName .. " verlassen.", player, 255, 165, 0)
        spawnPlayer(player, 0, 0, 5, 0, standardSkin)
        fadeCamera(player, true)
        setCameraTarget(player, player)
    else
        outputChatBox("Error leaving fraction: " .. (errMsg or "Database Error"), player, 255, 0, 0)
        outputDebugString("[MocroMafia] FEHLER: DB DELETE für AccID " .. accID .. " fehlgeschlagen: " .. (errMsg or "Unbekannt"), 2)
    end
end)

addEventHandler("onPlayerLoginSuccess", root, function()
    local player = source
    local accID = getElementData(player, "account_id")
    if not accID then return end

    local fid, rank = getPlayerFractionAndRank(player)
    if fid == FRACTION_ID then
        local skinID = mocroSkins[rank] or mocroSkins[1]
        if getElementModel(player) ~= skinID then
            -- setElementModel(player, skinID) -- Wird von login_server.lua's loadAndSetPlayerSkin gehandhabt
        end
        outputDebugString("[MocroMafia] onPlayerLoginSuccess: Daten für Mocro Mitglied "..getPlayerName(player).." verarbeitet.")
    end
end)