-------------------------------------------
-- management_client.lua (Client-Side)
-------------------------------------------
local isManagementVisible = false
local fractionID = 0
local fractionName = "Civil"

local screenW, screenH = guiGetScreenSize()

-- Panel vom Server => öffnen
addEvent("managementShowPanel", true)
addEventHandler("managementShowPanel", root, function(fid, fname)
    if isManagementVisible then return end
    fractionID = fid
    fractionName = fname
    isManagementVisible = true
    showCursor(true)
    addEventHandler("onClientRender", root, renderManagementPanel)
end)

function closeManagementPanel()
    isManagementVisible = false
    showCursor(false)
    removeEventHandler("onClientRender", root, renderManagementPanel)
end

-- Eingabefelder
local inviteName = ""
local rankTargetName = ""
local rankTargetLevel = ""
local kickName = ""

local activeField = nil

function renderManagementPanel()
    if not isManagementVisible then return end

    local w,h = 420, 300
    local x = (screenW - w)/2
    local y = (screenH - h)/2

    dxDrawRectangle(x, y, w, h, tocolor(25,25,25,200))
    dxDrawText("Management - "..fractionName, x, y+5, x+w, y+30, tocolor(255,255,255), 1.3, "default-bold","center","top")

    local lineY = y+40
    -- Invite
    dxDrawText("Invite Player:", x+10, lineY, x+200, lineY+20, tocolor(255,255,255), 1.1, "default-bold", "left")
    dxDrawRectangle(x+120, lineY, 150, 20, tocolor(60,60,60,200))
    dxDrawText(inviteName .. (activeField=="inviteName" and "_" or ""), x+122, lineY, x+270, lineY+20, tocolor(255,255,255), 1, "default", "left","center") -- Cursor hinzugefügt
    dxDrawRectangle(x+280, lineY, 80, 20, tocolor(0,120,200,200))
    dxDrawText("Invite", x+280, lineY, x+360, lineY+20, tocolor(255,255,255),1,"default-bold","center","center")

    lineY = lineY + 40
    -- SetRank
    dxDrawText("Set Rank:", x+10, lineY, x+200, lineY+20, tocolor(255,255,255), 1.1,"default-bold","left")
    dxDrawRectangle(x+120, lineY, 150, 20, tocolor(60,60,60,200))
    dxDrawText(rankTargetName .. (activeField=="rankTargetName" and "_" or ""), x+122, lineY, x+270, lineY+20, tocolor(255,255,255),1,"default","left","center") -- Cursor

    dxDrawRectangle(x+280, lineY, 40, 20, tocolor(60,60,60,200))
    dxDrawText(rankTargetLevel .. (activeField=="rankTargetLevel" and "_" or ""), x+282, lineY, x+320, lineY+20, tocolor(255,255,255),1,"default","left","center") -- Cursor

    dxDrawRectangle(x+330, lineY, 60, 20, tocolor(0,200,120,200))
    dxDrawText("OK", x+330, lineY, x+390, lineY+20, tocolor(255,255,255),1,"default-bold","center","center")

    lineY = lineY + 40
    -- Kick
    dxDrawText("Kick Player:", x+10, lineY, x+200, lineY+20, tocolor(255,255,255), 1.1,"default-bold","left")
    dxDrawRectangle(x+120, lineY, 150, 20, tocolor(60,60,60,200))
    dxDrawText(kickName .. (activeField=="kickName" and "_" or ""), x+122, lineY, x+270, lineY+20, tocolor(255,255,255),1,"default","left","center") -- Cursor
    dxDrawRectangle(x+280, lineY, 80, 20, tocolor(200,0,0,200))
    dxDrawText("Kick", x+280, lineY, x+360, lineY+20, tocolor(255,255,255),1,"default-bold","center","center")

    -- Close
    dxDrawRectangle(x+10, y+h-35, w-20, 30, tocolor(200,0,0,200))
    dxDrawText("Close", x+10, y+h-35, x+w-10, y+h-5, tocolor(255,255,255),1.2,"default-bold","center","center")
end

addEventHandler("onClientClick", root, function(btn, state, cx, cy)
    if not isManagementVisible or btn~="left" or state~="up" then return end

    local w,h = 420, 300
    local x = (screenW - w)/2
    local y = (screenH - h)/2

    local lineY = y+40
    local fieldH = 20
    local buttonH = 20 -- Höhe der Aktionsbuttons

    -- Klick auf Input-Felder
    if cx>=x+120 and cx<=x+270 and cy>=lineY and cy<=lineY+fieldH then activeField="inviteName"; return end
    lineY=lineY+40
    if cx>=x+120 and cx<=x+270 and cy>=lineY and cy<=lineY+fieldH then activeField="rankTargetName"; return end
    if cx>=x+280 and cx<=x+320 and cy>=lineY and cy<=lineY+fieldH then activeField="rankTargetLevel"; return end
    lineY=lineY+40
    if cx>=x+120 and cx<=x+270 and cy>=lineY and cy<=lineY+fieldH then activeField="kickName"; return end

    -- Klick auf Aktions-Buttons
    lineY = y+40 -- Zurücksetzen für Button-Prüfung
    -- Invite Button
    if cx>=x+280 and cx<=x+360 and cy>=lineY and cy<=lineY+buttonH then
        if inviteName~="" then
            triggerServerEvent("onManagementInvitePlayer", localPlayer, fractionID, inviteName)
            inviteName = "" -- Feld leeren nach Aktion
        else
            outputChatBox("Bitte Namen eingeben!")
        end
        activeField=nil; return
    end

    lineY=lineY+40
    -- SetRank OK Button
    if cx>=x+330 and cx<=x+390 and cy>=lineY and cy<=lineY+buttonH then
        if rankTargetName~="" and rankTargetLevel~="" then
            triggerServerEvent("onManagementSetRank", localPlayer, fractionID, rankTargetName, rankTargetLevel)
            rankTargetName = ""; rankTargetLevel = "" -- Felder leeren
        else
            outputChatBox("Bitte Name und Rank-Level eingeben!")
        end
        activeField=nil; return
    end

    lineY=lineY+40
    -- Kick Button
    if cx>=x+280 and cx<=x+360 and cy>=lineY and cy<=lineY+buttonH then
        if kickName~="" then
            triggerServerEvent("onManagementKickPlayer", localPlayer, fractionID, kickName)
            kickName = "" -- Feld leeren
        else
            outputChatBox("Bitte Name eingeben!")
        end
        activeField=nil; return
    end

    -- Close Button
    if cx>=x+10 and cx<=x+w-10 and cy>=y+h-35 and cy<=y+h-5 then -- Korrigierte Breite
        closeManagementPanel()
        activeField=nil; return
    end

    -- Wenn nirgendwo relevant hingeklickt wurde, deaktiviere das Feld
    activeField=nil
end)


addEventHandler("onClientCharacter", root, function(c)
    if not isManagementVisible or not activeField then return end

    -- Erlaube nur Zahlen für Rank-Level
    if activeField == "rankTargetLevel" and not tonumber(c) then
         return -- Ignoriere nicht-numerische Eingabe für Rank
    end

    if activeField=="inviteName" then
        inviteName=inviteName..c
    elseif activeField=="rankTargetName" then
        rankTargetName=rankTargetName..c
    elseif activeField=="rankTargetLevel" then
        -- Begrenze Rank Level auf 1-5 (oder was auch immer max ist)
        local newRank = tonumber(rankTargetLevel .. c)
        if newRank and newRank >= 1 and newRank <= 5 then
             rankTargetLevel=rankTargetLevel..c
        end
    elseif activeField=="kickName" then
        kickName=kickName..c
    end
end)

addEventHandler("onClientKey", root, function(key,press)
    if not press or key~="backspace" or not isManagementVisible or not activeField then return end

    local function backspace(str)
        if #str>0 then
            return str:sub(1,#str-1)
        end
        return str
    end

    if activeField=="inviteName" then
        inviteName=backspace(inviteName)
    elseif activeField=="rankTargetName" then
        rankTargetName=backspace(rankTargetName)
    elseif activeField=="rankTargetLevel" then
        rankTargetLevel=backspace(rankTargetLevel)
    elseif activeField=="kickName" then
        kickName=backspace(kickName)
    end
end)

-- Aufräumen
addEventHandler("onClientResourceStop", resourceRoot, function()
     if isManagementVisible then
          closeManagementPanel()
     end
end)