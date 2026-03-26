local P = MZ_STAFFPANEL
local QBCore = P.QBCore

P.State.wallWatchers = P.State.wallWatchers or {}

local function isStaffPlayer(src)
    if P.HasQBBypass(src) then
        return true
    end

    local role = P.GetHighestStaffRoleName and P.GetHighestStaffRoleName(src)
    return role and role ~= 'staff'
end

RegisterNetEvent('mz_staffpanel:server:setWallState', function(state)
    local src = source

    if not P.RequireAction(src, 'wall') then
        P.State.wallWatchers[src] = nil
        return
    end

    if state then
        P.State.wallWatchers[src] = true
    else
        P.State.wallWatchers[src] = nil
    end
end)

RegisterNetEvent('mz_staffpanel:server:setSpectateBucket', function(bucket)
    local src = source
    local st = P.State.adminSpectateState[src]
    if not st or not st.active then return end

    bucket = tonumber(bucket or 0) or 0
    SetPlayerRoutingBucket(src, bucket)
end)

RegisterNetEvent('mz_staffpanel:server:saveVehicleData', function(props, plate)
    local src = source

    if not P.RequireAction(src, 'saveVehicle') then
        return
    end

    plate = tostring(plate or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if plate == '' then
        return P.Notify(src, 'Placa inválida.', 'error')
    end

    local ok, err = pcall(function()
        MySQL.update.await(
            ('UPDATE `%s` SET `mods` = ? WHERE `plate` = ?'):format(Config.PlayerVehiclesTable),
            { json.encode(props or {}), plate }
        )
    end)

    if not ok then
        print('^1[mz_staffpanel] saveVehicleData error:^7 ' .. tostring(err))
        return P.Notify(src, 'Falha ao salvar veículo. Verifique a tabela player_vehicles.', 'error')
    end

    P.Notify(src, 'Veículo salvo com sucesso.', 'success')
    P.AddLog('vehicle', 'saveVehicle', src, nil, 'Salvou veículo pelo painel.', {
        plate = plate
    })
end)

CreateThread(function()
    while true do
        Wait((Config.Wall and Config.Wall.UpdateInterval) or 120)

        if next(P.State.wallWatchers) then
            local snapshot = {}

            for _, pid in ipairs(GetPlayers()) do
                pid = tonumber(pid)
                if pid and P.IsOnline(pid) then
                    local ped = GetPlayerPed(pid)
                    if ped and ped ~= 0 then
                        local coords = GetEntityCoords(ped)

                        snapshot[#snapshot + 1] = {
                            id = pid,
                            name = GetPlayerName(pid) or ('ID ' .. tostring(pid)),
                            x = coords.x,
                            y = coords.y,
                            z = coords.z,
                            bucket = GetPlayerRoutingBucket(pid) or 0,
                            staff = isStaffPlayer(pid)
                        }
                    end
                end
            end

            for watcher, enabled in pairs(P.State.wallWatchers) do
                if enabled and P.IsOnline(watcher) then
                    TriggerClientEvent(
                        'mz_staffpanel:client:updateWall',
                        watcher,
                        snapshot,
                        GetPlayerRoutingBucket(watcher) or 0
                    )
                else
                    P.State.wallWatchers[watcher] = nil
                end
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    P.State.wallWatchers[src] = nil
end)