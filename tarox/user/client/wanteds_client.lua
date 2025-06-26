-----------------------------------------------
-- wanteds_client.lua
-- Zeigt das Wanted-Freikauf-Fenster.
-----------------------------------------------

local showReleasePanel = false
local windowW, windowH = 350, 220 -- Etwas größer für mehr Infos
local wantedCount = 0
local cost = 0
local costPerWanted = 500 -- Preis pro Wanted-Punkt (sollte mit Server übereinstimmen)

local screenW, screenH = guiGetScreenSize()
-- KORRIGIERTE ZEILE HIER: sy wurde zu screenH geändert
local posX, posY = (screenW - windowW)/2, (screenH - windowH)/2

-- Variable für den Render-Handler
local isWantedReleaseRenderActive = false

---------------------------------------------------------
-- Event vom Server: Freikauf-Fenster öffnen
---------------------------------------------------------
addEvent("onWantedReleaseOpen", true)
addEventHandler("onWantedReleaseOpen", root, function()
    if showReleasePanel then return end -- Nicht doppelt öffnen

    -- Aktuelle Wanteds vom Spieler holen (zuverlässiger als vom Server zu senden)
    wantedCount = getElementData(localPlayer, "wanted") or 0

    -- Erneute Prüfung, falls Event getriggert wird, obwohl keine Wanteds da sind
    if wantedCount <= 0 then
         outputChatBox("Du hast keine Wanteds zum Freikaufen.", 255, 165, 0)
         return
    end
    -- Prüfung auf > 49 Wanteds
    if wantedCount > 49 then
         outputChatBox("❌ Freikauf ist nur bis 49 Wanteds möglich!", 255, 0, 0)
         return
    end

    cost = wantedCount * costPerWanted
    showReleasePanel = true
    showCursor(true)

    -- Render-Handler nur hinzufügen, wenn er noch nicht läuft
    if not isWantedReleaseRenderActive then
         addEventHandler("onClientRender", root, renderWantedReleasePanel)
         isWantedReleaseRenderActive = true
    end
    --outputDebugString("[WantedsGUI] Freikauf-Fenster geöffnet.")
end)

---------------------------------------------------------
-- Event vom Server: Freikauf-Fenster schließen (z.B. bei Erfolg oder Verlassen des Pickups)
---------------------------------------------------------
addEvent("onWantedReleaseClose", true)
addEventHandler("onWantedReleaseClose", root, function()
    closeWantedReleasePanel()
end)


---------------------------------------------------------
-- DX-Fenster rendern
---------------------------------------------------------
function renderWantedReleasePanel()
    -- Rendert nur, wenn showReleasePanel true ist
    if not showReleasePanel then return end -- Füge diese Prüfung hinzu

    -- Hintergrund und Titel
    dxDrawRectangle(posX, posY, windowW, windowH, tocolor(0, 0, 0, 190))
    dxDrawRectangle(posX, posY, windowW, 35, tocolor(50, 0, 0, 210)) -- Dunkelroter Titelbalken
    dxDrawText("Wanted Level Clearance", posX, posY, posX+windowW, posY+35, tocolor(255, 255, 255), 1.3, "default-bold", "center", "center")

    local lineY = posY + 50
    local textX = posX + 20
    local textW = windowW - 40

    -- Info-Text
    dxDrawText("You currently have:", textX, lineY, textX + textW, lineY + 20, tocolor(200, 200, 200), 1.1, "default", "left", "top")
    dxDrawText(wantedCount .. " Wanted Level(s)", textX, lineY, textX + textW, lineY + 20, tocolor(255, 200, 0), 1.1, "default-bold", "right", "top")
    lineY = lineY + 30

    dxDrawText("Cost to clear your record:", textX, lineY, textX + textW, lineY + 20, tocolor(200, 200, 200), 1.1, "default", "left", "top")
    dxDrawText("$" .. cost, textX, lineY, textX + textW, lineY + 20, tocolor(0, 255, 0), 1.1, "default-bold", "right", "top")
    lineY = lineY + 40

    -- Buttons
    local btnW, btnH = (windowW - 50) / 2, 40 -- Zwei Buttons nebeneinander
    local btnY = lineY + 10
    local btnX1 = posX + 15
    local btnX2 = btnX1 + btnW + 20

    -- Pay/Clear Button
    dxDrawRectangle(btnX1, btnY, btnW, btnH, tocolor(0, 150, 50, 220))
    dxDrawText("Pay & Clear", btnX1, btnY, btnX1 + btnW, btnY + btnH, tocolor(255, 255, 255), 1.1, "default-bold", "center", "center")

    -- Cancel Button
    dxDrawRectangle(btnX2, btnY, btnW, btnH, tocolor(200, 50, 50, 220))
    dxDrawText("Cancel", btnX2, btnY, btnX2 + btnW, btnY + btnH, tocolor(255, 255, 255), 1.1, "default-bold", "center", "center")
end

---------------------------------------------------------
-- Klick-Handling
---------------------------------------------------------
addEventHandler("onClientClick", root, function(button, state, absX, absY)
    if not showReleasePanel or button ~= "left" or state ~= "up" then return end

    local btnW, btnH = (windowW - 50) / 2, 40
    -- Berechne die Y-Position der Buttons basierend auf der lineY im Render-Teil
    local buttonBaseY = posY + 50 + 30 + 40 -- Y-Position nach dem letzten Text
    local btnY = buttonBaseY + 10
    local btnX1 = posX + 15
    local btnX2 = btnX1 + btnW + 20

    -- Pay/Clear Button geklickt?
    if absX >= btnX1 and absX <= btnX1 + btnW and absY >= btnY and absY <= btnY + btnH then
        --outputDebugString("[WantedsGUI] Sende 'Pay' Request an Server.")
        triggerServerEvent("wantedReleasePay", localPlayer)
        -- Schließen passiert durch Server-Event "onWantedReleaseClose" bei Erfolg/Fehler
    -- Cancel Button geklickt?
    elseif absX >= btnX2 and absX <= btnX2 + btnW and absY >= btnY and absY <= btnY + btnH then
         closeWantedReleasePanel()
    end
end)

---------------------------------------------------------
-- Funktion zum Schließen und Aufräumen
---------------------------------------------------------
function closeWantedReleasePanel()
    if not showReleasePanel then return end
    showReleasePanel = false
    showCursor(false)
    if isWantedReleaseRenderActive then
         removeEventHandler("onClientRender", root, renderWantedReleasePanel)
         isWantedReleaseRenderActive = false
    end
    --outputDebugString("[WantedsGUI] Freikauf-Fenster geschlossen.")
end

---------------------------------------------------------
-- Optional: Wanted Level im HUD anzeigen oder aktualisieren
---------------------------------------------------------
addEvent("updateWantedLevelDisplay", true)
addEventHandler("updateWantedLevelDisplay", root, function(newLevel)
     -- Hier könntest du z.B. eine DX-Anzeige für Wanteds aktualisieren
     -- oder einfach eine Chatnachricht ausgeben (wird oft schon serverseitig gemacht)
     -- outputChatBox("Dein Wanted Level ist jetzt: " .. newLevel, 0, 200, 255)
     -- Wenn das Freikauf-Fenster offen ist, aktualisiere die Anzeige dort
     if showReleasePanel then
         wantedCount = newLevel
         if wantedCount <= 0 or wantedCount > 49 then
             -- Automatisch schließen wenn nicht mehr möglich/nötig
             closeWantedReleasePanel()
         else
             cost = wantedCount * costPerWanted
         end
     end
end)


-- Aufräumen beim Beenden
addEventHandler("onClientPlayerQuit", localPlayer, closeWantedReleasePanel)
addEventHandler("onClientResourceStop", resourceRoot, closeWantedReleasePanel)

--outputDebugString("[WantedsGUI] Wanted Release GUI (Client) geladen.")