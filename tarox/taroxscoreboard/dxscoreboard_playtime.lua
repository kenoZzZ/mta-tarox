-- dxscoreboard_playtime.lua
-- ANGEPASST V1.1: Verbesserte Fehlerbehandlung für Datenbankaufrufe

-- Globale Funktion zum Formatieren
function formatPlaytime(totalMinutes)
    if type(totalMinutes) ~= "number" then
        outputDebugString("[PLAYTIME] WARNUNG: formatPlaytime mit ungültigem Typ aufgerufen: " .. type(totalMinutes))
        return "00:00"
    end
    local hours = math.floor(totalMinutes / 60)
    local minutes = totalMinutes % 60
    return string.format("%02d:%02d", hours, minutes)
end

-- Globale Funktion zum Laden
function loadPlayerPlaytime(player)
    if not isElement(player) then
        outputDebugString("[PLAYTIME] ❌ loadPlayerPlaytime: Ungültiger Spieler!")
        return false, "Invalid player element" -- Fehler signalisieren
    end
    local accountID = getElementData(player, "account_id")
    if not accountID then
        outputDebugString("[PLAYTIME] ❌ loadPlayerPlaytime: Keine account_id für " .. getPlayerName(player))
        return false, "No account_id" -- Fehler signalisieren
    end

    local playtimeResult, errMsg = exports.datenbank:queryDatabase("SELECT total_minutes FROM playtime WHERE account_id=? LIMIT 1", accountID)
    local totalMinutes = 0

    if not playtimeResult then
        outputDebugString("[PLAYTIME] ❌ DB-Fehler beim Laden der Spielzeit für AccID " .. accountID .. ": " .. (errMsg or "Unbekannt"))
        -- Standardwerte setzen, aber Fehler signalisieren
        setElementData(player, "totalPlaytime", 0)
        setElementData(player, "playtime", formatPlaytime(0))
        return false, "Database query error"
    end

    if playtimeResult and playtimeResult[1] then
        totalMinutes = tonumber(playtimeResult[1].total_minutes) or 0
    else
        outputDebugString("[PLAYTIME] Kein Eintrag für accID=" .. accountID .. " -> Starte mit 0 Min.")
        -- Kein Fehler, nur keine Daten, Standard (0) wird verwendet.
    end
    setElementData(player, "totalPlaytime", totalMinutes)
    setElementData(player, "playtime", formatPlaytime(totalMinutes))
    return true, "Success" -- Erfolg signalisieren
end
_G.loadPlayerPlaytime = loadPlayerPlaytime -- Global machen für login_server

-- Globale Funktion zum Speichern/Aktualisieren
function updatePlayerPlaytimeFor(player, isQuitting)
    isQuitting = isQuitting or false
    if not isElement(player) then return false, "Invalid player element" end
    local accountID = getElementData(player, "account_id")
    if not accountID then return false, "No account_id" end

    local oldMinutes = getElementData(player, "totalPlaytime")
    if type(oldMinutes) ~= "number" then
        outputDebugString("[PLAYTIME] WARNUNG: oldMinutes ist kein number für accID=" .. accountID .. ". Typ: " .. type(oldMinutes))
        local loadSuccess, loadMsg = loadPlayerPlaytime(player) -- Versuche neu zu laden
        if not loadSuccess then
            outputDebugString("[PLAYTIME] updatePlayerPlaytimeFor: Fehler beim Neuladen der Spielzeit: " .. loadMsg)
            return false, "Failed to reload playtime"
        end
        oldMinutes = getElementData(player, "totalPlaytime") or 0
    end

    local newMinutes = oldMinutes
    if not isQuitting then
        newMinutes = oldMinutes + 1
        setElementData(player, "totalPlaytime", newMinutes)
        setElementData(player, "playtime", formatPlaytime(newMinutes))
    end

    if newMinutes == nil then
         outputDebugString(string.format("[PLAYTIME] VERHINDERT: Speichern von nil für accID=%s.", tostring(accountID)))
         return false, "newMinutes is nil"
    end
    if isQuitting and newMinutes == 0 and oldMinutes == 0 then
         outputDebugString(string.format("[PLAYTIME] VERHINDERT: Speichern von 0 für accID=%s beim Verlassen, da oldMinutes bereits 0 war.", tostring(accountID)))
         return true, "No change to save (already 0)"
    end

    if type(newMinutes) ~= "number" then
        outputDebugString("[PLAYTIME] FEHLER: newMinutes ist keine Zahl vor DB Exec für accID=" .. accountID .. ". Breche Speichern ab.")
        return false, "newMinutes is not a number"
    end

    local query = [[
        INSERT INTO playtime (account_id, total_minutes, last_session_end)
        VALUES (?, ?, NOW())
        ON DUPLICATE KEY UPDATE
        total_minutes = VALUES(total_minutes),
        last_session_end = VALUES(last_session_end)
    ]]
    local dbSuccess, dbErrMsg = exports.datenbank:executeDatabase(query, accountID, newMinutes)

    if not dbSuccess then
        outputDebugString(string.format("[PLAYTIME] ❌ DB FEHLER beim Speichern für accID=%s. Fehler: %s", tostring(accountID), tostring(dbErrMsg or "Unbekannt")))
        return false, "Database execute error"
    end
    return true, "Success"
end
_G.updatePlayerPlaytimeFor = updatePlayerPlaytimeFor -- Global machen für login_server

function updatePlaytimeForAllPlayersRegularly()
    for _, plr in ipairs(getElementsByType("player")) do
        if getElementData(plr, "account_id") then
            updatePlayerPlaytimeFor(plr, false) -- Fehlerbehandlung ist in der Funktion
        end
    end
end

setTimer(updatePlaytimeForAllPlayersRegularly, 60000, 0)

addEventHandler("onResourceStart", resourceRoot, function()
    local db_check = exports.datenbank:getConnection()
    if not db_check then
        outputDebugString("[Playtime] WARNUNG bei onResourceStart: Keine DB-Verbindung! Spielzeit kann nicht geladen/gespeichert werden.", 1)
    end
    --outputDebugString("[Playtime] Playtime Script (V1.1 - Robuste DB-Fehlerbehandlung) geladen.")
end)