-- tarox/user/client/userpanel_client.lua
-- Version OHNE Skill-Anzeige
-- SKILL SYSTEM ENTFERNT
-- Buttons nach unten verschoben

local screenW, screenH = guiGetScreenSize()
local localPlayer = getLocalPlayer()
local panelVisible = false

local playerName = "N/A"; local money = "$0"; local playtime = "00:00"; local faction = "Civil"; local wantedsDisplay = "0"
local vehicles = {}

local selectedVehicleIndex = nil; local scrollOffset = 0; local maxVisibleVehicles = 6 -- Angepasst, da Skill-Bereich wegfällt
local vehicleRowHeight = 40; local vehicleSpacing = 5
local vehicleClickAreas = {};
local lastClickTime = 0; local COOLDOWN_MS = 300

local userPanelRenderHandler = nil; local userPanelClickHandler = nil

local layout = {
    panelW = 720, panelH = 450, -- ANGEPASST: Höhe von 400 auf 450 erhöht, um Buttons nach unten zu verschieben
    headerH = 50, padding = 15, infoSectionH = 96,
    infoTextXOffset = 10, listHeaderH = 25, scrollBarWidth = 12, buttonAreaH = 60,
    buttonSpacing = 10, buttonH = 40, iconSize = 20, iconPadding = 8,
}
layout.panelX = (screenW - layout.panelW) / 2; layout.panelY = (screenH - layout.panelH) / 2
layout.infoAreaX = layout.panelX + layout.padding; layout.infoAreaY = layout.panelY + layout.headerH + layout.padding
layout.infoAreaW = layout.panelW - (layout.padding * 2)
layout.listAreaX = layout.panelX + layout.padding; layout.listAreaY = layout.infoAreaY + layout.infoSectionH + layout.padding
layout.listAreaW = layout.panelW - (layout.padding * 2)
-- ListAreaH angepasst, da Skill-Bereich wegfällt (wird jetzt basierend auf panelH=450 berechnet)
layout.listAreaH = layout.panelH - layout.headerH - (layout.padding * 3) - layout.infoSectionH - layout.buttonAreaH
layout.listContentX = layout.listAreaX; layout.listContentY = layout.listAreaY + layout.listHeaderH
layout.listContentW = layout.listAreaW - layout.scrollBarWidth - 5; layout.listContentH = layout.listAreaH - layout.listHeaderH
layout.buttonAreaItemWidth = (layout.listAreaW - layout.buttonSpacing) / 2
layout.buttonAreaY = layout.listAreaY + layout.listAreaH + layout.padding -- Diese Zeile positioniert die Buttons unterhalb der (jetzt potenziell größeren) listArea

local colors = {
    BG_MAIN = tocolor(28,30,36,240), BG_HEADER = tocolor(35,38,46,245), BG_SECTION_BORDER = tocolor(45,48,56,200),
    BG_LIST = tocolor(32,35,42,230), BG_LIST_ITEM = tocolor(40,43,51,210), BG_LIST_ITEM_ALT = tocolor(44,47,55,210),
    BG_LIST_SELECTED = tocolor(0,122,204,200), BG_LIST_HOVER = tocolor(55,58,68,180), TEXT_HEADER = tocolor(235,235,240),
    TEXT_LABEL = tocolor(170,175,185), TEXT_VALUE = tocolor(210,215,225), TEXT_MONEY = tocolor(90,210,140),
    TEXT_PLAYTIME = tocolor(230,190,90), TEXT_FACTION = tocolor(140,170,245), TEXT_WANTEDS = tocolor(255,100,100),
    HEALTH_GOOD = tocolor(70,210,70), HEALTH_MED = tocolor(210,210,70),
    HEALTH_BAD = tocolor(210,70,70), HEALTH_DESTROYED = tocolor(110,110,120), FUEL = tocolor(190,140,245),
    SCROLLBAR_BG = tocolor(40,43,51,180), SCROLLBAR_THUMB = tocolor(70,75,85,220),
    BUTTON_DESPAWN_BG = tocolor(200,70,70,220), BUTTON_DESPAWN_HOVER = tocolor(220,90,90,230),
    BUTTON_CLOSE_BG = tocolor(80,85,95,220), BUTTON_CLOSE_HOVER = tocolor(100,105,115,230),
    BUTTON_DISABLED_BG = tocolor(70,70,70,150), BUTTON_TEXT = tocolor(245,245,245),
    BORDER_LIGHT = tocolor(55,58,68,180), BORDER_DARK = tocolor(20,22,28,220),
}
local fonts = { HEADER = "default-bold", LABEL = "default", VALUE = "default-bold", LIST_HEADER = "default-bold", LIST_ITEM = "default", BUTTON = "default-bold" }

local icons = {
    MONEY = "user/client/images/usericons/money.png", PLAYTIME = "user/client/images/usericons/playtime.png",
    FACTION = "user/client/images/usericons/faction.png", WANTEDS = "user/client/images/usericons/wanted.png",
    VEHICLE = "user/client/images/usericons/vehicle.png", HP = "user/client/images/usericons/health.png",
    FUEL = "user/client/images/usericons/fuel.png", DESPAWN = "user/client/images/usericons/despawn.png",
    CLOSE = "user/client/images/usericons/close.png"
}

function formatMoneyForPanel(amount)
    local amountStr = tostring(math.floor(amount or 0))
    local formatted = amountStr; local k = string.len(amountStr) % 3
    if k == 0 then k = 3 end
    while k < string.len(formatted) do
        formatted = string.sub(formatted, 1, k) .. "." .. string.sub(formatted, k + 1)
        k = k + 4
    end
    return "$" .. formatted
end

function dxDrawTextWithIcon(iconPath, text, x, y, w, h, textColor, textScale, textFontName, alignX, alignY, clip, wordBreak, postGUI, colorCoded, subPixelPositioning, fRotation, fRotationCenterX, fRotationCenterY)
    local iconDrawSize = layout.iconSize; local actualIconX = x; local actualTextX = x + iconDrawSize + layout.iconPadding
    local actualIconY = y + (h - iconDrawSize) / 2; local textDrawWidth = w - (iconDrawSize + layout.iconPadding)
    if not iconPath or not fileExists(iconPath) then actualTextX = x; textDrawWidth = w
    else dxDrawImage(actualIconX, actualIconY, iconDrawSize, iconDrawSize, iconPath, fRotation or 0, fRotationCenterX or 0, fRotationCenterY or 0, tocolor(255,255,255,220), postGUI) end
    dxDrawText(text, actualTextX, y, actualTextX + textDrawWidth, y + h, textColor, textScale, textFontName, alignX or "left", alignY or "center", clip or false, wordBreak or false, postGUI or false, colorCoded or false, subPixelPositioning or false)
end

function dxDrawStyledButton_VisualOnly(text, x, y, w, h, bgColor, hoverColor, textColor, fontName, scale, iconPath)
    local cX, cY = getCursorPosition(); local hover = false
    if cX then local mouseX,mouseY=cX*screenW,cY*screenH; hover=mouseX>=x and mouseX<=x+w and mouseY>=y and mouseY<=y+h end
    local currentBgColor = hover and hoverColor or bgColor
    dxDrawRectangle(x,y,w,h,currentBgColor)
    dxDrawLine(x,y,x+w,y,colors.BORDER_LIGHT,1); dxDrawLine(x,y+h,x+w,y+h,colors.BORDER_DARK,1)
    dxDrawLine(x,y,x,y+h,colors.BORDER_LIGHT,1); dxDrawLine(x+w,y,x+w,y+h,colors.BORDER_DARK,1)
    local actualText = text; local textDrawX = x; local textDrawW = w
    if iconPath and fileExists(iconPath) then
        local iconDrawSize = layout.iconSize
        local iconDrawY = y + (h - iconDrawSize) / 2
        if text == "" then
            local startContentX = x + (w - iconDrawSize) / 2
            dxDrawImage(startContentX, iconDrawY, iconDrawSize, iconDrawSize, iconPath, 0,0,0,tocolor(255,255,255,230))
        else
            local textWidth = dxGetTextWidth(text, scale, fontName)
            local totalContentWidth = iconDrawSize + layout.iconPadding * 0.5 + textWidth
            local startContentX = x + (w - totalContentWidth) / 2
            dxDrawImage(startContentX, iconDrawY, iconDrawSize, iconDrawSize, iconPath, 0,0,0,tocolor(255,255,255,230))
            textDrawX = startContentX + iconDrawSize + layout.iconPadding * 0.5
            local remainingWidthForText = (x + w) - textDrawX
            dxDrawText(actualText, textDrawX, y, textDrawX + remainingWidthForText , y + h, textColor, scale, fontName, "left", "center", false,false,false,true)
        end
    else
        dxDrawText(actualText, textDrawX, y, textDrawX + textDrawW, y + h, textColor, scale, fontName, "center", "center", false,false,false,true)
    end
end

userPanelRenderHandler = function()
    if not panelVisible then return end
    dxDrawRectangle(layout.panelX,layout.panelY,layout.panelW,layout.panelH,colors.BG_MAIN)
    dxDrawLine(layout.panelX,layout.panelY,layout.panelX+layout.panelW,layout.panelY,colors.BORDER_LIGHT,2); dxDrawLine(layout.panelX,layout.panelY+layout.panelH,layout.panelX+layout.panelW,layout.panelY+layout.panelH,colors.BORDER_DARK,2)
    dxDrawLine(layout.panelX,layout.panelY,layout.panelX,layout.panelY+layout.panelH,colors.BORDER_LIGHT,2); dxDrawLine(layout.panelX+layout.panelW,layout.panelY,layout.panelX+layout.panelW,layout.panelY+layout.panelH,colors.BORDER_DARK,2)
    dxDrawRectangle(layout.panelX,layout.panelY,layout.panelW,layout.headerH,colors.BG_HEADER)
    dxDrawText("User Panel - "..playerName,layout.panelX,layout.panelY,layout.panelX+layout.panelW,layout.panelY+layout.headerH,colors.TEXT_HEADER,1.4,fonts.HEADER,"center","center")

    local infoRowH = layout.infoSectionH / 2 
    local currentInfoY = layout.infoAreaY
    local infoColW = layout.infoAreaW / 2 - layout.padding / 2 
    local leftColX = layout.infoAreaX + layout.infoTextXOffset
    local rightColX = leftColX + infoColW + layout.padding

    dxDrawTextWithIcon(icons.MONEY,money,leftColX,currentInfoY,infoColW,infoRowH,colors.TEXT_MONEY,1.0,fonts.VALUE,"left","center",false,false,false)
    dxDrawTextWithIcon(icons.PLAYTIME,playtime,rightColX,currentInfoY,infoColW,infoRowH,colors.TEXT_PLAYTIME,1.0,fonts.VALUE,"left","center",false,false,false)
    currentInfoY = currentInfoY + infoRowH

    dxDrawTextWithIcon(icons.FACTION,faction,leftColX,currentInfoY,infoColW,infoRowH,colors.TEXT_FACTION,1.0,fonts.VALUE,"left","center",false,false,false)
    dxDrawTextWithIcon(icons.WANTEDS,wantedsDisplay.." Wanteds",rightColX,currentInfoY,infoColW,infoRowH,colors.TEXT_WANTEDS,1.0,fonts.VALUE,"left","center",false,false,false)

    dxDrawLine(layout.infoAreaX, layout.infoAreaY + layout.infoSectionH, layout.infoAreaX + layout.infoAreaW, layout.infoAreaY + layout.infoSectionH, colors.BG_SECTION_BORDER, 1)
    
    dxDrawText("Meine Fahrzeuge ("..(#vehicles or 0)..")",layout.listAreaX,layout.listAreaY,layout.listAreaX + layout.listAreaW, layout.listAreaY + layout.listHeaderH,colors.TEXT_HEADER,1.1,fonts.LIST_HEADER,"left","center")
    dxDrawLine(layout.listAreaX,layout.listAreaY + layout.listHeaderH -2, layout.listAreaX + layout.listAreaW, layout.listAreaY + layout.listHeaderH -2,colors.BG_SECTION_BORDER,1)
    dxDrawRectangle(layout.listContentX,layout.listContentY,layout.listContentW,layout.listContentH,colors.BG_LIST)
    local tempVehicleClickAreas={}; if #vehicles==0 then dxDrawText("Du besitzt keine Fahrzeuge.",layout.listContentX,layout.listContentY,layout.listContentX+layout.listContentW,layout.listContentY+layout.listContentH,colors.TEXT_LABEL,1.1,fonts.LIST_ITEM,"center","center")
    else for i=1,maxVisibleVehicles do local index=i+scrollOffset; if vehicles[index]then local veh=vehicles[index]; local rowY=layout.listContentY+(i-1)*(vehicleRowHeight+vehicleSpacing); local bgColor=(index%2==0)and colors.BG_LIST_ITEM_ALT or colors.BG_LIST_ITEM; if selectedVehicleIndex==index then bgColor=colors.BG_LIST_SELECTED end
    local cX_cur,cY_cur=getCursorPosition();local rowDrawX_cur=layout.listContentX+layout.padding/2;local rowDrawW_cur=layout.listContentW-layout.padding;if cX_cur then local mX_cur,mY_cur=cX_cur*screenW,cY_cur*screenH;if mX_cur>=rowDrawX_cur and mX_cur<=rowDrawX_cur+rowDrawW_cur and mY_cur>=rowY and mY_cur<=rowY+vehicleRowHeight then if selectedVehicleIndex~=index then bgColor=colors.BG_LIST_HOVER end end end
    dxDrawRectangle(rowDrawX_cur,rowY,rowDrawW_cur,vehicleRowHeight,bgColor);dxDrawLine(rowDrawX_cur,rowY+vehicleRowHeight,rowDrawX_cur+rowDrawW_cur,rowY+vehicleRowHeight,colors.BORDER_LIGHT,1)
    local iconColW_cur=layout.iconSize+layout.iconPadding;local nameColW_cur=rowDrawW_cur*0.45-iconColW_cur;local hpColW_cur=rowDrawW_cur*0.25-iconColW_cur;local fuelColW_cur=rowDrawW_cur*0.30-iconColW_cur;local currentElementX_cur=rowDrawX_cur+layout.padding/2
    dxDrawTextWithIcon(icons.VEHICLE,veh.name,currentElementX_cur,rowY,nameColW_cur+iconColW_cur,vehicleRowHeight,colors.TEXT_VALUE,1.0,fonts.LIST_ITEM,"left","center",true)
    currentElementX_cur=currentElementX_cur+nameColW_cur+iconColW_cur+layout.padding/2;local healthColor_cur=colors.HEALTH_DESTROYED;local healthText_cur="ERR";if veh.health then healthText_cur="Destroyed";if veh.health>0 then healthText_cur=math.floor(veh.health/10).."%";if veh.health>700 then healthColor_cur=colors.HEALTH_GOOD elseif veh.health>300 then healthColor_cur=colors.HEALTH_MED else healthColor_cur=colors.HEALTH_BAD end end end
    dxDrawTextWithIcon(icons.HP,healthText_cur,currentElementX_cur,rowY,hpColW_cur+iconColW_cur,vehicleRowHeight,healthColor_cur,1.0,fonts.LIST_ITEM,"left","center",false)
    currentElementX_cur=currentElementX_cur+hpColW_cur+iconColW_cur+layout.padding/2;local fuelText_cur=(veh.fuel and veh.fuel .. "%") or "N/A"
    dxDrawTextWithIcon(icons.FUEL,fuelText_cur,currentElementX_cur,rowY,fuelColW_cur+iconColW_cur,vehicleRowHeight,colors.FUEL,1.0,fonts.LIST_ITEM,"left","center",false)
    tempVehicleClickAreas[index]={x=rowDrawX_cur,y=rowY,w=rowDrawW_cur,h=vehicleRowHeight}end end end; vehicleClickAreas=tempVehicleClickAreas
    if #vehicles>maxVisibleVehicles then local scrollBarX=layout.listContentX+layout.listContentW+5;local scrollBarH=layout.listContentH;dxDrawRectangle(scrollBarX,layout.listContentY,layout.scrollBarWidth,scrollBarH,colors.SCROLLBAR_BG);local thumbH=math.max(20,scrollBarH*(maxVisibleVehicles/#vehicles));local thumbY=layout.listContentY+(scrollBarH-thumbH)*(scrollOffset/math.max(1,#vehicles-maxVisibleVehicles));dxDrawRectangle(scrollBarX,thumbY,layout.scrollBarWidth,thumbH,colors.SCROLLBAR_THUMB)end
    local despawnX=layout.listAreaX;local closeX=despawnX+layout.buttonAreaItemWidth+layout.buttonSpacing;local isDespawnEnabled=selectedVehicleIndex and vehicles[selectedVehicleIndex]and vehicles[selectedVehicleIndex].health>0;local despawnBgColor=isDespawnEnabled and colors.BUTTON_DESPAWN_BG or colors.BUTTON_DISABLED_BG;local despawnHoverC=isDespawnEnabled and colors.BUTTON_DESPAWN_HOVER or despawnBgColor
    dxDrawStyledButton_VisualOnly("Despawn",despawnX,layout.buttonAreaY,layout.buttonAreaItemWidth,layout.buttonH,despawnBgColor,despawnHoverC,colors.BUTTON_TEXT,fonts.BUTTON,1.1,icons.DESPAWN)
    dxDrawStyledButton_VisualOnly("Close",closeX,layout.buttonAreaY,layout.buttonAreaItemWidth,layout.buttonH,colors.BUTTON_CLOSE_BG,colors.BUTTON_CLOSE_HOVER,colors.BUTTON_TEXT,fonts.BUTTON,1.1,icons.CLOSE)
end

userPanelClickHandler = function(button, state, absX, absY)
    if not panelVisible then return end
    if button ~= "left" or state ~= "up" then return end

    for index, area in pairs(vehicleClickAreas) do
        if absX >= area.x and absX <= area.x + area.w and absY >= area.y and absY <= area.y + area.h then
            selectedVehicleIndex = index; return
        end
    end

    local despawnX=layout.listAreaX;local despawnButtonArea={x=despawnX,y=layout.buttonAreaY,w=layout.buttonAreaItemWidth,h=layout.buttonH}
    local closeX=despawnX+layout.buttonAreaItemWidth+layout.buttonSpacing;local closeButtonArea={x=closeX,y=layout.buttonAreaY,w=layout.buttonAreaItemWidth,h=layout.buttonH}
    if absX>=despawnButtonArea.x and absX<=despawnButtonArea.x+despawnButtonArea.w and absY>=despawnButtonArea.y and absY<=despawnButtonArea.y+despawnButtonArea.h then
        local now=getTickCount();if now-lastClickTime<COOLDOWN_MS then return end;lastClickTime=now
        if selectedVehicleIndex and vehicles[selectedVehicleIndex]then if vehicles[selectedVehicleIndex].health>0 then triggerServerEvent("despawnPlayerVehicle",localPlayer,vehicles[selectedVehicleIndex].id)else outputChatBox("Ein zerstörtes Fahrzeug kann nicht despawnt werden.",255,100,0)end else outputChatBox("Bitte wähle zuerst ein Fahrzeug aus der Liste.",255,165,0)end;return
    end
    if absX>=closeButtonArea.x and absX<=closeButtonArea.x+closeButtonArea.w and absY>=closeButtonArea.y and absY<=closeButtonArea.y+closeButtonArea.h then
        local now=getTickCount();if now-lastClickTime<COOLDOWN_MS then return end;lastClickTime=now;closeUserPanel();return
    end
end

addEvent("showUserPanel", true)
addEventHandler("showUserPanel", root, function(pName, pMoney, pPlaytime, pFaction, pWanteds, pVehicles)
    if panelVisible then return end 
    playerName=pName; money=formatMoneyForPanel(pMoney); playtime=pPlaytime; faction=pFaction; wantedsDisplay=tostring(pWanteds or 0); vehicles=pVehicles or {}
    table.sort(vehicles,function(a,b)return(a.name or"")<(b.name or"")end); selectedVehicleIndex=nil; scrollOffset=0; panelVisible=true; showCursor(true); guiSetInputMode("no_binds_when_editing")
    
    if not isEventHandlerAdded("onClientRender",root,userPanelRenderHandler)then addEventHandler("onClientRender",root,userPanelRenderHandler)end
    if not isEventHandlerAdded("onClientClick",root,userPanelClickHandler)then addEventHandler("onClientClick",root,userPanelClickHandler,true,"high")end 
    bindKey("mouse_wheel_up","down",scrollVehicleListUp); bindKey("mouse_wheel_down","down",scrollVehicleListDown); bindKey("escape","down",closeUserPanelByKey)
end)

function scrollVehicleListUp()if not panelVisible or #vehicles<=maxVisibleVehicles then return end;scrollOffset=math.max(0,scrollOffset-1)end
function scrollVehicleListDown()if not panelVisible or #vehicles<=maxVisibleVehicles then return end;scrollOffset=math.min(#vehicles-maxVisibleVehicles,scrollOffset+1)end
function closeUserPanelByKey(key,state)if key=="escape"and state=="down"and panelVisible then closeUserPanel()end end

function closeUserPanel()
    if not panelVisible then return end; panelVisible=false; showCursor(false); guiSetInputMode("allow_binds")
    if isEventHandlerAdded("onClientRender",root,userPanelRenderHandler)then removeEventHandler("onClientRender",root,userPanelRenderHandler)end
    if isEventHandlerAdded("onClientClick",root,userPanelClickHandler)then removeEventHandler("onClientClick",root,userPanelClickHandler)end
    unbindKey("mouse_wheel_up","down",scrollVehicleListUp); unbindKey("mouse_wheel_down","down",scrollVehicleListDown); unbindKey("escape","down",closeUserPanelByKey)
    vehicles={};selectedVehicleIndex=nil;scrollOffset=0;vehicleClickAreas={};
end

addEventHandler("onClientPlayerQuit",localPlayer,closeUserPanel)
addEventHandler("onClientResourceStop",resourceRoot,function()closeUserPanel()end)

function isEventHandlerAdded(eventName,attachedTo,func)
   local handlers=getEventHandlers(eventName,attachedTo)or{};for _,handlerFunc in ipairs(handlers)do if handlerFunc==func then return true end end;return false
end

--outputDebugString("[UserPanel] Userpanel GUI (Client - OHNE SKILLS, Buttons verschoben) geladen.")