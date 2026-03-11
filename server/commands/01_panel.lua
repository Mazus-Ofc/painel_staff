local P = MZ_STAFFPANEL

P.RegisterAliases(Config.Commands.panel, Config.Commands.panelAliases, 'Abrir painel da staff', {}, false, function(source)
    if not P.CanOpen(source) then return P.Notify(source, 'Sem permissão.', 'error') end
    TriggerClientEvent('mz_staffpanel:client:open', source)
end)
