local P = MZ_STAFFPANEL

P.RegisterQbCommand(Config.Commands.coords, 'Alternar coords na tela', {}, false, function(source)
    P.HandleAction(source, { action = 'coords' })
end, Config.ActionPerms.coords)

P.RegisterQbCommand(Config.Commands.vector2, 'Copiar vector2', {}, false, function(source)
    P.HandleAction(source, { action = 'copyVector2' })
end, Config.ActionPerms.vector)

P.RegisterQbCommand(Config.Commands.vector3, 'Copiar vector3', {}, false, function(source)
    P.HandleAction(source, { action = 'copyVector3' })
end, Config.ActionPerms.vector)

P.RegisterQbCommand(Config.Commands.vector4, 'Copiar vector4', {}, false, function(source)
    P.HandleAction(source, { action = 'copyVector4' })
end, Config.ActionPerms.vector)

P.RegisterQbCommand(Config.Commands.heading, 'Copiar heading', {}, false, function(source)
    P.HandleAction(source, { action = 'copyHeading' })
end, Config.ActionPerms.heading)

P.RegisterQbCommand(Config.Commands.setmodel, 'Trocar modelo do player', {{name='model', help='Nome do modelo'}, {name='id', help='ID opcional'}}, false, function(source, args)
    P.HandleAction(source, { action = 'setmodel', target = tonumber(args[2]), model = args[1] })
end, Config.ActionPerms.setmodel)

P.RegisterQbCommand(Config.Commands.setspeed, 'Definir velocidade do player', {{name='speed', help='fast/normal'}, {name='id', help='ID opcional'}}, true, function(source, args)
    P.HandleAction(source, { action = 'setspeed', target = tonumber(args[2]), speed = args[1] })
end, Config.ActionPerms.setspeed)

P.RegisterQbCommand(Config.Commands.setammo, 'Definir munição da arma atual', {{name='amount', help='Quantidade'}, {name='id', help='ID opcional'}}, true, function(source, args)
    P.HandleAction(source, { action = 'setammo', target = tonumber(args[2]), amount = tonumber(args[1]) })
end, Config.ActionPerms.setammo)

P.RegisterQbCommand(Config.Commands.givenuifocus, 'Setar NUI focus', {{name='id', help='ID do jogador'}, {name='focus', help='true/false'}, {name='mouse', help='true/false'}}, true, function(source, args)
    P.HandleAction(source, {
        action = 'givenuifocus',
        target = tonumber(args[1]),
        focus = tostring(args[2]) == 'true' or tostring(args[2]) == '1',
        mouse = tostring(args[3]) == 'true' or tostring(args[3]) == '1'
    })
end, Config.ActionPerms.givenuifocus)
