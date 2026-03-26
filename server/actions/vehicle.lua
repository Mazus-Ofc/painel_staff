local P = MZ_STAFFPANEL

P.RegisterAction('spawnVehicle', {
    resolveTarget = false,
}, function(ctx)
    local model = tostring(ctx.payload.model or ''):lower()
    if model == '' then
        return P.Notify(ctx.src, 'Modelo inválido.', 'error')
    end

    TriggerClientEvent('mz_staffpanel:client:spawnVehicle', ctx.src, model)
    ctx.log('vehicle', 'Spawnou veículo.', { model = model })
end)

P.RegisterAction('deleteVehicle', {
    resolveTarget = false,
}, function(ctx)
    TriggerClientEvent('mz_staffpanel:client:deleteVehicle', ctx.src)
    ctx.log('vehicle', 'Deletou veículo.', {})
end)

P.RegisterAction('saveVehicle', {
    resolveTarget = false,
}, function(ctx)
    TriggerClientEvent('mz_staffpanel:client:requestSaveVehicle', ctx.src)
    ctx.log('vehicle', 'Solicitou salvar veículo.', {})
end)

P.RegisterAction('maxmods', {
    resolveTarget = false,
}, function(ctx)
    TriggerClientEvent('mz_staffpanel:client:maxmodVehicle', ctx.src)
    ctx.log('vehicle', 'Aplicou maxmods.', {})
end)

P.RegisterAction('intoVehicle', {
    requiredTarget = true,
    targetProtected = true,
}, function(ctx)
    local adminPed = GetPlayerPed(ctx.src)
    local targetPed = GetPlayerPed(ctx.targetSrc)
    local vehicle = GetVehiclePedIsIn(targetPed, false)
    local seat = -1

    if vehicle == 0 then
        return P.Notify(ctx.src, 'O jogador não está em veículo.', 'error')
    end

    for i = -1, GetVehicleMaxNumberOfPassengers(vehicle) - 1 do
        if GetPedInVehicleSeat(vehicle, i) == 0 then
            seat = i
            break
        end
    end

    if seat == -1 then
        return P.Notify(ctx.src, 'Sem assento livre no veículo.', 'error')
    end

    SetPedIntoVehicle(adminPed, vehicle, seat)

    P.Notify(ctx.src, 'Você entrou no veículo do player.', 'success')
    ctx.log('admin_action', 'Entrou no veículo do jogador.', { target = ctx.targetSrc })
end)