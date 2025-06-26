-- tarox_chat/chat_server.lua

local LOCAL_CHAT_DISTANCE = 20.0
local GLOBAL_CHAT_PREFIX_COLOR = "#FFD700" -- Goldgelb für "Global"
local LOCAL_CHAT_PREFIX_COLOR = "#E0E0E0"  -- Hellgrau für "Lokal"

local FRACTION_COLORS = {
    ["Police"] = "#007BFF",
    ["Swat"] = "#343A40",
    ["Medic"] = "#28A745",
    ["Cosa Nostra"] = "#FF8C00",
    ["Mocro Mafia"] = "#800080",
    ["Yakuza"] = "#DC3545",
    ["Civil"] = "#FFFFFF"
}
local DEFAULT_FACTION_COLOR = "#FFFFFF"

function getCleanPlayerName(player)
    if not isElement(player) then return "Unknown" end
    local name = getPlayerName(player)
    name = string.gsub(name, "#%x%x%x%x%x%x", "")
    return name
end

addEventHandler("onPlayerChat", root,
    function(message, messageType)
        if messageType == 0 then
            cancelEvent()

            local playerName = getCleanPlayerName(source)
            local r, g, b = getPlayerNametagColor(source)
            if not r then r,g,b = 230,230,230 end

            -- Für lokalen Chat behalten wir die Spieler-Namensfarbe bei,
            -- da hier kein Fraktionspräfix vor dem Namen steht.
            local formattedMessage = string.format("%s[Lokal] %s: %s", LOCAL_CHAT_PREFIX_COLOR, playerName, message)

            local sx, sy, sz = getElementPosition(source)
            local sourceDimension = getElementDimension(source)
            local sourceInterior = getElementInterior(source)

            for _, nearbyPlayer in ipairs(getElementsByType("player")) do
                if getElementDimension(nearbyPlayer) == sourceDimension and getElementInterior(nearbyPlayer) == sourceInterior then
                    local nx, ny, nz = getElementPosition(nearbyPlayer)
                    if getDistanceBetweenPoints3D(sx, sy, sz, nx, ny, nz) <= LOCAL_CHAT_DISTANCE then
                        -- Sende die r,g,b für den Spielernamen mit, damit der Client sie nutzen kann
                        triggerClientEvent(nearbyPlayer, "taroxChat:receiveLocalMessage", source, playerName, message, r, g, b)
                    end
                end
            end
        end
    end
)

addCommandHandler("g",
    function(player, command, ...)
        if not (...) then
            outputChatBox("Syntax: /g [Nachricht]", player, 255, 194, 14)
            return
        end
        local message = table.concat({...}, " ")
        if string.gsub(message, "%s+", "") == "" then
            outputChatBox("Syntax: /g [Nachricht]", player, 255, 194, 14)
            return
        end
        sendGlobalChatMessage(player, message)
    end
)
addCommandHandler("global",
    function(player, command, ...)
        if not (...) then
            outputChatBox("Syntax: /global [Nachricht]", player, 255, 194, 14)
            return
        end
        local message = table.concat({...}, " ")
        if string.gsub(message, "%s+", "") == "" then
            outputChatBox("Syntax: /global [Nachricht]", player, 255, 194, 14)
            return
        end
        sendGlobalChatMessage(player, message)
    end
)

-- Funktion zum Senden einer globalen Nachricht (MODIFIZIERT)
function sendGlobalChatMessage(sender, message)
    if not isElement(sender) then return end

    local playerName = getCleanPlayerName(sender)
    -- Die r,g,b der Nametag-Farbe werden hier nicht mehr direkt für den Namen im Globalchat verwendet,
    -- stattdessen wird die Fraktionsfarbe genutzt.

    local playerFID, playerRank = exports.tarox:getPlayerFractionAndRank(sender)
    local playerFractionName = exports.tarox:getFractionNameFromID(playerFID)

    local nameDisplayColor = DEFAULT_FACTION_COLOR -- Standardfarbe für den Namen (z.B. Weiß)
    local fractionPrefixColored = ""

    if playerFractionName and playerFractionName ~= "" then -- Auch "Civil" kann eine Farbe haben
        nameDisplayColor = FRACTION_COLORS[playerFractionName] or DEFAULT_FACTION_COLOR
        if playerFractionName ~= "Civil" then -- Nur für Nicht-Zivilisten das Fraktionskürzel anzeigen
             fractionPrefixColored = string.format("%s[%s]%s ", nameDisplayColor, playerFractionName, GLOBAL_CHAT_PREFIX_COLOR) -- Fraktion in Fraktionsfarbe, dann zurück zur Global-Farbe
        end
    end

    -- Nachricht zusammenbauen:
    -- [Global-Farbe][Global] [Fraktions-Farbe][Fraktion] [Spieler-Name-Farbe]Spielername: [Nachrichten-Farbe]Nachricht
    local finalFormattedMessage = string.format("%s[Global] %s%s%s%s: %s%s",
                                                GLOBAL_CHAT_PREFIX_COLOR,      -- Farbe für "[Global]"
                                                fractionPrefixColored,         -- Farbiger Fraktionstag (oder leer)
                                                nameDisplayColor,              -- Farbe für den Spielernamen (Fraktionsfarbe oder Default)
                                                playerName,
                                                DEFAULT_FACTION_COLOR,         -- Farbe für den Doppelpunkt (z.B. Weiß)
                                                DEFAULT_FACTION_COLOR,         -- Standardfarbe für die Nachricht (kann durch Farbcodes in der Nachricht überschrieben werden)
                                                message)

    -- Sende die komplett formatierte Nachricht an alle Spieler
    -- Die RGB-Parameter für outputChatBox auf Clientseite sind dann weniger kritisch für die Kernfarben,
    -- da der String schon alles enthält.
    triggerClientEvent(root, "taroxChat:receiveFormattedGlobalMessage", sender, finalFormattedMessage)
end

--outputDebugString("[Tarox Chat] Chat-System (Server mit Fraktionspräfix & Namensfarbe V3) geladen.")