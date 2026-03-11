function renderPerms() {
  permPills.innerHTML = "";
  const enabled = Object.entries(state.perms || {}).filter(([, v]) => v);
  enabled.forEach(([name]) => {
    const pill = document.createElement("span");
    pill.className = "pill";
    pill.textContent = name;
    permPills.appendChild(pill);
  });
}

function playerActionButtons(p) {
  const actions = [];
  if (state.perms.spectate)
    actions.push(actionButton("Spec", "spectate", p.id));
  if (state.perms.revive) actions.push(actionButton("Reviver", "revive", p.id));
  if (state.perms.heal) actions.push(actionButton("Heal", "heal", p.id));
  if (state.perms.gotoPlayer)
    actions.push(actionButton("Ir", "gotoPlayer", p.id));
  if (state.perms.bringPlayer)
    actions.push(actionButton("Trazer", "bringPlayer", p.id));
  if (state.perms.inventory)
    actions.push(actionButton("Inv", "inventory", p.id));
  if (state.perms.freeze) actions.push(actionButton("Freeze", "freeze", p.id));
  if (state.perms.warn) actions.push(actionButton("Warn", "warn", p.id));
  if (state.perms.kick) actions.push(actionButton("Kick", "kick", p.id));
  if (state.perms.ban) actions.push(actionButton("Ban", "ban", p.id));
  if (state.perms.dimension)
    actions.push(actionButton("Dim", "setDimension", p.id));
  return actions.join("");
}

function renderPlayers() {
  const term = (searchInput.value || "").toLowerCase();
  const rows = (state.players || []).filter((p) =>
    [String(p.id), p.name, p.citizenid, p.job, p.gang, p.license, p.discord]
      .join(" ")
      .toLowerCase()
      .includes(term),
  );

  playerRows.innerHTML = rows
    .map(
      (p) => `
    <tr>
      <td>${p.id}</td>
      <td>${escapeHtml(p.name)}<br><small style="color:var(--muted)">${escapeHtml(p.citizenid)}</small></td>
      <td>${escapeHtml(p.job)}</td>
      <td>${escapeHtml(p.gang)}</td>
      <td>${escapeHtml(p.ping)}</td>
      <td>${escapeHtml(p.bucket)}</td>
      <td><div class="row-actions"><button class="mini primary" data-open-player="${p.id}">Detalhes</button></div></td>
    </tr>
  `,
    )
    .join("");

  document
    .querySelectorAll("[data-open-player]")
    .forEach((btn) =>
      btn.addEventListener("click", () =>
        openPlayerModal(Number(btn.dataset.openPlayer)),
      ),
    );
}

function openPlayerModal(playerId) {
  selectedPlayer = (state.players || []).find(
    (p) => Number(p.id) === Number(playerId),
  );
  if (!selectedPlayer) return;
  playerModal.classList.remove("hidden");
  playerModalTitle.textContent = `${selectedPlayer.name} [${selectedPlayer.id}]`;
  playerModalSubtitle.textContent = `${selectedPlayer.job} • ${selectedPlayer.gang}`;
  const items = [
    ["Citizen ID", selectedPlayer.citizenid],
    ["Ping", selectedPlayer.ping],
    ["Bucket", selectedPlayer.bucket],
    ["Health", selectedPlayer.health],
    ["Armor", selectedPlayer.armor],
    ["Cash", selectedPlayer.cash],
    ["Bank", selectedPlayer.bank],
    ["Phone", selectedPlayer.phone],
    ["License", selectedPlayer.license],
    ["Discord", selectedPlayer.discord],
    ["Steam", selectedPlayer.steam],
    ["FiveM", selectedPlayer.fivem],
    [
      "Coords",
      `${selectedPlayer.coords?.x?.toFixed?.(2) ?? 0}, ${selectedPlayer.coords?.y?.toFixed?.(2) ?? 0}, ${selectedPlayer.coords?.z?.toFixed?.(2) ?? 0}`,
    ],
  ];
  playerDetailGrid.innerHTML = items
    .map(
      ([label, value]) =>
        `<div class="detail-item"><span>${escapeHtml(label)}</span><strong>${escapeHtml(value)}</strong></div>`,
    )
    .join("");
  playerDetailActions.innerHTML = playerActionButtons(selectedPlayer);
  playerDetailActions.querySelectorAll(".mini").forEach((btn) =>
    btn.addEventListener("click", () => {
      performAction(btn.dataset.action, Number(btn.dataset.target));
    }),
  );
  loadPlayerStaffManager(selectedPlayer.id);
}

function renderStaffRoleDropdown(items = []) {
  const select = document.getElementById("playerStaffRoleSelect");
  if (!select || !playerStaffRoleMenu || !playerStaffRoleToggle) return;

  const ordered = [...items]
    .map((item) => ({
      name: String(item?.name || "")
        .trim()
        .toLowerCase(),
      level: Number(item?.level || 0),
    }))
    .filter((item) => item.name)
    .sort(
      (a, b) =>
        Number(a.level || 0) - Number(b.level || 0) ||
        String(a.name || "").localeCompare(String(b.name || ""), "pt-BR"),
    );

  playerStaffRolePicker?.classList.remove("open");
  playerStaffRoleMenu.classList.add("hidden");

  select.innerHTML =
    ordered
      .map(
        (item) =>
          `<option value="${escapeHtml(item.name)}">${escapeHtml(item.name)} • nível ${escapeHtml(item.level)}</option>`,
      )
      .join("") || '<option value="">Sem cargos disponíveis</option>';
  playerStaffRoleMenu.innerHTML =
    ordered
      .map(
        (item, index) => `
    <button type="button" class="staff-role-option ${index === 0 ? "active" : ""}" data-value="${escapeHtml(item.name)}">
      <strong>${escapeHtml(item.name)}</strong>
      <span>Nível ${escapeHtml(item.level)}</span>
    </button>
  `,
      )
      .join("") || '<div class="vehicle-empty">Sem cargos disponíveis</div>';

  const firstValue = ordered[0]?.name || "";
  select.value = firstValue;
  playerStaffRoleToggle.textContent = firstValue
    ? `${firstValue} • nível ${ordered[0].level}`
    : "Sem cargos disponíveis";

  playerStaffRoleMenu.querySelectorAll(".staff-role-option").forEach((btn) =>
    btn.addEventListener("click", (e) => {
      e.preventDefault();
      e.stopPropagation();

      const value = String(btn.dataset.value || "")
        .trim()
        .toLowerCase();
      select.value = value;

      const found = ordered.find((item) => String(item.name) === value);
      playerStaffRoleToggle.textContent = found
        ? `${found.name} • nível ${found.level}`
        : "Selecione um cargo";
      playerStaffRoleMenu
        .querySelectorAll(".staff-role-option")
        .forEach((opt) => opt.classList.toggle("active", opt === btn));
      playerStaffRolePicker?.classList.remove("open");
      playerStaffRoleMenu.classList.add("hidden");
    }),
  );
}

function bindStaffRolePicker() {
  playerStaffRoleToggle?.addEventListener("click", (e) => {
    e.stopPropagation();
    if (!playerStaffRoleMenu) return;
    const hasOptions = !!playerStaffRoleMenu.children.length;
    if (!hasOptions) return;
    playerStaffRolePicker?.classList.toggle("open");
    playerStaffRoleMenu.classList.toggle("hidden");
  });
  document.addEventListener("click", (e) => {
    if (!playerStaffRolePicker?.contains(e.target)) {
      playerStaffRolePicker?.classList.remove("open");
      playerStaffRoleMenu?.classList.add("hidden");
    }
  });
}

async function loadPlayerStaffManager(playerId) {
  const managerWrap = document.getElementById("playerStaffManager");
  if (!managerWrap) return;
  if (!state.perms.setPermissions) {
    managerWrap.classList.add("hidden");
    return;
  }
  managerWrap.classList.remove("hidden");
  const select = document.getElementById("playerStaffRoleSelect");
  const currentWrap = document.getElementById("playerStaffCurrent");
  const infoWrap = document.getElementById("playerStaffAssignable");
  const rawResp = await nui("getStaffManageData", { target: playerId });
  const resp =
    typeof rawResp?.json === "function" ? await rawResp.json() : rawResp;
  if (!resp?.ok) {
    currentWrap.innerHTML = `<span class="tag rejeitado">${escapeHtml(resp?.error || "Falha ao carregar cargos.")}</span>`;
    if (select) select.innerHTML = '<option value="">Sem opções</option>';
    if (playerStaffRoleToggle)
      playerStaffRoleToggle.textContent = "Sem cargos disponíveis";
    if (playerStaffRoleMenu)
      playerStaffRoleMenu.innerHTML =
        '<div class="vehicle-empty">Sem opções</div>';
    if (infoWrap) infoWrap.textContent = "";
    return;
  }
  playerStaffState = {
    currentRoles: resp.currentRoles || [],
    assignableRoles: resp.assignableRoles || [],
    actorLevel: Number(resp.actorLevel || 0),
  };
  currentWrap.innerHTML = (
    playerStaffState.currentRoles.length
      ? playerStaffState.currentRoles
      : [{ name: "sem cargo" }]
  )
    .map(
      (role) => `<span class="pill">${escapeHtml(role?.name || role)}</span>`,
    )
    .join("");
  renderStaffRoleDropdown(playerStaffState.assignableRoles || []);
  if (infoWrap) {
    infoWrap.textContent = `Você pode definir cargos até o seu nível de gestão. Opções disponíveis: ${(playerStaffState.assignableRoles || []).map((item) => item.name).join(", ") || "nenhuma"}.`;
  }
}

async function submitPlayerStaff(mode) {
  if (!selectedPlayer) return;
  const select = document.getElementById("playerStaffRoleSelect");
  const note = document.getElementById("playerStaffNote");
  const role = String(select?.value || "")
    .trim()
    .toLowerCase();
  if ((mode === "add" || mode === "remove") && !role) return;
  if (mode === "clear") {
    await nui("clearStaffRoles", {
      target: selectedPlayer.id,
      note: note?.value || "",
    });
  } else {
    await nui("manageStaffRole", {
      target: selectedPlayer.id,
      role,
      mode,
      note: note?.value || "",
    });
  }
  if (note) note.value = "";
  setTimeout(async () => {
    await nui("refresh");
    openPlayerModal(selectedPlayer.id);
  }, 250);
}

function closePlayerModal() {
  playerModal.classList.add("hidden");
  selectedPlayer = null;
  playerStaffState = { currentRoles: [], assignableRoles: [], actorLevel: 0 };
}

function renderSupportMessages() {
  supportMessages.innerHTML =
    (supportState.messages || [])
      .map((m) => {
        const who =
          m.sender_type === "admin"
            ? "Administrador"
            : m.sender_type === "player"
              ? "Jogador"
              : "Sistema";
        const cls =
          m.sender_type === "admin"
            ? "admin"
            : m.sender_type === "player"
              ? "player"
              : "system";
        return `<div class="support-bubble ${cls}"><div class="support-author">${escapeHtml(m.sender_name || who)}</div><div>${escapeHtml(m.message || "")}</div><small>${formatDate(m.created_at)}</small></div>`;
      })
      .join("") || '<div class="vehicle-empty">Nenhuma mensagem ainda.</div>';
  supportMessages.scrollTop = supportMessages.scrollHeight;
}

async function fetchSupportSession(reportId = 0) {
  const res = await nui("supportFetch", { reportId });
  return res.json();
}

async function openSupportModal(reportId = 0, role = "staff") {
  supportState.role = role;
  supportState.reportId = Number(reportId || 0);
  supportModal.classList.remove("hidden");
  const data = await fetchSupportSession(supportState.reportId);
  if (!data?.ok) {
    supportInfoBar.innerHTML =
      '<span class="tag rejeitado">Não foi possível carregar o atendimento.</span>';
    return;
  }
  supportState.canManage = !!data.canManage;
  supportState.report = data.report || null;
  supportState.messages = data.messages || [];
  supportState.reportId = Number(data.report?.id || supportState.reportId || 0);
  supportTitle.textContent = supportState.report
    ? `Atendimento #${supportState.report.id}`
    : "Novo atendimento";
  supportSubtitle.textContent = supportState.canManage
    ? "Chat entre staff e jogador"
    : "Converse com a staff por aqui";
  supportInfoBar.innerHTML = supportState.report
    ? `<span class="tag">Status: ${escapeHtml(supportState.report.status || "pendente")}</span><span class="tag">Jogador: ${escapeHtml(supportState.report.player_name || "-")}</span><span class="tag">Atendido por: ${escapeHtml(supportState.report.accepted_by_name || "-")}</span>`
    : '<span class="tag">Envie a primeira mensagem para abrir o chamado</span>';
  supportGotoBtn.classList.toggle(
    "hidden",
    !(
      supportState.canManage && Number(supportState.report?.player_src || 0) > 0
    ),
  );
  supportCloseBtn.classList.toggle("hidden", !supportState.canManage);
  renderSupportMessages();
  if (supportState.poll) clearInterval(supportState.poll);
  supportState.poll = setInterval(async () => {
    if (supportModal.classList.contains("hidden")) return;
    const refreshed = await fetchSupportSession(supportState.reportId);
    if (refreshed?.ok) {
      supportState.report = refreshed.report || supportState.report;
      supportState.messages = refreshed.messages || [];
      supportState.reportId = Number(
        refreshed.report?.id || supportState.reportId || 0,
      );
      supportInfoBar.innerHTML = supportState.report
        ? `<span class="tag">Status: ${escapeHtml(supportState.report.status || "pendente")}</span><span class="tag">Jogador: ${escapeHtml(supportState.report.player_name || "-")}</span><span class="tag">Atendido por: ${escapeHtml(supportState.report.accepted_by_name || "-")}</span>`
        : supportInfoBar.innerHTML;
      supportGotoBtn.classList.toggle(
        "hidden",
        !(
          supportState.canManage &&
          Number(supportState.report?.player_src || 0) > 0
        ),
      );
      renderSupportMessages();
    }
  }, 2000);
}

function closeSupportModal() {
  supportModal.classList.add("hidden");
  if (supportState.poll) clearInterval(supportState.poll);
  supportState.poll = null;
  if (supportState.supportOnly) {
    supportState.supportOnly = false;
    app.classList.remove("support-only");
    nui("close");
  }
}

async function sendSupportMessage() {
  const message = supportMessageInput.value.trim();
  if (!message) return;
  await nui("supportSend", { reportId: supportState.reportId, message });
  supportMessageInput.value = "";
  setTimeout(
    () => openSupportModal(supportState.reportId, supportState.role),
    250,
  );
}

async function finalizeSupport() {
  if (!supportState.reportId) return;
  await nui("supportCloseReport", {
    reportId: supportState.reportId,
    status: supportCloseStatus.value,
    note: supportCloseNote.value || "",
  });
  supportCloseNote.value = "";
  setTimeout(() => {
    openSupportModal(supportState.reportId, supportState.role);
    nui("refresh");
  }, 250);
}

supportSendBtn?.addEventListener("click", sendSupportMessage);
supportCloseBtn?.addEventListener("click", finalizeSupport);
supportMessageInput?.addEventListener("keydown", (e) => {
  if (e.key === "Enter" && !e.shiftKey) {
    e.preventDefault();
    sendSupportMessage();
  }
});
supportGotoBtn?.addEventListener("click", () => {
  if (supportState.report?.player_src)
    performAction("gotoPlayer", Number(supportState.report.player_src));
});

function badgeForStatus(status) {
  const safe = String(status || "").toLowerCase();
  return `<span class="tag ${safe}">${escapeHtml(safe || "pendente")}</span>`;
}

function renderReports() {
  const term = (reportSearchInput.value || "").toLowerCase();
  const rows = (state.reports || []).filter((r) =>
    [r.id, r.player_name, r.player_citizenid, r.status, r.message, r.response]
      .join(" ")
      .toLowerCase()
      .includes(term),
  );
  reportList.innerHTML =
    rows
      .map(
        (r) => `
    <article class="log-card">
      <div class="log-top">
        <div>
          <strong>#${r.id} • ${escapeHtml(r.player_name || "Desconhecido")}</strong>
          ${badgeForStatus(r.status)}
        </div>
        <small>${formatDate(r.created_at)}</small>
      </div>
      <div class="log-meta">Player ID: ${escapeHtml(r.player_src || "-")} • CitizenID: ${escapeHtml(r.player_citizenid || "-")} • Atendido por: ${escapeHtml(r.accepted_by_name || "-")}</div>
      <p>${escapeHtml(r.message || "-")}</p>
      ${r.response ? `<div class="reply-box">Resposta: ${escapeHtml(r.response)}</div>` : ""}
      <div class="row-actions left">
        ${state.perms.staffchat ? actionButton("Abrir chat", "openSupportChat", null, { reportid: r.id }) : ""}
        ${state.perms.staffchat ? actionButton("Assumir", "reportAccept", null, { reportid: r.id }) : ""}
      </div>
    </article>
  `,
      )
      .join("") ||
    '<div class="vehicle-empty">Nenhum chamado encontrado.</div>';

  reportList.querySelectorAll(".mini").forEach((btn) =>
    btn.addEventListener("click", () => {
      const action = btn.dataset.action;
      if (action === "openSupportChat") {
        openSupportModal(Number(btn.dataset.reportid), "staff");
        return;
      }
      performAction(action, null, { reportId: Number(btn.dataset.reportid) });
      setTimeout(() => nui("refresh"), 250);
    }),
  );
}

function renderLogs() {
  const term = (logSearchInput.value || "").toLowerCase();
  const rows = (state.logs || []).filter((r) =>
    [r.category, r.action, r.actor_name, r.target_name, r.message]
      .join(" ")
      .toLowerCase()
      .includes(term),
  );
  logList.innerHTML =
    rows.map(renderLogCard).join("") ||
    '<div class="vehicle-empty">Nenhum log encontrado.</div>';
}

function renderLogCard(r) {
  return `
    <article class="log-card compact">
      <div class="log-top">
        <div><strong>${escapeHtml(r.category || "log")}</strong> <span class="tag">${escapeHtml(r.action || "-")}</span></div>
        <small>${formatDate(r.created_at)}</small>
      </div>
      <div class="log-meta">Ator: ${escapeHtml(r.actor_name || "-")} ${r.actor_src ? "[" + escapeHtml(r.actor_src) + "]" : ""} • Alvo: ${escapeHtml(r.target_name || "-")} ${r.target_src ? "[" + escapeHtml(r.target_src) + "]" : ""}</div>
      <p>${escapeHtml(r.message || "-")}</p>
    </article>
  `;
}

function renderDashboard() {
  dashboardLogs.innerHTML =
    (state.logs || []).slice(0, 8).map(renderLogCard).join("") ||
    '<div class="vehicle-empty">Sem logs.</div>';
  dashboardReports.innerHTML =
    (state.reports || [])
      .slice(0, 8)
      .map(
        (r) => `
    <article class="log-card compact">
      <div class="log-top">
        <div><strong>#${r.id} ${escapeHtml(r.player_name || "-")}</strong> ${badgeForStatus(r.status)}</div>
        <small>${formatDate(r.created_at)}</small>
      </div>
      <p>${escapeHtml(r.message || "-")}</p>
    </article>
  `,
      )
      .join("") || '<div class="vehicle-empty">Sem chamados.</div>';
  recentCommands.innerHTML =
    (state.recentCommands || [])
      .map(
        (r) => `
    <article class="log-card compact">
      <div class="log-top"><div><strong>${escapeHtml(r.action || "comando")}</strong></div><small>${formatDate(r.created_at)}</small></div>
      <div class="log-meta">${escapeHtml(r.actor_name || "-")}</div>
      <p>${escapeHtml(r.message || "-")}</p>
    </article>
  `,
      )
      .join("") || '<div class="vehicle-empty">Sem comandos recentes.</div>';
}

function renderQuickActions() {
  quickActions.innerHTML = "";
  quickCards
    .filter((card) => {
      if (card.key.startsWith("copyVector")) return !!state.perms.vector;
      if (card.key === "copyHeading") return !!state.perms.heading;
      if (card.key === "setMyDimension") return !!state.perms.dimension;
      return !!state.perms[card.key] || card.key === "spectateStop";
    })
    .forEach((card) => {
      const div = document.createElement("article");
      div.className = "card action-card";
      div.innerHTML = `<h4>${card.title}</h4><p>${card.desc}</p><button class="btn">Executar</button>`;
      div
        .querySelector("button")
        .addEventListener("click", () => performAction(card.key));
      quickActions.appendChild(div);
    });
}

function renderVehicles() {
  const term = (vehicleSearchInput.value || "").toLowerCase();
  const limit = Number(state.vehiclePreviewLimit || 120);
  const rows = (state.vehicles || [])
    .filter((v) =>
      [v.spawn, v.name, v.brand, v.category, v.shop]
        .join(" ")
        .toLowerCase()
        .includes(term),
    )
    .slice(0, limit);
  vehicleGrid.innerHTML =
    rows
      .map(
        (v) => `
    <article class="vehicle-card">
      <div class="vehicle-thumb-wrap">
        <img class="vehicle-thumb" src="${escapeHtml(v.image)}" onerror="this.style.display='none'; this.nextElementSibling.style.display='flex'" />
        <div class="vehicle-fallback" style="display:none">${escapeHtml(v.spawn)}</div>
      </div>
      <div class="vehicle-body">
        <strong>${escapeHtml(v.name)}</strong>
        <span>${escapeHtml(v.brand)} • ${escapeHtml(v.category)}</span>
        <code>${escapeHtml(v.spawn)}</code>
      </div>
      <button class="btn vehicle-btn" data-model="${escapeHtml(v.spawn)}">Spawnar</button>
    </article>
  `,
      )
      .join("") ||
    '<div class="vehicle-empty">Nenhum veículo encontrado.</div>';
  document
    .querySelectorAll(".vehicle-btn")
    .forEach((btn) =>
      btn.addEventListener("click", () =>
        performAction("spawnVehicle", null, { model: btn.dataset.model }),
      ),
    );
}

let commandsExpanded = false;

function renderCommands() {
  const term = (commandSearchInput?.value || "").trim().toLowerCase();
  const filtered = commands.filter(([cmd, desc]) =>
    `${cmd} ${desc}`.toLowerCase().includes(term),
  );
  commandList.innerHTML =
    filtered
      .map(
        ([cmd, desc]) =>
          `<div class="command-item"><code>${escapeHtml(cmd)}</code><div style="margin-top:8px;color:var(--muted)">${escapeHtml(desc)}</div></div>`,
      )
      .join("") ||
    '<div class="vehicle-empty">Nenhum comando encontrado.</div>';
  commandListWrap?.classList.toggle("expanded", commandsExpanded);
  commandListWrap?.classList.toggle("compact", !commandsExpanded);
  if (toggleCommandsBtn)
    toggleCommandsBtn.textContent = commandsExpanded ? "Recolher" : "Ver todos";
}
