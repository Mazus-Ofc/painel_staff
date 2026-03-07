local P = MZ_STAFFPANEL

P.RegisterQbCommand(Config.Commands.dim, 'Trocar sua dimensão', {{name='dim', help='ID da dimensão (0 = padrão)'}}, false, function(source, args)
    P.HandleAction(source, { action = 'setMyDimension', dimension = tonumber(args[1] or '0') })
end, Config.ActionPerms.dimension)

P.RegisterQbCommand(Config.Commands.setdim, 'Definir dimensão de um player', {{name='id', help='ID do jogador'}, {name='dim', help='ID da dimensão (0 = padrão)'}}, true, function(source, args)
    P.HandleAction(source, { action = 'setDimension', target = tonumber(args[1]), dimension = tonumber(args[2] or '0') })
end, Config.ActionPerms.dimension)
