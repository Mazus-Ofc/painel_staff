fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Mazus'
description 'Painel de staff por hierarquia usando mz_perm (QBCore)'
version '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/js/*.js'
}

shared_scripts {
    'config/config.lua'
}

client_scripts {
    'client/main.lua',
    'client/noclip.lua',
    'client/commands/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/core/permissions.lua',
    'server/core/logs.lua',
    'server/core/reports.lua',
    'server/core/staff_roles.lua',
    'server/core/actions.lua',
    'server/lib/shared.lua',
    'server/commands/*.lua'
}

dependencies {
    'qb-core',
    'mz_perm'
}
