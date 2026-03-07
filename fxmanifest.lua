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
    'html/app.js'
}

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/noclip.lua',
    'client/commands/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/commands/*.lua'
}

dependencies {
    'qb-core',
    'mz_perm'
}
