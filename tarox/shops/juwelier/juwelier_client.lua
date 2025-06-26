-- tarox/shops/juwelier/juwelier_client.lua

local screenW, screenH = guiGetScreenSize()
local isJuwelierGUIVisible = false
local juwelierSellableItems = {}
local selectedItemToSell = nil
local quantityToSellInput = "1"
local activeSellInputElement = nil

local guiColors = {
    BG_MAIN = tocolor(28, 30, 36, 245), BG_HEADER = tocolor(218, 165, 32, 235),
    TEXT_HEADER = tocolor(255, 255, 255), TEXT_LIGHT = tocolor(230, 230, 235),
    TEXT_ITEM_NAME = tocolor(255, 223, 120), TEXT_PRICE = tocolor(100, 220, 100),
    TEXT_QUANTITY_VALUE = tocolor(230, 230, 240),
    TEXT_PRICE_VALUE = tocolor(150, 250, 150),
    TEXT_LABEL = tocolor(190, 190, 200),
    TEXT_INFO_HEADER = tocolor(215, 215, 225),
    SLOT_BG = tocolor(40, 43, 51, 210), SLOT_HOVER_BG = tocolor(55, 58, 68, 220),
    SLOT_SELECTED_BG = tocolor(0, 122, 204, 190),
    BUTTON_SELL_BG = tocolor(70, 180, 70, 220), BUTTON_SELL_HOVER = tocolor(90, 200, 90, 230),
    BUTTON_CLOSE_BG = tocolor(200, 70, 70, 220), BUTTON_CLOSE_HOVER = tocolor(220, 90, 90, 230),
    BUTTON_TEXT = tocolor(245, 245, 245), INPUT_BG = tocolor(50,50,55,230),
    ARROW_BUTTON_BG = tocolor(85, 85, 95, 225), ARROW_BUTTON_HOVER_BG = tocolor(105, 105, 115, 235)
}

local guiFonts = {
    HEADER = {font = "default-bold", scale = 1.25},
    LIST_HEADER = {font = "default", scale = 1},
    ITEM_NAME = {font = "default", scale = 1},
    ITEM_DETAILS_QTY = {font = "default", scale = 1},
    ITEM_DETAILS_PRICE = {font = "default", scale = 1},
    BUTTON = {font = "default", scale = 1},
    ARROW_BUTTON = {font = "default", scale = 1.3},
    INFO_HEADER = {font = "default", scale = 1},
    INFO_TEXT_LABEL = {font = "default", scale = 1},
    INFO_TEXT_VALUE = {font = "default", scale = 1},
    INPUT_TEXT = {font = "default", scale = 1},
    TOTAL_PRICE_TEXT = {font = "default", scale = 1}
}

local windowW, windowH = 640, 560
local windowX, windowY = (screenW - windowW) / 2, (screenH - windowH) / 2

local listHeaderYPosition = windowY + 55
local listItemsOffsetYFromHeader = 25
local itemsStartY = listHeaderYPosition + listItemsOffsetYFromHeader

local listOffsetX = 20;
local listWidth = windowW - (listOffsetX * 2)
local listItemHeight = 48
local itemSlotSpacing = 3

local buttonW = 140
local buttonH = 42
local buttonBottomMargin = 20 + 2
local buttonSpacing = 20

local mengeInputWidth = 70
local mengeInputHeight = 30
local mengeArrowButtonWidth = 34
local mengeArrowButtonHeight = mengeInputHeight
local mengeLabelToControlsSpacing = 15

local currentMengeControlsY = 0

local isJuwelierGuiRenderHandlerActive = false
local isJuwelierGuiInputHandlersActive = false

local scrollOffset = 0
local maxVisibleItemsInList = 1

addEvent("juwelier:openSellGUI", true)
addEvent("juwelier:refreshSellGUIData", true)

local function calculateTotalSellPrice()
    if selectedItemToSell and juwelierSellableItems[selectedItemToSell] then
        local item = juwelierSellableItems[selectedItemToSell]
        local qty = tonumber(quantityToSellInput) or 0
        qty = math.max(0, math.min(qty, item.quantity))
        return (item.sell_price_each or 0) * qty
    end
    return 0
end

function renderJuwelierSellGUI()
    if not isJuwelierGUIVisible then return end

    dxDrawRectangle(windowX, windowY, windowW, windowH, guiColors.BG_MAIN)
    dxDrawRectangle(windowX, windowY, windowW, 40, guiColors.BG_HEADER)
    dxDrawText("Juwelier - Wertsachen Verkaufen", windowX, windowY, windowX + windowW, windowY + 40, guiColors.TEXT_HEADER, guiFonts.HEADER.scale, guiFonts.HEADER.font, "center", "center")

    local mX_rel, mY_rel = getCursorPosition()
    local mX_abs, mY_abs
    if mX_rel then mX_abs = mX_rel * screenW; mY_abs = mY_rel * screenH end

    local colIconWidthSpace = 50
    local colNameX = windowX + listOffsetX + 5
    local colQtyX = colNameX + 290
    local colPriceEachX = colQtyX + 90

    dxDrawText("Item", colNameX + colIconWidthSpace/2 - 10, listHeaderYPosition, 0,0, guiColors.TEXT_LABEL, guiFonts.LIST_HEADER.scale, guiFonts.LIST_HEADER.font, "left")
    dxDrawText("Menge", colQtyX, listHeaderYPosition, 0,0, guiColors.TEXT_LABEL, guiFonts.LIST_HEADER.scale, guiFonts.LIST_HEADER.font, "left")
    dxDrawText("Preis/Stk.", colPriceEachX, listHeaderYPosition,0,0, guiColors.TEXT_LABEL, guiFonts.LIST_HEADER.scale, guiFonts.LIST_HEADER.font, "left")

    local sellSectionHeightEstimate = 145
    local listRenderAreaStartY = itemsStartY
    local listRenderAreaEndY = windowY + windowH - buttonBottomMargin - buttonH - 15 - sellSectionHeightEstimate
    local listAvailableRenderHeight = listRenderAreaEndY - listRenderAreaStartY

    if listAvailableRenderHeight > 0 then
        maxVisibleItemsInList = math.max(1, math.floor(listAvailableRenderHeight / listItemHeight))
    else
        maxVisibleItemsInList = 1
    end

    if #juwelierSellableItems == 0 then
        dxDrawText("Du besitzt keine verkaufbaren Wertgegenstände.", windowX + listOffsetX, itemsStartY + 50, windowX + listOffsetX + listWidth, itemsStartY + 150, guiColors.TEXT_LIGHT, 1.1, "default-bold", "center", "center", true)
    else
        for i = 1, maxVisibleItemsInList do
            local index = i + scrollOffset
            if juwelierSellableItems[index] then
                local item = juwelierSellableItems[index]
                local itemRowY = itemsStartY + (i-1) * listItemHeight
                local bgColor = guiColors.SLOT_BG

                if mX_abs and mY_abs and mX_abs >= windowX + listOffsetX and mX_abs <= windowX + listOffsetX + listWidth and mY_abs >= itemRowY and mY_abs <= itemRowY + listItemHeight - itemSlotSpacing then
                    bgColor = guiColors.SLOT_HOVER_BG
                end
                if selectedItemToSell == index then bgColor = guiColors.SLOT_SELECTED_BG end
                dxDrawRectangle(windowX + listOffsetX, itemRowY, listWidth, listItemHeight - itemSlotSpacing, bgColor)

                local textStartX = windowX + listOffsetX + 8
                local iconSize = 40
                local textIconOffsetY = (listItemHeight - itemSlotSpacing - iconSize)/2

                if item.imagePath and fileExists(item.imagePath) then
                    dxDrawImage(textStartX, itemRowY + textIconOffsetY, iconSize, iconSize, item.imagePath)
                    textStartX = textStartX + iconSize + 10
                else
                    textStartX = textStartX + iconSize + 10
                end
                dxDrawText(item.name or "Unbekannt", textStartX, itemRowY, colQtyX - 10, itemRowY + listItemHeight - itemSlotSpacing, guiColors.TEXT_ITEM_NAME, guiFonts.ITEM_NAME.scale, guiFonts.ITEM_NAME.font, "left", "center", true)
                dxDrawText(tostring(item.quantity or 0), colQtyX + 5, itemRowY, colPriceEachX - 10 , itemRowY + listItemHeight - itemSlotSpacing, guiColors.TEXT_QUANTITY_VALUE, guiFonts.ITEM_DETAILS_QTY.scale, guiFonts.ITEM_DETAILS_QTY.font, "left", "center")
                dxDrawText("$" .. string.format("%.0f", item.sell_price_each or 0), colPriceEachX + 5, itemRowY, windowX + listOffsetX + listWidth - 10, itemRowY + listItemHeight - itemSlotSpacing, guiColors.TEXT_PRICE_VALUE, guiFonts.ITEM_DETAILS_PRICE.scale, guiFonts.ITEM_DETAILS_PRICE.font, "left", "center")
            end
        end
    end

    local sellSectionContentX = windowX + listOffsetX + 15
    local sellSectionRenderY = listRenderAreaEndY + 20
    local lineHeightInSellSection = guiFonts.INFO_HEADER.scale * 12 * guiFonts.INFO_HEADER.scale + 12

    if selectedItemToSell and juwelierSellableItems[selectedItemToSell] then
        local item = juwelierSellableItems[selectedItemToSell]

        dxDrawText("Verkaufe:", sellSectionContentX, sellSectionRenderY, 0,0, guiColors.TEXT_INFO_HEADER, guiFonts.INFO_HEADER.scale, guiFonts.INFO_HEADER.font, "left", "top")
        dxDrawText(item.name or "Unbekannt", sellSectionContentX + dxGetTextWidth("Verkaufe: ", guiFonts.INFO_HEADER.scale, guiFonts.INFO_HEADER.font) + 5, sellSectionRenderY, 0,0, guiColors.TEXT_ITEM_NAME, guiFonts.INFO_TEXT_VALUE.scale, guiFonts.INFO_TEXT_VALUE.font, "left", "top")

        sellSectionRenderY = sellSectionRenderY + lineHeightInSellSection

        currentMengeControlsY = sellSectionRenderY + 2
        local mengeLabel = "Anzahl (Max: " .. item.quantity .. "):"
        local fontHeightAnzahlLabel = dxGetFontHeight(guiFonts.INFO_TEXT_LABEL.scale, guiFonts.INFO_TEXT_LABEL.font)
        local mengeLabelY = currentMengeControlsY + (mengeInputHeight - fontHeightAnzahlLabel) / 2
        dxDrawText(mengeLabel, sellSectionContentX, mengeLabelY, 0,0, guiColors.TEXT_LABEL, guiFonts.INFO_TEXT_LABEL.scale, guiFonts.INFO_TEXT_LABEL.font, "left", "top")

        local mengeControlsStartX = sellSectionContentX + dxGetTextWidth(mengeLabel, guiFonts.INFO_TEXT_LABEL.scale, guiFonts.INFO_TEXT_LABEL.font) + mengeLabelToControlsSpacing

        local minusButtonX = mengeControlsStartX
        local minusButtonHover = mX_abs and mY_abs and mX_abs >= minusButtonX and mX_abs <= minusButtonX + mengeArrowButtonWidth and mY_abs >= currentMengeControlsY and mY_abs <= currentMengeControlsY + mengeArrowButtonHeight
        dxDrawRectangle(minusButtonX, currentMengeControlsY, mengeArrowButtonWidth, mengeArrowButtonHeight, minusButtonHover and guiColors.ARROW_BUTTON_HOVER_BG or guiColors.ARROW_BUTTON_BG)
        dxDrawText("<", minusButtonX, currentMengeControlsY, minusButtonX + mengeArrowButtonWidth, currentMengeControlsY + mengeArrowButtonHeight, guiColors.BUTTON_TEXT, guiFonts.ARROW_BUTTON.scale, guiFonts.ARROW_BUTTON.font, "center", "center")

        local mengeDisplayX = minusButtonX + mengeArrowButtonWidth + 5
        dxDrawRectangle(mengeDisplayX, currentMengeControlsY, mengeInputWidth, mengeInputHeight, guiColors.INPUT_BG)
        dxDrawText(quantityToSellInput .. (activeSellInputElement=="quantity" and "_" or ""), mengeDisplayX + 5, currentMengeControlsY, mengeDisplayX + mengeInputWidth, currentMengeControlsY + mengeInputHeight, guiColors.TEXT_LIGHT, guiFonts.INPUT_TEXT.scale, guiFonts.INPUT_TEXT.font, "left", "center")

        local plusButtonX = mengeDisplayX + mengeInputWidth + 5
        local plusButtonHover = mX_abs and mY_abs and mX_abs >= plusButtonX and mX_abs <= plusButtonX + mengeArrowButtonWidth and mY_abs >= currentMengeControlsY and mY_abs <= currentMengeControlsY + mengeArrowButtonHeight
        dxDrawRectangle(plusButtonX, currentMengeControlsY, mengeArrowButtonWidth, mengeArrowButtonHeight, plusButtonHover and guiColors.ARROW_BUTTON_HOVER_BG or guiColors.ARROW_BUTTON_BG)
        dxDrawText(">", plusButtonX, currentMengeControlsY, plusButtonX + mengeArrowButtonWidth, currentMengeControlsY + mengeArrowButtonHeight, guiColors.BUTTON_TEXT, guiFonts.ARROW_BUTTON.scale, guiFonts.ARROW_BUTTON.font, "center", "center")

        sellSectionRenderY = sellSectionRenderY + mengeInputHeight + 15

        dxDrawText("Voraussichtlicher Erlös:", sellSectionContentX, sellSectionRenderY,0,0, guiColors.TEXT_INFO_HEADER, guiFonts.INFO_HEADER.scale, guiFonts.INFO_HEADER.font, "left", "top")
        dxDrawText("$" .. string.format("%.0f", calculateTotalSellPrice()), sellSectionContentX + dxGetTextWidth("Voraussichtlicher Erlös: ", guiFonts.INFO_HEADER.scale, guiFonts.INFO_HEADER.font) + 10, sellSectionRenderY,0,0, guiColors.TEXT_PRICE, guiFonts.TOTAL_PRICE_TEXT.scale, guiFonts.TOTAL_PRICE_TEXT.font, "left", "top")
    else
        dxDrawText("Wähle ein Item aus der Liste oben, um es zu verkaufen.", sellSectionContentX, sellSectionRenderY, sellSectionContentX + listWidth - 30, sellSectionRenderY + 40, guiColors.TEXT_LABEL, 1.0, "default-bold", "center", "center", true)
    end

    local closeButtonX = windowX + windowW - buttonW - 20
    local sellAndCloseButtonY = windowY + windowH - buttonH - buttonBottomMargin
    local sellButtonX = closeButtonX - buttonW - buttonSpacing

    dxDrawRectangle(closeButtonX, sellAndCloseButtonY, buttonW, buttonH, guiColors.BUTTON_CLOSE_BG)
    dxDrawText("Schließen", closeButtonX, sellAndCloseButtonY, closeButtonX + buttonW, sellAndCloseButtonY + buttonH, guiColors.BUTTON_TEXT, guiFonts.BUTTON.scale, guiFonts.BUTTON.font, "center", "center")

    if selectedItemToSell then
        dxDrawRectangle(sellButtonX, sellAndCloseButtonY, buttonW, buttonH, guiColors.BUTTON_SELL_BG)
        dxDrawText("Verkaufen", sellButtonX, sellAndCloseButtonY, sellButtonX + buttonW, sellAndCloseButtonY + buttonH, guiColors.BUTTON_TEXT, guiFonts.BUTTON.scale, guiFonts.BUTTON.font, "center", "center")
    end
end

function openJuwelierSellGUI(items)
    local firstOpen = not isJuwelierGUIVisible
    isJuwelierGUIVisible = true
    juwelierSellableItems = items or {}
    table.sort(juwelierSellableItems, function(a,b) return (a.name or "") < (b.name or "") end)

    if firstOpen then
        selectedItemToSell = nil
        quantityToSellInput = "1"
        scrollOffset = 0
        activeSellInputElement = nil
    else
        local currentSelectedActualSlot = nil
        if selectedItemToSell and juwelierSellableItems[selectedItemToSell] then
             currentSelectedActualSlot = juwelierSellableItems[selectedItemToSell].slot
        end

        local oldSelectedSellIndex = selectedItemToSell
        selectedItemToSell = nil

        if currentSelectedActualSlot then
            local newQtyForSelectedItem = 0
            for i, itemEntry in ipairs(juwelierSellableItems) do
                if itemEntry.slot == currentSelectedActualSlot then
                    if itemEntry.quantity > 0 then
                        selectedItemToSell = i
                        newQtyForSelectedItem = itemEntry.quantity
                    end
                    break
                end
            end
            if selectedItemToSell then
                local currentInputQty = tonumber(quantityToSellInput) or 1
                if currentInputQty > newQtyForSelectedItem then
                    quantityToSellInput = tostring(newQtyForSelectedItem)
                elseif tonumber(quantityToSellInput) <= 0 and newQtyForSelectedItem > 0 then
                     quantityToSellInput = "1"
                end
                if newQtyForSelectedItem == 0 then
                    selectedItemToSell = nil
                    quantityToSellInput = "1"
                end
            else
                quantityToSellInput = "1"
                if oldSelectedSellIndex then scrollOffset = 0 end
            end
        else
             quantityToSellInput = "1"
             if oldSelectedSellIndex then scrollOffset = 0 end
        end
    end

    if firstOpen then
        showCursor(true)
        guiSetInputMode("no_binds_when_editing")

        if not isJuwelierGuiRenderHandlerActive then
            addEventHandler("onClientRender", root, renderJuwelierSellGUI)
            isJuwelierGuiRenderHandlerActive = true
        end
        if not isJuwelierGuiInputHandlersActive then
            addEventHandler("onClientClick", root, handleJuwelierGUIClick)
            addEventHandler("onClientKey", root, handleJuwelierGUIKey)
            addEventHandler("onClientCharacter", root, handleJuwelierGUICharacter)
            bindKey("mouse_wheel_up", "down", scrollJuwelierListUp)
            bindKey("mouse_wheel_down", "down", scrollJuwelierListDown)
            isJuwelierGuiInputHandlersActive = true
        end
    end
end

function closeJuwelierSellGUI()
    if not isJuwelierGUIVisible then return end
    isJuwelierGUIVisible = false
    if isJuwelierGuiRenderHandlerActive then
        removeEventHandler("onClientRender", root, renderJuwelierSellGUI)
        isJuwelierGuiRenderHandlerActive = false
    end
    if isJuwelierGuiInputHandlersActive then
        removeEventHandler("onClientClick", root, handleJuwelierGUIClick)
        removeEventHandler("onClientKey", root, handleJuwelierGUIKey)
        removeEventHandler("onClientCharacter", root, handleJuwelierGUICharacter)
        unbindKey("mouse_wheel_up", "down", scrollJuwelierListUp)
        unbindKey("mouse_wheel_down", "down", scrollJuwelierListDown)
        isJuwelierGuiInputHandlersActive = false
    end
    showCursor(false)
    guiSetInputMode("allow_binds")
    activeSellInputElement = nil
end

function scrollJuwelierListUp()
    if not isJuwelierGUIVisible then return end
    if #juwelierSellableItems > maxVisibleItemsInList then
        scrollOffset = math.max(0, scrollOffset - 1)
    end
end

function scrollJuwelierListDown()
    if not isJuwelierGUIVisible then return end
    if #juwelierSellableItems > maxVisibleItemsInList then
        scrollOffset = math.min(#juwelierSellableItems - maxVisibleItemsInList, scrollOffset + 1)
    end
end

function handleJuwelierGUIClick(button, state, absX, absY)
    if not isJuwelierGUIVisible or button ~= "left" or state ~= "up" then return end

    local prevActiveInputElement = activeSellInputElement
    activeSellInputElement = nil

    for i = 1, maxVisibleItemsInList do
        local index = i + scrollOffset
        if juwelierSellableItems[index] then
            local itemRowY = itemsStartY + (i-1) * listItemHeight
            if absX >= windowX + listOffsetX and absX <= windowX + listOffsetX + listWidth and absY >= itemRowY and absY <= itemRowY + listItemHeight - itemSlotSpacing then
                selectedItemToSell = index
                quantityToSellInput = "1"
                return
            end
        end
    end

    if selectedItemToSell and juwelierSellableItems[selectedItemToSell] then
        local item = juwelierSellableItems[selectedItemToSell]
        local mengeControlsY_click = currentMengeControlsY
        local mengeLabel_click_text = "Anzahl (Max: " .. item.quantity .. "):"
        local mengeControlsStartX_click_pos = windowX + listOffsetX + 15 + dxGetTextWidth(mengeLabel_click_text, guiFonts.INFO_TEXT_LABEL.scale, guiFonts.INFO_TEXT_LABEL.font) + mengeLabelToControlsSpacing

        local minusButtonX_click_pos = mengeControlsStartX_click_pos
        if absX >= minusButtonX_click_pos and absX <= minusButtonX_click_pos + mengeArrowButtonWidth and absY >= mengeControlsY_click and absY <= mengeControlsY_click + mengeArrowButtonHeight then
            local currentQty = tonumber(quantityToSellInput) or 1
            currentQty = math.max(1, currentQty - 1)
            quantityToSellInput = tostring(currentQty)
            activeSellInputElement = prevActiveInputElement
            return
        end

        local mengeDisplayX_click_pos = minusButtonX_click_pos + mengeArrowButtonWidth + 5
        if absX >= mengeDisplayX_click_pos and absX <= mengeDisplayX_click_pos + mengeInputWidth and absY >= mengeControlsY_click and absY <= mengeControlsY_click + mengeInputHeight then
             activeSellInputElement = "quantity"
             return
        end

        local plusButtonX_click_pos = mengeDisplayX_click_pos + mengeInputWidth + 5
        if absX >= plusButtonX_click_pos and absX <= plusButtonX_click_pos + mengeArrowButtonWidth and absY >= mengeControlsY_click and absY <= mengeControlsY_click + mengeArrowButtonHeight then
            local currentQty = tonumber(quantityToSellInput) or 0
            currentQty = math.min(item.quantity, currentQty + 1)
            quantityToSellInput = tostring(currentQty)
            activeSellInputElement = prevActiveInputElement
            return
        end
    end

    local closeButtonX_click = windowX + windowW - buttonW - 20
    local sellAndCloseButtonY_click = windowY + windowH - buttonH - buttonBottomMargin
    local sellButtonX_click = closeButtonX_click - buttonW - buttonSpacing

    if absX >= closeButtonX_click and absX <= closeButtonX_click + buttonW and absY >= sellAndCloseButtonY_click and absY <= sellAndCloseButtonY_click + buttonH then
        closeJuwelierSellGUI()
        return
    end

    if selectedItemToSell then
        if absX >= sellButtonX_click and absX <= sellButtonX_click + buttonW and absY >= sellAndCloseButtonY_click and absY <= sellAndCloseButtonY_click + buttonH then
            local item = juwelierSellableItems[selectedItemToSell]
            local qty = tonumber(quantityToSellInput)
            if item and qty and qty > 0 and item.slot then
                if qty > item.quantity then
                    outputChatBox("Du kannst nicht mehr verkaufen, als du besitzt (Max: " .. item.quantity .. ").", 255,100,0)
                    quantityToSellInput = tostring(item.quantity)
                else
                    triggerServerEvent("juwelier:sellItem", localPlayer, item.slot, qty)
                end
            else
                outputChatBox("Ungültige Menge oder Itemauswahl.", 255,100,0)
            end
            return
        end
    end
end

function handleJuwelierGUIKey(key, press)
    if not isJuwelierGUIVisible or not press then return end
    if key == "escape" then closeJuwelierSellGUI()
    elseif activeSellInputElement == "quantity" then
        if key == "backspace" then
            quantityToSellInput = string.sub(quantityToSellInput, 1, -2)
            if quantityToSellInput == "" then quantityToSellInput = "0" end
            local numVal = tonumber(quantityToSellInput) or 0
            if selectedItemToSell and juwelierSellableItems[selectedItemToSell] then
                local maxQty = juwelierSellableItems[selectedItemToSell].quantity
                if numVal > maxQty then quantityToSellInput = tostring(maxQty) end
            end
            if numVal < 0 then quantityToSellInput = "0" end
        end
    end
end

function handleJuwelierGUICharacter(char)
    if not isJuwelierGUIVisible or not activeSellInputElement then return end
    if activeSellInputElement == "quantity" then
        if tonumber(char) then
            local newQuantityString = quantityToSellInput
            if quantityToSellInput == "0" and char ~= "0" then newQuantityString = "" end
            newQuantityString = newQuantityString .. char

            if string.len(newQuantityString) <= 7 then
                local numVal = tonumber(newQuantityString)
                if numVal then
                    if selectedItemToSell and juwelierSellableItems[selectedItemToSell] then
                        local maxQty = juwelierSellableItems[selectedItemToSell].quantity
                        if numVal > maxQty then
                            quantityToSellInput = tostring(maxQty)
                        else
                            quantityToSellInput = newQuantityString
                        end
                    else
                        quantityToSellInput = newQuantityString
                    end
                else
                    quantityToSellInput = "0"
                end
            end
        end
    end
end

addEventHandler("juwelier:openSellGUI", root, function(sellableItems)
    openJuwelierSellGUI(sellableItems)
end)

addEventHandler("juwelier:refreshSellGUIData", root, function()
    if isJuwelierGUIVisible then
        triggerServerEvent("juwelier:requestSellGUIData", localPlayer)
    end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    closeJuwelierSellGUI()
end)