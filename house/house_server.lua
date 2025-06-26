-- [house_system]/house_server.lua (Mit Dimension Handling & Kauf-Limit)

local existingHouses = {} -- Cache für Hausdaten

-- Tabelle für Standard-Interior-Spawnpositionen
local interiorSpawnPositions = {
    [3] = { x = 230.5, y = 1050.8, z = 1003.0, rot = 90 },  [4] = { x = 260.98001, y = 1284.55005, z = 1080.25781, rot = 90 },
    [5] = { x = 140.0, y = 1370.0, z = 1083.8, rot = 180 }, [6] = { x = -68.69000, y = 1351.96997, z = 1080.21094, rot = 0 },
    [8] = { x = 2364.9, y = -1133.6, z = 1050.8, rot = 0 }, [9] = { x = 2317.5, y = -1026.0, z = 1050.2, rot = 0 },
    [18] = { x = 163.1, y = -94.4, z = 1001.8, rot = 0 },
    -- Füge hier weitere Interior-IDs hinzu
}

-- Admin Command /sethouse (unverändert)
addCommandHandler("sethouse", function(player, command, interiorIDStr, priceStr)
    local adminLevel = getElementData(player, "adminLevel") or 0; if adminLevel < 1 then outputChatBox("❌ Berechtigung!", player, 255, 0, 0); return end
    local interiorID = tonumber(interiorIDStr); local price = tonumber(priceStr); if not interiorID or not price or interiorID <= 0 or price <= 0 then outputChatBox("SYNTAX: /sethouse <InteriorID> <Preis>", player, 255, 180, 0); return end
    local x, y, z = getElementPosition(player); local db = exports.datenbank:getConnection(); if not db then outputChatBox("❌ DB Fehler!", player, 255, 0, 0); return end
    local query = "INSERT INTO houses (posX, posY, posZ, price, interior_id, owner_account_id, locked, interior_posX, interior_posY, interior_posZ) VALUES (?, ?, ?, ?, ?, NULL, 1, NULL, NULL, NULL)"
    local success = exports.datenbank:executeDatabase(query, x, y, z, price, interiorID)
    if success then local resultId = exports.datenbank:queryDatabase("SELECT LAST_INSERT_ID() as id"); local houseID = (resultId and resultId[1]) and resultId[1].id or nil
        if houseID then outputChatBox(string.format("✅ Haus #%d erstellt (Int: %d) für $%s!", houseID, interiorID, formatMoney(price)), player, 0, 255, 0); existingHouses[houseID] = { id = houseID, posX = x, posY = y, posZ = z, interior_id = interiorID, owner_account_id = nil }; triggerClientEvent(root, "createHouseBlipClient", resourceRoot, houseID, x, y, z, nil)
        else outputChatBox("❌ ID Fehler.", player, 255, 100, 0) end
    else outputChatBox("❌ DB Fehler.", player, 255, 0, 0) end
end)

-- Laden der Häuser beim Serverstart (unverändert)
addEventHandler("onResourceStart", resourceRoot, function()
    local db = exports.datenbank:getConnection(); if not db then outputDebugString("FEHLER: DB Start!", 2); return end
    local result = exports.datenbank:queryDatabase("SELECT id, posX, posY, posZ, interior_id, owner_account_id FROM houses")
    existingHouses = {}; if result then outputDebugString("[HouseSystem] Lade " .. #result .. " Häuser in Cache..."); for _, row in ipairs(result) do if type(row.owner_account_id) ~= "number" then row.owner_account_id = nil end; existingHouses[row.id] = row end; outputDebugString("[HouseSystem] Haus-Cache gefüllt.") else outputDebugString("[HouseSystem] Keine Häuser zum Laden.", 1) end
end)

-- Handler für Client-Anfrage (Pickups erstellen) (unverändert)
addEvent("requestExistingHouses", true)
addEventHandler("requestExistingHouses", root, function()
    local player=client; local playerName=getPlayerName(player);
	local count=0
    if existingHouses and next(existingHouses) then for houseID, houseData in pairs(existingHouses) do if houseData and houseData.posX then triggerClientEvent(player, "createHouseBlipClient", resourceRoot, houseID, houseData.posX, houseData.posY, houseData.posZ, houseData.owner_account_id); count = count + 1 end end end
end)


-- Event: Spieler möchte Hausinformationen (unverändert)
addEvent("requestHouseInfo", true)
addEventHandler("requestHouseInfo", root, function(houseID)
    local player=client
    if not houseID then return end
    local db=exports.datenbank:getConnection()
    if not db then return end
    local query="SELECT h.price, h.owner_account_id, h.interior_id, a.username AS owner_name FROM houses h LEFT JOIN account a ON h.owner_account_id = a.id WHERE h.id = ?"
    local result=exports.datenbank:queryDatabase(query, houseID)
    if result and result[1] then
        local houseData=result[1]
        local info={ id=houseID, interior=houseData.interior_id or 0 }
        if type(houseData.owner_account_id)=="number" and houseData.owner_account_id > 0 then
            info.status="owned"
            info.owner=houseData.owner_name or "Unbekannt"
            info.owner_id=houseData.owner_account_id
        else
            info.status="forsale"
            info.price=houseData.price
        end
        triggerClientEvent(player, "showHouseInfoGUI", player, info)
    end
end)

-- Event: Kaufversuch (Mit Besitz-Limitierung, unverändert)
addEvent("tryBuyHouse", true)
addEventHandler("tryBuyHouse", root, function(houseID)
    local player = client; local playerAccountID = getElementData(player, "account_id"); local playerName = getPlayerName(player)
    if not playerAccountID then outputChatBox("Fehler: Account.", player, 255, 0, 0); return end; if not houseID then outputChatBox("Fehler: Haus-ID.", player, 255, 0, 0); return end
    local db = exports.datenbank:getConnection(); if not db then outputChatBox("DB Fehler.", player, 255, 0, 0); return end
    local ownershipCheckQuery = "SELECT COUNT(*) as house_count FROM houses WHERE owner_account_id = ?"; local ownershipResult = exports.datenbank:queryDatabase(ownershipCheckQuery, playerAccountID)
    if not ownershipResult or not ownershipResult[1] then outputChatBox("❌ Fehler beim Prüfen des Hausbesitzes.", player, 255, 0, 0); triggerClientEvent(player, "closeHouseGUI", player); return end
    if tonumber(ownershipResult[1].house_count) > 0 then outputChatBox("❌ Du besitzt bereits ein Haus!", player, 255, 100, 0); triggerClientEvent(player, "closeHouseGUI", player); return end
    local checkQuery = "SELECT price, owner_account_id, interior_id FROM houses WHERE id = ?"; local checkResult = exports.datenbank:queryDatabase(checkQuery, houseID)
    if not checkResult or not checkResult[1] then outputChatBox("Haus nicht gefunden.", player, 255, 100, 0); triggerClientEvent(player, "closeHouseGUI", player); return end
    local houseData = checkResult[1]; local currentOwnerRaw = houseData.owner_account_id; local price = tonumber(houseData.price); local isOwned = (type(currentOwnerRaw) == "number" and currentOwnerRaw > 0)
    if isOwned then outputChatBox("Dieses Haus wurde bereits gekauft!", player, 255, 100, 0); local ownerID = currentOwnerRaw; local ownerNameResult = exports.datenbank:queryDatabase("SELECT username FROM account WHERE id = ?", ownerID); local ownerName = (ownerNameResult and ownerNameResult[1]) and ownerNameResult[1].username or "Unbekannt"; triggerClientEvent(player, "showHouseInfoGUI", player, { id = houseID, status = "owned", owner = ownerName, owner_id = ownerID, interior = houseData.interior_id or 0 }); return end
    local playerMoney = getPlayerMoney(player); if playerMoney < price then outputChatBox("Nicht genug Geld! (" .. formatMoney(price) .. ").", player, 255, 0, 0); return end
    if takePlayerMoney(player, price) then local updateQuery = "UPDATE houses SET owner_account_id = ?, locked = 1 WHERE id = ? AND owner_account_id IS NULL"; local success = exports.datenbank:executeDatabase(updateQuery, playerAccountID, houseID)
        if success then outputChatBox("Glückwunsch! Haus #" .. houseID .. " gekauft für " .. formatMoney(price) .. "!", player, 0, 255, 0); triggerClientEvent(player, "closeHouseGUI", player); if existingHouses[houseID] then existingHouses[houseID].owner_account_id = playerAccountID end; triggerClientEvent(root, "updateHouseVisualStateClient", resourceRoot, houseID, playerAccountID, playerName)
        else outputChatBox("Kauf fehlgeschlagen! Das Haus wurde möglicherweise gerade von jemand anderem gekauft.", player, 255, 0, 0); givePlayerMoney(player, price); triggerClientEvent(player, "closeHouseGUI", player); addEvent("requestHouseInfo", true); triggerEvent("requestHouseInfo", player, houseID) end
    else outputChatBox("Fehler beim Geld abziehen.", player, 255, 0, 0) end
end)

-- Event: Haus betreten (MODIFIZIERT FÜR DIMENSION)
addEvent("requestEnterHouse", true)
addEventHandler("requestEnterHouse", root, function(houseID)
    local player = client
    local playerAccountID = getElementData(player, "account_id")
    if not playerAccountID or not houseID then return end

    local db = exports.datenbank:getConnection()
    if not db then outputChatBox("DB Fehler.", player, 255, 0, 0); return end

    local query = "SELECT owner_account_id, interior_id, posX, posY, posZ, interior_posX, interior_posY, interior_posZ FROM houses WHERE id = ?"
    local result = exports.datenbank:queryDatabase(query, houseID)
    if not result or not result[1] then outputChatBox("Haus nicht gefunden.", player, 255, 100, 0); return end

    local houseData = result[1]
    local ownerID = tonumber(houseData.owner_account_id)
    local canEnter = (ownerID == playerAccountID) -- Beispiel: Nur Besitzer darf rein

    if not canEnter then outputChatBox("Du besitzt dieses Haus nicht oder bist kein Gast!", player, 255, 0, 0); return end

    local interiorID = tonumber(houseData.interior_id) or 0
    if interiorID <= 0 then outputChatBox("Kein Interior gesetzt.", player, 255, 100, 0); return end

    local spawnX, spawnY, spawnZ, spawnRot
    if houseData.interior_posX and houseData.interior_posY and houseData.interior_posZ then
        spawnX = tonumber(houseData.interior_posX); spawnY = tonumber(houseData.interior_posY); spawnZ = tonumber(houseData.interior_posZ); spawnRot = 0
    elseif interiorSpawnPositions[interiorID] then
        local data = interiorSpawnPositions[interiorID]
        spawnX = data.x; spawnY = data.y; spawnZ = data.z; spawnRot = data.rot or 0
    else
        spawnX = 0; spawnY = 0; spawnZ = 5; spawnRot = 0
    end

    local exteriorPos = { x = houseData.posX, y = houseData.posY, z = houseData.posZ }
    setElementData(player, "currentHouseExterior", exteriorPos, false)

    fadeCamera(player, false, 0.5)
    setTimer(function()
        if isElement(player) then
            setElementInterior(player, interiorID)
            setElementDimension(player, houseID) -- *** DIMENSION SETZEN ***
            setElementPosition(player, spawnX, spawnY, spawnZ)
            setPedRotation(player, spawnRot)
            fadeCamera(player, true, 0.5)
        end
    end, 500, 1)
    triggerClientEvent(player, "closeHouseGUI", player)
    outputChatBox("Willkommen zuhause!", player, 0, 200, 100)
end)

-- Command /leave (MODIFIZIERT FÜR DIMENSION)
addCommandHandler("leave", function(player, command)
    local currentDimension = getElementDimension(player)
    local exteriorPos = getElementData(player, "currentHouseExterior")

    if currentDimension == 0 or not exteriorPos then
        outputChatBox("Du bist in keinem Haus.", player, 255, 165, 0)
        return
    end

    fadeCamera(player, false, 0.5)
    setTimer(function()
        if isElement(player) then
            setElementInterior(player, 0)
            setElementDimension(player, 0) -- *** DIMENSION ZURÜCKSETZEN ***
            setElementPosition(player, exteriorPos.x, exteriorPos.y, exteriorPos.z)
            removeElementData(player, "currentHouseExterior")
            fadeCamera(player, true, 0.5)
        end
    end, 500, 1)
end)

-- Command /sellhouse (unverändert)
addCommandHandler("sellhouse", function(player, command)
    local playerAccountID = getElementData(player, "account_id"); if not playerAccountID then outputChatBox("Account-Fehler.", player, 255,0,0); return end; local houseID = getElementDimension(player); local interior = getElementInterior(player); if houseID == 0 or interior == 0 then outputChatBox("Du musst dich in deinem Haus befinden.", player, 255, 165, 0); return end; if not existingHouses[houseID] then outputChatBox("Du bist in keinem gültigen Haus-Interior.", player, 255, 165, 0); return end; local db = exports.datenbank:getConnection(); if not db then outputChatBox("DB Fehler.", player, 255, 0, 0); return end; local query = "SELECT price, owner_account_id FROM houses WHERE id = ?"; local result = exports.datenbank:queryDatabase(query, houseID); if not result or not result[1] then outputChatBox("Hausdaten nicht gefunden.", player, 255, 100, 0); return end; local houseData = result[1]; if tonumber(houseData.owner_account_id) ~= playerAccountID then outputChatBox("Du besitzt dieses Haus nicht.", player, 255, 0, 0); return end; local originalPrice = tonumber(houseData.price) or 0; local sellPrice = math.floor(originalPrice * 0.50); triggerClientEvent(player, "showSellConfirmationClient", player, houseID, sellPrice) end)

-- Handler für Verkaufsbestätigung vom Client (unverändert)
addEvent("confirmSellHouse", true)
addEventHandler("confirmSellHouse", root, function(houseID)
    local player = client; local playerAccountID = getElementData(player, "account_id"); local playerName = getPlayerName(player)
    if not playerAccountID or not houseID then return end; local currentDimension = getElementDimension(player); if currentDimension ~= houseID then outputChatBox("Du befindest dich nicht mehr im Haus!", player, 255, 0, 0); return end
    local db = exports.datenbank:getConnection(); if not db then outputChatBox("DB Fehler.", player, 255, 0, 0); return end
    local query = "SELECT price, owner_account_id FROM houses WHERE id = ?"; local result = exports.datenbank:queryDatabase(query, houseID); if not result or not result[1] then outputChatBox("Hausdaten Fehler.", player, 255, 100, 0); return end; local houseData = result[1]
    if tonumber(houseData.owner_account_id) ~= playerAccountID then outputChatBox("Fehler: Besitzrecht geändert!", player, 255, 0, 0); return end
    local originalPrice = tonumber(houseData.price) or 0; local sellPrice = math.floor(originalPrice * 0.50)
    local updateQuery = "UPDATE houses SET owner_account_id = NULL, locked = 1 WHERE id = ? AND owner_account_id = ?"; local success = exports.datenbank:executeDatabase(updateQuery, houseID, playerAccountID)
    outputDebugString(string.format("[HouseServer-SELL] DB Update für Haus #%d (Besitzer: %d): success=%s", houseID, playerAccountID, tostring(success)))
    if success then givePlayerMoney(player, sellPrice); outputChatBox("Haus #"..houseID.." erfolgreich für "..formatMoney(sellPrice).." verkauft!", player, 0, 255, 0); local exteriorPos = getElementData(player, "currentHouseExterior"); if exteriorPos then setElementInterior(player, 0); setElementDimension(player, 0); setElementPosition(player, exteriorPos.x, exteriorPos.y, exteriorPos.z); removeElementData(player, "currentHouseExterior") else local fallbackPos = existingHouses[houseID] or {posX=0,posY=0,posZ=5}; setElementInterior(player, 0); setElementDimension(player, 0); setElementPosition(player, fallbackPos.posX, fallbackPos.posY, fallbackPos.posZ) end; if existingHouses[houseID] then existingHouses[houseID].owner_account_id = nil end; triggerClientEvent(root, "updateHouseVisualStateClient", resourceRoot, houseID, nil, nil)
    else outputDebugString(string.format("[HouseServer-SELL] FEHLER: UPDATE für Haus #%d fehlgeschlagen (executeDatabase gab false zurück). Verkauf abgebrochen.", houseID)); outputChatBox("Fehler beim Verkaufen des Hauses in der Datenbank.", player, 255, 0, 0) end
end)


-- Hilfsfunktion Geld formatieren
function formatMoney(amount) local formatted=string.format("%.0f", amount or 0); local k repeat formatted, k=string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1.%2') until k==0 return "$" .. formatted end

outputDebugString("[HouseSystem] Haus-System (Server - mit Dimensionen & Kauf-Limit) geladen.")