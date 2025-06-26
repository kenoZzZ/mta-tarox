--[[
    bankrob_client.lua
    Bankraub-System (Client-Seite) V4.2
    ERWEITERT: Alarm-Sound Handling (Pfad korrigiert), Fix für destroyElement in closeConfirmActionWindow
]]

-- ////////////////////////////////////////////////////////////////////
-- // VARIABLEN & EINSTELLUNGEN
-- ////////////////////////////////////////////////////////////////////
local robberyTimerActive = false
local robberyEndTime = 0
local copsOnline = 0
local gangstersInBank = 0

local cooldownActive = false
local cooldownEndTime = 0

local actionInProgress = false
local actionProgressEndTime = 0
local ACTION_BAR_DURATION = 15 * 1000

local confirmWindow = nil
local confirmLabel = nil
local confirmYesButton = nil
local confirmNoButton = nil
local confirmActionTypeClient = ""
local confirmItemUsedClient = nil

local screenW, screenH = guiGetScreenSize()
local policeBlips = {}
local isRobberyInfoRenderActive = false

local alarmSoundElement = nil
local ALARM_SOUND_PATH = "bankrob/files/sounds/alarm.mp3" 
local isAlarmPlaying = false
local BANK_INTERIOR_ID = 3 
local BANK_INTERIOR_DIMENSION_START = 1


-- ////////////////////////////////////////////////////////////////////
-- // DX FUNKTIONEN (Timer & Info Anzeige)
-- ////////////////////////////////////////////////////////////////////

function renderBankRobberyInfo()
    if not robberyTimerActive and not cooldownActive and not actionInProgress then
        if isRobberyInfoRenderActive then
            removeEventHandler("onClientRender", root, renderBankRobberyInfo)
            isRobberyInfoRenderActive = false
        end
        return
    end

    local yPos = screenH * 0.25; local lineHeight = 18
    local textColor = tocolor(255,255,255,230); local shadowColor = tocolor(0,0,0,150)
    local valueColor = tocolor(255,200,0); local robColor = tocolor(255,80,80); local cooldownColor = tocolor(150,150,255)

    if robberyTimerActive then
        local remainingMs = robberyEndTime - getTickCount()
        if remainingMs <= 0 then robberyTimerActive = false
        else
            local totalSec = math.floor(remainingMs/1000); local min=math.floor(totalSec/60); local sec=totalSec%60
            local timeStr=string.format("%02d:%02d",min,sec)
            dxDrawText("Bankraub läuft!",10+1,yPos+1,screenW,yPos+lineHeight+1,shadowColor,1.2,"default-bold")
            dxDrawText("Bankraub läuft!",10,yPos,screenW,yPos+lineHeight,robColor,1.2,"default-bold"); yPos=yPos+lineHeight+2
            dxDrawText("Verbleibende Zeit: #FFFFFF"..timeStr,12+1,yPos+1,screenW,yPos+lineHeight+1,shadowColor,1.0,"default-bold","left","top",false,false,false,true)
            dxDrawText("Verbleibende Zeit: #FFFFFF"..timeStr,12,yPos,screenW,yPos+lineHeight,valueColor,1.0,"default-bold","left","top",false,false,false,true); yPos=yPos+lineHeight
            dxDrawText("Polizisten im Dienst: #FFFFFF"..copsOnline,12+1,yPos+1,screenW,yPos+lineHeight+1,shadowColor,1.0,"default-bold","left","top",false,false,false,true)
            dxDrawText("Polizisten im Dienst: #FFFFFF"..copsOnline,12,yPos,screenW,yPos+lineHeight,textColor,1.0,"default-bold","left","top",false,false,false,true); yPos=yPos+lineHeight
            dxDrawText("Verbrecher in der Bank: #FFFFFF"..gangstersInBank,12+1,yPos+1,screenW,yPos+lineHeight+1,shadowColor,1.0,"default-bold","left","top",false,false,false,true)
            dxDrawText("Verbrecher in der Bank: #FFFFFF"..gangstersInBank,12,yPos,screenW,yPos+lineHeight,textColor,1.0,"default-bold","left","top",false,false,false,true); yPos=yPos+lineHeight+5
        end
    end
    if cooldownActive then
        local remainingMs = cooldownEndTime - getTickCount()
        if remainingMs <= 0 then cooldownActive = false
        else
            local totalSec = math.floor(remainingMs/1000); local min=math.floor(totalSec/60); local sec=totalSec%60
            local timeStr=string.format("%02d:%02d",min,sec)
            dxDrawText("Bank Cooldown: #FFFFFF"..timeStr,10+1,yPos+1,screenW,yPos+lineHeight+1,shadowColor,1.1,"default-bold","left","top",false,false,false,true)
            dxDrawText("Bank Cooldown: #FFFFFF"..timeStr,10,yPos,screenW,yPos+lineHeight,cooldownColor,1.1,"default-bold","left","top",false,false,false,true)
        end
    end
    if actionInProgress then
        local remainingMs = actionProgressEndTime - getTickCount()
        if remainingMs <= 0 then actionInProgress = false
        else
            local progress=1-(remainingMs/ACTION_BAR_DURATION); local barW,barH=250,22; local barX=(screenW-barW)/2; local barY=screenH*0.85
            dxDrawRectangle(barX-2,barY-2,barW+4,barH+4,tocolor(10,10,10,200)); dxDrawRectangle(barX,barY,barW,barH,tocolor(50,50,50,220))
            dxDrawRectangle(barX,barY,barW*progress,barH,tocolor(0,150,255,220)); dxDrawText(string.format("Aktion läuft... %.1fs",remainingMs/1000),barX,barY,barX+barW,barY+barH,tocolor(255,255,255),1.0,"default-bold","center","center")
        end
    end
end

function ensureRenderHandlerActive()
    if not isRobberyInfoRenderActive and (robberyTimerActive or cooldownActive or actionInProgress) then
        addEventHandler("onClientRender",root,renderBankRobberyInfo); isRobberyInfoRenderActive=true
    end
end
function checkAndRemoveRenderHandler()
    if isRobberyInfoRenderActive and not robberyTimerActive and not cooldownActive and not actionInProgress then
        removeEventHandler("onClientRender",root,renderBankRobberyInfo); isRobberyInfoRenderActive=false
    end
end

-- ////////////////////////////////////////////////////////////////////
-- // ALARM SOUND FUNKTIONEN 
-- ////////////////////////////////////////////////////////////////////
function playStopBankAlarm(play)
    if play then
        if not isAlarmPlaying and not isElement(alarmSoundElement) then
            if getElementInterior(localPlayer) == BANK_INTERIOR_ID and getElementDimension(localPlayer) == BANK_INTERIOR_DIMENSION_START then
                alarmSoundElement = playSound(ALARM_SOUND_PATH, true) 
                if isElement(alarmSoundElement) then
                    setSoundVolume(alarmSoundElement, 0.6) 
                    isAlarmPlaying = true
                end
            end
        end
    else
        if isElement(alarmSoundElement) then
            stopSound(alarmSoundElement)
            destroyElement(alarmSoundElement)
            alarmSoundElement = nil
        end
        isAlarmPlaying = false
    end
end

-- ////////////////////////////////////////////////////////////////////
-- // EVENT HANDLER (CLIENT SEITIG)
-- ////////////////////////////////////////////////////////////////////
addEvent("bankrob:startRobberyTimer",true); addEventHandler("bankrob:startRobberyTimer",root,function(durationMs) robberyTimerActive=true;robberyEndTime=getTickCount()+durationMs;ensureRenderHandlerActive() end)
addEvent("bankrob:stopRobberyTimer",true); addEventHandler("bankrob:stopRobberyTimer",root,function() 
    robberyTimerActive=false;
    checkAndRemoveRenderHandler();
    if isAlarmPlaying then playStopBankAlarm(false) end 
end)
addEvent("bankrob:updateRobberyInfo",true); addEventHandler("bankrob:updateRobberyInfo",root,function(cops,robbers) copsOnline=cops;gangstersInBank=robbers end)
addEvent("bankrob:cooldownUpdate",true); addEventHandler("bankrob:cooldownUpdate",root,function(durationMs) if durationMs>0 then cooldownActive=true;cooldownEndTime=getTickCount()+durationMs else cooldownActive=false end; ensureRenderHandlerActive(); checkAndRemoveRenderHandler() end)
addEventHandler("onClientElementDataChange",localPlayer,function(dataName) if dataName=="bankrob:isDoingAction" then actionInProgress=getElementData(localPlayer,"bankrob:isDoingAction")or false; if actionInProgress then actionProgressEndTime=getTickCount()+ACTION_BAR_DURATION end; ensureRenderHandlerActive(); checkAndRemoveRenderHandler() end end)

addEvent("bankrob:requestActionConfirmation",true)
addEventHandler("bankrob:requestActionConfirmation",root,function(message,actionType,itemID)
    if isElement(confirmWindow)then closeConfirmActionWindow()end
    local w,h=380,170; local x=(screenW-w)/2; local y=(screenH-h)/2
    confirmWindow=guiCreateWindow(x,y,w,h,"Bankraub Aktion Bestätigung",false); guiWindowSetSizable(confirmWindow,false); guiSetProperty(confirmWindow,"AlwaysOnTop","True")
    confirmLabel=guiCreateLabel(0.05,0.10,0.9,0.50,message,true,confirmWindow); guiLabelSetHorizontalAlign(confirmLabel,"center",true); guiLabelSetVerticalAlign(confirmLabel,"center")
    confirmYesButton=guiCreateButton(0.15,0.70,0.3,0.2,"Ja",true,confirmWindow); guiSetProperty(confirmYesButton,"NormalTextColour","FFA0D8A0")
    confirmNoButton=guiCreateButton(0.55,0.70,0.3,0.2,"Nein",true,confirmWindow); guiSetProperty(confirmNoButton,"NormalTextColour","FFFFB0B0")
    confirmActionTypeClient=actionType; confirmItemUsedClient=itemID
    addEventHandler("onClientGUIClick",confirmYesButton,handleConfirmAction,false); addEventHandler("onClientGUIClick",confirmNoButton,closeConfirmActionWindow,false); addEventHandler("onClientKey",root,handleConfirmEscapeKey,false)
    showCursor(true); guiSetInputMode("no_binds_when_editing")
end)

function handleConfirmAction() 
    if source==confirmYesButton then 
        triggerServerEvent("bankrob:confirmAction",localPlayer,confirmActionTypeClient,confirmItemUsedClient)
        closeConfirmActionWindow()
    end 
end

function closeConfirmActionWindow()
    -- Remove event handlers first to prevent them from firing during destruction
    if isElement(confirmYesButton) then removeEventHandler("onClientGUIClick", confirmYesButton, handleConfirmAction, false) end
    if isElement(confirmNoButton) then removeEventHandler("onClientGUIClick", confirmNoButton, closeConfirmActionWindow, false) end
    if isElement(confirmWindow) then removeEventHandler("onClientKey", root, handleConfirmEscapeKey, false) end

    -- Destroy elements if they exist
    if isElement(confirmYesButton) then destroyElement(confirmYesButton); confirmYesButton = nil; end
    if isElement(confirmNoButton) then destroyElement(confirmNoButton); confirmNoButton = nil; end
    if isElement(confirmLabel) then destroyElement(confirmLabel); confirmLabel = nil; end
    if isElement(confirmWindow) then destroyElement(confirmWindow); confirmWindow = nil; end
    
    confirmActionTypeClient = ""
    confirmItemUsedClient = nil
    
    local loginVisible = getElementData(getLocalPlayer(), "loginScreenActive")
    if not loginVisible then 
        showCursor(false)
        guiSetInputMode("allow_binds") 
    end
end

function handleConfirmEscapeKey(key,press) 
    if key=="escape" and press and isElement(confirmWindow) then 
        closeConfirmActionWindow()
    end 
end

addEvent("bankrob:startPoliceNotification",true)
addEventHandler("bankrob:startPoliceNotification",root,function(blipX,blipY,blipZ,bankName)
    if isElement(policeBlips[bankName])then destroyElement(policeBlips[bankName])end
    local blip=createBlip(blipX,blipY,blipZ,16,2,255,0,0,255,0,99999); if isElement(blip)then setBlipVisibleDistance(blip,3000);policeBlips[bankName]=blip end
    outputChatBox("[ALARM] Bankraub bei: "..bankName,255,50,50); playSoundFrontEnd(4)
end)
addEvent("bankrob:stopPoliceNotification",true)
addEventHandler("bankrob:stopPoliceNotification",root,function(bankName) if isElement(policeBlips[bankName])then destroyElement(policeBlips[bankName]);policeBlips[bankName]=nil end end)

addEvent("bankrob:playAlarmSound", true)
addEventHandler("bankrob:playAlarmSound", resourceRoot, playStopBankAlarm)

addEventHandler("onClientPlayerWarped", localPlayer, function(previousInterior, previousDimension)
    if getElementInterior(localPlayer) ~= BANK_INTERIOR_ID or getElementDimension(localPlayer) ~= BANK_INTERIOR_DIMENSION_START then
        if isAlarmPlaying then
            playStopBankAlarm(false)
        end
    end
end)

-- ////////////////////////////////////////////////////////////////////
-- // RESOURCE START/STOP & AUFRÄUMEN
-- ////////////////////////////////////////////////////////////////////
function cleanupClientBankRobState()
    robberyTimerActive=false;cooldownActive=false;actionInProgress=false; checkAndRemoveRenderHandler()
    closeConfirmActionWindow()
    for _,blip in pairs(policeBlips)do if isElement(blip)then destroyElement(blip)end end; policeBlips={}
    
    playStopBankAlarm(false)

    local loginVisible=getElementData(getLocalPlayer(),"loginScreenActive")
    if not loginVisible then showCursor(false);guiSetInputMode("allow_binds")end
    --outputDebugString("[BankRob Client] Zustand Reset.")
end
addEventHandler("onClientResourceStart",resourceRoot,cleanupClientBankRobState)
addEventHandler("onClientPlayerQuit",localPlayer,cleanupClientBankRobState) 
addEventHandler("onClientResourceStop",resourceRoot,cleanupClientBankRobState)
--outputDebugString("[BankRob] Client V4.2 (mit Alarm - Pfad Fix, destroyElement Fix V2) geladen.")