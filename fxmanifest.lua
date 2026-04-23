fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'TMG_Manic'
description 'Secured and Improved Apartments'
version '1.0.0'

shared_scripts {
    'config.lua',
    '@tmg-core/shared/locale.lua',
    'locales/en.lua',
    'locales/*.lua'
}

server_scripts {
    'server/main.lua'
}

client_scripts {
    'client/main.lua',
    '@PolyZone/client.lua',
    '@PolyZone/BoxZone.lua',
    '@PolyZone/CircleZone.lua',
}

dependencies {
    'tmg-core',
    'tmg-interior',
    'tmg-clothing',
    'tmg-weathersync',
}
