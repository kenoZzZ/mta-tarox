-- tarox/fraktionen/mechanic/cartune_client.lua
-- Clientseitige Logik für das Fahrzeug-Tuning & Lackier-Menü
-- Design V8.3: Spezifische Kameraposition für Felgenauswahl und Entsperren des Spielers.
-- NEU V9: Mechaniker-Interaktion für Lvl 2/3 Motor/Nitro
-- NEU V9.1: Fortschrittsbalken für Installation

local screenW, screenH = guiGetScreenSize()
local localPlayer = getLocalPlayer()

----------------------------------------------------------------
--[[                DESIGN & THEME KONFIGURATION            ]]--
----------------------------------------------------------------
local theme = {
    font = "default-bold",
    window = {
        width = 580, height = 500,
        color = {r=28, g=30, b=36, a=245},
        strokeColor = {r=10, g=10, b=12, a=200},
        borderRadius = 0,
        alignX = "left", alignY = "center", offsetX = 20, offsetY = 0
    },
    header = {
        height = 48, color = {r=35, g=38, b=46, a=250},
        textColor = {r=235, g=235, b=240, a=255}, textSize = 1.3,
    },
    tabs = {
        height = 40, bgColor = {r=22, g=24, b=28, a=255},
        activeColor = {r=28, g=30, b=36, a=255},
        inactiveColor = {r=35, g=38, b=46, a=255},
        hoverColor = {r=42, g=45, b=53, a=255},
        textColor = {r=210, g=215, b=225, a=255},
        iconColor = {r=200, g=200, b=210, a=230}, iconSize = 18, iconPadding = 7,
        borderColor = {r=45,g=48,b=56,a=200},
        underlineColor = {r=0, g=122, b=204, a=255}
    },
    buttons = {
        height = 38, radius = 0,
        shadowOffset = 1, shadowColor = {r=0, g=0, b=0, a=70},
        primary = { bg = {r=0, g=122, b=204, a=220}, hover = {r=0, g=142, b=234, a=230}, text = {r=245, g=245, b=245, a=255}},
        success = { bg = {r=40, g=167, b=69, a=220}, hover = {r=50, g=187, b=89, a=230}, text = {r=245, g=245, b=245, a=255}},
        danger = { bg = {r=200, g=70, b=70, a=220}, hover = {r=220, g=90, b=90, a=230}, text = {r=245, g=245, b=245, a=255}},
        disabled = { bg = {r=50, g=55, b=60, a=180}, hover = {r=50,g=55,b=60,a=180}, text = {r=120, g=120, b=120, a=200}},
        item = {
            bg = {r=40,g=43,b=51,a=210}, hover = {r=55,g=58,b=68,a=220}, text = {r=210,g=215,b=225,a=255},
            installedText = {r=90,g=210,b=140,a=255}, priceText = {r=100,g=220,b=150,a=255},
            unavailableText = {r=150,g=150,b=160,a=200},
            previewActiveText = {r=100, 200, 255, a=255},
            requestSentText = {r=255,165,0,a=255}
        },
        wheelTextButton = {
            bg = {r=42, g=45, b=53, a=230}, hover = {r=55, g=58, b=68, a=240},
            text = {r=190, g=195, b=205, a=255}, installedText = {r=90,g=210,b=140,a=255},
            previewActiveText = {r=100, 200, 255, a=255},
            height = 32
        }
    },
    labels = { groupColor = {r=220, g=225, b=230, a=255}, groupSize = 1.05, priceColor = {r=90, g=210, b=140, a=255}},
    colors = {
        SLIDER_BG = {r=40, g=42, b=50, a=220}, SLIDER_FG_R = {r=220, g=80, b=80, a=220},
        SLIDER_FG_G = {r=80, g=200, b=80, a=220}, SLIDER_FG_B = {r=80, g=130, b=220, a=220},
        SLIDER_HANDLE = {r=220, g=220, b=230, a=250}, BORDER_LIGHT = {r=55, g=58, b=68, a=180},
        BORDER_DARK = {r=20, g=22, b=28, a=220}, COLOR_PREVIEW_BG = {r=20,g=22,b=25,a=200},
        PROGRESS_BAR_BG = {r=50, g=50, b=50, a=220},  -- NEU
        PROGRESS_BAR_FG = {r=0, g=150, b=255, a=220}, -- NEU
        PROGRESS_BAR_BORDER = {r=10,g=10,b=10,a=200}, -- NEU
        PROGRESS_TEXT = {r=255,g=255,b=255,a=255}    -- NEU
    },
    layout = {
        padding = 15, contentPadding = 20, iconSize = 18, iconPadding = 6,
        sliderHeight = 10, sliderHandleWidth = 6, sliderHandleHeightExtra = 4,
        colorPreviewHeight = 55, scrollBarWidth = 8,
        scrollThumbColor = {r=70,g=75,b=85,a=180}, scrollBgColor = {r=25,g=28,b=32,a=160},
        buttonSpacing = 10,
        confirmDialog = {
            width = 380, height = 200,
            headerHeight = 40,
            buttonWidth = 120,
            buttonSpacing = 15
        },
        progressBarW = 280, -- NEU
        progressBarH = 25   -- NEU
    }
}

----------------------------------------------------------------
--[[                     STATUS-VARIABLEN                     ]]--
----------------------------------------------------------------
local isMenuVisible = false
_G.isTuneMenuVisible = false
local tuneMenuTargetVehicle = nil
local currentTuneData = {}
local activeTab = "tuning"
local originalVehicleColors = nil
local hoverStates = {}
local colorSliders = {}
local activeSlider = nil
local mtaColors = {}
local TUNE_PRICES = {
    engine = { 15000, 35000, 70000 }, nitro  = { 5000, 12000, 25000 },
    wheels = 8000, paint = 350
}
local NITRO_UPGRADE_IDS_CLIENT = { [1]=1010, [2]=1009, [3]=1008 }
local wheelIDs = {
    {name = "Twist",   id = 1073}, {name = "Cutter",  id = 1074}, {name = "Offroad", id = 1075},
    {name = "Mega",    id = 1076}, {name = "Dollar",  id = 1077}, {name = "Trance",  id = 1078},
    {name = "Shadow",  id = 1080}, {name = "Classic", id = 1081}, {name = "Switch",  id = 1082},
    {name = "Groove",  id = 1083}, {name = "Stalker", id = 1084}, {name = "Import",  id = 1085}
}
local wheelScrollOffset = 0; local maxVisibleWheels = 12; local clickableElements = {}
local currentPanelX, currentPanelY = 0, 0

local isPurchaseConfirmVisible = false
local purchaseConfirmData = { tuneType = nil, levelOrID = nil, itemName = "", itemPrice = 0 }
local confirmDialogClickableElements = {}

local originalWheelIDOnMenuOpen = 0
local previewWheelIDClient = nil

local STANDARD_TUNE_CAMERA_POS_FROM = {-2040.61511, 162.77849, 28.83562 + 1.0}
local VEHICLE_AT_TUNE_POS_LOOKAT = {-2047.60974, 173.88263, 28.35471 + 0.5}
local WHEEL_FOCUS_CAMERA_POS_FROM = {-2047.49463, 169.15517, 28.83562}
local currentCameraMode = "standard"

local pendingMechanicRequest = {
    active = false, tuneType = nil, levelOrID = nil, message = ""
}

-- NEU: Variablen für Fortschrittsbalken
local isInstallProgressActive = false
local installProgressEndTime = 0
local installProgressDuration = 0
local installProgressText = "Installation..."
local installProgressRenderHandler = nil

----------------------------------------------------------------
--[[                  MODERNE ZEICHENFUNKTIONEN               ]]--
-- (dxDrawRoundedRectangle, lerpColor, dxDrawUserPanelStyleButton bleiben unverändert)
----------------------------------------------------------------
function dxDrawRoundedRectangle(x, y, w, h, colorTable, radius)
    if not colorTable or type(colorTable.r) ~= "number" then outputDebugString("dxDrawRoundedRectangle: colorTable ist ungültig: " .. inspect(colorTable)); return end
	local finalColor = tocolor(colorTable.r, colorTable.g, colorTable.b, colorTable.a)
    radius = radius or theme.window.borderRadius
    if radius <= 0 then dxDrawRectangle(x, y, w, h, finalColor); return end
    dxDrawRectangle(x + radius, y, w - 2 * radius, h, finalColor); dxDrawRectangle(x, y + radius, w, h - 2 * radius, finalColor)
    dxDrawCircle(x+radius,y+radius,radius,finalColor,finalColor,36,180,90); dxDrawCircle(x+w-radius,y+radius,radius,finalColor,finalColor,36,270,90)
    dxDrawCircle(x+radius,y+h-radius,radius,finalColor,finalColor,36,90,90); dxDrawCircle(x+w-radius,y+h-radius,radius,finalColor,finalColor,36,0,90)
end

function lerpColor(fromColor, toColor, progress)
    local p = math.max(0, math.min(1, progress))
    if type(fromColor)~="table" or not fromColor.r then fromColor={r=0,g=0,b=0,a=255} end
    if type(toColor)~="table" or not toColor.r then toColor=fromColor end
    return { r = fromColor.r + (toColor.r - fromColor.r) * p, g = fromColor.g + (toColor.g - fromColor.g) * p, b = fromColor.b + (toColor.b - fromColor.b) * p, a = fromColor.a + (toColor.a - fromColor.a) * p }
end

function dxDrawUserPanelStyleButton(id, text, x, y, w, h, styleKey, enabled, iconPath, parentClickableTable)
    parentClickableTable = parentClickableTable or clickableElements
    enabled = (enabled == nil) and true or enabled
    local buttonThemeToUse = enabled and theme.buttons[styleKey] or theme.buttons.disabled
    if not buttonThemeToUse then outputDebugString("dxDrawUserPanelStyleButton: buttonThemeToUse für StyleKey "..tostring(styleKey).." ist nil"); return end
    if not buttonThemeToUse.bg then outputDebugString("dxDrawUserPanelStyleButton: buttonThemeToUse.bg ist nil für StyleKey " .. tostring(styleKey)); return end
    local mouseX_abs, mouseY_abs = -1, -1; local cX, cY = getCursorPosition(); if cX then mouseX_abs, mouseY_abs = cX * screenW, cY * screenH end
    local isHovering = enabled and mouseX_abs >= x and mouseX_abs <= x+w and mouseY_abs >= y and mouseY_abs <= y+h
    if not hoverStates[id] then hoverStates[id] = { alpha = 0, lastTick = getTickCount() } end
    local delta = (getTickCount() - hoverStates[id].lastTick) / 150; hoverStates[id].lastTick = getTickCount(); hoverStates[id].alpha = math.max(0, math.min(1, hoverStates[id].alpha + (isHovering and delta or -delta)))
    local hoverColorToUse = buttonThemeToUse.hover or buttonThemeToUse.bg
    local finalBgColorTable = lerpColor(buttonThemeToUse.bg, hoverColorToUse, hoverStates[id].alpha)
    local actualButtonHeight = styleKey == "wheelTextButton" and theme.buttons.wheelTextButton.height or theme.buttons.height
    if theme.buttons.radius > 0 then dxDrawRoundedRectangle(x, y, w, actualButtonHeight, finalBgColorTable, theme.buttons.radius) else dxDrawRectangle(x, y, w, actualButtonHeight, tocolor(finalBgColorTable.r, finalBgColorTable.g, finalBgColorTable.b, finalBgColorTable.a)) end
    dxDrawLine(x,y,x+w,y,tocolor(theme.colors.BORDER_LIGHT.r,theme.colors.BORDER_LIGHT.g,theme.colors.BORDER_LIGHT.b,theme.colors.BORDER_LIGHT.a),1); dxDrawLine(x,y+actualButtonHeight,x+w,y+actualButtonHeight,tocolor(theme.colors.BORDER_DARK.r,theme.colors.BORDER_DARK.g,theme.colors.BORDER_DARK.b,theme.colors.BORDER_DARK.a),1); dxDrawLine(x,y,x,y+actualButtonHeight,tocolor(theme.colors.BORDER_LIGHT.r,theme.colors.BORDER_LIGHT.g,theme.colors.BORDER_LIGHT.b,theme.colors.BORDER_LIGHT.a),1); dxDrawLine(x+w,y,x+w,y+actualButtonHeight,tocolor(theme.colors.BORDER_DARK.r,theme.colors.BORDER_DARK.g,theme.colors.BORDER_DARK.b,theme.colors.BORDER_DARK.a),1)
    local textX_draw, textW_draw, actualText_draw, textColorTable_draw, textFontScale_draw = x, w, text, buttonThemeToUse.text, (styleKey == "wheelTextButton" and 0.9 or 1.05)

    if styleKey == "item" or styleKey == "wheelTextButton" then
        if not enabled then
            textColorTable_draw = theme.buttons.disabled.text
        elseif previewWheelIDClient ~= nil and id == "wheels_".. tostring(previewWheelIDClient) then
            textColorTable_draw = buttonThemeToUse.previewActiveText or textColorTable_draw
        elseif enabled and string.find(text, "(I)", 1, true) then
            textColorTable_draw = buttonThemeToUse.installedText or textColorTable_draw
        elseif pendingMechanicRequest.active and
               ((pendingMechanicRequest.tuneType == "engine" and id == "engine_"..pendingMechanicRequest.levelOrID) or
                (pendingMechanicRequest.tuneType == "nitro"  and id == "nitro_"..pendingMechanicRequest.levelOrID)) then
            textColorTable_draw = theme.buttons.item.requestSentText or textColorTable_draw
            actualText_draw = "Angefragt..."
        end
    end

    if iconPath and fileExists(iconPath) then
        local iconDrawSize_draw, textWidth_draw_calc = theme.layout.iconSize * (styleKey == "wheelTextButton" and 0.8 or 1.0), dxGetTextWidth(text, textFontScale_draw, theme.font); textWidth_draw_calc = textWidth_draw_calc or 0
        local totalContentWidth_draw = iconDrawSize_draw + theme.layout.iconPadding + textWidth_draw_calc
        local startContentX_draw = x + (w - totalContentWidth_draw) / 2; local iconDrawY_draw = y + (actualButtonHeight - iconDrawSize_draw) / 2
        dxDrawImage(startContentX_draw, iconDrawY_draw, iconDrawSize_draw, iconDrawSize_draw, iconPath, 0,0,0,tocolor(textColorTable_draw.r,textColorTable_draw.g,textColorTable_draw.b, (textColorTable_draw.a and textColorTable_draw.a * 0.8) or 200) )
        textX_draw = startContentX_draw + iconDrawSize_draw + theme.layout.iconPadding
        dxDrawText(actualText_draw, textX_draw, y, (x + w) - (startContentX_draw - x) , y + actualButtonHeight, tocolor(textColorTable_draw.r,textColorTable_draw.g,textColorTable_draw.b,textColorTable_draw.a), textFontScale_draw, theme.font, "left", "center", false, false, false, true)
    else
        dxDrawText(actualText_draw, textX_draw, y, textX_draw + textW_draw, y + actualButtonHeight, tocolor(textColorTable_draw.r,textColorTable_draw.g,textColorTable_draw.b,textColorTable_draw.a), textFontScale_draw, theme.font, "center", "center", false, false, false, true)
    end
    table.insert(parentClickableTable, {id=id, x=x, y=y, w=w, h=actualButtonHeight, enabled=enabled, isHovering=isHovering, actionType=styleKey})
end
----------------------------------------------------------------
--[[                 KAMERA-STEUERUNGSFUNKTIONEN            ]]--
-- (setStandardTuneCamera, setWheelFocusCamera bleiben unverändert)
----------------------------------------------------------------
function setStandardTuneCamera()
    setCameraMatrix(STANDARD_TUNE_CAMERA_POS_FROM[1], STANDARD_TUNE_CAMERA_POS_FROM[2], STANDARD_TUNE_CAMERA_POS_FROM[3],
                    VEHICLE_AT_TUNE_POS_LOOKAT[1], VEHICLE_AT_TUNE_POS_LOOKAT[2], VEHICLE_AT_TUNE_POS_LOOKAT[3])
    currentCameraMode = "standard"
end

function setWheelFocusCamera(vehicle)
    if not isElement(vehicle) then
        setStandardTuneCamera()
        return
    end
    setCameraMatrix(WHEEL_FOCUS_CAMERA_POS_FROM[1], WHEEL_FOCUS_CAMERA_POS_FROM[2], WHEEL_FOCUS_CAMERA_POS_FROM[3],
                    VEHICLE_AT_TUNE_POS_LOOKAT[1], VEHICLE_AT_TUNE_POS_LOOKAT[2], VEHICLE_AT_TUNE_POS_LOOKAT[3] + 0.2)
    currentCameraMode = "wheel_focus"
end
----------------------------------------------------------------
--[[ MENÜ-STEUERUNG (ÖFFNEN/SCHLIEßEN) ]]--
-- (unverändert)
----------------------------------------------------------------
addEvent("mechanic:openTuningMenuClient", true)
addEventHandler("mechanic:openTuningMenuClient", root, function(targetVehicle, vehicleTuneData)
    if isMenuVisible or isPurchaseConfirmVisible then return end; isMenuVisible = true; _G.isTuneMenuVisible = true
    tuneMenuTargetVehicle = targetVehicle; currentTuneData = vehicleTuneData or { tune1=0, tune2=0, tune3=0 }
    activeTab = "tuning"; hoverStates = {}; clickableElements = {}
    pendingMechanicRequest = { active = false, tuneType = nil, levelOrID = nil, message = "" }

    if isElement(tuneMenuTargetVehicle) then
        setElementFrozen(localPlayer, true)
        setStandardTuneCamera()
        originalVehicleColors = { getVehicleColor(tuneMenuTargetVehicle, true) }; local mta_c1,mta_c2,mta_c3,mta_c4 = getVehicleColor(tuneMenuTargetVehicle,false); mtaColors={mta_c1 or 0,mta_c2 or 0,mta_c3 or 0,mta_c4 or 0}; colorSliders={}
        for i=1,4 do local r,g,b=getVehicleColor(tuneMenuTargetVehicle,true,i);table.insert(colorSliders,{id=i,r=r or 0,g=g or 0,b=b or 0,text="Farbe "..i..(i==1 and " (Primär)"or""),mtaID=mtaColors[i]})end
        originalWheelIDOnMenuOpen = currentTuneData.tune3 or 0
        previewWheelIDClient = nil
    else outputChatBox("Mechanic Tuning: Ungültiges Fahrzeug-Ziel.",255,0,0); closeMenu(false); return end
    showCursor(true); guiSetInputMode("no_binds_when_editing")
    addEventHandler("onClientRender",root,renderMasterTuneMenu); addEventHandler("onClientClick",root,handleTuneMenuClick,true); addEventHandler("onClientKey",root,handleTuneMenuKey); addEventHandler("onClientCursorMove",root,handleTuneMenuCursorMove)
end)

function closeMenu(calledFromConfirm)
    if not isMenuVisible and not calledFromConfirm then return end
    if isElement(tuneMenuTargetVehicle) then
        triggerServerEvent("mechanic:clientClosedTuningMenu", localPlayer, tuneMenuTargetVehicle)
    end

    if isElement(tuneMenuTargetVehicle) then
        if originalVehicleColors then setVehicleColor(tuneMenuTargetVehicle,unpack(originalVehicleColors)) end
        if previewWheelIDClient ~= nil and previewWheelIDClient ~= (currentTuneData.tune3 or 0) then
            if previewWheelIDClient and previewWheelIDClient > 0 then removeVehicleUpgrade(tuneMenuTargetVehicle, previewWheelIDClient) end
            if originalWheelIDOnMenuOpen and originalWheelIDOnMenuOpen > 0 then addVehicleUpgrade(tuneMenuTargetVehicle, originalWheelIDOnMenuOpen) end
        end
    end
    setCameraTarget(localPlayer); currentCameraMode = "standard"; setElementFrozen(localPlayer, false)
    isMenuVisible=false; _G.isTuneMenuVisible=false
    originalVehicleColors=nil; tuneMenuTargetVehicle=nil; activeSlider=nil; wheelScrollOffset=0
    originalWheelIDOnMenuOpen = 0; previewWheelIDClient = nil
    pendingMechanicRequest = { active = false, tuneType = nil, levelOrID = nil, message = "" }
    if isInstallProgressActive then -- NEU: Fortschrittsbalken stoppen
        isInstallProgressActive = false
        if installProgressRenderHandler and isEventHandlerAdded("onClientRender", root, installProgressRenderHandler) then
            removeEventHandler("onClientRender", root, installProgressRenderHandler)
            installProgressRenderHandler = nil
        end
    end

    removeEventHandler("onClientRender",root,renderMasterTuneMenu); removeEventHandler("onClientClick",root,handleTuneMenuClick); removeEventHandler("onClientKey",root,handleTuneMenuKey); removeEventHandler("onClientCursorMove",root,handleTuneMenuCursorMove)
    if not isPurchaseConfirmVisible then
        local otherGuiActive=_G.isInventoryVisible or _G.isPedGuiOpen or _G.idPurchaseConfirmVisible or _G.idCardGuiVisible or _G.isHandyGUIVisible or _G.isMessageGUIOpen or _G.isRepairMenuVisible or _G.isMechanicWindowVisible
        if not otherGuiActive then showCursor(false); guiSetInputMode("allow_binds")end
    end
end
addEvent("mechanic:forceCloseTuningMenu", true); addEventHandler("mechanic:forceCloseTuningMenu", root, function() closeMenu(false) end)
addEventHandler("onClientResourceStop", resourceRoot, function() closeMenu(false); closePurchaseConfirmDialog() end)
----------------------------------------------------------------
--[[              KAUFBESTÄTIGUNGS-DIALOG                   ]]--
-- (openPurchaseConfirmDialog, closePurchaseConfirmDialog, renderPurchaseConfirmDialog bleiben unverändert)
----------------------------------------------------------------
function openPurchaseConfirmDialog(tuneType, levelOrID, itemName, itemPrice)
    if isPurchaseConfirmVisible then return end
    isPurchaseConfirmVisible = true
    purchaseConfirmData = { tuneType = tuneType, levelOrID = levelOrID, itemName = itemName, itemPrice = itemPrice }
    confirmDialogClickableElements = {}
    if not isCursorShowing() then showCursor(true) end
    addEventHandler("onClientRender", root, renderPurchaseConfirmDialog)
end

function closePurchaseConfirmDialog()
    if not isPurchaseConfirmVisible then return end
    isPurchaseConfirmVisible = false
    removeEventHandler("onClientRender", root, renderPurchaseConfirmDialog)
    purchaseConfirmData = {}
    confirmDialogClickableElements = {}
    if not isMenuVisible then
        local otherGuiActive = _G.isInventoryVisible or _G.isPedGuiOpen or _G.idPurchaseConfirmVisible or _G.idCardGuiVisible or _G.isHandyGUIVisible or _G.isMessageGUIOpen or _G.isRepairMenuVisible or _G.isMechanicWindowVisible
        if not otherGuiActive then showCursor(false); guiSetInputMode("allow_binds") end
    else
         if not isCursorShowing() then showCursor(true); guiSetInputMode("no_binds_when_editing") end
    end
end

function renderPurchaseConfirmDialog()
    if not isPurchaseConfirmVisible then return end
    local dialogW, dialogH = theme.layout.confirmDialog.width, theme.layout.confirmDialog.height
    local dialogX, dialogY = (screenW - dialogW) / 2, (screenH - dialogH) / 2
    local headerH = theme.layout.confirmDialog.headerHeight
    local padding = theme.layout.padding
    local btnW = theme.layout.confirmDialog.buttonWidth
    local btnSpacing = theme.layout.confirmDialog.buttonSpacing

    dxDrawRectangle(dialogX, dialogY, dialogW, dialogH, tocolor(theme.window.color.r,theme.window.color.g,theme.window.color.b, 250))
    dxDrawLine(dialogX,dialogY,dialogX+dialogW,dialogY,tocolor(theme.colors.BORDER_LIGHT.r,theme.colors.BORDER_LIGHT.g,theme.colors.BORDER_LIGHT.b,theme.colors.BORDER_LIGHT.a),2)
    dxDrawLine(dialogX,dialogY+dialogH,dialogX+dialogW,dialogY+dialogH,tocolor(theme.colors.BORDER_DARK.r,theme.colors.BORDER_DARK.g,theme.colors.BORDER_DARK.b,theme.colors.BORDER_DARK.a),2)
    dxDrawRectangle(dialogX, dialogY, dialogW, headerH, tocolor(theme.header.color.r, theme.header.color.g, theme.header.color.b, 250))
    dxDrawText("Kaufbestätigung", dialogX, dialogY, dialogX + dialogW, dialogY + headerH, tocolor(theme.header.textColor.r,theme.header.textColor.g,theme.header.textColor.b,theme.header.textColor.a), 1.2, theme.font, "center", "center")
    local textY = dialogY + headerH + padding * 1.5
    local confirmText = string.format("Möchtest du %s für $%d kaufen?", purchaseConfirmData.itemName, purchaseConfirmData.itemPrice)
    dxDrawText(confirmText, dialogX + padding, textY, dialogX + dialogW - padding, textY + 50, tocolor(theme.labels.groupColor.r,theme.labels.groupColor.g,theme.labels.groupColor.b,theme.labels.groupColor.a), 1.0, "default", "center", "center", true)
    local totalButtonsWidth = (btnW * 2) + btnSpacing
    local buttonsStartX = dialogX + (dialogW - totalButtonsWidth) / 2
    local buttonsY = dialogY + dialogH - theme.buttons.height - padding
    dxDrawUserPanelStyleButton("confirm_yes", "Kaufen", buttonsStartX, buttonsY, btnW, theme.buttons.height, "success", true, "user/client/images/usericons/confirm.png", confirmDialogClickableElements)
    dxDrawUserPanelStyleButton("confirm_no", "Abbrechen", buttonsStartX + btnW + btnSpacing, buttonsY, btnW, theme.buttons.height, "danger", true, "user/client/images/usericons/cancel.png", confirmDialogClickableElements)
end
----------------------------------------------------------------
--[[                 RENDERING DER UI-ELEMENTE                ]]--
-- (renderMasterTuneMenu, renderTuningTab_UserPanelStyle, renderPaintTab_UserPanelStyle bleiben strukturell gleich, nur Text bei Buttons angepasst)
----------------------------------------------------------------
function renderMasterTuneMenu()
    if not isMenuVisible then return end; clickableElements = {}
    local panelW,panelH=theme.window.width,theme.window.height
    if theme.window.alignX == "left" then currentPanelX = theme.window.offsetX elseif theme.window.alignX == "right" then currentPanelX = screenW - panelW - theme.window.offsetX else currentPanelX = (screenW - panelW) / 2 end
    if theme.window.alignY == "top" then currentPanelY = theme.window.offsetY elseif theme.window.alignY == "bottom" then currentPanelY = screenH - panelH - theme.window.offsetY else currentPanelY = (screenH - panelH) / 2 end
    local panelX, panelY = currentPanelX, currentPanelY
    dxDrawRectangle(panelX,panelY,panelW,panelH,tocolor(theme.window.color.r,theme.window.color.g,theme.window.color.b,theme.window.color.a))
    dxDrawLine(panelX,panelY,panelX+panelW,panelY,tocolor(theme.colors.BORDER_LIGHT.r,theme.colors.BORDER_LIGHT.g,theme.colors.BORDER_LIGHT.b,theme.colors.BORDER_LIGHT.a),2); dxDrawLine(panelX,panelY+panelH,panelX+panelW,panelY+panelH,tocolor(theme.colors.BORDER_DARK.r,theme.colors.BORDER_DARK.g,theme.colors.BORDER_DARK.b,theme.colors.BORDER_DARK.a),2); dxDrawLine(panelX,panelY,panelX,panelY+panelH,tocolor(theme.colors.BORDER_LIGHT.r,theme.colors.BORDER_LIGHT.g,theme.colors.BORDER_LIGHT.b,theme.colors.BORDER_LIGHT.a),2); dxDrawLine(panelX+panelW,panelY,panelX+panelW,panelY+panelH,tocolor(theme.colors.BORDER_DARK.r,theme.colors.BORDER_DARK.g,theme.colors.BORDER_DARK.b,theme.colors.BORDER_DARK.a),2)
    dxDrawRectangle(panelX,panelY,panelW,theme.header.height,tocolor(theme.header.color.r,theme.header.color.g,theme.header.color.b,theme.header.color.a))
    dxDrawText("Fahrzeug Tuning",panelX,panelY,panelX+panelW,panelY+theme.header.height,tocolor(theme.header.textColor.r,theme.header.textColor.g,theme.header.textColor.b,theme.header.textColor.a),theme.header.textSize,theme.font,"center","center",false,false,false,true)
    local tabStartY=panelY+theme.header.height; local tabWidth=panelW/2
    local tabsDefinition={{id="tuning",text="Performance",icon="fraktionen/mechanic/images/tuning.png"},{id="paint",text="Lackierung",icon="fraktionen/mechanic/images/paynspray.png"}}
    local mouseX_abs,mouseY_abs=-1,-1; local cX,cY=getCursorPosition(); if cX then mouseX_abs,mouseY_abs=cX*screenW,cY*screenH end
    for i,tabInfo in ipairs(tabsDefinition)do
        local currentTabX=panelX+(i-1)*tabWidth; local isCurrentTabHovering=mouseX_abs>=currentTabX and mouseX_abs<=currentTabX+tabWidth and mouseY_abs>=tabStartY and mouseY_abs<=tabStartY+theme.tabs.height
        local tabId_hover="tab_"..tabInfo.id; if not hoverStates[tabId_hover]then hoverStates[tabId_hover]={alpha=0,lastTick=getTickCount()}end
        local delta_hover=(getTickCount()-hoverStates[tabId_hover].lastTick)/150; hoverStates[tabId_hover].lastTick=getTickCount(); hoverStates[tabId_hover].alpha=math.max(0,math.min(1,hoverStates[tabId_hover].alpha+(isCurrentTabHovering and delta_hover or -delta_hover)))
        local baseTabColor=(activeTab==tabInfo.id)and theme.tabs.activeColor or theme.tabs.inactiveColor
        local finalTabColorTable=(hoverStates[tabId_hover].alpha>0 and activeTab~=tabInfo.id)and lerpColor(baseTabColor,theme.tabs.hoverColor,hoverStates[tabId_hover].alpha)or baseTabColor
        dxDrawRectangle(currentTabX,tabStartY,tabWidth,theme.tabs.height,tocolor(finalTabColorTable.r,finalTabColorTable.g,finalTabColorTable.b,finalTabColorTable.a))
        local textX_tab,textW_tab,tabIconColor=currentTabX,tabWidth,tocolor(theme.tabs.iconColor.r,theme.tabs.iconColor.g,theme.tabs.iconColor.b,theme.tabs.iconColor.a)
        if tabInfo.icon and fileExists(tabInfo.icon)then
            local iconSize_tab,iconPadding_tab,textWidth_tab_val=theme.tabs.iconSize,theme.tabs.iconPadding,dxGetTextWidth(tabInfo.text,1.0,theme.font)
            textWidth_tab_val = textWidth_tab_val or 50; local totalContentWidth_tab=iconSize_tab+iconPadding_tab+textWidth_tab_val; local startContentX_tab=currentTabX+(tabWidth-totalContentWidth_tab)/2
            local iconY_tab=tabStartY+(theme.tabs.height-iconSize_tab)/2
            dxDrawImage(startContentX_tab,iconY_tab,iconSize_tab,iconSize_tab,tabInfo.icon,0,0,0,tabIconColor)
            textX_tab=startContentX_tab+iconSize_tab+iconPadding_tab
            dxDrawText(tabInfo.text,textX_tab,tabStartY,currentTabX+tabWidth-(startContentX_tab-currentTabX),tabStartY+theme.tabs.height,tocolor(theme.tabs.textColor.r,theme.tabs.textColor.g,theme.tabs.textColor.b,theme.tabs.textColor.a),1.0,theme.font,"left","center")
        else dxDrawText(tabInfo.text,textX_tab,tabStartY,textX_tab+textW_tab,tabStartY+theme.tabs.height,tocolor(theme.tabs.textColor.r,theme.tabs.textColor.g,theme.tabs.textColor.b,theme.tabs.textColor.a),1.0,theme.font,"center","center")end
        if activeTab==tabInfo.id then dxDrawRectangle(currentTabX,tabStartY+theme.tabs.height-3,tabWidth,3,tocolor(theme.tabs.underlineColor.r,theme.tabs.underlineColor.g,theme.tabs.underlineColor.b,theme.tabs.underlineColor.a))end
        if i<#tabsDefinition then dxDrawLine(currentTabX+tabWidth-1,tabStartY+5,currentTabX+tabWidth-1,tabStartY+theme.tabs.height-5,tocolor(theme.tabs.borderColor.r,theme.tabs.borderColor.g,theme.tabs.borderColor.b,theme.tabs.borderColor.a),1)end
        dxDrawUserPanelStyleButton("tab_"..tabInfo.id, "", currentTabX, tabStartY, tabWidth, theme.tabs.height, "primary", true, nil)
    end
    dxDrawLine(panelX,tabStartY+theme.tabs.height,panelX+panelW,tabStartY+theme.tabs.height,tocolor(theme.tabs.borderColor.r,theme.tabs.borderColor.g,theme.tabs.borderColor.b,theme.tabs.borderColor.a),1)

    local purchasePreviewButtonY = panelY + panelH - theme.buttons.height - theme.layout.padding
    local closeButtonWidth = 130
    local purchaseButtonWidth = panelW - (theme.layout.padding * 2) - (theme.layout.buttonSpacing or 10) - closeButtonWidth
    local purchaseButtonX = panelX + theme.layout.padding
    local closeBtnMasterX = purchaseButtonX + purchaseButtonWidth + (theme.layout.buttonSpacing or 10)

    local contentAreaX,contentAreaY=panelX+theme.layout.contentPadding,tabStartY+theme.tabs.height+theme.layout.contentPadding
    local contentAreaH = purchasePreviewButtonY - theme.layout.padding - contentAreaY
    local contentAreaW = panelW - (theme.layout.contentPadding*2)

    if activeTab=="tuning"then renderTuningTab_UserPanelStyle(contentAreaX,contentAreaY,contentAreaW,contentAreaH, purchasePreviewButtonY)
    elseif activeTab=="paint"then renderPaintTab_UserPanelStyle(contentAreaX,contentAreaY,contentAreaW,contentAreaH, purchasePreviewButtonY)end

    if pendingMechanicRequest.active and pendingMechanicRequest.message and pendingMechanicRequest.message ~= "" then
        local noticeBgColor = {r=35, g=38, b=46, a=230}
        local noticeTextColor = {r=255, g=190, b=100, a=255}
        local noticeH = 40
        local noticeY = panelY + panelH - theme.buttons.height - theme.layout.padding - noticeH - 5
        dxDrawRectangle(panelX + theme.layout.padding, noticeY, panelW - (theme.layout.padding * 2), noticeH, tocolor(noticeBgColor.r, noticeBgColor.g, noticeBgColor.b, noticeBgColor.a))
        dxDrawText(pendingMechanicRequest.message, panelX + theme.layout.padding + 10, noticeY, panelX + panelW - theme.layout.padding - 10, noticeY + noticeH, tocolor(noticeTextColor.r, noticeTextColor.g, noticeTextColor.b, noticeTextColor.a), 0.95, theme.font, "center", "center", true)
    else
        if activeTab == "tuning" then
            local canBuyPreview = previewWheelIDClient ~= nil and previewWheelIDClient ~= (currentTuneData.tune3 or 0)
            local previewWheelName = ""
            if previewWheelIDClient then for _, wheel in ipairs(wheelIDs) do if wheel.id == previewWheelIDClient then previewWheelName = wheel.name; break; end end end
            local purchaseText = canBuyPreview and "Kaufe '" .. previewWheelName .. "' ($" .. TUNE_PRICES.wheels .. ")" or "Felge auswählen"
            dxDrawUserPanelStyleButton("purchase_preview_wheel", purchaseText, purchaseButtonX, purchasePreviewButtonY, purchaseButtonWidth, theme.buttons.height, "success", canBuyPreview, nil)
        elseif activeTab == "paint" then
             dxDrawUserPanelStyleButton("apply_color","Lackierung anwenden ($"..TUNE_PRICES.paint..")",purchaseButtonX, purchasePreviewButtonY, purchaseButtonWidth,theme.buttons.height,"success",true,"fraktionen/mechanic/images/paynspray.png")
        end
    end
    dxDrawUserPanelStyleButton("close_main","Schließen",closeBtnMasterX,purchasePreviewButtonY,closeButtonWidth,theme.buttons.height,"danger",true,"user/client/images/usericons/close.png")
end

function renderTuningTab_UserPanelStyle(x,y,w,h, bottomButtonsY)
    local itemButtonHeight = theme.buttons.wheelTextButton.height ; local sectionSpacing=18; local currentY=y
    local groupLabelColor = tocolor(theme.labels.groupColor.r,theme.labels.groupColor.g,theme.labels.groupColor.b,theme.labels.groupColor.a)
    local sectionTextYOffset=18
    dxDrawText("Motor-Upgrade:",x,currentY,x+w,currentY+sectionTextYOffset,groupLabelColor,theme.labels.groupSize,theme.font,"left","center");dxDrawText("Installiert: Lvl "..(currentTuneData.tune1 or 0),x,currentY,x+w-5,currentY+sectionTextYOffset,groupLabelColor,0.9,"default","right","center");currentY=currentY+sectionTextYOffset+5;local motorButtonW=(w-(10*2))/3
    for i=1,3 do
        local isInstalled=(currentTuneData.tune1 or 0)>=i
        local canPurchaseNext=(currentTuneData.tune1 or 0)==i-1
        local buttonText, buttonStyleKey, buttonEnabled
        local isRequested = pendingMechanicRequest.active and pendingMechanicRequest.tuneType == "engine" and pendingMechanicRequest.levelOrID == i

        if isInstalled then buttonText="Lvl "..i.." Installiert"; buttonEnabled=false; buttonStyleKey="item"
        elseif isRequested then buttonText="Angefragt..."; buttonEnabled=false; buttonStyleKey="item"
        elseif canPurchaseNext then
            if i >= 2 then buttonText="Lvl "..i.." Anfragen ($"..TUNE_PRICES.engine[i]..")"; buttonEnabled=true; buttonStyleKey="item"
            else buttonText="Lvl "..i.." Kaufen ($"..TUNE_PRICES.engine[i]..")"; buttonEnabled=true; buttonStyleKey="item" end
        else buttonText="Lvl "..i; buttonEnabled=false; buttonStyleKey="disabled" end
        dxDrawUserPanelStyleButton("engine_"..i,buttonText,x+(i-1)*(motorButtonW+10),currentY,motorButtonW,itemButtonHeight,buttonStyleKey,buttonEnabled,nil)
    end
    currentY=currentY+itemButtonHeight+sectionSpacing;dxDrawText("Nitro-Upgrade:",x,currentY,x+w,currentY+sectionTextYOffset,groupLabelColor,theme.labels.groupSize,theme.font,"left","center");dxDrawText("Installiert: Lvl "..(currentTuneData.tune2 or 0),x,currentY,x+w-5,currentY+sectionTextYOffset,groupLabelColor,0.9,"default","right","center");currentY=currentY+sectionTextYOffset+5;local nitroButtonW=(w-(10*2))/3
    for i=1,3 do
        local isInstalled=(currentTuneData.tune2 or 0)>=i
        local canPurchaseNext=(currentTuneData.tune2 or 0)==i-1
        local buttonText, buttonStyleKey, buttonEnabled
        local isRequested = pendingMechanicRequest.active and pendingMechanicRequest.tuneType == "nitro" and pendingMechanicRequest.levelOrID == i

        if isInstalled then buttonText="Nitro "..i.." Installiert"; buttonEnabled=false; buttonStyleKey="item"
        elseif isRequested then buttonText="Angefragt..."; buttonEnabled=false; buttonStyleKey="item"
        elseif canPurchaseNext then
            if i >= 2 then buttonText="Nitro "..i.." Anfragen ($"..TUNE_PRICES.nitro[i]..")"; buttonEnabled=true; buttonStyleKey="item"
            else buttonText="Nitro "..i.." Kaufen ($"..TUNE_PRICES.nitro[i]..")"; buttonEnabled=true; buttonStyleKey="item" end
        else buttonText="Nitro "..i; buttonEnabled=false; buttonStyleKey="disabled" end
        dxDrawUserPanelStyleButton("nitro_"..i,buttonText,x+(i-1)*(nitroButtonW+10),currentY,nitroButtonW,itemButtonHeight,buttonStyleKey,buttonEnabled,nil)
    end
    currentY = currentY + itemButtonHeight + sectionSpacing
    dxDrawText("Felgen Auswahl:", x, currentY, x + w, currentY + sectionTextYOffset, groupLabelColor, theme.labels.groupSize, theme.font, "left", "center")
    local currentInstalledWheelID = currentTuneData.tune3 or 0; local installedWheelName = "Standard"
    if currentInstalledWheelID ~= 0 then for _, wheel in ipairs(wheelIDs) do if wheel.id == currentInstalledWheelID then installedWheelName = wheel.name; break; end end end
    dxDrawText("Installiert: " .. installedWheelName, x, currentY, x + w - 5, currentY + sectionTextYOffset, groupLabelColor, 0.9, "default", "right", "center")
    currentY = currentY + sectionTextYOffset + 5; local wheelItemW = (w - 10 * 2) / 3; local wheelButtonUseHeight = theme.buttons.wheelTextButton.height
    local wheelContentH = bottomButtonsY - currentY - (theme.layout.padding * 2); maxVisibleWheels = math.max(1, math.floor(wheelContentH / (wheelButtonUseHeight + 5))) * 3
    for i = 1, maxVisibleWheels do local actualIndex = i + wheelScrollOffset
        if wheelIDs[actualIndex] then local wheelData = wheelIDs[actualIndex]; local col = (i - 1) % 3; local row = math.floor((i - 1) / 3)
            local wheelX = x + col * (wheelItemW + 10); local wheelY = currentY + row * (wheelButtonUseHeight + 5)
            if wheelY + wheelButtonUseHeight > bottomButtonsY - (theme.layout.padding * 2) then break end
            local buttonText; local isInstalled = (currentTuneData.tune3 or 0) == wheelData.id; local isPreviewing = previewWheelIDClient == wheelData.id
            if isInstalled then buttonText = wheelData.name .. " (I)" elseif isPreviewing then buttonText = wheelData.name .. " (Vorschau)" else buttonText = wheelData.name end
            dxDrawUserPanelStyleButton("wheels_" .. wheelData.id, buttonText, wheelX, wheelY, wheelItemW, wheelButtonUseHeight, "wheelTextButton", true, nil)
        end
    end
    if #wheelIDs * (wheelButtonUseHeight + 5) / 3 > wheelContentH then
        local scrollAreaH_w=wheelContentH;local totalContentHeight_w=(#wheelIDs/3)*(wheelButtonUseHeight+5);local scrollBarX_w=x+w-theme.layout.scrollBarWidth;local thumbH_w=math.max(20,scrollAreaH_w*(scrollAreaH_w/totalContentHeight_w));local thumbY_w=currentY+(scrollAreaH_w-thumbH_w)*(wheelScrollOffset/math.max(1,#wheelIDs-maxVisibleWheels))
        dxDrawRectangle(scrollBarX_w,currentY,theme.layout.scrollBarWidth,scrollAreaH_w,tocolor(theme.layout.scrollBgColor.r,theme.layout.scrollBgColor.g,theme.layout.scrollBgColor.b,theme.layout.scrollBgColor.a));dxDrawRectangle(scrollBarX_w,thumbY_w,theme.layout.scrollBarWidth,thumbH_w,tocolor(theme.layout.scrollThumbColor.r,theme.layout.scrollThumbColor.g,theme.layout.scrollThumbColor.b,theme.layout.scrollThumbColor.a))
    end
end

function renderPaintTab_UserPanelStyle(x,y,w,h, masterCloseButtonY)
    local labelColorTable=theme.labels.groupColor;local valueColorTable=theme.header.textColor;local sliderLabelScale=0.9;local sliderValueScale=0.95;local sectionSpacing=12;local sliderAreaHeight=theme.layout.sliderHeight;local sliderClickableHeight=sliderAreaHeight+6;local previewBoxSize=theme.layout.colorPreviewHeight-5;local sliderControlWidth=w*0.68;local valueTextWidth=32;local currentY=y
    for i,sliderSet in ipairs(colorSliders)do dxDrawText(sliderSet.text.." (ID: "..sliderSet.mtaID..")",x,currentY,x+w,currentY+16,tocolor(labelColorTable.r,labelColorTable.g,labelColorTable.b,labelColorTable.a),theme.labels.groupSize-0.1,theme.font,"left","center");currentY=currentY+18;local previewX=x+w-previewBoxSize-5;dxDrawRectangle(previewX,currentY,previewBoxSize,previewBoxSize,tocolor(theme.colors.COLOR_PREVIEW_BG.r,theme.colors.COLOR_PREVIEW_BG.g,theme.colors.COLOR_PREVIEW_BG.b,theme.colors.COLOR_PREVIEW_BG.a));dxDrawRectangle(previewX+1,currentY+1,previewBoxSize-2,previewBoxSize-2,tocolor(sliderSet.r,sliderSet.g,sliderSet.b,255));dxDrawLine(previewX,currentY,previewX+previewBoxSize,currentY,tocolor(theme.colors.BORDER_LIGHT.r,theme.colors.BORDER_LIGHT.g,theme.colors.BORDER_LIGHT.b,theme.colors.BORDER_LIGHT.a),1);dxDrawLine(previewX,currentY+previewBoxSize,previewX+previewBoxSize,currentY+previewBoxSize,tocolor(theme.colors.BORDER_DARK.r,theme.colors.BORDER_DARK.g,theme.colors.BORDER_DARK.b,theme.colors.BORDER_DARK.a),1);local channelStartX=x;local channelBlockStartY=currentY
        for channelIndex,channelKey in ipairs({"r","g","b"})do local channelColor=theme.colors["SLIDER_FG_"..string.upper(channelKey)];local channelValue=sliderSet[channelKey];local percentage=channelValue/255;local sliderY_visual=channelBlockStartY+(channelIndex-1)*sliderClickableHeight+(sliderClickableHeight-sliderAreaHeight)/2;dxDrawRectangle(channelStartX,sliderY_visual,sliderControlWidth,sliderAreaHeight,tocolor(theme.colors.SLIDER_BG.r,theme.colors.SLIDER_BG.g,theme.colors.SLIDER_BG.b,theme.colors.SLIDER_BG.a));if percentage>0 then dxDrawRectangle(channelStartX,sliderY_visual,sliderControlWidth*percentage,sliderAreaHeight,tocolor(channelColor.r,channelColor.g,channelColor.b,channelColor.a))end;local handleDrawX=channelStartX+(sliderControlWidth*percentage)-(theme.layout.sliderHandleWidth/2);local handleDrawY=sliderY_visual+(sliderAreaHeight-(sliderAreaHeight+theme.layout.sliderHandleHeightExtra))/2;dxDrawRectangle(handleDrawX,handleDrawY,theme.layout.sliderHandleWidth,sliderAreaHeight+theme.layout.sliderHandleHeightExtra,tocolor(theme.colors.SLIDER_HANDLE.r,theme.colors.SLIDER_HANDLE.g,theme.colors.SLIDER_HANDLE.b,theme.colors.SLIDER_HANDLE.a));dxDrawText(channelValue,channelStartX+sliderControlWidth+5,sliderY_visual-(sliderClickableHeight-sliderAreaHeight)/2,channelStartX+sliderControlWidth+5+valueTextWidth,sliderY_visual+sliderAreaHeight+(sliderClickableHeight-sliderAreaHeight)/2,tocolor(valueColorTable.r,valueColorTable.g,valueColorTable.b,valueColorTable.a),sliderValueScale,theme.font,"left","center");table.insert(clickableElements,{id="slider_"..channelKey.."_"..i,x=channelStartX,y=channelBlockStartY+(channelIndex-1)*sliderClickableHeight,w=sliderControlWidth,h=sliderClickableHeight})end
        currentY=channelBlockStartY+math.max((3*sliderClickableHeight),previewBoxSize)+sectionSpacing; if i==2 then currentY=currentY-5 end
    end
end
----------------------------------------------------------------
--[[                      INPUT HANDLER                       ]]--
-- (handleTuneMenuClick, handleTuneMenuKey, handleTuneMenuCursorMove bleiben strukturell gleich, Logik für Motor/Nitro Lvl 2/3 angepasst)
----------------------------------------------------------------
function handleTuneMenuClick(button,state,absX,absY)
    if not isMenuVisible or button~="left" then return end
    local targetClickableElements = clickableElements
    if isPurchaseConfirmVisible then targetClickableElements = confirmDialogClickableElements end

    if state=="down"then
        if activeTab=="paint" and not isPurchaseConfirmVisible then
            for _,el in ipairs(targetClickableElements)do if absX>=el.x and absX<=el.x+el.w and absY>=el.y and absY<=el.y+el.h then local parts=splitString(el.id,"_"); if parts[1]=="slider"and #parts==3 then activeSlider={sliderIndex=tonumber(parts[3]),channel=parts[2],sliderX=el.x,sliderWidth=el.w}; updateSliderFromClick_Cartune(absX); playSoundFrontEnd(42); return end end end
        end
    elseif state=="up"then
        if activeSlider then activeSlider=nil;return end
        if isPurchaseConfirmVisible then
            local dialogW_click,dialogH_click=theme.layout.confirmDialog.width,theme.layout.confirmDialog.height;local dialogX_click,dialogY_click=(screenW-dialogW_click)/2,(screenH-dialogH_click)/2;local padding_click=theme.layout.padding;local btnW_click=theme.layout.confirmDialog.buttonWidth;local btnSpacing_click=theme.layout.confirmDialog.buttonSpacing;local totalButtonsWidth_click=(btnW_click*2)+btnSpacing_click;local buttonsStartX_click=dialogX_click+(dialogW_click-totalButtonsWidth_click)/2;local buttonsY_click=dialogY_click+dialogH_click-theme.buttons.height-padding_click
            local confirmYesButtonArea={x=buttonsStartX_click,y=buttonsY_click,w=btnW_click,h=theme.buttons.height};local confirmNoButtonArea={x=buttonsStartX_click+btnW_click+btnSpacing_click,y=buttonsY_click,w=btnW_click,h=theme.buttons.height}
            if absX>=confirmYesButtonArea.x and absX<=confirmYesButtonArea.x+confirmYesButtonArea.w and absY>=confirmYesButtonArea.y and absY<=confirmYesButtonArea.y+confirmYesButtonArea.h then
                playSoundFrontEnd(40);triggerServerEvent("cartune:purchaseUpgrade",localPlayer,tuneMenuTargetVehicle,purchaseConfirmData.tuneType,purchaseConfirmData.levelOrID)
                if purchaseConfirmData.tuneType=="wheels"then originalWheelIDOnMenuOpen=purchaseConfirmData.levelOrID;currentTuneData.tune3=purchaseConfirmData.levelOrID;previewWheelIDClient=nil;setStandardTuneCamera(tuneMenuTargetVehicle)end
                closePurchaseConfirmDialog();cancelEvent();return
            elseif absX>=confirmNoButtonArea.x and absX<=confirmNoButtonArea.x+confirmNoButtonArea.w and absY>=confirmNoButtonArea.y and absY<=confirmNoButtonArea.y+confirmNoButtonArea.h then
                playSoundFrontEnd(40);if purchaseConfirmData.tuneType=="wheels"and isElement(tuneMenuTargetVehicle)then if previewWheelIDClient and previewWheelIDClient>0 then removeVehicleUpgrade(tuneMenuTargetVehicle,previewWheelIDClient)end;if originalWheelIDOnMenuOpen and originalWheelIDOnMenuOpen>0 then addVehicleUpgrade(tuneMenuTargetVehicle,originalWheelIDOnMenuOpen)end;previewWheelIDClient=nil end
                setStandardTuneCamera(tuneMenuTargetVehicle);closePurchaseConfirmDialog();cancelEvent();return
            else cancelEvent();return
            end
        else
            for _,elData in ipairs(targetClickableElements)do
                if elData.isHovering and elData.enabled then playSoundFrontEnd(40); local parts=splitString(elData.id,"_")
                    if parts[1]=="tab"then if activeTab~=parts[2]then if activeTab=="tuning"and previewWheelIDClient and previewWheelIDClient~=(currentTuneData.tune3 or 0)then if isElement(tuneMenuTargetVehicle)then if previewWheelIDClient and previewWheelIDClient>0 then removeVehicleUpgrade(tuneMenuTargetVehicle,previewWheelIDClient)end;if originalWheelIDOnMenuOpen and originalWheelIDOnMenuOpen>0 then addVehicleUpgrade(tuneMenuTargetVehicle,originalWheelIDOnMenuOpen)end end;previewWheelIDClient=nil end;activeTab=parts[2];setStandardTuneCamera(tuneMenuTargetVehicle)end
                    elseif elData.id=="close_main"then closeMenu(false)
                    elseif elData.id=="apply_color"then local s1,s2,s3,s4=colorSliders[1],colorSliders[2],colorSliders[3],colorSliders[4];triggerServerEvent("cartune:purchaseColor",localPlayer,tuneMenuTargetVehicle,s1.mtaID,s2.mtaID,s3.mtaID,s4.mtaID,s1.r,s1.g,s1.b,s2.r,s2.g,s2.b,s3.r,s3.g,s3.b,s4.r,s4.g,s4.b);originalVehicleColors={s1.r,s1.g,s1.b,s2.r,s2.g,s2.b,s3.r,s3.g,s3.b,s4.r,s4.g,s4.b}
                    elseif parts[1]=="wheels"then local clickedWheelID=tonumber(parts[2])
                        if isElement(tuneMenuTargetVehicle)then if clickedWheelID==(currentTuneData.tune3 or 0)then if previewWheelIDClient and previewWheelIDClient>0 then removeVehicleUpgrade(tuneMenuTargetVehicle,previewWheelIDClient)end;if originalWheelIDOnMenuOpen~=clickedWheelID and originalWheelIDOnMenuOpen and originalWheelIDOnMenuOpen>0 then addVehicleUpgrade(tuneMenuTargetVehicle,originalWheelIDOnMenuOpen)elseif originalWheelIDOnMenuOpen==0 and clickedWheelID~=0 then end;previewWheelIDClient=nil;setStandardTuneCamera(tuneMenuTargetVehicle)
                        elseif previewWheelIDClient==clickedWheelID then if previewWheelIDClient and previewWheelIDClient>0 then removeVehicleUpgrade(tuneMenuTargetVehicle,previewWheelIDClient)end;if originalWheelIDOnMenuOpen and originalWheelIDOnMenuOpen>0 then addVehicleUpgrade(tuneMenuTargetVehicle,originalWheelIDOnMenuOpen)end;previewWheelIDClient=nil;setStandardTuneCamera(tuneMenuTargetVehicle)
                        else local wheelToRemove=previewWheelIDClient;if not wheelToRemove or wheelToRemove==0 then wheelToRemove=currentTuneData.tune3 or 0 end;if wheelToRemove and wheelToRemove>0 then removeVehicleUpgrade(tuneMenuTargetVehicle,wheelToRemove)end;addVehicleUpgrade(tuneMenuTargetVehicle,clickedWheelID);previewWheelIDClient=clickedWheelID;setWheelFocusCamera(tuneMenuTargetVehicle)end
                        end
                    elseif elData.id=="purchase_preview_wheel"then if previewWheelIDClient and previewWheelIDClient~=(currentTuneData.tune3 or 0)then local wheelName="";for _,wData in ipairs(wheelIDs)do if wData.id==previewWheelIDClient then wheelName=wData.name;break;end end;openPurchaseConfirmDialog("wheels",previewWheelIDClient,"Felgen: "..wheelName,TUNE_PRICES.wheels)end
                    elseif parts[1]=="engine"or parts[1]=="nitro"then local tuneType_click,levelOrID_click=parts[1],tonumber(parts[2])
                        if tuneType_click and levelOrID_click then local itemName,itemPrice="",0
                            if tuneType_click=="engine"then itemName="Motor Lvl "..levelOrID_click;itemPrice=TUNE_PRICES.engine[levelOrID_click]elseif tuneType_click=="nitro"then itemName="Nitro Lvl "..levelOrID_click;itemPrice=TUNE_PRICES.nitro[levelOrID_click]end
                            if itemName~=""and itemPrice>0 then
                                if (tuneType_click=="engine"or tuneType_click=="nitro")and(levelOrID_click==2 or levelOrID_click==3)then
                                    if not pendingMechanicRequest.active or(pendingMechanicRequest.tuneType~=tuneType_click or pendingMechanicRequest.levelOrID~=levelOrID_click)then triggerServerEvent("mechanic:requestHighLevelTune",localPlayer,tuneMenuTargetVehicle,tuneType_click,levelOrID_click,itemName,itemPrice);pendingMechanicRequest={active=true,tuneType=tuneType_click,levelOrID=levelOrID_click,message="Warte auf Mechaniker..."}end
                                else openPurchaseConfirmDialog(tuneType_click,levelOrID_click,itemName,itemPrice)end
                            end
                        end
                    end;return
                end
            end
        end
    end
end

function updateSliderFromClick_Cartune(absX)if not activeSlider then return end;local percentage=(absX-activeSlider.sliderX)/activeSlider.sliderWidth;local value=math.floor(math.max(0,math.min(1,percentage))*255);colorSliders[activeSlider.sliderIndex][activeSlider.channel]=value;if isElement(tuneMenuTargetVehicle)then setVehicleColor(tuneMenuTargetVehicle,colorSliders[1].r,colorSliders[1].g,colorSliders[1].b,colorSliders[2].r,colorSliders[2].g,colorSliders[2].b,colorSliders[3].r,colorSliders[3].g,colorSliders[3].b,colorSliders[4].r,colorSliders[4].g,colorSliders[4].b)end end
function handleTuneMenuCursorMove(cursorX_move,cursorY_move,absX_move,absY_move)if not isMenuVisible or not activeSlider then return end;updateSliderFromClick_Cartune(absX_move)end
function handleTuneMenuKey(key,press)
    if not press then return end
    if key=="escape"then if isPurchaseConfirmVisible then if purchaseConfirmData.tuneType=="wheels"and isElement(tuneMenuTargetVehicle)then if previewWheelIDClient and previewWheelIDClient>0 then removeVehicleUpgrade(tuneMenuTargetVehicle,previewWheelIDClient)end;if originalWheelIDOnMenuOpen and originalWheelIDOnMenuOpen>0 then addVehicleUpgrade(tuneMenuTargetVehicle,originalWheelIDOnMenuOpen)end;previewWheelIDClient=nil end;setStandardTuneCamera(tuneMenuTargetVehicle);closePurchaseConfirmDialog();cancelEvent();return elseif isMenuVisible then closeMenu(false);cancelEvent();return end end
    if not isMenuVisible or isPurchaseConfirmVisible then return end
    if key=="mouse_wheel_down"and activeTab=="tuning"then local maxScroll=math.max(0,#wheelIDs-maxVisibleWheels);if maxScroll>0 then wheelScrollOffset=math.min(maxScroll,wheelScrollOffset+3);playSoundFrontEnd(42)end
    elseif key=="mouse_wheel_up"and activeTab=="tuning"then wheelScrollOffset=math.max(0,wheelScrollOffset-3);playSoundFrontEnd(42)end
end

addEvent("cartune:updateLocalTuneData",true)
addEventHandler("cartune:updateLocalTuneData",root,function(newData)
    if type(newData)=="table"then local oldTune3=currentTuneData.tune3;currentTuneData=newData;pendingMechanicRequest={active=false,tuneType=nil,levelOrID=nil,message=""}
        if oldTune3~=(currentTuneData.tune3 or 0)then originalWheelIDOnMenuOpen=currentTuneData.tune3 or 0;previewWheelIDClient=nil;if isMenuVisible and isElement(tuneMenuTargetVehicle)then setStandardTuneCamera(tuneMenuTargetVehicle)end end
    end
end)

function splitString(inputstr,sep)if sep==nil then sep="%s"end;local t={};local i=1;for str in string.gmatch(inputstr,"([^"..sep.."]+)")do t[i]=str;i=i+1 end;return t end
if not _G.isTuneMenuVisible then _G.isTuneMenuVisible=false end

addEvent("mechanic:tuneRequestStatus", true)
addEventHandler("mechanic:tuneRequestStatus", root, function(message, success, tuneType, levelOrID)
    outputChatBox(message, 255, 255, 0)
    if success == false or success == nil then pendingMechanicRequest = { active = false, tuneType = nil, levelOrID = nil, message = "" }
    elseif success == true and tuneType and levelOrID then pendingMechanicRequest = {active = true, tuneType = tuneType, levelOrID = levelOrID, message = message}end
end)

-- NEU: Funktion und Event-Handler für Fortschrittsbalken
function startTuneInstallProgress(duration, text)
    isInstallProgressActive = true
    installProgressDuration = duration
    installProgressEndTime = getTickCount() + duration
    installProgressText = text or "Installation läuft..."
    if not installProgressRenderHandler then
        installProgressRenderHandler = renderInstallProgressBar
        addEventHandler("onClientRender", root, installProgressRenderHandler)
    end
end

function renderInstallProgressBar()
    if not isInstallProgressActive then
        if installProgressRenderHandler and isEventHandlerAdded("onClientRender", root, installProgressRenderHandler) then
            removeEventHandler("onClientRender", root, installProgressRenderHandler)
            installProgressRenderHandler = nil
        end
        return
    end
    local remainingTime = math.max(0, installProgressEndTime - getTickCount())
    if remainingTime == 0 then
        isInstallProgressActive = false
        if installProgressRenderHandler and isEventHandlerAdded("onClientRender", root, installProgressRenderHandler) then
            removeEventHandler("onClientRender", root, installProgressRenderHandler)
            installProgressRenderHandler = nil
        end
        return
    end
    local progress = 1 - (remainingTime / installProgressDuration)
    local barW, barH = theme.layout.progressBarW, theme.layout.progressBarH
    local barX = (screenW - barW) / 2
    local barY = screenH * 0.82 -- Etwas höher als die Bankrob-Bar

    dxDrawRectangle(barX - 2, barY - 2, barW + 4, barH + 4, tocolor(theme.colors.PROGRESS_BAR_BORDER.r,theme.colors.PROGRESS_BAR_BORDER.g,theme.colors.PROGRESS_BAR_BORDER.b,theme.colors.PROGRESS_BAR_BORDER.a))
    dxDrawRectangle(barX, barY, barW, barH, tocolor(theme.colors.PROGRESS_BAR_BG.r,theme.colors.PROGRESS_BAR_BG.g,theme.colors.PROGRESS_BAR_BG.b,theme.colors.PROGRESS_BAR_BG.a))
    dxDrawRectangle(barX, barY, barW * progress, barH, tocolor(theme.colors.PROGRESS_BAR_FG.r,theme.colors.PROGRESS_BAR_FG.g,theme.colors.PROGRESS_BAR_FG.b,theme.colors.PROGRESS_BAR_FG.a))
    dxDrawText(string.format("%s %.1fs", installProgressText, remainingTime/1000), barX, barY, barX+barW, barY+barH, tocolor(theme.colors.PROGRESS_TEXT.r,theme.colors.PROGRESS_TEXT.g,theme.colors.PROGRESS_TEXT.b,theme.colors.PROGRESS_TEXT.a), 1.0, "default-bold", "center", "center")
end

addEvent("mechanic:beginInstallNotification", true)
addEventHandler("mechanic:beginInstallNotification", root, function(duration)
    startTuneInstallProgress(duration, "Tuning wird installiert...")
end)

addEvent("mechanic:installationStarted", true)
addEventHandler("mechanic:installationStarted", root, function(mechanicName, upgradeName)
    local msg = "Mechaniker ".. (mechanicName or "Ein Mechaniker").. " beginnt mit der Installation von ".. (upgradeName or "Upgrade") .."."
    outputChatBox(msg, 0, 200, 50)
    if pendingMechanicRequest.active then pendingMechanicRequest.message = "Installation läuft..." end
    -- Der Fortschrittsbalken wird durch 'mechanic:beginInstallNotification' gestartet
end)

addEvent("mechanic:installationFinished", true)
addEventHandler("mechanic:installationFinished", root, function(upgradeName, success)
    local msg; if success then msg = "Installation von " .. (upgradeName or "Upgrade") .. " erfolgreich abgeschlossen!"; outputChatBox(msg, 0, 255, 0)
    else msg = "Installation von " .. (upgradeName or "Upgrade") .. " fehlgeschlagen."; outputChatBox(msg, 255, 0, 0) end
    pendingMechanicRequest = { active = false, tuneType = nil, levelOrID = nil, message = "" }
    isInstallProgressActive = false -- Stoppt den Fortschrittsbalken
    if installProgressRenderHandler and isEventHandlerAdded("onClientRender", root, installProgressRenderHandler) then
        removeEventHandler("onClientRender", root, installProgressRenderHandler)
        installProgressRenderHandler = nil
    end
    if isMenuVisible and isElement(tuneMenuTargetVehicle) then triggerServerEvent("cartune:requestUpdatedTuneData", localPlayer, tuneMenuTargetVehicle) end
end)

--outputDebugString("[MechanicC] CarTune Client V9.1 (Fortschrittsbalken) geladen.")