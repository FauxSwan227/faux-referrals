Config = {}

Config.Debug = false
Config.ResourceName = 'faux-referrals'

Config.Commands = {
  redeem = 'redeem',
  panel = 'referrals'
}

Config.AdminAce = 'fauxreferrals.manage'

Config.Framework = {
  name = 'auto', -- auto, qb, qbox, esx, standalone
  qbResource = 'qb-core',
  esxExport = 'es_extended'
}

Config.Website = {
  enabled = true,
  baseUrl = 'https://your-domain.com',
  bridgeKey = 'replace-with-a-long-random-secret',
  timeoutMs = 7000,

  -- Existing bridge endpoints from docs/FIVEM_BRIDGE.md.
  eventPath = '/api/fivem/referrals/events',
  summaryPath = '/api/fivem/referrals/%s',
  creatorByDiscordPath = '/api/fivem/referrals/discord/%s',

  -- Add this endpoint to the website for accepted/rejected creator-code truth.
  -- See docs/WEBSITE_CONTRACT.md.
  validationPath = '/api/fivem/referrals/validate/%s',
  requireCreatorValidation = true
}

Config.CreatorCodes = {
  enabled = true,
  type = 'creator',
  label = 'Lighthouse Creator',
  allowOnlyOnePerPlayer = true,
  fallbackPattern = '^[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]?%-[%w]+$',
  rewards = {
    { type = 'money', account = 'cash', amount = 15000, label = '$15,000 Cash' },
    { type = 'item', name = 'phone', amount = 1, label = 'Starter Phone' }
  }
}

Config.AdminCodes = {
  WELCOME26 = {
    label = 'Welcome Package',
    issuedBy = 'Management',
    expiresAt = nil,
    maxUses = nil,
    rewards = {
      { type = 'money', account = 'bank', amount = 25000, label = '$25,000 Bank' },
      { type = 'item', name = 'water', amount = 5, label = 'Water x5' },
      { type = 'item', name = 'sandwich', amount = 5, label = 'Sandwich x5' }
    }
  },
  COASTCAR = {
    label = 'Launch Vehicle',
    issuedBy = 'Management',
    expiresAt = nil,
    maxUses = 50,
    rewards = {
      { type = 'vehicle', model = 'blista', garage = 'pillboxgarage', label = 'Blista' }
    }
  }
}

Config.Milestones = {
  creator = {
    {
      uses = 10,
      label = 'First Wave',
      rewards = {
        { type = 'money', account = 'bank', amount = 50000, label = '$50,000 Bank' }
      }
    },
    {
      uses = 25,
      label = 'Coast Signal',
      rewards = {
        { type = 'item', name = 'radio', amount = 1, label = 'Radio' },
        { type = 'money', account = 'bank', amount = 100000, label = '$100,000 Bank' }
      }
    },
    {
      uses = 50,
      label = 'Lighthouse Legend',
      rewards = {
        { type = 'vehicle', model = 'sultan', garage = 'pillboxgarage', label = 'Sultan' },
        { type = 'money', account = 'bank', amount = 250000, label = '$250,000 Bank' }
      }
    }
  }
}

Config.Notifications = {
  redeemed = 'Referral redeemed.',
  duplicateCreator = 'You have already redeemed a creator referral code.',
  duplicateAdmin = 'You have already redeemed this admin referral code.',
  invalid = 'That referral code is not active.',
  unavailable = 'Referral validation is unavailable. Please try again later.',
  noAccess = 'You do not have referral dashboard access.'
}

Config.Notify = function(source, message, kind)
  TriggerClientEvent('faux-referrals:client:notify', source, message, kind or 'info')
end

Config.GetCharacterName = function(source)
  local playerName = GetPlayerName(source) or ('Player ' .. tostring(source))

  if GetResourceState('qb-core') == 'started' then
    local QBCore = exports['qb-core']:GetCoreObject()
    local player = QBCore.Functions.GetPlayer(source)
    if player and player.PlayerData and player.PlayerData.charinfo then
      local info = player.PlayerData.charinfo
      return ((info.firstname or '') .. ' ' .. (info.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    end
  end

  if GetResourceState('es_extended') == 'started' then
    local ESX = exports['es_extended']:getSharedObject()
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer and xPlayer.getName then
      return xPlayer.getName()
    end
  end

  return playerName
end

Config.GrantReward = function(source, reward)
  if reward.type == 'money' then
    if GetResourceState('qb-core') == 'started' then
      local QBCore = exports['qb-core']:GetCoreObject()
      local player = QBCore.Functions.GetPlayer(source)
      if player then player.Functions.AddMoney(reward.account or 'cash', reward.amount or 0, 'referral-reward') return true end
    end

    if GetResourceState('es_extended') == 'started' then
      local ESX = exports['es_extended']:getSharedObject()
      local xPlayer = ESX.GetPlayerFromId(source)
      if xPlayer then
        if reward.account == 'bank' then xPlayer.addAccountMoney('bank', reward.amount or 0) else xPlayer.addMoney(reward.amount or 0) end
        return true
      end
    end
  end

  if reward.type == 'item' then
    if GetResourceState('qb-core') == 'started' then
      local QBCore = exports['qb-core']:GetCoreObject()
      local player = QBCore.Functions.GetPlayer(source)
      if player then player.Functions.AddItem(reward.name, reward.amount or 1) return true end
    end

    if GetResourceState('es_extended') == 'started' then
      local ESX = exports['es_extended']:getSharedObject()
      local xPlayer = ESX.GetPlayerFromId(source)
      if xPlayer then xPlayer.addInventoryItem(reward.name, reward.amount or 1) return true end
    end
  end

  if reward.type == 'vehicle' then
    TriggerEvent('faux-referrals:server:grantVehicle', source, reward)
    return true
  end

  return false
end
