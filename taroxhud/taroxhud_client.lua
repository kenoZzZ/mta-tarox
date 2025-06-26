-- tarox_customhud/taroxhud_client.lua
-- VERSION 15: Uhrzeit ohne Icon, rechts neben Waffen/Munition, nutzt getRealTime() direkt

local screenW, screenH = guiGetScreenSize()
local localPlayer = getLocalPlayer()
local isLoggedIn = false

-- HUD Daten & Animationsvariablen
local playerMoney_display = 0
local playerWanteds_cache = 0

local moneyAnimationStep = 0
local MONEY_ANIMATION_SPEED_FACTOR = 0.08
local MIN_MONEY_ANIMATION_STEP = 1

local mtaHudComponentsToHide = {
    ["ammo"] = true, ["area_name"] = true, ["armour"] = true,
    ["breath"] = true, ["clock"] = true, ["health"] = true,
    ["money"] = true, ["radio"] = true, ["vehicle_name"] = true,
    ["weapon"] = true, ["wanted"] = true
}

local hudLayout = {
    mainBoxWidth = 310, padding = 12, itemTextHeight = 28,
    barHeight = 10, barOffsetY = 3,
    getTotalItemHeightWithBar = function(self) return self.itemTextHeight + self.barOffsetY + self.barHeight end,
    itemHeightRegular = 0,
    weaponBoxHeight = 50, weaponIconSize = 42,
    textOffsetX = 10,
    mainOffsetX = 25, mainOffsetY = 25, itemSpacingY = 7,
    iconSizeStandard = 30,
}
hudLayout.itemHeightRegular = hudLayout.itemTextHeight

local hudColors = {
    BG_MAIN = tocolor(28, 30, 36, 230), BORDER_LIGHT = tocolor(65, 68, 78, 220), TEXT_VALUE = tocolor(250, 250, 255),
    HEALTH_GOOD = tocolor(90, 210, 90, 245), HEALTH_MEDIUM = tocolor(225, 205, 90, 245), HEALTH_BAD = tocolor(225, 90, 90, 245),
    ARMOR_BAR = tocolor(130, 170, 250, 245), ARMOR_TEXT = tocolor(130, 170, 250, 245),
    MONEY = tocolor(110, 225, 160, 245),
    WANTEDS = tocolor(250, 130, 130, 245), WANTEDS_ZERO = tocolor(200, 205, 210, 240),
    WEAPON_AMMO = tocolor(230, 230, 230, 245), WEAPON_NAME = tocolor(225, 225, 235, 245),
    ICON_TINT = tocolor(250, 250, 250, 255), BAR_BG = tocolor(45, 48, 56, 210),
    TIME_TEXT = tocolor(220, 220, 250, 245)
}

local hudFonts = {
    VALUE = {font = "default-bold", scale = 1.20}, WANTEDS_VALUE = {font = "default-bold", scale = 1.25},
    WEAPON_NAME = {font = "default-bold", scale = 1.05},
    WEAPON_AMMO = {font = "default-bold", scale = 1.1},
    WEAPON_DISPLAY = {font = "default-bold", scale = 1.0},
    TIME_VALUE = {font = "default-bold", scale = 1.20}
}

local hudIcons = {
    HEALTH = "images/health.png", ARMOR = "images/armor.png", MONEY = "images/money.png",
    WANTEDS = "images/wanted.png"
}

local function getWeaponIconPath(weaponID)
    if weaponID == 0 then return "images/weapons/weapon_0.png" end
    if weaponID == 1 or (weaponID >= 10 and weaponID <= 15) or weaponID == 40 or weaponID == 44 or weaponID == 45 then
        return nil
    end
    if weaponID >= 2 and weaponID <= 46 then
        local path = "images/weapons/weapon_" .. weaponID .. ".png"
        if fileExists(path) then
            return path
        end
    end
    return nil
end

local function hideStandardHUDComponents()
    if not isLoggedIn then return end
    for component, shouldHide in pairs(mtaHudComponentsToHide) do
        if shouldHide then
            showPlayerHudComponent(component, false)
        end
    end
    showChat(true)
end

addEvent("loginSuccess", true)
addEventHandler("loginSuccess", root, function()
    isLoggedIn = true
    playerMoney_display = getPlayerMoney(localPlayer) or 0
    playerWanteds_cache = getElementData(localPlayer, "wanted") or 0
    setTimer(hideStandardHUDComponents, 500, 1)
end)

addEvent("onPlayerLogout", true)
addEventHandler("onPlayerLogout", root, function()
    isLoggedIn = false
    for component, _ in pairs(mtaHudComponentsToHide) do
        showPlayerHudComponent(component, true)
    end
    showPlayerHudComponent("radar", true)
end)

addEventHandler("onClientElementDataChange", localPlayer, function(dataName)
    if not isLoggedIn then return end
    if dataName == "wanted" then
        playerWanteds_cache = getElementData(localPlayer, "wanted") or 0
    end
end)

local function formatMoneyForHUD(amount)
    local amountStr = tostring(math.floor(amount or 0))
    local formatted = amountStr
    local k = string.len(amountStr) % 3
    if k == 0 then k = 3 end
    while k < string.len(formatted) do
        formatted = string.sub(formatted, 1, k) .. "." .. string.sub(formatted, k + 1)
        k = k + 4
    end
    return formatted
end

local function dxDrawInfoElementInBox(iconPath, valueText, drawX, drawY, elementWidth, elementActualHeight,
                                   barPercent, barColor, valueColor, iconTint, pIconSize, pFontStyle, pTextOffsetX, textAlignment)
    textAlignment = textAlignment or "left"
    local currentIconSize = pIconSize or hudLayout.iconSizeStandard
    local currentFontStyle = pFontStyle or hudFonts.VALUE
    local actualFontName = type(currentFontStyle) == "table" and currentFontStyle.font or currentFontStyle
    local actualFontScale = type(currentFontStyle) == "table" and currentFontStyle.scale or 1.0
    local currentTextOffsetX = pTextOffsetX or hudLayout.textOffsetX

    local textPartDrawHeight = hudLayout.itemTextHeight
    if not barPercent then
        textPartDrawHeight = elementActualHeight
    end

    local iconX = drawX
    local iconY = drawY + (textPartDrawHeight - currentIconSize) / 2
    local actualIconDrawSize = 0

    if iconPath and fileExists(iconPath) then
        dxDrawImage(iconX, iconY, currentIconSize, currentIconSize, iconPath, 0,0,0, iconTint or hudColors.ICON_TINT)
        actualIconDrawSize = currentIconSize
    end

    local textX = iconX + actualIconDrawSize + currentTextOffsetX
    if not iconPath or not fileExists(iconPath) then
        textX = drawX
    end
    local textDrawWidth = elementWidth - (textX - drawX)

    dxDrawText(valueText, textX, drawY, textX + textDrawWidth, drawY + textPartDrawHeight, valueColor or hudColors.TEXT_VALUE, actualFontScale, actualFontName, textAlignment, "center", false,false,false,true)

    if type(barPercent) == "number" and barPercent >= 0 then
        local barActualColor = barColor or hudColors.HEALTH_GOOD
        local barDrawY = drawY + textPartDrawHeight + hudLayout.barOffsetY
        local barDrawWidth = elementWidth
        dxDrawRectangle(drawX, barDrawY, barDrawWidth, hudLayout.barHeight, hudColors.BAR_BG)
        dxDrawRectangle(drawX, barDrawY, barDrawWidth * (math.max(0, math.min(100,barPercent))/100), hudLayout.barHeight, barActualColor)
        dxDrawLine(drawX, barDrawY, drawX+barDrawWidth, barDrawY, hudColors.BORDER_LIGHT,1)
        dxDrawLine(drawX, barDrawY+hudLayout.barHeight, drawX+barDrawWidth, barDrawY+hudLayout.barHeight, hudColors.BORDER_LIGHT,1)
    end
end

local function renderCustomHUD()
    if not isLoggedIn or isConsoleActive() or isMainMenuActive() then return end
    if isPedDead(localPlayer) then return end

    local playerMoney_target_now = getPlayerMoney(localPlayer) or 0
    if playerMoney_display ~= playerMoney_target_now then
        local diff = playerMoney_target_now - playerMoney_display
        moneyAnimationStep = diff * MONEY_ANIMATION_SPEED_FACTOR
        if math.abs(moneyAnimationStep) < MIN_MONEY_ANIMATION_STEP and diff ~= 0 then
            moneyAnimationStep = (diff > 0 and MIN_MONEY_ANIMATION_STEP or -MIN_MONEY_ANIMATION_STEP)
        end
        if math.abs(diff) < MIN_MONEY_ANIMATION_STEP then
            playerMoney_display = playerMoney_target_now
        else
            playerMoney_display = playerMoney_display + moneyAnimationStep
        end
        if (moneyAnimationStep > 0 and playerMoney_display > playerMoney_target_now) or (moneyAnimationStep < 0 and playerMoney_display < playerMoney_target_now) then
            playerMoney_display = playerMoney_target_now
        end
    end

    local currentHealth = getElementHealth(localPlayer)
    local maxHealth = 100
    local healthTextForDisplay = math.floor(currentHealth) .. " / " .. math.floor(maxHealth) .. " HP"
    local healthBarPercent = (maxHealth > 0 and (currentHealth / maxHealth * 100)) or 0
    local currentArmor = getPedArmor(localPlayer)
    local currentWanteds = getElementData(localPlayer, "wanted") or playerWanteds_cache
    local currentWeaponID = getPedWeapon(localPlayer)
    local weaponSlot = getPedWeaponSlot(localPlayer)
    local currentWeaponAmmo = getPedAmmoInClip(localPlayer, weaponSlot)
    local totalWeaponAmmo = getPedTotalAmmo(localPlayer, weaponSlot)

    local mainBoxRealX = screenW - hudLayout.mainBoxWidth - hudLayout.mainOffsetX
    local currentContentY_render = hudLayout.mainOffsetY + hudLayout.padding
    local contentStartX = mainBoxRealX + hudLayout.padding
    local contentFullWidth = hudLayout.mainBoxWidth - (2*hudLayout.padding)
    local halfWidth = contentFullWidth/2 - (hudLayout.itemSpacingY/2)
    local totalItemHeightWithBarValue = hudLayout:getTotalItemHeightWithBar()

    local calculatedBoxHeight = hudLayout.padding
    calculatedBoxHeight = calculatedBoxHeight + totalItemHeightWithBarValue + hudLayout.itemSpacingY
    calculatedBoxHeight = calculatedBoxHeight + hudLayout.itemHeightRegular + hudLayout.itemSpacingY

    local weaponIconPath = getWeaponIconPath(currentWeaponID)
    if weaponIconPath then
        calculatedBoxHeight = calculatedBoxHeight + hudLayout.weaponBoxHeight
    else
        calculatedBoxHeight = calculatedBoxHeight + hudLayout.itemHeightRegular -- Platz für Zeit, wenn keine Waffe
    end
    calculatedBoxHeight = calculatedBoxHeight + hudLayout.padding

    dxDrawRectangle(mainBoxRealX, hudLayout.mainOffsetY, hudLayout.mainBoxWidth, calculatedBoxHeight, hudColors.BG_MAIN)
    dxDrawLine(mainBoxRealX, hudLayout.mainOffsetY+calculatedBoxHeight, mainBoxRealX+hudLayout.mainBoxWidth, hudLayout.mainOffsetY+calculatedBoxHeight, hudColors.BORDER_LIGHT, 1)
    currentContentY_render = hudLayout.mainOffsetY + hudLayout.padding

    local healthBarColor = hudColors.HEALTH_GOOD
    if healthBarPercent < 70 then healthBarColor = hudColors.HEALTH_MEDIUM end
    if healthBarPercent < 30 then healthBarColor = hudColors.HEALTH_BAD end
    if currentHealth <= 0 then healthBarPercent = 0 end

    dxDrawInfoElementInBox(hudIcons.HEALTH, healthTextForDisplay, contentStartX, currentContentY_render, halfWidth, totalItemHeightWithBarValue, healthBarPercent, healthBarColor, hudColors.TEXT_VALUE, hudColors.ICON_TINT, hudLayout.iconSizeStandard, hudFonts.VALUE, hudLayout.textOffsetX, "left")
    dxDrawInfoElementInBox(hudIcons.ARMOR, math.floor(currentArmor).."%", contentStartX + halfWidth + hudLayout.itemSpacingY, currentContentY_render, halfWidth, totalItemHeightWithBarValue, currentArmor, hudColors.ARMOR_BAR, hudColors.ARMOR_TEXT, hudColors.ICON_TINT, hudLayout.iconSizeStandard, hudFonts.VALUE, hudLayout.textOffsetX, "left")
    currentContentY_render = currentContentY_render + totalItemHeightWithBarValue + hudLayout.itemSpacingY

    dxDrawInfoElementInBox(hudIcons.MONEY, "$"..formatMoneyForHUD(playerMoney_display), contentStartX, currentContentY_render, halfWidth, hudLayout.itemHeightRegular, nil,nil, hudColors.MONEY, hudColors.ICON_TINT, hudLayout.iconSizeStandard, hudFonts.VALUE, hudLayout.textOffsetX, "left")
    local wantedsText = currentWanteds .. " Wanted(s)"; local wantedsColorToUse = hudColors.WANTEDS
    if currentWanteds == 0 then wantedsText = "0 Wanteds"; wantedsColorToUse = hudColors.WANTEDS_ZERO end
    dxDrawInfoElementInBox(hudIcons.WANTEDS, wantedsText, contentStartX + halfWidth + hudLayout.itemSpacingY, currentContentY_render, halfWidth, hudLayout.itemHeightRegular, nil, nil, wantedsColorToUse, hudColors.ICON_TINT, hudLayout.iconSizeStandard, hudFonts.WANTEDS_VALUE, hudLayout.textOffsetX, "left")
    currentContentY_render = currentContentY_render + hudLayout.itemHeightRegular + hudLayout.itemSpacingY

    -- [[ NEU: Uhrzeit direkt mit getRealTime() holen ]]
    local time = getRealTime()
    local hour = time.hour
    local minute = time.minute
    local timeStringForHUD = string.format("%02d:%02d Uhr", hour, minute)
    -- Temporäre Debug-Ausgabe, um zu sehen, welche Zeit hier verwendet wird
    -- dxDrawText("HUD Zeit: " .. timeStringForHUD, 10, 10, 300, 30, tocolor(255,255,255), 1.0, "default")


    if weaponIconPath then
        local weaponName = getWeaponNameFromID(currentWeaponID) or "Unknown"
        if currentWeaponID == 0 then weaponName = "Unbewaffnet" end
        local ammoText = ""
        if currentWeaponID > 1 and currentWeaponID ~= 46 and weaponSlot >= 2 and weaponSlot <= 9 then
            if currentWeaponAmmo and totalWeaponAmmo then
                local reserveAmmo = totalWeaponAmmo - currentWeaponAmmo
                ammoText = currentWeaponAmmo .. " / " .. math.max(0, reserveAmmo)
            end
        elseif currentWeaponID > 1 and (weaponSlot == 0 or weaponSlot == 1 or weaponSlot >= 10) then
             if totalWeaponAmmo and totalWeaponAmmo > 0 then
                ammoText = totalWeaponAmmo
             end
        end

        local displayWeaponText = weaponName .. (ammoText ~= "" and "  " .. ammoText or "")
        local timeTextWidth = dxGetTextWidth(timeStringForHUD, hudFonts.TIME_VALUE.scale, hudFonts.TIME_VALUE.font)

        -- Breite für Waffeninfo dynamisch (maximal verfügbar minus Platz für Zeit und einen kleinen Abstand)
        local spaceBetweenWeaponAndTime = 10 -- Pixel Abstand
        local weaponDisplayAreaWidth = contentFullWidth - timeTextWidth - spaceBetweenWeaponAndTime - hudLayout.textOffsetX - hudLayout.weaponIconSize

        -- Waffe/Muni linksbündig mit Icon
        dxDrawInfoElementInBox(weaponIconPath, displayWeaponText, contentStartX, currentContentY_render, weaponDisplayAreaWidth, hudLayout.weaponBoxHeight, nil,nil, hudColors.WEAPON_AMMO, hudColors.ICON_TINT, hudLayout.weaponIconSize, hudFonts.WEAPON_DISPLAY, hudLayout.textOffsetX, "left")

        -- Zeit rechtsbündig in der verbleibenden Breite
        local timeDrawX = contentStartX + hudLayout.weaponIconSize + hudLayout.textOffsetX + weaponDisplayAreaWidth + spaceBetweenWeaponAndTime
        local timeDrawWidth = contentFullWidth - (timeDrawX - contentStartX)
        dxDrawText(timeStringForHUD, timeDrawX, currentContentY_render, timeDrawX + timeDrawWidth, currentContentY_render + hudLayout.weaponBoxHeight, hudColors.TIME_TEXT, hudFonts.TIME_VALUE.scale, hudFonts.TIME_VALUE.font, "right", "center",false,true,false,true)

    else
        -- Wenn keine Waffe, Zeit zentriert anzeigen (ohne Icon, da du keins wolltest)
        dxDrawText(timeStringForHUD, contentStartX, currentContentY_render, contentStartX + contentFullWidth, currentContentY_render + hudLayout.itemHeightRegular, hudColors.TIME_TEXT, hudFonts.TIME_VALUE.scale, hudFonts.TIME_VALUE.font, "center", "center", false, true, false, true)
    end
end
addEventHandler("onClientRender", root, renderCustomHUD)

addEventHandler("onClientResourceStart", resourceRoot, function()
    if getElementData(localPlayer, "account_id") then
        isLoggedIn = true;
        playerMoney_display = getPlayerMoney(localPlayer) or 0;
        playerWanteds_cache = getElementData(localPlayer, "wanted") or 0;
        setTimer(hideStandardHUDComponents, 500, 1)
    else isLoggedIn = false end
    -- Die _G Variablen werden hier nicht mehr explizit für das HUD initialisiert,
    -- da das HUD getRealTime() direkt verwendet.
    --outputChatBox("[TaroxHUD] HUD Client V15 (Zeit direkt via getRealTime()) geladen.", 200,200,0)
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    for component, _ in pairs(mtaHudComponentsToHide) do
        showPlayerHudComponent(component, true)
    end
    showPlayerHudComponent("radar", true)
end)

-- [[ CODE ZUM AUSBLENDEN DER STANDARD NAMETAGS ]] --
-- Funktion, um Nametags für alle aktuellen Spieler auszublenden
function hideAllPlayerNametags()
    local players = getElementsByType("player")
    for i, playerElement in ipairs(players) do
        if isElement(playerElement) then -- Stelle sicher, dass das Element noch gültig ist
            setPlayerNametagShowing(playerElement, false)
        end
    end
end

-- Event-Handler, um die Funktion beim Start der Ressource auszuführen
addEventHandler("onClientResourceStart", resourceRoot, function()
    hideAllPlayerNametags()
end)

-- Event-Handler, um Nametags für neu beitretende Spieler auszublenden
addEventHandler("onClientPlayerJoin", root, function()
    if isElement(source) then -- 'source' ist der Spieler, der beigetreten ist
        setPlayerNametagShowing(source, false)
    end
end)

-- Optional: Stelle sicher, dass der Nametag auch nach einem Respawn ausgeblendet bleibt
addEventHandler("onClientPlayerSpawn", root, function()
    -- Kurze Verzögerung, um sicherzustellen, dass der Spieler-Ped gültig ist und
    -- die Standard-Logik von MTA abgeschlossen ist.
    setTimer(function()
        if isElement(source) then -- 'source' ist der gespawnte Spieler
            setPlayerNametagShowing(source, false)
        end
    end, 100, 1) -- 100 Millisekunden Verzögerung, einmalige Ausführung
end)
-- [[ ENDE CODE ZUM AUSBLENDEN DER STANDARD NAMETAGS ]] --