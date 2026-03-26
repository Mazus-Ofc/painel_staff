local P = MZ_STAFFPANEL

P.RegisterAction('giveWeapon', {
    targetProtected = true,
}, function(ctx)
    local weaponName = tostring(ctx.payload.weapon or ''):upper()
    local ammo = tonumber(ctx.payload.ammo or 250) or 250
    local targetSrc = ctx.targetOrSelf

    if weaponName == '' then
        return P.Notify(ctx.src, 'Arma inválida.', 'error')
    end

    TriggerClientEvent('mz_staffpanel:client:giveWeapon', targetSrc, weaponName, ammo)

    P.Notify(ctx.src, ('Arma enviada: %s'):format(weaponName), 'success')
    ctx.log('weapon', 'Enviou arma.', {
        target = targetSrc,
        weapon = weaponName,
        ammo = ammo
    })
end)

P.RegisterAction('setmodel', {
    targetProtected = true,
}, function(ctx)
    local model = tostring(ctx.payload.model or '')
    local targetSrc = ctx.targetOrSelf

    if model == '' then
        return P.Notify(ctx.src, 'Modelo inválido.', 'error')
    end

    TriggerClientEvent('mz_staffpanel:client:setModel', targetSrc, model)
    ctx.log('dev', 'Alterou model.', { target = targetSrc, model = model })
end)

P.RegisterAction('setspeed', {
    targetProtected = true,
}, function(ctx)
    local speed = tostring(ctx.payload.speed or 'normal')
    local targetSrc = ctx.targetOrSelf

    TriggerClientEvent('mz_staffpanel:client:setSpeed', targetSrc, speed)
    ctx.log('dev', 'Alterou velocidade.', { target = targetSrc, speed = speed })
end)

P.RegisterAction('setammo', {
    targetProtected = true,
}, function(ctx)
    local amount = tonumber(ctx.payload.amount or 0) or 0
    local targetSrc = ctx.targetOrSelf

    TriggerClientEvent('mz_staffpanel:client:setAmmo', targetSrc, amount)
    ctx.log('weapon', 'Setou munição.', { target = targetSrc, amount = amount })
end)

P.RegisterAction('givenuifocus', {
    targetProtected = true,
}, function(ctx)
    local targetSrc = ctx.targetOrSelf
    local focus = ctx.payload.focus == true
    local mouse = ctx.payload.mouse == true

    TriggerClientEvent('mz_staffpanel:client:giveNuiFocus', targetSrc, focus, mouse)
    ctx.log('dev', 'Alterou NUI focus.', {
        target = targetSrc,
        focus = focus,
        mouse = mouse
    })
end)