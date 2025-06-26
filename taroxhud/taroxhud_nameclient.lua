-- taroxhud/taroxhud_nameclient.lua
-- VERSION V2.12: Nur Nickname in Fraktionsfarbe, KEINE ID. Titel-Logik wie V2.8.

local playerCustomTitles = {}
local playerAccountIDs = {}
local renderCallCounter = 0

local playerNametagColors = {} -- Cache für die Nickname-Farben

local function getPlayerDisplayNametagColor(player)
    if playerNametagColors[player] and
       type(playerNametagColors[player].r) == "number" and
       type(playerNametagColors[player].g) == "number" and
       type(playerNametagColors[player].b) == "number" then
        return playerNametagColors[player].r, playerNametagColors[player].g, playerNametagColors[player].b
    end
    local r_mta, g_mta, b_mta = getPlayerNametagColor(player)
    return r_mta or 255, g_mta or 255, b_mta or 255
end

local function initializePlayerDataClient(playerElement)
    if not isElement(playerElement) then return end
    local titleFromServer = getElementData(playerElement, "playerTitle")
    playerCustomTitles[playerElement] = (titleFromServer and titleFromServer ~= "" and titleFromServer ~= "[Titel]") and titleFromServer or "Beginner"
    playerAccountIDs[playerElement] = getElementData(playerElement, "account_id") 

    playerNametagColors[playerElement] = {
        r = getElementData(playerElement, "nametagColorR"),
        g = getElementData(playerElement, "nametagColorG"),
        b = getElementData(playerElement, "nametagColorB")
    }
end

addEventHandler("onClientElementDataChange", root,
    function(dataName)
        if source and getElementType(source) == "player" then
            if dataName == "playerTitle" then
                local receivedTitle = getElementData(source, "playerTitle")
                playerCustomTitles[source] = (receivedTitle and receivedTitle ~= "" and receivedTitle ~= "[Titel]") and receivedTitle or "Beginner"
            elseif dataName == "account_id" then 
                playerAccountIDs[source] = getElementData(source, "account_id")
            elseif dataName == "nametagColorR" or dataName == "nametagColorG" or dataName == "nametagColorB" then
                if not playerNametagColors[source] then playerNametagColors[source] = {} end
                if dataName == "nametagColorR" then playerNametagColors[source].r = getElementData(source, "nametagColorR") end
                if dataName == "nametagColorG" then playerNametagColors[source].g = getElementData(source, "nametagColorG") end
                if dataName == "nametagColorB" then playerNametagColors[source].b = getElementData(source, "nametagColorB") end
            end
        end
    end
)

addEventHandler("onClientPlayerJoin", root, function() initializePlayerDataClient(source) end)
addEventHandler("onClientPlayerSpawn", root, function() initializePlayerDataClient(source) end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    for _, player in ipairs(getElementsByType("player")) do
        initializePlayerDataClient(player)
    end
    nameTagState = true
    removeEventHandler("onClientRender", root, renderNameTags) -- Sicherstellen, dass es nicht doppelt hinzugefügt wird
    addEventHandler("onClientRender", root, renderNameTags)
end)

addEventHandler("onClientPlayerQuit", root, function()
    if source then
        if playerCustomTitles[source] then playerCustomTitles[source] = nil end
        if playerAccountIDs[source] then playerAccountIDs[source] = nil end
        if playerNametagColors[source] then playerNametagColors[source] = nil end
    end
end)

local tagFont = dxCreateFont("files/font.ttf", 13) or "default-bold"
if not tagFont or tagFont == "default-bold" then
    outputChatBox("TAROXHUD WARNUNG: Schriftart files/font.ttf konnte nicht geladen werden oder ist nicht vorhanden! Standard-Schriftart wird verwendet.", 255, 194, 14, true)
    tagFont = "default-bold" -- Fallback, falls dxCreateFont fehlschlägt oder die Datei nicht existiert
end

local screenW_name, screenH_name = guiGetScreenSize()
local nameTagState = true
local nametagDistance = 50*50 -- Quadrat der Distanz für Nametags
local nametagDistanceMaxHealth = 20*20 -- Quadrat der Distanz für volle Details (Health/Armor)

function getPlayerTitleClient(player) --
    if not isElement(player) then return "[Ungültiger Spieler]" end

    local fraktion = getElementData(player, "fraktion") --
    local job = getElementData(player, "job") --
    local rang = getElementData(player, "rang") --
    local reputationTitle = playerCustomTitles[player] --

    if fraktion and fraktion ~= "Zivilist" and fraktion ~= "" then --
        local rankText = "" --
        if rang and rang ~= "" and rang ~= "Rang" then --
            rankText = " (" .. tostring(rang) .. ")" --
        end
        return tostring(fraktion) .. rankText --
    end
    if job and job ~= "" then --
        return tostring(job) --
    end
    if reputationTitle and reputationTitle ~= "" and reputationTitle ~= "[Titel]" and reputationTitle ~= "Beginner" then --
        return reputationTitle --
    end
    return "Beginner" --
end


function renderNameTags()
    renderCallCounter = renderCallCounter + 1
    if not nameTagState then return end
    if not localPlayer or getElementAlpha(localPlayer) == 0 then return end -- localPlayer ist bereits global definiert

    local pX, pY, pZ = getElementPosition(localPlayer)
    local localPlayerDimension = getElementDimension(localPlayer)
    local localPlayerInterior = getElementInterior(localPlayer)

    for key, player in ipairs(getElementsByType("player")) do
        if player ~= localPlayer then
            local playerDimension = getElementDimension(player)
            local playerInterior = getElementInterior(player)
            local isLoggedIn = getElementData(player, "loggedin")
            local playerAlpha = getElementAlpha(player)

            if playerDimension == localPlayerDimension and
               playerInterior == localPlayerInterior and
               isLoggedIn == true and -- expliziter Check auf true
               playerAlpha > 0 then

                local x, y, z = getElementPosition(player)
                local distSq = getDistanceBetweenPoints3DSquared(pX, pY, pZ, x, y, z)

                if distSq <= nametagDistance then
                    local boneSuccess, cx, cy, cz = pcall(getPedBonePosition, player, 6) -- Kopfknochen (ID 6)
                    if not boneSuccess or not cx then
                        -- Fallback, falls Knochenposition nicht ermittelbar
                        cx, cy, cz = x, y, z + 0.9 -- Etwas über der Spielerposition
                    else
                        cz = cz + 0.28 -- Kleiner Offset über dem Kopfknochen
                    end

                    local screenXPlayer, screenYPlayer = getScreenFromWorldPosition(cx, cy, cz)

                    if screenXPlayer and screenYPlayer then
                        local drawDetails = true
                        -- Die Logik für drawDetails basierend auf Sichtlinie/Distanz bleibt wie in deinem Original

                        local yNametagTextOffset = 4 -- Beibehaltung der Verschiebung des gesamten Blocks
                        
                        if drawDetails then
                            local cleanName = getPlayerName(player)
                            local title = getPlayerTitleClient(player)
                            local health = getElementHealth(player)
                            local armor = getPedArmor(player)

                            local nick_r, nick_g, nick_b = getPlayerDisplayNametagColor(player)
                            local titleColor = tocolor(210,210,210,240)
                            
                            local nameFontSizeScale = 1.15
                            local titleFontSizeScale = 0.85
                            local textLineHeightName = dxGetFontHeight(nameFontSizeScale, tagFont)
                            local textLineHeightTitle = dxGetFontHeight(titleFontSizeScale, tagFont)
                            
                            -- MODIFIKATION HIER: Abstand zwischen Titel und Name verringert
                            local verticalSpacingBetweenNameAndTitle = -5 -- Vorher 2, jetzt 0 für direkten Anschluss
                            
                            local barOffsetY = 3
                            local barHeight = 7
                            local barWidth = 65
                            local currentDrawY = screenYPlayer

                            if distSq <= nametagDistanceMaxHealth then
                                local healthPercent = math.max(0, math.min(100, health)) / 100
                                local healthColorBar
                                if health <= 0 then healthColorBar = tocolor(80,80,80,200)
                                elseif health < 30 then healthColorBar = tocolor(220, 50, 50, 210)
                                elseif health < 70 then healthColorBar = tocolor(220, 200, 50, 210)
                                else healthColorBar = tocolor(50, 200, 50, 210) end
                                
                                local barDrawX_Health = screenXPlayer - barWidth / 2
                                dxDrawRectangle(barDrawX_Health -1, currentDrawY -1, barWidth + 2, barHeight + 2, tocolor(0,0,0,180))
                                dxDrawRectangle(barDrawX_Health, currentDrawY, barWidth, barHeight, tocolor(50,50,50,180))
                                if health > 0 then dxDrawRectangle(barDrawX_Health, currentDrawY, barWidth * healthPercent, barHeight, healthColorBar) end
                                
                                currentDrawY = currentDrawY - (barHeight + barOffsetY)
                            end

                            if armor > 0 and distSq <= nametagDistanceMaxHealth then
                                local armorPercent = math.max(0, math.min(100, armor)) / 100
                                local armorColorBar = tocolor(100, 140, 220, 210)
                                local barDrawX_Armor = screenXPlayer - barWidth / 2
                                dxDrawRectangle(barDrawX_Armor - 1, currentDrawY -1, barWidth + 2, barHeight + 2, tocolor(0,0,0,180))
                                dxDrawRectangle(barDrawX_Armor, currentDrawY, barWidth, barHeight, tocolor(50,50,50,180))
                                dxDrawRectangle(barDrawX_Armor, currentDrawY, barWidth * armorPercent, barHeight, armorColorBar)
                                currentDrawY = currentDrawY - (barHeight + barOffsetY + 2)
                            elseif distSq <= nametagDistanceMaxHealth then 
                                currentDrawY = currentDrawY - 2
                            end
                            
                            local titleTextY_original = 0
                            local nameTextY_original = 0
                            
                            if title and title ~= "" and title ~= "[Bürger]" then
                                titleTextY_original = currentDrawY - textLineHeightTitle
                                local actualTitleDrawY = titleTextY_original + yNametagTextOffset

                                local titleTextWidth = dxGetTextWidth(title, titleFontSizeScale, tagFont)
                                dxDrawText(title, screenXPlayer - titleTextWidth/2 + 1, actualTitleDrawY + 1, screenXPlayer - titleTextWidth/2 + 1 + titleTextWidth, actualTitleDrawY + 1 + textLineHeightTitle, tocolor(0,0,0,190), titleFontSizeScale, tagFont, "left", "top", false, false, false, true)
                                dxDrawText(title, screenXPlayer - titleTextWidth/2, actualTitleDrawY, screenXPlayer - titleTextWidth/2 + titleTextWidth, actualTitleDrawY + textLineHeightTitle, titleColor, titleFontSizeScale, tagFont, "left", "top", false, false, false, true)
                                
                                currentDrawY = titleTextY_original - verticalSpacingBetweenNameAndTitle -- Verwendet den neuen Wert (z.B. 0)
                            end

                            nameTextY_original = currentDrawY - textLineHeightName
                            local actualNameDrawY = nameTextY_original + yNametagTextOffset

                            local nameTextWidth = dxGetTextWidth(cleanName, nameFontSizeScale, tagFont)
                            dxDrawText(cleanName, screenXPlayer - nameTextWidth/2 + 1, actualNameDrawY + 1, screenXPlayer - nameTextWidth/2 + 1 + nameTextWidth, actualNameDrawY + 1 + textLineHeightName, tocolor(0,0,0,190), nameFontSizeScale, tagFont, "left", "top", false, false, false, true)
                            dxDrawText(cleanName, screenXPlayer - nameTextWidth/2, actualNameDrawY, screenXPlayer - nameTextWidth/2 + nameTextWidth, actualNameDrawY + textLineHeightName, tocolor(nick_r,nick_g,nick_b,245), nameFontSizeScale, tagFont, "left", "top", false, false, false, true)
                        else
                            local cleanName = getPlayerName(player)
                            local nick_r, nick_g, nick_b = getPlayerDisplayNametagColor(player)
                            local nameFontSizeScale = 1.15
                            local textLineHeightName = dxGetFontHeight(nameFontSizeScale, tagFont) 
                            local nameTextWidth = dxGetTextWidth(cleanName, nameFontSizeScale, tagFont)
                            local nameTextY = screenYPlayer - textLineHeightName

                            dxDrawText(cleanName, screenXPlayer - nameTextWidth/2 + 1, nameTextY + 1, screenXPlayer - nameTextWidth/2 + 1 + nameTextWidth, nameTextY + 1 + textLineHeightName, tocolor(0,0,0,190), nameFontSizeScale, tagFont, "left", "top", false, false, false, true)
                            dxDrawText(cleanName, screenXPlayer - nameTextWidth/2, nameTextY, screenXPlayer - nameTextWidth/2 + nameTextWidth, nameTextY + textLineHeightName, tocolor(nick_r,nick_g,nick_b,245), nameFontSizeScale, tagFont, "left", "top", false, false, false, true)
                        end
                    end
                end
            end
        end
    end
end

function toggleNameTags()
    nameTagState = not nameTagState
    if nameTagState then outputChatBox("TAROXHUD: Benutzerdefinierte Nametags aktiviert!", 0, 255, 0, true)
    else outputChatBox("TAROXHUD: Benutzerdefinierte Nametags deaktiviert!", 255, 0, 0, true) end
end
bindKey("F10", "down", toggleNameTags)

addEventHandler("onClientResourceStop", resourceRoot, function()
    removeEventHandler("onClientRender", root, renderNameTags)
    if isElement(tagFont) and tagFont ~= "default-bold" then 
        destroyElement(tagFont)
        tagFont = nil
    end
end)

function getDistanceBetweenPoints3DSquared(x1, y1, z1, x2, y2, z2)
    local dX = x1 - x2; local dY = y1 - y2; local dZ = z1 - z2
    return dX * dX + dY * dY + dZ * dZ
end