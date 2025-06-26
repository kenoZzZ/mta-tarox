-- tarox/jail/tarox_jail_server.lua (Vollständig - Mit 10s Timer & Wanted-Logik Anpassung)
-- Zentralisierte Jail-Logik & Jailbreak-System
-- ANGEPASST V1.1: Verbesserte Fehlerbehandlung für Datenbankaufrufe

-- Globale Tabelle, um Spieler im Gefängnis zu tracken
local jailedPlayers = {}
local jailTimer = nil -- Timer Variable
local lastPrisonTimeDBSave = {} -- Wann wurde Zeit zuletzt für Spieler gespeichert? { [player] = tickCount }
local PRISON_TIME_SAVE_INTERVAL_MS = 3 * 60 * 1000 -- Speichere Gefängniszeit nur alle 3 Minuten in DB
local JAIL_CHECK_INTERVAL_SECONDS = 10

if not table.isEmpty then function table.isEmpty(t) if not t then return true end return next(t) == nil end end
if not table.count then function table.count(t) if not t then return 0 end local count = 0 for _ in pairs(t) do count = count + 1 end return count end end

function getPlayerFromAccountID(accountID)
    if not accountID then return nil end; accountID = tonumber(accountID)
    if not accountID then return nil end
    for _, p in ipairs(getElementsByType("player")) do
        local pAccID = getElementData(p, "account_id")
        if pAccID and tonumber(pAccID) == accountID then return p end
    end; return nil
end

-------------------------------------------------------------------
-- A) Jailbreak-Einstellungen
-------------------------------------------------------------------
local markerFreezerPos = { x = -1510.6, y = 772.5, z = 16.5 }; local markerFreezer = nil
local countdownTimeFreezer = 120; local countdownRunningFreezer = false; local countdownValueFreezer = 0; local tCountdownFreezer = nil
local isFreezerDoorOnCooldown = false; local freezerDoorModel = 2963
local freezerDoorClosedPos = { x = -1510.0, y = 770.2, z = 18.15, rx = 0, ry = 0, rz = 270 }
local freezerDoorOpenPos = { x = -1507.8, y = 770.2, z = 18.1,  rx = 0, ry = 0, rz = 270 }; local freezerDoorObject = nil
local doorOpenDuration = 5*60; local markerDespawnTime = 10*60*1000
local markerGatesPos = { x = -1494.9, y = 724.6, z = 12.4 }; local markerGates = nil; local isGatesOnCooldown = false
local gatesOpenDuration = 10*60; local prisonGateObjects = {}; local prisonGateClosedPositions = {}
local markerOutsidePos = { x = -1513.20105, y = 748.31793, z = 10.23281 }; local markerOutside = nil
local markerInsidePos  = { x = -1507.0, y = 777.9, z = 17.7 }; local markerInside = nil
local insideToOutsideTargetPos = { x = -1514.56653, y = 748.27649, z = 10.23281 }
local chinagateModel = 2930; local gate1ClosedPos = { x = -1496.7, y = 723.2, z = 15.2, rx = 0, ry = 0, rz = 90 }; local gate1OpenPos = { x = -1498.2, y = 723.2, z = 15.2, rx = 0, ry = 0, rz = 90 }
local gate2ClosedPos = { x = -1495.0, y = 723.2, z = 15.2, rx = 0, ry = 0, rz = 90 }; local gate2OpenPos = { x = -1493.6, y = 723.2, z = 15.2, rx = 0, ry = 0, rz = 90 }; local chinagate1, chinagate2
local markerExitLobbyPos = { x = -1486.9, y = 768.4, z = 17.8 }; local markerExitLobby = nil; local exitLobbyTargetPos = { x = -1488.22278, y = 772.60791, z = 17.77031 }

-------------------------------------------------------------------
-- B) Jail-Definitionen
-------------------------------------------------------------------
local jailCells = {
    { x=-1488.00354,y=724.77301,z=7.17992 }, { x=-1487.85413,y=728.37347,z=7.17985 }, { x=-1487.44727,y=732.26404,z=7.17965 }, { x=-1488.14124,y=744.13916,z=7.17999 },
    { x=-1487.69141,y=748.24261,z=7.17977 }, { x=-1487.82654,y=752.22784,z=7.17983 }, { x=-1487.79102,y=756.13593,z=7.17981 }, { x=-1487.97266,y=760.49115,z=7.17990 },
    { x=-1487.72485,y=764.24164,z=7.17978 }, { x=-1509.51941,y=764.25397,z=7.18750 }, { x=-1509.80029,y=760.08582,z=7.18750 }, { x=-1509.38843,y=756.13068,z=7.18750 },
    { x=-1509.72620,y=752.00641,z=7.18750 }, { x=-1509.62891,y=748.14471,z=7.18750 }, { x=-1509.19849,y=744.11853,z=7.18750 }, { x=-1509.68091,y=740.11230,z=7.18750 },
    { x=-1509.74597,y=736.17102,z=7.18750 }, { x=-1509.55261,y=732.10767,z=7.18750 }, { x=-1509.49902,y=728.47681,z=7.18750 }
}
local releasePos = { x=-1522.96143,y=720.25488,z=7.18750 }

-------------------------------------------------------------------
-- C) Jail-Funktionen (arrest, free)
-------------------------------------------------------------------
function arrestPlayer(victimData, jailTimeSeconds)
    local victimAccountID = nil
    local thePlayer = nil

    if type(victimData) == "table" then
        if isElement(victimData) and getElementType(victimData) == "player" then
             thePlayer = victimData
             victimAccountID = getElementData(thePlayer, "account_id")
        elseif victimData.account_id then
             victimAccountID = victimData.account_id
             thePlayer = getPlayerFromAccountID(victimAccountID)
        else
             outputDebugString("[Jail Arrest Fn] FEHLER: Unbekannte Tabellenstruktur für victimData.")
             return false, "Invalid victim data structure"
        end
    elseif type(victimData) == "number" or type(victimData) == "string" then
        victimAccountID = tonumber(victimData)
        thePlayer = getPlayerFromAccountID(victimAccountID)
    else
        outputDebugString("[Jail Arrest Fn] FEHLER: Ungültiger Typ für victimData: " .. type(victimData))
        return false, "Invalid victim data type"
    end

    if not victimAccountID then
        outputDebugString("[Jail Arrest Fn] Fehler: Konnte keine gültige Account ID extrahieren.")
        return false, "Could not extract account ID"
    end
    if not isElement(thePlayer) then
        outputDebugString("[Jail Arrest Fn] Fehler: Spieler mit AccID " .. victimAccountID .. " ist nicht (mehr) online.")
        return false, "Player not online"
    end

    local playerName = getPlayerName(thePlayer)
    local accID = victimAccountID
    local wantedLvl = getElementData(thePlayer, "wanted") or 0
    local calculatedTime = jailTimeSeconds or (wantedLvl * 10)
    calculatedTime = math.max(10, calculatedTime)

    if wantedLvl <= 0 and not jailTimeSeconds then -- Nur ins Jail, wenn Wanteds oder explizite Zeit
        outputDebugString("[Jail Arrest Fn] Abbruch für " .. playerName .. ": Keine Wanteds und keine explizite Zeit.")
        return false, "No wanteds and no explicit jail time"
    end

    local cell = jailCells[math.random(#jailCells)]
    local skinID = getElementModel(thePlayer)
    spawnPlayer(thePlayer, cell.x, cell.y, cell.z + 0.2, 0, skinID, 0, 0)
    setPedStat(thePlayer, 24, 1000); setPedArmor(thePlayer, 0)
    setElementPosition(thePlayer, cell.x, cell.y, cell.z)
    setElementInterior(thePlayer, 0); setElementDimension(thePlayer, 0)
    fadeCamera(thePlayer, false, 0.5); setTimer(fadeCamera, 500, 1, thePlayer, true, 0.5)
    setCameraTarget(thePlayer, thePlayer); takeAllWeapons(thePlayer)
    setElementData(thePlayer, "prisontime", calculatedTime)

    local dbUpdateSuccess, dbErrMsg = exports.datenbank:executeDatabase("UPDATE wanteds SET prisontime=? WHERE account_id=?", calculatedTime, accID)
    if not dbUpdateSuccess then
        outputDebugString("[Jail Arrest Fn] DB Update FEHLGESCHLAGEN für AccID " .. accID .. "! Fehler: " .. (dbErrMsg or "N/A"))
        -- Hier könnte man überlegen, den Spieler nicht ins Jail zu stecken oder eine Fallback-Logik zu haben.
        -- Fürs Erste wird der Spieler clientseitig informiert, aber der DB-Status ist inkonsistent.
        outputChatBox("Fehler beim Speichern der Gefängniszeit! Bitte Admin kontaktieren.", thePlayer, 255,0,0)
        return false, "Database update failed"
    end

    if not jailedPlayers[thePlayer] then
         jailedPlayers[thePlayer] = true
         lastPrisonTimeDBSave[thePlayer] = getTickCount()
         startGlobalJailTimer()
    end
    outputChatBox("Du wurdest ins Gefängnis gesteckt für " .. calculatedTime .. " Sekunden!", thePlayer, 255, 0, 0)
    return true, "Success"
end
_G.arrestPlayer = arrestPlayer -- Global machen für police_server.lua

function freePlayerFromJail(player)
    if not isElement(player) then return end
    local accID = getElementData(player, "account_id")
    if not accID then outputDebugString("[Jail] freePlayerFromJail: Kein accID für "..getPlayerName(player)); return end

    if jailedPlayers[player] then
        jailedPlayers[player] = nil
        lastPrisonTimeDBSave[player] = nil
    end
    setElementData(player, "prisontime", 0)

    local dbSuccessTime, errMsgTime = exports.datenbank:executeDatabase("UPDATE wanteds SET prisontime=0 WHERE account_id=?", accID)
    if not dbSuccessTime then
        outputDebugString("[Jail] DB FEHLER beim Zurücksetzen der PrisonTime für AccID "..accID..": "..(errMsgTime or "Unbekannt"), 2)
    end

    if getElementData(player, "wanted") > 0 then
         if type(setPlayerWantedLevel) == "function" then
              setPlayerWantedLevel(player, 0)
         else
              outputDebugString("[Jail] FEHLER: setPlayerWantedLevel nicht gefunden für "..getPlayerName(player).."!", 2)
              setElementData(player, "wanted", 0)
              local dbSuccessWanted, errMsgWanted = exports.datenbank:executeDatabase("UPDATE wanteds SET wanted_level=0 WHERE account_id=?", accID)
              if not dbSuccessWanted then outputDebugString("[Jail] DB FEHLER beim Zurücksetzen der Wanteds für AccID "..accID..": "..(errMsgWanted or "Unbekannt"), 2) end
              triggerClientEvent(player, "updateWantedLevelDisplay", player, 0)
              triggerEvent("onWantedChange", player, 0, 0) -- Annahme: oldWanted war > 0
         end
    end

    spawnPlayer(player, releasePos.x, releasePos.y, releasePos.z, 0, getElementModel(player), 0, 0)
    fadeCamera(player, true, 1.0); setCameraTarget(player, player)
    outputChatBox("Du bist aus dem Gefängnis entlassen!", player, 0, 255, 0)
end
_G.freePlayerFromJail = freePlayerFromJail -- Global machen

-------------------------------------------------------------------
-- D) Jail-Timer-Logik
-------------------------------------------------------------------
function startGlobalJailTimer()
    if not isTimer(jailTimer) and not table.isEmpty(jailedPlayers) then
        outputDebugString("[Jail] Starte globalen Jail-Timer (Intervall: "..JAIL_CHECK_INTERVAL_SECONDS.."s)")
        jailTimer = setTimer(checkAllPrisoners, JAIL_CHECK_INTERVAL_SECONDS * 1000, 0)
    end
end

function checkAllPrisoners()
    local now = getTickCount()
    local playersToRemove = {}
    if table.isEmpty(jailedPlayers) then
        if isTimer(jailTimer) then killTimer(jailTimer); jailTimer = nil; outputDebugString("[Jail] Kein Spieler mehr im Gefängnis. Stoppe Jail-Timer.") end
        return
    end

    for p, _ in pairs(jailedPlayers) do
        if not isElement(p) then table.insert(playersToRemove, p)
        else
            local pt = getElementData(p, "prisontime") or 0
            if pt <= 0 then table.insert(playersToRemove, p)
            else
                local newTime = math.max(0, pt - JAIL_CHECK_INTERVAL_SECONDS)
                setElementData(p, "prisontime", newTime)
                local accID_timer = getElementData(p, "account_id"); local playerName_timer = getPlayerName(p)
                local oldWanted_timer = getElementData(p, "wanted") or 0

                if newTime <= 0 then
                    if not playersToRemove[p] then
                        playersToRemove[p] = true
                        if type(setPlayerWantedLevel) == "function" then setPlayerWantedLevel(p, 0)
                        else
                             outputDebugString("[Jail Timer] FEHLER: setPlayerWantedLevel nicht gefunden!", 2)
                             setElementData(p, "wanted", 0)
                             local _, errWT = exports.datenbank:executeDatabase("UPDATE wanteds SET wanted_level=0 WHERE account_id=?", accID_timer)
                             if errWT then outputDebugString("[Jail Timer] DB Fehler beim Setzen von Wanteds auf 0 für AccID " .. accID_timer .. ": " .. errWT) end
                             triggerClientEvent(p, "updateWantedLevelDisplay", p, 0); triggerEvent("onWantedChange", p, 0, oldWanted_timer)
                        end
                    end
                elseif oldWanted_timer > 0 then
                    local wantedReduction = 1
                    local newWanted_timer = math.max(0, oldWanted_timer - wantedReduction)
                    if newWanted_timer < oldWanted_timer then
                        if type(setPlayerWantedLevel) == "function" then setPlayerWantedLevel(p, newWanted_timer)
                        else
                            outputDebugString("[Jail Timer] FEHLER: setPlayerWantedLevel nicht gefunden!", 2)
                            setElementData(p, "wanted", newWanted_timer)
                            local _, errWTR = exports.datenbank:executeDatabase("UPDATE wanteds SET wanted_level=? WHERE account_id=?", newWanted_timer, accID_timer)
                            if errWTR then outputDebugString("[Jail Timer] DB Fehler beim Reduzieren von Wanteds für AccID " .. accID_timer .. ": " .. errWTR) end
                            triggerClientEvent(p, "updateWantedLevelDisplay", p, newWanted_timer); triggerEvent("onWantedChange", p, newWanted_timer, oldWanted_timer)
                        end
                    end
                end

                local lastSave = lastPrisonTimeDBSave[p] or 0
                if accID_timer and (now - lastSave >= PRISON_TIME_SAVE_INTERVAL_MS) and newTime > 0 then
                    local saveSuccess, saveErrMsg = exports.datenbank:executeDatabase("UPDATE wanteds SET prisontime=? WHERE account_id=?", newTime, accID_timer)
                    if saveSuccess then lastPrisonTimeDBSave[p] = now
                    else outputDebugString(string.format("[Jail DB Save] FEHLER beim Speichern der PrisonTime für %s (AccID %d): %s", playerName_timer, accID_timer, (saveErrMsg or "Unbekannt")), 2) end
                end
            end
        end
    end
    for _, playerToRemove in ipairs(playersToRemove) do freePlayerFromJail(playerToRemove) end
    if table.isEmpty(jailedPlayers) and isTimer(jailTimer) then killTimer(jailTimer); jailTimer = nil; outputDebugString("[Jail] Kein Spieler mehr im Gefängnis nach Prüfung. Stoppe Jail-Timer.") end
end

-------------------------------------------------------------------
-- E) Jailbreak-Funktion
-------------------------------------------------------------------
function breakOutAllPrisoners(hacker)
    local freedCount = 0
    local currentJailed = {}
    for p, _ in pairs(jailedPlayers) do table.insert(currentJailed, p) end

    for _, plr in ipairs(currentJailed) do
        if isElement(plr) then
             local ptime = getElementData(plr, "prisontime") or 0
             if ptime > 0 then
                 setElementData(plr, "prisontime", 0)
                 local accID_breakout = getElementData(plr, "account_id")
                 if accID_breakout then
                      local _, errJT = exports.datenbank:executeDatabase("UPDATE wanteds SET prisontime=0 WHERE account_id=?", accID_breakout)
                      if errJT then outputDebugString("[Jailbreak] DB Fehler beim Setzen von prisontime=0 für AccID " .. accID_breakout .. ": " .. errJT) end
                 end
                 if jailedPlayers[plr] then
                     jailedPlayers[plr] = nil
                     lastPrisonTimeDBSave[plr] = nil
                 end
                 if type(ensureWantedTimerIsRunning) == "function" then ensureWantedTimerIsRunning()
                 else outputDebugString("[Jailbreak] WARNUNG: Funktion ensureWantedTimerIsRunning nicht gefunden!") end
                 outputChatBox("The jail security system has been hacked! Doors open for 5 min, wanteds remain!", plr, 255, 200, 0)
                 freedCount = freedCount + 1
             end
        end
    end
    if isElement(hacker) then outputChatBox("You hacked the jail system. Gates open for 5 min!", hacker, 0, 255, 0) end
    if freedCount > 0 then
        for _, p_notify in ipairs(getElementsByType("player")) do
             if isElement(p_notify) then
                 local frac_notify = getElementData(p_notify, "group") or "Civil"
                 if frac_notify == "Police" or frac_notify == "Swat" then outputChatBox("Jail system hacked! Prison break in progress!", p_notify, 255, 0, 0) end
             end
        end
    end
end

-- Event Handler und Hilfsfunktionen für Jailbreak (Marker, Tore etc.) bleiben unverändert,
-- da sie keine direkten Datenbankaufrufe enthalten, die angepasst werden müssten.
-- Ihre Logik ist primär auf Client-Events und Objektmanipulationen ausgerichtet.
-- ... (Rest des Skripts: G, H, I, J, K, L) ...
function handleJailOutsideMarkerHit(p, dim) if not dim or getElementType(p) ~= "player" or isPedInVehicle(p) then return end; fadeCamera(p, false, 1.0, 0, 0, 0); setTimer(function() if isElement(p) then local tX,tY,tZ=-1507.47241,775.29388,17.72031; setElementInterior(p, 0); setElementDimension(p, 0); setTimer(function() if isElement(p) then setElementPosition(p, tX, tY, tZ); fadeCamera(p, true, 1.0) end end, 50, 1) end end, 1000, 1) end
function handleInsideMarkerHit(p,dim) if not dim or getElementType(p)~="player" or isPedInVehicle(p) then return end; fadeCamera(p,false,1); setTimer(function() if isElement(p) then setElementInterior(p, 0); setElementDimension(p, 0); setElementPosition(p, insideToOutsideTargetPos.x, insideToOutsideTargetPos.y, insideToOutsideTargetPos.z); fadeCamera(p,true,1) end end,1000,1) end
function handleFreezerMarkerHit(p, dim) if not dim or getElementType(p)~="player" or isPedInVehicle(p) then return end; if isFreezerDoorOnCooldown or countdownRunningFreezer then outputChatBox("FreezerDoor is on cooldown or running!", p,255,0,0); return end; triggerClientEvent(p, "jail_showDoorBreakUI", p) end
function handleGatesMarkerHit(p,dim) if not dim or getElementType(p)~="player" or isPedInVehicle(p) then return end; if isGatesOnCooldown then outputChatBox("Marker #2 is on cooldown!", p,255,0,0); return end; triggerClientEvent(p,"jail_showHackSystemUI",p) end
function handleExitLobbyMarkerHit(p,dim) if not dim or getElementType(p)~="player" or isPedInVehicle(p) then return end; triggerClientEvent(p,"jail_showExitLobby",resourceRoot); fadeCamera(p,false,1,0,0,0); setTimer(function() if isElement(p) then setElementPosition(p, exitLobbyTargetPos.x,exitLobbyTargetPos.y,exitLobbyTargetPos.z); fadeCamera(p,true,1) end end,1000,1) end

function createFreezerMarker() if isElement(markerFreezer) then destroyElement(markerFreezer) end; markerFreezer = createMarker(markerFreezerPos.x, markerFreezerPos.y, markerFreezerPos.z - 1, "cylinder", 2.5, 255, 0, 0, 150); if isElement(markerFreezer) then addEventHandler("onMarkerHit", markerFreezer, handleFreezerMarkerHit); isFreezerDoorOnCooldown=false; countdownRunningFreezer=false else outputDebugString("[Jail] FEHLER: Konnte FreezerDoor Marker nicht erstellen!", 2) end end
function openFreezerDoor() if not isElement(freezerDoorObject) then outputDebugString("[Jail] FEHLER: FreezerDoor Object ungültig beim Öffnen!", 2); isFreezerDoorOnCooldown=false; return end; moveObject(freezerDoorObject,2000, freezerDoorOpenPos.x, freezerDoorOpenPos.y, freezerDoorOpenPos.z, freezerDoorOpenPos.rx - freezerDoorClosedPos.rx, freezerDoorOpenPos.ry - freezerDoorClosedPos.ry, freezerDoorOpenPos.rz - freezerDoorClosedPos.rz); if isElement(markerFreezer) then destroyElement(markerFreezer); markerFreezer=nil; end; setTimer(closeFreezerDoor, doorOpenDuration*1000, 1); setTimer(createFreezerMarker, markerDespawnTime, 1) end
function closeFreezerDoor() if not isElement(freezerDoorObject) then outputDebugString("[Jail] FreezerDoor Object ungültig beim Schließen!", 1); isFreezerDoorOnCooldown=false; return end; moveObject(freezerDoorObject,2000, freezerDoorClosedPos.x, freezerDoorClosedPos.y, freezerDoorClosedPos.z, freezerDoorClosedPos.rx - freezerDoorOpenPos.rx, freezerDoorClosedPos.ry - freezerDoorOpenPos.ry, freezerDoorClosedPos.rz - freezerDoorOpenPos.rz); setTimer(function() isFreezerDoorOnCooldown=false; end, 2000, 1) end
function createGatesMarker() if isElement(markerGates) then destroyElement(markerGates) end; markerGates = createMarker(markerGatesPos.x, markerGatesPos.y, markerGatesPos.z -1, "cylinder", 2.5, 255,0,0,150); if isElement(markerGates) then addEventHandler("onMarkerHit", markerGates, handleGatesMarkerHit); isGatesOnCooldown=false else outputDebugString("[Jail] FEHLER: Konnte PrisonGates Marker nicht erstellen!", 2) end end
function moveChinagatesOpen() if isElement(chinagate1) then moveObject(chinagate1, 2000, gate1OpenPos.x, gate1OpenPos.y, gate1OpenPos.z, gate1OpenPos.rx - gate1ClosedPos.rx, gate1OpenPos.ry - gate1ClosedPos.ry, gate1OpenPos.rz - gate1ClosedPos.rz ) end; if isElement(chinagate2) then moveObject(chinagate2, 2000, gate2OpenPos.x, gate2OpenPos.y, gate2OpenPos.z, gate2OpenPos.rx - gate2ClosedPos.rx, gate2OpenPos.ry - gate2ClosedPos.ry, gate2OpenPos.rz - gate2ClosedPos.rz ) end end
function moveChinagatesClose() if isElement(chinagate1) then moveObject(chinagate1, 2000, gate1ClosedPos.x, gate1ClosedPos.y, gate1ClosedPos.z, gate1ClosedPos.rx - gate1OpenPos.rx, gate1ClosedPos.ry - gate1OpenPos.ry, gate1ClosedPos.rz - gate1OpenPos.rz ) end; if isElement(chinagate2) then moveObject(chinagate2, 2000, gate2ClosedPos.x, gate2ClosedPos.y, gate2ClosedPos.z, gate2ClosedPos.rx - gate2OpenPos.rx, gate2ClosedPos.ry - gate2OpenPos.ry, gate2ClosedPos.rz - gate2OpenPos.rz ) end; end
function openChinagates() moveChinagatesOpen(); setTimer(moveChinagatesClose, gatesOpenDuration*1000, 1) end
function createExitLobbyMarker() if isElement(markerExitLobby) then destroyElement(markerExitLobby) end; markerExitLobby = createMarker(markerExitLobbyPos.x, markerExitLobbyPos.y, markerExitLobbyPos.z -1, "cylinder",1.2,0,0,255,150); if isElement(markerExitLobby) then addEventHandler("onMarkerHit", markerExitLobby, handleExitLobbyMarkerHit) else outputDebugString("[Jail] FEHLER: Konnte ExitLobby Marker nicht erstellen!", 2) end end
function removeExitLobbyMarker() if isElement(markerExitLobby) then destroyElement(markerExitLobby); markerExitLobby=nil; end end

addEventHandler("onResourceStart", resourceRoot, function()
    local db_check = exports.datenbank:getConnection(); if not db_check then outputDebugString("[Jail] FATAL ERROR onResourceStart: No Database Connection!", 1); return end
    if not isElement(freezerDoorObject) then freezerDoorObject = createObject(freezerDoorModel, freezerDoorClosedPos.x, freezerDoorClosedPos.y, freezerDoorClosedPos.z, freezerDoorClosedPos.rx, freezerDoorClosedPos.ry, freezerDoorClosedPos.rz); if isElement(freezerDoorObject) then setObjectBreakable(freezerDoorObject, false) else outputDebugString("[Jail] FEHLER: Konnte freezerDoorObject nicht erstellen!", 2) end end
    if not isElement(chinagate1) then chinagate1 = createObject(chinagateModel, gate1ClosedPos.x, gate1ClosedPos.y, gate1ClosedPos.z, gate1ClosedPos.rx, gate1ClosedPos.ry, gate1ClosedPos.rz); if isElement(chinagate1) then setObjectBreakable(chinagate1, false) end end
    if not isElement(chinagate2) then chinagate2 = createObject(chinagateModel, gate2ClosedPos.x, gate2ClosedPos.y, gate2ClosedPos.z, gate2ClosedPos.rx, gate2ClosedPos.ry, gate2ClosedPos.rz); if isElement(chinagate2) then setObjectBreakable(chinagate2, false) end end
    createFreezerMarker(); createGatesMarker()
    local mapGates = getElementsByType("object", resourceRoot); prisonGateObjects = {}; prisonGateClosedPositions = {}
    for _, obj in ipairs(mapGates) do if getElementModel(obj) == 14883 then table.insert(prisonGateObjects, obj); setObjectBreakable(obj, false); local x,y,z = getElementPosition(obj); prisonGateClosedPositions[obj] = { x=x, y=y, z=z } end end
    if #prisonGateObjects == 0 then outputDebugString("[Jail] WARNUNG: Keine Tore mit Modell 14883 in der Map gefunden!", 1) end
    if not isElement(markerOutside) then markerOutside = createMarker(markerOutsidePos.x, markerOutsidePos.y, markerOutsidePos.z - 1, "cylinder", 1.2, 0, 0, 255, 150); if isElement(markerOutside) then addEventHandler("onMarkerHit", markerOutside, handleJailOutsideMarkerHit) else outputDebugString("[Jail] FEHLER: Außen-Marker konnte nicht erstellt werden!", 2) end end
    if not isElement(markerInside) then markerInside = createMarker(markerInsidePos.x, markerInsidePos.y, markerInsidePos.z - 1, "cylinder", 1.2, 0, 0, 255, 150); if isElement(markerInside) then addEventHandler("onMarkerHit", markerInside, handleInsideMarkerHit) else outputDebugString("[Jail] FEHLER: Innen-Marker konnte nicht erstellt werden!", 2) end end
    setTimer(function()
        jailedPlayers = {}; lastPrisonTimeDBSave = {};
        local queryResult, errMsg = exports.datenbank:queryDatabase("SELECT account_id, prisontime FROM wanteds WHERE prisontime > 0")
        if not queryResult then
            outputDebugString("[Jail Start] Fehler beim Abfragen der Gefangenen aus der DB: " .. (errMsg or "Unbekannt"), 2)
            return
        end
        if queryResult and type(queryResult) == "table" then
             for _, row in ipairs(queryResult) do
                 local accID_startup = tonumber(row.account_id); local ptime_startup = tonumber(row.prisontime) or 0; local player_startup = getPlayerFromAccountID(accID_startup)
                 if isElement(player_startup) and ptime_startup > 0 then if not jailedPlayers[player_startup] then jailedPlayers[player_startup] = true; lastPrisonTimeDBSave[player_startup] = getTickCount(); end end
             end
        end
        startGlobalJailTimer()
    end, 5500, 1)
    outputDebugString("[Jail] Jail System (Server V1.1 - Robuste DB Fehlerbehandlung) geladen.")
end)

addEvent("jail_onDoorBreakYes",true); addEventHandler("jail_onDoorBreakYes",root,function() local player = source; if not isElement(player) or isFreezerDoorOnCooldown or countdownRunningFreezer then return end; if type(setPlayerWantedLevel) == "function" then local oW=getElementData(player,"wanted") or 0; local nW=math.min(100,oW+35); setPlayerWantedLevel(player, nW); outputChatBox("Camera triggered! Wanted level: "..nW, player,255,100,0) else outputDebugString("[Jail] FEHLER: setPlayerWantedLevel nicht gefunden!", 2); local oWF=getElementData(player,"wanted")or 0;local nWF=math.min(100,oWF+35);setElementData(player,"wanted",nWF);triggerClientEvent(player,"updateWantedLevelDisplay",player,nWF);triggerEvent("onWantedChange",player,nWF,oWF);outputChatBox("Camera triggered! Wanted level: "..nWF,player,255,100,0)end;isFreezerDoorOnCooldown=true;countdownRunningFreezer=true;countdownValueFreezer=countdownTimeFreezer;if isTimer(tCountdownFreezer)then killTimer(tCountdownFreezer)end;tCountdownFreezer=setTimer(function()countdownValueFreezer=countdownValueFreezer-1;triggerClientEvent(root,"jail_updateCountdown1",resourceRoot,countdownRunningFreezer,countdownValueFreezer);if countdownValueFreezer<=0 then countdownRunningFreezer=false;if isTimer(tCountdownFreezer)then killTimer(tCountdownFreezer)end;tCountdownFreezer=nil;openFreezerDoor()end end,1000,countdownTimeFreezer);triggerClientEvent(root,"jail_updateCountdown1",resourceRoot,countdownRunningFreezer,countdownValueFreezer)end)
addEvent("jail_onHackSystemSuccess",true); addEventHandler("jail_onHackSystemSuccess",root,function() local player=source;if not isElement(player)or isGatesOnCooldown then return end;isGatesOnCooldown=true;breakOutAllPrisoners(player);if isElement(markerGates)then destroyElement(markerGates);markerGates=nil;end;for _,gobj in ipairs(prisonGateObjects)do if isElement(gobj)then local cpos=prisonGateClosedPositions[gobj];if cpos then moveObject(gobj,2000,cpos.x,cpos.y+1.9,cpos.z)end end end;setTimer(function()for _,gobj in ipairs(prisonGateObjects)do if isElement(gobj)then local cpos=prisonGateClosedPositions[gobj];if cpos then moveObject(gobj,2000,cpos.x,cpos.y,cpos.z)end end end end,gatesOpenDuration*1000,1);setTimer(createGatesMarker,markerDespawnTime,1);createExitLobbyMarker();setTimer(removeExitLobbyMarker,gatesOpenDuration*1000,1);openChinagates()end)

addCommandHandler("openchinagates", function(plr) moveChinagatesOpen(); outputChatBox("China gates -> open!", plr,0,255,0) end)
addCommandHandler("closechinagates", function(plr) moveChinagatesClose(); outputChatBox("China gates -> closed!", plr,255,0,0) end)

addEventHandler("onResourceStop", resourceRoot, function() if isTimer(tCountdownFreezer)then killTimer(tCountdownFreezer)end;if isTimer(jailTimer)then killTimer(jailTimer);jailTimer=nil end; if not table.isEmpty(jailedPlayers) then outputDebugString("[Jail Stop] Speichere verbleibende Gefängniszeiten..."); local saveCount=0;for player,_ in pairs(jailedPlayers)do if isElement(player)then local accID_stop=getElementData(player,"account_id");local ptime_stop=getElementData(player,"prisontime")or 0;if accID_stop and ptime_stop>0 then local success_stop,err_stop=exports.datenbank:executeDatabase("UPDATE wanteds SET prisontime=? WHERE account_id=?",ptime_stop,accID_stop);if success_stop then saveCount=saveCount+1 else outputDebugString("[Jail Stop] DB Fehler beim Speichern für AccID "..accID_stop..": "..(err_stop or "Unbekannt")) end end end end;outputDebugString("[Jail Stop] "..saveCount.." Gefängniszeiten gespeichert.")end end)
addEventHandler("onPlayerQuit", root, function() if jailedPlayers[source]then local accID_quit=getElementData(source,"account_id");local ptime_quit=getElementData(source,"prisontime")or 0;if accID_quit and ptime_quit>0 then local success_quit,err_quit=exports.datenbank:executeDatabase("UPDATE wanteds SET prisontime=? WHERE account_id=?",ptime_quit,accID_quit);if not success_quit then outputDebugString("[Jail Save] FEHLER beim Speichern der PrisonTime für AccID "..accID_quit..": "..(err_quit or "Unbekannt"),2)end end;jailedPlayers[source]=nil;lastPrisonTimeDBSave[source]=nil;end end)

addEvent("requestAutomaticJailSpawn", true); addEventHandler("requestAutomaticJailSpawn", root, function() local player=client;if not isElement(player)then return end;local pAccID=getElementData(player,"account_id");if not pAccID then outputDebugString("[Jail] Fehler: AccID für autom. Jail-Spawn von "..getPlayerName(player));if isElement(player)then spawnPlayer(player,0,0,5)end;return end;local success_auto,errMsg_auto=arrestPlayer(pAccID);if not success_auto then outputDebugString("[Jail] Fehler beim autom. Jail-Spawn für AccID "..pAccID..": "..(errMsg_auto or ""));local pElemFallback=getPlayerFromAccountID(pAccID);if isElement(pElemFallback)then outputChatBox("Fehler beim Transfer ins Gefängnis.",pElemFallback,255,100,0);spawnPlayer(pElemFallback,0,0,5);fadeCamera(pElemFallback,true);setCameraTarget(pElemFallback,pElemFallback);toggleAllControls(pElemFallback,true)end end end)