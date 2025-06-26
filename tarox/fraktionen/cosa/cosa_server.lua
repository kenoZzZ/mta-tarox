-- tarox/fraktionen/cosa/cosa_server.lua
-- Nutzt die zentrale Spawn-Prüfungsfunktion aus fractions_server.lua
-- ANGEPASST V1.1: Verbesserte Fehlerbehandlung
-- ANGEPASST V1.2: Waffengeben aus onPlayerLoginSuccess entfernt

local FRACTION_ID  = 4
local fractionName = "Cosa Nostra"
local cosaSpawn = { x = -1911.49988, y = 1388.20898, z = 7.18250, rot = 180 }
local gateObject
local isGateOpen = false
local gateConfig = {
    model = 980,
    closedPos = { x=-1888.90039, y=1361.70020, z=9,   rx=0, ry=0, rz=44.9945 },
    openPos   = { x=-1888.90002, y=1361.69995, z=14.4,rx=0, ry=0, rz=44.9945 },
    checkRadius= 7
}
local cosaVehiclesConfig = {
    { model=545, x=-1899.3, y=1359.6, z=7.1, rot=0,   minRank=1 }, { model=545, x=-1902.2, y=1359.6, z=7.1, rot=0,   minRank=1 },
    { model=551, x=-1905.7, y=1360.2, z=7.1, rot=0,   minRank=1 }, { model=551, x=-1909.5, y=1360.2, z=7.1, rot=0,   minRank=1 },
    { model=581, x=-1910.4, y=1377.5, z=6.9, rot=270, minRank=3 }, { model=581, x=-1910.5, y=1375.8, z=6.9, rot=270, minRank=3 },
    { model=487, x=-1923.8, y=1346.9, z=21.8, rot=270, minRank=4 }, { model=487, x=-1923.9, y=1360.4, z=21.8, rot=270, minRank=4 },
}
local cosaVehicles = {}
local despawnTimers = {}
local interiorMarkers = {
    { x=-1911.8, y=1373.3, z=6.2, int=0, dim=0, tx=2364.94531, ty=-1133.60950, tz=1050.87500, tint=8, tdim=0, color={0,0,0,150} },
    { x=2365.20532, y=-1135.59888, z=1050.88257, int=8, dim=0, tx=-1909.67639, ty=1372.98486, tz=7.18750, tint=0, tdim=0, color={0,0,0,150} },
    { x=2363.84839, y=-1127.44897, z=1050.88257, int=8, dim=0, tx=-1928.68921, ty=1353.81494, tz=21.58278, tint=0, tdim=0, color={0,0,0,150} },
    { x=-1928.68921, y=1353.81494, z=21.58278, int=0, dim=0, tx=2363.84839, ty=-1127.44897, tz=1050.88257, tint=8, tdim=0, color={0,0,0,150} },
}
local cosaSkins = { [1]=297, [2]=298, [3]=124, [4]=125, [5]=126 } -- Skins für Cosa Nostra

addEventHandler("onResourceStart", resourceRoot, function()
    local db_check = exports.datenbank:getConnection()
    if not db_check then
        outputDebugString("[CosaNostra] WARNUNG bei onResourceStart: Keine DB-Verbindung!", 1)
    end

    gateObject = createObject(gateConfig.model, gateConfig.closedPos.x, gateConfig.closedPos.y, gateConfig.closedPos.z, gateConfig.closedPos.rx, gateConfig.closedPos.ry, gateConfig.closedPos.rz)
    if isElement(gateObject) then
        setObjectBreakable(gateObject, false)
        isGateOpen = false
    else
        outputDebugString("[CosaNostra] FEHLER: Haupttor konnte nicht erstellt werden!", 2)
    end

    for _, data in ipairs(cosaVehiclesConfig) do
        local veh = createVehicle(data.model, data.x, data.y, data.z, 0, 0, data.rot)
        if veh then
            setElementData(veh, "cosaVehicle", true)
            setElementData(veh, "minRank", data.minRank or 5) 
            setVehicleColor(veh, 0, 0, 0)
            cosaVehicles[veh] = data
        else
            outputDebugString("[CosaNostra] FEHLER: Fahrzeug Model " .. data.model .. " konnte nicht erstellt werden!", 2)
        end
    end

    for _, mData in ipairs(interiorMarkers) do
        local marker = createMarker(mData.x, mData.y, mData.z, "cylinder", 1.5, mData.color[1], mData.color[2], mData.color[3], mData.color[4])
        if isElement(marker) then
            setElementInterior(marker, mData.int)
            setElementDimension(marker, mData.dim)
            setElementData(marker, "cosaMarkerData", { tx=mData.tx, ty=mData.ty, tz=mData.tz, tint=mData.tint, tdim=mData.tdim })
            addEventHandler("onMarkerHit", marker, function(hitElem, matchingDim)
                if matchingDim and getElementType(hitElem)=="player" and not isPedInVehicle(hitElem) then
                    handleCosaMarkerHit(hitElem, source)
                end
            end)
        else
            outputDebugString("[CosaNostra] FEHLER: Interior-Marker konnte nicht erstellt werden bei x=" .. mData.x, 2)
        end
    end
    --outputDebugString("[CosaNostra] Cosa Nostra Script (Server V1.2 - Waffenlogik in onLoginSuccess entfernt) geladen.")
end)

setTimer(function()
    if not isElement(gateObject) then return end
    local nearbyCosaMember = false
    local gx, gy, gz = gateConfig.closedPos.x, gateConfig.closedPos.y, gateConfig.closedPos.z
    local radius = gateConfig.checkRadius or 7
    local dimension = getElementDimension(gateObject)
    local interior = getElementInterior(gateObject)
    local nearbyPlayers = getElementsWithinRange(gx, gy, gz, radius, "player")

    for _, player in ipairs(nearbyPlayers) do
        if getElementDimension(player) == dimension and getElementInterior(player) == interior then
            local fid, rank = getPlayerFractionAndRank(player)
            if fid == FRACTION_ID then
                nearbyCosaMember = true
                break
            end
        end
    end
    if nearbyCosaMember then openCosaGate() else closeCosaGate() end
end, 3000, 0)

function openCosaGate()
    if isGateOpen or not isElement(gateObject) then return end
    moveObject(gateObject, 2000, gateConfig.openPos.x, gateConfig.openPos.y, gateConfig.openPos.z, gateConfig.openPos.rx - gateConfig.closedPos.rx, gateConfig.openPos.ry - gateConfig.closedPos.ry, gateConfig.openPos.rz - gateConfig.closedPos.rz)
    isGateOpen = true
end

function closeCosaGate()
    if not isGateOpen or not isElement(gateObject) then return end
    moveObject(gateObject, 2000, gateConfig.closedPos.x, gateConfig.closedPos.y, gateConfig.closedPos.z, gateConfig.closedPos.rx - gateConfig.openPos.rx, gateConfig.closedPos.ry - gateConfig.openPos.ry, gateConfig.closedPos.rz - gateConfig.openPos.rz)
    isGateOpen = false
end

function handleCosaMarkerHit(player, marker)
    local fid, rank = getPlayerFractionAndRank(player)
    if fid ~= FRACTION_ID then
        outputChatBox("[Cosa] Only for Cosa Nostra!", player, 255,0,0)
        return
    end
    if getElementData(player, "isTeleporting") then return end
    local data = getElementData(marker, "cosaMarkerData")
    if not data then return end
    setElementData(player, "isTeleporting", true)
    fadeCamera(player, false, 1)
    setTimer(function()
        if isElement(player) then
            setElementInterior(player, data.tint or 0)
            setElementDimension(player, data.tdim or 0)
            setElementPosition(player, data.tx, data.ty, data.tz)
            fadeCamera(player, true, 1)
            setTimer(function() if isElement(player) then setElementData(player, "isTeleporting", false) end end, 2000, 1)
        end
    end, 1000, 1)
end

addEventHandler("onVehicleStartEnter", root, function(player, seat)
    if seat == 0 and getElementData(source, "cosaVehicle") then
        local fid, rank = getPlayerFractionAndRank(player)
        if fid ~= FRACTION_ID then
            cancelEvent()
            outputChatBox("[Cosa] Only for Cosa Nostra!", player,255,0,0)
            return
        end
        local minR = getElementData(source, "minRank") or 5
        if rank < minR then
            cancelEvent()
            outputChatBox("[Cosa] Your Rank is not high enough (min. Rank"..minR..")!", player,255,0,0)
        end
    end
end)

addEventHandler("onVehicleExit", root, function(player)
    if getElementData(source, "cosaVehicle") then
        local vehicle = source
        if despawnTimers[vehicle] then killTimer(despawnTimers[vehicle]); despawnTimers[vehicle] = nil; end
        outputChatBox("[Cosa] You have exited the vehicle. It will despawn in 10 minutes unless you re-enter!", player, 255,165,0)
        despawnTimers[vehicle] = setTimer(function(veh)
            if isElement(veh) and not getVehicleOccupant(veh) then
                respawnCosaVehicle(veh)
            end
        end, 600000, 1, vehicle)
    end
end)

addEventHandler("onVehicleEnter", root, function(player, seat)
    if seat == 0 and getElementData(source, "cosaVehicle") then
        local vehicle = source
        if despawnTimers[vehicle] then
            killTimer(despawnTimers[vehicle])
            despawnTimers[vehicle] = nil
            outputChatBox("[Cosa] The despawn timer has been canceled because you re-entered!", player, 0,255,0)
        end
    end
end)

addEventHandler("onVehicleExplode", root, function()
    if not isElement(source) then return end
    if getElementData(source, "cosaVehicle") then
        setTimer(respawnCosaVehicle, 5000, 1, source)
    end
end)

function respawnCosaVehicle(vehicle)
    if not isElement(vehicle) or not cosaVehicles[vehicle] then return end
    local data = cosaVehicles[vehicle]
    destroyElement(vehicle)
    local newVeh = createVehicle(data.model, data.x, data.y, data.z, 0, 0, data.rot)
    if not isElement(newVeh) then
        outputDebugString("[Cosa] createVehicle fehlgeschlagen, Model="..tostring(data.model))
        return
    end
    setElementData(newVeh, "cosaVehicle", true)
    setElementData(newVeh, "minRank", data.minRank or 5)
    setVehicleColor(newVeh, 0,0,0)
    cosaVehicles[newVeh] = data
end

addCommandHandler("cosa", function(player)
    local fid, rank = getPlayerFractionAndRank(player)
    if fid ~= FRACTION_ID then
        outputChatBox("[Cosa] You are not a Cosa Nostra!", player,255,0,0)
        return
    end
    triggerClientEvent(player, "openCosaWindow", player)
end)

local function giveCosaWeapons(player)
    if not isElement(player) or not getElementData(player, "account_id") then return end
    local _, rank = getPlayerFractionAndRank(player)
    if getPlayerFractionAndRank(player) ~= FRACTION_ID then return end -- Sicherstellen, dass es wirklich ein Cosa ist
    takeAllWeapons(player)
    local meleeWeapon = 5 
    if rank == 1 then giveWeapon(player, 22, 30); giveWeapon(player, meleeWeapon, 1);
    elseif rank == 2 then giveWeapon(player, 24, 14); giveWeapon(player, meleeWeapon, 1); giveWeapon(player, 25, 15);
    elseif rank == 3 then giveWeapon(player, 24, 21); giveWeapon(player, meleeWeapon, 1); giveWeapon(player, 25, 20); giveWeapon(player, 29, 60);
    elseif rank == 4 then giveWeapon(player, 24, 28); giveWeapon(player, meleeWeapon, 1); giveWeapon(player, 25, 25); giveWeapon(player, 29, 90); giveWeapon(player, 30, 30); giveWeapon(player, 16, 1);
    elseif rank == 5 then giveWeapon(player, 24, 35); giveWeapon(player, meleeWeapon, 1); giveWeapon(player, 25, 30); giveWeapon(player, 29, 120); giveWeapon(player, 30, 60); giveWeapon(player, 16, 2); giveWeapon(player, 34, 7);
    end
end

addEvent("onCosaRequestSpawn", true)
addEventHandler("onCosaRequestSpawn", root, function()
    local player = source
    local allowedToSpawn, messageSpawn = exports.tarox:canPlayerUseFactionSpawnCommand(player)
    if not allowedToSpawn then
        outputChatBox(messageSpawn, player, 255, 100, 0)
        return
    end

    local fid, rank = getPlayerFractionAndRank(player)
    if fid ~= FRACTION_ID then
        outputChatBox("[Cosa] Du bist kein Cosa Nostra!", source, 255,0,0)
        return
    end
    local skinID = cosaSkins[rank] or cosaSkins[1]
    spawnPlayer(source, cosaSpawn.x, cosaSpawn.y, cosaSpawn.z, cosaSpawn.rot, skinID)
    fadeCamera(source, true)
    setCameraTarget(source, source)
    giveCosaWeapons(source)
    outputChatBox("[Cosa] Du wurdest als Cosa Nostra (Rank " .. rank .. ") gespawnt!", source, 0,255,0)
end)

addEvent("onCosaRequestLeave", true)
addEventHandler("onCosaRequestLeave", root, function()
    local player = source
    local fid, rank = getPlayerFractionAndRank(player)
    if fid ~= FRACTION_ID then
        outputChatBox("[Cosa] You are not a Cosa Nostra", source,255,0,0)
        return
    end
    local accID = getElementData(source,"account_id")
    if not accID then
        outputChatBox("[Cosa] account_id nicht gefunden!", source,255,0,0)
        return
    end

    local deleteSuccess, errMsg = exports.datenbank:executeDatabase("DELETE FROM fraction_members WHERE account_id=? AND fraction_id=?", accID, FRACTION_ID)
    if not deleteSuccess then
        outputChatBox("[Cosa] Fehler beim Verlassen der Fraktion (Datenbankfehler): " .. (errMsg or "Unbekannt"), source, 255,0,0)
        outputDebugString("[CosaNostra] FEHLER: DB DELETE für AccID " .. accID .. " fehlgeschlagen: " .. (errMsg or "Unbekannt"), 2)
        return
    end

    if type(_G.refreshPlayerFractionData) == "function" then
        _G.refreshPlayerFractionData(source)
    else
        outputDebugString("[CosaNostra] WARNUNG: _G.refreshPlayerFractionData nicht gefunden nach Fraktionsaustritt.")
    end

    takeAllWeapons(source)
    local standardSkinResult, skinErrMsg = exports.datenbank:queryDatabase("SELECT standard_skin FROM account WHERE id=? LIMIT 1", accID)
    local standardSkin = (_G.DEFAULT_CIVIL_SKIN or 0)
    if not standardSkinResult then
        outputDebugString("[CosaNostra] DB Fehler beim Laden des Standard-Skins für AccID " .. accID .. " (Leave): " .. (skinErrMsg or "Unbekannt"))
    elseif standardSkinResult and standardSkinResult[1] and tonumber(standardSkinResult[1].standard_skin) then
        standardSkin = tonumber(standardSkinResult[1].standard_skin)
    end
    setElementModel(source, standardSkin)
    outputChatBox("[Cosa] You leaved Cosa Nostra!", source,255,165,0)
end)

addEventHandler("onPlayerLoginSuccess", root, function()
    local player = source
    local accID = getElementData(player, "account_id")
    if not accID then return end

    local fid, rank = getPlayerFractionAndRank(player)
    if fid == FRACTION_ID then
        local skinID = cosaSkins[rank] or cosaSkins[1]
        if getElementModel(player) ~= skinID then
            -- Nur setzen, wenn der Skin nicht schon durch login_server.lua's loadAndSetPlayerSkin gesetzt wurde.
            -- loadAndSetPlayerSkin sollte bereits den korrekten Fraktionsskin setzen.
            -- Diese zusätzliche Prüfung hier ist eher ein Fallback oder zur Sicherstellung.
            -- setElementModel(player, skinID) 
        end
        --outputDebugString("[CosaNostra] onPlayerLoginSuccess: Daten für Cosa Nostra Mitglied "..getPlayerName(player).." verarbeitet.")
        -- Keine Waffenausgabe hier, das übernimmt login_server.lua für gespeicherte Waffen,
        -- oder der /cosa Befehl für Standard-Fraktionswaffen.
    end
end)

addEventHandler("onResourceStop", resourceRoot, function()
    if isElement(gateObject) then destroyElement(gateObject); gateObject = nil end
    --outputDebugString("[CosaNostra] Cosa Nostra Script (Server V1.2) gestoppt.")
end)