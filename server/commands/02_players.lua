local P = MZ_STAFFPANEL

P.RegisterAliases(Config.Commands.revive, Config.Commands.reviveAliases, 'Reviver jogador', {{name='id', help='ID do jogador'}}, true, function(source, args)
    P.HandleAction(source, { action = 'revive', target = tonumber(args[1]) })
end, Config.ActionPerms.revive)

P.RegisterAliases(Config.Commands.heal, Config.Commands.healAliases, 'Curar jogador', {{name='id', help='ID do jogador (vazio = você)'}}, false, function(source, args)
    local target = tonumber(args[1]) or source
    P.HandleAction(source, { action = 'heal', target = target })
end, Config.ActionPerms.heal)

local function parseCoordArg(value)
    if value == nil then return nil end
    value = tostring(value):gsub(',', ''):gsub('%s+', '')
    if value == '' then return nil end
    return tonumber(value)
end

P.RegisterAliases(Config.Commands.gotoPlayer, Config.Commands.gotoPlayerAliases, 'Ir até jogador ou coordenada', {
    {name='id/x', help='ID do jogador ou X'},
    {name='y', help='Y da coordenada (opcional)'},
    {name='z', help='Z da coordenada (opcional)'}
}, true, function(source, args)
    local a1 = parseCoordArg(args[1])
    local a2 = parseCoordArg(args[2])
    local a3 = parseCoordArg(args[3])

    if a1 and a2 and a3 then
        return P.HandleAction(source, {
            action = 'gotoCoords',
            coords = { x = a1, y = a2, z = a3 }
        })
    end

    P.HandleAction(source, { action = 'gotoPlayer', target = a1 })
end, Config.ActionPerms.gotoPlayer)

P.RegisterAliases(Config.Commands.bringPlayer, Config.Commands.bringPlayerAliases, 'Trazer jogador', {{name='id', help='ID do jogador'}}, true, function(source, args)
    P.HandleAction(source, { action = 'bringPlayer', target = tonumber(args[1]) })
end, Config.ActionPerms.bringPlayer)

P.RegisterQbCommand(Config.Commands.freeze, 'Congelar jogador', {{name='id', help='ID do jogador'}}, true, function(source, args)
    P.HandleAction(source, { action = 'freeze', target = tonumber(args[1]) })
end, Config.ActionPerms.freeze)

P.RegisterAliases(Config.Commands.kill, Config.Commands.killAliases, 'Matar jogador', {{name='id', help='ID do jogador'}}, true, function(source, args)
    P.HandleAction(source, { action = 'kill', target = tonumber(args[1]) })
end, Config.ActionPerms.kill)

P.RegisterAliases(Config.Commands.kick, Config.Commands.kickAliases, 'Kickar jogador', {{name='id', help='ID do jogador'}, {name='motivo', help='Motivo'}}, true, function(source, args)
    local id = tonumber(args[1])
    table.remove(args, 1)
    P.HandleAction(source, { action = 'kick', target = id, reason = table.concat(args, ' ') })
end, Config.ActionPerms.kick)

P.RegisterAliases(Config.Commands.ban, Config.Commands.banAliases, 'Banir jogador', {{name='id', help='ID do jogador'}, {name='segundos', help='Tempo em segundos'}, {name='motivo', help='Motivo'}}, true, function(source, args)
    local id = tonumber(args[1])
    local seconds = tonumber(args[2]) or Config.DefaultBanSeconds
    table.remove(args, 1)
    table.remove(args, 1)
    P.HandleAction(source, { action = 'ban', target = id, seconds = seconds, reason = table.concat(args, ' ') })
end, Config.ActionPerms.ban)

P.RegisterAliases(Config.Commands.spectate, Config.Commands.spectateAliases, 'Spectar jogador', {{name='id', help='ID do jogador'}}, true, function(source, args)
    P.HandleAction(source, { action = 'spectate', target = tonumber(args[1]) })
end, Config.ActionPerms.spectate)

P.RegisterQbCommand(Config.Commands.specoff, 'Sair do spectate', {}, false, function(source)
    P.HandleAction(source, { action = 'spectateStop' })
end, Config.ActionPerms.spectate)

P.RegisterAliases(Config.Commands.intovehicle, Config.Commands.intovehicleAliases, 'Entrar no veículo do alvo', {{name='id', help='ID do jogador'}}, true, function(source, args)
    P.HandleAction(source, { action = 'intoVehicle', target = tonumber(args[1]) })
end, Config.ActionPerms.intoVehicle)

P.RegisterAliases(Config.Commands.inventory, Config.Commands.inventoryAliases, 'Abrir inventário do jogador', {{name='id', help='ID do jogador'}}, true, function(source, args)
    P.HandleAction(source, { action = 'inventory', target = tonumber(args[1]) })
end, Config.ActionPerms.inventory)

P.RegisterAliases(Config.Commands.cloth, Config.Commands.clothAliases, 'Abrir roupa do jogador', {{name='id', help='ID do jogador'}}, true, function(source, args)
    P.HandleAction(source, { action = 'cloth', target = tonumber(args[1]) })
end, Config.ActionPerms.clothing)

P.RegisterAliases(Config.Commands.giveweapon, {}, 'Dar arma para jogador', {{name='id', help='ID do jogador'}, {name='arma', help='WEAPON_XXX'}, {name='ammo', help='Munição'}}, true, function(source, args)
    local id = tonumber(args[1])
    local weapon = tostring(args[2] or '')
    local ammo = tonumber(args[3]) or 250
    P.HandleAction(source, { action = 'giveWeapon', target = id, weapon = weapon, ammo = ammo })
end, Config.ActionPerms.giveWeapon)
