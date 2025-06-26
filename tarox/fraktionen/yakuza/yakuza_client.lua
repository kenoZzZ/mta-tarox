---------------------------------------------
-- yakuza_fraction_client.lua (CLIENT)
---------------------------------------------

-------------------------------------------------
-- Automatische Tore für Yakuza
-------------------------------------------------
local yakuzaGates = {
    {
        index = 1,
        model = 971,
        posX = -2241.0, posY = 640.5, posZ = 52.8,
        openX = -2240.8, openY = 635.6, openZ = 52.8,
        scale = 1.26666,
        rotZ = 90,
        checkRadius = 10
    },
    {
        index = 2,
        model = 971,
        posX = -2213.5, posY = 579.1, posZ = 38.7,
        openX = -2220.4, openY = 579.6, openZ = 38.7,
        scale = 1.26666,
        checkRadius = 10
    }
}

local gateObjects = {}

addEventHandler("onClientResourceStart", resourceRoot, function()
    for _, gate in ipairs(yakuzaGates) do
        local obj = createObject(gate.model, gate.posX, gate.posY, gate.posZ, 0, 0, gate.rotZ or 0)
        if obj then
            setObjectScale(obj, gate.scale)
            gateObjects[gate.index] = obj
        end
    end
end)

local function checkYakuzaGates()
    for _, gate in ipairs(yakuzaGates) do
        local obj = gateObjects[gate.index]
        if isElement(obj) then
            local gateOpen = false
            for _, player in ipairs(getElementsByType("player")) do
                if getElementData(player, "group") == "Yakuza" then
                    local px, py = getElementPosition(player)
                    if getDistanceBetweenPoints2D(px, py, gate.posX, gate.posY) <= gate.checkRadius then
                        gateOpen = true
                        break
                    end
                end
            end
            moveObject(obj, 2000,
                       gateOpen and gate.openX or gate.posX,
                       gateOpen and gate.openY or gate.posY,
                       gate.posZ)
        end
    end
end
setTimer(checkYakuzaGates, 1000, 0)


-------------------------------------------------
-- Yakuza GUI (Leader oder so)
-------------------------------------------------
local screenW, screenH = guiGetScreenSize()
local windowWidth, windowHeight = 400, 250
local windowX, windowY = (screenW - windowWidth)/2, (screenH - windowHeight)/2

local yakuzaWindowVisible = false

local buttonW, buttonH = 180, 40
local btnSpawnX, btnSpawnY = windowX + (windowWidth - buttonW)/2, windowY + 70
local btnLeaveX, btnLeaveY = windowX + (windowWidth - buttonW)/2, windowY + 120
local btnCloseX, btnCloseY = windowX + (windowWidth - buttonW)/2, windowY + 170

local function renderYakuzaWindow()
    if not yakuzaWindowVisible then return end

    dxDrawRectangle(windowX, windowY, windowWidth, windowHeight, tocolor(0, 0, 0, 200))
    dxDrawRectangle(windowX, windowY, windowWidth, 40, tocolor(255, 0, 0, 220)) -- Yakuza Rot
    dxDrawText("Yakuza Management", windowX, windowY, windowX + windowWidth, windowY + 40, tocolor(255,255,255), 1.4, "default-bold", "center", "center")

    dxDrawRectangle(btnSpawnX, btnSpawnY, buttonW, buttonH, tocolor(50, 50, 50, 230))
    dxDrawText("Spawn as Yakuza", btnSpawnX, btnSpawnY, btnSpawnX + buttonW, btnSpawnY + buttonH, tocolor(255,255,255), 1.2, "default-bold", "center", "center")

    dxDrawRectangle(btnLeaveX, btnLeaveY, buttonW, buttonH, tocolor(50, 50, 50, 230))
    dxDrawText("Leave Fraction", btnLeaveX, btnLeaveY, btnLeaveX + buttonW, btnLeaveY + buttonH, tocolor(255,255,255), 1.2, "default-bold", "center", "center")

    dxDrawRectangle(btnCloseX, btnCloseY, buttonW, buttonH, tocolor(120, 0, 0, 230))
    dxDrawText("Close", btnCloseX, btnCloseY, btnCloseX + buttonW, btnCloseY + buttonH, tocolor(255,255,255), 1.2, "default-bold", "center", "center")
end

local function openYakuzaWindow()
    if yakuzaWindowVisible then return end
    yakuzaWindowVisible = true
    addEventHandler("onClientRender", root, renderYakuzaWindow)
    showCursor(true)
end

local function closeYakuzaWindow()
    yakuzaWindowVisible = false
    removeEventHandler("onClientRender", root, renderYakuzaWindow)
    showCursor(false)
end

addEventHandler("onClientClick", root, function(button, state, cx, cy)
    if not yakuzaWindowVisible then return end
    if button ~= "left" or state ~= "up" then return end

    if cx >= btnSpawnX and cx <= btnSpawnX + buttonW and cy >= btnSpawnY and cy <= btnSpawnY + buttonH then
        triggerServerEvent("onYakuzaRequestSpawn", localPlayer)
        closeYakuzaWindow()
        return
    end

    if cx >= btnLeaveX and cx <= btnLeaveX + buttonW and cy >= btnLeaveY and cy <= btnLeaveY + buttonH then
        triggerServerEvent("onYakuzaRequestLeave", localPlayer)
        closeYakuzaWindow()
        return
    end

    if cx >= btnCloseX and cx <= btnCloseX + buttonW and cy >= btnCloseY and cy <= btnCloseY + buttonH then
        closeYakuzaWindow()
        return
    end
end)

addEvent("openYakuzaWindow", true)
addEventHandler("openYakuzaWindow", root, function()
    openYakuzaWindow()
end)