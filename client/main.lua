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

RegisterNetEvent('mz_staffpanel:client:open', function()
    QBCore.Functions.TriggerCallback('mz_staffpanel:server:canOpen', function(canOpen)
        if canOpen then setUI(true) end
    end)
end)

RegisterNUICallback('close', function(_, cb) setUI(false) cb('ok') end)
RegisterNUICallback('refresh', function(_, cb)
    QBCore.Functions.TriggerCallback('mz_staffpanel:server:getData', function(data)
        sendUI('hydrate', data)
        cb(data)
    end)
end)
RegisterNUICallback('action', function(data, cb) TriggerServerEvent('mz_staffpanel:server:performAction', data) cb('ok') end)

RegisterNetEvent('mz_staffpanel:client:teleportToCoords', function(coords)
    SetEntityCoords(PlayerPedId(), coords.x + 0.0, coords.y + 0.0, coords.z + 0.0, false, false, false, false)
end)

RegisterNetEvent('mz_staffpanel:client:killPlayer', function() SetEntityHealth(PlayerPedId(), 0) end)
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
        if IsPedInAnyVehicle(ped, false) then TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 16) end
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
                    if DoesEntityExist(tPed) then NetworkSetInSpectatorMode(true, tPed) end
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

RegisterNetEvent('mz_staffpanel:client:syncSpectateTarget', function(payload) spectateLastSync = payload end)
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
    if not silent then QBCore.Functions.Notify('Spectate desativado.', 'primary') end
end)

RegisterNetEvent('mz_staffpanel:client:toggleNames', function()
    showNames = not showNames
    QBCore.Functions.Notify(showNames and 'Nomes ativados.' or 'Nomes desativados.', showNames and 'success' or 'primary')
end)
RegisterNetEvent('mz_staffpanel:client:toggleBlips', function()
    showBlips = not showBlips
    if not showBlips then
        for _, blip in pairs(playerBlips) do if DoesBlipExist(blip) then RemoveBlip(blip) end end
        playerBlips = {}
    end
    QBCore.Functions.Notify(showBlips and 'Blips ativados.' or 'Blips desativados.', showBlips and 'success' or 'primary')
end)
RegisterNetEvent('mz_staffpanel:client:toggleInvisible', function()
    invisible = not invisible
    local ped = PlayerPedId()
    SetEntityVisible(ped, not invisible, false)
    NetworkSetEntityInvisibleToNetwork(ped, invisible)
    if invisible then SetEntityAlpha(ped, 120, false) else ResetEntityAlpha(ped) end
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
    if str ~= '' then
        SendNUIMessage({ action = 'clipboard', data = str })
        QBCore.Functions.Notify('Copiado para a área de transferência.', 'success')
    end
end

RegisterNetEvent('mz_staffpanel:client:copyToClipboard', function(dataType) copyToClipboard(dataType) end)
RegisterNetEvent('mz_staffpanel:client:giveWeapon', function(weaponName, ammo)
    local hash = joaat(tostring(weaponName or ''):upper())
    ammo = tonumber(ammo or 250) or 250
    GiveWeaponToPed(PlayerPedId(), hash, ammo, false, true)
    SetPedAmmo(PlayerPedId(), hash, ammo)
end)

local blockedPeds = { mp_m_freemode_01 = true, mp_f_freemode_01 = true }
local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 8000
    while not HasModelLoaded(hash) do
        Wait(10)
        if GetGameTimer() > timeout then return nil end
    end
    return hash
end

RegisterNetEvent('mz_staffpanel:client:setModel', function(model)
    local hash = loadModel(model)
    if not hash then return QBCore.Functions.Notify('Modelo inválido.', 'error') end
    local ped = PlayerPedId()
    SetEntityInvincible(ped, true)
    SetPlayerModel(PlayerId(), hash)
    if not blockedPeds[tostring(model)] then SetPedRandomComponentVariation(PlayerPedId(), true) end
    SetModelAsNoLongerNeeded(hash)
    SetEntityInvincible(PlayerPedId(), godmode)
    QBCore.Functions.Notify(('Modelo alterado para %s.'):format(model), 'success')
end)
RegisterNetEvent('mz_staffpanel:client:setSpeed', function(speed)
    local player = PlayerId()
    if tostring(speed) == 'fast' then
        SetRunSprintMultiplierForPlayer(player, 1.49)
        SetSwimMultiplierForPlayer(player, 1.49)
        QBCore.Functions.Notify('Velocidade rápida ativada.', 'success')
    else
        SetRunSprintMultiplierForPlayer(player, 1.0)
        SetSwimMultiplierForPlayer(player, 1.0)
        QBCore.Functions.Notify('Velocidade normal restaurada.', 'primary')
    end
end)
RegisterNetEvent('mz_staffpanel:client:setAmmo', function(amount)
    local weapon = GetSelectedPedWeapon(PlayerPedId())
    amount = tonumber(amount or 0) or 0
    if weapon and weapon ~= 0 then
        SetPedAmmo(PlayerPedId(), weapon, amount)
        QBCore.Functions.Notify(('Munição definida para %d.'):format(amount), 'success')
    end
end)
RegisterNetEvent('mz_staffpanel:client:giveNuiFocus', function(focus, mouse) SetNuiFocus(focus == true, mouse == true) end)
RegisterNetEvent('mz_staffpanel:client:requestSaveVehicle', function()
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh == 0 then return QBCore.Functions.Notify('Você não está em um veículo.', 'error') end
    TriggerServerEvent('mz_staffpanel:server:saveVehicleData', QBCore.Functions.GetVehicleProperties(veh), QBCore.Functions.GetPlate(veh))
end)
RegisterNetEvent('mz_staffpanel:client:maxmodVehicle', function()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if vehicle == 0 then return QBCore.Functions.Notify('Você não está em veículo.', 'error') end
    local mods = {11,12,13,15,16}
    SetVehicleModKit(vehicle, 0)
    for _, modType in ipairs(mods) do SetVehicleMod(vehicle, modType, GetNumVehicleMods(vehicle, modType) - 1, false) end
    ToggleVehicleMod(vehicle, 18, true)
    SetVehicleFixed(vehicle)
    QBCore.Functions.Notify('Maxmods aplicados.', 'success')
end)

CreateThread(function()
    while true do
        if showNames then
            for _, player in ipairs(GetActivePlayers()) do
                local ped = GetPlayerPed(player)
                if ped ~= PlayerPedId() then
                    local coords = GetEntityCoords(ped)
                    if #(coords - GetEntityCoords(PlayerPedId())) < 30.0 then
                        local onScreen, x, y = GetScreenCoordFromWorldCoord(coords.x, coords.y, coords.z + 1.0)
                        if onScreen then
                            SetTextScale(0.32, 0.32); SetTextFont(4); SetTextOutline(); SetTextCentre(true); SetTextColour(255, 255, 255, 215)
                            BeginTextCommandDisplayText('STRING')
                            AddTextComponentSubstringPlayerName(('[%s] %s'):format(GetPlayerServerId(player), GetPlayerName(player)))
                            EndTextCommandDisplayText(x, y)
                        end
                    end
                end
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

CreateThread(function()
    while true do
        if showBlips then
            local active = {}
            for _, player in ipairs(GetActivePlayers()) do
                local sid = GetPlayerServerId(player)
                if sid ~= GetPlayerServerId(PlayerId()) then
                    active[sid] = true
                    local ped = GetPlayerPed(player)
                    if ped ~= 0 then
                        if not playerBlips[sid] or not DoesBlipExist(playerBlips[sid]) then
                            local blip = AddBlipForEntity(ped)
                            SetBlipScale(blip, 0.85)
                            SetBlipCategory(blip, 7)
                            ShowHeadingIndicatorOnBlip(blip, true)
                            BeginTextCommandSetBlipName('STRING')
                            AddTextComponentString(('[%s] %s'):format(sid, GetPlayerName(player)))
                            EndTextCommandSetBlipName(blip)
                            playerBlips[sid] = blip
                        else
                            SetBlipCoords(playerBlips[sid], GetEntityCoords(ped))
                        end
                    end
                end
            end
            for sid, blip in pairs(playerBlips) do
                if not active[sid] and DoesBlipExist(blip) then
                    RemoveBlip(blip)
                    playerBlips[sid] = nil
                end
            end
            Wait(1000)
        else
            Wait(800)
        end
    end
end)

CreateThread(function()
    while true do
        if showCoords then
            local coords = GetEntityCoords(PlayerPedId())
            draw2DText(('Coords: vector4(%s, %s, %s, %s)'):format(QBCore.Shared.Round(coords.x,2), QBCore.Shared.Round(coords.y,2), QBCore.Shared.Round(coords.z,2), QBCore.Shared.Round(GetEntityHeading(PlayerPedId()),2)), 4, {66,182,245}, 0.4, 0.40, 0.025)
            Wait(0)
        else
            Wait(700)
        end
    end
end)

RegisterCommand('+' .. Config.Command, function() TriggerEvent('mz_staffpanel:client:open') end, false)
RegisterKeyMapping('+' .. Config.Command, 'Abrir painel da staff', 'keyboard', 'F10')

RegisterNetEvent('mz_staffpanel:client:spawnVehicle', function(model)
    model = tostring(model or ''):lower()
    local hash = loadModel(model)
    if not hash then return QBCore.Functions.Notify(('Veículo %s não encontrado.'):format(model), 'error') end
    local ped = PlayerPedId()
    local currentVeh = GetVehiclePedIsIn(ped, false)
    if currentVeh ~= 0 then
        TaskLeaveVehicle(ped, currentVeh, 16)
        Wait(250)
    end
    local spawnCoords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 5.0, 0.2)
    local spawned = CreateVehicle(hash, spawnCoords.x, spawnCoords.y, spawnCoords.z, GetEntityHeading(ped), true, false)
    if spawned == 0 then return QBCore.Functions.Notify('Não consegui gerar o veículo.', 'error') end
    SetVehicleOnGroundProperly(spawned)
    SetEntityAsMissionEntity(spawned, true, true)
    SetVehicleHasBeenOwnedByPlayer(spawned, true)
    SetVehRadioStation(spawned, 'OFF')
    SetModelAsNoLongerNeeded(hash)
    TaskWarpPedIntoVehicle(ped, spawned, -1)
    SetVehicleEngineOn(spawned, true, true, false)
    SetVehicleDirtLevel(spawned, 0.0)
    SetVehicleFuelLevel(spawned, 100.0)
    QBCore.Functions.Notify(('Veículo %s gerado.'):format(model), 'success')
end)
RegisterNetEvent('mz_staffpanel:client:deleteVehicle', function()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then vehicle = GetClosestVehicle(GetEntityCoords(ped), 6.0, 0, 71) end
    if vehicle == 0 then return QBCore.Functions.Notify('Nenhum veículo próximo.', 'error') end
    SetEntityAsMissionEntity(vehicle, true, true)
    DeleteVehicle(vehicle)
    if DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
    QBCore.Functions.Notify('Veículo removido.', 'success')
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if spectating then setSpectatePedState(false) end
end)
