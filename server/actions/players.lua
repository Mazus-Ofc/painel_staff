local P = MZ_STAFFPANEL

local function addDailyStat(src, field, amount)
    local adminLicense = (P.GetStaffLicense and P.GetStaffLicense(src)) or P.GetIdentifierSafe(src, 'license') or '-'
    local adminName = GetPlayerName(src) or ('ID ' .. tostring(src))
    P.AddDailyStat(adminLicense, adminName, field, amount or 1)
end

P.RegisterAction('revive', {
    requiredTarget = true,
    targetProtected = true,
}, function(ctx)
    TriggerClientEvent('hospital:client:Revive', ctx.targetSrc)
    TriggerClientEvent('qb-ambulancejob:client:revive', ctx.targetSrc)

    P.Notify(ctx.src, ('Você reviveu ID %s.'):format(ctx.targetSrc), 'success')
    ctx.log('admin_action', 'Reviveu jogador.', { target = ctx.targetSrc })

    addDailyStat(ctx.src, 'revives_done', 1)
end)

P.RegisterAction('heal', {
    targetProtected = true,
}, function(ctx)
    local targetSrc = ctx.targetOrSelf

    TriggerClientEvent('mz_staffpanel:client:healPlayer', targetSrc)

    P.Notify(ctx.src, 'Heal aplicado.', 'success')
    ctx.log('admin_action', 'Aplicou heal.', { target = targetSrc })
end)

P.RegisterAction('kill', {
    requiredTarget = true,
    targetProtected = true,
}, function(ctx)
    TriggerClientEvent('mz_staffpanel:client:killPlayer', ctx.targetSrc)

    P.Notify(ctx.src, ('Você matou ID %s.'):format(ctx.targetSrc), 'success')
    ctx.log('admin_action', 'Matou jogador.', { target = ctx.targetSrc })
end)

P.RegisterAction('freeze', {
    requiredTarget = true,
    targetProtected = true,
}, function(ctx)
    local state = not P.State.frozenPlayers[ctx.targetSrc]
    P.State.frozenPlayers[ctx.targetSrc] = state

    TriggerClientEvent('mz_staffpanel:client:setFrozen', ctx.targetSrc, state)

    P.Notify(ctx.src, state and 'Jogador congelado.' or 'Jogador descongelado.', 'success')
    ctx.log('admin_action', state and 'Congelou jogador.' or 'Descongelou jogador.', {
        target = ctx.targetSrc,
        state = state
    })
end)

P.RegisterAction('gotoPlayer', {
    requiredTarget = true,
    targetProtected = true,
}, function(ctx)
    local ped = GetPlayerPed(ctx.targetSrc)
    if ped == 0 then
        return P.Notify(ctx.src, 'Ped do jogador não encontrado.', 'error')
    end

    local coords = GetEntityCoords(ped)

    TriggerClientEvent('mz_staffpanel:client:teleportToCoords', ctx.src, {
        x = coords.x,
        y = coords.y,
        z = coords.z + 1.0
    })

    P.Notify(ctx.src, ('Teleportado até ID %s.'):format(ctx.targetSrc), 'success')
    ctx.log('admin_action', 'Teleportou até jogador.', { target = ctx.targetSrc })

    addDailyStat(ctx.src, 'teleports_done', 1)
end)

P.RegisterAction('gotoCoords', {
    resolveTarget = false,
    permission = 'gotoPlayer',
}, function(ctx)
    local coords = ctx.payload.coords or ctx.payload
    local x = tonumber(coords and coords.x)
    local y = tonumber(coords and coords.y)
    local z = tonumber(coords and coords.z)

    if not x or not y or not z then
        return P.Notify(ctx.src, 'Coordenadas inválidas. Use X, Y e Z.', 'error')
    end

    TriggerClientEvent('mz_staffpanel:client:teleportToCoords', ctx.src, {
        x = x + 0.0,
        y = y + 0.0,
        z = z + 0.0
    })

    P.Notify(ctx.src, ('Teleportado para a localização: %.2f, %.2f, %.2f'):format(x, y, z), 'success')
    ctx.log('admin_action', 'Teleportou para coordenadas.', {
        coords = { x = x, y = y, z = z }
    })

    addDailyStat(ctx.src, 'teleports_done', 1)
end)

P.RegisterAction('bringPlayer', {
    requiredTarget = true,
    targetProtected = true,
}, function(ctx)
    local ped = GetPlayerPed(ctx.src)
    if ped == 0 then
        return P.Notify(ctx.src, 'Seu ped não foi encontrado.', 'error')
    end

    local coords = GetEntityCoords(ped)

    TriggerClientEvent('mz_staffpanel:client:teleportToCoords', ctx.targetSrc, {
        x = coords.x,
        y = coords.y,
        z = coords.z + 1.0
    })

    P.Notify(ctx.src, ('Você trouxe ID %s.'):format(ctx.targetSrc), 'success')
    ctx.log('admin_action', 'Trouxe jogador.', { target = ctx.targetSrc })

    addDailyStat(ctx.src, 'teleports_done', 1)
end)

P.RegisterAction('spectate', {
    requiredTarget = true,
    targetProtected = true,
}, function(ctx)
    local adminSrc = ctx.src
    local targetSrc = ctx.targetSrc

    if targetSrc == adminSrc then
        return P.Notify(adminSrc, 'Você não pode espectar você mesmo.', 'error')
    end

    if P.State.adminSpectateState[adminSrc] and P.State.adminSpectateState[adminSrc].target == targetSrc then
        P.StopSpectate(adminSrc, false)
        return
    end

    if P.State.adminSpectateState[adminSrc] then
        P.StopSpectate(adminSrc, true)
    end

    local returnCoords, returnHeading = P.GetPedCoordsHeading(adminSrc)
    if not returnCoords then
        return P.Notify(adminSrc, 'Não consegui capturar sua posição.', 'error')
    end

    P.State.adminSpectateState[adminSrc] = {
        active = true,
        target = targetSrc,
        returnCoords = returnCoords,
        returnHeading = returnHeading or 0.0,
        returnBucket = GetPlayerRoutingBucket(adminSrc) or 0
    }

    TriggerClientEvent('mz_staffpanel:client:startSpectate', adminSrc, targetSrc)

    P.Notify(adminSrc, ('Espectando ID %s. Use /%s para sair.'):format(targetSrc, Config.Commands.specoff), 'primary')
    ctx.log('admin_action', 'Iniciou spectate.', { target = targetSrc })

    addDailyStat(ctx.src, 'spectates_done', 1)
end)

P.RegisterAction('spectateStop', {
    resolveTarget = false,
    permission = 'spectate',
}, function(ctx)
    P.StopSpectate(ctx.src, false)
end)