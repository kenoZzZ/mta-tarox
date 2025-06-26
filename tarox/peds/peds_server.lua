-- tarox/peds/peds_server.lua (Zentrales Ped-Management)
-- Version: Nametags V3
-- ANGEPASST V3.1: Keine DB-spezifischen Änderungen, da keine direkten DB-Aufrufe.
-- ERWEITERT FÜR SAMENVERKAUF: Neue Peds für den Samenverkauf hinzugefügt.

local managedPedsConfig = {
    {
        configName = "bank_teller_main",
        model = 290, x = 588.18512, y = 869.77893, z = -42.49732, rot = 180,
        interior = 0, dimension = 0, frozen = true, isClickable = true,
        pedIdentifier = "bank_teller_main",
        displayName = "Bankangestellter",
        jobItem = 3, jobItemName = "Dietrich",
        jobVehicleSpawnPos = {x=584.48901, y=902.19617, z=-44.04642, rot = 0},
        jobDeliveryPos = {x=2771.42871, y=-1607.07007, z=10.88517},
        jobInitialMessage = "Guten Tag! Ich habe einen speziellen Kurierauftrag für einen Dietrich. Möchtest du ihn für eine Belohnung übernehmen?",
        canBeDamaged = false,
        requiredLicense = "car"
    },
    {
        configName = "service_ped_airport",
        model = 170, x = -2371.67651, y = 1533.54065, z = 10.82086, rot = 90,
        interior = 0, dimension = 0, frozen = true, isClickable = true,
        pedIdentifier = "service_ped_airport",
        displayName = "Flughafen Service",
        jobItem = 12, jobItemName = "Spezialwerkzeug",
        jobVehicleSpawnPos = {x=-2342.22583, y=1572.85327, z=1.06142, rot = 0},
        jobDeliveryPos = {x=2359.57007, y=515.66418, z=1.06272},
        jobInitialMessage = "Hallo! Ich benötige dringend dieses Spezialwerkzeug an einem anderen Ort. Kannst du die Lieferung übernehmen?",
        canBeDamaged = false,
        requiredLicense = "car"
    },
    {
        configName = "ryder_multistage_job",
        model = 300,
        x = 2454.90527, y = -1708.17615, z = 13.62034, rot = 180,
        interior = 0, dimension = 0, frozen = true, isClickable = true,
        pedIdentifier = "character_ryder_grove",
        displayName = "Ryder",
        jobItem = 11,
        jobItemName = "Laptop",
        jobVehicleSpawnPos = {x=2473.35132, y = -1699.32861, z = 13.51889, rot = 0},
        jobInitialMessage = "Yo Homie, ich hab da 'nen speziellen Kurierdienst für dich, kapiert? Ist 'ne heiße Ware, also halt die Augen offen!",
        jobType = "multi_stage_motorcycle",
        jobZwischenstoppPos = {x=-1989.03076, y=1039.86511, z=55.72656},
        jobPlayerTeleportPos = {x=-1928.81519, y=947.22382, z=45.81250},
        jobFinalDeliveryPos = {x=-1853.95508, y=985.87177, z=45.42969},
        canBeDamaged = false,
        requiredLicense = "bike"
    },
    {
        configName = "c4_delivery_ped5",
        model = 142,
        x = 213.13750, y = -183.36911, z = 1.57812, rot = 90,
        interior = 0, dimension = 0,
        frozen = true,
        isClickable = true,
        pedIdentifier = "ped_c4_job",
        displayName = "Sprengstoffexperte",
        jobItem = 9,
        jobItemName = "C4 Sprengstoff",
        jobVehicleSpawnPos = {x = 206.13309, y = -177.06624, z = 1.93176, rot = 90},
        jobDeliveryPos = {x = -2133.71143, y = 1217.77295, z = 47.27344},
        jobInitialMessage = "Pssst! Ich brauche jemanden, der eine sensible Lieferung C4 übernimmt. Diskretes Fahrzeug steht bereit. Bist du dabei?",
        canBeDamaged = false,
        requiredLicense = "car"
    },
    {
        configName = "drill_job_ped4",
        model = 260,
        x = 2823.41260, y = 2200.92749, z = 11.02344, rot = 180,
        interior = 0, dimension = 0,
        frozen = true,
        isClickable = true,
        pedIdentifier = "ped_drill_job",
        displayName = "Bohr-Experte",
        jobItem = 8,
        jobItemName = "Bohrer",
        jobVehicleSpawnPos = {x = 2828.16528, y = 2197.92236, z = 11.84889, rot = 270},
        jobDeliveryPos = {x = 323.96786, y = -1801.62585, z = 4.63491},
        jobInitialMessage = "Ich habe hier einen hochwertigen Bohrer, der dringend geliefert werden muss. Bist du der Richtige für den Job?",
        canBeDamaged = false,
        requiredLicense = "car"
    },
    {
        configName = "juwelier_main",
        model = 150,
        x = 204.85362, y = -8.15140, z = 1001.21094, rot = 270,
        interior = 5, dimension = 0,
        frozen = true, isClickable = true,
        pedIdentifier = "juwelier_shop_ped",
        displayName = "Juwelier",
        initialMessage = "Willkommen! Möchten Sie Wertgegenstände verkaufen?",
        canBeDamaged = false
    },
    {
        configName = "id_request_officer_config",
        model = 150,
        x = -2764.81079, y = 375.62979, z = 6.34233,
        rot = 270,
        interior = 0,
        dimension = 0,
        frozen = true,
        isClickable = true,
        pedIdentifier = "id_request_officer",
        displayName = "Beamter",
        canBeDamaged = false
    },
	{
        configName = "job_vermittler_main",
        model = 150, -- Du kannst jedes gewünschte Modell verwenden
        x = -2764.77954, y = 382.15839, z = 6.32812, rot = 270,
        interior = 0, dimension = 0, frozen = true, isClickable = true,
        pedIdentifier = "job_vermittler_ped", -- Eindeutiger Identifier
        displayName = "Jobvermittler",
        canBeDamaged = false
    },
	{
        configName = "lkw_dispatcher_main",
        model = 155, -- Beispiel-Modell, kannst du anpassen (z.B. Arbeiter-Skin)
        x = -476.60367, y = -536.10791, z = 25.52961, rot = 0, -- Deine gewünschte Position und Rotation
        interior = 0, dimension = 0, frozen = true, isClickable = true,
        pedIdentifier = "lkw_dispatcher_ped", -- Wichtig für die Interaktion
        displayName = "LKW Disponent",
        canBeDamaged = false
        -- Kein jobItem etc., da dieser Ped nur die Tour bestätigt
    },
	{
		configName = "bank_teller_transaction", -- Eindeutiger Name
		model = 150, -- Modell-ID für den Ped (z.B. Anzugträger, Anpassen bei Bedarf)
		x = 359.71393, y = 173.64297, z = 1008.38934, -- Z-Koordinate für den Ped
		rot = 270, -- Rotation, sodass er in eine sinnvolle Richtung schaut (ggf. anpassen)
		interior = 3,
		dimension = 1,
		frozen = true,
		isClickable = true,
		pedIdentifier = "bank_transaction_ped", -- Wichtig für das Klick-Handling
		displayName = "Bankangestellter", -- Wird über dem Kopf angezeigt
		canBeDamaged = false
		-- Kein jobItem etc., da dieser Ped nur das Bank-GUI öffnet
	},
    {
        configName = "driving_instructor_main",
        model = 141,
        x = -2035.08801, y = -117.60417, z = 1035.17188,
        rot = 270,
        interior = 3,
        dimension = 0,
        frozen = true,
        isClickable = true,
        pedIdentifier = "driving_instructor",
        displayName = "Fahrlehrer",
        canBeDamaged = false,
        initialMessage = "Willkommen in der Fahrschule! Wie kann ich dir helfen?"
    },

    -- =========================================================================
    -- ## NEUE PEDS FÜR DROGEN-SAMEN-VERKAUF ##
    -- =========================================================================
    {
        configName = "samen_verkaeufer_1",
        model = 188, -- Beliebiges Modell
        x = -1650.27246, y = 782.27509, z = 18.21556, rot = 90, -- Beispielposition 1
        interior = 0, dimension = 0, frozen = true, isClickable = true,
        pedIdentifier = "drogen_samen_verkaufs_ped", -- Wichtig: Gleicher Identifier für alle Samenverkäufer
        displayName = "Samenhändler",
        canBeDamaged = false
    },
    {
        configName = "samen_verkaeufer_2",
        model = 240, -- Anderes Modell
        x = 1566.63428, y = -1556.67297, z = 13.54688, rot = 90, -- Beispielposition 2
        interior = 0, dimension = 0, frozen = true, isClickable = true,
        pedIdentifier = "drogen_samen_verkaufs_ped", -- Wichtig: Gleicher Identifier für alle Samenverkäufer
        displayName = "Samenhändler",
        canBeDamaged = false
    },
}

local createdManagedPeds = {}

function createSingleManagedPed(pedData)
    if not pedData or not pedData.model or not pedData.x then
        -- outputDebugString("[PEDS_SERVER] Ungültige Ped-Daten für createSingleManagedPed.")
        return nil
    end

    local ped = createPed(pedData.model, pedData.x, pedData.y, pedData.z, pedData.rot or 0)

    if isElement(ped) then
        setElementInterior(ped, pedData.interior or 0)
        setElementDimension(ped, pedData.dimension or 0)
        if pedData.frozen then setElementFrozen(ped, true) end

        setElementData(ped, "managedPedConfigName", pedData.configName, false)
        setElementData(ped, "isTaroxPed", true, true)

        if pedData.isClickable then
            setElementData(ped, "isClickablePed", true, true)
        end

        if pedData.pedIdentifier then
            setElementData(ped, "pedIdentifier", pedData.pedIdentifier, true)
        end

        local pedDisplayNameToSet = pedData.displayName
        if not pedDisplayNameToSet or pedDisplayNameToSet == "" then
            if pedData.configName then
                pedDisplayNameToSet = string.gsub(pedData.configName, "_", " ")
                local words = {}
                for word in string.gmatch(pedDisplayNameToSet, "%S+") do
                    table.insert(words, string.upper(string.sub(word,1,1)) .. string.lower(string.sub(word,2)))
                end
                pedDisplayNameToSet = table.concat(words, " ")
            else
                pedDisplayNameToSet = "Ped"
            end
            -- outputDebugString("[PEDS_SERVER] Hinweis: Kein 'displayName' für Ped '"..(pedData.configName or pedData.pedIdentifier or "Unbekannt").."' definiert. Fallback auf: '"..pedDisplayNameToSet.."'")
        end

        setElementData(ped, "pedName", pedDisplayNameToSet, true)
        -- outputDebugString(string.format("[PEDS_SERVER] Ped '%s' (Identifier: %s) erstellt mit Anzeigename: '%s'",
            --tostring(pedData.configName), tostring(pedData.pedIdentifier or "N/A"), pedDisplayNameToSet))

        if pedData.canBeDamaged == false then
            if type(setElementInvincible) == "function" then
                setElementInvincible(ped, true)
            else
                addEventHandler("onPedDamage", ped, function(attacker, weapon, bodypart, loss) cancelEvent() end)
            end
        end
        createdManagedPeds[ped] = pedData
        return ped
    else
        -- outputDebugString(string.format("[PEDS_SERVER] FEHLER: Konnte Ped '%s' (Model: %d) nicht erstellen!", pedData.configName or "Unbenannt", pedData.model))
        return nil
    end
end

function createAllManagedPeds()
    for pedElement, _ in pairs(createdManagedPeds) do
        if isElement(pedElement) then
            destroyElement(pedElement)
        end
    end
    createdManagedPeds = {}

    local createdCount = 0
    for i, pedDataEntry in ipairs(managedPedsConfig) do
        if createSingleManagedPed(pedDataEntry) then
            createdCount = createdCount + 1
        end
    end
    -- outputDebugString(string.format("[PEDS_SERVER] %d von %d Peds erfolgreich erstellt.", createdCount, #managedPedsConfig))
end

function handleManagedPedDamage(attacker, weapon, bodypart, loss)
    local damagedPed = source
    loss = tonumber(loss) or 0
    local pedConfig = createdManagedPeds[damagedPed]

    if pedConfig then
        if pedConfig.canBeDamaged == false then
            cancelEvent()
            if getElementHealth(damagedPed) < 100 then
                setElementHealth(damagedPed, 100)
            end
            return
        end
    end
end

function handleManagedPedWasted(totalAmmo, killer, killerWeapon, bodypart, stealth)
    local wastedPed = source
    local pedConfig = createdManagedPeds[wastedPed]

    if pedConfig then
        -- outputDebugString(string.format("[PEDS_SERVER] Ped '%s' (Model: %d) wurde getötet. Wird in Kürze neu erstellt.", pedConfig.configName or "Unbenannt", pedConfig.model))
        createdManagedPeds[wastedPed] = nil
        setTimer(function()
            if not isElement(wastedPed) then
                createSingleManagedPed(pedConfig)
            else
                 -- outputDebugString("[PEDS_SERVER] WARNUNG: Alter Ped existiert noch, versuche erneut zu löschen vor Respawn.")
                 destroyElement(wastedPed)
                 setTimer(createSingleManagedPed, 50, 1, pedConfig)
            end
        end, 200, 1)
    end
end

addEventHandler("onResourceStart", resourceRoot, function()
    createAllManagedPeds()
    addEventHandler("onPedDamage", getRootElement(), handleManagedPedDamage)
    addEventHandler("onPedWasted", getRootElement(), handleManagedPedWasted)
    -- outputDebugString("[PEDS_SERVER] Zentrales Ped-Management (V3.1 - Keine DB Änderungen) gestartet und alle Peds erstellt.")
end)

addEventHandler("onResourceStop", resourceRoot, function()
    for pedElement, _ in pairs(createdManagedPeds) do
        if isElement(pedElement) then
            destroyElement(pedElement)
        end
    end
    createdManagedPeds = {}
    removeEventHandler("onPedDamage", getRootElement(), handleManagedPedDamage)
    removeEventHandler("onPedWasted", getRootElement(), handleManagedPedWasted)
    -- outputDebugString("[PEDS_SERVER] Alle gemanagten Peds beim Ressourcenstopp entfernt.")
end)

_G.getManagedPedConfigByIdentifier = function(identifier)
    if not identifier then return nil end
    for _, pedData in ipairs(managedPedsConfig) do
        if pedData.pedIdentifier == identifier then
            return pedData
        end
    end
    return nil
end
-- Export für andere Ressourcen, falls benötigt
-- exports.tarox:getManagedPedConfigByIdentifier = _G.getManagedPedConfigByIdentifier