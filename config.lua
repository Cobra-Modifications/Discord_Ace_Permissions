Config = {}

-- Discord Bot Configuration
Config.DiscordBotToken = "Set_Your_Discord_Bot_Token_Here" -- Replace with your Discord bot token
Config.DiscordGuildId = "Set_Your_Discord_Guild_ID_Here"  -- Replace with your Discord server ID

-- Debug mode (set to false in production)
Config.Debug = false

-- Permission update interval (in milliseconds)
Config.UpdateInterval = 300000 -- 5 minutes

-- Auto-refresh permissions when player joins
Config.RefreshOnJoin = true

-- Remove permissions when player leaves Discord server
Config.RemoveOnLeave = true

-- Whitelist System Configuration
Config.Whitelist = {
    enabled = false, -- Set to true to enable whitelist system
    requiredRoleId = "Set_Your_Required_Role_ID_Here", -- Role ID required to join the server
    kickMessage = "You need to join our discord community and apply for whitelist to be able to play within this server. Discord Invite: Here",
    discordInvite = "https://discord.gg/YourInviteCode" -- Replace with your actual Discord invite
}

-- Role to ACE Permission Mappings
-- Format: ["role_id"] = {"ace_permission_1", "ace_permission_2", ...}
Config.RolePermissions = {
    -- Add your role mappings here as needed
    ["Your_Role_ID_Here"] = {"doorlock.police"} -- Owner role
}

-- Principal mappings (for advanced ACE usage)
-- This allows you to assign principals (groups) based on Discord roles
Config.RolePrincipals = {
    ["Your_Role_ID_Here"] = "group.owner",    -- Owner role gets owner principal
    ["Your_Role_ID_Here"] = "group.admin",    -- Admin role gets admin principal
    ["Your_Role_ID_Here"] = "group.moderator",      -- Mod role gets mod principal
    ["Your_Role_ID_Here"] = "group.user"      -- User role gets user principal

}

-- Webhook Configuration (This is not working yet - coming soon)
Config.Webhook = {
    enabled = false,
    url = "Set_Your_Webhook_URL_Here", -- Replace with your webhook URL
    name = "Discord ACE Perms",
    avatar = "Set_Your_LOGO_URL_Here" -- Optional: Replace with your avatar URL
}

-- Error handling
Config.RetryAttempts = 3
Config.RetryDelay = 5000 -- 5 seconds

-- Cache settings
Config.CachePlayerRoles = true
Config.CacheExpiration = 600000 -- 10 minutes