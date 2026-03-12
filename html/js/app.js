window.addEventListener("message", async (event) => {
  const payload = event.data || {};
  const action = payload.action;
  const data = payload.data;

  if (action === "visible") {
    const app = document.querySelector("#app");
    window.AppState.visible = data === true;
    app?.classList.toggle("hidden", !window.AppState.visible);

    if (!window.AppState.visible) {
      window.AppState.supportOnly = false;
      window.clearSupportSession();
      document.querySelector("#supportModal")?.classList.add("hidden");
      document.querySelector("#playerModal")?.classList.add("hidden");
      document.querySelector("#staffManagerModal")?.classList.add("hidden");
      window.AppState.modals.player = false;
      window.AppState.modals.support = false;
      window.AppState.modals.staffManager = false;
    }
    return;
  }

  if (action === "hydrate") {
    if (data && data.ok) {
      const serverName = document.querySelector("#serverName");
      if (serverName) {
        serverName.textContent =
          (data.theme && data.theme.serverName) || "Painel Staff";
      }

      window.hydrateState(data);
      window.renderAll();
    }
    return;
  }

  if (action === "supportOnly") {
    window.AppState.supportOnly = data === true;
    if (window.AppState.supportOnly) {
      window.openTab("reports");
    }
    return;
  }

  if (action === "supportOpen") {
    const reportId = Number((data && data.reportId) || 0);
    await window.openSupport(reportId);
    return;
  }

  if (action === "copy") {
    try {
      await navigator.clipboard.writeText(String(data || ""));
    } catch (e) {
      const temp = document.createElement("textarea");
      temp.value = String(data || "");
      document.body.appendChild(temp);
      temp.select();
      document.execCommand("copy");
      document.body.removeChild(temp);
    }
    return;
  }
});

document.addEventListener("DOMContentLoaded", () => {
  window.bindStaticEvents();
  window.openTab("dashboard");
});
