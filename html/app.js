const app = document.querySelector('#app');
const tabs = document.querySelectorAll('[data-tab]');
const panels = document.querySelectorAll('[data-panel]');
const redeemForm = document.querySelector('[data-redeem-form]');
const resultNode = document.querySelector('[data-result]');
const metricsNode = document.querySelector('[data-metrics]');
const codeGrid = document.querySelector('[data-code-grid]');
const activityNode = document.querySelector('[data-activity]');
const accessNode = document.querySelector('[data-access]');

let state = {
  viewer: {},
  codes: [],
  audit: [],
  ownCreator: null,
  limited: false
};

function nui(name, data = {}) {
  if (typeof GetParentResourceName !== 'function') return Promise.resolve();

  return fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data)
  }).catch(() => {});
}

function escapeHtml(value = '') {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function formatDate(value) {
  if (!value) return 'Never';
  return new Date(Number(value) * 1000).toLocaleString();
}

function setTab(name) {
  tabs.forEach((tab) => tab.classList.toggle('active', tab.dataset.tab === name));
  panels.forEach((panel) => panel.classList.toggle('hidden', panel.dataset.panel !== name));
}

function renderAccess() {
  const labels = [];
  if (state.viewer?.isAdmin) labels.push('Management');
  if (state.ownCreator) labels.push('Creator');
  accessNode.textContent = labels.length ? labels.join(' + ') : 'Player';
}

function renderMetrics() {
  const totalUses = state.codes.reduce((sum, item) => sum + Number(item.stats?.uses || 0), 0);
  const uniquePlayers = new Set();
  state.codes.forEach((item) => {
    (item.stats?.players || []).forEach((player) => uniquePlayers.add(player.fivemIdentifier));
  });

  metricsNode.innerHTML = [
    ['Tracked Codes', state.codes.length],
    ['Total Uses', totalUses],
    ['Unique Players', uniquePlayers.size]
  ].map(([label, value]) => `
    <article class="metric">
      <span>${escapeHtml(label)}</span>
      <strong>${escapeHtml(value)}</strong>
    </article>
  `).join('');
}

function renderCodes() {
  if (!state.codes.length) {
    codeGrid.innerHTML = `
      <article class="code-card">
        <span>No dashboard access yet</span>
        <h3>Redeem a code or connect an accepted Lighthouse creator Discord ID.</h3>
      </article>
    `;
    return;
  }

  codeGrid.innerHTML = state.codes.map((item) => {
    const stats = item.stats || {};
    const players = (stats.players || []).slice(-5).reverse();
    const rewards = item.definition?.rewards || [];
    return `
      <article class="code-card">
        <header>
          <div>
            <span>${escapeHtml(stats.type || item.definition?.label || 'Referral')}</span>
            <h3>${escapeHtml(item.code)}</h3>
          </div>
          <strong class="uses">${Number(stats.uses || 0)}</strong>
        </header>
        ${rewards.length ? `<p class="muted">${escapeHtml(rewards.join(', '))}</p>` : ''}
        <div class="player-list">
          ${players.length ? players.map((player) => `
            <div class="player-row">
              <strong>${escapeHtml(player.characterName || player.playerName || 'Unknown')}</strong>
              <span>${escapeHtml(player.discordId ? `Discord ${player.discordId}` : 'No Discord ID')}</span>
              <span class="pill">${formatDate(player.redeemedAt)}</span>
            </div>
          `).join('') : '<span>No claims yet.</span>'}
        </div>
      </article>
    `;
  }).join('');
}

function renderActivity() {
  const rows = state.audit.length
    ? state.audit
    : state.codes.flatMap((item) => (item.stats?.players || []).map((player) => ({
      event: 'redeemed',
      code: item.code,
      type: item.stats?.type,
      characterName: player.characterName,
      discordId: player.discordId,
      at: player.redeemedAt
    }))).sort((a, b) => Number(b.at || 0) - Number(a.at || 0));

  activityNode.innerHTML = rows.length ? rows.slice(0, 80).map((entry) => `
    <article class="activity-item">
      <strong>${escapeHtml(entry.characterName || entry.playerName || entry.milestone || 'Referral event')}</strong>
      <span>${escapeHtml(entry.code || '')} ${entry.discordId ? `- ${entry.discordId}` : ''}</span>
      <span class="pill">${escapeHtml(entry.event || entry.type || 'claim')} - ${formatDate(entry.at || entry.reachedAt)}</span>
    </article>
  `).join('') : '<article class="activity-item"><strong>No referral activity yet.</strong><span></span><span class="pill">Ready</span></article>';
}

function render(payload = state) {
  state = {
    ...state,
    ...payload,
    viewer: payload.viewer || state.viewer || {},
    codes: payload.codes || state.codes || [],
    audit: payload.audit || state.audit || []
  };

  renderAccess();
  renderMetrics();
  renderCodes();
  renderActivity();
}

document.addEventListener('click', (event) => {
  const tab = event.target.closest('[data-tab]');
  if (tab) {
    setTab(tab.dataset.tab);
    return;
  }

  if (event.target.closest('[data-close]')) {
    app.classList.add('hidden');
    nui('close');
    return;
  }

  if (event.target.closest('[data-refresh]')) {
    nui('refresh');
  }
});

redeemForm.addEventListener('submit', (event) => {
  event.preventDefault();
  const code = new FormData(redeemForm).get('code');
  resultNode.textContent = 'Checking referral signal...';
  nui('redeem', { code });
});

document.addEventListener('keyup', (event) => {
  if (event.key === 'Escape') {
    app.classList.add('hidden');
    nui('close');
  }
});

window.addEventListener('message', (event) => {
  const { action, payload } = event.data || {};

  if (action === 'open') {
    render(payload || {});
    app.classList.remove('hidden');
    return;
  }

  if (action === 'close') {
    app.classList.add('hidden');
    return;
  }

  if (action === 'panelData') {
    render(payload || {});
    return;
  }

  if (action === 'redeemResult') {
    resultNode.textContent = payload?.message || 'Referral response received.';
    if (payload?.ok) nui('refresh');
  }
});

if (location.hostname === 'localhost' || location.hostname === '127.0.0.1') {
  render({
    viewer: { isAdmin: true, characterName: 'Alex Coast' },
    codes: [
      {
        code: 'RC1-00A',
        stats: {
          type: 'creator',
          uses: 18,
          players: [
            { characterName: 'Mina Vale', discordId: '1234567890', redeemedAt: Math.floor(Date.now() / 1000) - 3600 },
            { characterName: 'Drew Stone', discordId: '2234567890', redeemedAt: Math.floor(Date.now() / 1000) - 7200 }
          ]
        }
      },
      {
        code: 'WELCOME26',
        definition: { rewards: ['$25,000 Bank', 'Water x5', 'Sandwich x5'] },
        stats: { type: 'admin', uses: 44, players: [] }
      }
    ],
    audit: []
  });
  app.classList.remove('hidden');
}
