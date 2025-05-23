local Config = lib.load("config.config")
local InStation = {}

GlobalState:set("fuelPrice", Config.FuelPrice, true)

---@description Callbacks
local function inStation(source, name)
	if not InStation[source] then
		return false
	end

	return InStation[source] == name
end

lib.callback.register("mnr_fuel:server:InStation", inStation)

lib.callback.register("mnr_fuel:server:GetPlayerMoney", function(source)
	local cashMoney, bankMoney = server.GetPlayerMoney(source)

	return cashMoney, bankMoney
end)

---@description Zones Handling
RegisterNetEvent("mnr_fuel:server:EnterStation", function(name)
    local station = Config.GasStations[name]

    if not source or not station then return end
    
    local stationCoords = station.coords
    local stationRadius = station.radius
    local playerPed = GetPlayerPed(source)
    local playerCoords = GetEntityCoords(playerPed)

    if #(playerCoords - stationCoords) > stationRadius then return end

    InStation[source] = name
end)

RegisterNetEvent("mnr_fuel:server:ExitStation", function()
    if not source then return end

    InStation[source] = nil
end)

local function setFuel(netID, fuelAmount)
	local vehicle = NetworkGetEntityFromNetworkId(netID)
	if vehicle == 0 or GetEntityType(vehicle) ~= 2 then return end

	local vehicleState = Entity(vehicle)?.state
	local fuelLevel = vehicleState.fuel

	local fuel = fuelLevel + fuelAmount

	vehicleState:set("fuel", fuel, true)
end

RegisterNetEvent("mnr_fuel:server:ElaborateAction", function(data)
	if not source then return end

	local price = data.PT == "fuel" and math.ceil(data.Amount * GlobalState.fuelPrice) or Config.JerrycanPrice
	local playerMoney = server.GetPlayerMoney(source, data.PM)
	if playerMoney < price then return server.Notify(source, locale("notify.not-enough-money"), "error") end

	if data.PT == "fuel" then
		if not server.PayMoney(source, data.PM, price) then return end

		local fuelAmount = math.floor(data.Amount)
		setFuel(data.NetID, fuelAmount)

		TriggerClientEvent("mnr_fuel:client:PlayRefuelAnim", source, {NetID = data.NetID, Amount = data.Amount}, true)
	elseif data.PT == "jerrycan" then
		if playerState.holding == "jerrycan" then
			local item, durability = inventory.GetJerrycan(source)
			if not item or item.name ~= "WEAPON_PETROLCAN" then return end
			if durability > 0 then return server.Notify(source, locale("notify.jerrycan-not-empty"), "error") end

			if not server.PayMoney(source, data.PM, price) then return end
			inventory.UpdateJerrycan(source, item, 100)
		else
			if not inventory.CanCarry(source, "WEAPON_PETROLCAN") then
				return server.Notify(source, locale("notify.not-enough-space"), "error")
			end

			if not server.PayMoney(source, data.PM, price) then return end

			inventory.AddItem(source, "WEAPON_PETROLCAN", 1)
		end
	end
end)

RegisterNetEvent("mnr_fuel:server:RefuelVehicle", function(data)
	if not source or not data.entity then return end
	local playerState = Player(source).state
	if playerState.holding ~= "jerrycan" then return end

	local vehicle = NetworkGetEntityFromNetworkId(data.entity)
	if vehicle == 0 or GetEntityType(vehicle) ~= 2 then return end

	local vehicleState = Entity(vehicle)?.state
	local fuelLevel = math.ceil(vehicleState.fuel)
	local requiredFuel = 100 - fuelLevel
	if requiredFuel <= 0 then return server.Notify(source, locale("notify.vehicle-full"), "error") end

	local item, durability = inventory.GetJerrycan(source)
	if not item or durability <= 0 then return end

	local newDurability = math.floor(durability - requiredFuel)
	inventory.UpdateJerrycan(source, item, newDurability)

	setFuel(data.entity, requiredFuel)
	TriggerClientEvent("mnr_fuel:client:PlayRefuelAnim", source, {NetID = data.entity, Amount = requiredFuel}, false)
end)