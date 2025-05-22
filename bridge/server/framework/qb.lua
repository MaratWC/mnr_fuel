---@diagnostic disable: duplicate-set-field, lowercase-global

if GetResourceState("qb-core") ~= "started" then return end

local QBCore = exports["qb-core"]:GetCoreObject()

server = {}

function server.Notify(source, msg, type)
    TriggerClientEvent("QBCore:Notify", source, msg, type)
end

function server.GetPlayerMoney(source, account)
    local Player = QBCore.Functions.GetPlayer(source)
    local cashMoney = Player.PlayerData.money["cash"]
    local bankMoney = Player.PlayerData.money["bank"]

    if account == "bank" then
        return bankMoney
    elseif account == "cash" then
        return cashMoney
    else
        return cashMoney, bankMoney
    end
end

function server.PayMoney(source, paymentMethod, amount)
    local Player = QBCore.Functions.GetPlayer(source)
    local paymentSuccess = Player.Functions.RemoveMoney(paymentMethod, amount)

    return paymentSuccess
end