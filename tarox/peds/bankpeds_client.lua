-- Dateiname: bankpeds_client.lua
-- tarox/peds/bankpeds_client.lua
-- Bereinigte Version mit Item-Bild im Job-Bestätigungsfenster
-- Anpassung für "Als Belohnung erhältst du:" Text
-- NEU: 15-Minuten Job-Timer Anzeige

local screenW, screenH = guiGetScreenSize()
if _G.isPedGuiOpen == nil then _G.isPedGuiOpen = false end 

local currentPedInfoWindow = nil
local currentJobConfirmWindow = nil

local colors = {
    BG_MAIN = tocolor(28, 30, 36, 240),
    BG_HEADER = tocolor(0, 100, 180, 230),
    TEXT_HEADER = tocolor(235, 235, 240),
    TEXT_LIGHT = tocolor(230, 230, 235, 255),
    TEXT_VALUE = tocolor(255, 223, 120), 
    BORDER_LIGHT = tocolor(55, 58, 68, 180),
    BORDER_DARK = tocolor(20, 22, 28, 220),
    BUTTON_YES_BG = tocolor(70, 180, 70, 220),
    BUTTON_YES_HOVER = tocolor(90, 200, 90, 230),
    BUTTON_NO_BG = tocolor(200, 70, 70, 220),
    BUTTON_NO_HOVER = tocolor(220, 90, 90, 230),
    BUTTON_TEXT = tocolor(245, 245, 245),
}
local fonts = {
    HEADER = "default-bold",
    TEXT = "default",
    BUTTON = "default-bold",
    VALUE = "default-bold" 
}

guiElements = { closeButton = nil, jobAcceptButton = nil, jobDeclineButton = nil }
local isPedGuiRenderHandlerActive = false
local isPedGuiClickHandlerActive = false
local currentJobPedIdentifier = nil

-- NEU: Variablen für Job-Timer Anzeige
local jobTimerDisplayActive = false
local jobTimerDisplayEndTime = 0
local isJobTimerRenderActive = false 

local function dxDrawStyledButton(text, x, y, w, h, bgColor, hoverColor, textColor, font, scale)
    local cX, cY = getCursorPosition()
    local hover = false
    if cX then
        local mouseX, mouseY = cX * screenW, cY * screenH
        hover = mouseX >= x and mouseX <= x + w and mouseY >= y and mouseY <= y + h
    end
    local currentBgColor = hover and hoverColor or bgColor
    dxDrawRectangle(x, y, w, h, currentBgColor)
    dxDrawLine(x, y, x + w, y, colors.BORDER_LIGHT, 1)
    dxDrawLine(x, y + h, x + w, y + h, colors.BORDER_DARK, 1)
    dxDrawLine(x, y, x, y + h, colors.BORDER_LIGHT, 1)
    dxDrawLine(x + w, y, x + w, y + h, colors.BORDER_DARK, 1)
    dxDrawText(text, x, y, x + w, y + h, textColor, scale, font, "center", "center", false, false, false, true)
end

function openPedInfoGUI(infoTable)
    if _G.isPedGuiOpen then return end 
    if type(infoTable) ~= "table" or not infoTable.title or not infoTable.messages then
        currentPedInfoWindow = {title="Fehler", messages={"Ungültige Daten vom Server."}, buttonText="OK"}
    else
        currentPedInfoWindow = infoTable
    end
    _G.isPedGuiOpen = true
    currentJobConfirmWindow = nil 
    if not _G.isCursorManuallyShownByClickSystem and not isCursorShowing() then showCursor(true) end
    guiSetInputMode("no_binds_when_editing")
    if not isPedGuiRenderHandlerActive then addEventHandler("onClientRender", root, renderPedGUI); isPedGuiRenderHandlerActive = true; end
    if not isPedGuiClickHandlerActive then addEventHandler("onClientClick", root, handlePedGUIClick); isPedGuiClickHandlerActive = true; end
end

function openJobConfirmationGUI(pedId, message, jobItemName, itemImagePath)
    if _G.isPedGuiOpen then return end
    currentJobPedIdentifier = pedId
    currentJobConfirmWindow = {
        title = "Jobangebot",
        message = message,
        rewardText = "Als Belohnung erhältst du:",
        itemName = jobItemName or "eine Belohnung",
        itemImage = itemImagePath, 
        acceptText = "Job annehmen",
        declineText = "Ablehnen"
    }
    _G.isPedGuiOpen = true
    currentPedInfoWindow = nil
    if not _G.isCursorManuallyShownByClickSystem and not isCursorShowing() then showCursor(true) end
    guiSetInputMode("no_binds_when_editing")
    if not isPedGuiRenderHandlerActive then addEventHandler("onClientRender", root, renderPedGUI); isPedGuiRenderHandlerActive = true; end
    if not isPedGuiClickHandlerActive then addEventHandler("onClientClick", root, handlePedGUIClick); isPedGuiClickHandlerActive = true; end
end

function closePedGUI()
    if not _G.isPedGuiOpen then return end
    _G.isPedGuiOpen = false
    currentPedInfoWindow = nil
    currentJobConfirmWindow = nil
    currentJobPedIdentifier = nil

    if type(_G.forceCloseManualCursor) == "function" then
        _G.forceCloseManualCursor() 
    elseif _G.isCursorManuallyShownByClickSystem then 
        _G.isCursorManuallyShownByClickSystem = false
        showCursor(false)
        guiSetInputMode("allow_binds")
    elseif isCursorShowing() and not _G.isInventoryVisible and not _G.isDriveMenuVisible and not _G.isTheoryTestVisible and not _G.isConfirmPracticalVisible and not _G.idPurchaseConfirmVisible and not _G.idCardGuiVisible then 
        showCursor(false)
        guiSetInputMode("allow_binds")
    end

    if isPedGuiRenderHandlerActive then removeEventHandler("onClientRender", root, renderPedGUI); isPedGuiRenderHandlerActive = false; end
    if isPedGuiClickHandlerActive then removeEventHandler("onClientClick", root, handlePedGUIClick); isPedGuiClickHandlerActive = false; end
    guiElements.closeButton = nil
    guiElements.jobAcceptButton = nil
    guiElements.jobDeclineButton = nil
end

function renderPedGUI()
    if not _G.isPedGuiOpen then return end

    if currentPedInfoWindow then
        local info = currentPedInfoWindow
        local panelW, panelH = 450, 180 
        local headerH = 45
        local padding = 15
        local buttonH = 40

        local lineHeight = dxGetFontHeight(1.0, fonts.TEXT) + 2 
        if lineHeight <=0 then lineHeight = 16 end 

        if info.messages and #info.messages > 0 then
            panelH = headerH + (padding * 2) + (#info.messages * lineHeight) + buttonH + padding
        else
            panelH = headerH + (padding * 2) + lineHeight + buttonH + padding
        end
        panelH = math.max(180, math.min(panelH, screenH * 0.7)) 

        local panelX, panelY = (screenW - panelW) / 2, (screenH - panelH) / 2

        dxDrawRectangle(panelX, panelY, panelW, panelH, colors.BG_MAIN)
        dxDrawLine(panelX, panelY, panelX + panelW, panelY, colors.BORDER_LIGHT, 2)
        dxDrawLine(panelX, panelY + panelH, panelX + panelW, panelH + panelY, colors.BORDER_DARK, 2)
        dxDrawLine(panelX, panelY, panelX, panelY + panelH, colors.BORDER_LIGHT, 2)
        dxDrawLine(panelX + panelW, panelY, panelX + panelW, panelH + panelY, colors.BORDER_DARK, 2)
        dxDrawRectangle(panelX, panelY, panelW, headerH, colors.BG_HEADER)
        dxDrawText(info.title or "Information", panelX, panelY, panelX + panelW, panelY + headerH, colors.TEXT_HEADER, 1.3, fonts.HEADER, "center", "center")

        local textY = panelY + headerH + padding
        local textRenderAreaHeight = panelH - headerH - (padding * 2) - buttonH
        local currentTextRenderedHeight = 0

        if info.messages and #info.messages > 0 then
            for _, message in ipairs(info.messages) do
                if currentTextRenderedHeight + lineHeight <= textRenderAreaHeight then
                    dxDrawText(message, panelX + padding, textY + currentTextRenderedHeight, panelX + panelW - padding, textY + currentTextRenderedHeight + lineHeight, colors.TEXT_LIGHT, 1.0, fonts.TEXT, "left", "top", true, true)
                    currentTextRenderedHeight = currentTextRenderedHeight + lineHeight
                else
                    break 
                end
            end
        else
            dxDrawText("Keine Informationen verfügbar.", panelX + padding, textY, panelX + panelW - padding, textY + lineHeight, colors.TEXT_LIGHT, 1.0, fonts.TEXT, "center", "top", true)
        end

        local btnW = 100
        local btnCloseX = panelX + (panelW - btnW) / 2
        local btnCloseY = panelY + panelH - padding - buttonH
        dxDrawStyledButton(info.buttonText or "Schließen", btnCloseX, btnCloseY, btnW, buttonH, colors.BUTTON_NO_BG, colors.BUTTON_NO_HOVER, colors.BUTTON_TEXT, fonts.BUTTON, 1.1)
        guiElements.closeButton = { x = btnCloseX, y = btnCloseY, w = btnW, h = buttonH }
        guiElements.jobAcceptButton = nil 
        guiElements.jobDeclineButton = nil

    elseif currentJobConfirmWindow then
        local jobUI = currentJobConfirmWindow
        local panelW, panelH = 480, 320 
        local headerH = 45
        local padding = 15
        local buttonH = 40
        local buttonSpacing = 10
        local itemImageSize = 64 
        local itemTextOffsetY = 5 

        local panelX, panelY = (screenW - panelW) / 2, (screenH - panelH) / 2

        dxDrawRectangle(panelX, panelY, panelW, panelH, colors.BG_MAIN)
        dxDrawLine(panelX, panelY, panelX + panelW, panelY, colors.BORDER_LIGHT, 2)
        dxDrawLine(panelX, panelY + panelH, panelX + panelW, panelH + panelY, colors.BORDER_DARK, 2)
        dxDrawLine(panelX, panelY, panelX, panelY + panelH, colors.BORDER_LIGHT, 2)
        dxDrawLine(panelX + panelW, panelY, panelX + panelW, panelH + panelY, colors.BORDER_DARK, 2)
        dxDrawRectangle(panelX, panelY, panelW, headerH, colors.BG_HEADER)
        dxDrawText(jobUI.title or "Jobangebot", panelX, panelY, panelX + panelW, panelY + headerH, colors.TEXT_HEADER, 1.3, fonts.HEADER, "center", "center")

        local messageTextY = panelY + headerH + padding
        local messageTextHeight = 60 
        dxDrawText(jobUI.message, panelX + padding, messageTextY, panelX + panelW - padding, messageTextY + messageTextHeight, colors.TEXT_LIGHT, 1.0, fonts.TEXT, "center", "center", true, true)

        local rewardLabelY = messageTextY + messageTextHeight + padding
        dxDrawText(jobUI.rewardText, panelX + padding, rewardLabelY, panelX + panelW - padding, rewardLabelY + 20, colors.TEXT_LIGHT, 1.0, fonts.TEXT, "center", "top", true, false)

        local itemDisplayY = rewardLabelY + 20 + itemTextOffsetY 
        if jobUI.itemImage and fileExists(jobUI.itemImage) then
            local imageX = panelX + (panelW - itemImageSize) / 2
            dxDrawImage(imageX, itemDisplayY, itemImageSize, itemImageSize, jobUI.itemImage, 0,0,0, tocolor(255,255,255,220))
            itemDisplayY = itemDisplayY + itemImageSize + itemTextOffsetY 
        else
            itemDisplayY = itemDisplayY + itemTextOffsetY 
        end

        dxDrawText(jobUI.itemName, panelX, itemDisplayY, panelX + panelW, itemDisplayY + 25, colors.TEXT_VALUE, 1.1, fonts.VALUE, "center", "top")

        local btnW = (panelW - (padding * 2) - buttonSpacing) / 2
        local btnDeclineX = panelX + padding
        local btnAcceptX = btnDeclineX + btnW + buttonSpacing
        local btnY = panelY + panelH - padding - buttonH 

        dxDrawStyledButton(jobUI.acceptText, btnAcceptX, btnY, btnW, buttonH, colors.BUTTON_YES_BG, colors.BUTTON_YES_HOVER, colors.BUTTON_TEXT, fonts.BUTTON, 1.1)
        dxDrawStyledButton(jobUI.declineText, btnDeclineX, btnY, btnW, buttonH, colors.BUTTON_NO_BG, colors.BUTTON_NO_HOVER, colors.BUTTON_TEXT, fonts.BUTTON, 1.1)

        guiElements.jobAcceptButton = { x = btnAcceptX, y = btnY, w = btnW, h = buttonH }
        guiElements.jobDeclineButton = { x = btnDeclineX, y = btnY, w = btnW, h = buttonH }
        guiElements.closeButton = nil 
    end
end

function handlePedGUIClick(button, state, absX, absY)
    if not _G.isPedGuiOpen or button ~= "left" or state ~= "up" then return end

    if currentPedInfoWindow and guiElements.closeButton then
        local btn = guiElements.closeButton
        if absX >= btn.x and absX <= btn.x + btn.w and absY >= btn.y and absY <= btn.y + btn.h then
            closePedGUI()
        end
    elseif currentJobConfirmWindow then
        local btnA = guiElements.jobAcceptButton
        local btnD = guiElements.jobDeclineButton
        if btnA and absX >= btnA.x and absX <= btnA.x + btnA.w and absY >= btnA.y and absY <= btnA.y + btnA.h then
            if currentJobPedIdentifier then
                triggerServerEvent("onPlayerAcceptsJobOffer", localPlayer, currentJobPedIdentifier)
            end
            closePedGUI()
        elseif btnD and absX >= btnD.x and absX <= btnD.x + btnD.w and absY >= btnD.y and absY <= btnD.y + btnD.h then
            closePedGUI()
        end
    end
end

addEvent("onServerSendsBankPedInfo", true)
addEventHandler("onServerSendsBankPedInfo", root, function(infoTable)
    openPedInfoGUI(infoTable)
end)

addEvent("onServerRequestsJobConfirmation", true)
addEventHandler("onServerRequestsJobConfirmation", root, function(pedId, message, jobItemName, itemImagePath) 
    openJobConfirmationGUI(pedId, message, jobItemName, itemImagePath)
end)

-- NEU: Event-Handler für den Job-Timer
addEvent("startJobTimerDisplay", true)
addEventHandler("startJobTimerDisplay", root, function(duration)
    jobTimerDisplayActive = true
    jobTimerDisplayEndTime = getTickCount() + duration
    if not isJobTimerRenderActive then
        addEventHandler("onClientRender", root, renderJobTimerDisplay)
        isJobTimerRenderActive = true
    end
end)

addEvent("stopJobTimerDisplay", true)
addEventHandler("stopJobTimerDisplay", root, function()
    jobTimerDisplayActive = false
    if isJobTimerRenderActive then
        removeEventHandler("onClientRender", root, renderJobTimerDisplay)
        isJobTimerRenderActive = false
    end
end)

-- NEU: Render-Funktion für den Job-Timer
function renderJobTimerDisplay()
    if not jobTimerDisplayActive then
        if isJobTimerRenderActive then -- Sicherstellen, dass der Handler entfernt wird
            removeEventHandler("onClientRender", root, renderJobTimerDisplay)
            isJobTimerRenderActive = false
        end
        return
    end

    local remainingMs = jobTimerDisplayEndTime - getTickCount()
    if remainingMs <= 0 then
        jobTimerDisplayActive = false 
        if isJobTimerRenderActive then -- Handler entfernen
            removeEventHandler("onClientRender", root, renderJobTimerDisplay)
            isJobTimerRenderActive = false
        end
        return
    end

    local totalSeconds = math.floor(remainingMs / 1000)
    local minutes = math.floor(totalSeconds / 60)
    local seconds = totalSeconds % 60
    local timerText = string.format("Job-Zeit: %02d:%02d", minutes, seconds)

    local textScale = 1.2 
    local fontName = "default-bold" 
    
    local textWidth = dxGetTextWidth(timerText, textScale, fontName)
    local textHeight = dxGetFontHeight(textScale, fontName)
    
    local posX = 30 
    local posY = (screenH / 2) - (textHeight / 2) 

    dxDrawText(timerText, posX + 1, posY + 1, posX + textWidth + 6, posY + textHeight + 6, tocolor(0, 0, 0, 180), textScale, fontName, "left", "top", false, false, false, true)
    dxDrawText(timerText, posX, posY, posX + textWidth + 5, posY + textHeight + 5, tocolor(255, 223, 0, 230), textScale, fontName, "left", "top", false, false, false, true)
end


addEventHandler("onClientResourceStart", resourceRoot, function()
    if _G.isPedGuiOpen == nil then _G.isPedGuiOpen = false end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    closePedGUI() 
    -- NEU: Job-Timer Display stoppen und Handler entfernen
    if isJobTimerRenderActive then
        removeEventHandler("onClientRender", root, renderJobTimerDisplay)
        isJobTimerRenderActive = false
        jobTimerDisplayActive = false
    end
end)

-- outputDebugString("[BankPeds] Ped Job System (Client - mit Item-Bild V3, Text-Anpassung, Job-Timer V1) geladen.")