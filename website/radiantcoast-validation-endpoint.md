# RadiantCoast Website Validation Endpoint

Add this before the existing summary route:

```js
app.get("/api/fivem/referrals/:code", requireFiveMBridge, ...)
```

The more specific `/validate/:code` route must be registered first, otherwise Express treats `validate` as the referral code.

## Node / Express

In `src/db.js`, add:

```js
export function getAcceptedCreatorReferralByCode(referralCode) {
  const row = db.prepare(`
    SELECT c.*, u.username, u.avatar
    FROM creator_applications c
    JOIN users u ON u.discord_id = c.discord_id
    WHERE c.referral_code = ? AND c.status = 'accepted'
    ORDER BY c.reviewed_at DESC
    LIMIT 1
  `).get(referralCode);
  return row ? hydrateCreatorApplication(row) : null;
}
```

In `src/server.js`, import it from `./db.js`, then add this route before `/api/fivem/referrals/:code`:

```js
app.get("/api/fivem/referrals/validate/:code", requireFiveMBridge, (req, res) => {
  const referralCode = String(req.params.code || "").trim().toUpperCase();
  if (!referralCode) return res.status(400).json({ error: "Referral code is required." });

  const creator = getAcceptedCreatorReferralByCode(referralCode);
  if (!creator) {
    return res.json({ ok: true, valid: false, reason: "not_active" });
  }

  res.json({
    ok: true,
    valid: true,
    type: "creator",
    referralCode: creator.referralCode,
    ownerDiscordId: creator.discordId,
    ownerName: creator.creatorName,
    platform: creator.platform,
    label: "Lighthouse Creator"
  });
});
```

## DreamHost PHP

In `api/index.php`, add this block before the existing `fivem/referrals/([^/]+)` summary route:

```php
if (preg_match('#^fivem/referrals/validate/([^/]+)$#', $route, $match) && $method === 'GET') {
    require_fivem_bridge();
    $referralCode = strtoupper(trim(urldecode($match[1])));
    if (!$referralCode) json_response(['error' => 'Referral code is required.'], 400);
    $creator = creator_referral_by_code($referralCode);
    if (!$creator) {
        json_response(['ok' => true, 'valid' => false, 'reason' => 'not_active']);
    }
    json_response([
        'ok' => true,
        'valid' => true,
        'type' => 'creator',
        'referralCode' => $creator['referralCode'],
        'ownerDiscordId' => $creator['discordId'],
        'ownerName' => $creator['creatorName'],
        'platform' => $creator['platform'],
        'label' => 'Lighthouse Creator',
    ]);
}
```

Add this helper beside the existing creator referral helpers:

```php
function creator_referral_by_code(string $referralCode): ?array {
    $stmt = db()->prepare(
        "SELECT c.*, u.username, u.avatar
         FROM creator_applications c
         JOIN users u ON u.discord_id = c.discord_id
         WHERE c.referral_code = ? AND c.status = 'accepted'
         ORDER BY c.reviewed_at DESC
         LIMIT 1"
    );
    $stmt->execute([$referralCode]);
    $row = $stmt->fetch();
    return $row ? public_creator_application($row) : null;
}
```
