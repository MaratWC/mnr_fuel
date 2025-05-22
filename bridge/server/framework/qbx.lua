---@diagnostic disable: duplicate-set-field, lowercase-global

if GetResourceState("qbx_core") ~= "started" then return end

local QBX = exports.qbx_core

server = {}

function server.Notify(source, msg, type)
    TriggerClientEvent("ox_lib:notify", source, {
        description = msg,
        position = "top",
        type = type or "inform",
    })
end

function server.GetPlayerMoney(source, account)
    local player = QBX:GetPlayer(source)
    local cashMoney = player.PlayerData.money["cash"]
    local bankMoney = player.PlayerData.money["bank"]

    if account == "bank" then
        return bankMoney
    elseif account == "cash" then
        return cashMoney
    else
        return cashMoney, bankMoney
    end
end

function server.PayMoney(source, paymentMethod, amount)
    local player = QBX:GetPlayer(source)
    local paymentSuccess = player.Functions.RemoveMoney(paymentMethod, amount)

    return paymentSuccess
end