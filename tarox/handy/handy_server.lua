-- tarox/handy/handy_server.lua
-- Version 2: Interaktion mit Userpanel-Server
-- ANGEPASST V2.1: Keine DB-spezifischen Änderungen notwendig, da Abhängigkeit von Userpanel

-- ID des Handy-Items (muss mit der ID in der Datenbank übereinstimmen)
HANDY_ITEM_ID = 19 -- Beispiel-ID

-- Diese Funktion wird vom Client aufgerufen, wenn das Handy aus dem Inventar benutzt wird
addEvent("onPlayerUseHandyItem", true)
addEventHandler("onPlayerUseHandyItem", root, function()
    local player = client
    if not isElement(player) then return end

    -- Leitet einfach an den Client weiter, um das UI zu öffnen.
    triggerClientEvent(player, "toggleHandyGUI", player)
end)

-- Event-Handler für die Anfrage vom Handy-Client, das Userpanel zu öffnen
addEvent("requestUserPanelDataFromHandy", true)
addEventHandler("requestUserPanelDataFromHandy", root, function()
    local player = client
    if not isElement(player) then return end

    local accountId = getElementData(player, "account_id")
    if not accountId then
        triggerClientEvent(player, "showMessage", player, "Fehler: Account nicht vollständig geladen für Userpanel.", 255,0,0)
        return
    end

    -- Rufe die globale Funktion getPlayerStatistics auf, die dann das
    -- 'showUserPanel' Event an den Client sendet.
    -- Diese Funktion sollte in deinem userpanel_server.lua oder einem globalen Skript existieren.
    if type(_G.getPlayerStatistics) == "function" then -- Überprüfen, ob die globale Funktion existiert
        _G.getPlayerStatistics(player)
    elseif type(getPlayerStatistics) == "function" then -- Fallback, falls nicht in _G, aber lokal verfügbar (unwahrscheinlich hier)
        getPlayerStatistics(player)
    else
        outputDebugString("[HandyServer] FEHLER: Funktion getPlayerStatistics nicht gefunden! Userpanel kann nicht geöffnet werden.")
        triggerClientEvent(player, "showMessage", player, "Fehler: Userpanel-Daten konnten nicht geladen werden (Serverfunktion fehlt).", 255,0,0)
    end
end)


addEventHandler("onResourceStart", resourceRoot, function()
    -- Überprüfung, ob die Abhängigkeit zu getPlayerStatistics erfüllt ist.
    if not _G.getPlayerStatistics and not getPlayerStatistics then
         outputDebugString("[HandyServer] WARNUNG bei onResourceStart: Funktion 'getPlayerStatistics' nicht gefunden. Userpanel-Funktionalität im Handy wird nicht gehen.", 1)
    end
    outputDebugString("[Handy] Handy-System (Server V2.1 - Keine DB Änderungen) geladen.")
end)