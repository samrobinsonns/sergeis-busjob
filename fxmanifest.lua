fx_version 'cerulean'
game 'gta5'

author 'Your Name'
description 'Bus Driving Script with Route Management and Passenger System'
version '1.0.0'

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

shared_scripts {
    'config.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

dependencies {
    'qb-core'
}
