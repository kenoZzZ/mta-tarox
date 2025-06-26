---------------------------------------------
-- cosa_client.lua (CLIENT-Side)
-- Automatische Tore für Cosa Nostra (ähnlich wie Yakuza)
-- + Cosa GUI (falls du das auch clientseitig willst)
---------------------------------------------

-------------------------------------------------
-- 1) Automatische Tore für Cosa
-------------------------------------------------
local cosaGates = {
    {
        index = 2,
        model = 971,
        posX = -1920.0, posY = 1350.0, posZ = 10.0,  -- weitere Tore
        openX = -1920.0, openY = 1345.0, openZ = 10.0,
        scale = 1.26666,
        rotZ = 90,
        checkRadius = 15
    }
}

local gateObjects = {}

addEventHandler("onClientResourceStart", resourceRoot, function()
    -- Erstelle alle Gate-Objekte
    for _, gate in ipairs(cosaGates) do
        local obj = createObject(gate.model, gate.posX, gate.posY, gate.posZ, 0, 0, gate.rotZ or 0)
        if obj then
            setObjectScale(obj, gate.scale or 1)
            gateObjects[gate.index] = obj
        end
    end
end)

-- Jede Sekunde checken: wenn ein Cosa-Mitglied im Umkreis => Gate verschieben
local function checkCosaGates()
    for _, gate in ipairs(cosaGates) do
        local obj = gateObjects[gate.index]
        if isElement(obj) then
            local shouldOpen = false
            for _, player in ipairs(getElementsByType("player")) do
                -- Prüfe, ob dieser Spieler "Cosa Nostra" in getElementData hat
                if getElementData(player, "group") == "Cosa Nostra" then
                    local px, py = getElementPosition(player)
                    if getDistanceBetweenPoints2D(px, py, gate.posX, gate.posY) <= (gate.checkRadius or 15) then
                        shouldOpen = true
                        break
                    end
                end
            end
            -- Nun "moveObject" je nach Zustand
            moveObject(obj, 2000,
                       shouldOpen and gate.openX or gate.posX,
                       shouldOpen and gate.openY or gate.posY,
                       gate.posZ)  -- Z bleibt fix (oder kannst du gate.openZ / gate.posZ analog wie yakuza)
        end
    end
end
setTimer(checkCosaGates, 1000, 0)

-------------------------------------------------
-- 2) Cosa GUI (falls ähnlich wie Yakuza)
-------------------------------------------------
local screenW, screenH = guiGetScreenSize()
local windowWidth, windowHeight = 400, 250
local windowX, windowY = (screenW - windowWidth)/2, (screenH - windowHeight)/2

local cosaWindowVisible = false

local buttonW, buttonH = 180, 40
local btnSpawnX, btnSpawnY = windowX + (windowWidth - buttonW)/2, windowY + 70
local btnLeaveX, btnLeaveY = windowX + (windowWidth - buttonW)/2, windowY + 120
local btnCloseX, btnCloseY = windowX + (windowWidth - buttonW)/2, windowY + 170

local function renderCosaWindow()
    if not cosaWindowVisible then return end

    dxDrawRectangle(windowX, windowY, windowWidth, windowHeight, tocolor(0, 0, 0, 200))
    dxDrawRectangle(windowX, windowY, windowWidth, 40, tocolor(0, 0, 0, 220))
    dxDrawText("Cosa Nostra Management", windowX, windowY, windowX + windowWidth, windowY + 40,
               tocolor(255,255,255), 1.4, "default-bold", "center", "center")

    dxDrawRectangle(btnSpawnX, btnSpawnY, buttonW, buttonH, tocolor(50, 50, 50, 230))
    dxDrawText("Spawn as Cosa", btnSpawnX, btnSpawnY, btnSpawnX + buttonW, btnSpawnY + buttonH,
               tocolor(255,255,255), 1.2, "default-bold", "center", "center")

    dxDrawRectangle(btnLeaveX, btnLeaveY, buttonW, buttonH, tocolor(50, 50, 50, 230))
    dxDrawText("Leave Fraction", btnLeaveX, btnLeaveY, btnLeaveX + buttonW, btnLeaveY + buttonH,
               tocolor(255,255,255), 1.2, "default-bold", "center", "center")

    dxDrawRectangle(btnCloseX, btnCloseY, buttonW, buttonH, tocolor(120, 0, 0, 230))
    dxDrawText("Close", btnCloseX, btnCloseY, btnCloseX + buttonW, btnCloseY + buttonH,
               tocolor(255,255,255), 1.2, "default-bold", "center", "center")
end

local function openCosaWindow()
    if cosaWindowVisible then return end
    cosaWindowVisible = true
    addEventHandler("onClientRender", root, renderCosaWindow)
    showCursor(true)
end

local function closeCosaWindow()
    cosaWindowVisible = false
    removeEventHandler("onClientRender", root, renderCosaWindow)
    showCursor(false)
end

addEventHandler("onClientClick", root, function(button, state, cx, cy)
    if not cosaWindowVisible then return end
    if button ~= "left" or state ~= "up" then return end

    if cx >= btnSpawnX and cx <= btnSpawnX + buttonW and cy >= btnSpawnY and cy <= btnSpawnY + buttonH then
        triggerServerEvent("onCosaRequestSpawn", localPlayer)
        closeCosaWindow()
        return
    end

    if cx >= btnLeaveX and cx <= btnLeaveX + buttonW and cy >= btnLeaveY and cy <= btnLeaveY + buttonH then
        triggerServerEvent("onCosaRequestLeave", localPlayer)
        closeCosaWindow()
        return
    end

    if cx >= btnCloseX and cx <= btnCloseX + buttonW and cy >= btnCloseY and cy <= btnCloseY + buttonH then
        closeCosaWindow()
        return
    end
end)

-- Server-Event => "openCosaWindow"
addEvent("openCosaWindow", true)
addEventHandler("openCosaWindow", root, function()
    openCosaWindow()
end)