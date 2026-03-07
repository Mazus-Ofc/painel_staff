local QBCore = exports['qb-core']:GetCoreObject()

local wallEnabled = false
local wallSnapshot = {}
local wallMyBucket = 0
local wallSmooth = {}

local function wallNotify(msg, typ)
    if not Config.Wall or not Config.Wall.Notifies then return end
    if QBCore and QBCore.Functions and QBCore.Functions.Notify then
        QBCore.Functions.Notify(msg, typ or 'primary', 2500)
    end
end

local function wallClamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end

local function wallTrunc(s, maxLen)
    if not s then return s end
    maxLen = maxLen or 18
    if #s <= maxLen then return s end
    return string.sub(s, 1, maxLen - 1) .. '…'
end

local function getVehLabel(veh)
    if veh == 0 or veh == nil then return nil end
    local model = GetEntityModel(veh)
    if not model or model == 0 then return nil end
    local display = GetDisplayNameFromVehicleModel(model)
    if not display or display == '' then return nil end
    local label = GetLabelText(display)
    if label and label ~= '' and label ~= 'NULL' then return label end
    return display
end

local function getWeapLabel(weaponHash)
    if not weaponHash or weaponHash == 0 or weaponHash == `WEAPON_UNARMED` then
        return nil
    end

    local ok, weaponName = pcall(function()
        return Citizen.InvokeNative(0x7FEAD38B326B9F74, weaponHash)
    end)

    if ok and weaponName and weaponName ~= '' then
        local text = GetLabelText(weaponName)
        if text and text ~= 'NULL' and text ~= '' then
            return text
        end
        return weaponName
    end

    return tostring(weaponHash)
end

local function draw2DText(sx, sy, text, scale, r, g, b, a)
    SetTextFont(4)
    SetTextScale(scale, scale)
    SetTextProportional(1)
    SetTextOutline()
    SetTextCentre(true)
    SetTextColour(r or 255, g or 255, b or 255, a or 255)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(sx, sy)
end

RegisterNetEvent('mz_staffpanel:client:toggleWall', function()
    wallEnabled = not wallEnabled
    if not wallEnabled then
        wallSnapshot = {}
        wallSmooth = {}
    end
    TriggerServerEvent('mz_staffpanel:server:setWallState', wallEnabled)
    wallNotify('Wall: ' .. (wallEnabled and 'ON' or 'OFF'), wallEnabled and 'success' or 'error')
end)

RegisterNetEvent('mz_staffpanel:client:updateWall', function(payload, adminBucket)
    wallSnapshot = payload or {}
    wallMyBucket = tonumber(adminBucket) or 0

    if not Config.Wall or not Config.Wall.Smooth then return end

    local t = GetGameTimer()
    for i = 1, #wallSnapshot do
        local p = wallSnapshot[i]
        local s = wallSmooth[p.id]
        if not s then
            wallSmooth[p.id] = { x = p.x, y = p.y, z = p.z, tx = p.x, ty = p.y, tz = p.z, lastT = t }
        else
            if s.x == nil then s.x, s.y, s.z = p.x, p.y, p.z end
            s.tx, s.ty, s.tz = p.x, p.y, p.z
            s.lastT = t
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if wallEnabled then
        TriggerServerEvent('mz_staffpanel:server:setWallState', false)
    end
end)

CreateThread(function()
    while true do
        Wait(1000)
        if not Config.Wall or not Config.Wall.Smooth then
            wallSmooth = {}
        else
            local t = GetGameTimer()
            for id, s in pairs(wallSmooth) do
                if s.lastT and (t - s.lastT) > (Config.Wall.SmoothDropAfterMs or 3000) then
                    wallSmooth[id] = nil
                end
            end
        end
    end
end)

CreateThread(function()
    while true do
        if not wallEnabled then
            Wait(250)
        else
            Wait(0)
            local myPed = PlayerPedId()
            local myCoords = GetEntityCoords(myPed)
            local mySid = GetPlayerServerId(PlayerId())

            for i = 1, #wallSnapshot do
                local p = wallSnapshot[i]
                if (Config.Wall.ShowSelf) or (p.id ~= mySid) then
                    local x, y, z = p.x, p.y, p.z
                    if Config.Wall.Smooth then
                        local s = wallSmooth[p.id]
                        if s and s.tx then
                            s.x = s.x + (s.tx - s.x) * (Config.Wall.SmoothFactor or 0.25)
                            s.y = s.y + (s.ty - s.y) * (Config.Wall.SmoothFactor or 0.25)
                            s.z = s.z + (s.tz - s.z) * (Config.Wall.SmoothFactor or 0.25)
                            x, y, z = s.x, s.y, s.z
                        end
                    end

                    local otherDim = (tonumber(p.bucket) ~= tonumber(wallMyBucket))
                    if (not otherDim) or Config.Wall.ShowOtherBuckets then
                        local dx = myCoords.x - x
                        local dy = myCoords.y - y
                        local dz = myCoords.z - z
                        local dist = math.sqrt(dx*dx + dy*dy + dz*dz)

                        if dist <= (Config.Wall.DrawDistance or 800.0) then
                            local hpPct, arPct, vehTxt = -1, -1, 'UNK'
                            local ped = nil
                            local playerIdx = GetPlayerFromServerId(p.id)

                            if playerIdx ~= -1 then
                                ped = GetPlayerPed(playerIdx)
                                if ped and ped ~= 0 then
                                    if Config.Wall.PreferStreamedCoords then
                                        local pc = GetEntityCoords(ped)
                                        x, y, z = pc.x, pc.y, pc.z
                                    end
                                    local hp = GetEntityHealth(ped) or 0
                                    local ar = GetPedArmour(ped) or 0
                                    local inVeh = IsPedInAnyVehicle(ped, false)

                                    if inVeh and Config.Wall.PreferStreamedCoords then
                                        local vehc = GetVehiclePedIsIn(ped, false)
                                        if vehc and vehc ~= 0 then
                                            local vc = GetEntityCoords(vehc)
                                            x, y, z = vc.x, vc.y, vc.z
                                        end
                                    end

                                    hpPct = wallClamp(math.floor((hp - 100) * 1.0), 0, 100)
                                    arPct = wallClamp(math.floor(ar), 0, 100)
                                    if inVeh and Config.Wall.ShowVehicleName then
                                        local veh = GetVehiclePedIsIn(ped, false)
                                        local vn = getVehLabel(veh)
                                        vehTxt = vn and ('VEH:' .. wallTrunc(vn, Config.Wall.VehicleNameMaxLen or 18)) or 'VEH'
                                    else
                                        vehTxt = inVeh and 'VEH' or 'ONFOOT'
                                    end
                                end
                            end

                            local hpTxt = (hpPct >= 0) and tostring(hpPct) or '??'
                            local arTxt = (arPct >= 0) and tostring(arPct) or '??'
                            local dimTag = otherDim and ('DIM:%s*'):format(tostring(p.bucket)) or ('DIM:%s'):format(tostring(p.bucket))

                            local cr, cg, cb, ca = table.unpack(Config.Wall.ColorDefault or {255,255,255,255})
                            local isDead = false
                            if playerIdx ~= -1 and ped and ped ~= 0 then
                                isDead = IsEntityDead(ped)
                            end
                            if isDead then
                                cr, cg, cb, ca = table.unpack(Config.Wall.ColorDead or {255,70,70,255})
                            end

                            local nameText = p.name or 'SemNome'
                            local staffTag = ''
                            if p.staff then
                                nameText = ('~y~%s~s~'):format(p.name or 'SemNome')
                                staffTag = ' ~y~[ADM]~s~'
                            end

                            local wepTxt = ''
                            if Config.Wall.ShowWeaponInfo and playerIdx ~= -1 and ped and ped ~= 0 then
                                if IsPedArmed(ped, 7) then
                                    local wh = GetSelectedPedWeapon(ped)
                                    local wl = getWeapLabel(wh)
                                    wepTxt = wl and ('ARM:' .. wallTrunc(wl, Config.Wall.WeaponNameMaxLen or 20)) or 'ARM'
                                else
                                    wepTxt = 'DESARM'
                                end
                            end

                            local line1 = ('[%d] %s%s'):format(p.id, nameText, staffTag)
                            local line2 = ('HP:%s  AR:%s  |  %s'):format(hpTxt, arTxt, (vehTxt or 'UNK'))
                            local line3 = ('%s  |  %s  |  %.0fm'):format(dimTag, (wepTxt ~= '' and wepTxt or 'SEMINFO'), dist)

                            if Config.Wall.DrawLines and dist <= (Config.Wall.LineDistance or 200.0) then
                                DrawLine(myCoords.x, myCoords.y, myCoords.z + 0.8, x, y, z + 0.8, cr, cg, cb, (Config.Wall.LineAlpha or 180))
                            end

                            local onScreen, sx, sy = World3dToScreen2d(x, y, z + (Config.Wall.TextZOffset or 1.15))
                            if onScreen then
                                local scale = (Config.Wall.TextScale or 0.30)
                                local gap = (Config.Wall.ScreenLineSpacing or 0.024)
                                draw2DText(sx, sy, line1, scale, cr, cg, cb, ca)
                                if Config.Wall.MultiLine then
                                    draw2DText(sx, sy + gap, line2, scale, 255, 255, 255, 255)
                                    draw2DText(sx, sy + (gap * 2), line3, scale, 255, 255, 255, 255)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)
