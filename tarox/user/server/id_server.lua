-- tarox/user/server/id_server.lua
-- MODIFIED: Added driver's license viewing and showing functionality
-- ANGEPASST V1.1: Verbesserte Fehlerbehandlung für Inventaraktionen

local ID_CARD_ITEM_ID = 17
local ID_CARD_COST = 70
local SHOW_ID_RANGE = 5

local DRIVERS_LICENSE_ITEM_ID = 18
local SHOW_LICENSE_RANGE = 5

function tableToMetadataString(tbl)
    if type(tbl) ~= "table" then return "" end
    local parts = {}
    for key, value in pairs(tbl) do
        local valStr = tostring(value)
        valStr = string.gsub(valStr, "|", "{pipe}")
        valStr = string.gsub(valStr, ":", "{colon}")
        table.insert(parts, tostring(key) .. ":" .. valStr)
    end
    return table.concat(parts, "|")
end

function metadataStringToTable(str)
    if type(str) ~= "string" or str == "" then return {} end
    local tbl = {}
    for part in string.gmatch(str, "([^|]+)") do
        local key, value = string.match(part, "([^:]+):(.+)")
        if key and value then
            value = string.gsub(value, "{pipe}", "|")
            value = string.gsub(value, "{colon}", ":")
            if key == "accountId" or key == "skin" or key == "wanteds" or key == "currentSkin" then -- currentSkin hinzugefügt
                value = tonumber(value) or value
            end
            tbl[key] = value
        end
    end
    return tbl
end

addEventHandler("onResourceStart", resourceRoot, function()
    --outputDebugString("[ID-System & License-Item] Server Logik (V1.1 - DB Fehlerbehandlung) gestartet.")
end)

addEvent("idcard:pedClicked", true)
addEventHandler("idcard:pedClicked", root, function()
    local player = client
    if not isElement(player) then return end

    local hasIDCard, errMsgHas = exports.tarox:hasPlayerItem(player, ID_CARD_ITEM_ID, 1)
    if errMsgHas then -- Annahme: hasPlayerItem gibt einen zweiten Wert bei Fehler zurück
        outputChatBox("Fehler beim Überprüfen des Inventars: " .. errMsgHas, player, 255, 0, 0)
        return
    end

    if hasIDCard then
        outputChatBox("Sie besitzen bereits einen Personalausweis.", player, 255, 165, 0)
        return
    end
    outputChatBox("Guten Tag! Benötigen Sie einen Personalausweis? Die Gebühr beträgt $" .. ID_CARD_COST .. ".", player, 255, 223, 176)
    triggerClientEvent(player, "idcard:showPurchaseConfirmation", player, ID_CARD_COST)
end)

addEvent("idcard:confirmPurchase", true)
addEventHandler("idcard:confirmPurchase", root, function()
    local player = client
    if not isElement(player) then return end

    local hasIDCard, errMsgHas = exports.tarox:hasPlayerItem(player, ID_CARD_ITEM_ID, 1)
    if errMsgHas then
        outputChatBox("Fehler beim Überprüfen des Inventars: " .. errMsgHas, player, 255, 0, 0)
        return
    end
    if hasIDCard then
        outputChatBox("Sie besitzen bereits einen Personalausweis.", player, 255, 165, 0)
        return
    end

    if getPlayerMoney(player) < ID_CARD_COST then
        outputChatBox("Sie haben nicht genügend Geld ($" .. ID_CARD_COST .. ") für den Ausweis.", player, 255, 0, 0)
        return
    end

    takePlayerMoney(player, ID_CARD_COST) -- Annahme: MTA Kernfunktion, keine direkte Fehlerbehandlung hier nötig

    local accountId = getElementData(player, "account_id")
    local playerName = getPlayerName(player)
    local issueDate = os.date("%d.%m.%Y")
    local playerSkin = getElementModel(player)
    local idCardMetadata = {
        name = playerName, accountId = accountId, issued = issueDate, skin = playerSkin,
        serialNumber = string.format("SA-%d-%s", math.random(10000,99999), string.sub(tostring(accountId or 0) .. getRealTime().timestamp, 1, 8))
    }
    local metadataString = tableToMetadataString(idCardMetadata)
    local successGive, giveMsg = exports.tarox:givePlayerItem(player, ID_CARD_ITEM_ID, 1, metadataString)

    if successGive then
        outputChatBox("Personalausweis für $" .. ID_CARD_COST .. " erhalten und im Inventar abgelegt.", player, 0, 200, 50)
        outputServerLog("[ID-System] Personalausweis für " .. playerName .. " (AccID: " .. (accountId or "N/A") .. ") ausgestellt. Meta: " .. metadataString)
    else
        outputChatBox("Fehler bei der Ausstellung des Ausweises: "..(giveMsg or "Inventar voll?").." Das Geld wurde zurückerstattet.", player, 255, 0, 0)
        givePlayerMoney(player, ID_CARD_COST)
        outputServerLog("[ID-System] FEHLER beim Ausstellen des Ausweises für " .. playerName .. ". Geld zurückerstattet. Grund: " .. (giveMsg or "Unbekannt"))
    end
end)

addEvent("idcard:requestShowSelf", true)
addEventHandler("idcard:requestShowSelf", root, function(itemSlot)
    local player = client
    if not isElement(player) then return end
    local inventory = _G.playerInventories and _G.playerInventories[player]

    if not inventory or not inventory[itemSlot] then
        outputChatBox("Fehler: Ausweis nicht im Inventar gefunden (Slot: " .. tostring(itemSlot) .. ").", player, 255, 0, 0)
        return
    end
    local itemData = inventory[itemSlot]
    if tonumber(itemData.item_id) ~= ID_CARD_ITEM_ID then
        outputChatBox("Fehler: Dies ist kein Ausweis.", player, 255, 0, 0)
        return
    end

    local metadataString = itemData.metadata
    if metadataString and metadataString ~= "" then
        local playtimeStr = getElementData(player, "playtime") or "00:00"
        local wanteds = getElementData(player, "wanted") or 0
        local currentSkinID = getElementModel(player)
        local parsedMeta = metadataStringToTable(metadataString)
        parsedMeta.playtime = playtimeStr; parsedMeta.wanteds = wanteds; parsedMeta.currentSkin = currentSkinID
        parsedMeta.name = getPlayerName(player) -- Immer den aktuellen Namen verwenden
        triggerClientEvent(player, "idcard:displayGUI_Client", player, tableToMetadataString(parsedMeta))
    else
        outputChatBox("Fehler: Ausweisdaten nicht lesbar oder beschädigt.", player, 255, 0, 0)
    end
end)

addCommandHandler("showid", function(player, command, targetPlayerNameOrID)
    if not targetPlayerNameOrID then
        outputChatBox("SYNTAX: /" .. command .. " [Name des Spielers oder Account-ID]", player, 200, 200, 0)
        return
    end
    local targetPlayer = nil; local searchStringLower = string.lower(tostring(targetPlayerNameOrID)); local potentialTargets = {}
    for _, p in ipairs(getElementsByType("player")) do
        if getElementData(p, "account_id") then
            if string.find(string.lower(getPlayerName(p)), searchStringLower, 1, true) or
               tostring(getElementData(p, "account_id")) == searchStringLower then
                table.insert(potentialTargets, p)
            end
        end
    end
    if #potentialTargets == 0 then outputChatBox("Spieler '" .. targetPlayerNameOrID .. "' nicht gefunden.", player, 255, 100, 0); return
    elseif #potentialTargets > 1 then
        outputChatBox("Mehrere Spieler gefunden, bitte sei genauer:", player, 255, 165, 0)
        for i=1, math.min(5, #potentialTargets) do local tP = potentialTargets[i]; outputChatBox("  - " .. getPlayerName(tP) .. " (AccID: " .. (getElementData(tP, "account_id") or "N/A") .. ")", player, 200, 200, 200) end
        if #potentialTargets > 5 then outputChatBox("  ... und weitere.", player, 200,200,200) end; return
    else targetPlayer = potentialTargets[1] end

    if not isElement(targetPlayer) then outputChatBox("Spieler '" .. targetPlayerNameOrID .. "' nicht gefunden.", player, 255, 100, 0); return end
    if targetPlayer == player then outputChatBox("Du kannst dir deinen Ausweis selbst über das Inventar ansehen.", player, 200, 200, 0); return end
    local px, py, pz = getElementPosition(player); local tx, ty, tz = getElementPosition(targetPlayer)
    if getDistanceBetweenPoints3D(px, py, pz, tx, ty, tz) > SHOW_ID_RANGE then outputChatBox(getPlayerName(targetPlayer) .. " ist zu weit entfernt.", player, 255, 100, 0); return end

    local sourceInventory = _G.playerInventories and _G.playerInventories[player]; local sourceIdCardSlot = nil
    if sourceInventory then for slot, item in pairs(sourceInventory) do if tonumber(item.item_id) == ID_CARD_ITEM_ID then sourceIdCardSlot = slot; break; end end end

    if not sourceIdCardSlot then outputChatBox("Du besitzt keinen Personalausweis.", player, 255, 100, 0); return end
    local itemData = sourceInventory[sourceIdCardSlot]; local metadataString = itemData.metadata
    if metadataString and metadataString ~= "" then
        local playtimeStr = getElementData(player, "playtime") or "00:00"; local wanteds = getElementData(player, "wanted") or 0; local currentSkinID = getElementModel(player)
        local parsedMeta = metadataStringToTable(metadataString); parsedMeta.playtime = playtimeStr; parsedMeta.wanteds = wanteds; parsedMeta.currentSkin = currentSkinID; parsedMeta.name = getPlayerName(player)
        triggerClientEvent(targetPlayer, "idcard:displayGUI_Client", player, tableToMetadataString(parsedMeta), getPlayerName(player))
        outputChatBox("Du zeigst deinen Ausweis " .. getPlayerName(targetPlayer) .. ".", player, 0, 200, 100)
        outputChatBox(getPlayerName(player) .. " zeigt dir seinen Ausweis.", targetPlayer, 100, 200, 255)
    else outputChatBox("Fehler: Deine Ausweisdaten konnten nicht gelesen werden.", player, 255, 0, 0) end
end)

addEvent("drivelicense:requestShowSelf", true)
addEventHandler("drivelicense:requestShowSelf", root, function(itemSlot)
    local player = client
    if not isElement(player) then return end
    local inventory = _G.playerInventories and _G.playerInventories[player]
    if not inventory or not inventory[itemSlot] then
        outputChatBox("Fehler: Führerschein nicht im Inventar gefunden (Slot: " .. tostring(itemSlot) .. ").", player, 255, 0, 0)
        return
    end
    local itemData = inventory[itemSlot]
    if tonumber(itemData.item_id) ~= DRIVERS_LICENSE_ITEM_ID then
        outputChatBox("Fehler: Dies ist kein Führerschein.", player, 255, 0, 0)
        return
    end
    local metadataString = itemData.metadata
    if metadataString and metadataString ~= "" then
        local parsedMeta = metadataStringToTable(metadataString)
        parsedMeta.name = getPlayerName(player)
        triggerClientEvent(player, "drivelicense:displayGUI_Client", player, tableToMetadataString(parsedMeta))
    else outputChatBox("Fehler: Führerscheindaten nicht lesbar oder beschädigt.", player, 255, 0, 0) end
end)

addCommandHandler("showlicense", function(player, command, targetPlayerNameOrID)
    if not targetPlayerNameOrID then outputChatBox("SYNTAX: /" .. command .. " [Name des Spielers oder Account-ID]", player, 200,200,0); return end
    local targetPlayer = nil; local searchStringLower = string.lower(tostring(targetPlayerNameOrID)); local potentialTargets = {}
    for _, p in ipairs(getElementsByType("player")) do if getElementData(p, "account_id") then if string.find(string.lower(getPlayerName(p)), searchStringLower, 1, true) or tostring(getElementData(p, "account_id")) == searchStringLower then table.insert(potentialTargets, p) end end end
    if #potentialTargets == 0 then outputChatBox("Spieler '" .. targetPlayerNameOrID .. "' nicht gefunden.", player, 255, 100, 0); return
    elseif #potentialTargets > 1 then outputChatBox("Mehrere Spieler gefunden, bitte sei genauer:", player, 255,165,0); for i=1,math.min(5,#potentialTargets)do local tP=potentialTargets[i];outputChatBox("  - "..getPlayerName(tP).." (AccID: "..(getElementData(tP,"account_id")or"N/A")..")",player,200,200,200)end;if #potentialTargets>5 then outputChatBox("  ... und weitere.",player,200,200,200)end;return
    else targetPlayer=potentialTargets[1] end
    if not isElement(targetPlayer)then outputChatBox("Spieler '"..targetPlayerNameOrID.."' nicht gefunden.",player,255,100,0);return end
    if targetPlayer==player then outputChatBox("Du kannst dir deinen Führerschein selbst über das Inventar ansehen.",player,200,200,0);return end
    local px,py,pz=getElementPosition(player);local tx,ty,tz=getElementPosition(targetPlayer)
    if getDistanceBetweenPoints3D(px,py,pz,tx,ty,tz)>SHOW_LICENSE_RANGE then outputChatBox(getPlayerName(targetPlayer).." ist zu weit entfernt.",player,255,100,0);return end
    local sourceInventory = _G.playerInventories and _G.playerInventories[player]; local sourceLicenseSlot = nil
    if sourceInventory then for slot,item in pairs(sourceInventory)do if tonumber(item.item_id)==DRIVERS_LICENSE_ITEM_ID then sourceLicenseSlot=slot;break;end end end
    if not sourceLicenseSlot then outputChatBox("Du besitzt keinen Führerschein.",player,255,100,0);return end
    local itemData = sourceInventory[sourceLicenseSlot]; local metadataString = itemData.metadata
    if metadataString and metadataString ~= "" then
        local parsedMeta = metadataStringToTable(metadataString); parsedMeta.name = getPlayerName(player)
        triggerClientEvent(targetPlayer, "drivelicense:displayGUI_Client", player, tableToMetadataString(parsedMeta), getPlayerName(player))
        outputChatBox("Du zeigst deinen Führerschein "..getPlayerName(targetPlayer)..".",player,0,200,100)
        outputChatBox(getPlayerName(player).." zeigt dir seinen Führerschein.",targetPlayer,100,200,255)
    else outputChatBox("Fehler: Deine Führerscheindaten nicht lesbar.",player,255,0,0) end
end)

--outputDebugString("[ID-System & License-Item] Server Logik (V1.1 - DB Fehlerbehandlung) geladen.")