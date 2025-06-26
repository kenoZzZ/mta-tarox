-- tarox/bank/bank_client.lua
-- KORREKTUR V1.3: setPedLookAt (via setPedAnimation) und M-Tasten-Interaktion

local screenW, screenH = guiGetScreenSize()
local localPlayer = getLocalPlayer()

local isBankGUIVisible = false
_G.isBankGUIVisible = false 

local bankData = {
    cash = 0,
    bankMoney = 0
}
local transactionAmountInput = ""
local activeInputElement = nil 
local cursorBlinkVisible = true

local layout = {
    panelW = 450, panelH = 380,
    headerH = 45, padding = 20,
    inputFieldH = 38, inputFieldSpacing = 15,
    buttonH = 40, buttonSpacing = 10,
    infoTextScale = 1.05,
    inputLabelScale = 1.0
}
layout.panelX = (screenW - layout.panelW) / 2
layout.panelY = (screenH - layout.panelH) / 2

local colors = {
    BG_MAIN = tocolor(28, 30, 36, 245), BG_HEADER = tocolor(0, 100, 180, 250),
    TEXT_HEADER = tocolor(235, 235, 240), TEXT_LABEL = tocolor(170, 175, 185),
    TEXT_VALUE_CASH = tocolor(90, 210, 140), TEXT_VALUE_BANK = tocolor(100, 150, 255),
    TEXT_INPUT = tocolor(210, 215, 225), TEXT_PLACEHOLDER = tocolor(120, 125, 135),
    BUTTON_ACTION_BG = tocolor(70, 180, 70, 220), BUTTON_ACTION_HOVER = tocolor(90, 200, 90, 230),
    BUTTON_WITHDRAW_BG = tocolor(0, 122, 204, 220), BUTTON_WITHDRAW_HOVER = tocolor(0, 142, 234, 230),
    BUTTON_CLOSE_BG = tocolor(200, 70, 70, 220), BUTTON_CLOSE_HOVER = tocolor(220, 90, 90, 230),
    BUTTON_TEXT = tocolor(245, 245, 245), INPUT_BG = tocolor(45, 48, 56, 255),
    BORDER_LIGHT = tocolor(55, 58, 68, 200), BORDER_DARK = tocolor(20, 22, 28, 220)
}

local fonts = { HEADER = "default-bold", TEXT_VALUE = "default-bold", INPUT_TEXT = "default", BUTTON = "default-bold" }
local guiElements = {}
local renderHandler, clickHandler, keyHandler, charHandler, blinkTimer = nil, nil, nil, nil, nil

local function formatMoneyClient(amount)
    local formatted = string.format("%.0f", amount or 0)
    local k repeat formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1.%2") until k == 0
    return "$" .. formatted
end

local function dxDrawStyledBankButton(id, text, x, y, w, h, bgColor, hoverColor, textColor)
    local cX, cY = getCursorPosition(); local hover = false
    if cX then local mouseX, mouseY = cX*screenW, cY*screenH; hover = mouseX >= x and mouseX <= x+w and mouseY >= y and mouseY <= y+h end
    local currentBgColor = hover and hoverColor or bgColor
    dxDrawRectangle(x, y, w, h, currentBgColor)
    dxDrawLine(x,y,x+w,y,colors.BORDER_LIGHT,1); dxDrawLine(x,y+h,x+w,y+h,colors.BORDER_DARK,1)
    dxDrawText(text, x, y, x+w, y+h, textColor, 1.1, fonts.BUTTON, "center", "center", false, false, false, true)
    guiElements[id] = { x=x, y=y, w=w, h=h }
end

local function renderBankGUI()
    if not isBankGUIVisible then return end
    dxDrawRectangle(layout.panelX,layout.panelY,layout.panelW,layout.panelH,colors.BG_MAIN)
    dxDrawLine(layout.panelX,layout.panelY,layout.panelX+layout.panelW,layout.panelY,colors.BORDER_LIGHT,2)
    dxDrawLine(layout.panelX,layout.panelY+layout.panelH,layout.panelX+layout.panelW,layout.panelY+layout.panelH,colors.BORDER_DARK,2)
    dxDrawRectangle(layout.panelX,layout.panelY,layout.panelW,layout.headerH,colors.BG_HEADER)
    dxDrawText("Tarox Bank",layout.panelX,layout.panelY,layout.panelX+layout.panelW,layout.panelY+layout.headerH,colors.TEXT_HEADER,1.3,fonts.HEADER,"center","center")
    local currentY=layout.panelY+layout.headerH+layout.padding
    dxDrawText("Bargeld:",layout.panelX+layout.padding,currentY,0,0,colors.TEXT_LABEL,layout.infoTextScale,fonts.TEXT_VALUE)
    dxDrawText(formatMoneyClient(bankData.cash),layout.panelX+layout.padding+100,currentY,0,0,colors.TEXT_VALUE_CASH,layout.infoTextScale,fonts.TEXT_VALUE)
    currentY=currentY+25
    dxDrawText("Bankguthaben:",layout.panelX+layout.padding,currentY,0,0,colors.TEXT_LABEL,layout.infoTextScale,fonts.TEXT_VALUE)
    dxDrawText(formatMoneyClient(bankData.bankMoney),layout.panelX+layout.padding+100,currentY,0,0,colors.TEXT_VALUE_BANK,layout.infoTextScale,fonts.TEXT_VALUE)
    currentY=currentY+40
    dxDrawText("Betrag:",layout.panelX+layout.padding,currentY,0,0,colors.TEXT_LABEL,layout.inputLabelScale,"default")
    currentY=currentY+20
    local inputX=layout.panelX+layout.padding; local inputW=layout.panelW-(layout.padding*2)
    dxDrawRectangle(inputX,currentY,inputW,layout.inputFieldH,colors.INPUT_BG)
    dxDrawLine(inputX,currentY,inputX+inputW,currentY,colors.BORDER_DARK,1)
    dxDrawLine(inputX,currentY+layout.inputFieldH,inputX+inputW,currentY+layout.inputFieldH,colors.BORDER_LIGHT,1)
    local displayText=transactionAmountInput; local displayColor=colors.TEXT_INPUT
    if transactionAmountInput=="" and activeInputElement~="amount" then displayText="Betrag eingeben...";displayColor=colors.TEXT_PLACEHOLDER end
    if activeInputElement=="amount" and cursorBlinkVisible then displayText=displayText.."|" end
    dxDrawText(displayText,inputX+10,currentY,inputX+inputW-10,currentY+layout.inputFieldH,displayColor,1.0,fonts.INPUT_TEXT,"left","center")
    guiElements["amount_input"]={x=inputX,y=currentY,w=inputW,h=layout.inputFieldH}
    currentY=currentY+layout.inputFieldH+layout.inputFieldSpacing+10
    local actionButtonW=(layout.panelW-(layout.padding*2)-layout.buttonSpacing)/2
    dxDrawStyledBankButton("deposit","Einzahlen",layout.panelX+layout.padding,currentY,actionButtonW,layout.buttonH,colors.BUTTON_ACTION_BG,colors.BUTTON_ACTION_HOVER,colors.BUTTON_TEXT)
    dxDrawStyledBankButton("withdraw","Auszahlen",layout.panelX+layout.padding+actionButtonW+layout.buttonSpacing,currentY,actionButtonW,layout.buttonH,colors.BUTTON_WITHDRAW_BG,colors.BUTTON_WITHDRAW_HOVER,colors.BUTTON_TEXT)
    currentY=currentY+layout.buttonH+layout.padding
    dxDrawStyledBankButton("close","Schließen",layout.panelX+layout.padding,currentY,layout.panelW-(layout.padding*2),layout.buttonH,colors.BUTTON_CLOSE_BG,colors.BUTTON_CLOSE_HOVER,colors.BUTTON_TEXT)
end

local function toggleBankGUI(elementClicked) -- Parameter kann Ped oder ATM-Objekt sein
    isBankGUIVisible = not isBankGUIVisible
    _G.isBankGUIVisible = isBankGUIVisible

    if isBankGUIVisible then
        if _G.isCursorManuallyShownByClickSystem then
            _G.isCursorManuallyShownByClickSystem = false 
        end

        if isElement(elementClicked) and getElementType(elementClicked) == "ped" then -- Nur für Peds LookAt
            local px, py, pz = getElementPosition(localPlayer)
            setPedLookAt(elementClicked, px, py, pz)
            setTimer(function(pedToStopLooking) 
                if isElement(pedToStopLooking) then
                    setPedAnimation(pedToStopLooking) 
                end
            end, 2000, 1, elementClicked)
        end
        triggerServerEvent("bank:requestBalance",localPlayer)
        transactionAmountInput=""; activeInputElement=nil; showCursor(true); guiSetInputMode("no_binds_when_editing")
        renderHandler=renderBankGUI; clickHandler=handleBankGUIClick; keyHandler=handleBankGUIKey; charHandler=handleBankGUICharacter
        if isTimer(blinkTimer)then killTimer(blinkTimer); blinkTimer = nil; end 
        blinkTimer=setTimer(function()cursorBlinkVisible=not cursorBlinkVisible end,500,0)
        addEventHandler("onClientRender",root,renderHandler)
        addEventHandler("onClientClick",root,clickHandler)
        addEventHandler("onClientKey",root,keyHandler,true) 
        addEventHandler("onClientCharacter",root,charHandler)
    else
        if isTimer(blinkTimer)then killTimer(blinkTimer);blinkTimer=nil;cursorBlinkVisible=true end
        if renderHandler then removeEventHandler("onClientRender",root,renderHandler);renderHandler=nil end
        if clickHandler then removeEventHandler("onClientClick",root,clickHandler);clickHandler=nil end
        if keyHandler then removeEventHandler("onClientKey",root,keyHandler,true);keyHandler=nil end
        if charHandler then removeEventHandler("onClientCharacter",root,charHandler);charHandler=nil end
        
        local anyOtherGlobalGuiActive = false 
        for k, v in pairs(_G) do
            if type(k) == "string" and string.sub(k, 1, 3) == "is_" and string.sub(k, -8) == "Visible" and k ~= "isBankGUIVisible" then
                if v == true then anyOtherGlobalGuiActive = true; break end
            end
        end
        if _G.isMessageGUIOpen then anyOtherGlobalGuiActive = true end

        if not anyOtherGlobalGuiActive and not _G.isCursorManuallyShownByClickSystem then
             showCursor(false); guiSetInputMode("allow_binds")
        end
        guiElements={}
    end
end

function handleBankGUIClick(button,state)
    if not isBankGUIVisible or button~="left" or state~="up" then return end
    local prevActiveInput=activeInputElement;activeInputElement=nil
    for id,area in pairs(guiElements)do if isCursorOverElement(area)then
        if id=="amount_input"then activeInputElement="amount";return
        elseif id=="deposit"then local amount=tonumber(transactionAmountInput)
            if amount and amount>0 then triggerServerEvent("bank:depositMoney",localPlayer,amount);transactionAmountInput=""
            else outputChatBox("Ungültiger Betrag.",255,100,0)end
        elseif id=="withdraw"then local amount=tonumber(transactionAmountInput)
            if amount and amount>0 then triggerServerEvent("bank:withdrawMoney",localPlayer,amount);transactionAmountInput=""
            else outputChatBox("Ungültiger Betrag.",255,100,0)end
        elseif id=="close"then toggleBankGUI()end
        playSoundFrontEnd(40);return
    end end
    if prevActiveInput=="amount"and not isCursorOverElement(guiElements["amount_input"])then activeInputElement=nil end
end

function handleBankGUIKey(key,press)
    if not isBankGUIVisible then return end
    if key=="escape"and press then toggleBankGUI();cancelEvent();return end
    if activeInputElement=="amount"then
        if press then
            if key=="backspace"then transactionAmountInput=string.sub(transactionAmountInput,1,-2);cancelEvent()
            elseif key=="enter"then activeInputElement=nil;cancelEvent()
            elseif(key>="0"and key<="9")or(key>="num_0"and key<="num_9")then cancelEvent()end
        end
    end
end

function handleBankGUICharacter(character)
    if not isBankGUIVisible or activeInputElement~="amount" then return end
    if tonumber(character)then if string.len(transactionAmountInput)<9 then transactionAmountInput=transactionAmountInput..character end end
end

function isCursorOverElement(elementData)
    if not isCursorShowing()or not elementData then return false end
    local cX,cY=getCursorPosition();if not cX then return false end
    local absCX,absCY=cX*screenW,cY*screenH
    return absCX>=elementData.x and absCX<=elementData.x+elementData.w and absCY>=elementData.y and absCY<=elementData.y+elementData.h
end

addEvent("bank:requestOpenGUI_Client",true);addEventHandler("bank:requestOpenGUI_Client",root,function(clickedEl)toggleBankGUI(clickedEl)end) -- clickedEl kann Ped oder ATM sein
addEvent("bank:updateBalance",true);addEventHandler("bank:updateBalance",root,function(cash,bank)bankData.cash=cash or 0;bankData.bankMoney=bank or 0 end)
addEvent("bank:transactionFeedback",true);addEventHandler("bank:transactionFeedback",root,function(msg,isErr)local r,g,b=0,200,50;if isErr then r,g,b=255,100,0 end;outputChatBox(msg,r,g,b)end)

addEventHandler("onClientResourceStart",resourceRoot,function()
    _G.isBankGUIVisible=false
    if isTimer(blinkTimer)then killTimer(blinkTimer);blinkTimer=nil end
    --outputDebugString("[BankClient] Bank-System Client (V1.3) geladen.")
end)
addEventHandler("onClientResourceStop",resourceRoot,function()
    if isBankGUIVisible then toggleBankGUI()end
    if isTimer(blinkTimer)then killTimer(blinkTimer);blinkTimer=nil end
end)