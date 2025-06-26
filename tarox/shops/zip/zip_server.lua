-- tarox/shops/zip/zip_server.lua
-- VERSION MIT KORRIGIERTER FUNKTIONSREIHENFOLGE & DEBUGGING
-- ANGEPASST V1.1: Verbesserte Fehlerbehandlung für Datenbankaufrufe

local outsideToInsideMarkerPos = { x = -1882.83997, y = 866.02673, z = 35.17188 }
local insideTeleportPos        = { x = 163.18648,   y = -94.45720,  z = 1001.80469 } -- ZIP Innen-Ziel

local interiorID = 18
local dimension  = 0

-- Exit marker => teleports them outside:
local exitMarkerPos  = { x = 161.50127, y = -96.36082, z = 1001.80469 }
local outsideExitPos = { x = -1885.06079, y = 863.75616, z = 35.17284 }

-- Inside "shop marker" => opens the clothes menu
local shopMarkerPos  = { x = 181.16753, y = -88.11806, z = 1002.03070 }

local outsideMarker
local exitMarker
local shopMarker

local playersInShopMarker = {}

--------------------------------------------
-- Event Handler Funktionen
--------------------------------------------

function handleZipOutsideMarkerHit(player, matchingDimension)
    if not matchingDimension then return end
    if getElementType(player) ~= "player" then return end
    if isPedInVehicle(player) then return end

    outputDebugString("[ZIP] handleZipOutsideMarkerHit ausgelöst für: " .. getPlayerName(player))

    fadeCamera(player, false, 1.0, 0, 0, 0)
    setTimer(function()
        if isElement(player) then
             local targetX = insideTeleportPos.x
             local targetY = insideTeleportPos.y
             local targetZ = insideTeleportPos.z
             local targetInterior = interiorID
             local targetDimension = dimension

             outputDebugString("[ZIP] [DEBUG] Ziel-Koordinaten für Teleport: X=" .. targetX .. ", Y=" .. targetY .. ", Z=" .. targetZ .. ", Int=" .. targetInterior .. ", Dim=" .. targetDimension)

             setElementInterior(player, targetInterior)
             setElementDimension(player, targetDimension)
             setTimer(function()
                  if isElement(player) then
                       setElementPosition(player, targetX, targetY, targetZ)
                       outputDebugString("[ZIP] Teleport REIN: Position gesetzt.")
                       fadeCamera(player, true, 1.0)
                  end
             end, 50, 1)
        end
    end, 1000, 1)
end

function handleExitMarkerHit(player, matchingDimension)
    if not matchingDimension then return end
    if getElementType(player) ~= "player" then return end
    if isPedInVehicle(player) then return end

    outputDebugString("[ZIP] handleExitMarkerHit ausgelöst für: " .. getPlayerName(player))

    fadeCamera(player, false, 1.0, 0, 0, 0)
    setTimer(function()
        if isElement(player) then
            setElementInterior(player, 0)
            setElementDimension(player, 0)
            setElementPosition(player, outsideExitPos.x, outsideExitPos.y, outsideExitPos.z)
            outputDebugString("[ZIP] Teleport RAUS: Position gesetzt auf X="..outsideExitPos.x..", Y="..outsideExitPos.y..", Z="..outsideExitPos.z)
            fadeCamera(player, true, 1.0)
        end
    end, 1000, 1)
end

function handleShopMarkerHit(player, matchingDimension)
    if not matchingDimension then return end
    if getElementType(player) ~= "player" then return end
    if isPedInVehicle(player) then return end
    if playersInShopMarker[player] then return end
    playersInShopMarker[player] = true
    triggerClientEvent(player, "onClothesShopMarkerHit", player)
end

function handleShopMarkerLeave(player, matchingDimension)
    if not matchingDimension then return end
    if getElementType(player) ~= "player" then return end
    if playersInShopMarker[player] then playersInShopMarker[player] = nil end
end

--------------------------------------------
-- onResourceStart
--------------------------------------------
addEventHandler("onResourceStart", resourceRoot, function()
    local db_check = exports.datenbank:getConnection() -- DB-Verbindung prüfen
    if not db_check then
        outputDebugString("[ZIP-SHOP] WARNUNG bei onResourceStart: Keine DB-Verbindung! Skin-Speicherung wird fehlschlagen.", 1)
    end

    outsideMarker = createMarker(outsideToInsideMarkerPos.x, outsideToInsideMarkerPos.y, outsideToInsideMarkerPos.z - 1, "cylinder", 1.5, 255, 255, 0, 150)
    if isElement(outsideMarker) then addEventHandler("onMarkerHit", outsideMarker, handleZipOutsideMarkerHit)
    else outputDebugString("[ZIP-SHOP] FEHLER: Konnte Außen-Marker nicht erstellen!", 2) end

    exitMarker = createMarker(exitMarkerPos.x, exitMarkerPos.y, exitMarkerPos.z - 1, "cylinder", 1.5, 255, 0, 0, 150)
    if isElement(exitMarker) then setElementInterior(exitMarker, interiorID); setElementDimension(exitMarker, dimension); addEventHandler("onMarkerHit", exitMarker, handleExitMarkerHit)
    else outputDebugString("[ZIP-SHOP] FEHLER: Konnte Exit-Marker nicht erstellen!", 2) end

    shopMarker = createMarker(shopMarkerPos.x, shopMarkerPos.y, shopMarkerPos.z - 1, "cylinder", 1.5, 0, 200, 0, 150)
    if isElement(shopMarker) then setElementInterior(shopMarker, interiorID); setElementDimension(shopMarker, dimension); addEventHandler("onMarkerHit", shopMarker, handleShopMarkerHit); addEventHandler("onMarkerLeave", shopMarker, handleShopMarkerLeave)
    else outputDebugString("[ZIP-SHOP] FEHLER: Konnte Shop-Marker nicht erstellen!", 2) end

    outputDebugString("[ZIP-SHOP] Markers created.")
end)

--------------------------------------------
-- Buy logic
--------------------------------------------
addEvent("onPlayerBuyOutfit", true)
addEventHandler("onPlayerBuyOutfit", root, function(selectedSkin)
    local plr = client
    if not isElement(plr) then return end
    local cost = 1000
    local haveMoney = getPlayerMoney(plr)
    if haveMoney < cost then outputChatBox("Not enough money for that outfit!", plr, 255,0,0); return end

    takePlayerMoney(plr, cost) -- Fehlerbehandlung für takePlayerMoney ist nicht MTA-Standard, wird oft serverseitig gehandhabt
    setElementModel(plr, selectedSkin)

    local accID = getElementData(plr, "account_id")
    if accID then
        local success, errMsg = exports.datenbank:executeDatabase("UPDATE account SET standard_skin=? WHERE id=?", selectedSkin, accID)
        if not success then
            outputDebugString("[ZIP-SHOP] FEHLER beim Speichern des Skins in der DB für AccID " .. accID .. ": " .. (errMsg or "Unbekannt"), 2)
            outputChatBox("Fehler beim Speichern des Outfits. Dein Geld wurde zurückerstattet.", plr, 255, 0, 0)
            givePlayerMoney(plr, cost) -- Geld zurückgeben bei DB-Fehler
            -- Optional: Skin zurücksetzen auf alten Wert, falls bekannt
            -- local oldSkin = getElementData(plr, "standard_skin_before_zip") -- Annahme: wird vorher gesetzt
            -- if oldSkin then setElementModel(plr, oldSkin) end
            return
        end
        setElementData(plr, "standard_skin", selectedSkin) -- ElementData aktualisieren
    else
        outputDebugString("[ZIP-SHOP] FEHLER: Keine Account-ID zum Speichern des Skins für Spieler " .. getPlayerName(plr), 2)
        -- Hier könnte man auch das Geld zurückgeben, da die Speicherung nicht möglich ist.
    end

    triggerClientEvent(plr, "onOutfitPurchaseSuccess", plr, selectedSkin)
    outputChatBox("You bought a new outfit for $" .. cost .. "!", plr, 0,255,0)
end)

addEventHandler("onResourceStop", resourceRoot, function()
    if isElement(outsideMarker) then destroyElement(outsideMarker); outsideMarker = nil end
    if isElement(exitMarker) then destroyElement(exitMarker); exitMarker = nil end
    if isElement(shopMarker) then destroyElement(shopMarker); shopMarker = nil end
    playersInShopMarker = {}
    outputDebugString("[ZIP-SHOP] ZIP Shop (Server V1.1 - DB Fehlerbehandlung) gestoppt und Elemente entfernt.")
end)

outputDebugString("[ZIP-SHOP] ZIP Shop (Server V1.1 - DB Fehlerbehandlung) geladen.")