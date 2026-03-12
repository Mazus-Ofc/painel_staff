window.AppState = {
  visible: false,
  me: null,
  perms: {},
  theme: {},
  players: [],
  filteredPlayers: [],
  selectedPlayer: null,
  selectedPlayerData: null,
  vehicles: [],
  filteredVehicles: [],
  search: "",
  vehicleSearch: "",
  commandsSearch: "",
  currentTab: "dashboard",
  reports: [],
  logs: [],
  bans: [],
  stats: {},
  supportOnly: false,
  supportSession: null,
  supportQuickReplies: [],
  supportMeta: {
    statuses: [],
    priorities: [],
  },
  supportFilters: {
    status: "",
    priority: "",
    search: "",
  },
  modals: {
    player: false,
    vehicle: false,
    support: false,
    staffManager: false,
  },
  staffManager: {
    target: null,
    data: null,
    selectedRole: "",
    note: "",
  },
  staffDuty: {
    rows: [],
    stats: {
      totalOnDuty: 0,
      totalBusy: 0,
      totalFree: 0,
    },
    meOnDuty: false,
    meState: null,
    dailyStats: [],
    recentLogs: [],
    myToday: null,
    totals: {
      seconds_on_duty: 0,
      reports_handled: 0,
      reports_closed: 0,
      warns_applied: 0,
      bans_applied: 0,
      revives_done: 0,
      teleports_done: 0,
      spectates_done: 0,
    },
  },
  actionModal: {
    open: false,
    action: null,
    playerId: null,
    playerName: "",
    values: {},
  },
  playerAdminHistory: {
    warns: [],
    bans: [],
  },
};

window.SupportStatusLabels = {
  pendente: "Pendente",
  em_atendimento: "Em atendimento",
  aguardando_player: "Aguardando player",
  aguardando_staff: "Aguardando staff",
  resolvido: "Resolvido",
  recusado: "Recusado",
  cancelado: "Cancelado",
};

window.SupportPriorityLabels = {
  baixa: "Baixa",
  normal: "Normal",
  alta: "Alta",
  urgente: "Urgente",
};

window.setState = function (patch) {
  Object.assign(window.AppState, patch || {});
};

window.getSelectedPlayer = function () {
  const id = window.AppState.selectedPlayer;
  if (!id) return null;
  return (
    (window.AppState.players || []).find((p) => Number(p.id) === Number(id)) ||
    null
  );
};

window.applyPlayerFilters = function () {
  const q = String(window.AppState.search || "")
    .toLowerCase()
    .trim();
  const list = window.AppState.players || [];
  if (!q) {
    window.AppState.filteredPlayers = list.slice();
    return;
  }

  window.AppState.filteredPlayers = list.filter((p) => {
    const staffText = Array.isArray(p.staff) ? p.staff.join(" ") : "";
    return [
      p.name,
      p.id,
      p.citizenid,
      p.job,
      p.gang,
      p.license,
      p.discord,
      p.phone,
      staffText,
    ]
      .join(" ")
      .toLowerCase()
      .includes(q);
  });
};

window.applyVehicleFilters = function () {
  const q = String(window.AppState.vehicleSearch || "")
    .toLowerCase()
    .trim();
  const list = window.AppState.vehicles || [];
  if (!q) {
    window.AppState.filteredVehicles = list.slice();
    return;
  }

  window.AppState.filteredVehicles = list.filter((v) => {
    return [v.name, v.spawn, v.brand, v.category, v.shop]
      .join(" ")
      .toLowerCase()
      .includes(q);
  });
};

window.applySupportFilters = function () {
  const { status, priority, search } = window.AppState.supportFilters || {};
  const q = String(search || "")
    .toLowerCase()
    .trim();

  let reports = (window.AppState.reports || []).slice();

  if (status) {
    reports = reports.filter((r) => String(r.status || "") === String(status));
  }

  if (priority) {
    reports = reports.filter(
      (r) => String(r.priority || "") === String(priority),
    );
  }

  if (q) {
    reports = reports.filter((r) => {
      const tags = Array.isArray(r.tags_list)
        ? r.tags_list.join(" ")
        : r.tags || "";
      return [
        r.id,
        r.player_name,
        r.player_citizenid,
        r.player_license,
        r.message,
        r.response,
        r.accepted_by_name,
        tags,
      ]
        .join(" ")
        .toLowerCase()
        .includes(q);
    });
  }

  return reports;
};

window.resetSupportComposer = function () {
  const textarea = document.querySelector("#supportMessage");
  if (textarea) textarea.value = "";

  const closeNote = document.querySelector("#supportCloseNote");
  if (closeNote) closeNote.value = "";
};

window.setSupportSession = function (session) {
  window.AppState.supportSession = session || null;
  window.AppState.supportQuickReplies = (session && session.quickReplies) || [];
  window.AppState.supportMeta = (session && session.meta) || {
    statuses: [],
    priorities: [],
  };
};

window.clearSupportSession = function () {
  window.AppState.supportSession = null;
  window.AppState.supportQuickReplies = [];
  window.AppState.supportMeta = { statuses: [], priorities: [] };
};

window.ensureSelectedPlayerStillExists = function () {
  const current = getSelectedPlayer();
  if (!current) {
    window.AppState.selectedPlayer = null;
    window.AppState.selectedPlayerData = null;
    window.AppState.modals.player = false;
  }
};

window.hydrateState = function (data) {
  window.setState({
    me: data.me,
    perms: data.perms || {},
    theme: data.theme || {},
    players: data.players || [],
    vehicles: data.vehicles || [],
    reports: data.reports || [],
    logs: data.logs || [],
    bans: data.bans || [],
    stats: data.stats || {},
  });

  window.applyPlayerFilters();
  window.applyVehicleFilters();
  window.ensureSelectedPlayerStillExists();
};

window.setStaffDutyData = function (data) {
  data = data || {};
  window.AppState.staffDuty = {
    rows: data.rows || [],
    stats: data.stats || {
      totalOnDuty: 0,
      totalBusy: 0,
      totalFree: 0,
    },
    meOnDuty: data.meOnDuty === true,
    meState: data.meState || null,
    dailyStats: data.dailyStats || [],
    recentLogs: data.recentLogs || [],
    myToday: data.myToday || null,
    totals: data.totals || {
      seconds_on_duty: 0,
      reports_handled: 0,
      reports_closed: 0,
      warns_applied: 0,
      bans_applied: 0,
      revives_done: 0,
      teleports_done: 0,
      spectates_done: 0,
    },
  };
};
window.setActionModalState = function (data) {
  window.AppState.actionModal = Object.assign(
    {
      open: false,
      action: null,
      playerId: null,
      playerName: "",
      values: {},
    },
    data || {},
  );
};

window.clearActionModalState = function () {
  window.AppState.actionModal = {
    open: false,
    action: null,
    playerId: null,
    playerName: "",
    values: {},
  };
};

window.setPlayerAdminHistory = function (data) {
  window.AppState.playerAdminHistory = {
    warns: (data && data.warns) || [],
    bans: (data && data.bans) || [],
  };
};

window.clearPlayerAdminHistory = function () {
  window.AppState.playerAdminHistory = {
    warns: [],
    bans: [],
  };
};
