-- tarox/drivelicense/drive_server.lua
-- Version mit Beifahrer-Ped und Geschwindigkeitskontrolle
-- MODIFIED: Added driver's license item granting
-- ANGEPASST V1.1: Verbesserte Fehlerbehandlung
-- KORRIGIERT V1.2: Syntaxfehler in Zeile 369 behoben
-- KORRIGIERT V1.3: Syntaxfehler bei Export in Zeile 384 behoben

local LICENSE_CONFIG = {
    ["car"] = {
        id = 1,
        internal_name = "car_license",
        displayName = "PKW Führerschein (Klasse B)",
        cost_theory = 500,
        cost_practical = 1000,
        cost_total = 1500,
        required_vehicle_model_practical = 400, -- Landstalker
        min_age = 17,
        instructor_ped_model = 141,
        theory_questions = {
            { q = "Wie schnell darf man innerorts maximal fahren, wenn nicht anders ausgeschildert?", a = {"30 km/h", "50 km/h", "60 km/h"}, correct = 2, image = nil },
            { q = "Was bedeutet dieses Verkehrszeichen? (STOP-Schild)", a = {"Parkverbot", "Halteverbot", "Anhalten und Vorfahrt gewähren"}, correct = 3, image = "stop_sign.png" },
            { q = "Darf man unter Alkoholeinfluss fahren?", a = {"Ja, geringe Mengen sind erlaubt", "Nein, niemals", "Nur wenn man sich fit fühlt"}, correct = 2, image = nil },
            { q = "Welche Farbe hat das Bremslicht eines Fahrzeugs?", a = {"Weiß", "Gelb", "Rot"}, correct = 3, image = nil },
            { q = "Was ist beim Überholen auf einer Landstraße besonders zu beachten?", a = {"Ausreichend Seitenabstand", "Gegenverkehr", "Beides"}, correct = 3, image = nil }
        },
        practical_route_checkpoints = {
            {x = -2182.95801, y = -67.70458, z = 34.58163, tolerance = 5},
            {x = -2235.59180, y = -67.90887, z = 34.58155, tolerance = 5},
            {x = -2260.25928, y = -107.06631, z = 34.58142, tolerance = 5},
            {x = -2260.19678, y = -171.42984, z = 34.58204, tolerance = 5},
            {x = -2217.31689, y = -191.81082, z = 34.62883, tolerance = 5},
            {x = -2165.42993, y = -142.41386, z = 34.58152, tolerance = 5},
            {x = -2165.29810, y = -87.16048, z = 34.58162, tolerance = 5},
            {x = -2116.35938, y = -72.31026, z = 34.58107, tolerance = 5},
            {x = -2046.59290, y = -103.69129, z = 34.60006, tolerance = 5}
        },
        allows_vehicle_models = { 400,401,402,404,405,410,411,412,413,414,415,416,418,419,420,421,422,423,424,426,429,434,436,438,439,440,442,445,448,451,461,462,463,468,470,474,475,477,478,479,480,489,490,491,492,494,495,496,500,502,503,504,505,506,507,508,516,517,518,519,520,521,522,523,526,527,529,533,534,535,536,540,541,542,543,545,546,547,549,550,551,552,554,555,558,559,560,561,562,565,566,567,568,571,572,575,576,579,580,581,582,583,585,586,587,589,592,593,596,597,598,599,600,602,603,604,609 },
        vehicle_spawn_pos_practical_test = { x = -2045.98792, y = -87.67596, z = 35.55709, rot = 270, interior = 0, dimension = 1 }
    },
    ["bike"] = {
        id = 2,
        internal_name = "bike_license",
        displayName = "Motorrad Führerschein (Klasse A)",
        cost_theory = 300,
        cost_practical = 500,
        cost_total = 800,
        required_vehicle_model_practical = 461, -- PCJ-600
        instructor_ped_model = 141,
        theory_questions = {
             { q = "Welche Schutzkleidung ist für Motorradfahrer vorgeschrieben?", a = {"Nur Helm", "Helm und Handschuhe", "Helm, Jacke, Hose, Handschuhe, Stiefel"}, correct = 3, image = nil },
             { q = "Darf ein Motorrad zwischen zwei Fahrstreifen fahren (Stau)?", a = {"Ja, immer", "Nein, niemals", "Nur wenn genug Platz ist und mit Vorsicht"}, correct = 2, image = nil },
        },
        practical_route_checkpoints = {
            {x = -2182.95801, y = -67.70458, z = 34.58163, tolerance = 5},
            {x = -2235.59180, y = -67.90887, z = 34.58155, tolerance = 5},
            {x = -2260.25928, y = -107.06631, z = 34.58142, tolerance = 5},
            {x = -2260.19678, y = -171.42984, z = 34.58204, tolerance = 5},
            {x = -2217.31689, y = -191.81082, z = 34.62883, tolerance = 5},
            {x = -2165.42993, y = -142.41386, z = 34.58152, tolerance = 5},
            {x = -2165.29810, y = -87.16048, z = 34.58162, tolerance = 5},
            {x = -2116.35938, y = -72.31026, z = 34.58107, tolerance = 5},
            {x = -2046.59290, y = -103.69129, z = 34.60006, tolerance = 5}
        },
        allows_vehicle_models = { 461, 462, 463, 468, 521, 522, 581, 586, 448, 471, 523 },
        vehicle_spawn_pos_practical_test = { x = -2045.98792, y = -87.67596, z = 35.55709, rot = 270, interior = 0, dimension = 1 }
    },
}
_G.LICENSE_CONFIG = LICENSE_CONFIG

local playerLicenseProgress = {}

local FAHRSCHULE_SPAWN_POS_X = -2032.47937
local FAHRSCHULE_SPAWN_POS_Y = -117.47287
local FAHRSCHULE_SPAWN_POS_Z = 1035.17188
local FAHRSCHULE_SPAWN_INTERIOR = 3
local FAHRSCHULE_SPAWN_DIMENSION = 0
local FAHRSCHULE_SPAWN_ROTATION = 180

local DRIVING_SCHOOL_ENTRANCE_MARKER_POS = {x = -2026.55566, y = -101.18298, z = 35.16406}
local DRIVING_SCHOOL_ENTRANCE_TARGET_POS = {x = -2029.42566, y = -116.92297, z = 1035.17188}
local DRIVING_SCHOOL_ENTRANCE_TARGET_INTERIOR = 3
local DRIVING_SCHOOL_ENTRANCE_TARGET_DIMENSION = 0
local DRIVING_SCHOOL_ENTRANCE_TARGET_ROTATION = 180

local DRIVING_SCHOOL_EXIT_MARKER_POS = {x = -2029.75977, y = -119.44710, z = 1035.17188}
local DRIVING_SCHOOL_EXIT_TARGET_POS = {x = -2026.62036, y = -97.68080, z = 35.16406}
local DRIVING_SCHOOL_EXIT_TARGET_INTERIOR = 0
local DRIVING_SCHOOL_EXIT_TARGET_DIMENSION = 0
local DRIVING_SCHOOL_EXIT_TARGET_ROTATION = 270

local drivingSchoolEntranceMarker = nil
local drivingSchoolExitMarker = nil

local function tableToMetadataString(tbl)
    if type(tbl) ~= "table" then return "" end
    local parts = {}
    for key, value in pairs(tbl) do
        local valStr = tostring(value)
        valStr = string.gsub(valStr, "|", "{pipe}")
        valStr = string.gsub(valStr, ":", "{colon}")
        table.insert(parts, tostring(key) .. ":" .. valStr)
    end
    return table.concat(parts, "|")
end

function createDrivingSchoolTeleportMarkers()
    if isElement(drivingSchoolEntranceMarker) then destroyElement(drivingSchoolEntranceMarker) end
    drivingSchoolEntranceMarker = createMarker(
        DRIVING_SCHOOL_ENTRANCE_MARKER_POS.x, DRIVING_SCHOOL_ENTRANCE_MARKER_POS.y, DRIVING_SCHOOL_ENTRANCE_MARKER_POS.z - 1,
        "cylinder", 1.5, 0, 255, 0, 150
    )
    if isElement(drivingSchoolEntranceMarker) then
        setElementInterior(drivingSchoolEntranceMarker, 0); setElementDimension(drivingSchoolEntranceMarker, 0)
        addEventHandler("onMarkerHit", drivingSchoolEntranceMarker, function(hitElement, matchingDimension)
            if getElementType(hitElement) == "player" and matchingDimension and not isPedInVehicle(hitElement) then
                fadeCamera(hitElement, false, 0.5)
                setTimer(function() if isElement(hitElement) then setElementPosition(hitElement, DRIVING_SCHOOL_ENTRANCE_TARGET_POS.x, DRIVING_SCHOOL_ENTRANCE_TARGET_POS.y, DRIVING_SCHOOL_ENTRANCE_TARGET_POS.z); setElementInterior(hitElement, DRIVING_SCHOOL_ENTRANCE_TARGET_INTERIOR); setElementDimension(hitElement, DRIVING_SCHOOL_ENTRANCE_TARGET_DIMENSION); setElementRotation(hitElement, 0, 0, DRIVING_SCHOOL_ENTRANCE_TARGET_ROTATION); fadeCamera(hitElement, true, 0.5) end end, 500, 1)
            end
        end)
    else outputDebugString("[DriveServer ERROR] Fahrschul-Eingangsmarker konnte nicht erstellt werden!") end

    if isElement(drivingSchoolExitMarker) then destroyElement(drivingSchoolExitMarker) end
    drivingSchoolExitMarker = createMarker(
        DRIVING_SCHOOL_EXIT_MARKER_POS.x, DRIVING_SCHOOL_EXIT_MARKER_POS.y, DRIVING_SCHOOL_EXIT_MARKER_POS.z -1,
        "cylinder", 1.5, 255, 0, 0, 150
    )
    if isElement(drivingSchoolExitMarker) then
        setElementInterior(drivingSchoolExitMarker, DRIVING_SCHOOL_ENTRANCE_TARGET_INTERIOR); setElementDimension(drivingSchoolExitMarker, DRIVING_SCHOOL_ENTRANCE_TARGET_DIMENSION)
        addEventHandler("onMarkerHit", drivingSchoolExitMarker, function(hitElement, matchingDimension)
            if getElementType(hitElement) == "player" and matchingDimension and not isPedInVehicle(hitElement) then
                fadeCamera(hitElement, false, 0.5)
                setTimer(function() if isElement(hitElement) then setElementPosition(hitElement, DRIVING_SCHOOL_EXIT_TARGET_POS.x, DRIVING_SCHOOL_EXIT_TARGET_POS.y, DRIVING_SCHOOL_EXIT_TARGET_POS.z); setElementInterior(hitElement, DRIVING_SCHOOL_EXIT_TARGET_INTERIOR); setElementDimension(hitElement, DRIVING_SCHOOL_EXIT_TARGET_DIMENSION); setElementRotation(hitElement, 0, 0, DRIVING_SCHOOL_EXIT_TARGET_ROTATION); fadeCamera(hitElement, true, 0.5) end end, 500, 1)
            end
        end)
    else outputDebugString("[DriveServer ERROR] Fahrschul-Ausgangsmarker konnte nicht erstellt werden!") end
    --outputDebugString("[DriveServer] Fahrschul Teleport-Marker erstellt.")
end

addEvent("drivelicense:pedInteraction", true)
addEventHandler("drivelicense:pedInteraction", root, function()
    local player = client
    if not isElement(player) then return end
    local accountId = getElementData(player, "account_id")
    if not accountId then outputChatBox("Fehler: Account-Daten nicht geladen.", player, 255, 0, 0); return end

    local existingLicenses, licErrMsg = getPlayerLicenses(player) -- Anpassung: Fehlerbehandlung für getPlayerLicenses
    if licErrMsg then
        outputChatBox("Fehler beim Laden deiner Lizenzen: " .. licErrMsg, player, 255, 0, 0)
        return -- Abbruch, wenn Lizenzen nicht geladen werden können
    end
    local availableLicensesForGUI = {}

    for licenseKey, config in pairs(LICENSE_CONFIG) do
        local hasThisLicense = false
        local statusThisLicense = "not_started"
        for _, ownedLicense in ipairs(existingLicenses) do
            if ownedLicense.license_type == licenseKey then
                if ownedLicense.status == "active" then hasThisLicense = true; statusThisLicense = "active";
                elseif ownedLicense.status == "pending_practical_test" then statusThisLicense = "pending_practical_test"; end
                break
            end
        end
        local isCurrentlyDoingThis = false
        if playerLicenseProgress[player] and playerLicenseProgress[player].license_key == licenseKey then
            isCurrentlyDoingThis = true
            if playerLicenseProgress[player].stage == "awaiting_practical" then statusThisLicense = "pending_practical_test"; end
        end
        table.insert(availableLicensesForGUI, {
            key = licenseKey, displayName = config.displayName, cost_theory = config.cost_theory,
            cost_practical = config.cost_practical, cost_total = config.cost_total,
            hasLicense = hasThisLicense, status = statusThisLicense, isCurrentlyDoing = isCurrentlyDoingThis
        })
    end
    if type(triggerClientEvent) == "function" then
        triggerClientEvent(player, "drivelicense:openMenu", player, availableLicensesForGUI)
    else outputChatBox("Systemfehler beim Öffnen des Menüs.", player, 255,0,0) end
end)

addEvent("drivelicense:startLicenseProcess", true)
addEventHandler("drivelicense:startLicenseProcess", root, function(licenseKey)
    local player = client
    if not isElement(player) then return end
    local accountId = getElementData(player, "account_id"); if not accountId then return end
    local licenseConfig = LICENSE_CONFIG[licenseKey]
    if not licenseConfig then outputChatBox("Ungültiger Führerscheintyp.", player, 255,0,0); return; end
    if playerLicenseProgress[player] then outputChatBox("Du machst bereits einen Führerschein.", player, 255,100,0); return; end
    if hasPlayerLicense(player, licenseKey) then outputChatBox("Du besitzt diesen Führerschein bereits.", player, 255,165,0); return; end

    local currentLicenses, licErrMsg = getPlayerLicenses(player)
    if licErrMsg then outputChatBox("Fehler beim Prüfen vorhandener Lizenzen.", player, 255,0,0); return end
    for _, lic in ipairs(currentLicenses) do
        if lic.license_type == licenseKey and lic.status == "pending_practical_test" then
            playerLicenseProgress[player] = { license_key = licenseKey, stage = "awaiting_practical" }
            if type(triggerClientEvent) == "function" then
                 triggerClientEvent(player, "drivelicense:confirmStartPractical", player, licenseConfig.displayName, licenseConfig.cost_practical)
            else outputChatBox("Systemfehler beim Fortsetzen.", player, 255,0,0) end
            return
        end
    end

    if getPlayerMoney(player) < licenseConfig.cost_theory then outputChatBox("Nicht genug Geld ($" .. licenseConfig.cost_theory .. ").", player, 255,100,0); return; end
    takePlayerMoney(player, licenseConfig.cost_theory)
    playerLicenseProgress[player] = { license_key = licenseKey, stage = "theory_test", current_question_index = 1, score = 0, answers = {} }
    outputChatBox("Theorieprüfung für " .. licenseConfig.displayName .. " gestartet. Kosten: $" .. licenseConfig.cost_theory, player, 0,200,50)
    if type(triggerClientEvent) == "function" then
        triggerClientEvent(player, "drivelicense:showTheoryQuestion", player, licenseConfig.theory_questions[1], 1, #licenseConfig.theory_questions)
    else outputChatBox("Systemfehler beim Start der Theorieprüfung.", player, 255,0,0) end
end)

addEvent("drivelicense:submitTheoryAnswer", true)
addEventHandler("drivelicense:submitTheoryAnswer", root, function(answerIndex)
    local player = client
    if not isElement(player) or not playerLicenseProgress[player] or playerLicenseProgress[player].stage ~= "theory_test" then return end
    local state = playerLicenseProgress[player]; local licenseConfig = LICENSE_CONFIG[state.license_key]
    local currentQuestionData = licenseConfig.theory_questions[state.current_question_index]
    if tonumber(answerIndex) == currentQuestionData.correct then state.score = state.score + 1; outputChatBox("Richtig!", player, 0,200,0);
    else outputChatBox("Falsch. Richtig: " .. currentQuestionData.a[currentQuestionData.correct], player, 200,0,0); end
    state.answers[state.current_question_index] = tonumber(answerIndex); state.current_question_index = state.current_question_index + 1

    if type(triggerClientEvent) ~= "function" then
        outputChatBox("Systemfehler bei der Theorieprüfung.", player, 255,0,0)
        playerLicenseProgress[player] = nil
        return
    end

    if state.current_question_index > #licenseConfig.theory_questions then
        local passThreshold = math.ceil(#licenseConfig.theory_questions * 0.75)
        if state.score >= passThreshold then
            local statusSetSuccess, statusSetMsg = setPlayerLicenseStatus(player, state.license_key, "pending_practical_test")
            if not statusSetSuccess then
                outputChatBox("Fehler beim Aktualisieren des Lizenzstatus: " .. (statusSetMsg or "DB Fehler"), player, 255,0,0)
                playerLicenseProgress[player] = nil
                triggerClientEvent(player, "drivelicense:theoryTestFinished", player, false, state.score, #licenseConfig.theory_questions, "Fehler beim Speichern des Fortschritts.")
                return
            end

            if licenseConfig.practical_route_checkpoints and #licenseConfig.practical_route_checkpoints > 0 then
                playerLicenseProgress[player].stage = "awaiting_practical"
                triggerClientEvent(player, "drivelicense:theoryTestFinished", player, true, state.score, #licenseConfig.theory_questions, "Möchtest du nun die praktische Prüfung für $".. licenseConfig.cost_practical .." starten?")
            else
                local giveLicSuccess, giveLicMsg = givePlayerLicenseInternal(player, state.license_key, licenseConfig.displayName)
                if not giveLicSuccess then
                     outputChatBox("Fehler beim Ausstellen des Führerscheins: ".. (giveLicMsg or "Unbekannt"), player, 255,0,0)
                end
                playerLicenseProgress[player] = nil;
                triggerClientEvent(player, "drivelicense:theoryTestFinished", player, true, state.score, #licenseConfig.theory_questions, nil);
            end
        else
            outputChatBox("Theorie nicht bestanden (" .. state.score .. "/" .. #licenseConfig.theory_questions .. ").", player, 255,0,0)
            playerLicenseProgress[player] = nil;
            triggerClientEvent(player, "drivelicense:theoryTestFinished", player, false, state.score, #licenseConfig.theory_questions, nil);
        end
    else
        triggerClientEvent(player, "drivelicense:showTheoryQuestion", player, licenseConfig.theory_questions[state.current_question_index], state.current_question_index, #licenseConfig.theory_questions);
    end
end)

addEvent("drivelicense:startPracticalTest", true)
addEventHandler("drivelicense:startPracticalTest", root, function()
    local player = client
    if not isElement(player) then return end
    local currentLicenseKeyForPractical = nil
    if playerLicenseProgress[player] and playerLicenseProgress[player].license_key then
        currentLicenseKeyForPractical = playerLicenseProgress[player].license_key
        if playerLicenseProgress[player].stage ~= "awaiting_practical" then
            local licensesDB, licErr = getPlayerLicenses(player); if licErr then outputChatBox("Fehler beim Laden der Lizenzen.",player,255,0,0);return end
            local foundPendingInDB = false
            for _, lic_db in ipairs(licensesDB) do if lic_db.license_type == currentLicenseKeyForPractical and lic_db.status == "pending_practical_test" then playerLicenseProgress[player].stage = "awaiting_practical"; foundPendingInDB = true; break end end
            if not foundPendingInDB then playerLicenseProgress[player] = nil; currentLicenseKeyForPractical = nil end
        end
    end
    if not currentLicenseKeyForPractical then
        local licenses, licErr2 = getPlayerLicenses(player); if licErr2 then outputChatBox("Fehler beim Laden der Lizenzen.",player,255,0,0);return end
        for _, lic in ipairs(licenses) do
            if lic.status == "pending_practical_test" then currentLicenseKeyForPractical = lic.license_type; if not playerLicenseProgress[player] or playerLicenseProgress[player].license_key ~= currentLicenseKeyForPractical then playerLicenseProgress[player] = { license_key = currentLicenseKeyForPractical, stage = "awaiting_practical" } elseif playerLicenseProgress[player].stage ~= "awaiting_practical" then playerLicenseProgress[player].stage = "awaiting_practical" end; break end
        end
    end
    if not playerLicenseProgress[player] or playerLicenseProgress[player].stage ~= "awaiting_practical" or not currentLicenseKeyForPractical then outputChatBox("Fehler: Prüfungsprozess konnte nicht korrekt gestartet werden.", player,255,100,0); if playerLicenseProgress[player]then playerLicenseProgress[player]=nil end; return end
    local state = playerLicenseProgress[player]; local licenseConfig = LICENSE_CONFIG[state.license_key]
    if not licenseConfig.required_vehicle_model_practical or not licenseConfig.practical_route_checkpoints or #licenseConfig.practical_route_checkpoints == 0 then outputChatBox("Keine praktische Prüfung vorgesehen.", player,255,100,0); givePlayerLicenseInternal(player,state.license_key,licenseConfig.displayName); playerLicenseProgress[player]=nil; return end
    if getPlayerMoney(player) < licenseConfig.cost_practical then outputChatBox("Nicht genug Geld ($"..licenseConfig.cost_practical..").", player,255,100,0); return end
    takePlayerMoney(player, licenseConfig.cost_practical)
    local vsCfg=licenseConfig.vehicle_spawn_pos_practical_test; local testVehicle=createVehicle(licenseConfig.required_vehicle_model_practical,vsCfg.x,vsCfg.y,vsCfg.z,0,0,vsCfg.rot)
    if not isElement(testVehicle) then outputChatBox("Fehler: Prüfungsfahrzeug konnte nicht erstellt werden.", player,255,0,0); givePlayerMoney(player,licenseConfig.cost_practical); playerLicenseProgress[player]=nil; return end
    setElementInterior(testVehicle,vsCfg.interior); setElementDimension(testVehicle,vsCfg.dimension); setElementData(testVehicle,"isDrivingTestVehicle",true); setElementData(testVehicle,"driverSchoolPlayer",player); setElementData(testVehicle,"licenseKeyForTest",state.license_key)
    local instructorPed=nil; if licenseConfig.instructor_ped_model and licenseConfig.instructor_ped_model>0 then instructorPed=createPed(licenseConfig.instructor_ped_model,vsCfg.x+2,vsCfg.y,vsCfg.z); if isElement(instructorPed)then setElementInterior(instructorPed,vsCfg.interior);setElementDimension(instructorPed,vsCfg.dimension);setPedRotation(instructorPed,vsCfg.rot);warpPedIntoVehicle(instructorPed,testVehicle,1);setElementFrozen(instructorPed,true);setElementData(testVehicle,"drivingInstructorPed",instructorPed);setElementData(instructorPed,"isDrivingInstructorCompanion",true);outputChatBox("Fahrlehrer: Max 50 km/h.",player,255,165,0)else outputDebugString("[DriveServer] FEHLER: Beifahrer-Ped nicht erstellt.")end end
    state.stage="practical_test"; state.practical_test_vehicle=testVehicle; state.practical_test_instructor=instructorPed; state.current_checkpoint_index=1; state.start_health=getElementHealth(testVehicle); state.speeding_start_time=0; state.speeding_warned=false
    setVehicleDamageProof(testVehicle,false); setVehicleEngineState(testVehicle,true); setVehicleLocked(testVehicle,false)
    if getElementInterior(player)~=vsCfg.interior or getElementDimension(player)~=vsCfg.dimension then fadeCamera(player,false,0.2);setTimer(function()if isElement(player)and isElement(testVehicle)then setElementInterior(player,vsCfg.interior);setElementDimension(player,vsCfg.dimension);warpPedIntoVehicle(player,testVehicle,0);fadeCamera(player,true,0.5)end end,250,1)else warpPedIntoVehicle(player,testVehicle,0)end
    setTimer(setElementFrozen,500,1,testVehicle,false)
    outputChatBox("Praktische Prüfung für "..licenseConfig.displayName.." gestartet! Folge Checkpoints. Kosten: $"..licenseConfig.cost_practical, player,0,200,100)
    if type(triggerClientEvent)=="function"then triggerClientEvent(player,"drivelicense:startPracticalTestClient",player,licenseConfig.practical_route_checkpoints,testVehicle)else outputDebugString("[DriveServer] FEHLER: triggerClientEvent nicht existent!");outputChatBox("Systemfehler Start praktische Prüfung.",player,255,0,0);if isElement(testVehicle)then destroyElement(testVehicle)end;if isElement(instructorPed)then destroyElement(instructorPed)end;givePlayerMoney(player,licenseConfig.cost_practical);playerLicenseProgress[player]=nil end
end)


addEvent("drivelicense:finishPracticalTest", true)
addEventHandler("drivelicense:finishPracticalTest", root, function(success, reason)
    local player = client
    if not isElement(player) or not playerLicenseProgress[player] or playerLicenseProgress[player].stage ~= "practical_test" then return end
    local state = playerLicenseProgress[player]; local licenseConfig = LICENSE_CONFIG[state.license_key]
    if isElement(state.practical_test_vehicle) then destroyElement(state.practical_test_vehicle) end
    if isElement(state.practical_test_instructor) then destroyElement(state.practical_test_instructor) end
    if isElement(player) then fadeCamera(player,false,0.2);setTimer(function()if isElement(player)then setElementPosition(player,FAHRSCHULE_SPAWN_POS_X,FAHRSCHULE_SPAWN_POS_Y,FAHRSCHULE_SPAWN_POS_Z);setElementRotation(player,0,0,FAHRSCHULE_SPAWN_ROTATION);setElementInterior(player,FAHRSCHULE_SPAWN_INTERIOR);setElementDimension(player,FAHRSCHULE_SPAWN_DIMENSION);fadeCamera(player,true,0.5)end end,250,1)end
    if success then
        outputChatBox("Praktische Prüfung bestanden!", player,0,255,0)
        local giveSuccessInternal, giveMsgInternal = givePlayerLicenseInternal(player,state.license_key,licenseConfig.displayName)
        if not giveSuccessInternal then outputChatBox("Problem beim Ausstellen des Führerscheins: ".. (giveMsgInternal or "Unbekannt"), player, 255,0,0) end
    else
        outputChatBox("Praktische Prüfung nicht bestanden: "..(reason or "Unbekannt"), player,255,0,0)
        local statusSetSuccessInternal, statusSetMsgInternal = setPlayerLicenseStatus(player,state.license_key,"pending_theory")
        if not statusSetSuccessInternal then outputChatBox("Problem beim Aktualisieren des Lizenzstatus: ".. (statusSetMsgInternal or "Unbekannt"), player, 255,0,0) end
    end
    playerLicenseProgress[player].speeding_start_time=0; playerLicenseProgress[player].speeding_warned=false; playerLicenseProgress[player]=nil;
    if type(triggerClientEvent)=="function"then triggerClientEvent(player,"drivelicense:practicalTestFinishedClient",player,success)else outputDebugString("[DriveServer] FEHLER: triggerClientEvent nicht existent!")end
end)

function handleTestVehicleDestroyed()
    local vehicle=source; local player=getElementData(vehicle,"driverSchoolPlayer"); local licenseKey=getElementData(vehicle,"licenseKeyForTest")
    if isElement(player)and playerLicenseProgress[player]and playerLicenseProgress[player].license_key==licenseKey and playerLicenseProgress[player].stage=="practical_test"then if playerLicenseProgress[player].practical_test_vehicle==vehicle then triggerEvent("drivelicense:finishPracticalTest",player,false,"Prüfungsfahrzeug zerstört")end end
    local instructorPed=getElementData(vehicle,"drivingInstructorPed"); if isElement(instructorPed)then destroyElement(instructorPed)end
end
addEventHandler("onVehicleExplode",root,handleTestVehicleDestroyed)
addEventHandler("onElementDestroy",root,function()if getElementType(source)=="vehicle"and getElementData(source,"isDrivingTestVehicle")then handleTestVehicleDestroyed()end end)

function givePlayerLicenseInternal(player, licenseTypeKey, licenseDisplayName)
    local accountId = getElementData(player, "account_id"); if not accountId then return false, "No account_id" end
    local deleteSuccess, delErrMsg = exports.datenbank:executeDatabase("DELETE FROM player_licenses WHERE account_id = ? AND license_type = ?", accountId, licenseTypeKey)
    if not deleteSuccess then outputDebugString("[DriveLicense] givePlayerLicenseInternal: DB Fehler (DELETE) für AccID "..accountId..", Lizenz "..licenseTypeKey..": ".. (delErrMsg or "Unbekannt")) end

    local insertSuccess, insErrMsg = exports.datenbank:executeDatabase("INSERT INTO player_licenses (account_id, license_type, issue_date, status, points) VALUES (?, ?, CURDATE(), 'active', 0)", accountId, licenseTypeKey)
    if insertSuccess then
        outputChatBox("Herzlichen Glückwunsch! Du hast den " .. licenseDisplayName .. " erhalten.", player, 0,220,50)
        local currentLicenses, _ = getPlayerLicenses(player) -- Fehlerbehandlung in getPlayerLicenses
        triggerClientEvent(player,"drivelicense:updateClientLicenses",player,currentLicenses)
        local DRIVERS_LICENSE_ITEM_ID = 18; local activeLicenseTypes = {}
        for _, lic in ipairs(currentLicenses) do if lic.status == 'active' then table.insert(activeLicenseTypes, lic.license_type) end end
        local licensesString = table.concat(activeLicenseTypes, ","); local metadata = { name=getPlayerName(player), licenses=licensesString, issuedDate=os.date("%d.%m.%Y") }; local metadataString=tableToMetadataString(metadata)

        local hasOldLicenseItem, _ = exports.tarox:hasPlayerItem(player,DRIVERS_LICENSE_ITEM_ID,1)
        if hasOldLicenseItem then
            local tookOld, _ = exports.tarox:takePlayerItemByID(player,DRIVERS_LICENSE_ITEM_ID,1)
            if not tookOld then outputDebugString("[DriveLicense] Fehler beim Entfernen des alten Führerschein-Items für AccID " .. accountId) end
        end
        local gaveNew, giveNewMsg = exports.tarox:givePlayerItem(player,DRIVERS_LICENSE_ITEM_ID,1,metadataString)
        if gaveNew then outputChatBox("Dein Führerschein-Dokument wurde aktualisiert.",player,0,200,100)
        else outputChatBox("Fehler beim Ausstellen des Führerschein-Dokuments: "..(giveNewMsg or "Unbekannt"), player, 255,0,0) end
        return true, "Success"
    else
        outputChatBox("Fehler beim Eintragen des Führerscheins: ".. (insErrMsg or "DB Fehler"), player, 255,0,0)
        return false, "Database error on insert"
    end
end
_G.givePlayerLicenseInternal = givePlayerLicenseInternal

function setPlayerLicenseStatus(player, licenseTypeKey, newStatus)
    local accountId = getElementData(player, "account_id"); if not accountId then return false, "No account_id" end
    local existingQueryResult, queryErrMsg = exports.datenbank:queryDatabase("SELECT status FROM player_licenses WHERE account_id = ? AND license_type = ?",accountId,licenseTypeKey);
    if not existingQueryResult then
        outputDebugString("[DriveLicense] setPlayerLicenseStatus: DB Fehler (SELECT) AccID "..accountId..", Lizenz "..licenseTypeKey..": ".. (queryErrMsg or "Unbekannt"))
        return false, "DB Select Error"
    end

    local success, execErrMsg
    if existingQueryResult and #existingQueryResult > 0 then
        success, execErrMsg = exports.datenbank:executeDatabase("UPDATE player_licenses SET status = ?, issue_date = IF(? = 'active' AND issue_date IS NULL, CURDATE(), issue_date) WHERE account_id = ? AND license_type = ?",newStatus,newStatus,accountId,licenseTypeKey)
    else
        success, execErrMsg = exports.datenbank:executeDatabase("INSERT INTO player_licenses (account_id, license_type, status, issue_date, points) VALUES (?, ?, ?, IF(? = 'active', CURDATE(), NULL), 0)",accountId,licenseTypeKey,newStatus,newStatus);
    end

    if success then
        local licenses, _ = getPlayerLicenses(player)
        triggerClientEvent(player,"drivelicense:updateClientLicenses",player,licenses)
        return true, "Success"
    else
        outputDebugString("[DriveLicense] setPlayerLicenseStatus: DB Fehler (UPDATE/INSERT) AccID "..accountId..", Lizenz "..licenseTypeKey..": ".. (execErrMsg or "Unbekannt"))
        return false, "DB Execute Error"
    end
end
_G.setPlayerLicenseStatus = setPlayerLicenseStatus

function hasPlayerLicense(player, licenseTypeKey)
    if not isElement(player) then return false end
    local licenses, errMsg = getPlayerLicenses(player)
    if errMsg then
        outputDebugString("[DriveLicense] hasPlayerLicense: Fehler beim Abrufen der Lizenzen für "..getPlayerName(player)..": "..errMsg)
        return false
    end
    for _, licData in ipairs(licenses) do
        if licData.license_type == licenseTypeKey and licData.status == "active" then return true end
    end
    return false
end
_G.hasPlayerLicense = hasPlayerLicense
exports.tarox.hasPlayerLicense = hasPlayerLicense -- KORRIGIERT: Punkt statt Doppelpunkt

function getPlayerLicenses(player)
    local accountId = getElementData(player, "account_id"); if not accountId then return {}, "No account_id" end
    local queryResult, errMsg = exports.datenbank:queryDatabase("SELECT license_type, status, issue_date, expiry_date, points FROM player_licenses WHERE account_id = ?", accountId)
    local licenses = {}
    if not queryResult then
        outputDebugString("[DriveLicense] getPlayerLicenses: DB Fehler für AccID "..accountId..": ".. (errMsg or "Unbekannt"))
        return licenses, "Database query error"
    end
    if queryResult then for _, row in ipairs(queryResult) do table.insert(licenses, {license_type=row.license_type,status=row.status,issue_date=row.issue_date,expiry_date=row.expiry_date,points=tonumber(row.points)or 0})end end
    return licenses, nil
end
_G.getPlayerLicenses = getPlayerLicenses
exports.tarox.getPlayerLicenses = getPlayerLicenses -- KORRIGIERT: Punkt statt Doppelpunkt

function givePlayerLicense(player, licenseTypeKey)
    if not isElement(player) then return false, "Invalid player" end; local lc = LICENSE_CONFIG[licenseTypeKey]; if not lc then return false, "Invalid license key" end;
    return givePlayerLicenseInternal(player, licenseTypeKey, lc.displayName)
end
exports.tarox.givePlayerLicense = givePlayerLicense -- KORRIGIERT: Punkt statt Doppelpunkt

function removePlayerLicense(player, licenseTypeKey)
    local accID = getElementData(player, "account_id"); if not accID then return false, "No account_id" end;
    local success, errMsg = exports.datenbank:executeDatabase("DELETE FROM player_licenses WHERE account_id = ? AND license_type = ?", accID, licenseTypeKey);
    if success then
        outputChatBox("Führerschein '"..(LICENSE_CONFIG[licenseTypeKey] and LICENSE_CONFIG[licenseTypeKey].displayName or licenseTypeKey).."' entzogen.", player, 200,0,0);
        local licenses, _ = getPlayerLicenses(player)
        triggerClientEvent(player, "drivelicense:updateClientLicenses", player, licenses)
        local DRIVERS_LICENSE_ITEM_ID_REM = 18
        local hasItem, _ = exports.tarox:hasPlayerItem(player, DRIVERS_LICENSE_ITEM_ID_REM, 1)
        if hasItem then
            local currentLicensesRem, _ = getPlayerLicenses(player); local activeLicenseTypesRem = {}
            for _, licRem in ipairs(currentLicensesRem) do if licRem.status == 'active' then table.insert(activeLicenseTypesRem, licRem.license_type) end end
            local tookOldItem, _ = exports.tarox:takePlayerItemByID(player, DRIVERS_LICENSE_ITEM_ID_REM, 1)
            if not tookOldItem then outputDebugString("[DriveLicense] Fehler beim Entfernen des alten Führerschein-Items nach Lizenzentzug für AccID " .. accID) end
            if #activeLicenseTypesRem > 0 then
                local licensesStringRem = table.concat(activeLicenseTypesRem, ","); local metadataRem = {name=getPlayerName(player),licenses=licensesStringRem,issuedDate=os.date("%d.%m.%Y")}; local metadataStringRem=tableToMetadataString(metadataRem);
                local gaveNewItem, _ = exports.tarox:givePlayerItem(player,DRIVERS_LICENSE_ITEM_ID_REM,1,metadataStringRem)
                if gaveNewItem then outputChatBox("Dein Führerschein-Dokument wurde aktualisiert.", player, 200,150,0)
                else outputChatBox("Fehler beim Aktualisieren des Führerschein-Dokuments.", player, 255,100,0) end
            else outputChatBox("Führerschein-Dokument entfernt, da keine aktiven Lizenzen mehr vorhanden.", player, 200,150,0) end
        end
        return true, "Success"
    else
        outputDebugString("[DriveLicense] removePlayerLicense: DB Fehler für AccID "..accID..", Lizenz "..licenseTypeKey..": ".. (errMsg or "Unbekannt"))
        return false, "DB Execute Error"
    end
end
exports.tarox.removePlayerLicense = removePlayerLicense -- KORRIGIERT: Punkt statt Doppelpunkt

addEventHandler("onPlayerQuit", root, function() if playerLicenseProgress[source] then if isElement(playerLicenseProgress[source].practical_test_vehicle)then destroyElement(playerLicenseProgress[source].practical_test_vehicle)end; if isElement(playerLicenseProgress[source].practical_test_instructor)then destroyElement(playerLicenseProgress[source].practical_test_instructor)end; playerLicenseProgress[source]=nil end end)
function checkVehicleLicenseOnEnter(player,seat,jacked) if seat==0 then local vehicle=source;local model=getElementModel(vehicle);local vehicleIsPlayersOwn=(getElementData(vehicle,"account_id")==getElementData(player,"account_id"));local vehicleIsTestVehicle=getElementData(vehicle,"isDrivingTestVehicle")==true and getElementData(vehicle,"driverSchoolPlayer")==player;if vehicleIsPlayersOwn or vehicleIsTestVehicle then return end;local requiredLicenseKey=nil;for licenseKey,configData in pairs(LICENSE_CONFIG)do if configData.allows_vehicle_models then for _,allowedModel in ipairs(configData.allows_vehicle_models)do if allowedModel==model then requiredLicenseKey=licenseKey;break end end end;if requiredLicenseKey then break end end;if requiredLicenseKey then if not hasPlayerLicense(player,requiredLicenseKey)then outputChatBox("Du hast nicht den erforderlichen Führerschein ("..(LICENSE_CONFIG[requiredLicenseKey].displayName or requiredLicenseKey)..") für dieses Fahrzeug!",player,255,0,0);removePedFromVehicle(player)end end end end
addEventHandler("onVehicleEnter", root, checkVehicleLicenseOnEnter)
addEvent("drivelicense:cancelTest", true); addEventHandler("drivelicense:cancelTest",root,function()local player=client;if not isElement(player)then return end;if playerLicenseProgress[player]then if playerLicenseProgress[player].stage=="theory_test"then outputChatBox("Theorieprüfung abgebrochen.",player,200,100,0)elseif playerLicenseProgress[player].stage=="practical_test"or playerLicenseProgress[player].stage=="awaiting_practical"then outputChatBox("Führerscheinprozess abgebrochen.",player,200,100,0);if isElement(playerLicenseProgress[player].practical_test_vehicle)then destroyElement(playerLicenseProgress[player].practical_test_vehicle)end;if isElement(playerLicenseProgress[player].practical_test_instructor)then destroyElement(playerLicenseProgress[player].practical_test_instructor)end;if isElement(player)then fadeCamera(player,false,0.2);setTimer(function()if isElement(player)then setElementPosition(player,FAHRSCHULE_SPAWN_POS_X,FAHRSCHULE_SPAWN_POS_Y,FAHRSCHULE_SPAWN_POS_Z);setElementRotation(player,0,0,FAHRSCHULE_SPAWN_ROTATION);setElementInterior(player,FAHRSCHULE_SPAWN_INTERIOR);setElementDimension(player,FAHRSCHULE_SPAWN_DIMENSION);fadeCamera(player,true,0.5)end end,250,1)end end;playerLicenseProgress[player]=nil;triggerClientEvent(player,"drivelicense:testCancelledClient",player)end end)
addEvent("drivelicense:testTrigger", true);addEventHandler("drivelicense:testTrigger",root,function(msg)end)
local SPEED_CHECK_INTERVAL=1000;local MAX_SPEED_ALLOWED=50;local MAX_SPEED_TOLERANCE=53;local SPEEDING_DURATION_THRESHOLD=3000
setTimer(function()for player,progress in pairs(playerLicenseProgress)do if isElement(player)and progress.stage=="practical_test"and isElement(progress.practical_test_vehicle)then local vx,vy,vz=getElementVelocity(progress.practical_test_vehicle);local currentSpeed=math.sqrt(vx^2+vy^2+vz^2)*180;if currentSpeed>MAX_SPEED_TOLERANCE then if progress.speeding_start_time==0 then progress.speeding_start_time=getTickCount();progress.speeding_warned=false else local speedingDuration=getTickCount()-progress.speeding_start_time;if speedingDuration>SPEEDING_DURATION_THRESHOLD then triggerEvent("drivelicense:finishPracticalTest",player,false,"Zu schnell gefahren (Prüfung abgebrochen).");break elseif speedingDuration>1000 and not progress.speeding_warned then outputChatBox("Fahrlehrer: Achtung, zu schnell!",player,255,100,0);progress.speeding_warned=true end end else progress.speeding_start_time=0;progress.speeding_warned=false end end end end,SPEED_CHECK_INTERVAL,0)

addEventHandler("onResourceStart", resourceRoot, function()
    local db_check = exports.datenbank:getConnection()
    if not db_check then
        outputDebugString("[DriveServer] FATALER FEHLER bei onResourceStart: Keine Datenbankverbindung!", 2)
        return
    end
    createDrivingSchoolTeleportMarkers()
    --outputDebugString("[DriveServer] Führerschein-System (Server V1.3 - Syntax Export Fix, DB Fehlerbehandlung) geladen.")
end)
addEventHandler("onResourceStop",resourceRoot,function()if isElement(drivingSchoolEntranceMarker)then destroyElement(drivingSchoolEntranceMarker);drivingSchoolEntranceMarker=nil end;if isElement(drivingSchoolExitMarker)then destroyElement(drivingSchoolExitMarker);drivingSchoolExitMarker=nil end;for player,progress in pairs(playerLicenseProgress)do if isElement(player)then if isElement(progress.practical_test_vehicle)then destroyElement(progress.practical_test_vehicle)end;if isElement(progress.practical_test_instructor)then destroyElement(progress.practical_test_instructor)end end end;playerLicenseProgress={};outputDebugString("[DriveServer] Fahrschul Teleport-Marker und Prüfungen beim Stoppen entfernt.")end)