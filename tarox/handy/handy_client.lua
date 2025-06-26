-- tarox/handy/handy_client.lua
-- Version 6: Integration des Nachrichten-Systems (Aufruf) und kleinere Icon-Anpassung

local screenW, screenH = guiGetScreenSize()
local localPlayer = getLocalPlayer()

local isHandyVisible = false
local handyButtons = {} -- Tabelle für App-Icons/Buttons im Handy-UI
local closeButtonData = {} -- Separate Daten für den Schließen-Button

-- Handy-Design-Parameter
local handyWidth = 220
local handyHeight = 420
local handyX = screenW - handyWidth - 20
local handyY = screenH - handyHeight - 20
local handyBezelColor = tocolor(20, 20, 25, 255)
local handyScreenColor = tocolor(10, 12, 15, 240)
local handyScreenX = handyX + 8
local handyScreenY = handyY + 8
local handyScreenWidth = handyWidth - 16
local handyScreenHeight = handyHeight - 16

-- Header im Bildschirm
local screenHeaderHeight = 40
local screenHeaderColor = tocolor(25, 28, 32, 230)
local timeTextColor = tocolor(220, 220, 220, 200)

-- App-Icons/Buttons
local appIconSize = 40
local appIconSpacing = 12
local appsPerRow = 3
local appAreaPaddingX = 15
local appAreaPaddingY = 10
local appAreaStartX = handyScreenX + appAreaPaddingX
local appAreaStartY = handyScreenY + screenHeaderHeight + appAreaPaddingY

local appButtonTextColor = tocolor(230, 230, 230)
local appButtonFontScale = 1.0
local appButtonTextOffsetY = 4
local appRowHeight = appIconSize + dxGetFontHeight(appButtonFontScale, "default") + appButtonTextOffsetY + appIconSpacing

-- Schließen-Button (Home-Button-Stil)
local closeButtonSize = 45
local closeButtonX = handyX + (handyWidth - closeButtonSize) / 2
local closeButtonY = handyY + handyHeight - closeButtonSize - 12
local closeButtonColor = tocolor(40, 42, 48, 255)
local closeButtonHoverColor = tocolor(60, 62, 68, 255)
local closeButtonIconColor = tocolor(180, 180, 180)

_G.isHandyGUIVisible = false

-- Funktion zum Zeichnen des Handy-Fensters
local function renderHandyGUI()
    if not isHandyVisible then return end

    dxDrawRectangle(handyX, handyY, handyWidth, handyHeight, handyBezelColor)
    dxDrawRectangle(handyScreenX, handyScreenY, handyScreenWidth, handyScreenHeight, handyScreenColor)
    dxDrawRectangle(handyScreenX, handyScreenY, handyScreenWidth, screenHeaderHeight, screenHeaderColor)
    local currentTime = getRealTime()
    local timeString = string.format("%02d:%02d", currentTime.hour, currentTime.minute)
    dxDrawText(timeString, handyScreenX, handyScreenY, handyScreenX + handyScreenWidth - 10, handyScreenY + screenHeaderHeight, timeTextColor, 0.9, "default-bold", "right", "center")

    for id, buttonData in pairs(handyButtons) do
        if buttonData.iconPath and fileExists(buttonData.iconPath) then
            local iconColor = (isCursorOverButton(buttonData) and buttonData.hoverIconColor) or buttonData.iconColor or tocolor(255,255,255,220)
            dxDrawImage(buttonData.x, buttonData.y, buttonData.w, buttonData.h, buttonData.iconPath, 0,0,0, iconColor)
        else
            local bgColor = isCursorOverButton(buttonData) and tocolor(80,80,80,200) or tocolor(60,60,60,200)
            dxDrawRectangle(buttonData.x, buttonData.y, buttonData.w, buttonData.h, bgColor)
            dxDrawText("?", buttonData.x, buttonData.y, buttonData.x + buttonData.w, buttonData.y + buttonData.h, appButtonTextColor, 2.0, "default-bold", "center", "center")
        end
        dxDrawText(buttonData.text, buttonData.x, buttonData.y + buttonData.h + appButtonTextOffsetY, buttonData.x + buttonData.w, buttonData.y + buttonData.h + appButtonTextOffsetY + dxGetFontHeight(appButtonFontScale, "default"), appButtonTextColor, appButtonFontScale, "default", "center", "top")
    end

    local cbBgColor = isCursorOverButton(closeButtonData) and closeButtonHoverColor or closeButtonColor
    dxDrawRectangle(closeButtonData.x, closeButtonData.y, closeButtonData.w, closeButtonData.h, cbBgColor)
    local squareSize = closeButtonData.w * 0.4
    dxDrawRectangle(closeButtonData.x + (closeButtonData.w - squareSize)/2, closeButtonData.y + (closeButtonData.h - squareSize)/2, squareSize, squareSize, closeButtonIconColor)
end

function isCursorOverButton(buttonData)
    if not isCursorShowing() or not buttonData then return false end
    local cX, cY = getCursorPosition()
    if not cX then return false end
    local absCX, absCY = cX * screenW, cY * screenH
    return absCX >= buttonData.x and absCX <= buttonData.x + buttonData.w and
           absCY >= buttonData.y and absCY <= buttonData.y + buttonData.h
end

function toggleHandyVisibility()
    isHandyVisible = not isHandyVisible
    _G.isHandyGUIVisible = isHandyVisible

    if isHandyVisible then
        handyButtons = {}
        local col = 0
        local row = 0

        -- Userpanel Button
        local appX_up = appAreaStartX + col * (appIconSize + appIconSpacing)
        local appY_up = appAreaStartY + row * appRowHeight
        handyButtons["userpanel"] = {
            x = appX_up, y = appY_up, w = appIconSize, h = appIconSize,
            text = "Panel",
            iconPath = "handy/images/userpanel.png",
            iconColor = tocolor(200, 200, 255, 220),
            hoverIconColor = tocolor(230,230,255,255),
            action = function()
                triggerServerEvent("requestUserPanelDataFromHandy", localPlayer)
                toggleHandyVisibility()
            end
        }
        col = col + 1
        if col >= appsPerRow then col = 0; row = row + 1; end

        -- Nachrichten Button
        local appX_msg = appAreaStartX + col * (appIconSize + appIconSpacing)
        local appY_msg = appAreaStartY + row * appRowHeight
        handyButtons["messages"] = {
            x = appX_msg, y = appY_msg, w = appIconSize, h = appIconSize,
            text = "SMS",
            iconPath = "handy/images/message.png",
            iconColor = tocolor(180, 230, 180, 220),
            hoverIconColor = tocolor(210,255,210,255),
            action = function()
                if not _G.isMessageGUIOpen then
                    triggerEvent("messageSystem:openGUI", localPlayer)
                end
            end
        }
        col = col + 1
        if col >= appsPerRow then col = 0; row = row + 1; end

        closeButtonData = {
            x = closeButtonX, y = closeButtonY, w = closeButtonSize, h = closeButtonSize,
            action = function()
                toggleHandyVisibility()
            end
        }

        addEventHandler("onClientRender", root, renderHandyGUI)
        showCursor(true)
        guiSetInputMode("no_binds_when_editing")
    else
        removeEventHandler("onClientRender", root, renderHandyGUI)
        if _G.isMessageGUIOpen then
            triggerEvent("messageSystem:closeGUI", localPlayer)
        end
        if not _G.isInventoryVisible then
            showCursor(false)
            guiSetInputMode("allow_binds")
        end
        handyButtons = {}
        closeButtonData = {}
    end
end

addEvent("toggleHandyGUI", true)
addEventHandler("toggleHandyGUI", root, function()
    toggleHandyVisibility()
end)

bindKey("u", "down", function()
    local hatHandyItem = true -- Platzhalter, idealerweise serverseitig prüfen

    if hatHandyItem then
        if _G.isInventoryVisible or isChatBoxInputActive() or isConsoleActive() or isMainMenuActive() then
            return
        end
        if _G.isMessageGUIOpen then -- Wenn Nachrichtenfenster offen ist, schließe es zuerst
            triggerEvent("messageSystem:closeGUI", localPlayer)
            -- toggleHandyVisibility() -- Optional: Direkt das Handy-Menü schließen oder offen lassen
        else
            toggleHandyVisibility()
        end
    else
        outputChatBox("Du besitzt kein Handy.", 255, 100, 0)
    end
end)

addEventHandler("onClientClick", root, function(button, state)
    if not isHandyVisible or button ~= "left" or state ~= "up" then return end

    for id, buttonData in pairs(handyButtons) do
        if isCursorOverButton(buttonData) then
            if buttonData.action then
                buttonData.action()
                playSoundFrontEnd(40)
            end
            return
        end
    end

    if isCursorOverButton(closeButtonData) then
        if closeButtonData.action then
            closeButtonData.action()
            playSoundFrontEnd(41)
        end
        return
    end
end)

addEventHandler("onClientKey", root, function(key, press)
    if key == "escape" and press and isHandyVisible then
        if _G.isMessageGUIOpen then -- Wenn Nachrichtenfenster offen ist, schließe das zuerst
             triggerEvent("messageSystem:closeGUI", localPlayer)
        else
            toggleHandyVisibility()
        end
        cancelEvent()
    end
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    _G.isHandyGUIVisible = false
    outputDebugString("[Handy] Handy-System (Client V6) geladen.")
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if isHandyVisible then
        removeEventHandler("onClientRender", root, renderHandyGUI)
        showCursor(false)
        guiSetInputMode("allow_binds")
        isHandyVisible = false
        _G.isHandyGUIVisible = false
    end
    unbindKey("u", "down")
end)