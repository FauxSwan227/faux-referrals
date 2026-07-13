# Website Contract

`faux-referrals` uses the existing FiveM bridge key documented in `radiantcoast-web/docs/FIVEM_BRIDGE.md`.

The existing endpoints are enough to record claims and look up a creator code by Discord ID. For in-game code redemption, the resource also needs one truth endpoint so accepted creator codes validate and rejected creator codes do not.

## Validate A Referral Code

```text
GET /api/fivem/referrals/validate/RC1-00A
X-RadiantCoast-Bridge-Key: replace-with-a-long-random-secret
```

Successful accepted creator response:

```json
{
  "ok": true,
  "valid": true,
  "type": "creator",
  "referralCode": "RC1-00A",
  "ownerDiscordId": "123456789012345678",
  "ownerName": "CoastCam",
  "platform": "Twitch",
  "label": "Lighthouse Creator"
}
```

Rejected, pending, missing, or revoked response:

```json
{
  "ok": true,
  "valid": false,
  "reason": "not_active"
}
```

## Existing Bridge Events

After a successful in-game redemption, the resource posts to:

```text
POST /api/fivem/referrals/events
```

The payload includes `metadata.characterName`, `metadata.playerName`, `metadata.codeType`, `metadata.ownerDiscordId`, and the granted reward labels.

## Dashboard Owner Lookup

When a player opens `/referrals`, the resource uses:

```text
GET /api/fivem/referrals/discord/:discordId
```

If the Discord ID belongs to an accepted Lighthouse creator, the NUI shows that creator's code stats and claim ledger.
