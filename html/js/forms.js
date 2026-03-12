const nui = async (action, data = {}) => {
  const res = await fetch(`https://${GetParentResourceName()}/${action}`, {
    method: "POST",
    headers: { "Content-Type": "application/json; charset=UTF-8" },
    body: JSON.stringify(data || {}),
  });
  try {
    return await res.json();
  } catch (e) {
    return null;
  }
};

function openTab(tab) {
  window.AppState.currentTab = tab;

  document.querySelectorAll(".nav-btn").forEach((btn) => {
    btn.classList.toggle("active", btn.dataset.tab === tab);
  });

  document.querySelectorAll(".tab").forEach((el) => {
    el.classList.toggle("active", el.id === `tab-${tab}`);
  });
}

function openActionModal(action, player) {
  if (!player) return;

  let defaults = {};

  if (action === "warn") {
    defaults = { reason: "Aviso da staff" };
  } else if (action === "kick") {
    defaults = { reason: "Removido pela staff" };
  } else if (action === "ban") {
    defaults = { seconds: "86400", reason: "Banido pela staff" };
  } else if (action === "setDimension") {
    defaults = { dimension: "0" };
  }

  window.setActionModalState({
    open: true,
    action,
    playerId: Number(player.id),
    playerName: `[${player.online ? player.id : "OFF"}] ${player.name || "Jogador"}`,
    values: defaults,
  });

  window.renderActionModal();
  showModal("actionModal");
}

async function confirmActionModal() {
  const state = window.AppState.actionModal || {};
  const action = state.action;
  const playerId = Number(state.playerId || 0);

  if (!action || !playerId) return;

  const payload = {
    action,
    target: playerId,
  };

  if (action === "warn") {
    payload.reason =
      document.querySelector("#actionWarnReason")?.value || "Aviso da staff";
  }

  if (action === "kick") {
    payload.reason =
      document.querySelector("#actionKickReason")?.value ||
      "Removido pela staff";
  }

  if (action === "ban") {
    payload.seconds = Number(
      document.querySelector("#actionBanSeconds")?.value || 0,
    );
    payload.reason =
      document.querySelector("#actionBanReason")?.value || "Banido pela staff";
  }

  if (action === "setDimension") {
    payload.dimension = Number(
      document.querySelector("#actionDimensionValue")?.value || 0,
    );
  }

  await nui("action", payload);

  hideModal("actionModal");
  window.clearActionModalState();

  setTimeout(refreshPanel, 250);
}

function showModal(id) {
  const el = document.getElementById(id);
  if (!el) return;
  el.classList.remove("hidden");

  if (id === "playerModal") window.AppState.modals.player = true;
  if (id === "supportModal") window.AppState.modals.support = true;
  if (id === "staffManagerModal") window.AppState.modals.staffManager = true;
}

function hideModal(id) {
  const el = document.getElementById(id);
  if (!el) return;
  el.classList.add("hidden");

  if (id === "playerModal") window.AppState.modals.player = false;
  if (id === "supportModal") window.AppState.modals.support = false;
  if (id === "staffManagerModal") window.AppState.modals.staffManager = false;

  if (id === "actionModal") {
    window.clearActionModalState();
  }
}

async function refreshPanel() {
  const data = await nui("refresh");
  if (data && data.ok) {
    window.hydrateState(data);
    window.renderAll();
  }
}

async function openPlayer(playerId) {
  playerId = Number(playerId || 0);
  const player = (window.AppState.players || []).find(
    (p) => Number(p.id) === playerId,
  );
  if (!player) return;

  window.AppState.selectedPlayer = playerId;
  window.AppState.selectedPlayerData = player;
  window.renderPlayerModal(player);
  showModal("playerModal");
}

async function openSupport(reportId = 0) {
  const session = await nui("supportFetch", {
    reportId: Number(reportId || 0),
  });
  if (!session || !session.ok) return;

  window.setSupportSession(session);
  window.renderSupportModal();
  window.resetSupportComposer();
  showModal("supportModal");
}

async function refreshStaffDuty() {
  const data = await nui("getStaffDutyData");
  if (!data || !data.ok) return;

  window.setStaffDutyData(data);
  window.renderAll();
}

async function setDutyState(mode) {
  await nui("setDutyState", { mode });
  setTimeout(async () => {
    await refreshStaffDuty();
    await refreshPanel();
  }, 200);
}

async function openStaffManager(playerId) {
  const player = (window.AppState.players || []).find(
    (p) => Number(p.id) === Number(playerId || 0),
  );
  if (!player) return;

  const data = await nui("getStaffManageData", { target: Number(playerId) });
  if (!data || !data.ok) return;

  window.AppState.staffManager.target = player;
  window.AppState.staffManager.data = data;
  window.AppState.staffManager.selectedRole = "";
  window.AppState.staffManager.note = "";

  window.renderStaffManager();
  showModal("staffManagerModal");
}

async function doPlayerAction(action, playerId) {
  const target = Number(playerId || 0);
  const player = (window.AppState.players || []).find(
    (p) => Number(p.id) === target,
  );

  if (!player || player.online === false) {
    return;
  }

  if (
    action === "kick" ||
    action === "ban" ||
    action === "warn" ||
    action === "setDimension"
  ) {
    return openActionModal(action, player);
  }

  const payload = { action, target };

  await nui("action", payload);
  setTimeout(refreshPanel, 250);
}

async function supportSendMessage() {
  const session = window.AppState.supportSession;
  const report = session && session.report;
  const textarea = document.querySelector("#supportMessage");
  if (!textarea) return;

  const message = String(textarea.value || "").trim();
  if (!message) return;

  await nui("supportSend", {
    reportId: Number((report && report.id) || 0),
    message,
  });

  textarea.value = "";
  setTimeout(async () => {
    if (report && report.id) await openSupport(report.id);
    else await openSupport(0);
    refreshPanel();
  }, 200);
}

async function supportCloseReport() {
  const session = window.AppState.supportSession;
  const report = session && session.report;
  if (!report) return;

  const status =
    document.querySelector("#supportCloseStatus")?.value || "resolvido";
  const note = document.querySelector("#supportCloseNote")?.value || "";

  await nui("supportCloseReport", {
    reportId: Number(report.id),
    status,
    note,
    closedReason: status,
  });

  setTimeout(async () => {
    await openSupport(report.id);
    refreshPanel();
  }, 200);
}

async function supportAcceptReport() {
  const session = window.AppState.supportSession;
  const report = session && session.report;
  if (!report) return;

  await nui("supportAcceptReport", {
    reportId: Number(report.id),
  });

  setTimeout(async () => {
    await openSupport(report.id);
    refreshPanel();
  }, 200);
}

async function supportReopenReport() {
  const session = window.AppState.supportSession;
  const report = session && session.report;
  if (!report) return;

  await nui("supportReopenReport", {
    reportId: Number(report.id),
  });

  setTimeout(async () => {
    await openSupport(report.id);
    refreshPanel();
  }, 200);
}

async function supportUpdateMeta() {
  const session = window.AppState.supportSession;
  const report = session && session.report;
  if (!report) return;

  const status =
    document.querySelector("#supportStatus")?.value ||
    report.status ||
    "pendente";
  const priority =
    document.querySelector("#supportPriority")?.value ||
    report.priority ||
    "normal";
  const tags = document.querySelector("#supportTags")?.value || "";

  await nui("supportUpdateMeta", {
    reportId: Number(report.id),
    status,
    priority,
    tags,
  });

  setTimeout(async () => {
    await openSupport(report.id);
    refreshPanel();
  }, 200);
}

async function staffAddRole() {
  const target = window.AppState.staffManager.target;
  if (!target) return;

  const role = document.querySelector("#staffRoleSelect")?.value || "";
  const note = document.querySelector("#staffRoleNote")?.value || "";

  if (!role) return;

  await nui("manageStaffRole", {
    target: Number(target.id),
    role,
    mode: "add",
    note,
  });

  setTimeout(async () => {
    await openStaffManager(target.id);
    refreshPanel();
  }, 200);
}

async function staffRemoveRole() {
  const target = window.AppState.staffManager.target;
  if (!target) return;

  const role = document.querySelector("#staffRoleSelect")?.value || "";
  const note = document.querySelector("#staffRoleNote")?.value || "";

  if (!role) return;

  await nui("manageStaffRole", {
    target: Number(target.id),
    role,
    mode: "remove",
    note,
  });

  setTimeout(async () => {
    await openStaffManager(target.id);
    refreshPanel();
  }, 200);
}

async function staffClearRoles() {
  const target = window.AppState.staffManager.target;
  if (!target) return;

  const note = document.querySelector("#staffRoleNote")?.value || "";

  await nui("clearStaffRoles", {
    target: Number(target.id),
    note,
  });

  setTimeout(async () => {
    hideModal("staffManagerModal");
    refreshPanel();
  }, 200);
}

function bindStaticEvents() {
  document.querySelectorAll(".nav-btn").forEach((btn) => {
    btn.addEventListener("click", async () => {
      openTab(btn.dataset.tab);

      if (btn.dataset.tab === "staff") {
        await refreshStaffDuty();
      }
    });
  });
  document
    .querySelector("#actionModalConfirmBtn")
    ?.addEventListener("click", confirmActionModal);
  document
    .querySelector("#staffRefreshBtn")
    ?.addEventListener("click", refreshStaffDuty);
  document
    .querySelector("#staffOnBtn")
    ?.addEventListener("click", () => setDutyState("on"));
  document
    .querySelector("#staffOffBtn")
    ?.addEventListener("click", () => setDutyState("off"));

  document
    .querySelector("#closeBtn")
    ?.addEventListener("click", () => nui("close"));
  document
    .querySelector("#refreshBtn")
    ?.addEventListener("click", refreshPanel);

  document.querySelector("#playerSearch")?.addEventListener("input", (e) => {
    window.AppState.search = e.target.value || "";
    window.applyPlayerFilters();
    window.renderPlayers?.() || window.renderAll();
  });

  document.querySelector("#vehicleSearch")?.addEventListener("input", (e) => {
    window.AppState.vehicleSearch = e.target.value || "";
    window.applyVehicleFilters();
    window.renderVehicles?.() || window.renderAll();
  });

  document.querySelector("#reportSearch")?.addEventListener("input", (e) => {
    window.AppState.supportFilters.search = e.target.value || "";
    window.renderReports?.() || window.renderAll();
  });

  document
    .querySelector("#reportStatusFilter")
    ?.addEventListener("change", (e) => {
      window.AppState.supportFilters.status = e.target.value || "";
      window.renderReports?.() || window.renderAll();
    });

  document
    .querySelector("#reportPriorityFilter")
    ?.addEventListener("change", (e) => {
      window.AppState.supportFilters.priority = e.target.value || "";
      window.renderReports?.() || window.renderAll();
    });

  document
    .querySelector("#supportSendBtn")
    ?.addEventListener("click", supportSendMessage);
  document
    .querySelector("#supportCloseBtn")
    ?.addEventListener("click", supportCloseReport);
  document
    .querySelector("#supportAcceptBtn")
    ?.addEventListener("click", supportAcceptReport);
  document
    .querySelector("#supportReopenBtn")
    ?.addEventListener("click", supportReopenReport);
  document
    .querySelector("#supportSaveMetaBtn")
    ?.addEventListener("click", supportUpdateMeta);

  document
    .querySelector("#staffAddBtn")
    ?.addEventListener("click", staffAddRole);
  document
    .querySelector("#staffRemoveBtn")
    ?.addEventListener("click", staffRemoveRole);
  document
    .querySelector("#staffClearBtn")
    ?.addEventListener("click", staffClearRoles);

  document.querySelectorAll("[data-close-modal]").forEach((btn) => {
    btn.addEventListener("click", () => hideModal(btn.dataset.closeModal));
  });

  document.addEventListener("click", async (e) => {
    const playerBtn = e.target.closest(".player-open-btn");
    if (playerBtn) {
      await openPlayer(playerBtn.dataset.playerId);
      return;
    }

    const reportBtn = e.target.closest(".report-open-btn");
    if (reportBtn) {
      await openSupport(reportBtn.dataset.reportId);
      return;
    }

    const acceptBtn = e.target.closest(".report-accept-btn");
    if (acceptBtn) {
      await nui("supportAcceptReport", {
        reportId: Number(acceptBtn.dataset.reportId),
      });
      setTimeout(refreshPanel, 200);
      return;
    }

    const vehicleBtn = e.target.closest(".vehicle-spawn-btn");
    if (vehicleBtn) {
      await nui("action", {
        action: "spawnVehicle",
        model: vehicleBtn.dataset.model,
      });
      return;
    }

    const quickReplyBtn = e.target.closest(".quick-reply-btn");
    if (quickReplyBtn) {
      const textarea = document.querySelector("#supportMessage");
      if (textarea) textarea.value = quickReplyBtn.dataset.reply || "";
      return;
    }

    const playerActionBtn = e.target.closest(".player-action-btn");
    if (playerActionBtn) {
      const action = playerActionBtn.dataset.action;
      const playerId = playerActionBtn.dataset.playerId;

      if (action === "staffManager") {
        await openStaffManager(playerId);
      } else {
        await doPlayerAction(action, playerId);
      }
      return;
    }
  });

  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") {
      if (window.AppState.modals.staffManager)
        return hideModal("staffManagerModal");
      if (window.AppState.modals.support) return hideModal("supportModal");
      if (window.AppState.modals.player) return hideModal("playerModal");
      nui("close");
    }
  });
}

window.NuiRequest = nui;
window.openTab = openTab;
window.openPlayer = openPlayer;
window.openSupport = openSupport;
window.openStaffManager = openStaffManager;
window.refreshPanel = refreshPanel;
window.bindStaticEvents = bindStaticEvents;
window.showModal = showModal;
window.hideModal = hideModal;
