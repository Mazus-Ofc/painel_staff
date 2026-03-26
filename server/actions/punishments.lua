local P = MZ_STAFFPANEL
local QBCore = P.QBCore

function P.BanPlayerByAdmin(src, targetSrc, seconds, reason)
    local expiresAt = 2147483647

    if tonumber(seconds) and tonumber(seconds) > 0 then
        expiresAt = tonumber(os.time() + tonumber(seconds))
        if expiresAt > 2147483647 then
            expiresAt = 2147483647
        end
    end

    local name = GetPlayerName(targetSrc) or ('ID ' .. tostring(targetSrc))
    local license = P.GetIdentifierSafe(targetSrc, 'license')
    local discord = P.GetIdentifierSafe(targetSrc, 'discord')
    local ip = P.GetIdentifierSafe(targetSrc, 'ip')
    local bannedBy = GetPlayerName(src) or ('ID ' .. tostring(src))

    if not license and not discord and not ip then
        error('Nenhum identificador válido encontrado para o alvo do ban.')
    end

    MySQL.insert.await(
        ('INSERT INTO `%s` (name, license, discord, ip, reason, expire, bannedby, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?)'):format(Config.BanTable),
        { name, license, discord, ip, reason, expiresAt, bannedBy, 'active' }
    )

    TriggerClientEvent('chat:addMessage', -1, {
        template = "\nADMIN | {0} foi banido: {1}\n",
        args = { name, reason }
    })

    if expiresAt >= 2147483647 then
        DropPlayer(targetSrc, ('Você foi banido permanentemente.\nMotivo: %s'):format(reason))
    else
        local t = os.date('*t', expiresAt)
        DropPlayer(targetSrc, ('Você foi banido.\nMotivo: %s\nExpira em: %02d/%02d/%04d %02d:%02d'):format(reason, t.day, t.month, t.year, t.hour, t.min))
    end
end

function P.UnbanBanRecordByAdmin(src, banId, reason)
    banId = tonumber(banId or 0)
    if not banId or banId <= 0 then
        return false, 'ID do ban inválido.'
    end

    local ban = MySQL.single.await(('SELECT * FROM `%s` WHERE id = ? LIMIT 1'):format(Config.BanTable), { banId })
    if not ban then
        return false, 'Ban não encontrado.'
    end

    local status = tostring(ban.status or 'active')
    if status == 'removed' then
        return false, 'Esse ban já foi removido.'
    end

    local removerName = GetPlayerName(src) or ('ID ' .. tostring(src))
    local removeReason = tostring(reason or '')
    if removeReason == '' then
        removeReason = 'Removido pela staff'
    end

    local affected = MySQL.update.await(
        ('UPDATE `%s` SET status = ?, removed_at = CURRENT_TIMESTAMP, removed_by = ?, remove_reason = ? WHERE id = ?'):format(Config.BanTable),
        { 'removed', removerName, removeReason, banId }
    )

    if not affected or affected < 1 then
        return false, 'Falha ao remover ban.'
    end

    return true, {
        id = banId,
        name = tostring(ban.name or '-'),
        previousStatus = status,
        removedBy = removerName,
        removeReason = removeReason
    }
end

function P.AddWarn(src, targetSrc, reason)
    local sender = QBCore.Functions.GetPlayer(src)
    local target = QBCore.Functions.GetPlayer(targetSrc)

    if not sender or not target then
        return false, 'Jogador offline.'
    end

    local senderIdentifier = sender.PlayerData.license or P.GetIdentifierSafe(src, 'license')
    local targetIdentifier = target.PlayerData.license or P.GetIdentifierSafe(targetSrc, 'license')

    if not senderIdentifier or not targetIdentifier then
        return false, 'Licença não encontrada.'
    end

    local warnId = ('WARN-%d-%d'):format(os.time(), math.random(1111, 999999))
    local inserted = MySQL.insert.await(
        ('INSERT INTO `%s` (senderIdentifier, targetIdentifier, reason, warnId) VALUES (?, ?, ?, ?)'):format(Config.WarnTable),
        { senderIdentifier, targetIdentifier, tostring(reason or ''), warnId }
    )

    if not inserted then
        return false, 'Falha ao registrar warn.'
    end

    return true, warnId
end

function P.CheckWarns(targetSrc)
    local target = QBCore.Functions.GetPlayer(targetSrc)
    if not target then return nil end

    local targetIdentifier = target.PlayerData.license or P.GetIdentifierSafe(targetSrc, 'license')
    if not targetIdentifier then return nil end

    return MySQL.query.await(
        ('SELECT * FROM `%s` WHERE targetIdentifier = ? ORDER BY id DESC'):format(Config.WarnTable),
        { targetIdentifier }
    ) or {}
end

function P.DeleteWarn(targetSrc, index)
    local warns = P.CheckWarns(targetSrc) or {}
    local selected = warns[tonumber(index or 0)]

    if not selected then
        return false, 'Warn não encontrado.'
    end

    MySQL.query.await(('DELETE FROM `%s` WHERE warnId = ?'):format(Config.WarnTable), { selected.warnId })
    return true, selected
end

function P.GetWarnHistoryByLicense(license)
    license = tostring(license or '')
    if license == '' or license == '-' then
        return {}
    end

    return MySQL.query.await(
        ('SELECT * FROM `%s` WHERE targetIdentifier = ? ORDER BY id DESC'):format(Config.WarnTable),
        { license }
    ) or {}
end

local function syncExpiredBans()
    local now = os.time()

    pcall(function()
        MySQL.update.await(
            ("UPDATE `%s` SET status = ?, expired_at = COALESCE(expired_at, CURRENT_TIMESTAMP) WHERE (status IS NULL OR status = '' OR status = ?) AND expire > 0 AND expire < 2147483647 AND expire <= ?"):format(Config.BanTable),
            { 'expired', 'active', now }
        )
    end)
end

function P.FetchBansPage(page, pageSize, filters)
    syncExpiredBans()

    page = math.max(1, tonumber(page or 1) or 1)
    pageSize = math.max(1, math.min(100, tonumber(pageSize or 15) or 15))
    filters = type(filters) == 'table' and filters or {}

    local clauses = { '1=1' }
    local params = {}

    local function addLike(column, value)
        value = tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
        if value ~= '' then
            clauses[#clauses + 1] = ('LOWER(%s) LIKE ?'):format(column)
            params[#params + 1] = '%%' .. value:lower() .. '%%'
        end
    end

    addLike('name', filters.name)
    addLike('reason', filters.reason)
    addLike('bannedby', filters.bannedby)

    local status = tostring(filters.status or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if status ~= '' and status ~= 'all' then
        clauses[#clauses + 1] = 'status = ?'
        params[#params + 1] = status
    end

    local whereSql = table.concat(clauses, ' AND ')
    local total = MySQL.scalar.await(('SELECT COUNT(*) FROM `%s` WHERE %s'):format(Config.BanTable, whereSql), params) or 0
    local offset = (page - 1) * pageSize

    local queryParams = {}
    for i = 1, #params do
        queryParams[i] = params[i]
    end
    queryParams[#queryParams + 1] = pageSize
    queryParams[#queryParams + 1] = offset

    local rows = MySQL.query.await(
        ('SELECT * FROM `%s` WHERE %s ORDER BY id DESC LIMIT ? OFFSET ?'):format(Config.BanTable, whereSql),
        queryParams
    ) or {}

    return {
        rows = rows,
        total = tonumber(total) or 0,
        page = page,
        pageSize = pageSize,
        totalPages = math.max(1, math.ceil((tonumber(total) or 0) / pageSize)),
        filters = {
            status = status,
            name = tostring(filters.name or ''),
            reason = tostring(filters.reason or ''),
            bannedby = tostring(filters.bannedby or '')
        }
    }
end

local function addDailyStat(src, field, amount)
    local adminLicense = (P.GetStaffLicense and P.GetStaffLicense(src)) or P.GetIdentifierSafe(src, 'license') or '-'
    local adminName = GetPlayerName(src) or ('ID ' .. tostring(src))
    P.AddDailyStat(adminLicense, adminName, field, amount or 1)
end

P.RegisterAction('kick', {
    requiredTarget = true,
    targetProtected = true,
}, function(ctx)
    local reason = tostring(ctx.payload.reason or 'Removido pela staff')

    QBCore.Functions.Kick(ctx.targetSrc, reason, nil, nil)

    P.Notify(ctx.src, ('Você kickou ID %s.'):format(ctx.targetSrc), 'success')
    ctx.log('admin_action', reason, { target = ctx.targetSrc })
end)

P.RegisterAction('kickall', {
    resolveTarget = false,
}, function(ctx)
    local reason = tostring(ctx.payload.reason or 'Servidor reiniciando')

    for _, pid in ipairs(GetPlayers()) do
        DropPlayer(pid, reason)
    end

    ctx.log('admin_action', reason, { scope = 'all' })
end)

P.RegisterAction('ban', {
    requiredTarget = true,
    targetProtected = true,
}, function(ctx)
    local seconds = tonumber(ctx.payload.seconds or Config.DefaultBanSeconds) or Config.DefaultBanSeconds
    local reason = tostring(ctx.payload.reason or 'Banido pela staff')

    local ok, err = pcall(P.BanPlayerByAdmin, ctx.src, ctx.targetSrc, seconds, reason)
    if ok then
        P.Notify(ctx.src, ('Você baniu ID %s.'):format(ctx.targetSrc), 'success')
        ctx.log('ban', reason, {
            target = ctx.targetSrc,
            seconds = seconds
        })

        addDailyStat(ctx.src, 'bans_applied', 1)
        return
    end

    P.Notify(ctx.src, 'Falha ao banir. Verifique a tabela bans.', 'error')
    print('^1[mz_staffpanel] ban error:^7', err)
end)

P.RegisterAction('unban', {
    resolveTarget = false,
}, function(ctx)
    local banId = tonumber(ctx.payload.banId or ctx.payload.id or 0)
    local reason = tostring(ctx.payload.reason or 'Removido pela staff')

    local ok, dataOrError = P.UnbanBanRecordByAdmin(ctx.src, banId, reason)
    if ok then
        P.Notify(ctx.src, ('Ban #%s removido com sucesso.'):format(tostring(dataOrError.id or banId)), 'success')
        P.AddLog('ban', 'unban', ctx.src, nil, ('Removeu o ban #%s'):format(tostring(dataOrError.id or banId)), {
            banId = dataOrError.id or banId,
            targetName = dataOrError.name or '-',
            previousStatus = dataOrError.previousStatus or 'active',
            reason = dataOrError.removeReason or reason
        })
        return
    end

    P.Notify(ctx.src, dataOrError or 'Falha ao remover ban.', 'error')
end)

P.RegisterAction('warn', {
    requiredTarget = true,
    targetProtected = true,
}, function(ctx)
    local reason = tostring(ctx.payload.reason or 'Aviso da staff')
    local ok, warnIdOrError = P.AddWarn(ctx.src, ctx.targetSrc, reason)

    if ok then
        TriggerClientEvent('chat:addMessage', ctx.targetSrc, {
            args = {
                'SYSTEM',
                ('Você recebeu um warn de %s. Motivo: %s'):format(GetPlayerName(ctx.src), reason)
            },
            color = { 255, 0, 0 }
        })

        P.Notify(ctx.src, ('Warn aplicado: %s'):format(warnIdOrError), 'success')
        ctx.log('warn', reason, {
            target = ctx.targetSrc,
            warnId = warnIdOrError
        })

        addDailyStat(ctx.src, 'warns_applied', 1)
        return
    end

    P.Notify(ctx.src, warnIdOrError or 'Falha ao aplicar warn. Verifique a tabela player_warns.', 'error')
    print('^1[mz_staffpanel] warn error:^7', warnIdOrError)
end)