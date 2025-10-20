# Discord ACE Perms - Installation & Setup Guide

This guide will help you install and configure the Discord ACE Perms resource for your FiveM server.

## Prerequisites
- A running FiveM server
- Access to your server's `server.cfg` and resources folder
- A Discord bot token and server (guild) ID
- (Optional) Discord webhook URL for logging - Currently Not Working.

## Installation Steps

### 1. Download & Place the Resource
- Place the entire `discord-ace-perms` folder in your server's `resources` directory.

### 2. Configure the Resource
- Open `config.lua` and set the following:
  - `Config.DiscordBotToken`: Your Discord bot token
  - `Config.DiscordGuildId`: Your Discord server (guild) ID
  - `Config.Whitelist`: Set up whitelist options and required role ID
  - `Config.RolePermissions`: Map Discord role IDs to ACE permissions
  - `Config.Webhook`: (Optional) Set up webhook logging

### 3. Update Your server.cfg
Add the following lines to your `server.cfg`:

```
# Grant the resource permission to manage ACE permissions
add_ace resource.discord-ace-perms command.add_ace allow
add_ace resource.discord-ace-perms command.add_principal allow
add_ace resource.discord-ace-perms command.remove_ace allow
add_ace resource.discord-ace-perms command.remove_principal allow

# Start the resource
ensure discord-ace-perms
```

### 4. Set Up Your Discord Bot
- Invite your bot to your Discord server with the `guilds` and `members` intents enabled.
- Give the bot a role with permission to read member roles.

### 5. (Optional) Set Up Webhook Logging - Again not working currently wip.
- Create a Discord webhook in your desired channel.
- Paste the webhook URL in `Config.Webhook.url` in `config.lua`.
- Set `Config.Webhook.enabled = true`.

### 6. Start Your Server
- Restart your FiveM server.
- Check the console for any errors.
- Test by joining the server and verifying ACE permissions are assigned based on Discord roles.

## Troubleshooting
- If permissions are not assigned, check your bot token, guild ID, and role mappings.

## Support
For further help, open an issue or ask in Cobra`s Friends Discord !.
