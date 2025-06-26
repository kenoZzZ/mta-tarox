-- tarox/user/server/money_server.lua
-- VERSION ANGEPASST FÜR BANK-SYSTEM

function loadPlayerMoney(player)
    if not isElement(player) then
        outputDebugString("[MONEY SYSTEM] ❌ loadPlayerMoney: Ungültiger Spieler!")
        return false
    end

    local accountID = getElementData(player, "account_id")
    if not accountID then
        outputDebugString("[MONEY SYSTEM] ❌ loadPlayerMoney: Keine account_id für " .. getPlayerName(player))
        return false
    end

    -- Lade Bargeld und Bankguthaben
    local moneyResult, errMsg = exports.datenbank:queryDatabase("SELECT money, bank_money FROM money WHERE account_id=?", accountID) -- MODIFIZIERT

    if not moneyResult then
        outputDebugString("[MONEY SYSTEM] ❌ FEHLER beim Laden des Geldes: DB-Fehler für Account-ID " .. accountID .. ": " .. (errMsg or "Unbekannt"), 2)
        setPlayerMoney(player, 0) -- Fallback Bargeld
        setElementData(player, "bank_money", 0) -- Fallback Bankguthaben
        return false
    end

    if moneyResult and moneyResult[1] then
        local cash = tonumber(moneyResult[1].money) or 0
        local bank = tonumber(moneyResult[1].bank_money) or 0 -- NEU
        setPlayerMoney(player, cash)
        setElementData(player, "bank_money", bank) -- NEU
        setElementData(player, "lastSavedMoney", cash) -- Nur Bargeld für onPlayerMoneyChange
        setElementData(player, "lastSavedBankMoney", bank) -- Für separates Speichern
    else
        outputDebugString("[MONEY SYSTEM] ⚠ Kein Geld-Eintrag in DB für ID "..accountID.." -> Erstelle neuen Eintrag mit 500 Startgeld (Cash), 0 (Bank).")
        -- Erstelle Eintrag mit Standard-Bargeld und 0 Bankguthaben
        local success_insert, insertErrMsg = exports.datenbank:executeDatabase("INSERT INTO money (account_id, money, bank_money) VALUES (?, 500, 0)", accountID) -- MODIFIZIERT
        if success_insert then
            setPlayerMoney(player, 500)
            setElementData(player, "bank_money", 0) -- NEU
            setElementData(player, "lastSavedMoney", 500)
            setElementData(player, "lastSavedBankMoney", 0)
        else
            setPlayerMoney(player, 0)
            setElementData(player, "bank_money", 0) -- NEU
            outputDebugString("[MONEY SYSTEM] ❌ Fehler beim Erstellen des Geld-Eintrags für ID "..accountID..": " .. (insertErrMsg or "Unbekannt"), 2)
            return false
        end
    end
    return true
end
_G.loadPlayerMoney = loadPlayerMoney -- Sicherstellen, dass es global ist, falls login_server es so aufruft

addEventHandler("onPlayerLoginSuccess", root, function()
    local player = source -- Client ist source bei onPlayerLoginSuccess
    setTimer(function(p)
        if isElement(p) then
            local success = loadPlayerMoney(p) -- Ruft die angepasste Funktion auf
            if not success then
                outputChatBox("Ein Fehler ist beim Laden deiner Finanzdaten aufgetreten.", p, 255, 0, 0)
            end
        end
    end, 250, 1, player)
end)

function savePlayerMoney(player) -- Diese Funktion speichert jetzt Bargeld UND Bankguthaben
    if not isElement(player) then
        outputDebugString("[MONEY SYSTEM] savePlayerMoney: Spieler-Element ungültig.")
        return false
    end

    local accountID = getElementData(player, "account_id")
    if not accountID then
        outputDebugString("[MONEY SYSTEM] ❌ Kein account_id beim Speichern für "..getPlayerName(player).."!")
        return false
    end

    local cash = getPlayerMoney(player)
    local bankMoney = getElementData(player, "bank_money") or 0 -- Bankguthaben holen

    if type(cash) ~= "number" or type(bankMoney) ~= "number" then
        outputDebugString("[MONEY SYSTEM] ❌ Ungültiger Geldwert (Cash oder Bank) für Account-ID "..accountID)
        return false
    end

    local lastSavedCash = getElementData(player, "lastSavedMoney")
    local lastSavedBank = getElementData(player, "lastSavedBankMoney")

    -- Nur speichern, wenn sich etwas geändert hat
    if lastSavedCash and lastSavedCash == cash and lastSavedBank and lastSavedBank == bankMoney then
        return true
    end

    local success, updateErrMsg = exports.datenbank:executeDatabase("UPDATE money SET money=?, bank_money=? WHERE account_id=?", cash, bankMoney, accountID) -- MODIFIZIERT

    if success then
        setElementData(player, "lastSavedMoney", cash)
        setElementData(player, "lastSavedBankMoney", bankMoney)
        return true
    else
        outputDebugString("[MONEY SYSTEM] ❌ Fehler beim Speichern des Geldes in der DB für Account-ID "..accountID..". Fehler: " .. (updateErrMsg or "Unbekannt"))
        return false
    end
end
_G.savePlayerMoney = savePlayerMoney -- Sicherstellen, dass es global ist

-- onPlayerMoneyChange wird ausgelöst, wenn setPlayerMoney (Bargeld) geändert wird.
-- Wir speichern dann Bargeld und Bankguthaben zusammen.
addEventHandler("onPlayerMoneyChange", root, function(oldValue, newValue)
    -- Das Speichern von Bargeld UND Bankguthaben passiert nun hier,
    -- da savePlayerMoney beides handhabt.
    savePlayerMoney(source)
end)

-- Beim Verlassen des Servers wird savePlayerMoney aufgerufen, was Bargeld und Bank speichert.
addEventHandler("onPlayerQuit", root, function()
    outputDebugString("[Money] Spieler "..getPlayerName(source).." verlässt den Server. Speichere Geld (money_server.lua onPlayerQuit).")
    savePlayerMoney(source)
end)

-- Beim Stoppen der Ressource wird für alle eingeloggten Spieler gespeichert.
addEventHandler("onResourceStop", resourceRoot, function(stoppedResource)
    if stoppedResource == getThisResource() then
        outputDebugString("[Money] Ressource wird gestoppt. Speichere Geld aller eingeloggten Spieler (money_server.lua onResourceStop)...")
        for _, player in ipairs(getElementsByType("player")) do
             if getElementData(player, "account_id") then
                savePlayerMoney(player)
            end
        end
        --outputDebugString("[Money] Geld gespeichert (money_server.lua onResourceStop).")
    end
end)

--outputDebugString("[Money] Geld-System (Server V2.2 - Bank-Integration) geladen.")--