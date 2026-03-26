local P = MZ_STAFFPANEL
local QBCore = P.QBCore

P.RegisterAction('noclip', {
    resolveTarget = false,
}, function(ctx)
    TriggerClientEvent('mz_staffpanel:client:toggleNoClip', ctx.src)
    ctx.log('admin_action', 'Alternou noclip.', {})
end)

P.RegisterAction('invisible', {
    resolveTarget = false,
}, function(ctx)
    TriggerClientEvent('mz_staffpanel:client:toggleInvisible', ctx.src)
    ctx.log('admin_action', 'Alternou invisibilidade.', {})
end)

P.RegisterAction('god', {
    resolveTarget = false,
}, function(ctx)
    TriggerClientEvent('mz_staffpanel:client:toggleGod', ctx.src)
    ctx.log('admin_action', 'Alternou godmode.', {})
end)

P.RegisterAction('names', {
    resolveTarget = false,
}, function(ctx)
    TriggerClientEvent('mz_staffpanel:client:toggleNames', ctx.src)
    ctx.log('admin_action', 'Alternou nomes.', {})
end)

P.RegisterAction('blips', {
    resolveTarget = false,
}, function(ctx)
    TriggerClientEvent('mz_staffpanel:client:toggleBlips', ctx.src)
    ctx.log('admin_action', 'Alternou blips.', {})
end)

P.RegisterAction('wall', {
    resolveTarget = false,
}, function(ctx)
    TriggerClientEvent('mz_staffpanel:client:toggleWall', ctx.src)
    ctx.log('admin_action', 'Alternou wall.', {})
end)

P.RegisterAction('coords', {
    resolveTarget = false,
}, function(ctx)
    TriggerClientEvent('mz_staffpanel:client:toggleCoords', ctx.src)
end)

P.RegisterAction('copyVector2', {
    resolveTarget = false,
    permission = 'vector',
}, function(ctx)
    TriggerClientEvent('mz_staffpanel:client:copyToClipboard', ctx.src, 'coords2')
end)

P.RegisterAction('copyVector3', {
    resolveTarget = false,
    permission = 'vector',
}, function(ctx)
    TriggerClientEvent('mz_staffpanel:client:copyToClipboard', ctx.src, 'coords3')
end)

P.RegisterAction('copyVector4', {
    resolveTarget = false,
    permission = 'vector',
}, function(ctx)
    TriggerClientEvent('mz_staffpanel:client:copyToClipboard', ctx.src, 'coords4')
end)

P.RegisterAction('copyHeading', {
    resolveTarget = false,
    permission = 'heading',
}, function(ctx)
    TriggerClientEvent('mz_staffpanel:client:copyToClipboard', ctx.src, 'heading')
end)

P.RegisterAction('reporttoggle', {
    resolveTarget = false,
}, function(ctx)
    if QBCore.Functions.ToggleOptin then
        QBCore.Functions.ToggleOptin(ctx.src)
    end

    if QBCore.Functions.IsOptin and QBCore.Functions.IsOptin(ctx.src) then
        P.Notify(ctx.src, 'Recebimento de reports ativado.', 'success')
        ctx.log('report', 'Ativou recebimento de reports.', {})
    else
        P.Notify(ctx.src, 'Recebimento de reports desativado.', 'error')
        ctx.log('report', 'Desativou recebimento de reports.', {})
    end
end)