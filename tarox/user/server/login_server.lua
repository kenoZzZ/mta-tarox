-- tarox/user/server/login_server.lua
-- << GEÄNDERT V8 >> Nametag-Farben werden nun über refreshPlayerFractionData gesetzt.
-- << Gemini Patch V11 >> Deine V8-Struktur beibehalten, Login-Hash-Funktion korrigiert.

local db 

addEvent("onPlayerLoginSuccess", true) --
addEvent("onPlayerLoginComplete", true) --
addEvent("forceShowLogin", true) --
addEvent("loginPlayer", true) --

local POLICE_FRACTION_ID_LOGIN = 1 --
local MEDIC_FRACTION_ID_LOGIN = 3 --
local COSA_NOSTRA_FRACTION_ID_LOGIN = 4 --
local MOCRO_MAFIA_FRACTION_ID_LOGIN = 5 --
local YAKUZA_FRACTION_ID_LOGIN = 6 --
local MECHANIC_FRACTION_ID_LOGIN = 7 --

function loadPlayerWeaponsFromSQL(player)
    if not isElement(player) then return {} end
    local accountID = getElementData(player, "account_id")
    if not accountID then return {} end

    local weaponsResult, errMsg = exports.datenbank:queryDatabase("SELECT * FROM weapons WHERE account_id=? LIMIT 1", accountID) --
    if not weaponsResult then
        outputDebugString("[Login] loadPlayerWeaponsFromSQL: DB-Fehler beim Laden der Waffen für AccID " .. accountID .. ": " .. (errMsg or "Unbekannt"))
        return {}
    end

    local restoredWeaponsArray = {}
    if weaponsResult and weaponsResult[1] then
        local row = weaponsResult[1]
        for i = 1, 9 do
            local weaponID = tonumber(row["weapon_slot"..i])
            local ammo = tonumber(row["ammo_slot"..i])
            if weaponID and weaponID > 0 and ammo ~= nil then
                table.insert(restoredWeaponsArray, {weaponID = weaponID, ammo = ammo})
            end
        end
    end
    return restoredWeaponsArray
end
_G.loadPlayerWeaponsFromSQL = loadPlayerWeaponsFromSQL --


addEventHandler("loginPlayer", root, function(username, password) --
    local player = source
    if not isGuestAccount(getPlayerAccount(player)) then
        triggerClientEvent(player, "showMessage", player, "Du bist bereits eingeloggt! Benutze /logout.", 255, 165, 0)
        return
    end
    if not username or not password or username == "" or password == "" then
        triggerClientEvent(player, "showMessage", player, "Fehlende Login-Daten!", 255, 0, 0)
        return
    end

    local accountDataResult, errMsg = exports.datenbank:queryDatabase("SELECT * FROM account WHERE username=?", username) --
    if not accountDataResult then
        triggerClientEvent(player, "showMessage", player, "Login Fehler: Datenbankproblem.", 255, 0, 0)
        outputDebugString("[Login] DB-Fehler bei Account-Abfrage: " .. (errMsg or "Unbekannt"))
        return
    end

    if accountDataResult and #accountDataResult > 0 then
        local row = accountDataResult[1]
        local dbPasswordHash = row["password"]
        -- KORREKTUR ZUM ORIGINAL: Diese Zeile wurde zurückgeändert, um den Fehler zu beheben.
        local inputHash = hash("sha256", password)

        if dbPasswordHash == inputHash then
            local account = getAccount(username)
            if not account then
                 account = addAccount(username, password)
                 if not account then
                      triggerClientEvent(player, "showMessage", player, "Login Fehler: MTA Account Problem!", 255, 0, 0)
                      return
                 end
            end

            setElementFrozen(player, true)
            toggleAllControls(player, false)
            fadeCamera(player, false, 0)

            if logIn(player, account, password) then
                local accountID = tonumber(row["id"])
                setElementData(player, "account_id", accountID, true) --
                local adminLevel = tonumber(row["admin_level"]) or 0
                setElementData(player, "adminLevel", adminLevel, true) --
                setElementData(player, "loggedin", true, true) --

                local updateSuccess, updateErrMsg = exports.datenbank:executeDatabase("UPDATE account SET last_login=NOW(), ip_adresse=? WHERE id=?", getPlayerIP(player), accountID) --
                if not updateSuccess then
                    outputDebugString("[Login] DB-Fehler beim Aktualisieren von last_login: " .. (updateErrMsg or "Unbekannt"))
                end

                local dataLoadSuccess = true
                local pcallStatus, pcallErrorMsg

                if type(_G.refreshPlayerFractionData) == "function" then --
                    pcallStatus, pcallErrorMsg = pcall(_G.refreshPlayerFractionData, player) --
                    if not pcallStatus then
                        dataLoadSuccess = false
                        outputDebugString("[Login] Fehler beim Ausführen von refreshPlayerFractionData: " .. tostring(pcallErrorMsg))
                    end
                else
                    dataLoadSuccess = false
                    outputDebugString("[Login] Ladefunktion refreshPlayerFractionData nicht gefunden.")
                end

                local loadFunctions = {
                    {name = "loadPlayerMoney", func = _G.loadPlayerMoney}, --
                    {name = "loadPlayerPlaytime", func = _G.loadPlayerPlaytime}, --
                    {name = "loadWantedAndPrisonTimeForPlayer", func = _G.loadWantedAndPrisonTimeForPlayer}, --
                    {name = "loadPlayerInventory", func = _G.loadPlayerInventory} --
                }

                for _, loader in ipairs(loadFunctions) do
                    if type(loader.func) == "function" then
                        pcallStatus, pcallErrorMsg = pcall(loader.func, player)
                        if not pcallStatus then
                            dataLoadSuccess = false
                            outputDebugString("[Login] Fehler beim Ausführen von " .. loader.name .. ": " .. tostring(pcallErrorMsg))
                        end
                    else
                        dataLoadSuccess = false
                        outputDebugString("[Login] Ladefunktion " .. loader.name .. " nicht gefunden.")
                    end
                end

                if not dataLoadSuccess then
                    outputChatBox("Ein Fehler ist beim Laden deiner Accountdaten aufgetreten. Bitte versuche es erneut oder kontaktiere den Support.", player, 255,0,0)
                    kickPlayer(player, "Fehler beim Laden der Accountdaten.")
                    if isElement(player) and getPlayerAccount(player) and not isGuestAccount(getPlayerAccount(player)) then pcall(logOut, player) end
                    return
                end

                triggerEvent("onPlayerLoginSuccess", player) --

                if type(loadAndSetPlayerSkin) == "function" then --
                    pcall(loadAndSetPlayerSkin, player) --
                else
                    outputDebugString("[Login] Funktion loadAndSetPlayerSkin nicht gefunden.")
                end

                local spawnOK, loadPosResult = false, false
                if type(loadPlayerPosition) == "function" then --
                    spawnOK, loadPosResult = pcall(loadPlayerPosition,player) --
                    if not spawnOK then
                        outputDebugString("[Login] Fehler beim Aufrufen von loadPlayerPosition: " .. tostring(loadPosResult))
                    end
                else
                    outputDebugString("[Login] Funktion loadPlayerPosition nicht gefunden.")
                end
                if not spawnOK or not loadPosResult then
                     spawnPlayer(player, 0,0,3, 0, getElementModel(player) or 0, 0, 1)
                     fadeCamera(player, true, 1); setCameraTarget(player, player)
                     toggleAllControls(player, true); setElementFrozen(player, false)
                end

                local weaponsToRestore = loadPlayerWeaponsFromSQL(player) --
                local playerFid, playerRank = -1, -1
                if type(_G.getPlayerFractionAndRank) == "function" then
                    playerFid, playerRank = _G.getPlayerFractionAndRank(player)
                else
                    outputDebugString("[Login] getPlayerFractionAndRank nicht gefunden, Waffen-Logik kann fehlschlagen.")
                end
                 

                if getElementData(player, "policeImDienst") == true and playerFid == POLICE_FRACTION_ID_LOGIN then --
                    if exports.tarox and type(exports.tarox.givePoliceDutyWeapons) == "function" then --
                        exports.tarox:givePoliceDutyWeapons(player, weaponsToRestore) --
                    elseif type(givePoliceDutyWeapons) == "function" then --
                        givePoliceDutyWeapons(player, weaponsToRestore) --
                    else
                        outputDebugString("[Login] FEHLER: givePoliceDutyWeapons nicht gefunden.")
                        if #weaponsToRestore > 0 then takeAllWeapons(player); for _, wd in ipairs(weaponsToRestore) do giveWeapon(player, wd.weaponID, wd.ammo) end end
                    end
                elseif getElementData(player, "mechanicImDienst") == true and playerFid == MECHANIC_FRACTION_ID_LOGIN then --
                    if exports.tarox and type(exports.tarox.giveMechanicDutyTools) == "function" then --
                        exports.tarox:giveMechanicDutyTools(player, weaponsToRestore) --
                    elseif type(giveMechanicDutyTools) == "function" then --
                        giveMechanicDutyTools(player, weaponsToRestore) --
                    else
                        outputDebugString("[Login] FEHLER: giveMechanicDutyTools nicht gefunden.")
                        if #weaponsToRestore > 0 then takeAllWeapons(player); for _, wd in ipairs(weaponsToRestore) do giveWeapon(player, wd.weaponID, wd.ammo) end end
                    end
                elseif playerFid == COSA_NOSTRA_FRACTION_ID_LOGIN or playerFid == MOCRO_MAFIA_FRACTION_ID_LOGIN or playerFid == YAKUZA_FRACTION_ID_LOGIN then --
                    if #weaponsToRestore > 0 then
                        takeAllWeapons(player)
                        for _, wd in ipairs(weaponsToRestore) do giveWeapon(player, wd.weaponID, wd.ammo) end
                    else
                        takeAllWeapons(player)
                    end
                elseif #weaponsToRestore > 0 then
                    takeAllWeapons(player)
                    for _, wd in ipairs(weaponsToRestore) do
                        giveWeapon(player, wd.weaponID, wd.ammo)
                    end
                else
                    takeAllWeapons(player)
                end

                triggerClientEvent(player, "loginSuccess", player)
                triggerEvent("onPlayerLoginComplete", player, accountID) --
            else
                triggerClientEvent(player, "showMessage", player, "Login fehlgeschlagen (MTA Account Fehler).", 255, 0, 0)
                fadeCamera(player, true, 0.5); toggleAllControls(player, true); setElementFrozen(player, false)
            end
        else
            triggerClientEvent(player, "showMessage", player, "Falsches Passwort!", 255, 0, 0)
        end
    else
        triggerClientEvent(player, "showMessage", player, "Account existiert nicht!", 255, 0, 0)
    end
end)


function loadAndSetPlayerSkin(player)
    if not isElement(player) then return false end
    local accID = getElementData(player, "account_id")
    if not accID then
        return false
    end

    local getPlayerFractionAndRankFunc = _G.getPlayerFractionAndRank --
    if not getPlayerFractionAndRankFunc then
        outputDebugString("[Login|Skin] getPlayerFractionAndRank Funktion nicht gefunden.")
        return false
    end

    local fid, rank = getPlayerFractionAndRankFunc(player) 

    local accountSkinResult, errMsg = exports.datenbank:queryDatabase("SELECT standard_skin FROM account WHERE id=? LIMIT 1", accID) --
    if not accountSkinResult then
        outputDebugString("[Login|Skin] DB-Fehler beim Laden des Standard-Skins für AccID " .. accID .. ": " .. (errMsg or "Unbekannt"))
        return false
    end

    local standard_skin_db = _G.DEFAULT_CIVIL_SKIN or 29 --

    if accountSkinResult and accountSkinResult[1] then
        standard_skin_db = tonumber(accountSkinResult[1].standard_skin) or standard_skin_db
    end

    local targetSkin = standard_skin_db

    if fid and fid > 0 then
        local isOnDuty = false
        if fid == POLICE_FRACTION_ID_LOGIN then --
            isOnDuty = getElementData(player, "policeImDienst") or false --
        elseif fid == MEDIC_FRACTION_ID_LOGIN then --
            isOnDuty = getElementData(player, "medicImDienst") or false --
        elseif fid == MECHANIC_FRACTION_ID_LOGIN then --
            isOnDuty = getElementData(player, "mechanicImDienst") or false --
        else
            if _G.FRACTION_SKINS and _G.FRACTION_SKINS[fid] then --
                 local factionSpecificSkins = _G.FRACTION_SKINS[fid] --
                 targetSkin = factionSpecificSkins[math.min(rank, #factionSpecificSkins)] or factionSpecificSkins[1] or standard_skin_db
            end
        end

        if isOnDuty then
             if _G.FRACTION_SKINS and _G.FRACTION_SKINS[fid] then --
                 local factionSkinsForDuty = _G.FRACTION_SKINS[fid] --
                 targetSkin = factionSkinsForDuty[math.min(rank, #factionSkinsForDuty)] or factionSkinsForDuty[1] or standard_skin_db
             end
        elseif not isOnDuty and (fid == POLICE_FRACTION_ID_LOGIN or fid == MEDIC_FRACTION_ID_LOGIN or fid == MECHANIC_FRACTION_ID_LOGIN) then --
            targetSkin = standard_skin_db
        end
    end

    if getElementModel(player) ~= targetSkin then
        setElementModel(player, targetSkin)
    end
    return true
end

function saveCurrentPlayerWeaponsToSQL(player)
    if not isElement(player) then return false end
    local accountID = getElementData(player, "account_id")
    if not accountID then
        return false
    end

    local weaponsInHand = {}
    for slot = 0, 12 do
        local weaponInSlot = getPedWeapon(player, slot)
        if weaponInSlot and weaponInSlot > 0 then
            local alreadyAdded = false
            for _, existingWep in ipairs(weaponsInHand) do
                if existingWep.weaponID == weaponInSlot then
                    alreadyAdded = true
                    break
                end
            end
            if not alreadyAdded and #weaponsInHand < 9 then
                table.insert(weaponsInHand, {
                    weaponID = weaponInSlot,
                    ammo = getPedTotalAmmo(player, slot)
                })
            end
        end
    end

    local insertIgnoreSuccess, insertIgnoreErr = exports.datenbank:executeDatabase("INSERT IGNORE INTO weapons (account_id) VALUES (?)", accountID) --
    if not insertIgnoreSuccess then
        outputDebugString("[SaveCurrentWeapons] FEHLER: DB INSERT IGNORE für weapons Tabelle fehlgeschlagen für AccID " .. accountID .. ": " .. (insertIgnoreErr or "Unbekannt"))
    end

    local updatesSQLParts = {}
    local paramsSQL = {}
    for i = 1, 9 do
        if weaponsInHand[i] then
            table.insert(updatesSQLParts, string.format("weapon_slot%d = ?", i))
            table.insert(paramsSQL, weaponsInHand[i].weaponID)
            table.insert(updatesSQLParts, string.format("ammo_slot%d = ?", i))
            table.insert(paramsSQL, weaponsInHand[i].ammo)
        else
            table.insert(updatesSQLParts, string.format("weapon_slot%d = NULL", i))
            table.insert(updatesSQLParts, string.format("ammo_slot%d = 0", i))
        end
    end
    table.insert(paramsSQL, accountID)

    if #updatesSQLParts == 0 then
         local resetQuery = "UPDATE weapons SET " .. table.concat((function() local t={} for i=1,9 do table.insert(t, string.format("weapon_slot%d = NULL, ammo_slot%d = 0",i,i)) end return t end)(), ", ") .. " WHERE account_id = ?"
         local successClear, errMsgClear = exports.datenbank:executeDatabase(resetQuery, accountID) --
         if not successClear then outputDebugString("[SaveCurrentWeapons] FEHLER beim Leeren der Slots für AccID "..accountID..": ".. (errMsgClear or "Unbekannt"))
         end
         return successClear
    end
    
    local queryString = "UPDATE weapons SET " .. table.concat(updatesSQLParts, ", ") .. " WHERE account_id = ?"
    local successUpdate, errMsgUpdate = exports.datenbank:executeDatabase(queryString, unpack(paramsSQL)) --

    if not successUpdate then
        outputDebugString("[SaveCurrentWeapons] FEHLER beim Speichern der aktuellen Waffen in SQL für " .. getPlayerName(player) .. ": " .. (errMsgUpdate or "Unbekannt"))
    end
    return successUpdate
end
_G.saveCurrentPlayerWeaponsToSQL = saveCurrentPlayerWeaponsToSQL --


function handlePlayerQuitCleanupAndSave(player)
    if not isElement(player) then return end
    local playerName = getPlayerName(player)
    local accID = getElementData(player, "account_id")

    if not accID then
        if isElement(player) and getPlayerAccount(player) and not isGuestAccount(getPlayerAccount(player)) then
             pcall(logOut, player)
        end
        return
    end

    local fid_quit, rank_quit = -1, -1
    if type(_G.getPlayerFractionAndRank) == "function" then
        fid_quit, rank_quit = _G.getPlayerFractionAndRank(player)
    else
        outputDebugString("[QuitSave] getPlayerFractionAndRank nicht gefunden, Waffen-Speicherung kann fehlschlagen.")
    end

    if (fid_quit == POLICE_FRACTION_ID_LOGIN and getElementData(player, "policeImDienst") == true) then --
        if type(savePoliceDutyWeaponsToSQL) == "function" then pcall(savePoliceDutyWeaponsToSQL, player) --
        elseif exports.tarox and type(exports.tarox.savePoliceDutyWeaponsToSQL) == "function" then pcall(exports.tarox.savePoliceDutyWeaponsToSQL, player) --
        else outputDebugString("[QuitProcess] WARNUNG: savePoliceDutyWeaponsToSQL (für Polizei) nicht gefunden!") end
    elseif (fid_quit == MECHANIC_FRACTION_ID_LOGIN and getElementData(player, "mechanicImDienst") == true) then --
        if type(saveMechanicDutyToolsToSQL) == "function" then pcall(saveMechanicDutyToolsToSQL, player) --
        else outputDebugString("[QuitProcess] WARNUNG: saveMechanicDutyToolsToSQL (für Mechaniker) nicht gefunden!") end
    elseif fid_quit == COSA_NOSTRA_FRACTION_ID_LOGIN or --
           fid_quit == MOCRO_MAFIA_FRACTION_ID_LOGIN or --
           fid_quit == YAKUZA_FRACTION_ID_LOGIN then --
        if type(_G.saveCurrentPlayerWeaponsToSQL) == "function" then --
            pcall(_G.saveCurrentPlayerWeaponsToSQL, player) --
        else
            outputDebugString("[QuitProcess] WARNUNG: saveCurrentPlayerWeaponsToSQL nicht gefunden für Fraktion " .. fid_quit)
        end
    end

    if type(savePlayerPosition) == "function" then pcall(savePlayerPosition, player) end --
    if type(savePlayerMoney) == "function" then pcall(savePlayerMoney, player) end --
    if type(updatePlayerPlaytimeFor) == "function" then pcall(updatePlayerPlaytimeFor, player, true) end --
    if type(savePlayerInventory) == "function" then pcall(savePlayerInventory, player) end --

    if fid_quit == MEDIC_FRACTION_ID_LOGIN and type(setPlayerMedicDutyStatus) == "function" then --
        pcall(setPlayerMedicDutyStatus, player, getElementData(player, "medicImDienst") or false) --
    elseif fid_quit == POLICE_FRACTION_ID_LOGIN and type(setPlayerPoliceDutyStatus) == "function" then --
        pcall(setPlayerPoliceDutyStatus, player, getElementData(player, "policeImDienst") or false) --
    elseif fid_quit == MECHANIC_FRACTION_ID_LOGIN and type(setPlayerMechanicDutyStatus) == "function" then --
        pcall(setPlayerMechanicDutyStatus, player, getElementData(player, "mechanicImDienst") or false) --
    end

    local cleanupKeys = {
        "account_id", "adminLevel", "group", "rank", "totalPlaytime", "playtime",
        "wanted", "prisontime", "nextWantedReductionTick", "currentHouseExterior",
        "spawnedVehicleElement", "lastSavedMoney", "standard_skin", "fraction_skin",
        "medicImDienst", "policeImDienst", "mechanicImDienst",
        "nametagColorR", "nametagColorG", "nametagColorB", "loggedin"
    }
    for _, key in ipairs(cleanupKeys) do
        if isElement(player) and getElementData(player, key) ~= nil then
             removeElementData(player, key)
        end
    end

    if isElement(player) then
        local mtaAccount = getPlayerAccount(player);
        if mtaAccount and not isGuestAccount(mtaAccount) then
             pcall(logOut, player);
        end
    end
end

addCommandHandler("logout", function(player, command) --
    if not getElementData(player, "account_id") and isGuestAccount(getPlayerAccount(player)) then
        outputChatBox("Du bist nicht eingeloggt.", player, 255, 165, 0)
        return
    end
    outputChatBox("Du wirst ausgeloggt...", player, 0, 255, 0)
    handlePlayerQuitCleanupAndSave(player)
    triggerClientEvent(player, "forceShowLogin", player) --
end)

addEventHandler("onPlayerQuit", root, function() --
    handlePlayerQuitCleanupAndSave(source)
end)

addEventHandler("onResourceStop", resourceRoot, function(stoppedResource) --
    if source == resourceRoot then
        local loggedInPlayers = 0
        for _, player in ipairs(getElementsByType("player")) do
            if isElement(player) and getElementData(player, "account_id") then
                handlePlayerQuitCleanupAndSave(player)
                loggedInPlayers = loggedInPlayers + 1
            end
        end
    end
end)

--outputDebugString("[Login] Login-System (Server - V8 Nametag-Farben Integration) geladen.")