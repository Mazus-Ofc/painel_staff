local P = MZ_STAFFPANEL

P.RegisterAliases(Config.Commands.noclip, Config.Commands.noclipAliases, 'Alternar noclip', {}, false, function(source)
    P.HandleAction(source, { action = 'noclip' })
end, Config.ActionPerms.noclip)

P.RegisterAliases(Config.Commands.invisible, Config.Commands.invisibleAliases, 'Alternar invisibilidade', {}, false, function(source)
    P.HandleAction(source, { action = 'invisible' })
end, Config.ActionPerms.invisible)

P.RegisterAliases(Config.Commands.god, Config.Commands.godAliases, 'Alternar godmode', {}, false, function(source)
    P.HandleAction(source, { action = 'god' })
end, Config.ActionPerms.god)

P.RegisterAliases(Config.Commands.names, Config.Commands.namesAliases, 'Alternar nomes', {}, false, function(source)
    P.HandleAction(source, { action = 'names' })
end, Config.ActionPerms.names)

P.RegisterAliases(Config.Commands.blips, Config.Commands.blipsAliases, 'Alternar blips', {}, false, function(source)
    P.HandleAction(source, { action = 'blips' })
end, Config.ActionPerms.blips)

P.RegisterAliases(Config.Commands.wall, Config.Commands.wallAliases, 'Alternar wall', {}, false, function(source)
    P.HandleAction(source, { action = 'wall' })
end, Config.ActionPerms.wall)