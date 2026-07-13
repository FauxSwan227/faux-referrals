# Faux Referrals

FiveM referral resource for RadiantCoast-style creator, streamer, admin, and management codes.

## What It Does

- Creator/streamer codes are validated against the website, so accepted Lighthouse applications are active and rejected/pending ones are not.
- Players can redeem only one creator code ever.
- Players can redeem multiple admin/management codes, but each admin code only once.
- Rewards support cash, bank money, items, and vehicle hooks.
- In-game `/referrals` NUI shows creator/admin code uses, IC names, Discord IDs, recent activity, and milestone progress.
- Successful claims are posted back to the website bridge from `docs/FIVEM_BRIDGE.md`.

## Install

1. Drop this folder into your FiveM resources.
2. Add `ensure faux-referrals` to `server.cfg`.
3. Set `Config.Website.baseUrl` and `Config.Website.bridgeKey` in `config.lua`.
4. Add this ACE permission for management dashboard access:

```cfg
add_ace group.admin fauxreferrals.manage allow
```

5. Add the validation endpoint described in [docs/WEBSITE_CONTRACT.md](docs/WEBSITE_CONTRACT.md) to the website. Copy-ready Node and DreamHost PHP snippets are in [website/radiantcoast-validation-endpoint.md](website/radiantcoast-validation-endpoint.md).

## Commands

- `/redeem CODE` redeems a referral code.
- `/redeem` opens the referral UI.
- `/referrals` opens the dashboard/redeem UI.

## Rewards

Configure creator rewards, admin codes, and creator milestones in `config.lua`.

Vehicle rewards trigger:

```lua
AddEventHandler('faux-referrals:server:grantVehicle', function(source, reward)
  -- Insert into your garage/owned vehicles table here.
  -- reward.model, reward.garage, reward.label are available.
end)
```

## Website Bridge

This resource uses the same `X-RadiantCoast-Bridge-Key` header as the existing bridge. The current bridge records events; the additional validation endpoint lets the FiveM server know whether a creator code belongs to an accepted Lighthouse application.
