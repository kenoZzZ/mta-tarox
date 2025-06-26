-- tarox/user/client/deathspawn_client.lua
-- VERSION 9: Textanpassung für Medic-Wartezeit
-- DEBUG-VERSION: Mit outputChatBox für Button-Anzeige-Logik

local screenW, screenH = guiGetScreenSize()
local localPlayer = getLocalPlayer()

local isDeathScreenActive = false
local deathTimerEndTime = 0
local showSpawnButtons = false
local deathCameraPosition = nil
local killerName = "N/A"
local weaponName = "N/A"
local shouldBeJailed = false

local currentDeathTimerDurationMs = 15 * 1000 -- Standard 15s, wird überschrieben

local windowWidth, windowHeight = 480, 310
local windowX, windowY = (screenW - windowWidth) / 2, (screenH - windowHeight) / 2

local COLOR_BACKGROUND = tocolor(25, 25, 30, 225)
local COLOR_BORDER = tocolor(150, 150, 160, 150)
local COLOR_TITLE_BG = tocolor(180, 40, 40, 230)
local COLOR_TITLE_TEXT = tocolor(255, 255, 255, 255)
local COLOR_TEXT_LIGHT = tocolor(230, 230, 235, 255)
local COLOR_TEXT_MEDIUM = tocolor(180, 180, 190, 200)
local COLOR_BAR_BG = tocolor(50, 50, 55, 200)
local COLOR_BAR_FG = tocolor(210, 50, 50, 220)
local COLOR_BUTTON_CITY = tocolor(60, 140, 220, 220)
local COLOR_BUTTON_HOME = tocolor(60, 200, 140, 220)
local COLOR_BUTTON_FACTION = tocolor(220, 180, 60, 220)
local COLOR_BUTTON_TEXT = tocolor(255, 255, 255, 255)
local COLOR_BUTTON_HOVER = tocolor(255, 255, 255, 55)

local FONT_BOLD = "default-bold"

local function findRotation(x1, y1, x2, y2)
    local t = -math.deg(math.atan2(x2 - x1, y2 - y1)); if t < 0 then t = t + 360 end; return t
end
local function getPointFromDistanceRotation(x,y,dist,angle) local a=math.rad(90-angle); local dx=math.cos(a)*dist; local dy=math.sin(a)*dist; return x+dx,y+dy end

local renderDeathScreenHandler = nil
local REVIVE_WINDOW_MS_CLIENT_CHECK = 150 * 1000 -- Um zu prüfen, ob der lange Timer aktiv ist

addEvent("showDeathScreenClient", true)
addEventHandler("showDeathScreenClient", root, function(killer, weapon, forceJail, durationMs)
    if isDeathScreenActive then return end
    isDeathScreenActive = true
    showSpawnButtons = false
    killerName = killer or "Unknown"
    weaponName = weapon or "Unknown"
    shouldBeJailed = forceJail or false

    if not forceJail and durationMs and durationMs > 0 then
        currentDeathTimerDurationMs = durationMs
    else
        currentDeathTimerDurationMs = 15 * 1000
    end
    deathTimerEndTime = getTickCount() + currentDeathTimerDurationMs

    local x, y, z = getElementPosition(localPlayer)
    local camMatrixX, camMatrixY, camMatrixZ = getCameraMatrix()
    if not camMatrixX then camMatrixX,camMatrixY,camMatrixZ = x-5,y-5,z+5 else camMatrixX,camMatrixY,camMatrixZ = getCameraMatrix() end
    local angle = findRotation(x,y,camMatrixX,camMatrixY); local distance=10; local heightOffset=3
    local camNewX,camNewY = getPointFromDistanceRotation(x,y,distance,angle)
    deathCameraPosition = {camNewX,camNewY,z+heightOffset,x,y,z}

    fadeCamera(false,0); setTimer(fadeCamera,100,1,true,0.5)
    toggleAllControls(false,true,false)

    if not renderDeathScreenHandler then
        renderDeathScreenHandler = renderDeathScreenV9 -- Geändert zu V9
        addEventHandler("onClientRender",root,renderDeathScreenHandler)
    end
    if not isCursorShowing() then showCursor(true) end
end)

addEvent("forceCloseDeathScreenClient", true)
addEventHandler("forceCloseDeathScreenClient", root, function()
    if isDeathScreenActive then
        closeDeathScreenV9() -- Geändert zu V9
    end
end)


local function drawButtonV9(text, x, y, w, h, bgColor, hoverColor, textColor)
    local cX, cY = getCursorPosition(); local hover = false
    if cX then local mX,mY=cX*screenW,cY*screenH; if mX>=x and mX<=x+w and mY>=y and mY<=y+h then hover=true end end
    dxDrawRectangle(x,y,w,h,bgColor); if hover then dxDrawRectangle(x,y,w,h,hoverColor) end
    dxDrawLine(x,y,x+w,y,COLOR_BORDER,1.5); dxDrawLine(x,y+h,x+w,y+h,COLOR_BORDER,1.5)
    dxDrawLine(x,y,x,y+h,COLOR_BORDER,1.5); dxDrawLine(x+w,y,x+w,y+h,COLOR_BORDER,1.5)
    dxDrawText(text,x,y,x+w,y+h,textColor,1.1,FONT_BOLD,"center","center")
end

function renderDeathScreenV9() -- Umbenannt
    if not isDeathScreenActive then return end
    if deathCameraPosition then setCameraMatrix(unpack(deathCameraPosition)) else setCameraTarget(localPlayer) end

    dxDrawRectangle(windowX,windowY,windowWidth,windowHeight,COLOR_BACKGROUND)
    dxDrawRectangle(windowX,windowY,windowWidth,40,COLOR_TITLE_BG)
    dxDrawText("YOU ARE WASTED",windowX,windowY,windowX+windowWidth,windowY+40,COLOR_TITLE_TEXT,1.4,FONT_BOLD,"center","center")
    dxDrawLine(windowX,windowY,windowX+windowWidth,windowY,COLOR_BORDER,2); dxDrawLine(windowX,windowY+windowHeight,windowX+windowWidth,windowY+windowHeight,COLOR_BORDER,2)
    dxDrawLine(windowX,windowY,windowX,windowY+windowHeight,COLOR_BORDER,2); dxDrawLine(windowX+windowWidth,windowY,windowX+windowWidth,windowY+windowHeight,COLOR_BORDER,2)

    local remainingTimeMs = math.max(0, deathTimerEndTime - getTickCount())
    local contentY = windowY + 50 -- Initialisiere contentY hier oben
    local deathInfoText = "Killed by: #d94444" .. killerName .. " #ffffffwith #aae0ff" .. weaponName
    dxDrawText(deathInfoText,windowX,contentY,windowX+windowWidth,contentY+20,COLOR_TEXT_LIGHT,1.1,FONT_BOLD,"center","top",false,false,false,true,true)
    contentY=contentY+30 -- contentY wird hier erhöht für den nächsten Block

    if remainingTimeMs > 0 then
        local barHeight=30; local barWidth=windowWidth-80; local barX=windowX+40; local barY=contentY+10
        local timerProgress = 1 - (remainingTimeMs / currentDeathTimerDurationMs)

        local waitText = "Respawn possible in:" -- Standardtext
        if not shouldBeJailed and currentDeathTimerDurationMs == REVIVE_WINDOW_MS_CLIENT_CHECK then
            waitText = "Waiting for Medic / Respawn in:" -- Angepasster Text
        elseif shouldBeJailed then
             waitText = "Transfer to Prison in:"
        end

        dxDrawText(waitText,windowX,barY-25,windowX+windowWidth,barY,COLOR_TEXT_LIGHT,1.1,FONT_BOLD,"center","bottom")
        dxDrawRectangle(barX,barY,barWidth,barHeight,COLOR_BAR_BG)
        dxDrawRectangle(barX,barY,barWidth*(1-timerProgress),barHeight,COLOR_BAR_FG)
        dxDrawLine(barX,barY,barX+barWidth,barY,COLOR_BORDER,1); dxDrawLine(barX,barY+barHeight,barX+barWidth,barY+barHeight,COLOR_BORDER,1)
        dxDrawLine(barX,barY,barX,barY+barHeight,COLOR_BORDER,1); dxDrawLine(barX+barWidth,barY,barX+barWidth,barY+barHeight,COLOR_BORDER,1)
        dxDrawText(string.format("%d seconds remaining",math.ceil(remainingTimeMs/1000)),barX,barY,barX+barWidth,barY+barHeight,COLOR_TITLE_TEXT,1.0,FONT_BOLD,"center","center")

        local infoTextY=barY+barHeight+20
        local infoText = " "
        if not shouldBeJailed and currentDeathTimerDurationMs == REVIVE_WINDOW_MS_CLIENT_CHECK then
            infoText = "Medics have been notified."
        elseif shouldBeJailed then
            infoText = "You are being processed due to your wanted level."
        end
        dxDrawText(infoText,windowX,infoTextY,windowX+windowWidth,infoTextY+25,COLOR_TEXT_MEDIUM,1.2,FONT_BOLD,"center","top")

    else -- remainingTimeMs <= 0
        -- **** DEBUGGING START ****
        --outputChatBox("DEBUG: Timer abgelaufen. isDeathScreenActive: " .. tostring(isDeathScreenActive))
        --outputChatBox("DEBUG: Initial showSpawnButtons: " .. tostring(showSpawnButtons))
        --outputChatBox("DEBUG: Initial shouldBeJailed: " .. tostring(shouldBeJailed))
        -- **** DEBUGGING ENDE ****

        if not showSpawnButtons then
            if shouldBeJailed then
                triggerServerEvent("requestAutomaticJailSpawn",localPlayer)
                dxDrawText("Transferring to Prison...",windowX,contentY+20,windowX+windowWidth,contentY+50,COLOR_TEXT_LIGHT,1.3,FONT_BOLD,"center","center")
                setTimer(closeDeathScreenV9, 1500, 1)
                showSpawnButtons=true
                outputChatBox("DEBUG: shouldBeJailed=true, showSpawnButtons jetzt: " .. tostring(showSpawnButtons)) -- DEBUG
            else -- NICHT shouldBeJailed
                showSpawnButtons=true
                outputChatBox("DEBUG: shouldBeJailed=false, showSpawnButtons jetzt: " .. tostring(showSpawnButtons)) -- DEBUG
                if not isCursorShowing()then showCursor(true)end
            end
        end

        -- Hier wird contentY für "Choose your Spawn Location" verwendet.
        -- Dieser contentY ist windowY + 50 + 30 = windowY + 80
        if showSpawnButtons and not shouldBeJailed then
            --outputChatBox("DEBUG: Buttons sollten jetzt gezeichnet werden.") -- DEBUG
            dxDrawText("Choose your Spawn Location:",windowX,contentY,windowX+windowWidth,contentY+25,COLOR_TEXT_LIGHT,1.2,FONT_BOLD,"center","top")
            local btnW,btnH=130,50; local btnSpacing=15; local totalBtnW=(btnW*3)+(btnSpacing*2)
            local btnStartX=windowX+(windowWidth-totalBtnW)/2;
            local btnYpos=contentY+40 -- btnYpos wird windowY + 80 + 40 = windowY + 120
            drawButtonV9("City",btnStartX,btnYpos,btnW,btnH,COLOR_BUTTON_CITY,COLOR_BUTTON_HOVER,COLOR_BUTTON_TEXT)
            local btnHomeX=btnStartX+btnW+btnSpacing
            drawButtonV9("Home",btnHomeX,btnYpos,btnW,btnH,COLOR_BUTTON_HOME,COLOR_BUTTON_HOVER,COLOR_BUTTON_TEXT)
            local btnFactionX=btnHomeX+btnW+btnSpacing
            drawButtonV9("Faction",btnFactionX,btnYpos,btnW,btnH,COLOR_BUTTON_FACTION,COLOR_BUTTON_HOVER,COLOR_BUTTON_TEXT)
        else
            if remainingTimeMs <= 0 then -- Nur loggen, wenn Timer abgelaufen ist und Buttons NICHT gezeigt werden
                 --outputChatBox("DEBUG: Timer abgelaufen, aber Buttons werden NICHT gezeichnet. showSpawnButtons: " .. tostring(showSpawnButtons) .. ", shouldBeJailed: " .. tostring(shouldBeJailed)) -- DEBUG
            end
        end
    end
end

addEventHandler("onClientClick", root, function(button, state, cursorX, cursorY)
    if not isDeathScreenActive or button ~= "left" or state ~= "up" then return end
    if not showSpawnButtons or shouldBeJailed then return end

    local btnW,btnH=130,50; local btnSpacing=15; local totalBtnWidth=(btnW*3)+(btnSpacing*2)
    local btnStartX=windowX+(windowWidth-totalBtnWidth)/2
    -- Wichtig: contentY muss hier dem Wert entsprechen, der beim Zeichnen der Buttons verwendet wurde.
    -- Oben im Render: contentY wird nach der Killer-Info auf windowY + 80 gesetzt.
    local contentY_click = windowY + 80
    local btnY_click = contentY_click + 40 -- (windowY + 80) + 40 = windowY + 120
    local btnHomeX=btnStartX+btnW+btnSpacing; local btnFactionX=btnHomeX+btnW+btnSpacing

    if cursorX>=btnStartX and cursorX<=btnStartX+btnW and cursorY>=btnY_click and cursorY<=btnY_click+btnH then
        triggerServerEvent("onSpawnRequestCity",localPlayer); closeDeathScreenV9()
    elseif cursorX>=btnHomeX and cursorX<=btnHomeX+btnW and cursorY>=btnY_click and cursorY<=btnY_click+btnH then
        triggerServerEvent("onSpawnRequestHome",localPlayer); closeDeathScreenV9()
    elseif cursorX>=btnFactionX and cursorX<=btnFactionX+btnW and cursorY>=btnY_click and cursorY<=btnY_click+btnH then
        triggerServerEvent("onSpawnRequestFactionBase",localPlayer); closeDeathScreenV9()
    end
end)

function closeDeathScreenV9()
    if not isDeathScreenActive then return end
    isDeathScreenActive=false; showSpawnButtons=false; shouldBeJailed=false
    deathTimerEndTime=0; deathCameraPosition=nil; killerName="N/A"; weaponName="N/A"
    currentDeathTimerDurationMs = 15 * 1000
    if renderDeathScreenHandler then
        if isEventHandlerAdded("onClientRender", root, renderDeathScreenHandler) then
            removeEventHandler("onClientRender",root,renderDeathScreenHandler)
        end
        renderDeathScreenHandler = nil
    end
    toggleAllControls(true,true,true)
    setCameraTarget(localPlayer)
    if isCursorShowing() then showCursor(false) end
end

addEventHandler("onClientPlayerQuit",localPlayer,function() closeDeathScreenV9() end)
addEventHandler("onClientResourceStop",resourceRoot,function() closeDeathScreenV9() end)

--outputDebugString("[DeathSpawn V9] Spawn-nach-Tod GUI (Client - Textanpassung für Medic Timer, DEBUG-VERSION) geladen.")