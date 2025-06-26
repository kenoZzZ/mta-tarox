-- tarox_chat/chat_client.lua

-- Event-Handler für lokale Nachrichten (ANGEPASST, um playerName und message getrennt zu empfangen)
addEvent("taroxChat:receiveLocalMessage", true)
addEventHandler("taroxChat:receiveLocalMessage", root,
    function(senderName, message, r, g, b) -- Nimmt jetzt playerName und message getrennt
        -- Lokaler Chat-Präfix und Farbe
        local localChatPrefixColor = "#E0E0E0" -- Hellgrau (oder deine definierte Farbe)
        local nameColorHex = string.format("#%02X%02X%02X", r, g, b)
        local messageColorReset = "#FFFFFF" -- Standard-Nachrichtenfarbe

        local formattedMessage = string.format("%s[Lokal] %s%s%s: %s%s",
                                            localChatPrefixColor,
                                            nameColorHex,
                                            senderName,
                                            messageColorReset, -- Farbe für Doppelpunkt
                                            messageColorReset, -- Farbe für Nachrichtentext
                                            message)

        outputChatBox(formattedMessage, 255, 255, 255, true) -- Basis Weiß, da String Farben enthält
    end
)

-- Event-Handler für globale Nachrichten (MODIFIZIERT: Nimmt nur noch einen formatierten String)
addEvent("taroxChat:receiveFormattedGlobalMessage", true)
addEventHandler("taroxChat:receiveFormattedGlobalMessage", root,
    function(finalFormattedMessage)
        -- finalFormattedMessage kommt jetzt komplett formatiert vom Server
        outputChatBox(finalFormattedMessage, 255, 255, 255, true) -- Basis Weiß, da String Farben enthält
    end
)

--outputDebugString("[Tarox Chat] Chat-System (Client mit Fraktionspräfix & Namensfarbe V3) geladen.")