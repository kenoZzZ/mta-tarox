-- tarox/user/server/position_server.lua
-- Speichert und lädt Spielerpositionen.
-- BEREINIGT: Event-Handler für Quit/Logout/Stop entfernt!
-- ANGEPASST V1.1: Verbesserte Fehlerbehandlung für Datenbankaufrufe

-- Globale Funktion zum Speichern (wird von login_server aufgerufen)
function savePlayerPosition(player)
    if not isElement(player) then return false end
    local account = getPlayerAccount(player)
    if not account or isGuestAccount(account) then return false end
    local accID = getElementData(player, "account_id")
    if not accID then
        -- outputDebugString("[Position] savePlayerPosition: Keine accID für ".. getPlayerName(player))
        return false
    end

    local x, y, z = getElementPosition(player)
    local rot = getPedRotation(player)
    local dim = getElementDimension(player)
    local int = getElementInterior(player)
    -- outputDebugString(string.format("[Position] savePlayerPosition: Speichere für AccID %s -> Pos: %.2f,%.2f,%.2f Rot: %.2f Dim: %d Int: %d",
    --    tostring(accID), x, y, z, rot, dim, int))

    local query = [[
        INSERT INTO positions (account_id, posX, posY, posZ, rotation, dimension, interior, last_update)
        VALUES (?, ?, ?, ?, ?, ?, ?, NOW())
        ON DUPLICATE KEY UPDATE
        posX=VALUES(posX), posY=VALUES(posY), posZ=VALUES(posZ), rotation=VALUES(rotation),
        dimension=VALUES(dimension), interior=VALUES(interior), last_update=NOW()
    ]]
    local dbSuccess, execErrMsg = exports.datenbank:executeDatabase(query, accID, x, y, z, rot, dim, int)

    if not dbSuccess then
        -- outputDebugString("[Position] DB FEHLER beim Speichern für ID: "..accID .. " Fehler: " .. (execErrMsg or "Unbekannt"))
        return false -- Signalisiere den Fehler
    else
        -- outputDebugString("[Position] DB Execute zum Speichern erfolgreich für ID: "..accID)
        return true -- Erfolg
    end
end

-- Globale Funktion zum Laden/Spawnen (wird von login_server aufgerufen)
-- tarox/user/server/position_server.lua (NEUE, KORRIGIERTE Version)

function loadPlayerPosition(player)
    if not isElement(player) then return false, "Invalid player element" end
    local account = getPlayerAccount(player)
    if not account or isGuestAccount(account) then
        spawnPlayer(player, 0, 0, 3, 0, getElementModel(player) or 0)
        fadeCamera(player, true); setCameraTarget(player, player); toggleAllControls(player, true); setElementFrozen(player, false)
        return false, "Guest account or no account"
    end
    local accID = getElementData(player, "account_id")
    if not accID then
        spawnPlayer(player, 0, 0, 3, 0, getElementModel(player) or 0)
        fadeCamera(player, true); setCameraTarget(player, player); toggleAllControls(player, true); setElementFrozen(player, false)
        return false, "No account_id"
    end

    local positionResult, errMsg = exports.datenbank:queryDatabase("SELECT posX, posY, posZ, rotation, dimension, interior FROM positions WHERE account_id=? LIMIT 1", accID)

    if not positionResult then
        spawnPlayer(player, 0, 0, 3, 0, getElementModel(player) or 0, 0, 1)
        fadeCamera(player, true, 1); setCameraTarget(player, player)
        toggleAllControls(player, true); setElementFrozen(player, false)
        return false, "Database query error"
    end

    local spawnX, spawnY, spawnZ, spawnRot, spawnInt, spawnDim = 0, 0, 3, 0, 0, 0
    local loadedFromDB = false

    if positionResult and positionResult[1] then
        local row = positionResult[1]
        spawnX = tonumber(row.posX) or spawnX; spawnY = tonumber(row.posY) or spawnY; spawnZ = tonumber(row.posZ) or spawnZ
        spawnRot = tonumber(row.rotation) or spawnRot; spawnInt = tonumber(row.interior) or spawnInt; spawnDim = tonumber(row.dimension) or spawnDim
        loadedFromDB = true

        -- =========================================================================
        -- ## HIER IST DIE KORREKTUR ##
        -- Prüfen, ob der Spieler in einer Haus-Dimension ist.
        -- Wenn ja, lade die Außenkoordinaten des Hauses und setze sie als ElementData.
        -- =========================================================================
        if spawnDim > 0 then
            local houseExteriorResult, houseErrMsg = exports.datenbank:queryDatabase("SELECT posX, posY, posZ FROM houses WHERE id = ? LIMIT 1", spawnDim)
            if houseExteriorResult and houseExteriorResult[1] then
                local exteriorPos = {
                    x = houseExteriorResult[1].posX,
                    y = houseExteriorResult[1].posY,
                    z = houseExteriorResult[1].posZ
                }
                setElementData(player, "currentHouseExterior", exteriorPos, false)
            else
                -- Fallback, falls die Haus-Dimension in der DB nicht (mehr) existiert
                outputDebugString("[House-Login] WARNUNG: Spieler " .. getPlayerName(player) .. " in Dimension " .. spawnDim .. ", aber kein passendes Haus gefunden. '/leave' wird nicht funktionieren.")
            end
        end
        -- =========================================================================
        -- ## ENDE DER KORREKTUR ##
        -- =========================================================================
    end

    spawnPlayer(player, spawnX, spawnY, spawnZ, spawnRot, getElementModel(player) or 0, spawnInt, spawnDim)
    fadeCamera(player, true, 0.5)
    setCameraTarget(player, player)
    toggleAllControls(player, true)
    setElementFrozen(player, false)

    setTimer(function() if isElement(player) then setElementInterior(player, spawnInt); setElementDimension(player, spawnDim) end end, 100, 1)

    return loadedFromDB, "Success"
end

-- outputDebugString("[Position] Positions-System (Server V1.1 - Robuste DB-Fehlerbehandlung) geladen.")