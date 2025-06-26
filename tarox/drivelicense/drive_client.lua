-- tarox/drivelicense/drive_client.lua
-- Version mit Checkpoint Dim/Int Fix und neuer KM/H Anzeige

local screenW, screenH = guiGetScreenSize()
local localPlayer = getLocalPlayer()

local isDriveMenuVisible = false
local availableLicensesGUI = {}
local selectedLicenseIndex = 1
local isTheoryTestVisible = false
local currentTheoryQuestion = {}
local currentQuestionNum = 0
local totalQuestions = 0
local selectedTheoryAnswer = nil
local isConfirmPracticalVisible = false
local confirmPracticalData = {}
local isPracticalTestActive = false
local practicalTestVehicle = nil
local practicalCheckpoints = {}
local currentCheckpointIndexClient = 0
local practicalTestBlipsAndMarkers = {}

local colors = {
    bg = tocolor(28,30,36,230), headerBg = tocolor(0,120,180,240), headerText = tocolor(240,240,245),
    itemBg = tocolor(40,43,51,210), itemText = tocolor(220,220,225), itemCostText = tocolor(130,230,130),
    itemOwnedText = tocolor(100,200,250), itemPendingText = tocolor(255,180,90), itemDisabledText = tocolor(150,150,160),
    selectedItemBg = tocolor(0,152,224,220), buttonBg = tocolor(70,75,85,220), buttonHoverBg = tocolor(90,95,105,230),
    buttonDisabledBg = tocolor(50,50,55,200), buttonText = tocolor(235,235,240), questionText = tocolor(230,230,235),
    answerText = tocolor(210,210,215), selectedAnswerBg = tocolor(0,152,224,190),
    speedTextColor = tocolor(255, 255, 255, 230), -- NEU: Farbe für KM/H Anzeige
    speedTextShadowColor = tocolor(0,0,0,180)    -- NEU: Schatten für KM/H Anzeige
}
local windowWidth,windowHeight=520,400; local windowX,windowY=(screenW-windowWidth)/2,(screenH-windowHeight)/2
local uiElements={closeButton={},actionButton={},theoryAnswerButtons={}}
local THEORY_ANSWER_HEIGHT=38; local THEORY_ANSWER_SPACING=8
local renderHandlerActive,keyHandlerActive,clickHandlerActive=false,false,false

if _G.isPedGuiOpen==nil then _G.isPedGuiOpen=false end; if _G.isInventoryVisible==nil then _G.isInventoryVisible=false end
if _G.isDriveMenuVisible==nil then _G.isDriveMenuVisible=false end; if _G.isTheoryTestVisible==nil then _G.isTheoryTestVisible=false end
if _G.isConfirmPracticalVisible==nil then _G.isConfirmPracticalVisible=false end
if _G.idPurchaseConfirmVisible==nil then _G.idPurchaseConfirmVisible=false end; if _G.idCardGuiVisible==nil then _G.idCardGuiVisible=false end

local function drawStyledButton(text,x,y,w,h,bgColor,hoverColor,textColor,enabled)
    enabled=(enabled==nil)and true or enabled;local cBg=bgColor;if not enabled then cBg=colors.buttonDisabledBg else local cX,cY=getCursorPosition();if cX then local mX,mY=cX*screenW,cY*screenH;if mX>=x and mX<=x+w and mY>=y and mY<=y+h then cBg=hoverColor end end end
    dxDrawRectangle(x,y,w,h,cBg);dxDrawLine(x,y,x+w,y,tocolor(255,255,255,30),1);dxDrawLine(x,y+h,x+w,y+h,tocolor(0,0,0,100),1);dxDrawText(text,x,y,x+w,y+h,textColor,1.0,"default-bold","center","center")
end
function countTextLines(text,mW,sc,fnt)local ls=0;local cl="";local wds={};if text then for w in string.gmatch(text,"[^%s]+")do table.insert(wds,w)end end;if #wds==0 then return 1 end;ls=1;cl=wds[1];for i=2,#wds do if dxGetTextWidth(cl.." "..wds[i],sc,fnt)<=mW then cl=cl.." "..wds[i]else ls=ls+1;cl=wds[i];if dxGetTextWidth(cl,sc,fnt)>mW then local tW=0;for c=1,#cl do tW=tW+dxGetTextWidth(string.sub(cl,c,c),sc,fnt);if tW>mW then ls=ls+1;tW=dxGetTextWidth(string.sub(cl,c,c),sc,fnt)end end end end end;return ls+1 end

function openConfirmPracticalGUI(licenseName,cost)
    if _G.isPedGuiOpen or _G.isInventoryVisible then return end
    isDriveMenuVisible=false;isTheoryTestVisible=false;isConfirmPracticalVisible=true;_G.isConfirmPracticalVisible=true
    confirmPracticalData={name=licenseName,cost=cost}
    if type(_G.forceCloseManualCursor) == "function" then _G.forceCloseManualCursor() end 
    _G.isCursorManuallyShownByClickSystem = false 
    if not isCursorShowing()then showCursor(true) end; guiSetInputMode("no_binds_when_editing")
    if not renderHandlerActive then addEventHandler("onClientRender",root,renderMasterDriveLicenseGUI);renderHandlerActive=true end
    if not keyHandlerActive then addEventHandler("onClientKey",root,handleMasterDriveLicenseKey);keyHandlerActive=true end
    if not clickHandlerActive then addEventHandler("onClientClick",root,handleMasterDriveLicenseClick);clickHandlerActive=true end
end

addEvent("drivelicense:openMenu",true);addEventHandler("drivelicense:openMenu",root,function(lD)
    if isDriveMenuVisible or isTheoryTestVisible or isConfirmPracticalVisible or isPracticalTestActive then return end
    if _G.isPedGuiOpen or _G.isInventoryVisible then return end
    if type(_G.forceCloseManualCursor) == "function" then _G.forceCloseManualCursor() end
    _G.isCursorManuallyShownByClickSystem = false
    isDriveMenuVisible=true;_G.isDriveMenuVisible=true;availableLicensesGUI=lD or{};selectedLicenseIndex=1;if not isCursorShowing()then showCursor(true)end;guiSetInputMode("no_binds_when_editing")
    if not renderHandlerActive then addEventHandler("onClientRender",root,renderMasterDriveLicenseGUI);renderHandlerActive=true end
    if not keyHandlerActive then addEventHandler("onClientKey",root,handleMasterDriveLicenseKey);keyHandlerActive=true end
    if not clickHandlerActive then addEventHandler("onClientClick",root,handleMasterDriveLicenseClick);clickHandlerActive=true end
end)

function closeAllDriveLicenseGUIs(keepCursorActiveForNextInteractionWithPed)
    isDriveMenuVisible = false
    isTheoryTestVisible = false
    isConfirmPracticalVisible = false
    _G.isDriveMenuVisible = false
    _G.isTheoryTestVisible = false
    _G.isConfirmPracticalVisible = false
    
    local anyOtherDriveLicenseGuiActive = isDriveMenuVisible or isTheoryTestVisible or isConfirmPracticalVisible or isPracticalTestActive
    local anyOtherGlobalGuiActive = _G.isPedGuiOpen or _G.isInventoryVisible or _G.idPurchaseConfirmVisible or _G.idCardGuiVisible

    if not anyOtherDriveLicenseGuiActive and not anyOtherGlobalGuiActive then
        if keepCursorActiveForNextInteractionWithPed then
            if not isCursorShowing() then showCursor(true) end
            guiSetInputMode("allow_binds") 
            _G.isCursorManuallyShownByClickSystem = true 
        else
            if not _G.isCursorManuallyShownByClickSystem then
                if isCursorShowing() then showCursor(false) end
                guiSetInputMode("allow_binds")
            else
                guiSetInputMode("allow_binds") 
            end
        end
    elseif not isCursorShowing() and (anyOtherDriveLicenseGuiActive or anyOtherGlobalGuiActive) then
        showCursor(true)
        guiSetInputMode("no_binds_when_editing")
        _G.isCursorManuallyShownByClickSystem = false 
    elseif isCursorShowing() and not (anyOtherDriveLicenseGuiActive or anyOtherGlobalGuiActive or keepCursorActiveForNextInteractionWithPed or _G.isCursorManuallyShownByClickSystem) then
        showCursor(false)
        guiSetInputMode("allow_binds")
    end

    if not anyOtherDriveLicenseGuiActive then
        if renderHandlerActive then removeEventHandler("onClientRender",root,renderMasterDriveLicenseGUI);renderHandlerActive=false end
        if keyHandlerActive then removeEventHandler("onClientKey",root,handleMasterDriveLicenseKey);keyHandlerActive=false end
        if clickHandlerActive then removeEventHandler("onClientClick",root,handleMasterDriveLicenseClick);clickHandlerActive=false end
    end
end

function renderDriveLicenseMenuGUI()
    dxDrawRectangle(windowX,windowY,windowWidth,windowHeight,colors.bg);dxDrawRectangle(windowX,windowY,windowWidth,40,colors.headerBg);dxDrawText("Fahrschule - Lizenz auswählen",windowX,windowY,windowX+windowWidth,windowY+40,colors.headerText,1.3,"default-bold","center","center")
    local iH=45;local lSY=windowY+50;local lMaxH=windowHeight-110
    if #availableLicensesGUI==0 then dxDrawText("Keine Führerscheine konfiguriert oder alle bereits erworben.",windowX,lSY,windowX+windowWidth,lSY+lMaxH,colors.itemText,1.1,"default","center","center",true)
    else for i,lD in ipairs(availableLicensesGUI)do local iY=lSY+(i-1)*iH;if iY+iH>lSY+lMaxH+5 then break end;local cIBg=(i==selectedLicenseIndex)and colors.selectedItemBg or colors.itemBg;dxDrawRectangle(windowX+10,iY,windowWidth-20,iH-5,cIBg);dxDrawText(lD.displayName,windowX+20,iY,windowX+windowWidth-150,iY+iH-5,colors.itemText,1.0,"default-bold","left","center")
    local sT="$"..(lD.cost_total or lD.cost_theory or"N/A");local sC=colors.itemCostText;local cABT="Theorie starten ($"..(lD.cost_theory or"?")..")";local cABE=true
    if lD.hasLicense then sT="✔ Vorhanden";sC=colors.itemOwnedText;cABT="Bereits erworben";cABE=false elseif lD.status=="pending_practical_test"then sT="Praxis ausstehend";sC=colors.itemPendingText;cABT="Praxis starten ($"..(lD.cost_practical or"?")..")"elseif lD.isCurrentlyDoing then sT="In Bearbeitung...";sC=colors.itemPendingText;cABT="Wird bearbeitet";cABE=false end
    dxDrawText(sT,windowX+windowWidth-140,iY,windowX+windowWidth-20,iY+iH-5,sC,0.9,"default-bold","right","center");if i==selectedLicenseIndex then uiElements.actionButton.text=cABT;uiElements.actionButton.enabled=cABE end end end
    local bW,bH=140,38;uiElements.closeButton={x=windowX+windowWidth-bW-15,y=windowY+windowHeight-bH-10,w=bW,h=bH,text="Schließen"};drawStyledButton(uiElements.closeButton.text,uiElements.closeButton.x,uiElements.closeButton.y,uiElements.closeButton.w,uiElements.closeButton.h,colors.buttonBg,colors.buttonHoverBg,colors.buttonText,true)
    local aBW=uiElements.actionButton.text and dxGetTextWidth(uiElements.actionButton.text,1.0,"default-bold")+30 or bW+30;aBW=math.max(bW+30,aBW);uiElements.actionButton.w=aBW;uiElements.actionButton.h=bH;uiElements.actionButton.x=uiElements.closeButton.x-aBW-10;uiElements.actionButton.y=uiElements.closeButton.y
    if uiElements.actionButton.text then drawStyledButton(uiElements.actionButton.text,uiElements.actionButton.x,uiElements.actionButton.y,uiElements.actionButton.w,uiElements.actionButton.h,colors.buttonBg,colors.buttonHoverBg,colors.buttonText,uiElements.actionButton.enabled)end
end

addEvent("drivelicense:showTheoryQuestion",true);addEventHandler("drivelicense:showTheoryQuestion",root,function(qD,qN,qT)
    if _G.isPedGuiOpen or _G.isInventoryVisible then return end;isDriveMenuVisible=false;isConfirmPracticalVisible=false;isTheoryTestVisible=true;_G.isTheoryTestVisible=true;currentTheoryQuestion=qD;currentQuestionNum=qN;totalQuestions=qT;selectedTheoryAnswer=nil;uiElements.theoryAnswerButtons={}
    if type(_G.forceCloseManualCursor) == "function" then _G.forceCloseManualCursor() end
    _G.isCursorManuallyShownByClickSystem = false
    if not isCursorShowing()then showCursor(true); guiSetInputMode("no_binds_when_editing") end
    if not renderHandlerActive then addEventHandler("onClientRender",root,renderMasterDriveLicenseGUI);renderHandlerActive=true end;if not keyHandlerActive then addEventHandler("onClientKey",root,handleMasterDriveLicenseKey);keyHandlerActive=true end;if not clickHandlerActive then addEventHandler("onClientClick",root,handleMasterDriveLicenseClick);clickHandlerActive=true end
end)

function closeTheoryTestGUI(keepCursorActiveAfterClose) 
    if not isTheoryTestVisible then return end;isTheoryTestVisible=false;_G.isTheoryTestVisible=false
    closeAllDriveLicenseGUIs(keepCursorActiveAfterClose)
end

function renderTheoryTestGUI()
    local pW,pH=650,450;local pX,pY=(screenW-pW)/2,(screenH-pH)/2;dxDrawRectangle(pX,pY,pW,pH,colors.bg);dxDrawRectangle(pX,pY,pW,40,colors.headerBg);dxDrawText("Theorieprüfung - Frage "..currentQuestionNum.." von "..totalQuestions,pX,pY,pX+pW,pY+40,colors.headerText,1.3,"default-bold","center","center")
    local qTY=pY+60;local qTS=1.1;local qTF="default";local nL=countTextLines(currentTheoryQuestion.q,pW-40,qTS,qTF);local sLH=dxGetFontHeight(qTS,qTF);if not sLH or sLH<=0 then sLH=12 end;local qTH=sLH*nL;dxDrawText(currentTheoryQuestion.q,pX+20,qTY,pX+pW-20,qTY+qTH,colors.questionText,qTS,qTF,"center","top",true)
    local aSY=qTY+qTH+20;if currentTheoryQuestion.image and fileExists("drivelicense/images/theory/"..currentTheoryQuestion.image)then local iW,iH=150,100;local iX=pX+(pW-iW)/2;local iY=qTY+qTH+10;dxDrawImage(iX,iY,iW,iH,"drivelicense/images/theory/"..currentTheoryQuestion.image);aSY=iY+iH+15 end
    local aBW=pW-100;uiElements.theoryAnswerButtons={};if currentTheoryQuestion and currentTheoryQuestion.a then for i,aTI in ipairs(currentTheoryQuestion.a)do local aY=aSY+(i-1)*(THEORY_ANSWER_HEIGHT+THEORY_ANSWER_SPACING);local cABg=(selectedTheoryAnswer==i)and colors.selectedAnswerBg or colors.itemBg;local btn={x=pX+50,y=aY,w=aBW,h=THEORY_ANSWER_HEIGHT,text=i..". "..aTI,id=i};drawStyledButton(btn.text,btn.x,btn.y,btn.w,btn.h,cABg,colors.selectedItemBg,colors.answerText,true);table.insert(uiElements.theoryAnswerButtons,btn)end end
    local bW,bH=180,40;uiElements.actionButton={x=pX+(pW-bW)/2,y=pY+pH-bH-15,w=bW,h=bH,text=(selectedTheoryAnswer and"Antwort bestätigen"or"Wähle eine Antwort"),enabled=(selectedTheoryAnswer~=nil)};drawStyledButton(uiElements.actionButton.text,uiElements.actionButton.x,uiElements.actionButton.y,uiElements.actionButton.w,uiElements.actionButton.h,colors.buttonBg,colors.buttonHoverBg,colors.buttonText,uiElements.actionButton.enabled)
end

addEvent("drivelicense:theoryTestFinished",true)
addEventHandler("drivelicense:theoryTestFinished",root,function(passed,score,total,nextStepPrompt)
    local shouldKeepCursorForNextInteraction = (passed and nextStepPrompt ~= nil)
    closeTheoryTestGUI(shouldKeepCursorForNextInteraction) 

    if passed then outputChatBox("Theorieprüfung bestanden ("..score.."/"..total..")!",0,200,0)
        if nextStepPrompt then
            -- `drivelicense:confirmStartPractical` wird vom Server getriggert.
        else
            outputChatBox("Kein nächster Schritt definiert oder Lizenz direkt erhalten.",0,200,0)
            setTimer(triggerServerEvent,500,1,"drivelicense:pedInteraction",localPlayer) 
        end
    else 
        outputChatBox("Theorieprüfung leider nicht bestanden ("..score.."/"..total.."). Versuche es später erneut.",200,0,0)
        setTimer(triggerServerEvent,500,1,"drivelicense:pedInteraction",localPlayer)
    end
end)

addEvent("drivelicense:confirmStartPractical", true)
addEventHandler("drivelicense:confirmStartPractical", root, function(licenseName, cost)
    openConfirmPracticalGUI(licenseName, cost)
end)

function closeConfirmPracticalGUI()
    if not isConfirmPracticalVisible then return end;isConfirmPracticalVisible=false;_G.isConfirmPracticalVisible=false;
    closeAllDriveLicenseGUIs(true) 
end
function renderConfirmPracticalGUI()
    local pW,pH=400,220;local pX,pY=(screenW-pW)/2,(screenH-pH)/2;dxDrawRectangle(pX,pY,pW,pH,colors.bg);dxDrawRectangle(pX,pY,pW,35,colors.headerBg);dxDrawText("Praktische Prüfung",pX,pY,pX+pW,pY+35,colors.headerText,1.2,"default-bold","center","center")
    local txt="Möchtest du die praktische Prüfung für den\n'"..(confirmPracticalData.name or"Führerschein").."'\nfür $"..(confirmPracticalData.cost or"??").." starten?";dxDrawText(txt,pX+15,pY+50,pX+pW-15,pY+pH-60,colors.itemText,1.0,"default","center","center",true)
    local bW,bH=140,38;local bSp=10;uiElements.actionButton={x=pX+(pW/2)-bW-bSp/2,y=pY+pH-bH-15,w=bW,h=bH,text="Ja, starten",enabled=true};uiElements.closeButton={x=pX+(pW/2)+bSp/2,y=pY+pH-bH-15,w=bW,h=bH,text="Nein, später",enabled=true}
    drawStyledButton(uiElements.actionButton.text,uiElements.actionButton.x,uiElements.actionButton.y,uiElements.actionButton.w,uiElements.actionButton.h,colors.buttonBg,colors.buttonHoverBg,colors.buttonText,true);drawStyledButton(uiElements.closeButton.text,uiElements.closeButton.x,uiElements.closeButton.y,uiElements.closeButton.w,uiElements.closeButton.h,colors.buttonBg,colors.buttonHoverBg,colors.buttonText,true)
end

addEvent("drivelicense:startPracticalTestClient",true)
addEventHandler("drivelicense:startPracticalTestClient",root,function(cP,vE)
    closeAllDriveLicenseGUIs(false);isPracticalTestActive=true;practicalTestVehicle=vE;practicalCheckpoints=cP or {};currentCheckpointIndexClient=1;destroyPracticalTestElements()
    if not isElement(practicalTestVehicle)then outputChatBox("Fehler: Prüfungsfahrzeug existiert nicht (Client).",255,0,0);triggerServerEvent("drivelicense:finishPracticalTest",localPlayer,false,"Prüfungsfahrzeug Client-Fehler");cleanupPracticalTestClient();return end
    setElementData(localPlayer,"lastPracticalVehicle",practicalTestVehicle)
    setElementData(localPlayer,"inDrivingTestClient",true);setPedCanBeKnockedOffBike(localPlayer,false)
    if type(setCameraBehindPlayer) == "function" then setCameraBehindPlayer() else outputDebugString("WARNUNG [Client]: setCameraBehindPlayer ist nil!"); setCameraTarget(localPlayer) end
    if isCursorShowing()then showCursor(false)end;guiSetInputMode("allow_binds");createNextCheckpointElements()
    if not renderHandlerActive then addEventHandler("onClientRender",root,renderMasterDriveLicenseGUI);renderHandlerActive=true end;if not keyHandlerActive then addEventHandler("onClientKey",root,handleMasterDriveLicenseKey);keyHandlerActive=true end
    addEventHandler("onClientMarkerHit",root,handlePracticalCheckpointHitClient);if isElement(practicalTestVehicle)then addEventHandler("onClientVehicleDamage",practicalTestVehicle,handlePracticalVehicleDamageClient)end;addEventHandler("onClientPlayerVehicleExit",localPlayer,handlePlayerExitTestVehicleClient);outputChatBox("Praktische Prüfung gestartet! Fahre zum ersten Checkpoint.",0,200,100)
end)

function createNextCheckpointElements()
    destroyPracticalTestElements()
    if type(practicalCheckpoints)~="table"then triggerServerEvent("drivelicense:finishPracticalTest",localPlayer,false,"Fehlerhafte Checkpoint-Daten (Typ)");cleanupPracticalTestClient();return end
    if currentCheckpointIndexClient<=#practicalCheckpoints then local cpD=practicalCheckpoints[currentCheckpointIndexClient]
        if type(cpD)=="table"and cpD.x and cpD.y and cpD.z then local blC={255,200,0,200};local mrkC={255,200,0,150};
            local blp=createBlip(cpD.x,cpD.y,cpD.z,0,2,blC[1],blC[2],blC[3],blC[4],0,99999.0)
            local mrk=createMarker(cpD.x,cpD.y,cpD.z-(cpD.tolerance or 3)/2,"checkpoint",cpD.tolerance or 3,mrkC[1],mrkC[2],mrkC[3],mrkC[4])
            
            if isElement(mrk)then 
                setElementData(mrk,"isDrivingTestCheckpointClient",true)
                setElementData(mrk,"checkpointIndexClient",currentCheckpointIndexClient)
                setElementInterior(mrk, 0)      
                setElementDimension(mrk, 1)     
                table.insert(practicalTestBlipsAndMarkers,mrk)
            else 
                outputChatBox("FEHLER [Client]: Konnte Marker #"..currentCheckpointIndexClient.." nicht erstellen!",255,0,0)
            end
            
            if isElement(blp)then 
                setElementDimension(blp, 1)     
                table.insert(practicalTestBlipsAndMarkers,blp)
            else 
                outputChatBox("FEHLER [Client]: Konnte Blip für Marker #"..currentCheckpointIndexClient.." nicht erstellen!",255,0,0)
            end
        else 
            triggerServerEvent("drivelicense:finishPracticalTest",localPlayer,false,"Fehlerhafte Checkpoint-Daten (Inhalt)")
            cleanupPracticalTestClient()
        end
    end
end
function destroyPracticalTestElements()for _,el in ipairs(practicalTestBlipsAndMarkers)do if isElement(el)then destroyElement(el)end end;practicalTestBlipsAndMarkers={}end
function handlePracticalCheckpointHitClient(hE,mD)if not isPracticalTestActive or not mD or hE~=localPlayer then return end;local mrk=source;if getElementData(mrk,"isDrivingTestCheckpointClient")and getElementData(mrk,"checkpointIndexClient")==currentCheckpointIndexClient then playSoundFrontEnd(40);currentCheckpointIndexClient=currentCheckpointIndexClient+1;if currentCheckpointIndexClient>#practicalCheckpoints then triggerServerEvent("drivelicense:finishPracticalTest",localPlayer,true,"Alle Checkpoints erreicht");cleanupPracticalTestClient()else createNextCheckpointElements();outputChatBox("Checkpoint "..(currentCheckpointIndexClient-1).."/"..#practicalCheckpoints.." erreicht. Fahre zum nächsten.",0,200,50)end end end
function handlePracticalVehicleDamageClient(att,wpn,loss,x,y,z,tire)if not isPracticalTestActive or not isElement(practicalTestVehicle)then return end end
function handlePlayerExitTestVehicleClient(exV,seat)if isPracticalTestActive and isElement(exV)and exV==practicalTestVehicle and seat==0 then outputChatBox("Prüfung fehlgeschlagen: Fahrzeug verlassen!",255,0,0);triggerServerEvent("drivelicense:finishPracticalTest",localPlayer,false,"Fahrzeug verlassen");cleanupPracticalTestClient()end end

addEvent("drivelicense:practicalTestFinishedClient",true);addEventHandler("drivelicense:practicalTestFinishedClient",root,function(succ)cleanupPracticalTestClient(); closeAllDriveLicenseGUIs(false) end)

function cleanupPracticalTestClient()
    if not isPracticalTestActive then return end;isPracticalTestActive=false;destroyPracticalTestElements()
    setElementData(localPlayer,"inDrivingTestClient",false);setPedCanBeKnockedOffBike(localPlayer,true);setCameraTarget(localPlayer)
    removeEventHandler("onClientMarkerHit",root,handlePracticalCheckpointHitClient)
    local lstV=getElementData(localPlayer,"lastPracticalVehicle")
    if isElement(lstV)then
        removeEventHandler("onClientVehicleDamage",lstV,handlePracticalVehicleDamageClient)
        if type(removeElementData) == "function" then removeElementData(localPlayer,"lastPracticalVehicle")
        else outputDebugString("WARNUNG [Client]: removeElementData ist nil in cleanupPracticalTestClient!") end
    end
    removeEventHandler("onClientPlayerVehicleExit",localPlayer,handlePlayerExitTestVehicleClient);practicalTestVehicle=nil
    if not isDriveMenuVisible and not isTheoryTestVisible and not isConfirmPracticalVisible then if renderHandlerActive then removeEventHandler("onClientRender",root,renderMasterDriveLicenseGUI);renderHandlerActive=false end;if keyHandlerActive then removeEventHandler("onClientKey",root,handleMasterDriveLicenseKey);keyHandlerActive=false end end
end

function renderPracticalTestHUD()
    if not isPracticalTestActive then return end
    local cpTxt="Praktische Prüfung - Checkpoint: "..currentCheckpointIndexClient.."/"..#practicalCheckpoints
    if currentCheckpointIndexClient>#practicalCheckpoints then cpTxt="Praktische Prüfung abgeschlossen!"end
    dxDrawText(cpTxt,10,screenH-90,screenW,screenH-70,tocolor(255,200,0),1.2,"default-bold","left","top",false,false,false,true)

    if isElement(practicalTestVehicle)then 
        local h=getElementHealth(practicalTestVehicle)
        dxDrawText("Fahrzeugzustand: "..math.floor(h/10).."%",10,screenH-70,screenW,screenH-50,tocolor(255,255,255),1.1,"default","left","top",false,false,false,true)
        
        -- NEU: KM/H Anzeige
        local vx, vy, vz = getElementVelocity(practicalTestVehicle)
        local currentSpeed = math.sqrt(vx^2 + vy^2 + vz^2) * 180 -- Umrechnung in km/h
        local speedText = string.format("%d KM/H", math.floor(currentSpeed))
        local speedTextWidth = dxGetTextWidth(speedText, 1.8, "default-bold")
        local speedTextX = (screenW - speedTextWidth) / 2
        local speedTextY = screenH - 60 -- Position mittig unten

        dxDrawText(speedText, speedTextX + 1, speedTextY + 1, speedTextX + speedTextWidth + 1, speedTextY + 30 + 1, colors.speedTextShadowColor, 1.8, "default-bold", "left", "top", false, false, false, false)
        dxDrawText(speedText, speedTextX, speedTextY, speedTextX + speedTextWidth, speedTextY + 30, colors.speedTextColor, 1.8, "default-bold", "left", "top", false, false, false, false)
    end 
end

function renderMasterDriveLicenseGUI()if isDriveMenuVisible then renderDriveLicenseMenuGUI()elseif isTheoryTestVisible then renderTheoryTestGUI()elseif isConfirmPracticalVisible then renderConfirmPracticalGUI()elseif isPracticalTestActive then renderPracticalTestHUD()else if renderHandlerActive then removeEventHandler("onClientRender",root,renderMasterDriveLicenseGUI);renderHandlerActive=false end end end

function handleMasterDriveLicenseClick(button,state,absX,absY)
    if button~="left"or state~="up"then return end;if _G.isPedGuiOpen or _G.isInventoryVisible then return end
    if isDriveMenuVisible then if uiElements.closeButton and absX>=uiElements.closeButton.x and absX<=uiElements.closeButton.x+uiElements.closeButton.w and absY>=uiElements.closeButton.y and absY<=uiElements.closeButton.y+uiElements.closeButton.h then closeAllDriveLicenseGUIs(false);triggerServerEvent("drivelicense:cancelTest",localPlayer);return end
        if uiElements.actionButton and uiElements.actionButton.enabled and absX>=uiElements.actionButton.x and absX<=uiElements.actionButton.x+uiElements.actionButton.w and absY>=uiElements.actionButton.y and absY<=uiElements.actionButton.y+uiElements.actionButton.h then local selD=availableLicensesGUI[selectedLicenseIndex];if selD then if selD.status=="pending_practical_test"then openConfirmPracticalGUI(selD.displayName,selD.cost_practical)else triggerServerEvent("drivelicense:startLicenseProcess",localPlayer,selD.key)end end;return end
        local itmH=45;local lstSY=windowY+50;if availableLicensesGUI and #availableLicensesGUI>0 then for i=1,#availableLicensesGUI do local itmY=lstSY+(i-1)*itmH;if absX>=windowX+10 and absX<=windowX+windowWidth-10 and absY>=itmY and absY<=itmY+itmH-5 then selectedLicenseIndex=i;return end end end
    elseif isTheoryTestVisible then if uiElements.actionButton and uiElements.actionButton.enabled and absX>=uiElements.actionButton.x and absX<=uiElements.actionButton.x+uiElements.actionButton.w and absY>=uiElements.actionButton.y and absY<=uiElements.actionButton.y+uiElements.actionButton.h then triggerServerEvent("drivelicense:submitTheoryAnswer",localPlayer,selectedTheoryAnswer);return end
        if uiElements.theoryAnswerButtons then for i,btnD in ipairs(uiElements.theoryAnswerButtons)do if absX>=btnD.x and absX<=btnD.x+btnD.w and absY>=btnD.y and absY<=btnD.y+btnD.h then selectedTheoryAnswer=btnD.id;return end end end
    elseif isConfirmPracticalVisible then if uiElements.actionButton and absX>=uiElements.actionButton.x and absX<=uiElements.actionButton.x+uiElements.actionButton.w and absY>=uiElements.actionButton.y and absY<=uiElements.actionButton.y+uiElements.actionButton.h then triggerServerEvent("drivelicense:startPracticalTest",localPlayer);return end
        if uiElements.closeButton and absX>=uiElements.closeButton.x and absX<=uiElements.closeButton.x+uiElements.closeButton.w and absY>=uiElements.closeButton.y and absY<=uiElements.closeButton.y+uiElements.closeButton.h then closeConfirmPracticalGUI();setTimer(triggerServerEvent,200,1,"drivelicense:pedInteraction",localPlayer);return end
    end
end

function handleMasterDriveLicenseKey(key,press)
    if not press then return end;if _G.isPedGuiOpen or _G.isInventoryVisible then return end
    if isDriveMenuVisible then if key=="arrow_u"then selectedLicenseIndex=math.max(1,selectedLicenseIndex-1)elseif key=="arrow_d"then selectedLicenseIndex=math.min(#availableLicensesGUI>0 and #availableLicensesGUI or 1,selectedLicenseIndex+1)elseif key=="enter"then if uiElements.actionButton and uiElements.actionButton.enabled then local selD=availableLicensesGUI[selectedLicenseIndex];if selD then if selD.status=="pending_practical_test"then openConfirmPracticalGUI(selD.displayName,selD.cost_practical)else triggerServerEvent("drivelicense:startLicenseProcess",localPlayer,selD.key)end end end elseif key=="escape"then closeAllDriveLicenseGUIs(false);triggerServerEvent("drivelicense:cancelTest",localPlayer);end
    elseif isTheoryTestVisible then if key=="escape"then closeAllDriveLicenseGUIs(true);triggerServerEvent("drivelicense:cancelTest",localPlayer);elseif tonumber(key)and currentTheoryQuestion.a and tonumber(key)>=1 and tonumber(key)<=#currentTheoryQuestion.a then selectedTheoryAnswer=tonumber(key)elseif key=="enter"and selectedTheoryAnswer then triggerServerEvent("drivelicense:submitTheoryAnswer",localPlayer,selectedTheoryAnswer)end
    elseif isConfirmPracticalVisible then if key=="escape"then closeConfirmPracticalGUI();setTimer(triggerServerEvent,200,1,"drivelicense:pedInteraction",localPlayer);elseif key=="enter"then triggerServerEvent("drivelicense:startPracticalTest",localPlayer);end
    elseif isPracticalTestActive then if key=="escape"then triggerServerEvent("drivelicense:finishPracticalTest",localPlayer,false,"Manuell abgebrochen");cleanupPracticalTestClient();end end
end

addEvent("drivelicense:updateClientLicenses",true);addEventHandler("drivelicense:updateClientLicenses",root,function(nLT)end)
addEvent("drivelicense:testCancelledClient",true);addEventHandler("drivelicense:testCancelledClient",root,function()closeAllDriveLicenseGUIs(false);cleanupPracticalTestClient();outputChatBox("Der aktuelle Führerscheinprozess wurde abgebrochen.",200,100,0)end)

addEventHandler("onClientResourceStop",resourceRoot,function()closeAllDriveLicenseGUIs(false);cleanupPracticalTestClient()end)
addEventHandler("onClientResourceStart",resourceRoot,function()if _G.isDriveMenuVisible==nil then _G.isDriveMenuVisible=false end;if _G.isTheoryTestVisible==nil then _G.isTheoryTestVisible=false end;if _G.isConfirmPracticalVisible==nil then _G.isConfirmPracticalVisible=false end;outputDebugString("[DriveLicenseClient] Führerschein-System Client (V13 mit KMH Anzeige) geladen.")end)

addEvent("drivelicense:testTrigger",true);addEventHandler("drivelicense:testTrigger",localPlayer,function(msg)end)