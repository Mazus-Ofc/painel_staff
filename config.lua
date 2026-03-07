Config = {}

Config.Command = 'staffpanel'
Config.Theme = {
    serverName = 'Maravilhosa',
    accent = '#8b5cf6'
}

Config.MenuAccess = 'helper'
Config.VehicleImageBase = 'https://fivem.mazinho.org/imagens/carros/'
Config.VehiclePreviewLimit = 300
Config.DefaultBanSeconds = 86400
Config.BanTable = 'bans'
Config.WarnTable = 'player_warns'
Config.PlayerVehiclesTable = 'player_vehicles'
Config.DefaultGarage = 'pillboxgarage'
Config.OpenInventoryResource = 'qb-inventory'
Config.ClothingEvent = 'qb-clothing:client:openMenu'
Config.QBBypassPermissions = { 'admin', 'god' }
Config.AceBypassPermissions = { 'mz_staffpanel.bypass', 'command.admin', 'command.god' }

Config.ActionPerms = {
    spectate = 'helper',
    names = 'helper',
    blips = 'helper',
    wall = 'helper',
    dimension = 'helper',
    coords = 'helper',
    vector = 'helper',
    heading = 'helper',

    revive = 'suporte',
    gotoPlayer = 'suporte',
    bringPlayer = 'suporte',
    kill = 'suporte',
    heal = 'suporte',
    intoVehicle = 'suporte',

    freeze = 'moderador',
    kick = 'moderador',
    warn = 'moderador',
    announce = 'moderador',
    staffchat = 'moderador',
    spawnVehicle = 'moderador',
    deleteVehicle = 'moderador',
    saveVehicle = 'moderador',
    maxmods = 'moderador',
    inventory = 'moderador',
    clothing = 'moderador',
    setammo = 'moderador',
    setmodel = 'moderador',
    setspeed = 'moderador',
    reporttoggle = 'moderador',

    noclip = 'administrador',
    invisible = 'administrador',
    god = 'administrador',
    ban = 'administrador',
    setPermissions = 'administrador',
    giveWeapon = 'administrador',
    givenuifocus = 'administrador',

    kickall = 'diretor'
}

Config.Commands = {
    panel = 'staffpanel',
    panelAliases = { 'admin' },

    revive = 'revive',
    reviveAliases = { 'reviver' },
    heal = 'heal',
    healAliases = { 'curar' },

    gotoPlayer = 'goto',
    gotoPlayerAliases = { 'ir', 'tp', 'tpto' },

    bringPlayer = 'bring',
    bringPlayerAliases = { 'trazer', 'bringhere' },

    freeze = 'freeze',
    kill = 'kill',
    killAliases = { 'slay' },

    kick = 'kick',
    kickAliases = { 'kickstaff' },
    kickall = 'kickall',

    ban = 'ban',
    banAliases = {},

    warn = 'warn',
    checkwarns = 'checkwarns',
    delwarn = 'delwarn',

    spectate = 'spectate',
    spectateAliases = { 'spec' },
    specoff = 'specoff',

    noclip = 'noclip',
    noclipAliases = { 'staffnoclip' },
    invisible = 'invisible',
    invisibleAliases = { 'vanish' },
    god = 'god',
    godAliases = { 'ungod' },
    names = 'names',
    namesAliases = { 'staffnames' },
    blips = 'blips',
    blipsAliases = { 'staffblips' },
    wall = 'wall',
    wallAliases = { 'staffwall' },

    report = 'report',
    reportr = 'reportr',
    reporttoggle = 'reporttoggle',
    staffchat = 'staffchat',
    announce = 'announce',

    dim = 'dim',
    setdim = 'setdim',

    car = 'car',
    carAliases = { 'veh', 'spcar' },
    dv = 'dv',
    savecar = 'admincar',
    savecarAliases = { 'savecar' },
    maxmods = 'maxmods',

    intovehicle = 'intovehicle',
    intovehicleAliases = { 'carroplayer' },
    inventory = 'inventory',
    inventoryAliases = { 'invsee' },
    cloth = 'cloth',
    clothAliases = { 'clothing' },
    giveweapon = 'giveweapon',

    setmodel = 'setmodel',
    setspeed = 'setspeed',
    setammo = 'setammo',
    givenuifocus = 'givenuifocus',
    coords = 'coords',
    vector2 = 'vector2',
    vector3 = 'vector3',
    vector4 = 'vector4',
    heading = 'heading'
}

Config.Wall = {
    UpdateInterval = 120,
    DrawDistance = 800.0,
    ShowOtherBuckets = true,
    Notifies = true,
    TextZOffset = 1.15,
    Smooth = true,
    SmoothFactor = 0.28,
    SmoothDropAfterMs = 3000,
    ShowSelf = true,
    ShowVehicleName = true,
    VehicleNameMaxLen = 18,
    PreferStreamedCoords = true,
    ShowWeaponInfo = true,
    WeaponNameMaxLen = 20,
    DrawLines = true,
    LineDistance = 200.0,
    LineAlpha = 180,
    ColorDefault = { 255, 255, 255, 255 },
    ColorDead    = { 255,  70,  70, 255 },
    ColorAdmin   = { 255, 220,   0, 255 },
    ColorVehicle = {  80, 170, 255, 255 },
    MultiLine = true,
    TextScale = 0.30,
    ScreenLineSpacing = 0.024
}
