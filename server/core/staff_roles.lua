local P = MZ_STAFFPANEL
local QBCore = P.QBCore

function P.NormalizeStaffRoleList(items)
    local hierarchy = Config.StaffHierarchy or {}
    local allowed = Config.AllowedStaffNames or {}
    local seen, out = {}, {}

    for _, item in ipairs(items or {}) do
        local name = ''
        local level = 0

        if type(item) == 'table' then
            name = tostring(item.name or item.group_name or ''):lower()
            level = tonumber(item.level or hierarchy[name] or 0) or 0
        else
            name = tostring(item or ''):lower()
            level = tonumber(hierarchy[name] or 0) or 0
        end

        if name ~= '' and not seen[name] then
            seen[name] = true
            out[#out + 1] = { name = name, level = level }
        end
    end

    if #out == 0 then
        for _, name in ipairs(allowed) do
            name = tostring(name or ''):lower()
            if name ~= '' and not seen[name] then
                seen[name] = true
                out[#out + 1] = { name = name, level = tonumber(hierarchy[name] or 0) or 0 }
            end
        end
    end

    table.sort(out, function(a, b)
        if a.level == b.level then
            return a.name < b.name
        end
        return a.level < b.level
    end)

    return out
end

function P.GetAssignableStaffRolesFor(src)
    local mz = P.GetMzPermExport()
    local roles, actorLevel = {}, 0

    if mz and mz.GetAssignableStaffRoles then
        local data = mz:GetAssignableStaffRoles(src)
        roles = (data and data.roles) or {}
        actorLevel = tonumber(data and data.actorLevel or 0) or 0
    end

    roles = P.NormalizeStaffRoleList(roles)

    if actorLevel <= 0 and P.HasQBBypass(src) then
        for _, lvl in pairs(Config.StaffHierarchy or {}) do
            lvl = tonumber(lvl or 0) or 0
            if lvl > actorLevel then actorLevel = lvl end
        end
    end

    if actorLevel > 0 then
        local filtered = {}
        for _, item in ipairs(roles) do
            if tonumber(item.level or 0) <= actorLevel then
                filtered[#filtered + 1] = item
            end
        end
        roles = filtered
    else
        roles = {}
    end

    return roles, actorLevel
end

function P.GetPlayerStaffRolesFor(target)
    local mz = P.GetMzPermExport()
    if not mz or not mz.GetPlayerStaffRoles then
        return { ok = false, error = 'mz_perm indisponível.' }
    end
    return mz:GetPlayerStaffRoles(target)
end

function P.IsAllowedStaffRole(role)
    role = tostring(role or ''):lower()
    for _, v in ipairs(Config.AllowedStaffNames or {}) do
        if tostring(v):lower() == role then
            return true
        end
    end
    return false
end

QBCore.Functions.CreateCallback('mz_staffpanel:server:getStaffManageData', function(src, cb, targetId)
    if not P.CanManageStaffPanel(src) then
        return cb({ ok = false, error = 'Sem permissão.' })
    end

    local target = tonumber(targetId or 0) or 0
    if target <= 0 then
        return cb({ ok = false, error = 'Jogador inválido.' })
    end

    local player = QBCore.Functions.GetPlayer(target)
    if not player then
        return cb({ ok = false, error = 'Jogador offline.' })
    end

    local rolesData = P.GetPlayerStaffRolesFor(target)
    local assignable, actorLevel = P.GetAssignableStaffRolesFor(src)
    local currentRoles = P.NormalizeStaffRoleList((rolesData and rolesData.roles) or {})

    local canTarget, targetErr = P.CanActOnTarget(src, target, 'manage_staff')
    if not canTarget then
        return cb({ ok = false, error = targetErr or 'Você não pode gerenciar esse alvo.' })
    end

    cb({
        ok = true,
        target = {
            id = target,
            name = P.GetPlayerNameSafe(player),
            citizenid = player.PlayerData.citizenid or '-',
            license = player.PlayerData.license or P.GetIdentifierSafe(target, 'license') or '-'
        },
        currentRoles = currentRoles or {},
        highestRole = rolesData and rolesData.highestRole or nil,
        highestLevel = tonumber(rolesData and rolesData.highestLevel or 0) or 0,
        assignableRoles = assignable or {},
        actorLevel = actorLevel or 0
    })
end)

RegisterNetEvent('mz_staffpanel:server:manageStaffRole', function(payload)
    local src = source
    if not P.CanManageStaffPanel(src) then return end

    payload = type(payload) == 'table' and payload or {}
    local target = tonumber(payload.target or 0) or 0
    local role = tostring(payload.role or ''):lower()
    local mode = tostring(payload.mode or 'add'):lower()
    local note = tostring(payload.note or ''):sub(1, 300)

    if target <= 0 or role == '' then
        return P.Notify(src, 'Dados inválidos para cargo.', 'error')
    end

    if mode ~= 'add' and mode ~= 'remove' then
        return P.Notify(src, 'Modo inválido.', 'error')
    end

    if not P.IsAllowedStaffRole(role) then
        return P.Notify(src, 'Cargo inválido.', 'error')
    end

    local mz = P.GetMzPermExport()
    if not mz or not mz.ManageStaffRole then
        return P.Notify(src, 'Integração com mz_perm indisponível.', 'error')
    end

    local before = P.GetPlayerStaffRolesFor(target)
    local ok, err = mz:ManageStaffRole(src, target, mode, role)
    if not ok then
        return P.Notify(src, err or 'Não foi possível alterar o cargo.', 'error')
    end

    local after = P.GetPlayerStaffRolesFor(target)
    local targetInfo = P.GetTargetInfo(target)
    local actor = P.GetActorInfo(src)
    local actionName = mode == 'remove' and 'staff_remove' or 'staff_add'
    local msg = (mode == 'remove' and 'Removeu cargo de staff.' or 'Definiu cargo de staff.')

    P.AddLog('staff_manage', actionName, src, target, msg, {
        role = role,
        note = note,
        before = before and before.roles or {},
        after = after and after.roles or {},
        actor = actor.name,
        target = targetInfo.name
    })

    P.Notify(src, (mode == 'remove' and 'Cargo removido: %s' or 'Cargo definido: %s'):format(role), 'success')

    if target ~= src and P.IsOnline(target) then
        P.Notify(target, (mode == 'remove' and 'Seu cargo de staff foi removido: %s' or 'Você recebeu cargo de staff: %s'):format(role), mode == 'remove' and 'error' or 'success')
    end
end)

RegisterNetEvent('mz_staffpanel:server:clearStaffRoles', function(payload)
    local src = source
    if not P.CanManageStaffPanel(src) then return end

    payload = type(payload) == 'table' and payload or {}
    local target = tonumber(payload.target or 0) or 0
    local note = tostring(payload.note or '')

    if target <= 0 then
        return P.Notify(src, 'Jogador inválido.', 'error')
    end

    local before = P.GetPlayerStaffRolesFor(target)
    if not before or not before.ok or #(before.roles or {}) == 0 then
        return P.Notify(src, 'Esse jogador não possui cargos de staff.', 'error')
    end

    local mz = P.GetMzPermExport()
    if not mz or not mz.ManageStaffRole then
        return P.Notify(src, 'Integração com mz_perm indisponível.', 'error')
    end

    for _, role in ipairs(before.roles) do
        local ok, err = mz:ManageStaffRole(src, target, 'remove', role)
        if not ok then
            return P.Notify(src, err or ('Falha ao remover cargo %s.'):format(role), 'error')
        end
    end

    local after = P.GetPlayerStaffRolesFor(target)

    P.AddLog('staff_manage', 'staff_clear', src, target, 'Removeu todos os cargos de staff.', {
        note = note,
        before = before.roles or {},
        after = after and after.roles or {}
    })

    P.Notify(src, 'Todos os cargos de staff foram removidos.', 'success')

    if target ~= src and P.IsOnline(target) then
        P.Notify(target, 'Você não faz mais parte da staff.', 'error')
    end
end)