-- tarox/vehicles/vehicles_server.lua
-- VERSION 1.33: Handling-Eigenschaften EINZELN setzen via setVehicleHandling(vehicle, property, value)

local NITRO_UPGRADE_IDS_SPAWN = { [1]=1010, [2]=1009, [3]=1008 }

-- ### Handling-Hilfsfunktionen (Bleiben wie in V1.32) ###
local function getNumericValue_vehicles(val)
    if type(val) == "number" then return val end
    if type(val) == "string" then
        local num = tonumber(val)
        if num ~= nil then return num end
    end
    return nil
end

local function isVectorTable_vehicles(tbl)
    if type(tbl) ~= "table" then return false end
    if getNumericValue_vehicles(tbl.x) ~= nil and getNumericValue_vehicles(tbl.y) ~= nil and getNumericValue_vehicles(tbl.z) ~= nil then
        return true
    end
    if getNumericValue_vehicles(tbl[1]) ~= nil and getNumericValue_vehicles(tbl[2]) ~= nil and getNumericValue_vehicles(tbl[3]) ~= nil then
        return true
    end
    return false
end

local function createCleanVector_vehicles(originalVector, defaultX, defaultY, defaultZ)
    local defaultVec = { x = defaultX or 0, y = defaultY or 0, z = defaultZ or 0 }
    if type(originalVector) ~= "table" then return defaultVec end
    if isVectorTable_vehicles(originalVector) then
        local x_val, y_val, z_val
        if getNumericValue_vehicles(originalVector.x) ~= nil and getNumericValue_vehicles(originalVector.y) ~= nil and getNumericValue_vehicles(originalVector.z) ~= nil then
            x_val = getNumericValue_vehicles(originalVector.x); y_val = getNumericValue_vehicles(originalVector.y); z_val = getNumericValue_vehicles(originalVector.z)
        elseif getNumericValue_vehicles(originalVector[1]) ~= nil and getNumericValue_vehicles(originalVector[2]) ~= nil and getNumericValue_vehicles(originalVector[3]) ~= nil then
            x_val = getNumericValue_vehicles(originalVector[1]); y_val = getNumericValue_vehicles(originalVector[2]); z_val = getNumericValue_vehicles(originalVector[3])
        end
        if x_val ~= nil and y_val ~= nil and z_val ~= nil then return { x = x_val, y = y_val, z = z_val } end
    end
    return defaultVec
end

local typeConverters_vehicles = {
    engineType = function(val, default)
        if type(val) == "string" then local s = string.lower(val); if s == "petrol" then return 0 elseif s == "diesel" then return 1 elseif s == "electric" then return 2 end end
        local num_val = getNumericValue_vehicles(val); if num_val ~= nil and (num_val >= 0 and num_val <= 2) then return num_val end
        return default 
    end,
    driveType = function(val, default)
        if type(val) == "string" then local s = string.lower(val); if s == "fwd" then return 0 elseif s == "rwd" then return 1 elseif s == "awd" or s == "4wd" then return 2 end end
        local num_val = getNumericValue_vehicles(val); if num_val ~= nil and (num_val >= 0 and num_val <= 2) then return num_val end
        return default
    end,
    headLightType = function(val, default)
        if type(val) == "string" then local s = string.lower(val); if s == "small" then return 0 elseif s == "long" then return 1 elseif s == "big" then return 2 elseif s == "tall" then return 3 end end
        local num_val = getNumericValue_vehicles(val); if num_val ~= nil and (num_val >= 0 and num_val <= 3) then return num_val end
        return default or 0
    end,
    tailLightType = function(val, default)
        if type(val) == "string" then local s = string.lower(val); if s == "small" then return 0 elseif s == "long" then return 1 elseif s == "big" then return 2 elseif s == "tall" then return 3 end end
        local num_val = getNumericValue_vehicles(val); if num_val ~= nil and (num_val >= 0 and num_val <= 3) then return num_val end
        return default or 0
    end,
    ABS = function(val, default)
        if type(val) == "boolean" then return val end
        if type(val) == "string" then local s = string.lower(val); if s == "true" then return true elseif s == "false" then return false end end
        local num_val = getNumericValue_vehicles(val); if num_val ~= nil and (num_val == 0 or num_val == 1) then return num_val == 1 end
        return default or false
    end
}
-- ### ENDE Handling-Hilfsfunktionen ###

function getModifiedHandlingForSpawn(theVehicle, engineLevel)
    -- Diese Funktion erstellt weiterhin die Zieltabelle, wie in V1.32
    if not isElement(theVehicle) or getElementType(theVehicle) ~= "vehicle" then
        outputDebugString("[VehiclesServer|getModifiedHandlingForSpawn] Fehler: 'theVehicle' ist kein valides Fahrzeug-Element.")
        return false
    end
    if not engineLevel or type(engineLevel) ~= "number" or engineLevel < 0 or engineLevel > 3 then
        outputDebugString("[VehiclesServer|getModifiedHandlingForSpawn] Fehler: Ungültiger 'engineLevel'.")
        return false
    end

    local vehicleModelID = getElementModel(theVehicle)
    local success, originalHandling_raw = pcall(getOriginalHandling, vehicleModelID)

    if not success or type(originalHandling_raw) ~= "table" then
        outputDebugString(string.format("[VehiclesServer|getModifiedHandlingForSpawn] pcall(getOriginalHandling) für Modell %d FEHLGESCHLAGEN. Fehler/Typ: %s", vehicleModelID, tostring(originalHandling_raw)))
        return false
    end

    local oh = originalHandling_raw
    local finalHandling = {}
    local transData = oh.transmissionData or oh 

    finalHandling.mass = getNumericValue_vehicles(oh.mass) or 1700.0
    finalHandling.turnMass = getNumericValue_vehicles(oh.turnMass) or 5000.0
    finalHandling.dragCoeff = getNumericValue_vehicles(oh.dragCoeff) or 2.5
    finalHandling.centerOfMass = createCleanVector_vehicles(oh.centerOfMass or oh.vecCentreOfMass, 0, 0, -0.1)
    finalHandling.percentSubmerged = getNumericValue_vehicles(oh.percentSubmerged) or 85
    finalHandling.tractionMultiplier = getNumericValue_vehicles(oh.tractionMultiplier) or 0.75
    finalHandling.tractionLoss = getNumericValue_vehicles(oh.tractionLoss) or 0.85
    finalHandling.tractionBias = getNumericValue_vehicles(oh.tractionBias or oh.driveBias) or 0.5
    
    finalHandling.numberOfGears = getNumericValue_vehicles(transData.maxGear or transData.numberOfGears) or 4
    finalHandling.maxVelocity = getNumericValue_vehicles(transData.maxVelocity) or 200.0
    finalHandling.engineAcceleration = getNumericValue_vehicles(transData.engineAcceleration) or 10.0
    finalHandling.engineInertia = getNumericValue_vehicles(oh.engineInertia or (transData and transData.engineInertia)) or 5.0

    finalHandling.driveType = typeConverters_vehicles.driveType(oh.driveType or (transData and transData.driveType), 1) 
    finalHandling.engineType = typeConverters_vehicles.engineType(oh.engineType or (transData and transData.engineType), 0)

    finalHandling.brakeDeceleration = getNumericValue_vehicles(oh.brakeDeceleration) or 10.0
    finalHandling.brakeBias = getNumericValue_vehicles(oh.brakeBias) or 0.5
    finalHandling.ABS = typeConverters_vehicles.ABS(oh.ABS, (oh.ABS ~= nil and typeConverters_vehicles.ABS(oh.ABS)) or false)
    finalHandling.steeringLock = getNumericValue_vehicles(oh.steeringLock) or 35.0

    finalHandling.suspensionForceLevel = getNumericValue_vehicles(oh.suspensionForceLevel) or 1.0
    finalHandling.suspensionDampingLevel = getNumericValue_vehicles(oh.suspensionDampingLevel or oh.suspensionDamping) or 0.1
    finalHandling.suspensionHighSpeedDamping = getNumericValue_vehicles(oh.suspensionHighSpeedDamping) or 0.0
    finalHandling.suspensionUpperLimit = getNumericValue_vehicles(oh.suspensionUpperLimit) or 0.35
    finalHandling.suspensionLowerLimit = getNumericValue_vehicles(oh.suspensionLowerLimit) or -0.15
    finalHandling.suspensionBiasBetweenFrontAndRear = getNumericValue_vehicles(oh.suspensionBiasBetweenFrontAndRear or oh.suspensionFrontRearBias) or 0.5
    finalHandling.suspensionAntiDiveMultiplier = getNumericValue_vehicles(oh.suspensionAntiDiveMultiplier) or 0.3
    
    finalHandling.seatOffsetDistance = getNumericValue_vehicles(oh.seatOffsetDistance) or 0.0
    finalHandling.collisionDamageMultiplier = getNumericValue_vehicles(oh.collisionDamageMultiplier) or 1.0
    
    finalHandling.modelFlags = (type(oh.modelFlags) == "string" and string.sub(oh.modelFlags, 1, 2) == "0x" and tonumber(oh.modelFlags, 16)) or getNumericValue_vehicles(oh.modelFlags) or 0
    finalHandling.handlingFlags = (type(oh.handlingFlags) == "string" and string.sub(oh.handlingFlags, 1, 2) == "0x" and tonumber(oh.handlingFlags, 16)) or getNumericValue_vehicles(oh.handlingFlags) or 0

    finalHandling.headLightType = typeConverters_vehicles.headLightType(oh.headLight or oh.headLightType, (oh.headLight and typeConverters_vehicles.headLightType(oh.headLight)) or 0)
    finalHandling.tailLightType = typeConverters_vehicles.tailLightType(oh.tailLight or oh.tailLightType, (oh.tailLight and typeConverters_vehicles.tailLightType(oh.tailLight)) or 0)

    finalHandling.inertiaTensor = createCleanVector_vehicles(oh.inertiaTensor or oh.vecInertia, 0.1, 0.1, 0.1)

    local baseDriveForce = getNumericValue_vehicles(oh.driveForce)
    if not baseDriveForce or baseDriveForce <= 0.001 then
        baseDriveForce = (vehicleModelID == 451 and 0.30) or (vehicleModelID == 411 and 0.35) or (vehicleModelID == 560 and 0.25) or 0.20
    end
    finalHandling.driveForce = baseDriveForce

    if engineLevel > 0 then
        local velocityMultiplier, accelerationMultiplier, driveForceMultiplier = 1.0, 1.0, 1.0
        if engineLevel == 1 then
            velocityMultiplier = 1.10; accelerationMultiplier = 1.10; driveForceMultiplier = 1.05 
        elseif engineLevel == 2 then
            velocityMultiplier = 1.20; accelerationMultiplier = 1.20; driveForceMultiplier = 1.10
        elseif engineLevel == 3 then
            velocityMultiplier = 1.30; accelerationMultiplier = 1.30; driveForceMultiplier = 1.15
        end
        
        finalHandling.maxVelocity = (getNumericValue_vehicles(transData.maxVelocity) or 200.0) * velocityMultiplier
        finalHandling.engineAcceleration = (getNumericValue_vehicles(transData.engineAcceleration) or 10.0) * accelerationMultiplier
        finalHandling.driveForce = baseDriveForce * driveForceMultiplier
    end
    
    -- outputDebugString("[VehiclesServer DEBUG V1.33] Finales Handling für Modell "..vehicleModelID..", Level "..engineLevel..": " .. inspect(finalHandling))
    return finalHandling
end

function applyUpgradesOnSpawn(theVehicle)
    if not isElement(theVehicle) or getElementType(theVehicle) ~= "vehicle" then
        outputDebugString("[VehiclesServer|applyUpgradesOnSpawn] Fehler: 'theVehicle' ist kein valides Fahrzeug-Element.")
        return
    end
    local vehicleDBID = getElementData(theVehicle, "id")
    if not vehicleDBID then
        outputDebugString("[VehiclesServer|applyUpgradesOnSpawn] Fahrzeug ID " .. tostring(vehicleDBID) .. " hat keine DB-ID für Tuning-Abfrage.")
        -- Kein setVehicleHandling hier, da wir kein modifiziertes Handling haben
        return
    end

    local tuneDataResult, errMsg = exports.datenbank:queryDatabase("SELECT tune1, tune2, tune3, tune4, tune5, tune6, tune7, tune8, tune9, tune10 FROM vehicles WHERE id = ?", vehicleDBID)
    if not tuneDataResult then
        outputDebugString("[applyUpgradesOnSpawn] DB-Fehler beim Laden der Tuning-Daten für ID " .. vehicleDBID .. ": " .. (errMsg or "Unbekannt"))
        return
    end
    if not tuneDataResult[1] then
        outputDebugString("[applyUpgradesOnSpawn] Keine Tuning-Daten in DB für Fahrzeug ID " .. vehicleDBID .. ". Original-Handling wird verwendet.")
        -- Wichtig: Hier das Fahrzeug auf sein Original-Handling zurücksetzen, falls es zuvor modifiziert war
        setVehicleHandling(theVehicle, false) -- Setzt auf Model-Handling zurück
        return
    end

    local data = tuneDataResult[1]
    local engineTuneLevel = 0
    if data.tune1 and tonumber(data.tune1) and tonumber(data.tune1) >= 0 and tonumber(data.tune1) <= 3 then -- >= 0 erlaubt Level 0 (Original)
        engineTuneLevel = tonumber(data.tune1)
    end

    local modifiedHandlingTable = getModifiedHandlingForSpawn(theVehicle, engineTuneLevel)
    
    if modifiedHandlingTable then
        local allPropertiesSetSuccessfully = true
        local failedProperties = {}

        -- Setze jede Eigenschaft einzeln
        for property, value in pairs(modifiedHandlingTable) do
            local success_prop_set = setVehicleHandling(theVehicle, property, value)
            if not success_prop_set then
                allPropertiesSetSuccessfully = false
                table.insert(failedProperties, property .. " (Wert: " .. tostring(value) .. ")")
            end
        end

        if allPropertiesSetSuccessfully then
            --outputDebugString(string.format("[applyUpgradesOnSpawn] Alle Handling-Eigenschaften für Lvl %d, Fahrzeug ID %s (Modell: %d) ERFOLGREICH einzeln gesetzt.", engineTuneLevel, tostring(vehicleDBID), getElementModel(theVehicle)))
        else
            outputDebugString(string.format("[applyUpgradesOnSpawn] FEHLER beim einzelnen Setzen einiger Handling-Eigenschaften für Lvl %d, Fahrzeug ID %s (Modell: %d).", engineTuneLevel, tostring(vehicleDBID), getElementModel(theVehicle)))
            outputDebugString("Fehlgeschlagene Properties: " .. table.concat(failedProperties, ", "))
            local currentHandlingAfterFail = getVehicleHandling(theVehicle)
            outputDebugString("[applyUpgradesOnSpawn] Aktuelles Handling NACH partiellem Fehlversuch: "..inspect(currentHandlingAfterFail))
        end
    else
        outputDebugString(string.format("[applyUpgradesOnSpawn] Motor-Tuning Lvl %d für Fahrzeug ID %s konnte NICHT vorbereitet werden. Original-Handling wird verwendet.", engineTuneLevel, tostring(vehicleDBID)))
        setVehicleHandling(theVehicle, false) -- Setzt auf Model-Handling zurück
    end

    -- Nitro-Tuning (bleibt gleich)
    local currentNitroOnVehicle = getVehicleUpgradeOnSlot(theVehicle, 5)
    local targetNitroUpgradeID = nil
    if data.tune2 and tonumber(data.tune2) and tonumber(data.tune2) > 0 then
        targetNitroUpgradeID = NITRO_UPGRADE_IDS_SPAWN[tonumber(data.tune2)]
    end

    if targetNitroUpgradeID then
        if currentNitroOnVehicle ~= targetNitroUpgradeID then
            if currentNitroOnVehicle and currentNitroOnVehicle ~= 0 then removeVehicleUpgrade(theVehicle, currentNitroOnVehicle) end
            addVehicleUpgrade(theVehicle, targetNitroUpgradeID)
        end
    elseif currentNitroOnVehicle and currentNitroOnVehicle ~= 0 then
        removeVehicleUpgrade(theVehicle, currentNitroOnVehicle)
    end

    -- Felgen-Tuning (bleibt gleich)
    local dbWheelID = data.tune3 and tonumber(data.tune3)
    local currentWheelUpgrade = nil
    local vehicleUpgrades = getVehicleUpgrades(theVehicle)
    for _, upgradeID in ipairs(vehicleUpgrades) do
        if upgradeID >= 1073 and upgradeID <= 1098 then currentWheelUpgrade = upgradeID; break; end
    end

    if dbWheelID and dbWheelID >= 1073 and dbWheelID <= 1098 then
        if currentWheelUpgrade ~= dbWheelID then
            if currentWheelUpgrade then removeVehicleUpgrade(theVehicle, currentWheelUpgrade) end
            addVehicleUpgrade(theVehicle, dbWheelID)
        end
    elseif currentWheelUpgrade then
        removeVehicleUpgrade(theVehicle, currentWheelUpgrade)
    end

    -- Andere sichtbare Tuning-Teile (bleibt gleich)
    local dbUpgradesVisual = {}
    for i = 4, 10 do
        local tuneValue = data["tune"..i]
        if tuneValue and tonumber(tuneValue) and tonumber(tuneValue) > 999 then
            dbUpgradesVisual[tonumber(tuneValue)] = true
        end
    end

    currentUpgradesOnVehicle = getVehicleUpgrades(theVehicle)
    for _, installedUpgradeID in ipairs(currentUpgradesOnVehicle) do
        local isNitro = false; for _, nid in pairs(NITRO_UPGRADE_IDS_SPAWN) do if installedUpgradeID == nid then isNitro = true; break; end end
        local isWheel = (installedUpgradeID >= 1073 and installedUpgradeID <= 1098)
        if not dbUpgradesVisual[installedUpgradeID] and not isNitro and not isWheel then
            removeVehicleUpgrade(theVehicle, installedUpgradeID)
        end
    end
    for dbUpgradeID, _ in pairs(dbUpgradesVisual) do
        local alreadyOn = false
        for _, installedUpgradeID_check in ipairs(currentUpgradesOnVehicle) do
            if dbUpgradeID == installedUpgradeID_check then alreadyOn = true; break; end
        end
        if not alreadyOn then
            addVehicleUpgrade(theVehicle, dbUpgradeID)
        end
    end
end


------------------------------------------------
-- TEIL 1: FUEL-SERVER DEFINITIONEN
------------------------------------------------
local fuelStations = {
    {x = -2406.44067, y = 976.44055, z = 45.29688},
    {x = -2021.53748, y = 158.37646, z = 28.69496},
    {x = -1677.62170, y = 411.71838, z = 7.17969},
    {x = 2639.37402, y = 1106.62402, z = 10.82031},
}
local fuelMarkers = {}

------------------------------------------------
-- TEIL 2: SHOP-SERVER DEFINITIONEN
------------------------------------------------
local vehiclesForSale = {
    {model = 411, price = 100000},
    {model = 451, price = 120000},
    {model = 400, price = 80000},
    {model = 402, price = 90000},
}

------------------------------------------------
-- TEIL 3: SPAWN-SERVER DEFINITIONEN
------------------------------------------------
addEvent("onPlayerRequestVehicleSpawn", true)

local spawnMarkers = {
    { x = -2710.31299, y = 376.08527, z = 4.97273,   spawn = { x = -2707.03589, y = 397.30011, z = 4.36719, rot = 0 } },
    { x = -2412.31689, y = 950.10999, z = 45.29688,  spawn = { x = -2401.91699, y = 958.12177, z = 45.30162, rot = 270 } },
    { x = -1935.02173, y = 575.67462, z = 35.17188,  spawn = { x = -1930.0,     y = 580.0,     z = 35.2,    rot = 90 } },
    { x = -2035.12646, y = 174.76651, z = 28.83594,  spawn = { x = -2030.0,     y = 179.0,     z = 28.8,    rot = 180 } },
    { x = -2057.18970, y = -88.01767, z = 35.32031,  spawn = { x = -2060.0,     y = -85.0,     z = 35.0,    rot = 0 } },
    { x = -2266.85571, y = 158.26285, z = 35.31250,  spawn = { x = -2263.0,     y = 163.0,     z = 35.3,    rot = 0 } },
    { x = -2404.16406, y = 324.96268, z = 35.17188,  spawn = { x = -2400.0,     y = 330.0,     z = 35.1,    rot = 0 } },
    { x = -2199.40430, y = 306.03894, z = 35.11719,  spawn = { x = -2195.0,     y = 311.0,     z = 35.1,    rot = 0 } },
    { x = -2271.52075, y = 533.74780, z = 35.01562,  spawn = { x = -2268.0,     y = 538.0,     z = 35.0,    rot = 0 } },
    { x = -2190.72339, y = 1009.40668, z = 80.0,     spawn = { x = -2185.0,     y = 1014.0,    z = 80.0,    rot = 0 } },
    { x = -1895.63647, y = 1165.12512, z = 45.45274, spawn = { x = -1890.0,     y = 1170.0,    z = 45.4,    rot = 0 } },
    { x = -1633.51599, y = 1199.96838, z = 7.18750,  spawn = { x = -1629.0,     y = 1204.0,    z = 7.2,     rot = 220 } },
    { x = -1946.19189, y = 1332.03650, z = 7.18750,  spawn = { x = -1938.77307, y = 1313.50415,z = 6.41625, rot = 95 } },
    { x = -2635.12891, y = 1360.98169, z = 7.12294,  spawn = { x = -2631.0,     y = 1365.0,    z = 7.1,     rot = 0 } },
    { x = -2845.00317, y = 1001.12213, z = 41.94608, spawn = { x = -2840.0,     y = 1006.0,    z = 41.9,    rot = 0 } },
    { x = -2586.75879, y = 586.68079, z = 14.45312,  spawn = { x = -2582.0,     y = 591.0,     z = 14.4,    rot = 0 } },
    { x = -2418.80054, y = 730.94208, z = 35.17188,  spawn = { x = -2414.0,     y = 735.0,     z = 35.2,    rot = 0 } },
    { x = -1826.86182, y = 372.75009, z = 17.16406,  spawn = { x = -1819.68372, y = 369.37393, z = 16.71844, rot = 225 } },
    { x = -1529.62024, y = 707.78760, z = 7.18750,   spawn = { x = -1525.0,     y = 712.0,     z = 7.2,     rot = 0 } },
    { x = -1755.38416, y = 944.29816, z = 24.88281,  spawn = { x = -1751.0,     y = 949.0,     z = 24.8,    rot = 0 } },
    { x = -1981.41296, y = 883.49005, z = 45.20312,  spawn = { x = -1977.0,     y = 888.0,     z = 45.2,    rot = 0 } },
    { x = -2796.17651, y = 806.13947, z = 48.10721,  spawn = { x = -2791.0,     y = 811.0,     z = 48.1,    rot = 0 } },
    { x = -2649.92896, y = 32.01897,  z = 4.33594,   spawn = { x = -2645.0,     y = 37.0,      z = 4.3,     rot = 0 } },
    { x = -2752.30029, y = -311.00696,z = 7.03906,   spawn = { x = -2747.0,     y = -306.0,    z = 7.0,     rot = 0 } },
    { x = -2392.59009, y = -588.97278,z = 132.73846, spawn = { x = -2388.0,     y = -584.0,    z = 132.7,   rot = 0 } },
    { x = -2140.67432, y = -859.70044,z = 32.02344,  spawn = { x = -2136.0,     y = -854.0,    z = 32.0,    rot = 0 } },
    { x = -2150.67114, y = -406.47214,z = 35.33594,  spawn = { x = -2146.0,     y = -401.0,    z = 35.3,    rot = 0 } },
    { x = -1762.93726, y = -129.56950,z = 3.55469,   spawn = { x = -1758.0,     y = -124.0,    z = 3.5,     rot = 0 } },
    { x = -1710.01404, y = 398.62332, z = 7.17969,   spawn = { x = -1708.95154, y = 389.20398, z = 6.85677, rot = 220 } },
    { x = 2646.10205,  y = 1084.28955,z = 10.82031,  spawn = { x = 2623.53613,  y = 1073.53625,z = 10.22999,rot = 90 } }
}

local lastMenuRequest = {}
local lastSpawnRequest = {}
local MENU_COOLDOWN  = 5000
local SPAWN_COOLDOWN = 10000

addEventHandler("onResourceStart", resourceRoot, function()
    local db_check = exports.datenbank:getConnection()
    if not db_check then
        outputDebugString("[VehiclesServer] WARNUNG bei onResourceStart: Keine DB-Verbindung! Fahrzeugoperationen könnten fehlschlagen.", 1)
    end

    for _, pos in ipairs(fuelStations) do
        local marker = createMarker(pos.x, pos.y, pos.z - 1, "cylinder", 4, 255, 255, 0, 150)
        if marker then table.insert(fuelMarkers, marker) end
    end

    for i, data in ipairs(spawnMarkers) do
        local marker = createMarker(data.x, data.y, data.z - 1, "cylinder", 1.5, 255, 255, 0, 150)
        if marker then
            addEventHandler("onMarkerHit", marker, (function(spawnData)
                return function(hitElement, dim)
                    if dim and getElementType(hitElement) == "player" and not isPedInVehicle(hitElement) then
                        setElementData(hitElement, "selectedSpawnPointCoords", spawnData, false)
                        triggerEvent("onPlayerRequestVehicleSpawn", hitElement)
                    end
                end
            end)(data.spawn))
        end
    end
    --outputDebugString("[VehiclesServer] Fuel/Shop/Spawn (V1.33 - Einzelnes Setzen) geladen!")
end)

addEvent("purchaseFuel", true)
addEventHandler("purchaseFuel", root, function(vehicleID, newFuel, cost)
    local player = source
    if not vehicleID or not newFuel or not cost then return end
    if cost < 0 then return end
    local MAX_FUEL_COST = 100000
    if cost > MAX_FUEL_COST then outputChatBox("❌ Error: The cost is invalid!", player, 255, 0, 0); return; end

    local playerMoney = getPlayerMoney(player)
    local playerID = getElementData(player, "account_id")
    if not playerID then outputChatBox("❌ Error: No account data!", player, 255, 0, 0); return; end
    if playerMoney < cost then outputChatBox("❌ Not enough money! You need $" .. cost, player, 255, 0, 0); return; end

    takePlayerMoney(player, cost)
    local newBalance = playerMoney - cost
    if newBalance < 0 then newBalance = 0 end

    local moneyUpdateSuccess, moneyErrMsg = exports.datenbank:executeDatabase("UPDATE money SET money=? WHERE account_id=?", newBalance, playerID)
    if not moneyUpdateSuccess then
        outputDebugString("[VehiclesServer|Fuel] DB Fehler beim Aktualisieren des Geldes für AccID " .. playerID .. ": " .. (moneyErrMsg or "Unbekannt"))
        outputChatBox("❌ Database Error (Money Update)!", player, 255,0,0)
        givePlayerMoney(player, cost)
        return
    end

    local clampedFuel = math.max(0, math.min(newFuel, 100))
    local fuelUpdateSuccess, fuelErrMsg = exports.datenbank:executeDatabase("UPDATE vehicles SET fuel=? WHERE id=?", clampedFuel, vehicleID)
    if fuelUpdateSuccess then
        local vehicleElement = nil
        for _, veh in ipairs(getElementsByType("vehicle")) do
            if getElementData(veh, "id") == vehicleID then
                vehicleElement = veh
                break
            end
        end
        if isElement(vehicleElement) then
            setElementData(vehicleElement, "fuel", clampedFuel, true)
        end
        outputChatBox("✅ Your vehicle has been refueled! Cost: $" .. cost, player, 0, 255, 0)
    else
        outputDebugString("[VehiclesServer|Fuel] DB Fehler beim Aktualisieren des Treibstoffs für Fahrzeug ID " .. vehicleID .. ": " .. (fuelErrMsg or "Unbekannt"))
        outputChatBox("❌ Error saving fuel data! Money refunded.", player, 255, 0, 0)
        givePlayerMoney(player, cost)
         exports.datenbank:executeDatabase("UPDATE money SET money=? WHERE account_id=?", playerMoney, playerID)
    end
end)

addEvent("onRequestVehiclesForSale", true)
addEventHandler("onRequestVehiclesForSale", root, function()
    local sortedVehicles = {}
    for _, vehicleData in ipairs(vehiclesForSale) do
        table.insert(sortedVehicles, vehicleData)
    end
    table.sort(sortedVehicles, function(a, b) return a.price < b.price end)
    triggerClientEvent(source, "onReceiveVehiclesForSale", resourceRoot, sortedVehicles)
end)

addEvent("onPlayerBuyVehicle", true)
addEventHandler("onPlayerBuyVehicle", root, function(model, price)
    local player = source
    local playerID = getElementData(player, "account_id")
    if not playerID then outputChatBox("❌ Error: No account data!", player, 255, 0, 0); return; end

    if price <= 0 then outputChatBox("❌ Invalid vehicle price!", player, 255, 0, 0); return; end
    local MAX_VEHICLE_PRICE = 100000000
    if price > MAX_VEHICLE_PRICE then outputChatBox("❌ Price is invalid!", player, 255, 0, 0); return; end

    local checkQueryResult, checkErr = exports.datenbank:queryDatabase("SELECT COUNT(*) AS vehicle_count FROM vehicles WHERE account_id=? AND model=?", playerID, model)
    if not checkQueryResult then
        outputChatBox("❌ DB Error checking vehicle: " .. (checkErr or "Unknown"), player, 255,0,0)
        return
    end
    if checkQueryResult[1].vehicle_count > 0 then
        outputChatBox("❌ You already own this vehicle model!", player, 255, 0, 0)
        return
    end

    local playerMoney = getPlayerMoney(player)
    if playerMoney < price then
        outputChatBox("❌ Not enough money! You need $"..price, player, 255, 0, 0)
        return
    end

    takePlayerMoney(player, price)
    local newMoney = playerMoney - price
    if newMoney < 0 then newMoney = 0 end

    local moneyUpdateSuccess, moneyUpdateErr = exports.datenbank:executeDatabase("UPDATE money SET money=? WHERE account_id=?", newMoney, playerID)
    if not moneyUpdateSuccess then
        outputDebugString("[VehiclesServer|Buy] DB Fehler beim Aktualisieren des Geldes nach Fahrzeugkauf für AccID " .. playerID .. ": " .. (moneyUpdateErr or "Unbekannt"))
        outputChatBox("❌ Database Error (Money Update)! Purchase rolled back.", player, 255,0,0)
        givePlayerMoney(player, price)
        return
    end

    local insertVehicleSuccess, insertVehicleErr = exports.datenbank:executeDatabase([[
        INSERT INTO vehicles (account_id, posX, posY, posZ, rotation, dimension, interior, model, fuel, locked, color1, color2, color3, color4, health, engine, odometer)
        VALUES (?, 0,0,0, 0, 0,0, ?, 100, 0, 0,0,0,0, 1000, 0, 0) -- Standardfarben 0 (Schwarz)
    ]], playerID, model)

    if not insertVehicleSuccess then
        outputDebugString("[VehiclesServer|Buy] DB Fehler beim Einfügen des neuen Fahrzeugs für AccID " .. playerID .. ": " .. (insertVehicleErr or "Unbekannt"))
        outputChatBox("❌ Database Error (Vehicle Insert)! Purchase rolled back.", player, 255,0,0)
        givePlayerMoney(player, price)
        local moneyRollbackSuccess, _ = exports.datenbank:executeDatabase("UPDATE money SET money=? WHERE account_id=?", playerMoney, playerID)
        if not moneyRollbackSuccess then
            outputDebugString("[VehiclesServer|Buy] Kritischer Fehler: Konnte Geld nach fehlgeschlagenem Fahrzeuginsert nicht zurücksetzen für AccID " .. playerID)
        end
        return
    end

    outputChatBox("✅ Purchased " .. getVehicleNameFromModel(model) .. " for $" .. price, player, 0, 255, 0)
    triggerClientEvent(player, "onVehiclePurchaseSuccess", player, model)
end)

addEventHandler("onPlayerRequestVehicleSpawn", root, function()
    local player = source
    if not isElement(player) then return end
    local now = getTickCount(); local last = lastMenuRequest[player] or 0
    if (now - last) < MENU_COOLDOWN then
        outputChatBox("Bitte warte "..math.ceil((MENU_COOLDOWN-(now-last))/1000).." Sekunden.", player,255,165,0)
        return
    end
    lastMenuRequest[player] = now

    local playerID = getElementData(player, "account_id")
    if not playerID then outputChatBox("⚠ Account Error!", player,255,165,0); return; end

    local queryResult, errMsg = exports.datenbank:queryDatabase("SELECT id, model, health, fuel, odometer FROM vehicles WHERE account_id=?", playerID)
    if not queryResult then
        outputChatBox("❌ DB Error fetching vehicles: " .. (errMsg or "Unknown"), player, 255,0,0)
        return
    end

    if queryResult and #queryResult > 0 then
        local clientVehicleList = {}
        for _, row in ipairs(queryResult) do
            table.insert(clientVehicleList, {
                id=row.id, model=row.model, health=row.health, fuel=row.fuel, odometer=row.odometer
            })
        end
        table.sort(clientVehicleList, function(a,b) return a.id < b.id end)
        triggerClientEvent(player, "onReceivePlayerVehicles", player, clientVehicleList)
    else
        outputChatBox("⚠ You have no saved vehicles!", player,255,165,0)
    end
end)

addEvent("onPlayerSpawnVehicle", true)
addEventHandler("onPlayerSpawnVehicle", root, function(vehicleID)
    local player = source
    if not isElement(player) then return end
    local now = getTickCount(); local last = lastSpawnRequest[player] or 0
    if (now - last) < SPAWN_COOLDOWN then
        outputChatBox("Bitte warte "..math.ceil((SPAWN_COOLDOWN-(now-last))/1000).." Sekunden.", player,255,165,0)
        return
    end

    local playerID = getElementData(player, "account_id")
    if not playerID then outputChatBox("Account Error!", player,255,0,0); return end

    local queryResult, errMsg = exports.datenbank:queryDatabase("SELECT * FROM vehicles WHERE id=? AND account_id=?", vehicleID, playerID)
    if not queryResult then
        outputChatBox("❌ DB Error fetching vehicle data: " .. (errMsg or "Unknown"), player, 255,0,0)
        return
    end

    if queryResult and #queryResult > 0 then
        local vehicleData = queryResult[1]
        local modelID=tonumber(vehicleData.model)
        if not modelID or modelID<=0 then outputChatBox("❌ Invalid vehicle model!", player,255,0,0); return end
        if tonumber(vehicleData.health)<=0 then outputChatBox("❌ Vehicle destroyed, repair first!", player,255,0,0); return end

        local spawnPoint = getElementData(player, "selectedSpawnPointCoords")
        if not spawnPoint then outputChatBox("❌ Error: No spawn point. Re-enter marker.", player,255,0,0); return end

        local existingVehicle=getElementData(player,"spawnedVehicleElement")
        if isElement(existingVehicle)then destroyElement(existingVehicle);removeElementData(player,"spawnedVehicleElement")end

        local spawnedVehicle=createVehicle(modelID,spawnPoint.x,spawnPoint.y,spawnPoint.z,0,0,spawnPoint.rot)
        if isElement(spawnedVehicle)then
            lastSpawnRequest[player]=getTickCount()
            setElementHealth(spawnedVehicle,tonumber(vehicleData.health)or 1000)

            local r1,g1,b1 = tonumber(vehicleData.rgb_r1), tonumber(vehicleData.rgb_g1), tonumber(vehicleData.rgb_b1)
            local r2,g2,b2 = tonumber(vehicleData.rgb_r2), tonumber(vehicleData.rgb_g2), tonumber(vehicleData.rgb_b2)
            local r3,g3,b3 = tonumber(vehicleData.rgb_r3), tonumber(vehicleData.rgb_g3), tonumber(vehicleData.rgb_b3)
            local r4,g4,b4 = tonumber(vehicleData.rgb_r4), tonumber(vehicleData.rgb_g4), tonumber(vehicleData.rgb_b4)

            if r1 ~= nil and g1 ~= nil and b1 ~= nil then
                setVehicleColor(spawnedVehicle, r1,g1,b1, r2,g2,b2, r3,g3,b3, r4,g4,b4)
            else
                setVehicleColor(spawnedVehicle,
                    tonumber(vehicleData.color1) or 0, tonumber(vehicleData.color2) or 0,
                    tonumber(vehicleData.color3) or 0, tonumber(vehicleData.color4) or 0
                )
            end

            setElementDimension(spawnedVehicle,tonumber(vehicleData.dimension)or 0)
            setElementInterior(spawnedVehicle,tonumber(vehicleData.interior)or 0)
            local fuelAmount=tonumber(vehicleData.fuel)or 100
            local lockedState=tonumber(vehicleData.locked)or 0
            local engineState=tonumber(vehicleData.engine)or 0
            local odometerFromDB=tonumber(vehicleData.odometer)or 0
            setElementData(spawnedVehicle,"fuel",fuelAmount,true)
            setElementData(spawnedVehicle,"locked",lockedState,true)
            setElementData(spawnedVehicle,"engine",engineState,true)
            setElementData(spawnedVehicle,"odometer",odometerFromDB,true)
            setElementData(spawnedVehicle,"lastSavedHealth", tonumber(vehicleData.health) or 1000)
            setElementData(spawnedVehicle,"lastSavedOdometer", odometerFromDB)
            setElementData(spawnedVehicle,"lastSavedColor1", tonumber(vehicleData.color1) or 0)
            setElementData(spawnedVehicle,"lastSavedColor2", tonumber(vehicleData.color2) or 0)
            setElementData(spawnedVehicle,"lastSavedColor3", tonumber(vehicleData.color3) or 0)
            setElementData(spawnedVehicle,"lastSavedColor4", tonumber(vehicleData.color4) or 0)
            setVehicleLocked(spawnedVehicle,lockedState==1)
            setVehicleEngineState(spawnedVehicle,engineState==1)
            setElementData(spawnedVehicle,"id",tonumber(vehicleData.id),true)
            setElementData(spawnedVehicle,"account_id",playerID,true)
            setElementData(spawnedVehicle,"owner_element",player,false)
            setElementData(player,"spawnedVehicleElement",spawnedVehicle,false)

            local warpedIn = warpPedIntoVehicle(player, spawnedVehicle)
            if not warpedIn then
                outputDebugString("[VehiclesServer|Spawn] FEHLER: warpPedIntoVehicle fehlgeschlagen für Spieler " .. getPlayerName(player))
            end

            if type(applyUpgradesOnSpawn) == "function" then
                applyUpgradesOnSpawn(spawnedVehicle)
            else
                outputDebugString("[VehiclesServer|Spawn] FEHLER: applyUpgradesOnSpawn Funktion nicht gefunden!")
            end

            outputChatBox("✅ Vehicle spawned! Odometer: "..string.format("%.1f",odometerFromDB).." KM",player,0,255,0)
             if r1 ~= nil then
                 triggerClientEvent(player, "vehicles:applyRGBColorsToVehicle", player, spawnedVehicle,
                    r1, g1, b1, r2, g2, b2, r3, g3, b3, r4, g4, b4)
             end
        else
            outputChatBox("❌ Error spawning vehicle!",player,255,0,0)
        end
    else
        outputChatBox("❌ Vehicle not found or not yours!",player,255,0,0)
    end
end)

addEvent("onPlayerRepairVehicle", true)
addEventHandler("onPlayerRepairVehicle", root, function(vehicleID)
    local player = source
    local playerID = getElementData(player, "account_id")
    if not playerID then return end

    local queryResult, errMsgQuery = exports.datenbank:queryDatabase("SELECT health FROM vehicles WHERE id=? AND account_id=?", vehicleID, playerID)
    if not queryResult then
        outputChatBox("❌ DB Error fetching vehicle: " .. (errMsgQuery or "Unknown"), player, 255,0,0)
        return
    end
    if not queryResult[1] then
        outputChatBox("❌ Vehicle not found or not yours!", player,255,0,0)
        return
    end

    local currentHealth=tonumber(queryResult[1].health)
    local repairCost=0
    local needsFullRepair=false
    local needsTireRepair=false

    local vehicleElement=nil
    local foundVehicleElement=getElementData(player,"spawnedVehicleElement")
    if isElement(foundVehicleElement)and getElementData(foundVehicleElement,"id")==vehicleID then
        vehicleElement=foundVehicleElement
    else
        for _,veh in ipairs(getElementsByType("vehicle"))do
            if getElementData(veh,"id")==vehicleID then
                vehicleElement=veh
                break
            end
        end
    end
    if isElement(vehicleElement)then
        local w1,w2,w3,w4=getVehicleWheelStates(vehicleElement)
        if w1==1 or w2==1 or w3==1 or w4==1 then needsTireRepair=true;repairCost=repairCost+100 end
    end

    if currentHealth<1000 then needsFullRepair=true;repairCost=repairCost+math.ceil((1000-currentHealth)/100)*100 end
    if not needsFullRepair and not needsTireRepair then outputChatBox("🔧 Vehicle already repaired!", player,0,255,150); return end

    local moneyPlayer=getPlayerMoney(player)
    if moneyPlayer<repairCost then outputChatBox("❌ Not enough money! Cost: $"..repairCost,player,255,0,0); return end
    takePlayerMoney(player,repairCost)

    if isElement(vehicleElement)then
        if needsFullRepair then setElementHealth(vehicleElement,1000);fixVehicle(vehicleElement)end
        if needsTireRepair then setVehicleWheelStates(vehicleElement,0,0,0,0)end
    end
    local dbSuccess, errMsgDb = exports.datenbank:executeDatabase("UPDATE vehicles SET health=1000 WHERE id=?", vehicleID)
    if dbSuccess then
        setElementData(vehicleElement, "lastSavedHealth", 1000)
        outputChatBox("✅ Vehicle repaired! Cost: $"..repairCost,player,0,255,0)
        triggerClientEvent(player,"refreshVehicleSpawnMenu",player,vehicleID)
    else
        outputChatBox("❌ Error repairing vehicle in DB: " .. (errMsgDb or "Unbekannt"),player,255,0,0)
        givePlayerMoney(player,repairCost)
    end
end)

addEventHandler("onVehicleExplode", root, function()
    local vehicleID = getElementData(source,"id")
    if not vehicleID then return end

    local ownerElement = getElementData(source,"owner_element")
    if isElement(ownerElement)and getElementData(ownerElement,"spawnedVehicleElement")==source then
        removeElementData(ownerElement,"spawnedVehicleElement")
    end
    local _, errMsg = exports.datenbank:executeDatabase("UPDATE vehicles SET health=0 WHERE id=?", vehicleID)
    if errMsg then
        outputDebugString("[Vehicles] DB Fehler (onVehicleExplode) für ID "..vehicleID..": "..errMsg)
    end
end)

function toggleVehicleLock(player, lockState)
    local playerID = getElementData(player,"account_id")
    if not playerID then return end

    local vehicleElement=getElementData(player,"spawnedVehicleElement")
    if not isElement(vehicleElement)then
        outputChatBox("❌ No vehicle spawned/selected!",player,255,165,0)
        return
    end
    local vehicleID=getElementData(vehicleElement,"id")
    if not vehicleID then return end

    if getElementData(vehicleElement,"account_id")~=playerID then
        outputChatBox("❌ Not your vehicle!",player,255,0,0)
        return
    end

    local newLockedValue=lockState and 1 or 0
    setVehicleLocked(vehicleElement,lockState)
    setElementData(vehicleElement,"locked",newLockedValue,true)

    local success,errMsg=exports.datenbank:executeDatabase("UPDATE vehicles SET locked=? WHERE id=? AND account_id=?",newLockedValue,vehicleID,playerID)
    if success then
        local txt=lockState and"locked 🔒"or"unlocked 🔓"
        outputChatBox("✅ Vehicle "..txt,player,0,255,0)
    else
        outputChatBox("❌ Error saving lock status: "..(errMsg or "DB Error"),player,255,0,0)
        setVehicleLocked(vehicleElement,not lockState)
        setElementData(vehicleElement,"locked",not lockState and 1 or 0,true)
    end
end
addCommandHandler("lock",function(p)toggleVehicleLock(p,true)end)
addCommandHandler("unlock",function(p)toggleVehicleLock(p,false)end)

function toggleVehicleEngine(player)
    local pid=getElementData(player,"account_id");if not pid then return end
    local vehicleElement=getElementData(player,"spawnedVehicleElement")
    if not isElement(vehicleElement)then
        local currentVeh=getPedOccupiedVehicle(player)
        if not currentVeh or getElementData(currentVeh,"account_id")~=pid then
            outputChatBox("❌ Not in your spawned vehicle!",player,255,165,0);return
        end
        vehicleElement=currentVeh
    end
    if getVehicleOccupant(vehicleElement,0)~=player then
        outputChatBox("❌ Must be in driver's seat!",player,255,165,0);return
    end
    local vid=getElementData(vehicleElement,"id");if not vid then return end
    if getElementData(vehicleElement,"account_id")~=pid then
        outputChatBox("❌ Not your vehicle!",player,255,0,0);return
    end

    local currentState=getElementData(vehicleElement,"engine")or 0
    local newState=(currentState==1)and 0 or 1
    setVehicleEngineState(vehicleElement,newState==1)
    setElementData(vehicleElement,"engine",newState,true)

    local success,errMsg=exports.datenbank:executeDatabase("UPDATE vehicles SET engine=? WHERE id=? AND account_id=?",newState,vid,pid)
    if success then
        local txt=(newState==1)and"on 🚀"or"off 🛑"
        outputChatBox("✅ Engine turned "..txt,player,0,255,0)
    else
        outputChatBox("❌ Error saving engine status: "..(errMsg or "DB Error"),player,255,0,0)
        setVehicleEngineState(vehicleElement,currentState==1)
        setElementData(vehicleElement,"engine",currentState,true)
    end
end
addCommandHandler("engine",toggleVehicleEngine)

addEvent("refreshVehicleSpawnMenu", true)
addEventHandler("refreshVehicleSpawnMenu", root, function(playerWhoRepaired, repairedVehicleID)
end)

addEventHandler("onResourceStop", resourceRoot, function()
    --outputDebugString("[VehiclesServer] vehicles_server.lua (V1.32) gestoppt.")
end)

if not table.count then
    function table.count(t)
        if type(t) ~= "table" then return 0 end
        local count = 0
        for _ in pairs(t) do
            count = count + 1
        end
        return count
    end
end