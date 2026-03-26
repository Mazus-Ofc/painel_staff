local P = MZ_STAFFPANEL
local QBCore = P.QBCore

local REPORT_CLOSED_STATUSES = {
    resolvido = true,
    recusado = true,
    cancelado = true,
}

local function trimText(value, maxLen)
    value = tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if maxLen and maxLen > 0 then
        value = value:sub(1, maxLen)
    end
    return value
end

local function getAdminIdentity(src)
    local adminPlayer = QBCore.Functions.GetPlayer(src)
    local adminName = GetPlayerName(src) or ('ID ' .. tostring(src))
    local adminLicense = (adminPlayer and adminPlayer.PlayerData.license) or P.GetIdentifierSafe(src, 'license') or '-'
    return adminName, adminLicense
end

local function resolveReport(payload)
    local reportId = tonumber(payload.reportId or payload.id or 0) or 0
    if reportId > 0 then
        return reportId, P.GetReportById(reportId)
    end

    local targetId = tonumber(payload.target or payload.playerId or 0) or 0
    if targetId > 0 then
        local row = P.GetOpenReportForPlayer(targetId)
        if row then
            return tonumber(row.id or 0) or 0, row
        end
    end

    return 0, nil
end

P.RegisterAction('announce', {
    resolveTarget = false,
}, function(ctx)
    local msg = trimText(ctx.payload.message, 500)
    if msg == '' then
        return P.Notify(ctx.src, 'Digite uma mensagem.', 'error')
    end

    TriggerClientEvent('chat:addMessage', -1, {
        color = { 255, 0, 0 },
        multiline = true,
        args = { 'ANÚNCIO', msg }
    })

    ctx.log('communication', msg, {})
end)

P.RegisterAction('staffchat', {
    resolveTarget = false,
}, function(ctx)
    local msg = trimText(ctx.payload.message, 500)
    if msg == '' then
        return P.Notify(ctx.src, 'Digite uma mensagem.', 'error')
    end

    P.BroadcastToAdmins({
        ('STAFF | %s'):format(GetPlayerName(ctx.src)),
        msg
    }, { 255, 0, 0 })

    ctx.log('communication', msg, {})
end)

P.RegisterAction('replyReport', {
    resolveTarget = false,
    permission = 'staffchat',
}, function(ctx)
    local msg = trimText(ctx.payload.message, 500)
    if msg == '' then
        return P.Notify(ctx.src, 'Mensagem inválida.', 'error')
    end

    local reportId, reportRow = resolveReport(ctx.payload)
    if reportId <= 0 or not reportRow then
        return P.Notify(ctx.src, 'Report não encontrado.', 'error')
    end

    local adminName, adminLicense = getAdminIdentity(ctx.src)

    if not reportRow.accepted_by_src or tonumber(reportRow.accepted_by_src or 0) <= 0 then
        P.TouchReport(reportId, {
            status = 'em_atendimento',
            waitingOn = 'player',
            acceptedBySrc = ctx.src,
            acceptedByName = adminName,
            claimedByLicense = adminLicense,
            response = msg
        })
    else
        P.TouchReport(reportId, {
            response = msg
        })
    end

    P.AddReportMessage(reportId, 'admin', ctx.src, msg, { action = 'reply' })

    P.Notify(ctx.src, 'Resposta enviada no atendimento.', 'success')
    ctx.log('report', msg, { reportId = reportId })
end)

P.RegisterAction('reportAccept', {
    resolveTarget = false,
    permission = 'staffchat',
}, function(ctx)
    local reportId = tonumber(ctx.payload.reportId or 0) or 0
    if reportId <= 0 then
        return P.Notify(ctx.src, 'Report inválido.', 'error')
    end

    local adminName, adminLicense = getAdminIdentity(ctx.src)

    P.TouchReport(reportId, {
        status = 'em_atendimento',
        waitingOn = 'player',
        acceptedBySrc = ctx.src,
        acceptedByName = adminName,
        claimedByLicense = adminLicense,
        forceAcceptedAt = true
    })

    P.AddReportMessage(reportId, 'system', 0, ('Atendimento assumido por %s.'):format(adminName), {
        action = 'accept',
        admin = ctx.src
    })

    local st = P.GetDutyState and P.GetDutyState(ctx.src)
    if st then
        st.status = 'em_atendimento'
    end

    P.AddDailyStat(adminLicense, adminName, 'reports_handled', 1)

    P.Notify(ctx.src, ('Report #%d assumido.'):format(reportId), 'success')
    ctx.log('report', 'Assumiu report.', { reportId = reportId })
end)

P.RegisterAction('reportClose', {
    resolveTarget = false,
    permission = 'staffchat',
}, function(ctx)
    local reportId = tonumber(ctx.payload.reportId or 0) or 0
    if reportId <= 0 then
        return P.Notify(ctx.src, 'Report inválido.', 'error')
    end

    local status = P.NormalizeReportStatus(ctx.payload.status or 'resolvido', 'resolvido')
    if not REPORT_CLOSED_STATUSES[status] then
        return P.Notify(ctx.src, 'Status inválido para encerramento.', 'error')
    end

    local note = trimText(ctx.payload.note, 500)
    local closeReason = trimText(ctx.payload.closedReason or ctx.payload.reason or status, 255)

    local adminName, adminLicense = getAdminIdentity(ctx.src)

    P.TouchReport(reportId, {
        status = status,
        waitingOn = 'none',
        closedBySrc = ctx.src,
        closedByName = adminName,
        closedReason = closeReason,
        response = note ~= '' and note or nil
    })

    if note ~= '' then
        P.AddReportMessage(reportId, 'admin', ctx.src, note, {
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

    local st = P.GetDutyState and P.GetDutyState(ctx.src)
    if st and tostring(st.status or '') == 'em_atendimento' then
        st.status = 'livre'
    end

    P.AddDailyStat(adminLicense, adminName, 'reports_closed', 1)

    P.Notify(ctx.src, ('Report #%d finalizado.'):format(reportId), 'success')
    ctx.log('report', 'Finalizou report.', {
        reportId = reportId,
        status = status,
        note = note,
        closedReason = closeReason
    })
end)

P.RegisterAction('reportReopen', {
    resolveTarget = false,
    permission = 'staffchat',
}, function(ctx)
    local reportId = tonumber(ctx.payload.reportId or 0) or 0
    if reportId <= 0 then
        return P.Notify(ctx.src, 'Report inválido.', 'error')
    end

    P.TouchReport(reportId, {
        status = 'em_atendimento',
        waitingOn = 'player',
        resetClosed = true,
        bumpReopened = true
    })

    P.AddReportMessage(reportId, 'system', 0, ('Atendimento reaberto por %s.'):format(GetPlayerName(ctx.src) or ('ID ' .. tostring(ctx.src))), {
        action = 'reopen',
        admin = ctx.src
    })

    P.Notify(ctx.src, ('Report #%d reaberto.'):format(reportId), 'success')
    ctx.log('report', 'Reabriu report.', { reportId = reportId })
end)