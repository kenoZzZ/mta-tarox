------------------------------------------
-- zip_client.lua
------------------------------------------
local screenW, screenH = guiGetScreenSize()

local availableSkins = {0, 1, 2, 7, 9, 11, 13, 14, 15, 16}
local currentSkinIndex = 1

local skinNames = {
    [0] = "CJ",
    [1] = "Truth",
    [2] = "Maccer",
    -- etc...
}

local isClothesMenuOpen = false
local oldSkinID = nil

-- We'll place the camera inside to look at the player
local camX, camY, camZ = 178.85400, -86.5, 1003.0
local lookX, lookY, lookZ = 181.0, -88.0, 1002.0

----------------------------------------------------------------------------
-- Event from server: "onClothesShopMarkerHit"
----------------------------------------------------------------------------
addEvent("onClothesShopMarkerHit", true)
addEventHandler("onClothesShopMarkerHit", root, function()
    if isClothesMenuOpen then return end

    isClothesMenuOpen = true
    currentSkinIndex = 1

    oldSkinID = getElementModel(localPlayer)

    setCameraMatrix(camX, camY, camZ, lookX, lookY, lookZ)
    showCursor(true)

    addEventHandler("onClientRender", root, renderClothesMenu)
end)

----------------------------------------------------------------------------
-- Render bottom-centered menu
----------------------------------------------------------------------------
function renderClothesMenu()
    if not isClothesMenuOpen then return end

    local menuW, menuH = 600, 140
    local startX = (screenW - menuW)/2
    local startY = screenH - menuH - 50

    dxDrawRectangle(startX, startY, menuW, menuH, tocolor(0,0,0,180), true)
    dxDrawText("Clothes Shop", startX, startY+5, startX+menuW, startY+30,
        tocolor(255,255,255), 1.3, "default-bold", "center","top", false, false, true)

    local selSkin = availableSkins[currentSkinIndex]
    local label = skinNames[selSkin] or ("Skin #"..selSkin)
    dxDrawText(label.."   |   Price: $1000",
        startX, startY+35, startX+menuW, startY+60,
        tocolor(255,255,0), 1.2, "default-bold", "center","top", false, false, true)

    -- Arrows
    local arrowSize = 50
    local arrowY = startY + (menuH - arrowSize)/2
    local arrowLeftX = startX + 10
    local arrowRightX= startX + menuW - arrowSize - 10

    dxDrawRectangle(arrowLeftX, arrowY, arrowSize, arrowSize, tocolor(50,50,50,220), true)
    dxDrawText("<", arrowLeftX, arrowY, arrowLeftX+arrowSize, arrowY+arrowSize,
        tocolor(255,255,255), 2, "default-bold","center","center", false,false,true)

    dxDrawRectangle(arrowRightX, arrowY, arrowSize, arrowSize, tocolor(50,50,50,220), true)
    dxDrawText(">", arrowRightX, arrowY, arrowRightX+arrowSize, arrowY+arrowSize,
        tocolor(255,255,255), 2, "default-bold","center","center", false,false,true)

    -- Buy / Cancel
    local btnW, btnH = 120, 40
    local spacing = 20
    local totalBtnsW = btnW*2 + spacing
    local btnsX = startX + (menuW - totalBtnsW)/2
    local btnsY = startY + menuH - btnH - 10

    dxDrawRectangle(btnsX, btnsY, btnW, btnH, tocolor(0,150,0,220), true)
    dxDrawText("BUY", btnsX, btnsY, btnsX+btnW, btnsY+btnH,
        tocolor(255,255,255), 1.2,"default-bold","center","center",false,false,true)

    local cancelX = btnsX + btnW + spacing
    dxDrawRectangle(cancelX, btnsY, btnW, btnH, tocolor(200,0,0,220), true)
    dxDrawText("CANCEL", cancelX, btnsY, cancelX+btnW, btnsY+btnH,
        tocolor(255,255,255), 1.2,"default-bold","center","center",false,false,true)
end

----------------------------------------------------------------------------
-- onClientClick => arrows => preview => buy => cancel
----------------------------------------------------------------------------
addEventHandler("onClientClick", root, function(btn, state, cx, cy)
    if not isClothesMenuOpen then return end
    if btn ~= "left" or state ~= "up" then return end

    local menuW, menuH = 600, 140
    local startX = (screenW - menuW)/2
    local startY = screenH - menuH - 50

    local arrowSize = 50
    local arrowY = startY + (menuH - arrowSize)/2
    local arrowLeftX = startX + 10
    local arrowRightX= startX + menuW - arrowSize - 10

    local btnW, btnH = 120, 40
    local spacing = 20
    local totalBtnsW = btnW*2 + spacing
    local btnsX = startX + (menuW - totalBtnsW)/2
    local btnsY = startY + menuH - btnH - 10
    local cancelX = btnsX + btnW + spacing

    -- Left arrow
    if cx >= arrowLeftX and cx <= arrowLeftX+arrowSize
       and cy >= arrowY and cy <= arrowY+arrowSize then
        currentSkinIndex = currentSkinIndex - 1
        if currentSkinIndex < 1 then
            currentSkinIndex = #availableSkins
        end
        setElementModel(localPlayer, availableSkins[currentSkinIndex])
        return
    end

    -- Right arrow
    if cx >= arrowRightX and cx <= arrowRightX+arrowSize
       and cy >= arrowY and cy <= arrowY+arrowSize then
        currentSkinIndex = currentSkinIndex + 1
        if currentSkinIndex > #availableSkins then
            currentSkinIndex = 1
        end
        setElementModel(localPlayer, availableSkins[currentSkinIndex])
        return
    end

    -- BUY
    if cx >= btnsX and cx <= (btnsX+btnW)
       and cy >= btnsY and cy <= (btnsY+btnH) then
        local chosen = availableSkins[currentSkinIndex]
        triggerServerEvent("onPlayerBuyOutfit", localPlayer, chosen)
        return
    end

    -- CANCEL => revert to old
    if cx >= cancelX and cx <= (cancelX+btnW)
       and cy >= btnsY and cy <= (btnsY+btnH) then
        if oldSkinID then
            setElementModel(localPlayer, oldSkinID)
        end
        closeClothesMenu()
        return
    end
end)

----------------------------------------------------------------------------
-- onOutfitPurchaseSuccess => close
----------------------------------------------------------------------------
addEvent("onOutfitPurchaseSuccess", true)
addEventHandler("onOutfitPurchaseSuccess", root, function(newSkin)
    outputChatBox("Purchased skin #"..newSkin, 0,255,0)
    closeClothesMenu()
end)

----------------------------------------------------------------------------
-- closeClothesMenu => restore camera, remove UI
----------------------------------------------------------------------------
function closeClothesMenu()
    if not isClothesMenuOpen then return end
    isClothesMenuOpen = false

    removeEventHandler("onClientRender", root, renderClothesMenu)
    setCameraTarget(localPlayer)
    showCursor(false)
end
