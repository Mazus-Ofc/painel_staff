local P = MZ_STAFFPANEL
local QBCore = P.QBCore

local REPORT_OPEN_STATUSES = {
    pendente = true,
    em_atendimento = true,
    aguardando_player = true,
    aguardando_staff = true,
}

local REPORT_CLOSED_STATUSES = {
    resolvido = true,
    recusado = true,
    cancelado = true,
}

local REPORT_ALLOWED_STATUSES = {
    pendente = true,
    em_atendimento = true,
    aguardando_player = true,
    aguardando_staff = true,
    resolvido = true,
    recusado = true,
    cancelado = true,
}

local REPORT_ALLOWED_PRIORITIES = {
    baixa = true,
    normal = true,
    alta = true,
    urgente = true,
}

local REPORT_QUICK_REPLIES = {
    'Estamos analisando seu caso agora.',
    'Explique melhor o ocorrido, por favor.',
    'Envie mais detalhes ou nomes envolvidos.',
    'Aguarde em um local seguro, a staff já vai até você.',
    'Seu chamado foi atendido e será encerrado.'
}

local function trimText(value, maxLen)
    value = tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if maxLen and maxLen > 0 then
        value = value:sub(1, maxLen)
    end
    return value
end

function P.NormalizeReportStatus(status, fallback)
    status = trimText(status, 32):lower()
    if REPORT_ALLOWED_STATUSES[status] then
        return status
    end
    return fallback or 'pendente'
end

function P.NormalizeReportPriority(priority, fallback)
    priority = trimText(priority, 16):lower()
    if REPORT_ALLOWED_PRIORITIES[priority] then
        return priority
    end
    return fallback or 'normal'
end

function P.NormalizeReportTags(tags)
    local out, seen = {}, {}
    if type(tags) == 'string' then
        for token in string.gmatch(tags, '([^,]+)') do
            local t = trimText(token, 24):lower()
            if t ~= '' and not seen[t] then
                seen[t] = true
                out[#out + 1] = t
            end
        end
    elseif type(tags) == 'table' then
        for _, token in ipairs(tags) do
            local t = trimText(token, 24):lower()
            if t ~= '' and not seen[t] then
                seen[t] = true
                out[#out + 1] = t
            end
        end
    end
    table.sort(out)
    return out
end

function P.JoinReportTags(tags)
    return table.concat(P.NormalizeReportTags(tags), ',')
end

function P.DecodeReportTags(tags)
    return P.NormalizeReportTags(tags)
end

function P.IsReportOpen(status)
    return REPORT_OPEN_STATUSES[P.NormalizeReportStatus(status)] == true
end

function P.GetReportQuickReplies()
    return REPORT_QUICK_REPLIES
end

function P.TouchReport(reportId, opts)
    opts = type(opts) == 'table' and opts or {}
    reportId = tonumber(reportId or 0) or 0
    if reportId <= 0 then return false end

    local sets, params = {}, {}
    local function addSet(sql, value)
        sets[#sets + 1] = sql
        params[#params + 1] = value
    end

    sets[#sets + 1] = 'updated_at = NOW()'

    if opts.status then addSet('status = ?', P.NormalizeReportStatus(opts.status)) end
    if opts.priority then addSet('priority = ?', P.NormalizeReportPriority(opts.priority)) end
    if opts.waitingOn then addSet('waiting_on = ?', trimText(opts.waitingOn, 24):lower()) end
    if opts.response ~= nil then addSet('response = ?', trimText(opts.response, 500)) end
    if opts.tags ~= nil then addSet('tags = ?', P.JoinReportTags(opts.tags)) end
    if opts.closedReason ~= nil then addSet('closed_reason = ?', trimText(opts.closedReason, 255)) end
    if opts.lastMessageBy then addSet('last_message_by = ?', trimText(opts.lastMessageBy, 24):lower()) end
    if opts.bumpLastMessageAt then sets[#sets + 1] = 'last_message_at = NOW()' end

    if opts.acceptedBySrc ~= nil then
        addSet('accepted_by_src = ?', tonumber(opts.acceptedBySrc) or 0)
        addSet('accepted_by_name = ?', trimText(opts.acceptedByName, 255))
        addSet('claimed_by_license = ?', trimText(opts.claimedByLicense, 80))
        sets[#sets + 1] = 'accepted_at = IFNULL(accepted_at, NOW())'
    end

    if opts.forceAcceptedAt then
        sets[#sets + 1] = 'accepted_at = NOW()'
    end

    if opts.closedBySrc ~= nil then
        addSet('closed_by_src = ?', tonumber(opts.closedBySrc) or 0)
        addSet('closed_by_name = ?', trimText(opts.closedByName, 255))
        sets[#sets + 1] = 'closed_at = NOW()'
    end

    if opts.resetClosed then
        sets[#sets + 1] = 'closed_by_src = NULL'
        sets[#sets + 1] = 'closed_by_name = NULL'
        sets[#sets + 1] = 'closed_at = NULL'
        sets[#sets + 1] = 'closed_reason = NULL'
    end

    if opts.bumpReopened then
        sets[#sets + 1] = 'reopened_count = COALESCE(reopened_count, 0) + 1'
    end

    params[#params + 1] = reportId
    MySQL.update.await(("UPDATE `%s` SET %s WHERE id = ?"):format(Config.ReportTable or 'staff_reports', table.concat(sets, ', ')), params)
    return true
end

function P.AddReportMessage(reportId, senderType, senderSrc, message, metadata)
    reportId = tonumber(reportId or 0) or 0
    if reportId <= 0 then return false end

    senderType = trimText(senderType, 24):lower()
    if senderType == '' then senderType = 'system' end

    local actor = P.GetActorInfo(senderSrc or 0)
    local cleanMessage = trimText(message, 500)

    MySQL.insert.await(('INSERT INTO `%s` (report_id, sender_type, sender_src, sender_name, sender_license, message, metadata) VALUES (?, ?, ?, ?, ?, ?, ?)'):format(Config.ReportMessagesTable or 'staff_report_messages'), {
        reportId,
        senderType,
        actor.src,
        actor.name,
        actor.license,
        cleanMessage,
        P.SafeJson(metadata)
    })

    local waitingOn = senderType == 'admin' and 'player' or (senderType == 'player' and 'staff' or nil)
    local nextStatus = senderType == 'admin' and 'aguardando_player' or (senderType == 'player' and 'aguardando_staff' or nil)

    P.TouchReport(reportId, {
        status = nextStatus,
        waitingOn = waitingOn,
        lastMessageBy = senderType,
        bumpLastMessageAt = true
    })

    P.AddLog('report_chat', senderType, senderSrc or 0, nil, cleanMessage, {
        reportId = reportId,
        metadata = metadata or {}
    })

    return true
end

function P.GetReportById(reportId)
    reportId = tonumber(reportId or 0) or 0
    if reportId <= 0 then return nil end

    local rows = MySQL.query.await(('SELECT * FROM `%s` WHERE id = ? LIMIT 1'):format(Config.ReportTable or 'staff_reports'), { reportId }) or {}
    local row = rows[1]
    if row then row.tags_list = P.DecodeReportTags(row.tags) end
    return row
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

function P.GetOpenReportForPlayer(src)
    local Player = QBCore.Functions.GetPlayer(src)
    local license = (Player and Player.PlayerData.license) or P.GetIdentifierSafe(src, 'license') or '-'
    local rows = MySQL.query.await(('SELECT * FROM `%s` WHERE player_license = ? AND status IN (?, ?, ?, ?) ORDER BY id DESC LIMIT 1'):format(Config.ReportTable or 'staff_reports'), {
        license, 'pendente', 'em_atendimento', 'aguardando_player', 'aguardando_staff'
    }) or {}
    local row = rows[1]
    if row then row.tags_list = P.DecodeReportTags(row.tags) end
    return row
end

function P.CreateReport(src, msg, origin, extra)
    extra = type(extra) == 'table' and extra or {}
    local Player = QBCore.Functions.GetPlayer(src)
    local existing = P.GetOpenReportForPlayer(src)
    if existing then
        return false, 'Você já possui um chamado em andamento.', existing.id
    end

    local reportId = MySQL.insert.await(('INSERT INTO `%s` (player_src, player_name, player_license, player_citizenid, message, status, priority, waiting_on, tags, last_message_at, last_message_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), ?)'):format(Config.ReportTable or 'staff_reports'), {
        src,
        Player and P.GetPlayerNameSafe(Player) or (GetPlayerName(src) or ('ID ' .. tostring(src))),
        (Player and Player.PlayerData.license) or P.GetIdentifierSafe(src, 'license') or '-',
        Player and Player.PlayerData.citizenid or '-',
        trimText(msg, 500),
        'pendente',
        P.NormalizeReportPriority(extra.priority or 'normal'),
        'staff',
        P.JoinReportTags(extra.tags),
        'player'
    })

    P.AddLog('report', 'create', src, nil, trimText(msg, 500), {
        reportId = reportId,
        origin = origin or 'command',
        priority = P.NormalizeReportPriority(extra.priority or 'normal'),
        tags = P.NormalizeReportTags(extra.tags)
    })

    P.AddReportMessage(reportId, 'player', src, trimText(msg, 500), {
        kind = 'initial',
        origin = origin or 'command'
    })

    return true, reportId
end

function P.FetchRecentReports(limit)
    local rows = MySQL.query.await(('SELECT * FROM `%s` ORDER BY id DESC LIMIT %d'):format(Config.ReportTable or 'staff_reports', tonumber(limit or 20) or 20)) or {}
    for _, row in ipairs(rows) do
        row.tags_list = P.DecodeReportTags(row.tags)
    end
    return rows
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
        reportRow = P.GetOpenReportForPlayer(src)
    end

    if reportRow and not P.CanAccessReport(src, reportRow) then
        return cb({ ok = false, error = 'Sem acesso ao atendimento.' })
    end

    cb({
        ok = true,
        canManage = P.CanOpen(src),
        report = reportRow,
        messages = reportRow and P.GetReportMessages(reportRow.id) or {},
        quickReplies = P.GetReportQuickReplies(),
        meta = {
            statuses = {
                'pendente',
                'em_atendimento',
                'aguardando_player',
                'aguardando_staff',
                'resolvido',
                'recusado',
                'cancelado'
            },
            priorities = {
                'baixa',
                'normal',
                'alta',
                'urgente'
            }
        }
    })
end)

AddEventHandler('mz_staffpanel:server:reportProxy', function(src, msg)
    if not src then return end
    msg = trimText(msg, 500)
    if msg == '' then return end

    local Player = QBCore.Functions.GetPlayer(src)
    local ok, reportIdOrError, existingId = P.CreateReport(src, msg, 'proxy')
    if not ok then
        if existingId then
            return P.Notify(src, ('Você já possui um chamado aberto (#%d).'):format(existingId), 'error')
        end
        return P.Notify(src, reportIdOrError or 'Falha ao criar chamado.', 'error')
    end

    local reportId = reportIdOrError
    P.AddReportMessage(reportId, 'system', 0, 'Seu chamado foi criado. Aguarde um administrador assumir o atendimento.', { action = 'created' })
    P.Notify(src, ('Seu chamado foi enviado para a staff. Protocolo #%d.'):format(reportId), 'success')

    if Player then
        print(('[mz_staffpanel] report %s (%s): %s'):format(GetPlayerName(src), Player.PlayerData.citizenid or '-', msg))
    end
end)

RegisterNetEvent('mz_staffpanel:server:sendReport', function(msg)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    msg = trimText(msg, 500)
    if msg == '' then return end

    local okCooldown, waitTime = P.CanSendReportNow(src, 5)
    if not okCooldown then
        return P.Notify(src, ('Aguarde %d segundos para enviar outro chamado.'):format(waitTime), 'error')
    end

    local ok, reportIdOrError, existingId = P.CreateReport(src, msg, 'event')
    if not ok then
        if existingId then
            return P.Notify(src, ('Você já possui um chamado aberto (#%d).'):format(existingId), 'error')
        end
        return P.Notify(src, reportIdOrError or 'Falha ao criar chamado.', 'error')
    end

    local reportId = reportIdOrError
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
    local msg = trimText(payload.message, 500)
    if msg == '' then return end

    local okCooldown, waitTime = P.CanSendReportNow(src, 3)
    if not okCooldown then
        return P.Notify(src, ('Aguarde %d segundos para enviar outra mensagem.'):format(waitTime), 'error')
    end

    local isAdmin = P.CanOpen(src) and P.IsStaffOnDuty and P.IsStaffOnDuty(src)

    if reportId <= 0 then
        if isAdmin then return end

        local ok, reportIdOrError, existingId = P.CreateReport(src, msg, 'support_ui', {
            priority = payload.priority,
            tags = payload.tags
        })

        if not ok then
            if existingId then
                return P.Notify(src, ('Você já possui um chamado aberto (#%d).'):format(existingId), 'error')
            end
            return P.Notify(src, reportIdOrError or 'Falha ao criar chamado.', 'error')
        end

        reportId = reportIdOrError
        P.AddReportMessage(reportId, 'system', 0, 'Seu chamado foi criado. Aguarde um administrador assumir o atendimento.', { action = 'created' })
        TriggerClientEvent('QBCore:Notify', src, ('Chamado #%d criado.'):format(reportId), 'success')
        return
    end

    local reportRow = P.GetReportById(reportId)
    if not reportRow or not P.CanAccessReport(src, reportRow) then
        return P.Notify(src, 'Atendimento não encontrado.', 'error')
    end

    if isAdmin then
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
    else
        P.AddReportMessage(reportId, 'player', src, msg, { action = 'reply' })
    end
end)

RegisterNetEvent('mz_staffpanel:server:supportAccept', function(payload)
    local src = source
    if not P.RequireAction(src, 'staffchat') then return end
    if not P.RequireStaffDuty(src) then return end

    payload = type(payload) == 'table' and payload or {}
    local reportId = tonumber(payload.reportId or 0) or 0
    if reportId <= 0 then
        return P.Notify(src, 'Atendimento inválido.', 'error')
    end

    local reportRow = P.GetReportById(reportId)
    if not reportRow then
        return P.Notify(src, 'Atendimento não encontrado.', 'error')
    end

    local adminPlayer = QBCore.Functions.GetPlayer(src)
    local adminName = GetPlayerName(src) or ('ID ' .. tostring(src))
    local adminLicense = (adminPlayer and adminPlayer.PlayerData.license) or P.GetIdentifierSafe(src, 'license') or '-'

    P.TouchReport(reportId, {
        status = 'em_atendimento',
        waitingOn = 'player',
        acceptedBySrc = src,
        acceptedByName = adminName,
        claimedByLicense = adminLicense,
        forceAcceptedAt = true
    })

    P.AddReportMessage(reportId, 'system', 0, ('Atendimento assumido por %s.'):format(adminName), {
        action = 'accept',
        admin = src
    })

    local st = P.GetDutyState and P.GetDutyState(src)
    if st then
        st.status = 'em_atendimento'
    end

    P.AddDailyStat(adminLicense, adminName, 'reports_handled', 1)

    P.AddLog('report', 'support_accept', src, nil, 'Assumiu atendimento.', {
        reportId = reportId,
        admin = adminName
    })

    P.Notify(src, ('Atendimento #%d assumido.'):format(reportId), 'success')
end)

RegisterNetEvent('mz_staffpanel:server:supportSetMeta', function(payload)
    local src = source
    if not P.RequireAction(src, 'staffchat') then return end
    if not P.RequireStaffDuty(src) then return end

    payload = type(payload) == 'table' and payload or {}
    local reportId = tonumber(payload.reportId or 0) or 0
    if reportId <= 0 then
        return P.Notify(src, 'Atendimento inválido.', 'error')
    end

    local reportRow = P.GetReportById(reportId)
    if not reportRow then
        return P.Notify(src, 'Atendimento não encontrado.', 'error')
    end

    local priority = P.NormalizeReportPriority(payload.priority, reportRow.priority or 'normal')
    local tags = P.NormalizeReportTags(payload.tags or reportRow.tags)
    local status = payload.status and P.NormalizeReportStatus(payload.status, reportRow.status) or nil

    P.TouchReport(reportId, {
        priority = priority,
        tags = tags,
        status = status
    })

    P.AddLog('report', 'meta_update', src, nil, 'Atualizou metadados do atendimento.', {
        reportId = reportId,
        priority = priority,
        tags = tags,
        status = status
    })

    P.Notify(src, ('Atendimento #%d atualizado.'):format(reportId), 'success')
end)

RegisterNetEvent('mz_staffpanel:server:supportReopen', function(payload)
    local src = source
    if not P.RequireAction(src, 'staffchat') then return end
    if not P.RequireStaffDuty(src) then return end

    payload = type(payload) == 'table' and payload or {}
    local reportId = tonumber(payload.reportId or 0) or 0
    if reportId <= 0 then
        return P.Notify(src, 'Atendimento inválido.', 'error')
    end

    local reportRow = P.GetReportById(reportId)
    if not reportRow then
        return P.Notify(src, 'Atendimento não encontrado.', 'error')
    end

    P.TouchReport(reportId, {
        status = 'em_atendimento',
        waitingOn = 'player',
        resetClosed = true,
        bumpReopened = true
    })

    P.AddReportMessage(reportId, 'system', 0, ('Atendimento reaberto por %s.'):format(GetPlayerName(src) or ('ID ' .. tostring(src))), {
        action = 'reopen',
        admin = src
    })

    P.Notify(src, ('Atendimento #%d reaberto.'):format(reportId), 'success')
end)

RegisterNetEvent('mz_staffpanel:server:supportClose', function(payload)
    local src = source
    if not P.RequireAction(src, 'staffchat') then return end
    if not P.RequireStaffDuty(src) then return end

    payload = type(payload) == 'table' and payload or {}
    local reportId = tonumber(payload.reportId or 0) or 0
    if reportId <= 0 then
        return P.Notify(src, 'Atendimento inválido.', 'error')
    end

    local status = P.NormalizeReportStatus(payload.status or 'resolvido', 'resolvido')
    if not REPORT_CLOSED_STATUSES[status] then
        return P.Notify(src, 'Status inválido para encerramento.', 'error')
    end

    local note = trimText(payload.note, 500)
    local closeReason = trimText(payload.closedReason or payload.reason or status, 255)
    local adminPlayer = QBCore.Functions.GetPlayer(src)
    local adminName = GetPlayerName(src) or ('ID ' .. tostring(src))
    local adminLicense = (adminPlayer and adminPlayer.PlayerData.license) or P.GetIdentifierSafe(src, 'license') or '-'

    P.TouchReport(reportId, {
        status = status,
        waitingOn = 'none',
        closedBySrc = src,
        closedByName = adminName,
        closedReason = closeReason,
        response = note ~= '' and note or nil
    })

    if note ~= '' then
        P.AddReportMessage(reportId, 'admin', src, note, {
            action = 'close_note',
            status = status
        })
    end

    P.AddReportMessage(reportId, 'system', 0, ('Atendimento finalizado com status: %s.'):format(status), {
        action = 'close',
        status = status,
        note = note,
        closedReason = closeReason
    })

    local st = P.GetDutyState and P.GetDutyState(src)
    if st and tostring(st.status or '') == 'em_atendimento' then
        st.status = 'livre'
    end

    P.AddDailyStat(adminLicense, adminName, 'reports_closed', 1)

    P.AddLog('report', 'support_close', src, nil, 'Finalizou atendimento.', {
        reportId = reportId,
        status = status,
        closedReason = closeReason
    })

    P.Notify(src, ('Atendimento #%d finalizado.'):format(reportId), 'success')
end)