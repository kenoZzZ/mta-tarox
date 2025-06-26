-- tarox/user/client/id_client.lua
-- Version V6 mit Cursor-Anpassung für Inventar
-- MODIFIED: Added driver's license display GUI

local screenW, screenH = guiGetScreenSize()
local localPlayer = getLocalPlayer()

local idCardGuiVisible = false
_G.idCardGuiVisible = false 
local idCardDisplayData = {}
local idCardShownByPlayerName = nil

local idPurchaseConfirmVisible = false
_G.idPurchaseConfirmVisible = false 
local idPurchaseCost = 0

-- NEU: Variablen für Führerschein-GUI
local driverLicenseGuiVisible = false
_G.driverLicenseGuiVisible = false -- Globales Flag für andere Skripte
local driverLicenseDisplayData = {}
local driverLicenseShownByPlayerName = nil

if _G.isInventoryVisible == nil then _G.isInventoryVisible = false end
if _G.isPedGuiOpen == nil then _G.isPedGuiOpen = false end


function metadataStringToTableClient(str)
    if type(str) ~= "string" or str == "" then return {} end
    local tbl = {}
    for part in string.gmatch(str, "([^|]+)") do
        local key, value = string.match(part, "([^:]+):(.+)")
        if key and value then
            value = string.gsub(value, "{pipe}", "|")
            value = string.gsub(value, "{colon}", ":")
            if key == "accountId" or key == "skin" or key == "wanteds" or key == "currentSkin" then
                value = tonumber(value) or value
            end
            tbl[key] = value
        end
    end
    return tbl
end

local colorsId = {
    BG_MAIN = tocolor(35, 40, 50, 235), BG_HEADER = tocolor(60, 70, 90, 245),
    TEXT_HEADER = tocolor(230, 230, 240), TEXT_LABEL = tocolor(180, 190, 210),
    TEXT_VALUE = tocolor(255, 255, 255), TEXT_COST = tocolor(220, 220, 150),
    BUTTON_CONFIRM_BG = tocolor(70, 180, 70, 220), BUTTON_CONFIRM_HOVER = tocolor(90, 200, 90, 230),
    BUTTON_CANCEL_BG = tocolor(200, 70, 70, 220), BUTTON_CANCEL_HOVER = tocolor(230, 90, 90, 230),
    BUTTON_TEXT = tocolor(245, 245, 245),
    LICENSE_HEADER_BG = tocolor(0, 100, 180, 245), -- Blaue Farbe für Führerschein
    LICENSE_TEXT_CLASS = tocolor(255, 215, 0), -- Gold für Klassen
}
local fontsId = {
    HEADER = {font = "default-bold", scale = 1.2}, LABEL = {font = "default", scale = 1},
    VALUE = {font = "default-bold", scale = 1.0}, BUTTON = {font = "default-bold", scale = 1.0},
    COST = {font = "default-bold", scale = 1},
    LICENSE_CLASS_LABEL = {font = "default", scale = 1.0},
    LICENSE_CLASS_VALUE = {font = "default-bold", scale = 1.0}
}

local guiElementsConfirm = {}
local guiElementsDisplayID = {} -- Umbenannt zur Klarheit
local guiElementsDisplayLicense = {} -- NEU
local guiRenderHandlers = {}

local SKIN_PREVIEW_IMAGE_PATH_PREFIX = "user/client/images/skin_previews/"


addEventHandler("onClientClick", root, function(button, state, absX, absY, wx, wy, wz, elementClicked)
    if idPurchaseConfirmVisible or idCardGuiVisible or driverLicenseGuiVisible or _G.isInventoryVisible or _G.isPedGuiOpen then
        return
    end
    local cursorInteractionActive = (_G.isCursorManuallyShownByClickSystem == true) or isCursorShowing()
    if not cursorInteractionActive or button ~= "left" or state ~= "down" then
        return
    end
    if isElement(elementClicked) and getElementType(elementClicked) == "ped" then
        local pedIdentifier = getElementData(elementClicked, "pedIdentifier")
        if pedIdentifier == "id_request_officer" then
--outputDebugString("[ID-Client] Klick auf 'id_request_officer' Ped registriert. Triggere 'idcard:pedClicked'.")
            triggerServerEvent("idcard:pedClicked", localPlayer)
            cancelEvent()
            return
        end
    end
end)

addEvent("idcard:showPurchaseConfirmation", true)
addEventHandler("idcard:showPurchaseConfirmation", root, function(cost)
    if idPurchaseConfirmVisible or idCardGuiVisible or driverLicenseGuiVisible then return end
    idPurchaseCost = tonumber(cost) or 0
    idPurchaseConfirmVisible = true; _G.idPurchaseConfirmVisible = true;
    if not isCursorShowing() then showCursor(true) end
    guiSetInputMode("no_binds_when_editing")
    if not guiRenderHandlers["purchaseConfirm"] then
        addEventHandler("onClientRender", root, renderIdPurchaseConfirmGUI)
        guiRenderHandlers["purchaseConfirm"] = renderIdPurchaseConfirmGUI
    end
end)

function closeIdPurchaseConfirmGUI()
    if not idPurchaseConfirmVisible then return end
    idPurchaseConfirmVisible = false; _G.idPurchaseConfirmVisible = false;
    if not idCardGuiVisible and not driverLicenseGuiVisible and not _G.isInventoryVisible then
        showCursor(false)
        guiSetInputMode("allow_binds")
    end
    if guiRenderHandlers["purchaseConfirm"] then
        removeEventHandler("onClientRender", root, renderIdPurchaseConfirmGUI)
        guiRenderHandlers["purchaseConfirm"] = nil
    end
    guiElementsConfirm = {}
end

function renderIdPurchaseConfirmGUI()
    if not idPurchaseConfirmVisible then return end
    local w, h = 380, 200
    local panelX, panelY = (screenW - w) / 2, (screenH - h) / 2
    local headerH = 40; local padding = 15; local btnH = 35; local btnSpacing = 10
    dxDrawRectangle(panelX, panelY, w, h, colorsId.BG_MAIN)
    dxDrawRectangle(panelX, panelY, w, headerH, colorsId.BG_HEADER)
    dxDrawText("Ausweis beantragen", panelX, panelY, panelX + w, panelY + headerH, colorsId.TEXT_HEADER, fontsId.HEADER.scale, fontsId.HEADER.font, "center", "center")
    local textY = panelY + headerH + padding
    dxDrawText("Möchten Sie einen Personalausweis für\n#FCD734$" .. idPurchaseCost .. " #E6E6FAbeantragen?", panelX + padding, textY, panelX + w - padding, textY + 50, colorsId.TEXT_LABEL, fontsId.VALUE.scale, fontsId.VALUE.font, "center", "center", true,false,false,true)
    local btnW = (w - padding*2 - btnSpacing) / 2
    local btnConfirmX = panelX + padding
    local btnCancelX = btnConfirmX + btnW + btnSpacing
    local btnActionY = panelY + h - padding - btnH
    local mX_cursor,mY_cursor = getCursorPosition(); local hoverConfirm, hoverCancel = false, false
    if mX_cursor then mX_cursor,mY_cursor = mX_cursor*screenW,mY_cursor*screenH
        if mX_cursor >= btnConfirmX and mX_cursor <= btnConfirmX+btnW and mY_cursor >= btnActionY and mY_cursor <= btnActionY+btnH then hoverConfirm=true end
        if mX_cursor >= btnCancelX and mX_cursor <= btnCancelX+btnW and mY_cursor >= btnActionY and mY_cursor <= btnActionY+btnH then hoverCancel=true end
    end
    dxDrawRectangle(btnConfirmX, btnActionY, btnW, btnH, hoverConfirm and colorsId.BUTTON_CONFIRM_HOVER or colorsId.BUTTON_CONFIRM_BG)
    dxDrawText("Ja, beantragen", btnConfirmX, btnActionY, btnConfirmX+btnW, btnActionY+btnH, colorsId.BUTTON_TEXT,fontsId.BUTTON.scale,fontsId.BUTTON.font,"center","center")
    dxDrawRectangle(btnCancelX, btnActionY, btnW, btnH, hoverCancel and colorsId.BUTTON_CANCEL_HOVER or colorsId.BUTTON_CANCEL_BG)
    dxDrawText("Nein, abbrechen", btnCancelX, btnActionY, btnCancelX+btnW, btnActionY+btnH, colorsId.BUTTON_TEXT,fontsId.BUTTON.scale,fontsId.BUTTON.font,"center","center")
    guiElementsConfirm = {
        confirm = {x=btnConfirmX, y=btnActionY, w=btnW, h=btnH, action="confirm_purchase"},
        cancel = {x=btnCancelX, y=btnActionY, w=btnW, h=btnH, action="cancel_purchase"}
    }
end

addEvent("idcard:displayGUI_Client", true)
addEventHandler("idcard:displayGUI_Client", root, function(metadataString, shownBy)
    if idCardGuiVisible or driverLicenseGuiVisible then closeIdCardDisplayGUI_Client(); closeDriverLicenseDisplayGUI_Client() end
    local data = metadataStringToTableClient(metadataString)
    if type(data) ~= "table" or not next(data) then outputChatBox("Fehler: Ausweisdaten fehlerhaft.", 255, 0, 0); return end
    idCardDisplayData = data
    idCardShownByPlayerName = shownBy or nil
    idCardGuiVisible = true; _G.idCardGuiVisible = true;
    if not isCursorShowing() then showCursor(true) end
    guiSetInputMode("no_binds_when_editing")
    if not guiRenderHandlers["displayCard"] then
        addEventHandler("onClientRender", root, renderIdCardDisplayGUI_Client)
        guiRenderHandlers["displayCard"] = renderIdCardDisplayGUI_Client
    end
end)

function closeIdCardDisplayGUI_Client()
    if not idCardGuiVisible then return end
    idCardGuiVisible = false; _G.idCardGuiVisible = false;
    if not idPurchaseConfirmVisible and not driverLicenseGuiVisible and not _G.isInventoryVisible then
        showCursor(false)
        guiSetInputMode("allow_binds")
    end
    if guiRenderHandlers["displayCard"] then
        removeEventHandler("onClientRender", root, renderIdCardDisplayGUI_Client)
        guiRenderHandlers["displayCard"] = nil
    end
    idCardDisplayData = {}; idCardShownByPlayerName = nil; guiElementsDisplayID = {}
end

function renderIdCardDisplayGUI_Client()
    if not idCardGuiVisible then return end
    local w, h = 400, 290; local panelX, panelY = (screenW - w) / 2, (screenH - h) / 2
    dxDrawRectangle(panelX, panelY, w, h, colorsId.BG_MAIN)
    local headerText = "PERSONALAUSWEIS"; if idCardShownByPlayerName then headerText = "Ausweis von: " .. idCardShownByPlayerName end
    dxDrawRectangle(panelX, panelY, w, 45, colorsId.BG_HEADER)
    dxDrawText(headerText, panelX, panelY, panelX + w, panelY + 45, colorsId.TEXT_HEADER, fontsId.HEADER.scale, fontsId.HEADER.font, "center", "center")
    local contentX = panelX + 20; local lineY = panelY + 45 + 20
    local labelX = contentX; local valueX = contentX + 130; local lineHeight = 24
    local skinDisplayW = 60; local skinDisplayH = 90
    local skinPreviewX = panelX + w - 20 - skinDisplayW; local skinPreviewY = lineY
    local skinID_to_display = idCardDisplayData.currentSkin or idCardDisplayData.skin or 0
    local skinImagePath = SKIN_PREVIEW_IMAGE_PATH_PREFIX .. tostring(skinID_to_display) .. ".png"
    if fileExists(skinImagePath) then dxDrawImage(skinPreviewX, skinPreviewY, skinDisplayW, skinDisplayH, skinImagePath, 0, 0, 0, tocolor(255,255,255,255))
    else dxDrawRectangle(skinPreviewX, skinPreviewY, skinDisplayW, skinDisplayH, tocolor(20,20,25,200)); dxDrawText("Skin ID:\n" .. tostring(skinID_to_display), skinPreviewX, skinPreviewY, skinPreviewX + skinDisplayW, skinPreviewY + skinDisplayH, tocolor(150,150,160), 1.0, "default", "center", "center") end
    dxDrawLine(skinPreviewX,skinPreviewY, skinPreviewX+skinDisplayW, skinPreviewY, colorsId.TEXT_LABEL,1); dxDrawLine(skinPreviewX,skinPreviewY+skinDisplayH, skinPreviewX+skinDisplayW, skinPreviewY+skinDisplayH, colorsId.TEXT_LABEL,1); dxDrawLine(skinPreviewX,skinPreviewY, skinPreviewX, skinPreviewY+skinDisplayH, colorsId.TEXT_LABEL,1); dxDrawLine(skinPreviewX+skinDisplayW,skinPreviewY, skinPreviewX+skinDisplayW, skinPreviewY+skinDisplayH, colorsId.TEXT_LABEL,1)
    dxDrawText("Name:", labelX, lineY, 0,0, colorsId.TEXT_LABEL, fontsId.LABEL.scale, fontsId.LABEL.font); dxDrawText(idCardDisplayData.name or "N/A", valueX, lineY, 0,0, colorsId.TEXT_VALUE, fontsId.VALUE.scale, fontsId.VALUE.font); lineY = lineY + lineHeight
    dxDrawText("Spielzeit:", labelX, lineY, 0,0, colorsId.TEXT_LABEL, fontsId.LABEL.scale, fontsId.LABEL.font); dxDrawText(idCardDisplayData.playtime or "00:00", valueX, lineY, 0,0, tocolor(220,220,150), fontsId.VALUE.scale, fontsId.VALUE.font); lineY = lineY + lineHeight
    dxDrawText("Wanteds:", labelX, lineY, 0,0, colorsId.TEXT_LABEL, fontsId.LABEL.scale, fontsId.LABEL.font); local wantedsColor = (tonumber(idCardDisplayData.wanteds) or 0) > 0 and tocolor(255,100,100) or tocolor(150,220,150); dxDrawText(tostring(idCardDisplayData.wanteds or "0"), valueX, lineY, 0,0, wantedsColor, fontsId.VALUE.scale, fontsId.VALUE.font); lineY = lineY + lineHeight
    dxDrawText("Ausgestellt:", labelX, lineY, 0,0, colorsId.TEXT_LABEL, fontsId.LABEL.scale, fontsId.LABEL.font); dxDrawText(idCardDisplayData.issued or "N/A", valueX, lineY, 0,0, tocolor(200,200,200), fontsId.LABEL.scale, fontsId.LABEL.font); lineY = lineY + lineHeight
    dxDrawText("Seriennr.:", labelX, lineY, 0,0, colorsId.TEXT_LABEL, fontsId.LABEL.scale, fontsId.LABEL.font); dxDrawText(idCardDisplayData.serialNumber or "N/A", valueX, lineY, 0,0, tocolor(200,200,200), fontsId.LABEL.scale, fontsId.LABEL.font); lineY = lineY + 35
    local btnCloseW, btnCloseH = 130, 38; local btnCloseX = panelX + (w - btnCloseW) / 2; local btnCloseY = panelY + h - btnCloseH - 15
    local mX_cursor, mY_cursor = getCursorPosition(); local hoverClose = false
    if mX_cursor then mX_cursor,mY_cursor = mX_cursor*screenW, mY_cursor*screenH; if mX_cursor >= btnCloseX and mX_cursor <= btnCloseX+btnCloseW and mY_cursor >= btnCloseY and mY_cursor <= btnCloseY+btnCloseH then hoverClose = true end end
    dxDrawRectangle(btnCloseX, btnCloseY, btnCloseW, btnCloseH, hoverClose and colorsId.BUTTON_CANCEL_HOVER or colorsId.BUTTON_CANCEL_BG)
    dxDrawText("Schließen", btnCloseX, btnCloseY, btnCloseX+btnCloseW, btnCloseY+btnCloseH, colorsId.BUTTON_TEXT, fontsId.BUTTON.scale, fontsId.BUTTON.font, "center","center")
    guiElementsDisplayID = { closeButton = {x=btnCloseX, y=btnCloseY, w=btnCloseW, h=btnCloseH, action="close_display_id"} }
end


-- NEU: Funktionen für Führerschein-GUI
addEvent("drivelicense:displayGUI_Client", true)
addEventHandler("drivelicense:displayGUI_Client", root, function(metadataString, shownBy)
    if idCardGuiVisible or driverLicenseGuiVisible then closeIdCardDisplayGUI_Client(); closeDriverLicenseDisplayGUI_Client() end
    local data = metadataStringToTableClient(metadataString)
    if type(data) ~= "table" or not next(data) then outputChatBox("Fehler: Führerscheindaten fehlerhaft.", 255, 0, 0); return end
    driverLicenseDisplayData = data
    driverLicenseShownByPlayerName = shownBy or nil
    driverLicenseGuiVisible = true; _G.driverLicenseGuiVisible = true;
    if not isCursorShowing() then showCursor(true) end
    guiSetInputMode("no_binds_when_editing")
    if not guiRenderHandlers["displayLicense"] then
        addEventHandler("onClientRender", root, renderDriverLicenseDisplayGUI_Client)
        guiRenderHandlers["displayLicense"] = renderDriverLicenseDisplayGUI_Client
    end
end)

function closeDriverLicenseDisplayGUI_Client()
    if not driverLicenseGuiVisible then return end
    driverLicenseGuiVisible = false; _G.driverLicenseGuiVisible = false;
    if not idPurchaseConfirmVisible and not idCardGuiVisible and not _G.isInventoryVisible then
        showCursor(false)
        guiSetInputMode("allow_binds")
    end
    if guiRenderHandlers["displayLicense"] then
        removeEventHandler("onClientRender", root, renderDriverLicenseDisplayGUI_Client)
        guiRenderHandlers["displayLicense"] = nil
    end
    driverLicenseDisplayData = {}; driverLicenseShownByPlayerName = nil; guiElementsDisplayLicense = {}
end

function renderDriverLicenseDisplayGUI_Client()
    if not driverLicenseGuiVisible then return end
    local w, h = 400, 250 -- Höhe angepasst für Lizenzinfo
    local panelX, panelY = (screenW - w) / 2, (screenH - h) / 2
    dxDrawRectangle(panelX, panelY, w, h, colorsId.BG_MAIN)
    local headerText = "FÜHRERSCHEIN"; if driverLicenseShownByPlayerName then headerText = "Führerschein von: " .. driverLicenseShownByPlayerName end
    dxDrawRectangle(panelX, panelY, w, 45, colorsId.LICENSE_HEADER_BG) -- Blauer Header für Führerschein
    dxDrawText(headerText, panelX, panelY, panelX + w, panelY + 45, colorsId.TEXT_HEADER, fontsId.HEADER.scale, fontsId.HEADER.font, "center", "center")

    local contentX = panelX + 20
    local lineY = panelY + 45 + 20
    local labelX = contentX
    local valueX = contentX + 150 -- Mehr Platz für Lizenzklassen
    local lineHeight = 26

    -- Name anzeigen
    dxDrawText("Name:", labelX, lineY, 0,0, colorsId.TEXT_LABEL, fontsId.LABEL.scale, fontsId.LABEL.font)
    dxDrawText(driverLicenseDisplayData.name or "N/A", valueX, lineY, 0,0, colorsId.TEXT_VALUE, fontsId.VALUE.scale, fontsId.VALUE.font)
    lineY = lineY + lineHeight

    -- Ausstellungsdatum anzeigen
    dxDrawText("Ausgestellt am:", labelX, lineY, 0,0, colorsId.TEXT_LABEL, fontsId.LABEL.scale, fontsId.LABEL.font)
    dxDrawText(driverLicenseDisplayData.issuedDate or "N/A", valueX, lineY, 0,0, colorsId.TEXT_VALUE, fontsId.LABEL.scale, fontsId.LABEL.font) -- Kleinere Schrift für Datum
    lineY = lineY + lineHeight + 10 -- Mehr Abstand vor Klassen

    -- Führerscheinklassen anzeigen
    dxDrawText("Klassen:", labelX, lineY, 0,0, colorsId.TEXT_LABEL, fontsId.LICENSE_CLASS_LABEL.scale, fontsId.LICENSE_CLASS_LABEL.font)
    lineY = lineY + lineHeight * 0.8 -- Etwas weniger Abstand für die Klassenliste

    local licensesStr = driverLicenseDisplayData.licenses or ""
    local licenseClasses = {}
    for class in string.gmatch(licensesStr, "([^,]+)") do
        table.insert(licenseClasses, string.upper(class)) -- Zeige Klassen in Großbuchstaben an
    end

    if #licenseClasses > 0 then
        for i, classKey in ipairs(licenseClasses) do
            local classDisplayName = (_G.LICENSE_CONFIG and _G.LICENSE_CONFIG[string.lower(classKey)] and _G.LICENSE_CONFIG[string.lower(classKey)].displayName) or classKey
            dxDrawText("- " .. classDisplayName, labelX + 15, lineY, 0,0, colorsId.LICENSE_TEXT_CLASS, fontsId.LICENSE_CLASS_VALUE.scale, fontsId.LICENSE_CLASS_VALUE.font)
            lineY = lineY + lineHeight * 0.9
            if i >= 3 and #licenseClasses > 3 then -- Max 3 Klassen direkt anzeigen, dann "..."
                 if i == 3 and #licenseClasses > 3 then
                    dxDrawText("  ...", labelX + 15, lineY, 0,0, colorsId.LICENSE_TEXT_CLASS, fontsId.LICENSE_CLASS_VALUE.scale, fontsId.LICENSE_CLASS_VALUE.font)
                    lineY = lineY + lineHeight * 0.9
                 end
                 break
            end
        end
    else
        dxDrawText("Keine Klassen vorhanden", labelX + 15, lineY, 0,0, colorsId.TEXT_VALUE, fontsId.LABEL.scale, fontsId.LABEL.font)
        lineY = lineY + lineHeight
    end
    
    lineY = math.max(lineY, panelY + h - 38 - 15 - 5) -- Stelle sicher, dass der Button unten ist

    local btnCloseW, btnCloseH = 130, 38
    local btnCloseX = panelX + (w - btnCloseW) / 2
    local btnCloseY = panelY + h - btnCloseH - 15

    local mX_cursor, mY_cursor = getCursorPosition(); local hoverClose = false
    if mX_cursor then mX_cursor,mY_cursor = mX_cursor*screenW, mY_cursor*screenH; if mX_cursor >= btnCloseX and mX_cursor <= btnCloseX+btnCloseW and mY_cursor >= btnCloseY and mY_cursor <= btnCloseY+btnCloseH then hoverClose = true end end
    dxDrawRectangle(btnCloseX, btnCloseY, btnCloseW, btnCloseH, hoverClose and colorsId.BUTTON_CANCEL_HOVER or colorsId.BUTTON_CANCEL_BG)
    dxDrawText("Schließen", btnCloseX, btnCloseY, btnCloseX+btnCloseW, btnCloseY+btnCloseH, colorsId.BUTTON_TEXT, fontsId.BUTTON.scale, fontsId.BUTTON.font, "center","center")
    guiElementsDisplayLicense = { closeButton = {x=btnCloseX, y=btnCloseY, w=btnCloseW, h=btnCloseH, action="close_display_license"} }
end


addEventHandler("onClientClick", root, function(button, state, absX, absY)
    if not (idPurchaseConfirmVisible or idCardGuiVisible or driverLicenseGuiVisible) then return end
    if button ~= "left" or state ~= "up" then return end

    if idPurchaseConfirmVisible and guiElementsConfirm and guiElementsConfirm.confirm and guiElementsConfirm.cancel then
        local btnC = guiElementsConfirm.confirm; local btnN = guiElementsConfirm.cancel
        if absX >= btnC.x and absX <= btnC.x + btnC.w and absY >= btnC.y and absY <= btnC.y + btnC.h then
            triggerServerEvent("idcard:confirmPurchase", localPlayer); closeIdPurchaseConfirmGUI(); cancelEvent(); return
        elseif absX >= btnN.x and absX <= btnN.x + btnN.w and absY >= btnN.y and absY <= btnN.y + btnN.h then
            closeIdPurchaseConfirmGUI(); cancelEvent(); return
        end
    end

    if idCardGuiVisible and guiElementsDisplayID and guiElementsDisplayID.closeButton then
        local btn = guiElementsDisplayID.closeButton
        if btn and absX >= btn.x and absX <= btn.x + btn.w and absY >= btn.y and absY <= btn.y + btn.h then
            closeIdCardDisplayGUI_Client(); cancelEvent(); return
        end
    end

    -- NEU: Klick-Handling für Führerschein-GUI
    if driverLicenseGuiVisible and guiElementsDisplayLicense and guiElementsDisplayLicense.closeButton then
        local btn = guiElementsDisplayLicense.closeButton
        if btn and absX >= btn.x and absX <= btn.x + btn.w and absY >= btn.y and absY <= btn.y + btn.h then
            closeDriverLicenseDisplayGUI_Client(); cancelEvent(); return
        end
    end
end)

addEventHandler("onClientKey", root, function(key, press)
    if key == "escape" and press then
        if idPurchaseConfirmVisible then closeIdPurchaseConfirmGUI(); cancelEvent()
        elseif idCardGuiVisible then closeIdCardDisplayGUI_Client(); cancelEvent()
        elseif driverLicenseGuiVisible then closeDriverLicenseDisplayGUI_Client(); cancelEvent() -- NEU
        end
    end
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    if _G.idCardGuiVisible == nil then _G.idCardGuiVisible = false end
    if _G.idPurchaseConfirmVisible == nil then _G.idPurchaseConfirmVisible = false end
    if _G.driverLicenseGuiVisible == nil then _G.driverLicenseGuiVisible = false end -- NEU
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    closeIdCardDisplayGUI_Client()
    closeIdPurchaseConfirmGUI()
    closeDriverLicenseDisplayGUI_Client() -- NEU
end)

--outputDebugString("[ID-System & License-Item] Client (V6 mit Cursor-Anpassung & Führerschein-GUI) geladen.")