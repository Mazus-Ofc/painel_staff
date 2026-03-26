local P = MZ_STAFFPANEL
local QBCore = P.QBCore

P.ActionHandlers = P.ActionHandlers or {}
P.ActionMeta = P.ActionMeta or {}

local function normalizeActionName(name)
    name = tostring(name or ''):gsub('^%s+', ''):gsub('%s+$', '')
    return name
end

function P.RegisterAction(name, options, handler)
    if type(options) == 'function' then
        handler = options
        options = {}
    end

    local action = normalizeActionName(name)
    if action == '' or type(handler) ~= 'function' then
        return
    end

    options = type(options) == 'table' and options or {}

    P.ActionHandlers[action] = handler
    P.ActionMeta[action] = {
        requiredTarget = options.requiredTarget == true,
        targetProtected = options.targetProtected == true,
        permission = options.permission,
        resolveTarget = options.resolveTarget ~= false,
    }
end

function P.GetActionMeta(action)
    return P.ActionMeta[tostring(action or '')] or {}
end

function P.GetActionTargetOrSelf(src, targetPlayer)
    if targetPlayer and targetPlayer.PlayerData and targetPlayer.PlayerData.source then
        return targetPlayer.PlayerData.source
    end

    return src
end

function P.GetPedCoordsHeading(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil, nil end

    local c = GetEntityCoords(ped)
    local h = GetEntityHeading(ped)

    return {
        x = c.x,
        y = c.y,
        z = c.z
    }, h
end

function P.StopSpectate(src, silent)
    local st = P.State.adminSpectateState[src]
    if not st then return end

    P.State.adminSpectateState[src] = nil

    if st.returnBucket ~= nil then
        SetPlayerRoutingBucket(src, tonumber(st.returnBucket) or 0)
    end

    TriggerClientEvent('mz_staffpanel:client:stopSpectate', src, st.returnCoords, st.returnHeading, silent == true)
end

function P.BroadcastToAdmins(messageArgs, color)
    local players = GetPlayers()

    for _, pid in ipairs(players) do
        pid = tonumber(pid)

        if pid and (P.HasQBBypass(pid) or P.CanOpen(pid)) then
            if not QBCore.Functions.IsOptin or QBCore.Functions.IsOptin(pid) then
                TriggerClientEvent('chat:addMessage', pid, {
                    color = color or { 255, 0, 0 },
                    multiline = true,
                    args = messageArgs
                })
            end
        end
    end
end

function P.GetVehicleModelByHash(hash)
    for spawn, v in pairs(QBCore.Shared.Vehicles or {}) do
        if tonumber(v.hash) == tonumber(hash) then
            return tostring(v.model or spawn or ''):lower(), v
        end
    end

    return nil, nil
end