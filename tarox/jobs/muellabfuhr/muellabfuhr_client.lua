-- tarox/jobs/muellabfuhr/muellabfuhr_client.lua
-- ANGEPASST: Sichtbare Marker durch Müll-Objekte (ID 2672) und unsichtbare Trigger ersetzt.

-- =================================================================
-- Globale Variablen & Konfiguration
-- =================================================================
local localPlayer = getLocalPlayer()
local screenW, screenH = guiGetScreenSize()

-- GUI Status
local isJobSelectionVisible = false
local isJobConfirmVisible = false
local currentJobsData = {}
local currentConfirmJobKey = nil
local currentConfirmJobDisplayName = ""
local currentJobSkillLevel = 0
local currentJobCompletedTotal = 0
local currentJobNeededForNext = "N/A"

-- Checkpoint & Objekt-Verwaltung
local currentJobCheckpointMarker, currentJobBlip = nil, nil
local currentGarbageObject = nil -- NEU: Variable für das Müll-Objekt

-- Design Konstanten
local layout = {
    panelW = 470,
    panelH_selection_base = 120, panelH_confirm = 260,
    headerH = 45, padding = 20, itemHeight = 55,
    itemSpacing = 8,
    buttonH = 40, buttonSpacing = 12,
    iconSize = 18, iconPadding = 7,
    skillTextOffsetX = 195,
    detailTextOffsetY = 18
}

local colors = {
    BG_MAIN = tocolor(28, 30, 36, 240),
    BG_HEADER = tocolor(38, 40, 48, 245),
    TEXT_HEADER = tocolor(235, 235, 240),
    TEXT_LABEL = tocolor(190, 195, 205),
    TEXT_VALUE = tocolor(220, 220, 225),
    TEXT_SKILL = tocolor(120, 180, 255),
    TEXT_JOB_DETAIL = tocolor(160, 165, 175),
    BUTTON_JOB_BG = tocolor(45, 48, 56, 220),
    BUTTON_JOB_HOVER = tocolor(55, 58, 68, 230),
    BUTTON_JOB_TEXT = tocolor(210, 215, 225),
    BUTTON_YES_BG = tocolor(70, 180, 70, 220),
    BUTTON_YES_HOVER = tocolor(90, 200, 90, 230),
    BUTTON_NO_BG = tocolor(200, 70, 70, 220),
    BUTTON_NO_HOVER = tocolor(220, 90, 90, 230),
    BUTTON_TEXT_CONFIRM = tocolor(245, 245, 245),
    BORDER_LIGHT = tocolor(55, 58, 68, 180),
    BORDER_DARK = tocolor(20, 22, 28, 220)
}

local fonts = {
    HEADER = {font = "default-bold", scale = 1.2},
    TEXT = {font = "default", scale = 1.0},
    BUTTON = {font = "default-bold", scale = 1.0},
    SKILL = {font = "default", scale = 1.0},
    JOB_DETAIL = {font = "default", scale = 1.0}
}

local icons = {
    JOB_DEFAULT = "user/client/images/usericons/job_icon.png",
    CONFIRM = "user/client/images/usericons/confirm.png",
    CANCEL = "user/client/images/usericons/cancel.png"
}

local jobSelectionElements = {}
local jobConfirmElements = {}

if _G.isPedGuiOpen == nil then _G.isPedGuiOpen = false end
_G.isJobGuiOpen = false

local jobSelectionRenderHandler = nil
local jobSelectionClickHandler = nil
local jobSelectionKeyHandler = nil


-- =================================================================
-- Hilfsfunktionen für DX-Zeichnung (unverändert)
-- =================================================================
local function dxDrawStyledPanel(x, y, w, h, title)
    dxDrawRectangle(x, y, w, h, colors.BG_MAIN)
    dxDrawLine(x, y, x + w, y, colors.BORDER_LIGHT, 2)
    dxDrawLine(x, y + h, x + w, y + h, colors.BORDER_DARK, 2)
    dxDrawLine(x, y, x, y + h, colors.BORDER_LIGHT, 2)
    dxDrawLine(x + w, y, x + w, y + h, colors.BORDER_DARK, 2)

    dxDrawRectangle(x, y, w, layout.headerH, colors.BG_HEADER)
    dxDrawText(title, x, y, x + w, y + layout.headerH, colors.TEXT_HEADER, fonts.HEADER.scale, fonts.HEADER.font, "center", "center")
end

local function dxDrawStyledJobButton(id, text, skillText, jobsCompletedText, jobsNeededText, x, y, w, h)
    local cX, cY = getCursorPosition()
    local hover = false
    if cX then
        local mouseX, mouseY = cX * screenW, cY * screenH
        hover = mouseX >= x and mouseX <= x + w and mouseY >= y and mouseY <= y + h
    end
    local currentBgColor = hover and colors.BUTTON_JOB_HOVER or colors.BUTTON_JOB_BG
    dxDrawRectangle(x, y, w, h, currentBgColor)
    dxDrawLine(x,y, x+w,y, colors.BORDER_LIGHT,1); dxDrawLine(x,y+h, x+w,y+h, colors.BORDER_DARK,1)
    dxDrawLine(x,y,x,y+h, colors.BORDER_LIGHT,1); dxDrawLine(x+w,y,x+w,y+h, colors.BORDER_DARK,1)

    local textDrawX = x + layout.padding / 2
    local iconDrawSize = layout.iconSize * 0.9
    local iconX = x + layout.iconPadding / 2 + 5
    local iconY_main = y + (h / 2 - layout.detailTextOffsetY / 2 - iconDrawSize) / 2 + 3

    if icons.JOB_DEFAULT and fileExists(icons.JOB_DEFAULT) then
        dxDrawImage(iconX, iconY_main, iconDrawSize, iconDrawSize, icons.JOB_DEFAULT, 0,0,0,tocolor(200,200,220,200))
        textDrawX = iconX + iconDrawSize + layout.iconPadding / 2
    end
    
    local availableWidthForJobName = w - (textDrawX - x) - (layout.padding / 2) - layout.skillTextOffsetX
    dxDrawText(text, textDrawX, y, textDrawX + availableWidthForJobName, y + h/2 - layout.detailTextOffsetY/2 + 3, colors.BUTTON_JOB_TEXT, fonts.BUTTON.scale, fonts.BUTTON.font, "left", "center", true)

    if skillText then
        local skillDrawX = x + w - layout.skillTextOffsetX - layout.padding / 2
        dxDrawText(skillText, skillDrawX, y, x + w - (layout.padding / 2 + 5), y + h/2 - layout.detailTextOffsetY/2 + 3, colors.TEXT_SKILL, fonts.SKILL.scale, fonts.SKILL.font, "right", "center", true)
    end

    local detailY = y + h/2 - layout.detailTextOffsetY / 2 + 3
    
    local completedTextDrawWidth = w - (textDrawX - x) - (layout.padding / 2) - layout.skillTextOffsetX
    if jobsCompletedText then
        dxDrawText(jobsCompletedText, textDrawX, detailY, textDrawX + completedTextDrawWidth, detailY + layout.detailTextOffsetY, colors.TEXT_JOB_DETAIL, fonts.JOB_DETAIL.scale, fonts.JOB_DETAIL.font, "left", "top", true)
    end

    if jobsNeededText then
        local jobsNeededX = x + w - layout.skillTextOffsetX - layout.padding / 2
        dxDrawText(jobsNeededText, jobsNeededX, detailY, x + w - (layout.padding/2 + 5), detailY + layout.detailTextOffsetY, colors.TEXT_JOB_DETAIL, fonts.JOB_DETAIL.scale, fonts.JOB_DETAIL.font, "right", "top", true)
    end

    jobSelectionElements[id] = { x = x, y = y, w = w, h = h, jobKey = id }
end

local function dxDrawStyledConfirmButton(id, text, x, y, w, h, style, iconPath, targetElementTable)
    targetElementTable = targetElementTable or jobConfirmElements

    local cX, cY = getCursorPosition(); local hover = false
    if cX then local mouseX, mouseY = cX*screenW, cY*screenH; hover = mouseX >= x and mouseX <= x+w and mouseY >= y and mouseY <= y+h end
    local currentBgColor = style.bg; if hover then currentBgColor = style.hover end
    dxDrawRectangle(x,y,w,h,currentBgColor)
    dxDrawLine(x,y,x+w,y,colors.BORDER_LIGHT,1); dxDrawLine(x,y+h,x+w,y+h,colors.BORDER_DARK,1)

    local textDrawX = x; local textDrawW = w
    if iconPath and fileExists(iconPath) then
        local iconDrawSize = layout.iconSize; local iconX = x + (layout.padding/2); local iconY = y + (h-iconDrawSize)/2
        dxDrawImage(iconX, iconY, iconDrawSize, iconDrawSize, iconPath, 0,0,0,tocolor(255,255,255,220))
        textDrawX = iconX + iconDrawSize + layout.iconPadding/2; textDrawW = w - (textDrawX-x) - (layout.padding/2)
    end
    dxDrawText(text,textDrawX,y,textDrawX+textDrawW,y+h,style.text or colors.BUTTON_TEXT_CONFIRM,fonts.BUTTON.scale,fonts.BUTTON.font,"center","center",false,false,false,true)
    targetElementTable[id] = { x = x, y = y, w = w, h = h, action = id }
end

-- =================================================================
-- Jobauswahl-GUI (unverändert)
-- =================================================================
function showJobSelectionGUI_DX(jobsWithSkills)
    closeAllJobGUIs_DX()
    _G.isJobGuiOpen = true
    isJobSelectionVisible = true
    currentJobsData = jobsWithSkills or {}
    jobSelectionElements = {}

    if not isCursorShowing() then showCursor(true) end
    guiSetInputMode("no_binds_when_editing")

    if not jobSelectionRenderHandler then
        jobSelectionRenderHandler = renderJobSelectionGUI_DX
        addEventHandler("onClientRender", root, jobSelectionRenderHandler)
    end
    if not jobSelectionClickHandler then
        jobSelectionClickHandler = handleJobSelectionClick_DX
        addEventHandler("onClientClick", root, jobSelectionClickHandler)
    end
    if not jobSelectionKeyHandler then
        jobSelectionKeyHandler = function(key, press) if key == "escape" and press then closeAllJobGUIs_DX() end end
        addEventHandler("onClientKey", root, jobSelectionKeyHandler, true)
    end
end
addEvent("jobs:showJobSelectionGUI", true)
addEventHandler("jobs:showJobSelectionGUI", root, showJobSelectionGUI_DX)

function renderJobSelectionGUI_DX()
    if not isJobSelectionVisible then return end
    local numJobs = 0; for _ in pairs(currentJobsData) do numJobs = numJobs + 1 end
    local windowHeight = layout.panelH_selection_base + (numJobs * (layout.itemHeight + layout.itemSpacing))
    windowHeight = math.min(windowHeight, screenH * 0.8)
    local panelX, panelY = (screenW - layout.panelW) / 2, (screenH - windowHeight) / 2
    dxDrawStyledPanel(panelX, panelY, layout.panelW, windowHeight, "Jobvermittlung")
    local labelY = panelY + layout.headerH + layout.padding / 2
    dxDrawText("Wähle einen Job:", panelX + layout.padding, labelY, panelX + layout.panelW - layout.padding, labelY + 20, colors.TEXT_LABEL, fonts.TEXT.scale, fonts.TEXT.font, "left", "top")
    local currentItemY = labelY + 20 + layout.itemSpacing
    local listContentWidth = layout.panelW - layout.padding * 2
    for jobKey, jobData in pairs(currentJobsData) do
        local skillText = "Skill: Lvl " .. (jobData.skillLevel or 0)
        local jobsCompletedText = "Erledigte Touren: " .. (jobData.jobsCompletedTotal or 0)
        local jobsNeededNum = jobData.jobsNeededForNextLevel
        local jobsNeededTextDisplay = "Next LvL -> (Touren in): " .. (type(jobsNeededNum) == "number" and jobsNeededNum > 0 and tostring(jobsNeededNum) or (jobsNeededNum == "Max" and "Max" or "N/A"))
        dxDrawStyledJobButton(jobKey, jobData.displayName, skillText, jobsCompletedText, jobsNeededTextDisplay, panelX + layout.padding, currentItemY, listContentWidth, layout.itemHeight)
        currentItemY = currentItemY + layout.itemHeight + layout.itemSpacing
        if currentItemY + layout.itemHeight > panelY + windowHeight - (layout.padding + layout.buttonH) then
            dxDrawText("...", panelX + layout.padding, currentItemY, panelX + layout.panelW - layout.padding, currentItemY + 20, colors.TEXT_LABEL, fonts.TEXT.scale, fonts.TEXT.font, "center", "top")
            break
        end
    end
    local closeButtonY = panelY + windowHeight - layout.padding - layout.buttonH
    dxDrawStyledConfirmButton("close_selection", "Schließen", panelX + layout.padding, closeButtonY, layout.panelW - layout.padding*2, layout.buttonH, {bg = colors.BUTTON_NO_BG, hover = colors.BUTTON_NO_HOVER, text=colors.BUTTON_TEXT_CONFIRM}, icons.CANCEL, jobSelectionElements)
end

function handleJobSelectionClick_DX(button, state, absX, absY)
    if not isJobSelectionVisible or button ~= "left" or state ~= "up" then return end
    for id, area in pairs(jobSelectionElements) do
        if absX >= area.x and absX <= area.x + area.w and absY >= area.y and absY <= area.y + area.h then
            if id == "close_selection" then
                closeAllJobGUIs_DX()
            else
                triggerServerEvent("jobs:playerSelectedJob", localPlayer, area.jobKey)
            end
            playSoundFrontEnd(40)
            return
        end
    end
end

-- =================================================================
-- Job-Bestätigungs-GUI (Müllfahrer) (unverändert)
-- =================================================================
function showMuellfahrerConfirmGUI_DX(jobKey, displayName, skillLevel, jobsCompleted, jobsNeeded)
    closeAllJobGUIs_DX()
    _G.isJobGuiOpen = true
    isJobConfirmVisible = true
    currentConfirmJobKey = jobKey
    currentConfirmJobDisplayName = displayName
    currentJobSkillLevel = skillLevel or 0
    currentJobCompletedTotal = jobsCompleted or 0
    currentJobNeededForNext = jobsNeeded or "N/A"
    jobConfirmElements = {}
    if not isCursorShowing() then showCursor(true) end
    guiSetInputMode("no_binds_when_editing")
    if not jobSelectionRenderHandler then
        jobSelectionRenderHandler = renderMuellfahrerConfirmGUI_DX
        addEventHandler("onClientRender", root, jobSelectionRenderHandler)
    else
        removeEventHandler("onClientRender", root, jobSelectionRenderHandler)
        jobSelectionRenderHandler = renderMuellfahrerConfirmGUI_DX
        addEventHandler("onClientRender", root, jobSelectionRenderHandler)
    end
    if not jobSelectionClickHandler then
        jobSelectionClickHandler = handleMuellfahrerConfirmClick_DX
        addEventHandler("onClientClick", root, jobSelectionClickHandler)
    end
    if not jobSelectionKeyHandler then
        jobSelectionKeyHandler = function(key, press) if key == "escape" and press then closeAllJobGUIs_DX() end end
        addEventHandler("onClientKey", root, jobSelectionKeyHandler, true)
    end
end
addEvent("jobs:muellfahrer:confirmStart", true)
addEventHandler("jobs:muellfahrer:confirmStart", root, showMuellfahrerConfirmGUI_DX)

function renderMuellfahrerConfirmGUI_DX()
    if not isJobConfirmVisible then return end
    local panelH = layout.panelH_confirm
    local panelX, panelY = (screenW - layout.panelW) / 2, (screenH - panelH) / 2
    dxDrawStyledPanel(panelX, panelY, layout.panelW, panelH, currentConfirmJobDisplayName .. " Job")
    local messageY = panelY + layout.headerH + layout.padding
    local textHeightForOneLine = dxGetFontHeight(fonts.TEXT.scale, fonts.TEXT.font)
    if not textHeightForOneLine or textHeightForOneLine <= 0 then textHeightForOneLine = 16 end
    local line1Text = "Möchtest du den Job als '" .. currentConfirmJobDisplayName .. "' starten?"
    dxDrawText(line1Text, panelX + layout.padding, messageY, panelX + layout.panelW - layout.padding, messageY + textHeightForOneLine, colors.TEXT_LABEL, fonts.TEXT.scale, fonts.TEXT.font, "center", "top", true)
    messageY = messageY + textHeightForOneLine + 5
    local line2Text = "Dein Skill: Lvl " .. currentJobSkillLevel
    dxDrawText(line2Text, panelX + layout.padding, messageY, panelX + layout.panelW - layout.padding, messageY + textHeightForOneLine, colors.TEXT_SKILL, fonts.SKILL.scale, fonts.SKILL.font, "center", "top")
    messageY = messageY + textHeightForOneLine + 10
    local line3Text = "Insgesamt erledigte Strecken: " .. currentJobCompletedTotal
    dxDrawText(line3Text, panelX + layout.padding, messageY, panelX + layout.panelW - layout.padding, messageY + textHeightForOneLine, colors.TEXT_JOB_DETAIL, fonts.JOB_DETAIL.scale, fonts.JOB_DETAIL.font, "center", "top")
    messageY = messageY + textHeightForOneLine + 5
    local jobsNeededNum = currentJobNeededForNext
    local line4Text = "Benötigte Strecken zum nächsten Level: " .. (type(jobsNeededNum) == "number" and jobsNeededNum > 0 and tostring(jobsNeededNum) or (jobsNeededNum == "Max" and "Max Level" or "N/A"))
    dxDrawText(line4Text, panelX + layout.padding, messageY, panelX + layout.panelW - layout.padding, messageY + textHeightForOneLine, colors.TEXT_JOB_DETAIL, fonts.JOB_DETAIL.scale, fonts.JOB_DETAIL.font, "center", "top")
    local buttonAreaY = panelY + panelH - layout.padding - layout.buttonH
    local confirmButtonW = (layout.panelW - layout.padding*2 - layout.buttonSpacing) / 2
    dxDrawStyledConfirmButton("confirm_yes", "Ja, starten", panelX + layout.padding, buttonAreaY, confirmButtonW, layout.buttonH, {bg = colors.BUTTON_YES_BG, hover = colors.BUTTON_YES_HOVER, text=colors.BUTTON_TEXT_CONFIRM}, icons.CONFIRM, jobConfirmElements)
    dxDrawStyledConfirmButton("confirm_no", "Nein, abbrechen", panelX + layout.padding + confirmButtonW + layout.buttonSpacing, buttonAreaY, confirmButtonW, layout.buttonH, {bg = colors.BUTTON_NO_BG, hover = colors.BUTTON_NO_HOVER, text=colors.BUTTON_TEXT_CONFIRM}, icons.CANCEL, jobConfirmElements)
end

function handleMuellfahrerConfirmClick_DX(button, state, absX, absY)
    if not isJobConfirmVisible or button ~= "left" or state ~= "up" then return end
    for action, area in pairs(jobConfirmElements) do
        if absX >= area.x and absX <= area.x + area.w and absY >= area.y and absY <= area.y + area.h then
            if action == "confirm_yes" then
                triggerServerEvent("jobs:muellfahrer:startJobConfirmed", localPlayer, currentConfirmJobKey)
            end
            closeAllJobGUIs_DX()
            playSoundFrontEnd(40)
            return
        end
    end
end

-- =================================================================
-- Job-Elemente & Checkpoint-Handling
-- =================================================================
function closeAllJobGUIs_DX()
    if isJobSelectionVisible then
        isJobSelectionVisible = false
        if jobSelectionRenderHandler then removeEventHandler("onClientRender", root, jobSelectionRenderHandler); jobSelectionRenderHandler = nil end
        if jobSelectionClickHandler then removeEventHandler("onClientClick", root, jobSelectionClickHandler); jobSelectionClickHandler = nil end
        if jobSelectionKeyHandler then removeEventHandler("onClientKey", root, jobSelectionKeyHandler); jobSelectionKeyHandler = nil end
    end
    if isJobConfirmVisible then
        isJobConfirmVisible = false
        if not isJobSelectionVisible then
            if jobSelectionRenderHandler then removeEventHandler("onClientRender", root, jobSelectionRenderHandler); jobSelectionRenderHandler = nil end
            if jobSelectionClickHandler then removeEventHandler("onClientClick", root, jobSelectionClickHandler); jobSelectionClickHandler = nil end
            if jobSelectionKeyHandler then removeEventHandler("onClientKey", root, jobSelectionKeyHandler); jobSelectionKeyHandler = nil end
        end
    end
    if _G.isJobGuiOpen then
        if not isCursorShowing() and not (_G.isInventoryVisible or _G.isHandyGUIVisible or _G.isMessageGUIOpen or _G.isPedGuiOpen) then
        elseif isCursorShowing() and not (_G.isInventoryVisible or _G.isHandyGUIVisible or _G.isMessageGUIOpen or _G.isPedGuiOpen) then
             showCursor(false)
        end
        guiSetInputMode("allow_binds")
        _G.isJobGuiOpen = false
    end
    jobSelectionElements = {}; jobConfirmElements = {}; currentJobsData = {}; currentConfirmJobKey = nil; currentConfirmJobDisplayName = ""; currentJobSkillLevel = 0; currentJobCompletedTotal = 0; currentJobNeededForNext = "N/A"
end

function cleanupJobElements()
    if isElement(currentJobCheckpointMarker) then destroyElement(currentJobCheckpointMarker); currentJobCheckpointMarker = nil; end
    if isElement(currentJobBlip) then destroyElement(currentJobBlip); currentJobBlip = nil; end
    if isElement(currentGarbageObject) then destroyElement(currentGarbageObject); currentGarbageObject = nil; end
end
addEvent("jobs:muellfahrer:jobCancelled", true)
addEventHandler("jobs:muellfahrer:jobCancelled", root, cleanupJobElements)

function updateCheckpoint(checkpointPos, currentNum, totalNum)
    cleanupJobElements()

    local garbageObjectID = 2672
    
    currentGarbageObject = createObject(garbageObjectID, checkpointPos.x, checkpointPos.y, checkpointPos.z - 0.5)
    if isElement(currentGarbageObject) then
        setElementDimension(currentGarbageObject, getElementDimension(localPlayer))
        setElementInterior(currentGarbageObject, getElementInterior(localPlayer))
        setObjectScale(currentGarbageObject, 1.5)
    end

    currentJobCheckpointMarker = createMarker(checkpointPos.x, checkpointPos.y, checkpointPos.z - 1, "cylinder", 4.0, 255, 200, 0, 0)
    currentJobBlip = createBlipAttachedTo(currentJobCheckpointMarker, 56, 2, 255, 200, 0, 255, 0, 99999.0)

    if isElement(currentJobCheckpointMarker) then
        setElementDimension(currentJobCheckpointMarker, getElementDimension(localPlayer))
        setElementInterior(currentJobCheckpointMarker, getElementInterior(localPlayer))
    end
    if isElement(currentJobBlip) then
        setElementDimension(currentJobBlip, getElementDimension(localPlayer))
        setElementInterior(currentJobBlip, getElementInterior(localPlayer))
    end
end
addEvent("jobs:muellfahrer:updateCheckpoint", true)
addEventHandler("jobs:muellfahrer:updateCheckpoint", root, updateCheckpoint)

addEventHandler("onClientMarkerHit", root, function(hitElement, matchingDimension)
    if hitElement == localPlayer and source == currentJobCheckpointMarker and matchingDimension then
        if isElement(currentGarbageObject) then
            destroyElement(currentGarbageObject)
            currentGarbageObject = nil
        end
        triggerServerEvent("jobs:muellfahrer:checkpointReached", localPlayer)
    end
end)

-- =================================================================
-- Ressourcen-Handling
-- =================================================================
addEventHandler("onClientResourceStop", resourceRoot, function()
    closeAllJobGUIs_DX()
    cleanupJobElements()
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    if _G.isJobGuiOpen == nil then _G.isJobGuiOpen = false end
end)