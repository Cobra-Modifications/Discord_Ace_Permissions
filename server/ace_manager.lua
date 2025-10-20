AceManager = {}


local playerPermissions = {}
local playerPrincipals = {}

-- Helper function for debugging
local function debugPrint(msg)
    if Config.Debug then
        print("^2[ACE Manager]^7 " .. msg)
    end
end

-- Helper function for logging
local function logInfo(msg)
    print("^5[ACE Manager]^7 " .. msg)
end

-- Get player identifier for ACE system
local function getPlayerIdentifier(source)
    -- Try to get license identifier first (most reliable)
    local identifiers = GetPlayerIdentifiers(source)
    for _, identifier in pairs(identifiers) do
        if string.match(identifier, "license:") then
            return identifier
        end
    end
    
    -- Fallback to steam if no license
    for _, identifier in pairs(identifiers) do
        if string.match(identifier, "steam:") then
            return identifier
        end
    end
    
    return nil
end

-- Add ACE permission to player
local function grantPermission(source, permission)
    local playerIdentifier = getPlayerIdentifier(source)
    if not playerIdentifier then
        debugPrint("No valid identifier found for player: " .. GetPlayerName(source))
        return false
    end
    
    ExecuteCommand("add_ace identifier." .. playerIdentifier .. " " .. permission .. " allow")
    debugPrint("Granted permission '" .. permission .. "' to " .. GetPlayerName(source) .. " (" .. playerIdentifier .. ")")
    return true
end

-- Remove ACE permission from player
local function revokePermission(source, permission)
    local playerIdentifier = getPlayerIdentifier(source)
    if not playerIdentifier then
        debugPrint("No valid identifier found for player: " .. GetPlayerName(source))
        return false
    end
    
    ExecuteCommand("remove_ace identifier." .. playerIdentifier .. " " .. permission .. " allow")
    debugPrint("Revoked permission '" .. permission .. "' from " .. GetPlayerName(source) .. " (" .. playerIdentifier .. ")")
    return true
end

-- Add principal (group) to player
local function grantPrincipal(source, principal)
    local playerIdentifier = getPlayerIdentifier(source)
    if not playerIdentifier then
        debugPrint("No valid identifier found for player: " .. GetPlayerName(source))
        return false
    end
    
    ExecuteCommand("add_principal identifier." .. playerIdentifier .. " " .. principal)
    debugPrint("Granted principal '" .. principal .. "' to " .. GetPlayerName(source) .. " (" .. playerIdentifier .. ")")
    return true
end

-- Remove principal (group) from player
local function revokePrincipal(source, principal)
    local playerIdentifier = getPlayerIdentifier(source)
    if not playerIdentifier then
        debugPrint("No valid identifier found for player: " .. GetPlayerName(source))
        return false
    end
    
    ExecuteCommand("remove_principal identifier." .. playerIdentifier .. " " .. principal)
    debugPrint("Revoked principal '" .. principal .. "' from " .. GetPlayerName(source) .. " (" .. playerIdentifier .. ")")
    return true
end

-- Get permissions that should be granted based on Discord roles
function AceManager.getPermissionsFromRoles(discordRoles)
    local permissions = {}
    local principals = {}
    
    for _, roleId in pairs(discordRoles) do
        -- Check for direct permissions
        if Config.RolePermissions[roleId] then
            for _, permission in pairs(Config.RolePermissions[roleId]) do
                if not permissions[permission] then
                    permissions[permission] = true
                end
            end
        end
        
        -- Check for principals
        if Config.RolePrincipals[roleId] then
            local principal = Config.RolePrincipals[roleId]
            if not principals[principal] then
                principals[principal] = true
            end
        end
    end
    
    -- Convert to arrays
    local permissionArray = {}
    local principalArray = {}
    
    for permission, _ in pairs(permissions) do
        table.insert(permissionArray, permission)
    end
    
    for principal, _ in pairs(principals) do
        table.insert(principalArray, principal)
    end
    
    return permissionArray, principalArray
end

-- Update player's ACE permissions based on Discord roles
function AceManager.updatePlayerPermissions(source)
    local playerName = GetPlayerName(source)
    debugPrint("Updating permissions for player: " .. playerName)
    
    Discord.getPlayerRoles(source, function(success, roles)
        if not success then
            debugPrint("Failed to get Discord roles for player: " .. playerName)
            return
        end
        
        -- Get current permissions that should be assigned
        local newPermissions, newPrincipals = AceManager.getPermissionsFromRoles(roles)
        
        -- Get previously assigned permissions
        local oldPermissions = playerPermissions[source] or {}
        local oldPrincipals = playerPrincipals[source] or {}
        
        -- Remove old permissions that are no longer valid
        for _, permission in pairs(oldPermissions) do
            local shouldKeep = false
            for _, newPermission in pairs(newPermissions) do
                if permission == newPermission then
                    shouldKeep = true
                    break
                end
            end
            
            if not shouldKeep then
                revokePermission(source, permission)
            end
        end
        
        -- Remove old principals that are no longer valid
        for _, principal in pairs(oldPrincipals) do
            local shouldKeep = false
            for _, newPrincipal in pairs(newPrincipals) do
                if principal == newPrincipal then
                    shouldKeep = true
                    break
                end
            end
            
            if not shouldKeep then
                revokePrincipal(source, principal)
            end
        end
        
        -- Grant new permissions
        for _, permission in pairs(newPermissions) do
            local alreadyHas = false
            for _, oldPermission in pairs(oldPermissions) do
                if permission == oldPermission then
                    alreadyHas = true
                    break
                end
            end
            
            if not alreadyHas then
                grantPermission(source, permission)
            end
        end
        
        -- Grant new principals
        for _, principal in pairs(newPrincipals) do
            local alreadyHas = false
            for _, oldPrincipal in pairs(oldPrincipals) do
                if principal == oldPrincipal then
                    alreadyHas = true
                    break
                end
            end
            
            if not alreadyHas then
                grantPrincipal(source, principal)
            end
        end
        
        -- Update stored permissions
        playerPermissions[source] = newPermissions
        playerPrincipals[source] = newPrincipals
        
        -- Log the update
        if #newPermissions > 0 or #newPrincipals > 0 then
            local permStr = table.concat(newPermissions, ", ")
            local princStr = table.concat(newPrincipals, ", ")
            logInfo("Updated permissions for " .. playerName .. 
                   " | Permissions: [" .. permStr .. "]" ..
                   " | Principals: [" .. princStr .. "]")
        else
            debugPrint("No permissions assigned to " .. playerName)
        end
        
        -- Send webhook notification if enabled
        if Config.Webhook.enabled then
            AceManager.sendWebhookNotification(source, newPermissions, newPrincipals)
        end
    end)
end

-- Remove all permissions from a player
function AceManager.removeAllPermissions(source)
    local playerName = GetPlayerName(source)
    debugPrint("Removing all permissions from player: " .. playerName)
    
    -- Remove tracked permissions
    local oldPermissions = playerPermissions[source] or {}
    local oldPrincipals = playerPrincipals[source] or {}
    
    for _, permission in pairs(oldPermissions) do
        revokePermission(source, permission)
    end
    
    for _, principal in pairs(oldPrincipals) do
        revokePrincipal(source, principal)
    end
    
    -- Clear tracking
    playerPermissions[source] = nil
    playerPrincipals[source] = nil
    
    logInfo("Removed all permissions from " .. playerName)
end

-- Check if player has a specific permission (export function)
function AceManager.hasPermission(source, permission)
    local playerIdentifier = getPlayerIdentifier(source)
    if not playerIdentifier then
        return false
    end
    
    return IsPlayerAceAllowed(source, permission)
end

-- Get player's current permissions (export function)
function AceManager.getPlayerPermissions(source)
    return {
        permissions = playerPermissions[source] or {},
        principals = playerPrincipals[source] or {}
    }
end

-- Send webhook notification about permission changes
function AceManager.sendWebhookNotification(source, permissions, principals)
    if not Config.Webhook.enabled or not Config.Webhook.url then
        return
    end
    
    local playerName = GetPlayerName(source)
    local discordId = Discord.getPlayerDiscordId(source)
    
    local embed = {
        title = "ACE Permissions Updated",
        color = 3447003, -- Blue color
        fields = {
            {
                name = "Player",
                value = playerName .. " (" .. source .. ")",
                inline = true
            },
            {
                name = "Discord ID",
                value = discordId or "Not Found",
                inline = true
            },
            {
                name = "Permissions",
                value = #permissions > 0 and table.concat(permissions, "\n") or "None",
                inline = false
            },
            {
                name = "Principals",
                value = #principals > 0 and table.concat(principals, "\n") or "None",
                inline = false
            }
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    
    local payload = {
        username = Config.Webhook.name,
        avatar_url = Config.Webhook.avatar,
        embeds = {embed}
    }
    
    PerformHttpRequest(Config.Webhook.url, function(statusCode, responseText, headers)
        if statusCode ~= 204 then
            debugPrint("Webhook notification failed with status: " .. statusCode)
        end
    end, "POST", json.encode(payload), {["Content-Type"] = "application/json"})
end