local QBCore = exports['qb-core']:GetCoreObject()

local frozenPlayers = {}
local adminSpectateState = {}
local wallWatchers = {}
MZ_STAFFPANEL = MZ_STAFFPANEL or {}

math.randomseed(os.time())

local function hasQBBypass(src)
    for _, perm in ipairs(Config.QBBypassPermissions or { 'admin', 'god' }) do
        if QBCore.Functions.HasPermission(src, perm) then
            return true
        end
    end

    for _, ace in ipairs(Config.AceBypassPermissions or {}) do
        if ace and ace ~= '' and IsPlayerAceAllowed(src, ace) then
            return true
        end
    end

    return false
end

local function hasLevel(src, level)
    if not level or level == '' then return true end
    if hasQBBypass(src) then return true end
    return exports['mz_perm'] and exports['mz_perm']:HasStaff(src, level) or false
end

local function canOpen(src)
    return hasLevel(src, Config.MenuAccess)
end

local function notify(src, msg, typ)
    TriggerClientEvent('QBCore:Notify', src, msg, typ or 'primary')
end

local function getPlayerNameSafe(Player)
    if not Player then return 'Desconhecido' end
    local ci = Player.PlayerData.charinfo or {}
    local fullname = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    if fullname == '' then fullname = GetPlayerName(Player.PlayerData.source) or ('ID ' .. tostring(Player.PlayerData.source)) end
    return fullname
end

local function getIdentifierSafe(src, kind)
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

local function buildPermMap(src)
    local out = {}
    for action, level in pairs(Config.ActionPerms) do
        out[action] = hasLevel(src, level)
    end
    out.panel = canOpen(src)
    return out
end

local function getVehicleList()
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
    table.sort(out, function(a, b) return (a.name or a.spawn) < (b.name or b.spawn) end)
    return out
end

local function getOnlinePlayersData()
    local list, staffOnline = {}, 0
    local players = QBCore.Functions.GetQBPlayers()
    for _, Player in pairs(players) do
        local metaPerms = (Player.PlayerData.metadata and Player.PlayerData.metadata.perms) or {}
        local staffNames = {}
        for name, enabled in pairs(metaPerms.staff or {}) do
            if enabled then staffNames[#staffNames + 1] = name end
        end
        table.sort(staffNames)
        if #staffNames > 0 or hasQBBypass(Player.PlayerData.source) then
            staffOnline = staffOnline + 1
        end
        local src = Player.PlayerData.source
        local ped = GetPlayerPed(src)
        local coords = ped ~= 0 and GetEntityCoords(ped) or vec3(0.0, 0.0, 0.0)
        local health = ped ~= 0 and GetEntityHealth(ped) or 0
        local armor = ped ~= 0 and GetPedArmour(ped) or 0
        local identifiers = {
            license = Player.PlayerData.license or getIdentifierSafe(src, 'license') or '-',
            discord = getIdentifierSafe(src, 'discord') or '-',
            steam = getIdentifierSafe(src, 'steam') or '-',
            fivem = getIdentifierSafe(src, 'fivem') or '-'
        }
        list[#list + 1] = {
            id = src,
            name = getPlayerNameSafe(Player),
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
            coords = { x = coords.x, y = coords.y, z = coords.z }
        }
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list, staffOnline
end

local function ensureTables()
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
            `accepted_by_src` INT NULL,
            `accepted_by_name` VARCHAR(255) NULL,
            `accepted_at` TIMESTAMP NULL DEFAULT NULL,
            `closed_by_src` INT NULL,
            `closed_by_name` VARCHAR(255) NULL,
            `closed_at` TIMESTAMP NULL DEFAULT NULL,
            `response` TEXT NULL,
            `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `idx_status` (`status`),
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
end

CreateThread(function()
    ensureTables()
end)

local function safeJson(data)
    local ok, encoded = pcall(json.encode, data or {})
    return ok and encoded or '{}'
end

local function getActorInfo(src)
    if not src or src == 0 then
        return { src = 0, name = 'SYSTEM', license = 'system' }
    end
    local Player = QBCore.Functions.GetPlayer(src)
    return {
        src = src,
        name = Player and getPlayerNameSafe(Player) or (GetPlayerName(src) or ('ID ' .. tostring(src))),
        license = (Player and Player.PlayerData.license) or getIdentifierSafe(src, 'license') or '-'
    }
end

local function getTargetInfo(targetSrc)
    if not targetSrc then return { src = nil, name = nil, license = nil } end
    local Player = QBCore.Functions.GetPlayer(targetSrc)
    return {
        src = tonumber(targetSrc),
        name = Player and getPlayerNameSafe(Player) or (GetPlayerName(targetSrc) or ('ID ' .. tostring(targetSrc))),
        license = (Player and Player.PlayerData.license) or getIdentifierSafe(targetSrc, 'license') or '-'
    }
end

local function addLog(category, action, actorSrc, targetSrc, message, metadata)
    local actor = getActorInfo(actorSrc)
    local target = getTargetInfo(targetSrc)
    local ok, err = pcall(function()
        MySQL.insert.await(('INSERT INTO `%s` (category, action, actor_src, actor_name, actor_license, target_src, target_name, target_license, message, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'):format(Config.LogTable or 'staff_logs'), {
            tostring(category or 'general'),
            tostring(action or 'event'),
            actor.src,
            actor.name,
            actor.license,
            target.src,
            target.name,
            target.license,
            tostring(message or ''),
            safeJson(metadata)
        })
    end)
    if not ok then
        print('^1[mz_staffpanel] log insert error:^7', err)
    end
end

local function addReportMessage(reportId, senderType, senderSrc, message, metadata)
    reportId = tonumber(reportId or 0) or 0
    if reportId <= 0 then return false end
    local actor = getActorInfo(senderSrc or 0)
    MySQL.insert.await(('INSERT INTO `%s` (report_id, sender_type, sender_src, sender_name, sender_license, message, metadata) VALUES (?, ?, ?, ?, ?, ?, ?)'):format(Config.ReportMessagesTable or 'staff_report_messages'), {
        reportId,
        tostring(senderType or 'system'),
        actor.src,
        actor.name,
        actor.license,
        tostring(message or ''),
        safeJson(metadata)
    })
    addLog('report_chat', tostring(senderType or 'system'), senderSrc or 0, nil, tostring(message or ''), { reportId = reportId, metadata = metadata or {} })
    return true
end

local function getReportById(reportId)
    reportId = tonumber(reportId or 0) or 0
    if reportId <= 0 then return nil end
    local rows = MySQL.query.await(('SELECT * FROM `%s` WHERE id = ? LIMIT 1'):format(Config.ReportTable or 'staff_reports'), { reportId }) or {}
    return rows[1]
end

local function getReportMessages(reportId)
    reportId = tonumber(reportId or 0) or 0
    if reportId <= 0 then return {} end
    return MySQL.query.await(('SELECT * FROM `%s` WHERE report_id = ? ORDER BY id ASC'):format(Config.ReportMessagesTable or 'staff_report_messages'), { reportId }) or {}
end

local function canAccessReport(src, reportRow)
    if not reportRow then return false end
    if canOpen(src) then return true end
    local Player = QBCore.Functions.GetPlayer(src)
    local license = (Player and Player.PlayerData.license) or getIdentifierSafe(src, 'license') or '-'
    return tonumber(reportRow.player_src or 0) == tonumber(src) or tostring(reportRow.player_license or '-') == tostring(license)
end

local function createReport(src, msg, origin)
    local Player = QBCore.Functions.GetPlayer(src)
    local reportId = MySQL.insert.await(('INSERT INTO `%s` (player_src, player_name, player_license, player_citizenid, message, status, priority) VALUES (?, ?, ?, ?, ?, ?, ?)'):format(Config.ReportTable or 'staff_reports'), {
        src,
        Player and getPlayerNameSafe(Player) or (GetPlayerName(src) or ('ID ' .. tostring(src))),
        (Player and Player.PlayerData.license) or getIdentifierSafe(src, 'license') or '-',
        Player and Player.PlayerData.citizenid or '-',
        tostring(msg or ''),
        'pendente',
        'normal'
    })
    addLog('report', 'create', src, nil, tostring(msg or ''), { reportId = reportId, origin = origin or 'command' })
    addReportMessage(reportId, 'player', src, tostring(msg or ''), { kind = 'initial', origin = origin or 'command' })
    return reportId
end

local function fetchRecentLogs(limit)
    return MySQL.query.await(('SELECT * FROM `%s` ORDER BY id DESC LIMIT %d'):format(Config.LogTable or 'staff_logs', tonumber(limit or 20) or 20)) or {}
end

local function fetchRecentReports(limit)
    return MySQL.query.await(('SELECT * FROM `%s` ORDER BY id DESC LIMIT %d'):format(Config.ReportTable or 'staff_reports', tonumber(limit or 20) or 20)) or {}
end

QBCore.Functions.CreateCallback('mz_staffpanel:server:canOpen', function(src, cb)
    cb(canOpen(src), buildPermMap(src))
end)

QBCore.Functions.CreateCallback('mz_staffpanel:server:getData', function(src, cb)
    if not canOpen(src) then return cb(false) end
    local players, staffOnline = getOnlinePlayersData()
    local totalBans = MySQL.scalar.await(('SELECT COUNT(*) FROM `%s`'):format(Config.BanTable)) or 0
    local totalWarns = MySQL.scalar.await(('SELECT COUNT(*) FROM `%s`'):format(Config.WarnTable)) or 0
    local openReports = MySQL.scalar.await(([[SELECT COUNT(*) FROM `%s` WHERE status IN ('pendente', 'em_atendimento')]]):format(Config.ReportTable or 'staff_reports')) or 0
    local reportRows = fetchRecentReports(25)
    local logRows = fetchRecentLogs(40)
    local commandRows = MySQL.query.await(('SELECT * FROM `%s` WHERE category = ? ORDER BY id DESC LIMIT 10'):format(Config.LogTable or 'staff_logs'), { 'command' }) or {}
    local banRows = MySQL.query.await(('SELECT * FROM `%s` ORDER BY id DESC LIMIT 20'):format(Config.BanTable)) or {}
    cb({
        ok = true,
        theme = Config.Theme,
        me = src,
        perms = buildPermMap(src),
        players = players,
        vehicles = buildPermMap(src).spawnVehicle and getVehicleList() or {},
        reports = reportRows,
        logs = logRows,
        recentCommands = commandRows,
        bans = banRows,
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

QBCore.Functions.CreateCallback('mz_staffpanel:server:getSupportSession', function(src, cb, reportId)
    reportId = tonumber(reportId or 0) or 0
    local reportRow = nil

    if reportId > 0 then
        reportRow = getReportById(reportId)
    else
        local Player = QBCore.Functions.GetPlayer(src)
        local license = (Player and Player.PlayerData.license) or getIdentifierSafe(src, 'license') or '-'
        local rows = MySQL.query.await(('SELECT * FROM `%s` WHERE player_license = ? AND status IN (?, ?) ORDER BY id DESC LIMIT 1'):format(Config.ReportTable or 'staff_reports'), { license, 'pendente', 'em_atendimento' }) or {}
        reportRow = rows[1]
    end

    if reportRow and not canAccessReport(src, reportRow) then
        return cb({ ok = false, error = 'Sem acesso ao atendimento.' })
    end

    cb({
        ok = true,
        canManage = canOpen(src),
        report = reportRow,
        messages = reportRow and getReportMessages(reportRow.id) or {}
    })
end)

local function requireAction(src, action)
    local level = Config.ActionPerms[action]
    if not level then return true end
    if not hasLevel(src, level) then
        notify(src, 'Você não tem permissão para esta ação.', 'error')
        return false
    end
    return true
end

local function getTarget(src, targetId)
    targetId = tonumber(targetId)
    if not targetId then
        notify(src, 'ID inválido.', 'error')
        return nil
    end
    local Player = QBCore.Functions.GetPlayer(targetId)
    if not Player then
        notify(src, 'Jogador não encontrado.', 'error')
        return nil
    end
    return Player
end

local function isOnline(src)
    return src and GetPlayerPing(src) and GetPlayerPing(src) > 0
end

local function getPedCoordsHeading(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil, nil end
    local c = GetEntityCoords(ped)
    local h = GetEntityHeading(ped)
    return { x = c.x, y = c.y, z = c.z }, h
end

local function stopSpectate(src, silent)
    local st = adminSpectateState[src]
    if not st then return end
    adminSpectateState[src] = nil
    if st.returnBucket ~= nil then
        SetPlayerRoutingBucket(src, tonumber(st.returnBucket) or 0)
    end
    TriggerClientEvent('mz_staffpanel:client:stopSpectate', src, st.returnCoords, st.returnHeading, silent == true)
end

local function broadcastToAdmins(messageArgs, color)
    local players = GetPlayers()
    for _, pid in ipairs(players) do
        pid = tonumber(pid)
        if pid and (hasQBBypass(pid) or canOpen(pid)) then
            if not QBCore.Functions.IsOptin or QBCore.Functions.IsOptin(pid) then
                TriggerClientEvent('chat:addMessage', pid, { color = color or {255, 0, 0}, multiline = true, args = messageArgs })
            end
        end
    end
end

local function getVehicleModelByHash(hash)
    for spawn, v in pairs(QBCore.Shared.Vehicles or {}) do
        if tonumber(v.hash) == tonumber(hash) then
            return tostring(v.model or spawn or ''):lower(), v
        end
    end
    return nil, nil
end

local function banPlayerByAdmin(src, targetSrc, seconds, reason)
    local expiresAt = 2147483647
    if tonumber(seconds) and tonumber(seconds) > 0 then
        expiresAt = tonumber(os.time() + tonumber(seconds))
        if expiresAt > 2147483647 then expiresAt = 2147483647 end
    end

    local name = GetPlayerName(targetSrc) or ('ID ' .. tostring(targetSrc))
    local license = getIdentifierSafe(targetSrc, 'license')
    local discord = getIdentifierSafe(targetSrc, 'discord')
    local ip = getIdentifierSafe(targetSrc, 'ip')
    local bannedBy = GetPlayerName(src) or ('ID ' .. tostring(src))

    if not license and not discord and not ip then
        error('Nenhum identificador válido encontrado para o alvo do ban.')
    end

    MySQL.insert.await(('INSERT INTO `%s` (name, license, discord, ip, reason, expire, bannedby) VALUES (?, ?, ?, ?, ?, ?, ?)'):format(Config.BanTable), {
        name,
        license,
        discord,
        ip,
        reason,
        expiresAt,
        bannedBy
    })

    TriggerClientEvent('chat:addMessage', -1, {
        template = "<div class=chat-message server'><strong>ADMIN | {0} foi banido:</strong> {1}</div>",
        args = { name, reason }
    })

    if expiresAt >= 2147483647 then
        DropPlayer(targetSrc, ('Você foi banido permanentemente.\nMotivo: %s'):format(reason))
    else
        local t = os.date('*t', expiresAt)
        DropPlayer(targetSrc, ('Você foi banido.\nMotivo: %s\nExpira em: %02d/%02d/%04d %02d:%02d'):format(reason, t.day, t.month, t.year, t.hour, t.min))
    end
end

local function addWarn(src, targetSrc, reason)
    local sender = QBCore.Functions.GetPlayer(src)
    local target = QBCore.Functions.GetPlayer(targetSrc)
    if not sender or not target then return false, 'Jogador offline.' end

    local senderIdentifier = sender.PlayerData.license or getIdentifierSafe(src, 'license')
    local targetIdentifier = target.PlayerData.license or getIdentifierSafe(targetSrc, 'license')
    if not senderIdentifier or not targetIdentifier then
        return false, 'Licença não encontrada.'
    end

    local warnId = ('WARN-%d-%d'):format(os.time(), math.random(1111, 999999))
    local inserted = MySQL.insert.await(('INSERT INTO `%s` (senderIdentifier, targetIdentifier, reason, warnId) VALUES (?, ?, ?, ?)'):format(Config.WarnTable), {
        senderIdentifier,
        targetIdentifier,
        tostring(reason or ''),
        warnId
    })

    if not inserted then
        return false, 'Falha ao registrar warn.'
    end

    return true, warnId
end

local function checkWarns(targetSrc)
    local target = QBCore.Functions.GetPlayer(targetSrc)
    if not target then return nil end
    local targetIdentifier = target.PlayerData.license or getIdentifierSafe(targetSrc, 'license')
    if not targetIdentifier then return nil end
    return MySQL.query.await(('SELECT * FROM `%s` WHERE targetIdentifier = ? ORDER BY id DESC'):format(Config.WarnTable), { targetIdentifier }) or {}
end

local function deleteWarn(targetSrc, index)
    local warns = checkWarns(targetSrc) or {}
    local selected = warns[tonumber(index or 0)]
    if not selected then return false, 'Warn não encontrado.' end
    MySQL.query.await(('DELETE FROM `%s` WHERE warnId = ?'):format(Config.WarnTable), { selected.warnId })
    return true, selected
end

local function handleAction(src, payload)
    if type(payload) ~= 'table' or not canOpen(src) then return end

    local action = payload.action
    local targetPlayer = payload.target and getTarget(src, payload.target)
    if payload.target and not targetPlayer then return end
    local function actionLog(category, message, metadata)
        addLog(category or 'action', tostring(action or 'unknown'), src, targetPlayer and targetPlayer.PlayerData.source or nil, message, metadata or payload)
    end

    if action == 'revive' then
        if not requireAction(src, action) then return end
        TriggerClientEvent('hospital:client:Revive', targetPlayer.PlayerData.source)
        TriggerClientEvent('qb-ambulancejob:client:revive', targetPlayer.PlayerData.source)
        notify(src, ('Você reviveu ID %s.'):format(targetPlayer.PlayerData.source), 'success')
        actionLog('admin_action', 'Reviveu jogador.', { target = targetPlayer.PlayerData.source })

    elseif action == 'heal' then
        if not requireAction(src, action) then return end
        TriggerClientEvent('mz_staffpanel:client:healPlayer', targetPlayer and targetPlayer.PlayerData.source or src)
        notify(src, 'Heal aplicado.', 'success')
        actionLog('admin_action', 'Aplicou heal.', { target = targetPlayer and targetPlayer.PlayerData.source or src })

    elseif action == 'kill' then
        if not requireAction(src, action) then return end
        TriggerClientEvent('mz_staffpanel:client:killPlayer', targetPlayer.PlayerData.source)
        notify(src, ('Você matou ID %s.'):format(targetPlayer.PlayerData.source), 'success')
        actionLog('admin_action', 'Matou jogador.', { target = targetPlayer.PlayerData.source })

    elseif action == 'freeze' then
        if not requireAction(src, action) then return end
        local state = not frozenPlayers[targetPlayer.PlayerData.source]
        frozenPlayers[targetPlayer.PlayerData.source] = state
        TriggerClientEvent('mz_staffpanel:client:setFrozen', targetPlayer.PlayerData.source, state)
        notify(src, (state and 'Jogador congelado.' or 'Jogador descongelado.'), 'success')
        actionLog('admin_action', state and 'Congelou jogador.' or 'Descongelou jogador.', { target = targetPlayer.PlayerData.source, state = state })

    elseif action == 'gotoPlayer' then
        if not requireAction(src, action) then return end
        local ped = GetPlayerPed(targetPlayer.PlayerData.source)
        if ped == 0 then return notify(src, 'Ped do jogador não encontrado.', 'error') end
        local coords = GetEntityCoords(ped)
        TriggerClientEvent('mz_staffpanel:client:teleportToCoords', src, { x = coords.x, y = coords.y, z = coords.z + 1.0 })
        notify(src, ('Teleportado até ID %s.'):format(targetPlayer.PlayerData.source), 'success')
        actionLog('admin_action', 'Teleportou até jogador.', { target = targetPlayer.PlayerData.source })

    elseif action == 'bringPlayer' then
        if not requireAction(src, action) then return end
        local ped = GetPlayerPed(src)
        if ped == 0 then return notify(src, 'Seu ped não foi encontrado.', 'error') end
        local coords = GetEntityCoords(ped)
        TriggerClientEvent('mz_staffpanel:client:teleportToCoords', targetPlayer.PlayerData.source, { x = coords.x, y = coords.y, z = coords.z + 1.0 })
        notify(src, ('Você trouxe ID %s.'):format(targetPlayer.PlayerData.source), 'success')
        actionLog('admin_action', 'Trouxe jogador.', { target = targetPlayer.PlayerData.source })

    elseif action == 'spectate' then
        if not requireAction(src, action) then return end
        local adminSrc = src
        local targetSrc = targetPlayer.PlayerData.source
        if targetSrc == adminSrc then return notify(adminSrc, 'Você não pode espectar você mesmo.', 'error') end
        if adminSpectateState[adminSrc] and adminSpectateState[adminSrc].target == targetSrc then
            stopSpectate(adminSrc, false)
            return
        end
        if adminSpectateState[adminSrc] then stopSpectate(adminSrc, true) end
        local returnCoords, returnHeading = getPedCoordsHeading(adminSrc)
        if not returnCoords then return notify(adminSrc, 'Não consegui capturar sua posição.', 'error') end
        adminSpectateState[adminSrc] = {
            active = true,
            target = targetSrc,
            returnCoords = returnCoords,
            returnHeading = returnHeading or 0.0,
            returnBucket = GetPlayerRoutingBucket(adminSrc) or 0
        }
        TriggerClientEvent('mz_staffpanel:client:startSpectate', adminSrc, targetSrc)
        notify(adminSrc, ('Espectando ID %s. Use /%s para sair.'):format(targetSrc, Config.Commands.specoff), 'primary')
        actionLog('admin_action', 'Iniciou spectate.', { target = targetSrc })

    elseif action == 'spectateStop' then
        if not requireAction(src, 'spectate') then return end
        stopSpectate(src, false)

    elseif action == 'kick' then
        if not requireAction(src, action) then return end
        local reason = tostring(payload.reason or 'Removido pela staff')
        QBCore.Functions.Kick(targetPlayer.PlayerData.source, reason, nil, nil)
        notify(src, ('Você kickou ID %s.'):format(targetPlayer.PlayerData.source), 'success')
        actionLog('admin_action', reason, { target = targetPlayer.PlayerData.source })

    elseif action == 'kickall' then
        if not requireAction(src, action) then return end
        local reason = tostring(payload.reason or 'Servidor reiniciando')
        for _, pid in ipairs(GetPlayers()) do
            DropPlayer(pid, reason)
        end
        actionLog('admin_action', reason, { scope = 'all' })

    elseif action == 'ban' then
        if not requireAction(src, action) then return end
        local seconds = tonumber(payload.seconds or Config.DefaultBanSeconds) or Config.DefaultBanSeconds
        local reason = tostring(payload.reason or 'Banido pela staff')
        local ok, err = pcall(banPlayerByAdmin, src, targetPlayer.PlayerData.source, seconds, reason)
        if ok then
            notify(src, ('Você baniu ID %s.'):format(targetPlayer.PlayerData.source), 'success')
            actionLog('ban', reason, { target = targetPlayer.PlayerData.source, seconds = seconds })
        else
            notify(src, 'Falha ao banir. Verifique a tabela bans.', 'error')
            print('^1[mz_staffpanel] ban error:^7', err)
        end

    elseif action == 'warn' then
        if not requireAction(src, action) then return end
        local reason = tostring(payload.reason or 'Aviso da staff')
        local ok, warnIdOrError = addWarn(src, targetPlayer.PlayerData.source, reason)
        if ok then
            TriggerClientEvent('chat:addMessage', targetPlayer.PlayerData.source, { args = { 'SYSTEM', ('Você recebeu um warn de %s. Motivo: %s'):format(GetPlayerName(src), reason) }, color = {255, 0, 0} })
            notify(src, ('Warn aplicado: %s'):format(warnIdOrError), 'success')
            actionLog('warn', reason, { target = targetPlayer.PlayerData.source, warnId = warnIdOrError })
        else
            notify(src, warnIdOrError or 'Falha ao aplicar warn. Verifique a tabela player_warns.', 'error')
            print('^1[mz_staffpanel] warn error:^7', warnIdOrError)
        end

    elseif action == 'noclip' then
        if not requireAction(src, action) then return end
        TriggerClientEvent('mz_staffpanel:client:toggleNoClip', src)
        actionLog('admin_action', 'Alternou noclip.', {})

    elseif action == 'invisible' then
        if not requireAction(src, action) then return end
        TriggerClientEvent('mz_staffpanel:client:toggleInvisible', src)
        actionLog('admin_action', 'Alternou invisibilidade.', {})

    elseif action == 'god' then
        if not requireAction(src, action) then return end
        TriggerClientEvent('mz_staffpanel:client:toggleGod', src)
        actionLog('admin_action', 'Alternou godmode.', {})

    elseif action == 'names' then
        if not requireAction(src, action) then return end
        TriggerClientEvent('mz_staffpanel:client:toggleNames', src)
        actionLog('admin_action', 'Alternou nomes.', {})

    elseif action == 'blips' then
        if not requireAction(src, action) then return end
        TriggerClientEvent('mz_staffpanel:client:toggleBlips', src)
        actionLog('admin_action', 'Alternou blips.', {})

    elseif action == 'wall' then
        if not requireAction(src, action) then return end
        TriggerClientEvent('mz_staffpanel:client:toggleWall', src)
        actionLog('admin_action', 'Alternou wall.', {})

    elseif action == 'coords' then
        if not requireAction(src, action) then return end
        TriggerClientEvent('mz_staffpanel:client:toggleCoords', src)

    elseif action == 'copyVector2' then
        if not requireAction(src, 'vector') then return end
        TriggerClientEvent('mz_staffpanel:client:copyToClipboard', src, 'coords2')

    elseif action == 'copyVector3' then
        if not requireAction(src, 'vector') then return end
        TriggerClientEvent('mz_staffpanel:client:copyToClipboard', src, 'coords3')

    elseif action == 'copyVector4' then
        if not requireAction(src, 'vector') then return end
        TriggerClientEvent('mz_staffpanel:client:copyToClipboard', src, 'coords4')

    elseif action == 'copyHeading' then
        if not requireAction(src, 'heading') then return end
        TriggerClientEvent('mz_staffpanel:client:copyToClipboard', src, 'heading')

    elseif action == 'reporttoggle' then
        if not requireAction(src, action) then return end
        if QBCore.Functions.ToggleOptin then QBCore.Functions.ToggleOptin(src) end
        if QBCore.Functions.IsOptin and QBCore.Functions.IsOptin(src) then
            notify(src, 'Recebimento de reports ativado.', 'success')
            actionLog('report', 'Ativou recebimento de reports.', {})
        else
            notify(src, 'Recebimento de reports desativado.', 'error')
            actionLog('report', 'Desativou recebimento de reports.', {})
        end

    elseif action == 'announce' then
        if not requireAction(src, action) then return end
        local msg = tostring(payload.message or '')
        if msg == '' then return notify(src, 'Digite uma mensagem.', 'error') end
        TriggerClientEvent('chat:addMessage', -1, { color = {255, 0, 0}, multiline = true, args = { 'ANÚNCIO', msg } })
        actionLog('communication', msg, {})

    elseif action == 'staffchat' then
        if not requireAction(src, action) then return end
        local msg = tostring(payload.message or '')
        if msg == '' then return notify(src, 'Digite uma mensagem.', 'error') end
        broadcastToAdmins({ ('STAFF | %s'):format(GetPlayerName(src)), msg }, {255, 0, 0})
        actionLog('communication', msg, {})

    elseif action == 'replyReport' then
        if not requireAction(src, 'staffchat') then return end
        local msg = tostring(payload.message or '')
        if msg == '' then return notify(src, 'Mensagem inválida.', 'error') end
        local reportId = tonumber(payload.reportId or 0) or 0
        if reportId <= 0 then return notify(src, 'Report inválido.', 'error') end
        MySQL.update.await(('UPDATE `%s` SET response = ?, status = ?, accepted_by_src = ?, accepted_by_name = ?, accepted_at = IFNULL(accepted_at, NOW()) WHERE id = ?'):format(Config.ReportTable or 'staff_reports'), { msg, 'em_atendimento', src, GetPlayerName(src) or ('ID ' .. tostring(src)), reportId })
        addReportMessage(reportId, 'admin', src, msg, { action = 'reply' })
        notify(src, 'Resposta enviada no atendimento.', 'success')
        actionLog('report', msg, { target = targetPlayer and targetPlayer.PlayerData.source or nil, reportId = reportId })

    elseif action == 'reportAccept' then
        if not requireAction(src, 'staffchat') then return end
        local reportId = tonumber(payload.reportId or 0) or 0
        if reportId <= 0 then return notify(src, 'Report inválido.', 'error') end
        MySQL.update.await(('UPDATE `%s` SET status = ?, accepted_by_src = ?, accepted_by_name = ?, accepted_at = NOW() WHERE id = ?'):format(Config.ReportTable or 'staff_reports'), { 'em_atendimento', src, GetPlayerName(src) or ('ID ' .. tostring(src)), reportId })
        addReportMessage(reportId, 'system', 0, ('Atendimento assumido por %s.'):format(GetPlayerName(src) or ('ID ' .. tostring(src))), { action = 'accept', admin = src })
        notify(src, ('Report #%d assumido.'):format(reportId), 'success')
        actionLog('report', 'Assumiu report.', { reportId = reportId })

    elseif action == 'reportClose' then
        if not requireAction(src, 'staffchat') then return end
        local reportId = tonumber(payload.reportId or 0) or 0
        if reportId <= 0 then return notify(src, 'Report inválido.', 'error') end
        local status = tostring(payload.status or 'resolvido')
        local note = tostring(payload.note or '')
        MySQL.update.await(("UPDATE `%s` SET status = ?, closed_by_src = ?, closed_by_name = ?, closed_at = NOW(), response = CASE WHEN ? = '' THEN response ELSE ? END WHERE id = ?"):format(Config.ReportTable or "staff_reports"), { status, src, GetPlayerName(src) or ("ID " .. tostring(src)), note, note, reportId })
        if note ~= '' then
            addReportMessage(reportId, 'admin', src, note, { action = 'close_note', status = status })
        end
        addReportMessage(reportId, 'system', 0, ('Atendimento finalizado com status: %s.'):format(status), { action = 'close', status = status, note = note })
        notify(src, ('Report #%d finalizado.'):format(reportId), 'success')
        actionLog('report', 'Finalizou report.', { reportId = reportId, status = status, note = note })

    elseif action == 'setMyDimension' then
        if not requireAction(src, 'dimension') then return end
        local bucket = tonumber(payload.dimension or payload.bucket or 0) or 0
        if bucket < 0 then bucket = 0 end
        SetPlayerRoutingBucket(src, bucket)
        notify(src, ('Sua dimensão foi alterada para %d.'):format(bucket), 'success')
        actionLog('admin_action', 'Alterou a própria dimensão.', { bucket = bucket })

    elseif action == 'setDimension' then
        if not requireAction(src, 'dimension') then return end
        local bucket = tonumber(payload.dimension or payload.bucket or 0) or 0
        if bucket < 0 then bucket = 0 end
        SetPlayerRoutingBucket(targetPlayer.PlayerData.source, bucket)
        notify(src, ('Player %d foi para dimensão %d.'):format(targetPlayer.PlayerData.source, bucket), 'success')
        actionLog('admin_action', 'Alterou dimensão do jogador.', { target = targetPlayer.PlayerData.source, bucket = bucket })
        notify(targetPlayer.PlayerData.source, ('Você foi movido para dimensão %d.'):format(bucket), 'primary')

    elseif action == 'spawnVehicle' then
        if not requireAction(src, action) then return end
        local model = tostring(payload.model or ''):lower()
        if model == '' then return notify(src, 'Modelo inválido.', 'error') end
        TriggerClientEvent('mz_staffpanel:client:spawnVehicle', src, model)
        actionLog('vehicle', 'Spawnou veículo.', { model = model })

    elseif action == 'deleteVehicle' then
        if not requireAction(src, action) then return end
        TriggerClientEvent('mz_staffpanel:client:deleteVehicle', src)
        actionLog('vehicle', 'Deletou veículo.', {})

    elseif action == 'saveVehicle' then
        if not requireAction(src, action) then return end
        TriggerClientEvent('mz_staffpanel:client:requestSaveVehicle', src)
        actionLog('vehicle', 'Solicitou salvar veículo.', {})

    elseif action == 'maxmods' then
        if not requireAction(src, action) then return end
        TriggerClientEvent('mz_staffpanel:client:maxmodVehicle', src)
        actionLog('vehicle', 'Aplicou maxmods.', {})

    elseif action == 'intoVehicle' then
        if not requireAction(src, action) then return end
        local admin = GetPlayerPed(src)
        local targetPed = GetPlayerPed(targetPlayer.PlayerData.source)
        local vehicle = GetVehiclePedIsIn(targetPed, false)
        local seat = -1
        if vehicle ~= 0 then
            for i = -1, GetVehicleMaxNumberOfPassengers(vehicle) - 1 do
                if GetPedInVehicleSeat(vehicle, i) == 0 then
                    seat = i
                    break
                end
            end
            if seat ~= -1 then
                SetPedIntoVehicle(admin, vehicle, seat)
                notify(src, 'Você entrou no veículo do player.', 'success')
                actionLog('admin_action', 'Entrou no veículo do jogador.', { target = targetPlayer.PlayerData.source })
            else
                notify(src, 'Sem assento livre no veículo.', 'error')
            end
        else
            notify(src, 'O jogador não está em veículo.', 'error')
        end

    elseif action == 'inventory' then
        if not requireAction(src, action) then return end
        if GetResourceState(Config.OpenInventoryResource) == 'started' then
            exports[Config.OpenInventoryResource]:OpenInventoryById(src, targetPlayer.PlayerData.source)
            actionLog('inventory', 'Abriu inventário do jogador.', { target = targetPlayer.PlayerData.source })
        else
            notify(src, 'qb-inventory não está iniciado.', 'error')
        end

    elseif action == 'cloth' then
        if not requireAction(src, 'clothing') then return end
        TriggerClientEvent(Config.ClothingEvent, targetPlayer.PlayerData.source)
        notify(src, 'Menu de roupa aberto no player.', 'success')
        actionLog('admin_action', 'Abriu menu de roupa do jogador.', { target = targetPlayer.PlayerData.source })

    elseif action == 'giveWeapon' then
        if not requireAction(src, action) then return end
        local weaponName = tostring(payload.weapon or ''):upper()
        local ammo = tonumber(payload.ammo or 250) or 250
        if weaponName == '' then return notify(src, 'Arma inválida.', 'error') end
        TriggerClientEvent('mz_staffpanel:client:giveWeapon', targetPlayer and targetPlayer.PlayerData.source or src, weaponName, ammo)
        notify(src, ('Arma enviada: %s'):format(weaponName), 'success')
        actionLog('weapon', 'Enviou arma.', { target = targetPlayer and targetPlayer.PlayerData.source or src, weapon = weaponName, ammo = ammo })

    elseif action == 'setmodel' then
        if not requireAction(src, action) then return end
        local model = tostring(payload.model or '')
        if model == '' then return notify(src, 'Modelo inválido.', 'error') end
        TriggerClientEvent('mz_staffpanel:client:setModel', targetPlayer and targetPlayer.PlayerData.source or src, model)
        actionLog('dev', 'Alterou model.', { target = targetPlayer and targetPlayer.PlayerData.source or src, model = model })

    elseif action == 'setspeed' then
        if not requireAction(src, action) then return end
        local speed = tostring(payload.speed or 'normal')
        TriggerClientEvent('mz_staffpanel:client:setSpeed', targetPlayer and targetPlayer.PlayerData.source or src, speed)
        actionLog('dev', 'Alterou velocidade.', { target = targetPlayer and targetPlayer.PlayerData.source or src, speed = speed })

    elseif action == 'setammo' then
        if not requireAction(src, action) then return end
        local amount = tonumber(payload.amount or 0)
        if not amount then return notify(src, 'Quantidade inválida.', 'error') end
        TriggerClientEvent('mz_staffpanel:client:setAmmo', targetPlayer and targetPlayer.PlayerData.source or src, amount)
        actionLog('weapon', 'Setou munição.', { target = targetPlayer and targetPlayer.PlayerData.source or src, amount = amount })

    elseif action == 'givenuifocus' then
        if not requireAction(src, action) then return end
        TriggerClientEvent('mz_staffpanel:client:giveNuiFocus', targetPlayer and targetPlayer.PlayerData.source or src, payload.focus == true, payload.mouse == true)
        actionLog('dev', 'Alterou NUI focus.', { target = targetPlayer and targetPlayer.PlayerData.source or src, focus = payload.focus == true, mouse = payload.mouse == true })
    end
end

RegisterNetEvent('mz_staffpanel:server:performAction', function(payload)
    handleAction(source, payload)
end)

RegisterNetEvent('mz_staffpanel:server:spectateTick', function()
    local adminSrc = source
    local st = adminSpectateState[adminSrc]
    if not st or not st.active then return end
    local targetSrc = st.target
    if not isOnline(adminSrc) or not isOnline(targetSrc) then return stopSpectate(adminSrc, false) end
    local tPed = GetPlayerPed(targetSrc)
    if not tPed or tPed == 0 then return stopSpectate(adminSrc, false) end
    local c = GetEntityCoords(tPed)
    local h = GetEntityHeading(tPed)
    local bucket = GetPlayerRoutingBucket(targetSrc) or 0
    TriggerClientEvent('mz_staffpanel:client:syncSpectateTarget', adminSrc, {
        src = targetSrc,
        coords = { x = c.x, y = c.y, z = c.z },
        heading = h or 0.0,
        bucket = bucket
    })
end)

RegisterNetEvent('mz_staffpanel:server:setSpectateBucket', function(bucket)
    local adminSrc = source
    local st = adminSpectateState[adminSrc]
    if not st or not st.active then return end
    bucket = tonumber(bucket or 0) or 0
    if bucket < 0 then bucket = 0 end
    SetPlayerRoutingBucket(adminSrc, bucket)
end)

RegisterNetEvent('mz_staffpanel:server:setWallState', function(state)
    local src = source
    if not requireAction(src, 'wall') then return end
    wallWatchers[src] = state == true
    addLog('admin_action', 'wall_state', src, nil, wallWatchers[src] and 'Ativou wall.' or 'Desativou wall.', { state = wallWatchers[src] })
    if not wallWatchers[src] then
        TriggerClientEvent('mz_staffpanel:client:updateWall', src, {}, GetPlayerRoutingBucket(src) or 0)
    end
end)

CreateThread(function()
    while true do
        Wait((Config.Wall and Config.Wall.UpdateInterval) or 150)

        local hasWatcher = false
        for src, enabled in pairs(wallWatchers) do
            if enabled and isOnline(src) then
                hasWatcher = true
                break
            end
        end

        if hasWatcher then
            local snapshot = {}
            for _, pid in ipairs(GetPlayers()) do
                local targetSrc = tonumber(pid)
                if targetSrc then
                    local ped = GetPlayerPed(targetSrc)
                    if ped and ped ~= 0 then
                        local coords = GetEntityCoords(ped)
                        local Player = QBCore.Functions.GetPlayer(targetSrc)
                        local metaPerms = Player and Player.PlayerData.metadata and Player.PlayerData.metadata.perms or {}
                        local isStaff = hasQBBypass(targetSrc)
                        if not isStaff then
                            for _, enabled in pairs(metaPerms.staff or {}) do
                                if enabled then
                                    isStaff = true
                                    break
                                end
                            end
                        end

                        snapshot[#snapshot + 1] = {
                            id = targetSrc,
                            name = Player and getPlayerNameSafe(Player) or (GetPlayerName(targetSrc) or ('ID ' .. tostring(targetSrc))),
                            x = coords.x,
                            y = coords.y,
                            z = coords.z,
                            bucket = GetPlayerRoutingBucket(targetSrc) or 0,
                            staff = isStaff == true
                        }
                    end
                end
            end

            for src, enabled in pairs(wallWatchers) do
                if enabled and isOnline(src) then
                    TriggerClientEvent('mz_staffpanel:client:updateWall', src, snapshot, GetPlayerRoutingBucket(src) or 0)
                else
                    wallWatchers[src] = nil
                end
            end
        end
    end
end)

AddEventHandler('mz_staffpanel:server:reportProxy', function(src, msg)
    if not src then return end
    msg = tostring(msg or '')
    if msg == '' then return end
    local Player = QBCore.Functions.GetPlayer(src)
    local reportId = createReport(src, msg, 'proxy')
    addReportMessage(reportId, 'system', 0, 'Seu chamado foi criado. Aguarde um administrador assumir o atendimento.', { action = 'created' })
    notify(src, ('Seu chamado foi enviado para a staff. Protocolo #%d.'):format(reportId), 'success')
    if Player then
        print(('[mz_staffpanel] report %s (%s): %s'):format(GetPlayerName(src), Player.PlayerData.citizenid or '-', msg))
    end
end)

RegisterNetEvent('mz_staffpanel:server:sendReport', function(msg)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    msg = tostring(msg or '')
    if msg == '' then return end
    local reportId = createReport(src, msg, 'event')
    addReportMessage(reportId, 'system', 0, 'Seu chamado foi criado. Aguarde um administrador assumir o atendimento.', { action = 'created' })
    notify(src, ('Seu chamado foi enviado para a staff. Protocolo #%d.'):format(reportId), 'success')
    if Player then
        print(('[mz_staffpanel] report %s (%s): %s'):format(GetPlayerName(src), Player.PlayerData.citizenid or '-', msg))
    end
end)

RegisterNetEvent('mz_staffpanel:server:supportSend', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}
    local reportId = tonumber(payload.reportId or 0) or 0
    local msg = tostring(payload.message or '')
    if msg == '' then return end

    local isAdmin = canOpen(src)
    if reportId <= 0 then
        if isAdmin then return end
        reportId = createReport(src, msg, 'support_ui')
        addReportMessage(reportId, 'system', 0, 'Seu chamado foi criado. Aguarde um administrador assumir o atendimento.', { action = 'created' })
        TriggerClientEvent('QBCore:Notify', src, ('Chamado #%d criado.'):format(reportId), 'success')
    else
        local reportRow = getReportById(reportId)
        if not reportRow or not canAccessReport(src, reportRow) then
            return notify(src, 'Atendimento não encontrado.', 'error')
        end

        if isAdmin then
            if tostring(reportRow.status or '') ~= 'em_atendimento' then
                MySQL.update.await(('UPDATE `%s` SET status = ?, accepted_by_src = ?, accepted_by_name = ?, accepted_at = IFNULL(accepted_at, NOW()) WHERE id = ?'):format(Config.ReportTable or 'staff_reports'), { 'em_atendimento', src, GetPlayerName(src) or ('ID ' .. tostring(src)), reportId })
            end
            MySQL.update.await(('UPDATE `%s` SET response = ?, status = ?, accepted_by_src = ?, accepted_by_name = ?, accepted_at = IFNULL(accepted_at, NOW()) WHERE id = ?'):format(Config.ReportTable or 'staff_reports'), { msg, 'em_atendimento', src, GetPlayerName(src) or ('ID ' .. tostring(src)), reportId })
            addReportMessage(reportId, 'admin', src, msg, { action = 'reply' })
        else
            addReportMessage(reportId, 'player', src, msg, { action = 'reply' })
        end
    end
end)

RegisterNetEvent('mz_staffpanel:server:supportClose', function(payload)
    local src = source
    if not requireAction(src, 'staffchat') then return end
    payload = type(payload) == 'table' and payload or {}
    local reportId = tonumber(payload.reportId or 0) or 0
    if reportId <= 0 then return notify(src, 'Atendimento inválido.', 'error') end
    local status = tostring(payload.status or 'resolvido')
    local note = tostring(payload.note or '')
    MySQL.update.await(("UPDATE `%s` SET status = ?, closed_by_src = ?, closed_by_name = ?, closed_at = NOW(), response = CASE WHEN ? = '' THEN response ELSE ? END WHERE id = ?"):format(Config.ReportTable or 'staff_reports'), { status, src, GetPlayerName(src) or ('ID ' .. tostring(src)), note, note, reportId })
    if note ~= '' then
        addReportMessage(reportId, 'admin', src, note, { action = 'close_note', status = status })
    end
    addReportMessage(reportId, 'system', 0, ('Atendimento finalizado com status: %s.'):format(status), { action = 'close', status = status, note = note })
    notify(src, ('Atendimento #%d finalizado.'):format(reportId), 'success')
end)

RegisterNetEvent('mz_staffpanel:server:addCustomLog', function(category, action, message, targetSrc, metadata)
    addLog(category or 'custom', action or 'event', source or 0, tonumber(targetSrc) or nil, message or '', metadata or {})
end)

RegisterNetEvent('mz_staffpanel:server:saveVehicleData', function(props, plate)
    local src = source
    if not requireAction(src, 'saveVehicle') then return end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or type(props) ~= 'table' then
        return notify(src, 'Dados do veículo inválidos.', 'error')
    end

    local inputPlate = tostring(plate or props.plate or ''):gsub('^%s+', ''):gsub('%s+$', ''):upper()
    if inputPlate == '' then
        return notify(src, 'Placa inválida.', 'error')
    end

    local modelName, vehicleData = nil, nil
    if props.model then
        modelName, vehicleData = getVehicleModelByHash(props.model)
    end

    if not vehicleData then
        local fallbackName = tostring(props.modelName or props.vehicle or props.spawn or ''):lower()
        if fallbackName ~= '' then
            vehicleData = QBCore.Shared.Vehicles[fallbackName]
            modelName = fallbackName
        end
    end

    if not vehicleData then
        return notify(src, 'Não encontrei esse veículo na shared.', 'error')
    end

    local vehiclesTable = Config.PlayerVehiclesTable or 'player_vehicles'
    local existing = MySQL.single.await(('SELECT plate, citizenid FROM `%s` WHERE plate = ? LIMIT 1'):format(vehiclesTable), { inputPlate })
    if existing then
        if tostring(existing.citizenid or '') == tostring(Player.PlayerData.citizenid or '') then
            return notify(src, ('Já existe um veículo salvo com a placa %s para esse player.'):format(inputPlate), 'error')
        else
            return notify(src, ('A placa %s já pertence a outro registro.'):format(inputPlate), 'error')
        end
    end

    local garage = tostring(Config.DefaultGarage or 'pillboxgarage')
    local hash = tonumber(vehicleData.hash or props.model or 0) or 0
    local record = {
        Player.PlayerData.license,
        Player.PlayerData.citizenid,
        tostring(vehicleData.model or modelName or ''),
        hash,
        json.encode(props),
        inputPlate,
        garage,
        0
    }

    local ok, err = pcall(function()
        MySQL.insert.await(('INSERT INTO `%s` (license, citizenid, vehicle, hash, mods, plate, garage, state) VALUES (?, ?, ?, ?, ?, ?, ?, ?)'):format(vehiclesTable), record)
    end)

    if ok then
        notify(src, ('Veículo %s salvo na garagem.'):format(tostring(vehicleData.model or modelName or 'desconhecido')), 'success')
        addLog('vehicle', 'save_vehicle', src, nil, 'Salvou veículo na garagem.', { model = tostring(vehicleData.model or modelName or 'desconhecido'), plate = inputPlate })
    else
        notify(src, 'Falha ao salvar veículo. Verifique a tabela player_vehicles.', 'error')
        print('^1[mz_staffpanel] save vehicle error:^7', err)
    end
end)

AddEventHandler('playerConnecting', function(playerName, setKickReason, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)

    local now = os.time()
    local license = getIdentifierSafe(src, 'license')
    local discord = getIdentifierSafe(src, 'discord')
    local ip = getIdentifierSafe(src, 'ip')

    local clauses, params = {}, {}
    if license then clauses[#clauses + 1] = 'license = ?'; params[#params + 1] = license end
    if discord then clauses[#clauses + 1] = 'discord = ?'; params[#params + 1] = discord end
    if ip then clauses[#clauses + 1] = 'ip = ?'; params[#params + 1] = ip end

    if #clauses == 0 then
        deferrals.done()
        return
    end

    local query = ('SELECT * FROM `%s` WHERE (%s) ORDER BY id DESC LIMIT 1'):format(Config.BanTable, table.concat(clauses, ' OR '))
    local ban = MySQL.single.await(query, params)
    if not ban then
        deferrals.done()
        return
    end

    local expire = tonumber(ban.expire or 0) or 0
    if expire > 0 and expire < 2147483647 and expire <= now then
        MySQL.query.await(('DELETE FROM `%s` WHERE id = ?'):format(Config.BanTable), { ban.id })
        deferrals.done()
        return
    end

    local reason = tostring(ban.reason or 'Banido')
    if expire >= 2147483647 then
        addLog('ban', 'block_connect', 0, src, reason, { permanent = true, banId = ban.id })
        deferrals.done(('Você está banido permanentemente.\nMotivo: %s'):format(reason))
    else
        local t = os.date('*t', expire)
        addLog('ban', 'block_connect', 0, src, reason, { permanent = false, banId = ban.id, expire = expire })
        deferrals.done(('Você está banido.\nMotivo: %s\nExpira em: %02d/%02d/%04d %02d:%02d'):format(reason, t.day, t.month, t.year, t.hour, t.min))
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    frozenPlayers[src] = nil
    wallWatchers[src] = nil
    if adminSpectateState[src] then adminSpectateState[src] = nil end
    for adminSrc, st in pairs(adminSpectateState) do
        if st and st.target == src then stopSpectate(adminSrc, true) end
    end
end)

MZ_STAFFPANEL.Notify = notify
MZ_STAFFPANEL.CanOpen = canOpen
MZ_STAFFPANEL.HasLevel = hasLevel
MZ_STAFFPANEL.RequireAction = requireAction
MZ_STAFFPANEL.HandleAction = handleAction
MZ_STAFFPANEL.GetTarget = getTarget
MZ_STAFFPANEL.CheckWarns = checkWarns
MZ_STAFFPANEL.DeleteWarn = deleteWarn
MZ_STAFFPANEL.AddLog = addLog
MZ_STAFFPANEL.CreateReport = createReport
MZ_STAFFPANEL.GetReportById = getReportById
MZ_STAFFPANEL.GetReportMessages = getReportMessages
MZ_STAFFPANEL.AddReportMessage = addReportMessage
MZ_STAFFPANEL.RegisterQbCommand = function(commandName, help, arguments, argsrequired, handler, permission)
    if not commandName or commandName == '' then return end
    QBCore.Commands.Add(commandName, help, arguments or {}, argsrequired == true, function(source, args, rawCommand)
        addLog('command', commandName, source, nil, rawCommand or commandName, { args = args or {} })
        handler(source, args, rawCommand)
    end, permission or Config.MenuAccess)
end
