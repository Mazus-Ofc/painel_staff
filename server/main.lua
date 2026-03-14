local QBCore = exports['qb-core']:GetCoreObject()

MZ_STAFFPANEL = MZ_STAFFPANEL or {}
local P = MZ_STAFFPANEL

P.QBCore = QBCore
P.State = P.State or {
    frozenPlayers = {},
    adminSpectateState = {},
    wallWatchers = {},
    reportCooldown = {}
}

math.randomseed(os.time())

function P.Notify(src, msg, typ)
    TriggerClientEvent('QBCore:Notify', src, msg, typ or 'primary')
end

function P.GetPlayerNameSafe(Player)
    if not Player then return 'Desconhecido' end
    local ci = Player.PlayerData.charinfo or {}
    local fullname = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    if fullname == '' then
        fullname = GetPlayerName(Player.PlayerData.source) or ('ID ' .. tostring(Player.PlayerData.source))
    end
    return fullname
end

function P.GetIdentifierSafe(src, kind)
    if QBCore.Functions.GetIdentifier then
        local value = QBCore.Functions.GetIdentifier(src, kind)
        if value and value ~= '' then
            return value
        end
    end

    local prefix = tostring(kind or '') .. ':'
    for _, identifier in ipairs(GetPlayerIdentifiers(src)) do
        if identifier:sub(1, #prefix) == prefix then
            return identifier
        end
    end

    return nil
end

function P.GetVehicleList()
    local out, seen = {}, {}
    local shared = (QBCore.Shared and QBCore.Shared.Vehicles) or {}

    for spawn, data in pairs(shared) do
        local spawnName = tostring((data and data.model) or spawn or ''):lower()
        if spawnName ~= '' and not seen[spawnName] then
            seen[spawnName] = true
            out[#out + 1] = {
                spawn = spawnName,
                name = (data and data.name) or spawnName,
                brand = (data and data.brand) or '-',
                category = (data and data.category) or '-',
                shop = (data and data.shop) or '-',
                image = (Config.VehicleImageBase or '') .. spawnName .. '.png'
            }
        end
    end

    table.sort(out, function(a, b)
        return (a.name or a.spawn) < (b.name or b.spawn)
    end)

    return out
end

function P.GetOnlinePlayersData()
    local list, staffOnline = {}, 0
    local players = QBCore.Functions.GetQBPlayers()

    for _, Player in pairs(players) do
        local metaPerms = (Player.PlayerData.metadata and Player.PlayerData.metadata.perms) or {}
        local staffNames = {}

        for name, enabled in pairs(metaPerms.staff or {}) do
            if enabled then
                staffNames[#staffNames + 1] = name
            end
        end

        table.sort(staffNames)

        if #staffNames > 0 or P.HasQBBypass(Player.PlayerData.source) then
            staffOnline = staffOnline + 1
        end

        local src = Player.PlayerData.source
        local ped = GetPlayerPed(src)
        local coords = ped ~= 0 and GetEntityCoords(ped) or vec3(0.0, 0.0, 0.0)
        local health = ped ~= 0 and GetEntityHealth(ped) or 0
        local armor = ped ~= 0 and GetPedArmour(ped) or 0

        local identifiers = {
            license = Player.PlayerData.license or P.GetIdentifierSafe(src, 'license') or '-',
            discord = P.GetIdentifierSafe(src, 'discord') or '-',
            steam = P.GetIdentifierSafe(src, 'steam') or '-',
            fivem = P.GetIdentifierSafe(src, 'fivem') or '-'
        }

        list[#list + 1] = {
            id = src,
            name = P.GetPlayerNameSafe(Player),
            citizenid = Player.PlayerData.citizenid or '-',
            job = (Player.PlayerData.job and (Player.PlayerData.job.label or Player.PlayerData.job.name)) or '-',
            gang = (Player.PlayerData.gang and (Player.PlayerData.gang.label or Player.PlayerData.gang.name)) or '-',
            staff = staffNames,
            ping = GetPlayerPing(src),
            bucket = GetPlayerRoutingBucket(src) or 0,
            health = health,
            armor = armor,
            cash = (Player.PlayerData.money and Player.PlayerData.money.cash) or 0,
            bank = (Player.PlayerData.money and Player.PlayerData.money.bank) or 0,
            phone = Player.PlayerData.charinfo and Player.PlayerData.charinfo.phone or '-',
            license = identifiers.license,
            discord = identifiers.discord,
            steam = identifiers.steam,
            fivem = identifiers.fivem,
            coords = { x = coords.x, y = coords.y, z = coords.z },
            online = true
        }
    end

    table.sort(list, function(a, b)
        return a.id < b.id
    end)

    return list, staffOnline
end

function P.EnsureTables()

    MySQL.query.await(([=[
    CREATE TABLE IF NOT EXISTS `staff_duty_logs` (
      `id` INT NOT NULL AUTO_INCREMENT,
      `staff_src` INT NULL,
      `staff_name` VARCHAR(255) NULL,
      `staff_license` VARCHAR(80) NOT NULL,
      `role` VARCHAR(64) NULL,
      `action` VARCHAR(24) NOT NULL,
      `status` VARCHAR(32) NULL,
      `started_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
      `ended_at` TIMESTAMP NULL DEFAULT NULL,
      `duration_seconds` INT NULL DEFAULT 0,
      `date_ref` DATE NULL,
      `metadata` LONGTEXT NULL,
      PRIMARY KEY (`id`),
      KEY `idx_staff_license` (`staff_license`),
      KEY `idx_action` (`action`),
      KEY `idx_date_ref` (`date_ref`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]=]))

    MySQL.query.await(([=[
        CREATE TABLE IF NOT EXISTS `staff_daily_stats` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `staff_license` VARCHAR(80) NOT NULL,
        `staff_name` VARCHAR(255) NULL,
        `date_ref` DATE NOT NULL,
        `seconds_on_duty` INT NULL DEFAULT 0,
        `reports_handled` INT NULL DEFAULT 0,
        `reports_closed` INT NULL DEFAULT 0,
        `warns_applied` INT NULL DEFAULT 0,
        `bans_applied` INT NULL DEFAULT 0,
        `revives_done` INT NULL DEFAULT 0,
        `teleports_done` INT NULL DEFAULT 0,
        `spectates_done` INT NULL DEFAULT 0,
        PRIMARY KEY (`id`),
        UNIQUE KEY `uniq_staff_day` (`staff_license`, `date_ref`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]=]))
    MySQL.query.await(([=[
        CREATE TABLE IF NOT EXISTS `%s` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `name` VARCHAR(255) NULL,
            `license` VARCHAR(80) NULL,
            `discord` VARCHAR(80) NULL,
            `ip` VARCHAR(80) NULL,
            `reason` VARCHAR(255) NULL,
            `expire` BIGINT NULL DEFAULT 0,
            `bannedby` VARCHAR(255) NULL,
            `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `idx_license` (`license`),
            KEY `idx_discord` (`discord`),
            KEY `idx_ip` (`ip`),
            KEY `idx_expire` (`expire`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]=]):format(Config.BanTable))


    pcall(function()
        MySQL.query.await(("ALTER TABLE `%s` ADD COLUMN IF NOT EXISTS `status` VARCHAR(24) NULL DEFAULT 'active'"):format(Config.BanTable))
        MySQL.query.await(('ALTER TABLE `%s` ADD COLUMN IF NOT EXISTS `expired_at` TIMESTAMP NULL DEFAULT NULL'):format(Config.BanTable))
        MySQL.query.await(('ALTER TABLE `%s` ADD COLUMN IF NOT EXISTS `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP'):format(Config.BanTable))
        pcall(function() MySQL.query.await(("ALTER TABLE `%s` ADD INDEX `idx_status` (`status`)"):format(Config.BanTable)) end)
    end)

    MySQL.query.await(([=[
        CREATE TABLE IF NOT EXISTS `%s` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `senderIdentifier` VARCHAR(80) NULL,
            `targetIdentifier` VARCHAR(80) NULL,
            `reason` TEXT NULL,
            `warnId` VARCHAR(40) NULL,
            `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `uniq_warnid` (`warnId`),
            KEY `idx_targetIdentifier` (`targetIdentifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]=]):format(Config.WarnTable))

    MySQL.query.await(([=[
        CREATE TABLE IF NOT EXISTS `%s` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `category` VARCHAR(64) NOT NULL,
            `action` VARCHAR(64) NOT NULL,
            `actor_src` INT NULL,
            `actor_name` VARCHAR(255) NULL,
            `actor_license` VARCHAR(80) NULL,
            `target_src` INT NULL,
            `target_name` VARCHAR(255) NULL,
            `target_license` VARCHAR(80) NULL,
            `message` TEXT NULL,
            `metadata` LONGTEXT NULL,
            `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `idx_category` (`category`),
            KEY `idx_action` (`action`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]=]):format(Config.LogTable or 'staff_logs'))

    MySQL.query.await(([=[
        CREATE TABLE IF NOT EXISTS `%s` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `player_src` INT NULL,
            `player_name` VARCHAR(255) NULL,
            `player_license` VARCHAR(80) NULL,
            `player_citizenid` VARCHAR(80) NULL,
            `message` TEXT NULL,
            `status` VARCHAR(32) NOT NULL DEFAULT 'pendente',
            `priority` VARCHAR(32) NULL DEFAULT 'normal',
            `waiting_on` VARCHAR(24) NULL DEFAULT 'staff',
            `accepted_by_src` INT NULL,
            `accepted_by_name` VARCHAR(255) NULL,
            `accepted_at` TIMESTAMP NULL DEFAULT NULL,
            `claimed_by_license` VARCHAR(80) NULL,
            `closed_by_src` INT NULL,
            `closed_by_name` VARCHAR(255) NULL,
            `closed_at` TIMESTAMP NULL DEFAULT NULL,
            `closed_reason` VARCHAR(255) NULL,
            `response` TEXT NULL,
            `tags` VARCHAR(255) NULL,
            `last_message_at` TIMESTAMP NULL DEFAULT NULL,
            `last_message_by` VARCHAR(24) NULL,
            `reopened_count` INT NULL DEFAULT 0,
            `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `idx_status` (`status`),
            KEY `idx_priority` (`priority`),
            KEY `idx_player_license` (`player_license`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]=]):format(Config.ReportTable or 'staff_reports'))

    MySQL.query.await(([=[
        CREATE TABLE IF NOT EXISTS `%s` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `report_id` INT NOT NULL,
            `sender_type` VARCHAR(24) NOT NULL,
            `sender_src` INT NULL,
            `sender_name` VARCHAR(255) NULL,
            `sender_license` VARCHAR(80) NULL,
            `message` TEXT NULL,
            `metadata` LONGTEXT NULL,
            `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `idx_report_id` (`report_id`),
            KEY `idx_sender_type` (`sender_type`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]=]):format(Config.ReportMessagesTable or 'staff_report_messages'))

    local reportTable = Config.ReportTable or 'staff_reports'
    local alters = {
        ("ALTER TABLE `%s` ADD COLUMN `waiting_on` VARCHAR(24) NULL DEFAULT 'staff' AFTER `priority`"):format(reportTable),
        ("ALTER TABLE `%s` ADD COLUMN `claimed_by_license` VARCHAR(80) NULL AFTER `accepted_at`"):format(reportTable),
        ("ALTER TABLE `%s` ADD COLUMN `closed_reason` VARCHAR(255) NULL AFTER `closed_at`"):format(reportTable),
        ("ALTER TABLE `%s` ADD COLUMN `tags` VARCHAR(255) NULL AFTER `response`"):format(reportTable),
        ("ALTER TABLE `%s` ADD COLUMN `last_message_at` TIMESTAMP NULL DEFAULT NULL AFTER `tags`"):format(reportTable),
        ("ALTER TABLE `%s` ADD COLUMN `last_message_by` VARCHAR(24) NULL AFTER `last_message_at`"):format(reportTable),
        ("ALTER TABLE `%s` ADD COLUMN `reopened_count` INT NULL DEFAULT 0 AFTER `last_message_by`"):format(reportTable)
    }

    for _, sql in ipairs(alters) do
        pcall(function()
            MySQL.query.await(sql)
        end)
    end
end

CreateThread(function()
    P.EnsureTables()
end)

QBCore.Functions.CreateCallback('mz_staffpanel:server:canOpen', function(src, cb)
    cb(P.CanOpen(src), P.BuildPermMap(src))
end)

QBCore.Functions.CreateCallback('mz_staffpanel:server:getData', function(src, cb)
    if not P.CanOpen(src) then
        return cb(false)
    end

    local players, staffOnline = P.GetOnlinePlayersData()
    local totalBans = MySQL.scalar.await(('SELECT COUNT(*) FROM `%s`'):format(Config.BanTable)) or 0
    local totalWarns = MySQL.scalar.await(('SELECT COUNT(*) FROM `%s`'):format(Config.WarnTable)) or 0
    local openReports = MySQL.scalar.await(([[SELECT COUNT(*) FROM `%s` WHERE status IN ('pendente', 'em_atendimento', 'aguardando_player', 'aguardando_staff')]]):format(Config.ReportTable or 'staff_reports')) or 0
    local reportRows = P.FetchRecentReports(25)
    local logsPage = P.FetchLogsPage(1, 20, {})
    local commandRows = MySQL.query.await(('SELECT * FROM `%s` WHERE category = ? ORDER BY id DESC LIMIT 10'):format(Config.LogTable or 'staff_logs'), { 'command' }) or {}
    local banPage = P.FetchBansPage and P.FetchBansPage(1, 15, {}) or { rows = {}, total = 0, page = 1, pageSize = 15, totalPages = 1, filters = {} }

    cb({
        ok = true,
        theme = Config.Theme,
        me = src,
        perms = P.BuildPermMap(src),
        players = players,
        vehicles = P.BuildPermMap(src).spawnVehicle and P.GetVehicleList() or {},
        reports = reportRows,
        logs = logsPage.rows,
        logsPage = logsPage,
        recentCommands = commandRows,
        bans = banPage.rows,
        bansPage = banPage,
        stats = {
            online = #players,
            staffOnline = staffOnline,
            totalBans = tonumber(totalBans) or 0,
            totalWarns = tonumber(totalWarns) or 0,
            openReports = tonumber(openReports) or 0
        },
        vehiclePreviewLimit = tonumber(Config.VehiclePreviewLimit or 120) or 120
    })
end)

QBCore.Functions.CreateCallback('mz_staffpanel:server:getPlayerAdminHistory', function(src, cb, targetId)
    if not P.CanOpen(src) then
        return cb({ ok = false, error = 'Sem permissão.' })
    end

    targetId = tonumber(targetId or 0) or 0
    if targetId <= 0 then
        return cb({ ok = false, error = 'Jogador inválido.' })
    end

    --local players = P.GetOnlinePlayersData()
    local players = select(1, P.GetOnlinePlayersData())
    local targetPlayer = nil

    for _, row in ipairs(players) do
        if tonumber(row.id or 0) == targetId then
            targetPlayer = row
            break
        end
    end

    if not targetPlayer then
        return cb({ ok = false, error = 'Jogador não encontrado.' })
    end

    local license = tostring(targetPlayer.license or '')
    local warns = P.GetWarnHistoryByLicense and P.GetWarnHistoryByLicense(license) or {}
    local bans = MySQL.query.await(('SELECT * FROM `%s` WHERE license = ? ORDER BY id DESC'):format(Config.BanTable), {
        license
    }) or {}

    cb({
        ok = true,
        warns = warns,
        bans = bans,
        player = targetPlayer
    })
end)

QBCore.Functions.CreateCallback('mz_staffpanel:server:getLogsPage', function(src, cb, page, pageSize, filters)
    if not P.CanOpen(src) then
        return cb({ ok = false, error = 'Sem permissão.' })
    end

    local payload = P.FetchLogsPage(page, pageSize, filters)
    payload.ok = true
    cb(payload)
end)

QBCore.Functions.CreateCallback('mz_staffpanel:server:getBansPage', function(src, cb, page, pageSize, filters)
    if not P.CanOpen(src) then
        return cb({ ok = false, error = 'Sem permissão.' })
    end

    local payload = P.FetchBansPage(page, pageSize, filters)
    payload.ok = true
    cb(payload)
end)
