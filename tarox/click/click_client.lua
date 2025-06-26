-- tarox/click/click_client.lua
_G.isCursorManuallyShownByClickSystem = false

-- Initialisiere globale GUI-Statusvariablen, falls sie noch nicht existieren
if _G.isPedGuiOpen == nil then _G.isPedGuiOpen = false end
if _G.isInventoryVisible == nil then _G.isInventoryVisible = false end
if _G.isDriveMenuVisible == nil then _G.isDriveMenuVisible = false end
if _G.isTheoryTestVisible == nil then _G.isTheoryTestVisible = false end
if _G.isConfirmPracticalVisible == nil then _G.isConfirmPracticalVisible = false end
if _G.idPurchaseConfirmVisible == nil then _G.idPurchaseConfirmVisible = false end
if _G.idCardGuiVisible == nil then _G.idCardGuiVisible = false end
if _G.isHandyGUIVisible == nil then _G.isHandyGUIVisible = false end
if _G.isMessageGUIOpen == nil then _G.isMessageGUIOpen = false end
if _G.isBankGUIVisible == nil then _G.isBankGUIVisible = false end
if _G.isMechanicWindowVisible == nil then _G.isMechanicWindowVisible = false end
if _G.isMechanicOfferGuiVisible == nil then _G.isMechanicOfferGuiVisible = false end
if _G.isRepairConfirmVisible == nil then _G.isRepairConfirmVisible = false end
if _G.isRepairMenuVisible == nil then _G.isRepairMenuVisible = false end
if _G.isTuneMenuVisible == nil then _G.isTuneMenuVisible = false end
if _G.isPolicePanelVisible == nil then _G.isPolicePanelVisible = false end
if _G.isWantedPlayersGUIVisible == nil then _G.isWantedPlayersGUIVisible = false end
if _G.isMedicWindowVisible == nil then _G.isMedicWindowVisible = false end
if _G.isPatientListVisible == nil then _G.isPatientListVisible = false end
if _G.isYakuzaWindowVisible == nil then _G.isYakuzaWindowVisible = false end
if _G.isMocroWindowVisible == nil then _G.isMocroWindowVisible = false end
if _G.isCosaWindowVisible == nil then _G.isCosaWindowVisible = false end
if _G.isManagementVisible == nil then _G.isManagementVisible = false end
if _G.isJuwelierGUIVisible == nil then _G.isJuwelierGUIVisible = false end
if _G.isClothesMenuOpen == nil then _G.isClothesMenuOpen = false end
if _G.isFuelWindowVisible == nil then _G.isFuelWindowVisible = false end
if _G.isCarShopVisible == nil then _G.isCarShopVisible = false end
if _G.isSpawnWindowVisible == nil then _G.isSpawnWindowVisible = false end
if _G.isBankRobConfirmWindowActive == nil then _G.isBankRobConfirmWindowActive = false end
if _G.isCasinoRobConfirmWindowActive == nil then _G.isCasinoRobConfirmWindowActive = false end
if _G.isDeathScreenActive == nil then _G.isDeathScreenActive = false end
if _G.isLoginVisible == nil then _G.isLoginVisible = false end
if _G.isRegisterVisible == nil then _G.isRegisterVisible = false end
if _G.isUserPanelVisible == nil then _G.isUserPanelVisible = false end
if _G.isJailDoorBreakUIVisible == nil then _G.isJailDoorBreakUIVisible = false end
if _G.isJailHackSystemUIVisible == nil then _G.isJailHackSystemUIVisible = false end
if _G.isJobGuiOpen == nil then _G.isJobGuiOpen = false end
if _G.isDrugSellGUIVisible == nil then _G.isDrugSellGUIVisible = false end
if _G.isDrugSeedBuyGUIVisible == nil then _G.isDrugSeedBuyGUIVisible = false end -- NEU

function toggleManualCursor()
    local chatActive = isChatBoxInputActive()
    local consoleActive = isConsoleActive()
    local mainMenuOpen = isMainMenuActive()

    local anyCustomGuiActive = _G.isPedGuiOpen or _G.isInventoryVisible or _G.isDriveMenuVisible or
                               _G.isTheoryTestVisible or _G.isConfirmPracticalVisible or _G.idPurchaseConfirmVisible or
                               _G.idCardGuiVisible or _G.isHandyGUIVisible or _G.isMessageGUIOpen or _G.isBankGUIVisible or
                               _G.isMechanicWindowVisible or _G.isMechanicOfferGuiVisible or _G.isRepairConfirmVisible or
                               _G.isRepairMenuVisible or _G.isTuneMenuVisible or _G.isPolicePanelVisible or
                               _G.isWantedPlayersGUIVisible or _G.isMedicWindowVisible or _G.isPatientListVisible or
                               _G.isYakuzaWindowVisible or _G.isMocroWindowVisible or _G.isCosaWindowVisible or
                               _G.isManagementVisible or _G.isJuwelierGUIVisible or _G.isClothesMenuOpen or
                               _G.isFuelWindowVisible or _G.isCarShopVisible or _G.isSpawnWindowVisible or
                               _G.isBankRobConfirmWindowActive or _G.isCasinoRobConfirmWindowActive or
                               _G.isDeathScreenActive or _G.isLoginVisible or _G.isRegisterVisible or
                               _G.isUserPanelVisible or _G.isJailDoorBreakUIVisible or _G.isJailHackSystemUIVisible or
                               _G.isDrugSellGUIVisible or _G.isDrugSeedBuyGUIVisible -- NEU

    if chatActive or consoleActive or mainMenuOpen or anyCustomGuiActive then
        if _G.isCursorManuallyShownByClickSystem then
            showCursor(false)
            _G.isCursorManuallyShownByClickSystem = false
            guiSetInputMode("allow_binds")
        end
        return
    end

    _G.isCursorManuallyShownByClickSystem = not _G.isCursorManuallyShownByClickSystem
    showCursor(_G.isCursorManuallyShownByClickSystem)

    if _G.isCursorManuallyShownByClickSystem then
        guiSetInputMode("no_binds_when_editing")
    else
        guiSetInputMode("allow_binds")
    end
end
bindKey("m", "down", toggleManualCursor)

function forceCloseManualCursor()
    if _G.isCursorManuallyShownByClickSystem then
        _G.isCursorManuallyShownByClickSystem = false
        showCursor(false)
        guiSetInputMode("allow_binds")
    end
end
_G.forceCloseManualCursor = forceCloseManualCursor

addEventHandler("onClientGUIShowCursor", root, function(sourceGuiElement, shownByScript)
    if _G.isCursorManuallyShownByClickSystem and sourceGuiElement ~= localPlayer and shownByScript then
        showCursor(false)
        _G.isCursorManuallyShownByClickSystem = false
    end
end)

addEventHandler("onClientChatBoxInput", root, function(previousText, newText)
    if _G.isCursorManuallyShownByClickSystem then
        showCursor(false)
        _G.isCursorManuallyShownByClickSystem = false
    end
end)

addEventHandler("onClientConsole", root, function()
    if _G.isCursorManuallyShownByClickSystem then
        showCursor(false)
        _G.isCursorManuallyShownByClickSystem = false
    end
end)

addEventHandler("onClientClick", root, function(button, state, absX, absY, wx, wy, wz, elementClicked)
    -- Prüfe zuerst, ob ein anderes GUI-Fenster den Klick verarbeiten soll
    if _G.isPedGuiOpen or _G.isInventoryVisible or _G.isDriveMenuVisible or _G.isTheoryTestVisible or
       _G.isConfirmPracticalVisible or _G.idPurchaseConfirmVisible or _G.idCardGuiVisible or
       _G.isHandyGUIVisible or _G.isMessageGUIOpen or _G.isBankGUIVisible or
       _G.isMechanicWindowVisible or _G.isMechanicOfferGuiVisible or _G.isRepairConfirmVisible or
       _G.isRepairMenuVisible or _G.isTuneMenuVisible or _G.isPolicePanelVisible or
       _G.isWantedPlayersGUIVisible or _G.isMedicWindowVisible or _G.isPatientListVisible or
       _G.isYakuzaWindowVisible or _G.isMocroWindowVisible or _G.isCosaWindowVisible or
       _G.isManagementVisible or _G.isJuwelierGUIVisible or _G.isClothesMenuOpen or
       _G.isFuelWindowVisible or
       _G.isCarShopVisible or _G.isSpawnWindowVisible or
       _G.isBankRobConfirmWindowActive or _G.isCasinoRobConfirmWindowActive or
       _G.isDeathScreenActive or _G.isLoginVisible or _G.isRegisterVisible or
       _G.isUserPanelVisible or _G.isJailDoorBreakUIVisible or _G.isJailHackSystemUIVisible or
       _G.isJobGuiOpen or _G.isDrugSellGUIVisible or _G.isDrugSeedBuyGUIVisible then -- NEU

        return
    end

    -- Nur fortfahren, wenn der manuelle Cursor aktiv ist und es ein Linksklick ist
    if not _G.isCursorManuallyShownByClickSystem or button ~= "left" or state ~= "down" then
        return
    end

    -- [[ MECHANIKER-FAHRZEUGKLICK-LOGIK ]]
    if isElement(elementClicked) and getElementType(elementClicked) == "vehicle" then
        local playerFactionID = getElementData(localPlayer, "group")
        local isMechanicOnDuty = getElementData(localPlayer, "mechanicImDienst")

        if playerFactionID == "Mechanic" and isMechanicOnDuty == true and _G.isCursorManuallyShownByClickSystem then
            local vehicleOwnerAccountID = getElementData(elementClicked, "account_id")
            local playerAccountID = getElementData(localPlayer, "account_id")

            if vehicleOwnerAccountID and playerAccountID and vehicleOwnerAccountID == playerAccountID then
                --outputDebugString("[ClickClient] Mechanic Klick auf EIGENES Fahrzeug (ID: " .. (getElementData(elementClicked, "id") or "N/A") .. ")")
                triggerEvent("mechanic:showSelfRepairConfirmationGUI", localPlayer, elementClicked)
                cancelEvent()
                return
            elseif vehicleOwnerAccountID then
                local vehicleOwnerElement = getVehicleController(elementClicked)
                local ownerNameForDebug = "N/A"
                if isElement(vehicleOwnerElement) then
                    ownerNameForDebug = getPlayerName(vehicleOwnerElement)
                end
                --outputDebugString("[ClickClient] Mechanic Klick auf FREMDES Fahrzeug (Model: " .. getElementModel(elementClicked) .. ", Fahrer: "..ownerNameForDebug..", Besitzer-AccID: " .. tostring(vehicleOwnerAccountID) ..")")
                triggerServerEvent("mechanic:requestRepairOfferFromClickedVehicle", localPlayer, elementClicked)
                cancelEvent()
                return
            else
                -- Fahrzeug hat keine account_id (z.B. NPC-Fahrzeug), hier könnte man eine andere Logik implementieren falls gewünscht
            end
        end
    end
    -- [[ ENDE MECHANIKER-FAHRZEUGKLICK-LOGIK ]]

    -- Ped Klick Logik
    if isElement(elementClicked) and getElementType(elementClicked) == "ped" then
        if getElementData(elementClicked, "isClickablePed") then
            local pedIdentifier = getElementData(elementClicked, "pedIdentifier")

            -- Spezifische Ausnahmen, die von ihren eigenen Skripten behandelt werden
            if pedIdentifier == "id_request_officer" then return end
            if pedIdentifier == "driving_instructor" then triggerServerEvent("drivelicense:pedInteraction", localPlayer); return end

            if pedIdentifier == "bank_transaction_ped" then
                 --outputDebugString("[ClickClient] Klick auf Bank-Transaktions-Ped registriert. Trigger 'bank:requestOpenGUI_Client'.")
                 triggerEvent("bank:requestOpenGUI_Client", localPlayer, elementClicked)
                 cancelEvent()
                 return
            end

            -- Generischer Ped-Klick für andere Jobs etc.
            -- Dieser Teil ist wichtig für den Drogen-Verkaufs-Ped, wenn er den "pedIdentifier" und "isClickablePed" gesetzt hat.
            --outputDebugString("[ClickClient] Klick auf klickbaren Ped (Identifier: "..tostring(pedIdentifier)..") registriert. Triggere 'onClientRequestsPedAction'.")
            triggerServerEvent("onClientRequestsPedAction", localPlayer, elementClicked, math.random(10000, 99999))
            return
        end
    end

    -- Objekt Klick Logik (z.B. für ATMs)
    if isElement(elementClicked) and getElementType(elementClicked) == "object" then
        if getElementData(elementClicked, "isBankInteractionObject") == true then
            local interactionType = getElementData(elementClicked, "interactionType")
            if interactionType == "atm" then
                --outputDebugString("[ClickClient] Klick auf ATM-Objekt (ID: "..getElementModel(elementClicked)..") registriert. Trigger 'bank:requestOpenGUI_Client'.")
                triggerEvent("bank:requestOpenGUI_Client", localPlayer, elementClicked)
                cancelEvent()
                return
            end
        end
    end
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    _G.isCursorManuallyShownByClickSystem = false
    if _G.isDrugSellGUIVisible == nil then _G.isDrugSellGUIVisible = false end -- Sicherstellen, dass es initialisiert ist
    if _G.isDrugSeedBuyGUIVisible == nil then _G.isDrugSeedBuyGUIVisible = false end -- Sicherstellen, dass es initialisiert ist
    
    guiSetInputMode("allow_binds")
    --outputDebugString("[ClickClient] Click-System (Client V3.4.2 - Tankstellen-UI Check, DrugSellGUI Check) geladen.")
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if _G.isCursorManuallyShownByClickSystem then
        showCursor(false)
        _G.isCursorManuallyShownByClickSystem = false
    end
    unbindKey("m", "down", toggleManualCursor)
    guiSetInputMode("allow_binds")
end)