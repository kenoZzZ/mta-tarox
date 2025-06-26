-- Dateiname: bankpeds_server.lua
-- tarox/peds/bankpeds_server.lua
-- KORRIGIERT: Korrekter pedIdentifier für Fahrlehrer
-- NEU: Führerscheinüberprüfung für Jobs mit Fahrzeugen
-- NEU: 15-Minuten Job-Timer
-- ANGEPASST V1.1: Verbesserte Fehlerbehandlung
-- BEREINIGT: Debug-Ausgaben entfernt
-- KORRIGIERT V1.1.1: isEventHandlerAdded entfernt, da serverseitig nicht verfügbar
-- KORRIGIERT V1.1.2: Tippfehler im LKW-Dispatcher Event
-- KORRIGIERT V1.1.3: Korrekter Event-Name für LKW-Dispatcher
-- KORREKTUR V1.2: Ignoriert jetzt Drogen-Samenverkäufer-Peds, um Konflikte zu vermeiden.

local playerJobData = {} -- Hält aktive Jobdaten für Spieler (z.B. { [player] = { pedIdentifier = "...", vehicle = veh, ... } } )
local pedJobCooldowns = {} -- Hält Cooldowns für Peds pro Spieler (z.B. { [accountID] = { [pedIdentifier] = tick_cooldown_endet } } )

local JOB_VEHICLE_MODELS = {
    ["bank_teller_main"] = 418,      -- Beispiel: Sultan
    ["service_ped_airport"] = 453,   -- Beispiel: Turismo
    ["character_ryder_grove"] = 581, -- Beispiel: Freeway (Motorrad)
    ["ped_drill_job"] = 455,         -- Beispiel: Picador
    ["ped_c4_job"] = 609,            -- Beispiel: FBI Rancher
}
local DEFAULT_JOB_VEHICLE_MODEL = 418 -- Fallback, falls kein spezifisches Modell definiert ist
local JOB_REENTER_TIMEOUT = 60 * 1000 -- 1 Minute Zeit, um wieder ins Jobfahrzeug zu steigen
local JOB_MAIN_COOLDOWN = 4 * 60 * 60 * 1000 -- 4 Stunden Cooldown für einen spezifischen Ped-Job
local DELIVERY_MARKER_COLOR_STANDARD = {0, 200, 50, 120}
local DELIVERY_MARKER_COLOR_ZWISCHENSTOPP = {255, 165, 0, 150}
local DELIVERY_MARKER_SIZE = 3
local JOB_DELIVERY_DURATION = 15 * 60 * 1000 -- 15 Minuten Zeitlimit für Lieferjobs

-- Event Handler für Klicks auf Peds
local function handlePedAction(clickedPedElement, clientClickId)
    local player = client
    if clientClickId == nil then return end
    if not isElement(clickedPedElement) or getElementType(clickedPedElement) ~= "ped" then return end

    local pedId = getElementData(clickedPedElement, "pedIdentifier")

    -- KORREKTUR: Prüfen, ob dieser Ped vom Drogensystem (Verkauf ODER Kauf) behandelt wird und dann ignorieren.
    local DROGEN_VERKAUFS_PED_ID_CHECK = "drogen_verkaufs_ped"
    local SAMEN_VERKAUFS_PED_ID_CHECK = "drogen_samen_verkaufs_ped" -- Identifier aus dem Drogensystem
    if pedId == DROGEN_VERKAUFS_PED_ID_CHECK or pedId == SAMEN_VERKAUFS_PED_ID_CHECK then
        -- Diese Peds werden vom Drogensystem-Skript behandelt. Dieses Skript soll nichts tun.
        return
    end

    if pedId == "job_vermittler_ped" then
        return
    end

    if pedId == "lkw_dispatcher_ped" then
        triggerEvent("jobs:lkwfahrer:interactionWithStartPed", player)
        return
    end

    if pedId == "driving_instructor" then
        triggerEvent("drivelicense:pedInteraction", player)
        return
    end

    local pedDefinition = nil
    if _G.getManagedPedConfigByIdentifier then
        pedDefinition = _G.getManagedPedConfigByIdentifier(pedId)
    elseif exports.tarox and exports.tarox.getManagedPedConfigByIdentifier then
        pedDefinition = exports.tarox.getManagedPedConfigByIdentifier(pedId)
    end

    if not pedDefinition then
        triggerClientEvent(player, "onServerSendsBankPedInfo", resourceRoot, {title="Fehler", messages={"Charakter nicht konfiguriert."}, buttonText="OK"})
        return
    end

    if pedDefinition.pedIdentifier == "juwelier_shop_ped" then
        triggerEvent("juwelier:requestSellGUIData", player)
        return
    end

    if pedDefinition.jobItem then
        local accountID = getElementData(player, "account_id")
        if not accountID then
            outputChatBox("Fehler: Account nicht geladen.", player, 255, 0, 0)
            return
        end

        if playerJobData and playerJobData[player] then
            outputChatBox("Du bist bereits auf einer Mission!", player, 255, 150, 0)
            return
        end

        if pedJobCooldowns and pedJobCooldowns[accountID] and pedJobCooldowns[accountID][pedId] and getTickCount() < pedJobCooldowns[accountID][pedId] then
            local remainingTime = math.ceil((pedJobCooldowns[accountID][pedId] - getTickCount()) / 1000 / 60)
            outputChatBox("Du musst noch ca. " .. remainingTime .. " Minute(n) warten, bevor du diesen Job erneut annehmen kannst.", player, 255, 150, 0)
            return
        end

        local itemDef = exports.tarox:getItemDefinition(pedDefinition.jobItem)
        local itemImagePath = nil
        if itemDef and itemDef.imagePath then
            itemImagePath = itemDef.imagePath
        end

        triggerClientEvent(player, "onServerRequestsJobConfirmation", resourceRoot,
            pedDefinition.pedIdentifier,
            pedDefinition.jobInitialMessage,
            pedDefinition.jobItemName,
            itemImagePath
        )
        return
    elseif pedDefinition.windowInfo then
        triggerClientEvent(player, "onServerSendsBankPedInfo", resourceRoot, pedDefinition.windowInfo)
        return
    else
        triggerClientEvent(player, "onServerSendsBankPedInfo", resourceRoot, {title="Information", messages={"Dieser Charakter hat dir momentan nichts zu sagen."}, buttonText="OK"})
    end
end
addEvent("onClientRequestsPedAction", true)
addEventHandler("onClientRequestsPedAction", root, handlePedAction)


function isVehicleApproximatelyInCylinderMarker_Fallback(vehicle, marker)
    if not isElement(vehicle) or not isElement(marker) or getElementType(marker) ~= "marker" then return false end
    local markerType = getMarkerType(marker)
    if markerType ~= "cylinder" then return false end
    local vx, vy, vz = getElementPosition(vehicle)
    local mx, my, mz = getElementPosition(marker)
    local sizeX, sizeY, _ = getMarkerSize(marker)
    local radius = sizeX / 2
    local distance2D = getDistanceBetweenPoints2D(vx, vy, mx, my)
    local markerBottomZ = mz
    local markerTopZ = mz + sizeY
    return distance2D <= radius and vz >= markerBottomZ and vz <= markerTopZ
end

function abortPlayerJob(player, reason, suppressVehicleDestroy)
    if not isElement(player) or not playerJobData[player] then return end
    local jobInfo = playerJobData[player]

    if isTimer(jobInfo.deliveryTimeLimitTimer) then
        killTimer(jobInfo.deliveryTimeLimitTimer)
        jobInfo.deliveryTimeLimitTimer = nil
    end
    triggerClientEvent(player, "stopJobTimerDisplay", player)

    if isTimer(jobInfo.exitTimer) then killTimer(jobInfo.exitTimer) end
    if isElement(jobInfo.deliveryMarker) then destroyElement(jobInfo.deliveryMarker) end
    if not suppressVehicleDestroy and isElement(jobInfo.vehicle) then destroyElement(jobInfo.vehicle) end
    local blipElement = getElementData(player, "jobDeliveryBlip")
    if isElement(blipElement) then destroyElement(blipElement); removeElementData(player, "jobDeliveryBlip") end
    playerJobData[player] = nil
end

addEventHandler("onResourceStart", resourceRoot, function()
    playerJobData = {}
    pedJobCooldowns = {}
end)

addEvent("onPlayerAcceptsJobOffer", true)
addEventHandler("onPlayerAcceptsJobOffer", root, function(pedIdentifier)
    local player = client
    local accountID = getElementData(player, "account_id")
    if not accountID then
        outputChatBox("Fehler: Account nicht geladen.", player, 255,0,0)
        return
    end
    if playerJobData[player] then
        outputChatBox("Fehler: Du bist bereits auf einer Mission.", player, 255, 100,0)
        return
    end

    local pedDefinition = _G.getManagedPedConfigByIdentifier and _G.getManagedPedConfigByIdentifier(pedIdentifier) or (exports.tarox and exports.tarox.getManagedPedConfigByIdentifier and exports.tarox.getManagedPedConfigByIdentifier(pedIdentifier))

    if not pedDefinition or not pedDefinition.jobItem then
        outputChatBox("Fehler: Job nicht gefunden oder ungültig für Ped-ID: " .. tostring(pedIdentifier), player, 255,0,0)
        return
    end

    if pedDefinition.jobVehicleSpawnPos and pedDefinition.requiredLicense then
        local licenseExportResource = exports.tarox
        if not licenseExportResource or type(licenseExportResource.hasPlayerLicense) ~= "function" then
            licenseExportResource = exports.drivelicense -- Fallback, falls es unter drivelicense exportiert wurde
        end

        if licenseExportResource and type(licenseExportResource.hasPlayerLicense) == "function" then
            if not licenseExportResource:hasPlayerLicense(player, pedDefinition.requiredLicense) then
                local licenseDisplayName = pedDefinition.requiredLicense
                if _G.LICENSE_CONFIG and _G.LICENSE_CONFIG[pedDefinition.requiredLicense] and _G.LICENSE_CONFIG[pedDefinition.requiredLicense].displayName then
                    licenseDisplayName = _G.LICENSE_CONFIG[pedDefinition.requiredLicense].displayName
                elseif LICENSE_CONFIG and LICENSE_CONFIG[pedDefinition.requiredLicense] and LICENSE_CONFIG[pedDefinition.requiredLicense].displayName then
                    licenseDisplayName = LICENSE_CONFIG[pedDefinition.requiredLicense].displayName
                end
                outputChatBox("Für diesen Job benötigst du einen gültigen Führerschein: " .. licenseDisplayName, player, 255, 100, 0)
                return
            end
        else
             outputChatBox("Warnung: Lizenz konnte für diesen Job nicht überprüft werden.", player, 255,165,0)
        end
    end


    if pedJobCooldowns[accountID] and pedJobCooldowns[accountID][pedIdentifier] and getTickCount() < pedJobCooldowns[accountID][pedIdentifier] then
        local remainingTime = math.ceil((pedJobCooldowns[accountID][pedIdentifier] - getTickCount()) / 1000 / 60)
        outputChatBox("Du musst noch ca. " .. remainingTime .. " Minute(n) warten, bevor du diesen Job erneut annehmen kannst.", player, 255, 150, 0)
        return
    end

    local vehicleModelToSpawn = JOB_VEHICLE_MODELS[pedIdentifier] or DEFAULT_JOB_VEHICLE_MODEL
    local spawnPos = pedDefinition.jobVehicleSpawnPos
    local jobVehicle = createVehicle(vehicleModelToSpawn, spawnPos.x, spawnPos.y, spawnPos.z, 0, 0, spawnPos.rot or 0)

    if not isElement(jobVehicle) then
        outputChatBox("Fehler beim Erstellen des Job-Fahrzeugs (Modell: "..vehicleModelToSpawn..").", player, 255,0,0)
        return
    end

    setElementData(jobVehicle, "jobVehicleForPlayer", player, false)
    setElementData(jobVehicle, "jobPedIdentifier", pedIdentifier, false)
    setVehicleLocked(jobVehicle, false)
    setElementData(jobVehicle, "locked", 0, true) -- Für das Tacho-Skript
    warpPedIntoVehicle(player, jobVehicle)
    setVehicleEngineState(jobVehicle, true)

    local targetPos, markerColor, markerType, jobMessage
    if pedDefinition.jobType == "multi_stage_motorcycle" then
        targetPos = pedDefinition.jobZwischenstoppPos
        markerColor = DELIVERY_MARKER_COLOR_ZWISCHENSTOPP
        markerType = "zwischenstopp_motorcycle"
        playerJobData[player] = {
            pedIdentifier = pedIdentifier, vehicle = jobVehicle, deliveryMarker = nil,
            exitTimer = nil, jobStartTime = getTickCount(), jobStage = 1,
            jobType = "multi_stage_motorcycle", deliveryTimeLimitTimer = nil
        }
        jobMessage = "Job angenommen! Fahre das " .. getVehicleNameFromModel(vehicleModelToSpawn) .. " zum ersten markierten Zielort (Zwischenstopp)."
    else
        targetPos = pedDefinition.jobDeliveryPos
        markerColor = DELIVERY_MARKER_COLOR_STANDARD
        markerType = "standard_delivery"
        playerJobData[player] = {
            pedIdentifier = pedIdentifier, vehicle = jobVehicle, deliveryMarker = nil,
            exitTimer = nil, jobStartTime = getTickCount(), jobStage = 1,
            jobType = "standard", deliveryTimeLimitTimer = nil
        }
        jobMessage = "Job angenommen! Bringe das " .. getVehicleNameFromModel(vehicleModelToSpawn) .. " zum markierten Zielort."
    end

    local deliveryMarker = createMarker(targetPos.x, targetPos.y, targetPos.z -1, "cylinder", DELIVERY_MARKER_SIZE, unpack(markerColor))
    if not isElement(deliveryMarker) then
        if isElement(jobVehicle) then destroyElement(jobVehicle) end
        outputChatBox("Fehler beim Erstellen des Liefermarkers.", player, 255,0,0)
        if playerJobData[player] then playerJobData[player] = nil end
        return
    end

    setElementData(deliveryMarker, "isJobDeliveryMarker", true); setElementData(deliveryMarker, "forPlayer", player)
    setElementData(deliveryMarker, "forPedJob", pedIdentifier); setElementData(deliveryMarker, "jobMarkerType", markerType)

    if playerJobData[player] then
        playerJobData[player].deliveryMarker = deliveryMarker
        playerJobData[player].deliveryTimeLimitTimer = setTimer(checkJobTimeLimit, JOB_DELIVERY_DURATION, 1, player)
        triggerClientEvent(player, "startJobTimerDisplay", player, JOB_DELIVERY_DURATION) -- Event für den Timer an den Client senden
    else
        destroyElement(deliveryMarker)
        if isElement(jobVehicle) then destroyElement(jobVehicle) end
        outputChatBox("Fehler beim Jobstart (Interne Daten).", player, 255,0,0)
        return
    end

    local blip = createBlipAttachedTo(deliveryMarker, 0, 2, markerColor[1],markerColor[2],markerColor[3],255,0, 99999.0)
    setElementData(player, "jobDeliveryBlip", blip, false)
    outputChatBox(jobMessage, player, 0, 200, 50)
end)

function checkJobTimeLimit(player)
    if not isElement(player) then return end
    if playerJobData and playerJobData[player] then
        local jobInfo = playerJobData[player]
        if isTimer(jobInfo.deliveryTimeLimitTimer) then
            killTimer(jobInfo.deliveryTimeLimitTimer)
            playerJobData[player].deliveryTimeLimitTimer = nil
        end
        abortPlayerJob(player, "Zeitlimit überschritten", false)
    end
end


addEventHandler("onMarkerHit", root, function(hitElement, matchingDimension)
    if not matchingDimension then return end
    local deliveryMarkerElement = source
    if not getElementData(deliveryMarkerElement, "isJobDeliveryMarker") then return end

    local player = nil
    if getElementType(hitElement) == "player" then player = hitElement
    elseif getElementType(hitElement) == "vehicle" then player = getVehicleOccupant(hitElement, 0)
    else return end

    if not player or not playerJobData[player] then return end
    local jobInfo = playerJobData[player]
    local markerType = getElementData(deliveryMarkerElement, "jobMarkerType")

    if getElementData(deliveryMarkerElement, "forPlayer") ~= player or getElementData(deliveryMarkerElement, "forPedJob") ~= jobInfo.pedIdentifier then return end

    local pedDefinition = _G.getManagedPedConfigByIdentifier and _G.getManagedPedConfigByIdentifier(jobInfo.pedIdentifier) or (exports.tarox and exports.tarox.getManagedPedConfigByIdentifier and exports.tarox.getManagedPedConfigByIdentifier(jobInfo.pedIdentifier))
    if not pedDefinition then abortPlayerJob(player, "Job Definition verloren"); return end

    if markerType == "zwischenstopp_motorcycle" and jobInfo.jobType == "multi_stage_motorcycle" and jobInfo.jobStage == 1 then
        local actualVehiclePlayerIsIn = getPedOccupiedVehicle(player)
        if not isElement(actualVehiclePlayerIsIn) then
            outputChatBox("Du musst mit dem Motorrad in den Marker fahren!", player, 255, 100, 0);
            return
        end
        if not isElement(jobInfo.vehicle) then abortPlayerJob(player, "Job-Fahrzeug verloren", true); return end
        if actualVehiclePlayerIsIn ~= jobInfo.vehicle then
            outputChatBox("Du sitzt im falschen Motorrad!", player, 255,100,0);
            return
        end

        local vehicleInMarkerCheck = false
        if type(isElementWithinMarker)=="function"then vehicleInMarkerCheck=isElementWithinMarker(actualVehiclePlayerIsIn,deliveryMarkerElement)elseif type(isElementInMarker)=="function"then vehicleInMarkerCheck=isElementInMarker(actualVehiclePlayerIsIn,deliveryMarkerElement)else vehicleInMarkerCheck=isVehicleApproximatelyInCylinderMarker_Fallback(actualVehiclePlayerIsIn,deliveryMarkerElement)end

        if vehicleInMarkerCheck then
            outputChatBox("Zwischenstopp erreicht. Fahrzeug wird entfernt, du wirst teleportiert.", player, 0, 200, 100)
            if isElement(jobInfo.vehicle) then destroyElement(jobInfo.vehicle); playerJobData[player].vehicle = nil; end
            if isElement(deliveryMarkerElement) then destroyElement(deliveryMarkerElement); playerJobData[player].deliveryMarker = nil; end
            local blipElement = getElementData(player, "jobDeliveryBlip"); if isElement(blipElement) then destroyElement(blipElement); removeElementData(player, "jobDeliveryBlip") end

            fadeCamera(player, false, 0.5)
            setTimer(function()
                if isElement(player) and playerJobData[player] then
                    setElementPosition(player, pedDefinition.jobPlayerTeleportPos.x, pedDefinition.jobPlayerTeleportPos.y, pedDefinition.jobPlayerTeleportPos.z)
                    setElementInterior(player, 0); setElementDimension(player, 0); fadeCamera(player, true, 0.5)

                    local finalMarkerPos = pedDefinition.jobFinalDeliveryPos
                    local finalMarker = createMarker(finalMarkerPos.x, finalMarkerPos.y, finalMarkerPos.z -1, "cylinder", DELIVERY_MARKER_SIZE, unpack(DELIVERY_MARKER_COLOR_STANDARD))
                    if isElement(finalMarker) then
                        setElementData(finalMarker, "isJobDeliveryMarker", true); setElementData(finalMarker, "forPlayer", player)
                        setElementData(finalMarker, "forPedJob", pedDefinition.pedIdentifier); setElementData(finalMarker, "jobMarkerType", "final_delivery_on_foot")
                        playerJobData[player].deliveryMarker = finalMarker; playerJobData[player].jobStage = 2
                        local finalBlip = createBlipAttachedTo(finalMarker, 0, 2, DELIVERY_MARKER_COLOR_STANDARD[1],DELIVERY_MARKER_COLOR_STANDARD[2],DELIVERY_MARKER_COLOR_STANDARD[3],255,0, 99999.0)
                        setElementData(player, "jobDeliveryBlip", finalBlip, false)
                        outputChatBox("Gehe nun zum finalen Abgabepunkt.", player, 0, 200, 50)
                    else abortPlayerJob(player, "Fehler beim Erstellen des finalen Markers.") end
                end
            end, 500, 1)
        end
    elseif (markerType == "standard_delivery" and jobInfo.jobType == "standard" and jobInfo.jobStage == 1) or
           (markerType == "final_delivery_on_foot" and jobInfo.jobType == "multi_stage_motorcycle" and jobInfo.jobStage == 2) then

        local inMarkerCheck = false
        if markerType == "standard_delivery" then
            local actualVehiclePlayerIsIn = getPedOccupiedVehicle(player)
            if not isElement(actualVehiclePlayerIsIn) then
                outputChatBox("Du musst im Fahrzeug sein!", player, 255,100,0);
                return
            end
            if not isElement(jobInfo.vehicle) then abortPlayerJob(player, "Job-Fahrzeug verloren", true); return end
            if actualVehiclePlayerIsIn ~= jobInfo.vehicle then
                outputChatBox("Du sitzt im falschen Fahrzeug!", player, 255,100,0);
                return
            end
            if type(isElementWithinMarker)=="function"then inMarkerCheck=isElementWithinMarker(actualVehiclePlayerIsIn,deliveryMarkerElement)elseif type(isElementInMarker)=="function"then inMarkerCheck=isElementInMarker(actualVehiclePlayerIsIn,deliveryMarkerElement)else inMarkerCheck=isVehicleApproximatelyInCylinderMarker_Fallback(actualVehiclePlayerIsIn,deliveryMarkerElement)end
        else
            if type(isElementWithinMarker)=="function"then inMarkerCheck=isElementWithinMarker(player,deliveryMarkerElement)elseif type(isElementInMarker)=="function"then inMarkerCheck=isElementInMarker(player,deliveryMarkerElement)else local px,py,pz=getElementPosition(player);local mx,my,mz=getElementPosition(deliveryMarkerElement);local dSizeX,dSizeY=getMarkerSize(deliveryMarkerElement);inMarkerCheck=getDistanceBetweenPoints2D(px,py,mx,my)<=dSizeX/2 and math.abs(pz-(mz+dSizeY/2))<dSizeY/2 end
        end

        if inMarkerCheck then
            if isTimer(jobInfo.deliveryTimeLimitTimer) then killTimer(jobInfo.deliveryTimeLimitTimer) end
            triggerClientEvent(player, "stopJobTimerDisplay", player)

            if pedDefinition and pedDefinition.jobItem then
                local itemGivenSuccess, itemGiveMsg = exports.tarox:givePlayerItem(player, pedDefinition.jobItem, 1)
                if itemGivenSuccess then
                    outputChatBox("Lieferung erfolgreich! Du hast 1x " .. pedDefinition.jobItemName .. " erhalten.", player, 50, 200, 50)
                    local accountID_cooldown = getElementData(player, "account_id")
                    if accountID_cooldown then
                        if not pedJobCooldowns[accountID_cooldown] then pedJobCooldowns[accountID_cooldown] = {} end
                        pedJobCooldowns[accountID_cooldown][jobInfo.pedIdentifier] = getTickCount() + JOB_MAIN_COOLDOWN
                    end
                else
                    outputChatBox("Lieferung erfolgreich, aber Item konnte nicht gegeben werden: "..(itemGiveMsg or "Inventar voll?"), player, 255, 150, 0)
                end
            else
                outputChatBox("Fehler: Job-Definition nicht gefunden nach Abschluss.", player, 255,0,0)
            end
            if isElement(deliveryMarkerElement)then destroyElement(deliveryMarkerElement)end
            if isElement(jobInfo.vehicle)then destroyElement(jobInfo.vehicle)end
            local blipElement = getElementData(player,"jobDeliveryBlip"); if isElement(blipElement)then destroyElement(blipElement);removeElementData(player,"jobDeliveryBlip")end
            if isTimer(jobInfo.exitTimer)then killTimer(jobInfo.exitTimer)end
            playerJobData[player]=nil
        end
    end
end)

addEventHandler("onMarkerLeave", root, function(hitElement, matchingDimension)
    -- Keine spezielle Logik hier für das Verlassen des Markers notwendig
end)


addEventHandler("onVehicleExit", root, function(player, seat)
    if seat ~= 0 or not playerJobData[player] then return end
    local jobInfo = playerJobData[player]
    if source == jobInfo.vehicle then
        if isTimer(jobInfo.exitTimer) then killTimer(jobInfo.exitTimer) end
        outputChatBox("Du hast das Lieferfahrzeug verlassen! Steige innerhalb von 1 Minute wieder ein, sonst wird der Job abgebrochen.", player, 255, 150, 0)
        jobInfo.exitTimer = setTimer(abortPlayerJob, JOB_REENTER_TIMEOUT, 1, player, "Zeitlimit für Wiedereinstieg überschritten.", false)
        playerJobData[player] = jobInfo
    end
end)

addEventHandler("onVehicleEnter", root, function(player, seat)
    if seat ~= 0 or not playerJobData[player] then return end
    local jobInfo = playerJobData[player]
    if source == jobInfo.vehicle then
        if isTimer(jobInfo.exitTimer) then
            killTimer(jobInfo.exitTimer)
            jobInfo.exitTimer = nil
            playerJobData[player] = jobInfo
            outputChatBox("Lieferung fortgesetzt.", player, 50, 200, 50)
        end
    end
end)

addEventHandler("onVehicleExplode", root, function()
    for player, jobInfo in pairs(playerJobData) do
        if isElement(player) and isElement(jobInfo.vehicle) and jobInfo.vehicle == source then
            abortPlayerJob(player, "Dein Lieferfahrzeug wurde zerstört.", true)
            break
        end
    end
end)

addEventHandler("onPlayerQuit", root, function()
    local player = source
    if playerJobData[player] then
        abortPlayerJob(player, "Verbindung getrennt.", false)
    end
    local accID_quit = getElementData(player, "account_id")
    if accID_quit and pedJobCooldowns[accID_quit] then
        pedJobCooldowns[accID_quit] = nil
    end
end)


addEvent("onClientRequestsBankPedInfo", true)
addEventHandler("onClientRequestsBankPedInfo", root, function(...)
    local clientPlayer = source
    local arg1 = ...
    local clickedPedElement = arg1
    if isElement(clickedPedElement) and getElementType(clickedPedElement) == "ped" then
        local pedId = getElementData(clickedPedElement, "pedIdentifier")
        local pedDefinition = nil
        if pedId then
            pedDefinition = _G.getManagedPedConfigByIdentifier and _G.getManagedPedConfigByIdentifier(pedId) or (exports.tarox and exports.tarox.getManagedPedConfigByIdentifier and exports.tarox.getManagedPedConfigByIdentifier(pedId))
        end
        if pedDefinition and pedDefinition.windowInfo then
            triggerClientEvent(clientPlayer, "onServerSendsBankPedInfo", clientPlayer, pedDefinition.windowInfo)
        elseif pedDefinition and pedDefinition.jobItem then
            -- Job-bezogene Logik (z.B. Bestätigungsfenster öffnen) ist bereits in handlePedAction
        else
            triggerClientEvent(clientPlayer, "onServerSendsBankPedInfo", clientPlayer, {title="Information", messages={"Dieser Charakter hat dir momentan nichts zu sagen."}, buttonText="OK"})
        end
    else
        triggerClientEvent(clientPlayer, "onServerSendsBankPedInfo", clientPlayer, {title="Fehler", messages={"Ungültige Ped-Anfrage."}, buttonText="OK"})
    end
end)


addEventHandler("onResourceStop", resourceRoot, function()
    removeEventHandler("onClientRequestsPedAction", root, handlePedAction)
    for player, jobInfo in pairs(playerJobData) do
        if isElement(player) then
            if isTimer(jobInfo.exitTimer) then killTimer(jobInfo.exitTimer) end
            if isTimer(jobInfo.deliveryTimeLimitTimer) then killTimer(jobInfo.deliveryTimeLimitTimer) end
            if isElement(jobInfo.deliveryMarker) then destroyElement(jobInfo.deliveryMarker) end
            if isElement(jobInfo.vehicle) then destroyElement(jobInfo.vehicle) end
            local blipElement = getElementData(player, "jobDeliveryBlip")
            if isElement(blipElement) then destroyElement(blipElement) end
        end
    end
    playerJobData = {}
    pedJobCooldowns = {}
end)