const $ = (sel) => document.querySelector(sel);

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function statusBadge(status) {
  const labels = window.SupportStatusLabels || {};
  const text = labels[status] || status || "-";
  return `<span class="badge status ${escapeHtml(status || "")}">${escapeHtml(text)}</span>`;
}

function priorityBadge(priority) {
  const labels = window.SupportPriorityLabels || {};
  const text = labels[priority] || priority || "-";
  return `<span class="badge priority ${escapeHtml(priority || "")}">${escapeHtml(text)}</span>`;
}

function tagList(tags) {
  const arr = Array.isArray(tags) ? tags : [];
  if (!arr.length) return '<span class="muted">Sem tags</span>';
  return arr
    .map((tag) => `<span class="chip">${escapeHtml(tag)}</span>`)
    .join("");
}

function fmtDate(value) {
  if (!value) return "-";
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return String(value);
  return d.toLocaleString("pt-BR");
}

function renderDashboard() {
  const stats = window.AppState.stats || {};
  $("#stat-online").textContent = stats.online || 0;
  $("#stat-staff-online").textContent = stats.staffOnline || 0;
  $("#stat-bans").textContent = stats.totalBans || 0;
  $("#stat-warns").textContent = stats.totalWarns || 0;
  $("#stat-reports").textContent = stats.openReports || 0;

  const dashboardReports = $("#dashboardReports");
  const reports = (window.AppState.reports || []).slice(0, 8);
  dashboardReports.innerHTML = reports.length
    ? reports
        .map(
          (r) => `
      <button class="list-item report-open-btn" data-report-id="${Number(r.id)}">
        <div class="list-item-top">
          <strong>#${Number(r.id)} - ${escapeHtml(r.player_name || "Sem nome")}</strong>
          <div class="inline-badges">
            ${statusBadge(r.status)}
            ${priorityBadge(r.priority)}
          </div>
        </div>
        <div class="list-item-bottom">
          <span>${escapeHtml(r.message || "")}</span>
        </div>
      </button>
    `,
        )
        .join("")
    : '<div class="empty">Nenhum report recente.</div>';

  const dashboardLogs = $("#dashboardLogs");
  const logs = (window.AppState.logs || []).slice(0, 10);
  dashboardLogs.innerHTML = logs.length
    ? logs
        .map(
          (log) => `
      <div class="list-item static">
        <div class="list-item-top">
          <strong>${escapeHtml(log.category || "-")} / ${escapeHtml(log.action || "-")}</strong>
          <span>${fmtDate(log.created_at)}</span>
        </div>
        <div class="list-item-bottom">
          <span>${escapeHtml(log.message || "")}</span>
        </div>
      </div>
    `,
        )
        .join("")
    : '<div class="empty">Nenhum log recente.</div>';
}

function renderPlayers() {
  const list = $("#playersList");
  const players = window.AppState.filteredPlayers || [];

  list.innerHTML = players.length
    ? `
    <div class="table-head">
      <span>ID</span>
      <span>Nome</span>
      <span>Job</span>
      <span>Gang</span>
      <span>Staff</span>
      <span>Ping</span>
      <span>Ações</span>
    </div>
    ${players
      .map(
        (p) => `
      <div class="table-row">
        <span>${Number(p.id)}</span>
        <span>${escapeHtml(p.name || "-")}</span>
        <span>${escapeHtml(p.job || "-")}</span>
        <span>${escapeHtml(p.gang || "-")}</span>
        <span>${Array.isArray(p.staff) && p.staff.length ? escapeHtml(p.staff.join(", ")) : "-"}</span>
        <span>${Number(p.ping || 0)}</span>
        <span>
          <button class="btn btn-small btn-primary player-open-btn" data-player-id="${Number(p.id)}">Abrir</button>
        </span>
      </div>
    `,
      )
      .join("")}
  `
    : '<div class="empty">Nenhum jogador encontrado.</div>';
}

function renderVehicles() {
  const list = $("#vehiclesList");
  const summary = $("#vehiclesSummary");
  const loadMoreWrap = $("#vehiclesLoadMoreWrap");
  const vehicles = window.AppState.filteredVehicles || [];
  const previewLimit = Number(window.AppState.vehiclePreviewLimit || 48);
  const visibleCount = Math.max(
    previewLimit,
    Number(window.AppState.visibleVehicleCount || previewLimit),
  );
  const visibleVehicles = vehicles.slice(0, visibleCount);
  const remaining = Math.max(vehicles.length - visibleVehicles.length, 0);

  if (summary) {
    summary.textContent = vehicles.length
      ? `Mostrando ${visibleVehicles.length} de ${vehicles.length} veículos`
      : "Nenhum veículo encontrado";
  }

  list.innerHTML = visibleVehicles.length
    ? visibleVehicles
        .map(
          (v) => `
    <div class="vehicle-card">
      <img
        src="${escapeHtml(v.image || "")}"
        alt="${escapeHtml(v.name || "")}"
        loading="lazy"
        decoding="async"
        onerror="this.style.display='none'"
      >
      <div class="vehicle-card-body">
        <strong>${escapeHtml(v.name || v.spawn || "-")}</strong>
        <span>${escapeHtml(v.spawn || "-")}</span>
        <small>${escapeHtml(v.brand || "-")} • ${escapeHtml(v.category || "-")}</small>
        <button class="btn btn-primary btn-small vehicle-spawn-btn" data-model="${escapeHtml(v.spawn || "")}">Spawnar</button>
      </div>
    </div>
  `,
        )
        .join("")
    : '<div class="empty">Nenhum veículo encontrado.</div>';

  if (loadMoreWrap) {
    loadMoreWrap.innerHTML = remaining > 0
      ? `<button id="vehiclesLoadMoreBtn" class="btn btn-secondary">Carregar mais ${Math.min(remaining, previewLimit)} veículos</button>`
      : "";
  }
}

function renderLogs() {
  const list = $('#logsList');
  const page = window.AppState.logsPage || { rows: [], total: 0, page: 1, totalPages: 1, filters: {} };
  const logs = page.rows || window.AppState.logs || [];
  const filters = page.filters || {};

  const pagination = `
    <div class="pagination-bar">
      <div class="pagination-info">Mostrando ${logs.length} de ${Number(page.total || 0)} logs • Página ${Number(page.page || 1)} / ${Number(page.totalPages || 1)}</div>
      <div class="pagination-actions">
        <button class="btn btn-small btn-secondary logs-page-btn" data-page="${Math.max(1, Number(page.page || 1) - 1)}" ${Number(page.page || 1) <= 1 ? 'disabled' : ''}>Anterior</button>
        <button class="btn btn-small btn-secondary logs-page-btn" data-page="${Math.min(Number(page.totalPages || 1), Number(page.page || 1) + 1)}" ${Number(page.page || 1) >= Number(page.totalPages || 1) ? 'disabled' : ''}>Próxima</button>
      </div>
    </div>`;

  list.innerHTML = `
    <div class="filter-toolbar filter-toolbar-logs">
      <input id="logsFilterCategory" class="input" type="text" placeholder="Filtrar categoria..." value="${escapeHtml(filters.category || '')}">
      <input id="logsFilterAction" class="input" type="text" placeholder="Filtrar ação..." value="${escapeHtml(filters.action || '')}">
      <input id="logsFilterActor" class="input" type="text" placeholder="Filtrar autor..." value="${escapeHtml(filters.actor || '')}">
      <button id="logsClearFilters" class="btn btn-secondary">Geral</button>
    </div>
    ${pagination}
    ${logs.length ? `
      <div class="table-head table-head-logs">
        <span>ID</span>
        <span>Categoria</span>
        <span>Ação</span>
        <span>Ator</span>
        <span>Alvo</span>
        <span>Mensagem</span>
        <span>Data</span>
      </div>
      ${logs.map((log) => `
        <div class="table-row table-row-logs">
          <span>${Number(log.id || 0)}</span>
          <span>${escapeHtml(log.category || '-')}</span>
          <span>${escapeHtml(log.action || '-')}</span>
          <span>${escapeHtml(log.actor_name || '-')}</span>
          <span>${escapeHtml(log.target_name || '-')}</span>
          <span>${escapeHtml(log.message || '')}</span>
          <span>${fmtDate(log.created_at)}</span>
        </div>
      `).join('')}
    ` : '<div class="empty">Sem logs encontrados para esse filtro.</div>'}
    ${pagination}
  `;
}

function renderBans() {
  const list = $('#bansList');
  const page = window.AppState.bansPage || { rows: [], total: 0, page: 1, totalPages: 1, filters: {} };
  const bans = page.rows || window.AppState.bans || [];
  const filters = page.filters || {};

  const pagination = `
    <div class="pagination-bar">
      <div class="pagination-info">Mostrando ${bans.length} de ${Number(page.total || 0)} bans • Página ${Number(page.page || 1)} / ${Number(page.totalPages || 1)}</div>
      <div class="pagination-actions">
        <button class="btn btn-small btn-secondary bans-page-btn" data-page="${Math.max(1, Number(page.page || 1) - 1)}" ${Number(page.page || 1) <= 1 ? 'disabled' : ''}>Anterior</button>
        <button class="btn btn-small btn-secondary bans-page-btn" data-page="${Math.min(Number(page.totalPages || 1), Number(page.page || 1) + 1)}" ${Number(page.page || 1) >= Number(page.totalPages || 1) ? 'disabled' : ''}>Próxima</button>
      </div>
    </div>`;

  list.innerHTML = `
    <div class="filter-toolbar filter-toolbar-bans">
      <select id="bansFilterStatus" class="select">
        <option value="" ${!filters.status ? 'selected' : ''}>Todos status</option>
        <option value="active" ${filters.status === 'active' ? 'selected' : ''}>Ativo</option>
        <option value="expired" ${filters.status === 'expired' ? 'selected' : ''}>Expirado</option>
        <option value="removed" ${filters.status === 'removed' ? 'selected' : ''}>Removido</option>
      </select>
      <input id="bansFilterName" class="input" type="text" placeholder="Filtrar nome..." value="${escapeHtml(filters.name || '')}">
      <input id="bansFilterReason" class="input" type="text" placeholder="Filtrar motivo..." value="${escapeHtml(filters.reason || '')}">
      <input id="bansFilterAuthor" class="input" type="text" placeholder="Filtrar autor..." value="${escapeHtml(filters.bannedby || '')}">
      <button id="bansClearFilters" class="btn btn-secondary">Geral</button>
    </div>
    ${pagination}
    ${bans.length ? `
      <div class="table-head table-head-bans">
        <span>ID</span>
        <span>Nome</span>
        <span>Status</span>
        <span>Motivo</span>
        <span>Banido por</span>
        <span>Expira</span>
        <span>Criado em</span>
        <span>Ações</span>
      </div>
      ${bans.map((b) => {
        const expire = Number(b.expire || 0);
        const status = String(b.status || 'active');
        const expireText = expire >= 2147483647 ? 'Permanente' : (expire > 0 ? fmtDate(new Date(expire * 1000).toISOString()) : '-');
        const statusText = status === 'expired' ? 'Expirado' : (status === 'removed' ? 'Removido' : 'Ativo');
        const canUnban = window.AppState?.perms?.unban === true;
        const removedMeta = status === 'removed' ? ` por ${escapeHtml(b.removed_by || '-')} em ${fmtDate(b.removed_at)} (${escapeHtml(b.remove_reason || '-')})` : '';
        return `
        <div class="table-row table-row-bans">
          <span>${Number(b.id || 0)}</span>
          <span>${escapeHtml(b.name || '-')}</span>
          <span title="${status === 'removed' ? removedMeta : ''}">${escapeHtml(statusText)}</span>
          <span>${escapeHtml(b.reason || '-')}</span>
          <span>${escapeHtml(b.bannedby || '-')}</span>
          <span>${escapeHtml(expireText)}</span>
          <span>${fmtDate(b.created_at)}</span>
          <span>${canUnban && status !== 'removed' ? `<button class="btn btn-small btn-secondary ban-unban-btn" data-ban-id="${Number(b.id || 0)}" data-ban-name="${escapeHtml(b.name || '-') }">Remover</button>` : '<span class="muted-text">-</span>'}</span>
        </div>`;
      }).join('')}
    ` : '<div class="empty">Nenhum ban encontrado.</div>'}
    ${pagination}
  `;
}

function renderReports() {
  const wrap = $("#reportsList");
  const reports = window.applySupportFilters();

  wrap.innerHTML = reports.length
    ? reports
        .map(
          (r) => `
    <div class="report-card">
      <div class="report-card-top">
        <div>
          <strong>#${Number(r.id)} - ${escapeHtml(r.player_name || "Sem nome")}</strong>
          <p>${escapeHtml(r.player_citizenid || "-")}</p>
        </div>
        <div class="inline-badges">
          ${statusBadge(r.status)}
          ${priorityBadge(r.priority)}
        </div>
      </div>

      <div class="report-card-body">
        <p class="report-message">${escapeHtml(r.message || "")}</p>

        <div class="report-meta">
          <span><b>Responsável:</b> ${escapeHtml(r.accepted_by_name || "-")}</span>
          <span><b>Aguardando:</b> ${escapeHtml(r.waiting_on || "-")}</span>
          <span><b>Última msg:</b> ${fmtDate(r.last_message_at || r.updated_at)}</span>
          <span><b>Reaberto:</b> ${Number(r.reopened_count || 0)}x</span>
        </div>

        <div class="tags-row">
          ${tagList(r.tags_list)}
        </div>
      </div>

      <div class="report-card-actions">
        <button class="btn btn-primary report-open-btn" data-report-id="${Number(r.id)}">Abrir</button>
        <button class="btn btn-secondary report-accept-btn" data-report-id="${Number(r.id)}">Assumir</button>
        <button class="btn btn-secondary player-open-btn" data-player-id="${Number(r.player_src || 0)}">Player</button>
      </div>
    </div>
  `,
        )
        .join("")
    : '<div class="empty">Nenhum report encontrado.</div>';
}

function renderPlayerModal(player) {
  if (!player) return;

  const adminHistory = window.AppState.playerAdminHistory || {};
  const warns = adminHistory.warns || [];
  const bans = adminHistory.bans || [];
  const lastWarn = warns[0] || {};
  const lastBan = bans[0] || {};
  const staffText = Array.isArray(player.staff) && player.staff.length ? escapeHtml(player.staff.join(', ')) : '-';

  $('#playerModalSubtitle').textContent = `[${player.online ? player.id : 'OFF'}] ${player.name || 'Sem nome'}`;

  $('#playerInfo').innerHTML = `
    <div class="player-modal-layout">
      <div class="modal-section soft-section">
        <h4>Informações do jogador</h4>
        <div class="player-basic-grid">
          <div class="info-box"><span>Status</span><strong>${player.online ? 'Online' : 'Offline'}</strong></div>
          <div class="info-box"><span>ID</span><strong>${player.online ? Number(player.id) : 'Offline'}</strong></div>
          <div class="info-box"><span>CitizenID</span><strong>${escapeHtml(player.citizenid || '-')}</strong></div>
          <div class="info-box span-2"><span>Job</span><strong>${escapeHtml(player.job || '-')}</strong></div>
          <div class="info-box"><span>Gang</span><strong>${escapeHtml(player.gang || '-')}</strong></div>
          <div class="info-box"><span>Staff</span><strong>${staffText}</strong></div>
          <div class="info-box"><span>Ping</span><strong>${player.online ? Number(player.ping || 0) : '-'}</strong></div>
          <div class="info-box"><span>Bucket</span><strong>${player.online ? Number(player.bucket || 0) : '-'}</strong></div>
          <div class="info-box"><span>Cash</span><strong>${Number(player.cash || 0)}</strong></div>
          <div class="info-box"><span>Bank</span><strong>${Number(player.bank || 0)}</strong></div>
          <div class="info-box"><span>Telefone</span><strong>${escapeHtml(player.phone || '-')}</strong></div>
          <div class="info-box span-full"><span>License</span><strong>${escapeHtml(player.license || '-')}</strong></div>
          <div class="info-box span-full"><span>Discord</span><strong>${escapeHtml(player.discord || '-')}</strong></div>
        </div>
      </div>

      <div class="modal-section soft-section">
        <h4>Punições do jogador</h4>
        <div class="player-punishment-grid">
          <div class="info-box"><span>Total de warns</span><strong>${Number(warns.length || 0)}</strong></div>
          <div class="info-box"><span>Total de bans</span><strong>${Number(bans.length || 0)}</strong></div>
          <div class="info-box"><span>Último warn</span><strong>${fmtDate(lastWarn.created_at || '')}</strong></div>
          <div class="info-box"><span>Último ban</span><strong>${fmtDate(lastBan.created_at || '')}</strong></div>
          <div class="info-box span-2"><span>Motivo último warn</span><strong>${escapeHtml(lastWarn.reason || '-')}</strong></div>
          <div class="info-box span-2"><span>Motivo último ban</span><strong>${escapeHtml(lastBan.reason || '-')}</strong></div>
        </div>

        <div class="admin-history-columns">
          <div class="admin-history-card">
            <h4>Warns aplicados</h4>
            <div class="admin-history-list">
              ${warns.length ? warns.map((row, index) => `
                <div class="admin-history-item">
                  <strong>Warn ${warns.length - index}</strong>
                  <span>${escapeHtml(row.reason || '-')}</span>
                  <small>${fmtDate(row.created_at || '')}</small>
                </div>
              `).join('') : '<div class="empty">Nenhum warn encontrado.</div>'}
            </div>
          </div>

          <div class="admin-history-card">
            <h4>Bans aplicados</h4>
            <div class="admin-history-list">
              ${bans.length ? bans.map((row, index) => `
                <div class="admin-history-item">
                  <strong>Ban ${bans.length - index}</strong>
                  <span>${escapeHtml(row.reason || '-')}</span>
                  <small>${fmtDate(row.created_at || '')}</small>
                </div>
              `).join('') : '<div class="empty">Nenhum ban encontrado.</div>'}
            </div>
          </div>
        </div>
      </div>
    </div>
  `;

  if (!player.online) {
    $('#playerActions').innerHTML = `
      <div class="empty">Jogador offline. Ações em tempo real indisponíveis.</div>
    `;
    return;
  }

  const actionDefs = [
    ['Reviver', 'revive'],
    ['Curar', 'heal'],
    ['Matar', 'kill'],
    ['Congelar', 'freeze'],
    ['Ir até', 'gotoPlayer'],
    ['Ir coord', 'gotoCoords'],
    ['Trazer', 'bringPlayer'],
    ['Spectar', 'spectate'],
    ['Kick', 'kick'],
    ['Ban', 'ban'],
    ['Warn', 'warn'],
    ['Inventário', 'inventory'],
    ['Roupa', 'cloth'],
    ['Dimensão', 'setDimension'],
    ['Entrar veículo', 'intoVehicle'],
    ['Gerenciar staff', 'staffManager'],
  ];

  $('#playerActions').innerHTML = actionDefs.map(([label, action]) => `
    <button class="btn btn-secondary player-action-btn" data-action="${action}" data-player-id="${Number(player.id)}">
      ${escapeHtml(label)}
    </button>
  `).join('');
}

function renderSupportMetaBar(report) {
  const el = $("#supportMetaBar");
  if (!report) {
    el.innerHTML = '<div class="empty">Nenhum atendimento carregado.</div>';
    return;
  }

  el.innerHTML = `
    <div class="meta-pill"><span>ID</span><strong>#${Number(report.id)}</strong></div>
    <div class="meta-pill"><span>Player</span><strong>${escapeHtml(report.player_name || "-")}</strong></div>
    <div class="meta-pill"><span>Status</span><strong>${escapeHtml((window.SupportStatusLabels || {})[report.status] || report.status || "-")}</strong></div>
    <div class="meta-pill"><span>Prioridade</span><strong>${escapeHtml((window.SupportPriorityLabels || {})[report.priority] || report.priority || "-")}</strong></div>
    <div class="meta-pill"><span>Aguardando</span><strong>${escapeHtml(report.waiting_on || "-")}</strong></div>
    <div class="meta-pill"><span>Responsável</span><strong>${escapeHtml(report.accepted_by_name || "-")}</strong></div>
  `;
}

function renderSupportMessages(session) {
  const wrap = $("#supportMessages");
  const report = session && session.report;
  const messages = (session && session.messages) || [];

  if (!report) {
    wrap.innerHTML = '<div class="empty">Nenhum atendimento aberto.</div>';
    return;
  }

  wrap.innerHTML = messages.length
    ? messages
        .map((msg) => {
          const cls =
            msg.sender_type === "admin"
              ? "admin"
              : msg.sender_type === "player"
                ? "player"
                : "system";

          return `
      <div class="chat-bubble ${cls}">
        <div class="chat-meta">
          <strong>${escapeHtml(msg.sender_name || msg.sender_type || "Sistema")}</strong>
          <span>${fmtDate(msg.created_at)}</span>
        </div>
        <div class="chat-text">${escapeHtml(msg.message || "")}</div>
      </div>
    `;
        })
        .join("")
    : '<div class="empty">Sem mensagens.</div>';
}

function renderQuickReplies() {
  const wrap = $("#quickReplies");
  const replies = window.AppState.supportQuickReplies || [];
  wrap.innerHTML = replies.length
    ? replies
        .map(
          (reply) =>
            `<button class="chip quick-reply-btn" data-reply="${escapeHtml(reply)}">${escapeHtml(reply)}</button>`,
        )
        .join("")
    : '<span class="muted">Sem respostas rápidas.</span>';
}

function renderSupportModal() {
  const session = window.AppState.supportSession;
  const report = session && session.report;

  renderSupportMetaBar(report);
  renderSupportMessages(session);
  renderQuickReplies();

  const statusSelect = $("#supportStatus");
  const statuses =
    (window.AppState.supportMeta && window.AppState.supportMeta.statuses) || [];
  statusSelect.innerHTML = statuses
    .map(
      (status) => `
    <option value="${escapeHtml(status)}" ${report && String(report.status) === String(status) ? "selected" : ""}>
      ${escapeHtml((window.SupportStatusLabels || {})[status] || status)}
    </option>
  `,
    )
    .join("");

  $("#supportPriority").value = (report && report.priority) || "normal";
  $("#supportTags").value = Array.isArray(report && report.tags_list)
    ? report.tags_list.join(", ")
    : (report && report.tags) || "";
  $("#supportCloseStatus").value = "resolvido";
  $("#supportTitle").textContent = report
    ? `Atendimento #${Number(report.id)} - ${report.player_name || "Sem nome"}`
    : "Sessão de suporte";
}

function renderStaffManager() {
  const data = window.AppState.staffManager.data;
  const target = window.AppState.staffManager.target;
  if (!data || !target) return;

  $("#staffManagerTitle").textContent =
    `[${target.id}] ${target.name || "Sem nome"}`;

  $("#staffManagerCurrent").innerHTML = (data.currentRoles || []).length
    ? data.currentRoles
        .map(
          (role) =>
            `<span class="chip">${escapeHtml(role.name || role)}</span>`,
        )
        .join("")
    : '<span class="muted">Sem cargos.</span>';

  const select = $("#staffRoleSelect");
  select.innerHTML = (data.assignableRoles || [])
    .map(
      (role) => `
    <option value="${escapeHtml(role.name)}">${escapeHtml(role.name)} (${Number(role.level || 0)})</option>
  `,
    )
    .join("");
}

function secondsToReadable(value) {
  value = Number(value || 0);
  const hours = Math.floor(value / 3600);
  const minutes = Math.floor((value % 3600) / 60);
  const seconds = Math.floor(value % 60);

  const pad = (n) => String(n).padStart(2, "0");
  return `${pad(hours)}:${pad(minutes)}:${pad(seconds)}`;
}
function numberOrZero(value) {
  return Number(value || 0);
}

function renderStaffDuty() {
  const duty = window.AppState.staffDuty || {};
  const rows = duty.rows || [];
  const stats = duty.stats || {};
  const ranking = duty.dailyStats || [];
  const recentLogs = duty.recentLogs || [];
  const myToday = duty.myToday || {};

  const totalEl = document.querySelector("#staff-duty-total");
  const busyEl = document.querySelector("#staff-duty-busy");
  const freeEl = document.querySelector("#staff-duty-free");
  const meEl = document.querySelector("#staff-duty-me");

  if (totalEl) totalEl.textContent = Number(stats.totalOnDuty || 0);
  if (busyEl) busyEl.textContent = Number(stats.totalBusy || 0);
  if (freeEl) freeEl.textContent = Number(stats.totalFree || 0);

  if (meEl) {
    if (duty.meOnDuty) {
      const st = duty.meState || {};
      meEl.textContent = String(st.status || "ON").toUpperCase();
    } else {
      meEl.textContent = "OFF";
    }
  }

  const list = document.querySelector("#staffDutyList");
  if (list) {
    list.innerHTML = rows.length
      ? `
      <div class="table-head staff-duty-head">
        <span>ID</span>
        <span>Nome</span>
        <span>Cargo</span>
        <span>Status</span>
        <span>Tempo em serviço</span>
        <span>Licença</span>
      </div>
      ${rows
        .map(
          (row) => `
        <div class="table-row staff-duty-row">
          <span>${Number(row.src || 0)}</span>
          <span>${escapeHtml(row.name || "-")}</span>
          <span>${escapeHtml(row.role || "-")}</span>
          <span><span class="badge">${escapeHtml(row.status || "livre")}</span></span>
          <span>${secondsToReadable(row.secondsOnDuty || 0)}</span>
          <span>${escapeHtml(row.license || "-")}</span>
        </div>
      `,
        )
        .join("")}
    `
      : '<div class="empty">Nenhum staff em serviço no momento.</div>';
  }

  const myTodayWrap = document.querySelector("#staffMyToday");
  if (myTodayWrap) {
    myTodayWrap.innerHTML = `
      <div class="info-box"><span>Tempo em serviço</span><strong>${secondsToReadable(myToday.seconds_on_duty || 0)}</strong></div>
      <div class="info-box"><span>Reports assumidos</span><strong>${numberOrZero(myToday.reports_handled)}</strong></div>
      <div class="info-box"><span>Reports fechados</span><strong>${numberOrZero(myToday.reports_closed)}</strong></div>
      <div class="info-box"><span>Warns aplicados</span><strong>${numberOrZero(myToday.warns_applied)}</strong></div>
      <div class="info-box"><span>Bans aplicados</span><strong>${numberOrZero(myToday.bans_applied)}</strong></div>
      <div class="info-box"><span>Revives</span><strong>${numberOrZero(myToday.revives_done)}</strong></div>
      <div class="info-box"><span>Teleports</span><strong>${numberOrZero(myToday.teleports_done)}</strong></div>
      <div class="info-box"><span>Spectates</span><strong>${numberOrZero(myToday.spectates_done)}</strong></div>
    `;
  }

  const rankingWrap = document.querySelector("#staffTodayRanking");
  if (rankingWrap) {
    rankingWrap.innerHTML = ranking.length
      ? ranking
          .map(
            (row, index) => `
        <div class="list-item static">
          <div class="list-item-top">
            <strong>#${index + 1} - ${escapeHtml(row.staff_name || "-")}</strong>
            <span>${secondsToReadable(row.seconds_on_duty || 0)}</span>
          </div>
          <div class="list-item-bottom">
            <span>
              Reports fechados: ${numberOrZero(row.reports_closed)} |
              Reports assumidos: ${numberOrZero(row.reports_handled)} |
              Warns: ${numberOrZero(row.warns_applied)} |
              Bans: ${numberOrZero(row.bans_applied)}
            </span>
          </div>
        </div>
      `,
          )
          .join("")
      : '<div class="empty">Sem estatísticas registradas hoje.</div>';
  }

  const logsWrap = document.querySelector("#staffDutyRecentLogs");
  if (logsWrap) {
    logsWrap.innerHTML = recentLogs.length
      ? recentLogs
          .map(
            (row) => `
        <div class="list-item static">
          <div class="list-item-top">
            <strong>${escapeHtml(row.staff_name || "-")} • ${escapeHtml(row.action || "-")}</strong>
            <span>${fmtDate(row.started_at)}</span>
          </div>
          <div class="list-item-bottom">
            <span>
              Cargo: ${escapeHtml(row.role || "-")} |
              Status: ${escapeHtml(row.status || "-")} |
              Duração: ${secondsToReadable(row.duration_seconds || 0)}
            </span>
          </div>
        </div>
      `,
          )
          .join("")
      : '<div class="empty">Sem logs recentes de serviço.</div>';
  }
}

function renderActionModal() {
  const state = window.AppState.actionModal || {};
  const fieldsWrap = document.querySelector("#actionModalFields");
  const titleEl = document.querySelector("#actionModalTitle");
  const subtitleEl = document.querySelector("#actionModalSubtitle");

  if (!fieldsWrap || !titleEl || !subtitleEl) return;

  if (!state.open) {
    return;
  }

  const playerName = state.playerName || "Jogador";
  subtitleEl.textContent = playerName;

  let html = "";

  if (state.action === "warn") {
    titleEl.textContent = "Aplicar warn";
    html = `
      <label>Motivo do warn</label>
      <textarea id="actionWarnReason" placeholder="Digite o motivo...">${escapeHtml(state.values.reason || "Aviso da staff")}</textarea>
    `;
  } else if (state.action === "kick") {
    titleEl.textContent = "Kickar jogador";
    html = `
      <label>Motivo do kick</label>
      <textarea id="actionKickReason" placeholder="Digite o motivo...">${escapeHtml(state.values.reason || "Removido pela staff")}</textarea>
    `;
  } else if (state.action === "ban") {
    titleEl.textContent = "Banir jogador";
    html = `
      <label>Tempo do ban em segundos (0 = permanente)</label>
      <input id="actionBanSeconds" class="input" type="number" min="0" value="${escapeHtml(state.values.seconds || "86400")}" />

      <label>Motivo do ban</label>
      <textarea id="actionBanReason" placeholder="Digite o motivo...">${escapeHtml(state.values.reason || "Banido pela staff")}</textarea>
    `;
  } else if (state.action === "setDimension") {
    titleEl.textContent = "Alterar dimensão";
    html = `
      <label>Dimensão / Bucket</label>
      <input id="actionDimensionValue" class="input" type="number" min="0" value="${escapeHtml(state.values.dimension || "0")}" />
    `;
  } else if (state.action === "gotoCoords") {
    titleEl.textContent = "Ir para coordenada";
    html = `
      <label>Coordenada X</label>
      <input id="actionGotoX" class="input" type="number" step="0.01" value="${escapeHtml(state.values.x || "0.0")}" />

      <label>Coordenada Y</label>
      <input id="actionGotoY" class="input" type="number" step="0.01" value="${escapeHtml(state.values.y || "0.0")}" />

      <label>Coordenada Z</label>
      <input id="actionGotoZ" class="input" type="number" step="0.01" value="${escapeHtml(state.values.z || "0.0")}" />
    `;
  } else {
    titleEl.textContent = "Ação";
    html = '<div class="empty">Nenhuma ação selecionada.</div>';
  }

  fieldsWrap.innerHTML = html;
}

function renderAll() {
  renderDashboard();
  renderPlayers();
  renderStaffDuty();
  renderVehicles();
  renderLogs();
  renderBans();
  renderReports();
  renderActionModal();

  if (window.AppState.modals.player) {
    renderPlayerModal(window.getSelectedPlayer());
  }

  if (window.AppState.modals.support) {
    renderSupportModal();
  }

  if (window.AppState.modals.staffManager) {
    renderStaffManager();
  }
}

window.renderAll = renderAll;
window.renderPlayerModal = renderPlayerModal;
window.renderSupportModal = renderSupportModal;
window.renderStaffManager = renderStaffManager;
