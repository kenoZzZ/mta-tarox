-- datenbank.lua (Sichere Version - ohne Fallback-Credentials, mit expliziter Fehler-Rückgabe)

-- Lese die Zugangsdaten AUSSCHLIESSLICH aus der mtaserver.conf
local dbHost = get("*db_host")
local dbName = get("*db_name")
local dbUser = get("*db_user")
local dbPassword = get("*db_pass")
local dbPort = tonumber(get("*db_port"))

if not dbHost or not dbName or not dbUser or not dbPassword or not dbPort then
    outputDebugString("[Datenbank] FATALER FEHLER: Ein oder mehrere Datenbank-Zugangsdaten konnten nicht aus der mtaserver.conf gelesen werden! Bitte Konfiguration prüfen.", 0)
    return false
end

local dbConnectionString = string.format("dbname=%s;host=%s;port=%d", dbName, dbHost, dbPort)
local dbConnection = nil

local function connectToDatabase()
    outputDebugString("[Datenbank] Versuche Verbindung zur Datenbank herzustellen...")
    dbConnection = dbConnect("mysql", dbConnectionString, dbUser, dbPassword)

    if dbConnection then
        outputDebugString("[Datenbank] ✅ Erfolgreich mit der MySQL-Datenbank verbunden.")
        return true
    else
        outputDebugString("[Datenbank] ❌ Fehler: Verbindung zur MySQL-Datenbank fehlgeschlagen! Überprüfe die Zugangsdaten in der mtaserver.conf und die Erreichbarkeit der DB.", 1)
        dbConnection = nil
        return false
    end
end

connectToDatabase()

function getConnection()
    if not dbConnection then
        outputDebugString("[Datenbank] Keine aktive Verbindung vorhanden. Versuche neu zu verbinden...", 2)
        if not connectToDatabase() then
            return nil
        end
    end
    -- Optional: Ein dbPing hier könnte die Verbindung prüfen, erhöht aber den Overhead.
    -- Für kritische Operationen könnte es sinnvoll sein, aber für generelle getConnection
    -- verlassen wir uns erstmal auf das Ergebnis von dbQuery/dbExec.
    return dbConnection
end

function queryDatabase(query, ...)
    local connection = getConnection()
    if not connection then
        outputDebugString("[Datenbank] Query fehlgeschlagen: Keine Datenbankverbindung! Query: " .. query, 2)
        return false, "No database connection" -- Explizite Rückgabe
    end

    local qh = dbQuery(connection, query, ...)
    if not qh then
        local errStr, errNo = dbPoll(nil, 0) -- Versuche, den letzten Fehler zu bekommen
        errStr = errStr or "Unknown dbQuery error"
        outputDebugString(string.format("[Datenbank] dbQuery Fehler: %s (Nr: %s) bei Query: %s", errStr, tostring(errNo or "N/A"), query), 2)
        return false, errStr -- Explizite Rückgabe
    end

    local result, numRows, errStrPoll = dbPoll(qh, -1)
    if not result then
         errStrPoll = errStrPoll or "Unknown dbPoll error"
         outputDebugString(string.format("[Datenbank] dbPoll Fehler: %s bei Query: %s", errStrPoll, query), 2)
         return false, errStrPoll -- Explizite Rückgabe
    end

    return result -- Gibt die Ergebnistabelle oder eine leere Tabelle zurück
end

function executeDatabase(query, ...)
    local connection = getConnection()
    if not connection then
        outputDebugString("[Datenbank] Execute fehlgeschlagen: Keine Datenbankverbindung! Query: " .. query, 2)
        return false, "No database connection" -- Explizite Rückgabe
    end

    local success, affectedRowsOrError, lastInsertId = dbExec(connection, query, ...)
    if not success then
        -- dbExec gibt im Fehlerfall oft 'false' und als zweiten Wert eine Fehlermeldung zurück.
        -- Falls nicht, versuchen wir es mit dbPoll.
        local errStr = type(affectedRowsOrError) == "string" and affectedRowsOrError or "Unknown dbExec error"
        if errStr == "Unknown dbExec error" then
            local _, potentialErrStr = dbPoll(nil, 0)
            if potentialErrStr then errStr = potentialErrStr end
        end
        outputDebugString(string.format("[Datenbank] dbExec Fehler: %s bei Query: %s", errStr, query), 2)
        return false, errStr -- Explizite Rückgabe
    end
    -- Gibt bei Erfolg true, Anzahl der betroffenen Zeilen und die letzte Insert-ID zurück
    return true, affectedRowsOrError, lastInsertId
end

function getLastError()
    local connection = getConnection()
    if not connection then return "Keine Verbindung" end
    local _, errStr = dbPoll(nil, 0)
    return errStr or "Kein Fehler"
end

outputDebugString("[Datenbank] Datenbank-Modul (sicher, mit expliziter Fehler-Rückgabe) geladen.")