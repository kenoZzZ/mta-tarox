-- tarox/user/server/register_server.lua
-- Verarbeitet Spieler-Registrierungen.
-- ANGEPASST V1.1: Verbesserte Fehlerbehandlung für Datenbankaufrufe

-- Stellt sicher, dass die DB Verbindung besteht (wird jetzt bei Bedarf geholt)

addEvent("registerPlayer", true)
addEventHandler("registerPlayer", root, function(username, password, email)
    outputServerLog("[REGISTER] registerPlayer aufgerufen: " .. tostring(username))

    -- Validierung der Eingaben
    if not username or not password or not email or username == "" or password == "" or email == "" then
        outputServerLog("[REGISTER] ❌ Fehlende Registrierungsdaten!")
        triggerClientEvent(source, "showMessage", source, "Missing registration data!", 255, 0, 0)
        return
    end

    if not string.match(email, "^[%w%+%-%_%.]+@[%w%-%_%.]+%.%w%w+$") then
         outputServerLog("[REGISTER] ❌ Ungültige E-Mail-Adresse: " .. email)
         triggerClientEvent(source, "showMessage", source, "Invalid E-Mail format!", 255, 0, 0)
         return
    end

    if string.len(username) < 3 or string.len(username) > 20 then
         outputServerLog("[REGISTER] ❌ Ungültige Username-Länge: " .. username)
         triggerClientEvent(source, "showMessage", source, "Username must be between 3 and 20 characters!", 255, 0, 0)
         return
    end
     if string.len(password) < 5 then
         outputServerLog("[REGISTER] ❌ Passwort zu kurz für: " .. username)
         triggerClientEvent(source, "showMessage", source, "Password must be at least 5 characters long!", 255, 0, 0)
         return
    end

    -- Prüfen, ob Username in DB schon existiert
    local userExistsResult, userErrMsg = exports.datenbank:queryDatabase("SELECT id FROM account WHERE username=?", username)
    if not userExistsResult then
        outputServerLog("[REGISTER] ❌ DB-Fehler beim Prüfen des Usernames: " .. (userErrMsg or "Unbekannt"))
        triggerClientEvent(source, "showMessage", source, "Registration failed (Database Error)!", 255, 0, 0)
        return
    end
    if userExistsResult and #userExistsResult > 0 then
        outputServerLog("[REGISTER] ❌ Name '" .. username .. "' existiert bereits in der DB!")
        triggerClientEvent(source, "showMessage", source, "Username already exists!", 255, 0, 0)
        return
    end

    -- Prüfen, ob E-Mail in DB schon existiert
    local emailExistsResult, emailErrMsg = exports.datenbank:queryDatabase("SELECT id FROM account WHERE email=?", email)
    if not emailExistsResult then
        outputServerLog("[REGISTER] ❌ DB-Fehler beim Prüfen der E-Mail: " .. (emailErrMsg or "Unbekannt"))
        triggerClientEvent(source, "showMessage", source, "Registration failed (Database Error)!", 255, 0, 0)
        return
    end
    if emailExistsResult and #emailExistsResult > 0 then
        outputServerLog("[REGISTER] ❌ E-Mail '" .. email .. "' existiert bereits in der DB!")
        triggerClientEvent(source, "showMessage", source, "E-Mail already registered!", 255, 0, 0)
        return
    end

    if getAccount(username) then
        outputServerLog("[REGISTER] ❌ Name '" .. username .. "' existiert schon als MTA-Account!")
        triggerClientEvent(source, "showMessage", source, "Username is taken (MTA account)!", 255, 0, 0)
        return
    end

    local passwordHash = hash("sha256", password)
    local insertSuccess, insertErrMsg = exports.datenbank:executeDatabase("INSERT INTO account (username, password, email, register_datum, ip_adresse) VALUES (?,?,?,NOW(),?)", username, passwordHash, email, getPlayerIP(source))

    if insertSuccess then
        local mtaAccount = addAccount(username, password)
        if mtaAccount then
            local idResult, idErrMsg = exports.datenbank:queryDatabase("SELECT id FROM account WHERE username=?", username)
            local newAccountId = nil
            if not idResult then
                 outputServerLog("[REGISTER] ❌ DB-Fehler beim Abrufen der neuen Account ID: " .. (idErrMsg or "Unbekannt"))
                 -- Hier könnte man den DB-Eintrag wieder löschen oder den MTA-Account
            elseif idResult and idResult[1] then
                 newAccountId = idResult[1].id
            end

            if newAccountId then
                 local initQueries = {
                     {query = "INSERT INTO money (account_id, money) VALUES (?, 0)", params = {newAccountId}},
                     {query = "INSERT INTO playtime (account_id, total_minutes, last_session_start, last_session_end) VALUES (?,0,NOW(),NOW())", params = {newAccountId}},
                     {query = "INSERT INTO wanteds (account_id, wanted_level, prisontime) VALUES (?, 0, 0)", params = {newAccountId}}
                 }
                 for _, qData in ipairs(initQueries) do
                     local initSuccess, initErr = exports.datenbank:executeDatabase(qData.query, unpack(qData.params))
                     if not initSuccess then
                         outputServerLog("[REGISTER] ❌ DB-Fehler beim Initialisieren von Daten für AccID " .. newAccountId .. ": " .. (initErr or "Unbekannt") .. " Query: " .. qData.query)
                         -- Kritischer Fehler, eventuell Registrierung rückgängig machen?
                     end
                 end
            else
                 outputServerLog("[REGISTER] ❌ Konnte neue Account ID nicht abrufen für: " .. username .. ". Initialisierungsdaten nicht erstellt.")
                 -- Hier sollte der zuvor erstellte Account-Eintrag ggf. gelöscht werden, um Inkonsistenzen zu vermeiden.
                 -- z.B. exports.datenbank:executeDatabase("DELETE FROM account WHERE username=?", username)
                 -- Und der MTA Account auch: removeAccount(mtaAccount)
                 triggerClientEvent(source, "showMessage", source, "Registration failed (Internal Error)!", 255, 0, 0)
                 return
            end

            outputServerLog("[REGISTER] ✅ Neuer Account in MySQL & MTA erstellt: " .. username)
            triggerClientEvent(source, "showMessage", source, "Registration successful! You can now log in.", 0, 255, 0)
            triggerClientEvent(source, "switchToLogin", source)
        else
            outputServerLog("[REGISTER] ❌ Konnte keinen MTA-Account für '" .. username .. "' erstellen. DB Eintrag wird gelöscht.")
            exports.datenbank:executeDatabase("DELETE FROM account WHERE username=?", username) -- Rollback
            triggerClientEvent(source, "showMessage", source, "Error creating MTA account! Please contact support.", 255, 0, 0)
        end
    else
        outputServerLog("[REGISTER] ❌ Fehler beim Registrieren (INSERT): "..(insertErrMsg or "Unbekannt"))
        triggerClientEvent(source, "showMessage", source, "Registration failed (Database Error)!", 255, 0, 0)
    end
end)

--outputDebugString("[Register] Register-System (Server V1.1 - Robuste DB-Fehlerbehandlung) geladen.")