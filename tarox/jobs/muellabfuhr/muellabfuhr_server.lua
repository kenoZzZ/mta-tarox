-- tarox/jobs/muellabfuhr/muellabfuhr_server.lua
-- MODIFIZIERT: Sendet Skill-Daten (inkl. jobs_completed_total und jobs_needed_for_next_level) an den Client
-- ERWEITERT: Logik für LKW-Fahrer Jobauswahl hinzugefügt
-- MODIFIZIERT: LKW-Fahrer Job-Voraussetzungen entfernt, da diese in lkw_server.lua geprüft werden. Müllfahrer benötigt Item 17.
-- NEU: Führerscheinprüfung und Teleport für LKW-Fahrer
-- MODIFIZIERT V2.3: Korrekte Weiterleitung für LKW-Job-Interaktion

-- =================================================================
-- Konfiguration
-- =================================================================
local JOB_PED_IDENTIFIER = "job_vermittler_ped" -- Dieser Ped ist für die Jobauswahl zuständig

-- jobRequirements sollte hier definiert sein oder aus einer globalen Quelle geladen werden.
-- Stelle sicher, dass der Eintrag für 'lkwfahrer' den korrekten 'skillName' enthält.
-- Beispiel (angenommen, es ist hier definiert):
jobRequirements = {
    muellfahrer = {
        playtime = 0.3,
        items = {17}, -- Benötigt Personalausweis (ID 17)
        displayName = "Müllfahrer",
        skillName = "muellfahrer" -- Muss mit dem Namen in player_job_skills übereinstimmen
    },
    busfahrer = {
        playtime = 1.5,
        items = {17, 18},
        displayName = "Busfahrer",
        skillName = "busfahrer"
    },
    lkwfahrer = { -- WICHTIG: skillName muss mit _G.lkwFahrerData.skillName übereinstimmen
        playtime = 1.0,
        items = {17},
        displayName = "LKW Fahrer",
        skillName = "lkwfahrer", -- Dies ist der Schlüssel, der in player_job_skills verwendet wird
        dispatcherPedIdentifier = "lkw_dispatcher_ped"
    },
    fischer = {
        playtime = 5,
        items = {17, 18},
        displayName = "Fischer",
        skillName = "fischer"
    },
    goldhaendler = {
        playtime = 10,
        items = {17, 18},
        displayName = "Goldhändler",
        skillName = "goldhaendler"
    },
    mechaniker = {
        playtime = 25,
        items = {17, 18},
        displayName = "Mechaniker",
        skillName = "mechaniker_skill"
    }
}


local muellfahrerData = {
    vehicleSpawnPos = {x = -2747.24805, y = 386.22818, z = 4.10314},
    vehicleModel = 574,
    checkpoints = {
        Vector3(-2747.18433, 403.00534, 4.10340), Vector3(-2719.86157, 412.97021, 4.14059),
        Vector3(-2704.02368, 446.86710, 4.15794), Vector3(-2709.69849, 494.85419, 6.17638),
        Vector3(-2746.05811, 543.69568, 13.24573), Vector3(-2708.51270, 561.83063, 14.47863),
        Vector3(-2623.71802, 562.37250, 14.43151), Vector3(-2551.26953, 561.45715, 14.43153),
        Vector3(-2529.56567, 539.17932, 14.43427), Vector3(-2554.62573, 471.64169, 14.43150),
        Vector3(-2609.44556, 453.57010, 14.42352), Vector3(-2609.20923, 377.29828, 7.32591),
        Vector3(-2625.46484, 333.16718, 4.15608), Vector3(-2702.53003, 337.39703, 4.15191),
        Vector3(-2747.19458, 360.34766, 4.15002)
    },
    rewardLevel1 = 600,
    rewardLevel2 = 1000,
    jobsForLevelUp = {
        [0] = 10, [1] = 25, [2] = 50, [3] = 100, [4] = 200
    },
    maxSkillLevel = 5
}

local activeMuellfahrerJobs = {}

function getJobsNeededForNextLevel(jobKey, currentSkillLevel, currentJobsCompleted)
    if jobKey ~= "muellfahrer" then return "N/A" end
    local config = muellfahrerData
    if currentSkillLevel >= config.maxSkillLevel then return "Max" end
    local neededForNextOverall = config.jobsForLevelUp[currentSkillLevel]
    if not neededForNextOverall then return "N/A" end
    local remaining = neededForNextOverall - currentJobsCompleted
    return math.max(0, remaining)
end

function handleJobPedInteraction(clickedPed)
    local player = client
    if not isElement(player) or not isElement(clickedPed) then return end
    local pedId = getElementData(clickedPed, "pedIdentifier")
    if pedId ~= JOB_PED_IDENTIFIER then return end
    if getElementData(player, "currentJob") then
        outputChatBox("Du hast bereits einen aktiven Job.", player, 255, 100, 0)
        return
    end
    local accID = getElementData(player, "account_id")
    if not accID then
        outputChatBox("Fehler: Account-Daten nicht geladen.", player, 255, 0, 0)
        return
    end

    local jobsWithSkills = {}
    local allSkillsQuery = "SELECT job_name, skill_level, jobs_completed_total FROM player_job_skills WHERE account_id = ?" --
    local skillsResult, skillsErrMsg = exports.datenbank:queryDatabase(allSkillsQuery, accID) --
    local playerSkills = {}

    if skillsResult == false then
        outputDebugString("[JOBS_SERVER] DB Fehler beim Laden der Skills für AccID " .. accID .. ": " .. (skillsErrMsg or "Unbekannt"))
    elseif skillsResult and #skillsResult > 0 then
        for _, row in ipairs(skillsResult) do
            playerSkills[row.job_name] = {
                skillLevel = tonumber(row.skill_level) or 0,
                jobsCompletedTotal = tonumber(row.jobs_completed_total) or 0
            }
        end
    end

    if not jobRequirements or type(jobRequirements) ~= "table" then
        outputDebugString("[JOBS_SERVER] FEHLER: jobRequirements nicht definiert oder kein Table in handleJobPedInteraction.")
        outputChatBox("Fehler bei der Jobauflistung.", player, 255,0,0)
        return
    end

    for jobKey, jobDataFromReq in pairs(jobRequirements) do
        local currentSkillData = playerSkills[jobDataFromReq.skillName] or { skillLevel = 0, jobsCompletedTotal = 0 }
        local jobsNeededDisplay = "N/A"

        if jobKey == "muellfahrer" then
             if type(getJobsNeededForNextLevel) == "function" then
                jobsNeededDisplay = getJobsNeededForNextLevel(jobKey, currentSkillData.skillLevel, currentSkillData.jobsCompletedTotal)
             else
                outputDebugString("[JOBS_SERVER] WARNUNG: getJobsNeededForNextLevel für Müllfahrer nicht gefunden.")
             end
        elseif jobKey == "lkwfahrer" then
             if _G.lkwFahrerData and type(_G.getJobsNeededForNextLevelLKW) == "function" then
                jobsNeededDisplay = _G.getJobsNeededForNextLevelLKW(currentSkillData.skillLevel, currentSkillData.jobsCompletedTotal)
             else
                outputDebugString("[JOBS_SERVER] WARNUNG: _G.lkwFahrerData oder _G.getJobsNeededForNextLevelLKW nicht global verfügbar für LKW Job GUI.")
             end
        end
        -- Hier können weitere else if Blöcke für andere Jobs mit spezifischen Skill-Anzeige-Logiken folgen

        jobsWithSkills[jobKey] = {
            displayName = jobDataFromReq.displayName,
            skillLevel = currentSkillData.skillLevel,
            jobsCompletedTotal = currentSkillData.jobsCompletedTotal,
            jobsNeededForNextLevel = jobsNeededDisplay
        }
    end
    triggerClientEvent(player, "jobs:showJobSelectionGUI", player, jobsWithSkills) --
end
addEvent("onClientRequestsPedAction", true)
addEventHandler("onClientRequestsPedAction", root, handleJobPedInteraction)

-- ... (Rest deiner muellabfuhr_server.lua Datei für onPlayerSelectJob, onPlayerStartMuellfahrerJob, onCheckpointReached, cleanupPlayerMuellJob und Event-Handler)
-- Die Funktion onPlayerSelectJob in muellabfuhr_server.lua muss jetzt auch den Fall "lkwfahrer" korrekt behandeln (Weiterleitung zum Dispatcher)

function onPlayerSelectJob(jobKey)
    local player = source
    if not jobRequirements[jobKey] then
        outputChatBox("Ungültiger Job ausgewählt.", player, 255,0,0)
        return
    end
    local jobData = jobRequirements[jobKey]

    if jobData.items and #jobData.items > 0 then
        for _, itemID in ipairs(jobData.items) do
            local hasItem, _ = exports.tarox:hasPlayerItem(player, itemID, 1) --
            if not hasItem then
                local itemDef = exports.tarox:getItemDefinition(itemID) --
                outputChatBox("Du benötigst: " .. (itemDef and itemDef.name or "ID: "..itemID), player, 255, 100, 0)
                return
            end
        end
    end

    local playerTotalMinutes = getElementData(player, "totalPlaytime") or 0
    if jobData.playtime and playerTotalMinutes < (jobData.playtime * 60) then
        outputChatBox("Du benötigst " .. jobData.playtime .. " Stunden Spielzeit für diesen Job.", player, 255, 100, 0)
        return
    end

    if jobKey == "lkwfahrer" then
        local dispatcherPedIdentifier = jobData.dispatcherPedIdentifier
        if not dispatcherPedIdentifier then
            outputChatBox("Fehler: LKW-Disponenten-Informationen nicht gefunden.", player, 255,0,0)
            return
        end
        local dispatcherPedElement = nil
        local allPeds = getElementsByType("ped")
        for _, ped in ipairs(allPeds) do
            if getElementData(ped, "pedIdentifier") == dispatcherPedIdentifier then
                dispatcherPedElement = ped
                break
            end
        end
        if not isElement(dispatcherPedElement) then
            outputChatBox("Fehler: LKW-Disponent nicht gefunden.", player, 255,100,0)
            return
        end
        local targetX, targetY, targetZ = -484.56033, -536.03162, 25.52961 -- Feste Koordinaten
        outputChatBox("Du wirst zum LKW Disponenten weitergeleitet.", player, 0, 200, 100)
        fadeCamera(player, false, 0.5)
        setTimer(function()
            if isElement(player) then
                if not isElement(dispatcherPedElement) then -- Erneute Prüfung im Timer
                    outputChatBox("Fehler: Der Job-Ansprechpartner ist nicht mehr verfügbar.", player, 255, 0, 0)
                    fadeCamera(player, true, 0.1)
                    return
                end
                setElementPosition(player, targetX, targetY, targetZ + 0.5)
                local pedRotX, pedRotY, pedRotZ = getElementRotation(dispatcherPedElement)
                if type(pedRotZ) == "number" then setElementRotation(player, 0, 0, pedRotZ + 180)
                else setElementRotation(player, 0, 0, 0) end
                setElementInterior(player, getElementInterior(dispatcherPedElement))
                setElementDimension(player, getElementDimension(dispatcherPedElement))
                fadeCamera(player, true, 0.5)
            end
        end, 500, 1)
        return
    end

    local accID = getElementData(player, "account_id")
    local currentSkillLevel = 0
    local currentJobsCompleted = 0
    if accID then
        local skillResult, skillErr = exports.datenbank:queryDatabase("SELECT skill_level, jobs_completed_total FROM player_job_skills WHERE account_id = ? AND job_name = ?", accID, jobData.skillName or jobKey) --
        if skillResult and skillResult[1] then
            currentSkillLevel = tonumber(skillResult[1].skill_level) or 0
            currentJobsCompleted = tonumber(skillResult[1].jobs_completed_total) or 0
        end
    end

    if jobKey == "muellfahrer" then
        local jobsNeededForNext = getJobsNeededForNextLevel(jobKey, currentSkillLevel, currentJobsCompleted)
        triggerClientEvent(player, "jobs:muellfahrer:confirmStart", player, jobKey, jobData.displayName, currentSkillLevel, currentJobsCompleted, jobsNeededForNext) --
    else
        outputChatBox("Dieser Job ist nicht implementiert oder erfordert eine andere Startmethode.", player, 255, 100, 0)
    end
end
addEvent("jobs:playerSelectedJob", true)
addEventHandler("jobs:playerSelectedJob", root, onPlayerSelectJob)


-- Müllfahrer spezifische Funktionen (onPlayerStartMuellfahrerJob, onCheckpointReached, cleanupPlayerMuellJob und Event-Handler dafür)
-- bleiben wie in deiner Originaldatei tarox/jobs/muellabfuhr/muellabfuhr_server.lua.
-- Hier ist ein Platzhalter für diesen Code:
-- [[ ... Dein Müllfahrer-spezifischer Code ab hier ... ]]
function onPlayerStartMuellfahrerJob(jobKey)
    local player = source
    local playerNameForDebug = getPlayerName(player)

    if not jobKey or jobKey ~= "muellfahrer" then
        outputChatBox("Fehler: Ungültiger Job-Startversuch.", player, 255,0,0)
        return
    end
    if getElementData(player, "currentJob") then
        outputChatBox("Du hast bereits einen aktiven Job.", player, 255, 100, 0)
        return
    end
    local accID = getElementData(player, "account_id")
    if not accID or type(tonumber(accID)) ~= "number" then
        outputChatBox("Fehler: Account-Daten nicht geladen oder validiert.", player, 255, 0, 0)
        return
    end
    local numericAccID = tonumber(accID)
    local resultData, errMsg = exports.datenbank:queryDatabase("SELECT skill_level, jobs_completed_total FROM player_job_skills WHERE account_id = ? AND job_name = 'muellfahrer'", numericAccID) --
    if resultData == false then
        outputChatBox("Ein Datenbankfehler ist aufgetreten.", player, 255,0,0)
        return
    end
    local playerSkillLevel, jobsDone = 0, 0
    if resultData and #resultData > 0 and resultData[1] then
        playerSkillLevel = tonumber(resultData[1].skill_level) or 0
        jobsDone = tonumber(resultData[1].jobs_completed_total) or 0
    else
         exports.datenbank:executeDatabase("INSERT IGNORE INTO player_job_skills (account_id, job_name, skill_level, jobs_completed_total) VALUES (?, 'muellfahrer', 0, 0)", numericAccID) --
    end
    local newSkillLevel = playerSkillLevel
    if playerSkillLevel < muellfahrerData.maxSkillLevel then
        local neededForNextLevelUp = muellfahrerData.jobsForLevelUp[playerSkillLevel]
        if neededForNextLevelUp and jobsDone >= neededForNextLevelUp then
            newSkillLevel = playerSkillLevel + 1
            if newSkillLevel > muellfahrerData.maxSkillLevel then newSkillLevel = muellfahrerData.maxSkillLevel end
            local updateSuccess, updateMsg = exports.datenbank:executeDatabase("UPDATE player_job_skills SET skill_level = ? WHERE account_id = ? AND job_name = 'muellfahrer'", newSkillLevel, numericAccID) --
            if updateSuccess then
                outputChatBox("Herzlichen Glückwunsch! Du hast Müllfahrer Level " .. newSkillLevel .. " erreicht!", player, 255, 215, 0)
                playerSkillLevel = newSkillLevel
            else
                outputDebugString("[MUELLJOB_SERVER] FEHLER beim Skill-Level Update für " .. playerNameForDebug .. ": " .. (updateMsg or "Unbekannt"))
            end
        end
    end
    local jobLevelToStart = playerSkillLevel
    if playerSkillLevel < 1 then jobLevelToStart = 0 end
    if jobLevelToStart >= muellfahrerData.maxSkillLevel then jobLevelToStart = muellfahrerData.maxSkillLevel -1 end
    local veh = createVehicle(muellfahrerData.vehicleModel, muellfahrerData.vehicleSpawnPos.x, muellfahrerData.vehicleSpawnPos.y, muellfahrerData.vehicleSpawnPos.z)
    if not isElement(veh) then
        outputChatBox("Fehler: Jobfahrzeug konnte nicht erstellt werden.", player, 255, 0, 0)
        return
    end
    setElementDimension(veh, getElementDimension(player))
    setElementInterior(veh, getElementInterior(player))
    setElementData(veh, "jobVehicleForPlayer", player, false)
    local warped = warpPedIntoVehicle(player, veh)
    if not warped then
       outputChatBox("Fehler: Konnte dich nicht ins Fahrzeug setzen.", player, 255,0,0)
       if isElement(veh) then destroyElement(veh) end
       return
    end
    setElementData(player, "currentJob", "muellfahrer", false)
    activeMuellfahrerJobs[player] = { vehicle = veh, currentCheckpoint = 1, level = jobLevelToStart + 1, leaveTimer = nil }
    outputChatBox("Müllfahrer-Job (Level " .. (jobLevelToStart + 1) .. ") gestartet! Fahre zum ersten Checkpoint.", player, 0, 200, 50)
    local cpData = muellfahrerData.checkpoints[1]
    if cpData then
        local checkpointTable = { x = cpData.x, y = cpData.y, z = cpData.z }
        triggerClientEvent(player, "jobs:muellfahrer:updateCheckpoint", player, checkpointTable, 1, #muellfahrerData.checkpoints) --
    else
        cleanupPlayerMuellJob(player, "Interner Fehler bei Checkpoint-Daten.")
    end
end
addEvent("jobs:muellfahrer:startJobConfirmed", true)
addEventHandler("jobs:muellfahrer:startJobConfirmed", root, onPlayerStartMuellfahrerJob)

function onCheckpointReached()
    local player = source
    if not activeMuellfahrerJobs[player] then return end
    local jobData = activeMuellfahrerJobs[player]
    jobData.currentCheckpoint = jobData.currentCheckpoint + 1
    if jobData.currentCheckpoint > #muellfahrerData.checkpoints then
        local reward = (jobData.level == 1) and muellfahrerData.rewardLevel1 or muellfahrerData.rewardLevel2
        givePlayerMoney(player, reward)
        outputChatBox("Müllfahrer-Job erfolgreich beendet! Du hast $" .. reward .. " erhalten.", player, 0, 255, 0)
        local accID = getElementData(player, "account_id")
        if accID and tonumber(accID) then
            local currentSkill = 0
            local jobsTotal = 0
            local skillRes, skillErr = exports.datenbank:queryDatabase("SELECT skill_level, jobs_completed_total FROM player_job_skills WHERE account_id = ? AND job_name = 'muellfahrer'", tonumber(accID)) --
            if skillRes and skillRes[1] then
                currentSkill = tonumber(skillRes[1].skill_level) or 0
                jobsTotal = tonumber(skillRes[1].jobs_completed_total) or 0
            end
            jobsTotal = jobsTotal + 1
            local newSkillAfterJob = currentSkill
            if currentSkill < muellfahrerData.maxSkillLevel then
                local neededForNextLvlUp = muellfahrerData.jobsForLevelUp[currentSkill]
                if neededForNextLvlUp and jobsTotal >= neededForNextLvlUp then
                    newSkillAfterJob = currentSkill + 1
                    if newSkillAfterJob > muellfahrerData.maxSkillLevel then newSkillAfterJob = muellfahrerData.maxSkillLevel end
                    outputChatBox("Herzlichen Glückwunsch! Du hast Müllfahrer Level " .. newSkillAfterJob .. " erreicht!", player, 255, 215, 0)
                end
            end
            local success, errMsg = exports.datenbank:executeDatabase("UPDATE player_job_skills SET jobs_completed_total = ?, skill_level = ? WHERE account_id = ? AND job_name = 'muellfahrer'", jobsTotal, newSkillAfterJob, tonumber(accID)) --
            if not success then
                outputDebugString("[MUELLJOB_SERVER] FEHLER beim Speichern des Job-Abschlusses für AccID " .. accID .. ": "..(errMsg or "Unbekannt"))
            end
        else
            outputDebugString("[MUELLJOB_SERVER] FEHLER: Ungültige Account-ID ("..tostring(accID)..") beim Speichern für " .. getPlayerName(player))
        end
        cleanupPlayerMuellJob(player)
    else
        outputChatBox("Checkpoint erreicht! Fahre zum nächsten Punkt.", player, 0, 200, 50)
        local cpDataNext = muellfahrerData.checkpoints[jobData.currentCheckpoint]
        if cpDataNext then
            local nextCheckpointTable = { x = cpDataNext.x, y = cpDataNext.y, z = cpDataNext.z }
            triggerClientEvent(player, "jobs:muellfahrer:updateCheckpoint", player, nextCheckpointTable, jobData.currentCheckpoint, #muellfahrerData.checkpoints) --
        else
            cleanupPlayerMuellJob(player, "Interner Fehler bei Checkpoint-Daten.")
        end
    end
end
addEvent("jobs:muellfahrer:checkpointReached", true)
addEventHandler("jobs:muellfahrer:checkpointReached", root, onCheckpointReached)

function cleanupPlayerMuellJob(player, reason)
    if not isElement(player) or not activeMuellfahrerJobs[player] then return end
    local jobData = activeMuellfahrerJobs[player]
    if isElement(jobData.vehicle) then destroyElement(jobData.vehicle) end
    if isTimer(jobData.leaveTimer) then killTimer(jobData.leaveTimer) end
    activeMuellfahrerJobs[player] = nil
    removeElementData(player, "currentJob")
    triggerClientEvent(player, "jobs:muellfahrer:jobCancelled", player) --
    if reason then
        outputChatBox("Müllfahrer-Job abgebrochen: " .. reason, player, 255, 100, 0)
    end
end
addEventHandler("onPlayerQuit", root, function() if activeMuellfahrerJobs[source] then cleanupPlayerMuellJob(source, "Verbindung getrennt.") end end)
addEventHandler("onPlayerWasted", root, function() if activeMuellfahrerJobs[source] then cleanupPlayerMuellJob(source, "Gestorben.") end end)
addEventHandler("onVehicleExplode", root, function() for player, jobData in pairs(activeMuellfahrerJobs) do if source == jobData.vehicle then cleanupPlayerMuellJob(player, "Jobfahrzeug zerstört."); break end end end)
addEventHandler("onVehicleExit", root, function(player, seat) if activeMuellfahrerJobs[player] and source == activeMuellfahrerJobs[player].vehicle and seat == 0 then outputChatBox("Du hast 30 Sekunden Zeit, wieder einzusteigen.", player, 255, 150, 0); activeMuellfahrerJobs[player].leaveTimer = setTimer(cleanupPlayerMuellJob, 30000, 1, player, "Fahrzeug zu lange verlassen.") end end)
addEventHandler("onVehicleEnter", root, function(player, seat) if activeMuellfahrerJobs[player] and source == activeMuellfahrerJobs[player].vehicle and seat == 0 then if isTimer(activeMuellfahrerJobs[player].leaveTimer) then killTimer(activeMuellfahrerJobs[player].leaveTimer); activeMuellfahrerJobs[player].leaveTimer = nil; outputChatBox("Job fortgesetzt.", player, 0, 200, 50) end end end)
addEventHandler("onResourceStop", resourceRoot, function() for player, _ in pairs(activeMuellfahrerJobs) do cleanupPlayerMuellJob(player, "Ressource gestoppt.") end end)
addEventHandler("onResourceStart", resourceRoot, function() if not exports.datenbank or not exports.datenbank:getConnection() then outputDebugString("[JOBS_SERVER] WARNUNG: DB nicht verfügbar.") end end)