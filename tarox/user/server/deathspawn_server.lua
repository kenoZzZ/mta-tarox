-- tarox/user/server/deathspawn_server.lua
-- VERSION 13: Client-seitiger Haupttimer (150s) für Medic-Revive-Fenster
-- ANGEPASST V13.1: Überprüfung auf globale Fraktionsfunktion

-- Globale Funktionen (werden über _G erwartet oder direkt aufgerufen, falls im selben Skript definiert)
-- local getPlayerFractionAndRank = _G.getPlayerFractionAndRank
-- local arrestPlayer = _G.arrestPlayer -- Wird von jail_server.lua global gemacht

-- Standard Krankenhaus/City Spawn
local defaultSpawn = { x=-2758.93994, y=375.28598, z=4.33567, rot=270, int=0, dim=0 }

-- Fraktionsbasen (Dimensionen wie von dir in V10 angegeben)
local fractionBases = {
    ["Police"]      = { x=-1586.83459, y=724.70258,  z=-4.90625, rot=270, int=0, dim=0 },
    ["Swat"]        = { x=2231.11,    y=2457.35,    z=10.82,    rot=180, int=0, dim=0 },
    ["Medic"]       = { x=-2654.39795, y=633.56366,  z=14.45312, rot=0,   int=0, dim=0 },
    ["Cosa Nostra"] = { x=-1911.49988, y=1388.20898, z=7.18250,  rot=180, int=0, dim=0 },
    ["Mocro Mafia"] = { x=-2459.23438, y=-139.27902, z=25.91920, rot=0,   int=0, dim=0 },
    ["Yakuza"]      = { x=-2178.63281, y=702.67426,  z=53.89062, rot=0,   int=0, dim=0 },
    ["Mechanic"]	= { x=-2048.60669, y=143.98064,  z=28.83594, rot=180,   int=0, dim=0 },
}

local interiorSpawnPositions = {
    [3] = { x = 230.5, y = 1050.8, z = 1003.0, rot = 90 },
    [4] = { x = 260.98001, y = 1284.55005, z = 1080.25781, rot = 90 },
    [5] = { x = 140.0, y = 1370.0, z = 1083.8, rot = 180 },
    [6] = { x = -68.69000, y = 1351.96997, z = 1080.21094, rot = 0 },
    [8] = { x = 2364.9, y = -1133.6, z = 1050.8, rot = 0 },
    [9] = { x = 2317.5, y = -1026.0, z = 1050.2, rot = 0 },
    [18] = { x = 163.1, y = -94.4, z = 1001.8, rot = 0 },
}

_G.awaitingRevive = {}
local REVIVE_WINDOW_MS = 15 * 1000 -- 150 Sekunden (2:30 Minuten)

addEvent("onSpawnRequestCity", true)
addEventHandler("onSpawnRequestCity", root, function()
    local player = client; if not isElement(player) then return end
    if getElementData(player, "currentHouseExterior") then removeElementData(player, "currentHouseExterior") end
    if _G.awaitingRevive[player] then
        if isTimer(_G.awaitingRevive[player].reviveTimer) then killTimer(_G.awaitingRevive[player].reviveTimer) end
        _G.awaitingRevive[player] = nil; setElementData(player, "isCurrentlyDead", false)
    end
    spawnPlayerAtPosition(player, defaultSpawn)
end)

addEvent("onSpawnRequestHome", true)
addEventHandler("onSpawnRequestHome", root, function()
    local player = client; if not isElement(player) then return end
    local playerAccountID = getElementData(player, "account_id"); local homeSpawnParams, exteriorCoords = nil

    if playerAccountID then
        local houseResult, errMsg = exports.datenbank:queryDatabase("SELECT id, interior_id, posX, posY, posZ, interior_posX, interior_posY, interior_posZ FROM houses WHERE owner_account_id = ? LIMIT 1", playerAccountID)
        if not houseResult then
            outputChatBox("❌ Datenbankfehler beim Laden der Hausdaten: " .. (errMsg or "Unbekannt"), player,255,0,0)
            if _G.awaitingRevive[player] then if isTimer(_G.awaitingRevive[player].reviveTimer) then killTimer(_G.awaitingRevive[player].reviveTimer) end; _G.awaitingRevive[player] = nil; setElementData(player, "isCurrentlyDead", false); end
            spawnPlayerAtPosition(player,defaultSpawn); return
        end

        if houseResult and houseResult[1] then
            local d=houseResult[1]; local hID=tonumber(d.id); local intID=tonumber(d.interior_id)
            if hID and intID and intID > 0 then
                local sX,sY,sZ,sRot
                if d.interior_posX and d.interior_posY and d.interior_posZ then sX,sY,sZ,sRot=tonumber(d.interior_posX),tonumber(d.interior_posY),tonumber(d.interior_posZ),0
                elseif interiorSpawnPositions[intID] then local dP=interiorSpawnPositions[intID]; sX,sY,sZ,sRot=dP.x,dP.y,dP.z,dP.rot or 0
                else sX,sY,sZ,sRot,intID,hID=0,0,5,0,0,0 end -- Fallback
                exteriorCoords={x=d.posX,y=d.posY,z=d.posZ}
                homeSpawnParams={x=sX,y=sY,z=sZ,rot=sRot,int=intID,dim=hID}
            else outputChatBox("❌ Hausdaten unvollständig oder kein Interior gesetzt.",player,255,165,0) end
        else outputChatBox("❌ Du besitzt kein Haus.",player,255,165,0) end
    else outputChatBox("❌ Account-Fehler.",player,255,0,0) end

    if _G.awaitingRevive[player] then if isTimer(_G.awaitingRevive[player].reviveTimer) then killTimer(_G.awaitingRevive[player].reviveTimer) end; _G.awaitingRevive[player] = nil; setElementData(player, "isCurrentlyDead", false); end
    spawnPlayerAtPosition(player, homeSpawnParams or defaultSpawn, exteriorCoords)
end)

addEvent("onSpawnRequestFactionBase", true)
addEventHandler("onSpawnRequestFactionBase", root, function()
    local player = client; if not isElement(player) then return end
    local fractionName = getElementData(player, "group") or "Civil"; local base = fractionBases[fractionName]
    if base then
        if getElementData(player, "currentHouseExterior") then removeElementData(player, "currentHouseExterior") end
        if _G.awaitingRevive[player] then if isTimer(_G.awaitingRevive[player].reviveTimer) then killTimer(_G.awaitingRevive[player].reviveTimer) end; _G.awaitingRevive[player] = nil; setElementData(player, "isCurrentlyDead", false); end
        spawnPlayerAtPosition(player, base)
    else
        outputChatBox("Keine Fraktionsbasis definiert oder du bist Zivilist.", player,255,165,0)
        if getElementData(player, "currentHouseExterior") then removeElementData(player, "currentHouseExterior") end
        if _G.awaitingRevive[player] then if isTimer(_G.awaitingRevive[player].reviveTimer) then killTimer(_G.awaitingRevive[player].reviveTimer) end; _G.awaitingRevive[player] = nil; setElementData(player, "isCurrentlyDead", false); end
        spawnPlayerAtPosition(player, defaultSpawn)
    end
end)

function spawnPlayerAtPosition(player, coords, exteriorCoordsToSet)
    if not isElement(player) then return end
    if not coords then coords = defaultSpawn; exteriorCoordsToSet = nil; end

    local x,y,z,rot,interior,dimension = coords.x or defaultSpawn.x, coords.y or defaultSpawn.y, coords.z or defaultSpawn.z, coords.rot or defaultSpawn.rot, coords.int or defaultSpawn.int, coords.dim or defaultSpawn.dim
    local currentSkin = getElementModel(player) or 0
    if isElementFrozen(player) then setElementFrozen(player, false) end
    toggleAllControls(player, false, true, false)
    spawnPlayer(player, x,y,z,rot,currentSkin,interior,dimension)

    if exteriorCoordsToSet and type(exteriorCoordsToSet)=="table" and dimension > 0 then
        setElementData(player,"currentHouseExterior",exteriorCoordsToSet,false)
    elseif getElementData(player,"currentHouseExterior") then
        removeElementData(player,"currentHouseExterior")
    end
    setElementData(player, "isCurrentlyDead", false)
    fadeCamera(player,true,0.5); setCameraTarget(player,player)
    setTimer(function() if isElement(player) then setElementHealth(player,100); toggleAllControls(player,true,true,true) end end, 250,1)
    outputChatBox("Du wurdest wiederbelebt!",player,0,255,0)
end

addEventHandler("onPlayerWasted", root, function(totalAmmo, killer, killerWeapon, bodypart, stealth)
    local victim = source
    local killerName, weaponName = "Environment", getWeaponNameFromID(killerWeapon) or "Unknown"
    local killerIsPoliceOrSwat = false

    if isElement(killer) then
        if getElementType(killer) == "player" then
            if killer == victim then killerName = "Yourself (Suicide)"
            else
                killerName = getPlayerName(killer) or "Unknown Player"
                if type(_G.getPlayerFractionAndRank) == "function" then
                    local killerGroup = getElementData(killer, "group") or "Civil" -- Fallback, falls getPlayerFractionAndRank nicht gefunden
                    if killerGroup == "Police" or killerGroup == "Swat" then killerIsPoliceOrSwat = true end
                end
            end
        elseif getElementType(killer) == "vehicle" then
            local driver=getVehicleController(killer)
            if isElement(driver) and getElementType(driver)=="player" then
                local dG="Civil"
                if type(_G.getPlayerFractionAndRank) == "function" then dG = getElementData(driver,"group")or"Civil" end
                if dG=="Police"or dG=="Swat"then killerIsPoliceOrSwat=true; killerName=getPlayerName(driver)or"Police/Swat Vehicle"
                else killerName=getVehicleName(killer)or"A Vehicle"end
            else killerName=getVehicleName(killer)or"A Vehicle"end; weaponName="Ran over"
        end
    else if killerWeapon==51 then killerName,weaponName="Gravity","Fell" elseif killerWeapon==53 then killerName,weaponName="Water","Drowned" elseif killerWeapon==37 then killerName,weaponName="Fire/Explosion","Burned/Exploded" end end

    local victimWanted = getElementData(victim, "wanted") or 0
    local forceJail = (killerIsPoliceOrSwat and victimWanted > 0)

    setElementData(victim, "isCurrentlyDead", true)

    if forceJail then
        --outputDebugString("[DeathSpawn] Spieler " .. getPlayerName(victim) .. " wird ins Gefängnis geschickt. Trigger showDeathScreenClient (forceJail=true).")
        triggerClientEvent(victim, "showDeathScreenClient", victim, killerName, weaponName, true, 15000)
        setElementData(victim, "isCurrentlyDead", false)
        if _G.awaitingRevive and _G.awaitingRevive[victim] then
           if isTimer(_G.awaitingRevive[victim].reviveTimer) then killTimer(_G.awaitingRevive[victim].reviveTimer) end
            _G.awaitingRevive[victim] = nil
        end
    else
        local vX,vY,vZ = getElementPosition(victim); local vRot = getPedRotation(victim)
        local vInt = getElementInterior(victim); local vDim = getElementDimension(victim)
        if _G.awaitingRevive[victim] and isTimer(_G.awaitingRevive[victim].reviveTimer) then killTimer(_G.awaitingRevive[victim].reviveTimer) end

        _G.awaitingRevive[victim] = {
            deathX=vX, deathY=vY, deathZ=vZ, deathRot=vRot, deathInt=vInt, deathDim=vDim,
            deathTick=getTickCount(), killerName=killerName, weaponName=weaponName,
            reviveTimer = setTimer(function(playerToCleanUp)
                if isElement(playerToCleanUp) and _G.awaitingRevive and _G.awaitingRevive[playerToCleanUp] then
                    outputDebugString("[MedicRevive] Serverseitiger Aufräum-Timer für " .. getPlayerName(playerToCleanUp) .. " abgelaufen.")
                    _G.awaitingRevive[playerToCleanUp] = nil
                end
            end, REVIVE_WINDOW_MS + 5000, 1, victim)
        }

        local victimName = getPlayerName(victim)
        for _, medicPlayer in ipairs(getElementsByType("player")) do
            if type(_G.getPlayerFractionAndRank) == "function" then
                local fid, rank = _G.getPlayerFractionAndRank(medicPlayer)
                if fid == 3 and getElementData(medicPlayer, "medicImDienst") == true then
                    triggerClientEvent(medicPlayer, "medic:playerDownNotificationClient", victim, victimName, vX, vY, vZ)
                end
            end
        end
        outputDebugString("[DeathSpawn] Spieler " .. getPlayerName(victim) .. " gestorben. Trigger showDeathScreenClient (forceJail=false, duration=" .. REVIVE_WINDOW_MS .. ").")
        triggerClientEvent(victim, "showDeathScreenClient", victim, killerName, weaponName, false, REVIVE_WINDOW_MS)
    end
end)

addEvent("medic:playerRevived", true)
addEventHandler("medic:playerRevived", root, function(revivedPlayer)
    if isElement(revivedPlayer) and _G.awaitingRevive and _G.awaitingRevive[revivedPlayer] then
        if isTimer(_G.awaitingRevive[revivedPlayer].reviveTimer) then killTimer(_G.awaitingRevive[revivedPlayer].reviveTimer) end
        _G.awaitingRevive[revivedPlayer] = nil
        setElementData(revivedPlayer, "isCurrentlyDead", false)
        triggerClientEvent(revivedPlayer, "forceCloseDeathScreenClient", revivedPlayer)
        local victimName = getPlayerName(revivedPlayer)
        for _, medicPlayer in ipairs(getElementsByType("player")) do
            if type(_G.getPlayerFractionAndRank) == "function" then
                local fid, rank = _G.getPlayerFractionAndRank(medicPlayer)
                if fid == 3 and getElementData(medicPlayer, "medicImDienst") == true then
                    triggerClientEvent(medicPlayer, "medic:playerCaseClosedClient", revivedPlayer, victimName)
                end
            end
        end
    end
end)

addEventHandler("onPlayerQuit", root, function()
    if _G.awaitingRevive and _G.awaitingRevive[source] then
        if isTimer(_G.awaitingRevive[source].reviveTimer) then killTimer(_G.awaitingRevive[source].reviveTimer) end
        _G.awaitingRevive[source] = nil
    end
end)

addEvent("requestAutomaticJailSpawn", true)
addEventHandler("requestAutomaticJailSpawn", root, function()
    local player = client; if not isElement(player) then return end
    local pAccID = getElementData(player, "account_id")
    if not pAccID then
        outputDebugString("[Jail] Fehler: Keine AccID für automatischen Jail-Spawn von " .. getPlayerName(player))
        if isElement(player) then spawnPlayer(player, 0,0,5) end -- Fallback
        return
    end
    outputDebugString("[Jail] Automatischer Jail-Spawn angefordert für AccID: " .. pAccID)

    local arrestSuccess, arrestMsg
    if type(_G.arrestPlayer) == "function" then
        arrestSuccess, arrestMsg = _G.arrestPlayer(pAccID)
    else
        outputDebugString("[Jail] FEHLER: _G.arrestPlayer Funktion nicht gefunden für requestAutomaticJailSpawn!")
        arrestSuccess = false
        arrestMsg = "Jail system function not found."
    end

    if not arrestSuccess then
        outputDebugString("[Jail] Fehler beim automatischen Jail-Spawn für AccID " .. pAccID .. ": " .. (arrestMsg or "Unbekannt"))
        local playerElementForFallback = getPlayerFromAccountID(pAccID)
        if isElement(playerElementForFallback) then
            outputChatBox("Fehler beim Transfer ins Gefängnis. Spawne am Standardort.", playerElementForFallback, 255,100,0)
            spawnPlayer(playerElementForFallback, 0,0,5); fadeCamera(playerElementForFallback,true); setCameraTarget(playerElementForFallback,playerElementForFallback); toggleAllControls(playerElementForFallback,true)
        end
    end
end)

addEventHandler("onResourceStart", resourceRoot, function()
    local db_check = exports.datenbank:getConnection()
    if not db_check then
        outputDebugString("[DeathSpawn] WARNUNG bei onResourceStart: Keine DB-Verbindung! Haus-Spawn könnte fehlschlagen.", 1)
    end
    if not _G.getPlayerFractionAndRank then
         outputDebugString("[DeathSpawn] WARNUNG bei onResourceStart: _G.getPlayerFractionAndRank nicht global verfügbar! Fraktionsspezifische Logik könnte fehlschlagen.", 1)
    end
    if not _G.arrestPlayer then
         outputDebugString("[DeathSpawn] WARNUNG bei onResourceStart: _G.arrestPlayer nicht global verfügbar! Jail-Spawn bei Bedarf könnte fehlschlagen.", 1)
    end
    --outputServerLog("[DeathSpawn V13.1] Spawn-nach-Tod System (Server - DB Fehlerbehandlung) geladen.")
end)

addEventHandler("onResourceStop", resourceRoot, function()
    -- Aufräumen von Timern für alle Spieler in _G.awaitingRevive
    if _G.awaitingRevive then
        for player, data in pairs(_G.awaitingRevive) do
            if data and isTimer(data.reviveTimer) then
                killTimer(data.reviveTimer)
            end
        end
        _G.awaitingRevive = {}
    end
    --outputDebugString("[DeathSpawn] Spawn-nach-Tod System gestoppt und Revive-Timer bereinigt.")
end)