-- tarox/vehicles/tacho_client.lua
-- Version mit KM-Anzeige IM Tacho, Odometer-Speicherung,
-- Fuel-Icon/% ÜBER alter Balkenposition,
-- breiterer KM-Box mit größerer Schrift,
-- und korrigierter horizontaler KM-Box Position.
-- MODIFIZIERT: Position nach unten rechts verschoben.

local screenW, screenH = guiGetScreenSize()
local localPlayer = getLocalPlayer()

-- Tacho Design Einstellungen
local tachoRadius = 90
-- panelTopY wird nicht mehr für die Hauptpositionierung benötigt
-- local panelTopY = screenH * 0.78 -- AUSKOMMENTIERT/ENTFERNT

-- Styling
local panelBackgroundColor = tocolor(28, 30, 36, 220)
local panelBorderColorLight = tocolor(55, 58, 68, 200)
local panelBorderColorDark = tocolor(20, 22, 28, 220)

local containerWidth = tachoRadius * 2 + 60
local fuelBarHeight = 22
local fuelBarPaddingTop = -7
local bottomPadding = 8
local topPaddingForTacho = 10
local tachoVisualHeight = tachoRadius * 2
local fuelVisualHeight = fuelBarHeight
local containerHeight = topPaddingForTacho + tachoVisualHeight + fuelBarPaddingTop + fuelVisualHeight + bottomPadding
if fuelBarPaddingTop < 0 then
    containerHeight = containerHeight + math.abs(fuelBarPaddingTop)
end

-- [[ HIER BEGINNT DIE ÄNDERUNG ]] --

local tachoOffsetX = 25 -- Abstand vom rechten Rand (ähnlich deinem HUD)
local tachoOffsetY = 25 -- Abstand vom unteren Rand

-- Berechnet die X-Position von rechts
local containerX = screenW - containerWidth - tachoOffsetX

-- Berechnet die Y-Position von unten
local containerY = screenH - containerHeight - tachoOffsetY

-- [[ HIER ENDET DIE ÄNDERUNG ]] --


-- Original Tacho Colors
local speedometerCircleBackgroundColor = tocolor(20, 20, 20, 190)
local needleColor = tocolor(255, 50, 50, 230)
local textColor = tocolor(255, 255, 255, 240)
local textShadowColor = tocolor(0, 0, 0, 190)
local kmhFont = "default-bold"
local kmhFontSize = 1.9
local fuelFont = "default"
local fuelFontSize = 1
local subTextColor = tocolor(210, 210, 210, 210)
local maxSpeedDisplay = 300
local fuelIconPath = "user/client/images/usericons/fuel.png"
local fuelIconSize = 18
local fuelIconPadding = 5
local lockedIconPath = "user/client/images/usericons/locked.png"
local unlockedIconPath = "user/client/images/usericons/unlocked.png"
local lockIconSize = 20
local lockIconColor = tocolor(255, 255, 255, 220)


-- Einstellungen für die KM-Anzeige IM Tacho (oben rechts im Tacho-Kreis)
local tachoOdometerTextXOffset = tachoRadius * 0.85
local tachoOdometerTextYOffset = -tachoRadius * 0.98
local tachoOdometerFont = "default-bold"
local tachoOdometerFontSize = 1
local tachoOdometerColor = tocolor(255, 255, 255, 230) -- Schrift Weiß
local tachoOdometerShadowColor = tocolor(0,0,0,180)
local kmBoxPaddingHorizontal = 12
local kmBoxPaddingVertical = 4
local kmBoxBackgroundColor = tocolor(10,10,10,160)
local kmBoxBorderColor = tocolor(80,80,90,150)


local isCustomSpeedometerActive = false
local speedometerRenderHandler = nil

local vehicleLastPos = {}
local ODOMETER_UPDATE_SERVER_INTERVAL = 3000
local vehicleOdometerTimers = {}

-- ##########################################################################
-- FUNKTIONSDEFINITIONEN
-- ##########################################################################

function getVehicleSpeedKMH(vehicle)
    if not isElement(vehicle) or getElementType(vehicle) ~= "vehicle" then return 0 end
    local vx, vy, vz = getElementVelocity(vehicle)
    return math.floor(math.sqrt(vx*vx + vy*vy + vz*vz) * 180)
end

function updateAndSyncVehicleOdometer(vehicle)
    if not isElement(vehicle) or not vehicleLastPos[vehicle] then return end
    if getPedOccupiedVehicle(localPlayer) ~= vehicle then return end

    local prevData = vehicleLastPos[vehicle]
    local currentX, currentY, currentZ = getElementPosition(vehicle)
    local currentTick = getTickCount()
    local timeDiffSeconds = (currentTick - prevData.lastTick) / 1000

    if timeDiffSeconds <= 0 then return end

    local distanceTraveled = getDistanceBetweenPoints3D(prevData.x, prevData.y, prevData.z, currentX, currentY, currentZ)

    if distanceTraveled > 0.5 then
        local distanceTraveledKM = distanceTraveled / 1000
        local currentOdometer = getElementData(vehicle, "odometer") or 0
        local newOdometer = currentOdometer + distanceTraveledKM
        setElementData(vehicle, "odometer", newOdometer, true)
    end

    vehicleLastPos[vehicle] = { x = currentX, y = currentY, z = currentZ, lastTick = currentTick }
end

local renderCustomSpeedometer -- Vorwärtsdeklaration

local function startSpeedometerRendering()
    if not isCustomSpeedometerActive then
        isCustomSpeedometerActive = true
        if not isEventHandlerAdded("onClientRender", root, renderCustomSpeedometer) then
            speedometerRenderHandler = renderCustomSpeedometer
            addEventHandler("onClientRender", root, speedometerRenderHandler)
        end
    end
    local vehicle = getPedOccupiedVehicle(localPlayer)
    if vehicle and getVehicleController(vehicle) == localPlayer then
        local px, py, pz = getElementPosition(vehicle)
        local initialOdometer = getElementData(vehicle, "odometer") or 0
        vehicleLastPos[vehicle] = { x = px, y = py, z = pz, lastTick = getTickCount(), initialOdometer = initialOdometer }

        if vehicleOdometerTimers[vehicle] and isTimer(vehicleOdometerTimers[vehicle]) then
            killTimer(vehicleOdometerTimers[vehicle])
        end
        vehicleOdometerTimers[vehicle] = setTimer(updateAndSyncVehicleOdometer, ODOMETER_UPDATE_SERVER_INTERVAL, 0, vehicle)
    end
end

local function stopSpeedometerRendering(vehicleElement)
    local vehicleToStopTimerFor = vehicleElement or (getPedOccupiedVehicle(localPlayer) or (isElement(source) and getElementType(source) == "vehicle" and source))

    if vehicleToStopTimerFor and vehicleOdometerTimers[vehicleToStopTimerFor] and isTimer(vehicleOdometerTimers[vehicleToStopTimerFor]) then
        killTimer(vehicleOdometerTimers[vehicleToStopTimerFor])
        vehicleOdometerTimers[vehicleToStopTimerFor] = nil
        if vehicleLastPos[vehicleToStopTimerFor] then
            updateAndSyncVehicleOdometer(vehicleToStopTimerFor)
        end
        vehicleLastPos[vehicleToStopTimerFor] = nil
    end

    if not getPedOccupiedVehicle(localPlayer) then
        if isCustomSpeedometerActive then
            isCustomSpeedometerActive = false
            if speedometerRenderHandler and isEventHandlerAdded("onClientRender", root, speedometerRenderHandler) then
                removeEventHandler("onClientRender", root, speedometerRenderHandler)
                speedometerRenderHandler = nil
            end
        end
    end
end


-- ##########################################################################
-- HAUPT-RENDERFUNKTION
-- ##########################################################################
renderCustomSpeedometer = function()
    if not isCustomSpeedometerActive then return end
    local vehicle = getPedOccupiedVehicle(localPlayer)

    if vehicle and getVehicleController(vehicle) == localPlayer then
        local currentSpeed = getVehicleSpeedKMH(vehicle)
        local fuelPercent = getElementData(vehicle, "fuel") or 0
        local isLocked = (getElementData(vehicle, "locked") == 1)
        local odometerValue = getElementData(vehicle, "odometer") or 0

        -- Container Hintergrund
        dxDrawRectangle(containerX, containerY, containerWidth, containerHeight, panelBackgroundColor)
        dxDrawLine(containerX, containerY, containerX + containerWidth, containerY, panelBorderColorLight, 2)
        dxDrawLine(containerX, containerY + containerHeight, containerX + containerWidth, containerY + containerHeight, panelBorderColorDark, 2)
        dxDrawLine(containerX, containerY, containerX, containerY + containerHeight, panelBorderColorLight, 2)
        dxDrawLine(containerX + containerWidth, containerY, containerX + containerWidth, containerY + containerHeight, panelBorderColorDark, 2)

        -- Tacho-Kreis Positionierung
        local tachoAreaWidthForCentering = containerWidth
        local actualTachoCenterX = containerX + tachoAreaWidthForCentering / 2
        local actualTachoCenterY = containerY + topPaddingForTacho + tachoRadius

        -- Tacho-Kreis zeichnen
        dxDrawCircle(actualTachoCenterX, actualTachoCenterY, tachoRadius, speedometerCircleBackgroundColor, speedometerCircleBackgroundColor, 48, 1)
        dxDrawCircle(actualTachoCenterX, actualTachoCenterY, tachoRadius + 3, tocolor(60,60,60,180), tocolor(60,60,60,180), 48, 1)

        -- Lock-Icon
        local currentLockIconPath = isLocked and lockedIconPath or unlockedIconPath
        if fileExists(currentLockIconPath) then
            local lockIconXOffsetFactor = 1.2; local lockIconYOffsetFactor = 1
            local lockIconX = actualTachoCenterX - tachoRadius * lockIconXOffsetFactor + (lockIconSize * 0.1)
            local lockIconY = actualTachoCenterY - tachoRadius * lockIconYOffsetFactor + (lockIconSize * 0.1)
            dxDrawImage(lockIconX, lockIconY, lockIconSize, lockIconSize, currentLockIconPath, 0,0,0, lockIconColor)
        end

        -- Nadel, Skala, Geschwindigkeitsanzeige (KM/H in der Mitte)
        local speedStartAngle = -225; local speedEndAngle = 45; local speedAngleRange = speedEndAngle - speedStartAngle
        local speedNormalized = math.min(currentSpeed / maxSpeedDisplay, 1.0)
        local currentSpeedAngle = speedStartAngle + speedNormalized * speedAngleRange
        local needleLength = tachoRadius * 0.82
        local needleEndX = actualTachoCenterX + needleLength * math.cos(math.rad(currentSpeedAngle))
        local needleEndY = actualTachoCenterY + needleLength * math.sin(math.rad(currentSpeedAngle))
        dxDrawLine(actualTachoCenterX, actualTachoCenterY, needleEndX, needleEndY, needleColor, 3, true)
        dxDrawCircle(actualTachoCenterX, actualTachoCenterY, 6, needleColor, needleColor, 24, 1)
        local scaleRadius = tachoRadius * 0.9; local numMainLines = 11; local speedStep = 30
        for i = 0, numMainLines -1 do
            local currentMarkSpeed = i * speedStep; local percent = currentMarkSpeed / maxSpeedDisplay
            local angle = speedStartAngle + percent * speedAngleRange
            local lineLength = 8; local lineThickness = 1.5
            if currentMarkSpeed % 60 == 0 then lineLength = 13; lineThickness = 2.2; end
            local x1 = actualTachoCenterX + (scaleRadius - lineLength) * math.cos(math.rad(angle))
            local y1 = actualTachoCenterY + (scaleRadius - lineLength) * math.sin(math.rad(angle))
            local x2 = actualTachoCenterX + scaleRadius * math.cos(math.rad(angle))
            local y2 = actualTachoCenterY + scaleRadius * math.sin(math.rad(angle))
            dxDrawLine(x1, y1, x2, y2, textColor, lineThickness, true)
            if currentMarkSpeed % 30 == 0 then
                local textRadius = scaleRadius - (lineLength + 12); local textAngleOffset = 0
                if currentMarkSpeed == 0 then textAngleOffset = 3.5 elseif currentMarkSpeed == maxSpeedDisplay then textAngleOffset = -3.5 end
                local textX = actualTachoCenterX + textRadius * math.cos(math.rad(angle + textAngleOffset))
                local textY = actualTachoCenterY + textRadius * math.sin(math.rad(angle + textAngleOffset))
                dxDrawText(tostring(math.floor(currentMarkSpeed)), textX, textY, textX, textY, subTextColor, 0.70, "default-bold", "center", "center", false, false, true, false, false)
            end
        end
        local speedDisplayText = tostring(currentSpeed)
        local speedTextFontHeight = tonumber(dxGetFontHeight(kmhFontSize, kmhFont)) or 20
        local kmhLabelTextHeight = tonumber(dxGetFontHeight(0.75, "default-bold")) or 10
        local digitalDisplayAnchorY = actualTachoCenterY + tachoRadius * 0.30
        local totalDigitalBlockHeight = speedTextFontHeight + kmhLabelTextHeight * 0.7
        local speedTextActualY = digitalDisplayAnchorY - totalDigitalBlockHeight / 2
        local kmhLabelActualY = speedTextActualY + speedTextFontHeight * 0.85
        dxDrawText(speedDisplayText, actualTachoCenterX + 1, speedTextActualY + 1, actualTachoCenterX + 1, speedTextActualY + 1, textShadowColor, kmhFontSize, kmhFont, "center", "top", false, false, true, false, false)
        dxDrawText(speedDisplayText, actualTachoCenterX, speedTextActualY, actualTachoCenterX, speedTextActualY, textColor, kmhFontSize, kmhFont, "center", "top", false, false, true, false, false)
        dxDrawText("KM/H", actualTachoCenterX + 1, kmhLabelActualY + 1, actualTachoCenterX + 1, kmhLabelActualY + 1, textShadowColor, 0.75, "default-bold", "center", "top", false, false, true, false, false)
        dxDrawText("KM/H", actualTachoCenterX, kmhLabelActualY, actualTachoCenterX, kmhLabelActualY, subTextColor, 0.75, "default-bold", "center", "top", false, false, true, false, false)

        -- Kilometer-Anzeige IM Tacho (oben rechts)
        local kmDisplayText = string.format("%.1f KM", odometerValue)
        local kmTextDrawX = actualTachoCenterX + tachoOdometerTextXOffset
        local kmTextDrawY = actualTachoCenterY + tachoOdometerTextYOffset
        local kmTextDisplayWidth = dxGetTextWidth(kmDisplayText, tachoOdometerFontSize, tachoOdometerFont)
        local kmTextDisplayHeight = dxGetFontHeight(tachoOdometerFontSize, tachoOdometerFont)
        local boxX = kmTextDrawX - (kmTextDisplayWidth / 2) - kmBoxPaddingHorizontal
        local boxY = kmTextDrawY - (kmTextDisplayHeight / 2) - kmBoxPaddingVertical / 2
        local boxW = kmTextDisplayWidth + kmBoxPaddingHorizontal * 2
        local boxH = kmTextDisplayHeight + kmBoxPaddingVertical
        dxDrawRectangle(boxX, boxY, boxW, boxH, kmBoxBackgroundColor)
        dxDrawLine(boxX, boxY, boxX + boxW, boxY, kmBoxBorderColor, 1)
        dxDrawLine(boxX, boxY + boxH, boxX + boxW, boxY + boxH, kmBoxBorderColor, 1)
        dxDrawText(kmDisplayText, boxX + 1, boxY + 1, boxX + boxW + 1, boxY + boxH + 1, tachoOdometerShadowColor, tachoOdometerFontSize, tachoOdometerFont, "center", "center", false, false, false, true)
        dxDrawText(kmDisplayText, boxX, boxY, boxX + boxW, boxY + boxH, tachoOdometerColor, tachoOdometerFontSize, tachoOdometerFont, "center", "center", false, false, false, true)

        -- Tankfüllstand (NUR ICON UND PROZENTTEXT)
        local fuelBarWidthCalculated = tachoAreaWidthForCentering
        local fuelBarX = containerX + (containerWidth - fuelBarWidthCalculated) / 2
        local originalFuelBarY = actualTachoCenterY + tachoRadius + fuelBarPaddingTop
        local fuelIconAndTextY = originalFuelBarY + (fuelBarHeight - fuelIconSize) / 2

        local fuelTextDisplay = string.format("%.0f%%", (tonumber(fuelPercent) or 0) )
        local fuelTextWidth = dxGetTextWidth(fuelTextDisplay, fuelFontSize, fuelFont)
        local totalFuelDisplayWidth = fuelIconSize + fuelIconPadding + fuelTextWidth
        local fuelDisplayStartX = actualTachoCenterX - (totalFuelDisplayWidth / 2)

        if fileExists(fuelIconPath) then
            local iconColor = tocolor(255,255,255,255)
            dxDrawImage(fuelDisplayStartX, fuelIconAndTextY, fuelIconSize, fuelIconSize, fuelIconPath, 0, 0, 0, iconColor)
        end
        
        local fuelTextX = fuelDisplayStartX + fuelIconSize + fuelIconPadding
        local fuelTextActualY = fuelIconAndTextY + (fuelIconSize - dxGetFontHeight(fuelFontSize, fuelFont))/2
        dxDrawText(fuelTextDisplay, fuelTextX + 1, fuelTextActualY + 1, 0,0, textShadowColor, fuelFontSize, fuelFont, "left", "top", false, false, false, false)
        dxDrawText(fuelTextDisplay, fuelTextX, fuelTextActualY, 0,0, textColor, fuelFontSize, fuelFont, "left", "top", false, false, false, false)

    else
        local lastVehicle = nil
        for veh, _ in pairs(vehicleOdometerTimers) do
            if isElement(veh) then lastVehicle = veh; break; end
        end
        stopSpeedometerRendering(lastVehicle)
    end
end

-- ##########################################################################
-- EVENT HANDLER
-- ##########################################################################
addEventHandler("onClientPlayerVehicleEnter", root, function(vehicleElement, seat)
    if source == localPlayer and seat == 0 then
        local initialOdometer = getElementData(vehicleElement, "odometer") or 0
        setElementData(vehicleElement, "odometer", initialOdometer, false)
        startSpeedometerRendering()
    end
end)

addEventHandler("onClientPlayerVehicleExit", root, function(vehicleElement, seat)
    if source == localPlayer and seat == 0 then
        stopSpeedometerRendering(vehicleElement)
    end
end)

addEventHandler("onClientPlayerWasted", localPlayer, function()
    local vehicle = getPedOccupiedVehicle(localPlayer)
    stopSpeedometerRendering(vehicle)
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    local currentVehicle = getPedOccupiedVehicle(localPlayer)
    if currentVehicle and getVehicleController(currentVehicle) == localPlayer then
        local initialOdometer = getElementData(currentVehicle, "odometer") or 0
        setElementData(currentVehicle, "odometer", initialOdometer, false)
        startSpeedometerRendering()
    else
        stopSpeedometerRendering(nil)
    end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    for vehicle, timer in pairs(vehicleOdometerTimers) do
        if isElement(vehicle) and isTimer(timer) then
            killTimer(timer)
            if vehicleLastPos[vehicle] then updateAndSyncVehicleOdometer(vehicle) end
        end
    end
    vehicleOdometerTimers = {}
    vehicleLastPos = {}
    stopSpeedometerRendering(nil)
end)