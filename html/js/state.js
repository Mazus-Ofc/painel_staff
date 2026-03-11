window.MZPanel = window.MZPanel || {};
const resource =
  typeof GetParentResourceName === "function"
    ? GetParentResourceName()
    : "mz_staffpanel";
const app = document.getElementById("app");
const serverName = document.getElementById("serverName");
const statOnline = document.getElementById("statOnline");
const statMe = document.getElementById("statMe");
const statStaff = document.getElementById("statStaff");
const statReports = document.getElementById("statReports");
const statBans = document.getElementById("statBans");
const permPills = document.getElementById("permPills");
const playerRows = document.getElementById("playerRows");
const searchInput = document.getElementById("searchInput");
const reportSearchInput = document.getElementById("reportSearchInput");
const logSearchInput = document.getElementById("logSearchInput");
const quickActions = document.getElementById("quickActions");
const commandList = document.getElementById("commandList");
const commandSearchInput = document.getElementById("commandSearchInput");
const toggleCommandsBtn = document.getElementById("toggleCommandsBtn");
const commandListWrap = document.getElementById("commandListWrap");
const vehicleSearchInput = document.getElementById("vehicleSearchInput");
const vehicleGrid = document.getElementById("vehicleGrid");
const reportList = document.getElementById("reportList");
const logList = document.getElementById("logList");
const dashboardLogs = document.getElementById("dashboardLogs");
const dashboardReports = document.getElementById("dashboardReports");
const recentCommands = document.getElementById("recentCommands");
const playerModal = document.getElementById("playerModal");
const playerDetailGrid = document.getElementById("playerDetailGrid");
const playerDetailActions = document.getElementById("playerDetailActions");
const playerModalTitle = document.getElementById("playerModalTitle");
const playerModalSubtitle = document.getElementById("playerModalSubtitle");
const supportModal = document.getElementById("supportModal");
const supportTitle = document.getElementById("supportTitle");
const supportSubtitle = document.getElementById("supportSubtitle");
const supportInfoBar = document.getElementById("supportInfoBar");
const supportMessages = document.getElementById("supportMessages");
const supportMessageInput = document.getElementById("supportMessageInput");
const supportSendBtn = document.getElementById("supportSendBtn");
const supportCloseBtn = document.getElementById("supportCloseBtn");
const supportCloseStatus = document.getElementById("supportCloseStatus");
const supportCloseNote = document.getElementById("supportCloseNote");
const supportGotoBtn = document.getElementById("supportGotoBtn");
const playerStaffRolePicker = document.getElementById("playerStaffRolePicker");
const playerStaffRoleToggle = document.getElementById("playerStaffRoleToggle");
const playerStaffRoleMenu = document.getElementById("playerStaffRoleMenu");

let state = {
  players: [],
  perms: {},
  vehicles: [],
  stats: {},
  logs: [],
  reports: [],
  recentCommands: [],
  bans: [],
};
let selectedPlayer = null;
let playerStaffState = { currentRoles: [], assignableRoles: [], actorLevel: 0 };
let supportState = {
  reportId: 0,
  role: "staff",
  canManage: false,
  report: null,
  messages: [],
  poll: null,
  supportOnly: false,
};

const commands = [
  ["/staffpanel", "Abrir o painel"],
  ["/admin", "Alias para abrir o painel"],
  ["/adm [mensagem]", "Abrir chamado para a staff"],
  ["/report [mensagem]", "Enviar report"],
  ["/reportr [id] [mensagem]", "Responder report"],
  ["/reporttoggle", "Alternar reports"],
  ["/revive [id]", "Reviver jogador"],
  ["/heal [id]", "Curar jogador"],
  ["/goto [id]", "Ir até o jogador"],
  ["/bring [id]", "Trazer jogador"],
  ["/freeze [id]", "Congelar"],
  ["/kill [id]", "Matar"],
  ["/kick [id] [motivo]", "Kickar"],
  ["/ban [id] [segundos] [motivo]", "Banir"],
  ["/warn [id] [motivo]", "Advertir"],
  ["/spectate [id]", "Spectar"],
  ["/noclip", "Noclip"],
  ["/names", "Ver nomes"],
  ["/blips", "Ver blips"],
  ["/wall", "Wall"],
  ["/announce [mensagem]", "Anúncio global"],
  ["/staffchat [mensagem]", "Chat da staff"],
  ["/car [spawn]", "Gerar veículo"],
  ["/admincar", "Salvar veículo"],
];

const quickCards = [
  { key: "noclip", title: "Noclip", desc: "Movimento livre." },
  { key: "invisible", title: "Invisible", desc: "Fica invisível." },
  { key: "god", title: "God", desc: "Invulnerabilidade." },
  { key: "names", title: "Nomes", desc: "Ver nomes sobre a cabeça." },
  { key: "blips", title: "Blips", desc: "Ver jogadores no mapa." },
  { key: "wall", title: "Wall", desc: "ESP integrado." },
  { key: "coords", title: "Coords", desc: "Mostrar vector4 na tela." },
  { key: "copyVector2", title: "Vector2", desc: "Copiar vector2." },
  { key: "copyVector3", title: "Vector3", desc: "Copiar vector3." },
  { key: "copyVector4", title: "Vector4", desc: "Copiar vector4." },
  { key: "copyHeading", title: "Heading", desc: "Copiar heading." },
  { key: "maxmods", title: "Maxmods", desc: "Tunagem máxima no carro." },
  { key: "saveVehicle", title: "Salvar carro", desc: "Salvar na garagem." },
  { key: "reporttoggle", title: "Reports", desc: "Ativar/desativar reports." },
  { key: "spectateStop", title: "Sair do spec", desc: "Encerra o spectate." },
  {
    key: "setMyDimension",
    title: "Minha dimensão",
    desc: "Trocar bucket atual.",
  },
  {
    key: "deleteVehicle",
    title: "DV",
    desc: "Deletar carro atual ou próximo.",
  },
];
