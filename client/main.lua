local panelOpen = false

local function setPanelOpen(value)
  panelOpen = value
  SetNuiFocus(value, value)
  if not value then
    SendNUIMessage({ action = 'close' })
  end
end

RegisterNetEvent('faux-referrals:client:notify', function(message, kind)
  if GetResourceState('qb-core') == 'started' then
    local QBCore = exports['qb-core']:GetCoreObject()
    QBCore.Functions.Notify(message, kind or 'primary')
    return
  end

  if GetResourceState('es_extended') == 'started' then
    local ESX = exports['es_extended']:getSharedObject()
    ESX.ShowNotification(message)
    return
  end

  BeginTextCommandThefeedPost('STRING')
  AddTextComponentSubstringPlayerName(message)
  EndTextCommandThefeedPostTicker(false, false)
end)

RegisterNetEvent('faux-referrals:client:openPanel', function(payload)
  setPanelOpen(true)
  SendNUIMessage({
    action = 'open',
    payload = payload
  })
end)

RegisterNetEvent('faux-referrals:client:panelData', function(payload)
  SendNUIMessage({
    action = 'panelData',
    payload = payload
  })
end)

RegisterNetEvent('faux-referrals:client:redeemResult', function(payload)
  SendNUIMessage({
    action = 'redeemResult',
    payload = payload
  })
end)

RegisterCommand(Config.Commands.panel, function()
  TriggerServerEvent('faux-referrals:server:openPanel')
end, false)

RegisterCommand(Config.Commands.redeem, function(_, args)
  local code = table.concat(args or {}, ' ')
  if code == '' then
    TriggerServerEvent('faux-referrals:server:openPanel')
    return
  end

  TriggerServerEvent('faux-referrals:server:redeemCode', code)
end, false)

RegisterNUICallback('close', function(_, cb)
  setPanelOpen(false)
  cb({ ok = true })
end)

RegisterNUICallback('redeem', function(data, cb)
  TriggerServerEvent('faux-referrals:server:redeemCode', data and data.code or '')
  cb({ ok = true })
end)

RegisterNUICallback('refresh', function(_, cb)
  TriggerServerEvent('faux-referrals:server:requestPanelData')
  cb({ ok = true })
end)

CreateThread(function()
  while true do
    if panelOpen and IsControlJustReleased(0, 322) then
      setPanelOpen(false)
    end
    Wait(0)
  end
end)
