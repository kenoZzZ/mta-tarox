-- tarox/jobs/lkw/lkw_client.lua
-- MODIFIZIERT V2.3: Syntaxprüfung und Struktur

local localPlayer = getLocalPlayer()
local screenW, screenH = guiGetScreenSize()

local isLKWConfirmGUIVisible = false
local lkwJobDisplayName = ""
local lkwConfirmElements = {}

local deliveryBlip = nil
local deliveryCheckpoint = nil
local jobTimerLKWActive = false
local jobTimerLKWEndTime = 0

local colors = {
    BG_MAIN = tocolor(28, 30, 36, 240),
    BG_HEADER = tocolor(38, 40, 48, 245),
    TEXT_HEADER = tocolor(235, 235, 240),
    TEXT_LABEL = tocolor(190, 195, 205),
    BUTTON_YES_BG = tocolor(70, 180, 70, 220),
    BUTTON_YES_HOVER = tocolor(90, 200, 90, 230),
    BUTTON_NO_BG = tocolor(200, 70, 70, 220),
    BUTTON_NO_HOVER = tocolor(220, 90, 90, 230),
    BUTTON_TEXT_CONFIRM = tocolor(245, 245, 245),
    BORDER_LIGHT = tocolor(55, 58, 68, 180),
    BORDER_DARK = tocolor(20, 22, 28, 220),
    JOB_TIMER_TEXT = tocolor(255, 223, 0, 230)
}
local fonts = {
    HEADER = "default-bold",
    TEXT = "default",
    BUTTON_FONT = "default-bold",
    JOB_TIMER_FONT = "default-bold"
}
local layout = {
    panelW = 400, panelH_confirm = 200,
    headerH = 45, padding = 20,
    buttonH = 40, buttonSpacing = 12,
    JOB_TIMER_SCALE = 1.2
}
local icons = {
    CONFIRM = "user/client/images/usericons/confirm.png",
    CANCEL = "user/client/images/usericons/cancel.png"
}

-- Globale Flags Initialisierung (Fallback)
if _G.isPedGuiOpen == nil then _G.isPedGuiOpen = false end
if _G.isInventoryVisible == nil then _G.isInventoryVisible = false end
if _G.isDriveMenuVisible == nil then _G.isDriveMenuVisible = false end
if _G.isTheoryTestVisible == nil then _G.isTheoryTestVisible = false end
if _G.isConfirmPracticalVisible == nil then _G.isConfirmPracticalVisible = false end
if _G.idPurchaseConfirmVisible == nil then _G.idPurchaseConfirmVisible = false end
if _G.idCardGuiVisible == nil then _G.idCardGuiVisible = false end
if _G.isHandyGUIVisible == nil then _G.isHandyGUIVisible = false end
if _G.isMessageGUIOpen == nil then _G.isMessageGUIOpen = false end
if _G.isBankGUIVisible == nil then _G.isBankGUIVisible = false end
if _G.isMechanicWindowVisible == nil then _G.isMechanicWindowVisible = false end
if _G.isMechanicOfferGuiVisible == nil then _G.isMechanicOfferGuiVisible = false end
if _G.isRepairConfirmVisible == nil then _G.isRepairConfirmVisible = false end
if _G.isRepairMenuVisible == nil then _G.isRepairMenuVisible = false end
if _G.isTuneMenuVisible == nil then _G.isTuneMenuVisible = false end
if _G.isPolicePanelVisible == nil then _G.isPolicePanelVisible = false end
if _G.isWantedPlayersGUIVisible == nil then _G.isWantedPlayersGUIVisible = false end
if _G.isMedicWindowVisible == nil then _G.isMedicWindowVisible = false end
if _G.isPatientListVisible == nil then _G.isPatientListVisible = false end
if _G.isYakuzaWindowVisible == nil then _G.isYakuzaWindowVisible = false end
if _G.isMocroWindowVisible == nil then _G.isMocroWindowVisible = false end
if _G.isCosaWindowVisible == nil then _G.isCosaWindowVisible = false end
if _G.isManagementVisible == nil then _G.isManagementVisible = false end
if _G.isJuwelierGUIVisible == nil then _G.isJuwelierGUIVisible = false end
if _G.isClothesMenuOpen == nil then _G.isClothesMenuOpen = false end
if _G.isFuelWindowVisible == nil then _G.isFuelWindowVisible = false end
if _G.isCarShopVisible == nil then _G.isCarShopVisible = false end
if _G.isSpawnWindowVisible == nil then _G.isSpawnWindowVisible = false end
if _G.isBankRobConfirmWindowActive == nil then _G.isBankRobConfirmWindowActive = false end
if _G.isCasinoRobConfirmWindowActive == nil then _G.isCasinoRobConfirmWindowActive = false end
if _G.isDeathScreenActive == nil then _G.isDeathScreenActive = false end
if _G.isLoginVisible == nil then _G.isLoginVisible = false end
if _G.isRegisterVisible == nil then _G.isRegisterVisible = false end
if _G.isUserPanelVisible == nil then _G.isUserPanelVisible = false end
if _G.isJailDoorBreakUIVisible == nil then _G.isJailDoorBreakUIVisible = false end
if _G.isJailHackSystemUIVisible == nil then _G.isJailHackSystemUIVisible = false end
if _G.isJobGuiOpen == nil then _G.isJobGuiOpen = false end
if _G.isCursorManuallyShownByClickSystem == nil then _G.isCursorManuallyShownByClickSystem = false end


local function dxDrawStyledConfirmButton(id, text, x, y, w, h, style, iconPath, targetElementTable)
    targetElementTable = targetElementTable or lkwConfirmElements
    local cX, cY = getCursorPosition(); local hover = false
    if cX then local mouseX, mouseY = cX*screenW, cY*screenH; hover = mouseX >= x and mouseX <= x+w and mouseY >= y and mouseY <= y+h end
    local currentBgColor = style.bg; if hover then currentBgColor = style.hover end
    dxDrawRectangle(x,y,w,h,currentBgColor)
    dxDrawLine(x,y,x+w,y,colors.BORDER_LIGHT,1); dxDrawLine(x,y+h,x+w,y+h,colors.BORDER_DARK,1)
    local textDrawX = x; local textDrawW = w
    if iconPath and fileExists(iconPath) then
        local iconDrawSize = 20; local iconX = x + (layout.padding/2); local iconY = y + (h-iconDrawSize)/2
        dxDrawImage(iconX, iconY, iconDrawSize, iconDrawSize, iconPath, 0,0,0,tocolor(255,255,255,220))
        textDrawX = iconX + iconDrawSize + (layout.padding/2); textDrawW = w - (textDrawX-x) - (layout.padding/2)
    end
    dxDrawText(text,textDrawX,y,textDrawX+textDrawW,y+h,style.text or colors.BUTTON_TEXT_CONFIRM,1.0, fonts.BUTTON_FONT ,"center","center",false,false,false,true)
    targetElementTable[id] = { x = x, y = y, w = w, h = h, action = id }
end

addEvent("jobs:lkwfahrer:confirmTourStart", true)
addEventHandler("jobs:lkwfahrer:confirmTourStart", root, function(displayName)
    -- Stelle sicher, dass die Funktion showLKWConfirmGUI_DX hier aufgerufen wird
    -- Diese Funktion sollte das DX Fenster anzeigen, um die Tour zu bestätigen.
    showLKWConfirmGUI_DX(displayName)
end)

function showLKWConfirmGUI_DX(displayName)
    --outputDebugString("[LKW_CLIENT DEBUG] showLKWConfirmGUI_DX aufgerufen. isLKWConfirmGUIVisible vorher: " .. tostring(isLKWConfirmGUIVisible))
    if isLKWConfirmGUIVisible then
        --outputDebugString("[LKW_CLIENT DEBUG] showLKWConfirmGUI_DX: GUI bereits sichtbar, return.")
        return
    end

    if (_G.isInventoryVisible == true) or (_G.isHandyGUIVisible == true) or (_G.isMessageGUIOpen == true) or (_G.isBankGUIVisible == true) or
       (_G.isTuneMenuVisible == true) or (_G.isRepairMenuVisible == true) or (_G.isMechanicOfferGuiVisible == true) or (_G.isRepairConfirmVisible == true) or
       (_G.isSelfRepairConfirmGUIVisible == true) or (_G.isPolicePanelVisible == true) or (_G.isMedicWindowVisible == true) or
       (_G.isUserPanelVisible == true) or (_G.isClothesMenuOpen == true) or (_G.isFuelWindowVisible == true) or (_G.isCarShopVisible == true) or
       (_G.isSpawnWindowVisible == true) or (_G.isJuwelierGUIVisible == true) or (_G.isDriveMenuVisible == true) or (_G.isTheoryTestVisible == true) or
       (_G.isConfirmPracticalVisible == true) or (_G.isBankRobConfirmWindowActive == true) or (_G.isCasinoRobConfirmWindowActive == true) or
       (_G.isJailDoorBreakUIVisible == true) or (_G.isJailHackSystemUIVisible == true) or (_G.isPedGuiOpen == true) then
        --outputDebugString("[LKW_CLIENT DEBUG] showLKWConfirmGUI_DX: Anderes _G-GUI ist aktiv, LKW-Job-GUI wird nicht geöffnet.")
        outputChatBox("Schließe zuerst andere Menüs, um den Job anzunehmen.", 255,165,0)
        return
    end

    _G.isJobGuiOpen = true
    isLKWConfirmGUIVisible = true
    lkwJobDisplayName = displayName
    lkwConfirmElements = {}
    --outputDebugString("[LKW_CLIENT DEBUG] showLKWConfirmGUI_DX: Flags gesetzt, isLKWConfirmGUIVisible: " .. tostring(isLKWConfirmGUIVisible) .. ", _G.isJobGuiOpen: " .. tostring(_G.isJobGuiOpen))

    if not isCursorShowing() then
        showCursor(true)
        --outputDebugString("[LKW_CLIENT DEBUG] showLKWConfirmGUI_DX: Cursor sichtbar gemacht.")
    end
    guiSetInputMode("no_binds_when_editing")

    if isEventHandlerAdded("onClientRender", root, renderLKWConfirmGUI_DX) then
        removeEventHandler("onClientRender", root, renderLKWConfirmGUI_DX)
    end
    addEventHandler("onClientRender", root, renderLKWConfirmGUI_DX)
    --outputDebugString("[LKW_CLIENT DEBUG] showLKWConfirmGUI_DX: Render-Handler hinzugefügt.")

    if isEventHandlerAdded("onClientClick", root, handleLKWConfirmClick_DX) then
        removeEventHandler("onClientClick", root, handleLKWConfirmClick_DX)
    end
    addEventHandler("onClientClick", root, handleLKWConfirmClick_DX)

    if isEventHandlerAdded("onClientKey", root, handleLKWConfirmKey_DX) then
        removeEventHandler("onClientKey", root, handleLKWConfirmKey_DX, true)
    end
    addEventHandler("onClientKey", root, handleLKWConfirmKey_DX, true)
end

function renderLKWConfirmGUI_DX()
    if not isLKWConfirmGUIVisible then return end

    local panelH = layout.panelH_confirm
    local panelX, panelY = (screenW - layout.panelW) / 2, (screenH - panelH) / 2

    dxDrawRectangle(panelX, panelY, layout.panelW, panelH, colors.BG_MAIN)
    dxDrawLine(panelX, panelY, panelX + layout.panelW, panelY, colors.BORDER_LIGHT, 2)
    dxDrawLine(panelX, panelY + panelH, panelX + layout.panelW, panelY + panelH, colors.BORDER_DARK, 2)
    dxDrawRectangle(panelX, panelY, layout.panelW, layout.headerH, colors.BG_HEADER)
    dxDrawText(lkwJobDisplayName .. " - Tour starten?", panelX, panelY, panelX + layout.panelW, panelY + layout.headerH, colors.TEXT_HEADER, 1.2, fonts.HEADER, "center", "center")

    local messageY = panelY + layout.headerH + layout.padding
    local textHeightForOneLine = dxGetFontHeight(1.0, fonts.TEXT)
    if not textHeightForOneLine or textHeightForOneLine <= 0 then textHeightForOneLine = 16 end

    local line1Text = "Möchtest du die LKW-Tour jetzt beginnen?"
    dxDrawText(line1Text, panelX + layout.padding, messageY, panelX + layout.panelW - layout.padding, messageY + textHeightForOneLine * 2, colors.TEXT_LABEL, 1.0, fonts.TEXT, "center", "center", true)

    local buttonAreaY = panelY + panelH - layout.padding - layout.buttonH
    local confirmButtonW = (layout.panelW - layout.padding*2 - layout.buttonSpacing) / 2

    dxDrawStyledConfirmButton("lkw_confirm_yes", "Ja, Tour starten", panelX + layout.padding, buttonAreaY, confirmButtonW, layout.buttonH, {bg = colors.BUTTON_YES_BG, hover = colors.BUTTON_YES_HOVER, text=colors.BUTTON_TEXT_CONFIRM}, icons.CONFIRM, lkwConfirmElements)
    dxDrawStyledConfirmButton("lkw_confirm_no", "Nein, abbrechen", panelX + layout.padding + confirmButtonW + layout.buttonSpacing, buttonAreaY, confirmButtonW, layout.buttonH, {bg = colors.BUTTON_NO_BG, hover = colors.BUTTON_NO_HOVER, text=colors.BUTTON_TEXT_CONFIRM}, icons.CANCEL, lkwConfirmElements)
end

function handleLKWConfirmClick_DX(button, state, absX, absY)
    if not isLKWConfirmGUIVisible or button ~= "left" or state ~= "up" then return end
    --outputDebugString("[LKW_CLIENT DEBUG] handleLKWConfirmClick_DX: Klick registriert.")

    for id, area in pairs(lkwConfirmElements) do
        if absX >= area.x and absX <= area.x + area.w and absY >= area.y and absY <= area.y + area.h then
            --outputDebugString("[LKW_CLIENT DEBUG] Klick auf Button: " .. id)
            if id == "lkw_confirm_yes" then
                triggerServerEvent("jobs:lkwfahrer:startTourConfirmed", localPlayer)
                --outputDebugString("[LKW_CLIENT DEBUG] Event 'jobs:lkwfahrer:startTourConfirmed' an Server gesendet.")
            end
            closeLKWConfirmGUI_DX()
            playSoundFrontEnd(40)
            return
        end
    end
end

function handleLKWConfirmKey_DX(key, press)
    if not isLKWConfirmGUIVisible or not press then return end
    if key == "escape" then
        --outputDebugString("[LKW_CLIENT DEBUG] Escape gedrückt, schließe LKW Confirm GUI.")
        closeLKWConfirmGUI_DX()
        cancelEvent()
    end
end

function closeLKWConfirmGUI_DX()
    --outputDebugString("[LKW_CLIENT DEBUG] closeLKWConfirmGUI_DX aufgerufen. isLKWConfirmGUIVisible vorher: " .. tostring(isLKWConfirmGUIVisible))
    if not isLKWConfirmGUIVisible then return end
    isLKWConfirmGUIVisible = false
    _G.isJobGuiOpen = false
    --outputDebugString("[LKW_CLIENT DEBUG] closeLKWConfirmGUI_DX: Flags zurückgesetzt. _G.isJobGuiOpen: " .. tostring(_G.isJobGuiOpen))


    if isEventHandlerAdded("onClientRender", root, renderLKWConfirmGUI_DX) then
        removeEventHandler("onClientRender", root, renderLKWConfirmGUI_DX)
    end
    if isEventHandlerAdded("onClientClick", root, handleLKWConfirmClick_DX) then
        removeEventHandler("onClientClick", root, handleLKWConfirmClick_DX)
    end
    if isEventHandlerAdded("onClientKey", root, handleLKWConfirmKey_DX) then
        removeEventHandler("onClientKey", root, handleLKWConfirmKey_DX, true)
    end

    local anyOtherMajorGuiActive = (_G.isInventoryVisible == true) or (_G.isHandyGUIVisible == true) or (_G.isMessageGUIOpen == true) or (_G.isBankGUIVisible == true) or
                               (_G.isTuneMenuVisible == true) or (_G.isRepairMenuVisible == true) or (_G.isMechanicOfferGuiVisible == true) or
                               (_G.isRepairConfirmVisible == true) or (_G.isSelfRepairConfirmGUIVisible == true) or (_G.isPolicePanelVisible == true) or
                               (_G.isMedicWindowVisible == true) or (_G.isUserPanelVisible == true) or (_G.isClothesMenuOpen == true) or (_G.isFuelWindowVisible == true) or
                               (_G.isCarShopVisible == true) or (_G.isSpawnWindowVisible == true) or (_G.isJuwelierGUIVisible == true) or
                               (_G.isDriveMenuVisible == true) or (_G.isTheoryTestVisible == true) or (_G.isConfirmPracticalVisible == true) or
                               (_G.isBankRobConfirmWindowActive == true) or (_G.isCasinoRobConfirmWindowActive == true) or
                               (_G.isJailDoorBreakUIVisible == true) or (_G.isJailHackSystemUIVisible == true) or (_G.isPedGuiOpen == true)

    if not anyOtherMajorGuiActive then
        if not (_G.isCursorManuallyShownByClickSystem == true) then
            showCursor(false)
            guiSetInputMode("allow_binds")
            --outputDebugString("[LKW_CLIENT DEBUG] closeLKWConfirmGUI_DX: Cursor ausgeblendet, da keine anderen GUIs aktiv.")
        else
            --outputDebugString("[LKW_CLIENT DEBUG] closeLKWConfirmGUI_DX: Cursor bleibt sichtbar (manuell aktiviert).")
        end
    else
         --outputDebugString("[LKW_CLIENT DEBUG] closeLKWConfirmGUI_DX: Cursor bleibt sichtbar (andere GUIs aktiv).")
    end
    lkwConfirmElements = {}
    lkwJobDisplayName = ""
end

function updateLKWDeliveryMarker(checkpointPos, lkwModel, trailerModel)
    cleanupLKWDeliveryMarker()
    --outputDebugString("[LKW_CLIENT DEBUG] updateLKWDeliveryMarker: Erstelle Marker bei X:" .. checkpointPos.x .. " Y:" .. checkpointPos.y) --

    deliveryCheckpoint = createMarker(checkpointPos.x, checkpointPos.y, checkpointPos.z -1, "checkpoint", 7.0, 0, 0, 255, 180)
    deliveryBlip = createBlipAttachedTo(deliveryCheckpoint, 56, 2, 0, 0, 255, 255, 0, 99999.0)

    if isElement(deliveryCheckpoint) then
        setElementDimension(deliveryCheckpoint, getElementDimension(localPlayer))
        setElementInterior(deliveryCheckpoint, getElementInterior(localPlayer))
    else
        outputDebugString("[LKW_CLIENT DEBUG] FEHLER: Konnte DeliveryCheckpoint nicht erstellen.")
    end
    if isElement(deliveryBlip) then
        setElementDimension(deliveryBlip, getElementDimension(localPlayer))
        setElementInterior(deliveryBlip, getElementInterior(localPlayer))
    else
        outputDebugString("[LKW_CLIENT DEBUG] FEHLER: Konnte DeliveryBlip nicht erstellen.")
    end
end
addEvent("jobs:lkwfahrer:updateDeliveryMarker", true)
addEventHandler("jobs:lkwfahrer:updateDeliveryMarker", root, updateLKWDeliveryMarker)

function cleanupLKWDeliveryMarker()
    --outputDebugString("[LKW_CLIENT DEBUG] cleanupLKWDeliveryMarker aufgerufen.") --
    if isElement(deliveryCheckpoint) then destroyElement(deliveryCheckpoint); deliveryCheckpoint = nil; end
    if isElement(deliveryBlip) then destroyElement(deliveryBlip); deliveryBlip = nil; end
end
addEvent("jobs:lkwfahrer:trailerDelivered", true)
addEventHandler("jobs:lkwfahrer:trailerDelivered", root, cleanupLKWDeliveryMarker)

addEvent("jobs:lkwfahrer:jobCancelled", true)
addEventHandler("jobs:lkwfahrer:jobCancelled", root, cleanupLKWDeliveryMarker)

local jobTimerRenderHandlerLKW = nil

function startJobTimerDisplayLKW(duration)
    --outputDebugString("[LKW_CLIENT DEBUG] startJobTimerDisplayLKW aufgerufen mit Dauer: " .. duration) --
    jobTimerLKWActive = true
    jobTimerLKWEndTime = getTickCount() + duration
    if not jobTimerRenderHandlerLKW then
        jobTimerRenderHandlerLKW = renderJobTimerDisplayLKW
        addEventHandler("onClientRender", root, jobTimerRenderHandlerLKW)
        --outputDebugString("[LKW_CLIENT DEBUG] Render-Handler für Job-Timer hinzugefügt.")
    end
end
addEvent("startJobTimerDisplay", true)
addEventHandler("startJobTimerDisplay", root, function(duration)
    local currentJob = getElementData(localPlayer, "currentJob")
    --outputDebugString("[LKW_CLIENT DEBUG] Event 'startJobTimerDisplay' empfangen. CurrentJob: " .. tostring(currentJob) .. ", Dauer: " .. duration) --
    if currentJob == "lkwfahrer" then
        startJobTimerDisplayLKW(duration)
    end
end)

function stopJobTimerDisplayLKW()
    --outputDebugString("[LKW_CLIENT DEBUG] stopJobTimerDisplayLKW aufgerufen.") --
    jobTimerLKWActive = false
    if jobTimerRenderHandlerLKW then
        if isEventHandlerAdded("onClientRender", root, jobTimerRenderHandlerLKW) then
            removeEventHandler("onClientRender", root, jobTimerRenderHandlerLKW)
            --outputDebugString("[LKW_CLIENT DEBUG] Render-Handler für Job-Timer entfernt.")
        end
        jobTimerRenderHandlerLKW = nil
    end
end
addEvent("stopJobTimerDisplay", true)
addEventHandler("stopJobTimerDisplay", root, function()
    local currentJob = getElementData(localPlayer, "currentJob")
     outputDebugString("[LKW_CLIENT DEBUG] Event 'stopJobTimerDisplay' empfangen. CurrentJob: " .. tostring(currentJob)) --
    if currentJob == "lkwfahrer" or not currentJob then
         stopJobTimerDisplayLKW()
    end
end)

function renderJobTimerDisplayLKW()
    if not jobTimerLKWActive then
        if jobTimerRenderHandlerLKW then
            if isEventHandlerAdded("onClientRender", root, jobTimerRenderHandlerLKW) then
                removeEventHandler("onClientRender", root, jobTimerRenderHandlerLKW)
            end
            jobTimerRenderHandlerLKW = nil
        end
        return
    end

    local remainingMs = jobTimerLKWEndTime - getTickCount()
    if remainingMs <= 0 then
        jobTimerLKWActive = false
        if jobTimerRenderHandlerLKW then
            if isEventHandlerAdded("onClientRender", root, jobTimerRenderHandlerLKW) then
                removeEventHandler("onClientRender", root, jobTimerRenderHandlerLKW)
            end
            jobTimerRenderHandlerLKW = nil
        end
        return
    end

    local totalSeconds = math.floor(remainingMs / 1000)
    local minutes = math.floor(totalSeconds / 60)
    local seconds = totalSeconds % 60
    local timerText = string.format("LKW-Tour Zeit: %02d:%02d", minutes, seconds)
    local textScale = layout.JOB_TIMER_SCALE
    local fontName = fonts.JOB_TIMER_FONT
    local textWidth = dxGetTextWidth(timerText, textScale, fontName)
    local textHeight = dxGetFontHeight(textScale, fontName)
    local posX = 30
    local posY = (screenH / 2) - (textHeight / 2) - 30
    dxDrawText(timerText, posX + 1, posY + 1, posX + textWidth + 6, posY + textHeight + 6, tocolor(0, 0, 0, 180), textScale, fontName, "left", "top", false, false, false, true)
    dxDrawText(timerText, posX, posY, posX + textWidth + 5, posY + textHeight + 5, colors.JOB_TIMER_TEXT, textScale, fontName, "left", "top", false, false, false, true)
end

addEventHandler("onClientMarkerHit", root, function(hitElement, matchingDimension)
    if not isElement(deliveryCheckpoint) or source ~= deliveryCheckpoint then return end
    if hitElement ~= localPlayer and getElementType(hitElement) ~= "vehicle" then return end

    local vehicleToCheck = nil
    if getElementType(hitElement) == "vehicle" then
        vehicleToCheck = hitElement
    elseif getElementType(hitElement) == "player" then
        vehicleToCheck = getPedOccupiedVehicle(hitElement)
    end

    if not isElement(vehicleToCheck) then return end
    if getElementData(vehicleToCheck, "isLKWJobVehicle") ~= true then return end
    if not matchingDimension then return end

    --outputDebugString("[LKW_CLIENT DEBUG] onClientMarkerHit: Korrekter Marker und Fahrzeug. Triggere Server-Event.") --
    triggerServerEvent("jobs:lkwfahrer:trailerReachedDeliveryPoint", localPlayer, vehicleToCheck)
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    closeLKWConfirmGUI_DX()
    cleanupLKWDeliveryMarker()
    stopJobTimerDisplayLKW()
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    if _G.isJobGuiOpen == nil then _G.isJobGuiOpen = false end
    outputDebugString("[LKW Job Client V2.3 DEBUG] LKW Fahrer Job geladen.")
end) -- Hier war die überflüssige Klammer.