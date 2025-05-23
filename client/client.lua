local Config = lib.load("config.config")
local utils = lib.load("client.utils")

local Stations = {Blips = {}, Zones = {}}
local FuelEntities = {nozzle = nil, rope = nil}

---@description Init Functions
local function InitTargets()
	target.AddGlobalVehicle()

	for model, data in pairs(Config.Pumps) do
		target.AddModel(model, data.type == "ev")
	end
end

local function CreateStationZone(name, data)
	Stations.Zones[name] = lib.zones.sphere({
		coords = data.coords,
		radius = data.radius,
		onEnter = function(self)
			TriggerServerEvent("mnr_fuel:server:EnterStation", name)
		end,
		onExit = function(self)
			TriggerServerEvent("mnr_fuel:server:ExitStation")
		end,
		debug = data.debug,
	})
end

local function CreateStationBlip(coords, name, ev)
	Stations.Blips[name] = utils.CreateBlip(coords, ev)
end

local function InitFuelStates()
    local playerState = LocalPlayer.state
    playerState:set("holding", "null", true)
    playerState:set("refueling", false, true)
end

local function InitGasStations()
	for name, data in pairs(Config.GasStations) do
		CreateStationZone(name, data)
		CreateStationBlip(data.coords, name, data.type == "ev")
	end
	InitTargets()
end

AddEventHandler("onClientResourceStart", function(resourceName)
    local scriptName = cache.resource or GetCurrentResourceName()
    if resourceName ~= scriptName then return end
    InitFuelStates()
    InitGasStations()
end)

---@description Stop Unload
local function SecureEntityDeletion()
    DeleteObject(FuelEntities.nozzle)
    RopeUnloadTextures()
    DeleteObject(FuelEntities.rope)
end

local function RemoveStationBlips()
	for _, blip in pairs(Stations.Blips) do
		RemoveBlip(blip)
	end
end

AddEventHandler("onResourceStop", function(resourceName)
	local scriptName = cache.resource or GetCurrentResourceName()
	if resourceName ~= scriptName then return end
	SecureEntityDeletion()
	target.RemoveGlobalVehicle()
	RemoveStationBlips()
end)

---@description Events
RegisterNetEvent("mnr_fuel:client:TakeNozzle", function(data, pumpType)
	if not data.entity or not CheckFuelState("take_nozzle") then return end

	local playerPed = cache.ped or PlayerPedId()
	lib.requestAnimDict("anim@am_hold_up@male", 300)
	if utils.LoadAudioBank() then
		PlaySoundFromEntity(-1, "mnr_take_fv_nozzle", data.entity, "mnr_fuel", true, 0)
	end
	TaskPlayAnim(playerPed, "anim@am_hold_up@male", "shoplift_high", 2.0, 8.0, -1, 50, 0, 0, 0, 0)
	Wait(300)
	StopAnimTask(playerPed, "anim@am_hold_up@male", "shoplift_high", 1.0)
	RemoveAnimDict("anim@am_hold_up@male")

	local pump = GetEntityModel(data.entity)
    local pumpCoords = GetEntityCoords(data.entity)
	local nozzleModel = Config.NozzleType[pumpType].hash
	local handOffset = Config.NozzleType[pumpType].offsets.hand
	local lefthand = GetPedBoneIndex(playerPed, 18905)
	FuelEntities.nozzle = CreateObject(nozzleModel, 1.0, 1.0, 1.0, true, true, false)
	AttachEntityToEntity(FuelEntities.nozzle, playerPed, lefthand, handOffset[1], handOffset[2], handOffset[3], handOffset[4], handOffset[5], handOffset[6], false, true, false, true, 0, true)

    RopeLoadTextures()
    while not RopeAreTexturesLoaded() do
        Wait(0)
        RopeLoadTextures()
    end
	FuelEntities.rope = AddRope(pumpCoords.x, pumpCoords.y, pumpCoords.z, 0.0, 0.0, 0.0, 3.0, Config.RopeType["fv"], 8.0 --[[ DON'T SET TO 0.0!!! GAME CRASH!]], 0.0, 1.0, false, false, false, 1.0, true)
	while not FuelEntities.rope do
		Wait(0)
	end
	ActivatePhysics(FuelEntities.rope)
	Wait(100)

	local playerCoords = GetEntityCoords(playerPed)
	local nozzlePos = GetEntityCoords(FuelEntities.nozzle)
	local nozzleOffset = Config.NozzleType[pumpType].offsets.rope
	nozzlePos = GetOffsetFromEntityInWorldCoords(FuelEntities.nozzle, nozzleOffset.x, nozzleOffset.y, nozzleOffset.z)
	local pumpHeading = GetEntityHeading(data.entity)
	local rotatedPumpOffset = utils.RotateOffset(Config.Pumps[pump].offset, pumpHeading)
	local newPumpCoords = pumpCoords + rotatedPumpOffset
	AttachEntitiesToRope(FuelEntities.rope, data.entity, FuelEntities.nozzle, newPumpCoords.x, newPumpCoords.y, newPumpCoords.z, nozzlePos.x, nozzlePos.y, nozzlePos.z, length, false, false, nil, nil)

	SetFuelState("holding", ("%s_nozzle"):format(pumpType))
	CreateThread(function()
		local playerState = LocalPlayer.state
		local nozzleName = ("%s_nozzle"):format(pumpType)
		while playerState.holding == nozzleName do
			local currentcoords = GetEntityCoords(playerPed)
			local dist = #(playerCoords - currentcoords)
			if not TargetCreated then if Config.FuelTargetExport then exports["ox_target"]:AllowRefuel(true) end end
			TargetCreated = true
			if dist > 7.5 then
				if TargetCreated then if Config.FuelTargetExport then exports["ox_target"]:AllowRefuel(false) end end
				TargetCreated = true
				SetFuelState("holding", "null")
				DeleteObject(FuelEntities.nozzle)
				RopeUnloadTextures()
				DeleteRope(FuelEntities.rope)
			end
			Wait(2500)
		end
	end)
end)

RegisterNetEvent("mnr_fuel:client:ReturnNozzle", function(data, pumpType)
	if not CheckFuelState("return_nozzle") then return end
	if utils.LoadAudioBank() then
		PlaySoundFromEntity(-1, ("mnr_return_%s_nozzle"):format(pumpType), data.entity, "mnr_fuel", true, 0)
	end
	SetFuelState("holding", "null")
	TargetCreated = false
	Wait(250)
	if Config.FuelTargetExport then exports["ox_target"]:AllowRefuel(false) end
	DeleteObject(FuelEntities.nozzle)
	RopeUnloadTextures()
	DeleteRope(FuelEntities.rope)
end)

local function SecondaryMenu(data)
	local totalCost = (data.PT == "fuel") and math.ceil(data.fuelAmount * GlobalState.fuelPrice) or Config.JerrycanPrice
	local vehNetID = (data.PT == "fuel") and NetworkGetEntityIsNetworked(data.Veh) and VehToNet(data.Veh)
	local cashMoney, bankMoney = lib.callback.await("mnr_fuel:server:GetPlayerMoney", false)

	lib.registerContext({
		id = "mnr_fuel:menu:payment",
		title = locale("menu.payment-title"):format(totalCost),
		options = {
			{
				title = locale("menu.payment-bank"),
				description = locale("menu.payment-bank-desc"):format(bankMoney),
				icon = "building-columns",
				onSelect = function()
					TriggerServerEvent("mnr_fuel:server:ElaborateAction", {
						NetID = vehNetID or false,
						PM = "bank",
						PT = data.PT,
						Amount = data.fuelAmount,
						Cost = totalCost,
					})
				end,
			},
			{
				title = locale("menu.payment-cash"),
				description = locale("menu.payment-cash-desc"):format(cashMoney),
				icon = "money-bill",
				onSelect = function()
					TriggerServerEvent("mnr_fuel:server:ElaborateAction", {
						NetID = vehNetID or false,
						PM = "cash",
						PT = data.PT,
						Amount = data.fuelAmount,
						Cost = totalCost,
					})
				end,
			},
		},
	})

	lib.registerContext({
		id = "mnr_fuel:menu:confirm",
		title = locale("menu.confirm-title"):format(totalCost),
		options = {
			{
				title = locale("menu.confirm-choice-title"),
				menu = "mnr_fuel:menu:payment",
				icon = "circle-check",
				iconColor = "#4CAF50",
			},
			{
				title = locale("menu.cancel-choice-title"),
				icon = "circle-xmark",
				iconColor = "#FF0000",
				onSelect = function()
					lib.hideContext()
				end,
			},
		},
	})

	lib.showContext("mnr_fuel:menu:confirm")
end

RegisterNetEvent("mnr_fuel:client:RefuelVehicle", function(data)
	if not data.entity or not CheckFuelState("refuel_nozzle") then return end

	local playerState = LocalPlayer.state
	local isElectric = GetIsVehicleElectric(GetEntityModel(data.entity))
	if playerState.holding == "ev_nozzle" and not isElectric then return client.Notify(locale("notify.not-ev"), "error") end
	if playerState.holding == "fv_nozzle" and isElectric then return client.Notify(locale("notify.not-fv"), "error") end

	local vehicleState = Entity(data.entity).state
	local currentFuel = vehicleState.fuel or GetVehicleFuelLevel(data.entity)

	local input = lib.inputDialog(locale("input.select-amount"), {
		{type = "slider", label = locale("input.select-amount"), default = currentFuel, min = 0, max = 100},
	})
	if not input then return end

	local inputFuel = tonumber(input[1])
	local fuelAmount = inputFuel - currentFuel
	if not fuelAmount then return end

	SecondaryMenu({Veh = data.entity, PT = "fuel", fuelAmount = fuelAmount})
end)

RegisterNetEvent("mnr_fuel:client:BuyJerrycan", function(data)
	if not data.entity or not CheckFuelState("buy_jerrycan") then return end

	SecondaryMenu({PT = "jerrycan"})
end)

RegisterNetEvent("mnr_fuel:client:PlayRefuelAnim", function(data, isPump)
	local playerState = LocalPlayer.state
	if isPump and not (playerState.holding == "fv_nozzle" or playerState.holding == "ev_nozzle") then return end
	if not isPump and not playerState.holding == "jerrycan" then return end

	local vehicle = NetToVeh(data.NetID)
	local playerPed = cache.ped or PlayerPedId()

	TaskTurnPedToFaceEntity(playerPed, vehicle, 500)
	Wait(500)

	local refuelTime = data.Amount * 2000
	SetFuelState("refueling", true)
	local pumpType = playerState.holding == "fv_nozzle" and "fv" or playerState.holding == "ev_nozzle" and "ev"
	local soundId = GetSoundId()
	if utils.LoadAudioBank() then
		PlaySoundFromEntity(soundId, ("mnr_%s_start"):format(pumpType), FuelEntities.nozzle, "mnr_fuel", true, 0)
	end
	if lib.progressCircle({
		duration = refuelTime,
		label = locale("progress.refueling-vehicle"),
		position = "bottom",
		useWhileDead = false,
		canCancel = false,
		anim = {
			dict = isPump and "timetable@gardener@filling_can" or "weapon@w_sp_jerrycan",
			clip = isPump and "gar_ig_5_filling_can" or "fire",
		},
		disable = {move = true, car = true, combat = true},
	}) then
		StopSound(soundId)
		ReleaseSoundId(soundId)
		PlaySoundFromEntity(-1, ("mnr_%s_stop"):format(pumpType), FuelEntities.nozzle, "mnr_fuel", true, 0)
		SetFuelState("refueling", false)
		client.Notify(locale("notify.refuel-success"), "success")
	end
end)
