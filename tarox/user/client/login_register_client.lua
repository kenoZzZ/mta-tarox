-- tarox/user/client/login_register_client.lua
-- VERSION 4c: Angepasste Schriftskalierung, Icons, gut lesbare Event-Handler

local screenW, screenH = guiGetScreenSize()
local isLoginVisible = false
local isRegisterVisible = false
local isRenderHandlerActive = false

local usernameInput = ""
local passwordInput = ""
local passwordRepeatInput = ""
local emailInput = ""

local activeInput = nil
local cursorVisible = true
local rememberMe = false
local encryptionKey = "aVerySecretKey!§$%&" -- BITTE ÄNDERN SIE DIESEN SCHLÜSSEL!

-- ====================================================
-- Design Konstanten
-- ====================================================
local layout = {
    panelW_login = 420, panelH_login = 380,
    panelW_register = 450, panelH_register = 480,
    headerH = 50, padding = 20,
    inputFieldH = 38, inputFieldSpacing = 15,
    checkboxSize = 20, checkboxLabelOffset = 8,
    buttonH = 42, buttonSpacing = 12,
    iconSize = 20,
    iconPadding = 10,
}

local colors = {
    BG_MAIN = tocolor(28, 30, 36, 245),
    BG_HEADER = tocolor(38, 40, 48, 250),
    BG_INPUT = tocolor(45, 48, 56, 255),
    BORDER_LIGHT = tocolor(55, 58, 68, 200),
    BORDER_DARK = tocolor(20, 22, 28, 220),
    TEXT_HEADER = tocolor(235, 235, 240),
    TEXT_LABEL = tocolor(170, 175, 185),
    TEXT_INPUT = tocolor(210, 215, 225),
    TEXT_PLACEHOLDER = tocolor(120, 125, 135),
    TEXT_LINK = tocolor(100, 150, 255),
    BUTTON_PRIMARY_BG = tocolor(0, 122, 204, 220),
    BUTTON_PRIMARY_HOVER = tocolor(0, 142, 234, 230),
    BUTTON_SECONDARY_BG = tocolor(80, 85, 95, 220),
    BUTTON_SECONDARY_HOVER = tocolor(100, 105, 115, 230),
    BUTTON_SUCCESS_BG = tocolor(70, 180, 70, 220),
    BUTTON_SUCCESS_HOVER = tocolor(90, 200, 90, 230),
    BUTTON_DANGER_BG = tocolor(200, 70, 70, 220),
    BUTTON_DANGER_HOVER = tocolor(220, 90, 90, 230),
    BUTTON_TEXT = tocolor(245, 245, 245),
    CHECKBOX_BG = tocolor(45, 48, 56, 255),
    CHECKBOX_TICK = tocolor(0, 180, 100, 255),
}

local fonts = {
    HEADER = {font = "default-bold", scale = 1.3},
    INPUT_TEXT = {font = "default", scale = 1.0},
    INPUT_PLACEHOLDER = {font = "default", scale = 1.0},
    BUTTON = {font = "default-bold", scale = 1.05},
    LABEL = {font = "default", scale = 1.0},
    LINK_TEXT = {font = "default-bold", scale = 1.0}
}

local icons = {
    USER = "user/client/images/usericons/user_icon.png",
    PASSWORD = "user/client/images/usericons/password_icon.png",
    EMAIL = "user/client/images/usericons/email_icon.png",
    LOGIN = "user/client/images/usericons/login_arrow_icon.png",
    REGISTER = "user/client/images/usericons/register_plus_icon.png",
    BACK = "user/client/images/usericons/back_arrow_icon.png"
}

-- Hilfsfunktion zum Zeichnen gestylter Buttons
local function dxDrawStyledButton(text, x, y, w, h, bgColor, hoverColor, textColor, fontStyle, iconPath)
    local cX, cY = getCursorPosition()
    local hover = false
    if cX then
        local mouseX, mouseY = cX * screenW, cY * screenH
        hover = mouseX >= x and mouseX <= x + w and mouseY >= y and mouseY <= y + h
    end
    local currentBgColor = hover and hoverColor or bgColor
    dxDrawRectangle(x, y, w, h, currentBgColor)
    dxDrawLine(x, y, x + w, y, colors.BORDER_LIGHT, 1)
    dxDrawLine(x, y + h, x + w, y + h, colors.BORDER_DARK, 1)
    dxDrawLine(x, y, x, y + h, colors.BORDER_LIGHT, 1)
    dxDrawLine(x + w, y, x + w, y + h, colors.BORDER_DARK, 1)
    local textDrawX = x; local textDrawW = w; local actualText = text
    if iconPath and fileExists(iconPath) then
        local iconDrawSize = layout.iconSize * 0.9
        local iconDrawY = y + (h - iconDrawSize) / 2
        local textWidth = dxGetTextWidth(text, fontStyle.scale, fontStyle.font)
        local totalContentWidth = iconDrawSize + layout.iconPadding * 0.5 + textWidth
        local startContentX = x + (w - totalContentWidth) / 2
        dxDrawImage(startContentX, iconDrawY, iconDrawSize, iconDrawSize, iconPath, 0,0,0,tocolor(255,255,255,230))
        textDrawX = startContentX + iconDrawSize + layout.iconPadding * 0.5
        dxDrawText(actualText, textDrawX, y, (x + w) - (startContentX - x) , y + h, textColor, fontStyle.scale, fontStyle.font, "left", "center", false, false, false, true)
    else
        dxDrawText(actualText, textDrawX, y, textDrawX + textDrawW, y + h, textColor, fontStyle.scale, fontStyle.font, "center", "center", false, false, false, true)
    end
end

-- Hilfsfunktion zum Zeichnen von Eingabefeldern
local function dxDrawStyledInput(value, placeholder, x, y, w, h, isActive, isPassword, iconPath)
    dxDrawRectangle(x, y, w, h, colors.BG_INPUT)
    dxDrawLine(x,y, x+w, y, colors.BORDER_DARK,1); dxDrawLine(x,y+h, x+w, y+h, colors.BORDER_LIGHT,1)
    dxDrawLine(x,y, x, y+h, colors.BORDER_DARK,1); dxDrawLine(x+w,y, x+w, y+h, colors.BORDER_LIGHT,1)
    local textX = x + layout.padding / 2; local textW = w - layout.padding
    if iconPath and fileExists(iconPath) then
        local iconDrawSize = layout.iconSize; local iconX = x + layout.iconPadding/2; local iconY = y + (h-iconDrawSize)/2
        dxDrawImage(iconX, iconY, iconDrawSize, iconDrawSize, iconPath, 0,0,0,tocolor(255,255,255,255)) -- Icon Farbe korrigiert
        textX = iconX + iconDrawSize + layout.iconPadding/2; textW = w - (textX - x) - (layout.padding/2)
    end
    local displayText = value; local displayColor = colors.TEXT_INPUT; local currentFontStyle = fonts.INPUT_TEXT
    if value == "" and not isActive then displayText = placeholder; displayColor = colors.TEXT_PLACEHOLDER; currentFontStyle = fonts.INPUT_PLACEHOLDER end
    if isPassword and value ~= "" then displayText = string.rep("*", #value) end
    if isActive and cursorVisible then displayText = displayText .. "|" end
    dxDrawText(displayText, textX, y, textX + textW, y + h, displayColor, currentFontStyle.scale, currentFontStyle.font, "left", "center", false,true)
end

-- "Remember Me" Logik
local function bitXor(a,b)local r,p=0,1;while a>0 or b>0 do local x,y=a%2,b%2;r=r+((x+y)%2)*p;a=(a-x)/2;b=(b-y)/2;p=p*2 end;return r end
local function xorEncryptDecrypt(i,k)if type(i)~="string"then return""end;if type(k)~="string"or #k==0 then return""end;local o={};for l=1,#i do local c=string.byte(i,l);local m=string.byte(k,(l-1)%#k+1);if not c or not m then return""end;o[l]=string.char(bitXor(c,m))end;return table.concat(o)end
local function saveCredentials(u,p)local eP=xorEncryptDecrypt(p,encryptionKey);if eP==""and p~=""then return end;local x=xmlCreateFile("@rememberLogin.xml","remember");if not x then return end;local uC=xmlCreateChild(x,"username");if uC then xmlNodeSetValue(uC,u)end;local pC=xmlCreateChild(x,"password");if pC then xmlNodeSetValue(pC,eP)end;xmlSaveFile(x);if type(x)=="userdata"then xmlUnloadFile(x)end end
local function loadCredentials()local x=xmlLoadFile("@rememberLogin.xml");if not x then rememberMe=false;return false end;local uN=xmlFindChild(x,"username",0);local pN=xmlFindChild(x,"password",0);local s=false;if uN and pN then local uV=xmlNodeGetValue(uN);local ePV=xmlNodeGetValue(pN);if uV and ePV and ePV~=""then local pw=xorEncryptDecrypt(ePV,encryptionKey);if pw~=""or ePV==""then usernameInput=uV;passwordInput=pw;rememberMe=true;s=true else rememberMe=false end else rememberMe=false end else rememberMe=false end;if type(x)=="userdata"then xmlUnloadFile(x)end;return s end
function clearCredentials()if fileExists("@rememberLogin.xml")then fileDelete("@rememberLogin.xml")end;rememberMe=false end

setTimer(function() if isLoginVisible or isRegisterVisible then cursorVisible = not cursorVisible end end, 500, 0)
addEvent("showMessage", true); addEventHandler("showMessage", root, function(msg, r, g, b) outputChatBox(msg, r, g, b) end)

addEvent("loginSuccess", true)
addEventHandler("loginSuccess", root, function()
    isLoginVisible=false;isRegisterVisible=false;activeInput=nil
    if isRenderHandlerActive then removeEventHandler("onClientRender",root,renderLoginRegisterGUI);isRenderHandlerActive=false end
    if rememberMe then saveCredentials(usernameInput,passwordInput)else clearCredentials()end
    showCursor(false);guiSetInputMode("allow_binds")
end)

addEvent("switchToLogin", true)
addEventHandler("switchToLogin", root, function()
    isRegisterVisible=false;isLoginVisible=true;passwordInput="";passwordRepeatInput="";emailInput="";activeInput="PasswordLogin"
end)

addEvent("forceShowLogin", true)
addEventHandler("forceShowLogin", root, function()
    isLoginVisible=true;isRegisterVisible=false;activeInput=nil;usernameInput="";passwordInput="";passwordRepeatInput="";emailInput="";rememberMe=false
    showCursor(true);guiSetInputMode("no_binds_when_editing")
    if not isRenderHandlerActive then addEventHandler("onClientRender",root,renderLoginRegisterGUI);isRenderHandlerActive=true end
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    loadCredentials()
    isLoginVisible=true;isRegisterVisible=false;activeInput="UsernameLogin"
    showCursor(true);guiSetInputMode("no_binds_when_editing")
    if not isRenderHandlerActive then addEventHandler("onClientRender",root,renderLoginRegisterGUI);isRenderHandlerActive=true end
end)

function renderLoginRegisterGUI()
    if not isLoginVisible and not isRegisterVisible then return end
    local panelW, panelH, panelX, panelY; local currentY

    if isLoginVisible then
        panelW,panelH=layout.panelW_login,layout.panelH_login;panelX,panelY=(screenW-panelW)/2,(screenH-panelH)/2;currentY=panelY+layout.headerH+layout.padding
        dxDrawRectangle(panelX,panelY,panelW,panelH,colors.BG_MAIN)
        dxDrawRectangle(panelX,panelY,panelW,layout.headerH,colors.BG_HEADER)
        dxDrawText("Willkommen zurück!",panelX,panelY,panelX+panelW,panelY+layout.headerH,colors.TEXT_HEADER,fonts.HEADER.scale,fonts.HEADER.font,"center","center")
        dxDrawStyledInput(usernameInput,"Benutzername",panelX+layout.padding,currentY,panelW-2*layout.padding,layout.inputFieldH,activeInput=="UsernameLogin",false,icons.USER)
        currentY=currentY+layout.inputFieldH+layout.inputFieldSpacing
        dxDrawStyledInput(passwordInput,"Passwort",panelX+layout.padding,currentY,panelW-2*layout.padding,layout.inputFieldH,activeInput=="PasswordLogin",true,icons.PASSWORD)
        currentY=currentY+layout.inputFieldH+layout.padding
        local cbX,cbY,cbS=panelX+layout.padding,currentY,layout.checkboxSize
        dxDrawRectangle(cbX,cbY,cbS,cbS,colors.CHECKBOX_BG)
        if rememberMe then dxDrawLine(cbX+cbS*0.2,cbY+cbS*0.5,cbX+cbS*0.4,cbY+cbS*0.7,colors.CHECKBOX_TICK,2);dxDrawLine(cbX+cbS*0.4,cbY+cbS*0.7,cbX+cbS*0.8,cbY+cbS*0.3,colors.CHECKBOX_TICK,2)end
        dxDrawText("Angemeldet bleiben",cbX+cbS+layout.checkboxLabelOffset,cbY,cbX+cbS+180,cbY+cbS,colors.TEXT_LABEL,fonts.LABEL.scale,fonts.LABEL.font,"left","center")
        currentY=currentY+cbS+layout.padding
        dxDrawStyledButton("Login",panelX+layout.padding,currentY,panelW-2*layout.padding,layout.buttonH,colors.BUTTON_PRIMARY_BG,colors.BUTTON_PRIMARY_HOVER,colors.BUTTON_TEXT,fonts.BUTTON,icons.LOGIN)
        currentY=currentY+layout.buttonH+layout.padding*0.75
        dxDrawText("Noch keinen Account?",panelX,currentY,panelX+panelW,currentY+20,colors.TEXT_LABEL,fonts.LABEL.scale,fonts.LABEL.font,"center","top")
        currentY=currentY+20
        dxDrawStyledButton("Hier registrieren",panelX+layout.padding*2,currentY,panelW-4*layout.padding,layout.buttonH-5,colors.BUTTON_SUCCESS_BG,colors.BUTTON_SUCCESS_HOVER,colors.BUTTON_TEXT,fonts.LINK_TEXT,icons.REGISTER)
    elseif isRegisterVisible then
        panelW,panelH=layout.panelW_register,layout.panelH_register;panelX,panelY=(screenW-panelW)/2,(screenH-panelH)/2;currentY=panelY+layout.headerH+layout.padding
        dxDrawRectangle(panelX,panelY,panelW,panelH,colors.BG_MAIN)
        dxDrawRectangle(panelX,panelY,panelW,layout.headerH,colors.BG_HEADER)
        dxDrawText("Account erstellen",panelX,panelY,panelX+panelW,panelY+layout.headerH,colors.TEXT_HEADER,fonts.HEADER.scale,fonts.HEADER.font,"center","center")
        dxDrawStyledInput(usernameInput,"Benutzername (3-20 Zeichen)",panelX+layout.padding,currentY,panelW-2*layout.padding,layout.inputFieldH,activeInput=="UsernameReg",false,icons.USER)
        currentY=currentY+layout.inputFieldH+layout.inputFieldSpacing
        dxDrawStyledInput(passwordInput,"Passwort (min. 5 Zeichen)",panelX+layout.padding,currentY,panelW-2*layout.padding,layout.inputFieldH,activeInput=="PasswordReg",true,icons.PASSWORD)
        currentY=currentY+layout.inputFieldH+layout.inputFieldSpacing
        dxDrawStyledInput(passwordRepeatInput,"Passwort wiederholen",panelX+layout.padding,currentY,panelW-2*layout.padding,layout.inputFieldH,activeInput=="RepeatPasswordReg",true,icons.PASSWORD)
        currentY=currentY+layout.inputFieldH+layout.inputFieldSpacing
        dxDrawStyledInput(emailInput,"E-Mail Adresse",panelX+layout.padding,currentY,panelW-2*layout.padding,layout.inputFieldH,activeInput=="EmailReg",false,icons.EMAIL)
        currentY=currentY+layout.inputFieldH+layout.padding
        dxDrawStyledButton("Registrieren",panelX+layout.padding,currentY,panelW-2*layout.padding,layout.buttonH,colors.BUTTON_SUCCESS_BG,colors.BUTTON_SUCCESS_HOVER,colors.BUTTON_TEXT,fonts.BUTTON,icons.REGISTER)
        currentY=currentY+layout.buttonH+layout.inputFieldSpacing
        dxDrawStyledButton("Zurück zum Login",panelX+layout.padding,currentY,panelW-2*layout.padding,layout.buttonH,colors.BUTTON_DANGER_BG,colors.BUTTON_DANGER_HOVER,colors.BUTTON_TEXT,fonts.BUTTON,icons.BACK)
    end
end

addEventHandler("onClientClick", root, function(button, state, clickX, clickY)
    if not isLoginVisible and not isRegisterVisible then return end
    if button ~= "left" or state ~= "up" then return end

    local panelW, panelH, panelX, panelY
    local currentY_check

    if isLoginVisible then
        panelW, panelH = layout.panelW_login, layout.panelH_login
        panelX, panelY = (screenW - panelW) / 2, (screenH - panelH) / 2
        currentY_check = panelY + layout.headerH + layout.padding

        -- Username field
        if clickX >= panelX + layout.padding and clickX <= panelX + panelW - layout.padding and
           clickY >= currentY_check and clickY <= currentY_check + layout.inputFieldH then
            activeInput = "UsernameLogin"; return
        end
        currentY_check = currentY_check + layout.inputFieldH + layout.inputFieldSpacing

        -- Password field
        if clickX >= panelX + layout.padding and clickX <= panelX + panelW - layout.padding and
           clickY >= currentY_check and clickY <= currentY_check + layout.inputFieldH then
            activeInput = "PasswordLogin"; return
        end
        currentY_check = currentY_check + layout.inputFieldH + layout.padding

        -- Remember Me checkbox
        local cbX, cbY, cbSize = panelX + layout.padding, currentY_check, layout.checkboxSize
        if clickX >= cbX and clickX <= cbX + cbSize + 150 and -- Erweiteter Klickbereich für Text
           clickY >= cbY and clickY <= cbY + cbSize then
            rememberMe = not rememberMe; activeInput = nil; return
        end
        currentY_check = currentY_check + cbSize + layout.padding

        -- Login Button
        if clickX >= panelX + layout.padding and clickX <= panelX + panelW - layout.padding and
           clickY >= currentY_check and clickY <= currentY_check + layout.buttonH then
            if usernameInput ~= "" and passwordInput ~= "" then
                triggerServerEvent("loginPlayer", localPlayer, usernameInput, passwordInput)
            else outputChatBox("Bitte Benutzername und Passwort eingeben!", 255, 100, 0) end
            activeInput = nil; return
        end
        currentY_check = currentY_check + layout.buttonH + layout.padding * 0.75 + 20 -- +20 for "No account yet?" text

        -- Register Button
        if clickX >= panelX + layout.padding * 2 and clickX <= panelX + panelW - layout.padding * 2 and
           clickY >= currentY_check and clickY <= currentY_check + layout.buttonH - 5 then
            isLoginVisible = false; isRegisterVisible = true; activeInput = "UsernameReg"
            passwordInput = ""; passwordRepeatInput = ""; emailInput = ""; usernameInput = ""
            return
        end
        activeInput = nil

    elseif isRegisterVisible then
        panelW, panelH = layout.panelW_register, layout.panelH_register
        panelX, panelY = (screenW - panelW) / 2, (screenH - panelH) / 2
        currentY_check = panelY + layout.headerH + layout.padding

        -- UsernameReg field
        if clickX >= panelX + layout.padding and clickX <= panelX + panelW - layout.padding and
           clickY >= currentY_check and clickY <= currentY_check + layout.inputFieldH then
            activeInput = "UsernameReg"; return
        end
        currentY_check = currentY_check + layout.inputFieldH + layout.inputFieldSpacing

        -- PasswordReg field
        if clickX >= panelX + layout.padding and clickX <= panelX + panelW - layout.padding and
           clickY >= currentY_check and clickY <= currentY_check + layout.inputFieldH then
            activeInput = "PasswordReg"; return
        end
        currentY_check = currentY_check + layout.inputFieldH + layout.inputFieldSpacing

        -- RepeatPasswordReg field
        if clickX >= panelX + layout.padding and clickX <= panelX + panelW - layout.padding and
           clickY >= currentY_check and clickY <= currentY_check + layout.inputFieldH then
            activeInput = "RepeatPasswordReg"; return
        end
        currentY_check = currentY_check + layout.inputFieldH + layout.inputFieldSpacing

        -- EmailReg field
        if clickX >= panelX + layout.padding and clickX <= panelX + panelW - layout.padding and
           clickY >= currentY_check and clickY <= currentY_check + layout.inputFieldH then
            activeInput = "EmailReg"; return
        end
        currentY_check = currentY_check + layout.inputFieldH + layout.padding

        -- Register Button
        if clickX >= panelX + layout.padding and clickX <= panelX + panelW - layout.padding and
           clickY >= currentY_check and clickY <= currentY_check + layout.buttonH then
            if usernameInput == "" or passwordInput == "" or passwordRepeatInput == "" or emailInput == "" then
                outputChatBox("Bitte alle Felder ausfüllen!", 255, 100, 0)
            elseif passwordInput ~= passwordRepeatInput then
                outputChatBox("Passwörter stimmen nicht überein!", 255, 0, 0)
            else
                triggerServerEvent("registerPlayer", localPlayer, usernameInput, passwordInput, emailInput)
            end
            activeInput = nil; return
        end
        currentY_check = currentY_check + layout.buttonH + layout.inputFieldSpacing

        -- Back Button
        if clickX >= panelX + layout.padding and clickX <= panelX + panelW - layout.padding and
           clickY >= currentY_check and clickY <= currentY_check + layout.buttonH then
            isRegisterVisible = false; isLoginVisible = true; activeInput = "UsernameLogin"
            passwordInput = ""; passwordRepeatInput = ""; emailInput = ""
            return
        end
        activeInput = nil
    end
end)

addEventHandler("onClientCharacter", root, function(character)
    if not isLoginVisible and not isRegisterVisible or not activeInput then return end
    local maxLength = 30;
    if activeInput == "UsernameLogin" or activeInput == "UsernameReg" then
        maxLength = 20
        if not string.match(character, "^[%w_]$") then return end
    elseif activeInput == "EmailReg" then
        maxLength = 50
        if not string.match(character, "^[%w%p@%.%-]$") then return end
    elseif activeInput == "PasswordLogin" or activeInput == "PasswordReg" or activeInput == "RepeatPasswordReg" then
         maxLength = 30
         if string.byte(character) < 32 or string.byte(character) > 126 then return end
    end

    if activeInput == "UsernameLogin" then
        if #usernameInput < maxLength then usernameInput = usernameInput .. character end
    elseif activeInput == "PasswordLogin" then
        if #passwordInput < maxLength then passwordInput = passwordInput .. character end
    elseif activeInput == "UsernameReg" then
        if #usernameInput < maxLength then usernameInput = usernameInput .. character end
    elseif activeInput == "PasswordReg" then
        if #passwordInput < maxLength then passwordInput = passwordInput .. character end
    elseif activeInput == "RepeatPasswordReg" then
        if #passwordRepeatInput < maxLength then passwordRepeatInput = passwordRepeatInput .. character end
    elseif activeInput == "EmailReg" then
        if #emailInput < maxLength then emailInput = emailInput .. character end
    end
end)

addEventHandler("onClientKey", root, function(key, press)
    if not isLoginVisible and not isRegisterVisible or not activeInput or key ~= "backspace" or not press then return end

    if activeInput == "UsernameLogin" and #usernameInput > 0 then
        usernameInput = string.sub(usernameInput, 1, -2)
    elseif activeInput == "PasswordLogin" and #passwordInput > 0 then
        passwordInput = string.sub(passwordInput, 1, -2)
    elseif activeInput == "UsernameReg" and #usernameInput > 0 then
        usernameInput = string.sub(usernameInput, 1, -2)
    elseif activeInput == "PasswordReg" and #passwordInput > 0 then
        passwordInput = string.sub(passwordInput, 1, -2)
    elseif activeInput == "RepeatPasswordReg" and #passwordRepeatInput > 0 then
        passwordRepeatInput = string.sub(passwordRepeatInput, 1, -2)
    elseif activeInput == "EmailReg" and #emailInput > 0 then
        emailInput = string.sub(emailInput, 1, -2)
    end
end)

addEventHandler("onClientResourceStop",resourceRoot,function()
    if isRenderHandlerActive then
        removeEventHandler("onClientRender",root,renderLoginRegisterGUI)
        isRenderHandlerActive=false
    end
    showCursor(false)
    guiSetInputMode("allow_binds")
end)