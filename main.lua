-- Main server script for Discord ACE Permissions

-- Resource initialization
local resourceStarted = false
local updateTimer = nil

-- Helper function for logging
local function logInfo(msg)
    print("^6[Discord ACE Perms]^7 " .. msg)
end

local function logError(msg)
    print("^1[Discord ACE Perms ERROR]^7 " .. msg)
end

local function debugPrint(msg)
    if Config and Config.Debug then
        print("^3[Discord ACE Perms DEBUG]^7 " .. msg)
    end
end

-- Initialize the resource
Citizen.CreateThread(function()
    logInfo("Starting Discord ACE Permissions resource...")
    
    -- Validate configuration
    Discord.validateConfig(function(success, message)
        if success then
            logInfo("Discord configuration validated successfully!")
            resourceStarted = true
            
            -- Update permissions for all current players
            local players = GetPlayers()
            for _, playerId in pairs(players) do
                if Config.RefreshOnJoin then
                    Citizen.Wait(1000) -- Small delay to ensure player is fully loaded
                    AceManager.updatePlayerPermissions(tonumber(playerId))
                end
            end
            
            -- Start periodic update timer if configured
            if Config.UpdateInterval and Config.UpdateInterval > 0 then
                startPeriodicUpdates()
            end
            
        else
            logError("Failed to validate Discord configuration: " .. message)
            logError("Please check your Discord bot token and guild ID in config.lua")
        end
    end)
end)

-- Start periodic permission updates
function startPeriodicUpdates()
    if updateTimer then
        return -- Already running
    end
    
    updateTimer = true
    
    Citizen.CreateThread(function()
        while updateTimer do
            Citizen.Wait(Config.UpdateInterval)
            
            if updateTimer then -- Check again in case it was stopped
                local players = GetPlayers()
                debugPrint("Running periodic permission update for " .. #players .. " players")
                
                for _, playerId in pairs(players) do
                    if updateTimer then -- Check if still running
                        Citizen.Wait(1000) -- Delay between players to avoid rate limits
                        AceManager.updatePlayerPermissions(tonumber(playerId))
                    else
                        break
                    end
                end
            end
        end
    end)
    
    logInfo("Started periodic permission updates every " .. (Config.UpdateInterval / 1000) .. " seconds")
end

-- Stop periodic updates
function stopPeriodicUpdates()
    if updateTimer then
        updateTimer = false
        logInfo("Stopped periodic permission updates")
    end
end

-- Event handlers
AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local source = source
    debugPrint("Player connecting: " .. name .. " (ID: " .. source .. ")")
    
    -- Check whitelist if enabled
    if Config and Config.Whitelist and Config.Whitelist.enabled then
        deferrals.defer()
        deferrals.update("Checking Discord whitelist...")
        
        -- Small delay to ensure Discord module is ready
        Citizen.Wait(1000)
        
        local discordId = Discord.getPlayerDiscordId(source)
        if not discordId then
            debugPrint("No Discord ID found for connecting player: " .. name)
            deferrals.done("You need to have Discord linked to your FiveM account. " .. (Config.Whitelist.discordInvite or ""))
            return
        end
        
        Discord.getPlayerRoles(source, function(success, roles)
            if not success then
                debugPrint("Failed to get Discord roles for connecting player: " .. name)
                deferrals.done("Failed to verify Discord whitelist. Please try again later.")
                return
            end
            
            -- Check if player has the required whitelist role
            local hasWhitelistRole = false
            for _, roleId in pairs(roles) do
                if roleId == Config.Whitelist.requiredRoleId then
                    hasWhitelistRole = true
                    break
                end
            end
            
            if hasWhitelistRole then
                debugPrint("Player " .. name .. " has whitelist role, allowing connection")
                deferrals.done()
            else
                local kickMsg = string.gsub(Config.Whitelist.kickMessage or "You are not whitelisted", "${User}", name)
                logInfo("Rejected connection from " .. name .. " - Missing whitelist role")
                deferrals.done(kickMsg)
            end
        end)
    end
end)

AddEventHandler('playerJoining', function(source)
    local playerName = GetPlayerName(source)
    debugPrint("Player joining: " .. playerName .. " (ID: " .. source .. ")")
    
    if not resourceStarted then
        debugPrint("Resource not fully started yet, skipping permission update for " .. playerName)
        return
    end
    
    -- Small delay to ensure player data is available
    Citizen.SetTimeout(3000, function()
        if GetPlayerPing(source) > 0 then -- Ensure player is still connected
            if Config.RefreshOnJoin then
                AceManager.updatePlayerPermissions(source)
            end
        end
    end)
end)

AddEventHandler('playerDropped', function(reason)
    local source = source
    local playerName = GetPlayerName(source)
    debugPrint("Player dropped: " .. playerName .. " (ID: " .. source .. ") - Reason: " .. reason)
    
    -- Clean up player data
    AceManager.removeAllPermissions(source)
    
    -- Clear Discord cache for this player
    local discordId = Discord.getPlayerDiscordId(source)
    if discordId then
        Discord.clearPlayerCache(discordId)
    end
end)

-- Resource stop handler
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        logInfo("Resource stopping, cleaning up...")
        
        -- Stop periodic updates
        stopPeriodicUpdates()
        
        -- Remove all granted permissions
        local players = GetPlayers()
        for _, playerId in pairs(players) do
            AceManager.removeAllPermissions(tonumber(playerId))
        end
        
        -- Clear all cache
        Discord.clearAllCache()
        
        logInfo("Cleanup completed")
    end
end)

-- Console commands
RegisterCommand('dap_refresh', function(source, args, rawCommand)
    if source ~= 0 then -- Only allow from server console
        return
    end
    
    logInfo("Manually refreshing permissions for all players...")
    local players = GetPlayers()
    
    for _, playerId in pairs(players) do
        Citizen.Wait(500)
        AceManager.updatePlayerPermissions(tonumber(playerId))
    end
    
    logInfo("Permission refresh completed for " .. #players .. " players")
end, true)

RegisterCommand('dap_refresh_player', function(source, args, rawCommand)
    if source ~= 0 then -- Only allow from server console
        return
    end
    
    if not args[1] then
        print("Usage: dap_refresh_player <player_id>")
        return
    end
    
    local targetId = tonumber(args[1])
    if not targetId or GetPlayerName(targetId) == nil then
        print("Invalid player ID: " .. args[1])
        return
    end
    
    logInfo("Refreshing permissions for player: " .. GetPlayerName(targetId))
    AceManager.updatePlayerPermissions(targetId)
end, true)

RegisterCommand('dap_clear_cache', function(source, args, rawCommand)
    if source ~= 0 then -- Only allow from server console
        return
    end
    
    Discord.clearAllCache()
    logInfo("Cleared all Discord cache")
end, true)

RegisterCommand('dap_status', function(source, args, rawCommand)
    if source ~= 0 then -- Only allow from server console
        return
    end
    
    local players = GetPlayers()
    print("^6=== Discord ACE Permissions Status ===^7")
    print("Resource Started: " .. tostring(resourceStarted))
    print("Connected Players: " .. #players)
    print("Periodic Updates: " .. (updateTimer and "Enabled" or "Disabled"))
    print("Update Interval: " .. (Config.UpdateInterval / 1000) .. " seconds")
    print("Debug Mode: " .. tostring(Config.Debug))
    print("Whitelist Enabled: " .. tostring(Config.Whitelist and Config.Whitelist.enabled or false))
    if Config.Whitelist and Config.Whitelist.enabled then
        print("Whitelist Role ID: " .. (Config.Whitelist.requiredRoleId or "Not Set"))
    end
    
    -- Show player status
    for _, playerId in pairs(players) do
        local playerName = GetPlayerName(tonumber(playerId))
        local discordId = Discord.getPlayerDiscordId(tonumber(playerId))
        local permissions = AceManager.getPlayerPermissions(tonumber(playerId))
        
        print("^5Player: " .. playerName .. " (ID: " .. playerId .. ")^7")
        print("  Discord ID: " .. (discordId or "Not Found"))
        print("  Permissions: " .. #permissions.permissions)
        print("  Principals: " .. #permissions.principals)
    end
end, true)

RegisterCommand('dap_whitelist_check', function(source, args, rawCommand)
    if source ~= 0 then -- Only allow from server console
        return
    end
    
    if not args[1] then
        print("Usage: dap_whitelist_check <player_id>")
        return
    end
    
    local targetId = tonumber(args[1])
    if not targetId or GetPlayerName(targetId) == nil then
        print("Invalid player ID: " .. args[1])
        return
    end
    
    local playerName = GetPlayerName(targetId)
    print("Checking whitelist status for: " .. playerName)
    
    Discord.getPlayerRoles(targetId, function(success, roles)
        if success then
            local hasWhitelistRole = false
            for _, roleId in pairs(roles) do
                if roleId == Config.Whitelist.requiredRoleId then
                    hasWhitelistRole = true
                    break
                end
            end
            
            if hasWhitelistRole then
                print("^2" .. playerName .. " HAS the required whitelist role^7")
            else
                print("^1" .. playerName .. " does NOT have the required whitelist role^7")
            end
        else
            print("^1Failed to get Discord roles for " .. playerName .. "^7")
        end
    end)
end, true)

-- Export functions for other resources
exports('updatePlayerPermissions', function(source)
    if resourceStarted then
        AceManager.updatePlayerPermissions(source)
        return true
    end
    return false
end)

exports('getPlayerDiscordRoles', function(source, callback)
    Discord.getPlayerRoles(source, callback)
end)

exports('hasPermission', function(source, permission)
    return AceManager.hasPermission(source, permission)
end)

exports('getPlayerPermissions', function(source)
    return AceManager.getPlayerPermissions(source)
end)

exports('isPlayerInDiscord', function(source, callback)
    Discord.isPlayerInGuild(source, callback)
end)

exports('checkWhitelist', function(source, callback)
    if not Config.Whitelist or not Config.Whitelist.enabled then
        callback(true) -- Whitelist disabled, allow all
        return
    end
    
    Discord.getPlayerRoles(source, function(success, roles)
        if not success then
            callback(false)
            return
        end
        
        for _, roleId in pairs(roles) do
            if roleId == Config.Whitelist.requiredRoleId then
                callback(true)
                return
            end
        end
        callback(false)
    end)
end)

exports('isWhitelisted', function(source)
    -- Synchronous check - only works for already connected players
    if not Config.Whitelist or not Config.Whitelist.enabled then
        return true
    end
    
    -- This would require caching the whitelist status when player joins
    -- For now, use the async version above
    return false
end)

-- Register export events for backwards compatibility
RegisterNetEvent('discord-ace-perms:updatePermissions', function()
    local source = source
    if resourceStarted then
        AceManager.updatePlayerPermissions(source)
    end
end)

RegisterNetEvent('discord-ace-perms:getPermissions', function()
    local source = source
    local permissions = AceManager.getPlayerPermissions(source)
    TriggerClientEvent('discord-ace-perms:permissionsResult', source, permissions)
end)

-- Startup message
Citizen.CreateThread(function()
    Citizen.Wait(5000) -- Wait for resource to fully initialize
    if resourceStarted then
        logInfo("^2Discord ACE Permissions successfully loaded!^7")
        logInfo("Use 'dap_status' in console to view current status")
    else
        logError("^1Discord ACE Permissions failed to load - check your configuration!^7")
    end
end)