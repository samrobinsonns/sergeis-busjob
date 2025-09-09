fx_version 'adamant'
game 'gta5'
author 'Sergei Scripts'
description 'sergei-bus.fivem.net'
lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/shared.lua',
    'config.lua',
}

client_scripts {
    'shared/c_framework.lua',
    'client/main.lua',
    'client/ui.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'shared/s_framework.lua',
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/images/*.*',
    'html/images/**/*.*',
    'html/font/*.*',
    'html/*.*',    
}

escrow_ignore {
    'shared/*.lua'
}
dependency '/assetpacks'