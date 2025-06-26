------------------------------------------------------------------------------------
-- mocro_client.lua (CLIENT-Side)
-- Mit Bestätigungsdialog für "Leave Fraction".
-- Verwendet Events: openMocroWindow, onMocroRequestSpawn, onMocroRequestLeave
------------------------------------------------------------------------------------

local screenW, screenH = guiGetScreenSize()
local windowWidth, windowHeight = 350, 250
local windowX, windowY = (screenW - windowWidth)/2, (screenH - windowHeight)/2

local mocroWindowVisible = false
local showLeaveConfirmation = false
local fractionColor = {128, 0, 128, 230} -- Lila

-- Button Dimensionen
local buttonW, buttonH = 200, 45
local btnSpawnX = windowX + (windowWidth - buttonW)/2
local btnSpawnY = windowY + 70
local btnLeaveX = btnSpawnX
local btnLeaveY = btnSpawnY + buttonH + 15
local btnCloseX = btnSpawnX
local btnCloseY = btnLeaveY + buttonH + 15

-- Bestätigungsdialog Dimensionen und Button Positionen
local confirmW, confirmH = 300, 150
local confirmX, confirmY = (screenW - confirmW)/2, (screenH - confirmH)/2
local confirmBtnW, confirmBtnH = 100, 35
local confirmBtnYesX = confirmX + (confirmW / 4) - (confirmBtnW / 2)
local confirmBtnNoX = confirmX + (confirmW * 3 / 4) - (confirmBtnW / 2)
local confirmBtnY = confirmY + confirmH - confirmBtnH - 20

-- Funktion zum Rendern des Fensters
local function renderMocroWindow()
    if not mocroWindowVisible then return end

    -- Hauptfenster
    dxDrawRectangle(windowX, windowY, windowWidth, windowHeight, tocolor(10, 10, 10, 210))
    dxDrawRectangle(windowX, windowY, windowWidth, 40, tocolor(fractionColor[1], fractionColor[2], fractionColor[3], 230))
    dxDrawText("Mocro Mafia Management", windowX, windowY, windowX + windowWidth, windowY + 40,
               tocolor(200, 180, 200), 1.4, "default-bold", "center", "center") -- Angepasste Textfarbe
    dxDrawRectangle(btnSpawnX, btnSpawnY, buttonW, buttonH, tocolor(50, 50, 50, 230))
    dxDrawText("Spawn as Mocro Mafia", btnSpawnX, btnSpawnY, btnSpawnX + buttonW, btnSpawnY + buttonH,
               tocolor(255,255,255), 1.1, "default-bold", "center", "center")
    dxDrawRectangle(btnLeaveX, btnLeaveY, buttonW, buttonH, tocolor(100, 50, 100, 230))
    dxDrawText("Leave Fraction", btnLeaveX, btnLeaveY, btnLeaveX + buttonW, btnLeaveY + buttonH,
               tocolor(255,200,255), 1.1, "default-bold", "center", "center") -- Angepasste Textfarbe
    dxDrawRectangle(btnCloseX, btnCloseY, buttonW, buttonH, tocolor(150, 0, 150, 230))
    dxDrawText("Close", btnCloseX, btnCloseY, btnCloseX + buttonW, btnCloseY + buttonH,
               tocolor(255,255,255), 1.1, "default-bold", "center", "center")

    -- Bestätigungsdialog
    if showLeaveConfirmation then
        dxDrawRectangle(0, 0, screenW, screenH, tocolor(0, 0, 0, 100)) -- Overlay
        dxDrawRectangle(confirmX, confirmY, confirmW, confirmH, tocolor(30, 10, 30, 240))
        dxDrawText("Leave Mocro Mafia?", confirmX, confirmY + 10, confirmX + confirmW, confirmY + 40,
                   tocolor(220, 180, 220), 1.3, "default-bold", "center", "top")
        dxDrawText("Are you sure you want to\nleave the fraction?", confirmX+10, confirmY + 50, confirmX + confirmW - 10, confirmY + confirmH - 60,
                   tocolor(255, 255, 255), 1.1, "default", "center", "top")
        -- Yes Button
        dxDrawRectangle(confirmBtnYesX, confirmBtnY, confirmBtnW, confirmBtnH, tocolor(0, 150, 0, 220))
        dxDrawText("Yes", confirmBtnYesX, confirmBtnY, confirmBtnYesX + confirmBtnW, confirmBtnY + confirmBtnH,
                   tocolor(255,255,255), 1.1, "default-bold", "center", "center")
        -- No Button
        dxDrawRectangle(confirmBtnNoX, confirmBtnY, confirmBtnW, confirmBtnH, tocolor(200, 0, 0, 220))
        dxDrawText("No", confirmBtnNoX, confirmBtnY, confirmBtnNoX + confirmBtnW, confirmBtnY + confirmBtnH,
                   tocolor(255,255,255), 1.1, "default-bold", "center", "center")
    end
end

local function openMocroWindow()
    if mocroWindowVisible then return end
    mocroWindowVisible = true
    showLeaveConfirmation = false
    addEventHandler("onClientRender", root, renderMocroWindow)
    showCursor(true)
    guiSetInputMode("no_binds_when_editing") -- Verhindert, dass Tastenbindungen ausgelöst werden
end

local function closeMocroWindow()
    if not mocroWindowVisible then return end
    mocroWindowVisible = false
    showLeaveConfirmation = false
    removeEventHandler("onClientRender", root, renderMocroWindow)
    showCursor(false)
    guiSetInputMode("allow_binds") -- Gibt Tastenbindungen wieder frei
end

-- Klick-Handler
addEventHandler("onClientClick", root, function(button, state, absX, absY)
    if not mocroWindowVisible or button ~= "left" or state ~= "up" then return end

    -- Klicks im Bestätigungsdialog zuerst behandeln
    if showLeaveConfirmation then
        -- Yes Button
        if absX >= confirmBtnYesX and absX <= confirmBtnYesX + confirmBtnW and absY >= confirmBtnY and absY <= confirmBtnY + confirmBtnH then
            triggerServerEvent("onMocroRequestLeave", localPlayer) -- NEUES Event
            closeMocroWindow()
        -- No Button
        elseif absX >= confirmBtnNoX and absX <= confirmBtnNoX + confirmBtnW and absY >= confirmBtnY and absY <= confirmBtnY + confirmBtnH then
            showLeaveConfirmation = false -- Nur Dialog schließen
        end
        return -- Wichtig: Verhindert Klicks auf Hauptfenster dahinter
    end

    -- Klicks im Hauptfenster
    -- Spawn Button
    if absX >= btnSpawnX and absX <= btnSpawnX + buttonW and absY >= btnSpawnY and absY <= btnSpawnY + buttonH then
        triggerServerEvent("onMocroRequestSpawn", localPlayer) -- NEUES Event
        closeMocroWindow()
    -- Leave Button
    elseif absX >= btnLeaveX and absX <= btnLeaveX + buttonW and absY >= btnLeaveY and absY <= btnLeaveY + buttonH then
        showLeaveConfirmation = true -- Nur Bestätigung anzeigen
    -- Close Button
    elseif absX >= btnCloseX and absX <= btnCloseX + buttonW and absY >= btnCloseY and absY <= btnCloseY + buttonH then
        closeMocroWindow()
    end
end)

-- Event vom Server zum Öffnen des Fensters
addEvent("openMocroWindow", true) -- NEUES Event
addEventHandler("openMocroWindow", root, openMocroWindow)

-- Aufräumen
addEventHandler("onClientResourceStop", resourceRoot, function()
    if mocroWindowVisible then
        closeMocroWindow()
    end
end)

--outpudDebugString("[MocroMafia] Client-Skript geladen (mit Leave-Bestätigung).")