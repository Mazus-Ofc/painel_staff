local P = MZ_STAFFPANEL
local QBCore = P.QBCore

function P.GetPedCoordsHeading(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil, nil end
    local c = GetEntityCoords(ped)
    local h = GetEntityHeading(ped)
    return { x = c.x, y = c.y, z = c.z }, h
end

function P.StopSpectate(src, silent)
    local st = P.State.adminSpectateState[src]
    if not st then return end

    P.State.adminSpectateState[src] = nil

    if st.returnBucket ~= nil then
        SetPlayerRoutingBucket(src, tonumber(st.returnBucket) or 0)
    end

    TriggerClientEvent('mz_staffpanel:client:stopSpectate', src, st.returnCoords, st.returnHeading, silent == true)
end

function P.BroadcastToAdmins(messageArgs, color)
    local players = GetPlayers()
    for _, pid in ipairs(players) do
        pid = tonumber(pid)
        if pid and (P.HasQBBypass(pid) or P.CanOpen(pid)) then
            if not QBCore.Functions.IsOptin or QBCore.Functions.IsOptin(pid) then
                TriggerClientEvent('chat:addMessage', pid, { color = color or {255, 0, 0}, multiline = true, args = messageArgs })
            end
        end
    end
end

function P.GetVehicleModelByHash(hash)
    for spawn, v in pairs(QBCore.Shared.Vehicles or {}) do
        if tonumber(v.hash) == tonumber(hash) then
            return tostring(v.model or spawn or ''):lower(), v
        end
    end
    return nil, nil
end

function P.BanPlayerByAdmin(src, targetSrc, seconds, reason)
    local expiresAt = 2147483647
    if tonumber(seconds) and tonumber(seconds) > 0 then
        expiresAt = tonumber(os.time() + tonumber(seconds))
        if expiresAt > 2147483647 then expiresAt = 2147483647 end
    end

    local name = GetPlayerName(targetSrc) or ('ID ' .. tostring(targetSrc))
    local license = P.GetIdentifierSafe(targetSrc, 'license')
    local discord = P.GetIdentifierSafe(targetSrc, 'discord')
    local ip = P.GetIdentifierSafe(targetSrc, 'ip')
    local bannedBy = GetPlayerName(src) or ('ID ' .. tostring(src))

    if not license and not discord and not ip then
        error('Nenhum identificador válido encontrado para o alvo do ban.')
    end

    MySQL.insert.await(('INSERT INTO `%s` (name, license, discord, ip, reason, expire, bannedby, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?)'):format(Config.BanTable), {
        name, license, discord, ip, reason, expiresAt, bannedBy, 'active'
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

    local affected = MySQL.update.await(('UPDATE `%s` SET status = ?, removed_at = CURRENT_TIMESTAMP, removed_by = ?, remove_reason = ? WHERE id = ?'):format(Config.BanTable), {
        'removed', removerName, removeReason, banId
    })

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
    if not sender or not target then return false, 'Jogador offline.' end

    local senderIdentifier = sender.PlayerData.license or P.GetIdentifierSafe(src, 'license')
    local targetIdentifier = target.PlayerData.license or P.GetIdentifierSafe(targetSrc, 'license')
    if not senderIdentifier or not targetIdentifier then
        return false, 'Licença não encontrada.'
    end

    local warnId = ('WARN-%d-%d'):format(os.time(), math.random(1111, 999999))
    local inserted = MySQL.insert.await(('INSERT INTO `%s` (senderIdentifier, targetIdentifier, reason, warnId) VALUES (?, ?, ?, ?)'):format(Config.WarnTable), {
        senderIdentifier, targetIdentifier, tostring(reason or ''), warnId
    })

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
    return MySQL.query.await(('SELECT * FROM `%s` WHERE targetIdentifier = ? ORDER BY id DESC'):format(Config.WarnTable), { targetIdentifier }) or {}
end

function P.DeleteWarn(targetSrc, index)
    local warns = P.CheckWarns(targetSrc) or {}
    local selected = warns[tonumber(index or 0)]
    if not selected then return false, 'Warn não encontrado.' end
    MySQL.query.await(('DELETE FROM `%s` WHERE warnId = ?'):format(Config.WarnTable), { selected.warnId })
    return true, selected
end

function P.GetWarnHistoryByLicense(license)
    license = tostring(license or '')
    if license == '' or license == '-' then return {} end

    return MySQL.query.await(('SELECT * FROM `%s` WHERE targetIdentifier = ? ORDER BY id DESC'):format(Config.WarnTable), {
        license
    }) or {}
end



local function syncExpiredBans()
    local now = os.time()
    pcall(function()
        MySQL.update.await(("UPDATE `%s` SET status = ?, expired_at = COALESCE(expired_at, CURRENT_TIMESTAMP) WHERE (status IS NULL OR status = '' OR status = ?) AND expire > 0 AND expire < 2147483647 AND expire <= ?"):format(Config.BanTable), {
            'expired', 'active', now
        })
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
    for i = 1, #params do queryParams[i] = params[i] end
    queryParams[#queryParams + 1] = pageSize
    queryParams[#queryParams + 1] = offset

    local rows = MySQL.query.await(('SELECT * FROM `%s` WHERE %s ORDER BY id DESC LIMIT ? OFFSET ?'):format(Config.BanTable, whereSql), queryParams) or {}

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

function P.HandleAction(src, payload)
    if type(payload) ~= 'table' or not P.CanOpen(src) then return end

    local action = payload.action
    local actionsWithoutTarget = { unban = true, kickall = true, spectateStop = true }
    local targetPlayer = nil
    if payload.target and not actionsWithoutTarget[action] then
        targetPlayer = P.GetTarget(src, payload.target)
        if not targetPlayer then return end
    end

    local function actionLog(category, message, metadata)
        P.AddLog(category or 'action', tostring(action or 'unknown'), src, targetPlayer and targetPlayer.PlayerData.source or nil, message, metadata or payload)
    end

    if action == 'revive' then
        if not P.RequireAction(src, action) then return end
        TriggerClientEvent('hospital:client:Revive', targetPlayer.PlayerData.source)
        TriggerClientEvent('qb-ambulancejob:client:revive', targetPlayer.PlayerData.source)
        P.Notify(src, ('Você reviveu ID %s.'):format(targetPlayer.PlayerData.source), 'success')
        actionLog('admin_action', 'Reviveu jogador.', { target = targetPlayer.PlayerData.source })
        local adminLicense = P.GetStaffLicense and P.GetStaffLicense(src) or P.GetIdentifierSafe(src, 'license') or '-'
        local adminName = GetPlayerName(src) or ('ID ' .. tostring(src))
        P.AddDailyStat(adminLicense, adminName, 'revives_done', 1)

    elseif action == 'heal' then
        if not P.RequireAction(src, action) then return end
        TriggerClientEvent('mz_staffpanel:client:healPlayer', targetPlayer and targetPlayer.PlayerData.source or src)
        P.Notify(src, 'Heal aplicado.', 'success')
        actionLog('admin_action', 'Aplicou heal.', { target = targetPlayer and targetPlayer.PlayerData.source or src })

    elseif action == 'kill' then
        if not P.RequireAction(src, action) then return end
        TriggerClientEvent('mz_staffpanel:client:killPlayer', targetPlayer.PlayerData.source)
        P.Notify(src, ('Você matou ID %s.'):format(targetPlayer.PlayerData.source), 'success')
        actionLog('admin_action', 'Matou jogador.', { target = targetPlayer.PlayerData.source })

    elseif action == 'freeze' then
        if not P.RequireAction(src, action) then return end
        local state = not P.State.frozenPlayers[targetPlayer.PlayerData.source]
        P.State.frozenPlayers[targetPlayer.PlayerData.source] = state
        TriggerClientEvent('mz_staffpanel:client:setFrozen', targetPlayer.PlayerData.source, state)
        P.Notify(src, (state and 'Jogador congelado.' or 'Jogador descongelado.'), 'success')
        actionLog('admin_action', state and 'Congelou jogador.' or 'Descongelou jogador.', { target = targetPlayer.PlayerData.source, state = state })

    elseif action == 'gotoPlayer' then
        if not P.RequireAction(src, action) then return end
        local ped = GetPlayerPed(targetPlayer.PlayerData.source)
        if ped == 0 then return P.Notify(src, 'Ped do jogador não encontrado.', 'error') end
        local coords = GetEntityCoords(ped)
        TriggerClientEvent('mz_staffpanel:client:teleportToCoords', src, { x = coords.x, y = coords.y, z = coords.z + 1.0 })
        P.Notify(src, ('Teleportado até ID %s.'):format(targetPlayer.PlayerData.source), 'success')
        actionLog('admin_action', 'Teleportou até jogador.', { target = targetPlayer.PlayerData.source })
        local adminLicense = P.GetStaffLicense and P.GetStaffLicense(src) or P.GetIdentifierSafe(src, 'license') or '-'
        local adminName = GetPlayerName(src) or ('ID ' .. tostring(src))
        P.AddDailyStat(adminLicense, adminName, 'teleports_done', 1)

    elseif action == 'bringPlayer' then
        if not P.RequireAction(src, action) then return end
        local ped = GetPlayerPed(src)
        if ped == 0 then return P.Notify(src, 'Seu ped não foi encontrado.', 'error') end
        local coords = GetEntityCoords(ped)
        TriggerClientEvent('mz_staffpanel:client:teleportToCoords', targetPlayer.PlayerData.source, { x = coords.x, y = coords.y, z = coords.z + 1.0 })
        P.Notify(src, ('Você trouxe ID %s.'):format(targetPlayer.PlayerData.source), 'success')
        actionLog('admin_action', 'Trouxe jogador.', { target = targetPlayer.PlayerData.source })
        local adminLicense = P.GetStaffLicense and P.GetStaffLicense(src) or P.GetIdentifierSafe(src, 'license') or '-'
        local adminName = GetPlayerName(src) or ('ID ' .. tostring(src))
        P.AddDailyStat(adminLicense, adminName, 'teleports_done', 1)

    elseif action == 'spectate' then
        if not P.RequireAction(src, action) then return end
        local adminSrc = src
        local targetSrc = targetPlayer.PlayerData.source
        if targetSrc == adminSrc then return P.Notify(adminSrc, 'Você não pode espectar você mesmo.', 'error') end
        if P.State.adminSpectateState[adminSrc] and P.State.adminSpectateState[adminSrc].target == targetSrc then
            P.StopSpectate(adminSrc, false)
            return
        end
        if P.State.adminSpectateState[adminSrc] then P.StopSpectate(adminSrc, true) end
        local returnCoords, returnHeading = P.GetPedCoordsHeading(adminSrc)
        if not returnCoords then return P.Notify(adminSrc, 'Não consegui capturar sua posição.', 'error') end
        P.State.adminSpectateState[adminSrc] = {
            active = true,
            target = targetSrc,
            returnCoords = returnCoords,
            returnHeading = returnHeading or 0.0,
            returnBucket = GetPlayerRoutingBucket(adminSrc) or 0
        }
        TriggerClientEvent('mz_staffpanel:client:startSpectate', adminSrc, targetSrc)
        P.Notify(adminSrc, ('Espectando ID %s. Use /%s para sair.'):format(targetSrc, Config.Commands.specoff), 'primary')
        actionLog('admin_action', 'Iniciou spectate.', { target = targetSrc })
        local adminLicense = P.GetStaffLicense and P.GetStaffLicense(src) or P.GetIdentifierSafe(src, 'license') or '-'
        local adminName = GetPlayerName(src) or ('ID ' .. tostring(src))
        P.AddDailyStat(adminLicense, adminName, 'spectates_done', 1)

    elseif action == 'spectateStop' then
        if not P.RequireAction(src, 'spectate') then return end
        P.StopSpectate(src, false)

    elseif action == 'kick' then
        if not P.RequireAction(src, action) then return end
        local reason = tostring(payload.reason or 'Removido pela staff')
        QBCore.Functions.Kick(targetPlayer.PlayerData.source, reason, nil, nil)
        P.Notify(src, ('Você kickou ID %s.'):format(targetPlayer.PlayerData.source), 'success')
        actionLog('admin_action', reason, { target = targetPlayer.PlayerData.source })

    elseif action == 'kickall' then
        if not P.RequireAction(src, action) then return end
        local reason = tostring(payload.reason or 'Servidor reiniciando')
        for _, pid in ipairs(GetPlayers()) do
            DropPlayer(pid, reason)
        end
        actionLog('admin_action', reason, { scope = 'all' })

    elseif action == 'ban' then
        if not P.RequireAction(src, action) then return end
        local seconds = tonumber(payload.seconds or Config.DefaultBanSeconds) or Config.DefaultBanSeconds
        local reason = tostring(payload.reason or 'Banido pela staff')
        local ok, err = pcall(P.BanPlayerByAdmin, src, targetPlayer.PlayerData.source, seconds, reason)
        if ok then
            P.Notify(src, ('Você baniu ID %s.'):format(targetPlayer.PlayerData.source), 'success')
            actionLog('ban', reason, { target = targetPlayer.PlayerData.source, seconds = seconds })
            local adminLicense = P.GetStaffLicense and P.GetStaffLicense(src) or P.GetIdentifierSafe(src, 'license') or '-'
            local adminName = GetPlayerName(src) or ('ID ' .. tostring(src))
            P.AddDailyStat(adminLicense, adminName, 'bans_applied', 1)
        else
            P.Notify(src, 'Falha ao banir. Verifique a tabela bans.', 'error')
            print('^1[mz_staffpanel] ban error:^7', err)
        end

    elseif action == 'unban' then
        if not P.RequireAction(src, action) then return end
        local banId = tonumber(payload.banId or payload.id or 0)
        local reason = tostring(payload.reason or 'Removido pela staff')
        local ok, dataOrError = P.UnbanBanRecordByAdmin(src, banId, reason)
        if ok then
            P.Notify(src, ('Ban #%s removido com sucesso.'):format(tostring(dataOrError.id or banId)), 'success')
            P.AddLog('ban', 'unban', src, nil, ('Removeu o ban #%s'):format(tostring(dataOrError.id or banId)), {
                banId = dataOrError.id or banId,
                targetName = dataOrError.name or '-',
                previousStatus = dataOrError.previousStatus or 'active',
                reason = dataOrError.removeReason or reason
            })
        else
            P.Notify(src, dataOrError or 'Falha ao remover ban.', 'error')
        end

    elseif action == 'warn' then
        if not P.RequireAction(src, action) then return end
        local reason = tostring(payload.reason or 'Aviso da staff')
        local ok, warnIdOrError = P.AddWarn(src, targetPlayer.PlayerData.source, reason)
        if ok then
            TriggerClientEvent('chat:addMessage', targetPlayer.PlayerData.source, { args = { 'SYSTEM', ('Você recebeu um warn de %s. Motivo: %s'):format(GetPlayerName(src), reason) }, color = {255, 0, 0} })
            P.Notify(src, ('Warn aplicado: %s'):format(warnIdOrError), 'success')
            actionLog('warn', reason, { target = targetPlayer.PlayerData.source, warnId = warnIdOrError })
            local adminLicense = P.GetStaffLicense and P.GetStaffLicense(src) or P.GetIdentifierSafe(src, 'license') or '-'
            local adminName = GetPlayerName(src) or ('ID ' .. tostring(src))
            P.AddDailyStat(adminLicense, adminName, 'warns_applied', 1)
        else
            P.Notify(src, warnIdOrError or 'Falha ao aplicar warn. Verifique a tabela player_warns.', 'error')
            print('^1[mz_staffpanel] warn error:^7', warnIdOrError)
        end

    elseif action == 'noclip' then
        if not P.RequireAction(src, action) then return end
        TriggerClientEvent('mz_staffpanel:client:toggleNoClip', src)
        actionLog('admin_action', 'Alternou noclip.', {})

    elseif action == 'invisible' then
        if not P.RequireAction(src, action) then return end
        TriggerClientEvent('mz_staffpanel:client:toggleInvisible', src)
        actionLog('admin_action', 'Alternou invisibilidade.', {})

    elseif action == 'god' then
        if not P.RequireAction(src, action) then return end
        TriggerClientEvent('mz_staffpanel:client:toggleGod', src)
        actionLog('admin_action', 'Alternou godmode.', {})

    elseif action == 'names' then
        if not P.RequireAction(src, action) then return end
        TriggerClientEvent('mz_staffpanel:client:toggleNames', src)
        actionLog('admin_action', 'Alternou nomes.', {})

    elseif action == 'blips' then
        if not P.RequireAction(src, action) then return end
        TriggerClientEvent('mz_staffpanel:client:toggleBlips', src)
        actionLog('admin_action', 'Alternou blips.', {})

    elseif action == 'wall' then
        if not P.RequireAction(src, action) then return end
        TriggerClientEvent('mz_staffpanel:client:toggleWall', src)
        actionLog('admin_action', 'Alternou wall.', {})

    elseif action == 'coords' then
        if not P.RequireAction(src, action) then return end
        TriggerClientEvent('mz_staffpanel:client:toggleCoords', src)

    elseif action == 'copyVector2' then
        if not P.RequireAction(src, 'vector') then return end
        TriggerClientEvent('mz_staffpanel:client:copyToClipboard', src, 'coords2')

    elseif action == 'copyVector3' then
        if not P.RequireAction(src, 'vector') then return end
        TriggerClientEvent('mz_staffpanel:client:copyToClipboard', src, 'coords3')

    elseif action == 'copyVector4' then
        if not P.RequireAction(src, 'vector') then return end
        TriggerClientEvent('mz_staffpanel:client:copyToClipboard', src, 'coords4')

    elseif action == 'copyHeading' then
        if not P.RequireAction(src, 'heading') then return end
        TriggerClientEvent('mz_staffpanel:client:copyToClipboard', src, 'heading')

    elseif action == 'reporttoggle' then
        if not P.RequireAction(src, action) then return end
        if QBCore.Functions.ToggleOptin then QBCore.Functions.ToggleOptin(src) end
        if QBCore.Functions.IsOptin and QBCore.Functions.IsOptin(src) then
            P.Notify(src, 'Recebimento de reports ativado.', 'success')
            actionLog('report', 'Ativou recebimento de reports.', {})
        else
            P.Notify(src, 'Recebimento de reports desativado.', 'error')
            actionLog('report', 'Desativou recebimento de reports.', {})
        end

    elseif action == 'announce' then
        if not P.RequireAction(src, action) then return end
        local msg = tostring(payload.message or '')
        if msg == '' then return P.Notify(src, 'Digite uma mensagem.', 'error') end
        TriggerClientEvent('chat:addMessage', -1, { color = {255, 0, 0}, multiline = true, args = { 'ANÚNCIO', msg } })
        actionLog('communication', msg, {})

    elseif action == 'staffchat' then
        if not P.RequireAction(src, action) then return end
        local msg = tostring(payload.message or '')
        if msg == '' then return P.Notify(src, 'Digite uma mensagem.', 'error') end
        P.BroadcastToAdmins({ ('STAFF | %s'):format(GetPlayerName(src)), msg }, {255, 0, 0})
        actionLog('communication', msg, {})

    elseif action == 'replyReport' then
    if not P.RequireAction(src, 'staffchat') then return end

    local msg = tostring(payload.message or ''):sub(1, 500)
    if msg == '' then
        return P.Notify(src, 'Mensagem inválida.', 'error')
    end

    local reportId = tonumber(payload.reportId or 0) or 0
    if reportId <= 0 then
        return P.Notify(src, 'Report inválido.', 'error')
    end

    local reportRow = P.GetReportById(reportId)
    if not reportRow then
        return P.Notify(src, 'Report não encontrado.', 'error')
    end

    local adminPlayer = QBCore.Functions.GetPlayer(src)
    local adminLicense = (adminPlayer and adminPlayer.PlayerData.license) or P.GetIdentifierSafe(src, 'license') or '-'

    if not reportRow.accepted_by_src or tonumber(reportRow.accepted_by_src or 0) <= 0 then
        P.TouchReport(reportId, {
            status = 'em_atendimento',
            waitingOn = 'player',
            acceptedBySrc = src,
            acceptedByName = GetPlayerName(src) or ('ID ' .. tostring(src)),
            claimedByLicense = adminLicense,
            response = msg
        })
    else
        P.TouchReport(reportId, {
            response = msg
        })
    end

    P.AddReportMessage(reportId, 'admin', src, msg, { action = 'reply' })
    P.Notify(src, 'Resposta enviada no atendimento.', 'success')
    actionLog('report', msg, { reportId = reportId })

    elseif action == 'reportAccept' then
    if not P.RequireAction(src, 'staffchat') then return end

    local reportId = tonumber(payload.reportId or 0) or 0
    if reportId <= 0 then
        return P.Notify(src, 'Report inválido.', 'error')
    end

    local adminPlayer = QBCore.Functions.GetPlayer(src)
    local adminLicense = (adminPlayer and adminPlayer.PlayerData.license) or P.GetIdentifierSafe(src, 'license') or '-'

    P.TouchReport(reportId, {
        status = 'em_atendimento',
        waitingOn = 'player',
        acceptedBySrc = src,
        acceptedByName = GetPlayerName(src) or ('ID ' .. tostring(src)),
        claimedByLicense = adminLicense,
        forceAcceptedAt = true
    })

    P.AddReportMessage(reportId, 'system', 0, ('Atendimento assumido por %s.'):format(GetPlayerName(src) or ('ID ' .. tostring(src))), {
        action = 'accept',
        admin = src
    })

    P.Notify(src, ('Report #%d assumido.'):format(reportId), 'success')
    actionLog('report', 'Assumiu report.', { reportId = reportId })

    elseif action == 'reportClose' then
    if not P.RequireAction(src, 'staffchat') then return end

    local reportId = tonumber(payload.reportId or 0) or 0
    if reportId <= 0 then
        return P.Notify(src, 'Report inválido.', 'error')
    end

    local status = P.NormalizeReportStatus(payload.status or 'resolvido', 'resolvido')
    local note = tostring(payload.note or ''):sub(1, 500)
    local closeReason = tostring(payload.closedReason or payload.reason or status):sub(1, 255)

    local allowedStatus = {
        resolvido = true,
        recusado = true,
        cancelado = true
    }

    if not allowedStatus[status] then
        return P.Notify(src, 'Status inválido.', 'error')
    end

    P.TouchReport(reportId, {
        status = status,
        waitingOn = 'none',
        closedBySrc = src,
        closedByName = GetPlayerName(src) or ('ID ' .. tostring(src)),
        closedReason = closeReason,
        response = note ~= '' and note or nil
    })

    if note ~= '' then
        P.AddReportMessage(reportId, 'admin', src, note, { action = 'close_note', status = status })
    end

    P.AddReportMessage(reportId, 'system', 0, ('Atendimento finalizado com status: %s.'):format(status), {
        action = 'close',
        status = status,
        note = note,
        closedReason = closeReason
    })

    P.Notify(src, ('Report #%d finalizado.'):format(reportId), 'success')
    actionLog('report', 'Finalizou report.', { reportId = reportId, status = status, note = note })

    elseif action == 'setMyDimension' then
        if not P.RequireAction(src, 'dimension') then return end
        local bucket = tonumber(payload.dimension or payload.bucket or 0) or 0
        if bucket < 0 then bucket = 0 end
        SetPlayerRoutingBucket(src, bucket)
        P.Notify(src, ('Sua dimensão foi alterada para %d.'):format(bucket), 'success')
        actionLog('admin_action', 'Alterou a própria dimensão.', { bucket = bucket })

    elseif action == 'setDimension' then
        if not P.RequireAction(src, 'dimension') then return end
        local bucket = tonumber(payload.dimension or payload.bucket or 0) or 0
        if bucket < 0 then bucket = 0 end
        SetPlayerRoutingBucket(targetPlayer.PlayerData.source, bucket)
        P.Notify(src, ('Player %d foi para dimensão %d.'):format(targetPlayer.PlayerData.source, bucket), 'success')
        actionLog('admin_action', 'Alterou dimensão do jogador.', { target = targetPlayer.PlayerData.source, bucket = bucket })
        P.Notify(targetPlayer.PlayerData.source, ('Você foi movido para dimensão %d.'):format(bucket), 'primary')

    elseif action == 'spawnVehicle' then
        if not P.RequireAction(src, action) then return end
        local model = tostring(payload.model or ''):lower()
        if model == '' then return P.Notify(src, 'Modelo inválido.', 'error') end
        TriggerClientEvent('mz_staffpanel:client:spawnVehicle', src, model)
        actionLog('vehicle', 'Spawnou veículo.', { model = model })

    elseif action == 'deleteVehicle' then
        if not P.RequireAction(src, action) then return end
        TriggerClientEvent('mz_staffpanel:client:deleteVehicle', src)
        actionLog('vehicle', 'Deletou veículo.', {})

    elseif action == 'saveVehicle' then
        if not P.RequireAction(src, action) then return end
        TriggerClientEvent('mz_staffpanel:client:requestSaveVehicle', src)
        actionLog('vehicle', 'Solicitou salvar veículo.', {})

    elseif action == 'maxmods' then
        if not P.RequireAction(src, action) then return end
        TriggerClientEvent('mz_staffpanel:client:maxmodVehicle', src)
        actionLog('vehicle', 'Aplicou maxmods.', {})

    elseif action == 'intoVehicle' then
        if not P.RequireAction(src, action) then return end
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
                P.Notify(src, 'Você entrou no veículo do player.', 'success')
                actionLog('admin_action', 'Entrou no veículo do jogador.', { target = targetPlayer.PlayerData.source })
            else
                P.Notify(src, 'Sem assento livre no veículo.', 'error')
            end
        else
            P.Notify(src, 'O jogador não está em veículo.', 'error')
        end

    elseif action == 'inventory' then
        if not P.RequireAction(src, action) then return end
        if GetResourceState(Config.OpenInventoryResource) == 'started' then
            exports[Config.OpenInventoryResource]:OpenInventoryById(src, targetPlayer.PlayerData.source)
            actionLog('inventory', 'Abriu inventário do jogador.', { target = targetPlayer.PlayerData.source })
        else
            P.Notify(src, 'qb-inventory não está iniciado.', 'error')
        end

    elseif action == 'cloth' then
        if not P.RequireAction(src, 'clothing') then return end
        TriggerClientEvent(Config.ClothingEvent, targetPlayer.PlayerData.source)
        P.Notify(src, 'Menu de roupa aberto no player.', 'success')
        actionLog('admin_action', 'Abriu menu de roupa do jogador.', { target = targetPlayer.PlayerData.source })

    elseif action == 'giveWeapon' then
        if not P.RequireAction(src, action) then return end
        local weaponName = tostring(payload.weapon or ''):upper()
        local ammo = tonumber(payload.ammo or 250) or 250
        if weaponName == '' then return P.Notify(src, 'Arma inválida.', 'error') end
        TriggerClientEvent('mz_staffpanel:client:giveWeapon', targetPlayer and targetPlayer.PlayerData.source or src, weaponName, ammo)
        P.Notify(src, ('Arma enviada: %s'):format(weaponName), 'success')
        actionLog('weapon', 'Enviou arma.', { target = targetPlayer and targetPlayer.PlayerData.source or src, weapon = weaponName, ammo = ammo })

    elseif action == 'setmodel' then
        if not P.RequireAction(src, action) then return end
        local model = tostring(payload.model or '')
        if model == '' then return P.Notify(src, 'Modelo inválido.', 'error') end
        TriggerClientEvent('mz_staffpanel:client:setModel', targetPlayer and targetPlayer.PlayerData.source or src, model)
        actionLog('dev', 'Alterou model.', { target = targetPlayer and targetPlayer.PlayerData.source or src, model = model })

    elseif action == 'setspeed' then
        if not P.RequireAction(src, action) then return end
        local speed = tostring(payload.speed or 'normal')
        TriggerClientEvent('mz_staffpanel:client:setSpeed', targetPlayer and targetPlayer.PlayerData.source or src, speed)
        actionLog('dev', 'Alterou velocidade.', { target = targetPlayer and targetPlayer.PlayerData.source or src, speed = speed })

    elseif action == 'setammo' then
        if not P.RequireAction(src, action) then return end
        local amount = tonumber(payload.amount or 0)
        if not amount then return P.Notify(src, 'Quantidade inválida.', 'error') end
        TriggerClientEvent('mz_staffpanel:client:setAmmo', targetPlayer and targetPlayer.PlayerData.source or src, amount)
        actionLog('weapon', 'Setou munição.', { target = targetPlayer and targetPlayer.PlayerData.source or src, amount = amount })

    elseif action == 'givenuifocus' then
        if not P.RequireAction(src, action) then return end
        TriggerClientEvent('mz_staffpanel:client:giveNuiFocus', targetPlayer and targetPlayer.PlayerData.source or src, payload.focus == true, payload.mouse == true)
        actionLog('dev', 'Alterou NUI focus.', { target = targetPlayer and targetPlayer.PlayerData.source or src, focus = payload.focus == true, mouse = payload.mouse == true })
    end
end

RegisterNetEvent('mz_staffpanel:server:performAction', function(payload)
    P.HandleAction(source, payload)
end)

RegisterNetEvent('mz_staffpanel:server:spectateTick', function()
    local adminSrc = source
    local st = P.State.adminSpectateState[adminSrc]
    if not st or not st.active then return end
    local targetSrc = st.target
    if not P.IsOnline(adminSrc) or not P.IsOnline(targetSrc) then return P.StopSpectate(adminSrc, false) end
    local tPed = GetPlayerPed(targetSrc)
    if not tPed or tPed == 0 then return P.StopSpectate(adminSrc, false) end
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

RegisterNetEvent('mz_staffpanel:server:setSpectateBucket', function()
    local adminSrc = source
    local st = P.State.adminSpectateState[adminSrc]
    if not st or not st.active or not st.target then return end

    local targetSrc = tonumber(st.target)
    if not targetSrc or not P.IsOnline(targetSrc) then return end

    local bucket = GetPlayerRoutingBucket(targetSrc) or 0
    if bucket < 0 then bucket = 0 end

    SetPlayerRoutingBucket(adminSrc, bucket)
end)

RegisterNetEvent('mz_staffpanel:server:setWallState', function(state)
    local src = source
    if not P.RequireAction(src, 'wall') then return end
    P.State.wallWatchers[src] = state == true
    P.AddLog('admin_action', 'wall_state', src, nil, P.State.wallWatchers[src] and 'Ativou wall.' or 'Desativou wall.', { state = P.State.wallWatchers[src] })
    if not P.State.wallWatchers[src] then
        TriggerClientEvent('mz_staffpanel:client:updateWall', src, {}, GetPlayerRoutingBucket(src) or 0)
    end
end)

CreateThread(function()
    while true do
        Wait((Config.Wall and Config.Wall.UpdateInterval) or 150)

        local hasWatcher = false
        for src, enabled in pairs(P.State.wallWatchers) do
            if enabled and P.IsOnline(src) then
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
                        local isStaff = P.HasQBBypass(targetSrc)
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
                            name = Player and P.GetPlayerNameSafe(Player) or (GetPlayerName(targetSrc) or ('ID ' .. tostring(targetSrc))),
                            x = coords.x,
                            y = coords.y,
                            z = coords.z,
                            bucket = GetPlayerRoutingBucket(targetSrc) or 0,
                            staff = isStaff == true
                        }
                    end
                end
            end

            for src, enabled in pairs(P.State.wallWatchers) do
                if enabled and P.IsOnline(src) then
                    TriggerClientEvent('mz_staffpanel:client:updateWall', src, snapshot, GetPlayerRoutingBucket(src) or 0)
                else
                    P.State.wallWatchers[src] = nil
                end
            end
        end
    end
end)

RegisterNetEvent('mz_staffpanel:server:saveVehicleData', function(props, plate)
    local src = source
    if not P.RequireAction(src, 'saveVehicle') then return end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or type(props) ~= 'table' then
        return P.Notify(src, 'Dados do veículo inválidos.', 'error')
    end

    local inputPlate = tostring(plate or props.plate or ''):gsub('^%s+', ''):gsub('%s+$', ''):upper()
    if inputPlate == '' then
        return P.Notify(src, 'Placa inválida.', 'error')
    end

    local modelName, vehicleData = nil, nil
    if props.model then
        modelName, vehicleData = P.GetVehicleModelByHash(props.model)
    end

    if not vehicleData then
        local fallbackName = tostring(props.modelName or props.vehicle or props.spawn or ''):lower()
        if fallbackName ~= '' then
            vehicleData = QBCore.Shared.Vehicles[fallbackName]
            modelName = fallbackName
        end
    end

    if not vehicleData then
        return P.Notify(src, 'Não encontrei esse veículo na shared.', 'error')
    end

    local vehiclesTable = Config.PlayerVehiclesTable or 'player_vehicles'
    local existing = MySQL.single.await(('SELECT plate, citizenid FROM `%s` WHERE plate = ? LIMIT 1'):format(vehiclesTable), { inputPlate })
    if existing then
        if tostring(existing.citizenid or '') == tostring(Player.PlayerData.citizenid or '') then
            return P.Notify(src, ('Já existe um veículo salvo com a placa %s para esse player.'):format(inputPlate), 'error')
        else
            return P.Notify(src, ('A placa %s já pertence a outro registro.'):format(inputPlate), 'error')
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
        P.Notify(src, ('Veículo %s salvo na garagem.'):format(tostring(vehicleData.model or modelName or 'desconhecido')), 'success')
        P.AddLog('vehicle', 'save_vehicle', src, nil, 'Salvou veículo na garagem.', { model = tostring(vehicleData.model or modelName or 'desconhecido'), plate = inputPlate })
    else
        P.Notify(src, 'Falha ao salvar veículo. Verifique a tabela player_vehicles.', 'error')
        print('^1[mz_staffpanel] save vehicle error:^7', err)
    end
end)

AddEventHandler('playerConnecting', function(playerName, setKickReason, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)

    local now = os.time()
    local license = P.GetIdentifierSafe(src, 'license')
    local discord = P.GetIdentifierSafe(src, 'discord')
    local ip = P.GetIdentifierSafe(src, 'ip')

    local clauses, params = {}, {}
    if license then clauses[#clauses + 1] = 'license = ?'; params[#params + 1] = license end
    if discord then clauses[#clauses + 1] = 'discord = ?'; params[#params + 1] = discord end
    if ip then clauses[#clauses + 1] = 'ip = ?'; params[#params + 1] = ip end

    if #clauses == 0 then
        deferrals.done()
        return
    end

    local query = ('SELECT * FROM `%s` WHERE status = ? AND (%s) ORDER BY id DESC LIMIT 1'):format(Config.BanTable, table.concat(clauses, ' OR '))
    table.insert(params, 1, 'active')
    local ban = MySQL.single.await(query, params)
    if not ban then
        deferrals.done()
        return
    end

    local expire = tonumber(ban.expire or 0) or 0
    if expire > 0 and expire < 2147483647 and expire <= now then
        MySQL.query.await(('UPDATE `%s` SET status = ?, expired_at = CURRENT_TIMESTAMP WHERE id = ?'):format(Config.BanTable), { 'expired', ban.id })
        deferrals.done()
        return
    end

    local reason = tostring(ban.reason or 'Banido')
    if expire >= 2147483647 then
        P.AddLog('ban', 'block_connect', 0, src, reason, { permanent = true, banId = ban.id })
        deferrals.done(('Você está banido permanentemente.\nMotivo: %s'):format(reason))
    else
        local t = os.date('*t', expire)
        P.AddLog('ban', 'block_connect', 0, src, reason, { permanent = false, banId = ban.id, expire = expire })
        deferrals.done(('Você está banido.\nMotivo: %s\nExpira em: %02d/%02d/%04d %02d:%02d'):format(reason, t.day, t.month, t.year, t.hour, t.min))
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    P.State.reportCooldown[src] = nil
    P.State.frozenPlayers[src] = nil
    P.State.wallWatchers[src] = nil

    if P.State.adminSpectateState[src] then
        P.State.adminSpectateState[src] = nil
    end

    for adminSrc, st in pairs(P.State.adminSpectateState) do
        if st and st.target == src then
            P.StopSpectate(adminSrc, true)
        end
    end
end)