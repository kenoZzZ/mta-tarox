-- tarox/fraktionen/medic_server.lua
-- Version mit Speicherung des Dienststatus in der Datenbank UND neuem Patientenlisten-System
-- ANGEPASST V12.1: Verbesserte Fehlerbehandlung für Datenbankaufrufe
-- NEU V12.2: /heal Befehl hinzugefügt

local FRACTION_ID_MEDIC = 3
local FRACTION_NAME_MEDIC = "Medic"
local MEDIC_COLOR_1 = 1
local MEDIC_COLOR_2 = 3
local MEDIC_COLOR_3 = 1
local MEDIC_COLOR_4 = 3

local medicPlayerSpawn = { x = -2654.39795, y = 633.56366, z = 14.45312, rot = 180 }

local ambulanceSpawnsConfig = {
    { x = -2654.03418, y = 620.69617, z = 14.65962, rot = 0 },
    { x = -2658.16382, y = 620.35284, z = 14.65906, rot = 0 },
    { x = -2662.26929, y = 620.30396, z = 14.65935, rot = 0 }
}
local spawnedAmbulances = {}
local AMBULANCE_MODEL_ID = 416
local AMBULANCE_MIN_RANK = 1
local AMBULANCE_RESPAWN_DELAY_EMPTY = 10 * 60 * 1000

local maverickSpawnsConfig = {
    { x = -2693.78613, y = 540.01575, z = 48.06757, rot = 180 },
    { x = -2682.20166, y = 540.92084, z = 48.06996, rot = 180 }
}
local MAVERICK_MODEL_ID = 487
local MAVERICK_MIN_RANK = 4

local leviathanSpawnConfig = {
    x = -2644.72021, y = 515.48358, z = 48.73210, rot = 270
}
local LEVIATHAN_MODEL_ID = 417
local LEVIATHAN_MIN_RANK = 5

local spawnedHelicopters = {}
local HELI_RESPAWN_DELAY_EMPTY = 10 * 60 * 1000
local VEHICLE_EXPLODE_RESPAWN_DELAY = 15 * 1000

local medicGatesConfig = {
    { objectID = 968, name = "Gate1_SE", closedPos = { x = -2670.3000488281, y = 579.29998779297, z = 14.5, rx = 0, ry = 90, rz = 0 }, openPos = { x = -2670.3000488281, y = 579.29998779297, z = 14.5, rx = 0, ry = 0, rz = 0 }, obj = nil, isOpen = false, checkRadius = 7 },
    { objectID = 968, name = "Gate2_SW", closedPos = { x = -2610.1000976562, y = 578.40002441406, z = 14.5, rx = 0, ry = 90, rz = 0 }, openPos = { x = -2610.1000976562, y = 578.40002441406, z = 14.5, rx = 0, ry = 0, rz = 0 }, obj = nil, isOpen = false, checkRadius = 7 },
    { objectID = 968, name = "Gate3_NW", closedPos = { x = -2570.1999511719, y = 579.09997558594, z = 14.5, rx = 0, ry = 90, rz = 0 }, openPos = { x = -2570.1999511719, y = 579.09997558594, z = 14.5, rx = 0, ry = 0, rz = 0 }, obj = nil, isOpen = false, checkRadius = 7 },
    { objectID = 968, name = "Gate4_NE_Heli", closedPos = { x = -2609.3999023438, y = 697.79998779297, z = 27.799999237061, rx = 0, ry = 90, rz = 0 }, openPos = { x = -2609.3999023438, y = 697.79998779297, z = 27.799999237061, rx = 0, ry = 0, rz = 0 }, obj = nil, isOpen = false, checkRadius = 7 }
}
local gateCheckTimer = nil
local activeVehicleDespawnTimers = {}

local entranceMarkerPos = { x = -2655.3000488281, y = 638.79998779297, z = 14.5 }
local entranceTargetPos = { x = -2686.93188, y = 568.22760, z = 48.65371 }
local entranceMarkerElement = nil

local defaultPlayerSpawnPoint = _G.defaultSpawn or { x=0, y=0, z=5, rot=0, int=0, dim=1 }

local REVIVE_ANIM_DURATION = 5000
local REVIVE_MAX_DISTANCE = 3.0
local REVIVE_REWARD = 500
local REVIVE_HEALTH_ON_SPAWN = 50
local revivingPlayers = {}

-- NEU: Konstanten für /heal
local HEAL_MAX_DISTANCE = 5.0
local HEAL_REWARD = 100
local HEAL_TARGET_HEALTH = 100
local HEAL_ANIMATION_DURATION = 3000 -- 3 Sekunden

function getPlayerAccountID(player) if not isElement(player) then return nil end; return getElementData(player, "account_id") end

function getMedicSkinByRank(rank)
    if not _G.FRACTION_SKINS or not _G.FRACTION_SKINS[FRACTION_ID_MEDIC] then
        outputDebugString("[MedicServer] FEHLER: _G.FRACTION_SKINS oder Skins für Medic ID " .. FRACTION_ID_MEDIC .. " nicht gefunden!")
        return 274
    end
    local medicSkinsForRank = _G.FRACTION_SKINS[FRACTION_ID_MEDIC]
    return medicSkinsForRank[math.min(rank, #medicSkinsForRank)] or medicSkinsForRank[1] or 274
end

function setPlayerMedicDutyStatus(player, onDuty)
    local accID = getPlayerAccountID(player)
    if not accID then return false, "No account_id" end

    local dutyStatus = onDuty and 1 or 0
    local success, errMsg = exports.datenbank:executeDatabase("UPDATE fraction_members SET on_duty = ? WHERE account_id = ? AND fraction_id = ?", dutyStatus, accID, FRACTION_ID_MEDIC)
    if success then
        setElementData(player, "medicImDienst", onDuty)
        if onDuty then
            local _, rank = getPlayerFractionAndRank(player)
            setElementModel(player, getMedicSkinByRank(rank))
        end
        if type(_G.refreshPlayerFractionData) == "function" then _G.refreshPlayerFractionData(player) end
        return true, "Success"
    else
        outputDebugString("[MedicServer] FEHLER beim Aktualisieren des Dienststatus in der DB für AccID: " .. accID .. ": " .. (errMsg or "Unbekannt"))
        return false, "Database error updating duty status"
    end
end

function initializeMedicBase()
    for i, gateData in ipairs(medicGatesConfig) do
        if isElement(gateData.obj) then destroyElement(gateData.obj) end
        local obj = createObject(gateData.objectID, gateData.closedPos.x, gateData.closedPos.y, gateData.closedPos.z, gateData.closedPos.rx, gateData.closedPos.ry, gateData.closedPos.rz)
        if isElement(obj) then setElementFrozen(obj, true); medicGatesConfig[i].obj = obj; medicGatesConfig[i].isOpen = false
        else outputDebugString("[MedicServer] FEHLER: Konnte Schrankenobjekt " .. gateData.name .. " nicht erstellen.") end
    end
    if isTimer(gateCheckTimer) then killTimer(gateCheckTimer) end
    gateCheckTimer = setTimer(checkMedicGates, 1500, 0)

    if isElement(entranceMarkerElement) then destroyElement(entranceMarkerElement) end
    entranceMarkerElement = createMarker(entranceMarkerPos.x, entranceMarkerPos.y, entranceMarkerPos.z -1, "cylinder", 1.5, 0, 255, 255, 150)
    if isElement(entranceMarkerElement) then setElementData(entranceMarkerElement, "medicEntrance", true); addEventHandler("onMarkerHit", entranceMarkerElement, handleMedicEntranceHit)
    else outputDebugString("[MedicServer] FEHLER: Konnte Medic-Eingangsmarker nicht erstellen.") end

    for i = 1, #ambulanceSpawnsConfig do respawnMedicVehicle("ambulance", i) end
    for i = 1, #maverickSpawnsConfig do respawnMedicVehicle("maverick", i) end
    respawnMedicVehicle("leviathan", 1)

    for _, p in ipairs(getElementsByType("player")) do
        if isElement(p) then
            local acc_id_start = getPlayerAccountID(p)
            if acc_id_start then
                local fid_start, rank_start = getPlayerFractionAndRank(p)
                if fid_start == FRACTION_ID_MEDIC then
                    local dutyResult, dutyErrMsg = exports.datenbank:queryDatabase("SELECT on_duty FROM fraction_members WHERE account_id = ? AND fraction_id = ? LIMIT 1", acc_id_start, FRACTION_ID_MEDIC)
                    local isOnDutyDB_start = false
                    if not dutyResult then
                        outputDebugString("[MedicServer] onResourceStart: DB Fehler beim Laden des Duty-Status für AccID " .. acc_id_start .. ": " .. (dutyErrMsg or "Unbekannt"))
                    elseif dutyResult and dutyResult[1] and tonumber(dutyResult[1].on_duty) == 1 then
                        isOnDutyDB_start = true
                    end
                    setElementData(p, "medicImDienst", isOnDutyDB_start)
                end
            end
        end
    end
end
addEventHandler("onResourceStart", resourceRoot, initializeMedicBase)

function checkMedicGates()
    for i, gateData in ipairs(medicGatesConfig) do
        if isElement(gateData.obj) then
            local shouldBeOpen = false
            local playersInRange = getElementsWithinRange(gateData.closedPos.x, gateData.closedPos.y, gateData.closedPos.z, gateData.checkRadius, "player")
            for _, player in ipairs(playersInRange) do
                if getElementDimension(player) == getElementDimension(gateData.obj) and getElementInterior(player) == getElementInterior(gateData.obj) then
                    local fid, _ = getPlayerFractionAndRank(player)
                    if fid == FRACTION_ID_MEDIC then shouldBeOpen = true; break end
                end
            end
            if shouldBeOpen and not gateData.isOpen then
                moveObject(gateData.obj, 1000, gateData.openPos.x, gateData.openPos.y, gateData.openPos.z, gateData.openPos.rx - gateData.closedPos.rx, gateData.openPos.ry - gateData.closedPos.ry, gateData.openPos.rz - gateData.closedPos.rz)
                medicGatesConfig[i].isOpen = true
            elseif not shouldBeOpen and gateData.isOpen then
                moveObject(gateData.obj, 1000, gateData.closedPos.x, gateData.closedPos.y, gateData.closedPos.z, gateData.closedPos.rx - gateData.openPos.rx, gateData.closedPos.ry - gateData.openPos.ry, gateData.closedPos.rz - gateData.openPos.rz)
                medicGatesConfig[i].isOpen = false
            end
        end
    end
end

function handleMedicEntranceHit(hitElement, matchingDimension)
    if getElementType(hitElement) == "player" and matchingDimension and not isPedInVehicle(hitElement) then
        local fid, _ = getPlayerFractionAndRank(hitElement)
        if fid == FRACTION_ID_MEDIC then
            fadeCamera(hitElement, false, 0.5)
            setTimer(function(player) if isElement(player) then setElementPosition(player, entranceTargetPos.x, entranceTargetPos.y, entranceTargetPos.z); setElementRotation(player, 0,0,90); setElementInterior(player,0); setElementDimension(player,0); fadeCamera(player,true,0.5) end end, 500, 1, hitElement)
        else outputChatBox("Zutritt nur für Medic Personal.", hitElement, 255,100,0) end
    end
end

function respawnMedicVehicle(vehicleType, spawnIndex)
    local config, modelId, storageTableRefName, minRank, currentVehicleData = nil
    local isHeli = false
    if vehicleType == "ambulance" then
        config, modelId, storageTableRefName, minRank = ambulanceSpawnsConfig[spawnIndex], AMBULANCE_MODEL_ID, "spawnedAmbulances", AMBULANCE_MIN_RANK
        currentVehicleData = spawnedAmbulances[spawnIndex]
    elseif vehicleType == "maverick" then
        config, modelId, storageTableRefName, minRank = maverickSpawnsConfig[spawnIndex], MAVERICK_MODEL_ID, "spawnedHelicopters", MAVERICK_MIN_RANK
        isHeli = true
        for i, heliData in ipairs(spawnedHelicopters) do if heliData.type == "maverick" and heliData.spawnIndex == spawnIndex then currentVehicleData = heliData; break end end
    elseif vehicleType == "leviathan" then
        config, modelId, storageTableRefName, minRank = leviathanSpawnConfig, LEVIATHAN_MODEL_ID, "spawnedHelicopters", LEVIATHAN_MIN_RANK
        isHeli = true
        for i, heliData in ipairs(spawnedHelicopters) do if heliData.type == "leviathan" then currentVehicleData = heliData; break end end
    else return end
    if not config then return end
    if currentVehicleData and isElement(currentVehicleData.vehicle) then
        if isTimer(activeVehicleDespawnTimers[currentVehicleData.vehicle]) then killTimer(activeVehicleDespawnTimers[currentVehicleData.vehicle]); activeVehicleDespawnTimers[currentVehicleData.vehicle] = nil; end
        destroyElement(currentVehicleData.vehicle)
    end
    if vehicleType == "ambulance" then spawnedAmbulances[spawnIndex] = nil
    elseif isHeli then
        local foundIdx = nil
        for i, data in ipairs(spawnedHelicopters) do if data.type == vehicleType and (vehicleType == "leviathan" or data.spawnIndex == spawnIndex) then foundIdx = i; break end end
        if foundIdx then table.remove(spawnedHelicopters, foundIdx) end
    end
    local veh = createVehicle(modelId, config.x, config.y, config.z, 0, 0, config.rot)
    if isElement(veh) then
        setVehicleColor(veh, MEDIC_COLOR_1, MEDIC_COLOR_2, MEDIC_COLOR_3, MEDIC_COLOR_4)
        setElementData(veh, "medicVehicle", true); setElementData(veh, "vehicleType", vehicleType); setElementData(veh, "minRank", minRank); setElementData(veh, "spawnIndex", vehicleType ~= "leviathan" and spawnIndex or 1)
        setElementData(veh, "fraction", FRACTION_ID_MEDIC)
        local vehicleEntry = { vehicle = veh, spawnIndex = (vehicleType ~= "leviathan" and spawnIndex or 1), type = vehicleType }
        if vehicleType == "ambulance" then spawnedAmbulances[spawnIndex] = vehicleEntry
        else table.insert(spawnedHelicopters, vehicleEntry) end
        addEventHandler("onVehicleExplode", veh, handleMedicVehicleExplodeGeneral)
        addEventHandler("onVehicleStartEnter", veh, handleMedicVehicleEnter)
        addEventHandler("onVehicleExit", veh, handleMedicVehicleExitGeneral)
    end
end

function handleMedicVehicleExplodeGeneral()
    local vehicle = source; local vehicleType = getElementData(vehicle, "vehicleType"); local spawnIndex = getElementData(vehicle, "spawnIndex")
    if isTimer(activeVehicleDespawnTimers[vehicle]) then killTimer(activeVehicleDespawnTimers[vehicle]); activeVehicleDespawnTimers[vehicle] = nil; end
    if vehicleType and (spawnIndex or vehicleType == "leviathan") then setTimer(respawnMedicVehicle, VEHICLE_EXPLODE_RESPAWN_DELAY, 1, vehicleType, spawnIndex or 1) end
    if vehicleType == "ambulance" and spawnIndex and spawnedAmbulances[spawnIndex] and spawnedAmbulances[spawnIndex].vehicle == vehicle then spawnedAmbulances[spawnIndex] = nil
    else for i, heliData in ipairs(spawnedHelicopters) do if heliData.vehicle == vehicle then table.remove(spawnedHelicopters, i); break end end end
end

function handleMedicVehicleExitGeneral(playerExiting, seat)
    local vehicle = source
    if not getElementData(vehicle, "medicVehicle") then return end
    if isTimer(activeVehicleDespawnTimers[vehicle]) then killTimer(activeVehicleDespawnTimers[vehicle]); activeVehicleDespawnTimers[vehicle] = nil; end
    local occupants = getVehicleOccupants(vehicle)
    if not occupants or #occupants == 0 then
        local vehicleType = getElementData(vehicle, "vehicleType")
        local spawnIndex = getElementData(vehicle, "spawnIndex")
        local delay = (vehicleType == "ambulance") and AMBULANCE_RESPAWN_DELAY_EMPTY or HELI_RESPAWN_DELAY_EMPTY
        activeVehicleDespawnTimers[vehicle] = setTimer(function(veh, vType, sIndex)
            if isElement(veh) then
                local stillEmpty = true; local o = getVehicleOccupants(veh); if o and #o > 0 then stillEmpty = false end
                if stillEmpty then respawnMedicVehicle(vType, sIndex) end
                activeVehicleDespawnTimers[veh] = nil
            end
        end, delay, 1, vehicle, vehicleType, spawnIndex)
    end
end

function handleMedicVehicleEnter(player, seat)
    if seat ~= 0 then return end
    local vehicle = source
    local fid, rank = getPlayerFractionAndRank(player)

    if fid ~= FRACTION_ID_MEDIC then
        outputChatBox("Nur für Medic Personal!", player, 255, 0, 0)
        cancelEvent(); return
    end

    local isImDienst = getElementData(player, "medicImDienst")
    if not isImDienst then
        outputChatBox("Du musst im Dienst sein, um dieses Fahrzeug zu benutzen!", player, 255, 100, 0)
        cancelEvent(); return
    end

    if isTimer(activeVehicleDespawnTimers[vehicle]) then
        killTimer(activeVehicleDespawnTimers[vehicle])
        activeVehicleDespawnTimers[vehicle] = nil
    end

    local minRankRequired = getElementData(vehicle, "minRank") or 1
    if rank < minRankRequired then
        outputChatBox("Dein Rang (" .. rank .. ") ist nicht hoch genug für dieses Fahrzeug (Benötigt: Rang " .. minRankRequired .. ").", player, 255, 100, 0)
        cancelEvent()
    end
end

addCommandHandler("medic", function(player)
    local fid, rank = getPlayerFractionAndRank(player)
    if fid ~= FRACTION_ID_MEDIC then outputChatBox("Du bist kein Mitglied des " .. FRACTION_NAME_MEDIC .. " Departments!", player,255,0,0); return end
    local wantedLevel = getElementData(player, "wanted") or 0
    triggerClientEvent(player, "openMedicWindow", player, rank, wantedLevel)
end)

addEvent("onMedicRequestSpawn", true)
addEventHandler("onMedicRequestSpawn", root, function()
    local player = source
    local allowedToSpawn, messageSpawn = exports.tarox:canPlayerUseFactionSpawnCommand(player)
    if not allowedToSpawn then outputChatBox(messageSpawn, player,255,100,0); return end
    local wantedLevel = getElementData(player, "wanted") or 0
    if wantedLevel > 0 then outputChatBox("Du kannst nicht in den Dienst gehen, während du gesucht wirst!", player, 255,0,0); return end
    local fid, rank = getPlayerFractionAndRank(player)
    if fid ~= FRACTION_ID_MEDIC then outputChatBox("Du bist kein Mitglied des " .. FRACTION_NAME_MEDIC .. " Departments!", player,255,0,0); return end
    local currentX, currentY, currentZ = getElementPosition(player); local currentRot = getPedRotation(player); local currentInt = getElementInterior(player); local currentDim = getElementDimension(player)
    setElementData(player, "lastPositionCivil", {x=currentX, y=currentY, z=currentZ, rot=currentRot, int=currentInt, dim=currentDim})

    local dutySuccess, dutyMsg = setPlayerMedicDutyStatus(player, true)
    if not dutySuccess then
        outputChatBox("Fehler beim Dienstantritt: " .. (dutyMsg or "Unbekannter DB Fehler"), player, 255,0,0)
        return
    end
    spawnPlayer(player, medicPlayerSpawn.x, medicPlayerSpawn.y, medicPlayerSpawn.z, medicPlayerSpawn.rot, getElementModel(player), 0, 0)
    fadeCamera(player, true); setCameraTarget(player, player);
    outputChatBox("Du hast den Dienst als Medic (Rang " .. rank .. ") angetreten!", player, 0,200,220)
end)

addEvent("onMedicRequestOffDuty", true)
addEventHandler("onMedicRequestOffDuty", root, function()
    local player = source
    local accID = getPlayerAccountID(player)
    if not accID then return end

    local fid, _ = getPlayerFractionAndRank(player)
    if fid ~= FRACTION_ID_MEDIC then outputChatBox("Du bist nicht im " .. FRACTION_NAME_MEDIC .. " Department.", player,255,0,0); return end

    local isImDienst = getElementData(player, "medicImDienst")
    if not isImDienst then
        outputChatBox("Du bist bereits außer Dienst.", player,255,165,0)
        return
    end

    local standardSkinResult, skinErrMsg = exports.datenbank:queryDatabase("SELECT standard_skin FROM account WHERE id=? LIMIT 1", accID)
    local standardSkin = (_G.DEFAULT_CIVIL_SKIN or 0)
    if not standardSkinResult then
        outputDebugString("[MedicServer] DB Fehler beim Laden des Standard-Skins für AccID " .. accID .. " (OffDuty): " .. (skinErrMsg or "Unbekannt"))
    elseif standardSkinResult and standardSkinResult[1] and tonumber(standardSkinResult[1].standard_skin) then
        standardSkin = tonumber(standardSkinResult[1].standard_skin)
    end
    setElementModel(player, standardSkin)

    local dutySuccess, dutyMsg = setPlayerMedicDutyStatus(player, false)
    if not dutySuccess then
        outputChatBox("Fehler beim Verlassen des Dienstes: " .. (dutyMsg or "Unbekannter DB Fehler"), player,255,0,0)
        local _, rank_fallback = getPlayerFractionAndRank(player)
        setElementModel(player, getMedicSkinByRank(rank_fallback))
        setPlayerMedicDutyStatus(player, true)
        return
    end
    outputChatBox("Du hast den Dienst vorerst verlassen. Du bleibst an deiner aktuellen Position.", player,0,200,220)
end)

addCommandHandler("revive", function(medicPlayer, commandName, targetPlayerNameOrID)
    local fid, rank = getPlayerFractionAndRank(medicPlayer)
    if fid ~= FRACTION_ID_MEDIC then outputChatBox("Nur Medics können diesen Befehl verwenden.", medicPlayer,255,0,0); return end
    if getElementData(medicPlayer, "medicImDienst") ~= true then outputChatBox("Du musst im Dienst sein, um jemanden wiederzubeleben.", medicPlayer,255,100,0); return end
    if revivingPlayers[medicPlayer] then outputChatBox("Du bist bereits dabei, jemanden wiederzubeleben.", medicPlayer,255,165,0); return end
    local targetPlayer = nil
    if targetPlayerNameOrID then
        targetPlayer = getPlayerFromName(targetPlayerNameOrID)
        if not targetPlayer then local id=tonumber(targetPlayerNameOrID); if id then for _,p in ipairs(getElementsByType("player"))do if getPlayerAccountID(p)==id then targetPlayer=p; break end end end end
    else
        local mx,my,mz=getElementPosition(medicPlayer); local closestPlayer,closestDist=nil,REVIVE_MAX_DISTANCE+0.1
        for player,data in pairs(_G.awaitingRevive or {})do if isElement(player)and getElementData(player,"isCurrentlyDead")==true then local px,py,pz=getElementPosition(player); local dist=getDistanceBetweenPoints3D(mx,my,mz,px,py,pz); if dist<closestDist then closestDist=dist; closestPlayer=player end end end
        targetPlayer = closestPlayer
    end
    if not isElement(targetPlayer)then outputChatBox("Kein wiederzubelebender Spieler gefunden/angegeben.", medicPlayer,255,100,0); return end
    local mX,mY,mZ=getElementPosition(medicPlayer); local tX,tY,tZ=getElementPosition(targetPlayer)
    if getDistanceBetweenPoints3D(mX,mY,mZ,tX,tY,tZ)>REVIVE_MAX_DISTANCE then outputChatBox(getPlayerName(targetPlayer).." ist zu weit entfernt.", medicPlayer,255,100,0); return end
    if getElementData(targetPlayer,"isCurrentlyDead")~=true then outputChatBox(getPlayerName(targetPlayer).." wartet nicht auf Wiederbelebung.", medicPlayer,255,165,0); return end
    revivingPlayers[medicPlayer]=targetPlayer; setPedAnimation(medicPlayer,"MEDIC","CPR",-1,false,false,false,false); toggleAllControls(medicPlayer,false,true,false)
    outputChatBox("Du beginnst mit der Wiederbelebung von "..getPlayerName(targetPlayer).."...", medicPlayer,0,200,220); triggerClientEvent(medicPlayer,"medic:startReviveTimerClient",medicPlayer,REVIVE_ANIM_DURATION)
    setTimer(function(medic,victim)
        if not isElement(medic)or not isElement(victim)then if isElement(medic)then toggleAllControls(medic,true,true,true);setPedAnimation(medic,false);revivingPlayers[medic]=nil;outputChatBox("Wiederbelebung abgebrochen (Spieler ungültig).",medic,255,0,0);triggerClientEvent(medic,"medic:stopReviveTimerClient",medic)end;return end
        if revivingPlayers[medic]~=victim then return end
        local medicX,medicY,medicZ=getElementPosition(medic); local victimX,victimY,victimZ=getElementPosition(victim)
        if getDistanceBetweenPoints3D(medicX,medicY,medicZ,victimX,victimY,victimZ)>REVIVE_MAX_DISTANCE+1 then toggleAllControls(medic,true,true,true);setPedAnimation(medic,false);revivingPlayers[medic]=nil;outputChatBox("Wiederbelebung abgebrochen: Zu weit entfernt.",medic,255,100,0);triggerClientEvent(medic,"medic:stopReviveTimerClient",medic);return end
        if getElementData(victim,"isCurrentlyDead")~=true then toggleAllControls(medic,true,true,true);setPedAnimation(medic,false);revivingPlayers[medic]=nil;outputChatBox(getPlayerName(victim).." wurde bereits versorgt.",medic,255,165,0);triggerClientEvent(medic,"medic:stopReviveTimerClient",medic);return end
        local deathData=(_G.awaitingRevive or{})[victim]; if not deathData then toggleAllControls(medic,true,true,true);setPedAnimation(medic,false);revivingPlayers[medic]=nil;outputChatBox("Fehler: Wiederbelebungsdaten für "..getPlayerName(victim).." nicht gefunden.",medic,255,0,0);triggerClientEvent(medic,"medic:stopReviveTimerClient",medic);return end
        spawnPlayer(victim,deathData.deathX,deathData.deathY,deathData.deathZ,deathData.deathRot,getElementModel(victim),deathData.deathInt,deathData.deathDim); setElementHealth(victim,REVIVE_HEALTH_ON_SPAWN); fadeCamera(victim,true,1.0); setCameraTarget(victim,victim); setTimer(function(p)if isElement(p)then toggleAllControls(p,true,true,true)end end,500,1,victim)
        givePlayerMoney(medic,REVIVE_REWARD); outputChatBox("Du hast "..getPlayerName(victim).." erfolgreich wiederbelebt und $"..REVIVE_REWARD.." erhalten!",medic,0,255,0); outputChatBox("Du wurdest von einem Medic wiederbelebt!",victim,0,255,0)
        triggerEvent("medic:playerRevived",root,victim); toggleAllControls(medic,true,true,true); setPedAnimation(medic,false); revivingPlayers[medic]=nil; triggerClientEvent(medic,"medic:stopReviveTimerClient",medic)
    end,REVIVE_ANIM_DURATION,1,medicPlayer,targetPlayer)
end)

-- NEUER BEFEHL /heal
addCommandHandler("heal", function(medicPlayer, commandName, targetPlayerNameOrID)
    local fid, rank = getPlayerFractionAndRank(medicPlayer)
    if fid ~= FRACTION_ID_MEDIC then
        outputChatBox("Nur Medics können diesen Befehl verwenden.", medicPlayer, 255, 0, 0)
        return
    end
    if getElementData(medicPlayer, "medicImDienst") ~= true then
        outputChatBox("Du musst im Dienst sein, um jemanden zu heilen.", medicPlayer, 255, 100, 0)
        return
    end

    if not targetPlayerNameOrID then
        outputChatBox("SYNTAX: /" .. commandName .. " [Spieler Name/ID]", medicPlayer, 200, 200, 0)
        return
    end

    local targetPlayer = nil
    local potentialTargets = {}
    local searchStringLower = string.lower(tostring(targetPlayerNameOrID))

    for _, p in ipairs(getElementsByType("player")) do
        if getElementData(p, "account_id") then
            if string.find(string.lower(getPlayerName(p)), searchStringLower, 1, true) or
               tostring(getElementData(p, "account_id")) == searchStringLower then
                table.insert(potentialTargets, p)
            end
        end
    end

    if #potentialTargets == 0 then
        outputChatBox("Spieler '" .. targetPlayerNameOrID .. "' nicht gefunden.", medicPlayer, 255, 100, 0)
        return
    elseif #potentialTargets > 1 then
        outputChatBox("Mehrere Spieler gefunden, bitte sei genauer:", medicPlayer, 255, 165, 0)
        for i=1, math.min(5, #potentialTargets) do local tP=potentialTargets[i]; outputChatBox("  - "..getPlayerName(tP).." (ID: "..(getElementData(tP,"account_id")or"N/A")..")", medicPlayer,200,200,200) end
        if #potentialTargets > 5 then outputChatBox("  ... und weitere.", medicPlayer, 200,200,200) end
        return
    else
        targetPlayer = potentialTargets[1]
    end


    if not isElement(targetPlayer) then
        outputChatBox("Zielspieler '" .. targetPlayerNameOrID .. "' nicht gefunden.", medicPlayer, 255, 100, 0)
        return
    end

    if targetPlayer == medicPlayer then
        outputChatBox("Du kannst dich nicht selbst heilen.", medicPlayer, 255, 165, 0)
        return
    end

    if isPedDead(targetPlayer) or getElementData(targetPlayer, "isCurrentlyDead") == true then
        outputChatBox(getPlayerName(targetPlayer) .. " ist tot und kann nicht geheilt werden. Benutze /revive.", medicPlayer, 255, 100, 0)
        return
    end

    local currentHealth = getElementHealth(targetPlayer)
    if currentHealth >= HEAL_TARGET_HEALTH then
        outputChatBox(getPlayerName(targetPlayer) .. " hat bereits volle oder fast volle Gesundheit.", medicPlayer, 0, 200, 100)
        return
    end

    local mX, mY, mZ = getElementPosition(medicPlayer)
    local tX, tY, tZ = getElementPosition(targetPlayer)
    if getDistanceBetweenPoints3D(mX, mY, mZ, tX, tY, tZ) > HEAL_MAX_DISTANCE then
        outputChatBox(getPlayerName(targetPlayer) .. " ist zu weit entfernt (max. 5 Meter).", medicPlayer, 255, 100, 0)
        return
    end

    -- Animation starten und Controls sperren
    setPedAnimation(medicPlayer, "MEDIC", "HEAL", -1, true, false, false, false) -- Eine passende Animation, z.B. BOMB_Place_Loop oder eine spezifische Heilungsanimation
    toggleAllControls(medicPlayer, false, true, false)
    outputChatBox("Du beginnst mit der Behandlung von " .. getPlayerName(targetPlayer) .. "...", medicPlayer, 0, 200, 220)
    -- Client-seitigen Timer für Fortschrittsbalken (optional)
    triggerClientEvent(medicPlayer, "medic:startHealTimerClient", medicPlayer, HEAL_ANIMATION_DURATION)


    setTimer(function(medic, victim)
        if not isElement(medic) or not isElement(victim) then
            if isElement(medic) then
                toggleAllControls(medic, true, true, true)
                setPedAnimation(medic, false)
                triggerClientEvent(medic, "medic:stopHealTimerClient", medic) -- Client-Timer stoppen
            end
            return
        end

        -- Erneute Distanzprüfung
        local medX, medY, medZ = getElementPosition(medic)
        local vicX, vicY, vicZ = getElementPosition(victim)
        if getDistanceBetweenPoints3D(medX, medY, medZ, vicX, vicY, vicZ) > HEAL_MAX_DISTANCE + 1 then -- Kleine Toleranz
            toggleAllControls(medic, true, true, true)
            setPedAnimation(medic, false)
            outputChatBox("Behandlung abgebrochen: Patient zu weit entfernt.", medic, 255, 100, 0)
            if isElement(victim) then outputChatBox("Der Medic hat sich zu weit entfernt.", victim, 255,100,0) end
            triggerClientEvent(medic, "medic:stopHealTimerClient", medic)
            return
        end

        if isPedDead(victim) then -- Falls der Spieler während der Behandlung stirbt
             toggleAllControls(medic, true, true, true)
             setPedAnimation(medic, false)
             outputChatBox(getPlayerName(victim) .. " ist während der Behandlung verstorben.", medic, 255, 100, 0)
             triggerClientEvent(medic, "medic:stopHealTimerClient", medic)
             return
        end

        setElementHealth(victim, HEAL_TARGET_HEALTH)
        givePlayerMoney(medic, HEAL_REWARD)

        outputChatBox("Du hast " .. getPlayerName(victim) .. " erfolgreich auf " .. HEAL_TARGET_HEALTH .. " HP geheilt und $" .. HEAL_REWARD .. " erhalten!", medic, 0, 255, 0)
        outputChatBox(getPlayerName(medic) .. " hat dich geheilt!", victim, 0, 255, 0)

        toggleAllControls(medic, true, true, true)
        setPedAnimation(medic, false)
        triggerClientEvent(medic, "medic:stopHealTimerClient", medic)
    end, HEAL_ANIMATION_DURATION, 1, medicPlayer, targetPlayer)
end)


addEventHandler("onPlayerLoginSuccess", root, function()
    local player = source
    local accID = getPlayerAccountID(player)
    if not accID then return end

    local fid, rank = getPlayerFractionAndRank(player)
    if fid == FRACTION_ID_MEDIC then
        local dutyResult, errMsg = exports.datenbank:queryDatabase("SELECT on_duty FROM fraction_members WHERE account_id = ? AND fraction_id = ? LIMIT 1", accID, FRACTION_ID_MEDIC)
        local isOnDutyDB = false
        if not dutyResult then
            outputDebugString("[MedicServer] onPlayerLoginSuccess: DB Fehler beim Laden des Duty-Status für AccID " .. accID .. ": " .. (errMsg or "Unbekannt"))
        elseif dutyResult and dutyResult[1] and tonumber(dutyResult[1].on_duty) == 1 then
            isOnDutyDB = true
        end
        setElementData(player, "medicImDienst", isOnDutyDB)
        if isOnDutyDB then
            setElementModel(player, getMedicSkinByRank(rank))
        end
    end
end)

addEventHandler("onPlayerQuit", root, function()
    local player = source
    if revivingPlayers[player] then local victim=revivingPlayers[player]; if isElement(victim)then outputChatBox("Der Medic hat den Server verlassen.",victim,255,165,0)end; setPedAnimation(player,false);toggleAllControls(player,true,true,true);revivingPlayers[player]=nil;triggerClientEvent(player,"medic:stopReviveTimerClient",player)end
    for medic,patient in pairs(revivingPlayers)do if patient==player then if isElement(medic)then outputChatBox(getPlayerName(player).." hat den Server verlassen.",medic,255,165,0);toggleAllControls(medic,true,true,true);setPedAnimation(medic,false);triggerClientEvent(medic,"medic:stopReviveTimerClient",medic)end;revivingPlayers[medic]=nil;break end end
    local accID = getPlayerAccountID(player)
    if accID then
        local fid, _ = getPlayerFractionAndRank(player)
        if fid == FRACTION_ID_MEDIC then
            local isOnDuty = getElementData(player, "medicImDienst") or false
            setPlayerMedicDutyStatus(player, isOnDuty)
        end
    end
end)

addEventHandler("onResourceStop", resourceRoot, function()
    if isTimer(gateCheckTimer) then killTimer(gateCheckTimer); gateCheckTimer = nil; end
    for i = #medicGatesConfig, 1, -1 do local gd = medicGatesConfig[i]; if gd and isElement(gd.obj) then destroyElement(gd.obj) end; table.remove(medicGatesConfig, i) end
    if isElement(entranceMarkerElement) then destroyElement(entranceMarkerElement); entranceMarkerElement = nil; end
    for _, data in pairs(spawnedAmbulances) do if data and isElement(data.vehicle) then destroyElement(data.vehicle) end end; spawnedAmbulances = {}
    for _, data in pairs(spawnedHelicopters) do if data and isElement(data.vehicle) then destroyElement(data.vehicle) end end; spawnedHelicopters = {}
    for veh, timer in pairs(activeVehicleDespawnTimers) do if isTimer(timer) then killTimer(timer) end end; activeVehicleDespawnTimers = {}
    for _, player in ipairs(getElementsByType("player")) do
        if isElement(player) then
            local accID = getPlayerAccountID(player)
            if accID then
                 local fid, _ = getPlayerFractionAndRank(player)
                 if fid == FRACTION_ID_MEDIC then
                    local isOnDuty = getElementData(player, "medicImDienst") or false
                    setPlayerMedicDutyStatus(player, isOnDuty)
                 end
            end
        end
    end
    --outpudDebugString("[MedicServer] Medic Fraktionsskript gestoppt (V12.2 - /heal Befehl).")
end)

addEvent("medic:requestLowHealthPlayers", true)
addEventHandler("medic:requestLowHealthPlayers", root, function()
    local requestingMedic = client
    if not isElement(requestingMedic) then return end

    local fid_req, rank_req = getPlayerFractionAndRank(requestingMedic)
    if fid_req ~= FRACTION_ID_MEDIC or not getElementData(requestingMedic, "medicImDienst") then
        return
    end

    local lowHealthPlayers = {}
    for _, player in ipairs(getElementsByType("player")) do
        if isElement(player) and not isPedDead(player) then
            local health = getElementHealth(player)
            if health < 100 then
                table.insert(lowHealthPlayers, {
                    source = player,
                    name = getPlayerName(player),
                    health = health
                })
            end
        end
    end
    triggerClientEvent(requestingMedic, "medic:receiveLowHealthPlayers", requestingMedic, lowHealthPlayers)
end)

addEvent("medic:requestPlayerLocate", true)
addEventHandler("medic:requestPlayerLocate", root, function(targetPlayerElement)
    local requestingMedic = client
    if not isElement(requestingMedic) or not isElement(targetPlayerElement) then return end

    local fid_req, rank_req = getPlayerFractionAndRank(requestingMedic)
    if fid_req ~= FRACTION_ID_MEDIC or not getElementData(requestingMedic, "medicImDienst") then
        return
    end

    if getElementHealth(targetPlayerElement) >= 100 then
         outputChatBox(getPlayerName(targetPlayerElement) .. " benötigt keine dringende Ortung mehr (HP >= 100%).", requestingMedic, 255, 165, 0)
         return
    end
    if isPedDead(targetPlayerElement) then
         outputChatBox(getPlayerName(targetPlayerElement) .. " ist bereits verstorben.", requestingMedic, 255, 165, 0)
         return
    end

    local LOCATE_DURATION = 30 * 1000
    triggerClientEvent(requestingMedic, "medic:showPatientBlip", requestingMedic, targetPlayerElement, LOCATE_DURATION)
end)

--outpudDebugString("[MedicServer] Medic Fraktionsskript (V12.2 - /heal Befehl) geladen.")