-- tarox/fraktionen/medic_client.lua
-- Version mit Revive-System UI-Elementen UND neuem Patientenlisten-System
-- KORRIGIERT: guiGetScreenSize Fehlerbehebung

-- local screenW, screenH = guiGetScreenSize() -- NICHT HIER DEFINIEREN
local localPlayer = getLocalPlayer()

-- Globale Variablen für Bildschirmgröße (werden später initialisiert)
local screenW, screenH

-- Medic Hauptfenster
local windowWidth, windowHeight -- Initialisierung später
local windowX, windowY -- Initialisierung später
local isMedicWindowVisible = false
local medicRank = 0
local playerWantedLevel = 0
local buttons = {}
local headerColor = {0, 150, 220, 220}
local buttonBaseColor = {50, 50, 70, 220}
local buttonDisabledColor = {100, 100, 110, 180}
local buttonHoverColor = {70, 70, 90, 230}
local buttonTextColor = {240, 240, 240, 255}
local buttonDisabledTextColor = {170, 170, 170, 200}

-- Für Revive Timer Anzeige
local isReviveTimerActive = false
local reviveTimerEndTime = 0
local REVIVE_ANIM_DURATION_CLIENT = 5000
local reviveBarColor = {0, 200, 100, 200}

-- Für "Player Down" Blips
local playerDownBlips = {}
local BLIP_DURATION = (2 * 60 * 1000) + (30 * 1000)

-- NEU: Für Patientenliste
local isPatientListVisible = false
local lowHealthPlayersList = {}
local selectedPatientIndex = nil
local patientScrollOffset = 0
local maxVisiblePatients = 10
local patientBlipTimers = {}

local patientListGuiWidth, patientListGuiHeight -- Initialisierung später
local patientListGuiX, patientListGuiY -- Initialisierung später

local COLOR_PATIENT_BG = {25, 28, 36, 220}
local COLOR_PATIENT_HEADER_BG = {0, 110, 160, 230}
local COLOR_PATIENT_TEXT_HEADER = {230, 230, 240, 255}
local COLOR_PATIENT_ROW_TEXT = {210, 215, 225, 255}
local COLOR_PATIENT_HEALTH_GOOD = {70, 210, 70, 255}
local COLOR_PATIENT_HEALTH_MEDIUM = {210, 210, 70, 255}
local COLOR_PATIENT_HEALTH_BAD = {210, 70, 70, 255}
local COLOR_PATIENT_SELECTED_BG = {0, 132, 194, 200}
local COLOR_PATIENT_BUTTON_BG = {60, 120, 180, 220}
local COLOR_PATIENT_BUTTON_HOVER = {80, 140, 200, 230}
local COLOR_PATIENT_BUTTON_TEXT = {240, 240, 245, 255}
-- Ende NEU Patientenliste Variablen

-- Funktion zur Initialisierung von GUI-Dimensionen
local function initializeGUIDimensions()
    screenW, screenH = guiGetScreenSize()

    windowWidth, windowHeight = 380, 230
    windowX, windowY = (screenW - windowWidth) / 2, (screenH - windowHeight) / 2

    patientListGuiWidth, patientListGuiHeight = 350, 400
    patientListGuiX, patientListGuiY = (screenW - patientListGuiWidth) / 2, (screenH - patientListGuiHeight) / 2
end

-- Rufe initializeGUIDimensions auf, sobald die Ressource clientseitig startet
addEventHandler("onClientResourceStart", resourceRoot, function()
    initializeGUIDimensions()
    --outpudDebugString("[MedicClient] Medic Client Skript (V9 - guiGetScreenSize Fix) geladen.")
end)


local function renderMedicWindow()
    if not isMedicWindowVisible then return end
    -- Stelle sicher, dass Dimensionen initialisiert sind (Fallback)
    if not windowX then initializeGUIDimensions() end

    dxDrawRectangle(windowX, windowY, windowWidth, windowHeight, tocolor(30, 30, 35, 230))
    dxDrawRectangle(windowX, windowY, windowWidth, 40, tocolor(unpack(headerColor)))
    dxDrawText("Medic Department (Rang: " .. medicRank .. ")", windowX, windowY, windowX + windowWidth, windowY + 40, tocolor(255, 255, 255), 1.3, "default-bold", "center", "center")
    local cX, cY = getCursorPosition(); local mX, mY; if cX then mX, mY = cX * screenW, cY * screenH end
    for id, btn in pairs(buttons) do
        local currentBgColorTable = buttonBaseColor; local currentTextColorTable = buttonTextColor; local isButtonDisabled = false
        if id == "onduty" and playerWantedLevel > 0 then currentBgColorTable=buttonDisabledColor; currentTextColorTable=buttonDisabledTextColor; isButtonDisabled=true
        elseif id == "close" then currentBgColorTable = {180,50,50,220} end
        dxDrawRectangle(btn.x,btn.y,btn.w,btn.h,tocolor(unpack(currentBgColorTable)))
        dxDrawText(btn.text,btn.x,btn.y,btn.x+btn.w,btn.y+btn.h,tocolor(unpack(currentTextColorTable)),1.1,"default-bold","center","center")
        if not isButtonDisabled and mX and mY and mX>=btn.x and mX<=btn.x+btn.w and mY>=btn.y and mY<=btn.y+btn.h then
            local hoverColTable=(id=="close")and{200,70,70,230}or buttonHoverColor
            dxDrawRectangle(btn.x,btn.y,btn.w,btn.h,tocolor(unpack(hoverColTable)))
            dxDrawText(btn.text,btn.x,btn.y,btn.x+btn.w,btn.y+btn.h,tocolor(unpack(buttonTextColor)),1.1,"default-bold","center","center")
        end
    end
end

function renderReviveTimer()
    if not isReviveTimerActive then return end
    if not screenW then initializeGUIDimensions() end -- Fallback

    local remainingMs = reviveTimerEndTime - getTickCount()
    if remainingMs <= 0 then
        isReviveTimerActive = false
        return
    end
    local progress = 1 - (remainingMs / REVIVE_ANIM_DURATION_CLIENT)
    local barW, barH = 250, 22
    local barX = (screenW - barW) / 2
    local barY = screenH * 0.85

    dxDrawRectangle(barX - 2, barY - 2, barW + 4, barH + 4, tocolor(10,10,10,200))
    dxDrawRectangle(barX, barY, barW, barH, tocolor(50,50,50,220))
    dxDrawRectangle(barX, barY, barW * progress, barH, tocolor(unpack(reviveBarColor)))
    dxDrawText(string.format("Wiederbelebung läuft... %.1fs", remainingMs / 1000), barX, barY, barX + barW, barY + barH, tocolor(255,255,255), 1.0, "default-bold", "center", "center")
end
addEventHandler("onClientRender", root, renderReviveTimer)

function openMedicWindowPanel(rank, wantedLvl)
    if isMedicWindowVisible or isPatientListVisible then return end
    if not windowX then initializeGUIDimensions() end -- Wichtig

    isMedicWindowVisible = true; medicRank = rank or 0; playerWantedLevel = wantedLvl or 0
    buttons = {}
    local currentY = windowY + 55; local buttonW_panel, buttonH_panel = windowWidth - 40, 40; local buttonSpacing_panel = 10
    buttons["onduty"] = { x=windowX+20,y=currentY,w=buttonW_panel,h=buttonH_panel,text="Im Dienst anmelden" }; currentY=currentY+buttonH_panel+buttonSpacing_panel
    buttons["offduty"] = { x=windowX+20,y=currentY,w=buttonW_panel,h=buttonH_panel,text="Dienst vorerst verlassen" }
    buttons["close"] = { x=windowX+20,y=windowY+windowHeight-buttonH_panel-15,w=buttonW_panel,h=buttonH_panel,text="Schließen" }
    showCursor(true); guiSetInputMode("no_binds_when_editing"); addEventHandler("onClientRender",root,renderMedicWindow)
end

function closeMedicWindowPanel()
    if not isMedicWindowVisible then return end
    isMedicWindowVisible = false;
    if not isPatientListVisible then
        showCursor(false);
        guiSetInputMode("allow_binds")
    end
    removeEventHandler("onClientRender",root,renderMedicWindow); buttons = {}
end

addEvent("openMedicWindow", true)
addEventHandler("openMedicWindow", root, openMedicWindowPanel)

addEventHandler("onClientClick", root, function(button, state, absX, absY)
    if button ~= "left" or state ~= "up" then return end
    if not screenW then return end -- Verhindere Klicks, wenn GUI nicht initialisiert

    if isMedicWindowVisible then
        for id, btnData in pairs(buttons) do
            if absX >= btnData.x and absX <= btnData.x + btnData.w and absY >= btnData.y and absY <= btnData.y + btnData.h then
                if id == "onduty" then if playerWantedLevel > 0 then outputChatBox("Du kannst mit Wanteds nicht in den Dienst gehen!",255,0,0) else triggerServerEvent("onMedicRequestSpawn", localPlayer); closeMedicWindowPanel() end
                elseif id == "offduty" then triggerServerEvent("onMedicRequestOffDuty", localPlayer); closeMedicWindowPanel()
                elseif id == "close" then closeMedicWindowPanel() end
                playSoundFrontEnd(40); return
            end
        end
    elseif isPatientListVisible then
        if not patientListGuiX then initializeGUIDimensions() end -- Fallback für Klick

        local listStartY_click = patientListGuiY + 45
        local rowH_click = 30
        local spacing_click = 4

        for i = 1, maxVisiblePatients do
            local index = i + patientScrollOffset
            if lowHealthPlayersList[index] then
                local currentY_click = listStartY_click + (i - 1) * (rowH_click + spacing_click)
                if absX >= patientListGuiX + 10 and absX <= patientListGuiX + patientListGuiWidth - 20 and
                   absY >= currentY_click and absY <= currentY_click + rowH_click then
                    selectedPatientIndex = index
                    return
                end
            end
        end

        local btnAreaY_click = patientListGuiY + patientListGuiHeight - 55
        local btnH_action_click = 40
        local btnW_locate_click = patientListGuiWidth * 0.5 - 15
        local btnW_close_click = patientListGuiWidth * 0.5 - 15
        local btnX_locate_click = patientListGuiX + 10
        local btnX_close_click = patientListGuiX + patientListGuiWidth - btnW_close_click - 10

        if absX >= btnX_locate_click and absX <= btnX_locate_click + btnW_locate_click and
           absY >= btnAreaY_click and absY <= btnAreaY_click + btnH_action_click then
            if selectedPatientIndex and lowHealthPlayersList[selectedPatientIndex] then
                local targetPlayerData = lowHealthPlayersList[selectedPatientIndex]
                if targetPlayerData.source then
                    triggerServerEvent("medic:requestPlayerLocate", localPlayer, targetPlayerData.source)
                else outputChatBox("Fehler: Spielerdaten für Ortung ungültig.", 255, 100, 0) end
            else outputChatBox("Bitte wähle zuerst einen Spieler aus der Liste.", 255, 165, 0) end
            return
        end

        if absX >= btnX_close_click and absX <= btnX_close_click + btnW_close_click and
           absY >= btnAreaY_click and absY <= btnAreaY_click + btnH_action_click then
            closePatientListGUI()
            return
        end
    end
end)

addEventHandler("onClientKey", root, function(key, press)
    if key == "escape" and press then
        if isMedicWindowVisible then closeMedicWindowPanel(); cancelEvent() -- cancelEvent um weitere Escape-Handler zu blocken
        elseif isPatientListVisible then closePatientListGUI(); cancelEvent()
        end
    end
end)

addEventHandler("onClientElementDataChange", localPlayer, function(dataName)
    if isMedicWindowVisible and dataName == "wanted" then
        playerWantedLevel = getElementData(localPlayer, "wanted") or 0
    end
end)

addEvent("medic:startReviveTimerClient", true)
addEventHandler("medic:startReviveTimerClient", root, function(duration)
    isReviveTimerActive = true
    REVIVE_ANIM_DURATION_CLIENT = duration
    reviveTimerEndTime = getTickCount() + duration
end)

addEvent("medic:stopReviveTimerClient", true)
addEventHandler("medic:stopReviveTimerClient", root, function()
    isReviveTimerActive = false
end)

addEvent("medic:playerDownNotificationClient", true)
addEventHandler("medic:playerDownNotificationClient", root, function(victimElement, victimName, x, y, z)
    if not isElement(victimElement) then return end
    if playerDownBlips[victimElement] and isElement(playerDownBlips[victimElement]) then
        destroyElement(playerDownBlips[victimElement])
    end
    local blip = createBlip(x, y, z, 16, 2, 255, 0, 0, 200, 0, 300)
    if isElement(blip) then
        playerDownBlips[victimElement] = blip
        setTimer(function(b, victim)
            if isElement(b) then destroyElement(b) end
            if playerDownBlips[victim] == b then playerDownBlips[victim] = nil end
        end, BLIP_DURATION, 1, blip, victimElement)
    end
end)

addEvent("medic:playerCaseClosedClient", true)
addEventHandler("medic:playerCaseClosedClient", root, function(victimElement, victimName)
    if playerDownBlips[victimElement] and isElement(playerDownBlips[victimElement]) then
        destroyElement(playerDownBlips[victimElement])
        playerDownBlips[victimElement] = nil
    end
end)

addEvent("showWaitForMedicScreenClient", true)
addEventHandler("showWaitForMedicScreenClient", root, function(killerName, weaponName, duration)
end)

function isPlayerEligibleForPatientList()
    local playerFactionID = getElementData(localPlayer, "group")
    local onDuty = getElementData(localPlayer, "medicImDienst") or false
    local vehicle = getPedOccupiedVehicle(localPlayer)
    local isMedicVehicle = false
    if vehicle then
        if getElementData(vehicle, "fraction") == 3 then
             isMedicVehicle = true
        end
    end
    return playerFactionID == "Medic" and onDuty and isMedicVehicle
end

function handleOpenPatientListKey(key, state)
    if key == "k" and state == "down" then
        if not isPlayerEligibleForPatientList() then
            return
        end
        if isPatientListVisible then
            closePatientListGUI()
        elseif not isMedicWindowVisible then -- Verhindere Öffnen, wenn Haupt-Medic-Fenster offen ist
            triggerServerEvent("medic:requestLowHealthPlayers", localPlayer)
        end
    end
end
bindKey("k", "down", handleOpenPatientListKey)

addEvent("medic:receiveLowHealthPlayers", true)
addEventHandler("medic:receiveLowHealthPlayers", root, function(playersTable)
    if not patientListGuiX then initializeGUIDimensions() end -- Wichtig

    if not isPatientListVisible then
        isPatientListVisible = true
        if not isCursorShowing() then showCursor(true) end
        guiSetInputMode("no_binds_when_editing")
        addEventHandler("onClientRender", root, renderPatientListGUI)
        bindKey("mouse_wheel_up", "down", scrollPatientListUp) -- Kein "Scrollt..." Text nötig
        bindKey("mouse_wheel_down", "down", scrollPatientListDown)
    end
    lowHealthPlayersList = playersTable or {}
    table.sort(lowHealthPlayersList, function(a,b) return (a.health or 100) < (b.health or 100) end)
    selectedPatientIndex = nil
    patientScrollOffset = 0
end)

function renderPatientListGUI()
    if not isPatientListVisible then return end
    if not patientListGuiX then initializeGUIDimensions() end -- Fallback

    dxDrawRectangle(patientListGuiX, patientListGuiY, patientListGuiWidth, patientListGuiHeight, tocolor(unpack(COLOR_PATIENT_BG)))
    dxDrawRectangle(patientListGuiX, patientListGuiY, patientListGuiWidth, 35, tocolor(unpack(COLOR_PATIENT_HEADER_BG)))
    dxDrawText("Patientenliste (<100% HP)", patientListGuiX, patientListGuiY, patientListGuiX + patientListGuiWidth, patientListGuiY + 35,
        tocolor(unpack(COLOR_PATIENT_TEXT_HEADER)), 1.3, "default-bold", "center", "center")

    local listStartY = patientListGuiY + 45
    local listRenderHeight = patientListGuiHeight - 110
    local rowH = 30
    local spacing = 4
    local colNameWidth = patientListGuiWidth * 0.60 - 15 -- Anpassung der Breite
    local colHealthWidth = patientListGuiWidth * 0.40 - 15 -- Anpassung der Breite

    if #lowHealthPlayersList == 0 then
        dxDrawText("Keine Patienten mit niedriger Gesundheit gefunden.", patientListGuiX + 10, listStartY + 20, patientListGuiX + patientListGuiWidth - 10, listStartY + 50,
            tocolor(unpack(COLOR_PATIENT_ROW_TEXT)), 1.0, "default", "center", "center", true)
    end

    for i = 1, maxVisiblePatients do
        local index = i + patientScrollOffset
        if lowHealthPlayersList[index] then
            local data = lowHealthPlayersList[index]
            local currentY = listStartY + (i - 1) * (rowH + spacing)
            local bgColorValues = (index == selectedPatientIndex) and COLOR_PATIENT_SELECTED_BG or {50, 55, 65, 180}

            dxDrawRectangle(patientListGuiX + 10, currentY, patientListGuiWidth - 20, rowH, tocolor(unpack(bgColorValues)))
            dxDrawText(data.name or "Unbekannt", patientListGuiX + 15, currentY, patientListGuiX + 15 + colNameWidth, currentY + rowH,
                tocolor(unpack(COLOR_PATIENT_ROW_TEXT)), 1.0, "default", "left", "center", true)

            local healthText = string.format("%.0f%%", data.health or 0)
            local healthColorValues = COLOR_PATIENT_HEALTH_GOOD
            if data.health < 70 then healthColorValues = COLOR_PATIENT_HEALTH_MEDIUM end
            if data.health < 30 then healthColorValues = COLOR_PATIENT_HEALTH_BAD end
            dxDrawText(healthText, patientListGuiX + 15 + colNameWidth + 5, currentY, patientListGuiX + patientListGuiWidth - 15, currentY + rowH,
                tocolor(unpack(healthColorValues)), 1.0, "default-bold", "right", "center")
        end
    end

    if #lowHealthPlayersList > maxVisiblePatients then
        local scrollbarX = patientListGuiX + patientListGuiWidth - 12 - 5
        local scrollbarWidth = 8
        dxDrawRectangle(scrollbarX, listStartY, scrollbarWidth, listRenderHeight, tocolor(0,0,0,100))
        local thumbH = math.max(15, listRenderHeight * (maxVisiblePatients / #lowHealthPlayersList))
        local thumbY = listStartY + (listRenderHeight - thumbH) * (patientScrollOffset / math.max(1, #lowHealthPlayersList - maxVisiblePatients))
        dxDrawRectangle(scrollbarX, thumbY, scrollbarWidth, thumbH, tocolor(150,150,150,150))
    end

    local btnAreaY = patientListGuiY + patientListGuiHeight - 55
    local btnH_action = 40
    local btnW_locate = patientListGuiWidth * 0.5 - 15
    local btnW_close = patientListGuiWidth * 0.5 - 15
    local btnX_locate = patientListGuiX + 10
    local btnX_close = patientListGuiX + patientListGuiWidth - btnW_close - 10

    local locateColorValues = (selectedPatientIndex and lowHealthPlayersList[selectedPatientIndex]) and COLOR_PATIENT_BUTTON_BG or {80, 80, 90, 150}
    local locateTextColorValues = (selectedPatientIndex and lowHealthPlayersList[selectedPatientIndex]) and COLOR_PATIENT_BUTTON_TEXT or {180,180,180,200}

    dxDrawRectangle(btnX_locate, btnAreaY, btnW_locate, btnH_action, tocolor(unpack(locateColorValues)))
    dxDrawText("Spieler Orten (30s)", btnX_locate, btnAreaY, btnX_locate + btnW_locate, btnAreaY + btnH_action, tocolor(unpack(locateTextColorValues)), 1.0, "default-bold", "center", "center")

    dxDrawRectangle(btnX_close, btnAreaY, btnW_close, btnH_action, tocolor(180,60,60,220))
    dxDrawText("Schließen", btnX_close, btnAreaY, btnX_close + btnW_close, btnAreaY + btnH_action, tocolor(unpack(COLOR_PATIENT_BUTTON_TEXT)), 1.0, "default-bold", "center", "center")

    local mX, mY = getCursorPosition()
    if mX then mX = mX * screenW; mY = mY * screenH
        if mX >= btnX_locate and mX <= btnX_locate + btnW_locate and mY >= btnAreaY and mY <= btnAreaY + btnH_action and (selectedPatientIndex and lowHealthPlayersList[selectedPatientIndex]) then
            dxDrawRectangle(btnX_locate, btnAreaY, btnW_locate, btnH_action, tocolor(unpack(COLOR_PATIENT_BUTTON_HOVER)))
            dxDrawText("Spieler Orten (30s)", btnX_locate, btnAreaY, btnX_locate + btnW_locate, btnAreaY + btnH_action, tocolor(unpack(COLOR_PATIENT_BUTTON_TEXT)), 1.0, "default-bold", "center", "center")
        end
        if mX >= btnX_close and mX <= btnX_close + btnW_close and mY >= btnAreaY and mY <= btnAreaY + btnH_action then
             dxDrawRectangle(btnX_close, btnAreaY, btnW_close, btnH_action, tocolor(200,80,80,230))
             dxDrawText("Schließen", btnX_close, btnAreaY, btnX_close + btnW_close, btnAreaY + btnH_action, tocolor(unpack(COLOR_PATIENT_BUTTON_TEXT)), 1.0, "default-bold", "center", "center")
        end
    end
end

function closePatientListGUI()
    if not isPatientListVisible then return end
    isPatientListVisible = false
    removeEventHandler("onClientRender", root, renderPatientListGUI)
    unbindKey("mouse_wheel_up", "down", scrollPatientListUp)
    unbindKey("mouse_wheel_down", "down", scrollPatientListDown)
    -- unbindKey("escape", "down", closePatientListGUIByKey) -- Wird durch globalen Handler abgedeckt

    if not isMedicWindowVisible then
        showCursor(false)
        guiSetInputMode("allow_binds")
    end
    lowHealthPlayersList = {}
    selectedPatientIndex = nil
end

function scrollPatientListUp()
    if not isPatientListVisible or #lowHealthPlayersList <= maxVisiblePatients then return end
    patientScrollOffset = math.max(0, patientScrollOffset - 1)
end

function scrollPatientListDown()
    if not isPatientListVisible or #lowHealthPlayersList <= maxVisiblePatients then return end
    patientScrollOffset = math.min(math.max(0, #lowHealthPlayersList - maxVisiblePatients), patientScrollOffset + 1)
end

addEvent("medic:showPatientBlip", true)
addEventHandler("medic:showPatientBlip", root, function(targetPlayerToBlip, duration)
    if not isElement(targetPlayerToBlip) then return end
    local oldBlipTimer = patientBlipTimers[targetPlayerToBlip]
    if isTimer(oldBlipTimer) then
        killTimer(oldBlipTimer)
        local oldBlip = getElementData(targetPlayerToBlip, "medicPatientLocationBlip")
        if isElement(oldBlip) then destroyElement(oldBlip) end
    end

    local blip = createBlipAttachedTo(targetPlayerToBlip, 0, 2, 0, 255, 0, 200, 0, 99999.0)
    if isElement(blip) then
        setElementData(targetPlayerToBlip, "medicPatientLocationBlip", blip)
        patientBlipTimers[targetPlayerToBlip] = setTimer(function(b, pKey)
            if isElement(b) then destroyElement(b) end
            if isElement(pKey) then removeElementData(pKey, "medicPatientLocationBlip") end
            patientBlipTimers[pKey] = nil
        end, duration, 1, blip, targetPlayerToBlip)
    end
end)

addEvent("medic:showPatientBlip", true)
addEventHandler("medic:showPatientBlip", root, function(targetPlayerToBlip, duration)
    if not isElement(targetPlayerToBlip) then return end
    local oldBlipTimer = patientBlipTimers[targetPlayerToBlip] -- Korrekter Zugriff auf die Tabelle
    if isTimer(oldBlipTimer) then
        killTimer(oldBlipTimer)
        local oldBlip = getElementData(targetPlayerToBlip, "medicPatientLocationBlip")
        if isElement(oldBlip) then destroyElement(oldBlip) end
        -- Hier KEIN removeElementData, da es serverseitig ist und der Fehler hier nicht lag
    end

    local blip = createBlipAttachedTo(targetPlayerToBlip, 0, 2, 0, 255, 0, 200, 0, 99999.0)
    if isElement(blip) then
        setElementData(targetPlayerToBlip, "medicPatientLocationBlip", blip) -- Clientseitiges Speichern der Blip-Referenz
        patientBlipTimers[targetPlayerToBlip] = setTimer(function(b, pKey) -- b ist der Blip, pKey ist targetPlayerToBlip
            -- Diese Funktion wird nach 'duration' ausgeführt
            if isElement(b) then
                destroyElement(b) -- Blip zerstören
            end
            if isElement(pKey) then
                -- Die nächste Zeile war der Übeltäter in der Annahme,
                -- dass 'removeElementData' clientseitig global verfügbar ist.
                -- removeElementData(pKey, "medicPatientLocationBlip") -- << FEHLERQUELLE, wenn Zeile 424 hier war

                -- KORREKTUR: Da "medicPatientLocationBlip" nur eine clientseitige Referenz ist,
                -- die mit setElementData(..., ..., ..., false) (oder ohne den letzten Parameter) gesetzt wird,
                -- können wir sie auch clientseitig mit setElementData auf nil setzen, um sie "zu entfernen".
                -- Aber noch besser: Da der Blip eh zerstört wird, ist das Setzen auf nil nicht zwingend nötig,
                -- solange wir beim nächsten Orten desselben Spielers den alten Blip korrekt behandeln (was wir tun).
                -- Wir entfernen hier einfach nur die Referenz aus unserer Timer-Verwaltung.
                if getElementData(pKey, "medicPatientLocationBlip") == b then -- Nur entfernen, wenn es noch der gleiche Blip ist
                    setElementData(pKey, "medicPatientLocationBlip", nil) -- Clientseitiges "Entfernen" der Referenz
                end
            end
            patientBlipTimers[pKey] = nil -- Timer aus der Verwaltung entfernen
        end, duration, 1, blip, targetPlayerToBlip) -- Blip und targetPlayerToBlip als Argumente übergeben
    end
end)

-- Output Debug wurde in onClientResourceStart verschoben