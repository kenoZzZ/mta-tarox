-- tarox/jobs/lkw/lkw_server.lua
-- MODIFIZIERT: Skill-System implementiert (Level, Belohnung, Fortschritt)

-- =================================================================
-- LKW FAHRER JOB - KONFIGURATION
-- =================================================================
local LKW_JOB_KEY = "lkwfahrer" -- Wichtig: Muss mit job_name in player_job_skills übereinstimmen
local LKW_JOB_DISPLAY_NAME = "LKW Fahrer"

-- NEU: Skill-Konfiguration für LKW-Fahrer
-- Global gemacht, damit muellabfuhr_server.lua darauf zugreifen kann
_G.lkwFahrerData = {
    skillName = "lkwfahrer", -- Name des Skills, wie er in der DB gespeichert wird
    rewardPerLevel = {
        2500, -- Level 0 (Grundbelohnung)
        2800, -- Level 1
        3200, -- Level 2
        3700, -- Level 3
        4300, -- Level 4
        5000  -- Level 5 (Maximallevel)
    },
    jobsForLevelUp = {
        [0] = 5,   -- Für Level 1 (von 0 auf 1) - 5 Touren gesamt
        [1] = 15,  -- Für Level 2 (von 1 auf 2) - 15 Touren gesamt
        [2] = 30,  -- Für Level 3 (von 2 auf 3) - 30 Touren gesamt
        [3] = 50,  -- Für Level 4 (von 3 auf 4) - 50 Touren gesamt
        [4] = 75   -- Für Level 5 (von 4 auf 5) - 75 Touren gesamt (Maximallevel)
    },
    maxSkillLevel = 5,
}

local LKW_FAHRZEUG_ID = 515
local LKW_ANHAENGER_MODELL = 450
local LKW_FAHRZEUG_SPAWN_POS = {x = -486.77832, y = -505.90808, z = 26.62250, rot = 180}
local LKW_ANHAENGER_SPAWN_POS = {x = -485.95612, y = -484.10510, z = 26.61777, rot = 0}
local LKW_ANHAENGER_ABGABE_MARKER_POS = {x = -491.50220, y = -552.92841, z = 26.62097}
local LKW_ANHAENGER_ABGABE_MARKER_SIZE = 7
local LKW_DISPATCHER_POS = {x = -476.60367, y = -536.10791, z = 25.52961, rot = 0}
local JOB_VEHICLE_LEAVE_TIMEOUT = 60 * 1000
local LKW_JOB_DELIVERY_DURATION = 10 * 60 * 1000
local activeLKWJobs = {}
local ID_PERSONALAUSWEIS_LKW = 17
local REQUIRED_LICENSE_TYPE_LKW = "car" -- Definiert in drive_server.lua

-- Hilfsfunktion für benötigte Jobs zum nächsten Level (LKW)
-- Global gemacht
function _G.getJobsNeededForNextLevelLKW(currentSkillLevel, currentJobsCompleted)
    local config = _G.lkwFahrerData -- Zugriff auf globale Konfig
    if currentSkillLevel >= config.maxSkillLevel then
        return "Max"
    end
    local neededForNextOverall = config.jobsForLevelUp[currentSkillLevel]
    if not neededForNextOverall then
        return "N/A"
    end
    local remaining = neededForNextOverall - currentJobsCompleted
    return math.max(0, remaining)
end

local function cleanupPlayerLKWJob(player, reason, suppressVehicleDestroy)
    if not isElement(player) or not activeLKWJobs[player] then return end
    local jobData = activeLKWJobs[player]
    if isTimer(jobData.leaveTimer) then killTimer(jobData.leaveTimer); jobData.leaveTimer = nil; end
    if isTimer(jobData.jobTimeLimitTimer) then killTimer(jobData.jobTimeLimitTimer); jobData.jobTimeLimitTimer = nil; end
    if isElement(jobData.deliveryMarker) then destroyElement(jobData.deliveryMarker); jobData.deliveryMarker = nil; end
    if not suppressVehicleDestroy then
        if isElement(jobData.vehicle) then destroyElement(jobData.vehicle); jobData.vehicle = nil; end
        if isElement(jobData.trailer) then destroyElement(jobData.trailer); jobData.trailer = nil; end
    end
    activeLKWJobs[player] = nil
    removeElementData(player, "currentJob")
    triggerClientEvent(player, "jobs:lkwfahrer:jobCancelled", player) --
    triggerClientEvent(player, "stopJobTimerDisplay", player) --
    if reason then
        outputChatBox("LKW-Fahrer Job abgebrochen: " .. reason, player, 255, 100, 0)
    end
end

addEvent("jobs:lkwfahrer:interactionWithStartPed", true)
addEventHandler("jobs:lkwfahrer:interactionWithStartPed", root, function()
    local player = source
    if not isElement(player) then return end
    if getElementData(player, "currentJob") then
        outputChatBox("Du hast bereits einen aktiven Job.", player, 255, 100, 0)
        return
    end
    local hasPerso, errMsgPerso = exports.tarox:hasPlayerItem(player, ID_PERSONALAUSWEIS_LKW, 1) --
    if errMsgPerso then
        outputChatBox("Fehler beim Überprüfen der Voraussetzungen (Perso).", player, 255,0,0)
        return
    end
    if not hasPerso then
        outputChatBox("Du benötigst einen Personalausweis für diesen Job.", player, 255, 100, 0)
        return
    end
    local hasLicense = false
    if exports.tarox and type(exports.tarox.hasPlayerLicense) == "function" then --
        hasLicense = exports.tarox:hasPlayerLicense(player, REQUIRED_LICENSE_TYPE_LKW) --
    else
        outputChatBox("Fehler: Führerscheinsystem nicht erreichbar.", player, 255,0,0)
        return
    end
    if not hasLicense then
        outputChatBox("Du benötigst einen PKW-Führerschein (Klasse B), um diese Tour zu starten.", player, 255, 100, 0)
        return
    end
    setTimer(triggerClientEvent, 500, 1, player, "jobs:lkwfahrer:confirmTourStart", player, LKW_JOB_DISPLAY_NAME) --
end)

addEvent("jobs:lkwfahrer:startTourConfirmed", true)
addEventHandler("jobs:lkwfahrer:startTourConfirmed", root, function()
    local player = client
    if not isElement(player) then return end
    if getElementData(player, "currentJob") then
        outputChatBox("Du hast bereits einen aktiven Job.", player, 255, 100, 0)
        return
    end

    local accID = getElementData(player, "account_id")
    if not accID then
        outputChatBox("Fehler: Account-Daten nicht geladen.", player, 255, 0, 0)
        return
    end

    local playerSkillLevel = 0
    local jobsDoneTotal = 0
    local skillQuery = "SELECT skill_level, jobs_completed_total FROM player_job_skills WHERE account_id = ? AND job_name = ?" --
    local skillResult, skillErrMsg = exports.datenbank:queryDatabase(skillQuery, accID, _G.lkwFahrerData.skillName) --

    if skillResult == false then
        outputChatBox("Fehler beim Laden deiner Job-Skills.", player, 255,0,0)
        outputDebugString("[LKW SERVER] DB Fehler (Skill laden) für AccID " .. accID .. ": " .. (skillErrMsg or "Unbekannt"))
        return
    end

    if skillResult and #skillResult > 0 and skillResult[1] then
        playerSkillLevel = tonumber(skillResult[1].skill_level) or 0
        jobsDoneTotal = tonumber(skillResult[1].jobs_completed_total) or 0
    else
        local insertSuccess, insertErr = exports.datenbank:executeDatabase("INSERT IGNORE INTO player_job_skills (account_id, job_name, skill_level, experience, jobs_completed_total) VALUES (?, ?, 0, 0, 0)", accID, _G.lkwFahrerData.skillName) --
        if not insertSuccess then
            outputChatBox("Fehler beim Initialisieren deiner Job-Skills.", player, 255,0,0)
            outputDebugString("[LKW SERVER] DB Fehler (Skill INSERT) für AccID " .. accID .. ": " .. (insertErr or "Unbekannt"))
            return
        end
    end

    local newSkillLevelBeforeStart = playerSkillLevel
    if playerSkillLevel < _G.lkwFahrerData.maxSkillLevel then
        local neededForNextLevelUp = _G.lkwFahrerData.jobsForLevelUp[playerSkillLevel]
        if neededForNextLevelUp and jobsDoneTotal >= neededForNextLevelUp then
            newSkillLevelBeforeStart = playerSkillLevel + 1
            if newSkillLevelBeforeStart > _G.lkwFahrerData.maxSkillLevel then newSkillLevelBeforeStart = _G.lkwFahrerData.maxSkillLevel end
            local updateSuccessPre, updateMsgPre = exports.datenbank:executeDatabase("UPDATE player_job_skills SET skill_level = ? WHERE account_id = ? AND job_name = ?", newSkillLevelBeforeStart, accID, _G.lkwFahrerData.skillName) --
            if updateSuccessPre then
                outputChatBox("Herzlichen Glückwunsch! Du hast LKW-Fahrer Level " .. (newSkillLevelBeforeStart + 1) .. " erreicht!", player, 255, 215, 0)
                playerSkillLevel = newSkillLevelBeforeStart
            else
                outputDebugString("[LKW SERVER] FEHLER Skill-Update (vor Job): " .. (updateMsgPre or "Unbekannt"))
            end
        end
    end
    local jobLevelForCurrentTour = playerSkillLevel

    local lkw = createVehicle(LKW_FAHRZEUG_ID, LKW_FAHRZEUG_SPAWN_POS.x, LKW_FAHRZEUG_SPAWN_POS.y, LKW_FAHRZEUG_SPAWN_POS.z, 0, 0, LKW_FAHRZEUG_SPAWN_POS.rot)
    if not isElement(lkw) then outputChatBox("Fehler: LKW konnte nicht erstellt werden.", player, 255, 0, 0); return end
    setElementDimension(lkw, getElementDimension(player)); setElementInterior(lkw, getElementInterior(player))
    setElementData(lkw, "jobVehicleForPlayer", player, false); setElementData(lkw, "isLKWJobVehicle", true, false)

    local anhaenger = createVehicle(LKW_ANHAENGER_MODELL, LKW_ANHAENGER_SPAWN_POS.x, LKW_ANHAENGER_SPAWN_POS.y, LKW_ANHAENGER_SPAWN_POS.z, 0, 0, LKW_ANHAENGER_SPAWN_POS.rot)
    if not isElement(anhaenger) then outputChatBox("Fehler: Anhänger konnte nicht erstellt werden.", player, 255, 0, 0); if isElement(lkw) then destroyElement(lkw) end; return end
    setElementDimension(anhaenger, getElementDimension(player)); setElementInterior(anhaenger, getElementInterior(player))
    setElementData(anhaenger, "jobTrailerForPlayer", player, false); setElementData(anhaenger, "isLKWJobTrailer", true, false)

    local warped = warpPedIntoVehicle(player, lkw)
    if not warped then outputChatBox("Fehler: Konnte dich nicht in den LKW setzen.", player, 255,0,0); if isElement(lkw) then destroyElement(lkw) end; if isElement(anhaenger) then destroyElement(anhaenger) end; return end
    setVehicleEngineState(lkw, true)

    setElementData(player, "currentJob", LKW_JOB_KEY, false)
    activeLKWJobs[player] = {
        vehicle = lkw, trailer = anhaenger, deliveryMarker = nil, leaveTimer = nil,
        jobTimeLimitTimer = setTimer(cleanupPlayerLKWJob, LKW_JOB_DELIVERY_DURATION, 1, player, "Zeitlimit überschritten", false),
        levelForReward = jobLevelForCurrentTour
    }
    triggerClientEvent(player, "startJobTimerDisplay", player, LKW_JOB_DELIVERY_DURATION) --
    outputChatBox("LKW-Tour (Level " .. (jobLevelForCurrentTour + 1) .. ") gestartet! Nimm den Anhänger auf und bringe ihn zum Zielort (Blauer Marker).", player, 0, 200, 50)

    local deliveryMarker = createMarker(LKW_ANHAENGER_ABGABE_MARKER_POS.x, LKW_ANHAENGER_ABGABE_MARKER_POS.y, LKW_ANHAENGER_ABGABE_MARKER_POS.z - 1, "checkpoint", LKW_ANHAENGER_ABGABE_MARKER_SIZE, 0, 0, 255, 180)
    if isElement(deliveryMarker) then
        setElementData(deliveryMarker, "lkwDeliveryMarkerFor", player, false)
        setElementDimension(deliveryMarker, getElementDimension(player)); setElementInterior(deliveryMarker, getElementInterior(player))
        activeLKWJobs[player].deliveryMarker = deliveryMarker
        triggerClientEvent(player, "jobs:lkwfahrer:updateDeliveryMarker", player, LKW_ANHAENGER_ABGABE_MARKER_POS, LKW_FAHRZEUG_ID, LKW_ANHAENGER_MODELL) --
    else
        cleanupPlayerLKWJob(player, "Fehler beim Erstellen des Abgabemarkers.")
    end
end)


addEventHandler("onMarkerHit", root, function(hitElement, matchingDimension)
    local player = nil
    local jobData = nil

    if getElementType(hitElement) == "player" then
        player = hitElement
    elseif getElementType(hitElement) == "vehicle" then
        player = getVehicleController(hitElement)
    end

    if not isElement(player) or not activeLKWJobs[player] then return end
    jobData = activeLKWJobs[player]

    if source ~= jobData.deliveryMarker or not matchingDimension then return end

    local currentVehicle = getPedOccupiedVehicle(player)
    if not isElement(currentVehicle) or currentVehicle ~= jobData.vehicle then
        outputChatBox("Du musst im richtigen LKW sitzen, um die Lieferung abzuschließen.", player, 255, 100, 0)
        return
    end

    local towedVehicle = getVehicleTowedByVehicle(currentVehicle)
    if not isElement(towedVehicle) or towedVehicle ~= jobData.trailer then
        outputChatBox("Du musst den korrekten Anhänger angekoppelt haben und zum Zielort bringen.", player, 255, 100, 0)
        return
    end

    local lkwIsWithinMarker = false
    if type(isElementWithinMarker) == "function" then
        lkwIsWithinMarker = isElementWithinMarker(currentVehicle, source)
    else
        local mx, my, mz = getElementPosition(source)
        local markerSizeX, _, _ = getMarkerSize(source)
        local vx, vy, _ = getElementPosition(currentVehicle)
        if getDistanceBetweenPoints2D(vx,vy, mx,my) <= markerSizeX / 2 then
            lkwIsWithinMarker = true
        end
    end

    if not lkwIsWithinMarker then
        outputChatBox("Fahre mit dem LKW und angekoppeltem Anhänger vollständig in den Marker.", player, 255,165,0)
        return
    end

    local jobLevelForReward = jobData.levelForReward or 0
    local reward = _G.lkwFahrerData.rewardPerLevel[jobLevelForReward + 1] or _G.lkwFahrerData.rewardPerLevel[1]
    if not reward then
        outputDebugString("[LKW SERVER] FEHLER: Keine Belohnung für Level " .. jobLevelForReward .. " definiert!")
        reward = 2000
    end

    givePlayerMoney(player, reward)
    outputChatBox("Anhänger erfolgreich abgeliefert! Du hast $" .. reward .. " erhalten.", player, 0, 255, 0)

    local accID = getElementData(player, "account_id")
    if accID then
        local currentSkillInfoQuery = "SELECT skill_level, jobs_completed_total FROM player_job_skills WHERE account_id = ? AND job_name = ?" --
        local currentSkillInfo, skillInfoErr = exports.datenbank:queryDatabase(currentSkillInfoQuery, accID, _G.lkwFahrerData.skillName) --
        local currentSkill = 0
        local currentJobsCompleted = 0

        if skillInfoErr then
            outputDebugString("[LKW SERVER] DB Fehler (Skill abrufen) für AccID " .. accID .. ": " .. skillInfoErr)
        elseif currentSkillInfo and #currentSkillInfo > 0 then
            currentSkill = tonumber(currentSkillInfo[1].skill_level) or 0
            currentJobsCompleted = tonumber(currentSkillInfo[1].jobs_completed_total) or 0
        end

        currentJobsCompleted = currentJobsCompleted + 1
        local newSkillAfterJob = currentSkill

        if currentSkill < _G.lkwFahrerData.maxSkillLevel then
            local neededForNextLvlUp = _G.lkwFahrerData.jobsForLevelUp[currentSkill]
            if neededForNextLvlUp and currentJobsCompleted >= neededForNextLvlUp then
                newSkillAfterJob = currentSkill + 1
                if newSkillAfterJob > _G.lkwFahrerData.maxSkillLevel then newSkillAfterJob = _G.lkwFahrerData.maxSkillLevel end
                outputChatBox("Herzlichen Glückwunsch! Du hast LKW-Fahrer Level " .. (newSkillAfterJob + 1) .. " erreicht!", player, 255, 215, 0)
            end
        end

        local updateQuery = "UPDATE player_job_skills SET jobs_completed_total = ?, skill_level = ? WHERE account_id = ? AND job_name = ?" --
        local successUpdate, errMsgUpdate = exports.datenbank:executeDatabase(updateQuery, currentJobsCompleted, newSkillAfterJob, accID, _G.lkwFahrerData.skillName) --
        if not successUpdate then
            outputDebugString("[LKW SERVER] FEHLER Skill Update (DB): " .. (errMsgUpdate or "Unbekannt"))
        end
    else
        outputDebugString("[LKW SERVER] FEHLER: Keine Account-ID für Skill Update bei " .. getPlayerName(player))
    end

    cleanupPlayerLKWJob(player, nil, false)
    triggerClientEvent(player, "jobs:lkwfahrer:trailerDelivered", player) --
    fadeCamera(player, false, 0.5)
    setTimer(function()
        if isElement(player) then
            setElementPosition(player, LKW_DISPATCHER_POS.x, LKW_DISPATCHER_POS.y, LKW_DISPATCHER_POS.z)
            setElementRotation(player, 0, 0, LKW_DISPATCHER_POS.rot or 0)
            setElementInterior(player, 0); setElementDimension(player, 0)
            fadeCamera(player, true, 0.5)
            outputChatBox("Du wurdest zurück zum LKW-Disponenten teleportiert.", player, 0, 200, 100)
        end
    end, 500, 1)
end)

addEventHandler("onPlayerQuit", root, function() cleanupPlayerLKWJob(source, "Verbindung getrennt.", false) end)
addEventHandler("onPlayerWasted", root, function() cleanupPlayerLKWJob(source, "Gestorben.", false) end)
addEventHandler("onVehicleExplode", root, function() for player, jobData in pairs(activeLKWJobs) do if source == jobData.vehicle or source == jobData.trailer then cleanupPlayerLKWJob(player, "Jobfahrzeug/Anhänger zerstört.", true); break end end end)
addEventHandler("onVehicleExit", root, function(player, seat) if activeLKWJobs[player] and source == activeLKWJobs[player].vehicle and seat == 0 then if isTimer(activeLKWJobs[player].leaveTimer) then killTimer(activeLKWJobs[player].leaveTimer) end; outputChatBox("LKW verlassen! Steige innerhalb von " .. (JOB_VEHICLE_LEAVE_TIMEOUT / 1000) .. "s wieder ein.", player, 255, 150, 0); activeLKWJobs[player].leaveTimer = setTimer(cleanupPlayerLKWJob, JOB_VEHICLE_LEAVE_TIMEOUT, 1, player, "LKW zu lange verlassen.", false) end end)
addEventHandler("onVehicleEnter", root, function(player, seat) if activeLKWJobs[player] and source == activeLKWJobs[player].vehicle and seat == 0 then if isTimer(activeLKWJobs[player].leaveTimer) then killTimer(activeLKWJobs[player].leaveTimer); activeLKWJobs[player].leaveTimer = nil; outputChatBox("Job fortgesetzt.", player, 0, 200, 50) end end end)
addEventHandler("onResourceStop", resourceRoot, function() for player, _ in pairs(activeLKWJobs) do cleanupPlayerLKWJob(player, "Ressource gestoppt.", false) end; activeLKWJobs = {} end)

-- outputDebugString("[LKW Job Server V-Skill] LKW Fahrer Job mit Skill-System geladen.")