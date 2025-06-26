-- tarox/handy/message_server.lua
-- Version 7.3: Klare Timestamp-Übergabe (Unix für Live, String für History/Konvos)
-- ANGEPASST V7.3.1: Verbesserte Fehlerbehandlung für Datenbankaufrufe

-- Die db-Variable wird nicht mehr global benötigt.

function findRecipientPlayer(recipientIdentifier)
    local targetPlayer = nil
    local recipientID = tonumber(recipientIdentifier)
    if recipientID then
        for _, playerElement in ipairs(getElementsByType("player")) do
            if isElement(playerElement) and getElementData(playerElement, "account_id") == recipientID then
                targetPlayer = playerElement
                break
            end
        end
    end
    if not targetPlayer then
        targetPlayer = getPlayerFromName(recipientIdentifier)
    end
    return targetPlayer
end

addEvent("messageSystem:sendMessageToServer", true)
addEventHandler("messageSystem:sendMessageToServer", root, function(recipientIdentifier, messageText)
    local senderPlayer = client
    outputDebugString("[MSG_SERVER V7.3.1] sendMessageToServer: Von " .. getPlayerName(senderPlayer) .. " an '" .. tostring(recipientIdentifier) .. "'. Text: " .. messageText)

    if not isElement(senderPlayer) then
        outputDebugString("[MSG_SERVER V7.3.1] FEHLER: senderPlayer ist kein valides Element.")
        return
    end
    local senderAccId = getElementData(senderPlayer, "account_id")
    if not senderAccId then
        outputDebugString("[MSG_SERVER V7.3.1] FEHLER: senderAccId nicht gefunden für " .. getPlayerName(senderPlayer))
        return
    end

    local senderName = getPlayerName(senderPlayer)
    messageText = string.sub(tostring(messageText), 1, 128)
    recipientIdentifier = tostring(recipientIdentifier)

    if string.gsub(messageText, "%s+", "") == "" then
        outputChatBox("Du kannst keine leere Nachricht senden.", senderPlayer, 255, 100, 0)
        return
    end
    if string.gsub(recipientIdentifier, "%s+", "") == "" then
        outputChatBox("Bitte gib einen Empfänger an.", senderPlayer, 255, 100, 0)
        return
    end

    local targetPlayerElement = findRecipientPlayer(recipientIdentifier)
    local receiverAccId = nil
    local receiverNameForDB = recipientIdentifier

    if isElement(targetPlayerElement) then
        receiverAccId = getElementData(targetPlayerElement, "account_id")
        receiverNameForDB = getPlayerName(targetPlayerElement)
    else
        local userLookupResult, errMsgUser = exports.datenbank:queryDatabase("SELECT id, username FROM account WHERE username = ? OR id = ? LIMIT 1", recipientIdentifier, tonumber(recipientIdentifier) or -1)
        if not userLookupResult then
            outputChatBox("Empfänger '" .. recipientIdentifier .. "' nicht gefunden (DB Fehler).", senderPlayer, 255, 100, 0)
            outputDebugString("[MSG_SERVER V7.3.1] DB-Fehler bei Empfängersuche: " .. (errMsgUser or "Unbekannt"))
            return
        end
        if userLookupResult and userLookupResult[1] then
            receiverAccId = tonumber(userLookupResult[1].id)
            receiverNameForDB = userLookupResult[1].username
        else
            outputChatBox("Empfänger '" .. recipientIdentifier .. "' nicht in der Datenbank gefunden.", senderPlayer, 255, 100, 0)
            return
        end
    end

    if not receiverAccId then
        outputChatBox("Empfänger-Account-ID konnte nicht ermittelt werden.", senderPlayer, 255, 100, 0)
        return
    end

    local isReadStatus = 0
    if isElement(targetPlayerElement) and targetPlayerElement == senderPlayer then
        isReadStatus = 1 -- Nachrichten an sich selbst sind immer gelesen
    end

    local insertSuccess, insertErrMsg = exports.datenbank:executeDatabase("INSERT INTO handy_messages (sender_acc_id, receiver_acc_id, message_text, timestamp, is_read) VALUES (?, ?, ?, NOW(), ?)",
        senderAccId, receiverAccId, messageText, isReadStatus)

    if not insertSuccess then
        outputChatBox("Fehler beim Senden der Nachricht (Datenbankfehler).", senderPlayer, 255, 0, 0)
        outputDebugString("[MSG_SERVER V7.3.1] FEHLER DB Insert für Nachricht: " .. (insertErrMsg or "Unbekannt"))
        return
    end
    outputDebugString("[MSG_SERVER V7.3.1] Nachricht in DB gespeichert.")

    local serverSendUnixTimestamp = getRealTime().timestamp

    outputDebugString("[MSG_SERVER V7.3.1] Trigger sentMessageUpdate an " .. senderName)
    triggerClientEvent(senderPlayer, "messageSystem:sentMessageUpdate", senderPlayer, receiverAccId, receiverNameForDB, messageText, serverSendUnixTimestamp)

    if isElement(targetPlayerElement) then
        if targetPlayerElement ~= senderPlayer then
            outputDebugString("[MSG_SERVER V7.3.1] Trigger receiveMessageFromServer an " .. receiverNameForDB)
            triggerClientEvent(targetPlayerElement, "messageSystem:receiveMessageFromServer", senderPlayer, senderName, messageText, serverSendUnixTimestamp, senderAccId)
        end
        outputChatBox("Nachricht an " .. receiverNameForDB .. " gesendet.", senderPlayer, 0, 220, 150)
    else
        outputChatBox("Nachricht an " .. receiverNameForDB .. " (offline) gesendet und gespeichert.", senderPlayer, 0, 220, 150)
    end
end)

addEvent("messageSystem:requestConversations", true)
addEventHandler("messageSystem:requestConversations", root, function()
    local player = client
    if not isElement(player) then return end
    local accId = getElementData(player, "account_id")
    if not accId then return end
    outputDebugString("[MSG_SERVER V7.3.1] requestConversations von " .. getPlayerName(player))

    local query_revised = [[
        SELECT
            OtherUser.username AS partner_name,
            OtherUser.id AS partner_acc_id,
            MAX(msg.timestamp) AS last_message_time,
            (SELECT message_text FROM handy_messages WHERE message_id = MAX(msg.message_id)) as last_message_text,
            SUM(CASE WHEN msg.receiver_acc_id = ? AND msg.is_read = 0 THEN 1 ELSE 0 END) as unread_count
        FROM handy_messages msg
        JOIN account AS Sender ON msg.sender_acc_id = Sender.id
        JOIN account AS Receiver ON msg.receiver_acc_id = Receiver.id
        JOIN account AS OtherUser ON OtherUser.id = IF(msg.sender_acc_id = ?, msg.receiver_acc_id, msg.sender_acc_id)
        WHERE (msg.sender_acc_id = ? OR msg.receiver_acc_id = ?)
        GROUP BY OtherUser.id, OtherUser.username
        ORDER BY last_message_time DESC
    ]]

    local conversationsResult, errMsgConv = exports.datenbank:queryDatabase(query_revised, accId, accId, accId, accId)
    local conversations = {}
    local processedPartnerIds = {}

    if not conversationsResult then
        outputDebugString("[MSG_SERVER V7.3.1] DB-Fehler beim Abrufen der Konversationen für AccID " .. accId .. ": " .. (errMsgConv or "Unbekannt"))
        -- Sende eine leere Liste oder eine Fehlermeldung an den Client
        triggerClientEvent(player, "messageSystem:receiveConversations", player, {})
        return
    end

    if conversationsResult and #conversationsResult > 0 then
        for _, row in ipairs(conversationsResult) do
            local unread = 0
            local partnerAccIdNum = tonumber(row.partner_acc_id)
            if partnerAccIdNum and partnerAccIdNum ~= accId then
                unread = tonumber(row.unread_count) or 0
            end
            table.insert(conversations, {
                partnerName = row.partner_name, partnerAccId = partnerAccIdNum,
                lastMessageTimestamp = row.last_message_time,
                lastMessageText = row.last_message_text or "...",
                unreadCount = unread, isConversation = true
            })
            if partnerAccIdNum then processedPartnerIds[partnerAccIdNum] = true end
        end
    end

    for _, p_online_element in ipairs(getElementsByType("player")) do
        if isElement(p_online_element) then
            local pAccId_online = getElementData(p_online_element, "account_id")
            if pAccId_online then
                local pName_online = getPlayerName(p_online_element)
                if pAccId_online ~= accId and not processedPartnerIds[pAccId_online] then
                    table.insert(conversations, {
                        partnerName = pName_online, partnerAccId = pAccId_online,
                        lastMessageTimestamp = nil, lastMessageText = "Online",
                        unreadCount = 0, isConversation = false
                    })
                end
            end
        end
    end
    triggerClientEvent(player, "messageSystem:receiveConversations", player, conversations)
end)


addEvent("messageSystem:requestMessageHistory", true)
addEventHandler("messageSystem:requestMessageHistory", root, function(partnerAccId)
    local player = client
    if not isElement(player) then return end
    local accId = getElementData(player, "account_id")
    if not accId or not partnerAccId then return end
    outputDebugString("[MSG_SERVER V7.3.1] requestMessageHistory von " .. getPlayerName(player) .. " für Partner " .. partnerAccId)

    if tonumber(accId) ~= tonumber(partnerAccId) then
        local markReadSuccess, markReadErrMsg = exports.datenbank:executeDatabase("UPDATE handy_messages SET is_read = 1 WHERE receiver_acc_id = ? AND sender_acc_id = ? AND is_read = 0", accId, partnerAccId)
        if not markReadSuccess then
            outputDebugString("[MSG_SERVER V7.3.1] DB-Fehler beim Markieren der Nachrichten als gelesen für AccID " .. accId .. ", Partner " .. partnerAccId .. ": " .. (markReadErrMsg or "Unbekannt"))
            -- Fehler wird geloggt, aber die Historie wird trotzdem geladen
        end
    end

    local query = [[
        SELECT
            m.message_id, s_acc.username AS sender_name, m.sender_acc_id,
            r_acc.username AS receiver_name, m.receiver_acc_id,
            m.message_text, m.timestamp, m.is_read
        FROM handy_messages m
        JOIN account s_acc ON m.sender_acc_id = s_acc.id
        JOIN account r_acc ON m.receiver_acc_id = r_acc.id
        WHERE (m.sender_acc_id = ? AND m.receiver_acc_id = ?) OR (m.sender_acc_id = ? AND m.receiver_acc_id = ?)
        ORDER BY m.timestamp ASC
        LIMIT 50
    ]]
    local historyResult, errMsgHist = exports.datenbank:queryDatabase(query, accId, partnerAccId, partnerAccId, accId)
    local history = {}

    if not historyResult then
        outputDebugString("[MSG_SERVER V7.3.1] DB-Fehler beim Abrufen der Nachrichten-Historie für AccID " .. accId .. ", Partner " .. partnerAccId .. ": " .. (errMsgHist or "Unbekannt"))
        -- Sende eine leere Historie oder eine Fehlermeldung an den Client
        triggerClientEvent(player, "messageSystem:receiveMessageHistory", player, partnerAccId, {})
        return
    end

    if historyResult then
        for _, row in ipairs(historyResult) do
            table.insert(history, {
                id = row.message_id, sender = row.sender_name, senderAccId = tonumber(row.sender_acc_id),
                receiver = row.receiver_name, receiverAccId = tonumber(row.receiver_acc_id),
                text = row.message_text,
                timestamp = row.timestamp,
                is_read = tonumber(row.is_read)
            })
        end
    end
    triggerClientEvent(player, "messageSystem:receiveMessageHistory", player, partnerAccId, history)
end)

addEvent("messageSystem:markMessagesAsRead", true)
addEventHandler("messageSystem:markMessagesAsRead", root, function(partnerAccId)
    local player = client
    if not isElement(player) then return end
    local accId = getElementData(player, "account_id")
    if not accId or not partnerAccId then return end

    if tonumber(accId) ~= tonumber(partnerAccId) then
        local markSuccess, markErrMsg = exports.datenbank:executeDatabase("UPDATE handy_messages SET is_read = 1 WHERE receiver_acc_id = ? AND sender_acc_id = ? AND is_read = 0", accId, partnerAccId)
        if not markSuccess then
            outputDebugString("[MSG_SERVER V7.3.1] DB-Fehler beim Markieren (explizit) der Nachrichten als gelesen für AccID " .. accId .. ", Partner " .. partnerAccId .. ": " .. (markErrMsg or "Unbekannt"))
        end
    end
    triggerEvent("messageSystem:requestConversations", player)
end)

addEventHandler("onResourceStart", resourceRoot, function()
    if not exports.datenbank or not exports.datenbank:getConnection() then
        outputDebugString("FATAL ERROR [MessageSys]: Datenbank-Ressource nicht verfügbar oder Verbindung fehlgeschlagen!")
    else
        outputDebugString("[MessageSys] Nachrichten-System (Server V7.3.1 - DB Fehlerbehandlung) geladen.")
    end
end)