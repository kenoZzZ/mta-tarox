-- casinorob_client.lua
-- Basierend auf bankrob_client.lua V4.2, angepasst für Casino-Raub
-- HINZUGEFÜGT: Schwebender Text für Belohnungsmarker, Alarm-Sound Handling (Pfad korrigiert), Fix für destroyElement in closeCasinoConfirmActionWindow

-- ////////////////////////////////////////////////////////////////////
-- // HILFSFUNKTION FÜR ZAHLENFORMATIERUNG
-- ////////////////////////////////////////////////////////////////////
function formatWithThousandSepClient(number)
    if type(number) ~= "number" then return tostring(number) end
    local s = string.format("%.0f", number)
    local len = #s
    if len <= 3 then return s end
    local res = ""
    for i=1,len do
        res = res .. s:sub(i,i)
        if (len-i) % 3 == 0 and i ~= len and s:sub(i+1,i+1) ~= '-' then
            res = res .. "."
        end
    end
    return res
end

-- ////////////////////////////////////////////////////////////////////
-- // VARIABLEN & EINSTELLUNGEN
-- ////////////////////////////////////////////////////////////////////
local casinoRobberyTimerActive = false
local casinoRobberyEndTime = 0
local casinoCopsOnline = 0
local casinoGangstersInArea = 0

local casinoCooldownActive = false
local casinoCooldownEndTime = 0

local casinoActionInProgress = false
local casinoActionProgressEndTime = 0
local CASINO_ACTION_BAR_DURATION = 15 * 1000

local casinoConfirmWindow = nil
local casinoConfirmLabel = nil
local casinoConfirmYesButton = nil
local casinoConfirmNoButton = nil
local casinoConfirmActionTypeClient = ""
local casinoConfirmItemUsedClient = nil

local screenW, screenH = guiGetScreenSize()
local casinoPoliceBlips = {}
local isCasinoRobberyInfoRenderActive = false

local currentCasinoRewardAmount = 0
local casinoRewardDisplayMarkerElement = nil
local isCasinoRewardTextRenderActive = false
local hasTriedToFindMarker = false 
local CASINO_INTERIOR_ID = 1 
local CASINO_INTERIOR_DIMENSION = 0 

local casinoAlarmSoundElement = nil
local CASINO_ALARM_SOUND_PATH = "casinorob/files/sounds/alarm.mp3" 
local isCasinoAlarmPlaying = false


-- ////////////////////////////////////////////////////////////////////
-- // DX FUNKTIONEN (Timer & Info Anzeige)
-- ////////////////////////////////////////////////////////////////////
function renderCasinoRobberyInfo()
    if not casinoRobberyTimerActive and not casinoCooldownActive and not casinoActionInProgress then
        if isCasinoRobberyInfoRenderActive then
            removeEventHandler("onClientRender", root, renderCasinoRobberyInfo)
            isCasinoRobberyInfoRenderActive = false
        end
        return
    end

    local yPos = screenH * 0.25; local lineHeight = 18
    local textColor = tocolor(255,255,255,230); local shadowColor = tocolor(0,0,0,150)
    local valueColor = tocolor(255,200,0); local robColor = tocolor(255,80,80); local cooldownColor = tocolor(150,150,255)

    if casinoRobberyTimerActive then
        local remainingMs = casinoRobberyEndTime - getTickCount()
        if remainingMs <= 0 then casinoRobberyTimerActive = false
        else
            local totalSec = math.floor(remainingMs/1000); local min=math.floor(totalSec/60); local sec=totalSec%60
            local timeStr=string.format("%02d:%02d",min,sec)
            dxDrawText("Casinoraub läuft!",10+1,yPos+1,screenW,yPos+lineHeight+1,shadowColor,1.2,"default-bold")
            dxDrawText("Casinoraub läuft!",10,yPos,screenW,yPos+lineHeight,robColor,1.2,"default-bold"); yPos=yPos+lineHeight+2
            dxDrawText("Verbleibende Zeit: #FFFFFF"..timeStr,12+1,yPos+1,screenW,yPos+lineHeight+1,shadowColor,1.0,"default-bold","left","top",false,false,false,true)
            dxDrawText("Verbleibende Zeit: #FFFFFF"..timeStr,12,yPos,screenW,yPos+lineHeight,valueColor,1.0,"default-bold","left","top",false,false,false,true); yPos=yPos+lineHeight
            dxDrawText("Polizisten im Dienst: #FFFFFF"..casinoCopsOnline,12+1,yPos+1,screenW,yPos+lineHeight+1,shadowColor,1.0,"default-bold","left","top",false,false,false,true)
            dxDrawText("Polizisten im Dienst: #FFFFFF"..casinoCopsOnline,12,yPos,screenW,yPos+lineHeight,textColor,1.0,"default-bold","left","top",false,false,false,true); yPos=yPos+lineHeight
            dxDrawText("Verbrecher im Casino: #FFFFFF"..casinoGangstersInArea,12+1,yPos+1,screenW,yPos+lineHeight+1,shadowColor,1.0,"default-bold","left","top",false,false,false,true)
            dxDrawText("Verbrecher im Casino: #FFFFFF"..casinoGangstersInArea,12,yPos,screenW,yPos+lineHeight,textColor,1.0,"default-bold","left","top",false,false,false,true); yPos=yPos+lineHeight+5
        end
    end
    if casinoCooldownActive then
        local remainingMs = casinoCooldownEndTime - getTickCount()
        if remainingMs <= 0 then casinoCooldownActive = false
        else
            local totalSec = math.floor(remainingMs/1000); local min=math.floor(totalSec/60); local sec=totalSec%60
            local timeStr=string.format("%02d:%02d",min,sec)
            dxDrawText("Casino Cooldown: #FFFFFF"..timeStr,10+1,yPos+1,screenW,yPos+lineHeight+1,shadowColor,1.1,"default-bold","left","top",false,false,false,true)
            dxDrawText("Casino Cooldown: #FFFFFF"..timeStr,10,yPos,screenW,yPos+lineHeight,cooldownColor,1.1,"default-bold","left","top",false,false,false,true)
        end
    end
    if casinoActionInProgress then
        local remainingMs = casinoActionProgressEndTime - getTickCount()
        if remainingMs <= 0 then casinoActionInProgress = false
        else
            local progress=1-(remainingMs/CASINO_ACTION_BAR_DURATION); local barW,barH=250,22; local barX=(screenW-barW)/2; local barY=screenH*0.85
            dxDrawRectangle(barX-2,barY-2,barW+4,barH+4,tocolor(10,10,10,200)); dxDrawRectangle(barX,barY,barW,barH,tocolor(50,50,50,220))
            dxDrawRectangle(barX,barY,barW*progress,barH,tocolor(0,150,255,220)); dxDrawText(string.format("Aktion läuft... %.1fs",remainingMs/1000),barX,barY,barX+barW,barY+barH,tocolor(255,255,255),1.0,"default-bold","center","center")
        end
    end
end

function ensureCasinoRenderHandlerActive()
    if not isCasinoRobberyInfoRenderActive and (casinoRobberyTimerActive or casinoCooldownActive or casinoActionInProgress) then
        addEventHandler("onClientRender",root,renderCasinoRobberyInfo); isCasinoRobberyInfoRenderActive=true
    end
end
function checkAndRemoveCasinoRenderHandler()
    if isCasinoRobberyInfoRenderActive and not casinoRobberyTimerActive and not casinoCooldownActive and not casinoActionInProgress then
        removeEventHandler("onClientRender",root,renderCasinoRobberyInfo); isCasinoRobberyInfoRenderActive=false
    end
end

-- ////////////////////////////////////////////////////////////////////
-- // ALARM SOUND FUNKTIONEN
-- ////////////////////////////////////////////////////////////////////
function playStopCasinoAlarm(play)
    if play then
        if not isCasinoAlarmPlaying and not isElement(casinoAlarmSoundElement) then
            if getElementInterior(localPlayer) == CASINO_INTERIOR_ID and getElementDimension(localPlayer) == CASINO_INTERIOR_DIMENSION then
                casinoAlarmSoundElement = playSound(CASINO_ALARM_SOUND_PATH, true) 
                if isElement(casinoAlarmSoundElement) then
                    setSoundVolume(casinoAlarmSoundElement, 0.6) 
                    isCasinoAlarmPlaying = true
                end
            end
        end
    else
        if isElement(casinoAlarmSoundElement) then
            stopSound(casinoAlarmSoundElement)
            destroyElement(casinoAlarmSoundElement)
            casinoAlarmSoundElement = nil
        end
        isCasinoAlarmPlaying = false
    end
end

-- ////////////////////////////////////////////////////////////////////
-- // DX FUNKTIONEN für schwebenden Belohnungstext
-- ////////////////////////////////////////////////////////////////////
function findCasinoRewardMarkerAndStartRenderer()
    if isElement(casinoRewardDisplayMarkerElement) and getElementDimension(casinoRewardDisplayMarkerElement) == CASINO_INTERIOR_DIMENSION then
    else
        casinoRewardDisplayMarkerElement = nil 
        local markers = getElementsByType("marker")
        for _, marker in ipairs(markers) do
            if getElementData(marker, "isCasinoRewardDisplayMarker") == true and
               getElementDimension(marker) == CASINO_INTERIOR_DIMENSION and
               getElementInterior(marker) == CASINO_INTERIOR_ID then
                casinoRewardDisplayMarkerElement = marker
                break
            end
        end
    end
    hasTriedToFindMarker = true 

    if isElement(casinoRewardDisplayMarkerElement) then
        if not isCasinoRewardTextRenderActive then
            addEventHandler("onClientRender", root, renderCasinoRewardText)
            isCasinoRewardTextRenderActive = true
        end
    elseif isCasinoRewardTextRenderActive then 
        removeEventHandler("onClientRender", root, renderCasinoRewardText)
        isCasinoRewardTextRenderActive = false
    end
end

function renderCasinoRewardText()
    local playerInterior = getElementInterior(localPlayer)
    local playerDimension = getElementDimension(localPlayer)

    if playerInterior ~= CASINO_INTERIOR_ID or playerDimension ~= CASINO_INTERIOR_DIMENSION then
        if isCasinoRewardTextRenderActive then
            removeEventHandler("onClientRender", root, renderCasinoRewardText)
            isCasinoRewardTextRenderActive = false
            casinoRewardDisplayMarkerElement = nil
            hasTriedToFindMarker = false 
        end
        return
    end

    if not isElement(casinoRewardDisplayMarkerElement) then
        if not hasTriedToFindMarker then
            findCasinoRewardMarkerAndStartRenderer()
        end
        if not isElement(casinoRewardDisplayMarkerElement) then 
             if isCasinoRewardTextRenderActive then
                removeEventHandler("onClientRender", root, renderCasinoRewardText)
                isCasinoRewardTextRenderActive = false
            end
            return
        end
    end

    local mx, my, mz = getElementPosition(casinoRewardDisplayMarkerElement)
    local px, py, pz = getElementPosition(localPlayer)
    local distance = getDistanceBetweenPoints3D(px, py, pz, mx, my, mz)

    if distance < 20 then 
        local text = "$" .. formatWithThousandSepClient(currentCasinoRewardAmount)
        local textScale = 1.0
        local textFont = "default-bold"
        local textColorValue = tocolor(255, 223, 0, 230) 
        local textShadowColorValue = tocolor(0,0,0,180)

        local screenX, screenY = getScreenFromWorldPosition(mx, my, mz + 0.8)

        if screenX and screenY then
            local textWidth = dxGetTextWidth(text, textScale, textFont)
            local drawX = screenX - (textWidth / 2)
            local drawY = screenY - 10

            dxDrawText(text, drawX + 1, drawY + 1, drawX + textWidth + 1, drawY + 20 + 1, textShadowColorValue, textScale, textFont, "left", "top", false, false, false, true)
            dxDrawText(text, drawX, drawY, drawX + textWidth, drawY + 20, textColorValue, textScale, textFont, "left", "top", false, false, false, true)
        end
    end
end

-- ////////////////////////////////////////////////////////////////////
-- // EVENT HANDLER (CLIENT SEITIG)
-- ////////////////////////////////////////////////////////////////////
addEvent("casinorob:startRobberyTimer",true); addEventHandler("casinorob:startRobberyTimer",root,function(durationMs) casinoRobberyTimerActive=true;casinoRobberyEndTime=getTickCount()+durationMs;ensureCasinoRenderHandlerActive() end)
addEvent("casinorob:stopRobberyTimer",true); addEventHandler("casinorob:stopRobberyTimer",root,function() 
    casinoRobberyTimerActive=false;
    checkAndRemoveCasinoRenderHandler();
    if isCasinoAlarmPlaying then playStopCasinoAlarm(false) end 
end)
addEvent("casinorob:updateRobberyInfo",true); addEventHandler("casinorob:updateRobberyInfo",root,function(cops,robbers) casinoCopsOnline=cops;casinoGangstersInArea=robbers end)
addEvent("casinorob:cooldownUpdate",true); addEventHandler("casinorob:cooldownUpdate",root,function(durationMs) if durationMs>0 then casinoCooldownActive=true;casinoCooldownEndTime=getTickCount()+durationMs else casinoCooldownActive=false end; ensureCasinoRenderHandlerActive(); checkAndRemoveCasinoRenderHandler() end)

addEvent("casinorob:updateRewardDisplay", true)
addEventHandler("casinorob:updateRewardDisplay", root, function(rewardAmount)
    currentCasinoRewardAmount = rewardAmount or 0
    local playerInterior = getElementInterior(localPlayer)
    local playerDimension = getElementDimension(localPlayer)

    if playerInterior == CASINO_INTERIOR_ID and playerDimension == CASINO_INTERIOR_DIMENSION then
        if not hasTriedToFindMarker or not isElement(casinoRewardDisplayMarkerElement) then
            findCasinoRewardMarkerAndStartRenderer()
        elseif not isCasinoRewardTextRenderActive and isElement(casinoRewardDisplayMarkerElement) then
            addEventHandler("onClientRender", root, renderCasinoRewardText)
            isCasinoRewardTextRenderActive = true
        end
    else
        if isCasinoRewardTextRenderActive then
            removeEventHandler("onClientRender", root, renderCasinoRewardText)
            isCasinoRewardTextRenderActive = false
        end
    end
end)

addEvent("casinorob:stopRewardDisplay", true)
addEventHandler("casinorob:stopRewardDisplay", root, function()
    if isCasinoRewardTextRenderActive then
        removeEventHandler("onClientRender", root, renderCasinoRewardText)
        isCasinoRewardTextRenderActive = false
        casinoRewardDisplayMarkerElement = nil
        hasTriedToFindMarker = false
    end
end)

addEventHandler("onClientElementDataChange",localPlayer,function(dataName)
    if dataName=="casinorob:isDoingAction" then
        casinoActionInProgress = getElementData(localPlayer,"casinorob:isDoingAction") or false
        if casinoActionInProgress then
            casinoActionProgressEndTime = getTickCount() + CASINO_ACTION_BAR_DURATION
        end
        ensureCasinoRenderHandlerActive();
        checkAndRemoveCasinoRenderHandler()
    end
end)

addEvent("casinorob:requestActionConfirmation",true)
addEventHandler("casinorob:requestActionConfirmation",root,function(message,actionType,itemID)
    if isElement(casinoConfirmWindow)then closeCasinoConfirmActionWindow()end
    local w,h=380,170; local x=(screenW-w)/2; local y=(screenH-h)/2
    casinoConfirmWindow=guiCreateWindow(x,y,w,h,"Casino Aktion Bestätigung",false); guiWindowSetSizable(casinoConfirmWindow,false); guiSetProperty(casinoConfirmWindow,"AlwaysOnTop","True")
    casinoConfirmLabel=guiCreateLabel(0.05,0.10,0.9,0.50,message,true,casinoConfirmWindow); guiLabelSetHorizontalAlign(casinoConfirmLabel,"center",true); guiLabelSetVerticalAlign(casinoConfirmLabel,"center")
    casinoConfirmYesButton=guiCreateButton(0.15,0.70,0.3,0.2,"Ja",true,casinoConfirmWindow); guiSetProperty(casinoConfirmYesButton,"NormalTextColour","FFA0D8A0")
    casinoConfirmNoButton=guiCreateButton(0.55,0.70,0.3,0.2,"Nein",true,casinoConfirmWindow); guiSetProperty(casinoConfirmNoButton,"NormalTextColour","FFFFB0B0")
    casinoConfirmActionTypeClient=actionType; casinoConfirmItemUsedClient=itemID
    addEventHandler("onClientGUIClick",casinoConfirmYesButton,handleCasinoConfirmAction,false);
    addEventHandler("onClientGUIClick",casinoConfirmNoButton,closeCasinoConfirmActionWindow,false);
    addEventHandler("onClientKey",root,handleCasinoConfirmEscapeKey,false)
    showCursor(true); guiSetInputMode("no_binds_when_editing")
end)

function handleCasinoConfirmAction()
    if source==casinoConfirmYesButton then
        triggerServerEvent("casinorob:confirmAction",localPlayer,casinoConfirmActionTypeClient,casinoConfirmItemUsedClient)
        closeCasinoConfirmActionWindow()
    end
end

function closeCasinoConfirmActionWindow()
    if isElement(casinoConfirmYesButton)then removeEventHandler("onClientGUIClick",casinoConfirmYesButton,handleCasinoConfirmAction,false); destroyElement(casinoConfirmYesButton); casinoConfirmYesButton = nil; end
    if isElement(casinoConfirmNoButton)then removeEventHandler("onClientGUIClick",casinoConfirmNoButton,closeCasinoConfirmActionWindow,false); destroyElement(casinoConfirmNoButton); casinoConfirmNoButton = nil; end
    if isElement(casinoConfirmLabel)then destroyElement(casinoConfirmLabel); casinoConfirmLabel = nil; end
    if isElement(casinoConfirmWindow)then
        removeEventHandler("onClientKey",root,handleCasinoConfirmEscapeKey,false);
        destroyElement(casinoConfirmWindow);
        casinoConfirmWindow=nil;
    end
    
    casinoConfirmActionTypeClient = ""
    casinoConfirmItemUsedClient = nil

    local loginVisible=getElementData(getLocalPlayer(),"loginScreenActive")
    if not loginVisible then
        showCursor(false); guiSetInputMode("allow_binds")
    end
end

function handleCasinoConfirmEscapeKey(key,press)
    if key=="escape"and press and isElement(casinoConfirmWindow)then
        closeCasinoConfirmActionWindow()
    end
end

addEvent("casinorob:startPoliceNotification",true)
addEventHandler("casinorob:startPoliceNotification",root,function(blipX,blipY,blipZ,casinoName)
    if isElement(casinoPoliceBlips[casinoName])then destroyElement(casinoPoliceBlips[casinoName])end
    local blip=createBlip(blipX,blipY,blipZ,16,2,255,0,0,255,0,99999);
    if isElement(blip)then
        setBlipVisibleDistance(blip,3000);
        casinoPoliceBlips[casinoName]=blip
    end
    outputChatBox("[ALARM] Einbruch im: "..casinoName,255,50,50); playSoundFrontEnd(4)
end)

addEvent("casinorob:stopPoliceNotification",true)
addEventHandler("casinorob:stopPoliceNotification",root,function(casinoName)
    if isElement(casinoPoliceBlips[casinoName])then
        destroyElement(casinoPoliceBlips[casinoName]);
        casinoPoliceBlips[casinoName]=nil
    end
end)

addEvent("casinoRob:playExplosionEffect", true)
addEventHandler("casinoRob:playExplosionEffect",resourceRoot,function(pos)
    if pos and pos.x and pos.y and pos.z then
        createExplosion(pos.x,pos.y,pos.z,12)
    end
end)

addEvent("casinoRob:showNotification", true)
addEventHandler("casinoRob:showNotification",resourceRoot,function(message,r,g,b)
    outputChatBox("[Casino] "..(message or ""),r or 255,g or 255,b or 255)
end)

addEvent("casinorob:playAlarmSound", true)
addEventHandler("casinorob:playAlarmSound", resourceRoot, playStopCasinoAlarm)

addEventHandler("onClientPlayerWarped", localPlayer, function(previousInterior, previousDimension)
    if getElementInterior(localPlayer) ~= CASINO_INTERIOR_ID or getElementDimension(localPlayer) ~= CASINO_INTERIOR_DIMENSION then
        if isCasinoAlarmPlaying then
            playStopCasinoAlarm(false)
        end
    end
end)

-- ////////////////////////////////////////////////////////////////////
-- // RESOURCE START/STOP & AUFRÄUMEN
-- ////////////////////////////////////////////////////////////////////
function cleanupClientCasinoRobState()
    casinoRobberyTimerActive=false;casinoCooldownActive=false;casinoActionInProgress=false;
    checkAndRemoveCasinoRenderHandler()
    closeCasinoConfirmActionWindow()
    for _,blip in pairs(casinoPoliceBlips)do if isElement(blip)then destroyElement(blip)end end; casinoPoliceBlips={}

    if isCasinoRewardTextRenderActive then
        removeEventHandler("onClientRender", root, renderCasinoRewardText)
        isCasinoRewardTextRenderActive = false
    end
    casinoRewardDisplayMarkerElement = nil
    currentCasinoRewardAmount = 0
    hasTriedToFindMarker = false
    
    playStopCasinoAlarm(false) 

    local loginVisible=getElementData(getLocalPlayer(),"loginScreenActive")
    if not loginVisible then
        showCursor(false);guiSetInputMode("allow_binds")
    end
    --outputDebugString("[CasinoRob Client] Zustand Reset.")
end

addEventHandler("onClientResourceStart",resourceRoot,function()
    cleanupClientCasinoRobState()
    --outputDebugString("[CasinoRob Client] CasinoRaub System (V2 & Alarm - Pfad/destroy Fix V2) geladen.")
    local playerInterior = getElementInterior(localPlayer)
    local playerDimension = getElementDimension(localPlayer)
    if playerInterior == CASINO_INTERIOR_ID and playerDimension == CASINO_INTERIOR_DIMENSION then
        findCasinoRewardMarkerAndStartRenderer()
    end
end)

addEventHandler("onClientPlayerQuit",localPlayer,cleanupClientCasinoRobState)
addEventHandler("onClientResourceStop",resourceRoot,cleanupClientCasinoRobState)