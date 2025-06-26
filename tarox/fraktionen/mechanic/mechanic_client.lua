-- tarox/fraktionen/mechanic/mechanic_client.lua
-- Version 9: Korrekte Button-Aktivierung basierend auf mechanicImDienst und Icon-Nutzung
-- KORREKTUR: toggleAllControls für Tuning-Installation

local screenW, screenH = guiGetScreenSize()
local localPlayer = getLocalPlayer()

local isMechanicWindowVisible = false
local isRepairConfirmVisible = false -- Dieses GUI ist jetzt in repair_client.lua
local repairConfirmData = {} 
local repairConfirmWindowElements = {} 

local repairAnimActive = false 
local repairProgressBar = { -- Wird jetzt von repair_client.lua verwaltet
    active = false,
    endTime = 0,
    duration = 0,
    text = "Repariere Fahrzeug..."
}
-- local MAX_REPAIR_DISTANCE_CLIENT = 5 -- Wird in repair_client.lua benötigt

-- GUI Design-Parameter für Hauptmenü
local windowWidth, windowHeight = 380, 270 
local windowX = (screenW - windowWidth) / 2
local windowY = (screenH - windowHeight) / 2

local colors = {
    bgMain = tocolor(28, 30, 36, 230),
    headerBg = tocolor(0, 110, 180, 235), 
    headerText = tocolor(240, 240, 245),
    buttonBg = tocolor(70, 75, 85, 220),
    buttonHoverBg = tocolor(90, 95, 105, 230),
    buttonText = tocolor(235, 235, 240),
    buttonDisabledBg = tocolor(50, 55, 60, 180), 
    buttonDisabledText = tocolor(120, 120, 120, 200), 
    buttonActionBg = tocolor(60, 160, 60, 220), 
    buttonActionHoverBg = tocolor(80, 180, 80, 230),
    buttonRedBg = tocolor(180, 50, 50, 220),
    buttonRedHoverBg = tocolor(200, 70, 70, 230),
    borderLight = tocolor(55, 58, 68, 180),
    borderDark = tocolor(20, 22, 28, 220),
    
    confirmBg = tocolor(30,35,45,240),
    confirmHeaderBg = tocolor(0,90,150,245),
    confirmTextLight = tocolor(220,225,235),
    confirmButtonYesBg = tocolor(70,170,70,220),
    confirmButtonYesHover = tocolor(90,190,90,230),
    confirmButtonNoBg = tocolor(190,70,70,220),
    confirmButtonNoHover = tocolor(210,90,90,230),
    confirmButtonText = tocolor(250,250,250)
}

local icons = { 
    onDuty = "user/client/images/usericons/power_on.png",
    offDuty = "user/client/images/usericons/power_off.png",
    close = "user/client/images/usericons/close.png"
}

local buttonStructure = {} 
local displayRankText = "" 

local function dxDrawStyledButton(id, text, x, y, w, h, baseColor, hoverColor, textColor, enabled, iconPath)
    enabled = (enabled == nil) and true or enabled
    local mouseX, mouseY = getCursorPosition()
    local isHovering = false
    if enabled and mouseX and mouseY then 
        mouseX = mouseX * screenW
        mouseY = mouseY * screenH
        if mouseX >= x and mouseX <= x + w and mouseY >= y and mouseY <= y + h then
            isHovering = true
        end
    end

    local currentBg = baseColor
    local currentTextColor = textColor
    if not enabled then
        currentBg = colors.buttonDisabledBg
        currentTextColor = colors.buttonDisabledText
    elseif isHovering then
        currentBg = hoverColor
    end

    dxDrawRectangle(x, y, w, h, currentBg)
    dxDrawLine(x,y, x+w,y, tocolor(255,255,255,30), 1) 
    dxDrawLine(x,y+h, x+w,y+h, tocolor(0,0,0,100), 1) 
    dxDrawLine(x, y, x, y + h, colors.borderLight, 1)
    dxDrawLine(x + w, y, x + w, y + h, colors.borderDark, 1)

    local textDrawX = x
    local textDrawW = w
    local fontToUse = "default-bold"
    local scaleToUse = 1.1

    if iconPath and fileExists(iconPath) then
        local iconDrawSize = 20 
        local iconPadding = 8
        local textWidth = dxGetTextWidth(text, scaleToUse, fontToUse)
        local totalContentWidth = iconDrawSize + iconPadding + textWidth
        
        local startContentX = x + (w - totalContentWidth) / 2
        local iconDrawY = y + (h - iconDrawSize) / 2
        dxDrawImage(startContentX, iconDrawY, iconDrawSize, iconDrawSize, iconPath, 0,0,0,tocolor(255,255,255,230))
        
        textDrawX = startContentX + iconDrawSize + iconPadding
        dxDrawText(text, textDrawX, y, x + w - (startContentX - x), y + h, currentTextColor, scaleToUse, fontToUse, "left", "center", false, false, false, true)
    else
        dxDrawText(text, textDrawX, y, textDrawX + textDrawW, y + h, currentTextColor, scaleToUse, fontToUse, "center", "center", false, false, false, true)
    end
    
    if id then 
        buttonStructure[id] = { x = x, y = y, w = w, h = h, text = text, enabled = enabled, baseColor = baseColor, hoverColor = hoverColor, textColor = textColor, icon = iconPath }
    end
end

local function renderMechanicWindow()
    if not isMechanicWindowVisible then return end

    dxDrawRectangle(windowX, windowY, windowWidth, windowHeight, colors.bgMain)
    dxDrawLine(windowX, windowY, windowX + windowWidth, windowY, colors.borderLight, 2)
    dxDrawLine(windowX, windowY + windowHeight, windowX + windowWidth, windowY + windowHeight, colors.borderDark, 2)
    dxDrawLine(windowX, windowY, windowX, windowY + windowHeight, colors.borderLight, 2)
    dxDrawLine(windowX + windowWidth, windowY, windowX + windowWidth, windowY + windowHeight, colors.borderDark, 2)

    dxDrawRectangle(windowX, windowY, windowWidth, 45, colors.headerBg) 
    local headerString = "Mechanic Department"
    if displayRankText ~= "" and displayRankText ~= "-" then
        local cleanRank = string.gsub(displayRankText, "Lvl:%s*", "")
        headerString = headerString .. " (Rang: " .. cleanRank .. ")"
    end
    dxDrawText(headerString, windowX, windowY, windowX + windowWidth, windowY + 45, colors.headerText, 1.3, "default-bold", "center", "center")

    local btnWidth, btnHeight = 240, 42 
    local spacing = 12
    local startY = windowY + 45 + 25 

    local imDienst = getElementData(localPlayer, "mechanicImDienst") == true
    
    dxDrawStyledButton("antreten", "Dienst antreten", windowX + (windowWidth - btnWidth) / 2, startY, btnWidth, btnHeight, 
                       colors.buttonActionBg, colors.buttonActionHoverBg, colors.buttonText, not imDienst, icons.onDuty)
    
    startY = startY + btnHeight + spacing
    dxDrawStyledButton("verlassen_dienst", "Dienst verlassen", windowX + (windowWidth - btnWidth) / 2, startY, btnWidth, btnHeight, 
                       colors.buttonRedBg, colors.buttonRedHoverBg, colors.buttonText, imDienst, icons.offDuty)
    
    startY = startY + btnHeight + spacing + 10 
    dxDrawStyledButton("schliessen", "Schließen", windowX + (windowWidth - btnWidth) / 2, startY, btnWidth, btnHeight, colors.buttonBg, colors.buttonHoverBg, colors.buttonText, true, icons.close)
end

-- Die Funktion renderRepairConfirmationGUI wurde nach repair_client.lua verschoben,
-- da sie spezifisch für das Reparaturangebot ist.

-- Die Funktion drawRepairProgressBar wurde nach repair_client.lua verschoben,
-- da sie spezifisch für den Reparaturfortschritt ist.

local function openMechanicWindowPanel()
    if _G.isRepairMenuVisible or _G.isTuneMenuVisible then return end -- Verhindere Öffnen, wenn andere Mechaniker-GUIs offen sind
    
    displayRankText = getElementData(localPlayer, "rank") or "-" 

    if isMechanicWindowVisible then
        isMechanicWindowVisible = false
        _G.isMechanicWindowVisible = false
        if not _G.isRepairConfirmVisible and not _G.isPlayerAcceptGUIVisible then -- Aus repair_client.lua
            showCursor(false)
            guiSetInputMode("allow_binds")
        end
        if isEventHandlerAdded("onClientRender", root, renderMechanicWindow) then
            removeEventHandler("onClientRender", root, renderMechanicWindow)
        end
    else
        isMechanicWindowVisible = true
        _G.isMechanicWindowVisible = true
        if not isCursorShowing() then showCursor(true) end
        guiSetInputMode("no_binds_when_editing")
        if not isEventHandlerAdded("onClientRender", root, renderMechanicWindow) then
            addEventHandler("onClientRender", root, renderMechanicWindow)
        end
    end
end

addEvent("openMechanicWindow", true)
addEventHandler("openMechanicWindow", root, openMechanicWindowPanel)

-- Die Event-Handler für Reparatur-Bestätigungs-GUIs wurden nach repair_client.lua verschoben.
-- Der Event-Handler für mechanic:startRepairAnimationOnVehicle wurde nach repair_client.lua verschoben.

addEventHandler("onClientClick", root, function(button, state, absX, absY)
    if not isMechanicWindowVisible then return end -- Nur wenn das Haupt-Mechanikerfenster offen ist
    if button ~= "left" or state ~= "up" then return end

    for id, btnData in pairs(buttonStructure) do
        if btnData.enabled and absX >= btnData.x and absX <= btnData.x + btnData.w and absY >= btnData.y and absY <= btnData.y + btnData.h then
            if id == "antreten" then
                triggerServerEvent("onMechanicRequestSpawn", localPlayer)
            elseif id == "verlassen_dienst" then
                triggerServerEvent("onMechanicLeaveDuty", localPlayer)
            elseif id == "schliessen" then
                -- Die openMechanicWindowPanel Funktion toggled die Sichtbarkeit
            end
            openMechanicWindowPanel() -- Schließt oder öffnet das Fenster (Toggle-Logik)
            playSoundFrontEnd(40) 
            return
        end
    end
end)

addEventHandler("onClientKey", root, function(key, press)
    if key == "escape" and press then
        if isMechanicWindowVisible then
            openMechanicWindowPanel() -- Schließt das Fenster
            cancelEvent()
        -- Die Behandlung für repairProgressBar.active wurde nach repair_client.lua verschoben.
        end
    end
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    buttonStructure = {} 
    if _G.isMechanicWindowVisible == nil then _G.isMechanicWindowVisible = false end
end)

addEventHandler("onClientElementDataChange", localPlayer, function(dataName)
    if dataName == "rank" and isMechanicWindowVisible then
        displayRankText = getElementData(localPlayer, "rank") or "-"
    end
    if dataName == "mechanicImDienst" and isMechanicWindowVisible then
        -- Das GUI wird beim nächsten Render-Tick automatisch korrekt gezeichnet.
    end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if isMechanicWindowVisible then openMechanicWindowPanel() end
    -- Die Behandlung für repairProgressBar wurde nach repair_client.lua verschoben.
end)

--outputDebugString("[MechanicC] Mechanic Client-Skript V9 (Struktur angepasst, toggleAllControls Fix für Tuning) geladen.")