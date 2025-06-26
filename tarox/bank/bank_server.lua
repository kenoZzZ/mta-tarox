-- tarox/bank/bank_server.lua
-- VERSION 1.1: Mit ATM-Erstellung und Fehlerbehandlung

local atmModelID = 2942
local atmCoordinates = {
    -- x, y, z, rx, ry, rz
    {2052.1999511719,-1897.5999755859,13.199999809265,0,0,0},
    {1688.3000488281,-1582.9000244141,13.199999809265, 0, 0, 0},
    {1469.0999755859,-1772.3000488281,18.39999961853,0, 0, 180},
    {1082.0999755859, -1562.6999511719,13.199999809265,0, 0, 0},
    {1060.9000244141, -1131.1999511719, 23.5, 0, 0, 0},
    {1467.8000488281, -1054.5999755859, 23.5, 0, 0, 90},
    {2130.1000976562,-1151.3000488281,23.60000038147,0,0,180},
    {2864.8999023438, -1468.1999511719, 10.60000038147, 0, 0, 90},
    {1940, -2113, 13.300000190735, 0, 0, 90},
    {1104.0999755859, -1271.1999511719, 13.199999809265, 0, 0, 0},
    {-1642.0999755859, 1207.8000488281, 6.8000001907349, 0, 0, 135},
    {-2622.8000488281, 1413.0999755859, 6.6999998092651, 0, 0, 15.5},
    {-2767.8000488281, 790.20001220703, 52.400001525879, 0, 0, 90},
    {-2420.1000976562, 971.59997558594, 44.900001525879, 0, 0, 90},
    {-2446.8000488281, 752.59997558594, 34.799999237061, 0, 0, 0},
    {-2730.13599, 424.91724, 3.95, 0, 0, 0},
    {-2430.6999511719, -45.39165, 34.900001525879, 0, 0, 90},
    {-2172.3999023438, 254.80000305176, 35, 0, 0, 90},
    {-1980.5999755859, 131.10000610352, 27.299999237061, 0, 0, 270},
    {-1677, 431.29998779297, 6.8000001907349, 0, 0, 45}
}

local createdATMs = {}

local function getPlayerCurrentMoney(player)
    if not isElement(player) then return 0, 0 end
    local accID = getElementData(player, "account_id")
    if not accID then return 0, 0 end

    local moneyResult, errMsg = exports.datenbank:queryDatabase("SELECT money, bank_money FROM money WHERE account_id=?", accID)
    if not moneyResult then
        outputDebugString("[BankServer] DB Fehler beim Laden des Geldes für AccID " .. accID .. ": " .. (errMsg or "Unbekannt"))
        return 0, 0 
    end

    if moneyResult and moneyResult[1] then
        return tonumber(moneyResult[1].money) or 0, tonumber(moneyResult[1].bank_money) or 0
    else
        return 0, 0
    end
end

local function updatePlayerMoneyInDB(player, newCash, newBankMoney)
    if not isElement(player) then return false end
    local accID = getElementData(player, "account_id")
    if not accID then return false end

    newCash = math.max(0, tonumber(newCash) or 0) 
    newBankMoney = math.max(0, tonumber(newBankMoney) or 0)

    local success, errMsg = exports.datenbank:executeDatabase("UPDATE money SET money=?, bank_money=? WHERE account_id=?", newCash, newBankMoney, accID)
    if not success then
        outputDebugString("[BankServer] DB Fehler beim Speichern des Geldes für AccID " .. accID .. ": " .. (errMsg or "Unbekannt"))
        return false
    end
    
    setPlayerMoney(player, newCash) 
    setElementData(player, "bank_money", newBankMoney) 

    return true
end

function createATMMachines()
    destroyATMMachines() -- Zuerst alte ATMs entfernen, falls vorhanden
    for i, atmData in ipairs(atmCoordinates) do
        local atm = createObject(atmModelID, atmData[1], atmData[2], atmData[3], atmData[4], atmData[5], atmData[6])
        if isElement(atm) then
            setElementFrozen(atm, true)
            setElementData(atm, "isBankInteractionObject", true, true) 
            setElementData(atm, "interactionType", "atm", true)     
            table.insert(createdATMs, atm)
        else
            outputDebugString("[BankServer] FEHLER: Konnte ATM #" .. i .. " nicht erstellen.")
        end
    end
    --outputDebugString("[BankServer] " .. #createdATMs .. " Geldautomaten erstellt.")
end

function destroyATMMachines()
    for i, atm in ipairs(createdATMs) do
        if isElement(atm) then
            destroyElement(atm)
        end
    end
    createdATMs = {}
    -- outputDebugString("[BankServer] Alle Geldautomaten entfernt.") -- Optional, kann beim normalen Stop der Ressource geschehen
end

addEvent("bank:requestBalance", true)
addEventHandler("bank:requestBalance", root, function()
    local player = client
    if not isElement(player) then return end
    local cash, bank = getPlayerCurrentMoney(player)
    triggerClientEvent(player, "bank:updateBalance", player, cash, bank)
end)

addEvent("bank:depositMoney", true)
addEventHandler("bank:depositMoney", root, function(amount)
    local player = client
    if not isElement(player) then return end
    amount = tonumber(amount)
    if not amount or amount <= 0 or amount > 2000000000 then 
        triggerClientEvent(player, "bank:transactionFeedback", player, "Ungültiger Betrag.", true)
        return
    end

    local cash, bank = getPlayerCurrentMoney(player)
    if cash < amount then
        triggerClientEvent(player, "bank:transactionFeedback", player, "Du hast nicht genug Bargeld zum Einzahlen.", true)
        return
    end

    local newCash = cash - amount
    local newBankMoney = bank + amount

    if updatePlayerMoneyInDB(player, newCash, newBankMoney) then
        triggerClientEvent(player, "bank:transactionFeedback", player, "Erfolgreich $" .. amount .. " eingezahlt.", false)
        triggerClientEvent(player, "bank:updateBalance", player, newCash, newBankMoney)
        outputServerLog(getPlayerName(player) .. " hat $" .. amount .. " eingezahlt. Neu: Cash $" .. newCash .. ", Bank $" .. newBankMoney)
    else
        triggerClientEvent(player, "bank:transactionFeedback", player, "Fehler bei der Transaktion (DB).", true)
    end
end)

addEvent("bank:withdrawMoney", true)
addEventHandler("bank:withdrawMoney", root, function(amount)
    local player = client
    if not isElement(player) then return end
    amount = tonumber(amount)
    if not amount or amount <= 0 or amount > 2000000000 then 
        triggerClientEvent(player, "bank:transactionFeedback", player, "Ungültiger Betrag.", true)
        return
    end

    local cash, bank = getPlayerCurrentMoney(player)
    if bank < amount then
        triggerClientEvent(player, "bank:transactionFeedback", player, "Du hast nicht genug Guthaben auf der Bank.", true)
        return
    end

    local newCash = cash + amount
    local newBankMoney = bank - amount

    if updatePlayerMoneyInDB(player, newCash, newBankMoney) then
        triggerClientEvent(player, "bank:transactionFeedback", player, "Erfolgreich $" .. amount .. " ausgezahlt.", false)
        triggerClientEvent(player, "bank:updateBalance", player, newCash, newBankMoney)
        outputServerLog(getPlayerName(player) .. " hat $" .. amount .. " ausgezahlt. Neu: Cash $" .. newCash .. ", Bank $" .. newBankMoney)
    else
        triggerClientEvent(player, "bank:transactionFeedback", player, "Fehler bei der Transaktion (DB).", true)
    end
end)

addEventHandler("onResourceStart", resourceRoot, function()
    createATMMachines() 
    --outputDebugString("[BankServer] Bank-System Server (V1.1 mit ATMs) geladen.")
end)

addEventHandler("onResourceStop", resourceRoot, function()
    destroyATMMachines() 
    --outputDebugString("[BankServer] Bank-System Server gestoppt, ATMs entfernt.")
end)