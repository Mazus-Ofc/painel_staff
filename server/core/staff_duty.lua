local P = MZ_STAFFPANEL
local QBCore = P.QBCore

P.State.duty = P.State.duty or {}

local function dutyDateRef()
    return os.date('%Y-%m-%d')
end

local function trimText(value, maxLen)
    value = tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if maxLen and maxLen > 0 then
        value = value:sub(1, maxLen)
    end
    return value
end

function P.GetHighestStaffRoleName(src)
    local mz = P.GetMzPermExport and P.GetMzPermExport() or nil
    if mz and mz.GetPlayerStaffRoles then
        local data = mz:GetPlayerStaffRoles(src)
        if data and data.highestRole then
            return tostring(data.highestRole)
        end
    end

    local bestName, bestLevel = nil, -1
    for name, lvl in pairs(Config.StaffHierarchy or {}) do
        if P.HasLevel(src, name) then
            lvl = tonumber(lvl or 0) or 0
            if lvl > bestLevel then
                bestLevel = lvl
                bestName = tostring(name)
            end
        end
    end

    return bestName or 'staff'
end

function P.GetStaffLicense(src)
    local Player = QBCore.Functions.GetPlayer(src)
    return (Player and Player.PlayerData.license) or P.GetIdentifierSafe(src, 'license') or '-'
end

function P.EnsureDailyStatsRow(license, name)
    if not Config.StaffDuty or not Config.StaffDuty.TrackDailyStats then return end
    MySQL.query.await([[
        INSERT INTO `staff_daily_stats` (`staff_license`, `staff_name`, `date_ref`)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE `staff_name` = VALUES(`staff_name`)
    ]], {
        license,
        name,
        dutyDateRef()
    })
end

function P.AddDailyStat(license, name, field, amount)
    if not Config.StaffDuty or not Config.StaffDuty.TrackDailyStats then return end
    local allowed = {
        seconds_on_duty = true,
        reports_handled = true,
        reports_closed = true,
        warns_applied = true,
        bans_applied = true,
        revives_done = true,
        teleports_done = true,
        spectates_done = true
    }
    if not allowed[field] then return end

    P.EnsureDailyStatsRow(license, name)

    MySQL.update.await(([[
        UPDATE `staff_daily_stats`
        SET `%s` = COALESCE(`%s`, 0) + ?, `staff_name` = ?
        WHERE `staff_license` = ? AND `date_ref` = ?
    ]]):format(field, field), {
        tonumber(amount or 0) or 0,
        name,
        license,
        dutyDateRef()
    })
end

function P.IsStaffOnDuty(src)
    local st = P.State.duty[src]
    return st and st.onDuty == true or false
end

function P.GetDutyState(src)
    return P.State.duty[src]
end

function P.SetStaffDuty(src, onDuty, status)
    if not P.CanOpen(src) then
        return false, 'Sem permissão.'
    end

    local Player = QBCore.Functions.GetPlayer(src)
    local license = P.GetStaffLicense(src)
    local name = Player and P.GetPlayerNameSafe(Player) or (GetPlayerName(src) or ('ID ' .. tostring(src)))
    local role = P.GetHighestStaffRoleName(src)
    local now = os.time()
    local current = P.State.duty[src]

    if onDuty then
        if current and current.onDuty then
            return false, 'Você já está em serviço.'
        end

        P.State.duty[src] = {
            onDuty = true,
            status = trimText(status or (Config.StaffDuty.DefaultStatus or 'livre'), 32),
            startedAt = now,
            staffName = name,
            staffLicense = license,
            role = role
        }

        MySQL.insert.await([[
            INSERT INTO `staff_duty_logs`
            (`staff_src`, `staff_name`, `staff_license`, `role`, `action`, `status`, `started_at`, `date_ref`, `metadata`)
            VALUES (?, ?, ?, ?, ?, ?, NOW(), ?, ?)
        ]], {
            src,
            name,
            license,
            role,
            'on',
            P.State.duty[src].status,
            dutyDateRef(),
            P.SafeJson({ source = src })
        })

        P.EnsureDailyStatsRow(license, name)
        P.AddLog('staff_duty', 'staff_on', src, nil, 'Entrou em serviço.', {
            status = P.State.duty[src].status,
            role = role
        })

        return true, P.State.duty[src]
    else
        if not current or not current.onDuty then
            return false, 'Você não está em serviço.'
        end

        local duration = math.max(0, now - (tonumber(current.startedAt or now) or now))

        MySQL.insert.await([[
            INSERT INTO `staff_duty_logs`
            (`staff_src`, `staff_name`, `staff_license`, `role`, `action`, `status`, `started_at`, `ended_at`, `duration_seconds`, `date_ref`, `metadata`)
            VALUES (?, ?, ?, ?, ?, ?, FROM_UNIXTIME(?), NOW(), ?, ?, ?)
        ]], {
            src,
            current.staffName or name,
            current.staffLicense or license,
            current.role or role,
            'off',
            current.status or 'livre',
            tonumber(current.startedAt or now) or now,
            duration,
            dutyDateRef(),
            P.SafeJson({ source = src })
        })

        P.AddDailyStat(current.staffLicense or license, current.staffName or name, 'seconds_on_duty', duration)

        P.AddLog('staff_duty', 'staff_off', src, nil, 'Saiu de serviço.', {
            status = current.status or 'livre',
            role = current.role or role,
            duration = duration
        })

        P.State.duty[src] = nil
        return true, { duration = duration }
    end
end

function P.RequireStaffDuty(src)
    if not Config.StaffDutyEnabled then return true end
    if not P.CanOpen(src) then return false end
    if not P.IsStaffOnDuty(src) then
        P.Notify(src, 'Você precisa entrar em serviço para usar essa função.', 'error')
        return false
    end
    return true
end

function P.ActionRequiresDuty(action)
    if not Config.StaffDutyEnabled then return false end
    local map = (Config.StaffDuty and Config.StaffDuty.RequireDutyForActions) or {}
    return map[action] == true
end

function P.GetStaffDutyRows()
    local rows = {}
    for src, st in pairs(P.State.duty or {}) do
        if st and st.onDuty and P.IsOnline(src) then
            rows[#rows + 1] = {
                src = src,
                name = st.staffName or (GetPlayerName(src) or ('ID ' .. tostring(src))),
                license = st.staffLicense or P.GetStaffLicense(src),
                role = st.role or P.GetHighestStaffRoleName(src),
                status = st.status or 'livre',
                onDuty = true,
                startedAt = st.startedAt,
                secondsOnDuty = math.max(0, os.time() - (tonumber(st.startedAt or os.time()) or os.time()))
            }
        end
    end

    table.sort(rows, function(a, b)
        return tostring(a.name or ''):lower() < tostring(b.name or ''):lower()
    end)

    return rows
end

QBCore.Functions.CreateCallback('mz_staffpanel:server:getStaffDutyData', function(src, cb)
    if not P.CanOpen(src) then
        return cb({ ok = false, error = 'Sem permissão.' })
    end

    local rows = P.GetStaffDutyRows()
    local totalOnDuty = #rows
    local totalBusy = 0

    for _, row in ipairs(rows) do
        if tostring(row.status or '') == 'em_atendimento' then
            totalBusy = totalBusy + 1
        end
    end

    cb({
        ok = true,
        rows = rows,
        meOnDuty = P.IsStaffOnDuty(src),
        meState = P.GetDutyState(src),
        stats = {
            totalOnDuty = totalOnDuty,
            totalBusy = totalBusy,
            totalFree = math.max(0, totalOnDuty - totalBusy)
        }
    })
end)

RegisterNetEvent('mz_staffpanel:server:setDutyState', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}

    local mode = tostring(payload.mode or ''):lower()
    local status = trimText(payload.status or (Config.StaffDuty.DefaultStatus or 'livre'), 32)

    if mode == 'on' then
        local ok, dataOrErr = P.SetStaffDuty(src, true, status)
        if not ok then
            return P.Notify(src, dataOrErr or 'Falha ao entrar em serviço.', 'error')
        end
        P.Notify(src, 'Você entrou em serviço.', 'success')
    elseif mode == 'off' then
        local ok, dataOrErr = P.SetStaffDuty(src, false)
        if not ok then
            return P.Notify(src, dataOrErr or 'Falha ao sair de serviço.', 'error')
        end
        P.Notify(src, 'Você saiu de serviço.', 'primary')
    elseif mode == 'status' then
        if not P.IsStaffOnDuty(src) then
            return P.Notify(src, 'Você não está em serviço.', 'error')
        end

        local st = P.State.duty[src]
        st.status = status ~= '' and status or 'livre'

        P.AddLog('staff_duty', 'staff_status', src, nil, 'Alterou status em serviço.', {
            status = st.status
        })

        P.Notify(src, ('Status atualizado para: %s'):format(st.status), 'success')
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    if P.IsStaffOnDuty(src) then
        P.SetStaffDuty(src, false)
    end
end)