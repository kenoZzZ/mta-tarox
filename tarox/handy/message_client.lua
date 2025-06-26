-- tarox/handy/message_client.lua
-- Version 20.9: Korrigiertes Auto-Scrollen (neueste Nachricht unten), "Echtzeit" für neue Timestamps, max. Anzeige von Nachrichten.

local screenW, screenH = guiGetScreenSize()
local localPlayer = getLocalPlayer()
local localPlayerName = getPlayerName(localPlayer)

local dxDrawRectangle = dxDrawRectangle
local dxDrawText = dxDrawText
local dxGetFontHeight = dxGetFontHeight 
local dxGetTextWidth = dxGetTextWidth
local getCursorPosition = getCursorPosition
local isCursorShowing = isCursorShowing
local showCursor = showCursor
local guiSetInputMode = guiSetInputMode
local getRealTime = getRealTime 
local playSoundFrontEnd = playSoundFrontEnd

_G.isMessageGUIOpen = false

outputDebugString("[MSG_CLIENT V20.9] message_client.lua wird geladen.")


local window = {
    w = screenW * 0.4, h = screenH * 0.55,
    bgColor = tocolor(28, 30, 36, 240),
    headerColor = tocolor(45, 48, 56, 250),
    headerTextColor = tocolor(220, 220, 230),
    headerHeight = 35,
    padding = 10
}
window.x = (screenW - window.w) / 2
window.y = (screenH - window.h) / 2

local contactList = {
    x = window.x + window.padding,
    y = window.y + window.headerHeight + window.padding,
    w = window.w * 0.35 - window.padding * 1.5,
    h = window.h - window.headerHeight - window.padding * 2,
    itemHeight = 35,
    itemSpacing = 3,
    bgColor = tocolor(22, 24, 28, 220),
    itemColor = tocolor(35, 38, 45, 200),
    itemHoverColor = tocolor(50, 53, 60, 210),
    itemSelectedColor = tocolor(0, 100, 180, 220),
    textColor = tocolor(190, 195, 205),
    onlinePlayerTextColor = tocolor(170, 200, 170),
    unreadColor = tocolor(255, 180, 0),
    fontScale = 1.0
}

local sendButtonWidth = 70
local messageInputBoxWidth = window.w * 0.65 - window.padding * 1.5 - sendButtonWidth - 5

local chatArea = {
    x = contactList.x + contactList.w + window.padding,
    y = window.y + window.headerHeight + window.padding,
    w = window.w * 0.65 - window.padding * 1.5,
    h = window.h - window.headerHeight - window.padding * 3 - 35 - 5 - 10, 
    historyBgColor = tocolor(22, 24, 28, 220),
    sentMsgColor = tocolor(170, 210, 170),
    receivedMsgColor = tocolor(200, 200, 210),
    timestampColor = tocolor(120, 120, 130),
    messageFontScale = 1.0 
}

local messageInputBox = {
    h = 35,
    bgColor = tocolor(40, 42, 50, 220),
    textColor = tocolor(220,220,220),
    placeholderColor = tocolor(150,150,150)
}
messageInputBox.y = chatArea.y + chatArea.h + 10 
messageInputBox.x = chatArea.x
messageInputBox.w = messageInputBoxWidth

local sendButton = {
    x = messageInputBox.x + messageInputBox.w + 5,
    y = messageInputBox.y,
    w = sendButtonWidth,
    h = messageInputBox.h,
    text = "Senden",
    bgColor = tocolor(0, 130, 190, 220),
    hoverColor = tocolor(0, 150, 220, 230),
    textColor = tocolor(240, 240, 240)
}

local conversationsData = {}
local currentChatPartnerAccId = nil
local currentChatPartnerName = "Wähle einen Chat"
-- Jedes Element: { sender, senderAccId, text, timestampForDisplay (timeTable für neue, DB-String für alte), type }
local currentMessageHistory = {} 
local messageInputText = ""
local activeMessageInput = false

local contactScrollOffset = 0
local maxVisibleContacts = 0

local MAX_DISPLAYED_MESSAGES = 27 -- Maximale Anzahl der im Chat angezeigten Nachrichten

local ui_closeButtonMessageGUI = {}
local ui_contactListItems = {}
local ui_messageInput = {}
local ui_chatHistoryArea = {}
local ui_sendButton = {}

local keysToBlockWhenInputActive = {
    ["t"] = true, ["i"] = true, ["u"] = true, ["y"] = true, ["p"] = true
}

local function formatTimestampForDisplay(timestampInput) 
    if not timestampInput then return "??:??" end
    local year, month, day, hour, min, timeDataToFormat

    if type(timestampInput) == "table" then 
        timeDataToFormat = timestampInput
    elseif type(timestampInput) == "string" then 
        local y,m,d,h,mm = string.match(timestampInput, "(%d%d%d%d)%-(%d%d)%-(%d%d)%s(%d%d):(%d%d)")
        if y then
            timeDataToFormat = { year = tonumber(y)-1900, month = tonumber(m)-1, monthday = tonumber(d), hour = tonumber(h), minute = tonumber(mm) }
        end
    elseif type(timestampInput) == "number" then 
         timeDataToFormat = getRealTime(timestampInput)
    end

    if not timeDataToFormat then return "??:??" end

    year, month, day, hour, min =
        timeDataToFormat.year + 1900, timeDataToFormat.month + 1, timeDataToFormat.monthday,
        timeDataToFormat.hour, timeDataToFormat.minute

    if not year then return "??:??" end 

    local clientNow = getRealTime() 
    if clientNow.year + 1900 == year and clientNow.month + 1 == month and clientNow.monthday == day then
        return string.format("%02d:%02d", hour, min)
    else
        return string.format("%02d.%02d %02d:%02d", day, month, hour, min)
    end
end

local function approximateTextHeight(text, maxWidth, fontScale, fontName)
    if not text or text == "" or not maxWidth or maxWidth <= 0 then return (type(dxGetFontHeight) == "function" and dxGetFontHeight(fontScale, fontName)) or 12 end
    local fontHeight = 12; if type(dxGetFontHeight) == "function" then fontHeight = dxGetFontHeight(fontScale, fontName) or 12 end
    if fontHeight <= 0 then fontHeight = 12 end
    local useDxGetTextWidth = type(dxGetTextWidth) == "function"; local averageCharWidth = 7
    if useDxGetTextWidth then local sT = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"; local sW = dxGetTextWidth(sT, fontScale, fontName); if sW and sW > 0 then averageCharWidth = sW / string.len(sT) end end
    if averageCharWidth <= 0 then averageCharWidth = 7 end; local charsPerLineEstimate = math.floor(maxWidth / averageCharWidth)
    if charsPerLineEstimate <= 0 then charsPerLineEstimate = 1 end; local lineCountEstimate = 0; local words = {}; for word in string.gmatch(text, "[^%s]+") do table.insert(words, word) end
    if #words > 0 then local currentLineWidth = 0; for i, word in ipairs(words) do local wordWidth = useDxGetTextWidth and dxGetTextWidth(word, fontScale, fontName) or (string.len(word) * averageCharWidth); local spaceWidth = useDxGetTextWidth and dxGetTextWidth(" ", fontScale, fontName) or averageCharWidth
            if i > 1 then if currentLineWidth + spaceWidth + wordWidth > maxWidth then lineCountEstimate = lineCountEstimate + 1; currentLineWidth = wordWidth else currentLineWidth = currentLineWidth + spaceWidth + wordWidth end
            else if wordWidth > maxWidth then lineCountEstimate = lineCountEstimate + math.ceil(wordWidth / maxWidth); currentLineWidth = wordWidth % maxWidth else currentLineWidth = wordWidth end end end
        if currentLineWidth > 0 then lineCountEstimate = lineCountEstimate + 1 end
    else lineCountEstimate = math.ceil((useDxGetTextWidth and dxGetTextWidth(text, fontScale, fontName) or (string.len(text) * averageCharWidth)) / maxWidth) end
    if lineCountEstimate == 0 then lineCountEstimate = 1 end; local estimatedHeight = lineCountEstimate * fontHeight; return math.max(fontHeight, estimatedHeight)
end

local function renderMessageGUI()
    if not _G.isMessageGUIOpen then return end
    local win = window; dxDrawRectangle(win.x, win.y, win.w, win.h, win.bgColor); dxDrawRectangle(win.x, win.y, win.w, win.headerHeight, win.headerColor); dxDrawText("Handy Nachrichten", win.x, win.y, win.x + win.w, win.y + win.headerHeight, win.headerTextColor, 1.1, "default-bold", "center", "center")
    dxDrawRectangle(contactList.x, contactList.y, contactList.w, contactList.h, contactList.bgColor); maxVisibleContacts = math.floor(contactList.h / (contactList.itemHeight + contactList.itemSpacing)); ui_contactListItems = {}
    if #conversationsData == 0 then dxDrawText("Keine Chats / Spieler online", contactList.x, contactList.y, contactList.x + contactList.w, contactList.y + contactList.h, contactList.textColor, contactList.fontScale, "default", "center", "center")
    else local contactY = contactList.y; for i = 1, maxVisibleContacts do local index = i + contactScrollOffset; if conversationsData[index] then local convo = conversationsData[index]; local itemBg = contactList.itemColor
                if convo.partnerAccId == currentChatPartnerAccId then itemBg = contactList.itemSelectedColor elseif isCursorOverElement({x=contactList.x, y=contactY, w=contactList.w, h=contactList.itemHeight}) then itemBg = contactList.itemHoverColor end
                dxDrawRectangle(contactList.x, contactY, contactList.w, contactList.itemHeight, itemBg); local displayName = convo.partnerName or "Unbekannt"; local displayColor = convo.isConversation and contactList.textColor or contactList.onlinePlayerTextColor
                dxDrawText(displayName, contactList.x + 5, contactY, contactList.x + contactList.w - (convo.unreadCount > 0 and 25 or 5), contactY + contactList.itemHeight, displayColor, contactList.fontScale, "default", "left", "center", true)
                if convo.unreadCount and convo.unreadCount > 0 then dxDrawText(tostring(convo.unreadCount), contactList.x + contactList.w - 25, contactY, contactList.x + contactList.w - 5, contactY + contactList.itemHeight, contactList.unreadColor, contactList.fontScale, "default-bold", "right", "center")
                elseif not convo.isConversation then dxDrawText("Online", contactList.x + contactList.w - 45, contactY, contactList.x + contactList.w - 5, contactY + contactList.itemHeight, tocolor(120,180,120,180), contactList.fontScale - 0.1, "default", "right", "center") end
                ui_contactListItems[index] = {x=contactList.x, y=contactY, w=contactList.w, h=contactList.itemHeight, accId = convo.partnerAccId, name = convo.partnerName}; contactY = contactY + contactList.itemHeight + contactList.itemSpacing else break end end end
    
    dxDrawRectangle(chatArea.x, chatArea.y, chatArea.w, chatArea.h, chatArea.historyBgColor); 
    ui_chatHistoryArea = {x = chatArea.x, y = chatArea.y, w = chatArea.w, h = chatArea.h}
    
    local currentYToDraw = chatArea.y + chatArea.h - 5 -- Startet am unteren Rand

    -- Bestimme, welche Nachrichten gezeichnet werden (die letzten MAX_DISPLAYED_MESSAGES)
    local startIndexInHistory = math.max(1, #currentMessageHistory - MAX_DISPLAYED_MESSAGES + 1)
    
    for i = #currentMessageHistory, startIndexInHistory, -1 do
        local msg = currentMessageHistory[i]
        if msg then
            local prefix = ""; local mainText = msg.text or ""; 
            local msgColor = chatArea.receivedMsgColor; local textAlign = "left"
            if msg.senderAccId == getElementData(localPlayer, "account_id") then 
                prefix = ""; msgColor = chatArea.sentMsgColor; textAlign = "right" 
            else 
                prefix = (msg.sender or "Unbekannt") .. ": " 
            end
            local textToDisplay = (textAlign == "left" and prefix or "") .. mainText; 
            local widthForHeightCalc = ui_chatHistoryArea.w - 10
            
            local timeStrToUse = formatTimestampForDisplay(msg.timestampForDisplay) 
            local timeStrWidth = dxGetTextWidth(timeStrToUse, 1.0, "default") or 30 
            local availableTextWidth = widthForHeightCalc - timeStrWidth - 10 

            local fontForHeightCalc = "default"; local scaleForHeightCalc = chatArea.messageFontScale; 
            local textHeight = approximateTextHeight(textToDisplay, availableTextWidth, scaleForHeightCalc, fontForHeightCalc)
            
            currentYToDraw = currentYToDraw - textHeight 
            if i < #currentMessageHistory then currentYToDraw = currentYToDraw - 3 end -- Abstand zwischen Nachrichten

            if currentYToDraw < chatArea.y then -- Stoppe, wenn wir über den oberen Rand hinausgehen würden
                currentYToDraw = currentYToDraw + textHeight + (i < #currentMessageHistory and 3 or 0) -- Korrigiere Y für die letzte sichtbare
                break 
            end
            
            local timeStrHeight = dxGetFontHeight(1.0, "default") or 12 

            if textAlign == "left" then 
                dxDrawText(textToDisplay, chatArea.x + 5, currentYToDraw, chatArea.x + 5 + availableTextWidth, currentYToDraw + textHeight, msgColor, scaleForHeightCalc, fontForHeightCalc, "left", "top", true, true)
                dxDrawText(timeStrToUse, chatArea.x + chatArea.w - 5 - timeStrWidth, currentYToDraw + math.max(0, textHeight - timeStrHeight), chatArea.x + chatArea.w - 5, currentYToDraw + textHeight , chatArea.timestampColor, 1.0, "default", "left", "top")
            else 
                local mainTextWidth = dxGetTextWidth(mainText, scaleForHeightCalc, fontForHeightCalc); 
                local textDrawX = chatArea.x + chatArea.w - 5 - mainTextWidth;
                dxDrawText(mainText, textDrawX, currentYToDraw, textDrawX + mainTextWidth, currentYToDraw + textHeight, msgColor, scaleForHeightCalc, fontForHeightCalc, "left", "top", true, true)
                dxDrawText(timeStrToUse, chatArea.x + 5 , currentYToDraw + math.max(0, textHeight - timeStrHeight), chatArea.x + 5 + timeStrWidth, currentYToDraw + textHeight , chatArea.timestampColor, 1.0, "default", "left", "top")
            end
        end
    end

    if not currentChatPartnerAccId then dxDrawText("Wähle links einen Chat aus.", chatArea.x, chatArea.y, chatArea.x + chatArea.w, chatArea.y + chatArea.h, contactList.textColor, 1.0, "default", "center", "center")
    elseif #currentMessageHistory == 0 then dxDrawText("Beginne eine neue Unterhaltung mit\n"..(currentChatPartnerName or "Unbekannt"), chatArea.x, chatArea.y, chatArea.x + chatArea.w, chatArea.y + chatArea.h, contactList.textColor, 0.9, "default", "center", "center",true) end
    
    ui_messageInput = messageInputBox; dxDrawRectangle(messageInputBox.x, messageInputBox.y, messageInputBox.w, messageInputBox.h, messageInputBox.bgColor)
    local inputText = messageInputText .. (activeMessageInput and "_" or ""); local inputPlaceholderColor = messageInputText == "" and not activeMessageInput and messageInputBox.placeholderColor or messageInputBox.textColor
    if messageInputText == "" and not activeMessageInput then inputText = currentChatPartnerAccId and "Nachricht an "..currentChatPartnerName or "Wähle Chatpartner" end
    dxDrawText(inputText, messageInputBox.x + 5, messageInputBox.y, messageInputBox.x + messageInputBox.w - 5, messageInputBox.y + messageInputBox.h, inputPlaceholderColor, 1.0, "default", "left", "center", true)
    ui_sendButton = sendButton; local currentSendBg = sendButton.bgColor; if isCursorOverElement(ui_sendButton) then currentSendBg = sendButton.hoverColor end
    dxDrawRectangle(sendButton.x, sendButton.y, sendButton.w, sendButton.h, currentSendBg); dxDrawText(sendButton.text, sendButton.x, sendButton.y, sendButton.x + sendButton.w, sendButton.y + sendButton.h, sendButton.textColor, 1.0, "default-bold", "center", "center")
    ui_closeButtonMessageGUI.w = 30; ui_closeButtonMessageGUI.h = 30; ui_closeButtonMessageGUI.x = window.x + window.w - ui_closeButtonMessageGUI.w - 5; ui_closeButtonMessageGUI.y = window.y + (window.headerHeight - ui_closeButtonMessageGUI.h) / 2
    local closeBtnColor = tocolor(180, 50, 50, 220); if isCursorOverElement(ui_closeButtonMessageGUI) then closeBtnColor = tocolor(210, 70, 70, 230) end
    dxDrawRectangle(ui_closeButtonMessageGUI.x, ui_closeButtonMessageGUI.y, ui_closeButtonMessageGUI.w, ui_closeButtonMessageGUI.h, closeBtnColor); dxDrawText("X", ui_closeButtonMessageGUI.x, ui_closeButtonMessageGUI.y, ui_closeButtonMessageGUI.x + ui_closeButtonMessageGUI.w, ui_closeButtonMessageGUI.y + ui_closeButtonMessageGUI.h, tocolor(255,255,255), 1.1, "default-bold", "center", "center")
end

function isCursorOverElement(elementData)
    if not isCursorShowing() or not elementData then return false end
    local cX, cY = getCursorPosition()
    if not cX then return false end
    local absCX, absCY = cX * screenW, cY * screenH
    return absCX >= elementData.x and absCX <= elementData.x + elementData.w and
           absCY >= elementData.y and absCY <= elementData.y + elementData.h
end

local function onClientKeyHandler_MessageInputBlock(key, press)
    if not _G.isMessageGUIOpen or not activeMessageInput then
        return 
    end
    if keysToBlockWhenInputActive[key] and press then cancelEvent() return end
    if key == "escape" and press then closeMessageSystemGUI(); cancelEvent(); return end
end

function setInputActive(isActive)
    if isActive == activeMessageInput then return end; activeMessageInput = isActive
    if isActive then guiSetInputMode("no_binds_when_editing")
    else if not _G.isInventoryVisible and not _G.isHandyGUIVisible and not (_G.isPedGuiOpen == true) then guiSetInputMode("allow_binds") end end
end

function openMessageSystemGUI()
    if _G.isMessageGUIOpen then return end; _G.isMessageGUIOpen = true; messageInputText = ""
    outputDebugString("[MSG_CLIENT V20.9] GUI GEÖFFNET")
    triggerServerEvent("messageSystem:requestConversations", localPlayer)
    addEventHandler("onClientRender", root, renderMessageGUI)
    addEventHandler("onClientClick", root, handleMessageGUIClick)
    addEventHandler("onClientKey", root, onClientKeyHandler_MessageInputBlock, true) 
    addEventHandler("onClientKey", root, handleMessageGUIKey_NormalPriority) 
    addEventHandler("onClientCharacter", root, handleMessageGUICharacter)
    -- Binde das Scrollen nur noch an die Kontaktliste, da der Chat nicht mehr manuell gescrollt wird
    bindKey("mouse_wheel_up", "down", scrollContactsOnly); 
    bindKey("mouse_wheel_down", "down", scrollContactsOnly)
    if not isCursorShowing() then showCursor(true) end; setInputActive(false) 
end

function closeMessageSystemGUI()
    if not _G.isMessageGUIOpen then return end; _G.isMessageGUIOpen = false; setInputActive(false)
    outputDebugString("[MSG_CLIENT V20.9] GUI GESCHLOSSEN")
    removeEventHandler("onClientRender", root, renderMessageGUI)
    removeEventHandler("onClientClick", root, handleMessageGUIClick)
    removeEventHandler("onClientKey", root, onClientKeyHandler_MessageInputBlock, true)
    removeEventHandler("onClientKey", root, handleMessageGUIKey_NormalPriority)
    removeEventHandler("onClientCharacter", root, handleMessageGUICharacter)
    unbindKey("mouse_wheel_up", "down", scrollContactsOnly); 
    unbindKey("mouse_wheel_down", "down", scrollContactsOnly)
    if not _G.isInventoryVisible and not _G.isHandyGUIVisible and not (_G.isPedGuiOpen == true) then showCursor(false) end
end

function scrollContactsOnly(key) -- Umbenannt, da nur noch Kontakte scrollen
    if not _G.isMessageGUIOpen then return end; 
    local cX, cY = getCursorPosition(); 
    if not cX then return end
    local absCX, absCY = cX*screenW, cY*screenH

    if absCX >= contactList.x and absCX <= contactList.x+contactList.w and absCY >= contactList.y and absCY <= contactList.y+contactList.h then
        if key=="mouse_wheel_up" then contactScrollOffset=math.max(0,contactScrollOffset-1) 
        elseif key=="mouse_wheel_down" and #conversationsData>maxVisibleContacts then contactScrollOffset=math.min(math.max(0,#conversationsData-maxVisibleContacts),contactScrollOffset+1) end
    end
    -- Kein else if für den Chat-Bereich mehr, da dieser nicht mehr manuell gescrollt wird
end

function handleMessageGUIClick(button, state)
    if not _G.isMessageGUIOpen or button ~= "left" or state ~= "up" then return end
    local prevActiveInput = activeMessageInput; local clickedOnInputOrContactOrSend = false
    for index, area in pairs(ui_contactListItems) do if isCursorOverElement(area) then
            if currentChatPartnerAccId ~= area.accId then 
                currentChatPartnerAccId=area.accId; currentChatPartnerName=area.name; 
                messageInputText=""; currentMessageHistory={}; 
                triggerServerEvent("messageSystem:requestMessageHistory",localPlayer,currentChatPartnerAccId); 
                triggerServerEvent("messageSystem:markMessagesAsRead",localPlayer,currentChatPartnerAccId)
                for i,convo in ipairs(conversationsData) do if convo.partnerAccId==currentChatPartnerAccId then conversationsData[i].unreadCount=0; break end end
            end; 
            setInputActive(true); clickedOnInputOrContactOrSend=true; return
    end end
    if isCursorOverElement(ui_messageInput) then setInputActive(true); clickedOnInputOrContactOrSend=true; return end
    if isCursorOverElement(ui_sendButton) then
        if currentChatPartnerAccId and messageInputText~="" then 
            triggerServerEvent("messageSystem:sendMessageToServer",localPlayer,currentChatPartnerAccId,messageInputText); 
            messageInputText=""; playSoundFrontEnd(40)
        elseif not currentChatPartnerAccId then outputChatBox("Bitte wähle zuerst einen Chatpartner aus.",255,150,0) 
        else outputChatBox("Nachricht darf nicht leer sein.",255,150,0) end
        setInputActive(true); clickedOnInputOrContactOrSend=true; return
    end
    if isCursorOverElement(ui_closeButtonMessageGUI) then closeMessageSystemGUI(); return end
    if not clickedOnInputOrContactOrSend and prevActiveInput then setInputActive(false) end
end

function handleMessageGUIKey_NormalPriority(key,press)
    if not _G.isMessageGUIOpen or not activeMessageInput or not press then return end
    if key=="backspace" then if #messageInputText>0 then messageInputText=string.sub(messageInputText,1,-2) end
    elseif key=="enter" then
        if currentChatPartnerAccId and messageInputText~="" then 
            triggerServerEvent("messageSystem:sendMessageToServer",localPlayer,currentChatPartnerAccId,messageInputText); 
            messageInputText=""; playSoundFrontEnd(40)
        elseif not currentChatPartnerAccId then outputChatBox("Bitte wähle zuerst einen Chatpartner aus.",255,150,0) 
        else outputChatBox("Nachricht darf nicht leer sein.",255,150,0) end
    end
end
function handleMessageGUICharacter(char) if not _G.isMessageGUIOpen or not activeMessageInput then return end; if #messageInputText<128 then messageInputText=messageInputText..char end end

addEvent("messageSystem:openGUI",true); addEventHandler("messageSystem:openGUI",root,openMessageSystemGUI)
addEvent("messageSystem:closeGUI",true); addEventHandler("messageSystem:closeGUI",root,closeMessageSystemGUI)

addEvent("messageSystem:receiveConversations",true)
addEventHandler("messageSystem:receiveConversations",root,function(convos)
    conversationsData=convos or {}; 
    table.sort(conversationsData,function(a,b) 
        if a.isConversation and not b.isConversation then return true end 
        if not a.isConversation and b.isConversation then return false end 
        if a.isConversation and b.isConversation then return (a.lastMessageTimestamp or "") > (b.lastMessageTimestamp or "") end 
        return (a.partnerName or "") < (b.partnerName or "") 
    end); contactScrollOffset=0
end)

addEvent("messageSystem:receiveMessageHistory",true)
addEventHandler("messageSystem:receiveMessageHistory",root,function(partnerId,history)
    if currentChatPartnerAccId==partnerId then 
        currentMessageHistory={}; 
        if history and #history>0 then 
            local startIndexForDisplay = math.max(1, #history - MAX_DISPLAYED_MESSAGES + 1)
            for i = startIndexForDisplay, #history do
                local msgData = history[i]
                table.insert(currentMessageHistory,{
                    sender=msgData.sender,senderAccId=msgData.senderAccId,
                    receiver=msgData.receiver,receiverAccId=msgData.receiverAccId,
                    text=msgData.text,
                    timestampForDisplay=msgData.timestamp, 
                    type=(msgData.senderAccId==getElementData(localPlayer,"account_id")and"sent"or"received")
                })
            end 
        end; 
        outputDebugString("[MSG_CLIENT V20.9] receiveMessageHistory: " .. #currentMessageHistory .. " (max. " .. MAX_DISPLAYED_MESSAGES .. ") Nachrichten für " .. partnerId .. " geladen.") 
    end
end)

addEvent("messageSystem:sentMessageUpdate",true)
addEventHandler("messageSystem:sentMessageUpdate",root,function(receiverAccId,receiverName,messageText,serverUnixTimestamp) 
    local clientSendTimeTable = getRealTime() 
    if currentChatPartnerAccId==receiverAccId then 
        table.insert(currentMessageHistory,{
            sender=localPlayerName,senderAccId=getElementData(localPlayer,"account_id"),
            receiver=receiverName,receiverAccId=receiverAccId,
            text=messageText,
            timestampForDisplay = clientSendTimeTable, 
            type="sent"
        }); 
        if #currentMessageHistory > MAX_DISPLAYED_MESSAGES then
            table.remove(currentMessageHistory, 1)
        end
    end
    triggerServerEvent("messageSystem:requestConversations",localPlayer)
end)

addEvent("messageSystem:receiveMessageFromServer",true)
addEventHandler("messageSystem:receiveMessageFromServer",root,function(senderName,messageText,serverUnixTimestamp,senderAccId) 
    local clientReceiveTimeTable = getRealTime() 
    local newUnread=true
    if _G.isMessageGUIOpen and currentChatPartnerAccId==senderAccId then 
        table.insert(currentMessageHistory,{
            sender=senderName,senderAccId=senderAccId,
            receiver=localPlayerName,receiverAccId=getElementData(localPlayer,"account_id"),
            text=messageText,
            timestampForDisplay = clientReceiveTimeTable, 
            type="received"
        });
        if #currentMessageHistory > MAX_DISPLAYED_MESSAGES then
            table.remove(currentMessageHistory, 1)
        end
        triggerServerEvent("messageSystem:markMessagesAsRead",localPlayer,senderAccId);
        newUnread=false
    else 
        outputChatBox("Neue SMS von "..senderName..": "..messageText,0,200,255);
        playSoundFrontEnd(10) 
    end
    if _G.isMessageGUIOpen or newUnread then 
        triggerServerEvent("messageSystem:requestConversations",localPlayer) 
    end
end)

addEventHandler("onClientResourceStart",resourceRoot,function()
    _G.isMessageGUIOpen=false;localPlayerName=getPlayerName(localPlayer)
    addEventHandler("onClientPlayerSpawn",localPlayer,function()localPlayerName=getPlayerName(localPlayer)end)
    outputDebugString("[MessageSys] Nachrichten-System (Client V20.9 - Max " .. MAX_DISPLAYED_MESSAGES .. " Nachrichten, kein Scrollen) geladen.")
    if type(_G.dxGetTextHeight)~="function"then outputDebugString("ALARM V20.9: _G.dxGetTextHeight ist 'nil'. Typ: "..type(_G.dxGetTextHeight))end
end)
addEventHandler("onClientResourceStop",resourceRoot,function()closeMessageSystemGUI()end)