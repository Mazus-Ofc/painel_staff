local P = MZ_STAFFPANEL
local QBCore = P.QBCore

function P.AddReportMessage(reportId, senderType, senderSrc, message, metadata)
    reportId = tonumber(reportId or 0) or 0
    if reportId <= 0 then return false end

    local actor = P.GetActorInfo(senderSrc or 0)

    MySQL.insert.await(('INSERT INTO `%s` (report_id, sender_type, sender_src, sender_name, sender_license, message, metadata) VALUES (?, ?, ?, ?, ?, ?, ?)'):format(Config.ReportMessagesTable or 'staff_report_messages'), {
        reportId,
        tostring(senderType or 'system'),
        actor.src,
        actor.name,
        actor.license,
        tostring(message or ''),
        P.SafeJson(metadata)
    })

    P.AddLog('report_chat', tostring(senderType or 'system'), senderSrc or 0, nil, tostring(message or ''), {
        reportId = reportId,
        metadata = metadata or {}
    })

    return true
end

function P.GetReportById(reportId)
    reportId = tonumber(reportId or 0) or 0
    if reportId <= 0 then return nil end

    local rows = MySQL.query.await(('SELECT * FROM `%s` WHERE id = ? LIMIT 1'):format(Config.ReportTable or 'staff_reports'), { reportId }) or {}
    return rows[1]
end

function P.GetReportMessages(reportId)
    reportId = tonumber(reportId or 0) or 0
    if reportId <= 0 then return {} end

    return MySQL.query.await(('SELECT * FROM `%s` WHERE report_id = ? ORDER BY id ASC'):format(Config.ReportMessagesTable or 'staff_report_messages'), { reportId }) or {}
end

function P.CanAccessReport(src, reportRow)
    if not reportRow then return false end
    if P.CanOpen(src) then return true end

    local Player = QBCore.Functions.GetPlayer(src)
    local license = (Player and Player.PlayerData.license) or P.GetIdentifierSafe(src, 'license') or '-'

    return tonumber(reportRow.player_src or 0) == tonumber(src)
        or tostring(reportRow.player_license or '-') == tostring(license)
end

function P.CreateReport(src, msg, origin)
    local Player = QBCore.Functions.GetPlayer(src)

    local reportId = MySQL.insert.await(('INSERT INTO `%s` (player_src, player_name, player_license, player_citizenid, message, status, priority) VALUES (?, ?, ?, ?, ?, ?, ?)'):format(Config.ReportTable or 'staff_reports'), {
        src,
        Player and P.GetPlayerNameSafe(Player) or (GetPlayerName(src) or ('ID ' .. tostring(src))),
        (Player and Player.PlayerData.license) or P.GetIdentifierSafe(src, 'license') or '-',
        Player and Player.PlayerData.citizenid or '-',
        tostring(msg or ''),
        'pendente',
        'normal'
    })

    P.AddLog('report', 'create', src, nil, tostring(msg or ''), { reportId = reportId, origin = origin or 'command' })
    P.AddReportMessage(reportId, 'player', src, tostring(msg or ''), { kind = 'initial', origin = origin or 'command' })

    return reportId
end

function P.FetchRecentReports(limit)
    return MySQL.query.await(('SELECT * FROM `%s` ORDER BY id DESC LIMIT %d'):format(Config.ReportTable or 'staff_reports', tonumber(limit or 20) or 20)) or {}
end

function P.CanSendReportNow(src, seconds)
    local now = os.time()
    seconds = tonumber(seconds) or 5

    if P.State.reportCooldown[src] and P.State.reportCooldown[src] > now then
        return false, (P.State.reportCooldown[src] - now)
    end

    P.State.reportCooldown[src] = now + seconds
    return true, 0
end

QBCore.Functions.CreateCallback('mz_staffpanel:server:getSupportSession', function(src, cb, reportId)
    reportId = tonumber(reportId or 0) or 0
    local reportRow = nil

    if reportId > 0 then
        reportRow = P.GetReportById(reportId)
    else
        local Player = QBCore.Functions.GetPlayer(src)
        local license = (Player and Player.PlayerData.license) or P.GetIdentifierSafe(src, 'license') or '-'
        local rows = MySQL.query.await(('SELECT * FROM `%s` WHERE player_license = ? AND status IN (?, ?) ORDER BY id DESC LIMIT 1'):format(Config.ReportTable or 'staff_reports'), {
            license, 'pendente', 'em_atendimento'
        }) or {}
        reportRow = rows[1]
    end

    if reportRow and not P.CanAccessReport(src, reportRow) then
        return cb({ ok = false, error = 'Sem acesso ao atendimento.' })
    end

    cb({
        ok = true,
        canManage = P.CanOpen(src),
        report = reportRow,
        messages = reportRow and P.GetReportMessages(reportRow.id) or {}
    })
end)

AddEventHandler('mz_staffpanel:server:reportProxy', function(src, msg)
    if not src then return end
    msg = tostring(msg or ''):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 500)
    if msg == '' then return end

    local Player = QBCore.Functions.GetPlayer(src)
    local reportId = P.CreateReport(src, msg, 'proxy')
    P.AddReportMessage(reportId, 'system', 0, 'Seu chamado foi criado. Aguarde um administrador assumir o atendimento.', { action = 'created' })
    P.Notify(src, ('Seu chamado foi enviado para a staff. Protocolo #%d.'):format(reportId), 'success')

    if Player then
        print(('[mz_staffpanel] report %s (%s): %s'):format(GetPlayerName(src), Player.PlayerData.citizenid or '-', msg))
    end
end)

RegisterNetEvent('mz_staffpanel:server:sendReport', function(msg)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    msg = tostring(msg or ''):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 500)
    if msg == '' then return end

    local ok, waitTime = P.CanSendReportNow(src, 5)
    if not ok then
        return P.Notify(src, ('Aguarde %d segundos para enviar outro chamado.'):format(waitTime), 'error')
    end

    local reportId = P.CreateReport(src, msg, 'event')
    P.AddReportMessage(reportId, 'system', 0, 'Seu chamado foi criado. Aguarde um administrador assumir o atendimento.', { action = 'created' })
    P.Notify(src, ('Seu chamado foi enviado para a staff. Protocolo #%d.'):format(reportId), 'success')

    if Player then
        print(('[mz_staffpanel] report %s (%s): %s'):format(GetPlayerName(src), Player.PlayerData.citizenid or '-', msg))
    end
end)

RegisterNetEvent('mz_staffpanel:server:supportSend', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}

    local reportId = tonumber(payload.reportId or 0) or 0
    local msg = tostring(payload.message or ''):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 500)
    if msg == '' then return end

    local ok, waitTime = P.CanSendReportNow(src, 3)
    if not ok then
        return P.Notify(src, ('Aguarde %d segundos para enviar outra mensagem.'):format(waitTime), 'error')
    end

    local isAdmin = P.CanOpen(src)

    if reportId <= 0 then
        if isAdmin then return end
        reportId = P.CreateReport(src, msg, 'support_ui')
        P.AddReportMessage(reportId, 'system', 0, 'Seu chamado foi criado. Aguarde um administrador assumir o atendimento.', { action = 'created' })
        TriggerClientEvent('QBCore:Notify', src, ('Chamado #%d criado.'):format(reportId), 'success')
        return
    end

    local reportRow = P.GetReportById(reportId)
    if not reportRow or not P.CanAccessReport(src, reportRow) then
        return P.Notify(src, 'Atendimento não encontrado.', 'error')
    end

    if isAdmin then
        if tostring(reportRow.status or '') ~= 'em_atendimento' then
            MySQL.update.await(('UPDATE `%s` SET status = ?, accepted_by_src = ?, accepted_by_name = ?, accepted_at = IFNULL(accepted_at, NOW()) WHERE id = ?'):format(Config.ReportTable or 'staff_reports'), {
                'em_atendimento', src, GetPlayerName(src) or ('ID ' .. tostring(src)), reportId
            })
        end

        MySQL.update.await(('UPDATE `%s` SET response = ?, status = ?, accepted_by_src = ?, accepted_by_name = ?, accepted_at = IFNULL(accepted_at, NOW()) WHERE id = ?'):format(Config.ReportTable or 'staff_reports'), {
            msg, 'em_atendimento', src, GetPlayerName(src) or ('ID ' .. tostring(src)), reportId
        })

        P.AddReportMessage(reportId, 'admin', src, msg, { action = 'reply' })
    else
        P.AddReportMessage(reportId, 'player', src, msg, { action = 'reply' })
    end
end)

RegisterNetEvent('mz_staffpanel:server:supportClose', function(payload)
    local src = source
    if not P.RequireAction(src, 'staffchat') then return end

    payload = type(payload) == 'table' and payload or {}
    local reportId = tonumber(payload.reportId or 0) or 0
    if reportId <= 0 then
        return P.Notify(src, 'Atendimento inválido.', 'error')
    end

    local status = tostring(payload.status or 'resolvido'):lower()
    local note = tostring(payload.note or ''):sub(1, 500)

    local allowedStatus = {
        resolvido = true,
        recusado = true,
        cancelado = true,
        finalizado = true
    }

    if not allowedStatus[status] then
        return P.Notify(src, 'Status inválido.', 'error')
    end

    MySQL.update.await(("UPDATE `%s` SET status = ?, closed_by_src = ?, closed_by_name = ?, closed_at = NOW(), response = CASE WHEN ? = '' THEN response ELSE ? END WHERE id = ?"):format(Config.ReportTable or 'staff_reports'), {
        status, src, GetPlayerName(src) or ('ID ' .. tostring(src)), note, note, reportId
    })

    if note ~= '' then
        P.AddReportMessage(reportId, 'admin', src, note, { action = 'close_note', status = status })
    end

    P.AddReportMessage(reportId, 'system', 0, ('Atendimento finalizado com status: %s.'):format(status), { action = 'close', status = status, note = note })
    P.Notify(src, ('Atendimento #%d finalizado.'):format(reportId), 'success')
end)