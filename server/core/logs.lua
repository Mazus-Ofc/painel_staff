local P = MZ_STAFFPANEL
local QBCore = P.QBCore

function P.SafeJson(data)
    local ok, encoded = pcall(json.encode, data or {})
    return ok and encoded or '{}'
end

function P.GetActorInfo(src)
    if not src or src == 0 then
        return { src = 0, name = 'SYSTEM', license = 'system' }
    end

    local Player = QBCore.Functions.GetPlayer(src)
    return {
        src = src,
        name = Player and P.GetPlayerNameSafe(Player) or (GetPlayerName(src) or ('ID ' .. tostring(src))),
        license = (Player and Player.PlayerData.license) or P.GetIdentifierSafe(src, 'license') or '-'
    }
end

function P.GetTargetInfo(targetSrc)
    if not targetSrc then
        return { src = nil, name = nil, license = nil }
    end

    local Player = QBCore.Functions.GetPlayer(targetSrc)
    return {
        src = tonumber(targetSrc),
        name = Player and P.GetPlayerNameSafe(Player) or (GetPlayerName(targetSrc) or ('ID ' .. tostring(targetSrc))),
        license = (Player and Player.PlayerData.license) or P.GetIdentifierSafe(targetSrc, 'license') or '-'
    }
end

function P.AddLog(category, action, actorSrc, targetSrc, message, metadata)
    local actor = P.GetActorInfo(actorSrc)
    local target = P.GetTargetInfo(targetSrc)

    local ok, err = pcall(function()
        MySQL.insert.await(('INSERT INTO `%s` (category, action, actor_src, actor_name, actor_license, target_src, target_name, target_license, message, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'):format(Config.LogTable or 'staff_logs'), {
            tostring(category or 'general'),
            tostring(action or 'event'),
            actor.src,
            actor.name,
            actor.license,
            target.src,
            target.name,
            target.license,
            tostring(message or ''),
            P.SafeJson(metadata)
        })
    end)

    if not ok then
        print('^1[mz_staffpanel] log insert error:^7', err)
    end
end

function P.FetchRecentLogs(limit)
    return MySQL.query.await(('SELECT * FROM `%s` ORDER BY id DESC LIMIT %d'):format(Config.LogTable or 'staff_logs', tonumber(limit or 20) or 20)) or {}
end

RegisterNetEvent('mz_staffpanel:server:addCustomLog', function(category, action, message, targetSrc, metadata)
    local src = source
    if not P.CanOpen(src) then return end

    category = tostring(category or 'custom'):sub(1, 64)
    action = tostring(action or 'event'):sub(1, 64)
    message = tostring(message or ''):sub(1, 500)

    P.AddLog(category, action, src, tonumber(targetSrc) or nil, message, type(metadata) == 'table' and metadata or {})
end)