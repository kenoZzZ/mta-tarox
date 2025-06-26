-- tarox/fraktionen/mechanic/repair_client.lua
-- Version 3.0: NUR Reparatur (alte Logik)
-- ERWEITERT V3.1: Mit Klick-Interaktion, Bestätigungs-GUIs und Cooldown-Balken
-- KORRIGIERT V3.2: toggleAllControls und repairProgressBar Initialisierung
-- NEU V3.3: Selbstreparatur-Bestätigungsfenster hinzugefügt

local screenW, screenH = guiGetScreenSize()
local localPlayer = getLocalPlayer()

-- Für Reparatur in der Garage
local isRepairMenuVisible = false
_G.isRepairMenuVisible = false -- Globales Flag
local repairMenuTargetVehicle = nil
local menuButtons_repair = {}

-- Für Klick-Reparatur (Mechaniker bietet an)
local isMechanicConfirmGUIVisible = false
_G.isMechanicOfferGuiVisible = false 
local mechanicConfirmData = {} 
local mechanicConfirmElements = {}

-- Für Klick-Reparatur (Spieler akzeptiert Angebot)
local isPlayerAcceptGUIVisible = false
_G.isRepairConfirmVisible = false 
local playerAcceptData = {} 
local playerAcceptElements = {}

-- NEU: Für Selbstreparatur-Bestätigung
local isSelfRepairConfirmGUIVisible = false
_G.isSelfRepairConfirmGUIVisible = false -- Globales Flag
local selfRepairConfirmData = { vehicle = nil }
local selfRepairConfirmElements = {}

local isRepairProgressBarActive = false 
local repairProgressBarEndTime = 0
local repairProgressBarDuration = 0
local repairProgressBarText = ""
local repairProgressBarRenderHandler = nil 

local windowWidth_repair, windowHeight_repair = 400, 160
local windowX_repair, windowY_repair = (screenW - windowWidth_repair) / 2, (screenH - windowHeight_repair) / 2

local colors_repair = {
    bgMain = tocolor(28, 30, 36, 230),
    headerBg = tocolor(255, 180, 0, 235), 
    headerText = tocolor(10, 10, 15),
    buttonActionBg = tocolor(60, 160, 60, 220),
    buttonActionHoverBg = tocolor(80, 180, 80, 230),
    buttonRedBg = tocolor(180, 50, 50, 220),
    buttonRedHoverBg = tocolor(200, 70, 70, 230),
    buttonText = tocolor(235, 235, 240),
    textLight = tocolor(240,240,245),
    textMedium = tocolor(190,195,205),
    borderLight = tocolor(55,58,68,200),
    borderDark = tocolor(20,22,28,200),
    confirmBg = tocolor(30,35,45,240),
    confirmHeaderBg = tocolor(0,90,150,245),
    confirmTextLight = tocolor(220,225,235),
    confirmButtonYesBg = tocolor(70,170,70,220),
    confirmButtonYesHover = tocolor(90,190,90,230),
    confirmButtonNoBg = tocolor(190,70,70,220),
    confirmButtonNoHover = tocolor(210,90,90,230),
    confirmButtonText = tocolor(250,250,250),
    progressBarBg = tocolor(50,50,50,220),
    progressBarFg = tocolor(255,165,0,220), 
    progressBarBorder = tocolor(10,10,10,210),
    progressText = tocolor(255,255,255,255)
}
local MAX_REPAIR_DISTANCE_CLIENT = 5 

local repairProgressBar = {
    active = false,
    endTime = 0,
    duration = 0,
    text = "Repariere Fahrzeug..."
}

-- ##########################################################################
-- ## Logik für Reparatur in der GARAGE
-- ##########################################################################
addEvent("mechanic:openRepairMenuClient", true)
addEventHandler("mechanic:openRepairMenuClient", root, function(targetVehicle)
    if isRepairMenuVisible or isMechanicConfirmGUIVisible or isPlayerAcceptGUIVisible or isSelfRepairConfirmGUIVisible then return end 
    isRepairMenuVisible = true
    _G.isRepairMenuVisible = true 
    repairMenuTargetVehicle = targetVehicle

    showCursor(true)
    guiSetInputMode("no_binds_when_editing")
    addEventHandler("onClientRender", root, renderGarageRepairMenu)
    addEventHandler("onClientClick", root, handleGarageRepairMenuClick, true)
    addEventHandler("onClientKey", root, handleGarageRepairMenuKey)
end)

function closeGarageRepairMenu()
    if not isRepairMenuVisible then return end
    isRepairMenuVisible = false
    _G.isRepairMenuVisible = false 
    repairMenuTargetVehicle = nil

    removeEventHandler("onClientRender", root, renderGarageRepairMenu)
    removeEventHandler("onClientClick", root, handleGarageRepairMenuClick)
    removeEventHandler("onClientKey", root, handleGarageRepairMenuKey)

    if not isMechanicConfirmGUIVisible and not isPlayerAcceptGUIVisible and not isSelfRepairConfirmGUIVisible then 
        showCursor(false)
        guiSetInputMode("allow_binds")
    end
end

function dxDrawGarageRepairButton(id, text, x, y, w, h)
    local mouseX, mouseY = getCursorPosition()
    local isHovering = false
    local current_screenW, current_screenH = guiGetScreenSize()
    if type(current_screenW) ~= "number" then current_screenW = 0 end
    if type(current_screenH) ~= "number" then current_screenH = 0 end

    if mouseX and mouseY then
        local absMouseX, absMouseY = mouseX * current_screenW, mouseY * current_screenH
        if type(absMouseX) == "number" and type(absMouseY) == "number" and
           type(x) == "number" and type(w) == "number" and
           type(y) == "number" and type(h) == "number" then
             if absMouseX >= x and absMouseX <= x + w and absMouseY >= y and absMouseY <= y + h then
                isHovering = true
            end
        end
    end
    local bgColor
    if id == "close_repair" then
        bgColor = isHovering and colors_repair.buttonRedHoverBg or colors_repair.buttonRedBg
    else
        bgColor = isHovering and colors_repair.buttonActionHoverBg or colors_repair.buttonActionBg
    end
    dxDrawRectangle(x, y, w, h, bgColor)
    dxDrawText(text, x, y, x + w, y + h, colors_repair.buttonText, 1.1, "default-bold", "center", "center", false, false, false, true)
    menuButtons_repair[id] = {x=x, y=y, w=w, h=h}
end

function renderGarageRepairMenu()
    if not isRepairMenuVisible then return end
    menuButtons_repair = {}
    dxDrawRectangle(windowX_repair, windowY_repair, windowWidth_repair, windowHeight_repair, colors_repair.bgMain)
    dxDrawRectangle(windowX_repair, windowY_repair, windowWidth_repair, 45, colors_repair.headerBg)
    dxDrawText("Werkstatt - Fahrzeugreparatur", windowX_repair, windowY_repair, windowX_repair + windowWidth_repair, windowY_repair + 45, colors_repair.headerText, 1.2, "default-bold", "center", "center")
    local startX = windowX_repair + 20
    local contentWidth = windowWidth_repair - 40
    local buttonY = windowY_repair + 65
    dxDrawGarageRepairButton("repair_vehicle", "Fahrzeug reparieren ($200)", startX, buttonY, contentWidth, 35)
    dxDrawGarageRepairButton("close_repair", "Schließen", startX, buttonY + 45, contentWidth, 35)
end

function handleGarageRepairMenuClick(button, state, absX, absY)
    if not isRepairMenuVisible or button ~= "left" or state ~= "up" then return end
    for id, data in pairs(menuButtons_repair) do
        if absX >= data.x and absX <= data.x + data.w and absY >= data.y and absY <= data.y + data.h then
            playSoundFrontEnd(40)
            if id == "close_repair" then
                closeGarageRepairMenu()
            elseif id == "repair_vehicle" then
                triggerServerEvent("mechanic:requestVehicleRepairServer", localPlayer, repairMenuTargetVehicle)
                closeGarageRepairMenu()
            end
            cancelEvent()
            return
        end
    end
end

function handleGarageRepairMenuKey(key, press)
    if not isRepairMenuVisible or not press then return end
    if key == "escape" then
        closeGarageRepairMenu()
        cancelEvent()
    end
end

addEvent("mechanic:forceCloseRepairMenu", true)
addEventHandler("mechanic:forceCloseRepairMenu", root, closeGarageRepairMenu)

-- ##########################################################################
-- ## Logik für Klick-Reparatur GUIs (Mechaniker-Angebot & Spieler-Akzeptanz)
-- ##########################################################################

-- Mechaniker Bestätigungs-GUI (Angebot an anderen Spieler)
addEvent("mechanic:showMechanicRepairConfirmGUI", true)
addEventHandler("mechanic:showMechanicRepairConfirmGUI", root, function(targetPlayerName, vehicleName)
    if isMechanicConfirmGUIVisible or isPlayerAcceptGUIVisible or isRepairMenuVisible or isSelfRepairConfirmGUIVisible then return end
    isMechanicConfirmGUIVisible = true
    _G.isMechanicOfferGuiVisible = true 
    mechanicConfirmData = { targetPlayerName = targetPlayerName, vehicleName = vehicleName }
    mechanicConfirmElements = {}

    showCursor(true)
    guiSetInputMode("no_binds_when_editing")
    addEventHandler("onClientRender", root, renderMechanicConfirmGUI)
    addEventHandler("onClientClick", root, handleMechanicConfirmGUIClick, false) 
    addEventHandler("onClientKey", root, handleMechanicConfirmGUIKey)
end)

function closeMechanicConfirmGUI()
    if not isMechanicConfirmGUIVisible then return end
    isMechanicConfirmGUIVisible = false
    _G.isMechanicOfferGuiVisible = false 
    mechanicConfirmData = {}
    removeEventHandler("onClientRender", root, renderMechanicConfirmGUI)
    removeEventHandler("onClientClick", root, handleMechanicConfirmGUIClick)
    removeEventHandler("onClientKey", root, handleMechanicConfirmGUIKey)
    if not isPlayerAcceptGUIVisible and not isRepairMenuVisible and not isSelfRepairConfirmGUIVisible then
        showCursor(false)
        guiSetInputMode("allow_binds")
    end
end
addEvent("mechanic:closeMechanicConfirmGUI", true)
addEventHandler("mechanic:closeMechanicConfirmGUI", root, closeMechanicConfirmGUI)


function renderMechanicConfirmGUI()
    if not isMechanicConfirmGUIVisible then return end
    mechanicConfirmElements = {} 
    local panelW, panelH = 400, 200
    local panelX, panelY = (screenW - panelW) / 2, (screenH - panelH) / 2
    dxDrawRectangle(panelX, panelY, panelW, panelH, colors_repair.confirmBg) 
    dxDrawRectangle(panelX, panelY, panelW, 40, colors_repair.confirmHeaderBg) 
    dxDrawText("Reparaturanfrage an Spieler", panelX, panelY, panelX + panelW, panelY + 40, colors_repair.buttonText, 1.2, "default-bold", "center", "center")

    local text = "Möchtest du ein Reparaturangebot für das Fahrzeug (".. (mechanicConfirmData.vehicleName or "Unbekannt") ..")\nvon ".. (mechanicConfirmData.targetPlayerName or "Unbekannt") .." erstellen?"
    dxDrawText(text, panelX + 15, panelY + 55, panelX + panelW - 15, panelY + panelH - 60, colors_repair.confirmTextLight, 1.0, "default", "center", "center", true)

    local btnW, btnH = 120, 35
    local btnY = panelY + panelH - 15 - btnH
    local btnYesX = panelX + (panelW / 2) - btnW - 5
    local btnNoX = panelX + (panelW / 2) + 5

    dxDrawRectangle(btnYesX, btnY, btnW, btnH, colors_repair.confirmButtonYesBg)
    dxDrawText("Ja", btnYesX, btnY, btnYesX + btnW, btnY + btnH, colors_repair.confirmButtonText, 1.0, "default-bold", "center", "center")
    mechanicConfirmElements.yes = {x=btnYesX, y=btnY, w=btnW, h=btnH}

    dxDrawRectangle(btnNoX, btnY, btnW, btnH, colors_repair.confirmButtonNoBg)
    dxDrawText("Nein", btnNoX, btnY, btnNoX + btnW, btnY + btnH, colors_repair.confirmButtonText, 1.0, "default-bold", "center", "center")
    mechanicConfirmElements.no = {x=btnNoX, y=btnY, w=btnW, h=btnH}
end

function handleMechanicConfirmGUIClick(button, state, absX, absY)
    if not isMechanicConfirmGUIVisible or button ~= "left" or state ~= "up" then return end
    if mechanicConfirmElements.yes and absX >= mechanicConfirmElements.yes.x and absX <= mechanicConfirmElements.yes.x + mechanicConfirmElements.yes.w and
       absY >= mechanicConfirmElements.yes.y and absY <= mechanicConfirmElements.yes.y + mechanicConfirmElements.yes.h then
        playSoundFrontEnd(40)
        triggerServerEvent("mechanic:mechanicConfirmsRepairOffer", localPlayer) 
        closeMechanicConfirmGUI()
    elseif mechanicConfirmElements.no and absX >= mechanicConfirmElements.no.x and absX <= mechanicConfirmElements.no.x + mechanicConfirmElements.no.w and
           absY >= mechanicConfirmElements.no.y and absY <= mechanicConfirmElements.no.y + mechanicConfirmElements.no.h then
        playSoundFrontEnd(41)
        closeMechanicConfirmGUI()
    end
end

function handleMechanicConfirmGUIKey(key, press)
    if not isMechanicConfirmGUIVisible or not press then return end
    if key == "escape" then
        closeMechanicConfirmGUI()
        cancelEvent()
    end
end

-- Spieler Akzeptanz-GUI (Angebot von anderem Mechaniker)
addEvent("mechanic:showPlayerAcceptRepairGUI", true)
addEventHandler("mechanic:showPlayerAcceptRepairGUI", root, function(mechanicName, vehicleName, cost, vehicleElement)
    if isPlayerAcceptGUIVisible or isMechanicConfirmGUIVisible or isRepairMenuVisible or isSelfRepairConfirmGUIVisible then return end
    isPlayerAcceptGUIVisible = true
    _G.isRepairConfirmVisible = true 
    playerAcceptData = { mechanicName = mechanicName, vehicleName = vehicleName, cost = cost, vehicleElement = vehicleElement }
    playerAcceptElements = {}

    showCursor(true)
    guiSetInputMode("no_binds_when_editing")
    addEventHandler("onClientRender", root, renderPlayerAcceptGUI)
    addEventHandler("onClientClick", root, handlePlayerAcceptGUIClick, false)
    addEventHandler("onClientKey", root, handlePlayerAcceptGUIKey)
end)

function closePlayerAcceptGUI()
    if not isPlayerAcceptGUIVisible then return end
    isPlayerAcceptGUIVisible = false
    _G.isRepairConfirmVisible = false 
    playerAcceptData = {}
    removeEventHandler("onClientRender", root, renderPlayerAcceptGUI)
    removeEventHandler("onClientClick", root, handlePlayerAcceptGUIClick)
    removeEventHandler("onClientKey", root, handlePlayerAcceptGUIKey)
    if not isMechanicConfirmGUIVisible and not isRepairMenuVisible and not isSelfRepairConfirmGUIVisible then
        showCursor(false)
        guiSetInputMode("allow_binds")
    end
end
addEvent("mechanic:closePlayerAcceptGUI", true)
addEventHandler("mechanic:closePlayerAcceptGUI", root, closePlayerAcceptGUI)

function renderPlayerAcceptGUI()
    if not isPlayerAcceptGUIVisible then return end
    playerAcceptElements = {}
    local panelW, panelH = 400, 220
    local panelX, panelY = (screenW - panelW) / 2, (screenH - panelH) / 2
    dxDrawRectangle(panelX, panelY, panelW, panelH, colors_repair.confirmBg)
    dxDrawRectangle(panelX, panelY, panelW, 40, colors_repair.confirmHeaderBg)
    dxDrawText("Reparaturangebot", panelX, panelY, panelX + panelW, panelY + 40, colors_repair.buttonText, 1.2, "default-bold", "center", "center")

    local text = string.format("Mechaniker %s möchte dein Fahrzeug (%s)\nfür $%d reparieren. Akzeptieren?",
                                playerAcceptData.mechanicName or "Unbekannt",
                                playerAcceptData.vehicleName or "Unbekannt",
                                playerAcceptData.cost or 0)
    dxDrawText(text, panelX + 15, panelY + 55, panelX + panelW - 15, panelY + panelH - 70, colors_repair.confirmTextLight, 1.0, "default", "center", "center", true)

    local btnW, btnH = 120, 35
    local btnY = panelY + panelH - 15 - btnH -10
    local btnYesX = panelX + (panelW / 2) - btnW - 5
    local btnNoX = panelX + (panelW / 2) + 5

    dxDrawRectangle(btnYesX, btnY, btnW, btnH, colors_repair.confirmButtonYesBg)
    dxDrawText("Ja ($"..playerAcceptData.cost..")", btnYesX, btnY, btnYesX+btnW, btnY+btnH, colors_repair.confirmButtonText, 1.0, "default-bold", "center", "center")
    playerAcceptElements.yes = {x=btnYesX, y=btnY, w=btnW, h=btnH}

    dxDrawRectangle(btnNoX, btnY, btnW, btnH, colors_repair.confirmButtonNoBg)
    dxDrawText("Nein", btnNoX, btnY, btnNoX+btnW, btnY+btnH, colors_repair.confirmButtonText, 1.0, "default-bold", "center", "center")
    playerAcceptElements.no = {x=btnNoX, y=btnY, w=btnW, h=btnH}
end

function handlePlayerAcceptGUIClick(button, state, absX, absY)
    if not isPlayerAcceptGUIVisible or button ~= "left" or state ~= "up" then return end
    if playerAcceptElements.yes and absX >= playerAcceptElements.yes.x and absX <= playerAcceptElements.yes.x + playerAcceptElements.yes.w and
       absY >= playerAcceptElements.yes.y and absY <= playerAcceptElements.yes.y + playerAcceptElements.yes.h then
        playSoundFrontEnd(40)
        triggerServerEvent("mechanic:playerRespondedToRepairOffer", localPlayer, getPlayerFromName(playerAcceptData.mechanicName), true, playerAcceptData.vehicleElement)
        closePlayerAcceptGUI()
    elseif playerAcceptElements.no and absX >= playerAcceptElements.no.x and absX <= playerAcceptElements.no.x + playerAcceptElements.no.w and
           absY >= playerAcceptElements.no.y and absY <= playerAcceptElements.no.y + playerAcceptElements.no.h then
        playSoundFrontEnd(41)
        triggerServerEvent("mechanic:playerRespondedToRepairOffer", localPlayer, getPlayerFromName(playerAcceptData.mechanicName), false, playerAcceptData.vehicleElement)
        closePlayerAcceptGUI()
    end
end

function handlePlayerAcceptGUIKey(key, press)
    if not isPlayerAcceptGUIVisible or not press then return end
    if key == "escape" then
        triggerServerEvent("mechanic:playerRespondedToRepairOffer", localPlayer, getPlayerFromName(playerAcceptData.mechanicName), false, playerAcceptData.vehicleElement)
        closePlayerAcceptGUI()
        cancelEvent()
    end
end

-- NEU: Logik für Selbstreparatur-Bestätigungsfenster
addEvent("mechanic:showSelfRepairConfirmationGUI", true)
addEventHandler("mechanic:showSelfRepairConfirmationGUI", root, function(vehicleToRepair)
    if isSelfRepairConfirmGUIVisible or isMechanicConfirmGUIVisible or isPlayerAcceptGUIVisible or isRepairMenuVisible then return end
    
    if not isElement(vehicleToRepair) then 
        outputChatBox("Fehler: Ungültiges Fahrzeug für Selbstreparatur.", 255,0,0)
        return
    end

    isSelfRepairConfirmGUIVisible = true
    _G.isSelfRepairConfirmGUIVisible = true
    selfRepairConfirmData.vehicle = vehicleToRepair
    selfRepairConfirmElements = {}

    showCursor(true)
    guiSetInputMode("no_binds_when_editing")
    addEventHandler("onClientRender", root, renderSelfRepairConfirmGUI)
    addEventHandler("onClientClick", root, handleSelfRepairConfirmGUIClick, false) 
    addEventHandler("onClientKey", root, handleSelfRepairConfirmGUIKey)
end)

function closeSelfRepairConfirmGUI()
    if not isSelfRepairConfirmGUIVisible then return end
    isSelfRepairConfirmGUIVisible = false
    _G.isSelfRepairConfirmGUIVisible = false
    selfRepairConfirmData.vehicle = nil
    removeEventHandler("onClientRender", root, renderSelfRepairConfirmGUI)
    removeEventHandler("onClientClick", root, handleSelfRepairConfirmGUIClick)
    removeEventHandler("onClientKey", root, handleSelfRepairConfirmGUIKey)
    
    if not isMechanicConfirmGUIVisible and not isPlayerAcceptGUIVisible and not isRepairMenuVisible then
        -- Nur den Cursor ausblenden, wenn keine andere Mechaniker-GUI offen ist
        -- Die M-Taste (click_client) wird den Cursor bei Bedarf wieder einblenden.
        -- Wir wollen nicht, dass der Cursor verschwindet, wenn der Spieler "M" drückt,
        -- das SelfRepair-GUI ablehnt und der Cursor dann weg ist.
        -- Der toggleManualCursor in click_client sollte dies handhaben.
        if _G.isCursorManuallyShownByClickSystem then
            -- Nichts tun, der Click-Client handhabt das Schließen des Cursors
        else
            showCursor(false)
            guiSetInputMode("allow_binds")
        end
    end
end

function renderSelfRepairConfirmGUI()
    if not isSelfRepairConfirmGUIVisible then return end
    selfRepairConfirmElements = {} 
    local panelW, panelH = 400, 200
    local panelX, panelY = (screenW - panelW) / 2, (screenH - panelH) / 2
    dxDrawRectangle(panelX, panelY, panelW, panelH, colors_repair.confirmBg)
    dxDrawRectangle(panelX, panelY, panelW, 40, colors_repair.confirmHeaderBg) -- Header wie bei anderem Confirm
    dxDrawText("Eigenes Fahrzeug reparieren", panelX, panelY, panelX + panelW, panelY + 40, colors_repair.buttonText, 1.2, "default-bold", "center", "center")

    local vehicleName = "deinem Fahrzeug"
    if selfRepairConfirmData.vehicle and isElement(selfRepairConfirmData.vehicle) then
        vehicleName = getVehicleNameFromModel(getElementModel(selfRepairConfirmData.vehicle)) or vehicleName
    end
    
    -- Kosten von der Serverseite holen, hier ein Platzhalter, da SELF_REPAIR_COST_MECHANIC serverseitig ist.
    local costText = "" -- "(Kostenlos für Mechaniker)" -- Oder dynamisch vom Server holen
    local text = string.format("Möchtest du %s reparieren?\n%s", vehicleName, costText)
    dxDrawText(text, panelX + 15, panelY + 55, panelX + panelW - 15, panelY + panelH - 60, colors_repair.confirmTextLight, 1.0, "default", "center", "center", true)

    local btnW, btnH = 120, 35
    local btnY = panelY + panelH - 15 - btnH
    local btnYesX = panelX + (panelW / 2) - btnW - 5
    local btnNoX = panelX + (panelW / 2) + 5

    dxDrawRectangle(btnYesX, btnY, btnW, btnH, colors_repair.confirmButtonYesBg)
    dxDrawText("Ja, reparieren", btnYesX, btnY, btnYesX + btnW, btnY + btnH, colors_repair.confirmButtonText, 1.0, "default-bold", "center", "center")
    selfRepairConfirmElements.yes = {x=btnYesX, y=btnY, w=btnW, h=btnH}

    dxDrawRectangle(btnNoX, btnY, btnW, btnH, colors_repair.confirmButtonNoBg)
    dxDrawText("Nein", btnNoX, btnY, btnNoX + btnW, btnY + btnH, colors_repair.confirmButtonText, 1.0, "default-bold", "center", "center")
    selfRepairConfirmElements.no = {x=btnNoX, y=btnY, w=btnW, h=btnH}
end

function handleSelfRepairConfirmGUIClick(button, state, absX, absY)
    if not isSelfRepairConfirmGUIVisible or button ~= "left" or state ~= "up" then return end
    if selfRepairConfirmElements.yes and absX >= selfRepairConfirmElements.yes.x and absX <= selfRepairConfirmElements.yes.x + selfRepairConfirmElements.yes.w and
       absY >= selfRepairConfirmElements.yes.y and absY <= selfRepairConfirmElements.yes.y + selfRepairConfirmElements.yes.h then
        playSoundFrontEnd(40)
        if selfRepairConfirmData.vehicle and isElement(selfRepairConfirmData.vehicle) then
            triggerServerEvent("mechanic:requestSelfRepairVehicle", localPlayer, selfRepairConfirmData.vehicle)
        else
            outputChatBox("Fehler: Fahrzeug für Selbstreparatur nicht mehr gültig.",255,0,0)
        end
        closeSelfRepairConfirmGUI()
    elseif selfRepairConfirmElements.no and absX >= selfRepairConfirmElements.no.x and absX <= selfRepairConfirmElements.no.x + selfRepairConfirmElements.no.w and
           absY >= selfRepairConfirmElements.no.y and absY <= selfRepairConfirmElements.no.y + selfRepairConfirmElements.no.h then
        playSoundFrontEnd(41)
        closeSelfRepairConfirmGUI()
    end
end

function handleSelfRepairConfirmGUIKey(key, press)
    if not isSelfRepairConfirmGUIVisible or not press then return end
    if key == "escape" then
        closeSelfRepairConfirmGUI()
        cancelEvent()
    end
end


-- Fortschrittsbalken
function drawRepairProgressBar() 
    if not repairProgressBar.active then 
        if repairProgressBarRenderHandler and isEventHandlerAdded("onClientRender", root, repairProgressBarRenderHandler) then
            removeEventHandler("onClientRender", root, repairProgressBarRenderHandler)
            repairProgressBarRenderHandler = nil
        end
        return
    end
    local remainingTime = math.max(0, repairProgressBar.endTime - getTickCount())
    if remainingTime == 0 then
        repairProgressBar.active = false
        if repairProgressBarRenderHandler and isEventHandlerAdded("onClientRender", root, repairProgressBarRenderHandler) then
            removeEventHandler("onClientRender", root, repairProgressBarRenderHandler)
            repairProgressBarRenderHandler = nil
        end
        return
    end
    local progress = 1 - (remainingTime / repairProgressBar.duration)
    local barW, barH = 280, 25
    local barX = (screenW - barW) / 2
    local barY = screenH * 0.82 
    dxDrawRectangle(barX - 2, barY - 2, barW + 4, barH + 4, colors_repair.progressBarBorder)
    dxDrawRectangle(barX, barY, barW, barH, colors_repair.progressBarBg)
    dxDrawRectangle(barX, barY, barW * progress, barH, colors_repair.progressBarFg) 
    dxDrawText(string.format("%s (%.1fs)", repairProgressBar.text, remainingTime/1000), barX, barY, barX+barW, barY+barH, colors_repair.progressText, 1.0, "default-bold", "center", "center")
end

addEvent("mechanic:startRepairAnimationOnVehicle", true)
addEventHandler("mechanic:startRepairAnimationOnVehicle", root, function(vehicleToRepair, duration)
    if not isElement(vehicleToRepair) then
        outputChatBox("❌ Fehler: Fahrzeug für Reparatur nicht gefunden.", 255,0,0)
        return
    end
    
    local px,py,pz = getElementPosition(localPlayer)
    local vx,vy,vz = getElementPosition(vehicleToRepair)

    if not MAX_REPAIR_DISTANCE_CLIENT then MAX_REPAIR_DISTANCE_CLIENT = 5 end

    if getDistanceBetweenPoints3D(px,py,pz, vx,vy,vz) > MAX_REPAIR_DISTANCE_CLIENT then
        outputChatBox("❌ Du bist zu weit vom Fahrzeug entfernt, um mit der Reparatur zu beginnen.", 255,100,0)
        return
    end

    repairProgressBar.active = true
    repairProgressBar.duration = duration
    repairProgressBar.endTime = getTickCount() + duration
    repairProgressBar.text = "Repariere Fahrzeug..."
    
    if not repairProgressBarRenderHandler then 
        repairProgressBarRenderHandler = drawRepairProgressBar
        addEventHandler("onClientRender", root, repairProgressBarRenderHandler)
    end

    setPedAnimation(localPlayer, "SHOP", "SHOP_shelf_get", -1, true, false, false, false, 250, true) 
    toggleAllControls(false, true, false) 

    setTimer(function()
        if isElement(localPlayer) then
            setPedAnimation(localPlayer, false) 
            toggleAllControls(true, true, true) 
        end
        repairProgressBar.active = false
        if repairProgressBarRenderHandler and isEventHandlerAdded("onClientRender", root, repairProgressBarRenderHandler) then
             removeEventHandler("onClientRender", root, repairProgressBarRenderHandler)
             repairProgressBarRenderHandler = nil
        end
    end, duration, 1)
end)


addEvent("mechanic:stopRepairProgressBar", true)
addEventHandler("mechanic:stopRepairProgressBar", root, function()
    repairProgressBar.active = false 
    if repairProgressBarRenderHandler and isEventHandlerAdded("onClientRender", root, repairProgressBarRenderHandler) then
        removeEventHandler("onClientRender", root, repairProgressBarRenderHandler)
        repairProgressBarRenderHandler = nil
    end
end)


addEventHandler("onClientResourceStop", resourceRoot, function()
    closeGarageRepairMenu()
    closeMechanicConfirmGUI()
    closePlayerAcceptGUI()
    closeSelfRepairConfirmGUI() -- NEU
    if repairProgressBar.active then 
        repairProgressBar.active = false
        if repairProgressBarRenderHandler and isEventHandlerAdded("onClientRender", root, repairProgressBarRenderHandler) then
            removeEventHandler("onClientRender", root, repairProgressBarRenderHandler)
            repairProgressBarRenderHandler = nil
        end
    end
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    _G.isRepairMenuVisible = false
    _G.isMechanicOfferGuiVisible = false
    _G.isRepairConfirmVisible = false
    _G.isSelfRepairConfirmGUIVisible = false -- NEU
    if type(repairProgressBar) ~= "table" then
        repairProgressBar = {
            active = false,
            endTime = 0,
            duration = 0,
            text = "Repariere Fahrzeug..."
        }
    end
    --outputDebugString("[RepairClient] V3.3 (SelfRepair GUI) geladen.")
end)