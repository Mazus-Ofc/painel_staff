local QBCore = exports['qb-core']:GetCoreObject()

local uiOpen = false
local spectating = false
local spectateReturnCoords = nil
local showNames = false
local showBlips = false
local frozen = false
local invisible = false
local godmode = false
local showCoords = false
local playerBlips = {}
local spectateTargetSrc = 0
local spectateLastSync = nil
local savedSpectateState = { wasVisible = true }

local function sendUI(action, data)
    SendNUIMessage({ action = action, data = data })
end

local function setUI(state)
    uiOpen = state
    SetNuiFocus(state, state)
    sendUI('visible', state)
    if state then
        QBCore.Functions.TriggerCallback('mz_staffpanel:server:getData', function(data)
            if data and data.ok then sendUI('hydrate', data) end
        end)
    end
end

local function openSupportChat(reportId)
    uiOpen = true
    SetNuiFocus(true, true)
    sendUI('visible', true)
    sendUI('supportOnly', true)
    sendUI('supportOpen', { reportId = tonumber(reportId or 0) or 0, role = 'player' })
end

RegisterNetEvent('mz_staffpanel:client:open', function()
    QBCore.Functions.TriggerCallback('mz_staffpanel:server:canOpen', function(canOpen)
        if canOpen then setUI(true) end
    end)
end)

RegisterNetEvent('mz_staffpanel:client:openSupportChat', function(payload)
    payload = type(payload) == 'table' and payload or {}
    openSupportChat(payload.reportId or 0)
end)

RegisterNUICallback('close', function(_, cb)
    setUI(false)
    cb('ok')
end)

RegisterNUICallback('getStaffDutyData', function(_, cb)
    QBCore.Functions.TriggerCallback('mz_staffpanel:server:getStaffDutyData', function(resp)
        cb(resp or { ok = false })
    end)
end)

RegisterNUICallback('setDutyState', function(data, cb)
    TriggerServerEvent('mz_staffpanel:server:setDutyState', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('refresh', function(_, cb)
    QBCore.Functions.TriggerCallback('mz_staffpanel:server:getData', function(data)
        sendUI('hydrate', data)
        cb(data)
    end)
end)

RegisterNUICallback('action', function(data, cb)
    TriggerServerEvent('mz_staffpanel:server:performAction', data)
    cb('ok')
end)


RegisterNUICallback('getLogsPage', function(data, cb)
    QBCore.Functions.TriggerCallback('mz_staffpanel:server:getLogsPage', function(resp)
        cb(resp or { ok = false })
    end, tonumber((data or {}).page or 1) or 1, tonumber((data or {}).pageSize or 20) or 20, (data or {}).filters or {})
end)

RegisterNUICallback('getBansPage', function(data, cb)
    QBCore.Functions.TriggerCallback('mz_staffpanel:server:getBansPage', function(resp)
        cb(resp or { ok = false })
    end, tonumber((data or {}).page or 1) or 1, tonumber((data or {}).pageSize or 15) or 15, (data or {}).filters or {})
end)


RegisterNUICallback('supportFetch', function(data, cb)
    QBCore.Functions.TriggerCallback('mz_staffpanel:server:getSupportSession', function(session)
        cb(session or { ok = false })
    end, tonumber((data or {}).reportId or 0) or 0)
end)

RegisterNUICallback('supportSend', function(data, cb)
    TriggerServerEvent('mz_staffpanel:server:supportSend', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('supportCloseReport', function(data, cb)
    TriggerServerEvent('mz_staffpanel:server:supportClose', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('supportAcceptReport', function(data, cb)
    TriggerServerEvent('mz_staffpanel:server:supportAccept', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('supportReopenReport', function(data, cb)
    TriggerServerEvent('mz_staffpanel:server:supportReopen', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('supportUpdateMeta', function(data, cb)
    TriggerServerEvent('mz_staffpanel:server:supportSetMeta', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('getStaffManageData', function(data, cb)
    QBCore.Functions.TriggerCallback('mz_staffpanel:server:getStaffManageData', function(resp)
        cb(resp or { ok = false })
    end, tonumber((data or {}).target or 0) or 0)
end)

RegisterNUICallback('manageStaffRole', function(data, cb)
    TriggerServerEvent('mz_staffpanel:server:manageStaffRole', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('clearStaffRoles', function(data, cb)
    TriggerServerEvent('mz_staffpanel:server:clearStaffRoles', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('getPlayerAdminHistory', function(data, cb)
    QBCore.Functions.TriggerCallback('mz_staffpanel:server:getPlayerAdminHistory', function(resp)
        cb(resp or { ok = false })
    end, tonumber((data or {}).target or 0) or 0)
end)

RegisterNetEvent('mz_staffpanel:client:teleportToCoords', function(coords)
    SetEntityCoords(PlayerPedId(), coords.x + 0.0, coords.y + 0.0, coords.z + 0.0, false, false, false, false)
end)

RegisterNetEvent('mz_staffpanel:client:killPlayer', function()
    SetEntityHealth(PlayerPedId(), 0)
end)

RegisterNetEvent('mz_staffpanel:client:healPlayer', function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
    ResetPedVisibleDamage(ped)
    QBCore.Functions.Notify('Você foi curado pela staff.', 'success')
end)

RegisterNetEvent('mz_staffpanel:client:setFrozen', function(state)
    frozen = state
    FreezeEntityPosition(PlayerPedId(), state)
    QBCore.Functions.Notify(state and 'Você foi congelado pela staff.' or 'Você foi descongelado.', state and 'error' or 'success')
end)

local function setSpectatePedState(isSpec)
    local ped = PlayerPedId()
    if isSpec then
        savedSpectateState.wasVisible = IsEntityVisible(ped)
        SetEntityVisible(ped, false, false)
        SetEntityInvincible(ped, true)
        FreezeEntityPosition(ped, true)
        SetEntityCollision(ped, false, false)
        if IsPedInAnyVehicle(ped, false) then
            TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 16)
        end
    else
        NetworkSetInSpectatorMode(false, ped)
        SetEntityVisible(ped, not invisible and (savedSpectateState.wasVisible ~= false), false)
        SetEntityInvincible(ped, godmode)
        FreezeEntityPosition(ped, frozen)
        SetEntityCollision(ped, true, true)
        NetworkSetEntityInvisibleToNetwork(ped, invisible)
    end
end

local function stickNearSpectateTarget(coords, heading)
    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, coords.x, coords.y - 6.0, coords.z + 1.0, false, false, false)
    SetEntityHeading(ped, heading or 0.0)
end

RegisterNetEvent('mz_staffpanel:client:startSpectate', function(targetSrc)
    targetSrc = tonumber(targetSrc or 0) or 0
    if targetSrc <= 0 then return end

    spectating = true
    spectateTargetSrc = targetSrc
    spectateLastSync = nil
    spectateReturnCoords = GetEntityCoords(PlayerPedId())
    setSpectatePedState(true)
    NetworkSetEntityInvisibleToNetwork(PlayerPedId(), true)

    CreateThread(function()
        while spectating do
            TriggerServerEvent('mz_staffpanel:server:spectateTick')
            Wait(250)
            if not spectating then break end

            if spectateLastSync and spectateLastSync.src == spectateTargetSrc then
                TriggerServerEvent('mz_staffpanel:server:setSpectateBucket', spectateLastSync.bucket)
                stickNearSpectateTarget(spectateLastSync.coords, spectateLastSync.heading)

                local tId = GetPlayerFromServerId(spectateTargetSrc)
                if tId ~= -1 then
                    local tPed = GetPlayerPed(tId)
                    if DoesEntityExist(tPed) then
                        NetworkSetInSpectatorMode(true, tPed)
                    end
                end

                DisableControlAction(0, 24, true)
                DisableControlAction(0, 25, true)
                DisableControlAction(0, 23, true)
                DisableControlAction(0, 75, true)
                DisableControlAction(0, 200, true)
            end
        end
    end)
end)

RegisterNetEvent('mz_staffpanel:client:syncSpectateTarget', function(payload)
    spectateLastSync = payload
end)

RegisterNetEvent('mz_staffpanel:client:stopSpectate', function(returnCoords, returnHeading, silent)
    if not spectating then return end

    spectating = false
    spectateTargetSrc = 0
    spectateLastSync = nil
    setSpectatePedState(false)

    local ped = PlayerPedId()
    if returnCoords and returnCoords.x then
        SetEntityCoordsNoOffset(ped, returnCoords.x, returnCoords.y, returnCoords.z, false, false, false)
        SetEntityHeading(ped, returnHeading or 0.0)
    elseif spectateReturnCoords then
        SetEntityCoords(ped, spectateReturnCoords.x, spectateReturnCoords.y, spectateReturnCoords.z, false, false, false, false)
    end

    spectateReturnCoords = nil

    if not silent then
        QBCore.Functions.Notify('Spectate desativado.', 'primary')
    end
end)

RegisterNetEvent('mz_staffpanel:client:toggleNames', function()
    showNames = not showNames
    QBCore.Functions.Notify(showNames and 'Nomes ativados.' or 'Nomes desativados.', showNames and 'success' or 'primary')
end)

RegisterNetEvent('mz_staffpanel:client:toggleBlips', function()
    showBlips = not showBlips
    if not showBlips then
        for _, blip in pairs(playerBlips) do
            if DoesBlipExist(blip) then RemoveBlip(blip) end
        end
        playerBlips = {}
    end
    QBCore.Functions.Notify(showBlips and 'Blips ativados.' or 'Blips desativados.', showBlips and 'success' or 'primary')
end)

RegisterNetEvent('mz_staffpanel:client:toggleInvisible', function()
    invisible = not invisible
    local ped = PlayerPedId()
    SetEntityVisible(ped, not invisible, false)
    NetworkSetEntityInvisibleToNetwork(ped, invisible)
    if invisible then
        SetEntityAlpha(ped, 120, false)
    else
        ResetEntityAlpha(ped)
    end
    QBCore.Functions.Notify(invisible and 'Invisibilidade ativada.' or 'Invisibilidade desativada.', invisible and 'success' or 'primary')
end)

RegisterNetEvent('mz_staffpanel:client:toggleGod', function()
    godmode = not godmode
    local ped = PlayerPedId()
    SetPlayerInvincible(PlayerId(), godmode)
    SetEntityInvincible(ped, godmode)
    SetPedCanRagdoll(ped, not godmode)
    QBCore.Functions.Notify(godmode and 'Godmode ativado.' or 'Godmode desativado.', godmode and 'success' or 'primary')
end)

local function draw2DText(content, font, colour, scale, x, y)
    SetTextFont(font)
    SetTextScale(scale, scale)
    SetTextColour(colour[1], colour[2], colour[3], 255)
    BeginTextCommandDisplayText('STRING')
    SetTextDropShadow()
    SetTextOutline()
    AddTextComponentSubstringPlayerName(content)
    EndTextCommandDisplayText(x, y)
end

RegisterNetEvent('mz_staffpanel:client:toggleCoords', function()
    showCoords = not showCoords
    QBCore.Functions.Notify(showCoords and 'Coords ativadas.' or 'Coords desativadas.', showCoords and 'success' or 'primary')
end)

local function copyToClipboard(dataType)
    local coords = GetEntityCoords(PlayerPedId())
    local heading = QBCore.Shared.Round(GetEntityHeading(PlayerPedId()), 2)
    local x, y, z = QBCore.Shared.Round(coords.x, 2), QBCore.Shared.Round(coords.y, 2), QBCore.Shared.Round(coords.z, 2)
    local str = ''

    if dataType == 'coords2' then str = ('vector2(%s, %s)'):format(x, y) end
    if dataType == 'coords3' then str = ('vector3(%s, %s, %s)'):format(x, y, z) end
    if dataType == 'coords4' then str = ('vector4(%s, %s, %s, %s)'):format(x, y, z, heading) end
    if dataType == 'heading' then str = tostring(heading) end

    SendNUIMessage({ action = 'copy', data = str })
    QBCore.Functions.Notify('Copiado para área de transferência.', 'success')
end

RegisterNetEvent('mz_staffpanel:client:copyToClipboard', copyToClipboard)

RegisterNetEvent('mz_staffpanel:client:spawnVehicle', function(model)
    local mHash = joaat(model)
    RequestModel(mHash)
    while not HasModelLoaded(mHash) do Wait(0) end
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local vehicle = CreateVehicle(mHash, coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
    SetVehicleOnGroundProperly(vehicle)
    SetPedIntoVehicle(ped, vehicle, -1)
    SetModelAsNoLongerNeeded(mHash)
end)

RegisterNetEvent('mz_staffpanel:client:deleteVehicle', function()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle ~= 0 then
        SetEntityAsMissionEntity(vehicle, true, true)
        DeleteVehicle(vehicle)
    else
        local coords = GetEntityCoords(ped)
        vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 6.0, 0, 71)
        if vehicle ~= 0 then
            SetEntityAsMissionEntity(vehicle, true, true)
            DeleteVehicle(vehicle)
        end
    end
end)

RegisterNetEvent('mz_staffpanel:client:maxmodVehicle', function()
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh == 0 then
        QBCore.Functions.Notify('Você precisa estar em um veículo.', 'error')
        return
    end

    SetVehicleModKit(veh, 0)
    for i = 0, 48 do
        local modCount = GetNumVehicleMods(veh, i)
        if modCount and modCount > 0 then
            SetVehicleMod(veh, i, modCount - 1, false)
        end
    end
    ToggleVehicleMod(veh, 18, true)
    SetVehicleTyresCanBurst(veh, false)
    SetVehicleFixed(veh)
    SetVehicleDeformationFixed(veh)
    SetVehicleDirtLevel(veh, 0.0)
end)

RegisterNetEvent('mz_staffpanel:client:requestSaveVehicle', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        QBCore.Functions.Notify('Entre em um veículo para salvá-lo.', 'error')
        return
    end
    local plate = QBCore.Functions.GetPlate(veh)
    local props = QBCore.Functions.GetVehicleProperties(veh)
    TriggerServerEvent('mz_staffpanel:server:saveVehicleData', props, plate)
end)

RegisterNetEvent('mz_staffpanel:client:giveWeapon', function(weaponName, ammo)
    local ped = PlayerPedId()
    local weaponHash = joaat(weaponName)
    GiveWeaponToPed(ped, weaponHash, tonumber(ammo or 250) or 250, false, true)
end)

RegisterNetEvent('mz_staffpanel:client:setModel', function(model)
    local modelHash = tonumber(model) or joaat(model)
    if not IsModelInCdimage(modelHash) or not IsModelValid(modelHash) then
        QBCore.Functions.Notify('Modelo inválido.', 'error')
        return
    end

    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do Wait(0) end

    SetPlayerModel(PlayerId(), modelHash)
    SetModelAsNoLongerNeeded(modelHash)
end)

RegisterNetEvent('mz_staffpanel:client:setSpeed', function(speed)
    local ped = PlayerPedId()
    local mult = 1.0
    speed = tostring(speed or 'normal'):lower()

    if speed == 'super' then mult = 1.2 end
    if speed == 'flash' then mult = 1.49 end
    if speed == 'normal' then mult = 1.0 end

    SetRunSprintMultiplierForPlayer(PlayerId(), mult)
    QBCore.Functions.Notify(('Velocidade ajustada: %s'):format(speed), 'success')
end)

RegisterNetEvent('mz_staffpanel:client:setAmmo', function(amount)
    amount = tonumber(amount or 0) or 0
    local ped = PlayerPedId()
    local weapon = GetSelectedPedWeapon(ped)
    if weapon == 0 then
        QBCore.Functions.Notify('Você precisa estar com uma arma em mãos.', 'error')
        return
    end
    SetPedAmmo(ped, weapon, amount)
    QBCore.Functions.Notify(('Munição ajustada: %d'):format(amount), 'success')
end)

RegisterNetEvent('mz_staffpanel:client:giveNuiFocus', function(focus, mouse)
    SetNuiFocus(focus == true, mouse == true)
end)

CreateThread(function()
    while true do
        Wait(0)

        if showCoords then
            local c = GetEntityCoords(PlayerPedId())
            local h = GetEntityHeading(PlayerPedId())
            draw2DText(
                ('~w~X: ~p~%.2f  ~w~Y: ~p~%.2f  ~w~Z: ~p~%.2f  ~w~H: ~p~%.2f'):format(c.x, c.y, c.z, h),
                4,
                { 255, 255, 255 },
                0.35,
                0.015,
                0.80
            )
        end

        if showNames then
            for _, player in ipairs(GetActivePlayers()) do
                local ped = GetPlayerPed(player)
                if ped ~= PlayerPedId() then
                    local myCoords = GetEntityCoords(PlayerPedId())
                    local coords = GetEntityCoords(ped)
                    local dist = #(myCoords - coords)
                    if dist < 30.0 then
                        local onScreen, x, y = World3dToScreen2d(coords.x, coords.y, coords.z + 1.1)
                        if onScreen then
                            local sid = GetPlayerServerId(player)
                            local hp = GetEntityHealth(ped)
                            draw2DText(('[%d] %s | HP %d'):format(sid, GetPlayerName(player), hp), 4, {255,255,255}, 0.30, x, y)
                        end
                    end
                end
            end
        end

        if showBlips then
            for _, player in ipairs(GetActivePlayers()) do
                local sid = GetPlayerServerId(player)
                if player ~= PlayerId() then
                    if not playerBlips[sid] or not DoesBlipExist(playerBlips[sid]) then
                        local blip = AddBlipForEntity(GetPlayerPed(player))
                        SetBlipSprite(blip, 1)
                        SetBlipColour(blip, 0)
                        SetBlipScale(blip, 0.75)
                        SetBlipAsShortRange(blip, false)
                        BeginTextCommandSetBlipName('STRING')
                        AddTextComponentString(('[%d] %s'):format(sid, GetPlayerName(player)))
                        EndTextCommandSetBlipName(blip)
                        playerBlips[sid] = blip
                    else
                        SetBlipCoords(playerBlips[sid], GetEntityCoords(GetPlayerPed(player)))
                    end
                end
            end
        end
    end
end)

RegisterCommand('reports', function()
    openSupportChat(0)
end)