local P = MZ_STAFFPANEL

P.RegisterQbCommand(Config.Commands.warn, 'Aplicar warn em jogador', {{name='id', help='ID do jogador'}, {name='motivo', help='Motivo'}}, true, function(source, args)
    local id = tonumber(args[1])
    table.remove(args, 1)
    P.HandleAction(source, { action = 'warn', target = id, reason = table.concat(args, ' ') })
end, Config.ActionPerms.warn)

P.RegisterQbCommand(Config.Commands.checkwarns, 'Ver warns do jogador', {{name='id', help='ID do jogador'}}, true, function(source, args)
    local targetId = tonumber(args[1])
    local warns = P.CheckWarns(targetId)
    if not warns then return P.Notify(source, 'Jogador offline ou warns indisponíveis.', 'error') end
    if #warns == 0 then return P.Notify(source, 'Esse jogador não possui warns.', 'primary') end
    P.Notify(source, ('Total de warns: %d'):format(#warns), 'success')
    for i, warn in ipairs(warns) do
        TriggerClientEvent('chat:addMessage', source, { args = { 'WARNS', ('#%d | %s | %s'):format(i, warn.warnId or '-', warn.reason or '-') }, color = {255, 180, 0} })
    end
end, Config.ActionPerms.warn)

P.RegisterQbCommand(Config.Commands.delwarn, 'Remover warn do jogador', {{name='id', help='ID do jogador'}, {name='numero', help='Índice do warn'}}, true, function(source, args)
    local ok, data = P.DeleteWarn(tonumber(args[1]), tonumber(args[2]))
    if not ok then return P.Notify(source, data or 'Falha ao remover warn.', 'error') end
    P.Notify(source, ('Warn removido: %s'):format(data.warnId or '-'), 'success')
end, Config.ActionPerms.warn)

P.RegisterAliases(Config.Commands.unban, Config.Commands.unbanAliases, 'Remover ban pelo ID do registro', {{name='banId', help='ID do ban'}, {name='motivo', help='Motivo da remoção'}}, true, function(source, args)
    local banId = tonumber(args[1])
    table.remove(args, 1)
    P.HandleAction(source, { action = 'unban', banId = banId, reason = table.concat(args, ' ') })
end, Config.ActionPerms.unban)
