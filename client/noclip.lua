local QBCore = exports['qb-core']:GetCoreObject()

local IsNoClipping      = false
local PlayerPed         = nil
local NoClipEntity      = nil
local Camera            = nil
local NoClipAlpha       = nil
local PlayerIsInVehicle = false
local ResourceName      = GetCurrentResourceName()

local MinY, MaxY        = -89.0, 89.0

-- Perspective values
local PedFirstPersonNoClip  = true
local VehFirstPersonNoClip  = false
local ESCEnable             = false

-- Speed settings
local Speed                 = 1.0
local TargetSpeed           = 1.0
local MaxSpeed              = 16.0

-- Key bindings
local MOVE_FORWARDS         = 32  -- W
local MOVE_BACKWARDS        = 33  -- S
local MOVE_LEFT             = 34  -- A
local MOVE_RIGHT            = 35  -- D
local MOVE_UP               = 44  -- Q
local MOVE_DOWN             = 46  -- E

local SPEED_DECREASE        = 14  -- Mouse wheel down
local SPEED_INCREASE        = 15  -- Mouse wheel up
local SPEED_RESET           = 348 -- Mouse wheel click
local SPEED_SLOW_MODIFIER   = 36  -- Ctrl
local SPEED_FAST_MODIFIER   = 21  -- Shift
local SPEED_FASTER_MODIFIER = 19  -- Alt

local function notify(msg, typ)
    if QBCore and QBCore.Functions and QBCore.Functions.Notify then
        QBCore.Functions.Notify(msg, typ or 'primary')
    end
end

local function DisabledControls()
    HudWeaponWheelIgnoreSelection()
    DisableAllControlActions(0)
    DisableAllControlActions(1)
    DisableAllControlActions(2)
    EnableControlAction(0, 220, true)
    EnableControlAction(0, 221, true)
    EnableControlAction(0, 245, true)
    if ESCEnable then
        EnableControlAction(0, 200, true)
    end
end

local function IsControlAlwaysPressed(inputGroup, control)
    return IsControlPressed(inputGroup, control) or IsDisabledControlPressed(inputGroup, control)
end

local function IsPedDrivingVehicle(ped, veh)
    return veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped
end

local function SetupCam()
    local entityRot = GetEntityRotation(NoClipEntity, 2)
    local coords = GetEntityCoords(NoClipEntity)
    Camera = CreateCameraWithParams('DEFAULT_SCRIPTED_CAMERA', coords.x, coords.y, coords.z, 0.0, 0.0, entityRot.z, 75.0)
    SetCamActive(Camera, true)
    RenderScriptCams(true, true, 500, false, false)

    if PlayerIsInVehicle then
        AttachCamToEntity(Camera, NoClipEntity, 0.0, VehFirstPersonNoClip and 0.5 or -4.5, VehFirstPersonNoClip and 1.0 or 2.0, true)
    else
        AttachCamToEntity(Camera, NoClipEntity, 0.0, PedFirstPersonNoClip and 0.0 or -2.0, PedFirstPersonNoClip and 1.0 or 0.5, true)
    end
end

local function DestroyCamera()
    if not Camera or Camera == 0 then return end
    SetGameplayCamRelativeHeading(0.0)
    RenderScriptCams(false, true, 500, true, true)
    SetCamActive(Camera, false)
    DestroyCam(Camera, true)
    Camera = nil
end

local function getGroundOrKeepCurrent(coords)
    local found, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 1.0, false)
    if found and math.abs(coords.z - groundZ) <= 8.0 then
        return vector3(coords.x, coords.y, groundZ + 1.0)
    end
    return coords
end

local function CheckInputRotation()
    local rightAxisX = GetDisabledControlNormal(0, 220)
    local rightAxisY = GetDisabledControlNormal(0, 221)

    local rotation = GetCamRot(Camera, 2)

    local yValue = rightAxisY * -5.0
    local newX = rotation.x
    local newZ = rotation.z + (rightAxisX * -10.0)

    if (rotation.x + yValue > MinY) and (rotation.x + yValue < MaxY) then
        newX = rotation.x + yValue
    end

    SetCamRot(Camera, newX, rotation.y, newZ, 2)
    SetEntityHeading(NoClipEntity, math.max(0.0, (newZ % 360.0)))
end

local function applyNoClipState()
    FreezeEntityPosition(NoClipEntity, true)
    SetEntityCollision(NoClipEntity, false, false)
    SetEntityVisible(NoClipEntity, false, false)
    SetEntityInvincible(NoClipEntity, true)
    SetLocalPlayerVisibleLocally(true)
    SetEntityAlpha(NoClipEntity, NoClipAlpha, false)
    if PlayerIsInVehicle then
        SetEntityAlpha(PlayerPed, NoClipAlpha, false)
    end
    SetEveryoneIgnorePlayer(PlayerPed, true)
    SetPoliceIgnorePlayer(PlayerPed, true)
end

local function restoreState()
    FreezeEntityPosition(NoClipEntity, false)
    FreezeEntityPosition(PlayerPed, false)
    SetEntityCollision(NoClipEntity, true, true)
    SetEntityVisible(NoClipEntity, true, false)
    SetLocalPlayerVisibleLocally(true)
    ResetEntityAlpha(NoClipEntity)
    ResetEntityAlpha(PlayerPed)
    SetEveryoneIgnorePlayer(PlayerPed, false)
    SetPoliceIgnorePlayer(PlayerPed, false)
    SetEntityInvincible(NoClipEntity, false)
    SetEntityVelocity(NoClipEntity, 0.0, 0.0, 0.0)
end

local function StopNoClip()
    local currentCoords = GetEntityCoords(NoClipEntity)
    local exitCoords = getGroundOrKeepCurrent(currentCoords)
    -- Use the camera yaw as source of truth on exit. It is what the player is
    -- actually looking at, while the entity heading can lag a frame behind.
    local finalHeading = Camera and GetCamRot(Camera, 2).z or GetEntityHeading(NoClipEntity)
    finalHeading = (finalHeading % 360.0 + 360.0) % 360.0

    restoreState()

    RequestCollisionAtCoord(exitCoords.x, exitCoords.y, exitCoords.z)
    SetFocusPosAndVel(exitCoords.x, exitCoords.y, exitCoords.z, 0.0, 0.0, 0.0)

    if PlayerIsInVehicle then
        SetEntityCoordsNoOffset(NoClipEntity, exitCoords.x, exitCoords.y, exitCoords.z + 0.3, false, false, false)
        -- Reset full rotation first, then let the game settle the car on the ground,
        -- and finally reapply the exact heading. This avoids the vehicle leaving noclip sideways.
        SetEntityRotation(NoClipEntity, 0.0, 0.0, finalHeading, 2, true)
        SetVehicleOnGroundProperly(NoClipEntity)
        SetEntityRotation(NoClipEntity, 0.0, 0.0, finalHeading, 2, true)
        SetEntityHeading(NoClipEntity, finalHeading)
        SetVehicleEngineOn(NoClipEntity, true, true, false)
    else
        SetEntityCoordsNoOffset(NoClipEntity, exitCoords.x, exitCoords.y, exitCoords.z, false, false, false)
        ClearPedTasksImmediately(PlayerPed)
        SetEntityHeading(NoClipEntity, finalHeading)
    end

    ClearFocus()
    DestroyCamera()
    SetUserRadioControlEnabled(true)
    PlaySoundFrontend(-1, 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    notify('Noclip desativado', 'primary')
end

local function RunNoClipThread()
    CreateThread(function()
        while IsNoClipping do
            Wait(0)
            CheckInputRotation()
            DisabledControls()

            if IsControlAlwaysPressed(2, SPEED_DECREASE) then
                TargetSpeed = TargetSpeed - 0.25
                if TargetSpeed < 0.5 then TargetSpeed = 0.5 end
                Wait(35)
            elseif IsControlAlwaysPressed(2, SPEED_INCREASE) then
                TargetSpeed = TargetSpeed + 0.25
                if TargetSpeed > MaxSpeed then TargetSpeed = MaxSpeed end
                Wait(35)
            elseif IsDisabledControlJustReleased(0, SPEED_RESET) then
                TargetSpeed = 1.0
            end

            Speed = Speed + ((TargetSpeed - Speed) * 0.18)

            local multi = 1.0
            if IsControlAlwaysPressed(0, SPEED_FAST_MODIFIER) then
                multi = 2.0
            elseif IsControlAlwaysPressed(0, SPEED_FASTER_MODIFIER) then
                multi = 4.0
            elseif IsControlAlwaysPressed(0, SPEED_SLOW_MODIFIER) then
                multi = 0.25
            end

            if IsControlAlwaysPressed(0, MOVE_FORWARDS) then
                local pitch = GetCamRot(Camera, 0)
                if pitch.x >= 0 then
                    SetEntityCoordsNoOffset(NoClipEntity, GetOffsetFromEntityInWorldCoords(NoClipEntity, 0.0, 0.5 * (Speed * multi), (pitch.x * ((Speed / 2.0) * multi)) / 89.0), true, true, true)
                else
                    SetEntityCoordsNoOffset(NoClipEntity, GetOffsetFromEntityInWorldCoords(NoClipEntity, 0.0, 0.5 * (Speed * multi), -1.0 * ((math.abs(pitch.x) * ((Speed / 2.0) * multi)) / 89.0)), true, true, true)
                end
            elseif IsControlAlwaysPressed(0, MOVE_BACKWARDS) then
                local pitch = GetCamRot(Camera, 2)
                if pitch.x >= 0 then
                    SetEntityCoordsNoOffset(NoClipEntity, GetOffsetFromEntityInWorldCoords(NoClipEntity, 0.0, -0.5 * (Speed * multi), -1.0 * (pitch.x * ((Speed / 2.0) * multi)) / 89.0), true, true, true)
                else
                    SetEntityCoordsNoOffset(NoClipEntity, GetOffsetFromEntityInWorldCoords(NoClipEntity, 0.0, -0.5 * (Speed * multi), ((math.abs(pitch.x) * ((Speed / 2.0) * multi)) / 89.0)), true, true, true)
                end
            end

            if IsControlAlwaysPressed(0, MOVE_LEFT) then
                SetEntityCoordsNoOffset(NoClipEntity, GetOffsetFromEntityInWorldCoords(NoClipEntity, -0.5 * (Speed * multi), 0.0, 0.0), true, true, true)
            elseif IsControlAlwaysPressed(0, MOVE_RIGHT) then
                SetEntityCoordsNoOffset(NoClipEntity, GetOffsetFromEntityInWorldCoords(NoClipEntity, 0.5 * (Speed * multi), 0.0, 0.0), true, true, true)
            end

            if IsControlAlwaysPressed(0, MOVE_UP) then
                SetEntityCoordsNoOffset(NoClipEntity, GetOffsetFromEntityInWorldCoords(NoClipEntity, 0.0, 0.0, 0.5 * (Speed * multi)), true, true, true)
            elseif IsControlAlwaysPressed(0, MOVE_DOWN) then
                SetEntityCoordsNoOffset(NoClipEntity, GetOffsetFromEntityInWorldCoords(NoClipEntity, 0.0, 0.0, -0.5 * (Speed * multi)), true, true, true)
            end

            local coords = GetEntityCoords(NoClipEntity)
            RequestCollisionAtCoord(coords.x, coords.y, coords.z)
            applyNoClipState()
        end
        StopNoClip()
    end)
end

local function ToggleNoClip(state)
    IsNoClipping      = state ~= nil and state or not IsNoClipping
    PlayerPed         = PlayerPedId()
    local currentVeh  = GetVehiclePedIsIn(PlayerPed, false)
    PlayerIsInVehicle = currentVeh ~= 0 and IsPedDrivingVehicle(PlayerPed, currentVeh)

    if PlayerIsInVehicle then
        NoClipEntity = currentVeh
        NoClipAlpha = VehFirstPersonNoClip and 0 or 51
        SetVehicleEngineOn(NoClipEntity, not IsNoClipping, true, IsNoClipping)
    else
        NoClipEntity = PlayerPed
        NoClipAlpha = PedFirstPersonNoClip and 0 or 51
    end

    if IsNoClipping then
        Speed = 1.0
        TargetSpeed = 1.0
        FreezeEntityPosition(PlayerPed, true)
        SetupCam()
        PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
        if not PlayerIsInVehicle then
            ClearPedTasksImmediately(PlayerPed)
        end
        SetUserRadioControlEnabled(false)
        notify('Noclip ativado', 'success')
        RunNoClipThread()
    else
        StopNoClip()
    end
end

RegisterNetEvent('mz_staffpanel:client:toggleNoClip', function()
    ToggleNoClip(not IsNoClipping)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= ResourceName then return end
    IsNoClipping = false
    if NoClipEntity and NoClipEntity ~= 0 then
        FreezeEntityPosition(NoClipEntity, false)
        SetEntityCollision(NoClipEntity, true, true)
        SetEntityVisible(NoClipEntity, true, false)
        ResetEntityAlpha(NoClipEntity)
        SetEntityInvincible(NoClipEntity, false)
    end
    if PlayerPed and PlayerPed ~= 0 then
        FreezeEntityPosition(PlayerPed, false)
        ResetEntityAlpha(PlayerPed)
        SetEveryoneIgnorePlayer(PlayerPed, false)
        SetPoliceIgnorePlayer(PlayerPed, false)
    end
    SetLocalPlayerVisibleLocally(true)
    DestroyCamera()
    SetUserRadioControlEnabled(true)
    ClearFocus()
end)
