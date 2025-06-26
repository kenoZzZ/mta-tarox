-- taroxgps/territory_client.lua (VERSION 5.5 - Mit DYNAMISCHEM Pickup-Streaming)

local localPlayer = getLocalPlayer()
local screenW, screenH = guiGetScreenSize()

-- Schriftarten
local bigMapFont = dxCreateFont("files/fonts/eroberung.ttf", 12)
local miniMapFont = dxCreateFont("files/fonts/eroberung.ttf", 8)
local dxFont = "default-bold"

local clientTerritories = {}
local factionColors = {
    [0] = { 20, 120, 20, 100 }, [1] = { 0, 123, 255, 100 }, [2] = { 52, 58, 64, 100 },
    [3] = { 40, 167, 69, 100 },  [4] = { 139, 0, 0, 100 }, [5] = { 128, 0, 128, 100 },
    [6] = { 220, 53, 69, 100 },  [7] = { 0, 100, 200, 100 }
}
local factionNames = {
    [0] = "Neutral", [1] = "Police Department", [2] = "S.W.A.T.",
    [3] = "San Andreas Medical Department", [4] = "Cosa Nostra",
    [5] = "Mocro Mafia", [6] = "Yakuza", [7] = "Mechanics"
}

local isTerritoryInfoGUIVisible = false
local currentTerritoryInfo = {}
local territoryInfoGUIElements = {}
local territoryPickups = {}

local canConquerCurrentTerritory = false
local conquestData = {} 
local isRenderHandlerActive = false

local activePreparationUI = {}
local isPreparationRenderHandlerActive = false

-- NEUE LOGIK: Timer für die Verwaltung der Pickups
local pickupManagementTimer = nil
local STREAM_DISTANCE = 300.0 -- Die Distanz, in der Pickups sichtbar werden

-- NEUE FUNKTION: Verwaltet das Erstellen und Zerstören der Pickups basierend auf der Spielerposition
function manageTerritoryPickups()
    if not clientTerritories or not next(clientTerritories) then return end

    local pX, pY, _ = getElementPosition(localPlayer)

    for id, data in pairs(clientTerritories) do
        -- Berechne die 2D-Distanz zum Gebietszentrum
        local distance = getDistanceBetweenPoints2D(pX, pY, data.posX, data.posY)

        -- Wenn der Spieler nah genug ist und das Pickup noch nicht existiert -> Erstellen
        if distance <= STREAM_DISTANCE then
            if not territoryPickups[id] or not isElement(territoryPickups[id]) then
                local groundZ = getGroundPosition(data.posX, data.posY, 20.0)
                if groundZ then
                    local pickup = createPickup(data.posX, data.posY, groundZ + 0.5, 3, 1318, 500)
                    if isElement(pickup) then
                        setElementData(pickup, "territoryID", id, false)
                        addEventHandler("onClientPickupHit", pickup, handleTerritoryPickupHit, false)
                        territoryPickups[id] = pickup
                    end
                end
            end
        -- Wenn der Spieler zu weit weg ist und das Pickup existiert -> Zerstören
        elseif territoryPickups[id] and isElement(territoryPickups[id]) then
            destroyElement(territoryPickups[id])
            territoryPickups[id] = nil
        end
    end
end

addEvent("territories:syncAll", true)
addEventHandler("territories:syncAll", root, function(serverTerritories)
    if type(serverTerritories) == "table" then
        clientTerritories = serverTerritories
        
        -- Stoppe einen eventuell laufenden alten Timer
        if isTimer(pickupManagementTimer) then
            killTimer(pickupManagementTimer)
        end
        
        -- Starte den neuen Management-Timer, der alle 2 Sekunden läuft
        pickupManagementTimer = setTimer(manageTerritoryPickups, 2000, 0)
        
        -- Führe die Funktion einmal direkt aus, um sofort Pickups in der Nähe zu erstellen
        manageTerritoryPickups()
    end
end)

-- MTA 3.2.1/taroxgps/territory_client.lua

-- NEUE ZUVERLÄSSIGE VERSION DES EVENT-HANDLERS
addEvent("territory:startPreparationPhase", true)
addEventHandler("territory:startPreparationPhase", root, function(territoryName, attackerName, defenderName, attackerFid, defenderFid, duration, attackingPlayer)
    -- Diese Version zeigt den Timer für alle an, um Fehler zu vermeiden,
    -- aber sie erkennt den Angreifer zuverlässig für die korrekte Textanzeige.

    local isAttacker = (attackingPlayer and attackingPlayer == localPlayer)

    activePreparationUI[territoryName] = {
        isAttacker = isAttacker,
        endTime = getTickCount() + duration
    }

    if not isPreparationRenderHandlerActive then
        addEventHandler("onClientRender", root, renderPreparationCountdown)
        isPreparationRenderHandlerActive = true
    end
end)

-- NEUE RENDER-FUNKTION MIT DEINEN GEWÜNSCHTEN TEXTEN
function renderPreparationCountdown()
    if not next(activePreparationUI) then
        if isPreparationRenderHandlerActive then
            removeEventHandler("onClientRender", root, renderPreparationCountdown)
            isPreparationRenderHandlerActive = false
        end
        return
    end

    -- Wir gehen alle aktiven UI-Elemente durch (normalerweise nur eins)
    for territoryName, data in pairs(activePreparationUI) do
        local remainingMs = data.endTime - getTickCount()

        if remainingMs <= 0 then
            activePreparationUI[territoryName] = nil
        else
            -- Zeit berechnen
            local totalSeconds = math.floor(remainingMs / 1000)
            local minutes = math.floor(totalSeconds / 60)
            local seconds = totalSeconds % 60
            local timeString = string.format("%02d:%02d", minutes, seconds)

            local mainText
            -- Hier wird der Text basierend auf deiner Anforderung und dem 'isAttacker'-Flag geändert
            if data.isAttacker then
                mainText = "Angriff beginnt in (" .. timeString .. "min)"
            else
                -- Für alle anderen (inkl. Verteidiger)
                mainText = "Verteidigung gestartet (" .. timeString .. "min)"
            end

            -- Der Code zum Zeichnen des Textes bleibt gleich
            local textScale = 1.8
            local textW = dxGetTextWidth(mainText, textScale, "default-bold")
            dxDrawText(
                mainText,
                (screenW - textW) / 2,
                screenH * 0.15,
                0, 0,
                tocolor(255, 200, 0, 240),
                textScale,
                "default-bold",
                "left", "top",
                false, false, false, true
            )
        end
    end
end

addEvent("territories:updateSingle", true)
addEventHandler("territories:updateSingle", root, function(territoryId, newFactionId)
    if clientTerritories and clientTerritories[territoryId] then
        clientTerritories[territoryId].owner_faction_id = newFactionId
    end
end)

addEvent("territory:startConquestUI", true)
addEventHandler("territory:startConquestUI", root, function(territoryId)
    if isTerritoryInfoGUIVisible and currentTerritoryInfo.id == territoryId then
        canConquerCurrentTerritory = true
    end
end)

addEvent("territory:updateConquestState", true)
addEventHandler("territory:updateConquestState", root, function(territoryId, remainingDuration, isPaused)
    if isPaused then
        if conquestData[territoryId] then
            conquestData[territoryId].isPaused = true
        end
    else
        conquestData[territoryId] = {
            endTime = getTickCount() + remainingDuration,
            isPaused = false
        }
    end
    
    if not isRenderHandlerActive then
        addEventHandler("onClientRender", root, renderConquestTimers)
        isRenderHandlerActive = true
    end
end)

addEvent("territory:conquestFinished", true)
addEventHandler("territory:conquestFinished", root, function(territoryId, success)
    if conquestData[territoryId] then
        conquestData[territoryId] = nil
    end
end)

function handleTerritoryPickupHit(hitPlayer)
    if hitPlayer ~= localPlayer or isPedInVehicle(hitPlayer) then return end
    local id = getElementData(source, "territoryID")
    local data = clientTerritories[id]
    if data then
        openTerritoryInfoGUI(data)
        triggerServerEvent("territory:playerHitPickup", localPlayer, id)
    end
end

function openTerritoryInfoGUI(data)
    if isTerritoryInfoGUIVisible then return end
    isTerritoryInfoGUIVisible = true
    canConquerCurrentTerritory = false
    currentTerritoryInfo = data
    showCursor(true)
    guiSetInputMode("no_binds_when_editing")
    addEventHandler("onClientRender", root, renderTerritoryInfoGUI)
    addEventHandler("onClientClick", root, handleTerritoryGUIClick, true)
    addEventHandler("onClientKey", root, handleTerritoryGUIKey, true)
end

function closeTerritoryInfoGUI()
    if not isTerritoryInfoGUIVisible then return end
    isTerritoryInfoGUIVisible = false
    canConquerCurrentTerritory = false
    currentTerritoryInfo = {}
    showCursor(false)
    guiSetInputMode("allow_binds")
    removeEventHandler("onClientRender", root, renderTerritoryInfoGUI)
    removeEventHandler("onClientClick", root, handleTerritoryGUIClick)
    removeEventHandler("onClientKey", root, handleTerritoryGUIKey)
end

function renderTerritoryInfoGUI()
    if not isTerritoryInfoGUIVisible then return end
    local screenW, screenH = guiGetScreenSize()
    local w, h = 350, 250 
    if not canConquerCurrentTerritory then h = 200 end
    local x, y = (screenW - w) / 2, (screenH - h) / 2
    dxDrawRectangle(x, y, w, h, tocolor(28, 30, 36, 230))
    dxDrawRectangle(x, y, w, 40, tocolor(38, 40, 48, 240))
    dxDrawText("Gebietsinformation", x, y, x + w, y + 40, tocolor(255,255,255), 1.2, "default-bold", "center", "center")
    local textY = y + 60
    dxDrawText("Gebiet:", x + 20, textY, x + w - 20, textY + 20, tocolor(180,180,190), 1.0, "default", "left", "top")
    dxDrawText(currentTerritoryInfo.name or "Unbekannt", x + 20, textY, x + w - 20, textY + 20, tocolor(255,255,255), 1.1, "default-bold", "right", "top")
    textY = textY + 35
    local ownerID = currentTerritoryInfo.owner_faction_id or 0
    local ownerName = factionNames[ownerID] or "Unbekannt"
    local ownerColor = factionColors[ownerID] or {180,180,180,255}
    dxDrawText("Aktueller Besitzer:", x + 20, textY, x + w - 20, textY + 20, tocolor(180,180,190), 1.0, "default", "left", "top")
    dxDrawText(ownerName, x + 20, textY, x + w - 20, textY + 20, tocolor(ownerColor[1], ownerColor[2], ownerColor[3], 255), 1.1, "default-bold", "right", "top")
    local btnW, btnH = 150, 40
    local btnCloseX = x + (w - btnW) / 2
    local btnCloseY = y + h - btnH - 15
    if canConquerCurrentTerritory then
        btnCloseY = y + h - (btnH*2 + 20)
        local btnConquerX = btnCloseX
        local btnConquerY = btnCloseY + btnH + 10
        dxDrawRectangle(btnConquerX, btnConquerY, btnW, btnH, tocolor(200, 50, 50, 220))
        dxDrawText("Gebiet erobern", btnConquerX, btnConquerY, btnConquerX + btnW, btnConquerY + btnH, tocolor(255,255,255), 1.0, "default-bold", "center", "center")
        territoryInfoGUIElements.conquerButton = { x = btnConquerX, y = btnConquerY, w = btnW, h = btnH }
    else
        territoryInfoGUIElements.conquerButton = nil
    end
    dxDrawRectangle(btnCloseX, btnCloseY, btnW, btnH, tocolor(50,50,60,220))
    dxDrawText("Schließen", btnCloseX, btnCloseY, btnCloseX + btnW, btnCloseY + btnH, tocolor(255,255,255), 1.0, "default-bold", "center", "center")
    territoryInfoGUIElements.closeButton = { x = btnCloseX, y = btnCloseY, w = btnW, h = btnH }
end

function handleTerritoryGUIClick(button, state)
    if not isTerritoryInfoGUIVisible or button ~= "left" or state ~= "up" then return end
    local cX, cY = getCursorPosition(); if not cX then return end
    local mX, mY = cX * screenW, cY * screenH
    local btnClose = territoryInfoGUIElements.closeButton
    if btnClose and mX >= btnClose.x and mX <= btnClose.x + btnClose.w and mY >= btnClose.y and mY <= btnClose.y + btnClose.h then
        closeTerritoryInfoGUI(); return
    end
    local btnConquer = territoryInfoGUIElements.conquerButton
    if btnConquer and mX >= btnConquer.x and mX <= btnConquer.x + btnConquer.w and mY >= btnConquer.y and mY <= btnConquer.y + btnConquer.h then
        triggerServerEvent("territory:requestConquestStart", localPlayer, currentTerritoryInfo.id)
        closeTerritoryInfoGUI(); return
    end
end

function handleTerritoryGUIKey(key, press)
    if not isTerritoryInfoGUIVisible or key ~= "escape" or not press then return end
    closeTerritoryInfoGUI()
end

function renderConquestTimers()
    if not next(conquestData) then
        if isRenderHandlerActive then removeEventHandler("onClientRender", root, renderConquestTimers); isRenderHandlerActive = false; end
        return
    end
    local px, py, pz = getElementPosition(localPlayer)
    for id, data in pairs(conquestData) do
        local territoryData = clientTerritories[id]
        if territoryData then
            local pz_ground = getGroundPosition(px, py, pz)
            local dist = getDistanceBetweenPoints3D(px, py, pz_ground, territoryData.posX, territoryData.posY, getGroundPosition(territoryData.posX, territoryData.posY, 20))
            if dist < 150 then
                local text
                if data.isPaused then
                    text = "Eroberung von '"..territoryData.name.."' PAUSIERT (Feind im Gebiet)"
                else
                    local remainingMs = data.endTime - getTickCount()
                    if remainingMs <= 0 then text = "Eroberung von '"..territoryData.name.."' beendet..."; conquestData[id] = nil
                    else local totalSec = math.floor(remainingMs / 1000); text = string.format("Eroberung von '%s': %d Sekunden", territoryData.name, totalSec); end
                end
                if text then
                    local textScale = 1.8
                    local textW = dxGetTextWidth(text, textScale, "default-bold")
                    dxDrawText(text, (screenW - textW) / 2, screenH * 0.15, 0, 0, tocolor(255, 200, 0, 240), textScale, "default-bold", "left", "top", false, false, false, true)
                end
            end
        end
    end
end

function renderTerritories()
    if not Bigmap or not Bigmap.IsVisible then return end
    for id, data in pairs(clientTerritories) do
        local worldCenterX, worldCenterY = data.posX, data.posY
        local worldSizeX, worldSizeY = data.sizeX, data.sizeY
        local worldX1 = worldCenterX - (worldSizeX / 2); local worldY1 = worldCenterY + (worldSizeY / 2)
        local worldX2 = worldCenterX + (worldSizeX / 2); local worldY2 = worldCenterY - (worldSizeY / 2)
        local mapX1, mapY1 = getMapFromWorldPosition(worldX1, worldY1)
        local mapX2, mapY2 = getMapFromWorldPosition(worldX2, worldY2)
        if mapX1 and mapY1 and mapX2 and mapY2 then
            local mapW, mapH = mapX2 - mapX1, mapY2 - mapY1
            local color = factionColors[data.owner_faction_id] or factionColors[0]
            dxDrawRoundedRectangle(mapX1, mapY1, mapW, mapH, tocolor(color[1], color[2], color[3], color[4]), 5)
            local ownerFid = data.owner_faction_id or 0
            if ownerFid ~= 0 and bigMapFont then
                local factionName = factionNames[ownerFid]
                if factionName then
                    local centerX = mapX1 + mapW / 2; local centerY = mapY1 + mapH / 2; local textScale = 0.7
                    dxDrawText(factionName, centerX + 1, centerY + 1, centerX + 1, centerY + 1, tocolor(0, 0, 0, 220), textScale, textScale, bigMapFont, "center", "center", false, false, false)
                    dxDrawText(factionName, centerX, centerY, centerX, centerY, tocolor(255, 255, 255, 255), textScale, textScale, bigMapFont, "center", "center", false, false, false)
                end
            end
        end
    end
end

function convertWorldToMinimapRT(worldX, worldY, mapSectionX, mapSectionY, mapSectionWidth, renderTargetSize) if not Minimap or not Minimap.TextureSize then return 0, 0 end; local mapUnit = Minimap.TextureSize / 6000; local textureX = (worldX + 3000) * mapUnit; local textureY = (-worldY + 3000) * mapUnit; local relativeX = textureX - mapSectionX; local relativeY = textureY - mapSectionY; local scale = renderTargetSize / mapSectionWidth; return relativeX * scale, relativeY * scale end

function renderTerritoriesOnMinimap(mapX, mapY, mapWidth, mapHeight, targetSize)
    if not Minimap or not Minimap.IsVisible or not clientTerritories or not Minimap.TextureSize then return end
    for id, data in pairs(clientTerritories) do
        local worldCenterX, worldCenterY = data.posX, data.posY; local worldSizeX, worldSizeY = data.sizeX, data.sizeY
        local worldTopLeftX = worldCenterX - (worldSizeX / 2); local worldTopLeftY = worldCenterY + (worldSizeY / 2)
        local renderX, renderY = convertWorldToMinimapRT(worldTopLeftX, worldTopLeftY, mapX, mapY, mapWidth, targetSize)
        local scale = targetSize / mapWidth
        local renderW = (worldSizeX / 6000 * Minimap.TextureSize) * scale; local renderH = (worldSizeY / 6000 * Minimap.TextureSize) * scale
        local colorData = factionColors[data.owner_faction_id] or factionColors[0]; local drawColor = tocolor(colorData[1], colorData[2], colorData[3], colorData[4] - 20)
        dxDrawRectangle(renderX, renderY, renderW, renderH, drawColor, false)
        local ownerFid = data.owner_faction_id or 0
        if ownerFid ~= 0 and miniMapFont then
            local factionName = factionNames[ownerFid]
            if factionName then
                dxDrawText(factionName, renderX + 1, renderY + 1, renderX + renderW + 1, renderY + renderH + 1, tocolor(0, 0, 0, 200), 1.0, 1.0, miniMapFont, "center", "center", true, true)
                dxDrawText(factionName, renderX, renderY, renderX + renderW, renderY + renderH, tocolor(255, 255, 255, 245), 1.0, 1.0, miniMapFont, "center", "center", true, true)
            end
        end
    end
end

function dxDrawRoundedRectangle(x, y, w, h, color, radius) radius = math.min(radius, w / 2, h / 2); dxDrawRectangle(x + radius, y, w - 2 * radius, h, color); dxDrawRectangle(x, y + radius, w, h - 2 * radius, color); dxDrawCircle(x + radius, y + radius, radius, color, color, 36, 180, 90); dxDrawCircle(x + w - radius, y + radius, radius, color, color, 36, 270, 90); dxDrawCircle(x + radius, y + h - radius, radius, color, color, 36, 90, 90); dxDrawCircle(x + w - radius, y + h - radius, radius, color, color, 36, 0, 90) end

addEventHandler("onClientResourceStart", resourceRoot, function()
    -- Fordere die Gebietsdaten vom Server an, wenn die Ressource startet
    triggerServerEvent("territories:requestSync", localPlayer)
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    -- Stoppe alle laufenden Prozesse des Skripts sauber
    closeTerritoryInfoGUI()

    -- Stoppe den Management-Timer
    if isTimer(pickupManagementTimer) then
        killTimer(pickupManagementTimer)
        pickupManagementTimer = nil
    end

    -- Zerstöre alle noch existierenden Pickups
    for id, pickup in pairs(territoryPickups) do
        if isElement(pickup) then destroyElement(pickup) end
    end
    territoryPickups = {}
    
    conquestData = {}
    activePreparationUI = {}
    if isRenderHandlerActive then removeEventHandler("onClientRender", root, renderConquestTimers); isRenderHandlerActive = false; end
    if isPreparationRenderHandlerActive then removeEventHandler("onClientRender", root, renderPreparationCountdown); isPreparationRenderHandlerActive = false; end
end)