-- tarox/peds/peds_nametags_client.lua
-- Version: Nametags V3.2 - Fallback auf getElementsByType

local localPlayer = getLocalPlayer()
local screenWidth, screenHeight = guiGetScreenSize()
local NAMETAG_DRAW_DISTANCE = 20 -- Maximale Entfernung, bis zu der Namensschilder gezeichnet werden
local NAMETAG_CLOSE_DISTANCE = 6 -- Entfernung, bei der das Schild auch gezeichnet wird, wenn es leicht verdeckt ist

-- Konfiguration für Namensschilder
local nametagFont = "default-bold"
local nametagScale = 1 -- << HIER ÄNDERN FÜR SCHRIFTGRÖSSE (z.B. auf 0.8 oder 0.9)
local nametagColor = tocolor(255, 255, 255, 235)
local nametagShadowColor = tocolor(0, 0, 0, 190)
local nametagWorldOffsetY = 0.1 -- Offset über dem Kopf des Peds (Welt-Einheiten) für die 3D-zu-2D-Konvertierung

local function renderPedNametags()
    local playerX, playerY, playerZ = getElementPosition(localPlayer)

    -- Iteriere durch alle Peds auf dem Server
    for _, pedElement in ipairs(getElementsByType("ped")) do
        -- Prüfe, ob der Ped für den lokalen Spieler gestreamt (sichtbar) ist
        if isElementStreamedIn(pedElement) then
            if getElementData(pedElement, "isTaroxPed") then -- Nur Peds vom Gamemode
                local pedName = getElementData(pedElement, "pedName")

                if pedName and pedName ~= "" then
                    local pedX, pedY, pedZ = getElementPosition(pedElement)
                    local distance = getDistanceBetweenPoints3D(playerX, playerY, playerZ, pedX, pedY, pedZ)

                    if distance <= NAMETAG_DRAW_DISTANCE then
                        local headPosX, headPosY, headPosZ = pedX, pedY, pedZ + 0.95 -- Start mit generischem Kopf-Offset

                        -- Versuche Bone-Position für genauere Platzierung
                        local boneSuccess, bX,bY,bZ = pcall(getPedBonePosition, pedElement, 6) -- Bone 6 (Kopf)
                        if boneSuccess and bX then
                            headPosX, headPosY, headPosZ = bX,bY,bZ
                        end
                        
                        local screenX, screenY = getScreenFromWorldPosition(headPosX, headPosY, headPosZ + nametagWorldOffsetY)

                        if screenX and screenY then
                            local drawText = true
                            if distance > NAMETAG_CLOSE_DISTANCE then
                                -- Prüfe Sichtlinie nur für weiter entfernte Peds
                                if not isLineOfSightClear(playerX, playerY, playerZ, headPosX, headPosY, headPosZ, true, false, false, true, false, false, false, localPlayer) then
                                    drawText = false
                                end
                            end

                            if drawText then
                                local textWidth = dxGetTextWidth(pedName, nametagScale, nametagFont)
                                local textHeight = dxGetFontHeight(nametagScale, nametagFont)
                                local drawX = screenX - (textWidth / 2)
                                local drawY = screenY - textHeight - 4 -- Positioniert Text über dem screenY Punkt

                                -- Schatten
                                dxDrawText(pedName, drawX + 1, drawY + 1, drawX + textWidth + 1, drawY + textHeight + 1, nametagShadowColor, nametagScale, nametagFont, "left", "top", false, false, false, true, false)
                                -- Eigentlicher Text
                                dxDrawText(pedName, drawX, drawY, drawX + textWidth, drawY + textHeight, nametagColor, nametagScale, nametagFont, "left", "top", false, false, false, true, false)
                            end
                        end
                    end
                end
            end
        end
    end
end
addEventHandler("onClientRender", root, renderPedNametags)

addEventHandler("onClientResourceStart", resourceRoot, function()
    -- outputChatBox("Tarox Ped Nametags Client (v3.2 - getElementsByType) geladen.", 0, 200, 50, true)
end)