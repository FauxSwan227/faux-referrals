local state = {
  redemptions = {},
  codeStats = {},
  ownerCache = {},
  audit = {}
}

local dataFile = 'referral_state.json'

local function debugPrint(...)
  if Config.Debug then
    print('[faux-referrals]', ...)
  end
end

local function normalizeCode(code)
  return string.upper(tostring(code or ''):gsub('%s+', ''):gsub('[^A-Z0-9%-_]', ''))
end

local function tableLength(value)
  local count = 0
  for _ in pairs(value or {}) do count = count + 1 end
  return count
end

local function loadState()
  local raw = LoadResourceFile(GetCurrentResourceName(), dataFile)
  if not raw or raw == '' then return end
  local decoded = json.decode(raw)
  if type(decoded) == 'table' then
    state.redemptions = decoded.redemptions or {}
    state.codeStats = decoded.codeStats or {}
    state.ownerCache = decoded.ownerCache or {}
    state.audit = decoded.audit or {}
  end
end

local function saveState()
  SaveResourceFile(GetCurrentResourceName(), dataFile, json.encode(state), -1)
end

local function primaryIdentifier(source)
  local fallback = 'source:' .. tostring(source)
  local identifiers = GetPlayerIdentifiers(source)
  for _, identifier in ipairs(identifiers) do
    if identifier:find('license:', 1, true) == 1 then return identifier end
  end
  return identifiers[1] or fallback
end

local function discordId(source)
  for _, identifier in ipairs(GetPlayerIdentifiers(source)) do
    local id = identifier:match('discord:(%d+)')
    if id then return id end
  end
  return nil
end

local function ensurePlayerLedger(identifier)
  state.redemptions[identifier] = state.redemptions[identifier] or {
    creatorCode = nil,
    adminCodes = {}
  }
  return state.redemptions[identifier]
end

local function adminCodeConfig(code)
  return Config.AdminCodes[code]
end

local function isExpired(config)
  if not config or not config.expiresAt then return false end
  local year, month, day, hour, min, sec = config.expiresAt:match('^(%d+)%-(%d+)%-(%d+)T?(%d*):?(%d*):?(%d*)')
  if not year then return false end
  local expiry = os.time({
    year = tonumber(year),
    month = tonumber(month),
    day = tonumber(day),
    hour = tonumber(hour) or 23,
    min = tonumber(min) or 59,
    sec = tonumber(sec) or 59
  })
  return os.time() > expiry
end

local function websiteUrl(path)
  return (Config.Website.baseUrl:gsub('/+$', '')) .. path
end

local function websiteHeaders()
  return {
    ['Content-Type'] = 'application/json',
    ['X-RadiantCoast-Bridge-Key'] = Config.Website.bridgeKey
  }
end

local function httpJson(method, path, body, cb)
  if not Config.Website.enabled then
    cb(false, nil, 0)
    return
  end

  PerformHttpRequest(websiteUrl(path), function(status, response)
    local ok = status >= 200 and status < 300
    local decoded = nil
    if response and response ~= '' then
      decoded = json.decode(response)
    end
    cb(ok, decoded, status)
  end, method, body and json.encode(body) or '', websiteHeaders())
end

local function validateCreatorCode(code, cb)
  if not Config.CreatorCodes.enabled then
    cb(nil)
    return
  end

  if Config.Website.enabled and Config.Website.validationPath then
    httpJson('GET', Config.Website.validationPath:format(code), nil, function(ok, data)
      if ok and data and data.ok and data.valid then
        cb({
          type = 'creator',
          code = code,
          label = data.label or Config.CreatorCodes.label,
          ownerDiscordId = data.ownerDiscordId or data.discordId,
          ownerName = data.ownerName or data.creatorName,
          platform = data.platform,
          rewards = data.rewards or Config.CreatorCodes.rewards
        })
        return
      end

      if Config.Website.requireCreatorValidation then
        cb(false)
        return
      end

      if code:match(Config.CreatorCodes.fallbackPattern) then
        cb({
          type = 'creator',
          code = code,
          label = Config.CreatorCodes.label,
          rewards = Config.CreatorCodes.rewards
        })
        return
      end

      cb(nil)
    end)
    return
  end

  if code:match(Config.CreatorCodes.fallbackPattern) then
    cb({
      type = 'creator',
      code = code,
      label = Config.CreatorCodes.label,
      rewards = Config.CreatorCodes.rewards
    })
    return
  end

  cb(nil)
end

local function resolveCode(code, cb)
  local admin = adminCodeConfig(code)
  if admin then
    if isExpired(admin) then
      cb(nil, 'expired')
      return
    end
    local uses = state.codeStats[code] and state.codeStats[code].uses or 0
    if admin.maxUses and uses >= admin.maxUses then
      cb(nil, 'max_uses')
      return
    end
    cb({
      type = 'admin',
      code = code,
      label = admin.label or 'Admin Code',
      issuedBy = admin.issuedBy or 'Management',
      rewards = admin.rewards or {}
    })
    return
  end

  validateCreatorCode(code, function(result)
    if result == false then
      cb(nil, 'website_rejected')
      return
    end
    cb(result, result and nil or 'not_found')
  end)
end

local function rewardLabels(rewards)
  local labels = {}
  for _, reward in ipairs(rewards or {}) do
    labels[#labels + 1] = reward.label or reward.name or reward.model or reward.type
  end
  return labels
end

local function grantRewards(source, rewards)
  local granted = {}
  for _, reward in ipairs(rewards or {}) do
    local ok = Config.GrantReward(source, reward)
    granted[#granted + 1] = {
      type = reward.type,
      label = reward.label or reward.name or reward.model or reward.type,
      ok = ok
    }
  end
  return granted
end

local function appendAudit(entry)
  state.audit[#state.audit + 1] = entry
  while #state.audit > 250 do
    table.remove(state.audit, 1)
  end
end

local function sendBridgeEvent(entry)
  if not Config.Website.enabled then return end
  httpJson('POST', Config.Website.eventPath, {
    referralCode = entry.code,
    eventType = 'claim',
    fivemIdentifier = entry.fivemIdentifier,
    discordId = entry.discordId,
    source = Config.ResourceName,
    metadata = {
      codeType = entry.type,
      characterName = entry.characterName,
      playerName = entry.playerName,
      ownerDiscordId = entry.ownerDiscordId,
      rewards = entry.rewardLabels,
      sourceResource = GetCurrentResourceName()
    }
  }, function(ok, data, status)
    debugPrint('bridge event', ok, status, data and data.id or 'no-id')
  end)
end

local function checkMilestones(entry)
  if entry.type ~= 'creator' then return end

  local milestones = Config.Milestones.creator or {}
  local stats = state.codeStats[entry.code]
  stats.milestones = stats.milestones or {}

  for _, milestone in ipairs(milestones) do
    local key = tostring(milestone.uses)
    if stats.uses >= milestone.uses and not stats.milestones[key] then
      stats.milestones[key] = {
        reachedAt = os.time(),
        label = milestone.label,
        rewards = rewardLabels(milestone.rewards)
      }

      appendAudit({
        event = 'milestone_reached',
        code = entry.code,
        ownerDiscordId = entry.ownerDiscordId,
        uses = stats.uses,
        milestone = milestone.label,
        rewards = rewardLabels(milestone.rewards),
        at = os.time()
      })

      if entry.ownerDiscordId then
        state.ownerCache[entry.ownerDiscordId] = state.ownerCache[entry.ownerDiscordId] or {}
        state.ownerCache[entry.ownerDiscordId].pendingMilestones = state.ownerCache[entry.ownerDiscordId].pendingMilestones or {}
        state.ownerCache[entry.ownerDiscordId].pendingMilestones[#state.ownerCache[entry.ownerDiscordId].pendingMilestones + 1] = {
          code = entry.code,
          label = milestone.label,
          rewards = rewardLabels(milestone.rewards),
          reachedAt = os.time()
        }
      end
    end
  end
end

local function redeem(source, rawCode)
  local code = normalizeCode(rawCode)
  if code == '' then
    Config.Notify(source, 'Enter a referral code first.', 'error')
    TriggerClientEvent('faux-referrals:client:redeemResult', source, { ok = false, message = 'Enter a referral code first.' })
    return
  end

  local identifier = primaryIdentifier(source)
  local playerLedger = ensurePlayerLedger(identifier)

  resolveCode(code, function(definition, reason)
    if not definition then
      local message = reason == 'website_rejected' and Config.Notifications.unavailable or Config.Notifications.invalid
      Config.Notify(source, message, 'error')
      TriggerClientEvent('faux-referrals:client:redeemResult', source, { ok = false, code = code, message = message })
      return
    end

    if definition.type == 'creator' and playerLedger.creatorCode then
      Config.Notify(source, Config.Notifications.duplicateCreator, 'error')
      TriggerClientEvent('faux-referrals:client:redeemResult', source, { ok = false, code = code, message = Config.Notifications.duplicateCreator })
      return
    end

    if definition.type == 'admin' and playerLedger.adminCodes[code] then
      Config.Notify(source, Config.Notifications.duplicateAdmin, 'error')
      TriggerClientEvent('faux-referrals:client:redeemResult', source, { ok = false, code = code, message = Config.Notifications.duplicateAdmin })
      return
    end

    local entry = {
      code = code,
      type = definition.type,
      label = definition.label,
      fivemIdentifier = identifier,
      discordId = discordId(source),
      playerName = GetPlayerName(source),
      characterName = Config.GetCharacterName(source),
      ownerDiscordId = definition.ownerDiscordId,
      ownerName = definition.ownerName,
      platform = definition.platform,
      rewards = grantRewards(source, definition.rewards),
      rewardLabels = rewardLabels(definition.rewards),
      redeemedAt = os.time()
    }

    if definition.type == 'creator' then
      playerLedger.creatorCode = code
    else
      playerLedger.adminCodes[code] = true
    end

    state.codeStats[code] = state.codeStats[code] or {
      type = definition.type,
      label = definition.label,
      issuedBy = definition.issuedBy,
      ownerDiscordId = definition.ownerDiscordId,
      ownerName = definition.ownerName,
      platform = definition.platform,
      uses = 0,
      players = {},
      milestones = {}
    }

    local stats = state.codeStats[code]
    stats.type = definition.type
    stats.label = definition.label
    stats.ownerDiscordId = definition.ownerDiscordId or stats.ownerDiscordId
    stats.ownerName = definition.ownerName or stats.ownerName
    stats.platform = definition.platform or stats.platform
    stats.uses = (stats.uses or 0) + 1
    stats.lastUsedAt = entry.redeemedAt
    stats.players[#stats.players + 1] = {
      fivemIdentifier = identifier,
      discordId = entry.discordId,
      playerName = entry.playerName,
      characterName = entry.characterName,
      redeemedAt = entry.redeemedAt
    }

    appendAudit({
      event = 'redeemed',
      code = code,
      type = definition.type,
      fivemIdentifier = identifier,
      discordId = entry.discordId,
      characterName = entry.characterName,
      playerName = entry.playerName,
      rewards = entry.rewardLabels,
      at = entry.redeemedAt
    })

    checkMilestones(entry)
    saveState()
    sendBridgeEvent(entry)

    local message = Config.Notifications.redeemed .. ' Rewards: ' .. table.concat(entry.rewardLabels, ', ')
    Config.Notify(source, message, 'success')
    TriggerClientEvent('faux-referrals:client:redeemResult', source, { ok = true, code = code, message = message, rewards = entry.rewardLabels })
    TriggerClientEvent('faux-referrals:client:panelData', source, buildPanelPayload(source))
  end)
end

local function fetchCreatorOwner(source, cb)
  local sourceDiscord = discordId(source)
  if not sourceDiscord or not Config.Website.enabled then
    cb()
    return
  end

  httpJson('GET', Config.Website.creatorByDiscordPath:format(sourceDiscord), nil, function(ok, data)
    if ok and data and data.found then
      state.ownerCache[sourceDiscord] = state.ownerCache[sourceDiscord] or {}
      state.ownerCache[sourceDiscord].referralCode = data.referralCode
      state.ownerCache[sourceDiscord].creatorName = data.creatorName
      state.ownerCache[sourceDiscord].platform = data.platform
      saveState()
    end
    cb()
  end)
end

function buildPanelPayload(source)
  local sourceDiscord = discordId(source)
  local isAdmin = IsPlayerAceAllowed(source, Config.AdminAce)
  local payload = {
    viewer = {
      isAdmin = isAdmin,
      discordId = sourceDiscord,
      characterName = Config.GetCharacterName(source),
      playerName = GetPlayerName(source)
    },
    ownCreator = nil,
    codes = {},
    audit = {}
  }

  local owner = sourceDiscord and state.ownerCache[sourceDiscord] or nil
  if owner and owner.referralCode then
    local stats = state.codeStats[owner.referralCode] or {
      type = 'creator',
      label = Config.CreatorCodes.label,
      uses = 0,
      players = {},
      milestones = {}
    }
    payload.ownCreator = {
      code = owner.referralCode,
      creatorName = owner.creatorName,
      platform = owner.platform,
      stats = stats,
      pendingMilestones = owner.pendingMilestones or {}
    }
    payload.codes[#payload.codes + 1] = { code = owner.referralCode, stats = stats }
  end

  if isAdmin then
    for code, config in pairs(Config.AdminCodes) do
      payload.codes[#payload.codes + 1] = {
        code = code,
        definition = {
          label = config.label,
          issuedBy = config.issuedBy,
          maxUses = config.maxUses,
          expiresAt = config.expiresAt,
          rewards = rewardLabels(config.rewards)
        },
        stats = state.codeStats[code] or {
          type = 'admin',
          label = config.label,
          issuedBy = config.issuedBy,
          uses = 0,
          players = {},
          milestones = {}
        }
      }
    end

    for i = #state.audit, math.max(1, #state.audit - 80), -1 do
      payload.audit[#payload.audit + 1] = state.audit[i]
    end
  end

  return payload
end

RegisterNetEvent('faux-referrals:server:redeemCode', function(code)
  redeem(source, code)
end)

RegisterNetEvent('faux-referrals:server:openPanel', function()
  local src = source
  fetchCreatorOwner(src, function()
    local payload = buildPanelPayload(src)
    if not payload.viewer.isAdmin and not payload.ownCreator then
      Config.Notify(src, Config.Notifications.noAccess, 'error')
      payload.limited = true
    end
    TriggerClientEvent('faux-referrals:client:openPanel', src, payload)
  end)
end)

RegisterNetEvent('faux-referrals:server:requestPanelData', function()
  local src = source
  fetchCreatorOwner(src, function()
    TriggerClientEvent('faux-referrals:client:panelData', src, buildPanelPayload(src))
  end)
end)

AddEventHandler('onResourceStart', function(resource)
  if resource ~= GetCurrentResourceName() then return end
  loadState()
  debugPrint(('loaded %s code stats and %s player ledgers'):format(tableLength(state.codeStats), tableLength(state.redemptions)))
end)

exports('RedeemCode', function(source, code)
  redeem(source, code)
end)

exports('GetCodeStats', function(code)
  return state.codeStats[normalizeCode(code)]
end)

exports('GetAllReferralState', function()
  return state
end)
