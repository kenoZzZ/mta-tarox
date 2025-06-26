-- In einer Test-Ressource (server_script.lua)
addCommandHandler("testhandling", function(player, cmd, modelIdStr)
    local modelId = tonumber(modelIdStr)
    if not modelId then
        outputChatBox("Syntax: /testhandling <modelID>", player)
        return
    end

    local success, handlingTableOrError = pcall(getVehicleHandling, modelId)
    if success then
        if type(handlingTableOrError) == "table" then
            outputChatBox("Handling für Modell " .. modelId .. " erfolgreich geladen.", player)
            -- Optional: Einige Werte ausgeben
            if handlingTableOrError.mass then
                 outputChatBox("Masse: " .. handlingTableOrError.mass, player)
            end
        else
            outputChatBox("getVehicleHandling für Modell " .. modelId .. " gab zurück: " .. tostring(handlingTableOrError), player, 255, 100, 0)
        end
    else
        outputChatBox("pcall(getVehicleHandling) für Modell " .. modelId .. " fehlgeschlagen: " .. tostring(handlingTableOrError), player, 255, 0, 0)
    end
end)