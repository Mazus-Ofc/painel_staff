local P = MZ_STAFFPANEL

function P.RegisterAliases(primary, aliases, help, arguments, argsrequired, handler, perm)
    P.RegisterQbCommand(primary, help, arguments, argsrequired, handler, perm)
    for _, alias in ipairs(aliases or {}) do
        P.RegisterQbCommand(alias, help, arguments, argsrequired, handler, perm)
    end
end
