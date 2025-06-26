-- tarox/user/server/userpanel_server.lua
-- Logik für das /self Userpanel.
-- Fügt Wanted-Level zur Anzeige hinzu.
-- ANGEPASST V1.1: Verbesserte Fehlerbehandlung für Datenbankaufrufe

-- db-Variable wird nicht mehr global benötigt, da sie bei Bedarf geholt wird.

-- Funktion, um Spielerstatistiken zu sammeln und an den Client zu senden
function getPlayerStatistics(player)
    if not isElement(player) then return end
    local accID = getElementData(player, "account_id")
    if not accID then
        outputDebugString("[USERPANEL] ⚠ Error: No account_id for "..getPlayerName(player))
        triggerClientEvent(player, "showMessage", player, "Error: Account data not loaded!", 255, 0, 0)
        return
    end

    -- Geld und Spielzeit abfragen
    local statsResult, errMsgStats = exports.datenbank:queryDatabase([[
        SELECT m.money, COALESCE(pt.total_minutes, 0) AS total_minutes
        FROM money m
        LEFT JOIN playtime pt ON m.account_id = pt.account_id
        WHERE m.account_id=? LIMIT 1
    ]], accID)

    local moneyValue = 0
    local playtimeValue = 0
    local formattedPlaytime = "00:00"
    local factionName = getElementData(player, "group") or "Civil"
    local wantedLevel = getElementData(player, "wanted") or 0

    if not statsResult then
        outputDebugString("[USERPANEL] ⚠ DB-Fehler beim Laden von Geld/Spielzeit für AccID " .. accID .. ": " .. (errMsgStats or "Unbekannt"))
        -- Standardwerte beibehalten, aber Fehler loggen. Man könnte hier auch den Vorgang abbrechen.
    elseif statsResult and statsResult[1] then
        moneyValue = tonumber(statsResult[1].money) or 0
        playtimeValue = tonumber(statsResult[1].total_minutes) or 0
        local hours = math.floor(playtimeValue / 60)
        local minutes = playtimeValue % 60
        formattedPlaytime = string.format("%02d:%02d", hours, minutes)
    else
        outputDebugString("[USERPANEL] ⚠ Error: No money/playtime data found for accID="..accID)
    end

    -- Fahrzeuge abfragen
    local vehicleResult, errMsgVehicles = exports.datenbank:queryDatabase("SELECT id, model, health, fuel FROM vehicles WHERE account_id=?", accID)
    local playerVehicles = {}

    if not vehicleResult then
        outputDebugString("[USERPANEL] ⚠ DB-Fehler beim Laden der Fahrzeuge für AccID " .. accID .. ": " .. (errMsgVehicles or "Unbekannt"))
        -- Fährt ohne Fahrzeuge fort, aber loggt den Fehler.
    elseif vehicleResult then
        for _, row in ipairs(vehicleResult) do
            local vehModel = tonumber(row.model)
            if vehModel and vehModel > 0 then
                 local vehicleName = getVehicleNameFromModel(vehModel) or ("Model "..vehModel)
                 local health = tonumber(row.health) or 1000
                 local fuel = tonumber(row.fuel) or 100
                 local vehicleID = tonumber(row.id)
                 table.insert(playerVehicles, {id = vehicleID, name = vehicleName, health = math.floor(health), fuel = math.floor(fuel)})
            else
                 outputDebugString("[USERPANEL] ⚠ Ungültiges Fahrzeugmodell (ID: "..tostring(row.id)..") für accID="..accID)
            end
        end
        table.sort(playerVehicles, function(a,b) return a.id < b.id end)
    else
         outputDebugString("[USERPANEL] ⚠ Fehler beim Abfragen der Fahrzeuge für accID="..accID .." (Result war nicht false, aber leer oder unerwartet).")
    end

    triggerClientEvent(player, "showUserPanel", player, getPlayerName(player), moneyValue, formattedPlaytime, factionName, wantedLevel, playerVehicles)
end

addEvent("despawnPlayerVehicle", true)
addEventHandler("despawnPlayerVehicle", root, function(vehicleID)
    local player = source
    if not isElement(player) or not vehicleID then return end

    local accID = getElementData(player, "account_id")
    if not accID then
        return
    end

    local vehicleFoundAndOwned = false
    for _, vehicle in ipairs(getElementsByType("vehicle")) do
        local vDataID = getElementData(vehicle, "id")
        local vOwnerAccID = getElementData(vehicle, "account_id")

        if vDataID == vehicleID then
            if vOwnerAccID == accID then
                destroyElement(vehicle)
                outputChatBox("✅ Fahrzeug erfolgreich entfernt!", player, 0, 255, 0)
                vehicleFoundAndOwned = true
                -- Optional: Aktualisiere das Userpanel für den Spieler
                -- getPlayerStatistics(player)
                break
            else
                outputChatBox("❌ Du bist nicht der Besitzer dieses Fahrzeugs.", player, 255, 0, 0)
                vehicleFoundAndOwned = true
                break
            end
        end
    end

    if not vehicleFoundAndOwned then
        outputChatBox("❌ Fahrzeug ist derzeit nicht gespawnt oder wurde bereits entfernt.", player, 255, 165, 0)
    end
end)

addEvent("requestUserPanelDataFromHandy", true)
addEventHandler("requestUserPanelDataFromHandy", root, function()
    local player = client
    if not isElement(player) then return end
    if not getElementData(player, "account_id") then
        triggerClientEvent(player, "showMessage", player, "Fehler: Account nicht vollständig geladen.", 255,0,0)
        return
    end
    getPlayerStatistics(player)
end)

local lastSelfUsage = {}
local COOLDOWN_MS   = 3000

addCommandHandler("self", function(player, command)
    local now = getTickCount()
    local last = lastSelfUsage[player] or 0
    if now - last < COOLDOWN_MS then
        local remaining = math.ceil((COOLDOWN_MS - (now - last)) / 1000)
        outputChatBox("Bitte warte "..remaining.." Sekunden.", player, 255, 150, 0)
        return
    end
    lastSelfUsage[player] = now
    getPlayerStatistics(player)
end)

addEventHandler("onResourceStart", resourceRoot, function()
    local db_check = exports.datenbank:getConnection()
    if not db_check then
        --outputDebugString("[UserPanel] FATALER FEHLER bei onResourceStart: Keine Datenbankverbindung!", 2)
        -- Hier könnte man überlegen, die Ressource zu stoppen, wenn die DB essentiell ist.
        -- cancelEvent() oder stopResource(getThisResource())
    end
    --outputDebugString("[UserPanel] Userpanel-System (Server V1.1 mit DB-Fehlerbehandlung) geladen.")
end)