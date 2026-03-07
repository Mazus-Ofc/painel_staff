local QBCore = exports['qb-core']:GetCoreObject()
local P = MZ_STAFFPANEL

QBCore.Commands.Add(Config.Commands.report, 'Enviar report para a staff', {{name='mensagem', help='Sua mensagem'}}, true, function(source, args)
    TriggerEvent('mz_staffpanel:server:reportProxy', source, table.concat(args, ' '))
end, 'user')

P.RegisterQbCommand(Config.Commands.reportr, 'Responder report de um jogador', {{name='id', help='ID do jogador'}, {name='mensagem', help='Resposta'}}, true, function(source, args)
    local id = tonumber(args[1])
    table.remove(args, 1)
    P.HandleAction(source, { action = 'replyReport', target = id, message = table.concat(args, ' ') })
end, Config.ActionPerms.staffchat)

P.RegisterQbCommand(Config.Commands.reporttoggle, 'Alternar recebimento de reports', {}, false, function(source)
    P.HandleAction(source, { action = 'reporttoggle' })
end, Config.ActionPerms.reporttoggle)

P.RegisterQbCommand(Config.Commands.staffchat, 'Mensagem no staffchat', {{name='mensagem', help='Mensagem'}}, true, function(source, args)
    P.HandleAction(source, { action = 'staffchat', message = table.concat(args, ' ') })
end, Config.ActionPerms.staffchat)

P.RegisterQbCommand(Config.Commands.announce, 'Enviar anúncio global', {{name='mensagem', help='Mensagem'}}, true, function(source, args)
    P.HandleAction(source, { action = 'announce', message = table.concat(args, ' ') })
end, Config.ActionPerms.announce)

P.RegisterQbCommand(Config.Commands.kickall, 'Kickar todos os players', {{name='motivo', help='Motivo'}}, true, function(source, args)
    P.HandleAction(source, { action = 'kickall', reason = table.concat(args, ' ') })
end, Config.ActionPerms.kickall)
