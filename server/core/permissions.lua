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

    local mz = P.GetMzPermExport()
    return mz and mz:HasStaff(src, level) or false
end

function P.CanOpen(src)
    return P.HasLevel(src, Config.MenuAccess)
end

function P.CanViewSensitiveData(src)
    return P.HasLevel(src, (Config.ViewAccess and Config.ViewAccess.sensitiveData) or 'suporte')
end

function P.CanViewHistory(src)
    return P.HasLevel(src, (Config.ViewAccess and Config.ViewAccess.history) or 'moderador')
end

function P.CanViewLogs(src)
    return P.HasLevel(src, (Config.ViewAccess and Config.ViewAccess.logs) or 'moderador')
end

function P.CanViewBans(src)
    return P.HasLevel(src, (Config.ViewAccess and Config.ViewAccess.bans) or 'administrador')
end

function P.CanAddCustomLog(src)
    return P.HasLevel(src, (Config.ViewAccess and Config.ViewAccess.customLog) or 'diretor')
end

function P.BuildPermMap(src)
    local out = {}
    for action, level in pairs(Config.ActionPerms) do
        out[action] = P.HasLevel(src, level)
    end
    out.panel = P.CanOpen(src)
    out.viewSensitiveData = P.CanViewSensitiveData(src)
    out.viewHistory = P.CanViewHistory(src)
    out.viewLogs = P.CanViewLogs(src)
    out.viewBans = P.CanViewBans(src)
    out.addCustomLog = P.CanAddCustomLog(src)
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

    if P.HasQBBypass and P.HasQBBypass(src) then
        return true
    end

    if P.ActionRequiresDuty and P.ActionRequiresDuty(action) then
        if not P.RequireStaffDuty(src) then
            return false
        end
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

function P.CanActOnTarget(src, targetId, action)
    targetId = tonumber(targetId or 0) or 0
    if targetId <= 0 then
        return false, 'Jogador inválido.'
    end

    if P.HasQBBypass(src) then
        return true
    end

    local mz = P.GetMzPermExport()
    if mz and mz.CanActOnTarget then
        local ok, err = mz:CanActOnTarget(src, targetId, action)
        if ok then return true end
        return false, err or 'Você não pode agir nesse alvo.'
    end

    local myLevel = 0
    local targetLevel = 0

    if mz and mz.GetPlayerStaffRoles then
        local mine = mz:GetPlayerStaffRoles(src)
        local target = mz:GetPlayerStaffRoles(targetId)
        myLevel = tonumber(mine and mine.highestLevel or 0) or 0
        targetLevel = tonumber(target and target.highestLevel or 0) or 0
    end

    if targetLevel <= 0 then
        return true
    end

    if myLevel <= targetLevel then
        return false, 'Você não pode agir em alguém do mesmo nível ou acima do seu.'
    end

    return true
end

function P.RequireTargetAction(src, action, targetId)
    local ok, err = P.CanActOnTarget(src, targetId, action)
    if ok then return true end

    P.Notify(src, err or 'Você não pode agir nesse alvo.', 'error')
    return false
end

function P.FilterPlayerDataForViewer(src, rows)
    if P.CanViewSensitiveData(src) then
        return rows
    end

    local out = {}
    for i = 1, #(rows or {}) do
        local row = rows[i]
        out[#out + 1] = {
            id = row.id,
            name = row.name,
            citizenid = row.citizenid,
            job = row.job,
            gang = row.gang,
            staff = row.staff,
            ping = row.ping,
            bucket = row.bucket,
            health = row.health,
            armor = row.armor,
            cash = 0,
            bank = 0,
            phone = '-',
            license = '-',
            discord = '-',
            steam = '-',
            fivem = '-',
            coords = { x = 0.0, y = 0.0, z = 0.0 },
            online = row.online
        }
    end
    return out
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
