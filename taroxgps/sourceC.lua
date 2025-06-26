-- Kaliteli Türkçe Scriptler : https://sparrow-mta.blogspot.com
-- İyi oyunlar.
-- MODIFIZIERT VON GEMINI FÜR ANPASSBARE ICON-GRÖSSE

Display = {};
Display.Width, Display.Height = guiGetScreenSize();

-- ##################################################################
-- ## HIER KANNST DU DIE GRÖSSE ALLER ICONS ANPASSEN ##
-- ##################################################################
local allgemeineBlipGroesse = 3 -- Größe für Standard-Blips (F11-Karte). Standard ist 2.
local customMinimapIconGroesse = 25 -- Größe für die Icons auf der Minikarte unten rechts. Standard war 20.
-- ##################################################################

--[[ 
	HINWEIS: Die 'radarSettings' scheinen aus einer anderen Datei zu kommen.
	Falls Fehler auftreten, stelle sicher, dass 'radarSettings' korrekt geladen wird.
	Ich habe zur Sicherheit Standardwerte eingefügt.
]]
local radarSettings = radarSettings or {
	mapTextureSize = 2048,
	mapTexture = 'files/images/map.png',
	mapWaterColor = {0, 0, 100},
	alpha = 255,
	showStats = true
}


Minimap = {};
Minimap.Width = 280;
Minimap.Height = 175;
Minimap.PosX = 20;
Minimap.PosY = (Display.Height - 20) - Minimap.Height;

Minimap.IsVisible = true;
Minimap.TextureSize = radarSettings['mapTextureSize'];
Minimap.NormalTargetSize, Minimap.BiggerTargetSize = Minimap.Width, Minimap.Width * 2;
Minimap.MapTarget = dxCreateRenderTarget(Minimap.BiggerTargetSize, Minimap.BiggerTargetSize, true);
Minimap.RenderTarget = dxCreateRenderTarget(Minimap.NormalTargetSize * 3, Minimap.NormalTargetSize * 3, true);
Minimap.MapTexture = dxCreateTexture(radarSettings['mapTexture']);

Minimap.CurrentZoom = 3;
Minimap.MaximumZoom = 8;
Minimap.MinimumZoom = 1;

Minimap.WaterColor = radarSettings['mapWaterColor'];
Minimap.Alpha = radarSettings['alpha'];
Minimap.PlayerInVehicle = false;
Minimap.LostRotation = 0;
Minimap.MapUnit = Minimap.TextureSize / 6000;

Bigmap = {};
Bigmap.Width, Bigmap.Height = Display.Width - 40, Display.Height - 40;
Bigmap.PosX, Bigmap.PosY = 20, 20;
Bigmap.IsVisible = false;
Bigmap.CurrentZoom = 1;
Bigmap.MinimumZoom = 1;
Bigmap.MaximumZoom = 3;

Fonts = {};
Fonts.Roboto = dxCreateFont('files/fonts/roboto.ttf',12, false, 'antialiased');

--burgers
createBlip ( -2023.5756835938, 512.63055419922, 35.171875, 10, allgemeineBlipGroesse)

Fonts.Icons = dxCreateFont('files/fonts/icons.ttf', 25, false, 'antialiased');

Stats = {};
Stats.Bar = {};
Stats.Bar.Width = Minimap.Width;
Stats.Bar.Height = 10;

local playerX, playerY, playerZ = 0, 0, 0;
local mapOffsetX, mapOffsetY, mapIsMoving = 0, 0, false;

addEventHandler('onClientResourceStart', resourceRoot,
	function()		
		setPlayerHudComponentVisible("radar", false);
		if (Minimap.MapTexture and isElement(Minimap.MapTexture)) then
			dxSetTextureEdge(Minimap.MapTexture, 'border', tocolor(Minimap.WaterColor[1], Minimap.WaterColor[2], Minimap.WaterColor[3], 255));
		end
	end
);

function RadarTrue()
    Minimap.IsVisible = true;
end
addEvent("onRadarTrue", true)
addEventHandler("onRadarTrue", root, RadarTrue)


function RadarFalse()
    Minimap.IsVisible = false;
end
addEvent("onRadarFalse", true)
addEventHandler("onRadarFalse", root, RadarFalse)


addEventHandler('onClientKey', root,
	function(key, state)
		if (state) then
			if (key == 'F11') then
				cancelEvent();
				Bigmap.IsVisible = not Bigmap.IsVisible;
				showCursor(false);
				
				if (Bigmap.IsVisible) then
					showChat(false);
					playSoundFrontEnd(1);
					Minimap.IsVisible = false;
					showCursor(true);
				else
					showChat(true);
					playSoundFrontEnd(2);
					Minimap.IsVisible = true;
					mapOffsetX, mapOffsetY, mapIsMoving = 0, 0, false;
				end
			elseif (key == 'mouse_wheel_down' and Bigmap.IsVisible) then
				Bigmap.CurrentZoom = math.min(Bigmap.CurrentZoom + 0.5, Bigmap.MaximumZoom);
			elseif (key == 'mouse_wheel_up' and Bigmap.IsVisible) then
				Bigmap.CurrentZoom = math.max(Bigmap.CurrentZoom - 0.5, Bigmap.MinimumZoom);
			elseif (key == 'mouse2' and Bigmap.IsVisible) then
				showCursor(not isCursorShowing());
			end
		end
	end
);

addEventHandler('onClientClick', root,
	function(button, state, cursorX, cursorY)
		if (not Minimap.IsVisible and Bigmap.IsVisible) then
			if (button == 'left' and state == 'down') then
				if (cursorX >= Bigmap.PosX and cursorX <= Bigmap.PosX + Bigmap.Width) then
					if (cursorY >= Bigmap.PosY and cursorY <= Bigmap.PosY + Bigmap.Height) then
						mapOffsetX = cursorX * Bigmap.CurrentZoom + playerX;
						mapOffsetY = cursorY * Bigmap.CurrentZoom - playerY;
						mapIsMoving = true;
					end
				end
			elseif (button == 'left' and state == 'up') then
				mapIsMoving = false;
			end
		end
	end
);

addEventHandler('onClientRender', root,
	function()
		if (not Minimap.IsVisible and Bigmap.IsVisible) then
			dxDrawBorder(Bigmap.PosX, Bigmap.PosY, Bigmap.Width, Bigmap.Height, 2, tocolor(0, 0, 0, 200));
			
			if (getElementInterior(localPlayer) == 0) then
				if (isCursorShowing()) then
					local cursorX, cursorY = getCursorPosition();
					
					local absoluteX = cursorX * Display.Width;
					local absoluteY = cursorY * Display.Height;
					
					if (getKeyState('mouse1') and mapIsMoving) then
						playerX = -(absoluteX * Bigmap.CurrentZoom - mapOffsetX);
						playerY = absoluteY * Bigmap.CurrentZoom - mapOffsetY;
						
						playerX = math.max(-3000, math.min(3000, playerX));
						playerY = math.max(-3000, math.min(3000, playerY));
					end
				end
				
				local playerRotation = getPedRotation(localPlayer);
				local mapX = (((3000 + playerX) * Minimap.MapUnit) - (Bigmap.Width / 2) * Bigmap.CurrentZoom);
				local mapY = (((3000 - playerY) * Minimap.MapUnit) - (Bigmap.Height / 2) * Bigmap.CurrentZoom);
				local mapWidth, mapHeight = Bigmap.Width * Bigmap.CurrentZoom, Bigmap.Height * Bigmap.CurrentZoom;

				if(Minimap.MapTexture and isElement(Minimap.MapTexture)) then
					dxDrawImageSection(Bigmap.PosX, Bigmap.PosY, Bigmap.Width, Bigmap.Height, mapX, mapY, mapWidth, mapHeight, Minimap.MapTexture, 0, 0, 0, tocolor(255, 255, 255, Minimap.Alpha));
				end
				
				-- Gebiete auf der F11 Karte zeichnen
				if (type(renderTerritories) == "function") then
					renderTerritories()
				end

				--> Blips
				for _, blip in ipairs(getElementsByType('blip')) do
					if (localPlayer ~= getElementAttachedTo(blip)) then
                        local blipX, blipY, blipZ = getElementPosition(blip)
						local blipSettings = {
							['color'] = {255, 255, 255, 255},
							['size'] = customMinimapIconGroesse, 
							['icon'] = getBlipIcon (blip) or 'target',
							['exclusive'] = getElementData(blip, 'exclusiveBlip') or false
						};
						
						if (blipSettings['icon'] == 0 or blipSettings['icon'] == 'waypoint') then
							blipSettings['color'] = {getBlipColor(blip)};
						end
						
						local centerX, centerY = (Bigmap.PosX + (Bigmap.Width / 2)), (Bigmap.PosY + (Bigmap.Height / 2));
						local leftFrame = (centerX - Bigmap.Width / 2) + (blipSettings['size'] / 2);
						local rightFrame = (centerX + Bigmap.Width / 2) - (blipSettings['size'] / 2);
						local topFrame = (centerY - Bigmap.Height / 2) + (blipSettings['size'] / 2);
						local bottomFrame = (centerY + Bigmap.Height / 2) - (blipSettings['size'] / 2);
						local blipDrawX, blipDrawY = getMapFromWorldPosition(blipX, blipY);
						
						centerX = math.max(leftFrame, math.min(rightFrame, blipDrawX));
						centerY = math.max(topFrame, math.min(bottomFrame, blipDrawY));

						dxDrawImage(centerX - (blipSettings['size'] / 2), centerY - (blipSettings['size'] / 2), blipSettings['size'], blipSettings['size'], 'files/images/blips/' .. blipSettings['icon'] .. '.png', 0, 0, 0, tocolor(blipSettings['color'][1], blipSettings['color'][2], blipSettings['color'][3], blipSettings['color'][4]));
					end
				end
				
				for _, player in ipairs(getElementsByType('player')) do
					if (localPlayer ~= player) then
                        local otherPlayerX, otherPlayerY, otherPlayerZ = getElementPosition(player)
						local blipSettings = {
							['color'] = {255, 255, 255, 255},
							['size'] = customMinimapIconGroesse,
							['icon'] = 'player'
						};
						
						blipSettings['color'] = {getPlayerNametagColor(player)};

						local blipX, blipY = getMapFromWorldPosition(otherPlayerX, otherPlayerY);
						
						if (blipX >= Bigmap.PosX and blipX <= Bigmap.PosX + Bigmap.Width) then
							if (blipY >= Bigmap.PosY and blipY <= Bigmap.PosY + Bigmap.Height) then
								dxDrawImage(blipX - (blipSettings['size'] / 2), blipY - (blipSettings['size'] / 2), blipSettings['size'], blipSettings['size'], 'files/images/blips/' .. blipSettings['icon'] .. '.png', 0, 0, 0, tocolor(blipSettings['color'][1], blipSettings['color'][2], blipSettings['color'][3], blipSettings['color'][4]));
							end
						end
					end
				end
				
				--> Local player
				local localX, localY, localZ = getElementPosition(localPlayer);
                local playerRotation = getPedRotation(localPlayer)
				local blipX, blipY = getMapFromWorldPosition(localX, localY);
						
				if (blipX >= Bigmap.PosX and blipX <= Bigmap.PosX + Bigmap.Width) then
					if (blipY >= Bigmap.PosY and blipY <= Bigmap.PosY + Bigmap.Height) then
						dxDrawImage(blipX - (customMinimapIconGroesse/2), blipY - (customMinimapIconGroesse/2), customMinimapIconGroesse, customMinimapIconGroesse, 'files/images/arrow.png', 360 - playerRotation);
					end
				end
			end
		elseif (Minimap.IsVisible and not Bigmap.IsVisible) then
			if (radarSettings['showStats']) then
				Minimap.PosY = ((Display.Height - 20) - Stats.Bar.Height) - Minimap.Height;
			else
				Minimap.PosY = (Display.Height - 20) - Minimap.Height;
			end
			
			dxDrawBorder(Minimap.PosX, Minimap.PosY, Minimap.Width, Minimap.Height, 2, tocolor(0, 0, 0, 0));
			
			if (getElementInterior(localPlayer) == 0) then
				Minimap.PlayerInVehicle = getPedOccupiedVehicle(localPlayer);
				playerX, playerY, playerZ = getElementPosition(localPlayer);
				
				--> Calculate positions
				local playerRotation = getPedRotation(localPlayer);
				local playerMapX, playerMapY = (3000 + playerX) / 6000 * Minimap.TextureSize, (3000 - playerY) / 6000 * Minimap.TextureSize;
				local streamDistance, pRotation = getRadarRadius(), getRotation();
				local mapRadius = streamDistance / 6000 * Minimap.TextureSize * Minimap.CurrentZoom;
				local mapX, mapY, mapWidth, mapHeight = playerMapX - mapRadius, playerMapY - mapRadius, mapRadius * 2, mapRadius * 2;
				
				--> Set world
				dxSetRenderTarget(Minimap.MapTarget, true);
				dxDrawRectangle(0, 0, Minimap.BiggerTargetSize, Minimap.BiggerTargetSize, tocolor(Minimap.WaterColor[1], Minimap.WaterColor[2], Minimap.WaterColor[3], Minimap.Alpha), false);
				if(Minimap.MapTexture and isElement(Minimap.MapTexture)) then
                    dxDrawImageSection(0, 0, Minimap.BiggerTargetSize, Minimap.BiggerTargetSize, mapX, mapY, mapWidth, mapHeight, Minimap.MapTexture, 0, 0, 0, tocolor(255, 255, 255, Minimap.Alpha), false);
                end

				-- ###############################################################
				-- ## HIER WERDEN DIE GEBIETE AUF DIE MINIKARTE GEZEICHNET
				-- ###############################################################
				if (type(renderTerritoriesOnMinimap) == "function") then
					renderTerritoriesOnMinimap(mapX, mapY, mapWidth, mapHeight, Minimap.BiggerTargetSize)
				end
				-- ###############################################################
				
				--> Draw blip
				dxSetRenderTarget(Minimap.RenderTarget, true);
				dxDrawImage(Minimap.NormalTargetSize / 2, Minimap.NormalTargetSize / 2, Minimap.BiggerTargetSize, Minimap.BiggerTargetSize, Minimap.MapTarget, math.deg(-pRotation), 0, 0, tocolor(255, 255, 255, 255), false);
				
				local serverBlips = getElementsByType('blip');
				
				table.sort(serverBlips,
					function(b1, b2)
						return getBlipOrdering(b1) < getBlipOrdering(b2);
					end
				);
				
				for _, blip in ipairs(serverBlips) do
					local blipX, blipY, blipZ = getElementPosition(blip);
					
					if (localPlayer ~= getElementAttachedTo(blip) and getElementInterior(localPlayer) == getElementInterior(blip) and getElementDimension(localPlayer) == getElementDimension(blip)) then
						local blipDistance = getDistanceBetweenPoints2D(blipX, blipY, playerX, playerY);
						local blipRotation = math.deg(-getVectorRotation(playerX, playerY, blipX, blipY) - (-pRotation)) - 180;
						local blipRadius = math.min((blipDistance / (streamDistance * Minimap.CurrentZoom)) * Minimap.NormalTargetSize, Minimap.NormalTargetSize);
						local distanceX, distanceY = getPointFromDistanceRotation(0, 0, blipRadius, blipRotation);
						
						local blipSettings = {
							['color'] = {255, 255, 255, 255},
							['size'] = customMinimapIconGroesse, 
							['exclusive'] = getElementData(blip, 'exclusiveBlip') or false,
							['icon'] = getBlipIcon (blip) or 'target'
						};
						
						local blipDrawX, blipDrawY = Minimap.NormalTargetSize * 1.5 + (distanceX - (blipSettings['size'] / 2)), Minimap.NormalTargetSize * 1.5 + (distanceY - (blipSettings['size'] / 2));
						
						if (blipSettings['icon'] == 0 or blipSettings['icon'] == 'waypoint') then
							blipSettings['color'] = {getBlipColor(blip)};
						end
						
						dxSetBlendMode('modulate_add');
						dxDrawImage(blipDrawX, blipDrawY, blipSettings['size'], blipSettings['size'], 'files/images/blips/' .. blipSettings['icon'] .. '.png', 0, 0, 0, tocolor(blipSettings['color'][1], blipSettings['color'][2], blipSettings['color'][3], blipSettings['color'][4]), false);
						dxSetBlendMode('blend');
					end
				end
				
				for _, player in ipairs(getElementsByType('player')) do
					local otherPlayerX, otherPlayerY, otherPlayerZ = getElementPosition(player);
					
					if (localPlayer ~= player and streamDistance * Minimap.CurrentZoom) then
						local playerDistance = getDistanceBetweenPoints2D(otherPlayerX, otherPlayerY, playerX, playerY);
						local playerRotation = math.deg(-getVectorRotation(playerX, playerY, otherPlayerX, otherPlayerY) - (-pRotation)) - 180;
						local playerRadius = math.min((playerDistance / (streamDistance * Minimap.CurrentZoom)) * Minimap.NormalTargetSize, Minimap.NormalTargetSize);
						local distanceX, distanceY = getPointFromDistanceRotation(0, 0, playerRadius, playerRotation);
						
						local blipDrawX, blipDrawY = Minimap.NormalTargetSize * 1.5 + (distanceX - (customMinimapIconGroesse/2)), Minimap.NormalTargetSize * 1.5 + (distanceY - (customMinimapIconGroesse/2));
						local playerR, playerG, playerB = getPlayerNametagColor(player);
						
						dxSetBlendMode('modulate_add');
						dxDrawImage(blipDrawX, blipDrawY, customMinimapIconGroesse, customMinimapIconGroesse, 'files/images/blips/0.png', 0, 0, 0, tocolor(playerR, playerG, playerB, 255), false);
						dxSetBlendMode('blend');
						
					end
				end
				
				--> Draw fully minimap
				dxSetRenderTarget();
				dxDrawImageSection(Minimap.PosX, Minimap.PosY, Minimap.Width, Minimap.Height, Minimap.NormalTargetSize / 2 + (Minimap.BiggerTargetSize / 2) - (Minimap.Width / 2), Minimap.NormalTargetSize / 2 + (Minimap.BiggerTargetSize / 2) - (Minimap.Height / 2), Minimap.Width, Minimap.Height, Minimap.RenderTarget, 0, -90, 0, tocolor(255, 255, 255, 255));
				dxDrawImage((Minimap.PosX + (Minimap.Width / 2)) - (customMinimapIconGroesse/2), (Minimap.PosY + (Minimap.Height / 2)) - (customMinimapIconGroesse/2), customMinimapIconGroesse, customMinimapIconGroesse, 'files/images/arrow.png', math.deg(-pRotation) - playerRotation);
            end
        end
	end)

function doesCollide(x1, y1, w1, h1, x2, y2, w2, h2)
	local horizontal = (x1 < x2) ~= (x1 + w1 < x2) or (x1 > x2) ~= (x1 > x2 + w2);
	local vertical = (y1 < y2) ~= (y1 + h1 < y2) or (y1 > y2) ~= (y1 > y2 + h2);
	
	return (horizontal and vertical);
end

function getRadarRadius()
	if (not Minimap.PlayerInVehicle) then
		return 180;
	else
		local vehicleX, vehicleY, vehicleZ = getElementVelocity(Minimap.PlayerInVehicle);
		local currentSpeed = (1 + (vehicleX ^ 2 + vehicleY ^ 2 + vehicleZ ^ 2) ^ (0.5)) / 2;
	
		if (currentSpeed <= 0.5) then
			return 180;
		elseif (currentSpeed >= 1) then
			return 360;
		end
		
		local distance = currentSpeed - 0.5;
		local ratio = 180 / 0.5;
		
		return math.ceil((distance * ratio) + 180);
	end
end

function getPointFromDistanceRotation(x, y, dist, angle)
	local a = math.rad(90 - angle);
	local dx = math.cos(a) * dist;
	local dy = math.sin(a) * dist;
	
	return x + dx, y + dy;
end

function getRotation()
	local cameraX, cameraY, _, rotateX, rotateY = getCameraMatrix();
	local camRotation = getVectorRotation(cameraX, cameraY, rotateX, rotateY);
	
	return camRotation;
end

function getVectorRotation(X, Y, X2, Y2)
	local rotation = 6.2831853071796 - math.atan2(X2 - X, Y2 - Y) % 6.2831853071796;
	
	return -rotation;
end

function dxDrawBorder(x, y, w, h, size, color, postGUI)
	size = size or 2;
	
	dxDrawRectangle(x - size, y, size, h, color or tocolor(0, 0, 0, 180), postGUI);
	dxDrawRectangle(x + w, y, size, h, color or tocolor(0, 0, 0, 180), postGUI);
	dxDrawRectangle(x - size, y - size, w + (size * 2), size, color or tocolor(0, 0, 0, 180), postGUI);
	dxDrawRectangle(x - size, y + h, w + (size * 2), size, color or tocolor(0, 0, 0, 180), postGUI);
end

function getMinimapState()
	return Minimap.IsVisible;
end

function getBigmapState()
	return Bigmap.IsVisible;
end

function getMapFromWorldPosition(worldX, worldY)
	local centerX, centerY = (Bigmap.PosX + (Bigmap.Width / 2)), (Bigmap.PosY + (Bigmap.Height / 2));
	local mapX = centerX - (playerX - worldX) / (3000 * Bigmap.CurrentZoom) * (Minimap.TextureSize / 2);
	local mapY = centerY + (playerY - worldY) / (3000 * Bigmap.CurrentZoom) * (Minimap.TextureSize / 2);
	return mapX, mapY
end

function getWorldFromMapPosition(mapX, mapY)
	local worldX = playerX + ((mapX * ((Bigmap.Width * Bigmap.CurrentZoom) * 2)) - (Bigmap.Width * Bigmap.CurrentZoom));
	local worldY = playerY + ((mapY * ((Bigmap.Height * Bigmap.CurrentZoom) * 2)) - (Bigmap.Height * Bigmap.CurrentZoom)) * -1;
	
	return worldX, worldY;
end

-- Fallback leere Funktionen
function getBlipOrdering() return 0 end
function getPlayerNametagColor() return 255, 255, 255 end