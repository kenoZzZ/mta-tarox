-- Tarox Fraktionsmanagement v1.2 by Tarox
-- last edited: 12.06.2025
-- FIX: Safeguard für 'fractions' Tabelle hinzugefügt & Abhängigkeiten geprüft.

local fractionRanks = {}

function loadFractionRanks()
    -- Safeguard: Stellt sicher, dass die globale 'fractions' Tabelle aus fractions_server.lua geladen ist.
    if not fractions or type(fractions) ~= "table" then
        outputDebugString("[Factions][Management] FATAL: Globale 'fractions' Tabelle nicht gefunden. Lade Skript ab. Stelle sicher, dass 'fractions_server.lua' in der meta.xml VOR diesem Skript geladen wird!")
        return
    end

	for i = 1, #fractions do
		fractionRanks[i] = {}
		-- Prüfen, ob die Datenbank-Ressource bereit ist
		if exports.datenbank and exports.datenbank.queryDatabase then
			local rankData, errMsg = exports.datenbank:queryDatabase("SELECT * FROM ranks WHERE fid=?", i)
			if rankData then
				for _, rank in ipairs(rankData) do
					fractionRanks[i][rank.rank] = rank.name
				end
			elseif errMsg then
				outputDebugString("[Factions][Management] DB-Fehler beim Laden der Ränge für FID " .. i .. ": " .. errMsg)
			end
		end
	end
end
loadFractionRanks()

function showFractionManagement(player)
	local isLeader, isCoLeader, isManager, fid, lvl, name = false, false, false, 0, 0, ""
	
	if _G.getPlayerFractionData then
		isLeader, isCoLeader, isManager, fid, lvl, name = _G.getPlayerFractionData(player)
	else
		outputDebugString("[Factions][Management] FATAL: _G.getPlayerFractionData nicht gefunden!")
		return
	end

	if isLeader or isCoLeader then
		local membersData = {}
		local members, errMsg = exports.datenbank:queryDatabase("SELECT account.username, account.last_seen, ranks.rank, ranks.name FROM account LEFT JOIN ranks ON account.fraktion = ranks.fid AND account.fraktion_rank = ranks.rank WHERE account.fraktion = ? ORDER BY ranks.rank DESC", fid)
		if members then
			for _, member in ipairs(members) do
				table.insert(membersData, {
					username = member.username,
					last_seen = member.last_seen,
					rank = member.rank,
					rank_name = member.name
				})
			end
		elseif errMsg then
			outputDebugString("[Factions][Management] DB-Fehler beim Laden der Mitgliederliste: " .. errMsg)
		end
		triggerClientEvent(player, "showFractionManagement", player, membersData, fractionRanks[fid], isLeader)
	end
end
addEvent("showFractionManagement", true)
addEventHandler("showFractionManagement", root, showFractionManagement)

function changePlayerRank(player, targetPlayerName, newRank)
	local isLeader, isCoLeader, isManager, fid, lvl, name = false, false, false, 0, 0, ""
	
	if _G.getPlayerFractionData then
		isLeader, isCoLeader, isManager, fid, lvl, name = _G.getPlayerFractionData(player)
	else
		outputDebugString("[Factions][Management] FATAL: _G.getPlayerFractionData nicht gefunden!")
		return
	end

	local targetPlayer = getPlayerFromName(targetPlayerName)
	if not targetPlayer then
		triggerClientEvent(player, "showMessage", player, "Spieler nicht online.", 255, 0, 0)
		return
	end
	
	if getPlayerTeam(player) ~= getPlayerTeam(targetPlayer) then
		return
	end
	
	if isLeader or isCoLeader then
		if tonumber(newRank) and fractionRanks[fid] and fractionRanks[fid][tonumber(newRank)] then
			if _G.setPlayerFraction and _G.getPlayerFractionAndRank and _G.isPlayerLeader then
				local _, targetLvl = _G.getPlayerFractionAndRank(targetPlayer)
				if (isLeader and lvl > targetLvl) or (isCoLeader and lvl > targetLvl and not _G.isPlayerLeader(targetPlayer)) then
					_G.setPlayerFraction(targetPlayer, fid, tonumber(newRank))
					triggerClientEvent(player, "showMessage", player, "Du hast den Rang von "..targetPlayerName.." erfolgreich geändert.", 0, 255, 0)
					triggerClientEvent(targetPlayer, "showMessage", targetPlayer, getPlayerName(player).." hat deinen Rang geändert.", 0, 255, 0)
					showFractionManagement(player) -- Refresh GUI
				else
					triggerClientEvent(player, "showMessage", player, "Dein Rang ist nicht hoch genug.", 255, 0, 0)
				end
			else
				outputDebugString("[Factions][Management] FATAL: _G.setPlayerFraction, _G.getPlayerFractionAndRank oder _G.isPlayerLeader nicht gefunden!")
			end
		end
	end
end
addEvent("changePlayerRank", true)
addEventHandler("changePlayerRank", root, changePlayerRank)

function removePlayerFromFraction(player, targetPlayerName)
	local isLeader, isCoLeader, isManager, fid, lvl, name = false, false, false, 0, 0, ""
	
	if _G.getPlayerFractionData then
		isLeader, isCoLeader, isManager, fid, lvl, name = _G.getPlayerFractionData(player)
	else
		outputDebugString("[Factions][Management] FATAL: _G.getPlayerFractionData nicht gefunden!")
		return
	end

	local targetPlayer = getPlayerFromName(targetPlayerName)
	if not targetPlayer then
		triggerClientEvent(player, "showMessage", player, "Spieler nicht online.", 255, 0, 0)
		return
	end
	
	if getPlayerTeam(player) ~= getPlayerTeam(targetPlayer) then
		return
	end

	if isLeader or isCoLeader then
		if _G.setPlayerFraction and _G.getPlayerFractionAndRank and _G.isPlayerLeader then
			local _, targetLvl = _G.getPlayerFractionAndRank(targetPlayer)
			if (isLeader and lvl > targetLvl) or (isCoLeader and lvl > targetLvl and not _G.isPlayerLeader(targetPlayer)) then
				_G.setPlayerFraction(targetPlayer, 0, 0)
				triggerClientEvent(player, "showMessage", player, "Du hast "..targetPlayerName.." erfolgreich aus der Fraktion entfernt.", 0, 255, 0)
				triggerClientEvent(targetPlayer, "showMessage", targetPlayer, getPlayerName(player).." hat dich aus der Fraktion entfernt.", 255, 0, 0)
				showFractionManagement(player) -- Refresh GUI
			else
				triggerClientEvent(player, "showMessage", player, "Dein Rang ist nicht hoch genug.", 255, 0, 0)
			end
		else
			outputDebugString("[Factions][Management] FATAL: _G.setPlayerFraction, _G.getPlayerFractionAndRank oder _G.isPlayerLeader nicht gefunden!")
		end
	end
end
addEvent("removePlayerFromFraction", true)
addEventHandler("removePlayerFromFraction", root, removePlayerFromFraction)

function invitePlayerToFraction(player, targetPlayerName)
    local isLeader, isCoLeader, isManager, fid, lvl, name = false, false, false, 0, 0, ""
	
	if _G.getPlayerFractionData then
		isLeader, isCoLeader, isManager, fid, lvl, name = _G.getPlayerFractionData(player)
	else
		outputDebugString("[Factions][Management] FATAL: _G.getPlayerFractionData nicht gefunden!")
		return
	end

    if not (isLeader or isCoLeader) then
        triggerClientEvent(player, "showMessage", player, "Du hast keine Berechtigung dazu.", 255, 0, 0)
        return
    end

    local targetPlayer = getPlayerFromName(targetPlayerName)
    if not targetPlayer then
        triggerClientEvent(player, "showMessage", player, "Spieler nicht online.", 255, 0, 0)
        return
    end

    if getElementData(targetPlayer, "fraktion") ~= 0 then
        triggerClientEvent(player, "showMessage", player, "Dieser Spieler ist bereits in einer Fraktion.", 255, 0, 0)
        return
    end

    if getElementData(targetPlayer, "fractionInvite") then
        triggerClientEvent(player, "showMessage", player, "Dieser Spieler hat bereits eine offene Einladung.", 255, 0, 0)
        return
    end

    local distance = getDistanceBetweenPoints3D(getElementPosition(player), getElementPosition(targetPlayer))
    if distance > 10 then
        triggerClientEvent(player, "showMessage", player, "Der Spieler ist zu weit entfernt.", 255, 0, 0)
        return
    end

    setElementData(targetPlayer, "fractionInvite", { inviter = player, fractionId = fid, fractionName = name })
    triggerClientEvent(player, "showMessage", player, "Du hast " .. targetPlayerName .. " in deine Fraktion eingeladen.", 0, 255, 0)
    triggerClientEvent(targetPlayer, "showFractionInvite", targetPlayer, getPlayerName(player), name)
end
addCommandHandler("invite", invitePlayerToFraction)
addCommandHandler("finvite", invitePlayerToFraction)


function acceptFractionInvite(player)
    local inviteData = getElementData(player, "fractionInvite")
    if not inviteData then
        return
    end

    local inviter = inviteData.inviter
    if not isElement(inviter) then
        triggerClientEvent(player, "showMessage", player, "Der einladende Spieler ist nicht mehr online.", 255, 0, 0)
        setElementData(player, "fractionInvite", nil)
        return
    end

	if _G.setPlayerFraction then
		_G.setPlayerFraction(player, inviteData.fractionId, 1) -- Rang 1 als Standard-Einsteiger-Rang
		setElementData(player, "fractionInvite", nil)
		triggerClientEvent(player, "showMessage", player, "Du bist der Fraktion " .. inviteData.fractionName .. " beigetreten.", 0, 255, 0)
		triggerClientEvent(inviter, "showMessage", inviter, getPlayerName(player) .. " hat die Einladung angenommen.", 0, 255, 0)
	else
		outputDebugString("[Factions][Management] FATAL: _G.setPlayerFraction nicht gefunden!")
		setElementData(player, "fractionInvite", nil)
	end
end
addEvent("acceptFractionInvite", true)
addEventHandler("acceptFractionInvite", root, acceptFractionInvite)

function declineFractionInvite(player)
    local inviteData = getElementData(player, "fractionInvite")
    if not inviteData then
        return
    end
    
    local inviter = inviteData.inviter
    if isElement(inviter) then
        triggerClientEvent(inviter, "showMessage", inviter, getPlayerName(player) .. " hat die Einladung abgelehnt.", 255, 100, 0)
    end
    
    setElementData(player, "fractionInvite", nil)
    triggerClientEvent(player, "showMessage", player, "Du hast die Einladung abgelehnt.", 255, 100, 0)
end
addEvent("declineFractionInvite", true)
addEventHandler("declineFractionInvite", root, declineFractionInvite)