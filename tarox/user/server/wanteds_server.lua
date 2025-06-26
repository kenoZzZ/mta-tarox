-- tarox/user/server/wanteds_server.lua
-- Mit Kill-Wanteds & Jail-Check
-- ANGEPASST V1.1: Verbesserte Fehlerbehandlung für Datenbankaufrufe
-- ANGEPASST V1.2: Wanted-Abbau alle 30 Sekunden
-- NEU V1.3: /resetwanted Befehl hinzugefügt

local playersWithWanteds = {}
local wantedReductionTimer = nil

if not exports.datenbank or not exports.datenbank:getConnection() then
    outputDebugString("[Wanteds] FATALER FEHLER: Datenbank-Ressource nicht verfügbar oder Verbindung fehlgeschlagen!", 2)
    -- Hier könnte man das Laden der Ressource stoppen, wenn die DB essentiell ist.
    -- return
end

-- Globale Funktion zum Setzen des Wanted Levels
function setPlayerWantedLevel(player, newLevel)
    if not isElement(player) then return end
    local accID = getElementData(player, "account_id")
    if not accID then return end

    newLevel = tonumber(newLevel) or 0
    if newLevel < 0 then newLevel = 0 end
    if newLevel > 100 then newLevel = 100 end

    local currentWanted = getElementData(player, "wanted") or 0
    if currentWanted == newLevel then return end

    local playerName = getPlayerName(player)
    outputDebugString(string.format("[Wanteds] setPlayerWantedLevel für %s: %d -> %d", playerName, currentWanted, newLevel))

    setElementData(player, "wanted", newLevel)

    local sql = [[
        INSERT INTO wanteds (account_id, wanted_level) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE wanted_level = VALUES(wanted_level)
    ]]
    local dbSuccess, dbErrMsg = exports.datenbank:executeDatabase(sql, accID, newLevel)
    if not dbSuccess then
        outputDebugString("[Wanteds] FEHLER beim Speichern des Wanted-Levels (DB Error: " .. (dbErrMsg or "Unbekannt") ..") für ID " .. accID, 2)
    end

    local prisonTime = getElementData(player, "prisontime") or 0
    if newLevel > 0 and prisonTime <= 0 then
        if not playersWithWanteds[player] then
            playersWithWanteds[player] = true
            -- Setze den nächsten Reduktionstick basierend auf dem globalen Intervall
            setElementData(player, "nextWantedReductionTick", getTickCount() + calculateWantedReductionDelay(newLevel) * 1000)
            outputDebugString(string.format("[Wanted Management] %s zur Wanted-Reduktionsliste hinzugefügt (Level: %d, Nicht im Gefängnis)", playerName, newLevel))
            ensureWantedTimerIsRunning()
        else
            -- Spieler ist bereits in der Liste, aktualisiere ggf. den nächsten Tick, falls das neue Level ein anderes Delay erfordert
            -- (In diesem Fall bleibt das Delay aber gleich bei 30s, also ist die Zeile unten optional, schadet aber nicht)
             setElementData(player, "nextWantedReductionTick", getTickCount() + calculateWantedReductionDelay(newLevel) * 1000)
        end
    else
        if playersWithWanteds[player] then
            playersWithWanteds[player] = nil
            setElementData(player, "nextWantedReductionTick", 0)
            outputDebugString(string.format("[Wanted Management] %s von Wanted-Reduktionsliste entfernt (Level: %d, In Haft: %s)", playerName, newLevel, tostring(prisonTime > 0)))
        end
    end

    triggerEvent("onWantedChange", player, newLevel, currentWanted)
    triggerClientEvent(player, "updateWantedLevelDisplay", player, newLevel)
end

local WANTED_REDUCTION_INTERVAL_SECONDS = 30 -- Der Timer läuft alle 30 Sekunden.

function calculateWantedReductionDelay(wantedLevel)
    -- Gibt das Intervall des Haupt-Timers zurück, damit bei jedem Durchlauf reduziert wird.
    return WANTED_REDUCTION_INTERVAL_SECONDS
end


function checkWantedReduction()
    local now = getTickCount()
    local playersToRemove = {}
    if table.isEmpty(playersWithWanteds) then
        if isTimer(wantedReductionTimer) then killTimer(wantedReductionTimer); wantedReductionTimer = nil; outputDebugString("[Wanted Timer] Timer gestoppt, da keine Spieler (außerhalb Haft) Wanteds haben.") end
        return
    end
    for player, _ in pairs(playersWithWanteds) do
        if not isElement(player) then table.insert(playersToRemove, player)
        else
            local w = getElementData(player, "wanted") or 0
            local prisonTime = getElementData(player, "prisontime") or 0
            local nextTick = getElementData(player, "nextWantedReductionTick") or 0
            if w <= 0 then table.insert(playersToRemove, player); setElementData(player, "nextWantedReductionTick", 0)
            elseif prisonTime > 0 then table.insert(playersToRemove, player); setElementData(player, "nextWantedReductionTick", 0); outputDebugString(string.format("[Wanted Timer] %s aus Reduktionsliste entfernt (ist im Gefängnis).", getPlayerName(player)))
            elseif now >= nextTick then
                local reduceAmount = 1; local newW = math.max(0, w - reduceAmount)
                setPlayerWantedLevel(player, newW) -- Ruft die Funktion auf, die nextWantedReductionTick neu setzt (auf now + 30s)
                if newW == 0 then outputDebugString(string.format("[Wanted Timer Debug] %s: Auf 0 reduziert (normal).", getPlayerName(player))) end
            end
        end
    end
    for _, playerToRemove in ipairs(playersToRemove) do if playersWithWanteds[playerToRemove] then playersWithWanteds[playerToRemove] = nil end end
end

function ensureWantedTimerIsRunning()
    if not isTimer(wantedReductionTimer) and not table.isEmpty(playersWithWanteds) then
        outputDebugString("[Wanted Timer] Starte Wanted-Reduktions-Timer (Intervall: " .. WANTED_REDUCTION_INTERVAL_SECONDS .. "s)")
        wantedReductionTimer = setTimer(checkWantedReduction, WANTED_REDUCTION_INTERVAL_SECONDS * 1000, 0)
    end
end

function loadWantedAndPrisonTimeForPlayer(player)
    if not isElement(player) then return 0,0, "Invalid player element" end
    local accountID = getElementData(player, "account_id")
    if not accountID then outputDebugString("[Wanteds] loadWanted: Keine account_id für "..getPlayerName(player)); return 0,0, "No account_id" end

    local wanted, ptime = 0, 0
    local queryResult, errMsg = exports.datenbank:queryDatabase("SELECT wanted_level, prisontime FROM wanteds WHERE account_id=? LIMIT 1", accountID)

    if not queryResult then
        outputDebugString("[Wanteds] DB-Fehler beim Laden von Wanteds/PrisonTime für AccID " .. accountID .. ": " .. (errMsg or "Unbekannt"))
        setElementData(player, "wanted", 0); setElementData(player, "prisontime", 0)
        triggerEvent("onWantedChange", player, 0, 0); triggerClientEvent(player, "updateWantedLevelDisplay", player, 0)
        return 0,0, "Database query error"
    end

    if queryResult and type(queryResult) == "table" and queryResult[1] then
        wanted = tonumber(queryResult[1].wanted_level) or 0
        ptime = tonumber(queryResult[1].prisontime) or 0
    else
        outputDebugString("[Wanteds] Kein DB Eintrag für ID "..accountID..", versuche neuen Eintrag (0/0) zu erstellen.")
        local insertSuccess, insertErrMsg = exports.datenbank:executeDatabase("INSERT IGNORE INTO wanteds (account_id, wanted_level, prisontime) VALUES (?, 0, 0)", accountID)
        if not insertSuccess then
            outputDebugString("[Wanteds] DB-Fehler beim Erstellen eines neuen Eintrags für AccID " .. accountID .. ": " .. (insertErrMsg or "Unbekannt"))
        end
    end

    setElementData(player, "wanted", wanted); setElementData(player, "prisontime", ptime)
    if wanted > 0 and ptime <= 0 then
        if not playersWithWanteds[player] then
            playersWithWanteds[player] = true;
            setElementData(player, "nextWantedReductionTick", getTickCount() + calculateWantedReductionDelay(wanted) * 1000);
            ensureWantedTimerIsRunning();
            outputDebugString(string.format("[Wanted Management] %s beim Laden zur Wanted-Reduktionsliste hinzugefügt (Level: %d)", getPlayerName(player), wanted))
        end
    else
        if playersWithWanteds[player] then playersWithWanteds[player] = nil end;
        setElementData(player, "nextWantedReductionTick", 0)
    end
    triggerEvent("onWantedChange", player, wanted, wanted); triggerClientEvent(player, "updateWantedLevelDisplay", player, wanted)
    outputDebugString(string.format("[Wanteds] Geladen für %s (ID %d): Wanteds=%d, PrisonTime=%d", getPlayerName(player), accountID, wanted, ptime))
    return wanted, ptime, "Success"
end

function giveWantedsOnDamage(attacker, weapon, bodypart, loss)
    if not attacker or getElementType(attacker) ~= "player" then return end
    if not source or getElementType(source) ~= "player" then return end
    if attacker == source then return end
    if loss <= 0 then return end

    local attackerFid, victimFid = 0, 0
    if type(getPlayerFractionAndRank) == "function" then
        attackerFid, _ = getPlayerFractionAndRank(attacker)
        victimFid, _ = getPlayerFractionAndRank(source)
    else
        outputDebugString("[Wanteds|Damage] FEHLER: getPlayerFractionAndRank Funktion nicht gefunden!")
        return
    end

    if attackerFid == 1 or attackerFid == 2 then -- Police or Swat
        return
    end

    local currentWanteds = getElementData(attacker, "wanted") or 0
    local wantedsToAdd = 1 -- Für normalen Schaden
    local newWanteds = math.min(100, currentWanteds + wantedsToAdd)

    if newWanteds > currentWanteds then
        if type(setPlayerWantedLevel) == "function" then
            setPlayerWantedLevel(attacker, newWanteds)
        else
            outputDebugString("[Wanteds|Damage] FEHLER: setPlayerWantedLevel Funktion nicht gefunden!")
        end
    end
end
addEventHandler("onPlayerDamage", root, giveWantedsOnDamage)

function giveWantedsOnKill(totalAmmo, killer, killerWeapon, bodypart)
    if not killer or getElementType(killer) ~= "player" then return end
    if killer == source then return end -- Kein Selbstmord

    local killerFid = 0
    if type(getPlayerFractionAndRank) == "function" then
        killerFid, _ = getPlayerFractionAndRank(killer)
    else
        outputDebugString("[Wanteds|Kill] FEHLER: getPlayerFractionAndRank Funktion nicht gefunden!")
    end

    if killerFid == 1 or killerFid == 2 then -- Police or Swat machen keinen Wanted-Self-Increase durch Kill
        return
    end

    local currentWanteds = getElementData(killer, "wanted") or 0
    local wantedsToAdd = 15 -- Standard für einen Kill
    local newWanteds = math.min(100, currentWanteds + wantedsToAdd)

    if type(setPlayerWantedLevel) == "function" then
        setPlayerWantedLevel(killer, newWanteds)
        outputDebugString(string.format("[Wanteds|Kill] %s (%s) killed %s. Wanteds: %d -> %d", getPlayerName(killer), killerFid, getPlayerName(source), currentWanteds, newWanteds))
        outputChatBox("Du hast jemanden getötet und +" .. wantedsToAdd .. " Wanteds erhalten!", killer, 255, 100, 0)
    else
        outputDebugString("[Wanteds|Kill] FEHLER: setPlayerWantedLevel Funktion nicht gefunden!")
    end
end
addEventHandler("onPlayerWasted", root, giveWantedsOnKill)

-- Hilfsfunktion zur Überprüfung des Admin-Levels
local function isAdminForWantedReset(player)
    local adminLevel = getElementData(player, "adminLevel") or 0
    return adminLevel >= 1 -- Ändere '1' auf das gewünschte Admin-Level
end

-- Neuer Befehl /resetwanted
addCommandHandler("resetwanted", function(adminPlayer, commandName, targetPlayerNameOrID)
    if not isAdminForWantedReset(adminPlayer) then
        outputChatBox("❌ Du hast keine Berechtigung für diesen Befehl.", adminPlayer, 255, 0, 0)
        return
    end

    if not targetPlayerNameOrID then
        outputChatBox("SYNTAX: /" .. commandName .. " [Spieler Name/ID]", adminPlayer, 200, 200, 0)
        return
    end

    local targetPlayer = nil
    local potentialTargets = {}
    local searchStringLower = string.lower(tostring(targetPlayerNameOrID))

    for _, p in ipairs(getElementsByType("player")) do
        if getElementData(p, "account_id") then
            if string.find(string.lower(getPlayerName(p)), searchStringLower, 1, true) or
               tostring(getElementData(p, "account_id")) == searchStringLower then
                table.insert(potentialTargets, p)
            end
        end
    end

    if #potentialTargets == 0 then
        outputChatBox("Spieler '" .. targetPlayerNameOrID .. "' nicht gefunden.", adminPlayer, 255, 100, 0)
        return
    elseif #potentialTargets > 1 then
        outputChatBox("Mehrere Spieler gefunden, bitte sei genauer:", adminPlayer, 255, 165, 0)
        for i=1, math.min(5, #potentialTargets) do local tP=potentialTargets[i]; outputChatBox("  - "..getPlayerName(tP).." (ID: "..(getElementData(tP,"account_id")or"N/A")..")", adminPlayer,200,200,200) end
        if #potentialTargets > 5 then outputChatBox("  ... und weitere.", adminPlayer, 200,200,200) end
        return
    else
        targetPlayer = potentialTargets[1]
    end

    if not isElement(targetPlayer) then
        outputChatBox("Spieler '" .. targetPlayerNameOrID .. "' nicht gefunden (nach Auswahl).", adminPlayer, 255, 100, 0)
        return
    end

    local targetAccID = getElementData(targetPlayer, "account_id")
    if not targetAccID then
        outputChatBox("Fehler: Zielspieler hat keine Account-ID.", adminPlayer, 255, 0, 0)
        return
    end

    setPlayerWantedLevel(targetPlayer, 0)
    -- Gefängniszeit auch zurücksetzen, falls der Spieler im Gefängnis war
    if getElementData(targetPlayer, "prisontime") > 0 then
        if type(_G.freePlayerFromJail) == "function" then
            _G.freePlayerFromJail(targetPlayer) -- Nutzt die globale Funktion aus jail_server
             outputChatBox("Gefängniszeit für " .. getPlayerName(targetPlayer) .. " ebenfalls zurückgesetzt.", adminPlayer, 0, 200, 50)
        else
            setElementData(targetPlayer, "prisontime", 0)
            local dbSuccessTime, errMsgTime = exports.datenbank:executeDatabase("UPDATE wanteds SET prisontime=0 WHERE account_id=?", targetAccID)
            if not dbSuccessTime then
                outputDebugString("[Wanteds|Reset] DB FEHLER beim Zurücksetzen der PrisonTime für AccID "..targetAccID..": "..(errMsgTime or "Unbekannt"), 2)
            end
            outputChatBox("Gefängniszeit für " .. getPlayerName(targetPlayer) .. " auf 0 gesetzt (Fallback).", adminPlayer, 0, 200, 50)
        end
    end

    outputChatBox("Wanteds für Spieler " .. getPlayerName(targetPlayer) .. " wurden zurückgesetzt.", adminPlayer, 0, 255, 0)
    outputChatBox("Deine Wanteds wurden von einem Admin zurückgesetzt.", targetPlayer, 0, 200, 220)
end)


addEventHandler("onPlayerQuit", root, function()
     local accID = getElementData(source, "account_id"); local playerName = getPlayerName(source)
     if playersWithWanteds[source] then playersWithWanteds[source] = nil; outputDebugString(string.format("[Wanted Management] %s beim Verlassen aus Wanted-Reduktionsliste entfernt.", playerName)) end
     if accID then
         local wanted = getElementData(source, "wanted") or 0
         local dbSuccess, dbErrMsg = exports.datenbank:executeDatabase("UPDATE wanteds SET wanted_level=? WHERE account_id=?", wanted, accID)
         if dbSuccess then
             --outputDebugString("[Wanteds] Wanteds für ID "..accID.." beim Verlassen gespeichert.")
         else
             outputDebugString("[Wanteds] FEHLER beim Speichern der Wanteds für ID "..accID.." (Quit): " .. (dbErrMsg or "Unbekannt"))
         end
     end
end)

addEventHandler("onResourceStop", resourceRoot, function(stoppedResource)
    if stoppedResource == getThisResource() then
        --outputDebugString("[Wanteds] Speichere Wanteds beim Stoppen der Ressource...")
        if isTimer(wantedReductionTimer) then killTimer(wantedReductionTimer); wantedReductionTimer = nil; outputDebugString("[Wanted Timer] Timer beim Ressourcen-Stopp gestoppt.") end
        for _, player in ipairs(getElementsByType("player")) do
            if isElement(player) then
                local accID = getElementData(player, "account_id")
                if accID then
                    local wanted = getElementData(player, "wanted") or 0
                    exports.datenbank:executeDatabase("UPDATE wanteds SET wanted_level=? WHERE account_id=?", wanted, accID)
                end
            end
        end
        --outputDebugString("[Wanteds] Wanteds gespeichert.")
    end
end)

addEventHandler("onResourceStart", resourceRoot, function()
    setTimer(function()
        for _, player in ipairs(getElementsByType("player")) do
            if isElement(player) then
                local accID = getElementData(player, "account_id")
                if accID then
                    local wanted, ptime, errMsg = loadWantedAndPrisonTimeForPlayer(player)
                    if errMsg ~= "Success" then
                        outputDebugString("[Wanteds] onResourceStart: Fehler beim Laden von Wanteds/PrisonTime für " .. getPlayerName(player) .. ": " .. errMsg)
                    end
                end
            end
        end
        ensureWantedTimerIsRunning()
    end, 5000, 1)
end)

if not table.isEmpty then function table.isEmpty(t) if not t then return true end return next(t) == nil end end
if not table.count then function table.count(t) local count = 0 for _ in pairs(t) do count = count + 1 end return count end end

--outputDebugString("[Wanteds] Wanted-System (Server V1.3 - /resetwanted Command) geladen.")