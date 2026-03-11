local P = MZ_STAFFPANEL
local QBCore = P.QBCore

function P.HasQBBypass(src)
    for _, perm in ipairs(Config.QBBypassPermissions or { 'admin', 'god' }) do
        if QBCore.Functions.HasPermission(src, perm) then
            return true
        end
    end

    for _, ace in ipairs(Config.AceBypassPermissions or {}) do
        if ace and ace ~= '' and IsPlayerAceAllowed(src, ace) then
            return true
        end
    end

    return false
end

function P.HasLevel(src, level)
    if not level or level == '' then return true end
    if P.HasQBBypass(src) then return true end
    return exports['mz_perm'] and exports['mz_perm']:HasStaff(src, level) or false
end

function P.CanOpen(src)
    return P.HasLevel(src, Config.MenuAccess)
end

function P.BuildPermMap(src)
    local out = {}
    for action, level in pairs(Config.ActionPerms) do
        out[action] = P.HasLevel(src, level)
    end
    out.panel = P.CanOpen(src)
    return out
end

function P.GetMzPermExport()
    local resource = tostring(Config.MzPermResource or 'mz_perm')
    if GetResourceState(resource) ~= 'started' then return nil end
    return exports[resource]
end

function P.RequireAction(src, action)
    local level = Config.ActionPerms[action]
    if not level then return true end

    if not P.HasLevel(src, level) then
        P.Notify(src, 'Você não tem permissão para esta ação.', 'error')
        return false
    end

    return true
end

function P.CanManageStaffPanel(src)
    local actionKey = tostring(Config.StaffManageAction or 'setPermissions')
    return P.RequireAction(src, actionKey)
end

function P.GetTarget(src, targetId)
    targetId = tonumber(targetId)
    if not targetId then
        P.Notify(src, 'ID inválido.', 'error')
        return nil
    end

    local Player = QBCore.Functions.GetPlayer(targetId)
    if not Player then
        P.Notify(src, 'Jogador não encontrado.', 'error')
        return nil
    end

    return Player
end

function P.IsOnline(src)
    return src and GetPlayerPing(src) and GetPlayerPing(src) > 0
end

function P.RegisterQbCommand(commandName, help, arguments, argsrequired, handler, permission)
    if not commandName or commandName == '' then return end

    QBCore.Commands.Add(commandName, help, arguments or {}, argsrequired == true, function(source, args, rawCommand)
        if P.AddLog then
            P.AddLog('command', commandName, source, nil, rawCommand or commandName, { args = args or {} })
        end
        handler(source, args, rawCommand)
    end, permission or Config.MenuAccess)
end