function bindForms() {
  commandSearchInput?.addEventListener("input", renderCommands);
  toggleCommandsBtn?.addEventListener("click", () => {
    commandsExpanded = !commandsExpanded;
    renderCommands();
  });
  document
    .getElementById("sendAnnounce")
    ?.addEventListener("click", () =>
      performAction("announce", null, {
        message: document.getElementById("announceMessage").value,
      }),
    );
  document
    .getElementById("sendStaffchat")
    ?.addEventListener("click", () =>
      performAction("staffchat", null, {
        message: document.getElementById("staffchatMessage").value,
      }),
    );
  document
    .getElementById("sendKickall")
    ?.addEventListener("click", () =>
      performAction("kickall", null, {
        reason: document.getElementById("kickallReason").value,
      }),
    );
  document.getElementById("sendReportReply")?.addEventListener("click", () =>
    performAction(
      "replyReport",
      Number(document.getElementById("reportReplyId").value),
      {
        message: document.getElementById("reportReplyMessage").value,
        reportId:
          Number(document.getElementById("reportReplyTicket").value) || 0,
      },
    ),
  );
  document
    .getElementById("sendSetModel")
    ?.addEventListener("click", () =>
      performAction(
        "setmodel",
        Number(document.getElementById("setModelTarget").value) || null,
        { model: document.getElementById("setModelInput").value },
      ),
    );
  document
    .getElementById("sendSetSpeed")
    ?.addEventListener("click", () =>
      performAction(
        "setspeed",
        Number(document.getElementById("setSpeedTarget").value) || null,
        { speed: document.getElementById("setSpeedInput").value },
      ),
    );
  document
    .getElementById("sendSetAmmo")
    ?.addEventListener("click", () =>
      performAction(
        "setammo",
        Number(document.getElementById("setAmmoTarget").value) || null,
        { amount: Number(document.getElementById("setAmmoInput").value) },
      ),
    );
  document
    .getElementById("sendNuiFocus")
    ?.addEventListener("click", () =>
      performAction(
        "givenuifocus",
        Number(document.getElementById("nuiFocusTarget").value) || null,
        {
          focus: document.getElementById("nuiFocusFlag").checked,
          mouse: document.getElementById("nuiMouseFlag").checked,
        },
      ),
    );
}
window.addEventListener("message", (event) => {
  const { action, data } = event.data || {};
  if (action === "visible") {
    app.classList.toggle("hidden", !data);
    if (data) setTab("dashboard");
  }
  if (action === "hydrate" && data) {
    supportState.supportOnly = false;
    app.classList.remove("support-only");
    state = data;
    serverName.textContent = data.theme?.serverName || "Mazus Staff";
    statOnline.textContent = data.stats?.online || data.players?.length || 0;
    statMe.textContent = data.me || 0;
    statStaff.textContent = data.stats?.staffOnline || 0;
    statReports.textContent = data.stats?.openReports || 0;
    statBans.textContent = data.stats?.totalBans || 0;
    renderPerms();
    renderPlayers();
    renderQuickActions();
    renderVehicles();
    renderCommands();
    renderReports();
    renderLogs();
    renderDashboard();
  }
  if (action === "supportOnly") {
    supportState.supportOnly = !!data;
    app.classList.toggle("support-only", !!data);
  }
  if (action === "supportOpen") {
    openSupportModal(data?.reportId || 0, data?.role || "player");
  }
  if (action === "clipboard" && typeof data === "string") {
    const el = document.createElement("textarea");
    el.value = data;
    document.body.appendChild(el);
    el.select();
    document.execCommand("copy");
    document.body.removeChild(el);
  }
});

bindForms();
bindStaffRolePicker();
