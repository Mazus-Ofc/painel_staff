local P = MZ_STAFFPANEL

P.RegisterAliases(
    Config.StaffDuty and Config.StaffDuty.DutyCommand or 'staffon',
    {},
    'Entrar em serviço como staff',
    {},
    false,
    function(source)
        if not P.CanOpen(source) then
            return P.Notify(source, 'Sem permissão.', 'error')
        end

        local ok, dataOrErr = P.SetStaffDuty(source, true, Config.StaffDuty.DefaultStatus or 'livre')
        if not ok then
            return P.Notify(source, dataOrErr or 'Falha ao entrar em serviço.', 'error')
        end

        P.Notify(source, 'Você entrou em serviço.', 'success')
    end,
    Config.MenuAccess
)

P.RegisterAliases(
    Config.StaffDuty and Config.StaffDuty.OffDutyCommand or 'staffoff',
    {},
    'Sair de serviço como staff',
    {},
    false,
    function(source)
        if not P.CanOpen(source) then
            return P.Notify(source, 'Sem permissão.', 'error')
        end

        local ok, dataOrErr = P.SetStaffDuty(source, false)
        if not ok then
            return P.Notify(source, dataOrErr or 'Falha ao sair de serviço.', 'error')
        end

        P.Notify(source, 'Você saiu de serviço.', 'primary')
    end,
    Config.MenuAccess
)