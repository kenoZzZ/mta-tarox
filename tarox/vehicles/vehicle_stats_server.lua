-- tarox/vehicles/vehicle_stats_server.lua
-- Enthält den Teil aus vehicle_stats_server.lua,
-- der periodisch Vehicle-Daten (Health, Pos etc.) in DB speichert.
-- OPTIMIERT: Timer entschärft
-- ERWEITERT: Odometer-Speicherung
-- ANGEPASST V1.1: Verbesserte Fehlerbehandlung
-- ANGEPASST V1.2: outputDebugString für fehlende ID/OwnerAccID bei onVehicleDamage unterdrückt
-------------------------------------------------------------

-- db-Variable wird nicht mehr global benötigt

-- Zeit (in ms), wie lange ein Fahrzeug als "kürzlich benutzt" gilt,
-- nachdem der letzte Spieler ausgestiegen ist.
local RECENTLY_USED_THRESHOLD_MS = 5 * 60 * 1000 -- 5 Minuten

function saveVehicleData(veh, forceSave)
    forceSave = forceSave or false
    if not isElement(veh) then return false, "Invalid vehicle element" end

    local vehicleID = getElementData(veh, "id")
    local ownerAccID = getElementData(veh, "account_id")
    if not vehicleID or not ownerAccID then
        -- Diese Nachricht wird intern zurückgegeben, aber nicht mehr zwingend geloggt durch onVehicleDamage
        return false, "Vehicle ID or Owner Account ID missing"
    end

    local health = getElementHealth(veh)
    local odometerValue = getElementData(veh, "odometer") or 0
    local lastHealth = getElementData(veh, "lastSavedHealth") or 1000
    local lastOdometer = getElementData(veh, "lastSavedOdometer") or 0

    local c1, c2, c3, c4 = getVehicleColor(veh, false) -- MTA-IDs
    local lastC1, lastC2, lastC3, lastC4 = getElementData(veh, "lastSavedColor1") or 0, getElementData(veh, "lastSavedColor2") or 0, getElementData(veh, "lastSavedColor3") or 0, getElementData(veh, "lastSavedColor4") or 0
    local colorsChanged = not (c1 == lastC1 and c2 == lastC2 and c3 == lastC3 and c4 == lastC4)

    if not forceSave and math.abs(health - lastHealth) < 1 and math.abs(odometerValue - lastOdometer) < 0.1 and not colorsChanged then
        return true, "No significant changes to save"
    end

    local x, y, z = getElementPosition(veh)
    local _, _, rot = getElementRotation(veh)
    local fuel = getElementData(veh, "fuel") or 100
    local locked = isVehicleLocked(veh) and 1 or 0
    local dim = getElementDimension(veh)
    local int = getElementInterior(veh)
    local engineState = getVehicleEngineState(veh) and 1 or 0
    local healthToSave = math.max(0, math.floor(health * 100) / 100)

    local updateSuccess, errMsg = exports.datenbank:executeDatabase([[
        UPDATE vehicles
        SET posX=?, posY=?, posZ=?, rotation=?, health=?, fuel=?, locked=?, dimension=?, interior=?,
            color1=?, color2=?, color3=?, color4=?, engine=?, odometer=?
        WHERE id=? AND account_id=?
    ]],
    x, y, z, rot, healthToSave, fuel, locked, dim, int,
    c1 or 0, c2 or 0, c3 or 0, c4 or 0,
    engineState,
    odometerValue,
    vehicleID, ownerAccID)

    if updateSuccess then
        setElementData(veh, "lastSavedHealth", health)
        setElementData(veh, "lastSavedOdometer", odometerValue)
        setElementData(veh, "lastSavedColor1", c1 or 0)
        setElementData(veh, "lastSavedColor2", c2 or 0)
        setElementData(veh, "lastSavedColor3", c3 or 0)
        setElementData(veh, "lastSavedColor4", c4 or 0)
        return true, "Success"
    else
        outputDebugString("[VEHICLE-STATS] FEHLER beim DB UPDATE für ID="..tostring(vehicleID)..": "..(errMsg or "Unbekannt"))
        return false, "Database update error"
    end
end

addEventHandler("onVehicleDamage", root, function(loss)
    if loss > 1 then
        local success, msg = saveVehicleData(source, true)
        if not success then
            -- Nur loggen, wenn der Fehler NICHT "Vehicle ID or Owner Account ID missing" ist
            if msg ~= "Vehicle ID or Owner Account ID missing" then
                 outputDebugString("[VEHICLE-STATS|onVehicleDamage] Fehler beim Speichern der Fahrzeugdaten: " .. msg)
            end
        end
    end
end)

addEventHandler("onPlayerQuit", root, function()
    local accountID = getElementData(source, "account_id")
    if not accountID then return end

    for _, veh in ipairs(getElementsByType("vehicle")) do
        if getElementData(veh, "account_id") == accountID then
            saveVehicleData(veh, true) -- Fehlerbehandlung ist in saveVehicleData
        end
    end
end)

addEventHandler("onVehicleExit", root, function(player, seat)
    if getElementType(player) == "player" and seat == 0 then
        local vehicleID = getElementData(source, "id")
        if vehicleID then -- Nur speichern, wenn es eine ID hat (also ein Spielerfahrzeug ist)
            setElementData(source, "lastUsedTick", getTickCount())
            saveVehicleData(source, false) -- Fehlerbehandlung ist in saveVehicleData
        end
    end
end)

local SAVE_INTERVAL_MS = 2 * 60 * 1000

setTimer(function()
    local currentTime = getTickCount()
    local vehiclesToCheck = getElementsByType("vehicle")

    for _, veh in ipairs(vehiclesToCheck) do
        if isElement(veh) then
            local vehicleID = getElementData(veh, "id")
            local ownerAccID = getElementData(veh, "account_id")

            if vehicleID and ownerAccID then -- Stelle sicher, dass es ein bekanntes Spielerfahrzeug ist
                local occupant = getVehicleOccupant(veh, 0)
                local lastUsed = getElementData(veh, "lastUsedTick") or 0

                if occupant or (currentTime - lastUsed < RECENTLY_USED_THRESHOLD_MS) then
                    saveVehicleData(veh, false) -- Fehlerbehandlung ist in saveVehicleData
                end
            end
        end
    end
end, SAVE_INTERVAL_MS, 0)

addEventHandler("onResourceStart", resourceRoot, function()
    local db_check = exports.datenbank:getConnection()
    if not db_check then
        outputDebugString("[vehicle_stats_server] WARNUNG bei onResourceStart: Keine DB-Verbindung! Fahrzeugdaten könnten nicht gespeichert werden.", 1)
    end
    --outputDebugString("[vehicle_stats_server.lua] Fahrzeug-Stats (V1.2 - Debug ODS für fehlende ID unterdrückt) geladen.")
end)

addEventHandler("onResourceStop", resourceRoot, function()
    --outputDebugString("[vehicle_stats_server.lua] Fahrzeug-Stats-System gestoppt.")
    -- Die Daten sollten idealerweise durch onPlayerQuit oder den periodischen Timer gespeichert worden sein.
    -- Ein explizites Speichern aller Fahrzeuge hier könnte bei vielen Fahrzeugen lange dauern und den Server-Shutdown verzögern.
end)