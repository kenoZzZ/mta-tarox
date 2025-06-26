-- drogensystem/drogen_server_new.lua
-- ERWEITERT: Drogen-Verkaufs-Ped Logik (basierend auf Juwelier-System)
-- KORRIGIERT: Fehlendes cancelEvent() im onClientRequestsPedAction Handler
-- MODIFIZIERT: Unterstützung für mehrere Drogen-Verkaufs-Peds
-- ERWEITERT FÜR SAMENVERKAUF: Logik für Samen-Verkäufer-Peds hinzugefügt.
-- MODIFIZIERT V6 (AI): Implementiert GUI-Öffnung auch wenn keine Ware da ist, mit Restock-Timer.
-- MODIFIZIERT V7 (AI): Live-Aktualisierung des Kauf-GUIs bei Bestandsänderungen (Ausverkauf/Restock).
-- MODIFIZIERT FÜR ANIMATION (AI): Pflanz-Befehl löst Animation aus, eigentliche Logik in neuem Event.
-- KORRIGIERT (AI): Fehlerhaften Funktionsaufruf 'getPlayerFromAccount' zu 'getAccountPlayer' geändert.

-- Konfiguration der Drogenarten (bestehend)
local drugTypes = {
    cannabis = {
        plantModel = 3409,
        seedItemId = 20,      -- Item ID für Cannabis Samen
        rawDrugItemId = 21,   -- Item ID für Rohe Cannabisblätter
        rawDrugName = "Rohe Cannabisblätter",
        growthTime = 30,      -- Sekunden bis zur Reife
        harvestWindow = 30,   -- Sekunden zum Ernten nach der Reife
        minYield = 1,
        maxYield = 2,
        startScale = 0.2,
        endScale = 1.0,
        plantDisplayName = "Cannabis Pflanze"
    },
    koka = {
        plantModel = 753,
        seedItemId = 22,      -- Item ID für Koka Setzling
        rawDrugItemId = 23,   -- Item ID für Rohe Kokablätter
        rawDrugName = "Rohe Kokablätter",
        growthTime = 30,
        harvestWindow = 30,
        minYield = 1,
        maxYield = 2,
        startScale = 0.2,
        endScale = 1.0,
        plantDisplayName = "Koka Strauch"
    }
}

local activePlants = {}
local nextPlantUID = 1
local PLANT_OBJECT_MARKER = "drogenSystemPlantObject"

-- Drogen-Verkaufs-Ped Konfiguration (bestehend)
local DROGEN_VERKAUFS_PED_BASIS_IDENTIFIER = "drogen_verkaufs_ped"
local aktiveDrogenVerkaufsPeds = {}

local DROGEN_VERKAUFS_PED_CONFIGS = {
    { model = 120, pos = {x = -2445.43726, y = -47.41283, z = 34.26562, rot = 90} },
    { model = 22, pos = {x = -1786.02405, y = 1429.24329, z = 7.18750, rot = 180} },
    { model = 72,  pos = {x = -2291.88013, y = 730.98798, z = 49.44250, rot = 180} },
	{ model = 23,  pos = {x = 1504.77576, y = 2304.79028, z = 10.82031, rot = 0} },
	{ model = 24,  pos = {x = 2488.28662, y = 1444.53015, z = 10.90625, rot = 270} },
	{ model = 25,  pos = {x = 1633.59290, y = 1074.18066, z = 10.82031, rot = 180} },
	{ model = 21,  pos = {x = 2480.06812, y = -1757.70557, z = 13.54688, rot = 0} },
	{ model = 20,  pos = {x = 1113.13525, y = -1024.66418, z = 31.89226, rot = 180} },
	{ model = 23,  pos = {x = 1753.49194, y = -1943.75720, z = 13.56912, rot = 180} },
}

local VERKAUFBARE_DROGEN_ITEM_IDS = {
    [21] = true, -- Rohe Cannabisblätter
    [23] = true  -- Rohe Kokablätter
}

-- Konfiguration für Samenverkäufer
local SAMEN_VERKAUFS_PED_IDENTIFIER = "drogen_samen_verkaufs_ped"
local SAMEN_ITEM_IDS = { 20, 22 }
local pedSeedInventories = {}
local SEED_RESTOCK_INTERVAL_MS = 1 * 60 * 1000 -- 1 Minute
local nextSeedRestockTime = 0
local playersInteractingWithSeedPeds = {} -- NEU: Tabelle für Live-Updates

local function logError(message)
    outputServerLog("[DrogenSERVER-NEW] ERROR: " .. tostring(message))
end

-----------------------------------------------------------------------------------------
--- ANFANG: VERÄNDERTE PFLANZ-FUNKTIONEN
-----------------------------------------------------------------------------------------

-- Der Befehl "/pflanze" startet nur noch die Überprüfungen und löst die Animation aus.
addCommandHandler("pflanze", function(player, command, drugKey)
    if not player or not drugKey then
        outputChatBox("Verwendung: /pflanze [cannabis|koka]", player, 255, 100, 0)
        return
    end

    if getElementInterior(player) ~= 0 then
        outputChatBox("Du kannst hier drinnen keine Drogen anpflanzen.", player, 255, 100, 0)
        return
    end

    drugKey = string.lower(drugKey)
    local drugConfig = drugTypes[drugKey]

    if not drugConfig then
        outputChatBox("Unbekannte Drogenart. Verfügbar: cannabis, koka", player, 255, 100, 0)
        return
    end

    local hasSeed, errMsg = exports.tarox:hasPlayerItem(player, drugConfig.seedItemId, 1)
    if errMsg then
        outputChatBox("Fehler beim Zugriff auf dein Inventar.", player, 255, 0, 0)
        return
    end
    if not hasSeed then
        outputChatBox("Du besitzt keine ".. drugConfig.plantDisplayName .." Samen um diese Pflanze anzubauen.", player, 255, 100, 0)
        return
    end

    -- Alle Prüfungen bestanden, starte die Animation auf dem Client (3 Sekunden)
    triggerClientEvent(player, "drogensystem:startPlantingAnimation", player, drugKey, 3000)
end)

-- Dieses neue Event wird vom Client ausgelöst, NACHDEM die Animation beendet ist.
addEvent("drogensystem:onClientFinishedPlanting", true)
addEventHandler("drogensystem:onClientFinishedPlanting", root, function(drugKey)
    local player = client
    if not isElement(player) or not drugKey then return end

    local drugConfig = drugTypes[drugKey]
    if not drugConfig then return end

    -- Erneute Prüfung, ob der Spieler die Samen noch hat.
    local hasSeed, _ = exports.tarox:hasPlayerItem(player, drugConfig.seedItemId, 1)
    if not hasSeed then
        -- Der Spieler hat die Samen nicht mehr, keine Aktion nötig.
        return
    end

    -- Samen aus dem Inventar nehmen
    local tookSeed, takeErrMsg = exports.tarox:takePlayerItemByID(player, drugConfig.seedItemId, 1)
    if not tookSeed then
        outputChatBox("Fehler: Saatgut konnte nicht aus dem Inventar entfernt werden.", player, 255, 0, 0)
        return
    end

    -- Pflanze in der Welt erstellen (die eigentliche Logik von vorher)
    local posX, posY, posZ = getElementPosition(player)
    local rotX, rotY, rotZ = getElementRotation(player)
    local offset = 0.8
    local plantX = posX + offset * math.cos(math.rad(rotZ + 90))
    local plantY = posY + offset * math.sin(math.rad(rotZ + 90))
    local plantZ = posZ - 0.9

    local plantObject = createObject(drugConfig.plantModel, plantX, plantY, plantZ, 0, 0, math.random(0, 360))
    if not plantObject then
        outputChatBox("Fehler: Die Pflanze konnte nicht platziert werden.", player, 255, 0, 0)
        -- WICHTIG: Gib die Samen zurück, da die Pflanze nicht erstellt werden konnte!
        exports.tarox:givePlayerItem(player, drugConfig.seedItemId, 1)
        return
    end

    setElementFrozen(plantObject, true)
    setObjectScale(plantObject, drugConfig.startScale)
    local plantUID = nextPlantUID; nextPlantUID = nextPlantUID + 1
    local plantData = {
        uid = plantUID, object = plantObject, drugKey = drugKey, ownerAccount = getAccountName(getPlayerAccount(player)),
        spawnTime = getTickCount(), isMature = false, growthTimer = nil, despawnTimer = nil, currentScale = drugConfig.startScale
    }
    activePlants[plantUID] = plantData
    setElementData(plantObject, PLANT_OBJECT_MARKER, plantUID, true)
    setElementData(plantObject, "drogenPlantReif", false, true)

    outputChatBox(drugConfig.plantDisplayName .. " gepflanzt.", player, 0, 200, 50)

    plantData.growthTimer = setTimer(function(pUID)
        local pData = activePlants[pUID]
        if not pData or not isElement(pData.object) then
            if pData and pData.growthTimer and isTimer(pData.growthTimer) then killTimer(pData.growthTimer) end
            if pData and pData.despawnTimer and isTimer(pData.despawnTimer) then killTimer(pData.despawnTimer) end
            if pData then activePlants[pUID] = nil end
            return
        end
        pData.isMature = true
        setObjectScale(pData.object, drugConfig.endScale)
        setElementData(pData.object, "drogenPlantReif", true, true)
        
        --- HIER WAR DER FEHLER ---
        -- KORRIGIERT: 'getPlayerFromAccount' existiert nicht, 'getAccountPlayer' ist korrekt.
        local ownerPlayer = getAccountPlayer(getAccount(pData.ownerAccount))
        if ownerPlayer then 
            outputChatBox("Deine ".. drugConfig.plantDisplayName .. " ist jetzt erntereif!", ownerPlayer, 50, 200, 50) 
        end
        --- ENDE DER KORREKTUR ---

        pData.despawnTimer = setTimer(function(pUID_despawn)
            local pData_despawn = activePlants[pUID_despawn]
            if pData_despawn then if isElement(pData_despawn.object) then destroyElement(pData_despawn.object) end
                activePlants[pUID_despawn] = nil
            end
        end, drugConfig.harvestWindow * 1000, 1, pUID)
    end, drugConfig.growthTime * 1000, 1, plantUID)
end)

-----------------------------------------------------------------------------------------
--- ENDE: VERÄNDERTE PFLANZ-FUNKTIONEN
-----------------------------------------------------------------------------------------


-- Bestehende Erntefunktion (unverändert)...
addEvent("drogensystem:harvestPlant", true)
addEventHandler("drogensystem:harvestPlant", root, function(plantUID)
    local player = client
    if not isElement(player) then return end
    local plantData = activePlants[plantUID]
    if not plantData then outputChatBox("Diese Pflanze existiert nicht mehr.", player, 255, 100, 0); return end
    if getAccountName(getPlayerAccount(player)) ~= plantData.ownerAccount then outputChatBox("Das ist nicht deine Pflanze!", player, 255, 100, 0); return end
    if not plantData.isMature then outputChatBox("Diese Pflanze ist noch nicht erntereif.", player, 255, 100, 0); return end
    if not isElement(plantData.object) then
        outputChatBox("Fehler beim Ernten.", player, 255, 0, 0)
        if plantData.growthTimer and isTimer(plantData.growthTimer) then killTimer(plantData.growthTimer) end
        if plantData.despawnTimer and isTimer(plantData.despawnTimer) then killTimer(plantData.despawnTimer) end
        activePlants[plantUID] = nil; return
    end
    local drugConfig = drugTypes[plantData.drugKey]
    local yield = math.random(drugConfig.minYield, drugConfig.maxYield)
    local gaveItem, giveMsg = exports.tarox:givePlayerItem(player, drugConfig.rawDrugItemId, yield)
    if gaveItem then
        outputChatBox("Du hast " .. yield .. "x " .. drugConfig.rawDrugName .. " geerntet!", player, 0, 200, 50)
        if isTimer(plantData.growthTimer) then killTimer(plantData.growthTimer) end
        if isTimer(plantData.despawnTimer) then killTimer(plantData.despawnTimer) end
        if isElement(plantData.object) then destroyElement(plantData.object) end
        activePlants[plantUID] = nil
    else
        outputChatBox("Fehler beim Hinzufügen der Ernte zum Inventar: " .. (giveMsg or "Unbekannt"), player, 255, 0, 0)
    end
end)


-- Bestehende Funktion zum Erstellen der Verkaufs-Peds (unverändert)
function createDrogenVerkaufsPeds()
    for _, pedElement in ipairs(aktiveDrogenVerkaufsPeds) do
        if isElement(pedElement) then destroyElement(pedElement) end
    end
    aktiveDrogenVerkaufsPeds = {}

    for i, config in ipairs(DROGEN_VERKAUFS_PED_CONFIGS) do
        local ped = createPed(config.model, config.pos.x, config.pos.y, config.pos.z, config.pos.rot)
        if isElement(ped) then
            setElementFrozen(ped, true)
            setElementData(ped, "pedIdentifier", DROGEN_VERKAUFS_PED_BASIS_IDENTIFIER, true)
            setElementData(ped, "isClickablePed", true, true)
            setElementData(ped, "pedName", "Drogenhändler", true)
            setElementData(ped, "isTaroxPed", true, true)
            table.insert(aktiveDrogenVerkaufsPeds, ped)
        else
            logError("Drogen-Verkaufs-Ped #" .. i .. " konnte NICHT erstellt werden!")
        end
    end
end

-- Funktion zur Aktualisierung des Inventars der Samenverkäufer
function updateSeedPedInventories()
    local peds = getElementsByType("ped")
    for _, ped in ipairs(peds) do
        if getElementData(ped, "pedIdentifier") == SAMEN_VERKAUFS_PED_IDENTIFIER then
            local randomSeedId = SAMEN_ITEM_IDS[math.random(#SAMEN_ITEM_IDS)]
            local randomQuantity = math.random(1, 15)
            pedSeedInventories[ped] = {
                itemID = randomSeedId,
                quantity = randomQuantity
            }
        end
    end
    nextSeedRestockTime = getTickCount() + SEED_RESTOCK_INTERVAL_MS

    -- NEU: Spieler benachrichtigen, die auf Ware warten
    for player, interactingPed in pairs(playersInteractingWithSeedPeds) do
        if isElement(player) and isElement(interactingPed) then
            local newInventory = pedSeedInventories[interactingPed]
            if newInventory and newInventory.quantity > 0 then
                 local itemDef = exports.tarox:getItemDefinition(newInventory.itemID)
                 if itemDef then
                      local dataForClient = {
                           hasStock = true,
                           ped = interactingPed,
                           itemID = newInventory.itemID,
                           itemName = itemDef.name,
                           itemPrice = itemDef.buy_price,
                           stock = newInventory.quantity,
                           imagePath = itemDef.imagePath
                      }
                      triggerClientEvent(player, "drogensystem:openSeedBuyGUI", player, dataForClient)
                 end
            end
        end
    end
end

-- Event-Handler für Ped-Klicks (erweitert und mit Priorität)
addEventHandler("onClientRequestsPedAction", root, function(clickedPedElement, clientClickId)
    local player = client
    if not isElement(player) or not isElement(clickedPedElement) then return end
    local pedId = getElementData(clickedPedElement, "pedIdentifier")
    
    if pedId == DROGEN_VERKAUFS_PED_BASIS_IDENTIFIER then
        if getElementData(player, "currentJob") then
            outputChatBox("Du kannst nicht mit dem Drogenhändler sprechen, während du einen Job hast.", player, 255, 100, 0)
            cancelEvent()
            return
        end
        triggerEvent("drogensystem:requestSellGUIData", player, player)
        cancelEvent()
    elseif pedId == SAMEN_VERKAUFS_PED_IDENTIFIER then
        if getElementData(player, "currentJob") then
            outputChatBox("Du kannst nicht mit dem Samenhändler sprechen, während du einen Job hast.", player, 255, 100, 0)
            cancelEvent()
            return
        end

        playersInteractingWithSeedPeds[player] = clickedPedElement -- NEU: Spieler merkt sich die Interaktion
        
        local pedInventory = pedSeedInventories[clickedPedElement]
        
        if not pedInventory or pedInventory.quantity <= 0 then
            local remainingTime = nextSeedRestockTime - getTickCount()
            if remainingTime < 0 then remainingTime = 0 end 
            local dataForClient = {
                hasStock = false,
                restockTimeRemaining = remainingTime
            }
            triggerClientEvent(player, "drogensystem:openSeedBuyGUI", player, dataForClient)
            cancelEvent()
            return
        end

        local itemDef = exports.tarox:getItemDefinition(pedInventory.itemID)
        if not itemDef then
            logError("Konnte Item-Definition für Samen-ID " .. pedInventory.itemID .. " nicht finden.")
            cancelEvent()
            return
        end
        
        local dataForClient = {
            hasStock = true,
            ped = clickedPedElement,
            itemID = pedInventory.itemID,
            itemName = itemDef.name,
            itemPrice = itemDef.buy_price,
            stock = pedInventory.quantity,
            imagePath = itemDef.imagePath
        }
        triggerClientEvent(player, "drogensystem:openSeedBuyGUI", player, dataForClient)
        cancelEvent()
    end
end, true, "high")

-- NEU: Event-Handler zum Entfernen des Spielers aus der Interaktionsliste
addEvent("drogensystem:clientClosedBuyGUI", true)
addEventHandler("drogensystem:clientClosedBuyGUI", root, function()
    if playersInteractingWithSeedPeds[client] then
        playersInteractingWithSeedPeds[client] = nil
    end
end)

-- Bestehender Handler für Drogenverkauf...
addEvent("drogensystem:requestSellGUIData", true)
addEventHandler("drogensystem:requestSellGUIData", root, function(requestingPlayer)
    local player = requestingPlayer
    if not isElement(player) then return end
    local accountId = getElementData(player, "account_id")
    if not accountId then triggerClientEvent(player, "drogensystem:openSellGUI", player, {}); return end
    local playerInventory = _G.playerInventories and _G.playerInventories[player] or nil
    if not playerInventory then
        if exports.tarox and type(exports.tarox.loadPlayerInventory) == "function" then
            local loadedSuccess, _, loadedInvData = exports.tarox:loadPlayerInventory(player)
            if loadedSuccess then playerInventory = loadedInvData else triggerClientEvent(player, "drogensystem:openSellGUI", player, {}); return end
        else triggerClientEvent(player, "drogensystem:openSellGUI", player, {}); return end
    end
    if not playerInventory then triggerClientEvent(player, "drogensystem:openSellGUI", player, {}); return end
    local sellableDrugItemsInInventory = {}
    if type(playerInventory) == "table" then
        for slot, itemData in pairs(playerInventory) do
            if itemData and itemData.item_id and tonumber(itemData.quantity) > 0 then
                local currentItemId = tonumber(itemData.item_id)
                if VERKAUFBARE_DROGEN_ITEM_IDS[currentItemId] then
                    local itemDef = exports.tarox:getItemDefinition(currentItemId)
                    if itemDef and itemDef.sell_price and tonumber(itemDef.sell_price) > 0 then
                        table.insert(sellableDrugItemsInInventory, {
                            item_id = currentItemId, name = itemDef.name, quantity = tonumber(itemData.quantity),
                            sell_price_each = tonumber(itemDef.sell_price), imagePath = itemDef.imagePath, slot = slot
                        })
                    end
                end
            end
        end
    end
    triggerClientEvent(player, "drogensystem:openSellGUI", player, sellableDrugItemsInInventory)
end)

addEvent("drogensystem:sellDrugItem", true)
addEventHandler("drogensystem:sellDrugItem", root, function(itemSlot, quantityToSell)
    local player = client
    if not isElement(player) then return end
    local accountId = getElementData(player, "account_id")
    if not accountId then return end
    itemSlot = tonumber(itemSlot); quantityToSell = tonumber(quantityToSell)
    if not itemSlot or not quantityToSell or quantityToSell <= 0 then outputChatBox("Ungültig.", player, 255, 0, 0); triggerEvent("drogensystem:requestSellGUIData", player, player); return end
    local playerInventory = _G.playerInventories and _G.playerInventories[player] or nil
    if not playerInventory or not playerInventory[itemSlot] then
        if exports.tarox and type(exports.tarox.loadPlayerInventory) == "function" then
            local loadedSuccess, _, loadedInvData = exports.tarox:loadPlayerInventory(player)
            if loadedSuccess then playerInventory = loadedInvData else outputChatBox("Inventarfehler.", player, 255, 0, 0); triggerEvent("drogensystem:requestSellGUIData", player, player); return end
        else outputChatBox("Systemfehler.", player, 255, 0, 0); triggerEvent("drogensystem:requestSellGUIData", player, player); return end
    end
    if not playerInventory or not playerInventory[itemSlot] then outputChatBox("Item nicht im Inventar.", player, 255, 0, 0); triggerEvent("drogensystem:requestSellGUIData", player, player); return end
    local itemData = playerInventory[itemSlot]; local itemId = tonumber(itemData.item_id)
    if not VERKAUFBARE_DROGEN_ITEM_IDS[itemId] then outputChatBox("Nicht verkaufbar.", player, 255, 0, 0); triggerEvent("drogensystem:requestSellGUIData", player, player); return end
    if tonumber(itemData.quantity) < quantityToSell then outputChatBox("Nicht genug.", player, 255, 0, 0); triggerEvent("drogensystem:requestSellGUIData", player, player); return end
    local itemDef = exports.tarox:getItemDefinition(itemId)
    if not itemDef or not itemDef.sell_price or tonumber(itemDef.sell_price) <= 0 then outputChatBox("Item-Fehler.", player, 255, 0, 0); triggerEvent("drogensystem:requestSellGUIData", player, player); return end
    local moneyGained = tonumber(itemDef.sell_price) * quantityToSell; local itemTakenSuccess, itemTakeMsg = exports.tarox:takePlayerItem(player, itemSlot, quantityToSell)
    if itemTakenSuccess then givePlayerMoney(player, moneyGained); outputChatBox(quantityToSell .. "x " .. itemDef.name .. " für $" .. moneyGained .. " verkauft.", player, 0, 200, 50); triggerEvent("drogensystem:requestSellGUIData", player, player);
    else outputChatBox("Fehler: " .. (itemTakeMsg or "Unbekannt"), player, 255, 0, 0); triggerEvent("drogensystem:requestSellGUIData", player, player); end
end)

-- Event-Handler für den Kauf von Samen
-- ERSETZE den alten Event-Handler 'drogensystem:buySeeds' mit diesem
addEvent("drogensystem:buySeeds", true)
addEventHandler("drogensystem:buySeeds", root, function(pedElement, itemID, quantity)
    local player = client
    if not isElement(player) or not isElement(pedElement) or not itemID or not quantity then return end
    quantity = tonumber(quantity)
    if not quantity or quantity <= 0 then return end
    
    local pedInventory = pedSeedInventories[pedElement]
    if not pedInventory or pedInventory.itemID ~= itemID or pedInventory.quantity < quantity then
        -- Der Bestand hat sich geändert, seit der Client das GUI geöffnet hat. Sende ein Update.
        local currentStock = (pedInventory and pedInventory.quantity) or 0
        local dataForClientRefresh
        if currentStock > 0 then
            local itemDefRefresh = exports.tarox:getItemDefinition(pedInventory.itemID)
            dataForClientRefresh = { hasStock = true, ped = pedElement, itemID = pedInventory.itemID, itemName = itemDefRefresh.name, itemPrice = itemDefRefresh.buy_price, stock = currentStock, imagePath = itemDefRefresh.imagePath }
        else
            dataForClientRefresh = { hasStock = false, restockTimeRemaining = nextSeedRestockTime - getTickCount() }
        end
        triggerClientEvent(player, "drogensystem:openSeedBuyGUI", player, dataForClientRefresh)
        outputChatBox("Der Vorrat dieses Händlers hat sich geändert oder ist nicht mehr ausreichend.", player, 255, 100, 0)
        return
    end

    local itemDef = exports.tarox:getItemDefinition(itemID)
    if not itemDef or not itemDef.buy_price then
        outputChatBox("Fehler: Preis für dieses Item nicht gefunden.", player, 255, 0, 0)
        return
    end

    local totalCost = itemDef.buy_price * quantity
    if getPlayerMoney(player) < totalCost then
        outputChatBox("Du hast nicht genug Geld. Du benötigst $" .. totalCost .. ".", player, 255, 100, 0)
        return
    end

    local gaveItem, giveMsg = exports.tarox:givePlayerItem(player, itemID, quantity)
    if not gaveItem then
        outputChatBox("Kauf fehlgeschlagen: " .. (giveMsg or "Dein Inventar ist möglicherweise voll."), player, 255, 0, 0)
        return
    end
    
    takePlayerMoney(player, totalCost)
    pedInventory.quantity = pedInventory.quantity - quantity
    
    outputChatBox("Du hast " .. quantity .. "x " .. itemDef.name .. " für $" .. totalCost .. " gekauft.", player, 0, 200, 50)
    
    -- << NEUER/VERBESSERTER TEIL STARTET HIER >>

    -- Prüfen, ob der Vorrat jetzt leer ist
    if pedInventory.quantity <= 0 then
        -- Der Vorrat ist leer. Sende eine "Out of Stock"-Nachricht an ALLE Spieler,
        -- die gerade mit DIESEM Ped interagieren.
        local remainingTime = nextSeedRestockTime - getTickCount()
        if remainingTime < 0 then remainingTime = 0 end
        local outOfStockData = { hasStock = false, restockTimeRemaining = remainingTime }

        for otherPlayer, interactingPed in pairs(playersInteractingWithSeedPeds) do
            if isElement(otherPlayer) and interactingPed == pedElement then
                triggerClientEvent(otherPlayer, "drogensystem:openSeedBuyGUI", otherPlayer, outOfStockData)
            end
        end
    else
        -- Wenn noch Ware da ist, nur den Käufer aktualisieren.
        local dataForClient = { hasStock = true, ped = pedElement, itemID = pedInventory.itemID, itemName = itemDef.name,
            itemPrice = itemDef.buy_price, stock = pedInventory.quantity, imagePath = itemDef.imagePath }
        triggerClientEvent(player, "drogensystem:openSeedBuyGUI", player, dataForClient)
    end
    -- << NEUER/VERBESSERTER TEIL ENDET HIER >>
end)


-- Bestehender /giveseed Befehl (unverändert)...
addCommandHandler("giveseed", function(adminPlayer, command, targetPlayerNameOrID, seedTypeStr)
    local adminLevel = getElementData(adminPlayer, "adminLevel") or 0
    if adminLevel < 1 then outputChatBox("Keine Berechtigung.", adminPlayer, 255,0,0); return end
    if not targetPlayerNameOrID or not seedTypeStr then outputChatBox("VERWENDUNG: /giveseed [Spielername/ID] [cannabis|koka]", adminPlayer, 200,200,0); return end
    local targetPlayer=nil; local potentialTargets={}; local searchStringLower=string.lower(tostring(targetPlayerNameOrID))
    for _,p in ipairs(getElementsByType("player"))do if getElementData(p,"account_id")then if string.find(string.lower(getPlayerName(p)),searchStringLower,1,true)or tostring(getElementData(p,"account_id"))==searchStringLower then table.insert(potentialTargets,p)end end end
    if #potentialTargets==0 then outputChatBox("Spieler '"..targetPlayerNameOrID.."' nicht gefunden.",adminPlayer,255,100,0);return elseif #potentialTargets>1 then outputChatBox("Mehrere Spieler:",adminPlayer,255,165,0);for i=1,math.min(5,#potentialTargets)do local tP=potentialTargets[i];outputChatBox(" - "..getPlayerName(tP).." (ID: "..(getElementData(tP,"account_id")or"N/A")..")",adminPlayer,200,200,200)end;if #potentialTargets>5 then outputChatBox(" ...",adminPlayer,200,200,200)end;return else targetPlayer=potentialTargets[1]end
    if not isElement(targetPlayer)then outputChatBox("Ungültiger Zielspieler.",adminPlayer,255,0,0);return end
    local seedType=string.lower(seedTypeStr);local itemIDToGive=nil;local itemName=""
    if seedType=="cannabis"then itemIDToGive=20;itemName="Cannabis Samen"elseif seedType=="koka"then itemIDToGive=22;itemName="Koka Setzling"else outputChatBox("Ungültiger Samentyp. cannabis|koka",adminPlayer,255,100,0);return end
    local success,message=exports.tarox:givePlayerItem(targetPlayer,itemIDToGive,1,nil)
    if success then outputChatBox("1x "..itemName.." an "..getPlayerName(targetPlayer).." gegeben.",adminPlayer,0,200,50);outputChatBox("1x "..itemName.." von "..getPlayerName(adminPlayer).." erhalten.",targetPlayer,0,200,50);
    else outputChatBox("Fehler: "..(message or"Unbekannt"),adminPlayer,255,0,0);if targetPlayer~=adminPlayer then outputChatBox("Admin "..getPlayerName(adminPlayer).." versuchte, dir "..itemName.." zu geben, Fehler.",targetPlayer,255,100,0)end;
    end
end)

addEventHandler("onResourceStart", resourceRoot, function()
    createDrogenVerkaufsPeds()
    setTimer(updateSeedPedInventories, SEED_RESTOCK_INTERVAL_MS, 0)
    updateSeedPedInventories()
end)

addEventHandler("onResourceStop", resourceRoot, function()
    local plantCount = 0
    for uid, plantData in pairs(activePlants) do
        if isElement(plantData.object) then destroyElement(plantData.object); plantCount = plantCount + 1 end
        if isTimer(plantData.growthTimer) then killTimer(plantData.growthTimer) end
        if isTimer(plantData.despawnTimer) then killTimer(plantData.despawnTimer) end
    end
    activePlants = {}
    
    local pedCount = 0
    for _, pedElement in ipairs(aktiveDrogenVerkaufsPeds) do
        if isElement(pedElement) then destroyElement(pedElement); pedCount = pedCount + 1 end
    end
    aktiveDrogenVerkaufsPeds = {}
    pedSeedInventories = {}
    playersInteractingWithSeedPeds = {} -- Leeren bei Stop
end)

-- NEU: Spieler aus Interaktionsliste entfernen, wenn er den Server verlässt.
addEventHandler("onPlayerQuit", root, function()
    if playersInteractingWithSeedPeds[source] then
        playersInteractingWithSeedPeds[source] = nil
    end
end)


if not table.count then function table.count(t) local c=0;if type(t)=="table"then for _ in pairs(t)do c=c+1 end end;return c end end