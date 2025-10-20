fx_version 'cerulean'
game 'gta5'

author 'Cobra Modifications'
description 'A FiveM resource that assigns ACE permissions based on Discord role IDs. Aims to provide dynamic permission management through Discord integration.'
version '1.0.0'

server_scripts {
    'config.lua',
    'server/discord.lua',
    'server/ace_manager.lua',
    'server/main.lua'
}

-- Dependencies
dependencies {
    'yarn',
    'webpack'
}

-- Export functions for other resources
exports {
    'updatePlayerPermissions',
    'getPlayerDiscordRoles',
    'hasPermission'
}