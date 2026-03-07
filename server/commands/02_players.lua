local P = MZ_STAFFPANEL

local function registerAliases(primary, aliases, help, arguments, argsrequired, handler, perm)
    P.RegisterQbCommand(primary, help, arguments, argsrequired, handler, perm)
    for _, alias in ipairs(aliases or {}) do
        P.RegisterQbCommand(alias, help, arguments, argsrequired, handler, perm)
    end
end

registerAliases(Config.Commands.revive, Config.Commands.reviveAliases, 'Reviver jogador', {{name='id', help='ID do jogador'}}, true, function(source, args)
    P.HandleAction(source, { action = 'revive', target = tonumber(args[1]) })
end, Config.ActionPerms.revive)

registerAliases(Config.Commands.heal, Config.Commands.healAliases, 'Curar jogador', {{name='id', help='ID do jogador (vazio = você)'}}, false, function(source, args)
    local target = tonumber(args[1]) or source
    P.HandleAction(source, { action = 'heal', target = target })
end, Config.ActionPerms.heal)

registerAliases(Config.Commands.gotoPlayer, Config.Commands.gotoPlayerAliases, 'Ir até jogador', {{name='id', help='ID do jogador'}}, true, function(source, args)
    P.HandleAction(source, { action = 'gotoPlayer', target = tonumber(args[1]) })
end, Config.ActionPerms.gotoPlayer)

registerAliases(Config.Commands.bringPlayer, Config.Commands.bringPlayerAliases, 'Trazer jogador', {{name='id', help='ID do jogador'}}, true, function(source, args)
    P.HandleAction(source, { action = 'bringPlayer', target = tonumber(args[1]) })
end, Config.ActionPerms.bringPlayer)

P.RegisterQbCommand(Config.Commands.freeze, 'Congelar jogador', {{name='id', help='ID do jogador'}}, true, function(source, args)
    P.HandleAction(source, { action = 'freeze', target = tonumber(args[1]) })
end, Config.ActionPerms.freeze)

registerAliases(Config.Commands.kill, Config.Commands.killAliases, 'Matar jogador', {{name='id', help='ID do jogador'}}, true, function(source, args)
    P.HandleAction(source, { action = 'kill', target = tonumber(args[1]) })
end, Config.ActionPerms.kill)

registerAliases(Config.Commands.kick, Config.Commands.kickAliases, 'Kickar jogador', {{name='id', help='ID do jogador'}, {name='motivo', help='Motivo'}}, true, function(source, args)
    local id = tonumber(args[1])
    table.remove(args, 1)
    P.HandleAction(source, { action = 'kick', target = id, reason = table.concat(args, ' ') })
end, Config.ActionPerms.kick)

registerAliases(Config.Commands.ban, Config.Commands.banAliases, 'Banir jogador', {{name='id', help='ID do jogador'}, {name='segundos', help='Tempo em segundos'}, {name='motivo', help='Motivo'}}, true, function(source, args)
    local id = tonumber(args[1])
    local seconds = tonumber(args[2]) or Config.DefaultBanSeconds
    table.remove(args, 1)
    table.remove(args, 1)
    P.HandleAction(source, { action = 'ban', target = id, seconds = seconds, reason = table.concat(args, ' ') })
end, Config.ActionPerms.ban)

registerAliases(Config.Commands.spectate, Config.Commands.spectateAliases, 'Spectar jogador', {{name='id', help='ID do jogador'}}, true, function(source, args)
    P.HandleAction(source, { action = 'spectate', target = tonumber(args[1]) })
end, Config.ActionPerms.spectate)

P.RegisterQbCommand(Config.Commands.specoff, 'Sair do spectate', {}, false, function(source)
    P.HandleAction(source, { action = 'spectateStop' })
end, Config.ActionPerms.spectate)

registerAliases(Config.Commands.intovehicle, Config.Commands.intovehicleAliases, 'Entrar no veículo do alvo', {{name='id', help='ID do jogador'}}, true, function(source, args)
    P.HandleAction(source, { action = 'intoVehicle', target = tonumber(args[1]) })
end, Config.ActionPerms.intoVehicle)

registerAliases(Config.Commands.inventory, Config.Commands.inventoryAliases, 'Abrir inventário do jogador', {{name='id', help='ID do jogador'}}, true, function(source, args)
    P.HandleAction(source, { action = 'inventory', target = tonumber(args[1]) })
end, Config.ActionPerms.inventory)

registerAliases(Config.Commands.cloth, Config.Commands.clothAliases, 'Abrir roupa do jogador', {{name='id', help='ID do jogador'}}, true, function(source, args)
    P.HandleAction(source, { action = 'cloth', target = tonumber(args[1]) })
end, Config.ActionPerms.clothing)

registerAliases(Config.Commands.giveweapon, {}, 'Dar arma para jogador', {{name='id', help='ID do jogador'}, {name='arma', help='WEAPON_XXX'}, {name='ammo', help='Munição'}}, true, function(source, args)
    local id = tonumber(args[1])
    local weapon = tostring(args[2] or '')
    local ammo = tonumber(args[3]) or 250
    P.HandleAction(source, { action = 'giveWeapon', target = id, weapon = weapon, ammo = ammo })
end, Config.ActionPerms.giveWeapon)
