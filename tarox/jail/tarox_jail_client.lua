-- tarox/jail/tarox_jail_client.lua (Client-Side)
-- Mit Userpanel-Style für DoorBreak UI und Icon im Text
-- dxGetTextHeight ersetzt durch dxGetFontHeight

local screenW, screenH = guiGetScreenSize()

-- Farben und Fonts (ähnlich dem Userpanel-Stil)
local colors = {
    BG_MAIN = tocolor(28, 30, 36, 240),
    BG_HEADER = tocolor(180, 40, 40, 230), -- Beibehalten für "gefährliche" Aktion
    TEXT_HEADER = tocolor(235, 235, 240),
    TEXT_LIGHT = tocolor(230, 230, 235, 255),
    TEXT_MEDIUM = tocolor(180, 180, 190, 200),
    BORDER_LIGHT = tocolor(55, 58, 68, 180),
    BORDER_DARK = tocolor(20, 22, 28, 220),
    BUTTON_YES_BG = tocolor(70, 200, 70, 220),    -- Grün für "YES"
    BUTTON_YES_HOVER = tocolor(90, 220, 90, 230),
    BUTTON_NO_BG = tocolor(200, 70, 70, 220),     -- Rot für "NO" (wie Header)
    BUTTON_NO_HOVER = tocolor(220, 90, 90, 230),
    BUTTON_TEXT = tocolor(245, 245, 245),
}

local fonts = {
    HEADER = "default-bold",
    TEXT = "default",
    BUTTON = "default-bold"
}

-- Icons (Pfad zum Wanted-Icon hinzugefügt)
local icons = {
    YES = "user/client/images/usericons/confirm.png", -- Beispielpfad, falls du ihn verwendest
    NO = "user/client/images/usericons/cancel.png",    -- Beispielpfad, falls du ihn verwendest
    WANTEDS = "user/client/images/usericons/wanted.png" -- Pfad zum Wanted-Icon
}
-- Stelle sicher, dass die userpanel_client.lua dxDrawStyledButton Funktion hier verfügbar ist
-- oder kopiere sie hierher, wenn sie nicht global ist.
-- Der Einfachheit halber kopieren wir die angepasste Version hierher:

local userpanelLayout = { -- Benötigt für iconSize etc. in dxDrawStyledButton
    iconSize = 20,
    iconPadding = 6,
    buttonH = 35, -- Standard Button Höhe
}

function dxDrawStyledButton(text, x, y, w, h, bgColor, hoverColor, textColor, font, scale, iconPath)
    local cX, cY = getCursorPosition(); local hover = false
    if cX then local mouseX, mouseY = cX * screenW, cY * screenH; hover = mouseX >= x and mouseX <= x + w and mouseY >= y and mouseY <= y + h end
    local currentBgColor = hover and hoverColor or bgColor
    dxDrawRectangle(x, y, w, h, currentBgColor)
    dxDrawLine(x, y, x + w, y, colors.BORDER_LIGHT, 1)
    dxDrawLine(x, y + h, x + w, y + h, colors.BORDER_DARK, 1)
    dxDrawLine(x, y, x, y + h, colors.BORDER_LIGHT, 1)
    dxDrawLine(x + w, y, x + w, y + h, colors.BORDER_DARK, 1)

    if iconPath and fileExists(iconPath) then
        local iconDrawSize = userpanelLayout.iconSize * 1 -- Oder eine andere passende Skalierung für Button-Icons
        local textW = dxGetTextWidth(text, scale, font)
        local totalContentW = iconDrawSize + userpanelLayout.iconPadding * 0.5 + textW
        local startContentX = x + (w - totalContentW) / 2
        local iconDrawY = y + (h - iconDrawSize) / 2
        dxDrawImage(startContentX, iconDrawY, iconDrawSize, iconDrawSize, iconPath, 0, 0, 0, tocolor(255,255,255,230))
        dxDrawText(text, startContentX + iconDrawSize + userpanelLayout.iconPadding * 0.5, y, x + w, y + h, textColor, scale, font, "left", "center", false, false, false, true)
    else
        -- if iconPath then outputDebugString("[JailClient] Button Icon NICHT GEFUNDEN: " .. iconPath) end -- Für den Fall, dass ein Pfad übergeben wird, aber die Datei nicht existiert
        dxDrawText(text, x, y, x + w, y + h, textColor, scale, font, "center", "center", false, false, false, true)
    end
end


-- 1) Freedoor-Countdown
local countdownRunning1=false
local countdownValue1=0

-- 2) PrisonGates-Countdown (aktuell nicht im UI verwendet, aber Logik bleibt)
local countdownRunning2=false
local countdownValue2=0

-- DoorBreak UI
local uiDoorBreakVisible=false
local doorBreakUIClickAreas = {} -- Für Klick-Erkennung

-- HackSystem UI
local uiHackSystemVisible=false
local hackDuration=5   -- 5s für Test, vorher 45s
local hackActive=false
local hackStartTime=0
local hackEndTime=0
local hackPosX,hackPosY,hackPosZ=0,0,0

-- Exit|Lobby text
local drawExitLobby=false
local exitLobbyTimer=nil

-----------------------------------------------------
-- SERVER => CLIENT => Freedoor & Gates countdown
-----------------------------------------------------
addEvent("jail_updateCountdown1",true)
addEventHandler("jail_updateCountdown1",root,function(running,value)
    countdownRunning1=running
    countdownValue1=value
end)

addEvent("jail_updateCountdown2",true)
addEventHandler("jail_updateCountdown2",root,function(running,value)
    countdownRunning2=running
    countdownValue2=value
end)

-----------------------------------------------------
-- Exit|Lobby => 3s
-----------------------------------------------------
addEvent("jail_showExitLobby",true)
addEventHandler("jail_showExitLobby",root,function()
    drawExitLobby=true
    if isTimer(exitLobbyTimer) then killTimer(exitLobbyTimer) end
    exitLobbyTimer=setTimer(function()
        drawExitLobby=false
    end,3000,1)
end)

-----------------------------------------------------
-- UI => Freedoor => +35 wanted
-----------------------------------------------------
addEvent("jail_showDoorBreakUI",true)
addEventHandler("jail_showDoorBreakUI",root,function()
    if uiDoorBreakVisible then return end
    uiDoorBreakVisible=true
    showCursor(true)
    addEventHandler("onClientRender", root, renderDoorBreakUI)
    guiSetInputMode("no_binds_when_editing") -- Verhindert andere Tastenbindungen
end)

function renderDoorBreakUI()
    if not uiDoorBreakVisible then return end

    local panelW, panelH = 420, 250
    local panelX, panelY = (screenW - panelW) / 2, (screenH - panelH) / 2
    local headerH = 45
    local padding = 15
    local buttonH = 40
    local buttonSpacing = 10

    -- Hintergrund und Border
    dxDrawRectangle(panelX, panelY, panelW, panelH, colors.BG_MAIN)
    dxDrawLine(panelX, panelY, panelX + panelW, panelY, colors.BORDER_LIGHT, 2)
    dxDrawLine(panelX, panelY + panelH, panelX + panelW, panelY + panelH, colors.BORDER_DARK, 2)
    dxDrawLine(panelX, panelY, panelX, panelY + panelH, colors.BORDER_LIGHT, 2)
    dxDrawLine(panelX + panelW, panelY, panelX + panelW, panelY + panelH, colors.BORDER_DARK, 2)

    -- Header
    dxDrawRectangle(panelX, panelY, panelW, headerH, colors.BG_HEADER)
    dxDrawText("Confirm Action", panelX, panelY, panelX + panelW, panelY + headerH, colors.TEXT_HEADER, 1.3, fonts.HEADER, "center", "center")

    -- Textinhalt (angepasst für Icon)
    local textX = panelX + padding
    local textY_start = panelY + headerH + padding
    local textW = panelW - (padding * 2)
    local textBlockH = panelH - headerH - (padding * 3) - buttonH
    local textScale = 1.0
    local textFont = fonts.TEXT
    -- ERSETZT: dxGetTextHeight durch dxGetFontHeight
    local lineHeight = dxGetFontHeight(textScale, textFont) -- Höhe einer einzelnen Textzeile, basierend auf der Font-Höhe
    if not lineHeight or lineHeight <= 0 then lineHeight = 12 end -- Fallback, falls dxGetFontHeight Probleme macht

    local iconSize = 18 -- Größe des Wanted-Icons, an Schriftgröße anpassen
    local iconPadding = 3 -- Kleiner Abstand um das Icon

    -- Berechne Start-Y für den gesamten Textblock, um ihn vertikal zu zentrieren
    local numTextLines = 3 -- "Are you sure..." , leere Zeile, "Camera surveillance..."
    local totalTextBlockHeightEstimate = numTextLines * lineHeight
    local blockDrawStartY = textY_start + (textBlockH - totalTextBlockHeightEstimate) / 2

    -- Zeile 1
    local line1_y = blockDrawStartY
    dxDrawText("Are you sure you want to break open the door?",
        textX, line1_y, textX + textW, line1_y + lineHeight,
        colors.TEXT_LIGHT, textScale, textFont, "center", "top", true, true, false, true)

    -- Zeile 3 (mit Icon)
    local line3_y = blockDrawStartY + 2 * lineHeight -- Nach der leeren Zeile

    local text_part1 = "Camera surveillance will add #FFD700+35"
    local text_part2 = "#EBEBEBWanteds to your record!"

    local width_part1 = dxGetTextWidth(text_part1, textScale, textFont, true)
    local width_icon = iconSize
    local width_part2 = dxGetTextWidth(text_part2, textScale, textFont, true)

    local total_line3_width = width_part1 + iconPadding + width_icon + iconPadding + width_part2
    local startX_line3 = textX + (textW - total_line3_width) / 2

    local current_drawX = startX_line3
    -- Teil 1 zeichnen
    dxDrawText(text_part1, current_drawX, line3_y, current_drawX + width_part1, line3_y + lineHeight,
        colors.TEXT_LIGHT, textScale, textFont, "left", "top", false, true, false, true)
    current_drawX = current_drawX + width_part1 + iconPadding

    -- Icon zeichnen
    if icons.WANTEDS and fileExists(icons.WANTEDS) then
        dxDrawImage(current_drawX, line3_y + (lineHeight - iconSize) / 2, iconSize, iconSize, icons.WANTEDS, 0,0,0,tocolor(255,255,255,220))
    end
    current_drawX = current_drawX + width_icon + iconPadding

    -- Teil 2 zeichnen
    dxDrawText(text_part2, current_drawX, line3_y, current_drawX + width_part2, line3_y + lineHeight,
        colors.TEXT_LIGHT, textScale, textFont, "left", "top", false, true, false, true)

    -- Buttons
    local buttonAreaY = panelY + panelH - padding - buttonH
    local buttonTotalW = (panelW - (padding * 2) - buttonSpacing)
    local buttonW = buttonTotalW / 2

    local btnYesX = panelX + padding
    local btnNoX = btnYesX + buttonW + buttonSpacing

    dxDrawStyledButton("YES", btnYesX, buttonAreaY, buttonW, buttonH, colors.BUTTON_YES_BG, colors.BUTTON_YES_HOVER, colors.BUTTON_TEXT, fonts.BUTTON, 1.1, icons.YES)
    dxDrawStyledButton("NO", btnNoX, buttonAreaY, buttonW, buttonH, colors.BUTTON_NO_BG, colors.BUTTON_NO_HOVER, colors.BUTTON_TEXT, fonts.BUTTON, 1.1, icons.NO)

    doorBreakUIClickAreas = {
        yes = {x = btnYesX, y = buttonAreaY, w = buttonW, h = buttonH},
        no  = {x = btnNoX,  y = buttonAreaY, w = buttonW, h = buttonH}
    }
end


-----------------------------------------------------
-- UI => HackSystem => 45s Anim => success/fail
-----------------------------------------------------
addEvent("jail_showHackSystemUI",true)
addEventHandler("jail_showHackSystemUI",root,function()
    if uiHackSystemVisible then return end
    uiHackSystemVisible=true
    showCursor(true)
    addEventHandler("onClientRender", root, renderHackSystemUI)
    guiSetInputMode("no_binds_when_editing")
end)

function renderHackSystemUI()
    if not uiHackSystemVisible then return end
    local panelW, panelH = 420, 250
    local panelX, panelY = (screenW - panelW) / 2, (screenH - panelH) / 2
    local headerH = 45
    local padding = 15
    local buttonH = 40
    local buttonSpacing = 10

    dxDrawRectangle(panelX, panelY, panelW, panelH, colors.BG_MAIN)
    dxDrawLine(panelX, panelY, panelX + panelW, panelY, colors.BORDER_LIGHT, 2)
    dxDrawLine(panelX, panelY + panelH, panelX + panelW, panelY + panelH, colors.BORDER_DARK, 2)
    dxDrawLine(panelX, panelY, panelX, panelY + panelH, colors.BORDER_LIGHT, 2)
    dxDrawLine(panelX + panelW, panelY, panelX + panelW, panelY + panelH, colors.BORDER_DARK, 2)

    dxDrawRectangle(panelX, panelY, panelW, headerH, colors.BG_HEADER)
    dxDrawText("Hack Security System", panelX, panelY, panelX + panelW, panelY + headerH, colors.TEXT_HEADER, 1.3, fonts.HEADER, "center", "center")

    local textX = panelX + padding
    local textY = panelY + headerH + padding
    local textW = panelW - (padding * 2)
    local textBlockH = panelH - headerH - (padding * 3) - buttonH

    dxDrawText("Are you sure you want to hack the jail security system?\n\nIf you #FF6347move or cancel #EBEBEBthe animation, the hack will #FF6347fail!",
        textX, textY, textX + textW, textY + textBlockH,
        colors.TEXT_LIGHT, 1.0, fonts.TEXT, "center", "center", -- Schriftgröße hier auch 1.0
        true, true, false, true)

    local buttonAreaY = panelY + panelH - padding - buttonH
    local buttonTotalW = (panelW - (padding * 2) - buttonSpacing)
    local buttonW = buttonTotalW / 2

    local btnYesX = panelX + padding
    local btnNoX = btnYesX + buttonW + buttonSpacing

    dxDrawStyledButton("HACK", btnYesX, buttonAreaY, buttonW, buttonH, colors.BUTTON_YES_BG, colors.BUTTON_YES_HOVER, colors.BUTTON_TEXT, fonts.BUTTON, 1.1)
    dxDrawStyledButton("CANCEL", btnNoX, buttonAreaY, buttonW, buttonH, colors.BUTTON_NO_BG, colors.BUTTON_NO_HOVER, colors.BUTTON_TEXT, fonts.BUTTON, 1.1)

    uiHackSystemClickAreas = {
        yes = {x = btnYesX, y = buttonAreaY, w = buttonW, h = buttonH},
        no  = {x = btnNoX,  y = buttonAreaY, w = buttonW, h = buttonH}
    }
end

-----------------------------------------------------
-- onClientClick => UI Buttons
-----------------------------------------------------
addEventHandler("onClientClick", root, function(btn, state, cx, cy)
    if btn ~= "left" or state ~= "up" then return end

    if uiDoorBreakVisible then
        local areaYes = doorBreakUIClickAreas.yes
        local areaNo = doorBreakUIClickAreas.no

        if cx >= areaYes.x and cx <= areaYes.x + areaYes.w and cy >= areaYes.y and cy <= areaYes.y + areaYes.h then
            uiDoorBreakVisible=false
            removeEventHandler("onClientRender",root,renderDoorBreakUI)
            showCursor(false)
            guiSetInputMode("allow_binds")
            triggerServerEvent("jail_onDoorBreakYes", localPlayer)
            return
        end
        if cx >= areaNo.x and cx <= areaNo.x + areaNo.w and cy >= areaNo.y and cy <= areaNo.y + areaNo.h then
            uiDoorBreakVisible=false
            removeEventHandler("onClientRender",root,renderDoorBreakUI)
            showCursor(false)
            guiSetInputMode("allow_binds")
            return
        end
    end

    if uiHackSystemVisible then
        local areaYes = uiHackSystemClickAreas.yes
        local areaNo = uiHackSystemClickAreas.no

        if cx >= areaYes.x and cx <= areaYes.x + areaYes.w and cy >= areaYes.y and cy <= areaYes.y + areaYes.h then
            uiHackSystemVisible=false
            removeEventHandler("onClientRender",root, renderHackSystemUI)
            showCursor(false)
            guiSetInputMode("allow_binds")
            startHackAnimation45s()
            return
        end
        if cx >= areaNo.x and cx <= areaNo.x + areaNo.w and cy >= areaNo.y and cy <= areaNo.y + areaNo.h then
            uiHackSystemVisible=false
            removeEventHandler("onClientRender",root,renderHackSystemUI)
            showCursor(false)
            guiSetInputMode("allow_binds")
            return
        end
    end
end)

-----------------------------------------------------
-- Hack => 45s => watch movement
-----------------------------------------------------
function startHackAnimation45s()
    if hackActive then return end
    hackActive=true
    hackStartTime=getTickCount()
    hackEndTime=hackStartTime+(hackDuration*1000)

    local x,y,z=getElementPosition(localPlayer)
    hackPosX,hackPosY,hackPosZ=x,y,z

    setPedAnimation(localPlayer, "SCRATCHING", "sclng_r", -1, true, false, false, false)
    addEventHandler("onClientRender", root, watchHackProcess)
    toggleAllControls(false, true, false)
end

function watchHackProcess()
    if not hackActive then
        removeEventHandler("onClientRender", root, watchHackProcess)
        toggleAllControls(true)
        return
    end

    local now=getTickCount()
    local remain=(hackEndTime-now)/1000
    if remain<=0 then
        stopHackAnimation(true)
        return
    end

    local px,py,pz=getElementPosition(localPlayer)
    local dist=getDistanceBetweenPoints3D(px,py,pz,hackPosX,hackPosY,hackPosZ)
    if dist>0.5 then
        stopHackAnimation(false)
        return
    end

    local barX, barY, barW, barH = screenW * 0.35, screenH * 0.85, screenW * 0.3, 25
    local progress = 1 - (remain / hackDuration)
    dxDrawRectangle(barX, barY, barW, barH, tocolor(50,50,50,200))
    dxDrawRectangle(barX, barY, barW * progress, barH, colors.BUTTON_YES_BG)
    dxDrawText(string.format("Hacking... %ds", math.ceil(remain)), barX, barY, barX + barW, barY + barH, colors.BUTTON_TEXT, 1.0, fonts.TEXT, "center", "center")
    dxDrawText("Do not move!", screenW * 0.35, screenH * 0.8, screenW * 0.65, screenH * 0.84, tocolor(255,100,100), 1.2, fonts.HEADER, "center", "bottom")
end

function stopHackAnimation(success)
    if not hackActive then return end
    hackActive=false
    removeEventHandler("onClientRender", root, watchHackProcess)
    setPedAnimation(localPlayer, false)
    toggleAllControls(true)

    if success then
        triggerServerEvent("jail_onHackSystemSuccess", localPlayer)
        outputChatBox("Hack successful! Prison systems compromised.", 0,220,0)
    else
        outputChatBox("Hack failed! You moved or the animation was interrupted.", 220,0,0)
    end
end

-----------------------------------------------------
-- onClientRender => Countdowns + Exit|Lobby
-----------------------------------------------------
addEventHandler("onClientRender", root, function()
    if countdownRunning1 and countdownValue1>0 then
        dxDrawText(("Freezer Door Opening: %ds"):format(countdownValue1),
            0, screenH * 0.05, screenW, screenH * 0.1, colors.BG_HEADER, 1.3, fonts.HEADER, "center", "center",
            false, false, false, true)
    end

    if drawExitLobby then
        dxDrawText("Exit | Lobby", 0,0,screenW,screenH,
            tocolor(0,160,255,255),1.8,fonts.HEADER,"center","center")
    end
end)

-- Aufräumen beim Beenden der Ressource
addEventHandler("onClientResourceStop", resourceRoot, function()
    if uiDoorBreakVisible then
        removeEventHandler("onClientRender", root, renderDoorBreakUI)
        uiDoorBreakVisible = false
    end
    if uiHackSystemVisible then
        removeEventHandler("onClientRender", root, renderHackSystemUI)
        uiHackSystemVisible = false
    end
    if hackActive then
        stopHackAnimation(false)
    end
    if isTimer(exitLobbyTimer) then
        killTimer(exitLobbyTimer)
        exitLobbyTimer = nil
    end
    showCursor(false)
    guiSetInputMode("allow_binds")
end)

outputDebugString("[JailClient] Jail Client (mit Userpanel Style & Icon im Text, dxGetFontHeight Fix) geladen.")
