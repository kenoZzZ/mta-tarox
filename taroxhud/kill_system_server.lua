-- taroxhud/kill_system_server.lua

-- Konfiguration der Ränge und ihrer Reputation (deine bestehende Liste)
local ranks = {
    beginner = { reputation = 0, type = "neutral", name = "Beginner" },
    -- Böse Ränge
    thug_life = { reputation = -10, type = "bad", name = "Thug Life" },
    outlaw = { reputation = -50, type = "bad", name = "Outlaw" },
    bandit = { reputation = -100, type = "bad", name = "Bandit" },
    hitman = { reputation = -300, type = "bad", name = "Hitman" },
    villain = { reputation = -600, type = "bad", name = "Villain" },
    assassin = { reputation = -1000, type = "bad", name = "Assassin" },
    agony = { reputation = -5000, type = "bad", name = "Agony" },
    killer = { reputation = -10000, type = "bad", name = "Killer" },
    warmonger = { reputation = -25000, type = "bad", name = "Warmonger" },
    reckless = { reputation = -50000, type = "bad", name = "Reckless" },
    malevolent = { reputation = -100000, type = "bad", name = "Malevolent" },
    berserk = { reputation = -150000, type = "bad", name = "Berserk" },
    lucifer = { reputation = -200000, type = "bad", name = "Lucifer" },
    destroyer = { reputation = -250000, type = "bad", name = "Destroyer" },
    predator = { reputation = -300000, type = "bad", name = "Predator" },
    beast = { reputation = -350000, type = "bad", name = "Beast" },
    warlord = { reputation = -400000, type = "bad", name = "Warlord" },
    monster = { reputation = -450000, type = "bad", name = "Monster" },
    ragnarok = { reputation = -500000, type = "bad", name = "Ragnarok" },
    undying = { reputation = -550000, type = "bad", name = "Undying" },
    eviscerator = { reputation = -600000, type = "bad", name = "Eviscerator" },
    hunter = { reputation = -700000, type = "bad", name = "Hunter" },
    -- Positive Ränge
    constable = { reputation = 5, type = "good", name = "Constable" },
    deputy = { reputation = 50, type = "good", name = "Deputy" },
    lawmen = { reputation = 100, type = "good", name = "Lawmen" },
    guardian = { reputation = 250, type = "good", name = "Guardian" },
    vigilante = { reputation = 500, type = "good", name = "Vigilante" },
    paragon = { reputation = 1000, type = "good", name = "Paragon" },
    agent = { reputation = 5000, type = "good", name = "Agent" },
    hero = { reputation = 10000, type = "good", name = "Hero" },
    savior = { reputation = 25000, type = "good", name = "Savior" },
    merciful = { reputation = 50000, type = "good", name = "Merciful" },
    angel = { reputation = 75000, type = "good", name = "Angel" },
    king = { reputation = 100000, type = "good", name = "King" },
    champion = { reputation = 200000, type = "good", name = "Champion" },
    genius = { reputation = 300000, type = "good", name = "Genius" },
    devin = { reputation = 400000, type = "good", name = "Devin" },
    sheriff = { reputation = 500000, type = "good", name = "Sheriff" },
    white_knight = { reputation = 750000, type = "good", name = "White Knight" },
    oracle = { reputation = 1000000, type = "good", name = "Oracle" },
    apostle = { reputation = 1250000, type = "good", name = "Apostle" },
    clergyman = { reputation = 1500000, type = "good", name = "Clergyman" },
    cleric = { reputation = 1750000, type = "good", name = "Cleric" },
    zealot = { reputation = 2000000, type = "good", name = "Zealot" }
}

-- Hilfsfunktion, um den Rang basierend auf der Reputation zu ermitteln
function getRankDataFromReputation(reputation)
    local determinedRank = ranks.beginner
    if reputation >= 0 then
        local bestPositiveRank = ranks.beginner
        for _, rankData in pairs(ranks) do
            if rankData.type == "good" and reputation >= rankData.reputation then
                if rankData.reputation >= bestPositiveRank.reputation then
                    bestPositiveRank = rankData
                end
            elseif rankData.type == "neutral" and reputation == 0 then
                 bestPositiveRank = ranks.beginner
            end
        end
        determinedRank = bestPositiveRank
    else
        local bestNegativeRank = ranks.beginner
        local foundNegative = false
        for _, rankData in pairs(ranks) do
            if rankData.type == "bad" and reputation <= rankData.reputation then
                if not foundNegative or rankData.reputation > bestNegativeRank.reputation then
                    bestNegativeRank = rankData
                    foundNegative = true
                end
            end
        end
        if foundNegative then
            determinedRank = bestNegativeRank
        end
    end
    return determinedRank.name, determinedRank.type, determinedRank.reputation
end

-- Funktion zum Abrufen oder Erstellen von Spielerstatistiken
function getOrCreatePlayerKillStats(player)
    outputServerLog("TAROXHUD DEBUG: getOrCreatePlayerKillStats aufgerufen für Spieler: " .. getPlayerName(player)) -- DEBUG
    local accountId = getElementData(player, "account_id")
    outputServerLog("TAROXHUD DEBUG: accountId für " .. getPlayerName(player) .. " in getOrCreatePlayerKillStats: " .. tostring(accountId)) -- DEBUG

    if not accountId then
        outputServerLog("TAROXHUD ERROR: playerAccId (accountId) ist nil für Spieler " .. getPlayerName(player) .. " in getOrCreatePlayerKillStats. Kann keine Stats erstellen/abrufen.") -- DEBUG
        return nil
    end

    local query = "SELECT total_kills, reputation, current_title FROM player_kill_stats WHERE account_id = ?"
    local result, num_affected_rows, err = exports.datenbank:queryDatabase(query, accountId)

    if result and result[1] and result[1].total_kills ~= nil then
        outputServerLog("TAROXHUD DEBUG: Stats für accountId " .. tostring(accountId) .. " gefunden. Kills: " .. tostring(result[1].total_kills)) -- DEBUG
        return {
            account_id = accountId,
            total_kills = tonumber(result[1].total_kills) or 0,
            reputation = tonumber(result[1].reputation) or 0,
            current_title = tostring(result[1].current_title) or "Beginner"
        }
    else
        outputServerLog("TAROXHUD DEBUG: Keine Stats für accountId " .. tostring(accountId) .. " gefunden. Versuche INSERT.") -- DEBUG
        local initialTitle, _, _ = getRankDataFromReputation(0)
        outputServerLog("TAROXHUD DEBUG: Versuche INSERT für accountId " .. tostring(accountId) .. " mit Titel: " .. tostring(initialTitle)) -- DEBUG
        local insertQuery = "INSERT INTO player_kill_stats (account_id, total_kills, reputation, current_title, last_kill_date) VALUES (?, 0, 0, ?, NOW())"
        local success_insert, affected_rows_insert, insert_err = exports.datenbank:executeDatabase(insertQuery, accountId, initialTitle)

        if not success_insert then
            local db_error_msg = "Unbekannter Fehler"
            if type(exports.datenbank.getLastError) == "function" then -- Falls datenbank.lua dbGetError nicht direkt wrappt
                db_error_msg = exports.datenbank:getLastError()
            elseif type(affected_rows_insert) == "string" then -- executeDatabase gibt manchmal Fehlermeldung als zweiten Parameter zurück
                db_error_msg = affected_rows_insert
            end
            outputServerLog("TAROXHUD ERROR: Fehler beim Erstellen eines neuen Eintrags (INSERT) in player_kill_stats für Account ID " .. accountId .. ": " .. tostring(insert_err) .. " | DB Fehler: " .. db_error_msg) -- DEBUG
            return nil
        else
            outputServerLog("TAROXHUD INFO: dbExec INSERT erfolgreich für accountId " .. tostring(accountId) .. ". Affected rows: " .. tostring(affected_rows_insert)) -- DEBUG
            -- KORREKTUR HIER: Gib das neu erstellte Stats-Objekt zurück
            return {
                account_id = accountId,
                total_kills = 0,
                reputation = 0,
                current_title = initialTitle
            }
        end
        -- Der vorherige return-Block hier war überflüssig, da er nach einem erfolgreichen Insert nicht erreicht würde.
    end
end

-- Event Handler für den Tod eines Spielers
function onPlayerWastedHandler(totalammo, killer, killerweapon, bodypart, stealth)
    outputServerLog("TAROXHUD DEBUG: onPlayerWastedHandler ausgelöst. Opfer: " .. getPlayerName(source) .. ", Killer: " .. (killer and getPlayerName(killer) or "N/A")) -- DEBUG

    if not killer or killer == source or getElementType(killer) ~= "player" then
        outputServerLog("TAROXHUD DEBUG: onPlayerWastedHandler - Kein gültiger Killer oder Selbstmord.") -- DEBUG
        return
    end

    if not getElementData(killer, "loggedin") or not getElementData(source, "loggedin") then
        outputServerLog("TAROXHUD DEBUG: onPlayerWastedHandler - Killer (" .. getPlayerName(killer) .. ", loggedin: " .. tostring(getElementData(killer, "loggedin")) .. ") oder Opfer (" .. getPlayerName(source) .. ", loggedin: " .. tostring(getElementData(source, "loggedin")) .. ") nicht eingeloggt.") -- DEBUG
        return
    end

    local killerPlayer = killer
    local victimPlayer = source

    outputServerLog("TAROXHUD DEBUG: onPlayerWastedHandler - Rufe getOrCreatePlayerKillStats für Killer: " .. getPlayerName(killerPlayer)) -- DEBUG
    local killerStats = getOrCreatePlayerKillStats(killerPlayer)
    outputServerLog("TAROXHUD DEBUG: onPlayerWastedHandler - Rufe getOrCreatePlayerKillStats für Opfer: " .. getPlayerName(victimPlayer)) -- DEBUG
    local victimStats = getOrCreatePlayerKillStats(victimPlayer)

    if not killerStats then
        outputServerLog("TAROXHUD ERROR: onPlayerWastedHandler - killerStats konnten nicht geladen/erstellt werden für Killer: " .. getPlayerName(killerPlayer)) -- DEBUG
        return
    end
    if not victimStats then
        outputServerLog("TAROXHUD ERROR: onPlayerWastedHandler - victimStats konnten nicht geladen/erstellt werden für Opfer: " .. getPlayerName(victimPlayer)) -- DEBUG
        return
    end
    outputServerLog("TAROXHUD DEBUG: onPlayerWastedHandler - Stats für Killer (AccID: "..tostring(killerStats.account_id)..") und Opfer (AccID: "..tostring(victimStats.account_id)..") geladen/erstellt.") -- DEBUG


    local _, killerRankType, killerRepValue = getRankDataFromReputation(killerStats.reputation)
    local _, victimRankType, victimRepValue = getRankDataFromReputation(victimStats.reputation)

    local reputationChange = 0

    if victimRankType == "bad" then
        reputationChange = reputationChange + 2
    elseif victimRankType == "good" then
        reputationChange = reputationChange - 2
    elseif victimRankType == "neutral" then
        reputationChange = reputationChange - 1
    end

    if killerStats.reputation > 0 then
        if victimRankType == "good" then
            reputationChange = -5
        end
    end

    if killerStats.reputation < -50 then
        if reputationChange > 0 then
            reputationChange = -1
        elseif reputationChange == 0 then
             reputationChange = -1
        end
    end

    if killerStats.reputation > 100 then
        if reputationChange < 0 then
            reputationChange = 1
        elseif reputationChange == 0 then
             reputationChange = 1
        end
    end

    killerStats.total_kills = (killerStats.total_kills or 0) + 1
    killerStats.reputation = (killerStats.reputation or 0) + reputationChange

    local newTitle, _, _ = getRankDataFromReputation(killerStats.reputation)
    killerStats.current_title = newTitle

    outputServerLog("TAROXHUD DEBUG: Versuche UPDATE für killerAccID " .. tostring(killerStats.account_id) .. " mit Kills: " .. killerStats.total_kills .. ", Rep: " .. killerStats.reputation .. ", Titel: " .. killerStats.current_title) -- DEBUG
    local updateQuery = [[
        UPDATE player_kill_stats
        SET total_kills = ?, reputation = ?, current_title = ?, last_kill_date = NOW()
        WHERE account_id = ?
    ]]
    local success_update, affected_rows_update, update_err = exports.datenbank:executeDatabase(updateQuery, killerStats.total_kills, killerStats.reputation, killerStats.current_title, killerStats.account_id)

    if success_update then
        outputServerLog("TAROXHUD INFO: dbExec UPDATE erfolgreich für killerAccID " .. tostring(killerStats.account_id) .. ". Affected rows: " .. tostring(affected_rows_update)) -- DEBUG
        setElementData(killerPlayer, "playerTitle", newTitle, true)
        outputChatBox("Du hast " .. getPlayerName(victimPlayer) .. " getötet!", killerPlayer, 0, 200, 0)
        local repChangeText = reputationChange > 0 and "+" .. reputationChange or tostring(reputationChange)
        outputChatBox("Reputation: " .. repChangeText .. ". Gesamt: " .. killerStats.reputation .. ". Dein neuer Titel: " .. newTitle, killerPlayer, 150, 150, 255)
    else
        local db_error_msg_update = "Unbekannter Fehler"
        if type(exports.datenbank.getLastError) == "function" then
             db_error_msg_update = exports.datenbank:getLastError()
        elseif type(affected_rows_update) == "string" then
             db_error_msg_update = affected_rows_update
        end
        outputServerLog("TAROXHUD ERROR: Fehler beim Aktualisieren (UPDATE) der Kill-Statistiken für Account ID: " .. killerStats.account_id .. ": " .. tostring(update_err) .. " | DB Fehler: " .. db_error_msg_update) -- DEBUG
    end
end
addEventHandler("onPlayerWasted", root, onPlayerWastedHandler)

function setInitialPlayerTitleOnLoginOrSpawn(playerSource)
    local player = playerSource or source
    outputServerLog("TAROXHUD DEBUG: setInitialPlayerTitleOnLoginOrSpawn aufgerufen für " .. getPlayerName(player) .. ". Loggedin-Status: " .. tostring(getElementData(player, "loggedin"))) -- DEBUG
    if getElementData(player, "loggedin") == true then
        outputServerLog("TAROXHUD DEBUG: Spieler " .. getPlayerName(player) .. " ist eingeloggt. Rufe getOrCreatePlayerKillStats.") -- DEBUG
        local playerStats = getOrCreatePlayerKillStats(player)
        local titleToSet = "Beginner"
        if playerStats and playerStats.current_title then
            titleToSet = playerStats.current_title
            outputServerLog("TAROXHUD DEBUG: Titel für " .. getPlayerName(player) .. " aus playerStats geladen: " .. titleToSet) -- DEBUG
        else
            local defaultTitle, _, _ = getRankDataFromReputation(0)
            titleToSet = defaultTitle
            outputServerLog("TAROXHUD DEBUG: playerStats nicht gefunden oder Titel leer für " .. getPlayerName(player) .. ". Fallback auf Default-Titel: " .. titleToSet) -- DEBUG
        end
        setElementData(player, "playerTitle", titleToSet, true)
    else
        outputServerLog("TAROXHUD DEBUG: Spieler " .. getPlayerName(player) .. " ist NICHT eingeloggt. Titel wird nicht gesetzt.") -- DEBUG
    end
end
addEventHandler("onPlayerLogin", root, function() setInitialPlayerTitleOnLoginOrSpawn(source) end)
addEventHandler("onPlayerSpawn", root, function() setInitialPlayerTitleOnLoginOrSpawn(source) end)

outputServerLog("[TAROXHUD] Kill-Reputations-System (V2.1 - Fix für INSERT Return) wurde geladen.")