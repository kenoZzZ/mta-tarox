-- tarox/shops/juwelier/juwelier_server.lua
-- ERWEITERT: Teleport-Marker zum Juwelierladen (Interior 5) mit Blip für Eingang
-- KORRIGIERT: Ausgangsmarker-Position nach Wunsch geändert
-- Blip nur für Eingang, Icon ID 60
-- ANGEPASST V1.1: Verbesserte Fehlerbehandlung (primär durch aufgerufene Funktionen)

local SELLABLE_ITEM_IDS = {
    [10] = true, -- Goldbarren
    [13] = true, -- Silberbarren
    [14] = true, -- Diamant
    [16] = true  -- Schmuck
}

-- Event Deklarationen
addEvent("juwelier:requestSellGUIData", true)
addEvent("juwelier:sellItem", true)

-- ##########################################################################
-- ## TELEPORTER KONFIGURATION UND FUNKTIONEN
-- ##########################################################################

local juwelierEingangMarkerPosition = {x = -2430.23877, y = 20.78238, z = 35.23784}
local juwelierEingangZielPosition = {x = 223.07195, y = -8.47656, z = 1002.21094}
local juwelierInteriorID = 5
local juwelierDimension = 0

local juwelierAusgangMarkerPosition = {x = 227.00851, y = -8.03714, z = 1003 - 0.8}
local juwelierAusgangZielPosition = {x = -2427.46143, y = 21.07078, z = 35.22789}

local juwelierEingangsMarker = nil
local juwelierAusgangsMarker = nil
local juwelierEingangsBlip = nil

local BLIP_ICON_JUWELIER_EINGANG = 60
local BLIP_SIZE = 1
local BLIP_COLOR_EINGANG = {218, 165, 32, 255}
local BLIP_VISIBLE_DISTANCE = 100

function erstelleJuwelierTeleporter()
    if isElement(juwelierEingangsMarker) then destroyElement(juwelierEingangsMarker) end
    if isElement(juwelierEingangsBlip) then destroyElement(juwelierEingangsBlip) end

    juwelierEingangsMarker = createMarker(
        juwelierEingangMarkerPosition.x, juwelierEingangMarkerPosition.y, juwelierEingangMarkerPosition.z - 1,
        "cylinder", 1.5, 218, 165, 32, 180
    )

    if isElement(juwelierEingangsMarker) then
        setElementInterior(juwelierEingangsMarker, 0); setElementDimension(juwelierEingangsMarker, 0)
        addEventHandler("onMarkerHit", juwelierEingangsMarker, function(hitElement, matchingDimension)
            if getElementType(hitElement) == "player" and matchingDimension then
                if not isPedInVehicle(hitElement) then
                    fadeCamera(hitElement, false, 0.5)
                    setTimer(function(player)
                        if isElement(player) then
                            setElementPosition(player, juwelierEingangZielPosition.x, juwelierEingangZielPosition.y, juwelierEingangZielPosition.z)
                            setElementInterior(player, juwelierInteriorID); setElementDimension(player, juwelierDimension)
                            fadeCamera(player, true, 0.5)
                        end
                    end, 500, 1, hitElement)
                end
            end
        end)
        juwelierEingangsBlip = createBlipAttachedTo(juwelierEingangsMarker, BLIP_ICON_JUWELIER_EINGANG, BLIP_SIZE, unpack(BLIP_COLOR_EINGANG))
        if isElement(juwelierEingangsBlip) then setBlipVisibleDistance(juwelierEingangsBlip, BLIP_VISIBLE_DISTANCE)
        else outputDebugString("[JuwelierTeleport] FEHLER: Eingangsblip konnte nicht erstellt werden!") end
    else outputDebugString("[JuwelierTeleport] FEHLER: Juwelier-Eingangsmarker konnte nicht erstellt werden!") end

    if isElement(juwelierAusgangsMarker) then destroyElement(juwelierAusgangsMarker) end
    juwelierAusgangsMarker = createMarker(
        juwelierAusgangMarkerPosition.x, juwelierAusgangMarkerPosition.y, juwelierAusgangMarkerPosition.z -1,
        "cylinder", 1.5, 200, 200, 200, 150
    )
    if isElement(juwelierAusgangsMarker) then
        setElementInterior(juwelierAusgangsMarker, juwelierInteriorID); setElementDimension(juwelierAusgangsMarker, juwelierDimension)
        addEventHandler("onMarkerHit", juwelierAusgangsMarker, function(hitElement, matchingDimension)
            if getElementType(hitElement) == "player" and matchingDimension then
                if not isPedInVehicle(hitElement) then
                    fadeCamera(hitElement, false, 0.5)
                    setTimer(function(player)
                        if isElement(player) then
                            setElementPosition(player, juwelierAusgangZielPosition.x, juwelierAusgangZielPosition.y, juwelierAusgangZielPosition.z)
                            setElementInterior(player, 0); setElementDimension(player, 0)
                            fadeCamera(player, true, 0.5)
                        end
                    end, 500, 1, hitElement)
                end
            end
        end)
    else outputDebugString("[JuwelierTeleport] FEHLER: Juwelier-Ausgangsmarker konnte nicht erstellt werden!") end
end

-- ##########################################################################
-- ## JUWELIER-LOGIK
-- ##########################################################################

addEventHandler("juwelier:requestSellGUIData", root, function()
    local player = source
    if not isElement(player) then return end
    local accountId = getElementData(player, "account_id")
    if not accountId then
        triggerClientEvent(player, "juwelier:openSellGUI", player, {})
        return
    end

    local sellableItemsInInventory = {}
    -- _G.playerInventories wird von inventory_server.lua gefüllt und aktualisiert
    local playerInventory = _G.playerInventories and _G.playerInventories[player] or nil

    if not playerInventory then
        outputDebugString("[Juwelier] requestSellGUIData: Kein Inventar-Cache für Spieler " .. getPlayerName(player) .. " gefunden.")
        triggerClientEvent(player, "juwelier:openSellGUI", player, {})
        return
    end

    if type(playerInventory) == "table" then
        for slot, itemData in pairs(playerInventory) do
            if itemData and itemData.item_id and tonumber(itemData.quantity) > 0 then
                local currentItemId = tonumber(itemData.item_id)
                if SELLABLE_ITEM_IDS[currentItemId] then
                    local itemDef = exports.tarox:getItemDefinition(currentItemId)
                    if itemDef and itemDef.sell_price and tonumber(itemDef.sell_price) > 0 then
                        table.insert(sellableItemsInInventory, {
                            item_id = currentItemId, name = itemDef.name, quantity = tonumber(itemData.quantity),
                            sell_price_each = tonumber(itemDef.sell_price), imagePath = itemDef.imagePath, slot = slot
                        })
                    end
                end
            end
        end
    end
    triggerClientEvent(player, "juwelier:openSellGUI", player, sellableItemsInInventory)
end)

addEventHandler("juwelier:sellItem", root, function(itemSlot, quantityToSell)
    local player = client
    if not isElement(player) then return end
    local accountId = getElementData(player, "account_id")
    if not accountId then return end

    itemSlot = tonumber(itemSlot)
    quantityToSell = tonumber(quantityToSell)
    if not itemSlot or not quantityToSell or quantityToSell <= 0 then
        outputChatBox("Ungültige Verkaufsanfrage.", player, 255, 0, 0)
        return
    end

    local playerInventory = _G.playerInventories and _G.playerInventories[player] or nil
    if not playerInventory or not playerInventory[itemSlot] then
        outputChatBox("Item nicht in deinem Inventar gefunden.", player, 255, 0, 0)
        return
    end

    local itemData = playerInventory[itemSlot]
    local itemId = tonumber(itemData.item_id)
    if not SELLABLE_ITEM_IDS[itemId] then
        outputChatBox("Dieses Item kann hier nicht verkauft werden.", player, 255, 0, 0)
        return
    end
    if tonumber(itemData.quantity) < quantityToSell then
        outputChatBox("Du hast nicht genügend von diesem Item (Benötigt: " .. quantityToSell .. ", Vorhanden: " .. itemData.quantity .. ").", player, 255, 0, 0)
        return
    end

    local itemDef = exports.tarox:getItemDefinition(itemId)
    if not itemDef or not itemDef.sell_price or tonumber(itemDef.sell_price) <= 0 then
        outputChatBox("Fehler: Item-Definition oder gültiger Verkaufspreis nicht gefunden.", player, 255, 0, 0)
        return
    end

    local moneyGained = tonumber(itemDef.sell_price) * quantityToSell
    local itemTakenSuccess, itemTakeMsg = exports.tarox:takePlayerItem(player, itemSlot, quantityToSell)

    if itemTakenSuccess then
        givePlayerMoney(player, moneyGained) -- MTA-Kernfunktion, keine explizite Fehlerbehandlung nötig hier
        outputChatBox("Du hast " .. quantityToSell .. "x " .. itemDef.name .. " für $" .. moneyGained .. " verkauft.", player, 0, 200, 50)
        triggerClientEvent(player, "juwelier:refreshSellGUIData", player) -- Client anweisen, GUI zu aktualisieren
    else
        outputChatBox("Fehler beim Entfernen des Items aus deinem Inventar: " .. (itemTakeMsg or "Unbekannt"), player, 255, 0, 0)
        -- Kein Geld geben, da das Item nicht entfernt wurde
    end
end)

if not table.count then
    function table.count(t) local c = 0; if type(t) == "table" then for _ in pairs(t) do c = c + 1 end end; return c end
end

-- ##########################################################################
-- ## RESSOURCEN-START UND -STOPP
-- ##########################################################################

local function initializeJuwelierSystem()
    local db_check = exports.datenbank:getConnection() -- DB-Verbindung prüfen
    if not db_check then
        outputDebugString("[Juwelier] WARNUNG bei onResourceStart: Keine DB-Verbindung! Item-Operationen könnten fehlschlagen.", 1)
    end
    erstelleJuwelierTeleporter()
    outputDebugString("[Juwelier] Juwelier-System (V1.1 - DB Fehlerbehandlung, Teleporter V4) gestartet.")
end

local function shutdownJuwelierSystem()
    if isElement(juwelierEingangsMarker) then destroyElement(juwelierEingangsMarker); juwelierEingangsMarker = nil; end
    if isElement(juwelierAusgangsMarker) then destroyElement(juwelierAusgangsMarker); juwelierAusgangsMarker = nil; end
    if isElement(juwelierEingangsBlip) then destroyElement(juwelierEingangsBlip); juwelierEingangsBlip = nil; end
    outputDebugString("[Juwelier] Juwelier-System (V1.1) gestoppt und Elemente entfernt.")
end

addEventHandler("onResourceStart", resourceRoot, initializeJuwelierSystem)
addEventHandler("onResourceStop", resourceRoot, shutdownJuwelierSystem)