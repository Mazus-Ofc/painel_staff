local P = MZ_STAFFPANEL

local function hasPayloadTarget(payload)
    if type(payload) ~= 'table' then return false end
    if payload.target == nil then return false end

    local value = tostring(payload.target)
    return value ~= ''
end

local function buildContext(src, action, payload, targetPlayer)
    local ctx = {
        src = src,
        action = action,
        payload = payload,
        targetPlayer = targetPlayer,
        targetSrc = targetPlayer and targetPlayer.PlayerData and targetPlayer.PlayerData.source or nil,
        targetOrSelf = P.GetActionTargetOrSelf(src, targetPlayer),
        meta = P.GetActionMeta(action)
    }

    function ctx.log(category, message, metadata)
        P.AddLog(
            category or 'action',
            tostring(action or 'unknown'),
            src,
            ctx.targetSrc,
            message,
            metadata or payload
        )
    end

    return ctx
end

function P.HandleAction(src, payload)
    if type(payload) ~= 'table' or not P.CanOpen(src) then
        return
    end

    local action = tostring(payload.action or '')
    if action == '' then
        return
    end

    local handler = P.ActionHandlers[action]
    if type(handler) ~= 'function' then
        return P.Notify(src, 'Ação inválida.', 'error')
    end

    local meta = P.GetActionMeta(action)
    local permissionKey = meta.permission or action

    if not P.RequireAction(src, permissionKey) then
        return
    end

    local targetPlayer = nil

    if meta.resolveTarget ~= false then
        if hasPayloadTarget(payload) then
            targetPlayer = P.GetTarget(src, payload.target)
            if not targetPlayer then
                return
            end

            if meta.targetProtected then
                local ok, err = P.CanActOnTarget(src, targetPlayer.PlayerData.source, action)
                if not ok then
                    return P.Notify(src, err or 'Você não pode agir nesse alvo.', 'error')
                end
            end
        elseif meta.requiredTarget then
            return P.Notify(src, 'Essa ação exige um alvo válido.', 'error')
        end
    end

    local ctx = buildContext(src, action, payload, targetPlayer)

    local ok, err = xpcall(function()
        handler(ctx)
    end, debug.traceback)

    if not ok then
        print(('^1[mz_staffpanel] action "%s" error:^7 %s'):format(action, tostring(err)))
        P.Notify(src, 'Falha interna ao executar a ação.', 'error')
    end
end

RegisterNetEvent('mz_staffpanel:server:performAction', function(payload)
    P.HandleAction(source, payload)
end)

RegisterNetEvent('mz_staffpanel:server:spectateTick', function()
    local adminSrc = source
    local st = P.State.adminSpectateState[adminSrc]

    if not st or not st.active then
        return
    end

    local targetSrc = st.target
    if not P.IsOnline(adminSrc) or not P.IsOnline(targetSrc) then
        return P.StopSpectate(adminSrc, false)
    end

    local tPed = GetPlayerPed(targetSrc)
    if not tPed or tPed == 0 then
        return P.StopSpectate(adminSrc, false)
    end

    local c = GetEntityCoords(tPed)
    local h = GetEntityHeading(tPed)
    local bucket = GetPlayerRoutingBucket(targetSrc) or 0

    if st.returnBucket ~= bucket then
        SetPlayerRoutingBucket(adminSrc, bucket)
    end

    TriggerClientEvent('mz_staffpanel:client:syncSpectateTarget', adminSrc, {
        src = targetSrc,
        coords = { x = c.x, y = c.y, z = c.z },
        heading = h,
        bucket = bucket
    })
end)

AddEventHandler('playerDropped', function()
    local src = source

    if P.State.adminSpectateState[src] then
        P.StopSpectate(src, true)
    end

    P.State.frozenPlayers[src] = nil

    for adminSrc, st in pairs(P.State.adminSpectateState) do
        if st and tonumber(st.target or 0) == tonumber(src) then
            P.StopSpectate(adminSrc, false)
        end
    end
end)