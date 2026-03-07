local P = MZ_STAFFPANEL

local function registerAliases(primary, aliases, help, arguments, argsrequired, handler, perm)
    P.RegisterQbCommand(primary, help, arguments, argsrequired, handler, perm)
    for _, alias in ipairs(aliases or {}) do
        P.RegisterQbCommand(alias, help, arguments, argsrequired, handler, perm)
    end
end

registerAliases(Config.Commands.noclip, Config.Commands.noclipAliases, 'Alternar noclip', {}, false, function(source)
    P.HandleAction(source, { action = 'noclip' })
end, Config.ActionPerms.noclip)

registerAliases(Config.Commands.invisible, Config.Commands.invisibleAliases, 'Alternar invisibilidade', {}, false, function(source)
    P.HandleAction(source, { action = 'invisible' })
end, Config.ActionPerms.invisible)

registerAliases(Config.Commands.god, Config.Commands.godAliases, 'Alternar godmode', {}, false, function(source)
    P.HandleAction(source, { action = 'god' })
end, Config.ActionPerms.god)

registerAliases(Config.Commands.names, Config.Commands.namesAliases, 'Alternar nomes', {}, false, function(source)
    P.HandleAction(source, { action = 'names' })
end, Config.ActionPerms.names)

registerAliases(Config.Commands.blips, Config.Commands.blipsAliases, 'Alternar blips', {}, false, function(source)
    P.HandleAction(source, { action = 'blips' })
end, Config.ActionPerms.blips)

registerAliases(Config.Commands.wall, Config.Commands.wallAliases, 'Alternar wall', {}, false, function(source)
    P.HandleAction(source, { action = 'wall' })
end, Config.ActionPerms.wall)
