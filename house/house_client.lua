-- [house_system]/house_client.lua (Final - Ohne DX Text, mit Bestätigungen)

-- Tabellen für Pickups
local housePickups = {} -- { [houseID] = { element = pickupElement, ownerId = id/nil, posX=, posY=, posZ= } }

-- GUI Status
local isGuiOpen = false
local currentGuiData = nil
local isInfoRenderHandlerAttached = false -- Flag für HAUPT GUI Render Handler

-- Status für Dialoge
local showBuyConfirmation = false
local showSellConfirmation = false
local houseIDToSell = nil
local calculatedSellPrice = 0
local isSellRenderHandlerAttached = false -- Flag für SELL DIALOG Render Handler
local sellConfirmYesArea = nil -- Globale Variable für Klickbereich
local sellConfirmNoArea = nil  -- Globale Variable für Klickbereich

-- Konstanten für Pickups
local HOUSE_PICKUP_TYPE = 3
local HOUSE_PICKUP_RESPAWN_TIME = 0
local PICKUP_MODEL_FORSALE = 1273 -- Grün
local PICKUP_MODEL_OWNED = 1272   -- Blau

-- Globale Variable für den Timer
nearbyCheckTimer = nil -- Wird in onClientResourceStart initialisiert

-- Handler-Funktionen explizit definieren
local function handleCreateBlipClient(houseID, x, y, z, ownerAccountId)
    createOrUpdatePickup(houseID, x, y, z, ownerAccountId)
end

local function handleShowInfoGUI(houseInfo)
    if isGuiOpen or showSellConfirmation then closeDialogs() end
    isGuiOpen = true
    currentGuiData = houseInfo
    showBuyConfirmation = false
    showSellConfirmation = false
    if not isInfoRenderHandlerAttached then addEventHandler("onClientRender", root, renderHouseInfoGUI); isInfoRenderHandlerAttached = true end
    if not isCursorShowing() then showCursor(true) end
    guiSetInputMode("no_binds_when_editing")
end

local function handleCloseGUI()
    closeDialogs()
end

local function handleUpdateVisualState(houseID, newOwnerId, newOwnerName)
    -- outputDebugString("[HouseClient] Update Visual State #" .. houseID)
    if housePickups[houseID] then
        local data = housePickups[houseID]
        housePickups[houseID].ownerId = newOwnerId
        createOrUpdatePickup(houseID, data.posX, data.posY, data.posZ, newOwnerId)
    end
end

local function handleShowSellConfirmation(houseID, sellPrice)
    if isGuiOpen or showSellConfirmation or showBuyConfirmation then closeDialogs() end
    -- outputDebugString("[HouseClient] Zeige Verkaufsbestätigung für Haus #" .. houseID .. " Preis: " .. sellPrice)
    houseIDToSell = houseID
    calculatedSellPrice = sellPrice
    showSellConfirmation = true
    if not isSellRenderHandlerAttached then
        addEventHandler("onClientRender", root, renderSellConfirmationDialog)
        isSellRenderHandlerAttached = true
    end
    if not isCursorShowing() then showCursor(true) end
    guiSetInputMode("no_binds_when_editing")
end


-- Hilfsfunktion: Pickup erstellen oder aktualisieren
function createOrUpdatePickup(houseID, x, y, z, ownerAccountId)
    local isOwned = (type(ownerAccountId) == "number" and ownerAccountId > 0)
    local modelToUse = isOwned and PICKUP_MODEL_OWNED or PICKUP_MODEL_FORSALE
    if isElement(housePickups[houseID] and housePickups[houseID].element) then
        local currentModel = getElementModel(housePickups[houseID].element)
        if currentModel == modelToUse then
             housePickups[houseID].ownerId = ownerAccountId; return
        else
            removeEventHandler("onClientPickupHit", housePickups[houseID].element, handlePickupHit)
            destroyElement(housePickups[houseID].element)
            housePickups[houseID] = nil
        end
    end
    if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
        -- outputDebugString("[HouseClient] FEHLER: Ungültige Koords Pickup #" .. tostring(houseID)); return
    end
    local pickup = createPickup(x, y, z, HOUSE_PICKUP_TYPE, modelToUse, HOUSE_PICKUP_RESPAWN_TIME)
    if isElement(pickup) then
        setElementData(pickup, "houseID", houseID, false)
        housePickups[houseID] = { element = pickup, ownerId = ownerAccountId, posX = x, posY = y, posZ = z }
        addEventHandler("onClientPickupHit", pickup, handlePickupHit)
    -- else outputDebugString("[HouseClient] Fehler Erstellen Pickup #" .. tostring(houseID))
    end
end

-- Handler-Funktion für Pickup-Hits
function handlePickupHit(hitElement, matchingDimension)
    if hitElement == localPlayer and matchingDimension then
        local id = getElementData(source, "houseID")
        if id then if isGuiOpen or showSellConfirmation or showBuyConfirmation then return end; triggerServerEvent("requestHouseInfo", localPlayer, id) end
    end
end

-- Setup in onClientResourceStart
addEventHandler("onClientResourceStart", resourceRoot, function()
    -- Benötigte Events registrieren
    addEvent("createHouseBlipClient", true); addEvent("showHouseInfoGUI", true)
    addEvent("closeHouseGUI", true); addEvent("updateHouseVisualStateClient", true)
    addEvent("showSellConfirmationClient", true)

    -- Event Handler hinzufügen
    addEventHandler("createHouseBlipClient", root, handleCreateBlipClient)
    addEventHandler("showHouseInfoGUI", root, handleShowInfoGUI)
    addEventHandler("closeHouseGUI", root, handleCloseGUI)
    addEventHandler("updateHouseVisualStateClient", root, handleUpdateVisualState)
    addEventHandler("showSellConfirmationClient", root, handleShowSellConfirmation)
    addEventHandler("onClientClick", root, handleGuiButtonClick) -- Globaler Klick-Handler für GUI

    -- Client fordert Häuser nach kurzer Verzögerung an
    setTimer(function() if isElement(localPlayer) then triggerServerEvent("requestExistingHouses", localPlayer) end end, 500, 1)

    outputDebugString("[HouseSystem] Client-Setup abgeschlossen (ohne DX Text).")
end)

-- Separate Render-Funktion für Verkaufsdialog
function renderSellConfirmationDialog()
    if not showSellConfirmation then return end
    local screenW, screenH = guiGetScreenSize(); if not screenW or not screenH then return end
    local confirmW, confirmH = 340, 170; local confirmX, confirmY = (screenW - confirmW) / 2, (screenH - confirmH) / 2
    dxDrawRectangle(0, 0, screenW, screenH, tocolor(0, 0, 0, 150)); dxDrawRectangle(confirmX, confirmY, confirmW, confirmH, tocolor(40, 40, 50, 245))
    dxDrawText("Confirm Sale", confirmX, confirmY + 5, confirmX + confirmW, confirmY + 35, tocolor(255, 200, 100), 1.2, "default-bold", "center", "top")
    dxDrawText(string.format("Do you really want to sell\nHouse #%d for %s?", houseIDToSell or -1, formatMoney(calculatedSellPrice or 0)), confirmX + 10, confirmY + 45, confirmX + confirmW - 10, confirmY + 105, tocolor(220, 220, 220), 1.1, "default", "center", "top")
    local confirmBtnW, confirmBtnH = 100, 35; local confirmBtnY = confirmY + confirmH - confirmBtnH - 15; local confirmBtnSpacing = 20
    local confirmBtnYesX = confirmX + (confirmW / 2) - confirmBtnW - (confirmBtnSpacing / 2); local confirmBtnNoX = confirmX + (confirmW / 2) + (confirmBtnSpacing / 2)
    dxDrawRectangle(confirmBtnYesX, confirmBtnY, confirmBtnW, confirmBtnH, tocolor(50, 180, 50, 220)); dxDrawText("Yes", confirmBtnYesX, confirmBtnY, confirmBtnYesX + confirmBtnW, confirmBtnY + confirmBtnH, tocolor(255,255,255), 1.1, "default-bold", "center", "center")
    dxDrawRectangle(confirmBtnNoX, confirmBtnY, confirmBtnW, confirmBtnH, tocolor(200, 50, 50, 220)); dxDrawText("No", confirmBtnNoX, confirmBtnY, confirmBtnNoX + confirmBtnW, confirmBtnY + confirmBtnH, tocolor(255,255,255), 1.1, "default-bold", "center", "center")
    sellConfirmYesArea = { x = confirmBtnYesX, y = confirmBtnY, w = confirmBtnW, h = confirmBtnH }; sellConfirmNoArea = { x = confirmBtnNoX, y = confirmBtnY, w = confirmBtnW, h = confirmBtnH }
end

-- GUI Render-Funktion (Zeichnet jetzt optional den KAUF-Dialog)
function renderHouseInfoGUI()
    if not isGuiOpen or not currentGuiData then return end; local screenW, screenH = guiGetScreenSize(); if not screenW or not screenH then return end
    local guiWidth, guiHeight = 350, 240; local guiX, guiY = (screenW - guiWidth) / 2, (screenH - guiHeight) / 2
    dxDrawRectangle(guiX, guiY, guiWidth, guiHeight, tocolor(30, 30, 35, 230)); dxDrawRectangle(guiX, guiY, guiWidth, 40, tocolor(0, 80, 150, 200))
    dxDrawLine(guiX, guiY+40, guiX+guiWidth, guiY+40, tocolor(255,255,255, 50), 2); dxDrawText("House Information (#" .. currentGuiData.id .. ")", guiX, guiY, guiX + guiWidth, guiY + 40, tocolor(255, 255, 255), 1.3, "default-bold", "center", "center")
    local textY = guiY + 55; local isOwner = false; local localPlayerAccountID = getElementData(localPlayer, "account_id"); local labelScale = 1.0; local valueScale = 1.1
    if currentGuiData.status == "forsale" then
        dxDrawText("Status:", guiX + 15, textY, guiX + guiWidth - 15, textY + 20, tocolor(200, 200, 200), labelScale, "default", "left", "top"); dxDrawText("For Sale", guiX + 15, textY, guiX + guiWidth - 15, textY + 20, tocolor(100, 255, 100), valueScale, "default-bold", "right", "top"); textY = textY + 25
        dxDrawText("Price:", guiX + 15, textY, guiX + guiWidth - 15, textY + 20, tocolor(200, 200, 200), labelScale, "default", "left", "top"); dxDrawText(formatMoney(currentGuiData.price), guiX + 15, textY, guiX + guiWidth - 15, textY + 20, tocolor(100, 255, 100), valueScale, "default-bold", "right", "top"); textY = textY + 25
        dxDrawText("Interior ID:", guiX + 15, textY, guiX + guiWidth - 15, textY + 20, tocolor(200, 200, 200), labelScale, "default", "left", "top"); dxDrawText(tostring(currentGuiData.interior or 0), guiX + 15, textY, guiX + guiWidth - 15, textY + 20, tocolor(180, 180, 255), labelScale, "default-bold", "right", "top")
    elseif currentGuiData.status == "owned" then
        dxDrawText("Status:", guiX + 15, textY, guiX + guiWidth - 15, textY + 20, tocolor(200, 200, 200), labelScale, "default", "left", "top"); dxDrawText("Owned", guiX + 15, textY, guiX + guiWidth - 15, textY + 20, tocolor(255, 100, 100), valueScale, "default-bold", "right", "top"); textY = textY + 25
        dxDrawText("Owner:", guiX + 15, textY, guiX + guiWidth - 15, textY + 20, tocolor(200, 200, 200), labelScale, "default", "left", "top"); dxDrawText(currentGuiData.owner or "Unknown", guiX + 15, textY, guiX + guiWidth - 15, textY + 20, tocolor(255, 255, 150), valueScale, "default-bold", "right", "top"); textY = textY + 25
        dxDrawText("Interior ID:", guiX + 15, textY, guiX + guiWidth - 15, textY + 20, tocolor(200, 200, 200), labelScale, "default", "left", "top"); dxDrawText(tostring(currentGuiData.interior or 0), guiX + 15, textY, guiX + guiWidth - 15, textY + 20, tocolor(180, 180, 255), labelScale, "default-bold", "right", "top")
        if localPlayerAccountID and currentGuiData.owner_id and localPlayerAccountID == currentGuiData.owner_id then isOwner = true end
    else dxDrawText("Info unavailable.", guiX + 10, textY, guiX + guiWidth - 10, guiY + guiHeight - 50, tocolor(220, 220, 220), 1.1, "default", "center", "top") end
    local btnW, btnH = 110, 35; local btnY = guiY + guiHeight - btnH - 20; local btnSpacing = 10; local buttonsToDraw = {}
    if currentGuiData.status == "forsale" then table.insert(buttonsToDraw, { text = "Buy House", color = {50, 180, 50, 220}, action = "buy" }) end
    if isOwner then table.insert(buttonsToDraw, { text = "Enter House", color = {50, 150, 200, 220}, action = "enter" }) end
    table.insert(buttonsToDraw, { text = "Close", color = {200, 50, 50, 220}, action = "close" })
    local totalButtonWidth=(#buttonsToDraw * btnW) + (math.max(0, #buttonsToDraw - 1) * btnSpacing); local currentBtnX=guiX+(guiWidth - totalButtonWidth) / 2; currentGuiData.buttons = {}
    for i, btnData in ipairs(buttonsToDraw) do dxDrawRectangle(currentBtnX, btnY, btnW, btnH, tocolor(unpack(btnData.color))); dxDrawText(btnData.text, currentBtnX, btnY, currentBtnX + btnW, btnY + btnH, tocolor(255, 255, 255), 1.1, "default-bold", "center", "center"); currentGuiData.buttons[btnData.action] = { x = currentBtnX, y = btnY, w = btnW, h = btnH }; currentBtnX = currentBtnX + btnW + btnSpacing end

    -- Zeichne KAUF-Bestätigungsdialog (wenn aktiv)
    if showBuyConfirmation then
        dxDrawRectangle(0, 0, screenW, screenH, tocolor(0, 0, 0, 150))
        local confirmW, confirmH = 340, 170; local confirmX, confirmY = (screenW - confirmW) / 2, (screenH - confirmH) / 2
        local price = currentGuiData and currentGuiData.price or 0
        dxDrawRectangle(confirmX, confirmY, confirmW, confirmH, tocolor(40, 40, 50, 245))
        dxDrawText("Confirm Purchase", confirmX, confirmY + 5, confirmX + confirmW, confirmY + 35, tocolor(255, 255, 150), 1.2, "default-bold", "center", "top")
        dxDrawText(string.format("Buy House #%d for %s?", currentGuiData.id, formatMoney(price)), confirmX + 10, confirmY + 45, confirmX + confirmW - 10, confirmY + 105, tocolor(220, 220, 220), 1.1, "default", "center", "top")
        local confirmBtnW, confirmBtnH = 100, 35; local confirmBtnY = confirmY + confirmH - confirmBtnH - 15; local confirmBtnSpacing = 20
        local confirmBtnYesX = confirmX + (confirmW / 2) - confirmBtnW - (confirmBtnSpacing / 2); local confirmBtnNoX = confirmX + (confirmW / 2) + (confirmBtnSpacing / 2)
        dxDrawRectangle(confirmBtnYesX, confirmBtnY, confirmBtnW, confirmBtnH, tocolor(50, 180, 50, 220)); dxDrawText("Yes", confirmBtnYesX, confirmBtnY, confirmBtnYesX + confirmBtnW, confirmBtnY + confirmBtnH, tocolor(255,255,255), 1.1, "default-bold", "center", "center")
        dxDrawRectangle(confirmBtnNoX, confirmBtnY, confirmBtnW, confirmBtnH, tocolor(200, 50, 50, 220)); dxDrawText("No", confirmBtnNoX, confirmBtnY, confirmBtnNoX + confirmBtnW, confirmBtnY + confirmBtnH, tocolor(255,255,255), 1.1, "default-bold", "center", "center")
        if not currentGuiData then currentGuiData = {} end; currentGuiData.confirmButtons = { yes = { x = confirmBtnYesX, y = confirmBtnY, w = confirmBtnW, h = confirmBtnH }, no = { x = confirmBtnNoX, y = confirmBtnY, w = confirmBtnW, h = confirmBtnH } }; currentGuiData.confirmAction = "buy"
    elseif not showSellConfirmation then -- Nur zurücksetzen, wenn kein anderer Dialog aktiv ist
        if currentGuiData then currentGuiData.confirmButtons = nil; currentGuiData.confirmAction = nil; end
    end
end

-- Funktion zum Schließen ALLER GUIs/Dialoge
function closeDialogs()
    if not isGuiOpen and not showSellConfirmation then return end
    isGuiOpen = false; showBuyConfirmation = false; showSellConfirmation = false
    currentGuiData = nil; houseIDToSell = nil; calculatedSellPrice = 0
    if isCursorShowing() then showCursor(false) end
    if isInfoRenderHandlerAttached then removeEventHandler("onClientRender", root, renderHouseInfoGUI); isInfoRenderHandlerAttached = false end
    if isSellRenderHandlerAttached then removeEventHandler("onClientRender", root, renderSellConfirmationDialog); isSellRenderHandlerAttached = false end
    guiSetInputMode("allow_binds")
end

-- Globaler Klick-Handler für GUI Buttons
function handleGuiButtonClick(button, state, absX, absY)
    if button ~= "left" or state ~= "up" then return end
    if not isGuiOpen and not showSellConfirmation then return end

    -- Prüfe VERKAUFS-Dialog
    if showSellConfirmation then
        local yesArea = sellConfirmYesArea; local noArea = sellConfirmNoArea
        if yesArea and absX >= yesArea.x and absX <= yesArea.x + yesArea.w and absY >= yesArea.y and absY <= yesArea.y + yesArea.h then
            -- outputDebugString("[HouseClient] Verkauf bestätigt #" .. tostring(houseIDToSell))
            triggerServerEvent("confirmSellHouse", localPlayer, houseIDToSell)
            closeDialogs()
        elseif noArea and absX >= noArea.x and absX <= noArea.x + noArea.w and absY >= noArea.y and absY <= noArea.y + noArea.h then
            -- outputDebugString("[HouseClient] Verkauf abgelehnt.")
            closeDialogs()
        end
        return
    end

    -- Prüfe KAUF-Dialog (nur wenn Haupt-GUI offen ist)
    if showBuyConfirmation and isGuiOpen and currentGuiData and currentGuiData.confirmButtons then
        local confirmAction = currentGuiData.confirmAction
        local yesArea = currentGuiData.confirmButtons.yes; local noArea = currentGuiData.confirmButtons.no
        if yesArea and absX >= yesArea.x and absX <= yesArea.x + yesArea.w and absY >= yesArea.y and absY <= yesArea.y + yesArea.h then
            if confirmAction == "buy" then -- outputDebugString("[HouseClient] Kauf bestätigt #" .. currentGuiData.id);
			triggerServerEvent("tryBuyHouse", localPlayer, currentGuiData.id) end
            showBuyConfirmation = false
        elseif noArea and absX >= noArea.x and absX <= noArea.x + noArea.w and absY >= noArea.y and absY <= noArea.y + noArea.h then
            showBuyConfirmation = false
        end
        return
    end

    -- Wenn KEIN Dialog aktiv ist, prüfe Haupt-GUI Buttons
    if isGuiOpen and currentGuiData and currentGuiData.buttons then
        for action, area in pairs(currentGuiData.buttons) do
            if absX >= area.x and absX <= area.x + area.w and absY >= area.y and absY <= area.y + area.h then
                if action == "close" then closeDialogs()
                elseif action == "buy" then -- outputDebugString("[HouseClient] Kauf-Button geklickt #" .. currentGuiData.id);
				showBuyConfirmation = true; if not isInfoRenderHandlerAttached then addEventHandler("onClientRender", root, renderHouseInfoGUI); isInfoRenderHandlerAttached = true end
                elseif action == "enter" then -- outputDebugString("[HouseClient] Enter-Anfrage #" .. currentGuiData.id);
				triggerServerEvent("requestEnterHouse", localPlayer, currentGuiData.id) end
                return
            end
        end
    end
end


-- Hilfsfunktion Geld formatieren
function formatMoney(amount) local formatted=string.format("%.0f", amount or 0); local k repeat formatted, k=string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1.%2') until k==0 return "$" .. formatted end

-- Aufräumen beim Beenden
addEventHandler("onClientResourceStop", resourceRoot, function()
    closeDialogs()
    for id, pickupData in pairs(housePickups) do if isElement(pickupData.element) then removeEventHandler("onClientPickupHit", pickupData.element, handlePickupHit); destroyElement(pickupData.element) end end
    housePickups = {}
    -- Entferne die spezifischen Handler
    removeEventHandler("onClientClick", root, handleGuiButtonClick)
    removeEventHandler("closeHouseGUI", root, handleCloseGUI)
    removeEventHandler("updateHouseVisualStateClient", root, handleUpdateVisualState)
    removeEventHandler("createHouseBlipClient", root, handleCreateBlipClient)
    removeEventHandler("showHouseInfoGUI", root, handleShowInfoGUI)
    removeEventHandler("showSellConfirmationClient", root, handleShowSellConfirmation)
    if isInfoRenderHandlerAttached then removeEventHandler("onClientRender", root, renderHouseInfoGUI); isInfoRenderHandlerAttached = false end
    if isSellRenderHandlerAttached then removeEventHandler("onClientRender", root, renderSellConfirmationDialog); isSellRenderHandlerAttached = false end
    if isTimer(nearbyCheckTimer) then killTimer(nearbyCheckTimer); nearbyCheckTimer = nil end
end)

outputDebugString("[HouseSystem] Haus-System Client (Final) geladen.")