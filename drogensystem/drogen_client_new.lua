-- drogensystem/drogen_client_new.lua
-- ERWEITERT: DX-Fenster und Logik für Drogenverkauf (basierend auf Juwelier)
-- HINZUGEFÜGT: Cannabis und Kokain Icons im Verkaufs-GUI
-- ERWEITERT FÜR SAMENVERKAUF: Neues GUI für den Kauf von Samen hinzugefügt.
-- MODIFIZIERT V7 (AI): Fügt clientseitigen Timer für Restock-Anzeige hinzu und benachrichtigt Server bei GUI-Schließung.

local localPlayer = getLocalPlayer()
local screenW, screenH = guiGetScreenSize()
local INTERACTION_KEY = "e"
local INTERACTION_DISTANCE = 2.0
local PLANT_OBJECT_MARKER_CLIENT = "drogenSystemPlantObject"

-- =========================================================================
-- ## LAYOUT- & DESIGN-VARIABLEN
-- =========================================================================
local windowDrogenW, windowDrogenH = 640, 560
local windowDrogenX, windowDrogenY = (screenW - windowDrogenW) / 2, (screenH - windowDrogenH) / 2
local listDrogenHeaderYPos = windowDrogenY + 55
local listDrogenItemsOffsetY = 25
local itemsDrogenStartY = listDrogenHeaderYPos + listDrogenItemsOffsetY
local listDrogenOffsetX = 20;
local listDrogenWidth = windowDrogenW - (listDrogenOffsetX * 2)
local listDrogenItemHeight = 48
local itemDrogenSlotSpacing = 3
local buttonDrogenW = 140
local buttonDrogenH = 42
local buttonDrogenBottomMargin = 20 + 2
local buttonDrogenSpacing = 20
local scrollOffsetDrogen = 0
local maxVisibleItemsDrogenList = 1
local currentMengeDrogenCtrlY = 0
local mengeDrogenInputWidth = 70
local mengeDrogenInputHeight = 30
local mengeDrogenArrowBtnW = 34
local mengeDrogenArrowBtnH = mengeDrogenInputHeight
local mengeDrogenLabelToCtrlSpacing = 15

-- =========================================================================
-- ## VARIABLEN FÜR DROGEN-VERKAUFS-GUI
-- =========================================================================
local isDrogenSellGUIVisible = false
_G.isDrugSellGUIVisible = false
local drogenSellableItemsClient = {}
local selectedDrugToSellClient = nil
local quantityToSellDrogenInputClient = "1"
local activeDrogenSellInputElement = nil
local cannabisIconTextureClient = nil
local kokainIconTextureClient = nil
local CANNABIS_ICON_PATH_CLIENT = "images/cannabis_icon.png"
local KOKAIN_ICON_PATH_CLIENT = "images/cocain_icon.png"
local drogenSellGUIElements = {}

-- =========================================================================
-- ## VARIABLEN FÜR SAMEN-KAUF-GUI
-- =========================================================================
local isDrogenBuyGUIVisible = false
_G.isDrugSeedBuyGUIVisible = false
local drogenBuyDataClient = {}
local quantityToBuySamenInputClient = "1"
local activeDrogenBuyInputElement = nil
local drogenBuyGUIElements = {}
local restockTimerDisplay = nil -- NEU: Timer für die Client-Anzeige

-- Design Konstanten...
local guiColors = {
    BG_MAIN = tocolor(28, 30, 36, 245), BG_HEADER = tocolor(40, 100, 40, 235),
    TEXT_HEADER = tocolor(220, 255, 220), TEXT_LIGHT = tocolor(230, 230, 235),
    TEXT_ITEM_NAME = tocolor(180, 255, 180), TEXT_PRICE = tocolor(100, 220, 100),
    TEXT_QUANTITY_VALUE = tocolor(230, 230, 240), TEXT_PRICE_VALUE = tocolor(150, 250, 150),
    TEXT_LABEL = tocolor(190, 190, 200), TEXT_INFO_HEADER = tocolor(215, 215, 225),
    SLOT_BG = tocolor(35, 50, 35, 210), SLOT_HOVER_BG = tocolor(50, 65, 50, 220),
    SLOT_SELECTED_BG = tocolor(0, 140, 0, 190),
    BUTTON_SELL_BG = tocolor(70, 180, 70, 220), BUTTON_SELL_HOVER = tocolor(90, 200, 90, 230),
    BUTTON_CLOSE_BG = tocolor(180, 50, 50, 220), BUTTON_CLOSE_HOVER = tocolor(200, 70, 70, 230),
    BUTTON_TEXT = tocolor(245, 245, 245), INPUT_BG = tocolor(30,60,30,230),
    ARROW_BUTTON_BG = tocolor(60, 100, 60, 225), ARROW_BUTTON_HOVER_BG = tocolor(80, 120, 80, 235)
}
local guiFonts = {
    HEADER = {font = "default-bold", scale = 1.25}, LIST_HEADER = {font = "default", scale = 1},
    ITEM_NAME = {font = "default", scale = 1}, ITEM_DETAILS_QTY = {font = "default", scale = 1},
    ITEM_DETAILS_PRICE = {font = "default", scale = 1}, BUTTON = {font = "default", scale = 1},
    ARROW_BUTTON = {font = "default", scale = 1.3}, INFO_HEADER = {font = "default", scale = 1},
    INFO_TEXT_LABEL = {font = "default", scale = 1}, INFO_TEXT_VALUE = {font = "default", scale = 1},
    INPUT_TEXT = {font = "default", scale = 1}, TOTAL_PRICE_TEXT = {font = "default", scale = 1}
}

-- Globale Variablen für Render-Handler etc.
local isDrogenSellGUIRenderHandlerActive = false
local isDrogenSellGUIInputHandlersActive = false
local isDrogenBuyGUIRenderHandlerActive = false
local isDrogenBuyGUIInputHandlersActive = false

-- Bestehende Funktionen für Erntehinweis und Erntelogik... (unverändert)
local function renderPlantInteractionText()
    if isChatBoxInputActive() or isConsoleActive() or isMainMenuActive() then return end
    if getPedOccupiedVehicle(localPlayer) then return end
    local playerX, playerY, playerZ = getElementPosition(localPlayer)
    local closestPlantObject = nil; local closestDistance = INTERACTION_DISTANCE + 0.1
    for _, objectElement in ipairs(getElementsByType("object", getResourceRootElement(getThisResource()))) do
        if isElement(objectElement) and getElementData(objectElement, PLANT_OBJECT_MARKER_CLIENT) then
            if getElementData(objectElement, "drogenPlantReif") == true then
                local objX, objY, objZ = getElementPosition(objectElement)
                local distance = getDistanceBetweenPoints3D(playerX, playerY, playerZ, objX, objY, objZ)
                if distance < closestDistance then closestDistance = distance; closestPlantObject = objectElement; end
            end
        end
    end
    if closestPlantObject and closestDistance <= INTERACTION_DISTANCE then
        local pX, pY, pZ = getElementPosition(closestPlantObject); local scaleZ = getObjectScale(closestPlantObject)
        local textWorldZ = pZ + (1.0 * (scaleZ or 1.0)) * 0.7
        local screenX, screenY = getScreenFromWorldPosition(pX, pY, textWorldZ)
        if screenX and screenY then
            local text = "Drücke [" .. string.upper(INTERACTION_KEY) .. "] zum Ernten"
            dxDrawText(text, screenX + 1, screenY + 1, screenX + 1, screenY + 1, tocolor(0,0,0,180), 1.0, "default-bold", "center", "center", false,false,false,true)
            dxDrawText(text, screenX, screenY, screenX, screenY, tocolor(255,255,255,220), 1.0, "default-bold", "center", "center", false,false,false,true)
        end
    end
end
addEventHandler("onClientRender", root, renderPlantInteractionText)

local function onPlayerPressHarvestKey(key, press)
    if not press or key ~= INTERACTION_KEY then return end
    if isChatBoxInputActive() or isConsoleActive() or isMainMenuActive() or getPedOccupiedVehicle(localPlayer) then return end
    local playerX, playerY, playerZ = getElementPosition(localPlayer)
    local plantToHarvestUID = nil; local closestHarvestDist = INTERACTION_DISTANCE + 0.1
    for _, objectElement in ipairs(getElementsByType("object", getResourceRootElement(getThisResource()))) do
        if isElement(objectElement) then
            local plantUID = getElementData(objectElement, PLANT_OBJECT_MARKER_CLIENT)
            if plantUID and getElementData(objectElement, "drogenPlantReif") == true then
                local objX, objY, objZ = getElementPosition(objectElement)
                local distance = getDistanceBetweenPoints3D(playerX, playerY, playerZ, objX, objY, objZ)
                if distance < closestHarvestDist then closestHarvestDist = distance; plantToHarvestUID = plantUID; end
            end
        end
    end
    if plantToHarvestUID and closestHarvestDist <= INTERACTION_DISTANCE then
        triggerServerEvent("drogensystem:harvestPlant", localPlayer, plantToHarvestUID)
    end
end
addEventHandler("onClientKey", root, onPlayerPressHarvestKey)

-- ##########################################################################
-- ## FUNKTIONEN FÜR SAMEN-KAUF-GUI
-- ##########################################################################

local function formatMillisecondsToMMSS(ms)
    if not ms or ms < 0 then return "00:00" end
    local totalSeconds = math.floor(ms / 1000)
    local minutes = math.floor(totalSeconds / 60)
    local seconds = totalSeconds % 60
    return string.format("%02d:%02d", minutes, seconds)
end

local function formatMoneyClient(amount)
    local formatted = string.format("%.0f", amount or 0)
    local k repeat formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1.%2") until k == 0
    return "$" .. formatted
end

local function calculateTotalSamenBuyPrice()
    if drogenBuyDataClient and drogenBuyDataClient.itemPrice then
        local qty = tonumber(quantityToBuySamenInputClient) or 0
        local maxQty = drogenBuyDataClient.stock or 0
        qty = math.max(0, math.min(qty, maxQty))
        return (drogenBuyDataClient.itemPrice or 0) * qty
    end
    return 0
end

function renderDrogenBuyGUI()
    if not isDrogenBuyGUIVisible then return end
    drogenBuyGUIElements = {}
    local buyWindowW, buyWindowH = 480, 280
    local buyWindowX, buyWindowY = (screenW - buyWindowW) / 2, (screenH - buyWindowH) / 2
    local mX_rel, mY_rel = getCursorPosition()
    local mX_abs, mY_abs; if mX_rel then mX_abs = mX_rel * screenW; mY_abs = mY_rel * screenH end
    local buttonW_buy, buttonH_buy, buttonSpacing_buy = 150, 40, 15
    local closeButtonX_buy = buyWindowX + buyWindowW - buttonW_buy - 20
    local buttonY_buy = buyWindowY + buyWindowH - buttonH_buy - 20

    dxDrawRectangle(buyWindowX, buyWindowY, buyWindowW, buyWindowH, guiColors.BG_MAIN)
    dxDrawRectangle(buyWindowX, buyWindowY, buyWindowW, 40, guiColors.BG_HEADER)
    dxDrawText("Samenhändler", buyWindowX, buyWindowY, buyWindowX + buyWindowW, buyWindowY + 40, guiColors.TEXT_HEADER, guiFonts.HEADER.scale, guiFonts.HEADER.font, "center", "center")

    if not drogenBuyDataClient.hasStock then
        local remainingMs = (drogenBuyDataClient.restockTimeRemaining or 0)
        local timeStr = formatMillisecondsToMMSS(remainingMs)
        local msg = "Neue Ware in: " .. timeStr
        dxDrawText(msg, buyWindowX, buyWindowY, buyWindowX + buyWindowW, buyWindowY + buyWindowH - 50, guiColors.TEXT_LIGHT, 1.2, "default-bold", "center", "center")
    else
        local item = drogenBuyDataClient
        local contentStartX = buyWindowX + 20
        local contentStartY = buyWindowY + 60
        local lineHeight = 28
        
        dxDrawText("Im Angebot:", contentStartX, contentStartY, 0, 0, guiColors.TEXT_LABEL, 1.0, "default-bold")
        dxDrawText(item.itemName, contentStartX + 120, contentStartY, 0, 0, guiColors.TEXT_ITEM_NAME, 1.1, "default-bold")
        contentStartY = contentStartY + lineHeight

        dxDrawText("Preis pro Stück:", contentStartX, contentStartY, 0, 0, guiColors.TEXT_LABEL, 1.0, "default-bold")
        dxDrawText("$" .. (item.itemPrice or "?"), contentStartX + 120, contentStartY, 0, 0, guiColors.TEXT_PRICE, 1.1, "default-bold")
        contentStartY = contentStartY + lineHeight
        
        dxDrawText("Auf Lager:", contentStartX, contentStartY, 0, 0, guiColors.TEXT_LABEL, 1.0, "default-bold")
        dxDrawText(item.stock or "0", contentStartX + 120, contentStartY, 0, 0, guiColors.TEXT_QUANTITY_VALUE, 1.1, "default-bold")
        contentStartY = contentStartY + lineHeight + 15
        
        local mengeCtrlY = contentStartY
        local mengeLabel = "Anzahl (Max: " .. (item.stock or 0) .. "):"
        local fontHAnzahlLabel = dxGetFontHeight(1.0, "default")
        local mengeLabelY = mengeCtrlY + (mengeDrogenInputHeight - fontHAnzahlLabel) / 2
        dxDrawText(mengeLabel, contentStartX, mengeLabelY, 0,0, guiColors.TEXT_LABEL, 1.0, "default")

        local mengeCtrlSX = contentStartX + dxGetTextWidth(mengeLabel, 1.0, "default") + 15
        local minusBtnX = mengeCtrlSX
        local minusBtnHover = mX_abs and mY_abs and mX_abs >= minusBtnX and mX_abs <= minusBtnX + mengeDrogenArrowBtnW and mY_abs >= mengeCtrlY and mY_abs <= mengeCtrlY + mengeDrogenArrowBtnH
        dxDrawRectangle(minusBtnX, mengeCtrlY, mengeDrogenArrowBtnW, mengeDrogenArrowBtnH, minusBtnHover and guiColors.ARROW_BUTTON_HOVER_BG or guiColors.ARROW_BUTTON_BG)
        dxDrawText("<", minusBtnX, mengeCtrlY, minusBtnX + mengeDrogenArrowBtnW, mengeCtrlY + mengeDrogenArrowBtnH, guiColors.BUTTON_TEXT, 1.3, "default-bold", "center", "center")
        drogenBuyGUIElements.minus = {x=minusBtnX, y=mengeCtrlY, w=mengeDrogenArrowBtnW, h=mengeDrogenArrowBtnH}

        local mengeDispX = minusBtnX + mengeDrogenArrowBtnW + 5
        dxDrawRectangle(mengeDispX, mengeCtrlY, mengeDrogenInputWidth, mengeDrogenInputHeight, guiColors.INPUT_BG)
        dxDrawText(quantityToBuySamenInputClient .. (activeDrogenBuyInputElement == "quantity" and "_" or ""), mengeDispX + 5, mengeCtrlY, mengeDispX + mengeDrogenInputWidth, mengeCtrlY + mengeDrogenInputHeight, guiColors.TEXT_LIGHT, 1.0, "default", "left", "center")
        drogenBuyGUIElements.input = {x=mengeDispX, y=mengeCtrlY, w=mengeDrogenInputWidth, h=mengeDrogenInputHeight}

        local plusBtnX = mengeDispX + mengeDrogenInputWidth + 5
        local plusBtnHover = mX_abs and mY_abs and mX_abs >= plusBtnX and mX_abs <= plusBtnX + mengeDrogenArrowBtnW and mY_abs >= mengeCtrlY and mY_abs <= mengeCtrlY + mengeDrogenArrowBtnH
        dxDrawRectangle(plusBtnX, mengeCtrlY, mengeDrogenArrowBtnW, mengeDrogenArrowBtnH, plusBtnHover and guiColors.ARROW_BUTTON_HOVER_BG or guiColors.ARROW_BUTTON_BG)
        dxDrawText(">", plusBtnX, mengeCtrlY, plusBtnX + mengeDrogenArrowBtnW, mengeCtrlY + mengeDrogenArrowBtnH, guiColors.BUTTON_TEXT, 1.3, "default-bold", "center", "center")
        drogenBuyGUIElements.plus = {x=plusBtnX, y=mengeCtrlY, w=mengeDrogenArrowBtnW, h=mengeDrogenArrowBtnH}
        
        contentStartY = contentStartY + mengeDrogenInputHeight + 15
        
        dxDrawText("Gesamtkosten:", contentStartX, contentStartY, 0, 0, guiColors.TEXT_INFO_HEADER, 1.1, "default-bold")
        dxDrawText("$" .. formatMoneyClient(calculateTotalSamenBuyPrice()), contentStartX + 150, contentStartY, 0, 0, guiColors.TEXT_PRICE, 1.2, "default-bold")

        local buyButtonX_buy = closeButtonX_buy - buttonW_buy - buttonSpacing_buy
        local canBuy = (tonumber(quantityToBuySamenInputClient) or 0) > 0 and (tonumber(quantityToBuySamenInputClient) or 0) <= (item.stock or 0)
        local buyBtnColor = canBuy and guiColors.BUTTON_SELL_BG or tocolor(80,80,80,200)
        local buyBtnHoverColor = canBuy and guiColors.BUTTON_SELL_HOVER or buyBtnColor
        dxDrawRectangle(buyButtonX_buy, buttonY_buy, buttonW_buy, buttonH_buy, buyBtnColor); if canBuy and mX_abs and mX_abs >= buyButtonX_buy and mX_abs <= buyButtonX_buy+buttonW_buy and mY_abs >= buttonY_buy and mY_abs <= buttonY_buy+buttonH_buy then dxDrawRectangle(buyButtonX_buy, buttonY_buy, buttonW_buy, buttonH_buy, buyBtnHoverColor) end
        dxDrawText("Kaufen", buyButtonX_buy, buttonY_buy, buyButtonX_buy+buttonW_buy, buttonY_buy+buttonH_buy, guiColors.BUTTON_TEXT, 1.1, "default-bold", "center", "center")
        drogenBuyGUIElements.buy = {x=buyButtonX_buy, y=buttonY_buy, w=buttonW_buy, h=buttonH_buy, enabled=canBuy}
    end

    local closeBtnHover = mX_abs and mX_abs >= closeButtonX_buy and mX_abs <= closeButtonX_buy+buttonW_buy and mY_abs >= buttonY_buy and mY_abs <= buttonY_buy+buttonH_buy
    dxDrawRectangle(closeButtonX_buy, buttonY_buy, buttonW_buy, buttonH_buy, closeBtnHover and guiColors.BUTTON_CLOSE_HOVER or guiColors.BUTTON_CLOSE_BG)
    dxDrawText("Schließen", closeButtonX_buy, buttonY_buy, closeButtonX_buy+buttonW_buy, buttonY_buy+buttonH_buy, guiColors.BUTTON_TEXT, 1.1, "default-bold", "center", "center")
    drogenBuyGUIElements.close = {x=closeButtonX_buy, y=buttonY_buy, w=buttonW_buy, h=buttonH_buy}
end

-- Die restlichen Funktionen `openDrogenBuyGUI`, `closeDrogenBuyGUI`, `handleDrogenBuyGUIClick`, `handleDrogenBuyGUIKey`, `handleDrogenBuyGUIChar`,
-- sowie alle Funktionen für den Drogenverkauf bleiben wie in der vorherigen Antwort, da sie bereits die korrigierte Logik verwenden.
-- (Der Code ist hier aus Platzgründen nicht wiederholt, aber der korrigierte Code aus meiner vorherigen Antwort sollte hier eingefügt werden)

-- ##########################################################################
-- ## DIE FOLGENDEN FUNKTIONEN BLEIBEN WIE IN IHRER LETZTEN KORRIGIERTEN VERSION
-- ##########################################################################

-- ERSETZE die alte Funktion 'openDrogenBuyGUI' mit dieser
function openDrogenBuyGUI(data)
    -- ALT (so ähnlich war es vorher):
    -- if isDrogenBuyGUIVisible and drogenBuyDataClient.hasStock == data.hasStock then return end

    -- NEU: Wir entfernen die 'return' Bedingung und aktualisieren stattdessen die Daten.
    -- Das verhindert das Flackern, aber erlaubt eine Live-Aktualisierung.
    local wasAlreadyVisible = isDrogenBuyGUIVisible

    _G.isDrugSeedBuyGUIVisible = true
    isDrogenBuyGUIVisible = true
    drogenBuyDataClient = data or {}
    
    -- Countdown Timer für Anzeige
    if isTimer(restockTimerDisplay) then killTimer(restockTimerDisplay); restockTimerDisplay = nil; end
    if data and data.hasStock == false then
        restockTimerDisplay = setTimer(function()
            if drogenBuyDataClient and not drogenBuyDataClient.hasStock then
                drogenBuyDataClient.restockTimeRemaining = math.max(0, (drogenBuyDataClient.restockTimeRemaining or 0) - 1000)
            else
                killTimer(restockTimerDisplay); restockTimerDisplay = nil
            end
        end, 1000, 0)
    else
        -- Wenn Ware wieder da ist oder initial da ist, die Menge zurücksetzen.
        quantityToBuySamenInputClient = "1"
    end
    
    if wasAlreadyVisible then
        -- Wenn das Fenster schon offen war, muss nichts weiter getan werden.
        -- Der Render-Handler zeichnet automatisch die neuen Daten.
        return
    end

    -- Nur beim ALLERERSTEN Öffnen die Handler und den Cursor setzen.
    activeDrogenBuyInputElement = nil
    
    if not isDrogenBuyGUIRenderHandlerActive then
        showCursor(true)
        guiSetInputMode("no_binds_when_editing")
        addEventHandler("onClientRender", root, renderDrogenBuyGUI); isDrogenBuyGUIRenderHandlerActive = true
        addEventHandler("onClientClick", root, handleDrogenBuyGUIClick); addEventHandler("onClientKey", root, handleDrogenBuyGUIKey); addEventHandler("onClientCharacter", root, handleDrogenBuyGUIChar); isDrogenBuyGUIInputHandlersActive = true
    end
end
addEvent("drogensystem:openSeedBuyGUI", true)
addEventHandler("drogensystem:openSeedBuyGUI", root, openDrogenBuyGUI)


function closeDrogenBuyGUI()
    if not isDrogenBuyGUIVisible then return end
    _G.isDrugSeedBuyGUIVisible = false
    isDrogenBuyGUIVisible = false
    drogenBuyDataClient = {}
    activeDrogenBuyInputElement = nil
    if isTimer(restockTimerDisplay) then killTimer(restockTimerDisplay); restockTimerDisplay=nil; end
    
    if isDrogenBuyGUIRenderHandlerActive then removeEventHandler("onClientRender", root, renderDrogenBuyGUI); isDrogenBuyGUIRenderHandlerActive = false end
    if isDrogenBuyGUIInputHandlersActive then removeEventHandler("onClientClick", root, handleDrogenBuyGUIClick); removeEventHandler("onClientKey", root, handleDrogenBuyGUIKey); removeEventHandler("onClientCharacter", root, handleDrogenBuyGUIChar); isDrogenBuyGUIInputHandlersActive = false end
    
    if not (_G.isInventoryVisible or _G.isHandyGUIVisible or _G.isPedGuiOpen or _G.isDrugSellGUIVisible) then
        showCursor(false)
        guiSetInputMode("allow_binds")
    end
    
    triggerServerEvent("drogensystem:clientClosedBuyGUI", localPlayer) -- NEU: Server benachrichtigen
end  

function handleDrogenBuyGUIClick(button, state, absX, absY)
    if not isDrogenBuyGUIVisible or button ~= "left" or state ~= "up" then return end
    
    local function isCursorOver(el)
        if not el then return false end
        return absX >= el.x and absX <= el.x + el.w and absY >= el.y and absY <= el.y + el.h
    end

    if isCursorOver(drogenBuyGUIElements.close) then
        closeDrogenBuyGUI()
        return
    end

    if not drogenBuyDataClient.hasStock then return end -- Wenn keine Ware, nur schließen erlauben

    local item = drogenBuyDataClient

    if isCursorOver(drogenBuyGUIElements.minus) then
        local cq = tonumber(quantityToBuySamenInputClient) or 1
        quantityToBuySamenInputClient = tostring(math.max(1, cq - 1))
        return
    end

    if isCursorOver(drogenBuyGUIElements.plus) then
        local cq = tonumber(quantityToBuySamenInputClient) or 0
        quantityToBuySamenInputClient = tostring(math.min(item.stock, cq + 1))
        return
    end

    if isCursorOver(drogenBuyGUIElements.input) then
        activeDrogenBuyInputElement = "quantity"
        return
    end

    if isCursorOver(drogenBuyGUIElements.buy) and drogenBuyGUIElements.buy.enabled then
        local qtyToBuy = tonumber(quantityToBuySamenInputClient) or 0
        if qtyToBuy > 0 and qtyToBuy <= item.stock then
            triggerServerEvent("drogensystem:buySeeds", localPlayer, item.ped, item.itemID, qtyToBuy)
        else
            outputChatBox("Ungültige Menge.", 255, 100, 0)
        end
        return
    end
    
    activeDrogenBuyInputElement = nil
end


function handleDrogenBuyGUIKey(key, press)
    if not isDrogenBuyGUIVisible or not press then return end
    if key == "escape" then closeDrogenBuyGUI(); cancelEvent() end
    if activeDrogenBuyInputElement == "quantity" then
        if key == "backspace" then quantityToBuySamenInputClient = string.sub(quantityToBuySamenInputClient, 1, -2); if quantityToBuySamenInputClient=="" then quantityToBuySamenInputClient="0" end
        elseif key == "enter" then activeDrogenBuyInputElement = nil; end
    end
end

function handleDrogenBuyGUIChar(char)
    if not isDrogenBuyGUIVisible or activeDrogenBuyInputElement ~= "quantity" then return end
    if tonumber(char) then local nqs = quantityToBuySamenInputClient; if quantityToBuySamenInputClient=="0" and char~="0" then nqs="" end; nqs=nqs..char
        if string.len(nqs) <= 7 then local numVal=tonumber(nqs); if numVal then local maxQty=drogenBuyDataClient.stock or 0; if numVal > maxQty then quantityToBuySamenInputClient=tostring(maxQty) else quantityToBuySamenInputClient=nqs end else quantityToBuySamenInputClient="0" end end
    end
end
-- ... (Der Rest des Codes für den Verkauf und ResourceStart/Stop bleibt wie in der vorherigen korrigierten Version)
-- ... [Hier den Code für die Verkaufs-GUI, Scrollen, etc. einfügen] ...
-- ##########################################################################
-- ## BESTEHENDE FUNKTIONEN FÜR DROGEN-VERKAUF-GUI (Mit Klick-Fix)
-- ##########################################################################
addEvent("drogensystem:openSellGUI", true)
addEventHandler("drogensystem:openSellGUI", root, function(items)
    openDrogenSellGUI(items)
end)

function calculateTotalDrogenSellPrice()
    if selectedDrugToSellClient and drogenSellableItemsClient[selectedDrugToSellClient] then
        local item = drogenSellableItemsClient[selectedDrugToSellClient]
        local qty = tonumber(quantityToSellDrogenInputClient) or 0
        qty = math.max(0, math.min(qty, item.quantity))
        return (item.sell_price_each or 0) * qty
    end
    return 0
end

function renderDrogenSellGUI()
    if not isDrogenSellGUIVisible then return end
    drogenSellGUIElements = {} 

    dxDrawRectangle(windowDrogenX, windowDrogenY, windowDrogenW, windowDrogenH, guiColors.BG_MAIN)
    dxDrawRectangle(windowDrogenX, windowDrogenY, windowDrogenW, 40, guiColors.BG_HEADER)
    dxDrawText("Drogen Verkauf", windowDrogenX, windowDrogenY, windowDrogenX + windowDrogenW, windowDrogenY + 40, guiColors.TEXT_HEADER, guiFonts.HEADER.scale, guiFonts.HEADER.font, "center", "center")

    local mX_rel, mY_rel = getCursorPosition()
    local mX_abs, mY_abs; if mX_rel then mX_abs = mX_rel * screenW; mY_abs = mY_rel * screenH end

    local colIconWidthSpace = 50
    local colNameX = windowDrogenX + listDrogenOffsetX + 5
    local colQtyX = colNameX + 290
    local colPriceEachX = colQtyX + 90

    dxDrawText("Item", colNameX + colIconWidthSpace/2 - 10, listDrogenHeaderYPos, 0,0, guiColors.TEXT_LABEL, guiFonts.LIST_HEADER.scale, guiFonts.LIST_HEADER.font, "left")
    dxDrawText("Menge", colQtyX, listDrogenHeaderYPos, 0,0, guiColors.TEXT_LABEL, guiFonts.LIST_HEADER.scale, guiFonts.LIST_HEADER.font, "left")
    dxDrawText("Preis/Stk.", colPriceEachX, listDrogenHeaderYPos,0,0, guiColors.TEXT_LABEL, guiFonts.LIST_HEADER.scale, guiFonts.LIST_HEADER.font, "left")

    local sellSectionHeightEstimate = 145
    local listRenderAreaStartY = itemsDrogenStartY
    local listRenderAreaEndY = windowDrogenY + windowDrogenH - buttonDrogenBottomMargin - buttonDrogenH - 15 - sellSectionHeightEstimate
    local listAvailableRenderHeight = listRenderAreaEndY - listRenderAreaStartY

    if listAvailableRenderHeight > 0 then maxVisibleItemsDrogenList = math.max(1, math.floor(listAvailableRenderHeight / listDrogenItemHeight)) else maxVisibleItemsDrogenList = 1 end

    if #drogenSellableItemsClient == 0 then dxDrawText("Du besitzt keine verkaufbaren Drogen.", windowDrogenX + listDrogenOffsetX, itemsDrogenStartY + 50, windowDrogenX + listDrogenOffsetX + listDrogenWidth, itemsDrogenStartY + 150, guiColors.TEXT_LIGHT, 1.1, "default-bold", "center", "center", true)
    else
        drogenSellGUIElements.items = {}
        for i = 1, maxVisibleItemsDrogenList do local index = i + scrollOffsetDrogen
            if drogenSellableItemsClient[index] then local item = drogenSellableItemsClient[index]; local itemRowY = itemsDrogenStartY + (i-1) * listDrogenItemHeight; local bgColor = guiColors.SLOT_BG
                if mX_abs and mY_abs and mX_abs >= windowDrogenX+listDrogenOffsetX and mX_abs <= windowDrogenX+listDrogenOffsetX+listDrogenWidth and mY_abs >= itemRowY and mY_abs <= itemRowY+listDrogenItemHeight-itemDrogenSlotSpacing then bgColor = guiColors.SLOT_HOVER_BG end
                if selectedDrugToSellClient == index then bgColor = guiColors.SLOT_SELECTED_BG end
                dxDrawRectangle(windowDrogenX+listDrogenOffsetX, itemRowY, listDrogenWidth, listDrogenItemHeight-itemDrogenSlotSpacing, bgColor)
                drogenSellGUIElements.items[index] = {x=windowDrogenX+listDrogenOffsetX, y=itemRowY, w=listDrogenWidth, h=listDrogenItemHeight-itemDrogenSlotSpacing}
                
                local iconS = 40; local textIconOffY = (listDrogenItemHeight - itemDrogenSlotSpacing - iconS) / 2; local iconDrawPosX = windowDrogenX + listDrogenOffsetX + 8; local textAfterIconPosX = iconDrawPosX + iconS + 10
                local drawnSpecificIcon = false
                if item.name then local itemNameLower = string.lower(item.name); if string.find(itemNameLower, "cannabis") and cannabisIconTextureClient then dxDrawImage(iconDrawPosX, itemRowY + textIconOffY, iconS, iconS, cannabisIconTextureClient); drawnSpecificIcon = true elseif string.find(itemNameLower, "cocain") and kokainIconTextureClient then dxDrawImage(iconDrawPosX, itemRowY + textIconOffY, iconS, iconS, kokainIconTextureClient); drawnSpecificIcon = true end end
                if not drawnSpecificIcon and item.imagePath and fileExists(item.imagePath) then dxDrawImage(iconDrawPosX, itemRowY + textIconOffY, iconS, iconS, item.imagePath) end
                
                dxDrawText(item.name or "Unbekannt", textAfterIconPosX, itemRowY, colQtyX - 10, itemRowY + listDrogenItemHeight - itemDrogenSlotSpacing, guiColors.TEXT_ITEM_NAME, guiFonts.ITEM_NAME.scale, guiFonts.ITEM_NAME.font, "left", "center", true)
                dxDrawText(tostring(item.quantity or 0),colQtyX+5,itemRowY,colPriceEachX-10 ,itemRowY+listDrogenItemHeight-itemDrogenSlotSpacing,guiColors.TEXT_QUANTITY_VALUE,guiFonts.ITEM_DETAILS_QTY.scale,guiFonts.ITEM_DETAILS_QTY.font,"left","center")
                dxDrawText("$"..string.format("%.0f",item.sell_price_each or 0),colPriceEachX+5,itemRowY,windowDrogenX+listDrogenOffsetX+listDrogenWidth-10,itemRowY+listDrogenItemHeight-itemDrogenSlotSpacing,guiColors.TEXT_PRICE_VALUE,guiFonts.ITEM_DETAILS_PRICE.scale,guiFonts.ITEM_DETAILS_PRICE.font,"left","center")
            end
        end
    end
    local sellSectionCX = windowDrogenX + listDrogenOffsetX + 15; local sellSectionRY = listRenderAreaEndY + 20; local lineHInSell = guiFonts.INFO_HEADER.scale * 12 * guiFonts.INFO_HEADER.scale + 12
    if selectedDrugToSellClient and drogenSellableItemsClient[selectedDrugToSellClient] then local item = drogenSellableItemsClient[selectedDrugToSellClient]
        dxDrawText("Verkaufe:",sellSectionCX,sellSectionRY,0,0,guiColors.TEXT_INFO_HEADER,guiFonts.INFO_HEADER.scale,guiFonts.INFO_HEADER.font,"left","top")
        dxDrawText(item.name or "Unbekannt",sellSectionCX+dxGetTextWidth("Verkaufe: ",guiFonts.INFO_HEADER.scale,guiFonts.INFO_HEADER.font)+5,sellSectionRY,0,0,guiColors.TEXT_ITEM_NAME,guiFonts.INFO_TEXT_VALUE.scale,guiFonts.INFO_TEXT_VALUE.font,"left","top")
        sellSectionRY=sellSectionRY+lineHInSell; currentMengeDrogenCtrlY=sellSectionRY+2; local mengeLabel="Anzahl (Max: "..item.quantity.."):"; local fontHAnzahlLabel=dxGetFontHeight(guiFonts.INFO_TEXT_LABEL.scale,guiFonts.INFO_TEXT_LABEL.font); local mengeLabelY=currentMengeDrogenCtrlY+(mengeDrogenInputHeight-fontHAnzahlLabel)/2
        dxDrawText(mengeLabel,sellSectionCX,mengeLabelY,0,0,guiColors.TEXT_LABEL,guiFonts.INFO_TEXT_LABEL.scale,guiFonts.INFO_TEXT_LABEL.font,"left","top")
        local mengeCtrlSX=sellSectionCX+dxGetTextWidth(mengeLabel,guiFonts.INFO_TEXT_LABEL.scale,guiFonts.INFO_TEXT_LABEL.font)+mengeDrogenLabelToCtrlSpacing
        local minusBtnX=mengeCtrlSX; local minusBtnHover=mX_abs and mY_abs and mX_abs>=minusBtnX and mX_abs<=minusBtnX+mengeDrogenArrowBtnW and mY_abs>=currentMengeDrogenCtrlY and mY_abs<=currentMengeDrogenCtrlY+mengeDrogenArrowBtnH
        dxDrawRectangle(minusBtnX,currentMengeDrogenCtrlY,mengeDrogenArrowBtnW,mengeDrogenArrowBtnH,minusBtnHover and guiColors.ARROW_BUTTON_HOVER_BG or guiColors.ARROW_BUTTON_BG); dxDrawText("<",minusBtnX,currentMengeDrogenCtrlY,minusBtnX+mengeDrogenArrowBtnW,currentMengeDrogenCtrlY+mengeDrogenArrowBtnH,guiColors.BUTTON_TEXT,guiFonts.ARROW_BUTTON.scale,guiFonts.ARROW_BUTTON.font,"center","center")
        drogenSellGUIElements.minus = {x=minusBtnX, y=currentMengeDrogenCtrlY, w=mengeDrogenArrowBtnW, h=mengeDrogenArrowBtnH}
        local mengeDispX=minusBtnX+mengeDrogenArrowBtnW+5; dxDrawRectangle(mengeDispX,currentMengeDrogenCtrlY,mengeDrogenInputWidth,mengeDrogenInputHeight,guiColors.INPUT_BG); dxDrawText(quantityToSellDrogenInputClient..(activeDrogenSellInputElement=="quantity"and"_"or""),mengeDispX+5,currentMengeDrogenCtrlY,mengeDispX+mengeDrogenInputWidth,currentMengeDrogenCtrlY+mengeDrogenInputHeight,guiColors.TEXT_LIGHT,guiFonts.INPUT_TEXT.scale,guiFonts.INPUT_TEXT.font,"left","center")
        drogenSellGUIElements.input = {x=mengeDispX, y=currentMengeDrogenCtrlY, w=mengeDrogenInputWidth, h=mengeDrogenInputHeight}
        local plusBtnX=mengeDispX+mengeDrogenInputWidth+5; local plusBtnHover=mX_abs and mY_abs and mX_abs>=plusBtnX and mX_abs<=plusBtnX+mengeDrogenArrowBtnW and mY_abs>=currentMengeDrogenCtrlY and mY_abs<=currentMengeDrogenCtrlY+mengeDrogenArrowBtnH
        dxDrawRectangle(plusBtnX,currentMengeDrogenCtrlY,mengeDrogenArrowBtnW,mengeDrogenArrowBtnH,plusBtnHover and guiColors.ARROW_BUTTON_HOVER_BG or guiColors.ARROW_BUTTON_BG); dxDrawText(">",plusBtnX,currentMengeDrogenCtrlY,plusBtnX+mengeDrogenArrowBtnW,currentMengeDrogenCtrlY+mengeDrogenArrowBtnH,guiColors.BUTTON_TEXT,guiFonts.ARROW_BUTTON.scale,guiFonts.ARROW_BUTTON.font,"center","center")
        drogenSellGUIElements.plus = {x=plusBtnX, y=currentMengeDrogenCtrlY, w=mengeDrogenArrowBtnW, h=mengeDrogenArrowBtnH}
        sellSectionRY=sellSectionRY+mengeDrogenInputHeight+15
        dxDrawText("Voraussichtlicher Erlös:",sellSectionCX,sellSectionRY,0,0,guiColors.TEXT_INFO_HEADER,guiFonts.INFO_HEADER.scale,guiFonts.INFO_HEADER.font,"left","top"); dxDrawText("$"..string.format("%.0f",calculateTotalDrogenSellPrice()),sellSectionCX+dxGetTextWidth("Voraussichtlicher Erlös: ",guiFonts.INFO_HEADER.scale,guiFonts.INFO_HEADER.font)+10,sellSectionRY,0,0,guiColors.TEXT_PRICE,guiFonts.TOTAL_PRICE_TEXT.scale,guiFonts.TOTAL_PRICE_TEXT.font,"left","top")
    else dxDrawText("Wähle eine Droge aus der Liste oben, um sie zu verkaufen.",sellSectionCX,sellSectionRY,sellSectionCX+listDrogenWidth-30,sellSectionRY+40,guiColors.TEXT_LABEL,1.0,"default-bold","center","center",true) end
    local closeBtnX=windowDrogenX+windowDrogenW-buttonDrogenW-20;local sellAndCloseBtnY=windowDrogenY+windowDrogenH-buttonDrogenH-buttonDrogenBottomMargin;local sellBtnX=closeBtnX-buttonDrogenW-buttonDrogenSpacing
    dxDrawRectangle(closeBtnX,sellAndCloseBtnY,buttonDrogenW,buttonDrogenH,guiColors.BUTTON_CLOSE_BG); dxDrawText("Schließen",closeBtnX,sellAndCloseBtnY,closeBtnX+buttonDrogenW,sellAndCloseBtnY+buttonDrogenH,guiColors.BUTTON_TEXT,guiFonts.BUTTON.scale,guiFonts.BUTTON.font,"center","center")
    drogenSellGUIElements.close = {x=closeBtnX, y=sellAndCloseBtnY, w=buttonDrogenW, h=buttonDrogenH}
    if selectedDrugToSellClient then dxDrawRectangle(sellBtnX,sellAndCloseBtnY,buttonDrogenW,buttonDrogenH,guiColors.BUTTON_SELL_BG); dxDrawText("Verkaufen",sellBtnX,sellAndCloseBtnY,sellBtnX+buttonDrogenW,sellAndCloseBtnY+buttonDrogenH,guiColors.BUTTON_TEXT,guiFonts.BUTTON.scale,guiFonts.BUTTON.font,"center","center"); drogenSellGUIElements.sell = {x=sellBtnX, y=sellAndCloseBtnY, w=buttonDrogenW, h=buttonDrogenH} end
end

function openDrogenSellGUI(items)
    local firstOpen = not isDrogenSellGUIVisible; isDrogenSellGUIVisible = true; _G.isDrugSellGUIVisible = true; drogenSellableItemsClient = items or {}; table.sort(drogenSellableItemsClient, function(a,b) return (a.name or "") < (b.name or "") end)
    if firstOpen then selectedDrugToSellClient=nil; quantityToSellDrogenInputClient="1"; scrollOffsetDrogen=0; activeDrogenSellInputElement=nil
    else
        local currentSelectedActualSlot=nil; if selectedDrugToSellClient and drogenSellableItemsClient[selectedDrugToSellClient] then currentSelectedActualSlot=drogenSellableItemsClient[selectedDrugToSellClient].slot; else selectedDrugToSellClient = nil; end
        local oldSelectedIdx=selectedDrugToSellClient; selectedDrugToSellClient=nil; if currentSelectedActualSlot then local newQty=0; local foundNewIndex=false; for i,itemEntry in ipairs(drogenSellableItemsClient) do if itemEntry.slot==currentSelectedActualSlot then if itemEntry.quantity>0 then selectedDrugToSellClient=i; newQty=itemEntry.quantity; foundNewIndex=true; end; break end end
            if selectedDrugToSellClient then local currentInputQty=tonumber(quantityToSellDrogenInputClient)or 1; if currentInputQty > newQty then quantityToSellDrogenInputClient = tostring(newQty); elseif tonumber(quantityToSellDrogenInputClient) <= 0 and newQty > 0 then quantityToSellDrogenInputClient = "1"; end; if newQty==0 then selectedDrugToSellClient=nil; quantityToSellDrogenInputClient="1"; end
            else quantityToSellDrogenInputClient="1"; if oldSelectedIdx then scrollOffsetDrogen=0 end end
        else quantityToSellDrogenInputClient="1"; if oldSelectedIdx then scrollOffsetDrogen=0 end end
    end
    if firstOpen then showCursor(true);guiSetInputMode("no_binds_when_editing"); if not isDrogenSellGUIRenderHandlerActive then addEventHandler("onClientRender",root,renderDrogenSellGUI);isDrogenSellGUIRenderHandlerActive=true end; if not isDrogenSellGUIInputHandlersActive then addEventHandler("onClientClick",root,handleDrogenSellGUIClick);addEventHandler("onClientKey",root,handleDrogenSellGUIKey);addEventHandler("onClientCharacter",root,handleDrogenSellGUICharacter);bindKey("mouse_wheel_up","down",scrollDrogenListUp);bindKey("mouse_wheel_down","down",scrollDrogenListDown);isDrogenSellGUIInputHandlersActive=true end end
end

function closeDrogenSellGUI()
    if not isDrogenSellGUIVisible then return end; isDrogenSellGUIVisible=false; _G.isDrugSellGUIVisible=false; activeDrogenSellInputElement=nil
    if isDrogenSellGUIRenderHandlerActive then removeEventHandler("onClientRender",root,renderDrogenSellGUI);isDrogenSellGUIRenderHandlerActive=false end
    if isDrogenSellGUIInputHandlersActive then removeEventHandler("onClientClick",root,handleDrogenSellGUIClick);removeEventHandler("onClientKey",root,handleDrogenSellGUIKey);removeEventHandler("onClientCharacter",root,handleDrogenSellGUICharacter);unbindKey("mouse_wheel_up","down",scrollDrogenListUp);unbindKey("mouse_wheel_down","down",scrollDrogenListDown);isDrogenSellGUIInputHandlersActive=false end
    if not (_G.isInventoryVisible or _G.isHandyGUIVisible or _G.isPedGuiOpen or _G.isDrugSeedBuyGUIVisible) then showCursor(false); guiSetInputMode("allow_binds") end
end

function handleDrogenSellGUIClick(button, state, absX, absY)
    if not isDrogenSellGUIVisible or button~="left" or state~="up" then return end
    
    local function isCursorOver(el)
        if not el then return false end
        return absX >= el.x and absX <= el.x + el.w and absY >= el.y and absY <= el.y + el.h
    end

    if drogenSellGUIElements.items then
        for index, area in pairs(drogenSellGUIElements.items) do
            if isCursorOver(area) then
                selectedDrugToSellClient = index
                quantityToSellDrogenInputClient = "1"
                return
            end
        end
    end
    
    if selectedDrugToSellClient and drogenSellableItemsClient[selectedDrugToSellClient] then
        local item = drogenSellableItemsClient[selectedDrugToSellClient]
        if isCursorOver(drogenSellGUIElements.minus) then
            local cq = tonumber(quantityToSellDrogenInputClient) or 1
            quantityToSellDrogenInputClient = tostring(math.max(1, cq - 1))
            return
        end
        if isCursorOver(drogenSellGUIElements.plus) then
            local cq = tonumber(quantityToSellDrogenInputClient) or 0
            quantityToSellDrogenInputClient = tostring(math.min(item.quantity, cq + 1))
            return
        end
        if isCursorOver(drogenSellGUIElements.input) then
            activeDrogenSellInputElement = "quantity"
            return
        end
        if isCursorOver(drogenSellGUIElements.sell) then
            local qty = tonumber(quantityToSellDrogenInputClient)
            if item and qty and qty > 0 and item.slot then
                if qty > item.quantity then
                    outputChatBox("Max: " .. item.quantity, 255, 100, 0)
                    quantityToSellDrogenInputClient = tostring(item.quantity)
                else
                    triggerServerEvent("drogensystem:sellDrugItem", localPlayer, item.slot, qty)
                end
            else
                outputChatBox("Ungültig.", 255, 100, 0)
            end
            return
        end
    end

    if isCursorOver(drogenSellGUIElements.close) then
        closeDrogenSellGUI()
        return
    end
end


function handleDrogenSellGUIKey(key,press)
    if not isDrogenSellGUIVisible or not press then return end;if key=="escape"then closeDrogenSellGUI();cancelEvent()elseif activeDrogenSellInputElement=="quantity"then if key=="backspace"then quantityToSellDrogenInputClient=string.sub(quantityToSellDrogenInputClient,1,-2);if quantityToSellDrogenInputClient==""then quantityToSellDrogenInputClient="0"end;local numVal=tonumber(quantityToSellDrogenInputClient)or 0;if selectedDrugToSellClient and drogenSellableItemsClient[selectedDrugToSellClient]then local maxQty=drogenSellableItemsClient[selectedDrugToSellClient].quantity;if numVal>maxQty then quantityToSellDrogenInputClient=tostring(maxQty)end end;if numVal<0 then quantityToSellDrogenInputClient="0"end end end
end

function handleDrogenSellGUICharacter(char)
    if not isDrogenSellGUIVisible or activeDrogenSellInputElement~="quantity"then return end
    if tonumber(char)then local newQtyStr=quantityToSellDrogenInputClient;if quantityToSellDrogenInputClient=="0"and char~="0"then newQtyStr=""end;newQtyStr=newQtyStr..char
        if string.len(newQtyStr)<=7 then local numVal=tonumber(newQtyStr);if numVal then if selectedDrugToSellClient and drogenSellableItemsClient[selectedDrugToSellClient]then local maxQty=drogenSellableItemsClient[selectedDrugToSellClient].quantity;if numVal>maxQty then quantityToSellDrogenInputClient=tostring(maxQty)else quantityToSellDrogenInputClient=newQtyStr end else quantityToSellDrogenInputClient=newQtyStr end else quantityToSellDrogenInputClient="0"end end
    end
end

function scrollDrogenListUp() if not isDrogenSellGUIVisible then return end;if #drogenSellableItemsClient>maxVisibleItemsDrogenList then scrollOffsetDrogen=math.max(0,scrollOffsetDrogen-1)end end
function scrollDrogenListDown() if not isDrogenSellGUIVisible then return end;if #drogenSellableItemsClient>maxVisibleItemsDrogenList then scrollOffsetDrogen=math.min(math.max(0,#drogenSellableItemsClient-maxVisibleItemsDrogenList),scrollOffsetDrogen+1)end end


-----------------------------------------------------------------------------------------
--- ANFANG: HINZUGEFÜGTER CODE FÜR PFLANZ-ANIMATION
-----------------------------------------------------------------------------------------

local isPlantingAnimationActive = false
local plantingProgressBarTimer = nil
local plantingProgressBarStart = nil
local plantingProgressBarEnd = nil

function renderPlantingProgressBar()
    if not isPlantingAnimationActive or not plantingProgressBarStart or not plantingProgressBarEnd then return end

    local now = getTickCount()
    local perc = (now - plantingProgressBarStart) / (plantingProgressBarEnd - plantingProgressBarStart)
    perc = math.max(0, math.min(1, perc))

    local barW, barH = 300, 30
    local barX, barY = (screenW - barW) / 2, screenH - 100

    dxDrawRectangle(barX, barY, barW, barH, tocolor(0, 0, 0, 180))
    dxDrawRectangle(barX, barY, barW * perc, barH, tocolor(0, 150, 0, 180))
    dxDrawText("Pflanze an...", barX, barY, barX + barW, barY + barH, tocolor(255, 255, 255, 220), 1.0, "default-bold", "center", "center")
end

function stopPlantingAnimation(drugKey)
    isPlantingAnimationActive = false
    if isTimer(plantingProgressBarTimer) then
        killTimer(plantingProgressBarTimer)
        plantingProgressBarTimer = nil
    end
    removeEventHandler("onClientRender", root, renderPlantingProgressBar)
    setPedAnimation(localPlayer)
    toggleAllControls(true)

    if drugKey then
        triggerServerEvent("drogensystem:onClientFinishedPlanting", localPlayer, drugKey)
    end
end

addEvent("drogensystem:startPlantingAnimation", true)
addEventHandler("drogensystem:startPlantingAnimation", root, function(drugKey, duration)
    -- Verhindern, dass die Animation gestartet wird, wenn bereits eine andere Aktion ausgeführt wird
    if isDrogenSellGUIVisible or isDrogenBuyGUIVisible or isPlantingAnimationActive then return end

    isPlantingAnimationActive = true
    plantingProgressBarStart = getTickCount()
    plantingProgressBarEnd = plantingProgressBarStart + duration

    -- Spieler einfrieren und Animation starten
    setPedAnimation(localPlayer, "BOMBER", "BOM_Plant", -1, false, false, false, false)
    toggleAllControls(false)

    addEventHandler("onClientRender", root, renderPlantingProgressBar)

    plantingProgressBarTimer = setTimer(stopPlantingAnimation, duration, 1, drugKey)
end)

-----------------------------------------------------------------------------------------
--- ENDE: HINZUGEFÜGTER CODE FÜR PFLANZ-ANIMATION
-----------------------------------------------------------------------------------------


-- Resource Start/Stop
addEventHandler("onClientResourceStart", resourceRoot, function()
    if _G.isDrugSellGUIVisible == nil then _G.isDrugSellGUIVisible = false end
    if _G.isDrugSeedBuyGUIVisible == nil then _G.isDrugSeedBuyGUIVisible = false end
    cannabisIconTextureClient = dxCreateTexture(CANNABIS_ICON_PATH_CLIENT); kokainIconTextureClient = dxCreateTexture(KOKAIN_ICON_PATH_CLIENT)
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    closeDrogenSellGUI(); closeDrogenBuyGUI()
    if cannabisIconTextureClient and isElement(cannabisIconTextureClient) then destroyElement(cannabisIconTextureClient); cannabisIconTextureClient = nil; end
    if kokainIconTextureClient and isElement(kokainIconTextureClient) then destroyElement(kokainIconTextureClient); kokainIconTextureClient = nil; end
end)