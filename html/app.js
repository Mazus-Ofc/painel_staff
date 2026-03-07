const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'mz_staffpanel'
const app = document.getElementById('app')
const serverName = document.getElementById('serverName')
const statOnline = document.getElementById('statOnline')
const statMe = document.getElementById('statMe')
const statStaff = document.getElementById('statStaff')
const permPills = document.getElementById('permPills')
const playerRows = document.getElementById('playerRows')
const searchInput = document.getElementById('searchInput')
const quickActions = document.getElementById('quickActions')
const commandList = document.getElementById('commandList')
const vehicleSearchInput = document.getElementById('vehicleSearchInput')
const vehicleGrid = document.getElementById('vehicleGrid')

let state = { players: [], perms: {}, vehicles: [], stats: {} }

const commands = [
  ['/staffpanel', 'Abrir o painel'], ['/admin', 'Alias para abrir o painel'],
  ['/revive [id]', 'Reviver jogador'], ['/heal [id]', 'Curar jogador'],
  ['/goto [id]', 'Teleportar até o jogador'], ['/bring [id]', 'Trazer jogador até você'],
  ['/freeze [id]', 'Congelar/descongelar jogador'], ['/kill [id]', 'Matar jogador'], ['/slay [id]', 'Alias de kill'],
  ['/kick [id] [motivo]', 'Kickar jogador'], ['/kickall [motivo]', 'Kickar todos'],
  ['/ban [id] [segundos] [motivo]', 'Banir jogador'],
  ['/warn [id] [motivo]', 'Aplicar warn'], ['/checkwarns [id]', 'Ver warns'], ['/delwarn [id] [numero]', 'Remover warn'],
  ['/spectate [id]', 'Entrar no spectate avançado'], ['/spec [id]', 'Alias de spectate'], ['/specoff', 'Sair do spectate'],
  ['/noclip', 'Alternar noclip'], ['/invisible', 'Alternar invisibilidade'], ['/god', 'Alternar godmode'],
  ['/names', 'Alternar nomes'], ['/blips', 'Alternar blips'], ['/wall', 'Alternar wall'],
  ['/report [mensagem]', 'Enviar report'], ['/reportr [id] [mensagem]', 'Responder report'], ['/reporttoggle', 'Alternar reports'],
  ['/staffchat [mensagem]', 'Mensagem da staff'], ['/announce [mensagem]', 'Anúncio global'],
  ['/dim [dim]', 'Trocar sua dimensão'], ['/setdim [id] [dim]', 'Mover player de dimensão'],
  ['/car [spawn]', 'Gerar veículo'], ['/veh [spawn]', 'Alias de car'], ['/dv', 'Deletar veículo'], ['/admincar', 'Salvar carro na garagem'], ['/maxmods', 'Maxmods no carro atual'],
  ['/intovehicle [id]', 'Entrar no veículo do alvo'], ['/inventory [id]', 'Abrir inventário do alvo'], ['/cloth [id]', 'Abrir roupa do alvo'],
  ['/giveweapon [id] [arma] [ammo]', 'Dar arma'], ['/setmodel [model] [id]', 'Trocar modelo'], ['/setspeed [fast/normal] [id]', 'Trocar velocidade'], ['/setammo [qtd] [id]', 'Setar munição'],
  ['/coords', 'Mostrar coords na tela'], ['/vector2', 'Copiar vector2'], ['/vector3', 'Copiar vector3'], ['/vector4', 'Copiar vector4'], ['/heading', 'Copiar heading'],
  ['/givenuifocus [id] [focus] [mouse]', 'Dar foco NUI ao alvo']
]

const quickCards = [
  { key: 'noclip', title: 'Noclip', desc: 'Movimento livre.' },
  { key: 'invisible', title: 'Invisible', desc: 'Fica invisível.' },
  { key: 'god', title: 'God', desc: 'Invulnerabilidade.' },
  { key: 'names', title: 'Nomes', desc: 'Ver nomes sobre a cabeça.' },
  { key: 'blips', title: 'Blips', desc: 'Ver jogadores no mapa.' },
  { key: 'wall', title: 'Wall', desc: 'ESP integrado.' },
  { key: 'coords', title: 'Coords', desc: 'Mostrar vector4 na tela.' },
  { key: 'copyVector2', title: 'Vector2', desc: 'Copiar vector2.' },
  { key: 'copyVector3', title: 'Vector3', desc: 'Copiar vector3.' },
  { key: 'copyVector4', title: 'Vector4', desc: 'Copiar vector4.' },
  { key: 'copyHeading', title: 'Heading', desc: 'Copiar heading.' },
  { key: 'maxmods', title: 'Maxmods', desc: 'Tunagem máxima no carro.' },
  { key: 'saveVehicle', title: 'Salvar carro', desc: 'Salvar na garagem.' },
  { key: 'reporttoggle', title: 'Reports', desc: 'Ativar/desativar reports.' },
  { key: 'spectateStop', title: 'Sair do spec', desc: 'Encerra o spectate.' },
  { key: 'setMyDimension', title: 'Minha dimensão', desc: 'Trocar bucket atual.' },
  { key: 'deleteVehicle', title: 'DV', desc: 'Deletar carro atual ou próximo.' }
]

function nui(path, body = {}) {
  return fetch(`https://${resource}/${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(body)
  })
}

function setTab(name) {
  document.querySelectorAll('.nav').forEach(btn => btn.classList.toggle('active', btn.dataset.tab === name))
  document.querySelectorAll('.tab').forEach(tab => tab.classList.toggle('active', tab.id === `tab-${name}`))
}

document.querySelectorAll('.nav').forEach(btn => btn.addEventListener('click', () => setTab(btn.dataset.tab)))
document.getElementById('closeBtn').addEventListener('click', () => nui('close'))
document.getElementById('refreshBtn').addEventListener('click', () => nui('refresh'))
window.addEventListener('keydown', (e) => { if (e.key === 'Escape') nui('close') })
searchInput.addEventListener('input', renderPlayers)
if (vehicleSearchInput) vehicleSearchInput.addEventListener('input', renderVehicles)

function parseBool(v) {
  return v === true || v === 'true' || v === '1' || v === 1
}

function performAction(action, target = null, extra = {}) {
  const payload = { action, target, ...extra }

  if (action === 'kick' && !payload.reason) {
    const reason = prompt('Motivo do kick:', 'Removido pela staff')
    if (reason === null) return
    payload.reason = reason
  }

  if (action === 'ban' && (!payload.reason || !payload.seconds)) {
    const seconds = prompt('Tempo do ban em segundos:', '86400')
    if (seconds === null) return
    const reason = prompt('Motivo do ban:', 'Banido pela staff')
    if (reason === null) return
    payload.seconds = Number(seconds)
    payload.reason = reason
  }

  if (action === 'warn' && !payload.reason) {
    const reason = prompt('Motivo do warn:', 'Aviso da staff')
    if (reason === null) return
    payload.reason = reason
  }

  if (action === 'setMyDimension') {
    const raw = prompt('Digite a dimensão (0 = padrão):', '0')
    if (raw === null) return
    payload.dimension = Number(raw)
  }

  if (action === 'setDimension') {
    const raw = prompt(`Digite a dimensão para o ID ${target} (0 = padrão):`, '0')
    if (raw === null) return
    payload.dimension = Number(raw)
  }

  if (action === 'giveWeapon' && !payload.weapon) {
    const weapon = prompt('Nome da arma:', 'WEAPON_CARBINERIFLE')
    if (weapon === null) return
    const ammo = prompt('Munição:', '250')
    if (ammo === null) return
    payload.weapon = weapon
    payload.ammo = Number(ammo)
  }

  nui('action', payload)
}

function actionButton(label, action, target) {
  return `<button class="mini" data-action="${action}" data-target="${target}">${label}</button>`
}

function renderPerms() {
  permPills.innerHTML = ''
  const enabled = Object.entries(state.perms || {}).filter(([, v]) => v)
  enabled.forEach(([name]) => {
    const pill = document.createElement('span')
    pill.className = 'pill'
    pill.textContent = name
    permPills.appendChild(pill)
  })
}

function renderPlayers() {
  const term = (searchInput.value || '').toLowerCase()
  const rows = (state.players || []).filter(p => [String(p.id), p.name, p.citizenid, p.job, p.gang, (p.staff || []).join(' ')].join(' ').toLowerCase().includes(term))

  playerRows.innerHTML = rows.map(p => {
    const staffTags = (p.staff || []).length ? p.staff.map(s => `<span class="tag">${s}</span>`).join('') : '<span class="tag">-</span>'
    const actions = []
    if (state.perms.spectate) actions.push(actionButton('Spec', 'spectate', p.id))
    if (state.perms.revive) actions.push(actionButton('Reviver', 'revive', p.id))
    if (state.perms.heal) actions.push(actionButton('Heal', 'heal', p.id))
    if (state.perms.gotoPlayer) actions.push(actionButton('Ir', 'gotoPlayer', p.id))
    if (state.perms.bringPlayer) actions.push(actionButton('Trazer', 'bringPlayer', p.id))
    if (state.perms.intoVehicle) actions.push(actionButton('No carro', 'intoVehicle', p.id))
    if (state.perms.inventory) actions.push(actionButton('Inv', 'inventory', p.id))
    if (state.perms.clothing) actions.push(actionButton('Roupa', 'cloth', p.id))
    if (state.perms.freeze) actions.push(actionButton('Freeze', 'freeze', p.id))
    if (state.perms.kill) actions.push(actionButton('Matar', 'kill', p.id))
    if (state.perms.kick) actions.push(actionButton('Kick', 'kick', p.id))
    if (state.perms.ban) actions.push(actionButton('Ban', 'ban', p.id))
    if (state.perms.warn) actions.push(actionButton('Warn', 'warn', p.id))
    if (state.perms.giveWeapon) actions.push(actionButton('Arma', 'giveWeapon', p.id))
    if (state.perms.dimension) actions.push(actionButton('Dim', 'setDimension', p.id))

    return `
      <tr>
        <td>${p.id}</td>
        <td>${p.name}<br><small style="color:var(--muted)">${p.citizenid}</small></td>
        <td>${p.job}</td>
        <td>${p.gang}</td>
        <td>${staffTags}</td>
        <td>${p.ping}</td>
        <td><div class="row-actions">${actions.join('')}</div></td>
      </tr>
    `
  }).join('')

  document.querySelectorAll('.mini').forEach(btn => btn.addEventListener('click', () => performAction(btn.dataset.action, Number(btn.dataset.target))))
}

function renderQuickActions() {
  quickActions.innerHTML = ''
  quickCards.filter(card => {
    if (card.key.startsWith('copyVector')) return !!state.perms.vector
    if (card.key === 'copyHeading') return !!state.perms.heading
    if (card.key === 'setMyDimension') return !!state.perms.dimension
    return !!state.perms[card.key] || card.key === 'spectateStop'
  }).forEach(card => {
    const div = document.createElement('article')
    div.className = 'card action-card'
    div.innerHTML = `<h4>${card.title}</h4><p>${card.desc}</p><button class="btn">Executar</button>`
    div.querySelector('button').addEventListener('click', () => performAction(card.key))
    quickActions.appendChild(div)
  })
}

function renderVehicles() {
  if (!vehicleGrid) return
  if (!state.perms.spawnVehicle) {
    vehicleGrid.innerHTML = '<div class="vehicle-empty">Sem permissão para gerar veículos.</div>'
    return
  }

  const term = (vehicleSearchInput?.value || '').toLowerCase()
  const limit = Number(state.vehiclePreviewLimit || 120) || 120
  const vehicles = (state.vehicles || []).filter(v => [v.name, v.spawn, v.brand, v.category, v.shop].join(' ').toLowerCase().includes(term)).slice(0, limit)
  if (!vehicles.length) {
    vehicleGrid.innerHTML = '<div class="vehicle-empty">Nenhum veículo encontrado.</div>'
    return
  }

  vehicleGrid.innerHTML = vehicles.map(v => `
    <article class="vehicle-card">
      <div class="vehicle-thumb-wrap">
        <img class="vehicle-thumb" src="${v.image}" alt="${v.spawn}" onerror="this.style.display='none'; this.nextElementSibling.style.display='flex';" />
        <div class="vehicle-fallback" style="display:none">${v.spawn}</div>
      </div>
      <div class="vehicle-body">
        <strong>${v.name}</strong>
        <span>${v.brand} • ${v.category}</span>
        <code>${v.spawn}</code>
      </div>
      <button class="btn vehicle-btn" data-model="${v.spawn}">Gerar</button>
    </article>
  `).join('')

  document.querySelectorAll('.vehicle-btn').forEach(btn => btn.addEventListener('click', () => performAction('spawnVehicle', null, { model: btn.dataset.model })))
}

function renderCommands() {
  commandList.innerHTML = commands.map(([cmd, desc]) => `<div class="command-item"><code>${cmd}</code><div style="margin-top:8px;color:var(--muted)">${desc}</div></div>`).join('')
}

function bindForms() {
  document.getElementById('sendAnnounce')?.addEventListener('click', () => performAction('announce', null, { message: document.getElementById('announceMessage').value }))
  document.getElementById('sendStaffchat')?.addEventListener('click', () => performAction('staffchat', null, { message: document.getElementById('staffchatMessage').value }))
  document.getElementById('sendKickall')?.addEventListener('click', () => performAction('kickall', null, { reason: document.getElementById('kickallReason').value }))
  document.getElementById('sendReportReply')?.addEventListener('click', () => performAction('replyReport', Number(document.getElementById('reportReplyId').value), { message: document.getElementById('reportReplyMessage').value }))
  document.getElementById('sendSetModel')?.addEventListener('click', () => performAction('setmodel', Number(document.getElementById('setModelTarget').value) || null, { model: document.getElementById('setModelInput').value }))
  document.getElementById('sendSetSpeed')?.addEventListener('click', () => performAction('setspeed', Number(document.getElementById('setSpeedTarget').value) || null, { speed: document.getElementById('setSpeedInput').value }))
  document.getElementById('sendSetAmmo')?.addEventListener('click', () => performAction('setammo', Number(document.getElementById('setAmmoTarget').value) || null, { amount: Number(document.getElementById('setAmmoInput').value) }))
  document.getElementById('sendNuiFocus')?.addEventListener('click', () => performAction('givenuifocus', Number(document.getElementById('nuiFocusTarget').value) || null, { focus: document.getElementById('nuiFocusFlag').checked, mouse: document.getElementById('nuiMouseFlag').checked }))
}

window.addEventListener('message', (event) => {
  const { action, data } = event.data || {}
  if (action === 'visible') {
    app.classList.toggle('hidden', !data)
    if (data) setTab('dashboard')
  }
  if (action === 'hydrate' && data) {
    state = data
    serverName.textContent = data.theme?.serverName || 'Mazus Staff'
    statOnline.textContent = data.stats?.online || data.players?.length || 0
    statMe.textContent = data.me || 0
    statStaff.textContent = data.stats?.staffOnline || 0
    renderPerms(); renderPlayers(); renderQuickActions(); renderVehicles(); renderCommands()
  }
  if (action === 'clipboard' && typeof data === 'string') {
    const el = document.createElement('textarea')
    el.value = data
    document.body.appendChild(el)
    el.select()
    document.execCommand('copy')
    document.body.removeChild(el)
  }
})

bindForms()
