local P = MZ_STAFFPANEL

local function registerAliases(primary, aliases, help, arguments, argsrequired, handler, perm)
    P.RegisterQbCommand(primary, help, arguments, argsrequired, handler, perm)
    for _, alias in ipairs(aliases or {}) do
        P.RegisterQbCommand(alias, help, arguments, argsrequired, handler, perm)
    end
end

registerAliases(Config.Commands.car, Config.Commands.carAliases, 'Gerar veículo por spawn', {{name='spawn', help='Nome do veículo'}}, true, function(source, args)
    P.HandleAction(source, { action = 'spawnVehicle', model = tostring(args[1] or ''):lower() })
end, Config.ActionPerms.spawnVehicle)

P.RegisterQbCommand(Config.Commands.dv, 'Deletar veículo atual ou próximo', {}, false, function(source)
    P.HandleAction(source, { action = 'deleteVehicle' })
end, Config.ActionPerms.deleteVehicle)

registerAliases(Config.Commands.savecar, Config.Commands.savecarAliases, 'Salvar veículo atual na garagem', {}, false, function(source)
    P.HandleAction(source, { action = 'saveVehicle' })
end, Config.ActionPerms.saveVehicle)

P.RegisterQbCommand(Config.Commands.maxmods, 'Aplicar maxmods no veículo atual', {}, false, function(source)
    P.HandleAction(source, { action = 'maxmods' })
end, Config.ActionPerms.maxmods)
