local P = MZ_STAFFPANEL

local function registerAliases(primary, aliases, help, arguments, argsrequired, handler, perm)
    P.RegisterQbCommand(primary, help, arguments, argsrequired, handler, perm)
    for _, alias in ipairs(aliases or {}) do
        P.RegisterQbCommand(alias, help, arguments, argsrequired, handler, perm)
    end
end

registerAliases(Config.Commands.panel, Config.Commands.panelAliases, 'Abrir painel da staff', {}, false, function(source)
    if not P.CanOpen(source) then return P.Notify(source, 'Sem permissão.', 'error') end
    TriggerClientEvent('mz_staffpanel:client:open', source)
end)
