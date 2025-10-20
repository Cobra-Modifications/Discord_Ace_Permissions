Discord = {}

-- Cache for player Discord data
local playerCache = {}
local cacheTimestamps = {}

-- Helper function for debugging
local function debugPrint(msg)
    if Config.Debug then
        print("^3[Discord ACE Perms]^7 " .. msg)
    end
end

-- Helper function for error logging
local function logError(msg)
    print("^1[Discord ACE Perms ERROR]^7 " .. msg)
end

-- Function to make HTTP requests to Discord API
local function makeDiscordRequest(endpoint, callback)
    local url = "https://discord.com/api/v10" .. endpoint
    local headers = {
        ["Authorization"] = "Bot " .. Config.DiscordBotToken,
        ["Content-Type"] = "application/json"
    }
    
    PerformHttpRequest(url, function(statusCode, responseText, headers)
        if statusCode == 200 then
            local success, data = pcall(json.decode, responseText)
            if success then
                callback(true, data)
            else
                logError("Failed to parse Discord API response")
                callback(false, nil)
            end
        elseif statusCode == 429 then
            logError("Discord API rate limited. Please wait before retrying.")
            callback(false, nil)
        elseif statusCode == 401 then
            logError("Invalid Discord bot token. Please check your configuration.")
            callback(false, nil)
        elseif statusCode == 403 then
            logError("Discord bot lacks permissions for this operation.")
            callback(false, nil)
        else
            logError("Discord API request failed with status: " .. statusCode)
            callback(false, nil)
        end
    end, "GET", "", headers)
end

-- Get Discord ID from player identifiers
function Discord.getPlayerDiscordId(source)
    local identifiers = GetPlayerIdentifiers(source)
    for _, identifier in pairs(identifiers) do
        if string.match(identifier, "discord:") then
            return string.gsub(identifier, "discord:", "")
        end
    end
    return nil
end

-- Get guild member information
function Discord.getGuildMember(discordId, callback)
    if not discordId then
        callback(false, nil)
        return
    end
    
    -- Check cache first
    if Config.CachePlayerRoles and playerCache[discordId] then
        local cacheAge = GetGameTimer() - (cacheTimestamps[discordId] or 0)
        if cacheAge < Config.CacheExpiration then
            debugPrint("Using cached data for Discord ID: " .. discordId)
            callback(true, playerCache[discordId])
            return
        end
    end
    
    local endpoint = "/guilds/" .. Config.DiscordGuildId .. "/members/" .. discordId
    
    makeDiscordRequest(endpoint, function(success, data)
        if success and data then
            -- Cache the result
            if Config.CachePlayerRoles then
                playerCache[discordId] = data
                cacheTimestamps[discordId] = GetGameTimer()
            end
            
            debugPrint("Retrieved guild member data for Discord ID: " .. discordId)
            callback(true, data)
        else
            -- Player might not be in the Discord server
            debugPrint("Could not find guild member with Discord ID: " .. discordId)
            callback(false, nil)
        end
    end)
end

-- Get player's Discord roles
function Discord.getPlayerRoles(source, callback)
    local discordId = Discord.getPlayerDiscordId(source)
    
    if not discordId then
        debugPrint("No Discord ID found for player: " .. GetPlayerName(source))
        callback(false, {})
        return
    end
    
    Discord.getGuildMember(discordId, function(success, memberData)
        if success and memberData and memberData.roles then
            debugPrint("Found " .. #memberData.roles .. " roles for player: " .. GetPlayerName(source))
            callback(true, memberData.roles)
        else
            debugPrint("No roles found for player: " .. GetPlayerName(source))
            callback(false, {})
        end
    end)
end

-- Check if player is in Discord server
function Discord.isPlayerInGuild(source, callback)
    local discordId = Discord.getPlayerDiscordId(source)
    
    if not discordId then
        callback(false)
        return
    end
    
    Discord.getGuildMember(discordId, function(success, memberData)
        callback(success and memberData ~= nil)
    end)
end

-- Get role information by role ID
function Discord.getRoleInfo(roleId, callback)
    local endpoint = "/guilds/" .. Config.DiscordGuildId .. "/roles"
    
    makeDiscordRequest(endpoint, function(success, roles)
        if success and roles then
            for _, role in pairs(roles) do
                if role.id == roleId then
                    callback(true, role)
                    return
                end
            end
            callback(false, nil)
        else
            callback(false, nil)
        end
    end)
end

-- Clear player cache
function Discord.clearPlayerCache(discordId)
    if discordId then
        playerCache[discordId] = nil
        cacheTimestamps[discordId] = nil
        debugPrint("Cleared cache for Discord ID: " .. discordId)
    end
end

-- Clear all cache
function Discord.clearAllCache()
    playerCache = {}
    cacheTimestamps = {}
    debugPrint("Cleared all Discord cache")
end

-- Validate Discord bot token and guild ID
function Discord.validateConfig(callback)
    if not Config.DiscordBotToken or Config.DiscordBotToken == "YOUR_DISCORD_BOT_TOKEN_HERE" then
        logError("Discord bot token not configured!")
        callback(false, "Invalid bot token")
        return
    end
    
    if not Config.DiscordGuildId or Config.DiscordGuildId == "YOUR_DISCORD_SERVER_ID_HERE" then
        logError("Discord guild ID not configured!")
        callback(false, "Invalid guild ID")
        return
    end
    
    -- Test the bot token by trying to get guild information
    local endpoint = "/guilds/" .. Config.DiscordGuildId
    makeDiscordRequest(endpoint, function(success, data)
        if success and data then
            debugPrint("Discord configuration validated successfully!")
            debugPrint("Connected to guild: " .. (data.name or "Unknown"))
            callback(true, "Configuration valid")
        else
            logError("Failed to validate Discord configuration!")
            callback(false, "Configuration validation failed")
        end
    end)
end