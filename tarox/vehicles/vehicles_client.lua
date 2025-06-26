-- tarox/vehicles/vehicles_client.lua
-- Enthält:
--   - Fuel-Client-Code (ANGEPASST: Shop/Spawn nur zu Fuß betretbar)
--   - Shop-Client-Code
--   - Spawn-Client-Code
-- KORRIGIERT: Client-Marker-Handler für Spawn entfernt
-- KORREKTUR V1.1: Sicherstellen, dass setVehicleColor mit korrekten RGB-Argumenten aufgerufen wird

local screenW, screenH = guiGetScreenSize()

---------------------------------------
-- Statische Positionen & Globale Variablen
---------------------------------------

-- Fuel Stations (Client-Side)
local fuelStations = {
    {x = -2406.44067, y = 976.44055, z = 45.29688},
    {x = -2021.53748, y = 158.37646, z = 28.69496},
    {x = -1677.62170, y = 411.71838, z = 7.17969},
	{x = 2639.37402, y = 1106.62402, z = 10.82031}
}
local fuelMarkers = {}

-- Car Shops (Client-Side)
local carShopMarkerPositions = {
    {x = -1966.14429, y = 293.96896, z = 35.46875},
    {x = 2131.88892, y = -1149.55298, z = 24.25534},
    {x = -2648.04126, y = -29.74344, z = 6.13281}
}
local carShopBlips = {}
local carShopMarkers = {}
local shopDisplayPosition = {x = -2030.06494, y = 157.33633, z = 33.93823, rotZ = 0}
local shopVehicleRotationSpeed = 0.2
local SHOP_DIMENSION = 1

-- Spawn Punkte / Garagen (Client-Side)
local spawnMarkerPositions = {
    { x = -2710.31299, y = 376.08527, z = 4.97273 },
    { x = -2412.31689, y = 950.10999, z = 45.29688 },
    { x = -1935.02173, y = 575.67462, z = 35.17188 },
    { x = -2035.12646, y = 174.76651, z = 28.83594 },
    { x = -2057.18970, y = -88.01767, z = 35.32031 },
    { x = -2266.85571, y = 158.26285, z = 35.31250 },
    { x = -2404.16406, y = 324.96268, z = 35.17188 },
    { x = -2199.40430, y = 306.03894, z = 35.11719 },
    { x = -2271.52075, y = 533.74780, z = 35.01562 },
    { x = -2190.72339, y = 1009.40668, z = 80.0 },
    { x = -1895.63647, y = 1165.12512, z = 45.45274 },
    { x = -1633.51599, y = 1199.96838, z = 7.18750 },
    { x = -1946.19189, y = 1332.03650, z = 7.18750 },
    { x = -2635.12891, y = 1360.98169, z = 7.12294 },
    { x = -2845.00317, y = 1001.12213, z = 41.94608 },
    { x = -2586.75879, y = 586.68079, z = 14.45312 },
    { x = -2418.80054, y = 730.94208, z = 35.17188 },
    { x = -1826.86182, y = 372.75009, z = 17.16406 },
    { x = -1529.62024, y = 707.78760, z = 7.18750 },
    { x = -1755.38416, y = 944.29816, z = 24.88281 },
    { x = -1981.41296, y = 883.49005, z = 45.20312 },
    { x = -2796.17651, y = 806.13947, z = 48.10721 },
    { x = -2649.92896, y = 32.01897, z = 4.33594 },
    { x = -2752.30029, y = -311.00696, z = 7.03906 },
    { x = -2392.59009, y = -588.97278, z = 132.73846 },
    { x = -2140.67432, y = -859.70044, z = 32.02344 },
    { x = -2150.67114, y = -406.47214, z = 35.33594 },
    { x = -1762.93726, y = -129.56950, z = 3.55469 },
    { x = -1710.01404, y = 398.62332, z = 7.17969 }
}
local spawnPointMarkers = {}
local spawnBlips = {}

-- Fuel UI
local fuelWindowVisible = false
local fuelAmount = 50
local maxFuel = 100
local totalCost = 0
local fuelPricePerUnit = 2
local fuelVehicleRef = nil
local fuelSliderX, fuelSliderY, fuelSliderWidth, fuelSliderHeight
local fuelIsDragging = false
local ui_buttonFillMax = {}
local ui_sliderHandle = {}

-- Car Shop UI
local shopVisible = false
local shopVehiclesForSale = {}
local shopCurrentVehicleIndex = 1
local shopDisplayVehicle = nil
local shopMenuWidth, shopMenuHeight = 400, 150
local shopMenuX = (screenW - shopMenuWidth) / 2
local shopMenuY = screenH - shopMenuHeight - 50
local shopButtonWidth, shopButtonHeight = 100, 40
local shopArrowSize = 40
local shopEnterX, shopEnterY, shopEnterZ, shopEnterRot = nil, nil, nil, nil
local originalPlayerDimension = 0

-- Spawn Manager UI
local spawnWindowVisible = false
local playerVehicles = {}
local selectedVehicleIndex = nil
local spawnLastClickTime = 0
local spawnWindowWidth, spawnWindowHeight = 380, 450
local spawnWindowX, spawnWindowY = screenW - spawnWindowWidth - 20, (screenH - spawnWindowHeight) / 2

local COLOR_BG = tocolor(25, 25, 30, 230)
local COLOR_TITLE_BG = tocolor(0, 80, 150, 200)
local COLOR_TITLE_TEXT = tocolor(255, 255, 255, 255)
local COLOR_LIST_BG = tocolor(40, 40, 45, 200)
local COLOR_LIST_ITEM_BG = tocolor(55, 55, 60, 200)
local COLOR_LIST_ITEM_SELECTED_BG = tocolor(0, 120, 200, 210)
local COLOR_LIST_ITEM_TEXT = tocolor(220, 220, 230)
local COLOR_LIST_HEADER_TEXT = tocolor(180, 180, 200)
local COLOR_HEALTH_GOOD = tocolor(80, 230, 80)
local COLOR_HEALTH_MED = tocolor(230, 230, 80)
local COLOR_HEALTH_BAD = tocolor(230, 80, 80)
local COLOR_HEALTH_DESTROYED = tocolor(120, 120, 120)
local COLOR_FUEL_SPAWN_UI = tocolor(255, 180, 100)
local COLOR_BUTTON_SPAWN = tocolor(50, 180, 50, 220)
local COLOR_BUTTON_REPAIR = tocolor(200, 120, 0, 220)
local COLOR_BUTTON_CLOSE_SPAWN_UI = tocolor(200, 50, 50, 220)
local COLOR_BUTTON_TEXT_SPAWN = tocolor(255, 255, 255, 255)
local COLOR_BUTTON_HOVER_SPAWN = tocolor(255, 255, 255, 50)

---------------------------------------
-- Hilfsfunktionen
---------------------------------------
function getVehicleModelNameSafe(modelID)
    local name = getVehicleNameFromModel(modelID)
    return name and name ~= "" and name or "Unknown Model"
end

function formatMoney(amount)
    local formatted = string.format("%.0f", amount or 0)
    local k
    repeat
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1.%2')
    until k == 0
    return "$" .. formatted
end

if not table.count then
    function table.count(t)
        if type(t) ~= "table" then return 0 end
        local count = 0
        for _ in pairs(t) do
            count = count + 1
        end
        return count
    end
end
---------------------------------------
-- TEIL 1: FUEL CLIENT FUNKTIONEN (ANGEPASST V3)
---------------------------------------

local fuelWindowColors = {
    BG_MAIN = tocolor(28, 30, 36, 235),
    BG_HEADER = tocolor(38, 40, 48, 245),
    TEXT_HEADER = tocolor(235, 235, 240),
    TEXT_LABEL = tocolor(170, 175, 185),
    TEXT_VALUE = tocolor(210, 215, 225),
    TEXT_COST_COLOR = tocolor(90, 210, 140),
    TEXT_FUEL_PERCENT_COLOR = tocolor(255, 200, 0),
    SLIDER_BG = tocolor(45, 48, 56, 230),
    SLIDER_FG = tocolor(0, 122, 204, 220),
    SLIDER_HANDLE_COLOR = tocolor(230, 230, 240, 250),
    BORDER_LIGHT = tocolor(55, 58, 68, 200),
    BORDER_DARK = tocolor(20, 22, 28, 220),
    BUTTON_ACTION_BG = tocolor(70, 180, 70, 220),
    BUTTON_ACTION_HOVER = tocolor(90, 200, 90, 230),
    BUTTON_CANCEL_BG = tocolor(200, 70, 70, 220),
    BUTTON_CANCEL_HOVER = tocolor(220, 90, 90, 230),
    BUTTON_TEXT = tocolor(245, 245, 245),
    BUTTON_MAX_BG = tocolor(0, 100, 160, 210),
    BUTTON_MAX_HOVER = tocolor(0, 120, 190, 220)
}

local fuelWindowFonts = {
    HEADER = "default-bold",
    LABEL = "default",
    VALUE = "default-bold",
    BUTTON = "default-bold"
}

local fuelWindowLayout = {
    panelW = 400, panelH = 360,
    headerH = 40,
    padding = 20,
    inputFieldH = 30,
    sliderHandleWidth = 10,
    sliderHandleHeightExtra = 8,
    buttonH = 42,
    buttonSpacing = 15,
    buttonMaxH = 28,
    buttonMaxW = 120,
    buttonMaxOffsetY = 8,
    iconSize = 20,
    iconPadding = 8
}
fuelWindowLayout.panelX = (screenW - fuelWindowLayout.panelW) / 2
fuelWindowLayout.panelY = (screenH - fuelWindowLayout.panelH) / 2

local function dxDrawStyledButtonForFuel(text, x, y, w, h, bgColor, hoverColor, textColor, fontStyle, iconPath)
    local cX, cY = getCursorPosition()
    local hover = false
    if cX then
        local mouseX, mouseY = cX * screenW, cY * screenH
        hover = mouseX >= x and mouseX <= x + w and mouseY >= y and mouseY <= y + h
    end
    local currentBgColor = hover and hoverColor or bgColor
    dxDrawRectangle(x, y, w, h, currentBgColor)
    dxDrawLine(x, y, x + w, y, fuelWindowColors.BORDER_LIGHT, 1)
    dxDrawLine(x, y + h, x + w, y + h, fuelWindowColors.BORDER_DARK, 1)
    dxDrawLine(x, y, x, y + h, fuelWindowColors.BORDER_LIGHT, 1)
    dxDrawLine(x + w, y, x + w, y + h, fuelWindowColors.BORDER_DARK, 1)

    local textDrawX = x
    local textDrawW = w
    local actualText = text
    local fontToUse = type(fontStyle) == "table" and fontStyle.font or fontStyle
    local scaleToUse = type(fontStyle) == "table" and fontStyle.scale or 1.0

    if iconPath and fileExists(iconPath) then
        local iconDrawSize = fuelWindowLayout.iconSize
        local iconDrawY = y + (h - iconDrawSize) / 2
        local textWidth = dxGetTextWidth(text, scaleToUse, fontToUse)
        local totalContentWidth = iconDrawSize + fuelWindowLayout.iconPadding + textWidth
        local startContentX = x + (w - totalContentWidth) / 2
        dxDrawImage(startContentX, iconDrawY, iconDrawSize, iconDrawSize, iconPath, 0,0,0,tocolor(255,255,255,230))
        textDrawX = startContentX + iconDrawSize + fuelWindowLayout.iconPadding
        dxDrawText(actualText, textDrawX, y, (x + w) - (startContentX - x) , y + h, textColor, scaleToUse, fontToUse, "left", "center", false, false, false, true)
    else
        dxDrawText(actualText, textDrawX, y, textDrawX + textDrawW, y + h, textColor, scaleToUse, fontToUse, "center", "center", false, false, false, true)
    end
end


function renderFuelWindow()
    if not fuelWindowVisible then return end

    local layout = fuelWindowLayout
    local colors = fuelWindowColors
    local fonts = fuelWindowFonts

    local winX, winY, winWidth, winHeight = layout.panelX, layout.panelY, layout.panelW, layout.panelH
    local currentFuel = 0
    if isElement(fuelVehicleRef) then currentFuel = getElementData(fuelVehicleRef, "fuel") or 0 end

    dxDrawRectangle(winX, winY, winWidth, winHeight, colors.BG_MAIN)
    dxDrawLine(winX, winY, winX + winWidth, winY, colors.BORDER_LIGHT, 2)
    dxDrawLine(winX, winY + winHeight, winX + winWidth, winY + winHeight, colors.BORDER_DARK, 2)
    dxDrawLine(winX, winY, winX, winY + winHeight, colors.BORDER_LIGHT, 2)
    dxDrawLine(winX + winWidth, winY, winX + winWidth, winY + winHeight, colors.BORDER_DARK, 2)

    dxDrawRectangle(winX, winY, winWidth, layout.headerH, colors.BG_HEADER)
    local headerText = "Tankstelle"
    local headerIconPath = "user/client/images/usericons/fuel.png"
    local textDrawX_h = winX; local textDrawW_h = winWidth
     if headerIconPath and fileExists(headerIconPath) then
        local iconDrawSize_h = layout.iconSize * 1.2
        local textWidth_h = dxGetTextWidth(headerText, 1.3, fonts.HEADER)
        local totalContentWidth_h = iconDrawSize_h + layout.iconPadding * 0.7 + textWidth_h
        local startContentX_h = winX + (winWidth - totalContentWidth_h) / 2
        local iconDrawY_h = winY + (layout.headerH - iconDrawSize_h) / 2
        dxDrawImage(startContentX_h, iconDrawY_h, iconDrawSize_h, iconDrawSize_h, headerIconPath, 0,0,0,tocolor(255,255,255,230))
        textDrawX_h = startContentX_h + iconDrawSize_h + layout.iconPadding * 0.7
        dxDrawText(headerText, textDrawX_h, winY, (winX + winWidth) - (startContentX_h - winX) , winY + layout.headerH, colors.TEXT_HEADER, 1.3, fonts.HEADER, "left", "center", false, false, false, true)
    else
        dxDrawText(headerText, textDrawX_h, winY, textDrawX_h + textDrawW_h, winY + layout.headerH, colors.TEXT_HEADER, 1.3, fonts.HEADER, "center", "center", false, false, false, true)
    end

    local contentY = winY + layout.headerH + layout.padding
    local contentX = winX + layout.padding
    local contentWidth = winWidth - (layout.padding * 2)
    local lineSpacing = 28

    dxDrawText("Aktueller Tank:", contentX, contentY, contentX + contentWidth, contentY + 20, colors.TEXT_LABEL, 1.0, fonts.LABEL, "left", "top")
    dxDrawText(math.floor(currentFuel) .. "%", contentX, contentY, contentX + contentWidth, contentY + 20, colors.TEXT_VALUE, 1.0, fonts.VALUE, "right", "top")
    contentY = contentY + lineSpacing

    dxDrawText("Ziel-Tankfüllung:", contentX, contentY, contentX + contentWidth, contentY + 20, colors.TEXT_LABEL, 1.0, fonts.LABEL, "left", "top")
    dxDrawText(math.floor(fuelAmount) .. "%", contentX, contentY, contentX + contentWidth, contentY + 20, colors.TEXT_FUEL_PERCENT_COLOR, 1.0, fonts.VALUE, "right", "top")
    contentY = contentY + lineSpacing + 5

    fuelSliderX = contentX
    fuelSliderY = contentY
    fuelSliderWidth = contentWidth
    fuelSliderHeight = layout.inputFieldH
    dxDrawRectangle(fuelSliderX, fuelSliderY, fuelSliderWidth, fuelSliderHeight, colors.SLIDER_BG)
    local sliderFillRatio = 0
    if maxFuel > 0 then sliderFillRatio = fuelAmount / maxFuel end
    dxDrawRectangle(fuelSliderX, fuelSliderY, fuelSliderWidth * sliderFillRatio, fuelSliderHeight, colors.SLIDER_FG)

    local handleVisualX = fuelSliderX + (fuelSliderWidth - layout.sliderHandleWidth) * sliderFillRatio
    handleVisualX = math.max(fuelSliderX, math.min(handleVisualX, fuelSliderX + fuelSliderWidth - layout.sliderHandleWidth))
    local handleVisualY = fuelSliderY - layout.sliderHandleHeightExtra / 2
    local handleVisualW = layout.sliderHandleWidth
    local handleVisualH = fuelSliderHeight + layout.sliderHandleHeightExtra
    ui_sliderHandle = {x = handleVisualX, y = handleVisualY, w = handleVisualW, h = handleVisualH}
    dxDrawRectangle(handleVisualX, handleVisualY, handleVisualW, handleVisualH, colors.SLIDER_HANDLE_COLOR)
    dxDrawLine(handleVisualX, handleVisualY, handleVisualX + handleVisualW, handleVisualY, colors.BORDER_DARK, 1)
    dxDrawLine(handleVisualX, handleVisualY + handleVisualH, handleVisualX + handleVisualW, handleVisualY + handleVisualH, colors.BORDER_LIGHT, 1)

    dxDrawLine(fuelSliderX, fuelSliderY, fuelSliderX + fuelSliderWidth, fuelSliderY, colors.BORDER_DARK, 1)
    dxDrawLine(fuelSliderX, fuelSliderY + fuelSliderHeight, fuelSliderX + fuelSliderWidth, fuelSliderY + fuelSliderHeight, colors.BORDER_LIGHT, 1)
    dxDrawLine(fuelSliderX, fuelSliderY, fuelSliderX, fuelSliderY + fuelSliderHeight, colors.BORDER_DARK, 1)
    dxDrawLine(fuelSliderX + fuelSliderWidth, fuelSliderY, fuelSliderX + fuelSliderWidth, fuelSliderY + fuelSliderHeight, colors.BORDER_LIGHT, 1)

    dxDrawText(math.floor(fuelAmount).."%", fuelSliderX, fuelSliderY, fuelSliderX+fuelSliderWidth, fuelSliderY+fuelSliderHeight, colors.TEXT_HEADER, 0.9, fonts.VALUE, "center", "center")
    contentY = contentY + fuelSliderHeight + layout.buttonMaxOffsetY

    local btnMaxX = contentX + (contentWidth - layout.buttonMaxW) / 2
    local btnMaxY = contentY
    dxDrawStyledButtonForFuel("Voll Auftanken", btnMaxX, btnMaxY, layout.buttonMaxW, layout.buttonMaxH, colors.BUTTON_MAX_BG, colors.BUTTON_MAX_HOVER, colors.BUTTON_TEXT, {font=fonts.BUTTON, scale=0.9}, nil)
    ui_buttonFillMax = {x = btnMaxX, y = btnMaxY, w = layout.buttonMaxW, h = layout.buttonMaxH}
    contentY = contentY + layout.buttonMaxH + layout.padding

    dxDrawText("Benötigt:", contentX, contentY, contentX + contentWidth, contentY + 20, colors.TEXT_LABEL, 1.0, fonts.LABEL, "left", "top")
    dxDrawText(math.floor(math.max(0, fuelAmount - currentFuel)) .. "%", contentX, contentY, contentX + contentWidth, contentY + 20, colors.TEXT_FUEL_PERCENT_COLOR, 1.0, fonts.VALUE, "right", "top")
    contentY = contentY + lineSpacing

    dxDrawText("Gesamtkosten:", contentX, contentY, contentX + contentWidth, contentY + 20, colors.TEXT_LABEL, 1.0, fonts.LABEL, "left", "top")
    dxDrawText(formatMoney(totalCost), contentX, contentY, contentX + contentWidth, contentY + 20, colors.TEXT_COST_COLOR, 1.1, fonts.VALUE, "right", "top")

    local btnW, btnH = (contentWidth - layout.buttonSpacing) / 2, layout.buttonH
    local btnYpos = winY + winHeight - btnH - layout.padding
    local btnRefuelX = contentX
    local btnCancelX = contentX + btnW + layout.buttonSpacing

    dxDrawStyledButtonForFuel("Tanken", btnRefuelX, btnYpos, btnW, btnH, colors.BUTTON_ACTION_BG, colors.BUTTON_ACTION_HOVER, colors.BUTTON_TEXT, {font=fonts.BUTTON, scale=1.1}, "user/client/images/usericons/confirm.png")
    dxDrawStyledButtonForFuel("Abbrechen", btnCancelX, btnYpos, btnW, btnH, colors.BUTTON_CANCEL_BG, colors.BUTTON_CANCEL_HOVER, colors.BUTTON_TEXT, {font=fonts.BUTTON, scale=1.1}, "user/client/images/usericons/cancel.png")

    if fuelIsDragging then
        local cX_render, cY_render = getCursorPosition()
        if cX_render then
            local mouseScreenX = cX_render * screenW
            local relativeX = mouseScreenX - fuelSliderX
            local ratio = math.max(0, math.min(1, relativeX / fuelSliderWidth))
            local currentFuelVal = 0
            if isElement(fuelVehicleRef) then currentFuelVal = getElementData(fuelVehicleRef, "fuel") or 0 end
            local targetFuel = maxFuel * ratio
            if targetFuel < currentFuelVal then targetFuel = currentFuelVal end
            fuelAmount = targetFuel
            totalCost = math.floor(math.max(0, fuelAmount - currentFuelVal) * fuelPricePerUnit)
        end
    end
end

function openFuelWindow()
    local playerVehicle = getPedOccupiedVehicle(getLocalPlayer())
    if playerVehicle and getVehicleController(playerVehicle) == getLocalPlayer() and getElementData(playerVehicle, "id") then
        fuelVehicleRef = playerVehicle
        fuelAmount = getElementData(fuelVehicleRef, "fuel") or 50
        maxFuel = 100
        totalCost = 0
        fuelWindowVisible = true
        fuelIsDragging = false
        ui_buttonFillMax = {}
        ui_sliderHandle = {}
        removeEventHandler("onClientRender", root, renderFuelWindow)
        addEventHandler("onClientRender", root, renderFuelWindow)
        showCursor(true)
    else
        outputChatBox("Du musst im Fahrersitz deines eigenen Fahrzeugs sitzen.", 255, 165, 0)
    end
end

function closeFuelWindow()
    if not fuelWindowVisible then return end
    fuelWindowVisible = false
    removeEventHandler("onClientRender", root, renderFuelWindow)
    showCursor(false)
    fuelVehicleRef = nil
    ui_buttonFillMax = {}
    ui_sliderHandle = {}
    fuelIsDragging = false
end

function refuelVehicle()
    if not isElement(fuelVehicleRef) then return end
    local vehicleID = getElementData(fuelVehicleRef, "id")
    if not vehicleID then return end
    triggerServerEvent("purchaseFuel", getLocalPlayer(), vehicleID, fuelAmount, totalCost)
    closeFuelWindow()
end

addEvent("updateVehicleFuel", true)
addEventHandler("updateVehicleFuel", root, function(newFuel)
    local playerVehicle = getPedOccupiedVehicle(getLocalPlayer())
    if isElement(playerVehicle) then
        setElementData(playerVehicle, "fuel", newFuel)
    end
    if fuelWindowVisible and isElement(fuelVehicleRef) and playerVehicle == fuelVehicleRef then
        local currentFuel = getElementData(fuelVehicleRef, "fuel") or 0
        if fuelAmount < currentFuel then fuelAmount = currentFuel end
        totalCost = math.floor(math.max(0, fuelAmount - currentFuel) * fuelPricePerUnit)
    end
end)

---------------------------------------
-- TEIL 2: SHOP CLIENT FUNKTIONEN
---------------------------------------
function openCarShop()
    if shopVisible then return end
    shopVisible = true
    shopCurrentVehicleIndex = 1
    originalPlayerDimension = getElementDimension(getLocalPlayer())
    setElementDimension(getLocalPlayer(), SHOP_DIMENSION)

    shopEnterX, shopEnterY, shopEnterZ = getElementPosition(getLocalPlayer())
    shopEnterRot = getPedRotation(getLocalPlayer())
    setElementFrozen(getLocalPlayer(), true)
    local camOffsetX, camOffsetY, camOffsetZ = 10, 4, 4

    if not shopDisplayPosition or not shopDisplayPosition.x then
        setCameraTarget(getLocalPlayer())
    else
        setCameraMatrix(shopDisplayPosition.x + camOffsetX, shopDisplayPosition.y + camOffsetY, shopDisplayPosition.z + camOffsetZ, shopDisplayPosition.x, shopDisplayPosition.y, shopDisplayPosition.z)
    end

    triggerServerEvent("onRequestVehiclesForSale", resourceRoot)
    showCursor(true)
    removeEventHandler("onClientRender", root, renderDXShop)
    addEventHandler("onClientRender", root, renderDXShop)
end

function updateCarShopVehicle()
    if isElement(shopDisplayVehicle) then destroyElement(shopDisplayVehicle); shopDisplayVehicle = nil; end
    if #shopVehiclesForSale > 0 then
        local vehicleData = shopVehiclesForSale[shopCurrentVehicleIndex]
        if vehicleData and vehicleData.model then
            if not shopDisplayPosition or not shopDisplayPosition.x then
                return
            end
            shopDisplayVehicle = createVehicle(vehicleData.model, shopDisplayPosition.x, shopDisplayPosition.y, shopDisplayPosition.z, 0, 0, shopDisplayPosition.rotZ + 65)
            if isElement(shopDisplayVehicle) then
                setElementDimension(shopDisplayVehicle, SHOP_DIMENSION)
                setElementInterior(shopDisplayVehicle, getElementInterior(getLocalPlayer()))
                setElementCollisionsEnabled(shopDisplayVehicle, false)
                setElementFrozen(shopDisplayVehicle, true)
                setVehicleDamageProof(shopDisplayVehicle, true)
                setVehicleColor(shopDisplayVehicle, 227, 187, 165)
            end
        end
    end
end

function buyCurrentVehicle()
    if #shopVehiclesForSale > 0 then
        local vehicleData = shopVehiclesForSale[shopCurrentVehicleIndex]
        if vehicleData then
            triggerServerEvent("onPlayerBuyVehicle", resourceRoot, vehicleData.model, vehicleData.price)
            closeCarShop()
        end
    end
end

function closeCarShop()
    if not shopVisible then return end
    shopVisible = false
    removeEventHandler("onClientRender", root, renderDXShop)
    showCursor(false)
    if isElement(shopDisplayVehicle) then destroyElement(shopDisplayVehicle); shopDisplayVehicle = nil; end

    setCameraTarget(getLocalPlayer())
    setElementDimension(getLocalPlayer(), originalPlayerDimension)
    setElementInterior(getLocalPlayer(), 0)

    if shopEnterX and shopEnterY and shopEnterZ then
        setElementVelocity(getLocalPlayer(), 0, 0, 0)
        setElementFrozen(getLocalPlayer(), false)
        shopEnterX, shopEnterY, shopEnterZ, shopEnterRot = nil, nil, nil, nil
    else
        setElementFrozen(getLocalPlayer(), false)
    end
end

addEvent("onReceiveVehiclesForSale", true)
addEventHandler("onReceiveVehiclesForSale", resourceRoot, function(vehicles)
    shopVehiclesForSale = vehicles or {}
    if #shopVehiclesForSale > 0 then
        shopCurrentVehicleIndex = 1
        updateCarShopVehicle()
    else
        if isElement(shopDisplayVehicle) then destroyElement(shopDisplayVehicle); shopDisplayVehicle = nil; end
    end
end)


function renderDXShop()
    if not shopVisible then return end
    local vehicleData = shopVehiclesForSale[shopCurrentVehicleIndex]
    local vehicleName = vehicleData and getVehicleModelNameSafe(vehicleData.model) or "No vehicles available"
    local vehiclePrice = vehicleData and formatMoney(vehicleData.price) or "---"
    dxDrawRectangle(shopMenuX, shopMenuY, shopMenuWidth, shopMenuHeight, tocolor(25, 25, 30, 220))
    dxDrawRectangle(shopMenuX, shopMenuY, shopMenuWidth, 35, tocolor(0, 80, 150, 200))
    dxDrawText("Vehicle Showroom", shopMenuX, shopMenuY, shopMenuX + shopMenuWidth, shopMenuY + 35, tocolor(255, 255, 255), 1.3, "default-bold", "center", "center")
    dxDrawText(vehicleName, shopMenuX, shopMenuY + 45, shopMenuX + shopMenuWidth, shopMenuY + 70, tocolor(230, 230, 255), 1.2, "default-bold", "center", "top")
    dxDrawText(vehiclePrice, shopMenuX, shopMenuY + 70, shopMenuX + shopMenuWidth, shopMenuY + 95, tocolor(100, 255, 100), 1.2, "default-bold", "center", "top")
    local arrowY = shopMenuY + (shopMenuHeight - shopArrowSize)/2 + 5
    local arrowLeftX = shopMenuX + 15
    local arrowRightX = shopMenuX + shopMenuWidth - shopArrowSize - 15
    dxDrawRectangle(arrowLeftX, arrowY, shopArrowSize, shopArrowSize, tocolor(60, 60, 70, 180))
    dxDrawText("<", arrowLeftX, arrowY, arrowLeftX + shopArrowSize, arrowY + shopArrowSize, tocolor(255, 255, 255), 1.8, "default-bold", "center", "center")
    dxDrawRectangle(arrowRightX, arrowY, shopArrowSize, shopArrowSize, tocolor(60, 60, 70, 180))
    dxDrawText(">", arrowRightX, arrowY, arrowRightX + shopArrowSize, arrowY + shopArrowSize, tocolor(255, 255, 255), 1.8, "default-bold", "center", "center")
    local btnY = shopMenuY + shopMenuHeight - shopButtonHeight - 15
    local btnExitX = shopMenuX + 20
    local btnBuyX = shopMenuX + shopMenuWidth - shopButtonWidth - 20
    dxDrawRectangle(btnExitX, btnY, shopButtonWidth, shopButtonHeight, tocolor(200, 50, 50, 220))
    dxDrawText("EXIT", btnExitX, btnY, btnExitX + shopButtonWidth, btnY + shopButtonHeight, tocolor(255, 255, 255), 1.1, "default-bold", "center", "center")
    dxDrawRectangle(btnBuyX, btnY, shopButtonWidth, shopButtonHeight, tocolor(50, 180, 50, 220))
    dxDrawText("BUY", btnBuyX, btnY, btnBuyX + shopButtonWidth, btnY + shopButtonHeight, tocolor(255, 255, 255), 1.1, "default-bold", "center", "center")

    if isElement(shopDisplayVehicle) then
        local rx, ry, rz = getElementRotation(shopDisplayVehicle)
        rz = rz + shopVehicleRotationSpeed
        setElementRotation(shopDisplayVehicle, rx, ry, rz)
    end
end

addEvent("onVehiclePurchaseSuccess", true)
addEventHandler("onVehiclePurchaseSuccess", root, function(model) end)

---------------------------------------
-- TEIL 3: SPAWN CLIENT FUNKTIONEN
---------------------------------------
function drawSpawnDXButton(text, x, y, width, height, baseColor, hoverColor, action)
    local cursorX, cursorY = getCursorPosition()
    local hover = false
    if cursorX and cursorY then
        local absX, absY = cursorX * screenW, cursorY * screenH
        hover = absX >= x and absX <= x + width and absY >= y and absY <= y + height
    end
    dxDrawRectangle(x, y, width, height, baseColor)
    if hover then dxDrawRectangle(x, y, width, height, hoverColor) end
    dxDrawLine(x, y, x+width, y, COLOR_TITLE_TEXT, 1)
    dxDrawLine(x, y+height, x+width, y+height, COLOR_TITLE_TEXT, 1)
    dxDrawLine(x, y, x, y+height, COLOR_TITLE_TEXT, 1)
    dxDrawLine(x+width, y, x+width, y+height, COLOR_TITLE_TEXT, 1)
    dxDrawText(text, x, y, x + width, y + height, COLOR_BUTTON_TEXT_SPAWN, 1.1, "default-bold", "center", "center")
end

function renderDXSpawnManager()
    if not spawnWindowVisible then return end
    dxDrawRectangle(spawnWindowX, spawnWindowY, spawnWindowWidth, spawnWindowHeight, COLOR_BG)
    dxDrawLine(spawnWindowX+1, spawnWindowY+1, spawnWindowX+spawnWindowWidth-1, spawnWindowY+1, COLOR_TITLE_TEXT, 1)
    dxDrawLine(spawnWindowX+1, spawnWindowY+spawnWindowHeight-1, spawnWindowX+spawnWindowWidth-1, spawnWindowY+spawnWindowHeight-1, tocolor(0,0,0,150), 1)
    dxDrawLine(spawnWindowX+1, spawnWindowY+1, spawnWindowX+1, spawnWindowY+spawnWindowHeight-1, COLOR_TITLE_TEXT, 1)
    dxDrawLine(spawnWindowX+spawnWindowWidth-1, spawnWindowY+1, spawnWindowX+spawnWindowWidth-1, spawnWindowY+spawnWindowHeight-1, tocolor(0,0,0,150), 1)
    dxDrawRectangle(spawnWindowX, spawnWindowY, spawnWindowWidth, 40, COLOR_TITLE_BG)
    dxDrawText("🚗 Vehicle Garage", spawnWindowX, spawnWindowY, spawnWindowX + spawnWindowWidth, spawnWindowY + 40, COLOR_TITLE_TEXT, 1.3, "default-bold", "center", "center")
    local listX = spawnWindowX + 15
    local listY = spawnWindowY + 55
    local listW = spawnWindowWidth - 30
    local listH = spawnWindowHeight - 150
    dxDrawRectangle(listX, listY, listW, listH, COLOR_LIST_BG)
    local nameWidthRatio = 0.45
    local healthWidthRatio = 0.25
    local fuelWidthRatio = 0.25
    local nameW = listW * nameWidthRatio
    local healthW = listW * healthWidthRatio
    local fuelW = listW * fuelWidthRatio
    local nameX = listX + 8
    local healthX = nameX + nameW
    local fuelX = healthX + healthW
    local headerY = listY + 5
    local headerH = 20
    dxDrawText("Vehicle", nameX, headerY, healthX, headerY + headerH, COLOR_LIST_HEADER_TEXT, 1.0, "default-bold", "left", "center")
    dxDrawText("HP", healthX, headerY, fuelX, headerY + headerH, COLOR_LIST_HEADER_TEXT, 1.0, "default-bold", "center", "center")
    dxDrawText("Fuel", fuelX, headerY, listX + listW - 8, headerY + headerH, COLOR_LIST_HEADER_TEXT, 1.0, "default-bold", "right", "center")
    dxDrawLine(listX + 2, headerY + headerH + 2, listX + listW - 2, headerY + headerH + 2, tocolor(255,255,255,30), 1)
    local itemStartY = headerY + headerH + 5
    local itemH = 30
    local itemSpacing = 4
    if #playerVehicles == 0 then
        dxDrawText("You own no vehicles.", listX, itemStartY, listX + listW, listY + listH, COLOR_LIST_ITEM_TEXT, 1.1, "default", "center", "center")
    else
        for i, vehicle in ipairs(playerVehicles) do
            local currentItemY = itemStartY + (i - 1) * (itemH + itemSpacing)
            if currentItemY < listY + listH - itemH then
                local modelID = tonumber(vehicle.model) or 0
                local vehicleName = (modelID > 0 and getVehicleModelNameSafe(modelID)) or "Unknown Vehicle"
                local health = tonumber(vehicle.health) or 0
                local fuel = tonumber(vehicle.fuel) or 0
                local healthStr = ""
                local healthColor = COLOR_HEALTH_DESTROYED
                if health <= 0 then healthStr = "DESTROYED"
                else
                    healthStr = math.floor(health / 10) .. "%"
                    if health > 700 then healthColor = COLOR_HEALTH_GOOD
                    elseif health > 300 then healthColor = COLOR_HEALTH_MED
                    else healthColor = COLOR_HEALTH_BAD end
                end
                local bgColor = (selectedVehicleIndex == i) and COLOR_LIST_ITEM_SELECTED_BG or COLOR_LIST_ITEM_BG
                dxDrawRectangle(listX + 2, currentItemY, listW - 4, itemH, bgColor)
                dxDrawText(vehicleName, nameX, currentItemY, healthX, currentItemY + itemH, COLOR_LIST_ITEM_TEXT, 1.0, "default-bold", "left", "center", true, false, false)
                dxDrawText(healthStr, healthX, currentItemY, fuelX, currentItemY + itemH, healthColor, 1.0, "default", "center", "center", false, false, false)
                local fuelStr = math.floor(fuel) .. "%"
                dxDrawText(fuelStr, fuelX, currentItemY, listX + listW - 8, currentItemY + itemH, COLOR_FUEL_SPAWN_UI, 1.0, "default", "right", "center", false, false, false)
            end
        end
    end
    local btnAreaY = spawnWindowY + spawnWindowHeight - 85
    local btnWidth, btnHeight = (listW - 20) / 2, 45
    local btnSpawnX = listX
    local btnRepairX = listX + btnWidth + 20
    local btnCloseX = spawnWindowX + (spawnWindowWidth - btnWidth) / 2
    local btnCloseY = btnAreaY + btnHeight + 10
    local btnCloseHeight = 35
    drawSpawnDXButton("Spawn", btnSpawnX, btnAreaY, btnWidth, btnHeight, COLOR_BUTTON_SPAWN, COLOR_BUTTON_HOVER_SPAWN, "spawn")
    drawSpawnDXButton("🔧 Repair", btnRepairX, btnAreaY, btnWidth, btnHeight, COLOR_BUTTON_REPAIR, COLOR_BUTTON_HOVER_SPAWN, "repair")
    drawSpawnDXButton("Close", btnCloseX, btnCloseY, btnWidth, btnCloseHeight, COLOR_BUTTON_CLOSE_SPAWN_UI, COLOR_BUTTON_HOVER_SPAWN, "close")
end

function openSpawnManager(vehicles)
    if spawnWindowVisible then return end
    spawnWindowVisible = true
    playerVehicles = vehicles or {}
    selectedVehicleIndex = nil
    removeEventHandler("onClientRender", root, renderDXSpawnManager)
    addEventHandler("onClientRender", root, renderDXSpawnManager)
    if not isCursorShowing() then showCursor(true) end
end

function closeSpawnManager()
    if not spawnWindowVisible then return end
    spawnWindowVisible = false
    removeEventHandler("onClientRender", root, renderDXSpawnManager)
    if isCursorShowing() then showCursor(false) end
    playerVehicles = {}
    selectedVehicleIndex = nil
end

function spawnSelectedVehicle()
    if not selectedVehicleIndex then outputChatBox("❌ Please select a vehicle first!", 255, 165, 0); return; end
    local vehicleData = playerVehicles[selectedVehicleIndex]
    if not vehicleData then outputChatBox("❌ Error: Invalid vehicle selection!", 255, 0, 0); return; end
    if tonumber(vehicleData.health) <= 0 then outputChatBox("❌ This vehicle is destroyed. Please repair it first!", 255, 100, 0); return; end
    triggerServerEvent("onPlayerSpawnVehicle", getLocalPlayer(), vehicleData.id)
    closeSpawnManager()
end

function repairSelectedVehicle()
    if not selectedVehicleIndex then outputChatBox("❌ Please select a vehicle to repair!", 255, 165, 0); return; end
    local vehicleData = playerVehicles[selectedVehicleIndex]
    if not vehicleData then outputChatBox("❌ Error: Invalid vehicle selection!", 255, 0, 0); return; end
    if tonumber(vehicleData.health) >= 1000 then outputChatBox("🔧 This vehicle doesn't seem to need body repairs.", 0, 255, 150); end
    triggerServerEvent("onPlayerRepairVehicle", getLocalPlayer(), vehicleData.id)
end

addEvent("onReceivePlayerVehicles", true)
addEventHandler("onReceivePlayerVehicles", root, function(vehicles)
    openSpawnManager(vehicles)
end)

addEvent("refreshVehicleSpawnMenu", true)
addEventHandler("refreshVehicleSpawnMenu", root, function(repairedVehicleID)
    if not spawnWindowVisible or not playerVehicles or #playerVehicles == 0 then return end
    for i, vehicleData in ipairs(playerVehicles) do
        if vehicleData.id == repairedVehicleID then
            playerVehicles[i].health = 1000
            break
        end
    end
end)

---------------------------------------
-- TEIL 4: Fuel Verbrauch (Logik bleibt, Anzeige entfernt)
---------------------------------------
function updateFuelClient()
    local veh = getPedOccupiedVehicle(getLocalPlayer())
    if isElement(veh) and getVehicleController(veh) == getLocalPlayer() then
        local engineState = getVehicleEngineState(veh)
        if engineState then
            local currentFuel = getElementData(veh, "fuel") or 100
            local vx, vy, vz = getElementVelocity(veh)
            local speed = math.sqrt(vx*vx + vy*vy + vz*vz) * 180
            local consumptionRate = 0.01 + (speed / 8000)
            local newFuel = math.max(0, currentFuel - consumptionRate)
            if newFuel ~= currentFuel then
                setElementData(veh, "fuel", newFuel, true)
            end
        end
    end
end
setTimer(updateFuelClient, 2000, 0)


---------------------------------------
-- TEIL 5: Event Handling & Start/Stop
---------------------------------------

addEventHandler("onClientClick", root, function(button, state, absX, absY)
    if fuelWindowVisible then
        onFuelClick(button, state, absX, absY)
    elseif shopVisible then
        onShopClick(button, state, absX, absY)
    elseif spawnWindowVisible then
        onClientClickSpawn(button, state, absX, absY)
    end
end)

function onFuelClick(button, state, absX, absY)
    if button == "left" then
        if state == "down" then
            if ui_sliderHandle and absX >= ui_sliderHandle.x and absX <= ui_sliderHandle.x + ui_sliderHandle.w and
               absY >= ui_sliderHandle.y and absY <= ui_sliderHandle.y + ui_sliderHandle.h then
                fuelIsDragging = true
                playSoundFrontEnd(40)
                return
            end
            if absX >= fuelSliderX and absX <= fuelSliderX + fuelSliderWidth and
               absY >= fuelSliderY and absY <= fuelSliderY + fuelSliderHeight then
                local relativeX = absX - fuelSliderX
                local currentFuelVal = 0
                if isElement(fuelVehicleRef) then currentFuelVal = getElementData(fuelVehicleRef, "fuel") or 0 end
                local ratio = math.max(0, math.min(1, relativeX / fuelSliderWidth))
                local targetFuel = maxFuel * ratio
                if targetFuel < currentFuelVal then targetFuel = currentFuelVal end
                fuelAmount = targetFuel
                totalCost = math.floor(math.max(0, fuelAmount - currentFuelVal) * fuelPricePerUnit)
                return
            end

        elseif state == "up" then
            if fuelIsDragging then
                fuelIsDragging = false
                return
            end
            local layout = fuelWindowLayout
            local winX = layout.panelX
            local btnW = (layout.panelW - (layout.padding*2) - layout.buttonSpacing) / 2
            local btnH = layout.buttonH
            local btnYpos = layout.panelY + layout.panelH - btnH - layout.padding

            local btnRefuelXpos = winX + layout.padding
            local btnCancelXpos = btnRefuelXpos + btnW + layout.buttonSpacing

            if ui_buttonFillMax and absX >= ui_buttonFillMax.x and absX <= ui_buttonFillMax.x + ui_buttonFillMax.w and
               absY >= ui_buttonFillMax.y and absY <= ui_buttonFillMax.y + ui_buttonFillMax.h then
                local currentFuelVal = 0
                if isElement(fuelVehicleRef) then currentFuelVal = getElementData(fuelVehicleRef, "fuel") or 0 end
                fuelAmount = maxFuel
                totalCost = math.floor(math.max(0, fuelAmount - currentFuelVal) * fuelPricePerUnit)
                playSoundFrontEnd(40)
                return
            end

            if absX >= btnRefuelXpos and absX <= btnRefuelXpos + btnW and absY >= btnYpos and absY <= btnYpos + btnH then
                refuelVehicle()
            elseif absX >= btnCancelXpos and absX <= btnCancelXpos + btnW and absY >= btnYpos and absY <= btnYpos + btnH then
                closeFuelWindow()
            end
        end
    end
end


function onShopClick(button, state, absX, absY)
    if button ~= "left" or state ~= "up" then return end
    local arrowY = shopMenuY + (shopMenuHeight - shopArrowSize)/2 + 5
    local arrowLeftX = shopMenuX + 15
    local arrowRightX = shopMenuX + shopMenuWidth - shopArrowSize - 15
    local btnY = shopMenuY + shopMenuHeight - shopButtonHeight - 15
    local btnExitX = shopMenuX + 20
    local btnBuyX = shopMenuX + shopMenuWidth - shopButtonWidth - 20
    if absX >= arrowLeftX and absX <= arrowLeftX + shopArrowSize and absY >= arrowY and absY <= arrowY + shopArrowSize then
        if #shopVehiclesForSale > 0 then
            shopCurrentVehicleIndex = (shopCurrentVehicleIndex - 2 + #shopVehiclesForSale) % #shopVehiclesForSale + 1
            updateCarShopVehicle()
        end
    elseif absX >= arrowRightX and absX <= arrowRightX + shopArrowSize and absY >= arrowY and absY <= arrowY + shopArrowSize then
        if #shopVehiclesForSale > 0 then
            shopCurrentVehicleIndex = shopCurrentVehicleIndex % #shopVehiclesForSale + 1
            updateCarShopVehicle()
        end
    elseif absX >= btnBuyX and absX <= btnBuyX + shopButtonWidth and absY >= btnY and absY <= btnY + shopButtonHeight then
        buyCurrentVehicle()
    elseif absX >= btnExitX and absX <= btnExitX + shopButtonWidth and absY >= btnY and absY <= btnY + shopButtonHeight then
        closeCarShop()
    end
end

function onClientClickSpawn(button, state, absX, absY)
    if button ~= "left" or state ~= "up" then return end
    local listX = spawnWindowX + 15
    local listY = spawnWindowY + 55
    local listW = spawnWindowWidth - 30
    local listH = spawnWindowHeight - 150
    local itemStartY = listY + 5 + 20 + 5
    local itemH = 30
    local itemSpacing = 4
    local btnAreaY = spawnWindowY + spawnWindowHeight - 85
    local btnWidth, btnHeight = (listW - 20) / 2, 45
    local btnSpawnX = listX
    local btnRepairX = listX + btnWidth + 20
    local btnCloseX = spawnWindowX + (spawnWindowWidth - btnWidth) / 2
    local btnCloseY = btnAreaY + btnHeight + 10
    local btnCloseHeight = 35
    if absX >= listX + 2 and absX <= listX + listW - 2 and absY >= itemStartY and absY <= listY + listH then
        for i = 1, #playerVehicles do
            local currentItemY = itemStartY + (i - 1) * (itemH + itemSpacing)
            if absY >= currentItemY and absY <= currentItemY + itemH then
                selectedVehicleIndex = i
                return
            end
        end
    end
    local now = getTickCount()
    if now - spawnLastClickTime < 1000 then return end
    if absX >= btnSpawnX and absX <= btnSpawnX + btnWidth and absY >= btnAreaY and absY <= btnAreaY + btnHeight then
        spawnLastClickTime = now
        spawnSelectedVehicle()
    elseif absX >= btnRepairX and absX <= btnRepairX + btnWidth and absY >= btnAreaY and absY <= btnAreaY + btnHeight then
        spawnLastClickTime = now
        repairSelectedVehicle()
    elseif absX >= btnCloseX and absX <= btnCloseX + btnWidth and absY >= btnCloseY and absY <= btnCloseY + btnCloseHeight then
        spawnLastClickTime = now
        closeSpawnManager()
    end
end

addEventHandler("onClientElementDataChange", root, function(dataName)
    if source == getLocalPlayer() then return end
    local playerVeh = getPedOccupiedVehicle(getLocalPlayer())
    if isElement(playerVeh) and source == playerVeh then
        if dataName == "locked" then
            local lockedState = getElementData(source, "locked")
            outputChatBox("Vehicle lock status changed: " .. (lockedState == 1 and "Locked 🔒" or "Unlocked 🔓"), 150, 150, 255)
        elseif dataName == "engine" then
            local engineState = getElementData(source, "engine")
            outputChatBox("Vehicle engine status changed: " .. (engineState == 1 and "On 🚀" or "Off 🛑"), 150, 150, 255)
        end
    end
end)

function createAndSetupSpawnBlips()
    for _, blip in ipairs(spawnBlips) do
        if isElement(blip) then destroyElement(blip) end
    end
    spawnBlips = {}

    for i, markerData in ipairs(spawnMarkerPositions) do
        local blip = createBlip(markerData.x, markerData.y, markerData.z, 63) -- Blip-ID auf 63 geändert
        if isElement(blip) then
            setBlipVisibleDistance(blip, 100)
            setBlipColor(blip, 0, 150, 255, 200)
            table.insert(spawnBlips, blip)
        end
    end
end


addEventHandler("onClientResourceStart", resourceRoot, function()
    for i, pos in ipairs(carShopMarkerPositions) do
        local blip = createBlip(pos.x, pos.y, pos.z, 55, 2, 0, 255, 0, 255, 0, 99999.0)
        setBlipVisibleDistance(blip, 100)
        table.insert(carShopBlips, blip)
        local marker = createMarker(pos.x, pos.y, pos.z - 1, "cylinder", 2.5, 0, 255, 0, 150)
        if marker then
            table.insert(carShopMarkers, marker)
            addEventHandler("onClientMarkerHit", marker, function(hitElement, matchingDimension)
                if hitElement == getLocalPlayer() and matchingDimension and not isPedInVehicle(hitElement) then
                    openCarShop()
                end
            end)
        end
    end

    for _, pos in ipairs(fuelStations) do
        local marker = createMarker(pos.x, pos.y, pos.z - 1, "cylinder", 4, 255, 165, 0, 150)
        if marker then
            table.insert(fuelMarkers, marker)
            addEventHandler("onClientMarkerHit", marker, function(hitElement, matchingDim)
                if hitElement == getLocalPlayer() then
                    local veh = getPedOccupiedVehicle(getLocalPlayer())
                    if veh and getVehicleController(veh) == getLocalPlayer() then
                        openFuelWindow()
                    else
                        outputChatBox("You must be in the driver's seat of a vehicle to refuel.", 255, 165, 0)
                    end
                end
            end)
        end
    end

    createAndSetupSpawnBlips()

    for i, markerData in ipairs(spawnMarkerPositions) do
        local marker = createMarker(markerData.x, markerData.y, markerData.z -1, "cylinder", 1.5, 0, 150, 255, 150)
        if marker then
            table.insert(spawnPointMarkers, marker)
            addEventHandler("onClientMarkerHit", marker, function(hitElement, matchingDimension)
                 if hitElement == getLocalPlayer() and matchingDimension and not isPedInVehicle(hitElement) then
                    triggerServerEvent("onPlayerRequestVehicleSpawn", getLocalPlayer())
                end
            end)
        end
    end
    --outputDebugString("[vehicles_client.lua] V1.1 (RGB Korrektur) Alle Client-Skripte geladen.")
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    closeFuelWindow()
    closeCarShop()
    closeSpawnManager()

    removeEventHandler("onClientRender", root, renderDXShop)
    removeEventHandler("onClientRender", root, renderDXSpawnManager)
    if fuelWindowVisible then removeEventHandler("onClientRender", root, renderFuelWindow) end

    for _, blip in ipairs(carShopBlips) do if isElement(blip) then destroyElement(blip) end end; carShopBlips = {}
    for _, marker in ipairs(carShopMarkers) do if isElement(marker) then destroyElement(marker) end end; carShopMarkers = {}
    for _, marker in ipairs(fuelMarkers) do if isElement(marker) then destroyElement(marker) end end; fuelMarkers = {}
    for _, blip in ipairs(spawnBlips) do if isElement(blip) then destroyElement(blip) end end; spawnBlips = {}
    for _, marker in ipairs(spawnPointMarkers) do if isElement(marker) then destroyElement(marker) end end; spawnPointMarkers = {}
end)

-- Event-Handler für vehicles:applyRGBColorsToVehicle (von Schritt 6)
addEvent("vehicles:applyRGBColorsToVehicle", true)
addEventHandler("vehicles:applyRGBColorsToVehicle", root, function(targetVehicle, r1,g1,b1, r2,g2,b2, r3,g3,b3, r4,g4,b4)
    if isElement(targetVehicle) then
        -- Stelle sicher, dass alle Farbwerte gültige Zahlen sind (Fallback auf 0, falls nil)
        r1 = tonumber(r1) or 0; g1 = tonumber(g1) or 0; b1 = tonumber(b1) or 0;
        r2 = tonumber(r2) or 0; g2 = tonumber(g2) or 0; b2 = tonumber(b2) or 0;
        r3 = tonumber(r3) or 0; g3 = tonumber(g3) or 0; b3 = tonumber(b3) or 0;
        r4 = tonumber(r4) or 0; g4 = tonumber(g4) or 0; b4 = tonumber(b4) or 0;
        setVehicleColor(targetVehicle, r1,g1,b1, r2,g2,b2, r3,g3,b3, r4,g4,b4)
    end
end)