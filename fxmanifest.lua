fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'TMG_Manic | Refactored via FiveM Specialist'
description 'Secured and Improved Apartments with Upgrades & Tenant Keys'
version '1.1.0'

shared_scripts {
    '@tmg-core/shared/locale.lua',
    'config.lua',
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
    '@PolyZone/CircleZone.lua'
}

dependencies {
    'tmg-core',
    'tmg-interior',
    'tmg-clothing',
    'tmg-weathersync'
}