-- tarox/inventory/inventory_client.lua
-- VERSION mit Handy-Kontextmenü-Option

addEvent("onClientInventoryUpdate", true)
addEvent("onClientReceiveItemDefinitions", true)

local screenW, screenH = guiGetScreenSize()
local _dxGetTextHeight = dxGetTextHeight
local _dxGetTextWidth = dxGetTextWidth
local _dxDrawRectangle = dxDrawRectangle
local _dxDrawText = dxDrawText

local isInventoryVisible = false
_G.isInventoryVisible = false
local localInventory = {}
local itemDefinitionsClient = {}
local MAX_INVENTORY_SLOTS_CLIENT = 15
local ID_CARD_ITEM_ID_FOR_INVENTORY_ACTION = 17
local DRIVERS_LICENSE_ITEM_ID_FOR_INVENTORY_ACTION = 18
local HANDY_ITEM_ID_FOR_INVENTORY_ACTION = 19 -- Deine Handy Item ID (Beispiel)


local windowWidth, windowHeight = 500, 0
local slotSize = 90; local slotSpacing = 10; local cols = 5
local rows = math.ceil(MAX_INVENTORY_SLOTS_CLIENT / cols)
local inventoryAreaHeight = rows * (slotSize + slotSpacing) - slotSpacing
windowHeight = 50 + inventoryAreaHeight + 50 + 20
local windowX, windowY = (screenW - windowWidth) / 2, (screenH - windowHeight) / 2
local startDrawX = windowX + (windowWidth - (cols * slotSize + (cols - 1) * slotSpacing)) / 2
local startDrawY = windowY + 50

local bgColor = tocolor(30, 30, 35, 220)
local slotColor = tocolor(50, 50, 55, 200)
local textColor = tocolor(220, 220, 220)
local quantityColor = tocolor(200, 200, 50)
local tooltipBgColor = tocolor(0, 0, 0, 210)
local tooltipTextColor = tocolor(255, 255, 255)
local draggingItemColor = tocolor(255,255,255,150)

local hoveredSlot = nil
local isInventoryRenderHandlerActive = false
local isContextMenuRenderHandlerActive = false

local isContextMenuVisible = false
local contextMenuX, contextMenuY = 0, 0
local contextMenuSlot = nil
local contextMenuItems = {}
local contextMenuItemHeight = 28
local contextMenuTextColor = tocolor(245, 245, 245)
local contextMenuItemBg = tocolor(45,45,50,230)
local contextMenuItemHoverBg = tocolor(65,65,70,240)

local isDraggingItem = false
local draggedItemSlot = nil
local draggedItemData = nil
local draggedItemIcon = nil

if not table.count then
    function table.count(t) local count = 0; if type(t) == "table" then for _ in pairs(t) do count = count + 1 end end; return count end
end

addEventHandler("onClientInventoryUpdate", root, function(updatedInventory)
    if type(updatedInventory) == "table" then localInventory = updatedInventory else localInventory = {} end
end)

addEventHandler("onClientReceiveItemDefinitions", root, function(definitions)
     if type(definitions) == "table" then itemDefinitionsClient = definitions; else itemDefinitionsClient = {} end
end)

local function renderContextMenu()
    if not isContextMenuVisible then return end
    local mouseX, mouseY = getCursorPosition(); if not mouseX then return end; mouseX = mouseX * screenW; mouseY = mouseY * screenH

    local menuWidth = 170
    local menuHeight = #contextMenuItems * contextMenuItemHeight + 10

    local drawMenuX = contextMenuX; local drawMenuY = contextMenuY
    if drawMenuX + menuWidth > screenW then drawMenuX = screenW - menuWidth end
    if drawMenuY + menuHeight > screenH then drawMenuY = screenH - menuHeight end
    if drawMenuX < 0 then drawMenuX = 0 end; if drawMenuY < 0 then drawMenuY = 0 end

    _dxDrawRectangle(drawMenuX, drawMenuY, menuWidth, menuHeight, tocolor(30,30,35,245), true)

    local itemY = drawMenuY + 5
    for i, item in ipairs(contextMenuItems) do
        local itemX = drawMenuX + 5; local itemW = menuWidth - 10
        local currentItemBg = contextMenuItemBg
        if mouseX >= itemX and mouseX <= itemX + itemW and mouseY >= itemY and mouseY <= itemY + contextMenuItemHeight then
            currentItemBg = contextMenuItemHoverBg
        end
        _dxDrawRectangle(itemX, itemY, itemW, contextMenuItemHeight, currentItemBg, true)
        _dxDrawText(item.text, itemX + 8, itemY, itemX + itemW - 8, itemY + contextMenuItemHeight, contextMenuTextColor, 1.0, "default", "left", "center", false, false, true, false)
        itemY = itemY + contextMenuItemHeight
    end
end

local function renderInventoryGUI()
    if not isInventoryVisible then return end
    _dxDrawRectangle(windowX, windowY, windowWidth, windowHeight, bgColor)
    _dxDrawText("Inventar", windowX, windowY + 5, windowX + windowWidth, windowY + 40, textColor, 1.4, "default-bold", "center", "top")

    hoveredSlot = nil
    local mouseX, mouseY = getCursorPosition(); if not mouseX then return end; mouseX = mouseX * screenW; mouseY = mouseY * screenH

    for i = 1, MAX_INVENTORY_SLOTS_CLIENT do
        local row = math.floor((i-1)/cols); local col = (i-1)%cols
        local slotX = startDrawX + col * (slotSize+slotSpacing); local slotY = startDrawY + row * (slotSize+slotSpacing)
        local isHovering = false
        if not isContextMenuVisible and not isDraggingItem and mouseX >= slotX and mouseX <= slotX + slotSize and mouseY >= slotY and mouseY <= slotY + slotSize then
            hoveredSlot = i; isHovering = true
        end
        local currentSlotColor = isHovering and tocolor(70,70,75,210) or slotColor
        if isDraggingItem and i == draggedItemSlot then currentSlotColor = tocolor(90,90,60,220) end

        _dxDrawRectangle(slotX, slotY, slotSize, slotSize, currentSlotColor)
        _dxDrawRectangle(slotX, slotY, slotSize, slotSize, tocolor(255,255,255,15), true)
        _dxDrawText(tostring(i), slotX+3, slotY+3, slotX+slotSize, slotY+18, tocolor(100,100,100,180), 0.7, "default", "left", "top")

        local itemData = localInventory[i]
        if itemData and itemData.item_id and itemData.quantity > 0 then
            local itemDef = itemDefinitionsClient[tonumber(itemData.item_id)]
            local itemName = itemDef and itemDef.name or "ID: "..itemData.item_id

            if not (isDraggingItem and i == draggedItemSlot) then
                if itemDef and itemDef.imagePath and fileExists(itemDef.imagePath) then
                    local imageDrawSize = 64
                    local imgX = slotX + (slotSize-imageDrawSize)/2
                    local imgY = slotY + 5
                    dxDrawImage(imgX, imgY, imageDrawSize, imageDrawSize, itemDef.imagePath, 0,0,0, tocolor(255,255,255,255), false)
                end
                local namePosX = slotX+5; local namePosY = slotY+slotSize-25; local nameWidth = slotSize-10; local nameHeight = 20
                _dxDrawText(itemName, namePosX, namePosY, namePosX+nameWidth, namePosY+nameHeight, textColor, 1.0, "default", "center", "bottom", true, true, false, true)

                if itemData.quantity > 1 then
                    local quantityPosX = slotX + (slotSize/2); local quantityPosY = slotY+3; local quantityWidth = (slotSize/2)-8
                    _dxDrawText("x"..itemData.quantity, quantityPosX, quantityPosY, quantityPosX+quantityWidth, quantityPosY+20, quantityColor, 0.9, "default-bold", "right", "top",false,false,false,true)
                end
            end
        else
            _dxDrawText("-", slotX, slotY, slotX+slotSize, slotY+slotSize, tocolor(100,100,100,50), 2.0, "default-bold", "center", "center")
        end
    end

    if hoveredSlot and not isContextMenuVisible and not isDraggingItem then
        local itemData = localInventory[hoveredSlot]
        if itemData and itemData.item_id then
            local itemDef = itemDefinitionsClient[tonumber(itemData.item_id)]
            if itemDef then
                local tooltipText = itemDef.name .. (itemDef.description and "\n"..itemDef.description or "")
                local tipPad = 10; local availW = windowWidth-20; local fontS = 1.0; local fontN = "default"; local textH = 0

                if type(_dxGetTextHeight)=="function" then
                    textH = _dxGetTextHeight(tooltipText, availW, fontS, fontN);
                    if not textH or textH==0 then
                        local lc=1; for _ in string.gmatch(tooltipText,"\n") do lc=lc+1 end;
                        textH = lc * (dxGetFontHeight and dxGetFontHeight(fontS,fontN) or 12)
                    end
                else
                    local lc=1; for _ in string.gmatch(tooltipText,"\n") do lc=lc+1 end; textH = lc*15
                end

                local textW = 0
                if type(_dxGetTextWidth)=="function" then
                    local lns={}; for l in string.gmatch(tooltipText,"[^\n]+") do table.insert(lns,l) end;
                    for _,l in ipairs(lns) do textW=math.max(textW,_dxGetTextWidth(l,fontS,fontN)) end
                else
                    local lns={}; for l in string.gmatch(tooltipText,"[^\n]+") do table.insert(lns,l) end;
                    local maxL=0; for _,l in ipairs(lns) do if string.len(l)>maxL then maxL=string.len(l) end end; textW=maxL*7
                end

                local tipW = math.min(availW, textW)+tipPad; local tipH = textH+tipPad
                local tipX = mouseX+15; local tipY = mouseY+5
                if tipX+tipW > screenW then tipX = screenW-tipW end; if tipX < 0 then tipX=0 end
                if tipY+tipH > screenH then tipY = mouseY-tipH-5 end; if tipY < 0 then tipY=0 end

                _dxDrawRectangle(tipX, tipY, tipW, tipH, tooltipBgColor)
                _dxDrawText(tooltipText, tipX+(tipPad/2), tipY+(tipPad/2), tipX+tipW-(tipPad/2), tipY+tipH-(tipPad/2), tooltipTextColor, fontS, fontN, "left","top", true,false,false,true)
            end
        end
    end

    if isDraggingItem and draggedItemIcon and fileExists(draggedItemIcon) then
        local dragIconSize = slotSize*0.7
        dxDrawImage(mouseX-dragIconSize/2, mouseY-dragIconSize/2, dragIconSize, dragIconSize, draggedItemIcon, 0,0,0, draggingItemColor)
        if draggedItemData and draggedItemData.quantity > 1 then
             _dxDrawText("x"..draggedItemData.quantity, mouseX+dragIconSize/2-15, mouseY+dragIconSize/2-15, mouseX+dragIconSize/2+15, mouseY+dragIconSize/2+5, quantityColor,0.8,"default-bold")
        end
    end

    local closeBtnW,closeBtnH=80,30; local closeBtnX,closeBtnY = windowX+windowWidth-closeBtnW-10, windowY+windowHeight-closeBtnH-10
    _dxDrawRectangle(closeBtnX,closeBtnY,closeBtnW,closeBtnH,tocolor(200,50,50,200))
    _dxDrawText("Close",closeBtnX,closeBtnY,closeBtnX+closeBtnW,closeBtnY+closeBtnH,textColor,1.0,"default-bold","center","center",false,false,false,true)
end

function toggleInventoryGUI(keepCursor)
    if not getElementData(localPlayer, "account_id") then
        if isInventoryVisible then
            isInventoryVisible=false; _G.isInventoryVisible = false;
            if not keepCursor then showCursor(false); guiSetInputMode("allow_binds"); end
            if isInventoryRenderHandlerActive then removeEventHandler("onClientRender",root,renderInventoryGUI); isInventoryRenderHandlerActive=false end;
            closeContextMenu();
            cancelItemDrag()
        end
        return
    end

    isInventoryVisible = not isInventoryVisible;
    _G.isInventoryVisible = isInventoryVisible

    closeContextMenu();
    cancelItemDrag()

    if isInventoryVisible then
        showCursor(true);
        guiSetInputMode("no_binds_when_editing");
        if not isInventoryRenderHandlerActive then
            addEventHandler("onClientRender",root,renderInventoryGUI);
            isInventoryRenderHandlerActive=true
        end;
        triggerServerEvent("requestItemDefinitions",localPlayer);
        triggerServerEvent("requestInventoryUpdate",localPlayer)
    else
        if not keepCursor then
            showCursor(false);
            guiSetInputMode("allow_binds");
        end
        if isInventoryRenderHandlerActive then
            removeEventHandler("onClientRender",root,renderInventoryGUI);
            isInventoryRenderHandlerActive=false
        end
    end
end
local function defaultToggleInventory()
    toggleInventoryGUI(false)
end
bindKey("i", "down", defaultToggleInventory)


function closeContextMenu()
    if not isContextMenuVisible then return end; isContextMenuVisible=false; contextMenuSlot=nil; contextMenuItems={}
    if isContextMenuRenderHandlerActive then removeEventHandler("onClientRender",root,renderContextMenu); isContextMenuRenderHandlerActive=false end
end

function cancelItemDrag() isDraggingItem=false; draggedItemSlot=nil; draggedItemData=nil; draggedItemIcon=nil end

addEventHandler("onClientClick", root, function(button, state, absX, absY)
    if not isInventoryVisible then return end

    local mouseX,mouseY = getCursorPosition(); if not mouseX then return end
    mouseX=mouseX*screenW; mouseY=mouseY*screenH

    if button == "right" and state == "down" then
        if isDraggingItem then cancelItemDrag(); return end
        closeContextMenu()
        local clickedSlot = nil
        for i=1,MAX_INVENTORY_SLOTS_CLIENT do
            local r=math.floor((i-1)/cols); local c=(i-1)%cols
            local sX=startDrawX+c*(slotSize+slotSpacing); local sY=startDrawY+r*(slotSize+slotSpacing)
            if absX>=sX and absX<=sX+slotSize and absY>=sY and absY<=sY+slotSize then
                clickedSlot=i; break
            end
        end
        if clickedSlot and localInventory[clickedSlot] then
            contextMenuSlot=clickedSlot; contextMenuItems={};
            local itemData = localInventory[clickedSlot]; local itemDef = itemDefinitionsClient[tonumber(itemData.item_id)]
            if itemDef then
                if itemDef.type=="usable" then table.insert(contextMenuItems,{text="Benutzen",action="use"}) end
                if itemDef.type=="weapon" then table.insert(contextMenuItems,{text="Ausrüsten",action="equip"}) end

                if tonumber(itemData.item_id) == ID_CARD_ITEM_ID_FOR_INVENTORY_ACTION then
                    table.insert(contextMenuItems, {text = "Ausweis ansehen", action = "idcard_view_self"})
                elseif tonumber(itemData.item_id) == DRIVERS_LICENSE_ITEM_ID_FOR_INVENTORY_ACTION then
                    table.insert(contextMenuItems, {text = "Führerschein ansehen", action = "drivelicense_view_self"})
                elseif tonumber(itemData.item_id) == HANDY_ITEM_ID_FOR_INVENTORY_ACTION then -- NEUE ABFRAGE FÜR HANDY
                    table.insert(contextMenuItems, {text = "Handy öffnen", action = "use_handy"}) -- Nutzt dieselbe Action wie oben
                end

                table.insert(contextMenuItems,{text="Verschieben",action="start_drag"})
                if tonumber(itemData.item_id) ~= ID_CARD_ITEM_ID_FOR_INVENTORY_ACTION and
                   tonumber(itemData.item_id) ~= DRIVERS_LICENSE_ITEM_ID_FOR_INVENTORY_ACTION and
                   tonumber(itemData.item_id) ~= HANDY_ITEM_ID_FOR_INVENTORY_ACTION then -- Auch Handy nicht droppen (konsistent mit Server)
                    table.insert(contextMenuItems,{text="Fallen lassen",action="drop"})
                end
            end
            if #contextMenuItems > 0 then
                contextMenuX,contextMenuY=absX,absY; isContextMenuVisible=true
                if not isContextMenuRenderHandlerActive then addEventHandler("onClientRender",root,renderContextMenu); isContextMenuRenderHandlerActive=true end
            end
        end
        return
    end

    if button == "left" and state == "up" then
        if isContextMenuVisible then
            local menuWidth=170; local drawMenuX=contextMenuX; local drawMenuY=contextMenuY; local menuHeight = #contextMenuItems*contextMenuItemHeight+10
            if drawMenuX+menuWidth>screenW then drawMenuX=screenW-menuWidth end; if drawMenuY+menuHeight>screenH then drawMenuY=screenH-menuHeight end
            if drawMenuX<0 then drawMenuX=0 end; if drawMenuY<0 then drawMenuY=0 end
            local clickedOnMenuItem = false
            for i,itemAction in ipairs(contextMenuItems) do
                 local itemX=drawMenuX+5; local itemW=menuWidth-10; local currentItemY=drawMenuY+5+(i-1)*contextMenuItemHeight
                 if absX>=itemX and absX<=itemX+itemW and absY>=currentItemY and absY<=currentItemY+contextMenuItemHeight then
                     if itemAction.action=="use" then triggerServerEvent("useInventoryItem",localPlayer,contextMenuSlot)
                     elseif itemAction.action=="drop" then triggerServerEvent("dropInventoryItem",localPlayer,contextMenuSlot,1)
                     elseif itemAction.action=="equip" then outputChatBox("Ausrüsten-Funktion noch nicht implementiert.",255,165,0)
                     elseif itemAction.action=="start_drag" then
                         if localInventory[contextMenuSlot] then
                             isDraggingItem=true; draggedItemSlot=contextMenuSlot; draggedItemData=localInventory[contextMenuSlot]
                             local def = itemDefinitionsClient[tonumber(draggedItemData.item_id)]; draggedItemIcon = def and def.imagePath or nil
                         end
                     elseif itemAction.action == "idcard_view_self" then
                         --outputDebugString("[InvClient] Aktion 'idcard_view_self' für Slot " .. tostring(contextMenuSlot) .. " ausgewählt.")
                         triggerServerEvent("idcard:requestShowSelf", localPlayer, contextMenuSlot)
                         toggleInventoryGUI(true)
                     elseif itemAction.action == "drivelicense_view_self" then
                         --outputDebugString("[InvClient] Aktion 'drivelicense_view_self' für Slot " .. tostring(contextMenuSlot) .. " ausgewählt.")
                         triggerServerEvent("drivelicense:requestShowSelf", localPlayer, contextMenuSlot)
                         toggleInventoryGUI(true)
                     elseif itemAction.action == "use_handy" then -- NEUE AKTION VERARBEITEN
                         --outputDebugString("[InvClient] Aktion 'use_handy' für Slot " .. tostring(contextMenuSlot) .. " ausgewählt.")
                         triggerServerEvent("onPlayerUseHandyItem", localPlayer) -- Trigger das Server-Event
                         -- toggleInventoryGUI(false) -- Inventar nach Handy-Öffnung schließen (optional)
                     end
                     clickedOnMenuItem = true; break
                 end
            end
            closeContextMenu()
            if clickedOnMenuItem then return end
        end

        if isDraggingItem then
            local targetSlot=nil
            for i=1,MAX_INVENTORY_SLOTS_CLIENT do
                local r=math.floor((i-1)/cols); local c=(i-1)%cols
                local sX=startDrawX+c*(slotSize+slotSpacing); local sY=startDrawY+r*(slotSize+slotSpacing)
                if absX>=sX and absX<=sX+slotSize and absY>=sY and absY<=sY+slotSize then targetSlot=i; break end
            end
            if targetSlot then triggerServerEvent("requestMoveItem", localPlayer, draggedItemSlot, targetSlot) end
            cancelItemDrag(); return
        end

        local cBW,cBH=80,30; local cBX,cBY=windowX+windowWidth-cBW-10,windowY+windowHeight-cBH-10
        if absX>=cBX and absX<=cBX+cBW and absY>=cBY and absY<=cBY+cBH then
            toggleInventoryGUI(false); return
        end
    end
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    if _G.isInventoryVisible == nil then _G.isInventoryVisible = false end
    setTimer(function() if isElement(localPlayer) then triggerServerEvent("clientInventoryReady",localPlayer) end end,1000,1)
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if isInventoryVisible then toggleInventoryGUI(false) end
    unbindKey("i","down",defaultToggleInventory)
    if isInventoryRenderHandlerActive then removeEventHandler("onClientRender",root,renderInventoryGUI); isInventoryRenderHandlerActive=false end
    if isContextMenuRenderHandlerActive then removeEventHandler("onClientRender",root,renderContextMenu); isContextMenuRenderHandlerActive=false end
    cancelItemDrag()
end)

--outputDebugString("[InvClient] Inventar Client-Skript (V11f - Handy Kontextmenü) geladen.")