window.MZPanel = window.MZPanel || {};
function nui(path, body = {}) {
  return fetch(`https://${resource}/${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json; charset=UTF-8" },
    body: JSON.stringify(body),
  });
}

function setTab(name) {
  document
    .querySelectorAll(".nav")
    .forEach((btn) => btn.classList.toggle("active", btn.dataset.tab === name));
  document
    .querySelectorAll(".tab")
    .forEach((tab) => tab.classList.toggle("active", tab.id === `tab-${name}`));
}

document
  .querySelectorAll(".nav")
  .forEach((btn) =>
    btn.addEventListener("click", () => setTab(btn.dataset.tab)),
  );
document
  .getElementById("closeBtn")
  .addEventListener("click", () => nui("close"));
document
  .getElementById("refreshBtn")
  .addEventListener("click", () => nui("refresh"));
document
  .getElementById("closePlayerModal")
  .addEventListener("click", closePlayerModal);
document
  .getElementById("playerStaffAddBtn")
  ?.addEventListener("click", () => submitPlayerStaff("add"));
document
  .getElementById("playerStaffRemoveBtn")
  ?.addEventListener("click", () => submitPlayerStaff("remove"));
document
  .getElementById("playerStaffClearBtn")
  ?.addEventListener("click", () => submitPlayerStaff("clear"));
document
  .getElementById("closeSupportModal")
  .addEventListener("click", closeSupportModal);
window.addEventListener("keydown", (e) => {
  if (e.key === "Escape") {
    if (!playerModal.classList.contains("hidden")) closePlayerModal();
    else if (!supportModal.classList.contains("hidden")) closeSupportModal();
    else nui("close");
  }
});
searchInput.addEventListener("input", renderPlayers);
reportSearchInput.addEventListener("input", renderReports);
logSearchInput.addEventListener("input", renderLogs);
vehicleSearchInput.addEventListener("input", renderVehicles);

function parseBool(v) {
  return v === true || v === "true" || v === "1" || v === 1;
}

function formatDate(v) {
  if (!v) return "-";
  const d = new Date(String(v).replace(" ", "T"));
  if (Number.isNaN(d.getTime())) return String(v);
  return d.toLocaleString("pt-BR");
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function performAction(action, target = null, extra = {}) {
  const payload = { action, target, ...extra };

  if (action === "kick" && !payload.reason) {
    const reason = prompt("Motivo do kick:", "Removido pela staff");
    if (reason === null) return;
    payload.reason = reason;
  }

  if (action === "ban" && (!payload.reason || !payload.seconds)) {
    const seconds = prompt(
      "Tempo do ban em segundos (0 = permanente):",
      "86400",
    );
    if (seconds === null) return;
    const reason = prompt("Motivo do ban:", "Banido pela staff");
    if (reason === null) return;
    payload.seconds = Number(seconds);
    payload.reason = reason;
  }

  if (action === "warn" && !payload.reason) {
    const reason = prompt("Motivo da advertência:", "Aviso da staff");
    if (reason === null) return;
    payload.reason = reason;
  }

  if (action === "setMyDimension" || action === "setDimension") {
    const raw = prompt("Digite a dimensão (0 = padrão):", "0");
    if (raw === null) return;
    payload.dimension = Number(raw);
  }

  if (action === "giveWeapon" && !payload.weapon) {
    const weapon = prompt("Nome da arma:", "WEAPON_CARBINERIFLE");
    if (weapon === null) return;
    const ammo = prompt("Munição:", "250");
    if (ammo === null) return;
    payload.weapon = weapon;
    payload.ammo = Number(ammo);
  }

  nui("action", payload);
}

function actionButton(label, action, target, extra = {}) {
  const attrs = Object.entries(extra)
    .map(([k, v]) => `data-${k}="${escapeHtml(v)}"`)
    .join(" ");
  return `<button class="mini" data-action="${action}" data-target="${target ?? ""}" ${attrs}>${label}</button>`;
}
