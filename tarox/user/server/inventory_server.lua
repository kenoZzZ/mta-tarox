-- tarox/user/server/inventory_server.lua
-- VERSION 1.2: Korrektur in loadPlayerInventory und givePlayerItem für bessere Datenkonsistenz
-- VERSION mit Nicht-Droppen-Logik für Item ID 17 (Ausweis), 18 (Führerschein) und 19 (Handy)

_G.playerInventories = {} -- Globale Tabelle für serverseitigen Cache
local itemDefinitions = {} -- Wird beim Start gefüllt
local MAX_INVENTORY_SLOTS = 15 -- Maximale Anzahl an Inventar-Slots pro Spieler

local clientReadyStatus = {} -- Um zu wissen, wann der Client bereit ist, Updates zu empfangen

-- Cooldowns, um Event-Spam zu verhindern
local actionCooldowns = {}
local USE_ITEM_COOLDOWN = 1000 -- Millisekunden
local DROP_ITEM_COOLDOWN = 500
local MOVE_ITEM_COOLDOWN = 250

local ID_CARD_ITEM_ID_NO_DROP = 17
local DRIVERS_LICENSE_ITEM_ID_NO_DROP = 18 
local HANDY_ITEM_ID_NO_DROP = 19         


-- Event Deklarationen
addEvent("requestItemDefinitions", true)
addEvent("requestInventoryUpdate", true)
addEvent("useInventoryItem", true)
addEvent("dropInventoryItem", true)
addEvent("clientInventoryReady", true)
addEvent("requestMoveItem", true)

-- Client-seitige Events, die hier ausgelöst werden
addEvent("onClientInventoryUpdate", true)
addEvent("onClientReceiveItemDefinitions", true)

-- Funktion zum Laden aller Item-Definitionen aus der Datenbank
local function loadItemDefinitions()
    itemDefinitions = {}
    local result, errMsg = exports.datenbank:queryDatabase("SELECT item_id, name, description, type, max_stack, weight, data, buy_price, sell_price, image_path FROM items")
    if not result then
        outputDebugString("[InventoryServer] FEHLER: Item-Definitionen konnten nicht aus der Datenbank geladen werden: " .. (errMsg or "Unbekannt"))
        return
    end

    if result and type(result) == "table" then
        local count = 0
        for _, row in ipairs(result) do
            local itemIdNum = tonumber(row.item_id)
            if itemIdNum then
                itemDefinitions[itemIdNum] = {
                    name = row.name,
                    description = row.description,
                    type = row.type,
                    max_stack = tonumber(row.max_stack) or 1,
                    weight = tonumber(row.weight) or 0,
                    data = row.data,
                    buy_price = tonumber(row.buy_price),
                    sell_price = tonumber(row.sell_price),
                    imagePath = row.image_path
                }
                count = count + 1
            end
        end
        --outputDebugString("[InventoryServer] " .. count .. " Item-Definitionen geladen.")
    else
        outputDebugString("[InventoryServer] FEHLER: Keine Item-Definitionen aus der Datenbank geladen oder Fehler bei der Abfrage (Result-Typ: "..(type(result))..").")
    end
end

-- Exportierte Funktion, um eine Item-Definition abzurufen
function getItemDefinition(itemId)
    local itemIdNum = tonumber(itemId)
    if not itemIdNum then return nil end
    return itemDefinitions[itemIdNum]
end
exports.tarox.getItemDefinition = getItemDefinition -- Für andere Skripte exportieren

if not table.count then
    function table.count(t)
        local count = 0
        if type(t) == "table" then for _ in pairs(t) do count = count + 1 end end
        return count
    end
end

-- Funktion zum Laden des Inventars eines Spielers
function loadPlayerInventory(player)
    if not isElement(player) then return false, "Invalid player element", nil end
    local accountId = getElementData(player, "account_id")
    if not accountId then
        outputDebugString("[InventoryServer] loadPlayerInventory: Kein AccountID für Spieler " .. getPlayerName(player))
        return false, "No account_id", nil
    end

    local inventoryResult, errMsg = exports.datenbank:queryDatabase("SELECT item_id, quantity, slot, metadata FROM player_inventory WHERE account_id = ?", accountId)

    if not inventoryResult then -- DB Fehler
        outputDebugString("[InventoryServer] DB FEHLER beim Laden des Inventars für Account " .. accountId .. ": " .. (errMsg or "Unbekannt"))
        return false, "Database query error", (_G.playerInventories and _G.playerInventories[player] or nil)
    end

    _G.playerInventories[player] = {} 
    local currentLoadedInventoryForPlayer = _G.playerInventories[player]

    if inventoryResult and type(inventoryResult) == "table" then
        for _, row in ipairs(inventoryResult) do
            local slot = tonumber(row.slot)
            if slot and slot > 0 and slot <= MAX_INVENTORY_SLOTS then
                currentLoadedInventoryForPlayer[slot] = {
                    item_id = tonumber(row.item_id),
                    quantity = tonumber(row.quantity),
                    metadata = row.metadata
                }
            else
                outputDebugString("[InventoryServer] Ungültiger Slot " .. tostring(row.slot) .. " für Account " .. accountId)
            end
        end
        return true, "Success", currentLoadedInventoryForPlayer
    end
    return true, "No items or unexpected result type", currentLoadedInventoryForPlayer
end
_G.loadPlayerInventory = loadPlayerInventory
exports.tarox.loadPlayerInventory = loadPlayerInventory -- Export

-- Funktion zum Speichern des Inventars eines Spielers
function savePlayerInventory(player)
    if not isElement(player) then return false, "Invalid player element" end
    local accountId = getElementData(player, "account_id")
    if not accountId then
        outputDebugString("[InventoryServer] savePlayerInventory: Kein AccountID für Spieler " .. getPlayerName(player))
        return false, "No account_id"
    end

    local inventoryCache = _G.playerInventories[player] -- Direkter Zugriff auf den globalen Cache
    local deleteSuccess, deleteErrMsg = exports.datenbank:executeDatabase("DELETE FROM player_inventory WHERE account_id = ?", accountId)
    if not deleteSuccess then
        outputDebugString("[InventoryServer] DB FEHLER beim Löschen des alten Inventars für Account " .. accountId .. ": " .. (deleteErrMsg or "Unbekannt"))
    end

    if not inventoryCache or table.count(inventoryCache) == 0 then
        return true, "Empty inventory, nothing to save after delete"
    end

    local itemsSavedCount = 0
    local allInsertsSuccessful = true
    for slot, itemData in pairs(inventoryCache) do
        if itemData and itemData.item_id and itemData.quantity and itemData.quantity > 0 and slot then
            local iid = tonumber(itemData.item_id)
            local qty = tonumber(itemData.quantity)
            local slt = tonumber(slot)
            if type(iid) == "number" and type(qty) == "number" and type(slt) == "number" and slt > 0 and slt <= MAX_INVENTORY_SLOTS then
                local metadataToSave = itemData.metadata or nil
                local insertSuccess, insertErrMsg = exports.datenbank:executeDatabase("INSERT INTO player_inventory (account_id, item_id, quantity, slot, metadata) VALUES (?, ?, ?, ?, ?)", accountId, iid, qty, slt, metadataToSave)
                if insertSuccess then
                    itemsSavedCount = itemsSavedCount + 1
                else
                    outputDebugString("[InventoryServer] DB FEHLER beim Speichern von Item (ID: "..iid..", Slot: "..slt..") für Account " .. accountId .. ": " .. (insertErrMsg or "Unbekannt"))
                    allInsertsSuccessful = false
                end
            else
                outputDebugString("[InventoryServer] Fehlerhafte Item-Daten beim Speichern für Slot " .. tostring(slt) .. ", AccID: " .. accountId)
                allInsertsSuccessful = false
            end
        end
    end

    if isElement(player) and clientReadyStatus[player] then
        triggerClientEvent(player, "onClientInventoryUpdate", player, inventoryCache or {})
    end
    return allInsertsSuccessful, (allInsertsSuccessful and "Success" or "Partial or full save error")
end
_G.savePlayerInventory = savePlayerInventory
exports.tarox.savePlayerInventory = savePlayerInventory -- Export

-- Funktion, um einem Spieler ein Item zu geben
function givePlayerItem(player, itemId, quantity, metadata)
    if not isElement(player) or not itemId or not quantity or quantity <= 0 then return false, "Invalid parameters" end
    itemId = tonumber(itemId); quantity = math.floor(tonumber(quantity) or 0)
    if not itemId or not quantity or quantity <= 0 then return false, "Invalid itemId or quantity (numeric)" end

    local itemDef = getItemDefinition(itemId)
    if not itemDef then
        outputDebugString("[InventoryServer] givePlayerItem: Item-Definition für ID " .. itemId .. " nicht gefunden.")
        return false, "Item definition not found"
    end

    local accountId = getElementData(player, "account_id")
    if not accountId then
        outputDebugString("[InventoryServer] givePlayerItem: Kein AccountID für Spieler " .. getPlayerName(player))
        return false, "No account_id"
    end

    local inventory = _G.playerInventories[player] 
    if not inventory then
        inventory = {}
        _G.playerInventories[player] = inventory
    end

    local originalQuantityGiven = quantity
    local remainingQuantity = quantity
    local itemAddedToCache = false

    if itemDef.max_stack > 1 then
        for slot = 1, MAX_INVENTORY_SLOTS do
            if remainingQuantity <= 0 then break end
            local slotData = inventory[slot]
            if slotData and slotData.item_id == itemId and (slotData.metadata == metadata or (not slotData.metadata and not metadata)) and slotData.quantity < itemDef.max_stack then
                local canAdd = itemDef.max_stack - slotData.quantity
                local amountToReallyAdd = math.min(remainingQuantity, canAdd)
                slotData.quantity = slotData.quantity + amountToReallyAdd
                remainingQuantity = remainingQuantity - amountToReallyAdd
                itemAddedToCache = true
            end
        end
    end

    while remainingQuantity > 0 do
        local emptySlot = nil
        for slot = 1, MAX_INVENTORY_SLOTS do
            if not inventory[slot] then emptySlot = slot; break end
        end

        if not emptySlot then
            outputChatBox("Dein Inventar ist voll!", player, 255, 100, 0)
            local message = "Inventory full"
            if remainingQuantity < originalQuantityGiven then
                 outputChatBox("Konnte nicht alle Items (" .. itemDef.name .. ") hinzufügen (" .. remainingQuantity .. " übrig).", player, 255, 165, 0)
                 message = "Partially added, inventory full for rest"
            end
            if itemAddedToCache then
                local savedPartial, savePartialMsg = savePlayerInventory(player) 
                if not savedPartial then outputDebugString("[InventoryServer] givePlayerItem: Fehler beim Speichern des teilw. hinzugefügten Inventars: " .. (savePartialMsg or "Unbekannt")) end
                if isElement(player) and clientReadyStatus[player] then triggerClientEvent(player, "onClientInventoryUpdate", player, inventory) end
            end
            return itemAddedToCache, message
        end

        local amountToPlaceInNewSlot = math.min(remainingQuantity, itemDef.max_stack)
        inventory[emptySlot] = {item_id = itemId, quantity = amountToPlaceInNewSlot, metadata = metadata}
        remainingQuantity = remainingQuantity - amountToPlaceInNewSlot
        itemAddedToCache = true
    end

    if itemAddedToCache then
        local savedToDbSuccess, saveDbMsg = savePlayerInventory(player) -- HIER SPEICHERN
        if not savedToDbSuccess then
            outputDebugString("[InventoryServer] givePlayerItem: FEHLER beim Speichern des Inventars in die DB nach Item-Hinzufügung für AccID " .. accountId .. ": " .. (saveDbMsg or "Unbekannt"))
        end
        if isElement(player) and clientReadyStatus[player] then
            triggerClientEvent(player, "onClientInventoryUpdate", player, inventory)
        end
    end
    return itemAddedToCache, (itemAddedToCache and "Success" or "Failed to add item")
end
exports.tarox.givePlayerItem = givePlayerItem -- Export

-- Funktion, um einem Spieler ein Item aus einem bestimmten Slot zu nehmen
function takePlayerItem(player, slot, quantity)
    if not isElement(player) or not slot or not quantity or quantity <= 0 then return false, "Invalid parameters" end
    slot = tonumber(slot); quantity = math.floor(tonumber(quantity) or 0)
    if not slot or not quantity or quantity <= 0 or slot <= 0 or slot > MAX_INVENTORY_SLOTS then return false, "Invalid slot or quantity" end

    local accountId = getElementData(player, "account_id"); if not accountId then return false, "No account_id" end
    local inventory = _G.playerInventories[player]; 
    if not inventory or not inventory[slot] then return false, "Item not found in slot" end

    local itemData = inventory[slot]
    local itemDef = getItemDefinition(itemData.item_id); if not itemDef then return false, "Item definition not found" end

    if itemData.quantity < quantity then return false, "Not enough quantity" end

    itemData.quantity = itemData.quantity - quantity
    if itemData.quantity <= 0 then
        inventory[slot] = nil 
    end

    local savedToDbSuccess, saveDbMsg = savePlayerInventory(player)
    if not savedToDbSuccess then
        outputDebugString("[InventoryServer] takePlayerItem: FEHLER beim Speichern des Inventars in die DB nach Item-Entnahme für AccID " .. accountId .. ": " .. (saveDbMsg or "Unbekannt"))
    end

    if isElement(player) and clientReadyStatus[player] then
        triggerClientEvent(player, "onClientInventoryUpdate", player, inventory) 
    end
    return true, "Success"
end
exports.tarox.takePlayerItem = takePlayerItem -- Export

function hasPlayerItem(player, itemId, quantity)
     if not isElement(player) or not itemId then return false end
     if not quantity or quantity <= 0 then quantity = 1 end
     itemId = tonumber(itemId); if not itemId then return false end
     quantity = math.floor(tonumber(quantity) or 1)

     local inventory = _G.playerInventories[player];
     if not inventory then return false end

     local function isTableEmpty(t) if not t then return true end return next(t) == nil end
     if isTableEmpty(inventory) then return false end

     local currentCount = 0
     for slot, itemData in pairs(inventory) do
         if itemData and itemData.item_id then
             if tonumber(itemData.item_id) == itemId then
                 currentCount = currentCount + (tonumber(itemData.quantity) or 0)
             end
         end
     end
     return currentCount >= quantity
end
exports.tarox.hasPlayerItem = hasPlayerItem -- Export

function takePlayerItemByID(player, itemId, quantity)
    if not isElement(player) or not itemId or not quantity or quantity <= 0 then return false, "Invalid parameters" end
    itemId = tonumber(itemId); quantity = math.floor(tonumber(quantity) or 0)
    if not itemId or not quantity or quantity <= 0 then return false, "Invalid itemId or quantity" end

    local accountId = getElementData(player, "account_id"); if not accountId then return false, "No account_id" end
    local inventory = _G.playerInventories[player]; if not inventory then return false, "Inventory not loaded" end

    local totalPlayerHas = 0
    for _, currentItemData in pairs(inventory) do
        if currentItemData and currentItemData.item_id == itemId then
            totalPlayerHas = totalPlayerHas + currentItemData.quantity
        end
    end

    if totalPlayerHas < quantity then return false, "Not enough items" end

    local quantityStillToRemove = quantity
    local slotsModified = false

    for slot = 1, MAX_INVENTORY_SLOTS do
        if quantityStillToRemove <= 0 then break end
        local slotData = inventory[slot]
        if slotData and slotData.item_id == itemId then
            local amountToRemoveFromThisSlot = math.min(quantityStillToRemove, slotData.quantity)
            slotData.quantity = slotData.quantity - amountToRemoveFromThisSlot
            quantityStillToRemove = quantityStillToRemove - amountToRemoveFromThisSlot
            slotsModified = true
            if slotData.quantity <= 0 then
                inventory[slot] = nil
            end
        end
    end

    if slotsModified then
        local savedToDbSuccess, saveDbMsg = savePlayerInventory(player)
        if not savedToDbSuccess then
            outputDebugString("[InventoryServer] takePlayerItemByID: FEHLER beim Speichern des Inventars in die DB nach Item-Entnahme für AccID " .. accountId .. ": " .. (saveDbMsg or "Unbekannt"))
        end

        if isElement(player) and clientReadyStatus[player] then
            triggerClientEvent(player, "onClientInventoryUpdate", player, inventory)
        end
    end
    return quantityStillToRemove == 0, (quantityStillToRemove == 0 and "Success" or "Could not remove all items")
end
exports.tarox.takePlayerItemByID = takePlayerItemByID -- Export


function getPlayerItemQuantity(player, itemId)
    if not isElement(player) or not itemId then return 0 end;
    itemId = tonumber(itemId);
    if not itemId then return 0 end

    local inventory = _G.playerInventories[player];
    if not inventory then return 0 end;
    local count = 0
    for slot, itemData in pairs(inventory) do
        if itemData and itemData.item_id == itemId then
            count = count + (tonumber(itemData.quantity) or 0)
        end
    end
    return count
end
exports.tarox.getPlayerItemQuantity = getPlayerItemQuantity -- Export

addEventHandler("requestItemDefinitions", root, function()
    local player = client; if not isElement(player) then return end
    triggerClientEvent(player, "onClientReceiveItemDefinitions", player, itemDefinitions)
end)

addEventHandler("requestInventoryUpdate", root, function()
    local player = client; if not isElement(player) then return end
    if clientReadyStatus[player] then
        triggerClientEvent(player, "onClientInventoryUpdate", player, playerInventories[player] or {})
    end
end)

local function sendInventoryWhenReady(player)
    if not isElement(player) then return end
    local accountId = getElementData(player, "account_id")
    if not accountId then
        setTimer(sendInventoryWhenReady, 500, 1, player)
        return
    end

    clientReadyStatus[player] = true

    local currentInv = _G.playerInventories[player] -- Zugriff auf globalen Cache
    local loadedSuccessfully = true
    local errorMsg = ""
    local invDataToReturn = nil

    if currentInv then
        invDataToReturn = currentInv
    else
        loadedSuccessfully, errorMsg, invDataToReturn = loadPlayerInventory(player) 
        if not loadedSuccessfully then
            outputChatBox("Fehler beim Laden deines Inventars.", player, 255,0,0)
        end
    end
    triggerClientEvent(player, "onClientInventoryUpdate", player, invDataToReturn or {})
end

addEventHandler("clientInventoryReady", root, function()
    local player = source; if not isElement(player) then return end
    sendInventoryWhenReady(player)
end)

addEventHandler("useInventoryItem", root, function(slot)
    local player = client
    if not isElement(player) or not getElementData(player, "account_id") then return end

    if not actionCooldowns[player] then actionCooldowns[player] = {} end
    local lastUse = actionCooldowns[player].useItem or 0
    if (getTickCount() - lastUse) < USE_ITEM_COOLDOWN then
        outputChatBox("Bitte warte kurz, bevor du wieder ein Item benutzt.", player, 255, 150, 0)
        return
    end

    slot = tonumber(slot); if not slot or slot <= 0 or slot > MAX_INVENTORY_SLOTS then return end
    local inventory = _G.playerInventories[player]; if not inventory or not inventory[slot] then return end

    local itemData = inventory[slot]
    local itemDef = getItemDefinition(itemData.item_id)
    if not itemDef then outputDebugString("[InventoryServer] Item-Definition nicht gefunden für ID: "..itemData.item_id); return end

    actionCooldowns[player].useItem = getTickCount()
    outputServerLog(string.format("[ITEM USE DEBUG] Spieler %s benutzt Item %s (ID: %s) aus Slot %s", getPlayerName(player), itemDef.name, tostring(itemData.item_id), tostring(slot)))

    if itemDef.type == "usable" then
        if itemData.item_id == 1 then 
            if isPedDead(player) then
                outputChatBox("Du kannst dies nicht benutzen, während du tot bist.", player, 255, 100, 0)
                return
            end
            local currentHealth = getElementHealth(player)
            local playerMaxHealth = 100
            outputServerLog(string.format("[ITEM USE DEBUG] Verbandskasten: CurrentHP: %s, MaxHP (Standard): %s", tostring(currentHealth), tostring(playerMaxHealth)))

            if currentHealth < playerMaxHealth then
                local healAmount = 30
                if itemDef.data then
                    local jsonData = fromJSON(itemDef.data)
                    if jsonData and jsonData.heal_amount then
                        healAmount = tonumber(jsonData.heal_amount) or healAmount
                    end
                end
                local newHealth = math.min(playerMaxHealth, currentHealth + healAmount)
                local hpBeforeSet_inventory = getElementHealth(player)
                setElementHealth(player, newHealth)
                local hpAfterSet_inventory = getElementHealth(player)
                outputServerLog(string.format("[ITEM USE DEBUG] Verbandskasten: Spieler %s: HP vor setElementHealth: %s, Soll-HP: %s, HP nach setElementHealth: %s", getPlayerName(player), tostring(hpBeforeSet_inventory), tostring(newHealth), tostring(hpAfterSet_inventory)))

                outputChatBox("Verbandskasten benutzt. Gesundheit wiederhergestellt!", player, 0, 200, 100)
                if not takePlayerItem(player, slot, 1) then
                    outputChatBox("Fehler: Verbandskasten konnte nicht aus dem Inventar entfernt werden.", player, 255,0,0)
                    setElementHealth(player, currentHealth)
                end
            else
                outputChatBox("Du hast bereits volle Gesundheit!", player, 255, 165, 0)
            end
        elseif itemData.item_id == 2 then 
            outputChatBox("Du hast eine Wasserflasche getrunken.", player, 100, 150, 255);
            takePlayerItem(player, slot, 1)
        elseif itemData.item_id == HANDY_ITEM_ID_NO_DROP then
            triggerEvent("onPlayerUseHandyItem", player)
        else
            outputChatBox("Das Item '"..itemDef.name.."' hat keine direkte Benutzungsfunktion.", player, 255, 165, 0)
        end
    else
        outputChatBox("Das Item '"..itemDef.name.."' ist nicht als 'benutzbar' klassifiziert.", player, 255, 165, 0)
    end
end)

addEventHandler("dropInventoryItem", root, function(slot, quantity)
    local player = client
    if not isElement(player) or not getElementData(player, "account_id") then return end

    if not actionCooldowns[player] then actionCooldowns[player] = {} end
    local lastDrop = actionCooldowns[player].dropItem or 0
    if (getTickCount() - lastDrop) < DROP_ITEM_COOLDOWN then
        outputChatBox("Bitte warte kurz.", player, 255, 150, 0)
        return
    end

    slot = tonumber(slot); quantity = math.floor(tonumber(quantity) or 1)
    if not slot or slot <= 0 or slot > MAX_INVENTORY_SLOTS then return end
    if not quantity or quantity <= 0 then return end

    local inventory = _G.playerInventories[player]; if not inventory or not inventory[slot] then return end
    local itemData = inventory[slot]
    local itemDef = getItemDefinition(itemData.item_id)
    if not itemDef then return end

    if itemData.item_id == ID_CARD_ITEM_ID_NO_DROP or
       itemData.item_id == DRIVERS_LICENSE_ITEM_ID_NO_DROP or
       itemData.item_id == HANDY_ITEM_ID_NO_DROP then
        outputChatBox("Diesen Gegenstand kannst du nicht fallen lassen.", player, 255, 100, 0)
        return
    end

    quantity = math.min(quantity, itemData.quantity)
    actionCooldowns[player].dropItem = getTickCount()

    if takePlayerItem(player, slot, quantity) then
        outputChatBox(quantity.."x "..itemDef.name.." fallen gelassen.", player, 200,200,200)
    else
        outputChatBox("Fehler beim Fallenlassen des Items.", player, 255,0,0)
    end
end)

addEventHandler("requestMoveItem", root, function(sourceSlot, destinationSlot)
    local player = client
    if not isElement(player) then return end
    local accountId = getElementData(player, "account_id")
    if not accountId then return end

    if not actionCooldowns[player] then actionCooldowns[player] = {} end
    local lastMove = actionCooldowns[player].moveItem or 0
    if (getTickCount() - lastMove) < MOVE_ITEM_COOLDOWN then
        return
    end
    actionCooldowns[player].moveItem = getTickCount()

    sourceSlot = tonumber(sourceSlot); destinationSlot = tonumber(destinationSlot)
    if not sourceSlot or not destinationSlot or sourceSlot < 1 or sourceSlot > MAX_INVENTORY_SLOTS or
       destinationSlot < 1 or destinationSlot > MAX_INVENTORY_SLOTS or sourceSlot == destinationSlot then
        return
    end

    local inventory = _G.playerInventories[player]; if not inventory then return end
    local sourceItem = inventory[sourceSlot]; local destinationItem = inventory[destinationSlot]

    if not sourceItem then return end
    local sourceItemDef = getItemDefinition(sourceItem.item_id); if not sourceItemDef then return end

    if not destinationItem then
        inventory[destinationSlot] = sourceItem
        inventory[sourceSlot] = nil
    else
        local destItemDef = getItemDefinition(destinationItem.item_id); if not destItemDef then return end
        if sourceItem.item_id == destinationItem.item_id and
           (sourceItem.metadata == destinationItem.metadata or (not sourceItem.metadata and not destinationItem.metadata)) and
           sourceItemDef.max_stack > 1 then
            local spaceInDest = destItemDef.max_stack - destinationItem.quantity
            if spaceInDest > 0 then
                local amountToMove = math.min(sourceItem.quantity, spaceInDest)
                destinationItem.quantity = destinationItem.quantity + amountToMove
                sourceItem.quantity = sourceItem.quantity - amountToMove
                if sourceItem.quantity <= 0 then inventory[sourceSlot] = nil end
            else
                inventory[destinationSlot] = sourceItem
                inventory[sourceSlot] = destinationItem
            end
        else
            inventory[destinationSlot] = sourceItem
            inventory[sourceSlot] = destinationItem
        end
    end
    
    -- Nach dem Verschieben im Cache, das Inventar auch in der DB speichern
    local savedSuccess, saveError = savePlayerInventory(player)
    if not savedSuccess then
        outputDebugString("[InventoryServer] requestMoveItem: FEHLER beim Speichern des Inventars nach Item-Verschiebung für AccID " .. accountId .. ": " .. (saveError or "Unbekannt"))
        -- Hier könnte man eine Logik einbauen, um die Verschiebung im Cache rückgängig zu machen,
        -- aber das ist komplexer und für den Moment wird der Client mit dem verschobenen Cache-Stand aktualisiert.
    end

    if clientReadyStatus[player] then
        triggerClientEvent(player, "onClientInventoryUpdate", player, inventory)
    end
end)

addEventHandler("onPlayerLoginSuccess", root, function()
    local player = source
    setTimer(function(p)
        if isElement(p) then
            local loaded, msg, invData = loadPlayerInventory(p)
            if not loaded then
                outputChatBox("Inventar konnte nicht vollständig geladen werden. " .. (msg or ""), p, 255,100,0)
            end
        end
    end, 500, 1, player)
    if not actionCooldowns[player] then actionCooldowns[player] = {} end
    clientReadyStatus[player] = false
end)

addEventHandler("onPlayerQuit", root, function()
    local player = source
    if getElementData(player, "account_id") then
        savePlayerInventory(player)
    end
    if actionCooldowns[player] then actionCooldowns[player] = nil end
    if clientReadyStatus[player] then clientReadyStatus[player] = nil end
    if _G.playerInventories[player] then _G.playerInventories[player] = nil end
end)

addEventHandler("onResourceStart", resourceRoot, function()
    loadItemDefinitions()
    clientReadyStatus = {}
    _G.playerInventories = {} -- Sicherstellen, dass der globale Cache geleert wird
    actionCooldowns = {}
    setTimer(function()
        for _, player in ipairs(getElementsByType("player")) do
            if getElementData(player, "account_id") then
                local loaded, msg, invData = loadPlayerInventory(player)
                if not loaded then
                    outputDebugString("[InventoryServer] onResourceStart: Fehler beim Laden des Inventars für " .. getPlayerName(player) .. ": " .. (msg or "Unbekannt"))
                end
                if not actionCooldowns[player] then actionCooldowns[player] = {} end
                clientReadyStatus[player] = false
            end
        end
    end, 1000, 1)
end)

local SAVE_INTERVAL_MINUTES = 15
setTimer(function()
    --outputDebugString("[InventoryServer] Starte periodisches Speichern aller Inventare...")
    local saveCount = 0
    local errorCount = 0
    for player, _ in pairs(_G.playerInventories) do -- Iteriere über den globalen Cache
        if isElement(player) and getElementData(player, "account_id") then
            local saved, msg = savePlayerInventory(player)
            if saved then
                saveCount = saveCount + 1
            else
                errorCount = errorCount + 1
                outputDebugString("[InventoryServer] Fehler beim periodischen Speichern für "..getPlayerName(player)..": "..(msg or "Unbekannt"))
            end
        else
            _G.playerInventories[player] = nil -- Entferne ungültige Spieler aus dem Cache
            if actionCooldowns[player] then actionCooldowns[player] = nil end
            if clientReadyStatus[player] then clientReadyStatus[player] = nil end
        end
    end
    --outputDebugString("[InventoryServer] " .. saveCount .. " Inventare periodisch gespeichert. " .. errorCount .. " Fehler aufgetreten.")
end, SAVE_INTERVAL_MINUTES * 60 * 1000, 0)

addCommandHandler("gi", function(player, cmd, itemIdStr, quantityStr)
    local adminLevel = getElementData(player, "adminLevel") or 0
    if adminLevel < 1 then
        outputChatBox("Keine Berechtigung für diesen Befehl.", player, 255,0,0)
        return
    end

    local itemId = tonumber(itemIdStr)
    local quantity = tonumber(quantityStr) or 1

    if not itemId then
        outputChatBox("Syntax: /gi <ItemID> [Menge]", player, 200,200,0)
        return
    end
    local itemDefCheck = getItemDefinition(itemId)
    if not itemDefCheck then
        outputChatBox("FEHLER: Item-Definition für ID " .. itemId .. " nicht gefunden!", player, 255, 0, 0)
        return
    end

    local gaveItem, giveMessage = givePlayerItem(player, itemId, quantity, nil) -- Rückgabewerte prüfen
    if gaveItem then 
        outputChatBox("Item '" .. itemDefCheck.name .. "' (x" .. quantity .. ") zum Inventar hinzugefügt.", player, 0, 255, 0)
    else
        outputChatBox("Konnte Item nicht zum Inventar hinzufügen. Grund: "..(giveMessage or "Unbekannt (vielleicht voll?)"), player, 255, 0, 0)
    end
end)

--outputDebugString("[InventoryServer] Inventar-System (Server V1.2 - givePlayerItem speichert nun) geladen.")