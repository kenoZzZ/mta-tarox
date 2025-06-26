-- tarox/fraktionen/police/police_server.lua
-- << GEÄNDERT V7 >> Polizist bleibt beim Off-Duty an seiner aktuellen Position.
-- << NEU V8 >> Funktion clearPlayerPoliceWeaponsAndDutyWhenKickedOrFactionChanged hinzugefügt und exportiert.
-- << ANGEPASST V8.1 >> Verbesserte Fehlerbehandlung für Datenbankaufrufe
-- << NEU V8.2 >> Polizei Infernus Handling Anpassung
-- << MODIFIZIERT FÜR USER >> outputDebugString für Infernus Handling (Geschwindigkeit) auskommentiert
-- << MODIFIZIERT FÜR USER V4 >> Lenkungs-Debug beibehalten, unnötige positive Debugs entfernt
-- << MODIFIZIERT FÜR USER (NÄCHSTE ANFRAGE) >> Spezifische Infernus Handling-Debug-Zeile entfernt
-- << KORREKTUR V8.2.1 >> Unerwünschten Debug-Output vollständig entfernt

local lastUsage = {}
local COOLDOWN_MS = 10000

local POLICE_FRACTION_ID = 1
local POLICE_SPAWN_POS = { x = -1586.83459, y = 724.70258, z = -4.90625, rot = 270 }

local POLICE_DUTY_WEAPONS_BY_RANK = {
    [1] = { [3]=1, [23]=30 },
    [2] = { [3]=1, [23]=30, [25]=15 },
    [3] = { [3]=1, [23]=30, [25]=15, [29]=60 },
    [4] = { [3]=1, [23]=30, [25]=15, [29]=60, [31]=60, [17]=3 },
    [5] = { [3]=1, [23]=30, [25]=15, [29]=60, [31]=60, [17]=3, [34]=11 }
}

local INFERNUS_MODEL_ID = 411
local INFERNUS_PERFORMANCE_FACTOR = 1.50

local function getNumericValuePolice(value, default)
    local num = tonumber(value)
    if type(num) == "number" then
        return num
    end
    return default
end

function applyPoliceVehicleSpecificHandling(vehicle)
    if not isElement(vehicle) then return end
    local model = getElementModel(vehicle)

    if model == INFERNUS_MODEL_ID then
        local success, handlingTableToModify = pcall(getOriginalHandling, model)
        if not success or type(handlingTableToModify) ~= "table" then
            outputDebugString("[PoliceServer] FEHLER: Konnte Original-Handling für Modell " .. model .. " nicht laden für Tuning.")
            return
        end

        local baseMaxVelocity = 220.0
        local baseEngineAcceleration = 10.0
        local baseDriveForce = 0.35
        local baseSteeringLock = 35.0
        local baseTractionMultiplier = 0.85

        if handlingTableToModify.transmissionData and type(handlingTableToModify.transmissionData) == "table" then
            baseMaxVelocity = getNumericValuePolice(handlingTableToModify.transmissionData.maxVelocity, baseMaxVelocity)
            baseEngineAcceleration = getNumericValuePolice(handlingTableToModify.transmissionData.engineAcceleration, baseEngineAcceleration)
        else
            baseMaxVelocity = getNumericValuePolice(handlingTableToModify.maxVelocity, baseMaxVelocity)
            baseEngineAcceleration = getNumericValuePolice(handlingTableToModify.engineAcceleration, baseEngineAcceleration)
        end
        baseDriveForce = getNumericValuePolice(handlingTableToModify.driveForce, baseDriveForce)
        baseSteeringLock = getNumericValuePolice(handlingTableToModify.steeringLock, baseSteeringLock)
        baseTractionMultiplier = getNumericValuePolice(handlingTableToModify.tractionMultiplier, baseTractionMultiplier)

        local newMaxVelocity = baseMaxVelocity * INFERNUS_PERFORMANCE_FACTOR
        local newEngineAcceleration = baseEngineAcceleration * INFERNUS_PERFORMANCE_FACTOR
        local newDriveForce = baseDriveForce * INFERNUS_PERFORMANCE_FACTOR
        local newSteeringLock = baseSteeringLock * 1.05
        local newTractionMultiplier = baseTractionMultiplier * 1.1

        setVehicleHandling(vehicle, "maxVelocity", newMaxVelocity)
        setVehicleHandling(vehicle, "engineAcceleration", newEngineAcceleration)
        setVehicleHandling(vehicle, "driveForce", newDriveForce)
        setVehicleHandling(vehicle, "steeringLock", newSteeringLock)
        setVehicleHandling(vehicle, "tractionMultiplier", newTractionMultiplier)
        -- Die spezifische Debug-Zeile für Infernus-Lenkung wurde hier entfernt.
    end
end

function getPoliceSkinByRank(rank)
    local skins = {
        [1] = 280, [2] = 281, [3] = 282, [4] = 283, [5] = 288
    }
    return skins[rank] or 280
end

function givePoliceDutyWeapons(player, restoredWeaponsArray)
    if not isElement(player) then return false end
    local fid, rank = getPlayerFractionAndRank(player) --
    if fid ~= POLICE_FRACTION_ID or rank < 1 then return false end

    takeAllWeapons(player)

    if type(restoredWeaponsArray) == "table" and #restoredWeaponsArray > 0 then
        for _, weaponData in ipairs(restoredWeaponsArray) do
            if weaponData.weaponID and weaponData.ammo ~= nil then
                giveWeapon(player, tonumber(weaponData.weaponID), tonumber(weaponData.ammo))
            end
        end
    else
        local rankWeapons = POLICE_DUTY_WEAPONS_BY_RANK[rank]
        if rankWeapons then
            for weaponID, ammoCount in pairs(rankWeapons) do
                giveWeapon(player, weaponID, ammoCount)
            end
        end
    end
    return true
end
_G.givePoliceDutyWeapons = givePoliceDutyWeapons --

function savePoliceDutyWeaponsToSQL(player)
    if not isElement(player) then return false end
    local accountID = getElementData(player, "account_id") --
    local fid, rank = getPlayerFractionAndRank(player) --

    if not accountID then
        outputDebugString("[Police] savePoliceDutyWeaponsToSQL: Keine AccountID für " .. getPlayerName(player)) --
        return false
    end

    if fid ~= POLICE_FRACTION_ID or getElementData(player, "policeImDienst") ~= true then --
        local successClear, errMsgClear = exports.datenbank:executeDatabase("UPDATE weapons SET " .. table.concat((function() local t={} for i=1,9 do table.insert(t, string.format("weapon_slot%d = NULL, ammo_slot%d = 0",i,i)) end return t end)(), ", ") .. " WHERE account_id = ?", accountID) --
        if not successClear then
            outputDebugString("[Police] savePoliceDutyWeaponsToSQL: DB Fehler beim Leeren der Waffenslots für AccID " .. accountID .. ": " .. (errMsgClear or "Unbekannt")) --
        end
        return successClear
    end

    local dutyWeaponConfig = POLICE_DUTY_WEAPONS_BY_RANK[rank] --
    if not dutyWeaponConfig then
        outputDebugString("[Police] savePoliceDutyWeaponsToSQL: Keine Waffenkonfiguration für Rang " .. rank) --
        return false
    end

    local currentDutyWeaponsInHand = {}
    for slot = 0, 12 do
        local weaponInSlot = getPedWeapon(player, slot)
        if weaponInSlot and weaponInSlot > 0 and dutyWeaponConfig[weaponInSlot] then
            if #currentDutyWeaponsInHand < 9 then
                local alreadyAdded = false
                for _, existingWep in ipairs(currentDutyWeaponsInHand) do
                    if existingWep.weaponID == weaponInSlot then
                        alreadyAdded = true
                        break
                    end
                end
                if not alreadyAdded then
                    table.insert(currentDutyWeaponsInHand, {
                        weaponID = weaponInSlot,
                        ammo = getPedTotalAmmo(player, slot)
                    })
                end
            end
        end
    end

    local insertIgnoreSuccess, insertIgnoreErr = exports.datenbank:executeDatabase("INSERT IGNORE INTO weapons (account_id) VALUES (?)", accountID) --
    if not insertIgnoreSuccess then
        outputDebugString("[Police] FEHLER: DB INSERT IGNORE für weapons Tabelle fehlgeschlagen für AccID " .. accountID .. ": " .. (insertIgnoreErr or "Unbekannt")) --
    end

    local updatesSQLParts = {}
    local paramsSQL = {}

    for i = 1, 9 do
        if currentDutyWeaponsInHand[i] then
            table.insert(updatesSQLParts, string.format("weapon_slot%d = ?", i))
            table.insert(paramsSQL, currentDutyWeaponsInHand[i].weaponID)
            table.insert(updatesSQLParts, string.format("ammo_slot%d = ?", i))
            table.insert(paramsSQL, currentDutyWeaponsInHand[i].ammo)
        else
            table.insert(updatesSQLParts, string.format("weapon_slot%d = NULL", i))
            table.insert(updatesSQLParts, string.format("ammo_slot%d = 0", i))
        end
    end
    table.insert(paramsSQL, accountID)

    if #updatesSQLParts == 0 and #currentDutyWeaponsInHand > 0 then
         outputDebugString("[Police] FEHLER: Konnte keine SQL Update Parts erstellen für "..getPlayerName(player)) --
         return false
    end

    local queryString = "UPDATE weapons SET " .. table.concat(updatesSQLParts, ", ") .. " WHERE account_id = ?"
    local successUpdate, errMsgUpdate = exports.datenbank:executeDatabase(queryString, unpack(paramsSQL)) --

    if not successUpdate then
        outputDebugString("[Police] FEHLER beim Aktualisieren der Dienstwaffen in SQL für " .. getPlayerName(player) .. ": " .. (errMsgUpdate or "Unbekannt")) --
    end
    return successUpdate
end
_G.savePoliceDutyWeaponsToSQL = savePoliceDutyWeaponsToSQL --

function setPlayerPoliceDutyStatus(player, onDuty)
    if not isElement(player) then return false, "Invalid player element" end
    local accountID = getElementData(player, "account_id") --
    if not accountID then return false, "No account_id" end

    local success, errMsg = exports.datenbank:executeDatabase("UPDATE fraction_members SET on_duty = ? WHERE account_id = ? AND fraction_id = ?", (onDuty and 1 or 0), accountID, POLICE_FRACTION_ID) --

    if success then
        setElementData(player, "policeImDienst", onDuty) --
        local _, rank = getPlayerFractionAndRank(player) --

        if onDuty then
            local policeSkin = getPoliceSkinByRank(rank) --
            setElementModel(player, policeSkin)
            if type(_G.updateFractionSkinInDB) == "function" then
                _G.updateFractionSkinInDB(accountID, POLICE_FRACTION_ID, rank) --
            end
        else
            takeAllWeapons(player)
            savePoliceDutyWeaponsToSQL(player) --

            local standardSkinResult, skinErrMsg = exports.datenbank:queryDatabase("SELECT standard_skin FROM account WHERE id=? LIMIT 1", accountID) --
            local standardSkin = _G.DEFAULT_CIVIL_SKIN or 0 --
            if not standardSkinResult then
                 outputDebugString("[Police] DB Fehler beim Laden des Standard-Skins für AccID " .. accountID .. " beim Off-Duty: " .. (skinErrMsg or "Unbekannt")) --
            elseif standardSkinResult and standardSkinResult[1] and tonumber(standardSkinResult[1].standard_skin) then
                standardSkin = tonumber(standardSkinResult[1].standard_skin)
            end
            setElementModel(player, standardSkin)
            if type(_G.updateFractionSkinInDB) == "function" then
                 _G.updateFractionSkinInDB(accountID, 0, 1) --
            end
        end
        if type(_G.refreshPlayerFractionData) == "function" then _G.refreshPlayerFractionData(player) end --
        return true, "Success"
    else
        outputDebugString("[Police] DB Fehler beim Setzen des Duty-Status für AccID " .. accountID .. ": " .. (errMsg or "Unbekannt")) --
        return false, "Database error updating duty status"
    end
end

function clearPlayerPoliceWeaponsAndDutyWhenKickedOrFactionChanged(player)
    if not isElement(player) then return false end
    local accountID = getElementData(player, "account_id") --
    if not accountID then return false end

    takeAllWeapons(player)

    local resetFields = {}
    for i = 1, 9 do table.insert(resetFields, string.format("weapon_slot%d = NULL, ammo_slot%d = 0", i, i)) end
    local resetQuery = "UPDATE weapons SET " .. table.concat(resetFields, ", ") .. " WHERE account_id = ?"
    local successQuery, errMsgQuery = exports.datenbank:executeDatabase(resetQuery, accountID) --

    if not successQuery then
        outputDebugString("[PoliceClear] FEHLER beim Leeren der Waffen-Slots in SQL für AccID " .. accountID .. ": " .. (errMsgQuery or "Unbekannt")) --
    end

    if getElementData(player, "policeImDienst") == true then --
        setElementData(player, "policeImDienst", false) --
    end
    return successQuery
end
_G.clearPlayerPoliceWeaponsAndDutyWhenKickedOrFactionChanged = clearPlayerPoliceWeaponsAndDutyWhenKickedOrFactionChanged --


addCommandHandler("police", function(player)
    local now = getTickCount()
    local last = lastUsage[player] or 0
    if now - last < COOLDOWN_MS then
        outputChatBox("Bitte warte ein paar Sekunden...", player, 255, 0, 0)
        return
    end
    lastUsage[player] = now
    local fid, rank = getPlayerFractionAndRank(player) --
    if fid ~= POLICE_FRACTION_ID or rank < 1 then
        outputChatBox("❌ Du bist kein Polizist!", player, 255, 0, 0)
        return
    end
    triggerClientEvent(player, "openPoliceManagement", player, rank) --
end)

addEvent("spawnPoliceOfficer", true) --
addEventHandler("spawnPoliceOfficer", root, function() --
    local player = source
    local allowedToSpawn, messageSpawn = exports.tarox:canPlayerUseFactionSpawnCommand(player) --
    if not allowedToSpawn then
        outputChatBox(messageSpawn, player, 255, 100, 0)
        return
    end
    local fid, rank = getPlayerFractionAndRank(player) --
    if fid ~= POLICE_FRACTION_ID or rank < 1 then return end

    local dutySuccess, dutyMsg = setPlayerPoliceDutyStatus(player, true)
    if dutySuccess then
        spawnPlayer(player, POLICE_SPAWN_POS.x, POLICE_SPAWN_POS.y, POLICE_SPAWN_POS.z, POLICE_SPAWN_POS.rot, getElementModel(player), 0, 0)
        fadeCamera(player, true)
        setCameraTarget(player, player)
        givePoliceDutyWeapons(player, nil) --
        outputChatBox("Dienst als Police Officer (Rang "..rank..") angetreten!", player, 0, 200, 220)
    else
        outputChatBox("Fehler beim Dienstantritt: " .. (dutyMsg or "Unbekannt"), player, 255,0,0)
    end
end)

addEvent("onPoliceRequestOffDuty", true) --
addEventHandler("onPoliceRequestOffDuty", root, function() --
    local player = source
    local fid, _ = getPlayerFractionAndRank(player) --
    if fid ~= POLICE_FRACTION_ID then return end

    if getElementData(player, "policeImDienst") == false then --
        outputChatBox("Du bist bereits außer Dienst.", player, 255, 165, 0)
        return
    end

    local dutySuccess, dutyMsg = setPlayerPoliceDutyStatus(player, false)
    if dutySuccess then
        fadeCamera(player, true)
        setCameraTarget(player, player)
        outputChatBox("Polizeidienst verlassen. Du bleibst an deiner aktuellen Position.", player, 0, 200, 220)
    else
        outputChatBox("Fehler beim Verlassen des Dienstes: " .. (dutyMsg or "Unbekannt"), player, 255, 0, 0)
    end
end)

local policeVehicles = {}
local baseX, baseY, baseZ = -1573.86670, 705.46344, -5.61899 --
local vehicleSpacing = 5 --
local vehicleModel = 597 --
local rotationZ = 90 --

local rangerSpawns = { --
    {model=599, x=-1580.11304,y=749.83942,z=-5.24219, rotZ=180, minRank=2},
    {model=599, x=-1584.29358,y=749.56305,z=-5.24219, rotZ=180, minRank=2}
}
local infernusSpawns = { --
    {model=INFERNUS_MODEL_ID, x=-1573.18848,y=725.91132,z=-5.72388, rotZ=90, minRank=3},
    {model=INFERNUS_MODEL_ID, x=-1573.23474,y=730.17255,z=-5.72324, rotZ=90, minRank=3}
}
local hunterSpawns = { --
    {model=425, x=-1682.30005,y=706,z=31.5, rotZ=90, minRank=4}
}

local allowedRanks_Cars     = {1,2,3,4,5} --
local allowedRanks_Rangers  = {2,3,4,5} --
local allowedRanks_Infernus = {3,4,5} --
local allowedRanks_Hunter   = {4,5} --

function addPoliceLights(vehicle)
    if isElement(vehicle) then setVehicleSirensOn(vehicle, true) end --
end

function respawnPoliceVehicle(vehicle)
     if not isElement(vehicle) then return end
     local data = policeVehicles[vehicle]
     if data then
        destroyElement(vehicle)
        policeVehicles[vehicle] = nil
        local newVeh = createVehicle(data.model, data.x, data.y, data.z, 0, 0, data.rotZ)
        if isElement(newVeh) then
            setElementData(newVeh, "policeVehicle", true) --
            setElementData(newVeh, "allowedRanks", data.allowedRanks) --
            setElementData(newVeh, "minRank", data.minRank or (data.allowedRanks and data.allowedRanks[1]) or 1) --
            setVehicleColor(newVeh, 0, 0, 0) --
            addPoliceLights(newVeh) --
            applyPoliceVehicleSpecificHandling(newVeh)
            policeVehicles[newVeh] = data
        else
             outputDebugString("[Police] FEHLER: Konnte Fahrzeug nicht respawnen, Model: "..tostring(data.model), 2) --
        end
    end
end

function checkVehicleIdle()
    if type(policeVehicles) ~= "table" then return end
    local vehiclesToRespawn = {}
    for veh, data in pairs(policeVehicles) do
        if not isElement(veh) then
             table.insert(vehiclesToRespawn, {action = "remove_invalid", key = veh})
        elseif not getVehicleOccupant(veh) then
            local lastUsed = getElementData(veh, "lastUsedTime") or 0 --
            if getTickCount() - lastUsed > 120000 then
                if data and data.model then
                    table.insert(vehiclesToRespawn, {action = "respawn", vehicle = veh})
                else
                    table.insert(vehiclesToRespawn, {action = "remove_invalid", key = veh})
                end
            end
        end
    end
    if #vehiclesToRespawn > 0 then
        for _, actionData in ipairs(vehiclesToRespawn) do
            if actionData.action == "respawn" then
                if isElement(actionData.vehicle) then respawnPoliceVehicle(actionData.vehicle) end
            elseif actionData.action == "remove_invalid" then
                if policeVehicles[actionData.key] then policeVehicles[actionData.key] = nil end
            end
        end
    end
end
setTimer(checkVehicleIdle, 60000, 0) --

addEventHandler("onVehicleExplode", root, function()
    if not isElement(source) then return end
    if getElementData(source, "policeVehicle") then --
        setTimer(respawnPoliceVehicle, 5000, 1, source) --
    end
end)

addEventHandler("onVehicleEnter", root, function(player, seat)
    if getElementData(source, "policeVehicle") then --
        if isElement(player) and getElementType(player) == "player" then
             setElementData(source, "lastUsedTime", getTickCount()) --
        end
    end
end)

function spawnPoliceCars()
    for i=0,3 do
        local y = baseY + (i * vehicleSpacing)
        local v = createVehicle(vehicleModel, baseX, y, baseZ, 0, 0, rotationZ)
        if isElement(v) then
            setElementData(v, "policeVehicle", true); setElementData(v, "allowedRanks", allowedRanks_Cars) --
            setElementData(v, "minRank", allowedRanks_Cars[1]) --
            setVehicleColor(v, 0, 0, 0); addPoliceLights(v) --
            policeVehicles[v] = { x=baseX, y=y, z=baseZ, rotZ=rotationZ, model=vehicleModel, allowedRanks = allowedRanks_Cars, minRank = allowedRanks_Cars[1] } --
        end
    end
end

function spawnPoliceRangers()
    for _, sp in ipairs(rangerSpawns) do
        local v = createVehicle(sp.model, sp.x, sp.y, sp.z, 0, 0, sp.rotZ)
         if isElement(v) then
            setElementData(v, "policeVehicle", true); setElementData(v, "allowedRanks", allowedRanks_Rangers) --
            setElementData(v, "minRank", sp.minRank or allowedRanks_Rangers[1]) --
            setVehicleColor(v, 0, 0, 0); addPoliceLights(v) --
            policeVehicles[v] = { x=sp.x, y=sp.y, z=sp.z, rotZ=sp.rotZ, model=sp.model, allowedRanks = allowedRanks_Rangers, minRank = sp.minRank or allowedRanks_Rangers[1] } --
        end
    end
end

function spawnInfernusVehicles()
    for _, sp in ipairs(infernusSpawns) do
        local v = createVehicle(sp.model, sp.x, sp.y, sp.z, 0, 0, sp.rotZ)
        if isElement(v) then
            setElementData(v, "policeVehicle", true); setElementData(v, "allowedRanks", allowedRanks_Infernus) --
            setElementData(v, "minRank", sp.minRank or allowedRanks_Infernus[1]) --
            setVehicleColor(v, 0, 0, 0); addPoliceLights(v) --
            applyPoliceVehicleSpecificHandling(v)
            policeVehicles[v] = { x=sp.x, y=sp.y, z=sp.z, rotZ=sp.rotZ, model=sp.model, allowedRanks = allowedRanks_Infernus, minRank = sp.minRank or allowedRanks_Infernus[1] } --
        end
    end
end

function spawnHunterVehicles()
    for _, sp in ipairs(hunterSpawns) do
        local v = createVehicle(sp.model, sp.x, sp.y, sp.z, 0, 0, sp.rotZ)
         if isElement(v) then
            setElementData(v, "policeVehicle", true); setElementData(v, "allowedRanks", allowedRanks_Hunter) --
            setElementData(v, "minRank", sp.minRank or allowedRanks_Hunter[1]) --
            setVehicleColor(v, 0, 0, 0) --
            policeVehicles[v] = { x=sp.x, y=sp.y, z=sp.z, rotZ=sp.rotZ, model=sp.model, allowedRanks = allowedRanks_Hunter, minRank = sp.minRank or allowedRanks_Hunter[1] } --
        end
    end
end

if not table.HasValue then --
    function table.HasValue ( tbl, value ) --
        if type(tbl) ~= "table" then return false end --
        for _, v in ipairs(tbl) do --
            if v == value then return true end --
        end --
        return false --
    end --
end --

addEventHandler("onVehicleStartEnter", root, function(player, seat)
    if getElementData(source, "policeVehicle") and isElement(player) and getElementType(player) == "player" then --
        if not getPlayerFractionAndRank then outputDebugString("[Police] FEHLER: getPlayerFractionAndRank nicht gefunden für VehicleEnter Check!"); return end --
        local fid, rank = getPlayerFractionAndRank(player) --

        local isOnPoliceDuty = getElementData(player, "policeImDienst") or false --
        if not isOnPoliceDuty then
            cancelEvent()
            outputChatBox("❌ Du musst im Dienst sein, um dieses Polizeifahrzeug zu benutzen!", player, 255, 0, 0) --
            return
        end

        if fid ~= POLICE_FRACTION_ID then
            cancelEvent()
            outputChatBox("❌ Nur für Polizei-Mitglieder!", player, 255, 0, 0) --
            return
        end

        local allowedRanksList = getElementData(source, "allowedRanks") or {} --
        local minRankRequiredByModel = getElementData(source, "minRank") --

        local isAllowed = false
        if minRankRequiredByModel and rank and rank >= minRankRequiredByModel then
            isAllowed = true
        elseif table.HasValue(allowedRanksList, rank) then --
            isAllowed = true
        end

        if not isAllowed then
            cancelEvent()
            local requiredRankText = "einen bestimmten Rang" --
            if minRankRequiredByModel then
                requiredRankText = "mindestens Rang " .. minRankRequiredByModel --
            elseif allowedRanksList and #allowedRanksList > 0 then
                requiredRankText = "einen der Ränge (" .. table.concat(allowedRanksList, "/") .. ")" --
            end
            outputChatBox("❌ Du hast nicht "..requiredRankText.." um dieses Fahrzeug zu benutzen!", player, 255, 0, 0) --
        end
    end
end)

addEventHandler("onResourceStart", resourceRoot, function()
    spawnPoliceCars() --
    spawnPoliceRangers() --
    spawnInfernusVehicles() --
    spawnHunterVehicles() --

    for _, player in ipairs(getElementsByType("player")) do
        if getElementData(player, "account_id") then --
            local fid, rank = getPlayerFractionAndRank(player) --
            if fid == POLICE_FRACTION_ID then
                local accID = getElementData(player, "account_id") --
                local dutyResult, errMsgDuty = exports.datenbank:queryDatabase("SELECT on_duty FROM fraction_members WHERE account_id = ? AND fraction_id = ? LIMIT 1", accID, POLICE_FRACTION_ID) --
                local isOnDutyDB = false
                if dutyResult and dutyResult[1] and tonumber(dutyResult[1].on_duty) == 1 then
                    isOnDutyDB = true
                elseif not dutyResult then
                     outputDebugString("[Police] onResourceStart: DB Fehler beim Laden des Duty-Status für AccID " .. accID .. ": " .. (errMsgDuty or "Unbekannt")) --
                end
                setElementData(player, "policeImDienst", isOnDutyDB) --
            end
        end
    end
    --outputDebugString("[Police] Polizei-Skript (Server - V8.2 Polizei Infernus Handling, ohne spezifischen Infernus Speed Log) geladen.") --
end)

addEventHandler("onPlayerDamage", root, function(attacker, weapon, bodypart, loss)
    if not attacker or getElementType(attacker) ~= "player" then return end
    if weapon ~= 3 or loss <= 0 then return end
    local attackerFid, attackerRank = 0, 0
    if getPlayerFractionAndRank then attackerFid, attackerRank = getPlayerFractionAndRank(attacker) else return end --
    if attackerFid ~= POLICE_FRACTION_ID and attackerFid ~= 2 then return end
    local victim_element = source
    if not isElement(victim_element) or getElementType(victim_element) ~= "player" then return end
    local victimAccountID = getElementData(victim_element, "account_id") --
    if not victimAccountID then return end
    if getElementHealth(victim_element) <= 0 then return end
    local victimFid, victimRank = 0, 0
    if getPlayerFractionAndRank then victimFid, victimRank = getPlayerFractionAndRank(victim_element) end --
    if victimFid == POLICE_FRACTION_ID or victimFid == 2 or victimFid == 3 then return end
    local victimWanted = getElementData(victim_element, "wanted") or 0 --
    if victimWanted <= 0 then outputChatBox("This person is not wanted.", attacker, 255, 165, 0); return end

    if exports.tarox and exports.tarox.arrestPlayer then --
        local idToPass = tonumber(victimAccountID)
        if not idToPass then
             outputChatBox("Interner Fehler beim Verhaften (ID-Problem).", attacker, 255, 0, 0)
        else
            local success, arrestMsg = exports.tarox:arrestPlayer(idToPass) --
            if success then outputChatBox("Du hast erfolgreich jemanden verhaftet!", attacker, 0, 255, 0)
            else outputChatBox("Fehler beim Verhaften: " .. (arrestMsg or "Unbekannt"), attacker, 255, 0, 0) end
        end
    else
        outputDebugString("[Police] FEHLER: Funktion 'arrestPlayer' nicht in exports.tarox gefunden!") --
        outputChatBox("Jail system error!", attacker, 255,0,0)
    end
end)

addEvent("requestWantedPlayers", true) --
addEventHandler("requestWantedPlayers", root, function() --
    local requester = client; if not isElement(requester) then return end
    local requesterFid, _ = 0,0; if getPlayerFractionAndRank then requesterFid, _ = getPlayerFractionAndRank(requester) else return end --
    if requesterFid ~= POLICE_FRACTION_ID and requesterFid ~= 2 then outputChatBox("Keine Berechtigung.", requester, 255, 100, 0); return end
    local wantedList = {}
    for _, player in ipairs(getElementsByType("player")) do if isElement(player) then local wl = getElementData(player, "wanted") or 0; if wl > 0 then table.insert(wantedList, {player = player, name = getPlayerName(player), wanted = wl}) end end end --
    triggerClientEvent(requester, "receiveWantedPlayers", requester, wantedList) --
end)

addEvent("requestPlayerLocation", true) --
addEventHandler("requestPlayerLocation", root, function(targetPlayer) --
    local requester = client; if not isElement(requester) or not isElement(targetPlayer) then if isElement(requester) then outputChatBox("Fehler: Zielspieler ungültig.", requester, 255,0,0) end; return end
    local requesterFid, _ = 0,0; if getPlayerFractionAndRank then requesterFid, _ = getPlayerFractionAndRank(requester) else return end --
    if requesterFid ~= POLICE_FRACTION_ID and requesterFid ~= 2 then outputChatBox("Keine Berechtigung.", requester, 255, 100, 0); return end
    local targetWanted = getElementData(targetPlayer, "wanted") or 0 --
    if targetWanted <= 0 then outputChatBox(getPlayerName(targetPlayer) .. " wird nicht mehr gesucht.", requester, 255, 165, 0); return end
    triggerClientEvent(requester, "showTargetBlip", requester, targetPlayer, 30000); outputChatBox("Ortung für " .. getPlayerName(targetPlayer) .. " gestartet (30s).", requester, 0, 200, 255) --
end)

addEventHandler("onPlayerLoginSuccess", root, function()
    local player = source
    local accID = getElementData(player, "account_id") --
    if not accID then return end

    local fid, rank = getPlayerFractionAndRank(player) --
    if fid == POLICE_FRACTION_ID then
        local dutyResult, errMsg = exports.datenbank:queryDatabase("SELECT on_duty FROM fraction_members WHERE account_id = ? AND fraction_id = ? LIMIT 1", accID, POLICE_FRACTION_ID) --
        local isOnDutyDB = false
        if not dutyResult then
            --outputDebugString("[Police] onPlayerLoginSuccess: DB Fehler beim Laden des Duty-Status für AccID " .. accID .. ": " .. (errMsg or "Unbekannt")) --
        elseif dutyResult and dutyResult[1] and tonumber(dutyResult[1].on_duty) == 1 then
            isOnDutyDB = true
        end
        setElementData(player, "policeImDienst", isOnDutyDB) --

        if isOnDutyDB then
             local policeSkin = getPoliceSkinByRank(rank) --
             setElementModel(player, policeSkin)
        end
    end
end)