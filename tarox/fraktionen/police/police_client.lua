-- tarox/fraktionen/police/police_client.lua (CLIENT-Side)
-- << GEÄNDERT >> Angepasstes GUI für On-Duty/Off-Duty

local screenW, screenH = guiGetScreenSize()

----------------------------------------------------------------------
-- 1) Police Management-GUI
----------------------------------------------------------------------
local isPolicePanelVisible = false
local policeRank = 0

addEvent("openPoliceManagement", true)
addEventHandler("openPoliceManagement", root, function(rank)
    if isPolicePanelVisible or isWantedPlayersGUIVisible then return end -- isWantedPlayersGUIVisible muss definiert sein oder entfernt werden
    policeRank = rank
    isPolicePanelVisible = true
    showCursor(true)
    guiSetInputMode("no_binds_when_editing")
    addEventHandler("onClientRender", root, renderPolicePanel)
end)

function closePolicePanel()
    if not isPolicePanelVisible then return end
    isPolicePanelVisible = false
    showCursor(false)
    guiSetInputMode("allow_binds")
    removeEventHandler("onClientRender", root, renderPolicePanel)
end

function renderPolicePanel()
    if not isPolicePanelVisible then return end
    local w, h = 400, 280 -- Höhe für zusätzlichen Button angepasst
    local x, y = (screenW - w) / 2, (screenH - h) / 2

    -- Hintergrund und Titel
    dxDrawRectangle(x, y, w, h, tocolor(0, 0, 50, 200))
    dxDrawText("Police Department", x, y + 5, x + w, y + 40,
        tocolor(255, 255, 255), 1.4, "default-bold", "center", "top")
    dxDrawText("Rang: "..policeRank, x + 10, y + 50, x + w - 10, y + 80,
        tocolor(255,255,255), 1.2, "default-bold", "center", "top")

    -- Button "Dienst antreten"
    local btnOnDutyY = y + 90
    dxDrawRectangle(x + 50, btnOnDutyY, 300, 40, tocolor(0, 150, 0, 200))
    dxDrawText("Dienst antreten", x + 50, btnOnDutyY, x + 350, btnOnDutyY + 40,
        tocolor(255,255,255), 1.2, "default-bold", "center", "center")

    -- Button "Dienst verlassen" -- << NEU
    local btnOffDutyY = btnOnDutyY + 40 + 10 -- 10px Abstand
    dxDrawRectangle(x + 50, btnOffDutyY, 300, 40, tocolor(150, 150, 0, 200))
    dxDrawText("Dienst verlassen", x + 50, btnOffDutyY, x + 350, btnOffDutyY + 40,
        tocolor(255,255,255), 1.2, "default-bold", "center", "center")

    -- Button "Schließen"
    local btnCloseY = btnOffDutyY + 40 + 10 -- 10px Abstand
    dxDrawRectangle(x + 50, btnCloseY, 300, 40, tocolor(200, 0, 0, 200))
    dxDrawText("Schließen", x + 50, btnCloseY, x + 350, btnCloseY + 40,
        tocolor(255,255,255), 1.2, "default-bold", "center", "center")
end

addEventHandler("onClientClick", root, function(button, state, absX, absY)
    if not isPolicePanelVisible or button ~= "left" or state ~= "up" then return end
    local w, h = 400, 280 -- Höhe angepasst
    local x, y = (screenW - w) / 2, (screenH - h) / 2

    local btnOnDutyY = y + 90
    local btnOffDutyY = btnOnDutyY + 40 + 10
    local btnCloseY = btnOffDutyY + 40 + 10

    -- Dienst antreten
    if absX >= x + 50 and absX <= x + 350 and absY >= btnOnDutyY and absY <= btnOnDutyY + 40 then
        triggerServerEvent("spawnPoliceOfficer", localPlayer) -- Dieses Event löst jetzt das "Dienst antreten" aus
        closePolicePanel()
        return
    end
    -- Dienst verlassen -- << NEU
    if absX >= x + 50 and absX <= x + 350 and absY >= btnOffDutyY and absY <= btnOffDutyY + 40 then
        triggerServerEvent("onPoliceRequestOffDuty", localPlayer)
        closePolicePanel()
        return
    end
    -- Schließen
    if absX >= x + 50 and absX <= x + 350 and absY >= btnCloseY and absY <= btnCloseY + 40 then
        closePolicePanel()
        return
    end
end)

----------------------------------------------------------------------
-- 2) Automatische Police-Gates (unverändert)
----------------------------------------------------------------------
local objects = {}
local objectsConfig = {
    { index = 1, type  = "position", model = 980,
        posX  = -1635.3000488281, posY  = 688.29998779297,
        closedZ = 9, openZ   = 13.699999809265, checkRadius = 15 },
    { index = 2, type  = "rotation", model = 968,
        posX  = -1572.1999511719, posY  = 658.90002441406, posZ  = 7.0999999046326,
        startRot = { x = 0, y = 90,  z = 90 }, endRot = { x = 0, y = 0,   z = 90 }, checkRadius = 15 },
    { index = 3, type  = "rotation", model = 968,
        posX  = -1701.5,           posY  = 687.59997558594, posZ  = 24.89999961853,
        startRot = { x = 0, y = 270, z = 90 }, endRot = { x = 0, y = 360, z = 90 }, checkRadius = 15 },
    { index = 4, type  = "position", model = 980,
        posX  = -1623.8,           posY  = 688.3,
        closedZ = 9, openZ   = 13.7,            checkRadius = 15 }
}

local function createMapObjects()
    for i, cfg in ipairs(objectsConfig) do
        local obj
        if cfg.type == "position" then
            obj = createObject(cfg.model, cfg.posX, cfg.posY, cfg.closedZ)
        elseif cfg.type == "rotation" then
            obj = createObject(cfg.model, cfg.posX, cfg.posY, cfg.posZ, cfg.startRot.x, cfg.startRot.y, cfg.startRot.z)
        end
        if obj then objects[cfg.index] = { element = obj, config = cfg, isOpen = false } end
    end
end

local function tweenObjectPosition(object, cfg, duration, open)
    local startZ = open and cfg.closedZ or cfg.openZ
    local endZ = open and cfg.openZ or cfg.closedZ
    local startTime = getTickCount()
    local tickTime = 16 
    local iterations = math.ceil(duration / tickTime)
    local timerID = setTimer(function()
        local elapsed = getTickCount() - startTime
        if elapsed >= duration then
            setElementPosition(object, cfg.posX, cfg.posY, endZ)
            if isTimer(timerID) then killTimer(timerID) end
        else
            local progress = elapsed / duration
            local newZ = startZ + (endZ - startZ) * progress
            setElementPosition(object, cfg.posX, cfg.posY, newZ)
        end
    end, tickTime, iterations)
end

local function tweenObjectRotation(object, cfg, duration, open)
    local startRot = open and cfg.startRot or cfg.endRot
    local endRot = open and cfg.endRot or cfg.startRot
    local startTime = getTickCount()
    local tickTime = 16 
    local iterations = math.ceil(duration / tickTime)
    local timerID = setTimer(function()
        local elapsed = getTickCount() - startTime
        if elapsed >= duration then
            setElementRotation(object, endRot.x, endRot.y, endRot.z)
            if isTimer(timerID) then killTimer(timerID) end
        else
            local progress = elapsed / duration
            local newRot = {
                x = startRot.x + (endRot.x - startRot.x) * progress,
                y = startRot.y + (endRot.y - startRot.y) * progress,
                z = startRot.z + (endRot.z - startRot.z) * progress
            }
            setElementRotation(object, newRot.x, newRot.y, newRot.z)
        end
    end, tickTime, iterations)
end

local function tweenObjectState(index, open)
    local data = objects[index]
    if not data then return end
    local obj = data.element
    local cfg = data.config
    if cfg.type == "position" then
        tweenObjectPosition(obj, cfg, 2000, open)
    elseif cfg.type == "rotation" then
        tweenObjectRotation(obj, cfg, 2000, open)
    end
    data.isOpen = open
end

setTimer(function()
    for _, gateData in pairs(objects) do
        local cfg = gateData.config
        local anyPoliceSwat = false
        for _, player in ipairs(getElementsByType("player")) do
            local faction = getElementData(player, "group") or "Civil"
            if faction == "Police" or faction == "Swat" then -- Hier könnte man auch auf "policeImDienst" prüfen, falls gewünscht
                local px, py = getElementPosition(player)
                if getDistanceBetweenPoints2D(px, py, cfg.posX, cfg.posY) <= (cfg.checkRadius or 15) then
                    anyPoliceSwat = true
                    break
                end
            end
        end
        if anyPoliceSwat and not gateData.isOpen then
            tweenObjectState(cfg.index, true)
        elseif not anyPoliceSwat and gateData.isOpen then
            tweenObjectState(cfg.index, false)
        end
    end
end, 1000, 0)

addEventHandler("onClientResourceStart", resourceRoot, function()
    createMapObjects()
end)

----------------------------------------------------------------------
-- 3) Wanted-Ortungs-GUI (unverändert)
----------------------------------------------------------------------
local isWantedPlayersGUIVisible = false
local wantedPlayersList = {}
local selectedWantedPlayerIndex = nil
local scrollOffset = 0
local maxVisibleEntries = 10
local blipTimers = {}

local guiWidth, guiHeight = 280, 450 -- DEFINE THESE IF NOT ALREADY DEFINED GLOBALLY
local guiX, guiY = screenW - guiWidth - 20, (screenH - guiHeight) / 2 -- DEFINE THESE

local wantedIconPath = "user/client/images/usericons/wanted.png"
local wantedIconSize = 16
local wantedIconPadding = 4

local policeVehicleModels = {
    [596] = true, [597] = true, [598] = true, [599] = true, [490] = true,
    [528] = true, [601] = true, [427] = true, [411] = true, [425] = true
}
function isPlayerInPoliceVehicle()
    local veh = getPedOccupiedVehicle(localPlayer)
    if not veh then return false end
    local model = getElementModel(veh)
    return policeVehicleModels[model] or getElementData(veh, "policeVehicle") == true
end

function openWantedPlayersGUI(players)
    if isWantedPlayersGUIVisible or isPolicePanelVisible then return end
    isWantedPlayersGUIVisible = true
    wantedPlayersList = players or {}
    table.sort(wantedPlayersList, function(a,b) return a.wanted > b.wanted end)
    selectedWantedPlayerIndex = nil
    scrollOffset = 0
    showCursor(true)
    guiSetInputMode("no_binds_when_editing")
    addEventHandler("onClientRender", root, renderWantedPlayersGUI)
    bindKey("mouse_wheel_up", "down", scrollWantedListUp)
    bindKey("mouse_wheel_down", "down", scrollWantedListDown)
    bindKey("escape", "down", closeWantedPlayersGUIByKey)
end

function closeWantedPlayersGUI()
    if not isWantedPlayersGUIVisible then return end
    isWantedPlayersGUIVisible = false
    removeEventHandler("onClientRender", root, renderWantedPlayersGUI)
    unbindKey("mouse_wheel_up", "down", scrollWantedListUp)
    unbindKey("mouse_wheel_down", "down", scrollWantedListDown)
    unbindKey("escape", "down", closeWantedPlayersGUIByKey)
    if not isPolicePanelVisible then -- Nur Cursor ausblenden, wenn kein anderes Polizei-Fenster offen ist
        showCursor(false)
        guiSetInputMode("allow_binds")
    end
    wantedPlayersList = {}
    selectedWantedPlayerIndex = nil
end

function closeWantedPlayersGUIByKey(key, state)
    if key == "escape" and state == "down" then
        closeWantedPlayersGUI()
    end
end

function scrollWantedListUp()
    if not isWantedPlayersGUIVisible or #wantedPlayersList <= maxVisibleEntries then return end
    scrollOffset = math.max(0, scrollOffset - 1)
end

function scrollWantedListDown()
    if not isWantedPlayersGUIVisible or #wantedPlayersList <= maxVisibleEntries then return end
    scrollOffset = math.min(#wantedPlayersList - maxVisibleEntries, scrollOffset + 1)
end

function renderWantedPlayersGUI()
    if not isWantedPlayersGUIVisible then return end

    dxDrawRectangle(guiX, guiY, guiWidth, guiHeight, tocolor(20, 20, 40, 220))
    dxDrawRectangle(guiX, guiY, guiWidth, 35, tocolor(0, 50, 100, 230))
    dxDrawText("Wanted List", guiX, guiY, guiX + guiWidth, guiY + 35,
        tocolor(255, 255, 255), 1.3, "default-bold", "center", "center")

    local listY = guiY + 45
    local listHeight = guiHeight - 110 
    local rowHeight = 30
    local spacing = 4

    if #wantedPlayersList > maxVisibleEntries then
        local scrollbarX = guiX + guiWidth - 12
        local scrollbarW = 8
        dxDrawRectangle(scrollbarX, listY, scrollbarW, listHeight, tocolor(0,0,0,100))
        local thumbH = math.max(15, listHeight * (maxVisibleEntries / #wantedPlayersList))
        local thumbY = listY + (listHeight - thumbH) * (scrollOffset / math.max(1, #wantedPlayersList - maxVisibleEntries))
        dxDrawRectangle(scrollbarX, thumbY, scrollbarW, thumbH, tocolor(150, 150, 150, 150))
    end

    local clickAreas = {}
    local nameColWidth = guiWidth * 0.62 
    local wantedColStartX = guiX + 5 + nameColWidth 

    for i = 1, maxVisibleEntries do
        local index = i + scrollOffset
        if wantedPlayersList[index] then
            local data = wantedPlayersList[index]
            local rowY = listY + (i-1) * (rowHeight + spacing)
            local bgColor = (index == selectedWantedPlayerIndex) and tocolor(0, 100, 150, 180) or tocolor(40, 40, 60, 180)
            local textColor = tocolor(230, 230, 230)

            dxDrawRectangle(guiX + 5, rowY, guiWidth - 22, rowHeight, bgColor)
            dxDrawText(data.name, guiX + 10, rowY, guiX + 5 + nameColWidth - 5, rowY + rowHeight,
                textColor, 1.0, "default", "left", "center", true)
            
            local wantedText = tostring(data.wanted or 0)
            local wantedTextWidth = dxGetTextWidth(wantedText, 1.0, "default-bold")
            local totalWantedDisplayWidth = wantedIconPadding + wantedIconSize + wantedIconPadding + wantedTextWidth
            local remainingSpaceForWanted = (guiWidth - 22) - nameColWidth
            local wantedDrawX = wantedColStartX + (remainingSpaceForWanted - totalWantedDisplayWidth) / 2

            if fileExists(wantedIconPath) then
                dxDrawImage(wantedDrawX, rowY + (rowHeight - wantedIconSize) / 2,
                    wantedIconSize, wantedIconSize, wantedIconPath, 0,0,0, tocolor(255,255,255,200))
            end
            dxDrawText(wantedText, wantedDrawX + wantedIconSize + wantedIconPadding, rowY,
                wantedDrawX + totalWantedDisplayWidth, rowY + rowHeight,
                tocolor(255, 180, 0), 1.0, "default-bold", "left", "center")

            clickAreas[index] = {x = guiX + 5, y = rowY, w = guiWidth - 22, h = rowHeight}
        end
    end
    _G.wantedPlayersGUIClickAreas = clickAreas -- Store for click handler

    local btnY = guiY + guiHeight - 55
    local btnH_action = 40
    local btnWLocate = guiWidth * 0.5 - 10
    local btnWClose = guiWidth * 0.5 - 10
    local btnXLocate = guiX + 5
    local btnXClose = guiX + guiWidth - btnWClose - 5

    local locateColor = (selectedWantedPlayerIndex) and tocolor(0, 150, 0, 200) or tocolor(50, 100, 50, 150)
    local locateTextColor = (selectedWantedPlayerIndex) and tocolor(255, 255, 255) or tocolor(150, 150, 150)
    dxDrawRectangle(btnXLocate, btnY, btnWLocate, btnH_action, locateColor)
    dxDrawText("Orten", btnXLocate, btnY, btnXLocate + btnWLocate, btnY + btnH_action,
        locateTextColor, 1.1, "default-bold", "center", "center")

    dxDrawRectangle(btnXClose, btnY, btnWClose, btnH_action, tocolor(200, 50, 50, 200))
    dxDrawText("Schließen", btnXClose, btnY, btnXClose + btnWClose, btnY + btnH_action,
        tocolor(255, 255, 255), 1.1, "default-bold", "center", "center")

    _G.wantedPlayersGUIButtons = {
        locate = {x=btnXLocate, y=btnY, w=btnWLocate, h=btnH_action},
        close = {x=btnXClose, y=btnY, w=btnWClose, h=btnH_action}
    }
end

addEventHandler("onClientClick", root, function(button, state, absX, absY)
    if not isWantedPlayersGUIVisible or button ~= "left" or state ~= "up" then return end
    local clickHandled = false
    if _G.wantedPlayersGUIClickAreas then
        for index, area in pairs(_G.wantedPlayersGUIClickAreas) do
            if absX >= area.x and absX <= area.x + area.w and absY >= area.y and absY <= area.y + area.h then
                selectedWantedPlayerIndex = index
                clickHandled = true
                break
            end
        end
    end

    if not clickHandled and _G.wantedPlayersGUIButtons then
        local locateBtn = _G.wantedPlayersGUIButtons.locate
        local closeBtn = _G.wantedPlayersGUIButtons.close
        if absX >= locateBtn.x and absX <= locateBtn.x + locateBtn.w and
           absY >= locateBtn.y and absY <= locateBtn.y + locateBtn.h then
            if selectedWantedPlayerIndex and wantedPlayersList[selectedWantedPlayerIndex] then
                local targetPlayerElement = wantedPlayersList[selectedWantedPlayerIndex].player
                if isElement(targetPlayerElement) then
                    triggerServerEvent("requestPlayerLocation", localPlayer, targetPlayerElement)
                else outputChatBox("Fehler: Spieler nicht mehr gültig.", 255, 100, 0) end
            else outputChatBox("Bitte wähle zuerst einen Spieler aus der Liste.", 255, 165, 0) end
            clickHandled = true
        elseif absX >= closeBtn.x and absX <= closeBtn.x + closeBtn.w and
               absY >= closeBtn.y and absY <= closeBtn.y + closeBtn.h then
            closeWantedPlayersGUI()
            clickHandled = true
        end
    end
end)

addEvent("receiveWantedPlayers", true)
addEventHandler("receiveWantedPlayers", root, function(playersTable)
    openWantedPlayersGUI(playersTable)
end)

addEvent("showTargetBlip", true)
addEventHandler("showTargetBlip", root, function(targetPlayer, duration)
    if not isElement(targetPlayer) then return end
    if isTimer(blipTimers[targetPlayer]) then killTimer(blipTimers[targetPlayer]); blipTimers[targetPlayer] = nil end
    local blip = createBlipAttachedTo(targetPlayer, 0, 2, 255, 0, 0)
    if isElement(blip) then
        setBlipVisibleDistance(blip, 9999)
        outputChatBox("Spieler " .. getPlayerName(targetPlayer) .. " wird für " .. (duration / 1000) .. " Sekunden auf der Karte markiert.", 0, 255, 0)
        blipTimers[targetPlayer] = setTimer(function(blipToDelete, playerKey)
            if isElement(blipToDelete) then destroyElement(blipToDelete) end
            if isElement(playerKey) then outputChatBox("Ortung für " .. getPlayerName(playerKey) .. " beendet.", 255, 165, 0) end
            blipTimers[playerKey] = nil
        end, duration, 1, blip, targetPlayer)
    else outputChatBox("Fehler beim Erstellen des Blips.", 255, 0, 0) end
end)

function handleOpenWantedListKey(key, state)
    if key == "k" and state == "down" then
        if not isPlayerInPoliceVehicle() then return end
        -- << GEÄNDERT >> Nur öffnen, wenn Spieler Polizist und im Dienst ist
        local playerFaction = getElementData(localPlayer, "group") or "Civil"
        local isPoliceOnDuty = getElementData(localPlayer, "policeImDienst") or false
        if not (playerFaction == "Police" and isPoliceOnDuty) and not (playerFaction == "Swat") then -- Swat kann immer
            outputChatBox("Nur Polizisten im Dienst oder SWAT-Mitglieder können die Fahndungsliste öffnen.", 255,100,0)
            return
        end
        -- Ende Änderung

        if isWantedPlayersGUIVisible then
            closeWantedPlayersGUI()
        elseif not isPolicePanelVisible then -- Verhindere Öffnen, wenn Haupt-Police-Fenster offen ist
             triggerServerEvent("requestWantedPlayers", localPlayer)
        end
    end
end
bindKey("k", "down", handleOpenWantedListKey)

addEventHandler("onClientResourceStop", resourceRoot, function()
    closePolicePanel()
    closeWantedPlayersGUI()
    unbindKey("k", "down", handleOpenWantedListKey)
    for target, timer in pairs(blipTimers) do
        if isTimer(timer) then killTimer(timer) end
        local attachedBlips = getAttachedElements(target, "blip")
        if attachedBlips then for _, b in ipairs(attachedBlips) do if isElement(b) then destroyElement(b) end end end
    end
    blipTimers = {}
end)