-- tarox/fraktionen/mechanic/tune_server.lua
-- Version 3.0: NUR Reparatur
-- KORRIGIERT V3.1: Explizitere Berechtigungsprüfung für Eigenreparatur

local getPlayerFractionAndRankFunc = _G.getPlayerFractionAndRank or (exports.tarox and exports.tarox.getPlayerFractionAndRank)
local addToFactionTreasuryFunc = _G.addToFactionTreasury or (exports.tarox and exports.tarox.addToFactionTreasury)

local MECHANIC_FRACTION_ID_REPAIR = 7
-- MARKER POSITION FÜR REPARATUR (z.B. Doherty Garage, SF)
local REPAIR_GARAGE_MARKER_POS = {x = -2026.97913, y = 122.59274, z = 29.20854} -- << NEUE, EIGENE POSITION
local REPAIR_GARAGE_MARKER_ELEMENT = nil
local REPAIR_GARAGE_REPAIR_COST = 200

local playerInRepairMarker = {} -- Speichert, welcher Spieler welches Fahrzeug im Marker hat

addEventHandler("onResourceStart", resourceRoot, function()
    if isElement(REPAIR_GARAGE_MARKER_ELEMENT) then destroyElement(REPAIR_GARAGE_MARKER_ELEMENT) end
    REPAIR_GARAGE_MARKER_ELEMENT = createMarker(
        REPAIR_GARAGE_MARKER_POS.x, REPAIR_GARAGE_MARKER_POS.y, REPAIR_GARAGE_MARKER_POS.z - 1,
        "cylinder", 4.0, 255, 200, 0, 100 -- Gelber Marker
    )
    if isElement(REPAIR_GARAGE_MARKER_ELEMENT) then
        setElementInterior(REPAIR_GARAGE_MARKER_ELEMENT, 0)
        setElementDimension(REPAIR_GARAGE_MARKER_ELEMENT, 0)
        addEventHandler("onMarkerHit", REPAIR_GARAGE_MARKER_ELEMENT, handleRepairGarageMarkerHit)
        addEventHandler("onMarkerLeave", REPAIR_GARAGE_MARKER_ELEMENT, handleRepairGarageMarkerLeave)
        --outpudDebugString("[TuneServer-Repair] Reparatur-Garagen Marker erfolgreich erstellt.")
    else
        outputDebugString("[TuneServer-Repair] FEHLER: Reparatur-Garagen Marker konnte NICHT erstellt werden!")
    end
end)

addEventHandler("onResourceStop", resourceRoot, function()
    if isElement(REPAIR_GARAGE_MARKER_ELEMENT) then
        destroyElement(REPAIR_GARAGE_MARKER_ELEMENT)
    end
    playerInRepairMarker = {}
end)

function handleRepairGarageMarkerHit(hitElement, matchingDimension)
    if getElementType(hitElement) ~= "vehicle" or not matchingDimension then return end

    local player = getVehicleOccupant(hitElement, 0)
    if not isElement(player) then return end

    playerInRepairMarker[player] = hitElement -- Wichtig für diese Logik

    if not getPlayerFractionAndRankFunc then
        outputChatBox("Fehler: Fraktionssystem nicht bereit (Server).", player, 255,0,0)
        return
    end

    local fid, rank = getPlayerFractionAndRankFunc(player)
    local isMechanicOnDuty = getElementData(player, "mechanicImDienst")
    local ownerAccId = getElementData(hitElement, "account_id") -- Fahrzeug-Besitzer
    local playerAccId = getElementData(player, "account_id")   -- Spieler im Fahrzeug

    -- HIER ERFOLGT DIE PRÜFUNG
    if (fid == MECHANIC_FRACTION_ID_REPAIR and isMechanicOnDuty) or (ownerAccId and playerAccId and ownerAccId == playerAccId) then
        triggerClientEvent(player, "mechanic:openRepairMenuClient", player, hitElement) -- Das ist das richtige Event für das Reparaturmenü
        if fid == MECHANIC_FRACTION_ID_REPAIR and isMechanicOnDuty then
            outputChatBox("🔧 Willkommen in der Mechanic Werkstatt. Du kannst dieses Fahrzeug reparieren.", player, 255, 200, 0)
        else
             outputChatBox("🔧 Willkommen in der Self-Service Werkstatt für Reparaturen.", player, 255, 200, 0)
        end
    else
        outputChatBox("Diese Werkstatt ist nur für Mechaniker im Dienst oder für die Bearbeitung eigener Fahrzeuge.", player, 255, 100, 0)
        playerInRepairMarker[player] = nil -- Spieler aus der Liste entfernen, wenn kein Zugriff
    end
end

function handleRepairGarageMarkerLeave(leftElement, matchingDimension)
    if not matchingDimension then return end
    local playerAssociated = nil
    if getElementType(leftElement) == "player" then
        playerAssociated = leftElement
    elseif getElementType(leftElement) == "vehicle" then
        for p, veh_in_marker in pairs(playerInRepairMarker) do
            if veh_in_marker == leftElement then
                playerAssociated = p; break
            end
        end
    end

    if isElement(playerAssociated) and playerInRepairMarker[playerAssociated] then
        if (getElementType(leftElement) == "player" and leftElement == playerAssociated) or
           (getElementType(leftElement) == "vehicle" and leftElement == playerInRepairMarker[playerAssociated]) then
            triggerClientEvent(playerAssociated, "mechanic:forceCloseRepairMenu", playerAssociated)
            playerInRepairMarker[playerAssociated] = nil
        end
    end
end

addEventHandler("onPlayerQuit", root, function()
    if playerInRepairMarker[source] then
        playerInRepairMarker[source] = nil
    end
end)

addEvent("mechanic:requestVehicleRepairServer", true)
addEventHandler("mechanic:requestVehicleRepairServer", root, function(vehicleToRepair)
    local player = client
    if not isElement(player) or not isElement(vehicleToRepair) or not addToFactionTreasuryFunc or not getPlayerFractionAndRankFunc then return end

    -- PRÜFUNG 1: Ist der Spieler mit diesem Fahrzeug noch im Marker?
    if playerInRepairMarker[player] ~= vehicleToRepair then
        outputChatBox("❌ Fehler: Dieses Fahrzeug befindet sich nicht in der Reparatur-Zone für dich.", player, 255,0,0)
        return
    end

    -- PRÜFUNG 2: Kosten (bleibt bestehen)
    if getPlayerMoney(player) < REPAIR_GARAGE_REPAIR_COST then
        outputChatBox("❌ Du hast nicht genügend Geld ($" .. REPAIR_GARAGE_REPAIR_COST .. ") für die Reparatur.", player, 255, 0, 0)
        return
    end

    -- PRÜFUNG 3: Ist es das eigene Fahrzeug ODER ist der Spieler Mechaniker im Dienst?
    local fidCheck, _ = getPlayerFractionAndRankFunc(player)
    local isMechanicOnDutyCheck = getElementData(player, "mechanicImDienst")
    local ownerAccIdCheck = getElementData(vehicleToRepair, "account_id")
    local playerAccIdCheck = getElementData(player, "account_id")

    local isAllowedToRepair = false
    if (fidCheck == MECHANIC_FRACTION_ID_REPAIR and isMechanicOnDutyCheck == true) then
        isAllowedToRepair = true -- Mechaniker im Dienst darf immer (wenn er im Fahrzeug sitzt)
    elseif (ownerAccIdCheck and playerAccIdCheck and ownerAccIdCheck == playerAccIdCheck) then
        isAllowedToRepair = true -- Spieler ist Besitzer des Fahrzeugs
    end

    if not isAllowedToRepair then
        outputChatBox("❌ Du bist nicht berechtigt, dieses Fahrzeug hier zu reparieren.", player, 255, 0, 0)
        return
    end
    
    -- Wenn alle Prüfungen okay sind:
    if takePlayerMoney(player, REPAIR_GARAGE_REPAIR_COST) then
        fixVehicle(vehicleToRepair)
        setElementHealth(vehicleToRepair, 1000)
        outputChatBox("✅ Fahrzeug erfolgreich für $" .. REPAIR_GARAGE_REPAIR_COST .. " repariert!", player, 0, 200, 50)

        -- Geld in Fraktionskasse, wenn Mechaniker im Dienst es macht (egal ob eigenes oder fremdes),
        -- ODER wenn ein normaler Spieler sein eigenes Fahrzeug repariert und Mechaniker ist (aber nicht zwingend im Dienst für Eigenreparatur)
        -- Diese Logik sorgt dafür, dass die Fraktionskasse nur profitiert, wenn ein *Mechaniker im Dienst* die Aktion durchführt.
        if fidCheck == MECHANIC_FRACTION_ID_REPAIR and isMechanicOnDutyCheck == true then
            local success, msg = addToFactionTreasuryFunc(MECHANIC_FRACTION_ID_REPAIR, REPAIR_GARAGE_REPAIR_COST)
            if success then
                outputChatBox("💰 $" .. REPAIR_GARAGE_REPAIR_COST .. " wurden der Mechanic Fraktionskasse gutgeschrieben.", player, 0, 220, 120)
            else
                outputDebugString("[MechanicS-Repair] Fehler beim Hinzufügen zur Fraktionskasse: " .. (msg or "Unbekannt"))
            end
        end
    else
        outputChatBox("❌ Ein Fehler ist beim Bezahlen aufgetreten.", player, 255,0,0)
    end
end)