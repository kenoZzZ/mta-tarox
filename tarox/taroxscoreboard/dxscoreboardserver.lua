-- taroxscoreboard/dxscoreboardserver.lua
-- V3: Mit Event-Handler für requestScoreboardRefresh
-- ANGEPASST V3.1: Keine direkten DB-Änderungen notwendig; Überprüfung auf globale Funktionen optional.

-- Timer Intervall erhöhen
local SCOREBOARD_UPDATE_INTERVAL_MS = 15000 -- Von 5000 auf 15000 (15 Sekunden)

-- Custom-Events deklarieren (falls noch nicht global)
-- Diese werden normalerweise in der meta.xml deklariert und hier serverseitig behandelt.
addEvent("onPlayerFactionChange", false)
addEvent("onPlayerRankChange",   false)
addEvent("onWantedChange", false)
addEvent("requestScoreboardRefresh", true)

-- Globale Variable für den Timer
local scoreboardUpdateTimer = nil -- explizit lokal gemacht, um _G zu vermeiden, falls nicht beabsichtigt

-- Funktion zum Sammeln und Senden der Scoreboard-Daten
function updateScoreboardData(eventTriggerSource, ...)
    local players = getElementsByType("player")
    local scoreboardData = {}

    for _, player in ipairs(players) do
        if isElement(player) then -- Sicherstellen, dass das Spieler-Element gültig ist
            -- Zugriff auf _G-Funktionen oder direkte Annahme, dass ElementData korrekt ist
            local group    = getElementData(player, "group") or "Keine Gruppe"
            local rank     = getElementData(player, "rank") or "-"
            local money    = getPlayerMoney(player) or 0
            local playtime = getElementData(player, "playtime") or "00:00" -- Wird von dxscoreboard_playtime gesetzt
            local ping     = getPlayerPing(player) or 0
            local origin   = getElementData(player, "origin") or "de"
            local wanted   = getElementData(player, "wanted") or 0

            if not scoreboardData[group] then
                scoreboardData[group] = {}
            end

            table.insert(scoreboardData[group], {
                name     = getPlayerName(player),
                rank     = rank,
                money    = money,
                playtime = playtime,
                ping     = ping,
                origin   = origin,
                wanted   = wanted
            })
        end
    end

    if eventTriggerSource and getElementType(eventTriggerSource) == "player" then
        triggerClientEvent(eventTriggerSource, "updateScoreboardDataClient", resourceRoot, scoreboardData)
    else
        triggerClientEvent(root, "updateScoreboardDataClient", resourceRoot, scoreboardData)
    end
end

addEventHandler("onResourceStart", resourceRoot, function()
    -- Optionale Überprüfung, ob die Playtime-Funktionen global verfügbar sind, falls nicht schon sichergestellt
    if not _G.formatPlaytime or not _G.loadPlayerPlaytime or not _G.updatePlayerPlaytimeFor then
        outputDebugString("[Scoreboard Server] WARNUNG: Playtime-Funktionen sind nicht global verfügbar. Scoreboard zeigt möglicherweise keine korrekte Spielzeit an.")
    end

    -- Füge eine kleine Verzögerung für den ersten Timer-Start hinzu
    setTimer(function()
        if isTimer(scoreboardUpdateTimer) then
            killTimer(scoreboardUpdateTimer)
        end
        scoreboardUpdateTimer = setTimer(updateScoreboardData, SCOREBOARD_UPDATE_INTERVAL_MS, 0, root)
        outputDebugString("[Scoreboard] Update Timer gestartet (Intervall: " .. (SCOREBOARD_UPDATE_INTERVAL_MS/1000) .. "s) - V3.1 mit Startverzögerung")
    end, 1000, 1) -- Startet den Haupttimer nach 1 Sekunde, einmalig

    --outputDebugString("[Scoreboard] Scoreboard Server (V3.1) initialisiert.")
end)

-- Standard-Events, die ein sofortiges Update an alle auslösen
addEventHandler("onPlayerJoin", root, function() updateScoreboardData(root) end)
addEventHandler("onPlayerQuit", root, function() updateScoreboardData(root) end)
-- onPlayerLoginComplete wird in login_server.lua getriggert, NACHDEM alle Daten geladen wurden.
addEventHandler("onPlayerLoginComplete", root, function() updateScoreboardData(root) end)
addEventHandler("onPlayerMoneyChange", root, function() updateScoreboardData(root) end)

-- Custom-Events, die ein sofortiges Update an alle auslösen
addEventHandler("onPlayerFactionChange", root, function() updateScoreboardData(root) end)
addEventHandler("onPlayerRankChange", root, function() updateScoreboardData(root) end)
addEventHandler("onWantedChange", root, function() updateScoreboardData(root) end)

-- Event-Handler für die explizite Anfrage vom Client, das Scoreboard zu aktualisieren
addEventHandler("requestScoreboardRefresh", root, function()
    if client and getElementType(client) == "player" then
        updateScoreboardData(client)
    end
end)

addEventHandler("onResourceStop", resourceRoot, function()
    if isTimer(scoreboardUpdateTimer) then
        killTimer(scoreboardUpdateTimer)
        scoreboardUpdateTimer = nil
    end
    --outputDebugString("[Scoreboard] Scoreboard Server (V3.1) gestoppt und Timer entfernt.")
end)

--outputDebugString("[Scoreboard] Scoreboard Server (V3.1 - Keine DB Änderungen) geladen.")