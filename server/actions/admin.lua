local P = MZ_STAFFPANEL

P.RegisterAction('inventory', {
    requiredTarget = true,
    targetProtected = true,
}, function(ctx)
    if GetResourceState(Config.OpenInventoryResource) ~= 'started' then
        return P.Notify(ctx.src, 'qb-inventory não está iniciado.', 'error')
    end

    exports[Config.OpenInventoryResource]:OpenInventoryById(ctx.src, ctx.targetSrc)
    ctx.log('inventory', 'Abriu inventário do jogador.', { target = ctx.targetSrc })
end)

P.RegisterAction('cloth', {
    requiredTarget = true,
    targetProtected = true,
    permission = 'clothing',
}, function(ctx)
    TriggerClientEvent(Config.ClothingEvent, ctx.targetSrc)

    P.Notify(ctx.src, 'Menu de roupa aberto no player.', 'success')
    ctx.log('admin_action', 'Abriu menu de roupa do jogador.', { target = ctx.targetSrc })
end)