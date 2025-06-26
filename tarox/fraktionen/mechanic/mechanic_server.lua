-- tarox/fraktionen/mechanic/mechanic_server.lua
-- Version 6.2: Direkte Verwendung der 'client' Variable für Event-Handler
-- << NEU V6.3 >> Waffen/Werkzeug-Management für Mechaniker (Speichern/Löschen)
-- << KORRIGIERT V6.3.2 >> Korrekter Aufruf für refreshPlayerFractionData innerhalb derselben Ressource
-- << ANGEPASST V6.3.3 >> Verbesserte Fehlerbehandlung für Datenbankaufrufe
-- << KORRIGIERT V6.3.4 >> toggleAllControls Aufruf für Reparatur-Selbst

local MECHANIC_FRACTION_ID = 7
local MECHANIC_FRACTION_NAME = "Mechanic"
local MECHANIC_WEAPON_SPRAYCAN = 41
local MECHANIC_DUTY_TOOLS_BY_RANK = {
    [1] = { [MECHANIC_WEAPON_SPRAYCAN] = 100, [10] = 1 },
    [2] = { [MECHANIC_WEAPON_SPRAYCAN] = 150, [10] = 1, [11] = 1 },
	[3] = { [MECHANIC_WEAPON_SPRAYCAN] = 200, [10] = 1, [11] = 1, [12] = 1 },
    [4] = { [MECHANIC_WEAPON_SPRAYCAN] = 250, [10] = 1, [11] = 1, [12] = 1 }, 
    [5] = { [MECHANIC_WEAPON_SPRAYCAN] = 300, [10] = 1, [11] = 1, [12] = 1 },
}

local mechanicSpawnLocations = {
    {x = -2048.60669, y = 143.98064, z = 28.83594, rot = 180, interior = 0, dimension = 0}
}
local _G_DEFAULT_CIVIL_SKIN_MECHANIC = _G.DEFAULT_CIVIL_SKIN or 29

local REPAIR_COST = 150
local REPAIR_ANIMATION_DURATION = 5000
local MAX_REPAIR_DISTANCE = 5
local pendingRepairOffers = {}

function giveMechanicDutyTools(player, restoredToolsArray)
    if not isElement(player) then return false end
    local fid, rank = getPlayerFractionAndRank(player)
    if fid ~= MECHANIC_FRACTION_ID or rank < 1 then return false end

    takeAllWeapons(player)

    if type(restoredToolsArray) == "table" and #restoredToolsArray > 0 then
        for _, toolData in ipairs(restoredToolsArray) do
            if toolData.weaponID and toolData.ammo ~= nil then
                giveWeapon(player, tonumber(toolData.weaponID), tonumber(toolData.ammo))
            end
        end
        --outputDebugString("[MechanicS] Werkzeuge für " .. getPlayerName(player) .. " aus SQL 'weapons' (letzter Stand) wiederhergestellt.")
    else
        local rankTools = MECHANIC_DUTY_TOOLS_BY_RANK[rank]
        if rankTools then
            for toolID, ammoCount in pairs(rankTools) do
                giveWeapon(player, toolID, ammoCount)
            end
        end
        --outputDebugString("[MechanicS] Standard-Dienstwerkzeuge an " .. getPlayerName(player) .. " (Rang " .. rank .. ") ausgegeben.")
    end
    return true
end
_G.giveMechanicDutyTools = giveMechanicDutyTools 

function saveMechanicDutyToolsToSQL(player)
    if not isElement(player) then return false end
    local accountID = getElementData(player, "account_id")
    local fid, rank = getPlayerFractionAndRank(player)

    if not accountID then
        outputDebugString("[MechanicS] saveMechanicDutyToolsToSQL: Keine AccountID für " .. getPlayerName(player))
        return false
    end

    if fid ~= MECHANIC_FRACTION_ID or getElementData(player, "mechanicImDienst") ~= true then
        local resetFieldsNoDuty = {}
        for i = 1, 9 do table.insert(resetFieldsNoDuty, string.format("weapon_slot%d = NULL, ammo_slot%d = 0", i, i)) end
        local resetQueryNoDuty = "UPDATE weapons SET " .. table.concat(resetFieldsNoDuty, ", ") .. " WHERE account_id = ?"
        local successClear, errMsgClear = exports.datenbank:executeDatabase(resetQueryNoDuty, accountID)
        if not successClear then
             outputDebugString("[MechanicS] saveMechanicDutyToolsToSQL: DB Fehler beim Leeren der Werkzeugslots für AccID " .. accountID .. ": " .. (errMsgClear or "Unbekannt"))
        else
            --outputDebugString("[MechanicS] Werkzeug-Slots in SQL für " .. getPlayerName(player) .. " (kein Mechaniker/nicht im Dienst) geleert.")
        end
        return successClear
    end

    local dutyToolConfig = MECHANIC_DUTY_TOOLS_BY_RANK[rank]
    if not dutyToolConfig then
        --outputDebugString("[MechanicS] Keine Werkzeugkonfiguration für Rang " .. rank .. " gefunden.")
        return false
    end

    local currentDutyToolsInHand = {}
    for slot = 0, 12 do
        local toolInSlot = getPedWeapon(player, slot)
        if toolInSlot and toolInSlot > 0 and dutyToolConfig[toolInSlot] then
            if #currentDutyToolsInHand < 9 then
                local alreadyAdded = false
                for _, existingTool in ipairs(currentDutyToolsInHand) do
                    if existingTool.weaponID == toolInSlot then
                        alreadyAdded = true; break
                    end
                end
                if not alreadyAdded then
                    table.insert(currentDutyToolsInHand, {
                        weaponID = toolInSlot,
                        ammo = getPedTotalAmmo(player, slot)
                    })
                end
            end
        end
    end

    local insertIgnoreSuccess, insertIgnoreErr = exports.datenbank:executeDatabase("INSERT IGNORE INTO weapons (account_id) VALUES (?)", accountID)
    if not insertIgnoreSuccess then
        outputDebugString("[MechanicS] FEHLER: DB INSERT IGNORE für weapons Tabelle fehlgeschlagen für AccID " .. accountID .. ": " .. (insertIgnoreErr or "Unbekannt"))
    end

    local updatesSQLParts = {}
    local paramsSQL = {}

    for i = 1, 9 do
        if currentDutyToolsInHand[i] then
            table.insert(updatesSQLParts, string.format("weapon_slot%d = ?", i))
            table.insert(paramsSQL, currentDutyToolsInHand[i].weaponID)
            table.insert(updatesSQLParts, string.format("ammo_slot%d = ?", i))
            table.insert(paramsSQL, currentDutyToolsInHand[i].ammo)
        else
            table.insert(updatesSQLParts, string.format("weapon_slot%d = NULL", i))
            table.insert(updatesSQLParts, string.format("ammo_slot%d = 0", i))
        end
    end
    table.insert(paramsSQL, accountID)

    if #updatesSQLParts == 0 and #currentDutyToolsInHand > 0 then
         outputDebugString("[MechanicS] FEHLER: Konnte keine SQL Update Parts erstellen für "..getPlayerName(player))
         return false
    elseif #updatesSQLParts == 0 and #currentDutyToolsInHand == 0 then 
         outputDebugString("[MechanicS] Keine Dienstwerkzeuge zum Speichern für "..getPlayerName(player).." in SQL 'weapons'. Slots werden geleert.")
         local resetFieldsEmptyDuty = {}
         for i = 1, 9 do table.insert(resetFieldsEmptyDuty, string.format("weapon_slot%d = NULL, ammo_slot%d = 0", i, i)) end
         local resetQueryEmptyDuty = "UPDATE weapons SET " .. table.concat(resetFieldsEmptyDuty, ", ") .. " WHERE account_id = ?"
         local successClearEmpty, errMsgClearEmpty = exports.datenbank:executeDatabase(resetQueryEmptyDuty, accountID)
         if not successClearEmpty then outputDebugString("[MechanicS] FEHLER beim Leeren der Werkzeug-Slots (Empty Duty) für AccID "..accountID..": ".. (errMsgClearEmpty or "Unbekannt")) end
         return successClearEmpty
    end
    
    local queryString = "UPDATE weapons SET " .. table.concat(updatesSQLParts, ", ") .. " WHERE account_id = ?"
    local successUpdate, errMsgUpdate = exports.datenbank:executeDatabase(queryString, unpack(paramsSQL))

    if successUpdate then
        --outputDebugString("[MechanicS] Dienstwerkzeug-Status für " .. getPlayerName(player) .. " in SQL 'weapons' aktualisiert.")
    else
        outputDebugString("[MechanicS] FEHLER beim Aktualisieren der Dienstwerkzeuge in SQL für " .. getPlayerName(player) .. ": " .. (errMsgUpdate or "Unbekannt"))
    end
    return successUpdate
end
_G.saveMechanicDutyToolsToSQL = saveMechanicDutyToolsToSQL 

function setPlayerMechanicDutyStatus(player, onDuty)
    if not isElement(player) then return false, "Invalid player element" end
    local accID = getElementData(player, "account_id")
    if not accID then
        outputDebugString("[MechanicS V6.3] setPlayerMechanicDutyStatus: Keine AccID für " .. getPlayerName(player))
        return false, "No account_id"
    end

    local dutyStatus = onDuty and 1 or 0
    local success, errMsg = exports.datenbank:executeDatabase("UPDATE fraction_members SET on_duty = ? WHERE account_id = ? AND fraction_id = ?", dutyStatus, accID, MECHANIC_FRACTION_ID)

    if success then
        setElementData(player, "mechanicImDienst", onDuty)

        if onDuty then
            local _, rank_level = getPlayerFractionAndRank(player)
            local skinToSet = (_G.FRACTION_SKINS and _G.FRACTION_SKINS[MECHANIC_FRACTION_ID] and _G.FRACTION_SKINS[MECHANIC_FRACTION_ID][math.min(rank_level, #_G.FRACTION_SKINS[MECHANIC_FRACTION_ID])]) or _G_DEFAULT_CIVIL_SKIN_MECHANIC
            setElementModel(player, skinToSet)
            if type(_G.updateFractionSkinInDB) == "function" then
                 _G.updateFractionSkinInDB(accID, MECHANIC_FRACTION_ID, rank_level)
            end
        else
            takeAllWeapons(player)
            saveMechanicDutyToolsToSQL(player) 

            local civilSkin = _G_DEFAULT_CIVIL_SKIN_MECHANIC
            local accID_skin = getElementData(player, "account_id")
            if accID_skin then
                 local standardSkinResult, skinErrMsg = exports.datenbank:queryDatabase("SELECT standard_skin FROM account WHERE id=? LIMIT 1", accID_skin)
                 if not standardSkinResult then
                     outputDebugString("[MechanicS] setPlayerMechanicDutyStatus: DB Fehler beim Laden des Standard-Skins (OffDuty) für AccID " .. accID_skin .. ": " .. (skinErrMsg or "Unbekannt"))
                 elseif standardSkinResult and standardSkinResult[1] and standardSkinResult[1].standard_skin then
                     civilSkin = tonumber(standardSkinResult[1].standard_skin) or _G_DEFAULT_CIVIL_SKIN_MECHANIC
                 end
            end
            setElementModel(player, civilSkin)
            if type(_G.updateFractionSkinInDB) == "function" then
                 _G.updateFractionSkinInDB(accID_skin, 0, 1) 
            end
        end
        if type(_G.refreshPlayerFractionData) == "function" then _G.refreshPlayerFractionData(player) end
        return true, "Success"
    else
        outputDebugString("[MechanicS V6.3] FEHLER beim DB-Update des Duty-Status für AccID: " .. accID .. ": " .. (errMsg or "Unbekannt"))
        return false, "Database error updating duty status"
    end
end
_G.setPlayerMechanicDutyStatus = setPlayerMechanicDutyStatus

function clearPlayerMechanicToolsAndDutyWhenKickedOrFactionChanged(player)
    if not isElement(player) then return false end
    local accountID = getElementData(player, "account_id")
    if not accountID then return false end

    local playerName = getPlayerName(player)
    outputDebugString("[MechanicClear] Entferne Mechaniker-Werkzeuge für " .. playerName .. " (AccID: " .. accountID .. ") aufgrund von Fraktionswechsel/Kick.")

    takeAllWeapons(player)

    local resetFields = {}
    for i = 1, 9 do table.insert(resetFields, string.format("weapon_slot%d = NULL, ammo_slot%d = 0", i, i)) end
    local resetQuery = "UPDATE weapons SET " .. table.concat(resetFields, ", ") .. " WHERE account_id = ?"
    local successQuery, errMsgQuery = exports.datenbank:executeDatabase(resetQuery, accountID)

    if successQuery then
        --outputDebugString("[MechanicClear] Werkzeug-Slots in SQL für AccID " .. accountID .. " erfolgreich geleert.")
    else
        outputDebugString("[MechanicClear] FEHLER beim Leeren der Werkzeug-Slots in SQL für AccID " .. accountID .. ": " .. (errMsgQuery or "Unbekannt"))
    end

    if getElementData(player, "mechanicImDienst") == true then
        setElementData(player, "mechanicImDienst", false)
        outputDebugString("[MechanicClear] ElementData 'mechanicImDienst' für " .. playerName .. " auf false gesetzt.")
    end
    return successQuery
end
_G.clearPlayerMechanicToolsAndDutyWhenKickedOrFactionChanged = clearPlayerMechanicToolsAndDutyWhenKickedOrFactionChanged


addEvent("onMechanicRequestSpawn", true)
addEventHandler("onMechanicRequestSpawn", root, function()
    local player = client
    if not isElement(player) then return end

    local canSpawn, reason = _G.canPlayerUseFactionSpawnCommand(player)
    if not canSpawn then
        outputChatBox("❌ " .. reason, player, 255, 0, 0)
        return
    end

    local fid, rank_level = getPlayerFractionAndRank(player)
    if fid ~= MECHANIC_FRACTION_ID then
        outputChatBox("❌ Du bist kein Mitglied der Mechanic Fraktion!", player, 255, 0, 0)
        return
    end

    if getElementData(player, "mechanicImDienst") == true then
        outputChatBox("🔧 Du bist bereits als Mechanic im Dienst!", player, 255, 165, 0)
        return
    end

    if rank_level < 1 or rank_level > 5 then 
        outputChatBox("❌ Ungültiger Rang in der Mechanic Fraktion!", player, 255, 0, 0)
        return
    end

    local dutySuccess, dutyMsg = setPlayerMechanicDutyStatus(player, true)
    if not dutySuccess then
        outputChatBox("❌ Fehler beim Dienstantritt: " .. (dutyMsg or "Unbekannter DB Fehler"), player, 255,0,0)
        return
    end
    local currentModelAfterDutySet = getElementModel(player)

    local spawnPosData = mechanicSpawnLocations[1]
    if not spawnPosData or not spawnPosData.x then
        outputChatBox("❌ Fehler: Spawn-Position für Mechaniker nicht konfiguriert.", player, 255,0,0)
        setPlayerMechanicDutyStatus(player, false) 
        return
    end

    local spawnSuccess = spawnPlayer(player, spawnPosData.x, spawnPosData.y, spawnPosData.z, spawnPosData.rot, currentModelAfterDutySet, spawnPosData.interior or 0, spawnPosData.dimension or 0)

    if not spawnSuccess then
        outputChatBox("❌ Ein Fehler ist beim Spawnen aufgetreten. Standard-Spawn wird versucht.", player, 255,0,0)
        spawnPlayer(player, 0,0,5,0, currentModelAfterDutySet, 0,0) 
        setPlayerMechanicDutyStatus(player, false) 
        return
    end

    fadeCamera(player, true)
    setCameraTarget(player, player)

    local restoredTools = {}
    if exports.tarox and type(exports.tarox.loadPlayerWeaponsFromSQL) == "function" then
        restoredTools = exports.tarox:loadPlayerWeaponsFromSQL(player)
    elseif type(loadPlayerWeaponsFromSQL) == "function" then 
        restoredTools = loadPlayerWeaponsFromSQL(player)
    end
    giveMechanicDutyTools(player, restoredTools)

    outputChatBox("🔧 Du hast den Dienst als Mechanic (Rang " .. rank_level .. ") angetreten!", player, 0, 200, 0)
end)

addEvent("onMechanicLeaveDuty", true)
addEventHandler("onMechanicLeaveDuty", root, function()
    local player = client
    if not isElement(player) then return end

    local fid, rank_level = getPlayerFractionAndRank(player)
    if fid ~= MECHANIC_FRACTION_ID then
        outputChatBox("❌ Du bist kein Mitglied der Mechanic Fraktion!", player, 255, 0, 0)
        return
    end

    if getElementData(player, "mechanicImDienst") == false then
        outputChatBox("❌ Du bist nicht als Mechanic im Dienst!", player, 255, 165, 0)
        return
    end

    saveMechanicDutyToolsToSQL(player) 

    local dutySuccess, dutyMsg = setPlayerMechanicDutyStatus(player, false)
    if not dutySuccess then
        outputChatBox("❌ Fehler beim Verlassen des Dienstes: " .. (dutyMsg or "Unbekannter DB Fehler"), player, 255, 0, 0)
        setPlayerMechanicDutyStatus(player, true)
        return
    end
    outputChatBox("🔧 Du hast den Dienst als Mechanic beendet.", player, 200, 200, 0)
end)

addCommandHandler("mechanic", function(player, cmd)
    local fid, _ = getPlayerFractionAndRank(player)
    if fid ~= MECHANIC_FRACTION_ID then
        outputChatBox("❌ Du bist kein Mitglied der Mechanic Fraktion!", player, 255, 0, 0)
        return
    end
    triggerClientEvent(player, "openMechanicWindow", player)
end)

addCommandHandler("repairrequest", function(mechanicPlayer, commandName, targetPlayerNameOrID, vehicleID_optional)
    if not isElement(mechanicPlayer) then return end

    local fid, rank = getPlayerFractionAndRank(mechanicPlayer)
    if fid ~= MECHANIC_FRACTION_ID then
        outputChatBox("❌ Nur Mechanics können diesen Befehl verwenden.", mechanicPlayer, 255, 0, 0)
        return
    end

    local imDienst = getElementData(mechanicPlayer, "mechanicImDienst")
    if imDienst ~= true then
        outputChatBox("❌ Du musst als Mechanic im Dienst sein, um Reparaturanfragen zu senden.", mechanicPlayer, 255, 100, 0)
        return
    end

    if not targetPlayerNameOrID then
        outputChatBox("SYNTAX: /" .. commandName .. " [Spieler Name/ID] [Fahrzeug-ID (optional)]", mechanicPlayer, 200, 200, 0)
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
        outputChatBox("Spieler '" .. targetPlayerNameOrID .. "' nicht gefunden.", mechanicPlayer, 255, 100, 0)
        return
    elseif #potentialTargets > 1 then
        outputChatBox("Mehrere Spieler gefunden, bitte sei genauer:", mechanicPlayer, 255, 165, 0)
        for i=1, math.min(5, #potentialTargets) do local tP=potentialTargets[i]; outputChatBox("  - "..getPlayerName(tP).." (ID: "..(getElementData(tP,"account_id")or"N/A")..")", mechanicPlayer,200,200,200) end
        if #potentialTargets > 5 then outputChatBox("  ... und weitere.", mechanicPlayer, 200,200,200) end
        return
    else
        targetPlayer = potentialTargets[1]
    end

    if not isElement(targetPlayer) then outputChatBox("Spieler '" .. targetPlayerNameOrID .. "' nicht gefunden.", mechanicPlayer, 255, 100, 0); return end
    if targetPlayer == mechanicPlayer then outputChatBox("Du kannst dir nicht selbst ein Reparaturangebot machen.", mechanicPlayer, 255, 165, 0); return end

    local vehicleToRepair = nil
    if vehicleID_optional then
        local idToSearch = tonumber(vehicleID_optional)
        if idToSearch then
            for _, veh in ipairs(getElementsByType("vehicle")) do if getElementData(veh, "id") == idToSearch then vehicleToRepair = veh; break end end
            if not vehicleToRepair then outputChatBox("Fahrzeug mit ID " .. vehicleID_optional .. " nicht in der Nähe oder nicht existent.", mechanicPlayer, 255, 100, 0); return end
        else outputChatBox("Ungültige Fahrzeug-ID angegeben.", mechanicPlayer, 255, 100, 0); return end
    else
        local targetVehiclesElements = {}; local occupiedVeh = getPedOccupiedVehicle(targetPlayer); if occupiedVeh then table.insert(targetVehiclesElements, occupiedVeh) end
        for _, veh in ipairs(getElementsByType("vehicle")) do
            if getElementData(veh, "account_id") == getElementData(targetPlayer, "account_id") then
                local alreadyAdded = false; for _, addedVeh in ipairs(targetVehiclesElements) do if addedVeh == veh then alreadyAdded = true; break; end end
                if not alreadyAdded then table.insert(targetVehiclesElements, veh) end
            end
        end
        if #targetVehiclesElements == 0 then outputChatBox(getPlayerName(targetPlayer) .. " besitzt keine gespawnten Fahrzeuge in deiner Nähe.", mechanicPlayer, 255, 100, 0); return end
        local closestVehicle = nil; local minDistance = MAX_REPAIR_DISTANCE + 15; local mx,my,mz = getElementPosition(mechanicPlayer)
        for _, veh in ipairs(targetVehiclesElements) do
            if isElement(veh) and getElementHealth(veh) < 999 then
                local vx,vy,vz = getElementPosition(veh); local dist = getDistanceBetweenPoints3D(mx,my,mz, vx,vy,vz)
                if dist < minDistance then minDistance = dist; closestVehicle = veh end
            end
        end
        vehicleToRepair = closestVehicle
    end

    if not isElement(vehicleToRepair) then outputChatBox("Kein beschädigtes Fahrzeug für " .. getPlayerName(targetPlayer) .. " gefunden.", mechanicPlayer, 255, 100, 0); return end
    if getElementHealth(vehicleToRepair) >= 999 then outputChatBox("Das Fahrzeug (" .. getVehicleNameFromModel(getElementModel(vehicleToRepair)) .. ") ist nicht signifikant beschädigt.", mechanicPlayer, 255, 165, 0); return end
    if pendingRepairOffers[targetPlayer] then
        outputChatBox(getPlayerName(targetPlayer) .. " hat bereits ein offenes Reparaturangebot.", mechanicPlayer, 255, 165, 0)
        local oldOfferData = pendingRepairOffers[targetPlayer]
        if isElement(oldOfferData.mechanic) and oldOfferData.mechanic ~= mechanicPlayer then outputChatBox("Deine vorherige Reparaturanfrage an "..getPlayerName(targetPlayer).." wurde von einem anderen Mechaniker überschrieben.",oldOfferData.mechanic,255,165,0) end
    end

    pendingRepairOffers[targetPlayer] = { mechanic = mechanicPlayer, vehicle = vehicleToRepair, time = getTickCount() }
    local vehicleName = getVehicleNameFromModel(getElementModel(vehicleToRepair))
    triggerClientEvent(targetPlayer, "mechanic:showRepairConfirmationToPlayer", mechanicPlayer, getPlayerName(mechanicPlayer), vehicleName, REPAIR_COST, vehicleToRepair)
    outputChatBox("Reparaturanfrage an " .. getPlayerName(targetPlayer) .. " für einen " .. vehicleName .. " gesendet.", mechanicPlayer, 0, 220, 0)
    outputChatBox(getPlayerName(mechanicPlayer) .. " möchte dein Fahrzeug (" .. vehicleName .. ") für $" .. REPAIR_COST .. " reparieren.", targetPlayer, 0, 220, 150)

    setTimer(function(playerWhoWasOffered, offerMechanic)
        if pendingRepairOffers[playerWhoWasOffered] and pendingRepairOffers[playerWhoWasOffered].mechanic == offerMechanic then
            pendingRepairOffers[playerWhoWasOffered] = nil
            if isElement(offerMechanic) then outputChatBox("Das Reparaturangebot an " .. getPlayerName(playerWhoWasOffered) .. " ist abgelaufen.", offerMechanic, 255, 165, 0) end
            if isElement(playerWhoWasOffered) then triggerClientEvent(playerWhoWasOffered,"mechanic:closeRepairConfirmation",playerWhoWasOffered); outputChatBox("Das Reparaturangebot von "..getPlayerName(offerMechanic).." ist abgelaufen.",playerWhoWasOffered,255,165,0) end
        end
    end, 60000, 1, targetPlayer, mechanicPlayer)
end)

addEvent("mechanic:playerRespondedToRepairOffer", true)
addEventHandler("mechanic:playerRespondedToRepairOffer", root, function(accepted, vehicleElementFromServer)
    local targetPlayer = client
    local offerData = pendingRepairOffers[targetPlayer]
    if not offerData then return end

    local mechanicPlayer = offerData.mechanic; local vehicleToRepair = offerData.vehicle
    if isElement(vehicleElementFromServer) and getElementType(vehicleElementFromServer)=="vehicle" then if getElementModel(vehicleElementFromServer)==getElementModel(vehicleToRepair) then vehicleToRepair=vehicleElementFromServer else outputDebugString("[MechanicS V6.3] Warnung: Client hat anderes Fahrzeugmodell für Reparatur gemeldet.")end end
    pendingRepairOffers[targetPlayer] = nil

    if not isElement(mechanicPlayer) then outputChatBox("Der Mechaniker ist nicht mehr online.", targetPlayer, 255,100,0); return end
    if not isElement(vehicleToRepair) then outputChatBox("Das zu reparierende Fahrzeug existiert nicht mehr.", targetPlayer,255,100,0); outputChatBox("Das zu reparierende Fahrzeug für "..getPlayerName(targetPlayer).." existiert nicht mehr.",mechanicPlayer,255,100,0); return end

    if accepted then
        if getPlayerMoney(targetPlayer) < REPAIR_COST then outputChatBox("Du hast nicht genügend Geld ($"..REPAIR_COST..") für die Reparatur.",targetPlayer,255,0,0); outputChatBox(getPlayerName(targetPlayer).." hat nicht genügend Geld.",mechanicPlayer,255,0,0); return end
        local mx,my,mz = getElementPosition(mechanicPlayer); local vx,vy,vz = getElementPosition(vehicleToRepair)
        if getDistanceBetweenPoints3D(mx,my,mz,vx,vy,vz) > MAX_REPAIR_DISTANCE+2 then outputChatBox("Du bist zu weit vom Fahrzeug entfernt.",mechanicPlayer,255,100,0); outputChatBox(getPlayerName(mechanicPlayer).." ist zu weit vom Fahrzeug entfernt.",targetPlayer,255,100,0); return end
        takePlayerMoney(targetPlayer, REPAIR_COST); givePlayerMoney(mechanicPlayer, REPAIR_COST)
        outputChatBox("Du hast das Angebot angenommen. Kosten: $"..REPAIR_COST,targetPlayer,0,200,50); outputChatBox(getPlayerName(targetPlayer).." hat dein Angebot angenommen.",mechanicPlayer,0,200,50)
        triggerClientEvent(mechanicPlayer,"mechanic:startRepairAnimationOnVehicle",mechanicPlayer,vehicleToRepair,REPAIR_ANIMATION_DURATION)
        setTimer(function(veh,mech,originalTargetPlayer)
            if isElement(veh)and isElement(mech)then local mX,mY,mZ=getElementPosition(mech);local vX,vY,vZ=getElementPosition(veh)
                if getDistanceBetweenPoints3D(mX,mY,mZ,vX,vY,vZ)<=MAX_REPAIR_DISTANCE+1 then setElementHealth(veh,1000);fixVehicle(veh);outputChatBox("Fahrzeug repariert!",mech,0,255,0);if isElement(originalTargetPlayer)and originalTargetPlayer~=mech then outputChatBox("Dein Fahrzeug wurde von "..getPlayerName(mech).." repariert!",originalTargetPlayer,0,255,0)end
                else outputChatBox("Reparatur fehlgeschlagen: Zu weit entfernt.",mech,255,0,0);if isElement(originalTargetPlayer)and originalTargetPlayer~=mech then outputChatBox(getPlayerName(mech).." hat sich entfernt.",originalTargetPlayer,255,0,0)end;if isElement(originalTargetPlayer)then givePlayerMoney(originalTargetPlayer,REPAIR_COST)end;takePlayerMoney(mech,REPAIR_COST)end
            end
        end,REPAIR_ANIMATION_DURATION,1,vehicleToRepair,mechanicPlayer,targetPlayer)
    else outputChatBox("Du hast das Angebot abgelehnt.",targetPlayer,200,200,0); outputChatBox(getPlayerName(targetPlayer).." hat dein Angebot abgelehnt.",mechanicPlayer,200,200,0) end
end)

addEvent("mechanic:requestRepairOfferFromClickedVehicle", true)
addEventHandler("mechanic:requestRepairOfferFromClickedVehicle", root, function(clickedVehicle)
    local mechanicPlayer = client 
    if not isElement(mechanicPlayer) or not isElement(clickedVehicle) then return end

    local fid, rank = getPlayerFractionAndRank(mechanicPlayer)
    if fid ~= MECHANIC_FRACTION_ID or getElementData(mechanicPlayer, "mechanicImDienst") ~= true then
        outputChatBox("❌ Nur Mechaniker im Dienst können Reparaturangebote erstellen.", mechanicPlayer, 255, 0, 0)
        return
    end

    local vehicleOwnerElement = getVehicleController(clickedVehicle) 
    local targetPlayerForOffer = nil
    local targetPlayerName = "Unbekannt"
    local vehicleOwnerAccountID_db = getElementData(clickedVehicle, "account_id")

    if isElement(vehicleOwnerElement) then
        targetPlayerForOffer = vehicleOwnerElement
        targetPlayerName = getPlayerName(targetPlayerForOffer)
    elseif vehicleOwnerAccountID_db then
        local ownerOnline = getPlayerFromAccountID(vehicleOwnerAccountID_db) 
        if isElement(ownerOnline) then
            targetPlayerForOffer = ownerOnline
            targetPlayerName = getPlayerName(targetPlayerForOffer)
        else
            local ownerDataResult, errMsgOwner = exports.datenbank:queryDatabase("SELECT username FROM account WHERE id = ? LIMIT 1", vehicleOwnerAccountID_db)
            if ownerDataResult and ownerDataResult[1] then
                targetPlayerName = ownerDataResult[1].username
            else
                targetPlayerName = "Besitzer (Offline)"
            end
            outputChatBox("Der Besitzer des Fahrzeugs ("..targetPlayerName..") ist nicht online oder es sitzt kein Fahrer im Fahrzeug.", mechanicPlayer, 255, 165, 0)
            return
        end
    else
        outputChatBox("❌ Fahrzeug hat keinen Fahrer oder bekannten Besitzer in der Datenbank.", mechanicPlayer, 255, 100, 0)
        return
    end

    if targetPlayerForOffer == mechanicPlayer then
        outputChatBox("🔧 Für die Reparatur deines eigenen Fahrzeugs bitte 'M' drücken und auf dein Fahrzeug klicken (Selbstreparatur).", mechanicPlayer, 0, 150, 200)
        return
    end

    if not isElement(targetPlayerForOffer) then 
        outputChatBox("❌ Zielspieler für Reparaturangebot konnte nicht ermittelt werden.", mechanicPlayer, 255, 100, 0)
        return
    end

    local vehicleName = getVehicleNameFromModel(getElementModel(clickedVehicle))

    setElementData(mechanicPlayer, "pendingRepairOfferTarget", {
        targetPlayerToOffer = targetPlayerForOffer, 
        vehicleToRepair = clickedVehicle,
        vehicleNameToDisplay = vehicleName,
        targetPlayerNameToDisplay = targetPlayerName 
    }, false) 

    triggerClientEvent(mechanicPlayer, "mechanic:showMechanicRepairConfirmGUI", mechanicPlayer, targetPlayerName, vehicleName)
end)

addEvent("mechanic:mechanicConfirmsRepairOffer", true)
addEventHandler("mechanic:mechanicConfirmsRepairOffer", root, function()
    local mechanicPlayer = client
    if not isElement(mechanicPlayer) then return end

    local offerDetails = getElementData(mechanicPlayer, "pendingRepairOfferTarget")
    if not offerDetails or not isElement(offerDetails.targetPlayerToOffer) or not isElement(offerDetails.vehicleToRepair) then
        outputChatBox("❌ Fehler: Angebot nicht mehr gültig oder Zielspieler/Fahrzeug nicht mehr verfügbar.", mechanicPlayer, 255,0,0)
        if offerDetails then removeElementData(mechanicPlayer, "pendingRepairOfferTarget") end
        return
    end

    local targetPlayerElement = offerDetails.targetPlayerToOffer
    local vehicleToRepair = offerDetails.vehicleToRepair
    local vehicleNameToDisplay = offerDetails.vehicleNameToDisplay
    local targetPlayerNameToDisplay = offerDetails.targetPlayerNameToDisplay

    removeElementData(mechanicPlayer, "pendingRepairOfferTarget") 

    if targetPlayerElement == mechanicPlayer then
        outputChatBox("🔧 Du kannst dir nicht selbst ein Angebot machen.", mechanicPlayer, 255, 165, 0);
        return
    end

    local mx,my,mz = getElementPosition(mechanicPlayer)
    local vx,vy,vz = getElementPosition(vehicleToRepair)
    if getDistanceBetweenPoints3D(mx,my,mz,vx,vy,vz) > MAX_REPAIR_DISTANCE + 5 then 
        outputChatBox("❌ Das Fahrzeug ist zu weit entfernt, um ein Angebot zu senden.", mechanicPlayer,255,100,0)
        return
    end

    if getElementHealth(vehicleToRepair) >= 999 then
        outputChatBox("Das Fahrzeug (" .. vehicleNameToDisplay .. ") von "..targetPlayerNameToDisplay.." ist nicht signifikant beschädigt.", mechanicPlayer, 255, 165, 0)
        return
    end

    if pendingRepairOffers[targetPlayerElement] then
        local oldOfferMech = pendingRepairOffers[targetPlayerElement].mechanic
        if isElement(oldOfferMech) and oldOfferMech ~= mechanicPlayer then
            triggerClientEvent(oldOfferMech, "mechanic:closePlayerAcceptGUI", oldOfferMech) 
            outputChatBox("Dein Reparaturangebot an "..targetPlayerNameToDisplay.." wurde von einem anderen Mechaniker überschrieben.",oldOfferMech,255,165,0)
        end
    end

    pendingRepairOffers[targetPlayerElement] = {
        mechanic = mechanicPlayer,
        vehicle = vehicleToRepair,
        time = getTickCount()
    }
    
    triggerClientEvent(targetPlayerElement, "mechanic:showPlayerAcceptRepairGUI", mechanicPlayer, getPlayerName(mechanicPlayer), vehicleNameToDisplay, REPAIR_COST, vehicleToRepair)
    outputChatBox("Reparaturanfrage an " .. targetPlayerNameToDisplay .. " für einen " .. vehicleNameToDisplay .. " gesendet (Kosten: $"..REPAIR_COST..").", mechanicPlayer, 0, 220, 0)
    outputChatBox(getPlayerName(mechanicPlayer) .. " möchte dein Fahrzeug (" .. vehicleNameToDisplay .. ") für $" .. REPAIR_COST .. " reparieren.", targetPlayerElement, 0, 220, 150)

    setTimer(function(playerWhoWasOffered, offerMech)
        if pendingRepairOffers[playerWhoWasOffered] and pendingRepairOffers[playerWhoWasOffered].mechanic == offerMech then
            pendingRepairOffers[playerWhoWasOffered] = nil
            if isElement(offerMech) then outputChatBox("Das Reparaturangebot an " .. getPlayerName(playerWhoWasOffered) .. " ist abgelaufen.", offerMech, 255, 165, 0) end
            if isElement(playerWhoWasOffered) then
                triggerClientEvent(playerWhoWasOffered,"mechanic:closePlayerAcceptGUI",playerWhoWasOffered)
                outputChatBox("Das Reparaturangebot von "..getPlayerName(offerMech).." ist abgelaufen.",playerWhoWasOffered,255,165,0)
            end
        end
    end, 60000, 1, targetPlayerElement, mechanicPlayer) 
end)

-- Event für Selbstreparatur
local SELF_REPAIR_COST_MECHANIC = 0 
local SELF_REPAIR_ANIMATION_DURATION_MECHANIC = 3000 

addEvent("mechanic:requestSelfRepairVehicle", true)
addEventHandler("mechanic:requestSelfRepairVehicle", root, function(vehicleToRepair)
    local player = client 
    if not isElement(player) or not isElement(vehicleToRepair) then return end

    local fid, rank = getPlayerFractionAndRank(player)
    if fid ~= MECHANIC_FRACTION_ID then
        outputChatBox("❌ Nur Mechaniker können diesen Befehl verwenden.", player, 255, 0, 0)
        return
    end

    local imDienst = getElementData(player, "mechanicImDienst")
    if imDienst ~= true then
        outputChatBox("❌ Du musst als Mechaniker im Dienst sein, um dein Fahrzeug zu reparieren.", player, 255, 100, 0)
        return
    end

    local ownerAccId = getElementData(vehicleToRepair, "account_id")
    local playerAccId = getElementData(player, "account_id")

    if ownerAccId ~= playerAccId then
        outputChatBox("❌ Dies ist nicht dein Fahrzeug.", player, 255, 100, 0)
        return
    end

    if getElementHealth(vehicleToRepair) >= 999 then
        outputChatBox("🔧 Dein Fahrzeug (" .. getVehicleNameFromModel(getElementModel(vehicleToRepair)) .. ") ist nicht signifikant beschädigt.", player, 0, 200, 100)
        return
    end

    if SELF_REPAIR_COST_MECHANIC > 0 then
        if getPlayerMoney(player) < SELF_REPAIR_COST_MECHANIC then
            outputChatBox("❌ Du hast nicht genug Geld ($" .. SELF_REPAIR_COST_MECHANIC .. ") für die Reparatur.", player, 255, 0, 0)
            return
        end
        takePlayerMoney(player, SELF_REPAIR_COST_MECHANIC)
    end

    triggerClientEvent(player, "mechanic:startRepairAnimationOnVehicle", player, vehicleToRepair, SELF_REPAIR_ANIMATION_DURATION_MECHANIC)
    outputChatBox("Du beginnst mit der Reparatur deines Fahrzeugs...", player, 0, 200, 150)

    setTimer(function(veh, p)
        if isElement(veh) and isElement(p) then
            local mX,mY,mZ = getElementPosition(p)
            local vX,vY,vZ = getElementPosition(veh)
            if getDistanceBetweenPoints3D(mX,mY,mZ,vX,vY,vZ) <= MAX_REPAIR_DISTANCE + 1 then
                fixVehicle(veh)
                setElementHealth(veh, 1000)
                if SELF_REPAIR_COST_MECHANIC > 0 then
                    outputChatBox("✅ Dein Fahrzeug wurde erfolgreich für $".. SELF_REPAIR_COST_MECHANIC .." repariert!", p, 0, 255, 0)
                else
                    outputChatBox("✅ Dein Fahrzeug wurde erfolgreich kostenlos repariert!", p, 0, 255, 0)
                end
            else
                outputChatBox("Reparatur fehlgeschlagen: Du hast dich zu weit vom Fahrzeug entfernt.", p, 255, 0, 0)
                if SELF_REPAIR_COST_MECHANIC > 0 then
                    givePlayerMoney(p, SELF_REPAIR_COST_MECHANIC) 
                end
            end
        end
    end, SELF_REPAIR_ANIMATION_DURATION_MECHANIC, 1, vehicleToRepair, player)
end)


addEventHandler("onResourceStart", resourceRoot, function()
    local db_check = exports.datenbank:getConnection()
    if not db_check then
        outputDebugString("[MechanicS] FATALER FEHLER bei onResourceStart: Keine Datenbankverbindung!", 2)
        return
    end
    for _, player in ipairs(getElementsByType("player")) do
        if getElementData(player, "account_id") then
            local fid_start, rank_start = getPlayerFractionAndRank(player)
            if fid_start == MECHANIC_FRACTION_ID then
                local acc_id_start = getElementData(player, "account_id")
                local dutyResult, dutyErrMsg = exports.datenbank:queryDatabase("SELECT on_duty FROM fraction_members WHERE account_id = ? AND fraction_id = ? LIMIT 1", acc_id_start, MECHANIC_FRACTION_ID)
                local isOnDutyDB_start = false
                if not dutyResult then
                    outputDebugString("[MechanicS] onResourceStart: DB Fehler beim Laden des Duty-Status für AccID " .. acc_id_start .. ": " .. (dutyErrMsg or "Unbekannt"))
                elseif dutyResult and dutyResult[1] and tonumber(dutyResult[1].on_duty) == 1 then
                    isOnDutyDB_start = true
                end
                setElementData(player, "mechanicImDienst", isOnDutyDB_start)
            end
        end
    end
    --outputDebugString("[MechanicS V6.3.4] Mechanic Server-Skript (toggleAllControls Fix) geladen.")
end)

addEventHandler("onResourceStop", resourceRoot, function()
     for player, data in pairs(pendingRepairOffers) do if isElement(player) then triggerClientEvent(player,"mechanic:closePlayerAcceptGUI",player)end end; pendingRepairOffers={} -- Geändert von closeRepairConfirmation
     for _, player in ipairs(getElementsByType("player")) do
        if isElement(player) and getElementData(player, "account_id") then
            local fid, _ = getPlayerFractionAndRank(player)
            if fid == MECHANIC_FRACTION_ID and getElementData(player, "mechanicImDienst") == true then saveMechanicDutyToolsToSQL(player) end
        end
     end
     --outputDebugString("[MechanicS V6.3.4] Alle Reparaturangebote und Dienstwerkzeuge beim Stoppen behandelt.")
end)

addEventHandler("onPlayerQuit", root, function()
    local player = source
    if pendingRepairOffers[player] then local mechanicWhoOffered=pendingRepairOffers[player].mechanic; if isElement(mechanicWhoOffered)then outputChatBox(getPlayerName(player).." hat das Spiel verlassen. Angebot abgebrochen.",mechanicWhoOffered,255,165,0)end; pendingRepairOffers[player]=nil end
    for offeredToPlayer, offerDetails in pairs(pendingRepairOffers)do if offerDetails.mechanic==player then if isElement(offeredToPlayer)then outputChatBox("Mechaniker "..getPlayerName(player).." hat das Spiel verlassen. Angebot abgebrochen.",offeredToPlayer,255,165,0);triggerClientEvent(offeredToPlayer,"mechanic:closePlayerAcceptGUI",offeredToPlayer)end;pendingRepairOffers[offeredToPlayer]=nil end end
    local accID = getElementData(player,"account_id")
    if accID then local fid,_=getPlayerFractionAndRank(player)
        if fid == MECHANIC_FRACTION_ID then if getElementData(player,"mechanicImDienst")==true then saveMechanicDutyToolsToSQL(player)end; local isOnDuty=getElementData(player,"mechanicImDienst")or false; setPlayerMechanicDutyStatus(player,isOnDuty)end
    end
end)

addEventHandler("onPlayerLoginSuccess", root, function()
    local player = source
    local accID = getElementData(player, "account_id")
    if not accID then return end

    local fid, rank = getPlayerFractionAndRank(player)
    if fid == MECHANIC_FRACTION_ID then 
        local dutyResult, errMsg = exports.datenbank:queryDatabase("SELECT on_duty FROM fraction_members WHERE account_id = ? AND fraction_id = ? LIMIT 1", accID, MECHANIC_FRACTION_ID)
        local isOnDutyDB = false
        if not dutyResult then
            outputDebugString("[MechanicS] onPlayerLoginSuccess: DB Fehler beim Laden des Duty-Status für AccID " .. accID .. ": " .. (errMsg or "Unbekannt"))
        elseif dutyResult and dutyResult[1] and tonumber(dutyResult[1].on_duty) == 1 then
            isOnDutyDB = true
        end
        setElementData(player, "mechanicImDienst", isOnDutyDB) 

        if isOnDutyDB then
             local mechanicSkin = (_G.FRACTION_SKINS and _G.FRACTION_SKINS[MECHANIC_FRACTION_ID] and _G.FRACTION_SKINS[MECHANIC_FRACTION_ID][math.min(rank, #_G.FRACTION_SKINS[MECHANIC_FRACTION_ID])]) or _G_DEFAULT_CIVIL_SKIN_MECHANIC 
             setElementModel(player, mechanicSkin)
             
             --outputDebugString("[MechanicS] onPlayerLoginSuccess: Duty-Status und Skin für Mechanic "..getPlayerName(player).." gesetzt. Werkzeuge werden von login_server.lua gehandhabt.")
        end
    end
end)