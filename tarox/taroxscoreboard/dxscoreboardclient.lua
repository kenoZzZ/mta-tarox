--------------------------------------------------------------------------------
-- dxscoreboardclient.lua
-- ANGEPASSTE VERSION (Design inspiriert von Userpanel/Login)
-- V4: Laufen mit geöffnetem Scoreboard, OHNE Cursor
--------------------------------------------------------------------------------

local scoreboardShowing = false
local scoreboardData = {}

local scoreboardWidth = 700
local scoreboardHeight = 450

local screenCoreW, screenCoreH = guiGetScreenSize()

--------------------------------------------------------------------------------
local function formatMoney(amount)
    local formatted = tostring(math.floor(amount or 0))
    local k
    repeat
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1.%2')
    until k == 0
    return formatted
end

--------------------------------------------------------------------------------
local function getFlagPath(origin)
    return "taroxscoreboard/flags/" .. (origin or "xx") .. ".png"
end

--------------------------------------------------------------------------------
local colors = {
    BACKGROUND = tocolor(28, 30, 36, 230),
    TITLE_BAR = tocolor(38, 40, 48, 245),
    HEADER_TEXT = tocolor(235, 235, 240, 255),
    ROW_TEXT_NORMAL = tocolor(210, 215, 225, 255),
    ROW_TEXT_DIMMED = tocolor(170, 175, 185, 230),
    COLUMN_HEADER_BG = tocolor(45, 48, 56, 240),
    GROUP_HEADER_BG = tocolor(42, 45, 53, 235),
    BORDER_LIGHT = tocolor(55, 58, 68, 180),
    BORDER_DARK = tocolor(20, 22, 28, 220),
    RANK = tocolor(100, 150, 255, 255),
    MONEY = tocolor(90, 210, 140, 255),
    PLAYTIME = tocolor(230, 190, 90, 255),
    WANTED_NORMAL = tocolor(255, 180, 90, 255),
    WANTED_HIGH_1 = tocolor(200, 70, 70, 255),
    WANTED_HIGH_2 = tocolor(255, 100, 100, 255),
    PING = tocolor(170, 175, 185, 255),
    Civil = tocolor(210, 215, 225, 255),
    Medic = tocolor(70, 210, 70, 255),          --
    Police = tocolor(100, 150, 255, 255),       --
    Swat = tocolor(60, 60, 70, 255),            --
    Yakuza = tocolor(200, 70, 70, 255),         --
    ["Mocro Mafia"] = tocolor(160, 90, 160, 255), --
    ["Cosa Nostra"] = tocolor(255, 150, 50, 255), --
    Mechanic = tocolor(0, 100, 200, 255) -- NEUER EINTRAG
}

--------------------------------------------------------------------------------
local layout = {
    PADDING = 15,
    TITLE_BAR_HEIGHT = 40,
    COLUMN_HEADER_HEIGHT = 28,
    GROUP_HEADER_HEIGHT = 25,
    ROW_HEIGHT = 26,
    ICON_SIZE_HEADER = 16,
    ICON_SIZE_ROW = 14,
    ICON_PADDING = 5,
}

--------------------------------------------------------------------------------
local standardGroups = { "Civil", "Medic", "Police", "Swat", "Yakuza", "Mocro Mafia", "Cosa Nostra" }

--------------------------------------------------------------------------------
local columns = {
    { title = "Name",     widthPerc = 0.22, icon = "user/client/images/usericons/user_icon.png" },
    { title = "Rank",     widthPerc = 0.15, icon = nil },
    { title = "Money",    widthPerc = 0.15, icon = "user/client/images/usericons/money.png" },
    { title = "Playtime", widthPerc = 0.15, icon = "user/client/images/usericons/playtime.png" },
    { title = "Wanted",   widthPerc = 0.10, icon = "user/client/images/usericons/wanted.png" },
    { title = "Country",  widthPerc = 0.08, icon = nil },
    { title = "Ping",     widthPerc = 0.15, icon = nil },
}

--------------------------------------------------------------------------------
local fonts = {
    TITLE = { font = "default-bold", scale = 1.3 },
    COLUMN_HEADER = { font = "default-bold", scale = 1.0 },
    GROUP_HEADER = { font = "default-bold", scale = 1.05 },
    ROW_PLAYER_NAME = { font = "default-bold", scale = 1.05 },
    ROW_DATA = { font = "default", scale = 1.0 }
}

--------------------------------------------------------------------------------
local function getColumnPositions(startX, currentScoreboardWidth)
    local positions = {}
    local currentX = startX + layout.PADDING
    local availableWidth = currentScoreboardWidth - (layout.PADDING * 2)
    for i, col in ipairs(columns) do
        local colWidth = availableWidth * col.widthPerc
        positions[i] = { x = currentX, width = colWidth }
        currentX = currentX + colWidth
    end
    return positions
end

--------------------------------------------------------------------------------
function updateScoreboardData(data)
    scoreboardData = data or {}
end
addEvent("updateScoreboardDataClient", true)
addEventHandler("updateScoreboardDataClient", root, updateScoreboardData)

--------------------------------------------------------------------------------
local function renderScoreboard()
    if not scoreboardShowing then return end

    local sWidth, sHeight = guiGetScreenSize()
    local sbX = (sWidth - scoreboardWidth) / 2
    local sbY = (sHeight - scoreboardHeight) / 2

    dxDrawRectangle(sbX, sbY, scoreboardWidth, scoreboardHeight, colors.BACKGROUND)
    dxDrawLine(sbX, sbY, sbX + scoreboardWidth, sbY, colors.BORDER_LIGHT, 2)
    dxDrawLine(sbX, sbY + scoreboardHeight, sbX + scoreboardWidth, sbY + scoreboardHeight, colors.BORDER_DARK, 2)
    dxDrawLine(sbX, sbY, sbX, sbY + scoreboardHeight, colors.BORDER_LIGHT, 2)
    dxDrawLine(sbX + scoreboardWidth, sbY, sbX + scoreboardWidth, sbY + scoreboardHeight, colors.BORDER_DARK, 2)

    dxDrawRectangle(sbX, sbY, scoreboardWidth, layout.TITLE_BAR_HEIGHT, colors.TITLE_BAR)
    dxDrawText("Scoreboard", sbX, sbY, sbX + scoreboardWidth, sbY + layout.TITLE_BAR_HEIGHT,
        colors.HEADER_TEXT, fonts.TITLE.scale, fonts.TITLE.font, "center", "center")
    dxDrawLine(sbX, sbY + layout.TITLE_BAR_HEIGHT, sbX + scoreboardWidth, sbY + layout.TITLE_BAR_HEIGHT, colors.BORDER_DARK, 1)

    local colHeaderY = sbY + layout.TITLE_BAR_HEIGHT + layout.PADDING / 2
    dxDrawRectangle(sbX + layout.PADDING, colHeaderY, scoreboardWidth - layout.PADDING * 2, layout.COLUMN_HEADER_HEIGHT, colors.COLUMN_HEADER_BG)

    local colPositions = getColumnPositions(sbX, scoreboardWidth)
    for i, col in ipairs(columns) do
        local textX = colPositions[i].x
        local textW = colPositions[i].width
        local alignH = "center"
        local actualText = col.title
        local iconOffsetX = 0

        if col.icon and fileExists(col.icon) then
            local iconDrawY = colHeaderY + (layout.COLUMN_HEADER_HEIGHT - layout.ICON_SIZE_HEADER) / 2
            local textWidth = dxGetTextWidth(actualText, fonts.COLUMN_HEADER.scale, fonts.COLUMN_HEADER.font)
            local totalContentWidth = layout.ICON_SIZE_HEADER + layout.ICON_PADDING + textWidth
            local startContentX = textX + (textW - totalContentWidth) / 2

            dxDrawImage(startContentX, iconDrawY, layout.ICON_SIZE_HEADER, layout.ICON_SIZE_HEADER, col.icon, 0, 0, 0, tocolor(255,255,255,220))
            textX = startContentX + layout.ICON_SIZE_HEADER + layout.ICON_PADDING
            alignH = "left"
        else
             if col.title == "Name" then alignH = "left"; textX = textX + layout.ICON_PADDING end
        end
        
        local textColorToUse = colors.HEADER_TEXT
        if col.title == "Rank" then textColorToUse = colors.RANK
        elseif col.title == "Money" then textColorToUse = colors.MONEY
        elseif col.title == "Playtime" then textColorToUse = colors.PLAYTIME
        elseif col.title == "Wanted" then textColorToUse = colors.WANTED_NORMAL
        end

        dxDrawText(actualText, textX, colHeaderY, textX + textW - iconOffsetX - (alignH=="left" and layout.ICON_PADDING or 0), colHeaderY + layout.COLUMN_HEADER_HEIGHT,
            textColorToUse, fonts.COLUMN_HEADER.scale, fonts.COLUMN_HEADER.font, alignH, "center", (alignH=="left" and false or true))
    end
    dxDrawLine(sbX + layout.PADDING, colHeaderY + layout.COLUMN_HEADER_HEIGHT, sbX + scoreboardWidth - layout.PADDING, colHeaderY + layout.COLUMN_HEADER_HEIGHT, colors.BORDER_LIGHT, 1)

    local currentY = colHeaderY + layout.COLUMN_HEADER_HEIGHT + layout.PADDING

    local function drawPlayerRow(info, groupColor)
        if currentY + layout.ROW_HEIGHT > sbY + scoreboardHeight - layout.PADDING then return false end

        dxDrawText(info.name, colPositions[1].x + layout.ICON_PADDING, currentY,
            colPositions[1].x + colPositions[1].width - layout.ICON_PADDING, currentY + layout.ROW_HEIGHT,
            groupColor or colors.ROW_TEXT_NORMAL, fonts.ROW_PLAYER_NAME.scale, fonts.ROW_PLAYER_NAME.font, "left", "center", true)

        dxDrawText(info.rank, colPositions[2].x, currentY,
            colPositions[2].x + colPositions[2].width, currentY + layout.ROW_HEIGHT,
            colors.RANK, fonts.ROW_DATA.scale, fonts.ROW_DATA.font, "center", "center")

        dxDrawText("$" .. formatMoney(info.money), colPositions[3].x, currentY,
            colPositions[3].x + colPositions[3].width, currentY + layout.ROW_HEIGHT,
            colors.MONEY, fonts.ROW_DATA.scale, fonts.ROW_DATA.font, "center", "center")

        dxDrawText(info.playtime, colPositions[4].x, currentY,
            colPositions[4].x + colPositions[4].width, currentY + layout.ROW_HEIGHT,
            colors.PLAYTIME, fonts.ROW_DATA.scale, fonts.ROW_DATA.font, "center", "center")

        local wantedValue = tonumber(info.wanted) or 0
        local wantedColor = colors.ROW_TEXT_DIMMED
        if wantedValue > 0 then
            if wantedValue >= 50 then
                wantedColor = (math.floor(getTickCount() / 500) % 2 == 0) and colors.WANTED_HIGH_1 or colors.WANTED_HIGH_2
            else
                wantedColor = colors.WANTED_NORMAL
            end
        end
        dxDrawText(tostring(wantedValue), colPositions[5].x, currentY,
            colPositions[5].x + colPositions[5].width, currentY + layout.ROW_HEIGHT,
            wantedColor, fonts.ROW_DATA.scale, fonts.ROW_DATA.font, "center", "center")

        local originCode = info.origin or ""
        local flagFile = getFlagPath(originCode)
        local flagX = colPositions[6].x + (colPositions[6].width - layout.ICON_SIZE_ROW) / 2
        if fileExists(flagFile) then
            dxDrawImage(flagX, currentY + (layout.ROW_HEIGHT - layout.ICON_SIZE_ROW*0.75) / 2, layout.ICON_SIZE_ROW, layout.ICON_SIZE_ROW*0.75, flagFile)
        else
            dxDrawText(originCode, colPositions[6].x, currentY, colPositions[6].x + colPositions[6].width, currentY + layout.ROW_HEIGHT, colors.ROW_TEXT_DIMMED, fonts.ROW_DATA.scale, fonts.ROW_DATA.font, "center", "center")
        end

        dxDrawText(info.ping, colPositions[7].x, currentY,
            colPositions[7].x + colPositions[7].width, currentY + layout.ROW_HEIGHT,
            colors.PING, fonts.ROW_DATA.scale, fonts.ROW_DATA.font, "center", "center")

        currentY = currentY + layout.ROW_HEIGHT
        return true
    end

    local allGroupsSorted = {}
    if type(scoreboardData) == "table" then
        for groupName, _ in pairs(scoreboardData) do
            table.insert(allGroupsSorted, groupName)
        end
    end
    table.sort(allGroupsSorted, function(a,b)
        local indexA = 99; local indexB = 99
        for i, stdGroup in ipairs(standardGroups) do
            if a == stdGroup then indexA = i end
            if b == stdGroup then indexB = i end
        end
        if indexA ~= indexB then return indexA < indexB end
        return a < b
    end)

    for _, groupName in ipairs(allGroupsSorted) do
        local playersInGroup = scoreboardData[groupName]
        if playersInGroup and #playersInGroup > 0 then
            if currentY + layout.GROUP_HEADER_HEIGHT + layout.PADDING/2 > sbY + scoreboardHeight - layout.PADDING then break end

            local groupTitleText = groupName .. " (" .. #playersInGroup .. ")"
            local groupHeaderColor = colors[groupName] or colors.HEADER_TEXT

            dxDrawRectangle(sbX + layout.PADDING, currentY, scoreboardWidth - layout.PADDING*2, layout.GROUP_HEADER_HEIGHT, colors.GROUP_HEADER_BG)
            dxDrawText(groupTitleText, sbX + layout.PADDING + layout.ICON_PADDING, currentY,
                sbX + scoreboardWidth - layout.PADDING, currentY + layout.GROUP_HEADER_HEIGHT,
                groupHeaderColor, fonts.GROUP_HEADER.scale, fonts.GROUP_HEADER.font, "left", "center")
            dxDrawLine(sbX + layout.PADDING, currentY + layout.GROUP_HEADER_HEIGHT, sbX + scoreboardWidth - layout.PADDING, currentY + layout.GROUP_HEADER_HEIGHT, colors.BORDER_LIGHT, 1)
            currentY = currentY + layout.GROUP_HEADER_HEIGHT + layout.PADDING / 3

            table.sort(playersInGroup, function(a,b) return (a.name or "") < (b.name or "") end)
            for _, playerData in ipairs(playersInGroup) do
                if not drawPlayerRow(playerData, colors[groupName] or colors.ROW_TEXT_NORMAL) then
                    break
                end
            end
            currentY = currentY + layout.PADDING / 2
        end
    end
end

--------------------------------------------------------------------------------
local function toggleScoreboard(key, state)
    if not getElementData(localPlayer, "account_id") then
        if scoreboardShowing then
            scoreboardShowing = false
            removeEventHandler("onClientRender", root, renderScoreboard)
            showCursor(false)
            guiSetInputMode("allow_binds")
        end
        return
    end

    if state == "down" then
        if not scoreboardShowing then
            scoreboardShowing = true
            triggerServerEvent("requestScoreboardRefresh", resourceRoot)
            addEventHandler("onClientRender", root, renderScoreboard)
            showCursor(false) -- << ÄNDERUNG HIER: Cursor nicht anzeigen
            guiSetInputMode("allow_binds")
        end
    else -- state == "up"
        if scoreboardShowing then
            scoreboardShowing = false
            removeEventHandler("onClientRender", root, renderScoreboard)
            showCursor(false) -- Cursor bleibt aus
            guiSetInputMode("allow_binds")
        end
    end
end
bindKey("tab", "both", toggleScoreboard)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if scoreboardShowing then
        removeEventHandler("onClientRender", root, renderScoreboard)
        showCursor(false)
        guiSetInputMode("allow_binds")
        scoreboardShowing = false
    end
    unbindKey("tab", "both", toggleScoreboard)
end)

-- outputChatBox("INFO: Angepasstes Scoreboard-Design V4 (Laufen ohne Cursor) geladen. Drücke TAB.", 200,200,0)
