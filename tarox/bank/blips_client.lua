-- Erstellt und verwaltet Blips für den Bank-Ped, alle ATMs und statische Raub-Orte
-- ERWEITERT: Fügt Blips für Samen- und Drogenverkäufer hinzu.
-- MODIFIZIERT: Blip-IDs für Drogen-Peds angepasst.
local localPlayer = getLocalPlayer()

--[[
	================================================================
	== STATISCHE BLIPS (IMMER SICHTBAR)
	================================================================
]]

-- Variablen für unsere permanenten Blips, damit wir sie später löschen können
local bankRobBlip = nil
local casinoRobBlip = nil
local samenVerkaufBlips = {}
local drogenVerkaufBlips = {}

-- Koordinaten der Drogen-Peds
local samenVerkaufLocations = {
    {x = -1650.27246, y = 782.27509, z = 18.21556},
    {x = 1566.63428, y = -1556.67297, z = 13.54688},
}

local drogenVerkaufLocations = {
    {x = -2445.43726, y = -47.41283, z = 34.26562},
    {x = -1786.02405, y = 1429.24329, z = 7.18750},
    {x = -2291.88013, y = 730.98798, z = 49.44250},
    {x = 1504.77576, y = 2304.79028, z = 10.82031},
    {x = 2488.28662, y = 1444.53015, z = 10.90625},
    {x = 1633.59290, y = 1074.18066, z = 10.82031},
    {x = 2480.06812, y = -1757.70557, z = 13.54688},
    {x = 1113.13525, y = -1024.66418, z = 31.89226},
    {x = 1753.49194, y = -1943.75720, z = 13.56912},
}


local function createPermanentBlips()
	-- Zerstöre alte Blips, falls sie noch existieren (z.B. nach einem Resourcen-Neustart)
	if isElement(bankRobBlip) then destroyElement(bankRobBlip) end
	if isElement(casinoRobBlip) then destroyElement(casinoRobBlip) end
    for _, blip in ipairs(samenVerkaufBlips) do if isElement(blip) then destroyElement(blip) end end
    samenVerkaufBlips = {}
    for _, blip in ipairs(drogenVerkaufBlips) do if isElement(blip) then destroyElement(blip) end end
    drogenVerkaufBlips = {}


	-- Blip für den Bankraub erstellen (ID 46)
	bankRobBlip = createBlip(-1749.44666, 867.55786, 25.08594, 46, 2, 255, 0, 0, 255, 0, 9999)
	if isElement(bankRobBlip) then
		setElementData(bankRobBlip, "name", "Bankraub")
	end

	-- Blip für den Casinoraub erstellen (ID 25)
	casinoRobBlip = createBlip(2165.60620, 2164.15283, 10.82031, 25, 2, 0, 255, 0, 255, 0, 9999)
	if isElement(casinoRobBlip) then
		setElementData(casinoRobBlip, "name", "Casinoraub")
	end

    -- NEU: Blips für Samenverkäufer erstellen (Blip ID 51)
    for _, loc in ipairs(samenVerkaufLocations) do
        local blip = createBlip(loc.x, loc.y, loc.z, 51, 2, 0, 255, 0, 255, 0, 9999) -- ID GEÄNDERT
        if isElement(blip) then
            setElementData(blip, "name", "Samenhändler")
            setBlipVisibleDistance(blip, 300)
            table.insert(samenVerkaufBlips, blip)
        end
    end

    -- NEU: Blips für Drogenverkäufer erstellen (Blip ID 50)
    for _, loc in ipairs(drogenVerkaufLocations) do
        local blip = createBlip(loc.x, loc.y, loc.z, 50, 2, 128, 0, 128, 255, 0, 9999) -- ID GEÄNDERT
        if isElement(blip) then
            setElementData(blip, "name", "Drogenhändler")
            setBlipVisibleDistance(blip, 300)
            table.insert(drogenVerkaufBlips, blip)
        end
    end
end


--[[
	================================================================
	== DYNAMISCHE BLIPS (NUR IN DER NÄHE SICHTBAR)
	================================================================
]]

local blipIconID = 52 -- Dollar-Symbol
local blipVisibleDistance = 500 -- Distanz in Metern, ab der Blips sichtbar sind
local blipCheckInterval = 2000 -- Timer-Intervall in Millisekunden (2 Sekunden)

-- Koordinaten aller Bank-Interaktionspunkte
local bankLocations = {
    -- Bankangestellter Ped
    {x=359.71393, y=173.64297, z=1008.38934, interior=3, dimension=1},

    -- ATMs
    {x=2052.1999511719, y=-1897.5999755859, z=13.199999809265, interior=0, dimension=0},
    {x=1688.3000488281, y=-1582.9000244141, z=13.199999809265, interior=0, dimension=0},
    {x=1469.0999755859, y=-1772.3000488281, z=18.39999961853, interior=0, dimension=0},
    {x=1082.0999755859, y=-1562.6999511719, z=13.199999809265, interior=0, dimension=0},
    {x=1060.9000244141, y=-1131.1999511719, z=23.5, interior=0, dimension=0},
    {x=1467.8000488281, y=-1054.5999755859, z=23.5, interior=0, dimension=0},
    {x=2130.1000976562, y=-1151.3000488281, z=23.60000038147, interior=0, dimension=0},
    {x=2864.8999023438, y=-1468.1999511719, z=10.60000038147, interior=0, dimension=0},
    {x=1940, y=-2113, z=13.300000190735, interior=0, dimension=0},
    {x=1104.0999755859, y=-1271.1999511719, z=13.199999809265, interior=0, dimension=0},
    {x=-1642.0999755859, y=1207.8000488281, z=6.8000001907349, interior=0, dimension=0},
    {x=-2622.8000488281, y=1413.0999755859, z=6.6999998092651, interior=0, dimension=0},
    {x=-2767.8000488281, y=790.20001220703, z=52.400001525879, interior=0, dimension=0},
    {x=-2420.1000976562, y=971.59997558594, z=44.900001525879, interior=0, dimension=0},
    {x=-2446.8000488281, y=752.59997558594, z=34.799999237061, interior=0, dimension=0},
    {x=-2730.13599, y=424.91724, z=4.32814, interior=0, dimension=0},
    {x=-2430.6999511719, y=-45.39165, z=34.900001525879, interior=0, dimension=0},
    {x=-2172.3999023438, y=254.80000305176, z=35, interior=0, dimension=0},
    {x=-1980.5999755859, y=131.10000610352, z=27.299999237061, interior=0, dimension=0},
    {x=-1677, y=431.29998779297, z=6.8000001907349, interior=0, dimension=0},
}

-- Tabelle, um die aktuell sichtbaren Blips zu verwalten
local activeBlips = {}

local function updateBlips()
    local pX, pY, pZ = getElementPosition(localPlayer)
    local pDimension = getElementDimension(localPlayer)
    local pInterior = getElementInterior(localPlayer)

    for index, loc in ipairs(bankLocations) do
        -- Prüfe, ob Spieler in derselben Dimension/Interior ist
        if pDimension == loc.dimension and pInterior == loc.interior then
            local distance = getDistanceBetweenPoints3D(pX, pY, pZ, loc.x, loc.y, loc.z)

            -- Prüfe, ob der Blip erstellt werden sollte
            if distance <= blipVisibleDistance then
                -- Wenn der Blip für diesen Index noch nicht existiert, erstelle ihn
                if not activeBlips[index] then
                    local blip = createBlip(loc.x, loc.y, loc.z, blipIconID)
                    if isElement(blip) then
                        setElementDimension(blip, loc.dimension)
                        setElementInterior(blip, loc.interior)
                        setBlipVisibleDistance(blip, blipVisibleDistance + 50) -- Stellt sicher, dass das Blip auch auf der Minimap korrekt dargestellt wird
                        activeBlips[index] = blip
                    end
                end
            -- Wenn der Blip zerstört werden sollte (außerhalb der Reichweite)
            else
                if activeBlips[index] then
                    if isElement(activeBlips[index]) then
                        destroyElement(activeBlips[index])
                    end
                    activeBlips[index] = nil
                end
            end
        -- Wenn der Spieler nicht in der Dimension/Interior ist, zerstöre den Blip
        else
            if activeBlips[index] then
                if isElement(activeBlips[index]) then
                    destroyElement(activeBlips[index])
                end
                activeBlips[index] = nil
            end
        end
    end
end


--[[
	================================================================
	== RESOURCEN-STEUERUNG
	================================================================
]]

-- Timer, um die dynamischen Blips regelmäßig zu aktualisieren
local blipTimer = setTimer(updateBlips, blipCheckInterval, 0)

addEventHandler("onClientResourceStop", resourceRoot, function()
    -- Aufräumen, wenn die Ressource stoppt
    if isTimer(blipTimer) then
        killTimer(blipTimer)
    end

    -- Zerstöre dynamische Blips
    for index, blip in pairs(activeBlips) do
        if isElement(blip) then
            destroyElement(blip)
        end
    end
    activeBlips = {}

    -- Zerstöre permanente Blips
	if isElement(bankRobBlip) then destroyElement(bankRobBlip) end
	if isElement(casinoRobBlip) then destroyElement(casinoRobBlip) end
    for _, blip in ipairs(samenVerkaufBlips) do if isElement(blip) then destroyElement(blip) end end
    samenVerkaufBlips = {}
    for _, blip in ipairs(drogenVerkaufBlips) do if isElement(blip) then destroyElement(blip) end end
    drogenVerkaufBlips = {}
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    createPermanentBlips() -- Permanente Blips erstellen
    updateBlips() -- Dynamische Blips einmal sofort ausführen
end)